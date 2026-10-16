# 模块结构：按路线拆模块、按层级切子包

> **状态**：Batch 1 已交付（2026-10-16），Batch 2 规划中  
> **跟踪**：TODO.md §1「G9 模块拆分」（Batch 2 落账）

## 1. 背景与目标

native-gui 计划支持三条渲染路线：**原生自绘 / WebView / 纯 3D**。当前代码库是单模块 `gui/` + 14 个子包的扁平结构，所有子包共享 `NoahLiu/native-gui`。`core` 同时依赖 render / theme / win / sys / text / dbus，构成「引力井」：只走 XFCE 自绘的用户也要承担 WebView2 SDK 的代价——14 MB vendor 下载加 WebKitGTK pkg-config 探测；未来的 3D 路线更不可能复用整套 widget 树。

本方案的目标：

| 目标 | 现状痛点 |
| --- | --- |
| 各路线按需组装 | `@core.App` 把全部自绘控件拖进闭包；一条 import `NoahLiu/native-gui/web` 就把 WebView2 和 WebKitGTK 桩全拉进来 |
| 减少构建负担 | prebuild 无条件编译全部平台桩、无条件拉 vendor 文件，每个消费者都要等一次完整预构建 |
| 允许路线独立演进 | media 已迁出成 `modules/gui-media`，代价是复制 96 行 prebuild 并 pin `native-gui@0.1.0`；每开一个新模块都重复这份劳动 |

## 2. 判据一句话

> **外部重资产 + 必须强制下发链接参数 → 开模块；纯内部层 → 留子包。**

## 3. 新仓库布局

```
moonbit-native-gui/                          # 根 workspace
├── modules/
│   ├── gui/                                   # [主模块] native-gui 核心子包 (0→N 的拆)
│   │   ├── moon.mod                           # NoahLiu/native-gui
│   │   ├── base/                              # 响应式 + 窗口泵 + Loop/host
│   │   ├── shell/                             # 窗 + 子件槽 + resize + 系统能力
│   │   ├── widget/                            # 布局树映射 + 命中 + Painter 绘制
│   │   └── ...其余子包保持不变...              # style/theme/icons/input/text/chart/mdview/sys/dbus
│   ├── gui-webview/                           # [新模块] WebView2 + WebKitGTK
│   │   ├── moon.mod                           # NoahLiu/gui-webview
│   │   ├── webview.mbt
│   │   ├── webview_ffi.mbt
│   │   ├── scheme.mbt
│   │   └── prebuild.py                        # 分平台分支：WebView2(Windows)/WebKitGTK(Linux)
│   ├── gui-media/                             # [已有模块] ffmpeg + miniaudio
│   └── gui-3d/                                # [未来模块] GL/Vulkan SDK + shader toolchain
├── examples/                                  # [独立模块] NoaLiu/native-gui-examples
├── experiment/                                # [独立模块] NoaLiu/native-gui-experiment
└── yoga-mbt/                                  # [独立模块] NoaLiu/yoga-mbt
```

### 3.1 主模块内的三个新子包

从 `core/` 提取：

| 新子包 | 文件来源 | 下游依赖 |
| --- | --- | --- |
| `base` | signal, store, effect, keys, focus, list_store, prof, tick, node | 无 |
| `shell` | loop, host, menu, hotkey, tray, notify, reveal, drag, app(开窗/泵/子件槽段) | win / sys / dbus |
| `widget` | widget, overlay, overlay_native, app(app.mbt:root.on_draw + paint_frame), text | render + yoga (不含 core 旧名空间) |

其余子包 `style`, `theme`, `icons`, `input`, `text`, `chart`, `mdview`, `sys`, `dbus`, `win` 不动。

**app.mbt 那 914 行是唯一钉子**：它一个文件用了 `@render @text @theme @win @yoga`，App 出现 39 次、Host 32 次。修法：把「窗口管理 + 泵调度 + 子件槽注册 + resize 通知」提进 `shell`，`root.on_draw` + `paint_frame` + 主题底色留在 `widget`。**先解 app.mbt，再改 import**——反过来会中途无法编译。

### 3.2 `NoahLiu/gui-webview` 模块

