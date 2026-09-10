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

## 已知边界

- `yue/moon.pkg.json` 的 `cc-link-flags` 由 `prepare.py` 托管回写（绝对路径），手动改动会被覆盖。
- macOS 分支含 ARC/no-ARC 双库结构，未实测，首次构建按官方 CMakeLists 微调；Windows 链接参数未自动化。
- 当前只封装了 App / Window / Label / Tray 一条最小链路；继续扩展控件时按既有模式：shim 加机械转换函数 → `ffi.mbt` 加 extern → 新 `*.mbt` 加类型与方法。
- 回调闭包由 `window.mbt` 的注册表保活，窗口销毁后条目暂不回收（骨架阶段可接受）。

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue 的 `lua_yue/`
- MoonBit 技能库：`.agents/skills/`（含 `moonbit-c-binding`、`make-moonbit-c-bindings`，FFI 规范以此为准）
