---
title: 使用keras破解验证码
author: Jeremy Xu
tags:
  - keras
  - tensorflow
  - python
categories:
  - 机器学习
date: 2017-05-07 18:20:00+08:00
---

今天做一个业务功能时，需要自动登录第三方系统，虽然第三方系统已经给我方分配了用户名及密码，但登录时必须必须输入验证码，如此就很难做到自动化登录了。因为前一段时间研究过机器学习，觉得可以使用`keras`, `tensorflow`之类的深度学习框架解决验证码识别的问题。

## 生成训练数据

机器学习一般都需要比较多的训练数据，怎么得到训练数据呢？主要有以下方法：
1. 手动（累死人系列）
2. 破解验证码生成机制，自动生成无限多的训练数据
3. 打入敌人内部（卧底+不要脸+不要命+多大仇系列）

第1个方法太耗人力，当然依赖打码兔之类的技术也可以完成，但也比较费钱，第3个方法太不实际，于是只能从第2个方法入手。检查了下，发现这个第三方网站做得挺随意的，验证码的地址就是`http://xxx.xxx.com/kaptcha.jpg`。从事多年java开发，一看就知道是使用[kaptcha](https://code.google.com/archive/p/kaptcha/wikis/HowToUse.wiki)库生成的验证码。进一步研究发现就是直接采用`kaptcha`的默认配置生成的验证码，这样就比较好办了，直接生成一批验证码出来。代码如下：

`GenKaptcha.java`

```java
import com.google.code.kaptcha.Producer;
import com.google.code.kaptcha.util.Config;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;

/**
 * Created by jeremy on 2017/5/7.
 */
public class GenKaptcha {

    public static void main(String[] args) throws IOException {
        ImageIO.setUseCache(false);
        Config config = new Config(new Properties());
        Producer kaptchaProducer = config.getProducerImpl();
        Path p = Paths.get("pics");
        if(!Files.exists(p)){
            Files.createDirectory(p);
        }
        genPics(kaptchaProducer, 5000);
    }

    private static void genPics(Producer kaptchaProducer, int count) throws IOException {
        for (int i=0; i<count; i++) {
            String capText = kaptchaProducer.createText();
            BufferedImage bi = kaptchaProducer.createImage(capText);
            Path p = Paths.get("pics", i + "_" + capText + ".jpg");
            if(!Files.exists(p)){
                Files.createFile(p);
            }
            ImageIO.write(bi, "jpg", Files.newOutputStream(p));
        }
    }
}
```

## 对训练数据预处理

有了训练数据还需要进行简单的预处理

### 验证码的向量化

验证码是形如`ncn34`之类的字符串，而机器学习时用到的标签也必须是向量，因此写两个方法，分别完成验证码字符串的向量化及反向量化。我们知道一个字符很容易向量化，采用`one-hot encoding`, 那么一个字符串向量化可以简单地把字符one-hot encoding得到的向量拼起来。

```python
# 验证码的可选字符是从kaptcha得到的默认值
captcha_chars = 'abcde2345678gfynmnpwx'

char_idx_mappings = {}
idx_char_mappings = {}

for idx, c in enumerate(list(captcha_chars)):
    char_idx_mappings[c] = idx
    idx_char_mappings[idx] = c

MAX_CAPTCHA = 5
CHAR_SET_LEN = len(captcha_chars)

# 验证码转化为向量
def text2vec(text):
    text_len = len(text)
    if text_len > MAX_CAPTCHA:
        raise ValueError('验证码最长%d个字符'%MAX_CAPTCHA)

    vector = np.zeros(MAX_CAPTCHA*CHAR_SET_LEN)
    for i, c in enumerate(text):
        idx = i * CHAR_SET_LEN + char_idx_mappings[c]
        vector[idx] = 1
    return vector

# 向量转化为验证码
def vec2text(vec):
    text = []
    vec[vec<0.5] = 0
    char_pos = vec.nonzero()[0]
    for i, c in enumerate(char_pos):
        char_idx = c % CHAR_SET_LEN
        text.append(idx_char_mappings[char_idx])
    return ''.join(text)
```

### 图片灰度化

验证码识别这个场景里，图片的色彩并不能帮助识别，因此可以将图片灰度化以减少计算压力。

```python
# 将图片灰度化以减少计算压力
def preprocess_pics():
    for (dirpath, dirnames, filenames) in os.walk(pics_dir):
        for filename in filenames:
            if filename.endswith('.jpg'):
                with open(pics_dir + '/' + filename, 'rb') as f:
                    image = Image.open(f)
                    # 直接使用convert方法对图片进行灰度操作
                    image = image.convert('L')
                    with open(processed_pics_dir + '/' + filename, 'wb') as of:
                        image.save(of)
```

### 提供取得训练数据的方法

为了便于在模型训练时取得训练数据，提供工具方法供外部取得数据

```python
img_idx_filename_mappings = {}
img_idx_text_mappings = {}
img_idxes = []

# 首先遍历目录，根据文件名初始化idx->filename, idx->text的映射，同时初始化idx列表
for (dirpath, dirnames, filenames) in os.walk(processed_pics_dir):
    for filename in filenames:
        if filename.endswith('.jpg'):
            idx = int(filename[0:filename.index('_')])
            text = filename[int(filename.index('_')+1):int(filename.index('.'))]
            img_idx_filename_mappings[idx] = filename
            img_idx_text_mappings[idx] = text
            img_idxes.append(idx)

# 为避免频繁读入文件，将images及labels缓存起来
sample_idx_image_mappings = {}
sample_idx_label_mappings = {}

# 提供给外部取得一批训练数据的接口
def get_batch_data(batch_size):
    images = []
    labels = []
    target_idxes = random.sample(img_idxes, batch_size)
    for target_idx in target_idxes:
        image = None
        if target_idx in sample_idx_image_mappings:
            image = sample_idx_image_mappings[target_idx]
        else:
            with open(processed_pics_dir + '/' + img_idx_filename_mappings[target_idx], 'rb') as f:
                image = Image.open(f)
                # 对数据正则化，tensorflow处理时更高效
                image = np.array(image)/255
            sample_idx_image_mappings[target_idx] = image
        label = None
        if target_idx in sample_idx_label_mappings:
            label = sample_idx_label_mappings[target_idx]
        else:
            label = text2vec(img_idx_text_mappings[target_idx])
            sample_idx_label_mappings[target_idx] = label
        images.append(image)
        labels.append(label)
    x = np.array(images)
    y = np.array(labels)
    return (x, y)
```

### 构造深度学习模型

以前直接玩过`tensorflow`，写起来真的很费劲，这回换`keras`使使，它相当于tensorflow的API简易封装，这次一用就喜欢上它了。直接上代码。

```python
from pathlib import Path
from keras.models import Sequential
from keras.layers import Dense, InputLayer
from keras.layers.core import Reshape, Dropout, Flatten
from keras.layers.convolutional import Conv2D
from keras.layers.pooling import MaxPooling2D
from keras.layers import Input, concatenate
from keras.models import Model

import kaptcha_data

model = Sequential()

# 首先对输入数据reshape一下，因为输入的数据是(-1, kaptcha_data.IMAGE_HEIGHT, kaptcha_data.IMAGE_WIDTH), 要把它变为(-1, kaptcha_data.IMAGE_HEIGHT, kaptcha_data.IMAGE_WIDTH, 1)这样才能方便后面卷积层处理
model.add(InputLayer(input_shape=(kaptcha_data.IMAGE_HEIGHT, kaptcha_data.IMAGE_WIDTH)))
model.add(Reshape((kaptcha_data.IMAGE_HEIGHT, kaptcha_data.IMAGE_WIDTH, 1)))

# 三组卷积逻辑，每组包括两个卷积层及一个池化层
for i in range(3):
    model.add(Conv2D(4*2**i, 3, strides=(1, 1), padding='same', use_bias=True))
    model.add(Conv2D(8*2**i, 5, strides=(1, 1), padding='same', use_bias=True))
    model.add(MaxPooling2D(pool_size=2, strides=2, padding='same'))

# 马上要接上全连接层，要将数据展平
model.add(Flatten())

# 全连接层，输出维数是kaptcha_data.MAX_CAPTCHA * kaptcha_data.CHAR_SET_LEN
image_input = Input(shape=(kaptcha_data.IMAGE_HEIGHT, kaptcha_data.IMAGE_WIDTH))
encoded_image = model(image_input)

encoded_softmax = []
for i in range(kaptcha_data.MAX_CAPTCHA):
    encoded_softmax.append(Dense(kaptcha_data.CHAR_SET_LEN, use_bias=True, activation='softmax')(encoded_image))

output = concatenate(encoded_softmax)

model = Model(inputs=[image_input], outputs=output)

# 编译模型，损失函数使用categorical_crossentropy， 优化函数使用adadelta，每一次epoch度量accuracy
model.compile(loss='categorical_crossentropy', optimizer='adadelta', metrics=['accuracy'])

# 模型可视化
# from keras.utils import plot_model
# plot_model(model, to_file=captcha_preprocess.base_dir + '/captcha_recognition_model.png')

# 加载之前模型的权值
if Path(kaptcha_data.base_dir + '/kaptcha_recognition.h5').is_file():
    model.load_weights(kaptcha_data.base_dir + '/kaptcha_recognition.h5')

batch_size = 64

epoch = 0
while True:
    print("epoch {}...".format(epoch + 1))
    (x_batch, y_batch) = kaptcha_data.get_batch_data(batch_size)
    train_result = model.train_on_batch(x=x_batch, y=y_batch)
    print(' loss: %.6f, accuracy: %.6f' % (train_result[0], train_result[1]))
    if epoch % 50 == 0:
        # 保存模型的权值
        model.save_weights(kaptcha_data.base_dir + '/kaptcha_recognition.h5')
    # 当准确率大于0.5时，说明学习到的模型已经可以投入实际使用，停止计算
    if train_result[1] > 0.5:
        break
    epoch += 1
```

### 验证结果

家里的电脑没有GPU支持，计算起来比较慢，但经过3000多次迭代后，还是达到了0.3以前的准确率。

```
epoch 3502...
 loss: 8.298573, accuracy: 0.312500
```

模型计算好了后，以后要计算某张图片的验证码就简单了。

```python
def get_single_image(filename):
    images = []
    with open(filename, 'rb') as f:
        image = Image.open(f)
        image = image.convert('L')
        images.append(np.array(image)/255)
    return np.array(images)


# 计算某一张图片的验证码
predicts = model.predict(kaptcha_data.get_single_image(kaptcha_data.base_dir + '/pics/0_ncn34.jpg'), batch_size=1)
print('predict: %s' % kaptcha_data.vec2text(predicts[0]))
```

## 总结

有了机器学习以后，以前认为很难突破的障碍变得越来越容易突破了，比如文字验证码，理论上说像`kaptcha`之类的纯粹文字验证码，对机器学习来说真的太容易破解了。另外在平时工作中如正在要用验证码，一定要设置别人不容易猜出来的规则，绝对不能直接用默认的。


