# NoahLiu/gui-media

# [native-gui](https://mooncakes.io/docs/NoahLiu/native-gui) 的媒体扩展：在 native-gui 之上提供开箱即用的音视频播放组件，解码基于 [NoahLiu/ffmpeg-mbt](https://mooncakes.io/docs/NoahLiu/ffmpeg-mbt)（链接系统 ffmpeg），音频输出基于内嵌 miniaudio。

## 为什么是独立模块

媒体要链 ffmpeg 与 miniaudio，而 GUI 应用大多不需要。把它放在**独立模块**（而不是主模块的一个子包）是为了让主模块的**依赖闭包**里根本不出现 `ffmpeg-mbt`——只要你不 `moon add NoahLiu/gui-media`，就不会被拉上，连它的 prebuild 都不会跑。

（另一层「按需」是**子包边界**：`moon.pkg` 里没 import 的包不进二进制。两者不是一回事：子包边界管编译/链接，模块边界管依赖解析。）

## 包布局

本模块只有一个包：

| 包 | 内容 |
|---|---|
| `NoahLiu/gui-media/media` | ffmpeg 解码 + miniaudio 设备直出的引擎（`AudioPlayer` / `VideoPlayer` / `Demuxer` 之上的字幕层与 LRC 歌词层、纯 MoonBit 的实时频谱分析），以及两个节点组件 `video`（含音轨与字幕叠加）与 `audio`（纯音频，含歌词与频谱条） |

两条时钟不同轴：`player_t` 的位置是墙钟 + 帧时间戳，`audio_player_t` 的是设备已消费字节。所以带视频轨的文件走前者、纯音频走后者，组件之间不互相代打。

## 安装

```sh
moon add NoahLiu/gui-media
```

需要系统已安装 ffmpeg 开发包（Ubuntu: `sudo apt install -y libavformat-dev libavcodec-dev libswscale-dev libswresample-dev libavutil-dev`）。

## 平台现状

| 平台 | 音频后端（miniaudio 设备层，零 ffmpeg 依赖） | ffmpeg 解码后端 |
|---|---|---|
| Linux | ✅ | ✅（pkg-config 探系统 libav*） |
| Windows | ✅ 可编译可运行（单调时钟走 `QueryPerformanceCounter`） | ✅ vendor dev 包真链接；vendor 缺失时 prebuild 降级空 link_configs 保可构建，CI 的 Windows job 装运行库跑**真解码**测试 |
| macOS | ⬜ 时钟分支已写（`mach_absolute_time`），未真机回证 | ❌ 未接（无 vendor 内容，门面给语义化降级） |

**媒体包整体目前只能在 Linux 上构建与测试。** 音频后端的 C 部分已跨平台（Windows 下由纯 C 探针 `experiment/media_probe/audio_backend_probe.c` 回证），但本包 import `ffmpeg-mbt`，测试可执行文件会把它一并链进来，所以非 Linux 上仍然编不过。

## 快速上手

组件层（节点组件，自带控制条；名字对齐 HTML 的 `<audio>` / `<video>`）：

```moonbit
// 纯音频：播放/进度/-5s·+5s 跳转/音量/倍速；lyric 传已读好的 LRC 文本
let a = @media.audio("music.mp3", lyric=lrc_text, width=560.0, auto_play=true, on_error=fn(e) { .. })

// 视频：画面 + 音轨 + 字幕叠加（subtitle 传已读好的 SRT/VTT 文本，留空则试容器内嵌轨）
let v = @media.video("demo.mp4", width=640.0, height=360.0, auto_play=true)
```

两个组件都返回 `@core.Node`，直接挂进声明式树即可；观测口 `on_tick`/`on_speed`/`on_subtitle`/`on_lyric` 给位置、档位、字幕来源与歌词行数，调用方不必读引擎内部状态。打不开时不抛异常——画说明板并把原因经 `on_error` 交出去。

控制条（两个组件同一份实现，`media/control_bar.mbt`）：左边一排真按钮——播放/暂停与全屏是图标按钮（悬停浅底、进 Tab 链、有焦点环），倍速与缩放是文字按钮（图标说不清「1.25x」和「铺满」），右边是自绘的进度轨 + 音量条 + 时间文字。进度**抬手才 seek**（真 seek 要回退关键帧），音量**每步生效**。视频另有缩放三档循环：适配（等比居中留黑边）→ 铺满（取大边，超出由控件裁掉）→ 1:1（原始像素）。

快捷键走 `App::add_key_fallthrough` 的**窗口级兜底通道**，不点窗口也生效：空格播放/暂停、回车全屏、`←`/`→`（音频 ±5 秒、视频逐帧）、`↑`/`↓` 音量、`Esc` 退全屏。焦点在输入框里时按键被编辑器吃掉，播放器不抢字；换载摘掉的播放器靠 `Widget::is_painted()` 自证活体，不再吃键。

外部文本（`.lrc` / `.srt`）由调用方读好喂进来，组件不做 IO；解析本身可单用：`@media.lrc_parse(text)` 给 `Lrc`（排好序的 `cues` + `ti/ar/al/by` 元信息），`@media.lrc_at(l, 秒)` 取当前行。

频谱条默认开着（`spectrum=false` 关掉）：引擎在每段 PCM 推给设备前经 `pcm_tap` 转一份出来，`@media.Spectrum` 加 Hann 窗做 1024 点 radix-2 FFT、转 dB 后按对数频段分 24 条，快起慢落。取样点比耳朵快一个队列深度（约 0.23 秒），绘制时按 `AudioPlayer::queued_frames` 往回看同样多的帧补回来。

引擎层（不用组件、自己驱动时钟时）：

```moonbit
let player = @media.AudioPlayer::make("music.mp3")!
player.play()
// 组件定时器里每 33ms 调一次 player.pump()

let vp = @media.VideoPlayer::make("demo.mp4")!
vp.play()
// 每 33ms 调一次 vp.tick()，帧从 vp.current_frame() 取 RGBA 字节
```

## 示例

完整用法见 [gui-examples](https://github.com/lb091188/moonbit-native-gui/tree/master/modules/gui-examples) 的 `audio`（播放列表 + 选文件/选目录扫描）与 `video`（侧栏列表 + 字幕双来源）两个示例。

## 许可

MIT。内嵌 miniaudio 为公有领域（见源码头注释）。
