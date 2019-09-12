---
title: kubernetes使用ceph存储卷
tags:
  - kubernetes
  - ceph
categories:
  - 容器编排
date: 2019-09-07 18:40:00+08:00
---

最近我在kubernetes中使用了ceph的rbd及cephfs存储卷，遇到了一些问题，并逐一解决了，在这里记录一下。

## ceph rbd存储卷扩容失败

第一个问题是某应用程序使用了ceph rbd存储卷，但随着时间的推移，发现原来pvc申请的存储空间不够用了，需要进行扩容。这里参考[官方指引](https://kubernetes.io/blog/2018/07/12/resizing-persistent-volumes-using-kubernetes/)，进行了一些配置。

storageclass设置`allowVolumeExpansion: true`：

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: rbd
provisioner: ceph.com/rbd
parameters:
  monitors: xx.xx.xx.xx:6789
  pool: kube
  adminId: admin
  adminSecretNamespace: kube-system
  adminSecretName: ceph-admin-secret
  userId: kube
  userSecretNamespace: kube-system
  userSecretName: ceph-secret
  imageFormat: "2"
  imageFeatures: layering
allowVolumeExpansion: true
```

`kube-controller-manager`及`kubelet`均开启`ExpandPersistentVolumes`、`PersistentVolumeClaimResize`、`ExpandInUsePersistentVolumes`：

```bash
--feature-gates ExpandPersistentVolumes=true,PersistentVolumeClaimResize=true,ExpandInUsePersistentVolumes=true
```

然后edit某个pvc，将`spec.resources.requests.storage`增大：

```bash
$ kubectl edit pvc resize
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    volume.beta.kubernetes.io/storage-provisioner: ceph.com/rbd
  name: resize
spec:
  resources:
    requests:
      storage: 5Gi
  storageClassName: sata
```

然后查看pvc，但过了很久，pvc仍然没有进行`FileSystemResizePending`状态。

难道遇到kubernetes的bug了？

查阅kubernetes的代码后，发现kubernetes是调用`rbd info`及`rbd resize`等外部命令完成rbd存储卷的扩容的：

`https://github.com/kubernetes/kubernetes/blob/master/pkg/volume/rbd/rbd_util.go#L647`

```go
// ExpandImage runs rbd resize command to resize the specified image.
func (util *RBDUtil) ExpandImage(rbdExpander *rbdVolumeExpander, oldSize resource.Quantity, newSize resource.Quantity) (resource.Quantity, error) {
	var output []byte
	var err error

	// Convert to MB that rbd defaults on.
	sz := int(volumehelpers.RoundUpToMiB(newSize))
	newVolSz := fmt.Sprintf("%d", sz)
	newSizeQuant := resource.MustParse(fmt.Sprintf("%dMi", sz))

	// Check the current size of rbd image, if equals to or greater that the new request size, do nothing.
	curSize, infoErr := util.rbdInfo(rbdExpander.rbdMounter)
	if infoErr != nil {
		return oldSize, fmt.Errorf("rbd info failed, error: %v", infoErr)
	}
	if curSize >= sz {
		return newSizeQuant, nil
	}

	// rbd resize.
	mon := util.kernelRBDMonitorsOpt(rbdExpander.rbdMounter.Mon)
	klog.V(4).Infof("rbd: resize %s using mon %s, pool %s id %s key %s", rbdExpander.rbdMounter.Image, mon, rbdExpander.rbdMounter.Pool, rbdExpander.rbdMounter.adminId, rbdExpander.rbdMounter.adminSecret)
	output, err = rbdExpander.exec.Run("rbd",
		"resize", rbdExpander.rbdMounter.Image, "--size", newVolSz, "--pool", rbdExpander.rbdMounter.Pool, "--id", rbdExpander.rbdMounter.adminId, "-m", mon, "--key="+rbdExpander.rbdMounter.adminSecret)
	if err == nil {
		return newSizeQuant, nil
	}

	klog.Errorf("failed to resize rbd image: %v, command output: %s", err, string(output))
	return oldSize, err
}
```

而执行这些外部命令后，代码还会解析这些命令的输出。而如果ceph的配置文件中启用了一些调试输出，则解析会发生错误。

知道原因就很好办了，修改`/etc/ceph/ceph.conf`文件，注释掉调试输出的设置就好了。

## cephfs存储卷quota失效

项目里还有一些应用程序使用了cephfs的存储卷，但经过验证，发现pvc里设置的存储卷大小无效，应用程序可以随意往存储卷里写入大量数据，这就很危险了。

```bash
$ cat test.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test
spec:
  storageClassName: cephfs
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: test
  containers:
    - name: nginx-server
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: data

# pvc的容量只有1G，竟然可以写入2G的数据到存储卷
$ kubectl exec -ti test-pod -- dd if=/dev/zero of=/usr/share/nginx/html/testfile.dat count=2018 bs=1048576
```

这里使用的是[cephfs-provisioner](https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/cephfs)来供应cephfs存储卷的。

浏览[cephfs-provisioner](https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/cephfs)的代码，发现它其实提供了一个`enable-quota`参数，用来启用pvc的quota功能。

`https://github.com/kubernetes-incubator/external-storage/blob/master/ceph/cephfs/cephfs-provisioner.go#L383`

```go
enableQuota                   = flag.Bool("enable-quota", false, "Enable PVC quota")
```

于是给[cephfs-provisioner](https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/cephfs)加上参数`-enable-quota=true`：

```yaml
kubectl edit deployment cephfs-provisioner

spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: cephfs-provisioner
  strategy:
    type: Recreate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: cephfs-provisioner
    spec:
      containers:
      - args:
        ...
        - -enable-quota=true
        command:
        - /usr/local/bin/cephfs-provisioner
```

本以为会一切正常，但在创建cephfs存储卷时却报错了：

```
E0831 12:27:01.347130       1 cephfs-provisioner.go:158] failed to provision share "kubernetes-dynamic-pvc-a1f36dc2-cbea-11e9-97cf-6639535e4727" for "kubernetes-dynamic-user-a1f36ec8-cbea-11e9-97cf-6639535e4727", err: exit status 1, output: Traceback (most recent call last):
  File "/usr/local/bin/cephfs_provisioner", line 364, in <module>
    main()
  File "/usr/local/bin/cephfs_provisioner", line 358, in main
    print cephfs.create_share(share, user, size=size)
  File "/usr/local/bin/cephfs_provisioner", line 228, in create_share
    volume = self.volume_client.create_volume(volume_path, size=size, namespace_isolated=not self.ceph_namespace_isolation_disabled)
  File "/lib/python2.7/site-packages/ceph_volume_client.py", line 622, in create_volume
    self.fs.setxattr(path, 'ceph.quota.max_bytes', size.__str__(), 0)
  File "cephfs.pyx", line 988, in cephfs.LibCephFS.setxattr (/home/jenkins-build/build/workspace/ceph-build/ARCH/x86_64/AVAILABLE_ARCH/x86_64/AVAILABLE_DIST/centos7/DIST/centos7/MACHINE_SIZE/huge/release/13.2.1/rpm/el7/BUILD/ceph-13.2.1/build/src/pybind/cephfs/pyrex/cephfs.c:10498)
cephfs.OperationNotSupported: [Errno 95] error in setxattr
```

继续查原因，发现`cephfs-provisioner`实际上是调用`libcephfs`中的`ceph_setxattr`函数，以实现给创建的cephfs存储卷设置quota的。而直接在ceph集群上通过命令给某个目录设置quota是正常的。看来还是哪里不太正常。

继续追查，发现`cephfs-provisioner`项目的[Dockerfile](https://github.com/kubernetes-incubator/external-storage/blob/master/ceph/cephfs/Dockerfile)里指示了安装的是`mimic`版的`ceph-common`和`python-cephfs`，而我部署的ceph集群是`luminous`版。会不会是ceph客户端与服务端不兼容？立即修改[Dockerfile](https://github.com/kubernetes-incubator/external-storage/blob/master/ceph/cephfs/Dockerfile)文件，改成安装`luminous`版`ceph-common`和`python-cephfs`，重新编译docker镜像，更新`cephfs-provisioner`所使用的镜像，这下创建pvc时终于不报错了。这里我们再检查下cephfs存储卷目录的quota是正常的。

```bash
$ mkdir test
$ ceph-fuse -c /etc/ceph/ceph.conf -m xx.xx.xx.xx:6789 -r /xxxx test
$ getfattr -n ceph.quota.max_bytes test
1073741824
```

看起来一切很美好了，但经测试发现quota依然无效，应用程序还是无视quota随意往存储卷里写入大量数据。

继续追查问题，发现CephFS的mount方式分为内核态mount和用户态mount，内核态使用mount命令挂载，用户态使用ceph-fuse。内核态只有在kernel 4.17 以上的版本才支持Quotas，用户态则没有限制。而我们的环境中内核明显没有这么高，而kubernetes的代码里会根据是否找得到`ceph-fuse`命令决定是否使用用户态挂载。

`https://github.com/kubernetes/kubernetes/blob/master/pkg/volume/cephfs/cephfs.go#L245`

```go
	// check whether it belongs to fuse, if not, default to use kernel mount.
	if cephfsVolume.checkFuseMount() {
		klog.V(4).Info("CephFS fuse mount.")
		err = cephfsVolume.execFuseMount(dir)
		// cleanup no matter if fuse mount fail.
		keyringPath := cephfsVolume.GetKeyringPath()
		_, StatErr := os.Stat(keyringPath)
		if !os.IsNotExist(StatErr) {
			os.RemoveAll(keyringPath)
		}
		if err == nil {
			// cephfs fuse mount succeeded.
			return nil
		}
		// if cephfs fuse mount failed, fallback to kernel mount.
		klog.V(2).Infof("CephFS fuse mount failed: %v, fallback to kernel mount.", err)

	}
	klog.V(4).Info("CephFS kernel mount.")

	err = cephfsVolume.execMount(dir)
	if err != nil {
		// cleanup upon failure.
		mount.CleanupMountPoint(dir, cephfsVolume.mounter, false)
		return err
	}
```

为了使用用户态挂载，则需要在node节点上安装`ceph-fuse`的软件包。验证一把，这下应用程序终于在受限的盒子里使用cephfs存储卷了。

真正的用户场景还是涉及cephfs存储卷的扩容，在网上找了下，发现已经有人实现了，文章在[这里](https://ieevee.com/tech/2019/04/14/pvc-resize.html#4cephfs可以扩容吗)。咨询过作者，大致了解了实现方法，需要修改kubernetes的代码：

1. 修改[k8s.io/kubernetes/cmd/kube-controller-manager/app/plugins.go](http://k8s.io/kubernetes/cmd/kube-controller-manager/app/plugins.go)， 将cephfs加入ExpandableVolumePlugins列表里

```go 
// ProbeExpandableVolumePlugins returns volume plugins which are expandable
func ProbeExpandableVolumePlugins(config persistentvolumeconfig.VolumeConfiguration) []volume.VolumePlugin {
   allPlugins := []volume.VolumePlugin{}

   allPlugins = append(allPlugins, awsebs.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, gcepd.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, cinder.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, portworx.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, vsphere_volume.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, glusterfs.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, rbd.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, azure_dd.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, azure_file.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, scaleio.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, storageos.ProbeVolumePlugins()...)
   allPlugins = append(allPlugins, fc.ProbeVolumePlugins()...)
   return allPlugins
}
```

2. 修改[k8s.io/kubernetes/pkg/volume/cephfs/cephfs.go](http://k8s.io/kubernetes/pkg/volume/cephfs/cephfs.go)

```go 
type ExpandableVolumePlugin interface {
   VolumePlugin
   ExpandVolumeDevice(spec *Spec, newSize resource.Quantity, oldSize resource.Quantity) (resource.Quantity, error)
   RequiresFSResize() bool
}
```

在交流的过程中还结识了一个做kubernetes的同行-[伊布](https://ieevee.com/about/)。

使用cephfs用户态挂载并不是完全没有缺陷的，在实际运营过程中，我们发现当重启了node节点上的kubelet，已经挂载的cephfs卷会失效，而使用这些cephfs卷的容器会出现`Transport endpoint is not connected`的报错。目前想到三种办法解决问题：

1. 通过`kubectl describe pod`、`docker inspect`等命令找到需要挂载cephfs卷的目录，通过`kubectl describe pv`命令找到cephfs卷的连接信息，然后使用`ceph-fuse`命令将cephfs卷挂载起来，参考如下命令：

   ```bash
   ceph-fuse -c /etc/ceph/ceph.conf -m xx.xx.xx.xx:6789 -r /xxxx /yyyy
   ```

2. 使用`kubectl delete pod`删除pod，kubernetes重建pod时会重新将cephfs卷挂载上。

3. 最后一招是一劳永逸的，修改kubernetes的代码，使用 `systemd-run` 来执行 `ceph-fuse`命令，这样重启kubelet后，这些`ceph-fuse`用户态进程不会随着kubelet进程的退出而退出，因此cephfs卷的挂载就不会失效，参考这个[bug提交](https://github.com/kubernetes/kubernetes/issues/77209)，抽空把这个bug改了，给社区做点贡献。

## 参考

1. https://kubernetes.io/blog/2018/07/12/resizing-persistent-volumes-using-kubernetes/
2. https://ieevee.com/tech/2019/04/14/pvc-resize.html
3. https://docs.ceph.com/docs/master/cephfs/quota/
4. https://docs.ceph.com/docs/master/cephfs/kernel/
5. https://docs.ceph.com/docs/master/cephfs/fuse/
6. https://www.cnblogs.com/ltxdzh/p/9173706.html