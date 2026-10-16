# 路线图 — MoonBit 原生 GUI 栈

记号：`[x]` 完成 · `[~]` 部分（缺口写在子条目）· `[ ]` 未开始。

- **唯一主线**：自绘栈（新栈拥有窗口/像素/事件循环/布局，控件全部基于 Painter 自绘 + 自定义主题，不提供独立原生控件）。
- **更名与目录定案（2026-10-12）**：主模块 `NoahLiu/moonbit-libyue` → **`NoahLiu/native-gui`**（mooncakes 新包名，首版 0.1.0 占位；待自绘栈稳定后将 `NoahLiu/moonbit-libyue` 标记废弃）；子模块 `NoahLiu/yue-media` → `NoahLiu/gui-media`、`NoahLiu/yue-examples` → `NoahLiu/gui-examples`；**库模块根落在 `gui/`**：13 个库包（`gui/core` … `gui/style`；原 `gui/web` 于 2026-10-16 G9 Batch 1 出成独立模块 `modules/gui-webview`）与 `moon.mod` 都在其下，模块名不变故 mooncakes 包路径 `NoahLiu/native-gui/<包>` 与既有 import 全部不变；`examples/`、`experiment/` 拆为**独立模块**（`NoahLiu/native-gui-examples` / `NoahLiu/native-gui-experiment`），经 `moon.work` 本地解析依赖库模块，构建/测试不再牵连库门禁；旧链 `yue/` 已删除。GitHub 仓库名 2026-10-13 已改为 **`moonbit-native-gui`**（旧名 301 重定向）；项目显示名（README 首行、文档站 title/hero、许可行）2026-10-15 随 0.1.1 重发统一为 **native-gui**，旧名只留更名注。
- **本分支不保留老 libyue 绑定**：`shim/`、`lib/` 预构建库、`scripts/prepare.py` 已删除；libyue 只作**老师**（行为参考、可平移资产来源、`patches/` 的真实 bug 语料）。
- **路径搬家注（2026-10-16）**：本文件历史条目里的 `gui/web/…`、`NoahLiu/native-gui/web`、`moon test ./gui/web` 均指已出模块的 webview 线，现落位 `modules/gui-webview/webview/`（包 `NoahLiu/gui-webview/webview`），不逐处改写。
- **旧链路的完成项与实测结论不在本文件重述**：代码在 `master`（`shim + libyue`，0.5.x 与 `bin-*`/`vendor-*` 发布照旧），踩坑与验收细节在 [docs/zh/adaptation.md](docs/zh/adaptation.md) 与 `git log`。**凡旧栈做过、新栈尚未重做的能力，本文件一律记为未完成。**
- **门禁口径**：全仓 `moon check --deny-warn` 零错误零警告（2026-10-15 复核；2026-10-11 起曾为红基线 287 errors / 68 warnings，逐批清零）；库门禁在 `gui/` 下按包限定跑 `moon check` + 分包 `moon test`，`examples/`、`experiment/`、`modules/*` 各模块 `--deny-warn` 复核。
- **验证示例归口（2026-10-16 收口）**：native-* 累积验证板已全部删除（`examples/native-app`、`examples/native-window`、`examples/systemprobe`、`modules/gui-examples/native-web`、`modules/gui-examples/systemprobe`），职能归正式示例——GUI 能力与系统能力只读探测归 `examples/showcase`（含第 15 页「系统能力探测」与任务栏进度/粘性列表/GIF/自绘消息框/字体回退/bind_node 各段）、浏览器归 `examples/browser`、媒体归 `modules/gui-examples/audio` / `video`、扩展图表归 showcase「图表」页的扩展/新图表/交互三段（2026-10-16 由独立示例 `examples/charts` 并回后删除）。后续新能力的演示一律直接进对应正式示例（或库测试），不再新开 native-* 验证板；本文件历史 `[x]` 条目里的 native-* 提及保持原样，不改写。
- **跟踪口径（2026-10-12 定）**：本文件**只跟踪跨平台能力**（三平台同构的 API 面、或「一个门面 + 各平台后端」的形态）。**纯 Linux 依赖的实现细节不再列为待办**——xrandr / wmctrl / xclip / sysfs / wpctl / pactl / CUPS / redshift / xfconf / gsettings / xdg-* / D-Bus 等命令线与总线面的适配，属「Linux 后端内部事务」，随各自能力批处理时按需实现，不进路线图。判据：一个条目若只在一个平台有意义（换个平台没有对应 API 可做）→ 不进 TODO；若换个平台有对应 API（tray/hotkey/通知/剪贴板/文件对话框/菜单栏…）→ 进 TODO，且**以「门面定形态 + 各平台后端」记账**。

## 1. 地基（新栈自身进度）

> 已完成的功能点全部收进 [docs/zh/roadmap.md](docs/zh/roadmap.md)「功能面全景」；本节只留未完成项。

- [~] **G5b** 输入通道补齐
  - ibus 一套复验（探针侧归因 libpinyin display-style，待确认）
  - macOS：`NSTextInputClient`（前置：有 mac 真机）
  - 肉眼确认项：preedit 下划线观感、候选窗是否贴组合串末尾、caret 闪烁观感（点击定位已用 xdotool 客观验通：点控件最左端 caret 归 0、原位插字符）
