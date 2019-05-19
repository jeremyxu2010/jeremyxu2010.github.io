---
title: 批量处理docker镜像
author: Jeremy Xu
tags:
  - bash
  - docker
categories:
  - 工具
date: 2017-05-19 18:00:00+08:00
---

这几天的工作频繁地操作大量docker镜像，这里总结一些过程中的小技巧。

## 小技巧

### 列出registry中的镜像

官方的docker registry虽然提供了一系列操作镜像的Restful API，但查看镜像列表并不直观，于是可以使用以下脚本查看registry中的镜像列表：

```bash
DOCKER_REGISTRY_ADDR=127.0.0.1:5000

for img in `curl -s ${DOCKER_REGISTRY_ADDR}/v2/_catalog | python -m json.tool | jq ".repositories[]" | tr -d '"'`; do
  for tag in `curl -s 10.10.30.21:5000/v2/${img}/tags/list|jq ".tags[]" | tr -d '"'`; do
    echo $img:$tag
  done
done
```

### 删除registry中的某个镜像

docker registry上的镜像默认是不允许删除的，如要删除，需要在启动docker registry时指定环境变量`REGISTRY_STORAGE_DELETE_ENABLED=true`，然后可以利用以下脚本删除镜像：

```bash
DOCKER_REGISTRY_ADDR=127.0.0.1:5000

function delete_image {
    imgFullName=$1
    img=`echo $imgFullName | awk -F ':' '{print $1}'`
    tag=`echo $imgFullName | awk -F ':' '{print $2}'`
    
    # delete image's blobs
    for digest in `curl -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -s ${DOCKER_REGISTRY_ADDR}/v2/${img}/manifests/${tag} | jq ".layers[].digest" | tr -d '"'`; do
      curl -X DELETE ${DOCKER_REGISTRY_ADDR}/v2/${img}/blobs/${digest}      
    done
    
    # delete image's manifest
    imgDigest=`curl -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -s ${DOCKER_REGISTRY_ADDR}/v2/${img}/manifests/${tag} | jq ".config.digest" | tr -d '"'`
    curl -X DELETE ${DOCKER_REGISTRY_ADDR}/v2/${img}//manifests/${imgDigest}
}
```

### 修改镜像的名字

一般手工用`docker tag`命令改镜像名字，一两个镜像这么做还行，如要批量操作，还是需要用脚本：

```bash
pulledImageName=127.0.0.1:5000/test/testdb/db:v1.0.0

# 只取不包含127.0.0.1:5000的镜像名
shortImageName=${pulledImageName#*/}

# 将repository的前缀修改为test2
changedShortImageName=${shortImageName/#test/test2}

# 将tag修改为1.0.0
changed2ShortImageName=${changedShortImageName/%v1.0.0/1.0.0}

docker tag $pulledImageName $changed2ShortImageName
```

### 列出kubernetes中目前使用到的镜像

有时需要列出Kubernetes中目前使用到的所有镜像，可以用以下脚本：

```bash
for img in `kubectl get pod -o yaml --all-namespaces | grep 'image:' | cut -c14- | sort | uniq`; do
   echo $img
   # save image to tar file
   save_dir=${img%/*}
   mkdir -p $save_dir
   docker save -o ${img}.tar ${img}
done
```

### 建个远程隧道

在家工作，需要建个隧道连到远程服务器上去，可使用以下命令：

```bash
# Make PubkeyAuthentication enabled
ssh-copy-id root@${remote_ip}

# make tunnel with autossh
autossh -f -M 34567 -ND 7070 root@${remote_ip}

# use web browser with Socks 5 Proxy Server 127.0.0.1:7070 
```

## 参考

1. <https://docs.docker.com/registry/spec/api/>
2. <https://www.jianshu.com/p/6a7b80122602>
3. <https://www.cnblogs.com/chengmo/archive/2010/10/02/1841355.html>
4. <https://www.cnblogs.com/eshizhan/archive/2012/07/16/2592902.html>