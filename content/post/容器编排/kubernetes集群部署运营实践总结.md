---
title: kubernetes集群部署运营实践总结
tags:
  - kubernetes
  - large-cluster
  - etcd
  - harbor
  - restic
categories:
  - 容器编排
date: 2019-11-02 18:40:00+08:00
---

最近为项目奔波，都没有多少时间写博文了。。。不过这大半个月在客户现场处理了大量kubernetes集群部署运营的相关工作，这里总结一下。

## kubernetes大规模集群优化

### 内核参数调化

增大部分内核选项，在`/etc/sysctl.conf`文件中添加下面片断：

```
fs.file-max=1000000
# max-file 表示系统级别的能够打开的文件句柄的数量， 一般如果遇到文件句柄达到上限时，会碰到
# "Too many open files"或者Socket/File: Can’t open so many files等错误。
# 配置arp cache 大小
net.ipv4.neigh.default.gc_thresh1=1024
# 存在于ARP高速缓存中的最少层数，如果少于这个数，垃圾收集器将不会运行。缺省值是128。
net.ipv4.neigh.default.gc_thresh2=4096
# 保存在 ARP 高速缓存中的最多的记录软限制。垃圾收集器在开始收集前，允许记录数超过这个数字 5 秒。缺省值是 512。
net.ipv4.neigh.default.gc_thresh3=8192
# 保存在 ARP 高速缓存中的最多记录的硬限制，一旦高速缓存中的数目高于此，垃圾收集器将马上运行。缺省值是1024。
# 以上三个参数，当内核维护的arp表过于庞大时候，可以考虑优化
net.netfilter.nf_conntrack_max=10485760
# 允许的最大跟踪连接条目，是在内核内存中netfilter可以同时处理的“任务”（连接跟踪条目）
net.netfilter.nf_conntrack_tcp_timeout_established=300
net.netfilter.nf_conntrack_buckets=655360
# 哈希表大小（只读）（64位系统、8G内存默认 65536，16G翻倍，如此类推）
net.core.netdev_max_backlog=10000
# 每个网络接口接收数据包的速率比内核处理这些包的速率快时，允许送到队列的数据包的最大数目。
fs.inotify.max_user_instances=524288
# 默认值: 128 指定了每一个real user ID可创建的inotify instatnces的数量上限
fs.inotify.max_user_watches=524288
# 默认值: 8192 指定了每个inotify instance相关联的watches的上限
```

### etcd性能优化

1. Etcd对磁盘写入延迟非常敏感，因此对于负载较重的集群，etcd一定要使用local SSD或者高性能云盘。可以使用`fio`测量磁盘实际顺序 IOPS。

  ```bash
  fio -filename=/dev/sda1 -direct=1 -iodepth 1 -thread -rw=write -ioengine=psync -bs=4k -size=60G -numjobs=64 -runtime=10 -group_reporting -name=file
  ```

2. 由于etcd必须将数据持久保存到磁盘日志文件中，因此来自其他进程的磁盘活动可能会导致增加写入时间，结果导致etcd请求超时和临时leader丢失。因此可以给etcd进程更高的磁盘优先级，使etcd服务可以稳定地与这些进程一起运行。

  ```bash
  ionice -c2 -n0 -p $(pgrep etcd)
  ```

3. 默认etcd空间配额大小为 2G，超过 2G 将不再写入数据。通过给etcd配置 `--quota-backend-bytes` 参数增大空间配额，最大支持 8G。

  ```
  --quota-backend-bytes 8589934592
  ```

4. 如果etcd leader处理大量并发客户端请求，可能由于网络拥塞而延迟处理follower对等请求。在follower 节点上可能会产生如下的发送缓冲区错误的消息：

   ```
   dropped MsgProp to 247ae21ff9436b2d since streamMsg's sending buffer is full
   dropped MsgAppResp to 247ae21ff9436b2d since streamMsg's sending buffer is full
   ```
   
   可以通过提高etcd对于对等网络流量优先级来解决这些错误。在 Linux 上，可以使用 tc 对对等流量进行优先级排序：
   
   ```bash
   tc qdisc add dev eth0 root handle 1: prio bands 3
   tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip sport 2380 0xffff flowid 1:1
   tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip dport 2380 0xffff flowid 1:1
   tc filter add dev eth0 parent 1: protocol ip prio 2 u32 match ip sport 2379 0xffff flowid 1:1
   tc filter add dev eth0 parent 1: protocol ip prio 2 u32 match ip dport 2379 0xffff flowid 1:1
   ```
   
