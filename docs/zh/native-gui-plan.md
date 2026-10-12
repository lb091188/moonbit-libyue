# MoonBit 原生 GUI 栈总体实施计划（Linux 站先行）

> 状态：**定稿**（2026-10-10 与协作方逐轮敲定）。后续批次按本文推进；实测结论与踩坑按仓库维护约定回写 [adaptation.md](adaptation.md)，本文只记「是什么 / 怎么分层 / 每批验收什么」。

## 1. 定案要点

- **路线**：自绘。新栈自己拥有窗口、像素缓冲、事件循环与布局，控件**全部基于 Painter 自绘 + 自定义主题**，不再提供独立的原生控件。
- **libyue 的角色**：**老师，不是运行时依赖**。新栈不含 libyue 一行代码；它的价值是行为语义参考、可平移的纯 MoonBit 上层资产、以及 `patches/` 里的真实 bug 语料。需要纯系统能力时按需调用，不作为渲染或布局后端。
- **布局层**：`modules/yoga-mbt`（纯 MoonBit Flexbox，只对齐 Web 标准），YG1–YG3 已完成。
- **Linux 后端锁定 GTK3**（`gtk+-3.0` 3.24.x）。理由两条：`scripts/prebuild.py` 现有依赖清单已含 `gtk+-3.0`/`pangoft2`/`fontconfig`/`x11`，用 GTK **零新增运行期依赖**；输入法的系统客户端（`GtkIMContext`）与 Wayland 后端都挂在这条链上。**裸 X11 自研窗口后端方案已删除**，不保留备选。
- **绘制与文本的平台矩阵（2026-10-11 改定，替代早先「直链 cairo/pango」的定案）**：
  - Linux = **GTK3 窗口 + cairo 光栅 + Pango 文本**，全部随系统库动态链，零打包负担、LGPL 无义务，G2–G5 已跑通的地基不动。
  - Windows = **纯 MoonBit 软件光栅器 + DirectWrite 文本**，渲染与文本零第三方依赖；图片解码走 WIC（系统组件，与 user32 同级）。
  - macOS = **CoreGraphics + CoreText**（取得设备后），同样零第三方依赖。
  - 取舍理由：曾评估 vcpkg 静态链 cairo/pango——依赖重（glib/fontconfig/harfbuzz 全家），且 LGPL 静态链进发行物有「提供重链接途径」义务，与本库「原生、轻量、无负担」定位相悖，弃。矢量渲染层（矩形/路径/AA/25 混合模式/渐变）由 MoonBit 光栅器**三平台同一实现**，像素断言跨平台通用；Linux 上保留 cairo 作**对拍标准答案**验收自研引擎。
  - **像素真值分两层**：矢量层跨平台逐位一致（断言共用）；文字的度量/宽度/像素字节分平台是固有的（旧栈即 Pango/DirectWrite/CoreText 三引擎），对策＝断言分「结构性（跨平台共用）/数值（平台基线目录）」两档，默认字体按平台显式编码进主题（Windows 钉雅黑系，Linux 跟 fontconfig）。
  - **行高 K 公式**（W5 第一条定案）：行高 = max(引擎自然行高, ceil(size×K))，K 实测三平台覆盖最肥字体（微软雅黑）后定为常量——行高成为 size 的纯函数，回退字体不再影响行高，多出空间半行距上下居中；异字体超地板时行高就地长高（优雅退化不裁字形）。
  - **跨平台分派机制**：一律**运行时探测 + 模式匹配**（render 包既有的「探针画一笔验像素、cairo 不可用退纯路径」形态），**禁用 `#cfg(platform=)` 编译指令**（即便工具链条件编译可用也不用，本条为定案不随工具链演进翻案）。
- `nu::Painter` 在 libyue 里只是 Cairo 的薄封装，因此它是**待移植的绘制库**而非后端；`Painter` 的方法签名照抄当契约。
- **版本纪律**：不试 GTK4——`nu::*` 的可比语义（焦点、编辑器、主题）全部是 GTK3 行为。
- **webview 与媒体的形态**（2026-10-11 定案，详见 §4）：窗口内容是 1..N 个**互不重叠的角色区（pane）**，每区 owner 要么自绘（Painter）要么挂原生子件（webview），矩形由 yoga 布局给；能力四档已锁（双向消息通道 / 只抓 DOM / CPU 回灌+软解 / 不做代理与拦截改写）。**本轮只做 Linux 闭环**，Windows/macOS 后端归平台线。
- **分支纪律**（2026-10-10 追加）：本特性分支**不保留老的 libyue 绑定，完全重来**——`shim/`、`lib/<平台>/`、`vendor/libyue` 与新栈不同进程共存，按 §2 清单摘除；**不设包内双轨开关**。因此允许「新栈起来之前全仓门禁为红」，红点即工作队列，口径见 §5。布局层（yoga-mbt）与 libyue 复刻**合算一个工程、一起推进**，不再分成两条时间线。

