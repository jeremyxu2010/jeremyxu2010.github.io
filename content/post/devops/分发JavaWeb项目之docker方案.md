---
title: 分发JavaWeb项目之docker方案
tags:
  - java
  - web
  - docker
categories:
  - devops
date: 2017-01-28 23:08:00+08:00
---

最近做了个小的Java Web脚手架工程。工程项目虽小，但算是一个很典型的Java Web项目，依赖于数据库，Java写的后端代码，JavaScript写的前端代码。本来写了一个说明，告诉用户如何将这个工程跑起来，很自然想到有好几步：

- 安装前后端编译工具
- 安装数据库，并初始化数据库结构
- 根据数据库的具体信息，修改项目中的配置文件
- 编译前端代码
- 编译后端代码，最终形成war包
- 将war包部署至应用服务器

想了下，真的好麻烦。突然想到可以使用docker简化应用的分发，于是有了以下尝试，这里记录一下。

## 改造工程

原来加载mysql连接信息配置文件的方式改造了一下，以适应在docker引擎中引用mysql。

`db.xml`

```xml
...
<bean id="propertyConfigurer" class="org.springframework.beans.factory.config.PropertyPlaceholderConfigurer">
    <property name="locations">
        <list>
            <value>classpath:jdbc.properties</value>
            <value>classpath:env.properties</value>
            <value>file:///external/env_overwrite.properties</value>
        </list>
    </property>
    <property name="ignoreResourceNotFound" value="true" />
    <property name="searchSystemEnvironment" value="true" />
    <property name="systemPropertiesModeName" value="SYSTEM_PROPERTIES_MODE_OVERRIDE" />
</bean>
...
```

`jdbc.properties`

```
jdbc_url=jdbc:mysql://${MYSQL_PORT_3306_TCP_ADDR}:${MYSQL_PORT_3306_TCP_PORT}/${MYSQL_ENV_MYSQL_DATABASE}?useUnicode=true
jdbc_user=root
jdbc_password=${MYSQL_ENV_MYSQL_ROOT_PASSWORD}
jdbc_driverClass=com.mysql.jdbc.Driver
```

`env.properties`

```
MYSQL_PORT_3306_TCP_ADDR=127.0.0.1
MYSQL_PORT_3306_TCP_PORT=3306
MYSQL_ENV_MYSQL_DATABASE=ssm-db
MYSQL_ENV_MYSQL_ROOT_PASSWORD=123456
```

这里设置`systemPropertiesModeName`属性为`SYSTEM_PROPERTIES_MODE_OVERRIDE`，这样在解析一个占位符的时候，会先用系统属性来尝试，如果系统属性里没有才会用`env.properties`文件里定义的。

## docker相关配置

项目下新建了`dockerfiles`目录，该目录下有一个`docker-compose.yml`文件，另外一个`initdb`目录下放数据库初始化脚本， 一个`wars`目录下放项目最后打的war包。

```
proj
  - dockerfiles
    - initdb
      - initdb.sql
    - wars
      - proj.war
    - docker-compose.yml
  - src
    - main
      - frontend
      - java
      - resources
      - webapp
  - pom.xml
```

`docker-compose.yml`

```
version: '2'
services:
  ssm-mysql:
    image:  'mysql'
    volumes:
      - ./initdb:/docker-entrypoint-initdb.d
    environment:
      - MYSQL_DATABASE=ssm-db
      - MYSQL_ROOT_PASSWORD=123456
  ssm-web:
    image: 'jetty:9-alpine'
    depends_on:
      - ssm-mysql
    links:
      - ssm-mysql
    volumes:
      - ./wars:/var/lib/jetty/webapps
    ports:
      - "8080:8080"
    environment:
      - MYSQL_PORT_3306_TCP_ADDR=ssm-mysql
      - MYSQL_PORT_3306_TCP_PORT=3306
      - MYSQL_ENV_MYSQL_DATABASE=ssm-db
      - MYSQL_ENV_MYSQL_ROOT_PASSWORD=123456
```

