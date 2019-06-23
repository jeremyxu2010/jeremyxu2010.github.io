---
title: gulp替换webpack
author: Jeremy Xu
tags:
  - gulp
  - react
  - redux
categories:
  - web开发
date: 2016-12-16 17:08:00+08:00
---
之前项目中使用的webpack进行前端代码的编译，但一直不太喜欢webpack的那种玩法。使用webpack编写编译脚本时就是按webpack的规则进行各种配置，必须完全遵守它的条条框框，明明是自己写nodejs代码进行编译，但完全可控感。之前就听说过gulp+browserify的组合，这次就尝试使用这个东东重写编译脚本。话不多说，直接上最后的成果。

## 前端依赖package.json

`package.json`

```javascript
{
  "name": "ssm-scaffold-frontend",
  "version": "1.0.0",
  "description": "SSM scaffold frontend, powered by React and Redux",
  "scripts": {
    "gulp": "./node_modules/.bin/gulp",
    "gulp-production": "./node_modules/.bin/gulp production"
  },
  "author": "Jeremy Xu",
  "license": "ISC",
  "dependencies": {
    "antd": "^2.6.1",
    "axios": "^0.15.3",
    "bootstrap": "^3.3.7",
    "intl": "^1.2.5",
    "lodash": "^4.17.2",
    "react": "^15.4.2",
    "react-dom": "^15.4.2",
    "react-intl": "^2.2.2",
    "react-redux": "^5.0.1",
    "react-router": "^3.0.0",
    "redux": "^3.6.0",
    "redux-thunk": "^2.1.0"
  },
  "devDependencies": {
    "babel-cli": "^6.18.0",
    "babel-plugin-transform-decorators-legacy": "^1.3.4",
    "babel-plugin-transform-object-rest-spread": "^6.20.2",
    "babel-preset-es2015": "^6.18.0",
    "babel-preset-react": "^6.16.0",
    "babelify": "^7.3.0",
    "browserify": "^13.1.1",
    "del": "^2.2.2",
    "errorify": "^0.3.1",
    "glob": "^7.1.1",
    "gulp": "^3.9.1",
    "gulp-clean-css": "^2.3.2",
    "gulp-concat": "^2.6.1",
    "gulp-connect": "^5.0.0",
    "gulp-connect-reproxy": "^0.0.98",
    "gulp-css-image-rev": "^1.0.4",
    "gulp-htmlmin": "^3.0.0",
    "gulp-if-else": "^1.0.3",
    "gulp-less": "3.3.0",
    "gulp-run-sequence": "^0.3.2",
    "gulp-sourcemaps": "^1.9.1",
    "gulp-uglify": "^2.0.0",
    "gulp-util": "^3.0.7",
    "gulp-version-number": "^0.1.5",
    "less": "^2.7.1",
    "merge-stream": "^1.0.1",
    "vinyl-buffer": "^1.0.0",
    "vinyl-source-stream": "^1.1.0",
    "watchify": "^3.8.0"
  }
}
```

可以看到该项目前端主要依赖react、redux、react-router、antd、 bootstrap、axios、lodash、react-intl，这算一个比较常见的选择。前端编译js时使用了gulp、babel、browserify、babelify，编译css时使用了less，使用gulp-connect作为开发服务器。

## gulp编译脚本

`gulpfile.js`

