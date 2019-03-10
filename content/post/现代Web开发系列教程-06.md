---
title: 现代Web开发系列教程_06
tags:
  - javascript
  - nodejs
  - webmvc
categories:
  - web开发
date: 2016-04-26 21:58:00+08:00
---
作为一个从事多年Java Web开发的程序员，面对现如今NodeJS开发Web后端程序一直十分感兴趣，于是花了点时间研究了下，本篇就主要说一说我在项目中应用NodeJS开发后端的具体步骤。实在是受Java Web后端开发影响太大了，我使用NodeJS开发后端程序还是采用了普通Java MVC分层架构，可能与一般的NodeJS程序员的做法不太一样。

## 数据访问层

首先定义一个全局唯一的数据访问对象。

`src/server/dao/DB.js`

```javascript
"use strict";

const orm = require("orm");
const qOrm = require('q-orm');
const transaction = require('orm-transaction');
const config = require('../config.js');

function defineSchemas(db){
    db.schemas = {
        qUser : db.qDefine("users", {
            id : Number,
            username      : String,
            pwd   : String
        })
    };
}

const DB = qOrm.qConnect({
    host:     config.db.host,
    database: config.db.database,
    user:     config.db.user,
    password: config.db.pwd,
    protocol: 'mysql',
    port:     config.db.port,
    query:    {
        reconnect : true,
        pool: true,
        debug: false
    }
}).then(function (db) {
    db.use(transaction);
    defineSchemas(db);
    return db;
}).fail(function (err) {
    throw err;
});

module.exports = DB;
```

可以看到DB还是比较简单的，就是按[orm](https://github.com/dresende/node-orm2)的基本用法定义了数据库连接与数据库中的schema, 这里有一点不同的是我比较喜欢返回Promise对象，避免写过多callback，因此采用了[q-orm](https://github.com/rafaelkaufmann/q-orm)。一般的数据访问层都提供了数据库事务的处理，在NodeJS里，我没找到太多选择，只找到[orm-transaction](https://github.com/dresende/node-orm-transaction)，同样不太喜欢它默认给出的callback用法，简单封装了一个返回Promise的工具方法。

`Transaction.js`

```javascript
module.exports = function(db){
    return new Promise(function(resolve, reject){
        db.transaction(function (err, t) {
            if(!err){
                resolve({
                    qCommit : function (){
                        return new Promise(function(resolve2, reject2){
                            t.commit(function(err){
                                if(!err){
                                    resolve2();
                                } else {
                                    reject2(err);
                                }
                            });
                        });
                    },
                    qRollback : function (){
                        return new Promise(function(resolve2, reject2){
                            t.rollback(function(err){
                                if(!err){
                                    resolve2();
                                } else {
                                    reject2(err);
                                }
                            });
                        });
                    }
                });
            } else {
                reject(err);
            }
        });
    });
};
```

## 业务Service层

这样简直写一个业务Service层实现，有Java基础的同学一看一定觉得很熟悉。

`src/server/service/UserService.js`

```javascript
"use strict";

const DB = require('../dao/DB.js');
const Transaction = require('../dao/Transaction.js');

module.exports = {

    findAll : function *(){
        let db = yield DB;
        let users = yield db.schemas.qUser.qAll();
        return Promise.resolve(users);
    },

    findByUsername : function *(username){
        let db = yield DB;
        let user = yield db.schemas.qUser.qOne({username : username});
        return Promise.resolve(user);
    },

    updateUserPwd : function *(username, pwd){
        let db = yield DB;
        let user = yield db.schemas.qUser.qOne({username : username});
        user.pwd = pwd;
        let transaction = yield Transaction(db);
        try {
            yield user.qSave();
            yield transaction.qCommit();
        } catch (err){
            console.log(err);
            yield transaction.qRollback();
        }
    }
};
```

因为数据访问层都是返回的Promise，这里就可以很方便使用Generator函数与yield来书写代码逻辑了，避免了JavaScript里大量的callback，Generator函数与yield的用法可以参考阮一峰的[异步操作的同步化表达](http://es6.ruanyifeng.com/#docs/generator)。

## Controller层

虽然NodeJS里叫这个为route，但我还是习惯按Java的玩法叫它Controller，我使用了`koa-router`，还是比较好用的。

`src\server\controller\UserController.js`

```javascript
"use strict";

const Router = require('koa-router');

const UserService = require('../service/UserService.js');

const UserController = new Router({
  prefix: '/users'
});

UserController.get('/', function *(){
    let users = yield UserService.findAll();
    this.body = users;
});

UserController.get('/:username', function *(){
    let user = yield UserService.findByUsername(this.params.username);
    this.body = user;
});

UserController.post('/:username', function *(){
    yield UserService.updateUserPwd(this.params.username, this.request.body.pwd);
    this.body = {success : true};
});

module.exports = UserController;
```

## 中间件容器

我使用`koa`作为这个小Web项目的中间件容器，简单写一个启动器。

`src\server\app.js`

```javascript
const koa = require('koa');
const app = koa();
const json = require('koa-json');
const bodyParser = require('koa-bodyparser');

const UserController = require('./controller/UserController.js');

app.use(json({ pretty: false, param: 'pretty' }));

app.use(bodyParser());

app.use(UserController.routes()).use(UserController.allowedMethods());

app.listen(3000);
```

最后执行命令`node src\server\app.js`, 这个小Web项目就跑起来了。

## 总结

个人感觉使用NodeJS写简单的Web后端程序确实比用Java简单了不少，最关键是不用编译，异常地快。

本篇[源代码地址](https://github.com/jeremyxu2010/web_dev/tree/master/demo6)
