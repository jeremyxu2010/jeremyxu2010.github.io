---
title: 保持Kubernetes容器平台稳定性
tags:
  - kubernetes
  - docker
categories:
  - 云计算
author: Jeremy Xu
date: 2019-05-21 20:26:00+08:00
---

这两天搭建了一套新的kubernetes环境，由于这套环境会被用于演示，所以持续观察了好几天这套环境，发现不少容器平台稳定性的问题，这里记录一下以备忘。

## 环境

我们这套环境的操作系统是`4.4.131-20181130.kylin.server aarm64 GNU/Linux`，64核128G内存。

## docker版本

最开始用的docker版本为`18.03.1-ce`，但在运行四五十个容器后，出现了`docker info`不响应的问题。因为情况紧急，没有查明原因，临时将docker版本降回`ubuntu-ports xenial`源里的`docker.io`了，版本为`17.03.2`，降级后，`docker info`终于一直有响应了。

过了一晚上，第二天再来看，发现有部分pod的健康检查失败，同时exec进pod再exit会卡住。这次查了下原因，发现是低版本docker的bug，见[bug记录](https://github.com/moby/moby/issues/35091)，官方建议将docker升级至`17.12`之后，于是将docker升级至`17.12.1-ce`，问题终于解决。

