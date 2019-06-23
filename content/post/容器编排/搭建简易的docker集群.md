---
title: 搭建简易的docker集群
tags:
  - linux
  - docker
categories:
  - 容器编排
date: 2016-06-29 02:27:00+08:00
---
今天又抽时间研究了一下如何搭建docker集群，终于找到配合`consul`、`docker-machine`、`swarm`搭建一个简易docker集群的办法，在这里记录一下。

## 创建一个consul数据库

首先需要创建一个用于swarm集群节点服务发现、健康检测的consul数据库。

```bash
#这里`https://xxxx.mirror.aliyuncs.com`参见上一篇文件里所提及的阿里云registry加速地址
docker-machine create -d virtualbox --engine-registry-mirror=https://xxxx.mirror.aliyuncs.com consul-servers
#设置docker命令连接consul-servers依赖的环境变量
eval $(docker-machine env consul-servers)
#启动第一个consul server节点容器
docker run --name consul-server1 --restart=always -d progrium/consul -server -bootstrap-expect 3 -ui-dir /ui
JOIN_IP=$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' consul-server1)
#启动第二个consul server节点容器，并加入consul集群中
docker run -d --name consul-server2 -h consul-server2 progrium/consul -server -join $JOIN_IP
#启动第三个consul server节点容器，并加入consul集群中
docker run -d --name consul-server3 -h consul-server3 progrium/consul -server -join $JOIN_IP
#启动第一个consul client节点容器，并加入consul集群中
docker run -d --restart=always -p 8400:8400 -p 8500:8500 -p 8600:53/udp --name consul-client1 -h consul-client1 progrium/consul -join $JOIN_IP
#启动第二个consul client节点容器，并加入consul集群中
docker run -d --restart=always -p 8401:8400 -p 8501:8500 -p 8601:53/udp --name consul-client2 -h consul-client2 progrium/consul -join $JOIN_IP
```

这里解释一下启动容器时的一些参数
`--name consul` 指定容器的名称为consul
`--restart=always` 指定当容器退出时自动重启
`-p 8400:8400` 将容器的8400端口映射至docker host的8400端口，这个是consul的RPC端口
`-p 53:53/udp` 将容器的UDP 53端口映射至docker host的UDP 53端口，这个是consul内置的DNS Server端口
`-d` 容器放在后台运行
`-server` consul在容器里以server模式运行
`-bootstrap-expect 3` 至少3个consul agent接入进来，则认为可以开始自启动了，设置集群当前状态为可工作。
`-p 8500:8500` 将容器的8500端口映射至docker host的8500端口，这个是consul的HTTP端口
`-ui-dir /ui` 启用consul的[WebUI](http://www.consul.io/intro/getting-started/ui.html)，访问地址为`http://${docker_host_ip}:8500`

## 创建swarm主节点

理论上这时应该开始创建`swarm`相关节点了，并将`swarm`相关节点加入到`swarm`集群了。但研究`docker-machine`的命令行参数，发现它其实支持一条命令自动创建。

```bash
#首先拿到`consul-servers`这个docker host IP地址，假设拿到的IP地址为${consul_client_ip}
docker-machine ip consul-servers
#创建swarm第一个主节点，swarm agent节点，并告知swarm使用consul的集群节点发现服务
docker-machine create -d virtualbox --engine-registry-mirror=https://xxxx.mirror.aliyuncs.com --swarm --swarm-master
--swarm-opt="replication"
--swarm-discovery="consul://${consul_client_ip}:8500" --engine-opt="cluster-store=consul://${consul_client_ip}:8500" --engine-opt="cluster-advertise=eth1:2376" swarm-master1
#创建swarm第二个主节点，swarm agent节点，并告知swarm使用consul的集群节点发现服务
docker-machine create -d virtualbox --engine-registry-mirror=https://xxxx.mirror.aliyuncs.com --swarm --swarm-master
--swarm-opt="replication"
--swarm-discovery="consul://${consul_client_ip}:8500" --engine-opt="cluster-store=consul://${consul_client_ip}:8500" --engine-opt="cluster-advertise=eth1:2376" swarm-master2
```

这里解释一下上面创建docker host的命令
`--swarm --swarm-master` 需要在docker host里创建swarm的主节点容器
`--swarm-opt="replication"` 启用swarm主节点之间的复制功能
`--swarm-discovery="consul://${consul_client_ip}:8500"` 指定swarm所使用的集群节点发现服务地址为`consul://${consul_client_ip}:8500`
`--engine-opt="cluster-store=consul://${consul_client_ip}:8500"` 设置`docker host`所使用的集群KV数据库地址`cluster-store=consul://${consul_client_ip}:8500`

最后我们看一眼这个`docker host`上的容器列表

```bash
$ > eval $(docker-machine env swarm-master1)
$ > docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
ba1ed23055bf        swarm:latest        "/swarm join --advert"   About an hour ago   Up About an hour                        swarm-agent
aff1d873fafc        swarm:latest        "/swarm manage --tlsv"   About an hour ago   Up About an hour                        swarm-agent-master
```

很清楚吧，一个是swarm-agent容器，一个是swarm-master容器。

## 再创建一个swarm节点

```bash
docker-machine create -d virtualbox --engine-registry-mirror=https://xxxx.mirror.aliyuncs.com --swarm --swarm-discovery="consul://${consul_client_ip}:8501" --engine-opt="cluster-store=consul://${consul_client_ip}:8501" --engine-opt="cluster-advertise=eth1:2376" swarm-node1
```

上述命令就不解释了，直接看创建的容器吧

```bash
$ > eval $(docker-machine env swarm-node1)
$ > docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
527d83c7d1a9        swarm:latest        "/swarm join --advert"   About an hour ago   Up About an hour                        swarm-agent
```
## 检查docker集群

