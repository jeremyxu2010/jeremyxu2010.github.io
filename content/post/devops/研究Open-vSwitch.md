---
title: 研究Open vSwitch
tags:
  - Open vSwitch
  - sdn
categories:
  - devops
date: 2016-09-09 01:48:00+08:00
---
## 概念

现在云计算大行其道，以kvm和docker为代表，极大地利用了机器的硬件资源，模拟了操作系统，而在海量虚拟机场景下，传统的硬件交换机越来越难以满足需求了。为了更加高效地利用网络，SDN应运而生。而SDN如何落地很大程度上取决于如何用软件交换机替代传统的交换机。

从名称来看，openvswitch就是一个用软件实现的虚拟交换机。一个物理交换机基本支持flows, VLANs, trunking, QoS, port aggregation, firewalling, 还有一些具备3层交换的功能，而虚拟环境kvm或者docker下的网络层就贫乏多了，没什么像样的东西。ovs就恰恰补充了这方面的功能。Open vSwitch 支持flows，VLANS, trunking和port aggregation，跟其他主流交换机基本一样。

## 名词解释

Open vSwitch中许多网络上的概念与平时接触到的不同，这里介绍一下Open vSwitch中用到的一些名词。

* Packet （数据包） 网络转发的最小数据单元，每个包都来自某个端口，最终会被发往一个或多个目标端口，转发数据包的过程就是网络的唯一功能。
* Bridge （网桥） Open vSwitch中的网桥对应物理交换机，其功能是根据一定流规则，把从端口收到的数据包转发到另一个或多个端口。
> * Normal Port: 用户可以把操作系统中的网卡绑定到Open vSwitch上，Open vSwitch会生成一个普通端口处理这块网卡进出的数据包。
  * Internal Port: 当设置端口类型为internal，Open vSwitch会创建一快虚拟网卡，此端口收到的所有数据包都会交给这块网卡，网卡发出的包会通过这个端口交给Open vSwitch。当Open vSwitch创建一个新网桥时，默认会创建一个与网桥同名的Internal Port，同时也创建一个与Port同名的Interface。三位一体，所以操作系统里就多了一块网卡，但是状态是down的。
  * Patch Port: 当机器中有多个Open vSwitch网桥时，可以使用Patch Port把两个网桥连起来。Patch Port总是成对出现，分别连接在两个网桥上，在两个网桥之间交换数据。Patch Port是机房术语，特指用于切换网线连接的接线卡。此卡上面网口成对出现，当需要把两台设备连接起来时，只需要把两台设备接入同一对网口即可。
  * Tunnel Port: 隧道端口是一种虚拟端口，支持使用gre或vxlan等隧道技术与位于网络上其他位置的远程端口通讯。
* Interface （iface/接口） 接口是Open vSwitch与外部交换数据包的组件。一个接口就是操作系统的一块网卡，这块网卡可能是Open vSwitch生成的虚拟网卡，也可能是物理网卡挂载在Open vSwitch上，也可能是操作系统的虚拟网卡（TUN/TAP）挂载在Open vSwitch上。
* Flow （流） 流定义了端口之间数据包的交换规则。每条流分为匹配和动作两部分，匹配部分选择哪些数据包需要可以通过这条流处理，动作决定这些匹配到的数据包如何转发。流描述了一个网桥上，端口到端口的转发规则。比如我可以定义这样一条流：`当数据包来自端口A，则发往端口B`, `来自端口A`就是匹配部分，`发往端口B`就是动作部分。流的定义可能非常复杂，比如：`当数据包来自端口A，并且其源MAC是aa:aa:aa:aa:aa:aa，并且其拥有vlan tag为a，并且其源IP是a.a.a.a，并且其协议是TCP，其TCP源端口号为a，则修改其源IP为b.b.b.b，发往端口B`
* Datapath 由于流可能非常复杂，对每个进来的数据包都去尝试匹配所有流，效率会非常低，所以有了datapath这个东西。Datapath是流的一个缓存，会把流的执行结果保存起来，当下次遇到匹配到同一条流的数据包，直接通过datapath处理。考虑到转发效率，datapath完全是在内核态实现的，并且默认的超时时间非常短，大概只有3秒左右。

