# 文档索引

本目录是 moonbit-libyue 的使用文档。组件 API 有两种写法，语义完全一致：**逐个 setter 的经典写法**（`X::new()` + `set_xxx()`），或 **props 风格一步到位**（`X::make(...)`，只是 setter 的打包）；所有类型经 `@yue` 引用，控件 API 速查（入参 / 方法表）见 [components.md](components.md)。

| 文档 | 内容 |
|---|---|
| [tutorial.md](tutorial.md) | 五分钟上手教程(面向 MoonBit 新手):从 `moon new` 到窗口跑起来,三个新手坑逐一避开;附官方 MoonBit 教程与 Tour 链接 |
| [adaptation.md](adaptation.md) | 平台适配经验:各平台实测坑、根因与验证结论(持续更新) |
| [components.md](components.md) | 组件 API 速查:经典 setter 与 `X::make` props 两种写法,含上游坑 |
| [declarative.md](declarative.md) | 声明式 UI:`Node`/`mount` 渲染树 + `Store`/`Signal` 响应式绑定(信号 computed 自动依赖收集 + batch) |
| [components-ui.md](components-ui.md) | 组件库:Element Plus 风格主题化非表单组件(导航/数据展示/反馈),含演示截图 |
| [layout.md](layout.md) | 布局样式键全集(Yoga flexbox),含实测记录 |
| [tray.md](tray.md) | Linux 托盘方案:SNI 协议栈设计、架构、后端降级、桌面兼容性 |
| [relink.md](relink.md) | 原生层(shim/vendor)变更后强制重链:判别与处理 |

快速开始、演示与使用说明见仓库根 [README_ZH.md](../../README_ZH.md)。
