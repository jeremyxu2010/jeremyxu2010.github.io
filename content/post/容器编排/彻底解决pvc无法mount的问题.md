---
title: 彻底解决pvc无法mount的问题
author: Jeremy Xu
tags:
  - k8s
  - devops
  - ceph
categories:
  - 容器编排
date: 2019-07-14 18:00:00+08:00
---

上周解决pvc无法mount的问题，其实留了一个尾巴，当时只是知道由于未知的原因，`AttachDetachController`执行`detach`操作失败了。这周这个问题又出现了，这次追查了一下根源，这里记录下。

## 问题复现

在某个测试环境，删除大量pod，待kubernetes重建大量pod时，该问题就复现了。

## 问题根源

检查kubelet的日志，可以看到以下的报错

```
E0708 09:50:14.407804   26508 nestedpendingoperations.go:267] Operation for "\"kubernetes.io/rbd/k8s:kubernetes-dynamic-pvc-998825ec-9c79-11e9-a3b2-fa163ed7c802\"" failed. No retries permitted until 2019-07-08 09:50:14.907753132 +0800 CST m=+247869.135080115 (durationBeforeRetry 500ms). Error: "UnmountDevice failed for volume \"pvc-9984bdab-9c79-11e9-b8ba-fa163ed7c802\" (UniqueName: \"kubernetes.io/rbd/k8s:kubernetes-dynamic-pvc-998825ec-9c79-11e9-a3b2-fa163ed7c802\") on node \"10.125.54.133\" : rbd: failed to unmap device /dev/rbd3, error exit status 16, rbd output: [114 98 100 58 32 115 121 115 102 115 32 119 114 105 116 101 32 102 97 105 108 101 100 10 114 98 100 58 32 117 110 109 97 112 32 102 97 105 108 101 100 58 32 40 49 54 41 32 68 101 118 105 99 101 32 111 114 32 114 101 115 111 117 114 99 101 32 98 117 115 121 10]"
```

