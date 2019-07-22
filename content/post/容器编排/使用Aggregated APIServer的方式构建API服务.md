---
title: 使用Aggregated APIServer的方式构建API服务
author: Jeremy Xu
tags:
  - k8s
  - devops
  - api
categories:
  - 容器编排
date: 2019-07-20 18:00:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20190720
---

工作中需要以kubernetes原生的方式构建API接口服务，并将构建出的API接口直接聚合到kubernetes的apiserver服务上。本周花了不少时间研究这个，这里记录一下。

## 好处

尽管可以使用gin, go-restful等go语言web框架轻易地构建出一个稳定的API接口服务，但以kubernetes原生的方式构建API接口服务还是有很多吸引人的好处的。[官方文档](https://kubernetes.io/docs/concepts/extend-kubernetes/extend-cluster/#api-extensions)中已经将这些好处列出了：

> ### User-Defined Types
>
> Consider adding a Custom Resource to Kubernetes if you want to define new controllers, application configuration objects or other declarative APIs, and to manage them using Kubernetes tools, such as `kubectl`.
>
> Do not use a Custom Resource as data storage for application, user, or monitoring data.
>
> For more about Custom Resources, see the [Custom Resources concept guide](https://kubernetes.io/docs/concepts/api-extension/custom-resources/).
>
> ### Combining New APIs with Automation
>
> The combination of a custom resource API and a control loop is called the [Operator pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/). The Operator pattern is used to manage specific, usually stateful, applications. These custom APIs and control loops can also be used to control other resources, such as storage or policies.
>
> ### Changing Built-in Resources
>
> When you extend the Kubernetes API by adding custom resources, the added resources always fall into a new API Groups. You cannot replace or change existing API groups. Adding an API does not directly let you affect the behavior of existing APIs (e.g. Pods), but API Access Extensions do.
>
> ### API Access Extensions
>
> When a request reaches the Kubernetes API Server, it is first Authenticated, then Authorized, then subject to various types of Admission Control. See [Controlling Access to the Kubernetes API](https://kubernetes.io/docs/reference/access-authn-authz/controlling-access/) for more on this flow.
>
> Each of these steps offers extension points.
>
> Kubernetes has several built-in authentication methods that it supports. It can also sit behind an authenticating proxy, and it can send a token from an Authorization header to a remote service for verification (a webhook). All of these methods are covered in the [Authentication documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/).
>
> ### Authentication
>
> [Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/) maps headers or certificates in all requests to a username for the client making the request.
>
> Kubernetes provides several built-in authentication methods, and an [Authentication webhook](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication) method if those don’t meet your needs.
>
> ### Authorization
>
> [Authorization](https://kubernetes.io/docs/reference/access-authn-authz/webhook/) determines whether specific users can read, write, and do other operations on API resources. It just works at the level of whole resources – it doesn’t discriminate based on arbitrary object fields. If the built-in authorization options don’t meet your needs, and [Authorization webhook](https://kubernetes.io/docs/reference/access-authn-authz/webhook/) allows calling out to user-provided code to make an authorization decision.
>
> ### Dynamic Admission Control
>
> After a request is authorized, if it is a write operation, it also goes through [Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) steps. In addition to the built-in steps, there are several extensions:
>
> - The [Image Policy webhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook) restricts what images can be run in containers.
> - To make arbitrary admission control decisions, a general [Admission webhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#admission-webhooks) can be used. Admission Webhooks can reject creations or updates.

简单一句话就是构建出的API接口更加规范整齐，能利用kubernetes原生的认证、授权、准入机制。当然对个人来说，也能更了解kubernetes里那些API接口到底是如何实现的。

## 实现方案

官方提供了两种方式以实现对标准kubernetes API接口的扩展：1）Aggregated APIServer  2）Custom Resource

两种方式的区别是定义api-resource的方式不同。在Aggregated APIServer方式中，api-resource是通过代码向kubernetes注册资源类型的方式实现的，而Custom Resource是直接通过yaml文件创建自定义资源的方式实现的。

最终达到的效果倒是比较类似，最终都可以通过访问`/apis/myextension.mycompany.io/v1/…`之类的API接口来存取api-resource。除此之外，在很多方面也存在一些区别，见[这里](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/compare_with_kubebuilder.md)。

> ### API Access Control
>
> ##### Authentication
>
> - **CR**: All strategies supported. Configured by root apiserver.
> - **AA**: Supporting all root apiserver's authenticating strategies but it has to be done via [authentication token review api](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication)except for [authentication proxy](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#authenticating-proxy) which will cause an extra cost of network RTT.
>
> ##### Authorization
>
> - **CR**: All strategies supported. Configured by root apiserver.
> - **AA**: Delegating authorization requests to root apiserver via [SubjectAccessReview api](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access). Note that this approach will also cost a network RTT.
>
> ##### Admission Control
>
> - **CR**: You could extend via dynamic admission control webhook (which is costing network RTT).
> - **AA**: While You can develop and customize your own admission controller which is dedicated to your AA. While You can't reuse root-apiserver's built-in admission controllers nomore.
>
> ### API Schema
>
> Note: CR's integration with OpenAPI schema is being enhanced in the future releases and it will have a stronger integration with OpenAPI mechanism.
>
> ##### Validating
>
> - **CR**: (landed in 1.12) Defined via OpenAPIv3 Schema grammar. [more](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/#validation)
> - **AA**: You can customize any validating flow you want.
>
> ##### Conversion
>
> - **CR**: (landed in 1.13) The CR conversioning (basically from storage version to requested version) could be done via conversioning webhook.
> - **AA**: Develop any conversion you want.
>
> ##### SubResource
>
> - **CR**: Currently only status and scale sub-resource supported.
> - **AA**: You can customize any sub-resouce you want.
>
> ##### OpenAPI Schema
>
> - **CR**: (landed in 1.13) The corresponding CRD's OpenAPI schema will be automatically synced to root-apiserver's openapi doc api.
> - **AA**: OpenAPI doc has to be manually generated by code-generating tools.
>
> ##### Other
>
> | Functionalities                       | AA (Aggregated APIServer)                                    | CR (Custom Resource)                                         |
> | ------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
> | SMP(Strategic Merge Patch)            | Supported                                                    | Not yet. Will be replaced via server-side apply instead      |
> | Informative Kubectl Printing          | Not supported, unless you develop your own with server-side printing. | By [AdditionalPrinterColumns](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/#additional-printer-columns) |
> | Websocket/(Other non-HTTP transport)  | Supported                                                    | No                                                           |
> | `metadata.Generation`Auto Increment   | Supported                                                    | Nope, and this is designed                                   |
> | Use Another Backend/Secondary Storage | Supported                                                    | For now, ETCD3 only                                          |
>
> More Comparision [here](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#advanced-features-and-flexibility)

总的来看，AA这个方式相对复杂一点，但灵活度很高，基本后续业务上的所有需求都可以满足。最终我们选择使用AA方案来构建API接口服务。

## 实现API接口服务

### 快速实现

虽然官方给了一个[sample-apiserver](https://github.com/kubernetes/sample-apiserver)，我们可以照着实现自己的Aggregated APIServer。但完全手工编写还是太费劲了，这里使用官方推荐的工具[apiserver-builder](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/README.md)帮助快速创建项目骨架。

[apiserver-builder](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/README.md)构建AA方案的API接口服务的原理还是比较清晰的，总之就是kubernetes里最常见的控制器模式，这里就不具体介绍了，[官方文档](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/concepts/api_building_overview.md)既有文字又有图片讲得还是挺细致的，强烈推荐大家多看看，学习一下。

`apiserver-builder`的安装就不细说了，照着[官方文档](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/installing.md)做就可以了。

以下参考`apiserver-builder`的官方文档，得出的一些关键步骤：

```bash
# 创建项目目录
mkdir $GOPATH/src/github.com/jeremyxu2010/demo-apiserver
# 在项目目录下新建一个名为boilerplate.go.txt，里面是代码的头部版权声明
cd $GOPATH/src/github.com/jeremyxu2010/demo-apiserver
curl -o boilerplate.go.txt https://github.com/kubernetes/kubernetes/blob/master/hack/boilerplate/boilerplate.go.txt
# 初始化项目
apiserver-boot init repo --domain jeremyxu2010.me
# 创建一个非命名空间范围的api-resource
apiserver-boot create group version resource --group demo --version v1beta1 --non-namespaced=true --kind Foo
# 创建Foo这个api-resource的子资源
apiserver-boot create subresource --subresource bar --group demo --version v1beta1 --kind Foo
# 生成上述创建的api-resource类型的相关代码，包括deepcopy接口实现代码、versioned/unversioned类型转换代码、api-resource类型注册代码、api-resource类型的Controller代码、api-resource类型的AdmissionController代码
apiserver-boot build generated
# 直接在本地将etcd, apiserver, controller运行起来
apiserver-boot run local
```

上述这样操作之后，就可以访问我们的APIServer了，如下面的命令：

```bash
curl -k https://127.0.0.1:9443/apis/demo.jeremyxu2010.me/v1beta1/foos
```

当然可以新建一个yaml文件，然后用kubectl命令直接对api-resource进行操作：

```bash
# 创建Foo资源的yaml
echo 'apiVersion: demo.jeremyxu2010.me/v1beta1
kind: Foo
metadata:
  name: foo-example
  namespace: test
spec: {}' > sample/foo.yaml

# 查看已经注册的api-resource类型
kubectl --kubeconfig api-resources
# 列所有foos
kubectl --kubeconfig kubeconfig get foos
# 创建foo
kubectl --kubeconfig kubeconfig create -f sample/foo.yaml
# 再列所有foos
kubectl --kubeconfig kubeconfig get foos
# Get新创建的foo
kubectl --kubeconfig kubeconfig get foos foo-example
kubectl --kubeconfig kubeconfig get foos foo-example -o yaml
# Delete新创建的foo
kubectl --kubeconfig kubeconfig delete foos foo-example
```

如果在apiserver的main方法里补上一些代码，以开启swagger-ui，还能更方便地看到这些API接口：

```go
func main() {
	version := "v0"
	server.StartApiServer("/registry/jeremyxu2010.me", apis.GetAllApiBuilders(), openapi.GetOpenAPIDefinitions, "Api", version, func(apiServerConfig *apiserver.Config) error {
		...
		apiServerConfig.RecommendedConfig.EnableSwaggerUI = true
		apiServerConfig.RecommendedConfig.SwaggerConfig = genericapiserver.DefaultSwaggerConfig()
		return nil
	})
}
```

然后浏览器访问`https://127.0.0.1:9443/swagger-ui/`就可以在swagger的Web页面上看到创建出来的所有API接口。

### 定制API接口

像上面这样创建的API接口，接口是都有了，但接口没有啥意义，一般要根据实际情况定义api-resource的spec、status等结构体。

```go
type Foo struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   FooSpec   `json:"spec,omitempty"`
	Status FooStatus `json:"status,omitempty"`
}

// FooSpec defines the desired state of Foo
type FooSpec struct {
}

// FooStatus defines the observed state of Foo
type FooStatus struct {
}
```

可参考[这里](https://github.com/operator-framework/operator-sdk/blob/master/doc/user-guide.md#define-the-spec-and-status)。

有时默认的增删改查操作并不满足业务需求，这时可以自定义api-resource或subresource的REST实现，默认实现是存取到etcd的，通过这种方式甚至可以将自定义资源存入后端数据库。自定义REST实现的方法参考[adding_custom_rest](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/adding_custom_rest.md)，[foo_rest.go](https://github.com/jeremyxu2010/demo-apiserver/blob/master/pkg/apis/demo/foo_rest.go)，[bar_foo_rest.go](https://github.com/jeremyxu2010/demo-apiserver/blob/master/pkg/apis/demo/bar_foo_rest.go)。另外kubernetes的代码里也有大量自定义REST实现可参考，见[这里](https://github.com/kubernetes/kubernetes/tree/master/pkg/registry/core/pod/rest)。

为api-resource类型的默认值设置可参考[这里](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/adding_defaulting.md)，添加校验规则可参考[这里](https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/adding_validation.md)。

### 定制Controller

默认生成的api-resource的Reconcile逻辑如下：

```go
// Reconcile reads that state of the cluster for a Foo object and makes changes based on the state read
// and what is in the Foo.Spec
// TODO(user): Modify this Reconcile function to implement your Controller logic.  The scaffolding writes
// a Deployment as an example
// +kubebuilder:rbac:groups=demo.jeremyxu2010.me,resources=foos,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=demo.jeremyxu2010.me,resources=foos/status,verbs=get;update;patch
func (r *ReconcileFoo) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	// Fetch the Foo instance
	instance := &demov1beta1.Foo{}
	err := r.Get(context.TODO(), request.NamespacedName, instance)
	if err != nil {
		if errors.IsNotFound(err) {
			// Object not found, return.  Created objects are automatically garbage collected.
			// For additional cleanup logic use finalizers.
			return reconcile.Result{}, nil
		}
		// Error reading the object - requeue the request.
		return reconcile.Result{}, err
	}

	return reconcile.Result{}, nil
}
```

一般来说要按自己的业务逻辑进行定制，可参考[这里](https://github.com/operator-framework/operator-sdk-samples/blob/master/memcached-operator/pkg/controller/memcached/memcached_controller.go#L84)。

api-resource的admission controller编写可参考[这里](https://github.com/stackrox/admission-controller-webhook-demo/blob/master/cmd/webhook-server/admission_controller.go)。

## 打包部署

程序写好后，通过以下命令即可生成容器镜像及kubernetes的部署manifest文件：

```bash
# 生成二进制文件
apiserver-boot build executables
# 生成容器镜像
apiserver-boot build container --image demo/foo-apiserver:latest
# 生成kubernetes的部署manifest文件，可直接在kubernetes里apply即完成部署
apiserver-boot build config --name fool-apiserver --namespace default --image demo/foo-apiserver:latest
```

观察生成的kubernetes部署manifest文件`config/apiserver.yaml`，可以发现最终会创建一个Deployment，一个Service和一个APIService类型的kubernetes资源，同时APIService的caBundle及apiserver的TLS证书也配置妥当了。这个跟[官方文档](https://kubernetes.io/docs/tasks/access-kubernetes-api/setup-extension-api-server/#setup-an-extension-api-server-to-work-with-the-aggregation-layer)中所说的第4、5、6、7、8、14点相符。

## 生成文档

最终交付除了部署好的程序，还可以生成相应的API文档，操作如下：

```bash
curl -o docs/openapi-spec/swagger.json https://127.0.0.1:9443/openapi/v2
apiserver-build build docs --build-openapi=false --operations=true
```

使用浏览器打开`docs/build/index.html`即可访问生成的API文档，这文档的风格可kubernetes的[reference文档](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.15/)风格是一致，相当专业！！！

## 其它

在实现过程中还顺带改了`apiserver-builder`的[一个小bug](https://github.com/kubernetes-incubator/apiserver-builder-alpha/pull/381)，也算为社区做了点贡献。

`apiserver-builder`在生成代码时使用了一些kubernetes项目本身使用的code generator，[这些code generator](https://github.com/kubernetes/code-generator/tree/master/cmd)也挺有趣的，有时间可以仔细研究下。

## 总结

编写Aggregated APIServer风格的API接口服务这一工作，终于接触到了kubernetes里的一些内部设计，不得不说这套设计还是相当简洁稳定的，难怪kubernetes项目最终能成功。

## 参考

1. https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/
2. https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
3. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/compare_with_kubebuilder.md
4. https://github.com/kubernetes/sample-apiserver/blob/master/README.md
5. https://github.com/Kubernetes-incubator/apiserver-builder/blob/master/README.md
6. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/installing.md
7. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/concepts/api_building_overview.md
8. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/tools_user_guide.md
9. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/adding_non_namespaced_resources.md
10. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/adding_defaulting.md
11. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/adding_validation.md
12. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/running_in_cluster.md
13. https://github.com/kubernetes-incubator/apiserver-builder-alpha/blob/master/docs/building_docs.md
14. https://github.com/kubernetes/code-generator
15. https://kubernetes.io/docs/tasks/access-kubernetes-api/setup-extension-api-server/