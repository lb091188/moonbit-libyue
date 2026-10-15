# 文档索引

本目录是 **native-gui** 的使用文档——[MoonBit](https://github.com/moonbitlang) 生态的原生跨平台桌面 GUI 库：窗口、像素、事件循环、布局与控件全部纯 MoonBit 实现，mooncakes 包名为 `NoahLiu/native-gui`。

## 包结构

`moon add NoahLiu/native-gui` 一次拿全整个模块，但 MoonBit 只编译只链接你 import 的那些（没 import 的包不进二进制）：

| `moon.pkg` 里的导入 | 别名 | 内容 |
|---|---|---|
| `NoahLiu/native-gui/core` | `@core` | 应用宿主、事件循环、焦点 / 键 / 指针、菜单、通知、托盘、浮层、拖放、`Store` / `Signal` |
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

较重的可选能力放在**独立模块**里，而不是主模块的子包——`moon add NoahLiu/native-gui` 不会把它们拉进来：

| 模块 | 内容 |
|---|---|
| `NoahLiu/gui-media` | 音视频引擎（ffmpeg 解码 + miniaudio 输出）与播放器组件。 |
| `NoahLiu/gui-examples` | 独立示例模块（systemprobe、native-web），依赖 `gui-media`。 |

**两种「可选」不要混**：没 import 的**子包**不进二进制（`moon.pkg` 的 import 是编译/链接边界）；没依赖的**模块**连解析与 prebuild 都不会发生（`moon.mod` 的 import 定义依赖闭包）。能力要做到后者，就必须住在自己的模块里。

## 演示

示例由浅入深：

```sh
moon run examples/hello          # 最小窗口
moon run examples/hello-themed   # 主题控件集
moon run examples/showcase       # 完整演示板：组件库 + 系统能力
```

`examples/showcase` 覆盖：基础 / 图标库 / 表单 / 导航 / 数据展示 / 图表 / 反馈 / 代码与文档 / 事件与布局 / Store 对照 / 窗口 + 画布与富文本 + 系统集成 + 过渡与效果；左侧分组可折叠菜单，底栏版本号与 moon.mod 同步。每页源码独立成文件（`examples/showcase/pages/*.mbt`），是最好的复制粘贴素材库；组件库各组件的截图：

![基础组件](/images/showcase-basic.png)

![表单组件](/images/showcase-form.png)

![数据展示](/images/showcase-data.png)

![代码与文档](/images/showcase-code.png)

![系统集成](/images/showcase-system.png)

## 分流

| 文档 | 内容 |
|---|---|
| [tutorial.md](tutorial.md) | 五分钟上手教程：装工具链、建工程、从零做一扇带点击计数的窗口 |
| [components.md](components.md) | 组件速查（`@ui`）：全部控件与组件构造器的入口签名与用途，按家族分（布局/文本/表单/展示/导航/表格/浮层/日期/响应式/拖放…） |
| [declarative.md](declarative.md) | 声明式层与响应式（`@core` + `@ui`）：节点树与 `mount_window`、`Store` / `Signal`、`for_list` / `when`、原位替换 |
| [layout.md](layout.md) | 布局样式：yoga-mbt（CSS Flexbox L1）+ `@style` 的 `Style` 字段集与 `class` 通道、min:auto 等必知口径 |
| [build.md](build.md) | 构建与链接：prebuild 全权托管链接参数、改 C 桩不重链这一条坑的判别与处理（旧 relink 的新栈后继文） |
| [roadmap.md](roadmap.md) | 对外路线图：定位、现在能拿到什么、平台支持矩阵、承诺与版本、下一阶段方向、待定决策、明确不做 |
| [design.md](design.md) | 前端化设计口径：样式表（MoonBit 的 `Style` 值 + 具名 class 常量，CSS 作导入通道）、组件前端化命名映射、响应式补强四项、视图层定案（`render` 函数替代模板） |
| [adaptation.md](adaptation.md) | 平台适配经验：各平台实测坑、根因与验证结论（持续更新） |
| [autostart.md](autostart.md) | 开机自启动：Linux 写 XDG .desktop、Windows 写 HKCU Run 键，is_enabled / enable / disable 统一语义 |
| [tray.md](tray.md) | Linux 托盘方案：SNI 协议栈设计、架构、后端降级、桌面兼容性 |
| [system-capabilities.md](system-capabilities.md) | 系统能力（包 `@sys`）：系统音量 / 应用查找 / 夜间色温 / 壁纸 / 显示器配置 / 系统窗口管理 / 剪贴板监听 / 系统信息 / 打印机 / 进程内环境变量与目录枚举 / 最近文件 / 浏览器书签与历史 / VS Code 历史…，统一 Result 语义；含子进程执行（procrun）与通用 D-Bus 调用层两块共享基建 |

项目总览与快速开始入口见仓库根 [README_ZH.md](https://github.com/lb091188/moonbit-native-gui/blob/master/README_ZH.md)。
