---
title: ansible简易入门之playbook
tags:
  - centos
  - ansible
  - deployment
  - automation
categories:
  - devops
date: 2018-03-20 22:53:00+08:00
---

## Playbooks 简介

Playbooks 与 adhoc 相比,是一种完全不同的运用 ansible 的方式,是非常之强大的.

简单来说,playbooks 是一种简单的配置管理系统与多机器部署系统的基础.与现有的其他系统有不同之处,且非常适合于复杂应用的部署.

Playbooks 可用于声明配置,更强大的地方在于,在 playbooks 中可以编排有序的执行过程,甚至于做到在多组机器间,来回有序的执行特别指定的步骤.并且可以同步或异步的发起任务.

我们使用 adhoc 时,主要是使用 `/usr/bin/ansible `程序执行任务.而使用 playbooks 时,更多是将之放入源码控制之中,用之推送你的配置或是用于确认你的远程系统的配置是否符合配置规范.

## Playbook示例

首先看一个最简单的示例，基本全是[YAML语法](http://docs.ansible.com/ansible/latest/YAMLSyntax.html)：

```bash
$ tree -L 2
.
├── ansible.cfg
├── example1.yml
├── hosts.yml
└── templates
    └── httpd.conf.j2
    
$ cat hosts.yml
[webservers]
192.168.1.1
192.168.1.2
    
$ cat example1.yml
---
- hosts: webservers
  vars:
    http_port: 80
    max_clients: 200
  remote_user: root
  tasks:
  - name: ensure apache is at the latest version
    yum: pkg=httpd state=latest
  - name: write the apache config file
    template: src=./templates/httpd.conf.j2 dest=/etc/httpd/conf/httpd.conf
    notify:
    - restart apache
  - name: ensure apache is running
    service: name=httpd state=started
  handlers:
    - name: restart apache
      service: name=httpd state=restarted
      
 $ cat httpd.conf.j2
 ...
 MaxClients         {{ max_clients }}
 ...
 Listen {{ http_port }}
 ...
```

这里主要看`example1.yml`这个文件，其代表的意义是在webservers这组主机上执行一个任务列表（先确保安装了httpd的软件包，再通过模板写入一个配置文件，再确保httpd服务已启动），很简单吧。

执行一下：

```bash
ansible-playbook example1.yml
```



## 创建可重用的Playbook

但为了代码的可维护性与重用，一般会重新组织下代码，如下：


```bash
$ tree -L 4
.
├── ansible.cfg
├── example1.yml
├── hosts.yml
└── roles
    └── httpd
        ├── handlers
        │   └── main.yml
        ├── tasks
        │   └── main.yml
        ├── templates
        │   └── httpd.conf.j2
        └── vars
            └── main.yml
            
$ cat example1.yml
---
- hosts: webservers
  remote_user: root
  roles:
    - httpd
  
$ cat roles/httpd/tasks/main.yml
---
- name: ensure apache is at the latest version
  yum: pkg=httpd state=latest
- name: write the apache config file
  template: src=httpd.conf.j2 dest=/etc/httpd/conf/httpd.conf
  notify:
  - restart apache
- name: ensure apache is running
  service: name=httpd state=started
  
$ cat roles/httpd/vars/main.yml
---
- http_port: 80
- max_clients: 200

$ cat roles/httpd/handlers/main.yml
---
- name: restart apache
  service: name=httpd state=restarted
  
$ cat roles/httpd/templates/httpd.conf.j2
 ...
 MaxClients         {{ max_clients }}
 ...
 Listen {{ http_port }}
 ...
```


比较简单，就是将ansible脚本封装到一个所谓的role里面，每个role里按照tasks、vars、templates、handlers等目录组织代码。tasks、vars、templates、handlers目录默认会加载目录中的main.yml，也可以继续拆分main.yml，并用import或include引入起来。

这样做的好处：一是可以让每个role的功能更内敛，另一方面可以比较方便地利用role，如下：

```yaml
---
- hosts: buzservers
  remote_user: root
  roles:
    - httpd
    - tomcat
```

上面的将在buzservers这组主机上安装httpd和tomcat（这两个各是一个已经写好的role）。role除了自己手写外，还可以通过`ansible-galaxy`安装得到，如：

```bash
ansible-galaxy install --roles-path ./roles bennojoy.mysql
```

在[ansible-galaxy](https://galaxy.ansible.com/list#/roles)上有大量别人写的role，基本覆盖了常用的运维需求，很多直接拿来使用就好。

## Tasks 列表

role的tasks目录下可定义任务列表，即在目标主机上执行的指令队列。ansible会按照顺序依次执行该指令队列里的指令。如下所示：

```
- name: ensure apache is at the latest version
  yum: pkg=httpd state=latest
- name: write the apache config file
  template: src=./templates/httpd.conf.j2 dest=/etc/httpd/conf/httpd.conf
  notify:
  - restart apache
- name: ensure apache is running
  service: name=httpd state=started
```

这里每一个指令可以用`name`给命个名，这样输出时方便观察当前执行的指令。

每个指令其实是执行ansible里的模块Module，完整的模块列表在[这里](http://docs.ansible.com/ansible/latest/modules_by_category.html)。每个模块都有很详尽的示例，照着写就可以了。比较常用的有

- [Files Modules](http://docs.ansible.com/ansible/latest/list_of_files_modules.html)
- [Net Tools Modules](http://docs.ansible.com/ansible/latest/list_of_net_tools_modules.html)
- [Network Modules](http://docs.ansible.com/ansible/latest/list_of_network_modules.html)
- [Packaging Modules](http://docs.ansible.com/ansible/latest/list_of_packaging_modules.html)
- [Source Control Modules](http://docs.ansible.com/ansible/latest/list_of_source_control_modules.html)
- [System Modules](http://docs.ansible.com/ansible/latest/list_of_system_modules.html)
- [Utilities Modules](http://docs.ansible.com/ansible/latest/list_of_utilities_modules.html)
- [Windows Modules](http://docs.ansible.com/ansible/latest/list_of_windows_modules.html) 如果要操作windows的话

## Playbook中的变量

变量在Playbook中算是比较复杂的，可以在很多地方定义变量。

### 定义变量

#### Inventory中定义变量

```yaml
# hosts.yml
[atlanta]
host1 http_port=80 maxRequestsPerChild=808
host2 http_port=303 maxRequestsPerChild=909

[atlanta:vars]
ntp_server=ntp.atlanta.example.com
proxy=proxy.atlanta.example.com
```

#### Playbook中定义变量

```yaml
# exampl2.yml
- hosts: webservers
  vars:
    http_port: 80
```

#### role的vars目录下定义变量

```yaml
---
# roles/httpd/vars/main.yml
- http_port: 80
- max_clients: 200
```

#### role的defaults目录下定义默认变量

```yaml
---
# roles/httpd/defaults/main.yml
- http_port: 80
- max_clients: 200
```

#### include指令可以传递变量

```yaml
# roles/httpd/tasks/main.yml
- include: wordpress.yml
vars:
    wp_user: timmy
    some_list_variable:
      - alpha
      - beta
      - gamma
```

#### 命令行中传递变量

```yaml
ansible-playbook release.yml --extra-vars "version=1.23.45 other_variable=foo"
```

#### 自动发现的变量

```yaml
$ ansible hostname -m setup
...
"ansible_all_ipv4_addresses": [
    "REDACTED IP ADDRESS"
],
"ansible_all_ipv6_addresses": [
    "REDACTED IPV6 ADDRESS"
],
"ansible_architecture": "x86_64",
"ansible_bios_date": "09/20/2012",
"ansible_bios_version": "6.00",
...
```

#### 通过register注册变量

```yaml
# roles/httpd/tasks/main.yml
- shell: /usr/bin/foo
  register: foo_result
  ignore_errors: True
- shell: /usr/bin/bar
  when: foo_result.rc == 5
```

#### 通过vars_files引入外部变量文件

```yaml
---
- hosts: all
  remote_user: root
  vars:
    favcolor: blue
  vars_files:
    - /vars/external_vars.yml
```

### 使用变量

#### 模板文件里使用变量

ansible里使用了Jinja2模板，在模板里使用变量还是比较简单的

```jinja2
# roles/httpd/templates/test.j2
My amp goes to {{ max_amp_value }}
```

模板里使用变量还可以使用一些内置的过滤器，参见[这里](http://jinja.pocoo.org/docs/2.10/templates/#builtin-filters)，如下：

```jinja2
{{ "%s - %s"|format("Hello?", "Foo!") }}
    -> Hello? - Foo!
```

#### YAML文件里使用变量

yaml文件里使用变量跟Jinja2模板里一样，也是用`{{ }}`将变量包起来，不过要注意YAML语法要求如果值以`{{ foo }}`开头的话，需要将整行用双引号包起来，这是为了确认不想声明一个YAML字典。

```yaml
- hosts: app_servers
  vars:
       app_path: "{{ base_path }}/22"
```

## Playbook中的流程控制

Playbook也算一种编程语言了，自然少不了流程控制。

### 条件选择

#### when语句

```yaml
# roles/httpd/tasks/main.yml
- name: "shutdown Debian flavored systems"
  command: /sbin/shutdown -t now
  when: ansible_os_family == "Debian"
```

#### 在roles 和 includes 上面应用’when’语句

根据条件决定是否执行一段任务列表：

```yaml
- include: tasks/sometasks.yml
  when: "'reticulating splines' in output"
```

根据条件决定是否执行一个role上的所有操作序列：

```yaml
- hosts: webservers
  roles:
     - { role: debian_stock_config, when: ansible_os_family == 'Debian' }
```

#### 基于变量选择文件和模版

怎样根据不同的系统选择不同的模板：

```ymal
- name: template a file
  template: src={{ item }} dest=/etc/myapp/foo.conf
  with_first_found:
    - files:
       - {{ ansible_distribution }}.conf
       - default.conf
      paths:
       - search_location/
```

### 循环

ansible里循环的用法较多，最常用的是`with_items`，如下：

```yaml
- name: add several users
  user: name={{ item }} state=present groups=wheel
  with_items:
     - testuser1
     - testuser2
```

其它高级循环用法参见[这里](http://www.ansible.com.cn/docs/playbooks_loops.html#standard-loops)

## 其它技巧

### YAML里的函数

ansible里批量删除文件，如果要删除的文件不存在，如果用file模块删除会报错，因此可以写一个工具yaml文件，相当于一个函数，然后使用include指令动态导入它，相当于调用函数。如下：

```yaml
# delete_files.yml
---
- name: Check file exists
  stat:
    path: "{{ file_path }}"
  register: stat_result

- name: Delete file
  file:
    path: "{{ file_path }}"
    state: absent
  when: stat_result.stat.exists
  
# other.yml
- include_tasks: util/delete_files.yml
  with_items:
  - '/var/log/sss'
  - '/tmp/xxx'
  loop_control:
    loop_var: file_path
```

类似的，一些重复的代码可以用这种方式简化。

**后面发现ansible2.0后添加了一个[Blocks](http://docs.ansible.com/ansible/latest/playbooks_blocks.html)的功能，可以把多个指令当成一个块执行，这下一些简单的多指令操作可以直接用Blocks搞定了**

### 查看自动获取的变量

有时需要使用到从目标主机自动获取的变量，但又清楚变量名是什么，这时可以使用setup模块单独获取该主机的所有自动获取变量：

```yaml
ansible -i hosts.yml 192.168.1.1 -m setup
```

### 拆分Playbook文件

如果部署的项目很复杂，这时Playbook文件会很大，这时可以用`import_playbook`按不同业务维度拆分Playbook文件，如下：

```
- import_playbook: playbooks/buz1.yml
- import_playbook: playbooks/buz2.yml
```

### 复用其它role

如果在一个role的task list里想复用另一个role，可以使用`import_role`，如下：

```yaml
# roles/httpd/tasks/main.yml
...
- import_role:
  name: other_role
...
```

### 快速失败

有时执行某个指令，其结果不正确，这时可以使用`fail`进行快速失败，如下：

```yaml
# Example playbook using fail and when together
- fail:
    msg: "The system may not be provisioned according to the CMDB status."
  when: cmdb_status != "to-be-staged"
```

### 最佳实践

[官方文档中的最佳实践](http://docs.ansible.com/ansible/latest/playbooks_best_practices.html)

## 参考

1. http://www.ansible.com.cn/docs/
2. https://www.the5fire.com/ansible-guide-cn.html
3. https://github.com/ansible/ansible-examples
4. https://galaxy.ansible.com/intro

