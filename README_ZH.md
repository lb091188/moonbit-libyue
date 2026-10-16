# native-gui [![CI](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml)

> **⚠ 已更名**——本项目现名 **native-gui**（原名 `moonbit-libyue`）：mooncakes 包名 **`NoahLiu/native-gui`**（待自绘栈稳定后将旧名标记废弃）；子模块 `NoahLiu/yue-media` → **`NoahLiu/gui-media`**、`NoahLiu/yue-examples` → **`NoahLiu/gui-examples`**。

> **来时的路**——本库最初是 [赵成(zcbenz)](https://github.com/zcbenz) 的 [Yue / libyue](https://github.com/yue/yue) 的 MoonBit 封装，布局沿用 [Yoga](https://github.com/facebook/yoga) 的 flexbox。如今这套栈已自绘、不再依赖二者——过去是**用**它们，现在是**学**它们留下的思路。也感谢 [MoonBit](https://github.com/moonbitlang)。

[MoonBit](https://github.com/moonbitlang) 生态的**桌面 GUI 库**——把桌面应用需要的系统集成做全（托盘 / 通知 / 快捷键 / 自启 / D-Bus…），渲染、布局与控件由自有的纯 MoonBit 栈实现、不依赖 Skia 等重型图形引擎。一套代码跑 Windows ✅ / Linux ✅ 原生窗口，macOS 后端在 `mac` 分支落地中；`moon add` 后零配置直接运行。

简体中文 | [English](https://github.com/lb091188/moonbit-native-gui/blob/master/README.md)

![组件库演示板](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-main.png)

![Linux(XFCE)实机演示](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-anim-linux.webp) ![Windows 实机演示](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-anim-windows.webp)

*图二 Linux(XFCE) · 图三:Windows —— 同一套 MoonBit 代码*

## 核心特色

**🖥 桌面系统集成** —— 托盘（SNI / NSStatusItem / Shell_NotifyIcon）、通知、全局快捷键、剪贴板、原生菜单、文件对话框、拖放、开机自启、空闲检测、MPRIS 媒体控制（Linux），以及音量 / 电源 / 壁纸 / 显示器 / 打印机 / 浏览器历史 / 已装应用等系统查询，都在同一套 `@sys` / `@core` API 之后——能力探测 + 结构化降级，不静默失败。

**🎨 轻量自绘，各平台同一套主题** —— 渲染走库自带的纯 MoonBit 软件光栅器（可选 Cairo 后端），不依赖 Skia 等重型图形引擎；`hello` 最小窗口的 release 二进制 **1.1 MB**（Linux 实测）。控件观感跨平台一致，默认跟随系统强调色与明暗模式，主题是可直接覆盖的普通值。

**📊 图表与富内容** —— 图表（折线 / 柱 / 饼 / 仪表 / 散点，另有雷达 / 热力 / 蜡烛 / 漏斗 / 箱线 / 桑基 / 树 / 矩形树 / 旭日 / 地图等，含横切交互层）、Markdown 视图、内嵌 WebView，与自绘控件同一个光栅器、同一棵布局树。

**📝 声明式 UI 与响应式状态** —— 界面以树描述、`mount_window` 一步挂载；状态放 `Store` / `Signal`，绑定点随数据自动刷新：

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.text("Hello, MoonBit!", font_size=18.0)],
    title="Hello, MoonBit!",
    width=400,
    height=300,
  ) {
    None => {
      // 本平台没有窗口后端或没有显示服务
      return
    }
    Some(a) => a
  }
  app.run()
}
```

> `moon run examples/showcase` —— 完整演示板：组件库 + 系统能力探测 + 扩展图表（15 页）。

## 生态坐标

MoonBit 生态内的 GUI 能力各有分工：[MoUI](https://github.com/wzzc-dev/MoUI) 面向多端共享逻辑（Skia / WebGPU 渲染），[Sun](https://github.com/wzzc-dev/sun) 提供图形与文本渲染底层。native-gui 与它们零代码依赖，专注第三条线——**桌面应用的一站式交付**：把系统集成做深，把桌面常用件（图表 / Markdown / WebView）做成开箱组件。

## 包结构

`moon add NoahLiu/native-gui` 引入整个模块，但 MoonBit 只编译和链接你 import 的包——没用到的包不占二进制体积：

| `moon.pkg` 中的 import | 别名 | 内容 |
|---|---|---|
| `NoahLiu/native-gui/core` | `@core` | 应用宿主、事件循环、焦点 / 键 / 指针、菜单、通知、托盘、热键门面、浮层、拖放、`Store` / `Signal` |
| `.../native-gui/ui` | `@ui` | 自绘控件与组件库：窗口挂载、标签 / 按钮、表单、显示、导航、日期、表格与虚拟列表、输入框、滚动、浮层、代码视图、声明式层 |
| `.../native-gui/render` | `@render` | 光栅器——纯 MoonBit 软件光栅（路径 / 填充 / 混合 / 渐变）加 Cairo 后端；位图、画布、图像、PNG |
| `.../native-gui/text` | `@text` | 文本层：字体族、字体、富文本与区间属性（Pango / DirectWrite） |
| `.../native-gui/theme` | `@theme` | 主题系统：色板派生 + 变更订阅 |
| `.../native-gui/icons` | `@icons` | 矢量图标系统 |
| `.../native-gui/sys` | `@sys` | 系统能力：自启动、空闲、子进程、环境、文件、JSON、对话框、浏览器历史 / 书签、最近文件、壁纸、音量、电源、打印机、显示器、窗口控制、应用查找… |
| `.../native-gui/input` | `@input` | 编辑内核与键码 |
| `.../native-gui/win` | `@win` | 平台窗口后端（Win32 / GTK3 的 C 桩）：快捷键、图标、输入法、消息框、通知、托盘、surface |
| `.../native-gui/dbus` | `@dbus` | Linux D-Bus 桥（托盘 SNI、通知、logind / upower、媒体、网络、屏保…） |
| `.../native-gui/chart` | `@chart` | 图表 + 横切交互层 |
| `.../native-gui/mdview` | `@mdview` | Markdown 渲染视图 |
| `.../native-gui/web` | `@web` | 内嵌 WebView |
| `.../native-gui/style` | `@style` | 样式层：样式表写成 MoonBit 值（`Style` 规则块 + 具名 class 常量、hover / active / focus 状态、过渡） |

更重的可选能力放在**独立模块**里，普通 `moon add` 不会带进来：

| 模块 | 内容 |
|---|---|
| `NoahLiu/gui-media` | 音视频引擎（ffmpeg 解码 + miniaudio 输出）与播放器组件。 |
| `NoahLiu/gui-examples` | 独立示例模块（audio / video 播放示例），依赖 `gui-media`。 |

**两层「可选」要分清** —— 不 import 的子包不占二进制体积（`moon.pkg` 的 import 是编译 / 链接边界）；不依赖的模块根本不会被解析或预构建（`moon.mod` 的 import 决定依赖闭包）。

## 快速开始

刚接触 MoonBit？[文档站](https://moonbit-libyue.pages.dev/zh/) 覆盖工具链与第一个窗口。

前置：MoonBit 原生工具链。

```sh
moon add NoahLiu/native-gui
```

然后跑一个自带示例：

```sh
moon run examples/hello          # 最小窗口
moon run examples/hello-themed   # 主题控件集
moon run examples/showcase       # 完整演示板：组件 + 系统探测 + 扩展图表
moon run examples/browser        # 内嵌 WebView 浏览器（演示菜单 + 状态栏）
```

## 平台支持

Ubuntu 24.04（XFCE / GNOME / KDE）✅ · Deepin 23 / 25 ✅ · Windows 10/11 ✅ · macOS 🚧 `mac` 分支落地中（Cocoa / CoreText / ImageIO / WKWebView，CI 全绿待真机复验）

Windows 上构建出的 exe 是 GUI 子系统二进制——双击运行不弹控制台窗口。

## 文档导航

📚 **在线文档**：<https://moonbit-libyue.pages.dev/> —— 中文版在 [`/zh/`](https://moonbit-libyue.pages.dev/zh/)。

| 文档 | 内容 |
|---|---|
| [docs/README.md](docs/README.md) | 文档索引与包结构总览 |
| [docs/zh/adaptation.md](docs/zh/adaptation.md) | 平台适配经验：各平台实测坑与修复 |
| [docs/adaptation.md](docs/adaptation.md) | Platform adaptation notes (English) |
| [docs/zh/autostart.md](docs/zh/autostart.md) | 跨平台开机自启 |
| [docs/zh/tray.md](docs/zh/tray.md) | Linux 托盘：SNI 协议栈设计 |
| [docs/zh/system-capabilities.md](docs/zh/system-capabilities.md) | 系统能力总览 |
| [docs/zh/design.md](docs/zh/design.md) | 前端化设计口径（样式层与组件库设计笔记） |

## 参与贡献

欢迎参与：报平台兼容问题、补控件、补文档都算——macOS 已在 `mac` 分支落地，真机目视复验与并线是当前最大的开放事项（需要一台 Apple Silicon 机器）。几条基本要求：

- **提交门禁**：库模块在 `gui/` 下 `moon check` + `moon test core ui render text theme icons sys input win dbus chart mdview web style` 零错误零警告
- **经验留档**：实测坑与修复写进 [adaptation.md](docs/zh/adaptation.md)，不要只留在提交信息里
- **小批次**：一个提交一个内聚改动，提交信息简短

补控件、CI 与发布的完整流程见 [AGENTS.md](AGENTS.md)。

## 许可

`native-gui` 以 [MIT 许可](LICENSE)发布。

## 参考

- [MoonBit 文档](https://docs.moonbitlang.cn/)
- 本库从中学习过思路的项目：[Yue / libyue](https://github.com/yue/yue) · [Yoga](https://github.com/facebook/yoga)
