# 平台适配经验

moonbit-libyue 在各平台适配过程中的实测经验与坑,全部来自真实环境验证。
主 AI 文档(仓库根 `AGENTS.md`,ZCode 读取)经 `@docs/adaptation.md` 引入本文件;以本文为平台适配坑的持续更新详版(README 只留指针,不再展开)。

**组织维度**:Linux 按「发行版 → 桌面环境 → 版本」三层;Windows / macOS 按「版本」。
**状态标记**:✅ 实测通过 / ⚠️ 部分可用或带条件 / ❌ 不可用 / ❓ 未实测(占位,待补)。

---

## 跨平台通用(构建链 / FFI,不分平台)

### 构建与链接

- `moon` 命令必须在**仓库根**执行:`cc-link-flags` 回写的是仓库根相对的 `-L build`,链接器按 moon 的调用目录解析相对路径,子目录调用直接找不到 `libyue_mbt.a`(2026-09-11 实测确认)。
- moon 的 `link` 段只作用于所在包、只对 main 包的二进制生效;库包(如 `yue/`)放 link 段会让 moon 生成无 main 的 `.exe` 导致构建失败。`prepare.py` 只回写 `is-main` 的包。
- `prepare.py` 幂等可重跑:缓存 zip sha256 不匹配(下载被截断)自动删除重下;下载先写 `.part` 临时文件、校验通过才原子落盘;内容未变的 `moon.pkg.json` 不回写(避免 mtime 触发无谓重链)。网络走标准 `http_proxy/https_proxy` 环境变量。
- libyue 版本钉死在 `scripts/prepare.py`(`LIBYUE_VERSION` + 三平台 sha256),升级需同步更新三个校验和。

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

## Windows ❓ 未实测

### Windows 10 / 11(libyue v0.15.6 发行包含 Windows 源码,本项目未实测)

- `prepare.py` 对 Windows **直接跳过链接参数回写**,需手工核对各 `moon.pkg.json`;链接参数自动化在 TODO(中期)。
- FFI 层注意:设置 `cc`/`cc-flags`(含 `-I`/`-L`)会破坏 Windows 可移植性,仅在链接系统库时使用(见 `.agents/skills/moonbit-c-binding/`)。
- 版本细分(Win10 与 Win11 的 WebView2/工具链差异)待实测后补充。

---

## macOS ❓ 未实测

### macOS(libyue v0.15.6 发行包含 ARC / no-ARC 双库结构)

- CMake 已备 ARC/no-ARC 双库分支,均未验证;首次实测先确认两种链接形态哪条走通。
- 版本细分(按 macOS 大版本)待实测后补充。

---

## 维护约定

1. 每次真实环境实测后,把「发行版 / 桌面环境 / 版本 + 现象 + 根因 + 修复 + 验证方式」写进对应小节;新发行版/桌面从 ❓ 占位小节开始。
2. 涉及协议互操作(DBus / DBusMenu / SNI)的结论必须来自真总线、真面板;单测自洽 ≠ 互操作通过。
3. 简短结论同步 README「Known Limitations / known pitfalls」;本文保留完整过程与版本细节。
