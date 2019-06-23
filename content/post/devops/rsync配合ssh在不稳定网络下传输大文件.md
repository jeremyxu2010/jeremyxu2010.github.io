---
title: rsync配合ssh在不稳定网络下传输大文件
author: Jeremy Xu
tags:
  - rsync
  - scp
categories:
  - devops
date: 2015-06-30 01:40:00+08:00
---

今天的工作需要将一个很大的文件传输出远程主机上，远程主机只开启了sshd服务，仅允许ssh登录，不允许安装其它软件，到远程主机的网络很不稳定。

首先尝试使用scp，由于网络很不稳定，传输20~30M，网络就断了，然后又从头重新传。后来想到rsync貌似可以使用ssh通道，于是写了下面的脚本。

```bash
#!/bin/bash
# rsync_copy.sh

export RSYNC_RSH="ssh -i /home/test/.ssh/id_rsa -c arcfour -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o ServerAliveInterval=15 -o ServerAliveCountMax=2"
rsyncSrcFile=$1
rsyncDestFile=$2
rsyncSuccess=-1
while [ $rsyncSuccess -ne 0 ]
do
 rsync -avq --partial --inplace $rsyncSrcFile $rsyncDestFile
 rsyncSuccess=$?
done
```

这个脚本的两个参数格式均可以是 /home/test/a.iso 或 root@192.168.3.4:/root/a.iso

```bash
#执行前需要作ssh密钥无密码登录
ssh-copy-id -i /home/test/.ssh/id_rsa root@192.168.3.4
#执行下面的命令，然后就可以登出去happy了，明天早上再登入远程主机检查文件，一切ok了
./rsync_copy.sh /home/test/a.iso root@192.168.3.4:/root/a.iso > /dev/null 2>&1 &
```
