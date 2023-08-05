---
title: golang开发环境搭建
tags:
  - golang
  - idea
categories:
  - golang开发
date: 2016-09-25 23:37:00+08:00
---
之前项目中使用go写过不少命令行工具，这些命令行工具主要进行网络扫描任务。很可惜当时并没有留下任何记录，今天突然想起这个事，觉得还是有必要将学习golang的过程记录下来，以便以后复习。

## 安装golang环境

mac下安装golang很简单

```bash
brew install golang
```

## 安装gotour及goimports

一列周边的工具命令还是有必要安装一下的，比如`gotour`，`goimports`。由于使用get命令默认会将命令安装到GOPATH的bin目录下，这些全局命令还是单独放在一个全局GOPATH里比较好。

```bash
mkdir ~/dev/go_global
export GOPATH=$HOME/dev/go_global
go get golang.org/x/tour/gotour
go get golang.org/x/tools/cmd/goimports

# 设置全局的GOPATH，设置gotour、goimports的别名
echo "
GO_GLOBAL_PATH=$HOME/dev/go_global
GOPATH=$GO_GLOBAL_PATH
alias gotour=$GO_GLOBAL_PATH/bin/gotour
alias goimports=$GO_GLOBAL_PATH/bin/goimports
" >> ~/.zshrc
# 刷新zsh的配置缓存
src
```

* `gotour`: 我主要是用来做一下小实验，在终端里直接输入`gotour`，这时就打开一个浏览器，在里面可以输入代码，点`Run`按钮就可以直接运行看结果，类似其他很多语言提供的REPL即时运行的工具。

* `goimports`: 很多IDE会用这个命令对go的源代码格式化。

## 标准库文档

标准库中文文档地址：[https://studygolang.com/pkgdoc](https://studygolang.com/pkgdoc)

## 设置项目GOPATH

另外我希望每进入一个不同的go项目，都能将这个项目的目录加入到GOPATH里，在网上找了一下，找到一个好办法

```bash
# 重写cd命令，cd进入目录时，向上查找.gopath文件，如查找到，则设置.gopath文件所在目录为GOPATH
echo '
cd () {
    builtin cd "$@"
    cdir=$PWD
    while [ "$cdir" != "/" ]; do
        if [ -e "$cdir/.gopath" ]; then
            export GOPATH=$cdir
            break
        fi
        cdir=$(dirname "$cdir")
    done
}
' >> ~/.zshrc
# 刷新zsh的配置缓存
src
```

这样以后只须在go项目根目录下创建一个`.gopath`目录就可以了。

## IntelliJ IDEA设置

IDEA要开发go程序，需要安装Go语言支持，如下。

![idea_golang.png](http://blog-images-1252238296.cosgz.myqcloud.com/idea_golang.png)

然后就可以导入工程了。这里导入一下`gopl.io`这个工程，`Go语言圣经`这本书是引用这个工程的源码，把这个工程里源代码导入IDEA，以后查看代码会很方便。

```
mkdir ~/dev/gobook
export GOPATH=$HOME/dev/gobook
go get gopl.io
touch ~/dev/gobook/.gopath
```

最后在IDEA里新建一个名为`gobook`的Go项目，项目目录就指定为`$HOME/dev/gobook`，走完向导，这个Go项目就创建好了。

## 总结

因为以前用过golang，简单看了下golang的入门教程还是大概知道怎么写go语言的代码了，接下来要再把书温习一翻，再多动手写点代码，争取早日将以前学过的go语言技巧都找回来。

