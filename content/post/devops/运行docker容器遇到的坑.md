---
title: 运行docker容器遇到的坑
author: Jeremy Xu
tags:
  - docker
  - consul
  - zipkin
categories:
  - devops
date: 2019-03-11 00:14:00+08:00
---

今天工作中，需要在本机启动consul、zipkin两个容器，参考[docker](https://hub.docker.com/_/consul?tab=description)和[zipkin](https://hub.docker.com/r/openzipkin/zipkin)两个镜像的说明，很自然地敲出了以下命令：

```bash
docker run -d -p 8500:8500 --name=dev-consul -e CONSUL_BIND_INTERFACE=eth0 consul agent -dev -ui
docker run -d -p 9411:9411 openzipkin/zipkin
```

然后用浏览器去访问[http://127.0.0.1:8500](http://127.0.0.1:8500)和[http://127.0.0.1:9411](http://127.0.0.1:9411)，结果发现竟然不能访问。

研究了好半天终于找到原因了。

consul在docker容器里运行的正确姿势：

```bash
docker run -d -p 8500:8500 --name=dev-consul -e CONSUL_BIND_INTERFACE=eth0 consul agent -dev -ui -client 0.0.0.0
```

关键是要加一个`-client`参数，[这个](https://www.consul.io/docs/agent/options.html#_client)在官方文档上有说明的：

> [`-client`](https://www.consul.io/docs/agent/options.html#_client) - The address to which Consul will bind client interfaces, including the HTTP and DNS servers. By default, this is "127.0.0.1", allowing only loopback connections. In Consul 1.0 and later this can be set to a space-separated list of addresses to bind to, or a [go-sockaddr](https://godoc.org/github.com/hashicorp/go-sockaddr/template) template that can potentially resolve to multiple addresses.

因为容器运行时是使用`-p`参数把容器命名空间里的端口映射出来的，因此在容器里运行的程序监听地址必须绑定到0.0.0.0，如果只绑定到127.0.0.1，这样的端口没法映射出来。

zipkin在docker容器里运行的正确姿势：

```bash
docker run -d -p 9411:9411 openzipkin/zipkin:2.12.3
```

关键是要指定镜像的版本为2.12.3，[最新的版本2.12.5或latest](https://hub.docker.com/r/openzipkin/zipkin/tags)是前4天发布的，存在严重的bug，汗！！！