## 2. 包结构（替代主包 `yue/`）

新栈**不建独立子模块**，而是直接替代主包 `yue/`：对外包名仍是 `@yue`，`examples/*` 与下游 main 包的引用形态保持不变，逐包把实现换掉。分包：

| 包 | 内容 | 来源 |
|---|---|---|
| `win` | 平台窗口后端：建窗、事件、DPI、焦点栈、**原生子表面挂载**（§4）；Linux=GTK3，Windows=Win32，macOS=Cocoa | 新写 |
| `core` | 事件循环（平台单步泵 + `wakeup`：Linux=`g_main_context_iteration`、Windows=`MsgWaitForMultipleObjectsEx`）、App/Window、脏区重绘、yoga-mbt 接线、命中测试、**哑视图（可吃键盘焦点）**、自绘组件宿主 | 新写 |
| `render` | `Painter` 契约 + 双后端 `Bitmap`（自有 RGBA 缓冲，离屏与上屏同源）：Linux=Cairo 桩（prebuild 带宏编译），Windows/mac=**纯 MoonBit 光栅器**（运行时探测选择，Linux 上与 cairo 对拍验收）；图片解码 Linux=GdkPixbuf、Windows=WIC | 契约照抄 `yue/painter.mbt` 58 法 |
| `text` | `Text`/`Font`/`AttributedText` 语义层（Linux 委托 Pango；Windows=DirectWrite、mac=CoreText，`rt_*` 桩按平台换实现，语义层不动）；测量与基线回灌 `set_measure`/`set_baseline` | 参考 `nativeui/gfx/` |
| `input` | 编辑器内核（文档 / 选区 / 编辑操作 / caret）+ `TextEditorHost` 后端抽象 | 新写 |
| `sys` | 系统能力 | 平移 `yue/system`（559 fn）、`yue/traybus`（175 fn）、`icons`（803 个图标路径数据） |

`shim/` 的职能随之改变：从「libyue 的 C++ 转接」变成「本栈自己的平台后端 stub」，链接参数仍由 `scripts/prebuild.py` 全权托管（AGENTS 规则 1/2 不变）。

**可直接平移的既有资产**（按对 libyue 的依赖形态分类）：纯 MoonBit 零依赖的 `yue/system`、`yue/traybus`、`yue/geometry.mbt`、`yue/signals.mbt`、图标路径数据、图表纯算法层；绑定绘制语义的 `yue/components`（约 190 fn）与 `yue/charts`（约 289 fn）在新栈里**调用点不变**，只换 `Painter` 实现；声明式层的 `Node{mount}` 闭包模式（`yue/node.mbt:12-24`）把挂载目标从 `View` 换成 yoga-mbt 节点即可复用。

**绑定层摘除清单**（按 `ffi` 引用实测统计，行数为该文件总行）：核心绑定 `yue/ffi.mbt`(2455/439 处)、`yue/browser/ffi.mbt`(198/27)、`yue/methods.mbt`(643/87)、`yue/widgets.mbt`(652/71)、`yue/view.mbt`(611/66)、`yue/painter.mbt`(731/48，契约保留、实现替换)、`yue/events.mbt`(909/19，键码表与结构体保留，注册蹦床段 :628-827 重写)、`yue/app.mbt`、1:1 控件 wrapper `button/menu/dialog/message_box/scroll/separator/group/tab/table/text_edit/tray/style/node`，以及 `yue/{props,splitter,envx,fsx,error,store,system}.mbt` 与 `yue/components/components_{datetime,overlay}.mbt`、`yue/declarative/hovergroup.mbt` 里的 FFI 段。零 FFI 的资产文件（`charts/*`、`components/components_{display,draw,form,nav,style,table,text}`、`overlays.mbt`、`declarative/{declarative,overlay_scroll}`、`markdown/`、`icons/`、`system/*` 大部、`traybus/*` 大部、`png_rgba.mbt`）**保留原地**，其编译错误按阶段消化。

## 3. 输入与输入法（定案表）

三平台**都不实现任何输入法协议**，一律取系统的输入客户端；差别只在客户端形态。

