---
title: centos下无污染地打rpm包
author: Jeremy Xu
tags:
  - centos
  - rpmbuild
categories:
  - devops
date: 2018-04-01 23:45:00+08:00
typora-root-url: ../../source
typora-copy-images-to: ../images/20180401
---

工作中要经常要给centos6, centos7打某应用程序的rpm包。原来安装了两个虚拟机专门干这个工作，但经常会因为打包给系统装上许多没用的软件包，占用空间，而且要频繁在两个虚拟机间切换，很是麻烦。经同事介绍，发现[mock](https://github.com/rpm-software-management/mock)这个工具，终于较完美地解决了此问题。

# 使用mock前的准备工作

```bash
yum -y install epel-release # 由于mock是在epel仓库里的，所以还需要先装epel仓库
yum -y install mock
```

通常情况下使用rpmbuild会新开一个用户，比如builder，这样就不会污染系统环境。我们需要把builder用户加入mock用户组：

```bash
usermod -a -G mock builder
```

mock打rpm包时需要src.rpm文件，还是用老方法生成src.rpm文件：

```bash
rpmbuild -bs test.spec
```

然后需要初始化mock环境，在/etc/mock文件夹下有各个环境的配置文件，比如centos 6就是centos-6-x86_64，centos 7就是centos-7-x86_64，初始化命令就是：

```bash
mock -r centos-6-x86_64 --init
```

可以在初始环境前修改配置文件中yum源的地址，这样生成rpm包的过程中下载相关依赖的rpm包会快很多。

# 使用mock

生成rpm包

```bash
mock -r centos-6-x86_64 rebuild test-1.1-1.src.rpm
```

构建完毕，rpm文件会存放在`/var/lib/mock/epel-6-x86_64/result`目录下。当然我们可以通过`–resultdir`参数来指定rpm文件的生成目录

```bash
mock -r centos-6-x86_64 rebuild test-1.1-1.src.rpm --resultdir=/home/builder/rpms
```

最后执行clean命令清理环境

```bash
mock -r centos-6-x86_64 --clean
```

# mock的实现原理

简单看了看mock的实现原理，就是在chroot环境中打rpm包，很自然。

# 参考

1. https://leo108.com/pid-2207/
