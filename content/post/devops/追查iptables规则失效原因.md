---
title: 追查iptables规则失效原因
tags:
  - iptables
  - netfilter
categories:
  - devops
date: 2018-10-13 22:50:00+08:00
---

今天在工作中用到了一条iptables规则，虽然明白这条规则的意思，但结合之前对iptables的理解，想不明白为什么会这么工作，后来仔细研读iptables的官方文档，终于从字里行间找到原因了，这里记录下问题的追踪过程。

## 现象

工作中用到了一条iptables规则，如下：

```bash
$ iptables -t nat -I OUTPUT 1 -p tcp -j REDIRECT --to-port 9999
```

这条规则的意思是从本机发出的数据包都重定向到本地的9999端口。

当前的防火墙规则如下：

```bash
$ iptables -t nat -L -n --line-numbers
Chain PREROUTING (policy ACCEPT)
num  target     prot opt source               destination

Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination
1    REDIRECT   tcp  --  0.0.0.0/0            0.0.0.0/0            redir ports 9999

Chain POSTROUTING (policy ACCEPT)
num  target     prot opt source               destination

$ iptables -t filter -L -n --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination

Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination
```

那么我提出了一个问题，如果在本机上跑一个程序监听8888端口，那么外部还可以正常连接该端口吗？

```bash
$ python -m SimpleHTTPServer 8888
# 那么从其它机器还可以正常访问它的8888端口吗？
curl http://$host_ip:8888
```

我最开始的判断是不能，但经过实测发现是可以的。

## 我的推导过程

数据包在netfilter中的流转可参考下图：