| 平台 | 后端 | 系统 API | 状态权威 | 兜底 |
|---|---|---|---|---|
| Linux | **B 纯通道（真机已闭环）** | `gtk_im_multicontext_new` + `filter_keypress` + `commit`/`preedit-*` 信号 + `set_cursor_location`；**四条件缺一不可**：`focus_in/out` 随焦点同步、按键挂焦点控件层、每拍 `set_surrounding`（已提交文本 + UTF-8 字节光标）、`use_preedit=TRUE`（语义＝用 preedit 串做内联反馈）；组合串只在一处拼接（绘制侧，正文不带线、组合串带线） | 单状态（自绘编辑器） | 无（ibus 未装未测） |
| Windows | **B 优先** | 无文本子窗口 + `ImmAssociateContext`；`WM_IME_COMPOSITION` 读 `GCS_COMPSTR`/`GCS_RESULTSTR`，`ImmSetCompositionWindow`/`ImmSetCandidateWindow` 定位 | 单状态 | **C**：可见 `EDIT` 子窗口（用于只走 TSF、legacy 通道打不出中文的 IME） |
| macOS | **C 先行** | `NSTextField`（borderless + `drawsBackground=NO` + `textColor`/`font` + `focusRingType=None`），marked text 由系统显示 | 控件持有 | 待有 mac 真机后升级为 **B**（自研 `NSTextInputClient`） |

统一抽象（`src/input`）——上层自绘控件只见这四个签名，后端可逐平台替换：

**平台无关的映射表已落 `core/input_map.mbt`**（纯函数 + 回归）：三平台修饰位折算、Win32/macOS 键码表、shift/caps 折算、按钮号、以及「这颗键先交给谁」的路由判定（`ime_route`）。后端只负责取原始值并调表，不再各自决定语义；Linux 的 `wm_mods` 与表逐位对齐。

```
process_key(keysym, modifiers, is_press) -> Consumed | NotConsumed
commit(text)
preedit(text, caret, active)
set_cursor_rect(x, y, w, h)
```

**为什么 mac 不先做 B**：`NSTextInputClient` 十余个方法必须互相自洽；`NSRange` 以 UTF-16 code unit 计（与 MoonBit 的 UTF-8 字节需逐区间换算，参照 `TODO.md` MD2 已踩过的同类坑）；且 `acceptsFirstResponder`/`keyDown:`/`inputContext` 活在 ObjC 消息派发里，MoonBit 的 native FFI 只能调 C 函数，需要自带 `.mm` 的 NSView 子类。三笔成本叠加，而 mac 当前无真机可验（`TODO.md` O4 前置即「获得 mac 真机」），故整块延后。

## 4. 角色区（pane）与原生控件嵌入

### 4.1 架构模型：角色区（pane）

窗口内容 = **1..N 个互不重叠的矩形区**，每区声明 owner（自绘 = Painter / webview = 原生子件），矩形由 yoga 布局给。三种产品形态同源，不是三套机制：

| 形态 | pane 数 | owner | 说明 |
|---|---|---|---|
| Tauri-like | 1 | webview | 铺满整窗 |
| 爬虫 / 内容获取页 | 2 | 原生 + webview | 工具栏/地址栏/控制区与页面区并排，互不重叠 |
| 原生多窗口 | 每窗 1..N | 自绘为主 | 每个窗口各套同一条规则 |

「子表面」这个词只保留**原生控件嵌入**这一条语义（能力型例外，逐条登记评审），不当通用子表面宣传：网页渲染（WebKit/WebView2/WKWebView）与真原生控件本质上不可能自绘，这是窗口层的一条能力，不是像素合成通道。

### 4.2 已锁能力档位（2026-10-11 定案，不再重开选型）

1. **消息通道：双向**。原生 → 网页 `evaluate_javascript`；网页 → 原生 `invoke`。
2. **抓取层次：只要 DOM**。注入 JS + evaluate 取渲染后结构；**不做网络响应层**。
3. **媒体：CPU 回灌 + 软解**。ffmpeg 出 RGBA → `render` 的 `Bitmap` → Painter 合成；音频走 `modules/gui-media` 内嵌的 miniaudio 设备层。硬解与 GPU 合成必须成对考虑，本档位下**不做硬解**。
4. **网络面：不做代理、不做请求/响应拦截改写**（那是外部工具的活，框架不为此臃肿）。保留引擎原生开关：UA 改写、cookie 读写、按 profile 分数据目录。

### 4.3 积木原则（产品形态要求，不是风格偏好）

- **一个能力一个接口**，接口可单独调用、可单独不用；能力之间不得互相依赖——webview 不依赖媒体层，媒体层不依赖 webview，两者都只依赖窗口/布局/事件层。
- **框架只给原语，不给产品**：爬虫框架、站点适配、内容解析、开发者面板、页面脚本库一律不进库，上层自己组合。
- 每项能力都要有**探测 + 语义化降级**入口（沿用 `sys` 既有范式），不许静默降级。
- 新增 API 一律走 `Painter`/`Bitmap` 门面，不新增绑死 Cairo 的接口（为 GPU 后端留路）。

### 4.4 cookie 与会话隔离

根因是 **Apple 的 API 边界**，不是实现缺陷：macOS 的持久化 profile 需要 **macOS 14+ 且有 bundle identifier（`.app` 包）**；任一不满足只能 `nonPersistentDataStore`（隔离成立、重启掉登录）。macOS 13 及以下视为不可抹平差异，**不进本包**（归后续分包）。

