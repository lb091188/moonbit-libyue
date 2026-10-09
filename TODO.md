# 路线图

状态:`[x]` 完成 · `[~]` 部分(括号内是缺口) · `[ ]` 未开始;做完勾掉并注明验证方式。

## 全仓排查修复清单(2026-10)

六路排查(TODO 时效 / markdown 能力 / sysmonitor 跨平台 / 代码与文档一致性 / yue 核心质量 / 示例与模块质量)去重汇总,用户点名优先域置顶,其后按严重度排列;MD1-MD3 即「Markdown 能力升级」M1 的落地拆分。

- [x] MD1 引入 mizchi/markdown 0.8.3 并 native 实证——独立探针示例 parse / render_html / serialize 三调用 native 跑通,根 moon.mod 钉 @0.8.3,5 个传递依赖对 mooncakes 发布链的隔离方案定案。验证:`moon run examples/probe-markdown --target native` 输出 PROBE-OK;闭包实测与「接受传递、不拆独立模块」定案见 adaptation.md「构建与链接」节 MD1 条
- [x] MD2 markdown_view 解析切换 mdast——旧自写解析器删除不留双轨,样式区间端点统一码点→UTF-16 换算(含 emoji 文本样式不错位),moon test 全绿。验证:`moon check` 零警告 + `moon test` 595 全绿(markdown_wbtest 19 条:换算/展平/区间 emoji 断言 [4,6)/info/切行 + setext/~~~/info 串/缩进代码/嵌套列表五项前后对比);mdast 实测语义回写 adaptation.md「声明式层与自绘组件」节 MD2 条
- [x] MD3 GFM 渲染面补齐——表格 / 任务列表 / 脚注 / 删除线 / 图片 / 可点击链接可渲染,showcase「代码与文档」页演示与复制串同源并补新语法,components-ui 中英能力清单同步。验证:`moon check` 零警告 + `moon test` 600 全绿(markdown_wbtest 24 条,新增删除线/携址链接/引用式链接/脚注编号上标/图片路径/表格单元格断言);真机视觉与点击项由用户在 showcase「代码与文档」页 Markdown 段验证(删除线横线/链接点击与悬浮/表格/图片/任务勾选/脚注),跨层契约与上游核实结论回写 adaptation.md「声明式层与自绘组件」节 MD3 条
- [x] SYS1 sysmonitor Windows 数据层——stub/sysmon.c Windows 分支以 Win32 补齐 CPU / 内存 / 磁盘 / 网络 / 进程 / GPU / 温度七路数据源(GetSystemTimes、GlobalMemoryStatusEx、PDH、DXGI、EnumProcesses 等,子进程原语 CREATE_NO_WINDOW),解析纯函数单测全绿,真机五页出数据(真机验证项列清单由用户执行)。验证:`moon check` 零警告 + `moon test` 600 全绿 + touch stub 后 `moon build` 零警告(sysmon.o 真实重编);Windows 分支以最小 Win32 桩头过 `gcc -fsyntax-only -Wall -Wextra` 零告警(桩不进仓库,真编译靠 CI Windows runner);Win32 虚拟 /proc、/sys 路由映射与偏差定案入 adaptation.md「系统监控数据层」节 SYS1 条;真机由用户执行五页清单:①概览页七卡出数(CPU 占用%·温度 / 内存已用·总量 / 每盘一张 / 网络收发 / N 卡占用·温度或 A·I 卡「—」/ 进程数)②CPU 详情曲线 + 各核柱 ③内存与 swap 曲线(无页面文件机器 swap 为 0 属预期)④进程页全量表可排序筛选 ⑤传感器页 N 卡温度行、A·I 卡机器为空属预期 ⑥磁盘页每盘容量条 + 读写速率(读盘时非 0)⑦网络页每网卡速率;重点核实项:中文 Windows 的 PDH 磁盘 IO 与 GPU Engine 计数器路径、GPU 占用 LUID 聚合数值、nvidia-smi 与 DXGI 型号匹配、进程管理按钮提示「不支持(仅 Linux)」属 SYS2 预期
- [x] SYS2 sysmonitor Windows 语义归一——kill / 优先级 / 错误码翻译为统一语义形态且错误码翻译表单测全绿,温度等不可用来源按位显示「—」,UI 文案平台化,TODO 边界节同步(实际终止 / 提权行为真机验证项列清单由用户执行)。验证:`moon check` 零警告 + `moon test` 608 全绿(sysproc_wbtest 新增 8 条:errno_text 翻译目标值、四档档界、kill/优先级按钮与结果文案、优先级列头、with_temp「—」占位、不存在 pid 的 get/set 归一 ESRCH)+ touch stub 后 `moon build examples/sysmonitor` 零警告(sysmon.o 真实重编);Windows 分支以最小 Win32 桩头(按真实 SDK 形状定义,不进仓库)过 `gcc -fsyntax-only -Wall -Wextra` 零告警,并修正 SYS1 遗留的 PDH `RawValue.FirstValue.largeValue` 笔误(真实 pdh.h 无该后缀,CI Windows 真实编译会红);Win32→errno 翻译表、OpenProcess 87→ESRCH 特判、优先级四档钳制与代表值反查、UI 平台化文案定案入 adaptation.md「系统监控数据层」节 SYS2 条;真机由用户执行清单:①进程页选中进程点「结束进程(立即终止)」确认进程确已退出(消息「已强制结束 N 个进程」)②对系统进程(如 csrss / audiodg)操作提示「权限不足(EACCES/EPERM)」而非异常③设优先级分别输入 7 / -10 / -20,消息依次为 正常(NORMAL)(代表值 0)/ 高(HIGH)(代表值 -13)/ 实时(REALTIME)(代表值 -20),nice 列值同步变化④普通身份设「实时」档提示权限不足,以管理员身份启动后成功⑤无 N 卡机器概览页处理器卡温度位显示「· —」、显卡卡显示「—」⑥传感器页无温度来源时显示「暂无可用温度来源」
- [x] SYS3 sysmonitor macOS 数据层——stub 补 macOS 分支(proc_listpids 进程枚举、sysctl + host_processor_info CPU、hw.memsize + host_statistics64 内存、getfsstat+statvfs 磁盘、getifaddrs 网络、system_profiler -json GPU 子进程),IO 速率与温度按边界显示「—」,解析纯函数单测全绿(真机验证项列清单由用户执行)。验证:`moon check` 零警告 + `moon test` 614 全绿(syshw_wbtest 新增 6 条:unescape_mount / parse_mounts macOS 形态 / is_system_mount 系统宗卷 / parse_vram / json 切分 / parse_system_profiler_gpu 双卡)+ touch stub 后 `moon build examples/sysmonitor` 零警告;macOS 分支以 `gcc -fsyntax-only -Wall -Wextra -D__APPLE__` 零告警(Mach / statfs / if_data64 布局按 xnu 源码逐字段核实,桩头不进仓库,真编译靠 CI macos-15 runner);七路映射与自声明布局核实过程、host_statistics64 count 语义、unsafe_get 返回 UInt16 等踩坑入 adaptation.md「系统监控数据层」节 SYS3 条;真机由用户执行清单:①概览页七卡出数(CPU 占用%·「· —」温度位 / 内存已用·总量 / 每卷一张(根 + Macintosh HD 数据卷,swap 有值)/ 网络收发 / 显卡卡「—」/ 进程数)②CPU 详情曲线 + 各核柱(重点核实占用数值合理、顺序无错位)③内存与 swap 曲线(与活动监视器对照)④进程页全量表可排序筛选(进程数与 ps 对照,选中→结束进程 / 设 nice 实际生效)⑤传感器页无温度来源显示「暂无可用温度来源」、显卡使用率与显存曲线为空属预期(无来源)⑥磁盘页每卷容量条 + 读写速率「—」(容量与 df 对照,含含空格卷名)⑦网络页每网卡速率;重点核实项:system_profiler -json 的键名与解析对位(Apple Silicon 与 Intel/AMD 卡各测)、中文/含空格卷名的挂载行、kill 提示语义与 Linux 一致
- [x] SYS4 Linux GPU 利用率补全(Intel 集显 / AMD)——DRM fdinfo 聚合采样免 root 得全卡利用率(AMD 保留 sysfs gpu_busy_percent 优先、fdinfo 兜底),「常规显卡数据无需超管、debugfs 细分不支持、polkit 暂不集成」边界入 adaptation.md,解析纯函数单测全绿。验证:`moon check` 零警告 + `moon test` 623 全绿(syshw_wbtest 新增 9 条:parse_drm_fdinfo 三形态 / is_drm_engine_key 与 drm_device_key / drm_clients_total 归并 / drm_busy_percent / is_pid_entry / parse_uevent_driver / fdinfo 真实采样两拍)+ 删 `_build` 下 sysmonitor `.o` 后 `moon build examples/sysmonitor` 零警告;免 root 权限实证(hwmon 0444 / debugfs 0700 / 他人 fdinfo EACCES)、fdinfo 键格式与版本边界(引擎键 5.19 起、drm-pdev 6.5 起)、扫描 56ms 成本等定案入 adaptation.md「系统监控数据层」节 SYS4 条;i915 / xe / amdgpu 真机七项由用户执行(intel_gpu_top 对照、AMD 双源对照、双卡归属、老内核回退、短命客户端漏计、sudo 差异量级、采样占空)
- [x] SYS5 GPU 型号名解析——AMD / Intel 显卡经 pci.ids 显示商业型号(查不到回退现 id 显示),解析纯函数单测全绿。验证:`moon check` 零警告 + `moon test` 628 全绿(syshw_wbtest 新增 5 条:norm_pci_id / is_hex4 归一化与判定、pci_ids_device_name 缩进层级解析、gpu_model_name 四形态、GpuMonitor::gpu_model 常驻缓存与 smi 优先、真实 pci.ids 采样)+ 删 `_build` 下 sysmonitor `.o` 后 `moon build examples/sysmonitor` 零警告;本机(Ubuntu 24.04)实测三对真实条目解析正确(1002:7480 → Navi 33、8086:3ea0 → WhiskeyLake-U GT2、10de:2488 → GA104),单次全文查找约 14ms 故按 PCI 地址常驻;pci.ids 路径差异与 Flatpak 沙箱兜底、空 id 补零踩坑入 adaptation.md「系统监控数据层」节 SYS5 条;AMD / Intel 真机七项(型号名与 lspci 对照、双卡、查不到回退、无 hwdata / Flatpak 兜底、跨发行版路径、长名换行)由用户执行
- [x] DOC1 英文 components-ui.md 补齐——第二批九图表与图表交互层整章翻译入英文档,Scroll::refresh_content_size 等三处英文滞后点同步,与 docs/README.md 索引描述对齐。验证:英文 components-ui.md 图表章补入树图/矩形树图/旭日图/地图与飞线/力导向/平行坐标/主题河流/涟漪散点/象形柱九节与图表交互层七小节(签名/参数表/示例逐节对齐中文版),components.md 补 Scroll::refresh_content_size 方法行与拖拽须在 on_mouse_down 内调用一句、declarative.md 补 scroll 备注句;`moon check` 零警告 + `moon test` 628 全绿
- [x] DOC2 文档签名错误与过时描述批量修复——7 处 width/height 示例改 style 传参、declarative card 签名行删 height?、declarative 中英括号错配示例、theme_* 过时描述、「四个示例」计数、aboutlibyue / plan-system-integration 索引缺项、README 组件数量口径、adaptation scroll() 过时陈述、system-capabilities Result 括号笔误全部修正。验证:`moon check --deny-warn` 零警告 + `moon test` 628 全绿;逐条与代码签名对位(line_chart_t / bar_chart_t / donut_chart_t / card / textarea_t / progress_line / divider 的 style? 参数与 40 原生控件类型、58 个返回 Node 的主题组件函数、20 图表 + 3 交互变体的重统计口径)
- [ ] CORE1 browser 自定义协议拒绝编码修复——reject 载荷首字节改 0、C 端对 ok==1 短载荷防御拒绝,handler 返回 None 路径补测试,拒绝不再触发原生堆越界读
- [ ] EX1 VideoPlayer 重播状态机修复——播完后再点播放从头重播、stop 后重播有声,循环 / stop→play / 播完→play / 音量钳制 wbtest 补齐,systemprobe 视频页文案更新为流式解码事实
- [ ] EX2 sysmonitor 进程数据正确性——nice 字段改 parse_i64 负值正确显示,新出现 pid 当拍 CPU% 置 0 不再钉满格,负值回归用例入 wbtest
- [ ] CORE2 yue 核心健壮性批次——SNI 菜单路径随项派生且注销 / 注册失败对称清理,总线重连先检查按需重建连接防 fd 泄漏,Store 增 remove 与主题订阅可退订,carousel / video_view 挂载定时器获得回收通道,moon test 全绿,SNI 多项场景真实总线复验

