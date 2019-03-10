---
title: 通过WebSocket传输文件
tags:
  - java
  - nio
  - websocket
categories:
  - java开发
date: 2016-06-11 19:41:00+08:00
---
工作中需要将大量文件从一台服务器传输至另一台服务器，最开始是直接使用基础的TCP编程搞定的。但后来业务上要求两台服务器间只能走HTTP协议，而且还要保证传输过去的文件的完整性。想了下，最后基于WebSocket协议完成了该功能。

## 思路

1. 服务器端侦听某端口，接受WebSocket请求，后面可用nginx作反向代理，外部看到的将是80端口
2. 客户端连接服务器的WebSocket地址，连接成功后，首先传送一个NEW_FILE的数据包，里面带上要传输的文件名
3. 服务器端收到NEW_FILE包后，解析出文件名，并创建目标文件，再回复ACK_NEW_FILE的数据包
4. 客户端收到ACK_NEW_FILE的数据包后，检查回应的code，如是成功码，则启动一个线程，该线程负责将源文件的数据封装成多个FILE_DATA数据包，传送这些FILE_DATA数据至服务器端
5. 服务器端接收FILE_DATA数据包，解析出里面的文件数据，将文件数据写入文件
6. 客户端发送完源文件数据后，再传送一个FILE_END数据包，该文件包中带上源文件的MD5值
7. 服务器端收到FILE_END数据包后，比对源文件的MD5值与目标文件的MD5值，如相同，则认为传输成功，并返回ACK_FILE_END数据包，里面带上成功码
8. 客户端收到ACK_FILE_END数据包，检查回应的code，如是成功码，则认为传输成功，否则认为传输失败。

## 具体实现

以下为示例的简易代码，项目中的代码比这组织得更完善一些。该实现使用了WebSocket的Java实现`Java-WebSocket`与Java NIO。

`FilePacket.java`

```java
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;

/**
 * Created by jeremy on 16/6/11.
 */
public class FilePacket {
    public static final int P_NEW_FILE = 0x01;
    public static final int P_ACK_NEW_FILE = 0x02;
    public static final int P_FILE_DATA = 0x03;
    public static final int P_FILE_END = 0x04;
    public static final int P_ACK_FILE_END = 0x05;

    public static final int SUCCESS_CODE = 0;
    public static final int ERROR_CODE = -1;

    private static final int TYPE_LEN = 1;

    private int type;

    private final ByteBuffer buffer;

    public FilePacket(ByteBuffer buffer) {
        this.buffer = buffer;
    }

    public static FilePacket constructNewFilePacket(String fileName) {
        byte[] bytes = fileName.getBytes(StandardCharsets.UTF_8);
        ByteBuffer buffer = ByteBuffer.allocate(TYPE_LEN + 4 + bytes.length);
        buffer.order(ByteOrder.BIG_ENDIAN);
        buffer.put((byte)P_NEW_FILE);
        buffer.putInt(bytes.length);
        buffer.put(bytes);
        buffer.flip();
        return new FilePacket(buffer);
    }

    public static FilePacket constructAckNewFilePacket(int code) {
        ByteBuffer buffer = ByteBuffer.allocate(TYPE_LEN + 1);
        buffer.order(ByteOrder.BIG_ENDIAN);
        buffer.put((byte)P_ACK_NEW_FILE);
        buffer.put((byte)code);
        buffer.flip();
        return new FilePacket(buffer);
    }

    public static FilePacket constructFileEndPacket(String digest) {
        byte[] bytes = digest.getBytes(StandardCharsets.UTF_8);
        ByteBuffer buffer = ByteBuffer.allocate(TYPE_LEN + 4 + bytes.length);
        buffer.order(ByteOrder.BIG_ENDIAN);
        buffer.put((byte)P_FILE_END);
        buffer.putInt(bytes.length);
        buffer.put(bytes);
        buffer.flip();
        return new FilePacket(buffer);
    }

    public static FilePacket constructAckFileEndPacket(int code) {
        ByteBuffer buffer = ByteBuffer.allocate(TYPE_LEN + 1);
        buffer.order(ByteOrder.BIG_ENDIAN);
        buffer.put((byte)P_ACK_FILE_END);
        buffer.put((byte)code);
        buffer.flip();
        return new FilePacket(buffer);
    }

    public static FilePacket parseByteBuffer(ByteBuffer buffer){
        FilePacket p = new FilePacket(buffer);
        p.parseType();
        return p;
    }

    private void parseType() {
        this.type = (int)this.buffer.get();
    }

    public ByteBuffer getBuffer() {
        return buffer;
    }

    public int getType() {
        return type;
    }


}
```

`FileServer.java`

