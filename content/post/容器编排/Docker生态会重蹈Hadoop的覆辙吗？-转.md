---
title: Docker生态会重蹈Hadoop的覆辙吗？(转)
tags:
  - docker
  - hadoop
categories:
  - 容器编排
date: 2016-08-28 22:23:00+08:00
---
docker最近一年可真是火，不过刚好看到下面这篇文章，觉得还是很有道理的。转载过来研读并思考一下，转载自[这里](http://mp.weixin.qq.com/s?__biz=MzA5NDg3ODMxNw==&mid=2649535024&idx=1&sn=5e15a1afd3adfd3dca538c688e28d1e2&scene=1&srcid=0823tcjhhk21e4dFuI7CT3Iu)。

---

## Docker的兴起和Hadoop何其相似

2015年说是Docker之年不为过，Docker热度高涨，IT从业人员要是说自己不知道Docker都不好意说自己是做IT的。2016年开始容器管理、集群调度成为热点，K8s开始成为热点。但这一幕和2013年的Hadoop大数据何其相似，当年你要说自己不知道大数据，或是知道大数据不知道Hadoop，那必然招来鄙视的眼光。

云计算喊了这么久，从来没有像Docker这么火过，究其原因不外乎两条：

1、开发者能够用Docker，开发者要一个开发环境，总会涉及到种种资源，比如数据库，比如消息中间件，去装这些东西不是开发人员的技能，是运维人员的技能。而用Docker去Pull一个mySQL镜像,或是Tomcat镜像，或是RabbitMQ镜像，简易轻松，几乎是零运维。做好了应用代码，打一个Docker镜像给测试或是运维人员，避免了从前打个程序包给测试或是运维人员，测试或运维人员要部署、配置应用，还得反反复复来麻烦开发人员，现在好了，丢个Docker镜像过去，让运维人员跑镜像就可以，配置在镜像里基本都做好了。

这正好满足了DevOps的要求，所以DevOps也一下热起来了。开发者是一个巨大的市场，是海量的个体，通过类似于病毒式的传销，Docker一下在开发者中热起来了。

2、镜像仓库和开源，谁都可以用，Docker镜像库非常丰富，谁做好一个镜像都可以往公有仓库推送，开发人员需要一个环境的时候，可以到Docker镜像仓库去查，有海量的选择，减少了大量无谓的环境安装工作。而通过开源，又开始大规模传播。

我们再来回顾看看2010-2013年，大数据的名词火遍大江南北，各行各业都在谈大数据，但是落到技术上就是Hadoop，还记得2012年的时候，和Hadoop没啥毛关系的VMWare也赶紧的做了一个虚机上部署Hadoop的serengeti，谁家产品要是和Hadoop不沾点边，不好意思说自己是IT公司。Hadoop当年的热度绝对不亚于2014-2015的Docker。而且时间上有一定的连续性，2014年开始，Hadoop热度达到顶点，开始逐渐降温，标志事件就是Intel投资Cloudera。而Docker是从2014年开始热度升高的。

再看Hadoop为何在2010年前后开始热起来，之前的大数据都是数据仓库，是昂贵的企业级数据分析并行数据库，而Hadoop是廉价的大数据处理模式，通过开源和X86廉价硬件，使得Hadoop可以大规模使用，而互联网时代产生的海量数据虽然垃圾居多，但是沙里淘金，也能淘出点价值，Hadoop正好迎合了这两个需求，虽然Hadoop的无论是功能还是性能远比MPP数据库差，但做简单的数据存储、数据查询、简单数据统计分析还是可以胜任的，事实上，到目前为止，大多数的Hadoop应用也就是数据存储、数据查询和简单的数据统计分析、ETL的业务处理。

Docker和Hadoop的热起来的原因不同，但是现象是差不多，开源和使用者群体大是共同要素。

## Hadoop从狂热走向了理性

Hadoop最热的时候，几乎就是要replace所有数据库，连Oracle也面临了前所未有的冲击，甚至Hadoop成了去IOE的Oracle的使命之一。在狂热的那个阶段，客户怎么也得做一两个大数据项目，否则会被同行瞧不起，各IT厂商也必须推出大数据产品，否则可能成为IT过时的典范，这不IBM成立了专门的大数据部门，打造了一个以Hadoop为核心的庞大的大数据解决方案。Intel虽然是做芯片的，但是大数据必须掺和，成立大数据部门，做Intel Hadoop 。连数据库的老大Oracle也憋不住了，做了个大数据一体机。

任何曾经狂热的新技术都会走向理性，Hadoop也不例外，只不过，这个进程还比较快。随着大数据的大跃进，随着Hadoop的应用越来越多，大家发现在被夸大的场景应用大数据效果并不好，只在特定场景有效，Hadoop进入理性发展阶段，比如一开始Hadoop据取代MPP数据库，取代数据仓库，取代Oracle，完美支持SQL等等均基本成为泡影。这其实本来是一个常识，任何技术都有其应用场景，夸大应用场景，任意扩展应用场景只会伤害这个技术的发展。

这和目前无限夸大Docker的应用场景有异曲同工之妙，比如Docker向下取代虚拟化，Docker向上取代PaaS之类，几乎成了云计算的唯一技术，这种论调一直充斥各种Meetup/论坛。虽然技术从夸大到理性需要时间，但是理性不会总是迟到。

Hadoop技术在发展，大数据的相关技术也在发展，Hadoop一直被诟病的处理速度慢，慢慢的被Spark/Storm等解决，特别在流数据处理领域。

所以，时至今日，人们对Hadoop的态度趋于理性，它只适合在特定场景使用，可是，当初那些在Hadoop不太适用的场景使用了Hadoop的客户交了学费的事情估计没人再提了。Docker估计也是一样的，总有在夸大的场景中交学费的客户，可是只是客户没眼光吗？和无限夸大某种技术的布道师无关么？

再反观大数据和Docker在全球的发展，在美国，无论是Hadoop和Docker并没有像国内这么狂热过。Hadoop技术来源于Google，成型于Yahoo(DougCutting)，而炒作却是在国内。同样，Docker也在走这么个流程，在美国没有这么多的Docker创业公司，主要就是Docker，然后各大厂商支持，创业公司和创投公司都知道，没有自己的技术或是技术受制于人的公司不值得投资，既然Docker一家独大，再去Docker分一杯羹会容易吗？

而国内二三十家的Docker创业公司，没有一家能对Docker/K8s源码有让人醒目的贡献(反倒是华为在K8s上有些贡献)，但是都在市场上拼嗓门，不是比谁的技术有潜力最有市场，而是比谁最能布道谁嗓门大，谁做的市场活动多，某Docker创业公司据说80%的资金用在市场宣传、Meetup上，而且不是个别现象，是普遍现象。反应了某些Docker创业者的浮躁心态。

## Hadoop生态圈的演进

Hadoop兴起和生态圈紧密相关，Hadoop的生态圈的公司主要是两大类:第一类是Hadoop的各个发行版公司，如Cloudera、HortonWorks、MapR、Intel、IBM等，第二类基于Hadoop做各行业的大数据项目实施或大数据应用和工具，如Tableau、Markerto、新炬、环星等

随着大数据的热度提升，Hadoop生态圈的两大类公司蓬勃发展，但是市场有限，市场还没有成熟，竞争就很激烈，特别是第二类做项目实施的企业，那就只能靠烧钱。

问题是如果是消费者市场，通过烧钱先把市场占领，然后再通过其他手段收费盈利，比如淘宝通过向卖家收费盈利，滴滴打车之类的未来可以通过让司机花的米抢好单、大单可以实现盈利，而Hadoop是企业级市场，通过亏钱树立案例标杆，然后复制，这条路走的并不顺利，因为复制案例的时候会碰到竞争，一开始就低价做烂的市场，客户不愿花钱，总有低价者抢市场，复制案例往往变成低价竞争。低价竞争很难把项目实施好，基本是个多输的模式，客户并没有得到自己预期的大数据项目价值，或是打折的价值，实施厂商没赚钱，留不住人，招不到好的人才。

这类生态圈公司的发展趋势是最终会留下少数几家公司，规模做大，其他的公司会被淘汰，现在还没有走出各个集成商苦苦支撑的时代。

对于第一类做发行版的Hadoop厂商，在烧钱进入后期阶段，日子也开始不好过，因为项目实施厂商的大多选择不用发行版，只用开源，发行版和相应的付费支持很难卖出量，进而难以盈利。资本市场成了继续烧钱的救命稻草，Hortonworks第一个上市， 16元的发行价，大数据概念蜜月期一过，要开始考察业绩的时候，股价步入漫漫熊途，到现在只有9元左右。CloudEra虽然没有上市，但是已经融资12亿美元，目前在Hadoop发行版，CloudEra和Hortonworks占据了最大的市场，特别是CloudEra的市场更大，即使CloudEra有巨大的Hadoop市场和技术优势，CloudEra到现在也不敢上市。

现实很残酷，CloudEra的盈利并不让人满意，现在上市，资本市场不会给出个好股价，但是CloudEra的困境是如果迟迟不上市，大数据热点成为非热点，资本市场那就考察的是盈利能力—市盈率，不是市梦率了，而CloudEra的盈利能力在目前状态能让资本市场满意吗？虽然Hortonworks上市的时候赶上了市梦率。

技术的演进同样在影响发行版的Hadoop厂商，Hadoop从1.0到2.0，技术有较大的改进，Yarn取代Map-Reduce，原来众多的发行版面临着自己对Hadoop 1.0的定制如何合并到Hadoop 2.0去的问题，定制的越多，合并的难度越大；定制的越少，和开源没啥区别，体现不出价值，这是发行版面对的两难问题。

Hadoop 1.0到2.0的升级成为一个重要的转折点--- Hadoop从1.0到2.0直接导致Intel的发行版出局，Intel的Hadoop部门裁撤销，Intel废弃自己的Hadoop转而直接投资CloudEra。因为Intel对Hadoop 1.0做了很多的定制、优化，这些定制优化本来一直是Intel宣称的竞争技术优势，现在1.0到2.0,立马优势变劣势，定制越多合并到新版本越难合并，而Hadoop不是Intel的主业，所以Intel权衡利弊，及时止损，放弃了自家的Hadoop，选择投资CloudEra。对Intel Hadoop客户而言，要吸取的教训是买产品一定要买卖家的核心产品，即使是大卖家，其边缘产品很容易被抛弃，受伤的是客户。这个道理其实是个大概率道理，可是吃这种亏的客户不会绝迹。

Hadoop发行版厂商面临一样的趋势潮流——留下不超过3家Hadoop发行商，其他的都会被淘汰。

再看大数据的应用和生态圈的公司，云端营销服务公司Marketo,13元的IPO价格，趁着大数据的东风，很快就飞到了45，随后熊途漫漫，在2016年2月份跌破发行价。和HortonWorks相比，Marketo是大数据的应用，是能通过大数据直接产生营收的，而且业绩也确实比Hortonworks要好，但是回天无力，持续亏损，随后被私募公司Vista Equity Partners收购。Tableau其实和Hadoop关系不大，当初接Hadoop东风股价飙起，现在也是熊途漫漫。

## Docker的生态圈

历史不会简单的重复，但是有惊人的相似!

Docker的生态圈和Hadoop的生态圈类似。

Docker的生态圈也分为两大类，第一类就是Mesosphere、Google这类做Docker的企业运行集群管理，类似于Hadoop的发行版的厂商。第二类是做Docker的项目实施或是做Docker开发者公有云，类似于Hadoop的项目实施厂商。

Docker的流行开始于开发者，也是在开发者中传播，真正进入企业级生产系统的很少，由于Docker天生就是从开发者起家的，缺乏进入企业的基因，Docker的设计就不是运行于企业级环境下。

可是从开发者身上很难赚钱，这已经成为共识了，如果想从开发者身上赚钱，那开发者都跑路了。Docker也意识到这点，所以Docker在2016开年就提出，要进入企业级—“Ready for Production”，但是理想是理想，理想和现实之间需要跨越巨大的鸿沟。

Docker进入企业级的需求，造就了第一类的生态公司，主要就是Mesosphere、Google和Redhat三家，Mesos本来就是部署、集群管理，之前部署Hadoop大数据、批处理、ETL之类的，随着Docker东风吹来，马上支持部署、管理Docker集群，再加一个Marathon管理长周期任务,就可以实现部署应用的CaaS，虽然离PaaS还有很大距离，缺乏很多PaaS功能。

首先要深刻理解PaaS。

PaaS的P是Application Platform，是应用平台As a Service，是着眼于应用和应用平台。

很多人往往把PaaS和CaaS混淆，Container As A Service是容器即服务，只管提供容器和容器管理，并不管容器里面跑的是应用还是数据库或是数据应用，所以CaaS要弄出个编排，而PaaS并无编排一说。如果只是提供容器，和IaaS其实并没有太大的区别，只不过把应用从虚机转移到容器里来。

PaaS的设计原理和方法论是要实现应用的零运维，通过平台本身来监控应用，而不是传统的思维方式，传统的运维是要针对不同的应用去不同的监控、不同的调度、不同的故障恢复，所以运维成了救火。

PaaS通过平台本身来监控应用、监控容器、监控虚机、监控物理机，应用不用去管监控的事情，无论是应用故障、容器故障、虚机故障还是物理机故障，统统故障自动恢复，应用实现一键部署，资源实现弹性伸缩。运维的三大任务：应用和系统部署、升级，故障恢复，根据业务的资源分配，这三大任务在PaaS全自动化。

当然，要达到这个目标，你的应用要符合十二要素，要向云原生应用靠近。退一步讲，即使是传统应用，不做改造，搬到PaaS下虽然不能100%达到上述的零运维，但是也可以达到相当程度的运维自动化。

PaaS和CaaS的另外一个根本区别是，PaaS区别对待应用和服务，应用运行在容器中，实现零运维。服务就是比如数据库、消息中间件、大数据、缓存等，并不适合运行于容器中，PaaS把这些服务部署在虚机中，服务的弹性伸缩要求并不强，不像应用弹性伸缩的要求比较强，谁会去把一个mySQL或是Oracle数据库的集群在运行中弹性扩展一下？

服务没必要放在容器中，服务更多的是需要备份、调优等操作系统相关的运维，而且往往会涉及到操作系统内核的调优，而应用是往往操作系统无关了，所以放在容器中。在容器中做操作系统内核参数调优是有风险的。通过区分应用和服务，并且把应用放在容器中，服务放在虚机中，自然的消除了编排的需求。容器是个革新性的技术，但是不是任何场合都适用，作用企业应用，应当在不同的场景选择不同的技术，而不是一个技术包揽全部。

 Borg是谷歌公司很早以前就在使用的内部容器管理系统，随着Docker的兴起，把Borg的精华部分抽取出来，支持Docker，弄出了个Kubernetes，但是Kubernetes出生于复杂的Borg系统，框架就比较大，而且复杂，而Docker进入企业，总是从小到大的过程，企业和互联网公司不一样，互联网公司可能经过几年的积累，已经有成千上万个容器需要管理，而且运维人员就是公司的主要资源。对于企业公司而言，把Docker弄到生产环境，都是尝试性的，一开始就弄一个超复杂的系统，哪个企业都吃不消，所以Kubernetes进入企业之路并不顺利。

特别是国内，在2015年大多第二类公司Docker项目集成公司都选择Mesos，毕竟Mesos简单易上手，一般客户也要不了Kubernetes那么复杂的功能来管理一个初始的小集群，所以在2015年国内鲜有采用Kubernetes的企业客户，当然2016年形势逆转，K8s成为热点了，因为大家发现Mesos不是正宗的Docker集群管理，K8s从一开始就定位到容器集群管理，虽然技术复杂了一点，但是2016的Docker生态圈创业公司很多是海归，更从技术根源上认可K8s对Docker的集群管理，加上这些创业公司不遗余力的宣传，K8s在2016年逆袭了，成为最热的Docker集群管理软件，这其实也说明了技术最终能够被发现。

而Redhat就直接用kubernetes加一些自己的功能来做PaaS云解决方案。Redhat自己宣传也是Docker+kubernetes=Openshift，那Redhat的Openshift其实自己可以掌控的东西很少，把几个不是自己主导的开源的产品组合成一个OpenShift，和国内的山寨思想没什么太大区别，也体现不出自己的价值，既然是山寨思想，那山寨的害处马上就体现出来了，一旦正宗的产品推出来，山寨之路就艰难了，而且OpenShift又是Redhat的边缘产品，记住前面的法则：买产品一定要买公司的核心产品。

Docker第二类生态公司，做企业Docker项目实施的，在国内众多，包括：DaoCloud、数人云、CSphere、云雀、迅达云、高伟达、宇信、飞致云、时速云等，其中有些一开始尝试做开发者公有云PaaS，但都证明不能盈利，这其实已经在新浪、盛大公有云证明是不成功的，有多少开发者或是中小软件公司愿意花钱在公有云上开发呢？这个市场还太小，不足以养活开发者公有云。

## Docker公司的战略野心受生态圈狙击

Docker本来是做PaaS的公司，原来称为DotCloud, 其提供了类似IDC的服务，为客户提供PaaS服务，包括Web、Application、Transaction、Database等服务。但PaaS云运营并不成功，DotCloud痛定思痛，技术转型到做容器，而且一开始就开源，吸引大量的开发者使用。

随着Docker在开发者中越来越流行，2013年10月，DotCloud干脆换名为Docker公司，2014年8月 Docker 宣布把平台即服务的业务「dotCloud」出售给位于德国柏林的平台即服务提供商「cloudControl」，Docker开始专心致志做Docker。

于此同时，Docker也开始融资准备把公司做大，适应Docker的发展势头。Docker从2013年开始，经过ABCD四轮融资，累计超过1.5亿美元的融资，Docker融资这么多，那么一定要上市IPO，才能给投资方以回报。而上市是需要业绩的，既然开发者市场是几乎不可能赚钱盈利，只能转向企业级市场，一旦启动进入企业级市场的进程，就必然会挤压Docker生态圈的第二类厂商——做Docker集群管理的厂商们。

Docker进入企业环境，第一个就是要运行Docker镜像，而且不是一个两个镜像，要运行一个集群，这样Docker集群的部署、管理、调度就成为Docker进入企业级第一需求。

如下图是Docker的发展历程，下面是Docker容器的进展，上面是CaaS(Container As a Servie)解决方案的并购和进展。有心人很容易发现，从2014年底开始，Docker密密麻麻的收购，全都投入在CaaS，无论是收购还是从产品到解决方案，可见Docker在CaaS上了大赌注。

![docker_growup.png](http://blog-images-1252238296.cosgz.myqcloud.com/docker_growup.png)

Docker进入企业级市场有比较宏大的目标，2014年10月，Docker收购持续集成服务商 Koality，Docker把Koality在企业市场方面的成熟经验引入到 Docker Hub企业版本中，瞄准的是企业市场。同月，Docker收购了总部位于伦敦的Orchard Laboratories，进入复杂应用编排功能的企业市场。2014年底推出Docker Machine、Swarm、Compose,　2015年对这三个产品持续升级。

2015年3月，Docker收购SDN公司SocketPlane,解决Docker集群的网络问题。同月Docker收购了用于Docker管理的开源图形用户界面工具Kitematic，自动化了Docker安装和配置过程。2015年 10年，Docker收购Tutum，补充Docker Hub，补充对Docker运行时的支持。进入2016年，Docker再次动作频频，2016年1月，Docker收购Unikernel Systems,进入OS领域，把Docker容器带入最简OS内核。如下图，打造适合运行容器的最简OS, 整个容器所占的资源进一步减少，从而让机器跑的更快，把容器的价值发挥到极限，至于这是否适合企业应用还需要验证。

![docker_os_kernel.png](http://blog-images-1252238296.cosgz.myqcloud.com/docker_os_kernel.png)

向下，Docker侵入OS领域，向上，Docker挤占CaaS市场空间。

2016年3月，Docker收购Conductant，入主Aurora，根据如下Docker的规划，Aurora直接和kubernetes以及Marathon竞争，特别是和Mesos的架构完全对应， Docker Aurora+Swarm直接和Marathon+Mesos竞争。使得Docker Swarm从小规模集群管理，扩展到大规模Docker集群管理。

![docker_arch1.png](http://blog-images-1252238296.cosgz.myqcloud.com/docker_arch1.png)

![docker_arch2.png](http://blog-images-1252238296.cosgz.myqcloud.com/docker_arch2.png)

在这个Docker提供架构图，可以清楚的看到没有了Mesos,而是Docker Swarm+Aurora直接取代Mesos+Marathon。同时，看看下面来自[Docker的博客](https://blog.docker.com/2016/03/docker-welcomes-aurora-project-creators/)

 “There are manycommercial distributions of Mesos, but none of them incorporate Aurora. Webelieve that is a wasted opportunity. We plan on incorporating the best ideasfrom Aurora into Docker Swarm, and are exploring integrating Aurora as anoptional component of the official Docker stack.”

翻译过来：

“虽然Mesos拥有多款商业发行版，但其中没有任何一款受到Aurora的启发。我们认为这实在是一种巨大的浪费。我们计划将Aurora中的各类卓越思维成果引入Docker Swarm，并正在尝试将Aurora作为Docker正式堆栈的可选组件之一。”

Docker已经在抱怨有太多的Mesos商业发行版，搭了Docker便车，已经在赚Docker进入企业级市场的钱，而Docker自己的产品居然还没开始赚钱。

是可忍孰不可忍！

2016年2月，Docker公布了其DDC(Docker DataCenter)的架构图和报价，如下图，蓝色部分是Docker的CaaS解决方案，青色部分是还需要第三代的产品或开源产品来补充形成完整的解决方案，青色部分所占比例还不小，可见Docker的CaaS上要走的路还很长，Docker的这个CaaS有不少模块是前面收购来的。既然是商业发行版，DDC也保留了部分模块不开源，走的甚至比CloudEra的发行版更远。Docker也很快给了个并不便宜公共订阅报价，难道是Docker在盈利上有急切的需求？

![docker_arch3.png](http://blog-images-1252238296.cosgz.myqcloud.com/docker_arch3.png)

## Docker生态圈的演进

Docker在2013-2014年专注于把容器做好，没来得及顾得上企业级市场，Mesosphere和Google瞄上了这个市场，同时Redhat也把自己的PaaS推倒重来，准备用Docker+kubernetes。2014年底，Docker已经准备进入企业级市场，推出Docker Machine,Swarm和Compose。

Docker作为Docker的宗主，着眼于Docker市场环境最有利润的Docker生产环境集群管理是很自然而然的，我们再来分析这个市场三只早起的鸟儿：Google、Mesosphere、Redhat。

一旦Docker进入企业级CaaS市场，Google第一个就感受到了这个压力。

Google无疑是最有技术敏锐性和市场敏锐性的，早早的看到了Docker企业级市场的企图心，所以Google是第一个支持Docker的竞争对手----CoreOS的Rocket容器，2014年四月份谷歌风险投资公司牵头对CoreOS进行了1200万美元的投资，目标明确---对准docker。Google不再是Docker+ kubernetes,而是容器抽象+ kubernetes。

Google对容器层进行了抽象，使得kubernetes即能支持Rocket,也能支持Docker,而Rocket和Docker有很大的不同，kubernetes对此进行了折中，不再对所以的Docker的功能支持，只支持kubernetes抽象出的容器功能，如果Docker自己的功能不在kubernetes抽象的容器功能之中，kubernetes选择不支持。最典型的是libnetwork/CNM，kubernetes认为这是Docker的特定功能，不予支持，Google自己搞了一个CNI。所以kubernetes和Docker走在分道扬镳的路上，距离越来越远。

除了支持CoreOS，Google更是联合容器业界相关的厂商,组成OCI(Open Container Initiative)。业界对Docker在容器领域一家把控早有怨言，所以OCI一成立，就得到热烈响应。和普通的联盟或标准化组织不一样，OCI成立之初就定下目标—容器标准化，包括容器引擎的标准化实现—RunC，定个标准化规范容易给各方钻空子，但是做一个标准化的实现，就可以在相当程度上实现真正的容器统一。Docker眼看OCI实在太热烈，不得不折中考虑，加入OCI，实现RunC。

但是总是心有不爽，虽然RunC发展很快Docker从1.11开始就采用了RunC的引擎，但是这不就开始和Google也业界大佬开撕了，过程很简单，Kubernetes的KelseyHightower说不要Docker引擎就可以跑Docker镜像，Docker CTO Solomon Hykes马上说，不用Docker引擎， 10%的运行会有问题，然后就扯到OCI，Docker说OCI是个伪标准，立马得到无数的砖头。

Docker也加入了OCI，对RunC的贡献也不小，现在出尔反尔，现在看到Docker可能会受OCI/RunC的牵制影响，立马不管脸面了，利益第一。

但是技术潮流是无法一家控制的，OCI/RunC作为业界各大厂商制约Docker的标准迟早会越发展越好，容器并不是什么可以垄断性的技术，或者说容器本身的技术含量并没有高到其他厂商做不好，只不过Docker在合适的时间点点燃了一个干柴烈火的市场。

关于开撕的细节，大家可以看：

`http://mp.weixin.qq.com/s?\_\_biz=MzI3OTEzNjI1OQ==&mid=2651492692&idx=1&sn=e24efbcc6dcc5ce50773c505a13ccab9&scene=1&srcid=0801BkQ10pDA18gQEy39nObK\#wechat\_redirect`

Google对Docker容器的制约，不止体现在OCI容器层面，这不，前两天Google宣布和Mirantis的合作，K8s直接支持OpenStack，意味着K8s除了可以管理容器，还会延伸到管理虚机集群，在这个架构下，Google弱化Docker容器的的意图很明显。

由于Google早早的对容器进行抽象，可以预见，即使脱离Docker生态圈，kubernetes依然有其市场，而且主要是大型容器和虚机部署的市场。

再说Mesosphere。2016年上半年迟钝的Mesosphere终于意识到Docker的野心和意图，开始尝试脱离Docker，在新的Mesos Containerizer中支持脱离Docker Daemon建立容器，为下一步支持Rocket/RunC做准备。

Mesosphere相当于而言是比较不敏感的，一直跟着Docker跑，即使在Docker要做Swarm时，而且Docker已经做了Swarm仍然不敏感，终于Docker已经明确的对Mesosphere通过发行版赚钱表示了明显的不满，可以理解，Docker自己花这么多资源做出一个Docker和相应生态，还没开始赚钱，搭车的先赚钱了，换谁谁也不乐意。2016年2月Docker发布DDC(Docker DataCenter)和报价,已经非常明确了Docker要进入企业级市场。

2016年上半年迟钝的Mesosphere终于意识到Docker的野心和意图，开始尝试脱离Docker，在新的Mesos Containerizer中支持脱离Docker Daemon建立容器，为下一步支持Rocket/RunC做准备。

Docker进入企业级市场，第一个碾压的就是Mesosphere。一方面Docker通过收购Conductant获得Aurora，未来必定会合并到DDC中，DDC完全可以覆盖Mesosphere的DCOS在Docker集群管理上的功能，而且Docker还有一招，未来只提供Swarm的API，封闭或是大幅改变Docker API，那么Mesos就只能调Swarm的API，Swarm本来就和Mesos有很大的重叠，如果Mesos再通过Swarm去管理Docker集群，那Mesos的价值可能小于功能重叠带来的复杂性。当然Docker是否会祭出这个大招让我们拭目以待，虽然在Docker的新的架构图已经有此规划。

在这种生态环境下，用户的选择是最难的，已经选择了Docker+Mesos的用户，必然会面临未来继续走Docker+Mesos的路，还是壮士断腕，切换到正宗的Docker DDC，但DDC还不成熟，目前阶段还不适合选择。

而Docker+Mesos是注定未来很难升级，越往后越边缘化。

再看Redhat，2014年的时候看到Docker火起来，Redhat见异思迁，马上抛弃自己的OpenShift V2的整体架构，包括抛弃原有应用容器Gear，全面采用Docker替代Gear，同时用kubernetes替代原有的容器管理。如此革命式的改造，完全不考虑前后的兼容性。

这导致已经部署在OpenShift V2的应用迁移到OpenShift V3非常困难，虽然提供了一个迁移工具，但是Redhat自己都不敢用，到目前为止，Redhat的OpenShift公有云还是OpenShift V2，在给客户推销OpenShift V3的时候自己不从V2升级到V3，一定是难度极大，否则拼了命也要升级，”自己的狗粮自己得吃”。

Redhat在OpenShift V3技术架构的选择显得鲁莽，核心技术是Docker和kubernetes,而Redhat对这两个技术都没有掌控，一旦Docker的发展或是kubernetes的发展和自己的战略目标不一致，可能还得推倒重来，又是一次”见异思迁”，目前就实际的遇到了这个问题，Docker要发展自己的DDC，和kubernetes竞争,而kubernetes已经对容器进行了抽象，不再支持Docker的特定功能，Docker和kubernetes已经处于分道扬镳的阶段，未来只会越走越远，而Redhat“只能眼睁睁的看着你却无能为力”，即无法说服Docker，也无法影响Google。

另外，既然Docker要进入企业级容器集群管理市场，那OpenShift就必然和Docker存在竞争，Docker因为绝对的掌控了Docker容器，在竞争中有天然的优势，这种优势随着Docker的升级和DDC的升级会与日俱增。到底是选择正宗(奥迪)还是山寨(奥拓)，客户也容易陷入困惑。

## 开源技术也需要商业的成功

开源不等于免费，开源是一种商业模式，一个开源组织和开源项目要想生存下去，最重要的基础就是普遍被使用，不然很快就会被竞争者替代。

一个软件被普遍被使用之后，还需要因此衍生出相关服务，团队可以通过这些服务获得比较好的收入，商业模式就成型了，没有商业的支持的开源是很难成为一个成熟、商业可用的技术。就拿Linux来说，Redhat和Suse Linux作为比较成功的Linux商业化，通过发行版和技术支持获得了商业成功，反过来推动了Linux的发展。Linux持续有开源路线和商业路线，商业客户需要商业的版本和支持，有Redhat和Suse等提供。开源的Linux如CentOS,CoreOS等。

反面的例子就是OpenSSL,去年暴露出“心脏出血“漏洞，大家发现就一个人在维护在OpenSSL，也没人捐钱，Theo de Raadt-- OpenBSD项目的创始人说OpenSSL的代码”令人作呕“，主要原因就是没有商业的支持。这不最近又爆出新型高危漏洞。

我们再看看Docker的生态圈，无论是Docker，还是Mesosphere，还是Google，都还没有在Docker开源生态圈获得商业成功。而开源技术终将走向商业，包括Docker，必然面临企业市场挑战，微软奋斗了几十年其企业市场跟甲骨文SAP比起来仍然望其项背，这需要积累。

面对二三十家Docker创业公司，投资人是需要这些创业公司能商业成功的，而Docker本身技术没有成熟，特别在Docker集群管理、资源调度等生产应用方面。Docker生产使用都成熟，要Docker商业成功，不会是一个短期的过程。而docker和mesos这两家核心生态圈的公司到今天为止离盈利还非常远，那国内这些二三十家外围生态圈的创业公司短时期内商业成功几乎不可能。

对于想在Docker上尝鲜的企业来说，要认清开源不等于免费。

## Docker生态圈的推论

Docker进入企业级市场，有优势，也有劣势，优势是挟Docker的大量开发者，劣势是没有做过企业级市场，开发者市场和企业级市场的做法完全不同，微软从消费者用户拓展到企业用户化了十多年的时间，在企业市场并没有取得和消费者市场一样的成功。

做消费者市场，只要把产品做好，而做企业级客户，要一个一个去谈，每个客户的需求都不一样，需要一只庞大的销售、定制、支持队伍。Docker公司到目前为止也就100多人，做企业级市场没有几千人的销售、支持队伍是很难打开全球市场的。100人到数千人，管理模式、业务模式都需要几次转型。而Docker公司目前也只是提供DDC的订阅License和支付服务，并不提供面对面的销售和定制服务

Docker公司进入企业级市场在技术上有最大的优势，撬夺Mesosphere、Google、Redhat的CaaS市场还是有相当的技术优势。通过对Docker API的控制、升级，可以完全影响上面所有对Docker容器集群管理的软件，也许3-5年，Docker的企业级产品会有相当的成功，但不会在2016年。但也许3-5年后，CaaS(Container As a Service)会有新的技术演进。

2016年，作为Docker集群部署管理的生态圈公司：Google kubernetes、Redhat OpenShift、Mesos，面临Docker DDC的不平等技术竞争，会承载巨大的压力，他们会联合起来反制Docker公司。他们的应对就是釜底抽薪，弱化Docker容器，尽快让RunC成熟，在一定程度上取代Docker引擎。另外，直接就是支持虚机，不再受制于Docker，而是直接在企业级市场全面竞争。

和Hadoop生态圈的第一类公司类似，2016-2017年，可能有Docker集群管理的公司会逐步退出这个市场。

事实上，无论是Google还是Mesos,都已经走在和Docker分道扬镳的路上。如果我们和大数据对比一下，Docker有点像CloudEra，技术领先； Redhat像Hortonworks，先上市再说，Redhat是先把产品上市，Hortonworks是先资本上市。Google有点像Intel投资Hadoop，不属于主业，在副业上也投资。Mesos有点像MapR，总是不在核心圈子里，越来越式微。

 2016年．作为Docker CaaS私有云项目实施公司，包括：Rancher、才云、数人云、CSphere、云雀云、Hyper、DaoCloud、有容云、好雨云、轻元科技、迅达云、飞致云、时速云、精灵云、领科云等。和Hadoop的第二类项目实施的生态圈公司走过的历程类似，2016-2017年，各大Docker CaaS项目实施厂商是陷入低价血战的时代。同时，技术方向的选择和标杆客户案例非常关键，如果技术方向选择不对，所选择的Docker集群管理软件被边缘化，那么技术的积累价值会大幅打折，客户的标杆也可能会成为反例。最典型的就是选择Mesos的技术路线的，目前已见颓势。也有的抱Docker大腿不放，选择纯Docker的技术线路，容器集群管理也用Docker Swarm，Docker Swarm有可能会一直很难成熟，特别是和K8s相比,存在巨大的技术风险。

2016年，有些企业级客户开始选择Docker做CaaS，但是客户面临最大的问题是战略性的问题，到底选择哪个Docker集群管理软件，在Docker纷繁复杂的生态圈里做出正确的选择并不容易，考验客户的技术眼光，选择了一个短命的产品以后再纠正并不容易。

其实，Hadoop的客户走过这样的困境，我想起上海某政府客户，在2012年选择Intel的Hadoop实施信息共享项目，成为Intel的全球案例，2013年10月上线，2014年Intel放弃自己的Hadoop，裁撤了几乎所有的Hadoop团队，这时数据和系统都已经上线半年多了，对于一个已经上线提供服务的Hadoop，再去换一个Hadoop，难度可想而知，数据迁移和应用迁移不一样，难度高出许多。如果不换Hadoop,永远停留在Intel的Hadoop 1.0上又失去了采用开源软件的意义，采用开源软件很重要一点是能随开源的成长而成长。面临这种尴尬的时候再次提醒我们产品和技术选择的重要性。推导到Docker企业应用，早期尝鲜的企业客户把Docker集群管理调度部署到生产环境，会不会碰到这种尴尬呢？

目前国内的Docker创业公司超过20家，都想进入企业市场，导致异乎激烈的竞争。而过于激烈的竞争，带来一个畸形的模式————大家主要把钱和资源化在吸引眼球上，而不是把主要力量放在把产品做好（国内的OpenSatck公司何尝不是如此！）。

有个银行客户，准备测试一下Docker，居然超过十家Docker创业公司主动要去测试，据说预算只有几十万。

20多家Docker创业的小公司，少的十几个人，多的几十人，上百的还很罕见，毕竟投资人的钱烧起来很快，搞个上百人的，一年的工资支出可能就几千万。20多家小公司，怎么让客户知道你？这是Docker创业公司的面临的第一个困境，解决办法就是搞市场活动，据说有的公司居然80%的资金都花在市场活动上，常用在酒店给客户讲方案的市场活动不凑效，那就搞技术Fans的Meetup，大家去看看今年的Docker/K8s/Mesos的Meetup多如牛毛，每周都有。Meetup就一定有效吗？对企业级市场来说，并不完全有效，参加Meetup的都是工程师，不是企业项目的决策人，工程师想用，企业决策人还没看清暂时不用是普遍现象。

一方面，把投资人的钱花在各种市场活动上，另外一方面，Docker/K8s/Mesos作为开源技术，这些创业公司对Docker/K8s/Mesos的代码贡献很小，仅仅有一两家对代码有微量贡献，大多数对Docker开源代码是零贡献，对于没有对开源有多少贡献，希望从开源项目赚钱，这多少有点投机取巧，而且，Docker/Google都还没有从自己主导的开源项目赚钱，搭便车的先赚钱，商业上合理吗？

中国目前的容器市场能支撑的了20多家Docker创业公司吗？而这些创业公司绝大多数拿的是投资人的钱，投资人的钱也不是风刮来的，天使轮投资可以只要个Idea,但到A轮/B轮，怎么也得看点数据，你是拿了几个单，还是有多少营收，有多少利润，Docker创业公司面对的是B2B市场，不是B2C市场，B2C市场可以烧钱拉用户，只要用户量在持续增长，可以扩大亏损继续烧。对于B2B市场，是要建立标杆案例项目再复制，标杆可以不赚钱，复制项目总得赚钱，而目前的残酷现实是标杆项目大家打破头，没赚钱。你想复制的时候，20 多家的竞争对手还想着不要钱做自己的标杆，所以标杆项目的复制为盈利项目几乎不可能。

在目前这个市场形势下，投资人再往下投多少会更谨慎一些，那在市场上花钱如流水的Docker创业公司，一旦钱花的差不多，并没有达到预期数字，投资人在投钱上再谨慎起来，一些Docker创业公司的死掉只是时间的问题，也许年底就可以看到倒掉的Docker创业公司。

## 给准备Docker尝鲜的客户的建议

目前有些企业已经在采用Docker和相关技术，据观察，有以下几类企业：

1. 互联网公司，比较早期就开始关注Docker技术，在互联网应用中采用Docker容器，对应用的一致性要求不高，能接受数据的最终一致性。有的仅仅是容器，自己做管理，有的采用Mesos来管理集群，也有采用K8s来管理Docker容器的。这类客户应当占了目前Docker用户的95%以上。

2. 为了混Docker圈子的重IT型公司，数量少，频繁出现在各种Docker市场活动中介绍成功经验。
   这些企业有个特点，喜欢在众多的Docker市场活动上介绍使用Docker的成功经验。作为一个企业，使用新技术可能可以造就新的竞争力，但是在各种Docker的市场活动中介绍成功经验好像和公司的核心竞争力并不完全一致，这些公司的核心竞争力肯定不是是用Docker而带来的。

3. 传统企业在技术创新中采用Docker，取代了很好的效果。

这种企业不多，企业的IT领导人有很强的技术驾驭能力，能够吸纳新技术。通过试点采用Docker成功以后，逐步推广，取代了比较好的效果。

分析这些Docker的使用者，很容易发现在真正企业级环境使用不多，在美国也如此。主要还是互联网公司在使用。

对于企业客户而言，要采用Docker，一般是两种方式：要么选择Docker相关公司来实施，要不然自己基于Docker定制，这种方式工作量太大，需要巨大的团队，对企业来说不合适。如果选择Docker相关公告，目前选择这些Docker创业公司是有巨大风险的，一方面他能生存多久很难说，考虑客户的选择眼光。

如果做Docker项目选择这些公司的产品来实施，对于技术力量稍微强一点的Docker创业公司，他会自己做一些包装定制，把自己的产品提供给客户，但是风险在于，对于定制过的产品，Docker/K8s/Mesos/Swarm的后续发展非常快，这些开源版本一升级，你就得跟着升级，定制了以后升级并不容易，往往会要去改动代码或是配置。作为客户如果采用开源的产品，而不跟着升级，那就失去了采用开源的非常关键的一个价值，开源的发展一开始是不成熟的，如果不能跟着开源逐渐成熟，那选择早期的开源不升级往往是很难达到效果。

也有小的创业公司，对Docker几乎不做定制，甚至界面都不改，就是把环境部署起来，那对企业级应用来说，过于简陋，对使用者要求很高，很大程度上是达不到应有效果的。

对于企业级客户准备采用Docker,鉴于目前Docker在企业级的生产环境应用规模很小，成熟度有待提高，而且对于企业级应用很难在Mesos/K8s/Swarm之间做选择，一旦技术路线选择错误，后面调头重来成本非常高。而且这么多小的Docker创业公司，能不能生存下去，长期提供技术支持，也是需要考虑的问题。

企业要综合考察IaaS/CaaS/PaaS，选择相对成熟的技术，相比而言IaaS和PaaS均比较成熟，基于Docker的CaaS还没有定型，还在成熟的过程中。要结合企业的实际需求，对于潮流技术，先小规模验证，体验取得的实际效果，分析存在的隐患，再做综合决策不迟。

---
