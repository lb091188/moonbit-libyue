---
layout: home
hero:
  name: moonbit-libyue
  text: libyue 的 MoonBit 封装
  tagline: 一份 MoonBit 代码,Windows / Linux / macOS 三平台原生窗口——moon add 之后零配置。
  actions:
    - theme: brand
      text: 五分钟上手教程
      link: /zh/tutorial
    - theme: alt
      text: 包结构
      link: /zh/README
features:
  - title: 原生,界面闪现
    details: libyue(C++)的完整绑定——真原生窗口与控件,二进制约 7 MB,启动约 80 ms。
  - title: 按需引入
    details: 核心、声明式、主题组件、图表、图标、markdown、系统能力各自独立成包,用不到的包不进二进制。
  - title: 平台差异库内消化
    details: 托盘、自启动、电源、音量、媒体按键等统一 API,Linux / Windows / macOS 差异由库吸收。
---

## 快速开始

```sh
moon add NoahLiu/moonbit-libyue
```

```moonbit
fn main {
  if !@yue.initialize() {
    return
  }
  let _ = @declarative.mount_window(
    [
      @declarative.label("Hello, MoonBit + libyue!"),
      @declarative.button("Quit", on_click=fn() { @yue.quit() }),
    ],
    title="Hello",
    center=true,
  )
  @yue.run()
}
```

`@declarative.*` 需要额外 import `NoahLiu/moonbit-libyue/yue/declarative`——完整包表见[文档索引](/zh/README)。
