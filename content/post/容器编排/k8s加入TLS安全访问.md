---
title: k8s加入TLS安全访问
tags:
  - kubernetes
  - tls
categories:
  - 容器编排
date: 2018-08-12 12:30:00+08:00
---

以前外部访问k8s里的服务，都是直接以http方式进行的，缺少TLS安全，今天抽空把这块处理一下。

## 生成并信任自签名证书

首先这里生成自签名的服务器证书，官方介绍了`easyrsa`, `openssl` 、 `cfssl`三个工具，这里使用`cfssl`。

```bash
brew install -y cfssl
# 生成默认配置文件
cfssl print-defaults config > config.json
cfssl print-defaults csr > csr.json
# 生成自定义的config.json文件
cp config.json ca-config.json
# 生成ca和server的证书请求json文件
cp csr.json ca-csr.json
cp csr.json server-csr.json
```

编辑`ca-config.json`，内容如下：

```json
{
    "signing": {
        "default": {
            "expiry": "168h"
        },
        "profiles": {
            "k8s-local": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
```

编辑ca-csr.json，内容如下：

```json
{
    "CN": "k8s-local",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "GuangDong",
            "L": "Shenzhen",
            "O": "my self signed certificate",
            "OU": "self signed"
        }
    ]
}
```

编辑server-csr.json，内容如下：

```json
{
    "CN": "k8s.local",
    "hosts": [
        "127.0.0.1",
        "*.k8s.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "GuangDong",
            "L": "Shenzhen",
            "O": "my self signed certificate",
            "OU": "self signed"
        }
    ]
}
```

执行以下命令，生成CA证书及服务器证书

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem --config=ca-config.json -profile=k8s-local server-csr.json | cfssljson -bare server
```

这样就得到`ca.pem`，`server-key.pem`，`server.pem`三个证书文件，其中`ca.pem`是ca的证书，`server-key.pem`是服务器证书的密钥，`server.pem`是服务器证书。

用`Keychain Access`打开`ca.pem`文件，然后修改设置，信任该CA，如下图如示：

![image-20180812220958311](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180812220958311.png)

## 在k8s里使用自签名证书

创建默认的tls secret：

```bash
kubectl -n kube-system create secret tls default-tls-cert --key=server-key.pem --cert=server.pem
```

这里举例，现在有一个服务`k8s-dashboard`，它是以下面的方式部署进k8s的：

```bash
helm install --name=local-k8s-dashboard --namespace kube-system stable/kubernetes-dashboard
```

而该k8s集群已经部署了nginx-ingress-controller，使用的以下命令：

```bash
helm install --name local-nginx-ingress stable/nginx-ingress
```

这里就可以创建`k8s-dashboard`这个服务的ingress规则了，如下：

```bash
cat << EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/secure-backends: "true"
  name: k8s-dashboard-ingress
  namespace: kube-system
spec:
  tls:
  - hosts:
    - k8s-dashboard.k8s.local
    secretName: default-tls-cert
  rules:
  - host: k8s-dashboard.k8s.local
    http:
      paths:
      - backend:
          serviceName: local-k8s-dashboard-kubernetes-dashboard
          servicePort: 443
EOF
```

注意，这里因为`k8s-dashboard`这个服务本身是以https提供服务的，所以才加上了一些与ssl相关的`annotations`，如果只是普通http服务，则不需要这些`annotations`。

最后在chrome浏览器中就可以以`https://k8s-dashboard.k8s.local`访问`k8s-dashboard`服务了，而且浏览器地址栏是安全的绿色哦。

![image-20180812222040765](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180812222040765.png)

## 为何选nginx-ingress

在上述过程中对比了k8s里两个比较重要的ingress controller：[traefik-ingress](https://docs.traefik.io/configuration/backends/kubernetes/)和[nginx-ingress](https://kubernetes.github.io/ingress-nginx/)，比较起来，还是[nginx-ingress](https://kubernetes.github.io/ingress-nginx/)功能更强大，与k8s整合更好一些，看来有k8s官方维护支持果然很强大。

![image-20180812222558350](http://blog-images-1252238296.cosgz.myqcloud.com/image-20180812222558350.png)

[nginx-ingress](https://kubernetes.github.io/ingress-nginx/)的[用户指南](https://kubernetes.github.io/ingress-nginx/user-guide/)也写得很详细，以后可以多看看。

## 参考

1. https://kubernetes.io/docs/concepts/cluster-administration/certificates/
2. https://github.com/helm/charts/blob/master/stable/kubernetes-dashboard
3. https://github.com/helm/charts/tree/master/stable/nginx-ingress
4. https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx/examples/tls
5. https://docs.traefik.io/configuration/backends/kubernetes/