# 路线图

状态:`[x]` 完成 · `[~]` 部分(括号内是缺口) · `[ ]` 未开始;做完勾掉并注明验证方式。

## 遗留

- [~] 通知回调 — reply(OS_MAC)留平台目标
- [~] 缓办 — Display 全字段枚举、mac 专属(Accelerator 类 / Tray 原生后端等)
- 平台
  - macOS 暂缓(无设备)
  - Windows 富文本 / markdown 观感待真机复验

## Chart 图表组件

- [ ] C1 line_chart_t 折线 / 面积图
  - 功能:定长滚动窗口(max_points,超出丢最旧);面积半透明填充可选;多序列 ≤4(主题色系)
  - 坐标:y 轴自适应(窗口 min/max + 留白)或手动范围;横向网格;最新值右端标注
  - 验收:1000 点 × 4 序列 2Hz 推点单帧重绘 <5ms(仅画布重绘,不重建视图树);10Hz 无闪烁;连续推点 10 分钟内存增量 <5MB
- [ ] C2 bar_chart_t 柱状 / 条形图
  - 功能:纵向柱与横向条两形态;正负值基线;hover 高亮 + 行内数值标注(Painter 自绘,不走弹层)
  - 验收:200 类目全量重绘 <3ms;hover 移动只重绘画布
- [ ] C3 donut_chart_t 环形 / 饼图
  - 功能:占比扇区;中心汇总数值;图例;hover 扇区外扩
  - 验收:50 扇区重绘 <3ms
- [ ] C4 gauge_t 仪表盘
  - 功能:单值百分比环 + 中心大数字;阈值分段着色;数值插值平滑(非动画帧驱动)
  - 验收:2Hz 更新无跳变
- [ ] C5 scatter_t 散点图
  - 功能:x/y 点列;最小二乘趋势线可选;框选缩放(后置)
  - 验收:10000 点首绘 <30ms;缩放重绘 <10ms
- [ ] C6 测试
  - 白盒:数据窗口 / 坐标换算 / 刻度算法纯函数测试
  - 基准:重绘耗时用例(release 计时);高频推点长跑内存平稳
  - 数据入 adaptation.md
- [ ] C7 演示与文档
  - showcase「数据展示」页:各图型一屏 + set_timer 模拟数据的实时曲线
  - components-ui 中英文档(签名 + 参数表)
  - 真机视觉复验(用户执行)

## Ubuntu 进程管理与硬件信息查看

- 定位:库的「表现力 + 性能」展示窗口,README 挂截图
- 数据层纯 MoonBit 读 /proc、/sys;刷新走 set_timer;系统调用经应用自有 native-stub(不进 yue)

### 数据层

- [ ] S0 文本读取入口
  - 应用 native-stub 提供 read_text_file;数据层统一使用
- [ ] S1 CPU
  - /proc/stat:总体 + 各核两次采样差值算占用率
  - /proc/cpuinfo:型号 / 核数 / 频率
- [ ] S2 内存 — /proc/meminfo:总 / 已用 / 可用 / swap
- [ ] S3 进程
  - /proc/[pid]/{stat,status,cmdline}:命令 / 状态(R,S,D,Z) / CPU%(差值采样) / MEM(rss)
  - ppid 构树备用
- [ ] S4 温度 — /sys/class/hwmon/hwmon*/(name + temp*_input/label,毫摄氏度换算)
- [ ] S5 磁盘
  - /proc/diskstats:IO 速率
  - statvfs(应用 native-stub 提供):容量
- [ ] S6 GPU
  - sysfs 枚举显卡(/sys/bus/pci/devices 的 class=Display + vendor/device);温度走 hwmon
  - NVIDIA 利用率走 nvidia-smi 子进程(后置)
