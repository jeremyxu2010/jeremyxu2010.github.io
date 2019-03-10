---
title: 使用阿里云API刷新CDN缓存
tags:
  - python
  - virtualenv
  - 阿里云API
categories:
  - devops
date: 2016-08-22 22:45:00+08:00
---
本时工作中经常需要向阿里云环境部署新的版本，部署完毕之后需要到阿里云管理控制台刷新页面的CDN缓存。这个过程中部署部分我现在是使用bash脚本完成的，很方便。但刷新页面CDN缓存一直是手工操作的，每次都要登录进入阿里云管理控制台，很是麻烦。今天突然想到是否可以调用阿里云API完成这个动作了，查一查还真查到了，[链接](https://help.aliyun.com/document_detail/27200.html?spm=5176.doc27247.6.180.XHmbyB)在这里。下面就想办法调用一下这个API。正好最近在学python，而且阿里云API也有python的SDK，就拿到使使。

## 编译python

由于SLES11SP2系统本身所带的python版本比较低，而阿里云依赖的python版本至少要2.7。时为了不影响系统自带的python，这个手工编译python。

```bash
zypper install -y -t pattern Basis-Devel
zypper install -y libbz2-devel readline-devel ncurses-devel libopenssl-devel libxslt-devel
wget https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz
tar zxvf Python-2.7.12.tgz
cd Python-2.7.12
./configure --prefix=/opt/python2.7
make && make installl
```

## 创建virtualenv环境
为了不在全局安装第三方python模块，这里使用virtaulenv构建出一个虚拟环境

```bash
wget https://pypi.python.org/packages/8b/2c/c0d3e47709d0458816167002e1aa3d64d03bdeb2a9d57c5bd18448fd24cd/virtualenv-15.0.3.tar.gz#md5=a5a061ad8a37d973d27eb197d05d99bf
tar zxvf virtualenv-15.0.3.tar.gz
cd virtualenv-15.0.3
/opt/python2.7/bin/python setup.py install
/opt/python2.7/bin/virtualenv /opt/refresh_cdn_cache
source /opt/refresh_cdn_cache/bin/activate
pip install aliyun-python-sdk-cdn
deactivate
```

## 编写调用阿里云API的脚本

将调用api的python脚本放到这个目录

`/opt/refresh_cdn_cache/refresh_cdn_cache.py`

```python
#!/usr/bin/env python

from aliyunsdkcore import client
Client=client.AcsClient('${AccessKey}','${AccessSecret}','cn-hangzhou')

from aliyunsdkcdn.request.v20141111 import RefreshObjectCachesRequest
request = RefreshObjectCachesRequest.RefreshObjectCachesRequest()
request.set_accept_format('json')
request.set_ObjectPath('https://yun.cloudbility.com/\nhttp://yun.cloudbility.com/')
request.set_ObjectType("Directory")

result=Client.do_action(request)

print result
```

## 改造原来的部署脚本

最后在原来的bash部署脚本最后添加一小段脚本如下：

```bash
......
#部署完毕之后，稍等一会儿，然后调用python脚本完成CDN页面缓存的刷新
sleep 15
source /opt/refresh_cdn_cache/bin/activate
python /opt/refresh_cdn_cache/refresh_cdn_cache.py
deactivate
```

## 总结

python配合virtualenv、pip等工具搭建一个独立不受干扰的环境确实很方便。另外这种第三方的API还是使用python这种脚本语言去调用更方便，调试起来还很方便。


