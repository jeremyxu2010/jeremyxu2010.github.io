---
title: InnoDB与MyISAM的区别
author: Jeremy Xu
tags:
  - mysql
  - innoDB
  - MyISAM
categories:
  - 数据库开发
date: 2016-10-28 23:41:00+08:00
---
今天被人问到InnoDB与MyISAM的区别，突然发现虽然平时做项目时经常时经常用到这两种存储引擎，但却只知道两者在事务支持方面的区别，其它的竟一概不知。

回到家立即查阅了相关资料，终于搞清楚这两者之间的真正差异，这里记录一下以备忘。

## 两者之间的差异

* MyISAM类型不支持事务处理等高级处理，而InnoDB类型支持
* MyISAM类型的表强调的是性能，其执行数度比 InnoDB类型更快，但是不提供事务支持，而InnoDB提供事务支持以及外键等高级数据库功能
* InnoDB不支持FULLTEXT类型的索引，而MyISAM支持
* InnoDB 中不保存表的具体行数，也就是说，执行select count(*) from table时，InnoDB要扫描一遍整个表来计算有多少行，但是MyISAM只要简单的读出保存好的行数即可。注意的是，当count(*)语句包含 where条件时，两种表的操作是一样的
* 对于AUTO_INCREMENT类型的字段，InnoDB中必须包含只有该字段的索引，但是在MyISAM表中，可以和其他字段一起建立联合索引
* DELETE FROM table时，InnoDB不会重新建立表，而是一行一行的删除，MyISAM里会重新建立表
* InnoDB支持行锁，MyISAM不支持。但InnoDB的行锁也不是绝对的，假如在执行一个SQL语句时MySQL不能确定要扫描的范围，InnoDB表同样会锁全表，例如update table set num=1 where name like “%a%”
* MyISAM的索引和数据是分开的，并且索引是有压缩的，内存使用率就对应提高了不少，能加载更多索引。而Innodb是索引和数据是紧密捆绑的，没有使用压缩从而会造成Innodb比MyISAM体积庞大不小

## 如何选择

* 数据量小，不太在乎读写性能，但需要事务、外键支持，可选用InnoDB
* 数据量大，读多写少，关注读写性能，可选用MyISAM，事务方面可用CAS的方案实现数据操作的原子性
* MyISAM表由3个文件构成，可直接将这3个文件拷贝到其它数据库，即完成数据迁移，十分便捷
* 需要使用全文索引，则选用MyISAM
* 数据量大，关心数据存储的体积大小，可选用MyISAM
