# moonbit-libyue [![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

> 感谢 [赵成(zcbenz)](https://github.com/zcbenz) 和他的 [Yue](https://github.com/yue/yue) 框架，以及 [MoonBit](https://github.com/moonbitlang)。很凑巧，这两个编程工具都有 “月”，现在我也很喜欢它们。 [关于我和 `libyue`](docs/zh/aboutlibyue.md)

[libyue](https://libyue.com/docs/latest/cpp/) 的 MoonBit 封装——兼容 Windows / macOS(待测试) / Linux 原生跨平台桌面应用。

简体中文 | [English](https://github.com/lb091188/moonbit-libyue/blob/master/README.md)

![组件库演示板](docs/images/showcase-basic.png)

## 三大特色

**🎨 现代主题** —— 全部自绘、三平台视觉一致；`theme_apply` 一行换肤，深浅自动跟随系统：

```moonbit
@yue.theme_apply({ ..@yue.default_theme(), primary: "#1E4FA3" })
```

**📝 声明式** —— 节点树描述界面，不手写 `new + set_xxx`：

```moonbit
let window = @yue.mount_window(
  [
    @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
    @yue.button("退出", on_click=fn() { @yue.quit() }),
  ],
  title="Hello", size=Some((420.0, 160.0)), center=true, on_close=fn(_w) { @yue.quit() },
)
```

**⚡ 信号响应式** —— 状态放 `Signal` / `Store`，绑定处自动刷新，不写「点击后改文本」的胶水：

```moonbit
let clicks = @yue.Signal::new(0)
let text = @yue.Signal::computed(fn() { "已点 \{clicks.get()} 次" })  // 依赖自动收集

@yue.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
@yue.bind(text, fn(s) { s }),
```

## 组件用法：两种写法

每个控件都有两种用法，语义完全一致：**逐个 setter 的经典写法**（`X::new()` + `set_xxx()`），或 **props 风格一步到位**（`X::make(...)`，只是 setter 的打包）。所有类型经 `@yue` 引用，控件 API 速查（入参 / 方法表）见 [components.md](docs/zh/components.md)。

## 快速开始

> **不会 MoonBit？** 有任意一门语言的编程基础就行——[五分钟上手教程](docs/zh/tutorial.md) 从 `moon new` 带你到窗口跑起来，附官方 MoonBit 教程与交互式 Tour 链接。

本项目基于 MoonBit 语言封装 libyue，使用本库需要了解 MoonBit，并准备各个系统的 C 编译环境，并且每个系统还有不同的依赖：

- Linux 依赖 libwebkit2gtk 和 libgtk-3
- Windows 依赖 WebView2

[详细和开发使用教程](docs/zh/tutorial.md)

## 演示

```sh
moon run examples/hello         # 原版控件最小窗口
moon run examples/hello-themed  # 主题组件库最小示例(theme_apply + button_t/input_t/label_t)
moon run examples/showcase      # 全功能演示板:15 页三组侧栏,组件库 + 系统能力全集
```

showcase 覆盖：基础/图标库/表单/导航/数据展示/反馈/代码与文档/事件与布局/Store 对照 + 原生控件/画布与富文本 + 系统集成/窗口/浏览器/环境与平台，左侧分组可折叠菜单，底栏版本号与 moon.mod 同步。更多截图见 [docs/zh/components-ui.md](docs/zh/components-ui.md)。

![导航组件页](docs/images/showcase-nav.png)

## 文档索引

| 文档 | 内容 |
|---|---|
| [components-ui.md](docs/zh/components-ui.md) | 主题组件库 API 一览 + 定制主题/深浅切换 |
| [declarative.md](docs/zh/declarative.md) | 声明式 `Node`/`mount` 渲染树 + `Store` 响应式绑定 |
| [components.md](docs/zh/components.md) | 控件 API 速查:经典 setter 与 `X::make` props 两种写法 |
| [layout.md](docs/zh/layout.md) | 布局样式键全集(Yoga flexbox) |
| [adaptation.md](docs/zh/adaptation.md) | 各平台实测坑、根因与验证结论 |
| [tray.md](docs/zh/tray.md) | Linux 托盘:SNI 协议栈设计与后端降级 |
| [relink.md](docs/zh/relink.md) | 原生层变更后强制重链 |

完整索引:[docs/zh/README.md](docs/zh/README.md)。

## 平台支持

Ubuntu 24.04(XFCE / GNOME / KDE) ✅ · Deepin 25 ✅ · Windows 10/11 ✅ · macOS 构建通过(CI,无真机)

## 开发贡献

- 构建与测试:`moon check && moon test`(提交门禁:零错误零警告)
- 新增控件:`shim/yue_mbt.cpp` 机械转换 → `shim/include/yue_mbt.h` 声明 → `yue/ffi.mbt` 加 extern → 新 `yue/*.mbt` 加类型与方法(FFI 规范见 `.agents/skills/moonbit-c-binding/`)
- 实测踩坑一律回写 [docs/zh/adaptation.md](docs/zh/adaptation.md);发布二进制推 `bin-*` 标签,原生层变更推 `vendor-*` 标签

## 参考

- libyue 文档：<https://libyue.com/docs/latest/cpp/guides/getting_started.html>
- Lua 绑定参考（架构对照）：github.com/yue/yue