5. 为了在大规模集群下提高性能，可以将events存储在单独的 ETCD 实例中，可以配置kube-apiserver参数：

   ```
   --etcd-servers="http://etcd1:2379,http://etcd2:2379,http://etcd3:2379" \
   --etcd-servers-overrides="/events#http://etcd4:2379,http://etcd5:2379,http://etcd6:2379"
   ```

### docker优化

1. 配置docker daemon并行拉取镜像，以提高镜像拉取效率，在`/etc/docker/daemon.json`中添加以下配置：

   ```
   "max-concurrent-downloads": 10
   ```

2. 可以使用local SSD或者高性能云盘作为docker容器的持久数据目录，在`/etc/docker/daemon.json`中添加以下配置：

   ```
   "data-root": "/ssd_mount_dir"
   ```

3. 启动pod时都会拉取pause镜像，为了减小拉取pause镜像网络带宽，可以每个node预加载pause镜像，在每个node节点上执行以下命令：

   ```bash
   docker load -i /tmp/preloaded_pause_image.tar
   ```

### kubelet优化

1. 设置 `--serialize-image-pulls=false`， 该选项配置串行拉取镜像，默认值时true，配置为false可以增加并发度。但是如果docker daemon 版本小于 1.9，且使用 aufs 存储则不能改动该选项。

2. 设置`--image-pull-progress-deadline=30`， 配置镜像拉取超时。默认值时1分，对于大镜像拉取需要适量增大超时时间。

3. kubelet 单节点允许运行的最大 Pod 数：`--max-pods=110`（默认是 110，可以根据实际需要设置）

### kube-apiserver优化

1. 设置 `--apiserver-count` 和 `--endpoint-reconciler-type`，可使得多个 kube-apiserver 实例加入到 Kubernetes Service 的 endpoints 中，从而实现高可用。

2. 设置 `--max-requests-inflight` 和 `--max-mutating-requests-inflight`，默认是 200 和 400。

   节点数量在 1000 - 3000 之间时，推荐：
   
   ```
   --max-requests-inflight=1500
   --max-mutating-requests-inflight=500
   ```
   
   节点数量大于 3000 时，推荐：
   
   ```
   --max-requests-inflight=3000
   --max-mutating-requests-inflight=1000
   ```
   
3. 使用`--target-ram-mb`配置kube-apiserver的内存，按以下公式得到一个合理的值：
  
   ```
   --target-ram-mb=node_nums * 60
   ```
   
### kube-controller-manager优化

1. kube-controller-manager可以通过 leader election 实现高可用，添加以下命令行参数：

   ```
   --leader-elect=true
   --leader-elect-lease-duration=15s
   --leader-elect-renew-deadline=10s
   --leader-elect-resource-lock=endpoints
   --leader-elect-retry-period=2s
   ```

2. 限制与kube-apiserver通信的qps，添加以下命令行参数：

   ```
   --kube-api-qps=100
   --kube-api-burst=150
   ```

### kube-scheduler优化

1. kube-scheduler可以通过 leader election 实现高可用，添加以下命令行参数：
  
   ```
   --leader-elect=true
   --leader-elect-lease-duration=15s
   --leader-elect-renew-deadline=10s
   --leader-elect-resource-lock=endpoints
   --leader-elect-retry-period=2s
   ```

2. 限制与kube-apiserver通信的qps，添加以下命令行参数：
  
   ```
   --kube-api-qps=100
   --kube-api-burst=150
   ```

### pod优化

在运行Pod的时候也需要注意遵循一些最佳实践。

1. 为容器设置资源请求和限制，尤其是一些基础插件服务
  
   ```
   spec.containers[].resources.limits.cpu
   spec.containers[].resources.limits.memory
   spec.containers[].resources.requests.cpu
   spec.containers[].resources.requests.memory
   spec.containers[].resources.limits.ephemeral-storage
   spec.containers[].resources.requests.ephemeral-storage
   ```
   
   在k8s中，会根据pod的limit 和 requests的配置将pod划分为不同的qos类别：
   
   ```
   * Guaranteed
   * Burstable
   * BestEffort
   ```
   
   当机器可用资源不够时，kubelet会根据qos级别划分迁移驱逐pod。被驱逐的优先级：`BestEffort > Burstable > Guaranteed`。