- [~] **G7** 声明式层与组件宿主接线（`mount` 目标从 `View` 换 yoga-mbt 节点；恢复全仓门禁。宿主与声明式地基已就位：`@core.App` + `@core.Widget` 树 + `@core.Node`/`bind_node`/`swap_node`/`Store`/`Signal`，验证页 `examples/native-app`；剩组件与图表挂新 Painter）
- [ ] **G8** 原生子表面通道与其消费者（见 §4「浏览器」「视频」）
- [~] **G9 模块拆分**（方案与判据见 [docs/zh/module-structure.md](docs/zh/module-structure.md)：外部重资产 + 必须强制下发链接参数 → 开模块；纯内部层 → 留子包。细案与验收在该文 §6.1/§6.2；**Batch 1（web 出模块）2026-10-16 已交付**；**Batch 2 进行中**——2026-10-17 完成步骤 1（`gui/base`：signal/store/effect/keys/focus/list_store/prof/tick 八文件 + 六条 wbtest 出包，core 挂 `compat.mbt` 薄转发层，下游 `@core.*` 零改动）与步骤 2·甲（`gui/shell`：menu/hotkey/tray/notify/reveal 五族 + 五条 wbtest 出包，`compat_shell.mbt` 转发；枚举变体无法同名转发——TrayError 与 HotkeyError 各有 `Unsupported`/`Failed`，外部消费方 showcase/menu_probe/hotkey_probe 已直接改 `@shell.`，这也是终态写法），步骤 2·乙已落：首批（`loop.mbt`+只读探针进 shell、`pub type Loop=@shell.Loop` 门面化）与核心手术（`Session` 承载平台窗/泵/退出/IM 缓存/整窗脏位，`host.mbt` 瘦身为「窗号→App」半本账，`App={session, root, …}`，`test_app` 通道补外部假宿主——全细节与五条实测坑在 module-structure.md §6.2）。步骤 3 已落（`gui/widget`：widget/node/overlay/overlay_native/popup/drag/input_map + `app.mbt`/`host.mbt` 全量入住，core 退为纯门面 `compat*.mbt`；全仓 `@core.Down` 一类裸变体约 290 处已改 `@widget.PointerKind::Down` 全限定形态——别名转不出构造子，实测）。剩集中改 import（ui/chart/mdview/style 与模块外消费者从 `@core.` 切到 `@base.`/`@shell.`/`@widget.`）与门面退场）
  - [ ] **Batch 2：`core` 三刀拆 `base`/`shell`/`widget`**（2-3 天，三条路线共用的地基）：**先解 `core/app.mbt`（914 行，一个人吃 `@render @text @theme @win @yoga`）再改 import**，反过来中途编不过——开窗/泵/子件槽/resize 段提进 `shell`，`root.on_draw` + `paint_frame` 留 `widget`，`shell` 对外给 `ShellApp`（不含 Painter）。**import 迁移清单必须含模块外消费者**：`ui`/`chart`/`mdview` 之外还有 `modules/gui-media`（引擎 + 两组件 + 控制条，将来同时吃 `@base`+`@shell`+`@widget`+`ui`）、`modules/gui-examples`、`examples/`、`experiment/`——它们经 `moon.work` 本地解析，不在主模块门禁视野里，漏一个就是「已推送的树断链」（拆包一批踩过 15 处）。过渡期可用聚合包 `GuiCore = { base|shell|widget }` 收一半改名再全量替换——**但本工具链没有 `pub use` 再导出**，聚合包只能自己写薄转发层；`@core.` 实测出现 3528 次（主模块内 2302），按这个量级拍「过渡包 vs 一步改完」，别默认前者省事。
  - [ ] 未决（随 Batch 2 定案）：`Webview::bare(app, url)` 的入口签名取决于 `ShellApp` 公开面；`@core.*` 大量既有调用点要不要 re-export 过渡期；`gui-3d` 是自建 GLFW/GL 上下文还是复用 `win` 子件槽挂 canvas（影响 `shell` 要不要多一层抽象）。
- [ ] **G10 窗口内按键路由补齐**（2026-10-16 播放器快捷键一批暴露的面）
  - [ ] **抬起事件不投递**：`App::route` 的 Key 分支开头 `if !kev.press { return }`（有因：编辑内核 `handle_key` 不区分按下/抬起，放行抬起会「松手再插一个字符」，实测 Tab 抬起插成 `'\t'`）。代价是**任何组件都拿不到 key-up**——「按住空格快进、松手停」这类播放器/游戏形态做不了。要的是把判据从「一刀切丢弃」改成**按焦点控件是否声明要抬起**（如 `Widget.on_key_release` 或 `on_key` 返回消费后再投抬起），并保住编辑内核那条回归。
  - [ ] **焦点链会抢走窗口级兜底**：`ui.button` 的键盘口径是「空格/回车激活」。于是用户 Tab 过任何一个按钮之后，空格就不再是播放器的「播放/暂停」而是「按下那个按钮」——与 Web 一致，但播放器用户预期相反。待定口径：播放器快捷键是否要**优先于**焦点链（给 `add_key_fallthrough` 加「抢占档」），还是把按钮激活键收成只 `Enter`（改 ui 公共行为，波及所有表单）。先立判据再动：同一窗内「Tab 到按钮 + 按空格」的期望行为写进契约与 wbtest。
  - [ ] **方向键与滚动/焦点导航的归属**：`←/→/↑/↓` 在 `ui.slider`、`ui.input`（光标移动）、滚动容器与本批的播放器音量键之间目前**没有优先级记录**——同一条键谁先吃，靠的是「焦点链先问、兜底后问」这条隐式规则。要把可达路径写成表（哪个控件在焦点上时四个方向键分别归谁）。
  - [ ] **输入法门控下的按键可达性复验**：非输入框焦点时，ibus/fcitx 会话里字符键可能被 IM 吃掉只剩修饰键（真机旧症状：回显恒 65507 = Control_L）。`App` 侧有 IM 焦点门，但**播放器快捷键全走 keysym 字符键之外的键**只是绕开、不是解决；要在带 IM 的真机跑一轮「焦点在播放器上按空格/方向键」的复验并记结果。

## 2. 框架能力域 — 全部待在新栈重做

> 清单已按 master 线参考副本逐包核对（2026-10-11，`/home/lkyh/ownCode/moonbit-libyue` 的 master，比本仓 origin/master 新）；条目里的文件/函数名均指 master 现行资产。

### 绘图与资源

（已交付面见 [roadmap.md](docs/zh/roadmap.md)「绘图与资源」。）

- [~] 图片解码后端：macOS 未接（Linux GdkPixbuf、Windows WIC 已落并纯 C 探针回证）
- [~] 文字后端：macOS CoreText 未接（Pango、DirectWrite 已落；行高 K 地板与缺省字族已定案）

### 前端化批次（design.md §5 的 P1–P5，2026-10-13 起）

（P1 样式层、P3 响应式补强、P4 绘制能力、P5 动画 `transition` 与逐组件样式通道已交付，见 roadmap「组件层与前端化」；真机反馈修复集迁入 adaptation。）

- [~] **P2 组件层**收尾：
  - [ ] P2-e 边界②：`chip` 的 `class` 只吃颜色与显式宽度——字号在挂载期参与测量宽，class 改字号不会跟着改宽，真要改字号请调用方给 `width=`/`class=[style(width=…)]`；
  - [ ] 观感逐页比对不回退（真机由用户复验，`examples/hello`、`hello-themed`、`showcase`、`native-app`、`sysmonitor`）。

### 控件（一律自绘，不再引入原生控件皮肤；家族名对应 master `yue/components/` 九个源文件）

（九族件数与清单见 roadmap「控件与组件清单」。）

- [~] 基础原语：`group`/`separator`/标签/图像/图标/按钮已落新包 **`ui`**（首批 7 件，另附 `container`；文本 measure/baseline 首次回灌布局引擎，`on_pointer`/`on_draw` 首参为控件本身以免自捕获引用环；`type=` 因是保留字改 `kind : ButtonKind`；`yue/components` 属旧链路红点，按批替换）；表单族 15 件已全部落 `ui/form.mbt` + `ui/entry.mbt` + `ui/textarea.mbt`；`tab` 已由 `ui/nav.mbt` 的 `tabs_t` 承担（页签头行 + 预建页区显隐），`scroll` 已落 `ui/scroll.mbt`（垂直滚动容器 + 自绘滚动条，平移用 yoga 新补的相对定位偏移），`splitter` 已落 `ui/split.mbt`（`hsplit`/`vsplit`）、`combo` 已落 `ui/form.mbt`

