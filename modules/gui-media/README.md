# NoahLiu/gui-media

# [native-gui](https://mooncakes.io/docs/NoahLiu/native-gui) 的媒体扩展：在 native-gui 之上提供开箱即用的音视频播放组件，解码基于 [NoahLiu/ffmpeg-mbt](https://mooncakes.io/docs/NoahLiu/ffmpeg-mbt)（链接系统 ffmpeg），音频输出基于内嵌 miniaudio。

## 为什么是独立模块

媒体要链 ffmpeg 与 miniaudio，而 GUI 应用大多不需要。把它放在**独立模块**（而不是主模块的一个子包）是为了让主模块的**依赖闭包**里根本不出现 `ffmpeg-mbt`——只要你不 `moon add NoahLiu/gui-media`，就不会被拉上，连它的 prebuild 都不会跑。

（另一层「按需」是**子包边界**：`moon.pkg` 里没 import 的包不进二进制。两者不是一回事：子包边界管编译/链接，模块边界管依赖解析。）

## 包布局

| 包 | 内容 | 状态 |
|---|---|---|
| `NoahLiu/gui-media/media` | **新栈引擎**：ffmpeg 解码 + miniaudio 设备直出，帧以 RGBA 字节交出；含 `player_t` 播放器组件与字幕层 | 现行 |
| `NoahLiu/gui-media/src` | 旧链声明式播放器组件（`AudioPlayer`/`VideoPlayer`/`*_player_t`），挂在 0.5.11 旧链上 | 待 `systemprobe` 媒体页迁移后下线（见 `TODO.md`） |

## 安装

```sh
moon add NoahLiu/gui-media
```

需要系统已安装 ffmpeg 开发包（Ubuntu: `sudo apt install -y libavformat-dev libavcodec-dev libswscale-dev libswresample-dev libavutil-dev`）。

## 平台现状

| 平台 | 音频后端（miniaudio 设备层，零 ffmpeg 依赖） | ffmpeg 解码后端 |
|---|---|---|
| Linux | ✅ | ✅ |
| Windows | ✅ 可编译可运行（单调时钟走 `QueryPerformanceCounter`） | ⬜ 未接（`ffmpeg-mbt` 要 `libavformat/*` 头） |
| macOS | ⬜ 时钟分支已写（`mach_absolute_time`），未真机回证 | ⬜ 未接 |

**媒体包整体目前只能在 Linux 上构建与测试。** 音频后端的 C 部分已跨平台（Windows 下由纯 C 探针 `experiment/media_probe/audio_backend_probe.c` 回证），但本包 import `ffmpeg-mbt`，测试可执行文件会把它一并链进来，所以非 Linux 上仍然编不过。

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

完整用法见 [gui-examples](https://github.com/lb091188/moonbit-native-gui/tree/master/modules/gui-examples) 的 systemprobe（媒体页）。

## 许可

MIT。内嵌 miniaudio 为公有领域（见源码头注释）。
