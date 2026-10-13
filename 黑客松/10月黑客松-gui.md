# native-gui 项目申报书（10 月）

## 基本信息

- 项目名称：native-gui（原 moonbit-libyue 更名）
- 参赛者：刘斌（NoahLiu）
- 联系方式：<lbpeter0911@163.com>
- GitHub：<https://github.com/lb091188/moonbit-libyue>
- 项目方向：MoonBit 原生跨平台桌面 GUI 开发框架
- 是否为移植项目：否

## 项目简介

native-gui 是为 MoonBit 生态打造的**原生跨平台桌面 GUI 库**——窗口、像素、事件循环、布局与控件**全部用纯 MoonBit 自绘实现**，一套代码在 Windows ✅ / Linux ✅ 原生运行。`moon add NoahLiu/native-gui` 后零配置直接 `moon run`。

- **全栈自绘**：库自带光栅化器，控件观感跨平台一致，不依赖平台皮肤；深浅色与系统强调色默认跟随，主题是普通值可整体覆盖
- **响应式与声明式**：状态放 `Store` / `Signal`，绑定点在数据变化时自动刷新；界面以树描述、`mount_window` 一步挂载
- **13 个库包按需取用**：`core` / `ui` / `render` / `text` / `theme` / `icons` / `sys` / `input` / `win` / `dbus` / `chart` / `mdview` / `web`——不 import 的包不进二进制,不依赖的重能力模块（`gui-media、gui-markdown、gui-webview`）不进依赖闭包
- **跨平台系统能力门面**：托盘、桌面通知、全局快捷键、原生菜单、剪贴板、文件对话框、拖放、自启动、用户空闲检测，以及 OS 查询族（音量 / 亮度 / 电源 / 打印机 / 显示器 / 浏览器历史 / 已装应用 / 壁纸…）——对外只暴露跨平台抽象 API，能力探测 + 语义化降级（不支持的组合给结构化 `Unsupported`，不静默失败）；平台专属能力规划为独立能力包按需引入，不进主库门面
- **自绘图表族与富内容**：折线 / 柱状 / 饼 / 仪表 / 散点之外新增雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基 / 树 / 矩形树 / 旭日等，配横向交互层；Markdown 全量渲染视图（GFM）
- **内嵌 WebView**（Windows WebView2 / Linux WebKitGTK）与**音视频引擎**（ffmpeg 解码 + miniaudio 输出，含内嵌字幕轨、倍速音画同步）
- **平台差异收敛在两处薄层**：窗口后端（Win32 / GTK3 C 桩）与文字后端（Pango / DirectWrite）；Linux 系统能力走 DBus / SNI 协议栈，其余全部纯 MoonBit

### 写法对比

具体功能 `examples/hello`：最小窗口直接跑起来

```moonbit
// 声明式挂载：一个库调用完成窗口创建、控件挂载、事件循环启动
fn main {
  let app = match @ui.mount_window(
    [@ui.label("Hello, MoonBit!", size=18.0)],
    title="Hello, MoonBit!",
    width=400,
    height=300,
  ) {
    None => return  // 本机无窗口后端或显示服务，结构化让调用方知道
    Some(a) => a
  }
  app.run()
}
```

**响应式状态**（`examples/hello-themed`）：状态改、UI 跟——输入框直接吃 `Store`，`bind_label` 绑定文本，`count.update` 一改绑定点自动刷新：

```moonbit
let count : @core.Store[Int] = @core.Store::new(0)
@ui.mount_window([
  @ui.button("问候", on_click=fn() { count.update(fn(n) { n + 1 }) }),
  // 订阅 count：set 即自动刷新文本，"改状态"与"UI 跟随"解耦
  @ui.bind_label(count, fn(n) { "已点 \{n} 次" }),
], title="hello")
```

## 10 月开发计划

