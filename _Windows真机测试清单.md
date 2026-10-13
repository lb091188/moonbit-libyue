# Windows 真机测试清单（本轮）

> 生成：2026-10-13 · 宿主：Windows（本机真机）
> 来源：`_人工测试清单.md`（A–R 全量）+ `TODO.md` §6.4 真机验证 + 平台批（WebView2 / ffmpeg）
> 本文件是**索引与进度表**：只回答「测什么 / 在哪测 / 优先级」；逐项操作与期望仍以 `_人工测试清单.md` 为准。
> 分工：GUI 观感与交互由你执行并回反馈；助手负责构建门禁与启动冒烟。

## 一、环境前置（已核对）

| 项 | 状态 |
|---|---|
| moon 工具链 | `moon 0.1.20260920`，`~/.moon/bin/moon` |
| MSVC | 需 `vcvars64.bat`（native-stub / `--target native` 要 `cl.exe`） |
| ffmpeg 运行库 | `C:/Users/NoahLiu/.workbuddy/binaries/ffmpeg-dll/`（avcodec-63 等 7 个 dll）——**媒体线必放 PATH 或与 exe 同目录** |
| WebView2 运行时 | 已装 `154.0.4258.62`（网页线必需） |

> **prebuild spawn 故障已结案（2026-10-13）**：助手侧 `moon build` / `moon run` / `moon test` 曾一律失败——
> moon 无法 spawn prebuild 子进程，报 `os error 231 所有的管道范例都在使用中`；**你自己的终端构建通过**，
> 故故障只存在于助手进程树内，**不影响本清单执行**（5 行最小模块同样复现、bash / PowerShell 与沙箱内外一致，
> 是环境问题而非仓库代码问题；去掉 prebuild 的模块构建正常，故障只在 prebuild-spawn 这条路径上）。
> 与 `TODO.md` §6.5 记录过的同一条现象（当时自行恢复）。`moon check` 不受影响，助手侧仍可跑。

## 二、本轮重点（尚未复验，按优先级）

| 优先级 | 范围 | 出处 | 入口命令 |
|---|---|---|---|
| **P0** | 平台批：WebView2 网页线 + ffmpeg 媒体线（Windows 首次真机） | 清单「平台批」Q1–Q9 | `moon run modules/gui-examples/native-web` |
| **P0** | W20 批观感：原生菜单栏 / 全局快捷键 / 托盘 / MessageBox / 窗口标题与图标 | TODO §6.4 | `moon run examples/native-app`；菜单栏另见 showcase P100–P105 |
| **P1** | W7 真实注入：微软拼音端到端 / 两窗遮挡拖动重绘 / 跨程序剪贴板 / 文件对话框真选文件 / 主题跟随系统 | 清单 B·C·D·E·F | `examples/native-app` + `experiment/dialog_probe` |
| **P1** | 任务栏进度（Windows 独有面，仅写不可读） | 清单 O1–O7 | `examples/native-app` |
| **P1** | 开机自启（真写注册表 `Run` 键） | 清单 M1–M7 | `moon run examples/systemprobe` |
| **P1** | 禁用态光标修复复验（禁用按钮悬停应为**普通箭头**、恢复可用立刻变手型） | 本批修复（`cursor_fn`） | `examples/native-app` / showcase 基础组件页 |
| **P2** | 用户空闲检测 | 清单 N1–N6 | `moon run examples/systemprobe` |
| **P2** | sysmonitor Windows 虚拟数据源 | 清单 R1–R12 | `moon run examples/sysmonitor` |
| **P2** | 演示板 14 页 + 菜单栏/托盘/单实例接线 | 清单 P1–P109 | `moon run examples/showcase` |
| **P2** | 系统能力探针 7 页（独立示例模块，与入口 2 同名不同物） | 清单「systemprobe」Q1–Q8 | `cd modules/gui-examples && moon run systemprobe` |

## 三、按入口分组的完整清单

### 入口 1 · `moon run examples/native-app`

| 节 | 编号 | 覆盖能力 | Windows 可测 |
|---|---|---|---|
| A | A1–A5 | 文字与字体（微软雅黑、基线、省略号、Markdown 字重、代码高亮） | ✅ |
| B | B1–B5 | 中文输入法（微软拼音：preedit 在框内、候选窗贴光标、选字落框、跨框不误 commit） | ✅ 重点 |
| C | C1–C3 | 剪贴板往返（应用 ↔ 记事本，含中文/换行） | ✅ |
| D | D1–D4 | 多窗口（独立控件树、互不串、反复开关 ≥5 次、遮挡拖动重绘） | ✅ 重点 |
| F | — | 主题跟随：设置→个性化→颜色 切浅/深 + 强调色，1 秒内换肤 | ✅ |
| G | ~140–4100px | 逐页观感：组件层/表格/虚拟表/粘性列表/分栏/卡片媒体/折线/交互图/专项图/Markdown/代码页/表单族/轮播/导航族/日历/浮层 | ✅（图片/GIF 区为空属预期） |
| H | H1–H7 | 系统托盘（建/悬停提示/右键菜单/弹菜单/左键计数/移除可重建/退出清理） | ✅ 重点 |
| I | I1–I7 | 桌面通知（信息/警告/错误图标、进度替换同一张、关闭、连发不堆叠） | ✅ |
| J | J1–J9 | 自绘消息框（自绘面板、三钮、Esc/Enter/✕、点外不收起） | ✅ |
| K | K1–K8 | 拖放（4px 阈值、落点高亮、accept 判收、松手区外不投） | ✅ 应用内 |
| O | O1–O7 | 任务栏进度（绿/红/黄/滚动/清除，看任务栏按钮） | ✅ Windows 独有 |

