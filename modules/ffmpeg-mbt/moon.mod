name = "NoahLiu/ffmpeg-mbt"
version = "0.1.0"
preferred_target = "native"

description = "FFmpeg 的 MoonBit 封装：音视频解码/转码/封装的进程内绑定，链接系统 ffmpeg 开发包，为 yue-media 提供媒体解码层"

readme = "README.md"

keywords = [ "ffmpeg", "audio", "video", "media", "native" ]

license = "MIT"

repository = "https://github.com/lb091188/moonbit-libyue"

options(
  "--moonbit-unstable-prebuild": "prebuild.py"
)
