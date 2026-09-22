# 路线图

状态:`[x]` 完成 · `[~]` 部分(括号内是缺口) · `[ ]` 未开始;做完勾掉并注明验证方式。

## 遗留

- [~] 通知回调 — reply(OS_MAC)留平台目标
- [~] 缓办:Display 全字段枚举、mac 专属(Accelerator 类/Tray 原生后端等)
- [ ] 可关闭页签(chrome 式动态增删)— tabs_t API 形态重构(动态页数组 + Store 驱动),独立批次做
- 平台:macOS 暂缓(无设备);Windows 富文本/markdown 观感待真机复验(记录在 adaptation.md)

## Chart 图表组件(主题组件库扩容,监控应用的需求内核)

- [ ] C1 line_chart_t 折线/面积图 — 定长滚动窗口(max_points,超出丢最旧)、面积半透明填充可选、多序列(≤4,主题色系)、y 轴自适应(窗口 min/max + 留白)或手动范围、横向网格 + 最新值右端标注。验收:1000 点 × 4 序列 2Hz 推点单帧重绘 <5ms(仅画布重绘,不重建视图树)、10Hz 无闪烁、连续推点 10 分钟内存增量 <5MB
- [ ] C2 bar_chart_t 柱状/条形图 — 纵向柱与横向条两形态、类目轴/数值轴、正负值基线、hover 高亮 + 行内数值标注(Painter 自绘,不走弹层)。验收:200 类目全量重绘 <3ms,hover 移动只重绘画布
- [ ] C3 donut_chart_t 环形/饼图 — 占比扇区 + 中心汇总数值、图例、hover 扇区外扩。验收:50 扇区重绘 <3ms
- [ ] C4 gauge_t 仪表盘 — 单值百分比环 + 中心大数字、阈值分段着色、数值插值平滑(非动画帧驱动)。验收:2Hz 更新无跳变
- [ ] C5 scatter_t 散点图 — x/y 点列、最小二乘趋势线可选、框选缩放(后置)。验收:10000 点首绘 <30ms、缩放重绘 <10ms
- [ ] C6 测试 — 数据窗口/坐标换算/刻度算法纯函数白盒测试;重绘耗时基准用例(release 计时);高频推点长跑内存平稳;数据入 adaptation.md
- [ ] C7 演示与文档 — showcase「数据展示」页:各图型一屏 + set_timer 模拟数据的实时曲线;components-ui 中英文档(签名 + 参数表);真机视觉复验(用户执行)

## 旗舰应用:examples/sysmonitor(Ubuntu 进程管理与硬件信息)

定位:库的「表现力 + 性能」展示窗口,README 挂截图;数据层纯 MoonBit 读 /proc、/sys,刷新走 set_timer;shim 只补极薄系统调用。

### 数据层(纯 MoonBit,控制台输出对照 htop/free/sensors 先验证再上 UI)

- [ ] S0 文本读取入口 — yue 暴露通用 read_text_file(ffi_read_file 已有,补 pub 包装),数据层统一用它
- [ ] S1 CPU — /proc/stat 总体+各核两次采样差值算占用率;/proc/cpuinfo 型号/核数/频率
- [ ] S2 内存 — /proc/meminfo:总/已用/可用/swap
- [ ] S3 进程 — /proc/[pid]/{stat,status,cmdline}:命令/状态 R,S,D,Z/CPU%(差值采样)/MEM(rss);ppid 构树备用
- [ ] S4 温度传感器 — /sys/class/hwmon/hwmon*/(name + temp*_input/label,毫摄氏度换算)
- [ ] S5 磁盘 — /proc/diskstats IO 速率;容量走 statvfs(shim 补)
- [ ] S6 GPU — sysfs 枚举显卡(/sys/bus/pci/devices 的 class=Display + vendor/device);温度走 hwmon;NVIDIA 利用率走 nvidia-smi 子进程(后置)
- [ ] S7 网络 — /sys/class/net/*/statistics 的 rx/tx 速率

### shim 极薄补充(固定流程:shim/yue_mbt.cpp → include/yue_mbt.h → ffi.mbt extern → yue 模块)

- [ ] F1 进程管理 — kill(pid, sig) / getpriority / setpriority
- [ ] F2 statvfs(path) — 磁盘容量
- [ ] F3 (后置)子进程执行 — nvidia-smi 等外部工具调用

### UI 与集成

- [ ] U1 骨架 — tabs_t 五页:概览/进程/传感器(温度+GPU)/磁盘/网络;主题深浅自动跟随
- [ ] U2 概览页 — CPU 总占用+各核、内存、swap 实时曲线(line_chart_t)+ 关键数值卡片
- [ ] U3 进程页 — table_v_t 虚拟表格(千行级):搜索过滤/列头点排序/选中 kill(SIGTERM,失败 SIGKILL)/renice;1Hz 增量刷新
- [ ] U4 其余页 — 传感器:温度列表+迷你曲线;磁盘:容量条+IO 曲线;网络:网卡 rx/tx 曲线
- [ ] U5 性能实测 — 千行进程页 1Hz/2Hz 刷新的帧率与内存占用,延续 vs C++ 基线口径入 adaptation.md
- [ ] U6 文档发布 — README 中英挂旗舰示例与截图;踩坑回写 adaptation.md;mooncakes 发新版

### 边界(不做)

- Windows/macOS 数据层(proc/sysfs 专属;UI 层天然跨平台,数据层留接口)
- systemd 服务管理、连接级网络监控(只做网卡速率)
- NVIDIA 之外 GPU 的专有利用率指标(温度走 hwmon 为准)

## Markdown 能力升级(mizchi/markdown 编译器)

- [ ] M1 引入与解析切换 — moon add mizchi/markdown(钉 0.8.3,MIT;native 后端实证可用,parse/render_html/serialize 全通,依赖链手写 import + moon install 拉通);markdown_view 自写解析改吃 mdast AST,顺带补 GFM 表格/任务列表/脚注
- [ ] M2 Browser 预览支线 — render_html(remark-html 兼容) + Browser 控件做「左编辑右预览」面板,挂 showcase「代码与文档」页
- [ ] M3 (远期)WYSIWYG 块编辑器 — parse_incremental 增量解析 + 源码 Span 光标→块定位 + 原生 TextEdit 行内编辑(IME 免费) + 块结构状态机(回车拆块/续列表/Tab 嵌套);前置:TextEdit 格式化 ABI(fork/shim,GTK tag / RichEdit CHARFORMAT2)
- 边界:span 为 UTF-16 索引,与 FFI 层 utf8_bytes 换算需谨慎;0.x 版本 API 有变动风险

## 已知边界(详见 docs/zh/adaptation.md)

- 原生控件不跟暗色:Table/DatePicker/Picker/ComboBox/原生 Button;RichEdit 输入框可经消息通道暗色化
- 主题库新组件一律全自绘,不再引入新的原生皮肤依赖
- 滚轮事件 Linux(GTK scroll-event)/Windows(WM_MOUSEWHEEL 命中下发补丁)已接入;mac 的 canvas 自绘视图滚轮待补
- color_picker_t 为预设色板形态,HSL 面板未做;carousel_t 无切换动画

## 随手可查

- FFI 规范与坑清单:`.agents/skills/moonbit-c-binding/`
- 平台适配经验:`docs/adaptation.md`
- 完整 API 对照:libyue TS 声明(github.com/yue/yue releases);Lua 绑定参考(github.com/yue/yue 的 `lua_yue/`)
