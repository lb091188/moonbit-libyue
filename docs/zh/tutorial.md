# 五分钟上手教程

不需要会 MoonBit——有任意一门语言的编程基础即可。本教程从零建一个桌面应用:一个窗口、一个按钮、一个随点击自动刷新的计数。

## 1. 准备工具

**MoonBit 工具链**:

```sh
# Linux / macOS
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
# Windows (PowerShell)
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

<details>
<summary>Linux(Ubuntu 24.04) 环境准备</summary>

需要 build-essential(gcc / g++ / make)、CMake、pkg-config，以及 GTK3 / Pango / FontConfig / X11 / WebKit2GTK 的开发包：

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev
```

运行时若报 GTK 库缺失，多半是这份 apt 清单没装全。

</details>

<details>
<summary>Windows(10/11, x64) 环境准备</summary>

需要 Python 3、MoonBit、CMake、MSVC C++ 工具链(含 ATL)；moon 在 Windows 编译原生代码时从 PATH 找 `cl`，须在「x64 Native Tools Command Prompt for VS 2022」执行，或先 call `vcvars64.bat`：

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex            # MoonBit
winget install Kitware.CMake
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
# 补装 ATL:
Start-Process -FilePath 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe' -ArgumentList 'modify','--installPath','"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"','--add','Microsoft.VisualStudio.Component.VC.ATL','--quiet','--norestart' -Verb RunAs -Wait
```

</details>

## 2. 建工程

```sh
moon new my_app
cd my_app
moon add NoahLiu/moonbit-libyue
```

`moon new` 生成的工程需要三处手工调整:

- **`moon.mod`:把 `preferred_target = "wasm"` 改为 `"native"`** —— 本库走原生 FFI,只支持 native 后端。

- **入口文件改名:`my_app.mbt` → `main.mbt`** —— 当前版本的 moon 只把名为 `main.mbt` 的文件识别为程序入口;用模板默认文件名会报 `Missing main function`。

- ** `moon.pkg` 整个替换为**(注意这是 moon 的 DSL 格式,不是 JSON):

  ```
  import {
    "NoahLiu/moonbit-libyue/yue",
  }

  options(
    "is-main": true,
  )
  ```

  `import` 让代码里能用 `@yue.*` 访问组件库;`is-main` 声明本包是可执行入口。

## 3. 第一个窗口

把 `main.mbt` 整个替换为:

```moonbit
fn main {
  if !@yue.initialize() {
    return
  }
  let clicks = @yue.Signal::new(0)
  let _ = @yue.mount_window(
    [
      @yue.label("Hello, MoonBit + libyue!", style=[("margin", 20.0)]),
      @yue.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
      @yue.bind(clicks, fn(n) { "已点 \{n} 次" }),
      @yue.button("退出", on_click=fn() { @yue.quit() }),
    ],
    title="教程示例",
    size=Some((360.0, 220.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
  )
  @yue.run()
}
```

```sh
moon run .
```

窗口出现:一个标签、一个按钮;点按钮,中间那行「已点 N 次」自动 +1——这就是**信号响应式**:状态变化时绑定处自动刷新,不写「点击后改文本」的胶水代码。`mount_window` 接收一个节点数组,**声明式**描述界面;`label`/`button` 的样式随时可换成组件库主题件(见「下一步」)。

## 4. MoonBit 语法速览(只覆盖上面代码用到的)

| 语法 | 含义 |
|---|---|
| `fn main { ... }` | 程序入口 |
| `if !cond { return }` | 提前返回;`!` 是逻辑非 |
| `let clicks = ...` | 不可变绑定(可变用 `let mut`,本示例用不到) |
| `fn(n) { n + 1 }` | 匿名函数(lambda),作回调传入 |
| `on_click=fn() { ... }` | 命名实参:带默认值的参数按名传递 |
| `"已点 \{n} 次"` | 字符串插值,`\{表达式}` 嵌入任意值 |
| `Some((360.0, 220.0))` | 可选值的「有值」形态;对应 `None` 表示缺省 |

**系统学 MoonBit**:官方[中文教程docs](https://docs.moonbitlang.com/zh-cn/latest/tutorial/index.html)( [English tutorial](https://docs.moonbitlang.com/en/latest/tutorial/index.html));偏好交互式边玩边学的,官方 [Tour of MoonBit](https://tour.moonbitlang.com) 在浏览器里逐课演练。

## 5. 下一步

第一个应用跑起来之后，按目标选路径：

**想做得好看**——默认已整套跟随系统（深浅 + 主色），一行即可定制换肤（定制后不再随系统，联动见 `on_system_theme_change`）：

```moonbit
@yue.theme_apply({ ..@yue.theme_from_system(), primary: "#1E4FA3" })
```

改主色、圆角、暗色等定制项见 [components-ui.md](components-ui.md) 的「主题」节；把 `label`/`button` 换成组件库主题件（`label_t`/`button_t`）也在该文档。

**想照着抄**——演示板就是素材库：

```sh
git clone https://github.com/lb091188/moonbit-libyue && cd moonbit-libyue
moon run examples/showcase    # 15 页：基础/表单/导航/数据展示/反馈/事件与布局/原生控件/系统集成…
```

左边菜单选页、右边对着写，每页源码独立成文件（`examples/showcase/pages_*.mbt`)，复制改写即可。想从小例子入手：`moon run examples/hello`（原版控件）与 `moon run examples/hello-themed`（主题版）。

**想系统学**——三本文档，对应三个面：

- [declarative.md](declarative.md)：节点树（`Node`/`mount`）描述界面、`Store`/`Signal` 绑定状态——本教程第 3 节的计数点击就是它的最小形态
- [layout.md](layout.md)：样式键全集（flex/padding/margin…），`set_style` 与 `X::make` 的 style 参数吃的都是这套键
- [components.md](components.md)：全部控件的入参与方法速查，setter 与 `X::make` 两种写法都收录

**遇到问题**——[adaptation.md](adaptation.md) 按平台记满实测坑与根因；托盘方案看 [tray.md](tray.md)。

## 6. 给库贡献者的留言

这个库始于一个简单的念头（来龙去脉见 [aboutlibyue.md](aboutlibyue.md)）：用 MoonBit 写原生桌面应用。它现在覆盖 libyue C++ 文档的大部分控件，但值得做的事还很多：

- **平台兼容**：目前主力验证在 Ubuntu（XFCE/GNOME/KDE）与 Windows，macOS 只有 CI 构建、没有真机——你在 mac 上跑出的任何问题都是宝贵输入。
- **控件与能力**：libyue 文档里还没封装的条目、各平台的适配坑，都欢迎从 issue 开始讨论。
- **文档与示例**：教程、组件文档、演示板每一页的例子，都欢迎改进。

参与没有门槛：提 issue 描述问题或想法、直接提 PR 都行。开始前只需记住三条——`moon check && moon test` 零错误零警告再提交、实测踩坑连同修复写进 [adaptation.md](adaptation.md)、一个内聚改动一批提交。完整流程（新增控件的 FFI 规范、原生层发布）见仓库根 [AGENTS.md](../../AGENTS.md)。
