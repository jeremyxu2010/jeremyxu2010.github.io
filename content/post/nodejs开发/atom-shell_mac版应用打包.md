---
title: atom-shell_mac版应用打包
author: Jeremy Xu
tags:
  - atom-shell
  - nodejs
  - macos
categories:
  - nodejs开发
date: 2014-03-30 01:40:00+08:00
---

上一篇文章写了一个简单的PingDemo应用，今天参照atom-shell的文档将那个应用打包到mac应用，试了多久终于成功了，记录一下。

atom-shell的文档上讲mac下应用是这样的

> To distribute your app with atom-shell, you should name the folder of your app as app, and put it under atom-shell's resources directory (on OS X it is Atom.app/Contents/Resources/, and on Linux and Windows it is resources/), like this:

> On Mac OS X:

```
atom-shell/Atom.app/Contents/Resources/app/
├── package.json
├── main.js
└── index.html
```

> On Windows and Linux:

```
atom-shell/resources/app
├── package.json
├── main.js
└── index.html
```

> Then execute Atom.app (or atom on Linux, and atom.exe on Windows), and atom-shell will start as your app. The atom-shelldirectory would then be your distribution that should be delivered to final users.

但实际场景应用打包时，一般要求重命名`Atom.app`为自定义的名称，我按照上述打完包后，直接将Atom.app重命名为`PingDemo.app`后，再运行`PingDemo.app`，提示

```
You can’t open the application “PingDemo.app” because it may be damaged or incomplete.
```

在网上搜索了半天，终于找到解决方案

```
cp -r Atom.app PingDemo.app
mkdir -p PingDemo.app/Contents/Resources/app/
cp pingDemoApp/{index.html,jquery.js,main.js,package.json,ping.js} PingDemo.app/Contents/Resources/app/
```

使用Property List Editor打开PingDemo.app/Contents/Info.plist, 将CFBundleName属性值修改为PingDemo, 添加一个属性CFBundleExecutable，值为Atom，如下图

![修改plist文件](http://blog-images-1252238296.cosgz.myqcloud.com/change_plist.png)

保存之后，就可以打开`PingDemo.app`这个应用了。

当然如果想修改应用图标，可替换`PingDemo.app/Contents/Resources/atom.icns`这个图标
