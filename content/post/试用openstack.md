---
title: 试用openstack
tags:
  - openstack
  - kvm
  - linux
categories:
  - 云计算
date: 2016-08-02 23:37:00+08:00
---
公司有八九台服务器一直由我负责运维，这些服务器的配置参次不齐，主要部署了研发的持续集成环境、测试环境、性能压测环境、maven私服等一系列支撑日常开发活动的服务器。之前的办法是在这些服务器利用KVM虚拟化技术手工创建虚拟机来满足需求，最常用到的命令可能就是qemu-img、virsh了。这种办法主要存在以下的问题：

* 需要将每个主机上跑了哪些主机这些信息记录下来，最好形成表格，一旦有变更一定是同步更新表格
* 虚拟机创建、销毁、迁移得手工敲命令完成，即使形成一些较通用的工具脚本，还是有不少敲命令的工作量
* 由于公司机房安全限制，不允许机房里启动DHCP服务器，每个虚拟机镜像创建完毕之后，需要自行敲命令使用libguestfs相关命令修改虚拟机镜像文件系统中的网络配置文件，以使创建的虚拟机启动好后，自行配置好IP地址、主机名等信息。

其实早就知道针对企业内部私有云可以采用openstack，但每次一看到openstack部署那浩浩荡荡的文档就打了退堂鼓。这个周末有空，终于有时间将看过到的openstack部署过程实践一把了。我基本上是参照[在CentOS7上部署openstack mitaka版](http://docs.openstack.org/mitaka/install-guide-rdo/)的官方文档来操作的，这里就不记录详细的过程了，重点写一下安装过程中坑。

## 安装环境概览

为了部署的方便，我仅在一台物理上部署openstack的Identity service(keystone)、Image service(glance)、Compute service(nova)、Networking service(neutron)、Block Storage service(cinder)、Dashboard(horizon)。由于只是测试部署的过程及试用openstack的功能，并没有部署Object Storage service(swift)。同时Networking service采用的是[Provider networks](http://docs.openstack.org/mitaka/install-guide-rdo/overview.html#id4)的方案。

整个部署还是比较简单的。

首先看一下[openstack各组成部分的概览](http://docs.openstack.org/mitaka/install-guide-rdo/overview.html)，大概理解各组成部分之间的关系，根据自身需求确定好网络方案。

然后就是按文档[准备环境](http://docs.openstack.org/mitaka/install-guide-rdo/environment.html)，这里主要就是生成安全的密码并记录下来、确定管理网络与工作网络的网络拓扑、配置时间同步服务、配置yum软件安装源、安装配置SQL数据库、安装配置NoSQL数据库、安装配置消息队列、安装配置内存缓存服务。

然后就是按照各部分的部署文档一步步部署就是了。大部分openstack组件的安装过程无非是以下几个步骤（有的组件还需要在控制节点及计算节点分别进行安装配置）：

* 创建组件对应的SQL数据库及授予访问该数据库的用户权限
* 创建管理该组件在keystone中对应服务的用户
* 在keystone中将该组件注册为服务，并创建服务的API访问端点（公开的、内部的、管理的）
* 安装该组件的rpm包，修改该组件的一系列配置文件
* 初始化组件对应的SQL数据库的表结构
* 设置组件对应的系统服务开机自启并启动

在安装的过程中其实也慢慢对openstack中说到的Domain、Project、Role、User有一些感觉，后来看到了[IBM的一篇文章](http://www.ibm.com/developerworks/cn/cloud/library/1506_yuwz_keystonev3/index.html)，才对openstack中的授权模型及它的鉴权逻辑有进一步理解。

##  使用openstack

还是按照[文档](http://docs.openstack.org/mitaka/install-guide-rdo/launch-instance.html)尝试在openstack平台上启动一个虚拟机。其实在这篇文章里的所有操作都可以通过访问dashboard来操作，而且如果只是为了使用openstack，我也建议应该使用dashboard界面操作，毕竟今后使用起来会经常创建虚拟机，早点熟悉界面操作也有益处。

创建并启动虚拟机这里有一个坑，我发现完全通过界面无法使用操作系统的安装ISO给一个虚拟机全新安装系统，每次总是报"no usable disks hava been found"，后来google后才知道现在只有两种解决方法：

* 要么使用传统KVM虚拟化方案，装好系统后，拿到系统的镜像文件，将镜像文件上传至openstack的镜像服务，再以此镜像创建虚拟机
* 要么下载操作系统的虚拟机镜像文件（如`http://docs.openstack.org/image-guide/obtain-images.html`），将镜像文件上传至openstack的镜像服务，再以此镜像创建虚拟机

## 使用体会

简单试用了openstack的功能后，记录一下自己的体会。

openstack作为云计算IaaS的一站式解决方案，总的来说架构还是比较清晰的，各组件之间的交互方式也比较统一(都是利用keystone这个服务注册框架来完成服务之间的交互的)，各个组件在设计初也考虑了多种底层实现方案，用户可根据自己的实际情况修改配置文件来满足需求。

不过缺点也比较明显，我感觉如下：

* 各个逻辑组成划分得比较细，如果只是搭建一个不超过10台物理机的小型私有云环境，使用openstack就会感觉逻辑组成部分过多了，增大了部署的复杂度
* 各个组件在设计时考虑了太多底层实现方案，导致配置文件里的配置项相当多，每个配置项的取值也相当多，十分考验部署能力
* 对虚拟机libvirt细粒度的调整能力不足，比如想调整某个虚拟机的xml定义变得很复杂。
* 组件过多，比较消耗系统资源，如图

![openstack相关进程消耗](/images/20160802/openstack_processes.png)

其实这几天我一直在思考在目前研发这个环境中，最适合的私有云管理平台是什么，可以肯定openstack肯定是不太适合。经过几天的思考，大致有一个方案，接下来我会将这个方案实践一下，如果成功，我会将这个方案写出来。

## 参考

`http://docs.openstack.org/mitaka/install-guide-rdo`
`http://www.ibm.com/developerworks/cn/cloud/library/1506_yuwz_keystonev3/index.html`
