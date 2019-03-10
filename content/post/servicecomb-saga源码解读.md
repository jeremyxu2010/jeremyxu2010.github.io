---
title: servicecomb-saga源码解读
tags:
  - microservice
  - java
categories:
  - microservice
date: 2018-08-18 17:50:00+08:00
---

前面写过一篇[servicecomb-saga开发实战](/2018/07/servicecomb-saga%E5%BC%80%E5%8F%91%E5%AE%9E%E6%88%98/)，当时说后面有时间写一篇源码解读，不过工作一忙，就把这事儿忘了，今天终于得闲可以补上这个坑了。

整个servicecomb-saga的代码量还是比较多的，这里着重解读下omega模块的源码，其实如果理解了omega模块的代码逻辑，alpha模块就比较清楚了。

## omega模块的功能

首先参考[具体处理流程](/2018/07/servicecomb-saga开发实战/#具体处理流程)：

### 成功场景

成功场景下，每个开始的事件都会有对应的结束事件。

[![Successful Scenario](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/successful_scenario.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/successful_scenario.png)

### 异常场景

异常场景下，omega会向alpha上报中断事件，然后alpha会向该全局事务的其它已完成的子事务发送补偿指令，确保最终所有的子事务要么都成功，要么都回滚。

[![Exception Scenario](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/exception_scenario.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/exception_scenario.png)

### 超时场景

超时场景下，已超时的事件会被alpha的定期扫描器检测出来，与此同时，该超时事务对应的全局事务也会被中断。

[![Timeout Scenario](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/timeout_scenario.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/timeout_scenario.png)

从上述处理流程可以看出omega主要完成以下4大功能：

1. 注入分布式事务ID（包括向当前服务注入分布式事务id、向调用的其它服务传递分布式事务id）
2. 在整个分布式事务开始与结束时记录saga执行事件
3. 在本地事务方法执行的前后记录saga执行事件
4. 收到补偿事件后执行补偿方法，并记录saga补偿执行事件

后面在解读时会逐一说明上述4大功能在代码上是如何实现的。

## omega代码解读

参考[添加saga的注解及相应的补偿方法](/2018/07/servicecomb-saga开发实战/#添加saga的注解及相应的补偿方法)，我们可以看到servicecomb-saga仅要求业务应用配置`EnableOmega`，`@SagaStart`，`@Compensable`这三个annotation，下面看下这三个annotation具体是如何工作的。

`incubator-servicecomb-saga/omega/omega-spring-starter/src/main/java/org/apache/servicecomb/saga/omega/spring/EnableOmega.java`

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Import({OmegaSpringConfig.class, TransactionAspectConfig.class})
/**
 * Indicates create the OmegaContext and inject it into the interceptors
 * to pass the transactions id across the application.
 * @see org.apache.servicecomb.saga.omega.context.OmegaContext
 */
public @interface EnableOmega {
}
```

一看名字就知道，这是个spring特性开关annotation，当在业务应用中打上此annotation，则会导入一些配置类，这种写法在spring-boot里很常见。

再来看`OmegaSpringConfig`，`TransactionAspectConfig`。

`incubator-servicecomb-saga/omega/omega-spring-starter/src/main/java/org/apache/servicecomb/saga/omega/spring/OmegaSpringConfig.java`

```java
@Configuration
class OmegaSpringConfig {

  @Bean(name = {"omegaUniqueIdGenerator"})
  IdGenerator<String> idGenerator() {
    return new UniqueIdGenerator();
  }

  @Bean
  OmegaContext omegaContext(@Qualifier("omegaUniqueIdGenerator") IdGenerator<String> idGenerator) {
    return new OmegaContext(idGenerator);
  }

  @Bean
  CompensationContext compensationContext(OmegaContext omegaContext) {
    return new CompensationContext(omegaContext);
  }

  @Bean
  ServiceConfig serviceConfig(@Value("${spring.application.name}") String serviceName) {
    return new ServiceConfig(serviceName);
  }

  @Bean
  MessageSender grpcMessageSender(
      @Value("${alpha.cluster.address:localhost:8080}") String[] addresses,
      @Value("${alpha.cluster.ssl.enable:false}") boolean enableSSL,
      @Value("${alpha.cluster.ssl.mutualAuth:false}") boolean mutualAuth,
      @Value("${alpha.cluster.ssl.cert:client.crt}") String cert,
      @Value("${alpha.cluster.ssl.key:client.pem}") String key,
      @Value("${alpha.cluster.ssl.certChain:ca.crt}") String certChain,
      @Value("${omega.connection.reconnectDelay:3000}") int reconnectDelay,
      ServiceConfig serviceConfig,
      @Lazy MessageHandler handler) {

    MessageFormat messageFormat = new KryoMessageFormat();
    AlphaClusterConfig clusterConfig = new AlphaClusterConfig(Arrays.asList(addresses),
        enableSSL, mutualAuth, cert, key, certChain);
    final MessageSender sender = new LoadBalancedClusterMessageSender(
        clusterConfig,
        messageFormat,
        messageFormat,
        serviceConfig,
        handler,
        reconnectDelay);

    sender.onConnected();
    
    Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
      @Override
      public void run() {
        sender.onDisconnected();
        sender.close();
      }
    }));
    return sender;
  }
}
```

这个配置类里声明了5个spring bean，功能如下：

1. `omegaUniqueIdGenerator`：这是一个唯一ID生成器，用于给分布式事务生成唯一的全局事务ID及本地事务ID。
2. `omegaContext`：这个bean里保存了当前的事务上下文信息（主要就是全局事务ID及本地事务ID），同时也提供API，用于读取设置当前的事务上下文信息。
3. `compensationContext`：这个bean里保存了可被调用的补偿方法，同时也提供API供其它部分执行某个补偿方法。
4. `serviceConfig`：这个bean里保存了当前业务服务的唯一标识。
5. `grpcMessageSender`：这个bean维护与`alpha`的grpc连接，同时如其名称提供API供其它部分通过grpc发送saga事件至`alpha`。

`incubator-servicecomb-saga/omega/omega-spring-tx/src/main/java/org/apache/servicecomb/saga/omega/transaction/spring/TransactionAspectConfig.java`

```java
@Configuration
@EnableAspectJAutoProxy
public class TransactionAspectConfig {

  @Bean
  MessageHandler messageHandler(MessageSender sender, CompensationContext context, OmegaContext omegaContext) {
    return new CompensationMessageHandler(sender, context);
  }

  @Order(0)
  @Bean
  SagaStartAspect sagaStartAspect(MessageSender sender, OmegaContext context) {
    return new SagaStartAspect(sender, context);
  }

  @Order(1)
  @Bean
  TransactionAspect transactionAspect(MessageSender sender, OmegaContext context) {
    return new TransactionAspect(sender, context);
  }

  @Bean
  CompensableAnnotationProcessor compensableAnnotationProcessor(OmegaContext omegaContext,
      CompensationContext compensationContext) {
    return new CompensableAnnotationProcessor(omegaContext, compensationContext);
  }
}
```

这个配置类里声明了4个spring bean，功能如下：

1. `messageHandler`：这个bean处理从`alpha`接收到的补偿事件，主要逻辑就是收到补偿事件后执行补偿方法，并向`alpha`发送saga补偿执行完成事件。
2. `sagaStartAspect`：这个bean完成`@SagaStart`这个annotation的AOP拦截处理，主要逻辑就是在整个分布式事务开始与结束时记录saga执行事件。
3. `transactionAspect`：这个bean完成`@Compensable`这个annotation的AOP拦截处理，主要逻辑就是在本地事务方法执行的前后记录saga执行事件。
4. `compensableAnnotationProcessor`：这个bean完成两个功能：
  * 完成`@OmegaContextAware`这个annotation的处理逻辑，主要逻辑是当spring bean的某个field是一个Executor，并且打上了`@OmegaContextAware`这个annotation，则让在这个Executor中执行的任务执行前设置上正确的事务上下文信息（主要就是全局事务ID及本地事务ID）。从代码上看目前这个功能仅在框架内部使用。
  * 将打上`@Compensable`这个annotation的方法提前注册好，保存在`compensationContext`这个bean中。

其实上面那样将主要的spring bean功能解读一遍后，整个脉络就很清楚了。这里再复述一遍omega的主体功能的如何实现的。

### 注入分布式事务ID

通过对`@SagaStart`这个annotation的AOP拦截处理，在分布式事务开始时给当前分布式事务ID分配全局唯一ID，代码如下：

`incubator-servicecomb-saga/omega/omega-transaction/src/main/java/org/apache/servicecomb/saga/omega/transaction/SagaStartAspect.java`

```java
@Around("execution(@org.apache.servicecomb.saga.omega.context.annotations.SagaStart * *(..)) && @annotation(sagaStart)")
  Object advise(ProceedingJoinPoint joinPoint, SagaStart sagaStart) throws Throwable {
    initializeOmegaContext();
    ......
  }

  private void initializeOmegaContext() {
    context.setLocalTxId(context.newGlobalTxId());
  }
```

通过对`@Compensable`这个annotation的AOP拦截处理，在本地事务开始时给当前本地事务ID分配唯一ID，代码如下：

`incubator-servicecomb-saga/omega/omega-transaction/src/main/java/org/apache/servicecomb/saga/omega/transaction/TransactionAspect.java`

```java
  @Around("execution(@org.apache.servicecomb.saga.omega.transaction.annotations.Compensable * *(..)) && @annotation(compensable)")
  Object advise(ProceedingJoinPoint joinPoint, Compensable compensable) throws Throwable {
    Method method = ((MethodSignature) joinPoint.getSignature()).getMethod();
    String localTxId = context.localTxId();
    context.newLocalTxId();
    LOG.debug("Updated context {} for compensable method {} ", context, method.toString());

    ......
    try {
      ......
    } finally {
      context.setLocalTxId(localTxId);
      LOG.debug("Restored context back to {}", context);
    }
  }
```

通过不同RequestInterceptor将当前的分布式上下文信息通过请求头等方式传递给其它的服务，代码如下：

框架实现了基于多种transport的分布式上下文信息传递方案，见`incubator-servicecomb-saga/omega/omega-transport`目录下的各类实现。下面的代码以`resttemplate`为例。

`incubator-servicecomb-saga/omega/omega-transport/omega-transport-resttemplate/src/main/java/org/apache/servicecomb/saga/omega/transport/resttemplate/TransactionClientHttpRequestInterceptor.java`

```java
class TransactionClientHttpRequestInterceptor implements ClientHttpRequestInterceptor {
  private static final Logger LOG = LoggerFactory.getLogger(MethodHandles.lookup().lookupClass());
  private final OmegaContext omegaContext;

  TransactionClientHttpRequestInterceptor(OmegaContext omegaContext) {
    this.omegaContext = omegaContext;
  }

  @Override
  public ClientHttpResponse intercept(HttpRequest request, byte[] body,
      ClientHttpRequestExecution execution) throws IOException {

    if (omegaContext!= null && omegaContext.globalTxId() != null) {
      request.getHeaders().add(GLOBAL_TX_ID_KEY, omegaContext.globalTxId());
      request.getHeaders().add(LOCAL_TX_ID_KEY, omegaContext.localTxId());

      LOG.debug("Added {} {} and {} {} to request header",
          GLOBAL_TX_ID_KEY,
          omegaContext.globalTxId(),
          LOCAL_TX_ID_KEY,
          omegaContext.localTxId());
    }
    return execution.execute(request, body);
  }
}
```

通过HandlerInterceptor在调用具体业务方法前将传递来的分布式上下文信息保存进`OmegaContext`，代码如下：

`incubator-servicecomb-saga/omega/omega-transport/omega-transport-resttemplate/src/main/java/org/apache/servicecomb/saga/omega/transport/resttemplate/TransactionHandlerInterceptor.java`

```java
class TransactionHandlerInterceptor implements HandlerInterceptor {

  private static final Logger LOG = LoggerFactory.getLogger(MethodHandles.lookup().lookupClass());

  private final OmegaContext omegaContext;

  TransactionHandlerInterceptor(OmegaContext omegaContext) {
    this.omegaContext = omegaContext;
  }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    if (omegaContext != null) {
      String globalTxId = request.getHeader(GLOBAL_TX_ID_KEY);
      if (globalTxId == null) {
        LOG.debug("no such header: {}", GLOBAL_TX_ID_KEY);
      } else {
        omegaContext.setGlobalTxId(globalTxId);
        omegaContext.setLocalTxId(request.getHeader(LOCAL_TX_ID_KEY));
      }
    }
    return true;
  }

  @Override
  public void postHandle(HttpServletRequest request, HttpServletResponse response, Object o, ModelAndView mv) {
  }

  @Override
  public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object o, Exception e) {
  }
}
```

### 分布式事务开始与结束时记录saga执行事件

通过对`@SagaStart`这个annotation的AOP拦截处理，在整个分布式事务开始与结束时记录saga执行事件，代码如下：

`incubator-servicecomb-saga/omega/omega-transaction/src/main/java/org/apache/servicecomb/saga/omega/transaction/SagaStartAspect.java`

```java
@Aspect
public class SagaStartAspect {
  ......
  @Around("execution(@org.apache.servicecomb.saga.omega.context.annotations.SagaStart * *(..)) && @annotation(sagaStart)")
  Object advise(ProceedingJoinPoint joinPoint, SagaStart sagaStart) throws Throwable {
    ......

    sagaStartAnnotationProcessor.preIntercept(context.globalTxId(), method.toString(), sagaStart.timeout(), "", 0);
    LOG.debug("Initialized context {} before execution of method {}", context, method.toString());

    try {
      Object result = joinPoint.proceed();

      sagaStartAnnotationProcessor.postIntercept(context.globalTxId(), method.toString());
      LOG.debug("Transaction with context {} has finished.", context);

      return result;
    } catch (Throwable throwable) {
      // We don't need to handle the OmegaException here
      if (!(throwable instanceof OmegaException)) {
        sagaStartAnnotationProcessor.onError(context.globalTxId(), method.toString(), throwable);
        LOG.error("Transaction {} failed.", context.globalTxId());
      }
      throw throwable;
    } finally {
      ......
    }
  }
  ......
}
```

`incubator-servicecomb-saga/omega/omega-transaction/src/main/java/org/apache/servicecomb/saga/omega/transaction/SagaStartAnnotationProcessor.java`

```java
class SagaStartAnnotationProcessor implements EventAwareInterceptor {

