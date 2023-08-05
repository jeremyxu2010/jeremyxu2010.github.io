---
title: 研究调用链跟踪技术之jaeger
tags:
  - golang
  - jaeger
categories:
  - 微服务
date: 2018-07-22 12:30:00+08:00
---

最近在做微服务构架里有关调用链跟踪（也有叫分布式追踪）的部分，有一些心得，这里总结一些。

## 为什么有必要跟踪调用链

当我们进行微服务架构开发时，通常会根据业务来划分微服务，各业务之间通过REST进行调用。一个用户操作，可能需要很多微服务的协同才能完成，如果在业务调用链路上任何一个微服务出现问题或者网络超时，都会导致功能失败。随着业务越来越多，对于微服务之间的调用链的分析会越来越复杂。通过追踪调用链，我们可以很方便的理清各微服务间的调用关系，同时调用链还可以帮助我们：

- **耗时分析:** 通过Sleuth可以很方便的了解到每个采样请求的耗时，从而分析出哪些服务调用比较耗时;
- **可视化错误:** 对于程序未捕捉的异常，可以通过集成的界面上看到;
- **链路优化:** 对于调用比较频繁的服务，可以针对这些服务实施一些优化措施。

## 调用链跟踪系统选型

拿`Distributed Tracing`这个关键词在google里搜索，基本第一页就列出了最流行的分布式追踪系统：[OpenZipkin](https://zipkin.io/)、[Jaeger](https://www.jaegertracing.io/)。那就直接在这两个里选型好了。

### 特性对比

两者的特性对比矩阵（摘自[https://sematext.com/blog/jaeger-vs-zipkin-opentracing-distributed-tracers/](https://sematext.com/blog/jaeger-vs-zipkin-opentracing-distributed-tracers/)，截至May 23, 2018)：

|                                    | **JAEGER**                                                   | **ZIPKIN**                                                   |
| ---------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **OpenTracing compatibility**      | Yes                                                          | Yes                                                          |
| **OpenTracing-compatible clients** | [Python](https://github.com/uber/jaeger-client-python)<br>[Go](https://github.com/uber/jaeger-client-go)<br>[Node](https://github.com/uber/jaeger-client-node)<br>[Java](https://github.com/uber/jaeger-client-java)<br>[C++](https://github.com/jaegertracing/jaeger-client-cpp)<br>[C#](https://github.com/jaegertracing/jaeger-client-csharp)<br>[Ruby](https://github.com/salemove/jaeger-client-ruby) <br>`*`[PHP](https://github.com/jukylin/jaeger-php)<br>`*`[Rust](https://github.com/sile/rustracing_jaeger) | [Go](https://github.com/openzipkin/zipkin-go-opentracing)<br>[Java](https://github.com/openzipkin-contrib/brave-opentracing)<br>[Ruby](https://github.com/salemove/zipkin-ruby-opentracing)<br>`*`[C++](https://github.com/rnburn/zipkin-cpp-opentracing)<br>Python (work in [progress](https://github.com/openzipkin-attic/zipkin-python-opentracing/pull/1)) |
| **Storage support**                | In-memory<br>CassandraElasticsearch<br>ScyllaDB (work in [progress](https://github.com/uber/jaeger/pull/201)) | In-memory<br>MySQL<br>CassandraElasticsearch                 |
| **Sampling**                       | Dynamic sampling rate   (supports rate limiting and  probabilistic sampling strategies) | Fixed sampling rate (supports probabilistic sampling strategy) |
| **Span transport**                 | UDP<br>HTTP                                                  | HTTP<br>Kafka<br>Scribe<br>AMQP                              |
| **Docker ready**                   | Yes                                                          | Yes                                                          |

`*` non-official OpenTracing clients

从上面的特性矩阵来年，在兼容的客户端语言和采样策略上jaeger胜出，在支持的传输层技术上zipkin胜出，其它都是差不多的水平。

### 架构对比

两者都是 [Google Dapper](http://research.google.com/pubs/pub36356.html) 这篇pager的实现，因此原理及架构是差不多了，但两者的架构有一点点小差异。

**openzipkin的架构图**

![openzipkin的架构图](http://blog-images-1252238296.cosgz.myqcloud.com/architecture-1.png)



**jaeger架构图**

![jaeger架构图](http://blog-images-1252238296.cosgz.myqcloud.com/architecture.png)

从以上架构图可以看出，jaeger将jaeger-agent从业务应用中抽出，部署在宿主机或容器中，专门负责向collector异步上报调用链跟踪数据，这样做将业务应用与collector解耦了，同时也减少了业务应用的第三方依赖。因此从架构上来看，明显jaeger胜出了。

另外jaeger整体是用go语言编写的，在并发性能、对系统资源的消耗上也对基于java的openzipkin好不少。

### 社区活跃性对比

github上项目的关键指标如下：

```bash
$ curl 'https://api.github.com/repos/openzipkin/zipkin' 2>/dev/null | grep -E 'created_at|updated_at|stargazers_count|watchers_count|forks_count'
  "created_at": "2012-06-06T18:26:16Z",
  "updated_at": "2018-07-22T13:36:01Z",
  "stargazers_count": 9039,
  "watchers_count": 9039,
  "forks_count": 1500,

$ curl 'https://api.github.com/repos/jaegertracing/jaeger' 2>/dev/null | grep -E 'created_at|updated_at|stargazers_count|watchers_count|forks_count'
  "created_at": "2016-04-15T18:49:02Z",
  "updated_at": "2018-07-22T10:46:39Z",
  "stargazers_count": 5184,
  "watchers_count": 5184,
  "forks_count": 414,
```

两者最近都属于活跃开发中，值得注意的是jaeger比openzipkin晚诞生4年，但start及watch的数量已有后者的一半了，可谓发展迅猛。另外还有一点值得注意的是jaeger是[Cloud Native Computing Foundation](https://www.cncf.io/)的项目，因此云原生的项目都会支持它。

### 结论

综上所述，这里就愉快地选择jaeger了。

## Getting Started

为了便于研究，先把官方的[Getting started](https://jaegertracing.io/docs/getting-started/)跑起来。不过为了理解其架构，我这里就不用官方的`all-in-one`启动了，而是将各个组件逐个部署启动起来。另外为了后面能整合ES搜索方案，我这里的storage使用了elasticsearch，这个jaeger也是支持的。下面的部署过程就直接贴docker-compose文件了，比较简单。

`.env`

```bash
COMPOSE_PROJECT_NAME=jaeger_demo
MY_HOST_IP=${your_host_ip}
```

`docker-compose.yml`

```yaml
version: '3'

services:
  elasticsearch:
    image: elasticsearch
    command: -Enode.name=jaegerESNode
    restart: always
    volumes:
      - "esdata:/usr/share/elasticsearch/data"
    ports:
      - "9200:9200"

  jaeger-collector:
    image: jaegertracing/jaeger-collector
    restart: always
    environment:
      SPAN_STORAGE_TYPE: elasticsearch
      ES_SERVER_URLS: http://${MY_HOST_IP:-127.0.0.1}:9200
    ports:
      - "14267:14267"
      - "14268:14268"
      - "9411:9411"

  jaeger-query:
    image: jaegertracing/jaeger-query
    restart: always
    environment:
      SPAN_STORAGE_TYPE: elasticsearch
      ES_SERVER_URLS: http://${MY_HOST_IP:-127.0.0.1}:9200
    ports:
      - "16686:16686"

  jaeger-agent:
    image: jaegertracing/jaeger-agent
    restart: always
    command: --collector.host-port=${MY_HOST_IP:-127.0.0.1}:14267
    ports:
      - "5775:5775/udp"
      - "6831:6831/udp"
      - "6832:6832/udp"
      - "5778:5778/tcp"
      
  jaeger-spark-dependencies:
    image: jaegertracing/spark-dependencies
    restart: always
    environment:
      STORAGE: elasticsearch
      ES_NODES: http://${MY_HOST_IP:-127.0.0.1}:9200
      ES_NODES_WAN_ONLY: 'true'
      JAVA_OPTS: -Dspark.testing.memory=481859200

  example-hotrod:
    image: jaegertracing/example-hotrod
    restart: always
    command: all --jaeger-agent.host-port=${MY_HOST_IP:-127.0.0.1}:6831
    ports:
      - "8080-8083:8080-8083"

volumes:
  esdata:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: "${PWD}/esdata"
```

`docker-compose.yml`文件中配置的各个组件可按照jaeger的架构图部署在多台宿主机上，只要配置好正确的地址引用即可。

跑起来后访问`http://127.0.0.1:8080/`，点击不同的按钮，用以模拟不同的客户订购car。

![](http://blog-images-1252238296.cosgz.myqcloud.com/1%2AtLGZLrpEE8gz6RZEVJRCbA.png)

然后访问`http://127.0.0.1:16686/`，即可查询调用链信息。

![](http://blog-images-1252238296.cosgz.myqcloud.com/1%2AKXMjUpiQMMjXJjjK1GDAoA.png)

![](http://blog-images-1252238296.cosgz.myqcloud.com/1%2Aph6PiyKcEXv42UP1BXhZMA.png)

基本功能大概就是这样了，一些强悍的功能可以查看[这篇文章](https://medium.com/opentracing/take-opentracing-for-a-hotrod-ride-f6e3141f7941)。

## Trace Instrumentation写法

从jaeger的架构图中可以看到，微服务接入分布式调用追踪需要插入一些代码用于进行`Trace Instrumentation`。因为我们的项目大部分是go语言编写的，因此这里重点说一下go语言的Trace Instrumentation写法，其它语言应该类似。

### 初始化Tracer

根据相关的配置选项初始化Tracer，初始化方法可参考`https://github.com/jaegertracing/jaeger/blob/master/examples/hotrod/pkg/tracing/init.go`

```go
// Init creates a new instance of Jaeger tracer.
func Init(serviceName string, metricsFactory metrics.Factory, logger log.Factory, backendHostPort string) opentracing.Tracer {
	cfg := config.Configuration{
		Sampler: &config.SamplerConfig{
			Type:  "const",
			Param: 1,
		},
	}
	// TODO(ys) a quick hack to ensure random generators get different seeds, which are based on current time.
	time.Sleep(100 * time.Millisecond)
	jaegerLogger := jaegerLoggerAdapter{logger.Bg()}
	var sender jaeger.Transport
	if strings.HasPrefix(backendHostPort, "http://") {
		sender = transport.NewHTTPTransport(
			backendHostPort,
			transport.HTTPBatchSize(1),
		)
	} else {
		if s, err := jaeger.NewUDPTransport(backendHostPort, 0); err != nil {
			logger.Bg().Fatal("cannot initialize UDP sender", zap.Error(err))
		} else {
			sender = s
		}
	}
	tracer, _, err := cfg.New(
		serviceName,
		config.Reporter(jaeger.NewRemoteReporter(
			sender,
			jaeger.ReporterOptions.BufferFlushInterval(1*time.Second),
			jaeger.ReporterOptions.Logger(jaegerLogger),
		)),
		config.Logger(jaegerLogger),
		config.Metrics(metricsFactory),
		config.Observer(rpcmetrics.NewObserver(metricsFactory, rpcmetrics.DefaultNameNormalizer)),
	)
	if err != nil {
		logger.Bg().Fatal("cannot initialize Jaeger Tracer", zap.Error(err))
	}
	return tracer
}
```

### 嵌入代码至http.Handler

如果微服务是用HTTP提交的restful接口，则需要嵌入代码至http.Handler，可参考`https://github.com/jaegertracing/jaeger/blob/master/examples/hotrod/pkg/tracing/mux.go`，这里的主要处理逻辑在`https://github.com/opentracing-contrib/go-stdlib/blob/master/nethttp/server.go`。

```go
// Handle implements http.ServeMux#Handle
func (tm *TracedServeMux) Handle(pattern string, handler http.Handler) {
	middleware := nethttp.Middleware(
		tm.tracer,
		handler,
		nethttp.OperationNameFunc(func(r *http.Request) string {
			return "HTTP " + r.Method + " " + pattern
		}))
	tm.mux.Handle(pattern, middleware)
}
```

其实就是用nethttp包里的middleware将http.Handler包裹起来，可以猜测这个middleware的处理逻辑，如没有Trace的上下文信息，则创建一个全新的Trace，并将Trace的上下文信息放入请求处理上下文；如有Trace的上下文信息，则直接使用该Trace的上下文信息，并将Trace的上下文信息放入请求处理上下文。

### 嵌入代码至http.Client

如果微服务是用http.Client调用其它微服务的restful接口，则需要嵌入代码至http.Client，可参考`https://github.com/jaegertracing/jaeger/blob/master/examples/hotrod/pkg/tracing/http.go`，这里的主要处理逻辑在`https://github.com/opentracing-contrib/go-stdlib/blob/master/nethttp/client.go`。

```go
// HTTPClient wraps an http.Client with tracing instrumentation.
type HTTPClient struct {
	Tracer opentracing.Tracer
	Client *http.Client
}

// GetJSON executes HTTP GET against specified url and tried to parse
// the response into out object.
func (c *HTTPClient) GetJSON(ctx context.Context, endpoint string, url string, out interface{}) error {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	req = req.WithContext(ctx)
	req, ht := nethttp.TraceRequest(c.Tracer, req, nethttp.OperationName("HTTP GET: "+endpoint))
	defer ht.Finish()

	res, err := c.Client.Do(req)
	if err != nil {
		return err
	}

	defer res.Body.Close()

	if res.StatusCode >= 400 {
		body, err := ioutil.ReadAll(res.Body)
		if err != nil {
			return err
		}
		return errors.New(string(body))
	}
	decoder := json.NewDecoder(res.Body)
	return decoder.Decode(out)
}
```

其实就是用`nethttp.TraceRequest`方法来跟踪请求，同时将当前Trace的上下文信息传递给下一个微服务。

### 给Span添加自定义tag

可以给Span添加自定义tag，可参考`https://github.com/jaegertracing/jaeger/blob/master/examples/hotrod/services/customer/database.go`

```go
// simulate opentracing instrumentation of an SQL query
	if span := opentracing.SpanFromContext(ctx); span != nil {
		span := d.tracer.StartSpan("SQL SELECT", opentracing.ChildOf(span.Context()))
		tags.SpanKindRPCClient.Set(span)
		tags.PeerService.Set(span, "mysql")
		span.SetTag("sql.query", "SELECT * FROM customer WHERE customer_id="+customerID)
		defer span.Finish()
		ctx = opentracing.ContextWithSpan(ctx, span)
	}
```

这样在jaeger的UI上展开这个Span时，即可看到一些详细的信息。

![image-20180722234642553](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180722234642553.png)

### 给Span添加相关的log

可以给Span添加自定义log，可参考`https://github.com/jaegertracing/jaeger/blob/master/examples/hotrod/pkg/log/spanlogger.go`

```go
type spanLogger struct {
	logger *zap.Logger
	span   opentracing.Span
}

func (sl spanLogger) Info(msg string, fields ...zapcore.Field) {
	sl.logToSpan("info", msg, fields...)
	sl.logger.Info(msg, fields...)
}

func (sl spanLogger) Error(msg string, fields ...zapcore.Field) {
	sl.logToSpan("error", msg, fields...)
	sl.logger.Error(msg, fields...)
}

func (sl spanLogger) Fatal(msg string, fields ...zapcore.Field) {
	sl.logToSpan("fatal", msg, fields...)
	tag.Error.Set(sl.span, true)
	sl.logger.Fatal(msg, fields...)
}

// With creates a child logger, and optionally adds some context fields to that logger.
func (sl spanLogger) With(fields ...zapcore.Field) Logger {
	return spanLogger{logger: sl.logger.With(fields...), span: sl.span}
}

func (sl spanLogger) logToSpan(level string, msg string, fields ...zapcore.Field) {
	// TODO rather than always converting the fields, we could wrap them into a lazy logger
	fa := fieldAdapter(make([]log.Field, 0, 2+len(fields)))
	fa = append(fa, log.String("event", msg))
	fa = append(fa, log.String("level", level))
	for _, field := range fields {
		field.AddTo(&fa)
	}
	sl.span.LogFields(fa...)
}
```

在打日志的地址使用下面的语句

```go
d.logger.For(ctx).Info("Loading customer", zap.String("customer_id", customerID))
```

这样在jaeger的UI里展开Span就可看到该Span相关的日志。

![image-20180722235354858](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180722235354858.png)

### 其它接口调用的Trace Instrumentation

除了常规restful接口，其它类型如何做Trace Instrumentation可参考[opentracing-contrib](https://github.com/opentracing-contrib?utf8=%E2%9C%93&q=&type=&language=go)。

## jaeger的源码解析

简单浏览下jaeger的源码，整体逻辑还是比较清晰的，通过阅读它的源码还是学到了不少coding技巧的。在网上还找到一位小哥写的jaeger源码解析，写得还挺详细的，这里就不赘述了，直接参考[jaeger源码解析](https://github.com/jukylin/blog/)就可以了。

THE END

## 参考

1. https://medium.com/opentracing/take-opentracing-for-a-hotrod-ride-f6e3141f7941
2. https://www.jaegertracing.io/
3. https://zipkin.io/
4. http://research.google.com/pubs/pub36356.html
5. https://sematext.com/blog/jaeger-vs-zipkin-opentracing-distributed-tracers/
6. http://opentracing.io/documentation/