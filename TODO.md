# 路线图

状态:`[x]` 完成 · `[~]` 部分(括号内是缺口) · `[ ]` 未开始;做完勾掉并注明验证方式。

## 遗留

- [~] 通知回调 — reply(OS_MAC)留平台目标
- [~] 缓办 — Display 全字段枚举、mac 专属(Accelerator 类 / Tray 原生后端等)
- 平台
  - macOS 暂缓(无设备)
  - Windows 富文本 / markdown 观感待真机复验

## Chart 图表组件

- [x] C1 line_chart_t 折线 / 面积图
  - 功能:定长滚动窗口(max_points,超出丢最旧);面积半透明填充可选;多序列 ≤4(主题色系)
  - 坐标:y 轴自适应(窗口 min/max + 留白)或手动范围;横向网格;最新值右端标注
  - 验收:1000 点 × 4 序列 2Hz 推点单帧重绘 <5ms(仅画布重绘,不重建视图树);10Hz 无闪烁;连续推点 10 分钟内存增量 <5MB
  - 验证:moon test --release 全帧基准 3.08ms(对抗锯齿数据)/ 1.81ms(平滑);推点只 schedule_paint 画布;窗口长度恒定 1000(活数据 32KB 有界),长跑内存数据入 adaptation.md
- [x] C2 bar_chart_t 柱状 / 条形图
  - 功能:纵向柱与横向条两形态;正负值基线;hover 高亮 + 行内数值标注(Painter 自绘,不走弹层)
  - 验收:200 类目全量重绘 <3ms;hover 移动只重绘画布
  - 验证:release 基准 0.38ms;hover 走 on_mouse_move + schedule_paint 画布
- [x] C3 donut_chart_t 环形 / 饼图
  - 功能:占比扇区;中心汇总数值;图例;hover 扇区外扩
  - 验收:50 扇区重绘 <3ms
  - 验证:release 基准 2.88ms
- [x] C4 gauge_t 仪表盘
  - 功能:单值百分比环 + 中心大数字;阈值分段着色;数值插值平滑(非动画帧驱动)
  - 验收:2Hz 更新无跳变
  - 验证:16ms 定时器每帧补 25% 差值逼近目标(非动画帧驱动);showcase 2Hz 三角波演示,冒烟进程存活
- [x] C5 scatter_t 散点图
  - 功能:x/y 点列;最小二乘趋势线可选;框选缩放(后置)
  - 验收:10000 点首绘 <30ms;缩放重绘 <10ms
  - 验证:release 基准 3.03ms;框选缩放按计划后置未做
- [x] C6 测试
  - 白盒:数据窗口 / 坐标换算 / 刻度算法纯函数测试
  - 基准:重绘耗时用例(release 计时);高频推点长跑内存平稳
  - 数据入 adaptation.md
  - 验证:charts_wbtest.mbt 13 个语义用例 + 3 个基准用例(纯函数管线 / 离屏几何镜像 / 有显示环境真实全帧);实测数据与软光栅化坑位已入 adaptation.md 中英两份
- [x] C7 演示与文档
  - showcase 独立「图表」页(pages_charts.mbt):各图型一屏 + set_timer 模拟数据的实时曲线(可暂停推点)
  - components-ui 中英文档(签名 + 参数表)
  - 真机视觉复验(用户执行)
  - 验证:独立「图表」页五个图表面(折线 500ms 推点可暂停 / 柱状纵横 / 环形 / 仪表双演示 / 散点),启动冒烟通过;components-ui 中英文档已补(签名 + 参数表 + 示例);真机视觉复验待用户执行后更新截图

## Ubuntu 进程管理与硬件信息查看

- 定位:库的「表现力 + 性能」展示窗口,README 挂截图
- 数据层纯 MoonBit 读 /proc、/sys;刷新走 set_timer;系统调用经应用自有 native-stub(不进 yue)

### 数据层

- [x] S0 文本读取入口
  - 应用 native-stub 提供 read_text_file;数据层统一使用
  - 验证:examples/sysmonitor/stub/sysmon.c(子目录 native-stub,libc 默认链接零链接参数),/proc、/sys 尺寸为 0 走循环增量读;`-> Bytes?` 可空返回当前工具链实测可用(NULL→None,debug/release 双模式),已回写 adaptation.md
- [x] S1 CPU
  - /proc/stat:总体 + 各核两次采样差值算占用率
  - /proc/cpuinfo:型号 / 核数 / 频率
  - 验证:parse_proc_stat / cpu_usage / parse_cpuinfo 纯函数测试(列序含 guest 不重复计数、钳制、ARM 回退);真机 1Hz 采样冒烟(20 核各核占用实时刷新),截图亲验
- [x] S2 内存 — /proc/meminfo:总 / 已用 / 可用 / swap
  - 验证:parse_meminfo 测试(全字段 / MemAvailable 回退 MemFree / 缺 MemTotal 返回 None);真机读取 31.1GB 总量与 free 一致
- [x] S3 进程
  - /proc/[pid]/{stat,status,cmdline}:命令 / 状态(R,S,D,Z) / CPU%(差值采样) / MEM(rss)
  - ppid 构树备用
  - 验证:parse_proc_pid_stat / parse_cmdline / proc_cpu_pct / proc_children 纯函数测试(comm 含空格括号按最后 ')' 切、多线程钳制、ppid 构树);真实 /proc 全量采样测试通过;release 基准 580 进程 9.57ms/次,数据入 adaptation.md;RSS 取 stat 页数 × 页大小(与 VmRSS 等值)省第三次读取
- [x] S4 温度 — /sys/class/hwmon/hwmon*/(name + temp*_input/label,毫摄氏度换算)
  - 验证:parse_temp_input / temp_indices 纯函数测试(负温度、跳号编号、label 缺省回退);真机实测 coretemp 20 核 + Package、nvme 三传感器、acpitz、网卡温度全部合理