  private final OmegaContext omegaContext;
  private final MessageSender sender;

  SagaStartAnnotationProcessor(OmegaContext omegaContext, MessageSender sender) {
    this.omegaContext = omegaContext;
    this.sender = sender;
  }

  @Override
  public AlphaResponse preIntercept(String parentTxId, String compensationMethod, int timeout, String retriesMethod,
      int retries, Object... message) {
    try {
      return sender.send(new SagaStartedEvent(omegaContext.globalTxId(), omegaContext.localTxId(), timeout));
    } catch (OmegaException e) {
      throw new TransactionalException(e.getMessage(), e.getCause());
    }
  }

  @Override
  public void postIntercept(String parentTxId, String compensationMethod) {
    AlphaResponse response = sender.send(new SagaEndedEvent(omegaContext.globalTxId(), omegaContext.localTxId()));
    if (response.aborted()) {
      throw new OmegaException("transaction " + parentTxId + " is aborted");
    }
  }

  @Override
  public void onError(String parentTxId, String compensationMethod, Throwable throwable) {
    String globalTxId = omegaContext.globalTxId();
    sender.send(new TxAbortedEvent(globalTxId, omegaContext.localTxId(), null, compensationMethod, throwable));
  }
}
```



### 本地事务方法执行前后记录saga执行事件

通过对`@Compensable`这个annotation的AOP拦截处理，在本地事务开始与结束时记录saga执行事件，代码如下：

`incubator-servicecomb-saga/omega/omega-transaction/src/main/java/org/apache/servicecomb/saga/omega/transaction/DefaultRecovery.java`

```java
public class DefaultRecovery implements RecoveryPolicy {
  private static final Logger LOG = LoggerFactory.getLogger(MethodHandles.lookup().lookupClass());

