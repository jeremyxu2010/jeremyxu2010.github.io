---
title: TL-WR941D路由器刷OpenWRT备忘
tags:
  - OpenWRT
  - linux
categories:
  - 工具
date: 2016-04-16 20:37:00+08:00
---
家里的路由器TL-WR941D还是多年前买的，之前一直用着还挺稳定的，只不过有时觉得网速有点慢。最近却频频遇到问题，一会儿ping国外某个IP丢包率奇高，一会儿DNS经常解析域名失败。之前就听说现在OpenWRT已经很稳定了，今天周末在家没什么事儿，决定刷OpenWRT算了。

## 下载对应的刷机包

刷之前先进TP-Link的Web管理控制台看了下版本，发现是TL-WR941D v6版，因此下载对应的[刷机包](https://downloads.openwrt.org/chaos_calmer/15.05.1/ar71xx/generic/openwrt-15.05.1-ar71xx-generic-tl-wr941nd-v6-squashfs-factory.bin), 登入TP-Link的Web管理控制台，在更新系统那里选择该刷机包，直接刷入就可以了。

## 配置OpenWRT

使用有线将电脑与路由器接好，然后执行命令

```bash
telnet 192.168.1.1

#登入OpenWRT后，因为我家是使用的adsl，所以执行下面的命令设置好wan口
uci set network.wan.proto=pppoe
uci set network.wan.username='${your adsl login name}'
uci set network.wan.proto='${your adsl password}'
uci commit network
ifup wan

#现在安装OpenWRT Web图形管理界面
opkg update
opkg install luci luci-i18n-chinese
/etc/init.d/uhttpd start
/etc/init.d/uhttpd enable
```

然后使用浏览器访问`http://192.168.1.1`，这时可以直接登录进去，不需要输入密码，首先在“System-System-Language”里将语言修改为“chinese”, 保存，刷新页面，这里页面就变成中文了。

然后在“系统-管理权”这里给路由器设个密码，以后命令行登入`ssh root@192.168.1.1`或Web控制台`http://192.168.1.1`登录就需要输入密码了。

在我这里OpenWRT默认没有打开WiFi，同时登入Web控制台，在“网络-无线”这里对无线网络进行设置后，启动该无线网络就可以了。
