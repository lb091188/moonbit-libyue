# 平台适配经验

moonbit-libyue 在各平台适配过程中的实测经验与坑,全部来自真实环境验证。
主 AI 文档(仓库根 `AGENTS.md`,ZCode 读取)经 `@docs/adaptation.md` 引入本文件;以本文为平台适配坑的持续更新详版(README 只留指针,不再展开)。

**组织维度**:Linux 按「发行版 → 桌面环境 → 版本」三层;Windows / macOS 按「版本」。
**状态标记**:✅ 实测通过 / ⚠️ 部分可用或带条件 / ❌ 不可用 / ❓ 未实测(占位,待补)。

---

## 跨平台通用(构建链 / FFI,不分平台)

### 构建与链接

- `moon` 命令必须在**仓库根**执行的习惯保留:链接参数虽已改为绝对路径(见下条),但 vendor/build 产物与 WebView2Loader.dll 的运行期搜索仍按工作目录。
- moon 的 `link` 段只作用于所在包、只对 main 包的二进制生效;库包(如 `yue/`)放 link 段会让 moon 生成无 main 的 `.exe` 导致构建失败。链接配置已全部收敛到 `scripts/prebuild.py`,任何包的 moon.pkg.json 都不再写 `cc-link-flags`。
- **双平台链接参数由 pre-build 钩子传播(当前方案,2026-09-12 实测入档)**:moon 的 `cc-link-flags` 是单一字符串、`targets` 条件编译无 OS 维度,链接参数无法按平台入库。现行机制:moon.mod.json 声明 `--moonbit-unstable-prebuild: scripts/prebuild.py`,moon 每次构建执行它,脚本按 `platform.system()` 输出 `link_configs` JSON,moon 把它**自动传播给所有依赖 yue 包的 main 包**——本仓 examples 与 mooncakes 使用方统一零配置,切换平台自动换参数。实测要点:
  - 脚本 **stdout 只能是最终 JSON**:任何 print(含子进程透传)都会导致 moon 反序列化失败(`invalid number at line 1 column 2`),进度信息一律走 stderr。
  - **不要用 `link_libs` 放 libyue_mbt**:moon 组装命令行时 `link_flags` 在 `link_libs` 之前,GNU ld 从左到右解析,`-lyue_mbt` 排在 `-lstdc++` 之后会 `undefined reference to __cxa_guard_acquire`。全部参数放 `link_flags` 单一字符串自控顺序(与旧响应文件同序)。
  - 脚本 cwd 是 **moon 调用目录(使用方项目根)**,定位自身必须 `Path(__file__)`;传播的库路径必须是**绝对路径**(链接命令的 cwd 在使用方侧)。
  - 原生产物缺失时脚本自动调 prepare.py 补建(产物存在时毫秒级返回),首次构建走 GitHub 下载。
  - 该机制官方标注实验性(`--moonbit-unstable-prebuild`),API 可能随 moon 升级变动;Windows 下 `python3` 命令可用性待真机验证。
  - 历史方案:先按系统回写 moon.pkg.json(两平台互相覆盖)→ `@build/link.flags` 响应文件(gcc/clang 与 cl 都支持 `@文件`,双平台同一份入库)。均已被传播机制替代。
- `prepare.py` 幂等可重跑:缓存 zip sha256 不匹配(下载被截断)自动删除重下;下载先写 `.part` 临时文件、校验通过才原子落盘。网络走标准 `http_proxy/https_proxy` 环境变量。
- **`postadd` 脚本仅在 registry `moon add` 安装时触发**,path/git 依赖与模块自身构建不触发;产物缺失的兜底由 prebuild.py 的检查承担。
- libyue 版本钉死在 `scripts/prepare.py`(`LIBYUE_VERSION` + 三平台 sha256),升级需同步更新三个校验和。

### MoonBit cfg(platform=) 平台条件编译

