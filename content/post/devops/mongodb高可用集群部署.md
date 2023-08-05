---
title: mongodb高可用集群部署
tags:
  - mongodb
  - devop
categories:
  - devops
date: 2018-10-13 12:50:00+08:00
---

最近比较忙，而且国庆节回了趟老家，各种事情比较多，博客又有一个月没有更新了。这周末有一些时间，所以计划分几篇文章把近一个月技术上的一些实践记录一下，这第一篇记录一下mongodb的高可用集群部署。

## 环境准备

### 操作系统信息

系统系统：centos7.2 

三台服务器：10.211.55.11/12/13

安装包：https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/

### 服务器规划

| 服务器mongo11             | 服务器mongo12             | 服务器mongo13             |
| ------------------------- | ------------------------- | ------------------------- |
| mongos                    | mongos                    | mongos                    |
| mongo config server       | mongo config server       | mongo config server       |
| shard server1 复制集节点1 | shard server1 复制集节点2 | shard server1 复制集节点3 |
| shard server2 复制集节点1 | shard server2 复制集节点2 | shard server2 复制集节点3 |
| shard server3 复制集节点1 | shard server3 复制集节点2 | shard server3 复制集节点3 |

### 端口分配

```
mongos：27088
config：27077
shard1：27017
shard2：27018
shard3：27019
```

## 集群搭建

### 安装mongodb

3台服务器上均安装mongodb的rpm包

```bash
yum install -y https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-4.0.3-1.el7.x86_64.rpm \
  https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-mongos-4.0.3-1.el7.x86_64.rpm \
  https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-server-4.0.3-1.el7.x86_64.rpm \
  https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-shell-4.0.3-1.el7.x86_64.rpm \
  https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-tools-4.0.3-1.el7.x86_64.rpm
```

分别在每台机器建立conf、mongos、config、shard1、shard2、shard3六个目录，因为mongos不存储数据，只需要建立日志文件目录即可。

```bash
mkdir -p /etc/mongodb/conf
mkdir -p /var/lib/mongodb/mongos/log
mkdir -p /var/lib/mongodb/config/data
mkdir -p /var/lib/mongodb/config/log
mkdir -p /var/lib/mongodb/shard1/data
mkdir -p /var/lib/mongodb/shard1/log
mkdir -p /var/lib/mongodb/shard2/data
mkdir -p /var/lib/mongodb/shard2/log
mkdir -p /var/lib/mongodb/shard3/data
mkdir -p /var/lib/mongodb/shard3/log
```

关闭selinux

```bash
setenforce 0
sed -i -e 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config
```

### 初始化分片的复制集

首先初始化分片shard1的复制集，在每台服务器上创建其配置文件：

```bash
$ cat <<EOF > /etc/mongodb/conf/shard1.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/lib/mongodb/shard1/log/mongod.log
 
# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb/shard1/data
  journal:
    enabled: true
 
# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /var/lib/mongodb/shard1/log/mongod.pid  # location of pidfile
 
# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0  # Listen to local interface only, comment to listen on all interfaces.

replication:
  replSetName: shard1

sharding:
    clusterRole: "shardsvr"
EOF
```

在每台服务器上创建该分片复制节点的systemd启动脚本：

```bash
$ cat <<EOF > /usr/lib/systemd/system/mongod-shard1.service
[Unit]
Description=MongoDB Database shard1 Service
Wants=network.target
After=network.target

[Service]
Type=forking
PIDFile=/var/lib/mongodb/shard1/log/mongod.pid
ExecStart=/usr/bin/mongod -f /etc/mongodb/conf/shard1.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
```

在每台服务器上启动该分片的复制集各节点：

```bash
systemctl enable mongod-shard1
systemctl start mongod-shard1
```

在任意一台服务上初始化复制集配置：

```bash
#连接
$ mongo --port 27017
> use admin
switched to db admin
> config = { 
... _id : "shard1",
... members : [
...... {_id : 0, host : "10.211.55.11:27017" },
...... {_id : 1, host : "10.211.55.12:27017" },
...... {_id : 2, host : "10.211.55.13:27017" }
... ]
... }
> rs.initiate(config)
> rs.status()
> exit
```

稍微等一会儿，复制集就初始化好了。

以同样的方法安装配置分片shard2、shard3的复制集。

### 初始化配置服务的复制集

这个过程跟初始化某一个分片的复制集类似，这里就直接贴配置命令了。

在每台服务器上执行下面的命令：

```bash
cat <<EOF > /etc/mongodb/conf/config.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/lib/mongodb/config/log/mongod.log
 
# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb/config/data
  journal:
    enabled: true
 
# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /var/lib/mongodb/config/log/mongod.pid  # location of pidfile
 
# network interfaces
net:
  port: 27077
  bindIp: 0.0.0.0  # Listen to local interface only, comment to listen on all interfaces.

replication:
  replSetName: config

sharding:
    clusterRole: "configsvr"
EOF

cat <<EOF > /usr/lib/systemd/system/mongod-config.service
[Unit]
Description=MongoDB Database config Service
Wants=network.target
After=network.target

[Service]
Type=forking
PIDFile=/var/lib/mongodb/config/log/mongod.pid
ExecStart=/usr/bin/mongod -f /etc/mongodb/conf/config.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mongod-config
systemctl start mongod-config
```

