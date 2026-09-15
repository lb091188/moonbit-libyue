# moonbit-libyue

[![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

[libyue](https://libyue.com/docs/latest/cpp/) 的 MoonBit 封装。  
原库支持 Windows、Mac OS、Linux，迁移第一阶段以跑通 Ubuntu Xfce4 环境为第一目标，后续在此基础上再推进。

- [x] Ubuntu 24.04 Xfce
- [ ] Ubuntu 24.04 Gnome
- [ ] Ubuntu 24.04 KDE
- [ ] Deepin 25
- [ ] OpenKylin 3
- [x] Windows 10 / 11
- [ ] Mac OS

简体中文 | [English](https://github.com/lb091188/moonbit-libyue/blob/master/README.md)

## Yue
一个跨平台原生桌面应用库（A library for creating native cross-platform GUI apps）。

## 三层架构

```
┌─────────────────────────────────────────────┐
│ 使用者（examples/*）                          │  纯 MoonBit，零平台代码
├─────────────────────────────────────────────┤
│ MoonBit 库（yue/）                           │  统一 API：平台探测与降级都在这里消化
├─────────────────────────────────────────────┤
│ 平台封装（shim/ + vendor/libyue）             │  最薄 C ABI（机械转换）+ libyue
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
  geometry.mbt       几何值类型（纯 MoonBit）
  error.mbt          结构化错误
  events.mbt         事件系统（鼠标/键盘/修饰键归一化/VKEY 常量/连击）
  button.mbt         按钮 / 单行输入框（Checkbox/Radio/Password）
  props.mbt          L1 props 构造器（X::make / apply_style）
  declarative.mbt    L2 声明式节点（Node/mount/vbox/label/…）
  store.mbt          L3 响应式 Store（订阅 / map 派生 / bind_label）
  tray.mbt           托盘统一 API
  traybus/           纯 MoonBit 的 DBus + StatusNotifierItem 协议栈（Linux 托盘）
    wire.mbt         DBus 线路格式编解码
    bus.mbt          会话总线连接、SASL EXTERNAL 握手、消息收发分发
    sni.mbt          SNI 协议实现
    detect.mbt       桌面环境识别（XDG_CURRENT_DESKTOP）
    icon.mbt         程序内置生成托盘位图（不依赖图片资源与解码器）
    sys.mbt          fd 级系统调用面（全部经 shim 转发）
shim/                C ABI 封装层（yue_mbt.cpp + include/yue_mbt.h）+ CMakeLists
scripts/prepare.py   固定版本下载 libyue + 构建静态库（链接参数由 prebuild.py 托管）
scripts/prebuild.py  moon 构建钩子：按当前系统输出链接配置，自动传播给依赖方
scripts/postadd.py   moon add 安装本库时自动触发首次构建
examples/            15 个示例：hello / editor / browser / drawing / table / widgets /
                     drag_source / drag_destination / floating_heart /
                     auto_height_edit / showcase / misc / advanced / events / layout
.agents/skills/      MoonBit 技能库
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
 **注意首次构建会到 github 下载 libyue 相关依赖**

```sh
moon run examples/hello
```

零配置：链接参数由构建钩子 `scripts/prebuild.py` 按当前系统生成并自动传播，静态库缺失时自动执行 `scripts/prepare.py` 补建。`prepare.py` 幂等可重跑；Linux/Windows 切换后首次构建自动重建。

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
moon add NoahLiu/moonbit-libyue
```

库代码（`yue/`）发布在 mooncakes，使用方零配置：

```sh
moon add NoahLiu/moonbit-libyue
moon run src   # 无需任何链接配置；安装时自动构建原生层，缺失时构建钩子自动补建
```

纯 MoonBit 部分（DBus 线路编解码、颜色工具、表格值编解码）不依赖原生库，可直接跑测试：

```sh
moon test
```

## 说明

- 当前封装面约 320 个 ABI 函数（`yue/ffi.mbt` 中 324 个 `extern "c"` 声明）：App/Lifetime、Window、View 通用能力与拖拽、Container/Label/Button/Entry/TextEdit、Slider/Picker/ComboBox/ProgressBar/Tab/Group/Scroll/Separator/DatePicker/GifPlayer、Browser、Menu/MenuBar、Table+模型桥、Painter/Canvas、Tray/Notification/GlobalShortcut/Clipboard/MessageBox/Popover/FileDialog、Screen/Appearance/Locale/Cursor；继续扩展控件时按既有模式：shim 加机械转换函数 → `ffi.mbt` 加 extern → 新 `*.mbt` 加类型与方法。
- 已知边界、ABI 坑与各平台适配经验不在 README 展开，见 `AGENTS.md`（AI 协作规则）与 [docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/adaptation.md)；Linux 托盘方案（设计动机、架构、后端降级、桌面兼容性、调试）独立成文：[docs/tray.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/tray.md)。
- shim/vendor 改动或重跑 `prepare.py` 后须强制重链：`moon clean` 或删对应 exe，见 [docs/relink.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/relink.md)。
- 文档索引：[docs/README.md](docs/README.md)。

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue 的 `lua_yue/`
- MoonBit 技能库：`.agents/skills/`（`moonbit-c-binding`、`make-moonbit-c-bindings`）
- AI 协作规则：`AGENTS.md` · 平台适配经验：[docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/adaptation.md)