自研薄绑定能解掉的四点：

1. context / data store 由我们创建，不存在「库没暴露就绕不过去」；
2. mac 产物默认按 `.app` 打包，把「没有 bundle id」这半个原因消掉；
3. 降级不静默——提供 `browser_profile_persistence() -> Persistent | EphemeralOnly`，调用方可在 UI 上提示「重启会掉登录」；
4. 自定义协议**按 context 注册**（旧链是进程级静态注册，多 context 后语义不清）。

profile 挂在 **pane 级参数**上（不是旧链 Browser 实例级的 Options）：「多账号」= 多 pane / 多窗 + 各自 profile。profile 键用可读规范 `<bundle-id>.<profile>`，不用 MD5 转 UUID。

写 mac 后端时的硬事实：`[[WKWebsiteDataStore alloc] initWithIdentifier:]` 这个 API **不存在**，真实的是 `dataStoreForIdentifier:`（14+）；fork 已为此修过一次编译硬错。

### 4.5 纪律（越线即返工）

- pane 之间**不重叠**；浮层（下拉/右键菜单/tooltip/toast/对话框）走**原生窗口**，不用自绘像素盖 webview。机制已落：`overlay_native.mbt` 按「所在窗有已挂载子件」自动切原生档（无网页时仍走图层），弹层是批 A 的附窗；「点外收起」需失焦判据，当前默认关（见 adaptation）。
- webview 区**不吃 `clip_rect`**，圆角/透明/被覆盖不作为承诺。
- 子表面只保留「原生控件嵌入」语义，§4 措辞照此，不叫通用子表面。
- webview 聚焦时本栈的**纯通道 IME 让位**，离开即恢复。
- 接口预留**窗口可见性开关**（爬虫后台要「不可见 webview」），首批不实现但不写死。

### 4.6 明确不做（避免反复讨论）

网络拦截/改写、代理配置、一窗多 webview 并排（Tauri 自己也在 unstable）、Linux 上把 webview 变纹理、首批硬解、首批 GPU 合成、网页内 `<video>` 与自绘播放器统一、macOS 13 及以下的持久化隔离（归后续分包）、Windows/macOS 后端实现（归输入通道另线）。

### 4.7 原生控件嵌入的接口形状（G2 冻结，实现随首个消费者）

- MoonBit 面：`win.mount_child_surface(kind : ChildKind, rect : (Double, Double, Double, Double)) -> ChildSurface`、`ChildSurface::set_rect(..)`、`ChildSurface::unmount()`、`ChildSurface::handle() -> Int64`（能力层拿它去挂真控件）。
- 语义：子表面**不被 Painter 绘制**，z 序在原生侧、恒覆盖在自绘像素之上；**不能用 `clip_rect` 裁剪**，超出窗口的部分由窗口系统裁掉；`rect` 由 yoga-mbt 布局给出，DPI 换算在后端。
- 实现落点（批 B 已落）：窗口内容 = 「绘制区 + 可定位子件」的 **`GtkFixed`**（不用 `GtkOverlay`：带子件的容器其 `pass_through` 事件归属不可靠，Fixed 是普通容器、指针落在子件归子件、落在别处归绘制区，零额外机制）；`ChildKind` 登记制，目前只有 `Webview = 1`。子件槽表记归属窗口，窗口拆除时连带清理。

### 4.8 平台落地要点

- **Linux 最轻**：`nu::Canvas`/`nu::Image` 在 libyue 里就是 Cairo/GdkPixbuf，而 `WebKitWebView` 本身就是带 GdkWindow 的 GtkWidget，libyue 直接把它挂进容器（`nativeui/gtk/browser_gtk.cc:296-306`）。我们拥有 GtkWindow 之后，这就是一次普通 `gtk_container_add` 摆到布局算出的矩形上——**不需要 XEmbed、不需要 GtkPlug/GtkSocket、不需要像素合成**（这是「Linux 锁 GTK3」换来的实际红利，裸 X11 方案在这里要多写一整套嵌入协议）。**只能动态链**：运行期依赖发行版 `webkit2gtk-4.1`（本机实测 2.52.6 在位），已知并接受，`scripts/prebuild.py` 增加该 pkg-config 探测项。协议面照 libyue 的机制移植：`webkit_web_context_register_uri_scheme` + 自定义 `GInputStream` 流式回灌（`nu_protocol_stream.cc:31-36`）+ `finish_error` 拒绝 + 无注销 API 时用错误 handler 顶替（`browser_gtk.cc:483-493`）。
- **Windows 是真成本**：WebView2 需要子 HWND，且是**两级异步 COM 创建**（环境 → controller，`webview2/browser_impl_webview2.cc:113-122,516-529`），创建期失败同步回退 IE、就绪前 `LoadURL` 要排队（`browser_win.cc:56-72,199-214`），跨 HWND 的焦点与滚轮要转发（`:103-152`）。
- **自定义协议（本地内容通道）：公开面只给「名字先预声明」**（2026-10-12 定案，三平台取严）。三家的入口与时机都不一样：

  | | Linux WebKitGTK | Windows WebView2 | macOS WKWebView |
  |---|---|---|---|
  | 注册入口 | `webkit_web_context_register_uri_scheme` | `ICoreWebView2CustomSchemeRegistration`（环境选项）+ `WebResourceRequested` | `WKURLSchemeHandler`（`setURLSchemeHandler:forURLScheme:`，macOS 10.13 / iOS 11 起） |
  | 最晚定名时机 | 随时（按 context） | **建 environment 之前**（一进程一次、全视图共用） | **建该视图之前**（挂在它的 configuration 上） |
  | 响应形态 | 回调里同步给流 | 事件驱动，可 deferral | 异步 `didReceive response/data/finish` |
  | 禁止注册的 scheme | — | — | `http/https/file`（Apple 拒绝；先 `handlesURLScheme:` 探） |

  因此契约定为：**`webview_predeclare_schemes([...])`（建第一扇 webview 之前）→ `register_protocol(scheme, root)` 只能用在已声明的名字上，根目录随时可换、`unregister_protocol` 顶替成错误 handler**。空名单封版时补缺省名 `app`（零配置可用）。Linux 那份「随时注册新名字」的动态能力仍在桩里，但**不对外**——暴露它等于写一份在 Windows/mac 上会失效的代码。
