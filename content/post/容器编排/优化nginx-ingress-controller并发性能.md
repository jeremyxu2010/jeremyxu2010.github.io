---
title: 优化nginx-ingress-controller并发性能
tags:
  - nginx
  - kubernetes
  - http
  - tcp
  - conntrack
categories:
  - 容器编排
date: 2019-11-10 18:35:00+08:00
---

这两天遇到一个很有意思的应用场景：有一个业务应用部署在kubernetes容器中，如果将该应用以Kubernetes Service NodePort暴露出来，这时测试人员测得应用的页面响应性能较高，可以达到2w多的QPS；而将这个Kubernetes Service再用Ingress暴露出来，测试人员测得的QPS立马就较得只有1w多的QPS了。这个性能开销可以说相当巨大了，急需进行性能调优。花了一段时间分析这个问题，终于找到原因了，这里记录一下。

## 问题复现

问题是在生产环境出现了，不便于直接在生产环境调参，这里搭建一个独立的测试环境以复现问题。

首先在一台16C32G的服务器上搭建了一个单节点的kubernetes集群，并部署了跟生产环境一样的nginx-ingress-controller。然后进行基本的调优，以保证尽量与生产环境一致，涉及的调优步骤如下：

1. ClusterIP使用性能更优异的ipvs实现
   ```bash
   $ yum install -y ipset
   
   $ cat << 'EOF' > /etc/sysconfig/modules/ipvs.modules
   #!/bin/bash
   ipvs_modules=(ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4)
   for kernel_module in ${ipvs_modules[*]}; do
       /sbin/modinfo -F filename ${kernel_module} > /dev/null 2>&1
       if [ $? -eq 0 ]; then
           /sbin/modprobe ${kernel_module}
       fi
   done
   EOF
   
   $ chmod +x /etc/sysconfig/modules/ipvs.modules
   
   $ /etc/sysconfig/modules/ipvs.modules
   
   $ kubectl -n kube-system edit cm kube-proxy
   ......
   mode: "ipvs"
   ......
   
   $ kubectl -n kube-system get pod -l k8s-app=kube-proxy | grep -v 'NAME' | awk '{print $1}' | xargs kubectl -n kube-system delete pod
   
   $ iptables -t filter -F; iptables -t filter -X; iptables -t nat -F; iptables -t nat -X;
   ```
   
2. flannel使用host-gw模式
   ```bash
   $ kubectl -n kube-system edit cm kube-flannel-cfg
   ......
         "Backend": {
           "Type": "host-gw"
         }
   ......
   
   $ kubectl -n kube-system get pod -l k8s-app=flannel  | grep -v 'NAME' | awk '{print $1}' | xargs kubectl -n kube-system delete pod
   ```

3. 集群node节点及客户端配置内核参数
   ```bash
   $ cat << EOF >> /etc/sysctl.conf
   net.core.somaxconn = 655350
   net.ipv4.tcp_syncookies = 1
   net.ipv4.tcp_timestamps = 1
   net.ipv4.tcp_tw_reuse = 1
   net.ipv4.tcp_fin_timeout = 30
   net.ipv4.tcp_max_tw_buckets = 5000
   net.nf_conntrack_max = 2097152
   net.netfilter.nf_conntrack_max = 2097152
   net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15
   net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
   net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
   net.netfilter.nf_conntrack_tcp_timeout_established = 1200
   EOF
   
   $ sysctl -p --system
   ```
   
4. 集群node节点及客户端配置最大打大文件数
   ```bash
   $ ulimit -n 655350

   $ cat /etc/sysctl.conf
   ...
   fs.file-max=655350
   ...

   $ sysctl -p --system

   $ cat /etc/security/limits.conf
   ...
   *	hard	nofile	655350
   *	soft	nofile	655350
   *	hard	nproc	6553
   *	soft	nproc	655350
   root hard nofile 655350
   root soft nofile 655350
   root hard nproc 655350
   root soft nproc 655350
      ...
      
   $ echo 'session required pam_limits.so' >> /etc/pam.d/common-session
   ```

然后在集群中部署了一个测试应用，以模拟生产环境上的业务应用：

```bash
$ cat web.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: web
  name: web
  namespace: default
spec:
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - image: nginx:1.17-alpine
        imagePullPolicy: IfNotPresent
        name: nginx
        resources:
          limits:
            cpu: 60m
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: web
  name: web
  namespace: default
spec:
  externalTrafficPolicy: Cluster
  ports:
  - nodePort: 32380
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: web
  sessionAffinity: None
  type: NodePort
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/connection-proxy-header: "keep-alive"
  labels:
    app: web
  name: web
  namespace: default
spec:
  rules:
  - host: web.test.com
    http:
      paths:
      - backend:
          serviceName: web
          servicePort: 80
        path: /
        
$ kubectl apply -f web.yaml
```

**注意：这里故意将pod的cpu限制在60m，这样一个pod副本可同时处理的页面请求数有限，以模拟真正的业务应用**

接下来简单测试一下：

