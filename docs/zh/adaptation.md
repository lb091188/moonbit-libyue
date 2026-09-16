# 平台适配经验

moonbit-libyue 在各平台适配过程中的实测经验与坑,全部来自真实环境验证。
主 AI 文档(仓库根 `AGENTS.md`,ZCode 读取)经 `@docs/adaptation.md` 引入本文件;以本文为平台适配坑的持续更新详版(README 只留指针,不再展开)。

**组织维度**:

- Linux 按「发行版 → 桌面环境 → 版本」三层;
- Windows / macOS 按「版本」。

**状态标记**:

- ✅ 实测通过
-  ⚠️ 部分可用或带条件 
-  ❌ 不可用
-  ❓ 未实测(占位,待补)

---

## 跨平台通用(构建链 / FFI,不分平台)

### 构建与链接

- `moon` 命令必须在**仓库根**执行的习惯保留:链接参数虽已改为绝对路径(见下条),但 vendor/build 产物与 WebView2Loader.dll 的运行期搜索仍按工作目录。
- moon 的 `link` 段只作用于所在包、只对 main 包的二进制生效;库包(如 `yue/`)放 link 段会让 moon 生成无 main 的 `.exe` 导致构建失败。链接配置已全部收敛到 `scripts/prebuild.py`,任何包的 `moon.pkg` 都不再写 `cc-link-flags`。
- **manifest 迁移到 `moon.mod` / `moon.pkg` 新格式(2026-09-15 实测入档)**:moon 新版弃用 `moon.mod.json` / `moon.pkg.json`,`moon fmt` 一键迁移(字段改 DSL 风格:`preferred_target`、`options(...)` 块;pkg 的 import/targets 同步迁移);`moondoc` / `moon doc` 只认新格式——mooncakes 0.1.0 的「Documentation failed to generate」即服务端 moondoc 找不到 `moon.mod` 所致,迁移后发新版本号即恢复。注意:旧版 moon(stable 20260904 等)不认新格式,消费方需较新工具链。
- **双平台链接参数由 pre-build 钩子传播(当前方案,2026-09-12 实测入档)**:moon 的 `cc-link-flags` 是单一字符串、`targets` 条件编译无 OS 维度,链接参数无法按平台入库。现行机制:`moon.mod` 声明 `--moonbit-unstable-prebuild: scripts/prebuild.py`,moon 每次构建执行它,脚本按 `platform.system()` 输出 `link_configs` JSON,moon 把它**自动传播给所有依赖 yue 包的 main 包**——本仓 examples 与 mooncakes 使用方统一零配置,切换平台自动换参数。实测要点:
  - 脚本 **stdout 只能是最终 JSON**:任何 print(含子进程透传)都会导致 moon 反序列化失败(`invalid number at line 1 column 2`),进度信息一律走 stderr。
  - **不要用 `link_libs` 放 libyue_mbt**:moon 组装命令行时 `link_flags` 在 `link_libs` 之前,GNU ld 从左到右解析,`-lyue_mbt` 排在 `-lstdc++` 之后会 `undefined reference to __cxa_guard_acquire`。全部参数放 `link_flags` 单一字符串自控顺序(与旧响应文件同序)。
  - 脚本 cwd 是 **moon 调用目录(使用方项目根)**,定位自身必须 `Path(__file__)`;传播的库路径必须是**绝对路径**(链接命令的 cwd 在使用方侧)。
  - 原生产物缺失时脚本自动调 prepare.py 补建(产物存在时毫秒级返回),首次构建走 GitHub 下载。
  - 该机制官方标注实验性(`--moonbit-unstable-prebuild`),API 可能随 moon 升级变动;Windows 下 `python3` 命令可用性待真机验证。
  - 历史方案:先按系统回写 moon.pkg.json(两平台互相覆盖)→ `@build/link.flags` 响应文件(gcc/clang 与 cl 都支持 `@文件`,双平台同一份入库)。均已被传播机制替代。
