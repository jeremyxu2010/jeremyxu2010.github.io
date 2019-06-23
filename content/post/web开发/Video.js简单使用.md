---
title: Video.js简单使用
author: Jeremy Xu
tags:
  - javascript
  - video
categories:
  - web开发
date: 2013-10-31 01:40:00+08:00
---

今天项目中需要跨浏览器地播放视频，在网上找了一下，找到了video.js，记录一下video.js的简单用法。

```html
<html>
<head>
...
<!-- 引入video.js的样式文件 -->
<link rel="stylesheet" type="text/css" href="css/video-js.css" />
...
<!-- 如果没有使用Modernizr，则使用以下代码做shiv -->
<script type="text/javascript">
	document.createElement('video');document.createElement('audio');document.createElement('track');
</script>
...
<!-- 引入video.js的脚本文件 -->
<script src="js/video.js" type="text/javascript" charset="utf-8"></script>
<!-- 指定videojs的flash文件 -->
<script type="text/javascript">
	videojs.options.flash.swf = "js/video-js.swf";
</script>
...
</head>
<body>
...
<video id="sample_video" preload="none"  class="video-js vjs-default-skin vjs-big-play-centered" data-setup='{ "controls": true, "autoplay": false, "preload": "none", "poster": "images/sample_video_poster.png", "width": 852, "height": 480 }'>
                    <source src="videos/sample_video.mp4" type='video/mp4' />

                    <!-- 如果浏览器不兼容HTML5则使用flash播放 -->
                    <object id="sample_video" class="vjs-flash-fallback" width="852"
                        height="480" type="application/x-shockwave-flash"
                        data="http://releases.flowplayer.org/swf/flowplayer-3.2.1.swf">
                        <param name="movie"
                            value="http://releases.flowplayer.org/swf/flowplayer-3.2.1.swf" />
                        <param name="allowfullscreen" value="true" />
                        <param name="flashvars" value='config={"playlist":["images/sample_video_poster.png", {"url": "videos/sample_video.mp4","autoPlay":false,"autoBuffering":true}]}' />
                        <!-- 视频图片. -->
                        <img src="images/sample_video.png" width="852"
                            height="480" alt="Poster Image"
                            title="No video playback capabilities." />
                    </object>
                </video>
...
<script type="text/javascript">
var myPlayer = null;
$(document).ready(function() {
...
    if(!myPlayer) {
        // Using the video's ID or element
        myPlayer = videojs("video_center_video");
    }
    // After you have references to your players you can...(example)
    myPlayer.play(); // Starts playing the video for this player.
...
});
</script>
</body>
</html>
```

上面的用法是tag标签的使用办法，官方文档里还写了使用js初始化的办法，很简单，可参照https://github.com/videojs/video.js/blob/stable/docs/guides/setup.md

使用video.js有一个好处就是video标签或flashvars中可以指定多个视频源，它会根据浏览器自动寻找合适的视频进行播放。

不过今天使用video.js的时候发现一个问题，当设置了preload为auto之后，在chrome下首次刷新网页网络请求会出现一个错误。

```
Request URL:
http://xxxxx/yyyy.mp4
Request Headers CAUTION: Provisional headers are shown.
Accept-Encoding:
identity;q=1, *;q=0
Cache-Control:
max-age=0
Range:
bytes=0-
Referer:
http://xxxxx
User-Agent:
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.131 Safari/537.36
```

暂时将preload设置为none规避此问题。

默认的video.js的样式不太好看，顺便附上从锤子网http://www.smartisan.com/爬下来的样式文件。

