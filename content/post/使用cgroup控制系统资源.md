---
title: 使用cgroup控制系统资源
tags:
  - linux
  - cgroup
categories:
  - devops
date: 2016-07-03 23:43:00+08:00
---
工作中需要对mongodb进程进行，控制它最多使用的内存，简单想了一下，想到可以使用linux中的cgroup完成此功能，于是研究了一下cgroup，在这里记录备忘一下。

## 概念

CGroup 技术被广泛用于 Linux 操作系统环境下的物理分割，是 Linux Container 技术的底层基础技术，是虚拟化技术的基础。CGroup 是 Control Groups 的缩写，是 Linux 内核提供的一种可以限制、记录、隔离进程组 (process groups) 所使用的物力资源 (如 cpu memory i/o 等等) 的机制。CGroup 是将任意进程进行分组化管理的 Linux 内核功能。CGroup 本身是提供将进程进行分组化管理的功能和接口的基础结构，I/O 或内存的分配控制等具体的资源管理功能是通过这个功能来实现的。这些具体的资源管理功能称为 CGroup 子系统或控制器。CGroup 子系统有控制内存的 Memory 控制器、控制进程调度的 CPU 控制器等。CGroup 提供了一个 CGroup 虚拟文件系统，作为进行分组管理和各子系统设置的用户接口。

* 子系统（**subsystem**）。一个子系统就是一个资源控制器，比如cpu子系统就是控制cpu时间分配的一个控制器。子系统必须附加（attach）到一个层级上才能起作用，一个子系统附加到某个层级以后，这个层级上的所有控制组群都受到这个子系统的控制。使用`lssubsys -a`命令查看内核支持的子系统。
* 层级（**hierarchy**）。子系统必须附加（attach）到一个层级上才能起作用。使用`mkdir -p /cgroup/name && mount -t cgroup -o subsystems name /cgroup/name`命令创建一个层级，并把该层级挂载到目录。
* 控制组群（**control group**）。控制组群就是一组按照某种标准划分的进程。cgroups中的资源控制都是以控制组群为单位实现。一个进程可以加入到某个控制组群，也从一个进程组迁移到另一个控制组群。一个进程组的进程可以使用cgroups以控制组群为单位分配的资源，同时受到cgroups以控制组群为单位设定的限制。某一个层级上默认存在一个`cgroup_path`为`/`的控制组群，另外还可以创建树形结构的控制组群。使用`cgcreate -g subsystems:cgroup_path`命令可以创建控制组群。
* 任务（**task**）。任务就是系统的一个进程。控制组群所对应的目录中有一个`tasks`文件，将进程ID写进该文件，该进程就会受到该控制组群的限制。

另外上述4个概念还存在一些规则，如下
* 每次在系统中创建新层级时，该系统中的所有任务都是那个层级的默认 cgroup（我们称之为 root cgroup，此 cgroup 在创建层级时自动创建，后面在该层级中创建的 cgroup 都是此 cgroup 的后代）的初始成员；比如在创建其它控制组群之前，使用`cat /cgroup/memory/tasks`命令查看一下，就可以看到系统里所有进程的ID都在这儿。
* 一个子系统最多只能附加到一个层级；比如使用`lssubsys -am`可以看到`memory`子系统都附件到`memory`层级并挂载至`/cgroup/memory`了，此时就不可再使用`mkdir -p /cgroup/memory2 && mount -t cgroup -o memory memory2 /cgroup/memory2`命令将`memory`子系统再附加到其它层级了。
* 一个层级可以附加多个子系统；可以使用`mkdir -p /cgroup/cpu,cpuacct && mount -t cgroup -o cpu,cpuacct cpu,cpuacct /cgroup/cpu,cpuacct`命令将`cpu`、`cpuacct`附加至层级`cpu,cpuacct`并挂载至`/cgroup/cpu,cpuacct`
* 一个任务可以是多个 cgroup 的成员，但是这些 cgroup 必须在不同的层级；比如一个层级里某一个进程ID只能归属于唯一一个控制组群，但该进程ID还可以归属于另一个层级里的唯一一个控制组群。
* 系统中的进程（任务）创建子进程（任务）时，该子任务自动成为其父进程所在 cgroup 的成员。然后可根据需要将该子任务移动到不同的 cgroup 中，但开始时它总是继承其父任务的 cgroup。

设计成这样的原因如下：