- [x] S5 磁盘
  - /proc/diskstats:IO 速率
  - statvfs(应用 native-stub 提供):容量
  - 验证:parse_mounts / parse_diskstats / byte_rate / sector_rate 测试(伪文件系统过滤、分区行、df 口径 usage);真机实测根 LVM 487GB、/boot、/boot/efi、/data 1.9TB;mapper→dm-N→slaves 反查后并发写入实测写速率 61MB/s 正确跳动
- [x] S6 GPU
  - sysfs 枚举显卡(/sys/bus/pci/devices 的 class=Display + vendor/device);温度走 hwmon
  - NVIDIA 利用率走 nvidia-smi 子进程(后置)
  - 验证:is_display_class / vendor_name 映射测试;真机实测 NVIDIA 0x2488 枚举成功,该卡无 hwmon 温度按设计显示「—」
- [x] S7 网络 — /sys/class/net/*/statistics 的 rx/tx 速率
  - 验证:真机实测 lo + 6 块网卡枚举,累计字节与差值速率正常;二次采样速率有定义

### 应用自有 native-stub(examples/sysmonitor/stub/)

监控应用的领域需求不是框架公共能力,经 moon.pkg 的 native-stub 编入应用包;符号全在 libc 默认链接,零 shim/fork/vendored/链接参数改动。

- [x] F1 进程管理 — kill(pid, sig) / getpriority / setpriority;errno → Result 语义化
  - 验证:真实调用双侧走通——signal 0 探活自身 pid 返回 Ok、pid_max+1 kill 返回 ESRCH 语义化 Err、自身 nice 读/设(10 后还原);getpriority 的 nice=-1 歧义经 Ref 出参;Windows stub 同 ABI 占位运行期降级,CI 三平台不受影响
- [x] F2 statvfs(path) — 磁盘容量;C 侧拆结构体为扁平出参
  - 验证:total/free/avail 三个 int64 出参跨 ABI;真机实测根/boot/efi/data 容量与 df 一致;f_bavail 口径(可用含保留块扣除)与 df Use% 对齐
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

- [ ] P1 防多开(单实例)
  - Linux:DBus claim 应用专属总线名,claim 失败即已有实例
  - Windows:命名互斥体,已存在标记即已有实例
  - 验收:双开第二实例立即退出;XFCE / GNOME / KDE 与 Win10 / 11 真机
- [ ] P2 二次启动唤起已有窗口
  - Linux:DBus——第二实例向应用总线名发消息,首实例回调并前置窗口
  - Windows:查找窗口 + 置前;参数透传后置
  - 验收:双开后首实例窗口置前
- [ ] P3 开机自启动(查询 / 设置 / 取消)
  - Linux:XDG 自启动目录写 .desktop 文件(纯 MoonBit);坑:exe 绝对路径经 /proc/self/exe 需 readlink(应用侧 stub),路径含空格的 .desktop 转义
  - Windows:注册表当前用户 Run 键写值(通知 AUMID 已有写注册表先例)
  - 验收:设置后重新登录 / 重启拉起,取消后不拉起
- [ ] P4 挂起与唤醒事件
  - Linux:DBus logind——PrepareForSleep 信号(参数区分将睡 / 已醒)
  - Windows:电源广播消息(挂起 / 自动恢复两事件,窗口过程 hook)
  - 验收:dbus-monitor 对照;真机休眠 / 唤醒各触发一次
- [ ] P5 锁屏与解锁事件
  - Linux:DBus logind——Session 的 Lock / Unlock 信号
  - Windows:终端服务会话变更通知(锁定 / 解锁两事件)
  - 验收:真机锁屏 / 解锁触发
- [ ] P6 获取用户空闲秒数
  - Linux:shim——X11 屏保扩展查询;Wayland 后置
  - Windows:shim——最后输入时间查询(结构更简单)
  - 边界:active / idle 阈值判定由调用方比较,不设单独接口
  - 验收:与 xset q / 手表计时对照(±2s)
- [ ] P7 默认浏览器打开 URL
  - Linux:shim spawn xdg-open
  - Windows:shim 系统打开命令
  - 验收:双平台真机开默认浏览器
- [ ] P8 文件管理器打开并选中文件
  - Linux:DBus 文件管理器统一接口的 ShowItems;无服务时回退 xdg-open 目录
  - Windows:explorer 定位选中参数
  - 验收:双平台打开文件管理器并选中;差异记 adaptation.md
- [ ] P9 屏幕常亮(设置 / 恢复)
  - Linux:DBus 屏保服务的 Inhibit / UnInhibit( inhibit 返回的 cookie 解除时须带原值)
  - Windows:线程执行状态(启用显示必需标志,解除还原)
  - 验收:启用后到达息屏时间不熄屏,禁用恢复
- [ ] P10 电量查询(百分比 + 充电状态;无电池返回空)
  - Linux:DBus UPower——电池设备的 Percentage / State 属性
  - Windows:系统电源状态(交流在线标志 + 剩余百分比;无电池标志判空)
  - 验收:与 upower -i / 系统托盘电量对照;台式机返回空
- [ ] P11 交流 / 电池电源切换事件
  - Linux:DBus UPower——OnBattery 属性变更信号
  - Windows:电源设置注册通知(交直流源)
  - 验收:拔插电源真机触发
- [ ] P12 网络在线状态(查询 + 变化事件)
  - Linux:DBus NetworkManager——连接状态查询与变更信号
  - Windows:在线状态 API 轮询;监听式后置
  - 验收:断网 / 联网真机触发
- [ ] P13 (后置)平台专属 — 任务栏进度(Windows)/ dock 徽标 / 最近文档
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