```css
/*!
Video.js Default Styles (http://videojs.com)
Version 4.6.1
Create your own skin at http://designer.videojs.com
*/.vjs-default-skin{color:#ccc}@font-face{font-weight:400;font-style:normal}.vjs-default-skin .vjs-slider{outline:0;position:relative;cursor:pointer;padding:0;background:url(../images/bg_player_icon_v.png) 0 -210px repeat-x}.vjs-default-skin .vjs-slider:focus{-webkit-box-shadow:0 0 2em #fff;-moz-box-shadow:0 0 2em #fff;box-shadow:0 0 2em #fff}.vjs-default-skin .vjs-slider-handle{font-family:VideoJS;font-size:1em;line-height:1;text-align:center;text-shadow:0 0 1em #fff;position:absolute;top:-13px;left:0;background:url(../images/bg_player_icon_v.png) 0 -90px no-repeat;width:33px;height:33px}.vjs-default-skin .vjs-control-bar{display:none;position:absolute;bottom:0;left:0;right:0;height:39px;padding:3px 0 0;background-color:#000}.vjs-default-skin.vjs-has-started .vjs-control-bar{display:block;visibility:visible;opacity:1;-webkit-transition:visibility .1s,opacity .1s;-moz-transition:visibility .1s,opacity .1s;-o-transition:visibility .1s,opacity .1s;transition:visibility .1s,opacity .1s}.vjs-default-skin.vjs-has-started.vjs-user-inactive.vjs-playing .vjs-control-bar{display:block;visibility:hidden;opacity:0;-webkit-transition:visibility 1s,opacity 1s;-moz-transition:visibility 1s,opacity 1s;-o-transition:visibility 1s,opacity 1s;transition:visibility 1s,opacity 1s}.vjs-default-skin.vjs-controls-disabled .vjs-control-bar{display:none}.vjs-default-skin.vjs-using-native-controls .vjs-control-bar{display:none}.vjs-default-skin.vjs-error .vjs-control-bar{display:none}@media \0screen{.vjs-default-skin.vjs-user-inactive.vjs-playing .vjs-control-bar :before{content:""}}.vjs-default-skin .vjs-control{outline:0;position:relative;float:left;text-align:center;margin:0;padding:0;height:3em;width:4em}.vjs-default-skin .vjs-control:before{font-family:VideoJS;font-size:1.5em;position:absolute;top:0;left:0;width:100%;height:100%;text-align:center;text-shadow:1px 1px 1px rgba(0,0,0,.5)}.vjs-default-skin .vjs-control:focus:before,.vjs-default-skin .vjs-control:hover:before{text-shadow:0 0 1em #fff}.vjs-default-skin .vjs-control-text{border:0;clip:rect(0 0 0 0);height:1px;margin:-1px;overflow:hidden;padding:0;position:absolute;width:1px}.vjs-default-skin .vjs-play-control{width:5em;cursor:pointer;background:url(../images/bg_player_icon.png) 27px 0 no-repeat}.vjs-default-skin.vjs-playing .vjs-play-control{background:url(../images/bg_player_icon.png) -33px 0 no-repeat}.vjs-default-skin .vjs-playback-rate .vjs-playback-rate-value{font-size:1.5em;line-height:2;position:absolute;top:0;left:0;width:100%;height:100%;text-align:center;text-shadow:1px 1px 1px rgba(0,0,0,.5)}.vjs-default-skin .vjs-playback-rate.vjs-menu-button .vjs-menu .vjs-menu-content{width:4em;left:-2em;list-style:none}.vjs-default-skin .vjs-mute-control,.vjs-default-skin .vjs-volume-menu-button{cursor:pointer;float:right;background:url(../images/bg_player_icon.png) -104px 0 no-repeat}.vjs-default-skin .vjs-mute-control.vjs-vol-0,.vjs-default-skin .vjs-volume-menu-button.vjs-vol-0{background:url(../images/bg_player_icon.png) -164px 0 no-repeat}.vjs-default-skin .vjs-mute-control.vjs-vol-1:before,.vjs-default-skin .vjs-volume-menu-button.vjs-vol-1:before{background:url(../images/bg_player_icon.png) -104px 0 no-repeat}.vjs-default-skin .vjs-mute-control.vjs-vol-2:before,.vjs-default-skin .vjs-volume-menu-button.vjs-vol-2:before{background:url(../images/bg_player_icon.png) -104px 0 no-repeat}.vjs-default-skin .vjs-volume-control{width:5em;float:right;top:2px;top:4px\0}.vjs-default-skin .vjs-volume-bar{width:5em;height:.6em;margin:1.1em auto 0}.vjs-default-skin .vjs-volume-menu-button .vjs-menu-content{height:2.9em}.vjs-default-skin .vjs-volume-level{position:absolute;top:0;left:0;height:.5em;width:100%;background:url(../images/bg_player_icon_v.png) 0 -150px repeat-x}.vjs-default-skin .vjs-volume-bar .vjs-volume-handle{width:14px;height:14px;left:4.5em;background:url(../images/bg_player_icon_v.png) 0 0 no-repeat;top:-4px}.vjs-default-skin .vjs-volume-handle:before{font-size:.9em;top:-.2em;left:-.2em;width:1em;height:1em}.vjs-default-skin .vjs-volume-menu-button .vjs-menu .vjs-menu-content{width:6em;left:-4em}.vjs-default-skin .vjs-progress-control{position:absolute;left:0;right:0;width:auto;font-size:.3em;height:6px;top:-6px;-webkit-transition:all .4s;-moz-transition:all .4s;-o-transition:all .4s;transition:all .4s}.vjs-default-skin:hover .vjs-progress-control{font-size:.9em;-webkit-transition:all .2s;-moz-transition:all .2s;-o-transition:all .2s;transition:all .2s}.vjs-default-skin .vjs-progress-holder{height:100%}.vjs-default-skin .vjs-progress-holder .vjs-play-progress,.vjs-default-skin .vjs-progress-holder .vjs-load-progress{position:absolute;display:block;height:100%;margin:0;padding:0;width:0;left:0;top:0}.vjs-default-skin .vjs-play-progress{background:url(../images/bg_player_icon_v.png) 0 -150px repeat-x}.vjs-default-skin .vjs-load-progress{background:url(../images/bg_player_icon_v.png) 0 -180px repeat-x}.vjs-default-skin.vjs-live .vjs-time-controls,.vjs-default-skin.vjs-live .vjs-time-divider,.vjs-default-skin.vjs-live .vjs-progress-control{display:none}.vjs-default-skin.vjs-live .vjs-live-display{display:block}.vjs-default-skin .vjs-live-display{display:none;font-size:1em;line-height:3em}.vjs-default-skin .vjs-time-controls{font-size:1em;line-height:36px}.vjs-default-skin .vjs-current-time{float:left}.vjs-default-skin .vjs-duration{float:left}.vjs-default-skin .vjs-remaining-time{display:none;float:left}.vjs-default-skin .vjs-time-controls,.vjs-default-skin .vjs-duration,.vjs-default-skin .vjs-duration{top:3px\0;top:1px}.vjs-time-divider{float:left;line-height:36px}.vjs-default-skin .vjs-fullscreen-control{width:3.8em;cursor:pointer;float:right}.vjs-default-skin .vjs-fullscreen-control{background:url(../images/bg_player_icon.png) -220px 0 no-repeat}.vjs-default-skin.vjs-fullscreen .vjs-fullscreen-control{background:url(../images/bg_player_icon.png) -284px 0 no-repeat}.vjs-default-skin .vjs-big-play-button{left:50%;top:50%;margin:-26.5px 0 0 -22.5px;display:block;z-index:2;position:absolute;width:45px;height:53px;cursor:pointer;opacity:1;background:url(../images/bg_player_play.png) left top no-repeat}.vjs-default-skin .vjs-mute-control.vjs-vol-0:hover,.vjs-default-skin .vjs-mute-control.vjs-vol-1:hover,.vjs-default-skin .vjs-mute-control.vjs-vol-2:hover,.vjs-default-skin .vjs-mute-control.vjs-vol-3:hover,.vjs-default-skin .vjs-mute-control:hover,.vjs-default-skin.vjs-fullscreen .vjs-fullscreen-control:hover,.vjs-default-skin .vjs-fullscreen-control:hover,.vjs-default-skin.vjs-playing .vjs-play-control:hover,.vjs-default-skin .vjs-play-control:hover,.vjs-default-skin .vjs-big-play-button:hover{opacity:.6;-moz-transition:opacity .3s ease;-webkit-transition:opacity .3s ease;-o-transition:opacity .3s ease;transition:opacity .3s ease}.vjs-default-skin.vjs-big-play-centered .vjs-big-play-button{left:50%;margin-left:-2.1em;top:50%;margin-top:-1.4000000000000001em}.vjs-default-skin.vjs-controls-disabled .vjs-big-play-button{display:none}.vjs-default-skin.vjs-has-started .vjs-big-play-button{display:none}.vjs-default-skin.vjs-using-native-controls .vjs-big-play-button{display:none}.vjs-default-skin:hover .vjs-big-play-button,.vjs-default-skin .vjs-big-play-button:focus{outline:0;border-color:#fff}.vjs-error .vjs-big-play-button{display:none}.vjs-error-display{display:none}.vjs-error .vjs-error-display{display:block;position:absolute;left:0;top:0;width:100%;height:100%}.vjs-error .vjs-error-display:before{content:'X';font-family:Arial;font-size:4em;color:#666;line-height:1;text-shadow:.05em .05em .1em #000;text-align:center;vertical-align:middle;position:absolute;top:50%;margin-top:-.5em;width:100%}.vjs-error-display div{position:absolute;font-size:1.4em;text-align:center;bottom:1em;right:1em;left:1em}.vjs-error-display a,.vjs-error-display a:visited{color:#F4A460}.vjs-loading-spinner{background:url(../images/bg_player_loading.png) no-repeat;display:none;position:absolute;top:50%;left:50%;font-size:4em;line-height:1;width:61px;height:61px;margin-left:-30.5px;margin-top:-30.5px;opacity:.75;-webkit-animation:spin 1.5s infinite linear;-moz-animation:spin 1.5s infinite linear;-o-animation:spin 1.5s infinite linear;animation:spin 1.5s infinite linear}.video-js.vjs-error .vjs-loading-spinner{display:none!important;-webkit-animation:none;-moz-animation:none;-o-animation:none;animation:none}@-moz-keyframes spin{0%{-moz-transform:rotate(0deg)}100%{-moz-transform:rotate(359deg)}}@-webkit-keyframes spin{0%{-webkit-transform:rotate(0deg)}100%{-webkit-transform:rotate(359deg)}}@-o-keyframes spin{0%{-o-transform:rotate(0deg)}100%{-o-transform:rotate(359deg)}}@keyframes spin{0%{transform:rotate(0deg)}100%{transform:rotate(359deg)}}.vjs-default-skin .vjs-menu-button{float:right;cursor:pointer}.vjs-default-skin .vjs-menu{display:none;position:absolute;bottom:0;left:0;width:0;height:0;margin-bottom:3em;border-left:2em solid transparent;border-right:2em solid transparent;border-top:1.55em solid #000;border-top-color:rgba(7,40,50,.5)}.vjs-default-skin .vjs-menu-button .vjs-menu .vjs-menu-content{display:block;padding:0;margin:0;position:absolute;width:10em;bottom:1.5em;max-height:15em;overflow:auto;left:-5em;background-color:#07141e;background-color:rgba(7,20,30,.7);-webkit-box-shadow:-.2em -.2em .3em rgba(255,255,255,.2);-moz-box-shadow:-.2em -.2em .3em rgba(255,255,255,.2);box-shadow:-.2em -.2em .3em rgba(255,255,255,.2)}.vjs-default-skin .vjs-menu-button:hover .vjs-menu{display:block}.vjs-default-skin .vjs-menu-button ul li{list-style:none;margin:0;padding:.3em 0;line-height:1.4em;font-size:1.2em;text-align:center;text-transform:lowercase}.vjs-default-skin .vjs-menu-button ul li.vjs-selected{background-color:#000}.vjs-default-skin .vjs-menu-button ul li:focus,.vjs-default-skin .vjs-menu-button ul li:hover,.vjs-default-skin .vjs-menu-button ul li.vjs-selected:focus,.vjs-default-skin .vjs-menu-button ul li.vjs-selected:hover{outline:0;color:#111;background-color:#fff;background-color:rgba(255,255,255,.75);-webkit-box-shadow:0 0 1em #fff;-moz-box-shadow:0 0 1em #fff;box-shadow:0 0 1em #fff}.vjs-default-skin .vjs-menu-button ul li.vjs-menu-title{text-align:center;text-transform:uppercase;font-size:1em;line-height:2em;padding:0;margin:0 0 .3em;font-weight:700;cursor:default}.vjs-default-skin .vjs-subtitles-button:before{content:"\e00c"}.vjs-default-skin .vjs-captions-button:before{content:"\e008"}.vjs-default-skin .vjs-captions-button:focus .vjs-control-content:before,.vjs-default-skin .vjs-captions-button:hover .vjs-control-content:before{-webkit-box-shadow:0 0 1em #fff;-moz-box-shadow:0 0 1em #fff;box-shadow:0 0 1em #fff}.video-js{background-color:#000;position:relative;padding:0;font-size:10px;vertical-align:middle;font-weight:400;font-style:normal;font-family:Arial,sans-serif;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none}.video-js .vjs-tech{position:absolute;top:0;left:0;width:100%;height:100%}.video-js:-moz-full-screen{position:absolute}body.vjs-full-window{padding:0;margin:0;height:100%;overflow-y:auto}.video-js.vjs-fullscreen{position:fixed;overflow:hidden;z-index:1000;left:0;top:0;bottom:0;right:0;width:100%!important;height:100%!important;_position:absolute}.video-js:-webkit-full-screen{width:100%!important;height:100%!important}.video-js.vjs-fullscreen.vjs-user-inactive{cursor:none}.vjs-poster{background-repeat:no-repeat;background-position:50% 50%;background-size:contain;cursor:pointer;height:100%;margin:0;padding:0;position:relative;width:100%}.vjs-poster img{display:block;margin:0 auto;max-height:100%;padding:0;width:100%}.video-js.vjs-using-native-controls .vjs-poster{display:none}.video-js .vjs-text-track-display{text-align:center;position:absolute;bottom:4em;left:1em;right:1em}.video-js.vjs-user-inactive.vjs-playing .vjs-text-track-display{bottom:1em}.video-js .vjs-text-track{display:none;font-size:1.4em;text-align:center;margin-bottom:.1em;background-color:#000;background-color:rgba(0,0,0,.5)}.video-js .vjs-subtitles{color:#fff}.video-js .vjs-captions{color:#fc6}.vjs-tt-cue{display:block}.vjs-default-skin .vjs-hidden{display:none}.vjs-lock-showing{display:block!important;opacity:1;visibility:visible}.vjs-no-js{padding:20px;color:#ccc;background-color:#333;font-size:18px;font-family:Arial,sans-serif;text-align:center;width:300px;height:150px;margin:0 auto}.vjs-no-js a,.vjs-no-js a:visited{color:#F4A460}
```
样式中引用了几张图片，从锤子网http://www.smartisan.com/上下载就可以了
