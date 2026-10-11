# 路线图 — MoonBit 原生 GUI 栈

记号：`[x]` 完成 · `[~]` 部分（缺口写在子条目）· `[ ]` 未开始。

- **唯一主线**：自绘栈（新栈拥有窗口/像素/事件循环/布局，控件全部基于 Painter 自绘 + 自定义主题，不提供独立原生控件）。方案见 [docs/zh/native-gui-plan.md](docs/zh/native-gui-plan.md)。
- **本分支不保留老 libyue 绑定**：`shim/`、`lib/` 预构建库、`scripts/prepare.py` 已删除；libyue 只作**老师**（行为参考、可平移资产来源、`patches/` 的真实 bug 语料）。
- **旧链路的完成项与实测结论不在本文件重述**：代码在 `master`（`shim + libyue`，0.5.x 与 `bin-*`/`vendor-*` 发布照旧），踩坑与验收细节在 [docs/zh/adaptation.md](docs/zh/adaptation.md) 与 `git log`。**凡旧栈做过、新栈尚未重做的能力，本文件一律记为未完成。**
- **门禁口径（本分支例外）**：全仓 `moon check` 允许为红（红点=工作队列，只减不增，当前基线 **287 errors / 68 warnings**（2026-10-11 实测），明细见方案 §5）；逐批验收改分包：`yoga-mbt` 基线不掉 + 新栈各包 `moon check` 零警告且各自测试全绿；组件与声明式层接线完成的那一批恢复全仓门禁。
- **验证示例归口**：GUI 侧的同类测试集中累积进 **`examples/native-app`**（宿主/控件/主题/图表/Markdown 各一页，不为单个特性新开示例）；系统能力与子表面侧集中进 **`examples/native-sys`**（待建）；`examples/native-window` 冻结为 G2–G5 的历史冒烟基准，不再往里加新特性。

## 1. 地基（新栈自身进度）

- [x] **G0** 输入法探针（`experiment/ime_probe`）— 纯通道四条件真机闭环（fcitx5）
- [x] **G0b** 绑定层摘除与目录重排
- [x] **G1** 绘制契约 + 离屏像素回归（`yue/render`）
- [x] **G2** GTK3 窗口地基 + 循环归 MoonBit（`yue/win`、`yue/core/loop.mbt`）
- [x] **G3** Cairo 光栅 + Pango 文本（`yue/render/cairo.mbt`、`yue/text`）
- [x] **G4** 焦点栈 + 键鼠接入 + 编辑内核（`yue/core/focus.mbt`、`yue/input`）
- [x] **G5a** Linux 纯通道输入法接入（xdotool 注入验通中文提交）
- [~] **G5b** 输入通道补齐
  - ibus 一套复验（探针侧归因 libpinyin display-style，待确认）
  - Windows：`ImmAssociateContext` 优先、可见 `EDIT` 作可切换兜底（触发条件：只走 TSF 的 IME 在 legacy 通道打不出中文）
  - macOS：`NSTextInputClient`（前置：有 mac 真机）
  - 肉眼确认项：preedit 下划线观感、候选窗是否贴组合串末尾、caret 闪烁观感（点击定位已用 xdotool 客观验通：点控件最左端 caret 归 0、原位插字符）
  - [x] `TextEditorHost` 抽象收口：做成**焦点控件上的五个回调**（`on_key`/`on_commit`/`on_preedit`/`im_context`/`im_cursor`，input 已依赖 core 故不能反向持有 host），宿主按焦点投递；配套 `Window::im_reset()`——换焦点时先把排队的 commit 交还**旧**控件再 reset，实测修掉「A 框打的拼音 commit 进 B 框」
