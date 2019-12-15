---
title: 60秒完成Linux系统的性能分析(译)
author: Jeremy Xu
tags:
  - linux
  - tracing
  - profiling
  - observability
categories:
  - linux
date: 2019-12-14 20:40:00+08:00
---



偶然间看到一篇英文文档，觉得还挺有用的，尝试翻译一下以加深记忆。

翻译自[https://medium.com/netflix-techblog/linux-performance-analysis-in-60-000-milliseconds-accc10403c55](https://medium.com/netflix-techblog/linux-performance-analysis-in-60-000-milliseconds-accc10403c55)。



## 问题背景

当登录到一台有性能问题的Linux服务器，第一分钟要检查什么？

在Netflix，我们拥有庞大的EC2 Linux虚拟机云，我们有众多性能分析工具来监视和诊断这些Linux服务器的性能。这些工具包括Atlas（负责整个虚拟机云的监控）和Vector（负责按需对虚拟机实例进行性能分析）。这些工具可以帮助我们解决大多数问题，但有时我们需要登录到虚拟机实例，并运行一些标准的Linux性能工具。



## 前60秒：摘要

在本文中，Netflix性能工程团队将使用您应该使用的标准Linux工具在命令行中向您展示一个性能诊断过程的前60秒。在60秒内，您可以通过运行以下十个命令来了解有关系统资源使用和运行进程的信息。最应该关注的是一些很容易理解的错误、饱和度指标和资源利用率等指标。饱和度是衡量资源负载超出其处理能力的指标，它可以通过观察请求队列的长度或等待时间反映出来。

```
uptime
dmesg | tail
vmstat 1
mpstat -P ALL 1
pidstat 1
iostat -xz 1
free -m
sar -n DEV 1
sar -n TCP,ETCP 1
top
```

其中的一些命令需要安装sysstat软件包。这些命令暴露出的指标将帮助您完成一些USE方法：一种查找性能瓶颈的方法。它们涉及检查所有资源（CPU、内存、磁盘等）的利用率，饱和度和错误指标。在诊断过程中还应该注意检查和排除某些资源的问题。因为通过排除某些资源的问题，可以缩小诊断的范围，并指民后续的诊断。

以下各节通过生产系统中的示例总结了这些命令。有关这些工具更多的信息，请参见其手册页。

## 1. uptime

```bash
$ uptime 
23:51:26 up 21:31, 1 user, load average: 30.02, 26.43, 19.02
```

这是快速查看平均负载的方法，该平均负载指标了要运行的任务（进程）的数量。在Linux系统上，这些数字包括要在CPU上运行的进程以及在不中断IO（通常是磁盘IO）中阻塞的进程。这里给出了资源负载高层次的概览，但是没有其它工具就很难正确理解，值得快速看一眼。

这三个数字是指数衰减移动平均值，分别代表了1分钟、5分钟、15分钟的平均值。这三个数字使我们对负载如何随时间变化有了一定的了解。例如，如果您去诊断一个有问题的服务器，发现1分钟的值比15分钟的值低很多，那么您可能已经登录得太晚了，错过了问题。

在上面的例子中，平均负载有所增加，因为1分钟的值30相对15分钟的值19来说大了一些。数字变大意味着很多种可能：有可能是CPU的需求变多了，使用3和4中提到的vmstat或mpstat命令将可以进一步确认问题。

## 2. dmesg | tail

```bash
$ dmesg | tail
[1880957.563150] perl invoked oom-killer: gfp_mask=0x280da, order=0, oom_score_adj=0
[...]
[1880957.563400] Out of memory: Kill process 18694 (perl) score 246 or sacrifice child
[1880957.563408] Killed process 18694 (perl) total-vm:1972392kB, anon-rss:1953348kB, file-rss:0kB
[2320864.954447] TCP: Possible SYN flooding on port 7001. Dropping request.  Check SNMP counters.
```

该命令展示最近 10条系统消息。在这些系统消息中查找有可能引起性能问题的报错。上面的例子包括`oom-killer`和TCP丢弃了一个请求。

不能忘记这个步骤，`dmesg`通常对诊断问题很有价值。

## 3. vmstat  1

```bash
$ vmstat 1
procs ---------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
34  0    0 200889792  73708 591828    0    0     0     5    6   10 96  1  3  0  0
32  0    0 200889920  73708 591860    0    0     0   592 13284 4282 98  1  1  0  0
32  0    0 200890112  73708 591860    0    0     0     0 9501 2154 99  1  0  0  0
32  0    0 200889568  73712 591856    0    0     0    48 11900 2459 99  0  0  0  0
32  0    0 200890208  73712 591860    0    0     0     0 15898 4840 98  1  1  0  0
^C
```

vmstat是虚拟内存统计(Virtual Memory Stat)的缩写，vmstat(8)是一个通常可用的工具(最初是在之前的BSD时代创建的)，它每行打印一行服务器关键统计的概览。

vmstat使用参数1运行，意味着每1秒打印打印一次概览。命令输出的第一行展示的是从启动开始的平均值，而不是最近一秒的平均值。因此跳过第一行，除非您想学习并记住哪一列是哪一列。

要检查的列：

* `r`：在CPU上运行并等待回合的进程数。由于它不包含IO，因此它比指示CPU饱和的平均负载提供了更多的信息。一个大于CPU核数的`r`值就是饱和的。
* `free`：空闲的内存（单位的KB）。如果计数很大，说明服务器有足够的内存，`free -m`命令将对空闲内存的状态有更好的说明。
* `si`、`so`：交换置入和交换置出。如果这两个值是非空，说明物理内存用完了，现在在使用交换内存了。
* `us`、`sy`、`id`、`wa`、`st`：这些是CPU时间的分类，其是所有CPU的平均值。它们是用户时间、系统时间(内核)、空闲时间、等待IO和被偷窃时间（被其它宾客系统进行使用，或宾客系统隔离的驱动程序域Xen）

通过将用户时间和系统时间这两个分类相加，即可判断CPU是否繁忙。一定的等待IO时间说明磁盘有可能是性能瓶颈。你可以认为等待IO时间是另一种形式的空闲时间，它提供了它是如何空闲的线索。

IO处理需要占用CPU系统时间。一个较高的CPU系统时间（超过20%）可能会很有趣，有必要进一步研究：也许内核在很低效地处理IO。

在上面的示例中，CPU时间基本全在用户时间，这说明应用程序本身在大量占用CPU时间。CPU的平均利用率也远远超过90%。这不一定是问题，可以使用`r`列来检查饱和度。



## 4. mpstat -P ALL  1

```bash
$ mpstat -P ALL 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015  _x86_64_ (32 CPU)

07:38:49 PM  CPU   %usr  %nice   %sys %iowait   %irq  %soft  %steal  %guest  %gnice  %idle
07:38:50 PM  all  98.47   0.00   0.75    0.00   0.00   0.00    0.00    0.00    0.00   0.78
07:38:50 PM    0  96.04   0.00   2.97    0.00   0.00   0.00    0.00    0.00    0.00   0.99
07:38:50 PM    1  97.00   0.00   1.00    0.00   0.00   0.00    0.00    0.00    0.00   2.00
07:38:50 PM    2  98.00   0.00   1.00    0.00   0.00   0.00    0.00    0.00    0.00   1.00
07:38:50 PM    3  96.97   0.00   0.00    0.00   0.00   0.00    0.00    0.00    0.00   3.03
[...]
```

此命令显示每个CPU的CPU时间明细，可用于检查不平衡的情况。单个热CPU说明是单线程应用程序在大量占用CPU时间。

## 5. pidstat 1

```bash
$ pidstat 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015    _x86_64_    (32 CPU)

07:41:02 PM   UID       PID    %usr %system  %guest    %CPU   CPU  Command
07:41:03 PM     0         9    0.00    0.94    0.00    0.94     1  rcuos/0
07:41:03 PM     0      4214    5.66    5.66    0.00   11.32    15  mesos-slave
07:41:03 PM     0      4354    0.94    0.94    0.00    1.89     8  java
07:41:03 PM     0      6521 1596.23    1.89    0.00 1598.11    27  java
07:41:03 PM     0      6564 1571.70    7.55    0.00 1579.25    28  java
07:41:03 PM 60004     60154    0.94    4.72    0.00    5.66     9  pidstat

07:41:03 PM   UID       PID    %usr %system  %guest    %CPU   CPU  Command
07:41:04 PM     0      4214    6.00    2.00    0.00    8.00    15  mesos-slave
07:41:04 PM     0      6521 1590.00    1.00    0.00 1591.00    27  java
07:41:04 PM     0      6564 1573.00   10.00    0.00 1583.00    28  java
07:41:04 PM   108      6718    1.00    0.00    0.00    1.00     0  snmp-pass
07:41:04 PM 60004     60154    1.00    4.00    0.00    5.00     9  pidstat
^C
```

`pidstat`有点像top的每个进程摘要，但是会滚动打印，而不是清屏再打印。这对于观察一段时间内的模式以及将所看到的内容（复制&粘贴）记录到调查记录中很有用。

上面的示例显示两个Java进程要为消耗大量CPU负责。`%CPU`这一列是所有CPU核的总和，`1591%`说明Java进程差不多消耗了16个核的CPU。

## 6. iostat -xz 1

```bash
$ iostat -xz 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015  _x86_64_ (32 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
          73.96    0.00    3.73    0.03    0.06   22.21

Device:   rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
xvda        0.00     0.23    0.21    0.18     4.52     2.08    34.37     0.00    9.98   13.80    5.42   2.44   0.09
xvdb        0.01     0.00    1.02    8.94   127.97   598.53   145.79     0.00    0.43    1.78    0.28   0.25   0.25
xvdc        0.01     0.00    1.02    8.86   127.79   595.94   146.50     0.00    0.45    1.82    0.30   0.27   0.26
dm-0        0.00     0.00    0.69    2.32    10.47    31.69    28.01     0.01    3.23    0.71    3.98   0.13   0.04
dm-1        0.00     0.00    0.00    0.94     0.01     3.78     8.00     0.33  345.84    0.04  346.81   0.01   0.00
dm-2        0.00     0.00    0.09    0.07     1.35     0.36    22.50     0.00    2.55    0.23    5.62   1.78   0.03
[...]
^C
```

这是了解块设备（磁盘），应用的工作负载和产生的性能影响的绝佳工具。重点关注下面的指标：

* `r/s`、`w/s`、 `rkB/s`、 `wkB/s`：这些是设备每秒交付的读取、写入、读取千字节和写入千字节。使用这些来表征块设备的工作负载。性能问题可能是由于向块设备施加了过多的工作负载。
* `await`：IO的平均时间，以毫秒为单位。这是应用程序所感受到的时间，它包括IO排队时间和IO服务时间。大于预期的平均时间可能表示块设备饱和或设备出现问题了。
* `avgqu-sz`：发给设备的平均请求数。值大于1可以表明已达到饱和状态（尽管设备通常可以并行处理请求，尤其是在多个后端磁盘所组成的前端虚拟设备的情况下）。
* `%util`：设备利用率。这是一个表征繁忙度的百分比，它表示设备每秒工作的时间。尽管它的值取决于设备，但值大于60%通常会导致性能不佳（也会通过await的值观察到）。接近100%的值通常表示饱和。

如果存储设备是有许多后端磁盘组成的前端逻辑磁盘设备，则100%的利用率可能仅意味着100%的时间正在处理某些IO，但是后端磁盘可能远远没有饱和，并且可能还可以处理更多的工作。

请记住，性能不佳的磁盘IO不一定是应用问题，通常可以使用许多技术以执行异步IO，以便使应用程序不会被阻塞住而产生直接产生IO延迟（例如，预读和缓冲写入技术）

## 7. free -m

```bash
$ free -m
             total       used       free     shared    buffers     cached
Mem:        245998      24545     221453         83         59        541
-/+ buffers/cache:      23944     222053
Swap:            0          0          0
```

右边两列：

* `buffers`：缓冲区高速缓存，用于块设备I / O
* `cached`：页面缓存，由文件系统使用

我们只需要检查下它们的大小是否接近零。如果接近零的话，这可能导致较高的磁盘IO（可以使用iostat进行确认）和较差的性能。上面的示例看起来不错，每列都有较大的数据。

`-/+ buffers/cache`为已用和空闲内存提供较少让人产生混乱的值。Linux将可用内存用于高速缓存，但是如果应用程序需要，它们可以快速被回收。因此应以某种方式将缓存的内存包括在`free`列中，这也就是这一行的所做的。甚至还有一个[网站](http://www.linuxatemyram.com/)专门讨论了这种混乱。

如果在Linux上使用ZFS，就像我们对某些服务所做的那么，因为ZFS具有自己的文件系统缓存，它们并不会反映在`free -m`的列中，因此这种场景下这种混乱还将存在。所以会看到似乎系统的可用内存不足，而实际上可根据需要从ZFS缓存中申请到内存。

## 8. sar -n DEV 1

```bash
$ sar -n DEV 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015     _x86_64_    (32 CPU)

12:16:48 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
12:16:49 AM      eth0  18763.00   5032.00  20686.42    478.30      0.00      0.00      0.00      0.00
12:16:49 AM        lo     14.00     14.00      1.36      1.36      0.00      0.00      0.00      0.00
12:16:49 AM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00

12:16:49 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
12:16:50 AM      eth0  19763.00   5101.00  21999.10    482.56      0.00      0.00      0.00      0.00
12:16:50 AM        lo     20.00     20.00      3.25      3.25      0.00      0.00      0.00      0.00
12:16:50 AM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
^C
```

此工具可以检查网络接口的吞吐量：`rxkB/s`和`txkB/s`，作为工作负载的度量，还可以检查是否已达到网络接口的限制。在上面的示例中，eth0接收速率达到22MB/s，即176Mbit/s（远低于1Gbit/s的网络接口限制，假设是千兆网卡）。

此版本还具有`%ifutil`用来指示设备利用率（全双工双向），这也是我们使用的Brendan的[nicstat工具](https://github.com/scotte/nicstat)测量出来的。就像nicstat一样，这个指标很难计算正确，而且在本例中好像不起作用（数据是0.00）。

## 9. sar -n TCP,ETCP 1

```bash
$ sar -n TCP,ETCP 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015    _x86_64_    (32 CPU)

12:17:19 AM  active/s passive/s    iseg/s    oseg/s
12:17:20 AM      1.00      0.00  10233.00  18846.00

12:17:19 AM  atmptf/s  estres/s retrans/s isegerr/s   orsts/s
12:17:20 AM      0.00      0.00      0.00      0.00      0.00

12:17:20 AM  active/s passive/s    iseg/s    oseg/s
12:17:21 AM      1.00      0.00   8359.00   6039.00

12:17:20 AM  atmptf/s  estres/s retrans/s isegerr/s   orsts/s
12:17:21 AM      0.00      0.00      0.00      0.00      0.00
^C
```

这是一些关键的TCP指标的摘要，包括：

* `active / s`：每秒本地启动的TCP连接数（例如，通过connect（））。
* `passive/s`：每秒远程启动的TCP连接数（例如，通过accept（））。
* `retrans / s`：每秒TCP重传的次数。

主动和被动计数通常作为服务器TCP负载的粗略度量：新接受的连接数（被动）和新出站的连接数（主动）。将主动视为出站，将被动视为入站可能对理解这两个指标有些帮助，但这并不是严格意义上的（例如，考虑从localhost到localhost的连接）。

重新传输是网络或服务器问题的迹象；它可能是不可靠的网络（例如，公共Internet），也可能是由于服务器过载并丢弃了数据包。上面的示例仅显示每秒一个新的TCP连接。

## 10. top

```bash
$ top
top - 00:15:40 up 21:56,  1 user,  load average: 31.09, 29.87, 29.92
Tasks: 871 total,   1 running, 868 sleeping,   0 stopped,   2 zombie
%Cpu(s): 96.8 us,  0.4 sy,  0.0 ni,  2.7 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem:  25190241+total, 24921688 used, 22698073+free,    60448 buffers
KiB Swap:        0 total,        0 used,        0 free.   554208 cached Mem

   PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 20248 root      20   0  0.227t 0.012t  18748 S  3090  5.2  29812:58 java
  4213 root      20   0 2722544  64640  44232 S  23.5  0.0 233:35.37 mesos-slave
 66128 titancl+  20   0   24344   2332   1172 R   1.0  0.0   0:00.07 top
  5235 root      20   0 38.227g 547004  49996 S   0.7  0.2   2:02.74 java
  4299 root      20   0 20.015g 2.682g  16836 S   0.3  1.1  33:14.42 java
     1 root      20   0   33620   2920   1496 S   0.0  0.0   0:03.82 init
     2 root      20   0       0      0      0 S   0.0  0.0   0:00.02 kthreadd
     3 root      20   0       0      0      0 S   0.0  0.0   0:05.35 ksoftirqd/0
     5 root       0 -20       0      0      0 S   0.0  0.0   0:00.00 kworker/0:0H
     6 root      20   0       0      0      0 S   0.0  0.0   0:06.94 kworker/u256:0
     8 root      20   0       0      0      0 S   0.0  0.0   2:38.05 rcu_sched
```

`top`命令包括我们之前检查的许多指标。运行它可以很方便地查看是否有任何东西与以前的命令有很大不同，这表明负载是可变的。

`top`命令不太好的地方是，随着时间的推移很难看到指标变化的模式，这在提供滚动输出的`vmstat`和`pidstat`之类的工具中可能更清楚一点。如果您没有足够快地暂停输出（Ctrl-S暂停，Ctrl-Q继续），在屏幕输出被`top`命令清除后，间歇性问题的证据也可能被丢失了。

## 后续分析

您可以使用更多的命令和方法来进行更深入的研究。可以看一下Brendan的[Linux Performance Tools tutorial](https://medium.com/@Netflix_Techblog/netflix-at-velocity-2015-linux-performance-tools-51964ddb81cf)，该教程讲述了40多个命令，涉及可观察性、基准测试、性能调优、静态性能调优、性能分析和跟踪。

解决一定网络规模后系统的可靠性和性能问题是我们特别热衷的事情之一。

## 总结

除了这篇文章外，还看到一篇使用eBPF技术完成对内核操作的tracing的文档，后面准备对这块也详细学习一下。

## 参考

1. https://medium.com/netflix-techblog/netflix-at-velocity-2015-linux-performance-tools-51964ddb81cf
2. https://medium.com/netflix-techblog/linux-performance-analysis-in-60-000-milliseconds-accc10403c55