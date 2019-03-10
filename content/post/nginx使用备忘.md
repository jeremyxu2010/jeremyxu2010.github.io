---
title: nginx使用备忘
tags:
  - nginx
  - web
categories:
  - devops
date: 2016-05-02 01:35:00+08:00
---
工作中经常要用到nginx，这里将使用nginx最常要用到的技巧记录下来以备忘。

## 安装

在linux或mac下安装nginx还是很简单的，我一般都是直接下载源代码编译安装。这里要注意，configure时它会提示缺少某些开发库，按照它说明的安装上就可以编译了。另外我一般是将nginx的源码目录留下来，以免以后在用的过程中缺少某个module，需要重新编译安装。

```bash
mkdir build/
tar xf nginx-x.y.z.tar.gz -C build/
cd build/nginx-x.y.z
./configure --prefix=/opt/nginx
make && make install
```

## 查看版本信息、启动、停止、检查配置文件、重加载配置、分割日志文件

查看版本信息

```bash
/opt/nginx/sbin/nginx -V
```

启动

```bash
/opt/nginx/sbin/nginx > /dev/null 2>&1 &
```

停止

```bash
/opt/nginx/sbin/nginx -s stop
```

检查配置文件

```bash
/opt/nginx/sbin/nginx -t
```

重加载配置

```bash
/opt/nginx/sbin/nginx -s reload
```

分割日志文件

```bash
mv /opt/nginx/logs/access.log /opt/nginx/logs/access_20160430.log && mv /opt/nginx/logs/error.log /opt/nginx/logs/error_20160430.log
/opt/nginx/sbin/nginx -s reopen
```

当然一般也不会像上面这样启停nginx，一般会用initscripts, 可参考[initscripts](https://www.nginx.com/resources/wiki/start/topics/examples/initscripts/)。日志的滚动也使用logrotate来完成，可参考[使用logrotate管理nginx日志文件](http://linux008.blog.51cto.com/2837805/555829/)

## 配置

配置文件的组成，这里摘录一下nginx官方文档的说明

`nginx consists of modules which are controlled by directives specified in the configuration file. Directives are divided into simple directives and block directives. A simple directive consists of the name and parameters separated by spaces and ends with a semicolon (;). A block directive has the same structure as a simple directive, but instead of the semicolon it ends with a set of additional instructions surrounded by braces ({ and }). If a block directive can have other directives inside braces, it is called a context (examples: events, http, server, and location). Directives placed in the configuration file outside of any contexts are considered to be in the main context. The events and http directives reside in the main context, server in http, and location in server.`

### 常用指令

#### error_log

配置错误日志输出到哪儿及日志的输出级别，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#error_log)

#### events

配置连接如何被处理，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#events)与[这里](http://nginx.org/en/docs/events.html)

#### include

包含其它配置文件，用于有效地分割配置文件，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#include)

#### pid

指定pid文件位置，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#pid)

#### thread_pool

设置线程池，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#thread_pool)

#### user

指定nginx运行时的用户身份，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#user)

#### worker_processes

指定worker进程的数目，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#worker_processes)

#### worker_connections

指定worker进程最大的连接数，详见[这里](http://nginx.org/en/docs/ngx_core_module.html#worker_connections)

#### client_body_buffer_size

指定读取客户端请求体的buffer大小，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#client_body_buffer_size)

#### client_max_body_size

指定可读取客户端请求体的最大大小，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size)

#### client_body_timeout

读取客户端请求体时，多久未传输任何数据，则认为请求超时了，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#client_body_timeout)

#### client_header_buffer_size

指定读取客户端请求头的buffer大小，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#client_header_buffer_size)

#### client_header_timeout

读取客户端请求头时，多久未传输任何数据，则认为请求超时了，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#client_body_timeout)

#### alias

指定location使用的路径，与root类似，但不改变文件的跟路径，仅适用文件系统的路径，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#alias)

#### default_type

指定默认的MIME type，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#default_type)

#### error_page

为错误响应码指定响应客户端的URI，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#error_page)

#### internal

指定某个location仅内部可用，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#internal)

#### limit_except

限制某个location里允许的HTTP方法，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#limit_except)

#### limit_rate

限制响应发回客户端的速度，一般用于限速，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#limit_rate)

#### limit_rate_after

响应发回客户端传输多大之后开始限速，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#limit_rate_after)

#### listen

指定server监听的地址及端口，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#listen)

#### location

指定相对于某个URI的配置，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#location)

`location`的优先级顺序比较复杂，见官方文档的三段话

`A location can either be defined by a prefix string, or by a regular expression. Regular expressions are specified with the preceding “~*” modifier (for case-insensitive matching), or the “~” modifier (for case-sensitive matching). To find location matching a given request, nginx first checks locations defined using the prefix strings (prefix locations). Among them, the location with the longest matching prefix is selected and remembered. Then regular expressions are checked, in the order of their appearance in the configuration file. The search of regular expressions terminates on the first match, and the corresponding configuration is used. If no match with a regular expression is found then the configuration of the prefix location remembered earlier is used.`

`If the longest matching prefix location has the “^~” modifier then regular expressions are not checked.`

`Also, using the “=” modifier it is possible to define an exact match of URI and location. If an exact match is found, the search terminates.`

#### resolver

指定用于查找upstream servers的DNS服务器，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver)

