# 模块结构：按路线拆模块、按层级切子包

> **状态**：规划中（2026-10-15）  
> **跟踪**：TODO.md §1「G9 模块拆分」（Batch 1/2 逐步落账）

## 1. 背景与目标

native-gui 计划支持三条渲染路线：**原生自绘 / WebView / 纯 3D**。当前代码库是单模块 (`gui/`) + 14 个子包的扁平结构——所有子包共享 `NoahLiu/native-gui`，`core` 同时依赖 render / theme / win / sys / text / dbus，构成「引力井」。一个只走 XFCE 自绘的用户也要承担 WebView2 SDK（14 MB vendor 下载 + WebKitGTK pkg-config 探测），未来的 3D 路线更不可能复用整套 widget 树。

本方案的目标：

| 目标 | 现状痛点 |
| --- | --- |
| 各路线按需组装 | `@core.App` 把全部自绘控件拖进闭包；一条 import `NoahLiu/native-gui/web` 就把 WebView2 和 WebKitGTK 桩全拉进来 |
| 减少构建负担 | prebuild 无条件编译全部平台桩、无条件拉 vendor 文件；每个消费者都要等一次完整预构建 |
| 允许路线独立演进 | media 已迁出成 `modules/gui-media` 但代价是复制 96 行 prebuild 并 pin `native-gui@0.1.0`；每开一个新模块都重复这份劳动 |

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

**app.mbt 那 914 行**是唯一钉子：它一个人用 `@render @text @theme @win @yoga`，出现 App 39 次、Host 32 次。修法是把「窗口管理 + 泵调度 + 子件槽注册 + resize 通知」提进 `shell`，保留 `root.on_draw` + `paint_frame` + 主题底色在 `widget`。**先解 app.mbt，再改 import**——反过来会中途无法编译。

### 3.2 `NoahLiu/gui-webview` 模块

从 `gui/web/` 平移：`dom.mbt`, `scheme.mbt`, `webview.mbt`, `webview_wbtest.mbt`, `scheme_wbtest.mbt`, `dom_wbtest.mbt`, FFI 声明, `webkit_stub.c`, `webview2_stub.c`, include/lib/vendor。

关键改动：

- **不再依赖任何 GUI 核心子包**。入口改为 `Webview::bare(app : ShellApp, url : String) -> Webview?`（整页壳）与 `Webview::node(self : Webview, ...) -> Node`（混排形态，可选引入 `shell` 或 `widget`）。
- **prebuild 自行管理 WebView2 资产**：`VENDOR_FILES` 中的 lib + h 文件移至本模块；Linux 分支探 WebKitGTK 时如果缺开发包返回空 link_configs（不报错误），MoonBit 侧 `webview_supported()` 探测降级。原主仓 prebuild 删除对 WEB_PACKAGE 的分发。
- **版本锁解绑**：对外发布独立的 version（首版 0.1.0），消费者通过 `moon.work` 本地解析或指定版本号。

### 3.3 模块化的代价

每新增一个模块 = 一份 platform 探测 + 静态库编译 + vendor 下载 + prebuild 脚本 + CI 矩阵条目 + 版本 lockstep。参考：

- `gui/scripts/prebuild.py` — 336 行（主仓，6 条 stub 分支）
- `modules/gui-media/prebuild.py` — 96 行（媒体线，2 条路径：Linux vs 非 Linux）
- `modules/ffmpeg-mbt/prebuild.py` — 单独管理 libav* flags

**因此只有真正踩线的才开模块**。

### 3.4 已有模块 `gui-media` 的依赖面（2026-10-16 控制面一批之后）

