---
title: apk反编译步骤
author: Jeremy Xu
tags:
  - android
  - java
  - decompiler
categories:
  - java开发
date: 2017-10-16 11:16:00+08:00
---

最近的工作中需要反编译第三方的apk，以也了解对方的签名逻辑，这里将用到的反编译技巧记录一下。

## apk文件转成jar文件

首先需要使用工具将apk文件转成jar文件，这里使用[dex2jar](https://github.com/pxb1988/dex2jar)，具体使用下面的命令：

```bash
sh d2j-dex2jar.sh -f ~/path/to/apk_to_decompile.apk
```

这样会在当前目录下生成文件`apk_to_decompile-dex2jar.jar`。

## 反编译jar文件

试用过[jad](https://varaneckas.com/jad/)、[jd-gui](http://jd.benow.ca/)、[fernflower](https://github.com/fesh0r/fernflower)，结果发现还是IDEA自带的[fernflower](https://github.com/fesh0r/fernflower)效果最好了，命令下执行也非常方便：

```bash
java -cp "/Applications/IntelliJ IDEA.app/Contents/plugins/java-decompiler/lib/java-decompiler.jar" org.jetbrains.java.decompiler.main.decompiler.ConsoleDecompiler -hes=0 -hdc=0 c:\Temp\binary\ -e=c:\Java\rt.jar c:\Temp\source\

java -cp "/Applications/IntelliJ IDEA.app/Contents/plugins/java-decompiler/lib/java-decompiler.jar" org.jetbrains.java.decompiler.main.decompiler.ConsoleDecompiler -dgs=1 c:\Temp\binary\library.jar  c:\Temp\source\
```

fernflower支持很多的命令行参数，详见其[文档](https://github.com/fesh0r/fernflower)。

