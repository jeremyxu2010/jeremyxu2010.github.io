---
title: CentOS7部署k8s集群
tags:
  - docker
  - k8s
categories:
  - devops
date: 2018-01-28 22:07:00+08:00
---

## 环境介绍及准备

操作系统采用Centos7.3 64位，细节如下：

```bash
[root@k8s-master ~]# uname -a
Linux k8s-master 3.10.0-327.el7.x86_64 #1 SMP Thu Nov 19 22:10:57 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
[root@k8s-master ~]# cat /etc/redhat-release
CentOS Linux release 7.2.1511 (Core)
```

### 主机信息

本文准备了三台机器用于部署k8s的运行环境，细节如下：

| 节点及功能                | 主机名        | IP          |
| -------------------- | ---------- | ----------- |
| master、etcd、registry | k8s-master | 10.211.55.6 |
| node1                | k8s-node-1 | 10.211.55.7 |
| node2                | k8s-node-2 | 10.211.55.8 |

设置三台机器的主机名：
master上执行：

```bash
[root@localhost ~]# hostnamectl --static set-hostname k8s-master
```

node1上执行：

```bash
[root@localhost ~]# hostnamectl --static set-hostname k8s-node-1
```

node2上执行：

```bash
[root@localhost ~]# hostnamectl --static set-hostname k8s-node-2
```

在三台机器上设置hosts，均执行如下命令：

```
echo '10.211.55.6    k8s-master
10.211.55.6   etcd
10.211.55.6   registry
10.211.55.7   k8s-node-1
10.211.55.8   k8s-node-2' >> /etc/hosts
```

### 关闭三台机器上的防火墙

```
systemctl disable firewalld.service
systemctl stop firewalld.service
```

## 部署etcd

k8s运行依赖etcd，需要先部署etcd，本文采用yum方式安装：

```
# yum install -y etcd
```

yum安装的etcd默认配置文件在`/etc/etcd/etcd.conf`。编辑配置文件，更改以下信息：

```
ETCD_NAME=master
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379,http://0.0.0.0:4001"
ETCD_ADVERTISE_CLIENT_URLS="http://etcd:2379,http://etcd:4001"
```

启动并验证状态

```bash
# systemctl start etcd
# systemctl enable etcd
#  etcdctl set testdir/testkey0 0
0
#  etcdctl get testdir/testkey0 
0
# etcdctl -C http://etcd:4001 cluster-health
member 8e9e05c52164694d is healthy: got healthy result from http://0.0.0.0:2379
cluster is healthy
# etcdctl -C http://etcd:2379 cluster-health
member 8e9e05c52164694d is healthy: got healthy result from http://0.0.0.0:2379
cluster is healthy
```

扩展：Etcd集群部署参见——<http://www.cnblogs.com/zhenyuyaodidiao/p/6237019.html>

## 部署master

### 安装Docker

```
[root@k8s-master ~]# yum install -y docker
```

#### 配置Docker配置文件

使其允许从registry中拉取镜像。增加如下一行：
OPTIONS='–insecure-registry registry:5000'

```
[root@k8s-master ~]# vim /etc/sysconfig/docker

# /etc/sysconfig/docker

# Modify these options if you want to change the way the docker daemon runs
OPTIONS='--selinux-enabled --log-driver=journald --signature-verification=false'
if [ -z "${DOCKER_CERT_PATH}" ]; then
    DOCKER_CERT_PATH=/etc/docker
fi

OPTIONS='--insecure-registry registry:5000'
```

#### 设置使用阿里云的docker加速器

```
cp -n /lib/systemd/system/docker.service /etc/systemd/system/docker.service
sed -i "s|ExecStart=/usr/bin/dockerd-current|ExecStart=/usr/bin/dockerd-current --registry-mirror=<your accelerate address>|g" /etc/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker.service
```

#### 设置开机自启动并开启服务

```
# systemctl enable docker.service
# systemctl restart docker.service
```

### 安装kubernets

```
[root@k8s-master ~]# yum install -y kubernetes
```

### 搭建及运行registry

```
docker pull registry:2
// 将registry的数据卷与本地关联，便于管理和备份registry数据
docker run -d -p 5000:5000 --name registry -v /data/registry:/var/lib/registry registry:2
```

### 配置并启动kubernetes

在kubernetes master上需要运行以下组件：

* Kubernets API Server
* Kubernets Controller Manager
* Kubernets Scheduler

相应的要更改以下几个配置中带颜色部分信息：

#### 修改`/etc/kubernetes/apiserver`

```
KUBE_API_ADDRESS=”–insecure-bind-address=0.0.0.0”
KUBE_API_PORT=”–port=8080”
KUBE_ETCD_SERVERS=”–etcd-servers=http://etcd:2379“
KUBE_ADMISSION_CONTROL=”–admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota”
```

#### 修改`/etc/kubernetes/config`

```
KUBE_MASTER="–master=http://k8s-master:8080"
```

#### 启动服务并设置开机自启动

```
# systemctl enable kube-apiserver.service
# systemctl start kube-apiserver.service
# systemctl enable kube-controller-manager.service
# systemctl start kube-controller-manager.service
# systemctl enable kube-scheduler.service
# systemctl start kube-scheduler.service
```

