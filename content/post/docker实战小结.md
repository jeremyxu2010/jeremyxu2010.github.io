---
title: docker实战小结
tags:
  - docker
  - deployment
  - automation
categories:
  - devops
date: 2018-06-18 23:00:00+08:00
---

好长一段时间没有写博文了，最近的工作主要涉及docker及golang开发，这里输出两篇博文小结一下。

其实以前的工作也涉及过docker，只是没有记录总结下来，这次争取记录得完善一点，以备以后查阅。

## 安装docker环境

安装docker环境就不用再提了，直接参考官方文档就可以了，需要注意在中国境内玩docker，最好配好镜像加速器，可参考[这里](https://yeasy.gitbooks.io/docker_practice/install/mirror.html)。

## docker常用操作

### 获取镜像

```bash
docker pull centos
docker pull centos:6.7
docker pull ${inner_docker_hub_ip}/${hub_user}/${image_name}:${image_tag}
```
### 运行镜像

```bash
docker run -it --rm ubuntu bash
docker run -d ubuntu
docker run -d -p 80:80 nginx
docker run -d -v /tmp/data:/var/lib/mysql -p 3306:3306 mysql
```
### 操作镜像

```bash
docker image ls
docker image ls ${repository_name}
docker rmi ${image_id}
docker rmi -f ${image_id}
docker image prune
docker tag ${image_id} ${image_name}:${image_tag}
```
### 编译镜像

```bash
docker build --rm -t ${image_name}:${image_tag} ./Dockerfile
```
### 操作容器

```bash
docker ps
docker stop ${container_id}
docker start ${container_id}
docker logs ${container_id}
docker exec -it ${container_id} bash
selected_container_ids=$(docker ps | grep ${filter_word} | awk '{print $1}')
docker rm -f ${container_id}
```
### 推送镜像

```bash
docker tag ${image_name}:${image_tag} ${inner_docker_hub_ip}/${hub_user}/${image_name}:${image_tag}
docker login ${inner_docker_hub_ip}
docker push ${inner_docker_hub_ip}/${hub_user}/${image_name}:${image_tag}
```
## 编写Dockerfile

最近的工作还涉及编写一些镜像的Dockerfile文件，Dockerfile的语法比较简单，常用的大概是以下的指令

### ARG指令

```dockerfile
ARG  CODE_VERSION=latest
FROM base:${CODE_VERSION}
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#arg)。

### FROM指令

```dockerfile
FROM centos:6.7
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#from)。

### LABEL指令

```dockerfile
LABEL maintainer="SvenDowideit@home.org.au"
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#label)。

### COPY指令

```dockerfile
COPY package.json /usr/src/app/

COPY hom* /mydir/
COPY hom?.txt /mydir/
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#copy)。

### ADD指令

```dockerfile
ADD ubuntu-xenial-core-cloudimg-amd64-root.tar.gz /
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#add)。

### RUN指令

```dockerfile
RUN /bin/bash -c 'source $HOME/.bashrc; echo $HOME'
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#run)。

### EXPOSE指令

```dockerfile
EXPOSE 3306
EXPOSE 80/tcp
EXPOSE 80/udp
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#expose)。

### VOLUME指令

```dockerfile
VOLUME ["/data"]
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#volume)。

### WORKDIR指令

```dockerfile
WORKDIR /path/to/workdir
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#workdir)。

### USER指令

```dockerfile
USER mysql
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#user)。

### CMD指令

```dockerfile
CMD ["/usr/bin/wc","--help"]
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#cmd)。

### ENTRYPOINT指令

```dockerfile
CMD ["/usr/bin/wc","--help"]
```

可参考[这里](https://docs.docker.com/engine/reference/builder/#cmd)。

ENTRYPOINT指令与CMD指令共同作用时，实际效果比较复杂，可参考下面的表格：

> The table below shows what command is executed for different `ENTRYPOINT` / `CMD` combinations:
>
> |                                | No ENTRYPOINT              | ENTRYPOINT exec_entry p1_entry | ENTRYPOINT [“exec_entry”, “p1_entry”]          |
> | ------------------------------ | -------------------------- | ------------------------------ | ---------------------------------------------- |
> | **No CMD**                     | *error, not allowed*       | /bin/sh -c exec_entry p1_entry | exec_entry p1_entry                            |
> | **CMD [“exec_cmd”, “p1_cmd”]** | exec_cmd p1_cmd            | /bin/sh -c exec_entry p1_entry | exec_entry p1_entry exec_cmd p1_cmd            |
> | **CMD [“p1_cmd”, “p2_cmd”]**   | p1_cmd p2_cmd              | /bin/sh -c exec_entry p1_entry | exec_entry p1_entry p1_cmd p2_cmd              |
> | **CMD exec_cmd p1_cmd**        | /bin/sh -c exec_cmd p1_cmd | /bin/sh -c exec_entry p1_entry | exec_entry p1_entry /bin/sh -c exec_cmd p1_cmd |

还有一些指令`ONBUILD`、`HEALTHCHECK`、`ENV`不太常用，直接参考[官方文档](https://docs.docker.com/engine/reference/builder/)就可以了。

另外再附一个[Dockerfile最佳实践](https://yeasy.gitbooks.io/docker_practice/appendix/best_practices.html)。

## 编写docker-compose.yml

`docker-compose.yml`的编写也比较简单，参考下面的例子：

```yaml
version: '3'

services:
  web:
    build: .
    depends_on:
      - db
      - redis

  redis:
    image: redis

  db:
    image: postgres
```

简单扩展就可以了。下面说一下平时常用的一些指令关键字。

### build

指定 `Dockerfile` 所在文件夹的路径（可以是绝对路径，或者相对 docker-compose.yml 文件的路径）。 `Compose` 将会利用它自动构建这个镜像，然后使用这个镜像。**我比较少用到它，习惯于先生成好镜像，再直接使用镜像**

### depends_on

解决容器的依赖、启动先后的问题。以下例子中会先启动 `redis` `db` 再启动 `web`，如下面的例子：

```yaml
version: '3'

services:
  web:
    build: .
    depends_on:
      - db
      - redis

  redis:
    image: redis

  db:
    image: postgres
```
### env_file

从文件中获取环境变量，可以为单独的文件路径或列表。

如果通过 `docker-compose -f FILE` 方式来指定 Compose 模板文件，则 `env_file` 中变量的路径会基于模板文件路径。

如果有变量名称与 `environment` 指令冲突，则按照惯例，以后者为准。

```yaml
env_file: .env

env_file:
  - ./common.env
  - ./apps/web.env
  - /opt/secrets.env
```

环境变量文件中每一行必须符合格式，支持 `#` 开头的注释行。

```
# common.env: Set development environment
PROG_ENV=development
```
### expose

暴露端口，但不映射到宿主机，只被连接的服务访问。

仅可以指定内部端口为参数

```yaml
expose:
 - "3000"
 - "8000"
```
### extra_hosts

类似 Docker 中的 `--add-host` 参数，指定额外的 host 名称映射信息。

```yaml
extra_hosts:
 - "googledns:8.8.8.8"
 - "dockerhub:52.1.157.61"
```

会在启动后的服务容器中 `/etc/hosts` 文件中添加如下两条条目。

```
8.8.8.8 googledns
52.1.157.61 dockerhub
```
### image

指定为镜像名称或镜像 ID。如果镜像在本地不存在，`Compose` 将会尝试拉取这个镜像。

```yaml
image: ubuntu
image: orchardup/postgresql
image: a4bc65fd
```
### networks

配置容器连接的网络。

```yaml
version: "3"
services:

  some-service:
    networks:
     - some-network
     - other-network

networks:
  some-network:
  other-network:
```
### ports

暴露端口信息。

使用宿主端口：容器端口 `(HOST:CONTAINER)` 格式，或者仅仅指定容器的端口（宿主将会随机选择端口）都可以。

```yaml
ports:
 - "3000"
 - "8000:8000"
 - "49100:22"
 - "127.0.0.1:8001:8001"
```

*注意：当使用 HOST:CONTAINER 格式来映射端口时，如果你使用的容器端口小于 60 并且没放到引号里，可能会得到错误结果，因为 YAML 会自动解析 xx:yy 这种数字格式为 60 进制。为避免出现这种问题，建议数字串都采用引号包括起来的字符串格式。*

### volumes

数据卷所挂载路径设置。可以设置宿主机路径 （`HOST:CONTAINER`） 或加上访问模式 （`HOST:CONTAINER:ro`）。

该指令中路径支持相对路径。

```yaml
volumes:
 - /var/lib/mysql
 - cache/:/tmp/cache
 - ~/configs:/etc/configs/:ro
```

 完整的指令关键字列表见[这里](https://yeasy.gitbooks.io/docker_practice/compose/compose_file.html#compose-%E6%A8%A1%E6%9D%BF%E6%96%87%E4%BB%B6)。

## 运行整个容器项目

使用以下命令运行起整个容器项目：

```bash
docker-compose up -f ./docker_compose.yml -d
# 停止整个容器项目
# docker-compose down -f ./docker_compose.yml 
```

## 其它发现

整个容器项目做完后，在网上又找到一个官方给出的写可复用[docker-compose方案](https://github.com/docker/app)，简单看了下文档，貌似很简单：

```bash
# 生成docker-compose.yml文件
docker-app render
# 用生成的docker-compose.yml文件运行整个容器项目
docker-app render | docker-compose -f - up
# 生成docker-compose.yml时指定一些选项
docker-app render --set version=0.2.3 --set port=4567 --set text="hello production"
# 生成helm的Chart，这个很方便啊，有木有
docker-app helm
```

## 参考

1. https://yeasy.gitbooks.io/docker_practice
2. https://docs.docker.com/engine/reference/builder
3. https://github.com/docker/app