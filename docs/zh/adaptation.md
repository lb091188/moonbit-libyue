# 平台适配经验

各平台实测坑与结论,每条只记「坑 + 修复」;协议互操作结论均来自真总线、真面板验证。Linux 按发行版 → 桌面环境组织,Windows / macOS 按版本;新增结论写进对应小节,英文版 [docs/adaptation.md](../adaptation.md) 同批同步。

## 性能基准

MoonBit 全链路(shim + MoonBit 运行时)相对 C++ 原生的开销:examples/hello(release 构建)对比功能相同的纯 C++ libyue hello,两者链接同一 vendored 静态库,C++ 侧不含 shim——差值即封装层全部开销。

| 指标 | C++ 原生 | MoonBit 全链路 |
|---|---|---|
| 启动(热启动 20 轮中位,exec → 窗口 map) | 73ms | 70ms |
| 稳态内存(窗口静置 3s 的 Rss) | 62.1MB | 62.9MB |
| 二进制体积 | 6.52MB | 7.39MB |

口径:Ubuntu 24.04 XFCE(X11)同机同会话,启动差值小于检测粒度视为持平。C++ 侧 `-std=c++20 -O2 -DNDEBUG`;头文件用同版 fork 树(nativeui)+ 预构建配套树(base/build,并把 `base/allocator/partition_allocator/src` 补为 include 根);缺 `-DNDEBUG` 会缺 `RefCountedBase::CalledOnValidSequence` 符号,链接失败。

## 跨平台通用(构建链 / FFI)

### 构建与链接

- moon 必须在仓库根执行:vendor/build 产物与 WebView2Loader.dll 的运行期搜索按工作目录。
- 库包不得写 link 段(moon 会生成无 main 的 exe,构建失败);链接参数全部由 `scripts/prebuild.py` 经 `--moonbit-unstable-prebuild` 钩子输出 link_configs,自动传播给所有依赖 yue 的 main 包,任何包不手写 `cc-link-flags`。
- prebuild 脚本约束:stdout 只能输出最终 JSON(进度信息走 stderr);全部参数放 link_flags 单一字符串自控顺序(`-lyue_mbt` 必须排在 `-lstdc++` 之前,GNU ld 单遍扫描);脚本 cwd 是使用方项目根,库路径必须绝对。
- moon 不因静态库内容变化自动重链(prebuild 只在库缺失时补建):shim 或静态库变更后用 `prepare.py` 重编 + `moon clean`(或删产物 exe)强制重链;`nm build/libyue_mbt.a | grep <符号>` 零命中即库过期。shim 比 vendored 库新时 prebuild 自动增量重编。
- shim 补丁以独立提交进 fork(lb091188/yue,main = 上游 v0.15.6),fork CI 按 tag `v*-mbt*` 出三平台源码包与预构建库;改 shim 的提交必须同批回填本机平台 vendored 库,并尽快走 `vendor-*` CI 拉齐三平台,否则 mooncakes 零编译路径对用户是断链。
- 静态库与 shim 必须同编译器家族:Linux 上 clang 库 + gcc shim 稳定段错误(同 ABI 同 libstdc++ 也崩);预构建库统一 gcc 出。Ubuntu 22.04 工具链产物最终链接需 `-latomic`。
- libyue 版本钉死在 prepare.py(`LIBYUE_VERSION` + 六资产 sha256),升级同步更新校验和。
- vendored 库随 mooncakes 分发(`lib/<平台>/`),prebuild 按「vendored → build/」级联;三平台产物由 `vendor-native.yml`(tag `vendor-*`)固化,维护机 `vendor_native.py --fetch <tag>` 拉齐。
- moon 新版弃用 `moon.mod.json` / `moon.pkg.json`(`moon fmt` 一键迁移);`moon doc` 只认新格式,旧版 moon 不认新格式。
- MSVC 按 cp936 误读无 BOM UTF-8 源码,中文注释会造出假预处理错误(报错行没有那个指令):CMake 对 MSVC 加 `/utf-8`。
- 新增 shim 函数:定义统一 `extern "C"`,声明同批进 `yue_mbt.h` 的 extern "C" 区,`nm` 确认符号无 `_Z` 前缀;GLib(`g_*`)是 Linux 专属,跨平台函数不得引用。
- 新版 moon 弃用 trait 方法隐式提升:调用写显式静态形式 `ViewLike::method(obj)`;`impl Trait for X` 声明点须补 `pub extend X with Trait::{...}`(方法清单从 `moon check --no-render` 输出生成,勿手抄);黑盒测试内引用包内符号须限定 `@yue.xxx`。此类警告增量编译漏报,clean 全量才见全量。

