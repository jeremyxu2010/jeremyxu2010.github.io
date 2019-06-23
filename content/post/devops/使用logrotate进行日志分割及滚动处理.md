---
title: 使用logrotate进行日志分割及滚动处理
author: Jeremy Xu
tags:
  - linux
  - logrotate
categories:
  - devops
date: 2015-04-30 01:40:00+08:00
---

linux server上服务一般持续长久运行，以致服务的日志文件随着时间越来越大，如果日志处理得不好甚至有可能占满磁盘。幸好找到了`logrotate`这个程序来处理。

下面是安装配置过程

```bash
zypper in -y logrotate

#虽然logrotate是通过cron来运行的
cat /etc/cron.daily/logrotate
#!/bin/sh
/usr/sbin/logrotate /etc/logrotate.conf
EXITVALUE=$?
if [ $EXITVALUE != 0 ]; then
    /usr/bin/logger -t logrotate "ALERT exited abnormally with [$EXITVALUE]"
fi
exit 0

#而logrotate.conf里会引用/etc/logrotate.d目录
cat /etc/logrotate.conf
...
include /etc/logrotate.d
...

#在/etc/logrotate.d目录中新建一个处理nginx日志文件的配置文件
vim /etc/logrotate.d/nginx
/opt/nginx/logs/*.log {
    daily
    dateext
    compress
    rotate 3
    sharedscripts
    postrotate
        if [ -f /opt/nginx/logs/nginx.pid ]; then
           kill -USR1 `cat /opt/nginx/logs/nginx.pid`
        fi
    endscript
}
```

还可以直接手动执行

```
logrotate -d -f /etc/logrotate.d/nginx
```
