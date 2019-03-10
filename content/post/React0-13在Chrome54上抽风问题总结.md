---
title: React0.13在Chrome54上抽风问题总结
author: Jeremy Xu
tags:
  - react
  - chrome
  - javascript
categories:
  - web开发
date: 2016-10-20 00:35:00+08:00
---
这几天产品处在发版阶段，工作比较忙，很久没有更新博客了。不过今天在工作中遇到一个最新版Chrome浏览器的坑，分析解决的过程还比较有意思，在这里记录一下。

## 问题描述

现在在做的项目，项目历时很长，之前选用的ReactJS的0.13.3版本，而现在ReactJS已经升级版本至0.15版本了，但旧版本代码一直运行得好好的，所以一直没有动力进行升级。不过今天Chrome自动升级至54版本后，ReactJS开始报错了。如下：

```javascript
unhandledRejection.js:23 Potentially unhandled rejection [2] TypeError: Failed to execute 'insertBefore' on 'Node': parameter 1 is not of type 'Node'.
    at insertChildAt (webpack:///./~/react/lib/DOMChildrenOperations.js?:34:14)
    at Object.processUpdates (webpack:///./~/react/lib/DOMChildrenOperations.js?:106:11)
    at Object.dangerouslyProcessChildrenUpdates (webpack:///./~/react/lib/ReactDOMIDOperations.js?:150:27)
    at Object.wrapper [as processChildrenUpdates] (webpack:///./~/react/lib/ReactPerf.js?:70:21)
    at processQueue (webpack:///./~/react/lib/ReactMultiChild.js?:141:31)
    at ReactDOMComponent.updateChildren (webpack:///./~/react/lib/ReactMultiChild.js?:263:13)
    at ReactDOMComponent._updateDOMChildren (webpack:///./~/react/lib/ReactDOMComponent.js?:470:12)
    at ReactDOMComponent.updateComponent (webpack:///./~/react/lib/ReactDOMComponent.js?:319:10)
    at ReactDOMComponent.receiveComponent (webpack:///./~/react/lib/ReactDOMComponent.js?:303:10)
    at Object.receiveComponent (webpack:///./~/react/lib/ReactReconciler.js?:97:22)
```

跟踪了下调用栈，发现问题出在ReactJS操作DOM的代码处

`DOMChildrenOperations.js`的105行处

```javascript
  case ReactMultiChildUpdateTypes.INSERT_MARKUP:
          insertChildAt(
            update.parentNode,
            renderedMarkup[update.markupIndex],
            update.toIndex
          );
          break;
```

这里查看一下`update.markupIndex`竟然是`NaN`。继续跟踪`ReactMultiChildUpdateTypes.INSERT_MARKUP`类型的update是在哪里生成的，于是找到以下代码：

`ReactMultiChild.js`的40行处

```javascript
/**
 * Queue of markup to be rendered.
 *
 * @type {array<string>}
 * @private
 */
var markupQueue = [];

/**
 * Enqueues markup to be rendered and inserted at a supplied index.
 *
 * @param {string} parentID ID of the parent component.
 * @param {string} markup Markup that renders into an element.
 * @param {number} toIndex Destination index.
 * @private
 */
function enqueueMarkup(parentID, markup, toIndex) {
  // NOTE: Null values reduce hidden classes.
  updateQueue.push({
    parentID: parentID,
    parentNode: null,
    type: ReactMultiChildUpdateTypes.INSERT_MARKUP,
    markupIndex: markupQueue.push(markup) - 1,
    textContent: null,
    fromIndex: null,
    toIndex: toIndex
  });
}
```

这里已经标明了生成的update的markupIndex为`markupQueue.push(markup) - 1`，照理说这肯定不会为NaN的。于是修改代码打印出值看一下。

```javascript
function enqueueMarkup(parentID, markup, toIndex) {
  var markupIndex = markupQueue.push(markup) - 1;
  console.log(markupIndex);
  // NOTE: Null values reduce hidden classes.
  updateQueue.push({
    parentID: parentID,
    parentNode: null,
    type: ReactMultiChildUpdateTypes.INSERT_MARKUP,
    markupIndex: markupIndex,
    textContent: null,
    fromIndex: null,
    toIndex: toIndex
  });
}
```

发现竟真的为`NaN`了，看来应该是Chrome的新版本bug了。为了规避问题，简单修改了下代码后，问题解决：

```javascript
function enqueueMarkup(parentID, markup, toIndex) {
  var markupIndex = markupQueue.push(markup) - 1;
  if(isNaN(markupIndex)) {
    markupIndex = markupQueue.length - 1;
  }
  // NOTE: Null values reduce hidden classes.
  updateQueue.push({
    parentID: parentID,
    parentNode: null,
    type: ReactMultiChildUpdateTypes.INSERT_MARKUP,
    markupIndex: markupIndex,
    textContent: null,
    fromIndex: null,
    toIndex: toIndex
  });
}
```

没有改变原来逻辑的本意，仅仅处理了下markupIndex为NaN的情况。

## 进一步分析

在Chrome的问题列表上搜索了下，果然找到[这个问题](https://bugs.chromium.org/p/chromium/issues/detail?id=656037)。

## 总结

ReactJS的源码还挺复杂的，特别是通过虚拟DOM树操作真正DOM那一段。有问题也不要紧，打开Chrome开发者工具，仔细分析还是可以找到问题发生的原因的。
