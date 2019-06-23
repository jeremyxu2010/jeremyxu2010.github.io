---
title: boot2docker中安装docker-compose
tags:
  - docker
categories:
  - 容器编排
date: 2017-01-29 02:20:00+08:00
---
boot2docker中未安装docker-compose，同时无法自动挂载我在宿主机上共享的目录。研究了下，终于找到办法了，记录如下：

```
sudo mkdir -p /var/lib/boot2docker/bin
sudo curl -sL https://github.com/docker/compose/releases/download/1.10.0/docker-compose-`uname -s`-`uname -m` -o /var/lib/boot2docker/bin/docker-compose
sudo chmod +x /var/lib/boot2docker/bin/docker-compose
sudo ln -sf /var/lib/boot2docker/bin/docker-compose /usr/local/bin/docker-compose

echo 'Writing to bootlocal.sh to make docker-compose available on every boot...'
cat <<SCRIPT | sudo tee -a /var/lib/boot2docker/bootlocal.sh > /dev/null
# docker-compose
sudo ln -sf /var/lib/boot2docker/bin/docker-compose /usr/local/bin/docker-compose

# automount SSDHOME
mountOptions='defaults,iocharset=utf8'
if grep -q '^docker:' /etc/passwd; then
        mountOptions="${mountOptions},uid=$(id -u docker),gid=$(id -g docker)"
fi
try_mount_share() {
        dir="$1"
        name="${2:-$dir}"

        mkdir -p "$dir" 2>/dev/null
        if ! mount -t vboxsf -o "$mountOptions" "$name" "$dir" 2>/dev/null; then
                rmdir "$dir" 2>/dev/null || true
                while [ "$(dirname "$dir")" != "$dir" ]; do
                        dir="$(dirname "$dir")"
                        rmdir "$dir" 2>/dev/null || break
                done

                return 1
        fi
        return 0
}
try_mount_share /SSDHOME 'SSDHOME'
SCRIPT
sudo chmod +x /var/lib/boot2docker/bootlocal.sh

```