2. 对关键应用使用 nodeAffinity、podAffinity 和 podAntiAffinity 等保护，使其调度分散到不同的node上。比如kube-dns 配置：

3. 尽量使用控制器来管理容器（如 Deployment、StatefulSet、DaemonSet、Job 等）

## kubernetes集群数据备份与还原

### etcd数据

#### 备份

备份数据前先找到etcd集群当前的leader：

```bash
ETCDCTL_API=3 etcdctl --endpoints=127.0.0.1:2379 --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --cacert=/etc/kubernetes/pki/etcd/ca.crt endpoint --cluster status | grep -v 'false' | awk -F '[/ :]' '{print $4}'
```

然后登录到leader节点，备份snapshot db文件：

```bash
rsync -avp /var/lib/etcd/member/snap/db /tmp/etcd_db.bak
```

#### 还原

将备份的snaphost db文件上传到各个etcd节点，使用以下命令还原数据：

```bash
ETCDCTL_API=3 etcdctl snapshot restore \
            /tmp/etcd_db.bak \
            --endpoints=192.168.0.11:2379 \
            --name=192.168.0.11 \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --initial-advertise-peer-urls=https://192.168.0.11:2380 \
            --initial-cluster-token=etcd-cluster-0 \
            --initial-cluster=192.168.0.11=https://192.168.0.11:2380,192.168.0.12=https://192.168.0.12:2380,192.168.0.13=https://192.168.0.13:2380 \
            --data-dir=/var/lib/etcd/ \
            --skip-hash-check=true
```

### harbor

如果使用harbor作为镜像仓库与chart仓库，可使用脚本将harbor中所有的镜像和chart导入导出。

#### 备份

```bash
#!/bin/bash

harborUsername='admin'
harborPassword='Harbor12345'
harborRegistry='registry.test.com'
harborBasicAuthToken=$(echo -n "${harborUsername}:${harborPassword}" | base64)

docker login --username ${harborUsername} --password ${harborPassword} ${harborRegistry}

rm -f dist/images.list
rm -f dist/charts.list

# list projects
projs=`curl -s -k -H "Authorization: Basic ${harborBasicAuthToken}" "https://${harborRegistry}"'/api/projects?page=1&page_size=1000' | jq -r '.[] | "\(.project_id)=\(.name)"'`
for proj in ${projs[*]}; do
  projId=`echo $proj|cut -d '=' -f 1`
  projName=`echo $proj|cut -d '=' -f 2`

  # list repos in one project
  repos=`curl -s -k -H "Authorization: Basic ${harborBasicAuthToken}" "https://${harborRegistry}"'/api/repositories?page=1&page_size=1000&project_id='"${projId}" | jq -r '.[] | "\(.id)=\(.name)"'`
  for repo in ${repos[*]}; do
    repoId=`echo $repo|cut -d '=' -f 1`
    repoName=`echo $repo|cut -d '=' -f 2`

    # list tags in one repo
    tags=`curl -s -k -H "Authorization: Basic ${harborBasicAuthToken}" "https://${harborRegistry}"'/api/repositories/'"${repoName}"'/tags?detail=1' | jq -r '.[].name'`
    for tag in ${tags[*]}; do
      #echo ${tag};

      # pull image
      docker pull ${harborRegistry}/${repoName}:${tag}

      # tag image
      docker tag ${harborRegistry}/${repoName}:${tag} ${repoName}:${tag}

      # save image
      mkdir -p $(dirname dist/${repoName})
      docker save -o dist/${repoName}:${tag}.tar  ${repoName}:${tag}

      # record image to list file
      echo "${repoName}:${tag}" >> dist/images.list
    done
  done

  # list charts in one project
  charts=`curl -s -k -H "Authorization: Basic ${harborBasicAuthToken}" "https://${harborRegistry}"'/api/chartrepo/'"${projName}"'/charts' | jq -r '.[].name'`
  for chart in ${charts[*]}; do
    #echo ${chart}

    # list download urls in one chart
    durls=`curl -s -k -H "Authorization: Basic ${harborBasicAuthToken}" "https://${harborRegistry}"'/api/chartrepo/'"${projName}"'/charts/'"${chart}" | jq -r '.[].urls[0]'`
    #echo ${durl[*]}
    for durl in ${durls[*]}; do
        #echo ${durl};

        # download chart
        mkdir -p $(dirname dist/${projName}/${durl})
        curl -s -k -H "Authorization: Basic ${harborBasicAuthToken}" -o dist/${projName}/${durl} "https://${harborRegistry}/chartrepo/${projName}/${durl}"

        # record chart to list file
        echo "${projName}/${durl}" >> dist/charts.list
        
    done
  done
done
```

