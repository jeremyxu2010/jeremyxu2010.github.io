---
title: TypeScript项目小结
tags:
  - nodejs
  - log4js
  - sourcemap
  - async_hooks
  - clinic
  - jaeger
categories:
  - nodejs开发
date: 2020-11-22 20:54:00+08:00
---



最近一段时间用TypeScript做了个项目，项目相关的业务代码没有过度封装，就是仿造`Java MVC框架`简单地分了层。编写业务代码的日子较为枯燥，没什么好说的。不过项目后期处理一些`日志上报`、`监控数据上报`、`性能调优`的通用任务比较有意思，这里记录一下。

## 解决的问题

### 上报日志

前提：

1）项目用的日志框架是[log4js-node](https://github.com/log4js-node/log4js-node) 
2）公司内部有一个特有的日志服务，可以通过API接口将日志上报上去

前期在业务代码中已经通过`log4js`的API打印了日志，现在需要尽量不修改业务代码，将打印的日志上报到这个特有日志服务上去。查阅[log4js的文档](https://log4js-node.github.io/log4js-node/appenders.html)，发现可以通过自定义Appender的方式解决这个问题，示例代码如下：

`reportLogAppenderConfigure.ts`

```typescript
// This is the function that generates an appender function
function reportLogAppender(layout) {
  // This is the appender function itself
  return (loggingEvent) => {
    const msg = `${layout(loggingEvent)}`
    // report to log system
    ...
  };
}

// reportLogAppender configure doesn't need to use findAppender, or levels
export default function configure(config, layouts) {
  // the default layout for the appender
  let layout = layouts.colouredLayout;
  // check if there is another layout specified
  if (config.layout) {
    // load the layout
    layout = layouts.layout(config.layout.type, config.layout);
  }
  //create a new appender instance
  return reportLogAppender(layout);
}
```

`logConfig.ts`

```typescript
import log4js from 'log4js';
import reportLogAppenderConfigure from 'reportLogAppenderConfigure';

log4js.configure({
  appenders: { 
    reportLogAppender: { 
      type: { 
        configure:  reportLogAppenderConfigure 
      }
    } 
  },
  categories: { 
    default: { 
      appenders: ['reportLogAppender'], 
      level: 'debug' 
    } 
  },
  disableClustering: true
});
```

### 输出日志的位置信息

前提：项目是用`TypeScript`代码写的，在服务器上运行时是提前编译成javascript代码的。而希望打印出的日志中希望能包含输出日志语句的准确代码位置。

查阅[log4js的文档](https://log4js-node.github.io/log4js-node/layouts.html)，发现其本身就支持输出打印日志语句的代码位置。另外要正确输出代码位置，需要使用SourceMap了。使用简述如下：

在node进程入口处安装`source-map-support`：

```typescript
import sourceMapSupport from 'source-map-support';

if (process.env.NODE_ENV === 'production') {
	sourceMapSupport.install();
}
```

用`tsc`命令编译时带`--sourceMap`参数：

```bash
tsc --sourceMap app_ts.ts
```

配置appender使用的layout, category要开启enableCallStack：

```typescript
log4js.configure({
  appenders: { 
    reportLogAppender: { 
      type: { 
        configure:  reportLogAppenderConfigure 
      }, 
      layout: {
				type: 'pattern',
				pattern: '%r %p %c [%f:%l] : %m',
  		} 
    } 
  },
  categories: { 
    default: { 
      appenders: ['reportLogAppender'], 
      level: 'debug',
      enableCallStack: true
    } 
  },
  disableClustering: true
});
```

### 同一个请求的所有日志带RequestId

前提：同一个请求的处理代码调用关系比较复杂，每个函数都会打印日志。希望同一个请求的所有日志都带上相同的RequestId。

参阅[Async hooks](https://nodejs.org/api/async_hooks.html)的文档，发现可以简单使用`AsyncLocalStorage`完成这个任务，这个相当于Java里的ThreadLocal。示例代码如下：

```typescript
import uuid from 'node-uuid';
import { AsyncLocalStorage } from 'async_hooks';

const asyncLocalStorage = new AsyncLocalStorage();

const log = message => {
  const requestId = asyncLocalStorage.getStore();
  if (requestId) {
    logger.info(`[${requestId}] ${message}`);
  }
  else { 
    logger.info(message);
  }
};

app.get('/', (request, response) => {
  const requestId = uuid();
  asyncLocalStorage.run(requestId, async () => {    
    // entering asynchronous context
    log('Start processing')
    const emailService = new EmailService();
    await emailService.notify(request.body.emails);
    response.writeHead(200);
  });
});

class EmailService {
  async notify (emails) {
    for (const email of emails) {
      log(`Send email: ${email}`);
      await otherService.send(email);
    }
  }
}
```

### 性能诊断

node生态中有很多性能诊断工具，但看了一圈还是发现`node-clinic`强大好用。示例如下：

```bash
# 全局安装 clinic
$ npm i clinic -g

# 使用 clinic doctor 启动并诊断 Node.js 应用
$ clinic doctor -- node app.js

# 使用 ab 压测
$ ab -c 10 -n 200 "http://localhost:3000/"

# 压测完毕后，CTRL+C 终止测试程序，终端打印出
Warning: Trace event is an experimental feature and could change at any time.
^Canalysing data
generated HTML file is 51485.clinic-doctor.html

# 用浏览器打开 51485.clinic-doctor.html即可，这个页面中有CPU、内存等信息的图表，还有猜测的问题原因和解决方案

# 还可以使用 clinic flame 生成火焰图
$ clinic flame -- node app.js
# 或
$ clinic flame --collect-only -- node app.js # 只收集数据
$ clinic flame --visualize-only PID.flamegraph # 将数据生成火焰图
```

### 调用链跟踪

可以使用[ koa-await-breakpoint-jaeger](https://github.com/nswbmw/koa-await-breakpoint-jaeger)自动完成调用链跟踪。

首先启动`jaeger`服务：

```bash
# 使用 Docker 启动 Jaeger + Jaeger UI（Jaeger 可视化 web 控制台）
$ docker run -d -p5775:5775/udp \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 14268:14268 \
  jaegertracing/all-in-one:latest
```

在koa程序的入口添加配置，使应用自动埋点上报调用链路径数据。

```typescript
import Koa from 'koa';
import JaegerStore from 'koa-await-breakpoint-jaeger';
import koaAwaitBreakpoint from 'koa-await-breakpoint';
import jaeger from 'jaeger-client';
import UDPSender from 'jaeger-client/dist/src/reporters/udp_sender';
koaAwaitBreakpoint({
  name: 'tracing',
  files: ['./routes/*.js'],
  store: new JaegerStore({
    reporter: new jaeger.RemoteReporter(new UDPSender({
      host: 127.0.0.1,
      port: 6831
    })),
    sampler: new jaeger.ConstSampler(true)
  })
});

const app = new Koa();
app.use(koaAwaitBreakpoint)
app.route({ method: 'POST', path: '/users', controller: require('./routes/user').createUser })
app.listen(3000)
```

## 总结

在做这些工作的过程中，不仅学到了挺多知识，还发掘了一本不错的书---[Node.js 调试指南](https://www.bookstack.cn/books/node-in-debugging)。这本书里讲了Node.js应用的很多开发技巧，很实用。

## 参考

1. https://log4js-node.github.io/log4js-node/appenders.html
2. https://log4js-node.github.io/log4js-node/writing-appenders.html
3. https://www.bookstack.cn/read/node-in-debugging/README.md
4. https://www.bookstack.cn/read/node-in-debugging/SourceMap.md
5. https://log4js-node.github.io/log4js-node/layouts.html
6. https://blog.kuzzle.io/nodejs-14-asynclocalstorage-asynchronous-calls
7. https://nodejs.org/api/async_hooks.html#async_hooks_class_asynclocalstorage
8. https://www.bookstack.cn/read/node-in-debugging/8.1node-clinic.md
9. https://www.bookstack.cn/read/node-in-debugging/6.4OpenTracingJaeger.md