- **回灌文本时 MIME 是唯一编码口径**：协议响应里只递 content type，裸 `text/html` 会被按 ISO-8859-1 解（页内 `<meta charset>` 要等标签解出来才看得见），中文页整屏乱码；`load_html` 那条通道不会露这个症状，因为它的入参本身就是 UTF-8 文本。所以本地内容通道的文本类一律给 `...; charset=utf-8`（三家后端同口径：WebView2 的 `WebResourceRequested` 响应、WKWebView 的 `didReceive response` 同样只认响应头）。
- **Windows 侧还有一条更省的路（后端实现时二选一，调用方不必知道）**：`SetVirtualHostNameToFolderMapping`（主机名 → 本地目录，子资源在 WebView2 **进程内**解析、算安全上下文）。代价是 URL 形状变成 `https://<host>/...` 而非 `scheme://`。若调用方能接受 https 主机名，这条比「预注册 scheme + 逐请求回包」又快又正；坚持自定义 scheme 形状的就走预注册那条。**另记一条实测事实**：WebView2 的 `NavigateToString` 在微软自己的对比表里「其他网络资源」一栏是 ❌（相对路径子资源根本不去取），与我们在 Linux 上测到的 `load_html` 不入历史同属「别用它做本地 App」的证据——本地页一律走协议/虚拟主机 URL。
- **macOS 已知风险（2026-10-12 修正范围）**：`NUWebView : WKWebView` 是 NSView，本体简单；**自定义协议现在有公开入口**（`WKURLSchemeHandler`，macOS 10.13+），libyue 当年走的 `WKBrowsingContextController registerSchemeForCustomProtocol:` 私有 API 是更老的路线。要验的是「公开入口够不够用」：自定义 scheme 默认**非标准**（origin/localStorage/cookie 行为要另配）、以及旧系统上 POST body 丢失那类坑。连同 `loadHTMLString:baseURL:` 的历史语义一起，随 mac 真机清单验。
- **不找第三方绑定**：渲染引擎必然是系统那三家，第三方也绕不开，真正的选择题只是绑定层谁写。MoonBit 生态内没有可靠的现成 webview 封装（待查证），C 层的通用 webview 库其同步模型不覆盖 custom scheme 流式与 JS binding 面，省不了工作量。结论：**自研薄绑定，libyue 当语义参考**。
- **契约沿用**：`yue/browser/browser.mbt` 的 22+6 个方法名（`load_url`/`go_back`/`execute_javascript`/`on_update_title`…）平台中立，直接作为新栈 browser 契约。三个绑死点要重做：协议载荷那套 `[ok][mime_len][mime][content_len][content]` 小端裸字节 ABI（`browser.mbt:252-292`，CORE1 越界读教训即出于此，见 `adaptation.md:133`）改**结构化返回值**；`(f, closure)` 蹦床随新 shim 重设计；内嵌 `@yue.View` 并 extend 40+ ViewLike（`types.mbt:7-13`）换成新宿主类型。现有面还缺 `on_close`/`on_start|fail_navigation`/`AddUserScript`/高级 binding，新栈补齐。

### 4.9 批次计划（本轮只做 Linux 闭环）