  @Override
  public Object apply(ProceedingJoinPoint joinPoint, Compensable compensable, CompensableInterceptor interceptor,
      OmegaContext context, String parentTxId, int retries) throws Throwable {
    ......

    AlphaResponse response = interceptor.preIntercept(parentTxId, compensationSignature, compensable.timeout(),
        retrySignature, retries, joinPoint.getArgs());
    ......

    try {
      Object result = joinPoint.proceed();
      interceptor.postIntercept(parentTxId, compensationSignature);

      return result;
    } catch (Throwable throwable) {
      interceptor.onError(parentTxId, compensationSignature, throwable);
      throw throwable;
    }
  }

  ......
}
```

`incubator-servicecomb-saga/omega/omega-transaction/src/main/java/org/apache/servicecomb/saga/omega/transaction/CompensableInterceptor.java`

```java
class CompensableInterceptor implements EventAwareInterceptor {
  private final OmegaContext context;
  private final MessageSender sender;

  CompensableInterceptor(OmegaContext context, MessageSender sender) {
    this.sender = sender;
    this.context = context;
  }

  @Override
  public AlphaResponse preIntercept(String parentTxId, String compensationMethod, int timeout, String retriesMethod,
      int retries, Object... message) {
    return sender.send(new TxStartedEvent(context.globalTxId(), context.localTxId(), parentTxId, compensationMethod,
        timeout, retriesMethod, retries, message));
  }

