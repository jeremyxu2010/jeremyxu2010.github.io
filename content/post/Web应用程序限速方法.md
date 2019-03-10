---
title: Web应用程序限速方法
tags:
  - java
  - nginx
  - guava
categories:
  - devops
date: 2016-05-09 00:15:00+08:00
---
一般来说Web应用程序的开发者不太关心网络限速的问题。所以通常写的程序逻辑基本认为用户提交上来的数据速率越快越好；用户下载文件时，下载越快越好。但现实情况是服务器的带宽不是无限的，通常我们并不希望某一个用户的极速下载导致其它用户感觉此Web应用程序不可用。这样就带来了网络速率的需求。我在实际工作中大概总结出好几种限速办法，在这里记录以备忘。

## ngx_http_core_module限制下载速率

最简单是直接使用`ngx_http_core_module`中的`limit_rate`、`limit_rate_after`指令，如下

```
location /flv/ {
    alias /www/flv/;
    limit_rate_after 500k;
    limit_rate       50k;
}
```

`limit_rate`可限制响应传输至浏览器客户端的速率，`limit_rate_after`表示浏览器客户端下载多少后才可以执行限速(使下载小文件不受限，下载大文件才限速)。

`limit_rate`还有一种配合后端被代理服务器的用户，如下

```
location /download/ {
    proxy_pass http://127.0.0.1:8080/download/; # proxied server return "X-Accel-Limit-Rate" response header
}
```

后端被代理服务器可返回`X-Accel-Limit-Rate`响应头，nginx将根据这个响应头设置的值进行限速。这样就可以灵活控制限速的逻辑（比如有些用户下载不限速，有些用户下载限速，而且限速的数值也可根据不同用户身份而不同）

## nginx-upload-module限制上传速率

```
location /upload {
        # 转到后台处理URL,表示Nginx接收完上传的文件后，然后交给后端处理的地址
        upload_pass @backend;

        # 临时保存路径, 可以使用散列
        # 上传模块接收到的文件临时存放的路径， 1 表示方式，该方式是需要在/tmp/nginx_upload下创建以0到9为目录名称的目录，上传时候会进行一个散列处理。
        upload_store /tmp/nginx_upload;

        # 上传文件的权限，rw表示读写 r只读
        upload_store_access user:rw group:rw all:rw;

        set $upload_field_name "file";
        # upload_resumable on;

        # 这里写入http报头，pass到后台页面后能获取这里set的报头字段
        upload_set_form_field "${upload_field_name}_name" $upload_file_name;
        upload_set_form_field "${upload_field_name}_content_type" $upload_content_type;
        upload_set_form_field "${upload_field_name}_path" $upload_tmp_path;

        # Upload模块自动生成的一些信息，如文件大小与文件md5值
        upload_aggregate_form_field "${upload_field_name}_md5" $upload_file_md5;
        upload_aggregate_form_field "${upload_field_name}_size" $upload_file_size;

        # 允许的字段，允许全部可以 "^.*$"
        upload_pass_form_field "^.*$";
        # upload_pass_form_field "^submit$|^description$";

        # 每秒字节速度控制，0表示不受控制，默认0, 128K
        upload_limit_rate 0;

        # 如果pass页面是以下状态码，就删除此次上传的临时文件
        upload_cleanup 400 404 499 500-505;

        # 打开开关，意思就是把前端脚本请求的参数会传给后端的脚本语言，比如：http://192.168.1.251:9000/upload/?k=23,后台可以通过POST['k']来访问。
        upload_pass_args on;
    }

    location @backend {
        proxy_pass http://127.0.0.1:8080/process_upload;
    }
```

`upload_limit_rate`即可对上传速率进行限制。

## ngx_stream_proxy_module限制上传下载速率

```
server {
    listen 81;
    proxy_pass 127.0.0.1:8081;
    proxy_download_rate 200k;
    proxy_upload_rate 200k;
}
```

使用`ngx_stream_proxy_module`的好处时只要是tcp或udp协议且使用nginx作反向代理，都可以限速。`proxy_download_rate`可限制下载速率，`proxy_upload_rate`可限制上传速率。

## Java使用Guava的RateLimiter进行限速

上面说的全是使用nginx配置的方式进行限速，当有很特殊需求时，我们也可以使用程序来限速，如Java可使用`Guava`的`RateLimiter`进行限速。

RateLimiter 从概念上来讲，速率限制器会在可配置的速率下分配许可证。如果必要的话，每个acquire() 会阻塞当前线程直到许可证可用后获取该许可证。一旦获取到许可证，不需要再释放许可证。

RateLimiter使用的是一种叫令牌桶的流控算法，RateLimiter会按照一定的频率往桶里扔令牌，线程拿到令牌才能执行，比如你希望自己的应用程序QPS不要超过1000，那么RateLimiter设置1000的速率后，就会每秒往桶里扔1000个令牌。（这个跟nginx的ngx_http_limit_req_module中用到的`leaky bucket`是一个意思）

RateLimiter经常用于限制对一些物理资源或者逻辑资源的访问速率。与Semaphore 相比，Semaphore 限制了并发访问的数量而不是使用速率。

### RateLimiter几个关键的方法

* static RateLimiter create(double permitsPerSecond) 根据指定的稳定吞吐率创建RateLimiter，这里的吞吐率是指每秒多少许可数（通常是指QPS，每秒多少查询）
* static RateLimiter create(double permitsPerSecond, long warmupPeriod, TimeUnit unit) 根据指定的稳定吞吐率和预热期来创建RateLimiter，这里的吞吐率是指每秒多少许可数（通常是指QPS，每秒多少个请求量），在这段预热时间内，RateLimiter每秒分配的许可数会平稳地增长直到预热期结束时达到其最大速率。（只要存在足够请求数来使其饱和）
* double acquire(int permits) 从RateLimiter获取指定许可数，该方法会被阻塞直到获取到请求
* void setRate(double permitsPerSecond) 动态更新RateLimite的稳定速率，参数permitsPerSecond 由构造RateLimiter的工厂方法提供。
* boolean tryAcquire(int permits) 从RateLimiter 获取许可数，如果该许可数可以在无延迟下的情况下立即获取得到的话
* boolean tryAcquire(int permits, long timeout, TimeUnit unit) 从RateLimiter 获取指定许可数如果该许可数可以在不超过timeout的时间内获取得到的话，或者如果无法在timeout 过期之前获取得到许可数的话，那么立即返回false （无需等待）

### 使用示例

限制写入response的速率不超过200kB/s

```java
RateLimiter limiter = RateLimiter.create(1024*200);
while(....){
  byte[] bytes = ...
  limiter.acquire(bytes.length);
  response.getWriter().write(bytes);
}
```