## 2026 年 10 月月度目标与 Q4 季度目标

10 月(月度):完成现在规划的三大能力域收尾——系统接口、音频、视频渲染;Q4(季度):月度目标全部达成后,macOS 真机验证测试收尾 + 发布闭环。

音视频主体已落地(modules/yue-media + modules/ffmpeg-mbt 两子模块,2026-10-08~09 修复链实测):FFI 流式解码全链路、AudioPlayer / VideoPlayer、悬浮控制条与全屏、墙钟同轴时钟;O2 / O3 为其收尾项。

- [ ] O1 系统接口收尾(月度)
  - P14 真机复验清单闭环:GNOME / KDE 桌面侧重跑 P1-P12 验收项;Windows 10/11 真机(双开唤起 / 自启动拉起 / 休眠唤醒 / 锁屏解锁 / 拔插电源 / 断联网);清单见 docs/zh/plan-system-integration.md B8 节
  - 视余量:媒体控制补 Windows 路径(SMTC,对齐 media.mbt 的 MPRIS 语义)
  - 验证:各真机项按 P1-P12 验收列逐条回填
- [ ] O2 音频收尾(月度)
  - 精确音画同步:音频光标回读(现为 play 起点同源时钟,误差数十毫秒级,记档见 adaptation.md「视频播放器」节)
  - 验证:VideoPlayer 拖动进度后音画偏差实测入档
