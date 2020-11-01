---
title: web浏览器自动化之playwright
tags:
  - nodejs
  - playwright
  - es6
categories:
  - nodejs开发
date: 2020-11-01 20:54:00+08:00
---

工作中经常需要在几个后台管理站点上进行一些重复性工作。作为一个会偷懒的程序员，自然要想点主意。

之前就使用[selenium-webdriver](https://jeremyxu2010.github.io/2016/05/web%E7%95%8C%E9%9D%A2%E6%B5%8B%E8%AF%95%E5%AE%9E%E8%B7%B5%E4%B9%8Bselenium-webdriver/)做过一些web浏览器自动化的工作，在github上找了下，发现microsoft又开源了一个[playwright](https://github.com/microsoft/playwright)，这个比以前的`selenium-webdriver`使用起来更简单了，这里就用它试一试。

## 安装

由于是`playwright`是一个node库，这里最好新建一个目录，并在这个目录中安装npm依赖库。

```bash
$ mkdir playwright-sandbox
$ cd playwright-sandbox
$ npm i -D playwright
$ npm i -D playwright-cli
```

安装时它会自动下载当前平台上3个浏览器二进制文件，可以通过一系统环境变量控制这种下载行为，参见[Advanced installation](https://playwright.dev/#version=v1.5.2&path=docs%2Finstallation.md&q=)。

安装完毕后可以写个小脚本测试一下：

`test.js`:

```javascript
const { webkit } = require('playwright');

(async () => {
  const browser = await webkit.launch();
  const page = await browser.newPage();
  await page.goto('http://whatsmyuseragent.org/');
  await page.screenshot({ path: `example.png` });
  await browser.close();
})();
```

可以简单地执行一下看看效果：

```bash
$ node ./test.js
```

像上面这样写脚本跟`selenium-webdriver`也差不多，实在有些无趣。因此`playwright`还提供了杀手级辅助工具，可以直接录制用户的交互行为生成代码。

```bash
$ npx playwright-cli codegen wikipedia.org
```

这个就方便太多了。

## 核心概念

脚本都可以生成了，写脚本就不再是问题了，真正要花脑力的地方变成了如何修改生成的脚本。在可以随心所欲地修改脚本前，有必要了解下`playwright`脚本里的一些核心概念。

### Browser

`Browser`代表的是一个Chromium、Firefox或WebKit浏览器实例。`Playwright`脚本通常会启动一个浏览器实例，最后会将这个实例关闭。`Browser`可以以headless模式或headful模式启动，分别是无GUI和有GUI模式。

```javascript
const { chromium } = require('playwright');  // Or 'firefox' or 'webkit'.

const browser = await chromium.launch({ headless: false });
await browser.close();
```

因为启动一个浏览器实例成本很高，因此在playwright脚本里一般会复用浏览器实例，通过多个浏览器上下文在同一个浏览器实例里达到完成不同的逻辑。

### Browser context

`Browser context`是一个隔离地有点类似于session的浏览器实例上下文。

```javascript
const browser = await chromium.launch();
const context = await browser.newContext();
```

`Browser context`可以用来模拟多个页面场景，每个场景可以有不同的权限、本地化、设备等。

```javascript
const { devices } = require('playwright');
const iPhone = devices['iPhone 11 Pro'];

const context = await browser.newContext({
  ...iPhone,
  permissions: ['geolocation'],
  geolocation: { latitude: 52.52, longitude: 13.39},
  colorScheme: 'dark',
  locale: 'de-DE'
});
```

### Page and frame

`Page`代表着一个浏览器tab页面，它应该被用于导航到URL。脚本中的绝大部分用户交互行为都是在页面内容上执行的。

```javascript
// Create a page.
const page = await context.newPage();

// Navigate explicitly, similar to entering a URL in the browser.
await page.goto('http://example.com');
// Fill an input.
await page.fill('#search', 'query');

// Navigate implicitly by clicking a link.
await page.click('#submit');
// Expect a new url.
console.log(page.url());

// Page can navigate from the script - this will be picked up by Playwright.
window.location.href = 'https://example.com';
```

跟正常的html页面一样，一个页面中可以有多个`frame`，同样可以用脚本操作`frame`。

```javascript
// Get frame using the frame's name attribute
const frame = page.frame('frame-login');

// Get frame using frame's URL
const frame = page.frame({ url: /.*domain.*/ });

// Get frame using any other selector
const frameElementHandle = await page.$('.frame-class');
const frame = await frameElementHandle.contentFrame();

// Interact with the frame
await frame.fill('#username-input', 'John');
```

### Selector

要对web页面进行操作，首先就要定位到页面元素。`playwright`同样支持`CSS selectors`,  `XPath selectors`,  `HTML attributes`和` text content`方式定位页面元素。

```javascript
// Using data-test-id= selector engine
await page.click('data-test-id=foo');

// CSS and XPath selector engines are automatically detected
await page.click('div');
await page.click('//html/body/div');

// Find node by text substring
await page.click('text=Hello w');

// Explicit CSS and XPath notation
await page.click('css=div');
await page.click('xpath=//html/body/div');

// Only search light DOM, outside WebComponent shadow DOM:
await page.click('css:light=div');

// Click an element with text 'Sign Up' inside of a #free-month-promo.
await page.click('#free-month-promo >> text=Sign Up');

// Capture textContent of a section that contains an element with text 'Selectors'.
const sectionText = await page.$eval('*css=section >> text=Selectors', e => e.textContent);
```

### Execution contexts: Node.js and Browser

除了操作web页面上已有的界面元素，还可以直接在浏览器上下文中执行自定义脚本，这个就相当于在页面的开发者工具Console中执行脚本。

```javascript
const status = await page.evaluate(async () => {
  const response = await fetch(location.href);
  return response.status;
});

const data = { text: 'some data', value: 1 };
// Pass |data| as a parameter.
const result = await page.evaluate(data => {
  window.myApp.use(data);
}, data);
```

主要核心概念就上面这些了，看起来不难。另外官方还很贴心地提供了[一系列指引](https://playwright.dev/#version=v1.5.2&path=docs%2Fselectors.md&q=)，参考这些应该可以解决编写脚本过程中遇到的各类问题。

## 调试

脚本写好后，需要简单调试一下，以确保脚本逻辑的正确性。[官方文档](https://playwright.dev/#version=v1.5.2&path=docs%2Fdebug.md&q=)也写得比较清楚了，只要会用chrome的开发者工具应该可以快速上手，这里就不赘述了。

## 认证

很多web页面都有认证鉴权，只有通过认证，获得合法的认证状态才能进行进一步的操作，因此需要特意说明一下。

### 自动登录

如果是简单的用户名密码认证，可以直接在脚本中完成登录。

```javascript
const page = await context.newPage();
await page.goto('https://github.com/login');

// Interact with login form
await page.click('text=Login');
await page.fill('input[name="login"]', USERNAME);
await page.fill('input[name="password"]', PASSWORD);
await page.click('text=Submit');
// Verify app is logged in
```

### 利用认证状态

有些web应用安全性做得比较好，采取的是双因素认证。这时可以先将认证状态保存下来，然后在脚本中利用该认证状态。

下面的例子假设认证状态是保存在cookies中的。

```javascript
const { webkit } = require('playwright');
const fs = require('fs').promises;

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

(async () => {
    const browser = await webkit.launch({ headless: false });
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto('https://www.google.com.hk/');
    # 这时手动完成web页面上的登录流程
    await sleep(60000);
    # 登录完毕后将上下文中的cookies写入文件
    const cookies = await context.cookies();
    await fs.writeFile('cookies.json', JSON.stringify(cookies));
    // Close page
    await page.close();
    await context.close();
    await browser.close();
})();
```

接下来可以利用认证状态。

```javascript
const { webkit } = require('playwright');
const fs = require('fs').promises;

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

(async () => {
    const browser = await webkit.launch({ headless: false });
    const context = await browser.newContext();
    const cookiesStr = await fs.readFile('cookies.json', 'utf8');
    await context.addCookies(JSON.parse(cookiesStr));
    const page = await context.newPage();
    await page.goto('https://www.google.com.hk/');
    // 在这里执行正常的逻辑
    // Close page
    await page.close();
    await context.close();
    await browser.close();
})();
```

`playwright`支持[Cookies](https://playwright.dev/#version=v1.5.2&path=docs%2Fauth.md&q=cookies)、[Local storage](https://playwright.dev/#version=v1.5.2&path=docs%2Fauth.md&q=local-storage)、[Session storage](https://playwright.dev/#version=v1.5.2&path=docs%2Fauth.md&q=session-storage)多种保存认证状态的方式。

## 代码封装

所有脚本逻辑都写在一起不便于关注点分离，因此官方建议对于逻辑较复杂的脚本，可以将在一个页面内的各个逻辑代码段封装为一个个类中的方法。

```javascript
// models/Search.js
class SearchPage {
  constructor(page) {
    this.page = page;
  }
  async navigate() {
    await this.page.goto('https://bing.com');
  }
  async search(text) {
    await this.page.fill('[aria-label="Enter your search term"]', text);
    await this.page.keyboard.press('Enter');
  }
}
module.exports = { SearchPage };
```

```javascript
// search.spec.js
const { SearchPage } = require('./models/Search');

// In the test
const page = await browser.newPage();
const searchPage = new SearchPage(page);
await searchPage.navigate();
await searchPage.search('search query');
```

## 进一步思考

`playwright`的介绍差不多就上面这些了，可以看出来这些功能之前`selenium-webdriver`也都可以提供，但无疑`playwright`做得更加易用了，特别是可以自动录制用户的交互行为，直接生成脚本，这个就很强了。

再想一想，平时开发过程中Android UI自动化测试脚本的编写也是比较程式化的，这个是否可以有一个像`playwright`之类的框架自动生成脚本？看了下暂时是没有的，这是个方向。

## 参考

1. https://playwright.dev/#?path=docs/README.md
2. https://github.com/microsoft/playwright-cli