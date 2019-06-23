---
title: Spring Boot学习备忘
date: 2017-09-18 00:20:00+08:00
author: 徐新杰
tags:
  - java
  - spring
  - spring boot
categories:
  - java开发
---



# Spring Boot学习备忘

Spring Boot简化了基于Spring的应用开发，只需要"run"就能创建一个独立的，产品级别的Spring应用。工作即将使用到Spring Boot，这里将自学Spring Boot的一些操作经验记录一下。 

## Spring Boot Cli

创建第一个Spring Boot应用有多种方式，我这里选用最简单的Spring Boot Cli方案。

### 安装Spring Boot Cli

我是使用macOS系统的，已经安装了Java8、maven、OSX Homebrew，安装Spring Cli就变得很简单了。

```bash
brew tap pivotal/tap
brew install springboot
spring version #验证安装的Spring Boot版本
```

### 使用Spring Boot  Cli

验证Spring Boot  Cli是否可正常工作也比较简单，先写一个`app.groovy`, 内容如下：

```groovy
@RestController
class ThisWillActuallyRun {

    @RequestMapping("/")
    String home() {
        "Hello World!"
    }

}
```

然后执行下面的命令：

```bash
spring run app.groovy
```

最后请求测试一下：

```bash
curl http://127.0.0.1:8080
```

使用Spring Boot Cli创建工程：

```bash
spring init --groupId=personal.jeremyxu --artifactId=springboottest --name=springboottest --description="Spring Boot Test Project" --dependencies=web
mkdir springboottest
unzip springboottest.zip -d springboottest
```

`spring init`执行时可以有不少参数，可以通过执行`spring init --list`命令来查看，详细文档可以参看[这里](https://docs.spring.io/spring-boot/docs/current/reference/html/cli-using-the-cli.html)。

工程创建后，简单地添加一个测试Controller，如下：

```java
package personal.jeremyxu.springboottest.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Created by jeremy on 2017/9/10.
 */
@RestController
public class GreetingController {

    @RequestMapping(value = "/")
    public String sayHello(){
        return "Hello World!";
    }
}
```

再在`SpringboottestApplication`里加上`@EnableAutoConfiguration`，然后便可运行Spring Boot应用了：

```bash
cd springboottest
spring run .
```

还是通过命令测试一下：

```bash
curl http://127.0.0.1:8080
```

代码写完后，执行下面的命令打包：

```bash
cd springboottest
mkdir -p ./target
spring jar ./target/springboottest.jar .
```

后面执行下面的命令就可以简单将工程运行起来了：

```bash
java -jar ./target/springboottest.jar
```

## 编写测试用例

以前写代码时不怎么关注测试用例，其实测试用例还是很重要的，这里将上面的小例子补上测试用例，测试用例的写法可以参考[这里](https://github.com/spring-projects/spring-boot/blob/master/spring-boot-samples/spring-boot-sample-test/src/main/java/sample/test/SampleTestApplication.java)。

`SpringboottestApplicationTests.java`

```java
import org.junit.Assert;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.rule.OutputCapture;
import org.springframework.test.context.junit4.SpringRunner;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

@RunWith(SpringRunner.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class SpringboottestApplicationTests {

	private static final String SPRING_STARTUP = "root of context hierarchy";

	@Rule
	public OutputCapture outputCapture = new OutputCapture();

	@Test
	public void contextLoads() {
		SpringboottestApplication.main(getArgs());
		Assert.assertTrue(getOutput().contains(SPRING_STARTUP));
	}

	private String[] getArgs(String... args) {
		List<String> list = new ArrayList<>(Arrays.asList(
				"--spring.main.webEnvironment=false", "--spring.main.showBanner=OFF",
				"--spring.main.registerShutdownHook=false"));
		if (args.length > 0) {
			list.add("--spring.main.sources="
					+ StringUtils.arrayToCommaDelimitedString(args));
		}
		return list.toArray(new String[list.size()]);
	}

	private String getOutput() {
		return this.outputCapture.toString();
	}

}
```

`GreetingControllerTests.java`

```java
import org.hamcrest.Matchers;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.junit4.SpringRunner;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;


/**
 * Created by jeremy on 2017/9/10.
 */
@RunWith(SpringRunner.class)
@WebMvcTest(GreetingController.class)
public class GreetingControllerTests {

    @Autowired
    private MockMvc mvc;

    @Test
    public void sayHello() throws Exception {
        mvc.perform(MockMvcRequestBuilders.get("/sayHello")
                .accept(MediaType.TEXT_PLAIN))
                .andExpect(MockMvcResultMatchers.status().isOk())
                .andExpect(MockMvcResultMatchers.content().string(Matchers.equalTo("Hello World!")));
    }
}
```

在IDEA里选中工程包，然后`Run 'Tests in …' with Coverage`, 然后就可以看到源代码的测试代码覆盖率为100%了，perfect!
