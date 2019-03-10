---
title: Gearman使用范例
author: Jeremy Xu
tags:
  - java
  - gearman
  - 任务分派
categories:
  - java开发
date: 2017-09-06 03:14:00+08:00
---

# Gearman使用范例

Gearman是一个分发任务的程序框架，可以用在各种场合，与Hadoop相比，Gearman更偏向于任务分发功能。它的任务分布非常简单，简单得可以只需要用脚本即可完成。Gearman最初用于LiveJournal的图片resize功能，由于图片resize需要消耗大量计算资源，因此需要调度到后端多台服务器执行，完成任务之后返回前端再呈现到界面。

## 工程依赖配置

```xml
<dependencies>
  <dependency>
    <groupId>org.gearman.jgs</groupId>
    <artifactId>java-gearman-service</artifactId>
    <version>0.7.0-SNAPSHOT</version>
  </dependency>
  <dependency>
    <groupId>net.sf.json-lib</groupId>
    <artifactId>json-lib</artifactId>
    <version>2.4</version>
    <classifier>jdk15</classifier>
  </dependency>
</dependencies>
<repositories>
  <repository>
    <id>aliyun</id>
    <name>aliyun private nexus</name>
    <url>http://maven.aliyun.com/nexus/content/groups/public/</url>
    <releases>
      <enabled>true</enabled>
    </releases>
    <snapshots>
      <enabled>false</enabled>
    </snapshots>
  </repository>
  <repository>
    <id>jfrog</id>
    <name>jfrog private maven library</name>
    <url>https://oss.jfrog.org/libs-snapshot/</url>
    <releases>
      <enabled>false</enabled>
    </releases>
    <snapshots>
      <enabled>true</enabled>
    </snapshots>
  </repository>
</repositories>
```

## Gearman服务端

```java
        /*
         * Create a Gearman instance
         */
        Gearman gearman = Gearman.createGearman();
        try {
            /*
             * Start a new job server. The resulting server will be running in
             * the local address space.
             *
             * Parameter 1: The port number to listen on
             *
             * throws IOException
             */
            GearmanServer server = gearman
                    .startGearmanServer(EchoWorker.ECHO_PORT);

            /*
             * Create a gearman worker. The worker poll jobs from the server and
             * executes the corresponding GearmanFunction
             */
        } catch (IOException ioe) {
            /*
             * If an exception occurs, make sure the gearman service is shutdown
             */
            gearman.shutdown();
            // forward exception
            throw ioe;
        }
```

这里注意有一个重载的`public GearmanServer startGearmanServer(int port, GearmanPersistence persistence)`，通过它可以将提交的任务持久化，即使Gearman服务端重启，提交的任务还是可以还原的



## Gearman客户端与Worker端

Gearman里提交任务有两种方式：非backgroud提交方式、background提交方式。简单来说`非backgroud提交方式`是一种同步提交方式，客户端提交任务后保持一个长连接，通过这个长连接可以从执行的Function中获得中间任务数据；而`background提交方式`是一种异步提交方式，客户端提交任务后获得一个`jobHandle`, 后面都通过`jobHandle`获取执行Function的任务状态。

### 非backgroud提交方式

```java
        System.out.println(EchoWorker.ECHO_FUNCTION_NAME);
        /*
         * Create a Gearman instance
         */
        Gearman gearman = Gearman.createGearman();
        /*
         * Create a new gearman client.
         *
         * The client is used to submit requests the job server.
         */
        GearmanClient client = gearman.createGearmanClient();
        /*
         * Create the job server object. This call creates an object represents
         * a remote job server.
         *
         * Parameter 1: the host address of the job server.
         * Parameter 2: the port number the job server is listening on.
         *
         * A job server receives jobs from clients and distributes them to
         * registered workers.
         */
        GearmanServer server = gearman.createGearmanServer(
                EchoWorker.ECHO_HOST, EchoWorker.ECHO_PORT);
        /*
         * Tell the client that it may connect to this server when submitting
         * jobs.
         */
        client.addServer(server);
        /*
         * Submit a job to a job server.
         *
         * Parameter 1: the gearman function name
         * Parameter 2: the data passed to the server and worker
         *
         * The GearmanJobReturn is used to poll the job's result
         */
        JSONObject json = new JSONObject();
        json.put("name", "admin");
        GearmanJobReturn jobReturn = client.submitJob(
                EchoWorker.ECHO_FUNCTION_NAME,json.toString().getBytes());
        /*
         * Iterate through the job events until we hit the end-of-file
         */
        byte[] jobHandle = null;
        while (!jobReturn.isEOF()) {

            // Poll the next job event (blocking operation)
            GearmanJobEvent event = jobReturn.poll();

            switch (event.getEventType()) {
                // success
                case GEARMAN_JOB_SUCCESS: // Job completed successfully
                    // print the result
                    System.out.println(new String(event.getData()));
                    break;
                case GEARMAN_SUBMIT_SUCCESS:
                    // get job handle
                    jobHandle = event.getData();
                    break;
                case GEARMAN_JOB_DATA:
                    // print job data
                    System.out.println(new String(event.getData()));
                    break;
                // failure
                case GEARMAN_SUBMIT_FAIL: // The job submit operation failed
                case GEARMAN_JOB_FAIL: // The job's execution failed
                    System.err.println(event.getEventType() + ": "
                            + new String(event.getData()));
            }

        }
        /*
         * Close the gearman service after it's no longer needed. (closes all
         * sub-services, such as the client)
         *
         * It's suggested that you reuse Gearman and GearmanClient instances
         * rather recreating and closing new ones between submissions
         */
        gearman.shutdown();
```

