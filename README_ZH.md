# moonbit-libyue

[libyue](https://libyue.com/docs/latest/cpp/) 的 MoonBit 封装。  
原库支持 Windows、Mac OS、Linux，迁移第一阶段以跑通 Ubuntu Xfce4 环境为第一目标，后续在此基础上再推进。

- [x] Ubuntu 24.04 Xfce
- [ ] Ubuntu 24.04 Gnome
- [ ] Ubuntu 24.04 KDE
- [ ] Deepin 25
- [ ] OpenKylin 3
- [x] Windows 10 / 11(2026-09 首次实测,showcase 全功能跑通;经验见 [docs/adaptation.md](docs/adaptation.md))
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
examples/            14 个示例：hello / editor / browser / drawing / table / widgets /
                     drag_source / drag_destination / floating_heart /
                     auto_height_edit / showcase / misc / advanced / events
.agents/skills/      MoonBit 技能库（FFI 规范以此为准）
```

## 快速开始

### Ubuntu 24.04

系统依赖：

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

`prepare.py` 与 `moon` 都需在仓库根目录执行：回写的链接参数是仓库根相对的 `-L build`（链接器按 moon 的调用目录解析相对路径）。`prepare.py` 幂等可重跑——缓存包 sha256 不匹配（如下载被中断截断）会自动删除重下；内容未变的 moon.pkg.json 不会回写。同一仓库在 Linux/Windows 间切换时重跑 `prepare.py` 即可换到对应平台的链接参数。

### Windows（10/11，x64）

需要：Python 3、MoonBit 工具链（`moon`）、CMake、MSVC C++ 工具链（含 ATL）。以下命令均在本项目 Windows 实测通过：

1. 安装 MoonBit 工具链（PowerShell）：

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

2. 安装 CMake 与 MSVC C++ 工具链（`winget`，或手动装 VS Installer 里的对应组件）：

```powershell
winget install Kitware.CMake
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

3. 补装 ATL 组件（libyue 的 Windows 源码包含 `atldef.h` 等 ATL 头，默认不装；需管理员权限）：

```powershell
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' -ArgumentList 'modify','--installPath','"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"','--add','Microsoft.VisualStudio.Component.VC.ATL','--quiet','--norestart' -Verb RunAs -Wait
```

4. 构建、运行。**moon 在 Windows 编译原生代码时会从 PATH 里找 `cl`，须在「x64 Native Tools Command Prompt for VS 2022」里执行，或先在命令行里 call `vcvars64.bat`**：

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
python3 scripts\prepare.py
moon run examples/hello
```

### 作为依赖使用（mooncakes）

```sh
moon add lkyh/moonbit-libyue
```

库代码（`yue/`）发布在 mooncakes；原生层（shim + vendored libyue）需在本仓库执行
`python3 scripts/prepare.py` 构建静态库，并在使用方的 `moon.pkg.json` 链接参数中加
`-L <本仓库>/build -lyue_mbt` 与对应系统库。

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

真实桌面（XFCE 4.18、GNOME 等）上实测出的平台差异与坑，统一记录在 [docs/adaptation.md](docs/adaptation.md)。

## 说明

- 当前封装面约 260 个 ABI 函数（`yue/ffi.mbt` 中 262 个 `extern "c"` 声明）：App/Lifetime、Window、View 通用能力与拖拽、Container/Label/Button/Entry/TextEdit、Slider/Picker/ComboBox/ProgressBar/Tab/Group/Scroll/Separator/DatePicker/GifPlayer、Browser、Menu/MenuBar、Table+模型桥、Painter/Canvas、Tray/Notification/GlobalShortcut/Clipboard/MessageBox/Popover/FileDialog、Screen/Appearance/Locale/Cursor；继续扩展控件时按既有模式：shim 加机械转换函数 → `ffi.mbt` 加 extern → 新 `*.mbt` 加类型与方法。
- 已知边界、ABI 坑与各平台适配经验不在 README 展开，见 `AGENTS.md`（AI 协作规则）与 [docs/adaptation.md](docs/adaptation.md)。

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue 的 `lua_yue/`
- MoonBit 技能库：`.agents/skills/`（含 `moonbit-c-binding`、`make-moonbit-c-bindings`，FFI 规范以此为准）
- AI 协作规则：`AGENTS.md` · 平台适配经验：[docs/adaptation.md](docs/adaptation.md)
