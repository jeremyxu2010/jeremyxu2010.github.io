---
title: 使用vagrant搭建验证环境
author: Jeremy Xu
tags:
  - linux
  - vagrant
  - kubernetes
categories:
  - 工具
date: 2019-03-24 10:30:00+08:00
---

这周的工作需要在一个独立的kubernetes环境调试功能，自然而然地想到在本机装个虚拟机搭建这个环境。不过有同事推荐我试一下[vagrant](https://www.vagrantup.com/docs/)，久闻**Vagrant**大名，之前也经常在一些开源项目中看到它，今天花了些时间了解下这个新东西。

## vagrant的简介

Vagrant是[hashicorp](https://www.hashicorp.com/)这家公司的产品，这家公司主要做云基础设施自动化的，其名下大名鼎鼎的产品有`Consul`、`Vault`、`Nomad`、`Terraform`，这前在做微服务框架时做过他们的`Consul`，还是挺靠谱的。他们的产品感觉都比较有创新，而且基本上都开源了，他们的开源地址是[这里](https://github.com/hashicorp)。

Vagrant是用来管理虚拟机的，如VirtualBox、VMware、AWS等，主要好处是可以提供一个可配置、可移植和复用的软件环境，可以使用shell、chef、puppet等工具部署。所以vagrant不能单独使用，如果你用它来管理自己的开发环境的话，必须在自己的电脑里安装了虚拟机软件，我使用的是**virtualbox**。

Vagrant提供一个命令行工具`vagrant`，通过这个命令行工具可以直接启动一个虚拟机，当然你需要提前定义一个Vagrantfile文件，这有点类似Dockerfile之于docker了。

跟docker类比这来看vagrant就比较好理解了，vagrant也是用来提供一致性环境的，vagrant本身也提供一个镜像源，使用`vagrant init hashicorp/precise64`就可以初始化一个Ubuntu 12.04的镜像。

## 安装vagrant

我本机是macOS系统，安装vagrant比较简单，命令如下：

```bash
$ brew cask install virtualbox
$ brew cask install vagrant
```

其它操作下安装也挺简单的，参见[官方文档](https://www.vagrantup.com/docs/installation/)就可以了。

## 使用vagrant

首先我这里创建第一个虚拟机，第一步是要将基础镜像拉回到本地缓存着，用以下命令：

```bash
$ vagrant box add --provider virtualbox centos/7
# 如果box文件下载太慢，也可以通过其它工具将box文件下载到本地之后，用下面的命令添加到缓存
$ vagrant box add --name centos/7 --provider virtualbox $your_donwload_dir/centos_virtualbox.box
```

对box的一系列操作命令文档见[这里](https://www.vagrantup.com/docs/cli/box.html)。

有了基础镜像box后，接下来在某一目录用`box init`即可创建一个初始的[Vagrantfile](https://www.vagrantup.com/docs/vagrantfile/)文件:

```bash
$ cd $your_working_dir
$ vagrant init centos/7
```

`vagrant init`命令比较简单，参见[官方文档](https://www.vagrantup.com/docs/cli/init.html)就可以了。

接下来就是修改[Vagrantfile](https://www.vagrantup.com/docs/vagrantfile/)文件了，打开[Vagrantfile](https://www.vagrantup.com/docs/vagrantfile/)文件，看一看里面的注释大概就知道怎么写了，主要是ruby的语法，我们用得最多的就是虚拟机配置`config.vm`和ssh配置`config.ssh`，这个[官方文档](https://www.vagrantup.com/docs/vagrantfile/)里将每个配置项都详细描述了，按描述配置就可以了，当然对于虚拟机、ssh本身有哪些配置可以调整提前要了解。

除了对虚拟机进行一些配置外，还可以通过各类`Provisioner`自动化地安装软件、调整配置。官方默认提供的`Provisioner`列表在[这里](https://www.vagrantup.com/docs/provisioning/)。但我们平时用得比较多的主要有以下几个`File`、`Shell`、`Ansible`、`Docker`等，使用方法如下：

```ruby
Vagrant.configure("2") do |config|
  # ... other configuration

  # Copy files from host to guest vm
  config.vm.provision "file", source: "~/path/to/host/folder", destination: "$HOME/remote/newfolder"
  
  # Execute shell script on guest vm
  config.vm.provision "shell", path: "script.sh"
  
  # Run Ansible from the Vagrant Host
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbook.yml"
  end
  
  # Install Docker and pull Docker images on guest vm
  config.vm.provision "docker" do |d|
    d.pull_images "ubuntu"
    d.pull_images "vagrant"
  end
end
```

上面的示例都比较简单，每个`Provisioner`都有一些参数用于满足一些特殊场景，这些参数的用法参考[官方文档](https://www.vagrantup.com/docs/provisioning/)就可以了。

除此之外还可以进行一些网络相关的配置，主要是映射一些[端口到宿主机](https://www.vagrantup.com/docs/networking/forwarded_ports.html)、[设置私有网络](https://www.vagrantup.com/docs/networking/private_network.html)、[设置公开网络](https://www.vagrantup.com/docs/networking/public_network.html)。如果是私有网络，则创建的虚拟机不对外公布，仅宿主机可访问。如果是公开网络，则创建的虚拟机会连接到局域网中的路由器上，如果能从路由器那里申请到IP，则其它主机也可以访问该虚拟机。

vagrant还提供多种机制将宿主机上的一些目录同步到虚拟机中，平时用得比较多就是它的默认机制：

```ruby
Vagrant.configure("2") do |config|
  # other config here
  config.vm.synced_folder "src/", "/srv/website"
end
```

[Vagrantfile](https://www.vagrantup.com/docs/vagrantfile/)文件写好后，就可以以此为基础操作虚拟机了：

```bash
# 启动
vagrant up
# 关机
vagrant halt
# 重启
vagrant reload
# 暂停
vagrant suspend
# 恢复
vagrant resume
# 给虚拟机打个快照
vagrant snapshot save ${snapshotName}
# 将虚拟机还原到快照
vagrant snapshot restore ${snapshotName}
# 列出虚拟机的快照
vagrant snapshot list
# 删除虚拟机的某个快照
vagrant snapshot delete ${snapshotName}
# 用ssh连接虚拟机
vagrant ssh
# 输出虚拟机的SSH连接配置，其它SSH工具可参考这些配置连接虚拟机
vagrant ssh-config
# 用RDP客户端连接虚拟机
vagrant rdp
# 删除虚拟机
vagrant destroy
```

这样操作虚拟机真的是很方便啊。

还有一些高级功能，比如[定义操控多个虚拟机](https://www.vagrantup.com/docs/multi-machine/)、[发布自已的镜像](https://www.vagrantup.com/docs/cli/cloud.html)等，这些参考官方文档就可以了。

## 为什么用vagrant

vagrant的功能介绍得差不多了，再来说一下为啥要用vagrant。原来我们搭建一个测试场景，会涉及很多台虚拟机，如果全部手工搭建，不仅很繁琐，而且不便于保存成果，下次遇到同样的需求又得重搭一次，而极容易出错，这些人肉操作也不便于修订管理。后面为了自动化实施，我们用了ansible之类工具，将操作步骤都写进ansible脚本中。ansbile方案确实解决了很大的问题，但失败率还是有些高，原因是待部署的虚拟机状态不统一。而vagrant直接将待部署的虚拟机也统一了，本身也支持用shell脚本、ansible脚本将操作步骤都记录下来。这样一来，只要拿到[Vagrantfile](https://www.vagrantup.com/docs/vagrantfile/)，在任何主机上都只需要一条命令就可以将整套环境部署起来了。

比如我写了一个搭建[单节点kubernetes环境的Vagrantfile](https://github.com/jeremyxu2010/vagrant_files/tree/master/k8s-centos7)，别人只要在本机安装好了vagrant，将这个vagrantfile下载下来，在该目录执行`vagrant up`命令，一个单节点kubernetes环境就自动创建好了。

## 总结

用正确的工具去做正确的事儿，真的是事半功倍。

## 参考

1. https://www.vagrantup.com/docs
2. https://jimmysong.io/posts/vagrant-intro/



