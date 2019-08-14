---
title: 使用casbin完成验证授权
tags:
  - casbin
  - golang
  - rbac
categories:
  - golang开发
date: 2019-08-10 15:20:00+08:00
---

上一篇讲了搭建一个身份认证系统，可以看到借助dex搭建一个安全可靠的身份认证系统并不是太难。本篇再讲一下用`casbin`完成验证授权。

## 什么是验证授权

> 授权（英语：Authorization）一般是指对信息安全或计算机安全相关的资源定义与授予访问权限，尤指访问控制。动词“授权”可指定义访问策略与接受访问。

`授权`作为名词，其代表的是在计算机系统中定义的资源访问权限。而`验证授权`就是验证计算机帐户是否有资源的访问权限。

举个栗子，假设现在有一本书`book1`，其拥有`read`, `write`的操作，那么我们可以先定义以下`授权`：

1. `alice`可以`read`书籍`book1`
2. `bob`可以`write`书籍`book1`
3. `bob`可以`read`书籍`book1`

现在来了一个用户`alice`她想`write`书籍`book1`，这时调用验证授权功能模块的接口，验证授权功能模块根据上述`授权`规则可以快速判断`alice`不可以`write`书籍`book1`；过一会儿又来了一个用户`bob`他想`write`书籍`book1`，这时调用验证授权系统的接口，验证授权系统根据上述`授权`规则可以快速判断`bob`可以`write`书籍`book1`。

可以看到`身份认证系统`强调地是安全可靠地得到计算机用户的身份信息，而`验证授权`强调地是根据计算机的身份信息、访问的资源、对资源的操作等给出一个Yes/No的答复。

## 常用授权模型

### ACL
`ACL`是`Access Control List`的缩写，称为访问控制列表. 定义了谁可以对某个数据进行何种操作.
关键数据模型有: 用户, 权限.

ACL规则简单, 也带来一些问题: 资源的权限需要在用户间切换的成本极大; 用户数或资源的数量增长, 都会加剧规则维护成本;

#### 典型应用

1. 文件系统

文件系统的文件或文件夹定义某个账号(user)或某个群组(group)对文件(夹)的读(read)/写(write)/执行(execute)权限.

2. 网络访问

防火墙: 服务器限制不允许指定机器访问其指定端口, 或允许特定指定服务器访问其指定几个端口.

### RBAC
`RBAC`是`Role-based access control`的缩写, 称为 基于角色的访问控制.
核心数据模型有: 用户, 角色, 权限.

用户具有角色, 而角色具有权限, 从而表达用户具有权限.

由于有角色作为中间纽带, 当新增用户时, 只需要为用户赋予角色, 用户即获得角色所包含的所有权限.