```java
import org.java_websocket.WebSocket;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;

import javax.xml.bind.DatatypeConverter;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.nio.ByteBuffer;
import java.nio.channels.ByteChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * Created by jeremy on 16/6/11.
 */
public class FileServer extends WebSocketServer {

    private ConcurrentMap<WebSocket, Map<String, Object>> clients = new ConcurrentHashMap<WebSocket, Map<String, Object>>();

    public FileServer(int port) throws UnknownHostException {
        super(new InetSocketAddress( port ));
    }

    @Override
    public void onOpen(WebSocket webSocket, ClientHandshake clientHandshake) {
        clients.put(webSocket, new HashMap<String, Object>());
    }

    @Override
    public void onClose(WebSocket webSocket, int i, String s, boolean b) {
        clients.remove(webSocket);
    }

    @Override
    public void onMessage(WebSocket webSocket, String s) {
        // do nothing
    }

    @Override
    public void onMessage(WebSocket conn, ByteBuffer message) {
        FilePacket p = FilePacket.parseByteBuffer(message);
        Map<String, Object> params;
        ByteChannel fileChannel;
        MessageDigest md;
        switch (p.getType()) {
            case FilePacket.P_NEW_FILE:
                try{
                    int fileNameLen = p.getBuffer().getInt();
                    byte[] fileNameBytes = new byte[fileNameLen];
                    p.getBuffer().get(fileNameBytes);
                    String fileName = new String(fileNameBytes, StandardCharsets.UTF_8);
                    System.out.println("receive file request : " + fileName);
                    Path filePath = Paths.get("/tmp/otherdir", fileName);
                    fileChannel = Files.newByteChannel(filePath, EnumSet.of(StandardOpenOption.CREATE, StandardOpenOption.WRITE));
                    params = clients.get(conn);
                    params.put("fileChannel", fileChannel);
                    md = MessageDigest.getInstance("MD5");
                    params.put("md", md);
                    System.out.println("server accept file request: " + fileName);
                    FilePacket ackP = FilePacket.constructAckNewFilePacket(FilePacket.SUCCESS_CODE);
                    conn.send(ackP.getBuffer());
                } catch (Exception e){
                    System.out.println("server deny file request");
                    FilePacket ackP = FilePacket.constructAckNewFilePacket(FilePacket.ERROR_CODE);
                    conn.send(ackP.getBuffer());
                }
                break;
            case FilePacket.P_FILE_DATA:
                params = clients.get(conn);
                fileChannel = (ByteChannel) params.get("fileChannel");
                md = (MessageDigest)params.get("md");
                try {
                    p.getBuffer().mark();
                    md.update(p.getBuffer());
                    p.getBuffer().reset();
                    fileChannel.write(p.getBuffer());
                } catch (IOException e){
                    try {
                        fileChannel.close();
                    } catch (IOException ignore) {
                    }
                    conn.close();
                }
                break;
            case FilePacket.P_FILE_END:
                params = clients.get(conn);
                fileChannel = (ByteChannel) params.get("fileChannel");
                md = (MessageDigest)params.get("md");
                try {
                    byte[] digest = md.digest();
                    String localDigest = DatatypeConverter.printHexBinary(digest).toUpperCase();
                    int digestBytesLen = p.getBuffer().getInt();
                    byte[] digestBytes = new byte[digestBytesLen];
                    p.getBuffer().get(digestBytes);
                    String remoteDigest = new String(digestBytes, StandardCharsets.UTF_8);
                    System.out.println("receive file end, digest : " + remoteDigest);
                    FilePacket ackP;
                    if(localDigest.equals(remoteDigest)){
                        System.out.println("file digests are same, send success ack code");
                        ackP = FilePacket.constructAckFileEndPacket(FilePacket.SUCCESS_CODE);
                    } else {
                        System.out.println("file digests are not same, send error ack code");
                        ackP = FilePacket.constructAckFileEndPacket(FilePacket.ERROR_CODE);
                    }
                    conn.send(ackP.getBuffer());
                } finally {
                    try {
                        fileChannel.close();
                    } catch (IOException ignore) {
                    }
                }
                break;
        }
    }

    @Override
    public void onError(WebSocket webSocket, Exception e) {

    }

    public static void main(String[] args) throws UnknownHostException, InterruptedException {
        FileServer s = new FileServer( 8888 );
        s.start();
        System.out.println( "FileServer started on port: " + s.getPort() );

        Thread.sleep(Long.MAX_VALUE);
    }
}
```

`FileClient.java`

