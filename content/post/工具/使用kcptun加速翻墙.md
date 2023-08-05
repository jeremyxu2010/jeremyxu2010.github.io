---
title: 使用kcptun加速翻墙
author: Jeremy Xu
tags:
  - fuckgfw
  - linux
categories:
  - 工具
date: 2016-10-25 00:59:00+08:00
---
之前有一篇博文里写到了[如何使用shadowsocks翻墙](/2016/04/10/fuckgfw_osx/)，可最近感觉这种翻墙方案网络延迟大了很多。最让人难以接受的是每次在Google页面里输入搜索关键字敲回车后，要过很久很久，搜索结果才能显示出来。

无意间在网上看到kcptun+shadowsocks加速翻墙的方案，一试果然效果很好，网络延迟小了很多，甚至可以看youtube上的1080P视频了。

## kcptun实现原理

Kcptun 是一个非常简单和快速的，基于 KCP 协议的 UDP 隧道，它可以将 TCP 流转换为 KCP+UDP 流。而 KCP 是一个快速可靠协议，能以比 TCP 浪费10%-20%的带宽的代价，换取平均延迟降低 30%-40%，且最大延迟降低三倍的传输效果。

Kcptun 是 KCP 协议的一个简单应用，可以用于任意 TCP 网络程序的传输承载，以提高网络流畅度，降低掉线情况。由于 Kcptun 使用 Go 语言编写，内存占用低（经测试，在64M内存服务器上稳定运行），而且适用于所有平台，甚至 Arm 平台。

Kcptun 工作示意图：
![kcptun](http://blog-images-1252238296.cosgz.myqcloud.com/kcptun.png)

## 在vps上启动kcptun服务端

```bash
./server_linux_amd64 -l :20086 -t 127.0.0.1:443  -mtu 1400 -sndwnd 2048 -rcvwnd 2048 -mode fast2 --crypt "aes" &
```

## 在本机启动kcptun客户端

```bash
./client_darwin_amd64 -l :443 -r $serverip:20086 -mtu 1400 -mode fast2 -dscp 46 --crypt aes
```

## 修改shadowsocks-libev的配置文件

将/usr/local/etc/shadowsocks-libev.json文件中server修改为127.0.0.1，然后重启shadowsocks-libev服务。
