---
title: 特别要检查Java文件操作相关方法的返回值
author: Jeremy Xu
tags:
  - java
  - filesystem
categories:
  - java开发
date: 2014-03-30 01:40:00+08:00
---

今天遇到一个很狗血的问题，一个功能在开发环境没有问题，但在生产环境出错了。

代码如下：

```java
...
File tmpFile = new File(fileTmpPath);
File newFileTarget = new File(filePath);
tmpFile.renameTo(newFileTarget);
// 修改新文件的权限
FileManageHelper.chmod(newFileTarget);
....
```

最后报错信息提示执行chmod命令失败，但这个代码在开发环境没有问题啊。

仔细查找原因发现jdk的renameTo方法介绍如下：

```java
    /**
     * Renames the file denoted by this abstract pathname.
     *
     * <p> Many aspects of the behavior of this method are inherently
     * platform-dependent: The rename operation might not be able to move a
     * file from one filesystem to another, it might not be atomic, and it
     * might not succeed if a file with the destination abstract pathname
     * already exists.  The return value should always be checked to make sure
     * that the rename operation was successful.
     *
     * <p> Note that the {@link java.nio.file.Files} class defines the {@link
     * java.nio.file.Files#move move} method to move or rename a file in a
     * platform independent manner.
     *
     * @param  dest  The new abstract pathname for the named file
     *
     * @return  <code>true</code> if and only if the renaming succeeded;
     *          <code>false</code> otherwise
     *
     * @throws  SecurityException
     *          If a security manager exists and its <code>{@link
     *          java.lang.SecurityManager#checkWrite(java.lang.String)}</code>
     *          method denies write access to either the old or new pathnames
     *
     * @throws  NullPointerException
     *          If parameter <code>dest</code> is <code>null</code>
     */
The rename operation might not be able to move a file from one filesystem to another
```

也就是说如果文件是从一个文件系统将文件move到另一个文件系统有可能失败，正好开发环境上`tmpFile`与`newFileTarget`在同一个文件系统中，而在生产环境中由于HA方案的原因这两个文件在不同的文件系统。

教训：一定要检查`File`的相关操作的返回值，如`setLastModified`, `setReadOnly`, `setWritable`, `setReadable`, `setExecutable`, `createNewFile`, `delete`, `mkdir`, `mkdirs`。
