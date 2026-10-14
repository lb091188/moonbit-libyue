# 系统能力（音量 / 应用查找 / 应用历史 / 影音与桌面控制）

系统能力族 API：系统音量、应用查找、夜间色温、壁纸、显示器配置、系统窗口管理、剪贴板监听、子进程执行、电源计划、系统信息、打印机、环境变量、目录枚举、最近文件、浏览器书签与 Firefox 历史、VS Code 本地历史。全部只读或经系统服务授权写入，统一返回 `Result`，不支持的环境给对应错误值而不是崩溃；`*_supported()` 每次调用真实探测当前环境。

## 平台状态（2026-10-15，mac 平台批①-⑤ 后）

> macOS 列的 **🚧 已接** = 代码在 `mac` 分支、CI 的 macOS job 证明编得过链得上，
> **真机目视/读数额外未回证**（清单在 `_人工测试清单.md` 的 T 节）；**❌ Unsupported**
> = 本批明确不做并让门面如实出声，两种都不等于「坏了」。

| 能力 | Windows | Linux | macOS |
|---|---|---|---|
| 剪贴板 / 自启动 / 子进程 / 文件(fsx) / 环境变量(envx) | ✅ 直调 | ✅ | 🚧 已接（pbpaste/pbcopy + NSPasteboard 桩；LaunchAgents plist + `launchctl load/unload`） |
| 系统信息 / 壁纸 / 启动器（打开与定位） | ✅ 直调 | ✅ | 🚧 已接（`sw_vers`/`ioreg`/`sysctl` + 桩内 `host_statistics64`/`kern.boottime`；osascript 桌面图片，只动主屏；`open` / `open -R`） |
| 音量 / 打印机(列表+默认+打印) | ✅ 直调 | ✅ | 🚧 已接（osascript 的 `volume settings`，sink 名这条口给不到按契约置空；macOS 自带 CUPS，与 Linux 同走 `lpstat`/`lp`——声明过的选择，不是漏跑到 Linux 分支） |
| 用户空闲检测 | ✅ 直调 | ✅ | 🚧 已接（`CGEventSourceSecondsSinceLastEventType` 的 HID 系统态读数，不需辅助功能授权） |
| 应用查找 / 最近文件 | ✅ 直调 | ✅ | ❌ Unsupported（`.app` + Info.plist 扫描、sharedfilelist 的私有格式，另批做） |
| 窗口管理 / 电源计划 | ✅ 直调 | ✅ | ❌ Unsupported（Accessibility 要用户先授权 / `pmset` 对不上三值方案语义） |
| browser/vscode 数据 | ✅（LOCALAPPDATA 路径） | ✅ | ✅（`Library/Application Support/<厂商>/<产品>` 路径，平台批①-⑥ 时就已同步） |
| sysmonitor 进程数据 | ✅（自带 stub/sysmon.c） | ✅ | 本批未动（示例模块自带桩，mac 路径按该模块的 stub 注释待验） |
| 夜间色温（redshift/xrandr 命令线） | ❌ 无公开 API | ✅ | ❌ 无公开 API（CoreBrightness 私有） |
| 显示器枚举（monitor） | ❌ | ✅（xrandr） | 🚧 已接（CoreGraphics 直调：`CGGetOnlineDisplayList` / `CGDisplayBounds` / `CGDisplayCopyAllDisplayModes`；只列「在线」屏，输出名给不了按 `Built-in` / `Display-<id>` 给；读数一律物理像素，故 `MonitorInfo` 不需要缩放比字段） |

macOS 的公开口与底层（🚧 已接项）：`open`/`open -R`、`sw_vers`、`ioreg -rd1 -c IOPlatformExpertDevice`、`sysctl hw.model/hw.memsize/kern.boottime`、`osascript`（System Events 的 `volume settings` 与桌面图片）、`launchctl load/unload` + `~/Library/LaunchAgents/*.plist`、`lpstat`/`lp`，以及桩内的 `host_statistics64`、`CGEventSourceSecondsSinceLastEventType`、`CGGetOnlineDisplayList`/`CGDisplayBounds`/`CGDisplayCopyDisplayMode`/`CGDisplayCopyAllDisplayModes`/`CGDisplayScreenSize`。

Windows 直调的底层：SystemParametersInfoW（壁纸）、ShellExecuteW（启动/定位/打印）、PowerGet/SetActiveScheme、注册表（产品与 DMI 信息）、GlobalMemoryStatusEx、GetTickCount64、EnumWindows、EnumPrintersW、IAudioEndpointVolume（COM）、GetLastInputInfo。踩坑与头文件/链接要求见 [adaptation.md](adaptation.md) 各平台批条目。

完整演示见 `moon run NoahLiu/gui-examples/systemprobe`——点「读取系统能力」逐项呈现本机真实结果，不支持的能力显示对应错误文本。各能力在不同发行版 / 桌面环境的实测结论与原理（logind 路径、wpctl/pactl 差异、SQLite 库直读等）见 [adaptation.md](adaptation.md)。

## 系统音量

作用于默认输出设备（default sink）。后端自动探测：优先 wpctl（PipeWire/WirePlumber），不可用回退 pactl（pipewire-pulse / PulseAudio），两者都不可用即 `Unsupported`。探测每次真实执行，高频场景请调用方自行缓存结果。

| 函数 | 说明 |
|---|---|
| `vol_supported() -> Bool` | 当前系统是否支持音量控制 |
| `vol_get() -> Result[VolumeInfo, VolumeError]` | 读快照：`VolumeInfo{ sink, volume, muted }`（sink 名取不到为空串，不影响音量与静音） |
| `vol_set(percent) -> Result[Unit, VolumeError]` | 设绝对音量（0-100，出界钳制） |
| `vol_add(delta) -> Result[Unit, VolumeError]` | 相对增减（正增负减，最终音量由工具侧钳制） |
| `vol_set_mute(mute) -> Result[Unit, VolumeError]` | 设 / 取消静音 |

