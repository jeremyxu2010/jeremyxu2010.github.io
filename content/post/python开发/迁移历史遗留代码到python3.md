---
title: 迁移历史遗留代码到python3
date: 2020-06-05 12:12:00+08:00
author: Jeremy Xu
tags:
  - python
categories:
  - python开发
typora-root-url: ../../../static
---

为了便于以后维护代码，最近花了些时间将历史遗留代码迁移到python3，整个迁移还是比较顺利的，在做这个的过程中有一些经验，这里记录一下。

## 字面值字符串的编码问题

python2中有一处很恶心的设计，同样声明一个字面值字符串，会产生两种不同的写法，如下：

```python
>>> a = 'abc'
>>> typeof(a) === 'str'
true
>>> a2 = b'abc'
>>> typeof(a2) === 'str'
true

>>> b = u'中国'
>>> typeof(b) === 'unicode'
true
```

字面值字符串中如出现非ascii编码才能表达的字符，则只能使用`u'xxx'`来声明。也就是说python2里的`str`类型代表的是采用某种具体编码格式编码后的二进制字节码，`unicode`类型代表的是还未采用某种具体编码格式编码的统一unicode码序列，而这两种类型的字符串混用经常会报错。

```python
>>> hi = u"今天" + "天气真好"
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
UnicodeDecodeError: 'ascii' codec can't decode byte 0xe5 in position 0: ordinal not in range(128)
```

网上对上述问题的解释都不太清楚，我经过分析终于知道了问题的根因。

首先这里的`"天气真好"`是一个`str`类型的二进制字节码，既然是二进制字节码，那么必然需要使用某种具体的编码格式进行编码，那么python2如何知道用何种编码将字符串`"天气真好"`编码成二进制字节码呢？一般情况下py文件头部会标明源码文件所用的编码（如下如示，如果文件中没标注，则会使用默认的ASCII编码），python就是用这个编码将字面值字符串编码成二进制字节码的。如果文件用的编码与标识的编码不一致，也会导致编码失败。

```
#!/usr/bin/env python
# -*- coding: utf-8 -*-
```

`u"今天"`只是一个统一unicode码序列。这两个类型进行`+`操作，必然先需要转换为相同的类型，这里实际上是将`str`类型的字符串转换为`unicode`类型的。这个转换会将二进制字符码采用某种具体的编码格式解码为统一unicode码序列。采用什么编码格式进行转换呢？实际上python2中是使用从`sys.getdefaultencoding()`得到的编码格式，默认情况下就是`ascii`编码，所以这里会导致解码失败。

代码里出现两种不同类型的字符串会导致很多类似的问题，之前为了规避这些问题将代码中出现的所有字符串都转型为一个类型，于是在代码中写了很多`encode`的代码。

