---
title: netty3与netty4的区别
author: Jeremy Xu
tags:
  - java
  - nio
  - netty
categories:
  - java开发
date: 2016-10-31 01:40:00+08:00
---
今天遇到一个人问我netty3与netty4有什么区别。因为我之前使用netty做过网络程序开发，心里还是有点谱的。很自然地就说到了一些主要区别

* 一些术语的变化，如Upstream变为了Inbound，Downstream变为了Outbound
* netty3对每个读或写的操作，还会额外创建一个新的ChannelBuffer对象，这带来了很大的GC压力，为了缓解频繁申请回收Buffer时的GC压力，引入了池化的ByteBufs，当然在使用完Buffer后要注意需使用BufUtil.release释放。

那人再问，还有其它区别吗？然后我就说不上来了，惭愧。

回家查阅资料，终于将这个问题又深入理解了一次，这里记录一下以备忘。

## 线程模型的变化

### Netty 3.X 版本线程模型

Netty 3.X的I/O操作线程模型比较复杂，它的处理模型包括两部分：

Inbound：主要包括链路建立事件、链路激活事件、读事件、I/O异常事件、链路关闭事件等；
Outbound：主要包括写事件、连接事件、监听绑定事件、刷新事件等。
我们首先分析下Inbound操作的线程模型：

