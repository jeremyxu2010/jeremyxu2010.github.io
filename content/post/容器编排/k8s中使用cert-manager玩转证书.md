---
title: k8s中使用cert-manager玩转证书
tags:
  - kubernetes
  - tls
categories:
  - 容器编排
date: 2018-08-26 12:30:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20180826
---

前几天写过一篇[k8s加入TLS安全访问](k8s加入TLS安全访问.md)，其中说到用`cfssl`之类的工具手动生成TLS证书，这样就可以轻松搞定站点的https访问了。理想是很美好，但实际操作时却很痛苦，主要有以下几点缺陷：

1. 如果k8s集群上部署的应用较多，要为每个应用的不同域名生成https证书，操作太麻烦。
2. 上述这些手动操作没有跟k8s的deployment描述文件放在一起记录下来，很容易遗忘。
3. 证书过期后，又得手动执行命令重新生成证书。

这样就迫切需要一个证书管理工具来完成以上需求。正好这几天浏览网站发现了[cert-manager](https://cert-manager.readthedocs.io/en/latest/index.html)，一个k8s原生的证书管理控制器。

> cert-manager is a native [Kubernetes](https://kubernetes.io/) certificate management controller. It can help with issuing certificates from a variety of sources, such as [Let’s Encrypt](https://letsencrypt.org/), [HashiCorp Vault](https://www.vaultproject.io/), a simple signing keypair, or self signed.
>
> It will ensure certificates are valid and up to date, and attempt to renew certificates at a configured time before expiry.

周末有一点时间正好研究一下。

## cert-manager的架构

![_images/high-level-overview.png](/images/20180826/high-level-overview.png)

上面是官方给出的架构图，可以看到cert-manager在k8s中定义了两个自定义类型资源：`Issuer`和`Certificate`。

其中`Issuer`代表的是证书颁发者，可以定义各种提供者的证书颁发者，当前支持基于`Letsencrypt`、`vault`和`CA`的证书颁发者，还可以定义不同环境下的证书颁发者。

而`Certificate`代表的是生成证书的请求，一般其中存入生成证书的元信息，如域名等等。

一旦在k8s中定义了上述两类资源，部署的`cert-manager`则会根据`Issuer`和`Certificate`生成TLS证书，并将证书保存进k8s的`Secret`资源中，然后在`Ingress`资源中就可以引用到这些生成的`Secret`资源。对于已经生成的证书，还是定期检查证书的有效期，如即将超过有效期，还会自动续期。

## 把玩一下

### 部署cert-manager

部署cert-manager还是比较简单的，直接用helm部署就可以了：

```bash
helm install \
    --name cert-manager \
    --namespace kube-system \
    stable/cert-manager
```

### 创建Issuer资源

由于我试验环境是个人电脑，不能被外网访问，因此无法试验`Letsencrypt`类型的证书颁发者，而`vault`貌似部署起来很是麻烦，所以还是创建一个简单的CA类型Issuer资源。

首先将根CA的key及证书文件存入一个secret中：

```bash
kubectl create secret tls ca-key-pair \
   --cert=ca.pem \
   --key=ca-key.pem \
   --namespace=kube-system
```

上述操作中的ca.pem,  ca-key.pem文件还是用`cfssl`命令生成的。

然后创建Issuer资源：

```bash
cat << EOF | kubectl create -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: ca-issuer
  namespace: kube-system
spec:
  ca:
    secretName: ca-key-pair
EOF
```

注意这里创建的资源类型是`ClusterIssuer`，这样这个证书颁发者就可以为整个集群中任意命名空间颁发证书。

关于`ClusterIssuer`与`Issuer`的区别可以查阅[这里](https://cert-manager.readthedocs.io/en/latest/getting-started/3-configuring-first-issuer.html)。

### 创建Certificate资源

然后创建Certificate资源：

```bash
cat << EOF | kubectl create -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: example-com
  namespace: kube-system
spec:
  secretName: example-com-tls
  issuerRef:
    name: ca-issuer
    # We can reference ClusterIssuers by changing the kind here.
    # The default value is Issuer (i.e. a locally namespaced Issuer)
    kind: ClusterIssuer
  commonName: example.com
  dnsNames:
  - example.com
  - www.example.com
EOF
```

稍等一会儿，就可以查询到cert-manager生成的证书secret：

```bash
> kubectl -n kube-system describe secret example-com-tls
Name:         example-com-tls
Namespace:    kube-system
Labels:       certmanager.k8s.io/certificate-name=example-com
Annotations:  certmanager.k8s.io/alt-names=example.com,www.example.com
              certmanager.k8s.io/common-name=example.com
              certmanager.k8s.io/issuer-kind=ClusterIssuer
              certmanager.k8s.io/issuer-name=ca-issuer

Type:  kubernetes.io/tls

Data
====
tls.crt:  2721 bytes
tls.key:  1679 bytes
```

然后就可以在`Ingress`资源里引用该`Secret`了，如下：

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
....
spec:
  tls:
  - hosts:
    - www.example.com
    secretName: example-com-tls
  rules:
    ...
```

### 使用建议

实际生产环境中使用cert-manager可以考虑以下建议：

1. 将CA的`Secret`及`Issuer`放在某个独立的命名空间中，与其它业务的命名空间隔离起来。
2. 如果是CA类型的`Issuer`，要记得定期更新根CA证书。
3. 如果服务可被公网访问，同时又不想花钱买域名证书，可以采用`Letsencrypt`类型的`Issuer`，目前支持两种方式验证域名的所有权，基于[DNS记录的验证方案](https://cert-manager.readthedocs.io/en/latest/tutorials/acme/dns-validation.html)和基于[文件的HTTP验证方案](https://cert-manager.readthedocs.io/en/latest/tutorials/acme/http-validation.html)。
4. `cert-manager`还提供`ingress-shim`方式，自动为`Ingress`资源生成证书，只需要在`Ingress`资源上打上一些标签即可，很方便有木有，详细可参考[这里](https://cert-manager.readthedocs.io/en/latest/reference/ingress-shim.html)。

## 总结

`cert-manager`要完成的功能不复杂，但恰好解决了原来比较麻烦的手工操作，因此还是带来的挺大价值的，所以说做产品功能不需要搞太高深的技术，只要解决刚需问题即可。

## 参考

1. https://cert-manager.readthedocs.io/en/latest/getting-started/2-installing.html
2. https://cert-manager.readthedocs.io/en/latest/tutorials/ca/creating-ca-issuer.html