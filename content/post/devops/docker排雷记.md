---
title: docker排雷记
tags:
  - docker
categories:
  - devops
date: 2017-02-03 20:20:00+08:00
---

上周末使用docker做了一个简化应用分发的小例子，但今天在最新版本的docker上一运行就出错，研究了好半天，终于将这些坑都填过去了，这里记录一下。

## 挂载目录用户权限问题

我是将dockerfiles相关文件放在windows系统上的，然后通过virtualbox虚拟机的共享文件夹功能将目录共享给Linux的，这样在Linux下就会看到这些文件的用户组是vboxsf, 这些文件的权限为770。

```
[jeremy@centos7-local dockerfiles]$ ls -l
总用量 1
-rwxrwx--- 1 root vboxsf 688 2月   3 11:53 docker-compose.yml
drwxrwx--- 1 root vboxsf   0 2月   2 09:51 initdb
drwxrwx--- 1 root vboxsf   0 2月   3 11:28 tools
drwxrwx--- 1 root vboxsf   0 2月   2 18:05 wars
```

这时使用`-v`将目录挂载到docker容器

```bash
docker run --name=test -v `pwd`/wars:/var/lib/jetty/webapps -p 8080:8080 -d jetty:9
```

这时目录挂载过去后权限就很不对了，如下

```
root@15ba64dfbe33:/var/lib/jetty# ls -l
total 0
drwxr-xr-x 3 jetty jetty  17 Feb  3 01:57 lib
drwxr-xr-x 2 jetty jetty   6 Jan 18 00:38 resources
drwxr-xr-x 2 jetty jetty 193 Feb  3 01:57 start.d
drwxrwx--- 1 root    984   0 Feb  2 10:05 webapps
```

可以看到webapps目录的用户组为984, 文件权限是770。而jetty是以jetty用户运行的，自然就无法读取webapps目录下的内容。

查了下，解决这个问题有四种办法：

- 在宿主机上创建与容器中需要的用户及用户组，创建的用户及用户组的ID必须与容器中的一致。在运行`docker run -v ...`命令前，将要挂载的目录权限设置正确。
- 将要挂载的目录设置为容器中存在的用户及用户组，比如设置为root用户，在宿主机与容器中都存在root用户与root用户组，而且root用户与root用户组的ID是一致的。
- 修改容器中用户及用户组的ID，使宿主机上的用户及用户组ID在容器内可被识别，有网友写了[一个脚本](https://github.com/schmidigital/permission-fix)来完成这件事。
- 运行`docker run -v ...`命令时，使用`--user`及`--group`更改容器运行进程的用户及用户组。同样要求指定的用户在容器里是存在的，一般来说也就只能使用`root`了。

这几种方法都有缺点，还是很麻烦。也在关注是否有其它更好的办法。

## depends_on失效了

在`docker-compose.yml`里使用`depends_on`指定了web服务依赖于db服务，但web服务还没等db服务就绪就启动了，最终web服务启动失败。

查了下文件，发现官方文档有这么一句话：

> Note: depends_on will not wait for db and redis to be “ready” before starting web - only until they have been started. If you need to wait for a service to be ready, see Controlling startup order for more on this problem and strategies for solving it.

最后参考[这里](https://docs.docker.com/compose/startup-order/), 使用`wait-for-it`方案解决了问题。

```
version: '2'
services:
  ssm-mysql:
    image:  'mysql'
    volumes:
      - ./initdb:/docker-entrypoint-initdb.d
    environment:
      - MYSQL_DATABASE=ssm-db
      - MYSQL_ROOT_PASSWORD=123456
  ssm-web:
    image: 'jetty:9'
    depends_on:
      - ssm-mysql
    links:
      - ssm-mysql
    volumes:
      - ./wars:/var/lib/jetty/webapps
      - ./tools:/tools
    entrypoint: ["/tools/wait-for-it.sh", "ssm-mysql:3306", "-s", "-t", "60", "--", "/docker-entrypoint.sh"]
    ports:
      - "8080:8080"
    environment:
      - MYSQL_PORT_3306_TCP_ADDR=ssm-mysql
      - MYSQL_PORT_3306_TCP_PORT=3306
      - MYSQL_ENV_MYSQL_DATABASE=ssm-db
      - MYSQL_ENV_MYSQL_ROOT_PASSWORD=123456
```

## 使用docker的-p选项不监听端口

直接使用docker的-p选项，发现docker宿主机并不监听指定的端口，在docker宿主机上可以访问该端口，但外部就无法访问该端口了。

```
[jeremy@centos7-local dockerfiles]$ docker run --name=test -p 8080:8080 -d jetty:9
dbb672d6c3bec87bd9048911798f7d3941e6681ebdd60e0bb54332b8a083ae3d
#宿主机并不监听8080端口
[jeremy@centos7-local dockerfiles]$ lsof -i :8080
# 但在docker宿主机上wget可访问8080，外部就无法访问8080了
[jeremy@centos7-local dockerfiles]$ wget http://127.0.0.1:8080
--2017-02-03 21:01:43--  http://127.0.0.1:8080/
正在连接 127.0.0.1:8080... 已连接。
# 发现原来是docker-proxy这个东东在工作
[jeremy@centos7-local dockerfiles]$ ps -ef|grep docker
...
root      3190  3050  0 20:58 ?        00:00:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8080 -container-ip 172.17.0.2 -container-port 8080
...
```

查阅[官方文档](https://docs.docker.com/engine/reference/commandline/dockerd/)后，发现`dockerd`存在`--userland-proxy`这个选项。

> --userland-proxy	true	Use userland proxy for loopback traffic

于是给`dockerd`加上`--userland-proxy=false`选项，然后问题解决了。这个选项应该是为安全性考虑的吧，默认只允许docker宿主机访问`-p`出来的端口，外部要想访问则需要配置相应的iptables规则。默认如果是这样也太不易用了。

## 参考

`https://docs.docker.com/engine/installation/linux/centos/`
`https://docs.docker.com/engine/installation/linux/linux-postinstall/`
`https://docs.docker.com/engine/admin/systemd/`
`https://github.com/schmidigital/permission-fix`
`https://docs.docker.com/compose/compose-file/`
`https://docs.docker.com/compose/startup-order/`
`https://github.com/vishnubob/wait-for-it`
`https://docs.docker.com/engine/reference/commandline/dockerd/`

