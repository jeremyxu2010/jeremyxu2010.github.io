---
title: JVM的Finalization Delay引起的OOM
tags:
  - java
  - nio
  - oom
categories:
  - java开发
date: 2016-07-13 22:03:00+08:00
---
今天在压力测试环境某一个服务出现crash了，经过一番检查，终于发现是由于JVM的Finalization Delay引起的，这个问题比较特殊，这里记录一下。

这个服务是用Java写的，主要完成的功能是根据特定的指令文件生成mp4文件，用到的java库主要有javacv，这个库底层其实是使用JNI调用操作系统里安装的ffmpeg。

## 检查日志文件

首先检查日志文件，发现日志里出现了OOM的报错

```java
java.lang.OutOfMemoryError: null
	at sun.misc.Unsafe.allocateMemory(Native Method) ~[na:1.7.0_79]
	at java.nio.DirectByteBuffer.<init>(DirectByteBuffer.java:127) ~[na:1.7.0_79]
	at java.nio.ByteBuffer.allocateDirect(ByteBuffer.java:306) ~[na:1.7.0_79]
	at org.bytedeco.javacv.Frame.<init>(Frame.java:105) ~[javacv-1.1.jar:1.1]
	at org.bytedeco.javacv.Java2DFrameConverter.getFrame(Java2DFrameConverter.java:712) ~[javacv-1.1.jar:1.1]
	at org.bytedeco.javacv.Java2DFrameConverter.getFrame(Java2DFrameConverter.java:679) ~[javacv-1.1.jar:1.1]
	at org.bytedeco.javacv.Java2DFrameConverter.getFrame(Java2DFrameConverter.java:673) ~[javacv-1.1.jar:1.1]
	at org.bytedeco.javacv.Java2DFrameConverter.convert(Java2DFrameConverter.java:62) ~[javacv-1.1.jar:1.1]
```

很明显这里是申请`DirectByteBuffer`出现了OOM，所以应该是`Direct Memory`申请太多了。为了确认问题，将服务跑起来，使用`jconsole`看了下JVM的堆内存使用情况，发现堆内存使用一直都是比较稳定的，但使用`top -p ${pid}`查看进程占用的内存，发现`RES`字段的值一直是在增长的，而且增长得很快，不到半个小时值就从原来的500M增长到1.6G。

## 分析代码

接下来看一下关键代码

```java
    public void encodeFrame(BufferedImage image, long frameTime) {
        try {
            long t = frameTime * 1000L;
            if(t>recorder.getTimestamp()) {
                recorder.setTimestamp(t);
            }
            Frame frame = java2dConverter.convert(image);
            recorder.record(frame);
        } catch (FrameRecorder.Exception e) {
            log.error("JavaCVMp4Encoder encode frame error.", e);
        }
    }
```

业务层是不停地调用`encodeFrame`将每一张图片编码到mp4文件里。

而`java2dConverter.convert(image);`这句代码的实现里会申请一个`DirectByteBuffer`。如下面的代码。

```java
    public Frame(int width, int height, int depth, int channels) {
        int pixelSize = Math.abs(depth) / 8;
        this.imageWidth = width;
        this.imageHeight = height;
        this.imageDepth = depth;
        this.imageChannels = channels;
        this.imageStride = ((imageWidth * imageChannels * pixelSize + 7) & ~7) / pixelSize; // 8-byte aligned
        this.image = new Buffer[1];

        ByteBuffer buffer = ByteBuffer.allocateDirect(imageHeight * imageStride * pixelSize).order(ByteOrder.nativeOrder());
        switch (imageDepth) {
            case DEPTH_BYTE:
            case DEPTH_UBYTE:  image[0] = buffer;                  break;
            case DEPTH_SHORT:
            case DEPTH_USHORT: image[0] = buffer.asShortBuffer();  break;
            case DEPTH_INT:    image[0] = buffer.asIntBuffer();    break;
            case DEPTH_LONG:   image[0] = buffer.asLongBuffer();   break;
            case DEPTH_FLOAT:  image[0] = buffer.asFloatBuffer();  break;
            case DEPTH_DOUBLE: image[0] = buffer.asDoubleBuffer(); break;
            default: throw new UnsupportedOperationException("Unsupported depth value: " + imageDepth);
        }
    }
```

这里`ByteBuffer.allocateDirect`方法申请的`DirectByteBuffer`并不是Java堆内存，而是直接在C堆上申请的。而`DirectByteBuffer`申请的C堆内存释放很特殊，并不是简单地由JVM GC完成的。

先看一下`DirectByteBuffer`的定义

