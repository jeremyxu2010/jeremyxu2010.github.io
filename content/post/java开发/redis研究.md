---
title: redis研究
author: Jeremy Xu
tags:
  - redis
  - java
categories:
  - java开发
date: 2016-11-13 01:18:00+08:00
---
最近看了本书《Redis中文文档》，这本书写得挺好，讲了Redis的方方面面，在这里记录一下以备忘。

## 相关概念

### 键空间通知

这个用得比较少，暂时不记录了。

### 事务

大多数NOSQL数据库并不支持事务，可Redis提供有限的事务支持。之所以说是有限的事务支持，是因为客户端成功在开启事务之后执行 EXEC，在执行EXEC的过程中如果 Redis 服务器因为某些原因被管理员杀死，或者遇上某种硬件故障，那么可能只有部分事务命令会被成功写入到磁盘中。这时Redis 在重新启动时发现 AOF 文件出了这样的问题，那么它会退出，并汇报一个错误。使用`redis-check-aof`  程序可以修复这一问题：它会移除 AOF 文件中不完整事务的信息，确保服务器可以顺利启动。

`MULTI` 、 `EXEC` 、 `DISCARD` 和 `WATCH` 是 Redis 事务的基础。

事务使用范例：

```
> MULTI
OK

> INCR foo
QUEUED

> INCR bar
QUEUED

> EXEC
1) (integer) 1
2) (integer) 1
```

### 发布与订阅

SUBSCRIBE 、 UNSUBSCRIBE 和 PUBLISH 三个命令实现了发布与订阅信息泛型（Publish/Subscribe messaging paradigm）， 在这个实现中， 发送者（发送信息的客户端）不是将信息直接发送给特定的接收者（接收信息的客户端）， 而是将信息发送给频道（channel）， 然后由频道将信息转发给所有对这个频道感兴趣的订阅者。

发送者无须知道任何关于订阅者的信息， 而订阅者也无须知道是那个客户端给它发送信息， 它只要关注自己感兴趣的频道即可。

发布与订阅使用范例：

```
> SUBSCRIBE first second
1) "subscribe"
2) "first"
3) (integer) 1

1) "subscribe"
2) "second"
3) (integer) 2

#另一个客户端执行PUBLISH命令
> PUBLISH second Hello

#前一个客户端则会收到消息
1) "message"
2) "second"
3) "hello"

```

### 复制

Redis 支持简单且易用的主从复制（master-slave replication）功能， 该功能可以让从服务器(slave server)成为主服务器(master server)的精确复制品。

复制功能可以单纯地用于数据冗余（data redundancy）， 也可以通过让多个从服务器处理只读命令请求来提升扩展性（scalability）。另外由于从服务器是主服务器的精确复制品，于是在Redis集群里，从服务器可以很方便地接管主服务器，以达到自动故障迁移的目的。

配置一个从服务器非常简单， 只要在配置文件中增加以下的这一行就可以了：

```
> slaveof 192.168.1.1 6379
OK
```

### 通信协议

通信协议一般实现Redis客户端时会用到，日常使用倒是不会用到它，这里暂时不记录它了。

### 持久化

相对于memcache来说，Redis一大优势是存在它里的数据是可以持久化的，即使重启Redis，数据依旧还在。

Redis 提供了多种不同级别的持久化方式：

* RDB 持久化可以在指定的时间间隔内生成数据集的时间点快照（point-in-time snapshot）。
* AOF 持久化记录服务器执行的所有写操作命令，并在服务器启动时，通过重新执行这些命令来还原数据集。 AOF 文件中的命令全部以 Redis 协议的格式来保存，新命令会被追加到文件的末尾。 Redis 还可以在后台对 AOF 文件进行重写（rewrite），使得 AOF 文件的体积不会超出保存数据集状态所需的实际大小。
* Redis 还可以同时使用 AOF 持久化和 RDB 持久化。 在这种情况下， 当 Redis 重启时， 它会优先使用 AOF 文件来还原数据集， 因为 AOF 文件保存的数据集通常比 RDB 文件所保存的数据集更完整。
* 你甚至可以关闭持久化功能，让数据只在服务器运行时存在。