- [x] **G6** 布局层承接
  - [x] 脏区增量重排 + 测量/内在缓存跨布局驻留（YG3e）：39 个 setter 与结构/回调变更一律 `mark_changed`（全局时钟 + 节点 `rev`），入口 `scan_subtree_rev` 算子树版本（**不用父指针**——会与 children 成引用环、回收处理不了），`layout_into` 按「子树版本 + 入参指纹」跳过干净子树，两份缓存改按 `cache_rev` 作废并加 16 槽上限。同机 A/B（release µs/轮 @1121 节点）steady 3652→4、one_leaf 3656→78、全量路径 3664→3602 无回归，三场景校验值改前改后逐位相同；yoga-mbt 91/91（新增 10 条一律与「同状态从零全量布局」逐节点比对）。`App::paint_frame` 每帧 relayout 走的就是这条跳过路径，G7 接文本 measure 后 one_leaf 即实际形态
  - [x] App 宿主（`yue/core/app.mbt`）：窗口+`Loop`+控件树+输入法通道+脏标上屏收成一处；原始事件 `raw_to_event` 独立可测（code 0/1 键、2/3 按钮、4 移动、5 滚轮，按钮号走 `button`、滚轮纵向走 `axis`）；Tab/Shift+Tab 由宿主驱动焦点栈；按下时 `Widget::focusable_at` 把焦点交给命中的可聚焦控件（点已聚焦者不打断输入法）；`examples/native-app` 为 GUI 侧同类测试的**累积**验证页（注入回证：打字/Tab 环绕/按钮计数/点击定位/中文各归各框）
  - [x] 控件宿主（`yue/core/widget.mbt`）：布局树 ↔ 控件树映射、绝对矩形只在 `collect_abs` 一处折算、命中（最深+后画优先）、指针/滚轮/按键沿祖先链冒泡、绘制逐层 translate+clip；yoga-mbt 首次进主包依赖；真窗口用 xdotool 点击四格回证 `band_h=1/1/1/1`（core 22/22）
  - [x] `patches/` 的 yoga bug 语料转回归用例：首条 `93078300` 已落成 `modules/yoga-mbt/src/patches_regression_wbtest.mbt`（守的是可观察契约——auto 高列容器下的弹性项隐藏/重显一轮后高度仍来自内容测量；本引擎无 Yoga 那条 computedFlexBasis 驻留路径）
  - [x] 语料派生结案：Chrome 实测口径 = auto 主轴尺寸取各子项**假想主轴尺寸之和**（growth 不参与）；根因是引擎把子项基准读成了容器的 `flex_basis`（子项 flex-basis 全程失效），已修并落 7 行 Chrome 矩阵回归（`patches_regression_wbtest.mbt`）
- [~] **G7** 声明式层与组件宿主接线（`mount` 目标从 `View` 换 yoga-mbt 节点；恢复全仓门禁。宿主与声明式地基已就位：`@core.App` + `@core.Widget` 树 + `@core.Node`/`bind_node`/`swap_node`/`Store`/`Signal`，验证页 `examples/native-app`；剩组件与图表挂新 Painter）
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
  - [x] 次批：`set_font_for`/`set_color_for` **区间属性**（`yue/text` 走 C 端 `rt_*` 会话 + Pango attribute list，区间为 UTF-8 字节下标、后设覆盖先设、越界钳制）；`text` 20/20
  - [x] 第三批：字体枚举与回退 + 混排行高口径——C 侧一次性建进程内族表（`pango_font_map_list_families` 排序去重、`\n` 拼接，MoonBit 逐字节读）；`families`/`family_available`(大小写不敏感，通用族 serif/sans-serif/monospace 一律可用)/`resolve_family`(CSS 列表口径，全不可用退空族名)/`Font::resolve`；行高定案为**逐字体上抛、行盒 = max ascent + max descent**（`FontMetrics`/`font_metrics`/`line_height_multi`，`line_height_font`/`line_ascent_font` 改为其投影），`AttributedText::line_height()` 把基准与所有区间字体一起喂；`yue/text` 28/28（新增 8 条，含「行高盖得住 get_bounds_for 的绘制高度」）
  - [x] 绘制入口形态：新 `Painter` 门面**不提供** `draw_text`，文本一律走 `yue/text`（`draw_at`/`draw_box_at`/`AttributedText::draw`，画在门面当前会话的 `cairo_t` 上，平移与裁剪才生效）；全仓新栈代码 grep 无一处 `p.draw_text(` 调用，旧契约入口随旧链路包一并消失，无需逐点改写

