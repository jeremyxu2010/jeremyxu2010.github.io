---
title: 避免容器中运行的Java应用被杀掉
tags:
  - java
  - docker
categories:
  - 容器编排
date: 2019-10-06 13:19:00+08:00
---

今天测试环境遇到一个问题，一个Java的容器由于OOM频繁被Killed掉。这个问题还经常出现的，这里记录下解决过程。

## 为啥会频繁OOM？

首先排除Java程序的问题，因为基本上Java程序刚运行起来没一会儿，容器就由于OOM被Killed掉了，料想程序还不会写得这么烂。

经诊断，频繁OOM的容器是设置了memory quota的，因此这里做一个实验：

```bash
$ docker run -m 100MB openjdk:8u121-alpine java -XshowSettings:vm -version
VM settings:
    Max. Heap Size (Estimated): 239.75M
    Ergonomics Machine Class: client
    Using VM: OpenJDK 64-Bit Server VM

openjdk version "1.8.0_121"
OpenJDK Runtime Environment (IcedTea 3.3.0) (Alpine 8.121.13-r0)
OpenJDK 64-Bit Server VM (build 25.121-b13, mixed mode)
```

这里发现给容器设置了100MB的memory quota，但JVM运行时实际最大的`Heap Size`却大于这个值。为啥会这样呢？

