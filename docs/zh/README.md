# 文档索引

## 引入

本目录是 moonbit-libyue 的使用文档。所有类型经 `@yue` 引用,控件 API 速查(入参 / 方法表)见 [components.md](components.md)。

组件 API 有两种写法、语义完全一致:**逐个 setter 的经典写法**(`X::new()` + `set_xxx()`),或 **props 风格一步到位**(`X::make(...)`,只是 setter 的打包)。

完全没接触过 MoonBit？从[五分钟上手教程](tutorial.md)开始——学 MoonBit、装依赖、建出第一个桌面应用。

## 包结构

0.5.11 起模块拆成多个子包——`moon add NoahLiu/moonbit-libyue` 一次拿全，但只编译只链接你 import 的那些(MoonBit 按 import 闭包构建，没 import 的包不进二进制)：

| `moon.pkg` 里的导入 | 别名 | 内容 |
|---|---|---|
| `NoahLiu/moonbit-libyue/yue` | `@yue` | 核心：FFI、原生控件(Window / View / Label / Button / Entry / Table / Tab / Menu / 对话框…)、Painter、事件、`Store`/`Signal`、主题、托盘、文件/环境助手 |
| `.../yue/declarative` | `@declarative` | 声明式层:`Node`/`mount` 渲染树、各节点构造器、`bind_label`/`bind`、hover 组、悬浮滚动 |
| `.../yue/components` | `@components` | 主题组件库:按钮 / 输入 / 选择 / 表单 / 导航 / 布局 / 数据展示 / 反馈 / 浮层 |
| `.../yue/charts` | `@charts` | 20+ 图表类型与图表交互层 |
| `.../yue/icons` | `@icons` | 矢量图标系统(`draw_icon` 与图标视图/按钮) |
| `.../yue/markdown` | `@markdown` | `markdown_view` 渲染(该包带入 mizchi/markdown 依赖) |
| `.../yue/system` | `@system` | 系统能力:自启动 / 单实例 / 电源与会话 / 音量 / 亮度 / 媒体按键 / 壁纸 / 蓝牙 / 打印机 / 磁盘卷 / 浏览器历史…(带入 subproc / sqlite 依赖) |
| `.../yue/browser` | `@browser` | 网页视图控件——只有真需要时才 import(唯一链接 WebKit/WebView2 的包) |

教程导入的是 核心 + declarative;主题组件库及其上层按需引入。

## 演示

五个示例，由浅入深：

```sh
moon run examples/hello         # 原版控件最小窗口
moon run examples/hello-themed  # 主题组件库最小示例（theme_apply + button_t/input_t/label_t）
moon run examples/showcase      # 全功能演示板：14 页三组侧栏，组件库 + 系统能力全集
moon run examples/sysmonitor    # 旗舰应用：Ubuntu 进程管理与硬件信息查看（千行进程表 + 实时曲线）
moon run NoahLiu/yue-examples/systemprobe   # 系统能力 + 扩展图表演示板（音量/亮度/浏览器历史/VS Code/应用查找 + 雷达/热力/K 线/漏斗/箱线/桑基）
```

showcase 覆盖 14 页:基础 / 图标库 / 表单 / 导航 / 数据展示 / 图表 / 反馈 / 代码与文档 / 事件与布局 / Store 对照 / 画布与富文本 / 系统集成 / 窗口 / 浏览器。

左侧是可折叠分组菜单,底栏版本号与 `moon.mod` 同步;每页源码独立成文件(`examples/showcase/pages/*.mbt`),可直接复制取用。组件库各组件截图:

![基础组件](/images/showcase-basic.png)

![表单组件](/images/showcase-form.png)

![数据展示](/images/showcase-data.png)

![代码与文档](/images/showcase-code.png)

![系统集成](/images/showcase-system.png)

### sysmonitor：进程管理与硬件信息查看

库「表现力 + 性能」的旗舰应用,分两层:

- **数据层** —— 纯 MoonBit 读 /proc、/sys:CPU 两次差值、内存、千行进程表、hwmon 温度、磁盘 IO 与容量、PCI 显卡、网卡速率;唯一的系统调用经应用自有 native-stub。
- **视图层** —— 五页 tabs(概览 / 进程 / 传感器 / 磁盘 / 网络),1Hz 单定时器驱动全部采样;曲线与数值卡只重绘画布,不重建视图树;深浅色跟随系统。

进程页:千行级虚拟表格,搜索过滤、六列排序、选中 kill(SIGTERM 失败转 SIGKILL)/ renice,errno 语义化为中文提示。实测 1053 进程全量采样 14.94ms/次、稳态 1Hz CPU 2-3%(数据见 [adaptation.md](adaptation.md))。

![概览](/images/sysmonitor-overview.png)

![进程页](/images/sysmonitor-process.png)

![深色主题](/images/sysmonitor-dark.png)

## 分流

| 文档 | 内容 |
|---|---|
| [tutorial.md](tutorial.md) | 五分钟上手教程(面向 MoonBit 新手):从 `moon new` 到窗口跑起来,三个新手坑逐一避开;附官方 MoonBit 教程与 Tour 链接 |
| [aboutlibyue.md](aboutlibyue.md) | 关于我和 `libyue`:作者与这个库的相识经过、封装来龙去脉 |
| [declarative.md](declarative.md) | 声明式 UI(包 `@declarative`):`Node`/`mount` 渲染树 + `Store`/`Signal` 响应式绑定(信号 computed 自动依赖收集 + batch) |
| [layout.md](layout.md) | 布局样式键速查:Yoga flexbox 全部样式键(枚举/数值/边缘/特殊)+ 常用组合示例 |
| [components-ui.md](components-ui.md) | 主题组件库速查(包 `@components`):逐 API 签名 + 参数表 + 示例;12 组——按钮与文本 / 输入 / 选择 / 表单 / 导航 / 布局 / 数据展示 / 图表 / 图表交互层 / 图标 / 反馈 / 浮层,含主题定制与深浅切换 |
| [components.md](components.md) | 组件 API 速查:经典 setter 与 `X::make` props 两种写法,含上游坑 |
| [adaptation.md](adaptation.md) | 平台适配经验:各平台实测坑、根因与验证结论(持续更新) |
| [tray.md](tray.md) | Linux 托盘方案:SNI 协议栈设计、架构、后端降级、桌面兼容性 |
| [autostart.md](autostart.md) | 开机自启动:Linux 写 XDG .desktop、Windows 写 HKCU Run 键,is_enabled / enable / disable 统一语义 |
| [system-capabilities.md](system-capabilities.md) | 系统能力(包 `@system`,仅中文):26 项能力 + 2 块共享基建(procrun / traybus),按硬件显示 / 音频媒体 / 桌面外观 / 系统语言 / 文件历史分组,逐项 API 表 + 示例,统一 `Result` 语义,不支持的环境给错误值而非崩溃 |
| [plan-system-integration.md](plan-system-integration.md) | 系统集成扩容总体实施计划:P1-P12 与收口项 P14 的批次划分、验收门、共享基建决策与风险(定稿) |
| [relink.md](relink.md) | 原生层(shim/vendor)变更后强制重链:判别与处理 |

项目总览与快速开始入口见仓库根 [README_ZH.md](https://github.com/lb091188/moonbit-libyue/blob/master/README_ZH.md)。
