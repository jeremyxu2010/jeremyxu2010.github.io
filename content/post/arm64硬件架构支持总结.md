---
title: arm64硬件架构支持总结
tags:
  - docker
  - k8s
  - cpp
  - blade
categories:
  - devops
date: 2018-12-01 18:07:00+08:00
typora-root-url: ../../static/
typora-copy-images-to: ../../static/images/20181201/
---

自从中兴事件后，国家开始在政策上大力支持国产硬软件，甚至在某些项目投标要求上都加上了隐性条件，软件系统必须能在国产硬软件基础上运行。而国产硬软件一般也就是代指arm64硬件架构及在此基础上的linux定制发行版，最近一周刚好完成了一些支持arm64硬件架构的工作，这里总结一下。

## arm64的软件源

国产操作系统一般基于比较成熟的ubuntu或centos，算是这些个发行版的arm64衍生版，所以操作上跟x86上的ubuntu或centos差不多，可能唯一区别是软件源有些不同。

一些常用的arm64软件源地址如下：

centos的arm64 yum源地址是：`https://mirrors.aliyun.com/centos-altarch/`

ubuntu的arm64 apt源地址是： `https://mirrors.aliyun.com/ubuntu-ports/`

epel的arm64 yum源地址是：`https://mirrors.aliyun.com/epel`