- [ ] O3 视频渲染收尾(月度)
  - 真实片源实测:mp4 已随修复链实际播放,mkv 等常见容器与长视频未系统实测;复核 ffmpeg-mbt 流式逐帧解码下长视频内存平稳性(原 CLI 帧集钳制已随路线删除)
  - moonav1(mooncakes 纯 MoonBit AV1 解码)帧源接入评估
  - 验证:真机播放实测片源截图入档
- [ ] O4 macOS 真机验证测试(季度,前置:获得 mac 真机)
  - 基础冒烟:hello / hello-themed / showcase / systemprobe 全量启动与视觉确认
  - 遗留清单逐项:reply(OS_MAC) 通知回调、Display 全字段枚举、Accelerator 类 / Tray 原生后端、mac canvas 滚轮事件、WebKit framework 拆分评估(浏览器按需化 fork 侧收尾)
  - 验证:mac 真机逐项执行,结论回填 TODO.md 与 adaptation.md
- [ ] O5 发布闭环(季度)
  - mooncakes 发 0.5.11:携带 yue-media / ffmpeg-mbt 依赖与悬浮控制条修复链(0.5.10 已于 2026-10-04 前后发布)
  - README 截图补齐(sysmonitor 传感器 / 磁盘 / 网络三页)

## 遗留

