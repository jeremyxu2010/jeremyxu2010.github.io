---
title: 试用WebVirtMgr
tags:
  - linux
  - kvm
categories:
  - 云计算
date: 2016-08-07 00:36:00+08:00
---
最近一段时间一直在试用各种KVM虚拟化管理平台，主要试用了ovirt、openstack、WebVirtMgr。最后发现针对我目前的工作场景(不超过10台物理机)，WebVirtMgr是最适合的场景，这里将WebVirtMgr的安装部署简单写下来备忘。

## 安装

### 安装WebVirtMgr

我是在CentOS6上进行安装，官方给出的文档还是比较详细的，照做就可以了。

```bash
# 启用epel的源，我一般是使用阿里云的centos源及epel源，见`http://mirrors.aliyun.com/help/centos`， `http://mirrors.aliyun.com/help/epel`
# 这里跟官方文档有一点点不一样，不要安装epel源里的supervisor，那个太老了，另外多安装了novnc包，这个后面通过网页连接虚拟机的控制台要用到
yum -y install git python-pip libvirt-python libxml2-python python-websockify nginx novnc
# 安装较新版本的supervisor
wget -O python-supervisor-3.0-3.noarch.rpm https://packagecloud.io/haf/oss/packages/el/6/python-supervisor-3.0-3.noarch.rpm/download
yum localinstall -y python-supervisor-3.0-3.noarch.rpm

mkdir -p /srv/www/
cd /srv/www/
git clone git://github.com/retspen/webvirtmgr.git
cd webvirtmgr
pip install -r requirements.txt
# 这里会提示让创建一个登录用户，按照提示创建就可以了，以后可以执行`./manage.py createsuperuser`再创建其它登录用户
./manage.py syncdb
./manage.py collectstatic

#将该目录的拥有者修改为nginx用户
chown -R nginx:nginx /var/www/webvirtmgr

#增加webvirtmgr的nginx配置
echo "
server {
    listen 80 default_server;

    server_name _;
    #access_log /var/log/nginx/webvirtmgr_access_log;

    location /static/ {
        root /srv/www/webvirtmgr/webvirtmgr; # or /srv instead of /var
        expires max;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-for $proxy_add_x_forwarded_for;
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 600;
        proxy_read_timeout 600;
        proxy_send_timeout 600;
        client_max_body_size 1024M; # Set higher depending on your needs
    }
}
"> /etc/nginx/conf.d/webvirtmgr.conf

# 注释掉nginx原有的默认主机配置
sed -i -e "s/^/#/g" /etc/nginx/conf.d/default.conf

# 增加webvirtmgr的supervisor配置
echo "
command=/usr/bin/python /srv/www/webvirtmgr/manage.py run_gunicorn -c /srv/www/webvirtmgr/conf/gunicorn.conf.py
directory=/srv/www/webvirtmgr
autostart=true
autorestart=true
logfile=/var/log/supervisor/webvirtmgr.log
log_stderr=true
user=nginx

[program:webvirtmgr-console]
command=/usr/bin/python /srv/www/webvirtmgr/console/webvirtmgr-console
directory=/srv/www/webvirtmgr
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/webvirtmgr-console.log
redirect_stderr=true
user=nginx
" > /etc/supervisor/conf.d/webvirtmgr.conf

# 设置nginx、supervisord开机自启动并启动它们
chkconfig nginx on
service nginx start
chkconfig supervisord on
service supervisord start
```

### 安装被管物理机

被管物理机的操作系统同样是CentOS6，安装过程也是很简单。

```bash
curl http://retspen.github.io/libvirt-bootstrap.sh | sh
service messagebus restart
service libvirtd restart
```

### 将被管物理机接入WebVirtMgr

我这里是使用ssh接入的方式

先在被管物理机上创建普通可执行libvirt相关命令的用户

```bash
adduser webvirtmgr
passwd webvirtmgr
usermod -G qemu,kvm -a webvirtmgr
echo "[Remote libvirt SSH access]
Identity=unix-user:webvirtmgr
Action=org.libvirt.unix.manage
ResultAny=yes
ResultInactive=yes
ResultActive=yes
" > /etc/polkit-1/localauthority/50-local.d/50-libvirt-remote-access.pkla
```

再在安装WebVirtMgr所在主机上做好密钥登录

```bash
#切换至nginx用户
su - nginx -s /bin/bash
#生成nginx用户默认的ssh登录密钥文件
ssh-keygen
touch ~/.ssh/config && echo -e "StrictHostKeyChecking=no\nUserKnownHostsFile=/dev/null" >> ~/.ssh/config
chmod 0600 ~/.ssh/config
#设置nginx使用webvirtmgr无密码登录至被管物理机
ssh-copy-id -P .ssh/id_rsa webvirtmgr@${libvirt_host_ip}
#从nginx用户跳出
exit
```

## 使用

访问`http://${webvirtmgr_host_ip}/servers/`，首先会要求登录，用之前安装时创建的帐户登入系统。然后添加一个连接，将被管物理机接入WebVirtMgr，如下图所示，这里IP输入被管物理机IP，用户名输入webvirtmgr就可以了。

