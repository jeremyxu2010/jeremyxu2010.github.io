---
title: 给tomcat7配置SSL证书
author: Jeremy Xu
tags:
  - java
  - ssl
  - tomcat
categories:
  - java开发
date: 2016-11-07 22:31:00+08:00
---
今天工作中需要给tomcat7配置SSL证书，以使用https访问tomcat服务。以前都是自签名，照着网上的文档完成的，这回有一点不同的是https证书已经从GoDaddy买回来了，配置过程中遇到了一点坑，这里记录一下。

## tomcat7配置SSL证书

从GoDaddy买来的证书包括3个文件，test.com.key, test.com.crt, godaddy_intermediate.crt。这里稍微解释一下，这3个文件。

test.com.key是私钥文件，文件内容如下：

```
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

test.com.crt是私钥对应的证书，文件内容如下：

```
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

godaddy_intermediate.crt是GoDaddy的一些中级证书，内容如下：

```
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

在网上查了下，需要先根据这3个文件生成p12文件，命令如下：

```bash
openssl pkcs12 -export -inkey test.com.key -in test.com.crt -chain -CAfile godaddy_intermediate.crt -out tomcatserver.p12 -name tomcatserver -passout pass:123456
```

不过我执行这行命令时，报错了：

```
Error unable to get issuer certificate getting chain.
```

又到处查阅文档，发现需要将`Go_Daddy_Class_2_CA.pem`与`godaddy_intermediate.crt`合并，得到`ca_bundle.crt`，以保证CA链可以到达根证书颁发节点，到处都是坑啊。

```bash
cat /etc/ssl/certs/Go_Daddy_Class_2_CA.pem godaddy_intermediate.crt > ca_bundle.crt
```

然后再执行上面的命令，p12文件就生成好了。

```bash
openssl pkcs12 -export -inkey test.com.key -in test.com.crt -chain -CAfile ca_bundle.crt -out tomcatserver.p12 -name tomcatserver -passout pass:123456
```

用portecle打开看一下，这个KeyPair的证书详情表明CA链上确实有4个证书。

![p12_portecle_open.png](/images/20161107/p12_portecle_open.png)

再将p12的keystore转化为jks的keystore。

```bash
keytool -importkeystore -v  -srckeystore tomcatserver.p12 -srcstoretype pkcs12 -srcstorepass 123456 -destkeystore tomcatserver.jks -deststoretype jks -deststorepass 123456
```

这样就得到了jks格式的keystore文件tomcatserver.jks。

最后在tomcat7的server.xml修改配置。

```xml
<Connector
           protocol="org.apache.coyote.http11.Http11NioProtocol"
           port="8443" maxThreads="200"
           scheme="https" secure="true" SSLEnabled="true"
           keystoreFile="/somewhere/tomcatserver.jks" keystorePass="123456"
           clientAuth="false" sslProtocol="TLS"/>
```

Over!

## 申请SSL证书的通用步骤

上一节的步骤有些曲折，仔细研究了下，发现如果按一定步骤从头来申请SSL证书，还是比较简单的。

* 生成私钥文件`www.test.com.key`
```bash
openssl genrsa -out www.test.com.key 2048
```
* 生成证书请求文件`www.test.com.csr`，下次证书过期了，还是同样方法生成一个新的证书请求文件

```bash
openssl req -new -sha256 -subj "/C=CN/ST=ProvinceName/L=CityName/O=OrgName/OU=OrgUnitName/CN=www.test.com" -key www.test.com.key -out www.test.com.csr
```

* 到SSL证书提供商那里填写在线申请表，并提交`www.test.com.csr`文件，提交申请
* SSL证书提供商证书审核通过后，将得到`ca_bundle.crt`与`www.test.com.crt`，于是就有这三个文件：`www.test.com.key`、`www.test.com.crt`、`ca_bundle.crt`
* 用上述3个文件生成p12文件

```bash
openssl pkcs12 -export -inkey www.test.com.key -in www.test.com.crt -chain -CAfile ca_bundle.crt -out tomcatserver.p12 -name tomcatserver -passout pass:123456
```

* 将p12文件转换为jks文件

```bash
keytool -importkeystore -v  -srckeystore tomcatserver.p12 -srcstoretype pkcs12 -srcstorepass 123456 -destkeystore tomcatserver.jks -deststoretype jks -deststorepass 123456
```

## 参考

`http://www.oschina.net/question/2266279_221175`
`http://www.fourproc.com/2010/06/23/create-a-ssl-keystore-for-a-tomcat-server-using-openssl-.html`
`https://sg.godaddy.com/zh/help/tomcat-4x5x6x-renew-a-certificate-5355`
`https://tomcat.apache.org/tomcat-7.0-doc/ssl-howto.html`