- [~] 通知回调 — reply(OS_MAC)留平台目标
- [~] 缓办 — Display 全字段枚举、mac 专属(Accelerator 类 / Tray 原生后端等)
- 平台
  - macOS 暂缓(无设备)
  - Windows 富文本 / markdown 观感待真机复验
- [ ] **libyue fork 根修:Windows 运行期 remove+add 子树后鼠标 hit-test 错乱**(bind_node 病根,详见 docs/zh/adaptation.md「bind_node 运行期重挂后 Windows 鼠标 hit-test 错乱」)
  - 现象:点击回调链里 remove_child+add 新子树后,新子树的 size_allocation_(ViewImpl 布局分配矩形)异常,FindChildFromPoint 恒命中它——全窗点击被误路由给重挂过的控件、不可逆、连标题栏都关不掉;推迟重挂躲不开,Linux 无恙
  - 复现工具:examples/probe-click(行2 bind_node(button_t) 必现,事件流自动记录)
  - 排查方向:RemoveChildView 后被移除 view 的 size_allocation_ 残留、新挂 view 首轮 Layout 前的初始值;补丁方向:remove 时清零或 FindChildFromPoint 对未布局 view 防御
  - 修好随 vendor-* 重出包后:解除 bind_node 的 Windows 警示与 swap_node 的「安全替代」定位(两 API 并存,swap_node 仍有零重建的低开销价值)
