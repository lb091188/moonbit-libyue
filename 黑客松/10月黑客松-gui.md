# native-gui(原 moonbit-libyue) 项目申报书

## 基本信息

- 项目名称：native-gui
- 参赛者：刘斌（NoahLiu）
- 联系方式：<lbpeter0911@163.com>
- GitHub：<https://github.com/lb091188/moonbit-native-gui>
- 项目方向：MoonBit 轻量原生跨平台桌面 GUI 库
- 是否为移植项目：否

## 项目简介

native-gui 是 MoonBit 生态的**轻量原生跨平台 GUI 库**，主攻三个方向：**系统接口丰富、轻量、开箱即用**。

- **系统接口：** —— 托盘、桌面通知、全局快捷键、开机自启、剪贴板、原生菜单、文件对话框、拖放、空闲检测、媒体控制，以及壁纸 / 音量 / 电源 / 打印机 / 显示器 / 浏览器历史 / 已装应用等系统查询
- **轻量：** —— 渲染、布局、控件均为纯 MoonBit 自绘（软件光栅器），不依赖 Skia 等外部图形引擎；`hello` 最小窗口的 release 二进制 **1.1 MB**、冷启动约 0.5 s 出窗，`showcase` 15 页全功能板 5.5 MB / 约 1 s（Linux 实测）；音视频引擎等重能力拆独立模块
- **开箱即用：** —— `moon add` 后零配置直接 `moon run`；组件库、14 种图表 + 交互层、Markdown 视图、内嵌 WebView 都是库内成品

平台状态：**🟩 Windows / 🟩 Linux / 🟨 macOS ** 
 - 🟨 待真机测试（后端已在 `mac` 分支落地，CI 三平台全绿）
 - 🟩 已真机测试

## 与既有 GUI 能力的边界

与 MoUI（wzzc-dev/moui）、Sun（wzzc-dev/sun）**零代码依赖**：本库直接依赖只有 MoonBit 标准库与操作系统组件（GTK / Win32 / Cocoa / Pango / DirectWrite / CoreText）。定位互补：MoUI 面向多端共享逻辑（Skia / WebGPU 渲染），Sun 是图形文本渲染底层，native-gui 专注桌面线——生态内此前没有以桌面系统集成为主线的 MoonBit GUI 库，此为独立重建的立足点。

## 差异化用户收益：同一界面的操作案例

**场景**：一个音乐播放器。窗口本身（列表 / 按钮 / 进度条）任何 GUI 库都画得出来；差别在**窗口之外**。

用 native-gui，以下行为全部是库内置 API（Windows / Linux / macOS 同一套代码）：

```moonbit
// 关窗后驻留系统托盘：Linux SNI / macOS NSStatusItem / Windows Shell_NotifyIcon
let ic = @win.icon_from_bgra(icon_pixels, 32, 32)
match @core.Tray::new("my-player", icon=ic) {
  Ok(tray) => {
    tray.set_tooltip("MyPlayer", "后台播放中")
    tray.on_click(fn() { main_window.show() })
  }
  Err(e) => show_reason(e) // 结构化错误：无后端 / 图标失败，不静默
}

// 桌面通知带进度：freedesktop Notifications / Windows 气泡 / macOS 用户通知
@core.notify_send("MyPlayer", "正在下载", "专辑封面 3/10", progress=30)

// 开机自启：XDG autostart / Windows 注册表 Run 键 / macOS LaunchAgents
@sys.autostart_enable("com.example.my-player")
```

操作走查：点关闭 → 图标驻留托盘，左键点回主窗口；切去别的应用 → 桌面通知汇报后台进度；重启系统 → 应用自动拉起。走的是真实桌面协议（SNI / freedesktop Notifications / XDG autostart），Linux 上还可经 D-Bus 枚举与控制 MPRIS 播放器。

这些能力在库内是同构门面：能力探测（`notify_supported()` / `Tray::is_supported()` 等）+ 结构化错误（`Unsupported` / `Failed` 两档），调用方据此适配 UI，不静默失败。

## 10 月工作

- **macOS 平台批（`mac` 分支，①–⑰）**：Cocoa 窗口后端（事件循环 / 输入法 / 文件对话框 / 剪贴板 / 菜单 / 托盘 / 通知 / Carbon 热键）、CoreText 文字、ImageIO 图片解码、WKWebView（自定义协议 / JS 互操作 / cookie）、系统能力族（launcher / sysinfo / 音量 / 壁纸 / 自启 / 空闲 / 打印机 / 应用查找 / 显示器）、媒体线（ffmpeg + CoreAudio）；CI 三平台全绿，含真实 macOS runner 上的读数环与建窗存活冒烟
- **全面原生化**：删除 libyue 绑定包与 vendored 二进制（52 MB），框架主体纯 MoonBit 自绘，模块更名 `NoahLiu/native-gui`
- **库按功能分层**：14 个库包各自成包、按需取用；媒体引擎与 Flexbox 布局引擎拆独立模块
- **跨平台系统集成**：托盘、通知、原生菜单栏、全局快捷键（Windows / macOS 已落，Linux 的 X11 路线在近期计划）、消息框、窗口图标与运行中改标题 / 最小尺寸 / 无边框拖拽、应用内拖放、空闲检测、开机自启、任务栏进度（Windows）
- **系统能力探测页（showcase 第 15 页）**：五段只读探针（系统桌面 / 显示器窗口 / 应用文件 / 浏览器数据 / 剪贴板电源总线），每段可重新探测
- **内嵌 WebView**：与自绘控件同树混排、导航与历史、JS 互操作（执行 / 注入 / 双向绑定）、DOM 抓取、cookie 与 profile 持久化、新窗 / 权限 / 下载策略、自定义协议、崩溃回报
- **媒体引擎**：ffmpeg 解码 + miniaudio 输出、字幕双来源（外挂 / 容器内嵌）、倍速音画同步；独立音视频播放示例
- **图表扩展**：雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基 / 树 / 矩形树 / 旭日九种 + 横切交互层，并入 showcase 图表页
- **质量门禁**：`moon check` 全仓零错误零警告、`moon test` 全绿为提交门槛；CI 三平台分层门禁；平台适配坑回写 adaptation 文档（中英双语）

