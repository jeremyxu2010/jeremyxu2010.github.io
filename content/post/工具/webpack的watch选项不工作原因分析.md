---
title: webpack的watch选项不工作原因分析
tags:
  - webpack
  - nodejs
categories:
  - 工具
date: 2017-01-26 16:40:00+08:00
---

今天尝试将以前创建的一个前端项目改为webpack编译，该项目使用了`VueJS v2.0`，原来是编写gulp脚本完成构建的。很自然就直接用`vue-cli`来搞定这个事了。

## 使用vue-cli创建项目

因为以前用过webpack，而vue-cli创建的项目底层其实还是使用webpack构建的，所以使用起来还是很简单的。

```
# 使用yarn，这个命令是跟npm兼容的，但速度快很多，而且可以保证依赖包版本的一致性，强烈推荐
yarn install --global vue-cli
vue-cli webpack vue-demo
cd vue-demo
# 安装项目依赖
yarn install
# 启动开发服务器
yarn run dev
```

## 发现问题

但我在开发过程中发现问题了，在IDE中修改了vue文件，webpack开发服务器并不会重新编译对应的模块，更不会reload浏览器页面，webpack的watch选项失效了。

在网上搜索了下原因，发现webpack的[一个issue项](https://github.com/webpack/webpack-dev-server/issues/194)。尝试按该问题中的说明在`vue-demo/build/dev-server.js`的23行加入`watchOptions.polling`选项，发现问题真的解决了。

```javascript
var devMiddleware = require('webpack-dev-middleware')(compiler, {
  publicPath: webpackConfig.output.publicPath,
  quiet: true,
  // Reportedly, this avoids CPU overload on some systems.
  // https://github.com/facebookincubator/create-react-app/issues/293
  watchOptions: {
    poll: true
  }
})
```

## 深究问题

`watchOptions.polling`选项是控制webpack如何检测文件变动的，webpack默认是采用监听文件系统变动事件来感知文件变动的，如果开启这个选项，则会定时询问文件系统是否有文件变动。现在开启这个选项，则功能正常，不开启功能不正常？而vue-cli的广大使用者并没有报告存在该问题。

个人感觉不应该是webpack的这个功能有问题，还是应该是环境问题。继续翻查资料，终于在webpack的官方文档中找到说明`https://webpack.github.io/docs/troubleshooting.html#watching`。这里说得很清楚，watch功能不起作用一般来说就是这几个原因。

而我现在的开发操作系统是Windows，那么就只剩下2个可能原因了。

1. windows路径问题
2. IDE的`safe write`特性干扰

试了一下终于发现是IDE的`safe write`特性这个问题造成的。IDE的这个特性是为了安全地写文件，它会先将文件写到一个临时文件里，然后最后一个原子move操作将文件move到目标位置。但这样webpack检测文件变动的原来逻辑就不工作了。代码见`webpack/lib/node/NodeWatchFileSystem.js`。

```javascript
/*
	MIT License http://www.opensource.org/licenses/mit-license.php
	Author Tobias Koppers @sokra
*/
var Watchpack = require("watchpack");

function NodeWatchFileSystem(inputFileSystem) {
	this.inputFileSystem = inputFileSystem;
	this.watcherOptions = {
		aggregateTimeout: 0
	};
	this.watcher = new Watchpack(this.watcherOptions);
}

module.exports = NodeWatchFileSystem;

NodeWatchFileSystem.prototype.watch = function watch(files, dirs, missing, startTime, options, callback, callbackUndelayed) {
	if(!Array.isArray(files))
		throw new Error("Invalid arguments: 'files'");
	if(!Array.isArray(dirs))
		throw new Error("Invalid arguments: 'dirs'");
	if(!Array.isArray(missing))
		throw new Error("Invalid arguments: 'missing'");
	if(typeof callback !== "function")
		throw new Error("Invalid arguments: 'callback'");
	if(typeof startTime !== "number" && startTime)
		throw new Error("Invalid arguments: 'startTime'");
	if(typeof options !== "object")
		throw new Error("Invalid arguments: 'options'");
	if(typeof callbackUndelayed !== "function" && callbackUndelayed)
		throw new Error("Invalid arguments: 'callbackUndelayed'");
	var oldWatcher = this.watcher;
	this.watcher = new Watchpack(options);

	if(callbackUndelayed)
		this.watcher.once("change", callbackUndelayed);

	this.watcher.once("aggregated", function(changes) {
		if(this.inputFileSystem && this.inputFileSystem.purge) {
			this.inputFileSystem.purge(changes);
		}
		var times = this.watcher.getTimes();
		callback(null, changes.filter(function(file) {
			return files.indexOf(file) >= 0;
		}).sort(), changes.filter(function(file) {
			return dirs.indexOf(file) >= 0;
		}).sort(), changes.filter(function(file) {
			return missing.indexOf(file) >= 0;
		}).sort(), times, times);
	}.bind(this));

	this.watcher.watch(files.concat(missing), dirs, startTime);

	if(oldWatcher) {
		oldWatcher.close();
	}
	return {
		close: function() {
			this.watcher.close();
		}.bind(this),
		pause: function() {
			this.watcher.pause();
		}.bind(this)
	};
};
```

最终关闭了IDE的`safe write`特性。

## 总结

研究这个坑的原因花了一个多小时，在此记录一下。
