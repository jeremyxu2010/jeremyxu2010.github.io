---
title: 解决zookeeper导致tomcat停止时报异常的问题
author: Jeremy Xu
tags:
  - zookeeper
categories:
  - java开发
date: 2016-12-09 12:09:00+08:00
---
## 问题由来

今天运行工程时，发现停止tomcat时，发现控制台会报一些错误。

```
十二月 09, 2016 9:25:14 上午 org.apache.coyote.AbstractProtocol stop
信息: Stopping ProtocolHandler ["http-apr-8080"]
十二月 09, 2016 9:25:14 上午 org.apache.catalina.loader.WebappClassLoaderBase loadClass
信息: Illegal access: this web application instance has been stopped already.  Could not load org.apache.zookeeper.server.ZooTrace.  The eventual following stack trace is caused by an error thrown for debugging purposes as well as to attempt to terminate the thread which caused the illegal access, and has no functional impact.
java.lang.IllegalStateException
	at org.apache.catalina.loader.WebappClassLoaderBase.loadClass(WebappClassLoaderBase.java:1747)
	at org.apache.catalina.loader.WebappClassLoaderBase.loadClass(WebappClassLoaderBase.java:1705)
	at org.apache.zookeeper.ClientCnxn$SendThread.run(ClientCnxn.java:1128)

十二月 09, 2016 9:25:14 上午 org.apache.catalina.loader.WebappClassLoaderBase loadClass
信息: Illegal access: this web application instance has been stopped already.  Could not load org.apache.log4j.spi.ThrowableInformation.  The eventual following stack trace is caused by an error thrown for debugging purposes as well as to attempt to terminate the thread which caused the illegal access, and has no functional impact.
java.lang.IllegalStateException
	at org.apache.catalina.loader.WebappClassLoaderBase.loadClass(WebappClassLoaderBase.java:1747)
	at org.apache.catalina.loader.WebappClassLoaderBase.loadClass(WebappClassLoaderBase.java:1705)
	at org.apache.log4j.spi.LoggingEvent.<init>(LoggingEvent.java:165)
	at org.apache.log4j.Category.forcedLog(Category.java:391)
	at org.apache.log4j.Category.log(Category.java:856)
	at org.slf4j.impl.Log4jLoggerAdapter.error(Log4jLoggerAdapter.java:576)
	at org.apache.zookeeper.ClientCnxn$1.uncaughtException(ClientCnxn.java:414)
	at java.lang.Thread.dispatchUncaughtException(Thread.java:1986)
```

## 分析原因

框架时使用CuratorFramework连接zookeeper的，在spring bean销毁时也正确的关闭了zookeeper连接。

```java
curatorFramework.close();
```

但跟踪代码发现curatorFramework关闭时会调用org.apache.curator.CuratorZookeeperClient#close，之后会org.apache.curator.ConnectionState#close，再之后会调到org.apache.curator.HandleHolder#closeAndClear，再之后会调到org.apache.curator.HandleHolder#internalClose，再之后会调到org.apache.zookeeper.ZooKeeper#close，再之后会调到org.apache.zookeeper.ClientCnxn#close，再之后再调到org.apache.zookeeper.ClientCnxn#disconnect，再之后会调到org.apache.zookeeper.ClientCnxn.SendThread#close。

`org/apache/zookeeper/ClientCnxn.java:1311`

```java
void close() {
    state = States.CLOSED;
    clientCnxnSocke.wakeupCnxn();
}
```

这样仅仅只是修改了SendThread线程内部的变量，并没有等SendThread完全退出。
这样就存在spring bean销毁了，但SendThread线程还活着的场景。spring容器退出后，tomcat将该web应用标识为stopped，该web应用的classloader也不再可用。这时SendThread线程执行时要从该web应用的classloader里加载类时，就会报上面的错。

## 解决方案

这个问题本质上应该是zookeeper-3.4.8.jar的bug, 关闭zookeeper时，并没有等待SendThread线程完全退出。但项目中不太好直接修改zookeeper的源码，因此从封装的框架层面解决此问题。


```java
public synchronized void destroy() {
    try {
        if (nodepath != null) {
            curatorFramework.delete().forPath(nodepath);
            LOGGER.info("ZK Close,Path:{}", nodepath);
        }


    } catch (Exception e) {
        LOGGER.error("Couldn't Delete Registry Node", e);
    }

    try {
        curatorFramework.close();
        //等待zookeeper的相关线程完全退出
        synchronized (curatorFramework){
            curatorFramework.wait(500L);
        }
    } catch (Exception e){
        LOGGER.error("Close Registry Error", e);
    }
}
```
