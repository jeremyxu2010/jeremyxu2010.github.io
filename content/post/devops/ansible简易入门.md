---
title: ansible简易入门
tags:
  - centos
  - ansible
  - deployment
  - automation
categories:
  - devops
date: 2018-02-26 02:53:00+08:00
---

工作中要使用ansible进行自动化部署，这两天花了点时间看了下ansible的文档，也稍稍体验了下，后面会用于项目实战，这里将实验过程中的一些经验记录下来方便后续查阅。

# 什么是ansible

ansible是个什么东西呢？官方的title是“Ansible is Simple IT Automation”——简单的自动化IT工具。这个工具的目标有这么几项：让我们自动化部署APP；自动化管理配置项；自动化的持续交付；自动化的（AWS）云服务管理。

所有的这几个目标本质上来说都是在一个台或者几台服务器上，执行一系列的命令而已。——**批量的在远程服务器上执行命令** 。

Ansible提供了一套简单的流程，你要按照它的流程来做，就能轻松完成任务。这就像是库和框架的关系一样。

Ansible是基于 [paramiko](https://github.com/paramiko/paramiko) 开发的。这个paramiko是什么呢？它是一个纯Python实现的ssh协议库。因此fabric和ansible还有一个共同点就是不需要在远程主机上安装client/agents，因为它们是基于ssh来和远程主机通讯的。

# 快速安装

我实验过程中管理主机的操作系统是macOS 10.13.3，托管主机的操作系统是CentOS 6.7，IP是10.211.55.10。

管理主机上安装ansible

```bash
brew install ansible
```

托管主机上安装ansible

```
# 启用epel源，并修改地址至sng源镜像地址
yum install -y http://mirror-sng.oa.com/epel/epel-release-latest-6.noarch.rpm
sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/epel.repo
sed -i 's/^#baseurl=http:\/\/download.fedoraproject.org\/pub\/epel/baseurl=http://mirror-sng.oa.com/epel/g' /etc/yum.repos.d/epel.repo

yum install -y ansible
```

到管理主机执行命令简单测试一下

```
mkdir ansible_test
cd ansible_test

# 创建hosts文件
echo '
[centos6.7]
10.211.55.10
' > hosts

# 创建ansible配置文件，指定hosts文件使用当前目录下的hosts文件
echo '
[defaults]
inventory=./hosts
' > ansible.cfg

# 使用ansible执行一条ad-hoc命令，按照指示输入托管主机的root密码即可
ansible all -m ping -u root -k
```

# 使用ansible

## 主机与组

Ansible 可同时操作属于一个组的多台主机,组和主机之间的关系通过 inventory 文件配置. 默认的文件路径为 /etc/ansible/hosts，也可在ansible.cfg里指定inventory。

除默认文件外,你还可以同时使用多个 inventory 文件，也可以从动态源,或云上拉取 inventory 配置信息.详见 [*动态 Inventory*](http://www.ansible.com.cn/docs/intro_dynamic_inventory.html).

详见[inventoryformat](http://www.ansible.com.cn/docs/intro_inventory.html#inventoryformat)

## Patterns

在Ansible中,Patterns 是指我们怎样确定由哪一台主机来管理. 意思就是与哪台主机进行交互. 但是在:doc:playbooks 中它指的是对应主机应用特定的配置或执行特定进程.

ad-hoc命令里使用patterns:

```
ansible <pattern_goes_here> -m <module_name> -a <arguments>
```

playbook里使用patterns:

```
# example.yml里会指定不同role对应的patterns，参见https://github.com/ansible/ansible-examples/blob/master/tomcat-memcached-failover/site.yml
ansible-playbook example.yml
```

## 设置公钥认证登录托管主机

每次执行命令时都要输入密码显然很难进行自动化部署，因此在实际使用一般会设置公钥认证。

在管理主机上输入以下命令

```
ssh-keygen -f $HOME/.ssh/id_rsa -t rsa -N ''  # 生成本地的ssh登录密钥
ssh-add $HOME/.ssh/id_rsa
ssh-copy-id -i $HOME/.ssh/id_rsa root@10.211.55.10  # 输入托管主机的root密码
echo '
host_key_checking = False' >> ansible.cfg  # 禁用对key信息的确认提示
```

后面就不用再输入托管主机的密码了，可直接远程执行命令了。

```
ansible all -m ping -u root
```

## ad-hoc 命令

ad hoc——临时的，在ansible中是指需要快速执行，并且不需要保存的命令。说白了就是执行简单的命令——一条命令。对于复杂的命令后面会说playbook。

ansible有许多模块,默认是 ‘command’,也就是命令模块,我们可以通过 `-m` 选项来指定不同的模块.

### 执行命令

```
ansible all -m command -a '/bin/echo hello' -u root
ansible all -m shell -a 'free -m' -u root
```

**command 模块不支持 shell 变量,也不支持管道等 shell 相关的东西.如果你想使用 shell相关的这些东西, 请使用’shell’ 模块.两个模块之前的差别请参考 [*模块相关*](http://www.ansible.com.cn/docs/modules.html) .**

### 文件传输

```
# 拷贝文件
ansible all -m copy -a "src=/etc/hosts dest=/tmp/hosts"
# 修改文件的属主和权限
ansible all -m file -a "dest=/srv/foo/a.txt mode=600"
ansible all -m file -a "dest=/srv/foo/b.txt mode=600 owner=mdehaan group=mdehaan"
# 创建目录
ansible all -m file -a "dest=/path/to/c mode=755 owner=mdehaan group=mdehaan state=directory"
# 删除目录(递归的删除)和删除文件
ansible all -m file -a "dest=/path/to/c state=absent"
```

### 管理软件包

```
# 确认一个软件包已经安装,但不去升级它
ansible webservers -m yum -a "name=acme state=present"
# 确认一个软件包的安装版本
ansible webservers -m yum -a "name=acme-1.5 state=present"
# 确认一个软件包还没有安装
ansible webservers -m yum -a "name=acme state=absent"
```

### 用户与用户组

使用 ‘user’ 模块可以方便的创建账户,删除账户,或是管理现有的账户

```
# 创建账户
ansible all -m user -a "name=foo password=<crypted password here>"
# 删除账户
ansible all -m user -a "name=foo state=absent"
```

### 管理服务

```
# 确认某个服务已经启动
ansible webservers -m service -a "name=httpd state=started" 
# 重启某个服务
ansible webservers -m service -a "name=httpd state=restarted"
# 确认某个服务已经停止
ansible webservers -m service -a "name=httpd state=stopped"
```

#### 限时后台任务

```
# 后台执行长时间任务，其中 -B 1800 表示最多运行30分钟, -P 60 表示每隔60秒获取一次状态信息.
ansible all -B 1800 -P 60 -a "/usr/bin/long_running_operation --do-stuff"
# 前面执行后台命令后会返回一个 job id, 将这个 id 传给 async_status 模块，可查询任务的执行状态
ansible web1.example.com -m async_status -a "jid=488359678239.2844"
```

## Playbooks

## Playbooks 简介

Playbooks 与 adhoc 相比,是一种完全不同的运用 ansible 的方式,是非常之强大的.

简单来说,playbooks 是一种简单的配置管理系统与多机器部署系统的基础.与现有的其他系统有不同之处,且非常适合于复杂应用的部署.

Playbooks 可用于声明配置,更强大的地方在于,在 playbooks 中可以编排有序的执行过程,甚至于做到在多组机器间,来回有序的执行特别指定的步骤.并且可以同步或异步的发起任务.

我们使用 adhoc 时,主要是使用 `/usr/bin/ansible `程序执行任务.而使用 playbooks 时,更多是将之放入源码控制之中,用之推送你的配置或是用于确认你的远程系统的配置是否符合配置规范.

playbooks就是按“约定大于配置“的方式组织需要远程执行的命令，先放在下一篇详细说明了，详见[Playbooks 介绍](http://www.ansible.com.cn/docs/playbooks_intro.html)和[Playbook 角色(Roles) 和 Include 语句](http://www.ansible.com.cn/docs/playbooks_roles.html#id5)。

# 参考

1. http://www.ansible.com.cn/docs/
2. https://www.the5fire.com/ansible-guide-cn.html
3. https://github.com/ansible/ansible-examples