## 实操

### 安装OVS

ovs的概念还比较复杂，还是实际操作一下印象比较深刻，我这里在CentOS7系统上操作一下。

一向懒得编译安装，这里就直接使用别人编译好的rpm包安装。

```bash
yum install -y http://mirror.beyondhosting.net/OpenVSwitch/openvswitch-2.3.1-1.el7.x86_64.rpm
modprobe openvswitch
systemctl enable openvswitch && systemctl start openvswitch
#检查一下是否安装成功
ovs-vsctl show
```

然后创建一个OVS的网桥，可以命令行操作如下：

```bash
ovs-vsctl add-br ovsbr0
ovs-vsctl add-port ovsbr0 enp3s1
ifconfig enp3s1 0.0.0.0
ifconfig ovsbr0 188.188.100.54/24
route del default
route add default gw 188.188.100.1 dev ovsbr0
```

不过由于我这里是远程操作，还是采取修改配置文件的方式：

修改/etc/sysconfig/network-scripts/ifcfg-ovsbr0

```bash
TYPE="OVSBridge"
DEVICETYPE="ovs"
BOOTPROTO="static"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
NAME="ovsbr0"
DEVICE="ovsbr0"
ONBOOT="yes"
IPADDR="188.188.100.54"
PREFIX="24"
GATEWAY="188.188.100.1"
DNS1="202.96.134.133"
IPV6_PEERDNS="yes"
IPV6_PEERROUTES="yes"
IPV6_PRIVACY="no"
```

修改/etc/sysconfig/network-scripts/ifcfg-enp3s1

```bash
OVS_BRIDGE="ovsbr0"
TYPE="OVSPort"
DEVICETYPE="ovs"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
NAME="enp3s1"
DEVICE="enp3s1"
ONBOOT="yes"
PREFIX="24"
IPV6_PEERDNS="yes"
IPV6_PEERROUTES="yes"
IPV6_PRIVACY="no"
```

最后重启一下网络

```bash
systemctl restart network
#检查一下OVS网桥
ovs-vsctl show
```

上述步骤跟Linux Bridge网桥的创建过程很相似。

### 在KVM里代替Linux Bridge网桥使用

在KVM里想用ovs网桥步骤也与Linux Bridge网桥很类似，如下：

编辑ovsbr0.xml

```bash
<network>
  <name>ovsbr0</name>
  <forward mode='bridge'/>
  <bridge name='ovsbr0'/>
  <virtualport type='openvswitch'/>
</network>
```

使用libvirt创建一个网络

```bash
virsh net-define ovsbr0.xml
virsh net-start ovsbr0
virsh net-autostart ovsbr0
```

最后在安装kvm虚拟机时使用ovsbr0

```bash
virt-install \
    -n nagios \
    -r 4096  \
    --disk path=/export/kvm/nagios.qcow2,format=qcow2,size=60 \
    --vcpus 4  \
    --noautoconsole \
    --cdrom=/export/kvm/iso/FAN-2.4-x86_64.iso \
    --os-type=linux  \
    --network network:ovsbr0 \
    --vnc --vnclisten=0.0.0.0 --vncport=5901
```

或使用`virsh edit vm1.xml`修改kvm虚拟机的定义

```bash
<interface type='bridge'>
  <source bridge='ovsbr0'/>
  <virtualport type='openvswitch'>
</interface>
```

还可以将正在运行的KVM虚拟机的vnet网络接口强制接到ovs上

```bash
#可使用virsh dumpxml $vmname|grep vnet得到某个KVM虚拟机在宿主机上对应的网络接口
ovs-vsctl add-port ovsbr0 vnet0
```