- **现状(2026-09-14 实测入档)**:moonc 已实现 `#cfg(platform="windows"/"linux"/"macos")` 条件编译(官方文档未写),求值依据是传给 moonc 的 `-target` **三元组**(`x86_64-unknown-linux-gnu` / `x86_64-pc-windows-msvc` / `aarch64-apple-darwin`);`not/any/all` 组合器可用。moonbitlang/openseek 生产在用(仅 `platform="windows"` 及其反)。
- **但当前可安装的 moon(stable 0.1.20260904 与 nightly 0.1.20260911)构建时只给 moonc 传无 OS 信息的泛用 `native`**,所有 `platform=` 条件恒 false——Linux 上连 `platform="linux"` 都不命中;`MOONBIT_NEW_NATIVE=1` 与 `moon.mod` 新格式(直出目标文件后端已生效,产物为 .o)也不传三元组。moon main 分支已有按宿主选三元组的逻辑(`NativeTarget::from_host`:x86_64 Linux / Apple Silicon 默认启用、Windows 需 env=1),**待发布版本携带后条件才会点亮**。
- 迁移信号:任意构建加 `-v`,moonc 命令行出现 `-target x86_64-unknown-linux-gnu` 即可用;届时 showcase 的运行时平台段可一行替换为 `#cfg`。
- 当前替代:运行时 `platform()` 判断——声明式树按条件组装节点,不满足就不创建控件,效果等同编译期隐藏;showcase 的平台段(桌面环境、剪贴板主选区、自定义协议等)即此方案,见 `examples/showcase/section.mbt` 头注释。
- 验证方式:临时工程双分支(`#cfg(platform="linux")` / `#cfg(not(platform="linux"))`)编译运行看走哪支;moonc 直调带 `-target x86_64-unknown-linux-gnu` 可证编译器侧已生效(实测三分支各归各位)。另:`moon.pkg.json` 的 `targets` 文件级条件仍只有后端(wasm/js/native)+ debug/release 维度,喂 OS 值直接 schema 加载失败;裸标识符条件(如 `#cfg(linux)`)恒真,无意义。
- 顺带:nightly 0911 对全仓 `impl ViewLike for X` 报 19 处 `implicit_impl_as_method` 弃用警告(stable 0904 无),属工具链前向收紧,非库代码回归。

### MoonBit ↔ C ABI

- **FuncRef+Callback 蹦床的形参个数必须与 C 函数指针原型逐位相等**(2026-09-11 实测入档)。约定:C 以 `callback(closure, args...)` 调用,MoonBit 蹦床为 `fn(f, args...)`,首参 `f` 收到的就是 closure。
  - 案例:Table 的 `get_value`/`set_value` 蹦床比 C 原型各多带一位(4↔3、8↔6),形参错位后 ModelBox 被当函数指针调用 → 首次渲染直接段错误;而 `row_count`(1↔1)正确,所以行数正常、窗口能建——**部分接口"看起来能跑"会掩盖 arity 错位**,必须让每个回调都真实触发一次才算验证过。
- `extern "c"` 不能返回可空类型(ABI 与 C 指针不兼容,直接段错误):成败经 `Ref[Int]` 出参报告,句柄按非空返回。
- FFI 指针参数必须标 `#borrow`(编译器强制);同函数多参数写在同一个 `#borrow(a, b)` 里。
- extern 声明的控件参数必须写底层句柄类型 `View`,不能写 MoonBit 包装 struct(如 `Slider`):struct 经 ABI 传入的是包装对象而非句柄值,运行时全部"句柄无效"且被静默丢弃(Slider/Table 系列曾因此整体失效,2026-09 修复 22 处)。
- 闭包跨 C ABI:只允许无捕获的顶层函数字面量(编译为真实 C 函数指针);带捕获闭包走"函数指针 + 闭包指针"双参数模式(`on_click` 系)。
- 回调闭包由注册表保活(`yue/view.mbt`),窗口销毁后条目暂不回收——**已定案维持进程级保活**(2026-09-12):回调与窗口无归属关系可循,精准回收需 weak-reference 注册表,当前 MoonBit 生态不成熟;单窗口工具场景泄漏量可忽略(2026-09-12 定案)。
- **Toolbar / Vibrant 在 Linux 不可用**:libyue 头文件无平台 guard,但 Linux 静态库未编入任何相关符号(nm 实测零符号),调用会链接失败;Binding 侧已明确标注不暴露。
- **Browser::GetCookiesForURL 空 Cookie 列表会 FATAL**:libyue 0.15.6 内部 `CHECK(cookies)` 对空列表直接崩溃(上游缺陷),查询前须确保页面已种 Cookie。

---

## Linux

### 发行版

#### Ubuntu 24.04 LTS (Noble) ✅ 主链路实测