在任意一台服务上初始化复制集配置：

```bash
#连接
$ mongo --port 27077
> use admin
switched to db admin
> config = { 
... _id : "config",
... members : [
...... {_id : 0, host : "10.211.55.11:27077" },
...... {_id : 1, host : "10.211.55.12:27077" },
...... {_id : 2, host : "10.211.55.13:27077" }
... ]
... }
> rs.initiate(config)
> rs.status()
> exit
```

稍微等一会儿，复制集就初始化好了。

### 配置路由服务器

最后配置路由服务器，比较简单，在每台服务器初始化其的配置文件并启动：

```bash
cat <<EOF > /etc/mongodb/conf/mongos.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/lib/mongodb/mongos/log/mongod.log
 
# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /var/lib/mongodb/mongos/log/mongod.pid  # location of pidfile
 
# network interfaces
net:
  port: 27088
  bindIp: 0.0.0.0  # Listen to local interface only, comment to listen on all interfaces.

sharding:
    configDB: "config/10.211.55.11:27077,10.211.55.12:27077,10.211.55.13:27077"
EOF

cat <<EOF > /usr/lib/systemd/system/mongos.service
[Unit]
Description=MongoDB Database mongos Service
Wants=network.target
After=network.target

[Service]
Type=forking
PIDFile=/var/lib/mongodb/mongos/log/mongod.pid
ExecStart=/usr/bin/mongos -f /etc/mongodb/conf/mongos.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mongos
systemctl start mongos
```

再在任意一台服务器上依次将3个分片加入到集群中：

```bash
#连接
$ mongo --port 27088
> use admin
switched to db admin
> sh.addShard( "shard1/10.211.55.11:27017,10.211.55.12:27017,10.211.55.13:27017")
> sh.addShard( "shard2/10.211.55.11:27018,10.211.55.12:27018,10.211.55.13:27018")
> sh.addShard( "shard3/10.211.55.11:27019,10.211.55.12:27019,10.211.55.13:27019")
> sh.status()
> exit
```

### 启用用户认证登录

创建一个超级管理员用户，在任意一台服务器上执行：

```bash
$ mongo --port 27088
> use admin
> db.createUser({
  user: "superadmin",
  pwd: "123456",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "clusterManager", db : "admin" }
  ],
  passwordDigestor: "server"
})
> exit
```

创建mongod、mongos之间通信所使用的key文件，在任意一台服务器上执行：

```bash
openssl rand -base64 756 > /etc/mongodb/conf/mongo.key
chmod 400 /etc/mongodb/conf/mongo.key
# 将/etc/mongodb/conf/mongo.key文件拷贝到其它服务器上，保持文件权限不变
```

修改每台服务器上的`/etc/mongodb/conf/shard*.conf`、`/etc/mongodb/conf/config.conf`、`/etc/mongodb/conf/mongos.conf`，其中`shard*.conf`、`config.conf`文件中加入以下内容：

```yaml
security:
    keyFile: "/etc/mongodb/conf/mongo.key"
    authorization: "enabled"
```

`mongos.conf`文件中加入以下内容：

```yaml
security:
    keyFile: "/etc/mongodb/conf/mongo.key"
```

在每台服务器上依次执行以下命令：

```bash
systemctl restart mognod-shard1
systemctl restart mognod-shard2
systemctl restart mognod-shard3
systemctl restart mognod-config
systemctl restart mognos
```

至此，整个mongodb高可用集群就搭建好了。

## 部署测试

先建一个database及user测试一下：

```bash
# 创建一个database的访问用户
$ mongo --username superadmin --password 123456 --authenticationDatabase admin --port 27088  admin
> use test
> db.createUser({
  user: "testadmin",
  pwd: "123456",
  roles: [
    { role: "dbOwner", db: "test" },
  ],
  passwordDigestor: "server"
})
> exit

# 使用该用户访问database，并插入数据，创建索引
$ mongo --username testadmin --password 123456 --authenticationDatabase test --port 27088  test
> db.col1.insert({"name": "xxj"})
> db.col1.createIndex( { "name": 1 } )
> exit

# 启用该database的分片及对某个collection分片
$ mongo --username superadmin --password 123456 --authenticationDatabase admin --port 27088  admin
> use admin
> sh.enableSharding("test")
> sh.shardCollection("test.col1", { "name" : 1 } )
> exit
```

## 总结

手工部署mongodb集群还是比较麻烦的，所以如果图省事儿，还是使用云厂商提供的PaaS服务好了，比如[云数据库 MongoDB](https://cloud.tencent.com/product/mongodb)。如果一定要自己搭建，还是建议用现成的[ansible-mongodb-cluster脚本](https://github.com/twoyao/ansible-mongodb-cluster)好了。

## 参考

1. https://zhuanlan.zhihu.com/p/28600032
2. https://gist.github.com/guileen/e2ebc1f7de2d2039fed2
3. https://gist.github.com/jwilm/5842956
4. https://docs.mongodb.com/manual/tutorial/enforce-keyfile-access-control-in-existing-replica-set/
5. https://docs.mongodb.com/manual/tutorial/deploy-shard-cluster/
6. https://docs.mongodb.com/manual/reference/method/js-collection/
7. https://docs.mongodb.com/manual/reference/method/js-sharding/
8. https://docs.mongodb.com/manual/reference/built-in-roles/#database-administration-roles