---
title: 现代Web开发系列教程_05
tags:
  - web
  - html5
  - javascript
categories:
  - web开发
date: 2016-04-17 23:41:00+08:00
---
本篇不开发新的功能，不过对目前的编译环境重新整理一下。

## 区别开发编译与生产编译

在webpack.config.js中添加读取环境变量`NODE_ENV`

```javascript
...
var isProduction = (process.env.NODE_ENV === 'production');
...
```

## 编译出css文件

```javascript
...
var ExtractTextPlugin = require('extract-text-webpack-plugin');
...
var plugins_options = [
  ...
  new ExtractTextPlugin('css/[name].css', {allChunks: true}),
  ...
];

var loaders = [
  ...
  {
      test: /\.css$/,
      loader: ExtractTextPlugin.extract("style-loader", "css-loader" + (isProduction ? '' : '?sourceMap') + "!postcss-loader")
  },{
      test: /\.less$/,
      loader: ExtractTextPlugin.extract("style-loader", "css-loader" + (isProduction ? '' : '?sourceMap') + "!postcss-loader!less-loader" + (isProduction ? '' : '?sourceMap'))
  }
  ...
];

var webpackConfig = {
    ...
    module: {
        ...
        postcss: function () {
            return [autoprefixer];
        }
    }
};
```

## 非生产编译模式，编译出sourcemap，以方便调试

```javascript
if(!isProduction){
    plugins_options.push(new webpack.SourceMapDevToolPlugin({
        test:      /\.(js|css|less)($|\?)/i,
        filename: '[file].map'
    }));
}
```

## 生产编译模式压缩、去注释、优化排序

```javascript
if(isProduction){
    plugins_options.push(new webpack.optimize.UglifyJsPlugin({
        compress: {
            warnings: false
        },
        output: {
            comments: false
        }
    }));
    plugins_options.push(new webpack.optimize.OccurenceOrderPlugin());
}
```

## 非生产编译模式，启用模块热替换

```javascript
if(!isProduction){
    plugins_options.push(new webpack.HotModuleReplacementPlugin());
}
```

## 非生产编译模式，编译出的js带webpack_dev_client

```javascript
if(!isProduction){
    entries.webpack_dev_client = 'webpack-dev-server/client?http://0.0.0.0:5000';
    entries.webpack_hot_dev_server = 'webpack/hot/only-dev-server';
}
```

## webpack-dev-server的配置

```javascript
var devServer_options = {
        host : '0.0.0.0',
        port: 5000,
        contentBase: ".",
        progress: true,
        hot: true,
        inline: true,
        stats: { colors: true },
        noInfo: true,
        historyApiFallback: true
};

var webpackConfig = {
    ...
    devServer: devServer_options,
    ...
};
```

## 非生产编译模式，使用eval方式生成sourcemap，这个速度最快

if(!isProduction){
    webpackConfig.devtool = 'eval';
}

## 使用eslint对js进行静态检查

```javascript
var loaders = [
  ...
  {
      test: /\.(js|jsx)$/,
      exclude: [/node_modules/], // exclude any and all files in the node_modules folder
      loaders: ['babel-loader', 'eslint-loader', 'strict-loader']
  }
  ...
];
```

## 安装一系列npm包

```bash
npm install webpack-dev-server --global

npm install webpack-dev-server extract-text-webpack-plugin eslint-loader eslint strict-loader eslint-plugin-react babel-eslint style-loader css-loader postcss-loader postcss less-loader less autoprefixer file-loader url-loader img-loader --save-dev
```

## 最后在package.json里加入两行npm script

```
  "scripts": {
    "serve-dev": "./node_modules/.bin/webpack-dev-server --progress",
    "build-prod": "NODE_ENV=production ./node_modules/.bin/webpack --progress"
  }
```

以后执行`npm run serve-dev`就直接打开了`webpack-dev-server`了，开发终于不用再依赖于`nginx`了，直接访问`http://127.0.0.1:5000/demo4/demo4.html`就可以看到页面效果，而且可以修改了代码后还可以热替换。 如果只想编译出最优化的代码，输入`npm run build-prod`就好了。

前端应该会玩了吧，下篇我将开始说后端了。

本篇[源代码地址](https://github.com/jeremyxu2010/web_dev/tree/master/demo4)
