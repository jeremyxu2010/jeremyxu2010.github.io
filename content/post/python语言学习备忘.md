---
title: python语言学习备忘
tags:
  - python
  - shadowsocks
categories:
  - python开发
date: 2016-08-21 14:48:00+08:00
---
作为一个有多年Java开发经验的老程序员，最近却被python精练的语法迷住了。同时发现python语言在云计算、系统运维领域确实用得很多，感觉有必要把python这门语言学一学。以下记录了学习过程中的关键点以备忘。

## 语言关键点

* 数字特殊计算符号

```python
print 4**3
print 17//3.0
```

* 复数支持

```python
print 3+4j
print (3+4j).real
print (3+4j).imag
print abs(3+4j)
```

* 字符串

```python
print 'abcdef'
print r'abc\ndef'
print '''abc
def
ghi
'''
print 'abc\
def\
ghi'
'abc'+'def'
'abc'*3
```

* unicode与str之间相互转换

```python
print u'中国'
unicodestr=u'中国'
utf8str=unicodestr.encode('utf-8')
unicodestr2=utf8str.decode('utf-8')
```

* list与slice

```python
list1=[1, 2, 3, 4]
print list1[3]
print list1[1:]
print list1[:3]
print list1[::2]
```

* 流程控制

```python
if a<b:
  print a
elif a==b:
  print a
else:
  print b

list1=[1, 2, 3, 4]
for num in list1:
  print num

for idx in range(len(list1)):
  print idx

for (idx, num) in enumerate(list1):
  print idx, num

for num in list1:
  if num==3:
    break

for num in list1:
  if num==3:
    continue

  print num

while running:
  print 'alive'

if 3==3:
  pass
```

* 函数相关

```python
def fun1(a, b):
  print a+b

def fun2(a, b=4):
  print a+b

def cheeseshop(kind, *arguments, **keywords):
  pass

cheeseshop("Limburger", "It's very runny, sir.",
           "It's really very, VERY runny, sir.",
           shopkeeper='Michael Palin',
           client="John Cleese",
           sketch="Cheese Shop Sketch")

pairs = [(1, 'one'), (2, 'two'), (3, 'three'), (4, 'four')]
pairs.sort(key=lambda pair: pair[1])

def fun3(a, b)
  '''Calculate a+b

  Comment here
  '''
  pass
```

* list作为堆栈

```python
stack=[3, 4, 5]
stack.append(6)
print stack.pop()
```

* 队列

```python
from collections import deque
queue = deque([3, 4, 5])
queue.append(6)
queue.popleft()
```

* filter, map, reduce

```python
filter(lambda x: x%3==0 or x%5==0, range(1, 100))

map(lambda x: x*2, range(1, 10))

reduce(lambda x, y: x+y, range(1, 10))
```

* 列表推导

```python
[num*2 for num in range(1, 10) if num%4!=0]
```

* 删除变量、删除list子项

```python
a=3
b=a
del a

list1=[1,2,3,4,5]
del list1[3]
del list1[:]
```

* tuple元组

```python
t = 12345, 54321, 'hello!'

a, b=b,a
```

* set集合

```python

fruit = set(['apple', 'orange', 'apple', 'pear', 'orange', 'banana'])
print 'orange' in fruit

a={'a', 'b', 'c'}

a = set('abracadabra')
b = set('alacazam')
print a-b
print a|b
print a&b
print a^b
```

* set集合推导式

```python
print {x for x in 'abracadabra' if x not in 'abc'}
```

* dict字典

```python
tel = {'jack': 4098, 'sape': 4139}

dict([('sape', 4139), ('guido', 4127), ('jack', 4098)])

dict(sape=4139, guido=4127, jack=4098)
```

* dict字典推导式

```python
{x: x**2 for x in (2, 4, 6)}
```

* 模块

```python
print __name__
import sys
print sys.path
print sys.argv
```

* 格式化输出

```python
print '%d + %d = %d' % (3, 4, 5) //不建议使用这种旧的语法

print '{} + {} = {}'.format(3, 4, 5)

print '{0} + {1} = {2}'.format(3, 4, 5)

print '{num1} + {num2} = {num3}'.format(num1=3, num2=4, num3=5)

print '{num1:.2f} + {num2:.2f} = {num3:.2f}'.format(num1=3, num2=4, num3=5)

print '{num1:4d} + {num2:4d} = {num3:4d}'.format(num1=3, num2=4, num3=5)

from string import Template
print Template('$who likes $what').substitute(who='tim', what='kung pao')

tel = {'jack': 4098, 'sape': 4139}
print json.dumps(tel, indent=2)
```

* 文件读写

```python
f=open('/somewhere/filename', 'w')

f.read()

for line in f:
  print line,

f.close()
```

* json处理

```python
import json

f=open('/somewhere/filename', 'w')

tel = {'jack': 4098, 'sape': 4139}
json.dumps(tel, f)
f.close()

f=open('/somewhere/filename', 'r')
x=json.load(f)
```

