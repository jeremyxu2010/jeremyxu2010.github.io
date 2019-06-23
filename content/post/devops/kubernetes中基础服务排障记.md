---
title: kubernetes中基础服务排障记
tags:
  - kubernetes
  - mysql
  - redis
  - iperf3
categories:
  - devops
date: 2019-05-30 18:40:00+08:00
---

工作中需要将原本部署在物理机或虚拟机上的一些基础服务搬到kubernetes中，在搬的过程中遇到了不少坑，这里记录一下。

## 异常网络引起的问题

之前使用[redis-operator](https://github.com/spotahome/redis-operator)在kubernetes中部署了一套Redis集群，可测试的同事使用[redis-benchmark](https://redis.io/topics/benchmarks)随便一压测，这个集群就会出问题。经过艰苦的问题查找过程，终于发现了问题，原来是两个虚拟机之间的网络存在异常。

经验教训，在测试前可用[iperf3](https://iperf.fr/)先测试下node节点之间，pod节点之间的网络状况，方法如下：

```bash
# 在某台node节点上启动iperf3服务端
$ iperf3 --server

# 在另一台node节点上启动iperf3客户端
$ iperf3 --client ${node_ip}  --length 150 --parallel 100 -t 60

# 在kuberntes中部署iperf3的服务端与客户端
$ kubectl apply -f https://raw.githubusercontent.com/Pharb/kubernetes-iperf3/master/iperf3.yaml

# 查看iperf3相关pod的podIP
$ kubectl get pod -o wide

# 在某个iperf3 client的pod中执行iperf3命令，以测试其到iperf3 server pod的网络状况
$ kubectl exec -ti iperf3-clients-5b5ll -- iperf3 --client ${iperf3_server_pod_ip} --length 150 --parallel 100 -t 60
```

## mysql低版本引起的集群脑裂

之前使用[mysql-operator](https://github.com/oracle/mysql-operator)在kubernetes中部署了一套3节点MySQL InnoDB集群，测试反馈压测一段时间后，这个集群会变得不可访问。检查出问题时mysql集群中mysql容器的日志，发现以下问题：

```bash
$ kubectl logs mysql-0 -c mysql

2018-04-22T15:24:36.984054Z 0 [ERROR] [MY-000000] [InnoDB] InnoDB: Assertion failure: log0write.cc:1799:time_elapsed >= 0
InnoDB: thread 139746458191616
InnoDB: We intentionally generate a memory trap.
InnoDB: Submit a detailed bug report to http://bugs.mysql.com.
InnoDB: If you get repeated assertion failures or crashes, even
InnoDB: immediately after the mysqld startup, there may be
InnoDB: corruption in the InnoDB tablespace. Please refer to
InnoDB: http://dev.mysql.com/doc/refman/8.0/en/forcing-innodb-recovery.html
InnoDB: about forcing recovery.
15:24:36 UTC - mysqld got signal 6 ;
This could be because you hit a bug. It is also possible that this binary
or one of the libraries it was linked against is corrupt, improperly built,
or misconfigured. This error can also be caused by malfunctioning hardware.
Attempting to collect some information that could help diagnose the problem.
As this is a crash and something is definitely wrong, the information
collection process might fail.

key_buffer_size=8388608
read_buffer_size=131072
max_used_connections=1
max_threads=151
thread_count=2
connection_count=1
It is possible that mysqld could use up to 
key_buffer_size + (read_buffer_size + sort_buffer_size)*max_threads = 67841 K  bytes of memory
Hope that's ok; if not, decrease some variables in the equation.

Thread pointer: 0x0
Attempting backtrace. You can use the following information to find out
where mysqld died. If you see no messages after this, something went
terribly wrong...
stack_bottom = 0 thread_stack 0x46000
/home/mdcallag/b/orig811/bin/mysqld(my_print_stacktrace(unsigned char*, unsigned long)+0x3d) [0x1b1461d]
/home/mdcallag/b/orig811/bin/mysqld(handle_fatal_signal+0x4c1) [0xd58441]
/lib/x86_64-linux-gnu/libpthread.so.0(+0x11390) [0x7f1cae617390]
/lib/x86_64-linux-gnu/libc.so.6(gsignal+0x38) [0x7f1cacb0a428]
/lib/x86_64-linux-gnu/libc.so.6(abort+0x16a) [0x7f1cacb0c02a]
/home/mdcallag/b/orig811/bin/mysqld(ut_dbg_assertion_failed(char const*, char const*, unsigned long)+0xea) [0xb25e13]
/home/mdcallag/b/orig811/bin/mysqld() [0x1ce5408]
/home/mdcallag/b/orig811/bin/mysqld(log_flusher(log_t*)+0x2fb) [0x1ce5fab]
/home/mdcallag/b/orig811/bin/mysqld(std::thread::_Impl<std::_Bind_simple<Runnable (void (*)(log_t*), log_t*)> >::_M_run()+0x68) [0x1ccbe18]
/usr/lib/x86_64-linux-gnu/libstdc++.so.6(+0xb8c80) [0x7f1cad476c80]
/lib/x86_64-linux-gnu/libpthread.so.0(+0x76ba) [0x7f1cae60d6ba]
/lib/x86_64-linux-gnu/libc.so.6(clone+0x6d) [0x7f1cacbdc41d]
The manual page at http://dev.mysql.com/doc/mysql/en/crashing.html contains
```

在mysql的bug跟踪系统里搜索了一下，果然发现了这个[bug](https://bugs.mysql.com/bug.php?id=90670)，官方提示这个bug在`8.0.12`之前都存在，推荐升级到`8.0.13`之后的版本。

还好[mysql-operator](https://github.com/oracle/mysql-operator)支持安装指定版本的MySQL，这里通过指定版本为最新稳定版`8.0.16`解决问题。

```yaml
apiVersion: mysql.oracle.com/v1alpha1
kind: Cluster
metadata:
  name: mysql
spec:
  members: 3
  version: "8.0.16"
```

## 超额使用ephemeral-storage空间引起集群故障

MySQL InnoDB集群方案中依赖于[MySQL Group Replication](https://dev.mysql.com/doc/refman/8.0/en/group-replication.html)在主从节点间同步数据，这种同步本质上是依赖于MySQL的binlog的，因此如果是压测场景，会在短时间内产生大量binlog日志，而这些binlog日志十分占用存储空间。

而如果使用使用[mysql-operator](https://github.com/oracle/mysql-operator)创建MySQL集群，如果在yaml文件中不声明volumeClaimTemplate，则pod会使用`ephemeral-storage`空间，虽然kubernetes官方提供了[办法](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#requests-and-limits-setting-for-local-ephemeral-storage)来设置`ephemeral-storage`空间的配额，但mysql-operator本身并没有提供参数让用户指定`ephemeral-storage`空间的配额。这样当MySQL集群长时间压测后，产生的大量binlog会超额使用`ephemeral-storage`空间，最终kubernetes为了保证容器平台的稳定，会将该pod杀掉，当3节点MySQL集群中有2个pod被杀掉时，整个集群就处于不法自动恢复的状态了。

```
Events:
  Type     Reason   Age   From                 Message
  ----     ------   ----  ----                 -------
  Warning  Evicted  39m   kubelet, 9.77.34.64  The node was low on resource: ephemeral-storage. Container mysql was using 256Ki, which exceeds its request of 0. Container mysql-agent was using 11572Ki, which exceeds its request of 0.
  Normal   Killing  39m   kubelet, 9.77.34.64  Killing container with id docker://mysql-agent:Need to kill Pod
  Normal   Killing  39m   kubelet, 9.77.34.64  Killing container with id docker://mysql:Need to kill Pod
```

解决办法也很简单，一是参考[示例](https://github.com/oracle/mysql-operator/blob/master/examples/cluster/cluster-with-data-volume-and-backup-volume.yaml)在yaml文件中声明volumeClaimTemplate，另外还可以在mysql的配置文件中指定[binlog_expire_logs_seconds](https://dev.mysql.com/doc/refman/8.0/en/replication-options-binary-log.html#sysvar_binlog_expire_logs_seconds)参数，在保证在压测场景下，能快速删除binlog，方法如下：

```yaml
apiVersion: v1
data:
  my.cnf: |
    [mysqld]
    default_authentication_plugin=mysql_native_password
    skip-name-resolve
    binlog_expire_logs_seconds=300
kind: ConfigMap
metadata:
  name: mycnf
---
apiVersion: mysql.oracle.com/v1alpha1
kind: Cluster
metadata:
  name: mysql
spec:
  members: 3
  version: "8.0.16"
  config:
    name: mycnf
  volumeClaimTemplate:
    metadata:
      name: data
    spec:
      storageClassName: default
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 1Gi
  backupVolumeClaimTemplate:
    metadata:
      name: backup-data
    spec:
      storageClassName: default
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 1Gi
```

至此，Redis集群、MySQL集群终于可以稳定地在kubernetes中运行了。

