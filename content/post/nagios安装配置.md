---
title: nagios安装配置
author: Jeremy Xu
tags:
  - nagios
  - 监控
categories:
  - devops
date: 2014-06-30 01:40:00+08:00
---

上线的服务器有时会被人攻击，导致服务不可用，今天安装配置了nagios对上线服务器进行监控，简单记录一下

```bash
#安装必要的软件包
yum install -y gcc glibc glibc-common gd gd-devel xinetd openssl-devel
#创建nagios用户及授予目录权限
useradd -s /sbin/nologin nagios
mkdir /usr/local/nagios
chown -R nagios.nagios /usr/local/nagios
#安装nagios
tar xf nagios-4.0.7.tar.gz
cd nagios-4.0.7
./configure --prefix=/usr/local/nagios
make all
make install && make install-init && make install-commandmode && make install-config
chkconfig --add nagios && chkconfig --level 35 nagios on && chkconfig --list nagios
#安装nagios-plugins
tar xf nagios-plugins-2.0.2.tar.gz
cd nagios-plugins-2.0.2
./configure --prefix=/usr/local/nagios
make && make install
#安装apache
tar xf httpd-2.2.23.tar.gz
cd httpd-2.2.23
./configure --prefix=/usr/local/apache2
make && make install
#安装php
tar xf php-5.5.13.tar.gz
cd php-5.5.13
./configure --prefix=/usr/local/php --with-apxs2=/usr/local/apache2/bin/apxs
make && make install
```

接下来配置apache

```bash
#生成nagios密码文件
/usr/local/apache2/bin/htpasswd -c /usr/local/nagios/etc/htpasswd admin
vim /usr/local/apache2/conf/httpd.conf
...
User nagios
Group nagios
...
<IfModule dir_module>
    DirectoryIndex index.html index.php
</IfModule>
...
AddType application/x-httpd-php .php
...
#setting for nagios
ScriptAlias /nagios/cgi-bin "/usr/local/nagios/sbin"
<Directory "/usr/local/nagios/sbin">
     AuthType Basic
     Options ExecCGI
     AllowOverride None
     Order allow,deny
     Allow from all
     AuthName "Nagios Access"
     AuthUserFile /usr/local/nagios/etc/htpasswd             //用于此目录访问身份验证的文件
     Require valid-user
</Directory> Alias /nagios "/usr/local/nagios/share"
<Directory "/usr/local/nagios/share">
     AuthType Basic
     Options None
     AllowOverride None
     Order allow,deny
     Allow from all
     AuthName "nagios Access"
     AuthUserFile /usr/local/nagios/etc/htpasswd
     Require valid-user
</Directory>
```

启动apache

```bash
vim /etc/init.d/httpd
#!/bin/sh
#
# Startup script for the Apache Web Server
#
# chkconfig: 345 85 15
# description: Apache is a World Wide Web server.  It is used to serve \
#           HTML files and CGI.
# processname: httpd
# pidfile: /usr/local/apache2/logs/httpd.pid
# config: /usr/local/apache2/conf/httpd.conf

# Source function library.
. /etc/rc.d/init.d/functions

# See how we were called.
case "$1" in
start)
echo -n "Starting httpd: "
daemon /usr/local/apache2/bin/httpd -DSSL
echo
touch /var/lock/subsys/httpd
;;
stop)
echo -n "Shutting down http: "
killproc httpd
echo
rm -f /var/lock/subsys/httpd
rm -f /usr/local/apache2/logs/httpd.pid
;;
status)
status httpd
;;
restart)
$0 stop
$0 start
;;
reload)
echo -n "Reloading httpd: "
killproc httpd -HUP
echo
;;
*)
echo "Usage: $0 {start|stop|restart|reload|status}"
exit 1
esac

exit 0

chmod +x /etc/init.d/httpd
chkconfig httpd on
/etc/init.d/httpd start
```

接下来配置nagios

