---
title: 基于Docker for macOS的Kubernetes本地环境搭建与应用部署
author: Jeremy Xu
tags:
  - k8s
  - devops
categories:
  - devops
date: 2018-05-05 23:00:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20180505
---

最近的工作跟微服务有关，偶然在网上发现一个用k8s写微服务的[小例子](https://github.com/GoogleContainerTools/skaffold/tree/master/examples/microservices)，觉得这样写微服务真的好简单，都不用在程序框架层面实现服务注册与服务发现了，这个后面可以好好研究一下。在使用这种方式写微服务前，需要在个人开发机上搭建k8s集群。我的开发机是macOS系统，今天研究了一下，找到一种极为简易的方法，终于不用为搭一个开发用的k8s集群而专门启动虚拟机了，这里记录一下。

## 安装Docker for macOS

### 安装

下载最新的[Docker for Mac Edge 版本](https://download.docker.com/mac/edge/Docker.dmg)，跟普通mac软件一样安装，然后运行它，会在右上角菜单栏看到多了一个鲸鱼图标，这个图标表明了 Docker 的运行状态。

![image-20180506034957469](/images/20180505/image-20180506034957469.png)

### 配置镜像加速地址

鉴于国内网络问题，国内从 Docker Hub 拉取镜像有时会遇到困难，此时可以配置镜像加速器。Docker 官方和国内很多云服务商都提供了国内加速器服务。

点击设置菜单

![image-20180506035102081](/images/20180505/image-20180506035102081.png)

设置镜像加速地址

![image-20180506035306657](/images/20180505/image-20180506035306657.png)

### 检查docker环境

可执行以下命令检查docker环境

```bash
$ docker --version
Docker version 18.05.0-ce-rc1, build 33f00ce
$ docker-compose --version
docker-compose version 1.21.0, build 5920eb0
$ docker-machine --version
docker-machine version 0.14.0, build 89b8332
# 如果 docker version、docker info 都正常的话，可以尝试运行一个 Nginx 服务器：
$ docker run -d -p 80:80 --name webserver nginx
# 访问一下Nginx服务器
$ curl http://localhost
# 停止 Nginx 服务器并删除
$ docker stop webserver
$ docker rm webserver
```



## 搭建k8s本地开发环境

### 启用k8s

点击设置菜单

![image-20180506035102081](/images/20180505/image-20180506035102081.png)



点击启动k8s的checkbox，这里会拉取比较多的镜像，可能要等好一会儿。

![image-20180506035603276](/images/20180505/image-20180506035603276.png)

### 检查k8s环境

可执行以下命令检查k8s环境

```bash
$ kubectl get nodes
NAME                 STATUS    ROLES     AGE       VERSION
docker-for-desktop   Ready     master    3h        v1.9.6
$ kubectl cluster-info
Kubernetes master is running at https://localhost:6443
KubeDNS is running at https://localhost:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### 部署kubernetes-dashboard服务

按以下步骤部署k8s-dashboard服务

```bash
$ kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
# 开发环境推荐用NodePort的方式访问dashboard，因此编辑一下该部署
$ kubectl -n kube-system edit service kubernetes-dashboard
# 这里将type: ClusterIP修改为type: NodePort
# 获取dashboard服务暴露的访问端口
$ kubectl -n kube-system get service kubernetes-dashboard
NAME                   TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
kubernetes-dashboard   NodePort   10.98.82.248   <none>        443:31241/TCP   2h
```

按上述输出，dashboard服务暴露的访问端口是31241，因此可以用浏览器访问`https://localhost:31241/`，我们可以看到登录界面

![image-20180506041543930](/images/20180505/image-20180506041543930.png)

此时可暂时直接跳过，进入到控制面板中

![image-20180506041643252](/images/20180505/image-20180506041643252.png)

## 使用k8s本地开发环境

这里尝试用[Skaffold](https://github.com/GoogleContainerTools/skaffold)往本地开发环境部署微服务应用。

### 安装Skaffold

```bash
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-darwin-amd64 && chmod +x skaffold && sudo mv skaffold /usr/local/bin
```

### 获取微服务示例代码

```bash
git clone https://github.com/GoogleContainerTools/skaffold
cd skaffold/examples/microservices
```

### 部署到本地k8s环境

```bash
skaffold run
# 获取leeroy-web服务暴露的访问端口
$ kubectl get service leeroy-web
NAME         TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
leeroy-web   NodePort   10.98.162.88   <none>        8080:30789/TCP   56m
```

按上述输出，dashboard服务暴露的访问端口是30789，因此可以用浏览器访问`http://localhost:30789/`

### k8s的dashboard中检查部署

![image-20180506042800026](/images/20180505/image-20180506042800026.png)

### 删除无用的docker实例及镜像

用skaffold反复进行部署时会产生一些无用的docker实例及镜像，这里用一个脚本将它们删除

```bash
# 删除停止或一直处于已创建状态的实例
docker ps --filter "status=exited"|sed -n -e '2,$p'|awk '{print $1}'|xargs docker rm
docker ps --filter "status=created"|sed -n -e '2,$p'|awk '{print $1}'|xargs docker rm
# 删除虚悬镜像
docker image prune --force
# 删除REPOSITORY是长长uuid的镜像
docker images | sed -n -e '2,$p'|awk '{if($1 ~ /[0-9a-f]{32}/) print $1":"$2}'|xargs docker rmi
# 删除TAG是长长uuid的镜像
docker images | sed -n -e '2,$p'|awk '{if($2 ~ /[0-9a-f]{64}/) print $1":"$2}'|xargs docker rmi
```

OVER

## 参考

1. https://juejin.im/post/5a5cbad5518825734216e14f
2. https://yeasy.gitbooks.io/docker_practice/content/install/mac.html
3. https://github.com/kubernetes/dashboard/wiki/Accessing-Dashboard---1.7.X-and-above
4. https://yeasy.gitbooks.io/docker_practice/content/image/list.html
5. https://github.com/GoogleContainerTools/skaffold
