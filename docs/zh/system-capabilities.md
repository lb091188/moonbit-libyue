# 系统能力（音量 / 亮度 / 应用查找 / 应用历史）

系统能力族 API：屏幕亮度、键盘背光、系统音量、已装应用查找、VS Code 本地历史与最近工作区、浏览器历史与下载记录。全部只读或经系统服务授权写入，统一返回 `Result`，不支持的环境给对应错误值而不是崩溃；`*_supported()` 每次调用真实探测当前环境。

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

## 边界

- 浏览器 History 库在浏览器运行中可能不断有新写入，读取结果是读入时刻的快照（不含尚未合并进主库的最新记录）。
- `appfind_executable` 的命中判定为文件可打开读取，不校验执行权限位。
- 音量 / 亮度设置依赖对应系统服务在线（PipeWire/Pulse、logind），服务缺席时读接口可能仍可用而写接口返回 `Unsupported`，按错误值逐项处理即可。