  @Override
  public void postIntercept(String parentTxId, String compensationMethod) {
    sender.send(new TxEndedEvent(context.globalTxId(), context.localTxId(), parentTxId, compensationMethod));
  }

  @Override
  public void onError(String parentTxId, String compensationMethod, Throwable throwable) {
    sender.send(
        new TxAbortedEvent(context.globalTxId(), context.localTxId(), parentTxId, compensationMethod, throwable));
  }
}
```

### 收到补偿事件后的处理流程

通过Server streaming的gRPC，当从`alpha`收到补偿事件后，调用消息处理器，消息处理器则会执行对应的补偿方法，并记录saga补偿执行事件，代码如下：

`incubator-servicecomb-saga/omega/omega-connector/omega-connector-grpc/src/main/java/org/apache/servicecomb/saga/omega/connector/grpc/GrpcCompensateStreamObserver.java`

```java
class GrpcCompensateStreamObserver implements StreamObserver<GrpcCompensateCommand> {
  ......

  @Override
  public void onNext(GrpcCompensateCommand command) {
    LOG.info("Received compensate command, global tx id: {}, local tx id: {}, compensation method: {}",
        command.getGlobalTxId(), command.getLocalTxId(), command.getCompensationMethod());

    messageHandler.onReceive(
        command.getGlobalTxId(),
        command.getLocalTxId(),
        command.getParentTxId().isEmpty() ? null : command.getParentTxId(),
        command.getCompensationMethod(),
        deserializer.deserialize(command.getPayloads().toByteArray()));
  }
  ......
}
```

`incubator-servicecomb-saga/omega/omega-transaction/src/main/java/org/apache/servicecomb/saga/omega/transaction/CompensationMessageHandler.java`

```java
public class CompensationMessageHandler implements MessageHandler {
  ......

