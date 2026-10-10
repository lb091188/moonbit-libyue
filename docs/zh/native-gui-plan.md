# MoonBit 原生 GUI 栈总体实施计划（Linux 站先行）

> 状态：**定稿**（2026-10-10 与协作方逐轮敲定）。后续批次按本文推进；实测结论与踩坑按仓库维护约定回写 [adaptation.md](adaptation.md)，本文只记「是什么 / 怎么分层 / 每批验收什么」。

## 1. 定案要点

- **路线**：自绘。新栈自己拥有窗口、像素缓冲、事件循环与布局，控件**全部基于 Painter 自绘 + 自定义主题**，不再提供独立的原生控件。
- **libyue 的角色**：**老师，不是运行时依赖**。新栈不含 libyue 一行代码；它的价值是行为语义参考、可平移的纯 MoonBit 上层资产、以及 `patches/` 里的真实 bug 语料。需要纯系统能力时按需调用，不作为渲染或布局后端。
- **布局层**：`modules/yoga-mbt`（纯 MoonBit Flexbox，只对齐 Web 标准），YG1–YG3 已完成。
- **Linux 后端锁定 GTK3**（`gtk+-3.0` 3.24.x）。理由两条：`scripts/prebuild.py` 现有依赖清单已含 `gtk+-3.0`/`pangoft2`/`fontconfig`/`x11`，用 GTK **零新增运行期依赖**；输入法的系统客户端（`GtkIMContext`）与 Wayland 后端都挂在这条链上。**裸 X11 自研窗口后端方案已删除**，不保留备选。
- **绘制**：`nu::Painter` 在 libyue 里只是 Cairo 的薄封装，因此它是**待移植的绘制库**而非后端。新栈直链 `cairo`/`pango`，`Painter` 的方法签名照抄当契约。
- **版本纪律**：不试 GTK4——`nu::*` 的可比语义（焦点、编辑器、主题）全部是 GTK3 行为。
- **分支纪律**（2026-10-10 追加）：本特性分支**不保留老的 libyue 绑定，完全重来**——`shim/`、`lib/<平台>/`、`vendor/libyue` 与新栈不同进程共存，按 §2 清单摘除；**不设包内双轨开关**。因此允许「新栈起来之前全仓门禁为红」，红点即工作队列，口径见 §5。布局层（yoga-mbt）与 libyue 复刻**合算一个工程、一起推进**，不再分成两条时间线。

## 2. 包结构（替代主包 `yue/`）

新栈**不建独立子模块**，而是直接替代主包 `yue/`：对外包名仍是 `@yue`，`examples/*` 与下游 main 包的引用形态保持不变，逐包把实现换掉。分包：

| 包 | 内容 | 来源 |
|---|---|---|
| `yue/win` | 平台窗口后端：建窗、事件、DPI、焦点栈、**原生子表面挂载**（§4）；Linux=GTK3，Windows=Win32，macOS=Cocoa | 新写 |
| `yue/core` | 事件循环（`g_main_context_iteration` 单步泵 + `wakeup`）、App/Window、脏区重绘、yoga-mbt 接线、命中测试、**哑视图（可吃键盘焦点）**、自绘组件宿主 | 新写 |
| `yue/render` | `Painter` 契约 + Cairo 实现 + `Bitmap`（自有 RGBA 缓冲，离屏与上屏同源） | 契约照抄 `yue/painter.mbt` 58 法 |
| `yue/text` | `Text`/`Font`/`AttributedText` 语义层（先委托 Pango，后按需要自研栅格化）；测量与基线回灌 `set_measure`/`set_baseline` | 参考 `nativeui/gfx/` |
| `yue/input` | 编辑器内核（文档 / 选区 / 编辑操作 / caret）+ `TextEditorHost` 后端抽象 | 新写 |
| `yue/sys` | 系统能力 | 平移 `yue/system`（559 fn）、`yue/traybus`（175 fn）、`yue/icons`（803 个图标路径数据） |

`shim/` 的职能随之改变：从「libyue 的 C++ 转接」变成「本栈自己的平台后端 stub」，链接参数仍由 `scripts/prebuild.py` 全权托管（AGENTS 规则 1/2 不变）。

**可直接平移的既有资产**（按对 libyue 的依赖形态分类）：纯 MoonBit 零依赖的 `yue/system`、`yue/traybus`、`yue/geometry.mbt`、`yue/signals.mbt`、图标路径数据、图表纯算法层；绑定绘制语义的 `yue/components`（约 190 fn）与 `yue/charts`（约 289 fn）在新栈里**调用点不变**，只换 `Painter` 实现；声明式层的 `Node{mount}` 闭包模式（`yue/node.mbt:12-24`）把挂载目标从 `View` 换成 yoga-mbt 节点即可复用。

