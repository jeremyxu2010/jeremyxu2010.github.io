---
title: MAC翻墙简易教程
categories:
  - 工具
tags:
  - linux
  - fuckgfw
date: 2016-04-10 13:26:00+08:00
---
## 买一个国外的VPS主机

我是在[digitalocean.com](https://www.digitalocean.com/)上买的，选的操作系统为CentOS 7

## 服务端操作

### 启用TCP BBR

```bash
yum upgrade -y
wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh # 这里会重启服务器
```

### 系统参数优化

```bash
tee /etc/sysctl.conf << EOF
# max open files
fs.file-max = 1024000
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096

# resist SYN flood attacks
net.ipv4.tcp_syncookies = 1
# reuse timewait sockets when safe
net.ipv4.tcp_tw_reuse = 1
# turn off fast timewait sockets recycling
net.ipv4.tcp_tw_recycle = 0
# short FIN timeout
net.ipv4.tcp_fin_timeout = 30
# short keepalive time
net.ipv4.tcp_keepalive_time = 1200
# outbound port range
net.ipv4.ip_local_port_range = 10000 65000
# max SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096
# max timewait sockets held by system simultaneously
net.ipv4.tcp_max_tw_buckets = 5000
# TCP receive buffer
net.ipv4.tcp_rmem = 4096 87380 67108864
# TCP write buffer
net.ipv4.tcp_wmem = 4096 65536 67108864
# turn on path MTU discovery
net.ipv4.tcp_mtu_probing = 1
EOF
sysctl -p

ulimit -SHn 1024000
tee -a /etc/security/limits.conf << EOF
*               soft    nofile           512000
*               hard    nofile          1024000
EOF
tee -a /etc/profile << EOF
ulimit -SHn 1024000
EOF
```

### 安装shadowsocks-libev服务端并启动

```bash
wget -q -O /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo
yum install -y mbedtls libsodium mbedtls-devel libsodium-devel gettext gcc autoconf libtool automake make asciidoc xmlto c-ares-devel libev-devel pcre-devel
wget -q -O shadowsocks-libev-3.1.3.tar.gz https://github.com/shadowsocks/shadowsocks-libev/releases/download/v3.1.3/shadowsocks-libev-3.1.3.tar.gz
tar xf shadowsocks-libev-3.1.3.tar.gz
pushd shadowsocks-libev-3.1.3 &> /dev/null
./configure && make && make install
popd  &> /dev/null
tee /etc/shadowsocks-libev/config.json << EOF
{
    "server":"0.0.0.0",
    "server_port":443,
    "password":"yourpassword",
    "timeout":600,
    "method":"chacha20"
}
EOF
tee /etc/systemd/system/shadowsocks-libev.service << EOF
[Unit]
Description=shadowsocks-libev

[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks-libev/config.json

[Install]
WantedBy=multi-user.target
EOF
systemctl enable shadowsocks-libev
systemctl restart shadowsocks-libev
```

## 客户端操作

### 在MAC上安装shadowsocks客户端并启动

```bash
brew install shadowsocks-libev
tee /usr/local/etc/shadowsocks-libev.json << EOF
{
    "server":"yourserverip",
    "server_port":443,
    "local_address": "0.0.0.0",
    "local_port":1080,
    "password":"yourpassword",
    "timeout":600,
    "method":"chacha20"
}
EOF
brew services restart shadowsocks-libev #启动客户端
```
现在本机上就有翻墙的SOCKS5代理，地址为`127.0.0.1:1080`

### 安装privoxy

有很多程序本身不支持SOCKS5代理，但支持HTTP代理，这里使用privoxy将SOCKS5代理转成HTTP代理，并根据actionsfile规则自动决定是否使用SOCKS5代理
```bash
brew install privoxy python@2
tee -a /usr/local/etc/privoxy/config << EOF
listen-address  0.0.0.0:8118
actionsfile gfwlist.action
EOF
pip2 install gfwlist2privoxy # 安装gfwlist2privoxy
# 下面两个网站虽然不在gfwlist.txt列表里，但希望走SOCKS5代理
tee user_rule.txt << EOF
!this is a user defined rule
.google.com.hk
.privoxy.org
EOF
SOCKS_PROXY=127.0.0.1:1080
curl -s --socks5 $SOCKS_PROXY -o gfwlist.txt 'https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt'
python2 -m gfwlist2privoxy.main -i gfwlist.txt -f /usr/local/etc/privoxy/gfwlist.action -p $SOCKS_PROXY -t socks5 --user-rule user_rule.txt # 使用gfwlist2privoxy生成gfwlist.action文件，gfwlist.action文件很好理解，里面全部是需要走SOCKS5代理的域名列表，可根据需求自行编辑，编辑完毕之后重启privoxy即可生效
brew services restart privoxy #启动privoxy
```
现在本机上就有自动翻墙的HTTP代理，地址为127.0.0.1:8118

### MAC系统全局使用HTTP代理

接下来在”系统偏好设置“-”网络“-”高级“-”代理“里设置，将`Web Proxy`和`Secure Web Proxy`都设置为`127.0.0.1:8118`

### 命令行中翻墙

```bash
echo '
alias proxy_on="export http_proxy=http://127.0.0.1:8118;export https_proxy=http://127.0.0.1:8118;"
alias proxy_off="unset http_proxy;unset https_proxy;"
' >> ~/.zshrc
```
以后执行命令如果需要用翻墙，则在执行前执行proxy_on, 执行命令结束后执行proxy_off

### 避免DNS污染

```bash
brew install pcap_dnsproxy
vim /usr/local/etc/pcap_DNSproxy/Config.ini
[Listen]
Operation Mode = Proxy
[Local DNS]
Local Main = 1
Local Routing = 1
[Proxy]
SOCKS Proxy = 1
SOCKS IPv4 Address = 127.0.0.1:1080
```

修改 Operation Mode 为Proxy以确保其只为本机提供代理域名解析请求服务，修改 Local Main、Local Routing 为1以确保国内网站获得更好的 DNS 解析结果。修改SOCKS Proxy为以SocksV5代理进行DNS请求。

设置pcap_DNSproxy开机自启

```bash
sudo cp -fv /usr/local/opt/pcap_dnsproxy/*.plist /Library/LaunchDaemons
sudo chown root /Library/LaunchDaemons/homebrew.mxcl.pcap_dnsproxy.plist
sudo  launchctl load /Library/LaunchDaemons/homebrew.mxcl.pcap_dnsproxy.plist
```

进入系统偏好设置 - 网络 - 高级 - DNS，将 DNS 服务器设置为 127.0.0.1 即可

## 参考

1. https://teddysun.com/489.html
2. https://github.com/iMeiji/shadowsocks_install/wiki/shadowsocks-optimize
3. https://github.com/snachx/gfwlist2privoxy
4. http://cckpg.blogspot.com/2011/06/privoxy.html