- [ ] S7 网络 — /sys/class/net/*/statistics 的 rx/tx 速率

### 应用自有 native-stub(examples/sysmonitor/stub/)

监控应用的领域需求不是框架公共能力,经 moon.pkg 的 native-stub 编入应用包;符号全在 libc 默认链接,零 shim/fork/vendored/链接参数改动。

- [ ] F1 进程管理 — kill(pid, sig) / getpriority / setpriority;errno → Result 语义化
- [ ] F2 statvfs(path) — 磁盘容量;C 侧拆结构体为扁平出参
- [ ] F3 (后置)子进程执行 — spawn + 捕获 stdout 返回字符串(nvidia-smi 等)

### UI 与集成

- [ ] U1 骨架 — tabs_t 五页:概览 / 进程 / 传感器(温度+GPU) / 磁盘 / 网络;主题深浅自动跟随
- [ ] U2 概览页 — CPU 总占用 + 各核、内存、swap 实时曲线(line_chart_t)+ 关键数值卡片
- [ ] U3 进程页 — table_v_t 虚拟表格(千行级)
  - 搜索过滤;列头点排序;选中 kill(SIGTERM,失败 SIGKILL)/ renice
  - 1Hz 增量刷新
- [ ] U4 其余页
  - 传感器:温度列表 + 迷你曲线
  - 磁盘:容量条 + IO 曲线
  - 网络:网卡 rx/tx 曲线
- [ ] U5 性能实测 — 千行进程页 1Hz/2Hz 刷新的帧率与内存占用,延续 vs C++ 基线口径入 adaptation.md
- [ ] U6 文档发布 — README 中英挂旗舰示例与截图;踩坑回写 adaptation.md;mooncakes 发新版

### 边界

- 仅测试 Ubuntu 24.04:GNOME、XFCE、KDE 桌面环境
- systemd 服务管理、连接级网络监控(只做网卡速率)
- NVIDIA 之外 GPU 的专有利用率指标(温度走 hwmon 为准)

## 系统集成扩容(Electron 对标,Linux + Windows)

桌面应用通用能力,属框架「系统集成」域(与托盘 / 通知同域),区别于 sysmonitor 的应用领域需求;macOS 暂缓。落地路由按平台:Linux = 纯 MoonBit / DBus(traybus 基建复用) / shim;Windows = 一律 shim(Win32 API)。语义归一在 MoonBit 层,使用方零平台感知。

- [ ] P1 request_single_instance(name : String) -> Bool — 防多开
  - Linux:DBus claim 总线名 org.app.<name>,claim 失败即已有实例
  - Windows:CreateMutexW 命名互斥体,ERROR_ALREADY_EXISTS 即已有实例
  - 验收:双开第二实例返回 false;XFCE / GNOME / KDE 与 Win10 / 11 真机
- [ ] P2 on_second_instance(callback) — 二次启动唤起已有窗口
  - Linux:DBus——第二实例向总线名发 method_call,首实例回调并前置窗口
  - Windows:FindWindow + SetForegroundWindow;参数透传走 WM_COPYDATA(后置)
  - 验收:双开后首实例窗口置前
- [ ] P3 get_autostart() -> Bool / set_autostart(enable : Bool)
  - Linux:读写 ~/.config/autostart/<app>.desktop(XDG 规范,纯 MoonBit);坑:/proc/self/exe 是符号链接,readlink 需应用侧 stub,路径含空格的 .desktop 转义
  - Windows:注册表 HKCU\Software\Microsoft\Windows\CurrentVersion\Run 写值(通知 AUMID 已有 HKCU 写入先例);exe 路径 GetModuleFileNameW
  - 验收:设置后重新登录 / 重启拉起,取消后不拉起
- [ ] P4 on_suspend / on_resume — 挂起与唤醒
  - Linux:DBus logind——org.freedesktop.login1.Manager 的 PrepareForSleep(Boolean)
  - Windows:WM_POWERBROADCAST(PBT_APMSUSPEND / PBT_APMRESUMEAUTOMATIC,窗口过程 hook)
  - 验收:dbus-monitor 对照;真机休眠 / 唤醒各触发一次
- [ ] P5 on_lock_screen / on_unlock_screen — 锁屏与解锁
  - Linux:DBus logind——Session 的 Lock / Unlock 信号
  - Windows:WTSRegisterSessionNotification(WM_WTSSESSION_CHANGE 的 WTS_SESSION_LOCK / UNLOCK)
  - 验收:真机锁屏 / 解锁触发
- [ ] P6 get_idle_time() -> Double — 用户空闲秒数
  - Linux:shim ABI——X11 ScreenSaver 扩展 XScreenSaverQueryInfo;Wayland 后置
  - Windows:shim ABI——GetLastInputInfo(结构更简单)
  - 注:active / idle 阈值判定由调用方比较,不设单独 API
  - 验收:与 xset q / 手表计时对照(±2s)
- [ ] P7 open_url(url : String) — 默认浏览器打开
  - Linux:shim spawn xdg-open
  - Windows:shim ShellExecuteW
  - 验收:双平台真机开默认浏览器
- [ ] P8 show_in_folder(path : String) — 文件管理器打开并选中
  - Linux:DBus org.freedesktop.FileManager1 的 ShowItems;无服务时回退 xdg-open 目录
  - Windows:explorer.exe /select,<path>(经 ShellExecuteW)
  - 验收:双平台打开文件管理器并选中;差异记 adaptation.md
- [ ] P9 set_keep_awake(enable : Bool) — 屏幕常亮
  - Linux:DBus org.freedesktop.ScreenSaver 的 Inhibit / UnInhibit(Inhibit 返回 cookie,解除须带原值)
  - Windows:SetThreadExecutionState(启用 ES_CONTINUOUS | ES_DISPLAY_REQUIRED,解除还原 ES_CONTINUOUS)
  - 验收:启用后到达息屏时间不熄屏,禁用恢复
- [ ] P10 get_battery() -> BatteryInfo? — 电量(percent + charging;无电池返回 None)
  - Linux:DBus UPower——devices/battery_BAT0 的 Percentage / State 属性
  - Windows:GetSystemPowerStatus(ACLineStatus / BatteryLifePercent;BATTERY_FLAG_NO_BATTERY 判无电池)
  - 验收:与 upower -i / 系统托盘电量对照;台式机返回 None
- [ ] P11 on_power_source(callback : Bool) — 交流 / 电池切换
  - Linux:DBus UPower 的 PropertiesChanged(OnBattery 属性)
  - Windows:WM_POWERBROADCAST + RegisterPowerSettingNotification(GUID_ACDC_POWER_SOURCE)
  - 验收:拔插电源真机触发
- [ ] P12 is_online() -> Bool / on_connectivity_change(callback)
  - Linux:DBus NetworkManager——State(NM_STATE_CONNECTED_GLOBAL = 70)/ StateChanged 信号
  - Windows:IsNetworkAlive(sensapi,轮询);NLM COM 连接点监听后置
  - 验收:断网 / 联网真机触发
- [ ] P13 (后置)平台专属 — 任务栏进度(Windows ITaskbarList3)/ dock 徽标 / JumpList 最近文档
- [ ] P14 测试与文档
  - Linux 三桌面 + Windows 10/11 真机复验;DBus 互操作真总线验证
  - components.md 中英文档;showcase「系统集成」页补演示(自启动开关 / 单实例 / 打开外部)
- 批次策略:Linux DBus 套系先行(P1/P3-P5/P9-P11 复用 traybus),Windows 侧同 API 批量补 shim ABI + vendored 出包

## Markdown 能力升级(mizchi/markdown 编译器)

- [ ] M1 引入与解析切换
  - moon add mizchi/markdown(钉 0.8.3,MIT);native 后端实证可用(parse/render_html/serialize 全通)
  - markdown_view 自写解析改吃 mdast AST,顺带补 GFM 表格 / 任务列表 / 脚注
- [ ] M2 Browser 预览支线
  - render_html(remark-html 兼容)+ Browser 控件做「左编辑右预览」面板,挂 showcase「代码与文档」页
- [ ] M3 (远期)WYSIWYG 块编辑器
  - parse_incremental 增量解析 + 源码 Span 光标→块定位
  - 原生 TextEdit 行内编辑(IME 免费)+ 块结构状态机(回车拆块 / 续列表 / Tab 嵌套)
  - 前置:TextEdit 格式化 ABI(fork/shim;GTK tag / RichEdit CHARFORMAT2)
- 边界:span 为 UTF-16 索引,与 FFI 层 utf8_bytes 换算需谨慎;0.x 版本 API 有变动风险

## 已知边界(详见 docs/zh/adaptation.md)

- 原生控件不跟暗色:Table/DatePicker/Picker/ComboBox/原生 Button;RichEdit 输入框可经消息通道暗色化
- 主题库新组件一律全自绘,不再引入新的原生皮肤依赖
- 滚轮事件 Linux(GTK scroll-event)/ Windows(WM_MOUSEWHEEL 命中下发补丁)已接入;mac 的 canvas 自绘视图滚轮待补
- color_picker_t 为预设色板形态,HSL 面板未做;carousel_t 无切换动画

## 随手可查

- FFI 规范与坑清单:`.agents/skills/moonbit-c-binding/`
- 平台适配经验:`docs/adaptation.md`
- 完整 API 对照:libyue TS 声明(github.com/yue/yue releases);Lua 绑定参考(github.com/yue/yue 的 `lua_yue/`)
