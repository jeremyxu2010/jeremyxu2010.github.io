---
title: 写py2、py3兼容的代码
date: 2017-11-05 12:12:00+08:00
author: 徐新杰
tags:
  - python
categories:
  - python开发
---

# 写py2、py3兼容的代码

用到一段时间python，之前也重点复习了一次python3。但工作中运行环境是python2.7，于是要求写出py2、py3都兼容的代码。下面将涉及到的几点技巧列举出来以备忘。

## print函数

py3中print语句没有了，取而代之的是print()函数。 Python 2.6与Python 2.7部分地支持这种形式的print语法。因此保险起见，新写的代码都使用print函数。

```python
from __future__ import print_function
print("fish", "panda", sep=', ')
```

## Unicode

Python 2 有 ASCII str() 类型，unicode() 是单独的，不是 byte 类型。

现在， 在 Python 3，我们最终有了 Unicode (utf-8) 字符串，以及一个字节类：byte 和 bytearrays。

由于 Python3.X 源码文件默认使用utf-8编码，这就使得以下代码是合法的：

```
>>> 中国 = 'china' 
>>>print(中国) 
china
```

Python 2.x

```
>>> str = "我爱北京天安门"
>>> str
'\xe6\x88\x91\xe7\x88\xb1\xe5\x8c\x97\xe4\xba\xac\xe5\xa4\xa9\xe5\xae\x89\xe9\x97\xa8'
>>> str = u"我爱北京天安门"
>>> str
u'\u6211\u7231\u5317\u4eac\u5929\u5b89\u95e8'
```

Python 3.x

```
>>> str = "我爱北京天安门"
>>> str
'我爱北京天安门'
```

个人还是喜欢py3的这种明确两种不同类型的方案，因此新写的代码都使用以下方案。

```python
from __future__ import unicode_literals
txt='中国'
>>> txt
u'\u4e2d\u56fd'
>>> type(txt)
<type 'unicode'>
>>> print(txt)
中国
arr=b'abcd'
>>> arr
'abcd'
>>> type(arr)
<type 'str'>
>>> print(arr)
abcd
```

## 除法运算

在python 2.x中/除法就跟我们熟悉的大多数语言，比如Java啊C啊差不多，整数相除的结果是一个整数，把小数部分完全忽略掉，浮点数除法会保留小数点的部分得到一个浮点数的结果。

在python 3.x中/除法不再这么做了，对于整数之间的相除，结果也会是浮点数。

而对于//除法，这种除法叫做floor除法，会对除法的结果自动进行一个floor操作，在python 2.x和python 3.x中是一致的。注意的是floor除法并不是舍弃小数部分，而是执行floor操作，如果要截取小数部分，那么需要使用math模块的trunc函数。

个人还是喜欢py3这种方案，毕竟是从java转过来的，因此新定的代码都使用以下方案。

```python
from __future__ import division
>>> 1/2
0.5
>>> 1//2
0
>>> trunc(1/2)
0
>>> -1//2
-1
>>> trunc(-1/2)
0
```

## 异常

在 Python 3 中处理异常也轻微的改变了，在 Python 3 中我们现在使用 as 作为关键词。

捕获异常的语法由 **except exc, var** 改为 **except exc as var**。

使用语法except (exc1, exc2) as var可以同时捕获多种类别的异常。 Python 2.6已经支持这两种语法。

- 在2.x时代，所有类型的对象都是可以被直接抛出的，在3.x时代，只有继承自BaseException的对象才可以被抛出。
- 2.x raise语句使用逗号将抛出对象类型和参数分开，3.x取消了这种奇葩的写法，直接调用构造函数抛出对象即可。

这里倒没有异议了，本来就常见原来py2那种奇葩写法很奇怪，只使用py3的写法就可以了。

```python
try:
    raise BaseException('fdf')
except BaseException as err:
    print(err)
```

## 八进制字面量表示

八进制数必须写成0o777，原来的形式0777不能用了；二进制必须写成0b111。