- [ ] 浏览器按需化的 fork 侧收尾(4a 治本,详见 docs/zh/adaptation.md「浏览器依赖按需化」)
  - fork(lb091188/yue)发行脚本把 browser.cc / browser_gtk.cc 与 menu_item_gtk 的 webkit 耦合拆出 jumbo(补丁原型已在本仓库 prepare.py 源码路径实测:抽段 + GType/dlsym 运行时探测)
  - 重发 vendor-* 三平台预构建库,prepare.py 升版本后,预构建模式(mooncakes 零编译路径)获得与源码模式同等的 webkit 按需化
  - macOS 的 WebKit framework 拆分随该批次一并评估(需先在 mac 侧核验 libyue_prebuilt(macos) 的 WebKit 引用面)

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

- [x] U1 骨架 — tabs_t 五页:概览 / 进程 / 传感器(温度+GPU) / 磁盘 / 网络;主题深浅自动跟随
  - 验证:五页页签切换真机实测;xfconf 切 Adwaita-dark 系统主题,应用实时跟随变深色(截图亲验),切回浅色同样联动;顺修 tabs_t 写死 360px 宽导致页内 Scroll 塌缩的缺陷(见 adaptation.md)
- [x] U2 概览页 — CPU 总占用 + 各核、内存、swap 实时曲线(line_chart_t)+ 关键数值卡片
  - 验证:8 张数值卡片(CPU/内存/swap/进程/温度/根磁盘/网络/GPU)+ 4 幅图(CPU 总占用 0-100 固定轴、20 核柱状 0-100、内存 GB、swap GB)1Hz 刷新、120 点 2 分钟滚动窗口;真机截图亲验曲线与卡片数值合理(CPU 4-5%、内存 10.5GB/31GB、60℃ Package、74% 根磁盘)
- [x] U3 进程页 — table_v_t 虚拟表格(千行级)
  - 搜索过滤;列头点排序;选中 kill(SIGTERM,失败 SIGKILL)/ renice
  - 1Hz 增量刷新
  - 验证:filter_procs / sort_procs / proc_row 纯函数测试(大小写不敏感、六列升降序、行格式);真机截图验证表格渲染(8 列 / 命令行 / 斑马纹 / 状态行)、PID/CPU%/进程名列头点击排序(状态行同步);输入框按用户要求从原生 Entry 换主题化 input_t(深色主题下跟随,截图复验);选中→kill→renice 交互链路待用户真机执行后回填
- [x] U4 其余页
  - 传感器:温度列表 + 迷你曲线
  - 磁盘:容量条 + IO 曲线
  - 网络:网卡 rx/tx 曲线
  - 验证:三页实现完成(moon check / moon test 全绿时点验证);单容器 on_draw 自绘行(迷你曲线 120 点窗口、容量条、rx/tx 叠加曲线),行数随数据增减不重建视图树;真机截图复验待用户执行(原前置 table_t / table_v_t 拖列宽已分别修复,复验本身仍待做)
- [x] U5 性能实测 — 千行进程页 1Hz/2Hz 刷新的帧率与内存占用,延续 vs C++ 基线口径入 adaptation.md
  - 验证:1053 进程全量采样 14.94ms/次(release);稳态进程页 1Hz CPU 2-3%、Rss 85.8MB 走平;启动中位 81ms、二进制 7.72MB,数据入 adaptation.md 中英两份;2Hz 档待应用可 rebuild 后补测(定时器改 500ms)
- [~] U6 文档发布 — README 中英挂旗舰示例与截图;踩坑回写 adaptation.md;mooncakes 发新版
  - 已完成:README 中英根文档 + docs/README 中英示例区挂 sysmonitor 旗舰条目与三张截图(概览/进程页/深色);U5 实测与全部坑位已入 adaptation.md 中英两份
  - 缺口:传感器/磁盘/网络三页截图待用户真机复验后补;mooncakes 发 0.5.11(0.5.10 已发布,现缺口为其后的 yue-media 依赖与控制条修复链增量)

### 边界

