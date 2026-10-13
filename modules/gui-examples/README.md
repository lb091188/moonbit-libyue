# NoahLiu/gui-examples

native-gui 的独立示例模块。这里的示例依赖媒体扩展等可选包，因此与主包的内置示例（`examples/`）分开维护。

## systemprobe

系统能力 + 扩展图表演示板（2026-10-13 起为 native-gui 新栈版，装配方式与 `examples/showcase` 同构）。侧栏三组七页：

- **能力**：系统能力（音量/亮度/浏览器历史与下载/VS Code/应用查找/默认应用/显示器/窗口/剪贴板/电源计划/系统信息/打印机/环境变量/书签/Firefox/最近文件 + MPRIS 媒体，真读本机）、命令与状态（设置类命令只展示文本，只读状态真实读取）
- **媒体**：视频播放 / 音频播放（gui-media `player_t` 音视频一体播放器组件；演示媒体由 ffmpeg lavfi 现场生成，本地文件走文件对话框）
- **图表**：扩展图表（雷达/热力/K 线/漏斗/箱线/桑基）、新图表（关系图/平行坐标/象形柱/旭日/主题河流/树图/矩形树图/特效散点）、交互图表（line/bar 缩放平移 + donut）

```sh
# 仓库根（workspace 模式）
cd modules/gui-examples && moon run systemprobe
```

依赖：[native-gui](https://mooncakes.io/docs/NoahLiu/native-gui)、[gui-media](https://mooncakes.io/docs/NoahLiu/gui-media)、[ffmpeg-mbt](https://mooncakes.io/docs/NoahLiu/ffmpeg-mbt)。

### Windows 运行前置：ffmpeg 运行期 dll（**不满足则进程起不来**）

`ffmpeg-mbt` 的 C 桩是**真绑定**（三平台同源、无平台条件编译，见该模块 `src/ffmpeg_stub.c` 文件头），Windows 侧由 `prebuild.py` 用 `vendor/*.lib`（BtbN win64-lgpl-shared 导入库）链接。导入库进链接意味着**生成的 exe 在加载期硬依赖下列 5 个 dll**：

`avcodec-63.dll` / `avformat-63.dll` / `avutil-61.dll` / `swscale-10.dll` / `swresample-7.dll`

（另 `avdevice-63.dll` / `avfilter-12.dll` 与 vendor 同版本配套，README 口径列全 7 个。）

**缺 dll 时的表现不是「媒体页报错」，而是进程根本启动不了**：Windows 加载器在 `main` 之前就拒绝加载，窗口从不出现，控制台一闪就退（Git Bash 下退出码 127，无任何输出）。探针页、图表页同样起不来——它们和媒体页在同一个 exe 里。

把 dll 放到 **exe 同目录**或**加进 PATH** 即可（大版本须与 `vendor/` 导入库一致，取自同一份 BtbN/gyan win64-lgpl-shared 构建的 `bin/`）。注意 Gyan 的 `-full_build` 是**静态**构建，`bin/` 里只有 exe、没有 dll，不能拿它当来源。

Linux 侧需系统 ffmpeg 开发包（`libav*-dev`，`pkg-config` 探测）。
