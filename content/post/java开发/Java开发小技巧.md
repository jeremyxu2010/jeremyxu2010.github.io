---
title: Java开发小技巧
tags:
  - java
  - nio
  - validate
  - log
  - guava
  - spring-retry
categories:
  - java开发
date: 2017-09-03 23:38:00+08:00
---



# Java开发小技巧

平时开发中有一些小技巧，都不算很有技术含量，但在工作中运用这些技巧确实可以提高工作效率，这里把这些小技分享出来。



## 参数验证

提供的API接口类方法如有参数，都要做参数校验，参数校验不通过明确抛出异常或对应的响应码。到处写if表达式判断代码，正常的业务逻辑会被这些校验代码干扰，这里介绍两个用得比较多的方案。

### Commons-lang的Validate

```java
String val1 = "  ";
Validate.notBlank(val1, "输入的参数val1=%s为空", val1);

String val2 = null;
Validate.notNull(val2, "输入的参数val2为null");

String[] arr1 = new String[0];
Validate.notEmpty(arr1, "数组为空");

List<String> lst1 = new ArrayList<String>();
Validate.notEmpty(lst1, "数组为空");

String[] arr2 = new String[0];
int idx = 3;
Validate.validIndex(arr2, idx, "索引超过数组范围");

short state1 = (short)1;
short validState = 3;
Validate.validState(state1==validState, "当前的状态不正确, state=%d", state1);

boolean valid = (3 == 4);
Validate.isTrue(valid, "表达式不合法");
```

### BeanValidation

如果输入参数是pojo对象，采用BeanValidation方案更优雅一些。

```java
public static void main(String[] args) {
  ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
  Validator validator = factory.getValidator();
  Pojo pojo = new Pojo();
  pojo.setKey1("abcdef");
  pojo.setKey2(3.3);
  pojo.setTime1(new GregorianCalendar(2010, 3, 4).getTime());
  Set<ConstraintViolation<Pojo>> violationSet = validator.validate(pojo);
  if(violationSet.size() > 0) {
    for (ConstraintViolation<Pojo> violation : violationSet) {
      System.out.println(violation);
    }
  } else {
    System.out.println("校验成功");
  }
}

private static class Pojo{
  @NotNull(message = "key1为空")
  @Size(min = 6, max = 20, message = "key1的长度不正确")
  private String key1;

  @NotNull(message = "key2为空")
  @DecimalMin(value = "0", message = "值不能小于0")
  @DecimalMax(value = "100", message = "值不能大于100")
  private Double key2;

  @NotNull(message = "time1为空")
  @Past(message = "时间不能大于现在")
  private Date time1;

  public String getKey1() {
    return key1;
  }

  public void setKey1(String key1) {
    this.key1 = key1;
  }

  public Double getKey2() {
    return key2;
  }

  public void setKey2(Double key2) {
    this.key2 = key2;
  }

  public Date getTime1() {
    return time1;
  }

  public void setTime1(Date time1) {
    this.time1 = time1;
  }
}
```



## 重视Deprecated

调用标准库或第三方API时，一些接口上打上了Deprecated标记，而且一些还解释了准备废弃这个接口的原因及应该改用的写法。

```java
// bad
java.net.URLEncoder#encode(java.lang.String);
// good
java.net.URLEncoder#encode(java.lang.String, java.lang.String);

// bad
java.net.URLDecoder#decode(java.lang.String);
// good
java.net.URLDecoder#decode(java.lang.String, java.lang.String);

// bad
java.util.Date#Date(int, int, int);
// good
java.net.URLDecoder#decode(java.lang.String, java.lang.String);

// bad
org.springframework.orm.hibernate3.support.HibernateDaoSupport#getSession().createSQLQuery(sql).executeUpdate();
// good
org.springframework.orm.hibernate3.support.HibernateDaoSupport#getHibernateTemplate().execute(new HibernateCallback<Void>() {
    @Override
    public Void doInHibernate(Session session) throws HibernateException, SQLException {
        session.createSQLQuery(sql).executeUpdate();
        return null;
    }
});
```



