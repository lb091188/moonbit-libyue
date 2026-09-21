# 文档索引

## 引入

本目录是 moonbit-libyue 的使用文档。组件 API 有两种写法、语义完全一致：**逐个 setter 的经典写法**（`X::new()` + `set_xxx()`），或 **props 风格一步到位**（`X::make(...)`，只是 setter 的打包）；所有类型经 `@yue` 引用，控件 API 速查（入参 / 方法表）见 [components.md](components.md)。

完全没接触过 MoonBit？从[五分钟上手教程](tutorial.md)开始——学 MoonBit、装依赖、建出第一个桌面应用。

## 演示

三个示例，由浅入深：

```sh
moon run examples/hello         # 原版控件最小窗口
moon run examples/hello-themed  # 主题组件库最小示例（theme_apply + button_t/input_t/label_t）
moon run examples/showcase      # 全功能演示板：15 页三组侧栏，组件库 + 系统能力全集
```

showcase 覆盖：基础 / 图标库 / 表单 / 导航 / 数据展示 / 反馈 / 代码与文档 / 事件与布局 / Store 对照 + 原生控件 / 画布与富文本 + 系统集成 / 窗口 / 浏览器 / 环境与平台；左侧分组可折叠菜单，底栏版本号与 moon.mod 同步。每页源码独立成文件（`examples/showcase/pages_*.mbt`），是最好的复制粘贴素材库。更多截图见 [components-ui.md](components-ui.md)。

![导航组件页](images/showcase-nav.png)

## 分流

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

项目总览与快速开始入口见仓库根 [README_ZH.md](../../README_ZH.md)。
