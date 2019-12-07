---
title: 解决HTTP File Server Hang住问题
categories:
  - 工具
tags:
  - linux
  - gdb
  - python
date: 2019-12-07 13:26:00+08:00
---

出差大半个月，一直在客户现场处理各类疑难杂症，当中遇到一个小问题，有点意思，花了些时间诊断该问题，这里记录一下。

## 问题引出

突然有需求要临时搭建一个http file server，以方便其它人从这个web站点下载文件。

最简单的做法，直接用python自带的SimpleHTTPServer：

```bash
$ cd ${some_dir}
$ nohup python -m SimpleHTTPServer 8888 >/dev/null 2>&1 &
```

本以为这样就OK了，结果发现只要ssh会话一中断，就没法从这个http file server下载文件了。

## 探究原因

是不是python自带的SimpleHTTPServer本身有些问题？先换个工具试试

```bash
$ curl -s -o - -L https://github.com/codeskyblue/gohttpserver/releases/download/1.0.5/gohttpserver_1.0.5_linux_amd64.zip | bsdtar -xvf-

$ nohup ./gohttpserver -r ./ --port 8888 --upload >/dev/null 2>&1 &
```

好了，即使ssh会话中断，依旧可以从这个http file server下载文件了。

难道python自带的SimpleHTTPServer真有这么大的bug？个人觉得不太可能。

参考[DebuggingWithGdb](https://wiki.python.org/moin/DebuggingWithGdb)，使用gdb调试下hung住的python进程，发现进程是因为读取标准输入卡住了。

意识到应该是ssh会话中断后，进程依赖的标准输入文件句柄不存在，导致卡住了。换个命令试一下：

```bash
$ nohup python -m SimpleHTTPServer 8888 </dev/null >/dev/null 2>&1 &
```

这下终于没问题了。

## 进一步思考

### 怎么诊断进程hang在哪里了？

参考[DebuggingWithGdb](https://wiki.python.org/moin/DebuggingWithGdb)，可以用gdb attach进程，使用bt、py-bt命令查看进程当前的运行栈：

```bash
$ gdb ${process_binary_file} ${process_pid}
(gdb) bt
(gdb) py-bt
(gdb) info threads
(gdb) py-list
(gdb) thread apply all py-list
```

### 怎么查看进程运行时依赖的标准输入、标准输出、标准错误文件？

很简单，直接查看proc文件系统就可以了：

```bash
$ ll /proc/${process_pid}/fd
total 0
lrwx------ 1 root root 64 Dec  7 23:14 0 -> /dev/pts/0 (deleted)
l-wx------ 1 root root 64 Dec  7 23:14 1 -> /dev/null
l-wx------ 1 root root 64 Dec  7 23:14 2 -> /dev/null
...
```

这里0、1、2指向的文件就是标准输入、标准输出、标准错误文件。

### 怎么在不重启进程的前提下改变其标准输入、标准输出、标准错误？

很幸运，找到一个工具[dupx](https://www.isi.edu/~yuri/dupx/):

```bash
$ dupx -q ${process_pid} </dev/null >/dev/null 2>&1
```

这个工具的原理也很简单，其实就是使用gdb attach到目标进程，然后执行`open`、`dup`、`dup2`、`close`等系统调用。

`https://github.com/oudream/dupx/blob/master/dupx#L145`

```bash
gdb_cmds () {
    local _name=$1
    local _mode=$2
    local _desc=$3
    local _msgs=$4
    local _len

    [ -w "/proc/$PID/fd/$_desc" ] || _msgs=""
    if [ -d "/proc/$PID/fd" ] && ! [ -e "/proc/$PID/fd/$_desc" ]; then
	warn "Attempting to remap non-existent fd $n of PID ($PID)"
    fi

    [ -z "$_name" ] && return

    echo "set \$fd=open(\"$_name\", $_mode)"
    echo "set \$xd=dup($_desc)"
    echo "call dup2(\$fd, $_desc)"
    echo "call close(\$fd)"
    if  [ $((_mode & 3)) ] && [ -n "$_msgs" ]; then
        _len=$(echo -en "$_msgs" | wc -c)
        echo "call write(\$xd, \"$_msgs\", $_len)"
    fi
    echo "call close(\$xd)"
}
```

## 参考

1. https://www.ibm.com/developerworks/cn/linux/l-cn-nohup/index.html
2. https://github.com/codeskyblue/gohttpserver
3. https://wiki.python.org/moin/DebuggingWithGdb
4. https://www.isi.edu/~yuri/dupx/