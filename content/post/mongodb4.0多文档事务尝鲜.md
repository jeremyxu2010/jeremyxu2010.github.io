---
title: mongodb4.0多文档事务尝鲜
tags:
  - mongodb
  - golang
  - transactions
categories:
  - go开发
date: 2018-08-19 20:20:00+08:00
---

mongodb4.0也出来一段时间了，这个版本最为大众期待的特性就是支持了多文档事务（multi-document transaction），本文记录一下尝鲜该特性的过程。

## mongodb多文档事务

> In MongoDB, an operation on a single document is atomic. Because you can use embedded documents and arrays to capture relationships between data in a single document structure instead of normalizing across multiple documents and collections, this single-document atomicity obviates the need for multi-document transactions for many practical use cases.
>
> However, for situations that require atomicity for updates to multiple documents or consistency between reads to multiple documents, MongoDB provides the ability to perform multi-document transactions against replica sets. Multi-document transactions can be used across multiple operations, collections, databases, and documents. Multi-document transactions provide an “all-or-nothing” proposition. When a transaction commits, all data changes made in the transaction are saved. If any operation in the transaction fails, the transaction aborts and all data changes made in the transaction are discarded without ever becoming visible. Until a transaction commits, no write operations in the transaction are visible outside the transaction.

在mongodb里，对于单个文档的操作本身是原子性的。而因为在mongodb里还可以采用嵌入式文档和数组来描述文档中的数据结构关系，所以这种单文档原子性基本消除了许多实际对多文档事务的需求。

在mongodb4.0里，对于副本集中的多文档，现在也有了一个机制用来原子性地更新多个文档，以保证读取多个文档的一致性。

看上去挺美好，不过官方文档也说了：

