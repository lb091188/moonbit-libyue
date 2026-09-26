name = "NoahLiu/moonbit-libyue"

version = "0.5.1"

preferred_target = "native"

description = "libyue 的 MoonBit 封装：统一跨平台 GUI API，平台差异由库内部吸收，消费方无感"

readme = "README.md"

keywords = [ "gui", "desktop", "native", "cross-platform", "libyue" ]

license = "MIT"

repository = "https://github.com/lb091188/moonbit-libyue"

options(
  homepage: "https://github.com/lb091188/moonbit-libyue",
  "--moonbit-unstable-prebuild": "scripts/prebuild.py",
)