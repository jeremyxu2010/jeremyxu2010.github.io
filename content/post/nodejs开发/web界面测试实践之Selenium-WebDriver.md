---
title: WEB界面测试实践之Selenium WebDriver
tags:
  - nodejs
  - webdriver
  - es6
categories:
  - nodejs开发
date: 2016-05-22 22:54:00+08:00
---
工作中需要对web界面进行测试，在网上找了找解决方案，最终找到了`Selenium WebDriver`。

## WebDriver简介


> The primary new feature in Selenium 2.0 is the integration of the WebDriver API. WebDriver is designed to provide a simpler, more concise programming interface in addition to addressing some limitations in the Selenium-RC API. Selenium-WebDriver was developed to better support dynamic web pages where elements of a page may change without the page itself being reloaded. WebDriver’s goal is to supply a well-designed object-oriented API that provides improved support for modern advanced web-app testing problems.

> Selenium-WebDriver makes direct calls to the browser using each browser’s native support for automation. How these direct calls are made, and the features they support depends on the browser you are using. Information on each ‘browser driver’ is provided later in this chapter.

> For those familiar with Selenium-RC, this is quite different from what you are used to. Selenium-RC worked the same way for each supported browser. It ‘injected’ javascript functions into the browser when the browser was loaded and then used its javascript to drive the AUT within the browser. WebDriver does not use this technique. Again, it drives the browser directly using the browser’s built in support for automation.

上面的官方介绍，我简单提练一下：

* `WebDriver API`相对于`Selenium Remote Control API`来说，虽然同样是控制浏览器，但它的编程接口更加简洁
* `WebDriver`可以应对那些网页本身不重新加载的动态网页。
* `Selenium Remote Control`是采用向浏览器注入javascript脚本来控制浏览器的，但`WebDriver`与之不同，它是直接使用浏览器内置的自动化支持来控制浏览器的。

`WebDriver`实际上就像它的名字一样，向上屏蔽各厂商浏览器的差异，提供了一个统一的编程API，方便广大程序员控制浏览器的行为。

## WebDriver的Driver