新增了一个bin()函数用于将一个整数转换成二进制字串。 Python 2.6已经支持这两种语法。

在Python 3.x中，表示八进制字面量的方式只有一种，就是0o1000。

很简单，只使用py3支持的写法。

## 不等运算符

Python 2.x中不等于有两种写法 != 和 <>。

Python 3.x中去掉了<>, 只有!=一种写法，还好，我从来没有使用<>的习惯。

## 数据类型

- Py3.X去除了long类型，现在只有一种整型——int，但它的行为就像2.X版本的long
- 新增了bytes类型，对应于2.X版本的八位串

这里如果要进行类型判断，优先使用six模块提供的兼容功能。

> - `six.class_types`
>
>   Possible class types. In Python 2, this encompasses old-style and new-style classes. In Python 3, this is just new-styles.
>
>
> - `six.integer_types`
>
>   Possible integer types. In Python 2, this is `long` and `int`, and in Python 3, just `int`.
>
>
> - `six.string_types`
>
>   Possible types for text data. This is [`basestring()`](https://docs.python.org/2/library/functions.html#basestring) in Python 2 and `str` in Python 3.
>
>
> - `six.text_type`
>
>   Type for representing (Unicode) textual data. This is [`unicode()`](https://docs.python.org/2/library/functions.html#unicode) in Python 2 and `str` in Python 3.
>
>
> - `six.binary_type`
>
>   Type for representing binary data. This is `str` in Python 2 and `bytes` in Python 3.

```python
import six

def dispatch_types(value):
    if isinstance(value, six.integer_types):
        handle_integer(value)
    elif isinstance(value, six.class_types):
        handle_class(value)
    elif isinstance(value, six.string_types):
        handle_string(value)
```

## dict的相关方法调整

dict的.keys()、.items 和.values()方法返回迭代器，而之前的iterkeys()等函数都被废弃。同时去掉的还有 dict.has_key()，用 in替代它吧。

这里还是使用six模块提供的兼容功能。

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

## 标准库及函数名称变更

py3重新组织了一些标准库及一些函数，为了保证在py2、py3下代码都工作正常，这里使用six模块提供的兼容功能。

```python
from six.moves.cPickle import loads
```

Supported renames:

| Name                      | Python 2 name                            | Python 3 name                            |
| ------------------------- | ---------------------------------------- | ---------------------------------------- |
| `builtins`                | [`__builtin__`](https://docs.python.org/2/library/__builtin__.html#module-__builtin__) | [`builtins`](https://docs.python.org/3/library/builtins.html#module-builtins) |
| `configparser`            | [`ConfigParser`](https://docs.python.org/2/library/configparser.html#module-ConfigParser) | [`configparser`](https://docs.python.org/3/library/configparser.html#module-configparser) |
| `copyreg`                 | [`copy_reg`](https://docs.python.org/2/library/copy_reg.html#module-copy_reg) | [`copyreg`](https://docs.python.org/3/library/copyreg.html#module-copyreg) |
| `cPickle`                 | [`cPickle`](https://docs.python.org/2/library/pickle.html#module-cPickle) | [`pickle`](https://docs.python.org/3/library/pickle.html#module-pickle) |
| `cStringIO`               | [`cStringIO.StringIO()`](https://docs.python.org/2/library/stringio.html#cStringIO.StringIO) | [`io.StringIO`](https://docs.python.org/3/library/io.html#io.StringIO) |
| `dbm_gnu`                 | `gdbm`                                   | `dbm.gnu`                                |
| `_dummy_thread`           | [`dummy_thread`](https://docs.python.org/2/library/dummy_thread.html#module-dummy_thread) | [`_dummy_thread`](https://docs.python.org/3/library/_dummy_thread.html#module-_dummy_thread) |
| `email_mime_multipart`    | `email.MIMEMultipart`                    | `email.mime.multipart`                   |
| `email_mime_nonmultipart` | `email.MIMENonMultipart`                 | `email.mime.nonmultipart`                |
| `email_mime_text`         | `email.MIMEText`                         | `email.mime.text`                        |
| `email_mime_base`         | `email.MIMEBase`                         | `email.mime.base`                        |
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
| `range`                   | [`xrange()`](https://docs.python.org/2/library/functions.html#xrange) | `range`                                  |
| `reduce`                  | [`reduce()`](https://docs.python.org/2/library/functions.html#reduce) | [`functools.reduce()`](https://docs.python.org/3/library/functools.html#functools.reduce) |
| `reload_module`           | [`reload()`](https://docs.python.org/2/library/functions.html#reload) | [`imp.reload()`](https://docs.python.org/3/library/imp.html#imp.reload), [`importlib.reload()`](https://docs.python.org/3/library/importlib.html#importlib.reload) on Python 3.4+ |
| `reprlib`                 | `repr`                                   | [`reprlib`](https://docs.python.org/3/library/reprlib.html#module-reprlib) |
| `shlex_quote`             | `pipes.quote`                            | `shlex.quote`                            |
| `socketserver`            | [`SocketServer`](https://docs.python.org/2/library/socketserver.html#module-SocketServer) | [`socketserver`](https://docs.python.org/3/library/socketserver.html#module-socketserver) |
| `_thread`                 | [`thread`](https://docs.python.org/2/library/thread.html#module-thread) | [`_thread`](https://docs.python.org/3/library/_thread.html#module-_thread) |
| `tkinter`                 | [`Tkinter`](https://docs.python.org/2/library/tkinter.html#module-Tkinter) | [`tkinter`](https://docs.python.org/3/library/tkinter.html#module-tkinter) |
| `tkinter_dialog`          | `Dialog`                                 | `tkinter.dialog`                         |
| `tkinter_filedialog`      | `FileDialog`                             | `tkinter.FileDialog`                     |
| `tkinter_scrolledtext`    | [`ScrolledText`](https://docs.python.org/2/library/scrolledtext.html#module-ScrolledText) | [`tkinter.scrolledtext`](https://docs.python.org/3/library/tkinter.scrolledtext.html#module-tkinter.scrolledtext) |
| `tkinter_simpledialog`    | `SimpleDialog`                           | `tkinter.simpledialog`                   |
| `tkinter_ttk`             | [`ttk`](https://docs.python.org/2/library/ttk.html#module-ttk) | [`tkinter.ttk`](https://docs.python.org/3/library/tkinter.ttk.html#module-tkinter.ttk) |
| `tkinter_tix`             | [`Tix`](https://docs.python.org/2/library/tix.html#module-Tix) | [`tkinter.tix`](https://docs.python.org/3/library/tkinter.tix.html#module-tkinter.tix) |
| `tkinter_constants`       | `Tkconstants`                            | `tkinter.constants`                      |
| `tkinter_dnd`             | `Tkdnd`                                  | `tkinter.dnd`                            |
| `tkinter_colorchooser`    | `tkColorChooser`                         | `tkinter.colorchooser`                   |
| `tkinter_commondialog`    | `tkCommonDialog`                         | `tkinter.commondialog`                   |
| `tkinter_tkfiledialog`    | `tkFileDialog`                           | `tkinter.filedialog`                     |
| `tkinter_font`            | `tkFont`                                 | `tkinter.font`                           |
| `tkinter_messagebox`      | `tkMessageBox`                           | `tkinter.messagebox`                     |
| `tkinter_tksimpledialog`  | `tkSimpleDialog`                         | `tkinter.simpledialog`                   |
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
| `xrange`                  | [`xrange()`](https://docs.python.org/2/library/functions.html#xrange) | `range`                                  |
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

## 版本指示变量

最后如果在py2、py3下逻辑不一致，可使用版本指示变量。

> - `six.PY2`
>
>   A boolean indicating if the code is running on Python 2.
>
>
> - `six.PY3`
>
>   A boolean indicating if the code is running on Python 3.

```python
import six

if six.PY2:
    # do some thing
    pass
elif six.PY3:
    # do other thing
    pass
```

