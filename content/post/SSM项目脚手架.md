---
title: SSM项目脚手架
author: Jeremy Xu
tags:
  - java
  - spring
  - springmvc
  - mybatis
categories:
  - java开发
date: 2016-11-06 00:09:00+08:00
---
使用SSM做了好几个项目，今天突然想起来还是建一个脚手架工程，地址在[这里](https://git.oschina.net/jeremy-xu/ssm-scaffold)，便于以后快速创建这类项目。

## SSM项目脚手架项目

在网上找到一个[ssm项目的脚手架工程](https://github.com/1994/ssm-scaffold)，我把它clone下来，做了少量修改，做出的修改如下：

* java包都改成personal.jeremyxu包下，也相应地修改了配置文件
* springmvc的url-pattern修改为/api/*
* 拆分了spring配置文件，spring配置文件放置于resources/spring目录下
* 修改了db.xml里的property-placeholder定义，以允许外部覆盖配置文件
```xml
    <context:property-placeholder location="classpath:jdbc.properties,file:///external/jdbc_overwrite.properties" ignore-resource-not-found="true"/>
```
* 修改README.md文件，说明如何覆盖默认的log4j.properties配置文件
* 修改jdbc.properties文件的注释，说明如何配置读写分离。至于mysql主从复制配置文件可参考[这里](http://369369.blog.51cto.com/319630/790921)

## MySQL主从读写分离源码实现

上一节基本是拿别人已经搭好的ssm脚手架工程简单改了一下。不过在改动过程中还是加入了自己的一些想法，其中最重要的就是配置MySQL主从读写分离。这一小节简单分析一下这个功能源码层面是如何实现的。

### 配置具体步骤

要实现MySQL主从读写分离，首先是配置MySQL服务主从复制，这个比较简单，不再赘述，可参考[这里](http://369369.blog.51cto.com/319630/790921)。

然后再配置jdbc.properties文件。

```
# 普通模式 jdbc_driverClass=com.mysql.jdbc.Driver
jdbc_driverClass=com.mysql.jdbc.ReplicationDriver
# 普通模式 jdbc:mysql://127.0.0.1:3306/test?useUnicode=true
jdbc_url=jdbc:mysql:replication://master:3306,slave1:3306,slave2:3306/test?useUnicode=true
jdbc_user=accessop
jdbc_password=123456
```

最后在数据库事务管理定义处添加一些AOP advice，当遇到某些只读查询时，设置readonly。

```xml
  <!--事务管理-->
  <tx:advice id="txAdvice" transaction-manager="transactionManager">
      <tx:attributes>
          <tx:method name="select*" read-only="true" />
          <tx:method name="find*" read-only="true" />
          <tx:method name="get*" read-only="true" />
          <tx:method name="*" />
      </tx:attributes>
  </tx:advice>
  <bean id="transactionManager" class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
      <property name="dataSource" ref="dataSource" />
  </bean>
```

### 源码实现分析

可以看到与普通模式最大的不同在于`jdbc_driverClass`，`jdbc_url`发生变化了。我从`com.mysql.jdbc.ReplicationDriver`分析起。

`ReplicationDriver.java`

```java
public class ReplicationDriver extends NonRegisteringReplicationDriver
		implements java.sql.Driver {
	static {
		try {
			java.sql.DriverManager
					.registerDriver(new NonRegisteringReplicationDriver());
		} catch (SQLException E) {
			throw new RuntimeException("Can't register driver!");
		}
	}

	public ReplicationDriver() throws SQLException {
		// Required for Class.forName().newInstance()
	}
}
```

这个代码比较简单，其中最重要的部分是在static代码块里注册驱动`NonRegisteringReplicationDriver`，这个也是一般jdbc驱动的写法。

`NonRegisteringReplicationDriver.java`

```java
public class NonRegisteringReplicationDriver extends NonRegisteringDriver {
	public NonRegisteringReplicationDriver() throws SQLException {
		super();
	}

	public Connection connect(String url, Properties info) throws SQLException {
		Properties parsedProps = parseURL(url, info);

		if (parsedProps == null) {
			return null;
		}

		Properties masterProps = (Properties)parsedProps.clone();
		Properties slavesProps = (Properties)parsedProps.clone();

		// Marker used for further testing later on, also when
		// debugging
		slavesProps.setProperty("com.mysql.jdbc.ReplicationConnection.isSlave", "true");

		String hostValues = parsedProps.getProperty(HOST_PROPERTY_KEY);

		if (hostValues != null) {
			StringTokenizer st = new StringTokenizer(hostValues, ",");

			StringBuffer masterHost = new StringBuffer();
			StringBuffer slaveHosts = new StringBuffer();

			if (st.hasMoreTokens()) {
				String[] hostPortPair = parseHostPortPair(st.nextToken());

				if (hostPortPair[HOST_NAME_INDEX] != null) {
					masterHost.append(hostPortPair[HOST_NAME_INDEX]);
				}

				if (hostPortPair[PORT_NUMBER_INDEX] != null) {
					masterHost.append(":");
					masterHost.append(hostPortPair[PORT_NUMBER_INDEX]);
				}
			}

			boolean firstSlaveHost = true;

			while (st.hasMoreTokens()) {
				String[] hostPortPair = parseHostPortPair(st.nextToken());

				if (!firstSlaveHost) {
					slaveHosts.append(",");
				} else {
					firstSlaveHost = false;
				}

				if (hostPortPair[HOST_NAME_INDEX] != null) {
					slaveHosts.append(hostPortPair[HOST_NAME_INDEX]);
				}

				if (hostPortPair[PORT_NUMBER_INDEX] != null) {
					slaveHosts.append(":");
					slaveHosts.append(hostPortPair[PORT_NUMBER_INDEX]);
				}
			}

			if (slaveHosts.length() == 0) {
				throw SQLError.createSQLException(
						"Must specify at least one slave host to connect to for master/slave replication load-balancing functionality",
						SQLError.SQL_STATE_INVALID_CONNECTION_ATTRIBUTE);
			}

			masterProps.setProperty(HOST_PROPERTY_KEY, masterHost.toString());
			slavesProps.setProperty(HOST_PROPERTY_KEY, slaveHosts.toString());
		}

		return new ReplicationConnection(masterProps, slavesProps);
	}
}
```

`NonRegisteringReplicationDriver`继承自普通模式驱动`NonRegisteringDriver`，覆盖了其`public Connection connect(String url, Properties info) throws SQLException`方法，解析jdbc_url，将其中第一个主机端口组与后面其它主机端口组解析出来，分别拼接为`masterHost`、`slaveHosts`。最后以构建好的`masterProps`、`slavesProps`构造`ReplicationConnection`，即一个包含主从连接的抽象概念连接。

`ReplicationConnection.java`

```java
public ReplicationConnection(Properties masterProperties,
		Properties slaveProperties) throws SQLException {
	Driver driver = new Driver();

	StringBuffer masterUrl = new StringBuffer("jdbc:mysql://");
      StringBuffer slaveUrl = new StringBuffer("jdbc:mysql://");

      String masterHost = masterProperties
      	.getProperty(NonRegisteringDriver.HOST_PROPERTY_KEY);

      if (masterHost != null) {
      	masterUrl.append(masterHost);
      }

      String slaveHost = slaveProperties
      	.getProperty(NonRegisteringDriver.HOST_PROPERTY_KEY);

      if (slaveHost != null) {
      	slaveUrl.append(slaveHost);
      }

      String masterDb = masterProperties
      	.getProperty(NonRegisteringDriver.DBNAME_PROPERTY_KEY);

      masterUrl.append("/");

      if (masterDb != null) {
      	masterUrl.append(masterDb);
      }

      String slaveDb = slaveProperties
      	.getProperty(NonRegisteringDriver.DBNAME_PROPERTY_KEY);

      slaveUrl.append("/");

      if (slaveDb != null) {
      	slaveUrl.append(slaveDb);
      }

      this.masterConnection = (com.mysql.jdbc.Connection) driver.connect(
              masterUrl.toString(), masterProperties);
      this.slavesConnection = (com.mysql.jdbc.Connection) driver.connect(
              slaveUrl.toString(), slaveProperties);

	this.currentConnection = this.masterConnection;
}
```

上面的代码比较清楚了，就是以正常的连接模式使用`masterProperties`、`slaveProperties`构造两个普通的JDBC连接，并且设置当前连接`currentConnection`为`masterConnection`。

如上所述，当数据库事务管理配置的的AOP advice执行时，会调用`Connection`的`setReadOnly`方法。我们看一下`ReplicationConnection`的`setReadOnly`方法。

```java
public synchronized void setReadOnly(boolean readOnly) throws SQLException {
	if (readOnly) {
		if (currentConnection != slavesConnection) {
			switchToSlavesConnection();
		}
	} else {
		if (currentConnection != masterConnection) {
			switchToMasterConnection();
		}
	}
}
private synchronized void switchToMasterConnection() throws SQLException {
	swapConnections(this.masterConnection, this.slavesConnection);
}

private synchronized void switchToSlavesConnection() throws SQLException {
	swapConnections(this.slavesConnection, this.masterConnection);
}
private synchronized void swapConnections(Connection switchToConnection,
		Connection switchFromConnection) throws SQLException {
	String switchFromCatalog = switchFromConnection.getCatalog();
	String switchToCatalog = switchToConnection.getCatalog();

	if (switchToCatalog != null && !switchToCatalog.equals(switchFromCatalog)) {
		switchToConnection.setCatalog(switchFromCatalog);
	} else if (switchFromCatalog != null) {
		switchToConnection.setCatalog(switchFromCatalog);
	}

	boolean switchToAutoCommit = switchToConnection.getAutoCommit();
	boolean switchFromConnectionAutoCommit = switchFromConnection.getAutoCommit();

	if (switchFromConnectionAutoCommit != switchToAutoCommit) {
		switchToConnection.setAutoCommit(switchFromConnectionAutoCommit);
	}

	int switchToIsolation = switchToConnection
			.getTransactionIsolation();

	int switchFromIsolation = switchFromConnection.getTransactionIsolation();

	if (switchFromIsolation != switchToIsolation) {
		switchToConnection
				.setTransactionIsolation(switchFromIsolation);
	}

	this.currentConnection = switchToConnection;
}
```

当`currentConnection`与根据`readOnly`应该使用的`Connection`不是同一个时，就会发生`currentConnection`连接的切换，切换的过程还需要保证`Catalog`、`AutoCommit`、`TransactionIsolation`与切换前一致。至此MySQL的主从读写分离就完成了。


## MySQL的jdbc连接url连接多个MySQL服务分析

从上面的代码来看，当存在多个MySQL slave服务时，这些是由普通连接驱动`NonRegisteringDriver`完成的。也就是说普通的jdbc_url中主机端口组处也是可以设置多个主机服务的。这个功能以前倒是没用过。这里分析一下它的代码。

先看看`NonRegisteringDriver`的`connect`方法。

```java
public java.sql.Connection connect(String url, Properties info)
		throws SQLException {
	if (url != null) {
		if (StringUtils.startsWithIgnoreCase(url, LOADBALANCE_URL_PREFIX)) {
			return connectLoadBalanced(url, info);
		} else if (StringUtils.startsWithIgnoreCase(url,
				REPLICATION_URL_PREFIX)) {
			return connectReplicationConnection(url, info);
		}
	}

	Properties props = null;

	if ((props = parseURL(url, info)) == null) {
		return null;
	}

	try {
		Connection newConn = new com.mysql.jdbc.Connection(host(props),
				port(props), props, database(props), url);

		return newConn;
	} catch (SQLException sqlEx) {
		// Don't wrap SQLExceptions, throw
		// them un-changed.
		throw sqlEx;
	} catch (Exception ex) {
		throw SQLError.createSQLException(Messages
				.getString("NonRegisteringDriver.17") //$NON-NLS-1$
				+ ex.toString()
				+ Messages.getString("NonRegisteringDriver.18"), //$NON-NLS-1$
				SQLError.SQL_STATE_UNABLE_TO_CONNECT_TO_DATASOURCE);
	}
}
```

这里可以看到实际上MySQL的jdbc_url支持三种URL_PREFIX，实现是四种。

```java
private static final String REPLICATION_URL_PREFIX = "jdbc:mysql:replication://";

private static final String URL_PREFIX = "jdbc:mysql://";

private static final String MXJ_URL_PREFIX = "jdbc:mysql:mxj://";

private static final String LOADBALANCE_URL_PREFIX = "jdbc:mysql:loadbalance://";
```

我们最常用的是`jdbc:mysql://`，前面一节我也用到了`jdbc:mysql:replication://`，`jdbc:mysql:loadbalance://`可以针对多个MySQL服务采取不同的负载策略，平时也是用得着的。`jdbc:mysql:mxj://`与`jdbc:mysql://`很类似，只不过它会使用自定义的SocketFactory `com.mysql.management.driverlaunched.ServerLauncherSocketFactory`，我没有去阅读它的源码，不过从名称猜测如果使用这个，可以通过JMX管理MySQL连接。

如果是普通的`jdbc:mysql://`，则会直接创建`Connection`。

`com.mysql.jdbc.Connection#Connection`方法。

```java
Connection(String hostToConnectTo, int portToConnectTo, Properties info,
			String databaseToConnectTo, String url)
			throws SQLException {
	this.charsetToNumBytesMap = new HashMap();

	this.connectionCreationTimeMillis = System.currentTimeMillis();
	this.pointOfOrigin = new Throwable();

	// Stash away for later, used to clone this connection for Statement.cancel
	// and Statement.setQueryTimeout().
	//

	this.origHostToConnectTo = hostToConnectTo;
	this.origPortToConnectTo = portToConnectTo;
	this.origDatabaseToConnectTo = databaseToConnectTo;

	try {
		Blob.class.getMethod("truncate", new Class[] {Long.TYPE});

		this.isRunningOnJDK13 = false;
	} catch (NoSuchMethodException nsme) {
		this.isRunningOnJDK13 = true;
	}

	this.sessionCalendar = new GregorianCalendar();
	this.utcCalendar = new GregorianCalendar();
	this.utcCalendar.setTimeZone(TimeZone.getTimeZone("GMT"));

	//
	// Normally, this code would be in initializeDriverProperties,
	// but we need to do this as early as possible, so we can start
	// logging to the 'correct' place as early as possible...this.log
	// points to 'NullLogger' for every connection at startup to avoid
	// NPEs and the overhead of checking for NULL at every logging call.
	//
	// We will reset this to the configured logger during properties
	// initialization.
	//
	this.log = LogFactory.getLogger(getLogger(), LOGGER_INSTANCE_NAME);

	// We store this per-connection, due to static synchronization
	// issues in Java's built-in TimeZone class...
	this.defaultTimeZone = Util.getDefaultTimeZone();

	if ("GMT".equalsIgnoreCase(this.defaultTimeZone.getID())) {
		this.isClientTzUTC = true;
	} else {
		this.isClientTzUTC = false;
	}

	this.openStatements = new HashMap();
	this.serverVariables = new HashMap();
	this.hostList = new ArrayList();

	if (hostToConnectTo == null) {
		this.host = "localhost";
		this.hostList.add(this.host);
	} else if (hostToConnectTo.indexOf(",") != -1) {
		// multiple hosts separated by commas (failover)
		StringTokenizer hostTokenizer = new StringTokenizer(
				hostToConnectTo, ",", false);

		while (hostTokenizer.hasMoreTokens()) {
			this.hostList.add(hostTokenizer.nextToken().trim());
		}
	} else {
		this.host = hostToConnectTo;
		this.hostList.add(this.host);
	}

	this.hostListSize = this.hostList.size();
	this.port = portToConnectTo;

	if (databaseToConnectTo == null) {
		databaseToConnectTo = "";
	}

	this.database = databaseToConnectTo;
	this.myURL = url;
	this.user = info.getProperty(NonRegisteringDriver.USER_PROPERTY_KEY);
	this.password = info
			.getProperty(NonRegisteringDriver.PASSWORD_PROPERTY_KEY);

	if ((this.user == null) || this.user.equals("")) {
		this.user = "";
	}

	if (this.password == null) {
		this.password = "";
	}

	this.props = info;
	initializeDriverProperties(info);

	try {
		createNewIO(false);
		this.dbmd = new DatabaseMetaData(this, this.database);
	} catch (SQLException ex) {
		cleanup(ex);

		// don't clobber SQL exceptions
		throw ex;
	} catch (Exception ex) {
		cleanup(ex);

		StringBuffer mesg = new StringBuffer();

		if (getParanoid()) {
			mesg.append("Cannot connect to MySQL server on ");
			mesg.append(this.host);
			mesg.append(":");
			mesg.append(this.port);
			mesg.append(".\n\n");
			mesg.append("Make sure that there is a MySQL server ");
			mesg.append("running on the machine/port you are trying ");
			mesg
					.append("to connect to and that the machine this software is "
							+ "running on ");
			mesg.append("is able to connect to this host/port "
					+ "(i.e. not firewalled). ");
			mesg
					.append("Also make sure that the server has not been started "
							+ "with the --skip-networking ");
			mesg.append("flag.\n\n");
		} else {
			mesg.append("Unable to connect to database.");
		}

		mesg.append("Underlying exception: \n\n");
		mesg.append(ex.getClass().getName());

		if (!getParanoid()) {
			mesg.append(Util.stackTraceToString(ex));
		}

		throw SQLError.createSQLException(mesg.toString(),
				SQLError.SQL_STATE_COMMUNICATION_LINK_FAILURE);
	}
}
```

这里代码比较多，但整个逻辑是根据参数，构造好`hostList`、`port`、`database`、`user`、`password`、`props`内部变量，最后调用`createNewIO(false);`建立数据库连接。

`com.mysql.jdbc.Connection#createNewIO`方法最后会根据上述内部变量建立数据库连接。

```java
if (getRoundRobinLoadBalance()) {
	hostIndex = getNextRoundRobinHostIndex(getURL(),
			this.hostList);
}

for (; hostIndex < this.hostListSize; hostIndex++) {

	if (hostIndex == 0) {
		this.hasTriedMasterFlag = true;
	}

	try {
		String newHostPortPair = (String) this.hostList
				.get(hostIndex);

		int newPort = 3306;

		String[] hostPortPair = NonRegisteringDriver
				.parseHostPortPair(newHostPortPair);
		String newHost = hostPortPair[NonRegisteringDriver.HOST_NAME_INDEX];

		if (newHost == null || newHost.trim().length() == 0) {
			newHost = "localhost";
		}

		if (hostPortPair[NonRegisteringDriver.PORT_NUMBER_INDEX] != null) {
			try {
				newPort = Integer
						.parseInt(hostPortPair[NonRegisteringDriver.PORT_NUMBER_INDEX]);
			} catch (NumberFormatException nfe) {
				throw SQLError.createSQLException(
						"Illegal connection port value '"
								+ hostPortPair[NonRegisteringDriver.PORT_NUMBER_INDEX]
								+ "'",
						SQLError.SQL_STATE_INVALID_CONNECTION_ATTRIBUTE);
			}
		}

		this.io = new MysqlIO(newHost, newPort, mergedProps,
				getSocketFactoryClassName(), this,
				getSocketTimeout());

		this.io.doHandshake(this.user, this.password,
				this.database);
		this.connectionId = this.io.getThreadId();
		this.isClosed = false;

		// save state from old connection
		boolean oldAutoCommit = getAutoCommit();
		int oldIsolationLevel = this.isolationLevel;
		boolean oldReadOnly = isReadOnly();
		String oldCatalog = getCatalog();

		// Server properties might be different
		// from previous connection, so initialize
		// again...
		initializePropsFromServer();

		if (isForReconnect) {
			// Restore state from old connection
			setAutoCommit(oldAutoCommit);

			if (this.hasIsolationLevels) {
				setTransactionIsolation(oldIsolationLevel);
			}

			setCatalog(oldCatalog);
		}

		if (hostIndex != 0) {
			setFailedOverState();
			queriesIssuedFailedOverCopy = 0;
		} else {
			this.failedOver = false;
			queriesIssuedFailedOverCopy = 0;

			if (this.hostListSize > 1) {
				setReadOnlyInternal(false);
			} else {
				setReadOnlyInternal(oldReadOnly);
			}
		}

		connectionGood = true;

		break; // low-level connection succeeded
	} catch (Exception EEE) {
		if (this.io != null) {
			this.io.forceClose();
		}

		connectionNotEstablishedBecause = EEE;

		connectionGood = false;

		if (EEE instanceof SQLException) {
			SQLException sqlEx = (SQLException)EEE;

			String sqlState = sqlEx.getSQLState();

			// If this isn't a communications failure, it will probably never succeed, so
			// give up right here and now ....
			if ((sqlState == null)
					|| !sqlState
							.equals(SQLError.SQL_STATE_COMMUNICATION_LINK_FAILURE)) {
				throw sqlEx;
			}
		}

		// Check next host, it might be up...
		if (getRoundRobinLoadBalance()) {
			hostIndex = getNextRoundRobinHostIndex(getURL(),
					this.hostList) - 1 /* incremented by for loop next time around */;
		} else if ((this.hostListSize - 1) == hostIndex) {
			throw new CommunicationsException(this,
					(this.io != null) ? this.io
							.getLastPacketSentTimeMs() : 0,
							EEE);
		}
	}
}
```

这样可以看到， 如果设置了`RoundRobinLoadBalance`，则会根据`RoundRobin`规则，在多个MySQL服务里选择一个建立连接，否则仅按顺序逐个尝试建立MySQL连接，如果前面一个建立成功，则后面的不再再继续尝试。

所以这里得到一个经验，如果设置了多个MySQL slave，为了多个slave服务的负载比较均衡，还是应该设置`roundRobinLoadBalance`参数，因此比较安全且合适的读写分离jdbc_url可能是下面这样的。

```
jdbc_url=jdbc:mysql:replication://master:3306,slave1:3306,slave2:3306/test?roundRobinLoadBalance=true&allowMasterDownConnections=true&allowSlavesDownConnections=true&readFromMasterNoSlaves=true&useUnicode=true
```

## 总结

MySQL的JDBC驱动功能还是挺丰富的，原来没有阅读代码，有很多功能其实并不清楚，这次认真阅读代码，对JDBC的使用有更深刻的认识了。
