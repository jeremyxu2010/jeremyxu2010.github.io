---
title: 使用grunt对css中的background图片自动生成雪碧图
author: Jeremy Xu
tags:
  - grunt
  - nodejs
  - css
categories:
  - web开发
date: 2015-03-31 01:40:00+08:00
---

公司研发的系统为B/S架构，用户使用浏览器访问系统时，使用浏览器自带工具查看，对图片的请求数极多，多为小图片。

今天想对这个现状进行改善，网上查到一种雪碧图的方案，其实就是使用工具将数量很多的小图片拼成一张大图片，然后css里都引用这张大图片，并指定显示该图片的某一个区域，但这个方案需要手工作很多处理。

于是就想到能不能用目前比较成熟的grunt对前端样式文件自动进行处理，自动生成雪碧图，自动修改样式文件。一搜索果然找到了方案，下面为Gruntfile.js文件的片断：

```javascript
module.exports = function(grunt) {
  // Project configuration.
  grunt.initConfig({
    // 自动雪碧图
    sprite: {
      options: {
        // 映射CSS中背景路径，支持函数和数组，默认为 null
        imagepath_map: null,
        // 各图片间间距，如果设置为奇数，会强制+1以保证生成的2x图片为偶数宽高，默认 0
        padding: 0,
        // 是否使用 image-set 作为2x图片实现，默认不使用
        useimageset: false,
        // 是否以时间戳为文件名生成新的雪碧图文件，如果启用请注意清理之前生成的文件，默认不生成新文件
        newsprite: false,
        // 给雪碧图追加时间戳，默认不追加
        spritestamp: true,
        // 在CSS文件末尾追加时间戳，默认不追加
        cssstamp: true,
        // 默认使用二叉树最优排列算法
        algorithm: 'binary-tree',
        // 默认使用`pixelsmith`图像处理引擎
        engine: 'pixelsmith'
      },
      sprite_module1: { //只对module1目录进行自动生成雪碧图处理
        options : {
          // sprite背景图源文件夹，只有匹配此路径才会处理，默认 images/slice/
          imagepath: 'module1/images/',
          // 雪碧图输出目录，注意，会覆盖之前文件！默认 images/
          spritedest: 'module1/images/'
        },
        files: [{
          // 启用动态扩展
          expand: true,
          // css文件源的文件夹
          cwd: 'module1/',
          // 匹配规则
          src: ['**/*.css', '!**/*.sprite.css'],
          // 导出css和sprite的路径地址
          dest: 'module1/',
          // 导出的css名
          ext: '.sprite.css',
          extDot: 'last'
        }]
      }
    }
  });

  // 加载包含 "sprite" 任务的插件。
  // grunt.loadNpmTasks('grunt-css-sprite'); //因为希望生成的雪碧图为.sprite.png结尾，对原来的grunt-css-sprite作了些改动，于是手动加载grunt_tasks
  grunt.loadTasks('grunt_tasks');
  grunt.registerTask('default', ['sprite']);
};
```

`package.json`

```json
{
  "name": "xxx",
  "version": "x.x.x",
  "devDependencies": {
    "grunt": "0.4.5",
    "async": "0.9.0",
    "spritesmith": "1.3.0"
  }
}
```

grunt_tasks目录结构如下：

```
grunt_tasks
    - sprite_libs
        - css-spritesmith.js
        - imageSetSpriteCreator.js
        - place_after.png
        - place_before.png
    - sprite.js
```


其中

`sprite.js` 从 `https://github.com/laoshu133/grunt-css-sprite` 工程里得来

`css-spritesmith.js`、`imageSetSpriteCreator.js`、`place_after.png`、`place_before.png` 从 `https://github.com/laoshu133/css-spritesmith` 工程里得来，但修改了`css-spritesmith.js`文件

```javascript
...
sliceData.timestamp = options.spritestamp ? timeNow : '';

sliceData.timestamp = options.spritestamp ? ('?'+timeNow) : '';
sliceData.imgDest = fixPath(path.join(options.spritedest, cssFilename + '.sprite.png'));
sliceData.spriteImg = fixPath(path.join(options.spritepath, cssFilename + '.sprite.png')) +
    sliceData.timestamp;

sliceData.retinaImgDest = fixPath(sliceData.imgDest.replace(/\.png$/, '@2x.sprite.png'));
sliceData.retinaSpriteImg = fixPath(path.join(options.spritepath, cssFilename + '@2x.sprite.png')) +  sliceData.timestamp;
...
```