> 因为某个任务可属于任一层级中的单一cgroup，所以只有一个方法可让单一子系统限制或者影响任务。这是合理的：是一个功能，而不是限制。
您可以将几个子系统分组在一起以便它们可影响单一层级中的所有任务。因为该层级中的cgroup有不同的参数设定，因此会对那些任务产生不同的影响。
有时可能需要重构层级。例如：从附加了几个子系统的层级中删除一个子系统，并将其附加到不同的层级中。
反正，如果从不同层级中分离子系统的需求降低，则您可以删除层级并将其子系统附加到现有层级中。
这个设计允许简单的cgroup使用，比如为单一层级中的具体任务设定几个参数，单一层级可以是只附加了cpu和memeory子系统的层级。
这个设计还允许高精度配置：系统中的每个任务（进程）都可以是每个层级的成员，每个层级都有单一附加的子系统。这样的配置可让系统管理员绝对控制每个单一任务的所有参数。

## 子系统

cgroups为每种可以控制的资源定义了一个子系统。典型的子系统介绍如下：

* cpu 子系统，主要限制进程的 cpu 使用率。
* cpuacct 子系统，可以统计 cgroups 中的进程的 cpu 使用报告。
* cpuset 子系统，可以为 cgroups 中的进程分配单独的 cpu 节点或者内存节点。
* memory 子系统，可以限制进程的 memory 使用量。
* blkio 子系统，可以限制进程的块设备 io。
* devices 子系统，可以控制进程能够访问某些设备。
* net_cls 子系统，可以标记 cgroups 中进程的网络数据包，然后可以使用 tc 模块（traffic control）对数据包进行控制。
* freezer 子系统，可以挂起或者恢复 cgroups 中的进程。
* ns 子系统，可以使不同 cgroups 下面的进程使用不同的 namespace。

## cgconfig.conf 文件

上面都是使用命令控制层级和控制组群，而且并没有将创建的结果存储下来，系统重启后创建的结果就没了。所以系统提供了cgconfig.conf文件，cgconfig 服务启动时会读取 cgroup 配置文件 -- /etc/cgconfig.conf。根据配置文件的内容，cgconfig 可创建层级、挂载所需文件系统、创建 cgroup 以及为每个组群设定子系统参数。

cgconfig.conf 文件包含两个主要类型的条目 -- mount 和 group。挂载条目生成并挂载层级并将其作为虚拟文件系统，同时将子系统附加到那些层级中。挂载条目使用以下语法定义：

```bash
mount {
    <controller> = <path>;
    …
}
```

组群条目创建 cgroup 并设定子系统参数。组群条目使用以下语法定义：

```bash
group <name> {
    [<permissions>]
    <controller> {
        <param name> = <param value>;
        …
    }
    …
}
```

请注意 permissions 部分是可选的。要为组群条目定义权限，请使用以下语法：

```bash
perm {
    task {
        uid = <task user>;
        gid = <task group>;
    }
    admin {
       uid = <admin name>;
       gid = <admin group>;
    }
}
```
这个表示`<admin group>:<admin name>`的用户可以调整该控制组群中子系统的参数，而`<task group>:<task user>`的用户可以读写该控制组群中的tasks文件。

还是举个实例：

```bash
mount {
		cpuset  = /cgroup/cpuset;
		cpu     = /cgroup/cpu;
		cpuacct = /cgroup/cpuacct;
		memory  = /cgroup/memory;
		devices = /cgroup/devices;
		freezer = /cgroup/freezer;
		net_cls = /cgroup/net_cls;
		blkio   = /cgroup/blkio;
}

group mysql_g1 {
    perm {
        task {
            uid = root;
            gid = sqladmin;
        } admin {
            uid = root;
            gid = root;
        }
    }
    cpu {
           cpu.cfs_quota_us = 50000;
           cpu.cfs_period_us = 100000;
    }
    cpuset {
           cpuset.cpus = "3";
           cpuset.mems = "0";
    }
    memory {
           memory.limit_in_bytes=104857600;
           memory.swappiness=0;
    }
    blkio  {
          blkio.throttle.read_bps_device="8:0 524288";
          blkio.throttle.write_bps_device="8:0 524288";
    }
}

group mongodb_g1 {
    perm {
        task {
            uid = root;
            gid = mongodbadmin;
        } admin {
            uid = root;
            gid = root;
        }
    }
    cpu {
           cpu.cfs_quota_us = 50000;
           cpu.cfs_period_us = 100000;
    }
}
```

## 将某个进程移动到控制组群中

有3个办法完成这个操作：