错误 `VolumeError`：`Unsupported`（无可用音量工具）/ `CommandFailed(String)`（执行失败、超时等）/ `ParseFailed(String)`（输出解析失败，带原文）。

```moonbit
match @sys.vol_get() {
  Ok(v) =>
    println(
      "sink=\{v.sink} 音量=\{v.volume}% 静音=\{if v.muted { "是" } else { "否" }}",
    )
  Err(e) => println("不可用：\{e}")
}
let _ = @sys.vol_set(42)
let _ = @sys.vol_add(-5)
let _ = @sys.vol_set_mute(false)
```

## 应用查找

两部分：已装应用清单与应用二进制查找。Linux 扫描 XDG `.desktop` 条目（用户目录覆盖系统目录）；Windows 递归扫描开始菜单（用户级 + 全机级）的 `.lnk`，条目的 exec 为 lnk 全路径（ShellExecute 可直接启动）、categories 标 `StartMenu`；macOS `Unsupported`。

| 函数 | 说明 |
|---|---|
| `appfind_installed() -> Result[Array[AppEntry], AppFindError]` | 已装应用清单（真实扫描；全部扫描目录都不存在给 `NoScanDir`） |
| `appfind_installed_with(list_dir) -> Result[Array[AppEntry], AppFindError]` | 同上，目录枚举由调用方注入（供无 fsx 层的调用方与测试；仅 Linux 分支） |
| `appfind_executable(name) -> Result[String, AppFindError]` | Linux 在 `~/.local/bin`、`/usr/local/bin`、`/usr/bin`、`/bin`、`/usr/sbin`、`/sbin` 按序找；Windows 按 `PATH` 各目录找 name / name.exe；找不到给 `NotFound` |

`AppEntry{ id, name, locale_name, exec, icon, categories }`：id 为 desktop id（.desktop 文件名去扩展名）、name 为显示名、locale_name 为本地化名（`Name[zh_CN]` 优先回退 Name）、exec / icon 原样、categories 按分号拆分。结果按 desktop id 去重（用户目录覆盖系统目录）、按 name 排序；Type 非 Application、NoDisplay=true、缺 Name 的条目已滤除。

```moonbit
// 已装清单:注入目录列举函数(如自有的 readdir 封装)
match @sys.appfind_installed_with(fn(dir) { my_list_dir(dir) }) {
  Ok(apps) => for a in apps {
      println("\{a.locale_name}  \{a.exec}")
    }
  Err(e) => println("不可用：\{e}")
}
// 二进制查找
match @sys.appfind_executable("code") {
  Ok(path) => println("code 位于 \{path}")
  Err(@sys.AppFindError::NotFound(_)) => println("未安装")
  Err(_) => println("平台不支持")
}
```

## VS Code 本地历史与最近工作区

读取本机 VS Code 用户数据：某文件的本地历史快照列表（`User/History`）与最近打开的工作区 / 文件夹。三平台路径均已实现（Linux / macOS / Windows 各按其用户数据目录定位）。

| 函数 | 说明 |
|---|---|
| `vsc_supported() -> Bool` | 本机是否具备可读的 VS Code 用户数据 |
| `vsc_local_history(file_path) -> Result[Array[VscHistoryEntry], VscodeError]` | 某文件的历史快照（按时间倒序，新→旧）；传绝对路径或 `file://` URI 均可，无历史记录返回空数组 |
| `vsc_recent() -> Result[Array[String], VscodeError]` | 最近打开的工作区 / 文件夹路径（最近活动的在最前）；无窗口状态返回空数组 |

`VscHistoryEntry{ path, timestamp }`：path 为快照文件绝对路径（内容即该时刻文件全文），timestamp 为 Unix 毫秒，`timestamp_seconds()` 换算秒。错误 `VscodeError`：`Unsupported`（无法定位用户数据目录）/ `StorageUnavailable`（VS Code 从未在本机运行过）/ `StorageCorrupted(String)` / `HistoryCorrupted(String)`。

```moonbit
match @sys.vsc_local_history("/home/me/proj/src/main.mbt") {
  Ok(snaps) => for s in snaps {
      println("\{s.timestamp_seconds()}  \{s.path}")
    }
  Err(e) => println("不可用：\{e}")
}
match @sys.vsc_recent() {
  Ok(paths) => if paths.length() > 0 {
      println("最近工作区：\{paths[0]}")
    }
  Err(e) => println("不可用：\{e}")
}
```

## 浏览器历史与下载记录

只读读取 Chrome / Chromium / Edge / Brave 的 History 库（直接解析磁盘文件，不复制、不修改原库）；自动探测全部 profile（Default 与 Profile 1..24）。仅实现 Linux 路径探测，其余平台 `BhUnsupported`。

| 函数 | 说明 |
|---|---|
| `bh_supported() -> Bool` | 当前平台是否支持 |
| `bh_browsers() -> Result[Array[BrowserProfile], BrowserHistoryError]` | 列出有可读 History 库的 profile；无可读库给 `BhNoBrowser` |
| `bh_history(limit? = 200) -> Result[Array[HistoryItem], BrowserHistoryError]` | 浏览历史（聚合全部 profile，按最近访问时间降序，hidden 重定向条目已滤除）；limit ≤ 0 取全部 |
| `bh_downloads(limit? = 50) -> Result[Array[DownloadItem], BrowserHistoryError]` | 下载记录（按开始时间降序） |
| `bh_search(keyword, limit? = 50) -> Result[Array[HistoryItem], BrowserHistoryError]` | url 或 title 子串搜索（ASCII 大小写不敏感）；keyword 为空匹配一切 |
| `bh_download_state_name(state) -> String` | 下载状态数值 → 名称（进行中 / 完成 / 已取消 / 中断） |

