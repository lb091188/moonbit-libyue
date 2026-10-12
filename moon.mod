name = "NoahLiu/native-gui"

version = "0.6.0"

preferred_target = "native"

description = "MoonBit 原生跨平台桌面 GUI 库：自绘控件 + 自定义主题，一份代码原生运行于 Windows / Linux / macOS"

readme = "README.md"

keywords = [ "gui", "desktop", "native", "cross-platform", "moonbit" ]

license = "MIT"

repository = "https://github.com/lb091188/moonbit-libyue"

import {
  "NoahLiu/yoga-mbt@0.1.0",
  "chensuiyi/subproc@0.3.0",
  "prowk/moonsqlitefile@0.8.0",
  "mizchi/markdown@0.8.3",
}

options(
  homepage: "https://github.com/lb091188/moonbit-libyue",
  "--moonbit-unstable-prebuild": "scripts/prebuild.py",
)