### 主题、声明式与应用层
- [~] 主题系统
  - 新栈刻意不做：原生控件 CSS 下发（全自绘后色板是唯一来源）
- [~] 声明式层（`declarative/` 612 行、24 构造器）：地基已落（`Node{mount:(Widget)->Widget}`、`node_of`/`node_of_new`/`mount_children`/`App::mount`、`invalidate` 回路）；**L1 构造器全集落 `ui/declarative.mbt`**——`vbox`/`hbox`/`text_edit`/`picker`/`scroll`/`tab`/`date_picker`（改名者，旧调用点原样跑在新栈上）+ `mount_window`（建宿主并挂载）+ `bind`/`bind_label`（Store/信号驱动的文本绑定），与组件**同名**的（`label`/`button`/`entry`/`checkbox`/`container`/`group`/`separator`/`image`/`icon`/`radio_group`/`slider`/`progress`）直接用组件、不再包第二层；`hover_group` 已落（本栈宿主悬停态是父链语义，旧链路那套全局指针轮询不需要）；`overlay_scroll` 即 `scroll_v`（滚动条一直是视口的绝对定位子控件）。`cursor_group` 已落（配套新增窗口层光标通道：`wm_set_cursor` FFI + `Widget.cursor` 请求 + 宿主按悬停路径取「最深非零」下发）；`combo`（可编辑下拉：`entry` + 随输入过滤的候选浮层，↑↓/回车/Esc 走按键沿祖先链冒泡）已落 `ui/form.mbt`；`gif`（动图组件，走 `@render.Animation` 的逐帧迭代 + 进程级延时通道）已落 `ui/gif.mbt`。**L1 构造器全集到此收口**（旧 24 个里除 `mount`（即 `App::mount`）与同名组件外都已到位）。
- [ ] 富文本编辑（远期 WYSIWYG 块编辑器）
- [ ] 代码高亮、终端模拟器、WebGL 画布（旧栈即无，列为待评估）

### 系统集成（master 参考面：`yue/system` 31 源文件 + `yue/traybus` 16 源文件，属可平移资产）
- [~] A 类平移 · 环境/文件原语
- [~] A 类平移 · 硬件族（六进 sys；sensor/bluetooth 走 @traybus、disk 走 UDisks+@traybus，随 DBus 线）：
  - [ ] `sensor`（iio-sensor-proxy）/ `bluetooth`（org.bluez）/ `disk`（UDisks2）随 DBus 线（**仅 Linux 有对应面，按新口径不进路线图**；如需启用另立 Linux 侧文档）
- [~] A 类平移 · 会话与状态：`power`/`session`/`powerctl`/`online`/`idle`/`keepawake`/`clipboard_watch`/`locale_sys`/`sysinfo`/`windowctl`（monitor 已随硬件族提前）
  - [~] `power`/`session`/`online`/`keepawake`/`powerctl` 的**总线能力已在 `dbus`**（`upower.mbt`/`logind.mbt`/`netmon.mbt`/`inhibit.mbt`，真总线回证）；`sys` 侧与旧链同名的语义化包装（电量读数、挂起/休眠动作、在线判定、抑制睡眠）待随各能力线补——**总线面为 Linux-only，按新口径不进路线图**；如需在非 Linux 提供同类能力，走 §6 的跨平台门面（如 W21a 通知）
- [~] DBus 系在新事件循环下**重写/重验**：SNI 托盘（`traybus/sni.mbt`）、通知（新栈须重写 `org.freedesktop.Notifications`，含 `Notification::set_progress` 进度文本）、logind（`SetBrightness`/inhibit）、UPower、NetworkManager（`netmon`/`online`）、屏保 `screensaver`、媒体键 MPRIS（`media` 含状态监视轮询）
  - **非 Linux 后端**：D-Bus 线本身是 Linux-only（`dbus_stub.c` 在 `_WIN32`/`__APPLE__` 为失败桩），但 **SNI 托盘 / 通知 / MPRIS 的跨平台面**已按新口径收进 §6（W20c 托盘、W21a 通知）；其余（logind/UPower/NetworkManager/屏保/inhibit）**无跨平台对应面，不再跟踪**
- [ ] 新建项（master 全仓无资产，属新做）：**任务栏进度 / dock 徽标** 已收进 §6.3（W20 批，三平台各有原生面）；**勿扰** 随 W21a 通知门面
- [ ] 平台分派：**跨平台能力的各平台后端按 §6 批次推进**（Win 基础能力 W20 / MBT 通用门面 W21）；master 有 Win32 直连族与 mac ObjC++ 族可参照

### webview 与媒体（角色区 pane 模型；已锁决策与批次验收见方案 §4）

窗口内容 = 1..N 个互不重叠的矩形区（pane），每区声明 owner（自绘 = Painter / webview = 原生子件），矩形由 yoga 布局给；Tauri-like、爬虫内容获取页、原生多窗口三种形态同源。**本轮只做 Linux 闭环**，Windows/macOS 后端归输入通道另线与平台批。

- [~] **批 C JS 桥 + DOM 抓取 + 导航面**（已完成面见 roadmap「webview 与原生子表面」；剩余见子条目）
  - [ ] 批 C 余项（仍待接）：跨窗共享的 cookie 同步（`get_cookies_for_url` 是 per-view 回包，多 pane 同 profile 时的同步策略没定）
  - [ ] 一条待查观测（不影响本批结论，且**不是每次都出现**）：协议页首屏在事件区偶发出现**两次** `导航开始 yuedemo://local/bridge.html`（出现时 `navs` 比真实导航数多 1）。同一份示例复跑四次的 `navs` 读数依次为 4、1、1、1，所以这条不是协议页的固定行为，更像引擎侧偶发的一次额外 `load-changed::STARTED`。已排除本栈双路径（`load_url` 在未挂载时只记 `self.url`，`wb_create` 建视图时才 `load_uri` 一次）。要定案就在 `wb_on_load_changed` 里带上 `load_event` 原值与 `webkit_web_view_get_uri` 的读数对照多轮，判据先立再改，不改行为
