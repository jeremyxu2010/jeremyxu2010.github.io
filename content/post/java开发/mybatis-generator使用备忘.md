---
title: mybatis-generator使用备忘
author: Jeremy Xu
tags:
  - java
  - mybatis
  - spring
categories:
  - java开发
date: 2017-03-05 23:00:00+08:00
---

最近要做一个新的项目，项目涉及的业务还比较复杂，表相当多。项目使用的技术框架为SSM。于是决定使用mybatis-generator来生成DAO层大部分代码。使用的过程中遇到一些问题，这里小计一下。

## 实体对象属性为枚举

为了避免硬编码，希望生成的实体对象有的属性尽量使用枚举。

可以先定义一个枚举。

`UserStatus.java`

```java
public enum UserState implements CodeTypeEnum<UserState> {
    ENABLED((byte)0),
    DISABLED((byte)1);

    private final Byte code;

    UserState(Byte code) {
        this.code = code;
    }

    @Override
    public Byte getCode(){
        return this.code;
    }
}
```

然后在MBG的配置文件中加入

```xml
<table tableName="user" escapeWildcards="true">
    <columnOverride column="user_status" javaType="personal.jeremyxu.entity.enums.UserState" />
</table>
```

还需要给枚举定义TypeHandler，TypeHandler的代码比较简单，这里为了以后其它枚举能复用，写了一个范式化的TypeHandler

`CodeTypeHandler.java`

```java
public class CodeTypeHandler <E extends CodeTypeEnum> extends BaseTypeHandler<E> {

    private Map<Byte, E> enumMap = new HashMap<Byte, E>();

    public CodeTypeHandler(Class<E> type) {

        E[] enums = type.getEnumConstants();
        if (enums == null) {
            throw new IllegalArgumentException(type.getSimpleName() + " does not represent an enum type.");
        }

        for(E e : enums){
            enumMap.put(e.getCode(), e);
        }

    }

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, E parameter, JdbcType jdbcType) throws SQLException {
        ps.setByte(i, parameter.getCode());
    }

    @Override
    public E getNullableResult(ResultSet rs, String columnName) throws SQLException {
        Byte code = rs.getByte(columnName);
        return enumMap.get(code);
    }

    @Override
    public E getNullableResult(ResultSet rs, int columnIndex) throws SQLException {
        Byte code = rs.getByte(columnIndex);
        return enumMap.get(code);
    }

    @Override
    public E getNullableResult(CallableStatement cs, int columnIndex) throws SQLException {
        Byte code = cs.getByte(columnIndex);
        return enumMap.get(code);
    }
}
```

然后其它具体某个枚举的TypeHandler就可以这么写了

`UserStateTypeHandler.java`

```java
public class UserStateTypeHandler extends CodeTypeHandler<UserState> {
    public UserStateTypeHandler() {
        super(UserState.class);
    }
}
```

最后在MyBatis配置里添加TypeHandler的注册

```xml
<bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
    <property name="dataSource" ref="dataSource" />
    <property name="mapperLocations" value="classpath:personal/jeremyxu/mapper/*.xml" />
    <property name="typeHandlersPackage" value="personal.jeremyxu.entity.enums.handlers" />
</bean>
```

## 定制MBG生成的代码

MBG提供大量的参数用来定制生成的代码，还提供插件机制，方便其它开发者开发插件来定制生成的代码。

我这里的配置如下：

```xml
<context id="default" targetRuntime="MyBatis3">
    ...
    <!-- 为生成的实体类添加equals，hashCode方法 -->
    <plugin type="org.mybatis.generator.plugins.EqualsHashCodePlugin" />
    <!-- 为生成的实体类添加toString方法 -->
    <plugin type="org.mybatis.generator.plugins.ToStringPlugin" />
    <!-- 修改生成的Example类的类名，将其中的Example修改为Criteria -->
    <plugin type="org.mybatis.generator.plugins.RenameExampleClassPlugin">
        <property name="searchString" value="Example$" />
        <property name="replaceString" value="Criteria" />
    </plugin>
    <!-- 修改生成的Mapper类中的方法名或参数名，将方法中的Example修改为Criteria，参数中的example修改为criteria -->
    <plugin type="personal.jeremyxu2010.mybatis.plugins.RenameExampleClassAndMethodsPlugin">
        <property name="classMethodSearchString" value="Example" />
        <property name="classMethodReplaceString" value="Criteria" />
        <property name="parameterSearchString" value="example" />
        <property name="parameterReplaceString" value="criteria" />
    </plugin>
    <!-- 使生成的Example类支持setOffset, setLimit方法，以便分页 -->
    <plugin type="personal.jeremyxu2010.mybatis.plugins.MySQLLimitPlugin" />
    <!-- 将生成的Example类放到filters包下，不跟实体类混在一起 -->
    <plugin type="personal.jeremyxu2010.mybatis.plugins.CreateSubPackagePlugin">
        <property name="exampleSubPackage" value="filters" />
        <property name="exampleClassSuffix" value="" />
    </plugin>

    <commentGenerator>
        <!-- 生成的注释中不带时间戳 -->
        <property name="suppressDate" value="true" />
        <!-- 将数据库中列的注释生成到实体的属性注释里，这个很重要 -->
        <property name="addRemarkComments" value="true" />
    </commentGenerator>

    <javaModelGenerator targetPackage="${modelPackage}" targetProject="${targetProject}">
        <!-- 是否对model添加构造函数 -->
        <property name="constructorBased" value="false" />
        <!-- 是否允许子包，即targetPackage.schemaName.tableName -->
        <property name="enableSubPackages" value="false" />
        <!-- 建立的Model对象是否 不可改变  即生成的Model对象不会有 setter方法，只有构造方法 -->
        <property name="immutable" value="false" />
        <!-- 是否对类CHAR类型的列的数据进行trim操作 -->
        <property name="trimStrings" value="true" />
    </javaModelGenerator>

    <!-- escapeWildcards设置为true可以帮助抵御SQL注入 -->
    <table tableName="user" escapeWildcards="true">
        <columnOverride column="user_status" javaType="personal.jeremyxu.entity.enums.UserState" />
    </table>
    ...
</context>
```

## 生成数据库中的TEXT字段

在表的配置中添加`columnOverride`即可，如下

```xml
<columnOverride column="text_column" jdbcType="VARCHAR" />
```

## 参考项目

这里提供了一个示例工程对上述说到的内容作了演示，地址在[这里](http://git.oschina.net/jeremy-xu/ssm-scaffold)。

