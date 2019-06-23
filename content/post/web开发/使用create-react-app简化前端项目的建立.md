---
title: 使用create-react-app简化前端项目的建立
tags:
  - react
  - nodejs
categories:
  - web开发
date: 2017-01-25 18:30:00+08:00
---

以往启动一个Web项目，总要从一个现存的项目将`gulpfile.js`, `package.json`拷贝至新项目，然后根据需要修改这两个文件，确实挺麻烦的。今天在github上看到一个评分还比较高的项目[create-react-app](https://github.com/facebookincubator/create-react-app)
。细细看了下它的文档，发现facebook通过这个项目将react的前端项目标准化了，约定大于配置，通过这个工具创建项目方便多了，这里记录一下以备忘。

## 创建项目

执行以下命令：

```bash
#安装create-react-app命令
npm install -g create-react-app
#创建一个名为demo1的前端项目
create-react-app demo1
cd demo1
#这里直接启动了开发服务器
npm start
```

它会自动打开浏览器，并访问`http://127.0.0.1:3000`。

如果修改工程`src`目录下的文件，则会自动编译，并刷新浏览器。如果出现编译错误，终端及浏览器上均会有提示。

## 开发设置

在我实际工作中，一般是用java做后台的，因此要配置前端页面的API都代理至后端的Java Web服务器。

修改`package.json`文件，加入代理设置

```
"proxy": "http://127.0.0.1:8080"
```

配置SpringMVC处理后台的api请求

```
<context-param>
    <param-name>contextConfigLocation</param-name>
    <param-value>classpath:applicationContext.xml</param-value>
</context-param>
<listener>
    <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
</listener>
<servlet>
    <servlet-name>springmvc</servlet-name>
    <servlet-class>org.springframework.web.servlet.DispatcherServlet</servlet-class>
    <load-on-startup>1</load-on-startup>
    <init-param>
        <param-name>contextConfigLocation</param-name>
        <param-value>classpath:spring/mvc.xml</param-value>
    </init-param>
</servlet>
<servlet-mapping>
    <servlet-name>springmvc</servlet-name>
    <url-pattern>/api/*</url-pattern>
</servlet-mapping>
```

实际开发时，先启动Java Web服务器，再执行`npm start`启动Web开发服务器，然后就可以开发了。

## Java Web应用启用browserHistory

如果前端使用了`browserHistory`, 则后台还需处理TryFiles的逻辑，TryFilesFilter在web.xml里的配置如下：

```xml
<filter>
    <filter-name>TryFiles</filter-name>
    <filter-class>personal.jeremyxu.filter.TryFilesFilter</filter-class>
    <init-param>
        <param-name>files</param-name>
        <param-value>$path /index.html</param-value>
    </init-param>
    <init-param>
        <param-name>excludes</param-name>
        <param-value>/api</param-value>
    </init-param>
</filter>
<filter-mapping>
    <filter-name>TryFiles</filter-name>
    <url-pattern>/*</url-pattern>
</filter-mapping>
```

TryFilesFilter的代码见[这里](http://git.oschina.net/jeremy-xu/ssm-scaffold/raw/master/src/main/java/personal/jeremyxu/filter/TryFilesFilter.java?dir=0&filepath=src%2Fmain%2Fjava%2Fpersonal%2Fjeremyxu%2Ffilter%2FTryFilesFilter.java)

## 重新组织工程目录结构

在我实际工作中，一般是用java做后台的，因而希望直接将前端代码放到maven的webapp工程里，所以我一般是下面这样组织目录结构的。

```
demo1/
  src/
    main/
      frontend/
        src/
          js/
            index.js
            actions/
            components/
            constants/
            i18n/
            reducers/
            utils/
          css/
        public/
          index.html
          static/
        package.json
        .gitignore
      java
      webapp
        WEB-INF
  pom.xml
```

创建一个frontend的目录与java目录平级，这里放置前端源代码。

然后修改maven项目的pom.xml文件，确保打war包能自动编译前端代码，并将编译后的文件打入war包里。

```xml
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>exec-maven-plugin</artifactId>
    <version>1.3.2</version>
    <executions>
        <execution>
            <phase>prepare-package</phase>
            <goals>
                <goal>exec</goal>
            </goals>
        </execution>
    </executions>
    <configuration>
        <executable>npm</executable>
        <workingDirectory>src/main/frontend</workingDirectory>
        <arguments>
            <argument>run</argument>
            <argument>build</argument>
        </arguments>
    </configuration>
</plugin>

<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-war-plugin</artifactId>
    <version>3.0.0</version>
    <configuration>
        <webResources>
            <resource>
                <!-- this is relative to the pom.xml directory -->
                <directory>src/main/frontend/build</directory>
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
```

## 总结

用`create-react-app`快速创建前端项目确实很方便，省去了用gulp、webpack写编译脚本的麻烦，约定大于配置的思想贯彻得挺好的，以后创建新项目就靠你了。

项目完整源码见[这里](http://git.oschina.net/jeremy-xu/ssm-scaffold)。