**绑定层摘除清单**（按 `ffi` 引用实测统计，行数为该文件总行）：核心绑定 `yue/ffi.mbt`(2455/439 处)、`yue/browser/ffi.mbt`(198/27)、`yue/methods.mbt`(643/87)、`yue/widgets.mbt`(652/71)、`yue/view.mbt`(611/66)、`yue/painter.mbt`(731/48，契约保留、实现替换)、`yue/events.mbt`(909/19，键码表与结构体保留，注册蹦床段 :628-827 重写)、`yue/app.mbt`、1:1 控件 wrapper `button/menu/dialog/message_box/scroll/separator/group/tab/table/text_edit/tray/style/node`，以及 `yue/{props,splitter,envx,fsx,error,store,system}.mbt` 与 `yue/components/components_{datetime,overlay}.mbt`、`yue/declarative/hovergroup.mbt` 里的 FFI 段。零 FFI 的资产文件（`charts/*`、`components/components_{display,draw,form,nav,style,table,text}`、`overlays.mbt`、`declarative/{declarative,overlay_scroll}`、`markdown/`、`icons/`、`system/*` 大部、`traybus/*` 大部、`png_rgba.mbt`）**保留原地**，其编译错误按阶段消化。

## 3. 输入与输入法（定案表）

三平台**都不实现任何输入法协议**，一律取系统的输入客户端；差别只在客户端形态。

| 平台 | 后端 | 系统 API | 状态权威 | 兜底 |
|---|---|---|---|---|
| Linux | **B 纯通道** | `gtk_im_multicontext_new` + `gtk_im_context_filter_keypress` + `commit`/`preedit-*` 信号 + `gtk_im_context_set_cursor_location` | 单状态（自绘编辑器） | 无 |
| Windows | **B 优先** | 无文本子窗口 + `ImmAssociateContext`；`WM_IME_COMPOSITION` 读 `GCS_COMPSTR`/`GCS_RESULTSTR`，`ImmSetCompositionWindow`/`ImmSetCandidateWindow` 定位 | 单状态 | **C**：可见 `EDIT` 子窗口（用于只走 TSF、legacy 通道打不出中文的 IME） |
| macOS | **C 先行** | `NSTextField`（borderless + `drawsBackground=NO` + `textColor`/`font` + `focusRingType=None`），marked text 由系统显示 | 控件持有 | 待有 mac 真机后升级为 **B**（自研 `NSTextInputClient`） |

统一抽象（`src/input`）——上层自绘控件只见这四个签名，后端可逐平台替换：

```
process_key(keysym, modifiers, is_press) -> Consumed | NotConsumed
commit(text)
preedit(text, caret, active)
set_cursor_rect(x, y, w, h)
```

**为什么 mac 不先做 B**：`NSTextInputClient` 十余个方法必须互相自洽；`NSRange` 以 UTF-16 code unit 计（与 MoonBit 的 UTF-8 字节需逐区间换算，参照 `TODO.md` MD2 已踩过的同类坑）；且 `acceptsFirstResponder`/`keyDown:`/`inputContext` 活在 ObjC 消息派发里，MoonBit 的 native FFI 只能调 C 函数，需要自带 `.mm` 的 NSView 子类。三笔成本叠加，而 mac 当前无真机可验（`TODO.md` O4 前置即「获得 mac 真机」），故整块延后。

## 4. 原生子表面（browser 与视频）

有些东西不可能自绘：网页渲染（WebKit/WebView2/WKWebView）与视频显示（`modules/yue-media` 的 VideoPlayer 现在也是原生 view）。这不是 browser 专用补丁，而是窗口层的一条**通用能力**，必须在 G2 就把接口形状定死（`mount_child_surface(handle, rect)`，rect 由 yoga-mbt 给），事后补等于重做窗口层。

