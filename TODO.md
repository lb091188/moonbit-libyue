# 路线图 — MoonBit 原生 GUI 栈

记号：`[x]` 完成 · `[~]` 部分（缺口写在子条目）· `[ ]` 未开始。

- **唯一主线**：自绘栈（新栈拥有窗口/像素/事件循环/布局，控件全部基于 Painter 自绘 + 自定义主题，不提供独立原生控件）。方案见 [docs/zh/native-gui-plan.md](docs/zh/native-gui-plan.md)。
- **本分支不保留老 libyue 绑定**：`shim/`、`lib/` 预构建库、`scripts/prepare.py` 已删除；libyue 只作**老师**（行为参考、可平移资产来源、`patches/` 的真实 bug 语料）。
- **旧链路的完成项与实测结论不在本文件重述**：代码在 `master`（`shim + libyue`，0.5.x 与 `bin-*`/`vendor-*` 发布照旧），踩坑与验收细节在 [docs/zh/adaptation.md](docs/zh/adaptation.md) 与 `git log`。**凡旧栈做过、新栈尚未重做的能力，本文件一律记为未完成。**
- **门禁口径（本分支例外）**：全仓 `moon check` 允许为红（红点=工作队列，只减不增，当前基线 **290 errors / 68 warnings**，明细见方案 §5）；逐批验收改分包：`yoga-mbt` 基线不掉 + 新栈各包 `moon check` 零警告且各自测试全绿；组件与声明式层接线完成的那一批恢复全仓门禁。

## 1. 地基（新栈自身进度）

- [x] **G0** 输入法探针（`experiment/ime_probe`）— 纯通道四条件真机闭环（fcitx5）
- [x] **G0b** 绑定层摘除与目录重排
- [x] **G1** 绘制契约 + 离屏像素回归（`yue/render`）
- [x] **G2** GTK3 窗口地基 + 循环归 MoonBit（`yue/win`、`yue/core/loop.mbt`）
- [x] **G3** Cairo 光栅 + Pango 文本（`yue/render/cairo.mbt`、`yue/text`）
- [x] **G4** 焦点栈 + 键鼠接入 + 编辑内核（`yue/core/focus.mbt`、`yue/input`）
- [x] **G5a** Linux 纯通道输入法接入（xdotool 注入验通中文提交）
- [ ] **G5b** 输入通道补齐
  - ibus 一套复验（探针侧归因 libpinyin display-style，待确认）
  - Windows：`ImmAssociateContext` 优先、可见 `EDIT` 作可切换兜底（触发条件：只走 TSF 的 IME 在 legacy 通道打不出中文）
  - macOS：`NSTextInputClient`（前置：有 mac 真机）
  - 肉眼确认项：preedit 下划线观感、候选窗是否贴组合串末尾、点击定位与 caret 闪烁观感
  - `TextEditorHost` 抽象收口（四签名 `process_key`/`commit`/`preedit`/`set_cursor_rect`）
- [ ] **G6** 布局层承接
  - 脏区增量重排 + 测量/内在缓存跨布局驻留
  - [x] `patches/` 的 yoga bug 语料转回归用例：首条 `93078300` 已落成 `modules/yoga-mbt/src/patches_regression_wbtest.mbt`（守的是可观察契约——auto 高列容器下的弹性项隐藏/重显一轮后高度仍来自内容测量；本引擎无 Yoga 那条 computedFlexBasis 驻留路径）
  - [ ] 语料派生待查：显式 `flex-basis:0` + `min-height:0` 在 auto 高列容器下本引擎给 60、按 CSS 推导应为 0，需 Chrome 对照后再定修引擎还是记为取舍（涉及 §4.5 min:auto 与 auto 主轴尺寸推算的交互）
  - 布局树 ↔ 自绘控件树映射、命中测试坐标对齐
- [ ] **G7** 声明式层与组件宿主接线（`mount` 目标从 `View` 换 yoga-mbt 节点；恢复全仓门禁）
- [ ] **G8** 原生子表面通道与其消费者（见 §4「浏览器」「视频」）

## 2. 框架能力域 — 全部待在新栈重做

> 清单已按 master 线参考副本逐包核对（2026-10-11，`/home/lkyh/ownCode/moonbit-libyue` 的 master，比本仓 origin/master 新）；条目里的文件/函数名均指 master 现行资产。