- Linux 仅测试 Ubuntu 24.04:GNOME、XFCE、KDE 桌面环境;Windows 窗口可编译启动(CI 三平台在跑),sysmonitor Windows 数据层(SYS1)与进程管理语义归一(SYS2)已完成,真机行为验证项列清单由用户执行;macOS 数据层(SYS3)已落地(七路虚拟 /proc、/sys 文本 + GPU system_profiler 解析,IO 速率与温度无来源按「—」显示),真机七页验证项列清单由用户执行
- Windows 进程管理边界(SYS2):结束进程一律立即终止(TerminateProcess,温和结束 WM_CLOSE 关闭通知方案后置);优先级为 IDLE/NORMAL/HIGH/REALTIME 四档离散值(nice 列显示档位代表值,输入就近钳制),「实时」档需管理员提权;非 NVIDIA 卡温度无来源,对应显示位显示「—」
- systemd 服务管理、连接级网络监控(只做网卡速率)
- GPU 受限项:Intel 集显温度无 sysfs / hwmon 节点(i915 hwmon 仅 dGfx)、macOS 温度走私有键、Windows 非 NVIDIA 温度需厂商 SDK;AMD gpu_busy_percent 为标准 sysfs 属性、Intel 利用率有 DRM fdinfo 标准接口,均免 root(Intel / AMD 利用率已由 SYS4 补全:DRM fdinfo 聚合采样,型号名解析见 SYS5)

## 系统集成扩容(Electron 对标,Linux + Windows)

实施计划:docs/zh/plan-system-integration.md

桌面应用通用能力,属框架「系统集成」域(与托盘 / 通知同域),区别于 sysmonitor 的应用领域需求;macOS 暂缓。落地路由按平台:Linux = 纯 MoonBit / DBus(traybus 基建复用) / shim;Windows = 一律 shim(Win32 API)。语义归一在 MoonBit 层,使用方零平台感知。

- [x] P1 防多开(单实例)
  - Linux:DBus claim 应用专属总线名,claim 失败即已有实例
  - Windows:命名互斥体,已存在标记即已有实例
  - 验收:双开第二实例先 wake_existing 唤起首实例再退出;XFCE 真总线抓包验证(Wake→RETURN 39µs,SIGKILL 后三实例可再 claim);GNOME / KDE 与 Win10 / 11 真机待验
- [x] P2 二次启动唤起已有窗口
  - Linux:DBus——第二实例向应用总线名发消息,首实例回调并前置窗口
  - Windows:消息窗口 WM_COPYDATA 透传命令行,标题查找置前为兜底
  - 验收:双开后首实例窗口置前,并收到第二实例命令行参数(真机待用户)
- [x] P3 开机自启动(查询 / 设置 / 取消)
  - Linux:XDG 自启动目录写 .desktop 文件(纯 MoonBit);坑:exe 绝对路径经 /proc/self/exe 需 readlink(应用侧 stub),路径含空格的 .desktop 转义
  - Windows:注册表当前用户 Run 键写值(通知 AUMID 已有写注册表先例)
  - 验收:设置后重新登录 / 重启拉起,取消后不拉起(宿主机冒烟:.desktop 落盘 + desktop-file-validate 零警告;重启拉起待真机)
- [x] P4 挂起与唤醒事件
  - Linux:DBus logind——PrepareForSleep 信号(参数区分将睡 / 已醒)
  - Windows:电源广播消息(挂起 / 自动恢复两事件,窗口过程 hook)
  - 验收:dbus-monitor 对照(系统总线 BecomeMonitor 被拒,以探针订阅往返+注册表分发单测代);真机休眠 / 唤醒各触发一次(待用户)
- [x] P5 锁屏与解锁事件
  - Linux:DBus logind——Session 的 Lock / Unlock 信号
  - Windows:终端服务会话变更通知(锁定 / 解锁两事件)
  - 验收:真机锁屏 / 解锁触发(待用户);无 logind 环境降级 Err(Unsupported) 已验
- [x] P6 获取用户空闲秒数
  - Linux:shim——X11 屏保扩展查询;Wayland 后置
  - Windows:shim——最后输入时间查询(结构更简单)
  - 边界:active / idle 阈值判定由调用方比较,不设单独接口
  - 验收:与 xprintidle 数值对照(实测差 17ms);xset q 不含当前空闲读数,不能当基准
