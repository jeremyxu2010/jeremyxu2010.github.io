---
title: atom-shell小例子
author: Jeremy Xu
tags:
  - nodejs
  - atom-shell
  - node-webkit
categories:
  - nodejs开发
date: 2014-06-30 01:40:00+08:00
---

今天一个朋友问我一个问题，他想做一个win32的桌面应用程序，而且还希望程序能做出web页面那种漂亮的效果，可目前项目组的成员全是以前做前端的一批人，怎么办？

我想了一下，几乎毫不犹豫地推荐了node-webkit, 但又想起前段时间看到的atom-shell，于是也推荐了下atom-shell，随手写了个atom-shell的例子给他。

`package.json`

```json
{
  "name"    : "pingdemo",
  "version" : "0.1.0",
  "main"    : "main.js"
}
```

`main.js`

```javascript
var app = require('app');  // Module to control application life.
var BrowserWindow = require('browser-window');  // Module to create native browser window.

// Report crashes to our server.
require('crash-reporter').start();

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the javascript object is GCed.
var mainWindow = null;

// Quit when all windows are closed.
app.on('window-all-closed', function() {
  if (process.platform != 'darwin')
    app.quit();
});

// This method will be called when atom-shell has done everything
// initialization and ready for creating browser windows.
app.on('ready', function() {
  // Create the browser window.
  mainWindow = new BrowserWindow({width: 800, height: 600});

  // and load the index.html of the app.
  mainWindow.loadUrl('file://' + __dirname + '/index.html');

  // Emitted when the window is closed.
  mainWindow.on('closed', function() {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null;
  });
});
```

`index.html`

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Ping Demo</title>
  </head>
  <body>
    <h1>Ping Demo</h1>
    <input id="addr" type="text" name="addr" value="www.baidu.com"/>
    <input id="ping" type="button" name="ping" value="Ping"/>
    <div id="ping-result"></div>
    <script type="text/javascript" src="ping.js"></script>
  </body>
</html>
```

`ping.js`

```javascript
try {
  var child_process = require('child_process');
  window.$ = window.jQuery = require('./jquery');
} catch(e) {console.log(e)}

$('#ping').on('click', function (){
  var opts = {
    encoding: 'utf8',
    timeout: 2000,
    maxBuffer: 200*1024,
    killSignal: 'SIGKILL',
    cwd: null,
    env: null
  };
  var cmd = 'ping -t 1 -c 1 ' + $('#addr').val();
  var child = child_process.exec(cmd, opts, function(error, stdout, stderr) {
    $('#ping-result').empty();
    if(stdout.length > 0){
      $('#ping-result').append('<pre>' + stdout + '</pre>');
    }
    if(stderr.length > 0){
      $('#ping-result').append('<pre>' + stderr + '</pre>');
    }
  });
});
```

jquery.js从code.jquery.com/jquery-1.11.0.min.js下载过来重命名即可

上述所有文件放在一个PingDemo目录中

最后执行

```
/Applications/Atom.app/Contents/MacOS/Atom ./PingDemo/
```

想想java调用外部程序还要考虑那么多东西，这东西真心简单啊。
