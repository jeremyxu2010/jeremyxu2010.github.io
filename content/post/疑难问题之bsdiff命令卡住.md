---
title: 疑难问题之bsdiff
tags:
  - bsdiff
  - cmake
categories:
  - 疑难问题
date: 2017-09-18 22:17:00+08:00
---

# 疑难问题之bsdiff

## 问题背景

项目中使用到了`bsdiff`命令进行增量包的生成，不过在使用中发现对于某些文件，`bsdiff`命令会卡住。

## 诊断问题

刚开始以为是操作系统的问题，换了个全新的系统，按网上的教程从[http://www.daemonology.net/bsdiff/](http://www.daemonology.net/bsdiff/)下载bsdiff的源码，重新编译得到bsdiff，这里把原来卡住的两个文件重新试了一次，发现还是会卡住。

看来这个是bsdiff本身存在问题，在网上搜索了下，终于发现有人遇过[一样的问题](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=409664)。很奇怪，在国内也有很多人用bsdiff生成增量包，但却没人反馈这个问题。国外这个帖子里也写明了解决方案，那就是打上一些优化补丁。

> ```t
> We should apply the following 4 patches from chromium - they are small,
> and, as part of Chromium, also presumably well tested:
>
> (1) https://chromium.googlesource.com/chromiumos/third_party/bsdiff/+/e2b85ce4ea246ca804ee2a9e18005c44e193d868
>
> Replacing the custom suffix sorting implementation with -ldivsufsort. This
> brings down the time to generate a delta (for the proposed new format) for
> libreoffice-core 5.4~rc2-1->5.4-1 from 93 seconds down to 50 seconds.
>
> It also just involves replacing code with a library call, so that's nice
> as well.
>
> (2) https://chromium.googlesource.com/chromiumos/third_party/bsdiff/+/a055996c743add7a9558839276fd1e4994d16bd3
>
> Speeds up a pathological case
>
> (3) https://chromium.googlesource.com/chromiumos/third_party/bsdiff/+/58146f74abd6b1b69693943195f37f4ac6a6acef
>
> Fixes a hang
>
> (4) https://chromium.googlesource.com/chromiumos/third_party/bsdiff/+/426e4aa1cbeb3c8a73002047d7a796ca8e5e17d4
>
> Another pathological case where files differ by less than 8 bytes
> ```

又看了下，发现这些补丁都在google的chromiumous项目中，于是找到项目代码地址[https://chromium.googlesource.com/chromiumos/third_party/bsdiff/](https://chromium.googlesource.com/chromiumos/third_party/bsdiff/)。原来google早就发现了这个问题，并在它的项目内对其进行了优化，但不知为什么迟迟没有回馈开源社区。这样就好办了，直接编译google版的bsdiff命令出来就好了。

## 编译google版本bsdiff命令

### 获取代码

```bash
wget https://cmake.org/files/v3.9/cmake-3.9.2.tar.gz # libdivsufsort编译要使用cmake
git clone https://github.com/y-256/libdivsufsort.git # google版的bsdiff依赖这个
git clone https://chromium.googlesource.com/chromiumos/third_party/bsdiff
```

### 编译

我用的linux服务器没有root权限，安装稍微麻烦一点。

```bash
tar xf cmake-3.9.2.tar.gz
pushd cmake-3.9.2
./bootstrap --prefix=$HOME/local
make && make install
popd

# 设置一系列环境变量
echo "
export PATH=$HOME/local/bin:$PATH
export LD_LIBRARY_PATH=$HOME/local/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=$HOME/local/lib:$LIBRARY_PATH
export CPATH=$HOME/local/include:$CPATH
" > $HOME/.bashrc
source $HOME/.bashrc

pushd libdivsufsort
mkdir build
pushd build
cmake -DCMAKE_BUILD_TYPE="Release" -DCMAKE_INSTALL_PREFIX="$HOME/local" ..
popd
popd

pushd bsdiff
# 稍微修改下Makefile文件
sed -i -e 's/\-ldivsufsort64//g' Makefile
sed -i -e "s#PREFIX = /usr#PREFIX = $HOME/local#g" Makefile
make && make install

# 为了不跟原来的命令重名，将新命令重命名为bsdiff2
mv $HOME/local/bin/bsdiff $HOME/local/bin/bsdiff2
```

## 效果

使用新的`bsdiff2`命令测试了下，目前生成增量包一切正常，再也没有卡住的现象了，而且占用的内存也比原来小不少，速度还快。
