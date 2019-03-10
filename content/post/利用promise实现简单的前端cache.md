---
title: 利用promise实现简单的前端cache
tags:
  - html5
  - promise
categories:
  - web开发
date: 2016-09-22 22:51:00+08:00
---
今天在工作中遇到一个关于promise有趣的小问题，这里分享一下分析的过程。

## 原始版本

```javascript
//这个方法模拟从服务端加载数据
var loadData = function(){
  return fetch('/').then(function(data){
    return data.statusText
  });
};

loadData().then(function(data){
  console.log(data);
});
```

上面这一小段方法本也没什么错，但考虑如果使用数据的地方比较多，每个地方都向服务端加载数据，这样会不会加重服务端压力？

## 来个简单的缓存

你一定会说来个简单的缓存吧，如下所示：

```javascript
//定义一个变量充当缓存
var cache = null;

//下面的方法使用了cache
var loadData = function(){
  if(cache === null) {
    return fetch('/').then(function(data){
      cache = data.statusText;
      return cache;
    });
  } else {
    return Promise.resolve(cache);
  }
};

//再定义了一个重新加载数据的方法
var reloadData = function(){
  cache = null;
  return loadData();
};

loadData().then(function(data){
  console.log(data);
});
```

一眼看过去，好像没有什么问题。

但经过仔细推敲代码，发现还是存在问题的。当调用两次`loadData()`方法，而在调用第二次方法时，cache还为null，因此最终还是fetch了两次。

## 判断一下promise的状态

你一定会说要判断一下promise的状态，好吧，这样试一下。

```javascript
var loadPromise = null;

var loadData = function(){
  //在加载数据时，如发现loadPromise为null，才重新加载
  if(loadPromise === null) {
    loadPromise = fetch('/').then(function(data){
      return data.statusText;
    });
  }
  //否则返回已经存在的promise对象
  return loadPromise;
};

var reloadData = function(){
  loadPromise = null;
  return loadData();
};

loadData().then(function(data){
  console.log(data);
});
```

可以看到上述代码连`cache`变量都没使用了。这里是将`loadPromise`的`resolved`值当成缓存来用了。

为啥可以这么干？参见这里[https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise)

> Promise 对象是一个返回值的代理，这个返回值在promise对象创建时未必已知。它允许你为异步操作的成功或失败指定处理方法。 这使得异步方法可以像同步方法那样返回值：异步方法会返回一个包含了原返回值的 promise 对象来替代原返回值。

> Promise对象有以下几种状态:

> * pending: 初始状态, 既不是 fulfilled 也不是 rejected.
> * fulfilled: 成功的操作.
> * rejected: 失败的操作.

> pending状态的promise对象既可转换为带着一个成功值的fulfilled 状态，也可变为带着一个失败信息的 rejected 状态。当状态发生转换时，promise.then绑定的方法（函数句柄）就会被调用。(`当绑定方法时，如果 promise对象已经处于 fulfilled 或 rejected 状态，那么相应的方法将会被立刻调用`， 所以在异步操作的完成情况和它的绑定方法之间不存在竞争条件。)

你估计会认为这次看上去OK了吧？

很遗憾还是存在问题。。。

试想一下，如果在加载数据时偶尔出现异常，`loadPromise`最终变为一个`rejected`状态的promise对象。即使以后故障解决了，这时调用`loadData()`还是只能拿到一个`rejected`状态的promise对象。

## 判断一下rejected状态

这次我们判断一下rejected状态。很可惜，原生的Promise并没有提供同步API直接获取某个promise对象的状态，所以这里采取一个变通的办法。

```javascript
var loadPromise = null;
//定义一个变量用来保存Promise是否处于rejected状态
var loadRejected = false;

var loadData = function(){
  //在加载数据时，如发现loadPromise为null或promise为rejected状态，才重新加载
  if(loadPromise === null || loadRejected) {
    //一旦准备加载数据，则重置rejected状态
    loadRejected = false;
    loadPromise = fetch('/').then(function(data){
      return data.statusText;
    }).then(undefined, function(){
      //如加载过程出现异常，则记录rejected状态
      loadRejected = true;
    });
  }
  return loadPromise;
};

var reloadData = function(){
  loadPromise = null;
  return loadData();
};

loadData().then(function(data){
  console.log(data);
});
```

仔细检查了好几遍，暂时没有发现其它问题。如有高手发现问题请通知我。

## 总结

HTML5中的Promise确实是个好特性，但用起来真的有很小心，不然很容易出问题。

## 参考

`https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise`