| 批 | 内容 | 验收 |
|---|---|---|
| **A** ✅ | 多窗口宿主：`core/app.mbt` 的 `App::new` 从「只建一窗」改成「一宿主管 N 窗，每窗一棵控件树、共用一个 `Loop`」（注册表在 `core/host.mbt`） | 纯自绘即可验：开一个「关于」窗；两窗各自收到注入的点击，关单窗不影响宿主 |
| **B** ✅ | pane 模型 + webview pane：把 §4.7 的 `mount_child_surface(kind, rect)` 落成「容器里放一个原生子件」；Linux 走 WebKitGTK | 整页（单 pane 铺满）与左右分栏（原生工具栏 + webview）两种摆法都出图 |
| **C** ✅（余项：本地内容通道与导航细粒度 reason 已接，跨窗 cookie 同步待接） | JS 桥 + DOM 抓取 + 导航面：`evaluate_javascript`/`add_user_script`/双向通道/UA+cookie+profile 与 persistence 探测/前进后退刷新与标题 URL 回调/`window.open` 策略/下载回调/权限默认拒绝可转原生提示/web 进程崩溃回调；余项为 `register_protocol`（自定义协议按 context 注册，`scheme://` 映射到根目录下的真文件）与 `NavError`（load-failed 拆 `uri|domain|code|message`、重定向独立一条） | 契约沿用 22+6 方法名，协议载荷改结构化返回；真实站点由使用者复验 |
| **D** ✅（首批 + 控制面 + 倍速 + 内嵌字幕轨已落；余项为 ASS 样式渲染与多轨切换，见 TODO） | 媒体播放器：复用 `modules/ffmpeg-mbt`（零 libyue 依赖，已有 `decode_rgba`/`decode_pcm`/`seek`/`duration_s`/`video_fps`）+ miniaudio 设备层；新写播放器 UI、帧上屏、音频时钟与同步、seek 防抖、倍速（零 C：PCM 线性重采样，音高随动）、逐帧步进、音量条、字幕叠加（**外部 SRT/VTT 与容器内嵌轨两条来源**，内嵌轨由 `ffmpeg-mbt` 的 `subtitle_cues` 整条读出） | 旧链踩过的坑照 adaptation.md 逐条验收（音画不同轴、seek 后进度从零重涨、换载崩溃等） |
| **E** ✅ | 原生弹层窗口：自绘 overlay 的「原生档」（`win` 目前无 popup/transient API），供 §4.5 的浮层纪律落地 | 下拉/右键菜单/对话框能盖住 webview pane |
| 交付面 | 示例迁移（`hello`/`hello-themed`/`showcase` 走新栈）、中英使用文档按新栈重写、README 新截图、CI 三平台脚本、发布链 | A/B 落地后接上 |
| 输入通道另线 | 先落**平台无关**的键位/指针/修饰键/IME 触发条件映射层（纯函数 + wbtest）；Win32/Cocoa 后端随各自真机 | 不写不可验的代码 |

**验证示例归口**：webview 与媒体侧的同类验证集中累积进 **`modules/gui-examples/native-web`**（批 B 起建：整页摆法、左右分栏、JS 桥与抓取、播放器各占一页；2026-10-12 从 `examples/` 整包迁到独立示例模块——媒体包归 `NoahLiu/gui-media`，主模块不能再反向依赖它），不为单个特性再开新示例；GUI 侧累计页仍是 `examples/native-app`，系统能力侧是 `examples/native-sys`。

## 5. 阶段划分与每批验收

**本分支门禁口径**（因 §1 分支纪律而立的例外）：主链路与发布分支仍按 AGENTS 规则 9（`moon check` 零警告 + 全仓 `moon test` 全绿才提交）；本分支 G1–G6 期间**允许全仓为红**，逐批验收改为分包门禁——① `moon test -p NoahLiu/yoga-mbt/src` 全绿且基线 740 条不掉；② 新栈各包单独 `moon check` 零警告 + 各自测试全绿；③ 提交说明记录当前全仓红点数量与原因，**红点只减不增**；④ G7 组件与声明式层接线完成后恢复全仓门禁。真机视觉/交互验证仍按 AGENTS 规则 6 出清单由协作方执行，实测结论回写 `adaptation.md`，一批一提交一推送。此例外与 AGENTS 条文的差异在 G7 收口时一并回写 AGENTS.md。

