---
title: 解决dubbo导致tomcat无法优雅shutdown的问题
author: Jeremy Xu
tags:
  - dubbo
  - tomcat
  - netty
categories:
  - java开发
date: 2016-12-09 12:02:00+08:00
---
## 问题由来

今天运行工程时，发现停止tomcat时，java进程并不会退出，而是必须kill -9杀掉tomcat进程。
问题出现时将线程dump出来后，发现有一个非daemon的线程仍在运行。

```
"Hashed wheel timer #1" prio=6 tid=0x000000000ee73800 nid=0x750 waiting on condition [0x000000001383e000]
   java.lang.Thread.State: TIMED_WAITING (sleeping)
	at java.lang.Thread.sleep(Native Method)
	at org.jboss.netty.util.HashedWheelTimer$Worker.waitForNextTick(HashedWheelTimer.java:503)
	at org.jboss.netty.util.HashedWheelTimer$Worker.run(HashedWheelTimer.java:401)
	at org.jboss.netty.util.ThreadRenamingRunnable.run(ThreadRenamingRunnable.java:108)
	at java.lang.Thread.run(Thread.java:745)
```

## 分析原因

com.alibaba.dubbo.remoting.transport.netty.NettyClient创建了一个NioClientSocketChannelFactory，而NioClientSocketChannelFactory在构造时又会创建一个NioClientBossPool，NioClientBossPool在构造时又会创建一个HashedWheelTimer，而HashedWheelTimer创建时使用的是Executors.defaultThreadFactory()，这个线程工厂创建的线程是非daemon的，因此必须调用NioClientSocketChannelFactory的releaseExternalResources方法才可以优雅地停止这些非daemon线程。而dubbo出于规避netty的一个bug

```java
// 因ChannelFactory的关闭有DirectMemory泄露，
// 采用静态化规避 https://issues.jboss.org/browse/NETTY-424
private static final ChannelFactory channelFactory = new NioClientSocketChannelFactory(Executors.newCachedThreadPool(new NamedThreadFactory("NettyClientBoss", true)),
                                                                                           Executors.newCachedThreadPool(new NamedThreadFactory("NettyClientWorker", true)),
                                                                                           Constants.DEFAULT_IO_THREADS);
```

, 所以注释掉了NettyClient里的doClose方法里的逻辑

```java
@Override
protected void doClose() throws Throwable {
    /*try {
        bootstrap.releaseExternalResources();
    } catch (Throwable t) {
        logger.warn(t.getMessage());
    }*/
}
```


而采用注册shutdownhook的方式进行资源的释放

```java
static {
    Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
        public void run() {
            if (logger.isInfoEnabled()) {
                logger.info("Run shutdown hook of netty client now.");
            }

            try {
                channelFactory.releaseExternalResources();
            } catch (Throwable t) {
                logger.warn(t.getMessage());
            }
        }
    }, "DubboShutdownHook-NettyClient"));
}
```

但这个方案其实并不能释放Netty的资源，正常关闭java进程时，因为有非daemon线程存在，所以shutdownhook并不会执行，这就是个死循环。

## 解决方案

最后使用反射解决了此问题。

```java
//先释放dubbo所占用的资源
ProtocolConfig.destroyAll();
//用反射释放NettyClient所占用的资源, 以避免不能优雅shutdown的问题
releaseNettyClientExternalResources();

private void releaseNettyClientExternalResources() {
	try {
		Field field = NettyClient.class.getDeclaredField("channelFactory");
		field.setAccessible(true);
		ChannelFactory channelFactory = (ChannelFactory) field.get(NettyClient.class);
		channelFactory.releaseExternalResources();
		field.setAccessible(false);
		LOGGER.info("Release NettyClient's external resources");
	} catch (Exception e){
		LOGGER.error("Release NettyClient's external resources error", e);
	}
}
```
