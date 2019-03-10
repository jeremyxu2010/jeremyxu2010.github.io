---
title: 使用go开发api服务
tags:
  - golang
  - api
categories:
  - golang开发
date: 2017-02-04 19:00:00+08:00
---

看到有人用go语言开发api服务，分发打包的程序只需要分发一个可执行文件就可以了，真的好方便，于是我也来试一试。

## 依赖管理

go语言的第三方包依赖管理一直比较混乱，官方并没有给出推荐的依赖管理工具。有人推荐使用godep或govendor，docker开源项目使用的又好像是trash。参考[这里](https://github.com/golang/go/wiki/PackageManagementTools),经过一番对比，我最终选择了[glide](https://github.com/Masterminds/glide)，原因很简单，它跟npm之类很像，对于我来说很容易上手。

```
#我习惯将一些工具命令装到一个独立的地方
set GOPATH=W:\go_tools
go get -v github.com/Masterminds/glide
#记得要将W:\go_tools\bin路径加入到系统的PATH变量里去
```

## 应用框架

搜索了一下，最终选定了比较热门的`beego`，这里使用它的命令行工具`bee`帮助创建工程。

- 安装bee

```
set GOPATH=W:\go_tools
go get -v github.com/beego/bee
```

- 创建工程

```
#我的GOPATH是W:\workspace\go_projs
cd W:\workspace\go_projs\src
bee api apitest
```

- 安装第三方依赖

```
cd W:\workspace\go_projs\src\apitest
glide init
glide install
```

- 运行

```
cd W:\workspace\go_projs\src\apitest
bee run
```

然后就可以使用浏览器访问`http://127.0.0.1:8080/v1/user/`。

- 打包

```
cd W:\workspace\go_projs\src\apitest
go build -o apitest.exe main.go
```

这样打出的`apitest.exe`就可以分发了，超方便啊。

## 总结

相对于java那一套，使用golang开发api服务分发程序真的很方便，就一个可执行文件就OK了，以后做点小项目可以用golang来整了。

## 参考

`https://github.com/golang/go/wiki/PackageManagementTools`
`https://github.com/Masterminds/glide`
`https://beego.me/docs/install/bee.md`


