---
title: Retrying_Library_For_Java
date: 2017-06-15 00:20:00+08:00
author: 徐新杰
tags:
  - java
  - spring
  - retry
categories:
  - java开发
---



最近在github上看到一个得了不少星的项目[Retrying library for Python](https://github.com/jd/tenacity)，果然还是人家比较有想法，这些重试的逻辑是可以包装为一个库供别人使用的。想到平时自己在写Java代码时，经常还手工写些代码实现重试逻辑，真的挺low的。那么Java里是否有类似的函数库呢？简单搜索了下，发现了两个选择：[guava-retrying](https://github.com/rholder/guava-retrying)、 [spring-retry](https://github.com/spring-projects/spring-retry)。简单比较了下，功能都差不多，但很明显spring-retry更强大一些，支持三种用法：API形式、Annotation形式、XML形式。个人还是比较喜欢Annotation形式的用法，看起来很简单，下面写一个简单的示例。

`NotStableService.java`

```java
import org.springframework.retry.annotation.Backoff;
import org.springframework.retry.annotation.EnableRetry;
import org.springframework.retry.annotation.Recover;
import org.springframework.retry.annotation.Retryable;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.util.Random;

/**
 * Created by jeremy on 2017/6/14.
 */
@EnableRetry
@Service
public class NotStableService {
    private Random random = new SecureRandom();

    @Retryable(
            value = {RuntimeException.class},
            maxAttempts = 8,
            backoff= @Backoff(delay = 1000, maxDelay = 32000, multiplier = 2)
    )
    public Integer executeNotStableMethod(){
        // 下面模拟该方法的执行不太稳定的状态，比如调用第三方不太稳定的服务接口等场景
        int result = random.nextInt(10);
        System.out.println("Got " + result);
        if(result < 7) {
            throw new RuntimeException("服务执行失败");
        } else {
            return result;
        }
    }

    @Recover
    public void recover(RuntimeException e){
        System.out.println("尝试多次，仍然失败");
    }
}
```

简单写个测试案例：

`NotStableServiceTests.java`

```java
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;

@RunWith(SpringRunner.class)
@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT)
public class NotStableServiceTests {

    @Autowired
    private NotStableService notStableService;

    @Test
    public void executeNotStableMethod(){
        Assert.assertNotNull(notStableService.executeNotStableMethod());
    }
}
```

测试执行结果：

```
2017-06-15 00:06:44.451  INFO 24549 --- [           main] p.j.service.NotStableServiceTests        : Started NotStableServiceTests in 15.068 seconds (JVM running for 16.511)
Got 3
Got 3
Got 2
Got 2
Got 6
Got 9
```

可以看到确实重试了好几次，最终得到了合适的结果。

本想好好讲一下[spring-retry](https://github.com/spring-projects/spring-retry)的详细用法的，不过在网上找资料时，发现已有一位兄弟写了很详细的文档，我这里就不赘述了。

以下内容转载自转载自[http://iyiguo.net/blog/2016/01/19/spring-retry-common-case/](http://iyiguo.net/blog/2016/01/19/spring-retry-common-case/)，[《Spring Retry 常用示例》](http://iyiguo.net/blog/2016/01/19/spring-retry-common-case/)的一切权利归作者[@Leeyee](mailto:seadlead@gmail.com)所有。

## 重试策略

### 连续重试N次

`SimpleRetryPolicy`可以实现指定次数的重试。只需要设置 *maxAttempts* 参数即可。其默认重试次数是3次。该策略为创建`RetryTemplate`对象时默认的重试策略。具体使用如下：

```java
SimpleRetryPolicy simpleRetryPolicy = new SimpleRetryPolicy();
simpleRetryPolicy.setMaxAttempts(4);
```

### 规定时间内连续重试

`TimeoutRetryPolicy`可以实现指定时间内的重试。超时时间通过参数 *timeout* 进行设置。默认超时时间1s。使用方式如下：

```java
// all spend 1s
TimeoutRetryPolicy timeoutRetryPolicy = new TimeoutRetryPolicy();
timeoutRetryPolicy.setTimeout(2000L);
```

### 组合重试

`CompositeRetryPolicy`实现了重试策略的组合。通过其 *policies* 字段，可以为其添加多个重试策略。组合策略执行的过程中，所有策略只要有一个达成终止条件，那么该重试结束。我们可以用组合重试策略实现一些相对比较复杂的重试。比如我们要实现在指定时间1s内重试3次，每次重试间隔0.2秒，就可以使用以下方法：

```java
CompositeRetryPolicy compositeRetryPolicy = new CompositeRetryPolicy();
SimpleRetryPolicy simpleRetryPolicy = new SimpleRetryPolicy();
TimeoutRetryPolicy timeoutRetryPolicy = new TimeoutRetryPolicy();
FixedBackOffPolicy fixedBackOffPolicy = new FixedBackOffPolicy();
fixedBackOffPolicy.setBackOffPeriod(200); // 每次重试间隔200ms

compositeRetryPolicy.setPolicies(new RetryPolicy[]{simpleRetryPolicy,		timeoutRetryPolicy,});
```

通过该方法，如果重试总耗时超过1s，重试次数不超过3次，那么重试终止；如果未超过1s，但重试次数已达到3次，那么重试终止！（重试等待的设置可以看下文）

### 异常分类重试

有可能存在这样一种场景，比如在进行HTTP请求时，有可能因为网络原因导致请求超时，也有可能在拿到HTTP响应结果后的业务处理中发生异常，针对这两种异常我们可能需要不同的异常重试机制。这时就可以通过`ExceptionClassifierRetryPolicy`对异常分类进行分类：

```java
ExceptionClassifierRetryPolicy retryPolicy = new ExceptionClassifierRetryPolicy();
Map<Class<? extends Throwable>, RetryPolicy> policyMap = Maps.newHashMap();
policyMap.put(NullPointerException.class, new SimpleRetryPolicy());
policyMap.put(ArithmeticException.class, new TimeoutRetryPolicy());
retryPolicy.setPolicyMap(policyMap);
```

上述示例中，我们针对重试业务抛出的空指针异常使用`SimpleRetryPolicy`策略，而对于算术异常采用`TimeoutRetryPolicy`策略。实际的重试过程中，这两中情况有可能交替出现，但不管如何，只要有一个重试策略达到终止状态，则整个重试调用终止。

## 等待策略（BackOff）

重试策略`RetryPolicy`只是实现了基本的重试功能，也就是核心的循环逻辑，形如以下的代码：

```
do ... while
```

那么每次重试之间的相关场景该如何处理呢？为此，Spring Retry 将重试间可能有的重试等待策略抽像成了`BackoffPolicy`接口，并提供了一些简单的实现。

在使用`RetryTemplate`时，可以通过*setBackOffPolicy*方法进行设置。

### 指定时间等待

首先`FixedBackOffPolicy`应该是最常用的重试间隔[1](http://iyiguo.net/blog/2016/01/19/spring-retry-common-case/#fn:comment1)策略！通过该类，可以指定重试之间需要等待的时间。FixedBackOffPolicy 有两个基本属性：*backOffPeriod* 和 *sleeper*。可以通过*backOffPeriod* 直接设定间隔实现，当然也可以通过*sleeper*属性，实现自己的重试间隔方法。同时，*backOffPeriod*实质上还是调用了Sleeper实现（`sleeper.sleep(backOffPeriod);`）。

```java
FixedBackOffPolicy fixedBackOffPolicy = new FixedBackOffPolicy();
fixedBackOffPolicy.setBackOffPeriod(1500);	
```

### 指数级等待

`ExponentialBackOffPolicy`类提供了指数级重试间隔的实现。通过该类，可以使重试之间的等待按指数级增长。其中

- *initialInterval*属性为初始默认间隔，默认值是100毫秒；
- *maxInterval*属性为最大默认间隔。当实际计算出的间隔超过该值时，使用该值。默认为30秒；
- *multiplier*为乘数。默认2，当其等于1时，其行为同`FixedBackOffPolicy`为固定时间间隔。建议不要使用1，会造成重试过快！

`FixedBackOffPolicy`的时间间隔计算公式是：

```java
Math.min(maxInterval, Math.pow(initialInterval, multiplier))
```

源码为：

```java
public synchronized long getSleepAndIncrement() {	
	long sleep = this.interval;	
	if (sleep > maxInterval) {		
		sleep = maxInterval;	
	} else {		
		this.interval = getNextInterval();	
	}	
	return sleep;
}

protected long getNextInterval() {	
  return (long)(this.interval * this.multiplier);
}
```

### 指数级随机等待

`ExponentialRandomBackOffPolicy`继承自`ExponentialBackOffPolicy`，只是重写了获取重试时间间隔的方法。在获取重试间隔后，在加上一些随机的时间。具体实现可参看源码：

```
@Overridepublic synchronized long getSleepAndIncrement() {	long next = super.getSleepAndIncrement();	next = (long)(next*(1 + r.nextFloat()*(getMultiplier()-1)));	return next;}
```

### 指定范围内的随机等待

`UniformRandomBackOffPolicy`允许给定最大，最小等待时间，然后让每次的重试在其之间进行随机等待。参数*minBackOffPeriod*和*maxBackOffPeriod*的默认值分别为500ms和1500ms，具体的计算方式是：

```java
protected void doBackOff() throws BackOffInterruptedException {	
  try {		
    long delta = maxBackOffPeriod==minBackOffPeriod ? 0 : random.nextInt((int) (maxBackOffPeriod - minBackOffPeriod));
    sleeper.sleep(minBackOffPeriod + delta );
  }	catch (InterruptedException e) {		
    throw new BackOffInterruptedException("Thread interrupted while sleeping", e);	
  }
}
```

## 基于注解的重试

最后我们了解下如何使用注解实现重试机制。最基本的，我们需要以下这几个注解：

- `@EnableRetry`：能否重试。注解类的，其*proxyTargetClass*属性为*true*时，使用CGLIB代理。默认使用标准JAVA注解。当类中有`@Retryable`注释的方法时，对该方法生成代理。
- `@Retryable`：注解需要被重试的方法。*include* 指定处理的异常类。默认所有异常*maxAttempts* 最大重试次数。默认3次*backoff* 重试等待策略。默认使用`@Backoff`注解
- `@Backoff`：重试等待策略。不设置参数时，默认使用`FixedBackOffPolicy`，重试等待1000ms只设置*delay()*属性时，使用`FixedBackOffPolicy`，重试等待指定的毫秒数当设置*delay()*和*maxDealy()*属性时，重试等待在这两个值之间均态分布使用*delay()*，*maxDealy()*和*multiplier()*属性时，使用`ExponentialBackOffPolicy`当设置*multiplier()*属性不等于0时，同时也设置了*random()*属性时，使用`ExponentialRandomBackOffPolicy`
- `@Recover`: 用于方法。用于@Retryable失败时的“兜底”处理方法。`@Recover`注释的方法参数为`@Retryable`异常类，返回值应与重试方法返回相同，否则无法识别！因此可以针对可能异常设置多个`@Recover`方法进行“兜底”处理。

对于`@Backoff`可以具体查看下参数不同时源码是如何处理的[2](http://iyiguo.net/blog/2016/01/19/spring-retry-common-case/#fn:codefrom1)：

```java
private BackOffPolicy getBackoffPolicy(Backoff backoff) {	
  long min = backoff.delay() == 0 ? backoff.value() : backoff.delay();	
  long max = backoff.maxDelay();	
  if (backoff.multiplier() > 0) {		
    ExponentialBackOffPolicy policy = new ExponentialBackOffPolicy();
    if (backoff.random()) {			
      policy = new ExponentialRandomBackOffPolicy();
    }		
    policy.setInitialInterval(min);
    policy.setMultiplier(backoff.multiplier());
    policy.setMaxInterval(max > min ? max : ExponentialBackOffPolicy.DEFAULT_MAX_INTERVAL);
    if (sleeper != null) {			
      policy.setSleeper(sleeper);		
    }		
    return policy;	
  }	
  if (max > min) {		
    UniformRandomBackOffPolicy policy = new UniformRandomBackOffPolicy();	
    policy.setMinBackOffPeriod(min);		
    policy.setMaxBackOffPeriod(max);		
    if (sleeper != null) {			
      policy.setSleeper(sleeper);		
    }		
    return policy;	
  }	
  FixedBackOffPolicy policy = new FixedBackOffPolicy();
  policy.setBackOffPeriod(min);	
  if (sleeper != null) {		
    policy.setSleeper(sleeper);	
  }	
  return policy;
}
```

最后给出一个使用示例，供大家参考下：

```java
@Service@EnableRetry()
public class AnnoService {	
  
  public Logger logger = LoggerFactory.getLogger(AnnoService.class);
  
  @Retryable(maxAttempts = 5, backoff = @Backoff(random = true))
  public String someService() {		
    int random = (int) (Math.random() * 10);
    if (random < 4) {			
      logger.info("random={} Null Pointer Excep", random);	
      throw new NullPointerException();		
    } else if (random < 9) {			
      logger.info("random={} Arithmetic Excep", random);			
      throw new ArithmeticException();		
    }		
    logger.info("random={} ok !!!!", random);		
    return "ok";	
  }	
  
  @Recover	
  public String recover(NullPointerException ne) {
    logger.info("{}", "NullPointerException");
    return "null pointer recover";	
  }	
  
  @Recover	public String recover(ArithmeticException ne) {
    logger.info("{}", "ArithmeticException");
    return "ArithmeticException recover";	
  }
}

public class Main {	
  public static void main(String[] args) throws Exception {
    ApplicationContext context = new AnnotationConfigApplicationContext("com.leeyee.spring.retry.*");
    AnnoService annoService = context.getBean(AnnoService.class);
    String result = annoService.someService();
    System.out.println(result);	
  }
}
```

