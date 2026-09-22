# 系统集成扩容 · 总体实施计划

> 状态：定稿。本计划由只读调研产出：全部代码引用按当前 HEAD 逐条读实，未运行 `moon check` / `moon test`（命令级验收由各实施批次执行）。
> 核验基准：HEAD `4105e1b`、`git status --short` 仅 `?? .zcodeignore`。仓库迭代快，每批开工前重跑 `git log` / `git status` 与符号 grep 复核行号。
> 覆盖范围：TODO.md「系统集成扩容」P1-P12 + 收口项 P14；P13 后置，仅在第 6 节留说明。

## 1. 总体策略

一段话：以「Linux DBus 套系先行、Windows 同 API 批量补 shim ABI」为主轴，排七批功能 + 一批收口。B1（单实例与二次唤起）打头，在会话总线上落地 RequestName claim 与按名定向 Wake，Windows 侧把 message-only 窗口 + WM_COPYDATA 参数透传前移进本批，使 on_activate 双平台对称；B2（自启动）、B3（打开外部）、B4（屏幕常亮与空闲）互不依赖、可并行；B5 作为唯一基建批，把 shim 单 fd 槽扩为按 fd 路由的分发表、connect_session 拆出 connect_unix、建系统总线独立连接与连接注册表、泛化信号订阅、修 call_sync 超时 pending 滞留、做最小断线自愈，一次做完并以最薄的 UPower 消费（电量查询 + 交直流事件）承载首验，让最危险的 shim 行为变更先过 SNI 托盘回归关；B6（休眠唤醒 + 锁屏）、B7（网络）退化为纯 AddMatch 增量；B8 收口文档与真机复验。全程硬约束：shim 只做 ABI 翻译无业务逻辑；任何 moon.pkg 不写链接参数（scripts/prebuild.py 全权托管）；协议级互操作一律真总线验证；真机 GUI 与电源/网络行为由用户执行；踩坑每批同批回写 docs/zh/adaptation.md 与 docs/adaptation.md。

关键决策（相对 TODO 批次策略的调整与评审裁决）：

1. **P3 不并 DBus 套系**：其 Linux 方案本就不依赖 traybus（纯 MoonBit 写 .desktop + 两个最小 shim ABI），独立成批更快，与 B1 可并行。
2. **P5 的「yue 层定时器轮询规避 shim 单槽」让位于 B5 一次性多 fd 改造**：轮询仅留作 shim 改造受阻时的回退，不进主路径。
3. **P10 与 P11 同批**：共享 UPower 服务与系统总线基建，用户一次拔插同时验查询与事件。
4. **P1/P2 的 API 草案分歧按 P2 形态裁决**：`SingleInstance::claim / is_supported / on_activate / wake_existing`；P1 原案「第二实例立即退出」作废，改为先 wake_existing 再退出。
5. **Windows 消息窗口基座前移进 B1**：避免 on_activate 在 Windows 侧静默不触发、showcase 演示段沦为死控件；B4/B6 的电源消息窗口沿用其模式（各自建窗）。
6. **链接清单唯一改动 = B6 的 wtsapi32.lib**：两份清单同提交追加，prebuild 仍全权托管、任何 moon.pkg 仍不写 link 段；动态加载（LoadLibraryW）记为回退但须新写 loader 模式（仓内无 LoadLibraryW 先例）。
7. **错误枚举一域一名**，照 TrayError 样板（yue/error.mbt:4-20），不预收敛统一 SystemError 家族（评估留 B8）。
8. **TODO.md 冲突验收列随批修订**：P1（TODO.md:124）、P2（:127）、P6（:145），B8 按修订后清单复验。
9. **每批含 shim 改动的批次，把「回填本机 vendored 库 + vendor-* 出包完成」写成本批 Windows 真机 gate 的前置**（docs/zh/adaptation.md:25 硬性要求）。
10. **降级验收不依赖 root**：本环境禁 sudo（实测 `sudo -n true` 退出 1），改用 dbus-run-session 私有总线 + 环境变量转发，或用户真机执行。
11. **DBUS_SYSTEM_BUS_ADDRESS 解析失败必须显式 Err、绝不静默回退默认 socket**：否则降级 gate 会连回真有 UPower/NM 的总线而假失败。
12. **命令一律写具体示例包路径**：`examples/` 下无 moon.pkg（实测 find 为空），合法形式为 `moon build examples/showcase` 等 per-example。

## 2. 批次总览表

| 批次 | 主题 | 包含项 | 前置依赖 | 验收门（摘要） |
|---|---|---|---|---|
| B1 | 单实例与二次唤起 | P1、P2 | 无 | moon check/test 零错误零警告 + `moon build examples/showcase`；回复码映射/Wake 分发 wbtest；真总线 dbus-monitor 抓 RequestName/Wake；三桌面与 Win10/11 双开（用户执行）；vendor-* 出包前置；TODO P1/P2 验收列修订 |
| B2 | 开机自启动 | P3 | 无（可与 B1 并行） | moon check/test；.desktop 转义/路径单测；重启拉起与 reg query（用户执行）；desktop-file-validate；冒烟后 disable 复位 |
| B3 | 打开外部程序与文件 | P7、P8 | 无 | moon check/test；file_uri 单测；用户侧一条命令自抓自发 dbus-monitor；ShowItems 实调用与 strace argv（用户执行）；三桌面/Win 选中文件 |
| B4 | 屏幕常亮与用户空闲 | P6、P9 | 无 | moon check/test；xprintidle 数值对照 ±2s；真总线抓 Inhibit/UnInhibit；不熄屏与 powercfg /requests（用户执行）；TODO P6 验收列修订 |
| B5 | 系统总线基建 + 电源查询与事件 | P10、P11 | 无（自承载共享基建，B6/B7 的前置） | moon check/test；wire 'd' roundtrip；多 fd 改造 SNI 回归（硬门槛）；私有总线降级验收（不依赖 root）；笔记本拔插（用户执行）；解析失败显式 Err 验收 |
| B6 | 休眠唤醒与锁屏解锁 | P4、P5 | B5（基建）；B1（消息窗口模式 + Wake 分发不得被破坏） | moon check/test；真总线抓 logind PrepareForSleep/Lock/Unlock；休眠唤醒与 Win+L（用户执行）；wtsapi32 双清单改动的 Windows 链接回归（用户/CI）；B1 Wake wbtest 复跑 |
| B7 | 网络在线状态 | P12 | B5（基建）；B1（分发链约束） | moon check/test；归一化纯函数测试；宿主机冒烟；私有总线 NM 降级验收；断网/联网与飞行模式（用户执行） |
| B8 | 收口：复验与中英文档 | P14 | B1-B7 全部 | moon check/test + `moon build examples/showcase`；components.md 中英「系统集成」节；adaptation 中英最终回写；TODO 终对齐；三桌面/Win10-11 复验（用户执行）；P13 后置说明 |

## 3. 每批详情

### B1 单实例与二次唤起（P1/P2）

**目标**：使用方零平台感知——同一 `SingleInstance` API 跨 Linux/Windows，第二实例检出已有实例后先唤醒首实例再退出；首实例 on_activate 收到第二实例命令行参数（双平台对称）。

**涉及文件与层**：
- `yue/traybus/instance.mbt`（拟新增）：RequestName/ReleaseName 同包封装 + NameClaim 枚举 + 回复码→结果纯函数映射 + 带超时清理的同步调用变体；Wake 构造与应答。
- `yue/traybus/bus.mbt`（修改）：`Conn::handle` 的 kind==1 分支（yue/traybus/bus.mbt:485-487）插 Wake 分发——今天入站调用一律进 `handle_call`（yue/traybus/sni.mbt:579），兜底 `reply_error` UnknownMethod（yue/traybus/sni.mbt:688-693），没有任何分支接收 Wake；wire 编解码层零改动（`build_call` 已带 DESTINATION，yue/traybus/wire.mbt:501-511）。
- `yue/traybus/moon.pkg`（修改）：targets native 列表增列（照 yue/traybus/moon.pkg:6-14）。
- `yue/singleinstance.mbt`（拟新增）：统一 API、平台分派（照 yue/app.mbt:30 的 `platform()`）、app_id 合法性预校验、结果归一。
- `yue/singleinstance_wbtest.mbt`（拟新增）：回复码映射与 key 合法性纯函数测试。
- `yue/error.mbt`（修改）：新增 `SingleInstanceError` 枚举 + Show impl（照 yue/error.mbt:4-20）。
- `yue/ffi.mbt`（修改）：新增 Windows ABI extern（#borrow 约定见 yue/ffi.mbt:1-8；出参形状照 `ffi_tray_new`，yue/ffi.mbt:1732）。
- `shim/yue_mbt.cpp`（修改）：五个 Windows ABI + message-only 窗口（自有 WNDPROC/窗口类，类名由 app_id 派生）+ WM_COPYDATA + PostTask 蹦床（蹦床原语照 `yue_mbt_post_task`，shim/yue_mbt.cpp:3474；static 一次性守卫照 `EnsureToastAumid`，shim/yue_mbt.cpp:3631-3632；UTF-8→UTF-16 复用 `base::SysUTF8ToWide`，shim/yue_mbt.cpp:2144）；非 Windows 分支给桩（照 shim/yue_mbt.cpp:4314-4331）。
- `shim/include/yue_mbt.h`（修改）：声明新 ABI（声明区体例见 shim/include/yue_mbt.h:1-13：UTF-8 进出、成败经 int32_t* 出参）。
- `examples/showcase/pages_system.mbt`（修改）：「系统集成」页（`page_system`，examples/showcase/pages_system.mbt:38；滚动骨架 :271）补单实例演示段。
- `TODO.md`（修改）：P1 验收列（TODO.md:124）改为「先 wake_existing 唤起再退出」；P2 验收列（TODO.md:127）删除「参数透传后置」。