这个问题在python3中有了较好的方案，所有代码中出现的字面值字符串都是统一unicode码序列，其类型为`str`，这个`str`类型与python2中的`str`类型有本质区别，类似于python2中的`unicode`类型。而且python3中`sys.getdefaultencoding()`已经与时俱进地改为了`utf-8`。其实在python2中也可以采用这个方案，那就是使用`from __future__ import unicode_literals`，这个在之前的博文中有提到过，参见[写py2py3兼容的代码](https://jeremyxu2010.github.io/2017/11/%E5%86%99py2py3%E5%85%BC%E5%AE%B9%E7%9A%84%E4%BB%A3%E7%A0%81/)。

知道了上述问题的原因，升级就比较容易处理了：删除原来很多无用的`encode`代码、注释`sys.setdefaultencoding()`相关的代码、代码中不要再使用`u'xxxx'`。

## dict的相关方法调整

dict的.keys()、.items 和.values()方法返回迭代器，而之前的iterkeys()等函数都被废弃。同时去掉的还有 dict.has_key()，用 in替代它。

还可以six模块，它提供兼容API，使得代码可以在python2、python3中运行。

> - `six.iterkeys`(*dictionary*, **\*kwargs*)
>
>   Returns an iterator over *dictionary*‘s keys. This replaces `dictionary.iterkeys()` on Python 2 and `dictionary.keys()` on Python 3. *kwargs* are passed through to the underlying method.
>
>
> - `six.itervalues`(*dictionary*, **\*kwargs*)
>
>   Returns an iterator over *dictionary*‘s values. This replaces `dictionary.itervalues()` on Python 2 and `dictionary.values()` on Python 3. *kwargs* are passed through to the underlying method.
>
>
> - `six.iteritems`(*dictionary*, **\*kwargs*)
>
>   Returns an iterator over *dictionary*‘s items. This replaces `dictionary.iteritems()` on Python 2 and `dictionary.items()` on Python 3. *kwargs* are passed through to the underlying method.
>
>
> - `six.iterlists`(*dictionary*, **\*kwargs*)
>
>   Calls `dictionary.iterlists()` on Python 2 and `dictionary.lists()` on Python 3. No builtin Python mapping type has such a method; this method is intended for use with multi-valued dictionaries like [Werkzeug’s](http://werkzeug.pocoo.org/docs/datastructures/#werkzeug.datastructures.MultiDict).*kwargs* are passed through to the underlying method.
>
>
> - `six.viewkeys`(*dictionary*)
>
>   Return a view over *dictionary*‘s keys. This replaces [`dict.viewkeys()`](https://docs.python.org/2/library/stdtypes.html#dict.viewkeys) on Python 2.7 and [`dict.keys()`](https://docs.python.org/3/library/stdtypes.html#dict.keys) on Python 3.
>
>
> - `six.viewvalues`(*dictionary*)
>
>   Return a view over *dictionary*‘s values. This replaces [`dict.viewvalues()`](https://docs.python.org/2/library/stdtypes.html#dict.viewvalues) on Python 2.7 and [`dict.values()`](https://docs.python.org/3/library/stdtypes.html#dict.values) on Python 3.
>
>
> - `six.viewitems`(*dictionary*)
>
>   Return a view over *dictionary*‘s items. This replaces [`dict.viewitems()`](https://docs.python.org/2/library/stdtypes.html#dict.viewitems) on Python 2.7 and [`dict.items()`](https://docs.python.org/3/library/stdtypes.html#dict.items) on Python 3.

## print函数

py3中print语句没有了，取而代之的是print()函数。 Python 2.6与Python 2.7部分地支持这种形式的print语法。因此保险起见，新写的代码最好都使用print函数。

```python
from __future__ import print_function
print("fish", "panda", sep=', ')
```

## 异常的处理

在 Python 3 中处理异常也轻微的改变了，在 Python 3 中我们现在使用 as 作为关键词。

捕获异常的语法由 **except exc, var** 改为 **except exc as var**。

使用语法except (exc1, exc2) as var可以同时捕获多种类别的异常。 Python 2.6已经支持这两种语法。

- 在2.x时代，所有类型的对象都是可以被直接抛出的，在3.x时代，只有继承自BaseException的对象才可以被抛出。
- 2.x raise语句使用逗号将抛出对象类型和参数分开，3.x取消了这种奇葩的写法，直接调用构造函数抛出对象即可。

这里倒没有异议了，本来原来py2那种奇葩写法很奇怪，基本都只使用的是py3的写法。

```python
try:
    raise BaseException('fdf')
except BaseException as err:
    print(err)
```

## 标准库及函数名称变更

py3重新组织了一些标准库及一些函数，还可以使用six的兼容API保证代码在python2、python3中都正常运行。

```python
from six.moves.cPickle import loads
```

Supported renames:

| Name                      | Python 2 name                                                | Python 3 name                                                |
| ------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `builtins`                | [`__builtin__`](https://docs.python.org/2/library/__builtin__.html#module-__builtin__) | [`builtins`](https://docs.python.org/3/library/builtins.html#module-builtins) |
| `configparser`            | [`ConfigParser`](https://docs.python.org/2/library/configparser.html#module-ConfigParser) | [`configparser`](https://docs.python.org/3/library/configparser.html#module-configparser) |
| `copyreg`                 | [`copy_reg`](https://docs.python.org/2/library/copy_reg.html#module-copy_reg) | [`copyreg`](https://docs.python.org/3/library/copyreg.html#module-copyreg) |
| `cPickle`                 | [`cPickle`](https://docs.python.org/2/library/pickle.html#module-cPickle) | [`pickle`](https://docs.python.org/3/library/pickle.html#module-pickle) |
| `cStringIO`               | [`cStringIO.StringIO()`](https://docs.python.org/2/library/stringio.html#cStringIO.StringIO) | [`io.StringIO`](https://docs.python.org/3/library/io.html#io.StringIO) |
| `dbm_gnu`                 | `gdbm`                                                       | `dbm.gnu`                                                    |
| `_dummy_thread`           | [`dummy_thread`](https://docs.python.org/2/library/dummy_thread.html#module-dummy_thread) | [`_dummy_thread`](https://docs.python.org/3/library/_dummy_thread.html#module-_dummy_thread) |
| `email_mime_multipart`    | `email.MIMEMultipart`                                        | `email.mime.multipart`                                       |
| `email_mime_nonmultipart` | `email.MIMENonMultipart`                                     | `email.mime.nonmultipart`                                    |
| `email_mime_text`         | `email.MIMEText`                                             | `email.mime.text`                                            |
| `email_mime_base`         | `email.MIMEBase`                                             | `email.mime.base`                                            |
| `filter`                  | [`itertools.ifilter()`](https://docs.python.org/2/library/itertools.html#itertools.ifilter) | [`filter()`](https://docs.python.org/3/library/functions.html#filter) |
| `filterfalse`             | [`itertools.ifilterfalse()`](https://docs.python.org/2/library/itertools.html#itertools.ifilterfalse) | [`itertools.filterfalse()`](https://docs.python.org/3/library/itertools.html#itertools.filterfalse) |
| `getcwd`                  | [`os.getcwdu()`](https://docs.python.org/2/library/os.html#os.getcwdu) | [`os.getcwd()`](https://docs.python.org/3/library/os.html#os.getcwd) |
| `getcwdb`                 | [`os.getcwd()`](https://docs.python.org/2/library/os.html#os.getcwd) | [`os.getcwdb()`](https://docs.python.org/3/library/os.html#os.getcwdb) |
| `http_cookiejar`          | [`cookielib`](https://docs.python.org/2/library/cookielib.html#module-cookielib) | [`http.cookiejar`](https://docs.python.org/3/library/http.cookiejar.html#module-http.cookiejar) |
| `http_cookies`            | [`Cookie`](https://docs.python.org/2/library/cookie.html#module-Cookie) | [`http.cookies`](https://docs.python.org/3/library/http.cookies.html#module-http.cookies) |
| `html_entities`           | [`htmlentitydefs`](https://docs.python.org/2/library/htmllib.html#module-htmlentitydefs) | [`html.entities`](https://docs.python.org/3/library/html.entities.html#module-html.entities) |
| `html_parser`             | [`HTMLParser`](https://docs.python.org/2/library/htmlparser.html#module-HTMLParser) | [`html.parser`](https://docs.python.org/3/library/html.parser.html#module-html.parser) |
| `http_client`             | [`httplib`](https://docs.python.org/2/library/httplib.html#module-httplib) | [`http.client`](https://docs.python.org/3/library/http.client.html#module-http.client) |
| `BaseHTTPServer`          | [`BaseHTTPServer`](https://docs.python.org/2/library/basehttpserver.html#module-BaseHTTPServer) | [`http.server`](https://docs.python.org/3/library/http.server.html#module-http.server) |
| `CGIHTTPServer`           | [`CGIHTTPServer`](https://docs.python.org/2/library/cgihttpserver.html#module-CGIHTTPServer) | [`http.server`](https://docs.python.org/3/library/http.server.html#module-http.server) |
| `SimpleHTTPServer`        | [`SimpleHTTPServer`](https://docs.python.org/2/library/simplehttpserver.html#module-SimpleHTTPServer) | [`http.server`](https://docs.python.org/3/library/http.server.html#module-http.server) |
| `input`                   | [`raw_input()`](https://docs.python.org/2/library/functions.html#raw_input) | [`input()`](https://docs.python.org/3/library/functions.html#input) |
| `intern`                  | [`intern()`](https://docs.python.org/2/library/functions.html#intern) | [`sys.intern()`](https://docs.python.org/3/library/sys.html#sys.intern) |
| `map`                     | [`itertools.imap()`](https://docs.python.org/2/library/itertools.html#itertools.imap) | [`map()`](https://docs.python.org/3/library/functions.html#map) |
| `queue`                   | [`Queue`](https://docs.python.org/2/library/queue.html#module-Queue) | [`queue`](https://docs.python.org/3/library/queue.html#module-queue) |
| `range`                   | [`xrange()`](https://docs.python.org/2/library/functions.html#xrange) | `range`                                                      |
| `reduce`                  | [`reduce()`](https://docs.python.org/2/library/functions.html#reduce) | [`functools.reduce()`](https://docs.python.org/3/library/functools.html#functools.reduce) |
| `reload_module`           | [`reload()`](https://docs.python.org/2/library/functions.html#reload) | [`imp.reload()`](https://docs.python.org/3/library/imp.html#imp.reload), [`importlib.reload()`](https://docs.python.org/3/library/importlib.html#importlib.reload) on Python 3.4+ |
| `reprlib`                 | `repr`                                                       | [`reprlib`](https://docs.python.org/3/library/reprlib.html#module-reprlib) |
| `shlex_quote`             | `pipes.quote`                                                | `shlex.quote`                                                |
| `socketserver`            | [`SocketServer`](https://docs.python.org/2/library/socketserver.html#module-SocketServer) | [`socketserver`](https://docs.python.org/3/library/socketserver.html#module-socketserver) |
| `_thread`                 | [`thread`](https://docs.python.org/2/library/thread.html#module-thread) | [`_thread`](https://docs.python.org/3/library/_thread.html#module-_thread) |
| `tkinter`                 | [`Tkinter`](https://docs.python.org/2/library/tkinter.html#module-Tkinter) | [`tkinter`](https://docs.python.org/3/library/tkinter.html#module-tkinter) |
| `tkinter_dialog`          | `Dialog`                                                     | `tkinter.dialog`                                             |
| `tkinter_filedialog`      | `FileDialog`                                                 | `tkinter.FileDialog`                                         |
| `tkinter_scrolledtext`    | [`ScrolledText`](https://docs.python.org/2/library/scrolledtext.html#module-ScrolledText) | [`tkinter.scrolledtext`](https://docs.python.org/3/library/tkinter.scrolledtext.html#module-tkinter.scrolledtext) |
| `tkinter_simpledialog`    | `SimpleDialog`                                               | `tkinter.simpledialog`                                       |
| `tkinter_ttk`             | [`ttk`](https://docs.python.org/2/library/ttk.html#module-ttk) | [`tkinter.ttk`](https://docs.python.org/3/library/tkinter.ttk.html#module-tkinter.ttk) |
| `tkinter_tix`             | [`Tix`](https://docs.python.org/2/library/tix.html#module-Tix) | [`tkinter.tix`](https://docs.python.org/3/library/tkinter.tix.html#module-tkinter.tix) |
| `tkinter_constants`       | `Tkconstants`                                                | `tkinter.constants`                                          |
| `tkinter_dnd`             | `Tkdnd`                                                      | `tkinter.dnd`                                                |
| `tkinter_colorchooser`    | `tkColorChooser`                                             | `tkinter.colorchooser`                                       |
| `tkinter_commondialog`    | `tkCommonDialog`                                             | `tkinter.commondialog`                                       |
| `tkinter_tkfiledialog`    | `tkFileDialog`                                               | `tkinter.filedialog`                                         |
| `tkinter_font`            | `tkFont`                                                     | `tkinter.font`                                               |
| `tkinter_messagebox`      | `tkMessageBox`                                               | `tkinter.messagebox`                                         |
| `tkinter_tksimpledialog`  | `tkSimpleDialog`                                             | `tkinter.simpledialog`                                       |
| `urllib.parse`            | See [`six.moves.urllib.parse`](http://pythonhosted.org/six/#module-six.moves.urllib.parse) | [`urllib.parse`](https://docs.python.org/3/library/urllib.parse.html#module-urllib.parse) |
| `urllib.error`            | See [`six.moves.urllib.error`](http://pythonhosted.org/six/#module-six.moves.urllib.error) | [`urllib.error`](https://docs.python.org/3/library/urllib.error.html#module-urllib.error) |
| `urllib.request`          | See [`six.moves.urllib.request`](http://pythonhosted.org/six/#module-six.moves.urllib.request) | [`urllib.request`](https://docs.python.org/3/library/urllib.request.html#module-urllib.request) |
| `urllib.response`         | See [`six.moves.urllib.response`](http://pythonhosted.org/six/#module-six.moves.urllib.response) | [`urllib.response`](https://docs.python.org/3/library/urllib.request.html#module-urllib.response) |
| `urllib.robotparser`      | [`robotparser`](https://docs.python.org/2/library/robotparser.html#module-robotparser) | [`urllib.robotparser`](https://docs.python.org/3/library/urllib.robotparser.html#module-urllib.robotparser) |
| `urllib_robotparser`      | [`robotparser`](https://docs.python.org/2/library/robotparser.html#module-robotparser) | [`urllib.robotparser`](https://docs.python.org/3/library/urllib.robotparser.html#module-urllib.robotparser) |
| `UserDict`                | [`UserDict.UserDict`](https://docs.python.org/2/library/userdict.html#UserDict.UserDict) | [`collections.UserDict`](https://docs.python.org/3/library/collections.html#collections.UserDict) |
| `UserList`                | [`UserList.UserList`](https://docs.python.org/2/library/userdict.html#UserList.UserList) | [`collections.UserList`](https://docs.python.org/3/library/collections.html#collections.UserList) |
| `UserString`              | [`UserString.UserString`](https://docs.python.org/2/library/userdict.html#UserString.UserString) | [`collections.UserString`](https://docs.python.org/3/library/collections.html#collections.UserString) |
| `winreg`                  | [`_winreg`](https://docs.python.org/2/library/_winreg.html#module-_winreg) | [`winreg`](https://docs.python.org/3/library/winreg.html#module-winreg) |
| `xmlrpc_client`           | [`xmlrpclib`](https://docs.python.org/2/library/xmlrpclib.html#module-xmlrpclib) | [`xmlrpc.client`](https://docs.python.org/3/library/xmlrpc.client.html#module-xmlrpc.client) |
| `xmlrpc_server`           | [`SimpleXMLRPCServer`](https://docs.python.org/2/library/simplexmlrpcserver.html#module-SimpleXMLRPCServer) | [`xmlrpc.server`](https://docs.python.org/3/library/xmlrpc.server.html#module-xmlrpc.server) |
| `xrange`                  | [`xrange()`](https://docs.python.org/2/library/functions.html#xrange) | `range`                                                      |
| `zip`                     | [`itertools.izip()`](https://docs.python.org/2/library/itertools.html#itertools.izip) | [`zip()`](https://docs.python.org/3/library/functions.html#zip) |
| `zip_longest`             | [`itertools.izip_longest()`](https://docs.python.org/2/library/itertools.html#itertools.izip_longest) | [`itertools.zip_longest()`](https://docs.python.org/3/library/itertools.html#itertools.zip_longest) |

这里用得比较多的是：

```python
import six.moves.configparser
import six.moves.cPickle
import six.moves.cStringIO
import six.moves.filter
import six.moves.filterfalse
import six.moves.getcwd
import six.moves.http_cookies
import six.moves.html_entities
import six.moves.html_parser
import six.moves.http_client
import six.moves.BaseHTTPServer
import six.moves.CGIHTTPServer
import six.moves.SimpleHTTPServer
import six.moves.input
import six.moves.map
import six.moves.queue
import six.moves.range
import six.moves.reduce
import six.moves.socketserver
import six.moves.zip
import six.moves.zip_longest
import six.moves.urllib.parse
import six.moves.urllib.error
import six.moves.urllib.request
import six.moves.urllib.response
```

只有按这个方案导入其它模块，即可保证在py2、py3下都可正确导入模块，详细可参看[six模块的文档](http://pythonhosted.org/six/#module-six.moves)。

## 类的比较特性

在python2中，如果要为某类添加比较特性，只需要为该类添加`__cmp__`方法就可以了。

```python
class Person(object):
    def __init__(self, firstname, lastname):
         self.first = firstname
         self.last = lastname

    def __cmp__(self, other):
        return cmp((self.last, self.first), (other.last, other.first))

    def __repr__(self):
        return "%s %s" % (self.first, self.last)
```

在python3中推荐使用`total_ordering`这个decorator，并添加三个方法`__eq__`、`__ne__`、`__lt__`。

```python
from functools import total_ordering

@total_ordering
class Person(object):

    def __init__(self, firstname, lastname):
        self.first = firstname
        self.last = lastname

    def __eq__(self, other):
        return ((self.last, self.first) == (other.last, other.first))

    def __ne__(self, other):
        return not (self == other)

    def __lt__(self, other):
        return ((self.last, self.first) < (other.last, other.first))

    def __repr__(self):
        return "%s %s" % (self.first, self.last)
```

python3中删除了`cmp`函数，可以很方便地补一个。

```python
def cmp(x, y):
    """
    Replacement for built-in function cmp that was removed in Python 3

    Compare the two objects x and y and return an integer according to
    the outcome. The return value is negative if x < y, zero if x == y
    and strictly positive if x > y.
    """

    return (x > y) - (x < y)
```

## 排序函数相关

在python2中，`.sort()` or `sorted()` 函数有一个 `cmp`参数，这个参数决定了排序。

```python
>>> def cmp_last_name(a, b):
...     """ Compare names by last name"""
...     return cmp(a.last, b.last)
...
>>> sorted(actors, cmp=cmp_last_name)
['John Cleese', 'Terry Gilliam', 'Eric Idle', 'Terry Jones', 'Michael Palin']
```

在python3中，排序函数只有一个 `key`参数，这个参数指定的函数直接返回用于进行排序的键值。

```python
>>> def keyfunction(item):
...     """Key for comparison by last name"""
...     return item.last
...
>>> sorted(actors, key=keyfunction)
['John Cleese', 'Terry Gilliam', 'Eric Idle', 'Terry Jones', 'Michael Palin']
```

本次迁移大概就遇到上述这些问题。

其实还有一个办法搞定历史遗留代码迁移，那就是直接使用python3运行脚本代码，遇报错则在[ Conservative Python 3 Porting Guide](https://portingguide.readthedocs.io/en/latest/index.html)中查找相关事项，并根据建议作相应改动。

The End！

## 参考

1. https://portingguide.readthedocs.io/en/latest/process.html
2. https://jeremyxu2010.github.io/2017/11/%E5%86%99py2py3%E5%85%BC%E5%AE%B9%E7%9A%84%E4%BB%A3%E7%A0%81/