```java
    public static void main(String... args) {

        System.out.println(EchoWorker.ECHO_FUNCTION_NAME);
        registWorker();


    }

    public static void registWorker(){
        /*
         * Create a Gearman instance
         */
        Gearman gearman = Gearman.createGearman();

        /*
         * Create the job server object. This call creates an object represents
         * a remote job server.
         *
         * Parameter 1: the host address of the job server.
         * Parameter 2: the port number the job server is listening on.
         *
         * A job server receives jobs from clients and distributes them to
         * registered workers.
         */
        GearmanServer server = gearman.createGearmanServer(
                EchoWorker.ECHO_HOST, EchoWorker.ECHO_PORT);

        /*
         * Create a gearman worker. The worker poll jobs from the server and
         * executes the corresponding GearmanFunction
         */
        System.out.println(server.toString());
        GearmanWorker worker = gearman.createGearmanWorker();
        /*
         *  Tell the worker how to perform the echo function
         */
        worker.addFunction(EchoWorker.ECHO_FUNCTION_NAME, new EchoWorker());
        /*
         *  Tell the worker that it may communicate with the this job server
         */
        boolean success = worker.addServer(server);
        System.out.println(success);
    }


    public byte[] work(String function, byte[] data,
                       GearmanFunctionCallback callback) throws Exception {

        /*
         * The work method performs the gearman function. In this case, the echo
         * function simply returns the data it received
         */

        System.out.println(new String(data));

        System.out.println("begin work");

        callback.sendData("some data".getBytes());

        System.out.println("end work");

        return "job result".getBytes();
    }
```

### backgroud提交方式

```java
        System.out.println(EchoWorker.ECHO_FUNCTION_NAME);
        /*
         * Create a Gearman instance
         */
        Gearman gearman = Gearman.createGearman();
        /*
         * Create a new gearman client.
         *
         * The client is used to submit requests the job server.
         */
        GearmanClient client = gearman.createGearmanClient();
        /*
         * Create the job server object. This call creates an object represents
         * a remote job server.
         *
         * Parameter 1: the host address of the job server.
         * Parameter 2: the port number the job server is listening on.
         *
         * A job server receives jobs from clients and distributes them to
         * registered workers.
         */
        GearmanServer server = gearman.createGearmanServer(
                EchoWorker.ECHO_HOST, EchoWorker.ECHO_PORT);
        /*
         * Tell the client that it may connect to this server when submitting
         * jobs.
         */
        client.addServer(server);
        /*
         * Submit a job to a job server.
         *
         * Parameter 1: the gearman function name
         * Parameter 2: the data passed to the server and worker
         *
         * The GearmanJobReturn is used to poll the job's result
         */
        JSONObject json = new JSONObject();
        json.put("name", "admin");
        GearmanJobReturn jobReturn = client.submitBackgroundJob(
                EchoWorker.ECHO_FUNCTION_NAME,json.toString().getBytes());
        /*
         * Iterate through the job events until we hit the end-of-file
         */
        byte[] jobHandle = null;
        while (!jobReturn.isEOF()) {
            // Poll the next job event (blocking operation)
            GearmanJobEvent event = jobReturn.poll();
            switch (event.getEventType()) {
                case GEARMAN_SUBMIT_SUCCESS:
                    jobHandle = event.getData();
                    break;
                // failure
                case GEARMAN_SUBMIT_FAIL: // The job submit operation failed
                case GEARMAN_JOB_FAIL: // The job's execution failed
                    System.err.println(event.getEventType() + ": "
                            + new String(event.getData()));
            }
        }
        for (int i = 0; i < 10; i++) {
            GearmanJobStatus status = client.getStatus(jobHandle);
            System.out.println(String.format("known: %b, running: %b, denominator: %d, numerator: %d", status.isKnown(), status.isRunning(), status.getDenominator(), status.getNumerator()));
            Thread.sleep(2000L);
        }
        /*
         * Close the gearman service after it's no longer needed. (closes all
         * sub-services, such as the client)
         *
         * It's suggested that you reuse Gearman and GearmanClient instances
         * rather recreating and closing new ones between submissions
         */
        gearman.shutdown();
```

```java
    public static void main(String... args) {
        System.out.println(EchoWorker.ECHO_FUNCTION_NAME);
        registWorker();
    }
    public static void registWorker(){
        /*
         * Create a Gearman instance
         */
        Gearman gearman = Gearman.createGearman();

        /*
         * Create the job server object. This call creates an object represents
         * a remote job server.
         *
         * Parameter 1: the host address of the job server.
         * Parameter 2: the port number the job server is listening on.
         *
         * A job server receives jobs from clients and distributes them to
         * registered workers.
         */
        GearmanServer server = gearman.createGearmanServer(
                EchoWorker.ECHO_HOST, EchoWorker.ECHO_PORT);
        /*
         * Create a gearman worker. The worker poll jobs from the server and
         * executes the corresponding GearmanFunction
         */
        System.out.println(server.toString());
        GearmanWorker worker = gearman.createGearmanWorker();
        /*
         *  Tell the worker how to perform the echo function
         */
        worker.addFunction(EchoWorker.ECHO_FUNCTION_NAME, new EchoWorker());
        /*
         *  Tell the worker that it may communicate with the this job server
         */
        boolean success = worker.addServer(server);
        System.out.println(success);
    }
    public byte[] work(String function, byte[] data,
                       GearmanFunctionCallback callback) throws Exception {

        /*
         * The work method performs the gearman function. In this case, the echo
         * function simply returns the data it received
         */
        System.out.println(new String(data));
        System.out.println("begin work");
        for (int i = 0; i < 10; i++) {
            callback.sendStatus(i, i);
            Thread.sleep(2000L);
        }
        System.out.println("end work");
        return null;
    }
```

## 参考

`http://www.blogdaren.com/m/?post=1497`

