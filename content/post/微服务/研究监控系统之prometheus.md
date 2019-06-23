---
title: 研究监控系统之prometheus
tags:
  - golang
  - prometheus
categories:
  - 微服务
date: 2018-08-05 12:30:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20180805
---

这周的工作是要为已有的系统搭建一套监控系统，主要监控以下指标：

1. 宿主机的CPU、内存使用情况
2. 自身系统的各进程占用CPU、内存使用情况
3. 自身系统本身的重要业务指标

以前用过[nagios](https://www.nagios.org/)和[zabbix](https://www.zabbix.com/)，nagios用起来太过原始，配置文件维护得很累，监控的图表也比较难看；zabbix的主要开发语言是C和PHP，要暴露一些自定义的监控指标较困难。网上一些云原生的项目都是用`prometheus+grafana`方案的，刚好花时间研究一下这个。

以下的概述摘自 `https://github.com/1046102779/prometheus/blob/master/introduction/overview.md`

## 什么是prometheus？

[Prometheus](https://github.com/prometheus)是一个开源监控系统，它前身是SoundCloud的警告工具包。从2012年开始，许多公司和组织开始使用Prometheus。该项目的开发人员和用户社区非常活跃，越来越多的开发人员和用户参与到该项目中。目前它是一个独立的开源项目，且不依赖与任何公司。 为了强调这点和明确该项目治理结构，Prometheus在2016年继Kurberntes之后，加入了Cloud Native Computing Foundation。

### 特征

Prometheus的主要特征有：

1. 多维度数据模型
2. 灵活的查询语言
3. 不依赖分布式存储，单个服务器节点是自主的
4. 以HTTP方式，通过pull模型拉去时间序列数据
5. 也通过中间网关支持push模型
6. 通过服务发现或者静态配置，来发现目标服务对象
7. 支持多种多样的图表和界面展示，grafana也支持它

### 组件

Prometheus生态包括了很多组件，它们中的一些是可选的：

1. 主服务Prometheus Server负责抓取和存储时间序列数据
2. 客户库负责检测应用程序代码
3. 支持短生命周期的PUSH网关
4. 基于Rails/SQL仪表盘构建器的GUI
5. 多种导出工具，可以支持Prometheus存储数据转化为HAProxy、StatsD、Graphite等工具所需要的数据存储格式
6. 警告管理器
7. 命令行查询工具
8. 其他各种支撑工具

多数Prometheus组件是Go语言写的，这使得这些组件很容易编译和部署。

### 架构

下面这张图说明了Prometheus的整体架构，以及生态中的一些组件作用: ![Prometheus Arhitecture](/images/20180805/68747470733a2f2f70726f6d6574686575732e696f2f6173736574732f6172636869746563747572652e737667.svg)

Prometheus服务，可以直接通过目标拉取数据，或者间接地通过中间网关拉取数据。它在本地存储抓取的所有数据，并通过一定规则进行清理和整理数据，并把得到的结果存储到新的时间序列中，PromQL和其他API可视化地展示收集的数据

### 适用场景

Prometheus在记录纯数字时间序列方面表现非常好。它既适用于面向服务器等硬件指标的监控，也适用于高动态的面向服务架构的监控。对于现在流行的微服务，Prometheus的多维度数据收集和数据筛选查询语言也是非常的强大。

Prometheus是为服务的可靠性而设计的，当服务出现故障时，它可以使你快速定位和诊断问题。它的搭建过程对硬件和服务没有很强的依赖关系。

### 不适用场景

Prometheus，它的价值在于可靠性，甚至在很恶劣的环境下，你都可以随时访问它和查看系统服务各种指标的统计信息。 如果你对统计数据需要100%的精确，它并不适用，例如：它不适用于实时计费系统

## prometheus的概念

prometheus里的概念比较少，重要的只有以下几个。

### Jobs和Instances(任务和实例)

就Prometheus而言，pull拉取采样点的端点服务称之为instance。多个这样pull拉取采样点的instance, 则构成了一个job。

例如, 一个被称作api-server的任务有四个相同的实例。

```
job: api-server
   instance 1：1.2.3.4:5670
   instance 2：1.2.3.4:5671
   instance 3：5.6.7.8:5670
   instance 4：5.6.7.8:5671
```

#### 自动化生成的标签和时间序列

当Prometheus拉取一个目标, 会自动地把两个标签添加到度量名称的标签列表中，分别是：

job: 目标所属的配置任务名称api-server。
instance: 采样点所在服务: host:port
如果以上两个标签二者之一存在于采样点中，这个取决于honor_labels配置选项。

对于每个采样点所在服务instance，Prometheus都会存储以下的度量指标采样点：

* up{job="[job-name]", instance="instance-id"}: up值=1，表示采样点所在服务健康; 否则，网络不通, 或者服务挂掉了
* scrape_duration_seconds{job="[job-name]", instance="[instance-id]"}: 尝试获取目前采样点的时间开销
* scrape_samples_scraped{job="[job-name]", instance="[instance-id]"}: 这个采样点目标暴露的样本点数量

**up度量指标对服务健康的监控是非常有用的**。

### 数据模型

Prometheus从根本上存储的所有数据都是[时间序列](http://en.wikipedia.org/wiki/Time_series): 具有时间戳的数据流只属于单个度量指标和该度量指标下的多个标签维度。除了存储时间序列数据外，Prometheus也可以利用查询表达式存储5分钟的返回结果中的时间序列数据

#### metrics和labels(度量指标名称和标签)

每一个时间序列数据由metric度量指标名称和它的标签labels键值对集合唯一确定。

这个metric度量指标名称指定监控目标系统的测量特征（如：`http_requests_total`- 接收http请求的总计数）. metric度量指标命名ASCII字母、数字、下划线和冒号，他必须配正则表达式`[a-zA-Z_:][a-zA-Z0-9_:]*`。

标签开启了Prometheus的多维数据模型：对于相同的度量名称，通过不同标签列表的结合, 会形成特定的度量维度实例。(例如：所有包含度量名称为`/api/tracks`的http请求，打上`method=POST`的标签，则形成了具体的http请求)。这个查询语言在这些度量和标签列表的基础上进行过滤和聚合。改变任何度量上的任何标签值，则会形成新的时间序列图

标签label名称可以包含ASCII字母、数字和下划线。它们必须匹配正则表达式`[a-zA-Z_][a-zA-Z0-9_]*`。带有`_`下划线的标签名称被保留内部使用。

标签labels值包含任意的Unicode码。

具体详见[metrics和labels命名最佳实践](https://prometheus.io/docs/practices/naming/)。

#### 有序的采样值

有序的采样值形成了实际的时间序列数据列表。每个采样值包括：

- 一个64位的浮点值
- 一个精确到毫秒级的时间戳 一个样本数据集是针对一个指定的时间序列在一定时间范围的数据收集。这个时间序列是由<metric_name>{<label_name>=<label_value>, ...}

''小结：指定度量名称和度量指标下的相关标签值，则确定了所关心的目标数据，随着时间推移形成一个个点，在图表上实时绘制动态变化的线条''

#### Notation(符号)

表示一个度量指标和一组键值对标签，需要使用以下符号：

> [metric name]{[label name]=[label value], ...}

例如，度量指标名称是`api_http_requests_total`， 标签为`method="POST"`, `handler="/messages"` 的示例如下所示：

> api_http_requests_total{method="POST", handler="/messages"}

这些命名和OpenTSDB使用方法是一样的

### metrics类型

------

Prometheus客户库提供了四个核心的metrics类型。这四种类型目前仅在客户库和wire协议中区分。Prometheus服务还没有充分利用这些类型。不久的将来就会发生改变。

#### Counter(计数器)

*counter* 是一个累计度量指标，它是一个只能递增的数值。计数器主要用于统计服务的请求数、任务完成数和错误出现的次数等等。计数器是一个递增的值。反例：统计goroutines的数量。

#### Gauge(测量器)

*gauge*是一个度量指标，它表示一个既可以递增, 又可以递减的值。

测量器主要测量类似于温度、当前内存使用量等，也可以统计当前服务运行随时增加或者减少的Goroutines数量

#### Histogram(柱状图)

*histogram*，是柱状图，在Prometheus系统中的查询语言中，有三种作用：

1. 对每个采样点进行统计，打到各个分类值中(bucket)
2. 对每个采样点值累计和(sum)
3. 对采样点的次数累计和(count)

度量指标名称: `[basename]`的柱状图, 上面三类的作用度量指标名称

- [basename]_bucket{le="上边界"}, 这个值为小于等于上边界的所有采样点数量
- [basename]_sum
- [basename]_count

小结：所以如果定义一个度量类型为Histogram，则Prometheus系统会自动生成三个对应的指标

使用[histogram_quantile()](https://prometheus.io/docs/querying/functions/#histogram_quantile)函数, 计算直方图或者是直方图聚合计算的分位数阈值。 一个直方图计算[Apdex值](http://en.wikipedia.org/wiki/Apdex)也是合适的, 当在buckets上操作时，记住直方图是累计的。

#### [Summary]总结

类似*histogram*柱状图，*summary*是采样点分位图统计，(通常的使用场景：请求持续时间和响应大小)。 它也有三种作用：

1. 对于每个采样点进行统计，并形成分位图。（如：正态分布一样，统计低于60分不及格的同学比例，统计低于80分的同学比例，统计低于95分的同学比例）
2. 统计班上所有同学的总成绩(sum)
3. 统计班上同学的考试总人数(count)

带有度量指标的`[basename]`的`summary` 在抓取时间序列数据展示。

- 观察时间的φ-quantiles (0 ≤ φ ≤ 1), 显示为`[basename]{分位数="[φ]"}`
- `[basename]_sum`， 是指所有观察值的总和
- `[basename]_count`, 是指已观察到的事件计数值

**summary的最简单的理解, DEMO*

详见[histogram和summaries](https://prometheus.io/docs/practices/histograms)

上面的几个概念单纯讲还是比较难讲清楚，下面还是安装部署好prometheus，结合实例具体说一下。

## 安装部署prometheus

安装部署prometheus也是极简单的，我这里用`docker-compose`部署，`docker-compose.yml`文件内容如下：

```yaml
version: '3'

services:
  prometheus:
    image: prom/prometheus
    ports:
      - 9090:9090/tcp
    user: root
    volumes:
      - ${PWD}/prometheus/data:/prometheus
      - ${PWD}/prometheus/conf/prometheus.yml:/etc/prometheus/prometheus.yml
  
  grafana:
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    image: grafana/grafana
    volumes:
      - ${PWD}/grafana/data:/var/lib/grafana
    ports:
      - 3000:3000/tcp
    user: grafana
```

上述描述文件将启动两个容器，prometheus和grafana，两个服务均使用本机的配置文件，使用本机的目录作为数据目录。

prometheus本地的配置文件直接用`( docker run --rm -ti --entrypoint '' prom/prometheus cat/etc/prometheus/prometheus.yml ) > ./prometheus/conf/prometheus.yml `就得到了。

然后用`docker-compose up -d`命令即可启动prometheus和grafana。可直接用浏览器访问，prometheus的访问地址是`http://127.0.0.1:9090`， grafana的访问地址是`http://127.0.0.1:3000`。

## 解读prometheus的概念

我们打开prometheus的配置文件，看一下内容：

```yaml
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.

alerting:
  alertmanagers:
  - static_configs:
    - targets: []

rule_files: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
```

这里可以看到配置了一个名叫`prometheus`的job：

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
```

而这个job的服务端点是静态配置的，目前只有`localhost:9090`这一个。以上配置说明prometheus将会每15s从prometheus这个job定义的服务端点`localhost:9090`拉取监控指标数据，并将之存入TSDB。当然prometheus还支持其它的服务端点定义方式，参见[配置](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)里一堆以`_sd_config`结尾的配置。例如可配置基于consul的服务端点发现：

```
  - job_name: 'consul_srvs'
    consul_sd_configs:
      server: '127.0.0.1:8500'
      services:
        - 'serviceA'
        - 'serviceB'
```

我们用浏览器访问`http://127.0.0.1:9090/metrics`，即可看到一个instance向外暴露的监控指标。除了注释外，其它每一行都是一个监控指标项，大部分指标形如：

```
go_info{version="go1.10.3"} 1
```

这里`go_info`即为度量指标名称，`version`为这个度量指标的标签，`go1.10.3`为这个度量指标version标签的值，`1`为这个度量指标当前采样的值，一个度量指标的标签可以有0个或多个标签。这就是上面说到的监控指标数据模型。

可以看到有些度量指标的形式如下：

```
go_memstats_frees_total 135196
```

按prometheus官方建议的规范，以`_total`为后缀的度量指标一般类型是counter计数器类型。

有些度量指标的形式如下：

```
go_memstats_gc_sys_bytes 913408
```

这种度量指标一般类型是gauge测量器类型。

有些度量指标的形式如下：

```
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="100"} 0
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="1000"} 0
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="10000"} 46
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="100000"} 46
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="1e+06"} 46
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="1e+07"} 46
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="1e+08"} 46
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="1e+09"} 46
prometheus_http_response_size_bytes_bucket{handler="/metrics",le="+Inf"} 46
prometheus_http_response_size_bytes_sum{handler="/metrics"} 234233
prometheus_http_response_size_bytes_count{handler="/metrics"} 46
```

这种就是histogram柱状图类型。

还有的形式如下：

```
go_gc_duration_seconds{quantile="0"} 7.3318e-05
go_gc_duration_seconds{quantile="0.25"} 0.000118693
go_gc_duration_seconds{quantile="0.5"} 0.000236845
go_gc_duration_seconds{quantile="0.75"} 0.000337872
go_gc_duration_seconds{quantile="1"} 0.000707002
go_gc_duration_seconds_sum 0.003731953
go_gc_duration_seconds_count 14
```

这种就是summary总结类型。

这就是上面说到的监控指标的数据类型。

## 监控指标上报

prometheus已经部署好了，接下来就要埋点上报监控指标数据了。

### 各类exporter

在prometheus的世界里70%的场景并不需要专门写埋点逻辑代码，因为已经有现成的各类exporter了，只要找到合适的exporter，启动exporter就直接暴露出一个符合prometheus规范的服务端点了。

exporter列表参见[这里](https://prometheus.io/docs/instrumenting/exporters/)，另外[官方git仓库](https://github.com/prometheus)里也有一些exporter。

举个栗子，在某个宿主机上运行[node_exporter](https://github.com/prometheus/node_exporter)后，用浏览器访问`http://${host_ip}:9100/metrics`即可看到node_exporter暴露出的这个宿主机各类监控指标数据，然后在prometheus的配置文件里加入以下一段：

```yaml
scrape_configs:
  ......
  - job_name: 'node_monitor_demo'
    static_configs:
    - targets: ['${host_ip}:9100']
```

然后在prometheus的web管理控制台里就可以查询到相应的监控指标了。在`http://127.0.0.1:9090/graph`界面里输入`go_memstats_alloc_bytes{instance="${host_ip}:9100"}`点击`Execute`按钮即可。

### 编写监控指标上报代码

如果不幸，你的监控指标很特殊，需要自己写埋点上报逻辑代码，也是比较简单的。已经有[各个语言的Client Libraries](https://prometheus.io/docs/instrumenting/clientlibs/)了，照着示例写就可以了。

下面举一个go语言的示例。

首先创建一个http服务

```go
import (
	"flag"
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var addr = flag.String("listen-address", ":8080", "The address to listen on for HTTP requests.")

func main() {
	flag.Parse()
	http.Handle("/metrics", promhttp.Handler())
	log.Fatal(http.ListenAndServe(*addr, nil))
}
```

然后初始化metric对象（这里采用[go-metrics](https://github.com/armon/go-metrics)库，方便不少）

```go
import (
    prometheussink "github.com/armon/go-metrics/prometheus"
    "github.com/armon/go-metrics"
)

sink, _ := prometheussink.NewPrometheusSink()
metrics.NewGlobal(metrics.DefaultConfig("service-name"), sink)
```

最后在需要埋点的地方调用metrics的相应方法就可以了

```go
// Run some code
metrics.SetGauge([]string{"foo"}, 42)
metrics.EmitKey([]string{"bar"}, 30)

metrics.IncrCounter([]string{"baz"}, 42)
metrics.IncrCounter([]string{"baz"}, 1)
metrics.IncrCounter([]string{"baz"}, 80)

metrics.AddSample([]string{"method", "wow"}, 42)
metrics.AddSample([]string{"method", "wow"}, 100)
metrics.AddSample([]string{"method", "wow"}, 22)
```

## 查询监控指标数据

Prometheus提供一个函数式的表达式语言，可以使用户实时地查找和聚合时间序列数据。表达式计算结果可以在图表中展示，也可以在Prometheus表达式浏览器中以表格形式展示，或者作为数据源, 以HTTP API的方式提供给外部系统使用。prometheus的查询表达式语言也比较简单，[官方文档](https://prometheus.io/docs/prometheus/latest/querying/)大概花了两三个网页就讲完了，我的感觉是看看官方文档，再结合官方给出的[示例](https://prometheus.io/docs/prometheus/latest/querying/examples/)，到prometheus的web管理控制台做做实验就掌握得差不多了。

## 图表里查看监控状态

监控数据采集上来了，当然不是只在prometheus的管理控制台里查询，业务上肯定需要在图表中展现监控状态，这里采用[grafana](http://grafana.org/)完成这个工作，具体整合步骤参考[官方文档](https://prometheus.io/docs/visualization/grafana/)即可。在grafana里的图表panel可share出去，集成到其它业务系统的web界面里。

## 部署优化

### 远端存储

prometheus默认是将监控数据保存在本地磁盘中的，当然在分布式架构环境下，这样是不太可取的。不过它支持远端存储，可与远端存储系统集成。

Prometheus integrates with remote storage systems in two ways:

- Prometheus can write samples that it ingests to a remote URL in a standardized format.
- Prometheus can read (back) sample data from a remote URL in a standardized format.

![Remote read and write architecture](/images/20180805/remote_integrations.png)

目前支持的远端存储系统如下：

The [remote write](https://prometheus.io/docs/operating/configuration/#%3Cremote_write%3E) and [remote read](https://prometheus.io/docs/operating/configuration/#%3Cremote_read%3E) features of Prometheus allow transparently sending and receiving samples. This is primarily intended for long term storage. It is recommended that you perform careful evaluation of any solution in this space to confirm it can handle your data volumes.

- [AppOptics](https://github.com/solarwinds/prometheus2appoptics): write
- [Chronix](https://github.com/ChronixDB/chronix.ingester): write
- [Cortex](https://github.com/weaveworks/cortex): read and write
- [CrateDB](https://github.com/crate/crate_adapter): read and write
- [Elasticsearch](https://github.com/infonova/prometheusbeat): write
- [Gnocchi](https://gnocchi.xyz/prometheus.html): write
- [Graphite](https://github.com/prometheus/prometheus/tree/master/documentation/examples/remote_storage/remote_storage_adapter): write
- [InfluxDB](https://docs.influxdata.com/influxdb/v1.4/supported_protocols/prometheus): read and write
- [IRONdb](https://github.com/circonus-labs/irondb-prometheus-adapter): read and write
- [M3DB](https://m3db.github.io/m3/integrations/prometheus): read and write
- [OpenTSDB](https://github.com/prometheus/prometheus/tree/master/documentation/examples/remote_storage/remote_storage_adapter): write
- [PostgreSQL/TimescaleDB](https://github.com/timescale/prometheus-postgresql-adapter): read and write
- [SignalFx](https://github.com/signalfx/metricproxy#prometheus): write

### 联邦模式

如果prometheus仅能够中心化地进行数据采集存储、分析，不支持集群模式，带来的性能问题显而易见。Prometheus给出了一种联邦的部署方式，就是Prometheus server可以从其他的Prometheus server采集数据，实施步骤直接参考[官方文档](https://prometheus.io/docs/prometheus/latest/federation/)。

## 监控告警

一个监控系统必须要有告警，否则产生不了太大的价值，prometheus的监控告警也是比较成熟的，不过本次没有深入使用，这里就不细谈了，直接参考[官方文档](https://prometheus.io/docs/alerting/overview/)就可以了，写得还算详细。

## 最佳实践

官方还给出一些[最佳实践](https://prometheus.io/docs/practices/naming/)，可以简单浏览一下。主要是一些指标命名建议、监控指标类型的选择、告警策略、采用Recording rules提前生成监控指标、何时部署Pushgateway。

THE END

## 参考

1. https://prometheus.io/docs
2. https://mp.weixin.qq.com/s/2m6x7MoNdHlzRCSenESvnw
3. https://github.com/1046102779/prometheus
4. https://github.com/armon/go-metrics
5. https://github.com/prometheus/node_exporter