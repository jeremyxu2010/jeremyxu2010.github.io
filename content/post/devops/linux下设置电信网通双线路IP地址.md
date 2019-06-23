---
title: linux下设置电信网通双线路IP地址
author: Jeremy Xu
tags:
  - linux
  - network
  - iproute2
categories:
  - devops
date: 2014-03-30 01:40:00+08:00
---

工作上遇到需要在linux下设置电信网通双线路IP地址，操作系统为Suse Linux Enterprise Linux 11 SP2，简要记录下步骤：

- 编辑`/etc/sysconfig/network/ifcfg-eth0`, `/etc/sysconfig/network/ifcfg-eth1`, 设置两个网卡的IP地址，eth0为电信的，eth1为网通的

```
BOOTPROTO='static'
BROADCAST=''
ETHTOOL_OPTIONS=''
IPADDR='${telecomip}/${telecomnetmask}'
MTU=''
NAME='Ethernet Card 0'
NETMASK=''
NETWORK=''
REMOTE_IPADDR=''
STARTMODE='auto'
USERCONTROL='no'
```

- 在路由表配置文件中添加两个命名路由表

```bash
echo "
252     tel
251     cnc
" >> /etc/iproute2/rt_tables
```

- 写一个脚本，并设置开机自启动

```bash
#!/bin/bash
/sbin/ip route flush table tel
/sbin/ip route add default via ${telecomgw} dev eth0 src ${telecomip} table tel
/sbin/ip rule add from ${telecomip} table tel
/sbin/ip route flush table cnc
/sbin/ip route add default via ${cncgw} dev eth2 src ${cncip} table cnc
/sbin/ip rule add from ${cncip} table cnc
```
