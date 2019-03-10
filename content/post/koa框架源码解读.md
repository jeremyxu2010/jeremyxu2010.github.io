---
title: koa框架源码解读
tags:
  - web
  - javascript
  - nodejs
categories:
  - web开发
date: 2016-05-06 00:44:00+08:00
---
虽然经常用koa作为NodeJS Web项目的框架，但一直都是只知道怎么做，但并不知道它究竟是怎么实现的。今天花了些时间来研究它，在这里记录一下。

## Generator函数

### Generator函数形式
Generator函数是ES6提供的一种异步编程解决方案，语法行为与传统函数完全不同。Generator函数相当是一个状态机，封装了多个内部状态。执行Generator函数会返回一个遍历器对象，也就是说，Generator函数除了状态机，还是一个遍历器对象生成函数。返回的遍历器对象，可以依次遍历Generator函数内部的每一个状态。

```javascript
function* helloWorldGenerator() {
  yield 'hello';
  yield 'world';
  return 'ending';
}

var hw = helloWorldGenerator();
```

在上面的例子里，`helloWorldGenerator`就是一个Generator函数，Generator函数的`function`关键字与函数名之间有一个星号，同时函数体内部使用yield语句，定义不同的内部状态，`helloWorldGenerator`这个Generator函数有3个状态：hello、world、ending。`hw`就是这个Generator函数产生的遍历器。

下面使用`hw`这个遍历器对Generator函数的内部状态进行遍历
```javascript
console.log(JSON.stringify(hw.next()));
// {value: "hello", done: false}

console.log(JSON.stringify(hw.next()));
// {"value":"world","done":false}

console.log(JSON.stringify(hw.next()));
// {"value":"ending","done":true}
```

### yield语句的返回值

yield句本身没有返回值，或者说总是返回undefined。next方法可以带一个参数，该参数就会被当作上一个yield语句的返回值。于是自然就可以写出下面的代码。

```javascript
function doSomeThing(){
  return 'xxj';
}

function doAnotherThing(name){
  return 'hello, ' + name;
}

function* f(){
  var name = yield doSomeThing();
  var greeting = yield doAnotherThing(name);
  return greeting;
}

var gen = f();

var state1 = gen.next();
var state2 = gen.next(state1.value);
var state3 = gen.next(state2.value);

console.log(state3.value);
// hello, xxj

```

上面的例子比较无聊，这种同步的方法使用Generator函数来调用并没有什么意义。请耐下心继续看下去。

### yield*语句

如果在Generater函数内部，调用另一个Generator函数，默认情况下是没有效果的。

```javascript
function* foo() {
  yield 'a';
  yield 'b';
}

function* bar() {
  yield 'x';
  foo();
  yield 'y';
}

for (let v of bar()){
  console.log(v);
}
// "x"
// "y"
```

直接用yield也达不到期望的效果

```javascript
function* inner() {
  yield 'hello!';
}

function* outer1() {
  yield 'open';
  yield inner();
  yield 'close';
}

var gen = outer1()
gen.next().value // "open"
gen.next().value // 返回一个遍历器对象
gen.next().value // "close"
```

可以看到第2次next()得到的value是一个遍历器对象，并没有得到“hello!”

必须要用yield*才可以

```javascript
function* inner() {
  yield 'hello!';
}

function* outer2() {
  yield 'open'
  yield* inner()
  yield 'close'
}

var gen = outer2()
gen.next().value // "open"
gen.next().value // "hello!"
gen.next().value // "close"
```

## co模块

从上面的例子可以看到，目前这种使用Generator函数的方式并没有解决什么问题，而且开发者还得自己不停地调用`next`方法才可以驱使Generator函数工作。那么是否有一种自动执行机制来驱使Generator函数呢？大招终于来了，co模块。