- 该批给 `modules/gui-media/media` 新加了 `NoahLiu/native-gui/ui` 依赖（播放/暂停与全屏用 `ui.icon_button`、倍速与缩放用 `ui.button`），媒体层此前只依赖 `core`/`render`/`text`/`theme`/`yoga`。方向仍是 media → ui（ui 不认媒体，无环），判据不变：ui 是纯内部层，不拉外部重资产。
- 媒体层同时吃 `@core` 的三个入口：`host_active()`（拿当前窗）、`App::add_key_fallthrough`（窗口级按键兜底）、`App::set_fullscreen`（全屏），外加 `Store`/`Signal`/`keys`/`Widget`/`invalidate`。**拆包后这些不是一次改名**：`host_active` 与 `App` 的开窗/泵段归 `shell`，`Widget`/Painter/`invalidate` 归 `widget`，`Store`/`Signal`/`keys` 归 `base`——媒体模块将来要同时 import `@base` + `@shell` + `@widget` + `ui`。
- 因此 Batch 2 的 import 迁移清单必须含 `modules/gui-media` 与 `modules/gui-examples`（见 §4 步骤 5），并且每批改完要逐模块重跑 `--deny-warn`（经 `moon.work` 本地解析的消费者不在主模块门禁的视野里）。

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

预计成本：半天（源文件移动 + prebuild 重写 + 导入路径替换）。收益：原生路线产物少 14 MB vendor，离线构建不触网络。

### Batch 2：Core 三刀（大改、三条路线共用）

| 步骤 | 改动 |
| --- | --- |
| 1 | 创建 `gui/base/`：平移 signal, store, effect, keys, focus, list_store, prof, tick, node；对应 wbtest 同搬；`moon.pkg` 声明 `supported_targets = "native"` |
| 2 | 创建 `gui/shell/`：平移 loop, host, menu, hotkey, tray, notify, reveal, drag；app.mbt 的「开窗/泵/子件槽/resize」段提进此包 |
| 3 | 重排 app.mbt（914 行）：保留 root.on_draw + paint_frame 在 widget 层；shell 层暴露 `ShellApp` 类型（loop + host + resize，不含 Painter） |
| 4 | 创建 `gui/widget/`：平移 widget, overlay, overlay_native, app 剩余部分；改用 `@base` 和 `@shell` |
| 5 | 更新所有下游包的 import：`ui` / `chart` / `mdview` 里 `@core` → 拆分成 `@base`/`@shell`/`@widget`；**模块外消费者同批迁移**——`modules/gui-media`（引擎 + 两个播放器组件 + 控制条）、`modules/gui-examples`（audio/video 示例）、`examples/`（showcase/browser/sysmonitor…）、`experiment/` 各探针。漏掉模块外消费者不是编译期能发现的：它们经 `moon.work` 本地解析，改完主模块若不重跑各模块 `--deny-warn` 就是「已推送的树断链」（拆包一批踩过：systemprobe 15 处） |
| 6 | 验证：`cd gui && moon check --deny-warn` 零警告；`cd gui && moon test` 逐包通过；示例正常编译运行 |

预计成本：2-3 天（主力工作是 app.mbt 解耦和 import 迁移）。收益：Tauri 整页壳可以用 `shell` + `webview` 组合跑起来；纯 3D 同理用 `shell` + 新 `gui-3d` 模块搭地基，不碰 widget。

## 5. 风险与缓解

| 风险 | 缓解 |
| --- | --- |
| `core` 重新划包导致大量 import 路径变更 | 分批做、每批独立可编译；先用 `GuiCore = { "base"|"shell"|"widget" }` 过渡再全量替换 |
| `shell` 和 `widget` 之间的边界模糊 | 严格守约：`widget` 能调 `@shell`，但不能反调；Painter 契约只在 `widget` 出现 |
| `modules/*` 版本脱节 | 发布前同一批递增版本号（参照 0.1.1 重发流程）；CI 测试清单扩展到新模块 |
| prebuild 复制劳动 | 考虑抽 shared library（如 `scripts/shared_prebuild.py`），先解决功能再抽象 |

## 6. 未决问题

- `webview_new(app : @core.App, ...)` 的接口签名要换成什么？`ShellApp`？还是 `Node` 形态的 `Webview::bare()` 统一入口？取决于 Batch 2 做完后 `ShellApp` 的公开面。
- 现有 consumer（showcase、native-app）import `@core.*` 的数量较多，是否需要过渡期 re-export？
- `gui-3d` 的初步范围：GLFW 窗口创建 + OpenGL ES/Vulkan 上下文，还是只用已有的 `win` 子件槽挂 canvas？这会影响 `shell` 是否需要额外抽象。
