---
title: Java NIO File操作
date: 2016-05-09 23:58:00+08:00
tags:
  - java
  - nio
categories:
  - java开发
---

今天在工作中遇到一个很奇怪的问题。使用java.io.File进行文件操作抛出了`FileNotFoundException`，代码如下

```java
//但事实上在`/somewhere`目录下存在文件`测试.txt`
FileInputStream fin = new FileInputStream(new File("/somewhere/测试.txt"));
```

在网络找了下，发现一个可能是由于路径中包括非ASCII字符，详见[这里](http://stackoverflow.com/questions/16977251/java-on-mac-os-filenotfound-if-path-contatins-non-latin-characters/17481204#17481204)

最后找到了解决方案

```java
InputStream fin = Files.newInputStream(Paths.get("/somewhere/测试.txt"));
```

看来Java老的那一套File操作接口确实问题多多啊。这里将Java 7引入的新File操作接口复习一下以备忘。

## Path接口

这个接口表示一个文件在文件系统中的定位器。常见与文件路径相关的操作都可以在这个接口里找到。详细文档参见[这里](https://docs.oracle.com/javase/7/docs/api/java/nio/file/Path.html)

注意以下两点
* `Path`对象一般由`java.nio.file.Paths`的两个`get`静态方法得来，并不是new出来的
* 如果与已有的库交互要用到`java.io.File`，可以使用它的`toFile`方法得到一个File对象

## Files接口

Files接口里基本上都是静态方法，所有与文件相关的操作都可以在这个接口里找到。详细文档参见[这里](https://docs.oracle.com/javase/7/docs/api/java/nio/file/Files.html)

为了便于更好地使用Files进行文件操作，这里列举经常用到的静态方法，并与使用`java.io.File`作个参照。

* `Files.exists(Paths.get("/somewhere/somefile.txt"))` vs  `(new File("/somewhere/somefile.txt")).exists()`
* `Files.newInputStream(Paths.get("/somewhere/somefile.txt"))` vs `new FileInputStream(new File("/somewhere/somefile.txt"))`
* `Files.newOutputStream(Paths.get("/somewhere/somefile.txt"))` vs `new FileOutputStream(new File("/somewhere/somefile.txt"))`
* `Files.newByteChannel(Paths.get("/somewhere/somefile.txt"))` vs `(new FileInputStream(new File("xxx")).getChannel()`
* `Files.newDirectoryStream(Paths.get("/somewhere"))` vs `(new File("/somewhere")).listFiles() `
* `Files.createFile(Paths.get("/somewhere/somefile.txt")` vs `(new File("/somewhere/somefile.txt")).createNewFile()`
* `Files.createDirectory(Paths.get("/somewhere"))` vs `(new File("/somewhere")).mkdir()`
* `Files.createDirectories(Paths.get("/somewhere"))` vs `(new File("/somewhere")).mkdirs()` 
* `Files.createAndCheckIsDirectory(Paths.get("/somewhere"))` vs `(new File("/somewhere")).mkdirs(); boolean success = (new File("/somewhere")).exists() && (new File("/somewhere")).isDirectory()`
* `Files.createTempFile(Paths.get("/somewhere"), "XXXX", null)` vs `File.createTempFile("XXXX", null, new File("/somewhere"))`
* `Files.createTempFile("XXXX", null)` vs `File.createTempFile("XXXX", null)` 
* `Files.createTempDirectory(Paths.get("/somewhere"), "XXXX")` vs - 
* `Files.createTempDirectory("XXXX")` vs - 
* `Files.createSymbolicLink(Paths.get("/somewhere/link.txt"), Paths.get("/somewhere/somefile.txt"))` vs - 
* `Files.createLink(Paths.get("/somewhere/link.txt"), Paths.get("/somewhere/somefile.txt"))` vs - 
* `Files.delete(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).delete()`
* `Files.deleteIfExists(Paths.get("/somewhere/somefile.txt"))` vs - 
* `Files.copy(Paths.get("/somewhere/somefile.txt"), Paths.get("/somewhere/somefile2.txt"))` vs - 
* `Files.move(Paths.get("/somewhere/somefile.txt"), Paths.get("/somewhere/somefile2.txt"))` vs `(new File("/somewhere/somefile.txt")).renameTo(new File("/somewhere/somefile2.txt"))` 
* `Files.readSymbolicLink(Paths.get("/somewhere/link.txt"))` | - 
* `Files.isSameFile(Paths.get("/somewhere/somefile.txt"), Paths.get("/somewhere/somefile2.txt"))` | - 
* `Files.isHidden(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).isHidden()` 
* `Files.getFileAttributeView(Paths.get("/somewhere/somefile.txt"), AclFileAttributeView.class)` vs - 
* `Files.readAttributes(Paths.get("/somewhere/somefile.txt"), PosixFileAttributes.class)` vs - 
* `Files.setAttribute(Paths.get("/somewhere/somefile.txt"), "dos:hidden", true)` vs - 
* `Files.getAttribute(Paths.get("/somewhere/somefile.txt"), "unix:uid")` | - 
* `Files.readAttributes(Paths.get("/somewhere/somefile.txt"), "posix:permissions,owner,size")` vs - 
* `Files.getPosixFilePermissions(Paths.get("/somewhere/somefile.txt"))` vs - 
* `Files.setPosixFilePermissions(Paths.get("/somewhere/somefile.txt"), new HashSet(){ {this.add(PosixFilePermission.OWNER_READ);this.add(PosixFilePermission.OWNER_WRITE);this.add(PosixFilePermission.OWNER_EXECUTE);} })` vs - 
* `Files.getOwner(Paths.get("/somewhere/somefile.txt"))` vs - 
* `UserPrincipal joe = lookupService.lookupPrincipalByName("joe");Files.setOwner(Paths.get("/somewhere/somefile.txt"), joe)` vs - 
* `Files.isSymbolicLink(Paths.get("/somewhere/somefile.txt"))` vs - 
* `Files.isDirectory(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).isDirectory()` 
* `Files.isRegularFile(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).isFile()`
* `Files.getLastModifiedTime(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).lastModified()`
* `Files.setLastModifiedTime(Paths.get("/somewhere/somefile.txt"), FileTime.fromMillis(System.currentTimeMillis()))` vs `(new File("/somewhere/somefile.txt")).setLastModified(System.currentTimeMillis())` 
* `Files.size(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).length()`
* `Files.notExists(Paths.get("/somewhere/somefile.txt"))` vs `!(new File("/somewhere/somefile.txt")).exists()`
* `Files.isAccessible(Paths.get("/somewhere/somefile.txt"))` vs - 
* `Files.isReadable(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).canRead()`
* `Files.isWritable(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).canWrite()`
* `Files.isExecutable(Paths.get("/somewhere/somefile.txt"))` vs `(new File("/somewhere/somefile.txt")).canExecute()`
* `Files.walkFileTree(Paths.get("/somewhere"), new FileVisitor<Path>(){…})` vs - 
* `Files.newBufferedReader(Paths.get("/somewhere/somefile.txt"))` vs `new InputStreamReader(new FileInputStream(new File("/somewhere/somefile.txt")))` 
* `Files.newBufferedWriter(Paths.get("/somewhere/somefile.txt"))` vs `new OutputStreamWriter(new FileOutputStream(new File("/somewhere/somefile.txt")))` 
* `Files.list(Paths.get("/somewhere"))` vs `(new File("/somewhere")).listFiles()`

有一些Stream与Path相互copy、一些重载的方法没有列在上面。

官方为什么又发明一个新的文件操作API呢？我想了下，感觉大概是以下原因

* 静态方法比对象方法更易用
* Files的静态方法实现得更跨平台
* 对于文件属和权限的操作更方便易用
* Files的静态方法在文件操作出错时能更好地给予外界信息供诊断
* Files的静态方法处理比较大的目录时，因为使用了Visitor模式，比老的方式效率更高
* Files的move方法操作更原子性
* 老的API已被广泛使用，不好直接对其作大幅修改

另外原来的`deleteOnExit`建议换成下面的写法

```java
OutputStream out = Files.newOutputStream(Paths.get("test.tmp"), StandardOpenOption.DELETE_ON_CLOSE);
...
out.close();
```