  @Override
  public void onReceive(String globalTxId, String localTxId, String parentTxId, String compensationMethod,
      Object... payloads) {
    context.apply(globalTxId, localTxId, compensationMethod, payloads);
    sender.send(new TxCompensatedEvent(globalTxId, localTxId, parentTxId, compensationMethod));
  }
}
```

以上就是omega主体流程的代码解读了，下面说一些框架实现的其它特性。

### saga消息发送支持多alpha负载均衡及重试

通过`LoadBalancedClusterMessageSender`、`RetryableMessageSender`（这个貌似没有实现完）包装原始的`GrpcClientMessageSender`，以支持saga消息发送的多alpha负载均衡、发送失败重试，代码如一下：

`incubator-servicecomb-saga/omega/omega-connector/omega-connector-grpc/src/main/java/org/apache/servicecomb/saga/omega/connector/grpc/LoadBalancedClusterMessageSender.java`

```java
public class LoadBalancedClusterMessageSender implements MessageSender {

  ......
  private final Map<MessageSender, Long> senders = new ConcurrentHashMap<>();
  private final Collection<ManagedChannel> channels;

  private final BlockingQueue<Runnable> pendingTasks = new LinkedBlockingQueue<>();
  private final BlockingQueue<MessageSender> availableMessageSenders = new LinkedBlockingQueue<>();
  private final MessageSender retryableMessageSender = new RetryableMessageSender(
      availableMessageSenders);

  private final Supplier<MessageSender> defaultMessageSender = new Supplier<MessageSender>() {
    @Override
    public MessageSender get() {
      return retryableMessageSender;
    }
  };

  ......