- **Linux 最轻**：`nu::Canvas`/`nu::Image` 在 libyue 里就是 Cairo/GdkPixbuf，而 `WebKitWebView` 本身就是带 GdkWindow 的 GtkWidget，libyue 直接把它挂进容器（`nativeui/gtk/browser_gtk.cc:296-306`）。我们拥有 GtkWindow 之后，这就是一次普通 `gtk_container_add` 摆到布局算出的矩形上——**不需要 XEmbed、不需要 GtkPlug/GtkSocket、不需要像素合成**（这是「Linux 锁 GTK3」换来的实际红利，裸 X11 方案在这里要多写一整套嵌入协议）。协议面照 libyue 的机制移植：`webkit_web_context_register_uri_scheme` + 自定义 `GInputStream` 流式回灌（`nu_protocol_stream.cc:31-36`）+ `finish_error` 拒绝 + 无注销 API 时用错误 handler 顶替（`browser_gtk.cc:483-493`）。
- **Windows 是真成本**：WebView2 需要子 HWND，且是**两级异步 COM 创建**（环境 → controller，`webview2/browser_impl_webview2.cc:113-122,516-529`），创建期失败同步回退 IE、就绪前 `LoadURL` 要排队（`browser_win.cc:56-72,199-214`），跨 HWND 的焦点与滚轮要转发（`:103-152`）。
- **macOS 已知风险**：`NUWebView : WKWebView` 是 NSView，本体简单；但自定义协议靠私有 API `WKBrowsingContextController registerSchemeForCustomProtocol:`（`nu_custom_protocol.mm:45-52`），新系统不可靠——挂到 mac 线遗留清单，不当等价能力规划。
- **不找第三方绑定**：渲染引擎必然是系统那三家，第三方也绕不开，真正的选择题只是绑定层谁写。MoonBit 生态内没有可靠的现成 webview 封装（待查证），C 层的通用 webview 库其同步模型不覆盖 custom scheme 流式与 JS binding 面，省不了工作量。结论：**自研薄绑定，libyue 当语义参考**。
- **契约沿用**：`yue/browser/browser.mbt` 的 22+6 个方法名（`load_url`/`go_back`/`execute_javascript`/`on_update_title`…）平台中立，直接作为新栈 browser 契约。三个绑死点要重做：协议载荷那套 `[ok][mime_len][mime][content_len][content]` 小端裸字节 ABI（`browser.mbt:252-292`，CORE1 越界读教训即出于此，见 `adaptation.md:133`）改**结构化返回值**；`(f, closure)` 蹦床随新 shim 重设计；内嵌 `@yue.View` 并 extend 40+ ViewLike（`types.mbt:7-13`）换成新宿主类型。现有面还缺 `on_close`/`on_start|fail_navigation`/`AddUserScript`/高级 binding，新栈补齐。

## 5. 阶段划分与每批验收

**本分支门禁口径**（因 §1 分支纪律而立的例外）：主链路与发布分支仍按 AGENTS 规则 9（`moon check` 零警告 + 全仓 `moon test` 全绿才提交）；本分支 G1–G6 期间**允许全仓为红**，逐批验收改为分包门禁——① `moon test -p NoahLiu/yoga-mbt/src` 全绿且基线 740 条不掉；② 新栈各包单独 `moon check` 零警告 + 各自测试全绿；③ 提交说明记录当前全仓红点数量与原因，**红点只减不增**；④ G7 组件与声明式层接线完成后恢复全仓门禁。真机视觉/交互验证仍按 AGENTS 规则 6 出清单由协作方执行，实测结论回写 `adaptation.md`，一批一提交一推送。此例外与 AGENTS 条文的差异在 G7 收口时一并回写 AGENTS.md。

