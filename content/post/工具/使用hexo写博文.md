---
title: 使用hexo写博文
tags:
  - hexo
  - nodejs
categories:
  - 工具
date: 2017-01-15 22:54:00+08:00
---

来到一个新的环境，发现周围好多同事都是用word写技术文档的，觉得有必要将markdown这么好的东西介绍给大家。同时为了方便各位技术同仁写技术博文，推荐一下hexo，真的很方便。

## markdown简介

Markdown 是一种「电子邮件」风格的「标记语言」，很适合写技术文档。总结下来，它有如下优点：

* 纯文本，所以兼容性极强，可以用所有文本编辑器打开。
* 让你专注于文字而不是排版。
* 格式转换方便，Markdown 的文本你可以轻松转换为 html、电子书等。
* Markdown 的标记语法有极好的可读性。

Markdown的语法很简单，这里介绍一些常用的。

### 标题

这是最为常用的格式，在平时常用的的文本编辑器中大多是这样实现的：输入文本、选中文本、设置标题格式。

而在 Markdown 中，你只需要在文本前面加上 # 即可，同理、你还可以增加二级标题、三级标题、四级标题、五级标题和六级标题，总共六级，只需要增加 # 即可，标题字号相应降低。例如：

```
# 一级标题
## 二级标题
### 三级标题
#### 四级标题
##### 五级标题
###### 六级标题
```

注：`#` 和`一级标题`之间要保留一个字符的空格，这是最标准的 Markdown 写法。

### 列表

列表格式也很常用，在 Markdown 中，你只需要在文字前面加上 - 就可以了，例如：

```
- 文本1
- 文本2
- 文本3
```

上面那个是有序列表，如果希望用有序列表，也可以在文字前面加上`1. 2. 3. `就可以了，例如：

```
1. 文本1
2. 文本2
3. 文本3
```

注：-、1.和文本之间要保留一个字符的空格。

### 链接和图片

在 Markdown 中，插入链接不需要其他按钮，你只需要使用 `[显示文本](链接地址) `这样的语法即可，例如：

```
[简书](http://www.jianshu.com)
```

在 Markdown 中，插入图片不需要其他按钮，你只需要使用 `![](图片链接地址) `这样的语法即可，例如：

```
![图片alt描述](http://ww4.sinaimg.cn/bmiddle/aa397b7fjw1dzplsgpdw5j.jpg)
```

注：插入图片的语法和链接的语法很像，只是前面多了一个`!`。

### 引用

在我们写作的时候经常需要引用他人的文字，这个时候引用这个格式就很有必要了，在 Markdown 中，你只需要在你希望引用的文字前面加上`>`就好了，例如：

```
> 一盏灯， 一片昏黄； 一简书， 一杯淡茶。 守着那一份淡定， 品读属于自己的寂寞。 保持淡定， 才能欣赏到最美丽的风景！ 保持淡定， 人生从此不再寂寞。
```

注：> 和文本之间要保留一个字符的空格。

### 粗体和斜体

Markdown 的粗体和斜体也非常简单，用两个`*`包含一段文本就是粗体的语法，用一个`*`包含一段文本就是斜体的语法。例如：

```
*一盏灯*， 一片昏黄；**一简书**， 一杯淡茶。 守着那一份淡定， 品读属于自己的寂寞。 保持淡定， 才能欣赏到最美丽的风景！ 保持淡定， 人生从此不再寂寞。
```

其中`一盏灯`是斜体，`一简书`是粗体。

### 代码引用