docker集群创建好了，用docker客户端连上去查看一下集群的状况。

```bash
$ > eval $(docker-machine env --swarm swarm-master1)
$ > docker info
Containers: 5
 Running: 5
 Paused: 0
 Stopped: 0
Images: 3
Server Version: swarm/1.2.3
Role: primary
Strategy: spread
Filters: health, port, containerslots, dependency, affinity, constraint
Nodes: 3
 swarm-master1: 192.168.99.109:2376
  └ ID: XTQ5:VQY2:OA7Y:NJ3E:6IOV:IJEA:WGCR:YQO4:4Z7L:WZOO:T3MH:BXLE
  └ Status: Healthy
  └ Containers: 2
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=, kernelversion=4.4.12-boot2docker, operatingsystem=Boot2Docker 1.11.2 (TCL 7.1); HEAD : a6645c3 - Wed Jun  1 22:59:51 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ UpdatedAt: 2016-06-29T15:50:13Z
  └ ServerVersion: 1.11.2
 swarm-master2: 192.168.99.110:2376
  └ ID: EDG6:QK6E:EWY5:SKJK:Y2KI:YURB:C3LV:2WDR:THNP:A5VB:WLQZ:2G4S
  └ Status: Healthy
  └ Containers: 2
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=, kernelversion=4.4.12-boot2docker, operatingsystem=Boot2Docker 1.11.2 (TCL 7.1); HEAD : a6645c3 - Wed Jun  1 22:59:51 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ UpdatedAt: 2016-06-29T15:50:10Z
  └ ServerVersion: 1.11.2
 swarm-node1: 192.168.99.111:2376
  └ ID: CD43:U7OL:FIZI:Y753:RBHU:65SL:ZEXK:RIUI:HJTE:UTUG:J3IB:TUAT
  └ Status: Healthy
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 1.021 GiB
  └ Labels: executiondriver=, kernelversion=4.4.12-boot2docker, operatingsystem=Boot2Docker 1.11.2 (TCL 7.1); HEAD : a6645c3 - Wed Jun  1 22:59:51 UTC 2016, provider=virtualbox, storagedriver=aufs
  └ UpdatedAt: 2016-06-29T15:50:36Z
  └ ServerVersion: 1.11.2
Plugins:
 Volume:
 Network:
Kernel Version: 4.4.12-boot2docker
Operating System: linux
Architecture: amd64
CPUs: 3
Total Memory: 3.063 GiB
Name: swarm-master1
Docker Root Dir:
Debug mode (client): false
Debug mode (server): false
WARNING: No kernel memory limit support
```

这里要注意`docker-machine env --swarm swarm-master1`，如果不加`--swarm`参数，则是设置连接`swarm-master1`这个`docker host`的环境变量，加了`--swarm`参数，则是设置连接swarm集群的环境变量。

## 注意事项

* 本方案中考虑了consul集群中consul server节点的单点故障问题，创建了多个consul server节点，如其中有某个consul server节点出现故障，会自动选举出一个新的Leader consul server节点
* 本方案中通过多个consul client节点减少转发请求至consul server节点的延时及资源消耗，同时也确保部分consul client节点出现故障不会导致整个consul集群不可用
* 本方案中考虑了swarm集群中swarm manager节点单点故障问题，创建了两个互相复制的swarm manager节点，一旦发觉其中一个出现故障，可很方便地连接另一个swarm manager节点进行操作
* 在正式生产环境里不会将所有consul节点都部署在一个docker host里。为了确保consul server节点不出现单点故障，一般创建3-5个consul server节点，并将consul server节点部署在不同的docker host里。为了通过多个consul client节点减少转发请求至consul server节点的延时及资源消耗，一般在一个数据中心会在不同的docker host上部署多个consul client节点，一个数据中心的所有swarm节点分成几组，每组里面的所有swarm节点使用一个consul client地址
* 我自己研究是在一台物理机上使用`docker-machine`开设多个virtualbox虚机来模拟集群环境的，而如果不指定其它参数，默认docker daemon创建的容器是使用docker0虚拟交换机实现网接接入的。docker0默认仅保证单机上的容器是可通信。而一般真实环境是多个主机上建立集群的，所以可能需要采用划分独立的网段、组VLAN、基于SDN等方式确保多个主机本身可通信，同时在创建`docker host`时需合理指定`cluster-advertise=eth1:2376`参数
* 目前看到简单实现跨主机实现容器间联通有两种方案，一种是自定义Docker Daemon启动时的桥接网桥，见[这里](http://wiki.jikexueyuan.com/project/docker-technology-and-combat/container_connect.html)；另一种是使用Overlay Network，见[这里](http://www.dockone.io/article/840)。我个人是更倾向于后一种，网络安全性更可控一点，只是不知道性能如何，需实际应用场景测试一下。
* 在使用swarm集群时，还可以自定义调度策略及选择节点的逻辑，可参考《Docker-从入门到实践》书中介绍的“Docker Swarm项目 - 调度器“，“Docker Swarm项目 - 过滤器“

## 其它集群方式

事实上还是比我这个教程更简单的docker集群创建办法，可参考《Docker-从入门到实践》书中介绍的“Docker Swarm项目 - 使用DockerHub提供的服务发现功能”、“Docker Swarm项目 - 使用文件”这两个章节，但这两个办法存在比较致命的缺陷。第一个方法要求docker集群能通畅地连结国外的DockerHub服务；第2个方法不能很好适合集群节点的动态变更。所以这两种方法都不建议生产环境使用。

## 参考

* `https://docs.docker.com/v1.10/engine/reference/commandline/daemon/`
* `http://dockone.io/article/667`
* `http://dockone.io/article/1298`
* `http://yunshen0909.iteye.com/blog/2245926`



