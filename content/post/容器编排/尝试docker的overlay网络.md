---
title: 尝试docker的overlay网络
tags:
  - docker
  - sdn
categories:
  - 容器编排
date: 2016-08-29 00:41:00+08:00
---
docker搭建起集群后，跨主机的容器相互之间通信就要另想方案了。幸好docker1.9之后内置了跨节点通信技术Overlay网络，这里将使用方法简单示例一下以备忘。

下面的操作还是在上周搭建的docker集群中进行，集群的搭建见[这里](/2016/08/24/%E9%87%8D%E6%90%ADdocker%E9%9B%86%E7%BE%A4/)。

## 解决docker集群遗留问题


上周搭建的docker集群还有一个小问题

* 每次所有docker主机再启动后，docker主机内部通信的网络接口地址有很大可能发生变化，这个会造成docker集群无法达到健康状态。搜索了下，找到一个简单办法将virtualbox创建的docker主机ip固定下来。

```bash
#ssh登入一台docker主机
docker-machine ssh node1

#创建bootsync.sh文件，里面杀死dhcp客户端进程，并静态设置docker主机ip地址，注意不同的docker主机要设置不同的IP地址
sudo echo "
if [ -f /var/run/udhcpc.eth1.pid ] ; then
       	kill $(more /var/run/udhcpc.eth1.pid)
fi
ifconfig eth1 192.168.99.104 netmask 255.255.255.0 broadcast 192.168.99.255 up" > /var/lib/boot2docker/bootsync.sh

#设置bootsync.sh文件可执行权限，docker主机启动时会执行该文件
chmod +x /var/lib/boot2docker/bootsync.sh
```
集群中所有docker主机重启一次。

* etcd服务的3个节点不能随docker主机的启动而启动。搜索了下，找一个简单办法在docker daemon启动后自动启动3个etcd容器。

```bash
sudo echo "
sleep 5
/usr/local/bin/docker start etcd1 etcd2 etcd3" > /var/lib/boot2docker/bootlocal.sh

#设置bootlocal.sh文件可执行权限，docker daemon启动后会执行该文件
chmod +x /var/lib/boot2docker/bootlocal.sh
```

## 创建overlay网络并使用它

连入docker集群

```bash
eval $(docker-machine env --swarm node1)
```

创建名称为ovr0的overlay网络并验证ovr0网络的信息

```bash
docker network create --driver=overlay ovr0
docker network inspect ovr0
```

创建两个容器试验一下

```bash
docker run -ti --rm --name alpine1 --net ovr0 alpine /bin/sh
docker run -ti --rm --name alpine2 --net ovr0 alpine /bin/sh
docker ps
...
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
137b0fa48ad9        alpine              "/bin/sh"           5 seconds ago       Up 4 seconds                            node4/alpine2
67ed2ad7d8aa        alpine              "/bin/sh"           9 seconds ago       Up 8 seconds                            node3/alpine1
...
```

上面可以看到这两个容器是创建在node3, node4两个docker主机上的。

再验证一下ovr0网络的信息
```bash
docker network inspect ovr0
...
[
    {
        "Name": "ovr0",
        "Id": "f86789f2d9575830b57aae8385bcd02e76b342b466c677c8aa02c2557e3eacb3",
        "Scope": "global",
        "Driver": "overlay",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "10.0.0.0/24",
                    "Gateway": "10.0.0.1/24"
                }
            ]
        },
        "Internal": false,
        "Containers": {
            "137b0fa48ad9df084afda45fd88f3312d481dafade0cc758f177761babd5f262": {
                "Name": "alpine2",
                "EndpointID": "860c6930714e41ebbe03315525c8c07f67119f1ececf05f2d15c3c0da4d28d62",
                "MacAddress": "02:42:0a:00:00:03",
                "IPv4Address": "10.0.0.3/24",
                "IPv6Address": ""
            },
            "67ed2ad7d8aaa1447d8e4d97782e917e544e18be283dee5c471425087d2d6639": {
                "Name": "alpine1",
                "EndpointID": "aa3bdff0cd7a6dc81e9df89241768b7ff21ef6b3010c96f291bd1a927e82a233",
                "MacAddress": "02:42:0a:00:00:02",
                "IPv4Address": "10.0.0.2/24",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {}
    }
]
...
```

可以看到两个容器均接入到了ovr0这网络，ip分别是10.0.0.2与10.0.0.3。

同时在两个容器里ping对方的主机名，均可正常ping通。

```bash
ping alpine2
PING alpine2 (10.0.0.3): 56 data bytes
64 bytes from 10.0.0.3: seq=0 ttl=64 time=0.686 ms
64 bytes from 10.0.0.3: seq=1 ttl=64 time=0.677 ms
```

同时再检查docker集群上所有的网络，发现node3、node4两个节点上多出了两个网络node3/docker_gwbridge、node4/docker_gwbridge。初步估计是overlay网络底层实现时依赖的桥接网络。

```bash
docker network ls

NETWORK ID          NAME                    DRIVER
72afcd321dca        node1/bridge            bridge
109efe6a8422        node1/host              host
93162425725b        node1/none              null
0225062d4555        node2/bridge            bridge
9889390b8909        node2/host              host
cf303662cde0        node2/none              null
34f56fd67dcc        node3/bridge            bridge
0d91c9626d8f        node3/docker_gwbridge   bridge
52fa10224530        node3/host              host
8f3212e00813        node3/none              null
c9f525cd4380        node4/bridge            bridge
787ce948a501        node4/docker_gwbridge   bridge
853b5214d03a        node4/host              host
1e1e88ef6e50        node4/none              null
f86789f2d957        ovr0                    overlay
```

另外如果想某个容器断开某网络，可执行下面的命令

```bash
docker network disconnect ovr0 alpine1
```

disconnect之后，容器中与这个网络相关的网络接口立马就消失了，同时在同一网络的其它的主机即不可ping通该容器主机名。

如果又想将某个容器连接某网络，可执行下面的命令

```bash
docker network connect ovr0 alpine1
```

connect之后，容器中将会出现与这个网络相关的网络接口，同时在同一网络的其它的主机即可ping通该容器主机名。

## 总结

docker的overlay网络使用起来还是比较方便的，但如果要给容器配上固定的外部访问IP还是有点麻烦，后面准备研究一下[pipework](https://github.com/jpetazzo/pipework)的用法。

## 参考

`http://www.alauda.cn/2016/01/18/docker-1-9-network/`
`https://github.com/docker/machine/issues/1709`
`https://github.com/boot2docker/boot2docker/blob/master/rootfs/rootfs/bootscript.sh`
