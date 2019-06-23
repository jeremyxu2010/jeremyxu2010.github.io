---
title: java中用好cache
tags:
  - java
  - guava
  - cache
categories:
  - java开发
date: 2016-09-01 23:46:00+08:00
---
在java开发中经常会遇到下面的代码：

```java
Graph get(Key key) {
    Graph result = get( key );
    if( null == result ) {
        result = createNewGraph( key );
        put( key, result );
    }
    return result;
}
```

即根据某个Key值，到缓存里查找是否有对应的值，如没有则创建，并把创建的结果保存在缓存里，供下次使用。

上述代码表面上看没有什么问题。但仔细分析一下就会开始多线程访问时，会根据一个`Key`导致创建了多个`Graph`。加个锁可以立即解决问题，但今天发现Google提供了更优的方案`Google Guava Cache`。

使用`Google Guava Cache`上面的代码可以改写为：

```java
    private static LoadingCache<Key, Graph> cache = CacheBuilder.newBuilder().build(new CacheLoader<Key, Graph>() {
        @Override
        public Graph load(Key key) throws Exception {
            return createNewGraph( key );
        }

        private Graph createNewGraph(Key key) {
            return new Graph();
        }
    });

    public static void main(String[] args) {
        try {
            cache.get(new Key(1));
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
    }
```

这种方案，cache使用起来更方便了。

注意，`get`方法有一个重载方法，可以在get时定义load方式，如下代码：

```java
final Key key = new Key(1);
cache.get(key, new Callable<Graph>(){
    public Graph call() throws Exception {
        return createNewGraph(key);
    }

    private Graph createNewGraph(Key key) {
        return new Graph();
    }
});
```

如果`Google Guava Cache`仅仅只是完成这个功能，那就很一般了。关键是CacheBuilder有很多选项可以来定制Cache的行为，如下：

* 大小的设置：CacheBuilder.maximumSize(long)  CacheBuilder.weigher(Weigher)  CacheBuilder.maxumumWeigher(long)
* 时间：expireAfterAccess(long, TimeUnit) expireAfterWrite(long, TimeUnit)
* 引用：CacheBuilder.weakKeys() CacheBuilder.weakValues()  CacheBuilder.softValues()
* 明确的删除：invalidate(key)  invalidateAll(keys)  invalidateAll()
* 删除监听器：CacheBuilder.removalListener(RemovalListener)



