---
title: consul基础运维-备份还原导入导出
author: Jeremy Xu
tags:
  - microservice
  - consul
categories:
  - 微服务
date: 2018-05-21 14:20:00+08:00
---

## 本文档目标

工作中要保证生产环境部署的consul的集群能够安全稳定地对外提供服务，即使出现系统故障也能快速恢复，这里将讲述部分的备份还原操作及KV的导入导出操作。

## 备份与还原

需要备份的主要有两类数据：consul相关的配置文件、consul的服务器状态，采用下面的脚本备份就可以了：

```bash
ts=$(date +%Y%m%d%H%M%S)

# 备份配置文件
tar -czpf consul_config_$ts.tar.gz /etc/consul/config.json /etc/consul/consul.d

# 备份consul的服务器状态，注意由于该consul开启了ACL，执行consul snapshot save时必须带Management Token，关于consul ACL token的说明见上一篇"consul安全加固"
consul snapshot save --http-addr=http://10.12.142.216:8500 -token=b3a9bca3-6e8e-9678-ea35-ccb8fb272d42 consul_state_$ts.snap

# 查看一下生成的consul服务器状态文件
consul snapshot inspect consul_state_$ts.snap
```

最后将生成的`consul_config_xxx.tar.gz`、`consul_state_xxx.snap`拷贝到其它服务器妥善存储。

还原也比较简单，采用下面的脚本就可以了：

```bash
# 还原配置文件
tar -xzpf consul_config_20180521145032.tar.gz -C /

# 还原consul服务器状态
consul snapshot restore --http-addr=http://10.12.142.216:8500 -token=b3a9bca3-6e8e-9678-ea35-ccb8fb272d42 consul_state_20180521145032.snap
```

## KV存储的导入导出

consul直接提供命令对KV里存储的数据进行导入导出，如下：

```bash
$ ts=$(date +%Y%m%d%H%M%S)

# 导出所有kv键值对，注意最后一个参数是导出键值对的前缀，为空字符串说明要导出所有
$ consul kv export --http-addr=http://10.12.142.216:8500 -token=b3a9bca3-6e8e-9678-ea35-ccb8fb272d42 '' > consul_kv_$ts.json

# 查看下导出的json文件格式
$ cat consul_kv_$ts.json
[
	{
		"key": "xxxxxx",
		"flags": 0,
		"value": "yyyyyy"
	},
	{
		"key": "xxxxxx2",
		"flags": 0,
		"value": "eyJ2ZXJzaW9uX3RpbWVzdGFtcCI6IC0xfQ=="
	},
]
```

发现是每个键值对都是json数值中一项，其中key为键值对Key的名称，value为键值对Value的base64编码，使用`base64 -d`命令编码就可以看到原始的value值，如：

```bash
$ echo 'eyJ2ZXJzaW9uX3RpbWVzdGFtcCI6IC0xfQ==' | base64 -d
{"version_timestamp": -1}
```

导入就更简单了：

```bash
consul kv import --http-addr=http://10.12.142.216:8500 -token=b3a9bca3-6e8e-9678-ea35-ccb8fb272d42 @consul_kv_20180521150322.json
```

OVER

## 参考

1. https://www.consul.io/docs/commands/snapshot.html
2. https://www.consul.io/docs/commands/kv/import.html
3. https://www.consul.io/docs/commands/kv/export.html