### MoonBit cfg(platform=)

- moonc 已实现 `#cfg(platform="windows"/"linux"/"macos")`,按 `-target` 三元组求值;但当前发布版 moon 只给 moonc 传无 OS 信息的 `native`,所有条件恒 false。`moon build -v` 的 moonc 命令行出现完整三元组即条件可用。
- 现行替代:运行时 `platform()` 判断,声明式树按条件组装节点,不满足就不创建控件。

### 声明式层与自绘组件

- mouse 回调内禁止 `set_background_color`:运行期 CSS 改写会吞掉紧随的首次 press(「点两次才生效」)。交互态(hover / 按下)一律 on_draw 表达;set_background_color 只用于挂载期与主题订阅回调。
- flex 容器的挂载序同时是排列序与 z 序:夹层件(把手 / 分隔线)必须严格按排列位置挂入,且视觉常显——用户靠「看」找它,不靠 hover。

### 自绘画布与图表渲染

- 离屏 `Canvas::new + get_painter` 在未 `initialize()` 时可做全部几何绘制(fill / stroke / arc / clip 均正常,无 DISPLAY 的 CI 也能跑绘制基准);但文本路径(`draw_text` / `AttributedText::get_bounds_for`)直接段错误——GTK 文本栈要 initialize 起过才在。测试基准因此分两级:无显示跑「纯函数管线 + 几何调用镜像」,有 DISPLAY 才 `initialize` 后跑真实全帧(含文本标注),两级数值都记入 `charts_wbtest.mbt` 的输出。
- painter 默认描边色下 `stroke()` 是空操作(不画任何东西):基准里忘记 `set_stroke_color` 会让描边成本显示为 ~0,虚假通过。所有描边基准必须显式设色后再测。
- 软件光栅化(GTK/X11 无 GPU 路径)下路径描边每段约 1.8µs,近垂直段(斜率 >30)约 13µs/段;`fill_rect` 每约 1µs(轴对齐快路径),`draw_text` 每次约 0.11ms,`line_to` 本身约 12ns(纯建路径)。折线图 1000 点 × 4 序列若全走路径描边,单帧 45~60ms,远超 5ms 验收线。
- 修复(图表族统一策略,见 `yue/charts.mbt`):密集态(点数 > 绘制区像素列数)按列抽稀(min/max 保极值)后改矩形路径——面积模式每列一个填到锚线的矩形(填充顶边即折线),折线模式每列画 min..max 竖条;稀疏态(点数 <= 列数)才走真实折线 + 多边形面积。绘制成本与窗口大小脱钩,只随绘制区宽度增长。
- libyue 的 Arc 无法表达逆时针弧:GTK 侧 `PainterGtk::Arc` 就是 `cairo_arc`,而 cairo 会把 `ea < sa` 规范化成「加 2π 的顺时针长弧」;Win 侧公开 API 也写死顺时针(底层 ArcPixel 有 anticlockwise 形参但没有暴露)。shim 里「ccw 用负角跨度表达」的换算因此两层都不生效——圆环内弧硬用 ccw 会把内孔包进长弧,填充出实心饼(真机截图实测:环形图/仪表盘中心不镂空,"总计"/百分比压在实心面上)。修复:内弧回程改折线近似(整圆 32 段,弦误差 <0.4px,三平台一致);纯描边场景(图标弧)直接交换起止角等价。fork 层若要把 `PainterGtk::Arc` 改成 `cairo_arc_negative` 才是根治,需走 vendor-* 出包,暂未做。
- 图表验收基准(release,Ubuntu 24.04 XFCE X11,离屏 Canvas + initialize,真实全帧含文本):折线 1000 点 × 4 序列(陡锯齿对抗数据)3.08ms / 平滑数据 1.81ms;柱状 200 类目 0.38ms;环形 50 扇区 0.70ms;仪表盘 0.15ms;散点 10000 点 3.03ms。纯函数管线(值域/刻度/抽稀/坐标换算)折线 0.028ms。推点长跑:4800 次(10 分钟 @2Hz × 4 序列)共 2.89ms,窗口长度恒定 1000 不增长——活数据 4 × 1000 × 8B = 32KB 有界,内存增量来自 GC 回收的换窗垃圾,连续推点不积累。
- 折线面积锚点:0 在值域内取零线,全正值取绘制区底,全负值取绘制区顶(跨零时一列上下两段矩形)。

### 布局几何(Yoga flexbox)

