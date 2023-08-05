---
title: docker日志丢失问题分析
tags:
  - docker
categories:
  - 容器编排
date: 2019-01-12 23:00:00+08:00
---

今天在工作遇到一个docker日志丢失的问题，最终一步步查找到原因了，这里记录一下过程。

## 问题

工作中把自己写的应用部署到kubernetes中后，用`kubectl -n some-ns logs some-pod -c one-container`命令查看不了该pod中container的日志，而用该命令去查看其它pod的日志，是可以正常显示的。

## 跟踪原因

首先怀疑是应用本身的程序问题，将应用在本机运行了一下，是可以正常输出日志到标准输出的。

接下来怀疑是kubernetes本身的问题，于是在kubernetes的某个节点上直接用docker命令运行起容器：

```bash
docker run --name some-name -d some-image
docker logs some-name # 这里还是没有输出日志
```

看来跟kubernetes无关，直接用`docker run`跑容器都没有输出日志啊。

不过一想应该docker本身应该不会存在这么大的问题，再做一个实验，同样的镜像，在我本机的docker环境中运行试一下：

```bash
docker run --name some-name -d some-image
docker logs some-name # 这里输出了日志
```

看来是服务器上的docker环境有些毛病。

然后看看docker的日志配置：

```bash
cat /etc/sysconfig/docker
...
OPTIONS='--selinux-enabled --log-driver=journald --signature-verification=false --graph=/data/docker'
...
```

docker的配置里是将日志发送到journald的，于是看下docker服务本身的日志：

```bash
journalctl _SYSTEMD_UNIT=docker.service
```

观察日志，日志发送应该是没有什么问题的。

接下来看看journald服务的日志：

```bash
journalctl _SYSTEMD_UNIT=systemd-journald.service
...
Jan 10 19:18:50 tshift-master systemd-journal[547]: Suppressed 1833 messages from /system.slice/docker.service
Jan 10 19:19:20 tshift-master systemd-journal[547]: Suppressed 1849 messages from /system.slice/docker.service
Jan 10 19:19:50 tshift-master systemd-journal[547]: Suppressed 1857 messages from /system.slice/docker.service
Jan 10 19:20:20 tshift-master systemd-journal[547]: Suppressed 2010 messages from /system.slice/docker.service
Jan 10 19:20:50 tshift-master systemd-journal[547]: Suppressed 1820 messages from /system.slice/docker.service
...
```

这里可以看到有大量的`Suppressed xxx messages from /system.slice/docker.service`的日志，从字面意思来理解，有很多日志被抑制了。

为啥会出现这种问题呢？参阅`journald.conf`的官方文档，可以看到下面这段话：

>     man journald.conf
>     ...
>     	RateLimitInterval=, RateLimitBurst=
>            Configures the rate limiting that is applied to all messages generated on the system. If, in the time interval defined by RateLimitInterval=, more messages than specified in RateLimitBurst= are logged by a service, all
>            further messages within the interval are dropped until the interval is over. A message about the number of dropped messages is generated. This rate limiting is applied per-service, so that two services which log do not
>            interfere with each other's limits. Defaults to 1000 messages in 30s. The time specification for RateLimitInterval= may be specified in the following units: "s", "min", "h", "ms", "us". To turn off any kind of rate
>            limiting, set either value to 0.
>     ...

也就是说`docker`这个服务输出日志超出了每30秒1000条的速率限制，因此超出部分的日志被journald丢弃了。

那么docker服务真的输出日志速率这么快吗？我这里用命令计算一下：

```bash
journalctl _SYSTEMD_UNIT=docker.service --since "2019-01-11 23:00:00" --until "2019-01-11 23:05:00" | wc -l
10011 # 10011/(5*60) * 30 = 1000
```

这样看来，docker服务输出日志的速度果然超出限制了。

## 解决办法

既然是docker服务输出日志的速率超限，自然有两种解法：降低docker日志的输出速率、增大journald的速率限制。

### 降低docker日志的输出速率

使用以下命令可以看到docker服务输出的日志：

```bash
journalctl _SYSTEMD_UNIT=docker.service --since "2019-01-11 23:00:00" --until "2019-01-11 23:05:00"
```

从命令的输出来看，基本都是一些容器的标准输出，而刚好出问题的服务器上运行了大量容器，而且有些容器确实在大量输出日志。当然改法自然是调整这些容器的程序，一般来说就是设置更合理的日志级别。

### 增大journald的速率限制

如果服务器上运行了大量容器，每个容器输出一些日志，这些日志加起来也很容易超过journald的速率限制。因此还可以直接增大journald的速率限制。

```bash
# 直接修改/etc/systemd/journald.conf，增大RateLimitBurst配置项的取值，修改完毕后重启journald服务
vim /etc/systemd/journald.conf
systemctl restart systemd-journald
```

## 其它

### journald配置文件的优化

在修改`journald.conf`里，发现其某些配置项并不合理，可以参考[这里](https://docs.lvrui.io/2017/02/19/%E6%9B%B4%E6%94%B9docker%E7%9A%84%E6%97%A5%E5%BF%97%E5%BC%95%E6%93%8E%E4%B8%BA-journald/)优化一下。

### 增大journald的速率限制的其它办法

查看`journald.conf`配置文件的文档时，还发现对于较新版本的systemd来说，可以只修改某个服务对应的日志速率限制参数，这样不用修改`journald.conf`影响全局，可惜这个特性只有较新版本的systemd才有。

> ```
> RateLimitIntervalSec=, RateLimitBurst=
> ```
>
> Configures the rate limiting that is applied to all messages generated on the system. If, in the time interval defined by `RateLimitIntervalSec=`, more messages than specified in `RateLimitBurst=` are logged by a service, all further messages within the interval are dropped until the interval is over. A message about the number of dropped messages is generated. This rate limiting is applied per-service, so that two services which log do not interfere with each other's limits. Defaults to 10000 messages in 30s. The time specification for `RateLimitIntervalSec=` may be specified in the following units: "`s`", "`min`", "`h`", "`ms`", "`us`". To turn off any kind of rate limiting, set either value to 0.
>
> If a service provides rate limits for itself through `LogRateLimitIntervalSec=` and/or `LogRateLimitBurst=` in [systemd.exec(5)](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#), those values will override the settings specified here.

## 总结

docker的日志输出逻辑还是比较清晰的，这里就不具体介绍了，参考[官方文档](https://docs.docker.com/config/containers/logging/configure/)就可以了，出了问题冷静一步步分析还是很靠谱的。

## 参考

1. https://docs.docker.com/config/containers/logging/configure/
2. https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/content/160.html
3. https://docs.lvrui.io/2017/02/19/%E6%9B%B4%E6%94%B9docker%E7%9A%84%E6%97%A5%E5%BF%97%E5%BC%95%E6%93%8E%E4%B8%BA-journald/
4. https://www.freedesktop.org/software/systemd/man/journald.conf.html
5. https://www.freedesktop.org/software/systemd/man/systemd.exec.html
6. https://bani.com.br/2015/06/systemd-journal-what-does-systemd-journal-suppressed-n-messages-from-system-slice-mean/
7. https://www.sulabs.net/?p=828
8. https://www.howtoing.com/how-to-use-journalctl-to-view-and-manipulate-systemd-logs