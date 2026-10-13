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

依赖：[native-gui](https://mooncakes.io/docs/NoahLiu/native-gui)、[gui-media](https://mooncakes.io/docs/NoahLiu/gui-media)、[ffmpeg-mbt](https://mooncakes.io/docs/NoahLiu/ffmpeg-mbt)（Linux 需系统 ffmpeg 开发包；Windows 侧 ffmpeg 后端未接，stub 为全错误降级实现——构建可过，媒体页运行时语义化报错，探针页与图表页不受影响）。
