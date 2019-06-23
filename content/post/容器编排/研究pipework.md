---
title: 研究pipework
tags:
  - docker
  - pipework
categories:
  - 容器编排
date: 2016-09-01 22:46:00+08:00
---
很早以前就听说过pipework，据说面对一些复杂的网络配置场景，docker自带的网络模式就有些力不从心了，很多人都在用pipework。今天终于能够抽出时间研究一下它。

## docker默认支持的网络模式

除了overlay网络外，docker默认支持4种网络模式，如下：

* host模式，使用--net=host指定，容器和宿主机共用一个Network Namespace。
* container模式，使用--net=container:NAME_or_ID指定，容器和已经存在的一个容器共享一个Network Namespace。
* none模式，使用--net=none指定，容器拥有自己的Network Namespace，但是，并不为Docker容器进行任何网络配置。
* bridge模式，使用--net=bridge指定，默认设置，为容器分配Network Namespace、设置IP等，并将容器连接到一个虚拟网桥上，默认是docker0。

## 祭出pipework

docker默认支持的网络模式，再配合docker的-p选项，一般场景都是可以满足需求，但有时我们就是想把某个固定IP设置到某个容器上，这时pipework就派上用场了。

安装pipework很简单，直接把pipework的源代码clone下来，将pipework这个脚本拷贝至PATH路径即可。

```bash
git clone https://github.com/jpetazzo/pipework.git
cp pipework/pipework /usr/local/bin/
chmod +x /usr/local/bin/pipework
```

这里做个试验

首先创建一个none网络模式的容器

```bash
docker run -ti --rm --name test --net none apline
```

进入容器后，执行ifconfig查看一下，容器里并没有一个网络接口。

再在docker主机上执行pipework命令，当然前提是先在docker主机上创建一个linux bridge网桥br1。

```bash
pipework br1 -i eth0 test 188.188.100.33/24@188.188.100.1
```

此时再在上面那个容器里执行ifconfig查看一下，就可以发现容器里已经有一个网络接口eth0了，并且设置好了IP地址、网关地址等。

这时在docker主机上执行`brctl show br1`就可以看到多了一个网络接口桥接到了br1。

看一看pipework的[官方文档](https://github.com/jpetazzo/pipework#let-the-docker-host-communicate-over-macvlan-interfaces)，其中还有一些高级用法，比如：定制主机上对应的veth peer网络接口名称、直接连接本地的物理网络接口、服务等待网络接口就绪、配置网络接口为DHCP模式、定制网络接口的MAC地址、指定容器至某个VLAN、控制容器内部的路由规则、支持Open vSwitch。

## 研究pipework的原理

pipework是用脚本实现的，因此很方便研究其实现原理。

首先创建一个none网络模式的容器

```bash
docker run -ti --rm --name test --net none apline
```

再在docker主机上执行pipework命令，这里我使用`bash -x`以显示bash的执行过程。

```bash
bash -x /usr/local/bin/pipework br1 -i eth0 test 188.188.100.33/24@188.188.100.1
```

从输出观察，可以看到以下关键过程：

```bash
#首先得到容器进程的pid
DOCKERPID=$(docker inspect '--format={{ .State.Pid }}' test)
#在netns目录下创建至容器网络名字空间的目录链接，方便下面在docker主机上执行ip netns命令对容器的网络名字空间进行操作
rm -f /var/run/netns/31076
ln -s /proc/31076/ns/net /var/run/netns/31076
#获取网桥网络接口上的MTU值
MTU=$(ip link show br1|awk '{print $5}')
#创建一对veth peer链接
ip link add name veth0pl31076 mtu 1500 type veth peer name veth0pg31076 mtu 1500
#将veth peer对的一端桥接至br1
ip link set veth0pl31076 master br1
ip link set veth0pl31076 up
#将veth peer对的另一端放入容器的网络名字空间，并重命名为eth0
ip link set veth0pg31076 netns 31076
ip netns exec 31076 ip link set veth0pg31076 name eth0
#给容器里的eth0网络接口设置IP地址
ip netns exec 31076 ip addr add 188.188.100.33/24 brd 188.188.100.255 dev eth0
#给容器设置默认网关地址
ip netns exec 31076 ip route delete default
ip netns exec 31076 ip link set eth0 up
ip netns exec 31076 ip route replace default via 188.188.100.1
#在容器里向邻居广播arp消息
ip netns exec 31076 arping -c 1 -A -I eth0 188.188.100.33
#删除之前创建的目录链接
rm -f /var/run/netns/31076
```

解释得已经很清楚了。pipework并没有提供反向操作的脚本，了解了其实现原理，我这里顺手写一个

```bash
GUESTNAME=test
CONTAINER_IFNAME=eth0
#首先得到容器进程的pid
DOCKERPID=$(docker inspect '--format={{ .State.Pid }}' $GUESTNAME)
#在netns目录下创建至容器网络名字空间的目录链接，方便下面在docker主机上执行ip netns命令对容器的网络名字空间进行操作
ln -s /proc/$DOCKERPID/ns/net /var/run/netns/$DOCKERPID
#停用容器中$CONTAINER_IFNAME的网络接口
ip netns exec $DOCKERPID ip link set $CONTAINER_IFNAME down
#删除容器网络名字空间中$CONTAINER_IFNAME的网络接口，同时其对应的veth peer链接也将销毁
ip netns exec $DOCKERPID ip link delete $CONTAINER_IFNAME
#删除之前创建的目录链接
rm -f /var/run/netns/$DOCKERPID
```

## 总结

pipework实现原理还是比较简单的，就是利用了veth peer链接对及独立的网络名字空间，这个跟docker的bridge桥接模式是一样的。在本篇里用到的是linux bridge网桥，linux bridge网桥使用起来比较方便，但面对细粒度的网络隔离也不太行，下一步计划研究一下Open vSwitch。