- 实测环境:24.04.4,内核 7.0.0-31-generic,X11 会话;GTK 3.24.41 / webkit2gtk 2.52.6(4.1 API)/ dbus-daemon 1.14.10。
- 系统依赖:`build-essential cmake pkg-config libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev`。
- AppIndicator:24.04 已移除传统 `libappindicator3` 运行库,libyue 内置托盘不可用(内部 dlopen 失败只打日志、对象静默失效)→ 本项目用 `yue/traybus/` 纯 MoonBit SNI 直连面板替代。
- libyue 的托盘探测列表只认 `libappindicator3`;本机装有 ayatana 分支不代表可用,shim 侧已加空指针防御。SNI 后端上线后此路径仅作回退。
- webkit2gtk 包名 4.0/4.1 因发行版而异:`prepare.py` 用 pkg-config 探测,任一存在即可(4.1 需补 `-ljavascriptcoregtk-4.1`)。

#### 其他发行版 ❓ 未实测

- Debian(包名与 Ubuntu 接近)、Fedora(`webkit2gtk4.1-devel` 命名不同)、Arch 等待实测;移植第一步是核对各依赖的 pkg-config 名称,再跑 `prepare.py`。

### 桌面环境(托盘 / 菜单行为差异)

#### XFCE ✅ 实测通过

- 实测版本:Xfce 4.18.4(xfce4-panel 4.18.4),托盘插件 `panel-8-systray`。
- SNI watcher 在线:托盘图标、Activate 点击回调贯通;`Tray::on_click` 正常。
- 右键菜单:面板**自己镜像 DBusMenu 渲染**,不走 SNI `ContextMenu` 让应用自绘(实测 dbus-monitor 只有 `AboutToShowGroup` + `GetLayout`/`GetGroupProperties`,无 `ContextMenu` 调用)。
- **xfce4-panel 4.18(libdbusmenu 客户端)只发批量版 `EventGroup` / `AboutToShowGroup`,不发单条 `Event` / `AboutToShow`**(2026-09-11 实测入档):只实现单条版会被 UnknownMethod 静默拒掉,表现为菜单弹出正常但点击全部无效。dbus-monitor 抓真总线才能发现。
- 桌面识别:`XDG_CURRENT_DESKTOP=XFCE`,`@traybus.desktop_name()` 可用于诊断。
- **桌面通知走 `Notification::Show()`,不是 `NotificationCenter::AddNotification`**(2026-09-12 实测入档):libyue Linux 的 `AddNotification` 只把对象登记进内部列表,**从不发 DBus `Notify` 调用**;发通知必须调 `Show()`(内部 GDBus 异步 `org.freedesktop.Notifications.Notify`)。shim 曾在 Linux 分支只调 AddNotification,表现为通知静默失败无任何报错。判据:`dbus-monitor "type='method_call',interface='org.freedesktop.Notifications'"` 抓真总线,`member=Notify` 计数为 0 即调用未发出;修复后实测 xfce4-notifyd 正常弹气泡(含 actions 按钮)。
- **全局快捷键是 X11 `XGrabKey` 排他注册,被占用即返回 -1**(2026-09-12 实测入档):XFCE 自定义快捷键(xfconf-query `/commands/custom/`,如本机 `<Primary><Alt>s` 绑了钉钉切换脚本)已抓取的组合键,再注册会 BadAccess,libyue 用 error trap 吞掉后 `Register` 返回 -1——不崩溃但静默失败,使用方必须检查 -1 并提示换键。验证键位占用:`xfconf-query -c xfce4-keyboard-shortcuts -l -v`。
- **焦点在桌面时 xfwm4 抢占键盘,全局快捷键不触发**(2026-09-12 实测入档):`XGrabKey` passive grab 已挂、焦点在任意应用窗口时按键正常触发;但焦点落在桌面(xfdesktop)时 xfwm4 的键盘处理抢先,事件到不了应用。自动化验证用 `xdotool windowfocus <窗口>` 先把键盘焦点移入被测窗口再 `xdotool key ctrl+alt+<k>`,仅 `windowactivate` 不转移键盘焦点,会得到"没触发"的假阴性。

#### GNOME ❓ 未实测

