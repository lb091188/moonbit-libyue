# 文档索引

**native-gui**：MoonBit 的轻量跨平台桌面 GUI 框架。窗口、像素、事件循环、布局与控件全部纯 MoonBit 实现，mooncakes 包名 `NoahLiu/native-gui`。

## 包结构

`moon add NoahLiu/native-gui` 一次引入整个模块，MoonBit 只编译和链接你 import 的包，没 import 的不进二进制：

| `moon.pkg` 里的导入 | 别名 | 内容 |
|---|---|---|
| `NoahLiu/native-gui/base` | `@base` | 平台无关基元：`Store` / `Signal` / `ListStore`、焦点栈、键码、帧末合并与账本 |
| `NoahLiu/native-gui/shell` | `@shell` | 系统能力壳层：菜单、全局热键门面、托盘、通知、外部打开、事件循环调度器与只读平台探针 |
| `NoahLiu/native-gui/widget` | `@widget` | 自绘控件宿主：布局树映射、命中与事件路由、绘制遍历、声明式 `Node`、浮层两档、拖放、输入映射、`App` 泵 |
| `NoahLiu/native-gui/core` | `@core` | G9 Batch 2 迁移期门面：`@base`/`@shell`/`@widget` 名仍经 `@core` 转发可用 |
| `.../native-gui/ui` | `@ui` | 自绘控件与组件库：窗口挂载、标签 / 按钮、表单、显示、导航、日期、表格与虚拟列表、输入框、滚动、浮层、代码视图、声明式层 |
| `.../native-gui/render` | `@render` | 光栅器：纯 MoonBit 软件光栅 + Cairo 后端；位图、画布、图像、PNG |
| `.../native-gui/text` | `@text` | 文本层：字体族、字体、富文本与区间属性（Pango / DirectWrite） |
| `.../native-gui/theme` | `@theme` | 主题系统：色板派生与变更订阅 |
| `.../native-gui/icons` | `@icons` | 矢量图标系统 |
| `.../native-gui/sys` | `@sys` | 系统能力：自启动、空闲、子进程、环境、文件、JSON、对话框、浏览器历史 / 书签、最近文件、壁纸、音量、电源、打印机、显示器、窗口控制、应用查找 |
| `.../native-gui/input` | `@input` | 编辑内核与键码 |
| `.../native-gui/win` | `@win` | 平台窗口后端（Win32 / GTK3 的 C 桩）：快捷键、图标、输入法、消息框、通知、托盘、surface |
| `.../native-gui/dbus` | `@dbus` | Linux D-Bus 桥：托盘 SNI、通知、logind / upower、媒体、网络、屏保 |
| `.../native-gui/chart` | `@chart` | 图表与横切交互层 |
| `.../native-gui/mdview` | `@mdview` | Markdown 渲染视图 |
| `.../native-gui/style` | `@style` | 样式层：样式表写成 MoonBit 值，含状态类与过渡 |

较重的可选能力放在独立模块，`moon add NoahLiu/native-gui` 不会把它们拉进来：

| 模块 | 内容 |
|---|---|
| `NoahLiu/gui-media` | 音视频引擎与播放器组件。
| `NoahLiu/gui-webview` | 内嵌 WebView（WebKitGTK / WebView2），2026-10-16 起从主模块 `web` 子包出成。 |
| `NoahLiu/gui-examples` | 独立示例模块，依赖 `gui-media`。 |

两种「可选」不要混：没 import 的子包不进二进制——`moon.pkg` 的 import 是编译与链接边界；没依赖的模块连解析和 prebuild 都不发生——`moon.mod` 的 import 决定依赖闭包。能力要选后者，就必须住在自己的模块里。

## 演示

示例由浅入深：

```sh
moon run examples/hello          # 最小窗口
moon run examples/hello-themed   # 主题控件集
moon run examples/showcase       # 完整演示板
moon run examples/browser        # 内嵌 WebView 浏览器
```

`examples/showcase` 覆盖组件库全部家族、图表、代码与文档视图、系统集成与过渡效果，并带一页只读的系统能力探测。每页源码独立成文件（`examples/showcase/pages/*.mbt`），可直接复制改用。各组件截图：

![基础组件](/images/showcase-basic.png)

![表单组件](/images/showcase-form.png)

![数据展示](/images/showcase-data.png)

![代码与文档](/images/showcase-code.png)

![系统集成](/images/showcase-system.png)

## 分流

| 文档 | 内容 |
|---|---|
| [tutorial.md](tutorial.md) | 五分钟上手：装工具链、建工程、做出第一扇带点击计数的窗口 |
| [components.md](components.md) | 组件速查（`@ui`）：各控件构造器的入口签名与用途，按家族分组 |
| [declarative.md](declarative.md) | 声明式层与响应式：节点树与 `mount_window`、`Store` / `Signal`、`for_list` / `when`、原位替换 |
| [layout.md](layout.md) | 布局：yoga-mbt 的 Flexbox 口径与 `@style` 的 `Style` 字段集、`class` 通道 |
| [build.md](build.md) | 构建与链接：prebuild 托管链接参数、改 C 桩不重链的判别与处理 |
| [roadmap.md](roadmap.md) | 对外路线图：定位、现在能拿到什么、平台与功能矩阵、承诺与版本、下一步、待定决策、明确不做 |
| [design.md](design.md) | 前端化设计口径：样式表形态、组件命名映射、响应式补强、视图层用 `render` 函数替代模板 |
| [module-structure.md](module-structure.md) | 模块结构规划（规划中）：`gui/web` 出成 `gui-webview`、`core` 拆 `base`/`shell`/`widget` 的批次、代价与风险，跟踪在 `TODO.md` §1「G9 模块拆分」 |
| [gpu-architecture.md](gpu-architecture.md) | GPU 合成与 3D 路径架构决策：两层落地（合成器 + 控件级 GPU 绘制）+ 三级 fallback（WebGPU → Cairo → Pure）+ WebGPU via wgpu-native 后端选型 + `Widget.on_render` 口子，跟踪在 `TODO.md` §1「G11 GPU 合成与 3D 路径」 |
| [adaptation.md](adaptation.md) | 平台适配经验：各平台实测坑、根因与验证结论 |
| [autostart.md](autostart.md) | 开机自启：Linux 写 XDG .desktop、Windows 写 HKCU Run 键，统一 `is_enabled` / `enable` / `disable` |
| [tray.md](tray.md) | Linux 托盘：SNI 协议栈设计、架构、后端降级与桌面兼容性 |
| [system-capabilities.md](system-capabilities.md) | 系统能力总览（`@sys`）：音量、应用查找、色温、壁纸、显示器、窗口管理、剪贴板监听、系统信息、打印机、最近文件、浏览器历史等，统一 `Result` 语义；含子进程与 D-Bus 调用层两块共享基建 |

项目总览与快速开始入口见仓库根 [README_ZH.md](https://github.com/lb091188/moonbit-native-gui/blob/master/README_ZH.md)。