**命令级验收**（工作流/批次执行者运行；本计划未运行）：
- `moon check && moon test` 全仓零错误零警告；`moon build examples/showcase` 通过。
- wbtest 覆盖：RequestName 回复码映射（1=PRIMARY_OWNER / 2 / 3=EXISTS / 4=ALREADY_OWNER / 未知码）、app_id 预校验、入站 Wake method_call → on_activate 触发 + RETURN 应答的分发往返。

**真总线验证（助手宿主机 Ubuntu 24.04 + X11 + XFCE 可执行）**：`dbus-monitor --session` 抓第二实例 RequestName（dest=org.freedesktop.DBus、签名 "su"、回复 u=3）与 Wake method_call（dest=应用总线名、member=Wake）+ 首实例 RETURN；SIGKILL 首实例后第三实例可 claim（回复 1）。

**用户真机验证清单（用户执行）**：
- XFCE/GNOME/KDE 三桌面双开：第二实例先唤醒首实例（含最小化态恢复并置前）再退出；kill -9 首实例后重启可 claim。
- Win10/11 主路径：双开后首实例 on_activate 收到第二实例命令行参数（WM_COPYDATA 透传）且首实例在回调内自置前成功；覆盖资源管理器双击与终端启动两种前台权限场景；showcase 演示段为活控件。
- Win10/11 兜底路径：首实例消息窗口不可达场景（旧构建混跑）下，第二进程经 FindWindowW(标题) 查找置前仍成功；主路径自置前因前台互斥失败时兜底必须成功。
- 本批 Windows 真机项以 vendor-* 出包完成（或用户本机 CMake 构建）为前置；未出包记「未实现」不得记通过。

