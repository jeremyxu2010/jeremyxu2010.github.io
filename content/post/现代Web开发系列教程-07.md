---
title: 现代Web开发系列教程_07
tags:
  - web
  - html5
  - javascript
  - nodejs
categories:
  - web开发
date: 2016-05-15 00:07:00+08:00
---
今天结合前面说到的前后端开发知识，做一个小工程，这个小工程并不完全具体的业务功能，但该工程包括前后端，可以作为以后复杂工程的起点。

## 前端代码

前端代码稍微复杂一点，就先从前端代码开始。

`frontend/js/demo6.js`

```javascript
import React from 'react';
import ReactDOM from 'react-dom';
import ReactRouter from 'react-router';
import { Router, Route, IndexRoute, browserHistory } from 'react-router';

class App extends React.Component{
  render(){
    return <div>{this.props.children}</div> ;
  }
}

class Home extends React.Component{
  render(){
    return <h1>Home Page</h1> ;
  }
}

class About extends React.Component{
  render(){
    return <h1>About Page</h1> ;
  }
}

class Features extends React.Component{
  render(){
    return <h1>Features Page</h1> ;
  }
}

document.body.innerHTML = '<div id="reactHolder"></div>';

ReactDOM.render(
  <Router history={browserHistory}>
    <Route path='/' component={App}>
      <IndexRoute component={Home} />
      <Route path='about' component={About} />
      <Route path='features' component={Features} />
      <Route path='*' component={Home} />
    </Route>
  </Router>,
  document.getElementById('reactHolder')
);
```

可以看到就是定义了几个React组件，并用`react-router`定义了一个很简的路由，这个路由的`history`使用的是`browserHistory`。`react`的用法可参考[这里](http://reactjs.cn/react/docs/getting-started.html)，`react-router`的用法可参考[这里](http://react-guide.github.io/react-router-cn/index.html)

## 写前端代码编译脚本

`webpack.config.js`

```javascript
const webpack = require("webpack");
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
    entry: {
        demo6 : __dirname + '/frontend/js/demo6.js'
    },
    output: {
        path: __dirname + '/public',
        publicPath: '/',
        filename: 'js/[name].js',
        hotUpdateMainFilename: 'hot-update/[hash].hot-update.json',
        chunkFilename: 'js/chunks/[name].js',
        hotUpdateChunkFilename: 'hot-update/chunks/[id].[hash].hot-update.js',
    },
    plugins: [
        new webpack.SourceMapDevToolPlugin({
            test:      /\.(js|css|less)($|\?)/i,
            filename: '[file].map'
        }),
        new HtmlWebpackPlugin({
          title: 'demo6',
          filename: 'index.html',
          hash : true,
          chunks : ['demo6']
        })
    ],
    module: {
        loaders: [
            {test: /\.(js|jsx)$/, loaders: ["babel"]}
        ]
    },
    resolve: {
        extensions: ['', '.js', '.jsx']
    },
    devtool: 'eval'
};
```

`.babelrc`

```javascript
{ "presets": ["react", "es2015"] }
```

上面的`webpack`编译配置很简单，就是配置把`frontend/js/demo6.js`编译到`public/js/demo6.js`，同时生成`public/index.html`，其引用生成的`public/js/demo6.js`

利用npm-scripts来进行webpack的调用

```
  "scripts": {
    "wpack": "./node_modules/.bin/webpack --watch --progress"
  },
```

## 后端代码

`backend/server.js`

```javascript
"use strict";

const koa = require('koa');
const serve = require('koa-static');
const sendfile = require('koa-sendfile')
const path = require('path');
const Promise = require('bluebird');
const fs = require('fs');

const statAsync = Promise.promisify(fs.stat);

const app = koa();

app.use(serve(__dirname + '/../public'));

app.use(function *(next){
    let p = path.resolve(__dirname, '..', 'public', this.path);
    let stats = null;
    try{
        stats = yield statAsync(p);
    }catch(ignore){}
    if (!stats) {
        try {
            stats = yield sendfile(this, path.resolve(__dirname, '..', 'public', 'index.html'));
        }catch(ignore){}
        if (!stats) this.throw(404);
    }
});

const port = 5000;

app.listen(port);

console.log("server started on port " + port);
```

因为前端使用了`browserHistory`路由，后端要实现类似nginx的try_files逻辑，详情见[这里](http://react-guide.github.io/react-router-cn/docs/guides/basics/Histories.html#createbrowserhistory)，如果后端是用Java写法，可以考虑使用[TryFilesFilter](https://github.com/eclipse/jetty.project/blob/master/jetty-fcgi/fcgi-server/src/main/java/org/eclipse/jetty/fcgi/server/proxy/TryFilesFilter.java)

这里使用`bluebird`的`promisify`方法将NodeJS风格的API `fs.stat` 转化成返回Promise对象的方法，这个是为配合`koa`的`yield`而为，详见[这里](/2016/05/06/koa%E6%A1%86%E6%9E%B6%E6%BA%90%E7%A0%81%E8%A7%A3%E8%AF%BB/)

同样利用npm-scripts启动后端server

```
  "scripts": {
    "serve": "node ./backend/server.js"
  },
```

## 运行测试

打开两个终端，在一个里面执行`npm run serve`启动后端server，在另一个里面执行`npm run wpack`启动webpack对前端代码进行编译。最后使用浏览器分别访问`http://127.0.0.1:5000/`、`http://127.0.0.1:5000/about`、`http://127.0.0.1:5000/features`，即可看到路由切换的效果。

本篇[源代码地址](https://github.com/jeremyxu2010/web_dev/tree/master/demo6)