需要引用代码时，如果引用的语句只有一段，不分行，可以用\`将语句包起来。
如果引用的语句为多行，可以将\`\`\`置于这段代码的首行和末行。

### 表格

表格的语法也很简单，如下

```
| Tables        | Are           | Cool  |
| ------------- |:-------------:| -----:|
| col 3 is      | right-aligned | $1600 |
| col 2 is      | centered      |   $12 |
| zebra stripes | are neat      |    $1 |
```

基本语法就这么多了，很简单吧。一些高级语法见[官方文档](http://www.markdown.cn/)。

## 写markdown的工具

语法介绍完了，下面就说一下写markdown的工具，市面上markdown编辑器很多，但因为我是一个开发人员，电脑里intellij idea会常年打开，因此就直接用idea写markdown了。idea的直接还挺好，在IDE里新建一个md文档，直接打开就可以了，而且默认分为两块面板，左边写markdown, 右边就直接显示markdown最终的显示效果，爽歪歪啊。

![idea编辑markdown文件](http://blog-images-1252238296.cosgz.myqcloud.com/idea_edit_markdown.png)

## 写博文工具

万事俱备，开始写博文了，我习惯使用`hexo`。为啥选它，因为它真的很简单，只有几步而已。

### 安装hexo

前提条件电脑上需要先安装NodeJS，如何安装可自行百度。

`安装hexo`

```
npm install -g hexo-cli
```

### 创建博客目录

```
hexo init blog
cd blog
npm install
```

新建完成后，指定文件夹的目录如下：

```
.
├── _config.yml
├── package.json
├── scaffolds
├── source
|   ├── _drafts
|   └── _posts
└── themes
```

因为source目录下才是博文的源目录，我一般将它归入到git版本管理里。

```
cd source
git init
git add .
git commit -m "first commit"
git add remote origin ....
git push -u master
```

### 使用idea编辑博文

在idea里新建一个Static Web的Module，Module的路径就指定为hexo的source目录，然后就可以在idea里进行博文的编辑了。

![idea新建静态Web模块](http://blog-images-1252238296.cosgz.myqcloud.com/idea_create_static_web_module.png)

### 编辑博文的一点小规范

- 直接在_posts目录下新建md文件即是创建了一篇新的博文，如下图。

![创建博文](http://blog-images-1252238296.cosgz.myqcloud.com/create_post.png)

- 博文最上面使用`Front-matter`指定博文的一些元信息，如下面。

![博文的front-matter](http://blog-images-1252238296.cosgz.myqcloud.com/post_front_matter.png)

`Front-matter`的详细语法见[这里](https://hexo.io/zh-cn/docs/front-matter.html)。

- 为确保博客不依赖于某个域名，以后可切换域名，博文中引用的图片（如引用外部站点图片，则指明外部站点的完整URL）全部使用相对于根的URL，见下面所示。

![博文中引用图片URL](http://blog-images-1252238296.cosgz.myqcloud.com/post_image_1.png)

- 为避免两篇博文的图片冲突，建议引用图片时，按博文的日期将图片放在不同的目录下。

![博文中引用图片URL](http://blog-images-1252238296.cosgz.myqcloud.com/post_image_1.png)

## 运行博客

直接在博客目录下运行`hexo server`即可运行博客，使用浏览器访问`http://127.0.0.1:4000`即可看到博客的效果。

## 博客自定义

1. hexo的配置文件`_config.yml`中有好几个配置项挺重要的，需设置合理。这些属性有`title`、`subtitle`、`description`、`author`、`language`、`timezone`、`url`、`highlight`。具体配置说明见[这里](https://hexo.io/zh-cn/docs/configuration.html)。

2. 为了便于被搜索引擎索引，可以使用`hexo-generator-baidu-sitemap`和`hexo-generator-sitemap`生成百度和Google的sitemap文件。具体用法见`https://github.com/coneycode/hexo-generator-baidu-sitemap`和`https://github.com/hexojs/hexo-generator-sitemap`。

3. 为了便于RSS阅读，可以使用`hexo-generator-feed`生成rss的feed。具体用法见`https://github.com/hexojs/hexo-generator-feed`。

4. 默认主题太没个性了不是，可以到主题库里选择一个有个性的主题，主题库地址在[这里](https://hexo.io/themes/)。

5. 博文要让人可以评论，可集成多说的评论系统，配置说明见[这里](http://dev.duoshuo.com/threads/541d3b2b40b5abcd2e4df0e9)。

6. 如果想将博客通过git部署到github或oschina，可参考我之前的[一篇博文](/2016/04/10/开发者的博客写作环境/)。


## 总结

这是篇工具使用说明，好像没什么可说明的。





