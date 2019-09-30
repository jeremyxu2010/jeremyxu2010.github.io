---
title: 生成多平台docker镜像
tags:
  - docker
  - buildx
  - arm64
categories:
  - 容器编排
date: 2019-09-30 20:35:00+08:00
---



工作中需要在一台x86服务器从写好的golang程序源码生成`linux/amd64`、`linux/arm64` docker镜像，查阅了下资料，这里记录一下操作过程。

## 安装docker

查阅[docker官方文档](https://docs.docker.com/buildx/working-with-buildx/#build-multi-platform-images)，需要使用[buildx](https://github.com/docker/buildx)，而Docker 19.03版本已经捆绑了buildx，方便起见，这里就直接使用19.03版本的docker了，过程如下：

```bash
$ sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
                  
$ sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
  
$ sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# 列一下可安装的docker版本
$ yum list docker-ce --showduplicates | sort -r

# 安装19.03.2版本的docker
$ sudo yum install docker-ce-19.03.2 docker-ce-cli-19.03.2 containerd.io

# 启动docker服务
$ systemctl start docker
```

## 安装qemu-user-static

为了让在x86上可以运行arm64的docker镜像，这里需要安装[qemu-user-static](https://github.com/multiarch/qemu-user-static)，过程如下：

```bash
$ docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

## 创建构建多平台docker镜像的构建器

首先打开docker-cli的`experimental`开关：

```bash
$ mkdir ~/.docker
$ cat << EOF > ~/.docker/config.json
{
  "experimental": "enabled"
}
EOF
```

创建并启动构建器：

```bash
# 创建构建器
$ docker buildx create --name builder --node default --use
# 启动构建器
$ docker buildx inspect builder --bootstrap
# 观察下当前使用的构建器及构建器支持的cpu架构，可以看到支持很多cpu架构
$ docker buildx ls
```

## 编写脚本生成多平台docker镜像

假设有一个普通的golang程序源码，我们已经写好了Dockerfile生成其docker镜像，如下：

```dockerfile
# Start from the latest golang base image
FROM golang:latest as go-builder

# Add Maintainer Info
LABEL maintainer="Jeremy Xu <jeremyxu2010@gmail.com>"

# Set the Current Working Directory inside the container
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download all dependencies. Dependencies will be cached if the go.mod and go.sum files are not changed
RUN go mod download

# Copy the source from the current directory to the Working Directory inside the container
COPY ./cmd ./cmd

# Build the Go app
RUN go build -o output/demo ./cmd

# Start from the latest alpine base image
FROM alpine:latest

# Set the Current Working Directory inside the container
WORKDIR /app

# Copy execute file from go-builder
COPY --from=go-builder /app/output/demo /app/demo

# Set docker image command
CMD [ "/app/demo" ]
```

那么现在只需要使用两条命令，即可生成`linux/amd64`、`linux/arm64` docker镜像，如下：

```bash
# 生成linux/amd64 docker镜像
$ docker buildx build --rm -t go-mul-arch-build:latest-amd64 --platform=linux/amd64 --output=type=docker .
# 生成linux/arm64 docker镜像
$ docker buildx build --rm -t go-mul-arch-build:latest-arm64 --platform=linux/arm64 --output=type=docker .
```

最后检查下生成的docker镜像：

```bash
# 运行下linux/amd64的docker镜像，检查镜像的cpu架构
$ docker run --rm -ti go-mul-arch-build:latest-amd64 sh
/app # ./demo
Hello world!
oh dear
/app # uname -m
x86_64
/app # exit

# 运行下linux/arm64的docker镜像，检查镜像的cpu架构
$ docker run --rm -ti go-mul-arch-build:latest-arm64 sh
/app # ./demo
Hello world!
oh dear
/app # uname -m
aarch64
/app # exit
```

本操作指引中涉及的示例代码、脚本见[github项目](https://github.com/jeremyxu2010/go-mul-arch-build)。

Done.

## 参考

1. https://docs.docker.com/install/linux/docker-ce/centos/
2. https://docs.docker.com/buildx/working-with-buildx/#build-multi-platform-images
3. https://github.com/docker/buildx
4. https://github.com/multiarch/qemu-user-static
5. https://www.callicoder.com/docker-golang-image-container-example/
6. https://github.com/docker/buildx/issues/138