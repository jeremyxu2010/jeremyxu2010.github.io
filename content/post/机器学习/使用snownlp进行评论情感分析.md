---
title: 使用snownlp进行评论情感分析
author: Jeremy Xu
tags:
  - python
  - matplotlib
  - snownlp
categories:
  - 机器学习
date: 2017-03-16 20:40:00+08:00
---

## 背景

最近项目中有一个需求，希望分析用户对某些商品的评论，以推测用户对这些商品的情感倾向，从而为运营人员管理这些商品提供依据。

这个问题属于[自然语言处理](https://en.wikipedia.org/wiki/Natural_language_processing)的范畴，国外有很多这方面的论文。但我不是搞学术的，得想办法快速解决这个问题。

从网上看到一哥们[通过微博分析女朋友的情绪](https://www.anotherhome.net/2920)，他的方案里包括分词的选择、情绪分析词典的选择、情绪值的计算等，但因为自己实现的效果比较差，最后废弃了自己的方案，直接选择了[腾讯文智的情感分析收费服务](http://nlp.qq.com/help.cgi#)。

因为最近研究过tensorflow，也了解到使用tensorflow参照[word2vec](https://www.tensorflow.org/tutorials/word2vec)完成了词向量后，使用训练好的词向量，应该可以很容易进行语句的情绪分类。这里海航的一个工程师做了个[方案](http://chuansong.me/n/1588922851927)。

一直在想有没有简单点的方案了，搜索了多天，还真被我发现一个简单的方案-[snownlp](https://github.com/isnowfy/snownlp)。

## snownlp的使用

snownlp的文档写得很简单，如下：

```python
from snownlp import SnowNLP

s = SnowNLP(u'这个东西真心很赞')

s.words         # [u'这个', u'东西', u'真心',
                #  u'很', u'赞']

s.tags          # [(u'这个', u'r'), (u'东西', u'n'),
                #  (u'真心', u'd'), (u'很', u'd'),
                #  (u'赞', u'Vg')]

s.sentiments    # 0.9769663402895832 positive的概率

s.pinyin        # [u'zhe', u'ge', u'dong', u'xi',
                #  u'zhen', u'xin', u'hen', u'zan']

s = SnowNLP(u'「繁體字」「繁體中文」的叫法在臺灣亦很常見。')

s.han           # u'「繁体字」「繁体中文」的叫法
                # 在台湾亦很常见。'

text = u'''
自然语言处理是计算机科学领域与人工智能领域中的一个重要方向。
它研究能实现人与计算机之间用自然语言进行有效通信的各种理论和方法。
自然语言处理是一门融语言学、计算机科学、数学于一体的科学。
因此，这一领域的研究将涉及自然语言，即人们日常使用的语言，
所以它与语言学的研究有着密切的联系，但又有重要的区别。
自然语言处理并不是一般地研究自然语言，
而在于研制能有效地实现自然语言通信的计算机系统，
特别是其中的软件系统。因而它是计算机科学的一部分。
'''

s = SnowNLP(text)

s.keywords(3)   # [u'语言', u'自然', u'计算机']

s.summary(3)    # [u'因而它是计算机科学的一部分',
                #  u'自然语言处理是一门融语言学、计算机科学、
                #    数学于一体的科学',
                #  u'自然语言处理是计算机科学领域与人工智能
                #    领域中的一个重要方向']
s.sentences

s = SnowNLP([[u'这篇', u'文章'],
             [u'那篇', u'论文'],
             [u'这个']])
s.tf
s.idf
s.sim([u'文章'])# [0.3756070762985226, 0, 0]
```

我这个场景主要用到`sentiments`得到某句话的情感倾向值，如下：

```python
from snownlp import SnowNLP
s = SnowNLP(u'这个东西真心很赞')
print(s.sentiments) # 得到这句话的情感倾向值，取值范围为0~1.0，0为负面评价的极限值，1.0为正面评价的极限值
```

文档中也说明

> 情感分析（现在训练数据主要是买卖东西时的评价，所以对其他的一些可能效果不是很好，待解决）

幸好它还提供了自己训练情感的方式：

```python
from snownlp import sentiment
sentiment.train('neg.txt', 'pos.txt')
sentiment.save('sentiment.marshal')
```

这样训练好的文件就存储为`sentiment.marshal`了，之后修改`snownlp/sentiment/__init__.py`里的data_path指向刚训练好的文件即可

## snownlp在项目中的应用

实际在项目中应用时，我选择了`snownlp`的一个[fork项目](https://github.com/david30907d/snownlp)，因为这个fork项目使用了jieba进行分词，同时加强了繁体中文的支持。

贴一下`requirements.txt`文件:

```
jieba==0.38
-e git+https://github.com/david30907d/snownlp.git@8af8237#egg=snownlp
```

计算某个商品的情感倾向均值方法比较简单，就是取到每条评论的情感倾向值，加起来平均即可。

实现时有几点要注意一下：

- 某个商品的评论数太少，比如不足5条，这样统计出的均值可能不具代表性，因此忽略对这些商品的分析
- 某个商品的评论数太多，多于200条，为了加快分析过程，随机取100条评论进行分析

## 使用matplotlib观测数据的分布

为了更直观地观测数据的分布，我这里还使了`matplotlib`进行图形显示，如下代码：

```python
import matplotlib
import matplotlib.pyplot as plt

def showPlot(goodsStats):
    """显示情感均值分布图"""
    x = []
    y = []
    idx = 1
    goodsSize = len(goodsStats)
    zhfont1 = matplotlib.font_manager.FontProperties(fname='C:/Windows/Fonts/msyh.ttf')
    for value in goodsStats.values():
        x.append(idx)
        y.append(value['sentimentsAvg'])
        idx += 1
    plt.plot(x, y, 'bo', label=(str(goodsSize) + " Goods Sentiments Average"))
    plt.ylabel("Sentiments Avarage")
    plt.ylim(0, 1.0)
    plt.axis([0, goodsSize, 0, 1.0])
    plt.title(str(goodsSize) + "个商品的情感均值分布图", fontproperties=zhfont1)
    plt.legend()
    plt.show()
```