```java
class DirectByteBuffer extends MappedByteBuffer implements DirectBuffer {
  ...
  protected static final Unsafe unsafe = Bits.unsafe();
  ...
  private static class Deallocator
        implements Runnable
    {

        private static Unsafe unsafe = Unsafe.getUnsafe();

        private long address;
        private long size;
        private int capacity;

        private Deallocator(long address, long size, int capacity) {
            assert (address != 0);
            this.address = address;
            this.size = size;
            this.capacity = capacity;
        }

        public void run() {
            if (address == 0) {
                // Paranoia
                return;
            }
            unsafe.freeMemory(address);
            address = 0;
            Bits.unreserveMemory(size, capacity);
        }

    }

    private final Cleaner cleaner;
    ...

    DirectByteBuffer(int cap) {                   // package-private

        super(-1, 0, cap, cap);
        boolean pa = VM.isDirectMemoryPageAligned();
        int ps = Bits.pageSize();
        long size = Math.max(1L, (long)cap + (pa ? ps : 0));
        Bits.reserveMemory(size, cap);

        long base = 0;
        try {
            base = unsafe.allocateMemory(size);
        } catch (OutOfMemoryError x) {
            Bits.unreserveMemory(size, cap);
            throw x;
        }
        unsafe.setMemory(base, size, (byte) 0);
        if (pa && (base % ps != 0)) {
            // Round up to page boundary
            address = base + ps - (base & (ps - 1));
        } else {
            address = base;
        }
        cleaner = Cleaner.create(this, new Deallocator(base, size, cap));
        att = null;



    }
    ...
}
```

可以看到创建`DirectByteBuffer`对象时实际上使用`unsafe.allocateMemory`申请一块C堆内存的。`DirectByteBuffer`对象内部有一个`Cleaner cleaner`，看样子应该是这个东东负责对申请申请的C堆内存进行释放的。看一下`Cleaner`的定义：

```java
public class Cleaner extends PhantomReference<Object> {
...
    private static final ReferenceQueue<Object> dummyQueue = new ReferenceQueue();
        private Cleaner(Object var1, Runnable var2) {
        super(var1, dummyQueue);
        this.thunk = var2;
    }

    public static Cleaner create(Object var0, Runnable var1) {
        return var1 == null?null:add(new Cleaner(var0, var1));
    }

    public void clean() {
        if(remove(this)) {
            try {
                this.thunk.run();
            } catch (final Throwable var2) {
                AccessController.doPrivileged(new PrivilegedAction() {
                    public Void run() {
                        if(System.err != null) {
                            (new Error("Cleaner terminated abnormally", var2)).printStackTrace();
                        }

                        System.exit(1);
                        return null;
                    }
                });
            }

        }
    }
...
}
```

原来`Cleaner`实际上是一个`PhantomReference`

> `PhantomReference`虚引用主要用来跟踪对象被垃圾回收器回收的活动。虚引用与软引用和弱引用的一个区别在于：虚引用必须和引用队列 （ReferenceQueue）联合使用。当垃圾回收器准备回收一个对象时，如果发现它还有虚引用，就会在回收对象的内存之前，把这个虚引用加入到与之关联的引用队列中。

在这个场景里也就是说当JVM垃圾回收器准备回收某个`DirectByteBuffer`对象时，发现这个`DirectByteBuffer`对象有虚引用，就会将虚引用加入到与之关联的引用队列中。将虚引用加入到与之关联的引用队列中有什么作用？看一下`Reference`的实现代码