### 设置VLAN

如果只是上面的用法，那跟Linux Bridge并没有太大的任何区别，ovs还可以支持VLAN

首先给ovsbr0增加两个端口vlan10，vlan20，并给它们vlan tag ID

```bash
ovs-vsctl add-port ovsbr0 vlan10 tag=10 -- set interface vlan10 type=internal
ifconfig vlan10 192.168.10.1 netmask 255.255.255.0

ovs-vsctl add-port ovsbr0 vlan20 tag=20 -- set interface vlan20 type=internal
ifconfig vlan20 192.168.20.1 netmask 255.255.255.0
```

然后在两个KVM虚拟机里执行命令

在kvm1里执行

```bash
ip link add link eth0 name eth0.10 type vlan id 10
ifconfig eth0.10 192.168.10.33 netmask 255.255.255.0 broadcast 192.168.10.255 up
route add default gw 192.168.10.1 dev eth0.10
```

在kvm2里执行

```bash
ip link add link eth0 name eth0.20 type vlan id 20
ifconfig eth0.20 192.168.20.33 netmask 255.255.255.0 broadcast 192.168.20.255 up
route add default gw 192.168.20.1 dev eth0.20
```

在kvm3里执行

```bash
ip link add link eth0 name eth0.10 type vlan id 10
ifconfig eth0.20 192.168.10.34 netmask 255.255.255.0 broadcast 192.168.10.255 up
route add default gw 192.168.10.1 dev eth0.10
```

这样kvm1与kvm3就在同一个vlan里，而kvm2在另一个vlan里，使用vlan隔离了KVM虚拟机。

还可以使用在定义libvirt网络时使用portgroup，这样在guest os里就不用专门设置网络接口的vlan tag ID了。

编辑ovsbr0.xml

```bash
<network>
  <name>ovsbr0</name>
  <forward mode='bridge'/>
  <bridge name='ovsbr0'/>
  <virtualport type='openvswitch'/>
  <portgroup name='ovsbr0' default='yes'>
  </portgroup>
    <portgroup name='vlan10'>
    <vlan>
      <tag id='10'/>
    </vlan>
  </portgroup>
  <portgroup name='vlan20'>
    <vlan>
      <tag id='20'/>
    </vlan>
  </portgroup>
</network>
```

KVM虚拟机中的网络配置

```bash
<interface type='bridge'>
  <source bridge='ovsbr0' portgroup='vlan10'/>
  <virtualport type='openvswitch'>
</interface>
```

### OVS的VLAN Trunk配置

带 VLAN 的交换机的端口分为两类：

* Access port：这些端口被打上了 VLAN Tag。离开交换机的 Access port 进入计算机的以太帧中没有 VLAN Tag，这意味着连接到 access ports 的机器不会觉察到 VLAN 的存在。离开计算机进入这些端口的数据帧被打上了 VLAN Tag。
* Trunk port： 有多个交换机时，组A中的部分机器连接到 switch 1，另一部分机器连接到 switch 2。要使得这些机器能够相互访问，你需要连接两台交换机。 要避免使用一根电缆连接每个 VLAN 的两个端口，我们可以在每个交换机上配置一个 VLAN trunk port。Trunk port 发出和收到的数据包都带有 VLAN header，该 header 表明了该数据包属于那个 VLAN。因此，只需要分别连接两个交换机的一个 trunk port 就可以转发所有的数据包了。通常来讲，只使用 trunk port 连接两个交换机，而不是用来连接机器和交换机，因为机器不想看到它们收到的数据包带有 VLAN Header。

所以假如一台物理机上的交换机上有vlan10与vlan20, 另一台物理机上的交换机上也有vlan10与vlan20，如果想让两台物理的vlan10内部可互相访问，则要用到OVS的VLAN Trunk端口。