  public LoadBalancedClusterMessageSender(AlphaClusterConfig clusterConfig,
      MessageSerializer serializer,
      MessageDeserializer deserializer,
      ServiceConfig serviceConfig,
      MessageHandler handler,
      int reconnectDelay) {

    ......
    for (String address : clusterConfig.getAddresses()) {
      ManagedChannel channel;

      if (clusterConfig.isEnableSSL()) {
        if (sslContext == null) {
          try {
            sslContext = buildSslContext(clusterConfig);
          } catch (SSLException e) {
            throw new IllegalArgumentException("Unable to build SslContext", e);
          }
        }
         channel = NettyChannelBuilder.forTarget(address)
            .negotiationType(NegotiationType.TLS)
            .sslContext(sslContext)
            .build();
      } else {
        channel = ManagedChannelBuilder.forTarget(address).usePlaintext()
            .build();
      }
      channels.add(channel);
      senders.put(
          new GrpcClientMessageSender(
              address,
              channel,
              serializer,
              deserializer,
              serviceConfig,
              new ErrorHandlerFactory(),
              handler),
          0L);
    }

    ......
  }

  ......

  @Override
  public void onConnected() {
    for(MessageSender sender :senders.keySet()){
      try {
        sender.onConnected();
      } catch (Exception e) {
        LOG.error("Failed connecting to alpha at {}", sender.target(), e);
      }
    }
  }

  @Override
  public void onDisconnected() {
    for (MessageSender sender :senders.keySet()) {
      try {
        sender.onDisconnected();
      } catch (Exception e) {
        LOG.error("Failed disconnecting from alpha at {}", sender.target(), e);
      }
    }
  }

  @Override
  public void close() {
    scheduler.shutdown();
    for(ManagedChannel channel : channels) {
      channel.shutdownNow();
    }
  }

  @Override
  public String target() {
    return "UNKNOWN";
  }

  @Override
  public AlphaResponse send(TxEvent event) {
    return send(event, new FastestSender());
  }

  AlphaResponse send(TxEvent event, MessageSenderPicker messageSenderPicker) {
    do {
      MessageSender messageSender = messageSenderPicker.pick(senders, defaultMessageSender);

      try {
        long startTime = System.nanoTime();
        AlphaResponse response = messageSender.send(event);
        senders.put(messageSender, System.nanoTime() - startTime);

        return response;
      } catch (OmegaException e) {
        throw e;
      } catch (Exception e) {
        LOG.error("Retry sending event {} due to failure", event, e);

        // very large latency on exception
        senders.put(messageSender, Long.MAX_VALUE);
      }
    } while (!Thread.currentThread().isInterrupted());

    throw new OmegaException("Failed to send event " + event + " due to interruption");
  }

  ......
}

/**
 * The strategy of picking the fastest {@link MessageSender}
 */
class FastestSender implements MessageSenderPicker {

  @Override
  public MessageSender pick(Map<MessageSender, Long> messageSenders,
      Supplier<MessageSender> defaultSender) {
    Long min = Long.MAX_VALUE;
    MessageSender sender = null;
    for (Map.Entry<MessageSender, Long> entry : messageSenders.entrySet()) {
      if (entry.getValue() != Long.MAX_VALUE) {
        if (min > entry.getValue()) {
          min = entry.getValue();
          sender = entry.getKey();
        }
      }
    }
    if (sender == null) {
      return defaultSender.get();
    } else {
      return sender;
    }
  }
}
```

### Server streaming gRPC连接中断尝试重连

当与alpha的Server streaming gRPC连接中断后，会往任务队列里扔进一个重新建立Server streaming gRPC连接的任务，而有一个定时执行的单线程池，其会定时扫描该队列里的任务，如有新的任务则会拿出来执行，代码如下：

`incubator-servicecomb-saga/omega/omega-connector/omega-connector-grpc/src/main/java/org/apache/servicecomb/saga/omega/connector/grpc/GrpcCompensateStreamObserver.java`

```java
class GrpcCompensateStreamObserver implements StreamObserver<GrpcCompensateCommand> {
  ......
  @Override
  public void onError(Throwable t) {
    LOG.error("failed to process grpc compensate command.", t);
    errorHandler.run();
  }
  ......
}
```

`incubator-servicecomb-saga/omega/omega-connector/omega-connector-grpc/src/main/java/org/apache/servicecomb/saga/omega/connector/grpc/LoadBalancedClusterMessageSender.java`

```java
public class LoadBalancedClusterMessageSender implements MessageSender {
  ......
  private final BlockingQueue<Runnable> pendingTasks = new LinkedBlockingQueue<>();
  ......
  private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();