`BrowserProfile{ browser, profile, history_path }`：browser 为 google-chrome / chromium / microsoft-edge / brave，profile 为目录名（Default 或 Profile N）。`HistoryItem{ url, title, visit_count, last_visit_time }`（时间为 Unix 毫秒，未知为 0）；`DownloadItem{ target_path, received_bytes, total_bytes, start_time, end_time, state }`。错误 `BrowserHistoryError`：`BhUnsupported` / `BhNoConfigDir` / `BhNoBrowser` / `BhIoFailed(String)`（单 profile 读失败跳过，全部失败才报错）。

```moonbit
match @sys.bh_history(limit=6) {
  Ok(items) => for it in items {
      let title = if it.title == "" { "(无标题)" } else { it.title }
      println("[\{it.visit_count}次] \{title}\n  \{it.url}")
    }
  Err(e) => println("不可用：\{e}")
}
match @sys.bh_downloads(limit=3) {
  Ok(ds) => for d in ds {
      println("\{d.target_path}  \{@sys.bh_download_state_name(d.state)}")
    }
  Err(_) => ()
}
let _ = @sys.bh_search("moonbit", limit=10)
```

## 媒体控制（MPRIS）

枚举会话总线上的 `org.mpris.MediaPlayer2.*` 播放器实例，播放控制（play / pause / play_pause / next / previous / stop）与状态读取（PlaybackStatus + Metadata 的 title / artist / album）走 MPRIS Player 接口；总线失败的播放控制可回退 `playerctl` 子命令（命令类回退路径）。目前仅实现 Linux 路径，其余平台一律 `Unsupported`。

| 函数 | 说明 |
|---|---|
| `media_supported() -> Bool` | 会话总线可用（ListNames 通）或 playerctl 可用 |
| `media_players() -> Result[Array[MediaPlayerInfo], MediaError]` | 枚举播放器实例（含 playerctld 代理实例），保持 ListNames 应答序；一个都没有给 `NoPlayer` |
| `media_status(player) -> Result[MediaStatus, MediaError]` | 读某播放器状态与当前曲目 |
| `media_play(player)` / `media_pause(player)` / `media_play_pause(player)` / `media_next(player)` / `media_previous(player)` / `media_stop(player)` | 播放控制（返回 `Result[Unit, MediaError]`） |

`MediaPlayerInfo{ name, identity }`：name 为总线名（`media_status` / 播放控制的入参），identity 为播放器显示名。`MediaStatus{ player, playback, title, artist, album }`，`MediaPlayback` 为 `MediaPlaying` / `MediaPaused` / `MediaStopped` / `MediaUnknown(String)`。错误 `MediaError`：`Unsupported` / `NoPlayer` / `BusFailed(String)`（带错误名与说明）/ `CommandFailed(String)`（playerctl 回退失败）/ `ParseFailed(String)`。

播放控制属设置类操作，只在调用方显式调用时执行，探测与查询路径不会触发。

```moonbit
match @dbus.media_players() {
  Ok(players) if players.length() > 0 => {
    let p = players[0].name
    match @dbus.media_status(p) {
      Ok(s) => println("\{s.title} - \{s.artist}（\{s.playback}）")
      Err(e) => println("读状态失败：\{e}")
    }
    let _ = @dbus.media_play_pause(p)
  }
  Err(@dbus.MediaError::NoPlayer) => println("无播放器")
  Err(e) => println("不可用：\{e}")
}
```

### 媒体状态监视

MPRIS 不提供统一的信号回调通路（总线可订阅 `PropertiesChanged`，但需要常驻读循环，与库的同步调用模型不兼容），状态监视采用轮询增量：按间隔读状态，播放态 / 标题 / 艺术家 / 专辑任一变化即触发 `on_change`；首轮只建立基线不触发；目标播放器（空 player 取首个实例）出现前每轮重试解析，出现后锁定；查询失败的轮次静默跳过。

| 函数 | 说明 |
|---|---|
| `MediaWatcher::make() -> MediaWatcher` | 建监视句柄（默认运行中） |
| `media_watch_status(player?, interval_ms? = 1000, on_change) -> MediaWatcher` | 启动轮询监视；player 为空监视首个 MPRIS 实例；on_change 得 `MediaStatus` |
| `media_watch_stop(w)` | 停止监视（下一帧注销定时器；不可恢复，重新监视请用新句柄） |
| `MediaWatcher::is_running() -> Bool` | 句柄是否在监视 |

`on_change` 回调抛异常会中断该定时器（先保证自身不抛）；组件销毁前调用 `media_watch_stop` 显式停止。

```moonbit
let w = @sys.media_watch_status(interval_ms=1000, fn(s : @sys.MediaStatus) {
  println("现在播放：\{s.title} - \{s.artist}")
})
// 不再关心时
@sys.media_watch_stop(w)
```

### 通知进度

桌面通知规范本身没有进度字段（freedesktop 通知协议无 progress，Windows / macOS 的原生进度呈现也各自为政），跨平台一致的做法是在正文内渲染字符进度条 + 百分比。

| 函数 | 说明 |
|---|---|
| `notification_progress_text(percent : Double, width? : Int = 10) -> String` | 进度文本：字符条 + 百分比（percent 钳到 [0,100]，NaN 按 0，width<=0 只给百分比） |
| `Notification::set_progress(body : String, percent : Double, width? : Int = 10) -> Unit` | 设通知正文：首行原文 + 第二行进度 |

```moonbit
let n = @core.Notification::new()
n.set_title("导出中")
n.set_progress("正在导出 3/8 个文件", 37.5, width=4)
n.show()
```

## 夜间色温

以百分比 0-100 表示色温（0 = 最暖、100 = 6500K 中性即不改动）。两条后端自动探测：`redshift` 存在时优先（`-P -O <K>` 一次性设色温），否则 `xrandr --output <首选输出> --gamma R:G:B`（蓝通道衰减越多越暖；绿通道恒 1.00）。

| 函数 | 说明 |
|---|---|
| `nl_supported() -> Bool` | redshift 或 xrandr 任一可用（探测均为只读调用，无副作用） |
| `nl_set_temperature(percent) -> Result[Unit, NightlightError]` | 设色温（0-100，出界钳制；redshift 路径 0→2500K / 100→6500K） |
| `nl_reset() -> Result[Unit, NightlightError]` | 复位（redshift `-x` / `xrandr --gamma 1.00:1.00:1.00`，不带 `--output` 作用于全部输出） |

错误 `NightlightError`：`Unsupported`（非 Linux，或 redshift 与 xrandr 均不可用、xrandr 无已连接输出）/ `CommandFailed(String)`。xrandr 路径的输出从当前主输出取，无主输出取首个已连接输出。

```moonbit
let _ = @sys.nl_set_temperature(30) // 偏暖
let _ = @sys.nl_reset()
```

## 壁纸

Windows 走 `SystemParametersInfoW（SPI_SETDESKWALLPAPER）` 直调。Linux 按桌面环境分派（DE 识别为 sys 包内自带的纯函数，即 `XDG_CURRENT_DESKTOP`）。**XFCE** 走 `xfconf-query` 读写 xfce4-desktop 频道的 `/backdrop/<screen>/monitor<输出>/<workspace>/last-image` 属性（多个显示器时取已连接输出）；**GNOME** 走 `gsettings` 读写 `org.gnome.desktop.background` 的 `picture-uri`（未设置回退 `picture-uri-dark`）；**KDE** 走 `qdbus6`/`qdbus` 调 plasmashell 的 `evaluateScript`（Plasma 脚本约定，本仓库未在 KDE 真机验证）。

| 函数 | 说明 |
|---|---|
| `wp_get() -> Result[String, WallpaperError]` | 读当前壁纸路径 |
| `wp_set(path) -> Result[Unit, WallpaperError]` | 设置壁纸（会改变桌面外观） |

错误 `WallpaperError`：`Unsupported`（Linux 上子进程不可用、KDE 的 qdbus 不在）/ `UnknownDesktop(String)`（非 XFCE/GNOME/KDE，带 `XDG_CURRENT_DESKTOP` 原文）/ `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`。XFCE 写入时属性不存在会创建。

```moonbit
match @sys.wp_get() {
  Ok(p) => println("当前壁纸：\{p}")
  Err(e) => println("读不到：\{e}")
}
let _ = @sys.wp_set("/home/me/Pictures/wall.png")
```

## 音频/视频播放（gui-media 可选层）

媒体播放不在 yue 核心包里（不引入 ffmpeg 依赖的人零成本），在可选模块 `NoahLiu/gui-media`（依赖 `NoahLiu/ffmpeg-mbt` 的 FFI 绑定）：

```moonbit
// moon.mod import: "NoahLiu/gui-media@0.1.0"
// moon.pkg import: "NoahLiu/gui-media/src" @yuemedia
```

解码走 ffmpeg FFI（进程内动态链，格式随系统 ffmpeg：MP3/OGG/M4A/AAC/FLAC/WAV…），输出设备由内嵌 miniaudio 设备层直出（s16 PCM 队列，零重采样）。无输出设备环境（CI/headless）自动静音降级，状态机照常。

### AudioPlayer（对标浏览器 `<audio>`）

```moonbit
let player = @yuemedia.AudioPlayer::make("/path/song.mp3")?
player.play()
let view = @yuemedia.audio_player_t(player)  // 播放/暂停/进度/时间/音量/循环控制条
```

| API | 说明 |
|---|---|
| `AudioPlayer::make(path, volume?=0.8, looping?=false)` | 打开音频文件（ffmpeg 全格式）+ 输出设备 |
| `play() / pause() / stop() / seek(t_s)` | 播放控制（seek 清队列重定位，播放中从新位置续播） |
| `pump()` | 推进一步（补 PCM 队列/播完转态）——组件 50ms 时钟自动调，独立使用时自行定时调 |
| `is_playing() / current() / duration() / has_audio 对应 is_muted()` | 状态/位置（按设备已消费字节换算）/时长/静音降级查询 |
| `set_volume(0..1) / get_volume / set_looping` | 音量与循环 |
| `free()` | 释放（之后组件时钟自动停摆） |

### 视频帧源视图（yue 核心，零依赖）

视频帧渲染走「帧源回调产出 RGBA 字节 → `pngr_encode_rgba` 内存编码为 PNG → `Image::new_from_png` 解码 → `Painter::draw_image` 铺满」：把内存里的 RGBA 经 PNG 编码再解码，是纯 MoonBit 的中转通道（stored 压缩，合法 zlib 流，小分辨率够用）。解码器与本组件解耦——任何帧源（未来的 moonav1 / 平台解码器）按帧号提供 RGBA 即可接入。

| 函数 | 说明 |
|---|---|
| `video_view_t(width, height, frame_count, source, fps?=30, looping?=false, handle?, fill?, style?, on_ready?)` | 视频视图；帧缺失/解码失败画主题底色占位，不中断播放 |
| `vid_pause(handle)` / `vid_resume(handle)` / `vid_stop(handle)` | 暂停/恢复/停止（stop 后定时器下一帧注销，不可恢复；**卸载组件前必须 vid_stop**——帧推进定时器无取消 id，漏 stop 会继续对已销毁的视图空转到播完） |
| `VidHandle::make()` / `is_running()` / `is_paused()` | 播放句柄 |
| `vid_frame_image(source, idx, w, h)` | 单体帧 → Image（长度校验+编码+解码，失败 None） |
| `pngr_encode_rgba(data, w, h)` | RGBA → PNG（Result；尺寸/长度不符 Err） |

```moonbit
// 帧源：按帧号产出 RGBA（此处 320x240 每帧变色示意）
fn source(i : Int) -> Bytes? {
  let px = FixedArray::make(320 * 240 * 4, (i * 7 % 255).to_byte())
  Some(Bytes::from_array(px))
}
let view = @yuemedia.video_view_t(320, 240, 120, source, fps=30)
```

