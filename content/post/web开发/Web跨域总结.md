---
title: Web跨域总结
tags:
  - web
  - html5
  - javascript
  - cors
  - jsonp
categories:
  - web开发
date: 2016-05-11 00:46:00+08:00
---
## 什么是同源

浏览器安全的基石是"同源政策"，所有浏览器都实行这个政策。所谓两个网页"同源"指的两个网页的"协议相同"、"域名相同"、"端口相同"。

## 浏览器为什么遵循同源政策

同源政策的目的，是为了保证用户信息的安全，防止恶意的网站窃取数据。设想这样一种情况：A网站是一家银行，用户登录以后，又去浏览其他网站。如果其他网站可以读取A网站的 Cookie，将会产生严重的信息安全问题。

## 不同源的两个网页有哪些限制

* 各自无法读取对方的Cookie、LocalStorage 和 IndexDB
* 各自无法操作对方的DOM
* 各自无法发送AJAX请求至对方的地址

## 如何规避限制

虽然上述限制是必要的，但是有时很不方便，合理的用途也受到影响，下面说一下如何规避。

### 不同源页面之间共享Cookie

如果两个网页一级域名相同，只是二级域名不同，浏览器允许通过设置`document.domain`共享 Cookie。示例如下

`http://a.test.com:8000/test1.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test1</title>
</head>
<body>
<script type="text/javascript">
    document.domain = 'test.com';
    document.cookie = "test1=hello;domain=.test.com";
</script>
</body>
</html>
```

`http://b.test.com:8000/test2.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test2</title>
</head>
<body>
<script type="text/javascript">
    document.domain = 'test.com';
    var allCookie = document.cookie;
    console.log(allCookie);
</script>
</body>
</html>
```

在上面的示例里，先用浏览器在一个标签页里访问`http://a.test.com:8000/test1.html`，再在另一个标签页里访问`http://b.test.com:8000/test2.html`，可以发现在`test2.html`里可以访问`test1.html`里设置的Cookie。这种方法虽然简单，但LocalStorage 和 IndexDB 无法通过这种方法规避同源政策。

### 不同源的父子页面之间互访JS对象、DOM对象

正常情况下两个页面本身也没有互操作DOM的需求，但在使用`iframe`窗口或`window.open`打开窗口时，经常存在父窗口需要与子窗口互访JS对象、DOM对象。这个时候如果父子窗口刚好不满足同源政策，这种互访操作将无法进行。

同样如果这两个网页一级域名相同，只是二级域名不同，浏览器允许通过设置`document.domain`允许这种互访操作。示例如下

`http://a.test.com:8000/test1.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test1</title>
</head>
<body>
<script type="text/javascript">
    document.domain = 'test.com';
    var myJsVar1 = 'test1JsVar';
    window.setTimeout(function(){
            console.log(document.getElementById("myIFrame").contentWindow.document);
            console.log(document.getElementById("myIFrame").contentWindow.myJsVar2);
    }, 2000);
</script>
<iframe id="myIFrame" src="http://b.test.com:8000/test2.html"/>
</body>
</html>
```

`http://b.test.com:8000/test2.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test2</title>
</head>
<body>
<script type="text/javascript">
    document.domain = 'test.com';
    var myJsVar2 = 'test2JsVar';
    window.setTimeout(function(){
            console.log(parent.document);
            console.log(parent.myJsVar1);
    }, 2000);
</script>
</body>
</html>
```

### 使用window.postMessage在不同源的父子页面间传递消息

不同源的父子页面间传递消息，除了使用`document.domain`方案，其实还存在其它3种方案：

* 片段识别符（fragment identifier）
* 通过window.name属性
* 通过window.postMessage方法

其中前两种方法限制较多，而且感觉像是奇技淫巧，这里就不介绍了。这里重点说一下`window.postMessage`方法。

HTML5为了解决不同源页面间消息传递的问题，引入了一个全新的API：跨文档通信 API（Cross-document messaging）。

这个API为window对象新增了一个window.postMessage方法，允许跨窗口通信，不论这两个窗口是否同源。示例如下

