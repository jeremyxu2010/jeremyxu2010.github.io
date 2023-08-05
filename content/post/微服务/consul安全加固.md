---
title: consul安全加固
author: Jeremy Xu
tags:
  - microservice
  - consul
categories:
  - 微服务
date: 2018-05-18 20:15:00+08:00
---

[TOC]

## 本文档目标

最近的工作需要对默认安装的consul集群进行安全加固，这里将安全加固的步骤记录下来。

## consul 术语

首先介绍下在 consul 中会经常见到的术语：

- `node`：节点，需要 consul 注册发现或配置管理的服务器。
- `agent`：consul 中的核心程序，它将以守护进程的方式在各个节点运行，有 client 和 server 启动模式。每个 agent 维护一套服务和注册发现以及健康信息。
- `client`：agent 以 client 模式启动的节点。在该模式下，该节点会采集相关信息，通过 RPC 的方式向 server 发送。
- `server`：agent 以 server 模式启动的节点。一个数据中心中至少包含 1 个 server 节点。不过官方建议使用 3 或 5 个 server 节点组建成集群，以保证高可用且不失效率。server 节点参与 Raft、维护会员信息、注册服务、健康检查等功能。
- `datacenter`：数据中心，私有的，低延迟的和高带宽的网络环境。一般的多个数据中心之间的数据是不会被复制的，但可用过 [ACL replication](https://www.consul.io/docs/guides/acl.html#outages-and-acl-replication) 或使用外部工具 [onsul-replicate](https://github.com/hashicorp/consul-replicate)。
- `Consensus`，[共识协议](https://www.consul.io/docs/internals/consensus.html)，使用它来协商选出 leader。
- `Gossip`：consul 是建立在 [Serf](https://www.serf.io/)，它提供完整的 [gossip protocol](https://www.consul.io/docs/internals/gossip.html)，[维基百科](https://en.wikipedia.org/wiki/Gossip_protocol)。
- `LAN Gossip`，Lan gossip 池，包含位于同一局域网或数据中心上的节点。
- `WAN Gossip`，只包含 server 的 WAN Gossip 池，这些服务器主要位于不同的数据中心，通常通过互联网或广域网进行通信。
- `members`：成员，对 consul 成员的称呼。提供会员资格，故障检测和事件广播。有兴趣的朋友可以深入研究下。

## consul 架构

consul 的架构是什么，官方给出了一个很直观的图片：

![image-20180518182958181](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180518182958181.png)

这里存在两个数据中心：DATACENTER1、DATACENTER2。每个数据中心有着 3 到 5 台 server（该数量使得在故障转移和性能之间达到平衡）。

单个数据中心的所有节点都参与 `LAN Gossip` 池，也就是说该池包含了这个数据中心的所有节点。这有几个目的：

1. 不需要给客户端配置服务器地址，发现自动完成。
2. 检测节点故障的工作不是放在服务器上，而是分布式的。这使得故障检测比心跳方案更具可扩展性。
3. 事件广播，以便在诸如领导选举等重要事件发生时通知。

所有 server 节点也单独加入 `WAN Gossip` 池，因为它针对互联网的高延迟进行了优化。这个池的目的是允许数据中心以低调的方式发现对方。在线启动新的数据中心与加入现有的 `WAN Gossip` 一样简单。因为这些服务器都在这个池中运行，所以它也支持跨数据中心的请求。当服务器收到对不同数据中心的请求时，它会将其转发到正确数据中心中的随机服务器。那个服务器可能会转发给当地的领导。

这导致数据中心之间的耦合非常低，但是由于故障检测，连接缓存和复用，跨数据中心请求相对快速可靠。

一般来说，数据不会在不同的领事数据中心之间复制。当对另一数据中心的资源进行请求时，本地 consul 服务器将 RPC 请求转发给该资源的远程 consul 服务器并返回结果。如果远程数据中心不可用，那么这些资源也将不可用，但这不会影响本地数据中心。有一些特殊情况可以复制有限的数据子集，例如使用 consul 内置的 [ACL replication](https://www.consul.io/docs/guides/acl.html#outages-and-acl-replication)功能，或外部工具如 [consul-replicate](https://github.com/hashicorp/consul-replicate)。

> 更多协议详情，你可以 [Consensus Protocol](https://www.consul.io/docs/internals/consensus.html) 和 [Gossip Protocol](https://www.consul.io/docs/internals/gossip.html)。

## consul 端口说明

consul 内使用了很多端口，理解这些端口的用处对你理解 consul 架构很有帮助：

| 端口         | 说明                                                         |
| ------------ | ------------------------------------------------------------ |
| TCP/8300     | 8300 端口用于服务器节点。客户端通过该端口 RPC 协议调用服务端节点。服务器节点之间相互调用 |
| TCP/UDP/8301 | 8301 端口用于单个数据中心所有节点之间的互相通信，即对 LAN 池信息的同步。它使得整个数据中心能够自动发现服务器地址，分布式检测节点故障，事件广播（如领导选举事件）。 |
| TCP/UDP/8302 | 8302 端口用于单个或多个数据中心之间的服务器节点的信息同步，即对 WAN 池信息的同步。它针对互联网的高延迟进行了优化，能够实现跨数据中心请求。 |
| 8500         | 8500 端口基于 HTTP 协议，用于 API 接口或 WEB UI 访问。       |
| 8600         | 8600 端口作为 DNS 服务器，它使得我们可以通过节点名查询节点信息。 |

## consul多数据中心搭建

参见[consul多数据中心搭建](http://www.xiaomastack.com/2016/05/20/consul02/)，可以看到多数据中心的搭建也是比较容易的，关键在于要在每个数据中心选择一个边界节点，并配好`-advertise-wan=`参数，再执行`consul join -wan $other_wlan_ip`。

## 定制datacenter名称

在我们私有部署的场景里，暂时不需要配置多datacenter，只用一个datacenter即可。默认安装的consul集群datacenter名称都为dc1，不太友好，首先将这个修改下，在每个consul节点（包括server节点及client节点）执行以下命令即可：

```bash
# 备份原来的配置文件
cp -f /etc/consul/config.json /etc/consul/config.json.orig
# 将datacenter名称修改为tstack_dc
sed -i -e 's/"datacenter".*/"datacenter": "tstack_dc",/' /etc/consul/config.json
# 重启consul
systemctl restart consul.service
```

再登录consul的web ui，即可看到datacenter的名称发生了改变。

![image-20180518161915805](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180518161915805.png)

## 启用consul ACL

Consul默认没有启用ACL（Access Control List），任何连上consul的node节点可以访问consul的所有功能，下面是consul里按功能分类的策略列表。

| Policy                                                       | Scope                                                        |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [`agent`](https://www.consul.io/docs/guides/acl.html#agent-rules) | Utility operations in the [Agent API](https://www.consul.io/api/agent.html), other than service and check registration |
| [`event`](https://www.consul.io/docs/guides/acl.html#event-rules) | Listing and firing events in the [Event API](https://www.consul.io/api/event.html) |
| [`key`](https://www.consul.io/docs/guides/acl.html#key-value-rules) | Key/value store operations in the [KV Store API](https://www.consul.io/api/kv.html) |
| [`keyring`](https://www.consul.io/docs/guides/acl.html#keyring-rules) | Keyring operations in the [Keyring API](https://www.consul.io/api/operator/keyring.html) |
| [`node`](https://www.consul.io/docs/guides/acl.html#node-rules) | Node-level catalog operations in the [Catalog API](https://www.consul.io/api/catalog.html), [Health API](https://www.consul.io/api/health.html), [Prepared Query API](https://www.consul.io/api/query.html), [Network Coordinate API](https://www.consul.io/api/coordinate.html), and [Agent API](https://www.consul.io/api/agent.html) |
| [`operator`](https://www.consul.io/docs/guides/acl.html#operator-rules) | Cluster-level operations in the [Operator API](https://www.consul.io/api/operator.html), other than the [Keyring API](https://www.consul.io/api/operator/keyring.html) |
| [`query`](https://www.consul.io/docs/guides/acl.html#prepared-query-rules) | Prepared query operations in the [Prepared Query API](https://www.consul.io/api/query.html) |
| [`service`](https://www.consul.io/docs/guides/acl.html#service-rules) | Service-level catalog operations in the [Catalog API](https://www.consul.io/api/catalog.html), [Health API](https://www.consul.io/api/health.html), [Prepared Query API](https://www.consul.io/api/query.html), and [Agent API](https://www.consul.io/api/agent.html) |
| [`session`](https://www.consul.io/docs/guides/acl.html#session-rules) | Session operations in the [Session API](https://www.consul.io/api/session.html) |

显然让任何连上consul的node节点访问consul的所有功能是不安全的，所以有必要启用ACL，以下是启用的步骤：

1. 在consul的配置文件中添加以下3个配置项

   ```json
   {
       ......
       "acl_datacenter": "tstack_dc",
       "acl_default_policy": "allow",
       "acl_down_policy": "extend-cache",
       ......
   }
   ```

   注意这里先将`acl_default_policy`设置为`allow`，后面得到client token，并在所有客户端中都配置了client token后，再将其修改为`deny`

2. 得到bootstrap的management token

   ```bash
   curl --request PUT https://10.12.142.217:8500/v1/acl/bootstrap
   {"ID":"b3a9bca3-6e8e-9678-ea35-ccb8fb272d42"} # 这里b3a9bca3-6e8e-9678-ea35-ccb8fb272d42就是bootstrap的management token
   ```

3. 因为我们只使用到consul的`node`、`service`、`key`、`session`、`agent`相关功能，因此只创建拥有这些功能访问权限的client token

   ```bash
   curl -X PUT --header "X-Consul-Token: b3a9bca3-6e8e-9678-ea35-ccb8fb272d42" --data \
   '{
     "Name": "AgentToken",
     "Type": "client",
     "Rules": "node \"\" { policy = \"read\" } node \"\" { policy = \"write\" } service \"\" { policy = \"read\" } service \"\" { policy = \"write\" }  key \"\" { policy = \"read\" } key \"\" { policy = \"write\" } agent \"\" { policy = \"read\" } agent \"\" { policy = \"write\" }  session \"\" { policy = \"read\" } session \"\" { policy = \"write\" }"
   }' http://10.12.142.217:8500/v1/acl/create
   {"ID":"0b7df19e-6eab-5748-bba3-2f56bf85a6a9"} # 这里0b7df19e-6eab-5748-bba3-2f56bf85a6a9就是client token
   ```

4. 为了运维管理方便，consul的web ui管理节点直接配置上management token，在这些节点的consul配置文件中加入下面的配置项：

   ```json
   {
       ......
       "acl_master_token": "b3a9bca3-6e8e-9678-ea35-ccb8fb272d42",
       "acl_agent_token": "b3a9bca3-6e8e-9678-ea35-ccb8fb272d42",
       ......
   }
   ```

   并重启consul

5. 验证ACL，在consul的web ui中配置访问时所用的token，观察使用该token是否只能使用正确的功能。配置浏览器访问时所用的token方法如下图所示：

   ![image-20180518181759727](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180518181759727.png)

   ![image-20180518181914004](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180518181914004.png)

6. 如token的权限是正常的，则可以将`acl_default_policy`设置为`deny`，并将client token分发给客户端，连上consul的node节点必需使用该token才可能使用权限指定的功能。

consul的ACL控制文档写得比较难理解，想了解具体细节，可以参考[官方文档](https://www.consul.io/docs/guides/acl.html)、[consul ACL配置使用](http://www.xiaomastack.com/2016/06/11/cousnl-acl/)。

## consul web ui的安全

consul本身并没有提供web ui的安全性保证，只要防火墙允许，则在外网的任何人也可以访问其web ui，这一点比较危险，这里采用基本的`auth_basic`来保证consul web ui的安全性，方案简述如下：

1. 以server模式运行consul agent的服务器，其配置网络策略，仅允许在内网范围内其它节点可访问其8500端口。

2. 以client模式运行consul agent的节点，其如果打开web ui，则只绑定地址127.0.0.1；其可以以8500端口连接consul server agent，但在使用consul相关功能时，必须使用client token或management token。

3. 在内网中采用nginx或apache做反向代理至consul server agent节点的8500端口，并在nginx或apache中配置`auth_basic`认证。反向代理及`auth_basic`认证的配置参考下面：

   ```bash
   yum install -y httpd-tools
   htpasswd -c /etc/nginx/htpsswd consul_access # 执行后会要求你输入密码，完了就完成了账号密码的生成
   # 下面以配置nginx示例，apache的配置类似
   upstream consul {
          server 10.12.142.216:8500;
          server 10.12.142.217:8500;
          server 10.12.142.218:8500;
   }
   server {
       listen 18500;
       server_name consul.xxxx.com;
       location / {
           proxy_pass http://consul;
           proxy_read_timeout 300;
           proxy_connect_timeout 300;
           proxy_redirect off;
           auth_basic "Restricted";
           auth_basic_user_file /etc/nginx/htpasswd;
       }
   }
   ```

4. 配置网络策略，在外网仅允许访问nginx的反向代理地址，访问时需输入`auth_basic`认证信息，并且在使用consul相关功能时，必须使用client token（原则上不允许将management token带出到外网）。

## 链路安全

consul 由于采用了 gossip、RPC、HTTPS、HTTP来提供功能。其中 gossip、RPC、HTTPS分别采用了不同的安全机制。其中 gossip 使用对称密钥提供加密，RPC 则可以使用客户端认证的端到端 TLS，HTTPS 也是使用客户端认证的端到端 TLS。而我们的使用场景实际上是只使用了gossip、HTTP，因此可参考[这篇文章](https://deepzz.com/post/the-consul-of-discovery-and-configure-services.html)酌情进行链路安全方面的设置，目前来看，只能加入`gossip 加密`。

## 参考

1. http://www.xiaomastack.com/2016/05/20/consul02
2. https://www.consul.io/docs/guides/acl.html
3. http://www.xiaomastack.com/2016/06/11/cousnl-acl
4. https://deepzz.com/post/the-consul-of-discovery-and-configure-services.html