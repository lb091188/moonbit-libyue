# moonbit-libyue

[![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

[libyue](https://libyue.com/docs/latest/cpp/) 的 MoonBit 封装——用纯 MoonBit 编写 Windows / macOS / Linux 原生跨平台桌面应用。

## 测试支持

- [x] Ubuntu 24.04 Xfce
- [x] Ubuntu 24.04 GNOME
- [x] Ubuntu 24.04 KDE
- [x] Deepin 25
- [x] Windows 10 / 11
- [ ] Mac （没有设备测试）

简体中文 | [English](https://github.com/lb091188/moonbit-libyue/blob/master/README.md)

## Yue

一个跨平台原生桌面应用库（A library for creating native cross-platform GUI apps）。

## 三种写界面的方式

| 层 | 用法 | 典型代码 | 适合 |
|---|---|---|---|
| 1 | **主题组件库 + 声明式 + 响应式** | `button_t` / `side_menu` / `tag` / `alert` … 节点 + `Store` 绑定 | 现代化应用外壳，推荐 |
| 2 | **libyue 原版控件 + 声明式 + 响应式** | `button` / `entry` / `slider` … 节点 + `Store` 绑定 | 原生外观 + 声明式写法 |
| 3 | **libyue 原版控件 + 命令式** | `Window::new` + `set_content` + setter | 贴近 libyue 原生 API |

主题层在保持原生渲染与体积的同时，提供 Element Plus 风格的现代外观、声明式节点树与响应式数据绑定——原生，但好用。默认深色低饱和色板，整体可定制：挂载前 `theme_apply({ ..default_theme(), primary: "#1E4FA3" })` 一行换肤，详见 [docs/zh/components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md) 的「定制主题」。

## 演示

### 最小示例

```sh
moon run examples/hello         # 原版控件:libyue 原生外观的最小窗口
moon run examples/hello-themed  # 主题组件库:theme_apply + button_t/input_t/label_t
```

### 全功能演示板——showcase

`moon run examples/showcase` —— 12 页演示板（现代主题），覆盖主题组件库与 libyue 全部能力：基础/表单/事件与布局/导航/数据展示/反馈 + Store 对照 + 原生控件/画布与富文本 + 系统集成/窗口与网页/环境与平台，左侧分组菜单（基础/进阶/响应式/原生/系统），底栏展示包版本号（与 moon.mod 同步）；API 一览见 [docs/zh/components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md)：

![基础组件](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-basic.png)

![导航](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-nav.png)

![数据展示](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-data.png)

![反馈](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-feedback.png)

更多示例见 [examples/](https://gitee.com/noahliu0911/moonbit-libyue/tree/master/examples)。

## 使用说明

### 快速开始

#### Ubuntu 24.04

系统依赖：

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev \
  libwebkit2gtk-4.1-dev
```

构建原生库并运行示例：
**首次构建从 GitHub 下载预编译的 libyue 静态库（秒级，无需本地编译 C++），
仅 shim 单文件参与编译；设 `LIBYUE_FORCE_SOURCE=1` 可回退为源码全量构建。**

```sh
moon run examples/showcase
```


#### Windows（10/11，x64）

需要：Python 3、MoonBit、CMake、MSVC C++ 工具链（含 ATL）等环境与工具。

1. 安装 MoonBit 工具链：

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

2. 安装 CMake 与 MSVC C++ 工具链：

```powershell
winget install Kitware.CMake
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

3. 补装 ATL 组件：

```powershell
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' -ArgumentList 'modify','--installPath','"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"','--add','Microsoft.VisualStudio.Component.VC.ATL','--quiet','--norestart' -Verb RunAs -Wait
```

4. 构建、运行。**moon 在 Windows 编译原生代码时会从 PATH 里找 `cl`，须在「x64 Native Tools Command Prompt for VS 2022」里执行，或先在命令行里 call `vcvars64.bat`**：

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
moon run examples/showcase
```

（原生层缺失时 moon 会自动调 `python3 scripts\prepare.py` 补建；如需手动执行，
须在上述 MSVC 环境中运行。）

### 作为依赖使用

预编译的原生库（Linux x64 / macOS 通用二进制 / Windows x64）随包分发，
`moon add` 后直接构建运行，无需本地编译 libyue 的 C++ 源码：

```sh
moon add NoahLiu/moonbit-libyue
moon run src
```

**注意工程须以 native 为目标**：本库仅支持 native 后端；`moon new` 模板默认
`preferred_target = "wasm"`，会因 FFI 文件不参与编译而报 `ffi_* is unbound`，
把工程 moon.mod 的 `preferred_target` 改为 `"native"`（或命令行加
`--target native`）即可。

Linux 侧链接期仍需 GTK 等系统开发包（见上文 apt 清单）；其他平台（如
linux/arm64）自动回退源码构建，需具备 CMake 与 C++ 工具链。

### 声明式 UI

窗口可以用声明式节点树(`@yue.mount_window`)描述,不必手写 `new + set_content`。

**1. Hello 窗口** —— 标签与按钮两个节点,直接挂进窗口:

```moonbit
fn main {
  if !@yue.initialize() {
    return
  }
  let window = @yue.mount_window(
    [
      @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
      @yue.button("退出", on_click=fn() { @yue.quit() }),
    ],
    title="Hello",
    size=Some((420.0, 160.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  window.activate()
  @yue.run()
}
```

![Hello 窗口](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/hello.png)

**2. 响应式计数器** —— 状态放在 `Store`,`bind_label` 在每次更新时自动刷新标签,无需手写「点击后改文本」:

```moonbit
let clicks : @yue.Store[Int] = @yue.Store::new(0)
let window = @yue.mount_window(
  [
    @yue.vbox(
      [
        @yue.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
        @yue.bind_label(clicks, fn(n) { "已点 \{n} 次" }),
      ],
      style=[("padding", 24.0)],
    ),
  ],
  title="Counter",
  size=Some((320.0, 160.0)),
  center=true,
  on_close=fn(_w) { @yue.quit() },
)
```

![计数器窗口](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/counter.png)

更多节点类型见 [docs/zh/declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md)。

### 文档索引

| 文档 | 内容 |
|---|---|
| [components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md) | 主题组件库 API 一览,含演示截图 |
| [declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md) | 声明式 `Node`/`mount` 渲染树 + `Store` 响应式绑定 |
| [components.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components.md) | 控件 API 速查:经典 setter 与 `X::make` props 两种写法 |
| [layout.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/layout.md) | 布局样式键全集(Yoga flexbox) |
| [adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md) | 各平台实测坑、根因与验证结论 |
| [tray.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/tray.md) | Linux 托盘:SNI 协议栈设计与后端降级 |
| [relink.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/relink.md) | 原生层变更后强制重链 |

完整索引:[docs/zh/README.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/README.md)。

## 开发贡献

- 构建与测试:`moon check && moon test`
- 新增控件:`shim/yue_mbt.cpp` 机械转换 → `shim/include/yue_mbt.h` 声明 → `yue/ffi.mbt` 加 extern → 新 `yue/*.mbt` 加类型与方法(FFI 规范见 `.agents/skills/moonbit-c-binding/`)。
- 当前封装面约 320 个 ABI 函数(`yue/ffi.mbt` 中 324 个 `extern "c"` 声明)。
- 实测踩坑与平台适配经验一律回写 [docs/zh/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md);使用文档与代码注释只写用法。
- shim/vendor 变更后须强制重链:`moon clean` 或删对应可执行文件,见 [docs/zh/relink.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/relink.md)。

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue
- MoonBit 技能库：`.agents/skills/`（`moonbit-c-binding`、`make-moonbit-c-bindings`）
- AI 协作规则：`AGENTS.md`
- 平台适配经验：[docs/zh/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)
