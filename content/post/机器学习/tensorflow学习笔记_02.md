---
title: tensorflow学习笔记_02
author: Jeremy Xu
tags:
  - tensorflow
  - python
categories:
  - 机器学习
date: 2017-03-02 18:20:00+08:00
---

上一篇笔记采用一个线性关系的神经层处理了MNIST的训练数据，最后得到一个准确率一般的神经网络。但其实对于这种图像识别的场景，tensorflow里还可以使用卷积神经网络技术进行准确率更高的机器学习。

## 卷积与池化

`卷积`是一个数学上的概念，简单说就是拿`卷积核`从原始图像里提取特征映射，将一张图片转化为多张包含特征映射的图片。理解`卷积`可以读一下[这篇帖子](https://www.zhihu.com/question/22298352)，里面除了很抽象的数学定义外，还有一些便于理解的示例。
`池化`主要用来浓缩卷积层的输出结果并创建一个压缩版本的信息并输出。

## 示例程序

学习卷积神经网络，我也参照官方的代码写了个小例子，如下。

`demo2.py`

```python
import tensorflow as tf
# 下载mnist并加载MNIST的训练数据
import tensorflow.examples.tutorials.mnist.input_data as input_data
mnist = input_data.read_data_sets("MNIST_data/", one_hot=True)
# 定义两个方法，用以产生带稍许噪音的权值与偏值
def weight_variable(shape):
    initial = tf.truncated_normal(shape, stddev=0.1)
    return tf.Variable(initial)
def bias_variable(shape):
    initial = tf.constant(0.1, shape=shape)
    return tf.Variable(initial)
# 定义工具方法，用以创建隐藏层
def add_layer(inputs, Weights, biases, activation_function=None):
    # add one more layer and return the output of this layer
    Wx_plus_b = tf.add(tf.matmul(inputs, Weights), biases)
    if activation_function is None:
        outputs = Wx_plus_b
    else:
        outputs = activation_function(Wx_plus_b, )
    return outputs
# 定义工具方法，创建卷积层
def conv2d(x, W):
    return tf.nn.conv2d(x, W, strides=[1, 1, 1, 1], padding='SAME')
# 定义工具方法，创建池化层
def max_pool_2x2(x):
    return tf.nn.max_pool(x, ksize=[1, 2, 2, 1], strides=[1, 2, 2, 1], padding='SAME')
# 定义两个外部传入的张量
x = tf.placeholder(tf.float32, [None, 784])
y = tf.placeholder(tf.float32, [None, 10])
# drop层使用到的保留比率
keep_prob = tf.placeholder(tf.float32)
# 将原始二维数据reshape为四维数据
x_image = tf.reshape(x, [-1, 28, 28, 1]) # (samples, 28, 28, 1)
# 第一层卷积层及池化层
W_conv1 = weight_variable([5, 5, 1, 32])
b_conv1 = bias_variable([32])
h_conv1 = tf.nn.relu(conv2d(x_image, W_conv1) + b_conv1) # (samples, 28, 28, 32)
h_pool1 = max_pool_2x2(h_conv1) # (samples, 14, 14, 32)
# 第二层卷积及池化层
W_conv2 = weight_variable([5, 5, 32, 64])
b_conv2 = bias_variable([64])
h_conv2 = tf.nn.relu(conv2d(h_pool1, W_conv2) + b_conv2) # (samples, 14, 14, 64)
h_pool2 = max_pool_2x2(h_conv2) # (samples, 7, 7, 64)
# 将四维的输出reshape为二维数据
h_pool2_flat = tf.reshape(h_pool2, [-1, 7*7*64]) # (samples, 7*7*64)
# 添加一个隐藏层
W_fc1 = weight_variable([7*7*64, 1024])
b_fc1 = bias_variable([1024])
h_fc1 = add_layer(h_pool2_flat, W_fc1, b_fc1, tf.nn.relu) # (samples, 1024)
# 添加一个按比率随机drop层
h_fc1_drop = tf.nn.dropout(h_fc1, keep_prob) # (samples, 1024)
# 使用softmax回归模型计算出预测的y，这个是用来分类处理的
W_fc2 = weight_variable([1024, 10])
b_fc2 = bias_variable([10])
prediction_y = tf.nn.softmax(tf.add(tf.matmul(h_fc1_drop, W_fc2), b_fc2)) # (samples, 10)
# 使用交叉熵计算预测的y与实际的y的损失
loss = -tf.reduce_sum(y*tf.log(prediction_y))
# 使用AdamOptimizer以0.0001的学习速率最小化交叉熵
train_step = tf.train.AdamOptimizer(1e-4).minimize(loss)
# 计算预测的y与实际的y是否匹配，返回为[True, False, True, True...]
correct_prediction = tf.equal(tf.argmax(prediction_y, 1), tf.argmax(y, 1))
# 计算上一步计算出来的张量的平均值
accuracy = tf.reduce_mean(tf.cast(correct_prediction, "float"))

with tf.Session() as sess:
    # 初始化所有变量
    sess.run(tf.global_variables_initializer())
    # 循环训练1000次，每次从MNIST的训练数据中随机抽出100条进行训练
    for i in range(1000):
        batch_xs, batch_ys = mnist.train.next_batch(100)
        sess.run(train_step, feed_dict={x: batch_xs, y: batch_ys, keep_prob: 0.5})
        if i % 10 == 0:
            # 使用MNIST的测试数据计算模型的准确率
            batch_xs, batch_ys = mnist.test.next_batch(100)
            print(sess.run(accuracy, \
                feed_dict={x: batch_xs, y: batch_ys, keep_prob: 0.5}))

```

代码注释得很清楚了，为了便于理解，多个层之间转换时，我也将张量的shape标示出来了。

## 总结

本篇作为tensorflow入门的一个较复杂的例子，其中涉及了较多数学知识，理解起来还是挺困难的。后面我会尝试用tensorboard等工具将神经网络以可视化的方式呈现出来，这样可能容易理解一点。看到一句话，原以为深度学习工程师很高大上，原来大家都是这么干活的。
> 话说，深度学习工程师50%的时间在调参数，49%的时间在对抗过/欠拟合，剩下1%时间在修改网上down下来的程序。

## 参考

`http://wiki.jikexueyuan.com/project/tensorflow-zh/tutorials/deep_cnn.html`
`http://www.jianshu.com/p/3b611043cbae`
`https://www.zhihu.com/question/22298352?rf=21686447`
`https://www.zhihu.com/question/38098038`
