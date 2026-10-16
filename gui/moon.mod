name = "NoahLiu/native-gui"

version = "0.1.1"

preferred_target = "native"

description = "MoonBit 桌面 GUI 库：丰富的桌面系统 API（托盘/通知/快捷键/自启…）+ 轻量自绘栈；Windows / Linux 原生运行，macOS 后端在 mac 分支落地中"

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