- 布局断言 16/16 通过(±1px);叠加规律:内容区 = 容器 − 2×padding;gap 不与 margin 叠加;百分比基准为父内容区宽。
- 复合控件(Tab / Scroll / Group)在 yoga 树里是无 measure 的叶节点,外框尺寸必须显式给出(如 `flex:1`),否则塌缩(Tab 构造时固化最小尺寸,页区域归零)。
- tabs_t 曾把 outer 宽度写死 360px、内容页无 flex:放进页里的 Scroll / Table 因此塌缩归零(实测 sysmonitor 概览页整个空白,只有页签头)。修复:outer 去掉固定宽改 `flex:1`(列容器默认 stretch 拿宽度,父有确定高度时填充),内容页同样 `flex:1`。父容器无确定高度时 flex 不增长,内嵌场景(showcase 的分段演示)布局不变。
- GUI 自动化:键盘驱动(Tab 聚焦 + Space 激活)首选;`xdotool key --window` 走 XSendEvent 会被 GTK 丢弃,必须 XTEST(不带 --window);坐标点击受 WM 装饰偏移影响不可靠。

### MoonBit ↔ C ABI

- 蹦床与 C 函数指针原型逐位对齐,含参数个数:C 以 `(closure, args...)` 调用,蹦床首参收 closure。错位后行数正常、部分回调能跑,极具掩盖性;每个回调都真实触发过才算验证。
- `extern "c"` 返回可空类型:旧版工具链直接段错误(成败经 `Ref[Int]` 出参报告);moon 0.1.20260904 + moonc v0.10.12 实测 `-> Bytes?` 已可用——C 侧返回 NULL 正确映射 None,debug / release 双模式、真实缺失文件与目录(EISDIR)路径均验证(sysmonitor 的 read_text_file)。其余可空类型(句柄等)未复测,仍按出参模式兜底。
- FFI 指针参数标 `#borrow`(编译器强制);控件参数写句柄类型 `View`,不写 MoonBit 包装 struct(否则运行时句柄全部无效且静默丢弃)。
- 闭包跨 ABI:无捕获顶层函数字面量即 C 函数指针;带捕获走「函数指针 + 闭包指针」双参模式。
- 回调闭包由注册表进程级保活,不随窗口回收(单窗口工具场景泄漏可忽略,已定案)。
- Toolbar / Vibrant 的 Linux 静态库无符号,链接必败,不暴露;Browser 空 Cookie 列表崩溃已在 fork mbt.7 修复。
- 改 shim 签名必须 `.cpp` / `yue_mbt.h` / ffi.mbt 三处同批;漏同步或整段漏声明的断链形态都是 mangle 分裂(`_Z` 前缀符号对纯 C 名引用),nm 对比定位;出包前跑「.cpp 全量定义 × 头文件声明」对照扫描。
- XFCE 面板 IconPixmap 优先于 IconName:set_icon_name 与 set_pixmap 互斥,设一方须清空另一方。

## Linux

### 发行版

#### Ubuntu 24.04 ✅ 主链路

- 系统依赖:`build-essential cmake pkg-config libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev`。
- AppIndicator 运行库已移除,libyue 内置托盘不可用 → 用 `yue/traybus/`(纯 MoonBit SNI 直连面板)替代。
- webkit2gtk 包名 4.0 / 4.1 因发行版而异,prepare.py 以 pkg-config 探测,任一存在即可。

#### 其他发行版 ❓ 未实测

- 移植第一步:核对依赖的 pkg-config 名称,再跑 prepare.py。

### 桌面环境(托盘 / 菜单行为差异)

#### XFCE ✅

- 右键菜单由面板自镜像 DBusMenu 渲染,不走 SNI ContextMenu 让应用自绘。
- xfce4-panel 4.18 只发批量版 `EventGroup` / `AboutToShowGroup`,不发单条版:只实现单条版会被 UnknownMethod 静默拒绝,表现为菜单能弹、点击全部无效。
- 桌面通知必须走 `Notification::Show()`;`NotificationCenter::AddNotification` 在 Linux 从不发 DBus Notify,静默失败。
- 全局快捷键是 XGrabKey 排他注册,键位被占用 Register 返回 -1(不崩,静默失败),使用方须检查并提示换键。
- 焦点落在桌面时 xfwm4 抢占键盘,全局快捷键不触发(焦点在应用窗口时正常)。

#### GNOME ✅(X11 与 Wayland 双会话)