- [~] **批 D 媒体播放器**（可与 B/C 并行）：复用 `modules/ffmpeg-mbt`（零 libyue 依赖，已有 `decode_rgba`/`decode_pcm`/`seek`/`duration_s`/`video_fps`）+ `modules/gui-media` 内嵌的 miniaudio 设备层；**CPU 回灌 + 软解**（RGBA → `render` 的 `Bitmap` → Painter 合成，本档位不做硬解与 GPU 合成）；新写播放器 UI（悬浮控制条/进度与音量/倍速/字幕叠加/seek 防抖）+ 音频时钟与同步；旧链坑照 adaptation.md 逐条验收（音画不同轴、seek 后进度从零重涨、换载崩溃）
  - [ ] 批 D2c 再余项（不假装完成）：ASS 样式渲染（颜色/定位，目前只按文本叠加）、多字幕轨列表与切换（现在只取 `av_find_best_stream` 选中的那条）、倍速听感复验（是否仍同步、音高随动是否可接受）
  - [ ] **`ui.button` 缺图标位（2026-10-16 控制面一批撞出来的框架缺口）**：示例的「选择文件…/选择目录…」这类**带文字的动作文案**要的是「无边框按钮 + 图标」，而 `ui.button(text, variant=…)` 只画文字、`ui.icon_button(kind)` 只画图标，两个都不合用；在示例里并排拼 `icon` + `button` 会得到两个分离的命中区（点图标不响应）。要补的是 `button(text, icon?=…)`：图标落在左内边距内、文字盒右移，**难点在固有宽度**——`attach_text_measure` 只按文字量尺，加了图标位就得让测量函数多算 `icon_w + gap`，否则窄按钮上文字会压住图标。定案前先量一遍 `draw_box_at` 的落位是否读样式 `padding_left`（现在写死 12.0），写死的话这条改动会波及所有按钮的水平内边距口径。
  - [ ] **媒体播放面缺口（2026-10-16 控制面一批点出来的，逐条待排）**：① **静音**——音量条能拖到 0，但没有「一键静音并可恢复」的键与图标（`sound`/`hide` 两个图标现成），也没有 `M` 快捷键；② **循环/随机键**——`looping` 只有 make 参数，控制条上切不了；③ **视频组件没有频谱**——`Spectrum` 与 `pcm_tap` 是引擎侧的，带音轨的视频同样能画，现在只接在 `audio` 上；④ **歌词只在 `audio`**——`video` 有 `subtitle` 没有 `lyric`，两套文本面（字幕叠加 / 歌词行）在组件层不同源；⑤ **全屏形态不完整**——全屏后鼠标指针不自动隐藏、双击不切全屏、控制条不自动收起；⑥ **LRC 编码**——只按 UTF-8 解，老 `.lrc` 常见 GBK 会出乱码（**推断，未实测**），要么加转码表要么给明确的「解不出=按空歌词」判据；⑦ **`ui.button` 图标位**（上一条）。
  - [ ] **播放器组件换载残账（2026-10-16 代码走查发现，未修、未上真机）**：`audio`/`video` 的 `@core.set_timeout` 自续链在宿主 `clear_children` 之后照跑——旧引擎继续 pump（换曲时上一首理论上仍在出声），且每换一次多一条链，`AudioPlayer::free`/`VideoPlayer::free` 全仓没有调用点。`core` 的卸载通道只有 `set_widget_discard_hook` 这**一个单槽**，已被 `gui/style/apply.mbt` 占了（媒体层装不上）。要么给 core 补「按控件登记」的多播卸载通道，要么组件 API 暴露显式 dispose 让调用方换载前调——先定口径再动。（2026-10-16 控制面一批里，窗口级按键兜底通道用 `Widget::is_painted()` 自证活体，摘掉的播放器不再吃键，**但时钟链与 FFI 句柄的残账照旧**，本条待决不变）
- [~] **批 E 原生弹层窗口**（已完成面见 roadmap 同节；剩余见子条目）
  - [ ] 「点外收起」的可用判据：失焦自收在映射期会误触发（对照实验：开=约两秒自关且 `hides=0`；关=常驻），故 `overlay_set_dismiss_on_blur` **默认关**，等「拿到过焦点才算」的判据；另欠 Esc 收起、弹层锚点跟随 owner 滚动/移动、六件各自的尺寸提示
- 积木原则：一个能力一个接口、可单独不用；能力之间不互相依赖（webview 不依赖媒体层，反之亦然，两者只依赖窗口/布局/事件层）；框架只给原语不给产品（爬虫框架、站点适配、内容解析、开发者面板、页面脚本库不进库）；每项能力给探测 + 语义化降级；新 API 一律走 `Painter`/`Bitmap` 门面
- 明确不做（避免反复讨论）：网络拦截/改写、代理配置、一窗多 webview 并排、Linux 上把 webview 变纹理、首批硬解、首批 GPU 合成、网页内 `<video>` 与自绘播放器统一、macOS 13 及以下的持久化隔离（根因是 Apple API 边界：持久化 profile 需 macOS 14+ 且有 bundle id）
- 平台后端（随各自真机）：Windows WebView2——**2026-10-13 平台批已接**（两级异步 COM 创建 Environment→Controller、失败走 dead 语义降级、就绪前 load 排队、13 事件 push 队列同构 WebKit 分支、自定义 scheme 经 `EnvironmentOptions4::SetCustomSchemeRegistrations` 预注册 + `WebResourceRequested` 回包（`CreateWebResourceResponse`，404 给明确空响应）；vendor 口径：NuGet Microsoft.Web.WebView2 1.0.4258.31 的 `WebView2LoaderStatic.lib` + 头 vendor 进 `gui/web/`，prebuild 下发链接参数；**真机验证**：web wbtest 17/17、一次性探针 load_html/标题事件/JS 求值/协议页导航/DOM 求值全通、`native-web` 冒烟 `supported=1` + GEO 真矩形 + 8 组统计；坑见中英 `adaptation.md`——未预注册 scheme 导航直接失败、COM propput 少 self 参数在 x64 上静默写坏 vtable、`GetCustomSchemeRegistrations` 数组必须 `CoTaskMemAlloc`（静态数组会被引擎 free 触发堆损坏 0xC0000374））。**未接**：跨 HWND 焦点与滚轮转发。macOS WKWebView（自定义协议走**公开**的 `WKURLSchemeHandler`（macOS 10.13+），libyue 当年那条 `WKBrowsingContextController registerSchemeForCustomProtocol:` 是更老的私有路线；要验的是公开入口够不够用：自定义 scheme 默认非标准、origin/localStorage 行为要另配；**另需真机验一条**：`loadHTMLString:baseURL:` 是否入前进/后退历史——Apple 无文档承诺，而 Linux 实测 `load_html` 不入历史、WebView2 文档明写 `NavigateToString` 不改历史，若 mac 相反就要在 `web` 里抹平或写进契约）