```
# 手动让Redis进行数据集RDB持久化
> BGSAVE

# 开启AOF持久化
> CONFIG SET appendonly yes

# 手动让Redis对AOF文件进行重建
> BGREWRITEAOF
```

### Sentinel哨兵

Redis 的 Sentinel 系统用于管理多个 Redis 服务器（instance）， 该系统执行以下三个任务：

* 监控（Monitoring）： Sentinel 会不断地检查你的主服务器和从服务器是否运作正常。
* 提醒（Notification）： 当被监控的某个 Redis 服务器出现问题时， Sentinel 可以通过 API 向管理员或者其他应用程序发送通知。
* 自动故障迁移（Automatic failover）： 当一个主服务器不能正常工作时， Sentinel 会开始一次自动故障迁移操作， 它会将失效主服务器的其中一个从服务器升级为新的主服务器， 并让失效主服务器的其他从服务器改为复制新的主服务器； 当客户端试图连接失效的主服务器时， 集群也会向客户端返回新主服务器的地址， 使得集群可以使用新主服务器代替失效服务器。

Redis Sentinel 是一个分布式系统， 你可以在一个架构中运行多个 Sentinel 进程（progress）， 这些进程使用流言协议（gossip protocols)来接收关于主服务器是否下线的信息， 并使用投票协议（agreement protocols）来决定是否执行自动故障迁移， 以及选择哪个从服务器作为新的主服务器。

### 集群

Redis 集群是一个可以在多个 Redis 节点之间进行数据共享的设施。
Redis 集群不支持那些需要同时处理多个键的 Redis 命令， 因为执行这些命令需要在多个 Redis 节点之间移动数据， 并且在高负载的情况下， 这些命令将降低 Redis 集群的性能， 并导致不可预测的行为。
Redis 集群通过分区（partition）来提供一定程度的可用性（availability）： 即使集群中有一部分节点失效或者无法进行通讯， 集群也可以继续处理命令请求。
Redis 集群提供了以下两个好处：

* 将数据自动切分（split）到多个节点的能力。
* 当集群中的一部分节点失效或者无法进行通讯时， 仍然可以继续处理命令请求的能力。

Redis 集群使用数据分片（sharding）而非一致性哈希（consistency hashing）来实现： 一个 Redis 集群包含  16384  个哈希槽（hash slot）， 数据库中的每个键都属于这  16384  个哈希槽的其中一个， 集群使用公式  CRC16(key) % 16384  来计算键  key  属于哪个槽， 其中  CRC16(key)  语句用于计算键  key  的 CRC16 校验和 。集群中的每个节点负责处理一部分哈希槽。

```
#创建集群
./redis-trib.rb create --replicas 1 127.0.0.1:7000 127.0.0.1:7001 \
127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005

#对集群进行重新分片
./redis-trib.rb reshard 127.0.0.1:7000
#接着回答几个问题，包括要移动的哈希槽的数量、目标节点的 ID、源节点信息，最后yes回车后，Redis集群就会开始重新分片操作

#检查集群是否正常
./redis-trib.rb check 127.0.0.1:7000

#列出集群节点信息
./redis-cli -p 7000 cluster nodes
```

## Redis命令

上一节主要是概括Redis的一些核心概念，Redis的部署运维时需了解这些概念。Redis与memcache最大的不同在于Redis拥有更多的数据结构和并支持更丰富的数据操作，而这些数据结构是通过一系列命令来完成的。

### 键的通用命令

DEL、DUMP、RESTORE、EXISTS、EXPIRE、EXPIREAT、TTL、PERSIST、PEXPIRE、PEXPIREAT、PTTL、MIGRAGE、MOVE、OBJECT、RANDOMKEY、KEYS、RENAME、RENAMENX、SORT、TYPE、SCAN

### String相关命令

APPEND、BITCOUNT、BITOP、DECR、DECRBY、GET、GETBIT、GETRANGE、GETSET、INCR、INCRBY、INCRBYFLOAT、MGET、MSET、MSETNX、PSETEX、SET、SETBIT、SETEX、SETNX、SETRANGE、STRLEN

