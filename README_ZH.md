# moonbit-libyue

[![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

[libyue](https://libyue.com/docs/latest/cpp/) 的 MoonBit 封装——用纯 MoonBit 编写 Windows / macOS / Linux 原生跨平台桌面应用。

简体中文 | [English](https://github.com/lb091188/moonbit-libyue/blob/master/README.md)

![组件库演示板](docs/images/showcase-basic.png)

## 三大特色

**🎨 现代主题** —— Element Plus 风格主题组件库（按钮 / 表单 / 导航 / 数据展示 / 反馈等 50+ 组件），全部自绘、三平台视觉一致；`theme_apply` 一行换肤，深浅自动跟随系统：

```moonbit
@yue.theme_apply({ ..@yue.default_theme(), primary: "#1E4FA3" })
```

**📝 声明式** —— 节点树描述界面，不手写 `new + set_content`：

```moonbit
let window = @yue.mount_window(
  [
    @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
    @yue.button("退出", on_click=fn() { @yue.quit() }),
  ],
  title="Hello", size=Some((420.0, 160.0)), center=true, on_close=fn(_w) { @yue.quit() },
)
```

**⚡ 信号响应式** —— 状态放 `Signal` / `Store`，绑定处自动刷新，不写「点击后改文本」的胶水：

```moonbit
let clicks = @yue.Signal::new(0)
@yue.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
@yue.bind(clicks, fn(n) { "已点 \{n} 次" }),  // 派生文本,点击即变
```

三者可单独用也可叠加：主题组件库是对外唯一窗口（统一视觉），libyue 原生控件与命令式写法同样保留。

> **不会 MoonBit？** 看 [五分钟上手教程](docs/zh/tutorial.md)：从 `moon new` 到窗口跑起来，附官方 MoonBit 教程与交互式 Tour 链接。

## 快速开始

```sh
# Ubuntu 24.04:装一次系统依赖(GTK/Webkit 开发包)
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev

# 作为依赖使用:原生库随包分发(三平台预编译),moon add 后零 C++ 编译
moon add NoahLiu/moonbit-libyue
moon run src

# 跑演示板
git clone https://github.com/lb091188/moonbit-libyue && cd moonbit-libyue
moon run examples/showcase
```

<details>
<summary>Windows(10/11, x64) 环境准备</summary>

需要 Python 3、MoonBit、CMake、MSVC C++ 工具链(含 ATL)；moon 在 Windows 编译原生代码时从 PATH 找 `cl`，须在「x64 Native Tools Command Prompt for VS 2022」执行，或先 call `vcvars64.bat`：

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex            # MoonBit
winget install Kitware.CMake
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
# 补装 ATL:
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' -ArgumentList 'modify','--installPath','"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"','--add','Microsoft.VisualStudio.Component.VC.ATL','--quiet','--norestart' -Verb RunAs -Wait
```

</details>

**注意工程须以 native 为目标**：`moon new` 模板默认 `preferred_target = "wasm"`，会报 `ffi_* is unbound`，把 moon.mod 的 `preferred_target` 改为 `"native"` 即可。

## 三种写界面的方式

| 层 | 用法 | 适合 |
|---|---|---|
| 1 | **主题组件库 + 声明式 + 响应式**：`button_t` / `side_menu` / `tag` … 节点 + `Store` 绑定 | 现代化应用外壳，推荐 |
| 2 | **libyue 原生控件 + 声明式 + 响应式**：`button` / `entry` / `slider` … 节点 + `Store` 绑定 | 原生外观 + 声明式写法 |
| 3 | **libyue 原生控件 + 命令式**：`Window::new` + `set_content` + setter | 贴近 libyue 原生 API |

## 演示

```sh
moon run examples/hello         # 原版控件最小窗口
moon run examples/hello-themed  # 主题组件库最小示例(theme_apply + button_t/input_t/label_t)
moon run examples/showcase      # 全功能演示板:15 页三组侧栏,组件库 + 系统能力全集
```

showcase 覆盖：基础/图标库/表单/导航/数据展示/反馈/代码与文档/事件与布局/Store 对照 + 原生控件/画布与富文本 + 系统集成/窗口/浏览器/环境与平台，左侧分组可折叠菜单，底栏版本号与 moon.mod 同步。更多截图见 [docs/zh/components-ui.md](docs/zh/components-ui.md)。

![导航组件页](docs/images/showcase-nav.png)

## 文档索引

| 文档 | 内容 |
|---|---|
| [components-ui.md](docs/zh/components-ui.md) | 主题组件库 API 一览 + 定制主题/深浅切换 |
| [declarative.md](docs/zh/declarative.md) | 声明式 `Node`/`mount` 渲染树 + `Store` 响应式绑定 |
| [components.md](docs/zh/components.md) | 控件 API 速查:经典 setter 与 `X::make` props 两种写法 |
| [layout.md](docs/zh/layout.md) | 布局样式键全集(Yoga flexbox) |
| [adaptation.md](docs/zh/adaptation.md) | 各平台实测坑、根因与验证结论 |
| [tray.md](docs/zh/tray.md) | Linux 托盘:SNI 协议栈设计与后端降级 |
| [relink.md](docs/zh/relink.md) | 原生层变更后强制重链 |

完整索引:[docs/zh/README.md](docs/zh/README.md)。

## 平台支持

Ubuntu 24.04(XFCE / GNOME / KDE) ✅ · Deepin 25 ✅ · Windows 10/11 ✅ · macOS 构建通过(CI,无真机)

## 开发贡献

- 构建与测试:`moon check && moon test`(提交门禁:零错误零警告)
- 新增控件:`shim/yue_mbt.cpp` 机械转换 → `shim/include/yue_mbt.h` 声明 → `yue/ffi.mbt` 加 extern → 新 `yue/*.mbt` 加类型与方法(FFI 规范见 `.agents/skills/moonbit-c-binding/`)
- 实测踩坑一律回写 [docs/zh/adaptation.md](docs/zh/adaptation.md);发布二进制推 `bin-*` 标签,原生层变更推 `vendor-*` 标签

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue
