---
title: kubernetes CSI存储插件探究
author: Jeremy Xu
date: 2019-09-29 18:00:00+08:00
categories:
  - 容器编排
tags:
  - k8s
  - devops
  - csi
  - volume
---

本周帮助为一个kubernetes CSI插件实现了动态供应(dynamic provisioning)功能，在这个过程中学习并了解了kubernetes CSI插件的实现细节，这里详细记录一下。

## CSI相关概念

在CSI未出现之前，容器编排系统（Container Orchestration Systems，简称COs，如kubernetes）为了能使用外部存储系统，使这些存储系统为容器工作负载提供存储卷。COs需要在自身的代码中嵌入大量与存储相关的代码，参见[kubernetes里的volume包](https://github.com/kubernetes/kubernetes/tree/master/pkg/volume)，这个包下面大部分就是所谓的in-tree（意思是在kubernetes的代码树里）存储卷插件。

要支持的存储系统多种多样，而且有些存储系统的支持代码还不便于开源，所以很明显上述设计并不好。

后面又出现了`Flexvolume`这种out-tree的存储卷插件机制，允许存储厂商将写好的存储卷插件二进制文件放置到各node节点预设的目录下，kubernetes即可在自动发现它们，并调用它们完成存储卷的供应。详情技术细节可参考[这里](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-storage/flexvolume.md)。

上述`Flexvolume`方案很类似于kubernetes里用的网络方案CNI，都是将外部插件放置在预设的目录下，以供kubernetes调用。但总的来说还是跟kubernetes这一容器编排系统绑定得太死了。于是人们又发明了CSI。

CSI 代表[容器存储接口](https://github.com/container-storage-interface/spec/blob/master/spec.md)，CSI 试图建立一个行业标准接口的规范，借助 CSI 容器编排系统（CO）可以将任意存储系统暴露给自己的容器工作负载。有关详细信息，请查看[设计方案](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/storage/container-storage-interface.md)。

`csi` 卷类型也是一种 out-tree（in-tree是指跟其它存储插件在同一个代码路径下，随 Kubernetes 的代码同时编译，out-tree则刚好相反） 的 CSI 卷插件，用于 Pod 与在同一节点上运行的外部 CSI 卷驱动程序交互。部署 CSI 兼容卷驱动后，用户可以使用 `csi` 作为卷类型来挂载驱动提供的存储。

CSI 持久化卷支持是在 Kubernetes v1.9 中引入的，作为一个 alpha 特性，必须由集群管理员明确启用。换句话说，集群管理员需要在 apiserver、controller-manager 和 kubelet 组件的 “`--feature-gates =`” 标志中加上 “`CSIPersistentVolume = true`”。

CSI 持久化卷具有以下字段可供用户指定：

- `driver`：一个字符串值，指定要使用的卷驱动程序的名称。必须少于 63 个字符，并以一个字符开头。驱动程序名称可以包含 “。”、“ - ”、“_” 或数字。
- `volumeHandle`：一个字符串值，唯一标识从 CSI 卷插件的 `CreateVolume` 调用返回的卷名。随后在卷驱动程序的所有后续调用中使用卷句柄来引用该卷。
- `readOnly`：一个可选的布尔值，指示卷是否被发布为只读。默认是 false。

## CSI插件机制分析

光看上面的概念，还是很难理解到底CSI插件是怎样的。其实说到底一个CSI插件就是实现了CSI规范要求的多个gRPC接口的服务程序。

一个CSI插件一般会以两种形式部署运行着，分别是Controller组件和Node组件。

> [Controller Plugin](https://kubernetes-csi.github.io/docs/deploying.html#controller-plugin)
>
> The controller component can be deployed as a Deployment or StatefulSet on any node in the cluster. It consists of the CSI driver that implements the CSI Controller service and one or more sidecar containers. These controller sidecar containers typically interact with Kubernetes objects and make calls to the driver's CSI Controller service.
>
> It generally does not need direct access to the host and can perform all its operations through the Kubernetes API and external control plane services. Multiple copies of the controller component can be deployed for HA, however it is recommended to use leader election to ensure there is only one active controller at a time.
>
> Controller sidecars include the external-provisioner, external-attacher, external-snapshotter, and external-resizer. Including a sidecar in the deployment may be optional.
>
> 
>
> [Node Plugin](https://kubernetes-csi.github.io/docs/deploying.html#node-plugin)
>
> The node component should be deployed on every node in the cluster through a DaemonSet. It consists of the CSI driver that implements the CSI Node service and the node-driver-registrar sidecar container.
>
> The Kubernetes kubelet runs on every node and is responsible for making the CSI Node service calls. These calls mount and unmount the storage volume from the storage system, making it available to the Pod to consume. Kubelet makes calls to the CSI driver through a UNIX domain socket shared on the host via a HostPath volume. There is also a second UNIX domain socket that the node-driver-registrar uses to register the CSI driver to kubelet.

可以看到Controller组件一般是以Deployment或StatefulSet形式部署的，它实现了CSI Controller service，它会与Kubernetes API、外部存储服务的控制面交互，但它并不会实际处理存储卷在宿主机上的挂载等事宜。

而Node组件因为要运行在所有node节点上，因此一般是以DaemonSet形式部署的，它实现了CSI Node service，它会暴露出一个UNIX domain socket文件出来，从而让kubelet在进行存储卷操作时，通过这个UNIX domain socket文件调用它的gRPC接口。

上述两个组件配合，即完成了将存储卷暴露给工作负载的功能。

下面看一下一个CSI插件要实现的三组gRPC接口服务：

> - **Identity Service**: Both the Node Plugin and the Controller Plugin MUST implement this sets of RPCs.
> - **Controller Service**: The Controller Plugin MUST implement this sets of RPCs.
> - **Node Service**: The Node Plugin MUST implement this sets of RPCs.

```protobuf
service Identity {
  rpc GetPluginInfo(GetPluginInfoRequest)
    returns (GetPluginInfoResponse) {}

  rpc GetPluginCapabilities(GetPluginCapabilitiesRequest)
    returns (GetPluginCapabilitiesResponse) {}

  rpc Probe (ProbeRequest)
    returns (ProbeResponse) {}
}

service Controller {
  rpc CreateVolume (CreateVolumeRequest)
    returns (CreateVolumeResponse) {}

  rpc DeleteVolume (DeleteVolumeRequest)
    returns (DeleteVolumeResponse) {}

  rpc ControllerPublishVolume (ControllerPublishVolumeRequest)
    returns (ControllerPublishVolumeResponse) {}

  rpc ControllerUnpublishVolume (ControllerUnpublishVolumeRequest)
    returns (ControllerUnpublishVolumeResponse) {}

  rpc ValidateVolumeCapabilities (ValidateVolumeCapabilitiesRequest)
    returns (ValidateVolumeCapabilitiesResponse) {}

  rpc ListVolumes (ListVolumesRequest)
    returns (ListVolumesResponse) {}

  rpc GetCapacity (GetCapacityRequest)
    returns (GetCapacityResponse) {}

  rpc ControllerGetCapabilities (ControllerGetCapabilitiesRequest)
    returns (ControllerGetCapabilitiesResponse) {}

  rpc CreateSnapshot (CreateSnapshotRequest)
    returns (CreateSnapshotResponse) {}

  rpc DeleteSnapshot (DeleteSnapshotRequest)
    returns (DeleteSnapshotResponse) {}

  rpc ListSnapshots (ListSnapshotsRequest)
    returns (ListSnapshotsResponse) {}

  rpc ControllerExpandVolume (ControllerExpandVolumeRequest)
    returns (ControllerExpandVolumeResponse) {}
}

service Node {
  rpc NodeStageVolume (NodeStageVolumeRequest)
    returns (NodeStageVolumeResponse) {}

  rpc NodeUnstageVolume (NodeUnstageVolumeRequest)
    returns (NodeUnstageVolumeResponse) {}

  rpc NodePublishVolume (NodePublishVolumeRequest)
    returns (NodePublishVolumeResponse) {}

  rpc NodeUnpublishVolume (NodeUnpublishVolumeRequest)
    returns (NodeUnpublishVolumeResponse) {}

  rpc NodeGetVolumeStats (NodeGetVolumeStatsRequest)
    returns (NodeGetVolumeStatsResponse) {}


  rpc NodeExpandVolume(NodeExpandVolumeRequest)
    returns (NodeExpandVolumeResponse) {}


  rpc NodeGetCapabilities (NodeGetCapabilitiesRequest)
    returns (NodeGetCapabilitiesResponse) {}

  rpc NodeGetInfo (NodeGetInfoRequest)
    returns (NodeGetInfoResponse) {}
}
```

上述这堆接口，看着挺多。其实如果不想实现CSI的某些功能，有些接口也不用实现的。比如如果不想实现存储卷的动态供应，`Controller`的`CreateVolume`、`DeleteVolume`即可不实现。另外有些接口属于元数据接口，仅仅是声明该CSI的Capability，Info的，如`Identity`的所有接口，`ControllerGetCapabilities`的`ControllerGetCapabilities`接口，`Node`的`NodeGetCapabilities`、`NodeGetInfo`接口。再看一下storage volume的lifecycle，这些接口之前的调用关系就很清楚了。

> ```
>    CreateVolume +------------+ DeleteVolume
>  +------------->|  CREATED   +--------------+
>  |              +---+----+---+              |
>  |       Controller |    | Controller       v
> +++         Publish |    | Unpublish       +++
> |X|          Volume |    | Volume          | |
> +-+             +---v----+---+             +-+
>                 | NODE_READY |
>                 +---+----^---+
>                Node |    | Node
>               Stage |    | Unstage
>              Volume |    | Volume
>                 +---v----+---+
>                 |  VOL_READY |
>                 +------------+
>                Node |    | Node
>             Publish |    | Unpublish
>              Volume |    | Volume
>                 +---v----+---+
>                 | PUBLISHED  |
>                 +------------+
> 
> Figure 6: The lifecycle of a dynamically provisioned volume, from
> creation to destruction, when the Node Plugin advertises the
> STAGE_UNSTAGE_VOLUME capability.
> ```

上面这个图是一个较为复杂的卷供应生命周期图，从这个图我们可以看出一个存储卷的供应分别调用了`Controller Plugin`的`CreateVolume`、`ControllerPublishVolume`及`Node Plugin`的`NodeStageVolume`、`NodePublishVolume`这4个gRPC接口，存储卷的销毁分别调用了`Node Plugin`的`NodeUnpublishVolume`、`NodeUnstageVolume`及`Controller`的`ControllerUnpublishVolume`、`DeleteVolume`这4个gRPC接口，这每个接口要完成的工作参见[CSI规范](https://github.com/container-storage-interface/spec/blob/master/spec.md#controller-service-rpc)。

只看规范可能会看得云里雾里的，我是参考一个现成的CSI插件实例来理解CSI规范的。这里推荐下[tencentcloud cbs块存储的CSI插件](https://github.com/TencentCloud/kubernetes-csi-tencentcloud)，这个CSI插件实现得相当规范，分别在[controller.go](https://github.com/TencentCloud/kubernetes-csi-tencentcloud/blob/master/driver/cbs/controller.go)里实现了Controller Service里的几个gRPC接口、[identity.go](https://github.com/TencentCloud/kubernetes-csi-tencentcloud/blob/master/driver/cbs/identity.go)里实现了Identify Service里的几个gRPC接口、[node.go](https://github.com/TencentCloud/kubernetes-csi-tencentcloud/blob/master/driver/cbs/node.go)里实现了Node Service里的几个gRPC接口。

## CSI插件的部署

按CSI规范实现了相应的gRPC接口后，一个CSI插件就基本成型了。但这并不是全部，回想下目前整个CSI插件的功能逻辑，我们只是实现了存储卷驱动的核心逻辑，但并没有与Kubernetes产生任何联动啊。这写好的CSI插件如何工作呢？

与Kubernetes的联动逻辑比较统一，基本就是watch Kubrernetes API，根据watch到的资源状态调用相应的CSI接口，根据CSI接口的返回结果更新Kubernetes里的资源状态。官方为了简化开发CSI插件的复杂度，提供了一系列的sidecar来完成这些工作。而CSI的开发人员要做的就是在部署CSI插件时声明将相应的sidecar与CSI插件捆绑部署在一起。

> Kubernetes CSI Sidecar Containers are a set of standard containers that aim to simplify the development and deployment of CSI Drivers on Kubernetes.
>
> These containers contain common logic to watch the Kubernetes API, trigger appropriate operations against the “CSI volume driver” container, and update the Kubernetes API as appropriate.
>
> The containers are intended to be bundled with third-party CSI driver containers and deployed together as pods.
>
> The containers are developed and maintained by the Kubernetes Storage community.
>
> Use of the containers is strictly optional, but highly recommended.

使用这些sidecar的好处很多，官方文档中下面这两段话说得很清楚。以后做设计时也可以参考这样优雅地实现。

> Benefits of these sidecar containers include:
>
> - Reduction of "boilerplate" code.
>   - CSI Driver developers do not have to worry about complicated, "Kubernetes specific" code.
> - Separation of concerns.
>   - Code that interacts with the Kubernetes API is isolated from (and in a different container then) the code that implements the CSI interface.

会使用到的sidecar如下：

- [external-provisioner](https://kubernetes-csi.github.io/docs/external-provisioner.html) 

  如果CSI插件要实现CREATE_DELETE_VOLUME能力（即动态供应），则CSI插件需要实现Controller Service的`CreateVolume`、`DeleteVolume`接口，并配合上该sidecar就可以了。这样当watch到指定StorageClass的 PersistentVolumeClaim资源状态变更，会自动地调用这两个接口。

- [external-attacher](https://kubernetes-csi.github.io/docs/external-attacher.html)

  如果CSI插件要实现PUBLISH_UNPUBLISH_VOLUME能力，则CSI插件需要实现Controller Service的`ControllerPublishVolume`、`ControllerUnpublishVolume`接口，并配合上该sidecar就可以了。这样当watch到VolumeAttachment资源状态变更，会自动地调用这两个接口。

- [external-snapshotter](https://kubernetes-csi.github.io/docs/external-snapshotter.html)

  如果CSI插件要实现CREATE_DELETE_SNAPSHOT能力，则CSI插件需要实现Controller Service的`CreateSnapshot`、`DeleteSnapshot`接口，并配合上该sidecar就可以了。这样当watch到指定SnapshotClass的VolumeSnapshot资源状态变更，会自动地调用这两个接口。

- [external-resizer](https://kubernetes-csi.github.io/docs/external-resizer.html)

  如果CSI插件要实现EXPAND_VOLUME能力，则CSI插件需要实现Controller Service的`ControllerExpandVolume`接口，并配合上该sidecar就可以了。这样当watch到PersistentVolumeClaim资源的容量发生变更，会自动地调用这个接口。

- [node-driver-registrar](https://kubernetes-csi.github.io/docs/node-driver-registrar.html)

  CSI插件实现Node Service的`NodeGetInfo`接口后，配合上该sidecar。这样当CSI Node Plugin部署到kubernetes的node节点时，该sidecar会自动调用接口获取CSI插件信息，并向kubelet进行注册。

- [livenessprobe](https://kubernetes-csi.github.io/docs/livenessprobe.html)

  配合上该sidecar，kubernetes即可检测到CSI插件相关pod的健康状态，当不正常时自动重启相应pod。

怎么将这些sidecar与CSI Driver部署在一起，[官方文档](https://kubernetes-csi.github.io/docs/deploying.html)其实讲得很清楚的。

同样个人觉得还是结合实际的示例理解文档更快一点。比如[tencentcloud cbs块存储的CSI插件](https://github.com/TencentCloud/kubernetes-csi-tencentcloud)的部署清单里：

1. [csi-cbsplugin.yaml](https://github.com/TencentCloud/kubernetes-csi-tencentcloud/blob/master/deploy/kubernetes/csi-cbsplugin.yaml)以DaemonSet方式部署了`csi-tencentcloud-cbs:v1.0.0`这个CSI插件Driver程序，这个插件Driver程序旁边放了一个`csi-node-driver-registrar:v1.0.2`的sidecar，这个sidecar会自动调用接口获取CSI插件信息，并向kubelet进行注册。
2. [csi-cbsplugin-provisioner.yaml](https://github.com/TencentCloud/kubernetes-csi-tencentcloud/blob/master/deploy/kubernetes/csi-cbsplugin-provisioner.yaml)以StatefulSet方式部署了`csi-provisioner:v1.0.1`、`csi-snapshotter:v1.0.1`这两个sidecar，这两个sidecar会watch指定StorageClass的 PersistentVolumeClaim资源状态变更、指定SnapshotClass的VolumeSnapshot资源状态变更，然后通过宿主机上的csi UNIX domain socket与CSI插件驱动通信，调用相应的gRPC接口方法。
3. [csi-cbsplugin-attacher.yaml](https://github.com/TencentCloud/kubernetes-csi-tencentcloud/blob/master/deploy/kubernetes/csi-cbsplugin-attacher.yaml)以StatefulSet方式部署了`csi-attacher:v1.0.1`这个sidecar，这个sidecar会watch VolumeAttachment资源状态变更，然后通过宿主机上的csi UNIX domain socket与CSI插件驱动通信，调用相应的gRPC接口方法。

其它的sidecar的使用方法都类似上面示例中的玩法，照着配置就可以了。

## CSI的其它技术细节

1. 在进行存储系统操作时会使用到各种密码、身份凭证，而这些需要按照一定的规约进行配置，详见[官方文档](https://kubernetes-csi.github.io/docs/secrets-and-credentials.html)。
2. 可以通过`CSIDriver`这一自定义资源，定制Kubernetes与CSI存储插件交互的行为，详见[官方文档](https://kubernetes-csi.github.io/docs/csi-driver-object.html)。
3. 可以通过`CSINodeInfo`这一自定义资源，将kubernetes的node与CSI Node映射起来。还可以通过`CSINodeInfo`指定node节点的的topologyKey，这个能实现基于topology的CSI存储卷供应，详见[官方文档1](https://kubernetes-csi.github.io/docs/csi-node-object.html)和[官方文档2](https://kubernetes-csi.github.io/docs/topology.html)。

## CSI插件的测试支持

官方还为开发CSI插件提供了[单元测试与e2e测试的方案](https://kubernetes-csi.github.io/docs/testing-drivers.html)，可惜时间关系，并没有演练一把，后面可以考虑把这一点实操一下，毕竟测试驱动开发是趋势。

## 现成的CSI插件驱动

目前各大知名云厂商都实现了自家存储产品的CSI插件驱动，列表在[这里](https://kubernetes-csi.github.io/docs/drivers.html)。正常情况下直接使用官方提供的CSI插件即可。当然如果要学习下也是可以，CSI插件的代码一般都不难，5-6个go文件而已。

DONE

## 参考

1. https://kubernetes-csi.github.io/docs
2. https://github.com/TencentCloud/kubernetes-csi-tencentcloud
3. https://github.com/container-storage-interface/spec
4. https://jimmysong.io/kubernetes-handbook/concepts/csi.html
5. https://github.com/kubernetes/community/blob/master/contributors/devel/sig-storage/flexvolume.md
6. https://github.com/kubernetes/kubernetes/tree/master/pkg/volume