## Java文件操作

Java 7中引入了新的文件操作API，具有不少优点，新代码建议采用这套API操作文件。

可参考[Java NIO File操作](http://jeremy-xu.oschina.io/2016/05/09/Java-NIO-File%E6%93%8D%E4%BD%9C/)。



## 打印日志

平时打日志时有几个错误范例，打日志时要注意一下。

### 拼接字符串

```java
// bad
Lg.info("abc " + 3 + " def " + 4 + " xxx " + 5); 
// good
Lg.info(String.format("abc %d def %d xxx %d", 3, 4, 5))
```

### 打印异常堆栈至标准错误输出

```java
// bad
e.printStackTrace();
Lg.error("执行出错");
// good
Lg.error("执行出错", e);
```

### 打印过长字符串

```java
// bad
Lg.info(tooLongStr);
// good
if(Lg.isInfoEnabled()){
	Lg.info(tooLongStr);	
}
```



## 资源清理

网络连接、数据库连接、会话、HttpClient的连接等使用完后一定要进行资源清理。

以下是一些错误的示例：

* ```java
  private static Logger Lg = LoggerFactory.getLogger(ResourceCleanDemo.class);

  public static void main(String[] args) {
    Socket socket = null;
    BufferedReader reader = null;
    PrintWriter writer = null;
    try {
      socket = new Socket("127.0.0.1", 8080);
      reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8.name()));
      writer = new PrintWriter(new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8.name()));
      // do something
      ...
        
      socket.close();
      writer.close();
      reader.close();
    } catch (IOException e){
      Lg.error("出错", e);
    }
  }
  ```

* ```java
  private static Logger Lg = LoggerFactory.getLogger(ResourceCleanDemo.class);

  public static void main(String[] args) {
    Socket socket = null;
    BufferedReader reader = null;
    PrintWriter writer = null;
    try {
      socket = new Socket("127.0.0.1", 8080);
      reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8.name()));
      writer = new PrintWriter(new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8.name()));
      // do something
      ...
    } catch (IOException e){
      Lg.error("出错", e);
    } finally {
      try {
        socket.close();
        writer.close();
        reader.close();
      } catch (IOException e) {
        Lg.error("出错", e);
      }
    }
  }
  ```

正确的范例：

```java
private static Logger Lg = LoggerFactory.getLogger(ResourceCleanDemo.class);

public static void main(String[] args) {
  Socket socket = null;
  BufferedReader reader = null;
  PrintWriter writer = null;
  try {
    socket = new Socket("127.0.0.1", 8080);
    reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8.name()));
    writer = new PrintWriter(new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8.name()));
  } catch (IOException e){
    Lg.error("出错", e);
  } finally {
    IOUtils.closeQuietly(socket);
    IOUtils.closeQuietly(writer);
    IOUtils.closeQuietly(reader);
  }
}
```



## HttpClient连接池

HttpClient库为了提高性能，是使用了连接池的，应尽量使用连接池特性。

错误示例如下：

```java
public static void main(String[] args) throws IOException {
  for (int i = 0; i < 10; i++) {
    CloseableHttpClient httpClient = HttpClients.createDefault();
    CloseableHttpResponse resp = httpClient.execute(new HttpGet("www.baidu.com"));
    // do something
    ....
    httpClient.close();
  }
}
```

正确示例如下：

```java
private static final CloseableHttpClient httpClient = HttpClients.createDefault();

public static void main(String[] args) throws IOException {
  for (int i = 0; i < 10; i++) {
    HttpGet httpGet = null;
    try {
      httpGet = new HttpGet("www.baidu.com");
      CloseableHttpResponse resp = httpClient.execute(httpGet);
      // do something
      ....
    } catch (Exception e) {
      Lg.error("出错", e);
    } finally {
      httpGet.releaseConnection();
    }
  }
  IOUtils.closeQuietly(httpClient);
}
```



## 善用Spring的工具类

Spring中有一些已经写好的工具类，代码都比较简单，即可以学习下，本时工作中用一用也可以提高开发效率。

```java
org.springframework.dao.support.DataAccessUtils
org.springframework.util.StringUtils
org.springframework.util.CollectionUtils
org.springframework.util.Base64Utils
org.springframework.util.DigestUtils
org.springframework.util.FileCopyUtils
org.springframework.util.FileSystemUtils
org.springframework.util.ReflectionUtils
org.springframework.util.SocketUtils
org.springframework.beans.BeanUtils
```



## Guava中一些有用的API

```java
// 把Throwable包装成RuntimeException抛出
com.google.common.base.Throwables#propagate(Throwable throwable);

// 新集合类型
com.google.common.collect.Multiset
com.google.common.collect.Multimap

// Google Guava，详细用法参见http://jeremy-xu.oschina.io/2016/09/01/java%E4%B8%AD%E7%94%A8%E5%A5%BDcache/
com.google.common.cache.LoadingCache

// 异步任务执行完毕后自动执行指定的回调方法
com.google.common.util.concurrent.ListenableFuture

// 同步事件总线
com.google.common.eventbus.EventBus

// 异步事件总线
com.google.common.eventbus.AsyncEventBus
```

可参考[Google Guava官方教程（中文版）](http://ifeve.com/google-guava/)

这里举几个例子：

### Throwables抛出异常

```java
public void someBusinessMethod(String param1){
  try {
    System.out.println(Integer.parseInt(param1));
  } catch (NumberFormatException e) {
    Throwables.propagate(e);
  }
}
```

### ListenableFuture示例

```java
private static final ListeningExecutorService service = MoreExecutors.listeningDecorator(Executors.newFixedThreadPool(10));
    
public static void main(String[] args) {
  ListenableFuture<Integer> future = service.submit(new Callable<Integer>() {
    @Override
    public Integer call() throws Exception {
      Thread.sleep(10000L);
      return new Integer(0);
    }
  });

  Futures.addCallback(future, new FutureCallback<Integer>() {
    @Override
    public void onSuccess(Integer result) {
      System.out.println(String.format("success, result: %d", result));
    }

    @Override
    public void onFailure(Throwable t) {
      t.printStackTrace();
    }
  });
}
```

### 事件总线

```java
private static EventBus eventBus = new EventBus("globalEventBus");

public static void main(String[] args) {
  eventBus.register(new CustomEventHandler());
  eventBus.register(new DeadEventHandler());

  eventBus.post(new CustomEvent());
}

private static class CustomEventHandler{
  @Subscribe
  public void handleCustomEvent(CustomEvent event){
    System.out.println(event);
  }
}

private static class DeadEventHandler{
  @Subscribe
  public void handleDeadEvent(DeadEvent deadEvent){
    System.out.println(deadEvent);
  }
}

private static class CustomEvent{

}
```



## 重试逻辑

经常写代码实现业务的重试逻辑，可考虑[spring-retry](https://github.com/spring-projects/spring-retry)，用法可参考[Retrying_Library_For_Java](http://jeremy-xu.oschina.io/2017/06/15/Retrying_Library_For_Java/)



## 工具技巧

1. `java -XX:+PrintFlagsFinal `：打印出几乎所有的JVM支持的参数以及他们的默认值

2. `-Xrunjdwp:transport=dt_socket,server=y,suspend=n,address={port}`：jvm开启jdwp，可运程调试

3. `-Dcom.sun.management.jmxremote=true -Djava.rmi.server.hostname=ip−Dcom.sun.management.jmxremote.port={port} -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false` ：jvm开启jmx，可使用jconsole连接

4. mybatis-generator的配置文件中加入`<property name="addRemarkComments" value="true" />`，可数据库表的备注可自动作为实体属性的注释

5. `IntelliJ IDEA`的几个重要的重构功能：Rename、Change Signature…、Move…、Copy…、Extract Constant…、Extract Method…、Extract Interface…、Pull Member Up…。

   ​
