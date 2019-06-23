---
title: kuberntes中的redis集群性能调优
tags:
  - redis
  - kubernetes
categories:
  - 容器编排
date: 2019-06-23 01:35:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/201910623
---

上周在kubernetes里发布了一个redis PaaS服务，不过其它同学简单测了一下，虽说功能上没啥问题，但性能相比物理上运行的Redis集群差太远，而且随着redis的分片数增加，性能并不能很好地线性增长，增长到一定程度就停止了，这个是需求方不能接受的，于是本周接了活，对部署在kubernetes中的redis服务进行性能优化。

## 基准测试

按照之前此类工作的工作方法，首先进行基准测试，得到目前的性能状况指标，也便于后面总结本次优化的成果。

我这里使用多个`redis-benchmark`进程对一个3分片的redis进行压测，最后得到的性能指标如下：

| 序号 | 场景                                                         | 总QPS |
| ---- | ------------------------------------------------------------ | ----- |
| 1    | 3个物理机，每个物理机部署一个Redis分片                       | 45w   |
| 2    | 同样在3个物理机上部署kuberntes集群，在其中部署3个pod，每个pod均部署一个redis分片 | 10w   |

## 逐步优化

### 优化内核参数

首先参考[performance-tips-for-redis-cache-server](https://www.techandme.se/performance-tips-for-redis-cache-server/)优化几个十分影响redis集群性能的内核参数，由于redis是部署在kubernetes的pod中，因此优化方法跟文章中提到的办法有一点点不一样，如下：

```bash
# sysctl.conf中配置fs.file-max、net.core.somaxconn两个属性
$ cat << EOF >> /etc/sysctl.conf
fs.file-max=655350
net.core.somaxconn=20480
EOF
sysctl -p

# limits.conf中配置文件句柄数及进程数的硬限制和软限制
$ cat << 'EOF' >> /etc/security/limits.conf
*	hard	nofile	655350
*	soft	nofile	655350
*	hard	nproc	655350
*	soft	nproc	655350
EOF

# 关闭内存transparent_hugepage特性
$ cat << 'EOF' >> /etc/rc.local
echo never > /sys/kernel/mm/transparent_hugepage/enabled
EOF
$ echo never > /sys/kernel/mm/transparent_hugepage/enabled

# kubelet中允许修改pod的net.core.somaxconn内核参数
$ cat /etc/systemd/system/kubelet.service
...
ExecStart=/usr/local/bin/kubelet \
   ...
   --allowed-unsafe-sysctls=net.core.somaxconn \
   ...
   
# 修改pod的net.core.somaxconn内核参数
$ kubectl -n demo get statefulsets  redis-redis-cluster -o yaml
...
podSpec:
	securityContext:
    sysctls:
    - name: net.core.somaxconn
    value: "20480"
...
```

### CPU绑核

压测时发现虽然服务的cpu核数较多，但任务数也有些多，cpu的争抢有些严重，因此这里进行CPU绑核操作。

首先对redis的pod进行cpu绑核，这里参考kubernetes的[官方文档-控制节点上的CPU管理策略](https://kubernetes.io/zh/docs/tasks/administer-cluster/cpu-management-policies/)。

```bash
# 启用kubelet的静态绑核开关
$ cat /etc/systemd/system/kubelet.service
...
ExecStart=/usr/local/bin/kubelet \
  ...
  --feature-gates=CPUManager=true \
  --cpu-manager-policy=static \
  --system-reserved=cpu=2,memory=500Mi,ephemeral-storage=1Gi \
  ...

# pod的resources.limits.cpu及resources.requests.cpu设置为相同的整数
$ kubectl -n demo get statefulsets  redis-redis-cluster -o yaml
...
podSpec:
	resources:
    limits:
      cpu: "1"
      ...
    requests:
      cpu: "1"
      ...
...
```

为了减少网卡软中断CPU上下文切换的开销，这里对之进行绑定CPU，这里参考网上的一篇[网卡软中断优化的文档](http://www.simlinux.com/2017/02/28/net-softirq.html)。

```bash
# 绑定网卡软中断至CPU0-CPU7
$ cat scripts/bind_nic_softirq.sh
#!/bin/bash
set -e -u
systemctl stop irqbalance.service
nic_name=enp5s0f0
irq_nos=$(grep "${nic_name}-TxRx" /proc/interrupts | awk '{print $1, $NF}' | awk -F ':' '{print $1}')
dec_value=1
for irq_no in ${irq_nos[*]}; do
  cpu_smp_affinity=$(printf '%x' ${dec_value})
  echo ${cpu_smp_affinity}  > /proc/irq/${irq_no}/smp_affinity
  dec_value=$((2*${dec_value}))
done

bash scripts/bind_nic_softirq.sh
```

### iptables切换为ipvs

在压测过程中发现直接压测podIP性能会好不少，但压测serviceIP性能打一个折扣。而由kubernetes Service的实现原理可知，serviceIP是由iptables或ipvs实现的。社区里也谈到ipvs确实比iptables有更好的性能，从kubernetes 1.12开始就默认使用ipvs了。而我这里用的是kubernetes 1.11版本，因此手动配置一下以启动ipvs。

```bash
# 所有node节点安装ipset
$ yum install -y ipset
# 配置启动时加载ipvs相关内核模块
$ cat /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
ipvs_modules=(ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4)
for kernel_module in ${ipvs_modules[*]}; do
    /sbin/modinfo -F filename ${kernel_module} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        /sbin/modprobe ${kernel_module}
    fi
done
$ chmod +x /etc/sysconfig/modules/ipvs.modules

# kube-proxy启用ipvs模式
$ cat /etc/systemd/system/kube-proxy.service
...
ExecStart=/usr/local/bin/kube-proxy \
  ...
  --proxy-mode=ipvs \
  --ipvs-min-sync-period=5s \
  --ipvs-sync-period=5s \
  --ipvs-scheduler=rr \
  --masquerade-all \
  ...
...
```

### 由overlay网络切换为underlay网络

继续压测，发现已可以达到26wQPS了，但和在物理机上部署的redis集群性能还有差距。咨询了专门搞kubernetes容器网络的同学，他建议使用underlay网络。

这里提一下两个概念：

Underlay网络：Underlay网络由底层网络驱动将接口暴露给虚机或容器，比较常用的方案有bridge, macvlan, ipvlan, sriov等。

Overlay网络：Overlay网络无需改造网络架构，只需三层可达即可，将二层报文封装在IP报文中。这样能利用成熟的IP路由协议进行数据分发，采用隔离标识能够突破VLAN的数量限制，必要时把广播流量转化为组网流量避免广播数据泛滥。比较常见的方案有vxlan, gre等。

可以看出在Underlay网络下，容器里看到的是底层实际的网络接口，直接读写这种网络接口自然比Overlay网络下那种虚拟出来的网络性能好得多。

由于不方便升级内核，因此这里就采用最简单的macvlan CNI网络方案了，切换方法就不详述了，参考[这篇文章](https://blog.csdn.net/cloudvtech/article/details/79830887)就可以了。

不过切换为macvlan之间遇到了几个问题。

1. 容器内无法ping通本主机主接口ip。

   这个会导致kubernetes无法对pod进行正常的健康检测。这里在网上找到一个[解决方案](https://www.yangcs.net/posts/macvlan-in-action/)：

   ```bash
   $ ip link add link ens160 mac0 type macvlan mode bridge
   # 下面的命令一定要放在一起执行，否则中间会失去连接
   $ ip addr del 192.168.179.9/16 dev ens160 && \
     ip addr add 192.168.179.9/16 dev mac0 && \
     ip link set dev mac0 up && \
     ip route flush dev ens160 && \
     ip route flush dev mac0 && \
     ip route add 192.168.0.0/16 dev mac0 metric 0 && \
     ip route add default via 192.168.1.1 dev mac0
   ```

   其实就是建立一个macvlan bridge，将主机主接口桥接到这上面，将主机主接口的ip挪到该bridge上的一个mac0网络接口上。

2. 使用macvlan ip的pod无法访问kubernetes里的serviceIP。

   kubernetes里的serviceIP实现原理参见[clusterip的实现机制](https://zhuanlan.zhihu.com/p/67384482)，说白了serviceIP是由iptables或ipvs机制模拟出的虚拟IP，它的流量分发是由iptables或ipvs进行必要的NAT操作实现的。而macvlan之类的UnderLay网络方案属于外部网络，并且拥有独立的网络空间namespace，所以并不会经过node的网络空间的内核协议栈，进而造成并不会经过iptables/ipvs的配置，因此使用了macvlan的pod，自然无法正常访问servicrIP。[kubernetes的clusterip机制调研及macvlan网络下的clusterip坑解决方案](https://zhuanlan.zhihu.com/p/67384482)这篇文章也谈到了两个解决方案：

   * 部分Node标记master，采用cluster network，例如flannel/calico/weave，貌似最近weave比较火，可以借机熟悉一下。然后部署管理Pod的时候，指定部署到master上去。

   * 基于[multus-cni](https://link.zhihu.com/?target=https%3A//github.com/intel/multus-cni)插件做双网卡，然后配置默认路由走macvlan的网卡，内部网络走cluster network那块网卡。

   我这里采用的方案一，给node打标签，区别出两种不同的node，采用不同的cni网络方案，一个是overlay网络，一个是underlay网络。利用节点亲和性规则，将一般应用的pod都调度到overlay网络的node上，将对网络性能有要求的pod调度到underlay网络的node上。同时调度到underlay网络的pod中要避免使用Service。
   
   节点亲和性规则如下编写：
   
   ```bash
   # 给某些node节点打label，标记为该node节点上运行管理类pod，该node节点上使用flannel的CNI网络方案，其它node节点上使用macvlan的CNI网络方案
    $ kubectl label node 10.10.20.151 managed_node=true

    # 业务类的pod使用nodeAffinity，使之被调度到没有打了label的node节点
    $ kubectl -n demo get statefulsets redis-redis-cluster -o yaml
    ...
    podSpec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: managed_node
                operator: NotIn
                values:
                - "true"
   ```
   
   当然另一种方案后面也可以尝试一下，可以参考[这里的文章](https://juejin.im/post/5c926709f265da60e86e0ca6#heading-3)。

## 性能回归测试

还是基准测试里的场景，重新进行压测，得到以下数据：

| 序号 | 场景                                                         | 总QPS |
| ---- | ------------------------------------------------------------ | ----- |
| 1    | 3个物理机，每个物理机部署一个Redis分片                       | 45w   |
| 2    | 3个物理机上部署kuberntes集群，在其中部署3个pod，每个pod均部署一个redis分片 | 44w   |

对比在物理机上直接部署的redis集群，两者的性能基本相近了，达到调优的目标。

## 总结

相比功能开发，性能调优是一个很有趣的工作，其需要对运行的平台、软件架构、硬软件基础有比较深入的了解才行，在调优的过程中也可以将之前了解的一些概念性理论在实际场景进行验证，从而理解得更深刻。因此调优的工作还是相当难得和具有挑战的。

## 参考

1. https://www.techandme.se/performance-tips-for-redis-cache-server/

2. https://kubernetes.io/zh/docs/tasks/administer-cluster/sysctl-cluster/

3. https://kubernetes.io/zh/docs/tasks/administer-cluster/cpu-management-policies/

4. [http://www.simlinux.com/2017/02/28/net-softirq.html](http://www.simlinux.com/2017/02/28/net-softirq.html)

5. https://blog.csdn.net/fanren224/article/details/86548398

6. [http://lotleaf.com/linux/docker-network.html](http://lotleaf.com/linux/docker-network.html)

7. https://blog.csdn.net/cloudvtech/article/details/79830887

8. https://www.yangcs.net/posts/macvlan-in-action/

9. https://zhuanlan.zhihu.com/p/67384482
  
10. https://juejin.im/post/5c926709f265da60e86e0ca6#heading-3