* 异常

```python
try:
  pass
except ValueError as e:
  pass
finally:
  pass

def fun1():
  raise ValueError('something')

class MyError(Exception):
  def __init__(self, value):
    self.value = value
  def __str__(self):
    return repr(self.value)
```

* with语法

```python
with open('/somewhere/filename', r) as f:
  for line in f:
    print line,
```

* 类的定义

```python
class MyClass(BaseClass):

  pubPro=None

  def __init__(self, arg1):
    BaseClass.__init__(self)
    self.arg1 =

  def pubFun1(self, arg1, arg2):
    pass

  def __priFun1(self, arg1):
    pass

cls=MyClass('hello')
print type(cls)
print cls.__class__
```

* 生成器

```python
def reverse(data):
  for index in range(len(data)-1, -1, -1):
    yield data[index]

for char in reverse('golf'):
  print char
```

* 标准库

```python
import os
print os.getcwd()
os.chdir('/somewhere')
os.system('ping -c 4 127.0.0.1')

import shutil
shutil.copyfile('/somewhere/filename', '/anotherwhere/filename')

import glob
print glob.glob('*.py')

import sys
sys.exit(0)
sys.stderr.write('err msg')
sys.stdout.write('output msg')

import re
print re.findall(r'([a-z]+)', 'which foot or hand fell fastest')

import math
math.cos(math.pi / 4.0)
math.log(1024, 2)

import random
random.choise(['apple', 'pear', 'banana'])
random.sample(xrange(100), 10)
random.random()
random.randrange(6)

import urllib2
f=urllib2.urlopen('http://www.baidu.com')
for line in f:
  print line,
f.close()

import smtplib
smtpConn = smtplib.SMTP('stmp.qq.com')
smtpConn.login('username', 'password')
smtpConn.sendmail('fromuser@qq.com', 'touser@qq.com',\
    '''
    some long text
    ''')
smtpConn.quit()

from datetime import date
now = date.today()
time1 = date(2016, 8, 15)
print now.strftime("%m-%d-%y. %d %b %Y is a %A on the %d day of %B.")

range1 = now - time1
print range1.days

import zlib
s = b'witch which has which witches wrist watch'
t = zlib.compress(s)
zlib.decompress(t)

import locale
locale.setlocale(locale.LC_ALL, locale='zh_CN.UTF-8')
locale.getlocale()
locale.getdefaultlocale()

import logging
logging.debug('Debugging information')
logging.info('Informational message')
logging.warning('Warning:config file %s not found', 'server.conf')
logging.error('Error occurred')
logging.critical('Critical error -- shutting down')
```

## 练手

使用编程语言完成一个简单的任务是学习某个语言最快捷的办法，于是我想了一个简单任务：通过抓取页面自动从`ishadowsocks.com`上得到一个shadowsocks服务器的连接信息，并更新本机shadowsocks-libev服务的配置文件，再自动重启shadowsocks-libev服务。如果再配合cron定时执行脚本，基本可以做到免费的翻墙方案。源代码如下：

```python
#!/usr/bin/env python
# coding: utf-8

import urllib
import re
from lxml import etree
import json
import os

# 请求www.ishadowsocks.org服务器, 获取shadowsocks服务器信息
content = ''
f = None
try:
    f = urllib.urlopen('http://www.ishadowsocks.org/')
    content = f.read()
finally:
    if f is not None:
        f.close()

tree = etree.HTML(content)
nodes = tree.xpath('//*[@id="free"]/div/div[2]/div[3]/h4')
addr = ''
port = 0
pwd = ''
method = ''
for node in nodes:
    txt = node.text
    if type(txt) is unicode:
        utf8str = txt.encode('utf-8')
        ret = re.findall(r'^.*服务器地址:(.*)$', utf8str)
        if len(ret) > 0:
            addr = ret[0]
        ret = re.findall(r'^端口:(.*)$', utf8str)
        if len(ret) > 0:
            port = int(ret[0])
        ret = re.findall(r'^.*密码:(.*)$', utf8str)
        if len(ret) > 0:
            pwd = ret[0]
        ret = re.findall(r'^加密方式:(.*)$', utf8str)
        if len(ret) > 0:
            method = ret[0].lower()

# 生成shadowsocks-libev配置文件
config = {
    "server": addr,
    "server_port": port,
    "local_port": 1080,
    "password": pwd,
    "timeout": 600,
    "method": method
}

configstr = json.dumps(config, indent=2)

with open('/tmp/shadowsocks-libev.json', 'w') as f:
    f.write(configstr)
    f.write('\n')

# 重启shadowsocks-libev服务
os.system('launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.shadowsocks-libev.plist')
os.system('launchctl load ~/Library/LaunchAgents/homebrew.mxcl.shadowsocks-libev.plist')
```

## 下一步计划

在kindle上买了本`python cookbook`，下一步计划把这本书先看完。