| 阶段 | 内容 | 验收 |
|---|---|---|
| **G0** | **Linux IME spike**（`experiment/ime_probe`，纯通道 `GtkIMContext` 与可见 `GtkEntry` 两模式同二进制切换）——**探针已落地**（`5a79180`：循环所有权在 MoonBit、preedit 与插入符全自绘、光标按 UTF-8 字节自管；实测「22px 盒子的 GtkEntry 被主题撑到 33、加 `min-height:0` 后 24」已记档） | **真机已回证（fcitx5）**：补 `gtk_im_context_focus_in`（未调时 `GtkIMMulticontext` 落回内建 Simple 上下文，每键直commit、preedit 恒 0）后**中文 commit 路径可用**；顶层 focus-in/out 需同步以丢残留组合串；**preedit 内联已闭环**（四条件 + 组合串单处拼接，详见 §3 表与 adaptation；主体重复显示曾疑输入法、实为探针两处拼接）。ibus 未装未测。结论入 `adaptation.md`「G0 · 真机回证」条 |
| **G0b** | 绑定层摘除与目录重排：删 §2 清单里的 FFI 绑定文件与 `shim/`、`lib/`、`vendor/` 构建链，建 `yue/{win,core,render,text,input,sys}` 骨架 | 新栈各包可 `moon check`；全仓红点清单成文，此后**只减不增** |
| **G1** | 绘制契约 + 离屏回归：`Painter` 矩形级子集签名定稿、`Bitmap`、yoga-mbt 盒子→像素 | 断言比 RGBA 字节；`moon check` 零警告 |
| **G2** ✅ | GTK3 窗口地基：建窗、`g_main_context_iteration` 驱动循环（不用 `gtk_main`）、`g_main_context_wakeup` 留跨线程唤醒位、事件全排空、**`mount_child_surface` 接口形状定死**（§4，形状已冻结、实现随首个消费者落地） | 独立进程出图；`open→create→loop→close` 干净退出，无退出期崩溃 |
| **G3** ✅ | 首批**已完成**：Cairo 光栅器（位图格式对齐 ARGB32 预乘、路径/贝塞尔/弧/变换/裁剪/内侧描边，与纯矩形绘制器逐像素一致，14/14 断言）。次批**已完成**：`text`（Pango 测量与绘制，字号=逻辑像素绝对尺寸、baseline=到盒顶与 yoga-mbt 同定义、ellipsize/wrap 照老师口径；测量不断言具体像素只断单调与约束，避免换机假红）。图标路径数据出图**顺延 G7**：`icons` 的 31 处 `@yue` 引用里只有 2 处是绘制、其余是声明式组件，单独为绘制拆这个 4297 行文件不划算，等声明式层一起接 | 首批：`moon test render` 14/14。次批：`moon test -p text` 7/7 + 示例窗口内中英混排文本、冒烟 52 帧退出码 0 |
| **G4** | 焦点栈与键盘、自绘 caret/选区、剪贴板；`TextEditorHost` 抽象落地 | 英文/数字在自绘输入框可打字；Tab/Shift+Tab 焦点跳转可用 |
| **G5** ◐ | **Linux 纯通道首批已完成**（`win/im.mbt` + GtkIMMulticontext 四条件、`Editor.set_preedit` 显示态不并入文本、示例自绘下划线与候选窗矩形）。四坑记档：realize 前设 client window 会静默不接管、commit 串不得 g_free（双释放崩）、喂 surrounding 时禁调 reset（打断组合）、preedit-changed 签名要 get_preedit_string。待补：ibus 一套、Windows/macOS 通道 | 本机 xdotool 注入 `nihao`+空格 → `a='hello你哈哦'`（字母零残留、未被消费键才进内核）；待肉眼：preedit 下划线观感与候选窗贴合 |
| **G6** | 系统能力平移（`yue/system`、`yue/traybus`、图标数据）+ 图片解码补齐 | 既有 wbtest 随包平移全绿 |
| **G7** | 组件与声明式层移植：`components`/`charts` 挂上新 `Painter`，`declarative` 的 mount 目标改 yoga-mbt 节点 | showcase 组件页与图表页在新栈渲染，与旧链路视觉逐页对照；**恢复全仓门禁** |
| **G8** | 原生控件嵌入消费者：按 §4.9 的批 A→E 推进（多窗口宿主 → pane 模型与 webview pane → JS 桥与 DOM 抓取 → 媒体播放器 → 原生弹层窗口）。browser 自研薄绑定（§4.8，引擎为系统三家），媒体走 CPU 回灌自绘（§4.2 第 3 条），**不再**共用「子表面」这一说法 | 契约沿用 `browser.mbt` 方法名、协议载荷改结构化返回；Linux 真机网页加载与自定义协议可打（清单交协作方）；每批分包门禁 + 一批一提交 |

**G0b 完成后的红点基线（实测，此后只减不增）**：

