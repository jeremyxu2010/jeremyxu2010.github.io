---
title: 两种获取hibernate会话的区别
tags:
  - java
  - hibernate
categories:
  - java开发
author: Jeremy Xu
date: 2017-02-09 20:30:00+08:00
---

今天在工作中，发现用Hibernate实现的DAO类中存在两种获取hibernate会话的方式，如下：

```java
@Repository("demoDao")
public class DemoDaoImpl extends HibernateDaoSupport implements DemoDao{
    //通过getSession方法获取
    @Override
    public Demo method1(final Integer param) {
        Session session = this.getSession();
        ...
    }

    //通过getHibernateTemplate().execute方法获取
    @Override
    public Demo method2(final Integer param) {
        return getHibernateTemplate().execute(new HibernateCallback<Demo>() {
            @Override
            public AppPzTestStats doInHibernate(Session session) throws HibernateException, SQLException {
                ...
            }
        });
    }
}

```

研究了下，这两种方式还有有区别的，先看看javadoc。

```java
	/**
	 * Obtain a Hibernate Session, either from the current transaction or
	 * a new one. The latter is only allowed if the
	 * {@link org.springframework.orm.hibernate3.HibernateTemplate#setAllowCreate "allowCreate"}
	 * setting of this bean's {@link #setHibernateTemplate HibernateTemplate} is "true".
	 * <p><b>Note that this is not meant to be invoked from HibernateTemplate code
	 * but rather just in plain Hibernate code.</b> Either rely on a thread-bound
	 * Session or use it in combination with {@link #releaseSession}.
	 * <p>In general, it is recommended to use HibernateTemplate, either with
	 * the provided convenience operations or with a custom HibernateCallback
	 * that provides you with a Session to work on. HibernateTemplate will care
	 * for all resource management and for proper exception conversion.
	 * @return the Hibernate Session
	 * @throws DataAccessResourceFailureException if the Session couldn't be created
	 * @throws IllegalStateException if no thread-bound Session found and allowCreate=false
	 * @see org.springframework.orm.hibernate3.SessionFactoryUtils#getSession(SessionFactory, boolean)
	 * @deprecated as of Spring 3.2.7, in favor of {@link HibernateTemplate} usage
	 */
	@Deprecated
	protected final Session getSession() throws DataAccessResourceFailureException, IllegalStateException {
		return getSession(this.hibernateTemplate.isAllowCreate());
	}

	/**
	 * Execute the action specified by the given action object within a
	 * {@link org.hibernate.Session}.
	 * <p>Application exceptions thrown by the action object get propagated
	 * to the caller (can only be unchecked). Hibernate exceptions are
	 * transformed into appropriate DAO ones. Allows for returning a result
	 * object, that is a domain object or a collection of domain objects.
	 * <p>Note: Callback code is not supposed to handle transactions itself!
	 * Use an appropriate transaction manager like
	 * {@link HibernateTransactionManager}. Generally, callback code must not
	 * touch any {@code Session} lifecycle methods, like close,
	 * disconnect, or reconnect, to let the template do its work.
	 * @param action callback object that specifies the Hibernate action
	 * @return a result object returned by the action, or {@code null}
	 * @throws org.springframework.dao.DataAccessException in case of Hibernate errors
	 * @see HibernateTransactionManager
	 * @see org.hibernate.Session
	 */
	<T> T execute(HibernateCallback<T> action) throws DataAccessException;

```

从文档上看，`getSession`的方式得到的Session需要由程序员自行调用`releaseSession`方法进行session的释放，而且`getSession`方法已经不推荐使用了。官方更推荐使用`hibernateTemplate`配合`HibernateCallback`的方案。这种方案由hibernate负责处理资源的管理及异常的转换。

另外看到网上[一哥们的分析](http://www.cnblogs.com/yangy608/archive/2012/04/26/2471787.html)，于是更坚信了要使用`hibernateTemplate`配合`HibernateCallback`的方案。一搜项目，竟然有700多处都是老写法，看来得花一番功夫将所有这些代码改成推荐的方案了。