![image-20181014012501981](http://blog-images-1252238296.cosgz.myqcloud.com/image-20181014012501981.png)

TCP连接的建立过程参照下图：

![image-20181014012627013](http://blog-images-1252238296.cosgz.myqcloud.com/image-20181014012627013.png)

由上述两图可知，curl命令发送HTTP请求至服务端，首先得建立TCP连接，而建立TCP连接的过程，客户端先向服务器发送了一个SYN包，服务端要回一个SYN+ACK包，但这个回应数据包会经过NAT表的OUTPUT链：

![image-20181014013039823](http://blog-images-1252238296.cosgz.myqcloud.com/image-20181014013039823.png)

而NAT表的OUTPUT链中第一条规则就是将这个数据重定向到本机9999端口，而本机的9999端口现在并没有任何程序在监听，因而这个数据包就丢了，而客户端收不到SYN+ACK包，连TCP连接都建立不了，更谈不上进行HTTP协议的其它处理。

现在现象并不是这样的，因而一定是哪儿推导出现问题了。

## 日志诊断

再添加几条规则打印出日志分析看看：

```bash
iptables -t nat -I OUTPUT 1 -p tcp --sport 8888 -j LOG --log-prefix 'nat-output-log '
iptables -t filter -I OUTPUT 1 -p tcp --sport 8888 -j LOG --log-prefix 'filter-output-log '
```

再发起curl请求，检查下打印的日志：

```bash
$ cat /var/log/messages | grep 'output-log'
Oct 13 13:45:28 centos-linux kernel: filter-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=10.211.55.2 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=8888 DPT=60181 WINDOW=28960 RES=0x00 ACK SYN URGP=0
Oct 13 13:45:28 centos-linux kernel: filter-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=10.211.55.2 LEN=52 TOS=0x00 PREC=0x00 TTL=64 ID=14590 DF PROTO=TCP SPT=8888 DPT=60181 WINDOW=227 RES=0x00 ACK URGP=0
Oct 13 13:45:28 centos-linux kernel: filter-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=10.211.55.2 LEN=69 TOS=0x00 PREC=0x00 TTL=64 ID=14591 DF PROTO=TCP SPT=8888 DPT=60181 WINDOW=227 RES=0x00 ACK PSH URGP=0
Oct 13 13:45:28 centos-linux kernel: filter-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=10.211.55.2 LEN=89 TOS=0x00 PREC=0x00 TTL=64 ID=14592 DF PROTO=TCP SPT=8888 DPT=60181 WINDOW=227 RES=0x00 ACK PSH URGP=0
Oct 13 13:45:28 centos-linux kernel: filter-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=10.211.55.2 LEN=808 TOS=0x00 PREC=0x00 TTL=64 ID=14593 DF PROTO=TCP SPT=8888 DPT=60181 WINDOW=227 RES=0x00 ACK PSH URGP=0
Oct 13 13:45:28 centos-linux kernel: filter-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=10.211.55.2 LEN=52 TOS=0x00 PREC=0x00 TTL=64 ID=14594 DF PROTO=TCP SPT=8888 DPT=60181 WINDOW=227 RES=0x00 ACK FIN URGP=0
Oct 13 13:45:28 centos-linux kernel: filter-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=10.211.55.2 LEN=52 TOS=0x00 PREC=0x00 TTL=64 ID=2569 DF PROTO=TCP SPT=8888 DPT=60181 WINDOW=227 RES=0x00 ACK URGP=0
```

奇怪，竟然没有nat-output-log的日志，难道NAT表的OUTPUT链失效了？

再在本机访问外部试试：

```bash
$ iptables -t nat -I OUTPUT 1 -p tcp --dport 8888 -j LOG --log-prefix 'nat-output-log '
$ curl http://www.baidu.com:8888
```

这回检查日志，发现nat-output-log的日志又出现了：

```bash
$ cat /var/log/messages | grep 'nat-output-log'
Oct 13 13:53:00 centos-linux kernel: nat-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=14.215.177.39 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=30145 DF PROTO=TCP SPT=35530 DPT=8888 WINDOW=29200 RES=0x00 SYN URGP=0
Oct 13 13:53:00 centos-linux kernel: nat-output-log IN= OUT=eth0 SRC=10.211.55.11 DST=14.215.177.38 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=7296 DF PROTO=TCP SPT=48494 DPT=8888 WINDOW=29200 RES=0x00 SYN URGP=0
```

难道NAT表的OUTPUT链里的规则时灵时不灵？

## 问题分析

仔细研读netfilter的[官方文档](https://netfilter.org/documentation/HOWTO/netfilter-hacking-HOWTO-3.html)发现了下面这句话：

> ### NAT
>
> This is the realm of the `nat' table, which is fed packets from two netfilter hooks: for non-local packets, the NF_IP_PRE_ROUTING and NF_IP_POST_ROUTING hooks are perfect for destination and source alterations respectively. If CONFIG_IP_NF_NAT_LOCAL is defined, the hooks NF_IP_LOCAL_OUT and NF_IP_LOCAL_IN are used for altering the destination of local packets.
>
> ***This table is slightly different from the `filter' table, in that only the first packet of a new connection will traverse the table: the result of this traversal is then applied to all future packets in the same connection.***

原来NAT表里的规则仅针对一条连接的第一个数据包有效。响应回的SYN+ACK包是第2个包，自然不受影响。

为什么会如此了？

想了下终于明白原因了，估计是因为执行效率。因为NAT表里的规则主要是用来进行网络地址转换的，而第一个包经过时已经进行了网络地址转换，连接的信息，包括地址由`a->b`转换为`a->c`这些信息，都已经被conntrack记录下来了。那么接下来如果再过来`a->b`的数据包，只要查查conntrack的记录信息，就可以推出要转成`a-c`，根本不需要再走一遍NAT表里的规则。

又搜索了下，更加证实了我的猜想：

1. https://serverfault.com/questions/741104/iptables-redirect-works-only-for-first-packet

> nat table rules always work only for first packet in connection. Subsequent packets of same connection never traverse nat rule list and only supported by conntrack code
>
> As UDP is connectionless in nature, "connection" here is defined simply by addresses, ports and timeout. So, if second UDP packet with same source port and address and same destination port and address arrives within the timeout, Linux believes it belongs to established "connection" and doensn't evaluate nat rule table for it at all, reusing verdict issued for previous packet.

2. https://blog.csdn.net/dog250/article/details/5692601

> 修改应用层协议控制包使用了ip_conntrack，iptables的REDIRECT target也使用了ip_conntrack，另外包括iptables的state模块也是如此，使用ip_conntrack，可见ip_conntrack的重要性，ip_conntrack的一个无比重要的作用是实现nat，可以说REDIRECT target和对诸如ftp的修改以实现server回连client最终都落实到了nat上，比如，所谓的REDIRECT就是内置一个nat规则，将符合matchs的包nat到本机的特定端口，这个和iptables的nat表原理是一样的，不同的是，nat表的配置是显式的nat，而REDIRECT和ip_nat_ftp是隐式的nat而已。它们都是nat，都依赖于原始的ip_conntrack，因此原始的链接流信息并没有丢失，还是可以得到的，事实上，内核就是通过原始的链接流来匹配nat规则的，如果丢弃了原始链接流信息，何谈匹配！如果一个原始链接是a->b，而后不管是显式的nat还是隐式的REDIRECT以及nat_ftp，将a->b改为了a->c，a->b还是可以得到的，内核正是从a->b的流信息中取得了“要转换为a->c”这个信息的。

至此所有迷题均解开了。

## 复习iptables数据包流程图

最后再复习一遍iptables的数据包流程图。

> **iptables 基本概念**
>
>
>
> 匹配（match）：符合指定的条件，比如指定的 IP 地址和端口。
>
> 丢弃（drop）：当一个包到达时，简单地丢弃，不做其它任何处理。
>
> 接受（accept）：和丢弃相反，接受这个包，让这个包通过。
>
> 拒绝（reject）：和丢弃相似，但它还会向发送这个包的源主机发送错误消息。这个错误消息可以指定，也可以自动产生。
>
> 目标（target）：指定的动作，说明如何处理一个包，比如：丢弃，接受，或拒绝。
>
> 跳转（jump）：和目标类似，不过它指定的不是一个具体的动作，而是另一个链，表示要跳转到那个链上。
>
> 规则（rule）：一个或多个匹配及其对应的目标。
>
> 链（chain）：每条链都包含有一系列的规则，这些规则会被依次应用到每个遍历该链的数据包上。每个链都有各自专门的用途， 这一点我们下面会详细讨论。
>
> 表（table）：每个表包含有若干个不同的链，比如 filter 表默认包含有 INPUT，FORWARD，OUTPUT 三个链。iptables有四个表，分别是：raw，nat，mangle和filter，每个表都有自己专门的用处，比如最常用filter表就是专门用来做包过滤的，而 nat 表是专门用来做NAT的。
>
> 策略（police）：我们在这里提到的策略是指，对于 iptables 中某条链，当所有规则都匹配不成功时其默认的处理动作。
>
> 连接跟踪（connection track）：又称为动态过滤，可以根据指定连接的状态进行一些适当的过滤，是一个很强大的功能，但同时也比较消耗内存资源。
>
>
>
>
>
> **经过iptables的数据包的流程介绍**
>
> 一个数据包到达时,是怎么依次穿过各个链和表的。
>
> ![image-20181014025406085](http://blog-images-1252238296.cosgz.myqcloud.com/image-20181014025406085.png)
>
> 基本步骤如下：
>
> 1. 数据包到达网络接口，比如 eth0。
> 2. 进入 raw 表的 PREROUTING 链，这个链的作用是赶在连接跟踪之前处理数据包。
> 3. 如果进行了连接跟踪，在此处理。
> 4. 进入 mangle 表的 PREROUTING 链，在此可以修改数据包，比如 TOS 等。
> 5. 进入 nat 表的 PREROUTING 链，可以在此做DNAT，但不要做过滤。
> 6. 决定路由，看是交给本地主机还是转发给其它主机。
>
>
>
> 到了这里我们就得分两种不同的情况进行讨论了，一种情况就是数据包要转发给其它主机，这时候它会依次经过：
>
> 7. 进入 mangle 表的 FORWARD 链，这里也比较特殊，这是在第一次路由决定之后，在进行最后的路由决定之前，我们仍然可以对数据包进行某些修改。
> 8. 进入 filter 表的 FORWARD 链，在这里我们可以对所有转发的数据包进行过滤。需要注意的是：经过这里的数据包是转发的，方向是双向的。
> 9. 进入 mangle 表的 POSTROUTING 链，到这里已经做完了所有的路由决定，但数据包仍然在本地主机，我们还可以进行某些修改。
> 10. 进入 nat 表的 POSTROUTING 链，在这里一般都是用来做 SNAT ，不要在这里进行过滤。
> 11. 进入出去的网络接口。完毕。
>
>
>
> 另一种情况是，数据包就是发给本地主机的，那么它会依次穿过：
>
> 7. 进入 mangle 表的 INPUT 链，这里是在路由之后，交由本地主机之前，我们也可以进行一些相应的修改。
> 8. 进入 filter 表的 INPUT 链，在这里我们可以对流入的所有数据包进行过滤，无论它来自哪个网络接口。
> 9. 交给本地主机的应用程序进行处理。
> 10. 处理完毕后进行路由决定，看该往那里发出。
> 11. 进入 raw 表的 OUTPUT 链，这里是在连接跟踪处理本地的数据包之前。
> 12. 连接跟踪对本地的数据包进行处理。
> 13. 进入 mangle 表的 OUTPUT 链，在这里我们可以修改数据包，但不要做过滤。
> 14. 进入 nat 表的 OUTPUT 链，可以对防火墙自己发出的数据做 NAT 。
> 15. 再次进行路由决定。
> 16. 进入 filter 表的 OUTPUT 链，可以对本地出去的数据包进行过滤。
> 17. 进入 mangle 表的 POSTROUTING 链，同上一种情况的第9步。注意，这里不光对经过防火墙的数据包进行处理，还对防火墙自己产生的数据包进行处理。
> 18. 进入 nat 表的 POSTROUTING 链，同上一种情况的第10步。
> 19. 进入出去的网络接口。完毕。
>

## 总结

这次对iptables的数据包流程又有更深的理解，幸好遇到问题时没有直接忽略，狠狠地追查下根本原因。

## 参考

1. https://netfilter.org/documentation/HOWTO/netfilter-hacking-HOWTO-3.html
2. https://serverfault.com/questions/741104/iptables-redirect-works-only-for-first-packet
3. https://blog.csdn.net/dog250/article/details/5692601
4. http://www.opsers.org/security/iptables-related-concepts-and-processes-the-packet-figure.html
5. http://www.ha97.com/4093.html
6. https://blog.csdn.net/guyuealian/article/details/52535294