| 阶段 | 内容 | 验收 |
|---|---|---|
| **G0** | **Linux IME spike**（`experiment/ime_probe`，纯通道 `GtkIMContext` 与可见 `GtkEntry` 两模式同二进制切换）——**探针已落地**（`5a79180`：循环所有权在 MoonBit、preedit 与插入符全自绘、光标按 UTF-8 字节自管；实测「22px 盒子的 GtkEntry 被主题撑到 33、加 `min-height:0` 后 24」已记档） | **待协作方真机回填**：fcitx5 与 ibus 两套各验 commit 送达、preedit 内联、候选窗定位、快捷键穿透；结论回填 `adaptation.md` 并据此确认第 3 节表 |
| **G0b** | 绑定层摘除与目录重排：删 §2 清单里的 FFI 绑定文件与 `shim/`、`lib/`、`vendor/` 构建链，建 `yue/{win,core,render,text,input,sys}` 骨架 | 新栈各包可 `moon check`；全仓红点清单成文，此后**只减不增** |
| **G1** | 绘制契约 + 离屏回归：`Painter` 矩形级子集签名定稿、`Bitmap`、yoga-mbt 盒子→像素 | 断言比 RGBA 字节；`moon check` 零警告 |
| **G2** | GTK3 窗口地基：建窗、`g_main_context_iteration` 驱动循环（不用 `gtk_main`）、`g_main_context_wakeup` 留跨线程唤醒位、事件全排空、**`mount_child_surface` 接口形状定死**（§4） | 独立进程出图；`open→create→loop→close` 干净退出，无退出期崩溃 |
| **G3** | Cairo 绘制 + Pango 文本（路径/变换/裁剪/图标；单行与多行测量绘制） | 图标页与两张图表自绘出图；测量语义与 `GetOneLineHeight` 等对齐 |
| **G4** | 焦点栈与键盘、自绘 caret/选区、剪贴板；`TextEditorHost` 抽象落地 | 英文/数字在自绘输入框可打字；Tab/Shift+Tab 焦点跳转可用 |
| **G5** | 输入法接入（按第 3 节表逐平台） | Linux 真机中文输入（fcitx5 / ibus 两套）；Windows 逐 IME 验，不通者降 C |
| **G6** | 系统能力平移（`yue/system`、`yue/traybus`、图标数据）+ 图片解码补齐 | 既有 wbtest 随包平移全绿 |
| **G7** | 组件与声明式层移植：`components`/`charts` 挂上新 `Painter`，`declarative` 的 mount 目标改 yoga-mbt 节点 | showcase 组件页与图表页在新栈渲染，与旧链路视觉逐页对照；**恢复全仓门禁** |
| **G8** | 原生子表面消费者：browser 自研薄绑定（§4，引擎为系统三家）+ `modules/yue-media` 的 VideoPlayer 走同一 `mount_child_surface` 通道 | 契约沿用 `browser.mbt` 方法名、协议载荷改结构化返回；Linux 真机网页加载与自定义协议可打（清单交协作方） |

**布局侧遗留**：`/home/lkyh/ownCode/yue/patches/` 是真实 bug 语料，须转成 yoga-mbt 回归用例——首条 `93078300`（`display:none` 清零重显后 flex 简写派生的 basis-0 永久驻留，auto 高父容器下节点永久 0 高，即 MoonBit 层 tabs 切页塌陷根因）。yoga-mbt 与 libyue 复刻**同工程同批推进**：每个 G 阶段用到布局就顺带补该路径的 yoga 回归，不再分两条时间线。

## 6. 风险与过渡期

- **两份文本状态**（仅 Windows/macOS 的 C 兜底路径）：原生控件自持 text/selection，须每拍同步并拦编辑键；这是该形态的长期 bug 面（快速连打丢字、拖窗、剪贴板回环）。Linux 取 B 即无此项。
- **例外扩散**：任何平台一旦把可见原生控件当默认，第二个例外（下拉、日期、富文本）会跟上，最终得到「少数派永远不一致、而少数派恰是用户碰得最多的输入框」。C 只作为**有明确触发条件的兜底**，不进默认路径。§4 的原生子表面是**能力型例外**（网页/视频本质上不可自绘），与兜底型例外不同类，但同样要登记在册、逐条评审。
- **过渡期红点**：G0b 摘除绑定后，`examples/*`、`modules/yue-examples`、`modules/yue-media` 会成片编译失败——这是工作队列而非事故，但**发布链不受影响**：`master` 仍是完整的旧链路（`shim + libyue`，0.5.x 与 `bin-*`/`vendor-*` 标签照旧），本分支的破坏性只在分支内。风险在于分支寿命越长、与 master 的文档/工具链漂移越大，故每个 G 阶段完成即提交推送、不积压。
- **回归基线**：全仓 `moon test` 740 条里有约 660 条属旧链路（yue 包测试）。G0b 后这些随绑定文件一起消失，是**净覆盖损失**——补法：新栈每包自建 wbtest，且平移 `yue/system`/`yue/traybus` 的既有 wbtest（G6），把「测试随资产走」而非「测试随绑定走」作为验收项。
- **工时冲突**：新栈与 `TODO.md` 的 10 月月度目标（系统接口 / 音频 / 视频渲染收尾）及 Q4 承诺（macOS 真机验证 + 0.5.11 发布闭环）争同一批工时。
- **退出期拆除顺序**：新栈必须遵守「先停派发、再拆对象」——libyue 在 `experiment/exit_crash/patch_notes.md:105-118` 栽过的偶发段错误属通用问题，不随换后端消失。
- **无障碍**：屏幕阅读器读不到自绘文本（ATK / UIA / NSAccessibility），本计划不含，仅记档。
