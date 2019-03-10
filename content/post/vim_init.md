---
title: 我的VIM配置
categories:
  - 工具
tags:
  - linux
  - vim
date: 2016-04-10 02:33:00+08:00
---
这个我自己的vim配置，以备我在一台全新的MAC电脑上恢复原来的vim配置

* 安装vim

```bash
brew install vim --with-lua
```

* 安装vundle

```bash
mkdir -p ~/.vim/bundle
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
```

* 克隆vim-config工程并进行vundle插件安装

```bash
git clone https://github.com:jeremyxu2010/vim-config.git
mv vim-config/vimrc ~/.vimrc
vim +BundleInstall +qall
```
