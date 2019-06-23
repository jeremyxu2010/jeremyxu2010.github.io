---
title: docker源码分析-Daemon创建及启动
tags:
  - docker
  - golang
categories:
  - 云计算
date: 2016-10-06 04:22:00+08:00
---
上一篇分析了Docker Client的源码运行逻辑，本篇接着分析Docker Daemon的运行逻辑。Docker Daemon的运行逻辑很复杂，大家看着来要有耐心了。

## Docker Daemon的执行

Docker Daemon的入口在`cmd/dockerd/docker.go`，先看main函数。

```
func main() {
	if reexec.Init() {
		return
	}

	// Set terminal emulation based on platform as required.
	_, stdout, stderr := term.StdStreams()
	logrus.SetOutput(stderr)

	cmd := newDaemonCommand()
	cmd.SetOutput(stdout)
	if err := cmd.Execute(); err != nil {
		fmt.Fprintf(stderr, "%s\n", err)
		os.Exit(1)
	}
}
```

跟Docker Client的main函数，只不过加了个是否执行过初始化方法的检查，看了半天，感觉在这里`dockerd`并没有注册对应的初始化方法，因此这里`reexec.Init()`必然返回false，因此这个检查看着很
诡异。

Daemon命令行不存在子命令，就一个根命令，按上一篇的跟踪方法，很快就跟踪到`runDaemon`函数。

```
func runDaemon(opts daemonOptions) error {
	if opts.version {
		showVersion()
		return nil
	}

	daemonCli := NewDaemonCli()

	// On Windows, this may be launching as a service or with an option to
	// register the service.
	stop, err := initService(daemonCli)
	if err != nil {
		logrus.Fatal(err)
	}

	if stop {
		return nil
	}

	err = daemonCli.start(opts)
	notifyShutdown(err)
	return err
}
```

与windows系统相关的代码忽略掉，其实就是创建了一个DaemonCli对象，然后调用`start`方法启动它，因为是个daemon程序，所以这里`start`方法是一个阻塞的方法，一旦它执行完毕，则进行收尾工作。

再看`daemonCli.start`方法，它定义在`cmd/dockerd/daemon.go`里，前面一大段都是读取解析检验参数，就不多说了，这个有个小地方要注意，daemon程序支持将参数写进json文件里，dockerd启动时会将json配置文件里的选项与命令行的选项进行合并。

然后是设置合理的umask以避免创建的文件权限不正确，再然后是设置日志选项、生成pid文件。

```
api := apiserver.New(serverConfig)
```

根据serverConfig创建API Server对象。

```
	for i := 0; i < len(cli.Config.Hosts); i++ {
		var err error
		if cli.Config.Hosts[i], err = dopts.ParseHost(cli.Config.TLS, cli.Config.Hosts[i]); err != nil {
			return fmt.Errorf("error parsing -H %s : %v", cli.Config.Hosts[i], err)
		}

		protoAddr := cli.Config.Hosts[i]
		protoAddrParts := strings.SplitN(protoAddr, "://", 2)
		if len(protoAddrParts) != 2 {
			return fmt.Errorf("bad format %s, expected PROTO://ADDR", protoAddr)
		}

		proto := protoAddrParts[0]
		addr := protoAddrParts[1]

		// It's a bad idea to bind to TCP without tlsverify.
		if proto == "tcp" && (serverConfig.TLSConfig == nil || serverConfig.TLSConfig.ClientAuth != tls.RequireAndVerifyClientCert) {
			logrus.Warn("[!] DON'T BIND ON ANY IP ADDRESS WITHOUT setting -tlsverify IF YOU DON'T KNOW WHAT YOU'RE DOING [!]")
		}
		ls, err := listeners.Init(proto, addr, serverConfig.SocketGroup, serverConfig.TLSConfig)
		if err != nil {
			return err
		}
		ls = wrapListeners(proto, ls)
		// If we're binding to a TCP port, make sure that a container doesn't try to use it.
		if proto == "tcp" {
			if err := allocateDaemonPort(addr); err != nil {
				return err
			}
		}
		logrus.Debugf("Listener created for HTTP on %s (%s)", proto, addr)
		api.Accept(addr, ls...)
	}
```

因为daemon程序可以根据选项监控多个地址，所以上述代码遍历这些地址，也监听了多个地址。

```
registryService := registry.NewService(cli.Config.ServiceOptions)
```