```bash
#确保admin用户登录后有权限查看信息
vim /usr/local/nagios/etc/cgi.cfg
...
default_user_name=admin
authorized_for_system_information=nagiosadmin,admin
authorized_for_configuration_information=nagiosadmin,admin
authorized_for_system_commands=admin
authorized_for_all_services=nagiosadmin,admin
authorized_for_all_hosts=nagiosadmin,admin
authorized_for_all_service_commands=nagiosadmin,admin
authorized_for_all_host_commands=nagiosadmin,admin
...

#修改nagios主配置文件，将主机的定义都放在/usr/local/nagios/etc/hosts目录中
mkdir /usr/local/nagios/etc/hosts
vim /usr/local/nagios/etc/nagios.cfg
...
cfg_dir=/usr/local/nagios/etc/hosts
...

#添加一个自定义命令
vim /usr/local/nagios/etc/objects/command.cfg

...
# 'check_custom_http' command definition
define command{
        command_name    check_custom_http
        command_line    $USER1$/check_http -4 -N -H $ARG1$ -u $ARG2$
        }

# 'check_dns' command definition
define command{
        command_name    check_dns
        command_line    $USER1$/check_dns -v -H $ARG1$ -a $ARG2$ -w $ARG3$ -c $ARG4$
        }
...

#定义主机组
vim /usr/local/nagios/etc/hosts/group.cfg

define hostgroup{
        hostgroup_name    groupname1
        alias               groupname1
        members             server1 #server1必须在/etc/hosts里有对应的映射
}

#定义主机server1
vim /usr/local/nagios/etc/hosts/server1.cfg

define host{
        use                     linux-server
        host_name               server1
        alias                   server1
        address                 xx.xx.xx.xx
        notification_period     24x7
}
define service{
        use                             local-service         ; Name of service template to use
        host_name                       server1
        service_description             PING
        check_command                   check_ping!100.0,20%!500.0,60% ; 延时100ms丢包率大于20%时，则发出警告通知; 延时500ms丢包率大于60%时，则发出严重错误通知
}
;需要做好本机使用的DNS设置，在/etc/resolv.conf文件中定义
define service{
        use                             local-service         ; Name of service template to use
        host_name                       server1
        service_description             DNS
        check_command                   check_dns!xxx.test.com!xx.xx.xx.xx!4!10 ;连续解析域名发生4次错误，则发出警告通知；连续解析域名发生10次错误，则发出严重错误通知；
}
define service{
        use                             local-service         ; Name of service template to use
        host_name                       server1
        service_description             HTTP
        check_command                   check_custom_http!xxx.abc.com!/somepath/path1  ;注意这里的参数要以!分隔
}
define service{
        use                             local-service         ; Name of service template to use
        host_name                       server1
        service_description             SSH
        check_command                   check_ssh
}

#配置监控出现问题时要通知的联系人
vim /usr/local/nagios/etc/objects/contacts.cfg

define contact{
        contact_name                    user1                ; Short name of user
        use                             generic-contact         ; Inherit default values from generic-contact template (defined above)
        alias                           user1                ; Full name of user

        email                           user1@abc.com  ; <<***** CHANGE THIS TO YOUR EMAIL ADDRESS ******
        }

define contact{
        contact_name                    user2                ; Short name of user
        use                             generic-contact         ; Inherit default values from generic-contact template (defined above)
        alias                           user2                ; Full name of user

        email                           user2@abc.com  ; <<***** CHANGE THIS TO YOUR EMAIL ADDRESS ******
        }

 define contactgroup{
        contactgroup_name       admins
        alias                   Nagios Administrators
        members                 user1,user2
        }
```

重启nagios

```bash
/etc/init.d/nagios restart
```

刚才发现nagios监控到服务器异常也没有发邮件通知，查了一下，还需要配置mail命令可发送邮件

```bash
yum install mail
vim /etc/mail.rc
...
set from=abc-noreply@abc.com
set smtp=smtp.abc.com
set smtp-auth-user=abc-noreply@abc.com
set smtp-auth-password=somepwd
set smtp-auth=login
...
```