`http://a.test.com:8000/test1.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test1</title>
</head>
<body>
<script type="text/javascript">
    window.addEventListener('message', function(e) {
      console.log(e.data);
    },false);
    window.setTimeout(function(){
        document.getElementById("myIFrame").contentWindow.postMessage('say hello to test2', 'http://b.test.com:8000');
    }, 2000);
</script>
<iframe id="myIFrame" src="http://b.test.com:8000/test2.html"/>
</body>
</html>
```

`http://b.test.com:8000/test2.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test2</title>
</head>
<body>
<script type="text/javascript">
    window.addEventListener('message', function(e) {
      console.log(e.data);
    },false);
    window.setTimeout(function(){
        window.parent.postMessage('say hello to test1', 'http://a.test.com:8000');
    }, 2000);
</script>
</body>
</html>
```

`postMessage`方法的第一个参数是具体的信息内容，第二个参数是接收消息的窗口的源（origin），即"协议 + 域名 + 端口"。也可以设为*，表示不限制域名，向所有窗口发送。

`message`事件的事件对象event，提供以下三个属性。

* event.source：发送消息的窗口
* event.origin: 消息发向的网址
* event.data: 消息内容

可以通过使用`event.source`属性拿到发送消息的窗口句柄，进而再使用`postMessage`向之传递消息。`event.origin`属性可以过滤不是发给本窗口的消息，如下

```javascript
    window.addEventListener('message', function(e) {
      if (e.origin !== 'http://a.test.com:8000') return;
      e.source.postMessage('Hello', event.origin);
    },false);
```

使用`postMessage`，花点心思，操作非同源页面的LocalStorage也可能了，如下

`http://a.test.com:8000/test1.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test1</title>
</head>
<body>
<script type="text/javascript">
    window.setTimeout(function(){
        var obj = { name: 'Jack' };
        document.getElementById("myIFrame").contentWindow.postMessage(JSON.stringify({key: 'storage', data: obj}), 'http://a.test.com:8000');
    }, 2000);
</script>
<iframe id="myIFrame" src="http://b.test.com:8000/test2.html"/>
</body>
</html>
```

`http://b.test.com:8000/test2.html`

```html
<!DOCTYPE html>
<html>
<head>
    <title>Test2</title>
</head>
<body>
<script type="text/javascript">
    window.addEventListener('message', function(e) {
        var payload = JSON.parse(e.data);
        localStorage.setItem(payload.key, JSON.stringify(payload.data));
    },false);
</script>
</body>
</html>
```

### 使用JSONP向不同源的站点发送AJAX请求

JSONP是服务器与客户端跨源通信的常用方法。最大特点就是简单适用，老式浏览器全部支持，服务器改造非常小。

它的基本思想是，网页通过添加一个`<script>`元素，向服务器请求JSON数据，这种做法不受同源政策限制；服务器收到请求后，将数据放在一个指定名字的回调函数里传回来。

这种方式用起来很简单，甚至jQuery都提供了一种请求类型`jsonp`，缺陷是请求的服务端必须进行改造，需要以`jsonp`的方式返回响应。

```javascript
/ Using YQL and JSONP
$.ajax({
     type: "get",
     url: "http://b.test.com:8000/api/getUserInfo",
     dataType: "jsonp",//指定以jsonp方式執行
     data: {
      userId : 3
     },
     success: function(res){
         alert(res.msg);
     },
     error: function(){
         alert('fail');
     }
 });
```

### 使用CORS向不同源的站点发送AJAX请求

CORS是跨源资源分享（Cross-Origin Resource Sharing）的缩写。它是W3C标准，是跨源AJAX请求的根本解决方法。相比JSONP只能发GET请求，CORS允许任何类型的请求。

CORS请求分成两类：简单请求（simple request）和非简单请求（not-so-simple request）。

#### 简单CORS请求

只要同时满足以下两大条件，就属于简单请求。

* 请求方法是以下三种方法之一：
  * HEAD
  * GET
  * POST

* HTTP的头信息包含以下几种字段：
  * Accept
  * Accept-Language
  * Content-Language
  * Last-Event-ID
  * Content-Type：只限于三个值application/x-www-form-urlencoded、multipart/form-data、text/plain