- **脱离 C++ 依赖的全面原生化**：删除 libyue 绑定包、vendored libyue（52MB）与全部旧链示例，模块更名 `NoahLiu/native-gui`（0.1.0）；窗口、事件循环、布局（Flexbox）、控件、光栅化全部 MoonBit 自绘
- **新栈 13 包定型**：库模块 `gui/` 含 core / ui / render / text / theme / icons / sys / input / win / dbus / chart / mdview / web，包路径与 mooncakes 一致；重能力拆独立模块（`gui-media` 媒体引擎、`ffmpeg-mbt` / `yoga-mbt`）
- **跨平台系统集成**：系统托盘、桌面通知、原生菜单栏、全局快捷键、消息框、窗口图标、运行中改标题 / 最小尺寸 / 无边框拖拽、应用内拖放、用户空闲检测、开机自启
- **web 包**：内嵌 WebView 与自定义协议
- **媒体引擎**：ffmpeg 解码 + miniaudio 输出，内嵌字幕轨（容器内嵌 / 外挂文本双来源、mov_text 时长谎报修正）、倍速音画同步
- **示例迁移全线收口**：hello / hello-themed / showcase（17 页：基础、表单、导航、数据展示、图表、代码与文档、画布与富文本、图标库、系统集成、窗口、事件与布局、浏览器、Store 对照等）/ sysmonitor / systemprobe 全部迁到新栈，使用方真机复验九条清单通过（2026-10-12）
- **质量门禁**：`moon check` 全仓零错误零警告（旧链 287 errors / 68 warnings 红点基线清零）、`moon test` 全仓 957/957 全绿为提交门槛，CI 重写为分层门禁（library 门禁 / 示例构建 / release 校验）

## 核心功能范围

- 应用与窗口（@core）
  - App 宿主与事件循环
  - 窗口挂载与访问器
  - 焦点栈 / 键盘 / 指针
  - 菜单 / 通知 / 托盘 / 覆盖层
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
- 文字（@text）：字体族 / 属性文本与区间属性（Pango / DirectWrite）
- 主题（@theme）：调色板派生 / 深浅色与强调色跟随 / 变更订阅
- 图标（@icons）：矢量图标系统
- 系统能力（@sys）
  - 自启动 / 用户空闲检测 / 子进程 / 环境变量
  - 文件 / JSON / 文件对话框 / 最近文件
  - 浏览器历史与书签 / 已装应用查找
  - 壁纸 / 音量 / 亮度 / 电源 / 打印机 / 显示器 / 窗口控制
- Linux 桥（@dbus，纯 MoonBit 协议栈）
  - 托盘 SNI / 通知 / 亮度
  - logind / upower / MPRIS 媒体 / 网络 / 屏保
- 窗口后端（@win）：平台窗口桩层——门面之下的平台实现（表面 / 图标 / IME 等），对外能力一律经跨平台门面暴露
- 图表（@chart）：折线 / 柱状 / 饼 / 仪表 / 散点 / 雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基 / 树 / 矩形树 / 旭日 + 横向交互层
- WebView（@web）：内嵌浏览器 / 自定义协议（预声明收口）/ 历史与导航
- 媒体（gui-media）：音频 / 视频播放器组件 / 字幕轨（外挂 + 容器内嵌）/ 倍速
- 布局（yoga-mbt）：纯 MoonBit Flexbox（W3C 规范逐条实现）

## 预期验收产物

- 可运行示例（`moon run` 直接启动）：
  - 主模块 7 个：`examples/hello` 最小窗口、`hello-themed` 主题控件族、`showcase` 全功能演示板（17 页覆盖上列组件与系统能力）、`sysmonitor` 系统监视器（进程管理 + 硬件监控）、`native-app` / `native-sys` / `native-window` 三个族级示例；
  - 独立示例模块：`systemprobe` 系统能力本机实测面板、`native-web` 内嵌 WebView 演示。
- CI 分层门禁：GitHub Actions 分层门禁（库包测试门禁 / 示例构建 / release 产物校验），Linux + Windows 触发，结果公开可查；`moon check` 全仓零错误零警告、`moon test` 957 用例全绿为提交门槛。

## 移植或参考说明

- 参考对象（设计思路与 API 形状对照）：Yue / libyue（<https://github.com/yue/yue> ，LGPL 2.1）与 Yoga（<https://github.com/facebook/yoga> ，MIT）
- 本项目许可证：MIT

本项目为独立设计与实现，**未复制参考项目源码，当前栈不依赖、不分发二者的任何代码或二进制**（vendored libyue 已删除）：

- 窗口、事件循环、Flexbox 布局、控件、光栅化器、主题系统、图表族全部为纯 MoonBit 自绘实现；布局引擎按 W3C CSS Flexbox 规范逐条实现（对照材料为规范文本）；
- Linux 系统能力基于自研纯 MoonBit DBus / SNI 协议栈实现；平台薄层为本项目自写的 Win32 / GTK3 C 桩与 Pango / DirectWrite 文字后端调用；
- 与参考项目相比的扩展：声明式 API 与响应式状态（Store / Signal）、13 包按需取用的模块化、跨平台系统集成门面（托盘 / 通知 / 快捷键 / 原生菜单 / 拖放 / 自启动等）、系统能力族（25+ 项 OS 查询）、15+ 图型自绘图表族、Markdown 视图、内嵌 WebView、音视频引擎。
