---
title: Java开发小技巧_02
tags:
  - java
  - p3c
  - concurrent
  - log
categories:
  - java开发
date: 2017-10-24 21:10:00+08:00
---

最近阿里发布了一个插件[p3c](https://github.com/alibaba/p3c)，用于进行Java开发规约的检查扫描。由于插件的代码是开源，于是第一时间也翻查了代码，发现目前实现的检查规则主要在`/p3c-pmd/src/main/resources/rulesets`、`/idea-plugin/p3c-common/src/main/kotlin/com/alibaba/p3c/idea/inspection/standalone`目录下。将规则大致看了下，这里将自己平时开发不太注意但它提到的几点记录一下。

## 注释掉代码时留下注释原因

平时由于某些原因，不会删除代码，而只是临时将代码注释起来，应按照规范留下注释原因。`For codes which are temporarily removed and likely to be reused, use /// to add a reasonable note.`代码示例：

```java
public static void hello() {
    /// Business is stopped temporarily by the owner.
    // Business business = new Business();
    // business.active();
    System.out.println("it's finished");
}
```

## 线程池必要使用ThreadPoolExecutor的方式

线程池不允许使用 Executors 去创建，而是通过 ThreadPoolExecutor 的方式，这样
的处理方式让写的同学更加明确线程池的运行规则，规避资源耗尽的风险。
说明：Executors 返回的线程池对象的弊端如下：

* FixedThreadPool 和 SingleThreadPool:

允许的请求队列长度为 Integer.MAX_VALUE，可能会堆积大量的请求，从而导致 OOM。

* CachedThreadPool 和 ScheduledThreadPool:

允许的创建线程数量为 Integer.MAX_VALUE，可能会创建大量的线程，从而导致 OOM。

平时在开发中，不要手动地创建线程，最好使用线程池，并且线程要命名。

有两种办法创建线程池：编码法、配置法。

编码法：

```java
// use org.apache.commons.lang3.concurrent.BasicThreadFactory
ScheduledExecutorService executorService = new ScheduledThreadPoolExecutor(
  						 1,
        				 new BasicThreadFactory.Builder().namingPattern("example-schedule-pool-%d").daemon(true).build());
```

或

```java
// use com.google.common.util.concurrent.ThreadFactoryBuilder
ThreadFactory namedThreadFactory = new ThreadFactoryBuilder()
                .setNameFormat("demo-pool-%d").build();
//Common Thread Pool
ExecutorService pool = new ThreadPoolExecutor(
  				5, 
  				200,
                0L, TimeUnit.MILLISECONDS,
                new LinkedBlockingQueue<Runnable>(1024), 
                namedThreadFactory, 
                new ThreadPoolExecutor.AbortPolicy());
```

配置法：

```xml
<bean id="threadFactory" class="org.springframework.scheduling.concurrent.CustomizableThreadFactory">
  <constructor-arg value="Custom-prefix-"/>
  <property name="daemon" value="true"/>
</bean>

<bean id="rejectedExecutionHandler" class="java.util.concurrent.ThreadPoolExecutor.AbortPolicy">
</bean>

<bean id="userThreadPool"
      class="org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor">
  <property name="corePoolSize" value="10" />
  <property name="maxPoolSize" value="100" />
  <property name="queueCapacity" value="2000" />
  <property name="threadFactory" ref="threadFactory"/>
  <property name="rejectedExecutionHandler" ref="rejectedExecutionHandler"/>
</bean>
```

在代码里使用：

```java
userThreadPool.execute(new Runnable() {
  @Override
  public void run() {
    System.out.println(Thread.currentThread().getName());
  }
});
```

## 不要调用静态的SimpleDateFormat属性的format方法

由于SimpleDateFormat是非线程安全的，不要定义一个静态的SimpleDateFormat属性，然后调用其format方法。有3种方法避免这种并发冲突：

```java
private static final String FORMAT = "yyyy-MM-dd HH:mm:ss";
public String getFormat(Date date){
  SimpleDateFormat dateFormat = new SimpleDateFormat(FORMAT);
  return sdf.format(date);
}
```

```java
private static final SimpleDateFormat SIMPLE_DATE_FORMAT = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
public void getFormat(){
  synchronized (sdf){
    sdf.format(new Date());
  }
  …;
}
```

```java
private static final ThreadLocal<DateFormat> DATE_FORMATTER = new ThreadLocal<DateFormat>() {
  @Override
  protected DateFormat initialValue() {
    return new SimpleDateFormat("yyyy-MM-dd");
  }
};
```

**如果是 JDK8 的应用，可以使用 Instant 代替 Date，LocalDateTime 代替 Calendar，DateTimeFormatter 代替 SimpleDateFormat，官方给出的解释：simple beautiful strong immutable thread-safe。**

## ThreadLocal里设置的属性要记得删除

```java
public class UserHolder {
  private static final ThreadLocal<User> userThreadLocal = new ThreadLocal<User>();
  public static void set(User user){
    userThreadLocal.set(user);
  }
  public static User get(){
    return userThreadLocal.get();
  }
  public static void remove(){
    userThreadLocal.remove();
  }
}

public class UserInterceptor extends HandlerInterceptorAdapter {
  @Override
  public boolean preHandle(HttpServletRequest request,
                           HttpServletResponse response, Object handler) throws Exception {
    UserHolder.set(new User());
    return true;
  }
  @Override
  public void afterCompletion(HttpServletRequest request,
                              HttpServletResponse response, Object handler, Exception ex) throws Exception {
    UserHolder.remove();
  }
}
```

## 避免 Random 实例被多线程使用

避免 Random 实例被多线程使用，虽然共享该实例是线程安全的，但会因竞争同一
seed 导致的性能下降。
说明：Random 实例包括 java.util.Random 的实例或者 Math.random()的方式。
正例：在 JDK7 之后，可以直接使用 API ThreadLocalRandom，而在 JDK7 之前，需要编码保
证每个线程持有一个实例。

## 事务必须标注回滚策略

```java
@Service
@Transactional(rollbackFor = Exception.class)
public class UserServiceImpl implements UserService {
  @Override
  public void save(User user) {
    //some code
    //db operation
  }
}
```

```java
@Service
public class UserServiceImpl implements UserService {
  @Override
  @Transactional(rollbackFor = Exception.class)
  public void save(User user) {
    //some code
    //db operation
  }
}
```

```java
@Service
public class UserServiceImpl implements UserService {
  @Autowired
  private DataSourceTransactionManager transactionManager;
  @Override
  @Transactional
  public void save(User user) throws UserException {
    DefaultTransactionDefinition def = new DefaultTransactionDefinition();
    // explicitly setting the transaction name is something that can only be done programmatically
    def.setName("SomeTxName");
    def.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRED);
    TransactionStatus status = transactionManager.getTransaction(def);
    try {
      // execute your business logic here
      //db operation
      transactionManager.commit(status);
    } catch (Exception ex) {
      transactionManager.rollback(status);
      throw new UserException(ex);
    }
  }
}
```

## 避免使用Apache的BeanUtils

Apache BeanUtils性能较差，可以使用其他方案比如Spring BeanUtils, Cglib BeanCopier。

## 使用System.currentTimeMillis()获取当前毫秒数

获取当前毫秒数：System.currentTimeMillis(); 而不是new Date().getTime();

## 集合类的一些注意事项

* List转化为数组

```java
Integer[] b = (Integer [])c.toArray(new Integer[c.size()]); 
```

* 使用工具类 Arrays.asList()把数组转换成集合时，不能使用其修改集合相关的方
  法，它的 add/remove/clear 方法会抛出 UnsupportedOperationException 异常。

* ArrayList的subList结果不可强转成ArrayList，否则会抛出ClassCastException
  异常，即 java.util.RandomAccessSubList cannot be cast to java.util.ArrayList.

  说明：subList 返回的是 ArrayList 的内部类 SubList，并不是 ArrayList ，而是
  ArrayList 的一个视图，对于 SubList 子列表的所有操作最终会反映到原列表上。

* 集合初始化时，指定集合初始值大小。
  说明：HashMap 使用 HashMap(int initialCapacity) 初始化，
  正例：initialCapacity = (需要存储的元素个数 / 负载因子) + 1。注意负载因子（即 loader
  factor）默认为 0.75，如果暂时无法确定初始值大小，请设置为 16（即默认值）。
  反例：HashMap 需要放置 1024 个元素，由于没有设置容量初始大小，随着元素不断增加，容
  量 7 次被迫扩大，resize 需要重建 hash 表，严重影响性能。

* 高度注意 Map 类集合 K/V 能不能存储 null 值的情况，如下表格:

  ![map_key_value_nullable](http://blog-images-1252238296.cosgz.myqcloud.com/map_key_value_nullable.png)

## 总结

上面只列了一些个人平时没在注意的地方，完整的编码规约见[阿里巴巴Java开发手册](https://github.com/alibaba/p3c/blob/master/%E9%98%BF%E9%87%8C%E5%B7%B4%E5%B7%B4Java%E5%BC%80%E5%8F%91%E6%89%8B%E5%86%8C%EF%BC%88%E7%BB%88%E6%9E%81%E7%89%88%EF%BC%89.pdf)。另外网上还有一个[白话版](http://www.jianshu.com/p/bc8fed863eca)。