* ###cgclassify 命令###
  可以运行 cgclassify 命令将进程移动到 cgroup 中，cgclassify 的语法为：`cgclassify -g subsystems:path_to_cgroup pidlist`，其中：
  * subsystems 是用逗号分开的子系统列表，或者 * 启动与所有可用子系统关联的层级中的进程。请注意：如果在多个层级中有同名的 cgroup，则 -g 选项会将该进程移动到每个组群中。
  * path_to_cgroup 是到其层级中的 cgroup 的路径
  * pidlist 是用空格分开的进程识别符（PID）列表
  还可以在 pid 前面添加 -- sticky 选项以保证所有子进程位于同一 cgroup 中。
  举个例子

```bash
cgclassify -g cpu,memory:mysql_g1 1701
```

* ###cgred 守护进程###
  Cgred 是一个守护进程，它可根据在 /etc/cgrules.conf 文件中设定的参数将任务移动到 cgroup 中。/etc/cgrules.conf 文件中的条目可以使用以下两个格式之一：

```bash
user hierarchies control_group
user:command hierarchies control_group
```

  举个例子

```bash
maria:ftp		devices		/usergroup/staff/ftp
```

* ###cgexec 命令###
  可以运行 cgexec 命令在 cgroup 中启动进程。cgexec 语法为：`cgexec -g subsystems:path_to_cgroup command arguments` ，其中：
  * subsystems 是用逗号分开的子系统列表或者 * 启动与所有可用子系统关联的层级中的进程。请注意：如 第 2.7 节 “设置参数” 所述的cgset，如果在多个层级中有同名的 cgroup，-g 选项会在每个组群中创建进程。
  * path_to_cgroup 是到与该层级相关的 cgroup 的路径。
  * command 是要运行的命令
  * arguments 是该命令所有参数

  举个例子

```bash
cgexec -g cpu:group1 lynx http://www.redhat.com
```

## 设置子系统参数

可以运行 cgset 命令设定子系统参数。cgset 的语法为：`cgset -r parameter=value path_to_cgroup` ，其中：
  * parameter 是要设定的参数，该参数与给定 cgroup 的目录中的文件对应。
  * value 是为参数设定的值
  * path_to_cgroup 是到相对该层级 root 的 cgroup 路径

举个例子：

```bash
cgset -r cpuset.cpus=0-1 group1
```

可以使用 cgset 将一个 cgroup 中的参数复制到另一个现有 cgroup 中。使用 cgset 复制参数的语法为：`cgset --copy-from path_to_source_cgroup path_to_target_cgroup`，其中：
  * path_to_source_cgroup 是相对该层级中 root 组群，到要复制其参数的 cgroup 的路径。
  * path_to_target_cgroup 是相对该层级 root 组群的目的 cgroup 的路径。

举个例子：

```bash
cgset --copy-from group1/ group2/
```

## 获取子系统参数

可以运行 cgget 命令获取子系统参数。cgget 的语法为：`cgget -r parameter list_of_cgroups`，其中：
  * parameter 是包含子系统值的伪文件
  * list_of_cgroups 是用空格分开的 cgroup 列表

举个例子：

```bash
cgget -r cpuset.cpus -r memory.limit_in_bytes lab1 lab2
```

如果不知道参数名称，请使用类似命令：

```bash
cgget -g cpuset lab1 lab2
```

## 子系统可调参数

子系统可调参数比较多，可参考`https://access.redhat.com/documentation/zh-CN/Red_Hat_Enterprise_Linux/6/html/Resource_Management_Guide/ch-Subsystems_and_Tunable_Parameters.html`

## 应用实例

在我的场景里需要对MongoDB服务进行资源限制，限制MongoDB服务所使用的内存在500M以内。

修改/etc/cgconfig.conf文件：

```bash
mount {
		cpuset  = /cgroup/cpuset;
		cpu     = /cgroup/cpu;
		cpuacct = /cgroup/cpuacct;
		memory  = /cgroup/memory;
		devices = /cgroup/devices;
		freezer = /cgroup/freezer;
		net_cls = /cgroup/net_cls;
		blkio   = /cgroup/blkio;
}

group mongodb_g1 {
    memory {
           memory.limit_in_bytes=524288000;
           memory.swappiness=0;
    }
}
```

然后修改/etc/init.d/mongod，使用cgexec启动mongod进程

```bash
/sbin/startproc -u $MONGOD_USER -g $MONGOD_GROUP -s -e /usr/bin/cgexec -g memory:mongodb_g1 $MONGOD_BIN --config /etc/mongod.conf run
```

## 参考

`https://access.redhat.com/documentation/zh-CN/Red_Hat_Enterprise_Linux/6/html/Resource_Management_Guide/ch01.html`
`http://www.ibm.com/developerworks/cn/linux/1506_cgroup/index.html`
`http://colobu.com/2015/07/23/Using-Cgroups-to-Limit-MongoDB-memory-usage/`