[co模块](https://github.com/tj/co)是著名程序员TJ Holowaychuk于2013年6月发布的一个小工具，用于Generator函数的自动执行。

使用`co模块`时，Generator就相当于一个容纳n个异步操作的容器，co模块负责自动推动这个容器内的异步操作逐个执行。使用co的前提条件是，Generator函数的yield命令后面，只能是Promise对象、Thunk函数、数组、对象、Generator函数、Generator函数的遍历器(当然数组、对象的属性键值还是必须为这5种类型)。

举个例子

callback的写法

```javascript
var fs = require('fs');

function readFiles(callback){
    fs.readFile('/etc/fstab', function(error, data){
          if (error) reject(error);
          var f1 = data;
          fs.readFile('/etc/fstab', function(error, data){
              if (error) reject(error);
              f2 = data;
              console.log(f1.toString());
              console.log(f2.toString());
              callback(f1, f2);
          });
    });
}

readFiles(function(f1, f2){
    console.log('finished');
});
```

Genertor函数配合co模块的写法

```javascript
var fs = require('fs');
var co = require('co');

var readFile = function (fileName){
  return new Promise(function (resolve, reject){
    fs.readFile(fileName, function(error, data){
      if (error) reject(error);
      resolve(data);
    });
  });
};

var gen = function* (){
  var f1 = yield readFile('/etc/fstab');
  var f2 = yield readFile('/etc/shells');
  console.log(f1.toString());
  console.log(f2.toString());
};

co(gen).then(function(){
  console.log('finished');
});
```

这个例子比较简单，但已经可以看出Genertor函数配合co模块将原来可能要使用多个callback的代码一下就优化得像同步代码一样简单了。所要付出的代价仅仅是要求`Generator函数的yield命令后面，只能是Promise对象、Thunk函数、数组、对象、Generator函数、Generator函数的遍历器(当然数组、对象的属性键值还是必须为这5种类型)`。这个要求也不是很难实现，事实上很多第三库的接口已经是返回Promise对象了，即使不是的，也可以用`new Promise(function (resolve, reject){...});`自行封装一个，很简单。

## koa的源码解读

先看一下koa最简单的使用示例。

```javascript
const app = require('koa')();

app.use(function *(next) {
  console.log(1);
  yield next;
  console.log(4);
});

app.use(function *(next) {
  console.log(2);
  yield next;
  console.log(3);
});

app.use(function *() {
  this.body = 'Hello World';
});

app.listen(3000);
```

可以看到`use`方法的3个参数都是Genertor函数，在koa里将这些Generator函数叫做middleware。

再看一下`use`方法

```javascript
app.use = function(fn){
  if (!this.experimental) {
    // es7 async functions are not allowed,
    // so we have to make sure that `fn` is a generator function
    assert(fn && 'GeneratorFunction' == fn.constructor.name, 'app.use() requires a generator function');
  }
  debug('use %s', fn._name || fn.name || '-');
  this.middleware.push(fn);
  return this;
};
```

很简单，就是将这些个Generator函数塞进`this.middleware`这个数组。

再看一下`app.listen`方法

```javascript
app.listen = function(){
  debug('listen');
  var server = http.createServer(this.callback());
  return server.listen.apply(server, arguments);
};
```

也很简单，就是创建一个http server, 监听某个地址，所有http请求交由`this.callback`处理。

再看一下`app.callback`方法

```javascript
app.callback = function(){
  if (this.experimental) {
    console.error('Experimental ES7 Async Function support is deprecated. Please look into Koa v2 as the middleware signature has changed.')
  }
  var fn = this.experimental
    ? compose_es7(this.middleware)
    : co.wrap(compose(this.middleware));
  var self = this;

  if (!this.listeners('error').length) this.on('error', this.onerror);

  return function(req, res){
    res.statusCode = 404;
    var ctx = self.createContext(req, res);
    onFinished(res, ctx.onerror);
    fn.call(ctx).then(function () {
      respond.call(ctx);
    }).catch(ctx.onerror);
  }
};

```

`co.wrap(compose(this.middleware));`这一句很关键，首先`compose(this.middleware)`是使用`koa-compose`将`this.middleware`里所有的Generator函数组装成一个Generator函数，这个Generator函数容纳了所有middleware里的异步操作。然后`co.wrap`将这个超级Generator函数转换成一个返回Promise对象的函数`fn`。

`var ctx = self.createContext(req, res);`创建处理http请求的上下文。`onFinished(res, ctx.onerror);`处理http请求处理完毕后的后续事宜。`fn.call(ctx)`以刚创建http请求上下文作为this，调用刚才得到的函数`fn`。刚才说过这个函数的返回值是一个Promise。`respond.call(ctx);`在这个Promise的then方法里根据`ctx上下文里保存的信息`写回response。很简单吧，一切都那么自然。


再回过头看一下`koa-compose`。

```javascript
function compose(middleware){
  return function *(next){
    if (!next) next = noop();

    var i = middleware.length;

    while (i--) {
      next = middleware[i].call(this, next);
    }

    return yield *next;
  }
}

/**
 * Noop.
 *
 * @api private
 */

function *noop(){}
```

跟最初的想象一样，就是将`middleware`里所有的Generator函数组装成一个超级Generator函数。再回头看看koa的使用示例，这下终于明白next原来是下一个Generator函数(middleware)的遍历器。

```javascript
const app = require('koa')();

app.use(function *(next) {
  console.log(1);
  yield next;
  console.log(4);
});

app.use(function *(next) {
  console.log(2);
  yield next;
  console.log(3);
});

app.use(function *() {
  this.body = 'Hello World';
});

app.listen(3000);
```

当初看示例的时候一直有个疑问，隐隐觉得next应该是Generator函数的遍历器，但在一个Generator函数内部调用另一个Generator函数，应该是要使用`yield*`的，为啥官方示例却没有用过`yield*`，但功能却正常呢？

于是做了个实验

```javascript
var co = require('co');
var compose = require('koa-compose');

var i = 0;

function promiseA (){
    console.log(++i);
    return Promise.resolve(true);
}

function *middleware1 (next){
    yield next;
}

function *middleware2 (next){
    yield promiseA();
    yield promiseA();
}

var middleware = [middleware1, middleware2];

var gen = compose(middleware);

var iter1 = gen();

while(!(iter1.next().done)){
}

console.log('finished');

// finished
```

这样功能是不正常的。但改成下面这样工作正常了。

```javascript
var co = require('co');
var compose = require('koa-compose');

var i = 0;

function promiseA (){
    console.log(++i);
    return Promise.resolve(true);
}

function *middleware1 (next){
    yield *next;
}

function *middleware2 (next){
    yield promiseA();
    yield promiseA();
}

var middleware = [middleware1, middleware2];

var gen = compose(middleware);

var iter1 = gen();

while(!(iter1.next().done)){
}

console.log('finished');

// 1
// 2
// finished
```

再配合co模块，功能才正常。

```javascript
var co = require('co');
var compose = require('koa-compose');

var i = 0;

function promiseA (){
    console.log(++i);
    return Promise.resolve(true);
}

function *middleware1 (next){
    yield next;
}

function *middleware2 (next){
    yield promiseA();
    yield promiseA();
}

var middleware = [middleware1, middleware2];

var gen = compose(middleware);

var fn = co.wrap(gen);

fn().then(function(){
    console.log('finished');
});
```

原因终于出来了，原来是co模块可以处理yield后面带Generator函数遍历器的场景。再看看co模块的代码。

```javascript
function co(gen) {
  var ctx = this;
  var args = slice.call(arguments, 1);

  // we wrap everything in a promise to avoid promise chaining,
  // which leads to memory leak errors.
  // see https://github.com/tj/co/issues/180
  return new Promise(function(resolve, reject) {
    if (typeof gen === 'function') gen = gen.apply(ctx, args);
    if (!gen || typeof gen.next !== 'function') return resolve(gen);

    onFulfilled();

    /**
     * @param {Mixed} res
     * @return {Promise}
     * @api private
     */

    function onFulfilled(res) {
      var ret;
      try {
        ret = gen.next(res);
      } catch (e) {
        return reject(e);
      }
      next(ret);
      return null;
    }

    /**
     * @param {Error} err
     * @return {Promise}
     * @api private
     */

    function onRejected(err) {
      var ret;
      try {
        ret = gen.throw(err);
      } catch (e) {
        return reject(e);
      }
      next(ret);
    }

    /**
     * Get the next value in the generator,
     * return a promise.
     *
     * @param {Object} ret
     * @return {Promise}
     * @api private
     */

    function next(ret) {
      if (ret.done) return resolve(ret.value);
      var value = toPromise.call(ctx, ret.value);
      if (value && isPromise(value)) return value.then(onFulfilled, onRejected);
      return onRejected(new TypeError('You may only yield a function, promise, generator, array, or object, '
        + 'but the following object was passed: "' + String(ret.value) + '"'));
    }
  });
}

/**
 * Convert a `yield`ed value into a promise.
 *
 * @param {Mixed} obj
 * @return {Promise}
 * @api private
 */

function toPromise(obj) {
  if (!obj) return obj;
  if (isPromise(obj)) return obj;
  if (isGeneratorFunction(obj) || isGenerator(obj)) return co.call(this, obj);
  if ('function' == typeof obj) return thunkToPromise.call(this, obj);
  if (Array.isArray(obj)) return arrayToPromise.call(this, obj);
  if (isObject(obj)) return objectToPromise.call(this, obj);
  return obj;
}
```

核心就4个函数。

* `co`函数将Generator函数或Generator遍历器转换为Promise对象。(要求`Generator函数的yield命令后面，只能是Promise对象、Thunk函数、数组、对象、Generator函数、Generator函数的遍历器`)
* `onFulfilled`函数调用Generator函数的`next`方法，将得到的状态传给`next`函数。
* `next`函数调用toPromise函数将状态里的value转换成Promise对象，再在Promise对象的then方法里调用`onFulfilled`函数，以推动Generator函数进入下一个状态。
* `toPromise`对状态里的value(即yield后跟着的值)进行转换，将之转换为Promise对象。这个可以看到当obj是Generator函数或Generator遍历器时，又去调用co函数了。

大神的代码确实不简单，短短几个函数就把这么复杂的问题解决了。

## 参考文档

[阮一峰的ECMAScript 6 入门 - Generator 函数](http://es6.ruanyifeng.com/#docs/generator)
[阮一峰的ECMAScript 6 入门 - 异步操作和Async函数](http://es6.ruanyifeng.com/#docs/async)
[koa源码](https://github.com/koajs/koa/blob/master/lib/application.js)
[koa-compose源码](https://github.com/koajs/compose/blob/master/index.js)
[co源码](https://github.com/tj/co/blob/master/index.js)