  public LoadBalancedClusterMessageSender(AlphaClusterConfig clusterConfig,
      MessageSerializer serializer,
      MessageDeserializer deserializer,
      ServiceConfig serviceConfig,
      MessageHandler handler,
      int reconnectDelay) {

    ......
    scheduleReconnectTask(reconnectDelay);
  }
  ......
  private void scheduleReconnectTask(int reconnectDelay) {
    scheduler.scheduleWithFixedDelay(new Runnable() {
      @Override
      public void run() {
        try {
          pendingTasks.take().run();
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
        }
      }
    }, 0, reconnectDelay, MILLISECONDS);
  }

  class ErrorHandlerFactory {
    Runnable getHandler(MessageSender messageSender) {
      final Runnable runnable = new PushBackReconnectRunnable(messageSender, senders, pendingTasks,
          availableMessageSenders);
      return new Runnable() {
        @Override
        public void run() {
          pendingTasks.offer(runnable);
        }
      };
    }

  }
  ......
}
```

`incubator-servicecomb-saga/omega/omega-connector/omega-connector-grpc/src/main/java/org/apache/servicecomb/saga/omega/connector/grpc/PushBackReconnectRunnable.java`

```java
class PushBackReconnectRunnable implements Runnable {
  private static final Logger LOG = LoggerFactory.getLogger(MethodHandles.lookup().lookupClass());
  private final MessageSender messageSender;
  private final Map<MessageSender, Long> senders;
  private final BlockingQueue<Runnable> pendingTasks;

  private final BlockingQueue<MessageSender> connectedSenders;

  PushBackReconnectRunnable(
      MessageSender messageSender,
      Map<MessageSender, Long> senders,
      BlockingQueue<Runnable> pendingTasks,
      BlockingQueue<MessageSender> connectedSenders) {
    this.messageSender = messageSender;
    this.senders = senders;
    this.pendingTasks = pendingTasks;
    this.connectedSenders = connectedSenders;
  }

  @Override
  public void run() {
    try {
      LOG.info("Retry connecting to alpha at {}", messageSender.target());
      messageSender.onDisconnected();
      messageSender.onConnected();
      senders.put(messageSender, 0L);
      connectedSenders.offer(messageSender);
      LOG.info("Retry connecting to alpha at {} is successful", messageSender.target());
    } catch (Exception e) {
      LOG.error("Failed to reconnect to alpha at {}", messageSender.target(), e);
      pendingTasks.offer(this);
    }
  }
}
```

### 方法执行参数的序列化

在记录saga事件时需要将Compensable方法的执行参数序列化保存下来，用于后面调用补偿方法时使用，这里使用了在java领域比较高效的[kryo](https://github.com/EsotericSoftware/kryo)序列化技术，代码如下：

`incubator-servicecomb-saga/omega/omega-format/src/main/java/org/apache/servicecomb/saga/omega/format/KryoMessageFormat.java`

```java
public class KryoMessageFormat implements MessageFormat {

  private static final int DEFAULT_BUFFER_SIZE = 4096;

  private static final KryoFactory factory = new KryoFactory() {
    @Override
    public Kryo create() {
      return new Kryo();
    }
  };

  private static final KryoPool pool = new KryoPool.Builder(factory).softReferences().build();

  @Override
  public byte[] serialize(Object[] objects) {
    Output output = new Output(DEFAULT_BUFFER_SIZE, -1);

    Kryo kryo = pool.borrow();
    kryo.writeObjectOrNull(output, objects, Object[].class);
    pool.release(kryo);

    return output.toBytes();
  }

  @Override
  public Object[] deserialize(byte[] message) {
    try {
      Input input = new Input(new ByteArrayInputStream(message));

      Kryo kryo = pool.borrow();
      Object[] objects = kryo.readObjectOrNull(input, Object[].class);
      pool.release(kryo);

      return objects;
    } catch (KryoException e) {
      throw new OmegaException("Unable to deserialize message", e);
    }
  }
}
```

omega主体流程的代码解读就到这里了。

## omega的golang实现

servicecomb-saga整个是java实现的，而对于golang语言实现的业务来说，不太好接入，这里为了加深对框架的理解，顺手写了一个omega的golang实现，github地址：[https://github.com/jeremyxu2010/matrix-saga-go](https://github.com/jeremyxu2010/matrix-saga-go)

## 参考

1. https://github.com/apache/incubator-servicecomb-saga