```javascript
const gulp = require('gulp');
const browserify = require('browserify');
const errorify = require('errorify');
const babelify = require("babelify");
const source = require('vinyl-source-stream');
const connect = require('gulp-connect');
const Reproxy = require("gulp-connect-reproxy");
const fs = require('fs');
const path = require('path');
const del = require('del');
const concat = require('gulp-concat');
const merge = require('merge-stream');
const less = require('gulp-less');
const gutil = require('gulp-util');
const ifElse = require('gulp-if-else');
const _ = require('lodash');
const watchify = require('watchify');
const runSequence = require('gulp-run-sequence');
const imageRev = require('gulp-css-image-rev');
const version = require('gulp-version-number');
const buffer = require('vinyl-buffer');
const uglify = require('gulp-uglify');
const cleanCSS = require('gulp-clean-css');
const sourcemaps = require('gulp-sourcemaps');
const htmlmin = require('gulp-htmlmin');

const srcPath = './src';
const buildPath = '../webapp';
const buildJsPath = buildPath + '/js';
const buildImgPath = buildPath + '/img';
const buildCssPath = buildPath + '/css';
const jsEntryPath = srcPath + '/js/pages';
const cssEntryPath = srcPath + '/css/pages';
const htmlEntryPath = srcPath + '/html';

const versionConfig = {
    'value': '%MDS%',
    'append': {
        'key': 'v',
        'to': ['css', 'js','image'],
    },
};

// Environment setup.
var env = {
    production: false
};

// Environment task.
gulp.task("set-production", function(){
    env.production = true;
});

gulp.task("clean", function(cb){
    del([
        path.join(buildPath, '*.html'),
        path.join(buildPath, 'js', '**/*'),
        path.join(buildPath, 'css', '**/*'),
        path.join(buildPath, 'img', '**/*')
    ], {force: true}).then(function(){
        cb();
    });
});

function getPageNames() {
    return fs.readdirSync(jsEntryPath)
        .filter(function(file) {
            return fs.statSync(path.join(jsEntryPath, file)).isDirectory();
        });
}

var pageNames = getPageNames();
var buildjs_tasks = [];
var buildjs_funcs = [];
var buildcss_tasks = [];

gulp.task("prepare", ["clean"], function(){
    let uglifyFunc = function(){
        return uglify({mangle: {except: ['require' ,'import', 'export', 'exports' ,'module']}});
    };
    pageNames.forEach(function(pageName) {
        // 在这里添加自定义 browserify 选项
        let customOpts = {
            entries: [path.join(jsEntryPath, pageName, 'index.js')],
            debug: !env.production,
            plugin: [watchify, errorify]
        };
        let opts = _.assign({}, watchify.args, customOpts);
        let b = browserify(opts);
        b.exclude('lodash');
        b.exclude('react');
        b.exclude('react-dom');
        b.exclude('intl');
        b.exclude('react-intl');
        b.exclude('react-intl-zh');
        b.exclude('react-intl-en');
        b.exclude('react-router');
        b.exclude('redux');
        b.exclude('redux-thunk');
        b.exclude('react-redux');
        b.exclude('antd');
        b.exclude('axios');
        // 在这里加入变换操作
        b.transform(babelify.configure({
            presets: ["es2015", "react"],
            plugins: ["transform-decorators-legacy", "transform-object-rest-spread"]
        }));

        let buildjs = function(){
            return b.bundle()
                .pipe(source(pageName + '_bundle.js'))
                .pipe(buffer())
                .pipe(ifElse(env.production, uglifyFunc))
                // write to output
                .pipe(gulp.dest(buildJsPath));
        };

        gulp.task('buildjs_' + pageName, buildjs); // 这样你就可以运行 `gulp js` 来编译文件了
        buildjs_tasks.push('buildjs_' + pageName);
        buildjs_funcs.push({b: b, func : buildjs});

        gulp.task('buildcss_' + pageName, function(){
            return gulp.src(path.join(cssEntryPath, pageName, 'index.less'))
                .pipe(imageRev())
                .pipe(ifElse(!env.production, function(){
                    return sourcemaps.init();
                }))
                .pipe(less({
                    paths: [ path.join(srcPath, 'css') ]
                }))
                .pipe(ifElse(!env.production, function(){
                    return sourcemaps.write();
                }))
                .pipe(concat(pageName + '_bundle.css'))
                .pipe(ifElse(env.production, function(){
                    return cleanCSS({keepSpecialComments: 0})
                }))
                // write to output
                .pipe(gulp.dest(buildCssPath));
        });
        buildcss_tasks.push('buildcss_' + pageName);
    });

    let b = browserify({
        plugin: [errorify]
    });
    b.require('./node_modules/lodash/lodash'+ (env.production ? '.min':'') + '.js', {expose: 'lodash'});
    b.require('./node_modules/react/dist/react'+ (env.production ? '.min':'') + '.js', {expose: 'react'});
    b.require('./node_modules/react-dom/dist/react-dom'+ (env.production ? '.min':'') + '.js', {expose: 'react-dom'});
    b.require('./node_modules/intl/dist/intl'+ (env.production ? '.min':'') + '.js', {expose: 'intl'});
    b.require('./node_modules/react-intl/dist/react-intl'+ (env.production ? '.min':'') + '.js', {expose: 'react-intl'});
    b.require('./node_modules/react-intl/locale-data/zh.js', {expose: 'react-intl-zh'});
    b.require('./node_modules/react-intl/locale-data/en.js', {expose: 'react-intl-en'});
    b.require('./node_modules/react-router/umd/ReactRouter'+ (env.production ? '.min':'') + '.js', {expose: 'react-router'});
    b.require('./node_modules/redux/dist/redux'+ (env.production ? '.min':'') + '.js', {expose: 'redux'});
    b.require('./node_modules/redux-thunk/dist/redux-thunk'+ (env.production ? '.min':'') + '.js', {expose: 'redux-thunk'});
    b.require('./node_modules/react-redux/dist/react-redux'+ (env.production ? '.min':'') + '.js', {expose: 'react-redux'});
    b.require('./node_modules/antd/dist/antd'+ (env.production ? '.min':'') + '.js', {expose: 'antd'});
    b.require('./node_modules/axios/dist/axios'+ (env.production ? '.min':'') + '.js', {expose: 'axios'});
    let jsVendorBundleTask = b.bundle()
        .pipe(source('vendor_bundle.js'))
        .pipe(buffer())
        .pipe(ifElse(env.production, uglifyFunc))
        // write to output
        .pipe(gulp.dest(buildJsPath));

    let cssVendorBundleTask = gulp.src([
        './node_modules/bootstrap/dist/css/bootstrap'+ (env.production ? '.min':'') + '.css',
        path.join(srcPath, 'css', 'common', 'sb-admin-2'+ (env.production ? '.min':'') + '.css'),
        path.join(srcPath, 'vendors', 'antd', 'antd'+ (env.production ? '.min':'') + '.css')])
        .pipe(concat('vendor_bundle.css'))
        .pipe(ifElse(env.production, function(){
            return cleanCSS({keepSpecialComments: 0})
        }))
        // write to output
        .pipe(gulp.dest(buildCssPath));
    let cssFontTask = gulp.src([path.join(srcPath, 'vendors', 'antd', 'font_*')])
        .pipe(gulp.dest(buildCssPath));
    return merge([]).add(jsVendorBundleTask).add(cssVendorBundleTask).add(cssFontTask);
});

gulp.task('buildAllJs', buildjs_tasks, function(cb){
    cb();
    gutil.log("All Javascript is built.")
});

gulp.task('buildAllCss', buildcss_tasks, function (cb) {
    cb();
    gutil.log("All Stylesheet is built.");
});

gulp.task("image", function(){
    gulp.src([path.join(srcPath, 'img', '**/*')])
        .pipe(gulp.dest(path.join(buildPath, 'img')));
});

gulp.task('html', function(){
    let pageNames = getPageNames();
    let tasks = pageNames.map(function(pageName) {
        return gulp.src(htmlEntryPath + '/' + pageName + '.html')
            .pipe(version(versionConfig))
            .pipe(ifElse(env.production, function(){
                return htmlmin({collapseWhitespace: true});
            }))
            .pipe(gulp.dest(buildPath));
    });
    return merge([]).add(tasks);
});

gulp.task('livereload', ['html'], function () {
    return gulp.src([])
        .pipe(connect.reload());
});

gulp.task('webserver', function() {
    connect.server({
        livereload: true,
        port: "7777",
        root: buildPath,
        //action请求直接反向代理至后端应用服务器
        middleware: function (connect, options) {
            options.rule = [/\/api\//];
            options.server = "127.0.0.1:8080";
            var proxy = new Reproxy(options);
            return [proxy];
        }
    });
});

gulp.task('watch', function() {

    buildjs_funcs.forEach(function(o){
        o.b.on('update', o.func); // 当任何依赖发生改变的时候，运行打包工具
        o.b.on('log', gutil.log); // 输出编译日志到终端
    });

    pageNames.forEach(function(pageName) {
        gulp.watch(path.join(cssEntryPath, pageName, '**/*.less'), ['buildcss_' + pageName]);
    });
    gulp.watch([path.join(srcPath, 'img', '**/*')], ['image']);

    gulp.watch([path.join(srcPath, 'html', '**/*')], ['html']);

    gulp.watch([path.join(buildJsPath, '**/*_bundle.js'), path.join(buildCssPath, '**/*_bundle.css'), path.join(buildImgPath, '**/*')], ['livereload']);
});


gulp.task('default', function(cb){
    runSequence('prepare', ['buildAllJs', 'buildAllCss', 'image'], 'html', 'webserver', 'watch', function(){
        cb();
        gutil.log("Default task is done.");
    });
});

gulp.task('production', function(cb){
    runSequence('set-production', 'prepare', ['buildAllJs', 'buildAllCss', 'image'], 'html',  function(){
        cb();
        gutil.log("Production task is done.");
        process.exit(0);
    });
});
```

