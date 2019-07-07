---
title: 完善cni的ipam方案
author: Jeremy Xu
tags:
  - k8s
  - devops
  - cni
categories:
  - 容器编排
date: 2019-07-07 14:00:00+08:00
typora-root-url: ../../../static
typora-copy-images-to: ../../../static/images/20190707
---

上两周，为了优化k8s的网络性能，最终选择了`macvlan+ptp`方案，最终性能也达到标准了。但其实存在一个问题，macvlan的pod的IP其实不太好分配。

### 原来ip分配的问题

原来的方案直接使用官方的`host-local`进行IP分配，虽然很稳定，但不同的node节点需要配置一个不重叠的网段，最终需要底层网络预先分配一个比较大的网段作为macvlan的地址范围。而在很多私有部署场景，一般只会给一个24位前缀的网段，如果采用`host-local`进行IP分配，每个node节点将得不到足够大的cidr。

## 集中式的ip分配

比较理想的方案是使用一个集中式的ip分配策略，各node节点从一个网段范围内按需申请pod的ip。集中式的ip分配方案比较多，官方本身就是`dhcp`的cni插件，另外也可以找一个集中存储（如consul, etcd），基于这个做集中式的cni插件。

本以为这个方案很简单，理论上业界上应该已经有现成方案了，但实际上在网上找了一圈，只找到[cni-ipam-consul](https://github.com/logingood/cni-ipam-consul)，而且代码都是3年前的，连编译都不成功。看来只能自行开发。

## 快速开发

为了减少依赖，最终计划开发一个`cni-ipam-etcd`，其直接采用kubernetes底层使用的etcd作为集中存储，存储ipam的ip分配信息。

其实`host-local`这个cni插件源代码架构比较好，它默认是使用本地文件存储ip分配信息的，只需要将这些逻辑修改为读写etcd就可以了。

参考上述思路，我快速完成了此cni插件的开发，源代码地址为[cni-ipam-etcd](https://github.com/jeremyxu2010/cni-ipam-etcd)。这里对etcd的读写代码参考[这里](https://enpsl.top/2019/01/05/2019-01-05-golang-etcd/)。

这个cni插件使用也比较简单，可配合常用的underlay网络cni插件使用，如下：

```json
{
	"name": "mymacvlan",
	"type": "macvlan",
	"master": "enp5s0f0",
	"ipam": {
		"name": "myetcd-ipam",
		"type": "etcd",
		"etcdConfig": {
			"etcdURL": "https://10.10.20.152:2379",
			"etcdCertFile": "/etc/etcd/ssl/etcd.pem",
			"etcdKeyFile": "/etc/etcd/ssl/etcd-key.pem",
			"etcdTrustedCAFileFile": "/etc/kubernetes/ssl/ca.pem"
		},
		"subnet": "10.10.20.0/24",
		"rangeStart": "10.10.20.50",
		"rangeEnd": "10.10.20.70",
		"gateway": "10.10.20.254",
		"routes": [{
			"dst": "0.0.0.0/0"
		}]
	}
}
```

## 简化部署

当然手工登录到每个node节点部署上述配置很是简单的，但在k8s里我们可以使用daemonset快速完成cni插件的部署，deamonset的配置可参考如下yaml：

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-macvlan-cfg
  namespace: kube-system
  labels:
    tier: node
    app: macvlan
data:
  etcd.pem: |
    -----BEGIN CERTIFICATE-----
    MIID5DCCAsygAwIBAgIUB9cmzTIGNK2SINBAl9Cx284K6TowDQYJKoZIhvcNAQEL
    BQAwYjELMAkGA1UEBhMCQ04xEjAQBgNVBAgTCUd1YW5nRG9uZzELMAkGA1UEBxMC
    U1oxDDAKBgNVBAoTA2s4czEPMA0GA1UECxMGU3lzdGVtMRMwEQYDVQQDEwprdWJl
    cm5ldGVzMB4XDTE5MDQxNjIzMjYwMFoXDTI5MDQxMzIzMjYwMFowXDELMAkGA1UE
    BhMCQ04xEjAQBgNVBAgTCUd1YW5nRG9uZzELMAkGA1UEBxMCU1oxDDAKBgNVBAoT
    A2s4czEPMA0GA1UECxMGU3lzdGVtMQ0wCwYDVQQDEwRldGNkMIIBIjANBgkqhkiG
    9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz0avwoL3gTbLIjGURQi/8r+Np1A4ALLSR+KS
    ig4MA8nUYwO5WoU6+71nF83kpO9KnSr0YrsgXIYgI2u57AxR7WFMvPphGy9C+9Z0
    BHDk6LCciiYiZphoE6792WfUchHrRjBbiAJDvvpb2qEu6qY53c1KQkX7jLVjkHt5
    bMOBhY/Y33J4uCsokmPmFZ1GxtwV8wsXq/flWCbQ7dC9sMMO3JpNrG7/tiv+lQmv
    uPojcMUt/ZVnbRU+OXnlqljJDYLu2OqY0PPxXR9t9WpSpdesNQblwopTH+MzH0Ga
    yXY8BhvwuRkFHTpVIeYUraTFSokopL0XSSF9DDBUJ8E+QS1MEQIDAQABo4GXMIGU
    MA4GA1UdDwEB/wQEAwIFoDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIw
    DAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUJ9k4rVtGuz+bip/YgGpAftPH2I8wHwYD
    VR0jBBgwFoAUUHIr7PnnjCO6GEc0+wln7Pr2HnowFQYDVR0RBA4wDIcEfwAAAYcE
    CU0L7DANBgkqhkiG9w0BAQsFAAOCAQEAhSjef8eG8X6z8xZEPNHEACKRgsPP8Hmv
    AzxJ2TLAYjGQaM7TklRseHSxn7cAx4bwvHZtVPRrIgK5ylkm4QHGQfMYejWQnUzJ
    m0F5/3oXfDTA10muw4tGQu7njUKMsfHnvgokxMjk3xdPpy+WrBsFtmO/TRgypzle
    3MTXbWIFDPaxVRx1oBtIuTkYZjc1CHUMyuXQhWU8mZCoGqFpcYwfRjUtA6hWe8xJ
    7aDEnxpXkA4/ehuWTrl3QCSrg4NBXqufSy7V0Y+mErxC9996rYP80bR8gdGKUo65
    bWmgDT/c49TA96MGbepsZPbDdFVnr1g5jiJnXQSYDw1pdCxb5MsggQ==
    -----END CERTIFICATE-----
  etcd-key.pem: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEAz0avwoL3gTbLIjGURQi/8r+Np1A4ALLSR+KSig4MA8nUYwO5
    WoU6+71nF83kpO9KnSr0YrsgXIYgI2u57AxR7WFMvPphGy9C+9Z0BHDk6LCciiYi
    ZphoE6792WfUchHrRjBbiAJDvvpb2qEu6qY53c1KQkX7jLVjkHt5bMOBhY/Y33J4
    uCsokmPmFZ1GxtwV8wsXq/flWCbQ7dC9sMMO3JpNrG7/tiv+lQmvuPojcMUt/ZVn
    bRU+OXnlqljJDYLu2OqY0PPxXR9t9WpSpdesNQblwopTH+MzH0GayXY8BhvwuRkF
    HTpVIeYUraTFSokopL0XSSF9DDBUJ8E+QS1MEQIDAQABAoIBAQDEuAqhadjrGozJ
    xBI7PqWmBqSzMZAlIZIvRVrciZ5fjhLzchpdTer/9u88CV3CJ5VB+v18IqsBBQ7F
    bz1CSSMMTvcct+ine0BwcUUk3dxy9wNqneyyQF0uqTslNcTMCjOoJscIG1Yej8/T
    fHxhmSd8WZTrty2ZiqGXA4jnb9miXoEtpHW65kWq50qK/ElxRhqHrMn3TO06nr+w
    tB7kSnT2E6Bx5eXCzvKL+2DlUWlBjme9dSessg566i+3Ua5Zmc2/SY3aS69Wp+9a
    DHsdLAtpVh/sfO3GXLEzoGo0wcPEjtbeV9snSGfQDluzt2rf1lht9vPHpbOpKZIj
    F61E6H0tAoGBAOUPQURoW37W22S8rH3u6iO53CgfWfiyIOoOk3hVWmmjuGx53i5d
    v8+dHNNSc94kj7EH5EIcksKpdc6fh9mRrHwnsTs3Pa6OgvcqR2LUe0UlECJ714HX
    SSQGNnYwZ+NKyOk9BkRt6PdAyvS/om3VSn7w6tXqb9SJBjBSbyo8C/czAoGBAOen
    jdd7Zt8yREE/GRfYLGANBfwbNcFAz5vXxRg+943OGmiJMr5q/o+rg+ubB119maZI
    fHzFryN77ZLo8gcudaiu6fNE0AxP68N3m0dUcOSSoX15MjWX3MQRtv7kYklg3lCr
    5FpcXo/IIWTk5W8MgBUxrntPWjIeADkkbGGEwB+rAoGAajlA0zBx/cg1xemZNG1v
    N1IhvpmLZ8FzcheAW/V5EDRUejmpx2bCZM0/aOB7yzC5UieOuvn1NUDQ2RkyLrtX
    edwOXJ+pgyGjqmt432QaJl6htNwpfJUR3hrjdrvL8aPkuAUMuv8dYkwx0n5sHPMk
    sOmYfctSQQWqUQ5pbvSZt/ECgYEAydJPoGFxkZkQoCuh6AU9O/18rlTic1jMx0Co
    BWSudowOs+58GCvNVkwepcCuHQSVPaq/UlFEMc0BgVGTszAF8A1b48aa328tv2FQ
    Fkf6Bxm8uj1BwjFpdCTe4pkFDFrptSzcyODavbelaGqHfUVNvalIE0RiF3HNzfru
    tdNbMvsCgYACKftFa4UkHZjO8wEaTLpUOotJYRRaWcDxkuHSc+zOr2/X+Q6GI3k/
    r1hi51otQSHissiNcTBskpsVO8JJUye77q5igNI/6rnmT5lmqbZrYQK5J322jYxt
    IVlXiSSyuY6ZL8k4yc27XG5Petk0SZiEdItRLh2AC5z/8Pg8gHFlsQ==
    -----END RSA PRIVATE KEY-----
  etcd-ca.pem: |
    -----BEGIN CERTIFICATE-----
    MIIDuDCCAqCgAwIBAgIUK4+VweLZgPFnIBGYCxBAzDJ17pwwDQYJKoZIhvcNAQEL
    BQAwYjELMAkGA1UEBhMCQ04xEjAQBgNVBAgTCUd1YW5nRG9uZzELMAkGA1UEBxMC
    U1oxDDAKBgNVBAoTA2s4czEPMA0GA1UECxMGU3lzdGVtMRMwEQYDVQQDEwprdWJl
    cm5ldGVzMB4XDTE5MDIyMDA2NDEwMFoXDTI0MDIxOTA2NDEwMFowYjELMAkGA1UE
    BhMCQ04xEjAQBgNVBAgTCUd1YW5nRG9uZzELMAkGA1UEBxMCU1oxDDAKBgNVBAoT
    A2s4czEPMA0GA1UECxMGU3lzdGVtMRMwEQYDVQQDEwprdWJlcm5ldGVzMIIBIjAN
    BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAttiDwQyPK41fI8NgRjdF3AIr9P1U
    hBS0JFlEJ2UVDhQDfS+ns42r4IHGayWaydldlcFX7Xhg0qQAONLK+2p6fXojCDM6
    ZEARNnOuQGFaOfrihsukQsj6Zn3VSi8PgwcMJUzjiY932cOTcQM49J9LOz0QCp8E
    tQ+so6qE7Bl0om+ifRuq1+O5bGmCBb2EEQfgHeuluZ8LoyHhQEbI3qq9e3XtdyKm
    KO1BRk7Z/m24amoC72gxljKP2KV1oiCZj+VcpFwEPpmYaNp1We0jk7WgDXZUXBkE
    NqhC2/Y2sUQ5VWm0dOnCA6pE3Fq2C7krVxhOelKIxFzuV56AeCVxe8qKMQIDAQAB
    o2YwZDAOBgNVHQ8BAf8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIBAjAdBgNVHQ4E
    FgQUUHIr7PnnjCO6GEc0+wln7Pr2HnowHwYDVR0jBBgwFoAUUHIr7PnnjCO6GEc0
    +wln7Pr2HnowDQYJKoZIhvcNAQELBQADggEBAEwf+/Cy62uvp3DJIGubFP4AzKQL
    pbxJwjn+dsSJFJkIwSCJJJPVwtU8qPdwBS2UKJ1evFBvk+2uLyCKW1F6I5Ryc658
    E/dOXAPUP0cpA1vwdkNv7yFqBY9S7pm9q2BZEOfwbS5sTkRztwqP75DKEf8t9eq/
    9JnTEhs3tCUtv2uSKLbwGrT/lmPwT32Xn90tYbrasfr9bzS8qhAml8KnHyIs0/DB
    h+p5N0gSRODK+u/JwSdnlwwDiYzeKfo87RypNCJt7UsX6J3RK8GNJwSMy5s70XhS
    1C0s4RRsDT7dhRssPBCvsH6HHjrLUAM7hd1XBAdkjMDA4B8qDnjb+2fAKhs=
    -----END CERTIFICATE-----
  cni-conf.json: |
    {
        "name": "cni0",
        "cniVersion": "0.3.1",
        "plugins": [
            {
                "name": "mymacvlan",
                "type": "macvlan",
                "master": "enp5s0f0",
                "ipam": {
                    "name": "myetcd-ipam",
                    "type": "ipam-etcd",
                    "etcdConfig": {
                        "etcdURL": "https://10.10.20.152:2379",
                        "etcdCertFile": "/etc/cni/net.d/etcd.pem",
                        "etcdKeyFile": "/etc/cni/net.d/etcd-key.pem",
                        "etcdTrustedCAFileFile": "/etc/cni/net.d/etcd-ca.pem"
                    },
                    "subnet": "10.10.20.0/24",
                    "rangeStart": "10.10.20.50",
                    "rangeEnd": "10.10.20.70",
                    "gateway": "10.10.20.254",
                    "routes": [{
                        "dst": "0.0.0.0/0"
                    }]
                }
            },
            {
                "name": "ptp",
                "type": "veth-to-host",
                "hostInterface": "enp5s0f0",
                "containerInterface": "veth0",
                "ipMasq": true
            }
        ]
    }
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: kube-macvlan-ds
  namespace: kube-system
  labels:
    tier: node
    app: macvlan
spec:
  template:
    metadata:
      labels:
        tier: node
        app: macvlan
    spec:
      hostNetwork: true
      nodeSelector:
        beta.kubernetes.io/arch: amd64
      tolerations:
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      initContainers:
        - name: install-cni-binaries
          image: k8s-network:v1.0.0
          command:
            - sh
          args:
            - -c
            - cp -r /opt/cni/bin/* /host/opt/cni/bin/
          volumeMounts:
            - name: host-cni-bin
              mountPath: /host/opt/cni/bin
        - name: install-cni-cfg
          image: k8s-network:v1.0.0
          command:
            - cp
          args:
            - -f
            - /etc/kube-macvlan/cni-conf.json
            - /etc/cni/net.d/00-macvlan.conflist
          volumeMounts:
            - name: host-cni-cfg
              mountPath: /etc/cni/net.d
            - name: macvlan-cfg
              mountPath: /etc/kube-macvlan/
        - name: install-etcd-certs
          image: k8s-network:v1.0.0
          command:
            - sh
          args:
            - -c
            - cp -f /etc/kube-macvlan/etcd*.pem /etc/cni/net.d/
          volumeMounts:
            - name: host-cni-cfg
              mountPath: /etc/cni/net.d
            - name: macvlan-cfg
              mountPath: /etc/kube-macvlan/
      containers:
        - name: kube-macvlan
          image: k8s-network:v1.0.0
          resources:
            requests:
              cpu: "100m"
              memory: "50Mi"
            limits:
              cpu: "100m"
              memory: "100Mi"
          securityContext:
            privileged: true
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          volumeMounts:
            - name: run
              mountPath: /run
            - name: macvlan-cfg
              mountPath: /etc/kube-macvlan/
      volumes:
        - name: run
          hostPath:
            path: /run
        - name: host-cni-cfg
          hostPath:
            path: /etc/cni/net.d
        - name: macvlan-cfg
          configMap:
            name: kube-macvlan-cfg
        - name: host-cni-bin
          hostPath:
            path: /opt/cni/bin
```

假设提前将名为`macvlan`、`ipam-etcd`的cni插件二进制文件放入了`k8s-network:v1.0.0` 这个docker镜像中。

这样部署就很方便了，命令如下：

```bash
kubectl apply -f macvlan-dpl.yaml
```

## 总结

通过这两周的实践，基本完成了开发cni网络插件的一整套流程，算是又开启了一门技能。

## 参考

1. https://github.com/logingood/cni-ipam-consul
2. https://github.com/containernetworking/plugins/tree/master/plugins/ipam/host-local
3. https://enpsl.top/2019/01/05/2019-01-05-golang-etcd/