具体配置可参考[这里](http://www.rendoumi.com/open-vswitchru-he-gei-kvmxu-ji-pei-zhi-vlan-trunk/)，不过我感觉这个例子里使用有些奇怪，一般使用trunk port的目的是为了连接两个交换机，使得两个交换机上的相同Tag的VLAN可互相访问。

### OVS链路聚合

OVS也支持链路聚合，见[这里](http://www.rendoumi.com/open-vswitchxia-zuo-duan-kou-bang-ding-bonding/)，不过据说性能不是太好。所以还是建议参照[这里](http://www.cnblogs.com/qmfsun/p/3810905.html)创建Linux的Bonding，再将bonding出来的网口接入ovs的网桥。

### VLAN的限制

来看看VLAN的定义：

> LAN 表示 Local Area Network，本地局域网，通常使用 Hub 和 Switch 来连接LAN 中的计算机。一般来说，当你将两台计算机连入同一个 Hub 或者 Switch 时，它们就在同一个 LAN 中。同样地，你连接两个 Switch 的话，它们也在一个 LAN 中。一个 LAN 表示一个广播域，它的意思是，LAN 中的所有成员都会收到 LAN 中一个成员发出的广播包。可见，LAN 的边界在路由器或者类似的3层设备。

> VLAN 表示 Virutal LAN。一个带有 VLAN 功能的switch 能够同时处于多个 LAN 中。最简单地说，VLAN 是一种将一个交换机分成多个交换机的一种方法。比方说，你有两组机器，group A 和 B，你想配置成组 A 中的机器可以相互访问，B 中的机器也可以相互访问，但是A组中的机器不能访问B组中的机器。你可以使用两个交换机，两个组分别接到一个交换机。如果你只有一个交换机，你可以使用 VLAN 达到同样的效果。你在交换机上分配配置连接组A和B的机器的端口为 VLAN access ports。这个交换机就会只在同一个 VLAN 的端口之间转发包。

> IEEE 802.1Q 标准定义了 VLAN Header 的格式。它在普通以太网帧结构的 SA （src addr）之后加入了 4bytes 的 VLAN Tag/Header 数据，其中包括 12-bits 的 VLAN ID。VLAN ID 最大值为4096，但是有效值范围是 1 - 4094。

可以看到VLAN ID的bit位只有12位，因此一个网络架构中最多只可能设置4094个VLAN。试想一下在云厂商的环境，VPC的数量可能远远大于4094，因此简单的VLAN并不能解决云厂商对虚拟子网的要求。于是又出现了VXLAN，这个比较复杂，后面研究后再开贴说明。

## 总结

最后附一个[Open vSwitch的ovs-vsctl常用命令](http://www.rendoumi.com/open-vswitchde-ovs-vsctlming-ling-xiang-jie/)

OVS确实还挺复杂的，要理解它的概念很考验网络知识基础，通过对它的学习对网络知识的了解有进一步加深。

## 参考

`http://blog.chinaunix.net/uid-25518484-id-5707513.html`
`http://www.rendoumi.com/openvswitch/`
`http://www.rendoumi.com/open-vswitch-gong-zuo-yuan-li/`
`http://www.rendoumi.com/openvswitchzai-centos-6-6xia-de-an-zhuang-2/`
`http://www.rendoumi.com/ovsxia-ru-he-she-zhi-linuxde-wang-qia/`
`https://github.com/openvswitch/ovs/blob/master/INSTALL.md`
`http://www.rendoumi.com/open-vswitchshe-zhi-vlande-ce-shi/`
`http://www.rendoumi.com/open-vswitchyu-kvmshi-yong-vlanjin-jie/`
`http://www.rendoumi.com/open-vswitchxia-zuo-duan-kou-bang-ding-bonding/`
`http://www.cnblogs.com/qmfsun/p/3810905.html`
`http://geek.csdn.net/news/detail/68291`
`http://www.rendoumi.com/open-vswitchde-ovs-vsctlming-ling-xiang-jie/`
