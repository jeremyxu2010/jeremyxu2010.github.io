---
title: 前端ReactJS技术介绍
author: Jeremy Xu
tags:
  - reactjs
  - javascript
categories:
  - web开发
date: 2017-03-09 18:00:00+08:00
---

## WEB应用程序基本架构

### 胖服务端

![fat_server.png](http://blog-images-1252238296.cosgz.myqcloud.com/fat_server.png)

这个架构的特点：

- 后台良好的分层模型
- 页面由后台输出至浏览器，一般采用JSP、PHP等动态页面技术处理页面的动态内容

一些改进：

- 引入AJAX，局部更新数据，避免整页面刷新
- 后端使用模板技术，帮助输出页面
- 前端使用模板技术，帮助构造html页面片断
- 前端形成了一些CSS框架，如bootstrap
- 前端形成了一些JS工具方法或常用组件，如jQuery, jQuery插件, ExtJS, YUI等

### 胖客户端

![fat_client.png](http://blog-images-1252238296.cosgz.myqcloud.com/fat_client.png)

这个架构的特点：

- 后端跟上面一样良好的分层模型，但成了仅提供API接口的API Server
- 前端处理与显现相关的大部分逻辑，包括页面路由、数据请求、组件数据绑定、业务逻辑串联等

## 胖客户端架构的优点

- 分离前后端关注点，前端负责界面显示，后端负责数据存储和计算，各司其职，不会把前后端的逻辑混杂在一起
- 前端页面组件化，提高代码重复利用率，简化了开发，适合大型的项目
- 减轻服务器压力，服务器只用出数据就可以，不用管展示逻辑和页面合成，吞吐能力会提高几倍
- 同一套后端程序代码，不用修改就可以用于Web界面、手机、平板等多种客户端

前端负责的逻辑这么复杂了，为了便于管理，自然要进行必要的分层。

## 前端架构模式

### 前端架构模式－MVC

![web_mvc.png](http://blog-images-1252238296.cosgz.myqcloud.com/web_mvc.png)

- 用户可以向 View 发送指令（DOM 事件），再由 View 直接要求 Model 改变状态。
- 用户也可以直接向 Controller 发送指令（改变 URL 触发 hashChange 事件），再由 Controller 发送给 View。
- Controller 非常薄，只起到路由的作用，而 View 非常厚，业务逻辑都部署在 View。所以，Backbone 索性取消了 Controller，只保留一个 Router（路由器） 。

典型代表：backbone之类的前端框架

### 前端架构模式－MVP

![web_mvp.png](http://blog-images-1252238296.cosgz.myqcloud.com/web_mvp.png)

- MVP 模式将 Controller 改名为 Presenter，同时改变了通信方向。
- 各部分之间的通信，都是双向的。
- View 与 Model 不发生联系，都通过 Presenter 传递。
- View 非常薄，不部署任何业务逻辑，称为"被动视图"（Passive View），即没有任何主动性，而 Presenter非常厚，所有逻辑都部署在那里。

这个在Android开发中用得比较多。

### 前端架构模式－MVVM

![web_mvvm.png](http://blog-images-1252238296.cosgz.myqcloud.com/web_mvvm.png)

MVVM 模式将 Presenter 改名为 ViewModel，基本上与 MVP 模式完全一致。唯一的区别是，它采用双向绑定（data-binding）：View的变动，自动反映在 ViewModel，反之亦然。这种双向绑定功能一般借助于ReactJS、VueJS、AngularJS之类的UI框架。

## ReactJS介绍

### 简介

React (有时叫 React.js 或 ReactJS) 是一个为数据提供渲染为 HTML 的视图的开源 JavaScript 库。React 视图通常采用包含以自定义 HTML 标记规定的其他组件的组件渲染。React 为程序员提供了一种子组件不能直接影响外层组件 ("data flows down") 的模型，数据改变时对 HTML 文档的有效更新，和现代单页应用中组件之间干净的分离。它由 Facebook, Instagram 和一个由个人开发者和企业组成的社群维护，它于 2013 年 5 月在 JSConf US 开源。

### 原理

在Web开发中，我们总需要将变化的数据实时反应到UI上，这时就需要对DOM进行操作，而复杂或频繁的DOM操作通常是性能瓶颈产生的原因。

React为此引入了[虚拟DOM（Virtual DOM）](http://www.alloyteam.com/2015/10/react-virtual-analysis-of-the-dom/)的机制：在浏览器端用Javascript实现了一套DOM API。基于React进行开发时所有的DOM构造都是通过虚拟DOM进行，每当数据变化时，React都会重新构建整个DOM树，然后React将当前整个DOM树和上一次的DOM树进行对比，得到DOM结构的区别，然后仅仅将需要变化的部分进行实际的浏览器DOM更新。而且React能够批处理虚拟DOM的刷新，在一个事件循环（Event Loop）内的两次数据变化会被合并。

尽管每一次都需要构造完整的虚拟DOM树，但是因为虚拟DOM是内存数据，性能是极高的，而对实际DOM进行操作的仅仅是Diff部分，因而能达到提高性能的目的。这样，在保证性能的同时，开发者将不再需要关注某个数据的变化如何更新到一个或多个具体的DOM元素，而只需要关心在任意一个数据状态下，整个界面是如何Render的。

这里有一个[更通俗的解释](http://chaoxi.me/react.js/%E6%B5%85%E8%B0%88%E5%89%8D%E7%AB%AF/%E8%AE%BE%E8%AE%A1%E6%80%9D%E6%83%B3/2017/02/20/In-depth-react-design-ideas.html)

如果对虚拟DOM的工作方式感兴趣，可以看[这里](https://www.zhihu.com/question/29504639)

### 特点

- 简单

仅仅只要表达出你的应用程序在任一个时间点应该长的样子，然后当底层的数据变了，React 会自动处理所有用户界面的更新。

- 响应式 (Declarative)

数据变化后，React 概念上与点击“刷新”按钮类似，但仅会更新变化的部分。

- 构建可组合的组件

React 易于构建可复用的组件。事实上，通过 React 你唯一要做的事情就是构建组件。得益于其良好的封装性，组件使代码复用、测试和关注分离（separation of concerns）更加简单。

- 学习一次，到处都可以使

React并没有依赖其它的技术栈，因此可以在老旧项目中使用ReactJS开发新功能，不需要重写存在的代码。React可以在浏览器端或服务端进行渲染，甚至借助于React Native，可在移动设备中渲染。

### 关键概念

- 渲染函数

`ReactDOM.render`是 React 的最基本方法，用于将模板转为HTML语言，并插入指定的DOM节点。用于将模板转为HTML语言，并插入指定的 DOM 节点

```
<!DOCTYPE html>
<html>
  <head>
    <script src="../build/react.js"></script>
    <script src="../build/react-dom.js"></script>
    <script src="../build/browser.min.js"></script>
  </head>
  <body>
    <div id="root"></div>
    <script type="text/babel">
      ReactDOM.render(
        <h1>Hello, world!</h1>,
        document.getElementById('root')
      );
    </script>
  </body>
</html>
```

- JSX语法

HTML语言直接写在JavaScript语言之中，不加任何引号，这就是JSX的语法，它允许HTML与JavaScript的混写。

JSX的规则是：遇到HTML标签（以`<`开头），就用HTML规则解析；遇到代码块（以`{`开头），就用 JavaScript 规则解析。

这种写法虽然将模板直接写到JavaScript中了，但带来很多灵活，不需要去学特定的标签语法，会JS就成。比如下面的代码：

```
var names = ['Alice', 'Emily', 'Kate'];

ReactDOM.render(
  <div>
  {
    names.map(function (name) {
      return <div>Hello, {name}!</div>
    })
  }
  </div>,
  document.getElementById('example')
);
```

- 组件

React 允许将代码封装成组件（component），然后像插入普通 HTML 标签一样，在网页中插入这个组件。所有组件类都必须有自己的`render`方法，用于输出组件。组件的用法与原生的HTML标签完全一致，可以任意加入属性。组件的属性可以在组件类的`this.props`对象上获取。

```javascript
class HelloWorld extends React.Component{
    render(){
        return <h1>Hello, {this.props.name}</h1>
    }
}

class Container extends React.Component{
    render(){
        return <HelloWorld name="world"></HelloWorld>
    }
}

ReactDOM.render(
  <Container />,
  document.getElementById('root')
);

```

- 组件状态

组件免不了要与用户互动，React将组件看成是一个状态机，一开始有一个初始状态，然后用户互动，导致状态变化，从而触发重新渲染UI。

```javascript
class LikeButton extends React.Component{
    constructor(props){
        super(props);
        this.state = {liked: false};
    }

    handleClick() {
        this.setState({liked: !this.state.liked});
    }
    render() {
        var text = this.state.liked ? 'like' : 'haven\'t liked';
        return (
          <p onClick={() => this.handleClick()}>
            You {text} this. Click to toggle.
          </p>
        );
    }
}

ReactDOM.render(
  <LikeButton />,
  document.getElementById('example')
);
```

- 组件的生命周期

组件的生命周期分成三个状态：

```
Mounting：已插入真实 DOM
Updating：正在被重新渲染
Unmounting：已移出真实 DOM
```

React 为每个状态都提供了两种处理函数，will 函数在进入状态之前调用，did 函数在进入状态之后调用，三种状态共计五种处理函数。

```
componentWillMount()
componentDidMount()
componentWillUpdate(object nextProps, object nextState)
componentDidUpdate(object prevProps, object prevState)
componentWillUnmount()
```

比如说实际编码过程中，我们经常会在`componentDidMount`方法加入逻辑：发出AJAX请求，请求后台数据后修改组件状态。

### 简单示例

![react_sample.png](http://blog-images-1252238296.cosgz.myqcloud.com/react_sample.png)

更多示例代码见 `https://facebook.github.io/react`

我自己写的一个SSM+ReactJS+Redux工程示例：`http://git.oschina.net/jeremy-xu/ssm-scaffold`

### React简单的教程

`http://www.ruanyifeng.com/blog/2015/03/react.html`
`http://wiki.jikexueyuan.com/project/react/`

### 缺点

- 尽管可以省掉编译过程体验ReactJS的特性，但要完全发挥它的优点，还得依赖webpack之类的前端打包工具
- JSX语法，在javascript代码里写标签，很难让人接受
- 相对于VueJS来说组件封装不够彻底，CSS部分还在外部文件里
- 由于整个页面都是JS渲染起来的，产生SEO问题，现在可以通过Prerender等技术解决一部分
- 初次加载耗时相对增多，现在可以通过服务端渲染解决一部分
- 有一定门槛，对前端开发人员技能水平要求较高

### 适用场景

一些后台管理、UI交互特别复杂、频繁操作DOM的页面

### 一些小坑

- 文档虽多，但因为历史原因，找到的文档有的是ES5语法，有的是ES6语法，造成了一些混乱。推荐使用ES6语法，多参考官方文档。同时也读一下[两种语法的对照表](http://bbs.reactnative.cn/topic/15/react-react-native-%E7%9A%84es5-es6%E5%86%99%E6%B3%95%E5%AF%B9%E7%85%A7%E8%A1%A8/2)

- 如果要支持IE8，有一些额外操作要做，参考[这里](https://github.com/xcatliu/react-ie8)

- 即使是HTML标准标签，在React里也变成React的组件了，要拿到组件对应的DOM对象，需用`ReactDOM.findDOMNode(componentInstance)`或`ReactDOM.findDOMNode(this.refs.compRef)`

- React里的事件是模拟事件`SyntheticEvent`，它不是原生的DOM事件，支持的属性与方法见[这里](https://facebook.github.io/react/docs/events.html)

- ES6语法中，组件的方法`this`回归JavaScript的本意。这样当指定事件回调方法时，`this`很有可能指定的是触发事件的组件。可以用ES6里的箭头函数来解决这个问题。


## ReactJS在老旧项目中的应用

### 限制

- 要与现有前端页面技术无缝衔接
- 没有前端编译工具
- 没有前端模块依赖工具，全凭script标签引入

### 目前的方案

- 将常用的JS库文件（ReactJS库、组件库、工具库）一起使用script标签引入
- 将用ReactJS书写的代码保存在单独的文件里
- 使用babel在前端实时将ES6的ReactJS代码编译为ES5（这个导致页面初次渲染更慢了）

比如一个实际的例子：

`test.jsp`

```
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<body>
    <div id="root"></div>
    <!-- 喜欢使用lodash里一些工具方法，高效且实用 -->
    <script type="text/javascript" src="${ctx}/libs/lodash.min.js"></script>
    <!-- React的库文件 -->
    <script type="text/javascript" src="${ctx}/libs/react.min.js"></script>
    <script type="text/javascript" src="${ctx}/libs/react-dom.min.js"></script>
    <!-- 阿里出品，强大的React组件库 -->
    <script type="text/javascript" src="${ctx}/libs/antd.min.js"></script>
    <!-- 时间日期工具库 -->
    <script type="text/javascript" src="${ctx}/libs/moment.min.js"></script>
    <!-- Promise风格发送AJAX请求，避免javascript callback hell http://callbackhell.com/ -->
    <script type="text/javascript" src="${ctx}/libs/axios.min.js"></script>
    <!-- 使用babel将ES6的代码在浏览器端翻译为ES5代码 -->
    <script type="text/javascript" src="${ctx}/libs/babel/browser.min.js"></script>
    <!-- 声明一个JS变量保存webapp上下文，以后发送AJAX请求时会用到 -->
    <script type="text/javascript">var __CTX_PATH__='${ctx}';</script>
    <!-- 引入业务JSX文件 -->
    <script type="text/babel" src="${ctx}/scripts/business1.jsx"></script>
</body>
```

`business1.jsx`

```javascript
const React = window.React;
const ReactDOM = window.ReactDOM;
const axios = window.axios;
const antd = window.antd;
const _ = window._;

class Demo1 extends React.Component{
    render(){
        return <h1>TODO</h1>
    }
}

ReactDOM.render(
  <Demo1 />,
  document.getElementById('root')
);

```

## 其它相关技术资料

- 语法类

ES6教程    `http://es6.ruanyifeng.com/`

- 编译工具类

Gulp教程    `http://www.gulpjs.com.cn/docs/`
Webpack教程    `http://zhaoda.net/webpack-handbook/module-system.html`
Browserify文档    `https://github.com/substack/node-browserify#usage`
Babeljs使用教程    `https://babeljs.io/docs/setup/#installation`

- 实用工具函数库

lodash文档  `http://lodashjs.com/docs/`

- 避免`js callback hell`利器

Promise教程    `http://es6.ruanyifeng.com/#docs/promise`
Axios教程      `https://www.kancloud.cn/yunye/axios/234845`

- 前端路由类

React-Router教程    `https://react-guide.github.io/react-router-cn/`

- React组件类

Antd文档    `https://ant.design/docs/react/introduce-cn`

- 前端数据流框架

Redux教程   `http://cn.redux.js.org/docs/basics/index.html`

- 优秀的对标者

VueJS文档     `https://cn.vuejs.org/v2/guide/`
Vuex文档      `https://vuex.vuejs.org/zh-cn/`
element组件文档     `http://element.eleme.io/#/zh-CN/component/installation`

