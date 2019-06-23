---
title: 编写mybatis-generator插件
author: Jeremy Xu
tags:
  - mybatis
  - mybatis-generator
categories:
  - java开发
date: 2017-03-20 20:20:00+08:00
---

## 背景

今天在用mybatis写一些单表查询操作业务逻辑时，发现一个简单的查询至少要写三行，如下所示：

```java
DemoCriteria criteria = new DemoCriteria();
criteria.createCriteria().andFiled1EqualTo(filed1Value);
List<Demo> demos = demoMapper.selectByCriteria(criteria);
```

这样写很累啊，于是想了下能否在一行里搞定呢？

## 分析

打开`DemoCriteria.java`，这样找到`createCriteriaInternal`这个方法：

```java
protected Criteria createCriteriaInternal() {
    Criteria criteria = new Criteria();
    return criteria;
}
```

这里我应该可以将`DemoCriteria`对象的引用转入`Criteria`对象，而`Criteria`对象的大部分方法已经支持链式操作，这样就可以在一行完成查询操作，如下面代码示例：

```
protected Criteria createCriteriaInternal() {
    Criteria criteria = new Criteria();
    return criteria;
}

public static class Criteria extends GeneratedCriteria {
    private DemoCriteria topCriteria;

    protected Criteria() {
        super();
    }

    protected Criteria(DemoCriteria topCriteria) {
        super();
        this.topCriteria = topCriteria;
    }

    public DemoCriteria getTopCriteria() {
        return this.topCriteria;
    }
}

// 使用代码示例方法
List<Demo> demos = demoMapper.selectByCriteria(new DemoCriteria().createCriteria().andFiled1EqualTo(filed1Value)getTopCriteria());
```

## 编写mybatis-generator插件

因为工程中的Example类都是用`mybatis-generator`生成出来的，而`mybatis-generator`并没有自带插件完成这件事，因此自己动手写了个插件，如下代码：

```java
package personal.jeremyxu2010.mybatis.plugins;

import org.mybatis.generator.api.IntrospectedTable;
import org.mybatis.generator.api.PluginAdapter;
import org.mybatis.generator.api.dom.java.Field;
import org.mybatis.generator.api.dom.java.FullyQualifiedJavaType;
import org.mybatis.generator.api.dom.java.InnerClass;
import org.mybatis.generator.api.dom.java.JavaVisibility;
import org.mybatis.generator.api.dom.java.Method;
import org.mybatis.generator.api.dom.java.Parameter;
import org.mybatis.generator.api.dom.java.TopLevelClass;

import java.util.List;

/**
 * @Description:
 * @Author: jeremyxu
 * @Created Date: 2017/3/20
 * @Created Time: 9:31
 * @Version:1.0
 */
public class ModelExampleBuilderPlugin extends PluginAdapter {
    public boolean validate(List<String> warnings) {
        return true;
    }

    public boolean modelExampleClassGenerated(TopLevelClass topLevelClass,
                                              IntrospectedTable introspectedTable) {
        for (Method method : topLevelClass.getMethods()) {
            if("createCriteriaInternal".equals(method.getName())){
                method.getBodyLines().clear();
                method.addBodyLine("Criteria criteria = new Criteria(this);"); //$NON-NLS-1$
                method.addBodyLine("return criteria;"); //$NON-NLS-1$
            }
        }
        for (InnerClass innerClass : topLevelClass.getInnerClasses()) {
            if(new FullyQualifiedJavaType("Criteria").equals(innerClass.getType())){
                Field filed = new Field("topCriteria", topLevelClass.getType());
                filed.setVisibility(JavaVisibility.PRIVATE);
                innerClass.addField(filed);

                Method constructMethod = new Method();
                constructMethod.setVisibility(JavaVisibility.PROTECTED);
                constructMethod.setName("Criteria"); //$NON-NLS-1$
                constructMethod.addParameter(new Parameter(topLevelClass.getType(), "topCriteria"));
                constructMethod.setConstructor(true);
                constructMethod.addBodyLine("super();"); //$NON-NLS-1$
                constructMethod.addBodyLine("this.topCriteria = topCriteria;"); //$NON-NLS-1$
                innerClass.addMethod(constructMethod);

                Method getMethod = new Method();
                getMethod.setVisibility(JavaVisibility.PUBLIC);
                getMethod.setName("getTopCriteria"); //$NON-NLS-1$
                getMethod.setReturnType(topLevelClass.getType());
                getMethod.setConstructor(false);
                getMethod.addBodyLine("return this.topCriteria;"); //$NON-NLS-1$
                innerClass.addMethod(getMethod);
            }
        }
        return true;
    }
}
```

代码很简单，就不另外说明了。

然后在`mybatis-generator`的配置文件里加入`<plugin type="personal.jeremyxu2010.mybatis.plugins.ModelExampleBuilderPlugin"></plugin>`就可以了。

这里值得注意的是`PluginAdapter`里提供了很多方法供插件来覆盖，开发者可根据自己的需要修改生成的`domain object`、`domain example object`、`mapper class`、`mapper xml file`，编写插件可参考[这里](http://www.mybatis.org/generator/reference/pluggingIn.html)。

最后安利一下自己常用的一些mybatis-generator插件，见[这里](http://git.oschina.net/jeremy-xu/mybatis-generator-plugins)。

