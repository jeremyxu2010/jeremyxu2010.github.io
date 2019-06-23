---
title: 保存mysql InnoDB的auto_increment值另类方案
tags:
  - mysql
  - linux
  - bash
categories:
  - 数据库开发
date: 2016-08-04 23:42:00+08:00
---

## 问题描述

mysql数据库有auto_increment这样一个特性，一般是用来设置Integer类型主键自增长。比如下面的代码：

```sql
-- 刚创建表，该表没有AUTO_INCREMENT值
create table test(
  id int(11) primary key not null auto_increment,
  field1 varchar(40) not null default ''
) engine=InnoDB;
show create table test\G;
...
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field1` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
...

-- 插入两条数据后，可以看到该表的AUTO_INCREMENT变为3了
insert into test(field1) values('test1');
insert into test(field1) values('test2');
show create table test\G;
...
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field1` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4
...

-- 删除一条数据后，该表的AUTO_INCREMENT还是3
delete from test where field1='test2';
show create table test\G;
...
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field1` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4
...

-- 再插入一条数据后，该表的AUTO_INCREMENT变为4
insert into test(field1) values('test2');
show create table test\G;
...
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field1` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4
...

-- 删除一条数据后，该表的AUTO_INCREMENT还是4
delete from test where field1='test2';
show create table test\G;
...
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field1` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4
...


-- /etc/init.d/mysql restart 重启后，该表又没有AUTO_INCREMENT值了
show create table test\G;
...
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field1` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
...

-- 再插入一条数据后，这里本来预期该表的AUTO_INCREMENT应该是5的，但实际上却又变为3了
insert into test(field1) values('test2');
show create table test\G;
...
Create Table: CREATE TABLE `test` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field1` varchar(40) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4
...
```

mysql的上述行为说明在mysql运行过程中InnoDB存储引擎的表，其AUTO_INCREMENT值会随着插入操作持续增长的，但mysql重启之后，AUTO_INCREMENT值并没有持久保存下来，重启后再插入数据，mysql会以表中`最大的id+1`作为当前的AUTO_INCREMENT值，新插入的数据的ID就变为这个了。

在mysql的bug跟踪系统里，上述问题已经被很多人反映了，如[链接1](http://bugs.mysql.com/bug.php?id=21641)、[链接2](https://mariadb.atlassian.net/browse/MDEV-6076)

mysql上述行为本身也没有太大的问题，但如果业务系统将这种自增ID当成业务ID就存在问题了。比如在业务系统里创建了一个工单A，该工单对应的自增ID为1002，后来由于业务操作，删除了ID为1002的工单记录，然后系统维护时重启了mysql，后面业务系统里又创建了一个工单B，该工单对应的自增ID就有可能也为1002，然后再以1002为查询条件，就会查到两个不同工单对应的日志。

当然本质上应避免用mysql的这种自增ID作为业务ID，而且应该使用自定义的业务ID生成器。

很不幸，我们目前做的项目，在设计之初并没有考虑到这个问题，因此大量使用这种自增ID作为业务ID。

## 另类解决方案

要从根源上解决这个问题，当然是使用自定义的业务ID来代替mysql的这种自增ID，但项目涉及的表非常多，基于这些表的数据访问方法也相当多，为了避免大规模修改业务代码，只能想办法规避这个问题。查阅mysql的问题跟踪系统，也没找到合理的解决方案。最后在一个讲触发器的帖子影响下想到一种另类解决方案，代码如下：

```bash
#!/bin/bash

MYSQL_HOST=127.0.0.1
MYSQL_USER=root
MYSQL_PWD=mysqlpwd
MYSQL_DBNAME=mysqldb

AUTOINCR_INDEXES_TABLE_NAME=autoincr_indexes
AUTOINCR_INDEXES_TABLE_NAME_COLUMN_NAME=table_name
AUTOINCR_INDEXES_INDEX_VALUE_COLUMN_NAME=index_value

PROCEDURE_NAME=restore_table_indexes

#需保证mysql用户对此文件可读
MYSQL_INIT_FILE=/var/call_procedure.sql



# 1. 创建记录数据库里每个表的auto_increment值的表$AUTOINCR_INDEXES_TABLE_NAME
mysql --batch -u$MYSQL_USER -p$MYSQL_PWD -h$MYSQL_HOST $MYSQL_DBNAME -e "DROP TABLE IF EXISTS $AUTOINCR_INDEXES_TABLE_NAME; CREATE TABLE $AUTOINCR_INDEXES_TABLE_NAME ($AUTOINCR_INDEXES_TABLE_NAME_COLUMN_NAME varchar(40) PRIMARY KEY NOT NULL, $AUTOINCR_INDEXES_INDEX_VALUE_COLUMN_NAME int(11) NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8;"

# 2. 列出数据库里每个表的表名
TABLES=`mysql --batch -u$MYSQL_USER -p$MYSQL_PWD -h$MYSQL_HOST mysql -e "SELECT t.table_name FROM INFORMATION_SCHEMA.TABLES t WHERE t.table_schema = '$MYSQL_DBNAME'" | sed -n '1!p'`

# 3. 针对有自增ID的表，为每个表创建一个自动更新$AUTOINCR_INDEXES_TABLE_NAME表中对应记录的触发器
TMP_CREATE_TRIGGER_FILE="$(mktemp /tmp/$$_create_trigger_XXXX.sql)"
trap "[ -f "$TMP_CREATE_TRIGGER_FILE" ] && rm -f $TMP_CREATE_TRIGGER_FILE" HUP INT QUIT TERM EXIT
for T in ${TABLES[@]} ; do
    autoIncrIndexValue=`mysql --batch -u$MYSQL_USER -p$MYSQL_PWD -h$MYSQL_HOST mysql -e "SELECT AUTO_INCREMENT FROM  INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$MYSQL_DBNAME' AND   TABLE_NAME   = '$T';" | sed -n '1!p' | awk '{print $1}'`
    if [[ $autoIncrIndexValue != "NULL" ]]; then
        #创建插入之后的触发器
        echo "
