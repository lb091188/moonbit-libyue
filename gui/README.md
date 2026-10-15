# native-gui

MoonBit 生态的原生跨平台桌面 GUI 库——**窗口、像素、事件循环、布局与控件全部纯 MoonBit 实现**（自绘，不依赖 libyue），一套代码在 Windows / Linux 上跑原生窗口，`moon add` 之后零配置。原名 `moonbit-libyue`（2026-10 更名），mooncakes 包名为 **`NoahLiu/native-gui`**。

本目录是**库模块**（`moon.mod` 的 name 为 `NoahLiu/native-gui`），包含全部 **14 个库包**：

`core` / `ui` / `render` / `text` / `theme` / `icons` / `sys` / `input` / `win` / `dbus` / `chart` / `mdview` / `web` / `style`

**包路径与 mooncakes 上一致**（`NoahLiu/native-gui/core` …），本目录名只是仓库内的文件系统布局，不进入包标识，因此 `moon add NoahLiu/native-gui` 的既有 import 不受影响。

![演示板](https://cdn.jsdelivr.net/gh/lb091188/moonbit-native-gui@master/docs/public/images/showcase-main.png)

## 快速开始

```sh
moon add NoahLiu/native-gui
```

```moonbit
fn main {
  let app = match @ui.mount_window(
    [@ui.text("Hello, MoonBit!", font_size=18.0)],
    title="Hello, MoonBit!",
    width=400,
    height=300,
  ) {
    None => return // 无窗口后端或无显示服务
    Some(a) => a
  }
  app.run()
}
```

自带示例（仓库内运行）：`moon run examples/hello`（最小窗口）、`moon run examples/hello-themed`（主题控件集）、`moon run examples/showcase`（全功能演示板：组件库 + 系统能力，14 页）。

## 平台支持

Ubuntu 24.04（XFCE / GNOME / KDE）✅ · Deepin 23 / 25 ✅ · Windows 10/11 ✅ · macOS 🚧 后端暂未开发。Windows 上构建出的 exe 是 GUI 子系统二进制，双击运行不弹控制台窗口。

## 文档

- 仓库根 [README](https://github.com/lb091188/moonbit-native-gui)——项目主文档（架构、包结构、平台矩阵、贡献与门禁）
- [在线文档站](https://moonbit-libyue.pages.dev/)——使用文档，中文版在 [`/zh/`](https://moonbit-libyue.pages.dev/zh/)
- [平台适配经验](https://github.com/lb091188/moonbit-native-gui/blob/master/docs/zh/adaptation.md)——各平台实测坑、根因与验证结论

MIT License。