**回写与提交**：完成即 `git commit` 并推送 origin。踩坑同批回写 docs/zh/adaptation.md 与 docs/adaptation.md（中英两份）：回复码实测结论（3=他实例持有才是「已有实例」、4=本连接已持有为幂等）、flags=4（DO_NOT_QUEUE）必须性、`Local\` 命名空间与同进程二次 CreateMutexW 幂等、call_sync 超时 pending 清理、Wake 的 path/interface 命名、Windows 实例消息窗口类名约定、置前主路径/兜底口径、消息窗口为仓内首例自有 WNDPROC 的建窗线程约束。

### B2 开机自启动（P3）

**目标**：Linux 写/查/删 `$XDG_CONFIG_HOME/autostart/<id>.desktop`，Windows 写 HKCU Run 键；`Autostart::is_supported / is_enabled / enable / disable` 统一语义，macOS 显式 Unsupported。

**涉及文件与层**：
- `yue/autostart.mbt`（拟新增）：.desktop 生成/解析/转义、目录回退链、平台降级；文件读写复用 `read_text_file` / `write_text_file`（yue/dialog.mbt:80、yue/dialog.mbt:92）。
- `yue/error.mbt`（修改）：新增 `AutostartError { Unsupported; NoExecutablePath; IoFailed(String) }`。
- `yue/ffi.mbt`（修改）：`ffi_exe_path` / `ffi_remove_file` / `ffi_autostart_set` / `ffi_autostart_get` / `ffi_autostart_remove` 五个 extern。
- `yue/moon.pkg`（修改）：`moonbitlang/core/env` 从 for "wbtest" 提升为常规 import（yue/moon.pkg:7-9）。
- `shim/yue_mbt.cpp`（修改）：`yue_mbt_exe_path`（Linux readlink("/proc/self/exe")；Windows `GetModuleFileNameW`）、`yue_mbt_remove_file`、三个注册表 ABI（`RegCreateKeyExW`/`RegSetValueExW` 照 shim/yue_mbt.cpp:3654/:3658 配方）；macOS 分支 -1000 哨兵。
- `shim/include/yue_mbt.h`（修改）：五个 ABI 声明。
- `examples/showcase/pages_system.mbt`（修改）：自启动开关演示段。
- `docs/autostart.md`、`docs/zh/autostart.md`（拟新增）+ 两份 README 索引表各加一行。

**命令级验收**：`moon check && moon test` 零错误零警告；wbtest 覆盖 .desktop Exec 转义（空格/双引号/$/反斜杠/中文）、目录三态拼装（XDG_CONFIG_HOME 有/空串/未设 + HOME 兜底）、Hidden=true 判未启用、app_id 合法性。

**用户真机验证清单（用户执行）**：
- Linux XFCE/GNOME/KDE：enable 后重新登录或重启自动拉起，disable 后不拉起；含空格目录安装下 `desktop-file-validate` 通过且能拉起。
- Win10/11：enable 后重启拉起；`reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v <app_id>` 见值；disable 后值消失。
- 助手宿主机冒烟（豁免范围）：`moon run examples/showcase` 开关段不崩，真实写 ~/.config/autostart，冒烟后必须 disable 复位。
- 本批 Windows 真机项以 vendor-* 出包完成为前置。

**回写与提交**：完成即 commit 并推送。回写 adaptation 中英两份：exe 路径时效（AppImage/wine 下 /proc/self/exe 指挂载点临时路径则自启动失效）、环境变量回退链、Run 键可被组策略禁用/自启动目录可被清理工具的边界。

### B3 打开外部程序与文件（P7/P8）

**目标**：`open_url(url)` 与 `reveal_in_file_manager(path)` 单入口 + 单错误枚举；Linux 优先 FileManager1 ShowItems，不在线回退 spawn xdg-open 打开父目录；Windows ShellExecuteW / explorer /select。

**涉及文件与层**：
- `yue/system.mbt`（拟新增）：open_url + reveal_in_file_manager 语义归一。
- `yue/traybus/filemanager.mbt`（拟新增）：`filemanager_available()`（NameHasOwner，照 yue/traybus/sni.mbt:140-158）、`show_items`（call_sync "ass"，照 yue/traybus/bus.mbt:272-292）、`file_uri` 百分号编码纯函数。
- `yue/traybus/sys.mbt`（修改）：新增 `sys_spawn_detached` / `sys_getcwd` extern（native 门控照 yue/traybus/moon.pkg:6-14）。
- `shim/yue_mbt.cpp`（修改）：Linux `posix_spawnp`/getcwd；Windows `yue_mbt_win_reveal_file`（ShellExecuteW + /select）；`yue_mbt_open_url` 双平台（Linux `g_spawn_async` 直传 argv 不经 shell）。
- `shim/include/yue_mbt.h`、`yue/ffi.mbt`（修改）：声明与 extern。
- `yue/error.mbt`（修改）：`OpenUrlError` + `FileManagerError`。
- `examples/showcase/pages_system.mbt`（修改）：打开外部演示段。

**命令级验收**：`moon check && moon test` 零错误零警告；file_uri 百分号编码与错误映射纯函数测试通过；助手宿主机冒烟（最小入口调 open_url 后进程存活、退出行为正常；不主动执行会产生真实弹窗的调用）。

**真总线验证**：会话总线 FileManager1 ShowItems 的线路层（DESTINATION/对齐/长度前缀）比对——用户执行一条命令自抓自发：`dbus-monitor --session "type='method_call',destination='org.freedesktop.FileManager1'" > /tmp/p8.log 2>&1 &`，触发应用操作后 kill 抓包进程，日志交助手与单测输出比对（本宿主已实测 org.freedesktop.FileManager1 NameHasOwner=true）。

**用户真机验证清单（用户执行）**：
- `gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "['<file_uri 单测输出>']" ""` 观察 Thunar 是否接受编码结果；`strace -f -e trace=execve` 抓 xdg-open 子进程并断言 argv[1] 与传入 URL 逐字节一致（证明不经 shell）。
- XFCE(Thunar) 选中普通文件/含空格中文名文件/目录各一次；GNOME(Nautilus)/KDE(Dolphin) 各一次；无 FileManager1 环境验证回退 xdg-open 打开父目录；Win10/11 explorer /select（空格/中文/逗号各一）；边界 URL（query &?=%、mailto:）双平台不得静默失败；退出 GUI 后 ps 查无僵尸/fd 残留。
- 本批 Windows 真机项以 vendor-* 出包完成为前置。

**回写与提交**：完成即 commit 并推送。回写 adaptation 中英两份：URI 百分号转义实测（Thunar 对 raw path 接受度）、回退路径选中态丢失语义、双平台不存在路径行为差异、Ok 只表示「已交给系统」的语义边界。

### B4 屏幕常亮与用户空闲（P6/P9）

**目标**：`idle_seconds()` 双精度秒（阈值判定留给调用方）；`KeepAwake::enable/release/is_supported` 屏幕常亮，Linux DBus 抑制服务、Windows SetThreadExecutionState。

**涉及文件与层**：
- `yue/idle.mbt`（拟新增）：idle_supported / idle_seconds + 降级语义。
- `yue/keepawake.mbt`（拟新增）：KeepAwakeError / KeepAwake / enable / release / is_supported / keep_awake_active，platform() 分发（yue/app.mbt:30）。
- `yue/traybus/inhibit.mbt`（拟新增）：候选表 + NameHasOwner 探测（照 yue/traybus/sni.mbt:140-158）+ Inhibit("ss")/UnInhibit("u") call_sync（照 yue/traybus/bus.mbt:272-292）。
- `shim/yue_mbt.cpp`（修改）：Linux dlopen libXss.so.1 + XScreenSaverQueryInfo（WAYLAND_DISPLAY 探测）；Windows GetLastInputInfo + GetTickCount64；`yue_mbt_win_keep_awake_enable/restore`（ES_CONTINUOUS|ES_DISPLAY_REQUIRED，返回上一状态）。
- `shim/include/yue_mbt.h`、`yue/ffi.mbt`（修改）。
- `yue/error.mbt`（修改）：`IdleError` + `KeepAwakeError`。
- `examples/showcase/pages_system.mbt`（修改）：空闲秒数与常亮开关演示段。

**命令级验收**：`moon check && moon test` 零错误零警告。数值对照（助手宿主机）：静止 10s 后 xprintidle（毫秒）与 idle_seconds() 差值 ≤2s；动鼠标后立即 <1s；`env -u DISPLAY` 与 `WAYLAND_DISPLAY=wayland-0` 两种环境均得 Err(Unsupported) 不崩。

**真总线验证（助手宿主机）**：`dbus-monitor --session` 抓 Inhibit(ss)→u cookie 与 UnInhibit(u 同 cookie) 往返一致（本机实测 org.xfce.ScreenSaver 在线、org.freedesktop.ScreenSaver 未被持有）。

**用户真机验证清单（用户执行）**：
- XFCE 息屏设 1 分钟：启用后 ≥2 分钟不熄、解除后 1 分钟内熄；GNOME/KDE 先 NameHasOwner('org.freedesktop.ScreenSaver') 实测再重复 XFCE 验收，为 false 则期望 is_supported()==false 且 enable 返回 Err(Unsupported)；笔记本 Modern Standby 机型记录 SetThreadExecutionState 是否生效（不生效走 PowerCreateRequest 兜底，结论回写）。
- Win10/11：启用后 `powercfg /requests` 出现 DISPLAY 相关请求，到息屏时间不熄；禁用后 requests 消失恢复熄屏。
- 本批 Windows 真机项以 vendor-* 出包完成为前置。
- TODO.md P6 验收列（TODO.md:145）随批修订：以 xprintidle 为数值基准（xset q 不含当前空闲读数，不能当基准）。

**回写与提交**：完成即 commit 并推送。回写 adaptation 中英两份：XSS dlopen 规避 libxss-dev 的理由、XWayland idle 虚高与 WAYLAND_DISPLAY 探测口径、三桌面抑制服务名分歧（服务名以真实在线为准）、锁屏不算重置 idle 的口径。

### B5 系统总线基建 + 电源查询与事件（P10/P11）

**目标**：一次完成共享基建并以最薄消费首验——shim 多 fd 分发表、connect_unix 拆分、系统总线独立连接、信号订阅泛化、pending 修复、最小断线自愈；落地 Battery 查询与 on_power_source_change 事件。

**涉及文件与层**：
- `yue/traybus/bus.mbt`（修改）：connect_session（yue/traybus/bus.mbt:108-180）拆出 `connect_unix(path)`；g_conn（:19）之外新增系统总线连接与连接注册表；on_bus_ready 从 ignore(fd)（:92）改按 fd 路由；Conn 增 watchers 分发表，handle 的 kind==4 分支（:459-483）保持「NameOwnerChanged 特判在前、注册表分发在后」；call_sync 超时摘除 pending（:283-292 仅在 :449 收应答时 remove 的滞留）；Disconnected（:480-483）改最小自愈（经 yue/app.mbt:41 post_task 延迟重连重放 AddMatch）。
- `yue/traybus/sys.mbt`（修改）：新增 `sys_unwatch_fd`、`sys_f64_from_bits` / `sys_f64_to_bits` extern。
- `shim/yue_mbt.cpp`（修改）：`g_mbt_fd_cb` 单槽（:4296，覆盖写 :4305）扩为 fd→cb 分发表，蹦床原型不变（mbt_fd_source_cb 已回传 fd，:4298-4300），新增 unwatch；非 Linux 同步补桩（照 :4314-4331）；`yue_mbt_win_power_status`；f64 位转换两个纯计算入口（static_assert(sizeof(double)==8)）。
- `yue/traybus/wire.mbt`（修改）：补 'd' 双精度，八处联动——DVal（:10-24）、Sig（:39-54）、sig_align（:27-36）、parse_one_sig（:81-135）、sig_of（:155-179）、sig_char（:688-713）、encode（:295-353，唯一静默兜底在 :351）、decode_in（:608-685）。
- `yue/traybus/upower.mbt`（拟新增）：system_bus_path、Properties.GetAll/Get、AddMatch PropertiesChanged 规则（arg0='org.freedesktop.UPower'，必须以方法调用发出，教训见 yue/traybus/sni.mbt:121-125）。
- `yue/power.mbt`（拟新增）：BatteryInfo / Battery::is_supported / query / PowerSource / power_event_supported / on_power_source_change + 平台路由。
- `yue/error.mbt`（修改）：`PowerError { Unsupported; QueryFailed(String) }`（P10/P11 合并）。
- `yue/ffi.mbt`、`shim/include/yue_mbt.h`（修改）：extern 与声明。
- `yue/traybus/wire_wbtest.mbt`、`yue/traybus/upower_wbtest.mbt`（拟新增/修改）：'d' roundtrip（含 a{sv} 内含 Percentage 的真实形状）与归一化纯函数测试。
- `yue/traybus/moon.pkg`（修改）：targets 增列。

**命令级验收**：`moon check && moon test` 零错误零警告；多 fd 改造回归（硬门槛）：助手宿主机 `moon run examples/showcase`，托盘增删/菜单点击正常，验证第二条（系统总线）连接不覆盖会话总线的 fd 监视；用户在其桌面复核面板图标与菜单。

**真总线验证（助手宿主机）**：`dbus-monitor --system` / `busctl monitor` 抓 UPower GetAll/Get 应答，无重发无超时（本宿主机已实测 org.freedesktop.UPower :1.100 在线、/run/dbus/system_bus_socket 存在、DisplayDevice IsPresent=false）。

**降级验收（不依赖 root，三条等价）**：
1. 助手可执行：`dbus-run-session -- sh -c 'DBUS_SYSTEM_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS <待测程序>'`（该工具无 --print-address，用会话内环境变量转发；私有总线地址为 unix:path=/tmp/dbus-* 文件 socket，与解析逻辑兼容）——总线上无 UPower，query() 返回 Err(Unsupported)，不崩不静默。
2. wbtest 纯函数覆盖 NameHasOwner=false 与 GetAll 错误应答（ServiceUnknown）→ Err(Unsupported) 归一化分支。
3. 用户真机可选 `sudo systemctl stop upower` 后复验同一行为。
4. 解析失败行为验收：DBUS_SYSTEM_BUS_ADDRESS 已设置但解析不到合法 unix:path= 时（含多地址串），必须显式 Err 带原文诊断，绝不允许静默回退默认 socket（否则连回真有 UPower 的总线，预期假失败）。

**用户真机验证清单（用户执行）**：
- 笔记本拔电源一次、插回一次：应用回调顺序 Battery→Ac 与 dbus-monitor 抓的 PropertiesChanged 时刻对齐；query() 读数与 `upower -i /org/freedesktop/UPower/devices/DisplayDevice` 及系统托盘一致（±1%，注 upower CLI 取整口径）。
- Win10/11：GetSystemPowerStatus 路径与托盘电量对照；台式机（无电池）返回 Ok(None)。
- 本批 Windows 真机项以 vendor-* 出包完成为前置。

**回写与提交**：完成即 commit 并推送。回写 adaptation 中英两份：系统总线真实 socket 名、多 fd 改造与回归口径、'd' 八处联动经 dbus-monitor 复核、f64 位转换进 shim 的取舍（core 无 Double::to_bits/from_bits）、Windows ACLineStatus/百分比 255 语义损失、DBUS_SYSTEM_BUS_ADDRESS 分隔符与解析失败行为实测。

### B6 休眠唤醒与锁屏解锁（P4/P5）

**目标**：logind PrepareForSleep 与 Session Lock/Unlock 两条 AddMatch 挂到 B5 基建；Windows 电源消息窗口（PBT_APMSUSPEND/RESUME）+ WTS 会话变更；`on_suspend_resume` / `session_lock_watch` 统一 API。

**涉及文件与层**：
- `yue/traybus/logind.mbt`（拟新增）：NameHasOwner 探活 + 两条 AddMatch + 信号分发（复用 B5 的 watchers 表）。
- `yue/traybus/bus.mbt`（复用 B5 改动，不重复改）。
- `yue/power.mbt`（修改）：追加 SleepEvent / suspend_resume_supported / on_suspend_resume。
- `yue/session.mbt`（拟新增）：session_lock_is_supported / session_lock_watch。
- `yue/error.mbt`（修改）：`SystemError { Unsupported; Message(String); Disconnected }`（P4/P5 合并）。
- `shim/yue_mbt.cpp`（修改）：电源 message-only 窗口（模式复用 B1：自有 WNDPROC + PostTask 抛回主循环，防重入配方照 PopoverMouseHook，shim/yue_mbt.cpp:2962）+ WTSRegisterSessionNotification + `yue_mbt_win_session_watch` 蹦床（closure-first，约定见 shim/include/yue_mbt.h:12）。
- `scripts/prebuild.py`（修改）：WINDOWS_LINK_LIBS（:44-56）追加 wtsapi32.lib——全计划唯一链接清单改动。
- `shim/CMakeLists.txt`（修改）：target_link_libraries（:139-145）同步追加 wtsapi32.lib（必须同提交，Windows 清单无「与 CMakeLists 一致」注释背书——该注释在 scripts/prebuild.py:32 挂的是 Linux 清单）。
- `shim/include/yue_mbt.h`、`yue/ffi.mbt`（修改）。
- `examples/showcase/pages_system.mbt`（修改）：休眠/唤醒与锁屏计数演示段。

**命令级验收**：`moon check && moon test` 零错误零警告；PrepareForSleep(b) 信号往返与按 (interface,member) 注册表分发单测通过；B1 的 Wake 分发 wbtest 复跑（防 B5 分发链重构破坏）。

**真总线验证（助手宿主机起抓包 + 用户触发）**：`dbus-monitor --system "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1'"` 抓 PrepareForSleep 与 Session Lock/Unlock，与应用回调时刻、参数逐一对齐；dbus-monitor 应见两条 AddMatch 规则被总线接受（本机已实测 BecomeMonitor 被拒回退 eavesdropping 仍可收系统总线信号）。

**用户真机验证清单（用户执行）**：
- XFCE 合盖/菜单休眠一次 + 唤醒一次；休眠数分钟后唤醒确认最小自愈后订阅仍有效；Win+L 锁屏与登录解锁各一次；GNOME/KDE 至少各一次（走系统总线，与桌面无关）；xfce4-screensaver --lock 对照 Lock/Unlock 各一次。
- Windows 休眠一次（合盖或 `rundll32.exe powrprof.dll,SetSuspendState 0,1,0`）+ 唤醒一次；若 modal 场景 message-only 窗口漏 PBT_APMSUSPEND，回退 PowerRegisterSuspendResumeNotification（线程池回调 + PostTask）并在 adaptation.md 记结论。
- Windows 链接回归：wtsapi32.lib 双清单追加后 `moon build examples/showcase` 在 Windows 宿主链接通过（LNK2019 不得出现）；vendored windows-x64 库随 vendor-* 出包拉齐。
- 降级验收：无 systemd-logind 的容器 suspend_resume_supported()==false、watch 返回结构化 Err，不静默无回调。

**回写与提交**：完成即 commit 并推送。回写 adaptation 中英两份：快速挂起唤醒可能连收两条 Resume（库内不去抖）、唤醒后网络/DBus 未就绪需延迟重试提示、锁屏工具不调 logind 则事件不到（记桌面环境）、多会话信号归属限制、wtsapi32.lib 双清单同步的决策与回退方案、消息窗口派发假设的 B1→B6 复验结论。

### B7 网络在线状态（P12）

**目标**：Linux NM 属性查询 + StateChanged/PropertiesChanged 订阅（信号驱动）；Windows NLM 查询 + MoonBit 层 set_timer 轮询；归一为 NetworkStatus 两值。

**涉及文件与层**：
- `yue/traybus/netmon.mbt`（拟新增）：NameHasOwner 探测、Properties.Get 读 State/Connectivity、AddMatch 订阅、原始码→NetworkStatus 归一化纯函数、on_status_change 回调表。
- `yue/online.mbt`（拟新增）：NetworkStatus / NetworkError、Network::is_supported / status / on_status_change；Windows 轮询（set_timer，yue/app.mbt:62）+ ffi 查询并归一。
- `yue/ffi.mbt`（修改）：`ffi_win_connectivity(out : Ref[Int])`。
- `shim/yue_mbt.cpp`（修改）：Windows NLM COM（CoInitializeEx 文件级 static 守卫 + CoCreateInstance + GetConnectivity）；非 Windows 补返回 0 桩。
- `shim/include/yue_mbt.h`（修改）。
- `yue/error.mbt`（修改）：`NetworkError { Unsupported; QueryFailed(String) }`。
- `yue/online_test.mbt`（拟新增）：归一化纯函数与 wire 层 "v"(u) 解析往返测试。
- `yue/traybus/moon.pkg`（修改）：targets 增列。

**命令级验收**：`moon check && moon test` 零错误零警告；归一化纯函数测试（NM State 70/50/20/0 × Connectivity 4/2/1、NLM 位掩码 0x24/0x02/0x00）与 NM 属性应答 "v"(u) 入站解析往返全绿；助手宿主机冒烟：最小 main 调 Network::status() 打印，进程存活、退出正常（预期 Ok(Online)，依据本机实测 State=70/Connectivity=4）；首次 status() 为同步建缓存，最坏阻塞 ≤1500ms（call_sync 超时，yue/traybus/bus.mbt:287），口径写进使用文档，回调与定时器内只读缓存、严禁 call_sync。

**真总线验证（助手宿主机）**：`timeout 8 dbus-monitor --system "type='signal',sender='org.freedesktop.NetworkManager',interface='org.freedesktop.NetworkManager',member='StateChanged'"` 与 PropertiesChanged 双开抓包，与事件回调时刻对照一次。

**降级验收（不依赖 root）**：助手可执行 dbus-run-session 私有总线转发（同 B5 手法），总线上无 NM 时 is_supported()==false 且 status()==Err(Unsupported)，解析失败显式 Err 不回退；用户真机执行 `systemctl stop NetworkManager` 后同一行为，重启 NM 后无需重启应用恢复（最小自愈）。

**用户真机验证清单（用户执行）**：
- Linux：拔网线/关 Wi-Fi 与恢复各一次，status() 切换且 on_status_change 各触发一次，与 nmcli general 一致；同机复核托盘不回归（多 fd 改造的间接回归面）。
- Win10/11：禁用/启用网卡或飞行模式，轮询 5s 内切换、回调触发；仅局域网（NLM_SUBNET）归 Offline；查询失败给 QueryFailed/Unsupported 不 panic。
- 本批 Windows 真机项以 vendor-* 出包完成为前置。

**回写与提交**：完成即 commit 并推送。回写 adaptation 中英两份：CONNECTED_LOCAL/SITE、Connectivity LIMITIED/PORTAL 与 NLM SUBNET/LOCALNETWORK 一律归 Offline 的语义决策、captive portal 不给独立 enum 值的理由、NLM COM apartment 真机结论、5s 轮询延迟口径与「首次同步查询 ≤1.5s」口径。

### B8 收口：复验与中英文档（P14）

**目标**：components.md 中英「系统集成」节、showcase 演示补齐、adaptation 中英最终汇总、TODO 终对齐、P13 后置说明。

**涉及文件与层**：
- `docs/zh/components.md`、`docs/components.md`（修改）：新增「系统集成」节（签名表 + 参数表 + 示例 + 跨平台差异表），置于托盘节之后，口径与托盘节一致（Err(Unsupported)/is_supported）。
- `examples/showcase/pages_system.mbt`（修改，若未随 B1/B2/B3 交付则本批补齐）。
- `docs/zh/adaptation.md`、`docs/adaptation.md`（修改）：三桌面版本号、Windows 版本、各 DBus 抓包结论按「环境+现象+根因+修复+验证方式」补齐。
- `TODO.md`（修改）：P1(:124)/P2(:127)/P6(:145) 已随 B1/B4 修订，本批复核 P3-P12 全部验收列与落地行为一致。
- `docs/zh/plan-system-integration.md`（本文档，随收口批更新状态）。

**命令级验收**：`moon check && moon test` 零错误零警告；`moon build examples/showcase` 通过；启动冒烟（进程存活 + 退出行为，烟测口径见 docs/zh/adaptation.md 构建小节）。

**用户真机验证清单（用户执行）**：
- showcase「系统集成」页三段演示双平台视觉与交互检查；后端缺失时结构化降级提示可见（如无托盘、无 UPower）；Windows 侧单实例演示段为活控件。
- 修订后 TODO.md P1-P12 验收列在 XFCE（主链路）/GNOME/KDE 与 Win10/11 逐项过（含休眠/唤醒、锁屏/解锁、拔插电源、断网/联网、双开、重启拉起）；Windows ABI 未落地或 vendor 未出包的项记「未实现」不得记通过。

**回写与提交**：完成即 commit 并推送。回写检查（提交门槛）：三桌面/Win/DBus 结论进 docs/zh/adaptation.md 与 docs/adaptation.md 同一提交（中英两份）；P13 在最终文档留一节「后置」说明，不实现、不排批。

## 4. 各项实施方案摘要

### P1 防多开（单实例）

- **Linux 路由**：纯 MoonBit（traybus 包内），复用进程级会话连接 g_conn（yue/traybus/bus.mbt:19，不存在则经 connect_session 兜底建连，:108-180）；同步调用向 org.freedesktop.DBus 发 RequestName(name, flags=4 DO_NOT_QUEUE)，签名 "su"、回复单参 "u"。本机真实会话总线实测：首 claim=1(PRIMARY_OWNER)、同连接再 claim=4(ALREADY_OWNER)、独立进程并发 claim=3(EXISTS)。3=他实例持有（才有「已有实例」）、4=本连接已持有（同进程幂等）。flags 必须带 4，否则第二实例拿到 2 会排队等待而非立即退出。
- **Windows 路由**：shim 新增 `yue_mbt_win_named_mutex(name_utf8, first_instance)`——CreateMutexW(`Local\` + sanitized) + GetLastError()==ERROR_ALREADY_EXISTS 判定；文件级 static 句柄 + 已持 key 记录做同进程幂等（否则第二次 CreateMutexW 同名会误报 ALREADY_EXISTS）；key sanitize（Win32 对象名仅 '\\' 作分隔）并经 UTF-8→UTF-16（复用 base::SysUTF8ToWide，shim/yue_mbt.cpp:2144）；非 Windows 桩返回 -1。必须用 `Local\`：标准用户无 SeCreateGlobalPrivilege。
- **MoonBit API 草案**：`pub fn SingleInstance::claim(app_id : String) -> Result[SingleInstance, SingleInstanceError]`（错误枚举与 P2 合并：InvalidAppId/AlreadyOwner/AlreadyRunning/Unsupported/DeliveryFailed）；app_id 须合法 DBus 总线名（点分层段、元素 [A-Za-z0-9_-]、非空、长度），MoonBit 层预校验；同进程同 key 幂等。
- **复用点**：connect_session 全链路（yue/traybus/bus.mbt:108-180）；call_sync 同步泵（:272-292，kind==3 转 Err）；sni_available 的「不存在则连接并缓存」入口形状（:24-36）；NameHasOwner 探测先例（yue/traybus/sni.mbt:140-158）；wire "su"/"u" 签名全覆盖（yue/traybus/wire.mbt:81-135、:155-179）。
- **风险**：回复码语义是最大坑（调研初判有误，已实测纠正）；总线断开只置 alive=false 无重连（yue/traybus/bus.mbt:480-483），休眠唤醒后名字已释放、防多开静默失效——P1 沿用现状并回写，自愈随 B5 统一处理；claim 失败不断开 g_conn（连接进程级共享，SNI 仍要用）。

### P2 二次启动唤起已有窗口

- **Linux 路由**：纯 MoonBit + traybus 复用，零新 extern、零新 fd。第二实例 wake_existing：call_sync(dest=应用总线名, path=/org/moonbitlibyue/Instance, iface=org.moonbitlibyue.Instance, member=Wake, sig='as')——build_call 本就带 DESTINATION（yue/traybus/wire.mbt:501-511），无需动 emit_signal；首实例侧在 Conn::handle 的 kind==1 分支（yue/traybus/bus.mbt:485-487）插 Wake 分发并回应答（今天其兜底是 UnknownMethod，yue/traybus/sni.mbt:688-693）。
- **Windows 路由**：shim 五个 ABI 同批——命名互斥体（与 P1 共享）、实例消息窗口登记（message-only 窗口 + 自注册窗口类，类名由 app_id 派生 + WNDPROC 收 WM_COPYDATA + PostTask 蹦床抛回主循环）、按 app_id 发送唤醒、前台许可 AllowSetForegroundWindow(ASFW_ANY)、查找置前（FindWindowW + IsIconic→SW_RESTORE + SetForegroundWindow，兜底 AttachThreadInput）。消息窗口配方：蹦床原语照 yue_mbt_post_task（shim/yue_mbt.cpp:3474），防重入照 PopoverMouseHook（:2962），static 守卫照 EnsureToastAumid（:3631-3632）。
- **MoonBit API 草案**：`SingleInstance::is_supported()` / `claim(app_id)` / `on_activate(self, cb : (Array[String]) -> Unit)` / `wake_existing(app_id, args)`；置前三件套已现成（Window::activate yue/view.mbt:111、restore yue/methods.mbt:20、is_minimized :26）；on_activate 为全新 API（仓内无 App 级 on_activate，仅 Entry::on_activate yue/button.mbt:131），注册形态照 on_system_theme_change（yue/app.mbt:102）。
- **复用点**：call_sync 与 pending 回配（yue/traybus/bus.mbt:246-292、:441-456）；入站调用契约自检模式（yue/traybus/sni.mbt:579-694）；消息往返单测样板（yue/traybus/wire_wbtest.mbt）。
- **风险**：Windows 前台互斥（非前台进程默认不能置前他人窗口）：缓解链=ASFW_ANY + 主路径首实例自置前 + 兜底标题查找，真机必须覆盖终端启动场景；标题查找残留约束（运行时改标题破坏兜底置前），身份与参数通道走注册类名；唤醒回调运行在 glib fd 主循环栈内，回调内严禁 call_sync（15ms 切片重入 drain，最坏阻塞 1500ms，yue/traybus/bus.mbt:347-362）。

### P3 开机自启动

- **Linux 路由**：纯 MoonBit 为主——写/查/删 $XDG_CONFIG_HOME/autostart/<id>.desktop（环境变量读 @env.get_env_var，需把 yue/moon.pkg:7-9 的 env 从 for "wbtest" 提升为常规 import）；文件读写复用 read_text_file/write_text_file（yue/dialog.mbt:80、:92）；exe 绝对路径与删文件需两个最小 shim ABI（/proc/self/exe 是符号链接，MoonBit 侧 read_text_file 只会读到 ELF 内容而非路径）；语义：enable 写 [Desktop Entry]、is_enabled 判文件存在且未被 Hidden=true 禁用、disable 删文件；Exec 转义与全部判定语义在 MoonBit 层。
- **Windows 路由**：shim 三个注册表 ABI——autostart_set（RegCreateKeyExW 开 HKCU\Software\Microsoft\Windows\CurrentVersion\Run + RegSetValueExW 写 REG_SZ，配方照 shim/yue_mbt.cpp:3654/:3658）、autostart_get（RegGetValueW 定长 buf）、autostart_remove（RegDeleteValueW 保留键）；exe 路径在 shim 内部 GetModuleFileNameW 解析；macOS 分支 -1000 哨兵。
- **MoonBit API 草案**：`Autostart::is_supported()` / `is_enabled(app_id)` / `enable(app_id, display_name, args?)` / `disable(app_id)`；错误 `AutostartError { Unsupported; NoExecutablePath; IoFailed(String) }`。
- **复用点**：platform()（yue/app.mbt:30）与 Tray::is_supported 形状（yue/tray.mbt:31-58）；TrayError 样板（yue/error.mbt:4-20）；文件写亦可经现成 yue_mbt_write_file（shim/yue_mbt.cpp:1456、extern yue/ffi.mbt:542）。
- **风险**：.desktop Exec 两层转义规则仓库零先例，必须三桌面真机拉起验证；exe 路径时效（AppImage/wine 形态自启动失效）；XDG_CONFIG_HOME 空串与未设是两种分支，HOME 也未设必须 Err 而非崩；Run 键可被组策略禁用，失败必须 Err(IoFailed) 不得静默。

### P4 挂起与唤醒事件

- **Linux 路由**：traybus 纯 MoonBit 为主 + B5 的 shim 多 fd 改造。系统总线连接（DBUS_SYSTEM_BUS_ADDRESS → /run/dbus/system_bus_socket → /var/run/dbus/system_bus_socket，本机实测第一条存在；已设置但解析失败显式 Err 不回退）；SASL EXTERNAL + Hello 复用 connect_unix；AddMatch 订阅 org.freedesktop.login1.Manager.PrepareForSleep(b)（必须以方法调用发出，教训见 yue/traybus/sni.mbt:121-125）；信号体只有一个 bool，wire 已支持，无新类型。
- **Windows 路由**：shim 新建 message-only 窗口（HWND_MESSAGE 父 + 自有 WNDPROC，模式复用 B1）+ WNDPROC 收 WM_POWERBROADCAST：PBT_APMSUSPEND→挂起、PBT_APMRESUMEAUTOMATIC/RESUMESUSPEND→唤醒；一律经 PostTask 抛回主循环再 invoke（防重入，配方同 B1）；`yue_mbt_win_power_events_start/stop` 一对 ABI。
- **MoonBit API 草案**：`SleepEvent { Suspend; Resume }` + `suspend_resume_supported()` + `on_suspend_resume(cb) -> Result[Unit, SystemError>`；错误 `SystemError { Unsupported; Message(String); Disconnected }`（与 P5 合并）。
- **复用点**：B5 基建全量；AddMatch 先例（yue/traybus/sni.mbt:121-138）；信号编解码（yue/traybus/wire.mbt:295-353、:608-685）；OS 事件→PostTask 模板（shim/yue_mbt.cpp:2962、:3474）。
- **风险**：message-only 窗口能否被 libyue 主循环 DispatchMessage 派发、模态时是否漏 PBT_APMSUSPEND 未经真机验证（vendor/libyue 仅 include+lib）；漏则回退 PowerRegisterSuspendResumeNotification；快速挂起唤醒可能连收两条 Resume，库内不去抖；唤醒后网络/DBus 可能未就绪，文档提示延迟重试。

### P5 锁屏与解锁事件

- **Linux 路由**：traybus 纯 MoonBit——复用 B5 的系统总线连接与信号订阅表；NameHasOwner 探活 logind 后发两条 AddMatch（org.freedesktop.login1.Session 的 Lock/Unlock，无参信号）；入站按 (interface,member) 注册表分发。本机实测：busctl introspect 确认 .Lock/.Unlock 无参信号存在；xfce4-screensaver 4.18 二进制内含逐字一致的规则串（strings 实测），证明 XFCE 24.04 锁屏链经 logind 广播。
- **Windows 路由**：shim 新增 `yue_mbt_win_session_watch(invoke, closure)`——message-only 窗口 + WTSRegisterSessionNotification(hwnd, NOTIFY_FOR_THIS_SESSION)，WM_WTSSESSION_CHANGE 的 WTS_SESSION_LOCK/UNLOCK 映射为语义码 0/1，WNDPROC 内不动 GUI、经 PostTask 抛回主循环；非 OS_WIN 桩返回 0。需 wtsapi32.lib（全计划唯一链接清单改动）。
- **MoonBit API 草案**：`session_lock_is_supported()` + `session_lock_watch(on_lock, on_unlock) -> Result[Unit, SystemError>`（全局无接收者回调风格，形状照 yue/app.mbt:102）；不提供主动锁屏/解锁，不提供初始锁定状态查询（Windows 无等价干净 API，避免平台差异穿透）。
- **复用点**：B5 系统总线基建；AddMatch 方法调用先例（yue/traybus/sni.mbt:121-138）；蹦床与 PostTask（shim/yue_mbt.cpp:3474）。
- **风险**：Session.Lock/Unlock 无参数，无法按会话区分（多 seat 场景会收到其他会话事件）；并非所有锁屏工具都调 logind，不调则事件不到（验收记录桌面环境）；系统总线只做文件 socket 路径解析，仅 abstract 地址的环境按 Err(Unsupported) 降级；WTS 仅覆盖本会话。

### P6 获取用户空闲秒数

- **Linux 路由**：shim——运行期 dlopen libXss.so.1/libXss.so 双候选调 XScreenSaverQueryInfo（本机实测运行时库在、libxss-dev 缺失，直链会引入新构建期依赖，故 dlopen；scrnsaver.h 缺头时以本地 typedef 镜像结构体，实施时与 /usr/include/X11/extensions/scrnsaver.h 逐字段核对）；XOpenDisplay(NULL) 句柄静态缓存、失效重开；WAYLAND_DISPLAY 置位 → 返回不支持（XWayland 下输入不进 X 服务端，idle 虚高）。
- **Windows 路由**：shim——LASTINPUTINFO + GetLastInputInfo，空闲毫秒 = GetTickCount64() - dwTime（64 位版本规避 49.7 天回绕），换算双精度秒写出参；无一次性初始化、无回调。
- **MoonBit API 草案**：`idle_supported() -> Bool` + `idle_seconds() -> Result[Double, IdleError>`；不设 active/idle 阈值接口（TODO 明确边界，阈值由调用方比较）；无事件回调。
- **复用点**：dlopen 探测先例（shim/yue_mbt.cpp 的 tray 探测配方）；出参约定（shim/include/yue_mbt.h:1-13）；TrayError 样板（yue/error.mbt:4-20）。
- **风险**：XWayland idle 虚高（本宿主机 xprintidle 读数随输入跳变可证）；RDP/注入输入扰动读数（实测 sleep 2s 期间 xprintidle 3117→223ms）；结构体镜像与上游 ABI 漂移；锁屏不重置 idle（两平台一致，使用方需知「锁屏也算空闲」）。

### P7 默认浏览器打开 URL

- **Linux 路由**：shim——`yue_mbt_open_url(url)`，g_spawn_async(nullptr, {"xdg-open", url, nullptr}, G_SPAWN_SEARCH_PATH) 直传 argv 不经 shell（严禁 system()/popen：URL 含 & ? ' " $ 空格会被 shell 二次解析，是本项安全核心）；内部双 fork 防僵尸；找不到 xdg-open 即失败返回。
- **Windows 路由**：同 ABI 的 OS_WIN 分支——ShellExecuteW(nullptr, L"open", url 转 UTF-16, SW_SHOWNORMAL)，返回值 ≤32 判失败并取 SE_ERR_* 码（31=SE_ERR_NOASSOC 即无关联程序）转正返回。
- **MoonBit API 草案**：`open_url(url : String) -> Result[Unit, OpenUrlError>`；`OpenUrlError { Unsupported; InvalidUrl; ExecFailed(Int) }`；url 空白串前置拦截 InvalidUrl；不设 scheme 白名单（由系统注册表/分发数据库路由）；**Ok 只表示「已把请求交给系统默认程序」，不保证浏览器一定弹出**——xdg-open 异步退出码不可观测，不要为观测结果改同步等待（会重蹈 call_sync 15ms 切片轮询阻塞主循环的坑）。
- **复用点**：UTF-8 边界与返回码约定（shim/include/yue_mbt.h:1-13）；glib 已在链接面（g_spawn_async 零链接改动）；Shell32 已在清单（scripts/prebuild.py:44-56）。
- **风险**：无桌面会话/精简容器（无 xdg-utils）时系统侧静默失败，属平台表现差异；g_spawn 默认继承 stderr（xdg-open 报错进控制台，保留便于排障）；真机须验证浏览器关掉后 GUI 仍能干净退出（无僵尸/fd 泄漏）。

### P8 文件管理器打开并选中文件

- **Linux 路由**：traybus 纯 MoonBit——复用会话总线单连接；NameHasOwner(org.freedesktop.FileManager1) 探测在线（本机实测 Thunar :1.27 持有，照 yue/traybus/sni.mbt:140-158）；在线则 call_sync ShowItems 签名 "ass"（uris + startup_id 空串），应答无出参空体即成功，kind==3 由 call_sync 转 Err(error_name)；不在线回退 shim spawn xdg-open 打开父目录（选中态丢失属已文档化降级）。
- **Windows 路由**：shim `yue_mbt_win_reveal_file(path_utf8, ok)`——UTF-8→UTF-16 后拼 explorer.exe 参数 /select,"<path>"（整段引号包裹防逗号/空格歧义，路径内双引号防御性处理），ShellExecuteW 以 "open" 启动，成败经 ok 出参；非 Windows 桩返回 -1。
- **MoonBit API 草案**：`reveal_in_file_manager(path) -> Result[Unit, FileManagerError>` + `reveal_in_file_manager_supported()`；`FileManagerError { Unsupported; InvalidPath; OpenFailed(String) }`；路径归一（空→InvalidPath；相对路径拼 getcwd 补绝对——拟新增 yue_mbt_sys_getcwd；含空格/非 ASCII/#/? 在 Linux 侧百分号编码）。
- **复用点**：call_sync（yue/traybus/bus.mbt:272-292）；NameHasOwner 探测（yue/traybus/sni.mbt:140-158）；'as' 数组签名编解码（yue/traybus/wire.mbt:318-332）；build_call 带 dest（yue/traybus/wire.mbt:501-511）。
- **风险**：URI 转义是最大未实测点（只做了只读 introspect，未发真实调用）——实现批必须真总线验证并回写；不存在路径双平台行为不一致（Thunar 错误框 vs explorer 开最近父级），shim 无 stat ABI，v1 不做 NotFound 归一；同步调用最坏阻塞主循环 1500ms，UI 点击回调里安全，严禁在 DBus 回调内调用。

### P9 屏幕常亮

- **Linux 路由**：traybus 纯 MoonBit——复用会话总线单连接；候选表按序 ['org.freedesktop.ScreenSaver', 'org.xfce.ScreenSaver']（接口名与 service 同名），NameHasOwner 第一个被持有者即后端（真实运行真伪以总线上服务是否在线为准，桌面环境名不参与选择）；Inhibit(app, reason) 签名 "ss" 返回体取 VU32 cookie；UnInhibit("u") 必须带启用时原 cookie。本机实测：org.freedesktop.ScreenSaver NameHasOwner=false、org.xfce.ScreenSaver=true（owner 为 xfce4-screensav）。
- **Windows 路由**：shim 两条 ABI——`yue_mbt_win_keep_awake_enable()`（SetThreadExecutionState(ES_CONTINUOUS|ES_DISPLAY_REQUIRED)，返回上一 execution state，0 即失败）、`yue_mbt_win_keep_awake_restore(previous, ok)`（还原上一状态，成败经 ok 出参）；必须 GUI 主线程调用（线程级状态）。
- **MoonBit API 草案**：`KeepAwakeError { Unsupported; AlreadyActive; Failed(String) }` + `KeepAwake { cookie }` + `enable() -> Result[KeepAwake, KeepAwakeError>` + `release(self)` + `is_supported()` + `keep_awake_active()`；活跃态用全局 Ref[KeepAwake?] 表达（规避 cookie=0 歧义）；单全局抑制，二次 enable 返回 AlreadyActive。
- **复用点**：call_sync（yue/traybus/bus.mbt:272-292）；NameHasOwner 探测（yue/traybus/sni.mbt:141-158）；'u' cookie 线格式全覆盖（yue/traybus/wire.mbt:88 附近 Sig 解析、:163 附近 sig_of、:310 附近编码、:632 附近解码——以符号 grep 定位）；Win32 出参先例与 static 守卫（shim/yue_mbt.cpp:3631-3632）。
- **风险**：三桌面抑制服务名分歧且标准名在 XFCE 实测未持有——GNOME/KDE 值必须真机 NameHasOwner 实测；cookie 是否可能为 0 无规范保证；抑制服务中途退出→UnInhibit 失败透传 Failed，服务重启后须重新 enable；call_sync 最坏阻塞 1500ms，不宜在定时器回调高频调用；Modern Standby 机型可能不生效（PowerCreateRequest 兜底待验证）。

### P10 电量查询

- **Linux 路由**：traybus 纯 MoonBit——B5 基座（connect_unix 拆分 + system_bus_path）上查系统总线 UPower DisplayDevice 的 Percentage(d)/State(u)/IsPresent(b)（Properties.GetAll 一次取回，a{sv} 现有能力直接解）；IsPresent=false → Ok(None)（台式机）；再取 OnBattery 交流标志。本机实测：org.freedesktop.UPower :1.100 在系统总线、IsPresent=false、EnumerateDevices 0 项（台式机，「无电池返回空」用例可直接在本机验证）。查询复用 B5 的系统总线长连（省一次握手），one-shot 方案降为回退。
- **Windows 路由**：shim `yue_mbt_win_power_status(ac_online, percent, charging)`——GetSystemPowerStatus，BatteryFlag&0x80（无电池）→0；BatteryLifePercent>100（255 未知）→-1；否则填出参。返回 1=有电池/0=无电池/-1=查询失败。
- **MoonBit API 草案**：`BatteryInfo { percent : Double; on_ac : Bool; charging : Bool }` + `Battery::is_supported()` + `Battery::query() -> Result[BatteryInfo?, PowerError>`；`PowerError { Unsupported; QueryFailed(String) }`（与 P11 合并）；Ok(None)=无电池，Err(Unsupported)=服务不在线/平台暂无。
- **复用点**：call_sync（yue/traybus/bus.mbt:272-292，ServiceUnknown 判定靠 kind==3 转 Err(error_name)）；a{sv} 解码（yue/traybus/wire.mbt:649-661、:676-683）；f64 位转换经 shim 两个纯入口（core 无 to_bits/from_bits，本轮 grep ~/.moon/lib/core/builtin/double.mbt 0 命中）。
- **风险**：wire 'd' 八处联动（真正静默点只有 encode 兜底 yue/traybus/wire.mbt:351，其余站点编译期/显式失败）；百分比为 double（93.7）而 upower CLI 显示取整——文档须写明对照口径；Windows 255 语义损失必须回写；多电池/UPS 取复合值不做逐设备聚合。

### P11 交流/电池电源切换事件

- **Linux 路由**：traybus 纯 MoonBit——B5 基座上订阅 UPower PropertiesChanged：订阅前先 call_sync Get OnBattery 作后端在线探测（拿不到应答即不在线，返回 Err 供结构化降级——fire-and-forget 的 AddMatch 无法探测后端缺失）；AddMatch 规则 type='signal',sender='org.freedesktop.UPower',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.freedesktop.UPower'；入站解 sa{sv}as 取字典里 OnBattery 项回调 true/false。wire 无需新类型（b/s/a{sv}/as 全覆盖）。
- **Windows 路由**：shim `yue_mbt_win_power_notify(invoke, closure)`——message-only 窗口 + RegisterPowerSettingNotification(hwnd, &GUID_ACDC_POWER_SOURCE, DEVICE_NOTIFY_WINDOW_HANDLE)，WM_POWERBROADCAST/PBT_POWERSETTINGCHANGE 校验 PowerSetting 后取 Data[0]（0=交流、非 0=直流，语义以 Windows SDK powersetting.h 为准），经 PostTask 抛回主循环再 invoke(closure, src)；非 OS_WIN 返回 0。powrprof/user32 已在链接清单，零链接改动。
- **MoonBit API 草案**：`PowerSource { Ac; Battery; Unknown }` + `power_event_supported()` + `on_power_source_change(cb : (PowerSource) -> Unit) -> Result[Unit, PowerError>`；纯事件语义：不立即回调当前值（初始状态查询属 P10）；重复注册后者覆盖前者（全局单回调，形状照 yue/app.mbt:102）。
- **复用点**：B5 的信号订阅表与 AddMatch 先例（yue/traybus/sni.mbt:121-138）；a{sv} 编解码（yue/traybus/wire.mbt:663-670）；闭包型 ABI 与 PostTask（shim/yue_mbt.cpp:3474）。
- **风险**：shim 单槽 fd 扩多槽是连接模型行为变更，断连清理必须同批做（fd 号复用会让回调表张冠李戴）；断线自愈只做最小版；GUID 数据位语义以 SDK 文档与真机实测为准，只钉 0/非 0 二分；本宿主为台式无电池，拔插触发只能由用户笔记本真机执行。

### P12 网络在线状态

- **Linux 路由**：traybus 纯 MoonBit——B5 基座上查 NM 的 State(u)/Connectivity(u)（Properties.Get，应答 "v" 包 u；本机实测 State=70=CONNECTED_GLOBAL、Connectivity=4=FULL，与 nmcli「已连接/完全」一致）+ 订阅 StateChanged 信号与 PropertiesChanged（捕获仅 Connectivity 翻转的场景）；NameHasOwner 判定后端在线性。Linux 信号驱动，无轮询 call_sync。
- **Windows 路由**：shim `yue_mbt_win_connectivity(out_flags)`——Network List Manager COM（CoInitializeEx 文件级 static 守卫 + CoCreateInstance(CLSID_NetworkListManager) + vtable GetConnectivity），出参收原始位掩码（NLM_CONNECTIVITY_IPV4_INTERNET=0x04、IPV6_INTERNET=0x20 等），shim 只做 ABI 翻译；事件后置，本批轮询由 MoonBit 层 set_timer 承担（yue/app.mbt:62）。
- **MoonBit API 草案**：`NetworkStatus { Online; Offline }` + `NetworkError { Unsupported; QueryFailed(String) }` + `Network::is_supported()` / `status()` / `on_status_change(cb)`（注册时立即用当前值回调一次）；NM 0-70 状态机、Connectivity 0-4、NLM 位掩码全部在 MoonBit 层归一；captive portal（Connectivity=2 PORTAL）统一归 Offline（Windows 无法区分，给独立值会让使用方写出永不触发的分支）。
- **复用点**：B5 基建全量；AddMatch 先例（yue/traybus/sni.mbt:121-138）；decode_in 覆盖 u/b/s/v/a{sv}（yue/traybus/wire.mbt:608-685）；set_timer（yue/app.mbt:62）；Ref[Int] 出参先例（yue/ffi.mbt:1732）。
- **风险**：多 fd shim 改造回归面=真机面板（用户复验）；断线自愈现状为零，最小自愈随 B5 落地，若不进批需文档明示「NM 重启后可能需重启应用」；Windows NLM COM 的 apartment 模型未验证；5s 轮询延迟与首次同步查询 ≤1.5s 口径须文档明示。

### P13（后置，不排批）

平台专属能力（Windows 任务栏进度 / macOS dock 徽标 / 最近文档）TODO 已标注后置：本计划不排批、不实现，仅在 B8 的最终文档留一节「后置」说明。

## 5. 共享基建决策

1. **DBus 调用封装**：一律走现有 Conn::call/call_sync（yue/traybus/bus.mbt:246-292），禁止另造发送路径；AddMatch 必须以方法调用发出（教训实证于 yue/traybus/sni.mbt:121-125：误发成广播信号会被总线忽略）。
2. **信号订阅泛化（B5 一次做完）**：Conn 增 watchers:Map["iface.member", Array[(Msg)->Unit]] + matched 规则集；handle 的 kind==4 分支（yue/traybus/bus.mbt:459-483）保持「NameOwnerChanged 特判在前、注册表分发在后」，SNI 重启重注册不回归；B6/B7 只加规则不加特判。
3. **分发链跨批约束**：B5 重构 handle 分发链不得破坏 B1 的 Wake 分发——kind==1 插入点（yue/traybus/bus.mbt:485-487）与 Wake path/interface 匹配保持稳定，若必须移动，B1 的 Wake wbtest 与真总线 gate 在 B5/B6 复跑。
4. **shim 多 fd 改造（B5）**：g_mbt_fd_cb 覆盖式单槽（shim/yue_mbt.cpp:4296，覆盖写 :4305）扩为 fd→cb 分发表 + yue_mbt_sys_unwatch_fd，断连清理表项；蹦床原型不变（mbt_fd_source_cb 已回传 fd，:4298-4300）；非 Linux 同步补桩（照 :4314-4331）；P5 原轮询方案仅作回退。
5. **连接模型（B5）**：connect_session（:108-180）拆出 connect_unix(path)；g_conn（:19）不动、新增系统总线独立 Conn 实例（第二条 fd，不复用 g_conn）与连接注册表；on_bus_ready 从 ignore(fd)（:92）改按 fd 路由；系统总线地址：DBUS_SYSTEM_BUS_ADDRESS 未设置才回退 /run/dbus/system_bus_socket → /var/run/dbus/system_bus_socket，已设置但解析失败显式 Err 不回退；分隔符 ';' 与 ',' 双兼容（现有 session 实现 ','，:44）。
6. **pending 修复与断线自愈（B5）**：call_sync 超时摘除 pending（:283-292 仅在 :449 remove 的滞留已读实）；Disconnected（:480-483）改最小自愈——清连接保订阅、经 post_task（yue/app.mbt:41）延迟重连重放 AddMatch（1500ms 同步握手严禁在 fd 回调栈内做）；系统总线断线时在途 pending 按 one-shot 语义丢弃、调用方重试；周期心跳不做。
7. **wire 'd'（仅 B5，八处联动）**：DVal（yue/traybus/wire.mbt:10-24）、Sig（:39-54）、sig_align（:27-36）、parse_one_sig（:81-135）、sig_of（:155-179）、sig_char（:688-713）、encode（:295-353）、decode_in（:608-685）；MoonBit 穷尽匹配使多数站点漏分支即编译失败，唯一静默点是 encode 兜底（:351）——roundtrip 单测（含 a{sv} 里 Percentage 的真实形状）定位即防此，并经真总线 dbus-monitor 复核。
8. **f64 位转换进 shim**：yue_mbt_f64_from_bits/to_bits 两个纯计算入口（memcpy 重解释 + static_assert(sizeof(double)==8)）；core 无 Double::to_bits/from_bits（grep 0 命中），纯 MoonBit 软解 IEEE-754 有亚常数与精度坑。
9. **shim ABI 规范**：命名 yue_mbt_<域>_<动作>；成败经 int32 返回码或 Ref[Int] 出参、禁止返回可空；字符串 UTF-8；新 ABI 一律进 shim/include/yue_mbt.h（声明区体例 :1-13），顺手补 traybus sys_* 系列历史缺失声明；UTF-8→UTF-16 复用 base::SysUTF8ToWide（shim/yue_mbt.cpp:2144）；非目标平台给桩（照 :4314-4331）；macOS 编译期符号存在 + 运行期 Err(Unsupported)，showcase 演示段在 is_supported()==false 时隐藏或显式降级提示，不留空段。
10. **链接清单**：唯一改动是 B6 的 wtsapi32.lib——scripts/prebuild.py:44-56 与 shim/CMakeLists.txt:139-145 两处同提交追加（Windows 清单无「与 CMakeLists 一致」注释背书，该注释在 scripts/prebuild.py:32 挂的是 Linux 清单；漏一处即 LNK2019）；其余 ABI 所需库（user32/advapi32/shell32/ole32/powrprof 已在两份清单，x11 在 prebuild.py:33-38，glib 随 GTK 面）零改动；任何 moon.pkg 不写 link 段；回退方案 LoadLibraryW 动态加载须新写 loader 模式（仓内 GetProcAddress 全配 GetModuleHandleW，shim/yue_mbt.cpp:5427-5430、:5440-5442、:5516、:5553，无 LoadLibraryW 先例）。
11. **Windows 消息窗口基座（B1 首次落地）**：message-only 窗口（HWND_MESSAGE 父 + 自注册窗口类，类名由 app_id 派生）+ WM_COPYDATA + PostTask 蹦床是仓内首例自有 WNDPROC 代码（grep WNDPROC|CreateWindowEx|RegisterClass|HWND_MESSAGE 0 命中），无模板可抄；可借模式：LL 钩子 + PostTask 防重入配方（PopoverMouseHook，shim/yue_mbt.cpp:2962；装钩 SetWindowsHookExW，:3210-3211）、蹦床原语（yue_mbt_post_task，:3474；extern yue/ffi.mbt:1795）、static 一次性守卫（EnsureToastAumid，:3631-3632；注册表写 :3654/:3658）；硬约束：必须在运行 libyue 主循环的主线程建窗；置前主路径=消息窗口唤醒 + on_activate 内首实例自置前（现成 MoonBit Window API：yue/view.mbt:111、yue/methods.mbt:20/:26），标题查找降级为兜底；能否被 libyue 主循环 DispatchMessage 派发未经真机验证，B1 首验、B4/B6 沿用。
12. **Wake 与 on_activate 契约（B1 定义）**：Wake 的 dest=app_id、path/interface 建议 /org/moonbitlibyue/Instance 与 org.moonbitlibyue.Instance；app_id 合法 DBus 名由 MoonBit 层预校验（非法 → InvalidAppId）；on_activate 注册形态=SingleInstance::on_activate(self, cb : (Array[String]) -> Unit) + MoonBit 侧回调表与 keep_alive（形状照 yue/app.mbt:102；仓内无 App 级 on_activate，仅 Entry::on_activate yue/button.mbt:131）；Linux showcase 演示不 spawn 自身，真双开由用户执行。
13. **MoonBit 错误枚举一域一名**（照 yue/error.mbt:4-20 样板）：B1 SingleInstanceError、B2 AutostartError、B3 OpenUrlError + FileManagerError、B4 IdleError + KeepAwakeError、B5 PowerError、B6 SystemError、B7 NetworkError；收敛为统一 SystemError 家族的评估留 B8。
14. **MoonBit 模块落点与门控**：B1 yue/singleinstance.mbt（拟新增）+ yue/traybus/instance.mbt（拟新增）+ yue/traybus/bus.mbt（改：Wake 分发）；B2 yue/autostart.mbt（拟新增）；B3 yue/system.mbt（拟新增）+ yue/traybus/filemanager.mbt（拟新增）；B4 yue/idle.mbt、yue/keepawake.mbt、yue/traybus/inhibit.mbt（均拟新增）；B5 yue/power.mbt、yue/traybus/upower.mbt（拟新增）；B6 yue/session.mbt、yue/traybus/logind.mbt（拟新增）；B7 yue/online.mbt、yue/traybus/netmon.mbt（拟新增）；所有新 traybus 文件必须同步登记 yue/traybus/moon.pkg 的 targets native 列表（:6-14）；B2 需把 moonbitlang/core/env 从 for "wbtest"（yue/moon.pkg:7-9）提升为常规 import。
15. **spawn 统一（B3）**：xdg-open 拉起统一走 glib g_spawn_async（内部双 fork 防僵尸、关继承 fd、按 PATH 定位、直传 argv 不经 shell；严禁 system()/popen）；P8 回退复用同一 ABI 形状（sys_spawn_detached），另补 sys_getcwd。
16. **showcase 演示段随功能批交付**（B1 单实例、B2 开关、B3 打开外部，照 examples/showcase/pages_system.mbt:38 的 page_system 与 :271 滚动骨架、examples/showcase/main.mbt:17 的 section  helper 追加）；事件类（P4/P5/P11/P12）只进文档不建常驻演示；B8 只剩文档、复验与 P13 说明。
17. **真机分工固化**：助手=命令级（moon check && moon test / moon build per-example）+ 宿主机真总线抓包（会话+系统总线均已实测在线）+ 启动冒烟；用户=休眠/锁屏/拔插/断网/三桌面双开/Windows 全部真机项及一切会产生真实弹窗的功能调用（AGENTS.md 规则 6），用户侧抓包一条命令自抓自发；每批 shim 改动的 Windows 真机 gate 以 vendor-* 出包完成（或用户本机 CMake 构建）为前置（docs/zh/adaptation.md:25），未出包记「未实现」。
18. **B7 可与 B6 合并**为「系统总线事件第二批」：若 B5 基建回归顺利则合并（减少一次 shim 改动与出包），反之保持独立。

## 6. P13 后置说明

P13（平台专属：Windows 任务栏进度 / macOS dock 徽标 / 最近文档）在 TODO 中已标注后置。本计划不排批、不实现、不分配验收；仅在 B8 收口时于最终文档（components.md 中英「系统集成」节末尾）留一节「后置」说明，列明三项能力名与「待立项」状态，不展开方案。

## 7. 风险与开放问题

1. wire 'd' 八处联动中真正会静默出错的只有 encode 兜底（yue/traybus/wire.mbt:351），其余站点漏分支编译期失败或显式 Err；a{sv} 含 Percentage 的真实形状 roundtrip 仍必须做并经真总线 dbus-monitor 复核（单测自洽不算互操作通过，AGENTS.md 规则 5）。
2. shim 多 fd 改造是连接模型行为变更，直接影响已验证的 SNI 托盘链路，回归面是 XFCE/KDE/GNOME 真机面板（用户复验），单测覆盖不到；故压进 B5 与最薄的 UPower 消费捆批先过回归关。
3. wtsapi32.lib 是全计划唯一链接清单改动：两份清单各 32 库均无它（已核验）、全仓 grep 0 命中、vendored 两库 0 引用 WTSRegisterSessionNotification；必须同提交双改并互相复核（Windows 清单无同步注释背书）；不愿动清单则回退 LoadLibraryW 动态加载，但须新写 loader 模式（仓内无 LoadLibraryW 先例）；无论哪条路 windows-x64 vendored 库都需 vendor-* 出包拉齐，否则 Windows 真机只能记「未实现」。
4. call_sync 超时不摘 pending（yue/traybus/bus.mbt:283-292、:449）致迟到应答回调陈旧闭包，长年监听进程缓慢累积——B5 根治；若 B5 延期，B6/B7 的 AddMatch/Get 迟到应答会打到失效闭包。
5. 断线自愈只做最小版（清订阅→post_task 延迟重连→重放 AddMatch），周期心跳未做；同步握手严禁放进 fd 回调栈（最坏阻塞主循环 1500ms，yue/traybus/bus.mbt:347-362 已读实）。
6. P1/P2 API 草案分歧已裁决为 P2 形态；实现期若再变，yue 层与 showcase 演示段需同步改（签名漂移风险）。
7. 「已有实例」后行为以 P2 为准（claim 得 3=EXISTS → wake_existing 后再退出），TODO.md:124 旧验收列随 B1 修订；置前主路径=消息窗口 + 首实例自置前，标题查找降级兜底；彻底去标题化需首实例自持 HWND 置前（shim 已有 GetNative()->hwnd() 通路，PopoverMouseHook 内已读实），列为后续评估。
8. B1 的 message-only 窗口是仓内首例自有 WNDPROC/窗口类代码（grep 0 命中），无模板可抄，实现期按图索骥会落空——可借模式仅 LL 钩子+PostTask（shim/yue_mbt.cpp:2962、:3210-3211）、蹦桥（:3474）与 static 守卫（:3631-3632），须如实写入 adaptation.md；必须建在运行 libyue 主循环的主线程；能否被 libyue 主循环 DispatchMessage 派发未经真机验证（vendor/libyue 仅 include+lib）；B1 无 PowerRegisterSuspendResumeNotification 式回退，退路是降级为「仅第二进程查找置前 + on_activate 仅 Linux 生效」并文档显式标注。
9. P4 的电源消息窗口派发假设与模态漏事件风险同 B1；漏则回退 PowerRegisterSuspendResumeNotification；该假设 B1 首验，B6 复验失败时影响面从单实例唤醒扩到休眠/锁屏全事件链。
10. Modern Standby 机型上 SetThreadExecutionState 可能不生效（P9），需 PowerCreateRequest/PowerSetRequest 兜底——未实测，列 B4 真机记录项。
11. XWayland 下 XSS idle 虚高（输入不进 X 服务端），以 WAYLAND_DISPLAY 探测提前 Err(Unsupported)；RDP/注入输入扰动读数（方案实测 sleep 2s 期间 xprintidle 3117→223ms）；数值口径与「锁屏也算空闲」必须写进使用文档。
12. .desktop Exec 两层转义规则仓库零先例，含空格/引号/$/反斜杠路径必须三桌面真机拉起验证；AppImage/wine 下 /proc/self/exe 给出挂载点临时路径，自启动失效，需写边界。
13. ShowItems 的 file:// URI 百分号转义未发真实调用验证（只读 introspect）；不存在路径双平台行为不一致（Thunar 错误框 vs explorer 开最近父级），shim 无 stat ABI，v1 不做 NotFound 归一；真实功能调用与抓包触发均由用户一条命令自抓自发（AGENTS.md 规则 6 未豁免助手主动弹窗）。
14. DBUS_SYSTEM_BUS_ADDRESS 解析行为是 B5/B7 降级 gate 的直接变量：已设置但解析失败必须显式 Err 不回退（否则连回真有服务的总线，预期假失败）；分隔符 ';' 与 ',' 双兼容（规范 ';' vs 现有 ',' 实现，yue/traybus/bus.mbt:44）；须在设置该变量的机器上核验并回写。
15. 本环境禁 sudo（实测 `sudo -n true` 退出 1，「no new privileges」）：依赖 root 的降级验收改走 dbus-run-session 私有总线（该工具无 --print-address，用 `dbus-run-session -- sh -c 'DBUS_SYSTEM_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS <程序>'` 会话内环境变量转发，本宿主机实测可用）或用户真机。
16. 服务在线性有桌面/发行版分歧（P9 已实测 XFCE 上 org.freedesktop.ScreenSaver 未被持有、实际是 org.xfce.ScreenSaver；P4/P5 也依赖锁屏工具实现）：GNOME/KDE 的 NameHasOwner 值必须真机实测，候选表按序探测、不凭记忆写死单一服务名，差异回写 adaptation.md「桌面环境」节。
17. Windows NLM COM 的 apartment 模型未验证（若 libyue 主线程已 MTA 初始化，STA 对象创建走 marshaling）；B7 Linux 信号驱动无轮询 call_sync，首次 status() 同步建缓存最坏 ≤1500ms（yue/traybus/bus.mbt:287），口径写进使用文档。
18. 行号时效：本计划全部行号按 HEAD 4105e1b、工作区仅 `?? .zcodeignore` 逐条 grep 校准；但本会话内 HEAD 三易（4951eee→3b203fe→4105e1b），每批开工前仍须重跑 git log/status 与符号 grep 复核，不复检就照抄行号会失真。
19. 用户侧遗留：锁屏工具不调 logind 则 P5 事件不到；P13 后置不排批——验收记录须注明桌面环境与版本，差异全部回写 adaptation.md。

---

*本计划为只读调研产出，未运行 moon check / moon test；命令级验收由各实施批次执行并报告。*
