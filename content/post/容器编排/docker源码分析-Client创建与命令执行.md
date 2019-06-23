---
title: docker源码分析-Client创建与命令执行
tags:
  - docker
  - golang
categories:
  - 容器编排
date: 2016-10-05 15:38:00+08:00
---
一直在研究docker，最近被人问到docker到底是怎么工作的却不是太清楚，在网上偶然看到一本讲[docker源码的电子书](http://www.kancloud.cn/infoq/docker-source-code-analysis/80525)，花了整晚看了下，终于对docker的实现细节比较清楚了。但这本电子书讲的是1.2版本时的docker源码，跟最新的1.12版本相比差别还是挺大的，在这本书里讲到的源码与最新源码已经对应不上了。因此我计划写一份针对1.12版本的docker源码分析。

## docker的总体架构

这部分基本没有太大的变化，我觉得可以直接参照1.2版本的总体架构，就不重复分析了。见[这里](http://www.kancloud.cn/infoq/docker-source-code-analysis/80525)。

## Client创建与命令执行

在1.12版本里，最终编译生成的二进制拆分成了两个：docker和dockerd。从名字就很容易猜得出一个是客户端，一个是daemon端。这里我们先分析客户端。

docker客户端的入口文件在`cmd/docker/docker.go`。

main函数的头两句

```
stdin, stdout, stderr := term.StdStreams()
logrus.SetOutput(stderr)
```

取得了终端的标准输入、标准输出、标准错误，并将日志输出至标准错误。

```
dockerCli := command.NewDockerCli(stdin, stdout, stderr)
```

然后创建`DockerCli`对象，`DockerCli`对象在`cli/cli.go`里声明。

```
cmd := newDockerCommand(dockerCli)
```

然后创建`DockerCommand`对象，这个是`github.com/spf13/cobra`库里所提及的所有命令的根命令。

```
	if err := cmd.Execute(); err != nil {
		if sterr, ok := err.(cli.StatusError); ok {
			if sterr.Status != "" {
				fmt.Fprintln(stderr, sterr.Status)
			}
			// StatusError should only be used for errors, and all errors should
			// have a non-zero exit status, so never exit with 0
			if sterr.StatusCode == 0 {
				os.Exit(1)
			}
			os.Exit(sterr.StatusCode)
		}
		fmt.Fprintln(stderr, err)
		os.Exit(1)
	}
```

最后执行命令，如果有错误则打印到标准输出里，然后退出。

看了下main函数，大家肯定知道关键代码肯定在`cmd := newDockerCommand(dockerCli)`这里。再来看`newDockerCommand`函数。

```
opts := cliflags.NewClientOptions()
var flags *pflag.FlagSet
```

这里首先创建了一个`ClientOptions`对象，一个`*pflag.FlagSet`对象

```
	cmd := &cobra.Command{
		Use:              "docker [OPTIONS] COMMAND [arg...]",
		Short:            "A self-sufficient runtime for containers.",
		SilenceUsage:     true,
		SilenceErrors:    true,
		TraverseChildren: true,
		Args:             noArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if opts.Version {
				showVersion()
				return nil
			}
			fmt.Fprintf(dockerCli.Err(), "\n"+cmd.UsageString())
			return nil
		},
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			// flags must be the top-level command flags, not cmd.Flags()
			opts.Common.SetDefaultOptions(flags)
			dockerPreRun(opts)
			return dockerCli.Initialize(opts)
		},
	}
	cli.SetupRootCommand(cmd)
```

然后构造了一个`github.com/spf13/cobra`库里所提及的根命令，当用户执行`docker`命令，并且不匹配其它子命令时，则这个根命令将得到执行，也即打印docker命令的用法。再使用`cli.SetupRootCommand(cmd)`初始化根命令。这个方法在`cli/cobra.go`里声明。

这里要提一下`github.com/spf13/cobra`库的工作原理。`github.com/spf13/cobra`库将一个命令行工具的所有命令抽象为一个层次结构，最上层为根命令，每个命令又可以定义它的子命令。每个命令在定义时可设置它的描述性文字，支持的选项、用法描述、命令的执行逻辑、相关模板等。用户执行命令行时，会根据命令行参数自动查找对应的命令，然后就可以运行该命令的执行逻辑了。详细用法可参阅`github.com/spf13/cobra`库的[文档](https://github.com/spf13/cobra)

```
	flags = cmd.Flags()
	flags.BoolVarP(&opts.Version, "version", "v", false, "Print version information and quit")
	flags.StringVar(&opts.ConfigDir, "config", cliconfig.ConfigDir(), "Location of client config files")
	opts.Common.InstallFlags(flags)
```

这些是一些命令行参数的定义。

```
	cmd.SetOutput(dockerCli.Out())
```

设置命令的输出为`DockerCli`的输出。

```
cmd.AddCommand(newDaemonCommand())
```

将`DaemonCommand`添加为根命令的子命令，这样`docker daemon`命令即可启动`docker daemon`。代码里也说到这个特性以后会移除的，所以这个命令的`Hidden`被设置为了`true`，即显示命令用法时，并不会显示它。`newDaemonCommand`函数定义在`cmd/docker/daemon_unix.go`里。

```
commands.AddCommands(cmd, dockerCli)
```

将其它子命令添加至根命令，`commands.AddCommands`函数定义在`cli/command/commands/commands.go`里。

```
func AddCommands(cmd *cobra.Command, dockerCli *command.DockerCli) {
	cmd.AddCommand(
		node.NewNodeCommand(dockerCli),
		service.NewServiceCommand(dockerCli),
		stack.NewStackCommand(dockerCli),
		stack.NewTopLevelDeployCommand(dockerCli),
		swarm.NewSwarmCommand(dockerCli),
		container.NewContainerCommand(dockerCli),
		image.NewImageCommand(dockerCli),
		system.NewSystemCommand(dockerCli),
		container.NewRunCommand(dockerCli),
		image.NewBuildCommand(dockerCli),
		network.NewNetworkCommand(dockerCli),
		hide(system.NewEventsCommand(dockerCli)),
		registry.NewLoginCommand(dockerCli),
		registry.NewLogoutCommand(dockerCli),
		registry.NewSearchCommand(dockerCli),
		system.NewVersionCommand(dockerCli),
		volume.NewVolumeCommand(dockerCli),
		hide(system.NewInfoCommand(dockerCli)),
		hide(container.NewAttachCommand(dockerCli)),
    ...
		hide(system.NewInspectCommand(dockerCli)),
		checkpoint.NewCheckpointCommand(dockerCli),
		plugin.NewPluginCommand(dockerCli),
	)
}
```

可以看到这里定义了很多子命令，并添加为根命令的子命令，每个子命令构建时都将`DockerCli`对象传入了。同样为了保证兼容性的，对其它不少子命令用的`hide`函数对原有命令进行了处理，将其`Hidden`属性设置为了`true`。

```
	return cmd
```

添加好子命令后，`newDockerCommand`函数就返回这个根命令退出了。

## Client命令行示例

这里我拿一个非常简单的子命令示例，来说明Docker客户端是如何运行的。

比如执行`docker system info`命令，根据子命令定义，首先找到了`system.NewSystemCommand`函数，它是在`cli/command/system/cmd.go`里定义的。

```
func NewSystemCommand(dockerCli *command.DockerCli) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "system",
		Short: "Manage Docker",
		Args:  cli.NoArgs,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Fprintf(dockerCli.Err(), "\n"+cmd.UsageString())
		},
	}
	cmd.AddCommand(
		NewEventsCommand(dockerCli),
		NewInfoCommand(dockerCli),
		NewDiskUsageCommand(dockerCli),
		NewPruneCommand(dockerCli),
	)
	return cmd
}
```

又由于子命令`info`，所以找到`NewInfoCommand`函数，这是在`cli/command/system/info.go`里定义的。

```
// NewInfoCommand creates a new cobra.Command for `docker info`
func NewInfoCommand(dockerCli *command.DockerCli) *cobra.Command {
	var opts infoOptions

	cmd := &cobra.Command{
		Use:   "info [OPTIONS]",
		Short: "Display system-wide information",
		Args:  cli.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runInfo(dockerCli, &opts)
		},
	}

	flags := cmd.Flags()

	flags.StringVarP(&opts.format, "format", "f", "", "Format the output using the given go template")

	return cmd
}

func runInfo(dockerCli *command.DockerCli, opts *infoOptions) error {
	ctx := context.Background()
	info, err := dockerCli.Client().Info(ctx)
	if err != nil {
		return err
	}
	if opts.format == "" {
		return prettyPrintInfo(dockerCli, info)
	}
	return formatInfo(dockerCli, info, opts.format)
}
```

找到了匹配的子命令后，当命令等到执行时，该命令的`RunE`属性就会得到调用，即会调用`runInfo`函数，这个函数会调用`dockerCli.Client().Info`函数，并将输出结果格式化并写到DockerCli的输出。

`Info(ctx context.Context) (types.Info, error)`是一个接口，定义在`client/interface.go`里，其实现定义在`client/info.go`里。

```
func (cli *Client) Info(ctx context.Context) (types.Info, error) {
	var info types.Info
	serverResp, err := cli.get(ctx, "/info", url.Values{}, nil)
	if err != nil {
		return info, err
	}
	defer ensureReaderClosed(serverResp)

	if err := json.NewDecoder(serverResp.body).Decode(&info); err != nil {
		return info, fmt.Errorf("Error reading remote info: %v", err)
	}

	return info, nil
}
```

上述代码就比较简单了，就是向`docker daemon`里的`api`服务发送了一个get请求，并将响应结果用json解码，最终返回info。

再看看`cli.get`函数，这个定义在`client/request.go`，说白了就是发送了一个HTTP请求，不解释。

```
// getWithContext sends an http request to the docker API using the method GET with a specific go context.
func (cli *Client) get(ctx context.Context, path string, query url.Values, headers map[string][]string) (serverResponse, error) {
	return cli.sendRequest(ctx, "GET", path, query, nil, headers)
}

func (cli *Client) sendRequest(ctx context.Context, method, path string, query url.Values, obj interface{}, headers map[string][]string) (serverResponse, error) {
	var body io.Reader

	if obj != nil {
		var err error
		body, err = encodeData(obj)
		if err != nil {
			return serverResponse{}, err
		}
		if headers == nil {
			headers = make(map[string][]string)
		}
		headers["Content-Type"] = []string{"application/json"}
	}

	return cli.sendClientRequest(ctx, method, path, query, body, headers)
}

func (cli *Client) sendClientRequest(ctx context.Context, method, path string, query url.Values, body io.Reader, headers map[string][]string) (serverResponse, error) {
	serverResp := serverResponse{
		body:       nil,
		statusCode: -1,
	}

	expectedPayload := (method == "POST" || method == "PUT")
	if expectedPayload && body == nil {
		body = bytes.NewReader([]byte{})
	}

	req, err := cli.newRequest(method, path, query, body, headers)
	if err != nil {
		return serverResp, err
	}

	if cli.proto == "unix" || cli.proto == "npipe" {
		// For local communications, it doesn't matter what the host is. We just
		// need a valid and meaningful host name. (See #189)
		req.Host = "docker"
	}

	scheme, err := resolveScheme(cli.client.Transport)
	if err != nil {
		return serverResp, err
	}

	req.URL.Host = cli.addr
	req.URL.Scheme = scheme

	if expectedPayload && req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", "text/plain")
	}

	resp, err := ctxhttp.Do(ctx, cli.client, req)
	if err != nil {

		if scheme == "https" && strings.Contains(err.Error(), "malformed HTTP response") {
			return serverResp, fmt.Errorf("%v.\n* Are you trying to connect to a TLS-enabled daemon without TLS?", err)
		}

		if scheme == "https" && strings.Contains(err.Error(), "bad certificate") {
			return serverResp, fmt.Errorf("The server probably has client authentication (--tlsverify) enabled. Please check your TLS client certification settings: %v", err)
		}

		// Don't decorate context sentinel errors; users may be comparing to
		// them directly.
		switch err {
		case context.Canceled, context.DeadlineExceeded:
			return serverResp, err
		}

		if err, ok := err.(net.Error); ok {
			if err.Timeout() {
				return serverResp, ErrorConnectionFailed(cli.host)
			}
			if !err.Temporary() {
				if strings.Contains(err.Error(), "connection refused") || strings.Contains(err.Error(), "dial unix") {
					return serverResp, ErrorConnectionFailed(cli.host)
				}
			}
		}

		return serverResp, errors.Wrap(err, "error during connect")
	}

	if resp != nil {
		serverResp.statusCode = resp.StatusCode
	}

	if serverResp.statusCode < 200 || serverResp.statusCode >= 400 {
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return serverResp, err
		}
		if len(body) == 0 {
			return serverResp, fmt.Errorf("Error: request returned %s for API route and version %s, check if the server supports the requested API version", http.StatusText(serverResp.statusCode), req.URL)
		}

		var errorMessage string
		if (cli.version == "" || versions.GreaterThan(cli.version, "1.23")) &&
			resp.Header.Get("Content-Type") == "application/json" {
			var errorResponse types.ErrorResponse
			if err := json.Unmarshal(body, &errorResponse); err != nil {
				return serverResp, fmt.Errorf("Error reading JSON: %v", err)
			}
			errorMessage = errorResponse.Message
		} else {
			errorMessage = string(body)
		}

		return serverResp, fmt.Errorf("Error response from daemon: %s", strings.TrimSpace(errorMessage))
	}

	serverResp.body = resp.Body
	serverResp.header = resp.Header
	return serverResp, nil
}

func (cli *Client) newRequest(method, path string, query url.Values, body io.Reader, headers map[string][]string) (*http.Request, error) {
	apiPath := cli.getAPIPath(path, query)
	req, err := http.NewRequest(method, apiPath, body)
	if err != nil {
		return nil, err
	}

	// Add CLI Config's HTTP Headers BEFORE we set the Docker headers
	// then the user can't change OUR headers
	for k, v := range cli.customHTTPHeaders {
		req.Header.Set(k, v)
	}

	if headers != nil {
		for k, v := range headers {
			req.Header[k] = v
		}
	}

	return req, nil
}
```

## 总结

Docker Client创建与命令执行整体逻辑也是比较清楚的。就是定义了一堆命令，然后根据命令行参数，找到`cli/command`目录下对应的命令执行，而执行逻辑又一般被转至`client`目录下对应的代码，这里一般都是拼凑一些HTTP请求的URL、参数等，然后使用`client/request.go`定义的方法向`Docker API Server`发送请求得到响应，再对响应进行解码得到对象，命令再对得到的对象进行分析处理，最终打印必要的输出。上面我仅分析了`docker system info`的执行过程，其它命令也很类似。

## 参考

`http://www.kancloud.cn/infoq/docker-source-code-analysis/80526`
`https://github.com/spf13/cobra`
`https://github.com/spf13/pflag`

## 其它

docker的源码看起来倒不是很复杂，但代码的执行逻辑经常跳来跳去，看得比较累，建议还是将它的代码导入IDE，这样跳转比较方便。导入IDE的步骤如下：

```bash
mkdir -p ~/dev/docker/src/github.com/docker
cd ~/dev/docker/src/github.com/docker
git clone https://github.com/docker/docker.git
```

然后在IDEA里新建一个Go的Module，名称为docker, 路径选择~/dev/docker。

最后在IDEA里设置该项目的GOPATH，如下图。

![docker_gopath.png](/images/20161005/docker_gopath.png)

有时看不清楚代码的执行逻辑，打个断点调试一下也是不错的办法，可以在IDEA里建一个运行项目，如下图。

![docker_launch.png](/images/20161005/docker_launch.png)
