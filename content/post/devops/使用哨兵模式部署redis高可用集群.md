---
title: 使用哨兵模式部署redis高可用集群
tags:
  - redis
  - sentinel
  - kubernetes
categories:
  - devops
date: 2019-03-12 10:50:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20190313
---

很早以前就听说过redis社区推崇一种哨兵模式的高可用集群部署模式，今天花时间研究了一下，正好记录下来。

## 哨兵模式

### 哨兵简介

哨兵模式是在Redis 2.8 版本开始引入的。哨兵的核心功能是主节点的自动故障转移。

下面是 Redis 官方文档对于哨兵功能的描述：

* 监控（Monitoring）：哨兵会不断地检查主节点和从节点是否运作正常。

- 自动故障转移（Automatic failover）：当主节点不能正常工作时，哨兵会开始自动故障转移操作，它会将失效主节点的其中一个从节点升级为新的主节点，并让其他从节点改为复制新的主节点。
- 配置提供者（Configurationprovider）：客户端在初始化时，通过连接哨兵来获得当前 Redis 服务的主节点地址。
- 通知（Notification）：哨兵可以将故障转移的结果发送给客户端。

其中，监控和自动故障转移功能，使得哨兵可以及时发现主节点故障并完成转移；而配置提供者和通知功能，则需要在与客户端的交互中才能体现。

### 哨兵的架构

典型的哨兵架构图如下所示：

![image-20190313234434034](/images/20190313/image-20190313234434034.png)

它由两部分组成，哨兵节点和数据节点：

- 哨兵节点：哨兵系统由一个或多个哨兵节点组成，哨兵节点是特殊的 Redis 节点，不存储数据。
- 数据节点：主节点和从节点都是数据节点。

### 哨兵模式的部署

参考[官方文档](https://redis.io/topics/sentinel)手工部署一个哨兵模式的redis集群还是挺麻烦的，网上有不少这方面的[操作指引](https://www.cnblogs.com/xishuai/p/redis-sentinel.html)，这里就不详细介绍了。

云原生时代，这里还是介绍一个快速[在kubernetes中部署哨兵模式redis集群的办法](https://github.com/helm/charts/tree/master/stable/redis-ha)，云原生时代部署基础组件就是方便啊。

因为在本机的k8s集群测试，k8s集群里只有一个节点，因此稍微修改部署时的values.yaml:

`redis-ha-values-custom.yaml`

```yaml
## Node labels, affinity, and tolerations for pod assignment
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#nodeselector
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#taints-and-tolerations-beta-feature
## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
# Just for local develop environment
affinity: {}
```

然后直接部署redis-ha:

```bash
helm install --namespace test --name redis-ha stable/redis-ha -f ./redis-ha-values-custom.yaml
```

很快在test命名空间就会发现redis的pod都正常运行了：

```bash
$ kubectl get pod -n test
NAME                READY     STATUS    RESTARTS   AGE
redis-ha-server-0   2/2       Running   0          1h
redis-ha-server-1   2/2       Running   0          1h
redis-ha-server-2   2/2       Running   0          1h

$ kubectl -n test get svc
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)              AGE
redis-ha              ClusterIP   None             <none>        6379/TCP,26379/TCP   2h
redis-ha-announce-0   ClusterIP   10.103.179.132   <none>        6379/TCP,26379/TCP   2h
redis-ha-announce-1   ClusterIP   10.98.58.246     <none>        6379/TCP,26379/TCP   2h
redis-ha-announce-2   ClusterIP   10.97.66.79      <none>        6379/TCP,26379/TCP   2h
```

总共3个pod，每个pod里有两个容器，一个是redis，一个是sentinel。整个部署方案的相关参数默认都配置得比较合理，完整的参考列表见[这里](https://github.com/helm/charts/tree/master/stable/redis-ha#configuration)。

这里有特别注意，使用哨兵模式的客户端应该要配置哨兵的访问地址，如`redis-ha-announce-0.test.svc.cluster.local:26379`。有3个哨兵的访问地址，一般客户端这边会将这3个哨兵都备份下来，这样将可以避免sentinel成为单点故障。

## 使用哨兵模式redis集群

从架构上看，要想使用哨兵模式的redis集群，客户端必须与哨兵先通信，拿到可用redis主节点信息后，再连接redis主节点，所以对redis客户端有一些要求。

好消息是有些redis连接库已经支持了sentinel模式，如[go-redis](https://godoc.org/github.com/go-redis/redis#NewFailoverClient)。即使有些redis库并不支持，也可以轻松加上对sentinel模式的支持，如[这里](https://blog.csdn.net/lanyang123456/article/details/81153474)。

最后看了下harbor的代码，发现它目前的代码还不支持sentinel模式，正好可以改明儿把这块功能做上，给官方发Pull Request。

`bootstrap.go`

```go
// Load and run the worker pool
func (bs *Bootstrap) loadAndRunRedisWorkerPool(ctx *env.Context, cfg *config.Configuration) (pool.Interface, error) {
	redisPool := &redis.Pool{
		MaxActive: 6,
		MaxIdle:   6,
		Wait:      true,
		Dial: func() (redis.Conn, error) {
			return redis.DialURL(
				cfg.PoolConfig.RedisPoolCfg.RedisURL,
				redis.DialConnectTimeout(dialConnectionTimeout),
				redis.DialReadTimeout(dialReadTimeout),
				redis.DialWriteTimeout(dialWriteTimeout),
			)
		},
		TestOnBorrow: func(c redis.Conn, t time.Time) error {
			if time.Since(t) < time.Minute {
				return nil
			}

			_, err := c.Do("PING")
			return err
		},
	}
    ......
```

## 遇到的坑

整个部署还是比较顺利的，只是部署完毕后，想用redis-cli连接试验一下，结果一直卡住：

```bash
# 这里会直接卡住
kubectl -n test run redis-client -t -i --image=redis:5.0.3-alpine -- redis-cli -h redis-ha-announce-0.test.svc.cluster.local -p 26379
```

改成下面这样就可以了：

```bash
kubectl -n test run redis-client -t -i --image=redis:5.0.3-alpine -- sh -c "sleep 3; redis-cli -h redis-ha-announce-0.test.svc.cluster.local -p 26379"
```

这个应该填[kubernetes的bug](https://github.com/kubernetes/kubernetes/issues/28695)吧。

## 参考

1. http://developer.51cto.com/art/201809/583104.htm
2. https://redis.io/topics/sentinel
3. https://www.cnblogs.com/xishuai/p/redis-sentinel.html
4. https://blog.csdn.net/lanyang123456/article/details/81153474
5. https://github.com/helm/charts/tree/master/stable/redis-ha