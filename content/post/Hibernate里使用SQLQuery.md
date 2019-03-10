---
title: Hibernate里使用SQLQuery
tags:
  - java
  - hibernate
  - sql
categories:
  - java开发
date: 2017-01-20 20:40:00+08:00
---

最近在做一个老旧项目，项目后台使用了hibernate。以前虽说也用过hibernate，但用得不够深入，一般最多两个表关联查询一下，比较简单。

但今天在项目有一个需求，要求5个表进行关联查询，这样hibernate试了很久，发现还是搞不定。于是尝试在hibernate里直接使用SQL。在这个地方遇到了坑，卡了很久。最终解决了问题，这里记录一下。

## Hibernate里使用SQL

```java
StringBuilder sql = new StringBuilder();
//这里开始拼装sql语句
//创建SQLQuery对象
SQLQuery sqlQuery = getSession().createSQLQuery(sql.toString());
//调用addScalar， 说明取结果集里的哪些字段， 字段被映射为哪种类型
sqlQuery.addScalar("column1", Hibernate.LONG);
sqlQuery.addScalar("column2", Hibernate.STRING);
sqlQuery.addScalar("column3", Hibernate.STRING);
//设置取的结果集行数
sqlQuery.setFirstResult(...);
sqlQuery.setMaxResults(...);
//设置将对象转化为Cto对象， 注意Cto对象的各属性类型要与addScalar里指明的一致
sqlQuery.setResultTransformer(Transformers.aliasToBean(TestCto.class));
//返回TestCto的List列表
return sqlQuery.list();
```

上述代码中的说明很详细了，就不解释了。

## 总结

hibernate里使用SQL真心很累，还是MyBatis大法好。