- AppIndicator 扩展在注册瞬间读 Menu 属性建代理:空菜单返回 `/` 会让菜单客户端永久坏死(点击图标全程无反应)。traybus 恒返回真实 `/MenuBar`,空菜单也导出,靠 LayoutUpdated 填充。
- `ItemIsMenu=false`:左 / 右键均发 Activate。
- 全局快捷键在 Wayland 会话段错误(上游用 GDK X11 宏强转根窗口):已加 `GDK_IS_X11_DISPLAY` 守卫,非 X11 会话 Register 返回 -1。
- 鼠标键位是 yue 统一语义 1=左 2=右 3=中,GDK 原始的 2/3 已被交换,组件按 yue 语义判断。
- SSH 起 GUI 的环境变量:X11 会话 `XAUTHORITY=/run/user/1000/gdm/Xauthority`;Wayland 会话 `XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.*` 与 `WAYLAND_DISPLAY=wayland-0`;均需 `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`。

#### KDE ✅(Plasma 5.27)

- 面板直收 SNI,新图标直接进可见托盘区;托盘 / 菜单 / 退出全链路通过。
- 协议行为与 XFCE 相反:只发单条 `Event` / `AboutToShow`,不发批量版;traybus 两种都实现。

#### Deepin ✅(23 / 25,DDE)

- dde-dock 实现 StatusNotifierWatcher,SNI 直连可用;新图标默认进折叠区,可拖出常驻。
- libyue 的 Popover(透明窗 + 指针抓取)在 DDE 不渲染且拖慢鼠标:shim 按 `XDG_CURRENT_DESKTOP`(23=DDE,25=Deepin)回退无边框普通窗口。
- 宿主机(Ubuntu 24.04)构建的二进制可直接跑:glibc 符号上限 2.38 且 deepin 带 webkit2gtk-4.1 运行库;跨发行版分发先查 glibc 符号需求(`objdump -T | grep GLIBC_`)。
- `TextEdit::Delete()` 是删选区不是清空;清空用 `set_text("")`。
- DDE 剪贴板管理器交互偶发 CHECK / CRITICAL 日志噪音,不影响功能。

#### KDE / MATE / Cinnamon / Budgie / LXQt ❓ 未实测

- 协议层均支持 SNI,traybus 已按协议实现,待真实环境逐一验证。

### DBus 线路协议(traybus)

- DBus 数组长度前缀不含首元素前的对齐填充;算进去会被 dbus-daemon 判违规断连。
- 头部 SIGNATURE 字段的 variant 签名是 "g"(u8 长度编码),按 "s" 编过不了真实总线。
- SNI Menu 属性恒返回真实菜单对象路径,空菜单也不能回 `/`。
- 单测自洽 ≠ 互操作通过:协议问题用 dbus-monitor 抓真总线定位,GNOME 面板侧异常看 journalctl。

- sysmonitor 实测(Ubuntu 24.04 XFCE X11,口径同篇首性能基准:启动中位、稳态 Rss、release 二进制):启动(exec → 窗口 map)5 轮 77/78/81/82/88ms,中位 81ms(hello 基线 70ms 是空载系统,本次系统载有 1042 进程);稳态进程页前台 1Hz 刷新 CPU 2-3%(采样 + 派生数据 + 千行表格重建 + 重绘合计约 25ms/秒),Rss 84.9MB → 100s 后 85.8MB 走平;二进制 7.72MB(hello 对照 7.03MB)。千行进程页验收达标:1053 进程全量采样 14.94ms/次(release,≈14µs/进程,每进程两次 /proc 读取),1Hz 下采样占空 1.5%。
- 千行表格用 table_v_t 虚拟滚动(只画可见行):刷新走「数据层全量采样 → 过滤/排序派生 → rows Store set → 表格 load + schedule_paint」,不重建视图树;选择按 pid 重映射(排序每秒变化时选中不漂)。无 C++ 对照副本,「封装层 + 数据层」合计开销以上述数值直接归因,UI 绘制部分与 hello 基线同口径(持平量级)。
### 系统监控数据层(/proc、/sys,sysmonitor 示例)