### VideoPlayer（对标浏览器 `<video>`）

FFI 全链路：视频流逐帧 RGBA（时间戳级 seek），音轨是同文件的第二个独立解码器（读游标互不干扰）解出 PCM 直推输出设备——无 CLI 子进程。无音轨/无输出设备自动静音。

```moonbit
let player = @yuemedia.VideoPlayer::make("demo.mp4", fps=12, width=480)?
player.play()
let view = @yuemedia.video_player_t(player)
```

| API | 说明 |
|---|---|
| `VideoPlayer::make(path, fps?=12, width?=0, height?=0, volume?=0.8, looping?=false)` | 打开视频（含音轨双解码器；同步耗时，宜放 `set_timeout`） |
| `play() / pause() / stop() / seek(t_s)` | 播放控制（seek 双流各自重定位续播） |
| `is_playing() / current() / duration() / has_audio()` | 状态/位置/时长/音轨查询 |
| `current_frame() / frame_width() / frame_height()` | 当前帧 RGBA（自渲染场景） |
| `set_volume / set_looping / free()` | 音量/循环/释放 |

控制条组件（video_player_t / audio_player_t 同风格）：播放/暂停按钮、可拖进度条（松手防抖 180ms 后 seek）、时间文本（m:ss / m:ss）、音量滑条、循环开关；50ms 时钟自动 pump + 刷新，`free()` 后时钟自动停摆。

systemprobe 启动即自动载入演示播放器，播放/暂停/拖进度/音量/循环全部可交互。

## 显示器配置

Linux 解析 `xrandr --query` 输出，macOS 直调 CoreGraphics（`CGGetOnlineDisplayList` 一家），两处都给出每个输出的名称 / 连接状态 / 当前分辨率 × 刷新率 / 位置 / 物理尺寸 / 支持的模式列表；分辨率与位置都是**物理像素**。刷新率以厘赫兹整数表示（×100，如 5995 = 59.95Hz），避免浮点解析与比较。

| 函数 | 说明 |
|---|---|
| `mon_list() -> Result[Array[MonitorInfo], MonitorError]` | 枚举显示器输出，保持后端顺序 |
| `mon_current() -> Result[Array[CurrentOutput], MonitorError]` | 当前输出简化快照（已连接且有当前模式），不含模式列表 |

`MonitorInfo{ name, connected, primary, width, height, refresh_centi, pos_x, pos_y, mm_width, mm_height, modes }`；`MonitorMode{ width, height, refresh_centi, preferred, current }`；`CurrentOutput{ name, width, height, refresh_centi, pos_x, pos_y }`。错误 `MonitorError`：`Unsupported`（Windows，或 macOS 上探不到在线显示器 / 非 macOS 平台的探测）/ `CommandFailed(String)`（Linux 的 xrandr 起不来或退出码非零）/ `ParseFailed(String)`（一条输出都没有）。

macOS 侧三条读数差异：`connected` 恒真（macOS 没有「接了但关掉」的公开清单，离线屏不出现在表里）；`name` 是 `Built-in`（内建屏）或 `Display-<CGDirectDisplayID>`（其余）——公开的 CG 接口没有显示器名，`NSScreen.localizedName` 属于 ObjC 侧；`refresh_centi` 在内建面板的部分模式上给 0（后端报「未知」，不冒充数值），`mm_width`/`mm_height` 同档缺省时给 0。

```moonbit
match @sys.mon_current() {
  Ok(outs) => for o in outs {
      println("\{o.name}  \{o.width}x\{o.height}@\{o.refresh_centi / 100}Hz")
    }
  Err(e) => println("读不到：\{e}")
}
```

## 系统窗口管理

窗口列表（id / 桌面 / 主机 / 标题）、按 id 或标题激活、按标题关闭。Windows 走 `EnumWindows` / `SetForegroundWindow` / `WM_CLOSE` 直调；Linux 解析 `wmctrl -l` 并走其激活 / 关闭动作。不依赖 GUI 应用环境，普通 MoonBit 进程即可使用。

| 函数 | 说明 |
|---|---|
| `win_supported() -> Bool` | Windows 恒真；Linux 且 wmctrl 可用（wmctrl 缺失时 Unix 以退出码 127 呈现） |
| `win_list() -> Result[Array[WindowInfo], WinError]` | 窗口列表 |
| `win_activate(id_or_title) -> Result[Unit, WinError]` | 按窗口 id（wmctrl 的 `0x...` 十六进制）或标题激活 |
| `win_close(title) -> Result[Unit, WinError]` | 按标题关闭窗口 |

`WindowInfo{ id, desktop, host, title }`：id 可直接回传 `win_activate`；desktop 为窗口所在桌面，-1 为全部桌面（sticky）。错误 `WinError`：`Unsupported` / `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`。

激活与关闭会改变真实窗口状态（设置类）：接口完整实现，应用层只在用户操作时调用。

```moonbit
match @sys.win_list() {
  Ok(wins) => for w in wins { println("\{w.id}  \{w.title}") }
  Err(e) => println("不可用：\{e}")
}
let _ = @sys.win_activate("ZCode")   // 按标题
let _ = @sys.win_close("ZCode")
```

## 剪贴板监听

文本读写与变化监听。Windows 走 Win32 的 `CF_UNICODETEXT` 直调；Linux 优先 GtkClipboard（需宿主跑过 gtk_init，探测给 0 时退回命令线 `xclip`），文本内容变化时回调派发新文本。本模块是纯轮询实现，任意 MoonBit 进程可用、回调落在调用方上下文。

| 函数 | 说明 |
|---|---|
| `cbw_get_text() -> Result[String, ClipboardError]` | 读一次剪贴板文本（不可用 / 选区无文本为对应 Err） |
| `cbw_start_watch(interval_ms? = 800, cb) -> ClipboardWatcher` | 启动监听（轮询间隔钳 100..60000；基线取启动瞬间内容，初始内容不触发回调） |
| `cbw_stop(watcher)` | 停止监听（置停靠标志，至多再跑一拍自行终止；幂等） |

