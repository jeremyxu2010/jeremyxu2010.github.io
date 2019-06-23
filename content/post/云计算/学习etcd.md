---
title: 学习etcd
tags:
  - etcd
  - python
  - docker
categories:
  - 云计算
date: 2016-08-24 01:24:00+08:00
---
很早之前就听说过etcd，只记得是一个跟zookeeper很类似的东西，可以用来实现分布式锁。但一直没有关心这个东西到底是如何部署的，部署时怎么保证高可用，除了分布式锁外是否还有其它趣的功能。今天下班回家研究了下这个东东，很有收获，这里记录一下。

## 部署

### 创建一个docker主机

由于我本机并没安装etcd，于是想就直接在docker里玩etcd好了，所以先创建一个docker主机。

```bash
docker-machine create --driver virtualbox --engine-registry-mirror=https://xxxxx.mirror.aliyuncs.com etcd-servers
#执行下面的命令拿到这个docker主机的ip，假设是192.168.99.100
docker-machine ip etcd-servers
#设置好使用docker命令依赖的环境变量
eval $(docker-machine env etcd-servers)
```

### etcd发现创建etcd集群

为了保证etcd服务的高可用性，我决定还是创建一个etcd服务集群。官方文档里讲到了三种方式：静态、etcd发现、DNS发现。见[这里](https://github.com/coreos/etcd/blob/master/Documentation/op-guide/clustering.md#static)。我感觉静态方式必须全都预先规划好才行，而DNS发现依赖于可控的域名解析服务，这些都挺不灵活的。所以最终还是选择了etcd发现的方式创建etcd集群。

首先创建一个单节点的etcd服务

```bash
docker run --rm -p 2380:2380 -p 2379:2379 --name etcd0 quay.io/coreos/etcd etcd --name etcd0 --initial-advertise-peer-urls http://192.168.99.100:2380 --listen-peer-urls http://0.0.0.0:2380 --advertise-client-urls http://192.168.99.100:2379 --listen-client-urls http://0.0.0.0:2379 --initial-cluster etcd0=http://192.168.99.100:2380
```

生成一个唯一的UUID

```bash
#假设生成的UUID为C7167DFB-6031-443B-9ED5-01DC3815F720
uuidgen
```

在单节点的etcd服务上创建集群服务发现的目录，并配置成当3个节点加入集群，整个集群开始启动。

```bash
curl -X PUT http://192.168.99.100:2379/v2/keys/discovery/C7167DFB-6031-443B-9ED5-01DC3815F720/_config/size -d value=3
```

分别启动三个etcd服务节点，并加入集群，当然这里只是试验，正常部署场景为了保证高可用，避免单点故障，集群节点需要部署在多台机器上。

```bash
docker run --restart=always -d -p 2382:2382 -p 2381:2381 --name etcd1 quay.io/coreos/etcd etcd --name etcd1 --initial-advertise-peer-urls http://192.168.99.100:2382 \
  --listen-peer-urls http://0.0.0.0:2382 \
  --listen-client-urls http://0.0.0.0:2381 \
  --advertise-client-urls http://192.168.99.100:2381 \
  --discovery http://192.168.99.100:2379/v2/keys/discovery/C7167DFB-6031-443B-9ED5-01DC3815F720

docker run --restart=always -d -p 2384:2384 -p 2383:2383 --name etcd2 quay.io/coreos/etcd etcd --name etcd2 --initial-advertise-peer-urls http://192.168.99.100:2384 \
  --listen-peer-urls http://0.0.0.0:2384 \
  --listen-client-urls http://0.0.0.0:2383 \
  --advertise-client-urls http://192.168.99.100:2383 \
  --discovery http://192.168.99.100:2379/v2/keys/discovery/C7167DFB-6031-443B-9ED5-01DC3815F720

docker run --restart=always -d -p 2386:2386 -p 2385:2385 --name etcd3 quay.io/coreos/etcd etcd --name etcd3 --initial-advertise-peer-urls http://192.168.99.100:2386 \
  --listen-peer-urls http://0.0.0.0:2386 \
  --listen-client-urls http://0.0.0.0:2385 \
  --advertise-client-urls http://192.168.99.100:2385 \
  --discovery http://192.168.99.100:2379/v2/keys/discovery/C7167DFB-6031-443B-9ED5-01DC3815F720
```

稍等一小会儿，然后就可以检查集群的运行状态了。

```bash
docker run --rm --name etcdctl quay.io/coreos/etcd etcdctl --endpoints http://192.168.99.100:2381,http://192.168.99.100:2383,http://192.168.99.100:2385 member list
#上述命令的输出一般为下面这样，表示其中有一个节点已被选举为Leader了
#294e0faabf651c4: name=etcd1 peerURLs=http://192.168.99.100:2382 clientURLs=http://192.168.99.100:2381 isLeader=false
#74afde18c4466428: name=etcd2 peerURLs=http://192.168.99.100:2384 clientURLs=http://192.168.99.100:2383 isLeader=false
#f979555993d104ee: name=etcd3 peerURLs=http://192.168.99.100:2386 clientURLs=http://192.168.99.100:2385 isLeader=true

docker run --rm --name etcdctl quay.io/coreos/etcd etcdctl --endpoints http://192.168.99.100:2381,http://192.168.99.100:2383,http://192.168.99.100:2385 cluster-health
#上述命令的输出一般为下面这样，表示集群是健康的
#member 294e0faabf651c4 is healthy: got healthy result from http://192.168.99.100:2381
#member 74afde18c4466428 is healthy: got healthy result from http://192.168.99.100:2383
#member f979555993d104ee is healthy: got healthy result from http://192.168.99.100:2385
#cluster is healthy
```

然后就可以把先前创建的单节点etcd服务停止了

```bash
docker stop etcd0
docker rm etcd0
```

后续可参考官方文档对集群作进一步调整，如增删成员节点，见[官方文档](https://github.com/coreos/etcd/blob/master/Documentation/op-guide/runtime-configuration.md)

## 使用etcd集群

etcd通过HTTP API对外提供服务，同时etcd还提供了一个etcdctl的命令，使用也很简单，就里就不重复描述了。可参考[这里](http://cizixs.com/2016/08/02/intro-to-etcd)。

python版本的etcd客户端在[这里](https://github.com/jplana/python-etcd)，使用方法也很简单，项目首页文档写得很清楚。

搭建docker swarm集群如要使用etcd作为外部配置存储服务，可在docker daemon的启动参数里加入`–cluster-store=etcd://${etcd服务所在主机IP}:2379/store -–cluster-advertise=${docker daemon服务所在主机外部可访问IP}:2376`

## 总结

* etcd相对于consul来看，提供了更多的访问方式，特别是HTTP API服务，对于调试问题来说很方便。之前搭建docker swarm集群使用的是consul，后面找个机会尝试一下使用etcd。
* 翻阅etcd文档后，发现etcd提供的功能比我数年前见到的zookeeper功能丰富了不少，很强大。以后项目中如果遇到分布式锁、监听变更事件、监测主机alive场景，可以考虑使用它。

## 参考

`http://soft.dog/2016/02/16/etcd-cluster/#section-7`
`http://www.alauda.cn/2016/01/18/docker-1-9-network/`
`https://github.com/jplana/python-etcd`
`https://coreos.com/etcd/docs/latest/docker_guide.html`
`https://github.com/coreos/etcd/blob/master/Documentation/dev-internal/discovery_protocol.md`
`https://github.com/coreos/etcd/blob/master/Documentation/op-guide/runtime-configuration.md`
`https://github.com/coreos/etcd/blob/master/Documentation/op-guide/clustering.md#static`
`https://coreos.com/etcd/docs/latest/configuration.html#member-flags`
`https://skyao.gitbooks.io/leaning-etcd3/content/`
`http://dockone.io/article/801`
