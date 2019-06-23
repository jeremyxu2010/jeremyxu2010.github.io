---
title: javacv编码mp4视频
tags:
  - java
  - ffmpeg
  - javacv
  - h264
categories:
  - java开发
date: 2016-04-10 18:29:00+08:00
---
目前在做的java项目里有一个需求，已经将用户在进行一个业务操作的操作行为记录下来了，形成了这些操作行为的指令文件，然后需要将这些指令文件编码为mp4视频。项目之前用的是xuggle来完成的，不过xuggle项目好像有四五年没有更新了，甚至我将OSX升级至10.11之后，xuggle就没法在我本机编译通过了，报了一大堆的错。上xuggle的github仓库一看，人家也说不维护了，推荐使用`https://github.com/artclarke/humble-video`了，不过我尝试了下，依然没能把`humble-video`在我本机编译通过。看来得找其它解决方案了。上网搜索过后，找到两个替代方案jcodec和javacv，对比编码性能后，最终选择了javacv，纯java方案相对于jni方案性能差得不是一星半点啊。不过在使用javacv过程中还是遇到了不少坑，在这里分享一下，也可以帮助一下正在这些坑里的兄弟们。

首先参照javacv的文档，在pom.xml里添加

```
<dependency>
  <groupId>org.bytedeco</groupId>
  <artifactId>javacv</artifactId>
  <version>1.1</version>
</dependency>
```

然后快速地写了个JavaCVMp4Encoder

```java
package test;

public class JavaCVMp4Encoder implements Mp4Encoder {
    private String fileName;
    private FFmpegFrameRecorder recorder;
    private static final double FRAME_RATE = 25.0;
    private static final double MOTION_FACTOR = 1;
    private static final Java2DFrameConverter java2dConverter;
    private static final Logger log = LoggerFactory.getLogger(JavaCVMp4Encoder.class);

    public JavaCVMp4Encoder(){
    	this.java2dConverter = new Java2DFrameConverter();
    }

    @Override
    public void make(String fileName) {
        this.fileName = fileName;
    }

    @Override
    public void configVideo(int width, int height) {
        recorder = new FFmpegFrameRecorder(this.fileName, width, height);
        recorder.setVideoCodec(avcodec.AV_CODEC_ID_H264);

        recorder.setFrameRate(FRAME_RATE);
        /*
        * videoBitRate这个参数很重要，当然越大，越清晰，但最终的生成的视频也越大。查看一个资料，说均衡考虑建议设为videoWidth*videoHeight*frameRate*0.07*运动因子，运动因子则与视频中画面活动频繁程度有关，如果很频繁就设为4，不频繁则设为1
        */
        recorder.setVideoBitrate((int)((width*height*FRAME_RATE)*MOTION_FACTOR*0.07));

        recorder.setPixelFormat(avutil.AV_PIX_FMT_YUV420P);
        recorder.setFormat("mp4");
        try {
            recorder.start();
        } catch (FrameRecorder.Exception e) {
            log.error("JavaCVMp4Encoder configure video error.", e);
        }

    }

    @Override
    public void encodeFrame(BufferedImage image, long timestamp) {
        try {
            recorder.record(java2dConverter.convert(image));
        } catch (FrameRecorder.Exception e) {
            log.error("JavaCVMp4Encoder encode frame error.", e);
        }
    }

    @Override
    public void close() {
        if(recorder != null){
            try {
                recorder.stop();
            } catch (FrameRecorder.Exception e) {
                log.error("JavaCVMp4Encoder stop error.", e);
            }
            try {
                recorder.release();
            } catch (FrameRecorder.Exception e) {
                log.error("JavaCVMp4Encoder release error.", e);
            }
        }
    }
}
```

顺手写了个测试案例，还好是可以工作的

```java
package test;

public JavaCVMp4EncoderTest {
	public static void main(String[] args){
    	Mp4Encoder encoder = new JavaCVMp4Encoder();
        encoder.make("/tmp/test.mp4");
        encoder.configVideo(1024, 768);
        BufferedImage img = new BufferedImage(1024, 768, BufferedImage.TYPE_3BYTE_BGR);

        Java2DFrameConverter java2dConverter = new Java2DFrameConverter();
        Graphics2D g2 = (Graphics2D)img.getGraphics();
        for (int i = 0; i <= 25 * 20; i++) {
            g2.setColor(Color.white);
            g2.fillRect(0, 0, width, height);
            g2.setPaint(Color.black);
            g2.drawString("frame " + i, 10, 25);
            encoder.encodeFrame(java2dConverter.convert(img), System.currentTimeMillis());
        }

        encoder.close();
    }
}
```

