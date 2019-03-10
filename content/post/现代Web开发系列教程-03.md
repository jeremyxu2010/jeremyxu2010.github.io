---
title: 现代Web开发系列教程_03
tags:
  - web
  - html5
  - javascript
categories:
  - web开发
date: 2016-04-17 15:26:00+08:00
---
现在我们使用React重写昨天的hello world示例。本篇涉及了很多react的知识，如果不清楚，建议先看看react[官方文档](https://facebook.github.io/react/docs/getting-started.html)

## 安装react及babel

```
npm install react react-dom --save
npm install babel-core babel-loader babel-preset-react --save-dev
```

## 修改js代码及模板文件

demo2.js

```javascript
var React = require('react');
var ReactDOM = require('react-dom');

var Greeting = React.createClass({
    render : function(){
        return <h1>Hello, world!</h1>;
    }
});

ReactDOM.render(
  <Greeting />,
  document.getElementById('reactHolder')
);
```

base.html

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
    <div id="reactHolder"></div>
    <% for (var chunk in htmlWebpackPlugin.files.chunks) { %> <script src="<%= htmlWebpackPlugin.files.chunks[chunk].entry %>"></script> <% } %>
</body>
</html>
```

## 修改webpack编译脚本

webpack.config.js

```
var webpack = require("webpack");
var HtmlWebpackPlugin = require('html-webpack-plugin');

var output_options = {
    path: 'public',
    publicPath: '/demo2/',
    filename: 'js/[name].js',
    hotUpdateMainFilename: 'hot-update/[name].[hash].hot-update.js',
    chunkFilename: 'js/chunks/[name].js',
    hotUpdateChunkFilename: 'hot-update/chunks/[name].[hash].hot-update.js',
};

var createHtmlDef = function(opts){
    return new HtmlWebpackPlugin({
        title: 'demo2',
        filename: opts.path,
        template: 'web-src/html/base.html',
        chunks: opts.chunks,
        hash: true,
        inject: false
    });
};

var plugins_options = [
    createHtmlDef({path: 'demo2.html', chunks: ['vendor', 'demo2']})
];

var entries = {
    demo2 : __dirname + '/web-src/js/demo2.js',
    vendor : ['react', 'react-dom']
};

var loaders = [
    {test: /\.(js|jsx)$/, loaders: ["babel"]},
];

var webpackConfig = {
    entry: entries,
    output: output_options,
    plugins: plugins_options,
    module: {
        loaders: loaders
    }
};

module.exports = webpackConfig;
```

因为是使用babel来编译jsx语法的js文件，需要对babel进行一些配置

.babalrc

```
{
  "presets": ["react"]
}
```

把这个小demo部署到nginx里吧

```bash
ln -sf demo2/public /usr/local/var/www/demo2
```

最后在浏览器里访问`http://127.0.0.1/demo2/demo2.html`，在页面上就可以看到`Hello World`了。

## 转换成ES6写法

react新版本已经推荐采用ES6写法了，也得用上吧。

```
npm install babel-preset-es2015 --save-dev
```

修改.babelrc文件

```
{ "presets": ["react", "es2015"] }
```

修改demo2.js

```javascript
import React from 'react'
import ReactDOM from 'react-dom'

class Greeting extends React.Component {
    render(){
       return <h1>Hello, world!</h1>;
    }
}

ReactDOM.render(
  <Greeting />,
  document.getElementById('reactHolder')
);
```
## 去除编译后的js大量重复内容

在webpack.config.js里作一点点修改

```
var plugins_options = [
    createHtmlDef({path: 'demo2.html', chunks: ['vendor', 'demo2']}),
    new webpack.optimize.CommonsChunkPlugin({
        name: "vendor",
        minChunks: Infinity,
    })
];
```

这里其实有个技巧，我研究了很久才想明白，其它人我不告诉的。CommonsChunkPlugin的工作原理相当于把指定的chunks里每个chunk引用的所有资源先抽出来，然后对这些重复资源进行统计，看每个重复资源被n个chunk引用，如果n>=minChunks设置的值，则将该资源移至common chunk里，如果n<minChunks，则看该资源name指定的chunk引用不，如果引用就只将该资源返还给name指定的chunk，否则返还给所有引用它的chunk。因此

```
    new webpack.optimize.CommonsChunkPlugin({
        name: "vendor",
        minChunks: Infinity,
    })

    var entries = {
      demo2 : __dirname + '/web-src/js/demo2.js',
      vendor : ['react', 'react-dom']
    };

```

相当于把引用的第三方资源抽到vendor.js里了。

本篇[源代码地址](https://github.com/jeremyxu2010/web_dev/tree/master/demo2)
