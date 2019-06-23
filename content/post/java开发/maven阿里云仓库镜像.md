---
title: maven阿里云仓库镜像
author: Jeremy Xu
tags:
  - java
  - maven
categories:
  - java开发
date: 2016-10-31 02:05:00+08:00
---
自从国内的oschina maven仓库镜像停止服务后，一直找不到稳定且速度快的maven仓库镜像，网上搜来搜去，都是说`http://mirrors.ibiblio.org/pub/mirrors/maven2/`与`http://repository.jboss.org/nexus/content/groups/public`这些，但我实际试过，很差劲，慢得很。今天偶然在网上发现了一个很稳定且速度快的maven仓库，是阿里云的，看来还是阿里爸爸有米啊。

配置方法：

在maven的settings.xml 文件里配置mirrors的子节点，添加如下mirror

```xml
<mirror>
  <id>nexus-aliyun</id>
  <mirrorOf>central</mirrorOf>
  <name>Nexus aliyun</name>
  <url>http://maven.aliyun.com/nexus/content/groups/public</url>
</mirror>
```
