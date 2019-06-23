---
title: MariaDB Galera Cluster部署实战
author: Jeremy Xu
tags:
  - mariadb
  - database
  - galera
categories:
  - devops
date: 2018-02-10 21:45:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20180401
---

# 背景

项目中使用的mariadb+gelera集群模式部署，之前一直用的是mysql的master/slave方式部署数据库的，这种集群模式以前没怎么搞过，这里研究并记录一下。

# MariaDB Galera Cluster 介绍

MariaDB 集群是 MariaDB 同步多主机集群。它仅支持 XtraDB/ InnoDB 存储引擎（虽然有对 MyISAM 实验支持 - 看 wsrep_replicate_myisam 系统变量）。

主要功能:

- 同步复制
- 真正的 multi-master，即所有节点可以同时读写数据库
- 自动的节点成员控制，失效节点自动被清除
- 新节点加入数据自动复制
- 真正的并行复制，行级
- 用户可以直接连接集群，使用感受上与MySQL完全一致

优势:

- 因为是多主，所以不存在Slavelag(延迟)
- 不存在丢失事务的情况
- 同时具有读和写的扩展能力
- 更小的客户端延迟
- 节点间数据是同步的,而 Master/Slave 模式是异步的,不同 slave 上的 binlog 可能是不同的

技术:

Galera 集群的复制功能基于 Galeralibrary 实现,为了让 MySQL 与 Galera library 通讯，特别针对 MySQL 开发了 wsrep API。

Galera 插件保证集群同步数据，保持数据的一致性，靠的就是可认证的复制，工作原理如下图：

![mariadb_galera_cluster](/images/20180210/mariadb_galera_cluster.png)

当客户端发出一个 commit 的指令，在事务被提交之前，所有对数据库的更改都会被`write-set`收集起来,并且将 `write-set` 纪录的内容发送给其他节点。

`write-set` 将在每个节点进行认证测试，测试结果决定着节点是否应用`write-set`更改数据。

如果认证测试失败，节点将丢弃 write-set ；如果认证测试成功，则事务提交。

# MariaDB Galera Cluster搭建

我这里实验时使用的操作系统是CentOS7，使用了3台虚拟机，IP分别为`10.211.55.6`、`10.211.55.7`、`10.211.55.8`

## 关闭防火墙及selinux