## 部署node

### 安装docker

参见master的docker安装步骤

### 安装kubernets

参见master的kubernets安装步骤

### 配置并启动kubernetes

在kubernetes node上需要运行以下组件：

* Kubelet
* Kubernets Proxy

相应的要更改以下几个配置文中信息：

#### 修改 /etc/kubernetes/config

```
KUBE_MASTER="–master=http://k8s-master:8080"
```

#### 修改/etc/kubernetes/kubelet

```
KUBELET_ADDRESS="–address=0.0.0.0"
KUBELET_HOSTNAME="–hostname-override=k8s-node-1" (注意第二台要写 k8s-node-2)
KUBELET_API_SERVER="–api-servers=http://k8s-master:8080"
```

#### 启动服务并设置开机自启动

```
# systemctl enable kubelet.service
# systemctl start kubelet.service
# systemctl enable kube-proxy.service
# systemctl start kube-proxy.service
```

### 查看状态

在master上查看集群中节点及节点状态

```
#  kubectl -s http://k8s-master:8080 get node
NAME         STATUS    AGE
k8s-node-1   Ready     3m
k8s-node-2   Ready     16s
# kubectl get nodes
NAME         STATUS    AGE
k8s-node-1   Ready     3m
k8s-node-2   Ready     43s
```

至此，已经搭建了一个kubernetes集群。

## 创建Overlay网络——Flannel

### 安装Flannel

在master、node上均执行如下命令，进行安装

```
# yum install -y flannel
```

### 配置Flannel

master、node上均编辑/etc/sysconfig/flanneld，修改以下配置：

```
# etcd url location.  Point this to the server where etcd runs
FLANNEL_ETCD_ENDPOINTS="http://etcd:2379"
```

### 配置etcd中关于flannel的key

Flannel使用Etcd进行配置，来保证多个Flannel实例之间的配置一致性，所以需要在etcd上进行如下配置：

```
# etcdctl mk /atomic.io/network/config '{ "Network": "10.0.0.0/16" }'
{ "Network": "10.0.0.0/16" }
```

### 启动

启动Flannel之后，需要依次重启docker、kubernete。
在master执行：

```
systemctl enable flanneld.service 
systemctl start flanneld.service 
service docker restart
systemctl restart kube-apiserver.service
systemctl restart kube-controller-manager.service
systemctl restart kube-scheduler.service

```

在node上执行：

```
systemctl enable flanneld.service 
systemctl start flanneld.service 
service docker restart
systemctl restart kubelet.service
systemctl restart kube-proxy.service
```

### Flannel网络

Flannel算是k8s里最简单的网络了，这里找到[一篇文章](http://tonybai.com/2017/01/17/understanding-flannel-network-for-kubernetes/)可以帮忙理解Flannel网络。

## 测试

```
# docker pull nginx # 从外网registry拉一个nginx镜像过来
# docker tag nginx registry:5000/nginx # 为本地镜像打tag
# docker push registry:5000/nginx # 推送至本地registry
# docker rmi registry:5000/nginx # 删除本地镜像

cat << EOF >nginx.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry:5000/nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 400m
EOF
# kubectl create -f nginx.yaml #创建nginx-dpmt部署

cat << EOF >nginx-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  labels:
    app: nginx-svc
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30088
EOF
# kubectl create -f nginx-svc.yaml # 创建nginx-svc服务
# kubectl describe service nginx-svc
Name:			nginx-svc
Namespace:		default
Labels:			app=nginx-svc
Selector:		app=nginx
Type:			NodePort
IP:			10.254.53.185
Port:			<unset>	80/TCP
NodePort:		<unset>	30088/TCP
Endpoints:		10.0.19.2:80,10.0.4.2:80
Session Affinity:	None
No events.
# curl http://k8s-node-1:30088/ # 通过nodePort测试nginx服务
```

测试过程中遇到两个问题：

1. pod服务一直处于 ContainerCreating状态，后来参考[这里](http://www.voidcn.com/article/p-kpjywccp-bny.html)，安装了rhsm相关的包解决了。

2. `nginx-svc.yaml`文件中`spec.selector.app`的名称与`nginx.yaml`中的`spec.template.metadata.labels.app`不一致，这个导致一直无法通过NodePort访问服务。

## 参考
1. [http://qinghua.github.io/kubernetes-deployment/](http://qinghua.github.io/kubernetes-deployment/)
2. [http://wdxtub.com/2017/06/05/k8s-note/](http://wdxtub.com/2017/06/05/k8s-note/)
3. [https://jimmysong.io/kubernetes-handbook/guide/accessing-kubernetes-pods-from-outside-of-the-cluster.html](https://jimmysong.io/kubernetes-handbook/guide/accessing-kubernetes-pods-from-outside-of-the-cluster.html)
4. [http://tonybai.com/2017/01/17/understanding-flannel-network-for-kubernetes/](http://tonybai.com/2017/01/17/understanding-flannel-network-for-kubernetes/)
5. [http://www.cnblogs.com/puroc/p/6297851.html](http://www.cnblogs.com/puroc/p/6297851.html)
6. [https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/](https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/)
