# moonbit-libyue [![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

> 感谢 [赵成(zcbenz)](https://github.com/zcbenz) 和他的 [Yue](https://github.com/yue/yue) 框架，以及 [MoonBit](https://github.com/moonbitlang)。很凑巧，这两个编程工具都有 “月”，现在我也很喜欢它们。 [关于我和 `libyue`](docs/zh/aboutlibyue.md)

[MoonBit](https://github.com/moonbitlang) 生态的**原生跨平台桌面 GUI 库**——对 [libyue](https://libyue.com/docs/latest/cpp/)(C++) 全量封装,一套 MoonBit 代码跑 Windows / macOS / Linux 原生窗口,`moon add` 后零配置直接运行。

简体中文 | [English](https://github.com/lb091188/moonbit-libyue/blob/master/README.md)

![组件库演示板](docs/images/showcase-basic.png)

<p align="center">
  <img src="docs/images/showcase-data.png" width="32%" alt="数据展示">
  <img src="docs/images/showcase-form.png" width="32%" alt="表单组件">
  <img src="docs/images/showcase-system.png" width="32%" alt="系统集成">
</p>

## 核心特色

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

**🖥 桌面级系统能力** —— 系统托盘（Linux 自研 DBus/SNI 直连，补齐 libyue 缺口）· 通知与通知中心 · 全局快捷键 · 剪贴板 · 原生菜单栏 · 文件对话框 · 拖放 · 多显示器：

```moonbit
let tray = @yue.Tray::new("icon.png") // Result,错误可处理
match tray {
  Ok(t) => t.on_click(fn() { window.show() })
  Err(e) => println("托盘不可用:\{e}")
}
let n = @yue.Notification::new()
n.set_title("构建完成"); n.set_body("45/45 通过"); n.show()
```

> 55 个原生控件全量封装 · 57 个主题化自绘组件 · 封装层开销实测[启动与 C++ 持平、内存 <1 MB](docs/zh/adaptation.md) · 三平台 CI · [mooncakes](https://mooncakes.io/) 已发布

## 快速开始

不会 MoonBit？有任意一门语言的编程基础就行——[五分钟上手教程](docs/zh/tutorial.md) 从 `moon new` 带到窗口跑起来：装 MoonBit 工具链与各平台系统依赖、避开三个新手坑、建出第一个桌面应用，附官方 MoonBit 教程与交互式 Tour 链接。

已经会 MoonBit？教程第 2 节从 `moon new` 到 `moon add` 引入本库，几分钟跑通。

## 文档索引

| 文档 | 内容 |
|---|---|
| [tutorial.md](docs/zh/tutorial.md) | 五分钟上手:从 `moon new` 到窗口跑起来,避开三个新手坑 |
| [declarative.md](docs/zh/declarative.md) | 声明式 `Node`/`mount` 渲染树 + `Store` 响应式绑定 |
| [layout.md](docs/zh/layout.md) | 布局样式键速查:全部样式键 + 常用组合示例 |
| [components-ui.md](docs/zh/components-ui.md) | 主题组件库速查:逐 API 签名 + 参数表,含定制主题/深浅切换 |
| [components.md](docs/zh/components.md) | 控件 API 速查:经典 setter 与 `X::make` props 两种写法 |
| [排错与专题](docs/zh/README.md) | 平台适配经验 · Linux 托盘 · 原生层重链(三篇独立文档) |

## 平台支持

Ubuntu 24.04(XFCE / GNOME / KDE) ✅ · Deepin 25 ✅ · Windows 10/11 ✅ · macOS 构建通过(CI,无真机)

Windows 下,依赖本库构建的 exe 自动为 GUI 子系统,双击无控制台黑框;`moon run` 的输出经管道捕获,照常可见。

## 开发贡献

欢迎参与：报平台兼容问题、补控件、补文档都算，尤其欢迎 macOS 真机测试（目前仅 CI 构建通过、无真机验证）。几条基本要求：

- **提交门槛**：`moon check && moon test` 全仓零错误零警告
- **经验入档**：实测踩坑连同修复写进 [adaptation.md](docs/zh/adaptation.md)，不留只在提交说明里
- **小批提交**：一个内聚改动一批提交，提交信息简短

新增控件、原生层发布等完整流程见 [AGENTS.md](AGENTS.md)。

## 参考

- [libyue 文档](https://libyue.com/docs/latest/cpp/guides/getting_started.html)

- [MoonBit 文档](https://docs.moonbitlang.cn/)