### 交付面（webview 批 A/B 落地后接上）
- [~] **示例迁移（G7）**（已完成面见 roadmap「交付面与工程化」；剩余见子条目）
  - **`showcase`（进行中，2026-10-12 首批）**：骨架 + **基础组件页** + **反馈组件页**已换到新栈（`core` 的 `Node` 层 + `ui` + `theme`）；本地共享层目录 `ui/` → `shared/`（新栈组件库本身就是 `ui`，两个包都派生成 `@ui` 会歧义）。三包 `--deny-warn` 零警告、全仓红点 287/68 未变、真机冒烟 `exit 0`（`SHOWCASE-READY pages=2` / `SHOWCASE-DONE`）。四处机械差与三个坑（`style` 改容器参数 / 显隐挂载换到 Widget 层 / `flexgrow` 要在 `handle` 里对滚动视口置 / `nav_page` 要自己写；本地包名歧义、`popover_t` 宽高是命名参数、`@yue.VERSION` 在主包里不可用）见中英 `adaptation.md`「示例迁移首批」节。**表单组件页已迁**（2026-10-12 第三批，`SHOWCASE-READY pages=3`）
  - **`showcase` 待迁页（按「先基础、后重控件」排序；旧源码取回：showcase 各页 `git show master:examples/showcase/pages/<页>.mbt`，systemprobe 各页在删除前提交 `git show 72643b7:modules/gui-examples/systemprobe/...`）**：~~表单组件~~（2026-10-12 已迁，六段：输入/数值/选择/开关/日期/表单，`input_t`→`entry`(Store 驱动)、`input_number`→`stepper`(Int)、`radio_group` 值改索引 Store、checkbox 改 Store 即状态）、~~导航组件~~（2026-10-12 已迁，七段；本栈 `Menu` 尚无 `popup_at` 右键弹出形态，该段以说明替代）→ ~~数据展示~~（2026-10-12 已迁，十段：展示族 + 表格族三形态 + 万行虚拟滚动；statistic 是静态快照形态、联动走 bind；card 改 children 在前 title 命名）→ ~~图表~~（2026-10-12 已迁，五段：折线、柱状、环形、仪表盘、散点；循环推点用 `set_timeout` 自重排替代旧重复定时器）→ ~~代码与文档~~（2026-10-12 已迁，两段：code_view 三语言高亮 + markdown_view GFM 全量）→ ~~Store 对照~~（2026-10-12 已迁，四段：手动计数/subscribe/map/信号对照）→ ~~事件与布局~~（2026-10-13 已迁，六段：指针/悬停/捕获/光标/键盘/布局；五鼠标回调合一 `on_pointer`、捕获改「命中即捕获」宿主规则、全局鼠标轮询段删（无窗口外指针通道，修饰键随事件下发）换 `on_hover_change` 悬停秒表、光标改 `w.cursor` 字段、键盘焦点区用 Node mount 闭包在挂载时注册焦点 id）→ ~~窗口~~（2026-10-13 已迁，三段：窗口 API/全局快捷键/应用内拖放；窗口段经新增的 `core.App::window()` 取 `@win.Window` 直调（最大化/置顶本栈未接，按钮不放）、快捷键切 `@core.hotkey_*` 门面（W22，回查表门面自持，页内 200ms 轮询表挂宿主）、拖放从「跨应用系统级」缩为「应用内」`drag_source`/`drop_target` 声明式钩子（系统级接口形状已定、随平台批）；共享 App 加 `host` 句柄字段，挂载时由 main 的 handle 回调填入）→ ~~系统集成~~（2026-10-13 已迁，十段：文件对话框/消息框/通知/剪贴板/定时器/托盘/自启/外部打开/系统信息/音量；通知切 `@core.notify_send` 门面、托盘切 `@core.Tray` + 200ms dispatch 表、文件对话框 parent 传宿主窗口 id、`@sys.autostart_*` 开关带 priming（读初值不反向写系统）、音量/系统信息补位旧页「电量网络」；旧页 13 段里 6 段本栈未接整段不迁：关闭拦截/单实例/无边框透明窗/屏幕常亮/休眠锁屏事件/电量网络；新增 `core.App::cancel_timer` 配 `timer` 的「句柄可停」语义）→ ~~图标库~~（2026-10-13 已迁，19 段 802 图标：生成器 `scripts/gen_showcase_icons.py` 为新栈改写——读 `gui/icons/icons.mbt` 标记区、经 `@shared.page/section` 装配、图标走 `@ui.icon`、悬停名走 `@ui.tooltip_t`、间距走容器参数；顺手修了生成器的 Windows 路径坑（`__file__` 反斜杠致 REPO 解析失败，改 `os.path`））→ ~~画布与富文本~~（2026-10-13 已迁，两段：Painter 自绘/AttributedText 富文本；`@declarative.container(on_draw=…, style=[…])` 换 `@core.node_of_new` 自挂 on_draw + yoga 尺寸、重绘从容器 schedule_paint 换进程级 `@core.invalidate()`、「系统语义色」换真实存在的两个系统读数（深浅=sys_color_scheme 来源的 dark_mode、主色=sys_accent 来源的 accent，走 bind 直连共享状态）、新增渐变填充演示（Gradient::linear + set_fill_gradient）；跨包 `set_format({…})` 结构体字面量实测可行）→ ~~浏览器~~（2026-10-13 已迁，七段：加载/导航与事件流水/JS 执行/JS↔原生 raw binding/Cookie/DOM 抓取/创建选项；五导航回调 + title 合一 `on_event`（WebEvent 族，消费式取）、cookie 改 `Cookies` 事件回包、`execute_javascript_with_result(code, done)` 回包只剩结果串、自定义协议改「文件根目录」形态 `register_protocol(scheme, root)` 且 `webview_predeclare_schemes` 须在建第一扇 webview 之前、拒绝路径改「注销协议后重载」走 LoadFailed + 结构化原因、新增 capture_dom 四档段（旧页没有）；pane 在 `@core.node_of_new` 挂载闭包里创建（页内容惰性挂载，挂载那一刻宿主才在）、引擎不在位降级自绘说明板；**showcase 待迁页至此清空**）；~~菜单栏 / 托盘菜单 / 单实例接线~~（2026-10-13 第十五批：菜单栏走 W20a 模型翻译 `MenuBar::apply_to` + 100ms `dispatch_menu_command` 表，「导航/主题/帮助」三菜单动作全真实（切页/拨深浅与跟随/关于冒提示/退出走 `App::quit`）；托盘菜单在系统集成页托盘段「挂菜单」（`Tray::set_menu`，项点击走同一条菜单派发链），托盘句柄存页内 `tray_holder`、「改提示」顺手改成真调 `set_tooltip`；单实例走 dbus 层 `claim_name`("com.moonbitlibyue.showcase") + `on_wake`（切回首页 + 冒提示），已有实例 `wake_existing` 后退出，D-Bus 排期通道与 200ms 泵由宿主给，无会话总线环境（Windows 桌面）Err 降级只打印；对话框已挂窗口根）
  - ~~`systemprobe`（8 页，`modules/gui-examples`）~~（2026-10-13 第十六批已迁，7 页：系统能力/视频播放/音频播放/命令与状态/扩展图表/新图表/交互图表；装配层照搬 showcase 的 shared（ProbeApp 只带 selected/toast/host），旧 `ui/page.mbt` 的 page_shell/report_set/nav_page 不再需要；「系统能力」21 族探针里 16 族走 `@sys` 真调 + MPRIS 走 `@dbus`，本栈未接的 5 族（磁盘卷/时区语言/蓝牙/传感器/logind 电源会话）以说明行替代；媒体两页改 `video` 全包组件（音视频一体，旧三件套 AudioPlayer 手动 pump + audio_player_t + 状态轮询全消失），换载 = holder `clear_children` + 重挂，演示媒体走 `@sys.pr_run` ffmpeg lavfi 现场生成（落点 TEMP）；「新图表」页的地图组件（geo_map_t 已平移）暂不展示——演示用抽象多边形易与真实地图混淆，口径等地图能力线定；特效散点动画 `EffAnim` 组件内部自驱动，ProbeApp 不持句柄；冒烟 `PROBE-READY pages=7` → 优雅关闭 → `PROBE-DONE`）；**附带**：`ffmpeg_stub.c` 加 Windows 分支——33 个 FFI 符号给「全错误降级实现」（链接不断、语义恒失败），gui-media 依赖链在 Windows 从「构建断」变「可构建 + 运行时语义降级」，gui-media 11 个真功能测试按 `@ffmbt.ffmpeg_supported()` 探测跳过（Linux CI 照常真跑，24/24）；`sysmonitor` 2026-10-13 第十七批已迁（原地升级 `examples/sysmonitor`：数据层 sysdata/sysproc/syshw + 三个 wbtest 原样平移（唯一改动 `@yue.platform()` → `@sys.sys_platform()`），stub/sysmon.c 2996 行零改动直挂新栈 native-stub（Windows 虚拟 /proc 数据源在 wbtest 真采到 237 个进程，66/66）；UI 六页改写：Mission Center 双栏（左卡片导航 + 右详情页一次性挂载切可见性）——自绘重绘从 schedule_paint 换 Store.subscribe + `@core.invalidate()`，手型光标换 cursor_group，值行走 label_dyn(align=End, grow)，进程页 table_v_t 固定 width=880（本栈无 fill 形态），图表 fill=true → area=true，搜索框 input_t → entry（clearable 未接，组件无此形态）；主题跟随换 `App::follow_system_theme()`；冒烟 `SYSMON-READY cores=8` → 优雅关闭 → `SYSMON-DONE`）——**G7 示例迁移全线收口**
