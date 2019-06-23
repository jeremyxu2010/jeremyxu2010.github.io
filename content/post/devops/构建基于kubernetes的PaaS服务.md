---
title: 构建基于kubernetes的PaaS服务
author: Jeremy Xu
tags:
  - kubernetes
  - redis
  - helm
  - operator
  - networkpolicy
categories:
  - devops
date: 2019-06-11 20:40:00+08:00
---

工作中需要向外部提供一些诸如MySQL、Redis、MongoDB、Kafka之类的基础PaaS服务。以前每做一个PaaS都要自己去实现工作节点管理、实例调度、实例运维、实例监控等功能模块，实在是太累。这次花了些时间想了下，感觉基于Kubernetes做这个会简单很多。下面概要性地梳理下基于Kubernetes构建基础PaaS服务的过程。

## 构建基础PaaS服务

### 将基础PaaS服务部署进kubernetes

假设现在一套生产可用的Kubernetes集群就绪了，第一步要做的是将目标基础服务部署进kubernetes。大体有三种方案：

1. 使用kubernetes的yaml描述文件部署
2. 使用helm chart部署
3. 使用operator部署

第一种方法太琐碎，长长的yaml描述文件也不方便维护。

第三种方法是现在社区最推荐的，但实际执行后，发现问题还比较多：

1）目前网上的operator质量参差不齐，很多是半成品，有一些官方维护的operator质量虽说还可以，但跟官方推荐的商业版软件绑定太死 

2）operator这种方案定制扩展性不太好，一旦operator定义自定义资源不能完全覆盖需求，需要定制时就需要改operator的源码，而且多个operator的代码风格也非常不一致，维护起来困难

第二种方法目前只能解决基础软件的部署、升级、卸载，其它运维相关的功能如备份还原等需要另外开发。

