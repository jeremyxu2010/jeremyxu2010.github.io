---
title: 使用docker in docker
author: Jeremy Xu
tags:
  - docker
  - golang
categories:
  - 云计算
date: 2019-02-24 19:00:00+08:00
---

工作中需要在容器里操作docker镜像，而且又不想污染宿主机上的docker镜像，找到了docker in docker(dind)的方案，这里记录一下。

## 容器里用dind

首先直接用docker容器作试验，试验一下功能：

```bash
# 启动docker in docker
docker run --privileged -v `pwd`/ca.crt:/etc/docker/certs.d/myregistrydomain.com/ca.crt -d --name dockerd docker:stable-dind --registry-mirror=https://myregistrydomain.com

# 在另一个容器里拉取镜像，从输出来看，拉取镜像是成功了的
docker run --rm --link dockerd:docker docker:stable docker pull busybox:latest

# 在宿主机上检查，并没有看到拉取的镜像，说明没有污染宿主机的docker镜像
docker images | grep busybox
```

使用还是比较简单的。

这里注意两点：

1. 为了拉取镜像加速，我这里使用了自己架设的docker registry服务，因此`dockerd`加了参数`--registry-mirror=https://myregistrydomain.com`。

2. 自己架设的docker registry服务使用的是自签名证书，因此参考[官方文档](https://docs.docker.com/registry/insecure/#use-self-signed-certificates)，还设置了自签名证书对应的ca证书`/etc/docker/certs.d/myregistrydomain.com/ca.crt`。

   在看官方文档时，发现文档上说[有些版本的docker需要设置在操作系统级别信任证书](https://docs.docker.com/registry/insecure/#docker-still-complains-about-the-certificate-when-using-authentication)，不过我目前还没遇到这种情况，这里稍微关注一下。

## k8s里使用dind

简单写个deployment的k8s描述文件：

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: docker-test
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: docker-test
    spec:
      containers:
        - name: dockerd
          image: 'docker:stable-dind'
          securityContext:
            privileged: true
          args: ["--registry-mirror=https://myregistrydomain.com"]
          volumeMounts:
          - name: cert-volume
            mountPath: /etc/docker/certs.d/myregistrydomain.com/
        - name: docker-cli
          image: 'docker:stable'
          env:
          - name: DOCKER_HOST
            value: tcp://127.0.0.1:2375
          command: ["/bin/sh"]
          args: ["-c", "docker info >/dev/null 2>&1; while [ $? -ne 0 ] ; do sleep 3; docker info >/dev/null 2>&1; done; docker pull library/busybox:latest; docker save -o busybox-latest.tar library/busybox:latest; docker rmi library/busybox:latest; while true; do sleep 86400; done"]
      volumes:
      - name: cert-volume
        configMap:
            name: registry-ca-cert
```

这里在pod里跑两个容器，其中一个dockerd，另外一个是使用docker命令的容器，这里注意两点：

1. 同样因为使用了私有的registry服务，而且证书是自签名的，dockerd容器要作一些配置
2. 因为两个container共享相同的网络空间，因此直接设置好`DOCKER_HOST`环境变量，`docker-cli`里就可以直接用docker命令了，因为不确定两个容器的启动顺序，这里用一段脚本做了个等待的处理`docker info >/dev/null 2>&1; while [ $? -ne 0 ] ; do sleep 3; docker info >/dev/null 2>&1; done;`

然后用`kubectl apply -f docker-test.yaml`把这个deployment部署起来，简单检查一下，一切正常。

## docker in docker的原理

docker in docker的原理还是比较简单的，可以参考[wrapdocker](https://github.com/jpetazzo/dind/blob/master/wrapdocker)源码，其实就是挂载cgroup、tmpfs、securityfs、cgroup的SUBSYS、关掉不需要的文件描述符、最后启动dockerd。[wrapdocker](https://github.com/jpetazzo/dind/blob/master/wrapdocker)源码里注释写得比较清楚。

## 用golang语言操作dockerd

运维时用docker命令来操作dockerd还是比较好的，但有时希望以编程的方式操作dockerd，这时docker的sdk就派上用场了，可以参考[官方文档](https://docs.docker.com/develop/sdk/)和[示例](https://docs.docker.com/develop/sdk/examples/)。

```go
package main

import (
    "context"
    "os"
    "time"

    "github.com/docker/docker/client"
    "github.com/docker/docker/api/types"
    "github.com/docker/docker/api/types/container"
    "github.com/docker/docker/pkg/stdcopy"
)

func main() {
    ctx := context.Background()
    cli, err := client.NewClientWithOpts(client.FromEnv)
    if err != nil {
        panic(err)
    }
    cli.NegotiateAPIVersion(ctx)

    reader, err := cli.ImagePull(ctx, "docker.io/library/alpine", types.ImagePullOptions{})
    if err != nil {
        panic(err)
    }
    io.Copy(os.Stdout, reader)
    
    // sleep for a while before using pulled new image
    time.Sleep(2 * time.Second)

    resp, err := cli.ContainerCreate(ctx, &container.Config{
        Image: "alpine",
        Cmd:   []string{"echo", "hello world"},
    }, nil, nil, "")
    if err != nil {
        panic(err)
    }

    if err := cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
        panic(err)
    }

    statusCh, errCh := cli.ContainerWait(ctx, resp.ID, container.WaitConditionNotRunning)
    select {
    case err := <-errCh:
        if err != nil {
            panic(err)
        }
    case <-statusCh:
    }

    out, err := cli.ContainerLogs(ctx, resp.ID, types.ContainerLogsOptions{ShowStdout: true})
    if err != nil {
        panic(err)
    }

    stdcopy.StdCopy(os.Stdout, os.Stderr, out)
}
```

这里要注意，刚pull下来的镜像要稍微等一下才可以使用，否则会报错，开发中踩到这个坑了，花了些时间才搞清楚原来是这个原因。

## 参考

1. https://hub.docker.com/_/docker/
2. https://docs.docker.com/registry/insecure/#use-self-signed-certificates
3. https://github.com/jpetazzo/dind
4. https://www.docker-cn.com/registry-mirror
5. https://docs.docker.com/develop/sdk/
6. https://docs.docker.com/develop/sdk/examples/