- [x] P7 默认浏览器打开 URL
  - Linux:shim spawn xdg-open
  - Windows:shim 系统打开命令
  - 验收:双平台真机开默认浏览器(Linux spawn 链路冒烟已过;视觉确认待真机)
- [x] P8 文件管理器打开并选中文件
  - Linux:DBus 文件管理器统一接口的 ShowItems;无服务时回退 xdg-open 目录
  - Windows:explorer 定位选中参数
  - 验收:双平台打开文件管理器并选中;差异记 adaptation.md(FM1 在线探测与 file_uri 冒烟已过;视觉确认待真机)
- [x] P9 屏幕常亮(设置 / 恢复)
  - Linux:DBus 屏保服务的 Inhibit / UnInhibit( inhibit 返回的 cookie 解除时须带原值)
  - Windows:线程执行状态(启用显示必需标志,解除还原)
  - 验收:启用后到达息屏时间不熄屏,禁用恢复(Inhibit/UnInhibit cookie 真总线往返一致;息屏实测待真机)
- [x] P10 电量查询(百分比 + 充电状态;无电池返回空)
  - Linux:DBus UPower——电池设备的 Percentage / State 属性(实测走 DisplayDevice 聚合设备,含 'd'/'t' 线型;台式机 IsPresent=false → Ok(None) 真总线验证)
  - Windows:系统电源状态(交流在线标志 + 剩余百分比;无电池标志判空)
  - 验收:与 upower -i / 系统托盘电量对照;台式机返回空(台式机路径已验,笔记本读数对照待真机)
- [x] P11 交流 / 电池电源切换事件
  - Linux:DBus UPower——OnBattery 属性变更信号(订阅经 B5 信号注册表,回调内直解 changed 字典不重查)
  - Windows:电源设置注册通知(交直流源;事件接入随 B6 电源消息窗口)
  - 验收:拔插电源真机触发(助手宿主机为台式机,无法本地触发)
- [x] P12 网络在线状态(查询 + 变化事件)
  - Linux:DBus NetworkManager——连接状态查询与变更信号(State 70/50 × Connectivity 4/3 归一 Online;两条信号订阅,回调内只读缓存)
  - Windows:在线状态 API 轮询(NLM COM,5s set_timer);监听式后置
  - 验收:断网 / 联网真机触发(待用户);查询路径 busctl 对照一致,私有总线降级 Err(Unsupported) 已验
- [ ] P13 (后置)平台专属 — 任务栏进度(Windows)/ dock 徽标 / 最近文档
- [x] P14 测试与文档
  - Linux 三桌面 + Windows 10/11 真机复验(待用户,复验清单见 docs/zh/plan-system-integration.md B8 节);DBus 互操作真总线验证(XFCE 主链路已随各批完成)
  - components.md 中英文档;showcase「系统集成」页补演示(自启动开关 / 单实例 / 打开外部 / 屏幕常亮与空闲 / 休眠唤醒与锁屏 / 电量与网络)
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
- 边界:mdast Span 为 Unicode 码点索引,yue AttributedText 区间为 UTF-16 code unit(MoonBit String 内部同为 UTF-16),换算方向码点→UTF-16,FFI 字符串统一 utf8_bytes 由 C 侧消化;0.x 版本 API 有变动风险

## 已知边界(详见 docs/zh/adaptation.md)

- 原生控件不跟暗色:Table/DatePicker/Picker/ComboBox/原生 Button;RichEdit 输入框可经消息通道暗色化
- 主题库新组件一律全自绘,不再引入新的原生皮肤依赖
- 滚轮事件 Linux(GTK scroll-event)/ Windows(WM_MOUSEWHEEL 命中下发补丁)已接入;mac 的 canvas 自绘视图滚轮待补
- color_picker_t 为预设色板形态,HSL 面板未做;carousel_t 无切换动画

## 随手可查

- FFI 规范与坑清单:`.agents/skills/moonbit-c-binding/`
- 平台适配经验:`docs/adaptation.md`
- 完整 API 对照:libyue TS 声明(github.com/yue/yue releases);Lua 绑定参考(github.com/yue/yue 的 `lua_yue/`)
