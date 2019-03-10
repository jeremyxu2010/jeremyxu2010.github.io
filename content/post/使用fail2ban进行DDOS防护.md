---
title: 使用fail2ban进行DDOS防护
author: Jeremy Xu
tags:
  - ddos
  - fail2ban
  - nginx
categories:
  - devops
date: 2015-06-30 01:40:00+08:00
---

朋友公司一网站被DDOS攻击了，不得已在机房呆了两天作防护工作，才算临时解决了问题。想着自己公司线上也运行着一个系统，担心有一天也会被攻击，还是提前作一下DDOS防护吧。线上系统用的是nginx，于是我采用了比较成熟的fail2ban+nginx防护方案。

首先安装配置fail2ban

```bash
zypper addrepo http://download.opensuse.org/repositories/home:Peuserik/SLE_11_SP2/home:Peuserik.repo
zypper refresh
zypper install fail2ban

vim /etc/fail2ban/jail.conf

[DEFAULT]
#设置忽略内网访问及某些安全网段的访问， 网段之间以空格分隔
ignoreip = 127.0.0.1/8 11.11.11.1/24 xx.xx.xx.xxx/28

...

#设置ssh登录防护
[ssh-iptables]
enabled  = true
filter   = sshd
action   = iptables[name=SSH, port=ssh, protocol=tcp]
logpath  = /var/log/sshd.log
maxretry = 5

...

#设置nginx防护ddos攻击
[xxx-get-dos]
enabled=true
port=http,https
filter=nginx-bansniffer
action=iptables[name=xxx, port=http, protocol=tcp]
logpath=/opt/nginx/logs/xxx_access.log
maxretry=100
findtime=60
bantime=300
...

vim /etc/fail2ban/filter.d/nginx-bansniffer.conf
[Definition]
failregex = <HOST> -.*- .*HTTP/1.* .* .*$
ignoreregex =

/etc/init.d/fail2ban start
```

nginx设置

```bash
vim /opt/nginx/conf/nginx.conf
....
if ($http_user_agent ~* (Siege|http_load|fwptt)) {
        return 404;
}
#空agent
if ($http_user_agent ~ ^$) {
    return 404;
}
#请求方式限制
if ($request_method !~ ^(GET|HEAD|POST)$) {
    return 403;
}
....
/etc/init.d/nginx restart
```

这样设置后发现fail2ban对正常请求也ban了，仔细检查后发现线上应用加载的静态资源过多，而nginx对这些静态资源也会记录访问日志，这样访问日志中就存在大量同一ip来的请求。于是决定对于静态资源，不记录访问日志。

```bash
vim /opt/nginx/conf/nginx.conf
...
location ~* /xxx/.+\.(gif|jpg|png|js|css)$ {
            root   /opt/jetty/webapps/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            expires 10d;
            access_log /dev/null;
        }
location ~* \.(gif|jpg|png|js|css)$ {
            root   /opt/jetty/webapps/root/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            expires 10d;
            access_log /dev/null;
}
...
```

这里特别需要注意nginx的location匹配规则，刚开始我把上面两个location的位置弄反了，一直有问题，后来发现nginx对于相同优先级的匹配符是从上往下匹配的，一旦匹配某个规则，则进行某个规则的处理。所以匹配规则一定要按先特殊后通用的顺序摆列。

附上nginx的location匹配规则的简述。

location匹配命令

```
~      #波浪线表示执行一个正则匹配，区分大小写
~*    #表示执行一个正则匹配，不区分大小写
^~    #^~表示普通字符匹配，如果该选项匹配，只匹配该选项，不匹配别的选项，一般用来匹配目录
=      #进行普通字符精确匹配
@     #"@" 定义一个命名的 location，使用在内部定向时，例如 error_page, try_files
```


location 匹配的优先级(与location在配置文件中的顺序无关)

```
= 精确匹配会第一个被处理。如果发现精确匹配，nginx停止搜索其他匹配。
普通字符匹配，正则表达式规则和长的块规则将被优先和查询匹配，也就是说如果该项匹配还需去看有没有正则表达式匹配和更长的匹配。
^~ 则只匹配该规则，nginx停止搜索其他匹配，否则nginx会继续处理其他location指令。
最后匹配理带有"~"和"~*"的指令，如果找到相应的匹配，则nginx停止搜索其他匹配；当没有正则表达式或者没有正则表达式被匹配的情况下，那么匹配程度最高的逐字匹配指令会被使用。
```
