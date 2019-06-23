---
title: 使用mathjax
date: 2017-06-03 18:00:00+08:00
tags:
  - hexo
  - markdwon
  - mathjax
categories:
  - 工具
author: 徐新杰
---

## 为何要用mathjax

在书写数值计算类文章，特别是机器学习相关算法时，难免需要插入复杂的数学公式。一种是用图片在网页上展示，另外一种是使用 [MathJax](https://www.mathjax.org/) 来展示复杂的数学公式。它直接使用 Javascript 使用矢量字库或 SVG 文件来显示数学公式。优点是效果好，比如在 Retina 屏幕上也不会变得模糊。并且可以直接把公式写在 Markdown 文章里。

## hexo支持MathJax

我是使用[Typora](https://typora.io/)书写`markdown`文档的，它自身就支持`MathJax`了，就不用特别的想办法支持`MathJax`了。

最好写好的`markdown`文档要`hexo-next`主题渲染出来，它支持`MathJax`的方法很简单，还是简单记录一下，直接在`_config.yml`文件里加入以下代码段就可以了。

```yaml
# MathJax Support
mathjax:
  enable: true
  per_page: false
  cdn: //cdn.bootcss.com/mathjax/2.4.0/MathJax.js?config=TeX-AMS-MML_HTMLorMML
```

但默认的hexo使用的markdown渲染引擎与mathjax有些冲突，建议还是换用[hexo-renderer-pandoc](https://github.com/wzpan/hexo-renderer-pandoc)作为markdown的渲染引擎。

安装方法也很简单：

```bash
brew install pandoc
yarn remove hexo-renderer-marked
yarn add hexo-renderer-pandoc
```

## LaTex简明教程

先看个例子

```latex
$$
J(\theta) = \frac 1 2 \sum_{i=1}^m (h_\theta(x^{(i)} - y^{(i)}))^2
$$
```

上面的LaTex 格式书写的数学公式经过 MathJax 展示后效果如下：

$$
J(\theta) = \frac 1 2 \sum_{i=1}^m (h_\theta(x^{(i)} - y^{(i)}))^2
$$
这个公式是线性回归算法里的成本函数。

## 规则

关于在 Markdown 书写 LaTex 数学公式有几个规则常用规则需要记住：

### 行内公式

行内公式使用 `$` 号作为公式的左右边界，如 `$h(x) = \theta_0 + \theta_1 x$`，示例如下：

梯度递减公式： $ \theta_i = \theta_i - \alpha\frac\partial{\partial\theta_i}J(\theta) $

### 行内公式

公式需要独立显示一行时，使用 `$$` 来作为公式的左右边界

### 常用LaTex代码

需要记住的几个常用的符号，这样书写起来会快一点

| 编码                                     | 说明                 | 示例                                       | 代码                                       |
| -------------------------------------- | ------------------ | ---------------------------------------- | ---------------------------------------- |
| \frac                                  | 分子分母之间的横线          | $\frac1 x$                               | ` $\frac1x$`                             |
| _                                      | 用下划线来表示下标          | $x_i$                                    | ` $x_i$`                                 |
| ^                                      | 次方运算符来表示上标         | $x^i$                                    | ` $x^i$`                                 |
| \sum                                   | 累加器，上下标用上面介绍的编码来书写 | $\sum$                                   | ` $\sum$`                                |
| \alpha                                 | 希腊字母 alpha         | $y := \alpha x$                          | ` $y := \alpha x$`                       |
| \theta                                 | 希腊字母theta          | $\theta$                                 | `$\theta$`                               |
| \pi                                    | 希腊字母pi             | $\pi$                                    | `$\pi$`                                  |
| \delta                                 | 希腊字母delta          | $\delta$                                 | `$\delta$`                               |
| \Delta                                 | 希腊字母Delta          | $\Delta$                                 | `$\Delta$`                               |
| \prod                                  | 连乘积符号              | $\prod$                                  | ` $\prod$ `                              |
| \int                                   | 积分符号               | $ \int$                                  | `$\int$`                                 |
| \nabla                                 | 希腊字母nabla          | $\nabla$                                 | `$\nabla$`                               |
| \in                                    | 属于                 | $\in$                                    | `$\in$`                                  |
| \partial                               | 希腊字母partial        | $\partial$                               | `$partial$`                              |
| \begin{bmatrix}a&b\\c&d\\\end{bmatrix} | 矩阵符号               | $\begin{bmatrix}a&b\\c&d\\\end{bmatrix}$ | `$\begin{bmatrix}a&b\\c&d\\\end{bmatrix}$` |
| \mathbb R                              | 实数                 | $\mathbb R$                              | `$\mathbb R$`                            |
| \left(A + B\right)                     | 随着公式大小缩放的左右括号      | $\left(A + B\right)$                     | `$\left(A + B\right)$`                   |
| A \quad B                              | 加入一些空隙             | $A \quad B$                              | `$A \quad B$`                            |
| \sqrt[2]{x}                            | 根式                 | $ \sqrt[2]{x}$                           | $\sqrt[2]{x}$                            |

记住这几个就差不多了，完整的符号列表要看[这里](http://mirrors.opencas.org/ctan/info/symbols/math/maths-symbols.pdf)，倒回去看一下线性回归算法的成本函数的公式及其 LaTex 代码，对着练习个10分钟基本就可以掌握常用公式的写法了。要特别注意公式里空格和 `{}` 的运用规则。基本原则是，空格可加可不加，但如果会引起歧义，最好加上空格。`{}` 是用来组成群组的。比如写一个分式时，分母是一个复杂公式时，可以用 `{}` 包含起来，这样整个复杂公式都会变成分母了。

## 几个非常有用的资源

* 这是一篇质量很高的[介绍 MathJax 的中文博客文章](http://mlworks.cn/posts/introduction-to-mathjax-and-latex-expression/)，需要注意的是如果是用 markdown 编写 MathJax 公式，当公式里需要两个斜杠 \ 时要写四个斜杠 \。因为 \ 会被 markdown 转义一次。

- Github 上有个[在线 Markdown MathJax 编辑器](https://kerzol.github.io/markdown-mathjax/editor.html)，可以在这里练习，平时写公式时也可以在这里先写好再拷贝到文章里
- 这是 [LaTex 完整教程](http://www.forkosh.com/mathtextutorial.html)，包含完整的 LaTex 数学公式的内容，包括更高级的格式控制等
- 这是一份PDF 格式的 [MathJax 支持的数学符号表](http://mirrors.ctan.org/info/symbols/math/maths-symbols.pdf)，当需要书写复杂数学公式时，一些非常特殊的符号的转义字符可以从这里查到
- 别人整理出的一份[技巧](http://mlworks.cn/posts/introduction-to-mathjax-and-latex-expression/)

好啦，这样差不多就可以写出优美的数学公式啦。
