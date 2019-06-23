---
title: 锁定NodeJS项目的依赖库
tags:
  - nodejs
  - npm
categories:
  - nodejs开发
date: 2016-05-03 21:58:00+08:00
---

今天一上班，顺手点了一次构建整个项目，结果发现项目中的javascript编译报错，而且报的错莫名其秒。


```
undefined is not iterable!
```

搜遍互联网才在babel的twitter上找到了这个问题的说明。

`
If you are getting an `undefined is not iterable!` error, please `npm install babel-types` (to use v6.8.1). If necessary, clear node_modules
`

看情况应该是babel相关的依赖自动升级导致的错误，这里鄙视一下NodeJS生态里的npmjs.com上的库，质量真的是参差不齐，明明安装的是兼容的版本，可实际上很有可能由于某个依赖的升级导致整个项目编译失败。

实际上我之前已发现了这个问题，当时的方案是在package.json里将所有依赖的包指定一个确定的版本号，如下如示：

```
  "dependencies": {
    "babel-polyfill": "6.3.14",
    "before-unload": "2.0.0",
    "bootstrap": "3.3.4",
    "bowser": "1.0.0",
    "browser-audio": "1.0.2",
    "classnames": "2.1.2",
    "cropper": "0.11.0",
    "extend": "3.0.0",
    "fancybox": "3.0.0",
    "favicon-notification": "0.1.4",
    "flux": "2.0.3",
    "fullscreen": "1.0.0",
    "immutable": "3.7.5",
    "inherits": "2.0.1",
    "jquery": "1.11.3",
    "jquery-textrange": "1.3.3",
    "jwt-decode": "1.4.0",
    "keymirror": "0.1.1",
    ...
  }
```

原以为这样依赖的版本号就固定了。但实际上在NodeJS生态里大量第三方库其package.json文件是这样的：

```
"dependencies": {
    "acorn": "^3.0.0",
    "async": "^1.3.0",
    "clone": "^1.0.2",
    "enhanced-resolve": "^2.2.0",
    "interpret": "^1.0.0",
    "loader-runner": "^2.1.0",
    "loader-utils": "^0.2.11",
    "memory-fs": "~0.3.0",
    "mkdirp": "~0.5.0",
    "node-libs-browser": "^1.0.0",
    "object-assign": "^4.0.1",
    "source-map": "^0.5.3",
    "supports-color": "^3.1.0",
    "tapable": "~0.2.3",
    "uglify-js": "~2.6.0",
    "watchpack": "^1.0.0",
    "webpack-sources": "^0.1.0",
    "yargs": "^3.31.0"
  }
```

可以看到`~`表示该依赖可能会自动更新至最近的minor版本，`^`表示该依赖可能会自动更新至最近的major版本。

这样就存在问题了，这里我用示例简单说明一下。

最开始项目是这样的，其中A使用`^`依赖于B

```
proj 1.0.0
   A 1.1.0
      B 1.2.0
```

某一天B的维护者发布了一个新的版本`1.3.0`，但他并没有经过完备的测试来保证一定是与`1.2.0`版本是兼容的。项目的维护者又手贱地执行了下`npm install`或`npm install C`，执行后，依赖树就变成下面这样了。

```
proj 1.0.0
   A 1.1.0
      B 1.3.0
```

然后项目编译时就失败了，或者编译成功，但在浏览器中运行出错了，悲剧。

怎么办？还好查到了npmjs.com官方针对这个问题的说明，详见[这里](https://docs.npmjs.com/cli/shrinkwrap)

`npm shrinkwrap`的作用就是以项目为根，将项目依赖树上所有第三方库版本固定。 使用上还是比较简单的，就是执行`npm shrinkwrap`命令，就会在package.json旁边上一个`npm-shrinkwrap.json`，以后再执行`npm install`，就会安装`npm-shrinkwrap.json`里描述的确切版本。

不过这里还有一个小坑，官方文档里说明如下：

```
Since npm shrinkwrap is intended to lock down your dependencies for production use, devDependencies will not be included unless you explicitly set the --dev flag when you run npm shrinkwrap.
```

也就是默认不会锁定`devDependencies`的版本，除非执行`npm shrinkwrap`带上`--dev`参数。我建议执行`npm shrinkwrap`还是带上`--dev`参数，否则很有可能某天一个开发依赖库版本小升个版本号，你的项目又悲剧了。
