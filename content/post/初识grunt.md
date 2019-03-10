---
title: 初识grunt
author: Jeremy Xu
tags:
  - grunt
  - bower
categories:
  - web开发
date: 2014-05-30 01:40:00+08:00
---

很早就听人提过grunt，我的概念里一直认为它是一个类似java界maven的东西，帮助开发人员从频繁地编译、配置管理等工作中解放出来。今天比较有空，就尝试使用一下这个东西，看看它是不是真的那么好用。

首先安装nodejs

```bash
#安装Homebrew
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
#安装nodejs
brew install node
#安装grunt-cli
npm install -g grunt-cli
```

切换到工程目录，安装3个nodejs模块

```bash
npm install grunt --save-dev
npm install grunt-contrib-uglify --save-dev
npm install grunt-contrib-htmlmin --save-dev
```

在工程目录中新建一个`Gruntfile.js`文件

```javascript
module.exports = function(grunt) {
  // Project configuration.
  grunt.initConfig({
    uglify: {
      build: {
          options: {
              preserveComments: false,
              compress: {
                  drop_console: true
              },
              banner: '/*! compress js file date : ' + '<%= grunt.template.today("yyyy-mm-dd") %> */'
          },
          files: [{
              expand: true,
              cwd: 'src/',
              src: '**/*.js',
              dest: 'build/'
          }]
      }
    },
    htmlmin: {
        build: {
            options: {                                 // Target options
                removeComments: true,
                collapseWhitespace: true
            },
            files: [{
                expand: true,
                cwd: 'src/',
                src: '**/*.html',
                dest: 'build/'
            }]
        }
    }
  });

  // 加载包含 "uglify" 任务的插件。
  grunt.loadNpmTasks('grunt-contrib-uglify');

  // 加载包含 "htmlmin" 任务的插件。
  grunt.loadNpmTasks('grunt-contrib-htmlmin');

  // 默认被执行的任务列表。
  grunt.registerTask('default', ['uglify', 'htmlmin']);
};
```

这个文件需要理解一下每个Gruntfile(和Grunt插件)都使用下面这个基本格式，并且所有Grunt代码都必须指定在这个函数里面：

```
module.exports = function(grunt) {
    // 在这里处理Grunt相关的事情
}
```

这个函数里面的内容一般会有一个项目配置、加载多个任务的插件、多个自定义任务，每个任务里又可以定义多个目标，每个任务和每个目标都可以有options配置，配置遵循就近原则（离目标越近,其优先级越高），大概形式如下：

```
    // 项目配置
    grunt.initConfig({
        task1: {
            options: {
            },
            target1: {
                options: {
                }
            },
            target2: {
            }
        }，
        task2: {
            target1: {
            },
            target2: {
            }
        }
        .....

    });

    // 加载提供"task1"任务的插件
    grunt.loadNpmTasks('task1_node_module_name');
    // 加载提供"task2"任务的插件
    grunt.loadNpmTasks('task2_node_module_name');
    ....

    grunt.registerTask('task3', ['task1:target1', 'task2']);
    grunt.registerTask('default', ['task1', 'task2']);
```

然后就可以使用`grunt task1:target1`, `grunt task2`(这个会执行task2下的所有目标), `grunt task3`来执行了, 其中名称叫default的自定义任务比较特殊，当直接执行`grunt`时，会执行这个任务。

当然还一些高级特性，这个看看官方文档就清楚了，比如数据属性、多种多样的文件描述、项目脚手架等。

了解地差不多了，我准备把前两个写的那个pingdemo使用grunt来构建试试看，期间还稍微看了下bower。

安装bower

```bash
npm install -g bower
```

在项目根目录下创建`bower.json`文件

```json
{
  "name": "pingdemo",
  "version": "0.1.0",
  "main": "build/main.js",
  "ignore": [
    "**/*.txt"
  ],
  "dependencies": {
    "jquery": "2.1.1"
  },
  "private": true
}
```

安装项目依赖的外部js文件

```bash
bower install
```

这样它会自动从github上下载jquery。

最后放出重新整理过工程结构的pingdemo地址

`https://github.com/jeremyxu2010/pingdemo`
