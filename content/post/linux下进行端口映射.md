---
title: linux下进行端口映射
author: Jeremy Xu
tags:
  - linux
  - network
  - iptables
  - ssh
categories:
  - devops
date: 2014-04-30 01:40:00+08:00
---

工作需要将某个具有外网IP的server的某个端口映射到某个内网IP的server的相同端口上。

首先想到使用NAT，命令如下

```bash
echo "1" > /proc/sys/net/ipv4/ip_forward
iptables -t nat -I PREROUTING -d $outterIP -p tcp --dport $outterPort -j DNAT --to-destination $innerIP:$innerPort
iptables -I FORWARD -p tcp -m state --state NEW,RELATED,ESTABLISHED -d $innerIP --dport $innerPort -j ACCEPT
iptables -I FORWARD -p tcp -m state --state NEW,RELATED,ESTABLISHED -s $innerIP --sport $innerPort -j ACCEPT
iptables -t nat -I POSTROUTING -s $innerIP -j SNAT --to-source $outterIP
```

后面发现NAT映射失败，仔细检查发现由于`$outterIP`并不是`$innerIP`的网关，从`$innerIP`回来的数据包直接从其网关传输走了，无法到达`$outterIP`所在的server, 即SNAT无法正常工作。

最后想了想，还是直接用ssh port forwarding了，命令如下
```bash
ssh -Nfq -c arcfour  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -L 0.0.0.0:8118:192.168.9.85:8118 -i /root/.ssh/id_rsa root@127.0.0.1
```

效率方面估计会比直接NAT端口映射差一点，但我也能接受了

最后附一张iptables数据包流转图

![iptables数据包流转](/images/20140431/iptables_overview.gif)