#### 还原

```bash
#!/bin/bash

harborUsername='admin'
harborPassword='Harbor12345'
harborRegistry='registry.test.com'

harborBasicAuthToken=$(echo -n "${harborUsername}:${harborPassword}" | base64)

docker login --username ${harborUsername} --password ${harborPassword} ${harborRegistry}

while IFS="" read -r image || [ -n "$image" ]
do
  projName=${image%%/*}
  # echo ${projName}

  # create harbor project
  curl -k -X POST -H "Authorization: Basic ${harborBasicAuthToken}" "https://${harborRegistry}/api/projects" -H "accept: application/json" -H "Content-Type: application/json" -d '{ "project_name": "'"$projName"'", "metadata": { "public": "true" }}'

  # load image
  docker load -i dist/${image}.tar

  # tag image
  docker tag ${image} ${harborRegistry}/${image}

  # push image
  docker push ${harborRegistry}/${image}

done < dist/images.list

while IFS="" read -r chart || [ -n "$chart" ]
do
  projName=${chart%%/*}
  # echo ${projName}

  # create harbor project
  curl -k -X POST -H "Authorization: Basic ${harborBasicAuthToken}" "https://${harborRegistry}/api/projects" -H "accept: application/json" -H "Content-Type: application/json" -d '{ "project_name": "'"$projName"'", "metadata": { "public": "true" }}'

  # upload chart
  curl -s -k -H "Authorization: Basic ${harborBasicAuthToken}" -X POST "https://${harborRegistry}/api/chartrepo/${projName}/charts" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "chart=@dist/${chart};type=application/gzip"

done < dist/charts.list
```

### pvc对应的存储卷

集群中其它应用数据一般是保存在pvc对应的存储卷中的。

#### 备份

首先根据pvc找到对应的pv：

```bash
kubectl -n test get pvc demo-pvc -o jsonpath='{.spec.volumeName}'
```

找到pv的挂载目录：

```bash
mount | grep pvc-xxxxxxxxxxxxxxxxxxx
```

使用rsync命令备份数据：

```bash
rsync -avp --delete /var/lib/kubelet/pods/xxxxxx/volumes/xxxxxxx/   /tmp/pvc-data-bak/test/demo-pvc/
```

#### 还原

首先根据pvc找到对应的pv：

```bash
kubectl -n test get pvc demo-pvc -o jsonpath='{.spec.volumeName}'
```

找到pv的挂载目录：

```bash
mount | grep pvc-xxxxxxxxxxxxxxxxxxx
```

使用rsync命令备份数据：

```bash
rsync -avp --delete /tmp/pvc-data-bak/test/demo-pvc/ /var/lib/kubelet/pods/xxxxxx/volumes/xxxxxxx/   
```

### 备份数据管理

所有备份出的数据可以存放在一个目录下，并使用[restic](https://github.com/restic/restic)工具保存到多个后端存储系统上，如：

```bash
# 初始化备份仓库
restic --repo sftp:user@host:/srv/restic-repo init

# 将目录备份到备份仓库
restic --repo sftp:user@host:/srv/restic-repo backup /data/k8s-all-data
```



DONE.



## 参考

1. [https://www.flftuu.com/2019/03/12/%E5%A4%A7%E8%A7%84%E6%A8%A1%E9%9B%86%E7%BE%A4%E9%85%8D%E7%BD%AE%E4%BC%98%E5%8C%96/](https://www.flftuu.com/2019/03/12/大规模集群配置优化/)
2. https://testerhome.com/topics/7509
3. https://etcd.io/docs/v3.4.0/tuning/
4. https://docs.docker.com/engine/reference/commandline/dockerd/
5. https://kubernetes.io/docs/setup/best-practices/cluster-large/
6. https://www.jianshu.com/p/904a3f2b6579
7. https://github.com/restic/restic
8. https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#sftp