### List相关命令

BLPOP、BRPOP、BRPOPLPUSH、LINDEX、LINSERT、LLEN、LPOP、LPUSH、LRANGE、LREM、LSET、LTRIM、RPOP、RPOPLPUSH、RPUSH、RPUSHX

### Hash相关命令

HDEL、HEXISTS、HGET、HGETALL、HINCRBY、HINCRBYFLOAT、HKEYS、HLEN、HMGET、HMSET、HSET、HSETNX、HVALS、HSCAN

### Set相关命令

SADD、SCARD、SDIFF、SDIFFSTORE、SINTER、SINTERSTORE、SISMEMBER、SMEMBERS、SMOVE、SPOP、SRANDMEMBER、SREM、SUNION、SUNIONSTORE、SSCAN

### SortedSet相关命令

ZADD、ZCARD、ZCOUNT、ZINCRBY、ZRANGE、ZRANGEBYSCORE、ZRANK、ZREM、ZREMRANGEBYRANK、ZREMRANGEBYSCORE、ZREVRANGE、ZREVRANGEBYSCORE、ZREVRANK、ZSCORE、ZUNIONSTORE、ZINTERSTORE、ZSCAN

### 发布订阅相关命令

PSUBSCRIBE、PUBLISH、PUBSUB、PUNSUBSCRIBE、SUBSCRIBE、UNSUBSCRIBE

### 事务相关命令

DISCARD、EXEC、MULTI、UNWATCH、WATCH

### Script相关命令

EVAL、EVALSHA、SCRIPT EXISTS、SCRIPT FLUSH、SCRIPT KILL、SCRIPT LOAD

### Connection相关命令

AUTH、ECHO、PING、QUIT、SELECT

### Server相关命令

BGREWRITEAOF、BGSAVE、CLIENT GETNAME、CLIENT KILL、CLIENT LIST、CLIENT SETNAME、CONFIG GET、CONFIG RESETSTAT、CONFIG REWRITE、CONFIG SET、DBSIZE、DEBUG OBJECT、DEBUG SEGFAULT、FLUSHALL、FLUSHDB、INFO、LASTSAVE、MONITOR、SAVE、SHUTDOWN、SLAVEOF、SLOWLOG、TIME