从 `gui/web/` 平移（2026-10-16 已交付，落位 `modules/gui-webview/webview/`）：`dom.mbt`、`scheme.mbt`、`webview.mbt`、`webview_wbtest.mbt`、`scheme_wbtest.mbt`、`dom_wbtest.mbt`、FFI 声明、`webkit_stub.c`、`webview2_stub.c`、include/lib/vendor。

关键改动：

- **不再依赖任何 GUI 核心子包**。入口改两个：`Webview::bare(app : ShellApp, url : String) -> Webview?` 作整页壳；`Webview::node(self : Webview, ...) -> Node` 作混排形态，混排可选引入 `shell` 或 `widget`。
- **prebuild 自行管理 WebView2 资产**：`VENDOR_FILES` 中的 lib + h 文件移至本模块。Linux 分支探 WebKitGTK 时，缺开发包返回空 link_configs 而不报错，MoonBit 侧以 `webview_supported()` 探测降级。原主仓 prebuild 删除对 WEB_PACKAGE 的分发。
- **版本锁解绑**：对外发布独立 version，首版 0.1.0；消费者经 `moon.work` 本地解析或指定版本号。

### 3.3 模块化的代价

每新增一个模块 = 一份 platform 探测 + 静态库编译 + vendor 下载 + prebuild 脚本 + CI 矩阵条目 + 版本 lockstep。参考：

- `gui/scripts/prebuild.py` — 336 行，主仓，6 条 stub 分支
- `modules/gui-media/prebuild.py` — 96 行，媒体线，2 条路径：Linux vs 非 Linux
- `modules/ffmpeg-mbt/prebuild.py` — 单独管理 libav* flags

**因此只有真正踩线的才开模块。**

### 3.4 已有模块 `gui-media` 的依赖面（2026-10-16 控制面一批之后）

- 该批给 `modules/gui-media/media` 新加了 `NoahLiu/native-gui/ui` 依赖：播放/暂停与全屏用 `ui.icon_button`，倍速与缩放用 `ui.button`。媒体层此前只依赖 `core`/`render`/`text`/`theme`/`yoga`。方向仍是 media → ui——ui 不认媒体，无环。判据不变：ui 是纯内部层，不拉外部重资产。
- 媒体层同时吃 `@core` 的三个入口：`host_active()` 拿当前窗，`App::add_key_fallthrough` 走窗口级按键兜底，`App::set_fullscreen` 走全屏，外加 `Store`/`Signal`/`keys`/`Widget`/`invalidate`。**拆包后这些不是一次改名**：`host_active` 与 `App` 的开窗/泵段归 `shell`，`Widget`/Painter/`invalidate` 归 `widget`，`Store`/`Signal`/`keys` 归 `base`。媒体模块将来要同时 import `@base` + `@shell` + `@widget` + `ui`。
- 因此 Batch 2 的 import 迁移清单必须含 `modules/gui-media` 与 `modules/gui-examples`（见 §4 步骤 5），并且每批改完逐模块重跑 `--deny-warn`——经 `moon.work` 本地解析的消费者不在主模块门禁的视野里。

## 4. 执行批次
### Batch 1：`gui-webview` 出模块（小改、立刻见效）

| 步骤 | 改动 |
| --- | --- |
| 1 | 创建 `modules/gui-webview/moon.mod`（`NoahLiu/gui-webview`, 0.1.0, prebuild -> prebuild.py） |
| 2 | 平移 `gui/web/` 的全部源文件 + C stub + vendor + include/lib 到 `modules/gui-webview/` |
| 3 | 修改 `gui-webview/prebuild.py`：分平台分支（Windows → WebView2 libs/h; Linux → WebKitGTK pkg-config） |
| 4 | 更新 `gui/scripts/prebuild.py`：删除 VENDOR_FILES 和 WEB_PACKAGE 条目；在 stderr 提示 "WEB moved to gui-webview module" |
| 5 | `moon.work` 加入 `"modules/gui-webview"`；消费方通过 `import "NoahLiu/gui-webview/webview"` 替代旧的 `NoahLiu/native-gui/web` |
| 6 | 验证：`cd gui && moon check` 零警告（web 不再被引用，需确认没有遗留消费者）；`cd modules/gui-webview && moon check --deny-warn` 零警告 |

预计成本：半天——源文件移动、prebuild 重写、导入路径替换。收益：原生路线产物少 14 MB vendor，离线构建不触网络。