### 绘图与资源
- [~] `Painter` 契约补齐（旧 `yue/painter.mbt` 共 58 法；对照 `docs/zh/components.md` 画布与图片章）
  - [x] 首批：门面化（Cairo 后端 + 无 Cairo 纯矩形降级，两路径逐像素一致）＋路径/曲线/弧/变换/裁剪/混合（25 模式映射 Cairo 算子，探针实测全部生效）/渐变（线性、径向）；`yue/render` 25/25
  - [x] 次批：`draw_image(_from_rect)`、`draw_canvas(_from_rect)`、离屏 `Canvas`（子表面限制采样域防串色、blit 尊重混合模式）
- [~] 图片：`Image`（`new_from_file`/`new_from_png`/`from_bitmap`/`resize`/`get_width|height`/`write_to_file`/`ImageSlot`）、GdkPixbuf 解码（PNG/JPEG/GIF **首帧**）、`Canvas` 离屏与 PNG 落盘已落地；缺口：**GIF 动画**（旧 `Image` 是 `GdkPixbufAnimation`）与 Windows/mac 解码后端
- [~] 图标（master `yue/icons/icons.mbt` 4297 行）
  - [x] 绘制面平移（`yue/icons`，自 master 前 4197 行逐行搬入、数据块零差异）：803 条定点路径串 + `fill_icon_path` 解释器 + `IconKind`/`icon_name`/`all_icons` + `draw_icon`（含全量出图扫描 4/4）
  - [ ] `icon`/`icon_button_t` 两个声明式包装 + 主题取色跟随（随声明式层 G7）
- [~] 字体与富文本子系统
  - [x] 首批：`Font`（族名/字号/9 档字重/斜体）+ `TextAlign`/`TextFormat`/`TextAttributes`/`SizeF` + `AttributedText` **整体属性**面（对齐/换行/省略/`get_bounds_for`）；顺带修正 `wrap=false` 未生效的语义（Pango 一设宽就折行）与 `draw_in_box` 盒内对齐；`yue/text` 14/14
  - [ ] 次批：`set_font_for`/`set_color_for` **区间属性**（Pango attribute list）、字体枚举与回退（`pango_font_map` 列族）、行高在多字体下的口径
  - [ ] 绘制入口形态：旧契约的 `Painter::draw_text` 在组件接线（G7）时逐点改 `@text.draw_in_box(p.bitmap, …)`

### 控件（一律自绘，不再引入原生控件皮肤；家族名对应 master `yue/components/` 九个源文件）
- [ ] 基础原语：`group`/`scroll`/`separator`/`splitter`/`tab`（yue 根）＋ 按钮 / 复选 / 单选 / 开关 / 滑块 / 进度 / 步进 / 标签 / 分隔线 / 图像 / 图标
- [ ] 文本族 `components_text.mbt`：`label_t`、`code_view`＋`tokenize_lang`/`tokenize_moonbit`、`measure_text_height`
- [ ] 表单族 `components_form.mbt`（15）：`button_t`/`entry_t`/`checkbox_t`/`radio_group`/`switch_t`/`input_t`/`input_number`/`form_item`/`form`/`link`/`textarea_t`/`slider_t`/`select_t`/`rate_t`/`color_picker_t`
- [ ] 输入框全语义（跨文本/表单两族）：选区、双击选词、拖放插入点、Shift+箭头、undo/redo、placeholder、粘贴降级、只读、密码遮罩、IME 与 preedit 内联
- [ ] 显示族 `components_display.mbt`（16）：`tag`/`tag_of_type`/`badge_count`/`badge_dot`/`avatar`/`timeline`/`descriptions`/`result`/`empty`/`statistic`/`progress_line`/`divider`/`card`/`alert`/`alert_closeable`/`carousel_t`
- [ ] 日期族 `components_datetime.mbt`（5）：`calendar_t`/`date_picker_t`/`date_range_picker_t`/`time_range_picker_t`/`datetime_range_picker_t`
- [ ] 导航族 `components_nav.mbt`（10）：`side_menu(_sections)`/`segmented`/`breadcrumb`/`pagination`/`steps`/`collapse`/`tree`/`transfer`/`tabs_t`
- [ ] 表格 `components_table.mbt`：`table_t`/`table_v_t` + `TableColumn`/`TableRow` 模型 —— 虚拟滚动、列宽拖动、排序、搜索、行选择
- [ ] 浮层族 `components_overlay.mbt` + `overlays.mbt`：`tooltip_t`/`popover_t`/`dropdown_menu`/`dialog_t`/`toast_layer`/`context_menu_for`（轮播切换动画旧栈即缺，列同批补）
- [ ] 容器与滚动补充：虚拟列表、粘性列表、垂直滚动条（滚轮 + 拖动）
- [ ] 托盘：SNI 后端 + DBusMenu 协议（按规则 5 上真实总线 + 真实面板复验）