```java
public abstract class Reference<T> {
  ...
  private T referent;
  ...

  static private class Lock { }
    private static Lock lock = new Lock();


    /* List of References waiting to be enqueued.  The collector adds
     * References to this list, while the Reference-handler thread removes
     * them.  This list is protected by the above lock object. The
     * list uses the discovered field to link its elements.
     */
    private static Reference<Object> pending = null;

    /* High-priority thread to enqueue pending References
     */
    private static class ReferenceHandler extends Thread {

        private static void ensureClassInitialized(Class<?> clazz) {
            try {
                Class.forName(clazz.getName(), true, clazz.getClassLoader());
            } catch (ClassNotFoundException e) {
                throw (Error) new NoClassDefFoundError(e.getMessage()).initCause(e);
            }
        }

        static {
            // pre-load and initialize InterruptedException and Cleaner classes
            // so that we don't get into trouble later in the run loop if there's
            // memory shortage while loading/initializing them lazily.
            ensureClassInitialized(InterruptedException.class);
            ensureClassInitialized(Cleaner.class);
        }

        ReferenceHandler(ThreadGroup g, String name) {
            super(g, name);
        }

        public void run() {
            while (true) {
                tryHandlePending(true);
            }
        }
    }

    /**
     * Try handle pending {@link Reference} if there is one.<p>
     * Return {@code true} as a hint that there might be another
     * {@link Reference} pending or {@code false} when there are no more pending
     * {@link Reference}s at the moment and the program can do some other
     * useful work instead of looping.
     *
     * @param waitForNotify if {@code true} and there was no pending
     *                      {@link Reference}, wait until notified from VM
     *                      or interrupted; if {@code false}, return immediately
     *                      when there is no pending {@link Reference}.
     * @return {@code true} if there was a {@link Reference} pending and it
     *         was processed, or we waited for notification and either got it
     *         or thread was interrupted before being notified;
     *         {@code false} otherwise.
     */
    static boolean tryHandlePending(boolean waitForNotify) {
        Reference<Object> r;
        Cleaner c;
        try {
            synchronized (lock) {
                if (pending != null) {
                    r = pending;
                    // 'instanceof' might throw OutOfMemoryError sometimes
                    // so do this before un-linking 'r' from the 'pending' chain...
                    c = r instanceof Cleaner ? (Cleaner) r : null;
                    // unlink 'r' from 'pending' chain
                    pending = r.discovered;
                    r.discovered = null;
                } else {
                    // The waiting on the lock may cause an OutOfMemoryError
                    // because it may try to allocate exception objects.
                    if (waitForNotify) {
                        lock.wait();
                    }
                    // retry if waited
                    return waitForNotify;
                }
            }
        } catch (OutOfMemoryError x) {
            // Give other threads CPU time so they hopefully drop some live references
            // and GC reclaims some space.
            // Also prevent CPU intensive spinning in case 'r instanceof Cleaner' above
            // persistently throws OOME for some time...
            Thread.yield();
            // retry
            return true;
        } catch (InterruptedException x) {
            // retry
            return true;
        }

        // Fast path for cleaners
        if (c != null) {
            c.clean();
            return true;
        }

        ReferenceQueue<? super Object> q = r.queue;
        if (q != ReferenceQueue.NULL) q.enqueue(r);
        return true;
    }

    static {
        ThreadGroup tg = Thread.currentThread().getThreadGroup();
        for (ThreadGroup tgn = tg;
             tgn != null;
             tg = tgn, tgn = tg.getParent());
        Thread handler = new ReferenceHandler(tg, "Reference Handler");
        /* If there were a special system-only priority greater than
         * MAX_PRIORITY, it would be used here
         */
        handler.setPriority(Thread.MAX_PRIORITY);
        handler.setDaemon(true);
        handler.start();

        // provide access in SharedSecrets
        SharedSecrets.setJavaLangRefAccess(new JavaLangRefAccess() {
            @Override
            public boolean tryHandlePendingReference() {
                return tryHandlePending(false);
            }
        });
    }
    ...
    Reference(T referent, ReferenceQueue<? super T> queue) {
        this.referent = referent;
        this.queue = (queue == null) ? ReferenceQueue.NULL : queue;
    }

}
```

这里代码看着有些糊涂，并没有代码给`pending`这个类变量赋值，为啥`ReferenceHandler`这个线程执行体里又在读取它的值，但看了看`private static Reference<Object> pending = null;`这一行上面的注释，想了想终于明白了，原来JVM垃圾回收器将将虚引用加入到与之关联的引用队列后，JVM垃圾回收器又负责逐个将引用队列中的引用拿出来赋于`pending`，然后通知`ReferenceHandler`线程，`ReferenceHandler`线程拿到引用后，发现如果是Cleaner，则调用其`clean`方法。然后终于与`DirectByteBuffer`里的`Deallocator`接上了，最终`DirectByteBuffer`申请的C堆内存被释放。

既然`DirectByteBuffer`申请的C堆内存释放是自动的，为啥在这个场景里会出现OOM呢？查阅java的bug记录，终于找到原因。`http://bugs.java.com/bugdatabase/view_bug.do?bug_id=4857305`，`http://bugs.java.com/bugdatabase/view_bug.do?bug_id=4469299`。

意思是如果`DirectByteBuffer`创建得过于频繁，服务器的CPU太繁忙，C堆内存还是会OOM的，原因是JVM来不及进行GC及Finalization，大量对象的销毁工作被推后，最终C堆内存无法得到释放。

## 解决方案

bug记录提到了3个解决方案：

> Insert occasional explicit System.gc() invocations to ensure that  direct buffers are reclaimed.

> Reduce the size of the young generation to force more frequent GCs.

> Explicitly pool direct buffers at the application level.

我这里采用了第一个解决方案，代码如下：

```java
    public void encodeFrame(BufferedImage image, long frameTime) {
        try {
            long t = frameTime * 1000L;
            if(t>recorder.getTimestamp()) {
                recorder.setTimestamp(t);
            }
            Frame frame = java2dConverter.convert(image);
            recorder.record(frame);
            if(System.currentTimeMillis() - lastGCTime > 60000){
                System.gc();
                System.runFinalization();
                lastGCTime = System.currentTimeMillis();
                Thread.yield();
                TimeUnit.SECONDS.sleep(3);
            }
        } catch (FrameRecorder.Exception e) {
            log.error("JavaCVMp4Encoder encode frame error.", e);
        }
    }
```

意思是说每隔1分钟显式地调用`System.gc();`与`System.runFinalization();`，并让出CPU休息3秒钟。经过长达10几个小时的测试，目前一切都正常了。