- 纯净 GNOME 无托盘协议 → `Tray::is_supported()` 为 false,`Tray::new` 返回结构化 `Err(Unsupported)`,属预期行为。
- 装 AppIndicator 扩展后协议层可用(traybus 已实现 SNI),待实测入档。
- GNOME (X11) 下托盘/菜单/对话框/WebView 的视觉与交互表现在 TODO,待人工确认。

#### KDE / MATE / Cinnamon / Budgie / LXQt ❓ 未实测

- 协议层均支持 SNI(StatusNotifierItem),traybus 已按协议实现,预期可用;待逐一真实环境实测后在本节补充版本号与差异。

### DBus 线路协议坑(traybus 实测,桌面环境无关)

- DBus 数组长度前缀**不含首元素前的对齐填充**:算进去会被 dbus-daemon 判协议违规直接断连。
- DBus 头部 SIGNATURE 字段的 variant 签名是 "g"(u8 长度编码),按 "s" 编能过自洽单测但会被真实总线拒绝。
- 教训:**单测证自洽,互操作必须上真总线验证**;discovery 类问题用 `dbus-monitor` 抓包定位。

### 显示协议

- X11 ✅(当前唯一主链路)。
- Wayland ❌ 未支持(TODO 已列);libyue 的 GTK 后端以 X11 为准,迁移前不要在 Wayland 会话里验证 GUI 行为。

### GTK 相关

- Table(GTK)放进 Notebook 页签内会在尺寸测量时段错误(negative allocation),必须放普通容器或独立窗口(showcase 采用独立子窗口方案;2026-09-11 在 showcase 复现:崩前先出现 `Negative content width -1 (… owner GtkFrame)` 与 `GtkScrollbar` 的 `size >= 0` 断言)。

---

## Windows ✅ 首次实测通过

### Windows 10 / 11 ✅(2026-09-12 实测:Windows 10.0.19045 x64 + MSVC 14.44 + Windows SDK 10.0.26100 + moon 0.1.20260904)

#### 工具链准备(现象→根因→修复)

- **moon 原生后端要求系统 C 编译器**:PATH 上找不到 `cl/cc/gcc/clang` 直接报 "no system C compiler found"。修复:装 VS Build Tools(`Microsoft.VisualStudio.Workload.VCTools`),并在 **x64 Native Tools Command Prompt**(或先 call `vcvars64.bat`)里执行 moon/cmake。
- **libyue Windows 源码需要 ATL 头**(`base/win/atl_throw.h` → `atldef.h`),VCTools 工作负载默认不带:报 C1083 找不到 atldef.h。修复:VS Installer `modify --add Microsoft.VisualStudio.Component.VC.ATL`。注意 **quiet/passive 模式必须从提权进程启动**,否则立即退出且 Exit Code 5007(日志在 `%TEMP%\dd_installer_*.log`)。
- **`prepare.py` 下载 404**:发行包资产名与 `platform.system()` 不同名——实际是 `libyue_{v}_win.zip` / `_mac.zip`(不是 windows/darwin)。已修 `prepare.py`(ASSET_OS 映射),macOS 路径顺带修好。

#### 链接参数(moon → cl/link 的真实行为,全部实测)

- **`cc-link-flags` 被 moon 原样拼进 `cl` 命令行**,不是直接给 link:GNU 风格 `-L/-l` 报 D9002/D9024;`/LIBPATH:` 也是 cl 不认识的编译器选项,只告警不转发。**正确做法是写链接输入**:`build/yue_mbt.lib setupapi.lib …`,cl 会把 .lib/.res 位置参数转交 link;系统库由 vcvars 注入的 `LIB` 环境变量解析,无需写参数。
- **分隔符必须用正斜杠**:`build\yue_mbt.lib` 会被 moon 的参数解析当转义吃掉反斜杠,link 收到 `buildyue_mbt.lib` 报 LNK1104。
- 官方 CMakeLists 的系统库清单本身缺项(无 user32/ole32/oleaut32/shell32 等),直接照抄会报 144+ 个 LNK2019(DefWindowProcW/VariantClear/SysStringLen 等);`prepare.py`/shim 清单已补齐 GUI 基础库,多余库 link 会忽略。
- **CRT 必须与 moon 一致为静态 /MT**:moon 生成代码固定 `/MT`(debug 亦然)。CMake 多配置生成器**忽略 `CMAKE_BUILD_TYPE`**,`cmake --build` 不带 `--config` 默认按 Debug(/MDd)编,最终链接报 LNK4098(MSVCRTD 冲突)+ 约 200 个 `__imp__*` 未解析。修复:shim 库 `cmake_policy(SET CMP0091 NEW)` + `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded`(须在 add_library 之前)+ 构建 `--config Release`(prepare.py 已自动化)。
- **moon 不因静态库更新自动重链**:cc-link-flags 与 MoonBit 源都没变时,换 `yue_mbt.lib` 后 `moon build` 报 "no work to do",需 touch 主包任一源文件强制重链。

