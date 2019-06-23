---
title: 打通到kubernetes集群的网络
tags:
  - kubernetes
  - iptables
  - vpn
  - strongswan
categories:
  - 云计算
date: 2019-03-31 21:21:00+08:00
---

最近在工作中验证istio的网格扩展方案，其中涉及打通网络的需求，也即希望在外部虚拟机可以连通kubernetes集群内部的服务IP、Pod IP，在kubernetes的Pod中可以连通外部虚拟机的IP。

显然kubernetes里的Pod连通外部虚拟机的IP不是问题，只要虚拟机的防火墙没有限制，这个本身就是连通的。关键是怎样让虚拟机可以直接连通kubernetes里的service IP和pod IP。

这里试验了好几种方案，记录一下。

## 配置路由规则

最先想到的是直接配置路由规则方案。由于kubernetes的宿主机上可以直接连通service IP和pod IP，而且kubernetes的宿主机上一般安装了docker，ip forward本身也是开启的。因此只需要在虚拟机上设置两条路由规则，就可以将从虚拟机发出的目标地址是service cidr和pod cidr范围里的数据包转发到kubernetes的宿主机，然后kubernetes的宿主机则可以将数据包再转发给service或pod，这基本是最简单的方案了。参考命令如下：

```bash
# 在虚拟机上添加以下两条路由规则
sudo route add -net 10.96.0.0/12 gw 192.168.33.10
sudo route add -net 10.244.0.0/16 gw 192.168.33.10
```

其中`10.96.0.0/12`为service cidr, `10.244.0.0/16`为pod cidr, `192.168.33.10`为kubernetes的宿主机。

## strongswan搭建VPN

配置路由规则虽然简单，但感觉还是太简易了，路由规则很容易被其它进程覆写了。偶然看到rancher推出的多kubernetes网络打通方案[submariner](https://github.com/rancher/submariner)，仔细读了下它的设计方案，发现它是使用[strongswan](https://github.com/strongswan/strongswan)建立的IPsec VPN。于是也尝试了直接使用strongswan搭建IPsec VPN。[strongswan的文档](https://github.com/strongswan/strongswan)写得比较好，将各种场景如何配置都举了个例子。经过仔细对比，发现[Roadwarrior Case with Virtual IP](https://github.com/strongswan/strongswan#roadwarrior-case-with-virtual-ip)这个场景应该是最适合我们的，于是参考这个场景的配置，验证了下我们这个场景，具体验证过程见[这里](https://github.com/jeremyxu2010/vagrant_files/tree/master/k8s-strongswan-vpn)。可惜最终没有成功，原因未知。

## sshuttle搭建VPN

虽然使用sshuttle搭建VPN失败了，但还是不甘心。前几天偶然发现了一个叫[sshuttle](https://sshuttle.readthedocs.io/)的工具，其号称是穷人极简的VPN方案。只有能与对端建立SSH连接，就可以使用这个工具非常方便地建立一个VPN隧道，于是试了试。参考命令如下：

```bash
sudo yum install -y sshuttle

sleep 5
# 提前生成ssh密钥对，并做好ssh密钥认证登录
# ssh-keygen -t rsa -N ''
# ssh-copy-id root@192.168.33.10
sudo sshuttle -r root@192.168.33.10 10.96.0.0/12 10.244.0.0/16 > sshuttle.log 2>&1 &
```

上面的命令意思是，如果发现数据包的目标IP地址是`10.96.0.0/12`、`10.244.0.0/16`这个范围内，则将数据包经由VPN隧道传送出去，真的是好方便。完整的验证过程见[这里](https://github.com/jeremyxu2010/vagrant_files/tree/master/k8s-sshuttle-vpn)。

## 总结

打通网络的方案很多，但基本都要求对网络及iptables知识有一定了解，幸好平时在这方面有一切储备。对于一般场景，设置路由规则或sshuttle建VPN基本就满足需求了。如果是对安全性要求非常高的场景，还是得采用一套成熟的VPN软件搞定。

## 参考

1. <https://istio.io/zh/docs/setup/kubernetes/additional-setup/mesh-expansion/>
2. https://github.com/rancher/submariner
3. https://github.com/strongswan/strongswan
4. https://sshuttle.readthedocs.io/