---
title: 现代Web开发教程系列_02
tags:
  - web
  - html5
  - javascript
categories:
  - web开发
date: 2016-04-16 23:38:00+08:00
---
## 引言

本文从一个很小的前端工程说起，慢慢推导出我目前多个项目前端实践的工程结构。

## 为Web前端项目建工程

Web工程需要建工程吗？不是建个目录就可以开搞的吗？你一定会这么问。但事实上面对越来越复杂的前端页面逻辑，真的有必要好好组织一下前端的代码结构。同时前端代码的依赖管理、编译方式真的需要考量一下。

```bash
mkdir -p demo1
cd demo1
npm install # 回答一系列回答后，一个npm工程就建好了
```

## 创建前端源代码目录及编译后产物目录

从Java带来的习惯，我是不习惯将源代码与编译后的产物放在一起的，还是分开一点好。

```bash
mkdir web-src #前端源代码目录
mkdir public #前端源代码编译后产物目录
```

## 来一个Hello World

在web-src目录下写一个JS版的hello world

web-src/js/demo1.js

```javascript
console.log('Hello World!');
```

## 写编译脚本

在demo1目录中执行命令安装webpack

```bash
npm install webpack --global #--global是安装到系统全局
npm install webpack --save-dev #--save-dev是安装到node_modules目录下，并修改package.json文件，添加此开发依赖
```

在demo1目录建一个webpack.config.js文件，在这里配置如何使用webpack编译。

webpack.config.js

```javascript
var webpack = require("webpack");

var output_options = {
    path: 'public',
    publicPath: '/demo1/',
    filename: 'js/[name].js',
    hotUpdateMainFilename: 'hot-update/[hash].hot-update.json',
    chunkFilename: 'js/chunks/[name].js',
    hotUpdateChunkFilename: 'hot-update/chunks/[id].[hash].hot-update.js',
};

var entries = {
    demo1 : __dirname + '/web-src/js/demo1.js'
};

var webpackConfig = {
    entry: entries,
    output: output_options
};

module.exports = webpackConfig;
```

这时在demo1目录下执行webpack命令，就会在public/js目录下生成编译后的js文件

```bash
webpack
```

你打开public/js/demo1.js一看，肯定吓一跳，就一个简单的hello world，怎么就编出这么大的文件，这个是脱裤子放屁。如果这个系列你继续看下去，你会发现这一些也是值得的。

## 生成html页面

光编出js文件，如果没法在浏览器里查看运行效果也是白搭，我不建议自己手工写html页面来引用生成的js文件，还是让webpack来做吧。

安装webpack生成html的插件

```bash
npm install html-webpack-plugin --save-dev
```

在web-src/html目录下创建html的模板文件

```html
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title><%= htmlWebpackPlugin.options.title || 'Webpack App'%></title>
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
    <meta name="renderer" content="webkit">
    <% for (var css in htmlWebpackPlugin.files.css) { %>
    <link href="<%= htmlWebpackPlugin.files.css[css] %>" rel="stylesheet">
    <% } %>
</head>
<body class="body-cls">
    <% for (var chunk in htmlWebpackPlugin.files.chunks) { %> <script src="<%= htmlWebpackPlugin.files.chunks[chunk].entry %>"></script> <% } %>
</body>
</html>
```

在webpack.config.js文件加入几行

``` javascript
...

var HtmlWebpackPlugin = require('html-webpack-plugin');

var createHtmlDef = function(opts){
    return new HtmlWebpackPlugin({
        title: 'demo1',
        filename: opts.path,
        template: 'web-src/html/base.html',
        chunks: opts.chunks,
        hash: true,
        inject: false
    });
};

var plugins_options = [
    createHtmlDef({path: 'demo1.html', chunks: ['demo1']})
];

var webpackConfig = {
    ...
    plugins: plugins_options,
    ...
};

...

```

然后在demo1目录下执行webpack命令，即完成编译

```bash
webpack
```

### 部署到nginx里

我本机安装了nginx，因此就直接把这个小demo部署到nginx里吧

```bash
ln -sf demo1/public /usr/local/var/www/demo1
```

最后在浏览器里访问`http://127.0.0.1/demo1/demo1.html`，打开chrome的控制台，应该就可以看到`Hello World`了。这么费劲才搞了个hello world, 确实很无聊，下篇我们在页面上做点好玩的。本篇[源代码地址](https://github.com/jeremyxu2010/web_dev/tree/master/demo1)。

### webpack的一些概念

本篇里出现了不少webpack的概念，这里简单介绍一下，详细的可以参考[官方文档](http://webpack.github.io/docs/)

webpack里有三个概念：入口文件（entry），分块（chunk），模块（module）。

module指各种资源文件，如js、css、图片、svg、scss、less等等，一切资源皆被当做模块。

chunk：包含一个或者多个资源，必须可以被其它资源用require依赖。

entry：入口，也是包含了一个或者多个资源，它是一种特殊的chunk，不是一定得能被其它资源依赖，通常是使用html标签直接引入到页面里的。

比如本篇中项目执行webpack命令的输出如下

```
Hash: 7bd5b3403fe5f918821c
Version: webpack 1.13.0
Time: 528ms
      Asset       Size  Chunks             Chunk Names
js/demo1.js    1.42 kB       0  [emitted]  demo1
 demo1.html  318 bytes          [emitted]
   [0] ./web-src/js/demo1.js 29 bytes {0} [built]
Child html-webpack-plugin for "demo1.html":
        + 3 hidden modules
```

这里可以看到entry里配置的名称为`demo1`的entry生成了一个同名的chunk, 该chunk的编号为`0`，该chunk最后编译生成了`js/demo1.js`。而通过`HtmlWebpackPlugin`插件生成了`demo1.html`，该插件的配置里写明了生成的html页面需要引入名称为`demo1`的chunk，因此最后生成的html页面里就用script标签引入了`js/demo1.js`，并且由于`hash: true`，引入的url后面还加了hash，以避免浏览器缓存js。

事实上除了定义entry的方式间接声明一个chunk外，还有另一种方法，这个后面会遇到，到时再说吧。
