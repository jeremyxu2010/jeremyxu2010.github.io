---
title: nodejs项目技术小结
tags:
  - javascript
  - typescript
  - nodejs
  - swagger
  - VueJS
  - koa2
categories:
  - nodejs开发
date: 2020-08-16 18:07:00+08:00
---



最近在很紧张地使用`typescript`开发一个项目。和正常的业务项目很类似，前期的设计及技术框架搭建还有些意思，目前在做的业务功能开发就比较按部就班，今天终于有时间，先将前期技术框架搭建过程中的一些技术点记录下来。

这个项目是一个正常的前后端单体应用，在项目启动之初，考虑到团队内部人员的技术积累，最终选择以`typescript`为前后端主要开发语言。

## 前端项目初始化

前端选用`VueJS`及与之配套的一组成熟的库，使用`vue-cli`创建项目：

```bash
$ npm install -g @vue/cli
$ vue create xx_frontend
```

这里选择`Manually select features`，选择`Babel`、`TypeScript`、`Router`、`Vuex`、`CSS Pre-processors`、`Linter/Formatter`这些特征。

![image-20200816213726968](http://blog-images-1252238296.cosgz.myqcloud.com/image-20200816213726968.png)

## 后端项目初始化

后端我以一个`starter`骨架项目为基础，在此基础上开发业务API接口：

```bash
$ git clone git@github.com:ddimaria/koa-typescript-starter.git
$ cd koa-typescript-starter
$ git checkout -b upgrade-to-typescript-3 origin/upgrade-to-typescript-3
$ yarn install
$ yarn run watch
```

## 前后端接口协议约定

这个项目里前后端使用`swagger.json`描述交互的API接口，事实上`koa-typescript-starter`里本身已经集成了`swagger`的功能。但经过调研，发现让业务开发同学直接编写`swagger.json`难度较大。于是找了种自动生成`swagger.json`文档的方案[koa-swagger-decorator](koa-swagger-decorator)，我对这个库进行了一些增强。

```bash
$ npm install --registry=https://npm.pkg.github.com @jeremyxu2010/koa-swagger-decorator@1.6.1 --save
```

然后就参考[https://github.com/jeremyxu2010/koa-swagger-decorator/blob/master/example/routes/index.js](https://github.com/jeremyxu2010/koa-swagger-decorator/blob/master/example/routes/index.js)简单配置下`SwaggerRouter`，在`Controller`里通过decorator描述每个API接口入参及响应schema就可以了。

```typescript
import {
  request,
  summary,
  body,
  tags,
  middlewares,
  path,
  description,
  producesAll,
  responses
} from '@jeremyxu2010/koa-swagger-decorator';

const tag = tags(['User']);

const logTime = () => async (ctx, next) => {
  console.log(`start: ${new Date()}`);
  await next();
  console.log(`end: ${new Date()}`);
};

const userSchema = {
  name: { type: 'string', required: true, default: 'jeremyxu' },
  password: { type: 'string', required: true, default: '123456' }
};

const userRespSchema = {
  type: 'object',
  properties: {
    name: { type: 'string', required: true }
  },
  example: {
    name: 'jeremyxu'
  }
};

@producesAll(['application/json'])
export default class UserRouter {

  @request('POST', '/user/register')
  @summary('register user')
  @description('example of api')
  @tag
  @middlewares([logTime()])
  @body(userSchema)
  @responses({
    200: { description: 'file upload success', schema: userRespSchema}
  })
  static async register(ctx) {
    const { name } = ctx.validatedBody;
    const user = { name };
    ctx.body = { user };
  }
  
  // ..... other API
}
```

后端项目运行起来即可通过[http://127.0.0.1:3000/swagger-html](http://127.0.0.1:3000/swagger-html)访问到接口文档。

前端同学根据swagger文档快速构建一个可用的mock服务也很方便：

```bash
# 转化swagger.json为openapi.yaml
$ curl -o swagger.json http://127.0.0.1:3000/swagger-json
$ npm install -g swagger2openapi && swagger2openapi -p -w -y -o openapi.yaml swagger.json

# 根据openapi.yaml自动启动一个mock server
$ wget https://github.com/danielgtaylor/apisprout/releases/download/v1.3.0/apisprout-v1.3.0-mac.tar.xz
$ tar -Jxf apisprout-v1.3.0-mac.tar.xz
$ ./apisprout -p 4000 ./openapi.yaml
```

## 生产环境部署

虽然通过`npm run start`可以将服务跑起来，但生产环境还需要利用服务器的多核性能，可以利用`pm2`来自动完成这点：

```bash
$ npm install -g pm2
$ pm2 start ./dist/index.js --name xx_backend --instances 4
```

The End！

## 参考

1. https://juejin.im/post/6844904088048500744
2. https://github.com/ddimaria/koa-typescript-starter/tree/upgrade-to-typescript-3
3. https://github.com/jeremyxu2010/koa-swagger-decorator
4. https://github.com/danielgtaylor/apisprout
5. http://www.doocr.com/articles/5894d4713c6bfb7e3b7fe20e