```java
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.drafts.Draft_17;
import org.java_websocket.handshake.ServerHandshake;

import javax.xml.bind.DatatypeConverter;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.channels.ByteChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.util.EnumSet;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Created by jeremy on 16/6/11.
 */
public class FileClient implements Runnable{

    private final String wsUrl;
    private final Path filePath;
    private WebSocketClient wsclient;

    private volatile AtomicBoolean running = new AtomicBoolean(false);

    public FileClient(String wsUrl, Path filePath) {
        this.wsUrl = wsUrl;
        this.filePath = filePath;

    }

    public static void main(String[] args) throws InterruptedException {
        FileClient fileClient = new FileClient("ws://127.0.0.1:8888", Paths.get("/tmp/onedir", "test1.txt"));
        fileClient.start();

        fileClient.await();
    }

    private void await() {
        while(running.get()){
            synchronized (running) {
                try {
                    running.wait(2000L);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    private void start() {
        Thread t = new Thread(this);
        t.start();
        running.set(true);
    }

    public void run() {
        try {
            wsclient = new WebSocketClient(new URI(this.wsUrl), new Draft_17()) {
                @Override
                public void onOpen(ServerHandshake serverHandshake) {
                    String fileName = FileClient.this.filePath.getFileName().toString();
                    System.out.println("request send file : " + fileName);
                    FilePacket p = FilePacket.constructNewFilePacket(fileName);
                    this.send(p.getBuffer().array());
                }

                @Override
                public void onMessage(String s) {
                    // do nothing
                }

                @Override
                public void onMessage(ByteBuffer bytes) {
                    FilePacket p = FilePacket.parseByteBuffer(bytes);
                    int code;
                    switch (p.getType()) {
                        case FilePacket.P_ACK_NEW_FILE:
                            code = (int)p.getBuffer().get();
                            if(FilePacket.SUCCESS_CODE == code){
                                System.out.println("server accept file request");
                                startSendFileData();
                            }
                            break;
                        case FilePacket.P_ACK_FILE_END:
                            code = (int)p.getBuffer().get();
                            if(FilePacket.SUCCESS_CODE == code){
                                System.out.println("server save file sucessfully");
                                wsclient.close();
                            }
                            break;
                    }
                }

                @Override
                public void onClose(int i, String s, boolean b) {
                    stop();
                }

                @Override
                public void onError(Exception e) {
                    stop();
                }
            };

            wsclient.connect();
        } catch (URISyntaxException e) {
            e.printStackTrace();
            stop();
        }
    }

    private void stop(){
        running.set(false);
        synchronized (running){
            running.notify();
        }
    }

    private void startSendFileData() {
        Runnable runnable = new Runnable() {
            public void run() {

                try {
                    ByteChannel fileChannel = Files.newByteChannel(FileClient.this.filePath, EnumSet.of(StandardOpenOption.READ));
                    ByteBuffer buffer = ByteBuffer.allocate(1 + 4096);
                    buffer.order(ByteOrder.BIG_ENDIAN);

                    MessageDigest md = MessageDigest.getInstance("MD5");

                    int bytesRead = -1;

                    buffer.clear();//make buffer ready for write
                    buffer.put((byte)FilePacket.P_FILE_DATA);

                    while((bytesRead = fileChannel.read(buffer)) != -1){
                        buffer.flip();  //make buffer ready for read
                        buffer.mark();
                        buffer.get(); //skip a byte
                        md.update(buffer);
                        buffer.reset();
                        FileClient.this.wsclient.getConnection().send(buffer);
                        buffer.clear(); //make buffer ready for write
                        buffer.put((byte)FilePacket.P_FILE_DATA);
                    }

                    byte[] digest = md.digest();
                    String digestInHex = DatatypeConverter.printHexBinary(digest).toUpperCase();
                    System.out.println("send file finished, digest: " + digestInHex);
                    FilePacket p = FilePacket.constructFileEndPacket(digestInHex);
                    FileClient.this.wsclient.getConnection().send(p.getBuffer());
                } catch (Exception e) {
                    wsclient.close();
                }
            }
        };

        new Thread(runnable).start();

    }
}
```

## 注意事项

1. 为了清除内存byte数组拷贝，全部使用的是Java NIO的Buffer，所以要注意`flip`、`clear`、`mark`、`reset`、`compact`的用法，用惯了Netty的Buffer，再用Java NIO的Buffer还真是不习惯
2. 服务器端与客户端传输了int，为了避免大小端问题，最好显式设置ByteOrder，`buffer.order(ByteOrder.BIG_ENDIAN);`
3. 为了提高文件操作效率，全部使用Java NIO File API，特别要注意打开文件的方式，`ByteChannel fileChannel = Files.newByteChannel(FileClient.this.filePath, EnumSet.of(StandardOpenOption.READ));`，这个跟Old File API有些不一样，在打开文件Channel时必须指定Channel的操作方式，详见`java.nio.file.StandardOpenOption`
