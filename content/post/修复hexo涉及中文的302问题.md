---
title: 修复hexo涉及中文的302问题
tags:
  - nodejs
categories:
  - 工具
author: Jeremy Xu
date: 2017-02-17 20:26:00+08:00
---

今天在用hexo写博文时遇到一个涉及中文的302问题，记录一下。

当访问链接为`http://middle3.dev.vivo.xyz:4000/authors/测试`时，控制台报错：

```
TypeError: The header content contains invalid characters
   at ServerResponse.OutgoingMessage.setHeader (_http_outgoing.js:358:11)
   at /home/hexo/blog/node_modules/hexo-server/lib/middlewares/route.js:27:11
   at call (/home/hexo/blog/node_modules/connect/index.js:239:7)
   at next (/home/hexo/blog/node_modules/connect/index.js:183:5)
   at /home/hexo/blog/node_modules/hexo-server/lib/middlewares/header.js:9:5
   at call (/home/hexo/blog/node_modules/connect/index.js:239:7)
   at next (/home/hexo/blog/node_modules/connect/index.js:183:5)
   at Function.handle (/home/hexo/blog/node_modules/connect/index.js:186:3)
   at Server.app (/home/hexo/blog/node_modules/connect/index.js:51:37)
   at emitTwo (events.js:106:13)
   at Server.emit (events.js:191:7)
   at HTTPParser.parserOnIncoming [as onIncoming] (_http_server.js:546:12)
   at HTTPParser.parserOnHeadersComplete (_http_common.js:99:23)
```

跟踪了下`hexo-server/lib/middlewares/route.js`的代码如下：

```javascript
var url = route.format(decodeURIComponent(req.url));
var data = route.get(url);
var extname = pathFn.extname(url);

// When the URL is `foo/index.html` but users access `foo`, redirect to `foo/`.
if (!data) {
  if (extname) return next();

  res.statusCode = 302;
  res.setHeader('Location', root + url + '/');
  res.end('Redirecting');
  return;
}
```

这里`url`是decode出来的字符串，如果字符串里包含中文，然后调用`res.setHeader`方法即会报上面的错，解决方法也比较简单，加入一行即可：

```javascript
if (!data) {
  if (extname) return next();

  url = encodeURI(url);

  res.statusCode = 302;
  res.setHeader('Location', root + url + '/');
  res.end('Redirecting');
  return;
}
```

进一步查了下，[hexo-server](https://github.com/hexojs/hexo-server)的git版本是修复了这个问题的，见[这里](https://github.com/hexojs/hexo-server/blob/master/lib/middlewares/route.js)，但hexo依赖的hexo-server@0.2.0版本却没有修复这个问题，估计很多非英语用户都会遇到这个问题，真坑爹！
