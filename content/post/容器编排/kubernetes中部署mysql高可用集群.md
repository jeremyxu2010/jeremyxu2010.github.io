---
title: kubernetes中部署mysql高可用集群
tags:
  - kubernetes
  - mysql
  - proxysql
  - helm
categories:
  - 容器编排
date: 2019-08-31 18:40:00+08:00
---

很多软件后端使用的存储都是mysql，当这些软件系统在生产环境部署时，都会面临一个严峻问题，需要在生产环境中部署一个高可用的mysql集群服务。刚好在最近一周的工作中，需要在kubernetes环境中搭建mysql高可用集群，这里记录一下。

## 搭建MySQL集群

MySQL的主从半同步复制方案、Galera集群方案以前都也实践过，感觉都不是太友好，配置比较麻烦，而且发生故障转移时经常需要人工参与。所以这里还是采用MySQL官方推荐的Group Replication集群方案。关于MySQL Group Replication集群的架构设计可以看[官方文档](https://dev.mysql.com/doc/refman/5.7/en/group-replication.html)，懒得看英文的话，也可以看我之前整理出的[资料](https://jeremyxu2010.github.io/2019/05/mysql-innodb-cluster%E5%AE%9E%E6%88%98/#mysql-innodb-cluster%E7%AE%80%E4%BB%8B)。另外kubedb网页上也有介绍[MySQL几种高可用方案的构架方案](https://kubedb.com/docs/0.12.0/guides/mysql/clustering/overview/)，也比较有意思。

[之前的博文](https://jeremyxu2010.github.io/2019/05/mysql-innodb-cluster%E5%AE%9E%E6%88%98/#%E6%90%AD%E5%BB%BAmysql-innodb-cluster)也讲过在非容器环境搭建MySQL Group Replication集群，现在在Kubernetes的容器环境配合kubedb，搭建更方便了，命令如下：

```bash
# 添加appscode的helm仓库
$ helm repo add appscode https://charts.appscode.com/stable/
$ helm repo update
# 部署kubedb
$ helm install appscode/kubedb --namespace kube-system --name kubedb --version 0.12.0

# 创建部署mysql集群的命名空间
$ kubectl create ns demo

# 创建MySQL类型的自定义资源，kubedb作为Controller会负责自动将MySQL Group Replication集群部署好
$ cat << EOF | kubectl apply -f -
---
apiVersion: catalog.kubedb.com/v1alpha1
kind: MySQLVersion
metadata:
  name: "5.7.25"
  labels:
    app: kubedb
spec:
  version: "5.7.25"
  db:
    image: "kubedb/mysql:5.7.25"
  exporter:
    image: "kubedb/mysqld-exporter:v0.11.0"
  tools:
    image: "kubedb/mysql-tools:5.7.25"
  podSecurityPolicies:
    databasePolicyName: "mysql-db"
    snapshotterPolicyName: "mysql-snapshot"
  initContainer:
    image: "kubedb/mysql-tools:5.7.25"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-custom-config
  namespace: demo
data:
  my-config.cnf: |
    [mysqld]
    max_connections = 2048
    read_buffer_size = 4194304
    skip-name-resolve
    innodb_lru_scan_depth = 256
    character-set-server = utf8mb4
    collation-server = utf8mb4_general_ci
---
apiVersion: kubedb.com/v1alpha1
kind: MySQL
metadata:
  name: mysql
  namespace: demo
spec:
  version: "5.7.25"
  replicas: 3
  topology:
    mode: GroupReplication
    group:
      name: "dc002fc3-c412-4d18-b1d4-66c1fbfbbc9b"
      baseServerID: 100
  storageType: Durable
  configSource:
    configMap:
      name: my-custom-config
  storage:
    storageClassName: "standard"
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
  terminationPolicy: WipeOut
  updateStrategy:
    type: RollingUpdate
---
EOF
```

## 实现MySQL集群透明访问

MySQL集群搭建好了，如何访问呢？kubedb的文档上有说明：

```bash
# 首先找到mysql的root密码
$ kubectl get secrets -n demo my-group-auth -o jsonpath='{.data.\username}' | base64 -d
root
$ kubectl get secrets -n demo my-group-auth -o jsonpath='{.data.\password}' | base64 -d
dlNiQpjULZvEqo3B

# 读数据的话，连接3个member中任何一个mysql实例都可以
$ kubectl exec -it -n demo mysql-0 -- mysql -u root --password=dlNiQpjULZvEqo3B --host=mysql-0.mysql-gvr.demo -e "select 1;"
mysql: [Warning] Using a password on the command line interface can be insecure.
+---+
| 1 |
+---+
| 1 |
+---+

# 写数据的话，得先找到当前是master的mysql实例地址
$ kubectl exec -it -n demo mysql-0 -- mysql -u root --password=dlNiQpjULZvEqo3B --host=mysql-0.mysql-gvr.demo -e "SELECT MEMBER_HOST, MEMBER_PORT FROM performance_schema.replication_group_members WHERE MEMBER_ID = (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'group_replication_primary_member');"
+------------------------------+-------------+
| MEMBER_HOST                  | MEMBER_PORT |
+------------------------------+-------------+
| mysql-0.mysql-gvr.demo |        3306 |
+------------------------------+-------------+

# 然后连接mysql的master实例地址进行数据库写操作
$ kubectl exec -it -n demo mysql-0 -- mysql -u root --password=dlNiQpjULZvEqo3B --host=mysql-0.mysql-gvr.demo -P 3306 -e "create database test;"
```

特别对于写操作，上层应用还得先找mysql的master实例地址后，操作才能进行下去，这样太难受了。

这里我们可以使用[MySQL Router方案](https://dev.mysql.com/doc/mysql-router/8.0/en/)来处理，这个在[之前的博文](https://jeremyxu2010.github.io/2019/05/mysql-innodb-cluster%E5%AE%9E%E6%88%98/#%E5%88%9D%E5%A7%8B%E5%8C%96mysql-router)里也讲到。不过在MySQL官方的方案里`MySQL Router`一般是[作为应用的sidecar进行部署](https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-general-using-deploying.html)的。我这里想更集中式地部署，于是采用了业界广泛实践的[ProxySQL方案](https://github.com/sysown/proxysql)。

部署ProxySQL的过程如下：

```bash
# 在MGR集群中创建检查MGR节点状态的函数和视图
$ curl -O https://raw.githubusercontent.com/lefred/mysql_gr_routing_check/master/addition_to_sys.sql
$ kubectl cp addition_to_sys.sql demo/mysql-0:/tmp/
$ kubectl -n demo exec -ti mysql-0 -- mysql -uroot -pdlNiQpjULZvEqo3B --host=mysql-0.mysql-gvr.demo -P 3306 -e 'source /tmp/addition_to_sys.sql'

# 在MGR集群中创建监控用户并授权
$ kubectl -n demo exec -ti mysql-0 -- mysql -uroot -pdlNiQpjULZvEqo3B --host=mysql-0.mysql-gvr.demo -P 3306 -e "grant SELECT on sys.* to 'proxymonitor'@'%' identified by 'proxymonitor';flush privileges;"

# 在MGR集群中创建访问业务库的用户并授权
$ kubectl -n demo exec -ti mysql-0 -- mysql -uroot -pdlNiQpjULZvEqo3B --host=mysql-0.mysql-gvr.demo -P 3306 -e "grant all privileges on biz_db.* to 'biz_user'@'%' identified by 'bizpassword';flush privileges;"

# 借助k8s-proxysql-cluster项目提供的helm charts部署proxysql 3实例集群
$ git clone https://github.com/jeremyxu2010/k8s-proxysql-cluster.git
$ docker build --rm -t scienta/k8s-proxysql-cluster:1.0.0 -f k8s-proxysql-cluster/docker/k8s-proxysql-cluster.Dockerfile k8s-proxysql-cluster/docker
$ cat << EOF > proxysql-values.yaml
# Default admin username
proxysql:
  admin:
    username: admin
    password: admin
  clusterAdmin:
    username: cluster1
    password: secret1pass
# MySQL Settings
mysql:
  # This is the monitor user, just needs usage rights on the databases
  monitor:
    username: proxymonitor
    password: proxymonitor
  admin:
    username: root
    password: dlNiQpjULZvEqo3B
EOF
$ helm install --namespace demo --name proxysql k8s-proxysql-cluster/deploy/charts/proxysql-cluster/ -f proxysql-values.yaml

# 在proxysql中初始化MGR集群的相关信息
$ cat << EOF > init-proxysql.sql
# 向mysql_servers表插入MGR各member的地址信息，其中当前的master示例放入hostgroup 1中，所有示例放入hostgroup 2中
DELETE FROM mysql_servers;
INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_connections) VALUES (1, 'mysql-0.mysql-gvr.demo', 3306, 2048);
INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_connections) VALUES (2, 'mysql-0.mysql-gvr.demo', 3306, 2048);
INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_connections) VALUES (2, 'mysql-1.mysql-gvr.demo', 3306, 2048);
INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_connections) VALUES (2, 'mysql-2.mysql-gvr.demo', 3306, 2048);

# 向mysql_group_replication_hostgroups表插入proxysql使用hostgroup的规则
# * proxysql会导流写请求到writer_hostgroup，即hostgrup 1
# * proxysql会导流读请求到reader_hostgroup，即hostgrup 2
# * backup_writer_hostgroup的id为3
# * offline_hostgroup的id为4
# * active表明这条规则是生效的
# * max_writers表明最多只有一个writer，如果监测到多个实例是可写的，则只会将一个实例移入writer_hostgroup，其它实例会被移入backup_writer_hostgroup
# * writer_is_also_reader表明可写实例也会被作为reader
# * max_transactions_behind表明后端最大允许的事务数
DELETE FROM mysql_group_replication_hostgroups;
insert into mysql_group_replication_hostgroups
(writer_hostgroup,backup_writer_hostgroup,reader_hostgroup, offline_hostgroup,active,max_writers,writer_is_also_reader,max_transactions_behind)
values (1,3,2,4,1,1,1,100);

# 将mysql_servers及mysql_group_replication_hostgroups的信息刷入RUNTIME及DISK
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

# 插入允许连接的帐户信息，注意要与MGR集群中的访问用户信息一致
DELETE FROM mysql_users;
insert into mysql_users(username, password, default_hostgroup) values('biz_user', 'bizpassword', 1);

# 将mysql_users的信息刷入RUNTIME及DISK
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
EOF

# 连接proxysql，导入上述初始配置
$ kubectl cp init-proxysql.sql demo/proxysql-proxysql-cluste-0:/tmp/
$ kubectl -n demo exec -ti proxysql-proxysql-cluste-0 -- mysql -u admin -h127.0.0.1 -padmin -P6032 -e 'source /tmp/init-proxysql.sql'
```

**这里要注意，ProxySQL做了分层的配置设计，要想配置生效并持久化，一定要将配置信息刷入RUNTIME及DISK，详见[这里](https://github.com/sysown/proxysql/wiki/Configuring-ProxySQL)**

## 业务访问MySQL

像上面那样部署了MySQL Group Replication集群和ProxySQL集群后，业务方访问MySQL服务就很轻松了：

```bash
# 容器内
$ mysql -ubiz_user -pbizpassword -hproxysql-proxysql-cluste.demo -P3306 biz_db -e "select 1;"

# 容器外，先得到k8s svc的clusterIP
$ kubectl -n demo get svc  proxysql-proxysql-cluste -o=jsonpath='{.spec.clusterIP}'
10.68.63.23
# 然后也是直接连接
$ mysql -ubiz_user -pbizpassword -h10.68.63.23 -P3306 biz_db -e "select 1;"
```

done

## 参考

1. https://kubedb.com/docs/0.12.0/guides/mysql/clustering/overview/
2. https://kubedb.com/docs/0.12.0/guides/mysql/clustering/group_replication_single_primary/
3. https://kubedb.com/docs/0.12.0/concepts/databases/mysql/
4. https://www.xuejiayuan.net/blog/ea021ec24ac240db8665f0299dbb0667
5. https://blog.frognew.com/2017/08/proxysql-1.4-and-mysql-group-replication.html
6. https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-general-using-deploying.html
7. https://github.com/sysown/proxysql/wiki/Configuring-ProxySQL
8. http://fuxkdb.com/2018/08/25/%E5%A6%82%E4%BD%95%E7%A1%AE%E5%AE%9ASingle-Primary%E6%A8%A1%E5%BC%8F%E4%B8%8B%E7%9A%84MGR%E4%B8%BB%E8%8A%82%E7%82%B9/