错误 `ClipboardError`：`Unsupported`（平台/后端都不可用）/ `CommandFailed(String)`。读失败静默跳过该拍，不触发回调。轮询挂在 GUI 定时器上，需在消息循环运行后才实际派发。

```moonbit
let w = @sys.cbw_start_watch(interval_ms=500, fn(text) {
  println("剪贴板新内容：\{text}")
})
// ……需要时
@sys.cbw_stop(w)
```

## 电源计划

经 `powerprofilesctl` 三条命令读可用计划集、读当前计划、切换计划（`power-profiles-daemon` 未安装时 shell 以退出码 127 呈现 → `PpUnsupported`）。

| 函数 | 说明 |
|---|---|
| `pp_supported() -> Bool` | powerprofilesctl 存在且可查询 |
| `pp_profiles() -> Result[Array[PowerProfile], PowerProfileError]` | 可用计划列表（按后端输出序，推荐序在前时即推荐序） |
| `pp_current() -> Result[PowerProfile, PowerProfileError]` | 当前计划 |
| `pp_set(profile) -> Result[Unit, PowerProfileError]` | 切换计划（有副作用、需要认证，调用方自行走授权流程） |

`PowerProfile`：`PPerformance`（性能）/ `PBalanced`（均衡）/ `PPowerSaver`（省电）。错误 `PowerProfileError`：`PpUnsupported` / `PpCommandFailed(String)` / `PpParseFailed(String)`。

```moonbit
match @sys.pp_profiles() {
  Ok(profiles) if profiles.contains(@sys.PBalanced) => {
    let _ = @sys.pp_set(@sys.PBalanced)
  }
  _ => ()
}
```

## 系统信息

只读 `/proc` 与 `/sys` 文本：发行版标识（`/etc/os-release`）、机器 DMI 标识（`/sys/class/dmi/id/`）、物理内存（`/proc/meminfo`）、开机时长（`/proc/uptime`）。非 Linux 一律 `Unsupported`；读不到（文件不存在 / 权限不足）给 `Err` 并带路径，不糊弄成空串。

| 函数 | 说明 |
|---|---|
| `si_os() -> Result[OsInfo, SysInfoError]` | 发行版：`OsInfo{ pretty_name, id, version_id }` |
| `si_machine() -> Result[MachineInfo, SysInfoError]` | 机器：`MachineInfo{ vendor, product, serial }`（序列号多数发行版仅 root 可读，读不到给 `Err`） |
| `si_memory() -> Result[MemoryInfo, SysInfoError]` | 内存：`MemoryInfo{ total_kb, available_kb }`（单位 kB，MemAvailable 为「还能拿来用多少」的实口径） |
| `si_uptime() -> Result[Double, SysInfoError]` | 开机时长（秒） |

错误 `SysInfoError`：`SiUnsupported`（非 Linux）/ `SiReadFailed(String)`（带路径）/ `SiParseFailed(String)`。

```moonbit
let os = @sys.si_os() // Ok({ pretty_name: "Ubuntu 24.04.5 LTS", id: "ubuntu", .. })
let mem = @sys.si_memory()
let up = @sys.si_uptime() // Ok(84088.08)
```

## 打印机

Windows 走 winspool 直调（`EnumPrintersW` 列表 + `GetDefaultPrinterW` 默认名）与 `ShellExecuteW`「print」动词打印；Linux 经 `lpstat` 读打印机列表（`-p`）与默认打印机（`-d`）、`lp` 提交打印任务。未装 CUPS（lpstat 以退出码 127 呈现）→ `PrtUnsupported`，属合法降级。

| 函数 | 说明 |
|---|---|
| `prt_supported() -> Bool` | Windows 看 winspool 列表可取；Linux 看 lpstat 可用 |
| `prt_list() -> Result[Array[PrinterInfo], PrinterError]` | 打印机列表（名称 + 可用状态） |
| `prt_default() -> Result[String, PrinterError]` | 默认打印机名 |
| `prt_print(printer? = "", path, copies? = 1) -> Result[Unit, PrinterError]` | 提交打印任务（Linux 用系统默认打印机当 printer 缺省；Windows 走「print」动词、不支持份数参数；有副作用，真实排队打印） |

`PrinterStatus`：`Idle` / `Printing` / `Paused`（暂停接新任务）/ `Disabled`；`prt_status_available(status)` 判是否可用接任务。`PrinterInfo{ name, status }`。错误 `PrinterError`：`PrtUnsupported` / `PrtCommandFailed(String)` / `PrtParseFailed(String)` / `PrtInvalidParam(String)`（文件路径为空、份数 < 1）。

```moonbit
match @sys.prt_default() {
  Ok(name) => {
    let _ = @sys.prt_print(printer=name, path="/tmp/doc.pdf")
  }
  Err(e) => println("无默认打印机：\{e}")
}
```

## 环境变量与目录枚举

两块小原语：进程内环境变量读写与环境变量删（`envx`，读走 `core/env`、写删走 C 层 setenv/unsetenv），目录枚举（`fsx`，C 层 opendir/readdir 或 Win32 FindFirstFileW）。

| 函数 | 用途 |
|---|---|
| `envx_get(name) -> String?` | 读（当前进程环境，取不到 None） |
| `envx_set(name, value) -> Result[Unit, EnvxError]` | 写（仅当前进程环境，之后 spawn 的子进程可见） |
| `envx_unset(name) -> Result[Unit, EnvxError]` | 删（本就不存在也视为成功，幂等） |
| `envx_common() -> Map[String, String]` | 常用集合：PATH / HOME / LANG / SHELL / USER 固定读取 + `XDG_*` 前缀扫描（环境里存在才收入） |
| `fsx_list_dir(path) -> Result[Array[String], FsError]` | 枚举目录子项名（不含 `.` `..`、不递归、含隐藏项） |
| `fsx_set_env(name, value, overwrite) -> Result[Unit, FsError]` | 写环境变量（overwrite=false 且已存在时保持原值，仍为 Ok） |
| `fsx_unset_env(name) -> Result[Unit, FsError]` | 删环境变量（envx_unset 的底层） |