- [ ] 文档：中英使用文档按新栈重写（`components`/`components-ui`/`declarative`/`layout`/`relink`/`system-capabilities`/`tutorial`），README 挂新截图
  - [ ] **清掉已删旧链的用法段**：`docs/zh/system-capabilities.md:253/293/304`（英文版同处）还在教 `@yuemedia.audio_player_t(player)` / `@yuemedia.video_player_t(player)`——那是已删的 `modules/gui-media/src` 旧链组件、签名收引擎实例，与新栈的 `audio`/`video` 无关；同段「50ms 时钟自动 pump」也过期（现口径：`ap_tick_ms`=33、时钟由组件内部 `set_timeout` 驱动）。改按新栈两组件重写，顺带补 `lyric` / `spectrum` / 缩放三档 / 快捷键。
  - [ ] **AGENTS.md 文档地图收录 `docs/zh/module-structure.md`**：本轮没加，因为该文件正被并行会话改（未提交），提交会把别人那行一起带走。
- [ ] 发布：mooncakes 新版本；旧 `bin-*`/`vendor-*` 预构建发布链退役
  - [ ] **`gui-media` / `gui-examples` 首发前最后一次公开面审校**：两模块 0.1.0 至今未发布，本轮组件改名（`player_t` → `video`、新增 `audio`）正是在「无历史版本」前提下才零破坏；一旦发出去就改不动了。首发前把两模块 README、`docs/zh/system-capabilities.md` 媒体段、`modules/gui-media/moon.mod` 依赖版本钉法过一遍（发布链与预演 zip 口径见根 `HANDOFF.md`）。
  - **0.1.0 构建失败与 0.1.1 重发链（2026-10-15 实测）**：`native-gui@0.1.0` 包页 Build failed——依赖 `NoahLiu/yoga-mbt@0.1.0` 的注册表归档里 `src/moon.pkg.json` 仍是旧清单（发布早于仓内迁移；已发布版本不可原地改写），四目标同一根因。重发顺序**先 `yoga-mbt` 后 `native-gui`**、版本各递增 0.1.1，仓内各模块钉版同批更新；发布从各自模块根执行（可先 `moon publish --dry-run`），发前 `moon package` 预演核对归档零旧清单，发后看包页 `build_status` 与构建日志 API；机理见中英 adaptation.md 的 mooncakes 构建器条。
- [ ] 真机验证矩阵：Ubuntu GNOME / KDE / XFCE；Windows 10 / 11；macOS（前置：取得设备）
- [~] **平台批：WebView2 桩真实现 + ffmpeg Windows 真链接**（已完成面见 roadmap；剩余见子条目）
  - **win 子 HWND 容器**（P1）：`gui/win/stub.c` 补 `wm_surface_new/set_rect/close/container` Windows 真实现（`WS_CHILD` 面板 HWND，父=宿主窗，DefWindowProc + 背景刷 NULL 免闪白），`wm_init` 注册窗口类、`wm_close` 清 surface 槽——web 桩经 `wm_surface_container(surface_id)` 拿 parentHWND。
  - **WebView2 桩真实现**（P2/P3）：`gui/web/webview2_stub.c`（仅 `_WIN32` 有内容，~1450 行）——静态 Loader 链接形态（`WebView2LoaderStatic.lib` vendor 进 `gui/web/lib/`、头 vendor 进 `gui/web/include/`，NuGet Microsoft.Web.WebView2 1.0.4258.31，MIT）；事件模型与 WebKit 分支同构（COM 回调 push 队列、MoonBit 每帧消费式取）；`webview_predeclare_schemes` 名单经新 extern `wb_predeclare_scheme` 流到 C 桩、Environment 创建时经 `EnvironmentOptions4::SetCustomSchemeRegistrations` 注册（`WbReg`/`WbOptions` 手写 COM，secure=TRUE/authority=TRUE）；`webkit_stub.c` 两分支加 no-op 对齐。**验证**：`moon test ./gui/web` 17/17、`core` 118/118、examples `--deny-warn` 零警告；一次性探针 `examples/webprobe`（验证后已删）——load_html+标题事件+JS 求值、协议预注册+本地文件服务+导航（`PROBE-TITLE ScmPage`/`PROBE-DONE title=ScmPage url=probescm://local/index.html`/`PROBE-JS scheme-ok`）全链路真机通；`native-web` 冒烟 `supported=1` + GEO 真矩形 + 8 组统计。
  - **ffmpeg Windows 真链接**（P4）：`ffmpeg_stub.c` 删 `_WIN32` 全错误降级分支，三平台实现同源；dev 内容 vendor 进 `modules/ffmpeg-mbt/vendor/`（BtbN `ffmpeg-n9.0-latest-win64-lgpl-shared-9.0` 的 include 头 + 导入库 + LGPLv3 LICENSE，共 2.5MB；**运行期 dll 不进仓库**——本地放 PATH 或与 exe 同目录）；`prebuild.py` Windows 分支输出 `vars.FFMPEG_INC` + 导入库 `link_configs`（官方 prebuild `vars` + moon.pkg `${build.VAR}` 替换机制）；`src/moon.pkg` 加 `stub-cc-flags: "/utf-8 -I${build.FFMPEG_INC}"`——**`/utf-8` 是必须项**：MSVC 默认按系统代码页（GBK）读无 BOM 源文件，中文注释与 ffmpeg 头的 UTF-8 字节序列被误读吞行（C4819 → 级联语法错误）。`gui-media/prebuild.py` 注释更新：Windows 实测 miniaudio WASAPI/COM 全走运行期加载，零额外链接库。**验证**：`moon test ./modules/ffmpeg-mbt/src` **6/6**（ogg/m4a/wav 音频真解码 + 视频真解码 96x64 12 帧）、`moon test ./modules/gui-media/media` **24/24**（AudioPlayer 冒烟 pump 33 拍播完 1 秒素材——WASAPI 设备链真出声）；`native-web`（依赖 media→ffmpeg-mbt）Windows 链接成功。
  - **门禁**：库 `moon check` 归零 + 8 包测试 **837/837**；各模块 check 全绿。**已知遗留**：`experiment/ime_probe` Windows 链接 `ip_set_surrounding` LNK2019（Windows 上 prebuild 不编 IME 探针桩，既有问题、与平台批无关）；`release-bin.yml` 等 CI 未覆盖 ffmpeg dll 分发口径。

