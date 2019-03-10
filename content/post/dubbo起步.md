---
title: dubbo起步
author: Jeremy Xu
tags:
  - dubbox
  - 微服务
  - rpc
categories:
  - java开发
date: 2016-12-05 19:58:00+08:00
---
之前在项目中使用过dubbo，但很久没有再用，以致都忘了它的用法，今天看到当当网开源的一个项目[dubbox](http://dangdangdotcom.github.io/dubbox/), 觉得挺实用的。这里先将dubbo的概念及用法记录下来以备忘。

## 快速启动

如果是在一个进程内不同的组件调用，一般在spring里是如下配置的：

```xml

<bean id=“xxxService” class=“com.xxx.XxxServiceImpl” />

<!-- xxxAction注入xxxService -->
<bean id=“xxxAction” class=“com.xxx.XxxAction”>
    <property name=“xxxService” ref=“xxxService” />
</bean>
```

但如果跨进程或跨主机，就不同这么简单的调用了，即会引入RPC框架。dubbo作为一个完善的RPC框架提供的解决方案还算比较简单。

### 准备注册中心

这里可以使用zookeeper、redis、multicast、simple四种方式，这里先采用官方首推的zookeeper。

```bash
tar xf zookeeper-3.4.9.tar.gz
mv zookeeper-3.4.9 zookeeper
cd zookeeper
cp conf/zoo_sample.cfg conf/zoo.cfg
vim conf/zoo.cfg #修改dataDir
./bin/zkServer.sh start #启动zkServer
```

当然，为了避免单点故障，在生产环境应该部署zkServer集群。

### 准备公共接口

`DemoService.java`

```java
public interface DemoService {
    String sayHello(String name);
}
```

### 服务提供方实现与配置

* 服务提供方实现公共接口

`DemoServiceImpl.java`

```java
public class DemoServiceImpl implements DemoService{
    @Override
    public String sayHello(String name) {
        return "hello, " + name;
    }
}
```

* 将服务为dubbo的方式暴露出来

`remote-provider.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:dubbo="http://code.alibabatech.com/schema/dubbo"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
       http://www.springframework.org/schema/beans/spring-beans.xsd
       http://code.alibabatech.com/schema/dubbo
       http://code.alibabatech.com/schema/dubbo/dubbo.xsd">
    <!-- 提供方应用信息，用于计算依赖关系 -->
    <dubbo:application name="hello-world-app"  organization="personal.jeremyxu"  owner="jeremyxu"/>
    <dubbo:registry address="zookeeper://127.0.0.1:2181" />
    <bean id="demoService" class="personal.jeremyxu.impl.DemoServiceImpl" /> <!-- 和本地服务一样实现远程服务 -->
    <dubbo:service interface="personal.jeremyxu.api.DemoService" ref="demoService" /> <!-- 增加暴露远程服务配置 -->
</beans>
```

* 服务提供方启动器

`ServiceProviderApp.java`

```java
public class ServiceProviderApp {
    public static void main( String[] args ) throws IOException {
        Properties props = System.getProperties();
        props.setProperty("dubbo.spring.config", "classpath:remote-provider.xml");
        Main.main(args);
    }
}
```

### 服务消费方实现与配置

* 使用dubbo的方式引入远程服务

`remote-consumer.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:dubbo="http://code.alibabatech.com/schema/dubbo"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
       http://www.springframework.org/schema/beans/spring-beans.xsd
       http://code.alibabatech.com/schema/dubbo
       http://code.alibabatech.com/schema/dubbo/dubbo.xsd">
    <!-- 提供方应用信息，用于计算依赖关系 -->
    <dubbo:application name="consumer-of-hello-world-app"   organization="personal.jeremyxu"  owner="jeremyxu" />
    <dubbo:registry address="zookeeper://127.0.0.1:2181" />
    <!-- 生成远程服务代理，可以和本地bean一样使用demoService -->
    <dubbo:reference id="demoService" interface="personal.jeremyxu.api.DemoService" />
</beans>
```

* 服务消费方启动器

`ServiceConsumerApp.java`

```java
public class ServiceConsumerApp {
    public static void main(String[] args) throws InterruptedException {
        ApplicationContext appCtx = new ClassPathXmlApplicationContext("remote-consumer.xml");
        DemoService demoService = (DemoService)appCtx.getBean("demoService");
        for(int i=0; i<100000; i++) {
            System.out.println(demoService.sayHello("xxj"));
            Thread.sleep(2000L);
        }
    }
}
```

### 依赖的jar包

```xml
<dependency>
  <groupId>org.springframework</groupId>
  <artifactId>spring-context</artifactId>
  <version>4.3.3.RELEASE</version>
</dependency>
<dependency>
  <groupId>com.alibaba</groupId>
  <artifactId>dubbo</artifactId>
  <version>2.5.3</version>
</dependency>
<dependency>
  <groupId>com.101tec</groupId>
  <artifactId>zkclient</artifactId>
  <version>0.10</version>
</dependency>
```

先后启动服务提供方与服务消费方，即可正常运行。

## 高级特性

可以看到快速启动还是比较容易的，但dubbo可没这么简单，它还有不少高级特性，参见[这里](http://dubbo.io/User+Guide-zh.htm#UserGuide-zh-%E5%8A%9F%E8%83%BD%E6%88%90%E7%86%9F%E5%BA%A6)。

dubbo在逻辑上分了很多层，每个层里都有好几个实现策略可以选择，参见[这里](http://dubbo.io/User+Guide-zh.htm#UserGuide-zh-%E7%AD%96%E7%95%A5%E6%88%90%E7%86%9F%E5%BA%A6)。可能会根据实现场景配置注册中心、协议、NIO框架、序列化框架、ProxyFactory动态代理实现、集群策略、负载均衡策略、路由策略、服务运行容器。

## 换用dubbox

dubbox相对于dubbox来说，新增了一些很有用的特性：

* 支持REST风格远程调用（HTTP + JSON/XML)：基于非常成熟的JBoss RestEasy框架，在dubbo中实现了REST风格（HTTP + JSON/XML）的远程调用，以显著简化企业内部的跨语言交互，同时显著简化企业对外的Open API、无线API甚至AJAX服务端等等的开发。事实上，这个REST调用也使得Dubbo可以对当今特别流行的“微服务”架构提供基础性支持。 另外，REST调用也达到了比较高的性能，在基准测试下，HTTP + JSON与Dubbo 2.x默认的RPC协议（即TCP + Hessian2二进制序列化）之间只有1.5倍左右的差距，详见文档中的基准测试报告。

* 支持基于Kryo和FST的Java高效序列化实现：基于当今比较知名的Kryo和FST高性能序列化库，为Dubbo默认的RPC协议添加新的序列化实现，并优化调整了其序列化体系，比较显著的提高了Dubbo RPC的性能，详见文档中的基准测试报告。

* 支持基于Jackson的JSON序列化：基于业界应用最广泛的Jackson序列化库，为Dubbo默认的RPC协议添加新的JSON序列化实现。

* 支持基于嵌入式Tomcat的HTTP remoting体系：基于嵌入式tomcat实现dubbo的HTTP remoting体系（即dubbo-remoting-http），用以逐步取代Dubbo中旧版本的嵌入式Jetty，可以显著的提高REST等的远程调用性能，并将Servlet API的支持从2.5升级到3.1。（注：除了REST，dubbo中的WebServices、Hessian、HTTP Invoker等协议都基于这个HTTP remoting体系）。

* 升级Spring：将dubbo中Spring由2.x升级到目前最常用的3.x版本，减少版本冲突带来的麻烦。

* 升级ZooKeeper客户端：将dubbo中的zookeeper客户端升级到最新的版本，以修正老版本中包含的bug。

* 支持完全基于Java代码的Dubbo配置：基于Spring的Java Config，实现完全无XML的纯Java代码方式来配置dubbo

注：dubbox和dubbo 2.x是兼容的，没有改变dubbo的任何已有的功能和配置方式（除了升级了spring之类的版本）

因为dubbox与dubbo 2.x是兼容的，因此不用修改代码，可直接替换dubbox，步骤如下：

### 编译dubbox

```bash
git clone https://github.com/dangdangdotcom/dubbox.git
cd dubbox
#确保JAVA_HOME指向JDK7
mvn -Dmaven.test.skip=true clean package install
```

### 修改pom.xml依赖

```xml
    <dependency>
      <groupId>com.alibaba</groupId>
      <artifactId>dubbo</artifactId>
      <version>2.8.4</version>
    </dependency>
```

## 使用dubbox的特性

换用dubbox必然是为了使用dubbox的一些新增特性，这里我参考[在Dubbo中使用高效的Java序列化（Kryo和FST）](http://dangdangdotcom.github.io/dubbox/serialization.html)，为dubbo换用的kryo序列化方法。

### 添加maven依赖

```xml
<dependency>
    <groupId>com.esotericsoftware.kryo</groupId>
    <artifactId>kryo</artifactId>
    <version>2.24.0</version>
</dependency>
<dependency>
    <groupId>de.javakaffee</groupId>
    <artifactId>kryo-serializers</artifactId>
    <version>0.26</version>
</dependency>
```

### 配置使用kryo序列化实现

在服务提供者及服务消费者的dubbo配置中增加以下配置：

```xml
<dubbo:protocol serialization="kryo"/>
```

经过对比，可以发现RPC调用的平均处理时间降低了不少。

## 配置Monitor

dubbo的核心概念里有一个Monitor，这个组件负责统计服务的调用频率和调用时间，它也是作为一个Dubbo服务部署的。

### 添加maven依赖

```xml
<dependency>
  <groupId>com.alibaba</groupId>
  <artifactId>dubbo-monitor-simple</artifactId>
  <version>2.8.4</version>
</dependency>
```

### 创建monitor服务的配置

`simple-monitor.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:dubbo="http://code.alibabatech.com/schema/dubbo"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
       http://www.springframework.org/schema/beans/spring-beans.xsd
       http://code.alibabatech.com/schema/dubbo
       http://code.alibabatech.com/schema/dubbo/dubbo.xsd">
    <!-- 提供方应用信息，用于计算依赖关系 -->
    <dubbo:application name="simple-monitor" organization="personal.jeremyxu"  owner="jeremyxu"/>
    <dubbo:registry address="zookeeper://127.0.0.1:2181" />
    <bean id="monitorService" class="com.alibaba.dubbo.monitor.simple.SimpleMonitorService" >
        <property name="statisticsDirectory" value="/tmp/monitor/statistics"/>
        <property name="chartsDirectory" value="/tmp/monitor/charts"/>
    </bean>
    <dubbo:service interface="com.alibaba.dubbo.monitor.MonitorService" ref="monitorService"/>
    <dubbo:reference id="registryService" interface="com.alibaba.dubbo.registry.RegistryService" />
</beans>
```

### 创建Monitor服务的启动器

`MonitorApp.java`

```java
public class MonitorApp {
    public static void main( String[] args ) throws IOException {
        Properties props = System.getProperties();
        props.setProperty("dubbo.spring.config", "classpath:simple-monitor.xml");
        props.setProperty("dubbo.container", "spring,jetty,registry");
        props.setProperty("dubbo.registry.address", "zookeeper://127.0.0.1:2181");
        props.setProperty("dubbo.jetty.port", "8889");
        props.setProperty("dubbo.jetty.directory", "/tmp/monitor");
        Main.main(args);
    }
}
```

### 修改服务提供方与消费方的dubbo配置文件

在服务提供方与消费方的dubbo配置文件中添加Monitor相关配置

```xml
<dubbo:monitor protocol="registry"/>
```

最后访问`http://${monitor_ip}:8889`, 即可通过网页看到服务的状态，还可以以图形化的方式查看服务的调用频率和调用时间。

## dubbo管理控制台

dubbo还提供了图形化的管理控制台用以管理dubbo内部的服务。部署方法可参考[这里](http://dubbo.io/Administrator+Guide-zh.htm#AdministratorGuide-zh-%E7%AE%A1%E7%90%86%E6%8E%A7%E5%88%B6%E5%8F%B0%E5%AE%89%E8%A3%85)

## 总结

dubbo作为一个服务治理框架，提供的功能还是比较完备的，选项也很丰富，在微服务架构体系中可以得到较多应用。