### 入口 2 · `moon run examples/systemprobe`（原 `native-sys`，系统能力累积验证页）

| 节 | 编号 | 覆盖能力 | 备注 |
|---|---|---|---|
| M | M1–M7 | 开机自启（写/清 `HKCU\...\Run\com.moonbit.libyue.systemprobe`，值带双引号；幂等） | 真改注册表，验完点「取消自启」 |
| N | N1–N6 | 用户空闲检测（只读不写；`supported` 恒 1；输入后归零） | — |
| — | — | 已知差异：本示例在 Windows 上会多排 `SYSPROBE-SKIP`（面板未按平台重构） | 不算 bug |

### 入口 3 · `moon run examples/showcase`

- P1–P17：骨架 + 基础组件页 + 反馈组件页（含主题切换、悬停组、光标组、轻提示、横幅、气泡、对话框）
- P18–P23：表单组件页　·　P24–P30：导航组件页　·　P31–P40：数据展示页
- P41–P46：图表页　·　P47–P49：代码与文档页　·　P50–P51：Store 对照页
- P52–P60：事件与布局页　·　P61–P65：窗口页（标题/全屏/无边框；快捷键 Ctrl+Alt+C；应用内拖放）
- P66–P76：系统集成页（文件对话框/消息框/通知/剪贴板/定时器/托盘/自启/外部/系统信息/音量）
- P77–P80：图标库页　·　P81–P88：画布与富文本页　·　P89–P99：浏览器页（WebView2 线）
- P100–P109：菜单栏 / 托盘菜单 / 单实例接线（P109 在 Windows 上应打 `SHOWCASE-INST: 单实例降级（…）` 后照常起窗）
- 已知边界：窗口页无「最大化/置顶」按钮（Win32 段未接 SC_MAXIMIZE / TOPMOST）

### 入口 4 · `moon run examples/sysmonitor`

- R1–R5：启动读数 `SYSMON-READY cores=N`、处理器卡、切卡、详情曲线、进程页（搜索/排序/结束进程）
- R6–R9：优先级（Windows 单档立即终止 + 离散优先级档）、传感器页、磁盘页、网络页
- R10–R12：深浅跟随、`SYSMON-DONE` 退出、Windows 为虚拟数据源（数值合理即可）

### 入口 5 · `cd modules/gui-examples && moon run systemprobe`（`PROBE-READY pages=7`）

> ⚠️ 本入口与入口 2 **同名不同物**：入口 2 是 `examples/systemprobe`（原 `native-sys`，系统能力累积验证页，读数前缀 `SYSPROBE-*`）；本入口是独立示例模块 `modules/gui-examples` 里的 7 页探针（读数前缀 `PROBE-*`）。回报时请写明是哪一个。

- 探针 Q1–Q8：系统能力报告 / 命令与状态 / 视频播放（需 ffmpeg）/ 选择本地视频 / 音频播放 / 扩展图表 / 新图表 / 交互图表
- 注：本文件的「Q1–Q8」与下文「平台批 Q1–Q9」在 `_人工测试清单.md` 里**同名不同源**，回报时请带前缀（`探针 Q3` / `平台批 Q5`）。

### 入口 6 · `moon run modules/gui-examples/native-web`（平台批，P0）

- 平台批 Q1–Q9：网页加载 / 自定义协议本地内容 / JS 执行与 DOM 抓取 / Cookie / 视频播放（真解码 + WASAPI 有声）/ 音频播放 / 字幕 / 长跑 5 分钟 / **焦点与滚轮转发**
- 前置：WebView2 运行时 + ffmpeg dll 进 PATH
- 回报：抄回统计行 `NATIVE-WEB-STAT/SCHEME/MEDIA/LOCAL/JS`

### 入口 7 · `moon run experiment/dialog_probe`

- E1–E5：文件对话框（过滤下拉三组、初始目录 `C:\Users`、选文件/保存默认名/文件夹选择/取消不崩）

## 四、已知不算 bug（Windows）

- 图片 / GIF 不显示（图片解码 W9，下一批）
- 整窗重绘 ~300ms/帧，滚动与点击回显有可感迟滞（性能批待排，非卡死）
- `systemprobe` 在 Windows 上多排 `SYSPROBE-SKIP`（面板未按平台重构）
- 托盘图标默认被收进任务栏「隐藏的图标」溢出区，点 `^` 展开即可
- 通知气泡驻留时长由系统「辅助功能 → 通知显示时长」定，示例无时长参数；开启勿扰/专注助手时可能只进通知中心
- 自启条目在但不执行（组策略禁用 Run 键）——库不做探测

## 五、回报格式

`编号 + 现象 + 截图（能截就截）+ 退出时对应读数行`，例如：
`D1 点开第二窗没反应；NATIVE-APP-MW wins=1 opened=0`。
通过项也请报一句「A1–A5 通过」，便于回填「已复验」。
