# moonbit-libyue [![CI](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml/badge.svg)](https://github.com/lb091188/moonbit-libyue/actions/workflows/ci.yml)

> 感谢 [赵成(zcbenz)](https://github.com/zcbenz) 和他的 [Yue](https://github.com/yue/yue) 框架，以及 [MoonBit](https://github.com/moonbitlang)。
>
> 很凑巧，这两个编程工具都有 “月”，现在我也很喜欢它们。 [关于我和 `libyue`](docs/zh/aboutlibyue.md)

[MoonBit](https://github.com/moonbitlang) 生态的**原生跨平台桌面 GUI 库**——对 [libyue](https://libyue.com/docs/latest/cpp/)(C++) 全量封装,一套 MoonBit 代码跑 Windows ✅ / Linux ✅ / macOS 🟡 原生窗口,`moon add` 后零配置直接运行。

📚 **在线文档**:<https://moonbit-libyue.pages.dev/zh/> —— 本仓各文档的网页版,随仓库自动部署;English: <https://moonbit-libyue.pages.dev/>。

简体中文 | [English](https://github.com/lb091188/moonbit-libyue/blob/master/README.md)

![组件库演示板](https://cdn.jsdelivr.net/gh/lb091188/moonbit-libyue@master/docs/public/images/showcase-main.png)

![Linux(XFCE)实机演示](https://cdn.jsdelivr.net/gh/lb091188/moonbit-libyue@master/docs/public/images/showcase-anim-linux.webp) ![Windows 实机演示](https://cdn.jsdelivr.net/gh/lb091188/moonbit-libyue@master/docs/public/images/showcase-anim-windows.webp)

*图二 Linux(XFCE) · 图三:Windows —— 同一套 MoonBit 代码*

## 核心特色

**🎨 现代主题** —— 跨平台视觉一致；默认整套跟随系统主色强调色、明暗模式，`theme_apply` 一行换肤：

```moonbit
@yue.theme_apply({ ..@yue.theme_from_system(), primary: "#1E4FA3" })
```

**📝 声明式** —— 节点树描述界面：

```moonbit
let window = @declarative.mount_window(
  [
    @declarative.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
    @declarative.button("退出", on_click=fn() { @yue.quit() }),
  ],
  title="Hello", size=Some((420.0, 160.0)), center=true, on_close=fn(_w) { @yue.quit() },
)
```

**⚡ 信号响应式** —— 状态放 `Signal` / `Store`，绑定处自动刷新：

```moonbit
let clicks = @yue.Signal::new(0)
let text = @yue.Signal::computed(fn() { "已点 \{clicks.get()} 次" })  // 依赖自动收集

@declarative.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
@declarative.bind(text, fn(s) { s }),
```

**🖥 桌面级系统能力** —— 三类原生能力开箱即用,无外部依赖:托盘与通知、全局快捷键(后台常驻);原生菜单栏、文件对话框、多显示器(窗口集成);剪贴板、拖放(数据交换)。

```moonbit
match @yue.Tray::new("icon.png") {
  Ok(t) => t.on_click(fn() { window.show() })
  Err(_e) => ()
}

let n = @yue.Notification::new()
n.set_title("构建完成")
n.show()
```

**📊 旗舰应用 — Linux 进程管理与硬件信息查看**：

![进程](https://cdn.jsdelivr.net/gh/lb091188/moonbit-libyue@master/docs/public/images/sys.png)

```moonbit
moon run examples/sysmonitor
```

> **规模与开销**:40 个原生控件全量封装 · 58 个主题化自绘组件 · 20 个自绘图表(另 3 个交互变体);封装开销[启动持平 C++、内存 +0.8MB](docs/zh/adaptation.md);三平台 CI,[mooncakes](https://mooncakes.io/) 已发布。

## 快速开始

不会 MoonBit？[五分钟上手教程](docs/zh/tutorial.md) 从 `moon new` 带到第一个窗口。

前置要求:MoonBit native 工具链,`moonc` ≥ 0.10.14(`moon version --all` 可验证)。

**预构建演示包**——解压即跑

| 平台 | 下载 |
|---|---|
| Windows 10/11 x64 | [`bin-windows-x64.zip`](https://github.com/lb091188/moonbit-libyue/releases/latest/download/bin-windows-x64.zip) |
| Linux x64(需 GTK3,Ubuntu 自带) | [`bin-linux-x64.zip`](https://github.com/lb091188/moonbit-libyue/releases/latest/download/bin-linux-x64.zip) |
| macOS(Apple Silicon) 🟡 未真机验证 | [`bin-macos-arm64.zip`](https://github.com/lb091188/moonbit-libyue/releases/latest/download/bin-macos-arm64.zip) |

> **0.5.11 起模块拆成多个子包**:`moon add` 仍一次拿全,但只有你 import 的包进二进制(MoonBit 按 import 闭包构建)。

> 核心 `.../yue`(`@yue`):原生控件、绘制、`Store`/`Signal`、主题、托盘;按需引入 `declarative`(声明式渲染树)、`components`(主题组件)、`charts`(图表)、`icons`(图标)、`markdown`(渲染)、`system`(系统能力)。完整表见 [docs/zh/README.md](docs/zh/README.md#包结构)。

> **升级到 0.5.0**：`Browser` 绑定拆分为独立包,import 路径改为 `NoahLiu/moonbit-libyue/yue/browser`(`@browser.Browser` → `@browser.Browser`,API 不变)。未 import 该包的程序不再链接 WebKit/WebView2 依赖。

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

Ubuntu 24.04(XFCE / GNOME / KDE) ✅ · Deepin 23 / 25 ✅ · Windows 10/11 ✅ · macOS 🟡 构建通过(CI,无真机)

Windows 下 exe 自动为 GUI 子系统,双击无控制台黑框。

## 开发贡献

欢迎参与：报平台兼容问题、补控件、补文档都算，尤其欢迎 macOS 真机测试。几条基本要求：

- **提交门槛**：`moon check && moon test` 全仓零错误零警告
- **经验入档**：实测踩坑连同修复写进 [adaptation.md](docs/zh/adaptation.md)，不留只在提交说明里
- **小批提交**：一个内聚改动一批提交，提交信息简短

新增控件、原生层发布等完整流程见 [AGENTS.md](AGENTS.md)。

## 许可证

- `moonbit-libyue` 以 [MIT](LICENSE) 发布。
- 封装的 [libyue](https://github.com/yue/libyue) 上游为 LGPL-2.1,并捆绑 Apache-2.0 / MIT / BSD-3-Clause 三方组件;完整许可文本随包分发于 [`vendor/libyue/LICENSE`](vendor/libyue/LICENSE)。
- 本仓库用到的全部 libyue 补丁以独立提交维护于 fork [lb091188/yue](https://github.com/lb091188/yue);随包分发的预构建静态库由 GitHub Actions 从 fork 的 `vendor-*` 标签源码构建,对应源码始终可从仓库标签取回。

## 参考

- [libyue 文档](https://libyue.com/docs/latest/cpp/guides/getting_started.html)

- [MoonBit 文档](https://docs.moonbitlang.cn/)
