---
title: Java VisualVM使用备忘
date: 2017-10-01 11:20:00+08:00
author: 徐新杰
tags:
  - java
  - visualvm
  - jstatd
categories:
  - java开发
---

# Java VisualVM使用备忘

一直觉得JDK带的新版诊断工具[VisualVM](https://visualvm.github.io)功能都没有原来的[jconsole](http://docs.oracle.com/javase/7/docs/technotes/guides/management/jconsole.html)强大，今天偶然翻到了[VisualVM](https://visualvm.github.io)的github主页，看了下文档，发现简单配置下，功能还是很强大的。

## 安装插件

默认带的功能看起来还不如jconsole，但其实装上插件就很强大了。不过我本机默认配置的插件更新地址还是java.net的，根本没法安装插件，在[这里](https://visualvm.github.io/pluginscenters.html)找到了对应版本的更新地址，比如我本机是JDK1.8.0_102自带的VisualVM，因此选择[https://visualvm.github.io/archive/uc/8u40/updates.xml.gz](https://visualvm.github.io/archive/uc/8u40/updates.html)，将其填到下图的位置：

![visualvm插件更新地址设置](/images/20171001/visualvm_setting.png)

然后就可以安装插件了，[这里](https://visualvm.github.io/plugins.html)有主要插件的描述，可以根据需要自行安装，我本机安装了以下这些插件：

![本机安装的插件](/images/20171001/visualvm_plugins.png)

安装后，VisualVM的功能看起来就很强大了，比jconsole强不少了，还美观。

![visualvm最终效果](/images/20171001/visualvm_display.png)

## 连接远程JVM

VisualVM默认是可以连接本机的JVM的，如果要连远程服务器上的JVM，则要在上面启动jstatd，启动方法如下：

```bash
# 创建jstatd运行时的安全策略文件，注意要填写正确的tools.jar路径
echo "grant codebase "file:/Library/Java/Home/lib/tools.jar" {
    permission java.security.AllPermission;
};" > jstatd.all.policy
# 启动jstatd
jstatd -J-Djava.security.policy=jstatd.all.policy
```

然后在VisualVM里填入远程服务器的IP地址，即可连接上该服务器上的JVM进行管理了。