### 控件（一律自绘，不再引入原生控件皮肤；家族名对应 master `yue/components/` 九个源文件）
- [~] 基础原语：`group`/`separator`/标签/图像/图标/按钮已落新包 **`yue/ui`**（首批 7 件，另附 `container`；文本 measure/baseline 首次回灌布局引擎，`on_pointer`/`on_draw` 首参为控件本身以免自捕获引用环；`type=` 因是保留字改 `kind : ButtonKind`；`yue/components` 属旧链路红点，按批替换）；表单族 15 件已全部落 `yue/ui/form.mbt` + `yue/ui/entry.mbt` + `yue/ui/textarea.mbt`；`tab` 已由 `yue/ui/nav.mbt` 的 `tabs_t` 承担（页签头行 + 预建页区显隐），`scroll` 已落 `yue/ui/scroll.mbt`（垂直滚动容器 + 自绘滚动条，平移用 yoga 新补的相对定位偏移），`splitter` 已落 `yue/ui/split.mbt`（`hsplit`/`vsplit`）、`combo` 已落 `yue/ui/form.mbt`
- [~] 文本族 `components_text.mbt`（3）：`TextRole`/`role_font`/`role_color`、`label_t`（角色化标签，可折行/定宽/固定色）、`measure_text_height`（按宽量高）已落 `yue/ui/text.mbt`，`splitter` 余项 `hsplit`/`vsplit` 落 `yue/ui/split.mbt`；剩 `code_view` + `tokenize_lang`/`tokenize_moonbit`（代码高亮，随 Markdown 批一起做）
- [x] 表单族 `components_form.mbt`（15/15）：`checkbox`/`radio_group`/`switch_t`/`slider_t`/`progress`/`stepper`(`input_number` 形态) 与 `button_t`（四变体配色 + 焦点环）/`link`（悬停下划线）/`form_item`（定宽标签 + 常驻错误行）/`form`/`rate_t`（矢量五角星 + 悬停预亮）/`select_t`（浮层图层上的候选列表，超 300 高套 `scroll_v`）/`color_picker_t`（字段 + 色板网格）已落 `yue/ui/form.mbt`（值走 `Store[T]`、订阅随回收袋退订、禁用态用 `Enabled` 单元、滑块拖动靠组件自持的 dragging；`on_change` 只在交互点触发，与 master 的「订阅里回调」差一条已记档；浮层句柄一律用 `overlay_alive` 判活性）；`textarea_t` 落 `yue/ui/textarea.mbt`（显示行布局 + 垂直滚动，见「输入框全语义」条）
- [x] 输入框全语义（单行 `yue/ui/entry.mbt` + 多行 `yue/ui/textarea.mbt`）：选区/双击选词/拖动插入点/Shift+箭头/undo-redo/Ctrl+A-C-V(内核内部剪贴板=记档降级)/placeholder/只读/密码遮罩/IME commit+preedit 内联全部落地，真窗口注入回证 `t3='组件框ab Q'`（点进框→打字→双击只选最后一个词→替换→Home+Shift+End+Delete+Ctrl+Z 撤销回来）。多行形态另落 `yue/ui/textarea.mbt`：`wrap_units`（空格/拉丁词/中日韩逐字分段）+ `layout_lines`（先按 `\n` 断逻辑行、再按盒宽贪心折行，超长单词不拆只溢出）两只纯函数钉住折行数学，`line_of_caret` 与「不超过 x 的最右码点边界」撑上下键跨显示行（记住起算 x）、Home/End 走行首行尾、回车插 `\n`、点击按 y 定行、拖选跨行、插入点自动滚进可视区，滚动复用 `scroll.mbt` 的 `ScrollState` 与滚动条控件（偏移在绘制期平移，不进布局）
- [x] 显示族 `components_display.mbt`（16）：全部落 `yue/ui/display.mbt`——`tag`/`tag_of_type`/`badge_count`/`badge_dot`/`avatar`/`statistic`/`progress_line`/`divider`/`alert`(含 closable 热区，master 的 `alert_closeable` 在此是同名参数而非独立函数)/`card`/`descriptions`/`empty`/`result`/`timeline`/`carousel_t`。两条口径记档：CSS `style` 通道未接（只给类型化参数，随主题批一起做）；轮播自转不走 libyue 的 `set_timeout` 而是本栈新落的**进程级延时通道** `@core.set_timeout`/`clear_timeout`（`App::new` 转派给自己的 `Loop`，无宿主时空操作，故无头测试能自己装通道手动派拍）
- [x] 日期族 `components_datetime.mbt`（5/5）：值模型（`DateYMD`/`TimeHM`/`DateRange`/`TimeRange`/`DateTimeRange` + 纯函数 `month_grid`/`month_shift`/`days_in_month`/`date_weekday` + `range_state_of`）与 `calendar_t` 落 `yue/ui/datetime.mbt`；`date_picker_t`/`date_range_picker_t`/`time_range_picker_t`/`datetime_range_picker_t` 落 `yue/ui/datepicker.mbt`（弹层开在浮层图层上，日历面板与网格数学复用 `build_calendar`/`range_state_of`）。三条记档：CSS `style` 通道未接；「今天」经 `wm_local_date` → `@core.local_ymd()` 走系统日历时间（单调钟 `now_ms` 不能推日期）；时间选择用步进器而非 `input_number`（自绘栈无原生输入框语义）
- [x] 导航族 `components_nav.mbt`（10/10）：`segmented`/`breadcrumb`/`pagination`/`steps`/`collapse`/`side_menu`/`side_menu_sections`/`tree`/`tabs_t`/`transfer` 全落 `yue/ui/nav.mbt`。共用口径记档：CSS `style` 通道未接（只给类型化参数）；底色与文字色由回调现取、悬停读宿主 `Widget.hovered`（不再有 master 的 `stateful_item` 自持 hover/focus）；选中态一律走 `Store[T]` 且画法现取；树/折叠面板/页签/分组菜单统一「子层预建 + `set_visible` 显隐」；圆角由组件层 `fill_round_rect` 拼路径（Painter 门面没有圆角，弧角须递增）；穿梭框的选中集合是组件自持的两张表、行级不持订阅
- [x] 表格 `components_table.mbt`（2/2）：`TableColumn`/`TableSort`/`TableCell`/`TableRow` 模型 + `table_t`（表头排序指示与状态机、斑马纹、悬停、行选择存源下标、四型单元格、`table_widths` 纯函数分列宽、表头边界拖动调列宽）落 `yue/ui/table.mbt`；`table_v_t`（万行级虚拟滚动，固定表头 + `virt_list`，与 `table_t` 共用 `table_header`/`table_row_widget`）落 `yue/ui/virtlist.mbt`。两条记档：排序状态归组件、排序口径归使用方（组件不替调用方排序）；列宽是活的（拖动只改样式不重建树；虚拟表靠 `rev` Store 整窗重挂）
- [x] 浮层族 `components_overlay.mbt` + `overlays.mbt`（6/6）：浮层基座 `yue/core/overlay.mbt`（整窗图层、空则不可见、点外收起在抬起、临开临建、`overlay_show_full` 铺满档）与六件 `yue/ui/overlay.mbt`（`tooltip_t`/`popover_t`/`dropdown_menu`/`dialog_t`/`toast_layer`/`context_menu_for`）。三条记档：tooltip 因自绘栈没有原生 tooltip 通道改为「悬停延时 + 自绘气泡」（走宿主新加的 `on_hover_change` 与父链悬停语义）；dialog 从 master 的「页面内绝对定位遮罩」改为开在浮层图层上；toast 从「调用方挂层 + 推送函数」改为「推送时开在图层上、最后一条撤下即收」，入口只剩推送函数；右键走「祖先优先」派发（上下文菜单是容器级能力）
- [x] 容器与滚动补充：垂直滚动条 `yue/ui/scroll.mbt`（滚轮 / 拖拇指 / 点轨道）+ 虚拟列表与粘性列表 `yue/ui/virtlist.mbt`（只挂可见区间 ±overscan、固定行高；粘性列表的「当前组」由每帧读各组矩形反推，吸顶条是视口里的绝对定位悬浮条）
- [ ] 托盘：SNI 后端 + DBusMenu 协议（按规则 5 上真实总线 + 真实面板复验）