不过不久就发现在项目中转出的录像播放得太快了，检查代码发现`JavaCVMp4Encoder`的`encodeFrame`方法的第二个参数`timestamp`并没有用到，但在项目中进行mp4编码时，实际上是对每一帧指定的时间戳的，于是修改`encodeFrame`方法

```java
@Override
public void encodeFrame(BufferedImage image, long timestamp) {
  try {
    long t = timestamp * 1000L;
    if (t > recorder.getTimestamp()) {
    	recorder.setTimestamp(t);
    }
    recorder.record(java2dConverter.convert(image));
  } catch (FrameRecorder.Exception e) {
    log.error("JavaCVMp4Encoder encode frame error.", e);
  }
}
```

终于转出的视频不再飞快播放了。

又过了好几天，在正式环境上运行着，又出问题，进行mp4编码的Java进程crash了。crash日志时仅报了一下跟jni调用相关的错。

```
Stack: [0x00007f1932fb4000,0x00007f19330b5000],  sp=0x00007f19330b2d88,  free space=1019k
Native frames: (J=compiled Java code, j=interpreted, Vv=VM code, C=native code)
C  [libswscale.so.3+0x52f41]  sws_getCachedContext+0x1471

[error occurred during error reporting (printing native stack), id 0xb]

Java frames: (J=compiled Java code, j=interpreted, Vv=VM code)
j  org.bytedeco.javacpp.swscale.sws_scale(Lorg/bytedeco/javacpp/swscale$SwsContext;Lorg/bytedeco/javacpp/PointerPointer;Lorg/bytedeco/javacpp/IntPointer;IILorg/bytedeco/javacpp/PointerPointer;Lorg/bytedeco/javacpp/IntPointer;)I+0
j  org.bytedeco.javacv.FFmpegFrameRecorder.recordImage(IIIIII[Ljava/nio/Buffer;)Z+570
j  org.bytedeco.javacv.FFmpegFrameRecorder.record(Lorg/bytedeco/javacv/Frame;I)V+70
j  org.bytedeco.javacv.FFmpegFrameRecorder.record(Lorg/bytedeco/javacv/Frame;)V+3
```

在网上查阅了很久，终于找到一个[线索](http://superuser.com/questions/728795/new-ffmpeg-swscaler-0xa314080-warning-data-is-not-aligned-this-can-lead/799987)，说是跟下面的代码相关

```c
if ( (uintptr_t)dst[0]%16 || (uintptr_t)dst[1]%16 || (uintptr_t)dst[2]%16
	|| (uintptr_t)src[0]%16 || (uintptr_t)src[1]%16 || (uintptr_t)src[2]%16
	|| dstStride[0]%16 || dstStride[1]%16 || dstStride[2]%16 || dstStride[3]%16
	|| srcStride[0]%16 || srcStride[1]%16 || srcStride[2]%16 || srcStride[3]%16
	) {
	static int warnedAlready=0;
	int cpu_flags = av_get_cpu_flags();
	if (HAVE_MMXEXT && (cpu_flags & AV_CPU_FLAG_SSE2) && !warnedAlready){
		av_log(c, AV_LOG_WARNING, "Warning: data is not aligned! This can lead to a speedloss\n");
  		warnedAlready=1;
  }
}
```

意思是视频的宽度必须是16的倍数，否则ffmpeg可能因为无法对齐而crash。这么重要的事情，在ffmpeg文档上竟然从来没提出。但经我实际测试，发现视频的宽度必须是32的倍数，高度必须是2的倍数，于是写了点代码修正了`width`与`height`，然后问题就解决了。

```java
int width = ...;
int height = ...;

if (width % 32 != 0) {
  int j = width % 32;
  if (j <= 16) {
    width = width - (width % 32);
  } else {
    width = width + (32 - width / 32);
  }
}
if (height % 2 != 0) {
  int j = height % 4;
  switch (j) {
    case 1:
      height = height - 1;
      break;
    case 3:
      height = height + 1;
      break;
  }
}
Mp4Encoder encoder = new JavaCVMp4Encoder();
encoder.make("/tmp/test.mp4");
encoder.configVideo(width, height);
BufferedImage img = new BufferedImage(width, height, BufferedImage.TYPE_3BYTE_BGR);

```
