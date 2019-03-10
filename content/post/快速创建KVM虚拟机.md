---
title: 快速创建KVM虚拟机
tags:
  - kvm
  - qemu
  - libvirt
  - libguestfs
categories:
  - 云计算
date: 2016-09-21 23:21:00+08:00
---
以前写到一篇文章[制作CentOS6基础镜像](/2016/08/07/%E5%88%B6%E4%BD%9CCentOS6%E5%9F%BA%E7%A1%80%E9%95%9C%E5%83%8F/)，今天在工作中突然要临时创建很多虚拟机，于是结合那篇文章得到的基础镜像，写了个简单的脚本快速创建KVM虚拟机。

## 快速创建一个虚拟机的脚本

这里假设创建的基础镜像为`centos6.7-sys.img`，而且是`qcow2`格式的。

`create_vm.sh`

```bash
#!/bin/bash

domain_name=$1
ip_fetch_method=$2
static_ip=$3
static_netmask=$4
static_gateway=$5
static_dns1=$6
static_dns2=$7

base_img_path=/vmdata/base/centos6.7-sys.img
vm_img_dir=/vmdata

#创建虚拟机的磁盘镜像文件
qemu-img create -f qcow2 -b $base_img_path $vm_img_dir/$domain_name.img

#将磁盘镜像文件挂载至宿主机目录，便于修改内部文件
guestmount -i -w -a $vm_img_dir/$domain_name.img /mnt

#设置主机名
echo "
NETWORKING=yes
HOSTNAME=$domain_name
" > /mnt/etc/sysconfig/network

#如采用静态IP，则设置IP地址相关信息
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
" > /mnt/etc/sysconfig/network-scripts/ifcfg-eth0
fi

#取消挂载
umount /mnt

#创建并启动虚拟机
virt-install --import --name=$domain_name --vcpus=2 --ram 2048 --boot hd --disk path=$vm_img_dir/$domain_name.img,format=qcow2,bus=virtio --network bridge=br0,model=virtio --autostart --graphics vnc,keymap=en-us --noautoconsole
```

脚本的逻辑比较简单，注释写得很清楚。需要注意跟以前不太一样的地方有两点：

* 这次是使用`guestmount`命令将磁盘文件先挂载至临时目录，这样修改磁盘文件里的内容就很方便了，个人感觉这个比以前用的`virt-copy-in`命令方案还是简单一些的。`guestmount`命令的用法可直接`man guestmount`查看。
* 这次是使用`virt-install`命令创建并启动虚拟机。这种方式相当快速，也是一般推荐的快速命令行创建虚拟机的办法。`virt-install`命令的参数相当多，虚拟机配置的方方面面都有参数，这里只使用了一些必须的，再详细的参数说明可直接`man virt-install`查看。

## 快速创建N个虚拟机

再写一个脚本，根据业务需要，调用上述脚本快速创建虚拟机。

```bash
#!/bin/bash

vm_name_prefix='test'

#循环创建20个虚拟机
for((i=1; i<=20; i++))
do
  create_vm.sh $vm_name_prefix$i static 10.10.10.$i 255.255.255.0 10.10.10.254 202.96.134.133 8.8.8.8
done
```

## 其它

`/usr/sbin/virt-install`本身就是用python编写的，使用了libvirt库API的python绑定，如果想了解如何使用libvirt库API，个人觉得这个源码还是可以读一读的。