## 3. 里程碑

- **M1** 新栈跑通一个完整 `showcase`（组件 + 图表 + 系统集成页），与旧链路逐页视觉对照 → 同时恢复全仓门禁
- **M2** Windows 地基与输入通道（W1–W16 已落）＋ Win 基础能力（W20 批，§6）
- **M3** macOS 地基（取得设备后）
- **M4** 发布新版本并冻结旧 `shim + libyue` 链路

## 6. 跨平台能力面（Win 基础能力 + MBT 通用能力）

> **本节口径**（2026-10-12 定）：只记跨平台能力——即「换个平台有对应原生 API 可做」的能力，一律记成**「MBT 门面定形态 + 各平台后端」**；纯 Linux 依赖的实现细节（xrandr/wmctrl/xclip/sysfs/wpctl/CUPS/D-Bus…）不再列为待办。清单来源＝旧栈资产面（`yue/tray.mbt`/`menu.mbt`/`misc.mbt`/`widgets.mbt` 的 `Notification`/`register_global_shortcut`/`Tray`/`MenuBar`/`MessageBox`，见本仓实验区 vendored 副本 `experiment/async_coexist/lab/.mooncakes/NoahLiu/native-gui/yue/`）逐文件比对，剔除 Linux-only 后重排。
>
> **执行顺序**：W20 批（Win 基础能力，桩层 `win/stub.c` 的 `_WIN32` 分支 + `win/window.mbt` FFI）→ W21 批（MBT 通用门面，跨平台同构）→ 两者交汇处（托盘/通知/热键的门面统一）归 W22。每批独立可交付、独立提交。

### 6.1 W20 · Win 基础能力（Windows 桩层，按现有范式）

> 范式：`win/stub.c` 的 `_WIN32` 分支加真实现 → `include` 或 `ffi.mbt` 声明 extern → `win/window.mbt` 加 `Window::*` 方法 → 纯函数/探针可测的抽成纯函数 → `examples/native-app` 累积验证页加一节 → 真机项进人工清单。

### 6.2 W21 · MBT 通用能力（跨平台同构，不依赖平台）

#### W22 · 三族门面统一（托盘 / 通知 / 热键）中未接的后端

- 交汇处托盘/通知/热键门面统一归 **W22**
  - ~~**Linux 全局热键后端（X11 `XGrabKey`）**~~（2026-10-16 已交付：自开 X 连接 + 四变体抓取 + BadAccess 错误陷阱 + `XPending` 泵抽，`wm_hotkey_supported` 按 `WAYLAND_DISPLAY` 分档；XFCE+X11 真机 xdotool 注入全链路命中。TODO 原推断的三处要点被实测推翻——grab 清位掩码行不通须变体抓取、事件不进 GTK 泵无需 filter、`Ctrl+Alt+Fn` 是 VT 保留域按不到——根因与实测定案见中英 adaptation「Linux 全局热键后端」节）
  - [ ] **媒体键走同一条 grab**（`XF86AudioPlay`/`XF86AudioPrev`/`XF86AudioNext`/`XF86AudioMute`）：这是「耳机键/键盘媒体键控播放」的正解，与 G10 的**窗口内**按键是两层，别混在一个门面里；Linux 侧键码取 `XKeysymToKeycode(XK_XF86AudioPlay)`，Windows 侧对应 `VK_MEDIA_PLAY_PAUSE`（W20b 的 vk 表要不要扩到媒体键一并定）。
  - [ ] **macOS 全局热键后端**（Carbon `RegisterEventHotKey`，或 `NSEvent.addGlobalMonitorForEvents` + 辅助功能授权）：同门面未接，前置=有 mac 真机，与 tray/notify 的 mac 档同批。
  - ~~**探针对齐**~~（2026-10-16 已交付：`hotkey_probe` 组合换 `Ctrl+Alt+H/J`（Fn 系是 VT 保留域），② 注册/幂等注销/槽位复用 + ③ 新增门面轮询段——`xdotool` 注入 6 秒内 `HOTKEY-CORE-FIRE` 即回证；组合被占走 `Err(Failed)` 门面已有）

#### W23 · 窗口显隐：`Window::hide`（与既有 `show` / `request_focus` 对称）

- [~] **`Window::hide` 门面已落，Linux 后端已接**（2026-10-16）：`win/stub.c` 三分支 + `Window::hide`/`Window::is_hidden`，`show` 唤回 hide 前的屏幕原点（GTK 分支 `gtk_widget_hide` + `XWithdrawWindow` 撤管，语义区别于 `XIconifyWindow` 最小化；Windows 分支 `SW_HIDE` 记客户区原点供 `SetWindowPos` 复位，**Linux 侧本机 wbtest 真开窗通过、Windows 分支未上机**）。macOS `orderOut:` / `makeKeyAndOrderFront:` 与 W22 的 mac 批同批，前置=有 mac 真机。
  - 动机：旗舰应用 moon-launcher（`lb091188/moon-launcher`）已把「Esc 隐藏驻留托盘」挂为其 README「已知边界」——发布包 0.1.1 只有 `show` 无 `hide`，启动器现在只能「Esc 清空→退出」。
  - 验收判据（本机判据已过：幂等、hide 后 `request_focus` 不异常；**真机肉眼项待用户复验**）：启动器 Esc 后窗口隐藏且托盘/DBus 单实例存活，Wake 或托盘点击唤回**原位置**并自动聚焦输入框。

### 6.3 与既有 §1/§2 的接缝（不改口径，仅指向）