- `prepare.py` 幂等可重跑:缓存 zip sha256 不匹配(下载被截断)自动删除重下;下载先写 `.part` 临时文件、校验通过才原子落盘。网络走标准 `http_proxy/https_proxy` 环境变量。
- **moon 不因静态库更新自动重链(跨平台,2026-09-15 Linux 实测)**:prebuild 只在静态库**缺失**时才调 prepare,且 moon 的重链判定只看 MoonBit 源与 link_configs 输出、不看静态库内容——shim/vendor 变更重跑 prepare 后,链接产物仍指向旧库。判别与处理见 [docs/relink.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/relink.md)。
- **shim 新增函数的三种死法(2026-09-16 实测,Linux 侧修复)**:「方法级审计补齐」批次(9-16)新增的约 90 个 shim 函数在 Linux 侧全部未编入,任何 MoonBit 调用即链接失败。三个叠加原因:①整段函数被错误圈进 `sys_*` 平台分支的 `#else(非 Linux)` 块(该段本应只含 sys 桩);②函数定义未写 `extern "C"`,符号被 C++ name mangling 改名,ffi 按 C 名解析找不到;③`yue_mbt.h` 的 `extern "C"` 块在 602 行被提前 `}`,605-697 的新声明全在块外(C++ linkage),与 cpp 侧定义冲突。段内另有六类真实编译错误被「挪进非 Linux 段」掩盖:Window 焦点信号名(`on_focus`/`on_blur`,lambda 参数为 `Window*`)、MessageBox `set_informative_text` 重复定义、`Table::Notify*` 是私有 API(GTK 端模型自动通知,Linux 桩 no-op)、`Appearance::SetDarkModeEnabled` 为 Windows 独有、审计段误用 `CastTo<>` 应为对应 `XStore::get()`(Linux 端部分类无 `kClassName`)、`base::JSONWriter` 需显式包含 `base/json/json_writer.h` 且 `ValueView` 按引用构造。修复:`#endif` 收窄到 sys 桩结束、统一 `extern "C" {}` 包裹审计段、头文件闭合点挪到文件尾、六类错误逐一改正。**新增 shim 函数的门槛:Linux 全量编译通过 + 声明进 `yue_mbt.h` 的 extern "C" 区 + `nm` 确认符号以 C 名字存在(出现 `_Z` 前缀即缺 extern "C")**。
- **MSVC 按 cp936 误读无 BOM UTF-8 源码,报「意外的 #endif」类假错误(2026-09-16 实测)**:ACP=936(GBK) 的机器上,中文注释的双字节序列会把后续字符(如下一行行首的 `#`)吞进字对,预处理指令被破坏;报错行号处根本没有 `#endif`。修复:CMake 对 MSVC 加 `/utf-8`(源码与执行字符集均按 UTF-8)。此坑对任何含中文注释的无 BOM UTF-8 源在中文 Windows 上必现,与代码内容无关。
- **shim 拖拽辅助函数把 GLib API 泄漏到 Windows(2026-09-16 实测,首次 Windows 编译审计段时暴露)**:`MakeFilePathsForDrag` 无平台保护地用了 `g_get_current_dir()`(GLib 仅 Linux 有)。修复:拆出 `CurrentDirForDrag`(Windows 用 `GetCurrentDirectoryA`)与 `IsAbsPathForDrag`(Windows 判盘符 `C:` 与 `/`、`\`),分隔符按平台给。教训:审计段/新增 shim 函数里引系统库前先确认该库在目标平台的可用性,GLib 系(`g_*`)是 Linux 专属。
- **shim 加新 FFI 后静态库过期,链接 `undefined reference to yue_mbt_*`(跨平台,2026-09-16 Linux 实测)**:shim/FFI 源码更新后未重跑 `prepare.py` 时,旧 `build/libyue_mbt.a` 缺新符号,用到新 API 的程序链接失败——2026-09-16 实测:shim 9-16 加入 `get_bounds_in_screen` 系列/`label_set_align`/`view_set_visible`,库停在 9-15,`moon run examples/showcase` 直接链接失败。两个加重因素:① prebuild 只在库**缺失**时才补建,库存在但过期不重编;② hello 等小示例不引用新符号,链接成功造成「构建正常」假象,必须用 showcase 验证。曾误判为 moon nightly 0911 的 test 构建回归(nm 对比库与 shim 符号后纠正)。修复:`python3 scripts/prepare.py` 重编 + `moon clean` 强制全仓重链。判别:`nm build/libyue_mbt.a | grep <新符号>` 零命中即库过期。同族坑见上条与 [docs/relink.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/relink.md)。
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

#### GNOME ✅ 实测通过(Ubuntu 24.04 原版,Wayland 与 X11 双会话,2026-09-15)

- 实测环境:ubuntu-24.04 虚拟机,GNOME Shell 46,`ubuntu-appindicators@ubuntu.com` 扩展默认启用(`gsettings enabled-extensions` 显示 `@as []` 是"默认值"表象,实际生效),`org.kde.StatusNotifierWatcher` 由 gnome-shell 持有。24.04.4 全新安装(原版桌面,默认 Wayland 会话;改 `/etc/gdm3/custom.conf` `WaylandEnable=false` 可切 Xorg 复测,两-session 均通过)。
- 托盘图标:顶栏正常渲染(IconPixmap 32+16 双档);SNI watcher 在线。
- **【修复】Menu 属性空菜单返回 `/` 导致 GNOME 点击图标全程无反应**(2026-09-15 实测入档):现象是图标显示正常但点击无菜单也无 Activate、dbus 零调用。根因:GNOME AppIndicator 扩展在**注册瞬间**就读 `Menu` 属性构造 DBusMenu 代理,而消费方 `Tray::new` 与 `set_menu` 之间有时间差,当时 `menu_items` 为空、属性返回根路径 `/` → 扩展代理指向无效对象(`journalctl` 可见 `UnknownObject: /`),菜单客户端永久坏死。XFCE/KDE/deepin 都是点击时才拉菜单所以不触发。修复:traybus 的 `Menu` 属性恒返回真实 `/MenuBar`(空菜单也导出,Qt 同款语义),后续靠 `LayoutUpdated` 通知填充。验证:dbus-monitor 见 Event/AboutToShow 流动、真机点击菜单三项回调闭环。
- 点击行为(GNOME 特有,`ItemIsMenu=false` 语义):左键/右键均发 Activate;实测菜单可弹出、项可点选,但弹出路径与 XFCE/KDE 不同(用户实测:菜单可开可点,退出闭环正常)。
- **全局快捷键在 Wayland 会话注册即段错误**(2026-09-15 实测入档):上游 `global_shortcut_gtk.cc` 直接用 `GDK_WINDOW_XDISPLAY(root)`(X11 专属宏),Wayland 下根窗口 impl 是 Wayland 类型,强转读出垃圾 `Display*` 传给 `XKeysymToKeycode` → SIGSEGV。修复:prepare.py `patch_linux_global_shortcut_wayland` 给 `Start/StopWatching` 与 `PlatformRegister` 加 `GDK_IS_X11_DISPLAY` 守卫,非 X11 会话 `Register` 返回 -1(既有失败语义)。X11 会话下 XGrabKey 行为不变。
- **鼠标键位是 yue 统一语义 1=左 2=右 3=中,不是 GDK 原始值**(2026-09-15 实测入档):libyue `ButtonFromGdkEvent` 把 GDK 的 2(中)/3(右)交换,全平台语义一致;showcase 菜单页曾按 GTK 惯例判 `==3` 为右键,导致"中键弹菜单、右键显示 2"(XFCE 同样存在,非 GNOME 特有)。
- 环境噪音(非本项目问题):spice-vdagent 在 Wayland 会话反复 SIGSEGV 弹 Apport 对话框(`/etc/default/apport` `enabled=0` 屏蔽);Wayland 空闲锁屏/息屏干扰自动化(`gsettings org.gnome.desktop.session idle-delay 0` + `lock-enabled false`)。
- SSH 远程起 GUI 进程的环境变量:X11 会话 `XAUTHORITY=/run/user/1000/gdm/Xauthority`;Wayland 会话 `XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.*`、`WAYLAND_DISPLAY=wayland-0`;两者都需要 `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`。SSH 环境缺 `XDG_CURRENT_DESKTOP` 会使 `desktop_name()` 返回 unknown(仅诊断信息,不影响功能)。

#### KDE ✅ 实测通过(Kubuntu 24.04,Plasma 5.27,2026-09-15)

- 实测环境:Kubuntu 24.04.5 虚拟机(X11 会话),面板托盘直收 SNI,新图标直接进可见托盘区(无折叠)。
- 全链路通过:图标显示 → 左键发 `Activate(x,y)`(回调贯通)→ 右键 Plasma 镜像渲染 DBusMenu(显示窗口/换图标/退出)→ 点「退出」回调触发 → `quit()` 干净退出(exit 0),图标即时消失。
- **协议行为与 XFCE 4.18 相反:KDE 发单条 `Event` / `AboutToShow`,不发批量版**(dbus-monitor 实证);traybus 两种都实现,无需分支。
- 环境准备:openssh-server 默认未装(GUI 终端 `sudo apt-get install openssh-server`);libwebkit2gtk-4.1-0 需补装运行库。

#### Deepin ✅ 实测通过(Deepin 23 社区版 + Deepin 25,DDE,2026-09-15)

- 实测环境:deepin 23 社区版虚拟机,glibc 2.38(Debian GLIBC 2.38-6deepin13),gcc 12.3,内核 6.6.84-amd64-desktop-hwe,X11 会话,`XDG_CURRENT_DESKTOP=DDE`。
- **dde-dock 实现 `org.kde.StatusNotifierWatcher`**,SNI 直连可用;新图标默认收进 dock 右侧「应用托盘」折叠区(点 `^` 展开),用户可拖出到常驻区。
- 全链路通过:折叠区图标显示 → 左键 `Activate` 回调贯通 → 右键 dde-dock 渲染 DBusMenu(三项齐全)→ 菜单点击回调 → 干净退出(exit 0),图标消失。协议为单条 `Event`。
- **宿主机二进制直接可跑**:Ubuntu 24.04(glibc 2.39)构建的探针在 deepin 23(glibc 2.38)运行正常——二进制 GLIBC 符号上限恰好 2.38,且 deepin 23 带 webkit2gtk-4.1 运行库(ldd 全解析);跨发行版分发不必逐环境重编,先查 glibc 符号需求(`objdump -T | grep GLIBC_`)。
- deepin 23 仓库**没有 openssh-server 包**(被引用但无可安装候选),远程管理走 virtiofs 共享 + GUI 终端执行脚本(安装器建的用户 noahliu 可 sudo)。
- 深度终端的 `script` 是 util-linux 标准版,注意命令须经 `-c` 传入(`script -q -f -c "cmd" log`),裸 `script -qf cmd log` 会报参数数错误。

- **Deepin 25(25.2)实测全链路通过**(Wayland 会话由用户确认;环境 glibc 2.38 / gcc 12.3 / 内核 6.6.143,`XDG_CURRENT_DESKTOP=Deepin`,宿主机二进制直跑):托盘探针折叠区图标/Activate/右键菜单/退出闭环。
- **DDE(23/25)下 Popover 气泡不可见且点击卡顿**(2026-09-15 实测入档):现象是点击「弹出气泡」无窗口出现、全局鼠标变钝。根因:libyue 的 Popover 是透明无边框窗 + `SetCapture` 指针抓取,DDE 合成器不渲染该透明窗、抓取又拖慢指针。修复:shim 检测 `XDG_CURRENT_DESKTOP`(23 为 `DDE`、25 为 `Deepin`,两种都要认),DDE 下回退无边框普通窗口(锚定控件 `GetBoundsInScreen` 正下方居中,不做指针抓取,点窗内关闭)。其余桌面仍走原生气泡。
- **deepin 25 移除了 openssh-server**(仓库无可安装候选):远程管理走 virtiofs 共享 + GUI 终端执行;deepin 23 同样没有该包。
- **`TextEdit::Delete()` 是删选区不是清空**(2026-09-15 实测):无选中时为空操作,「清空」语义要用 `set_text("")`(showcase 已改)。
- **showcase 在 DDE 的崩溃噪音**:DDE 剪贴板管理器交互时 libyue `Clipboard::Data` 构造报 `String data must be string type` CHECK(容错降级为 Text,不崩);`g_value_set_boxed` CRITICAL 为 GTK 与 DDE 主题交互噪音,不影响功能。

#### KDE / MATE / Cinnamon / Budgie / LXQt ❓ 未实测

- 协议层均支持 SNI(StatusNotifierItem),traybus 已按协议实现,预期可用;待逐一真实环境实测后在本节补充版本号与差异。

### DBus 线路协议坑(traybus 实测,桌面环境无关)

- DBus 数组长度前缀**不含首元素前的对齐填充**:算进去会被 dbus-daemon 判协议违规直接断连。
- DBus 头部 SIGNATURE 字段的 variant 签名是 "g"(u8 长度编码),按 "s" 编能过自洽单测但会被真实总线拒绝。
- **SNI `Menu` 属性必须恒返回真实菜单对象路径,空菜单也不能回 `/`**:GNOME AppIndicator 扩展注册瞬间即读该属性建代理,返回 `/` 会令菜单客户端永久坏死(详见「GNOME」节);Qt/ksni 同款语义是始终导出 `/MenuBar`。
- 教训:**单测证自洽,互操作必须上真总线验证**;discovery 类问题用 `dbus-monitor` 抓包定位,扩展/面板侧的 JS 异常看 `journalctl --user -u org.gnome.Shell@wayland.service`(gnome-shell 的 Gio.DBusError 行就是面板侧代理构建失败的第一现场)。

### 显示协议

- X11 ✅(当前唯一主链路)。
- Wayland ❌ 未支持(TODO 已列);libyue 的 GTK 后端以 X11 为准,迁移前不要在 Wayland 会话里验证 GUI 行为。

### GTK 相关

- Table(GTK)放进 Notebook 页签内会在尺寸测量时段错误(negative allocation),必须放普通容器或独立窗口(showcase 采用独立子窗口方案;2026-09-11 在 showcase 复现:崩前先出现 `Negative content width -1 (… owner GtkFrame)` 与 `GtkScrollbar` 的 `size >= 0` 断言)。
- **复合控件(Tab/Scroll/Group)在 yoga 树里是"无 measure 函数的叶节点",外框尺寸必须显式给出(flex/宽高),否则塌缩**。实测(2026-09-14,Ubuntu 24.04 + XFCE,showcase 声明式重写后):把 `Tab` 从直接作窗口内容(`SetContentView`,不进任何 yoga 树)改为挂进根 `Container` 后,整窗口签内容空白、页签以下不可交互,日志 `gtk_box_gadget_distribute: assertion 'size >= 0' failed in GtkNotebook` + `Negative content width -1 … owner GtkFrame`。根因三层:`Tab::Tab()` 构造时经 `UpdateDefaultStyle()` 把当时的 `GetMinimumSize()`(空 notebook ≈ 页签头高度)固化进 yoga minWidth/minHeight;`AddPage` 只设 View 层 parent、**不刷新该值**(libyue 上游局限);无 flex 时叶节点高度就停在固化值,notebook 页区域 = 分配高 − 页签头 ≤ 0。修复:给 `tab()` 节点 `("flex", 1.0)`(yoga 只管外框;页签页不进 Tab 的 yoga 树——`AddPage` 不做 yoga 插入,每页容器各自是独立 yoga 子树的根,由 GTK 分配页区域)。注意 `scroll_page` 曾误判为页内问题(490826b 对照实验),塌缩在 notebook 外框,与页内布局无关。
- **内容型控件的内容不走 `AddChild`**:`Group`/`Scroll` 直接继承 `View`(非 `Container`),挂内容必须用各自的 `SetContentView`;走 `Container::AddChild` 会被 shim 的 `CastTo<Container>` 类型校验拒绝(日志「类型不匹配，期望 Container，实际 Group/Scroll」),内容静默丢失。声明式层(`yue/declarative.mbt`)的 `group()`/`scroll()` 节点因此先把内容 mount 进一个临时 `Container`,再整块 `set_content`。切页瞬间的 `GtkNotebook` 断言在修复后仍少量残留(启动/切页瞬时布局噪音,CRITICAL 不致命),界面功能已全部恢复。
- **GTK 后端 NUContainer 的接缝缺陷(2026-09-14/15 实测,补丁见 `prepare.py patch_linux_container_events`)**。声明式重写把 Tab 包进根 `Container`、每页多包 `holder` 容器后暴露(旧版 Tab 直接做窗口内容视图,不经过这些路径):①`nu_container_map` 里事件窗口用 `gdk_window_show`(=map+**raise**),把覆盖容器全域的 INPUT_ONLY 窗口抬到子原生控件之上——X/GDK 命中被截走,**页签头点不动、滚轮失效,而按钮/键盘正常**(键盘走焦点,按钮/可编辑控件的窗口 map 更晚抬得更高);改 `gdk_window_show_unraised` 仅映射不抬高。②`nu_container_get_preferred_width/height` 硬编码返回 0,GtkViewport 以 child 的 size_request(上游被写为 0×0)计算滚动范围 → 滚动范围恒 0、滚动条不出现。**注意不要改成向 GTK 报告 yoga 动态自然尺寸**——allocate 会污染 yoga 状态,导致 requisition 协商震荡(实测 365→466→598→907 不收敛,布局停在中间帧,页面"有时不占满宽度");正确做法见③。③`Scroll::PlatformSetContentView` 对未挂载视图取 `GetPixelBounds()`=0×0 强制写入 size_request;改为:无显式 `SetContentSize` 时宽度保持 -1(随视口拉伸)、高度固化为内容 yoga 自然高度(经 `IsContainer()` 判别后向 `Container::GetPreferredSize` 查询)——滚动范围一次收敛且正确。`CreateEventWindow` 的 `attributes.y` 误写 `allocation.x` 笔误一并修正。
- **`Container::UpdateChildBounds` 开头的 `IsVisibleInHierarchy` 守卫让独立 yoga 根错过首次真实分配(2026-09-15 实测,同补丁函数)**。GTK 首次 size-allocate 发生在 map **之前**,此时整体可见性为 false → 守卫直接 return;map 后无人再以真实 allocation 重跑 yoga 布局,独立 yoga 根(每页 holder、Scroll 内容容器)永久停留在挂载时的自然尺寸布局——页内容"有时"不占满容器宽(是否必现取决于有无后续 resize 重分配)。修复:去掉整体守卫,布局计算无条件执行(`GetBounds()` 读的就是 size_allocate vfunc 已更新的 GTK allocation,提前布局安全;GTK 也允许对未映射 widget 预分配),孩子 bounds 传播仍受各自可见性限制;`nu_container_size_allocate` 里分配变化时补 `gtk_widget_queue_draw`。
- **`Slider::SetValue` 的 ignore 标记残留使滑块联动失效(2026-09-15 实测,同补丁函数)**:Linux 端拖动滑块,进度条与绑定标签不动。`Slider::SetValue` 无条件设 `ignore-value-change` 标记防回调循环,而 GTK 对"设置相同值"(yue 层 `Slider::make` 默认 `set_value(0)`,初值即 0)不发 `value-changed` → 标记残留,用户第一次拖动的首个回调被吞;xdotool 单点跳值场景恰只发一次信号,表现为完全失效。修复:仅当 `GetValue() != value` 才设标记。
- **`ProgressBar::SetValue` 的值域平台差异(2026-09-15 实测,修复在 shim)**:libyue Linux 端 `SetValue` 语义为 0..100(内部再 /100),yue 层统一 0..1 → 进度条只走到 1%(`v/100` 再被 /100)。已在 shim `yue_mbt_progress_bar_set_value` 按 `OS_LINUX` 条件编译换算 ×100;其余平台上游直接收 0..1。
- **`View::GetBoundsInScreen` 在 Scroll/嵌套容器下坐标叠错(全 Linux 桌面,2026-09-15 实测,补丁 `patch_linux_view_bounds_in_screen`)**:上游实现手动累加各级 allocation,视口文档坐标混入——showcase 页面滚到中下部时锚点 y 实测 1221(屏幕仅 1080 高),气泡被定位到屏幕外,表现为「窗口最大化才显示气泡、非最大化不出现」。修复:改用 `gtk_widget_translate_coordinates` + `gtk_window_get_position`(GTK 原生感知 viewport 滚动与嵌套),原逻辑保留为回退。所有屏幕坐标消费方(`popup_at`、气泡锚定)随之修正;新增 `ViewLike::get_bounds_in_screen` API(shim 4 个 ABI)。
- **表格 Checkbox 列指示器随行高缩放(XFCE 实测,2026-09-15,补丁 `patch_linux_table_checkbox_size`)**:GTK `CellRendererToggle` 的指示器在部分主题(XFCE)下不受 renderer `height` 控制——首版补丁只限 renderer 高度 20,showcase 表格演示窗口(未设行高)实测 checkbox 依旧填满整格;终版补丁对 Checkbox 列显式 `g_object_set(renderer, "indicator-size", 16)`(GTK 3.8+ 属性,默认 -1 即交给主题/字体),并保留 renderer 高度限 20,行高仍由文本列决定。补丁先 `g_object_class_find_property` 探测属性存在再设,防上游 GTK 变动。复现窗口(未设行高)截图像素级验证。

- **拖拽 FilePaths 数据被静默降级为 Text(XFCE 实测,2026-09-16,修复在 shim)**:shim 曾用 `Data(Data::Type::FilePaths, std::string)` 构造拖出数据,上游该构造只允许 Text/HTML,FilePaths 会被强制改写为 Text 并 NOTREACHED(即日志中 `String data must be string type` 的真正来源,此前误记为 DDE 剪贴板噪音);后果是拖出方实际提供文本而非 URI 列表,接收方按 FilePaths 请求得到空,表现为「拖入内容无法识别」。修复:shim 改用 `Data(std::vector<base::FilePath>)` 数组构造,并相对路径自动转绝对(`g_filename_to_uri` 不接受相对路径,绝对化用 g_get_current_dir 拼接)。**据此更正前文**:「String data must be string type」噪音在拖拽场景即此缺陷所致(剪贴板管理器交互场景另行确认)。showcase 拖拽演示同批改为:接收区分支显示 FilePaths/Text 可用性诊断;拖拽预览图 hotspot 补丁见 `patch_linux_drag_icon_hotspot`。
- **拖拽预览图垂在光标右下(Linux/GTK,2026-09-16,补丁 `patch_linux_drag_icon_hotspot`)**:上游 `gtk_drag_set_icon_pixbuf` 的 hotspot 写死 (0,0),预览图整体垂在光标右下;补丁改为图片宽高各半(中心对齐光标)。
- **GTK Entry/输入类控件慎用 `View::SetColor`(2026-09-16 实测)**:GTK 后端的 SetColor 会连带把 Entry 整体渲染为深色背景、文字不可见(override 语义覆盖 base 色而非仅前景);主题化输入框只应 `SetFont`,前景色保留系统样式。Button/Label 上 SetColor/SetFont 正常(组件库 button_t/label_t 依赖)。
- **主题组件不直接用原生 Button/Checkbox,交互行不挂子件(2026-09-16 实测,组件库 button_t/checkbox_t/radio_group 据此改全自绘)**:①原生 Button 设自定义底色后 hover 仍由 GTK 原生样式接管(深色遮罩盖掉自定义底),浅底变体的主题色字在深色 hover 上不可辨;②原生 Checkbox 悬停时主题画大号高亮圈,与直角低饱和主题冲突;③行级 hover 结构「父容器 on_mouse_enter/leave + 真 Label 子件」中,鼠标进入 Label 子件区域时父容器收到 mouse_leave,悬停效果在文字上消失。解法:交互项一律 Container 自绘(on_draw 画底 + draw_attributed_text 画字,on_mouse_enter/leave 切 hover 经 schedule_paint 重绘),文字不挂子件,hover 全区域生效。
- **GTK 端 `Painter::DrawAttributedText` 只实现 valign,水平 align 完全未实现(2026-09-16 源码确认,nativeui_jumbo_2.cc)**:实现里只按 valign 调整绘制起点后 `cairo_move_to` + `pango_cairo_show_layout`(pango 布局从该点向右下排布),`TextFormat.align` 被忽略,文字一律从区域左缘开始画;`draw_text` 内部即 `DrawAttributedText`,同样不受 align 影响。后果:所有「draw_text(align=Center)」在 GTK 上实际贴左——组件库 button_t 文字贴左、tag/avatar/steps/result/empty 的居中符号与文字全部偏左,固定方块(分页页码/头像/步骤数字)里的符号不居中;stateful_item 此前「居中正常」是 width=text_w+pad_x*2 两侧留白对称的巧合。修法:组件库统一手动水平居中——mount 时 `get_bounds_for` 测文本宽,绘制 x=(区域宽−文本宽)/2,align 保持默认,valign=Center 照常可用。
- **GifPlayer(GTK)不动画/不可见的三层修复(2026-09-15 实测,同补丁函数)**:①动画启动依赖 `IsVisibleInHierarchy()`(挂载于 Notebook 非当前页时为 false 跳过)与 `"show"` 信号(仅 `gtk_widget_show` 时发射一次,早于 SetImage 则错过)——切页 map 后无人启动 timer,永停首帧;补连 `"map"` 信号(每次实际映射发射,与 `"unmap"`→OnHide 对称,OnShow 幂等)。②drawing area 默认 no-window,嵌 NUContainer 链再进 Scroll 视口时 queue_draw 失效区域坐标归属错位——静止不重绘、整段空白、滚动时才留下一帧残影;改 `gtk_widget_set_has_window(TRUE)` 自建窗口。③**素材兼容性**:ImageMagick `convert` 生成的多帧 GIF 会让 gdk-pixbuf 的 iter 以约 1/9 速度爬行(纯 gdk-pixbuf C 程序可复现,advance 返回真但帧不轮换),换 PIL(pillow)生成即正常;且原素材本身是 45 字节损坏文件。GifPlayer 是 yoga 叶子且 `GetMinimumSize` 在默认 `ImageScale::Down` 下返回空,消费方需显式给宽高(showcase 用 `style=[("width",120),("height",120)]`)。

---

## Windows ✅ 首次实测通过

### Windows 10 / 11 ✅(2026-09-12 实测:Windows 10.0.19045 x64 + MSVC 14.44 + Windows SDK 10.0.26100 + moon 0.1.20260904)

#### 工具链准备(现象→根因→修复)

- **moon 原生后端要求系统 C 编译器**:PATH 上找不到 `cl/cc/gcc/clang` 直接报 "no system C compiler found"。修复:装 VS Build Tools(`Microsoft.VisualStudio.Workload.VCTools`),并在 **x64 Native Tools Command Prompt**(或先 call `vcvars64.bat`)里执行 moon/cmake。
- **libyue Windows 源码需要 ATL 头**(`base/win/atl_throw.h` → `atldef.h`),VCTools 工作负载默认不带:报 C1083 找不到 atldef.h。修复:VS Installer `modify --add Microsoft.VisualStudio.Component.VC.ATL`。注意 **quiet/passive 模式必须从提权进程启动**,否则立即退出且 Exit Code 5007(日志在 `%TEMP%\dd_installer_*.log`)。
- **`prepare.py` 下载 404**:发行包资产名与 `platform.system()` 不同名——实际是 `libyue_{v}_win.zip` / `_mac.zip`(不是 windows/darwin)。已修 `prepare.py`(ASSET_OS 映射),macOS 路径顺带修好。
- **hostshare/大小写敏感卷上编译 WebView2 头 C1083(2026-09-16 实测)**:仓库经大小写敏感的共享卷挂载到 Windows(Z: hostshare)时,libyue 的 `browser_impl_webview2.h` 写死 `#include <webview2.h>`(小写),而 SDK 只给 `WebView2.h`(大写 W)——普通 NTFS 大小写不敏感无感,敏感卷上 cl 直接 C1083。修复:`prepare.py` 的 `fetch_webview2_sdk` 解压后自动补 `webview2.h` 小写别名(NTFS 上无害)。同类坑:挂载卷上建 `.caseprobe_AAA.txt` 后按小写名查不到即敏感卷,构建 libyue 前先探。

- **`prepare.py` 的 Linux 补丁调用漏在平台分支外(2026-09-16 Windows 实测抓到)**:`patch_linux_drag_icon_hotspot()` 缩进错误落在 `if os_name == "Linux"` 之外,Windows 上 prepare 必崩(`FileNotFoundError: vendor\libyue\src\linux\...`,Linux 恰好能跑故一直未暴露)。修复:挪回 Linux 分支内。教训:平台分支补丁的新增调用务必确认缩进在对应 `if` 内;Windows 侧跑一遍 prepare 是发现此类问题的最快手段。


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
- **声明式整页滚动失效(2026-09-14 实测,与 Linux GTK 同根因的 Windows 版)**:现象是各页签内容只能看开头、滚轮无反应、滚动条不出现。根因:Windows 的 `ScrollImpl` 用自绘滚动条,滚动范围只来自 `content_size_`,而它只能经 `Scroll::SetContentSize` 显式写入(初值 0×0);声明式 `scroll()` 节点内容高度动态、从不调 SetContentSize,范围恒 0。修复:prepare.py 新增 vendor 补丁——`scroll_win.h` 加 `content_size_explicit_` 标记,`ScrollImpl::Layout` 在未显式设置时向内容视图的 yoga 树实时查自然尺寸(`GetPreferredSize`),尺寸变化即重建滚动条;与 Linux 端 nu_container preferred 尺寸 + size_request 两处补丁同一思路。验证:showcase 各页签滚轮整页滚动、滚动条出现并随内容更新。
- **WebView2 页面一律报「无网络」(2026-09-14 实测)**:现象是 WebView2 引擎加载任意远程站点都出错误页,应用本身与直连网络正常(直连 curl 200)。根因:WebView2(Chromium)默认跟随系统代理,本机系统代理 `ProxyEnable=1` 指向 `127.0.0.1:7890`(Clash 类工具退出未还原设置),代理端口无监听 → 所有请求 ERR_PROXY_*;IE 回退路径走 WinInet 同样受影响。修复:libyue 未暴露 AdditionalBrowserArguments,prepare.py 补丁让 `GetWebView2Options` 读环境变量 `LIBYUE_WEBVIEW2_ARGS` 并 `put_AdditionalBrowserArguments` 注入——代理失效的机器设 `LIBYUE_WEBVIEW2_ARGS=--no-proxy-server` 即直连(见 showcase 网页页说明)。验证:设变量后 `moon run examples/showcase` 网页页完整渲染 moonbitlang.com(Chrome Legacy Window 确认 WebView2 引擎)。
- **按键键码与修饰键跨平台不一致(2026-09-14 实测)**:现象一,Windows 上按键显示的数字与 yue 常量表(VKEY_ESCAPE=65307 等)对不上,比较恒 false。根因:libyue Windows 的 KeyboardCode 是 Win32 VK 值(Esc=0x1B),常量表取的是 keyboard_codes_gtk.h 键值(Esc=0xFF1B);修复:`yue/events.mbt` 事件入口 `normalize_win_vk` 把 VK 码归一化到常量表(字母/数字/空格两表本就同值),并新增 `KeyEvent::describe()` 输出 "Ctrl+A" 形式可读描述。现象二,Ctrl+A 显示成 Alt+A、Shift+Enter 显示成 Ctrl+Enter。根因:libyue Windows 修饰键位是 `Shift=2 Ctrl=4 Alt=8 Meta=16`,shim 的 `NormalizeModifiers` 只有 Linux/macOS 分支做归一化、Windows 原样透传,位值撞上 MoonBit 层 `KEY_MOD_ALT=4`。修复:shim 补 `OS_WIN` 分支映射到统一的 `1/2/4/8`。验证:真机按 Ctrl+A 显示「按键 Ctrl+A(键码 65,Esc=65307 A=65)」,键码与常量一致、修饰键正确;纯函数部分白盒单测覆盖(`events_wbtest.mbt`)。
- **非正常退出留「幽灵托盘」图标(2026-09-14 实测)**:现象是进程崩溃/被关控制台/abort 后,托盘残留月亮图标,直到鼠标扫过才被 Explorer 惰性清理。根因:图标删除全靠 `nu::Tray` 析构时 `NIM_DELETE`;shim 的 TrayStore 全局持有引用,正常退出靠 CRT 静态析构链(Store 析构 → 引用归零 → TrayImpl 析构)兜底,异常退出这条链不跑。修复:shim 在首次创建托盘时捕获 TrayHost 属主窗口并安装四道进程级钩子(`atexit`/`SetConsoleCtrlHandler`/`SetUnhandledExceptionFilter`(链式传递前一过滤器)/`signal(SIGABRT)`,libyue 的 CHECK 失败走 abort),凡还有代码可执行的退出路径都按「属主窗口 + 图标 ID 区间」补发 `NIM_DELETE`——libyue 的 ID 从 2 起连续分配、只增不复用,对已删除 ID 是无害空操作。`taskkill /F`/TerminateProcess 式硬杀没有任何进程代码可执行,幽灵无法在进程侧根除,由系统悬停时惰性清理。验证:真机图标可见 → 关闭其控制台窗口 → 图标立即消失(鼠标移开排除悬停清理干扰)。另注:新托盘图标默认进溢出区,是否常驻可见区由系统/用户逐图标设置(设置 → 个性化 → 任务栏 → 选择哪些图标显示在任务栏上),应用无法强制。
- **托盘图标显示为空白不是引擎问题,先查图标资产(2026-09-14 实测)**:showcase/hello 的 `icon.png` 从建库起就是 1×1 占位图,libyue 按其像素拉伸到托盘尺寸(SM_CXSMICON),结果就是一团白——表现像「图标没渲染」,实为资产问题。修复:用 PIL 绘制抗锯齿月牙(512×512 绘制后 LANCZOS 缩到 64×64)替换两处。排查顺序:确认 Image 非空(shim 已有 IsEmpty 拦截)→ 看资产本身尺寸/内容 → 再怀疑 GetHICON/NIM_MODIFY 链路。
- **本轮复测还确认**:`moon test` 的测试驱动在安装新版 moon 后需 `YUE_MBT_SKIP_MANIFEST=1`(CI 同款,规避新版 moon 自带 MANIFEST 与 manifest.res 的 CVT1100);且 moon 不因静态库更新重链对测试驱动/showcase 同样成立——换 `yue_mbt.lib` 后要删 `_build` 下对应 exe 再跑,否则拿到旧链接产物误判(见上「链接参数」节)。
- **Popover 气泡在 Windows 的替代实现**:libyue 无 Popover(见下),shim 用无边框、不抢焦点、置顶的小窗口替代,弹在点击位置右下,8 秒定时自动关闭(无外部点击关闭钩子),`close`/`on_close` 语义保留;验证:showcase 气泡按钮弹出/自动关闭/日志闭环。
- 平台信息(`platform()=="windows"`、区域、缩放、屏幕)、剪贴板、定时器、全局快捷键注册、全局鼠标轮询、画布(GDI+)与浮动爱心窗口均实测正常。

#### 验证方式

- `moon run examples/hello`:窗口渲染 + 托盘 + 点关闭经 `on_close→quit()` 优雅退出。
- `moon run examples/showcase`:8 页签逐一点击(基础控件/输入与选择/画布/网页/对话框/系统集成/事件/富文本)、菜单(勾选/单选/表格独立窗口)、消息框、画布色相重绘、鼠标事件实时回显、全局鼠标、浮动爱心、关闭退出,全程日志零 CHECK 失败。
- 2026-09-14 复测(新版 moon + 声明式 showcase 12 页签):`moon check` 零警告、`YUE_MBT_SKIP_MANIFEST=1 moon test` 30/30 全过;真机逐页截图确认——整页滚轮滚动、滚动条出现;网页页 WebView2 完整渲染 moonbitlang.com(设 LIBYUE_WEBVIEW2_ARGS=--no-proxy-server);事件页按键显示 Ctrl+A/Esc,键码与常量表一致。

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