#### 应用清单(manifest)

- **进程启动即弹"无法定位于序数 345 于动态链接库 …exe"**:comctl32 的 `TaskDialogIndirect` 仅以**序数 345** 在 Common-Controls v6 导出,exe 无清单时加载旧版 comctl32,解析静态导入阶段就失败。官方 sample_app 靠自带 `exe.manifest` 解决。修复:官方清单编译为 `build/yue_mbt_manifest.res`(shim/CMakeLists 的 rc 自定义命令),经链接参数进入每个示例 exe(RT_MANIFEST 声明 Common-Controls v6 依赖)。运行验证:showcase 消息框(TaskDialog)正常弹出。

#### shim 平台差异(首次 Windows 编译暴露,均已条件编译修复)

- `dlfcn.h` 的 include 要按 `__linux__` 守卫(使用点本来就在 `OS_LINUX` 块内);MSVC 的 `M_PI` 需 `#define _USE_MATH_DEFINES`。
- **`base::FilePath` 在 UNICODE 构建下 StringType 是 `std::wstring`**,`FilePath(const char*)`、`+= path.value()` 全部编不过:统一经 `FromUTF8Unsafe/AsUTF8Unsafe` 进出(见 shim 的 `FilePathFromUTF8/FilePathValueToUTF8`)。
- **Windows 版 libyue 无 Popover**(发行包不含 popover.h,jumbo 源零实现):shim 保留 6 个 ABI 但降级为空操作/空句柄,MoonBit 侧 `Popover` 方法空转。
- 其余 API 面差异(对照发行包头文件的平台 guard 逐一修复):`Browser::Options` 无 `allow_file_access_from_files`(MAC/LINUX)/`hardware_acceleration`(LINUX);`Scroll::SetOverlayScrollbar`、`Clipboard::Type::Selection`、`Tray::SetTitle`(MAC/LINUX)不存在,均降级空操作;`NotificationCenter::AddNotification` 是 Linux 内部接口,Windows 走 `Notification::Show()`。
- `operator new/delete` 接管:Linux 用 glibc `__libc_malloc/free` 绕开 mimalloc 接管;**Windows 下 moon 以 `MOONBIT_ALLOCATOR=SYSTEM` 编译运行时**,CRT 堆即系统堆,重定向到 `malloc/free` 即可。

#### 运行期差异(showcase 真机逐页验证发现)

