---
title: py3_cookbook_notes_01
date: 2017-10-05 12:12:00+08:00
author: 徐新杰
tags:
  - python
categories:
  - python开发
typora-root-url: ../../../static
---

最近在看[Python Cookbook第三版](http://python3-cookbook.readthedocs.io/zh_CN/latest/)，将看书过程中一些平时不太容易注意的知识点记录下来。

## 数据结构和算法

### 解压可迭代对象赋值给多个变量

```python
record = ('Dave', 'dave@example.com', '773-555-1212', '847-555-1212')
name, email, *phone_numbers = record
```

### 保留最后 N 个元素

```python
from collections import deque


def search(lines, pattern, history=5):
    previous_lines = deque(maxlen=history)
    for line in lines:
        if pattern in line:
            yield line, previous_lines
        previous_lines.append(line)

# Example use on a file
if __name__ == '__main__':
    with open(r'../../cookbook/somefile.txt') as f:
        for line, prevlines in search(f, 'python', 5):
            for pline in prevlines:
                print(pline, end='')
            print(line, end='')
            print('-' * 20)
```

### 查找最大或最小的 N 个元素

```python
import heapq
nums = [1, 8, 2, 23, 7, -4, 18, 23, 42, 37, 2]
print(heapq.nlargest(3, nums)) # Prints [42, 37, 23]
print(heapq.nsmallest(3, nums)) # Prints [-4, 1, 2]

portfolio = [
    {'name': 'IBM', 'shares': 100, 'price': 91.1},
    {'name': 'AAPL', 'shares': 50, 'price': 543.22},
    {'name': 'FB', 'shares': 200, 'price': 21.09},
    {'name': 'HPQ', 'shares': 35, 'price': 31.75},
    {'name': 'YHOO', 'shares': 45, 'price': 16.35},
    {'name': 'ACME', 'shares': 75, 'price': 115.65}
]
cheap = heapq.nsmallest(3, portfolio, key=lambda s: s['price'])
expensive = heapq.nlargest(3, portfolio, key=lambda s: s['price'])

nums = [1, 8, 2, 23, 7, -4, 18, 23, 42, 37, 2]
heapq.heapify(nums)
it = iter(lambda:heapq.heappop(nums) if len(nums)>0 else None, None)
for i in it:
	print(i)
```

### 实现一个优先级队列

```python
import heapq

class PriorityQueue:
    def __init__(self):
        self._queue = []
        self._index = 0

    def push(self, item, priority):
        heapq.heappush(self._queue, (-priority, self._index, item))
        self._index += 1

    def pop(self):
        return heapq.heappop(self._queue)[-1]
```

### 字典中的键映射多个值

```python
from collections import defaultdict

d = defaultdict(list)
d['a'].append(1)
d['a'].append(2)
d['b'].append(4)

d = defaultdict(set)
d['a'].add(1)
d['a'].add(2)
d['b'].add(4)
```

### 字典排序

```python
from collections import OrderedDict
d = OrderedDict()
d['foo'] = 1
d['bar'] = 2
d['spam'] = 3
d['grok'] = 4
# Outputs "foo 1", "bar 2", "spam 3", "grok 4"
for key in d:
    print(key, d[key])
```

### 字典的运算

```python
prices = {
    'ACME': 45.23,
    'AAPL': 612.78,
    'IBM': 205.55,
    'HPQ': 37.20,
    'FB': 10.75
}
min_price = min(zip(prices.values(), prices.keys()))
# min_price is (10.75, 'FB')
max_price = max(zip(prices.values(), prices.keys()))
# max_price is (612.78, 'AAPL')
```

### 查找两字典的相同点

```python
a = {
    'x' : 1,
    'y' : 2,
    'z' : 3
}

b = {
    'w' : 10,
    'x' : 11,
    'y' : 2
}

# Find keys in common
a.keys() & b.keys() # { 'x', 'y' }
# Find keys in a that are not in b
a.keys() - b.keys() # { 'z' }
# Find (key,value) pairs in common
a.items() & b.items() # { ('y', 2) }
```

### 删除序列相同元素并保持顺序

```python
def dedupe(items, key=None):
    seen = set()
    for item in items:
        val = item if key is None else key(item)
        if val not in seen:
            yield item
            seen.add(val)

a = [1, 5, 2, 1, 9, 1, 5, 10]
list(dedupe(a))

a = [ {'x':1, 'y':2}, {'x':1, 'y':3}, {'x':1, 'y':2}, {'x':2, 'y':4}]
list(dedupe(a, key=lambda d: (d['x'],d['y'])))
```

### 命名切片

```python
######    0123456789012345678901234567890123456789012345678901234567890'
record = '....................100 .......513.25 ..........'
SHARES = slice(20, 23)
PRICE = slice(31, 37)
cost = int(record[SHARES]) * float(record[PRICE])

a = slice(5, 50, 2)
s = 'HelloWorld'
for i in range(*a.indices(len(s))):
  print(s[i])
```

### 序列中出现次数最多的元素

```python
words = [
    'look', 'into', 'my', 'eyes', 'look', 'into', 'my', 'eyes',
    'the', 'eyes', 'the', 'eyes', 'the', 'eyes', 'not', 'around', 'the',
    'eyes', "don't", 'look', 'around', 'the', 'eyes', 'look', 'into',
    'my', 'eyes', "you're", 'under'
]
from collections import Counter
word_counts = Counter(words)
# 出现频率最高的3个单词
top_three = word_counts.most_common(3)
print(top_three)
# Outputs [('eyes', 8), ('the', 5), ('look', 4)]
```

### 通过某个关键字排序一个字典列表

```python
rows = [
    {'fname': 'Brian', 'lname': 'Jones', 'uid': 1003},
    {'fname': 'David', 'lname': 'Beazley', 'uid': 1002},
    {'fname': 'John', 'lname': 'Cleese', 'uid': 1001},
    {'fname': 'Big', 'lname': 'Jones', 'uid': 1004}
]
from operator import itemgetter
rows_by_fname = sorted(rows, key=itemgetter('fname'))
rows_by_uid = sorted(rows, key=itemgetter('uid'))
print(rows_by_fname)
print(rows_by_uid)
```

### 排序不支持原生比较的对象

```python
class User:
    def __init__(self, user_id):
        self.user_id = user_id

    def __repr__(self):
        return 'User({})'.format(self.user_id)


def sort_notcompare():
    users = [User(23), User(3), User(99)]
    print(users)
    print(sorted(users, key=lambda u: u.user_id))
```

### 通过某个字段将记录分组

```python
rows = [
    {'address': '5412 N CLARK', 'date': '07/01/2012'},
    {'address': '5148 N CLARK', 'date': '07/04/2012'},
    {'address': '5800 E 58TH', 'date': '07/02/2012'},
    {'address': '2122 N CLARK', 'date': '07/03/2012'},
    {'address': '5645 N RAVENSWOOD', 'date': '07/02/2012'},
    {'address': '1060 W ADDISON', 'date': '07/02/2012'},
    {'address': '4801 N BROADWAY', 'date': '07/01/2012'},
    {'address': '1039 W GRANVILLE', 'date': '07/04/2012'},
]
from operator import itemgetter
from itertools import groupby

# Sort by the desired field first
rows.sort(key=itemgetter('date'))
# Iterate in groups
for date, items in groupby(rows, key=itemgetter('date')):
    print(date)
    for i in items:
        print(' ', i)
```

### 映射名称到序列元素

```python
from collections import namedtuple

Subscriber = namedtuple('Subscriber', ['addr', 'joined'])
sub = Subscriber('jonesy@example.com', '2012-10-19')
sub
sub.addr
sub.joined

Stock = namedtuple('Stock', ['name', 'shares', 'price'])
def compute_cost(records):
    total = 0.0
    for rec in records:
        s = Stock(*rec)
        total += s.shares * s.price
    return total
```

### 合并多个字典或映射

```python
a = {'x': 1, 'z': 3 }
b = {'y': 2, 'z': 4 }
from collections import ChainMap
c = ChainMap(a,b)
print(c['x']) # Outputs 1 (from a)
print(c['y']) # Outputs 2 (from b)
print(c['z']) # Outputs 3 (from a)
```

## 字符串和文本

### 使用多个界定符分割字符串

```python
line = 'asdf fjdk; afed, fjek,asdf, foo'
import re
re.split(r'(?:,|;|\s)\s*', line)
```

### 字符串开头或结尾匹配

```python
import os
filenames = os.listdir('.')
(name for name in filenames if name.endswith(('.c', '.h')))
```

### 字符串匹配和搜索

```python
datepat = re.compile(r'(\d+)/(\d+)/(\d+)')
for m in datepat.finditer(text):
	print(m.groups())
```

### 删除字符串中不需要的字符

```python
>>> s = ' hello world \n'
>>> s.strip()
'hello world'
>>> s.lstrip()
'hello world \n'
>>> s.rstrip()
' hello world'
>>>
>>> # Character stripping
>>> t = '-----hello====='
>>> t.lstrip('-')
'hello====='
>>> t.strip('-=')
'hello'
```

### 字符串对齐

```python
>>> text = 'Hello World'
>>> text.ljust(20)
'Hello World         '
>>> text.rjust(20)
'         Hello World'
>>> text.center(20)
'    Hello World     '
>>> text.rjust(20,'=')
'=========Hello World'
>>> text.center(20,'*')
'****Hello World*****'
>>> format(text, '>20')
'         Hello World'
>>> format(text, '<20')
'Hello World         '
>>> format(text, '^20')
'    Hello World     '
>>> format(text, '=>20s')
'=========Hello World'
>>> format(text, '*^20s')
'****Hello World*****'
>>> '{:>10s} {:>10s}'.format('Hello', 'World')
'     Hello      World'
```

### 字符串中插入变量

```python
>>> s = '{name} has {n} messages.'
>>> s.format(name='Guido', n=37)
'Guido has 37 messages.'

class safesub(dict):
  """防止key找不到"""
  def __missing__(self, key):
      return '{' + key + '}'

>>> name = 'Guido'
>>> n = 37
>>> s.format_map(safesub(vars()))
'Guido has 37 messages.'
```

### 以指定列宽格式化字符串

```python
s = "Look into my eyes, look into my eyes, the eyes, the eyes, \
the eyes, not around the eyes, don't look around the eyes, \
look into my eyes, you're under."
import textwrap
print(textwrap.fill(s, 70))

>>> import os
>>> os.get_terminal_size().columns
80
```

### 在字符串中处理html和xml

```python
s = 'Elements are written as "<tag>text</tag>".'
print(html.escape(s, quote=False))

>>> s = 'Spicy &quot;Jalape&#241;o&quot.'
>>> from html.parser import HTMLParser
>>> p = HTMLParser()
>>> p.unescape(s)
'Spicy "Jalapeño".'
>>>
>>> t = 'The prompt is &gt;&gt;&gt;'
>>> from xml.sax.saxutils import unescape
>>> unescape(t)
'The prompt is >>>'
```

## 数字日期和时间

### 执行精确的浮点数运算

```python
>>> from decimal import Decimal
>>> a = Decimal('4.2')
>>> b = Decimal('2.1')
>>> a + b
Decimal('6.3')
>>> print(a + b)
6.3
>>> (a + b) == Decimal('6.3')
True

>>> from decimal import localcontext
>>> a = Decimal('1.3')
>>> b = Decimal('1.7')
>>> print(a / b)
0.7647058823529411764705882353
>>> with localcontext() as ctx:
...     ctx.prec = 3
...     print(a / b)
...
0.765
```

### 数字的格式化输出

```python
>>> x = 1234.56789

>>> # Two decimal places of accuracy
>>> format(x, '0.2f')
'1234.57'

>>> # Right justified in 10 chars, one-digit accuracy
>>> format(x, '>10.1f')
'    1234.6'

>>> # Left justified
>>> format(x, '<10.1f')
'1234.6    '

>>> # Centered
>>> format(x, '^10.1f')
'  1234.6  '

>>> # Inclusion of thousands separator
>>> format(x, ',')
'1,234.56789'
>>> format(x, '0,.1f')
'1,234.6'

>>> format(x, 'e')
'1.234568e+03'
>>> format(x, '0.2E')
'1.23E+03'
```

同时指定宽度和精度的一般形式是 `'[<>^]?width[,]?(.digits)?'` ， 其中 `width` 和 `digits` 为整数，？代表可选部分。 同样的格式也被用在字符串的 `format()` 方法中。

### 基本的日期与时间转换

```python
>>> from datetime import timedelta
>>> a = timedelta(days=2, hours=6)
>>> b = timedelta(hours=4.5)
>>> c = a + b
>>> c.days
2
>>> c.seconds
37800
>>> c.seconds / 3600
10.5
>>> c.total_seconds() / 3600
58.5

>>> from dateutil.relativedelta import relativedelta
>>> a + relativedelta(months=+1)
datetime.datetime(2012, 10, 23, 0, 0)
>>> a + relativedelta(months=+4)
datetime.datetime(2013, 1, 23, 0, 0)
```

### 计算最后一个周五的日期

```python
>>> from datetime import datetime
>>> from dateutil.relativedelta import relativedelta
>>> from dateutil.rrule import *
>>> d = datetime.now()
>>> print(d)
2012-12-23 16:31:52.718111

>>> # Next Friday
>>> print(d + relativedelta(weekday=FR))
2012-12-28 16:31:52.718111
>>>

>>> # Last Friday
>>> print(d + relativedelta(weekday=FR(-1)))
2012-12-21 16:31:52.718111
>>>
```

### 计算当前月份的日期范围

```python
from datetime import datetime, date, timedelta
import calendar

def get_month_range(start_date=None):
    if start_date is None:
        start_date = date.today().replace(day=1)
    _, days_in_month = calendar.monthrange(start_date.year, start_date.month)
    end_date = start_date + timedelta(days=days_in_month)
    return (start_date, end_date)
```

### 字符串转换为日期

```python
>>> from datetime import datetime
>>> text = '2012-09-20'
>>> y = datetime.strptime(text, '%Y-%m-%d')
```

### 结合时区的日期操作

```python
>>> from datetime import datetime
>>> from pytz import timezone
>>> d = datetime(2012, 12, 21, 9, 30, 0)
>>> # Localize the date for Chicago
>>> central = timezone('US/Central')
>>> loc_d = central.localize(d)
>>> print(loc_d)
>>> # Convert to Bangalore time
>>> bang_d = loc_d.astimezone(timezone('Asia/Kolkata'))
>>> print(bang_d)
>>> utc_d = loc_d.astimezone(pytz.utc)
>>> print(utc_d)
```

## 迭代器和生成器

### 手动遍历迭代器

```python
def manual_iter():
    with open('/etc/passwd') as f:
        try:
            while True:
                line = next(f)
                print(line, end='')
        except StopIteration:
            pass
```

### 代理迭代和生成器函数

```python
"""
文件说明 ：演示实现深度优先遍历及广度优先遍历
"""
class Node:
    def __init__(self, value):
        self._value = value
        self._children = []

    def __repr__(self):
        return 'Node{!r}'.format(self._value)

    def add_child(self, node):
        self._children.append(node)

    def __iter__(self):
        return iter(self._children)

    def depth_first(self):
        yield self
        for ch in self:
            yield from ch.depth_first()

    def breadth_first(self):
        stack = [self]
        while stack:
            current = stack.pop(0)
            yield current
            stack.extend(current._children)

if __name__ == '__main__':
    root = Node(0)

    child1 = Node(1)
    child2 = Node(2)

    child3 = Node(3)
    child4 = Node(4)
    child5 = Node(5)
    child6 = Node(6)

    child7 = Node(7)
    child8 = Node(8)
    child9 = Node(9)
    child10 = Node(10)
    child11 = Node(11)
    child12 = Node(12)
    child13 = Node(13)
    child14 = Node(14)

    child3.add_child(child7)
    child3.add_child(child8)
    child5.add_child(child9)
    child5.add_child(child10)
    child4.add_child(child11)
    child4.add_child(child12)
    child6.add_child(child13)
    child6.add_child(child14)

    child1.add_child(child3)
    child1.add_child(child5)
    child2.add_child(child4)
    child2.add_child(child6)

    root.add_child(child1)
    root.add_child(child2)

    for ch in root.depth_first():
        print(ch)

    for ch in root.breadth_first():
        print(ch)
```

### 反向迭代

```python
class Countdown:
    def __init__(self, start):
        self.start = start

    # Forward iterator
    def __iter__(self):
        n = self.start
        while n > 0:
            yield n
            n -= 1

    # Reverse iterator
    def __reversed__(self):
        n = 1
        while n <= self.start:
            yield n
            n += 1

for rr in reversed(Countdown(30)):
    print(rr)
```

### 带有外部状态的生成器函数

```python
from collections import deque

class linehistory:
    def __init__(self, lines, histlen=3):
        self.lines = lines
        self.history = deque(maxlen=histlen)

    def __iter__(self):
        for lineno, line in enumerate(self.lines, 1):
            self.history.append((lineno, line))
            yield line

    def clear(self):
        self.history.clear()
     
with open('somefile.txt') as f:
    lines = linehistory(f)
    for line in lines:
        if 'python' in line:
            for lineno, hline in lines.history:
                print('{}:{}'.format(lineno, hline), end='')
```

### 迭代器切片

```python
>>> def count(n):
...     while True:
...         yield n
...         n += 1
...
>>> c = count(0)
>>> import itertools
>>> for x in itertools.islice(c, 10, 20):
...     print(x)
...
```

### 跳过可迭代对象的开始部分

```python
>>> from itertools import dropwhile
>>> with open('/etc/passwd') as f:
...     for line in dropwhile(lambda line: line.startswith('#'), f):
...         print(line, end='')
...
```

### 序列上索引值迭代

```python
>>> my_list = ['a', 'b', 'c']
>>> for idx, val in enumerate(my_list, 1):
...     print(idx, val)
...
1 a
2 b
3 c
```

### 同时迭代多个序列

```python
>>> xpts = [1, 5, 4, 2, 10, 7]
>>> ypts = [101, 78, 37, 15, 62, 99]
>>> for x, y in zip(xpts, ypts):
...     print(x,y)
...
>>> from itertools import zip_longest
>>> for i in zip_longest(a,b):
...     print(i)
...
```

### 不同集合上元素的迭代

```python
from itertools import chain
import os

def gen_opener(filenames):
    for filename in filenames:
        with open(filename, 'rt') as f:
            yield f

def gen_concatenate(files):
    yield from chain.from_iterable(files)
    # for file in files:
    #     yield from file

files = gen_opener(iter([os.path.expanduser('~/.zshrc'), os.path.expanduser('~/.bash_history')]))
print(files)
lines = gen_concatenate(files)
for line in lines:
    print(line)
```

### 顺序迭代合并后的排序迭代对象

```python
import heapq
with open('sorted_file_1', 'rt') as file1, \
    open('sorted_file_2', 'rt') as file2, \
    open('merged_file', 'wt') as outf:

    for line in heapq.merge(file1, file2):
        outf.write(line)
```

### 迭代器代替while无限循环

```python
>>> import sys
>>> f = open('/etc/passwd')
>>> CHUNKSIZE = 8192
>>> for chunk in iter(lambda: f.read(CHUNKSIZE), b''):
...     n = sys.stdout.write(chunk)
...
```

## 文件和IO

### 打印输出至文件中

```python
with open('d:/work/test.txt', 'wt') as f:
    print('Hello World!', file=f)
```

### 使用其他分隔符或行终止符打印

```python
>>> print('ACME', 50, 91.5)
ACME 50 91.5
>>> print('ACME', 50, 91.5, sep=',')
ACME,50,91.5
>>> print('ACME', 50, 91.5, sep=',', end='!!\n')
ACME,50,91.5!!
>>> row = ('ACME', 50, 91.5)
>>> print(*row, sep=',')
```

### 字符串的I/O操作

```python
>>> s = io.StringIO()
>>> s.write('Hello World\n')
12
>>> print('This is a test', file=s)
15
>>> # Get all of the data written so far
>>> s.getvalue()
'Hello World\nThis is a test\n'
>>>

>>> # Wrap a file interface around an existing string
>>> s = io.StringIO('Hello\nWorld\n')
>>> s.read(4)
'Hell'
>>> s.read()
'o\nWorld\n'
>>>
```

### 固定大小记录的文件迭代

```python
from functools import partial

RECORD_SIZE = 32

with open('somefile.data', 'rb') as f:
    records = iter(partial(f.read, RECORD_SIZE), b'')
    for r in records:
        ...
```

### 读取二进制数据到可变缓冲区中

```python
import os.path

def read_into_buffer(filename):
    buf = bytearray(os.path.getsize(filename))
    with open(filename, 'rb') as f:
        f.readinto(buf)
    return buf
```

### 文件路径名的操作

```python
>>> import os
>>> path = '/Users/beazley/Data/data.csv'

>>> # Get the last component of the path
>>> os.path.basename(path)
'data.csv'

>>> # Get the directory name
>>> os.path.dirname(path)
'/Users/beazley/Data'

>>> # Join path components together
>>> os.path.join('tmp', 'data', os.path.basename(path))
'tmp/data/data.csv'

>>> # Expand the user's home directory
>>> path = '~/Data/data.csv'
>>> os.path.expanduser(path)
'/Users/beazley/Data/data.csv'

>>> # Split the file extension
>>> os.path.splitext(path)
('~/Data/data', '.csv')
>>>
```

### 获取文件夹中的文件列表

```python
import os.path

# Get all regular files
names = [name for name in os.listdir('somedir')
        if os.path.isfile(os.path.join('somedir', name))]

# Get all dirs
dirnames = [name for name in os.listdir('somedir')
        if os.path.isdir(os.path.join('somedir', name))]

import glob
pyfiles = glob.glob('somedir/*.py')

from fnmatch import fnmatch
pyfiles = [name for name in os.listdir('somedir')
            if fnmatch(name, '*.py')]
```

### 打印不合法的文件名

```python
def bad_filename(filename):
    temp = filename.encode(sys.getfilesystemencoding(), errors='surrogateescape')
    return temp.decode('latin-1')

>>> for name in files:
...     try:
...         print(name)
...     except UnicodeEncodeError:
...         print(bad_filename(name))
...
```

### 增加或改变已打开文件的编码

```python
>>> import sys
>>> sys.stdout.encoding
'UTF-8'
>>> sys.stdout = io.TextIOWrapper(sys.stdout.detach(), encoding='latin-1')
>>> sys.stdout.encoding
'latin-1'
>>>
```

### 将文件描述符包装成文件对象

```python
# Open a low-level file descriptor
import os
fd = os.open('somefile.txt', os.O_WRONLY | os.O_CREAT)

# Turn into a proper file
f = open(fd, 'wt')
f.write('hello world\n')
f.close()
```

### 创建临时文件和文件夹

```python
from tempfile import NamedTemporaryFile, TemporaryDirectory
with NamedTemporaryFile('wt', prefix='tmp_', suffix='.txt') as f:
    print(f.name)
    
with TemporaryDirectory(prefix='tmp_dir_') as dir:
    print(dir)
```

### 序列化Python对象

```python
import pickle
data = [1, 2, 3]
with open('somefile', 'wb') as f:
    pickle.dump(data, f)
print(pickle.dumps(data))

# Restore from a file
f = open('somefile', 'rb')
data = pickle.load(f)
# Restore from a string
data = pickle.loads(s)


import time
import threading

class Countdown:
    def __init__(self, n):
        self.n = n
        self.thr = threading.Thread(target=self.run)
        self.thr.daemon = True
        self.thr.start()

    def run(self):
        while self.n > 0:
            print('T-minus', self.n)
            self.n -= 1
            time.sleep(5)

    def __getstate__(self):
        return self.n

    def __setstate__(self, n):
        self.__init__(n)
```

## 数据编码和处理

### 读写CSV数据

```python
import csv
import re
col_types = [str, float, str, str, float, int]
with open('stock.csv') as f:
    f_csv = csv.reader(f)
    headers = [ re.sub('[^a-zA-Z_]', '_', h) for h in next(f_csv) ]
    Row = namedtuple('Row', headers)
    for row in f_csv:
    	# Apply conversions to the row items
        row = Row(convert(value) for convert, value in zip(col_types, row))
        
headers = ['Symbol', 'Price', 'Date', 'Time', 'Change', 'Volume']
rows = [{'Symbol':'AA', 'Price':39.48, 'Date':'6/11/2007',
        'Time':'9:36am', 'Change':-0.18, 'Volume':181800},
        {'Symbol':'AIG', 'Price': 71.38, 'Date':'6/11/2007',
        'Time':'9:36am', 'Change':-0.15, 'Volume': 195500},
        {'Symbol':'AXP', 'Price': 62.58, 'Date':'6/11/2007',
        'Time':'9:36am', 'Change':-0.46, 'Volume': 935000},
        ]

with open('stocks.csv','w') as f:
    f_csv = csv.DictWriter(f, headers)
    f_csv.writeheader()
    f_csv.writerows(rows)
```

### 读写JSON数据

```python
import json

data = {
    'name' : 'ACME',
    'shares' : 100,
    'price' : 542.23
}

json_str = json.dumps(data)
data = json.loads(json_str)

# Writing JSON data
with open('data.json', 'w') as f:
    json.dump(data, f)

# Reading data back
with open('data.json', 'r') as f:
    data = json.load(f)
```

### 解析和修改XML

```python
>>> from xml.etree.ElementTree import parse, Element
>>> doc = parse('pred.xml')
>>> root = doc.getroot()
>>> root
<Element 'stop' at 0x100770cb0>

>>> # Remove a few elements
>>> root.remove(root.find('sri'))
>>> root.remove(root.find('cr'))
>>> # Insert a new element after <nm>...</nm>
>>> root.getchildren().index(root.find('nm'))
1
>>> e = Element('spam')
>>> e.text = 'This is a test'
>>> root.insert(2, e)

>>> # Write back to a file
>>> doc.write('newpred.xml', xml_declaration=True)
>>>
```

### 与关系型数据库的交互

```python
stocks = [
    ('GOOG', 100, 490.1),
    ('AAPL', 50, 545.75),
    ('FB', 150, 7.45),
    ('HPQ', 75, 33.2),
]
>>> import sqlite3
>>> db = sqlite3.connect('database.db')
>>>
>>> c = db.cursor()
>>> c.execute('create table portfolio (symbol text, shares integer, price real)')
<sqlite3.Cursor object at 0x10067a730>
>>> db.commit()
>>>
>>> c.executemany('insert into portfolio values (?,?,?)', stocks)
<sqlite3.Cursor object at 0x10067a730>
>>> db.commit()
>>>
>>> for row in db.execute('select * from portfolio'):
...     print(row)
...
>>> min_price = 100
>>> for row in db.execute('select * from portfolio where price >= ?',
                          (min_price,)):
...     print(row)
...
```

### 编码和解码十六进制数

```python
>>> # Initial byte string
>>> s = b'hello'
>>> # Encode as hex
>>> import binascii
>>> h = binascii.b2a_hex(s)
>>> h
b'68656c6c6f'
>>> # Decode back to bytes
>>> binascii.a2b_hex(h)
b'hello'
>>>
```

### 编码解码Base64数据

```python
>>> # Some byte data
>>> s = b'hello'
>>> import base64

>>> # Encode as Base64
>>> a = base64.b64encode(s)
>>> a
b'aGVsbG8='

>>> # Decode from Base64
>>> base64.b64decode(a)
b'hello'
>>>
```

### 读写二进制数组数据

```python
from struct import Struct
def write_records(records, format, f):
    '''
    Write a sequence of tuples to a binary file of structures.
    '''
    record_struct = Struct(format)
    for r in records:
        f.write(record_struct.pack(*r))

# Example
if __name__ == '__main__':
    records = [ (1, 2.3, 4.5),
                (6, 7.8, 9.0),
                (12, 13.4, 56.7) ]
    with open('data.b', 'wb') as f:
        write_records(records, '<idd', f)

def read_records(format, f):
    record_struct = Struct(format)
    chunks = iter(lambda: f.read(record_struct.size), b'')
    return (record_struct.unpack(chunk) for chunk in chunks)

# Example
if __name__ == '__main__':
    with open('data.b','rb') as f:
        for rec in read_records('<idd', f):
            # Process rec
            ...
```

the first character of the format string can be used to indicate the byte order, size and alignment of the packed data, according to the following table:

| Character | Byte order             | Size     | Alignment |
| --------- | ---------------------- | -------- | --------- |
| `@`       | native                 | native   | native    |
| `=`       | native                 | standard | none      |
| `<`       | little-endian          | standard | none      |
| `>`       | big-endian             | standard | none      |
| `!`       | network (= big-endian) | standard | none      |

If the first character is not one of these, `'@'` is assumed.

Format characters have the following meaning; the conversion between C and Python values should be obvious given their types. The ‘Standard size’ column refers to the size of the packed value in bytes when using standard size; that is, when the format string starts with one of `'<'`, `'>'`, `'!'` or `'='`. When using native size, the size of the packed value is platform-dependent.

| Format | C Type               | Python type       | Standard size | Notes    |
| ------ | -------------------- | ----------------- | ------------- | -------- |
| `x`    | pad byte             | no value          |               |          |
| `c`    | `char`               | bytes of length 1 | 1             |          |
| `b`    | `signed char`        | integer           | 1             | (1),(3)  |
| `B`    | `unsigned char`      | integer           | 1             | (3)      |
| `?`    | `_Bool`              | bool              | 1             | (1)      |
| `h`    | `short`              | integer           | 2             | (3)      |
| `H`    | `unsigned short`     | integer           | 2             | (3)      |
| `i`    | `int`                | integer           | 4             | (3)      |
| `I`    | `unsigned int`       | integer           | 4             | (3)      |
| `l`    | `long`               | integer           | 4             | (3)      |
| `L`    | `unsigned long`      | integer           | 4             | (3)      |
| `q`    | `long long`          | integer           | 8             | (2), (3) |
| `Q`    | `unsigned long long` | integer           | 8             | (2), (3) |
| `n`    | `ssize_t`            | integer           |               | (4)      |
| `N`    | `size_t`             | integer           |               | (4)      |
| `e`    | (7)                  | float             | 2             | (5)      |
| `f`    | `float`              | float             | 4             | (5)      |
| `d`    | `double`             | float             | 8             | (5)      |
| `s`    | `char[]`             | bytes             |               |          |
| `p`    | `char[]`             | bytes             |               |          |
| `P`    | `void *`             | integer           |               | (6)      |

Changed in version 3.3: Added support for the `'n'` and `'N'` formats.

Changed in version 3.6: Added support for the `'e'` format.

### 读取嵌套和可变长二进制数据

```python
polys = [
    [ (1.0, 2.5), (3.5, 4.0), (2.5, 1.5) ],
    [ (7.0, 1.2), (5.1, 3.0), (0.5, 7.5), (0.8, 9.0) ],
    [ (3.4, 6.3), (1.2, 0.5), (4.6, 9.2) ],
]
```

数据要被编码到一个以下列头部开始的二进制文件中去了：

```
+------+--------+------------------------------------+
|Byte  | Type   |  Description                       |
+======+========+====================================+
|0     | int    |  文件代码（0x1234，小端）          |
+------+--------+------------------------------------+
|4     | double |  x 的最小值（小端）                |
+------+--------+------------------------------------+
|12    | double |  y 的最小值（小端）                |
+------+--------+------------------------------------+
|20    | double |  x 的最大值（小端）                |
+------+--------+------------------------------------+
|28    | double |  y 的最大值（小端）                |
+------+--------+------------------------------------+
|36    | int    |  三角形数量（小端）                |
+------+--------+------------------------------------+

```

紧跟着头部是一系列的多边形记录，编码格式如下：

```
+------+--------+-------------------------------------------+
|Byte  | Type   |  Description                              |
+======+========+===========================================+
|0     | int    |  记录长度（N字节）                        |
+------+--------+-------------------------------------------+
|4-N   | Points |  (X,Y) 坐标，以浮点数表示                 |
+------+--------+-------------------------------------------+
```

```python
import struct
import itertools

def write_polys(filename, polys):
    # Determine bounding box
    flattened = list(itertools.chain(*polys))
    min_x = min(x for x, y in flattened)
    max_x = max(x for x, y in flattened)
    min_y = min(y for x, y in flattened)
    max_y = max(y for x, y in flattened)
    with open(filename, 'wb') as f:
        f.write(struct.pack('<iddddi', 0x1234,
                            min_x, min_y,
                            max_x, max_y,
                            len(polys)))
        for poly in polys:
            size = len(poly) * struct.calcsize('<dd')
            f.write(struct.pack('<i', size + 4))
            for pt in poly:
                f.write(struct.pack('<dd', *pt))
                
def read_polys(filename):
    with open(filename, 'rb') as f:
        # Read the header
        header = f.read(40)
        file_code, min_x, min_y, max_x, max_y, num_polys = \
            struct.unpack('<iddddi', header)
        polys = []
        for n in range(num_polys):
            pbytes, = struct.unpack('<i', f.read(4))
            poly = []
            for m in range(pbytes // 16):
                pt = struct.unpack('<dd', f.read(16))
                poly.append(pt)
            polys.append(poly)
    return polys
```