简单请求的特征是浏览器本身就可以不依赖于CORS成功发送请求至服务端。比如一个JSONP请求可以被看作是一个简单CORS GET请求。一个普通的表单提交请求可以被看作是一个简单的CORS POST请求。

凡是不同时满足上面两个条件，就属于非简单请求。

##### 简单CORS请求流程

浏览器发现这次跨源AJAX请求是简单请求，就自动在头信息之中，添加一个`Origin`字段。

```
GET /api/getUserInfo HTTP/1.1
Origin: http://a.test.com:8000
Host: b.test.com
Accept-Language: en-US
Connection: keep-alive
User-Agent: Mozilla/5.0...
```

如果`Origin`指定的源，不在许可范围内，服务器会返回一个正常的HTTP回应。浏览器发现，这个回应的头信息没有包含`Access-Control-Allow-Origin`字段，浏览器就知道出错了，从而抛出一个错误，被XMLHttpRequest的onerror回调函数捕获。

如果Origin指定的域名在许可范围内，服务器返回的响应，会多出几个头信息字段。

```
Access-Control-Allow-Origin: http://a.test.com:8000
Access-Control-Allow-Credentials: true
Access-Control-Expose-Headers: FooBar
Content-Type: text/html; charset=utf-8
```

上面的头信息之中，有三个与CORS请求相关的字段，都以`Access-Control-`开头。

* Access-Control-Allow-Origin
该字段是必须的。它的值要么是请求时Origin字段的值，要么是一个*，表示接受任意域名的请求。

* Access-Control-Allow-Credentials
  该字段可选。它的值是一个布尔值，表示是否允许发送Cookie。设为true，即表示服务器明确许可，Cookie可以包含在请求中，一起发给服务器。这个值也只能设为true，如果服务器不要浏览器发送Cookie，删除该字段即可。
  默认情况下，Cookie和HTTP认证信息不包括在CORS请求之中，要将Cookie和HTTP认证信息包含到CORS请求里发送到服务端，首先发送AJAX请求时需打开withCredentials属性。

  ```javascript
  var xhr = new XMLHttpRequest();
  xhr.withCredentials = true;
  ```

  其次服务端必须返回

  ```
  Access-Control-Allow-Credentials: true
  ```

  上述两个条件都满足，CORS请求才会成功。如果其中只有一个为`true`，则请求会失败。

* Access-Control-Expose-Headers
该字段可选。CORS请求时，XMLHttpRequest对象的getResponseHeader()方法只能拿到6个基本字段：Cache-Control、Content-Language、Content-Type、Expires、Last-Modified、Pragma。如果想拿到其他字段，就必须在Access-Control-Expose-Headers里面指定。上面的例子指定，getResponseHeader('FooBar')可以返回FooBar字段的值。

#### 非简单CORS请求

非简单请求是那种对服务器有特殊要求的请求，比如请求方法是`PUT`或`DELETE`，或者`Content-Type`字段的类型是`application/json`。

非简单请求的CORS请求，会在正式通信之前，增加一次HTTP查询请求，称为"预检"请求（preflight）。

浏览器先询问服务器，当前网页所在的域名是否在服务器的许可名单之中，以及可以使用哪些HTTP动词和头信息字段。只有得到肯定答复，浏览器才会发出正式的XMLHttpRequest请求，否则就报错。

示例如下

首先浏览器发送一个非简单的CORS请求。

```javascript
var url = 'http://b.test.com:8000/api/createUser';
var xhr = new XMLHttpRequest();
xhr.open('PUT', url, true);
xhr.setRequestHeader('X-Custom-Header', 'value');
xhr.send();
```

浏览器发现，这是一个非简单请求，就自动发出一个"预检"请求，要求服务器确认可以这样请求。下面是这个"预检"请求的HTTP头信息。

```
OPTIONS /cors HTTP/1.1
Origin: http://a.test.com:8000
Access-Control-Request-Method: PUT
Access-Control-Request-Headers: X-Custom-Header
Host: b.test.com
Accept-Language: en-US
Connection: keep-alive
User-Agent: Mozilla/5.0...
```

