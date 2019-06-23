---
title: 免编译在JSP中直接写react代码
tags:
  - JSP
  - react
categories:
  - web开发
date: 2017-01-07 20:40:00+08:00
---

最近参与了一个历时4-5年的项目，项目是一个后台管理系统，访问量并不高，但经常根据业务方的一些特殊需求，在原有代码添加功能。项目所采用的技术架构还十分老旧，后台采用Struts + Spring + Hibernate， 前台直接使用JSP, 辅以struts与jstl的一些标签。

说实话，自从接受前端MVVM模式后，很久不再使用原始的JSP做前端了，实在是不习惯JSP这种杂乱无章的书写模式。

但项目目前还有线上跑着，维护工作还得继续，同时小组长还告诉我在未完全了解全部业务之前，千万不要尝试进行大面积重构。唉，说实话，我很怀疑这么乱的代码，我最终能完全理解业务。。。

想了下，最终还是想到办法使用原有的React技术栈完成前端工作，这里将方法写出来，供其它遇到这类问题的小伙伴参考一下。

## struts的改造

struts的action方法仅完成两种用途，一是页面URL跳转，一是返回ajax数据。具体实现如下：

```java
@Component("testAction")
@Scope("prototype")
public class TestAction {
    private static final String JSON_RESULT = "jsonResult";
    private Map<String, Object> jsonResultMap = Maps.newHashMap();

    ...

    //这类action方法主要负责页面的跳转
    public String gotoPage1(){
        return "page1";
    }

    //这类action方法主要负责以json的格式返回ajax数据
    public String loadTestData(){
        try {
            HttpServletRequest request = ServletActionContext.getRequest();
            String param1 = request.getParameter("param1");
            //做业务操作
            jsonResultMap.put("testData", testData);
            jsonResultMap.put("success", true);
        } catch (Exception e){
            jsonResultMap.put("errMsg", e.getMessage());
            jsonResultMap.put("success", false);
        }
        return JSON_RESULT;
    }

    ...
}
```

对应的struts配置

```xml
<package name="test" namespace="/test" extends="json-default">
    <action name="*" class="testAction" method="{1}">
        <result name="page1">/test/page1.jsp</result>
        <result name="jsonResult" type="json">
            <param name="root">jsonResultMap</param>
            <param name="contentType">text/html;charset=UTF-8</param>
        </result>
    </action>
</package>
```

## 前端jsp的改造

前端jsp页面引用一些常用CSS, JS资源，然后主要使用React来渲染页面，代码如下：

`page1.jsp`

```html
<%@ page language="java" pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ taglib uri="http://java.sun.com/jstl/core_rt" prefix="c" %>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <title>title</title>
    <link href="${ctx}/css/bootstrap/bootstrap.min.css" rel="stylesheet" type="text/css"/>
    <link href="${ctx}/css/sb-admin-2/sb-admin-2.min.css" rel="stylesheet" type="text/css"/>
    <link href="${ctx}/css/antd/antd.min.css" rel="stylesheet" type="text/css"/>
    <link href="${ctx}/css/module_common.css" rel="stylesheet" type="text/css"/>
</head>
<body>
<div id="reactHolder"></div>
<script type="text/javascript" src="${ctx}/script/lodash/lodash.min.js"></script>
<script type="text/javascript" src="${ctx}/script/react/react.min.js"></script>
<script type="text/javascript" src="${ctx}/script/react/react-dom.min.js"></script>
<script type="text/javascript" src="${ctx}/script/antd/antd.min.js"></script>
<script type="text/javascript" src="${ctx}/script/moment/moment.min.js"></script>
<script type="text/javascript" src="${ctx}/script/axios/axios.min.js"></script>
<script type="text/javascript" src="${ctx}/script/babel-core/browser.min.js"></script>
<script type="text/javascript">
    var __CTX_PATH__='${ctx}';
</script>
<script type="text/babel" src="${ctx}/script/TODO.jsx"></script>
</body>
</html>
```

这里在外部的jsx文件书写主要的页面渲染逻辑，jsx文件可使用ES6语法进行书写，将由babel5实时翻译为ES5代码（本项目为后台管理系统，可以忍受实时翻译的性能开销）。代码如下：

`TODO.jsx`代码

```javascript
const React = window.React;
const ReactDOM = window.ReactDOM;
const _ = window._;
const axios = window.axios;
const antd = window.antd;

class TODO extends React.Component{
    render(){
        return <h1>TODO</h1>;
    }
}

ReactDOM.render(<TODO/>, document.getElementById('reactHolder'));
```

## 前端jsx文件的引用

开发中可能会将一些公共方法抽取出来放到一个单独的文件中，而js(x)文件的加载都是异步的，无法保证依赖性。这里可采用umd方式封闭JS模块的方案，如下代码：

```javascript
;(function(f) {
    // CommonJS
    if (typeof exports === "object" && typeof module !== "undefined") {
        module.exports = f();

        // RequireJS
    } else if (typeof define === "function" && define.amd) {
        define([], f);

        // <script>
    } else {
        var g;
        if (typeof window !== "undefined") {
            g = window;
        } else if (typeof global !== "undefined") {
            g = global;
        } else if (typeof self !== "undefined") {
            g = self;
        } else {
            g = this;
        }
        g.Common = f();
    }
})(function(){
    const util1 = function(){
        ...
    };
    const util2 = function(){
        ...
    };
    return {
        util1,
        util2
    }
});
```

引用方可以这样写：

```javascript
;(function(f) {
    // CommonJS
    if (typeof exports === "object" && typeof module !== "undefined") {
        module.exports = f(require('common'));

        // RequireJS
    } else if (typeof define === "function" && define.amd) {
        define(['common'], f);

        // <script>
    } else {
        var g;
        if (typeof window !== "undefined") {
            g = window;
        } else if (typeof global !== "undefined") {
            g = global;
        } else if (typeof self !== "undefined") {
            g = self;
        } else {
            g = this;
        }
        g.App1 = f(g.Common);
    }
})(function(Common){
    const app1Module1 = function(){
        ...
    };
    const app1Module2 = function(){
        ...
    };
    return {
        app1Module1,
        app1Module2
    }
});
```

当然这么写还是有很大缺点，由于没有引入cmd，amd等JS模块化方案，这里是污染全局变量了。对于老旧项目来说，没有上requirejs或browserify、webpack打包方案，目前也只能这么干了。

## 总结

虽然维护老旧项目很累，但能采用以前的技术栈写前端代码，这已经很幸福了。