- /proc、/sys 伪文件 stat 尺寸恒为 0(fseek/ftell 拿不到长度):整文件读取必须循环增量 `fread` + 倍增缓冲(上限 16MB);读目录时 `fopen` 成功但 `fread` 报 EISDIR,靠 `ferror` 判失败。实现在应用 native-stub `examples/sysmonitor/stub/sysmon.c`,MoonBit 侧统一走 `read_text_file`。
- 应用自有 native-stub 可放子目录:`"native-stub": ["stub/sysmon.c"]` 相对 moon.pkg 所在目录解析;符号全在 libc 默认链接范围,零 shim / fork / vendored / 链接参数改动。测试目标自动链入该 stub,wbtest 可直接读真实 /proc 文件。
- /proc/stat 列序 `user nice system idle iowait irq softirq steal guest guest_nice`:第 9 列 guest 已由内核计入 user/nice,再累加即重复计数;占用率 = (Δ总 − Δidle − Δiowait) / Δ总,iowait 不算 CPU 忙。采样间隔短于一个 tick(USER_HZ 通常 10ms)时 Δ总 ≤ 0,返回 0;首帧前样本取全零,首屏值为开机至今均值。
- /proc/cpuinfo 型号字段平台分歧:x86 是 `model name`,ARM 开发板只有 `Processor` / `Hardware`,三级回退;核数取 `processor` 行数(逻辑 CPU 含超线程,与 nproc 一致)。
- /proc/meminfo 单位恒为 kB;`MemAvailable` 内核 ≥3.14 才有,缺失回退 `MemFree`;已用口径 = 总 − 可用(含可回收缓存)。
- `moon run` 包装进程不向子进程传播信号:冒烟验证退出行为要杀构建产物 exe 子进程,只杀包装 PID 会留下孤儿窗口。
- 全量进程采样实测(release,Ubuntu 24.04):580 进程 × 2 文件读取(stat + cmdline)共 9.57ms/次,1Hz 刷新约占 1% CPU;RSS 取 stat 的页数 × 页大小(与 status 的 VmRSS 等值),省掉每进程第三次读取。
- /proc/[pid]/stat 的 comm 可含空格与嵌套括号(进程名 "(foo (bar))"),只能按行内最后一个 ')' 切分;comm 截断到 15 字符,完整命令行另读 cmdline(NUL 分隔,空则内核线程回退 [comm])。
- getpriority 的 nice = -1 是合法值,与出错返回值歧义:成败经 `Ref[Int]` 出参报告(kill / setpriority 仍用 errno 返回值)。
- Windows 无 /proc 与 nice 语义:stub 编译期保留同一 ABI、运行期返回「不支持」哨兵(-1000),MoonBit 层语义化为中文提示,进程页整体降级;CI 三平台构建不受影响(macOS 走 POSIX 分支天然可用)。
- diskstats 同时含整盘与分区条目(nvme0n1 与 nvme0n1p1/p2/p3);LVM 挂载设备名(/dev/mapper/ubuntu--vg-ubuntu--lv)与 diskstats 名(dm-N)对不上,须经 `/sys/block/dm-*/dm/name` 反查 dm-N 再取 slaves 首项(实测 dm-0 → nvme0n1p3)才能把 IO 速率归属到挂载行。
- hwmon 温度编号跳号(coretemp 只暴露部分核的 tempN_input),label 可缺(acpitz 无 label,回退 chip 名);毫摄氏度可为负(电池传感器);NVIDIA 独显普遍不暴露 hwmon 温度(实测 0x2488 无 temp),GPU 温度按 hwmon 口径显示「—」。
- statvfs 容量取 f_bavail(可用,含保留块扣除)而非 f_bfree,与 df 的 Use% 口径一致;结构体跨 ABI 拆成 total/free/avail 三个 int64 出参。
- /proc/mounts 的伪文件系统(proc/sysfs/cgroup2/devtmpfs/efivarfs 等约 20 种)statvfs 无容量意义,容量表按 fstype 黑名单跳过,只留 /dev/ 真实设备行;同一设备多挂载点(btrfs 子卷 / LVM 快照)按设备去重取首个。
- 目录枚举(/sys/class/hwmon、/sys/class/net、/sys/bus/pci/devices、/sys/block/*/slaves)经 stub 的 opendir/readdir 通用化(换行分隔条目名),与 read_text_file 同为数据层唯一两类 IO 原语。

### 显示协议

- X11 ✅ 主链路;Wayland 未支持,验证 GUI 行为用 X11 会话(托盘 / 快捷键已按会话守卫)。

### GTK 相关

- Table 放进 Notebook 页签会在尺寸测量时段错误(negative allocation):放普通容器或独立窗口。
- 内容型控件(Group / Scroll)继承 View 而非 Container:挂内容用 `SetContentView`,`AddChild` 会被类型校验拒绝。
- 上游 NUContainer 缺陷(补丁 `patch_linux_container_events`):①事件窗口 map 即 raise,截走子原生控件命中(页签点不动、滚轮失效)→ 改 `gdk_window_show_unraised`;②容器 preferred 尺寸硬编码 0、Scroll 的 size_request 为 0×0 → 宽度随视口、高度取内容 yoga 自然高度。不要向 GTK 报告 yoga 动态自然尺寸:allocate 会污染 yoga 状态,requisition 震荡不收敛。
- `UpdateChildBounds` 开头的可见性守卫会错过 GTK 首次 size-allocate(发生在 map 之前):布局计算须无条件执行。
- `Slider::SetValue` 对相同值也置 ignore 标记,吞掉用户首个回调:仅值变化才设标记。
- `ProgressBar::SetValue` 在 Linux 与 Windows 端语义均为 0..100,yue 层统一 0..1,换算分支须覆盖两平台。
- `View::GetBoundsInScreen` 在 Scroll / 嵌套容器下坐标叠错(补丁 `patch_linux_view_bounds_in_screen`):GTK 屏幕坐标必须「客户区原点(`gdk_window_get_origin`)+ 客户区内偏移(`gtk_widget_translate_coordinates`)」;`gtk_window_get_position` 含标题栏装饰,与 translate 混用必差一个装饰尺寸。
- 表格 Checkbox 列指示器随行高缩放(XFCE 主题):对 Checkbox 列显式 `indicator-size=16`,renderer 高度限 20。
- 拖出数据须用 `Data(std::vector<base::FilePath>)` 构造(string 构造会被静默降级为 Text);相对路径先绝对化(`g_filename_to_uri` 不收相对路径)。
- 拖拽预览图 hotspot 上游写死 (0,0),补丁改图片中心对齐光标(`patch_linux_drag_icon_hotspot`)。
- 拖放能否接收由 drag-motion(`handle_drag_update`)决定,`handle_drag_enter` 只是进入通知;注册数据类型须补 Image(从图片查看器 / 浏览器拖入的是图片内容,不是文件路径)。
- libyue 的 `Entry::SetText` 会吞掉 `on_text_change`:GTK 侧用 `is-editing` 对象数据守卫,编程式设置期间 `changed` 信号被过滤(防回环),程序化清空 / 置文本后可见文本变了但使用方拿不到回调——`input_t` 的清空 ✕ 曾因此「文本没了、筛选列表不刷新」。修复:清空处理里显式补调一次 `on_input("")`。凡编程式改 Entry / TextEdit 文本后又依赖回调的路径,都要手动补回调。
- 拖出发起:同步调 `gtk_drag_begin` 会使 GTK 拖拽状态机不一致(嵌套 gtk_main 不退出、只能拖一次),须推迟到事件队列排空、以 press 事件发起并回填 drag_context;drag-failed 须防御性收尾(fork mbt.12)。

## Windows 10 / 11 ✅

### 工具链

- 需 VS Build Tools(VCTools 工作负载 + ATL 组件,`base/win/atl_throw.h` 依赖),在 x64 Native Tools Command Prompt 或 vcvars64 环境执行 moon / cmake;安装器 quiet / passive 模式须提权,否则 Exit 5007。
- 发行包资产名是 `libyue_{v}_win.zip` / `_mac.zip`(非 windows / darwin)。
- 大小写敏感卷上编译报 C1083 找不到 `webview2.h`:SDK 只给 `WebView2.h`(大写 W),prepare.py 解压后补小写别名;同一卷上 `shutil.copyfile` 的 samefile 判定不可靠,复制前先删目标。
- 平台专属代码的 include 与实现必须同批进平台分支:裸 `gtk/gtk.h`、或有使用守卫无定义守卫的函数,都会在另一平台编译端炸出 C1083 / C2065。
- shim 平台差异:`dlfcn.h` 按 `__linux__` 守卫;MSVC 的 `M_PI` 需 `_USE_MATH_DEFINES`;`base::FilePath` 在 UNICODE 构建下是 `std::wstring`,统一经 `FromUTF8Unsafe / AsUTF8Unsafe` 进出;Windows 无 Popover、无 `SetOverlayScrollbar` / `Clipboard::Selection` / `Tray::SetTitle` 等,shim 降级空操作;`operator new/delete` 重定向 `malloc/free`(moon 运行时以 MOONBIT_ALLOCATOR=SYSTEM 编译);控件 HWND 须经 `dynamic_cast<nu::SubwinView*>(GetNative())->hwnd()` 取,`GetNative()` 本身不是 HWND。
- 原生子控件滚动后 HWND 不随容器移动(悬浮遮挡):`View::Layout()` 强制重摆,scroll 封装已挂 on_scroll,回调经 0ms 定时器推迟到布局完成后执行;输入框内阴影是 `WS_EX_CLIENTEDGE`,borderless 须清 STATICEDGE / CLIENTEDGE / WS_BORDER 三者;DatePicker 不显式给宽只显示年份;字形小图标跨平台不一致,组件内一律 Painter 矢量自绘。

### 链接参数(moon → cl / link)

- `cc-link-flags` 被原样拼进 cl 命令行,GNU 风格 `-L/-l` 报 D9002;正确做法是写链接输入(`build/yue_mbt.lib setupapi.lib …`),cl 把 .lib 位置参数转交 link,系统库由 LIB 环境变量解析。
- 路径分隔符必须正斜杠:反斜杠被 moon 参数解析吃掉,报 LNK1104。
- 官方 CMakeLists 系统库清单缺项,照抄报 144+ LNK2019;prepare.py 清单已补齐。
- CRT 必须与 moon 一致为静态 /MT:CMake 多配置生成器忽略 `CMAKE_BUILD_TYPE`,`cmake --build` 必须带 `--config Release`(prepare.py 已自动化),否则 LNK4098 + `__imp__*` 未解析。
- exe 控制台黑框已由 yue 包内置 `win_gui.c` 链接 pragma 根治:pragma 存于 .obj 的 drectve 段,静态库归档成员须被引用才会被抽取——`initialize()` 引用 stub 符号 `yue_mbt_win_gui_marker` 保证生效,依赖方零配置;release-bin.yml 的 PE 头改写(Subsystem 3→2)为兜底。用户 link_flags 拼在 `/link` 之前,cl 直接丢弃 `/SUBSYSTEM` 类链接选项(D9002),追加参数路线不可行。GUI 子系统下 stdout 仅管道 / 重定向可见。
- 换 `yue_mbt.lib` 后 `moon build` 报 no work to do:删 `_build` 下产物 exe 强制重链。

### manifest

- exe 无清单时启动即报「无法定位于序数 345」(TaskDialogIndirect 仅以序数在 Common-Controls v6 导出):官方清单编译为 `yue_mbt_manifest.res` 经链接参数进每个 exe;测试驱动用 `YUE_MBT_SKIP_MANIFEST=1` 规避与 moon 自带 MANIFEST 的 CVT1100 冲突。

### 运行期差异

- `AttributedText` 区间字体 / 颜色:上游 Windows 只支持全文(区间 CHECK 崩,GDI+ 无富文本),fork mbt.9 自建分段布局器(run 存储 / 流式折行 / 测量绘制同源),MoonBit 层降级守卫已删,三平台语义一致。坑:`Gdiplus::Font::GetHeight` 重载是 `(const Graphics*)`,传引用编不过。
- `Color::Get(Border)` 触发 NOTREACHED 返回垃圾色:shim 对 Border 用 `GetSysColor(COLOR_WINDOWFRAME)`。
- 自绘字体发虚:libyue GDI+ 画笔写死灰度抗锯齿,prepare.py 幂等补丁换 `TextRenderingHintClearTypeGridFit`。
- 系统通知:WinRT toast 按 AUMID 查 notifier,未设 AppUserModelID 时静默失败;shim 首次通知前自动设 AUMID 并写注册表 DisplayName。
- 浏览器优先 WebView2(loader / 运行时缺失自动回退 IE);WebView2 跟随系统代理,代理失效机器设 `LIBYUE_WEBVIEW2_ARGS=--no-proxy-server` 直连(prepare.py 补丁经环境变量注入 AdditionalBrowserArguments);demo:// 自定义协议在 WebView2 下无效(IE 路径可用)。
- win32 的 Group / Scroll 不按内容自增长:须显式高度;ScrollImpl 滚动范围只认 SetContentSize,prepare.py 补丁在未显式设置时向内容 yoga 树查自然尺寸。
- 键码与修饰键:Windows KeyboardCode 是 Win32 VK 值,events.mbt 入口已归一化到常量表;修饰键位 Windows 原生 Shift=2 / Ctrl=4 / Alt=8,shim `NormalizeModifiers` 补 OS_WIN 分支映射统一 1/2/4/8。
- 幽灵托盘:异常退出不跑 CRT 静态析构,图标残留;shim 装 atexit / SetConsoleCtrlHandler / SetUnhandledExceptionFilter / SIGABRT 四道钩子,按「属主窗口 + 图标 ID 区间」补发 NIM_DELETE;taskkill /F 式硬杀无法进程侧根除。托盘图标显示为空白先查资产(曾用 1×1 占位图)。
- Popover 替代实现(无边框 / 不抢焦点 / 置顶小窗):弹窗须补 `WS_EX_NOACTIVATE`(防点击弹层时抢焦点);嵌套滚动下 `GetBoundsInScreen` 有垃圾偏移,锚点坐标改取原生子控件 HWND 的 `GetWindowRect`;close 在 Windows 是销毁语义,复用弹层改 `SetVisible(false)`;点外收起挂 `WH_MOUSE_LL` 钩子,按下不在弹层矩形即 PostTask 收层;弹层背景不随主题,新增 `Popover::set_background_color` 全链路接入。libyue 的 SetVisible / IsVisible 在无 Activate 置顶窗场景不可靠,直接 Win32 `SetWindowPos` + `SW_SHOWNOACTIVATE`。
- autocomplete 键盘导航:Windows 分支在 Entry 挂 on_key_down(↑↓ 高亮 / 回车选中 / Esc 收起);单行 EDIT 无垂直居中样式,`entry_vcenter` 按字体行高收窄控件高度均分 margin;RichEdit 恒黑字不随主题,`Entry::set_colors`(EM_SETBKCOLOR + CHARFORMAT2)接入主题链路。
- 原生控件暗色:真 Win32 通用控件(RICHEDIT50W / SysListView32 / SysDateTimePick32 等)均不跟系统暗色;RichEdit 可经消息通道暗色化;Table 不可行(custom draw 自绘白底覆盖外部消息);正式方案 = 组件库全自绘,原生暗色列为已知边界。
- 命中测试与绘制层级方向相反:上游 `FindChildFromPoint` 正序遍历,后挂的全屏遮罩视觉在上、事件却穿透到先挂的容器(dialog 关不掉、点击穿遮罩)——fork mbt.6 改倒序遍历对齐绘制层级。凡「视觉在上层收不到事件」先查命中遍历方向。
- 滚轮被最外层 Scroll 直接消费不下发,嵌套滚动与自绘 canvas 收不到:prepare.py 补丁(`patch_win_wheel_dispatch`)按 FindChildFromPoint 下发光标下子视图;shim `yue_mbt_view_on_wheel` 补 Windows 分支,换算 WM_MOUSEWHEEL delta。
- 文字测宽与绘制不一致:`GetBoundsFor` 用 GenericDefault(带 overhang)、`DrawString` 用 GenericTypographic,手动 `x=(宽-测量宽)/2` 摆位必左偏;摆位一律用 `align=Center/End` 交给平台,测宽仅用于算容器宽度。
- splitter 两坑:Windows 端显式 `SetCapture` 会触发 `WM_CAPTURECHANGED` 拆掉隐式捕获(已持捕获须跳过);`flexbasis:"50%"` 百分比字符串仅 GTK 端解析,跨平台统一写像素。
- Entry 无限递归案例:非 Linux 分支两函数互调栈溢出,MSVC C4717 早已告警——「逻辑必死」类警告应按错误对待。GUI「无窗口」用 `Get-Process <name> | Select MainWindowHandle` 判定;MoonBit println 管道下全缓冲,进程被杀即丢,插桩用 stderr。
- mount_window 在 handle 回调执行后自动激活显示,消费方无需手动 activate。
- 平台信息 / 区域 / 缩放 / 剪贴板 / 定时器 / 全局快捷键 / 全局鼠标轮询 / 画布(GDI+)实测正常。

## macOS ❓ 未实测

- libyue v0.15.6 发行包含 ARC / no-ARC 双库:Darwin 链接参数 = 主库 + `-lyue_mbt_noarc`(no-ARC 符号被主库引用,须排其后)+ AppKit / Carbon / IOKit / Security / WebKit / OpenDirectory 框架 + `-lobjc -lc++ -lpthread -lbsm -Wl,-dead_strip`;prebuild Darwin 分支已按此预修。
- CI(macos runner)承担构建 + 测试;headless 无 WindowServer,不做 GUI 冒烟。
- shim 平台分支的 `#else` 兜底会误吞 macOS:borderless 须 `#elif defined(OS_WIN)`;CurrentDirForDrag 拆三支(mac 用 `getcwd`);`Window::SetSkipTaskbar` / `SetIcon` / `App::SetID` 在 mac 头文件无声明,调用补守卫空操作。

## 维护约定

1. 新增结论写进对应小节,只记「坑 + 修复」;协议互操作结论必须来自真总线、真面板,单测自洽不算数。
2. 中英两份(本文与 docs/adaptation.md)同批同步。