`RBAC`存在多个扩展版本, `RBAC0`、`RBAC1`、`RBAC2`、`RBAC3`。这些版本的详细说明可以参数[这里](https://www.jianshu.com/p/b078abe9534f)。我们在实际项目中经常使用的是`RBAC1`，即带有角色继承概念的RBAC模型。

### ABAC
`ABAC`是`Attribute-based access control`的缩写, 称为基于属性的访问控制.

权限和资源当时的状态(属性)有关, 属性的值可以用于正向判断(符合某种条件则通过), 也可以用于反向判断(符合某种条件则拒绝):

#### 典型应用
1. 论坛的评论权限, 当帖子是锁定状态时, 则不再允许继续评论;
2. Github 私有仓库不允许其他人访问;
3. 发帖者可以编辑/删除评论(如果是RBAC, 会为发帖者定义一个角色, 但是每个帖子都要新增一条用户/发帖角色的记录);
4. 微信聊天消息超过2分钟则不再允许撤回;
5. 12306 只有实名认证后的账号才能购票;
6. 已过期的付费账号将不再允许使用付费功能;

## 实现权限验证

前面提到了多种不同的权限模型，要完全自研实现不同的权限模型还是挺麻烦的。幸好`casbin`出现，它将上述不同的模型抽象为自己的`PERM metamodel`，这个`PERM metamodel`只包括`Policy`, `Effect`, `Request`, `Matchers`，只通过这几个模型对象的组合即可实现上述提到的多种权限模型，如果业务上需要切换权限模型，也只需要配置一下`PERM metamodel`，并不需要大改权限模型相关的代码，这一点真的很赞！！！

一个最简单的`ACL`权限模型即可像下面这样定义：

`acl_simple_model.conf`

```
# Request definition
[request_definition]
r = sub, obj, act

# Policy definition
[policy_definition]
p = sub, obj, act

# Policy effect
[policy_effect]
e = some(where (p.eft == allow))

# Matchers
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
```

相应的授权规则可以像下面这样定义：

`acl_simple_policy.csv`

```
p, alice, data1, read
p, bob, data2, write
```

这意味着`alice`可以`read`资源`data1`；`bob`可以`write`资源`data2`。

写一个简单的程序就可以完成该权限验证：

```go
package main

import (
	"fmt"
	"github.com/casbin/casbin/v2"
)

func main() {
	e, _ := casbin.NewSyncedEnforcer("acl_simple_model.conf", "acl_simple_policy.csv")
	sub := "alice"   // the user that wants to access a resource.
	obj := "data1"   // the resource that is going to be accessed.
	act := "read"    // the operation that the user performs on the resource.

	if passed, _ := e.Enforce(sub, obj, act); passed {
		// permit alice to read data1
		fmt.Println("Enforce policy passed.")
	} else {
		// deny the request, show an error
		fmt.Println("Enforce policy denied.")
	}
}
```

## casbin模型详解

``casbin``官方其实已经提供了多种模型的定义及示例policy定义，见这里。而且为了便于用户理解诊断模型及policy，还给了个在线的editor，修改模型或policy时可以利用此工具。

从上面的示例可以看出基于`casbin`实现权限验证，代码很简单，但`casbin`的模型定义及policy定义初看还是挺复杂的，这样详细理解一下。

`casbin`的模型定义里会出现4个部分：`[request_definition]`,` [policy_definition]`,` [policy_effect]`, `[matchers]`。

其中`[request_definition]`描述的是访问请求的定义，如下面的定义将访问请求的三个参数分别映射为`r.sub`、`r.obj`、`r.act`（注意并不是所有的访问请求一定是3个参数）:

```
[request_definition]
r = sub, obj, act
```

同理`[policy_definition]`描述的是授权policy的定义，如下面的定义将每条授权policy分别映射为`p.sub`、`p.obj`、`p.act`（注意并不是所有的授权policy一定是3个参数，也不是必须只有一条授权policy定义）:

```
[policy_definition]
p = sub, obj, act
```

`[matchers]`描述的是根据访问请求如何找到匹配的授权policy，如下面的定义将根据`r.sub`、`r.obj`、`r.act`、`p.sub`、`p.obj`、`p.act`找到完全匹配的授权policy：

```
[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
```

在写`[matchers]`规则是还可以使用一些内置或自定义函数，参考[这里的文档](https://casbin.org/docs/en/syntax-for-models#functions-in-matchers)。

最后`[policy_effect]`描述如果找到匹配的多条的授权policy，最终给出的验证授权结果，如下面的定义说明只要有一条匹配的授权策略其`eft`是`allow`，则最终给出的验证授权结果就是`允许`（注意每条授权policy默认的eft就是allow）。

```
[policy_effect]
e = some(where (p.eft == allow))
```

如果使用`RBAC`权限模型，可能还会使用`[role_definition]`，这个`[role_definition]`算是最复杂的了，其可以描述user-role之间的映射关系或resource-role之间的映射关系。这么说比较抽象，还是举例说明：

假设模型定义如下：

```
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```

授权policy文件如下：

```csv
p, data2_admin, data2, read
p, data2_admin, data2, write

g, alice, data2_admin
```

现在收到了授权请求`alice, data2, read`，这时`r.sub`为`alice`，根据`g = _, _`及`g(r.sub, p.sub)`，我们可以得出对应的`p.sub`可以为`data2_admin`，接下来再根据`r.obj == p.obj && r.act == p.act`，最终找到匹配的授权policy规则为`p, data2_admin, data2, read`，最后根据`some(where (p.eft == allow))`规则，此时验证授权的结果就应该是`allow`。

这里`casbin`根据`r.sub`查找对应`p.sub`的过程还会考虑角色继承。考虑以下授权policy文件：

```csv
p, reader, data2, read
p, writer, data2, write

g, admin, reader
g, admin, writer
g, alice, admin
```

现在收到了授权请求`alice, data2, read`，这时`r.sub`为`alice`，根据`g = _, _`及`g(r.sub, p.sub)`，我们可以得出对应的`p.sub`可以为`admin`，`reader`，`writer`，接下来再根据`r.obj == p.obj && r.act == p.act`，最终找到匹配的授权policy规则为`p, reader, data2, read`，最后根据`some(where (p.eft == allow))`规则，此时验证授权的结果就应该是`allow`。

通过`[role_definition]`还可以定义resource-role之间的映射关系，见[示例](https://github.com/casbin/casbin/blob/master/examples/rbac_with_resource_roles_model.conf)。

`casbin`的模型大概就是上面描述的了，很多概念理解起来可能比较费劲，结合示例及在[editor](https://casbin.org/en/editor)上做些实验应该理解得更快一些。

## casbin相关事项

1. `casbin`的模型定义及授权policy定义还可以选择保存在其它存储中，见[Model Storage](https://casbin.org/docs/en/model-storage)、[Policy Storage](https://casbin.org/docs/en/policy-storage)、[Adapters](https://casbin.org/docs/en/adapters)。

2. `casbin`的`Enforcer`对象还提供了一系列API接口管理授权policy规则，见[Management API](https://casbin.org/docs/en/management-api)、[RBAC API](https://casbin.org/docs/en/rbac-api)。

3. 可以修改授权policy规则，那么当多个验证授权服务分布式部署时，必然要考虑某个服务修改了授权规则后，其它服务示例必须进行规则的同步。`casbin`也考虑到了这个需求，提供了Watchers机制，用于在观察到授权规则发生变更时进行必要的回调，见[Watchers](https://casbin.org/docs/en/watchers)。

4. 在多线程环境下使用`Enforcer`对象的接口，必须使用`casbin.NewSyncedEnforcer`创建`Enforcer`，另外还支持授权policy`AutoLoad`特性，见[这里](https://casbin.org/docs/en/multi-threading)。

5. `casbin`默认是从授权policy文件中加载角色及角色的继承信息的，也可以从其它外部数据源获取这些信息，见[这里](https://casbin.org/docs/en/role-managers)。

## casbin代码分析

`casbin`整体代码很简单，很多代码都是模型定义及授权policy定义加载的逻辑，关键代码只有一个方法[Enforce](https://github.com/casbin/casbin/blob/master/enforcer.go#L329)，见下面：

```go
	if !e.enabled {
		return true, nil
	}

	functions := make(map[string]govaluate.ExpressionFunction)
	for key, function := range e.fm {
		functions[key] = function
	}
	if _, ok := e.model["g"]; ok {
		for key, ast := range e.model["g"] {
			rm := ast.RM
			functions[key] = util.GenerateGFunction(rm)
		}
	}

	expString := e.model["m"]["m"].Value
	expression, err := govaluate.NewEvaluableExpressionWithFunctions(expString, functions)
	if err != nil {
		return false, err
	}

	rTokens := make(map[string]int, len(e.model["r"]["r"].Tokens))
	for i, token := range e.model["r"]["r"].Tokens {
		rTokens[token] = i
	}
	pTokens := make(map[string]int, len(e.model["p"]["p"].Tokens))
	for i, token := range e.model["p"]["p"].Tokens {
		pTokens[token] = i
	}

	parameters := enforceParameters{
		rTokens: rTokens,
		rVals:   rvals,

		pTokens: pTokens,
	}
  if policyLen := len(e.model["p"]["p"].Policy); policyLen != 0 {
		policyEffects = make([]effect.Effect, policyLen)
		matcherResults = make([]float64, policyLen)
		if len(e.model["r"]["r"].Tokens) != len(rvals) {
			return false, errors.New(
				fmt.Sprintf(
					"invalid request size: expected %d, got %d, rvals: %v",
					len(e.model["r"]["r"].Tokens),
					len(rvals),
					rvals))
		}
		for i, pvals := range e.model["p"]["p"].Policy {
			// log.LogPrint("Policy Rule: ", pvals)
			if len(e.model["p"]["p"].Tokens) != len(pvals) {
				return false, errors.New(
					fmt.Sprintf(
						"invalid policy size: expected %d, got %d, pvals: %v",
						len(e.model["p"]["p"].Tokens),
						len(pvals),
						pvals))
			}

			parameters.pVals = pvals

			result, err := expression.Eval(parameters)
			// log.LogPrint("Result: ", result)

			if err != nil {
				return false, err
			}

			switch result := result.(type) {
			case bool:
				if !result {
					policyEffects[i] = effect.Indeterminate
					continue
				}
			case float64:
				if result == 0 {
					policyEffects[i] = effect.Indeterminate
					continue
				} else {
					matcherResults[i] = result
				}
			default:
				return false, errors.New("matcher result should be bool, int or float")
			}

			if j, ok := parameters.pTokens["p_eft"]; ok {
				eft := parameters.pVals[j]
				if eft == "allow" {
					policyEffects[i] = effect.Allow
				} else if eft == "deny" {
					policyEffects[i] = effect.Deny
				} else {
					policyEffects[i] = effect.Indeterminate
				}
			} else {
				policyEffects[i] = effect.Allow
			}

			if e.model["e"]["e"].Value == "priority(p_eft) || deny" {
				break
			}

		}
	}
```

这个代码逻辑很清楚了，就是根据`[matchers]`、`[request_definition]`、`[policy_definition]`找到匹配的`[policy_definition]`，再根据`[policy_effect]`最后得出最终的验证授权结果。可以看到该处理逻辑里大量地遍历了`e.model["r"]["r"].Tokens`、`e.model["p"]["p"].Tokens`、`e.model["p"]["p"].Policy`，当授权policy规则条数较多时，估计性能不会太好。但官方给了个[性能测试报告](https://casbin.org/docs/en/benchmark)，据说性能还可以，这个后面还须再验证下。

为了优化性能，其实是可以将验证授权操作的结果进行缓存，官方也提供了[CachedEnforcer](https://github.com/casbin/casbin/blob/master/enforcer_cached.go)，目测逻辑没问题，如果确实遇到性能瓶颈，可以考虑采用。

## 其它外部支援

一些开源爱好者为`casbin`贡献了[很多中间件组件](https://casbin.org/docs/en/middlewares)，便于在多个编程语言中集成`casbin`进行权限验证。

还有一些开源爱好者为`casbin`贡献了[模型管理及授权策略管理的web前端](https://casbin.org/docs/en/admin-portal)，如果觉得手工修改授权策略文件不直观的话，可以考虑采用。

还可以看到目前[很多开源项目](https://casbin.org/docs/en/adopters)的权限验证部分都是采用了`casbin`来实现的，例如[harbor里的rbac权限验证](https://github.com/goharbor/harbor/tree/master/src/common/rbac)。

还发现一个基于`casbin`实现的身份认证及验证授权服务，[这个例子](https://github.com/Soontao/go-simple-api-gateway)以后可以好好参考一下。

自己研究`casbin`的[示例项目](https://github.com/jeremyxu2010/demo-casbin)。

## 参考

1. https://github.com/isayme/blog/issues/34
2. https://www.jianshu.com/p/b078abe9534f
3. https://casbin.org/docs/en/overview
4. https://casbin.org/docs/en/supported-models
5. https://casbin.org/docs/en/syntax-for-models
6. https://casbin.org/docs/en/rbac
7. https://casbin.org/docs/en/model-storage
8. https://casbin.org/docs/en/policy-storage
9. https://casbin.org/docs/en/adapters
10. https://casbin.org/docs/en/management-api
11. https://casbin.org/docs/en/rbac-api
12. https://casbin.org/docs/en/watchers
13. https://casbin.org/docs/en/role-managers
14. https://github.com/casbin/casbin
15. https://casbin.org/docs/en/benchmark
16. https://casbin.org/docs/en/middlewares
17. https://casbin.org/docs/en/admin-portal
18. https://casbin.org/docs/en/adopters
19. https://github.com/Soontao/go-simple-api-gateway
