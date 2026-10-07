# 系统能力（音量 / 亮度 / 应用查找 / 应用历史 / 影音与桌面控制）

系统能力族 API：屏幕亮度、键盘背光、系统音量（含输出设备与逐应用音量）、媒体播放控制、夜间色温、壁纸、显示器配置、系统窗口管理、剪贴板监听、子进程执行、磁盘卷、电源与登录会话、电源计划、系统信息、时区与本地语言、蓝牙、传感器、打印机、环境变量、目录枚举、最近文件、浏览器书签与 Firefox 历史、媒体状态监视与通知进度文本。全部只读或经系统服务授权写入，统一返回 `Result`，不支持的环境给对应错误值而不是崩溃；`*_supported()` 每次调用真实探测当前环境。

完整演示见 `moon run examples/systemprobe`——点「读取系统能力」逐项呈现本机真实结果，不支持的能力显示对应错误文本。各能力在不同发行版 / 桌面环境的实测结论与原理（logind 路径、wpctl/pactl 差异、SQLite 库直读等）见 [adaptation.md](adaptation.md)。

## 屏幕亮度

设备经 `brightness_devices()` 枚举（列表序即推荐序，原生驱动在前），读写以 `BrightnessDevice` 为句柄；读走 sysfs 只读，写走系统服务（logind）。

| 函数 | 说明 |
|---|---|
| `brightness_supported() -> Bool` | 当前环境是否可设置亮度（读枚举 / 当前值不依赖它） |
| `brightness_devices() -> Result[Array[BrightnessDevice], BrightnessError]` | 枚举背光设备；空列表 = 无背光或设备名不在探测表 |
| `brightness_get(dev) -> Result[Int, BrightnessError]` | 当前亮度百分比（0-100，实时读） |
| `brightness_set_percent(dev, percent) -> Result[Unit, BrightnessError]` | 设百分比（0-100，出界报错） |
| `brightness_step_percent(dev, delta) -> Result[Unit, BrightnessError]` | 按百分比步进（delta 可正可负，加后钳 0-100） |

`BrightnessDevice{ subsystem, name, max, current }`：subsystem 为 `"backlight"`（屏幕）、name 为 sysfs 设备名、max 为量程上限、current 为枚举时快照（实时值用 `brightness_get`）。设备名不在探测表时可手工构造 `BrightnessDevice` 访问。错误 `BrightnessError`：`Unsupported`（非 Linux 或系统服务不在线）/ `BusFailed(String)` / `DeviceNotFound` / `InvalidParam(String)`。

```moonbit
match @yue.brightness_devices() {
  Ok(devs) if devs.length() > 0 =>
    match @yue.brightness_set_percent(devs[0], 50) {
      Ok(_) => println("已设为半亮")
      Err(e) => println("失败：\{e}")
    }
  Ok(_) => println("无背光设备")
  Err(e) => println("不可用：\{e}")
}
```

## 键盘背光

与屏幕亮度同构，仅子系统不同（`"leds"`），设备名形如 `input3::kbd_backlight`。

| 函数 | 说明 |
|---|---|
| `kbd_brightness_supported() -> Bool` | 当前环境是否可设置（有无键盘背光以 `kbd_brightness_devices` 空列表判） |
| `kbd_brightness_devices() -> Result[Array[BrightnessDevice], BrightnessError]` | 枚举键盘背光设备；空列表 = 无键盘背光 |
| `kbd_brightness_get(dev) -> Result[Int, BrightnessError]` | 当前百分比（0-100） |
| `kbd_brightness_set_percent(dev, percent) -> Result[Unit, BrightnessError]` | 设百分比（0-100） |
| `kbd_brightness_step_percent(dev, delta) -> Result[Unit, BrightnessError]` | 按百分比步进 |

