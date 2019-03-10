---
title: servicecomb-saga开发实战
tags:
  - microservice
  - java
categories:
  - microservice
date: 2018-07-02 17:50:00+08:00
---

最近的工作主要是微服务框架的设计与开发，期间要解决多个微服务的分布式事务问题，由于要解决的主要场景是用spring boot写的java项目，最终选择了业界成熟的servicecomb-saga方案，这里稍微记录下以备忘。

## 为何会有分布式事务

这里不作深入叙述，网上有相当好的参考资料-[聊聊分布式事务，再说说解决方案](https://www.cnblogs.com/savorboard/p/distributed-system-transaction-consistency.html)。

## 为何选择saga方案

参考[聊聊分布式事务，再说说解决方案](https://www.cnblogs.com/savorboard/p/distributed-system-transaction-consistency.html)，可以看到

1. 两阶段提交方案实现较复杂，而且对性能影响太大；
2. TCC方案好像只有阿里内部在大规模使用；
3. 本地消息表方案消息表会耦合到业务系统，不太优雅；
4. MQ事务消息方案依赖于有事务消息的MQ中间件。

最后好像也只好选择saga方案，另外有了servicecomb-saga后，spring-boot应用要使用分布式事务还是挺容易的。

## servicecomb-saga的架构

servicecomb-saga的架构可直接参考其[官方文档](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/design_zh.md)，写得还是比较详细的。

### 概览

Pack中包含两个组件，即 **alpha** 和 **omega**。

- alpha充当协调者的角色，主要负责对事务的事件进行持久化存储以及协调子事务的状态，使其得以最终与全局事务的状态保持一致。
- omega是微服务中内嵌的一个agent，负责对网络请求进行拦截并向alpha上报事务事件，并在异常情况下根据alpha下发的指令执行相应的补偿操作。

[![Pack Architecture](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/pack.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/pack.png)

### Omega内部运行机制

omega是微服务中内嵌的一个agent。当服务收到请求时，omega会将其拦截并从中提取请求信息中的全局事务id作为其自身的全局事务id（即Saga事件id），并提取本地事务id作为其父事务id。在预处理阶段，alpha会记录事务开始的事件；在后处理阶段，alpha会记录事务结束的事件。因此，每个成功的子事务都有一一对应的开始及结束事件。

[![Omega Internal](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/omega_internal.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/omega_internal.png)

### 服务间通信流程

服务间通信的流程与[Zipkin](https://github.com/openzipkin/zipkin)的类似。在服务生产方，omega会拦截请求中事务相关的id来提取事务的上下文。在服务消费方，omega会在请求中注入事务相关的id来传递事务的上下文。通过服务提供方和服务消费方的这种协作处理，子事务能连接起来形成一个完整的全局事务。

[![Inter-Service Communication](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/inter-service_communication.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/inter-service_communication.png)

### 具体处理流程

#### 成功场景

成功场景下，每个开始的事件都会有对应的结束事件。

[![Successful Scenario](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/successful_scenario.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/successful_scenario.png)

#### 异常场景

异常场景下，omega会向alpha上报中断事件，然后alpha会向该全局事务的其它已完成的子事务发送补偿指令，确保最终所有的子事务要么都成功，要么都回滚。

[![Exception Scenario](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/exception_scenario.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/exception_scenario.png)

#### 超时场景

超时场景下，已超时的事件会被alpha的定期扫描器检测出来，与此同时，该超时事务对应的全局事务也会被中断。

[![Timeout Scenario](https://github.com/apache/incubator-servicecomb-saga/raw/master/docs/static_files/timeout_scenario.png)](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/static_files/timeout_scenario.png)

## 使用servicecomb-saga

下面的过程也是参考[官方文档](https://github.com/apache/incubator-servicecomb-saga/blob/master/docs/user_guide_zh.md)，但由于我这里使用mysql数据库作为底层数据库，修改了少量操作。

### 准备环境

1. 安装[JDK 1.8](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)

2. 安装[Maven 3.x](https://maven.apache.org/install.html)

### 编译

获取源码：

```bash
$ git clone https://github.com/apache/incubator-servicecomb-saga.git
$ cd incubator-servicecomb-saga
```

构建mysql的可执行文件：

```bash
$ mvn clean install -DskipTests -Pmysql
```

### 创建数据库

创建数据库并给予用户访问该数据库的权限

```bash
$ mysql
mysql> create database saga default character set utf8;
mysql> GRANT ALL PRIVILEGES ON saga.* to 'saga'@'localhost' identified by '123456';
mysql> flush priveleges;
mysql> exit
```

### 启动alpha-server

直接使用java命令启动alpha-server

```bash
java -Dspring.profiles.active=mysql -D"spring.datasource.url=jdbc:mysql://localhost:3306/saga?useSSL=false" -D"spring.datasource.username=saga" -D"spring.datasource.password=123456"  -jar alpha/alpha-server/target/saga/alpha-server-0.3.0-SNAPSHOT-exec.jar
```

### 配置Omega

按照servicecomb-saga的架构，所有支持分布式事务的spring-boot应用须配置Omega。其实也比较简单，大概有以下这些步骤。

#### 引入Saga的依赖

应用的pom.xml配置文件中引入servicecomb-saga的依赖

```
    <dependency>
      <groupId>org.apache.servicecomb.saga</groupId>
      <artifactId>omega-spring-starter</artifactId>
      <version>0.3.0-SNAPSHOT</version>
    </dependency>
    <dependency>
      <groupId>org.apache.servicecomb.saga</groupId>
      <artifactId>omega-transport-resttemplate</artifactId>
      <version>0.3.0-SNAPSHOT</version>
    </dependency>
```

#### 添加Saga的注解及相应的补偿方法

以一个转账应用为例：

1. 在应用入口添加 `@EnableOmega` 的注解来初始化omega的配置并与alpha建立连接。

   ```
   @SpringBootApplication
   @EnableOmega
   public class Application {
     public static void main(String[] args) {
       SpringApplication.run(Application.class, args);
     }
   }
   ```

2. 在全局事务的起点添加 `@SagaStart` 的注解。

   ```
   @SagaStart(timeout=10)
   public boolean transferMoney(String from, String to, int amount) {
     transferOut(from, amount);
     transferIn(to, amount);
   }
   ```

   **注意: 默认情况下，超时设置需要显式声明才生效。**

3. 在子事务处添加 `@Compensable` 的注解并指明其对应的补偿方法。

   ```
   @Compensable(timeout=5, compensationMethod="cancel")
   public boolean transferOut(String from, int amount) {
     repo.reduceBalanceByUsername(from, amount);
   }
   
   public boolean cancel(String from, int amount) {
     repo.addBalanceByUsername(from, amount);
   }
   ```

   **注意: 实现的服务和补偿必须满足幂等的条件。**

   **注意: 默认情况下，超时设置需要显式声明才生效。**

   **注意: 若全局事务起点与子事务起点重合，需同时声明 `@SagaStart` 和 `@Compensable` 的注解。**

4. 对转入服务重复第三步即可。

#### 配置omega的spring配置项

在`application.properties`中添加下面的配置项：

```
alpha.cluster.address=127.0.0.1:8080 #这个指向alpha server的grpc地址
```

然后就可以运行相关的微服务了，可通过访问http://127.0.0.1:8090/events 来查询所有的saga事件信息。

## 总结

本篇只大概介绍了下servicecomb-saga的使用过程，主要内容都是参考其官方文档，其实也花了些时间走读它的源码，对其实现原理有一定了解了，后面抽时间再写一篇具体分析其源代码。

## 参考

1. https://github.com/apache/incubator-servicecomb-saga/blob/master/docs
2. https://www.cnblogs.com/savorboard/p/distributed-system-transaction-consistency.html