---
title: 重新理解HTTP中的“持久连接”
tags:
  - HTTP
  - ' javascript'
categories:
  - web开发
date: 2016-09-05 23:16:00+08:00
---
Web页面优化中有一条很重要的规则说应在不影响代码可阅读性的前提下尽量减少请求数。以前一直以为过多的请求数会导致要建立大量连接，所以影响页面加载速度。但今天看到[阮一峰的一篇文章](http://www.ruanyifeng.com/blog/2016/08/http.html)，发现真相原来不是这样的。

## 持久连接的概念

HTTP/1.0 版的主要缺点是，每个TCP连接只能发送一个请求。发送数据完毕，连接就关闭，如果还要请求其他资源，就必须再新建一个连接。
TCP连接的新建成本很高，因为需要客户端和服务器三次握手，并且开始时发送速率较慢（slow start）。所以，HTTP 1.0版本的性能比较差。随着网页加载的外部资源越来越多，这个问题就愈发突出了。
为了解决这个问题，HTTP/1.1引入了持久连接（persistent connection），即TCP连接默认不关闭，可以被多个请求复用，不用声明`Connection: keep-alive`。

客户端和服务器发现对方一段时间没有活动，就可以主动关闭连接。不过，规范的做法是，客户端在最后一个请求时，发送Connection: close，明确要求服务器关闭TCP连接。

```
Connection: close
```

目前，对于同一个域名，大多数浏览器允许同时建立6个持久连接。

## 产生疑问

从上面的概念展开来想，HTTP/1.1中的持久连接仅仅是复用连接而已，但在HTTP协议层面并没有给每个请求添加编号，如果在一条TCP连接上同时发送多个请求，当响应返回时，并没有办法确定某个响应是对应哪个请求的。所以猜想在一条TCP连接上，所有的数据通信是按次序进行的。

这一猜想果然得到印证：

> 虽然1.1版允许复用TCP连接，但是同一个TCP连接里面，所有的数据通信是按次序进行的。服务器只有处理完一个回应，才会进行下一个回应。要是前面的回应特别慢，后面就会有许多请求排队等着。这称为"队头堵塞"（Head-of-line blocking）。

> 为了避免这个问题，只有两种方法：一是减少请求数，二是同时多开持久连接。这导致了很多的网页优化技巧，比如合并脚本和样式表、将图片嵌入CSS代码、域名分片（domain sharding）等等。

也就是说对于同一个域名，假设浏览器允许同时建立6个持久连接。通过ajax请求向服务器发送6个请求，如果这6个请求业务处理都比较慢，则此时再发起第7个ajax请求，这个请求将被阻塞住。所以说页面的异步请求问题仅靠AJAX是无法完全解决，当多个AJAX请求均阻塞TCP连接时，这个时候再怎么发送AJAX请求也达不到异步请求响应的需求。

想象一下，当一个页面被加载时，会同时向服务端发起多个请求，有的在加载js、有的在加载css、有的在加载图片，一旦某个资源加载过慢，它就会阻塞在这条TCP连接上其它的请求，最终导致整个页面加载时间过长。这个才是连接数过多页面加载慢的真正原因。

## HTTP/2中的改进

HTTP/2中引入了“多工”与“数据流”的概念来对上述缺陷进行改进，如下：

* 多工

> HTTP/2 复用TCP连接，在一个连接里，客户端和浏览器都可以同时发送多个请求或回应，而且不用按照顺序一一对应，这样就避免了"队头堵塞"。
举例来说，在一个TCP连接里面，服务器同时收到了A请求和B请求，于是先回应A请求，结果发现处理过程非常耗时，于是就发送A请求已经处理好的部分， 接着回应B请求，完成后，再发送A请求剩下的部分。
这样双向的、实时的通信，就叫做多工（Multiplexing）。

* 数据流

> 因为 HTTP/2 的数据包是不按顺序发送的，同一个连接里面连续的数据包，可能属于不同的回应。因此，必须要对数据包做标记，指出它属于哪个回应。
HTTP/2 将每个请求或回应的所有数据包，称为一个数据流（stream）。每个数据流都有一个独一无二的编号。数据包发送的时候，都必须标记数据流ID，用来区分它属于哪个数据流。另外还规定，客户端发出的数据流，ID一律为奇数，服务器发出的，ID为偶数。
数据流发送到一半的时候，客户端和服务器都可以发送信号（RST_STREAM帧），取消这个数据流。1.1版取消数据流的唯一方法，就是关闭TCP连接。这就是说，HTTP/2 可以取消某一次请求，同时保证TCP连接还打开着，可以被其他请求使用。
客户端还可以指定数据流的优先级。优先级越高，服务器就会越早回应。

## 基于WebSocket的Web请求机制

看到HTTP/2中“数据流”的实现方案，突然想到我之前实现的一套基于WebSocket的Web请求机制好像也是这么完成的。下面贴一段核心的实现代码：

`webIO.js`：

```javascript
var socketio_client = require('socket.io-client');

window.io = socketio_client; // IE8 need io

var AppConstant = require('../constants/AppConstant.js');

window.WEB_SOCKET_SWF_LOCATION = AppConstant.PORTAL_CONTEXT_PATH + '/flash/WebSocketMain.swf';

var EventEmitter = require('events').EventEmitter;
var inherits = require('inherits');
var when = require('when');
var Logger = require('./Logger.js');
var AjaxAPI = require('./AjaxAPI.js');

var websocketHostName = window.location.hostname;

var WebIO = function(opts){
    EventEmitter.call(this);
    opts = opts || {};
    this.opts = opts;
    this.opts.reconnectionAttempts = this.opts.reconnectionAttempts || 5;
    this.opts.reconnectionDelay = this.opts.reconnectionDelay || 2000;
    this.opts.connectTimeout = this.opts.connectTimeout || (this.opts.reconnectionAttempts * this.opts.reconnectionDelay);
    this.opts.disconnectTimeout = this.opts.disconnectTimeout || 5000;
    this.connected = false;
};

inherits(WebIO, EventEmitter);

var connectPromise = null;

WebIO.prototype.connect = function(opts){
    var that = this;
    if(connectPromise === null || connectPromise.inspect().state !== 'pending'){
        opts = opts || {};
        connectPromise = when.promise(function(resolve, reject) {
            if (!that.connected) {
                var connectCb = function () {
                    resolve();
                };
                AjaxAPI.request(AppConstant.PORTAL_CONTEXT_PATH + '/api/getSocketIOAccessInfo', {
                    data: {
                        t : new Date().getTime()
                    },
                    dataType: 'json',
                    method: 'post',
                    cache: false
                }).then(function(data){
                    let socketIOPort;
                    if(window.location.protocol == 'https:'){
                        socketIOPort = data.socketIOHttpsAccessPort;
                    } else if(window.location.protocol == 'http:'){
                        socketIOPort = data.socketIOAccessPort;
                    }
                    let websocketHostName = window.location.hostname;
                    if(data.socketIOAccessHostName){
                        websocketHostName = data.socketIOAccessHostName;
                    }
                    that.socket = socketio_client.connect(window.location.protocol + '//' + websocketHostName + ':' + socketIOPort, {
                        reconnect: true,
                        'max reconnection attempts': that.opts.reconnectionAttempts,
                        'reconnection delay': that.opts.reconnectionDelay,
                        transports: ['websocket', 'flashsocket', 'xhr-polling'],
                        resource: 'portal_socketio',
                        'force new connection': true
                    });
                    that.socket.on('connect', function(){
                        that.connected = true;
                        that.emit('open');
                    });
                    that.socket.on('disconnect', function(){
                        if(that.connected) {
                            try {
                                that.socket.disconnect();
                            } catch (e) {}
                            that.connected = false;
                        }
                        that.emit('close');
                    });
                    that.socket.on('connect_failed', function(){
                        reject(new Error('connect failed'));
                    });
                    that.socket.on('data', function(data){
                        that.emit('msg', data);
                    });

                    that.socket.once('connect', connectCb);
                }, function(){
                    reject(new Error('connect failed'));
                });
            } else {
                resolve();
            }
        });
        connectPromise = connectPromise.timeout(that.opts.connectTimeout, 'connect timeout').then(undefined, function(e){
            that.disconnect();
            Logger.error(e);
        });
    }
    return connectPromise;
};

WebIO.prototype.disconnect = function(opts){
    var that = this;
    opts = opts || {};
    var promise = when.promise(function(resolve, reject) {
        if(that.connected){
            var disconnectCb = function(){
                resolve();
            };
            that.socket.once('disconnect', disconnectCb);
            try {
                that.socket.disconnect();
            } catch (e){
                reject(e);
            }
        } else {
            resolve();
        }
    });
    return promise.timeout(that.opts.disconnectTimeout, 'disconnect timeout').then(undefined, function(e){
        Logger.error(e);
    });
};

WebIO.prototype.sendData = function(opts){
    var that = this;
    opts = opts || {};
    opts.msg = opts.msg || '';
    return when.resolve().then(function(){
        if(that.connected){
            that.socket.emit('data', opts.msg);
        } else {
            throw new Error('not connected');
        }
    }).then(undefined, function(e){
        Logger.error(e);
    });
};

WebIO.prototype.isConnected = function(){
    return this.connected;
};

module.exports = new WebIO();
```

`webAPI.js`：

```javascript
var webIO = require('./webIO.js');
var when = require('when');
var Logger = require('./Logger.js');

var msgIdCounter = 0;
var REQ_TIMEOUT = 1000 * 60 * 5;
var reqCb = {};

var nextMsgId = function(){
    msgIdCounter = (msgIdCounter + 1) % (Number.MAX_VALUE - 1);
    return msgIdCounter;

};

var MSG_TYPE = {
    REQ_MSG : 0,
    RES_MSG : 1,
    ...
};

var webAPI = {};

webAPI.request = function(opts){
    opts = opts || {};
    if(!opts.path){
        throw new Error('path must not be empty');
    }
    opts.data = opts.data || {};
    var reqId = nextMsgId();
    window.isDebug && Logger.debug("webAPI request", reqId, opts);
    var promise = when.promise(function(resolve, reject) {
        webAPI.connect().then(function(){
            var sendReqMsg = function(){
                var msg = {
                    type: MSG_TYPE.REQ_MSG,
                    reqId: reqId,
                    path: opts.path,
                    body: opts.data
                };
                return webIO.sendData({
                    msg: JSON.stringify(msg)
                });
            };
            reqCb[reqId] = {'resovle': resolve, 'reject': reject};
            sendReqMsg().then(undefined, reject);
        }, reject);
    });
    promise = promise.timeout(REQ_TIMEOUT, 'request timeout').then(undefined, function(e){
        if (reqCb[reqId]) {
            delete reqCb[reqId];
        }
        Logger.error('webAPI.request :', e);
        throw e;
    });
    return promise;
};

webAPI.connect = function(opts){
    opts = opts || {};
    if(connectPromise === null || connectPromise.inspect().state !== 'pending'){
        connectPromise = when.promise(function(resolve, reject) {
            webIO.connect().then(function(){
                if(connected) {
                    resolve();
                } else {
                    reject();
                }
            }, reject);
        });
    }
    return connectPromise;
};

...

webIO.on('msg', function(data){
    var msg = JSON.parse(data);
    window.isDebug && Logger.debug("webAPI response", msg);
    var msgType = msg.type;
    if(msgType === MSG_TYPE.RES_MSG){
        var reqId = msg.reqId;
        var resp = msg.body;
        if(reqCb[reqId]){
            if(resp.success) {
                reqCb[reqId].resovle(resp);
            } else {
                var e = new Error(resp.msg);
                e.msg = resp.msg;
                reqCb[reqId].reject(e);
            }
            delete reqCb[reqId];
        }
    }
    ...
});

...

module.exports = webAPI;
```

上述代码中`webIO.js`比较复杂，因为封装了与WebSocket连接的相关细节，但只需要知道`webIO`利用`socketio-client`连接WebSocket服务端，并将其常用方法进行了封闭，均返回Promise对象就好了。`webAPI.js`就比较简单了，这里的request方法与HTTP/2的“数据流”实现一致，也是给每个请求加上一个编号，当响应回来时，根据这个编号找到对应的回调方法执行回调。

## 总结

看[阮一峰的这篇文章](http://www.ruanyifeng.com/blog/2016/08/http.html)终于扭转了我之前对HTTP异步请求的误解，看来还是应该多看书多思考。另外发现只要是认真思考出来的思路也不会太差。

## 参考

`http://www.ruanyifeng.com/blog/2016/08/http.html`
`https://developer.mozilla.org/en-US/docs/Web/HTTP/Connection_management_in_HTTP_1.x`
