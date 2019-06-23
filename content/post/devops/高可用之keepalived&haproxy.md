---
title: 高可用之keepalived&haproxy
tags:
  - 高可用
  - keepalived
  - haproxy
  - nginx
  - lvs
categories:
  - devops
date: 2018-02-25 21:27:00+08:00
---

项目中用到了keepalived及haproxy来实现服务的高可用，防止单点故障。以前其实也用过keepalived及nginx实现类似的功能，当时没有作记录，这里作一下记录以备忘。

#  Keepalived

## keepalived是什么

keepalived是集群管理中保证集群高可用的一个服务软件，其功能类似于[heartbeat](https://github.com/chenzhiwei/linux/tree/master/heartbeat)，用来防止单点故障。

## keepalived工作原理

keepalived是以VRRP协议为实现基础的，VRRP全称Virtual Router Redundancy Protocol，即[虚拟路由冗余协议](http://en.wikipedia.org/wiki/VRRP)。

虚拟路由冗余协议，可以认为是实现路由器高可用的协议，即将N台提供相同功能的路由器组成一个路由器组，这个组里面有一个master和多个backup，master上面有一个对外提供服务的vip（该路由器所在局域网内其他机器的默认路由为该vip），master会发组播，当backup收不到vrrp包时就认为master宕掉了，这时就需要根据[VRRP的优先级](http://tools.ietf.org/html/rfc5798#section-5.1)来[选举一个backup当master](http://en.wikipedia.org/wiki/Virtual_Router_Redundancy_Protocol#Elections_of_master_routers)。这样的话就可以保证路由器的高可用了。

keepalived主要有三个模块，分别是core、check和vrrp。core模块为keepalived的核心，负责主进程的启动、维护以及全局配置文件的加载和解析。check负责健康检查，包括常见的各种检查方式。vrrp模块是来实现VRRP协议的。

## keepalived的配置文件

keepalived只有一个配置文件keepalived.conf，里面主要包括以下几个配置区域，分别是global_defs、static_ipaddress、static_routes、vrrp_script、vrrp_instance和virtual_server。

### global_defs区域

主要是配置故障发生时的通知对象以及机器标识

```
global_defs {
    notification_email {
        a@abc.com
        b@abc.com
        ...
    }
    notification_email_from alert@abc.com
    smtp_server smtp.abc.com
    smtp_connect_timeout 30
    enable_traps
    router_id host163
}

```

- notification_email 故障发生时给谁发邮件通知。
- notification_email_from 通知邮件从哪个地址发出。
- smpt_server 通知邮件的smtp地址。
- smtp_connect_timeout 连接smtp服务器的超时时间。
- enable_traps 开启SNMP陷阱（[Simple Network Management Protocol](http://en.wikipedia.org/wiki/Simple_Network_Management_Protocol)）。
- router_id 标识本节点的字条串，通常为hostname，但不一定非得是hostname。故障发生时，邮件通知会用到。

### static_ipaddress和static_routes区域

static_ipaddress和static_routes区域配置的是是本节点的IP和路由信息。如果你的机器上已经配置了IP和路由，那么这两个区域可以不用配置。其实，一般情况下你的机器都会有IP地址和路由信息的，因此没必要再在这两个区域配置。

```
static_ipaddress {
    10.210.214.163/24 brd 10.210.214.255 dev eth0
    ...
}

static_routes {
    10.0.0.0/8 via 10.210.214.1 dev eth0
    ...
}

```

以上分别表示启动/关闭keepalived时在本机执行的如下命令：

```
# /sbin/ip addr add 10.210.214.163/24 brd 10.210.214.255 dev eth0
# /sbin/ip route add 10.0.0.0/8 via 10.210.214.1 dev eth0
# /sbin/ip addr del 10.210.214.163/24 brd 10.210.214.255 dev eth0
# /sbin/ip route del 10.0.0.0/8 via 10.210.214.1 dev eth0

```

注意： 请忽略这两个区域，因为我坚信你的机器肯定已经配置了IP和路由。

### vrrp_script区域

用来做健康检查的，当时检查失败时会将`vrrp_instance`的`priority`减少相应的值。

```
vrrp_script chk_http_port {
    script "</dev/tcp/127.0.0.1/80"
    interval 1
    weight -10
}

```

以上意思是如果`script`中的指令执行失败，那么相应的`vrrp_instance`的优先级会减少10个点。

### vrrp_instance和vrrp_sync_group区域

vrrp_instance用来定义对外提供服务的VIP区域及其相关属性。

vrrp_rsync_group用来定义vrrp_intance组，使得这个组内成员动作一致。举个例子来说明一下其功能：

两个vrrp_instance同属于一个vrrp_rsync_group，那么其中一个vrrp_instance发生故障切换时，另一个vrrp_instance也会跟着切换（即使这个instance没有发生故障）。

```
vrrp_sync_group VG_1 {
    group {
        inside_network   # name of vrrp_instance (below)
        outside_network  # One for each moveable IP.
        ...
    }
    notify_master /path/to_master.sh
    notify_backup /path/to_backup.sh
    notify_fault "/path/fault.sh VG_1"
    notify /path/notify.sh
    smtp_alert
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    use_vmac <VMAC_INTERFACE>
    dont_track_primary
    track_interface {
        eth0
        eth1
    }
    mcast_src_ip <IPADDR>
    lvs_sync_daemon_interface eth1
    garp_master_delay 10
    virtual_router_id 1
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 12345678
    }
    virtual_ipaddress {
        10.210.214.253/24 brd 10.210.214.255 dev eth0
        192.168.1.11/24 brd 192.168.1.255 dev eth1
    }

    virtual_routes {
        172.16.0.0/12 via 10.210.214.1
        192.168.1.0/24 via 192.168.1.1 dev eth1
        default via 202.102.152.1
    }

    track_script {
        chk_http_port
    }

    nopreempt
    preempt_delay 300
    debug
    notify_master <STRING>|<QUOTED-STRING>
    notify_backup <STRING>|<QUOTED-STRING>
    notify_fault <STRING>|<QUOTED-STRING>
    notify <STRING>|<QUOTED-STRING>
    smtp_alert
}

```

- notify_master/backup/fault 分别表示切换为主/备/出错时所执行的脚本。
- notify 表示任何一状态切换时都会调用该脚本，并且该脚本在以上三个脚本执行完成之后进行调用，keepalived会自动传递三个参数（$1 = "GROUP"|"INSTANCE"，$2 = name of group or instance，$3 = target state of transition(MASTER/BACKUP/FAULT)）。
- smtp_alert 表示是否开启邮件通知（用全局区域的邮件设置来发通知）。
- state 可以是MASTER或BACKUP，不过当其他节点keepalived启动时会将priority比较大的节点选举为MASTER，因此该项其实没有实质用途。
- interface 节点固有IP（非VIP）的网卡，用来发VRRP包。
- use_vmac 是否使用VRRP的虚拟MAC地址。
- dont_track_primary 忽略VRRP网卡错误。（默认未设置）
- track_interface 监控以下网卡，如果任何一个不通就会切换到FALT状态。（可选项）
- mcast_src_ip 修改vrrp组播包的源地址，默认源地址为master的IP。（由于是组播，因此即使修改了源地址，该master还是能收到回应的）
- lvs_sync_daemon_interface 绑定lvs syncd的网卡。
- garp_master_delay 当切为主状态后多久更新ARP缓存，默认5秒。
- virtual_router_id 取值在0-255之间，用来区分多个instance的VRRP组播。

注意： 同一网段中virtual_router_id的值不能重复，否则会出错，相关错误信息如下。

```
Keepalived_vrrp[27120]: ip address associated with VRID not present in received packet :
one or more VIP associated with VRID mismatch actual MASTER advert
bogus VRRP packet received on eth1 !!!
receive an invalid ip number count associated with VRID!
VRRP_Instance(xxx) ignoring received advertisment...
```

可以用这条命令来查看该网络中所存在的vrid：`tcpdump -nn -i any net 224.0.0.0/8`

- priority 用来选举master的，要成为master，那么这个选项的值[最好高于其他机器50个点](http://tools.ietf.org/html/rfc5798#section-8.3.2)，该项[取值范围](http://tools.ietf.org/html/rfc5798#section-5.2.4)是1-255（在此范围之外会被识别成默认值100）。
- advert_int 发VRRP包的时间间隔，即多久进行一次master选举（可以认为是健康查检时间间隔）。
- authentication 认证区域，认证类型有PASS和HA（IPSEC），推荐使用PASS（密码只识别前8位）。
- virtual_ipaddress vip，不解释了。
- virtual_routes 虚拟路由，当IP漂过来之后需要添加的路由信息。
- virtual_ipaddress_excluded 发送的VRRP包里不包含的IP地址，为减少回应VRRP包的个数。在网卡上绑定的IP地址比较多的时候用。
- nopreempt 允许一个priority比较低的节点作为master，即使有priority更高的节点启动。

首先nopreemt必须在state为BACKUP的节点上才生效（因为是BACKUP节点决定是否来成为MASTER的），其次要实现类似于关闭auto failback的功能需要将所有节点的state都设置为BACKUP，或者将master节点的priority设置的比BACKUP低。我个人推荐使用将所有节点的state都设置成BACKUP并且都加上nopreempt选项，这样就完成了关于autofailback功能，当想手动将某节点切换为MASTER时只需去掉该节点的nopreempt选项并且将priority改的比其他节点大，然后重新加载配置文件即可（等MASTER切过来之后再将配置文件改回去再reload一下）。

当使用`track_script`时可以不用加`nopreempt`，只需要加上`preempt_delay 5`，这里的间隔时间要大于`vrrp_script`中定义的时长。

- preempt_delay master启动多久之后进行接管资源（VIP/Route信息等），并提是没有`nopreempt`选项。

**上述的文字来自于[这里](https://github.com/chenzhiwei/linux/tree/master/keepalived)，一般我们使用keepalived就是用上述的功能来监测服务，主从切换时自动地将vip进行漂移。**

其实keepalived也可以用来作负载均衡，如下。

### virtual_server_group和virtual_server区域

virtual_server_group一般在超大型的LVS中用到，一般LVS用不过这东西，因此不多说。

```
virtual_server IP Port {
    delay_loop <INT>
    lb_algo rr|wrr|lc|wlc|lblc|sh|dh
    lb_kind NAT|DR|TUN
    persistence_timeout <INT>
    persistence_granularity <NETMASK>
    protocol TCP
    ha_suspend
    virtualhost <STRING>
    alpha
    omega
    quorum <INT>
    hysteresis <INT>
    quorum_up <STRING>|<QUOTED-STRING>
    quorum_down <STRING>|<QUOTED-STRING>
    sorry_server <IPADDR> <PORT>
    real_server <IPADDR> <PORT> {
        weight <INT>
        inhibit_on_failure
        notify_up <STRING>|<QUOTED-STRING>
        notify_down <STRING>|<QUOTED-STRING>
        # HTTP_GET|SSL_GET|TCP_CHECK|SMTP_CHECK|MISC_CHECK
        HTTP_GET|SSL_GET {
            url {
                path <STRING>
                # Digest computed with genhash
                digest <STRING>
                status_code <INT>
            }
            connect_port <PORT>
            connect_timeout <INT>
            nb_get_retry <INT>
            delay_before_retry <INT>
        }
    }
}

```

- delay_loop 延迟轮询时间（单位秒）。
- lb_algo 后端调试算法（load balancing algorithm）。
- lb_kind LVS调度类型[NAT](http://kb.linuxvirtualserver.org/wiki/LVS/NAT)/[DR](http://kb.linuxvirtualserver.org/wiki/LVS/DR)/[TUN](http://kb.linuxvirtualserver.org/wiki/LVS/TUN)。
- virtualhost 用来给HTTP_GET和SSL_GET配置请求header的。
- sorry_server 当所有real server宕掉时，sorry server顶替。
- real_server 真正提供服务的服务器。
- weight 权重。
- notify_up/down 当real server宕掉或启动时执行的脚本。
- 健康检查的方式，N多种方式。
- path 请求real serserver上的路径。
- digest/status_code 分别表示用genhash算出的结果和http状态码。
- connect_port 健康检查，如果端口通则认为服务器正常。
- connect_timeout,nb_get_retry,delay_before_retry分别表示超时时长、重试次数，下次重试的时间延迟。

其他选项暂时不作说明。

### keepalived主从切换

主从切换比较让人蛋疼，需要将backup配置文件的priority选项的值调整的比master高50个点，然后reload配置文件就可以切换了。当时你也可以将master的keepalived停止，这样也可以进行主从切换。

# HAProxy

## HAProxy是什么

HAProxy是一个免费的负载均衡软件，可以运行于大部分主流的Linux操作系统上。

HAProxy提供了L4(TCP)和L7(HTTP)两种负载均衡能力，具备丰富的功能。HAProxy的社区非常活跃，版本更新快速（最新稳定版1.7.2于2017/01/13推出）。最关键的是，HAProxy具备媲美商用负载均衡器的性能和稳定性。

因为HAProxy的上述优点，它当前不仅仅是免费负载均衡软件的首选，更几乎成为了唯一选择。

## HAProxy的核心能力和关键特性

### HAProxy的核心功能

- 负载均衡：L4和L7两种模式，支持RR/静态RR/LC/IP Hash/URI Hash/URL_PARAM Hash/HTTP_HEADER Hash等丰富的负载均衡算法
- 健康检查：支持TCP和HTTP两种健康检查模式
- 会话保持：对于未实现会话共享的应用集群，可通过Insert Cookie/Rewrite Cookie/Prefix Cookie，以及上述的多种Hash方式实现会话保持
- SSL：HAProxy可以解析HTTPS协议，并能够将请求解密为HTTP后向后端传输
- HTTP请求重写与重定向
- 监控与统计：HAProxy提供了基于Web的统计信息页面，展现健康状态和流量数据。基于此功能，使用者可以开发监控程序来监控HAProxy的状态

**从这个核心功能来看，haproxy实现的功能类似于nginx的L4、L7反向代理。**

### HAProxy的关键特性

#### **性能**

- 采用单线程、事件驱动、非阻塞模型，减少上下文切换的消耗，能在1ms内处理数百个请求。并且每个会话只占用数KB的内存。
- 大量精细的性能优化，如O(1)复杂度的事件检查器、延迟更新技术、Single-buffereing、Zero-copy forwarding等等，这些技术使得HAProxy在中等负载下只占用极低的CPU资源。
- HAProxy大量利用操作系统本身的功能特性，使得其在处理请求时能发挥极高的性能，通常情况下，HAProxy自身只占用15%的处理时间，剩余的85%都是在系统内核层完成的。
- HAProxy作者在8年前（2009）年使用1.4版本进行了一次测试，单个HAProxy进程的处理能力突破了10万请求/秒，并轻松占满了10Gbps的网络带宽。

#### **稳定性**

作为建议以单进程模式运行的程序，HAProxy对稳定性的要求是十分严苛的。按照作者的说法，HAProxy在13年间从未出现过一个会导致其崩溃的BUG，HAProxy一旦成功启动，除非操作系统或硬件故障，否则就不会崩溃（我觉得可能多少还是有夸大的成分）。

在上文中提到过，HAProxy的大部分工作都是在操作系统内核完成的，所以HAProxy的稳定性主要依赖于操作系统，作者建议使用2.6或3.x的Linux内核，对sysctls参数进行精细的优化，并且确保主机有足够的内存。这样HAProxy就能够持续满负载稳定运行数年之久。

## HAProxy关键配置详解

### 总览

HAProxy的配置文件共有5个域

- global：用于配置全局参数
- default：用于配置所有frontend和backend的默认属性
- frontend：用于配置前端服务（即HAProxy自身提供的服务）实例
- backend：用于配置后端服务（即HAProxy后面接的服务）实例组
- listen：frontend+backend的组合配置，可以理解成更简洁的配置方法

### global域的关键配置

- daemon：指定HAProxy以后台模式运行，通常情况下都应该使用这一配置
- user [username] ：指定HAProxy进程所属的用户
- group [groupname] ：指定HAProxy进程所属的用户组
- `log [address][device][maxlevel][minlevel]`：日志输出配置，如log 127.0.0.1 local0 info warning，即向本机rsyslog或syslog的local0输出info到warning级别的日志。其中[minlevel]可以省略。HAProxy的日志共有8个级别，从高到低为emerg/alert/crit/err/warning/notice/info/debug
- pidfile ：指定记录HAProxy进程号的文件绝对路径。主要用于HAProxy进程的停止和重启动作。
- maxconn ：HAProxy进程同时处理的连接数，当连接数达到这一数值时，HAProxy将停止接收连接请求

### frontend域的关键配置

- `acl [name][criterion] [flags][operator] [value]`：定义一条ACL，ACL是根据数据包的指定属性以指定表达式计算出的true/false值。如"acl url_ms1 path_beg -i /ms1/"定义了名为url_ms1的ACL，该ACL在请求uri以/ms1/开头（忽略大小写）时为true
- bind [ip]:[port]：frontend服务监听的端口
- default_backend [name]：frontend对应的默认backend
- disabled：禁用此frontend
- `http-request [operation][condition]`：对所有到达此frontend的HTTP请求应用的策略，例如可以拒绝、要求认证、添加header、替换header、定义ACL等等。
- `http-response [operation][condition]`：对所有从此frontend返回的HTTP响应应用的策略，大体同上
- log：同global域的log配置，仅应用于此frontend。如果要沿用global域的log配置，则此处配置为log global
- maxconn：同global域的maxconn，仅应用于此frontend
- mode：此frontend的工作模式，主要有http和tcp两种，对应L7和L4两种负载均衡模式
- option forwardfor：在请求中添加X-Forwarded-For Header，记录客户端ip
- option http-keep-alive：以KeepAlive模式提供服务
- option httpclose：与http-keep-alive对应，关闭KeepAlive模式，如果HAProxy主要提供的是接口类型的服务，可以考虑采用httpclose模式，以节省连接数资源。但如果这样做了，接口的调用端将不能使用HTTP连接池
- option httplog：开启httplog，HAProxy将会以类似Apache HTTP或Nginx的格式来记录请求日志
- option tcplog：开启tcplog，HAProxy将会在日志中记录数据包在传输层的更多属性
- stats uri [uri]：在此frontend上开启监控页面，通过[uri]访问
- stats refresh [time]：监控数据刷新周期
- stats auth [user]:[password]：监控页面的认证用户名密码
- timeout client [time]：指连接创建后，客户端持续不发送数据的超时时间
- timeout http-request [time]：指连接创建后，客户端没能发送完整HTTP请求的超时时间，主要用于防止DoS类攻击，即创建连接后，以非常缓慢的速度发送请求包，导致HAProxy连接被长时间占用
- use_backend [backend] if|unless [acl]：与ACL搭配使用，在满足/不满足ACL时转发至指定的backend

### backend域的关键配置

- acl：同frontend域
- balance [algorithm]：在此backend下所有server间的负载均衡算法，常用的有roundrobin和source，完整的算法说明见官方文档[configuration.html#4.2-balance](https://link.jianshu.com?t=http://cbonte.github.io/haproxy-dconv/1.7/configuration.html#4.2-balance)
- cookie：在backend server间启用基于cookie的会话保持策略，最常用的是insert方式，如cookie HA_STICKY_ms1 insert indirect nocache，指HAProxy将在响应中插入名为HA_STICKY_ms1的cookie，其值为对应的server定义中指定的值，并根据请求中此cookie的值决定转发至哪个server。indirect代表如果请求中已经带有合法的HA_STICK_ms1 cookie，则HAProxy不会在响应中再次插入此cookie，nocache则代表禁止链路上的所有网关和缓存服务器缓存带有Set-Cookie头的响应。
- default-server：用于指定此backend下所有server的默认设置。具体见下面的server配置。
- disabled：禁用此backend
- http-request/http-response：同frontend域
- log：同frontend域
- mode：同frontend域
- option forwardfor：同frontend域
- option http-keep-alive：同frontend域
- option httpclose：同frontend域
- `option httpchk [METHOD][URL] [VERSION]`：定义以http方式进行的健康检查策略。如option httpchk GET /healthCheck.html HTTP/1.1
- option httplog：同frontend域
- option tcplog：同frontend域
- `server [name][ip]:[port][params]`：定义backend中的一个后端server，[params]用于指定这个server的参数，常用的包括有：

> check：指定此参数时，HAProxy将会对此server执行健康检查，检查方法在option httpchk中配置。同时还可以在check后指定inter, rise, fall三个参数，分别代表健康检查的周期、连续几次成功认为server UP，连续几次失败认为server DOWN，默认值是inter 2000ms rise 2 fall 3
> cookie [value]：用于配合基于cookie的会话保持，如cookie ms1.srv1代表交由此server处理的请求会在响应中写入值为ms1.srv1的cookie（具体的cookie名则在backend域中的cookie设置中指定）
> maxconn：指HAProxy最多同时向此server发起的连接数，当连接数到达maxconn后，向此server发起的新连接会进入等待队列。默认为0，即无限
> maxqueue：等待队列的长度，当队列已满后，后续请求将会发至此backend下的其他server，默认为0，即无限
> weight：server的权重，0-256，权重越大，分给这个server的请求就越多。weight为0的server将不会被分配任何新的连接。所有server默认weight为1

- timeout connect [time]：指HAProxy尝试与backend server创建连接的超时时间
- timeout check [time]：默认情况下，健康检查的连接+响应超时时间为server命令中指定的inter值，如果配置了timeout check，HAProxy会以inter作为健康检查请求的连接超时时间，并以timeout check的值作为健康检查请求的响应超时时间
- timeout server [time]：指backend server响应HAProxy请求的超时时间

### default域

上文所属的frontend和backend域关键配置中，除acl、bind、http-request、http-response、use_backend外，其余的均可以配置在default域中。default域中配置了的项目，如果在frontend或backend域中没有配置，将会使用default域中的配置。

### listen域

listen域是frontend域和backend域的组合，frontend域和backend域中所有的配置都可以配置在listen域下

### 官方配置文档

HAProxy的配置项非常多，支持非常丰富的功能，上文只列出了作为L7负载均衡器使用HAProxy时的一些关键参数。完整的参数说明请参见官方文档 [configuration.html](https://link.jianshu.com?t=http://cbonte.github.io/haproxy-dconv/1.7/configuration.html)

# 使用实例

## 使用HAProxy搭建L7负载均衡器

### 总体方案

本节中，我们将使用HAProxy搭建一个L7负载均衡器，应用如下功能

- 负载均衡

- 会话保持

- 健康检查

- 根据URI前缀向不同的后端集群转发

- 监控页面

### HAProxy配置文件

```
global
    daemon
    maxconn 30000   #ulimit -n至少为60018
    user ha
    pidfile /home/ha/haproxy/conf/haproxy.pid
    log 127.0.0.1 local0 info
    log 127.0.0.1 local1 warning

defaults
    mode http
    log global
    option http-keep-alive   #使用keepAlive连接
    option forwardfor        #记录客户端IP在X-Forwarded-For头域中
    option httplog           #开启httplog，HAProxy会记录更丰富的请求信息
    timeout connect 5000ms
    timeout client 10000ms
    timeout server 50000ms
    timeout http-request 20000ms    #从连接创建开始到从客户端读取完整HTTP请求的超时时间，用于避免类DoS攻击
    option httpchk GET /healthCheck.html    #定义默认的健康检查策略

frontend http-in
    bind *:9001
    maxconn 30000                    #定义此端口上的maxconn
    acl url_ms1 path_beg -i /ms1/    #定义ACL，当uri以/ms1/开头时，ACL[url_ms1]为true
    acl url_ms2 path_beg -i /ms2/    #同上，url_ms2
    use_backend ms1 if url_ms1       #当[url_ms1]为true时，定向到后端服务群ms1中
    use_backend ms2 if url_ms2       #当[url_ms2]为true时，定向到后端服务群ms2中
    default_backend default_servers  #其他情况时，定向到后端服务群default_servers中

backend ms1    #定义后端服务群ms1
    balance roundrobin    #使用RR负载均衡算法
    cookie HA_STICKY_ms1 insert indirect nocache    #会话保持策略，insert名为"HA_STICKY_ms1"的cookie
    #定义后端server[ms1.srv1]，请求定向到该server时会在响应中写入cookie值[ms1.srv1]
    #针对此server的maxconn设置为300
    #应用默认健康检查策略，健康检查间隔和超时时间为2000ms，两次成功视为节点UP，三次失败视为节点DOWN
    server ms1.srv1 192.168.8.111:8080 cookie ms1.srv1 maxconn 300 check inter 2000ms rise 2 fall 3
    #同上，inter 2000ms rise 2 fall 3是默认值，可以省略
    server ms1.srv2 192.168.8.112:8080 cookie ms1.srv2 maxconn 300 check

backend ms2    #定义后端服务群ms2
    balance roundrobin
    cookie HA_STICKY_ms2 insert indirect nocache
    server ms2.srv1 192.168.8.111:8081 cookie ms2.srv1 maxconn 300 check
    server ms2.srv2 192.168.8.112:8081 cookie ms2.srv2 maxconn 300 check

backend default_servers    #定义后端服务群default_servers
    balance roundrobin
    cookie HA_STICKY_def insert indirect nocache
    server def.srv1 192.168.8.111:8082 cookie def.srv1 maxconn 300 check
    server def.srv2 192.168.8.112:8082 cookie def.srv2 maxconn 300 check

listen stats    #定义监控页面
    bind *:1080                   #绑定端口1080
    stats refresh 30s             #每30秒更新监控数据
    stats uri /stats              #访问监控页面的uri
    stats realm HAProxy\ Stats    #监控页面的认证提示
    stats auth admin:admin        #监控页面的用户名和密码
```

## 使用HAProxy搭建L4负载均衡器

HAProxy作为L4负载均衡器工作时，不会去解析任何与HTTP协议相关的内容，只在传输层对数据包进行处理。也就是说，以L4模式运行的HAProxy，无法实现根据URL向不同后端转发、通过cookie实现会话保持等功能。

同时，在L4模式下工作的HAProxy也无法提供监控页面。

但作为L4负载均衡器的HAProxy能够提供更高的性能，适合于基于套接字的服务（如数据库、消息队列、RPC、邮件服务、Redis等），或不需要逻辑规则判断，并已实现了会话共享的HTTP服务。

### HAProxy配置文件

```
global
    daemon
    maxconn 30000   #ulimit -n至少为60018
    user ha
    pidfile /home/ha/haproxy/conf/haproxy.pid
    log 127.0.0.1 local0 info
    log 127.0.0.1 local1 warning

defaults
    mode tcp
    log global
    option tcplog            #开启tcplog
    timeout connect 5000ms
    timeout client 10000ms
    timeout server 10000ms   #TCP模式下，应将timeout client和timeout server设置为一样的值，以防止出现问题
    option httpchk GET /healthCheck.html    #定义默认的健康检查策略

frontend http-in
    bind *:9002
    maxconn 30000                    #定义此端口上的maxconn
    default_backend default_servers  #请求定向至后端服务群default_servers

backend default_servers    #定义后端服务群default_servers
    balance source  #基于客户端IP的会话保持
    server def.srv1 192.168.8.111:8082 maxconn 300 check
    server def.srv2 192.168.8.112:8082 maxconn 300 check
```




## 使用Keepalived实现HAProxy高可用

尽管HAProxy非常稳定，但仍然无法规避操作系统故障、主机硬件故障、网络故障甚至断电带来的风险。所以必须对HAProxy实施高可用方案。

下文将介绍利用Keepalived实现的HAProxy热备方案。即两台主机上的两个HAProxy实例同时在线，其中权重较高的实例为MASTER，MASTER出现问题时，另一台实例自动接管所有流量。

### 原理

在两台HAProxy的主机上分别运行着一个Keepalived实例，这两个Keepalived争抢同一个虚IP地址，两个HAProxy也尝试去绑定这同一个虚IP地址上的端口。
显然，同时只能有一个Keepalived抢到这个虚IP，抢到了这个虚IP的Keepalived主机上的HAProxy便是当前的MASTER。
Keepalived内部维护一个权重值，权重值最高的Keepalived实例能够抢到虚IP。同时Keepalived会定期check本主机上的HAProxy状态，状态OK时权重值增加。

### keepalived配置文件

```
global_defs {
    router_id LVS_DEVEL  #虚拟路由名称
}
#HAProxy健康检查配置
vrrp_script chk_haproxy {
    script "killall -0 haproxy"  #使用killall -0检查haproxy实例是否存在，性能高于ps命令
    interval 2   #脚本运行周期
    weight 2   #每次检查的加权权重值
}
#虚拟路由配置
vrrp_instance VI_1 {
    state MASTER           #本机实例状态，MASTER/BACKUP，备机配置文件中请写BACKUP
    interface enp0s25      #本机网卡名称，使用ifconfig命令查看
    virtual_router_id 51   #虚拟路由编号，主备机保持一致
    priority 101           #本机初始权重，备机请填写小于主机的值（例如100）
    advert_int 1           #争抢虚地址的周期，秒
    virtual_ipaddress {
        192.168.8.201      #虚地址IP，主备机保持一致
    }
    track_script {
        chk_haproxy        #对应的健康检查配置
    }
}
```

# 参考

1. https://github.com/chenzhiwei/linux/tree/master/keepalived
2. https://www.jianshu.com/p/c9f6d55288c0
3. http://seanlook.com/2015/05/18/nginx-keepalived-ha/