```moonbit
match @yue.kbd_brightness_devices() {
  Ok(devs) if devs.length() > 0 => {
    let _ = @yue.kbd_brightness_set_percent(devs[0], 80)
    let _ = @yue.kbd_brightness_step_percent(devs[0], -10) // 步进减 10%
  }
  _ => println("无键盘背光")
}
```

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
match @yue.vol_get() {
  Ok(v) =>
    println(
      "sink=\{v.sink} 音量=\{v.volume}% 静音=\{if v.muted { "是" } else { "否" }}",
    )
  Err(e) => println("不可用：\{e}")
}
let _ = @yue.vol_set(42)
let _ = @yue.vol_add(-5)
let _ = @yue.vol_set_mute(false)
```

### 音量增强（输出设备与逐应用音量 volx_）

`volx_` 前缀的第二组能力：设备枚举、默认设备切换、逐应用播放流音量。这一组依赖 pactl（wpctl 无等价的设备枚举与逐流接口），单独探测门控，探测失败不影响 `vol_` 组行为。

| 函数 | 说明 |
|---|---|
| `volx_devices() -> Result[Array[AudioDevice], VolumeError]` | 枚举输出设备（`pactl list short sinks` 取名 + `list sinks` 补描述 + `get-default-sink` 标默认）；无 pactl 或服务不在线为 `Unsupported`，空列表 = 服务在线但无输出设备 |
| `volx_set_default(name) -> Result[Unit, VolumeError]` | 切换默认输出设备（name 取上面枚举出的 `AudioDevice.name`，空名给 `CommandFailed`） |
| `volx_app_streams() -> Result[Array[AppStream], VolumeError]` | 枚举逐应用播放流（`pactl list sink-inputs`），无播放流为空列表 |
| `volx_set_app_volume(index, percent) -> Result[Unit, VolumeError]` | 设单个应用播放流音量（0-100，出界钳制；index 取枚举出的 `AppStream.index`，负序号为 `CommandFailed`） |
| `volx_set_app_mute(index, mute) -> Result[Unit, VolumeError]` | 设 / 取消单个应用播放流静音 |

`AudioDevice{ name, description, is_default }`（name 为 pactl 节点名，是 `volx_set_default` 的入参；description 为人类可读名）；`AppStream{ index, app_name, volume, muted }`（app_name 取 `application.name` 属性，缺省回落 `node.name`，再缺省 `"unknown"`；volume 为 0-100，各声道不一致取最响）。错误沿用 `VolumeError`。

```moonbit
match @yue.volx_devices() {
  Ok(devs) => for d in devs {
      println("\{d.description}（\{d.name}）\{if d.is_default { " ←默认" } else { "" }}")
    }
  Err(e) => println("不可用：\{e}")
}
match @yue.volx_app_streams() {
  Ok(streams) => for s in streams {
      println("\{s.app_name}  音量=\{s.volume}%")
    }
  Err(_) => ()
}
```

## 应用查找

两部分：已装应用清单（扫描 XDG `.desktop` 条目）与应用二进制查找（which 语义的固定目录版）。仅 Linux；macOS / Windows 无 XDG 桌面项体系，返回 `AppFindError::Unsupported`。

| 函数 | 说明 |
|---|---|
| `appfind_installed_with(list_dir) -> Result[Array[AppEntry], AppFindError]` | 已装应用清单；`list_dir : (String) -> Array[String]` 由调用方注入（收目录路径、返回该目录下文件名数组） |
| `appfind_executable(name) -> Result[String, AppFindError]` | 在 `~/.local/bin`、`/usr/local/bin`、`/usr/bin`、`/bin`、`/usr/sbin`、`/sbin` 中按序找名为 name 的文件，返回首个命中完整路径；找不到给 `NotFound` |

`AppEntry{ id, name, locale_name, exec, icon, categories }`：id 为 desktop id（.desktop 文件名去扩展名）、name 为显示名、locale_name 为本地化名（`Name[zh_CN]` 优先回退 Name）、exec / icon 原样、categories 按分号拆分。结果按 desktop id 去重（用户目录覆盖系统目录）、按 name 排序；Type 非 Application、NoDisplay=true、缺 Name 的条目已滤除。

```moonbit
// 已装清单:注入目录列举函数(如自有的 readdir 封装)
match @yue.appfind_installed_with(fn(dir) { my_list_dir(dir) }) {
  Ok(apps) => for a in apps {
      println("\{a.locale_name}  \{a.exec}")
    }
  Err(e) => println("不可用：\{e}")
}
// 二进制查找
match @yue.appfind_executable("code") {
  Ok(path) => println("code 位于 \{path}")
  Err(@yue.AppFindError::NotFound(_)) => println("未安装")
  Err(_) => println("平台不支持")
}
```

## 默认应用查询

查询文件类型与 MIME 类型的默认应用、枚举某类型的全部关联应用，以及设置默认应用。查询走 `xdg-mime`（PATH 探测），关联枚举直读三层 `mimeapps.list`（XDG mimeapps 规范：用户配置 `~/.config/mimeapps.list` 优先、`~/.local/share/applications/mimeapps.list` 次之、`/usr/share/applications/mimeapps.list` 兜底）。仅 Linux。

| 函数 | 说明 |
|---|---|
| `da_supported() -> Bool` | `xdg-mime` 是否在 PATH |
| `da_file_type(path) -> Result[String, DefaultAppError]` | 推断文件 MIME 类型（`xdg-mime query filetype`） |
| `da_default_for(mime) -> Result[String, DefaultAppError]` | 查默认应用（`.desktop` 名）；命令不可用或无结果时回退解析 mimeapps.list 的 `[Default Applications]` 段（同名多行按规范后写覆盖，取最后一个） |
| `da_associations_for(mime) -> Array[String]` | 某类型的全部关联 `.desktop` 名（去重；`[Default Applications]` 与 `[Added Associations]` 两段合并） |
| `da_set_default(mime, desktop_id) -> Result[Unit, DefaultAppError]` | 把 `mime=desktop_id` 写入用户 `~/.config/mimeapps.list` 的 `[Default Applications]` 段：已有该 MIME 行则替换、否则段内追加、段不存在则新建；desktop_id 必须以 `.desktop` 结尾 |

错误类型：`Unsupported`（无 xdg-mime）、`QueryFailed`（命令失败）、`NoDefault`（该类型无登记）、`IoFailed`（读写失败）。

```moonbit
// 文件类型与默认应用
match @yue.da_file_type("/home/me/report.pdf") {
  Ok(mime) => {
    println("类型：\{mime}")
    match @yue.da_default_for(mime) {
      Ok(desktop) => println("默认应用：\{desktop}")
      Err(_) => println("没有默认应用")
    }
  }
  Err(e) => println("查询失败：\{e}")
}
// 枚举关联应用、设置默认（set 是改变系统状态的操作，由用户显式触发）
let apps = @yue.da_associations_for("text/html")
@yue.da_set_default("text/html", "firefox.desktop")
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
match @yue.vsc_local_history("/home/me/proj/src/main.mbt") {
  Ok(snaps) => for s in snaps {
      println("\{s.timestamp_seconds()}  \{s.path}")
    }
  Err(e) => println("不可用：\{e}")
}
match @yue.vsc_recent() {
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
match @yue.bh_history(limit=6) {
  Ok(items) => for it in items {
      let title = if it.title == "" { "(无标题)" } else { it.title }
      println("[\{it.visit_count}次] \{title}\n  \{it.url}")
    }
  Err(e) => println("不可用：\{e}")
}
match @yue.bh_downloads(limit=3) {
  Ok(ds) => for d in ds {
      println("\{d.target_path}  \{@yue.bh_download_state_name(d.state)}")
    }
  Err(_) => ()
}
let _ = @yue.bh_search("moonbit", limit=10)
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
match @yue.media_players() {
  Ok(players) if players.length() > 0 => {
    let p = players[0].name
    match @yue.media_status(p) {
      Ok(s) => println("\{s.title} - \{s.artist}（\{s.playback}）")
      Err(e) => println("读状态失败：\{e}")
    }
    let _ = @yue.media_play_pause(p)
  }
  Err(@yue.MediaError::NoPlayer) => println("无播放器")
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
let w = @yue.media_watch_status(interval_ms=1000, fn(s : @yue.MediaStatus) {
  println("现在播放：\{s.title} - \{s.artist}")
})
// 不再关心时
@yue.media_watch_stop(w)
```

### 通知进度

桌面通知规范本身没有进度字段（freedesktop 通知协议无 progress，Windows / macOS 的原生进度呈现也各自为政），跨平台一致的做法是在正文内渲染字符进度条 + 百分比。

| 函数 | 说明 |
|---|---|
| `notification_progress_text(percent : Double, width? : Int = 10) -> String` | 进度文本：字符条 + 百分比（percent 钳到 [0,100]，NaN 按 0，width<=0 只给百分比） |
| `Notification::set_progress(body : String, percent : Double, width? : Int = 10) -> Unit` | 设通知正文：首行原文 + 第二行进度 |

```moonbit
let n = @yue.Notification::new()
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
let _ = @yue.nl_set_temperature(30) // 偏暖
let _ = @yue.nl_reset()
```

## 壁纸

按桌面环境分派（DE 识别复用 `@traybus.detect_desktop()`，即 `XDG_CURRENT_DESKTOP`）。**XFCE** 走 `xfconf-query` 读写 xfce4-desktop 频道的 `/backdrop/<screen>/monitor<输出>/<workspace>/last-image` 属性（多个显示器时取已连接输出）；**GNOME** 走 `gsettings` 读写 `org.gnome.desktop.background` 的 `picture-uri`（未设置回退 `picture-uri-dark`）；**KDE** 走 `qdbus6`/`qdbus` 调 plasmashell 的 `evaluateScript`（Plasma 脚本约定，本仓库未在 KDE 真机验证）。

| 函数 | 说明 |
|---|---|
| `wp_get() -> Result[String, WallpaperError]` | 读当前壁纸路径 |
| `wp_set(path) -> Result[Unit, WallpaperError]` | 设置壁纸（会改变桌面外观） |

错误 `WallpaperError`：`Unsupported`（非 Linux、子进程不可用、KDE 的 qdbus 不在）/ `UnknownDesktop(String)`（非 XFCE/GNOME/KDE，带 `XDG_CURRENT_DESKTOP` 原文）/ `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`。XFCE 写入时属性不存在会创建。

```moonbit
match @yue.wp_get() {
  Ok(p) => println("当前壁纸：\{p}")
  Err(e) => println("读不到：\{e}")
}
let _ = @yue.wp_set("/home/me/Pictures/wall.png")
```

## 显示器配置

解析 `xrandr --query` 输出，给出每个输出的名称 / 连接状态 / 当前分辨率 × 刷新率 / 位置 / 物理尺寸 / 支持的模式列表。刷新率以厘赫兹整数表示（×100，如 5995 = 59.95Hz），避免浮点解析与比较。

| 函数 | 说明 |
|---|---|
| `mon_list() -> Result[Array[MonitorInfo], MonitorError]` | 枚举全部输出（含未连接），保持 xrandr 顺序 |
| `mon_current() -> Result[Array[CurrentOutput], MonitorError]` | 当前输出简化快照（已连接且有当前模式），不含模式列表 |

`MonitorInfo{ name, connected, primary, width, height, refresh_centi, pos_x, pos_y, mm_width, mm_height, modes }`；`MonitorMode{ width, height, refresh_centi, preferred, current }`；`CurrentOutput{ name, width, height, refresh_centi, pos_x, pos_y }`。错误 `MonitorError`：`Unsupported`（非 Linux 或 xrandr 不可用）/ `CommandFailed(String)` / `ParseFailed(String)`（无任何输出条目）。

```moonbit
match @yue.mon_current() {
  Ok(outs) => for o in outs {
      println("\{o.name}  \{o.width}x\{o.height}@\{o.refresh_centi / 100}Hz")
    }
  Err(e) => println("读不到：\{e}")
}
```

## 系统窗口管理（X11）

解析 `wmctrl -l` 的窗口列表（窗口 id / 桌面 / 主机 / 标题），并按 id 或标题激活、按标题关闭窗口。不依赖 libyue GUI 应用环境，普通 MoonBit 进程即可使用（命令经 `pr_run` 执行）。

| 函数 | 说明 |
|---|---|
| `win_supported() -> Bool` | Linux 且 wmctrl 可用（wmctrl 缺失时 Unix 以退出码 127 呈现） |
| `win_list() -> Result[Array[WindowInfo], WinError]` | 窗口列表 |
| `win_activate(id_or_title) -> Result[Unit, WinError]` | 按窗口 id（wmctrl 的 `0x...` 十六进制）或标题激活 |
| `win_close(title) -> Result[Unit, WinError]` | 按标题关闭窗口 |

`WindowInfo{ id, desktop, host, title }`：id 可直接回传 `win_activate`；desktop 为窗口所在桌面，-1 为全部桌面（sticky）。错误 `WinError`：`Unsupported` / `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)`。

激活与关闭会改变真实窗口状态（设置类）：接口完整实现，应用层只在用户操作时调用。

```moonbit
match @yue.win_list() {
  Ok(wins) => for w in wins { println("\{w.id}  \{w.title}") }
  Err(e) => println("不可用：\{e}")
}
let _ = @yue.win_activate("ZCode")   // 按标题
let _ = @yue.win_close("ZCode")
```

## 剪贴板监听

经 `xclip` 只读轮询系统剪贴板（X11 CLIPBOARD 选区），文本内容变化时回调派发新文本。与 `methods.mbt` 里 libyue 原生 Clipboard 的 `start_watching` / `on_change` 分工：后者由 GUI 事件循环驱动（需 initialize 的应用环境），本模块是纯轮询实现，任意 MoonBit 进程可用、回调落在调用方上下文。

| 函数 | 说明 |
|---|---|
| `cbw_get_text() -> Result[String, ClipboardError]` | 读一次剪贴板文本（xclip 未装 / 选区无文本为对应 Err） |
| `cbw_start_watch(interval_ms? = 800, cb) -> ClipboardWatcher` | 启动监听（轮询间隔钳 100..60000；基线取启动瞬间内容，初始内容不触发回调） |
| `cbw_stop(watcher)` | 停止监听（置停靠标志，至多再跑一拍自行终止；幂等） |

错误 `ClipboardError`：`Unsupported`（非 Linux 或 xclip 不存在）/ `CommandFailed(String)`。读失败静默跳过该拍，不触发回调。轮询挂在 libyue 定时器上，需在 GUI 消息循环运行后才实际派发。

```moonbit
let w = @yue.cbw_start_watch(interval_ms=500, fn(text) {
  println("剪贴板新内容：\{text}")
})
// ……需要时
@yue.cbw_stop(w)
```

## 磁盘卷管理

枚举可挂载卷、挂载与卸载。Linux 优先走 udisks2 D-Bus（系统总线 `org.freedesktop.UDisks2`：Manager 列块设备、Block 取设备 / 卷标 / 容量 / 可移动、Filesystem 的 Mount / Unmount）；udisks2 不在线时回退 `lsblk --json` 子进程输出解析（经 `pr_run`，仅枚举，挂载卸载不可用）。

| 函数 | 说明 |
|---|---|
| `dsk_supported() -> Bool` | udisks2 在线（完整能力）或 lsblk 可用（仅枚举） |
| `dsk_volumes() -> Result[Array[DskVolume], DiskError]` | 枚举可挂载卷；系统无任何卷（台式机）返回 `Ok([])` |
| `dsk_mount(volume) -> Result[Unit, DiskError]` | 挂载（已挂载给 `AlreadyMounted`） |
| `dsk_unmount(volume) -> Result[Unit, DiskError]` | 卸载（未挂载给 `NotMounted`） |

`DskVolume{ device, label, mountpoint, size_bytes, removable, path }`：device 为块设备文件（`/dev/sda1`）、label 为卷标（无卷标空串）、mountpoint 为已挂载路径（未挂载 None）、size_bytes 为字节、removable 指示可移动介质、path 为 udisks2 对象路径（lsblk 路线取不到为空串，供挂载卸载内部定位）。错误 `DiskError`：`Unsupported` / `BusFailed(String)` / `CommandFailed(String)` / `ParseFailed(String)` / `InvalidParam(String)` / `NotMounted(String)` / `AlreadyMounted(String)`。

```moonbit
match @yue.dsk_volumes() {
  Ok(vols) =>
    for v in vols if v.removable && v.mountpoint is None {
      match @yue.dsk_mount(v) {
        Ok(_) => println("已挂载 \{v.device}")
        Err(e) => println("挂载失败：\{e}")
      }
    }
  Err(e) => println("不可用：\{e}")
}
```

## 电源与登录会话

关机 / 重启 / 注销统一走 logind（系统总线 `org.freedesktop.login1`）的 PowerOff / Reboot 与会话终断。关机类动作需要 polkit 授权（交互式桌面由 auth agent 弹框）；Vagrant / 容器 / 权限不足时 `Can*` 查询返回 false 或错误。

| 函数 | 说明 |
|---|---|
| `pwrc_supported() -> Bool` | Linux 且 logind 在线 |
| `pwrc_sessions() -> Result[Array[SessionInfo], PwrcError]` | 登录会话列表（id/user/uid/seat/对象路径） |
| `pwrc_can_power_off()` / `pwrc_can_reboot() -> Result[Bool, PwrcError]` | 当前环境是否允许对应动作 |
| `pwrc_power_off()` / `pwrc_reboot() -> Result[Unit, PwrcError]` | 关机 / 重启（有副作用） |
| `pwrc_logout(session) -> Result[Unit, PwrcError]` | 终断指定会话 |
| `pwrc_logout_self() -> Result[Unit, PwrcError]` | 终断当前会话（无关机权限时只退出自己） |

`SessionInfo{ id, uid, user, seat, path }`：seat 本地为 "seat0"，远程 / 无 seat 的会话为空串。错误 `PwrcError`：`Unsupported`（非 Linux 或 logind 不在线 / 总线不可达）/ `NotAllowed(String)`（Can* 返回 no/na、polkit 授权被拒）/ `BusFailed(String)`。

```moonbit
if @yue.pwrc_supported() {
  match @yue.pwrc_can_power_off() {
    Ok(true) => {
      let _ = @yue.pwrc_power_off() // 真机执行：弹 polkit 授权并关机
    }
    _ => {
      let _ = @yue.pwrc_logout_self()
    }
  }
}
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
match @yue.pp_profiles() {
  Ok(profiles) if profiles.contains(@yue.PBalanced) => {
    let _ = @yue.pp_set(@yue.PBalanced)
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
let os = @yue.si_os() // Ok({ pretty_name: "Ubuntu 24.04.5 LTS", id: "ubuntu", .. })
let mem = @yue.si_memory()
let up = @yue.si_uptime() // Ok(84088.08)
```

## 时区与本地语言

读走系统总线 D-Bus 属性 `org.freedesktop.timedate1` 的 Timezone（字符串）/ NTP（布尔）；总线不可达或服务不在线时回退 `timedatectl show` 的 KEY=VALUE 文本输出（子进程固定 C locale，输出恒定可解析）。本地语言读 `$LANG` 环境变量。

| 函数 | 说明 |
|---|---|
| `lc_timezone() -> Result[String, LocaleError]` | 当前时区（如 "Asia/Shanghai"） |
| `lc_ntp() -> Result[Bool, LocaleError]` | NTP 是否开启 |
| `lc_set_timezone(tz) -> Result[Unit, LocaleError]` | 设时区（D-Bus 属性写，有副作用、需认证） |
| `lc_lang() -> Result[String, LocaleError]` | 当前本地语言（`$LANG`，如 "zh_CN.UTF-8"） |

错误 `LocaleError`：`LcUnsupported` / `LcBusFailed(String)` / `LcCommandFailed(String)` / `LcParseFailed(String)` / `LcInvalidTimezone(String)`（空串 / 含空白 / 以 '/' 开头 / 含 '..'）。

```moonbit
let tz = @yue.lc_timezone()
let ntp = @yue.lc_ntp()
let _ = @yue.lc_set_timezone("Asia/Tokyo") // 需要认证
```

## 蓝牙

经 `org.bluez`（系统总线）查询适配器与已发现设备，支持开关电源、扫描发现、连接 / 断开 / 配对。对象枚举用 `ObjectManager.GetManagedObjects`（a{oa{sa{sv}}} 形状），属性读取用 `Properties.GetAll`。

| 函数 | 说明 |
|---|---|
| `bt_supported() -> Bool` | 系统有可用蓝牙适配器（`org.bluez` 在线且枚举到 Adapter1）；台式机与虚拟机无适配器是合法状态，返回 false 而非异常 |
| `bt_adapter_info() -> Result[BtAdapter, BtError]` | 适配器快照 |
| `bt_devices() -> Result[Array[BtDevice], BtError]` | 已发现设备列表 |
| `bt_set_powered(on) -> Result[Unit, BtError>` | 开关适配器电源 |
| `bt_start_discovery()` / `bt_stop_discovery() -> Result[Unit, BtError]` | 开始 / 停止扫描（数秒后 `bt_devices` 可见新设备） |
| `bt_connect(device)` / `bt_disconnect(device)` / `bt_pair(device)` | 连接 / 断开 / 配对（返回 `Result[Unit, BtError]`） |

`BtAdapter{ path, address, name, powered, discovering }`；`BtDevice{ path, address, name, paired, connected, trusted }`（name 取 Name 属性，空则回退 Alias，仍空回退 MAC）。错误 `BtError`：`Unsupported`（无适配器或服务不在线）/ `BusFailed(String)`。

```moonbit
if @yue.bt_supported() {
  match @yue.bt_adapter_info() {
    Ok(a) if !a.powered => {
      let _ = @yue.bt_set_powered(true)
    }
    _ => ()
  }
  let _ = @yue.bt_start_discovery()
  match @yue.bt_devices() {
    Ok(devs) => for d in devs if !d.paired { let _ = @yue.bt_pair(d) }
    Err(_) => ()
  }
}
```

## 传感器

经 `iio-sensor-proxy`（`net.hadess.SensorProxy`，系统总线）汇总 IIO 子系统传感器读数，当前支持环境光（LightLevel，勒克斯）与加速度计方向。本机 / 虚拟机没有该服务、没有对应传感器是合法状态：`sns_supported()` 为 false，取值为 `Unsupported`，不视为异常。

| 函数 | 说明 |
|---|---|
| `sns_supported() -> Bool` | 系统装有 iio-sensor-proxy（读 HasAccelerometer 属性探活） |
| `sns_has_ambient_light() -> Bool` | 是否具备环境光传感器（HasAmbientLight 属性） |
| `sns_ambient_light() -> Result[Double, SensorError]` | 环境光照度（勒克斯）。取值前 ClaimLight 点亮传感器、取完 ReleaseLight 释放（不点灯的读数会停在旧值） |
| `sns_accelerometer_orientation() -> Result[String, SensorError]` | 加速度计方向（"normal"/"left-up"/"left-down"/"right-up"/"right-down"/"bottom-up"/"bottom-down" 等）；取值前后自动 Claim/Release |

错误 `SensorError`：`Unsupported`（无服务 / 无对应传感器，含运行中传感器被拔出 / 服务退出）/ `BusFailed(String)`。

```moonbit
if @yue.sns_supported() && @yue.sns_has_ambient_light() {
  match @yue.sns_ambient_light() {
    Ok(lux) => println("环境光：\{lux} lx")
    Err(e) => println("读不到：\{e}")
  }
}
```

## 打印机（CUPS）

经 `lpstat` 三条只读命令读打印机列表（`-p`）、默认打印机（`-d`）、任务队列（`-o <打印机>`），以及 `lp` 提交打印任务的命令构造。子进程环境固定 C locale，输出语言恒定可解析；未装 CUPS（lpstat 以退出码 127 呈现）→ `PrtUnsupported`，属合法降级。

| 函数 | 说明 |
|---|---|
| `prt_supported() -> Bool` | lpstat 可用 |
| `prt_list() -> Result[Array[PrinterInfo], PrinterError]` | 打印机列表（名称 + 可用状态） |
| `prt_default() -> Result[String, PrinterError]` | 默认打印机名 |
| `prt_queue(printer) -> Result[Array[PrinterJob], PrinterError]` | 指定打印机任务队列 |
| `prt_print(printer? = "", path, copies? = 1) -> Result[Unit, PrinterError]` | 提交打印任务（printer 缺省用系统默认打印机；有副作用，真实排队打印） |

`PrinterStatus`：`Idle` / `Printing` / `Paused`（暂停接新任务）/ `Disabled`；`prt_status_available(status)` 判是否可用接任务。`PrinterInfo{ name, status }`；`PrinterJob{ name, id }`（name 为 "目标名-编号" 形态，如 `Gprinter-GP-9034T-12`）。错误 `PrinterError`：`PrtUnsupported` / `PrtCommandFailed(String)` / `PrtParseFailed(String)` / `PrtInvalidParam(String)`（打印机名 / 文件路径为空、份数 < 1）。

```moonbit
match @yue.prt_default() {
  Ok(name) => {
    let _ = @yue.prt_print(printer=name, path="/tmp/doc.pdf")
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
let path = @yue.envx_get("PATH")
let _ = @yue.envx_set("MY_FLAG", "1")
let _ = @yue.envx_unset("MY_FLAG")
match @yue.fsx_list_dir("/usr/share/applications") {
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
match @yue.rf_recent(limit=8) {
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

`BookmarkProfile{ browser, profile, bookmarks_path }`；`BookmarkNode{ name, url?, children, added, root }`（added 为 Unix 毫秒、root 标注所属根 bookmark_bar / other / synced）——返回虚拟根树（名称 "<浏览器>/<profile>"，children 为三根合并），`BookmarkNode::is_folder()` / `is_url()` 分类，`bm_flatten(node)` 给先序扁平 url 书签列表。错误 `BookmarkError`：`BmUnsupported` / `BmNoConfigDir` / `BmNoBrowser` / `BmIoFailed(String)`。

```moonbit
match @yue.bm_bookmarks("google-chrome") {
  Ok(root) =>
    for n in @yue.bm_flatten(root) {
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
match @yue.ffx_history(limit=10) {
  Ok(items) => for it in items { println("\{it.title}  \{it.url}") }
  Err(e) => println("读不到：\{e}")
}
```

## 共享基建：子进程执行 procrun

命令行类能力（音量、显示器、壁纸、夜间色温、打印机、电源计划、Firefox profile 定位）共用的「spawn → 限时回收 → 临时文件捕获 stdout/stderr」封装：命令名按 PATH 解析；子进程环境强制 C locale 使输出语言恒定可解析；退出码 0 归一为 `Ok`，非零退出归一为 `Err` 并携带 stderr，调用方无需再自行判码。

| 函数 | 说明 |
|---|---|
| `pr_available() -> Bool` | 当前平台是否支持子进程执行（仅 Linux，基于 `@subproc`） |
| `pr_run(cmd, args, timeout_ms? = 5000) -> Result[ProcOutput, ProcError]` | 运行命令并归一结果（超时进程会被强制终止） |

`ProcOutput{ stdout, exit_code }`；错误 `ProcError`：`Unsupported`（非 Linux）/ `SpawnFailed(String)`（命令不存在按 Unix 惯例由子进程以退出码 127 呈现，归入非零退出）/ `Timeout(String)` / `NonZeroExit(Int, String)` / `Signaled(Int)`。

命令缺失与「存在但失败」是两种语义：前者在该模块自身通常归一为 `*Supported == false` 或 `Unsupported`（如 `PpUnsupported`、`PrtUnsupported`），后者是 `CommandFailed`——调用方按错误值分类处理即可。

```moonbit
match @yue.pr_run("wpctl", ["get-volume", "@DEFAULT_SINK@"]) {
  Ok(out) => println(out.stdout)
  Err(@yue.ProcError::NonZeroExit(_, err)) => println("失败：\{err}")
  Err(e) => println(e)
}
```

## 共享基建：通用 D-Bus 调用层（@traybus）

面向任意服务的方法调用与属性读写，是媒体控制 / 磁盘 / 电源与登录会话 / 蓝牙 / 传感器 / 时区等模块的公共地基。连接复用 `bus.mbt` 的进程级会话 / 系统连接，编解码复用 `wire.mbt` 的线协议；同步调用 1.5 秒超时，应答超时给 `gdbus.timeout` 错误。

| 函数 | 说明 |
|---|---|
| `gdbus_call_session(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | 会话总线方法调用 |
| `gdbus_call_system(dest, path, iface, action, args) -> Result[GDBusValue, GDBusError]` | 系统总线方法调用 |
| `gdbus_get_property_session(dest, path, iface, prop)` / `gdbus_get_property_system(...)` | 读属性（走 `org.freedesktop.DBus.Properties.Get`，返回值已拆掉 variant 包裹） |
| `gdbus_set_property_session(dest, path, iface, prop, value)` / `gdbus_set_property_system(...)` | 写属性（走 `Properties.Set`；value 传裸值，variant 包裹在本层完成） |

值模型 `GDBusValue`：`GVNone`（无返回值，不能作调用参数）/ `GVBool` / `GVInt32` / `GVUInt32` / `GVInt64` / `GVU64`（'t'，udisks 的 Size/Time 等无符号 64 位）/ `GVDouble` / `GVString` / `GVPath`（'o'）/ `GVArray(元素签名, 元素表)` / `GVDict(a{sv}，值已拆掉 variant 包裹，Map 按插入序序列化)` / `GVVariant`（保持包裹）/ `GVStruct`。应答侧 `{sv}` 数组折成 `GVDict`，多返回值折成 `GVStruct`。错误 `GDBusError{ name, message }`：name 为 D-Bus 错误名或本地前缀 `gdbus.io`（连不上 / 已断开）/ `gdbus.timeout` / `gdbus.encode`。

```moonbit
match
  @traybus.gdbus_get_property_system(
    "org.freedesktop.timedate1",
    "/org/freedesktop/timedate1",
    "org.freedesktop.timedate1",
    "NTP",
  ) {
  Ok(@traybus.GVBool(on)) => println("NTP 开启：\{on}")
  Ok(_) => ()
  Err(e) => println("总线失败：\{e.name} \{e.message}")
}
```

## 边界

- 浏览器 History 库在浏览器运行中可能不断有新写入，读取结果是读入时刻的快照（不含尚未合并进主库的最新记录）。
- Firefox 的 places.sqlite 常处于 WAL 模式，本实现只读主库文件、尚未 checkpoint 进主库的最新浏览记录读不到；多 profile 聚合时同一 url 会各出现一次（与 Chrome 侧聚合口径一致）。
- `appfind_executable` 的命中判定为文件可打开读取，不校验执行权限位。
- 音量 / 亮度设置依赖对应系统服务在线（PipeWire/Pulse、logind），服务缺席时读接口可能仍可用而写接口返回 `Unsupported`，按错误值逐项处理即可。
- 关机 / 重启 / 设时区 / 切电源计划 / 蓝牙配对 / 打印 / 挂载都是会改变系统真实状态的操作，且多数需要 polkit 授权：接口完整实现，但只在用户显式操作时调用，不要在探测或查询路径里代为触发。
- 剪贴板监听与涟漪动画的定时器都由 libyue 消息循环驱动且无取消 id（`set_timer`）：停止的途径是让回调返回 false，故句柄类 API（`cbw_stop` / `eff_stop`）应在组件卸载前显式调用。