从docker的总体架构得知，daemon程序在pull镜像等操作时，需要与registry服务交互，这里即创建了registryService对象，用于与registry服务交互。registryService对象定义在`registry`目录，这个目录里文件不是太多，逻辑也不是太复杂，暂且略过。总体来说就是实现了下列接口方法，供daemon程序与registry服务交互。

```
type Service interface {
	Auth(ctx context.Context, authConfig *types.AuthConfig, userAgent string) (status, token string, err error)
	LookupPullEndpoints(hostname string) (endpoints []APIEndpoint, err error)
	LookupPushEndpoints(hostname string) (endpoints []APIEndpoint, err error)
	ResolveRepository(name reference.Named) (*RepositoryInfo, error)
	ResolveIndex(name string) (*registrytypes.IndexInfo, error)
	Search(ctx context.Context, term string, limit int, authConfig *types.AuthConfig, userAgent string, headers map[string][]string) (*registrytypes.SearchResults, error)
	ServiceConfig() *registrytypes.ServiceConfig
	TLSConfig(hostname string) (*tls.Config, error)
}
```

回到daemon的start方法，接下来构造了与`docker-containerd`通信的对象`containerdRemote`。

```
containerdRemote, err := libcontainerd.New(cli.getLibcontainerdRoot(), cli.getPlatformRemoteOptions()...)
	if err != nil {
		return err
	}
```

