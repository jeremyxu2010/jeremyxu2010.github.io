---
title: tensorflow学习笔记_01
author: Jeremy Xu
tags:
  - tensorflow
  - python
categories:
  - 机器学习
date: 2017-02-28 18:20:00+08:00
---

最近看到一个有趣的项目[pix2pix-tensorflow](https://github.com/yenchenlin/pix2pix-tensorflow)。大概功能是用户在网页上画一只猫的轮廓，然后它就可以输出与这个轮廓很相似的猫的清晰图片。出于好奇，就想研究一下这个项目是如何实现的，于是跳入了tensorflow机器学习这个坑。

## tensorflow是什么

> TensorFlow是一个开源软件库，用于各种感知和语言理解任务的机器学习。目前被50个团队用于研究和生产许多Google商业产品，如语音识别、Gmail、Google 相册和搜索，其中许多产品曾使用过其前任软件DistBelief。TensorFlow最初由Google Brain团队开发，用于Google的研究和生产，于2015年11月9日在Apache 2.0开源许可证下发布。

> TensorFlow是Google Brain的第二代机器学习系统，2015年11月9日，参考实现作为开源软件发布。虽然参考实现运行在单台设备，TensorFlow可以运行在多个CPU和GPU（和可选的CUDA扩展）。它运行在64位Linux或macOS桌面或服务器系统，以及在移动计算平台上，包括Android和iOS。TensorFlow的计算用有状态的数据流图表示。许多Google团队已从DistBelief迁移到TensorFlow进行研究和生产。这个库的算法源于Google需要指导称为神经网络的计算机系统，类似人类学习和推理的方法，以便派生出新的应用程序承担以前仅人类能胜任的角色和职能；TensorFlow的名字来源于这类神经网络对多维数组执行的操作。这些多维数组被称为“张量”，但这个概念并不等同于张量的数学概念。其目的是训练神经网络检测和识别模式和相互关系。

## tensorflow安装

安装过程很简单，就是普通的python库安装方法，这里重点说一下windows下安装tensorflow的方法，玩其它系统的用户看看官方文档肯定能搞定安装。

- 安装64位3.5.x版的python，安装包从[这里](https://www.python.org/downloads/release/python-353/)下载
- 安装cpu版本或gpu版本(如果有NV的显卡的话)的tensorflow

```bash
C:\> pip3 install --upgrade tensorflow
```
或
```bash
pip3 install --upgrade tensorflow-gpu
```

## 写个hello world入门程序

学什么东西，先上个hello world入门程序

`helloworld.py`

```python
import tensorflow as tf

greeting = tf.constant("hello world!", dtype=tf.string)

with tf.Session() as sess:
    print(sess.run(greeting))
```

然后执行它

```bash
python helloworld.py
b'hello world!'
```

正常输出`hello world!`了。

这个小程序逻辑很简单，解释一下：先用tensorflow定义图的结构，就定义了一个`tf.string`的常量`greeting`，然后在打开的tensorflow会话里运行并得到这个张量的值，最后用`print`打印出来。

## 一个入门的例子

先上代码：

`demo1.py`

```python
import tensorflow as tf
# 下载mnist并加载MNIST的训练数据
import tensorflow.examples.tutorials.mnist.input_data as input_data
mnist = input_data.read_data_sets("MNIST_data/", one_hot=True)
# 定义两个外部传入的张量
x = tf.placeholder(tf.float32, [None, 784])
y = tf.placeholder("float", [None, 10])
# 定义要训练学习的变量
W = tf.Variable(tf.zeros([784, 10]))
b = tf.Variable(tf.zeros([10]))
# 使用softmax回归模型计算出预测的y
prediction_y = tf.nn.softmax(tf.matmul(x, W) + b)
# 使用交叉熵计算预测的y与实际的y的损失
loss = -tf.reduce_sum(y*tf.log(prediction_y))
# 使用梯度下降算法以0.01的学习速率最小化交叉熵
train_step = tf.train.GradientDescentOptimizer(0.01).minimize(loss)
# 计算预测的y与实际的y是否匹配，返回为[True, False, True, True...]
correct_prediction = tf.equal(tf.argmax(prediction_y, 1), tf.argmax(y, 1))
# 计算上一步计算出来的张量的平均值
accuracy = tf.reduce_mean(tf.cast(correct_prediction, "float"))
with tf.Session() as sess:
    # 在图中初始化所有变量
    sess.run(tf.global_variables_initializer())
    # 循环训练1000次，每次从MNIST的训练数据中随机抽出100条进行训练
    for i in range(1000):
        batch_xs, batch_ys = mnist.train.next_batch(100)
        sess.run(train_step, feed_dict={x: batch_xs, y: batch_ys})
        if i % 10 == 0:
            # 使用MNIST的测试数据计算模型的准确率
            batch_xs, batch_ys = mnist.test.next_batch(100)
            print(sess.run(accuracy, \
                feed_dict={x: batch_xs, y: batch_ys}))
```

代码里的注释写得比较清楚，就不一一解释了。下面对关键点作个说明。

## 入门例子关键点分析

- tensorflow的程序一般分为如下几个部分
    1. 定义包含n个层的tensorflow神经网络的模型，这个模型一般会描述逻辑如何将输入计算为预测的输出
    2. 定义损失函数，损失函数为预测的输出与实际输出的差距
    3. 定义用何种方法优化减小预测的损失
    4. 迭代地输入训练数据，用以训练模型
    5. 训练的过程中定期检测模型的准确率

- 定义的模型如果要从外部传入张量，一般写法如下：

```python
# 定义外部传入的张量
parma1 = tf.placeholder(tf.float32, [None, 784])

...

with tf.Session() as sess:
    ...
    # 在图中运行时传入张量
    sess.run(val1, feed_dict={parma1: param_value})
```

- 定义的模型如果使用了变量，一般写法如下：

```python
# 定义变量
val1 = tf.placeholder(tf.float32, [None, 784])

...

# 初始化所有变量
init = tf.global_variables_initializer()

with tf.Session() as sess:
    # 在图中初始化所有变量
    sess.run(init)
    ...

```

- 一个神经网络层一般形式如下

```python
l1_output = tf.nn.softmax(tf.matmul(l1_input,W) + b)
```

其中W为权值，b为偏置，`tf.nn.softmax`是用来分类的。有可能还会有激励函数，毕竟并不是所有关系都是线性的，激励函数就是用来将线性关系掰弯的，tensorflow里完成此类功能的激励函数有很多，见[这里](https://www.tensorflow.org/versions/r0.10/api_docs/python/nn/#relu)。

- 一个训练step一般形式如下

```python
train_step = tf.train.GradientDescentOptimizer(0.01).minimize(loss)
```

其中`tf.train.GradientDescentOptimizer`为优化函数，tensorflow里自带的优化函数挺多的，见[这里](https://www.tensorflow.org/api_guides/python/train)，`loss`为损失函数。

## 总结

本篇作为tensorflow入门的一个笔记，后面我会再说一说tensorflow里的CNN与RNN。

## 参考

`https://www.tensorflow.org/install/install_windows`
`https://www.tensorflow.org/get_started/mnist/beginners`
`https://www.tensorflow.org/versions/r0.10/api_docs/python`
