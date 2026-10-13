# moonbit-libyue [![CI](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-native-gui/actions/workflows/ci.yml)

> **⚠ 已更名**——mooncakes 包名改为 **`NoahLiu/native-gui`**（原名 `NoahLiu/moonbit-libyue`；待自绘栈稳定后将旧名标记废弃）；子模块 `NoahLiu/yue-media` → **`NoahLiu/gui-media`**、`NoahLiu/yue-examples` → **`NoahLiu/gui-examples`**。

> **来时的路**——本库最初是 [赵成(zcbenz)](https://github.com/zcbenz) 的 [Yue / libyue](https://github.com/yue/yue) 的 MoonBit 封装，布局沿用 [Yoga](https://github.com/facebook/yoga) 的 flexbox。如今这套栈已自绘、不再依赖二者——过去是**用**它们，现在是**学**它们留下的思路。也感谢 [MoonBit](https://github.com/moonbitlang)。

[MoonBit](https://github.com/moonbitlang) 生态的**原生跨平台桌面 GUI 库**——窗口、像素、事件循环、布局与控件全部纯 MoonBit 实现。一套代码在 Windows ✅ / Linux ✅ 上跑原生窗口，macOS 后端暂未开发；`moon add` 后零配置直接运行。

简体中文 | [English](https://github.com/lb091188/moonbit-native-gui/blob/master/README.md)

![组件库演示板](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/images/showcase-main.png)

![Linux(XFCE)实机演示](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/images/showcase-anim-linux.webp) ![Windows 实机演示](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/images/showcase-anim-windows.webp)

*图二 Linux(XFCE) · 图三:Windows —— 同一套 MoonBit 代码*

## 核心特色

**🎨 自绘控件，各平台同一套主题** —— 控件由库自带的光栅器绘制，各平台外观一致；默认跟随系统主色强调色与明暗模式，主题是可直接覆盖的普通值。

**📝 声明式 UI** —— 用一棵节点树描述界面，交由库驱动：

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.label("Hello, MoonBit!", size=18.0)],
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

**⚡ 响应式状态** —— 状态放在 `Store` / `Signal`（`@core`）里，绑定的位置在数据变化时自动刷新。

**🖥 桌面级系统集成** —— 托盘、通知、全局快捷键、剪贴板、原生菜单、文件对话框、拖放、开机自启、媒体按键，以及音量 / 亮度 / 电源 / 浏览器历史 / 已装应用等系统查询，都在同一套 `@sys` API 之后。

**📊 自绘图表与富内容** —— 图表（折线 / 柱 / 饼 / 仪表 / 散点，另有雷达 / 热力 / 蜡烛 / 漏斗 / 箱线 / 桑基 / 树 / 矩形树 / 旭日 / 地图等，含横切交互层）与 Markdown 视图，由同一个光栅器绘制。

> `moon run examples/showcase` —— 完整演示板：组件库 + 系统能力。

## 包结构

`moon add NoahLiu/native-gui` 引入整个模块，但 MoonBit 只编译和链接你 import 的包——没用到的包不占二进制体积：

| `moon.pkg` 中的 import | 别名 | 内容 |
|---|---|---|
| `NoahLiu/native-gui/core` | `@core` | 应用宿主、事件循环、焦点 / 键 / 指针、菜单、通知、托盘、浮层、拖放、`Store` / `Signal` |
| `.../native-gui/ui` | `@ui` | 自绘控件与组件库：窗口挂载、标签 / 按钮、表单、显示、导航、日期、表格与虚拟列表、输入框、滚动、浮层、代码视图、声明式层 |
| `.../native-gui/render` | `@render` | 光栅器——纯 MoonBit 软件光栅（路径 / 填充 / 混合 / 渐变）加 Cairo 后端；位图、画布、图像、PNG |
| `.../native-gui/text` | `@text` | 文本层：字体族、字体、富文本与区间属性（Pango / DirectWrite） |
| `.../native-gui/theme` | `@theme` | 主题系统：色板派生 + 变更订阅 |
| `.../native-gui/icons` | `@icons` | 矢量图标系统 |
| `.../native-gui/sys` | `@sys` | 系统能力：自启动、空闲、子进程、环境、文件、JSON、对话框、浏览器历史 / 书签、最近文件、壁纸、音量、亮度、电源、打印机、显示器、窗口控制、应用查找… |
| `.../native-gui/input` | `@input` | 编辑内核与键码 |
| `.../native-gui/win` | `@win` | 平台窗口后端（Win32 / GTK3 的 C 桩）：快捷键、图标、输入法、消息框、通知、托盘、surface |
| `.../native-gui/dbus` | `@dbus` | Linux D-Bus 桥（托盘 SNI、通知、亮度、logind / upower、媒体、网络、屏保…） |
| `.../native-gui/chart` | `@chart` | 图表 + 横切交互层 |
| `.../native-gui/mdview` | `@mdview` | Markdown 渲染视图 |
| `.../native-gui/web` | `@web` | 内嵌 WebView |

更重的可选能力放在**独立模块**里，普通 `moon add` 不会带进来：

| 模块 | 内容 |
|---|---|
| `NoahLiu/gui-media` | 音视频引擎（ffmpeg 解码 + miniaudio 输出）与播放器组件。 |
| `NoahLiu/gui-examples` | 独立示例模块（systemprobe、native-web），依赖 `gui-media`。 |

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
moon run examples/showcase       # 完整演示板：组件 + 系统能力
```

## 平台支持

Ubuntu 24.04（XFCE / GNOME / KDE）✅ · Deepin 23 / 25 ✅ · Windows 10/11 ✅ · macOS 🚧 后端暂未开发

Windows 上构建出的 exe 是 GUI 子系统二进制——双击运行不弹控制台窗口。

## 文档导航

📚 **在线文档**：<https://moonbit-libyue.pages.dev/> —— 中文版在 [`/zh/`](https://moonbit-libyue.pages.dev/zh/)。

| 文档 | 内容 |
|---|---|
| [docs/README.md](docs/README.md) | 文档索引与包结构总览 |
| [docs/adaptation.md](docs/adaptation.md) | 平台适配经验：各平台实测坑与修复 |
| [docs/autostart.md](docs/autostart.md) | 跨平台开机自启 |
| [docs/tray.md](docs/tray.md) | Linux 托盘：SNI 协议栈设计 |
| [docs/zh/system-capabilities.md](docs/zh/system-capabilities.md) | 系统能力总览 |

## 参与贡献

欢迎参与：报平台兼容问题、补控件、补文档都算——macOS 后端是最大的空缺（暂未开发，需要一台 Apple Silicon 机器）。几条基本要求：

- **提交门禁**：全仓 `moon check && moon test` 零错误零警告
- **经验留档**：实测坑与修复写进 [adaptation.md](docs/adaptation.md)，不要只留在提交信息里
- **小批次**：一个提交一个内聚改动，提交信息简短

补控件、CI 与发布的完整流程见 [AGENTS.md](AGENTS.md)。

## 许可

`moonbit-libyue` 以 [MIT 许可](LICENSE)发布。

## 参考

- [MoonBit 文档](https://docs.moonbitlang.cn/)
- 本库从中学习过思路的项目：[Yue / libyue](https://github.com/yue/yue) · [Yoga](https://github.com/facebook/yoga)
