---
title: 巧妙调试docker容器
tags:
  - docker
  - bash
categories:
  - devops
date: 2019-04-21 20:00:00+08:00
---

## 问题

工作中经常发现一些第三方写的docker容器运行有问题，这时我们会通过`docker logs`命令观察容器的运行日志。很可惜，有时容器中运行的程序仅从日志很难查明问题。这时我们会通过`docker exec`在目标容器中执行某些命令以探查问题，有时却发现一些镜像很精简，连基本的`sh`、`bash`、`netstat`等命令都没包含。这时就很尴尬了，诊断问题很困难。

## 不太优雅的解决方案

为了避免上述问题，我们在开发过程中一般要求最终打出的docker镜像中包含一些基本的调试命令，如`sh`、`bash`、`netstat`、`telnet`等。但这个解决方案只能规范自己开发的docker镜像，对于第三方开发的docker镜像就没办法了，而且会导致最终打出的镜像变大了不少，影响镜像的分发效率。

## 更优雅的方案

今天在`github.com`上闲逛时偶然发现一个工具[docker-debug](https://github.com/zeromake/docker-debug)，发现这个工具可以很好的解决这个问题。

这个工具的使用方法也很简单，参考以下命令：

```bash
# Suppose the container below is a container which should be checked
docker run -d --name dev -p 8000:80 nginx:latest

# Enter a shell where we can access the above container's namespaces (ipc, pid, network, etc, filesystem)
docker-debug dev bash -l
```

更丰富的使用说明参考[这个视频](https://asciinema.org/a/235025)

## docker-debug的实现原理

看了下文档，发现[docker-debug](https://github.com/zeromake/docker-debug)的实现原理也挺简单的。

> 1. find image docker is has, not has pull the image.
> 2. find container name is has, not has return error.
> 3. from customize image runs a new container in the container's namespaces (ipc, pid, network, etc, filesystem) with the STDIN stay open.
> 4. create and run a exec on new container.
> 5. Debug in the debug container.
> 6. then waits for the debug container to exit and do the cleanup.

简单说执行docker-debug命令也会使用一个包含了常用诊断命令的镜像启动一个诊断容器，该诊断容器将在目标容器相关的命名空间中运行，这样在这个容器中就可以访问目标容器的ipc, pid, network, etc, filesystem，然后使用`docker exec`命令在诊断容器运行命令，并将`docker exec`运行命令的输入输出pipe到docker-debug命令的输入输出上。

## docker-debug的源码分析

在大量使用该工具前，简单分析下这个工具的源码。

工具的主逻辑源码在[这里](https://github.com/zeromake/docker-debug/blob/master/internal/command/root.go#L129)

```go
containerID, err = cli.FindContainer(options.container)
	if err != nil {
		return err
	}
	containerID, err = cli.CreateContainer(containerID, options)
	if err != nil {
		return err
	}
	resp, err := cli.ExecCreate(options, containerID)
	if err != nil {
		return err
	}

	errCh := make(chan error, 1)

	go func() {
		defer close(errCh)
		errCh <- func() error {
			return cli.ExecStart(options, resp.ID)
		}()
	}()
```

其中有两处重点：

一个是创建一个容器使用目标容器的ipc, pid, network, etc, filesystem，源码在[这里](https://github.com/zeromake/docker-debug/blob/master/internal/command/cli.go#L248)

```go
// CreateContainer create new container and attach target container resource
func (cli *DebugCli) CreateContainer(attachContainer string, options execOptions) (string, error) {
	var mounts []mount.Mount
	if cli.config.MountDir != "" {
		ctx, cancel := cli.withContent(cli.config.Timeout)
		info, err := cli.client.ContainerInspect(ctx, attachContainer)
		cancel()
		if err != nil {
			return "", errors.WithStack(err)
		}
		mountDir, ok := info.GraphDriver.Data["MergedDir"]
		mounts = []mount.Mount{}
		if ok {
			mounts = append(mounts, mount.Mount{
				Type:   "bind",
				Source: mountDir,
				Target: cli.config.MountDir,
			})
		}
		for _, i := range info.Mounts {
			var mountType = i.Type
			if i.Type == "volume" {
				mountType = "bind"
			}
			mounts = append(mounts, mount.Mount{
				Type:     mountType,
				Source:   i.Source,
				Target:   cli.config.MountDir + i.Destination,
				ReadOnly: !i.RW,
			})
		}
	}
	if options.volumes != nil {
		// -v bind mount
		if mounts == nil {
			mounts = []mount.Mount{}
		}
		for _, m := range options.volumes {
			mountArgs := strings.Split(m, ":")
			mountLen := len(mountArgs)
			if mountLen > 0 && mountLen <= 3 {
				mountDefault := mount.Mount{
					Type: "bind",
					ReadOnly: false,
				}
				switch mountLen {
				case 1:
					mountDefault.Source = mountArgs[0]
					mountDefault.Target = mountArgs[0]
				case 2:
					if mountArgs[1] == "rw" || mountArgs[1] == "ro" {
						mountDefault.ReadOnly = mountArgs[1] != "rw"
						mountDefault.Source = mountArgs[0]
						mountDefault.Target = mountArgs[0]
					} else {
						mountDefault.Source = mountArgs[0]
						mountDefault.Target = mountArgs[1]
					}
				case 3:
					mountDefault.Source = mountArgs[0]
					mountDefault.Target = mountArgs[1]
					mountDefault.ReadOnly = mountArgs[2] != "rw"
				}
				mounts = append(mounts, mountDefault)
			}
		}
	}
	targetName := containerMode(attachContainer)

	conf := &container.Config{
		Entrypoint: strslice.StrSlice([]string{"/usr/bin/env", "sh"}),
		Image:      cli.config.Image,
		Tty:        true,
		OpenStdin:  true,
		StdinOnce:  true,
	}
	hostConfig := &container.HostConfig{
		NetworkMode: container.NetworkMode(targetName),
		UsernsMode:  container.UsernsMode(targetName),
		IpcMode:     container.IpcMode(targetName),
		PidMode:     container.PidMode(targetName),
		Mounts:      mounts,
		//VolumesFrom: []string{attachContainer},
	}
	ctx, cancel := cli.withContent(cli.config.Timeout)
	body, err := cli.client.ContainerCreate(
		ctx,
		conf,
		hostConfig,
		nil,
		"",
	)
	cancel()
	if err != nil {
		return "", errors.WithStack(err)
	}
	ctx, cancel = cli.withContent(cli.config.Timeout)
	err = cli.client.ContainerStart(
		ctx,
		body.ID,
		types.ContainerStartOptions{},
	)
	cancel()
	return body.ID, errors.WithStack(err)
}
```

一个是将`docker exec`运行命令的输入输出pipe到docker-debug命令的输入输出，源码在[这里](https://github.com/zeromake/docker-debug/blob/master/internal/command/cli.go#L394)

```go
// ExecStart exec start
func (cli *DebugCli) ExecStart(options execOptions, execID string) error {
	execConfig := types.ExecStartCheck{
		Tty: true,
	}

	ctx, cancel := cli.withContent(cli.config.Timeout)
	response, err := cli.client.ContainerExecAttach(ctx, execID, execConfig)
	defer cancel()
	if err != nil {
		return errors.WithStack(err)
	}
	streamer := tty.HijackedIOStreamer{
		Streams:      cli,
		InputStream:  cli.in,
		OutputStream: cli.out,
		ErrorStream:  cli.err,
		Resp:         response,
		TTY:          true,
	}
	return streamer.Stream(context.Background())
}
```

整个实现逻辑还是比较清晰的。

另外，还发现类似的工具[kube-debug](https://github.com/aylei/kubectl-debug)，以后诊断pod中的问题方便多了。

## 参考

1. https://docs.docker.com/engine/api/latest
2. <https://github.com/zeromake/docker-debug>
3. <https://github.com/aylei/kubectl-debug>