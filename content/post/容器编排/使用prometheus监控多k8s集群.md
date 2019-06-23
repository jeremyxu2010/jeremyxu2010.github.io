---
title: 使用prometheus监控多k8s集群
tags:
  - prometheus
  - kubernetes
categories:
  - 容器编排
date: 2018-11-18 15:50:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20181118
---

最近在做k8s相关的开发工作，涉及不少k8s的相关知识，这里记录下。

## 问题引出

遇到一个需求，要使用prometheus监控多个k8s集群。

调研发现[prometheus](https://prometheus.io)配合[node_exporter](https://github.com/prometheus/node_exporter)、[kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)可以很方便地采集单个集群的监控指标。因此最初的构想是在每套k8s集群里部署prometheus，由它采集该集群的监控指标，再运用prometheus的联邦模式将多个prometheus中的监控数据聚合采集到一个中心prometheus里来，参考模型为[Hierarchical federation](https://prometheus.io/docs/prometheus/latest/federation/#hierarchical-federation)。

但甲方觉得上述方案中每个k8s集群都要部署prometheus，增加了每套k8s集群的资源开销，希望全局只部署一套prometheus，由它统一采集多个k8s集群的监控指标。尽管个人不太认可这种方案，中心prometheus今后很有可能成为性能瓶颈，但甲方要求的总得尽力满足，下面开始研究如何用一个prometheus采集多个k8s集群的监控指标。

## prometheus采集当前k8s监控数据

首先分析prometheus是如何采集单个k8s集群的监控指标。在k8s集群里用helm部署一套prometheus还是很简单的，命令如下：

```bash
# 假设就部署在default命名空间
helm install --name prometheus --namespace default stable/prometheus
```

部署完毕之后，由于默认并没有创造任何ingress资源对象，创建的service的类型也仅仅是ClusterIP，所以从集群外部是没法访问到它的，不过可以简单地将端口映射出来，如下：

```bash
kubectl -n default port-forward service/prometheus-server 30080:80
```

这里使用了`kubectl port-forward`命令，详细使用方法参考[这里](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#port-forward)。

然后用浏览器访问`http://127.0.0.1:30080/graph`，就可访问到prometheus的WebConsole了。

访问`http://127.0.0.1:30080/config`可以看到当前prometheus的配置，其中抓取当前k8s集群监控指标的配置如下：

```yaml
scrape_configs:
# 抓取当前prometheus的监控指标
- job_name: prometheus
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
  static_configs:
  - targets:
    - localhost:9090
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中endpoints列表，匹配到apiserver的endpoint，从该endpoint抓取apiserver的监控指标
- job_name: kubernetes-apiservers
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  kubernetes_sd_configs:
  - role: endpoints
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    insecure_skip_verify: true
  relabel_configs:
  - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
    separator: ;
    regex: default;kubernetes;https
    replacement: $1
    action: keep
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中node列表，从node列表中每个node抓取node的监控指标(kubelet通过/metrics接口将node的监控指标export出来了)
- job_name: kubernetes-nodes
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  kubernetes_sd_configs:
  - role: node
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    insecure_skip_verify: true
  relabel_configs:
  - separator: ;
    regex: __meta_kubernetes_node_label_(.+)
    replacement: $1
    action: labelmap
  - separator: ;
    regex: (.*)
    target_label: __address__
    replacement: kubernetes.default.svc:443
    action: replace
  - source_labels: [__meta_kubernetes_node_name]
    separator: ;
    regex: (.+)
    target_label: __metrics_path__
    replacement: /api/v1/nodes/${1}/proxy/metrics
    action: replace
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中node列表，从node列表中每个node抓取cadvisor的监控指标(kubelet通过/metrics/cadvisor接口将cadvisor的监控指标export出来了)
- job_name: kubernetes-nodes-cadvisor
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  kubernetes_sd_configs:
  - role: node
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    insecure_skip_verify: true
  relabel_configs:
  - separator: ;
    regex: __meta_kubernetes_node_label_(.+)
    replacement: $1
    action: labelmap
  - separator: ;
    regex: (.*)
    target_label: __address__
    replacement: kubernetes.default.svc:443
    action: replace
  - source_labels: [__meta_kubernetes_node_name]
    separator: ;
    regex: (.+)
    target_label: __metrics_path__
    replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
    action: replace
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中endpoints列表，匹配到打了prometheus_io_scrape: true annotation的endpoint，从匹配到的endpoint列表中每个endpoint抓取该endpoint暴露的监控指标
- job_name: kubernetes-service-endpoints
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
  kubernetes_sd_configs:
  - role: endpoints
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
    separator: ;
    regex: "true"
    replacement: $1
    action: keep
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
    separator: ;
    regex: (https?)
    target_label: __scheme__
    replacement: $1
    action: replace
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
    separator: ;
    regex: (.+)
    target_label: __metrics_path__
    replacement: $1
    action: replace
  - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
    separator: ;
    regex: ([^:]+)(?::\d+)?;(\d+)
    target_label: __address__
    replacement: $1:$2
    action: replace
  - separator: ;
    regex: __meta_kubernetes_service_label_(.+)
    replacement: $1
    action: labelmap
  - source_labels: [__meta_kubernetes_namespace]
    separator: ;
    regex: (.*)
    target_label: kubernetes_namespace
    replacement: $1
    action: replace
  - source_labels: [__meta_kubernetes_service_name]
    separator: ;
    regex: (.*)
    target_label: kubernetes_name
    replacement: $1
    action: replace
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中service列表，匹配到打了prometheus_io_scrape: pushgateway annotation的service，从匹配到的service列表中每个service抓取该service暴露的监控指标
- job_name: prometheus-pushgateway
  honor_labels: true
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
  kubernetes_sd_configs:
  - role: service
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
    separator: ;
    regex: pushgateway
    replacement: $1
    action: keep
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中service列表，匹配到打了prometheus_io_scrape: true annotation的service，从匹配到的service列表中每个service抓取该service暴露的监控指标(这里通过blackbox这个服务来抓取，需要在prometheus所在的namespace部署blackbox服务)
- job_name: kubernetes-services
  params:
    module:
    - http_2xx
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /probe
  scheme: http
  kubernetes_sd_configs:
  - role: service
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
    separator: ;
    regex: "true"
    replacement: $1
    action: keep
  - source_labels: [__address__]
    separator: ;
    regex: (.*)
    target_label: __param_target
    replacement: $1
    action: replace
  - separator: ;
    regex: (.*)
    target_label: __address__
    replacement: blackbox
    action: replace
  - source_labels: [__param_target]
    separator: ;
    regex: (.*)
    target_label: instance
    replacement: $1
    action: replace
  - separator: ;
    regex: __meta_kubernetes_service_label_(.+)
    replacement: $1
    action: labelmap
  - source_labels: [__meta_kubernetes_namespace]
    separator: ;
    regex: (.*)
    target_label: kubernetes_namespace
    replacement: $1
    action: replace
  - source_labels: [__meta_kubernetes_service_name]
    separator: ;
    regex: (.*)
    target_label: kubernetes_name
    replacement: $1
    action: replace
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中pod列表，匹配到打了prometheus_io_scrape: true annotation的pod，从匹配到的pod列表中每个pod抓取该pod暴露的监控指标
- job_name: kubernetes-pods
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    separator: ;
    regex: "true"
    replacement: $1
    action: keep
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    separator: ;
    regex: (.+)
    target_label: __metrics_path__
    replacement: $1
    action: replace
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
    separator: ;
    regex: ([^:]+)(?::\d+)?;(\d+)
    target_label: __address__
    replacement: $1:$2
    action: replace
  - separator: ;
    regex: __meta_kubernetes_pod_label_(.+)
    replacement: $1
    action: labelmap
  - source_labels: [__meta_kubernetes_namespace]
    separator: ;
    regex: (.*)
    target_label: kubernetes_namespace
    replacement: $1
    action: replace
  - source_labels: [__meta_kubernetes_pod_name]
    separator: ;
    regex: (.*)
    target_label: kubernetes_pod_name
    replacement: $1
    action: replace
```

这段配置好复杂，最开始看的时候也是晕晕的，不过慢慢研究终于还是看懂意思了。这里选取其中一小段详细解释一下：

```yaml
# 通过kubernetes_sd_configs发现机制，通过apiserver的接口列出当前k8s集群中endpoints列表，匹配到打了prometheus_io_scrape: true annotation的endpoint，从匹配到的endpoint列表中每个endpoint抓取该endpoint暴露的监控指标
- job_name: kubernetes-service-endpoints
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
  kubernetes_sd_configs:
  - role: endpoints
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
    separator: ;
    regex: "true"
    replacement: $1
    action: keep
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
    separator: ;
    regex: (https?)
    target_label: __scheme__
    replacement: $1
    action: replace
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
    separator: ;
    regex: (.+)
    target_label: __metrics_path__
    replacement: $1
    action: replace
  - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
    separator: ;
    regex: ([^:]+)(?::\d+)?;(\d+)
    target_label: __address__
    replacement: $1:$2
    action: replace
  - separator: ;
    regex: __meta_kubernetes_service_label_(.+)
    replacement: $1
    action: labelmap
  - source_labels: [__meta_kubernetes_namespace]
    separator: ;
    regex: (.*)
    target_label: kubernetes_namespace
    replacement: $1
    action: replace
  - source_labels: [__meta_kubernetes_service_name]
    separator: ;
    regex: (.*)
    target_label: kubernetes_name
    replacement: $1
    action: replace
```

首先是一小段prometheus的抓取配置，官方解释在[这里](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#%3Cscrape_config%3E)，这个比较简单，就不具体解释了

```yaml
- job_name: kubernetes-service-endpoints
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: http
```

然后说明是用k8s的发现机制去发现抓取地址的：

```yaml
  kubernetes_sd_configs:
  - role: endpoints
```

prometheus里k8s的发现机制配置见[这里](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#%3Ckubernetes_sd_config%3E)，注意这里没填`api_server`属性，因此用了默认值`kubernetes.default.svc`。

然后是一段relabel_configs配置，其作用主要是用于匹配最终要抓取的endpoint，构造抓取的地址，甚至给最终的时序指标加上一些label。这里以apiserver发现的node_exporter endpoint信息为例，在没有relabel之前，其endpoint信息如下：

```
__address__="192.168.65.3:9100"
__meta_kubernetes_endpoint_address_target_kind="Pod"
__meta_kubernetes_endpoint_address_target_name="prometheus-node-exporter-89tcq"
__meta_kubernetes_endpoint_port_name="metrics"
__meta_kubernetes_endpoint_port_protocol="TCP"
__meta_kubernetes_endpoint_ready="true"
__meta_kubernetes_endpoints_name="prometheus-node-exporter"
__meta_kubernetes_namespace="default"
__meta_kubernetes_pod_container_name="prometheus-node-exporter"
__meta_kubernetes_pod_container_port_name="metrics"
__meta_kubernetes_pod_container_port_number="9100"
__meta_kubernetes_pod_container_port_protocol="TCP"
__meta_kubernetes_pod_controller_kind="DaemonSet"
__meta_kubernetes_pod_controller_name="prometheus-node-exporter"
__meta_kubernetes_pod_host_ip="192.168.65.3"
__meta_kubernetes_pod_ip="192.168.65.3"
__meta_kubernetes_pod_label_app="prometheus"
__meta_kubernetes_pod_label_component="node-exporter"
__meta_kubernetes_pod_label_controller_revision_hash="1203132889"
__meta_kubernetes_pod_label_pod_template_generation="1"
__meta_kubernetes_pod_label_release="prometheus"
__meta_kubernetes_pod_name="prometheus-node-exporter-89tcq"
__meta_kubernetes_pod_node_name="docker-for-desktop"
__meta_kubernetes_pod_ready="true"
__meta_kubernetes_pod_uid="62b53ba7-eae3-11e8-b0a6-025000000001"
__meta_kubernetes_service_annotation_prometheus_io_scrape="true"
__meta_kubernetes_service_label_app="prometheus"
__meta_kubernetes_service_label_chart="prometheus-7.4.1"
__meta_kubernetes_service_label_component="node-exporter"
__meta_kubernetes_service_label_heritage="Tiller"
__meta_kubernetes_service_label_release="prometheus"
__meta_kubernetes_service_name="prometheus-node-exporter"
__metrics_path__="/metrics"
__scheme__="http"
job="kubernetes-service-endpoints"
```

经过下面的relabel规则后：

```yaml
relabel_configs:
  # 只匹配__meta_kubernetes_service_annotation_prometheus_io_scrape=true的endpoint
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
    separator: ;
    regex: "true"
    replacement: $1
    action: keep
  # 如果有__meta_kubernetes_service_annotation_prometheus_io_scheme，且正则匹配(https?)，则将__scheme__修改为__meta_kubernetes_service_annotation_prometheus_io_scheme指定的值
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
    separator: ;
    regex: (https?)
    target_label: __scheme__
    replacement: $1
    action: replace
  # 如果有__meta_kubernetes_service_annotation_prometheus_io_path，且正则匹配(.+)，则将__metrics_path__修改为__meta_kubernetes_service_annotation_prometheus_io_path指定的值
  - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
    separator: ;
    regex: (.+)
    target_label: __metrics_path__
    replacement: $1
    action: replace
  # 如果有__address__;__meta_kubernetes_service_annotation_prometheus_io_port，且正则匹配([^:]+)(?::\d+)?;(\d+)，则将__address__修改为$1:$2指定的值
  - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
    separator: ;
    regex: ([^:]+)(?::\d+)?;(\d+)
    target_label: __address__
    replacement: $1:$2
    action: replace
  # 如果label名称正则匹配__meta_kubernetes_service_label_(.+)，则设置相应的label
  - separator: ;
    regex: __meta_kubernetes_service_label_(.+)
    replacement: $1
    action: labelmap
  # 设置kubernetes_namespace为__meta_kubernetes_namespace指定的值
  - source_labels: [__meta_kubernetes_namespace]
    separator: ;
    regex: (.*)
    target_label: kubernetes_namespace
    replacement: $1
    action: replace
  # 设置kubernetes_name为__meta_kubernetes_service_name指定的值
  - source_labels: [__meta_kubernetes_service_name]
    separator: ;
    regex: (.*)
    target_label: kubernetes_name
    replacement: $1
    action: replace
```

最终形成的抓取endpoint信息如下：

```yaml
__address__="192.168.65.3:9100"
app="prometheus"
chart="prometheus-7.4.1"
component="node-exporter"
heritage="Tiller"
release="prometheus"
kubernetes_namespace="default"
kubernetes_service_name="prometheus-node-exporter"
__metrics_path__="/metrics"
__scheme__="http"
job="kubernetes-service-endpoints"
```

上述的endpoint信息交由prometheus，prometheus就可以得到抓取地址了，为`__scheme__://__address____metrics_path__`，也即`http://192.168.65.3:9100/metrics`，最终在prometheus的targets里会看到：

![image-20181118145221626](/images/20181118/image-20181118145221626-2523941.png)

`http://192.168.65.3:9100/metrics`这个地址在k8s集群外部是无法被访问的，但在k8s集群内部可被访问：

```bash
kubectl -n default run test -ti --rm --image=busybox -- /bin/wget -O - http://192.168.65.3:9100/metrics
```

可以看该地址确实一系列抓取的监控指标数据。

## prometheus采集其它k8s监控数据

从上述分析来看，假设其它k8s部署了node_exporter和kube-state-metrics，用prometheus采集其它k8s集群的监控数据也是可行的，只需要解决两个问题：

1. 设置好` kubernetes_sd_configs`，让其可通过其它k8s集群的apiserver发现抓取的endpionts。
2. 设置好`relabel_configs`，构造出访问其它k8s集群中的service, pod, node等endpoint URL。

### 构造apiserver连接信息

解决问题1还是比较简单的，设置` kubernetes_sd_configs`时填入其它k8s信息的api_server、ca_file、bearer_token_file即可。

得到其它apiserver的ca_file、bearer_token_file方法如下：

```bash
# 创建一个叫admin的serviceaccount
kubectl -n kube-system create serviceaccount admin
# 给这个admin的serviceaccount绑上cluser-admin的clusterrole
kubectl -n kube-system create clusterrolebinding sa-cluster-admin --serviceaccount kube-system/admin --clusterrole cluser-admin
# 查询admin的secret
kubectl -n kube-system get serviceaccounts admin -o yaml | yq r - secrets[0].name
# 查询admin的secret详细信息，这里的admin-token-vtrt6是上面的命令查询出来的
kubectl -n kube-system get secret admin-token-vtrt6 -o yaml
# 获取bearer_token的内容
kubectl -n kube-system get secret admin-token-vtrt6 -o yaml | yq r - data.token|base64 -D
```

上面这段关于`ServiceAccount`、`ClusterRoleBinding`、`Secret`的操作原理见[Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)和[Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)。

得到bearer_token内容后，将其保存进文件，就可以设置`kubernetes_sd_configs`了，如下：

```yaml
kubernetes_sd_configs:
  - role: endpoints
    api_server: https://9.77.11.236:8443
    tls_config:
      insecure_skip_verify: true
    bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
```

### 构造出访问其它k8s集群中的service, pod, node等endpoint URL

经调研，发现外部可通过k8s的apiserver proxy机制很轻松地访问其它k8s集群内部的service、pod、node，参见[Manually constructing apiserver proxy URLs](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#manually-constructing-apiserver-proxy-urls)，因此在外部访问其它k8s集群内的地址构造成如下这样就可以了：

`https://${other_apiserver_address}/api/v1/nodes/node_name:[port_name]/proxy/metrics`

`https://${other_apiserver_address}/api/v1/namespaces/service_namespace/services/http:service_name[:port_name]/proxy/metrics`

`https://${other_apiserver_address}/api/v1/namespaces/pod_namespace/pods/http:pod_name[:port_name]/proxy/metrics`

最终整理出的relabel_configs配置如下：

```yaml
- job_name: 'kubernetes-apiservers-other-cluster'
  kubernetes_sd_configs:
    - role: endpoints
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
      action: keep
      regex: default;kubernetes;https
    - target_label: __address__
      replacement: ${other_apiserver_address}
- job_name: 'kubernetes-nodes-other-cluster'
  kubernetes_sd_configs:
    - role: node
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: ${other_apiserver_address}
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/${1}/proxy/metrics
- job_name: 'kubernetes-nodes-cadvisor-other-cluster'
  kubernetes_sd_configs:
    - role: node
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: ${other_apiserver_address}
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
- job_name: 'kubernetes-kube-service-endpoints-other-cluster'
  kubernetes_sd_configs:
    - role: endpoints
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_label_component]
      action: keep
      regex: '^(node-exporter|kube-state-metrics)$'
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__address__]
      action: replace
      target_label: instance
    - target_label: __address__
      replacement: ${other_apiserver_address}
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_name, __meta_kubernetes_pod_container_port_number]
      regex: ([^;]+);([^;]+);([^;]+)
      target_label: __metrics_path__
      replacement: /api/v1/namespaces/${1}/pods/http:${2}:${3}/proxy/metrics
    - action: labelmap
      regex: __meta_kubernetes_service_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      action: replace
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_service_name]
      action: replace
      target_label: kubernetes_name
```

上述配置已经很复杂了，更变态的是prometheus竟然[只支持一个配置文件](https://github.com/prometheus/prometheus/issues/1648)，因此每加入一个k8s集群的监控，就得往prometheus的配置文件里加入一段上述配置，想想都让人捏一把汗。。。

## 总结

虽然用一个prometheus监控多个k8s集群在架构上不太合理，但运用多种技术手段还是搞定了这个问题。解决问题的过程中查询了k8s和prometheus的各种资料，对`K8S Apiserver`、`K8S RBAC Authorization`、`Prometheus Configration`有了更深入的理解。另外最终的解决方案将prometheus的配置搞得很复杂，很有必要用模板技术生成该配置文件了。