#### root

指定响应请求的根目录，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#root)

#### server

为某个虚拟主机指定配置，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#server)

#### server_name

为虚拟主机指定主机名，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#server_name)

#### tcp_nodelay

是否开启socket的TCP_NODELAY选项，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#tcp_nodelay)

#### try_files

按指定的顺序检查请求的文件是否存在(请求文件的路径是根据root或alias得出的)，如找到，则直接响应请求，否则内部重定向至最后一个参数指定的uri，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#try_files)

#### types

根据文件名的后缀决定输出的MIME type，详见[这里](http://nginx.org/en/docs/http/ngx_http_core_module.html#types)

#### allow

指定允许访问的IP地址或网络，详见[这里](http://nginx.org/en/docs/http/ngx_http_access_module.html#allow)

#### deny

指定拒绝访问的IP地址或网络，详见[这里](http://nginx.org/en/docs/http/ngx_http_access_module.html#deny)

#### autoindex

是否开启列目录输出，详见[这里](http://nginx.org/en/docs/http/ngx_http_autoindex_module.html#autoindex)

#### charset

添加指定的编译至响应头的`Content-Type`属性，详见[这里](http://nginx.org/en/docs/http/ngx_http_charset_module.html#charset)

#### empty_gif

输出一个1x1的透明gif图片，一般为占位图片，详见[这里](http://nginx.org/en/docs/http/ngx_http_empty_gif_module.html#empty_gif)

#### gzip

是否开启gzip响应，详见[这里](http://nginx.org/en/docs/http/ngx_http_gzip_module.html#gzip)

#### gzip_comp_level

设置gzip压缩的级别，级别越高压缩得越小，但越耗cpu，详见[这里](http://nginx.org/en/docs/http/ngx_http_gzip_module.html#gzip_comp_level)

#### gzip_disable

如果`User-Agent`请求头匹配指定的正则表达式，则禁用gzip，详见[这里](http://nginx.org/en/docs/http/ngx_http_gzip_module.html#gzip_disable)

#### gzip_min_length

当响应体超过这个大小才进行gzip压缩，详见[这里](http://nginx.org/en/docs/http/ngx_http_gzip_module.html#gzip_min_length)

#### gzip_types

针对哪些MIME type才进行gzip压缩，详见[这里](http://nginx.org/en/docs/http/ngx_http_gzip_module.html#gzip_types)

#### index

指定哪些文件被作为索引页，详见[这里](http://nginx.org/en/docs/http/ngx_http_index_module.html#index)

#### limit_conn_zone

定义限制连接数的数据区，详见[这里](http://nginx.org/en/docs/http/ngx_http_limit_conn_module.html#limit_conn_zone)

#### limit_conn

定义限制的连接数，详见[这里](http://nginx.org/en/docs/http/ngx_http_limit_conn_module.html#limit_conn)

#### limit_req_zone

定义限制请求数的数据区，详见[这里](http://nginx.org/en/docs/http/ngx_http_limit_req_module.html#limit_req_zone)

#### limit_req

定义限制的请求数，详见[这里](http://nginx.org/en/docs/http/ngx_http_limit_req_module.html#limit_req)

限制请求数的逻辑比较复杂，参见[这里](http://www.cnblogs.com/php5/archive/2012/12/10/2811732.html)

#### access_log

设置访问日志，详见[这里](http://nginx.org/en/docs/http/ngx_http_log_module.html#access_log)

#### log_format

设置日志的格式，详见[这里](http://nginx.org/en/docs/http/ngx_http_log_module.html#log_format)

#### proxy_pass

设置代理的协议及地址，详见[这里](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass)

#### proxy_redirect

设置代理服务器`Location`及`Refresh`响应头里应作的替换，详见[这里](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_redirect)

#### valid_referers

设置合法的`Referer`请求头，详见[这里](http://nginx.org/en/docs/http/ngx_http_referer_module.html#valid_referers)

#### return

停止处理，直接返回响应码至客户端，详见[这里](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#return)

#### if

if判断，详见[这里](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#if)

#### rewrite

重写URL，详见[这里](http://nginx.org/en/docs/http/ngx_http_rewrite_module.html#rewrite)

这里注意重写URL时如果加上flag, 意义不一样。

last相当于重写URL后，该URL重新开始location匹配搜索

break相当于中断在当前location里的rewrite处理

redirect是302临时重定向

permanent是301永久重定向

#### ssl

是否为指定的虚拟主机开启HTTPS协议，详见[这里](http://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl)

#### ssl_certificate

ssl的证书，详见[这里](http://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate)

#### ssl_certificate_key

ssl的私钥文件，详见[这里](http://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate_key)

#### upstream

定义一组upstream servers，详见[这里](http://nginx.org/en/docs/http/ngx_http_upstream_module.html#upstream)


## 示例

nginx官方有一个完整的[示例](http://nginx.org/en/docs/example.html)

其它示例：

虚拟主机的示例

```
http {
 server {
 listen          80;
 server_name     www.domain1.com;
 access_log      logs/domain1.access.log main;
 location / {
 index index.html;
 root  /var/www/domain1.com/htdocs;
 }
 }
 server {
 listen          80;
 server_name     www.domain2.com;
 access_log      logs/domain2.access.log main;
 location / {
 index index.html;
 root  /var/www/domain2.com/htdocs;
 }
 }
}
```

负载均衡的示例

```
http {
 upstream myproject {
 server 127.0.0.1:8000 weight=3;: server 127.0.0.1:8001;
 server 127.0.0.1:8002;
 server 127.0.0.1:8003;
 }

 server {
 listen 80;
 server_name www.domain.com;
 location / {
 proxy_pass http://myproject;
 }
 }
}
```


## 更多

官方完整的[指令列表](http://nginx.org/en/docs/dirindex.html)

官方完整的[变量列表](http://nginx.org/en/docs/varindex.html)

官方完整的[内置模块列表](http://nginx.org/en/docs/)

使用Nginx的X-Accel-Redirect实现下载的[示例](http://tilt.lib.tsinghua.edu.cn/node/753)

使用mod_zip实现打包下载的[示例](https://segmentfault.com/a/1190000000621313)

nginx反向代理WebSockets的[示例](http://www.oschina.net/translate/websocket-nginx)

nginx反向代理WebSockets的[示例](http://www.oschina.net/translate/websocket-nginx)

nginx利用image_filter动态生成缩略图的[示例](http://www.nginx.cn/2160.html)

nginx使用tcp代理实现HA的[示例](http://xiaorui.cc/2015/05/05/%E6%96%B0%E7%89%88nginx1-9%E4%BD%BF%E7%94%A8ngx_stream_core_module%E5%81%9Atcp%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1/)

增强nginx ssl安全性的[教程](https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html)
