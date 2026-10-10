# MoonBit 原生 GUI 栈总体实施计划（Linux 站先行）

> 状态：**定稿**（2026-10-10 与协作方逐轮敲定）。后续批次按本文推进；实测结论与踩坑按仓库维护约定回写 [adaptation.md](adaptation.md)，本文只记「是什么 / 怎么分层 / 每批验收什么」。

## 1. 定案要点

- **路线**：自绘。新栈自己拥有窗口、像素缓冲、事件循环与布局，控件**全部基于 Painter 自绘 + 自定义主题**，不再提供独立的原生控件。
- **libyue 的角色**：**老师，不是运行时依赖**。新栈不含 libyue 一行代码；它的价值是行为语义参考、可平移的纯 MoonBit 上层资产、以及 `patches/` 里的真实 bug 语料。需要纯系统能力时按需调用，不作为渲染或布局后端。
- **布局层**：`modules/yoga-mbt`（纯 MoonBit Flexbox，只对齐 Web 标准），YG1–YG3 已完成。
- **Linux 后端锁定 GTK3**（`gtk+-3.0` 3.24.x）。理由两条：`scripts/prebuild.py` 现有依赖清单已含 `gtk+-3.0`/`pangoft2`/`fontconfig`/`x11`，用 GTK **零新增运行期依赖**；输入法的系统客户端（`GtkIMContext`）与 Wayland 后端都挂在这条链上。**裸 X11 自研窗口后端方案已删除**，不保留备选。
- **绘制**：`nu::Painter` 在 libyue 里只是 Cairo 的薄封装，因此它是**待移植的绘制库**而非后端。新栈直链 `cairo`/`pango`，`Painter` 的方法签名照抄当契约。
- **版本纪律**：不试 GTK4——`nu::*` 的可比语义（焦点、编辑器、主题）全部是 GTK3 行为。

## 2. 模块结构

新增单个子模块 `modules/mbt-gui`（对齐 `modules/ffmpeg-mbt` 形态：自带 `prebuild.py` + `pkg-config` 探测 + `native-stub`，`supported_targets = "native"`，`moon.work` 注册一个成员），**模块内分包、不拆成多个可独立发布的子模块**——依据仓库记过的「模块级循环依赖导致发布互等死锁」教训。

| 包 | 内容 | 来源 |
|---|---|---|
| `src/win` | 平台窗口后端：建窗、事件、DPI、剪贴板、焦点栈；Linux=GTK3，Windows=Win32，macOS=Cocoa | 新写 |
| `src/render` | `Painter` 契约 + Cairo 实现 + `Bitmap`（自有 RGBA 缓冲，离屏与上屏同源） | 契约照抄 `yue/painter.mbt` 58 法 |
| `src/text` | `Text`/`Font`/`AttributedText` 语义层（先委托 Pango，后按需要自研栅格化） | 参考 `nativeui/gfx/` |
| `src/input` | 编辑器内核（文档 / 选区 / 编辑操作 / caret）+ `TextEditorHost` 后端抽象 | 新写 |
| `src/sys` | 系统能力 | 平移 `yue/system`（559 fn）、`yue/traybus`（175 fn）、`yue/icons`（803 个图标路径数据） |
| `src/ui` | 事件循环、脏区重绘、yoga-mbt 接线、命中测试、哑视图、自绘组件宿主 | 新写 |

**可直接平移的既有资产**（按对 libyue 的依赖形态分类）：纯 MoonBit 零依赖的 `yue/system`、`yue/traybus`、`yue/geometry.mbt`、`yue/signals.mbt`、图标路径数据、图表纯算法层；绑定绘制语义的 `yue/components`（约 190 fn）与 `yue/charts`（约 289 fn）在新栈里**调用点不变**，只换 `Painter` 实现；声明式层的 `Node{mount}` 闭包模式（`yue/node.mbt:12-24`）把挂载目标从 `View` 换成 yoga-mbt 节点即可复用。

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

## 4. 阶段划分与每批验收