虽然这里的命令看着很多，可大部分命令的方式很一致，实在不太清楚也可以查看[在线文档](http://www.redis.cn/commands.html)。

## 实际运用场景

### 显示最新的项目列表

直接用DB的实现方法可能是这样的：

```
SELECT * FROM foo WHERE ... ORDER BY time DESC LIMIT 10
```

可随着表里的数据越来越多，这个方案性能越来越差。

使用Redis可以这样设计：

假设我们的一个Web应用想要列出用户贴出的最新20条评论。在最新的评论边上我们有一个“显示全部”的链接，点击后就可以获得更多的评论。数据库中的每条评论都有一个唯一的递增的ID字段。我们可以使用分页来制作主页和评论页，使用Redis的模板，每次新评论发表时，我们会将它的ID添加到一个Redis列表：

```
#将ID添加到一个Redis列表
LPUSH latest.comments <ID>
#Redis只需要保存最新的5000条评论
LTRIM latest.comments 0 5000
```

每次我们需要获取最新评论的项目范围时，我们调用一个函数来完成（使用伪代码）：

```
FUNCTION get_latest_comments(start, num_items):
    id_list = redis.lrange("latest.comments",start,start+num_items - 1)
    IF id_list.length < num_items
        RETURN SQL_DB("SELECT ... ORDER BY time DESC LIMIT num_items OFFSET start")
    END
    RETURN SQL_DB("SELECT ... where id in id_list")
END
```

### 过滤

有些时候你想要给不同的列表附加上不同的过滤器。如果过滤器的数量受到限制，你可以简单的为每个不同的过滤器使用不同的Redis列表。毕竟每个列表只有5000条项目，但Redis却能够使用非常少的内存来处理几百万条项目。

使用Redis可以这样设计：

假设每次往DB插入新记录后，我们根据过滤条件将记录的ID插入多个Redis列表里：

```
#将ID添加到一个Redis列表
LPUSH keyword1.posts <ID>
#Redis只需要保存最新的5000条评论
LTRIM keyword1.posts 0 5000

#将ID添加到一个Redis列表
LPUSH keyword2.posts <ID>
#Redis只需要保存最新的5000条评论
LTRIM keyword2.posts 0 5000

#将ID添加到一个Redis列表
LPUSH keyword3.posts <ID>
#Redis只需要保存最新的5000条评论
LTRIM keyword4.posts 0 5000
```

以后要查询某个过滤条件的记录就很方便了：

```
FUNCTION get_posts_filter_by_keyword(keyword):
    id_list = redis.lrange(keyword + ".posts",0,-1)
    RETURN SQL_DB("SELECT ... where id in id_list")
END
```

### 排行榜相关

一个很普遍的需求是各种数据库的数据并非存储在内存中，因此在按得分排序以及实时更新这些几乎每秒钟都需要更新的功能上数据库的性能不够理想。

在某个用户获得新得分时，则执行下面的命令：

```
ZINCRBY sorceboard <score>  <userID>
```

要获取前100名高分用户就很简单：

```
ZREVRANGE sorceboard 0 99。
```

获取某个用户的排名也很简单：

```
ZRANK sorceboard <userID>
```

### 计数

记录某用户在单位时间内登录失败的次数，以后可根据失败的次数决定某些业务逻辑：

```
INCR loginFailed:<userID>
EXPIRE loginFailed:<userID> 60
```

### 限速

限制某API被请求的频率：

```
FUNCTION LIMIT_API_CALL(ip):
current = GET(ip)
IF current != NULL AND current > 10 THEN
    ERROR "too many requests per second"
ELSE
    value = INCR(ip)
    IF value == 1 THEN
        EXPIRE(value,1)
    END
    PERFORM_API_CALL()
END
```

### 特定时间内的特定项目

另一项对于其他数据库很难，但Redis做起来却轻而易举的事就是统计在某段特点时间里有多少特定用户访问了某个特定资源。比如我想要知道某些特定的注册用户或IP地址，他们到底有多少访问了某篇文章。

每次我获得一次新的页面浏览时我只需要这样做：

```
SADD page:day_20161112:<pageID> <userID>
```

想知道特定用户的数量吗？只需要使用

```
SCARD page:day_20161112:<pageID>
```

需要测试某个特定用户是否访问了这个页面？只需要使用

```
SISMEMBER page:day_20161112:<pageID> <userID>
```

### 订阅与发布

Redis的Pub/Sub非常非常简单，运行稳定并且快速。支持模式匹配，能够实时订阅与取消频道。一些可靠性要求没那么高的事件订阅与发布是可以用Redis的Pub/Sub代替MQ方案的。

### 队列

现代的互联网应用大量地使用了消息队列（Messaging）。消息队列不仅被用于系统内部组件之间的通信，同时也被用于系统跟其它服务之间的交互。消息队列的使用可以增加系统的可扩展性、灵活性和用户体验。非基于消息队列的系统，其运行速度取决于系统中最慢的组件的速度（注：短板效应）。而基于消息队列可以将系统中各组件解除耦合，这样系统就不再受最慢组件的束缚，各组件可以异步运行从而得以更快的速度完成各自的工作。

list push和list pop这样的Redis命令能够很方便的执行队列操作了，但能做的可不止这些：比如Redis还有list pop的变体命令，能够在列表为空时阻塞队列。

一些可靠性要求没那么高的事件订阅与发布是可以用Redis的List方案代替MQ方案的。

### 缓存

基本上memcache可以搞定的事儿，redis都可以搞定，而且redis重启后，数据还是持久的。因此memcache可以退休了。

## 总结

Redis作为传统关系型数据库的补充，在某些特定场景确实极大地提升了数据查询效率。下一篇研究一下在Java里如何访问Redis。

## 参考

《Redis中文文档》
`http://www.redis.cn/documentation.html`
`http://www.redis.cn/commands.html`
`http://blog.csdn.net/hguisu/article/details/8836819`