综合考虑，最终选择了第二种方法。第二种方法所要用到的chart在网上很方便地就可以搜索，可能参考[官方的helm chart仓库](https://github.com/helm/charts/tree/master/stable)。

例如借助[redis-ha](https://github.com/helm/charts/tree/master/stable/redis-ha)这个chart，我们可以很方便地将redis主从集群部署进kubernetes集群，参考命令如下：

```bash
helm install stable/redis-ha
```

当然如果有一些特殊需求，需要把官方提供的chart进行一些定制。

### 屏蔽底层集群

为了保证PaaS服务的高可用，上面我们部署redis时，使用的是[redis-ha](https://github.com/helm/charts/tree/master/stable/redis-ha)这个chart，其部署出的redis是高可用的主从集群。但PaaS服务的使用方以非集群模式的方便访问redis是最方便的。为了方便使用方，这里我们可以部署redis智能代理，以屏蔽底层的集群细节，让使用方像用单节点redis实例一样使用我们提供的redis服务。在网上搜索了一下，最后选择了[predixy](https://github.com/joyieldInc/predixy)这款redis智能代理，这款redis智能代理的优点是性能好，支持主从哨兵集群和分片集群，配置简单方便。如何将predixy打包成docker镜像就不具体说了，这样列一下其代理redis主从集群的核心配置：

`predixy.conf`

```
Bind 0.0.0.0:7617
WorkerThreads 4

Authority {
    Auth "123456" {
        Mode write
    }
    Auth "#a complex password#" {
        Mode admin
    }
}

SentinelServerPool {
    Databases 16
    Hash crc16
    HashTag "{}"
    Distribution modula
    MasterReadPriority 60
    StaticSlaveReadPriority 50
    DynamicSlaveReadPriority 50
    RefreshInterval 1
    ServerTimeout 1
    ServerFailureLimit 10
    ServerRetryTimeout 1
    KeepAlive 120
    Sentinels {
        + instance01-redis-ha:26379
    }
    Group mymaster {
    }
}
```

### 使kubernetes集群外能访问PaaS服务

PaaS服务已在kubernetes里部署好了，也可以以一种简单的方式向使用方提供服务了，接下来需要将PaaS服务暴露出来。我们知道如果是简单的http服务，要将服务暴露出来，直接使用kubernetes里的Ingress就可以了，但绝大部分基础PaaS服务都是TCP或UDP对外提供服务的，而很可惜我们所用的Ingress Controller竟然不支持TCP代理，于是只能另想办法处理这个问题。

还是继续上面的例子，假设上述的redis-ha及predixy部署在kubernetes工作节点，而高可用kubernetes集群的vip只是在几个master节点间漂移，外部用户也肯定是通过vip来访问PaaS服务的。因此我们需要一种方式将外部用户的流量从master节点引向工作节点的方案。又是一番寻寻觅觅，我找到[proxy-to-service](https://github.com/kubernetes-retired/contrib/tree/master/for-demos/proxy-to-service)，通过这个pod，我们可以很方便地完成这一功能。proxy-to-service关键性pod配置如下：

```yaml
  nodeSelector:
        node-role.kubernetes.io/master: true
  
  containers:
  - name: proxy-tcp
    image: k8s.gcr.io/proxy-to-service:v2
    args: [ "tcp", "7617", "predixy-svc.demo" ]
    ports:
    - name: tcp
      protocol: TCP
      containerPort: 7617
```

最后，我们创建proxy-to-service对应的Service，其Type设置为NodePort就可以了：

```yaml
apiVersion: v1
kind: Service
metadata:  
  name: proxy-to-service-nodeport-service
selector:    
  app: proxy-to-service
spec:
  type: NodePort
  ports:  
  - name: tcp-redis
    port: 6379
    targetPort: 7617
    nodePort: 36379
    protocol: TCP
```

此时外部用户已可以通过vip及nodePort访问到redis PaaS服务了：

```bash
redis-cli -h ${kubernetes_master_vip} -p 36379
```

### 设置访问白名单

这种对外提供的PaaS服务，安全起见，至少还是应该提供访问白名单功能，以限制访问服务的客户端，避免潜在的安全风险。我们这里可以使用kubernetes的NetworkPolicy功能实现该功能。

首先我们要选择一个支持NetworkPolicy的CNI网络方案，默认的flannel是不支持的，为此我们换用了[calico](https://docs.projectcalico.org/v3.5/usage/)。

另外为了取得正确的客户端源IP地址，以进行访问白名单检查，我们需要将Service的**externalTrafficPolicy**设置为**Local**，官方文档中将如此设置后流量路径也解释得比较清楚，参考[这里](https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-nodeport)就可以了。

```yaml
apiVersion: v1
kind: Service
metadata:  
  name: proxy-to-service-nodeport-service
selector:    
  app: proxy-to-service
spec:
  type: NodePort
  externalTrafficPolicy: Local
  ports:  
  - name: tcp-redis
    port: 6379
    targetPort: 7617
    nodePort: 36379
    protocol: TCP
```

这里要注意，采用这种设置后，Service只会将流量代理到本节点的endpoint，如果本节点没有对应的endpoint，进入的流量就会被丢弃。这显然不是用户希望看到的，这里我们可以使用daemonset配合nodeSelector，将proxy-to-service的pod调度到每个master节点上，以解决该问题。

最后应用一个NetworkPolicy就可以了，如下：

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: proxy-to-service-network-policy
spec:
  podSelector:
    matchLabels:
      role: redis-proxy-to-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 192.168.22.0/24
    ports:
    - protocol: TCP
      port: 6379
```

上面的NetworkPolicy指示仅允许IP地址在`192.168.22.0/24`这个范围的客户端访问本PaaS服务。

至此，一个基本可用的基础PaaS服务就可以交付用户使用了。

### 组合起来

上面所说的是基于kubernetes构建基础PaaS服务的大概过程，为了简化用户使用，可以将上面的多步操作封装成一个大chart，最终只需要部署这个大的chart就可以快速搭建一个基本可用的PaaS服务了。封装大chart的方法参考[helm官方文档](https://helm.sh/docs/chart_template_guide/#subcharts-and-global-values)，这里就不细讲了。

## 实例监控

对于这种基础服务，一般能找到现成的prometheus exporter，如[redis_exporter](https://github.com/oliver006/redis_exporter)，再配合prometheus及grafana，就可以很方便地实现对基础PaaS服务示例的监控。prometheus的配置方法可以参考[以前的博文](https://jeremyxu2010.github.io/2018/11/%E4%BD%BF%E7%94%A8prometheus%E7%9B%91%E6%8E%A7%E5%A4%9Ak8s%E9%9B%86%E7%BE%A4/)。

## 运维操作

### 升级操作

还可以通过helm完成基础PaaS服务的升级操作，参考命令如下：

```bash
helm upgrade ${special_release_name} ${big_chart_name} -f custom_values.yaml
```

### 其它运维操作

其它运维操作，如备份还原等，这些光用chart就无能为力了，这里可以参考[mysql-operator](https://github.com/oracle/mysql-operator)的方案，定义一些[备份](https://github.com/oracle/mysql-operator/tree/master/examples/backup)或[还原](https://github.com/oracle/mysql-operator/tree/master/examples/restore)任务的自定义资源，基于这些自定义资源，配合kubernetes的job完成备份或还原操作。这属于比较进阶的，就不细讲了。

## 总结

经实践，基于Kubernetes构建基础PaaS服务确实比以前要快很多，交付效率得到很大的提升，很多基础性的工作，kubernetes本身也已经实现了，而且稳定可靠，可以很方便地与现有的很多开源解决方案整合。而且这个方案很容易复制到其它基础PaaS服务的构建过程中，基本模式都很类似。

但也不是全无代价的，kubernetes本身引入了较多的网络栈开销，另外为了确保pod能在node节点间漂移，使用kubernetes必然会引入分布式存储，这两者综合起来，还是对性能产生了不小的影响。因此最好在使用前进行一些的性能测试，得到一些性能对比数据，权衡下性能损耗，如果能接受，个人还是十分推荐使用该方案构建基础PaaS服务的。

## 参考

1. [http://www.ruanyifeng.com/blog/2017/07/iaas-paas-saas.html](http://www.ruanyifeng.com/blog/2017/07/iaas-paas-saas.html)
2. https://github.com/helm/charts
3. https://github.com/joyieldInc/predixy/
4. https://github.com/kubernetes-retired/contrib/tree/master/for-demos/proxy-to-service
5. https://docs.projectcalico.org/v3.5/usage/
6. https://kubernetes.io/docs/concepts/services-networking/network-policies/
7. https://github.com/oracle/mysql-operator
8. https://github.com/oliver006/redis_exporter