### Batch 2：Core 三刀（大改、三条路线共用）

| 步骤 | 改动 |
| --- | --- |
| 1 | 创建 `gui/base/`：平移 signal、store、effect、keys、focus、list_store、prof、tick、node；对应 wbtest 同搬；`moon.pkg` 声明 `supported_targets = "native"` |
| 2 | 创建 `gui/shell/`：平移 loop、host、menu、hotkey、tray、notify、reveal、drag；app.mbt 的「开窗/泵/子件槽/resize」段提进此包 |
| 3 | 重排 app.mbt（914 行）：保留 root.on_draw + paint_frame 在 widget 层；shell 层暴露 `ShellApp` 类型（loop + host + resize，不含 Painter） |
| 4 | 创建 `gui/widget/`：平移 widget、overlay、overlay_native、app 剩余部分；改用 `@base` 和 `@shell` |
| 5 | 更新所有下游包的 import：`ui` / `chart` / `mdview` 里 `@core` → 拆分成 `@base`/`@shell`/`@widget`；**模块外消费者同批迁移**——`modules/gui-media` 的引擎 + 两个播放器组件 + 控制条、`modules/gui-examples` 的 audio/video 示例、`examples/` 的 showcase/browser/sysmonitor…、`experiment/` 各探针。漏掉模块外消费者不是编译期能发现的：它们经 `moon.work` 本地解析，改完主模块若不重跑各模块 `--deny-warn` 就是「已推送的树断链」——拆包一批踩过，systemprobe 15 处 |
| 6 | 验证：`cd gui && moon check --deny-warn` 零警告；`cd gui && moon test` 逐包通过；示例正常编译运行 |

预计成本：2-3 天——主力工作是 app.mbt 解耦和 import 迁移。收益：Tauri 整页壳可以用 `shell` + `webview` 组合跑起来；纯 3D 同理用 `shell` + 新 `gui-3d` 模块搭地基，不碰 widget。

## 5. 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| `core` 重新划包导致大量 import 路径变更 | 分批做、每批独立可编译；先用 `GuiCore = { "base"|"shell"|"widget" }` 过渡，再全量替换 |
| `shell` 和 `widget` 之间的边界模糊 | 严格守约：`widget` 能调 `@shell`，但不能反调；Painter 契约只在 `widget` 出现 |
| `modules/*` 版本脱节 | 发布前同一批递增版本号，参照 0.1.1 重发流程；CI 测试清单扩展到新模块 |
| prebuild 复制劳动 | 考虑抽 shared library，如 `scripts/shared_prebuild.py`；先解决功能再抽象 |

## 6. 可执行细案（2026-10-16 勘察，行号按当日文件）

### 6.1 Batch 1：`gui/web` → `modules/gui-webview`（2026-10-16 已交付）

**文件清单（实测）**：11 个源/桩文件 + 2 个 vendor 目录，vendor 合计 **14 MB**——`lib/` 11 MB、`include/` 2.9 MB。

- MoonBit：`webview.mbt` 20 KB、`scheme.mbt` 6.4 KB、`dom.mbt` 4.7 KB、`ffi.mbt` 4.1 KB，加 `webview_wbtest` / `scheme_wbtest` / `dom_wbtest` 三条与 `moon.pkg`
- C 桩：`webkit_stub.c` 32 KB、`webview2_stub.c` 72 KB
- 资产：`include/` 含 `WebView2.h` 等，`lib/` 含 `WebView2LoaderStatic.lib`

**消费者（实测）**：全仓只有 **一处** import `NoahLiu/native-gui/web`——`examples/browser/moon.pkg`。§4 步骤 6 里「确认没有遗留消费者」这条已经量掉，迁移面比原估更小。

**prebuild 改动点**（`gui/scripts/prebuild.py`）：

| 位置 | 现状 | 去向 |
|---|---|---|
| `:40` | `WEB_PACKAGE = "NoahLiu/native-gui/web"` | 删 |
| `:43` | `WEBKIT_PKG_CONFIG = "webkit2gtk-4.1"` | 移进新模块 |
| `:47-67` | `VENDOR_FILES`（WebView2 lib + h，带 sha256） | 整块移进新模块 |
| `:69` | vendor 下载与校验循环 | 移 |
| `:193-215` | Linux：探 webkit2gtk-4.1 → 编 `webkit_stub.c` → 给 `WEB_PACKAGE` 下发 link_configs | 移；主仓不再编 webkit 桩 |
| `:295-310` | Windows：WebView2 静态 Loader + 头 + link_configs | 移 |

