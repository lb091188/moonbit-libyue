# native-gui 项目申报书（10 月）

## 基本信息

- 项目名称：native-gui
- 参赛者：刘斌（NoahLiu）
- 联系方式：<lbpeter0911@163.com>
- GitHub：<https://github.com/lb091188/moonbit-libyue>
- 项目方向：MoonBit 原生跨平台桌面 GUI 开发框架
- 是否为移植项目：否

## 项目简介

native-gui 是为 MoonBit 生态打造的**原生跨平台桌面 GUI 库**——绘制、布局、控件这套自绘核心**全部用纯 MoonBit 实现**，一套代码在 Windows ✅ / Linux ✅ 原生运行。`moon add NoahLiu/native-gui` 后零配置直接 `moon run`。项目从 Yue / libyue 的 MoonBit 绑定起步，现在以他们为老师，把框架主体用纯 MoonBit 重写——为的是把框架的开发体验做得更好。

- **全栈自绘**：观感跨平台一致、不依赖平台皮肤，深浅色与系统强调色默认跟随，主题是普通值可整体覆盖；平台与三方引擎收敛在窗口、文字、WebView、媒体几处 C 薄层，框架主体全部纯 MoonBit
- **响应式与声明式**：状态放 `Store` / `Signal`，绑定点随数据自动刷新；界面以树描述、`mount_window` 一步挂载（写法见下）
- **开箱能力齐全**：组件库、图表族、Markdown 视图、内嵌 WebView、音视频引擎与系统能力门面（托盘 / 通知 / 快捷键 / OS 查询等），全部只暴露跨平台抽象 API，能力探测 + 语义化降级
- **按需取用**：功能各自成包、不 import 不进二进制；媒体等重能力拆独立模块、不进默认依赖闭包

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

## <span style="background-color:rgb(243, 245, 247)">10 月工作</span>

- **全面原生化**：删除 libyue 绑定包、vendored libyue（52MB）与全部旧链示例，模块更名 `NoahLiu/native-gui`；布局（Flexbox）、控件、光栅化等框架主体 MoonBit 自绘，窗口与文字平台层为自写 C 桩
- **库按功能分层**：应用宿主与事件循环、控件与组件库、光栅化绘制、文字排印、主题与图标、系统能力、平台桥接、图表、Markdown 富文本视图、内嵌 WebView 各自成包、按需取用——不 import 的包不进二进制；媒体引擎、FFmpeg 解码绑定、Flexbox 布局引擎等重能力拆独立模块、不进默认依赖闭包
- **跨平台系统集成**：系统托盘、桌面通知、原生菜单栏、全局快捷键、消息框、窗口图标、运行中改标题 / 最小尺寸 / 无边框拖拽、应用内拖放、用户空闲检测、开机自启
- **内嵌 WebView**：布局树内嵌与自绘控件同树混排、导航与历史、JS 互操作（执行取回结果 / 脚本注入 / 双向绑定）、DOM 内容抓取、Cookie 与 profile 持久化、新窗 / 权限 / 下载策略（默认拦下并回报、可切换）、崩溃回报、自定义协议本地站点、能力探测与语义化降级
- **媒体引擎**：ffmpeg 解码 + miniaudio 输出、内嵌字幕轨（外挂 / 容器内嵌双来源）、倍速音画同步
- **示例迁移收口**：hello / hello-themed / showcase（14 页）/ sysmonitor / systemprobe 全部迁到新栈，使用方真机复验九条清单通过
- **质量门禁**：`moon check` 全仓零错误零警告、`moon test` 全仓用例全绿为提交门槛，CI 分层门禁（库包测试 / 示例构建 / release 校验）

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
- WebView（@web）
  - 布局树内嵌（pane 模型，与自绘控件同树混排，矩形由布局给出）
  - 导航与历史：加载 / 重载 / 后退前进 / 可退可进查询 / 标题与 URL 读数
  - 导航事件流水（消费式取）与结构化加载失败原因（域 / 错误码 / 地址）
  - JS 互操作：执行并取回结果 / 用户脚本注入 / JS↔原生双向绑定
  - DOM 内容抓取（多档快照与解析）
  - Cookie 读取与 profile 持久化档位（持久 / 随用随弃探测）
  - 策略面：新窗 / 权限 / 下载——默认拦截并回报、可切换
  - 自定义协议本地内容通道（名字先预声明、根目录挂载、注销顶替）
  - 能力探测 / web 进程崩溃回报 / 句柄存活判据
- 媒体（gui-media）：音频 / 视频播放器组件 / 字幕轨（外挂 + 容器内嵌）/ 倍速
- 布局（yoga-mbt）：纯 MoonBit Flexbox（W3C 规范逐条实现）

## 预期验收产物

- 可运行示例（`moon run` 直接启动）：
  - 基础：`hello` 最小窗口、`hello-themed` 主题控件族、`showcase` 全功能演示板（14 页）；
  - 浏览器演示：地址栏导航与历史、自定义协议本地站点、JS↔原生互操作、DOM 抓取、新窗 / 权限 / 下载策略；
  - 音频演示：播放 / 暂停 / 进度与音量、循环、倍速音画同步；
  - 视频演示：进度拖拽 seek、倍速、外挂 / 内嵌字幕轨、音画同步。
- CI 门禁：GitHub Actions 分层门禁（库包测试 / 示例构建 / release 校验），Linux + Windows 触发、结果公开可查；`moon check` 全仓零错误零警告、`moon test` 全仓用例全绿为提交门槛。

## 移植或参考说明

- 参考对象：Yue / libyue（<https://github.com/yue/yue> ，LGPL 2.1）；Yoga（<https://github.com/facebook/yoga> ，MIT）
- 本项目许可证：MIT
