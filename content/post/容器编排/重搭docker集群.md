---
title: 重搭docker集群
tags:
  - docker
  - etcd
categories:
  - 容器编排
date: 2016-08-24 23:39:00+08:00
---
以前尝试使用consul搭建了docker集群，当时对底层为什么要执行那些命令不是太理解，直到昨天研究了etcd集群之后，终于对docker集群搭建时的一些命令有了新的认识。今天尝试配合etcd搭建docker集群，以这里记录以备忘。

## 创建docker swarm集群mange节点

还是使用上一篇文章里搭建好的etcd集群服务，其地址为`http://192.168.99.100:2381,http://192.168.99.100:2383,http://192.168.99.100:2385`

```bash
docker-machine create -d virtualbox --engine-registry-mirror=https://xxx.mirror.aliyuncs.com --swarm --swarm-master --swarm-opt="replication" --swarm-discovery="etcd://192.168.99.100:2381" --engine-opt="cluster-store=etcd://192.168.99.100:2381" --engine-opt="cluster-advertise=eth1:2376" node1
```

这里解释一下这条命令：
* `--swarm`指定了创建docker主机时开启swarm集群功能
* `--swarm-master`指定了创建docker主机后要在docker主机里运行一个swarm manage的docker容器
* `--swarm-opt="replication"` 启用swarm manage节点之间的复制功能
* `--swarm-discovery="etcd://192.168.99.100:2381"`指定swarm集群所使用的发现服务地址
* `--engine-opt="cluster-store=etcd://192.168.99.100:2381"` docker引擎所使用的KV存储服务地址
* `--engine-opt="cluster-advertise=eth1:2376"` swarm集群里该节点向外公布的服务地址。这里为什么是eth1，刚开始我也觉得很奇怪，后来我使用`docker-machine ssh node1`登入docker主机，再执行ifconfig才发现使用docker-machine创建的docker主机一般eth1为外部可访问的网络接口。

为了避免swarm集群manage节点的单点故障，这里再创建一个manage节点

```bash
docker-machine create -d virtualbox --engine-registry-mirror=https://xxx.mirror.aliyuncs.com --swarm --swarm-master --swarm-opt="replication" --swarm-discovery="etcd://192.168.99.100:2381" --engine-opt="cluster-store=etcd://192.168.99.100:2381" --engine-opt="cluster-advertise=eth1:2376" node2
```

## 创建docker swarm集群普通节点

```bash
docker-machine create -d virtualbox --engine-registry-mirror=https://xxx.mirror.aliyuncs.com --swarm --swarm-discovery="etcd://192.168.99.100:2381" --engine-opt="cluster-store=etcd://192.168.99.100:2381" --engine-opt="cluster-advertise=eth1:2376" node3

docker-machine create -d virtualbox --engine-registry-mirror=https://xxx.mirror.aliyuncs.com --swarm --swarm-discovery="etcd://192.168.99.100:2381" --engine-opt="cluster-store=etcd://192.168.99.100:2381" --engine-opt="cluster-advertise=eth1:2376" node4
```

这里创建了两个docker swarm集群普通节点

## 检查swarm集群的状况

docker集群创建好了，用docker客户端连上去查看一下集群的状况。

```bash
eval $(docker-machine env --swarm node2)
docker info

Containers: 6
 Running: 6
 Paused: 0
 Stopped: 0
Images: 4
Server Version: swarm/1.2.5
Role: replica
Primary: 192.168.99.104:3376
Strategy: spread
Filters: health, port, containerslots, dependency, affinity, constraint
Nodes: 4
 node1: 192.168.99.104:2376
  └ ID: A77F:BLVI:ZVRM:7RIL:XHGX:5K4F:OO3I:MPTE:JVJU:IBK2:NIPM:LDRJ
  └ Status: Healthy
  └ Containers: 2 (2 Running, 0 Paused, 0 Stopped)
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: kernelversion=4.4.17-boot2docker, operatingsystem=Boot2Docker 1.12.1 (TCL 7.2); HEAD : ef7d0b4 - Thu Aug 18 21:18:06 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ UpdatedAt: 2016-08-24T15:33:34Z
  └ ServerVersion: 1.12.1
 node2: 192.168.99.105:2376
  └ ID: EGYZ:TXBG:S3AR:W35S:Q3Y5:24GH:NEWN:ZAQP:R7QN:W3KR:VWGQ:YFRH
  └ Status: Healthy
  └ Containers: 2 (2 Running, 0 Paused, 0 Stopped)
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: kernelversion=4.4.17-boot2docker, operatingsystem=Boot2Docker 1.12.1 (TCL 7.2); HEAD : ef7d0b4 - Thu Aug 18 21:18:06 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ UpdatedAt: 2016-08-24T15:33:07Z
  └ ServerVersion: 1.12.1
 node3: 192.168.99.106:2376
  └ ID: OJAQ:GLMP:2LKC:6PSU:JYT6:DOGM:O5LA:IAS3:EZYG:G5NV:ON3F:76TF
  └ Status: Healthy
  └ Containers: 1 (1 Running, 0 Paused, 0 Stopped)
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: kernelversion=4.4.17-boot2docker, operatingsystem=Boot2Docker 1.12.1 (TCL 7.2); HEAD : ef7d0b4 - Thu Aug 18 21:18:06 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ UpdatedAt: 2016-08-24T15:33:00Z
  └ ServerVersion: 1.12.1
 node4: 192.168.99.107:2376
  └ ID: W6EL:DUI6:LWEV:T55B:YJ2O:GBIQ:S3CA:GAKD:OMC7:YBVE:NKE4:TT4U
  └ Status: Healthy
  └ Containers: 1 (1 Running, 0 Paused, 0 Stopped)
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: kernelversion=4.4.17-boot2docker, operatingsystem=Boot2Docker 1.12.1 (TCL 7.2); HEAD : ef7d0b4 - Thu Aug 18 21:18:06 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ UpdatedAt: 2016-08-24T15:33:23Z
  └ ServerVersion: 1.12.1
Plugins:
 Volume:
 Network:
Kernel Version: 4.4.17-boot2docker
Operating System: linux
Architecture: amd64
CPUs: 4
Total Memory: 4.085 GiB
Name: 7d436f0f312b
Docker Root Dir:
Debug mode (client): false
Debug mode (server): false
WARNING: No kernel memory limit support
```

Over，一个四节点的docker集群就这么简单的搭建好了。


## 下一步计划

参照`http://www.alauda.cn/2016/01/18/docker-1-9-network/`研究一下容器网络模型（Container Network Model，简称CNM），同时研究一下实际场景中如何使用[pipework](https://github.com/jpetazzo/pipework)来灵活地定制容器的网络。