![netty3_inbound.png](http://blog-images-1252238296.cosgz.myqcloud.com/netty3_inbound.png)

从上图可以看出，Inbound操作的主要处理流程如下：

* I/O线程（Work线程）将消息从TCP缓冲区读取到SocketChannel的接收缓冲区中；
* 由I/O线程负责生成相应的事件，触发事件向上执行，调度到ChannelPipeline中；
* I/O线程调度执行ChannelPipeline中Handler链的对应方法，直到业务实现的Last Handler;
* Last Handler将消息封装成Runnable，放入到业务线程池中执行，I/O线程返回，继续读/写等I/O操作；
* 业务线程池从任务队列中弹出消息，并发执行业务逻辑。

通过对Netty 3的Inbound操作进行分析我们可以看出，Inbound的Handler都是由Netty的I/O Work线程负责执行。

下面我们继续分析Outbound操作的线程模型：

![netty3_outbound.png](http://blog-images-1252238296.cosgz.myqcloud.com/netty3_outbound.png)

从上图可以看出，Outbound操作的主要处理流程如下：

业务线程发起Channel Write操作，发送消息；

* Netty将写操作封装成写事件，触发事件向下传播；
* 写事件被调度到ChannelPipeline中，由业务线程按照Handler Chain串行调用支持Downstream事件的Channel Handler;
* 执行到系统最后一个ChannelHandler，将编码后的消息Push到发送队列中，业务线程返回；
* Netty的I/O线程从发送消息队列中取出消息，调用SocketChannel的write方法进行消息发送。

### Netty 4.X 版本线程模型

相比于Netty 3.X系列版本，Netty 4.X的I/O操作线程模型比较简答，它的原理图如下所示：

![netty4_inoutbound.png](http://blog-images-1252238296.cosgz.myqcloud.com/netty4_inoutbound.png)

从上图可以看出，Outbound操作的主要处理流程如下：

* I/O线程NioEventLoop从SocketChannel中读取数据报，将ByteBuf投递到ChannelPipeline，触发ChannelRead事件；
* I/O线程NioEventLoop调用ChannelHandler链，直到将消息投递到业务线程，然后I/O线程返回，继续后续的读写操作；
* 业务线程调用ChannelHandlerContext.write(Object msg)方法进行消息发送；
* 如果是由业务线程发起的写操作，ChannelHandlerInvoker将发送消息封装成Task，放入到I/O线程NioEventLoop的任务队列中，由NioEventLoop在循环中统一调度和执行。放入任务队列之后，业务线程返回；
* I/O线程NioEventLoop调用ChannelHandler链，进行消息发送，处理Outbound事件，直到将消息放入发送队列，然后唤醒Selector，进而执行写操作。

通过流程分析，我们发现Netty 4修改了线程模型，无论是Inbound还是Outbound操作，统一由I/O线程NioEventLoop调度执行。

### 自己的进一步理解

上述这段对比分析摘自[这里](http://www.infoq.com/cn/articles/netty-version-upgrade-history-thread-part)。说的已经比较清楚了，但我还是加上一些说明：

* netty4里第2步，*I/O线程NioEventLoop调用ChannelHandler链，直到将消息投递到业务线程*，这里netty并不直接将消息投递到业务线程，主要依赖于程序自行投递，一般方法无非是自行构造Task，将Task投递给自己的业务线程池。当然也可以在添加业务ChannelHandler时指定业务Handler运行所在的业务线程池，如下面的代码。

```java
private final EventExecutorGroup businessGroup = new DefaultEventExecutorGroup(4);
private final EventLoopGroup bossGroup = new NioEventLoopGroup();
private final EventLoopGroup workerGroup = new NioEventLoopGroup();

private void start() throws InterruptedException {
    ServerBootstrap b = new ServerBootstrap();
    b.group(bossGroup, workerGroup).channel(NioServerSocketChannel.class)
            .option(ChannelOption.SO_REUSEADDR, true)
            .childOption(ChannelOption.TCP_NODELAY, true)
            .childOption(ChannelOption.ALLOCATOR, PooledByteBufAllocator.DEFAULT)
            .handler(new CheckAcceptHandler())
            .childHandler(new ChannelInitializer<SocketChannel>() {
                @Override
                public void initChannel(SocketChannel ch)
                        throws Exception {
                    ch.pipeline().addLast("decoder", new LineBasedFrameDecoder(4096));
                    ch.pipeline().addLast("stringDecoder", new StringDecoder(StandardCharsets.UTF_8));
                    ch.pipeline().addLast("lineEncoder", new LineEncoder(StandardCharsets.UTF_8));
                    //指定了业务handler运行所在的业务线程池
                    ch.pipeline().addLast(businessGroup, "logicHandler", new ServerLogicalHandler());
                }
            });
    final int listenPort = 8888;
    b.bind(listenPort).sync();
}
```

* 如果原来的程序逻辑并没有使用单独的业务线程池的话，netty3与netty4在线程模型上就看不到变更了。当然非常不建议这么干，直接使用IO线程处理业务逻辑会极大地影响网络程序的处理性能。
* netty3与netty4在线程模型上的变更，看着影响并不大，但其实会造成很多其它的问题，参见[这里](http://www.infoq.com/cn/articles/netty-version-upgrade-history-thread-part)提到的4个问题，这些问题产生的根本原因均是由于线程模型发生变化造成的。

## 事件对象从ChannelHandler中消失了

在3.x时代，所有的I/O操作都会创建一个新的ChannelEvent对象，如下面的API

```java
void handleUpstream(ChannelHandlerContext ctx, ChannelEvent e) throws Exception;
void handleDownstream(ChannelHandlerContext ctx, ChannelEvent e) throws Exception;
```

而netty4.x里，为了避免频繁创建与回收ChannelEvent对象所造成的GC压力，上述两个处理所有类型事件的接口被改成了多个接口。

```java
void channelRegistered(ChannelHandlerContext ctx);
void channelUnregistered(ChannelHandlerContext ctx);
void channelActive(ChannelHandlerContext ctx);
void channelInactive(ChannelHandlerContext ctx);
void channelRead(ChannelHandlerContext ctx, Object message);

void bind(ChannelHandlerContext ctx, SocketAddress localAddress, ChannelPromise promise);
void connect(
        ChannelHandlerContext ctx, SocketAddress remoteAddress,
        SocketAddress localAddress, ChannelPromise promise);
void disconnect(ChannelHandlerContext ctx, ChannelPromise promise);
void close(ChannelHandlerContext ctx, ChannelPromise promise);
void deregister(ChannelHandlerContext ctx, ChannelPromise promise);
void write(ChannelHandlerContext ctx, Object message, ChannelPromise promise);
void flush(ChannelHandlerContext ctx);
void read(ChannelHandlerContext ctx);
```

ChannelHandlerContext类也被修改来反映上述提到的变化:

```java
// Before:
ctx.sendUpstream(evt);

// After:
ctx.fireChannelRead(receivedMessage);
```

如果开发者有特殊需求，确实需要监听自己的事件类型，ChannelHandler也提供了一个处理器方法叫做userEventTriggered()。发送自定义事件类型可参考`io.netty.handler.timeout.IdleStateHandler`中发送`IdleStateEvent`的代码。处理自定义事件的代码如下

```java
@Override
public void userEventTriggered(ChannelHandlerContext ctx, Object evt)
        throws Exception {
    if (evt instanceof IdleStateEvent) {
        IdleStateEvent event = (IdleStateEvent) evt;
        if (event.state().equals(IdleState.READER_IDLE)) {
            System.out.println("READER_IDLE");
            // 超时关闭channel
            ctx.close();
        } else if (event.state().equals(IdleState.WRITER_IDLE)) {
            System.out.println("WRITER_IDLE");
        } else if (event.state().equals(IdleState.ALL_IDLE)) {
            System.out.println("ALL_IDLE");
            // 发送心跳
            ctx.channel().write("ping\n");
        }
    }
    super.userEventTriggered(ctx, evt);
}
```

## 4.x的netty里Channel的write方法不再自动flush

3.x的netty里Channel的write方法会自动flush, 而netty4.x里不会了，这样程序员可以按照业务逻辑write响应，最后一次flush。但千万要记住最后必须flush了。当然也可以直接用writeAndFlush方法。

## 入站流量挂起

3.x有一个由Channel.setReadable(boolean)提供的不是很明显的入站流量挂起机制。它引入了在ChannelHandler之间的复杂交互操作，同时处理器由于不正确实现而很容易互相干扰。
4.x里，新的名为read()的出站操作增加了。如果你使用Channel.config().setAutoRead(false)来关闭默认的auto-read标志，Netty不会读入任何东西，直到你显式地调用read()操作。一旦你发布的read()操作完成，同时通道再次停止读，一个名为channelReadComplete()的入站事件会触发一遍你能够重新发布另外的read()操作。你同样也可以拦截read()操作来执行更多高级的流量控制。

如下面的代码

```java
@Override
public void channelActive(ChannelHandlerContext ctx) throws Exception {
    //连接建立后，设置为不自动读入站流量
    ctx.channel().config().setAutoRead(false);
    super.channelActive(ctx);
}

@Override
public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
    //这里可根据条件，决定是否再读一次
    ctx.channel().read();
    super.channelReadComplete(ctx);
}
```

## 调度任意的任务到一个I/O线程里运行

当一个Channel被注册到EventLoopGroup时，Channel实际上是注册到由EventLoopGroup管理EventLoop中的一个。在4.x里，EventLoop实现了java.utilconcurrent.ScheduledExecutorService接口。这意味着用户可以在一个用户通道归属的I/O线程里执行或调度一个任意的Runnable或Callable。随着新的娘好定义的线程模型的到来（稍后会介绍），它变得极其容易地编写一个线程安全的处理器。

```java
public class MyHandler extends ChannelOutboundHandlerAdapter {
    ...
    public void flush(ChannelHandlerContext ctx, ChannelFuture f) {
        ...
        ctx.flush(f);

        // Schedule a write timeout.
        ctx.executor().schedule(new MyWriteTimeoutTask(), 30, TimeUnit.SECONDS);
        ...
    }
}
```

## AttributeMap

在4.x里，一个名为AttributeMap的新接口被加入了，它被Channel和ChannelHandlerContext继承。作为替代，ChannelLocal和Channel.attachment被移除。这些属性会在他们关联的Channel被垃圾回收的同时回收。这个确实比原来方便不少。

```java
public class MyHandler extends ChannelInboundHandlerAdapter<MyMessage> {

    private static final AttributeKey<MyState> STATE =
            new AttributeKey<MyState>("MyHandler.state");

    @Override
    public void channelRegistered(ChannelHandlerContext ctx) {
        ctx.attr(STATE).set(new MyState());
        ctx.fireChannelRegistered();
    }

    @Override
    public void messageReceived(ChannelHandlerContext ctx, MyMessage msg) {
        MyState state = ctx.attr(STATE).get();
    }
    ...
}
```

## ChannelFuture拆分为ChannelFuture和ChannelPromise

在4.x里，ChannelFuture已经被拆分为ChannelFuture和ChannelPromise了。这不仅仅是让异步操作里的生产者和消费者间的约定更明显，同样也是得在使用从链中返回的ChannelFuture更加安全，因为ChannelFuture的状态是不能改变的。
由于这个编号，一些方法现在都采用ChannelPromise而不是ChannelFuture来改变它的状态。两者的核心区别是ChannelFuture的状态是不可改变的，而ChannelPromise可以。

如下面的代码

```
@Override
public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
    if (timeoutNanos > 0) {
        promise = promise.unvoid();
        scheduleTimeout(ctx, promise);
    }
    //下面的方法会改变promise的状态
    ctx.write(msg, promise);
}
```

## 不再有ExecutionHandler

在4.x里，不再有ExecutionHandler，而是提供DefaultEventExecutorGroup，可以在添加业务ChannelHandler时指定业务Handler运行所在的业务线程池，如下面的代码。

```java
private final EventExecutorGroup businessGroup = new DefaultEventExecutorGroup(4);
private final EventLoopGroup bossGroup = new NioEventLoopGroup();
private final EventLoopGroup workerGroup = new NioEventLoopGroup();

private void start() throws InterruptedException {
    ServerBootstrap b = new ServerBootstrap();
    b.group(bossGroup, workerGroup).channel(NioServerSocketChannel.class)
            .option(ChannelOption.SO_REUSEADDR, true)
            .childOption(ChannelOption.TCP_NODELAY, true)
            .childOption(ChannelOption.ALLOCATOR, PooledByteBufAllocator.DEFAULT)
            .handler(new CheckAcceptHandler())
            .childHandler(new ChannelInitializer<SocketChannel>() {
                @Override
                public void initChannel(SocketChannel ch)
                        throws Exception {
                    ch.pipeline().addLast("decoder", new LineBasedFrameDecoder(4096));
                    ch.pipeline().addLast("stringDecoder", new StringDecoder(StandardCharsets.UTF_8));
                    ch.pipeline().addLast("lineEncoder", new LineEncoder(StandardCharsets.UTF_8));
                    //指定了业务handler运行所在的业务线程池
                    ch.pipeline().addLast(businessGroup, "logicHandler", new ServerLogicalHandler());
                }
            });
    final int listenPort = 8888;
    b.bind(listenPort).sync();
}
```

## 灵活的I/O线程分配

* 在4.x里，能够从一个已存在的jdk套接字上创建一个Channel

```java
java.nio.channels.SocketChannel mySocket = java.nio.channels.SocketChannel.open();

// Perform some blocking operation here.
...

// Netty takes over.
SocketChannel ch = new NioSocketChannel(mySocket);
EventLoopGroup group = ...;
group.register(ch);
```

* 在4.x里，能够取消注册和重新注册一个Channel从/到一个I/O线程。例如，你能够利用Netty提供的高层次无阻塞I/O的优势来解决复杂的协议，然后取消注册Channel并且切换到阻塞模式来在可能的最大吞吐量下传输一个文件。当然，它能够再次注册已经取消了注册的Channel。

```java
java.nio.channels.FileChannel myFile = ...;
java.nio.channels.SocketChannel mySocket = java.nio.channels.SocketChannel.open();

// Perform some blocking operation here.
...

// Netty takes over.
SocketChannel ch = new NioSocketChannel(mySocket);
EventLoopGroup group = ...;
group.register(ch);
...

// Deregister from Netty.
ch.deregister().sync();

// Perform some blocking operation here.
mySocket.configureBlocking(true);
myFile.transferFrom(mySocket, ...);

// Register back again to another event loop group.
EventLoopGroup anotherGroup = ...;
anotherGroup.register(ch);
```

## 简化的关闭

在4.x里，releaseExternalResources()不必再用了。你可以通过调用EventLoopGroup.shutdown()直接地关闭所有打开的连接同时使所有I/O线程停止，就像你使用java.util.concurrent.ExecutorService.shutdown()关闭你的线程池一样。


## 参考

`http://www.infoq.com/cn/articles/netty-version-upgrade-history-thread-part`
`https://www.oschina.net/translate/netty-4-0-new-and-noteworthy`
`https://www.oschina.net/question/139577_146101`
`http://netty.io/wiki/new-and-noteworthy-in-4.0.html`
