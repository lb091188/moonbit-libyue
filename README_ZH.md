# moonbit-libyue

[![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

[libyue](https://libyue.com/docs/latest/cpp/) 的 MoonBit 封装——用纯 MoonBit 编写 Windows / macOS / Linux 原生跨平台桌面应用。

## 测试支持

- [x] Ubuntu 24.04 Xfce
- [x] Ubuntu 24.04 GNOME
- [x] Ubuntu 24.04 KDE
- [x] Deepin 25
- [x] Windows 10 / 11

简体中文 | [English](https://github.com/lb091188/moonbit-libyue/blob/master/README.md)

## Yue

一个跨平台原生桌面应用库（A library for creating native cross-platform GUI apps）。

## 三种写界面的方式

| 层 | 用法 | 典型代码 | 适合 |
|---|---|---|---|
| 1 | **主题组件库 + 声明式 + 响应式** | `button_t` / `side_menu` / `tag` / `alert` … 节点 + `Store` 绑定 | 现代化应用外壳，推荐 |
| 2 | **libyue 原版控件 + 声明式 + 响应式** | `button` / `entry` / `slider` … 节点 + `Store` 绑定 | 原生外观 + 声明式写法 |
| 3 | **libyue 原版控件 + 命令式** | `Window::new` + `set_content` + setter | 贴近 libyue 原生 API |

主题层在保持原生渲染与体积的同时，提供 Element Plus 风格的现代外观、声明式节点树与响应式数据绑定——原生，但好用。

## 演示

### 现代示例——主题组件库（第 1 层）

`moon run examples/components` —— 四页演示板，覆盖主题组件库全部功能：每个组件、每种状态；API 一览见 [docs/zh/components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md)：

![基础组件](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-basic.png)

![导航](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-nav.png)

![数据展示](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-data.png)

![反馈](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/components-feedback.png)

### 传统示例——原版控件（第 2/3 层）

`moon run examples/showcase` —— 12 页演示，覆盖原版控件全部能力（基础控件/输入/画布/网页/表格/对话框/菜单/托盘/剪贴板/事件…）——控件页：

![showcase 控件页](https://gitee.com/noahliu0911/moonbit-libyue/raw/master/docs/images/widgets.png)

更多示例（共 17 个：hello / editor / browser / drawing / table / 拖拽 / 托盘 …）见 [examples/](https://gitee.com/noahliu0911/moonbit-libyue/tree/master/examples)。

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
 **注意首次构建会到 github 下载 libyue 相关依赖**

```sh
moon run examples/hello
```

零配置：链接参数由构建钩子 `scripts/prebuild.py` 按当前系统生成并自动传播，静态库缺失时自动执行 `scripts/prepare.py` 补建。`prepare.py` 幂等可重跑；Linux/Windows 切换后首次构建自动重建。

#### Windows（10/11，x64）

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
moon run src   # 无需任何链接配置；安装时自动构建原生层，缺失时构建钩子自动补建
```

### 声明式 UI

窗口可以用声明式节点树(`@yue.mount_window`)描述,不必手写 `new + set_content`。以下示例均可直接运行(截图链接指向 Gitee 仓库内文件)。

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

布局(yoga 弹性盒)、滚动、分组等更多节点类型见 [docs/zh/declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md)。

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

- 构建与测试:`moon check && moon test`——纯 MoonBit 部分(DBus 线路编解码、颜色/表格值编解码)不依赖原生库,可直接测试。
- 新增控件:`shim/yue_mbt.cpp` 机械转换 → `shim/include/yue_mbt.h` 声明 → `yue/ffi.mbt` 加 extern → 新 `yue/*.mbt` 加类型与方法(FFI 规范见 `.agents/skills/moonbit-c-binding/`)。
- 当前封装面约 320 个 ABI 函数(`yue/ffi.mbt` 中 324 个 `extern "c"` 声明)。
- 实测踩坑与平台适配经验一律回写 [docs/zh/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md);使用文档与代码注释只写用法。
- shim/vendor 变更后须强制重链:`moon clean` 或删对应可执行文件,见 [docs/zh/relink.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/relink.md)。

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue 的 `lua_yue/`
- MoonBit 技能库：`.agents/skills/`（`moonbit-c-binding`、`make-moonbit-c-bindings`）
- AI 协作规则：`AGENTS.md` · 平台适配经验：[docs/zh/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)
