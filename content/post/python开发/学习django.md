---
title: 学习django
tags:
  - python
  - django
  - web
categories:
  - python开发
date: 2019-12-29 14:48:00+08:00
---

项目中使用了django，这个之前并没有深度使用过，今天花了些时间把官方文档大概浏览了一遍，简单学习了一下，这里简单记录一下以备忘。

## 快速上手步骤

###  安装django

为了能使用`django-admin`命令，先将`django`安装到全局：

```bash
$ pip install Django
```

### 创建项目

```bash
$ django-admin startproject django_demo

$ cd django_demo
# 创建较干净的python virtualenv环境
$ virtualenv --no-site-packages .venv
$ source .venv/bin/activate
# 在此python virtualenv环境安装Django、mysqlclient
$ pip install Django
$ pip install mysqlclient

$ python manage.py startapp test_app
```

### 创建模型类

编辑项目的settings文件：

```bash
$ vim django_demo/settings.py
```

修改如下的片断：

```
INSTALLED_APPS = [
    'test_app.apps.TestAppConfig',
    ......
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'test',
        'USER': 'root',
        'PASSWORD': '123456',
        'HOST': '127.0.0.1',
        'PORT': '3306',
    }
}

TIME_ZONE = 'Asia/Shanghai'
```

修改模型文件：

```bash
$ vim test_app/models.py
```

`test_app/models.py`的内容如[这个文件](https://github.com/jeremyxu2010/django_demo/tree/master/test_app/models.py)。

根据模型文件修改数据库schema：

```bash
$ python ./manage.py makemigrations
$ python ./manage.py migrate
```

### 写模型类对应的测试用例

个人不太喜欢使用django的方案写测试用例，还是喜欢写标准的测试用例：

```bash
$ vim test_app/models_test.py
```

`test_app/models_test.py`的内容如[这个文件](https://github.com/jeremyxu2010/django_demo/tree/master/test_app/models_test.py)。

运行测试用例：

```bash
$ export PYTHONPATH=`pwd`:${PYTHONPATH}
$ python test_app/models_test.py
```

### 编写视图

编写视图文件：

```bash
$ vim test_app/views.py
```

`test_app/views.py`的内容如[这个文件](https://github.com/jeremyxu2010/django_demo/tree/master/test_app/views.py)。

编写模板文件：

```bash
$ vim test_app/templates/index.html
$ vim test_app/templates/detail.html
```

这两个文件的内容如[这些文件](https://github.com/jeremyxu2010/django_demo/tree/master/test_app/templates/)。

配置url：

```bash
$ vim test_app/urls.py
$ vim django_demo/urls.py
```

主要修改了以下几点：

```
from test_app import views

app_name = 'test_app'

urlpatterns = [
    url(r'^$', views.index, name='index'),
    url(r'^(?P<question_id>[0-9]+)/$', views.detail, name="detail")
]
```

```
url(r'^', include('test_app.urls'))
```

### 运行开发Server

```bash
$ python ./manage.py runserver
```

### 运行生产Server

```bash
$ pip install gunicorn==19.10.0
$ gunicorn -b 127.0.0.1:8000 -w 5 django_demo.wsgi
```

## 亮点

之前接触过其它语言的web开发框架，django给我印象比较深刻的是其自带的ORM框架，可参考[Model相关的API](https://docs.djangoproject.com/en/1.11/intro/tutorial02/#playing-with-the-api)。

```bash
>>> from polls.models import Question, Choice   # Import the model classes we just wrote.

# No questions are in the system yet.
>>> Question.objects.all()
<QuerySet []>

# Create a new Question.
# Support for time zones is enabled in the default settings file, so
# Django expects a datetime with tzinfo for pub_date. Use timezone.now()
# instead of datetime.datetime.now() and it will do the right thing.
>>> from django.utils import timezone
>>> q = Question(question_text="What's new?", pub_date=timezone.now())

# Save the object into the database. You have to call save() explicitly.
>>> q.save()

# Now it has an ID. Note that this might say "1L" instead of "1", depending
# on which database you're using. That's no biggie; it just means your
# database backend prefers to return integers as Python long integer
# objects.
>>> q.id
1

# Access model field values via Python attributes.
>>> q.question_text
"What's new?"
>>> q.pub_date
datetime.datetime(2012, 2, 26, 13, 0, 0, 775217, tzinfo=<UTC>)

# Change values by changing the attributes, then calling save().
>>> q.question_text = "What's up?"
>>> q.save()

# objects.all() displays all the questions in the database.
>>> Question.objects.all()
<QuerySet [<Question: Question object>]>
```

这个确实极大简化了操作数据库的复杂度，详情的配置文档可参考[这里](https://docs.djangoproject.com/en/1.11/ref/models/)。

如果想直接操作SQL，方法也很简单，参考[这里](https://docs.djangoproject.com/en/1.11/topics/db/sql/)

另外在web开发领域，一些常见问题均有推荐的解决方案：

1. [处理Form表单](https://docs.djangoproject.com/en/1.11/topics/forms/)
2. [使用middleware](https://docs.djangoproject.com/en/1.11/topics/http/middleware/)
3. [文件上传](https://docs.djangoproject.com/en/1.11/topics/http/file-uploads/)
4. [视图的装饰器](https://docs.djangoproject.com/en/1.11/topics/http/decorators/)
5. [复用视图](https://docs.djangoproject.com/en/1.11/ref/class-based-views/)
6. [使用会话](https://docs.djangoproject.com/en/1.11/topics/http/sessions/)
7. [页面数据分页](https://docs.djangoproject.com/en/1.11/topics/pagination/)
8. [发送邮件](https://docs.djangoproject.com/en/1.11/topics/email/)
9. [处理文件](https://docs.djangoproject.com/en/1.11/topics/files/)
10. [日志处理](https://docs.djangoproject.com/en/1.11/topics/logging/)
11. [认证鉴权](https://docs.djangoproject.com/en/1.11/topics/auth/)
12. [web安全防御](https://docs.djangoproject.com/en/1.11/topics/security/)
13. [序列化反序列化](https://docs.djangoproject.com/en/1.11/topics/serialization/)
14. [性能优化](https://docs.djangoproject.com/en/1.11/topics/performance/)

还是挺全面的。

DONE!

## 参考

1. https://docs.djangoproject.com/en/1.11/intro/
2. https://docs.djangoproject.com/en/1.11/topics/