```bash
# 使用httpd-utils中的ab命令直接压测Kubernetes Service NodePort，并发请求数为10000，总发出1000000个请求，此时测得QPS为2.4w
$ ab -r -n 1000000 -c 10000 http://${k8s_node_ip}:32380/ 2>&1 | grep 'Requests per second'
Requests per second:    24234.03 [#/sec] (mean)

# 再在客户端的/etc/hosts中将域名web.test.com指向${k8s_node_ip}，通过Ingress域名压测业务应用，测得QPS为1.1w
$ ab -r -n 1000000 -c 10000 http://web.test.com/ 2>&1 | grep 'Requests per second'
Requests per second:    11736.21 [#/sec] (mean)
```

可以看到访问Ingress域名后，确实QPS下降很明显，跟生产环境的现象一致。

## 分析原因

我们知道，nginx-ingress-controller的原理实际上是扫描Kubernetes集群中的Ingress资源，根据Ingress资源的定义自动为每个域名生成一段nginx虚拟主机及反向代理的配置，最后由nginx读取这些配置，完成实际的HTTP请求流量的处理，整个HTTP请求链路如下：

```
          client    ->    nginx    ->    upstream(kubernetes service)    ->    pods  
```

nginx的实现中必然要对接收的HTTP请求进行7层协议解析，并根据请求信息将HTTP请求转发给upstream。

而`client`直接请求`kubernetes service`有不错的QPS值，说明`nginx`这里存在问题。

## 解决问题

虽说nginx进行7层协议解析、HTTP请求转发会生产一些性能开销，但`nginx-ingress-controller`作为一个kubernetes推荐且广泛使用的`ingress-controller`，参考业界的测试数据，nginx可是可以实现百万并发HTTP反向代理的存在，照理说才一两万的QPS，其不应该有这么大的性能问题。所以首先怀疑`nginx-ingress-controller`的配置不够优化，需要进行一些调优。

我们可以从`nginx-ingress-controller` pod中取得nginx的配置文件，再参考[nginx的常用优化配置](https://blog.csdn.net/tiantiandjava/article/details/79969909)，可以发现有些优化配置没有应用上。

```bash
kubectl -n kube-system exec -ti nginx-ingress-controller-xxx-xxxx cat /etc/nginx/nginx.conf > /tmp/nginx.conf
```

对比后，发现`server context`中`keepalive_requests`、`keepalive_timeout`，`upstream context`中的`keepalive`、`keepalive_requests`、`keepalive_timeout`这些配置项还可以优化下，于是参考[nginx-ingress-controller的配置方法](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/)，这里配置了下：

```bash
$ kubectl -n kube-system edit configmap nginx-configuration
...
apiVersion: v1
data:
  keep-alive: "60"
  keep-alive-requests: "100"
  upstream-keepalive-connections: "10000"
  upstream-keepalive-requests: "100"
  upstream-keepalive-timeout: "60"
kind: ConfigMap
...
```

再次压测：

```bash
$ ab -r -n 1000000 -c 10000 http://web.test.com/ 2>&1 | grep 'Requests per second'
Requests per second:    22733.73 [#/sec] (mean)
```

此时发现性能好多了。

## 分析原理

### 什么是Keep-Alive模式？

HTTP协议采用请求-应答模式，有普通的非KeepAlive模式，也有KeepAlive模式。

非KeepAlive模式时，每个请求/应答客户和服务器都要新建一个连接，完成 之后立即断开连接（HTTP协议为无连接的协议）；当使用Keep-Alive模式（又称持久连接、连接重用）时，Keep-Alive功能使客户端到服 务器端的连接持续有效，当出现对服务器的后继请求时，Keep-Alive功能避免了建立或者重新建立连接。

### 启用Keep-Alive的优点

启用Keep-Alive模式肯定更高效，性能更高。因为避免了建立/释放连接的开销。下面是RFC 2616 上的总结：

* TCP连接更少，这样就会节约TCP连接在建立、释放过程中，主机和路由器上的CPU和内存开销。

* 网络拥塞也减少了，拿到响应的延时也减少了

* 错误处理更优雅：不会粗暴地直接关闭连接，而是report，retry

### 性能大提升的原因

压测命令`ab`并没有添加`-k`参数，因此`client->nginx`的HTTP处理并没有启用Keep-Alive。

但由于`nginx-ingress-controller`配置了`upstream-keepalive-connections`、`upstream-keepalive-requests`、`upstream-keepalive-timeout`参数，这样`nginx->upstream`的HTTP处理是启用了Keep-Alive的，这样到Kuberentes Service的TCP连接可以高效地复用，避免了重建连接的开销。

DONE.

## 参考

1. https://www.jianshu.com/p/024b33d1a1a1
2. https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
3. https://zhuanlan.zhihu.com/p/34052073
4. http://nginx.org/en/docs/http/ngx_http_core_module.html#keepalive_requests
5. http://nginx.org/en/docs/http/ngx_http_upstream_module.html#keepalive
6. https://kiswo.com/article/1018