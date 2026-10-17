# 五分钟上手教程

不需要会 MoonBit——有任意一门语言的编程基础即可。本教程从零建一个桌面应用：一个窗口、一个按钮、一个随点击自动刷新的计数。

## 1. 准备工具

**MoonBit 工具链**：

```sh
# Linux / macOS
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
# Windows (PowerShell)
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

<details>
<summary>Linux（Ubuntu 24.04）环境准备</summary>

本库自绘、走原生 FFI，构建只需要 C 工具链、pkg-config、Python 3 与 GTK3 / Pango / FontConfig / X11 的开发包；Python 3 用于跑库的 prebuild 脚本：

```sh
sudo apt install build-essential pkg-config python3 \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev
```

只有用到对应能力时才需要再装：内嵌 WebView（`@web`）加 `libwebkit2gtk-4.1-dev`；媒体模块（`NoahLiu/gui-media`）加 `libavformat-dev libavcodec-dev libswscale-dev libswresample-dev libavutil-dev`。运行时若报 GTK 库缺失，多半是上面这份 apt 清单没装全。

</details>

<details>
<summary>Windows（10/11，x64）环境准备</summary>

需要 Python 3 与 MSVC C++ 工具链——Python 3 跑 prebuild，工具链选 VS 2022 Build Tools 的「使用 C++ 的桌面开发」工作负载：

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex            # MoonBit
winget install Python.Python.3.12
winget install Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

moon 在 Windows 上编译原生代码**开箱即用，会自行定位 MSVC 工具链**，普通 shell（PowerShell / Git Bash）直接 `moon run` 即可，不必先进「x64 Native Tools Command Prompt」或手动 `call vcvars64.bat`。早期文档「必须在 Native Tools 命令行里跑」「还要装 CMake 与 ATL」的口径管的是旧 libyue/CMake 构建链，自绘新栈不适用。

</details>

## 2. 建工程

```sh
moon new my_app
cd my_app
moon add NoahLiu/native-gui
```

`moon new` 生成的工程需要三处手工调整：

- **`moon.mod`：把 `preferred_target = "wasm"` 改为 `"native"`**——本库走原生 FFI，只支持 native 后端；模板默认已是 native 时跳过。

- **入口文件改名：`my_app.mbt` → `main.mbt`**——当前版本的 moon 只把名为 `main.mbt` 的文件识别为程序入口；用模板默认文件名会报 `Missing main function`。

- **`moon.pkg` 整个替换为**——moon 的 DSL 格式，不是 JSON：

  ```
  import {
    "NoahLiu/native-gui/base",
    "NoahLiu/native-gui/shell",
    "NoahLiu/native-gui/widget" @widget,
    "NoahLiu/native-gui/ui",
  }

  pkgtype(kind: "executable")

  supported_targets = "native"
  ```

  `import` 让代码能访问库：`@ui.*` 提供控件、组件与声明式入口（`mount_window` 与各节点构造器），`@base.*`/`@shell.*`/`@widget.*` 提供应用宿主与响应式状态（`Store` / `Signal`）。`pkgtype(kind: "executable")` 与 `supported_targets = "native"` 声明本包是可执行入口、只出原生目标。

## 3. 第一个窗口

把 `main.mbt` 整个替换为：

```moonbit
fn main {
  let count : @base.Store[Int] = @base.Store::new(0)
  let app = match @ui.mount_window(
    [
      @ui.col(
        [
          @ui.text("Hello, MoonBit!", role=@ui.Title),
          @ui.button("点我", variant=@ui.Solid, on_click=fn() {
            count.update(fn(n) { n + 1 })
          }),
          @ui.bind_label(count, fn(n : Int) -> String { "已点 \{n} 次" }),
        ],
        padding=24.0,
        row_gap=12.0,
      ),
    ],
    title="教程示例",
    width=360,
    height=220,
  ) {
    None => {
      println("本平台没有窗口后端或没有显示服务")
      return
    }
    Some(a) => a
  }
  app.run()
}
```

```sh
moon run .
```

窗口出现：一个标题、一个按钮、一行「已点 0 次」；点按钮，数字自动 +1。这是**响应式状态**——`count` 一变，`bind_label` 自动刷新，无需「点击后改文本」的胶水代码。界面用 `@ui.col([...])` / `@ui.text(...)` / `@ui.button(...)` 等**节点构造器**声明成一棵树，交给 `mount_window` 一次挂载；`mount_window` 在没有窗口后端或没有显示服务时返回 `None`，示例据此结构化退出。

## 4. MoonBit 语法速览（只覆盖上面代码用到的）

| 语法 | 含义 |
|---|---|
| `fn main { ... }` | 程序入口 |
| `let count : @base.Store[Int] = ...` | 类型标注：`Store[Int]` 是一个整数状态盒 |
| `match expr { ... }` | 模式匹配，按分支取值（这里是拆 `Option`） |
| `None => ... / Some(a) => a` | 可选值的两态：`None` 缺省、`Some(x)` 有值 |
| `fn(n) { n + 1 }` | 匿名函数（lambda），作回调传入 |
| `on_click=fn() { ... }` | 命名实参：带默认值的参数按名传递 |
| `"已点 \{n} 次"` | 字符串插值，`\{表达式}` 嵌入任意值 |

**系统学 MoonBit**：官方[中文教程](https://docs.moonbitlang.com/zh-cn/latest/tutorial/index.html)（[English tutorial](https://docs.moonbitlang.com/en/latest/tutorial/index.html)）；偏好交互式边玩边学的，官方 [Tour of MoonBit](https://tour.moonbitlang.com) 在浏览器里逐课演练。

## 5. 下一步

第一个应用跑起来之后，按目标选路径：

**想做得好看**——默认已整套跟随系统深浅与主色，`follow_system_theme` 一行接上：

```moonbit
handle=fn(a : @widget.App) -> Unit {
  let _ = a.follow_system_theme(interval_ms=2000)
}
```

把 `@ui.text` / `@ui.button` 换成主题化形态（`button` 的 `variant` 四档、`tag` / `alert` / `card` 等）见 [components.md](components.md)；样式表（`Style` 值 + `hover` / `active` / `focus` 状态、过渡）见 [design.md](design.md)。

**想照着抄**——演示板就是素材库：

```sh
git clone https://github.com/lb091188/moonbit-native-gui && cd moonbit-native-gui
moon run examples/showcase    # 15 页：基础/表单/导航/数据展示/反馈/事件与布局/系统集成…
```

左边菜单选页、右边对着写，每页源码独立成文件（`examples/showcase/pages/*.mbt`），复制改写即可。想从小例子入手：`moon run examples/hello`（最小窗口）与 `moon run examples/hello-themed`（主题控件集）。

**想系统学**——几本文档，对应几个面：

- [declarative.md](declarative.md)：节点树（`Node` / `mount_window`）描述界面、`Store` / `Signal` 绑定状态——本教程第 3 节的计数点击就是它的最小形态
- [layout.md](layout.md)：布局样式（`Style` 的 flex / padding / margin 字段，`@ui.col` / `@ui.row` 的散参数与 `class` 通道）
- [components.md](components.md)：全部控件与组件的入参与事件速查
- [system-capabilities.md](system-capabilities.md)（中文）：系统能力（`@sys`）——音量 / 应用查找 / 壁纸 / 显示器 / 剪贴板 / 电源 / 打印机…，统一 `Result` 语义

**遇到问题**——[adaptation.md](adaptation.md) 按平台记满实测坑与根因；托盘方案看 [tray.md](tray.md)。

## 6. 给库贡献者的留言

这个库的目标是用 MoonBit 写原生桌面应用，现覆盖自绘控件、图表、Markdown、内嵌 WebView 与系统能力，值得做的事还很多：

- **平台兼容**：主力验证在 Ubuntu（XFCE/GNOME/KDE）与 Windows；macOS 后端在 `mac` 分支落地中、尚未合流 master——你在 mac 上跑出的任何问题都是宝贵输入。
- **控件与能力**：还没封装的条目、各平台的适配坑，都欢迎从 issue 开始讨论。
- **文档与示例**：教程、组件文档、演示板每一页的例子，都欢迎改进。

参与没有门槛：提 issue 描述问题或想法、直接提 PR 都行。开始前只需记住三条——`moon check` 零错误零警告、`moon test` 全绿再提交，实测踩坑连同修复写进 [adaptation.md](adaptation.md)，一个内聚改动一批提交。完整流程（新增控件的 FFI 规范、prebuild 链接托管）见仓库根 [AGENTS.md](https://github.com/lb091188/moonbit-native-gui/blob/master/AGENTS.md)。
