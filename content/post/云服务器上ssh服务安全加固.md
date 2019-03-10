---
title: 云服务器上ssh服务安全加固
tags:
  - linux
  - denyhosts
  - ssh
categories:
  - devops
date: 2016-08-24 22:00:00+08:00
---
今天到一个朋友的创业公司进行技术交流，交流过程中，朋友提到他在阿里云上买的linux服务器上ssh服务经常被人暴力破解。我感觉很奇怪，一般来说ssh服务经过简单设置是很安全的，怎么可能会出现这种情况呢。进一步交流才知道他们购买linux服务器后，连一些基本的安全措施都没做。原来并不是所有人都知道放在公网上的服务器是要进行简单的安全加固的。下面把我这些年使用linux时对ssh服务的安全加固步骤写下来，以便其它人参考。（以下的命令脚本基于CentOS6，其它发行版类似）

## 使用普通用户密钥文件登录

直接使用root用户登录服务器当然是不安全的，建议创建一个普通用户用于ssh远程登录。命令如下：

```bash
useradd -m cloudop
```

在另一台PC上生成登录密钥。命令如下：

```bash
ssh-keygen -N '' -f ~/.ssh/cloudkey_rsa
```

然后将上述命令生成的~/.ssh/cloudkey_rsa.pub文件拷贝到服务器，并执行以下命令配置好密钥登录：

```bash
mkdir -p /home/cloudop/.ssh
cat /tmp/cloudkey_rsa.pub >> /home/cloudop/.ssh/authorized_keys
chown -R cloudop:cloudop /home/cloudop/.ssh && chmod 700 /home/cloudop/.ssh && chmod 600 /home/cloudop/.ssh/authorized_keys
```

然后在另一台PC使用以下命令登录服务器：

```bash
ssh -i ~/.ssh/cloudkey_rsa cloudop@${server_ip}
```

如果可成功登录，则说明密钥登录配置成功，登录成功后可执行`su - root`命令切换至root权限进行操作，当然你得知道root密码。

最后修改ssh服务的配置文件禁用root用户登录、仅开放密钥验证方式禁用其它验证方式

```bash
sed -i -e '/^PermitRootLogin.*$/d' /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
sed -i -e '/^PasswordAuthentication.*$/d' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
sed -i -e '/^ChallengeResponseAuthentication.*$/d' /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
sed -i -e '/^GSSAPIAuthentication.*$/d' /etc/ssh/sshd_config
echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config
service sshd restart
```

## 修改ssh服务端口，升起防火墙

有很多攻击程序会扫描公网上服务器的22端口，一旦发现22端口就开始调用程序暴力破解。安全起见，建议修改ssh服务器的端口，命令如下：

```bash
sed -i -e '/^Port.*$/d' /etc/ssh/sshd_config
echo "Port 1221" >> /etc/ssh/sshd_config
service sshd restart
```

同时修改防火墙设置，以允许外部访问修改后的端口，命令如下：

```bash
service iptables start
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 1221 -j ACCEPT
iptables-save > /etc/sysconfig/iptables
service iptables restart
```

这里特意说明一下，放在公网上的服务器一定要升起防火墙，并只开必要的端口。我一般只开放80、443、1221三个端口。

当然以后访问服务器时得使用以下命令：

```bash
ssh -i ~/.ssh/cloudkey_rsa -p 1221 cloudop@${server_ip}
```

scp拷贝文件时得使用以下命令：

```bash
scp -i ~/.ssh/cloudkey_rsa -P 1221 cloudop@${server_ip}:/tmp/xxxx.txt ./
```

## 防止用户暴力破解ssh服务

尽管已经只允许使用密钥登录，而且ssh服务的端口也修改了，可还是难以避免攻击者暴力破解，我一般使用denyhosts这个小软件防范。

这个小软件的原理是分析/var/log/secure（redhat，Fedora Core）等日志文件，当发现同一IP在进行多次SSH密码尝试时就会记录IP到/etc/hosts.deny文件，从而达到自动屏蔽该IP的目的。

安装配置过程如下：

```bash
# 下载DenyHosts并解压
wget http://heanet.dl.sourceforge.net/project/denyhosts/denyhosts/2.6/DenyHosts-2.6.tar.gz
tar zxvf DenyHosts-2.6.tar.gz
cd DenyHosts-2.6

# 安装前清空以前的日志并重启一下rsyslog
echo "" > /var/log/secure && service rsyslog restart

# 因为DenyHosts是基于python的，所以要已安装python，大部分Linux发行版一般都有。默认是安装到/usr/share/denyhosts/目录的,进入相应的目录修改配置文件
python setup.py install

cd /usr/share/denyhosts/
cp denyhosts.cfg-dist denyhosts.cfg
cp daemon-control-dist daemon-control && chown root daemon-control && chmod 700 daemon-control

# 如果要使DenyHosts每次重起后自动启动还需做如下设置
ln -sf /usr/share/denyhosts/daemon-control /etc/init.d/denyhosts && chkconfig --add denyhosts && chkconfig --level 2345 denyhosts on

# 启动denyhosts服务
service denyhosts start
```

`/usr/share/denyhosts/denyhosts.cfg`为denyhosts服务的配置文件，默认的设置已经可以适合centos系统环境，这里对这个配置文件里一些关键配置项作一个说明，大家可以按需修改。

```
SECURE_LOG = /var/log/secure
#sshd日志文件，它是根据这个文件来判断的，不同的操作系统，文件名稍有不同。
HOSTS_DENY = /etc/hosts.deny
#控制用户登陆的文件
PURGE_DENY = 5m
DAEMON_PURGE = 5m
#过多久后清除已经禁止的IP，如5m（5分钟）、5h（5小时）、5d（5天）、5w（5周）、1y（一年）
BLOCK_SERVICE  = sshd
#禁止的服务名，可以只限制不允许访问ssh服务，也可以选择ALL
DENY_THRESHOLD_INVALID = 5
#允许无效用户失败的次数
DENY_THRESHOLD_VALID = 10
#允许普通用户登陆失败的次数
DENY_THRESHOLD_ROOT = 5
#允许root登陆失败的次数
HOSTNAME_LOOKUP=NO
#是否做域名反解
DAEMON_LOG = /var/log/denyhosts
```

如果你有一些确定的IP不希望被denyhosts屏蔽，可以执行以下命令将这些IP加入到白名单：

```bash
echo "你的IP" >>  /usr/share/denyhosts/allowed-hosts
# 重启denyhosts服务
service denyhosts restart
```

如有IP被误封，可以执行下面的命令解封：

```bash
wget -O /usr/share/denyhosts/denyhosts_removeip.sh http://soft.vpser.net/security/denyhosts/denyhosts_removeip.sh
bash /usr/share/denyhosts/denyhosts_removeip.sh 要解封的IP
```

## 其它

服务器的root密码一般只在由普通用户切换至root用户时用到，设置得太复杂，操作不方便，太复杂形同虚设。

所以我一般在团队内部约定一个root密码的规则，这个规则仅团队内部人员知道，比如设置为'R00T@主机名@公司名'。

另外服务器的登录密钥文件一定要妥善保存与分发。

## 总结

做完以上几步，攻击者基本上就很难暴力攻击你的ssh服务了。



