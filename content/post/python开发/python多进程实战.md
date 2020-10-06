---
title: python多进程实战
date: 2020-09-27 18:12:00+08:00
tags:
  - python
  - multiprocessing
categories:
  - python开发
---

最近花了很多精力写一个业务算法，编写这个算法涉及很多业务逻辑，这里不表。算法涉及的业务逻辑都书写完毕后，发现python程序并不能很好地利用硬件的多核性能。由于这是一个cpu密集的的程序，很自然要用上python的[multiprocessing](https://docs.python.org/3/library/multiprocessing.html)模块，在用这个python模块的时候发现一些有意思的东东。

## multiprocessing启动子进程

python3中支持三种方式启动多进程：`spawn`、`fork`、`forkserver`。

> *spawn*
>
> The parent process starts a fresh python interpreter process. The child process will only inherit those resources necessary to run the process objects [`run()`](https://docs.python.org/3/library/multiprocessing.html#multiprocessing.Process.run) method. In particular, unnecessary file descriptors and handles from the parent process will not be inherited. Starting a process using this method is rather slow compared to using *fork* or *forkserver*.
>
> Available on Unix and Windows. The default on Windows and macOS.
>
> *fork*
>
> The parent process uses [`os.fork()`](https://docs.python.org/3/library/os.html#os.fork) to fork the Python interpreter. The child process, when it begins, is effectively identical to the parent process. All resources of the parent are inherited by the child process. Note that safely forking a multithreaded process is problematic.
>
> Available on Unix only. The default on Unix.
>
> *forkserver*
>
> When the program starts and selects the *forkserver* start method, a server process is started. From then on, whenever a new process is needed, the parent process connects to the server and requests that it fork a new process. The fork server process is single threaded so it is safe for it to use [`os.fork()`](https://docs.python.org/3/library/os.html#os.fork). No unnecessary resources are inherited.
>
> Available on Unix platforms which support passing file descriptors over Unix pipes.

这3种方式启动子进程的方式上面说得比较清楚了。

总结下来就是：

1. spawn是启动一个全新的python解释器进程，这个进程不继承父进程的任何不必要的文件描述符或其它资源。
2. fork是使用`os.fork()`系统调用启动一个python解释器进程，因为是fork调用，这个启动的进程可以继承父进程中的资源。fork出的子进程虽然与父进程是不同的内存空间，但在linux下它是的copy-on-write方式实现的，因此即使创建了很多子进程，实际上看子进程并不会消耗多少内存。看起来fork方式创建子进程很好，但实际上还是存在一些问题的。如果父进程是一个多线程程序，用fork系统调用是很危险的，很容易造成死锁，详见[这里](https://pythonspeed.com/articles/python-multiprocessing/)。
3. 但fork系统调用又确实是启动子进程最高效的方法，于是官方又提供`forkserver`。当父进程需要启动子进程时，实际上是向一个`Fork Server`进程发指令，由它调用`os.fork()`产生子进程的。这个`Fork Server`进程是一个单线程进程，因此调用fork不会产生风险。`forkserver`的实现方式也挺有意思的，代码不长，源码在这里，[multiprocessing/forkserver.py](https://github.com/python/cpython/blob/master/Lib/multiprocessing/forkserver.py)。

不同的操作系统下默认的子进程启动方式是不一样的，目前有两种方式改变使用的启动子进程方式。

1. 通过`multiprocessing.set_start_method`方法全局改变。

   ```python
   import multiprocessing as mp
   
   if __name__ == '__main__':
       mp.set_start_method('spawn')
   ```

2. 通过`multiprocessing.get_context`方法得到一个上下文对象，通过此上下文对象创建的多进程相关对象将使用特定的子进程启动方式。

   ```python
   import multiprocessing as mp
   
   def foo(q):
       q.put('hello')
   
   if __name__ == '__main__':
       ctx = mp.get_context('spawn')
       q = ctx.Queue()
       p = ctx.Process(target=foo, args=(q,))
   ```

## 多进程间交换对象

`multiprocessing`库提供了两种方式交换对象：`Pipe`、`Queue`。

这里其实都是用进程间最原始的通信方式`Pipe`。`Pipe`的使用方法如下：

```python
from multiprocessing import Process, Pipe

def f(conn):
    conn.send([42, None, 'hello'])
    conn.close()

if __name__ == '__main__':
    parent_conn, child_conn = Pipe()
    p = Process(target=f, args=(child_conn,))
    p.start()
    print(parent_conn.recv())   # prints "[42, None, 'hello']"
    p.join()
```

调用`Pipe()`方法会返回一对connection对象，这两个connection对象一个用于读，一个用于写。

`Queue`的实现其实底层还是使用了`Pipe`、`Lock`和`Thread`。`Queue`的实现逻辑也挺有意思的，组合使用了`Pipe`、`Lock`和`Thread`，在首次向队列中写入一个对象时，会启动一个线程持续地将写进buffer里的对象刷进`Pipe`，当然为了实现队列的相关特性，也组合使用了基于操作系统信号量的`Lock`，`Queue`的代码也不多，源码在这里[multiprocessing/queues.py](multiprocessing/queues.py)。

## 多进程间的同步

`multiprocessing`库提供了一系列同步原语的功能，API接口与`threading`库提供的是一致的。

```python
from multiprocessing import Process, Lock

def f(l, i):
    l.acquire()
    try:
        print('hello world', i)
    finally:
        l.release()

if __name__ == '__main__':
    lock = Lock()

    for num in range(10):
        Process(target=f, args=(lock, num)).start()
```

当然虽然接口一致，但其实实现还是不一致的，这里主要是使用了操作系统信号量。实现这个功能的代码在这里[multiprocessing/synchronize.py](https://github.com/python/cpython/blob/master/Lib/multiprocessing/synchronize.py)，可以看到这个py文件里依赖了`_multiprocessing`这个模块，这是一个c语言实现的模块，源码在[这里](https://github.com/python/cpython/tree/master/Modules/_multiprocessing)。

## 多进程间共享状态

`multiprocessing`库提供了两种方式共享状态：`Shared memory`、`Server process`。

### Shared memory

`Shared memory`很好理解，就是向操作系统申请一块共享内存，然后多个进程可以操作这块共享内存了。

```python
from multiprocessing import Process, Value, Array

def f(n, a):
    n.value = 3.1415927
    for i in range(len(a)):
        a[i] = -a[i]

if __name__ == '__main__':
    num = Value('d', 0.0)
    arr = Array('i', range(10))

    p = Process(target=f, args=(num, arr))
    p.start()
    p.join()

    print(num.value)
    print(arr[:])
```

这里注意操作共享内存时，操作的是很基础的`Value`和`Array`，这里面存放的是ctype类型的基础数据，因而没法存放python里的正常对象。如果一定要使用这个共享，可以考虑用`pickle`库将python里的正常对象序列化为byte数组，再放进`Value`。使用时再读出来，进行反序列化回来。当然要承担序列化开销及两个进程存放两一份数据的内存开销。

### Server process

`Server process`有点类似于之前的`Fork Server`，调用`manager = multiprocessing.Manager()`方法会启动一个`Server process`进程，接着调用`manager.list()`或`manager.Queue()`，会在这个进程里创建实际的普通对象，并返回一个`Proxy`对象，这个`Proxy`对象里会维持着对`Server process`进程的连接（默认是Socket连接，也可以使用Pipe连接）。

```python
    # 启动Server process进程
    def Manager(self):
        '''Returns a manager associated with a running server process

        The managers methods such as `Lock()`, `Condition()` and `Queue()`
        can be used to create shared objects.
        '''
        from .managers import SyncManager
        m = SyncManager(ctx=self.get_context())
        m.start()
        return m
    
    # 注册可通过manager获得的共享对象类型
    SyncManager.register('list', list, ListProxy)
    SyncManager.register('Queue', queue.Queue)

    # 注册可通过manager获得的共享对象类型的实现方法
    @classmethod
    def register(cls, typeid, callable=None, proxytype=None, exposed=None,
                 method_to_typeid=None, create_method=True):
        '''
        Register a typeid with the manager type
        '''
        if '_registry' not in cls.__dict__:
            cls._registry = cls._registry.copy()

        if proxytype is None:
            proxytype = AutoProxy

        exposed = exposed or getattr(proxytype, '_exposed_', None)

        method_to_typeid = method_to_typeid or \
                           getattr(proxytype, '_method_to_typeid_', None)

        if method_to_typeid:
            for key, value in list(method_to_typeid.items()):
                assert type(key) is str, '%r is not a string' % key
                assert type(value) is str, '%r is not a string' % value

        cls._registry[typeid] = (
            callable, exposed, method_to_typeid, proxytype
            )

        if create_method:
            def temp(self, *args, **kwds):
                util.debug('requesting creation of a shared %r object', typeid)
                token, exp = self._create(typeid, *args, **kwds)
                proxy = proxytype(
                    token, self._serializer, manager=self,
                    authkey=self._authkey, exposed=exp
                    )
                conn = self._Client(token.address, authkey=self._authkey)
                dispatch(conn, None, 'decref', (token.id,))
                return proxy # 注意这里返回的是proxy对象
            temp.__name__ = typeid
            setattr(cls, typeid, temp)
```

接着在各进程中对这些proxy对象的操作即会通过上述连接操作到实际的对象。

至此终于知道虽然`multiprocessing.Queue()`与`manager.Queue()`都返回`Queue`对象，但其实两者的底层实现逻辑很不一样。

`SyncManager`的实现代码在[这里](https://github.com/python/cpython/blob/master/Lib/multiprocessing/managers.py)，仔细看这里有一些实现逻辑很巧妙。

## 进程池的实现

`multiprocessing`库还提供了一个进程池，具体做法很简单，就不赘述了。

```python
from multiprocessing import Pool, TimeoutError
import time
import os

def f(x):
    return x*x

if __name__ == '__main__':
    # start 4 worker processes
    with Pool(processes=4) as pool:

        # print "[0, 1, 4,..., 81]"
        print(pool.map(f, range(10)))

        # print same numbers in arbitrary order
        for i in pool.imap_unordered(f, range(10)):
            print(i)

        # evaluate "f(20)" asynchronously
        res = pool.apply_async(f, (20,))      # runs in *only* one process
        print(res.get(timeout=1))             # prints "400"

        # evaluate "os.getpid()" asynchronously
        res = pool.apply_async(os.getpid, ()) # runs in *only* one process
        print(res.get(timeout=1))             # prints the PID of that process

        # launching multiple evaluations asynchronously *may* use more processes
        multiple_results = [pool.apply_async(os.getpid, ()) for i in range(4)]
        print([res.get(timeout=1) for res in multiple_results])

        # make a single worker sleep for 10 secs
        res = pool.apply_async(time.sleep, (10,))
        try:
            print(res.get(timeout=1))
        except TimeoutError:
            print("We lacked patience and got a multiprocessing.TimeoutError")

        print("For the moment, the pool remains available for more work")

    # exiting the 'with'-block has stopped the pool
    print("Now the pool is closed and no longer available")
```

这里只说一下创建`multiprocessing.Pool`对象时，有几个参数有些作用：

1. `initializer`及`initargs`，通过这两个参数可即将对在进程池中创建的进程进行部分初始化工作。

2. `maxtasksperchild`，可以通过这个参数设定进程池中每个进程最大处理的任务数，超过任务数后，会启动一个新的进程来代替该进程。为什么会有这个需求？

   > Worker processes within a `Pool` typically live for the complete duration of the Pool’s work queue. A frequent pattern found in other systems (such as Apache, mod_wsgi, etc) to free resources held by workers is to allow a worker within a pool to complete only a set amount of work before being exiting, being cleaned up and a new process spawned to replace the old one. The *maxtasksperchild* argument to the `Pool` exposes this ability to the end user.

原来很多服务型程序都会实现这个模式，为的是能及时释放worker占用的资源，感觉还是worker进程有问题，存在资源泄漏吧，呵呵。

## 实践中遇到的问题

最后说一个实践中遇到的问题：如果要在父子进程间交换大量的数据怎么办？下面给下探索出的实际决策路径：

1. 传递过去的数据多个任务都共用，则使用Pool的`initializer`将数据传递过去，如果父进程刚好是个单线程进程，则用`fork`创建子进程方式就好了，这样即使创建了多个进程，实际占用的内存也并不多。（initializer传递数据，底层也是通过将数据pickle序列化，再通过Pipe传递到子进程的）

   ```python
   from multiprocessing import Pool
   
   def init_pool(the_list):
       global some_list
       some_list = the_list
   
   def access_some_list(index):
       return some_list[index]
   
   if __name__ == "__main__":
       some_list = [24, 12, 6, 3]
       indexes = [3, 2, 1, 0]
       pool = Pool(processes=2, initializer=init_pool, initargs=(some_list,))
       result = pool.imap_unordered(access_some_list, indexes)
       print(list(result))
   ```

   

2. 如果对数据的操作不是很多，那么用`Server process`里的共享对象，但要注意尽量控制对数据的操作次数，能批量操作就尽量批量操作。

3. 如果传递过去的数据仅对该任务有效，则可以在提交任务时通过参数传递数据（底层是通过将数据pickle序列化，再通过Pipe传递到子进程的）。

4. 如果数据可以很方便地与普通ctype类型转换，用`Shared memory`也是个好办法。

5. 如果对数据是存在多生产多消费的场景，那就最好用`multiprocessing.Queue`了。

## 总结

python作为一个脚本语言，开发业务逻辑确实快，但由于存在全局解释锁，对于一些cpu密集的应用场景，使用CPU多核性能就成了一个挑战，官方提供了`multiprocessing`库算了部分解决了此类问题，但实际使用时还是有很多要注意的地方，如果用得不好很可能还产生其它问题。在这次实战过程中，基本上将`multiprocessing`库的源码都看了一遍，其中有不少精彩的点值得反复推敲和学习。

## 参考

1. https://docs.python.org/3/library/multiprocessing.html
2. https://pythonspeed.com/articles/python-multiprocessing/
3. [http://www.calvinneo.com/2017/04/18/multiprocessing%E6%A8%A1%E5%9D%97%E7%94%A8%E6%B3%95/](http://www.calvinneo.com/2017/04/18/multiprocessing模块用法/)
4. http://www.calvinneo.com/2019/11/23/multiprocessing-implement/
5. https://jeffpan.net/2017/12/13/multiprocessing-Pool-and-Queue-usage/

