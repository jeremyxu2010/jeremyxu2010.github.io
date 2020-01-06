---
title: 分析APP访问后台服务的网络故障
tags:
  - golang
  - http
  - android
  - hey
categories:
  - golang开发
date: 2020-01-06 11:30:00+08:00
---

工作中一个小问题，Android手机上的APP访问后台服务频繁出现网络超时。以下为分析此问题的简要步骤，记录一下以备忘。

## 了解网络链路

首先大致了解下该场景的网络链路，比较简单。

```
APP  ->    HTTP Proxy Server   ->  APP backend Service
```

## 估算网络请求压力

在测试场景里，有70台手机上的APP向对后端服务发出HTTP请求。假设每个APP每秒发出一个请求，这样算得后端服务需要扛住的请求压力至少为70qps。

## 对后端服务进行压测

首先检测下后端服务是否可以扛住此压力。使用以下命令：

```bash
$ hey -z 60s -c 70 -q 1 -m 'POST' -d 'xxxxx' \
  -T "application/x-www-form-urlencoded; charset=UTF-8" \
  -H 'accept: */*' \
  -H 'accept-encoding: gzip, deflate' \
  -H 'connection: keep-alive' \
  -H 'content-length: 111' \
  -H 'user-agent: python-requests/2.10.0' \
	"http://xxx/yyyy"
	
Summary:
  Total:	10.7173 secs
  Slowest:	0.7229 secs
  Fastest:	0.3527 secs
  Average:	0.4343 secs
  Requests/sec:	65.3150
  
......

Latency distribution:
  10% in 0.3806 secs
  25% in 0.3908 secs
  50% in 0.4115 secs
  75% in 0.4431 secs
  90% in 0.4941 secs
  95% in 0.6704 secs
  99% in 0.7166 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0034 secs, 0.3527 secs, 0.7229 secs
  DNS-lookup:	0.0017 secs, 0.0000 secs, 0.0188 secs
  req write:	0.0001 secs, 0.0000 secs, 0.0012 secs
  resp wait:	0.4305 secs, 0.3525 secs, 0.7228 secs
  resp read:	0.0002 secs, 0.0000 secs, 0.0038 secs

Status code distribution:
  [200]	4200 responses
```

关注下结果中各关键指标，效果还是挺好的，因此认为后端服务没有问题。

**这里为啥要用hey，而不是ab？因为hey是用golang语言编写的，很方便编译出android手机上可运行的二进制版本。**

## 在手机上压测

首先要编译出一个可在Android手机上运行的hey二进制文件：

```bash
$ brew cask install android-ndk
$ export ANDROID_NDK_HOME=/usr/local/share/android-ndk
$ git clone https://github.com/rakyll/hey.git
$ cd hey
$ go mod download
$ env GOOS=android GOARCH=arm64 CC=/usr/local/share/android-ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang CXX=/usr/local/share/android-ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang++ CGO_ENABLED=1 go build -o hey .
```

将编译出的二进制文件上传至Android手机：

```bash 
$ adb connect xxx.xxx.xxx.xxx:yyy
$ adb -s xxx.xxx.xxx.xxx:yyy push hey /data/local/tmp/hey
```

最后在Android手机上执行压测命令：

```bash
$ adb -s xxx.xxx.xxx.xxx:yyy shell
$ cd /data/local/tmp
$ chmod +x ./hey
$ ./hey -z 60s -c 70 -q 1 -x http://zzz.zzz.zzz.zzz:aaa -m 'POST' -d 'xxxxx' \
  -T "application/x-www-form-urlencoded; charset=UTF-8" \
  -H 'accept: */*' \
  -H 'accept-encoding: gzip, deflate' \
  -H 'connection: keep-alive' \
  -H 'content-length: 111' \
  -H 'user-agent: python-requests/2.10.0' \
	"http://xxx/yyyy"
```

**这里按我们的场景，压测时还指定了HTTP代理**

果然这样测得QPS差了很多。找维护代理服务器的同学咨询了下，果然是代理服务器存在性能瓶颈。

## 参考

1. https://github.com/rakyll/hey
2. https://golang.org/misc/android/README