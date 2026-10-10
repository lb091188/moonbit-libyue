# NoahLiu/yue-media

[moonbit-libyue](https://mooncakes.io/docs/NoahLiu/moonbit-libyue) 的媒体扩展：在 yue GUI 之上提供开箱即用的音视频播放组件，解码基于 [NoahLiu/ffmpeg-mbt](https://mooncakes.io/docs/NoahLiu/ffmpeg-mbt)（链接系统 ffmpeg），音频输出基于内嵌 miniaudio。

## 安装

```sh
moon add NoahLiu/yue-media
```

需要系统已安装 ffmpeg 开发包（Ubuntu: `sudo apt install -y libavformat-dev libavcodec-dev libswscale-dev libswresample-dev libavutil-dev`）。

## 快速上手

音频播放：

```moonbit
let player = @yuemedia.AudioPlayer::make("music.mp3")!
player.play()
```

视频播放：

```moonbit
let vp = @yuemedia.VideoPlayer::make("demo.mp4")!
vp.play()
```

接入声明式 UI（节点组件，带进度/控制条）：

```moonbit
@yuemedia.audio_player_t(player, style=[("width", 360.0)], on_event=fn(ev) { .. })
@yuemedia.video_player_t(vp, style=[("width", 640.0), ("height", 360.0)])
```

## 示例

完整用法见 [yue-examples](https://github.com/lb091188/moonbit-libyue/tree/master/modules/yue-examples) 的 systemprobe（媒体页）。

## 许可

MIT。内嵌 miniaudio 为公有领域（见源码头注释）。