`docker-compose.yml`文件里定义了两个docker service, `ssm-mysql`是数据库服务，`ssm-web`是Web容器服务。

这里遇到了一坑，本来一个容器link另一个容器时，会从另一个容器得到一些环境变量，所以`ssm-web`服务的环境变量声明原本是不需要的，但去掉之后发现`ssm-web`服务跑不起来，好像是根本没有读到原本应该得到的环境变量。查了下原因，最后原因如下：

> links with environment variables: As documented in the environment variables reference, environment variables created by links have been deprecated for some time. In the new Docker network system, they have been removed. You should either connect directly to the appropriate hostname or set the relevant environment variable yourself, using the link hostname:

```
web:
  links:
    - db
  environment:
    - DB_PORT=tcp://db:5432
```

看来以后还是不能依赖于links带来的变量。

## 改造pom.xml文件

最后稍微改造了下`pom.xml`文件

`pom.xml`

```xml
...
<!-- 打war包前安装npm依赖及编译前端代码 -->
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>exec-maven-plugin</artifactId>
    <version>1.3.2</version>
    <executions>
        <execution>
            <id>install_npm_dependences</id>
            <phase>prepare-package</phase>
            <goals>
                <goal>exec</goal>
            </goals>
            <configuration>
                <executable>yarn</executable>
                <workingDirectory>src/main/frontend</workingDirectory>
            </configuration>
        </execution>
        <execution>
            <id>build_frontend</id>
            <phase>prepare-package</phase>
            <goals>
                <goal>exec</goal>
            </goals>
            <configuration>
                <executable>npm</executable>
                <workingDirectory>src/main/frontend</workingDirectory>
                <arguments>
                    <argument>run</argument>
                    <argument>build</argument>
                </arguments>
            </configuration>
        </execution>
    </executions>
</plugin>

<!-- 将编译后的前端代码也打入war包 -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-war-plugin</artifactId>
    <version>3.0.0</version>
    <configuration>
        <webResources>
            <resource>
                <!-- this is relative to the pom.xml directory -->
                <directory>src/main/frontend_react/build</directory>
                <!-- the default value is ** -->
                <includes>
                    <include>**/*</include>
                </includes>
                <!-- there's no default value for this -->
                <excludes>
                    <exclude>asset-manifest.json</exclude>
                    <exclude>**/*.css.map</exclude>
                    <exclude>**/*.js.map</exclude>
                </excludes>
            </resource>
        </webResources>
    </configuration>
</plugin>

<!-- 将最后打出的war包拷贝至dockerfiles/wars目录 -->
<plugin>
    <artifactId>maven-antrun-plugin</artifactId>
    <version>1.8</version>
    <executions>
        <execution>
            <phase>package</phase>
            <configuration>
                <target>
                    <copy file="${basedir}/target/${project.artifactId}.war" tofile="${basedir}/dockerfiles/wars/${project.artifactId}.war" />
                </target>
            </configuration>
            <goals>
                <goal>run</goal>
            </goals>
        </execution>
    </executions>
</plugin>
...
```

## 总结

像上述这样改造后，分发项目就变得很简单了。

- 在工程根目录下执行`mvn package`完成war的构建
- 在`dockerfiles`目录下执行`docker-compose up`
- 使用浏览器访问`http://${docker_host_ip}:8080`

进一步想，其实很多依赖组件较多的项目都可以考虑这样分发。记得以前做的一个项目依赖了`mysql`, `mongodb`, `redis`, `mq`, `zookeeper`，当时每个新加入团队的成员至少要花大半天来搭建开发环境，如果工程这样组织的话，一个新人就能很快将项目运行起来。

本工程源码地址：`http://git.oschina.net/jeremy-xu/ssm-scaffold`

## 参考

`http://javablog.blog.163.com/blog/static/20971116420127109200710/`
`https://docs.docker.com/compose/compose-file/`
`https://yeasy.gitbooks.io/docker_practice/content/compose/install.html`
`https://hub.docker.com/_/mysql/`
`https://hub.docker.com/_/jetty/`
