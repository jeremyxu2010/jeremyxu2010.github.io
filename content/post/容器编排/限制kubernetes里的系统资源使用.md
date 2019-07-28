---
title: 限制kubernetes里的系统资源使用
tags:
  - kuberentes
categories:
  - 容器编排
date: 2019-07-28 20:00:00+08:00
---

工作中需要对kubernetes中workload使用的系统资源进行一些限制，本周花时间研究了一下，这里记录一下。

## kubernetes的系统资源限制机制

kuberentes里存在两种机制进行系统资源限制，一个是Resource Quotas，一个是Limit Ranges。

### Resource Quotas

使用Resource Quotas可以限制某个命名空间使用的系统资源，使用方法如下：

```bash
kubectl create namespace quota-object-example

cat << EOF | kubectl -n quota-object-example create -f -
admin/resource/quota-objects.yaml 

apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-quota-demo
spec:
  hard:
  	requests.cpu: "8" # 限制该命名空间使用的总cpu request
  	requests.memory: "32Gi" # 限制该命名空间使用的总memory request
  	limits.cpu: "16" # 限制该命名空间使用的总cpu limit
  	limits.memory: "32Gi" # 限制该命名空间使用的总memory limit
  	requests.nvidia.com/gpu: 4 # 限制该命名空间使用的扩展资源
  	requests.storage: "500Gi" # 限制该命名空间使用的总storage request
  	limits.storage: "1000Gi" # 限制该命名空间使用的总storage limit
  	foo.storageclass.storage.k8s.io/requests.storage: "100Gi" # 限制该命名空间经由某个storage class创建的总storage request
  	foo.storageclass.storage.k8s.io/limits.storage: "200Gi" # 限制该命名空间经由某个storage class创建的总storage limit
  	requests.ephemeral-storage: "5Gi" # 限制该命名空间使用的总ephemeral-storage request
  	limits.ephemeral-storage: "50Gi" # 限制该命名空间使用的总ephemeral-storage limit
  	count/services: 20 # 限制该命名空间创建的总service数目
  	count/services.nodeports: 3 # 限制该命名空间创建的总nodeport类型service数目
  	count/deployments.apps: 5 # 限制该命名空间创建的总deployment数目
  	count/widgets.example.com: 5 # 限制该命名空间创建的总自定义资源widgets.example.com数目
EOF
```

可配置的系统资源表达式参考[Compute Resource Quota](https://kubernetes.io/docs/concepts/policy/resource-quotas/#compute-resource-quota)，[Storage Resource Quota](https://kubernetes.io/docs/concepts/policy/resource-quotas/#storage-resource-quota)，[Object Count Quota](https://kubernetes.io/docs/concepts/policy/resource-quotas/#object-count-quota)。

另外还可以给不同的scope指定不同的系统资源限制，如下：

```bash
cat << EOF | kubectl -n quota-object-example create -f -
apiVersion: v1
kind: List
items:
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-high
  spec:
    hard:
      cpu: "1000"
      memory: 200Gi
      pods: "10"
    scopeSelector:
      matchExpressions:
      - operator : In
        scopeName: PriorityClass
        values: ["high"]
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-medium
  spec:
    hard:
      cpu: "10"
      memory: 20Gi
      pods: "10"
    scopeSelector:
      matchExpressions:
      - operator : In
        scopeName: PriorityClass
        values: ["medium"]
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: pods-low
  spec:
    hard:
      cpu: "5"
      memory: 10Gi
      pods: "10"
    scopeSelector:
      matchExpressions:
      - operator : In
        scopeName: PriorityClass
        values: ["low"]
EOF

cat << EOF | kubectl -n quota-object-example create -f -
apiVersion: v1
kind: Pod
metadata:
  name: high-priority
spec:
  containers:
  - name: high-priority
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo hello; sleep 10;done"]
    resources:
      requests:
        memory: "10Gi"
        cpu: "500m"
      limits:
        memory: "10Gi"
        cpu: "500m"
  priorityClassName: high
EOF
```

这个例子创建了分别限制3个scope的ResourceQuota，下面创建的那个pod因为`priorityClassName`为`high`，因此它使用的系统资源只会遵守`pods-high`定义出的配额限制。

最后还可以组合`AdmissionConfiguration`，确保某些`priorityClassName`的资源只会被创建在有相应`ResourceQuota`的命名空间中，如下：

```bash
cat << EOF | kubectl -n quota-object-example create -f -
apiVersion: apiserver.k8s.io/v1alpha1
kind: AdmissionConfiguration
plugins:
- name: "ResourceQuota"
  configuration:
    apiVersion: resourcequota.admission.k8s.io/v1beta1
    kind: Configuration
    limitedResources:
    - resource: pods
      matchScopes:
      - scopeName: PriorityClass 
        operator: In
        values: ["cluster-services"]
EOF

cat << EOF | kubectl -n quota-object-example create -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pods-high
spec:
  hard:
    requests:
      memory: "10Gi"
      cpu: "500m"
    limits:
      memory: "10Gi"
      cpu: "500m"
  scopeSelector:
    matchExpressions:
    - scopeName: PriorityClass
      operator: In
      values: ["cluster-services"]
EOF

cat << EOF | kubectl -n quota-object-example create -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-service
spec:
  containers:
  - name: test-service
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo hello; sleep 10;done"]
    resources:
      requests:
        memory: "10Gi"
        cpu: "500m"
      limits:
        memory: "10Gi"
        cpu: "500m"
  priorityClassName: cluster-services
EOF
```

如上的配置可保证该pod只会被创建在有相应`ResourceQuota`的命名空间中。

### Limit Ranges

除了限制整个命名空间的系统资源使用量外，还可以通过`Limit Ranges`限制容器或pod的系统资源使用量，如下：

```bash
kubectl create namespace limitrange-demo

cat << EOF | kubectl -n limitrange-demo create -f -
admin/resource/limit-mem-cpu-container.yaml 

apiVersion: v1
kind: LimitRange
metadata:
  name: limit-mem-cpu-per-container
spec:
  limits:
  - max:
      cpu: "800m"
      memory: "1Gi"
    min:
      cpu: "100m"
      memory: "99Mi"
    default:
      cpu: "700m"
      memory: "900Mi"
    defaultRequest:
      cpu: "110m"
      memory: "111Mi"
    maxLimitRequestRatio:
      cpu: 2
      memory: 4
    type: Container # 也可以设置为Pod
EOF
```

这里跟`ResourceQuotas`的区别是这里设置的是最大最小值，只要申请的资源在范围内就算是合法的。同时还可以设置默认值，Container或Pod如果没有设置，就会使用默认值。

## 参考

1. https://kubernetes.io/docs/concepts/policy/resource-quotas/
2. https://kubernetes.io/docs/tasks/administer-cluster/quota-api-object/
3. https://kubernetes.io/docs/concepts/policy/limit-range/