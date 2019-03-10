---
title: hibernate查询的一些优化写法
tags:
  - java
  - hibernate
  - spring
categories:
  - java开发
author: Jeremy Xu
date: 2017-02-13 20:30:00+08:00
---

项目中使用hibernate进行数据库查询，但由于项目历时较长，经手的人较多，DAO层的代码风格很不致，这里将一些常见的场景进行归纳，并给出推荐的写法。

- 根据ID查询实体

```java
// 不推荐
Demo demo = getSession().createQuery("from Demo where id=?").setLong(0, id).uniqueResult();
// 推荐
Demo demo = getHibernateTemplate().get(Demo.class, id);
```

- 根据某些条件查询

```java
// 不推荐
List<Demo> demos = getSession().createQuery(hql).setLong(0, param1).setParameter(1, param2).list();
// 推荐
List<Demo> demos = getHibernateTemplate().find(hql, param1, param2);
```

- 根据某个条件查询唯一的返回值

```java
// 不推荐
Demo demo = getSession().createQuery(hql).setLong(0, param1).setParameter(1, param2).uniqueResult();
// 推荐
Demo demo = DataAccessUtils.uniqueResult((List<Demo>)getHibernateTemplate().find(hql, param1, param2));
```

- 删除、保存、更新实体

```java
// 不推荐
getSession().delete(demo);
getSession().save(demo);
getSession().saveOrUpdate(demo);
getSession().update(demo);
// 推荐
getHibernateTemplate().delete(demo);
getHibernateTemplate().save(demo);
getHibernateTemplate().saveOrUpdate(demo);
getHibernateTemplate().update(demo);
```

- 执行更新操作

```java
// 不推荐
getSession().createQuery(hql).setLong(0, param1).setParameter(1, param2).executeUpdate();
// 推荐
getHibernateTemplate().bulkUpdate(hql, param1, param2);
```

- 执行SQL

```java
// 不推荐
getSession().createSQLQuery(sql).setLong(0, param1).setParameter(1, param2).executeUpdate();
// 推荐
getHibernateTemplate().execute(new HibernateCallback<Void>() {
    @Override
    public Void doInHibernate(Session session) throws HibernateException, SQLException {
        session.createSQLQuery(sql).setLong(0, param1).setParameter(1, param2).executeUpdate();
        return null;
    }
});
```

- 查询数目

```java
// 不推荐
Long count = (Long)getSession().createQuery("select count(*) from Demo where param1=? and param2=?").setParameter(0, param1).setParameter(1, param2).uniqueResult();
// 推荐
long count = DataAccessUtils.longResult(getHibernateTemplate().find("select count(*) from Demo where param1=? and param2=?", param1, param2));
```

- 分页查询

```java
// 不推荐
Query query = getSession().createQuery(hql).setParameter(0, param1).setParameter(1, param2);
query.setFirstResult(offset);
query.setMaxResults(limit);
List<Demo> demos = query.list();
// 推荐
List<Demo> demos = getHibernateTemplate().executeFind(new HibernateCallback<List<Demo>>() {
    @Override
    public List<Demo> doInHibernate(Session session) throws HibernateException, SQLException {
        Query query = session.createSQLQuery(hql).setLong(0, param1).setParameter(1, param2);
        query.setFirstResult(offset);
        query.setMaxResults(limit);
        return query.list();
    }
});
```

- 使用Criteria

```java
// 不推荐
Criteria criteria = getSession().createCriteria(Demo.class);
criteria.add(Restrictions.eq("param1", param1));
List<Demo> demos = criteria.list();
// 推荐
DetachedCriteria criteria = DetachedCriteria.forClass(Demo.class)
    .add(Restrictions.eq("param1", param1));
List<Demo> demos = getHibernateTemplate().findByCriteria(criteria);
```

- 使用Criteria加分页功能

```java
Criteria criteria = getSession().createCriteria(Demo.class);
criteria.add(Restrictions.eq("param1", param1));
List<Demo> demos = criteria.list();
// 推荐
DetachedCriteria criteria = DetachedCriteria.forClass(Demo.class)
    .add(Restrictions.eq("param1", param1));
List<Demo> demos = getHibernateTemplate().findByCriteria(criteria, offset, pageSize);
```