上面的rbd output用[ascii-to-text工具](https://www.browserling.com/tools/ascii-to-text)解码为字符串为`rbd: sysfs write failed rbd: unmap failed: (16) Device or resource busy`，应该是块设备被占用了。直接用`rbd unmap`detach volome一次，发现也报这个错，所以该块设备一直被占用着，接下来查一下到底是什么进程占用着该块设备。

先用lsof查一下：

```bash
[root@node133 ~]# lsof 2>/dev/null | grep rbd3
rbd3-task  6561            root  cwd       DIR              253,1      4096          2 /
rbd3-task  6561            root  rtd       DIR              253,1      4096          2 /
rbd3-task  6561            root  txt   unknown                                         /proc/6561/exe
jbd2/rbd3  6589            root  cwd       DIR              253,1      4096          2 /
jbd2/rbd3  6589            root  rtd       DIR              253,1      4096          2 /
jbd2/rbd3  6589            root  txt   unknown                                         /proc/6589/exe
```

可以看到只有两个进程占用着该块设备。网上google了下，找到[这篇文章](https://www.fclose.com/linux-kernels/488425/jbd2-fix-use-after-free-in-kjournald2-linux-3-18-107/)，最开始以为是内核的bug，于是将内核升级到较高的版本`4.4.184-1.el7.elrepo.x86_64`，但问题依然会重现。

一愁莫展，就疯狂在网上搜寻答案，偶然看到[这篇帖子](https://unix.stackexchange.com/questions/437025/how-to-stop-jbd2-on-unmounted-filesystem)里的一段话:

> I really expect, if the FS is marked as dirty (mounted), and JBD is still running... that's because it's still mounted. E.g. what does /proc/self/mountinfo show? I wonder if you can pinky-swear you're not using mount namespaces... see here for suggestions on how to find and inspect other mount namespaces. It assumes you are in the initial PID namespace, i.e. you're not running inside a sandbox where you can't see all the processes on the system. – sourcejedi May 18 '18 at 8:55 

从这段话我知道了lsof查不到占用块设备文件的用户进程，很有可能是该进程在某个PID命名空间，在根PID命名空间通过普通命令查不到而已。

于是我换了一种方式查，果然就查到关键的用户进程：

```bash
[root@node133 ~]# grep 'rbd3' /proc/*/task/*/mountinfo

/proc/21839/task/28447/mountinfo:2892 2729 250:0 / /host/data/kubelet/plugins/kubernetes.io/rbd/mounts/k8s-image-kubernetes-dynamic-pvc-c838258f-9c7a-11e9-a3b2-fa163ed7c802 rw,relatime - ext4 /dev/rbd3 rw,stripe=1024,data=ordered

[root@node133 ~]# ps -ef|grep 21839
nfsnobo+ 21839 21795  0 01:26 ?        00:00:08 /bin/node_exporter --path.procfs=/host/proc --path.sysfs=/host/sys --collector.filesystem.ignored-fs-types=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs|tmpfs)$ --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|data/docker/.+|etc/.+|run/secrets)($|/) --path.rootfs=/host
```

## 根源分析

竟然是prometheus的node_exporter进程占用着该块设备文件，真的是想不到啊。将该进程杀掉，`rbd unmap`终于可以正常detach rbd volume了。

继续搜寻了一下，发现也有人遇到[这个问题](https://github.com/kubernetes/kubernetes/issues/54214#issuecomment-341357733)，这个评论里说明的原因是node_exporter因为要查探磁盘的使用率等数值，会将根文件系统挂载到容器里，而kubernetes默认的`Mount propagation`策略是`None`，即容器一旦启动，它从宿主机中读到的挂载信息就不变了，即使在宿主机里`unmount`了某个目录，容器里对此一无所知，它仍然会将块设备挂载到容器里的某个目录。

继续看`prometheus-node-exporter`这个chart的变动，发现也有人给`helm`官方报告[这个问题](https://github.com/helm/charts/pull/11194)，并且还发了PR，在挂载卷时通过使用`mountPropagation: HostToContainer`选项以解决该问题。加上了该选项后，如果宿主机的挂载信息发生变动后，挂载信息将能传播到容器里。容器内也会`unmount`相应的目录，从而最终释放对块设备的占用。

这里摘录下kubernetes提供的Mount propagation策略：

> Mount propagation allows for sharing volumes mounted by a Container to other Containers in the same Pod, or even to other Pods on the same node.
>
> Mount propagation of a volume is controlled by mountPropagation field in Container.volumeMounts. Its values are:
>
> None - This volume mount will not receive any subsequent mounts that are mounted to this volume or any of its subdirectories by the host. In similar fashion, no mounts created by the Container will be visible on the host. This is the default mode.
This mode is equal to private mount propagation as described in the Linux kernel documentation
>
> HostToContainer - This volume mount will receive all subsequent mounts that are mounted to this volume or any of its subdirectories.
In other words, if the host mounts anything inside the volume mount, the Container will see it mounted there.
>
> Similarly, if any Pod with Bidirectional mount propagation to the same volume mounts anything there, the Container with HostToContainer mount propagation will see it.
>
> This mode is equal to rslave mount propagation as described in the Linux kernel documentation
>
> Bidirectional - This volume mount behaves the same the HostToContainer mount. In addition, all volume mounts created by the Container will be propagated back to the host and to all Containers of all Pods that use the same volume.
> A typical use case for this mode is a Pod with a Flexvolume or CSI driver or a Pod that needs to mount something on the host using a hostPath volume.
>
> This mode is equal to rshared mount propagation as described in the Linux kernel documentation
>
> Caution: Bidirectional mount propagation can be dangerous. It can damage the host operating system and therefore it is allowed only in privileged Containers. Familiarity with Linux kernel behavior is strongly recommended. In addition, any volume mounts created by Containers in Pods must be destroyed (unmounted) by the Containers on termination.

## 问题解决

经验证`prometheus-node-exporter`挂载volume时加了`mountPropagation: HostToContainer`选项后，`prometheus-node-exporter`确实不会占用块设备了。

但问题还没完，毕竟是采用`Mount propagation`方式来释放块设备的，既然是传播就存在一个时延。在这个时延范围内，如果`detach volume`还是会失败的。理论上kubernetes在`detach volume`失败后，会尝试重试的，但这个重试逻辑有些问题，会导致无法重试`rbd unmap`:

```golang
// rbd volume will stuck when DetachDisk failed as Unmount will always returen not mounted

func (detacher *rbdDetacher) UnmountDevice(deviceMountPath string) error { 
 	if pathExists, pathErr := volutil.PathExists(deviceMountPath); pathErr != nil { 
 		return fmt.Errorf("Error checking if path exists: %v", pathErr) 
 	} else if !pathExists { 
 		klog.Warningf("Warning: Unmount skipped because path does not exist: %v", deviceMountPath) 
 		return nil 
 	} 
 	devicePath, _, err := mount.GetDeviceNameFromMount(detacher.mounter, deviceMountPath) 
 	if err != nil { 
 		return err 
 	} 
 	// Unmount the device from the device mount point. 
 	klog.V(4).Infof("rbd: unmouting device mountpoint %s", deviceMountPath) 
 	if err = detacher.mounter.Unmount(deviceMountPath); err != nil { 
 		return err 
 	} 
 	klog.V(3).Infof("rbd: successfully umount device mountpath %s", deviceMountPath) 
  
 	klog.V(4).Infof("rbd: detaching device %s", devicePath) 
 	err = detacher.manager.DetachDisk(detacher.plugin, deviceMountPath, devicePath) 
 	if err != nil { 
 		return err 
 	} 
 	klog.V(3).Infof("rbd: successfully detach device %s", devicePath) 
 	err = os.Remove(deviceMountPath) 
 	if err != nil { 
 		return err 
 	} 
 	klog.V(3).Infof("rbd: successfully remove device mount point %s", deviceMountPath) 
 	return nil 
 } 
```

为此，我最终还是修改了kubernetes的代码，并给官方发了[PR](https://github.com/kubernetes/kubernetes/pull/79940)

## 临时解决方案

等官方合入PR毕竟时间较长，在官方未修复该问题时，我们可以通过定时脚本规避该问题：

`/usr/local/bin/unmap_not_used_rbd.sh`

```bash
#!/bin/bash
for v in $(find /dev -name 'rbd*'); do
   # 如果设备没被占用，就正常unmap; 如果设备当前被使用，则unmap失败
   /usr/bin/rbd unmap $v
done
```

```bash
# 每分钟定时执行下上述脚本
chmod +x /usr/local/bin/unmap_not_used_rbd.sh
echo '* * * * * /usr/local/bin/unmap_not_used_rbd.sh >/dev/null 2>&1' >> /var/spool/cron/root
```

## 总结

有时候问题的根源总在一个想不到的地方，需要仔细追查。

## 参考

1. https://www.fclose.com/linux-kernels/488425/jbd2-fix-use-after-free-in-kjournald2-linux-3-18-107/
2. https://www.browserling.com/tools/ascii-to-text
3. https://unix.stackexchange.com/questions/437025/how-to-stop-jbd2-on-unmounted-filesystem
4. https://github.com/kubernetes/kubernetes/issues/54214#issuecomment-341357733
4. https://kubernetes.io/docs/concepts/storage/volumes/#mount-propagation
5. https://github.com/kubernetes/kubernetes/pull/79940