### 主题、声明式与应用层
- [~] 主题系统
  - [x] 首批（`yue/theme`）：`Theme` 20 字段色板 + `default_theme`/`dark_theme` + `theme_from_accent` 主色派生公式 + `theme_current`/`on_theme_change`/`off_theme_change`/`theme_apply` + 20 getter + `control_height`/`entry_ctrl_height`；7/7
  - [ ] `theme_from_system`（跟随系统深浅与主色）随系统集成层
  - [ ] 组件 style 通道（`themed_container`/`set_panel_bg`/`bind_bg`/`bind_fg`/`bind_popover_bg`）与 `sub_bag` 批量退订随组件/relink 批次
  - 新栈刻意不做：原生控件 CSS 下发（全自绘后色板是唯一来源）
- [~] 声明式层（`declarative/` 612 行、24 构造器）：地基已落（`Node{mount:(Widget)->Widget}`、`node_of`/`node_of_new`/`mount_children`/`App::mount`、`invalidate` 回路）；**L1 构造器全集落 `yue/ui/declarative.mbt`**——`vbox`/`hbox`/`text_edit`/`picker`/`scroll`/`tab`/`date_picker`（改名者，旧调用点原样跑在新栈上）+ `mount_window`（建宿主并挂载）+ `bind`/`bind_label`（Store/信号驱动的文本绑定），与组件**同名**的（`label`/`button`/`entry`/`checkbox`/`container`/`group`/`separator`/`image`/`icon`/`radio_group`/`slider`/`progress`）直接用组件、不再包第二层；`hover_group` 已落（本栈宿主悬停态是父链语义，旧链路那套全局指针轮询不需要）；`overlay_scroll` 即 `scroll_v`（滚动条一直是视口的绝对定位子控件）。`cursor_group` 已落（配套新增窗口层光标通道：`wm_set_cursor` FFI + `Widget.cursor` 请求 + 宿主按悬停路径取「最深非零」下发）；`combo`（可编辑下拉：`entry` + 随输入过滤的候选浮层，↑↓/回车/Esc 走按键沿祖先链冒泡）已落 `yue/ui/form.mbt`。剩 `gif`（随图标/动画批）
- [x] Store 与 signals：内核与 `Store` 自 master 逐行平移进 `yue/core/signal.mbt`/`store.mbt`（`Signal`/`Store` 9 方法、`computed`/`batch`/`sub_bag`、store↔signal 互转，公共名不改，19 条既有测试整段带过来）；`bind_node`/`swap_node` 换成新栈形态并落 `yue/core/node.mbt`，relink 定案=**原位替换**（引擎为此加 `insert_child`/`remove_child_at`，控件层加 `index_of`/`move_child`），旧链路 Windows 的 `post_task` 推迟一拍与 `refresh_layout` 两条规避在本栈不需要（命中矩形每帧从布局结果重取），重绘经进程级 `set_repaint_hook`/`invalidate` 回到 App 宿主
- [~] 组件库约 55 个声明式组件（家族划分见「控件」节；调用点应不变，只换实现）：九族里表单/显示/日期/导航/表格/浮层/容器滚动/基础原语/输入框已全部以 `@core.Node` 构造器形态落 `yue/ui`，剩 `code_view`（随 Markdown 批）与图表/Markdown 两族
- [ ] 图表（`yue/charts/`）：共享算法层（`LineSeries`/`win_push`/`auto_y_range`/`nice_ticks`/`bar_hit`/`sector_angles`/`gauge_angle`/`linreg`…）+ 20 种图（5 通用 + 15 专项 + tooltip 支撑层）+ 交互层（`ci_zoom`/`ci_visual_map`/`ci_mark_line`/`ci_mark_area`/`ci_save`/`ci_legend_hit`/`ci_filter_visible`）+ 3 个交互变体 `charts_it`（line/bar/donut）
- [ ] Markdown（`markdown/markdown.mbt`）：`markdown_view` 17 种 block 变体 → 新 AttributedText；GFM 渲染面（表格/任务列表/脚注/删除线/图片/可点击链接）
- [ ] 富文本编辑（远期 WYSIWYG 块编辑器）
- [ ] 代码高亮、终端模拟器、WebGL 画布（旧栈即无，列为待评估）

### 系统集成（master 参考面：`yue/system` 31 源文件 + `yue/traybus` 16 源文件，属可平移资产）
- [~] A 类平移 · 环境/文件原语
  - [x] `vscjson` → 新包 `yue/sys/json.mbt`（零依赖 JSON，公共名不变、只换包前缀），并按「每包自建 wbtest」补 7 条覆盖
  - [ ] `envx`/`fsx`（目录枚举与环境变量写删要 C 层）与 `dialog`/`procrun`/`singleinstance` 随各自的 sys stub 批次进来
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
