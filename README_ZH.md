# moonbit-libyue

[libyue](https://libyue.com/docs/latest/cpp/) 的 MoonBit 封装。  
原库支持 Windows、Mac OS、Linux，迁移第一阶段以跑通 Ubuntu Xfce4 环境为第一目标，后续在此基础上再推进。

- [x] Linux X11
- [ ] Linux Wayland
- [ ] Windows
- [ ] Mac OS

简体中文 | [English](README.md)

## Yue
一个跨平台原生桌面应用库（A library for creating native cross-platform GUI apps）。

## 三层架构

```
┌─────────────────────────────────────────────┐
│ 使用者（examples/*）                          │  纯 MoonBit，零平台代码
├─────────────────────────────────────────────┤
│ MoonBit 库（yue/）                           │  统一 API：类型、闭包、编码转换、
│                                             │  平台探测与降级都在这里消化
├─────────────────────────────────────────────┤
│ 平台封装（shim/ + vendor/libyue）             │  最薄 C ABI（机械转换）+ libyue
│                                             │  吸收 win/linux/macos 差异
└─────────────────────────────────────────────┘
```

分层原则：

1. **能 MoonBit 解决的不进 C/C++**——字符串 UTF-16↔UTF-8、闭包保活注册表、错误枚举、托盘降级逻辑全部在 `yue/` 内完成。
2. **C++ shim 只做 ABI 翻译**——`shim/yue_mbt.cpp` 逐函数对照 `shim/include/yue_mbt.h`，无业务逻辑。
3. **平台差异两级收敛**——libyue 已统一的（窗口、控件）直接用；libyue 未暴露的（如 Linux 托盘后端探测，它内部 dlopen 失败只打日志）由 shim 补探测接口，MoonBit 层翻译成 `Result` / `is_supported()` 统一语义。

## 目录

```
yue/                 MoonBit 库包
  ffi.mbt            私有 extern "c" 声明（仅 native 编译）
  types.mbt          控件类型定义（Window/Label/View 等句柄与包装）
  app.mbt            应用生命周期：init / run / quit
  view.mbt           View 通用能力 + 回调注册表（focus/启停/style/拖拽）
  widgets.mbt        基础与组合控件（Button/Entry/Slider/Picker/ComboBox/ProgressBar/Popover…）
  browser.mbt        内嵌浏览器（WebView）
  menu.mbt           菜单条 / 弹出菜单 / 菜单项
  dialog.mbt         文件打开/保存对话框
  text_edit.mbt      多行文本编辑框
  tab.mbt            页签
  table.mbt          表格 + 可挂 MoonBit trait 的数据模型桥
  painter.mbt        2D 绘制（Painter / 离屏 Canvas）
  misc.mbt           分组框 / 滚动视图 / 分隔线 / 剪贴板 / 消息框
  color.mbt          颜色工具（纯 MoonBit）
  error.mbt          结构化错误
  tray.mbt           托盘统一 API
  traybus/           纯 MoonBit 的 DBus + StatusNotifierItem 协议栈（Linux 托盘）
    wire.mbt         DBus 线路格式编解码
    bus.mbt          会话总线连接、SASL EXTERNAL 握手、消息收发分发
    sni.mbt          SNI 协议实现
    detect.mbt       桌面环境识别（XDG_CURRENT_DESKTOP）
    icon.mbt         程序内置生成托盘位图（不依赖图片资源与解码器）
    sys.mbt          fd 级系统调用面（全部经 shim 转发）
shim/                C ABI 封装层（yue_mbt.cpp + include/yue_mbt.h）+ CMakeLists
scripts/prepare.py   固定版本下载 libyue + 构建静态库 + 回写链接参数
examples/            13 个示例：hello / editor / browser / drawing / table / widgets /
                     drag_source / drag_destination / floating_heart /
                     auto_height_edit / showcase / misc / advanced
.agents/skills/      MoonBit 技能库（FFI 规范以此为准）
```

## 快速开始

系统依赖（Ubuntu 24.04）：

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev \
  libwebkit2gtk-4.1-dev
```

构建原生库并运行示例：
 **注意会到 github 下载 libyue 相关依赖** 

```sh
python3 scripts/prepare.py
moon run examples/hello
```

`prepare.py` 与 `moon` 都需在仓库根目录执行：回写的链接参数是仓库根相对的 `-L build`（链接器按 moon 的调用目录解析相对路径）。`prepare.py` 幂等可重跑——缓存包 sha256 不匹配（如下载被中断截断）会自动删除重下；内容未变的 moon.pkg.json 不会回写。

纯 MoonBit 部分（DBus 线路编解码、颜色工具、表格值编解码）不依赖原生库，可直接跑测试：

```sh
moon test
```

## Linux 托盘方案

AppIndicator 运行库（Ubuntu 24.04 已移除传统版）不可依赖，且 libyue 内部加载失败只打日志、对象静默失效。
现改为 **MoonBit 直连面板的 StatusNotifierItem 协议**，不再依赖任何 AppIndicator 运行库：

- `yue/traybus/` 纯 MoonBit 实现：DBus 线路编解码、SASL EXTERNAL 握手、消息收发循环（glib fd 监视接入 GTK 主循环）、SNI 属性/信号/Activate 分发、桌面环境识别（XDG_CURRENT_DESKTOP）、程序内置生成月牙位图；
- shim 只转发 8 个 fd 级系统调用（connect/read/write/poll/close/watch_fd/getuid/getenv），非 Linux 为失败桩；
- 后端优先级：SNI watcher 在线 → 自实现托盘；不在线 → 回退 nativeui AppIndicator；两者皆无 → `Err(Unsupported)`。XFCE/KDE/MATE/Cinnamon/Budgie/LXQt 及装 AppIndicator 扩展的 GNOME 可用，纯净 GNOME 无托盘协议则明确报错；
- 消费方面向统一 API：`Tray::new / is_supported / set_title / set_icon / set_icon_name / set_tooltip / on_click / set_menu / remove`，另有 `desktop_environment()` 诊断。
- 已知坑（实测入档）：DBus 数组长度前缀**不含首元素前的对齐填充**，算进去会被 dbus-daemon 判协议违规直接断连；DBus 头部 SIGNATURE 字段的 variant 签名是 "g"（u8 长度编码），按 "s" 编能过自洽单测但会被真实总线拒绝——单测证自洽，互操作必须上真总线验证。

## 已知边界

- `moon` 的 `link` 段只作用于所在包、且只对 main 包的二进制生效；库包 `yue/` 放 link 段会让 moon 生成无 main 的可执行文件（moon 对所有平台的产物统一加 `.exe` 后缀）导致构建失败。`prepare.py` 只回写 `is-main` 的包，`cc-link-flags` 写仓库根相对的 `-L build`，因此 `moon` 命令必须在仓库根目录执行（在子目录调用会找不到 `libyue_mbt.a`）。
- `extern "c"` 不能返回可空类型（ABI 与 C 指针不兼容，直接段错误）：成败经 `Ref[Int]` 出参报告，句柄按非空返回。
- FFI 指针参数必须标 `#borrow`（编译器强制）；同函数多参数写在同一个 `#borrow(a, b)` 里。
- Linux 托盘探测列表必须与 libyue 内部 dlopen 列表严格一致（只认 `libappindicator3`）；本机存在 ayatana 分支也不代表可用，nativeui 内部加载失败时只打日志，后续调用会踩空指针（shim 侧已加空指针防御）。SNI 自实现后端上线后此路径仅作回退。
- MoonBit 闭包/函数值跨 C ABI：只允许无捕获的顶层函数字面量（编译为真实 C 函数指针），带捕获闭包经"函数指针 + 闭包指针"双参数模式传递（`on_click` 系）。
- Table（GTK）放进 Notebook 页签内会在尺寸测量时段错误（negative allocation），必须放普通容器或独立窗口（showcase 采用独立子窗口方案）。
- macOS 分支含 ARC/no-ARC 双库结构，未实测；Windows 链接参数未自动化。
- 当前封装面约 250 个 ABI 函数（`yue/ffi.mbt` 中 248 个 `extern "c"` 声明）：App/Lifetime、Window、View 通用能力与拖拽、Container/Label/Button/Entry/TextEdit、Slider/Picker/ComboBox/ProgressBar/Tab/Group/Scroll/Separator/DatePicker/GifPlayer、Browser、Menu/MenuBar、Table+模型桥、Painter/Canvas、Tray/Notification/GlobalShortcut/Clipboard/MessageBox/Popover/FileDialog、Screen/Appearance/Locale/Cursor；继续扩展控件时按既有模式：shim 加机械转换函数 → `ffi.mbt` 加 extern → 新 `*.mbt` 加类型与方法。
- extern 声明的控件参数必须写底层句柄类型 `View` 而非 MoonBit 包装 struct（如 `Slider`）：struct 经 ABI 传入的是包装对象而非句柄值，运行时全部"句柄无效"且被静默丢弃（Slider/Table 系列曾因此整体失效，2026-09 修复）。
- 回调闭包由 `view.mbt` 的注册表保活，窗口销毁后条目暂不回收（骨架阶段可接受）。

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue 的 `lua_yue/`
- MoonBit 技能库：`.agents/skills/`（含 `moonbit-c-binding`、`make-moonbit-c-bindings`，FFI 规范以此为准）