语义为「进程内生效」——写只改当前进程环境，不触碰系统持久配置，也不影响父进程。错误：`EnvxError::ExInvalidParam(String)`（变量名空串）/ `ExFailed(String)`（C 层拒绝，如名含 '='）；`FsError::InvalidParam(String)` / `OpenFailed(String)`（目录打不开，带路径）/ `EnvFailed(String)`。`fsx_list_dir` 的已知边界：子项名本身含 '\n' 的极端文件名会被拆开（扁平文本编码）。

```moonbit
let path = @sys.envx_get("PATH")
let _ = @sys.envx_set("MY_FLAG", "1")
let _ = @sys.envx_unset("MY_FLAG")
match @sys.fsx_list_dir("/usr/share/applications") {
  Ok(names) => for n in names if n.ends_with(".desktop") { println(n) }
  Err(e) => println("打不开：\{e}")
}
```

## 最近文件（GTK recently-used.xbel）

解析 freedesktop 的 `recently-used.xbel`（GTK 应用经 GtkRecentManager / xdg-desktop-portal-gtk 统一写这份清单，Thunar / Nautilus / GIO 打开文件都会往里追加）。文件位置 `$XDG_DATA_HOME/recently-used.xbel`（缺省 `$HOME/.local/share/`）。XML 解析为手写薄扫描器：只取 bookmark 节点与 `bookmark:application` / `mime:mime-type` 子节点属性，属性值做 XML 实体解码，href 的 `file://` URI 做百分号解码；时间戳 ISO 8601 → Unix 毫秒。

| 函数 | 说明 |
|---|---|
| `rf_supported() -> Bool` | Linux 且文件可读 |
| `rf_recent(limit? = 100) -> Result[Array[RecentItem], RecentError]` | 最近文件列表（modified 倒序，并列按 path 升序）；limit ≤ 0 取全部 |
| `rf_by_app(name, limit? = 100) -> Result[Array[RecentItem], RecentError]` | 按应用名过滤（`bookmark:application` 的 name 精确匹配），同样倒序 |

`RecentItem{ uri, path, mime, added, modified, app_count }`：path 为 href 去 `file://` 前缀并百分号解码后的本地路径（非 file:// 方案给空串）、mime 为 MIME 类型（该 bookmark 无此节点给 None）、added / modified 为 Unix 毫秒（缺失或非法为 0）、app_count 为记录过该文件的应用个数。错误 `RecentError`：`RfUnsupported` / `RfNoDataDir` / `RfNoFile`（从未记录过）/ `RfParseFailed(String)`。解码与换算纯函数：`rf_xml_unescape` / `rf_percent_decode` / `rf_uri_to_path` / `rf_iso_to_unix_ms` / `rf_sort_recent`。

```moonbit
match @sys.rf_recent(limit=8) {
  Ok(items) => for it in items { println("\{it.path}  (\{it.modified})") }
  Err(e) => println("读不到：\{e}")
}
```

## 浏览器书签（Chrome 系）

只读解析 Chrome / Chromium / Edge / Brave 的 `Bookmarks` JSON 文件（不复制、不修改原文件）。JSON 解析复用同包手写解析器（整数字段保持 Int64 精度——Chrome 的 date_added 等以数值字符串存储，微秒值换算为 Unix 毫秒）；自动探测全部 profile（Default 与 Profile 1..24）。

| 函数 | 说明 |
|---|---|
| `bm_supported() -> Bool` | Linux（本文件仅实现 Linux 路径探测） |
| `bm_browsers() -> Result[Array[BookmarkProfile], BookmarkError]` | 列出有可读 Bookmarks 文件的 profile |
| `bm_bookmarks(browser) -> Result[BookmarkNode, BookmarkError]` | 指定浏览器的首个可读书签树（浏览器标识取 "google-chrome"/"chromium"/"microsoft-edge"/"brave"，profile 取 Default 优先、其次 Profile 1..24） |

`BookmarkProfile{ browser, profile, bookmarks_path }`；`BookmarkNode{ name, url?, children, added, root }`（added 为 Unix 毫秒、root 标注所属根 bookmark_bar / other / synced）——返回虚拟根树（名称 `"<浏览器>/<profile>"`，children 为三根合并），`BookmarkNode::is_folder()` / `is_url()` 分类，`bm_flatten(node)` 给先序扁平 url 书签列表。错误 `BookmarkError`：`BmUnsupported` / `BmNoConfigDir` / `BmNoBrowser` / `BmIoFailed(String)`。

```moonbit
match @sys.bm_bookmarks("google-chrome") {
  Ok(root) =>
    for n in @sys.bm_flatten(root) {
      println("\{n.name}  →  \{n.url}")
    }
  Err(e) => println("读不到：\{e}")
}
```

## Firefox 浏览历史

读取 `~/.mozilla/firefox/` 下各 profile 的 `places.sqlite`（`moz_places` 表，纯 MoonBit 读取，不复制、不修改原库）。条目复用 `browser_history.mbt` 的 `HistoryItem`（字段结构与 Chrome 历史一致），时间按 Firefox 的 Unix 纪元微秒 → 毫秒换算；排序 / 截断 / 取列同样复用该文件导出的纯函数。

| 函数 | 说明 |
|---|---|
| `ffx_supported() -> Bool` | profiles.ini 定位已实现 Linux / macOS / Windows |
| `ffx_profiles() -> Result[Array[FirefoxProfile], FirefoxHistoryError]` | 列出有可读 places.sqlite 的 profile |
| `ffx_history(limit? = 200) -> Result[Array[HistoryItem], FirefoxHistoryError]` | 浏览历史（聚合全部已探测 profile，按最近访问时间降序）；limit ≤ 0 取全部 |

