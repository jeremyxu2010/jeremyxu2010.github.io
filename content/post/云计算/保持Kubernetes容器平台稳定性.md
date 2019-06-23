---
title: 保持Kubernetes容器平台稳定性
tags:
  - kubernetes
  - docker
categories:
  - 云计算
author: Jeremy Xu
date: 2019-05-21 20:26:00+08:00
---

这两天搭建了一套新的kubernetes环境，由于这套环境会被用于演示，所以持续观察了好几天这套环境，发现不少容器平台稳定性的问题，这里记录一下以备忘。

## 环境

我们这套环境的操作系统是`4.4.131-20181130.kylin.server aarm64 GNU/Linux`，64核128G内存。

## 各类问题

### docker的问题

最开始用的docker版本为`18.03.1-ce`，但在运行四五十个容器后，出现了`docker info`不响应的问题。因为情况紧急，没有查明原因，临时将docker版本降回`ubuntu-ports xenial`源里的`docker.io`了，版本为`17.03.2`，降级后，`docker info`终于一直有响应了。

过了一晚上，第二天再来看，发现有部分pod的健康检查失败，同时exec进pod再exit会卡住，现象如下：

```bash
$ kubectl describe pod some-pod
...
Liveness probe failed. # 健康检查失败
Readiness probe failed. # 健康检查失败
...

$ kubectl exec -ti some-pod -- sh
> exit  # 这里会卡住
```

这次查了下原因，发现是低版本docker的bug，见[bug记录](https://github.com/moby/moby/issues/35091)。

> After some time a container becomes unhealthy (because of "containerd: container not found"). The container is running and accessible but it's not possible to "exec" into it. The container is also marked "unhealthy" because the healhcheck cannot be executed inside the container (same message).
>
> **Steps to reproduce the issue:**
>
> 1. Run a container (success)
> 2. Stop and remove container (success)
> 3. Build new image (success)
> 4. Start the image (success)
> 5. The container is accessible but is unhealty and it's not possible to "exec" into it

官方建议将docker升级至`17.12`之后，于是将docker升级至`17.12.1-ce`，问题终于解决。

### kubelet的问题

今天下午又发现kubelet调度pod异常缓慢，kubelet的日志里疯狂打印以下的报错：

```bash
E0521 16:45:28.353927   58235 kubelet_volumes.go:140] Orphaned pod "xxxxxx" found, but volume paths are still present on disk : There were a total of 1 errors similar to this. Turn up verbosity to see them.
```

查了下发现是kubernetes的bug，见[bug记录](https://github.com/kubernetes/kubernetes/issues/60987)，官方还没有将这个bug的PR合进主干代码，不过还好找到阿里容器服务提供的一个[Workaround方法](https://raw.githubusercontent.com/AliyunContainerService/kubernetes-issues-solution/master/kubelet/kubelet.sh)，简单改了下这个脚本，将其加入cron定时任务即可。

### etcd的问题

之前发现创建了一个deployment，但一直没有pod产生出来，查到etcd服务日志中有大量下面的报错：

```bash
2018-10-22 11:22:16.364641 W | etcdserver: read-only range request "key:\"xxx\" range_end:\"xxx\" " with result "range_response_c
ount:xx size:xxx" took too long (117.026891ms) to execute
```

查到了相关的[bug记录](https://github.com/kubernetes/kubernetes/issues/70082)，说是可能是磁盘性能太差导致的。又查了etcd的文档，其中有[如下说明](https://coreos.com/etcd/docs/latest/faq.html#performance) ：

> Usually this issue is caused by a slow disk. The disk could be experiencing contention among etcd and other applications, or the disk is too simply slow (e.g., a shared virtualized disk). To rule out a slow disk from causing this warning, monitor backend_commit_duration_seconds (p99 duration should be less than 25ms)
>
> The second most common cause is CPU starvation. If monitoring of the machine’s CPU usage shows heavy utilization, there may not be enough compute capacity for etcd. Moving etcd to dedicated machine, increasing process resource isolation cgroups, or renicing the etcd server process into a higher priority can usually solve the problem.

再查了下系统的iowait，果然很高，最后挂了一个独立的磁盘，专门用于etcd服务的数据存储，问题得到好转。

### flannel的问题

kubernetes在运行时，偶然发现flannel的pod因为OOM被Killed掉了，在该pod重启的过程中此node节点上的服务其它节点均不可访问。

查了下，发现官方的[bug记录](https://github.com/coreos/flannel/issues/963)。解决办法就是增加pod使用的资源限制：

```yaml
        resources:
          limits:
            cpu: 100m
            memory: 256Mi # 默认为50Mi，增大这个数据
          requests:
            cpu: 100m
            memory: 50Mi
```

## 总结

虽说现在容器平台蒸蒸日上，但还是有不少坑待我们去趟的，我辈须努力啊。

## 参考

1. https://github.com/moby/moby/issues/35091
2. https://xigang.github.io/2018/12/31/Orphaned-pod/
3. https://github.com/kubernetes/kubernetes/issues/60987
4. https://coreos.com/etcd/docs/latest/faq.html#performance
5. https://bingohuang.com/etcd-operation-3/
6. https://github.com/coreos/flannel/issues/963

