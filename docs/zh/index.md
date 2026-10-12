---
layout: home
hero:
  name: moonbit-libyue
  text: MoonBit 原生桌面 GUI 库
  tagline: 一份 MoonBit 代码,Windows / Linux 原生窗口——控件、布局与事件循环全部自绘。moon add 之后零配置。
  actions:
    - theme: brand
      text: 包结构
      link: /zh/README
    - theme: alt
      text: GitHub
      link: https://github.com/lb091188/moonbit-libyue
features:
  - title: 自绘控件,一套主题走全平台
    details: 窗口、像素、事件循环、布局与控件全部纯 MoonBit 实现,各平台外观一致,并跟随系统主色强调色与明暗模式。
  - title: 按需引入
    details: core / ui / render / text / theme / icons / sys / input / win / dbus / chart / mdview / web 各自独立成包,用不到的包不进二进制。
  - title: 平台差异库内消化
    details: 托盘、自启动、电源、音量、媒体按键等统一 API,Linux / Windows 差异由库吸收。
---

## 快速开始

```sh
moon add NoahLiu/native-gui
```

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.label("Hello, MoonBit!", size=18.0)],
    title="Hello, MoonBit!",
    width=400,
    height=300,
  ) {
    None => {
      // 本平台没有窗口后端或没有显示服务
      return
    }
    Some(a) => a
  }
  app.run()
}
```

`@ui.*` 来自 `NoahLiu/native-gui/ui`——完整包表见[文档索引](/zh/README)。