`FirefoxProfile{ profile, places_path }`（profile 为 profiles.ini 的 `Path=` 目录名，绝对路径取末段）。hidden 条目（书签等）已滤除；单 profile 读失败跳过、全部失败给 `FfxIoFailed`。错误 `FirefoxHistoryError`：`FfxUnsupported` / `FfxNoProfile`（未安装或从未启动 Firefox）/ `FfxIoFailed(String)`。profiles.ini 缺失时回退固定候选名（default / default-release / default-esr / default-nightly / dev-edition-default），随机前缀命名的 profile 目录收不到。

```moonbit
match @sys.ffx_history(limit=10) {
  Ok(items) => for it in items { println("\{it.title}  \{it.url}") }
  Err(e) => println("读不到：\{e}")
}
```

## 共享基建：子进程执行 procrun

命令行类能力（音量、显示器、壁纸、夜间色温、打印机、电源计划、Firefox profile 定位）共用的「spawn → 限时回收 → 临时文件捕获 stdout/stderr」封装：命令名按 PATH 解析；子进程环境强制 C locale 使输出语言恒定可解析；退出码 0 归一为 `Ok`，非零退出归一为 `Err` 并携带 stderr，调用方无需再自行判码。

| 函数 | 说明 |
|---|---|
| `pr_available() -> Bool` | 当前平台是否支持子进程执行（Linux / macOS / Windows 三主平台为真，基于 sys 包自有 C 桩） |
| `pr_run(cmd, args, timeout_ms? = 5000) -> Result[ProcOutput, ProcError]` | 运行命令并归一结果（超时进程会被强制终止） |

`ProcOutput{ stdout, exit_code }`；错误 `ProcError`：`Unsupported`（非 Linux / macOS / Windows 主平台）/ `SpawnFailed(String)`（命令不存在按 Unix 惯例由子进程以退出码 127 呈现，归入非零退出）/ `Timeout(String)` / `NonZeroExit(Int, String)` / `Signaled(Int)`。

命令缺失与「存在但失败」是两种语义：前者在该模块自身通常归一为 `*Supported == false` 或 `Unsupported`（如 `PpUnsupported`、`PrtUnsupported`），后者是 `CommandFailed`——调用方按错误值分类处理即可。

```moonbit
match @sys.pr_run("wpctl", ["get-volume", "@DEFAULT_SINK@"]) {
  Ok(out) => println(out.stdout)
  Err(@sys.ProcError::NonZeroExit(_, err)) => println("失败：\{err}")
  Err(e) => println(e)
}
```

## 共享基建：通用 D-Bus 调用层（@dbus）

面向任意服务的方法调用与属性读写，是媒体控制（MPRIS）等模块的公共地基。连接复用 `bus.mbt` 的进程级会话 / 系统连接，编解码复用 `wire.mbt` 的线协议；同步调用 1.5 秒超时，应答超时给 `gdbus.timeout` 错误。

| 函数 | 说明 |
|---|---|
| `gdbus_call_session(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | 会话总线方法调用 |
| `gdbus_call_system(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | 系统总线方法调用 |
| `gdbus_get_property_session(dest, path, iface, prop)` / `gdbus_get_property_system(...)` | 读属性（走 `org.freedesktop.DBus.Properties.Get`，返回值已拆掉 variant 包裹） |
| `gdbus_set_property_session(dest, path, iface, prop, value)` / `gdbus_set_property_system(...)` | 写属性（走 `Properties.Set`；value 传裸值，variant 包裹在本层完成） |

值模型 `GDBusValue`：`GVNone`（无返回值，不能作调用参数）/ `GVBool` / `GVInt32` / `GVUInt32` / `GVInt64` / `GVU64`（'t'，udisks 的 Size/Time 等无符号 64 位）/ `GVDouble` / `GVString` / `GVPath`（'o'）/ `GVArray(元素签名, 元素表)` / `GVDict(a{sv}，值已拆掉 variant 包裹，Map 按插入序序列化)` / `GVVariant`（保持包裹）/ `GVStruct`。应答侧 `{sv}` 数组折成 `GVDict`，多返回值折成 `GVStruct`。错误 `GDBusError{ name, message }`：name 为 D-Bus 错误名或本地前缀 `gdbus.io`（连不上 / 已断开）/ `gdbus.timeout` / `gdbus.encode`。

```moonbit
match
  @dbus.gdbus_get_property_system(
    "org.freedesktop.timedate1",
    "/org/freedesktop/timedate1",
    "org.freedesktop.timedate1",
    "NTP",
  ) {
  Ok(@dbus.GVBool(on)) => println("NTP 开启：\{on}")
  Ok(_) => ()
  Err(e) => println("总线失败：\{e.name} \{e.message}")
}
```

## 边界

- 浏览器 History 库在浏览器运行中可能不断有新写入，读取结果是读入时刻的快照（不含尚未合并进主库的最新记录）。
- Firefox 的 places.sqlite 常处于 WAL 模式，本实现只读主库文件、尚未 checkpoint 进主库的最新浏览记录读不到；多 profile 聚合时同一 url 会各出现一次（与 Chrome 侧聚合口径一致）。
- `appfind_executable` 的命中判定为目录里有该名字的条目，不读文件内容、不校验执行权限位。
- 音量设置依赖对应系统服务在线（Windows IAudioEndpointVolume / Linux PipeWire-Pulse），服务缺席时写接口返回错误值，按错误值逐项处理即可。
- 打印 / 切电源计划是会改变系统真实状态的操作：接口完整实现，但只在用户显式操作时调用，不要在探测或查询路径里代为触发。
- 剪贴板监听与涟漪动画的定时器都由消息循环驱动且无取消 id（`set_timer`）：停止的途径是让回调返回 false，故句柄类 API（`cbw_stop` / `eff_stop`）应在组件卸载前显式调用。