## 近期路线

- **macOS 并线**：真机目视复验（Retina 观感 / 输入法 / 通知 / 多屏 / launchctl）后合入主分支
- **Linux 全局快捷键**：X11 XGrabKey（libyue 有成熟先例可平移）

## 核心功能范围

- 应用与窗口（@core）
  - App 宿主与事件循环
  - 窗口挂载与访问器
  - 焦点栈 / 键盘 / 指针
  - 菜单 / 通知 / 托盘 / 热键门面 / 覆盖层
  - 拖放（会话模型）
  - Store / Signal 响应式状态
- 控件与组件库（@ui）
  - 标签 / 按钮 / 主题化变体
  - 表单：输入框 / 数值步进 / 选择 / 开关 / 日期 / 表单
  - 展示：徽标 / 统计 / 卡片 / 描述 / 空态
  - 表格三形态 / 万行虚拟滚动 / 树 / 穿梭 / 轮播
  - 导航：侧栏 / 菜单 / 原生菜单栏 / 分段 / 页签 / 面包屑 / 分页 / 步骤条
  - 滚动 / 覆盖层 / 模态消息框
  - 代码视图（三语言高亮）/ Markdown 视图
- 光栅化（@render）
  - 纯 MoonBit 软件光栅：路径 / 填充 / 混合 / 渐变
  - Cairo 后端 / 位图 / 画布 / 图片 / PNG
- 文字（@text）：字体族 / 属性文本与区间属性（Pango / DirectWrite / CoreText）
- 主题（@theme）：调色板派生 / 深浅色与强调色跟随 / 变更订阅
- 图标（@icons）：矢量图标系统
- 系统能力（@sys）
  - 自启动 / 用户空闲检测 / 子进程 / 环境变量
  - 文件 / JSON / 文件对话框 / 最近文件
  - 浏览器历史与书签 / 已装应用查找
  - 壁纸 / 音量 / 电源 / 打印机 / 显示器 / 窗口控制
- Linux 桥（@dbus，纯 MoonBit 协议栈）
  - 托盘 SNI / 通知
  - logind / upower / MPRIS 媒体 / 网络 / 屏保
- 窗口后端（@win）：平台窗口桩层——门面之下的平台实现（表面 / 图标 / IME 等），对外能力一律经跨平台门面暴露
- 图表（@chart）：折线 / 柱状 / 饼 / 仪表 / 散点 / 雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基 / 树 / 矩形树 / 旭日 + 横向交互层
- WebView（@web）
  - 布局树内嵌（pane 模型，与自绘控件同树混排）
  - 导航与历史 / 导航事件流水 / 结构化加载失败原因
  - JS 互操作：执行取回 / 脚本注入 / JS↔原生双向绑定
  - DOM 内容抓取 / Cookie 与 profile 持久化
  - 策略面：新窗 / 权限 / 下载——默认拦截并回报、可切换
  - 自定义协议本地内容通道 / 能力探测 / 崩溃回报
- 媒体（gui-media）：音频 / 视频播放器组件 / 字幕轨 / 倍速
- 布局（yoga-mbt）：纯 MoonBit Flexbox（W3C 规范逐条实现）

## 预期验收产物

- 可运行示例（`moon run` 直接启动）：
  - 基础：`hello` 最小窗口、`hello-themed` 主题控件族、`showcase` 全功能演示板（15 页，含系统能力探测页）
  - 浏览器演示：地址栏导航与历史、自定义协议本地站点、JS↔原生互操作、DOM 抓取、新窗 / 权限 / 下载策略
  - 音频 / 视频演示：播放 / 进度 / 倍速、外挂与内嵌字幕、音画同步
- CI 门禁：GitHub Actions 三平台（Linux / Windows / macOS），库包测试 / 示例构建 / release 校验分层；`moon check` 全仓零错误零警告、`moon test` 全仓用例全绿为提交门槛

## 移植或参考说明

- 参考对象：
  - Yue / libyue（<https://github.com/yue/yue>，LGPL 2.1）——本库起步于它的 MoonBit 绑定，现为独立实现，仅以之为行为参考
  - Yoga（<https://github.com/facebook/yoga>，MIT）——Flexbox 布局的规范参照，布局引擎为独立纯 MoonBit 实现
- 本项目许可证：MIT
