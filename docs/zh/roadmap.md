# 对外路线图

本文回答四个问题：**现在能做什么**、**都有什么功能点**、**什么算承诺**、**接下来做什么、明确不做什么**。

分工（2026-10-16 定）：本文「功能面全景」收**全部功能点**——已交付的与计划中的都在这一张目录里；仓库根 [TODO.md](https://github.com/lb091188/moonbit-native-gui/blob/master/TODO.md) **只留未完成项**（挂账与排期）；批次过程、根因与实测细节在 [adaptation.md](adaptation.md) 与 `git log`，三处不互相复述。

## 定位

MoonBit 生态的**原生桌面 GUI 库**——目标位置是 GTK / WinForms / AppKit 在各自生态里的角色：写桌面应用时的默认选择。

- **框架主体纯 MoonBit**：窗口宿主与事件循环、布局（Flexbox）、控件与组件库、光栅化、文字排印、主题全由本库实现；平台差异收敛在窗口、文字、图像解码、WebView、媒体几处 C 薄层
- **全栈自绘**：控件与主题跨平台一致，不依赖平台控件皮肤；深浅色与系统强调色默认跟随
- **跨平台同构**：一套代码三平台，能力探测 + 语义化降级——不支持的环境给 `Unsupported` 而不是崩
- **按需取用**：功能各自成包（14 个子包，见[文档索引](README.md)），不 import 不进二进制；媒体等重能力拆独立模块，不进默认依赖闭包

## 现在能拿到什么

| 入口 | 内容 |
|---|---|
| `moon add NoahLiu/native-gui` | 库本体：14 个子包与两个可选独立模块（gui-media / gui-examples） |
| 示例 | `examples/hello`（最小窗口）、`hello-themed`（主题控件集）、`showcase`（14 页演示板，每页源码独立成文件，是复制粘贴素材库） |
| 文档 | 本文所在文档站（VitePress，中英双语）与各包文档，见[文档索引](README.md) |
| CI | Linux 与 Windows 两条 job 每次推送全绿：库包测试（Linux 14 包 / Windows 12 包，dbus 与 sys 按平台能力排除）+ 构建 + 虚拟显示下启动冒烟，徽章见仓库 README |

## 平台支持矩阵

图例：✅ 已交付并验证 / 🚧 落地中 / ❌ 明确不做。

| 能力域 | Windows | Linux | macOS |
|---|---|---|---|
| 窗口与事件循环（自绘宿主、自研泵） | ✅ | ✅（X11 + GTK3） | 🚧 |
| 控件与组件库 / 主题 / 图标 / 图表 / Markdown 视图 | ✅ | ✅ | 🚧 |
| 光栅与文字（自绘光栅 + Cairo / Pango / DirectWrite / CoreText） | ✅ | ✅ | 🚧 |
| 内嵌 WebView（WebView2 / WebKitGTK / WKWebView） | ✅ | ✅ | 🚧 |
| 系统能力门面 `@sys`（二十余族） | ✅ 系统 API 直调 | ✅ 命令线与文件直读 | 🚧 |
| Linux 桥 `@dbus`（托盘 SNI / 通知 / logind·upower / MPRIS…） | — | ✅ | — |
| 媒体（gui-media：ffmpeg 解码 + miniaudio 输出） | ✅ | ✅ | 🚧 |
| 无障碍（ATK / UIA / NSAccessibility） | ❌ | ❌ | ❌ |

- **Linux**：X11 为主链路；Wayland 会话可运行（窗口后端自带 Wayland 支持），依赖 X11 的能力按会话探测降级（全局快捷键、空闲检测等给 `Unsupported`）。兼容跨度 **deepin 20 ~ Ubuntu 26**，工具包**留守 GTK3**（理由见「明确不做」）。
- **macOS**：后端在 `mac` 分支落地中（窗口 / 文字 / 图像解码 / WebView / 系统能力族已有实现），**尚未合流 master**；master 上 macOS 走占位实现，门面一律语义化 `Unsupported`。合流前置是真机验证收口。

## Linux 兼容档位

承诺跨度 deepin 20 ~ Ubuntu 26，验证按「库版本 × 桌面环境 × 会话类型」三元组选**代表档位**，不按发行版数量堆测：

| 档位 | 代表 | 覆盖的变量 | 状态 |
|---|---|---|---|
| 地板 | deepin 20（Debian 10 底） | GTK 3.24.5、webkit2gtk-4.0（无 4.1）、libsoup2、ffmpeg 4.1 时代、glibc 2.28 | 待验证 |
| 主链路 | Ubuntu 24.04 + X11 + XFCE | 开发机与 CI 所在档 | 已验证（真机 + CI） |
| 天花板 | Ubuntu 26 | GTK3 是否仍随发行版提供、webkit 4.1+ | 待验证 |

另一个轴是**桌面环境**（与发行版无关）：托盘 SNI、通知、深浅色与强调色读取、全局快捷键需在至少一个非 XFCE 桌面（KDE 或 DDE）上过一遍。

各能力域在上述档位上的结果分三类：**正常** / **语义化降级**（环境缺工具或服务，给 `Unsupported`，不算缺陷）/ **待修**。当前待核对项：

- **内嵌 WebView**：构建只探测 `webkit2gtk-4.1`，地板档无此 `.pc` → web 包退为占位实现（能力 `Unsupported`）；若地板档要承诺 web，需加 4.0 回退探测。
- **GTK API 地板**：把窗口桩用到的 GTK 函数面与 3.24.5 核对一遍，确认没有 3.24 之后才引入的调用。
- **媒体线**：地板档 ffmpeg 开发包版本面与运行期 so 版本兼容。
- **命令线能力**：音量（wpctl / pactl）、夜间色温（xrandr / redshift）、显示器（xrandr）、空闲（XSS）——地板档默认是否随系统安装这些工具；不装即语义化降级，写进清单而不是当缺陷。
- **工具链**：最新 moon 工具链在 glibc 2.28（Debian 10）上的可运行性——地板档构建的第一道闸。

验证方式：构建与无头判据在 VM / 容器上跑，能不进 GUI 的都不进；托盘、通知外观、主题色这类需要人眼的项进人工清单。

## 功能面全景

图例：✅ 已交付并验证 · 🚧 部分（缺口见 TODO）· ⏳ 计划中 · ❌ 明确不做。

本节是**能力目录**，不是施工记录：每条只回答「有什么、在哪、成什么样」。批次过程、根因与验收细节在 [adaptation.md](adaptation.md) 与 `git log`；未完成的排期在仓库根 [TODO.md](https://github.com/lb091188/moonbit-native-gui/blob/master/TODO.md)。

### 地基与宿主

| 功能点 | 状态 | 落点 | 成什么样 |
|---|---|---|---|
| 绘制契约与离屏像素回归 | ✅ | `render` | 纯 MoonBit 软件光栅（路径/填充/混合/渐变）+ Cairo 后端；位图、画布、图像、PNG 编解码；像素级判据可无头跑 |
| 窗口地基与事件循环 | ✅ | `win`、`core/loop.mbt` | GTK3 / Win32 窗口 + 自研泵；循环归 MoonBit，平台库不再持有主循环 |
| 文字排印 | ✅ | `text`、`render/cairo.mbt` | Pango（Linux）/ DirectWrite（Windows）字体族与富文本区间属性；文本 measure 与 baseline 回灌布局 |
| 布局层 | ✅ | `modules/yoga-mbt`、`core/widget.mbt` | Flexbox 全量；脏区增量重排（子树版本 + 入参指纹跳过干净子树）；Yoga 真实 bug 语料已转回归用例 |
| 焦点栈、键鼠接入与编辑内核 | ✅ | `core/focus.mbt`、`input` | Tab/Shift+Tab 由宿主驱动；按下即聚焦；跨平台同构的编辑内核（选区、撤销、IME 接缝） |
| 平台输入映射层 | ✅ | `core/input_map.mbt` | 三平台修饰位折算、Win/mac 键码表、按钮号、IME 按键路由判据（纯函数 + 回归） |
| 输入法通道 | ✅ | `win`、`text` | 四条件（preedit / commit / surrounding / caret）真机闭环；Linux 纯通道与 Windows `WM_IME_*` 两路；换焦点不串框 |
| 应用宿主 | ✅ | `core/app.mbt` | 窗口 + `Loop` + 控件树 + 输入法通道 + 脏标上屏收在一处；原始事件 `raw_to_event` 独立可测 |
| 自绘控件宿主 | ✅ | `core/widget.mbt` | 布局树 ↔ 控件树映射；绝对矩形单点折算；指针/滚轮/按键沿祖先链冒泡；绘制逐层平移 + 裁剪 |
| 声明式层 | ✅ | `core/node.mbt`、`ui` | `Node` / `bind_node` / `swap_node` / `Store` / `Signal`；`mount_window` 挂进宿主；`render` 函数即视图（无模板语言） |
| 样式层 | ✅ | `style` | 样式表写成 MoonBit 值（`Style` 规则块 + 具名 class 常量）、`hover/active/focus` 状态桶、`merge` 逐属性并集、过渡与阴影 |
| 主题系统 | ✅ | `theme` | 色板派生 + 变更订阅；跟随系统明暗与强调色 |
| 窗口级按键兜底通道 | ✅ | `core/app.mbt` | `App::add_key_fallthrough`：焦点链没消费或无焦点时按注册序问处理器，第一个 `true` 截断；摘掉的组件用 `Widget::is_painted()` 自证活体 |
| 输入法通道补齐 | 🚧 | `win`、`text` | ibus 一套复验待确认；macOS `NSTextInputClient` 待真机；preedit 观感/候选窗位置等待肉眼确认 |
| 原生子表面通道与其消费者 | ⏳ | `win/surface.mbt`、`web`、媒体 | 网页与视频作为纹理/子表面的统一形态，见 TODO §1「G8」 |
| 模块拆分 | ⏳ | `modules/` | 判据与批次见 [module-structure.md](module-structure.md)；`gui/web` 出成 `gui-webview`、`core` 三刀 `base`/`shell`/`widget`，排期在 TODO §1「G9」 |
| 窗口内按键路由补齐 | ⏳ | `core/app.mbt`、`ui` | 抬起事件投递、焦点链与兜底的优先级、方向键归属表、IM 门控复验——TODO §1「G10」 |

### 控件与组件

（逐节续写：绘图与资源 / 表单与交互 / 展示与导航 / 表格与列表 / 浮层与弹层 / 图表 / Markdown / 系统能力 / webview / 媒体 / 交付面 / 跨平台能力面。）

## 承诺与版本

- 当前版本 `0.1.1`：**0.x 阶段接口随批次演进**，破坏性改动在提交信息写明并同步更新文档。
- **稳定面清单与 1.0 时点待定**：落定后本节按「承诺面（1.x 内不破坏）/ 实验面（随批演进）」逐包列出。

## 接下来的方向

1. **上手门槛**：把「装 moon → `moon add` → 出窗口」的最短路径放进首页；每平台前置依赖一句话说清（Linux 构建需要 GTK3 开发包）；缺依赖时构建报错自带修复提示（prebuild 已按此口径退出非零）。
2. **可信度**：CI 门禁 + 真机人工清单 + 版本承诺（见上）。能力族的验收一律「各平台实现 + CI 可查 + 真机清单」三件套。
3. **内容**：文档站与组件文档、教程、showcase 持续补齐；组件文档配图，教程给可运行的最小工程。
4. **治理**：issue 模板与贡献指南随对外投放建立；本文与平台矩阵随每批更新，不积压。

## 待定决策

- **macOS 纳入对外承诺的时点**：前置是 mac 分支真机验证收口（Retina 观感、输入法内联、拖窗循环、通知、多屏读数、授权弹窗）。
- **稳定面清单与 1.0 时点**：逐包划分承诺面 / 实验面后，本文与各包文档同步。

## 明确不做

- **无障碍**（ATK / UIA / NSAccessibility）：自绘文本栈暂不含，只记不办。
- **单平台能力进跨平台门面**：只有单一平台实现的能力不做门面，也不留挂账。
- **Linux 工具包升级**：留守 GTK3——它是 deepin 20 到 Ubuntu 26 的公共交集，GTK4 会把系统地板抬到 2021 年之后；不引入 Qt（同级依赖的横向替换，换不来新能力）。脱 GTK 的唯一形态是降为可选后端。
- **原生控件皮肤**：不作主题化路径；按平台开关的原生兜底例外需逐条登记评审。
- **按「参考实现有什么」平移接口**：接口由真实用例驱动，不为对齐而补。