> IMPORTANT
>
> In most cases, multi-document transaction incurs a greater performance cost over single document writes, and the availability of multi-document transaction should not be a replacement for effective schema design. For many scenarios, the [denormalized data model (embedded documents and arrays)](https://docs.mongodb.com/master/core/data-model-design/#data-modeling-embedding) will continue to be optimal for your data and use cases. That is, for many scenarios, modeling your data appropriately will minimize the need for multi-document transactions.
>
> 
>
> Multi-document transactions are available for replica sets only. Transactions for sharded clusters are scheduled for MongoDB 4.2

在大多数场景，多文档事务会产生较大的性能开销，所以合理的模式设计（嵌入式文档和数组）还是应该是最应该优先考虑的解决方案。

另外4.0版本仅支持复制集中的多文档事务，分片集群中的多文档事务将计划在4.2版本中实现。

虽然有以上这些限制，还再怎么说也多了多文档事务能力，比以前还是进步了的。

## 尝鲜步骤

### 安装mongodb4.0

macOS系统比较简单：

```bash
brew install mongodb
brew services start mongodb
```

### 设置复制集名称

参考mongodb的[配置文件设置说明](https://docs.mongodb.com/manual/reference/configuration-options/#replication-options)，修改其主配置文件

```bash
vim /usr/local/etc/mongod.conf
......
# 这里添加复制集名称的选项
replication:
  replSetName: rs0
  
brew services start mongodb
```

### 检查特性兼容版本

因为多文档事务功能是4.0版本新加的，所以要保证特性兼容版本大于等于4.0

```bash
mongo
> db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )
> // 如果特性兼容版本小于4.0，则要设置为4.0
> db.adminCommand( { setFeatureCompatibilityVersion: "4.0" } )
> exit
```

### 初始化复制集

使用[复制集的方法](https://docs.mongodb.com/manual/reference/method/js-replication/)初始化复制集

```bash
mongo
> rs.initiate()
> rs.status()
> exit
```

### 运行多文档事务的例子

从[这里](https://docs.mongodb.com/master/core/transactions/#retry-transaction-and-commit-operation)拷贝多文档事务的例子，保存为`test.js`

`test.js`

```javascript
// Runs the txnFunc and retries if TransientTransactionError encountered

function runTransactionWithRetry(txnFunc, session) {
    while (true) {
        try {
            txnFunc(session);  // performs transaction
            break;
        } catch (error) {
            // If transient error, retry the whole transaction
            if ( error.hasOwnProperty("errorLabels") && error.errorLabels.includes("TransientTransactionError")  ) {
                print("TransientTransactionError, retrying transaction ...");
                continue;
            } else {
                throw error;
            }
        }
    }
}

// Retries commit if UnknownTransactionCommitResult encountered

function commitWithRetry(session) {
    while (true) {
        try {
            session.commitTransaction(); // Uses write concern set at transaction start.
            print("Transaction committed.");
            break;
        } catch (error) {
            // Can retry commit
            if (error.hasOwnProperty("errorLabels") && error.errorLabels.includes("UnknownTransactionCommitResult") ) {
                print("UnknownTransactionCommitResult, retrying commit operation ...");
                continue;
            } else {
                print("Error during commit ...");
                throw error;
            }
       }
    }
}

// Updates two collections in a transactions

function updateEmployeeInfo(session) {
    employeesCollection = session.getDatabase("hr").employees;
    eventsCollection = session.getDatabase("reporting").events;

    session.startTransaction( { readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } } );

    try{
        employeesCollection.updateOne( { employee: 3 }, { $set: { status: "Inactive" } } );
        eventsCollection.insertOne( { employee: 3, status: { new: "Inactive", old: "Active" } } );
    } catch (error) {
        print("Caught exception during transaction, aborting.");
        session.abortTransaction();
        throw error;
    }

    commitWithRetry(session);
}

// Start a session.
session = db.getMongo().startSession( { mode: "primary" } );

try{
   runTransactionWithRetry(updateEmployeeInfo, session);
} catch (error) {
   // Do something with error
} finally {
   session.endSession();
}
```

在运行上述脚本前先创建好脚本依赖的databases及collections：

```bash
mongo
> use hr
> db.createCollection("employees");
> use reporting
> db.createCollection("events")
> exit
```

最后运行示例脚本

```bash
mongo
> load("test.js")
Transaction committed.
true
> exit
```

如果结果是上面那样，说明一切正常。

官方示例虽然写得复杂了一点，不过是考虑了重试运行事务、重试提交事务场景的，应该说考虑还是比较周全的，可以作为其它语言实现的参考。

### 多文档事务的限制

> The following operations are not allowed in multi-document transactions:
>
> - Operations that affect the database catalog, such as creating or dropping a collection or an index. For example, a multi-document transaction cannot include an insert operation that would result in the creation of a new collection.
>
>   The [`listCollections`](https://docs.mongodb.com/master/reference/command/listCollections/#dbcmd.listCollections) and [`listIndexes`](https://docs.mongodb.com/master/reference/command/listIndexes/#dbcmd.listIndexes) commands and their helper methods are also excluded.
>
> - Non-CRUD and non-informational operations, such as [`createUser`](https://docs.mongodb.com/master/reference/command/createUser/#dbcmd.createUser), [`getParameter`](https://docs.mongodb.com/master/reference/command/getParameter/#dbcmd.getParameter), [`count`](https://docs.mongodb.com/master/reference/command/count/#dbcmd.count), etc. and their helpers.

说白了就是只支持对现有collections的增删查改操作及一些基本的信息查询操作，一般数据结构定义操作是不支持了。另外连 [`listCollections`](https://docs.mongodb.com/master/reference/command/listCollections/#dbcmd.listCollections) ， [`listIndexes`](https://docs.mongodb.com/master/reference/command/listIndexes/#dbcmd.listIndexes) 都不支持，如果真有需求，必须在事务外先查询保存起来，这点就比较变态了。

## 其它语言支持

### java语言支持

mongodb的官方其实也提供了[java语言的示例](https://docs.mongodb.com/master/core/transactions/#retry-transaction-and-commit-operation)，不过在java领域还是spring框架用得比较多，`spring-data`要比较新的版本才支持mongodb事务特性，文档见[这里](https://docs.spring.io/spring-data/mongodb/docs/2.1.0.M3/reference/html/#mongo.transactions)，也有[示例代码](https://github.com/spring-projects/spring-data-examples/tree/master/mongodb/transactions)。

### go语言支持

[mongodb社区版go语言驱动](https://github.com/globalsign/mgo)目前还没有支持mongodb4.0的多文档事务特性，看其开发计划，短期是不太可能支持了。

不过看[mongodb官方go语言驱动](https://github.com/mongodb/mongo-go-driver)的提交记录，好像前几天刚好实现了这个功能，赶紧模仿mongo-shell脚本写个go语言测试代码：

```go
package main

import (
	"context"
	"fmt"
	"github.com/mongodb/mongo-go-driver/mongo"
	"github.com/mongodb/mongo-go-driver/core/command"
	"github.com/mongodb/mongo-go-driver/bson"
)

func main() {
	client, err := mongo.Connect(context.Background(), "mongodb://localhost:27017", nil)
	panicIfErr(err)

	sess, err := client.StartSession()
	panicIfErr(err)
	defer sess.EndSession(context.Background())

	runTransactionWithRetry(updateEmployeeInfo, client, sess)
}

// Runs the txnFunc and retries if TransientTransactionError encountered

func runTransactionWithRetry(txnFunc func(*mongo.Client, *mongo.Session) error, client *mongo.Client, sess *mongo.Session) error {
	var err error
	for
	{
		err = txnFunc(client, sess) // performs transaction
		if err != nil {
			if v, ok := err.(command.Error); ok {
				if contains(v.Labels, command.TransientTransactionError) {
					fmt.Println("TransientTransactionError, retrying transaction ...")
					continue
				}
			}
			return err
		}
		break
	}
	return nil
}



// Retries commit if UnknownTransactionCommitResult encountered

func commitWithRetry(sess *mongo.Session) error {
	for
	{
		err := sess.CommitTransaction(context.Background()) // Uses write concern set at transaction start.
		if err != nil {
			if v, ok := err.(command.Error); ok {
				if contains(v.Labels, command.UnknownTransactionCommitResult) {
					fmt.Println("UnknownTransactionCommitResult, retrying commit operation ...")
					continue
				}
			}
			fmt.Println("Error during commit ...")
			return err
		}
		fmt.Println("Transaction committed.")
		break
	}
	return nil
}

// Updates two collections in a transactions

func updateEmployeeInfo(client *mongo.Client, sess *mongo.Session) error{
	employeesCollection := client.Database("hr").Collection("employees")
	eventsCollection := client.Database("reporting").Collection("events")
	err := sess.StartTransaction()
	if err != nil {
		return err
	}
	_, err = employeesCollection.UpdateOne(context.Background(), bson.NewDocument(
		bson.EC.Int32("employee", 3),
	),bson.NewDocument(
		bson.EC.SubDocumentFromElements("$set",
			bson.EC.String("status", "Inactive"),
		),
	), sess)
	if err != nil {
		fmt.Println("Caught exception during transaction, aborting.")
		sess.AbortTransaction(context.Background())
		return err
	}
	_, err = eventsCollection.InsertOne(context.Background(), bson.NewDocument(
		bson.EC.Int32("employee", 3),
		bson.EC.SubDocumentFromElements("status",
			bson.EC.String("new", "Inactive"),
			bson.EC.String("old", "Active"),
		),
	), sess)
	if err != nil {
		fmt.Println("Caught exception during transaction, aborting.")
		sess.AbortTransaction(context.Background())
		return err
	}
	return commitWithRetry(sess)
}

func panicIfErr(err error) {
	if err != nil {
		panic(err)
	}
}

func contains(slice []string, item string) bool {
	set := make(map[string]struct{}, len(slice))
	for _, s := range slice {
		set[s] = struct{}{}
	}

	_, ok := set[item]
	return ok
}
```

果然是好使的，不过[mongodb官方go语言驱动](https://github.com/mongodb/mongo-go-driver)目前还未发正式版，现在还是第11个alpha版本，能否直接用于生产就很难说了。

OVER

## 参考

1. https://docs.mongodb.com/master/core/transactions/
2. https://docs.mongodb.com/manual/reference/configuration-options/#replication-options
3. https://docs.mongodb.com/manual/reference/method/js-replication/
4. https://docs.mongodb.com/master/core/transactions/
5. https://docs.mongodb.com/manual/tutorial/write-scripts-for-the-mongo-shell/
6. https://github.com/mongodb/mongo-go-driver/