查阅[资料](https://medium.com/adorsys/jvm-memory-settings-in-a-container-environment-64b0840e1d9e)，发现JVM默认分配本机内存的大约`25%`作为`Max Heap Size`。

> ## Java Heap Sizing Basics
>
> Per default the JVM automatically configures heap size according to the spec of the machine it is running on. On my brand new MacBook Pro 2018 this yields the following heap size:
>

  ```bash
  $ java -XX:+PrintFlagsFinal -version | grep -Ei "maxheapsize|maxram"
      uintx DefaultMaxRAMFraction   = 4             {product}
      uintx MaxHeapSize             := 8589934592   {product}
      uint64_t MaxRAM               = 137438953472  {pd product}
      uintx MaxRAMFraction          = 4             {product}
  ```

> As you can see, the JVM defaults to 8.0 GB max heap `(8589934592 / 1024^3)` and 0.5 GB initial heap on my machine. The formula behind this is straight forward. Using the JVM configuration parameter names, we end up with: `MaxHeapSize = MaxRAM * 1 / MaxRAMFraction` where MaxRAM is the available RAM [(1](https://medium.com/adorsys/jvm-memory-settings-in-a-container-environment-64b0840e1d9e#fn1-20439)) and MaxRAMFraction is 4 [(2](https://medium.com/adorsys/jvm-memory-settings-in-a-container-environment-64b0840e1d9e#fn2-20439)) by default. That means the **JVM allocates up to 25% of your RAM per JVM** running on your machine.

而在容器中运行的Java进程默认取到的系统内存是宿主机的内存信息：

```bash
$ docker run -m 100MB openjdk:8u121-alpine cat /proc/meminfo
MemTotal:        1008492 kB
MemFree:          144328 kB
MemAvailable:     548688 kB
Buffers:           69864 kB
Cached:           421352 kB
...
```

如果宿主机上的内存容量较大，通过上述计算公式自然得到一个较大的`Max Heap Size`，这样Java程序在运行时如果频繁申请内存，而由于并没有接近`Max Heap Size`，因此不会去GC，这样运行下去，最终申请的内存超过了容器的memory quota，因而被cgroup杀掉容器进程了。

## 解决方案

容器如此火热的今天，这个问题自然有解决方案了。

### 方案1

如果java可以升级到Java 10，则使用`-XX:+UseContainerSupport`打开容器支持就可以了，这时容器中运行的JVM进程取到的系统内存即是施加的memory quota了：

```bash
$ docker run -m 400MB openjdk:10 java -XX:+UseContainerSupport -XX:InitialRAMPercentage=40.0 -XX:MaxRAMPercentage=90.0 -XX:MinRAMPercentage=50.0 -XshowSettings:vm -version
VM settings:
    Max. Heap Size (Estimated): 348.00M
    Using VM: OpenJDK 64-Bit Server VM

openjdk version "10.0.2" 2018-07-17
OpenJDK Runtime Environment (build 10.0.2+13-Debian-2)
OpenJDK 64-Bit Server VM (build 10.0.2+13-Debian-2, mixed mode)
```

同时还可以通过`-XX:InitialRAMPercentage`、`-XX:MaxRAMPercentage`、`-XX:MinRAMPercentage`这些参数控制JVM使用的内存比率。因为很多Java程序在运行时会调用外部进程、申请Native Memory等，所以即使是在容器中运行Java程序，也得预留一些内存给系统的。所以`-XX:MaxRAMPercentage`不能配置得太大。

进行一步查阅[资料](https://www.oracle.com/technetwork/java/javase/8u191-relnotes-5032181.html)，发现`-XX:+UseContainerSupport`这个标志选项在Java 8u191已经被backport到Java 8了。因此如果使用的jdk是Java 8u191之后的版本，上述那些JVM参数依然有效：

```bash
$ docker run -m 400MB openjdk:8u191-alpine java -XX:+UseContainerSupport -XX:InitialRAMPercentage=40.0 -XX:MaxRAMPercentage=90.0 -XX:MinRAMPercentage=50.0 -XshowSettings:vm -version
VM settings:
    Max. Heap Size (Estimated): 348.00M
    Ergonomics Machine Class: client
    Using VM: OpenJDK 64-Bit Server VM

openjdk version "1.8.0_191"
OpenJDK Runtime Environment (IcedTea 3.10.0) (Alpine 8.191.12-r0)
OpenJDK 64-Bit Server VM (build 25.191-b12, mixed mode)
```

### 方案2

如果使用的jdk是Java 8u131之后的版本，可使用`-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap`选项，如下：

```bash
$ docker run -m 400MB openjdk:8u131-alpine java -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=2 -XshowSettings:vm -version
VM settings:
    Max. Heap Size (Estimated): 193.38M
    Ergonomics Machine Class: client
    Using VM: OpenJDK 64-Bit Server VM

openjdk version "1.8.0_131"
OpenJDK Runtime Environment (IcedTea 3.4.0) (Alpine 8.131.11-r2)
OpenJDK 64-Bit Server VM (build 25.131-b11, mixed mode)
```

`-XX:MaxRAMFraction`就是刚才那个公式里的`MaxRAMFraction`，默认值是4，代表默认分配系统内存大约25%给`Heap Size`，可以减小这个参数，从而使JVM尽量地使用memory quota。同时这个值不能太小，设置为1还是有些危险，见[这里](https://stackoverflow.com/questions/49854237/is-xxmaxramfraction-1-safe-for-production-in-a-containered-environment)的说明，一般设置为2。

### 方案3

容器运行时会将容器的quota等cgroup目录挂载进容器，因此可以通过entrypoint脚本自行读取这些信息，并给JVM设置合理的`-Xms`、`-Xmx`等参数，参考[这里](https://github.com/jeremyxu2010/rocketmq-docker/blob/master/image-build/scripts/runbroker-customize.sh#L56)的脚本。

当然最好是能升级到Java 8u191或Java 10。

## 参考

1. https://medium.com/adorsys/jvm-memory-settings-in-a-container-environment-64b0840e1d9e
2. https://blog.csanchez.org/2017/05/31/running-a-jvm-in-a-container-without-getting-killed/
3. https://stackoverflow.com/questions/49854237/is-xxmaxramfraction-1-safe-for-production-in-a-containered-environment
4. https://stackoverflow.com/questions/42187085/check-mem-limit-within-a-docker-container
5. https://github.com/jeremyxu2010/rocketmq-docker