门控沿用仓库纪律：`moon check` 零警告 + 全仓 `moon test` 全绿；真机视觉/交互验证按 AGENTS 规则 6 出清单由协作方执行；实测结论回写 `adaptation.md`；一批一提交一推送。

| 阶段 | 内容 | 验收 |
|---|---|---|
| **G0** | **Linux IME spike**（`experiment/ime_probe`，纯通道 `GtkIMContext` 与可见 `GtkEntry` 两模式同二进制切换） | 真机 fcitx5 与 ibus 各验：commit 送达、preedit 内联、候选窗定位、快捷键穿透、GtkEntry 尺寸协商是否冲突；结论回填 `adaptation.md` 并据此确认第 3 节表 |
| **G1** | 绘制契约 + 离屏回归：`Painter` 矩形级子集签名定稿、`Bitmap`、yoga-mbt 盒子→像素 | 断言比 RGBA 字节；`moon check` 零警告 |
| **G2** | GTK3 窗口地基：建窗、`g_main_context_iteration` 驱动循环（不用 `gtk_main`）、`g_main_context_wakeup` 留跨线程唤醒位、事件全排空 | 独立进程出图；`open→create→loop→close` 干净退出，无退出期崩溃 |
| **G3** | Cairo 绘制 + Pango 文本（路径/变换/裁剪/图标；单行与多行测量绘制） | 图标页与两张图表自绘出图；测量语义与 `GetOneLineHeight` 等对齐 |
| **G4** | 焦点栈与键盘、自绘 caret/选区、剪贴板；`TextEditorHost` 抽象落地 | 英文/数字在自绘输入框可打字；Tab/Shift+Tab 焦点跳转可用 |
| **G5** | 输入法接入（按第 3 节表逐平台） | Linux 真机中文输入（fcitx5 / ibus 两套）；Windows 逐 IME 验，不通者降 C |
| **G6** | 系统能力平移（`yue/system`、`yue/traybus`、图标数据）+ 图片解码补齐 | 既有 wbtest 随包平移全绿 |
| **G7** | 组件与声明式层移植：`components`/`charts` 挂上新 `Painter`，`declarative` 的 mount 目标改 yoga-mbt 节点 | showcase 组件页与图表页在新栈渲染，与旧链路视觉逐页对照 |

**布局侧遗留**：`/home/lkyh/ownCode/yue/patches/` 是真实 bug 语料，须转成 yoga-mbt 回归用例——首条 `93078300`（`display:none` 清零重显后 flex 简写派生的 basis-0 永久驻留，auto 高父容器下节点永久 0 高，即 MoonBit 层 tabs 切页塌陷根因）。

## 5. 风险与并存期

- **两份文本状态**（仅 Windows/macOS 的 C 兜底路径）：原生控件自持 text/selection，须每拍同步并拦编辑键；这是该形态的长期 bug 面（快速连打丢字、拖窗、剪贴板回环）。Linux 取 B 即无此项。
- **例外扩散**：任何平台一旦把可见原生控件当默认，第二个例外（下拉、日期、富文本）会跟上，最终得到「少数派永远不一致、而少数派恰是用户碰得最多的输入框」。C 只作为**有明确触发条件的兜底**，不进默认路径。
- **两栈并存**：`shim + libyue` 主链路继续按原规则维护，新栈并行成长；发布链（`bin-*` / `vendor-*` 标签）不受影响。
- **工时冲突**：新栈与 `TODO.md` 的 10 月月度目标（系统接口 / 音频 / 视频渲染收尾）及 Q4 承诺（macOS 真机验证 + 0.5.11 发布闭环）争同一批工时。
- **退出期拆除顺序**：新栈必须遵守「先停派发、再拆对象」——libyue 在 `experiment/exit_crash/patch_notes.md:105-118` 栽过的偶发段错误属通用问题，不随换后端消失。
- **无障碍**：屏幕阅读器读不到自绘文本（ATK / UIA / NSAccessibility），本计划不含，仅记档。
