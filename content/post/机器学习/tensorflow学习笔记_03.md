---
title: tensorflow学习笔记_03
author: Jeremy Xu
tags:
  - tensorflow
  - python
categories:
  - 机器学习
date: 2017-03-19 18:20:00+08:00
---

上一篇使用tensorflow完成一个卷积神经网络，但当时写的代码虽然可以工作，还比较零乱，并且并没有经过参数调优，最终得到的模型准确率也并不是很高。本周花了些时间将代码进行了重构，并且对某些地方进行了调整了，目前得到的准确率就比较高了。

## 神经网络

### 神经网络的概念

神经网络只是一个很酷的名词，媒体用来夸大其词的，其实没有生物神经那么高级。神经网络归根结底就是计算图谱，或者说数据流图谱。其实就是一串链在一起的函数，这些函数的操作对象是各种维度的矩阵。

下面这段我总结出来的话很重要，很重要，很重要。

`在tensorflow里定义的计算图谱有一个很重要的特征，所有的矩阵运算都是可求导的。这样如果有大量可训练的数据，利用反向传播法，通过微积分就可以不断优化更新计算图谱里的各种权重值和偏值，最终即可训练出一个比较好的计算模型来。`

[这个视频](https://www.bilibili.com/video/av6563470/)讲得很通俗易懂，初入门的同学都可以看看。

## 卷积神经网络

### 概念

发现之前自己对卷积神经网络的理解并不是很清楚，这次重新学习终于将其理解清楚了。卷积神经网络可以总结为是一个“矩阵滑窗”乘法，主要用来在视觉识别里进行特征提取。

[这个视频](https://www.bilibili.com/video/av6712708/)将卷积神经网络提取特征的原理讲得非常清楚了。

### 重构版卷积神经网络实现

花了点时间将上一篇实现的卷积神经网络重写了，见下面的代码：

`demo3.py`

```python
'''卷积神经网络重构版本'''
from __future__ import print_function, division
import os
import stat
from pathlib import Path
import tensorflow as tf
import numpy as np
from tensorflow.examples.tutorials.mnist import input_data

mnist = input_data.read_data_sets("data/mnist/", one_hot=True)

print('Original train data', mnist.train.images.shape, mnist.train.labels.shape)
print('Original test data', mnist.test.images.shape, mnist.test.labels.shape)

ckpt_dir = '/ckpt/demo3'
ckpt_filename = 'default.ckpt'
logs_dir = '/logs/demo3'

def reformat(samples, labels):
    ''' 对原始数据进行格式化 '''
    samples = samples.reshape(samples.shape[0], 28, 28, 1) # (sampleNum, 28, 28, 1)
    return samples, labels

def rm_dirs(top):
    ''' 递归删除目录'''
    if Path(top).is_dir():
        for root, dirs, files in os.walk(top, topdown=False):
            for name in files:
                filename = os.path.join(root, name)
                os.chmod(filename, stat.S_IWUSR)
                os.remove(filename)
            for name in dirs:
                os.rmdir(os.path.join(root, name))
        os.rmdir(top)

train_samples, train_labels = reformat(mnist.train.images, mnist.train.labels)
test_samples, test_labels = reformat(mnist.test.images, mnist.test.labels)

print('Train data', train_samples.shape, train_labels.shape)
print('Test data', test_samples.shape, test_labels.shape)

class Network():

    def __init__(self, train_batch_size, test_batch_size, image_size, num_channels, conv_kernel_size, conv1_feature_num, conv2_feature_num, hidden1_num, keep_prob, num_labels):
        ''' 计算图谱的构造函数 '''
        self.train_batch_size = train_batch_size
        self.test_batch_size = test_batch_size

        # 计算图谱中各种层的关键参数
        self.image_size = image_size
        self.num_channels = num_channels
        self.conv_kernel_size = conv_kernel_size
        self.conv1_feature_num = conv1_feature_num
        self.conv2_feature_num = conv2_feature_num
        self.hidden1_num = hidden1_num
        self.keep_prob = keep_prob
        self.num_labels = num_labels

        # 计算图谱相关op
        self.graph = tf.Graph()
        self.session = None
        self.tf_train_samples = None
        self.tf_train_labels = None
        self.tf_test_samples = None
        self.tf_test_labels = None
        self.train_prediction = None
        self.test_prediction = None
        self.saver = None
        self.train_accuracy = None
        self.train_merged_summary = None
        self.loss = None
        self.optimizer = None
        self.test_accuracy = None
        self.test_merged_summary = None
        self.summary_writer = None

        # 各种权值及偏值
        self.w_conv1 = None
        self.b_conv1 = None
        self.w_conv2 = None
        self.b_conv2 = None
        self.w_fc1 = None
        self.b_fc1 = None
        self.w_fc2 = None
        self.b_fc2 = None
        self.fc_weights = []
        self.fc_biases = []

        # 定义计算图谱
        self.define_graph()

    def get_batch(self, samples, labels, batchSize):
        '''
        这个函数是一个迭代器/生成器，用于每一次只得到 batchSize 这么多的数据
        用于 for loop， just like range() function
        '''
        if len(samples) != len(labels):
            raise Exception('Length of samples and labels must equal')
        stepStart = 0    # initial step
        i = 0
        while stepStart < len(samples):
            stepEnd = stepStart + batchSize
            if stepEnd < len(samples):
                yield i, samples[stepStart:stepEnd], labels[stepStart:stepEnd]
                i += 1
            stepStart = stepEnd

    def weight_variable(self, shape):
        ''' 定义方法用以产生带稍许噪音的权值'''
        initial = tf.truncated_normal(shape, stddev=0.1)
        return tf.Variable(initial)

    def bias_variable(self, shape):
        ''' 定义方法用以产生带稍许噪音的偏值'''
        initial = tf.constant(0.1, shape=shape)
        return tf.Variable(initial)

    def add_layer(self, inputs, weights, biases, activation_function=None):
        ''' 定义工具方法，用以创建隐藏层'''
        wx_plus_b = tf.add(tf.matmul(inputs, weights), biases)
        if activation_function is None:
            outputs = wx_plus_b
        else:
            outputs = activation_function(wx_plus_b, )
        return outputs

    def conv2d(self, inputs, weights):
        ''' 定义工具方法，创建卷积层 '''
        return tf.nn.conv2d(inputs, weights, strides=[1, 1, 1, 1], padding='SAME')

    def max_pool_2x2(self, inputs):
        ''' 定义工具方法，创建池化层 '''
        return tf.nn.max_pool(inputs, ksize=[1, 2, 2, 1], strides=[1, 2, 2, 1], padding='SAME')

    def define_graph(self):
        ''' 定义计算图谱 '''
        with self.graph.as_default():
            # 这里只是定义图谱中的各种传入变量
            self.tf_train_samples = tf.placeholder(
                tf.float32, shape=(self.train_batch_size, self.image_size, self.image_size, self.num_channels)
            )
            self.tf_train_labels = tf.placeholder(
                tf.float32, shape=(self.train_batch_size, self.num_labels)
            )

            self.tf_test_samples = tf.placeholder(
                tf.float32, shape=(self.test_batch_size, self.image_size, self.image_size, self.num_channels)
            )
            self.tf_test_labels = tf.placeholder(
                tf.float32, shape=(self.test_batch_size, self.num_labels)
            )

            # 这里定义图谱中的各种权值及偏值
            with tf.name_scope("conv1_var"):
                self.w_conv1 = self.weight_variable([self.conv_kernel_size, self.conv_kernel_size, self.num_channels, self.conv1_feature_num])
                self.b_conv1 = self.bias_variable([self.conv1_feature_num])
            with tf.name_scope("conv2_var"):
                self.w_conv2 = self.weight_variable([self.conv_kernel_size, self.conv_kernel_size, self.conv1_feature_num, self.conv2_feature_num])
                self.b_conv2 = self.bias_variable([self.conv2_feature_num])
            with tf.name_scope("h_layer1_var"):
                self.w_fc1 = self.weight_variable([(self.image_size//(2*2))*(self.image_size//(2*2))*self.conv2_feature_num, self.hidden1_num])
                self.b_fc1 = self.bias_variable([self.hidden1_num])
            with tf.name_scope("h_layer2_var"):
                self.w_fc2 = self.weight_variable([self.hidden1_num, self.num_labels])
                self.b_fc2 = self.bias_variable([self.num_labels])

            self.fc_weights.append(self.w_fc1)
            self.fc_weights.append(self.w_fc2)
            self.fc_biases.append(self.b_fc1)
            self.fc_biases.append(self.b_fc2)

            # Add ops to save and restore variables.
            self.saver = tf.train.Saver()

            # 这里定义图谱的运算
            def model(samples):
                ''' 定义图谱的运算 '''
                # 第一层卷积层及池化层
                with tf.name_scope("conv1"):
                    h_conv1 = tf.nn.relu(self.conv2d(samples, self.w_conv1) + self.b_conv1) # (samples, 28, 28, 32)
                    h_pool1 = self.max_pool_2x2(h_conv1) # (samples, 14, 14, 32)

                # 第二层卷积及池化层
                with tf.name_scope("conv2"):
                    h_conv2 = tf.nn.relu(self.conv2d(h_pool1, self.w_conv2) + self.b_conv2) # (samples, 14, 14, 64)
                    h_pool2 = self.max_pool_2x2(h_conv2) # (samples, 7, 7, 64)

                # 将四维的输出reshape为二维数据，为连接全连接层作准备
                h_pool2_flat = tf.reshape(h_pool2, [-1, (self.image_size//(2*2))*(self.image_size//(2*2))*self.conv2_feature_num]) # (samples, 7*7*64)

                # 添加一个隐藏层
                with tf.name_scope("h_layer1"):
                    h_fc1 = self.add_layer(h_pool2_flat, self.w_fc1, self.b_fc1, tf.nn.relu) # (samples, 1024)

                # 添加一个按比率随机drop层
                with tf.name_scope("drop_layer"):
                    h_fc1_drop = tf.nn.dropout(h_fc1, self.keep_prob) # (samples, 1024)

                # 使用softmax回归模型计算出预测的y，这个是用来分类处理的
                with tf.name_scope("h_layer2"):
                    h_fc2 = tf.add(tf.matmul(h_fc1_drop, self.w_fc2), self.b_fc2)

                with tf.name_scope("softmax_layer"):
                    return tf.nn.softmax(h_fc2) # (samples, 10)

            def calc_accuracy(predictions, labels):
                ''' 计算预测的正确率 '''
                correct_prediction = tf.equal(tf.argmax(predictions, 1), tf.argmax(labels, 1))
                return tf.reduce_mean(tf.cast(correct_prediction, tf.float32)) * 100

            def apply_regularization():
                ''' 对全连接层的weights与biases进行regularization '''
                regularation_param = 0.01
                regularation = 0.0
                for weights, biases in zip(self.fc_weights, self.fc_biases):
                    regularation += tf.nn.l2_loss(weights) + tf.nn.l2_loss(biases)

                return regularation_param * regularation

            with tf.name_scope("train"):
                self.train_prediction = model(self.tf_train_samples)
                self.train_accuracy = calc_accuracy(self.train_prediction, self.tf_train_labels)
                self.train_merged_summary = tf.summary.merge([tf.summary.scalar('train_accuracy', self.train_accuracy)])

                # 损失
                self.loss = -tf.reduce_sum(self.tf_train_labels * tf.log(self.train_prediction))
                self.loss += apply_regularization()

                # 逐渐降低学习速率
                batch = tf.Variable(0, trainable=False)
                starter_learning_rate = 0.001
                learning_rate = tf.train.exponential_decay(starter_learning_rate, batch * self.train_batch_size, self.train_batch_size * 10, 0.95, staircase=True)
                # 优化
                self.optimizer = tf.train.AdamOptimizer(learning_rate).minimize(self.loss, global_step=batch)

            with tf.name_scope("test"):
                # Predictions for the training, validation, and test data.
                self.test_prediction = model(self.tf_test_samples)
                self.test_accuracy = calc_accuracy(self.test_prediction, self.tf_test_labels)
                self.test_merged_summary = tf.summary.merge([tf.summary.scalar('test_accuracy', self.test_accuracy)])



    def train(self):
        ''' 训练 '''
        if self.session is None:
            self.session = tf.Session(graph=self.graph)

        with self.session as session:
            session.run(tf.global_variables_initializer())

            # 从磁盘上还原计算图谱参数
            if Path(os.getcwd() + ckpt_dir + "/" + ckpt_filename + ".index").is_file():
                self.saver.restore(session, os.getcwd() + ckpt_dir + "/" + ckpt_filename)
                print("Model restored.")

            if self.summary_writer is None:
                self.summary_writer = tf.summary.FileWriter(os.getcwd() + logs_dir, self.graph)

            ### 训练
            print('Start Training')
            for i, samples, labels in self.get_batch(train_samples, train_labels, batchSize=self.train_batch_size):
                _, train_summary, loss, accuracy = session.run(
                    [self.optimizer, self.train_merged_summary, self.loss, self.train_accuracy],
                    feed_dict={self.tf_train_samples: samples, self.tf_train_labels: labels}
                )
                self.summary_writer.add_summary(train_summary, i)
                if i % 50 == 0:
                    print('Batch at step %d' % i)
                    print('Batch loss: %f' % loss)
                    print('Batch accuracy: %.1f%%' % accuracy)

            # 将训练得到的计算图谱参数写入磁盘
            if not Path(os.getcwd() + ckpt_dir).is_dir():
                os.makedirs(os.getcwd() + ckpt_dir)
            save_path = self.saver.save(session, os.getcwd() + ckpt_dir + "/" + ckpt_filename)
            print("Model saved in file: %s" % save_path)

        self.session = None

    def test(self):
        ''' 测试 '''
        if self.session is None:
            self.session = tf.Session(graph=self.graph)

        with self.session as session:

            session.run(tf.global_variables_initializer())

            # 从磁盘上还原计算图谱参数
            if Path(os.getcwd() + ckpt_dir + "/" + ckpt_filename + ".index").is_file():
                self.saver.restore(session, os.getcwd() + ckpt_dir + "/" + ckpt_filename)
                print("Model restored.")

            if self.summary_writer is None:
                self.summary_writer = tf.summary.FileWriter(os.getcwd() + logs_dir, self.graph)

            print('Start Testing')
            accuracies = []
            for i, samples, labels in self.get_batch(test_samples, test_labels, batchSize=self.test_batch_size):
                test_summary, accuracy = self.session.run(
                    [self.test_merged_summary, self.test_accuracy],
                    feed_dict={self.tf_test_samples: samples, self.tf_test_labels: labels}
                )
                accuracies.append(accuracy)
                self.summary_writer.add_summary(test_summary, i)
                print('Test accuracy: %.1f%%' % accuracy)
            print('Average  accuracy:', np.average(accuracies))
            print('Standard deviation:', np.std(accuracies))

        self.session = None

if __name__ == '__main__':
    rm_dirs(os.getcwd() + logs_dir)
    net = Network(100, 300, 28, 1, 5, 32, 64, 1024, 0.5, 10)
    net.train()
    net.test()

```

这里的代码注释得比较清楚了，与上一篇的主要区别有以下几点：

- 将计算图谱的定义写在一个`Network`类里了，同时这个类提供了`train`与`test`方法进行训练与测试

- `Network`类抽取了计算图谱里的参数，这样在主函数里就可以很方便的修改

- 对原始数据预处理的逻辑从计算图谱抽离出来了，保持计算图谱功能的单一性

- 整个代码框架整理的比较合理，以后其它类型的神经网络可以照此模式书写

## 优化点

为了提升学习效率及准备度，上述重构版本还采用了几项技术，这里简要记录一下。

- 使用了dropout层

为了预防训练出的模型`过拟合`，这里采用了dropout层，用以随机丢弃一些元素，代码示例如下：

```python
# 添加一个按比率随机drop层
with tf.name_scope("drop_layer"):
    h_fc1_drop = tf.nn.dropout(h_fc1, self.keep_prob) # (samples, 1024)
```

- 对全连接层的权值及偏值进行了regularization

为了控制全连接层的权值及偏值，使这些权值及偏值均衡地分布于真实权值及偏值的周围，对全连接层的权值及偏值进行了regularization。这里有一个讲解regularization作用的[视频](https://www.bilibili.com/video/av6981485/)。

代码示例如下：

```python
def apply_regularization():
    ''' 对全连接层的weights与biases进行regularization '''
    regularation_param = 0.01
    regularation = 0.0
    for weights, biases in zip(self.fc_weights, self.fc_biases):
        regularation += tf.nn.l2_loss(weights) + tf.nn.l2_loss(biases)

    return regularation_param * regularation
self.loss += apply_regularization()
```

- 使用了exponential_decay将学习速度递减

为了减小机器学习在后期的摇摆，使用了exponential_decay将学习速度递减。这里有一个详细讲解在训练过程中要将学习速度递减原理的[视频](https://www.bilibili.com/video/av7373482/)。代码示例如下：

```python
# 逐渐降低学习速率
batch = tf.Variable(0, trainable=False)
starter_learning_rate = 0.001
learning_rate = tf.train.exponential_decay(starter_learning_rate, batch * self.train_batch_size, self.train_batch_size * 10, 0.95, staircase=True)
# 优化
self.optimizer = tf.train.AdamOptimizer(learning_rate).minimize(self.loss, global_step=batch)
```

- 使用tf.train.Saver保存或加载训练的参数

为了利用上一次训练的结果，使用了`tf.train.Saver`保存或加载训练的参数。代码示例如下：

```python
# Add ops to save and restore variables.
self.saver = tf.train.Saver()

# 从磁盘上还原计算图谱参数
if Path(os.getcwd() + ckpt_dir + "/" + ckpt_filename + ".index").is_file():
    self.saver.restore(session, os.getcwd() + ckpt_dir + "/" + ckpt_filename)
    print("Model restored.")

# 将训练得到的计算图谱参数写入磁盘
if not Path(os.getcwd() + ckpt_dir).is_dir():
    os.makedirs(os.getcwd() + ckpt_dir)
save_path = self.saver.save(session, os.getcwd() + ckpt_dir + "/" + ckpt_filename)
print("Model saved in file: %s" % save_path)
```

- 使用tensorboard可视化准确率

使用tensorboard可视化观测准确率的变化。tensorboard的用法可参考[这里](https://www.tensorflow.org/versions/master/how_tos/graph_viz/index.html)。代码示例如下：

```python
self.train_accuracy = calc_accuracy(self.train_prediction, self.tf_train_labels)
self.train_merged_summary = tf.summary.merge([tf.summary.scalar('train_accuracy', self.train_accuracy)])

if self.summary_writer is None:
    self.summary_writer = tf.summary.FileWriter(os.getcwd() + logs_dir, self.graph)

for i, samples, labels in self.get_batch(train_samples, train_labels, batchSize=self.train_batch_size):
    _, train_summary, loss, accuracy = session.run(
        [self.optimizer, self.train_merged_summary, self.loss, self.train_accuracy],
        feed_dict={self.tf_train_samples: samples, self.tf_train_labels: labels}
    )
    self.summary_writer.add_summary(train_summary, i)
```

## 总结

经过这几天的重新学习，终于更进一步理解了tensorflow神经网络的概念，同时整理了一个较合理的代码框架结构，以后其它类型的神经网络可以照此模式书写。



