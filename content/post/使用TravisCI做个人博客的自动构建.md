---
title: 使用TravisCI做个人博客的自动构建
author: Jeremy Xu
tags:
  - linux
  - TravisCI
categories:
  - devops
date: 2019-03-10 10:30:00+08:00
---

今天又有朋友问我，这个博客是怎么搭建的。在回答后，顺便重新申视了下博客的构建部署方式，发现还是有一些改进空间的，刚好今天有点时间，就把它优化一下。

## 现状

博客是基于hugo构建的，构建过程可参考[参考](https://jeremyxu2010.github.io/2016/04/%E5%BC%80%E5%8F%91%E8%80%85%E7%9A%84%E5%8D%9A%E5%AE%A2%E5%86%99%E4%BD%9C%E7%8E%AF%E5%A2%83/)，我基本每隔一段时间会写一篇markdown格式的博文。本来编译部署还是比较简单的，不过有段时间github在国内访问比较慢，于是想到做一个镜像站，因而编译部署过程稍微复杂一点了，我写了个脚本专门搞定这个事。

`deploy.sh`

```bash
#!/bin/bash
echo -e "\033[0;32mDeploying updates to Server...\033[0m"

mkdir -p public_gitee
hugo --baseURL https://jeremy-xu.oschina.io/ -d public_gitee
cd public_gitee
git init
git add .
msg="rebuilding site `date`"
git commit -m "$msg"
git remote add origin git@gitee.com:jeremy-xu/jeremy-xu.git
git push --force origin master:master
cd ..

mkdir -p public_github
hugo --baseURL https://jeremyxu2010.github.io/ -d public_github
cd public_github
git init
git add .
msg="rebuilding site `date`"
git commit -m "$msg"
git remote add origin git@github.com:jeremyxu2010/jeremyxu2010.github.io.git
git push --force origin master:master
cd ..
```

整个还是比较简单的，就是分别编译两个站点的静态页面文件，分别推送到不同的git仓库里去。

但在用的过程发现一些问题：

1. 换一台新电脑时，就是写个markdown文档，最好要部署，还得在本机安装hugo这类工具
2. 换一台新电脑时，需要在重新配置该电脑到github.com、gitee.com的SSH Keys

## 改进

有了以上缺陷，于是就想着是不是可以在云上自动构建部署，现在这类专门作CI的解决方案还挺多的。看到github上有不少现在都是用TravisCI作自动构建的，于是我也选择了这个。

在网上很轻松找到一个[范例](https://axdlog.com/zh/2018/using-hugo-and-travis-ci-to-deploy-blog-to-github-pages-automatically/)，我参考它就快速写了一个。

`.travis.yaml`

```yaml
# https://docs.travis-ci.com/user/deployment/pages/
# https://docs.travis-ci.com/user/reference/xenial/
# https://docs.travis-ci.com/user/languages/go/
# https://docs.travis-ci.com/user/customizing-the-build/

dist: xenial
language: go
go:
  - 1.11.x
env:
  - GO111MODULE=on
cache:
  directories:
  - "$HOME/.cache/go-build"
  - "$HOME/gopath/pkg/mod"
# before_install
# install - install any dependencies required
install:
- go get github.com/gohugoio/hugo
before_script:
- mkdir -p public_github 2> /dev/null
# script - run the build script
script:
- hugo --baseURL https://jeremyxu2010.github.io/ -d public_github
deploy:
- provider: pages
  skip-cleanup: true
  github-token: "$GITHUB_TOKEN" # Set in travis-ci.org dashboard, marked secure
  email: "$GITHUB_EMAIL" # Set in travis-ci.org dashboard, marked secure
  name: "$GITHUB_USERNAME" # Set in travis-ci.org dashboard, marked secure
  github-url: github.com
  repo: "$GITHUB_USERNAME/$GITHUB_USERNAME.github.io"
  target_branch: master
  verbose: true
  keep-history: false
  local-dir: public_github
  on:
    branch: master
```

这部署单个git站点确实没什么问题了，可我还想顺便把gitee也部署了。

于是很自然的是像下面这样改一下。

`.travis.yaml`

```yaml
# https://docs.travis-ci.com/user/deployment/pages/
# https://docs.travis-ci.com/user/reference/xenial/
# https://docs.travis-ci.com/user/languages/go/
# https://docs.travis-ci.com/user/customizing-the-build/

dist: xenial
language: go
go:
  - 1.11.x
env:
  - GO111MODULE=on
cache:
  directories:
  - "$HOME/.cache/go-build"
  - "$HOME/gopath/pkg/mod"
# before_install
# install - install any dependencies required
install:
- go get github.com/gohugoio/hugo
before_script:
- mkdir -p public_github 2> /dev/null
- mkdir -p public_gitee 2> /dev/null
# script - run the build script
script:
- hugo --baseURL https://jeremyxu2010.github.io/ -d public_github
- hugo --baseURL https://jeremy-xu.github.io/ -d public_gitee
deploy:
- provider: pages
  skip-cleanup: true
  github-token: "$GITHUB_TOKEN" # Set in travis-ci.org dashboard, marked secure
  email: "$GITHUB_EMAIL" # Set in travis-ci.org dashboard, marked secure
  name: "$GITHUB_USERNAME" # Set in travis-ci.org dashboard, marked secure
  github-url: github.com
  repo: "$GITHUB_USERNAME/$GITHUB_USERNAME.github.io"
  target_branch: master
  verbose: true
  keep-history: false
  local-dir: public_github
  on:
    branch: master
- provider: pages
  skip-cleanup: true
  github-token: "$GITEE_TOKEN" # Set in travis-ci.org dashboard, marked secure
  email: "$GITEE_EMAIL" # Set in travis-ci.org dashboard, marked secure
  name: "$GITEE_USERNAME" # Set in travis-ci.org dashboard, marked secure
  github-url: gitee.com
  repo: "$GITEE_USERNAME/$GITEE_USERNAME"
  target_branch: master
  verbose: true
  keep-history: false
  local-dir: public_gitee
  on:
    branch: master
```

可惜这样花报错，好像是[github-pages的deploy provider](https://docs.travis-ci.com/user/deployment/pages/)与gitee的[私人令牌](https://gitee.com/profile/personal_access_tokens)兼容性不太好，只能作罢。

想了下，还是决定gitee就用脚本部署吧，刚好travis有[script的deploy provider](https://docs.travis-ci.com/user/deployment/script)。

最终修改成下面的样子。

`.travis.yaml`

```yaml
# https://docs.travis-ci.com/user/deployment/pages/
# https://docs.travis-ci.com/user/reference/xenial/
# https://docs.travis-ci.com/user/languages/go/
# https://docs.travis-ci.com/user/customizing-the-build/

dist: xenial
language: go
go:
  - 1.11.x
env:
  - GO111MODULE=on
cache:
  directories:
  - "$HOME/.cache/go-build"
  - "$HOME/gopath/pkg/mod"
before_install:
- openssl aes-256-cbc -K $encrypted_e5acc89010f1_key -iv $encrypted_e5acc89010f1_iv -in .travis/travis.key.enc -out ~/.ssh/id_rsa -d
- chmod 600 ~/.ssh/id_rsa
# install - install any dependencies required
install:
- go get github.com/gohugoio/hugo
before_script:
- mkdir -p public_github 2> /dev/null
- mkdir -p public_gitee 2> /dev/null
# script - run the build script
script:
- hugo --baseURL https://jeremyxu2010.github.io/ -d public_github
- hugo --baseURL https://jeremy-xu.github.io/ -d public_gitee
deploy:
- provider: pages
  skip-cleanup: true
  github-token: "$GITHUB_TOKEN" # Set in travis-ci.org dashboard, marked secure
  email: "$GITHUB_EMAIL" # Set in travis-ci.org dashboard, marked secure
  name: "$GITHUB_USERNAME" # Set in travis-ci.org dashboard, marked secure
  repo: "$GITHUB_USERNAME/$GITHUB_USERNAME.github.io"
  target_branch: master
  verbose: true
  keep-history: false
  local-dir: public_github
  on:
    branch: master
- provider: script
  skip-cleanup: true
  script: bash .travis/deploy_to_gitee.sh
  on:
    branch: master
addons:
  ssh_known_hosts:
  - github.com
  - gitee.com
```

`deploy_to_gitee.sh`

```bash
#!/bin/bash
cd public_gitee
git config user.name "Jeremy Xu"
git config user.email "xxxx@gmail.com"
git init
git add .
msg="rebuilding site `date`"
git commit -m "$msg"
git remote add origin git@gitee.com:jeremy-xu/jeremy-xu.git
git push --force origin master:master
cd ..
```

注意，这里为了保护gitee的SSH Keys，参考[这里](https://zzde.me/2018/auto-deploy-hexo-blog-with-traivs-ci/)采用了Travis加密了SSH Key文件。

## 成果

以后可以不再受工具、环境的限制的限制，随时写篇markdown文推到github上的[blog_source](https://github.com/jeremyxu2010/blog_source)项目就可以了。github本身提供了直接新建文件、编辑文件的功能，甚至都可以直接在github站点上编辑就可以了，太酷了。

## 参考

1. https://axdlog.com/zh/2018/using-hugo-and-travis-ci-to-deploy-blog-to-github-pages-automatically/
2. https://docs.travis-ci.com/user/deployment
3. https://docs.travis-ci.com/user/deployment/script
4. https://docs.travis-ci.com/user/deployment/pages/
5. https://restic.net/blog/2018-09-02/travis-build-cache
6. https://zzde.me/2018/auto-deploy-hexo-blog-with-traivs-ci/