为了先把MariaDB Galera Cluster部署起来，不受防火墙、selinux的干扰，先把3台虚拟机上这俩关闭了。如果防火墙一定要打开，可参考[这里](http://galeracluster.com/documentation-webpages/firewallsettings.html)设置防火墙规则。

```bash
systemctl disable firewalld.service
systemctl stop firewalld.service

setenforce 0
sed -i 's/^SELINUX=.*$/SELINUX=disabled/'  /etc/selinux/config
```

## 添加mariadb的yum源

在3台虚拟机上执行以下命令

```bash
# 已使用国内yum镜像，原镜像地址是http://yum.mariadb.org
echo '
[mariadb]
name = MariaDB
baseurl = http://mirrors.ustc.edu.cn/mariadb/yum/10.1/centos7-amd64
gpgkey=http://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1' > /etc/yum.repos.d/MariaDB.repo
```

## 安装软件包

在3台虚拟机上执行以下命令

```bash
yum install -y mariadb mariadb-server mariadb-common galera rsync
```

## 数据库初始化

在`10.211.55.6`上执行以下命令

```bash
systemctl start mariadb
mysql_secure_installation # 注意这一步是有交互的，需要回答一些问题，做一些设置
systemctl stop mariadb
```

## 修改galera相关配置

在3台虚拟机上均打开`/etc/my.cnf.d/server.cnf`进行编辑，修改片断如下：

```
...
[galera]
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_name=galera_cluster
wsrep_cluster_address="gcomm://10.211.55.6,10.211.55.7,10.211.55.8"
wsrep_node_name=10.211.55.6   # 注意这里改成本机IP
wsrep_node_address=10.211.55.6   # 注意这里改成本机IP
binlog_format=row
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
...
```

## 启动MariaDB Galera Cluster服务

先在第1台虚拟机执行以下命令：

```bash
sudo -u mysql /usr/sbin/mysqld --wsrep-new-cluster &> /tmp/wsrep_new_cluster.log &
disown $!
tail -f /tmp/wsrep_new_cluster.log
```

出现 `ready for connections` ,证明启动成功，继续在另外两个虚拟机里执行命令：

```bash
systemctl start mariadb
```

等后面两个虚拟机里mariadb服务启动后，再到第1台虚拟机里执行以下命令：

```
(ps -ef|grep mysqld|grep -v grep|awk '{print $2}'|xargs kill -9) &>/dev/null
systemctl start mariadb
```

## 验证MariaDB Galera Cluster服务

在任意虚拟机里执行以下命令：

``` bash
mysql -e "show status like 'wsrep_cluster_size'"  # 这里应该显示集群里有3个节点
mysql -e "show status like 'wsrep_connected'"     # 这里应该显示ON
mysql -e "show status like 'wsrep_incoming_addresses'" # 这里应该显示10.211.55.7:3306,10.211.55.8:3306,10.211.55.6:3306
mysql -e "show status like 'wsrep_local_state_comment'" # 这里节点的同步状态
```

查看集群全部相关状态参数可执行以下命令：

```bash
mysql -e "show status like 'wsrep_%'"
```

至此，MariaDB Galera Cluster已经成功部署。

# MariaDB Galera Cluster的自启动

在实际使用中发现一个问题，Galera集群启动时必须按照一个特定的规则启动，研究了下，发现规则如下：

* 如果集群从来没有启动过（3个节点上都没有`/var/lib/mysql/grastate.dat`文件），则必要由其中一个节点以`--wsrep-new-cluster`参数启动，另外两个节点正常启动即可

* 如果集群以前启动过，则参考`/var/lib/mysql/grastate.dat`，找到`safe_to_bootstrap`为`1`的节点，在该节点上以`--wsrep-new-cluster`参数启动，另外两个节点正常启动即可

* 如果集群以前启动过，但参考`/var/lib/mysql/grastate.dat`，找不到`safe_to_bootstrap`为`1`的节点（一般是因为mariadb服务非正常停止造成），则在3个节点中随便找1个节点，将`/var/lib/mysql/grastate.dat`中的`safe_to_bootstrap`修改为1，再在该节点上以`--wsrep-new-cluster`参数启动，另外两个节点正常启动即可

从以上3种场景可知，正常情况下很难保证mariadb galera cluster可以无人值守地完成开机自启动。国外论坛上也有人反映了[这个问题](https://groups.google.com/forum/#!topic/codership-team/xxwWXR6xBug/discussion)，但好像官方的人员好像说设计上就是这样，怎么可以这样。。。

最后写了个脚本，放在3个虚拟机上面，解决了这个问题。脚本如下：

```bash
cat /usr/local/bin/mariadb_cluster_helper.sh

#!/bin/bash
GRASTATE_FILE=/var/lib/mysql/grastate.dat
WSREP_NEW_CLUSTER_LOG_FILE=/tmp/wsrep_new_cluster.log
# 如果启动mariadb超过10秒还没返回0，则认为失败了
START_MARIADB_TIMEOUT=10
# 以--wsrep-new-cluster参数启动，超过5次检查，发现仍没有其它节点加入集群，则认为此路不通
SPECIAL_START_WAIT_MAX_COUNT=5
# 得到本机IP
MY_IP=$(grep 'wsrep_node_address' /etc/my.cnf.d/server.cnf | awk -F '=' '{print $2}')

# 杀掉mysqld进程
function kill_mysqld_process() {
    (ps -ef|grep mysqld|grep -v grep|awk '{print $2}'|xargs kill -9) &>/dev/null
}

# 正常启动mariadb
function start_mariadb_normal(){
    # 首先确保safe_to_bootstrap标记为0
    sed -i 's/^safe_to_bootstrap.*$/safe_to_bootstrap: 0/' $GRASTATE_FILE
    timeout $START_MARIADB_TIMEOUT systemctl start mariadb &> /dev/null
    return $?
}

# 以--wsrep-new-cluster参数启动mariadb
function start_mariadb_special(){
    # 首先确保safe_to_bootstrap标记为1
    sed -i 's/^safe_to_bootstrap.*$/safe_to_bootstrap: 1/' $GRASTATE_FILE
    # 以--wsrep-new-cluster参数启动mariadb
    /usr/sbin/mysqld --user=mysql --wsrep-new-cluster &> $WSREP_NEW_CLUSTER_LOG_FILE &
    disown $!
    try_count=0
    # 循环检查
    while [ 1 ]; do
        # 如果超过SPECIAL_START_WAIT_MAX_COUNT次检查，仍没有其它节点加入集群，则认为此路不通，尝试正常启动，跳出循环
        if [ $try_count -gt $SPECIAL_START_WAIT_MAX_COUNT ] ; then
            kill_mysqld_process
            start_mariadb_normal
            return $?
        fi
        new_joined_count=$(grep 'synced with group' /tmp/wsrep_new_cluster.log | grep -v $MY_IP|wc -l)
        exception_count=$(grep 'exception from gcomm, backend must be restarted' $WSREP_NEW_CLUSTER_LOG_FILE | wc -l)
        # 如果新加入的节点数大于0，则认为集群就绪了，可正常启动了，跳出循环
        # 如果运行日志中发现了异常(两个节点都以--wsrep-new-cluster参数启动，其中一个会报错)，则认为此路不通，尝试正常启动，跳出循环
        if [ $new_joined_count -gt 0 ] || [ $exception_count -gt 0 ] ; then
            kill_mysqld_process
            start_mariadb_normal
            return $?
        else
            try_count=$(( $try_count + 1 ))
        fi
        sleep 5
    done
}

# 首先杀掉mysqld进程
kill_mysqld_process

ret=-1

# 如果safe_to_bootstrap标记为1，则立即以--wsrep-new-cluster参数启动
if [ -f $GRASTATE_FILE ]; then
    safe_bootstrap_flag=$(grep 'safe_to_bootstrap' $GRASTATE_FILE | awk -F ': ' '{print $2}')
    if [ $safe_bootstrap_flag -eq 1 ] ; then
        start_mariadb_special
        ret=$?
    else
        start_mariadb_normal
        ret=$?
    fi
else
    start_mariadb_normal
    ret=$?
fi

# 随机地按某种方式启动，直到以某种方式正常启动以止；否则杀掉mysqld进程，随机休息一会儿，重试
while [ $ret -ne 0 ]; do
    kill_mysqld_process
    sleep_time=$(( $RANDOM % 10 ))
    sleep $sleep_time
    choice=$(( $RANDOM % 2 ))
    ret=-1
    if [ $choice -eq 0 ] ; then
        start_mariadb_special
        ret=$?
    else
        start_mariadb_normal
        ret=$?
    fi
done

# 使上述脚本开机自启动
chmod +x /usr/local/bin/mariadb_cluster_helper.sh
chmod +x /etc/rc.d/rc.local
echo '
/usr/local/bin/mariadb_cluster_helper.sh &> /var/log/mariadb_cluster_helper.log &' >> /etc/rc.d/rc.local
```

然后3个节点终于可以开机自启动自动组成集群了。

# 搭配keepalived+haproxy+clustercheck

为了保证mariadb galera集群的高可用，可以使用haproxy进行请求负载均衡，同时为了实现haproxy的高可用，可使用keepalived实现haproxy的热备方案。keepalived实现haproxy的热备方案可参见之前的[博文](http://jeremy-xu.oschina.io/2018/02/25/%E9%AB%98%E5%8F%AF%E7%94%A8%E4%B9%8Bkeepalived&haproxy/#%E4%BD%BF%E7%94%A8keepalived%E5%AE%9E%E7%8E%B0haproxy%E9%AB%98%E5%8F%AF%E7%94%A8)。这里重点说一下haproxy对mariadb galera集群的请求负载均衡。

这里使用了 https://github.com/olafz/percona-clustercheck 所述方案，使用外部脚本在应用层检查galera节点的状态。

首先在mariadb里进行授权：

```sql
GRANT PROCESS ON *.* TO 'clustercheckuser'@'%' IDENTIFIED BY 'clustercheckpassword!'
```

下载检测脚本：

```bash
wget -O /usr/bin/clustercheck https://raw.githubusercontent.com/olafz/percona-clustercheck/master/clustercheck
chmod +x /usr/bin/clustercheck
```

准备检测脚本用到的配置文件：

```
MYSQL_USERNAME="clustercheckuser"
MYSQL_PASSWORD="clustercheckpassword!"
MYSQL_HOST="$db_ip"
MYSQL_PORT="3306"
AVAILABLE_WHEN_DONOR=0
```

测试一下监控脚本：

```bash
# /usr/bin/clustercheck > /dev/null
# echo $?
0 # synced
1 # un-synced
```

使用xinetd暴露http接口，用于检测galera节点同步状态：

```
cat > /etc/xinetd.d/mysqlchk << EOF
# default: on
# description: mysqlchk
service mysqlchk
{
        disable = no
        flags = REUSE
        socket_type = stream
        port = 9200
        wait = no
        user = nobody
        server = /usr/bin/clustercheck
        log_on_failure += USERID
        only_from = 0.0.0.0/0
        per_source = UNLIMITED
}
EOF

service xinetd restart
```

测试一下暴露出的http接口：

```
curl http://127.0.0.1:9200
Galera cluster node is synced. # synced
Galera cluster node is not synced # un-synced
```

最后在`/etc/haproxy/haproxy.cfg`里配置负载均衡：

```
...
frontend vip-mysql
    bind $vip:3306
    timeout client 900m
    log global
    option tcplog
    mode tcp
    default_backend vms-mysql
backend vms-mysql
    option httpchk
    stick-table type ip size 1000
    stick on dst
    balance leastconn
    timeout server 900m
    server mysql1 $db1_ip:3306 check inter 1s port 9200 backup on-marked-down shutdown-sessions maxconn 60000
    server mysql2 $db2_ip:3306 check inter 1s port 9200 backup on-marked-down shutdown-sessions maxconn 60000
    server mysql2 $db3_ip:3306 check inter 1s port 9200 backup on-marked-down shutdown-sessions maxconn 60000

...
```

# 搭配galera仲裁服务

官方也提到gelera集群最少要三节点部署，但每增加一个节点，要付出相应的资源，因此也可以最少两节点部署，再加上一个galera仲裁服务。

> The recommended deployment of Galera Cluster is that you use a minimum of three instances. Three nodes, three datacenters and so on.
>
> In the event that the expense of adding resources, such as a third datacenter, is too costly, you can use [Galera Arbitrator](http://galeracluster.com/documentation-webpages/glossary.html#term-galera-arbitrator). Galera Arbitrator is a member of the cluster that participates in voting, but not in the actual replication

这种部署模式有两个好处：

1. 使集群刚好是奇数节点，不易产生脑裂。
2. 可能通过它得到一个一致的数据库状态快照，可以用来备份。

这种部署模式的架构图如下：

![mage-20180401214224](/images/20180401/image-201804012142243.png)

部署方法也比较简单：

```bash
# 假设已经构建了一个两节点的galera集群，在第3个节点部署garbd服务
echo '
GALERA_NODES="10.211.55.6:4567 10.211.55.7:4567" # 这里是两节点的地址
GALERA_GROUP="galera_cluster"  # 这里的group名称保持与两节点的wsrep_cluster_name属性一致
LOG_FILE="/var/log/garb.log"
' > /etc/sysconfig/garb
systemctl start garb # 启动garbd服务
```

测试一下效果。

首先看一下两节点部署产生脑裂的场景。

```bash
# 首先在第3个节点停止garb服务
systemctl stop garb

# 然后在第2个节点drop掉去住第1个节点和仲裁节点的数据包
iptables -A OUTPUT -d 10.211.55.6 -j DROP
iptables -A OUTPUT -d 10.211.55.9 -j DROP

# 这时检查前两个节点的同步状态，发生脑裂了，都不是同步状态了
mysql -e "show status like 'wsrep_local_state_comment'"
+---------------------------+-------------+
| Variable_name             | Value       |
+---------------------------+-------------+
| wsrep_local_state_comment | Initialized |
+---------------------------+-------------+
```

再试验下有仲裁节点参与的场景。

```bash
# 首先在第3个节点启动garb服务
systemctl start garb

# 在前两个节点查看集群节点数，发现是3个，说明包括了仲裁节点
mysql -e "show status like 'wsrep_cluster_size'"
+---------------------------+-------------+
| Variable_name             | Value       |
+---------------------------+-------------+
| wsrep_cluster_size        | 3           |
+---------------------------+-------------+

# 然后在第2个节点drop掉去住第1个节点和仲裁节点的数据包
iptables -A OUTPUT -d 10.211.55.6 -j DROP
iptables -A OUTPUT -d 10.211.55.9 -j DROP

# 这时检查第1个节点的同步状态，仍然是同步状态
mysql -e "show status like 'wsrep_local_state_comment'"
+---------------------------+-------------+
| Variable_name             | Value       |
+---------------------------+-------------+
| wsrep_local_state_comment | Synced      |
+---------------------------+-------------+

# 再在第1个节点查看集群节点数，发现是2个
mysql -e "show status like 'wsrep_cluster_size'"
+---------------------------+-------------+
| Variable_name             | Value       |
+---------------------------+-------------+
| wsrep_cluster_size        | 2           |
+---------------------------+-------------+

# 这时检查第2个节点的同步状态，发现是未同步的
mysql -e "show status like 'wsrep_local_state_comment'"
+---------------------------+-------------+
| Variable_name             | Value       |
+---------------------------+-------------+
| wsrep_local_state_comment | Initialized |
+---------------------------+-------------+
```

以前试验说明采用了仲裁节点后，因为集群节点数变为了奇数，有效地避免了脑裂，同时将真正有故障的节点隔离出去了。

# 参考

1. https://segmentfault.com/a/1190000002955693
2. https://github.com/olafz/percona-clustercheck
3. http://galeracluster.com/documentation-webpages/arbitrator.html