即然要屏蔽各厂商浏览器的差异，那么各厂商自然需要根据`WebDriver`规范作出各自的实现。`WebDriver`官方文档就列出各实现：`HtmlUnit Driver`、`Firefox Driver`、`InternetExplorerDriver`、`ChromeDriver`、`Opera Driver`、`iOS Driver`、`Android Driver`。这些`Driver`各有优缺点及各自适用的场景，具体可看[官方文档说明](http://www.seleniumhq.org/docs/03_webdriver.jsp#selenium-webdriver-s-drivers)。其实一看这些名字就知道是什么意思，要控制哪种浏览器就需要下载安装对应的`Driver`。比如我这里是Mac OSX系统，而且想控制该系统上的Chrome浏览器，那么就下载[chromedriver_mac32.zip](http://chromedriver.storage.googleapis.com/2.21/chromedriver_mac32.zip)(注意该Driver对你的Chrome浏览器有版本要求，要求版本必须是v46-50这个范围)，将该压缩包里的可执行文件放到PATH环境变量目录中，比如放到/usr/local/bin目录中。

## WebDriver的SDK的API介绍

官方还很贴心地为`WebDriver`提供了更主流语言的SDK。支持的语言有`Java`、`C#`、`Python`、`Ruby`、`Perl`、`PHP`、`JavaScript`。但我感觉这种测试相关的编程语言最好还是用脚本语言合适一点，改起来很方便，不需要时时编译。因此我最后选择了`JavaScript SDK`。安装过程见下面的命令：

```bash
//前提是先安装好NodeJS
mkdir test && cd test
npm init //这里根据提示一步步初始化一个新的NodeJS项目
npm install selenium-webdriver --save //安装WebDriver JavaScript SDK的npm依赖
```

## 使用WebDriver控制浏览器

```javascript
var webdriver = require('selenium-webdriver'),
    By = require('selenium-webdriver').By,
    until = require('selenium-webdriver').until;

var driver = new webdriver.Builder()
    .forBrowser('chrome')
    .build();

driver.get('http://www.google.com/ncr');
driver.findElement(By.name('q')).sendKeys('webdriver');
driver.findElement(By.name('btnG')).click();
driver.wait(until.titleIs('webdriver - Google Search'), 1000);
driver.quit();
```

上面是一个最简单的例子，它以沙箱方式打开一个Chrome窗口，然后访问`http://www.google.com/ncr`，再在搜索框中输入`webdriver`，再点击搜索按钮，最后等待浏览器显示出搜索结果页面后关闭浏览器窗口。

这个小例子确实简单了一些，接下来我们看一下`WebDriver`的其它一些常用的API。

### 定位UI元素 

* 根据ID定位：driver.findElement(By.id('eleID'));
* 根据Class类名定位：driver.findElements(By.className("eleCls"))
* 根据tag名定位：driver.findElement(By.tagName('iframe'));
* 根据name属性定位：driver.findElement(By.name('eleName'));
* 根据链接的文字定位：driver.findElement(By.linkText('linkText'));
* 根据链接的部分文字定位：driver.findElement(By.linkText('partialLinkText'));
* 根据CSS3的css selector定位：driver.findElement(By.css('#food span.dairy.aged'));
* 根据XPath定位：driver.findElements(By.xpath("//input"));

这么多种定位UI元素的办法，总有一款可以适应你的需求。我个人比较喜欢使用`css selector`来定位元素。要得到一个元素的`css selector`也很简单，只需要使用Chrome的开发者工具查看这个元素，然后在这个元素上右键，点击`Copy selector`就得到了(当然如有可能最好对得到的css selector简写一下)。

### 对UI元素的操作

* 取得元素的text values: driver.findElement(By.id('elementID')).getText();
* 查找多个元素：driver.findElement(By.tagName("select")).findElements(By.tagName("option"));
* 清空input元素的内容：driver.findElement(By.id('nameInput')).clear();
* 向input元素输入文字：driver.findElement(By.id('nameInput')).sendKeys('abcd');
* 向文件input元素指定文字：driver.findElement(By.id('fileInput')).sendKeys('/tmp/somefile.txt');
* 点击按钮：driver.findElement(By.id('submit').click();
* 提交表单：driver.findElement(By.id('submit').submit();

### 在窗口或Frame间移动

* 切换到窗口: driver.switchTo().window('windowName');
* 切换到Frame: driver.switchTo().frame('frameName');
* 取得当前窗口的Handle: driver.getWindowHandle();
* 列出所有浏览器窗口的Handles: driver.getAllWindowHandles();

### 操作Alert窗口

*  点击Alert窗口中的OK：driver.switchTo().alert().accept();
*  点击Alert窗口中的Cancel：driver.switchTo().alert().dismiss();
*  向Alert窗口输入文字：driver.switchTo().alert().sendKeys('abcd');

### 操作浏览器的导航及地址栏

* 导航到某个URL：driver.navigate().to('`http://www.baidu.com`');或driver.get('`http://www.baidu.com`');
* 导航后退：driver.navigate().back();
* 导航前进：driver.navigate().forward();
* 导航刷新：driver.navigate().refresh();

### 操作Cookie

* 得到所有Cookie：driver.manage().getCookies();
* 得到某一个Cookie：driver.manage().getCookie('cookieName');
* 删除所有Cookie：driver.manage().deleteAllCookies();
* 删除某一个Cookie：driver.manage().deleteCookie('cookieName');
* 添加一个Cookie：driver.manage().addCookie('cookieName', 'cookieValue');

### 操作窗口

* 设置窗口位置：driver.manage().window().setPosition(100, 100);
* 设置窗口大小：driver.manage().window().setSize(1280, 800);
* 最大化窗口：driver.manage().window().maximize();

### 高级用户接口

* 移动鼠标至某个UI元素：driver.actions().mouseMove(ele).perform();
* 鼠标按下：driver.actions().mouseDown().perform();
* 鼠标抬起：driver.actions().mouseUp().perform();
* 拖拽鼠标：driver.actions().dragAndDrop(ele, {x: 100, y: 80}).perform();
* 鼠标点击：driver.actions().click().perform();
* 鼠标双击：driver.actions().doubleClick().perform();
* 按键按下：driver.actions().keyDown(Key.CONTROL).perform();
* 按键抬起：driver.actions().keyUp(Key.CONTROL).perform();
* 发送按钮：driver.actions().sendKeys().perform(Key.chord(Key.CONTROL, 'c'));

上述这些在`actions()`与`perform()`之间的操作是可以串行执行的，如`driver.actions().mouseMove(ele).click().perform();`

### 操作等待

* 显式等待：driver.sleep(2000);
* `Wait for Expected Condition`: driver.wait(until.titleIs('webdriver - Google Search'), 5000);

上述`Wait for Expected Condition`的意思是说等待`Condition`满足，但如果等待的时间超过指定的值`Condition`还是没有满足，则抛出异常。第一种方式傻傻地等也不太好，因此一般也推荐使用第二种办法来做操作等待。这样可以尽可能快地完成测试的操作序列。

JavaScript SDK内置了很多方便产生`Condition`的方法，如：

* until.ableToSwitchToFrame('frameName');
* until.alertIsPresent();
* until.titleIs('test');
* until.titleContains('test');
* until.titleMatches(/test/);
* until.elementLocated(By.css('.test-cls'));
* until.elementsLocated(By.css('.test-cls'));
* until.stalenessOf(ele);
* until.elementIsVisible(ele);
* until.elementIsNotVisible(ele);
* until.elementIsEnabled(ele);
* until.elementIsDisabled(ele);
* until.elementIsSelected(ele);
* until.elementIsNotSelected(ele);
* unitl.elementTextIs(ele, 'test');
* until.elementTextContains(ele, 'test');
* until.elementTextMatches(ele, /test/);

上述这些方法含义很明确了，看方法名就可以了。另外自己也可以写产生`Condition`的方法，如下面的代码：

```javascript
//产生是否可以切换至第二个窗口Condition的方法
function ableToSwitchToSecondWindow() {
  return new Condition('to be able to switch to second window', function (driver) {
    return driver.getAllWindowHandles().then(function(winHandles){
        if(winHandles.length === 2) {
            return true;
        } else {
            throw new NoSuchWindowError('second window is not present');
        }
    }, function(e){
        if (!(e instanceof error.NoSuchWindowError)) {
            throw e;
          }
    });
  });
};

driver.wait(ableToSwitchToSecondWindow(), 5000);
```

`WebDriver JavaScript API`大概就上面这些内容了，还是比较简单的。其实我感觉官方的文档还是写得太简略了，只需要有个大致印象，真要查找特别API接口时直接查看`selenium-webdriver/lib`目录下的源码就好了，npm包的另一好处是基本也不用太写文档，源码即文档。

## 特别要注意的地方

### 绝大部分接口返回值都是Promise

这也是说最前面那个例子本来应该要像下面这样写的

```javascript
var webdriver = require('selenium-webdriver'),
    By = require('selenium-webdriver').By,
    until = require('selenium-webdriver').until;

var driver = new webdriver.Builder()
    .forBrowser('chrome')
    .build();

driver.get('http://www.google.com/ncr')
  .then(function(){
    return driver.findElement(By.name('q')).sendKeys('webdriver');
  })
  .then(function(){
    return driver.findElement(By.name('btnG')).click();
  })
  .then(function(){
    return driver.wait(until.titleIs('webdriver - Google Search'), 1000);
  })
  .then(function(){
    return driver.quit();
  });
```

但这样写就成`then hell`了，看起来仅仅比那个著名的[callback hell](http://callbackhell.com/)好一点点，但仍然很难看。幸好ES6推出了Generator函数，大神也写了`co`，现在终于可以比较好地解决Promise的`then hell`问题了。详见我之前关于[Generator函数的日志](/2016/05/06/koa%E6%A1%86%E6%9E%B6%E6%BA%90%E7%A0%81%E8%A7%A3%E8%AF%BB/)。而且`WebDriver JavaScript API`自已还提供Generator函数的执行器，连`co`模块都不用导入了。总之现在可以写成这样了：

```javascript
var webdriver = require('selenium-webdriver'),
    By = require('selenium-webdriver').By,
    until = require('selenium-webdriver').until;

var driver = new webdriver.Builder()
    .forBrowser('chrome')
    .build();

driver.call(function * () {
  yield driver.get('http://www.google.com/ncr');
  yield driver.findElement(By.name('q')).sendKeys('webdriver');
  yield driver.findElement(By.name('btnG')).click();
  yield driver.wait(until.titleIs('webdriver - Google Search'), 1000);
  yield driver.quit();
});
```

虽然JavaScript方法都是异步的，有了Generator函数，至少在形式上很像同步的写法了。

### 控制NodeJS主线程

凡是上述使用driver的脚本，其实是交给`Driver`执行去了，一旦NodeJS将这些脚本交给`Driver`了，NodeJS主线程的工作就完成了，NodeJS主线程的事件队列里没有其它事件需要处理，因此NodeJS主线程就退出了。但有时我们想在用户自动按Ctrl+C结束脚本执行后做一些清理工作，比如关闭打开的浏览器窗口。于是想了点办法，于是写了下面的代码：

```javascript
var webdriver = require('selenium-webdriver'),
    By = require('selenium-webdriver').By,
    until = require('selenium-webdriver').until;

var driver = new webdriver.Builder()
    .forBrowser('chrome')
    .build();

driver.call(function * () {
  while(true){
    yield driver.get('http://www.google.com/ncr');
    yield driver.findElement(By.name('q')).sendKeys('webdriver');
    yield driver.findElement(By.name('btnG')).click();
    yield driver.wait(until.titleIs('webdriver - Google Search'), 1000);
  }
});

var running = true;

var rl = null;

function shutdown(exitCode){
    running = false;
    if(rl){
      rl.close();
    }
    //nodejs主线程退出时一定关闭打开的浏览器
    driver.quit().then(function(){
        process.exit(exitCode);
    }, function(e){
        process.exit(exitCode);
    });
}

//block to nodejs's main thread
(function wait () {
    if(running){
        setTimeout(wait, 500);
    }
})();

//Windows平台需要这样监听Ctrl+C事件
if (process.platform === "win32") {
  rl = require("readline").createInterface({
    input: process.stdin,
    output: process.stdout
  });

  rl.on("SIGINT", function () {
    shutdown(0);
  });
}

process.on('SIGINT', function() {
    shutdown(0);
});
```

关键是使用一个递归调用保持NodeJS主线程的事件队列里一直有事件，另外用户按了Ctrl+C后主动关闭浏览器。

### 同时进行多个测试

一开始并不知道`WebDriver JavaScript SDK`支持多个测试同时进行，因此还搞了个主进程控制多个子进程的实现。主要代码如下：

parent.js

```javascript
var child_process = require('child_process');
var process = require('process');
var co = require('co');

var child_processes = [];

var child_count = process.argv[2];

var running = true;

function sleep(ms){
    return new Promise(function(resolve, reject){
        setTimeout(function(){
            if(running){
                resolve();
            } else {
                reject();
            }
        }, ms);
    });
}

function restartChildProcess(j){
    return function(){
        console.log('restart child process ' + j);
        co(startChildProcess(j));
    };
}

function * startChildProcess(j){
    console.log('start child process ' + j);
    var p = child_process.exec('node ' + __dirname + '/child.js ' + j + ' 2>&1' , function(err, stdout,stderr){
        if(err){
            p.kill();
            var idx = child_processes.indexOf(p);
            if(idx > -1){
                child_processes.splice(idx, 1);
            }
            p = null;
            if(running){
                process.nextTick(restartChildProcess(j));
            }
        }
    });
    child_processes.push(p);
    yield sleep(20000);
}

co(function * (){
    for(var j=0; j<child_count; j++){
        if(running){
            yield * startChildProcess(j);
        }
    }
}).then(function(){
    console.log('all child processes started');
});

function shutdown(){
    running = false;
    for(var i=0; i<child_processes.length; i++){
        child_processes[i].kill();
    }
}

//block to nodejs's main thread
(function wait () {
    if(running){
        setTimeout(wait, 500);
    }
})();

if (process.platform === "win32") {
  var rl = require("readline").createInterface({
    input: process.stdin,
    output: process.stdout
  });

  rl.on("SIGINT", function () {
    console.log("Caught interrupt signal");
    shutdown();
  });
}

process.on('SIGINT', function() {
    console.log("Caught interrupt signal");
    shutdown();
});
```

child.js

```javascript
'use strict';

const webdriver = require('selenium-webdriver'),
    By = webdriver.By,
    until = webdriver.until;

const process = require('process');

var driver = new webdriver.Builder().forBrowser('chrome').build();

driver.call(function * (){
  try {
    ...
  } catch (e){
      //发生异常时打印异常并退出nodejs's main thread
      console.log(e);
      shutdown(-1);
  }
});

var running = true;

var rl = null;

function shutdown(exitCode){
    running = false;
    if(rl){
      rl.close();
    }
    //nodejs主线程退出时一定关闭打开的浏览器
    driver.quit().then(function(){
        process.exit(exitCode);
    }, function(e){
        process.exit(exitCode);
    });
}

//block to nodejs's main thread
(function wait () {
    if(running){
        setTimeout(wait, 500);
    }
})();

if (process.platform === "win32") {
  rl = require("readline").createInterface({
    input: process.stdin,
    output: process.stdout
  });

  rl.on("SIGINT", function () {
    shutdown(0);
  });
}


process.on('SIGINT', function() {
    shutdown(0);
});
```

这样写虽然也能解决问题，但每个测试示例都要对应一个node进程，而且还需要一个父node进程，进程数多了之后进程间切换开销也很大。

后面翻阅`selenium-webdriver`的源码，在它的examples里找到了`parallel_flows.js`，原来`WebDriver JavaScript SDK`本身也是支持多个测试同时进行的。于是改进了原来的代码，如下：

```javascript
'use strict';

const webdriver = require('selenium-webdriver'),
    By = webdriver.By,
    until = webdriver.until;

const flow_interval = 30000;

let drivers = {};

let running = true;

function restartFlow(flowNo){
    return function(){
        if(running) {
            console.log('restart flow ' + flowNo);
            console.log('quit flow ' + flowNo + '\'s driver');
            try {
                drivers[flowNo].controlFlow().reset();
            } catch(e){
                console.log('reset flow ' + flowNo + '\'s controlFlow failed: %s', e);
            }
            drivers[flowNo].quit().then(function(){
                drivers[flowNo] = null;
                runOneFlow(flowNo, true);
            }, function(e){
                console.log('quit flow ' + flowNo + ' failed: %s', e);
            });
        }
    };
}

function runOneFlow(flowNo, noSleep){
    console.log('start flow ' + flowNo);
    let flow = new webdriver.promise.ControlFlow()
        .on('uncaughtException', function(e) {
            //console.log('uncaughtException in flow %d: %s', flowNo, e);
            process.nextTick(restartFlow(flowNo));
        });

    let driver = new webdriver.Builder().
        forBrowser('chrome').
        setControlFlow(flow).  // Comment out this line to see the difference.
        build();

    drivers[flowNo]=driver;

    driver.call(function* () {

        // Position and resize window so it's easy to see them running together.
        yield driver.manage().window().setSize(1280, 800);
        yield driver.manage().window().setPosition(90 * flowNo, 80 * flowNo);

        if(!noSleep){
            yield driver.sleep(flow_interval * flowNo);
        }

        ...
    });
}

for (let i = 0; i < session_count; i++) {
  runOneFlow(i);
}

function quitAllDrivers(){
    for(let i=0; i<drivers.length; i++){
        try {
            drivers[i].controlFlow().reset();
        } catch (e) {
            console.log('reset flow ' + i + '\'s controlFlow failed: %s', e);
        }
        drivers[i].quit().then(undefined, function(e){
            console.log('quit flow ' + i + ' failed: %s', e);
        });
    }
}

var rl = null;

function shutdown(){
    running = false;
    if(rl){
      rl.close();
    }
    //进程退出时关闭打开的浏览器
    quitAllDrivers();
}

//block to nodejs's main thread
(function wait () {
    if(running){
        setTimeout(wait, 500);
    }
})();

if (process.platform === "win32") {
  rl = require("readline").createInterface({
    input: process.stdin,
    output: process.stdout
  });

  rl.on("SIGINT", function () {
    shutdown();
  });
}


process.on('SIGINT', function() {
    shutdown();
});
```

终于是运行多个测试终于只有一个node进程了。

## 经验教训

以后使用第三方重要库决不能只看它给出的文档，还是应该仔细看一看人家给出的使用示例。

## 参考

`http://www.seleniumhq.org/docs/03_webdriver.jsp`
`http://www.seleniumhq.org/docs/04_webdriver_advanced.jsp`
`https://github.com/SeleniumHQ/selenium/tree/master/javascript/node/selenium-webdriver/lib`