`docker-containerd`是一个控制`runC`的后台程序，其代码在[https://github.com/docker/containerd](https://github.com/docker/containerd)。与`docker-containerd`通信的模块源码在`libcontainerd`目录，这个目录里文件不是太多，简单来说就是提供了下列接口方法，供daemon程序调用以控制管理容器的运行。

```
// Client provides access to containerd features.
type Client interface {
	Create(containerID string, checkpoint string, checkpointDir string, spec specs.Spec, options ...CreateOption) error
	Signal(containerID string, sig int) error
	SignalProcess(containerID string, processFriendlyName string, sig int) error
	AddProcess(ctx context.Context, containerID, processFriendlyName string, process Process) error
	Resize(containerID, processFriendlyName string, width, height int) error
	Pause(containerID string) error
	Resume(containerID string) error
	Restore(containerID string, options ...CreateOption) error
	Stats(containerID string) (*Stats, error)
	GetPidsForContainer(containerID string) ([]int, error)
	Summary(containerID string) ([]Summary, error)
	UpdateResources(containerID string, resources Resources) error
	CreateCheckpoint(containerID string, checkpointID string, checkpointDir string, exit bool) error
	DeleteCheckpoint(containerID string, checkpointID string, checkpointDir string) error
	ListCheckpoints(containerID string, checkpointDir string) (*Checkpoints, error)
}
```

再回到daemon的start方法，接下来声明监听系统的一些终止信号，如监听到这些信息，就停止`DaemonCli`。

```
	signal.Trap(func() {
		cli.stop()
		<-stopc // wait for daemonCli.start() to return
	})
```

再接下来，创建`Daemon`对象，注意创建`Daemon`对象时传入了`registryService`，`containerdRemote`，这个跟docker的总体架构是相符的。

```
	d, err := daemon.NewDaemon(cli.Config, registryService, containerdRemote)
	if err != nil {
		return fmt.Errorf("Error starting daemon: %v", err)
	}
```

`NewDaemon`方法完成的功能较多，下一小节再详细描述，这里还是继续看daemon的start方法。

```
	c, err := cluster.New(cluster.Config{
		Root:                   cli.Config.Root,
		Name:                   name,
		Backend:                d,
		NetworkSubnetsProvider: d,
		DefaultAdvertiseAddr:   cli.Config.SwarmDefaultAdvertiseAddr,
		RuntimeRoot:            cli.getSwarmRunRoot(),
	})
	if err != nil {
		logrus.Fatalf("Error creating cluster component: %v", err)
	}

	// Restart all autostart containers which has a swarm endpoint
	// and is not yet running now that we have successfully
	// initialized the cluster.
	d.RestartSwarmContainers()
```

V1.12版本的docker还集成了swarm的相关功能，这里将自动启动安装有swarm endpoint的容器。

```
	cli.initMiddlewares(api, serverConfig)
```

给API Server注册一些中间件，这些中间件主要进行版本兼容性检查、添加CORS跨站点请求相关响应头、对请求进行认证。

```
func (cli *DaemonCli) initMiddlewares(s *apiserver.Server, cfg *apiserver.Config) {
	v := cfg.Version

	vm := middleware.NewVersionMiddleware(v, api.DefaultVersion, api.MinVersion)
	s.UseMiddleware(vm)

	if cfg.EnableCors {
		c := middleware.NewCORSMiddleware(cfg.CorsHeaders)
		s.UseMiddleware(c)
	}

	u := middleware.NewUserAgentMiddleware(v)
	s.UseMiddleware(u)

	cli.authzMiddleware = authorization.NewMiddleware(cli.Config.AuthorizationPlugins)
	s.UseMiddleware(cli.authzMiddleware)
}
```

再接下来初始化API Server的路由。

```
	initRouter(api, d, c)

...

func initRouter(s *apiserver.Server, d *daemon.Daemon, c *cluster.Cluster) {
	decoder := runconfig.ContainerDecoder{}

	routers := []router.Router{}

	// we need to add the checkpoint router before the container router or the DELETE gets masked
	routers = addExperimentalRouters(routers, d, decoder)

	routers = append(routers, []router.Router{
		container.NewRouter(d, decoder),
		image.NewRouter(d, decoder),
		systemrouter.NewRouter(d, c),
		volume.NewRouter(d),
		build.NewRouter(dockerfile.NewBuildManager(d)),
		swarmrouter.NewRouter(c),
	}...)

	if d.NetworkControllerEnabled() {
		routers = append(routers, network.NewRouter(d, c))
	}

	s.InitRouter(utils.IsDebugEnabled(), routers...)
}
```

可能看到API Server处理的请求主要包括容器、镜像、系统、卷、编译、swarm、网络这几个方法。构建路由时均将`Daemon`对象传入了，也就是说某条路由对应的handler将会调用`Daemon`对象的相关方法进行业务操作，最后向Docker Client输出回应。API Server这些路由对应的Handler在`api/server/router`目录下都可以找到，每个handler逻辑都很简单，就不详细描述了。

再回到daemon的start方法，下面的方法当监听到系统信号`SIGHUP`，就会重新加载daemon程序的配置。

```
cli.setupConfigReloadTrap()
```

再然后创建goroutine使`API Server`开始对外提供服务，并在该goroutine里等待`API Server`停止。`API Server`默认也不会停止，除非主动停止它或出现什么错误，所以这个goroutine是阻塞的。另外`API Server`很有可能是监听多个地址的，所以`serveAPI`方法使用了多个goroutine以调用多个`HTTPServer`的`Serve`方法，并同样阻塞住。

```
	serveAPIWait := make(chan error)
	go api.Wait(serveAPIWait)

func (s *Server) Wait(waitChan chan error) {
  if err := s.serveAPI(); err != nil {
  	logrus.Errorf("ServeAPI error: %v", err)
  	waitChan <- err
  	return
  }
  waitChan <- nil
}

// serveAPI loops through all initialized servers and spawns goroutine
// with Server method for each. It sets createMux() as Handler also.
func (s *Server) serveAPI() error {
	var chErrors = make(chan error, len(s.servers))
	for _, srv := range s.servers {
		srv.srv.Handler = s.routerSwapper
		go func(srv *HTTPServer) {
			var err error
			logrus.Infof("API listen on %s", srv.l.Addr())
			if err = srv.Serve(); err != nil && strings.Contains(err.Error(), "use of closed network connection") {
				err = nil
			}
			chErrors <- err
		}(srv)
	}

	for i := 0; i < len(s.servers); i++ {
		err := <-chErrors
		if err != nil {
			return err
		}
	}

	return nil
}
```

然后调用操作系统的systemd服务，docker的daemon进程已成功启动。
```
	// after the daemon is done setting up we can notify systemd api
	notifySystem()
```

```
	// Daemon is fully initialized and handling API traffic
	// Wait for serve API to complete
	errAPI := <-serveAPIWait
	c.Cleanup()
	shutdownDaemon(d, 15)
	containerdRemote.Cleanup()
	if errAPI != nil {
		return fmt.Errorf("Shutting down due to ServeAPI error: %v", errAPI)
	}

	return nil
```

最后由于上面调用`serveAPI`方法的goroutine阻塞住了，所以`errAPI := <-serveAPIWait`这行代码就会使main goroutine阻塞住了，这样daemon进程就不会退出。一旦阻塞解除了，也就意味着daemon进程需要退出了，这时做一些清理工作。

以上就是Docker Daemon的整体执行逻辑了。

## Docker Daemon的创建

上面一小节里，有一个方法`daemon.NewDaemon(cli.Config, registryService, containerdRemote)`简单地跳过了，但其实这个方法是相当重要的，这里将这个方法详细说明一下。

```
	setDefaultMtu(config)

	// Ensure that we have a correct root key limit for launching containers.
	if err := ModifyRootKeyLimit(); err != nil {
		logrus.Warnf("unable to modify root key limit, number of containers could be limitied by this quota: %v", err)
	}

	// Ensure we have compatible and valid configuration options
	if err := verifyDaemonSettings(config); err != nil {
		return nil, err
	}

	// Do we have a disabled network?
	config.DisableBridge = isBridgeNetworkDisabled(config)

	// Verify the platform is supported as a daemon
	if !platformSupported {
		return nil, errSystemNotSupported
	}

	// Validate platform-specific requirements
	if err := checkSystem(); err != nil {
		return nil, err
	}

	// set up SIGUSR1 handler on Unix-like systems, or a Win32 global event
	// on Windows to dump Go routine stacks
	setupDumpStackTrap(config.Root)
```

首先就是一大段选项、环境的检测调整，代码注释得很清楚，就不多说了。

```
	uidMaps, gidMaps, err := setupRemappedRoot(config)
	if err != nil {
		return nil, err
	}
	rootUID, rootGID, err := idtools.GetRootUIDGID(uidMaps, gidMaps)
	if err != nil {
		return nil, err
	}
```

docker支持用户空间重映射特性，这里就是在解析与之相关的`userns-remap`参数。docker用户空间重映射特性其实就是将容器内的用户映射为宿主机上的普通用户，这个主要是为了加强容器安全的。

```
	// get the canonical path to the Docker root directory
	var realRoot string
	if _, err := os.Stat(config.Root); err != nil && os.IsNotExist(err) {
		realRoot = config.Root
	} else {
		realRoot, err = fileutils.ReadSymlinkedDirectory(config.Root)
		if err != nil {
			return nil, fmt.Errorf("Unable to get the full path to root (%s): %s", config.Root, err)
		}
	}

	if err := setupDaemonRoot(config, realRoot, rootUID, rootGID); err != nil {
		return nil, err
	}

	if err := setupDaemonProcess(config); err != nil {
		return nil, err
	}

	// set up the tmpDir to use a canonical path
	tmp, err := tempDir(config.Root, rootUID, rootGID)
	if err != nil {
		return nil, fmt.Errorf("Unable to get the TempDir under %s: %s", config.Root, err)
	}
	realTmp, err := fileutils.ReadSymlinkedDirectory(tmp)
	if err != nil {
		return nil, fmt.Errorf("Unable to get the full path to the TempDir (%s): %s", tmp, err)
	}
	os.Setenv("TMPDIR", realTmp)
```

接下来对存储目录进行必要的权限调整、对daemon进程的`oom_score_adj`参数进行必要的调整（减小daemon进程被OS杀掉的可能性）、创建临时目录。

```
	d := &Daemon{configStore: config}
	// Ensure the daemon is properly shutdown if there is a failure during
	// initialization
	defer func() {
		if err != nil {
			if err := d.Shutdown(); err != nil {
				logrus.Error(err)
			}
		}
	}()

	// Set the default isolation mode (only applicable on Windows)
	if err := d.setDefaultIsolation(); err != nil {
		return nil, fmt.Errorf("error setting default isolation mode: %v", err)
	}

	logrus.Debugf("Using default logging driver %s", config.LogConfig.Type)

	if err := configureMaxThreads(config); err != nil {
		logrus.Warnf("Failed to configure golang's threads limit: %v", err)
	}

	installDefaultAppArmorProfile()
```

上述代码完成以下几个功能：
  * 创建Daemon对象
  * 如`NewDaemon`方法有任何异常，则退出方法时关闭Daemon
  * 调整进程的最大线程数限制
  * 安装AppArmor相关的配置

```
	daemonRepo := filepath.Join(config.Root, "containers")
	if err := idtools.MkdirAllAs(daemonRepo, 0700, rootUID, rootGID); err != nil && !os.IsExist(err) {
		return nil, err
	}

	driverName := os.Getenv("DOCKER_DRIVER")
	if driverName == "" {
		driverName = config.GraphDriver
	}

	d.pluginStore = pluginstore.NewStore(config.Root)

	d.layerStore, err = layer.NewStoreFromOptions(layer.StoreOptions{
		StorePath:                 config.Root,
		MetadataStorePathTemplate: filepath.Join(config.Root, "image", "%s", "layerdb"),
		GraphDriver:               driverName,
		GraphDriverOptions:        config.GraphOptions,
		UIDMaps:                   uidMaps,
		GIDMaps:                   gidMaps,
		PluginGetter:              d.pluginStore,
	})
	if err != nil {
		return nil, err
	}

	graphDriver := d.layerStore.DriverName()
	imageRoot := filepath.Join(config.Root, "image", graphDriver)

	// Configure and validate the kernels security support
	if err := configureKernelSecuritySupport(config, graphDriver); err != nil {
		return nil, err
	}

	logrus.Debugf("Max Concurrent Downloads: %d", *config.MaxConcurrentDownloads)
	d.downloadManager = xfer.NewLayerDownloadManager(d.layerStore, *config.MaxConcurrentDownloads)
	logrus.Debugf("Max Concurrent Uploads: %d", *config.MaxConcurrentUploads)
	d.uploadManager = xfer.NewLayerUploadManager(*config.MaxConcurrentUploads)

	ifs, err := image.NewFSStoreBackend(filepath.Join(imageRoot, "imagedb"))
	if err != nil {
		return nil, err
	}

	d.imageStore, err = image.NewImageStore(ifs, d.layerStore)
	if err != nil {
		return nil, err
	}

	// Configure the volumes driver
	volStore, err := d.configureVolumes(rootUID, rootGID)
	if err != nil {
		return nil, err
	}

	trustKey, err := api.LoadOrCreateTrustKey(config.TrustKeyPath)
	if err != nil {
		return nil, err
	}

	trustDir := filepath.Join(config.Root, "trust")

	if err := system.MkdirAll(trustDir, 0700); err != nil {
		return nil, err
	}

	distributionMetadataStore, err := dmetadata.NewFSMetadataStore(filepath.Join(imageRoot, "distribution"))
	if err != nil {
		return nil, err
	}

	eventsService := events.New()

	referenceStore, err := reference.NewReferenceStore(filepath.Join(imageRoot, "repositories.json"))
	if err != nil {
		return nil, fmt.Errorf("Couldn't create Tag store repositories: %s", err)
	}
```

再就是创建初始化了一堆与镜像存储相关的目录及Store，有以下几个：
  * `/var/lib/docker/containers` 这个目录是用来记录的是容器相关的信息，每运行一个容器，就在这个目录下面生成一个容器Id对应的子目录。
  * `/var/lib/docker/image/${graphDriverName}/layerdb` 这个目录是用来记录layer元数据的
  * `/var/lib/docker/image/${graphDriverName}/imagedb` 这个目录是用来记录镜像元数据的
  * `/var/lib/docker/image/${graphDriverName}/distribution` 这个目录用来记录layer元数据与镜像元数据之间的关联关系
  * `/var/lib/docker/image/${graphDriverName}/repositories.json` 这个目录是用来记录镜像仓库元数据的
  * `/var/lib/docker/trust` 这个目录用来放一些证书文件
  * `/var/lib/docker/volumes` 这个目录是用来记录卷元数据的

```
	migrationStart := time.Now()
	if err := v1.Migrate(config.Root, graphDriver, d.layerStore, d.imageStore, referenceStore, distributionMetadataStore); err != nil {
		logrus.Errorf("Graph migration failed: %q. Your old graph data was found to be too inconsistent for upgrading to content-addressable storage. Some of the old data was probably not upgraded. We recommend starting over with a clean storage directory if possible.", err)
	}
	logrus.Infof("Graph migration to content-addressability took %.2f seconds", time.Since(migrationStart).Seconds())
```

接下来是一个迁移旧版Graph数据的逻辑。

```
	// Discovery is only enabled when the daemon is launched with an address to advertise.  When
	// initialized, the daemon is registered and we can store the discovery backend as its read-only
	if err := d.initDiscovery(config); err != nil {
		return nil, err
	}
```

如果配置了在集群中向外发布的访问地址，则需要初始化集群节点的服务发现Agent。一般来说就是定时向KV库报告自身的状态及公布访问地址，代码如下：

```
// initDiscovery initializes the nodes discovery subsystem by connecting to the specified backend
// and starts a registration loop to advertise the current node under the specified address.
func initDiscovery(backendAddress, advertiseAddress string, clusterOpts map[string]string) (discoveryReloader, error) {
	heartbeat, backend, err := parseDiscoveryOptions(backendAddress, clusterOpts)
	if err != nil {
		return nil, err
	}

	reloader := &daemonDiscoveryReloader{
		backend: backend,
		ticker:  time.NewTicker(heartbeat),
		term:    make(chan bool),
		readyCh: make(chan struct{}),
	}
	// We call Register() on the discovery backend in a loop for the whole lifetime of the daemon,
	// but we never actually Watch() for nodes appearing and disappearing for the moment.
	go reloader.advertiseHeartbeat(advertiseAddress)
	return reloader, nil
}

// advertiseHeartbeat registers the current node against the discovery backend using the specified
// address. The function never returns, as registration against the backend comes with a TTL and
// requires regular heartbeats.
func (d *daemonDiscoveryReloader) advertiseHeartbeat(address string) {
	var ready bool
	if err := d.initHeartbeat(address); err == nil {
		ready = true
		close(d.readyCh)
	}

	for {
		select {
		case <-d.ticker.C:
			if err := d.backend.Register(address); err != nil {
				logrus.Warnf("Registering as %q in discovery failed: %v", address, err)
			} else {
				if !ready {
					close(d.readyCh)
					ready = true
				}
			}
		case <-d.term:
			return
		}
	}
}

// initHeartbeat is used to do the first heartbeat. It uses a tight loop until
// either the timeout period is reached or the heartbeat is successful and returns.
func (d *daemonDiscoveryReloader) initHeartbeat(address string) error {
	// Setup a short ticker until the first heartbeat has succeeded
	t := time.NewTicker(500 * time.Millisecond)
	defer t.Stop()
	// timeout makes sure that after a period of time we stop being so aggressive trying to reach the discovery service
	timeout := time.After(60 * time.Second)

	for {
		select {
		case <-timeout:
			return errors.New("timeout waiting for initial discovery")
		case <-d.term:
			return errors.New("terminated")
		case <-t.C:
			if err := d.backend.Register(address); err == nil {
				return nil
			}
		}
	}
}
```

再然后就是给Daemon对象的一系列属性赋上值。

```
	d.ID = trustKey.PublicKey().KeyID()
	d.repository = daemonRepo
	d.containers = container.NewMemoryStore()
	d.execCommands = exec.NewStore()
	d.referenceStore = referenceStore
	d.distributionMetadataStore = distributionMetadataStore
	d.trustKey = trustKey
	d.idIndex = truncindex.NewTruncIndex([]string{})
	d.statsCollector = d.newStatsCollector(1 * time.Second)
	d.defaultLogConfig = containertypes.LogConfig{
		Type:   config.LogConfig.Type,
		Config: config.LogConfig.Config,
	}
	d.RegistryService = registryService
	d.EventsService = eventsService
	d.volumes = volStore
	d.root = config.Root
	d.uidMaps = uidMaps
	d.gidMaps = gidMaps
	d.seccompEnabled = sysInfo.Seccomp

	d.nameIndex = registrar.NewRegistrar()
	d.linkIndex = newLinkIndex()
	d.containerdRemote = containerdRemote

	go d.execCommandGC()

	d.containerd, err = containerdRemote.Client(d)
	if err != nil {
		return nil, err
	}
```

首先确保插件系统初始化完毕，然后根据`/var/lib/docker/containers`目录里容器目录还原部分容器、初始化容器依赖的网络环境，初始化容器之间的link关系等。


```
	// Plugin system initialization should happen before restore. Dont change order.
	if err := pluginInit(d, config, containerdRemote); err != nil {
		return nil, err
	}

	if err := d.restore(); err != nil {
		return nil, err
	}

	func (daemon *Daemon) restore() error {
	var (
		debug         = utils.IsDebugEnabled()
		currentDriver = daemon.GraphDriverName()
		containers    = make(map[string]*container.Container)
	)

	if !debug {
		logrus.Info("Loading containers: start.")
	}
	dir, err := ioutil.ReadDir(daemon.repository)
	if err != nil {
		return err
	}

	containerCount := 0
	for _, v := range dir {
		id := v.Name()
		container, err := daemon.load(id)
		if !debug && logrus.GetLevel() == logrus.InfoLevel {
			fmt.Print(".")
			containerCount++
		}
		if err != nil {
			logrus.Errorf("Failed to load container %v: %v", id, err)
			continue
		}

		// Ignore the container if it does not support the current driver being used by the graph
		if (container.Driver == "" && currentDriver == "aufs") || container.Driver == currentDriver {
			rwlayer, err := daemon.layerStore.GetRWLayer(container.ID)
			if err != nil {
				logrus.Errorf("Failed to load container mount %v: %v", id, err)
				continue
			}
			container.RWLayer = rwlayer
			logrus.Debugf("Loaded container %v", container.ID)

			containers[container.ID] = container
		} else {
			logrus.Debugf("Cannot load container %s because it was created with another graph driver.", container.ID)
		}
	}

	var migrateLegacyLinks bool
	removeContainers := make(map[string]*container.Container)
	restartContainers := make(map[*container.Container]chan struct{})
	activeSandboxes := make(map[string]interface{})
	for _, c := range containers {
		if err := daemon.registerName(c); err != nil {
			logrus.Errorf("Failed to register container %s: %s", c.ID, err)
			continue
		}
		if err := daemon.Register(c); err != nil {
			logrus.Errorf("Failed to register container %s: %s", c.ID, err)
			continue
		}

		// verify that all volumes valid and have been migrated from the pre-1.7 layout
		if err := daemon.verifyVolumesInfo(c); err != nil {
			// don't skip the container due to error
			logrus.Errorf("Failed to verify volumes for container '%s': %v", c.ID, err)
		}

		// The LogConfig.Type is empty if the container was created before docker 1.12 with default log driver.
		// We should rewrite it to use the daemon defaults.
		// Fixes https://github.com/docker/docker/issues/22536
		if c.HostConfig.LogConfig.Type == "" {
			if err := daemon.mergeAndVerifyLogConfig(&c.HostConfig.LogConfig); err != nil {
				logrus.Errorf("Failed to verify log config for container %s: %q", c.ID, err)
				continue
			}
		}
	}
	var wg sync.WaitGroup
	var mapLock sync.Mutex
	for _, c := range containers {
		wg.Add(1)
		go func(c *container.Container) {
			defer wg.Done()
			if err := backportMountSpec(c); err != nil {
				logrus.Errorf("Failed to migrate old mounts to use new spec format")
			}

			rm := c.RestartManager(false)
			if c.IsRunning() || c.IsPaused() {
				if err := daemon.containerd.Restore(c.ID, libcontainerd.WithRestartManager(rm)); err != nil {
					logrus.Errorf("Failed to restore %s with containerd: %s", c.ID, err)
					return
				}
				if !c.HostConfig.NetworkMode.IsContainer() && c.IsRunning() {
					options, err := daemon.buildSandboxOptions(c)
					if err != nil {
						logrus.Warnf("Failed build sandbox option to restore container %s: %v", c.ID, err)
					}
					mapLock.Lock()
					activeSandboxes[c.NetworkSettings.SandboxID] = options
					mapLock.Unlock()
				}

			}
			// fixme: only if not running
			// get list of containers we need to restart
			if !c.IsRunning() && !c.IsPaused() {
				// Do not autostart containers which
				// has endpoints in a swarm scope
				// network yet since the cluster is
				// not initialized yet. We will start
				// it after the cluster is
				// initialized.
				if daemon.configStore.AutoRestart && c.ShouldRestart() && !c.NetworkSettings.HasSwarmEndpoint {
					mapLock.Lock()
					restartContainers[c] = make(chan struct{})
					mapLock.Unlock()
				} else if c.HostConfig != nil && c.HostConfig.AutoRemove {
					mapLock.Lock()
					removeContainers[c.ID] = c
					mapLock.Unlock()
				}
			}

			if c.RemovalInProgress {
				// We probably crashed in the middle of a removal, reset
				// the flag.
				//
				// We DO NOT remove the container here as we do not
				// know if the user had requested for either the
				// associated volumes, network links or both to also
				// be removed. So we put the container in the "dead"
				// state and leave further processing up to them.
				logrus.Debugf("Resetting RemovalInProgress flag from %v", c.ID)
				c.ResetRemovalInProgress()
				c.SetDead()
				c.ToDisk()
			}

			// if c.hostConfig.Links is nil (not just empty), then it is using the old sqlite links and needs to be migrated
			if c.HostConfig != nil && c.HostConfig.Links == nil {
				migrateLegacyLinks = true
			}
		}(c)
	}
	wg.Wait()
	daemon.netController, err = daemon.initNetworkController(daemon.configStore, activeSandboxes)
	if err != nil {
		return fmt.Errorf("Error initializing network controller: %v", err)
	}

	// migrate any legacy links from sqlite
	linkdbFile := filepath.Join(daemon.root, "linkgraph.db")
	var legacyLinkDB *graphdb.Database
	if migrateLegacyLinks {
		legacyLinkDB, err = graphdb.NewSqliteConn(linkdbFile)
		if err != nil {
			return fmt.Errorf("error connecting to legacy link graph DB %s, container links may be lost: %v", linkdbFile, err)
		}
		defer legacyLinkDB.Close()
	}

	// Now that all the containers are registered, register the links
	for _, c := range containers {
		if migrateLegacyLinks {
			if err := daemon.migrateLegacySqliteLinks(legacyLinkDB, c); err != nil {
				return err
			}
		}
		if err := daemon.registerLinks(c, c.HostConfig); err != nil {
			logrus.Errorf("failed to register link for container %s: %v", c.ID, err)
		}
	}

	group := sync.WaitGroup{}
	for c, notifier := range restartContainers {
		group.Add(1)

		go func(c *container.Container, chNotify chan struct{}) {
			defer group.Done()

			logrus.Debugf("Starting container %s", c.ID)

			// ignore errors here as this is a best effort to wait for children to be
			//   running before we try to start the container
			children := daemon.children(c)
			timeout := time.After(5 * time.Second)
			for _, child := range children {
				if notifier, exists := restartContainers[child]; exists {
					select {
					case <-notifier:
					case <-timeout:
					}
				}
			}

			// Make sure networks are available before starting
			daemon.waitForNetworks(c)
			if err := daemon.containerStart(c, ""); err != nil {
				logrus.Errorf("Failed to start container %s: %s", c.ID, err)
			}
			close(chNotify)
		}(c, notifier)

	}
	group.Wait()

	removeGroup := sync.WaitGroup{}
	for id := range removeContainers {
		removeGroup.Add(1)
		go func(cid string) {
			if err := daemon.ContainerRm(cid, &types.ContainerRmConfig{ForceRemove: true, RemoveVolume: true}); err != nil {
				logrus.Errorf("Failed to remove container %s: %s", cid, err)
			}
			removeGroup.Done()
		}(id)
	}
	removeGroup.Wait()

	// any containers that were started above would already have had this done,
	// however we need to now prepare the mountpoints for the rest of the containers as well.
	// This shouldn't cause any issue running on the containers that already had this run.
	// This must be run after any containers with a restart policy so that containerized plugins
	// can have a chance to be running before we try to initialize them.
	for _, c := range containers {
		// if the container has restart policy, do not
		// prepare the mountpoints since it has been done on restarting.
		// This is to speed up the daemon start when a restart container
		// has a volume and the volume dirver is not available.
		if _, ok := restartContainers[c]; ok {
			continue
		} else if _, ok := removeContainers[c.ID]; ok {
			// container is automatically removed, skip it.
			continue
		}

		group.Add(1)
		go func(c *container.Container) {
			defer group.Done()
			if err := daemon.prepareMountPoints(c); err != nil {
				logrus.Error(err)
			}
		}(c)
	}

	group.Wait()

	if !debug {
		if logrus.GetLevel() == logrus.InfoLevel && containerCount > 0 {
			fmt.Println()
		}
		logrus.Info("Loading containers: done.")
	}

	return nil
}
```

至此Daemon对象就创建成功了。

## 总结

Docker Daemon的运行逻辑属于Docker的核心，它相关的组件很多，代码理起来很复杂，但如果仔细看还是能看明白它的条理的。

另外在看docker源码的过程中发现docker中有三块还是比较有意思的，这三块分别是：容器的创建与启动过程、镜像的存储过程、容器网络的创建过程。后面抽空将这三部分也写个文档分析一下。

## 参考

`http://www.kancloud.cn/infoq/docker-source-code-analysis/80527`
`http://www.kancloud.cn/infoq/docker-source-code-analysis/80528`
`http://www.kancloud.cn/infoq/docker-source-code-analysis/80529`
`http://www.aboutyun.com/thread-16811-1-1.html`
`http://pipul.org/2016/03/how-docker-image-stored-on-aufs-filesystem/`
`http://yihongwei.com/2015/10/docker-volume-plugin/`



