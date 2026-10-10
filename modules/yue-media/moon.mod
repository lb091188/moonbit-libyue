name = "NoahLiu/yue-media"
version = "0.1.0"
preferred_target = "native"

description = "moonbit-libyue 的媒体扩展：音视频播放器组件（基于 ffmpeg-mbt 解码 + miniaudio 播放），声明式 UI 可直接挂载"

readme = "README.md"

keywords = [ "media", "audio", "video", "player", "gui" ]

license = "MIT"

repository = "https://github.com/lb091188/moonbit-libyue"

import {
  "NoahLiu/moonbit-libyue@0.5.11",
  "NoahLiu/ffmpeg-mbt@0.1.0",
}

options(
  "--moonbit-unstable-prebuild": "prebuild.py"
)
