# 五分钟上手教程(面向 MoonBit 新手)

不需要会 MoonBit——有任意一门语言的编程基础即可。本教程从零建一个桌面应用:一个窗口、一个按钮、一个随点击自动刷新的计数。全部步骤在 Ubuntu 24.04 + moon 0.1.20260911 实测通过。

## 1. 准备工具(一次性)

**MoonBit 工具链**(moon 是它的官方构建工具):

```sh
# Linux / macOS
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
# Windows (PowerShell)
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

**Linux 还需要 GTK 系统库**(Ubuntu 24.04 一行):

```sh
sudo apt install build-essential cmake pkg-config \
  libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev
```

Windows 的 MSVC 环境准备见仓库 README「快速开始」的折叠段。

## 2. 建工程(三个新手坑逐一避开)

```sh
moon new my_app
cd my_app
moon add NoahLiu/moonbit-libyue
```

`moon new` 生成的工程需要三处手工调整——都是实测踩过的坑:

**① `moon.mod`:把 `preferred_target = "wasm"` 改为 `"native"`**
本库走原生 FFI,只支持 native 后端;不改会在编译期报 `ffi_* is unbound`。

**② 入口文件改名:`my_app.mbt` → `main.mbt`**
当前版本的 moon 只把名为 `main.mbt` 的文件识别为程序入口;用模板默认文件名会报 `Missing main function`。

**③ `moon.pkg` 整个替换为**(注意这是 moon 的 DSL 格式,不是 JSON):

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

其余语法(match 模式匹配、结构体、trait)用到时再查,不影响跑通本教程。

**系统学 MoonBit**:官方中文教程 [docs.moonbitlang.com/zh-cn/latest/tutorial](https://docs.moonbitlang.com/zh-cn/latest/tutorial/index.html)(英文版 [tutorial](https://docs.moonbitlang.com/en/latest/tutorial/index.html));偏好交互式边玩边学的,官方 [Tour of MoonBit](https://tour.moonbitlang.com) 在浏览器里逐课演练。

## 5. 下一步

- **换肤一行**:`@yue.theme_apply({ ..@yue.default_theme(), primary: "#1E4FA3" })`,深浅跟随系统见 [components-ui.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components-ui.md) 的「定制主题」
- **组件大全**:`git clone` 本仓库后 `moon run examples/showcase`,15 页演示板对着抄;每页源码独立成文件(`examples/showcase/pages_*.mbt`),是最好的复制粘贴素材库
- **系统学习**:声明式节点与响应式绑定看 [declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md),布局样式键全集看 [layout.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/layout.md),组件 API 速查看 [components.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/components.md)

## 常见问题

| 现象 | 原因与修法 |
|---|---|
| `ffi_* is unbound` | `moon.mod` 的 `preferred_target` 没改成 `"native"` |
| `Missing main function` | 入口文件没叫 `main.mbt`,或 `moon.pkg` 少 `options("is-main": true)` |
| `Package "yue" not found` | `moon.pkg` 的 `import` 段没加 `"NoahLiu/moonbit-libyue/yue"` |
| Linux 报 GTK 库缺失 | 第 1 节的 apt 清单没装全 |
| `moon run my_app` 报找不到路径 | 根包用 `moon run .` |
| 改了代码没生效 | 原生层(shim/vendor)变更后需强制重链,见 [relink.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/relink.md) |