- **`AttributedText::SetFontFor/SetColorFor` 局部区间直接 CHECK 崩溃**(`nativeui_jumbo_2.cc`: "does not work on Windows"),只支持全文范围(0,-1)。修复:yue/painter.mbt 按 `platform()=="windows"` 对区间调用降级为无操作并告警一次(showcase 富文本页因此从启动崩溃变为正常渲染,区间样式按平台优雅退化)。
- **`Color::Get(Border)` 触发 NOTREACHED**(Windows 实现无 Border 分支,ERROR 日志且返回垃圾色):shim 对 Border 直接 `GetSysColor(COLOR_WINDOWFRAME)`,showcase 系统语义色行输出正常、日志零 CHECK。
- 托盘为原生后端:`Shell_NotifyIconW` 创建成功(日志"托盘:已创建");`set_title` 无对应概念为空操作;图标加载会有 libpng iCCP 警告(无害)。
- **字体发虚(GDI+ 灰度抗锯齿)**:libyue 的 GDI+ 画笔写死 `TextRenderingHintAntiAlias`(灰度 AA),Windows 上自绘的 Tab/按钮/标签小字明显发虚。修复:prepare.py 解压后对 vendor 做幂等文本替换(AntiAlias → `TextRenderingHintClearTypeGridFit`),重建即锐利;vendor 不进版本库,重跑脚本自动重新应用。
- **系统通知静默失败**:WinRT toast 的 notifier 按 AUMID 查找,进程未设置 `AppUserModelID` 时 `GetNotifier` 直接返回 null,`Show()` 静默失败。修复:shim 在首次通知前自动设置 AUMID(基于 exe 名)并写 `HKCU\Software\Classes\AppUserModelId\<AUMID>` 的 DisplayName;横幅是否弹出还受系统专注助手/全屏抑制影响,通知历史在操作中心可查。
- **浏览器优先 WebView2**:发行包 vendor 只带 WebView2Loader.dll 不带头文件,官方 CMake 也未启用;prepare.py 现从 NuGet 固定版本补齐 `WebView2.h`(sha256 钉死)并把 loader DLL 复制到仓库根(libyue 按 exe 目录→工作目录搜索)。shim 构建定义 `WEBVIEW2_SUPPORT` 并加 include;`Browser::new` 在 Windows 默认 `webview2_support=true`,loader/运行时缺失时 libyue 自动回退 IE。验证:本地 HTML(load_html)、ExecuteScript 正常;远程站点依赖系统代理可用。
- **demo:// 自定义协议在 WebView2 下静默无效**(注册/拦截链齐全但导航无效果,IE 引擎可用):上游待查;IE 兜底路径保留。
- **滚动区内容零高度(跨平台统一默认值原则)**:win32 的 Group/Scroll 不按内容自增长(GTK 有自然首选尺寸),showcase 里"滚动区里的文本编辑"整块塌陷。修复:给 Group 显式 `set_style("height", 128)`——同一默认值两端表现一致;遇到类似不一致一律用统一默认值吸收,不做平台分支。
- **Popover 气泡在 Windows 的替代实现**:libyue 无 Popover(见下),shim 用无边框、不抢焦点、置顶的小窗口替代,弹在点击位置右下,8 秒定时自动关闭(无外部点击关闭钩子),`close`/`on_close` 语义保留;验证:showcase 气泡按钮弹出/自动关闭/日志闭环。
- 平台信息(`platform()=="windows"`、区域、缩放、屏幕)、剪贴板、定时器、全局快捷键注册、全局鼠标轮询、画布(GDI+)与浮动爱心窗口均实测正常。

#### 验证方式

- `moon run examples/hello`:窗口渲染 + 托盘 + 点关闭经 `on_close→quit()` 优雅退出。
- `moon run examples/showcase`:8 页签逐一点击(基础控件/输入与选择/画布/网页/对话框/系统集成/事件/富文本)、菜单(勾选/单选/表格独立窗口)、消息框、画布色相重绘、鼠标事件实时回显、全局鼠标、浮动爱心、关闭退出,全程日志零 CHECK 失败。
- `moon check` / `moon test` 全仓通过(2026-09-12)。

---

## macOS ❓ 未实测

### macOS(libyue v0.15.6 发行包含 ARC / no-ARC 双库结构)

- CMake 已备 ARC/no-ARC 双库分支,均未验证;首次实测先确认两种链接形态哪条走通。
- 首次 macOS 实测以 CI 承担(2026-09-14 起,`.github/workflows/ci.yml` 的 macos job,macos-latest ARM64 Runner):构建 + 测试级验证,不做 GUI 运行冒烟(headless Runner 无 WindowServer)。实测结果待首跑后回写本节。
- prebuild 的 Darwin 分支已按官方构建结构**预修**(尚未实测):链接参数补第二个静态库 `-lyue_mbt_noarc`(no-ARC 库符号被主库引用,GNU ld 从左到右须排其后)+ 全部框架(AppKit/Carbon/IOKit/Security/WebKit/OpenDirectory)+ `-lobjc -lc++ -lpthread`——静态库的系统依赖不会自动传播到 moon 的链接命令行,必须显式给出(与 Linux 侧 pkg-config 补系统库同构)。
- 版本细分(按 macOS 大版本)待实测后补充。

---

## 维护约定

1. 每次真实环境实测后,把「发行版 / 桌面环境 / 版本 + 现象 + 根因 + 修复 + 验证方式」写进对应小节;新发行版/桌面从 ❓ 占位小节开始。
2. 涉及协议互操作(DBus / DBusMenu / SNI)的结论必须来自真总线、真面板;单测自洽 ≠ 互操作通过。
3. 简短结论同步 README「Known Limitations / known pitfalls」;本文保留完整过程与版本细节。
