---
title: Java监听目录文件变更
tags:
  - java
  - nio
  - filesystem
categories:
  - java开发
date: 2016-05-12 23:38:00+08:00
---
Java 7中提供了`java.nio.file.WatchService`用来监听文件系统目录变更，用起来还是比较简单的，在这里记录一下。

### 创建一个WatchService

代码如下：

```java
WatchService watcher = FileSystems.getDefault().newWatchService();
```

当然一个WatchService是关联着操作系统资源的，需要完全的关闭，所以一般像下面这样写：

```java
WatchService watcher = null;
try {
  watcher = FileSystems.getDefault().newWatchService();
  ...
} finally {
  if(watcher != null){
    try {
      watcher.close();
    } catch (Exception ignore){}
  }
}
```

### 注册监听一个目录

```java
Path dir = Paths.get("/somewhere");
WatchKey key = dir.register(watcher, ENTRY_CREATE, ENTRY_DELETE, ENTRY_MODIFY);
```

这里这个`key`即与这个`dir`关联，以后`dir`里一旦发生监听的事件，则从`watcher`就可以`poll`或`take`到这个`key`

### 循环从WatchService里取出有信号的WatchKey

```java
for (;;) {
    // wait for key to be signalled
    WatchKey key;
    try {
        key = watcher.take();
    } catch (InterruptedException x) {
        return;
    }

    for (WatchEvent<?> event: key.pollEvents()) {
        WatchEvent.Kind kind = event.kind();

        // TBD - provide example of how OVERFLOW event is handled
        if (kind == OVERFLOW) {
            continue;
        }

        // Context for directory entry event is the file name of entry
        WatchEvent<Path> ev = (WatchEvent<T>)event;
        Path name = ev.context();

        ...
    }

    // reset key and remove from set if directory no longer accessible
    boolean valid = key.reset();
    if (!valid) {
        break;
    }
}
```

`WatchKey`被`cancel`或`WatchService`被`close`时，`key.reset()`会返回`false`, 此时应该跳出循环。

### 递归监听目录

上述的代码很简单了，跟Java原生NIO的思想差不多。不过经我实验，`dir.register(watcher, ENTRY_CREATE, ENTRY_DELETE, ENTRY_MODIFY);`只会监听该目录下一级的变更事件，子目录下的变更就监听不到了。例如在`/somewhere`目录下建一个目录`test`，再在test下建一个文件`test.txt`，此时就监听不到了。简单写了个递归监听某个目录下所有变更的例子，如下

```java
import java.nio.file.*;
import static java.nio.file.StandardWatchEventKinds.*;
import static java.nio.file.LinkOption.*;
import java.nio.file.attribute.*;
import java.io.*;
import java.util.*;

/**
 * Created by jeremy on 16/5/12.
 */
public class WatchDir {

    private final WatchService watcher;
    private final Map<WatchKey,Path> keys;
    private boolean trace = false;

    @SuppressWarnings("unchecked")
    static <T> WatchEvent<T> cast(WatchEvent<?> event) {
        return (WatchEvent<T>)event;
    }

    /**
     * Register the given directory with the WatchService
     */
    private void register(Path dir) throws IOException {
        WatchKey key = dir.register(watcher, ENTRY_CREATE, ENTRY_DELETE, ENTRY_MODIFY);
        if (trace) {
            Path prev = keys.get(key);
            if (prev == null) {
                System.out.format("register: %s\n", dir);
            } else {
                if (!dir.equals(prev)) {
                    System.out.format("update: %s -> %s\n", prev, dir);
                }
            }
        }
        keys.put(key, dir);
    }

    /**
     * Register the given directory, and all its sub-directories, with the
     * WatchService.
     */
    private void registerAll(final Path start) throws IOException {
        // register directory and sub-directories
        Files.walkFileTree(start, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs)
                    throws IOException
            {
                register(dir);
                return FileVisitResult.CONTINUE;
            }
        });
    }

    /**
     * Creates a WatchService and registers the given directory
     */
    WatchDir(Path dir) throws IOException {
        this.watcher = FileSystems.getDefault().newWatchService();
        this.keys = new HashMap<WatchKey,Path>();

        System.out.format("Scanning %s ...\n", dir);
        registerAll(dir);
        System.out.println("Done.");

        // enable trace after initial registration
        this.trace = true;
    }

    /**
     * Process all events for keys queued to the watcher
     */
    void processEvents() {
        for (;;) {

            // wait for key to be signalled
            WatchKey key;
            try {
                key = watcher.take();
            } catch (InterruptedException x) {
                return;
            }

            Path dir = keys.get(key);
            if (dir == null) {
                System.err.println("WatchKey not recognized!!");
                continue;
            }

            for (WatchEvent<?> event: key.pollEvents()) {
                WatchEvent.Kind kind = event.kind();

                // TBD - provide example of how OVERFLOW event is handled
                if (kind == OVERFLOW) {
                    continue;
                }

                // Context for directory entry event is the file name of entry
                WatchEvent<Path> ev = cast(event);
                Path name = ev.context();
                Path child = dir.resolve(name);

                // print out event
                System.out.format("%s: %s\n", event.kind().name(), child);

                // if directory is created, and watching recursively, then
                // register it and its sub-directories
                if (kind == ENTRY_CREATE) {
                    try {
                        if (Files.isDirectory(child, NOFOLLOW_LINKS)) {
                            registerAll(child);
                        }
                    } catch (IOException x) {
                        // ignore to keep sample readbale
                    }
                }
            }

            // reset key and remove from set if directory no longer accessible
            boolean valid = key.reset();
            if (!valid) {
                keys.remove(key);

                // all directories are inaccessible
                if (keys.isEmpty()) {
                    break;
                }
            }
        }
    }

    static void usage() {
        System.err.println("usage: java WatchDir dir");
        System.exit(-1);
    }

    public static void main(String[] args) throws IOException {
        // parse arguments
        if (args.length == 0 || args.length > 1)
            usage();

        // register directory and process its events
        Path dir = Paths.get(args[0]);
        new WatchDir(dir).processEvents();
    }
}
```

`Path name = ev.context();`拿到的仅仅只是相对于`dir`的Path，并不是绝对路径，为了拼出绝对路径，没办法只能建了一个`Map keys`，用来维护`WatchKey`与`dir`的映射关系。本以为这样写，面对一个巨大的目录，`Map keys`将会很大，性能不好。实测监听一个100多G的目录，并没占用太多内存，进程使用的文件句柄数也正常得很，而且性能还比较高。

希望Java以后的版本能直接在`WatchEvent`拿到变更`ENTRY`的绝对路径就好了。


