---
title: 编译自定义Python二进制程序
tags:
  - python
  - gcc
  - make
categories:
  - devops
date: 2018-12-28 18:07:00+08:00
---

工作中需要自行编译一个Python二进制程序，并尽量减少该程序依赖的库文件，使之在相同CPU架构上有更良好的可移植性。先找了下网上的资料，都不太详尽，经过探索最终还是成功了，这里记录一下过程以备忘。

## 过程记录

查阅Python27源码中的setup.py文件，发现Python核心仅依赖glibc，c++等标准库，因此按以下默认的编译命令即可编译出依赖较少的Python二进制程序了。

```bash
# 安装必要的编译工具链
sudo yum install -y gcc make gcc-c++ glibc-static libstdc++-static

curl -O https://www.python.org/ftp/python/2.7.13/Python-2.7.13.tgz
tar -xf Python-2.7.13.tgz && cd Python-2.7.13

# 注意这里添加了选项静态链接libgcc和libstdc++
LDFLAGS="-static-libgcc -static-libstdc++" ./configure --prefix=/usr/local/python27 --with-cxx-main=/usr/bin/g++
make -j4 > make.log
make install
```

我用`ldd`命令检查下Python二进制程序依赖的库文件：

```bash
[root@centos-linux-7 deps]# ldd /usr/local/python27/bin/python
	linux-vdso.so.1 =>  (0x00007fff78de8000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f8b2253a000)
	libdl.so.2 => /lib64/libdl.so.2 (0x00007f8b22336000)
	libutil.so.1 => /lib64/libutil.so.1 (0x00007f8b22133000)
	libm.so.6 => /lib64/libm.so.6 (0x00007f8b21b2a000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f8b21547000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f8b22756000)
```

发现依赖的库文件确实都是系统核心库文件，大部分Linux系统上均有这些库文件，因此可以断定将编译好的python程序拷贝到其它Linux系统上是可以执行的。

但我发现Python程序的执行并不是只使用了`python`这个二进制程序，在其加载某些python模块是会动态加载该模块对应的动态链接库文件。因此我用ldd命令检查下各python模块的动态库文件的依赖情况：

```bash
[root@centos-linux-7 Python-2.7.13]# find . -name '*.so'|xargs ldd
./build/lib.linux-x86_64-2.7/_socket.so:
	linux-vdso.so.1 =>  (0x00007ffdba579000)
	libm.so.6 => /lib64/libm.so.6 (0x00007ff0d8ded000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007ff0d8bd1000)
	libc.so.6 => /lib64/libc.so.6 (0x00007ff0d8804000)
	/lib64/ld-linux-x86-64.so.2 (0x00007ff0d9304000)
......
./build/lib.linux-x86_64-2.7/_curses.so:
	linux-vdso.so.1 =>  (0x00007ffd61969000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f6a52b86000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f6a527b9000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f6a52fe5000)
```

这么一看绝大部分python模块的动态库文件也是仅依赖系统核心库文件，一切都挺美好！

但在我的场景里，python编译时还需要启用`ssl`、`hashlib`、`readline`等模块，而这些模块编译时会依赖系统非核心库文件，我分析Python源代码目录下的`setup.py`文件，发现依赖关系如下：

1. ssl、hashlib依赖于libssl、libcrypto，而libssl、libcrypto又依赖libz。
2. readline依赖libreadline、libncurses。

于是这里先编译安装这些非核心库文件：