新模块骨架照 `gui-media` 的形态：`modules/gui-webview/moon.mod`——`NoahLiu/gui-webview` 0.1.0 + `--moonbit-unstable-prebuild`；`prebuild.py`——三分支：Linux WebKitGTK / Windows WebView2 / 其余平台空 link_configs；`webview/` 子包装源与桩。

**接口口径（把 §7 未决 #1 定死）**：现在 `webview_new(app : @core.App, …)` 与 `Webview::node(…)` 都吃 core 的 `App`/`Node`。**建议 Batch 1 保持 import `NoahLiu/native-gui/core`**——「出模块」与「去 GUI 核心依赖」是两件事：Batch 1 只搬 14 MB vendor 与 WebKitGTK 探测，去核心依赖等 Batch 2 的 `ShellApp` 定案后再做，否则 Batch 1 会卡在未决接口上做不完。

**验收判据**：`cd gui && moon check --deny-warn` 零警告，主模块再无 web；`cd modules/gui-webview && moon check --deny-warn` 零警告 + `moon test`；`cd examples && moon build browser` 通过；真机 `moon run examples/browser` 出页，由用户执行；CI 矩阵加一条，Linux 装 `libwebkit2gtk-4.1-dev`、Windows 拉 vendor；`moon.work` 增成员。

**回滚点**：整批 = 一次 `git mv` + 两个 prebuild 编辑 + 一处 import 改名，单提交，`revert` 即回。

**交付实录（2026-10-16）**：判据全过——库 `check --deny-warn` 零警告（13 包）、`gui-webview` 模块 check 零警告 + `moon test` 1194/1194（全 workspace 闭包）、`examples/browser` 全量重链通过 + 本机冒烟起进程 26 秒优雅退出。三条细案没预见的实测：
1. **prebuild 的 stdin 只给 `paths.module_root` 与 `paths.out_dir`**（探针实测），没有依赖模块路径——webkit 真实现引用主模块 win 桩的 `wm_surface_container()`，新模块定位 `libyue_win_stub.a` 只能按「workspace 兄弟目录 → `$MOON_HOME` 依赖缓存 → 当前工作区 `_build` glob」三处探，探不到就退占位分支（探测返回不可用，不断链）。**registry 消费方（非 workspace）那条路径未经实测**，发布前要在最小工程验一次或改契约。
2. **消费方模块必须在自己 `moon.mod` 的 `import` 里声明 `NoahLiu/gui-webview@0.1.0`**——只改包 import 不声明模块，moon 报「containing module is not imported」（`examples/moon.mod` 已补）。
3. **vendor 的 `WebView2.h`/`WebView2LoaderStatic.lib` 本就不入库**（Release 资产 + .gitignore），`git mv` 只搬了 `SDK-LICENSE.txt` 与 `WebView2EnvironmentOptions.h`；下载清单与 .gitignore 路径已同步改到 `modules/gui-webview/webview/`。

### 6.2 Batch 2：`core` 三刀

`core/app.mbt` 实测 **976 行、46 个顶层定义**。分段依据按归属计数：

| 归属 | 定义数 | 代表定义（行号） |
|---|---|---|
| `shell` | 26 | `app_window`(131)、`App::new`(198)、`open_window`(206)、`close_window`(939)、`run`(956)、`step`(856)、`drain_events`(894)、`route`(570)、`raw_to_event`(535)、`timer`(431)、`quit`(455)、`set_fullscreen`(247)、`move_focus`(508)、`add_key_fallthrough`(66)、`install_host_hooks`(103)、`follow_system_theme`(261) |
| `widget` | 13 | `mount`(286)、`enable_root_scroll`(300)、`schedule_paint`(339)、`paint_frame`(790)、`mark_widget_rect`(379)、`mark_state_chain`(389)、`mark_focus_rect`(410)、`rect_union`(348)、`accept_widget_rect`(367)、`dirty_clip`(373)、`text_batch_init`(776)、`sync_focus`(502)、`flush_ime_for_switch`(472) |
| `base` | 4 | `now_ms`(72)、`sys_color_scheme`(77)、`sys_accent`(82)、`local_ymd`(89)——平台只读探针转发，也可归 `shell`，定案时一并拍 |

