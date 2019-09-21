---
title: 编译arm64平台的软件包
tags:
  - debian
  - centos
  - deb
  - rpm
  - arm64
categories:
  - devops
date: 2019-09-20 17:50:00+08:00
---

本周做了较多的国产化适配工作，虽然主要是拿到源码在国产化平台上编译一下，不是太难，但还是总结一下。

国产化平台使用的是arm64v8 CPU芯片，因此传统软件厂商提供的x86架构二进制软件包都没法用，都需要在arm64v8 CPU的服务器上拿源码重新编译。

## 构建debian deb包

在x86上构建debian的deb包还是比较简单的，过程简述如下：

```bash
# 下面假设要编译curl的deb包

# 安装gcc、make等编译链工具
$ apt-get update && apt-get install -y build-essential
# 安装编译curl依赖的那些软件包
$ apt-get build-dep curl
# 创建编译目录
$ mkdir -p ~/build && cd ~/build
# 下载构建curl deb包的源码
$ apt source curl
# 切换到构建目录
$ cd curl-7.52.1/
# 执行dpkg-buildpackage命令构建deb包，该条命令执行完毕后，在上一层目录下就会生成deb包
$ dpkg-buildpackage -us -uc -b
```

对于apt源里有source包的软件包，基本上像上面这样构建就差不多了。

但有些软件厂商并没有提供apt源或apt源里没有相应CPU架构的包，只提供了软件的deb包，比如[mysql](https://dev.mysql.com/downloads/mysql/)。这个时候需要手工下载source deb包，并从source deb包构建出相应cpu架构的deb包，过程简述如下：

```bash
# 安装gcc、make等编译链工具
$ apt-get update && apt-get install -y build-essential
# 下载mysql-community的source包
$ curl -O -L 'https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-source_5.7.27-1debian9_amd64.deb'
# 安装source deb包
$ dpkg -i mysql-community-source_5.7.27-1debian9_amd64.deb
# 创建编译目录
$ mkdir -p ~/build && cd ~/build
# 将source deb包里的内容拷贝到构建目录
$ cp /usr/src/mysql/* ~/build/
# 解压mysql原始的源码
$ tar -xf mysql-community_5.7.27.orig.tar.gz
# 解压构建deb包的debian目录
$ tar -xf mysql-community_5.7.27-1debian9.debian.tar.xz -C mysql-5.7.27/
# 切换到deb包构建目录
$ cd mysql-5.7.27/
# 检查编译deb包依赖的那些软件包是否都安装好了，如果没有安装好，先用apt-get install安装一下
$ grep 'Build-Depends' debian/control
# 执行dpkg-buildpackage命令构建deb包，该条命令执行完毕后，在上一层目录下就会生成deb包
$ dpkg-buildpackage -us -uc -b
```

可以看到过程其实跟x86下构建deb包类似，只是需要手工下载下source deb包、手工准备下deb包的构建目录、手工安装编译时的依赖包。

构建出arm64v8的deb包后，再将之安装到arm64v8的base docker镜像里，一个arm64v8平台下可使用的docker镜像就生成好了，参考的Dockerfile如下：

```dockerfile
FROM arm64v8/debian:9
COPY curl_7.52.1-5+deb9u9_aarm64.deb /tmp/curl_7.52.1-5+deb9u9_aarm64.deb
RUN dpkg -i /tmp/curl_7.52.1-5+deb9u9_aarm64.deb
...
```

## 构建CentOS/RHEL rpm包

在x86上构建CentOS/RHEL的rpm包也比较简单，过程简述如下：

```bash
# 下面假设要编译curl的rpm包

# 安装gcc、make等编译链工具
$ yum groupinstall -y 'Development tools'
# 安装编译curl依赖的那些软件包
$ yum-builddep -y curl
# 下载构建curl rpm包的源码包
$ yumdownloader --source curl
# 安装构建curl rpm包的源码包
$ rpm -ivh curl-7.29.0-54.el7.src.rpm
# 使用rpmbuild命令构建rpm包，该条命令执行完毕后，在~/rpmbuild/RPMS/x86_64目录下就生成了rpm包
$ cd ~/rpmbuild/SPECS/
$ rpmbuild -bb ./curl.spec
```

对于yum源里有source包的软件包，基本上像上面这样构建就差不多了。

但有些软件厂商并没有提供yum源或yum源里没有相应CPU架构的包，只提供了软件的rpm包，比如[mysql](https://dev.mysql.com/downloads/mysql/)。这个时候需要手工下载source rpm包，并从source rpm包构建出相应cpu架构的rpm包，过程简述如下：

```bash
# 安装gcc、make等编译链工具
$ yum groupinstall -y 'Development tools'

$ curl -O -L 'https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-5.7.27-1.el7.src.rpm'
# 安装编译mysql-community依赖的那些软件包
$ yum-builddep -y ./mysql-community-5.7.27-1.el7.src.rpm
# 安装构建curl rpm包的源码包
$ rpm -ivh ./mysql-community-5.7.27-1.el7.src.rpm
# 使用rpmbuild命令构建rpm包，该条命令执行完毕后，在~/rpmbuild/RPMS/x86_64目录下就生成了rpm包
$ cd ~/rpmbuild/SPECS/
$ rpmbuild -bb ./mysql.spec
```

可以看到过程其实跟x86下构建yum包类似，只是需要手工下载下source rpm包、根据下载的source rpm包安装编译时的依赖包。

构建出arm64v8的rpm包后，再将之安装到arm64v8的base docker镜像里，一个arm64v8平台下可使用的docker镜像就生成好了，参考的Dockerfile如下：

```dockerfile
FROM arm64v8/centos:7
COPY curl-7.29.0-54.el7.aarm64.rpm /tmp/curl-7.29.0-54.el7.aarm64.rpm
RUN dpkg -i /tmp/curl-7.29.0-54.el7.aarm64.rpm
...
```

## 编译障碍

arm64v8平台现在还不是很流行，在编译过程中可能会遇到各种各样的编译报错，这时拿着编译报错信息到google上搜索一下，一般都可以找到解决方案，一般是改改源码使编译通过，或者改改编译参数使之通过，这里涉及工作细节，就不细述了。

## 参考

1. https://www.debian.org/doc/manuals/maint-guide/build.zh-cn.html
2. https://www.debian.org/doc/debian-policy/ch-source.html
3. https://askubuntu.com/questions/324845/whats-the-difference-between-apt-get-install-and-apt-get-build-dep
4. https://dev.mysql.com/downloads/mysql/
5. https://blog.packagecloud.io/eng/2015/04/20/working-with-source-rpms/