[yum源](https://www.jianshu.com/p/d8573f9d1f96)、[apt源](https://www.jianshu.com/p/fb337765c2c2)的配置方法参考网上的文档就可以了。

其实很多常用软件都有arm64的软件源，看看`https://opsx.alibaba.com/mirror`，软件源里有`aarch64`之类的目录，就是支持arm64硬件架构的软件源。

## k8s支持arm64架构

其实k8s要支持arm64还算是比较简单，由于Go语言里进行跨平台交叉编译很简单，所以k8s核心的一些二进制文件及docker镜像均有arm64架构的，将正常部署的k8s集群中这些二进制文件都替换成arm64架构的，k8s也就可以在arm64上正常运行了。比如：

etcd：`https://github.com/etcd-io/etcd/releases`（二进制文件名中带有aarch64的就是arm64架构的二进制文件）

kubernetes: `https://kubernetes.io/docs/setup/release/notes/#client-binaries`, `https://kubernetes.io/docs/setup/release/notes/#server-binaries`, `https://kubernetes.io/docs/setup/release/notes/#node-binaries`（二进制文件名中带有arm64的就是arm64架构的二进制文件）

docker： `https://mirrors.aliyun.com/docker-ce/linux/`（centos, ubuntu都有对应的docker arm64软件源）

default cni plugin(flannel): `https://github.com/containernetworking/cni/releases`，`https://github.com/coreos/flannel/releases`(二进制文件名中带有arm64的就是arm64架构的二进制文件)

calico：`https://github.com/projectcalico/cni-plugin/releases`

pause镜像：`gcr.io/google_containers/pause-arm64`

metrics-server镜像：`gcr.io/google_containers/metrics-server-arm64`

coredns镜像：`coredns/coredns:coredns-arm64`

kubernetes-dashboard镜像：`gcr.io/google_containers/kubernetes-dashboard-arm64`

flannel镜像：`gcr.io/google_containers/flannel-arm64`

kube-state-metrics镜像：`gcr.io/google_containers/kube-state-metrics-arm64`

其它一些arm64镜像可参考这里：`https://hub.docker.com/u/googlecontainer/`，`https://hub.docker.com/r/arm64v8/`。

## c++程序支持arm64架构

系统中还有一些c++写的程序，需要在arm64架构的服务器上重新编译一下，编译方法也比较简单，就是用如下这些命令：

```bash
sudo apt-get install xxxx-dev # 安装某些依赖库的开发包
cd $cpp_prog_dir
./configure && make && make install # 重新编译c++程序
```

在编译c++程序的过程中还接触了一个[开源的构建系统blade](https://github.com/chen3feng/typhoon-blade)，研究了下，发现功能还挺强大的，不过文档太简略了点，很多功能要拿示例与文档对照看才能想明白，下面将使用过程中一些要点记录一下。

### blade安装

很奇怪官方文档连怎么安装都没详细说明...

```bash
brew install scons #安装scons
git clone https://github.com/chen3feng/typhoon-blade.git
cd typhoon-blade
bash ./install
source ~/.profile # source ~/.zshrc
```

### 一个c++构建项目

```bash
mkdir -p ~/workspace/proj1
cd ~/workspace/proj1
touch BLADE_ROOT # 必须在项目根目录创建一个BLADE_ROOT文件
vim module1/test.cpp # 编写一个简单的c++文件
```

创建该模块的编译文件

```bash
vim module1/BUILD

cc_binary(
    name='module1',
    srcs=['./test.cpp'],
    deps=['#pthread'] # 该c++程序运行时需要动态链接pthread
)

blade build module1 # 编译module1
```

编译文件的书写方法参见[这里](https://github.com/chen3feng/typhoon-blade/blob/master/doc/build_file_zn_CN.md)，比较简单，只有deps的配置特殊一点：

deps的允许的格式：

- "//path/to/dir/:name" 其他目录下的target，path为从BLADE_ROOT出发的路径，name为被依赖的目标名。看见就知道在哪里。
- ":name" 当前BUILD文件内的target， path可以省略。
- "#pthread" 系统库。直接写#跟名字即可。

当自己的多个模块间存在依赖时，按照上述规则书写deps配置即可，blade自己会分析依赖关系，如下：

```bash
vim module1/BUILD

cc_binary(
    name='module1',
    srcs=['./test.cpp'],
    deps=['#pthread', '/module2:module2'] # 该c++程序编译时会链接module2, 同时动态链接系统中的pthread库
)

vim module2/BUILD

cc_binary(
    name='module2',
    srcs=['./mod2.cpp']
)

blade build module1 # 编译module1
```

### 静态链接系统库

有时候希望编译出的二进制程序尽量少依赖系统中的动态链接库，这样可以保证编出的二进制有更好的可移植性，不会由于部署的目标系统上没有某个动态链接库导致程序执行失败，这时可以使用prebuilt特性。这个在官方文档中并没有详实的例子说明，只有文档中一句话带过。

> prebuilt=True 主要应用在thirdparty中从rpm包解来的库，使用这个参数表示不从源码构建。对应的二进制文件必须存在 lib{32,64}_{release,debug} 这样的子目录中。不区分debug/release时可以只有两个实际的目录。

用法如下：

```bash
vim module1/BUILD

cc_binary(
    name='module1',
    srcs=['./test.cpp'],
    deps=['/gflags:gflags'] # 该c++程序编译时会链接gflags
)

vim gflags/BUILD

cc_library(
    name = 'gflags',
    prebuilt = True
)

mkdir gflags/{lib64_release, lib64_debug} # 在这两个目录中均放入从其实地方得到的gflags静态库文件

blade build module1 # 编译module1
```

编译出来的二进制文件可用`otool -L`或`ldd`命令查看其依赖的动态链接库等信息。

除了c++代码，blade还可以编译protobuf、thrift、java、scala、python等，只需要写不同的编译文件即可，可参考[这里](https://github.com/chen3feng/typhoon-blade/blob/master/doc/build_file_zn_CN.md)。

通过修改blade的配置文件可调整编译过程的一些参数，可参考[这里](https://github.com/chen3feng/typhoon-blade/blob/master/doc/config_files_zn_CN.md)。

## 总结

整个arm64硬件架构支持的调整工作并不是太难，不过在编译c++程序时还是遇到了一些困难，这时才发现这一块过度依赖公司内部框架及编译工具，开发人员并没有深入理解框架及编译工具的实现原理，当发现要为其它平台做一些适配工作时，顿时处于无法掌控的境地，很是被动。这些当初不考虑实现原理，用得爽不知其所以然的模块都属于迟早要攻克的技术债务啊。

## 参考

1. https://opsx.alibaba.com/mirror?lang=zh-CN
2. https://kubernetes.io/docs/setup/
3. https://github.com/chen3feng/typhoon-blade/tree/master/doc
4. https://github.com/chen3feng/typhoon-blade/tree/master/example
5. https://www.jianshu.com/p/e3fd94617fb3



