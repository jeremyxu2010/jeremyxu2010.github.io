---
title: 获取docker容器的主机虚拟网卡
tags:
  - docker
  - netns
categories:
  - 容器编排
date: 2016-09-19 00:51:00+08:00
---
## 起因

今天看到一个做docker开发工程师写的如何[实现docker网络隔离的方案](https://duffqiu.github.io/2016/09/14/docker-network-isolation/)，总的来说就是找到docker容器对应的主机虚拟网卡，然后使用wondershaper或traffic control对虚拟网卡进行流量控制。这个方案还是比较简单的，不过看了下他给出的如何找容器对应的主机虚拟网卡的步骤，觉得还是过于麻烦，而且还依赖于nsenter与ethtool命令，这个感觉不太好，就想着要进行一下这个过程。

## 改进

因为以前看到pipework的源码，对如何操作容器网络还是比较了解的，于是写了个简单脚本完成上述任务

```bash
#首先得到容器进程的pid
CON_PID=$(docker inspect '--format={{ .State.Pid }}' test)
#首先得到容器的命名空间目录
CON_NET_SANDBOX=$(docker inspect '--format={{ .NetworkSettings.SandboxKey }}' test)
#在netns目录下创建至容器网络名字空间的链接，方便下面在docker主机上执行ip netns命令对容器的网络名字空间进行操作
rm -f /var/run/netns/$CON_PID
mkdir -p /var/run/netns
ln -s $CON_NET_SANDBOX /var/run/netns/$CON_PID
#获取主机虚拟网卡ID
VETH_ID=$(ip netns exec $CON_PID ip link show eth0|head -n 1|awk -F: '{print $1}')
#获取主机虚拟网卡名称
VETH_NAME=$(ip link|grep "if${VETH_ID}:"|awk '{print $2}'|awk -F@ '{print $1}')
#最后删除在netns目录下创建的链接
rm -f /var/run/netns/$CON_PID
```

可以看到上述方案比原方案的优点在于仅使用了ip命令，比较简单，可惜原作者的博客没有开放评论权限，我也没法将这个改进办法告诉他。
