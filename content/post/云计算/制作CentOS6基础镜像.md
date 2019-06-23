---
title: 制作CentOS6基础镜像
tags:
  - kvm
  - linux
categories:
  - 云计算
date: 2016-08-07 23:29:00+08:00
---
搭建私有云时需要制作一些操作系统的基础镜像，这里也有一些持巧，在这里记录下来以备忘。

## 安装CentOS6操作系统

这里没有太多好说的，我是从[这里](http://mirrors.aliyun.com/centos/6/isos/x86_64/CentOS-6.8-x86_64-minimal.iso)下载最小安装ISO进行安装的，安装的硬盘大小为20G。安装时大部分选项都是默认的，只有分区采用了自定义分区方案，200M的boot分区，其它全部作为根分区。如果需要交换分区，以后可以使用文件分区，使用文件分区的操作方法如下：

```bash
dd if=/dev/zero of=/swapfile bs=1G count=2
chmod 600 /swapfile
mkswap -f /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab
mount -a
```

## 操作系统的一些基础设置

安装好操作系统后，使用root帐户登入系统做一些基础设置

```bash
#关闭selinux
setenforce 0
sed -i -e 's/^SELINUX=.*$/SELINUX=disabled/' /etc/sysconfig/selinux

#由于公司没有搭建centos的私有源，这里我都换用aliyun的centos源
rpm --import http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-6
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo
rpm --import http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-6
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-6.repo

#安装平时经常用到的vim wget等软件
yum install -y vim wget

#配置ntp服务，指向私有云中的时间服务器
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
server ${inner_ntp_server_ip}
#允许指定的时间服务器查询本时间服务器的信息
restrict ${inner_ntp_server_ip} nomodify notrap nopeer noquery
#其它认证信息
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
" > /etc/ntp.conf
service ntpd start
chkconfig ntpd on

#禁用sshd服务的UseDNS、GSSAPIAuthentication两项特性
sed -i -e 's/^#UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config
sed -e 's/^GSSAPIAuthentication.*$/GSSAPIAuthentication no/' /etc/ssh/sshd_config

#升级系统
yum update -y && yum clean all

#更改系统网络接口配置文件，设置该网络接口随系统启动而开启
sed -i -e '/^HWADDR=/d' -e '/^UUID=/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e 's/^ONBOOT.*$/ONBOOT=yes/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e 's/^NM_CONTROLLED.*$/NM_CONTROLLED=no/' /etc/sysconfig/network-scripts/ifcfg-eth0

#删除已存在的网络接口udev规则定义
sed -i -e  '/PCI device/d' -e '/^SUBSYSTEM/d' /etc/udev/rules.d/70-persistent-net.rules

#关闭系统
halt
```

最近精简一下生成的镜像文件

```bash
qemu-img convert -f qcow2 -O qcow2 centos6.img centos6_c.img
mv centos6_c.img centos6.img
```

## 对镜像文件预处理

使用虚拟机平台基于上述centos6基础镜像文件创建虚拟机后，在虚拟机启动前需对镜像文件进行预处理，我这里写个脚本处理这件事

执行脚本前需安装libguestfs-tools

```bash
yum install -y libguestfs-tools
#以后可能还要修改windows镜像文件，顺便把libguestfs-winsupport也安装一下
yum install -y libguestfs-winsupport
```

`preprocess_img.sh`脚本内容：

```
#!/bin/bash

domain_name=$1
ip_fetch_method=$2
static_ip=$3
static_netmask=$4
static_gateway=$5
static_dns1=$6
static_dns2=$7

TMP_CONFIG_DIR="$(mktemp -d /tmp/$$_config_XXXX)"
trap "[ -d "$TMP_CONFIG_DIR" ] && rm -rf $TMP_CONFIG_DIR" HUP INT QUIT TERM EXIT

echo "
NETWORKING=yes
HOSTNAME=$domain_name
" > $TMP_CONFIG_DIR/network
virt-copy-in -d $domain_name $TMP_CONFIG_DIR/network /etc/sysconfig

if [ $ip_fetch_method == "static" ] ; then
    echo "
DEVICE=eth0
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=static
IPADDR=$static_ip
NETMASK=$static_netmask
GATEWAY=$static_gateway
DNS1=$static_dns1
DNS2=$static_dns2
" > $TMP_CONFIG_DIR/ifcfg-eth0
    virt-copy-in -d $domain_name $TMP_CONFIG_DIR/ifcfg-eth0 /etc/sysconfig/network-scripts
fi
```

执行脚本

```bash
# 设置主机名为test，且eth0网络接口动态获取IP地址
./preprocess_img.sh test dhcp
# 设置主机名为test，且eth0网络接口配置静态IP地址
./preprocess_img.sh test static 188.188.100.137 255.255.255.0 188.188.100.1 202.96.134.133 202.96.128.86
```

镜像文件预处理完毕后，再启动虚拟机，可以看到虚拟机的主机名及IP地址均已设置OK

## 待改进的地方

* 目前的`preprocess_img.sh`脚本还比较原始，只能处理centos6操作系统，接下来会对这个脚本进行加强，以支持其它linux操作系统及windows系统
* 要是能扩展虚拟化管理平台WebVirtMgr，能在首次启动时执行指定的脚本对镜像进行预处理就好了。可惜我对python不是太熟。

## 参考

* `深度实践KVM/第16章 虚拟机镜像制作、配置与测试/16.2 Linux镜像制作方法`
* `http://www.361way.com/kvm-libguestfs-tools/3175.html`
