---
title: 编写Kubernetes Operator
author: Jeremy Xu
tags:
  - kubernetes
  - operator
  - mysql
categories:
  - golang开发
date: 2019-05-12 10:31:00+08:00
---

这周的工作主要是验证几个Kubernetes Operator：

1. [mysql-operator](https://github.com/oracle/mysql-operator)
2. [redis-operator](https://github.com/spotahome/redis-operator)
3. [Redis-Operator](https://github.com/AmadeusITGroup/Redis-Operator)
4. [percona-server-mongodb-operator](https://github.com/percona/percona-server-mongodb-operator)

这些operator基本上都是用来部署、管理、维护一些基础服务的。在验证这些operator的过程中，也顺便研究了下如何写Kubernetes Operator，这里记录一下。

## Operator

Operator 是 CoreOS 推出的旨在简化复杂有状态应用管理的框架，它是一个感知应用状态的控制器，通过扩展 Kubernetes API 来自动创建、管理和配置应用实例。

你可以在 [OperatorHub.io](https://www.operatorhub.io/) 上查看 Kubernetes 社区推荐的一些 Operator 范例。

## Operator 原理

Operator 基于 Third Party Resources 扩展了新的应用资源，并通过控制器来保证应用处于预期状态。比如 etcd operator 通过下面的三个步骤模拟了管理 etcd 集群的行为：

1. 通过 Kubernetes API 观察集群的当前状态；
2. 分析当前状态与期望状态的差别；
3. 调用 etcd 集群管理 API 或 Kubernetes API 消除这些差别。

![image-20190512225440863](http://blog-images-1252238296.cosgz.myqcloud.com/image-20190512225440863.png)

Operator 是一个感知应用状态的控制器，所以实现一个 Operator 最关键的就是把管理应用状态的所有操作封装到配置资源和控制器中。通常来说 Operator 需要包括以下功能：

- Operator 自身以 deployment 的方式部署
- Operator 自动创建一个 Third Party Resources 资源类型，用户可以用该类型创建应用实例
- Operator 应该利用 Kubernetes 内置的 Serivce/ReplicaSet 等管理应用
- Operator 应该向后兼容，并且在 Operator 自身退出或删除时不影响应用的状态
- Operator 应该支持应用版本更新
- Operator 应该测试 Pod 失效、配置错误、网络错误等异常情况

## 实例分析

上面这样说的一些概念可能比较抽象，这里以[mysql-operator](https://github.com/oracle/mysql-operator)这个operator为例，我们具体分析一下一个Kubernetes Operator具体是如何实现的。

首先分析其入口main函数，这个没有太多说的，就是解析参数，并执行`app.Run`函数。

`https://github.com/oracle/mysql-operator/blob/master/cmd/mysql-operator/main.go`

```golang
...
  if err := app.Run(opts); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
...	
```

然后看看`app.Run`函数

`https://github.com/oracle/mysql-operator/blob/master/cmd/mysql-operator/app/mysql_operator.go#L56:6`

```golang
// Run starts the mysql-operator controllers. This should never exit.
func Run(s *operatoropts.MySQLOperatorOpts) error {
  // 构造kubeconfig以便连接kubernetes的APIServer
	kubeconfig, err := clientcmd.BuildConfigFromFlags(s.Master, s.KubeConfig)
	if err != nil {
		return err
	}
	
	...
	
	// 构造kubeClient、 mysqlopClient, 以便操作Kubernetes里的一些资源
	kubeClient := kubernetes.NewForConfigOrDie(kubeconfig)
	mysqlopClient := clientset.NewForConfigOrDie(kubeconfig)

  // 构造一些共享的informer，以便监听自定义对象及kubernetes里的一些核心资源
	// Shared informers (non namespace specific).
	operatorInformerFactory := informers.NewFilteredSharedInformerFactory(mysqlopClient, resyncPeriod(s)(), s.Namespace, nil)
	kubeInformerFactory := kubeinformers.NewFilteredSharedInformerFactory(kubeClient, resyncPeriod(s)(), s.Namespace, nil)

  var wg sync.WaitGroup

  // 构造自定义类型mysqlcluster的控制器
	clusterController := cluster.NewController(
		*s,
		mysqlopClient,
		kubeClient,
		operatorInformerFactory.MySQL().V1alpha1().Clusters(),
		kubeInformerFactory.Apps().V1beta1().StatefulSets(),
		kubeInformerFactory.Core().V1().Pods(),
		kubeInformerFactory.Core().V1().Services(),
		30*time.Second,
		s.Namespace,
	)
	wg.Add(1)
	go func() {
		defer wg.Done()
		clusterController.Run(ctx, 5)
	}()
	
	// 下面分别为每个自定义类型构造了相应的控制器
	...
```

Kubernetes Operator的核心逻辑就在自定义类型的控制器里面。

`https://github.com/oracle/mysql-operator/blob/master/pkg/controllers/cluster/controller.go#L142`

```golang
// NewController creates a new MySQLController.
func NewController(
	...
) *MySQLController {
  // 构造MySQLController
  m := MySQLController{
		...
	}

  // 监控自定义类型mysqlcluster的变化(增加、更新、删除)，这里看一看m.enqueueCluster函数可以发现都只是把发生变化的自定义对象的名称放入工作队列中
	clusterInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: m.enqueueCluster,
		UpdateFunc: func(old, new interface{}) {
			m.enqueueCluster(new)
		},
		DeleteFunc: func(obj interface{}) {
			cluster, ok := obj.(*v1alpha1.Cluster)
			if ok {
				m.onClusterDeleted(cluster.Name)
			}
		},
	})
```

`https://github.com/oracle/mysql-operator/blob/master/pkg/controllers/cluster/controller.go#L231`

```golang
// Run函数里会启动工作协程处理上述放入工作队列的自定义对象的名称
func (m *MySQLController) Run(ctx context.Context, threadiness int) {
  ...
  // Launch two workers to process Foo resources
	for i := 0; i < threadiness; i++ {
		go wait.Until(m.runWorker, time.Second, ctx.Done())
	}
	...
}
```

从`runWorker`函数一步步跟踪过程，发现真正干活的是`syncHandler`函数

`https://github.com/oracle/mysql-operator/blob/master/pkg/controllers/cluster/controller.go#L301`

```golang
func (m *MySQLController) syncHandler(key string) error {
	...

	nsName := types.NamespacedName{Namespace: namespace, Name: name}

	// Get the Cluster resource with this namespace/name.
	cluster, err := m.clusterLister.Clusters(namespace).Get(name)
	if err != nil {
	  // 如果自定义资源对象已不存在，则不用处理
		// The Cluster resource may no longer exist, in which case we stop processing.
		if apierrors.IsNotFound(err) {
			utilruntime.HandleError(fmt.Errorf("mysqlcluster '%s' in work queue no longer exists", key))
			return nil
		}
		return err
	}

	cluster.EnsureDefaults()
	// 校验自定义资源对象
	if err = cluster.Validate(); err != nil {
		return errors.Wrap(err, "validating Cluster")
	}

  // 给自定义资源对象设置一些默认属性
	if cluster.Spec.Repository == "" {
		cluster.Spec.Repository = m.opConfig.Images.DefaultMySQLServerImage
	}

	...

	svc, err := m.serviceLister.Services(cluster.Namespace).Get(cluster.Name)
	// If the resource doesn't exist, we'll create it
	// 如果该自定义资源对象存在，则应该要创建相应的Serivce，如Serivce不存在，则创建
	if apierrors.IsNotFound(err) {
		glog.V(2).Infof("Creating a new Service for cluster %q", nsName)
		svc = services.NewForCluster(cluster)
		err = m.serviceControl.CreateService(svc)
	}

	// If an error occurs during Get/Create, we'll requeue the item so we can
	// attempt processing again later. This could have been caused by a
	// temporary network failure, or any other transient reason.
	if err != nil {
		return err
	}

	// If the Service is not controlled by this Cluster resource, we should
	// log a warning to the event recorder and return.
	if !metav1.IsControlledBy(svc, cluster) {
		msg := fmt.Sprintf(MessageResourceExists, "Service", svc.Namespace, svc.Name)
		m.recorder.Event(cluster, corev1.EventTypeWarning, ErrResourceExists, msg)
		return errors.New(msg)
	}

	ss, err := m.statefulSetLister.StatefulSets(cluster.Namespace).Get(cluster.Name)
	// If the resource doesn't exist, we'll create it
	// 如果该自定义资源对象存在，则应该要创建相应的StatefulSet，如StatefulSet不存在，则创建
	if apierrors.IsNotFound(err) {
		glog.V(2).Infof("Creating a new StatefulSet for cluster %q", nsName)
		ss = statefulsets.NewForCluster(cluster, m.opConfig.Images, svc.Name)
		err = m.statefulSetControl.CreateStatefulSet(ss)
	}

	// If an error occurs during Get/Create, we'll requeue the item so we can
	// attempt processing again later. This could have been caused by a
	// temporary network failure, or any other transient reason.
	if err != nil {
		return err
	}

	// If the StatefulSet is not controlled by this Cluster resource, we
	// should log a warning to the event recorder and return.
	if !metav1.IsControlledBy(ss, cluster) {
		msg := fmt.Sprintf(MessageResourceExists, "StatefulSet", ss.Namespace, ss.Name)
		m.recorder.Event(cluster, corev1.EventTypeWarning, ErrResourceExists, msg)
		return fmt.Errorf(msg)
	}

	// Upgrade the required component resources the current MySQLOperator version.
	// 确保StatefulSet上的BuildVersion与自定义资源对象上的一致，如不一致，则修改得一致
	if err := m.ensureMySQLOperatorVersion(cluster, ss, buildversion.GetBuildVersion()); err != nil {
		return errors.Wrap(err, "ensuring MySQL Operator version")
	}

	// Upgrade the MySQL server version if required.
	if err := m.ensureMySQLVersion(cluster, ss); err != nil {
		return errors.Wrap(err, "ensuring MySQL version")
	}

	// If this number of the members on the Cluster does not equal the
	// current desired replicas on the StatefulSet, we should update the
	// StatefulSet resource.
	// 如果StatefulSet的Replicas值与自定义资源对象上配置不一致，则更新StatefulSet
	if cluster.Spec.Members != *ss.Spec.Replicas {
		glog.V(4).Infof("Updating %q: clusterMembers=%d statefulSetReplicas=%d",
			nsName, cluster.Spec.Members, ss.Spec.Replicas)
		old := ss.DeepCopy()
		ss = statefulsets.NewForCluster(cluster, m.opConfig.Images, svc.Name)
		if err := m.statefulSetControl.Patch(old, ss); err != nil {
			// Requeue the item so we can attempt processing again later.
			// This could have been caused by a temporary network failure etc.
			return err
		}
	}

	// Finally, we update the status block of the Cluster resource to
	// reflect the current state of the world.
	// 最后更新自定义资源对象的状态
	err = m.updateClusterStatus(cluster, ss)
	if err != nil {
		return err
	}

	m.recorder.Event(cluster, corev1.EventTypeNormal, SuccessSynced, MessageResourceSynced)
	return nil
}
```

这个方法比较长，上面已在关键代码处加上中文注释了，结合代码应该看得比较清楚了。基本上大部分Controller都是这么个逻辑。

这里有个地址要注意下，为了保证那些依据自定义资源对象创建出的核心资源生命周期一致，比如随着自定义资源对象一起删除，在构建核心资源时需要设置`OwnerReferences`

`https://github.com/oracle/mysql-operator/blob/master/pkg/resources/statefulsets/statefulset.go#L390`

```golang
			OwnerReferences: []metav1.OwnerReference{
				*metav1.NewControllerRef(cluster, schema.GroupVersionKind{
					Group:   v1alpha1.SchemeGroupVersion.Group,
					Version: v1alpha1.SchemeGroupVersion.Version,
					Kind:    v1alpha1.ClusterCRDResourceKind,
				}),
			},
```

整个Operator大概就是这样了。

## 简易方法

上面这样写Operator还是太麻烦了点，其实官方已经给出了[operator-sdk](https://github.com/operator-framework/operator-sdk)，参考其[教程](https://github.com/operator-framework/operator-sdk/blob/master/doc/user-guide.md)，只需要重点编写[Reconcile](https://github.com/operator-framework/operator-sdk-samples/blob/master/memcached-operator/pkg/controller/memcached/memcached_controller.go#L84)函数的逻辑就可以了。

`https://github.com/operator-framework/operator-sdk-samples/blob/master/memcached-operator/pkg/controller/memcached/memcached_controller.go#L84`

```golang
// Reconcile reads that state of the cluster for a Memcached object and makes changes based on the state read
// and what is in the Memcached.Spec
// TODO(user): Modify this Reconcile function to implement your Controller logic.  This example creates
// a Memcached Deployment for each Memcached CR
// Note:
// The Controller will requeue the Request to be processed again if the returned error is non-nil or
// Result.Requeue is true, otherwise upon completion it will remove the work from the queue.
func (r *ReconcileMemcached) Reconcile(request reconcile.Request) (reconcile.Result, error) {
  ...
}
```

看一下该函数的注释，其功能已经很清楚，就是完成通过 Kubernetes API 观察集群的当前状态；分析当前状态与期望状态的差别；调用 Kubernetes API 消除这些差别，也就是上面`syncHandler`的逻辑。

当然用[operator-sdk](https://github.com/operator-framework/operator-sdk)生成Operator的骨架，只需填充核心逻辑，这种方法无疑更好，整个代码结构更加标准。

## Operator的现状

官方是希望通过Operator封装大部分基础服务软件的运维操作的，但目前很多Operator并不完善。比如虽然形式上给Operator划分了5个成熟度等级，但实际上大部分Operator仅只能完成安装部署而已。

![img](http://blog-images-1252238296.cosgz.myqcloud.com/capability-level-diagram.svg)

还有很多Operator明确说明目前只是alpha状态，目前不建议投入生产。

## 总结

本文概述了Kubernetes Operator的实现原理，并以mysql-operator的核心代码为示例，大致走读了一遍核心逻辑。

## 参考

1. https://kubernetes.feisky.xyz/fu-wu-zhi-li/index/operator
2. https://github.com/operator-framework/operator-sdk
3. https://github.com/oracle/mysql-operator/
4. https://operatorhub.io/