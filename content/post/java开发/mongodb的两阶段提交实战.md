---
title: mongodb的两阶段提交实战
tags:
  - mongodb
  - java
  - transactions
categories:
  - java开发
date: 2018-07-03 20:20:00+08:00
---

项目中用到了mongodb（3.x版本），业务上需要操作mongodb的多个collections，希望要么同时操作成功，要么回滚操作保持数据的一致性，这个实际上要求在mongodb上实现事务功能，在网上查了下资料，发现了两阶段提交的方案，不过网上基本上都是翻译，很少有人具体分析原理的，今天花了些时间仔细思考了下这个方案，记录在这里以备忘。

## MongoDB两阶段提交原理

下面的内容摘自[官方说明的翻译](https://acupple.github.io/2016/08/09/MongoDB%E4%B8%A4%E9%98%B6%E6%AE%B5%E6%8F%90%E4%BA%A4%E5%AE%9E%E7%8E%B0%E4%BA%8B%E5%8A%A1/)，完整的[英文版说明](https://docs.mongodb.com/tutorials/perform-two-phase-commits)。

MongoDB数据库中操作单个文档总是原子性的，然而，涉及多个文档的操作，通常被作为一个“事务”，而不是原子性的。因为文档可以是相当复杂并且包含多个嵌套文档，单文档的原子性对许多实际用例提供了支持。尽管单文档操作是原子性的，在某些情况下，需要多文档事务。在这些情况下，使用两阶段提交，提供这些类型的多文档更新支持。因为文档可以表示为Pending数据和状态，可以使用一个两阶段提交确保数据是一致的，在一个错误的情况下，事务前的状态是可恢复的。

事务最常见的例子是以可靠的方式从A账户转账到B账户，在关系型数据库中，此操作将从A账户减掉金额和给B账户增加金额的操作封装在单个原子事务中。在MongoDB中，可以使用两阶段提交达到相同的效果。本文中的所有示例使用mongo shell与数据库进行交互,并假设有两个集合：首先，一个名为accounts的集合存储每个账户的文档数据，另一个名为transactions的集合存储事务本身。

首先创建两个名为A和B的账户，使用下面的命令：

```
db.accounts.save({name:"A", balance:1000, pendingTransactions: []})
db.accounts.save({name:"B", balance:1000, pendingTransactions: []})
```

使用find()方法验证这两个操作已经成功：

```
db.accounts.find()
```

mongo会返回两个类似下面的文档：

```
{ "_id" :ObjectId("4d7bc66cb8a04f512696151f"), "name" :"A", 
    "balance" :1000, "pendingTransactions" :[ ]}
{ "_id" :ObjectId("4d7bc67bb8a04f5126961520"), "name" :"B",
     "balance" :1000, "pendingTransactions" :[ ]}
```

### 事务过程

#### 设置事务初始状态initial

通过插入下面的文档创建transaction集合，transaction文档持有源(source)和目标(destination)，它们引用自accounts集合文档的字段名，以及value字段表示改变balance字段数量的数据。最后，state字段反映事务的当前状态。

```
db.transactions.save({source:"A", destination:"B", value:100, 
    state:"initial"})
```

验证这个操作已经成功，使用find()：

```
db.transactions.find()
```

这个操作会返回一个类似下面的文档：

```
{ "_id" :ObjectId("4d7bc7a8b8a04f5126961522"), "source" :"A", 
    "destination" :"B", "value" :100, "state" :"initial"}
```

#### 切换事务到Pending状态

在修改accounts集合记录之前，将事务状态从initial设置为pending。使用findOne()方法将transaction文档赋值给shell会话中的局部变量t：

```
t =db.transactions.findOne({state:"initial"})
```

变量t创建后，shell将返回它的值，将会看到如下的输出：

```
{ "_id" :ObjectId("4d7bc7a8b8a04f5126961522"), "source" :"A",
     "destination" :"B", "value" :100, "state" :"initial"}
```

#### 使用update()改变state的值为pending

```
db.transactions.update({_id:t._id},{$set:{state:"pending"}})
db.transactions.find()
```

find()操作将返回transaction集合的内容，类似下面：

```
{ "_id" :ObjectId("4d7bc7a8b8a04f5126961522"), "source" :"A", 
    "destination" :"B", "value" :100, "state" :"pending"}
```

### 将事务应用到两个账户

使用update()方法应用事务到两个账户。在update()查询中，条件pendingTransactions:{$ne:t._id}阻止事务更新账户，如果账户的pendingTransaction字段包含事务t的_id：

```
db.accounts.update({name:t.source, 
    pendingTransactions: { $ne: t._id }},
    {$inc:{ balance: -t.value }, 
    $push:{pendingTransactions:t._id }})
db.accounts.update({name:t.destination, 
    pendingTransactions: { $ne: t._id }},
    {$inc:{ balance: t.value }, 
    $push:{pendingTransactions:t._id }})
db.accounts.find()
```

find()操作将返回accounts集合的内容，现在应该类似于下面的内容：

```
{ "_id" :ObjectId("4d7bc97fb8a04f5126961523"), "balance" :900, "name" :"A", 
    "pendingTransactions" :[ ObjectId("4d7bc7a8b8a04f5126961522") ] }
{ "_id" :ObjectId("4d7bc984b8a04f5126961524"), "balance" :1100, "name" :"B", 
    "pendingTransactions" :[ ObjectId("4d7bc7a8b8a04f5126961522") ] }
```

### 设置事务状态为committed

使用下面的update()操作设置事务的状态为committed：

```
db.transactions.update({_id:t._id},{$set:{state:"committed"}})db.transactions.find()
```

find()操作发回transactions集合的内容，现在应该类似下面的内容：

```
{ "_id" :ObjectId("4d7bc7a8b8a04f5126961522"), "destination" :"B", 
    "source" :"A", "state" :"committed", "value" :100}
```

### 移除pending事务

使用下面的update()操作从accounts集合中移除pending事务：

```
db.accounts.update({name:t.source},{$pull:{pendingTransactions: t._id}})
db.accounts.update({name:t.destination},{$pull:{pendingTransactions: t._id}})
db.accounts.find()
```

find()操作返回accounts集合内容，现在应该类似下面内容：

```
{ "_id" :ObjectId("4d7bc97fb8a04f5126961523"), "balance" :900, "name" :"A", 
    "pendingTransactions" :[ ] }
{ "_id" :ObjectId("4d7bc984b8a04f5126961524"), "balance" :1100, "name" :"B", 
    "pendingTransactions" :[ ] }
```

### 设置事务状态为done

通过设置transaction文档的state为done完成事务：

```
db.transactions.update({_id:t._id},{$set:{state:"done"}})
db.transactions.find()
```

find()操作返回transaction集合的内容，此时应该类似下面：

```
{ "_id" :ObjectId("4d7bc7a8b8a04f5126961522"), "destination" :"B", 
    "source" :"A", "state" :"done", "value" :100}
```

### 从失败场景中恢复

最重要的部分不是上面的典型例子，而是从各种失败场景中恢复未完成的事务的可能性。这部分将概述可能的失败，并提供方法从这些事件中恢复事务。这里有两种类型的失败：

1. 所有发生在第一步（即设置事务的初始状态initial）之后，但在第三步（即应用事务到两个账户）之前的失败。为了还原事务，应用应该获取一个pending状态的transaction列表并且从第二步（即切换事务到pending状态）中恢复。
2. 所有发生在第三步之后（即应用事务到两个账户）但在第五步(即设置事务状态为done)之前的失败。为了还原事务，应用需要获取一个committed状态的事务列表，并且从第四步（即移除pending事务）恢复。

因此应用程序总是能够恢复事务，最终达到一个一致的状态。应用程序开始捕获到每个未完成的事务时运行下面的恢复操作。你可能还希望定期运行恢复操作，以确保数据处于一致状态。达成一致状态所需要的时间取决于应用程序需要多长时间恢复每个事务。

## 回滚

在某些情况下可能需要“回滚”或“撤消”事务，当应用程序需要“取消”该事务时，或者是因为它永远需要恢复当其中一个帐户不存在的情况下，或停止现有的事务。这里有两种可能的回滚操作：

1. 应用事务（即第三步）之后，你已经完全提交事务，你不应该回滚事务。相反，创建一个新的事务，切换源(源)和目标(destination)的值。
2. 创建事务（即第一步）之后，在应用事务（即第三步）之前，使用下面的处理过程：

#### 设置事务状态为canceling

首先设置事务状态为canceling，使用下面的update()操作：

```
db.transactions.update({_id:t._id},{$set:{state:"canceling"}})
```

#### 撤销事务

使用下面的操作顺序从两个账户中撤销事务：

```
db.accounts.update({name:t.source, 
    pendingTransactions: t._id},
    {$inc:{balance: t.value}, 
    $pull:{pendingTransactions:t._id}})
db.accounts.update({name:t.destination, 
    pendingTransactions: t._id},
    {$inc:{balance: -t.value}, 
    $pull:{pendingTransactions:t._id}})
db.accounts.find()
```

find()操作返回acounts集合的内容，应该类似下面：

```
{ "_id" :ObjectId("4d7bc97fb8a04f5126961523"), "balance" :1000, 
    "name" :"A", "pendingTransactions" :[ ] }
{ "_id" :ObjectId("4d7bc984b8a04f5126961524"), "balance" :1000, 
    "name" :"B", "pendingTransactions" :[ ] }
```

#### 设置事务状态为canceled

最后，使用下面的update()状态将事务状态设置为canceled：

```
db.transactions.update({_id:t._id},{$set:{state:"canceled"}})
```

## 原理理解

这种通过代码模拟两阶段提交可以大概如下理解：

1. 首先给要修改的collections添加`pendingTransactions`字段，用来标记该条记录与哪个事务相关
2. 创建事务记录，初始状态为`initial`，将变更操作涉及到的属性保存在这条记录里
3. 然后把事务记录修改为`pending`状态
4. 然后修改目标的collection记录，且将经过修改的记录打上`pendingTransactions`标记（注意这里用了CAS的方法进行记录的更改）
5. 再将事务记录修改为`applied`状态
6. 再将目标collection记录中的`pendingTransactions`标记删除
7. 最后将事务记录修改为`done`状态

上述基本所有修改操作都是使用了CAS的方法进行记录的更改，这样保证只在前置条件满足的情况下才更新记录。

接下来考虑一下故障恢复：

1. 如果在上述第3步之后第5步之前出现故障了，服务进程重启后，只需要找到`pending`状态的事务记录（超过某个修改时间阀值），这时可以根据具体情况可以有两种方案继续进行：1）重新从第4步往下继续执行就可以了 2）根据事务里保存的变更相关属性，执行取消流程，目标记录进行进行反向补偿
2. 如果在第5步之后第7步之前出现故障了，服务进程重启后，只需要找到`applied`状态的事务记录（超过某个修改时间阀值），重新从第6步往下继续执行就可以了


## 一个更完整的例子

这里找到一个用[java语言写的较完整的例子](https://github.com/jeremyxu2010/mongodb-two-phase-commits)，并增加了一个较完整的测试用例方法：

```java
    @Test
    public void testNormalDemo() throws Exception {
        // insert test data
        accounts.insert(
                "[" +
                        "     { _id: \"A\", balance: 1000, pendingTransactions: [] },\n" +
                        "     { _id: \"B\", balance: 1000, pendingTransactions: [] }\n" +
                        "]"
        );

        String txId = ObjectId.get().toString();
        try {
            transactions.insert(
                    "{ _id:#, source: \"A\", destination: \"B\", value: 100, state: #, lastModified: #}", txId, TransactionState.INITIAL, System.currentTimeMillis()
            );
            Transaction transaction = transactions.findOne("{_id:#}", new Object[]{txId}).as(Transaction.class);

            transferService.transfer(transaction);

            Account accountA = accounts.findOne("{_id: \"A\"}").as(Account.class);
            assertThat(accountA.getBalance(), is(900));
            assertThat(accountA.getPendingTransactions(), is(emptyArray()));

            Account accountB = accounts.findOne("{_id: \"B\"}").as(Account.class);
            assertThat(accountB.getBalance(), is(1100));
            assertThat(accountB.getPendingTransactions(), is(emptyArray()));

            Transaction finalTransaction = transactions.findOne().as(Transaction.class);
            assertThat(finalTransaction.getState(), is(TransactionState.DONE));

        } catch (Exception e){
            Transaction transaction = transactions.findOne("{_id:#}", txId).as(Transaction.class);
            if (transaction == null) {
                System.err.printf("insert transaction failed, txId=%s\n", txId);
            }
            if (transaction.getState() == TransactionState.INITIAL){
                System.err.printf("execute transaction failed, txId=%s, current transaction state is: %s, try to recover the transaction\n", txId, TransactionState.INITIAL.toString());
                transferService.transfer(transaction);
            } if (transaction.getState() == TransactionState.PENDING) {
                // 这里可以选择是取消事务或者恢复事务
                System.err.printf("execute transaction failed, txId=%s, current transaction state is: %s, try to cancel the transaction\n", txId, TransactionState.PENDING.toString());
                transferService.cancelPending(transaction);
                // System.err.printf("execute transaction failed, txId=%s, current transaction state is: %s, try to recover the transaction\n", txId, TransactionState.PENDING.toString());
                // transferService.recoverPending(transaction);
            } else if (transaction.getState() == TransactionState.APPLIED){
                // 这里事务已经是APPLIED状态了，只差最后设置为DONE状态了，这里可以恢复事务
                System.err.printf("execute transaction failed, txId=%s, current transaction state is: %s, try to recover the transaction\n", txId, TransactionState.APPLIED.toString());
                transferService.recoverApplied(transaction);
            } else if (transaction.getState() == TransactionState.CANCELING){
                System.err.printf("execute transaction failed, txId=%s, current transaction state is: %s, try to cancel the transaction\n", txId, TransactionState.CANCELING.toString());
                transferService.cancelPending(transaction);
            }
            // 另外可以在后台运行一个定时任务，将超期的上述四种状态事务按上述逻辑处理
        }
    }
```

注释里对故障恢复说得比较清楚，就不赘述了。

这个例子里仅是一个简单转帐的示例，如果业务操作中还涉及插入新记录、删除记录、复杂的记录修改，则在事务记录中还需要将要操作的记录新旧状态都记录下来，便于出现故障时能提供足够的信息进行回滚，这样想一想，要构造一个通用的事务记录模式还是挺复杂的。

## 总结

实现mongodb的两阶段提交过程还是比较复杂的，上述的例子只是一个简单的转账，代码就已经很复杂了，因此在[mongodb4.0支持事务](https://www.mongodb.com/transactions)的情况下，还真不推荐搞mongodb的两阶段提交。

## 参考

1. https://acupple.github.io/2016/08/09/MongoDB%E4%B8%A4%E9%98%B6%E6%AE%B5%E6%8F%90%E4%BA%A4%E5%AE%9E%E7%8E%B0%E4%BA%8B%E5%8A%A1/
2. https://docs.mongodb.com/tutorials/perform-two-phase-commits
3. https://jackywu.github.io/articles/MongoDB%E7%9A%84%E4%BA%8B%E5%8A%A1/