这个gulpfile.js看着很长，但其实分成几个task任务，每个task任务的责任还是比较清楚。

`set-production`：这个task负责设置当前编译的环境级别，是开发级别的编译，还是生产级别的编译。
`clean`：这个task负责清理工作。
`prepare`：这个task最复杂了，主要包括两个部分，一是按页面分别定义了编译各页面的js与css任务。二是编译出引用的第三方公共的js、css、font资源。
`buildAllJs`：这个task负责编译所有的页面的js。
`buildAllCss`：这个task负责编译所有的页面的css。
`image`：这个task是对图片进行处理，目前仅仅是拷贝到编译目录。
`html`：这个task对html进行处理，这里会对引用的js, css加入version number以避免浏览器缓存。
`livereload`：这个task用来通知浏览器刷新。
`webserver`: 这个task启动一个开发web服务器，这里使用Reproxy将api请求代理至后端应用服务器。
`watch`：这个task启用监听源代码中的文件变更，当发现文件变更时，进行相应的编译处理。同时监听编译目录下的文件变更，当发现变更时，通过浏览器刷新页面。
`default`：这是default任务，还是将上述多个任务串进来。
`production`：这个是生产级别编译，也就是说仅编译，但不启动开发web服务器，也不监听文件变更。当执行完就退出node进程。

这样一分析，整个gulpfile.js就比较简单了。gulp的用法还是比较简单的，可参考[中文文档](http://www.gulpjs.com.cn/docs/api/)。

## 其它

最后分享一下我做了一个工程脚手架，前端使用react+redux, 前端编译使用gulp+browerify+babel, 后端使用springmvc+spring+MyBatis，项目地址`http://git.oschina.net/jeremy-xu/ssm-scaffold`。