**三个真难切点**：写码前必须先定接口，否则中途编不过。

1. **`App` 是一个跨三层的 struct**（`:17`）。字段里 `window`/`sched`/`host` 属 shell，`root`/`canvas`/`dirty*` 属 widget，`focus` 属 base，`hover_id`/`capture`/`cursor_kind`/`last_preedit`/`ime_focus` 散在 shell 与 widget。§3.1 说 shell 暴露 `ShellApp`、不含 Painter——**意味着 `App` 必须一分为二**：`ShellApp` 是泵 + 窗 + 焦点栈，`App = { shell : ShellApp, root, 脏区, canvas, … }`。这才是本批的真实工作量，不是 import 改名。
2. **`route` 占 570-693 行共 124 行，同时做三件事**：事件分类属 shell，焦点投递属 base/shell，脏区标记属 widget。切法：shell 只做到「原始事件 → 分类 → 交给注入的 sink」，`mark_*` 与 `dispatch_*` 整段进 widget，sink 由 widget 层装配时注入——进程级单槽有先例：`set_repaint_hook` / `set_timer_hooks`。
3. **`pump_ime` 占 706-768 行，跨 `win` + `text` + `root` 三层**：IME 门控调 `@win`，文本批量初始化调 `text`，preedit/commit 投递调 root。建议 IME 整块留 widget——它服务的就是编辑控件；shell 只在 `step` 里调注入的 `on_frame`。

**迁移顺序**：每步独立可编译、可回滚。

1. 建 `base/`：搬 `signal`/`store`/`effect`/`keys`/`focus`/`list_store`/`prof`/`tick`/`node` 九文件 + 对应 wbtest。
2. 建 `shell/`：搬 `loop`/`host`/`menu`/`hotkey`/`tray`/`notify`/`reveal`/`drag` + `app.mbt` 的 26 个 shell 定义；此步 `App` 一分为二、`ShellApp` 落地。
3. 建 `widget/`：搬 `widget`/`overlay`/`overlay_native` + `app.mbt` 剩余 13 个定义。
4. 集中改 import：`ui`/`chart`/`mdview` + **模块外消费者**——`modules/gui-media`、`modules/gui-examples`、`examples/*`、`experiment/*`，一次一批包。
5. 门禁：`cd gui && moon check --deny-warn` + 分包 `moon test` + 各模块 `--deny-warn` + 示例构建。

**过渡形态（把 §7 未决 #2 定死）**：本工具链**没有 `pub use` 再导出**，`moon.pkg` 也不能给依赖包配短名（实测，见 design.md §1.6 表）。所以「过渡期 re-export」只有两条路：做**聚合包** `GuiCore = { base | shell | widget }`——新写一个只 import 三者、把公共面薄转发一层的面子包；或一步到位全量改 import。判据是调用点总数：`@core.` 在 `gui/` + `examples/` + `experiment/` + `modules/` 的 `.mbt` 里出现 **3528 次**（实测 grep 计数，含注释与文档行；只算主模块 `gui/` 是 2302 次）。全量改是数千处机械编辑加四轮编译报错驱动，聚合包则多一层长期维护的面子包。**建议**：先按这个量级拍，别默认「过渡包更省事」。

**风险红线**：步骤 1-3 期间 `core` 与三个新包并存、调用点不动；**不要在步骤 1 就删 `core`**——那是唯一会让全仓中途编不过的做法。每步一个提交，出问题 revert 该步。

## 7. 未决问题

- `webview_new(app : @core.App, ...)` 的接口签名换成什么？`ShellApp`？还是 `Node` 形态的 `Webview::bare()` 统一入口？取决于 Batch 2 做完后 `ShellApp` 的公开面。
- 现有 consumer（showcase、native-app）import `@core.*` 的数量较多，是否需要过渡期 re-export？
- `gui-3d` 的初步范围：GLFW 窗口创建 + OpenGL ES/Vulkan 上下文，还是只用已有的 `win` 子件槽挂 canvas？这会影响 `shell` 是否需要额外抽象。