- **§2「系统集成」里已有的跨平台能力**（剪贴板、文件对话框、`open_url`/`reveal`、浏览器历史/书签、`sysinfo`、主题跟随系统）**Windows 后端已落**（W14/W14e/W16），无需重开；**只差真机观感复验**（见 6.4）。
- **§2「新建项」**（任务栏进度、dock 徽标、勿扰）与本节的「Win 基础能力」有重叠面——**任务栏进度**（Win32 `ITaskbarList3::SetProgressValue`）与 **dock 徽标**（macOS `NSDockTile`）建议**收进 W20 批一并做**（三平台各有原生面，符合跨平台口径）。
- **`monitor`/`brightness`/`wallpaper`/`nightlight`/`volume`/`printer`/`powerprofile`/`windowctl`/`locale_sys` 等**——按新口径**不再在 TODO 逐条跟踪**（Linux 实现已是既有事实、非 Linux 无对应面或属各自平台批内部事务）；如后续启用平台批，按「各自能力批的内部事务」处理，不占路线图。
- **能力删除定案（2026-10-14，用户拍板）**：`brightness`（屏幕/键盘背光，Linux logind+sysfs 线）、`defaultapps`（xdg-mime/mimeapps 线）、`volume` 的 `volx_` 增强组（pactl 设备枚举/逐应用流）、`printer` 的 `prt_queue`（lpstat 队列枚举）四族**从代码与文档整体删除**——它们只有单平台实现、不满足跨平台口径，也不再留「待补另一平台」的挂账；`dbus` 的 logind 亮度接线（`bridge.mbt`/`brightness.mbt`）随之删除。此前文档里的对应「Windows 待补」条目一并摘除，不作为计划保留。

### 6.4 真机验证（用户执行，助手只给步骤）

- [ ] **W7 真实注入验证**：微软拼音端到端（preedit 下划线/候选窗位置/commit 落框）、两窗互相遮挡与拖动重绘、跨程序剪贴板（复制→记事本→粘回）、文件对话框模态 run 与真选文件、主题跟随系统深浅/强调色——归 `examples/native-app` 人工清单（`_人工测试清单.md`）
- [ ] **W20 批观感复验**：原生菜单栏（下拉/快捷键提示/勾选项）、全局快捷键（切到别的程序仍能触发）、托盘（图标出现/右键菜单/左键计数）、MessageBox（图标/按钮/返回值）、窗口标题与图标
- [ ] **三平台真机矩阵**：Windows 10/11 本机冒烟已通（`NATIVE-APP-MW`/`SYSPROBE-*` 退出码 0）；macOS 无设备（M3 前置）

### 6.6 性能批（2026-10-13 真机反馈立项）

真机反馈原文：「native-app 整体感觉卡顿，滚动、点击、悬浮都有 300–500ms 的延迟，点线分布图推点按钮没用，表格排序不生效，虚拟表格滚动失效」。前三条是**一个根因**、第四条是**示例漏接线**，见下。

- [ ] **文本布局缓存的 1024 超限整表清空策略待 Windows 实测**（`323b537` 引入）：本机 Pango 路径 cold(1680 条不同文本) 与 warm 持平（3.35 vs 3.25 ms/帧），说明这条路径不吃亏；**Windows/DWrite 侧没量过**，而 showcase 这种上千条不同文本的页面正好踩在上限之上——若真机账本 `paint` 占比高且 `frames` 正常，就把整表清空换成按键淘汰。对照判据已留：`moon run experiment/showcase_cost_bench`（同树换版本），真机读数 `SHOWCASE-PROF` / `showcase-prof.txt`。
- [ ] **悬停/点击反馈的帧成本量化**（脏矩形已落地后的收益项，未量；P5 已按小脏区读数开工）：局部脏区一帧要花多少钱，由 `SHOWCASE-PROF` / `anim_cost_bench` 的小脏区档读数定档（滚动仍要全视口重画，收益在悬停与点击）。
- [ ] **光栅微优化**（未做）：`raster.mbt` / `raster_fill.mbt` 每次 fill/stroke 都新分配一条 width 长的 `cov` 数组（每帧数百次）；不透明实心填充可走「无覆盖率」快路径；`raster.mbt` 里根背景那 126 万像素的全窗填充占单帧成本的可观一份。
- [ ] **文本布局缓存**（未做，单帧成本里最重的一块）：`text/dwrite_text.cpp` 的 `ptw_session_layout` 每次 `rt_measure` / `rt_draw` 都新建 `IDWriteTextFormat` + `IDWriteTextLayout`（**同一条文本一帧建两次**），`AttributedText::rt()` 每个文本节点每帧开两个会话，且 `rt_new`/`rt_free` 每帧重来、无跨帧缓存；`ui` 的 label/button/表格单元格一律走这条路。布局（yoga）每帧还会为**全树**文本节点各测一次，屏外的也照测。
- [ ] **量出来再优化**：上面三条都还没在真机上分档计时（`experiment/text_bench` 已有先例可扩展）。建议先做一个「单帧成本分解」探针（根背景填充 / 控件绘制 / 文本 / memcpy+StretchDIBits 各占多少），再决定动哪一块。

## 4. 已知边界与风险

- 自绘文本的**无障碍**（ATK / UIA / NSAccessibility）本栈暂不含，只记不办。
- 例外扩散警戒：可见原生控件覆盖只作**按平台开关的兜底**，默认关；子表面（浏览器/视频）属能力型例外，需逐条登记评审。
- **过渡期已收口（2026-10-15）**：`examples/*`、`modules/gui-examples`、`modules/gui-media` 全量编译通过、各模块 `--deny-warn` 零警告；分支仍不宜积压——一批完成即提交推送。
- 回归基线：旧栈约 660 条测试随绑定文件消失，属净覆盖损失；补法是新栈每包自建 wbtest 并随资产平移测试。
- mac 线整体风险后置：无真机（旧栈遗留项 reply 通知回调、mac canvas 滚轮、Accelerator/Tray 原生后端等一并留在 master 侧记录）。

## 5. 随手可查

- 平台实测坑：[docs/zh/adaptation.md](docs/zh/adaptation.md)（中英两份）
- 布局引擎交接与决策：[modules/yoga-mbt/HANDOFF.md](modules/yoga-mbt/HANDOFF.md)
- libyue 源码（只读老师）：`/home/lkyh/ownCode/yue`，含 `patches/` bug 语料
- master 线参考副本（代码权威）：`/home/lkyh/ownCode/moonbit-libyue`（比本仓 origin/master 新，Windows/mac 批次在此；本仓文档落后量见「交付面」）
- FFI 规范与坑：`.agents/skills/moonbit-c-binding/`（同步自 [moonbitlang/skills](https://github.com/moonbitlang/skills)，`~/.agents/skills/` 同版）
- **跨平台能力批次表（Win 基础能力 + MBT 通用门面）：本文件 §6**（2026-10-12 定；只跟踪跨平台能力，Linux-only 细节不再入表）
- 旧栈 API 参照面（可平移资产）：`experiment/async_coexist/lab/.mooncakes/NoahLiu/native-gui/yue/`（`tray.mbt`/`menu.mbt`/`misc.mbt`/`widgets.mbt`，本机离线可用）
- 人工复验清单：`_人工测试清单.md`（跑 `moon run examples/native-app`）