### 主题、声明式与应用层
- [ ] 主题系统：`theme_from_accent`（主色公式派生）/`theme_from_system`/`theme_current`/`on_theme_change`/`theme_apply` + 浅深自动跟随；组件 style 通道（`set_panel_bg`/`bind_bg`/`bind_fg`/`bind_popover_bg`/`entry_ctrl_height`）；皮肤全走新 Painter（旧「原生控件不跟暗色」这条边界随自绘自然消失）
- [ ] 声明式层（`declarative/` 612 行、24 构造器）：L1 构造器全集（`vbox`/`hbox`/`label`/`button`/`checkbox`/`entry`/`text_edit`/`radio`/`slider`/`progress`/`picker`/`combo`/`group`/`scroll`/`separator`/`tab`/`date_picker`/`gif`/`container`…）+ `node_of`/`mount`/`mount_window` + `bind`/`bind_label`；`hover_group`/`cursor_group`；`overlay_scroll`
- [ ] Store 与 signals：`Store` 9 方法、`computed`/`batch`/`sub_bag`、store↔signal 双向绑定、`bind_node`/`swap_node`、relink 语义
- [ ] 组件库约 55 个声明式组件（家族划分见「控件」节；调用点应不变，只换实现）
- [ ] 图表（`yue/charts/`）：共享算法层（`LineSeries`/`win_push`/`auto_y_range`/`nice_ticks`/`bar_hit`/`sector_angles`/`gauge_angle`/`linreg`…）+ 20 种图（5 通用 + 15 专项 + tooltip 支撑层）+ 交互层（`ci_zoom`/`ci_visual_map`/`ci_mark_line`/`ci_mark_area`/`ci_save`/`ci_legend_hit`/`ci_filter_visible`）+ 3 个交互变体 `charts_it`（line/bar/donut）
- [ ] Markdown（`markdown/markdown.mbt`）：`markdown_view` 17 种 block 变体 → 新 AttributedText；GFM 渲染面（表格/任务列表/脚注/删除线/图片/可点击链接）
- [ ] 富文本编辑（远期 WYSIWYG 块编辑器）
- [ ] 代码高亮、终端模拟器、WebGL 画布（旧栈即无，列为待评估）

### 系统集成（master 参考面：`yue/system` 31 源文件 + `yue/traybus` 16 源文件，属可平移资产）
- [ ] A 类平移 · 环境/文件原语：`envx`/`fsx`/`dialog`（文件对话框与文本读写）/`procrun`/`singleinstance`/`vscjson`
- [ ] A 类平移 · 硬件族：`brightness`（含键盘背光）/`volume`（含 volx 音量增强）/`nightlight`/`sensor`/`bluetooth`/`printer`/`disk`/`powerprofile`
- [ ] A 类平移 · 桌面集成族：`wallpaper`/`defaultapps`/`appfind`/`open_url`+`reveal`（文件管理器定位）/`recent_files`
- [ ] A 类平移 · 历史族：`browser_history`（含下载）/`browser_bookmarks`/`firefox_history`/`vscode_history`
- [ ] A 类平移 · 会话与状态：`power`/`session`/`powerctl`/`online`/`idle`/`keepawake`/`clipboard_watch`/`monitor`/`locale_sys`/`sysinfo`/`windowctl`
- [ ] DBus 系在新事件循环下**重写/重验**：SNI 托盘（`traybus/sni.mbt`）、通知（新栈须重写 `org.freedesktop.Notifications`，含 `Notification::set_progress` 进度文本）、logind（`SetBrightness`/inhibit）、UPower、NetworkManager（`netmon`/`online`）、屏保 `screensaver`、媒体键 MPRIS（`media` 含状态监视轮询）
- [ ] DBus 通用基建：`bus`/`gdbus`/`wire`（41 内部 fn 编解码）/信号注册表/断线重连/注销与注册对称清理（CORE2 教训）
- [ ] 新建项（master 全仓无资产，属新做）：任务栏进度、dock 徽标、勿扰
- [ ] Wayland 后端：`idle`（X11 屏保扩展）/`windowctl`（wmctrl）/`clipboard_watch`（xclip）/`monitor`（xrandr）逐项定替代或降级
- [ ] 平台分派随各能力同批（master 有 Win32 直连族与 mac ObjC++ 族可参照）；真机清单见 `docs/zh/plan-system-integration.md` B8