![create_libvirt_host.png](http://blog-images-1252238296.cosgz.myqcloud.com/create_libvirt_host.png)

然后进入这台物理机的界面，在左侧可以看到几大功能，分别是：虚机实例管理、存储池管理、网络池管理、网络接口管理、密钥管理、物理机概览，如图。

![webvirtmgr_host_detail.png](http://blog-images-1252238296.cosgz.myqcloud.com/webvirtmgr_host_detail.png)

### 网络接口管理

原来我都是手工创建桥接网络接口配置的，虽然不难，但确实比较麻烦。在这里发现可以在界面上完成，如图。

![webvirtmgr_create_bridge_interface.png](http://blog-images-1252238296.cosgz.myqcloud.com/webvirtmgr_create_bridge_interface.png)

后来调查了下，发现原来libvirt自带这个功能的，命令如下

```bash
iface-bridge <interface> <bridge> [--no-stp] [--delay <number>] [--no-start]
```

### 网络池管理

这里可以管理libvirt里的网络池，其实就是libvirt网络管理功能的UI展现，这里贴一下libvirt网络管理相关的命令

>     net-autostart                  自动开始网络
    net-create                     从一个 XML 文件创建一个网络
    net-define                     从一个 XML 文件定义(但不开始)一个网络
    net-destroy                    destroy (stop) a network
    net-dumpxml                    XML 中的网络信息
    net-edit                       为网络编辑 XML 配置
    net-info                       network information
    net-list                       列出网络
    net-name                       把一个网络UUID 转换为网络名
    net-start                      开始一个(以前定义的)不活跃的网络
    net-undefine                   取消定义一个非活跃的网络
    net-update                     update parts of an existing network's configuration
    net-uuid                       把一个网络名转换为网络UUID

### 存储池管理

这里可以进行存储池的管理，支持的卷类型有五种：目录类型卷、LVM类型卷、Ceph类型卷、NETFS类型卷、iso镜像卷。

iso镜像卷一般是用来存放ISO镜像的。

在单机上，存放虚拟机镜像文件一般是使用目录类型卷，有的虚拟机为了有比较好的硬盘IO性能会使用LVM类型卷。

如果想将虚拟机镜像放到分布式存储或共享存储中，就会用到Ceph类型卷、NETFS类型卷。

### 虚机实例管理

这里可以根据向导创建虚拟机，也可以根据预先创建好的模板镜像创建虚拟机、也可以根据预先创建好的配置模板创建虚拟机，还可以根据xml文件内容创建虚拟机。

对虚拟机的管理，功能基本是覆盖virt-manager的功能，常用的功能都可以界面操作了，有些没有的功能也可以手工修改虚拟机xml配置文件实现，如图。

![webvirtmgr_vm_mgt.png](http://blog-images-1252238296.cosgz.myqcloud.com/webvirtmgr_vm_mgt.png)

## 待改进的地方

* 创建虚拟机后，默认的主机名、IP地址还得在虚机控制台设置，太麻烦，下一步尝试使用gusetfs的命令行工具，编写一个脚本对虚拟机的镜像文件进行预处理以解决这个问题。
* KVM集群中虚拟机要做到实时迁移，必须配合集中存储，而且需要在每个物理机上将其配置为存储池。目前我所了解的廉价、可扩展性好的集中存储方案有Ceph与Glusterfs，下一步需要对比这两种方案，以找出最合适的方案
* KVM集群中的虚拟机如果全部采用静态设置IP地址，管理查看虚机的IP地址将很麻烦；如果全部采用动态获取IP地址，则需要在网络内部安装dhcp服务器，然后可在dhcp服务器上管理查看虚机的IP地址。很显然后一种方案更合理一点，但这个还需要验证
* webvirtmgr并不是像openstack一样的虚拟化一站式解决方案，它的工作原理其中就是通过一个web页面，将多台物理机接入进来，然后通过libvirt分别管理每个物理机上的计算资源。要创建虚拟机时，才是管理员自行找到一个合适的物理，然后在上面创建虚拟机。那么在KVM集群环境，存储已经通过Ceph或Glusterfs方案解决了，当要创建某个配置的虚拟机时，最好能有一个调度器，依据CPU、内存的需求，帮助管理员从众多物理机中选取一个合适的物理机。简单处理，也许可以写一个脚本，根据CPU、内存的需求自动得出一个物理机选取推荐列表，以供管理员参考
* webvirtmgr所部署的主机需考虑高可用方案。简单处理可以将其做成docker镜像，一旦发现该服务故障了，可以快速地在其它地方启动起来

## 总结

webvirtmgr不是完美的，但目前在我来看，它是最适合我这种小型私有云建设的，后面我将在研发按这个方案推行下去。

## 参考

`https://github.com/retspen/webvirtmgr/wiki/Install-WebVirtMgr`
`https://github.com/retspen/webvirtmgr/wiki/Setup-Host-Server`
`https://github.com/retspen/webvirtmgr/wiki/Setup-SSH-Authorization`



