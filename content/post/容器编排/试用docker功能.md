---
title: 试用docker功能
tags:
  - linux
  - docker
categories:
  - 容器编排
date: 2016-06-19 23:19:00+08:00
---
花了好几天，终于看完了《Docker进阶与实战》，今天终于抽出时间来实践一把，这里把今天实战的过程记录一下。

## 安装Docker

因为我使用的MacOS系统，查阅文档找到在MacOS系统中最简易安装办法如下。

```bash
#使用Homebrew Cask安装virtualbox
brew cask install virtualbox
#使用Homebrew安装docker-machine
brew install docker-machine
#使用docker-machine创建名叫mydockerhost的docker主机
docker-machine create --driver=virtualbox mydockerhost
```

这里创建docker主机时要从github下载一个boot2docker.iso的镜像，下得很慢，我使用axel加速了一下

```bash
wget https://github.com/boot2docker/boot2docker/releases/download/v1.11.2/boot2docker.iso
# 这里会进行几次重定向，最后重定向到amazon上s3的一个地址，拷贝这个地址，然后中止下载，然后用axel来多线程下载
axel -o boot2docker.iso -n 20 "${amazon_s3_url}"
#最后将下载的iso移至docker的缓存目录
mv boot2docker.iso ~/.docker/machine/cache/boot2docker.iso
#重新创始docker主机
docker-machine create --driver=virtualbox mydockerhost
#登入docker主机
docker-machine ssh mydockerhost
```

## 加速docker抓取镜像

默认安装的docker主机抓取官方镜像是从国外官方registry上下载的，天朝的网速怎么受得了。因此花了些时间找加速的registry。

首先就是试用daocloud的加速服务。要使用daocloud的加速服务需要在daocloud上安装它的监控程序。安装过程倒是很简单，就是在docker主机上执行命令。

```bash
curl -sSL https://get.daocloud.io/daomonit/install.sh | sh -s ${你daocloud用户所对应的一长串字符}
```

但我实际测试发现daocloud的加速服务拉取像ubuntu这样的热门镜像比较快，但提取像jetty:9.2.11-jre7这样的冷门镜像就相当慢，弃之。

然后试用灵雀云alauda.cn的加速服务，注册它的帐户后，点“免费加速器”，会看到你的加速地址，形如`http://${你的帐户名}.m.alauda.cn`，然后就修改docker主机里的`/var/lib/boot2docker/profile`文件，在它的`EXTRA_ARGS`参数里加入`--registry-mirror=http://${你的帐户名}.m.alauda.cn`，然后重启docker主机，再次登入docker主机。根据我实际测试，同样拉取像ubuntu这样的热门镜像比较快，但提取像jetty:9.2.11-jre7这样的冷门镜像就相当慢，弃之。

最后试用阿里云的加速服务，同样注册阿里云帐户登入`https://cr.console.aliyun.com`之后，点击`加速器`，它同样给出了加速地址，形如`https://xxxxx.mirror.aliyuncs.com`，它也是修改`EXTRA_ARGS`参数法，就不赘述了。经测试无论拉取的是ubuntu之类热门镜像，还是jetty:9.2.11-jre7这样的冷门镜像，速度都相当快，点赞。

但看过三者的功能后，觉得从三个厂商提供的功能来看是daocloud>alauda>aliyun，aliyun仅仅提供了一个镜像构建管理，而alauda还提供了服务的编排及存储卷管理，daocloud更甚之还提供了管理集群的docker主机功能。阿里云在docker这方面是落后了，好在阿里云有钱基础设施如带宽是好的。

## docker常用命令

接下来就试用一下docker常用的一些命令

* docker pull centos:6 拉取版本为6的centos镜像
* docker pull nginx 拉取版本为latest的nginx镜像
* docker pull -a centos 拉取所有版本的centos镜像
* docker pull registry.aliyuncs.com/alicloudhpc/toolkit 从其它registry上拉取某个镜像的latest版本
* docker push ${你自己的registry地址}/my-centos:6 推送一个镜像至registry私服
* docker run -t -i --rm centos:6 /bin/bash  以交互式方式启动一个centos容器，可在bash里尝试各种命令操作，容器退出时会删除容器
* docker run -d --name=nginx nginx 以后台方式启动一个名称为nginx的nginx容器
* docker logs ${containerId} 在外部查看一个容器控制台输出
* docker attach ${containerId} 进入容器查看容器控制台输出，注意此时要返回外部千万不能按`Ctrl+C`，而应该按`Ctrl-P Ctrl-Q`，按`Ctrl+C`容器就停止了
* docker run -d -p 8000:80 nginx 将容器的80映射至docker主机的8000端口
* docker run -d -p 8000:80 -v /tmp/htmlfiles:/usr/share/nginx/html:ro nginx 将docker主机的/tmp/htmlfiles目录只读挂载至容器的/usr/share/nginx/html目录
* docker run --link db -d --name=nginx nginx 启动一个名称为nginx的nginx容器，它链接一个名叫db的容器（即需要使用其它容器提供的服务）
* docker commit ${containerId} my-centos:6 将某个容器提交为镜像，镜像的版本为6
* docker build -t my-centos:6 . 在当前目录下的Dockerfile构建镜像，镜像的名字为my-centos，版本为6

如果不涉及服务编排及docker主机集群基本就上面这些命令了

## 构建自己的镜像

为了易于版本管理，一般构建自己的镜像还是推荐编写Dockerfile的办法。编写Dockerfile比较简单，熟悉linux命令就好办了，我试着也写了一个，地址在[这里](https://github.com/jeremyxu2010/my-centos6)，写的过程中要注意控制最终镜像的大小，比如Dockerfile的行数要少一些，因为每一条命令后都会在存储上产生一个layer，安装软件包之后要注意及时清理cache等。

然后本地环境试着构建一下

```bash
cd my-centos6
docker build -t my-centos6 .
```

很好，一次就成功了。接下来到阿里云的镜像管理里试一下在线构建镜像。

点"创建镜像仓库"，在出现的表单里填写该镜像的信息，其中“代码源”的地址我选的github，构建设置我选择“master”分支的代码构建镜像版本为“latest”，“6”tag的代码构建镜像版本为“6”。镜像仓库创建好了之后，点“立即构建”，两个镜像就会快速构建，速度很快。构建完毕之后，该镜像就可以在`dev.aliyun.com`容器Hub里搜索到。也即别人可以通过`docker pull registry.aliyuncs.com/jeremyxu2010/my-centos6`抓取到我制作的镜像。

## 接下来的计划

今天只是简单地试用了docker的功能，接下来抽时间实践一下docker里服务编排及docker主机集群功能。

## 参考

* `https://docs.docker.com/machine/get-started/`
* `https://segmentfault.com/a/1190000000751601`