DELIMITER \$\$
drop trigger /*! IF EXISTS */ ${T}_autoincr_saver \$\$
create trigger ${T}_autoincr_saver
after insert on $T
for each row begin
    DECLARE x integer;
    SET @x = (SELECT AUTO_INCREMENT FROM  INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$MYSQL_DBNAME' AND   TABLE_NAME   = '$T');
    INSERT INTO $AUTOINCR_INDEXES_TABLE_NAME VALUES ('$T', @x) ON DUPLICATE KEY UPDATE $AUTOINCR_INDEXES_INDEX_VALUE_COLUMN_NAME=@x;
end
\$\$
DELIMITER ;
" >> $TMP_CREATE_TRIGGER_FILE
    fi
done
mysql -u$MYSQL_USER -p$MYSQL_PWD -h$MYSQL_HOST $MYSQL_DBNAME < $TMP_CREATE_TRIGGER_FILE
rm -f $TMP_CREATE_TRIGGER_FILE

# 4. 针对有自增ID的表，为每个表在$AUTOINCR_INDEXES_TABLE_NAME表中创建对应记录以保存该表的auto_increment值
for T in ${TABLES[@]} ; do
    autoIncrIndexValue=`mysql --batch -u$MYSQL_USER -p$MYSQL_PWD -h$MYSQL_HOST mysql -e "SELECT AUTO_INCREMENT FROM  INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$MYSQL_DBNAME' AND   TABLE_NAME   = '$T';" | sed -n '1!p' | awk '{print $1}'`
    if [[ $autoIncrIndexValue != "NULL" ]]; then
        mysql --batch -u$MYSQL_USER -p$MYSQL_PWD -h$MYSQL_HOST $MYSQL_DBNAME -e "INSERT INTO $AUTOINCR_INDEXES_TABLE_NAME VALUES ('$T', $autoIncrIndexValue) ON DUPLICATE KEY UPDATE $AUTOINCR_INDEXES_INDEX_VALUE_COLUMN_NAME=$autoIncrIndexValue;"
    fi
done

# 5. 创建一个存储过程，其功能是以$AUTOINCR_INDEXES_TABLE_NAME表的记录为准，恢复每个表的auto_increment值
TMP_CREATE_PROCEDURE_FILE="$(mktemp /tmp/$$_create_trigger_XXXX.sql)"
trap "[ -f "$TMP_CREATE_PROCEDURE_FILE" ] && rm -f $TMP_CREATE_PROCEDURE_FILE" HUP INT QUIT TERM EXIT
echo "
use $MYSQL_DBNAME;
drop procedure IF EXISTS $PROCEDURE_NAME;
delimiter \$\$
create procedure $PROCEDURE_NAME()
begin
    DECLARE done INT DEFAULT 0;
    DECLARE tableName CHAR(40);
    DECLARE indexValue INT;

    -- 声明游标对应的 SQL 语句
    DECLARE cur CURSOR FOR select table_name, index_value from $MYSQL_DBNAME.$AUTOINCR_INDEXES_TABLE_NAME;

    -- 在游标循环到最后会将 done 设置为 1
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- 执行查询
    open cur;
    -- 遍历游标每一行
    REPEAT
        -- 把一行的信息存放在对应的变量中
        FETCH cur INTO tableName, indexValue;
        if not done then
            -- 拼装修改auto_increment值的sql语句，并执行语句
            SET @STMT := CONCAT(\"ALTER TABLE $MYSQL_DBNAME.\", tableName, \" AUTO_INCREMENT=\", indexValue, \";\");
            PREPARE STMT FROM @STMT;
            EXECUTE STMT;
        end if;
    UNTIL done END REPEAT;
    CLOSE cur;
end
\$\$
DELIMITER ;
" > $TMP_CREATE_PROCEDURE_FILE
mysql -u$MYSQL_USER -p$MYSQL_PWD -h$MYSQL_HOST $MYSQL_DBNAME < $TMP_CREATE_PROCEDURE_FILE
rm -f $TMP_CREATE_PROCEDURE_FILE

# 6. 修改my.cnf文件，以使mysql在启动时调用存储过程
echo "
use $MYSQL_DBNAME;
call $PROCEDURE_NAME();
" > $MYSQL_INIT_FILE
sed -i -e "s|^\[mysqld\]$|[mysqld]\ninit-file=$MYSQL_INIT_FILE|" /etc/my.cnf
```

上述代码说起来大概可以归结为以下三点：

* 将所有表的auto_increment值保存下来
* 利用插入后的触发器，在每次插入数据后更新保存的auto_increment值
* 利用init-file参数，在mysql服务启动时调用一个存储过程，该存储过程负责以保存的auto_increment值为基准，恢复每个表的auto_increment值


## 参考

`https://mariadb.atlassian.net/browse/MDEV-6076`
`http://bugs.mysql.com/bug.php?id=199`
`http://dev.mysql.com/doc/refman/5.7/en/trigger-syntax.html`
`http://dev.mysql.com/doc/refman/5.7/en/server-options.html#option_mysqld_init-file`
`http://dev.mysql.com/doc/refman/5.7/en/create-procedure.html`
`http://dev.mysql.com/doc/refman/5.7/en/cursors.html`