"预检"请求用的请求方法是OPTIONS，表示这个请求是用来询问的。头信息里面，关键字段是Origin，表示请求来自哪个源。
除了Origin字段，"预检"请求的头信息包括两个特殊字段。

* `Access-Control-Request-Method` 该字段是必须的，用来列出浏览器的CORS请求会用到哪些HTTP方法，上例是`PUT`。
* `Access-Control-Request-Headers` 该字段是一个逗号分隔的字符串，指定浏览器CORS请求会额外发送的头信息字段，上例是`X-Custom-Header`

服务器收到"预检"请求以后，检查了`Origin`、`Access-Control-Request-Method`和`Access-Control-Request-Headers`字段以后，确认允许跨源请求，就可以做出回应。

```
HTTP/1.1 200 OK
Date: Mon, 01 Dec 2008 01:15:39 GMT
Server: Apache/2.0.61 (Unix)
Access-Control-Allow-Origin: http://a.test.com:8000
Access-Control-Allow-Methods: GET, POST, PUT
Access-Control-Allow-Headers: X-Custom-Header
Content-Type: text/html; charset=utf-8
Content-Encoding: gzip
Content-Length: 0
Keep-Alive: timeout=2, max=100
Connection: Keep-Alive
Content-Type: text/plain
```

上面的HTTP回应中，关键的是`Access-Control-Allow-Origin`字段，表示`http://a.test.com:8000`可以请求数据。该字段也可以设为星号，表示同意任意跨源请求。

如果浏览器否定了"预检"请求，会返回一个正常的HTTP回应，但是没有任何CORS相关的头信息字段。这时，浏览器就会认定，服务器不同意预检请求，因此触发一个错误，被`XMLHttpRequest`对象的`onerror`回调函数捕获。

服务器回应的其他CORS相关字段如下

```
Access-Control-Allow-Methods: GET, POST, PUT
Access-Control-Allow-Headers: X-Custom-Header
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 1728000
```

CORS"预检"响应字段意义如下：

* `Access-Control-Allow-Methods` 该字段必需，它的值是逗号分隔的一个字符串，表明服务器支持的所有跨域请求的方法。注意，返回的是所有支持的方法，而不单是浏览器请求的那个方法。这是为了避免多次"预检"请求。
* `Access-Control-Allow-Headers` 如果浏览器请求包括`Access-Control-Request-Headers`字段，则`Access-Control-Allow-Headers`字段是必需的。它也是一个逗号分隔的字符串，表明服务器支持的所有头信息字段，不限于浏览器在"预检"中请求的字段。
* `Access-Control-Allow-Credentials` 该字段与简单请求时的含义相同。
* `Access-Control-Max-Age` 该字段可选，用来指定本次预检请求的有效期，单位为秒。上面结果中，有效期是20天（1728000秒），即允许缓存该条回应1728000秒（即20天），在此期间，不用发出另一条预检请求。

一旦服务器通过了"预检"请求，以后每次浏览器正常的CORS请求，就都跟简单请求一样，会有一个`Origin`头信息字段。服务器的回应，也都会有一个`Access-Control-Allow-Origin`头信息字段。

"预检"请求之后，浏览器的正常CORS请求

```
PUT /api/createUser HTTP/1.1
Origin: http://a.test.com:8000
Host: b.test.com
X-Custom-Header: value
Accept-Language: en-US
Connection: keep-alive
User-Agent: Mozilla/5.0...
```

上面头信息的`Origin`字段是浏览器自动添加的。然后服务器正常的回应`Access-Control-Allow-Origin`。

```
Access-Control-Allow-Origin: http://a.test.com:8000
Content-Type: text/html; charset=utf-8
```

## 总结

* 如果非同源页面间消息传递，应该优选`window.postMessage`方案。如果两个网页一级域名相同，只是二级域名不同，也可以采用`document.domain`方案。

* AJAX请求非同源站点，应该优选`CORS`方案，如果方便对服务端接口进行改造，也可以使用`JSONP`方案