- 全仓 `moon check`：**290 errors / 68 warnings**，中断在根 `yue` 包（下游 `components`/`charts`/`declarative`/`markdown`/`browser`、`examples/*`、`modules/gui-examples`、`modules/gui-media` 未展开，故实际红点数以此下限计）。
- 根包剩余文件按「对已删类型（`View`/`Painter`/`RectF`/`Node`/`ffi_*`）的引用数」排优先级：`types.mbt` 62、`splitter.mbt` 43、`events.mbt` 34（内层键码表与 `KeyEvent` 结构体保留复用）、`geometry.mbt` 17、`signals.mbt` 15、`theme.mbt` 9、`clipboard.mbt` 7、`video_view.mbt` 6、`props.mbt` 3、`fsx.mbt` 3、`system.mbt` 2、`color.mbt` 1；零引用可独立编译的：`vscjson.mbt`、`store.mbt`、`png_rgba.mbt`、`version.mbt` 及各 `*_test.mbt`。
- 已删除：`shim/`(308K)、`lib/`(70M 预构建静态库)、`scripts/prepare.py`、`scripts/vendor_native.py`、`scripts/make_webkit_stubs.py`、`yue/win_gui.c`，以及 `yue/ffi.mbt`(2455)、`yue/browser/ffi.mbt`(198)、`yue/{app,methods,widgets,view,painter}.mbt` 与 14 个 1:1 控件 wrapper。`vendor/` 与 `build/` 本就在 `.gitignore` 内，留在磁盘作只读参考，不进构建也不进提交。
- `scripts/prebuild.py` 收缩为只服务输入法探针与新栈系统库参数（GTK3/Pango/X11 由 pkg-config 探测），不再下载或构建任何 libyue 产物。
- 命令口径两条：workspace 下 `moon check`（无参数）会连根包一起查，因此绿色包用路径形式点名 `moon check render modules/yoga-mbt/src`；`-p` 只对 `moon test` 有效（`moon check -p 包名` 会把包名当目录）。
- 绿色基线复验：`moon test -p NoahLiu/yoga-mbt/src` **79/79**、`moon test -p NoahLiu/native-gui/render` **8/8**，两者 `moon check` 均零警告。

**G2 完成记录（2026-10-10）**：`core/loop.mbt`（循环与任务调度，9 条单测）+ `win`（GTK3 建窗、`GtkDrawingArea` 上屏、`pump/wait/wake` 泵、事件全排空）+ `examples/native-window` 驱动示例。冒烟（本机 X11/XFCE，助手宿主）：进程存活、动画 52 帧、`open→create→loop→close` 干净退出、退出码 0；三个绿色包 `moon check` 零警告，`yoga-mbt` 79/79 未掉。四条实测坑与「Loop 时基必须显式 start」一并记入 adaptation.md「跨平台通用」节 G2 条。


**布局侧遗留**：`/home/lkyh/ownCode/yue/patches/` 是真实 bug 语料，须转成 yoga-mbt 回归用例——首条 `93078300`（`display:none` 清零重显后 flex 简写派生的 basis-0 永久驻留，auto 高父容器下节点永久 0 高，即 MoonBit 层 tabs 切页塌陷根因）。yoga-mbt 与 libyue 复刻**同工程同批推进**：每个 G 阶段用到布局就顺带补该路径的 yoga 回归，不再分两条时间线。

## 6. 风险与过渡期

- **两份文本状态**（仅 Windows/macOS 的 C 兜底路径）：原生控件自持 text/selection，须每拍同步并拦编辑键；这是该形态的长期 bug 面（快速连打丢字、拖窗、剪贴板回环）。Linux 取 B 即无此项。
- **例外扩散**：任何平台一旦把可见原生控件当默认，第二个例外（下拉、日期、富文本）会跟上，最终得到「少数派永远不一致、而少数派恰是用户碰得最多的输入框」。C 只作为**有明确触发条件的兜底**，不进默认路径。§4 的原生子表面是**能力型例外**（网页/视频本质上不可自绘），与兜底型例外不同类，但同样要登记在册、逐条评审。
- **过渡期红点**：G0b 摘除绑定后，`examples/*`、`modules/gui-examples`、`modules/gui-media` 会成片编译失败——这是工作队列而非事故，但**发布链不受影响**：`master` 仍是完整的旧链路（`shim + libyue`，0.5.x 与 `bin-*`/`vendor-*` 标签照旧），本分支的破坏性只在分支内。风险在于分支寿命越长、与 master 的文档/工具链漂移越大，故每个 G 阶段完成即提交推送、不积压。
- **回归基线**：全仓 `moon test` 740 条里有约 660 条属旧链路（yue 包测试）。G0b 后这些随绑定文件一起消失，是**净覆盖损失**——补法：新栈每包自建 wbtest，且平移 `yue/system`/`yue/traybus` 的既有 wbtest（G6），把「测试随资产走」而非「测试随绑定走」作为验收项。
- **工时冲突**：新栈与 `TODO.md` 的 10 月月度目标（系统接口 / 音频 / 视频渲染收尾）及 Q4 承诺（macOS 真机验证 + 0.5.11 发布闭环）争同一批工时。
- **退出期拆除顺序**：新栈必须遵守「先停派发、再拆对象」——libyue 在 `experiment/exit_crash/patch_notes.md:105-118` 栽过的偶发段错误属通用问题，不随换后端消失。
- **无障碍**：屏幕阅读器读不到自绘文本（ATK / UIA / NSAccessibility），本计划不含，仅记档。