### 浏览器与视频（原生子表面）
- [ ] `mount_child_surface(handle, rect)` 的 C 端实现（形状已在方案 §4 冻结）
- [ ] 浏览器自研薄绑定：Linux WebKitGTK（自定义 scheme 注册 + `GInputStream` 流式回灌 + 拒绝路径），Windows WebView2（两级异步 COM 创建、失败回退、就绪前排队、跨 HWND 焦点与滚轮转发），macOS WKWebView（自定义协议依赖私有 API，列为 mac 线风险）；协议载荷改**结构化返回**（CORE1 越界读教训）
- [ ] 视频：`modules/ffmpeg-mbt` 与解码链路可沿用（不依赖 libyue），但 VideoPlayer 的 UI（悬浮控制条、全屏、进度与音量交互）需按新自绘组件重写，画面走子表面通道
- [ ] 音频：`AudioPlayer` 在新栈下的设备与时钟复验；精确音画同步（音频光标回读）

### 交付面
- [ ] 示例迁移：`hello` / `hello-themed` / `showcase`（全功能演示板，15 页）/ `sysmonitor`（6 页）/ `systemprobe`（8 页，`modules/yue-examples`）/ `yue-examples`
- [ ] 文档：中英使用文档按新栈重写（`components`/`components-ui`/`declarative`/`layout`/`relink`/`system-capabilities`/`tutorial`），README 挂新截图
- [ ] 发布：mooncakes 新版本；旧 `bin-*`/`vendor-*` 预构建发布链退役
- [ ] CI：三平台构建与测试脚本随新栈调整（当前分支构建预期为红）
- [ ] 真机验证矩阵：Ubuntu GNOME / KDE / XFCE；Windows 10 / 11；macOS（前置：取得设备）
- [ ] 本仓 `docs/zh/{adaptation,system-capabilities,components-ui}.md` 落后于 master 参考副本（742/1066、797/833、1425/1458 行），按新栈重写前先以参考副本为准查证

## 3. 里程碑

- **M1** 新栈跑通一个完整 `showcase`（组件 + 图表 + 系统集成页），与旧链路逐页视觉对照 → 同时恢复全仓门禁
- **M2** Windows 地基与输入通道
- **M3** macOS 地基（取得设备后）
- **M4** 发布新版本并冻结旧 `shim + libyue` 链路

## 4. 已知边界与风险

- 自绘文本的**无障碍**（ATK / UIA / NSAccessibility）本栈暂不含，只记不办。
- 例外扩散警戒：可见原生控件覆盖只作**按平台开关的兜底**，默认关；子表面（浏览器/视频）属能力型例外，需逐条登记评审。
- 过渡期红点：`examples/*`、`modules/yue-examples`、`modules/yue-media` 成片编译失败属工作队列，不影响 `master` 发布链；分支寿命越长与 master 漂移越大，故每批完成即提交推送。
- 回归基线：旧栈约 660 条测试随绑定文件消失，属净覆盖损失；补法是新栈每包自建 wbtest 并随资产平移测试。
- mac 线整体风险后置：无真机（旧栈遗留项 reply 通知回调、mac canvas 滚轮、Accelerator/Tray 原生后端等一并留在 master 侧记录）。

## 5. 随手可查

- 方案与阶段：[docs/zh/native-gui-plan.md](docs/zh/native-gui-plan.md)
- 平台实测坑：[docs/zh/adaptation.md](docs/zh/adaptation.md)（中英两份）
- 布局引擎交接与决策：[modules/yoga-mbt/HANDOFF.md](modules/yoga-mbt/HANDOFF.md)
- libyue 源码（只读老师）：`/home/lkyh/ownCode/yue`，含 `patches/` bug 语料
- master 线参考副本（代码权威）：`/home/lkyh/ownCode/moonbit-libyue`（比本仓 origin/master 新，Windows/mac 批次在此；本仓文档落后量见「交付面」）
- FFI 规范与坑：`.agents/skills/moonbit-c-binding/`（同步自 [moonbitlang/skills](https://github.com/moonbitlang/skills)，`~/.agents/skills/` 同版）
