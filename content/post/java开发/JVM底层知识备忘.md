---
title: JVM底层知识备忘
tags:
  - java
categories:
  - java开发
date: 2016-04-14 00:28:00+08:00
---
今天的工作涉及了不少JVM底层的知识，趁着今天刚翻阅资料，还记得一些内容，将我常用的JVM知识整理一下。

## JVM组成

![JVM组成](http://blog-images-1252238296.cosgz.myqcloud.com/jvm_all.png)

**JVM = 类加载器 classloader + 执行引擎 execution engine + 运行时数据区域 runtime data area**

## 类加载器 classloader

类加载器classloader的作用就是装载.class文件，当然类文件不一定是以.class文件的方式存储。

类加载器classloader有两种装载类的时机：

    1. 隐式：运行过程中，碰到new方式生成对象时，隐式调用classLoader装载类到JVM
    2. 显式：通过class.forname()动态加载类到JVM

### 类加载器的工作方式

类的加载过程采用双亲委托机制，这种机制能更好的保证 Java 平台的安全。
该模型要求除了顶层的Bootstrap class loader启动类加载器外，其余的类加载器都应当有自己的父类加载器。子类加载器和父类加载器不是以继承（Inheritance）的关系来实现，而是通过组合（Composition）关系来复用父加载器的代码。每个类加载器都有自己的命名空间。（由该加载器及所有父类加载器所加载的类组成，在同一个命名空间中，不会出现类的完整名字（包括类的包名）相同的两个类；在不同的命名空间中，有可能会出现类的完整名字（包括类的包名）相同的两个类）

双亲委派模型的工作过程如下：
    1. 当前 ClassLoader 首先从自己已经加载的类的缓存中查询是否此类已经加载，如果已经加载则直接返回原来已经加载的类。
    2. 当前 classLoader 的缓存中没有找到被加载的类的时候，委托父类加载器去加载，父类加载器采用同样的策略，首先查看自己的缓存，然后委托父类的父类去加载，一直到 bootstrap ClassLoader.
    3. 当所有的父类加载器都没有加载的时候，再由当前的类加载器加载，并将其放入它自己的缓存中，以便下次有加载请求的时候直接返回。

这种工作方式的原因：
主要是为了安全性，避免用户自己编写的类动态替换 Java 的一些核心类，比如String，同时也避免了重复加载，因为 JVM中区分不同类，不仅仅是根据类名，相同的 class 文件被不同的 ClassLoader加载就是不同的两个类，如果相互转型的话会抛java.lang.ClassCaseException.

### 类加载器的层次结构

![类加载器的层次结构](http://blog-images-1252238296.cosgz.myqcloud.com/classloaders.png)

    1. Bootstrap class loader: 当运行 java 虚拟机时，这个类加载器被创建，它负责加载虚拟机的核心类库，如 java.lang.* 等。例如 java.lang.Object 就是由根类加载器加载的。
    2. Extension class loader: 这个加载器加载出了基本 API 之外的一些拓展类。
    3. AppClass Loader: 加载应用程序和程序员自定义的类。
    4. User-defined Class Loader: 用户定制的类加载器，Java 提供了抽象类java.lang.ClassLoader，所有用户自定义的类加载器应该继承 ClassLoader 类。

### 执行引擎 JVM Runtime

执行引擎JVM Runtime的作用是执行字节码，或者执行本地方法

### GC

垃圾回收机制是由垃圾收集器Garbage Collection GC来实现的，GC是后台的守护进程。它的特别之处是它是一个低优先级进程，但是可以根据内存的使用情况动态的调整他的优先级。因此，它是在内存中低到一定限度时才会自动运行，从而实现对内存的回收。这就是垃圾回收的时间不确定的原因。

因为GC也是进程，也要消耗CPU等资源，如果GC执行过于频繁会对java的程序的执行产生较大的影响，所以JVM中GC是不定期的，同时采用分代的方式进行对象的收集，以缩短GC对应用造成的暂停。

GC只能回收通过new关键字申请的堆内内存，但是堆上的内存并不完全是通过new申请分配的。还有一些本地方法（一般是调用的C方法）。这部分“特殊的内存”如果不手动释放，就会导致内存泄露，gc是无法回收这部分内存的。
所以需要在finalize中用本地方法(native method)如free操作等，再使用gc方法。


### 运行时数据区域 runtime data area

JVM 运行时数据区 (JVM Runtime Area) 其实就是指 JVM在运行期间，其对JVM内存空间的划分和分配。JVM在运行时将数据划分为了6个区域来存储。
程序员写的所有程序都被加载到运行时数据区域中，不同类别存放在heap, java stack, native method stack, PC register, method area.

![运行时数据区域](http://blog-images-1252238296.cosgz.myqcloud.com/runtime_data_area.png)

    1. PC程序计数器
    一块较小的内存空间，可以看做是当前线程所执行的字节码的行号指示器, NAMELY存储每个线程下一步将执行的JVM指令，如该方法为native的，则PC寄存器中不存储任何信息。Java 的多线程机制离不开程序计数器，每个线程都有一个自己的PC，以便完成不同线程上下文环境的切换。
    
    2. java虚拟机栈
    与 PC 一样，java 虚拟机栈也是线程私有的。每一个 JVM 线程都有自己的java 虚拟机栈，这个栈与线程同时创建，它的生命周期与线程相同。虚拟机栈描述的是Java方法执行的内存模型：每个方法被执行的时候都会同时创建一个栈帧（Stack Frame）用于存储局部变量表、操作数栈、动态链接、方法出口等信息。每一个方法被调用直至执行完成的过程就对应着一个栈帧在虚拟机栈中从入栈到出栈的过程。
    
    3. 本地方法栈
    与虚拟机栈的作用相似，虚拟机栈为虚拟机执行执行java方法服务，而本地方法栈则为虚拟机使用到的本地方法服务。
    
    4. Java堆
    被所有线程共享的一块存储区域，在虚拟机启动时创建，它是JVM用来存储对象实例以及数组值的区域，可以认为Java中所有通过new创建的对象的内存都在此分配。
    Java堆在JVM启动的时候就被创建，堆中储存了各种对象，这些对象被Garbage Collector（垃圾回收器）所管理。这些对象无需、也无法显示地被销毁。
    Java堆分为两块：新生代New Generation和旧生代Old Generation
    
    5. 方法区
    方法区和堆区域一样，是各个线程共享的内存区域，它用于存储每一个类的结构信息，例如运行时常量池，成员变量和方法数据，构造函数和普通函数的字节码内容，还包括一些在类、实例、接口初始化时用到的特殊方法。当开发人员在程序中通过Class对象中的getName、isInstance等方法获取信息时，这些数据都来自方法区。
    方法区也是全局共享的，在虚拟机启动时候创建。在一定条件下它也会被GC。这块区域对应Permanent Generation 持久代。 XX：PermSize指定大小。
    
    6. 运行时常量池
    其空间从方法区中分配，存放的为类中固定的常量信息、方法和域的引用信息。

执行引擎中的GC主要是对Java堆空间进行内存回收，而Java中的垃圾回收技术还很复杂，这里简单记录一下

## 垃圾回收技术

### Java堆的分代

由于GC需要消耗一些资源和时间的，Java在对对象的生命周期特征进行分析后，采用了分代的方式来进行对象的收集，即按照新生代、旧生代的方式来对对象进行收集，以尽可能的缩短GC对应用造成的暂停. heap 的组成有三区域/世代：

![Java Heap Memory](http://blog-images-1252238296.cosgz.myqcloud.com/java_heap.png)

    1. 新生代 Young Generation
        1.1 Eden Space 任何新进入运行时数据区域的实例都会存放在此
        1.2 S0 Suvivor Space 存在时间较长，经过垃圾回收没有被清除的实例，就从Eden 搬到了S0
        1.3 S1 Survivor Space 同理，存在时间更长的实例，就从S0 搬到了S1
    2. 旧生代 Old Generation/tenured 存在时间更长的实例，对象多次回收没被清除，就从S1 搬到了tenured
    3. Perm 存放运行时数据区的方法区

### JVM收集器

![JVM收集器](http://blog-images-1252238296.cosgz.myqcloud.com/jvm_heap_gens.jpg)

上面有7中收集器，分为两块，上面为新生代收集器，下面是老年代收集器。如果两个收集器之间存在连线，就说明它们可以搭配使用。

* Serial(串行GC)收集器

Serial收集器是一个新生代收集器，单线程执行，使用复制算法。它在进行垃圾收集时，必须暂停其他所有的工作线程(用户线程)。是Jvm client模式下默认的新生代收集器。对于限定单个CPU的环境来说，Serial收集器由于没有线程交互的开销，专心做垃圾收集自然可以获得最高的单线程收集效率。

* ParNew(并行GC)收集器

ParNew收集器其实就是serial收集器的多线程版本，除了使用多条线程进行垃圾收集之外，其余行为与Serial收集器一样。

* Parallel Scavenge(并行回收GC)收集器

Parallel Scavenge收集器也是一个新生代收集器，它也是使用复制算法的收集器，又是并行多线程收集器。parallel Scavenge收集器的特点是它的关注点与其他收集器不同，CMS等收集器的关注点是尽可能地缩短垃圾收集时用户线程的停顿时间，而parallel Scavenge收集器的目标则是达到一个可控制的吞吐量。吞吐量= 程序运行时间/(程序运行时间 + 垃圾收集时间)，虚拟机总共运行了100分钟。其中垃圾收集花掉1分钟，那吞吐量就是99%。

* Serial Old(串行GC)收集器

Serial Old是Serial收集器的老年代版本，它同样使用一个单线程执行收集，使用“标记-整理”算法。主要使用在Client模式下的虚拟机。

* Parallel Old(并行GC)收集器

Parallel Old是Parallel Scavenge收集器的老年代版本，使用多线程和“标记-整理”算法。

* CMS(并发GC)收集器

CMS(Concurrent Mark Sweep)收集器是一种以获取最短回收停顿时间为目标的收集器。CMS收集器是基于“标记-清除”算法实现的

* G1收集器

G1(Garbage First)收集器是JDK1.7提供的一个新收集器，G1收集器基于“标记-整理”算法实现，也就是说不会产生内存碎片。还有一个特点之前的收集器进行收集的范围都是整个新生代或老年代，而G1将整个Java堆(包括新生代，老年代)

#### Client、Server模式默认GC

| JVM模式	  |新生代GC方式       | 老年代和持久代GC方式            |
| -         | -                 | -                               |
|Client     | Serial 串行GC     |	Serial Old 串行GC               |
|Server     |	Parallel Scavenge |  并行回收GC	Parallel Old 并行GC |

#### Sun/oracle JDK GC组合方式

| JVM参数　| 	新生代GC方式 |	老年代和持久代GC方式 |
| -        | - | - |
|-XX:+UseSerialGC | Serial 串行GC |	Serial Old 串行GC |
|-XX:+UseParallelGC |	Parallel Scavenge  并行回收GC |	Serial Old  并行GC|
|-XX:+UseConcMarkSweepGC |	ParNew 并行GC |	CMS 并发GC, 当出现“Concurrent Mode Failure”时,采用Serial Old 串行GC |
|-XX:+UseParNewGC|ParNew 并行GC|Serial Old 串行GC|
|-XX:+UseParallelOldGC|Parallel Scavenge|并行回收GC	Parallel Old 并行GC|
|-XX:+UseConcMarkSweepGC -XX:-UseParNewGC |Serial 串行GC |	CMS 并发GC, 当出现“Concurrent Mode Failure”时,采用Serial Old 串行GC |


### 不同世代采用不同回收方法

通俗的回收方法：
    1. 引用计数法。简单但速度很慢。缺陷是：不能处理循环引用的情况。
    2. 停止-复制(stop and copy)。效率低，需要的空间大，优点，不会产生碎片。
    3. 标记 - 清除算法 (mark and sweep)。速度较快，占用空间少，标记清除后会产生大量的碎片。

分代回收：
    1. 在新生代中，使用“停止-复制”算法进行Minor GC，将新生代内存分为2部分，1部分Eden区较大，1部分Survivor比较小，并被划分为两个等量的部分。每次进行清理时，将Eden区和一个Survivor中仍然存活的对象拷贝到 另一个Survivor中，然后清理掉Eden和刚才的Survivor。
    由于绝大部分的对象都是短命的，甚至存活不到Survivor中，所以，Eden区与Survivor的比例较大，HotSpot默认是8:1，即分别占新生代的80%，10%，10%。如果一次回收中，Survivor+Eden中存活下来的内存超过了10%，则需要将一部分对象分配到 老年代。用-XX:SurvivorRatio参数来配置Eden区域Survivor区的容量比值。
    2. 老年代存储的对象比年轻代多得多，而且不乏大对象，对老年代进行内存清理时，如果使用停止-复制算法，则相当低效。一般，老年代用的算法是标记-整理算法，即：标记出仍然存活的对象（存在引用的），将所有存活的对象向一端移动，以保证内存的连续。在发生Minor GC时，虚拟机会检查每次晋升进入老年代的大小是否大于老年代的剩余空间大小，如果大于，则直接触发一次Full GC。
    3. 永久代的回收有两种：常量池中的常量，无用的类信息，常量的回收很简单，没有引用了就可以被回收。对于无用的类进行回收，必须保证3点：1）类的所有实例都已经被回收 2）加载类的ClassLoader已经被回收 3）类对象的Class对象没有被引用（即没有通过反射引用该类的地方）
永久代的回收并不是必须的，可以通过参数来设置是否对类进行回收。HotSpot提供-Xnoclassgc进行控制

## 常用JVM参数

1. -Xms或-XX:InitialHeapSize 初始堆容量
2. -Xmx或-XX:MaxHeapSize 最大堆容量
3. -Xmn或-XX:NewSize -XX:MaxNewSize 新生代容量
4. -XX:SurvivorRatio 新生代中eden的比例，如果设置为8，意味着新生代中eden占据80%的空间，两个survivor分别占据10%
5. -XX:NewRatio 年轻代(包括Eden和两个Survivor区)与年老代的比值(除去持久代)
6. -XX:PermSize 初始持久代容量
7. -XX:MaxPermSize 最大持久代容量
8. -XX:MaxDirectMemorySize 最大Java NIO Direct Buffer容量
9. -XX:+PrintGCDetails 让jvm在每次发生gc的时候打印日志，利于分析gc的原因和状况
10. -Xss 每个线程的堆栈大小，JDK5.0以后每个线程堆栈大小为1M，在相同物理内存下,减小这个值能生成更多的线程，一般小的应用， 如果栈不是很深， 应该是128k够用的大的应用建议使用256k。这个选项对性能影响比较大，需要严格的测试。
11. -XX:+DisableExplicitGC 关闭System.gc()
12. -XX:MaxTenuringThreshold 垃圾最大年龄，如果设置为0的话,则年轻代对象不经过Survivor区,直接进入年老代。对于年老代比较多的应用,可以提高效率.如果将此值设置为一个较大值,则年轻代对象会在Survivor区进行多次复制,这样可以增加对象再年轻代的存活 时间,增加在年轻代即被回收的概率，该参数只有在串行GC时才有效.
13. -Xnoclassgc 禁用持久代垃圾回收
14. -XX:+PrintGCDateStamps 打印GC发生的时间信息
15. -Xloggc:filename  指定gc日志存储路径，如-Xloggc:/tmp/gc.log
16. -XX:+HeapDumpOnOutOfMemoryError 当出现OOM时将Heap dump出来
17. -XX:HeapDumpPath  Heap dump出来时保存的目录
18. -XX:ErrorFile=targetDir/hs_err_pid_%p.log  JVM crash日志的存储路径
19. -XX:+CMSPermGenSweepingEnabled -XX:+CMSClassUnloadingEnabled 为了避免Perm区满引起的Full GC，建议开启CMS回收Perm区选项
20. -XX:CMSInitiatingOccupancyFraction=80 默认CMS是在tenured generation沾满68%的时候开始进行CMS收集，如果你的年老代增长不是那么快，并且希望降低CMS次数的话，可以适当调高此值
21. -XX:+ExplicitGCInvokesConcurrent 调用System.gc()时触发CMS Full GC，需配合CMS使用
22. -verbose:gc 记录 GC 运行以及运行时间，一般用来查看 GC 是否是应用的瓶颈
23. -XX:+UseG1GC 使用G1垃圾回收算法
24. -XX:PretenureSizeThreshold　直接晋升到老年代对象的大小，设置这个参数后，大于这个参数的对象将直接在老年代分配
25. -XX:UseAdaptiveSizePolicy　动态调整java堆中各个区域的大小以及进入老年代的年龄
26. -XX:ParallelGCThreads　设置并行GC进行内存回收的线程数
27. -XX:GCTimeRatio　GC时间占总时间的比列，默认值为99，即允许1%的GC时间，仅在使用Parallel Scavenge 收集器时有效
28. -XX:MaxGCPauseMillis　设置GC的最大停顿时间，在Parallel Scavenge 收集器下有效
29. -XX:+UseCMSCompactAtFullCollection　由于CMS收集器会产生碎片，此参数设置在垃圾收集器后是否需要一次内存碎片整理过程，仅在CMS收集器时有效
30. -XX:CMSFullGCBeforeCompaction　设置CMS收集器在进行n次垃圾收集后再进行一次内存碎片整理过程，通常与UseCMSCompactAtFullCollection参数一起使用
31. -XX:+CMSParallelRemarkEnabled　降低CMS标记停顿
32. -XX:MinHeapFreeRatio　指定 jvm heap 在使用率小于 n 的情况下,　heap进行收缩,　Xmx==Xms的情况下无效, 如:-XX:MinHeapFreeRatio=30
33. -XX:MaxHeapFreeRatio　指定 jvm heap 在使用率大于 n 的情况下,　heap进行扩张,　Xmx==Xms的情况下无效, 如:-XX:MaxHeapFreeRatio=70
34. -XX:+UseGCLogFileRotation　开启回转日志文件
35. -XX:GCLogFileSize　设置单个文件最大的文件大小
36. -XX:NumberOfGCLogFiles　设置回转日志文件的个数
37. -XX:+PrintFlagsFinal 打印出几乎所有的JVM支持的参数以及他们的默认值
38. -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=8090 开启Java远程调试
39. -Dcom.sun.management.jmxremote=true -Djava.rmi.server.hostname=${ip} -Dcom.sun.management.jmxremote.port=${port} -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false 允许jconsole接入
40. -verbose:[class|gc|jni] 开启指定类型的日志输出
