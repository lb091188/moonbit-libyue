# moonbit-libyue

libyue 的 MoonBit 封装。目标：消费方写一份 MoonBit 代码，Windows / macOS / Linux 三平台行为一致，感受不到平台差异。

## 三层架构

```
┌─────────────────────────────────────────────┐
│ 使用者（examples/hello）                      │  纯 MoonBit，零平台代码
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
yue/                 MoonBit 库包（对外 API）
  ffi.mbt            私有 extern "c" 声明（仅 native 编译）
  app.mbt            init / run / quit
  window.mbt         窗口 + 关闭回调（FuncRef trampoline）
  label.mbt          标签
  tray.mbt           托盘（平台降级示范）
  error.mbt          结构化错误
shim/                C ABI 封装层 + CMakeLists
scripts/prepare.py   固定版本下载 libyue + 构建静态库 + 回写链接参数
examples/hello/      使用者示例
.agents/skills/      moonbitlang/skills 全量技能（开发时给 agent 参考）
```

## 快速开始

系统依赖（Ubuntu 24.04）：

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev \
  libwebkit2gtk-4.1-dev
```

构建原生库并运行示例：

```sh
python3 scripts/prepare.py   # 下载 libyue v0.15.6（校验 sha256）+ CMake 构建
moon run examples/hello
```

## Linux 托盘方案

Linux 托盘依赖 AppIndicator（GNOME 等桌面的托盘协议），运行库不保证存在，且 libyue 内部 dlopen 失败后只打日志、对象静默失效。库内处理方式：

- shim 提供 `yue_mbt_tray_supported()`：按 ayatana / 传统 appindicator 两个分支探测（覆盖 Ubuntu 22.04+ 与更早发行版）；
- MoonBit 暴露统一的 `Tray::is_supported()` 与 `Tray::new() -> Result[Tray, TrayError]`，消费方 `match` 错误即可，不写任何平台判断。

## 已知边界（实测结论）

- `moon` 的 `link` 段只作用于所在包、且只对 main 包的二进制生效；库包 `yue/` 放 link 段会让 moon 生成无 main 的可执行文件（moon 对所有平台的产物统一加 `.exe` 后缀）导致构建失败。`prepare.py` 只回写 `is-main` 的包，`cc-link-flags` 为本机绝对路径。
- `extern "c"` 不能返回可空类型（ABI 与 C 指针不兼容，直接段错误）：成败经 `Ref[Int]` 出参报告，句柄按非空返回。
- FFI 指针参数必须标 `#borrow`（编译器强制）；同函数多参数写在同一个 `#borrow(a, b)` 里。
- Linux 托盘探测列表必须与 libyue 内部 dlopen 列表严格一致（只认 `libappindicator3`）；本机存在 ayatana 分支也不代表可用，nativeui 内部加载失败时只打日志，后续调用会踩空指针（shim 侧已加空指针防御）。
- macOS 分支含 ARC/no-ARC 双库结构，未实测；Windows 链接参数未自动化。
- 当前封装面约 130 个 ABI 函数：App/Lifetime、Window、View 通用能力与拖拽、Container/Label/Button/Entry/TextEdit、Slider/Picker/ComboBox/ProgressBar/Tab/Group/Scroll/Separator/DatePicker/GifPlayer、Browser、Menu/MenuBar、Table+模型桥、Painter/Canvas、Tray/Notification/GlobalShortcut/Clipboard/MessageBox/Popover/FileDialog、Screen/Appearance/Locale/Cursor；继续扩展控件时按既有模式：shim 加机械转换函数 → `ffi.mbt` 加 extern → 新 `*.mbt` 加类型与方法。
- extern 声明的控件参数必须写底层句柄类型 `View` 而非 MoonBit 包装 struct（如 `Slider`）：struct 经 ABI 传入的是包装对象而非句柄值，运行时全部"句柄无效"且被静默丢弃（Slider/Table 系列曾因此整体失效，2026-09 修复）。
- 回调闭包由 `window.mbt` 的注册表保活，窗口销毁后条目暂不回收（骨架阶段可接受）。

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue 的 `lua_yue/`
- MoonBit 技能库：`.agents/skills/`（含 `moonbit-c-binding`、`make-moonbit-c-bindings`，FFI 规范以此为准）