```bash
# 注意由于这些库文件后面都需要链接进python模块对应的动态库文件，所以下面编译的非核心库均要使用-fPIC选项，并且都只编译出静态库文件
mkdir -p deps/src
cd deps/src

curl -O https://zlib.net/zlib-1.2.11.tar.gz
tar -xf zlib-1.2.11.tar.gz && cd zlib-1.2.11
CFLAGS='-fPIC' ./configure --prefix=`pwd`/../../zlib --static
make -j4 && make install
cd ..

curl -O https://www.openssl.org/source/openssl-1.0.2q.tar.gz
tar -xf openssl-1.0.2q.tar.gz && cd openssl-1.0.2q
./Configure zlib --prefix=`pwd`/../../ssl --openssldir=`pwd`/../../ssl linux-x86_64 --with-zlib-lib=`pwd`/../../zlib/lib --with-zlib-include=`pwd`/../../zlib/include -fPIC
make -j4 && make install
cd ..

curl -O http://ftp.ntu.edu.tw/gnu/ncurses/ncurses-5.9.tar.gz
tar -xf ncurses-5.9.tar.gz && cd ncurses-5.9
CPPFLAGS="-fPIC" ./configure --prefix=`pwd`/../../ncurses
make -j4 && make install
cd ..

curl -O http://ftp.ntu.edu.tw/gnu/readline/readline-6.2.tar.gz
tar -xf readline-6.2.tar.gz && cd readline-6.2
CPPFLAGS="-fPIC" ./configure --prefix=`pwd`/../../readline --disable-shared
make -j4 && make install
cd ..

cd ../..
```

最后重新编译Python：

```bash
# 注意这里添加了选项静态链接libgcc和libstdc++，还指定了一些头文件目录及库文件目录
CPPFLAGS="-I`pwd`/deps/zlib/include  -I`pwd`/deps/ssl/include -I`pwd`/deps/readline/include -I`pwd`/deps/ncurses/include -I`pwd`/deps/ncurses/include/ncurses" LDFLAGS="-static-libgcc -static-libstdc++ -L`pwd`/deps/zlib/lib -L`pwd`/deps/ssl/lib -L`pwd`/deps/readline/lib -L`pwd`/deps/ncurses/lib" ./configure --prefix=/usr/local/python27 --with-cxx-main=/usr/bin/g++
make -j4 && make install
```

最后检查下编译出的python二进制程序文件及各模块的动态库文件，发现仅依赖系统核心库文件，效果很好：

```bash
[root@centos-linux-7 python27]# ldd /usr/local/python27/bin/python
	linux-vdso.so.1 =>  (0x00007ffc54fe8000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f9774b3d000)
	libdl.so.2 => /lib64/libdl.so.2 (0x00007f9774939000)
	libutil.so.1 => /lib64/libutil.so.1 (0x00007f9774736000)
	libm.so.6 => /lib64/libm.so.6 (0x00007f9774434000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f9774067000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f9774d59000)
	
[root@centos-linux-7 python27]# find /usr/local/python27 -name '*.so'|xargs ldd
/usr/local/python27/lib/python2.7/lib-dynload/nis.so:
	linux-vdso.so.1 =>  (0x00007fff42b14000)
	libnsl.so.1 => /lib64/libnsl.so.1 (0x00007fbc2ad4f000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007fbc2ab33000)
	libc.so.6 => /lib64/libc.so.6 (0x00007fbc2a766000)
	/lib64/ld-linux-x86-64.so.2 (0x00007fbc2b16d000)
......
/usr/local/python27/lib/python2.7/lib-dynload/_codecs_cn.so:
	linux-vdso.so.1 =>  (0x00007fff695db000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f421bd72000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f421b9a5000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f421c1b2000)
```

安装其它第三方python模块的方法与上面的过程很类似了，这里就不赘述了。

## 总结

手工编译一个python不难，但如果要尽可能少地依赖系统中库文件，这时要考虑的问题就比较多了。通过本次探索，对GCC的编译过程有了更深刻的认识，也基本掌握了`CFLAGS`、`CPPFLAGS`、`LDFLAGS`等常见编译参数的用法。

## 参考

1. https://devguide.python.org/setup/#unix
2. https://stackoverflow.com/questions/4156055/static-linking-only-some-libraries
3. https://www.cnblogs.com/taskiller/archive/2012/12/14/2817650.html
4. https://www.oschina.net/question/994701_105246
5. https://blog.csdn.net/haibosdu/article/details/77094833

