name = "NoahLiu/native-gui"

version = "0.1.1"

preferred_target = "native"

description = "MoonBit 轻量跨平台桌面 GUI 框架：窗口原生直连、渲染管线自绘、界面组件齐全、系统接口完备（托盘/通知/快捷键/输入法/自启…统一门面）；Windows / Linux 原生运行，macOS 后端在 mac 分支落地中"

readme = "README.md"

keywords = [ "gui", "desktop", "native", "cross-platform", "moonbit" ]

license = "MIT"

repository = "https://github.com/lb091188/moonbit-native-gui"

import {
  "NoahLiu/yoga-mbt@0.1.1",
  "prowk/moonsqlitefile@0.8.0",
  "mizchi/markdown@0.8.3",
}

options(
  homepage: "https://github.com/lb091188/moonbit-native-gui",
  "--moonbit-unstable-prebuild": "scripts/prebuild.py",
)
