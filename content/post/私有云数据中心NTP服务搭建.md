---
title: 私有云数据中心NTP服务搭建
tags:
  - ntp
  - linux
categories:
  - 云计算
date: 2016-07-27 23:45:00+08:00
---
搭建私有云环境，为了确保数据中心内部服务器的时间一致，一般建议在数据中心内部搭建NTP服务。这里将搭建NTP服务器的过程简单记录一下以备忘。

## NTP服务端设置

```bash
#安装ntp服务
yum install -y ntp

echo "
#在与上级时间服务器联系时所花费的时间，记录在driftfile参数后面的文件
driftfile /var/lib/ntp/drift
#默认关闭所有的 NTP 联机服务
restrict default ignore
restrict -6 default ignore
#如从loopback网口请求，则允许NTP的所有操作
restrict 127.0.0.1
restrict -6 ::1
#仅允许某个网段的客户端可以通过此服务端进行网络校时
restrict 188.188.100.0 mask 255.255.255.0 nomodify notrap nopeer
#中国区常用的时间服务器
server 1.cn.pool.ntp.org
server 2.cn.pool.ntp.org
server 3.cn.pool.ntp.org
server 0.cn.pool.ntp.org
server cn.pool.ntp.org
#不允许第三方时间服务器修改本时间服务器的配置，查询本时间服务器的信息
restrict 1.cn.pool.ntp.org nomodify notrap nopeer noquery
restrict 2.cn.pool.ntp.org nomodify notrap nopeer noquery
restrict 3.cn.pool.ntp.org nomodify notrap nopeer noquery
restrict 0.cn.pool.ntp.org nomodify notrap nopeer noquery
restrict cn.pool.ntp.org nomodify notrap nopeer noquery
#万一无法与第三方时间服务器校时，则使用本机时间
server	127.127.1.0	# local clock
fudge	127.127.1.0 stratum 10
#其它认证信息
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
" > /etc/ntp.conf
service ntpd start
iptables -A INPUT -p udp -m state --state NEW -m udp --dport 123 -j ACCEPT
#保存防火墙配置
service iptables save
service iptables restart
```

## NTP客户端设置

```bash
#安装ntp服务
yum install -y ntp

echo "
#在与上级时间服务器联系时所花费的时间，记录在driftfile参数后面的文件
driftfile /var/lib/ntp/drift
#默认关闭所有的 NTP 联机服务
restrict default ignore
restrict -6 default ignore
#如从loopback网口请求，则允许NTP的所有操作
restrict 127.0.0.1
restrict -6 ::1
#使用指定的时间服务器
server 188.188.100.54
#允许指定的时间服务器查询本时间服务器的信息
restrict 188.188.100.54 nomodify notrap nopeer noquery
#其它认证信息
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
" > /etc/ntp.conf
service ntpd start
```

## 验证

等待1024s后，执行下面的命令

```bash
ntpstat
```

得到下面类似的输出

```bash
synchronised to NTP server (188.188.100.54) at stratum 4
   time correct to within 87 ms
   polling server every 1024 s
```

则说明时间已校正

执行`ntpq -p`可看到与上游时间服务器校正的细节，输出类似下面的

```bash
     remote           refid      st t when poll reach   delay   offset  jitter
==============================================================================
*188.188.100.54  202.118.1.81     3 u  762 1024  377    0.171    0.051   0.389
```

`188.188.100.54`前面有一个`*`号代表已与该时间服务器校正了时间。

如需将时间同步到硬件时钟，可执行命令`hwclock --systohc`

