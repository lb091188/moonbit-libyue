# NoahLiu/gui-examples

native-gui 的独立示例模块。这里的示例依赖媒体扩展等可选包，因此与主包的内置示例（`examples/`）分开维护。

## audio / video（音视频播放示例）

依赖 `gui-media` 的两个播放器组件 `audio` / `video`（ffmpeg 解码 + miniaudio 设备直出，名字对齐 HTML 的 `<audio>` / `<video>`），所以放在独立示例模块——主示例模块（`examples/`）不依赖 gui-media，`hello` 一类示例不会被 ffmpeg 链路拖累。

- **audio**：左侧播放列表（当前曲目高亮、点击换曲）+ 右侧播放器与状态区；控制条（播放/进度/音量/倍速/-5s·+5s 跳转）组件自带。载入路径：默认资产 `assets/1.mp3`（路径对工作目录稳健解析）、文件对话框选音频、目录对话框选文件夹后扫描成播放列表（无音频文件给空态）。
- **video**：视频区为主 + 侧栏播放列表/信息；字幕双来源——容器内嵌轨自动读取，或「选外挂 .srt」读文本传入（`on_subtitle` 回报来源与条数，可清除回内嵌轨）。载入路径与 audio 同三条，默认资产 `assets/1.mp4`。

```sh
# 仓库根（workspace 模式）
cd modules/gui-examples && moon run audio
cd modules/gui-examples && moon run video
```

依赖：[native-gui](https://mooncakes.io/docs/NoahLiu/native-gui)、[gui-media](https://mooncakes.io/docs/NoahLiu/gui-media)、[ffmpeg-mbt](https://mooncakes.io/docs/NoahLiu/ffmpeg-mbt)。

### Windows 运行前置：ffmpeg 运行期 dll（**不满足则进程起不来**）

`ffmpeg-mbt` 的 C 桩是**真绑定**（三平台同源、无平台条件编译，见该模块 `src/ffmpeg_stub.c` 文件头），Windows 侧由 `prebuild.py` 用 `vendor/*.lib`（BtbN win64-lgpl-shared 导入库）链接。导入库进链接意味着**生成的 exe 在加载期硬依赖下列 5 个 dll**：

`avcodec-63.dll` / `avformat-63.dll` / `avutil-61.dll` / `swscale-10.dll` / `swresample-7.dll`

（另 `avdevice-63.dll` / `avfilter-12.dll` 与 vendor 同版本配套，README 口径列全 7 个。）

**缺 dll 时的表现不是「示例内报错」，而是进程根本启动不了**：Windows 加载器在 `main` 之前就拒绝加载，窗口从不出现，控制台一闪就退（Git Bash 下退出码 127，无任何输出）。audio 与 video 两个示例在同一个模块里，都吃这条前置。

把 dll 放到 **exe 同目录**或**加进 PATH** 即可（大版本须与 `vendor/` 导入库一致，取自同一份 BtbN/gyan win64-lgpl-shared 构建的 `bin/`）。

**怎么取（Windows 惯例 + 本仓的最短路径）**：

- Windows 没有 unix 那种「装一个 dev 包就全局可见」的机制，惯例是 **app-local 部署**——把依赖 dll 与 exe 放同一目录（加载器第一顺位就找 exe 所在目录），发布时随包带出去。放 PATH 只适合开发机；静态链接则与 `vendor/*.lib`（导入库）不兼容，且 LGPL 静态链接还要额外满足「可重链接」义务，本仓不走这条。winget/scoop/choco 这类包管理器只是把文件放到某处，**并不能让 dll 被找到**，仍要 app-local 或 PATH。
- **本仓最短路径**：winget 有与 `vendor/` **同源**的包 —— `BtbN.FFmpeg.LGPL.Shared.9.0`（BtbN / LGPL / **shared** / 9.0 分支，与 vendor 导入库出处一致）。装完 dll 落在该包目录的 `bin/`；winget 的 portable 包通常会把该 `bin` 加进 PATH，用 `where avcodec-63.dll` 确认，没有就手工把该目录加进 PATH。
- ⚠️ **别拿 `Gyan.FFmpeg` 当来源**：那是**静态**构建（`bin/` 只有 ffmpeg/ffplay/ffprobe 三个 exe、每个约 228MB，整个包目录零 dll）——静态 exe 把 ffmpeg 编进去了，不可能把库借给别的进程。同理 BtbN 的 `*.GPL`（static）分支也不行，要 `Shared`。

Linux 侧需系统 ffmpeg 开发包（`libav*-dev`，`pkg-config` 探测）。
