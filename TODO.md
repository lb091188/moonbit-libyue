# 路线图 — MoonBit 原生 GUI 栈

记号：`[x]` 完成 · `[~]` 部分（缺口写在子条目）· `[ ]` 未开始。

- **唯一主线**：自绘栈（新栈拥有窗口/像素/事件循环/布局，控件全部基于 Painter 自绘 + 自定义主题，不提供独立原生控件）。方案见 [docs/zh/native-gui-plan.md](docs/zh/native-gui-plan.md)。
- **本分支不保留老 libyue 绑定**：`shim/`、`lib/` 预构建库、`scripts/prepare.py` 已删除；libyue 只作**老师**（行为参考、可平移资产来源、`patches/` 的真实 bug 语料）。
- **旧链路的完成项与实测结论不在本文件重述**：代码在 `master`（`shim + libyue`，0.5.x 与 `bin-*`/`vendor-*` 发布照旧），踩坑与验收细节在 [docs/zh/adaptation.md](docs/zh/adaptation.md) 与 `git log`。**凡旧栈做过、新栈尚未重做的能力，本文件一律记为未完成。**
- **门禁口径（本分支例外）**：全仓 `moon check` 允许为红（红点=工作队列，只减不增，当前基线 **287 errors / 68 warnings**（2026-10-11 实测），明细见方案 §5）；逐批验收改分包：`yoga-mbt` 基线不掉 + 新栈各包 `moon check` 零警告且各自测试全绿；组件与声明式层接线完成的那一批恢复全仓门禁。
- **验证示例归口**：GUI 侧的同类测试集中累积进 **`examples/native-app`**（宿主/控件/主题/图表/Markdown 各一页，不为单个特性新开示例）；系统能力侧集中进 **`examples/native-sys`**（已建）；webview 与媒体侧集中进 **`examples/native-web`**（批 B 起建，整页/分栏/桥接/播放器各一页）；`examples/native-window` 冻结为 G2–G5 的历史冒烟基准，不再往里加新特性。

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
  - [x] **平台无关输入映射层落 `yue/core/input_map.mbt`**（另线 #19 首批，纯函数 + 7 条回归）：三平台修饰位折算（`gtk_mods_to_mods`/`win_mods_to_mods`/`mac_mods_to_mods`）、两套键码表（`win_vk_to_keysym`/`mac_vk_to_keysym`，字母数字给未加 shift 的基码、`win_apply_shift` 补 shift/caps、OEM 符号键不硬编布局表而走 WM_CHAR/Unicode）、按钮号（`win_button_to_index`/`mac_button_to_index`）、按键路由 `ime_route`（组合中 → 光标键(带 Ctrl 也算、带 Alt 不算) → Tab → 快捷键 → 可打印 → 其余）与 `ime_should_reset`/`ime_should_feed_surrounding`；Win/mac 后端在 MoonBit 侧直接调这张表，Linux 的 `wm_mods` 与 `gtk_mods_to_mods` 逐位一致（两边注释互点名）
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
- [~] 图片：`Image`（`new_from_file`/`new_from_png`/`from_bitmap`/`resize`/`get_width|height`/`write_to_file`/`ImageSlot`）、GdkPixbuf 解码（PNG/JPEG/GIF 首帧）、`Canvas` 离屏与 PNG 落盘已落地；**GIF 动画已补**——`Animation`（`new_from_file`/`advance`/`delay_ms`/`frame`/`current`/`close`，迭代器 + 与真实时间同速的虚拟时钟）+ 组件 `gif`（`yue/ui/gif.mbt`，自转/暂停/继续、静图退回一帧、槽位随回收袋释放），顺带修掉 `cr_blit` 的缩放路径（图案矩阵语义反了，等尺寸时恰好看不出）；缺口只剩 Windows/mac 解码后端
- [~] 图标（master `yue/icons/icons.mbt` 4297 行）
  - [x] 绘制面平移（`yue/icons`，自 master 前 4197 行逐行搬入、数据块零差异）：803 条定点路径串 + `fill_icon_path` 解释器 + `IconKind`/`icon_name`/`all_icons` + `draw_icon`（含全量出图扫描 4/4）
  - [x] `icon`/`icon_button_t` 两个声明式包装 + 主题取色跟随：`icon(kind, size, color?)` 颜色空即现取主题正文色并随主题变更重绘（`watch_theme`），`icon_button_t` 是只有图标的按钮（悬停浅底、按下更深、禁用不吃事件、手型光标）；两者都返回 `@core.Node`，与声明式层同形
- [~] 字体与富文本子系统
  - [x] 首批：`Font`（族名/字号/9 档字重/斜体）+ `TextAlign`/`TextFormat`/`TextAttributes`/`SizeF` + `AttributedText` **整体属性**面（对齐/换行/省略/`get_bounds_for`）；顺带修正 `wrap=false` 未生效的语义（Pango 一设宽就折行）与 `draw_in_box` 盒内对齐；`yue/text` 14/14
  - [x] 次批：`set_font_for`/`set_color_for` **区间属性**（`yue/text` 走 C 端 `rt_*` 会话 + Pango attribute list，区间为 UTF-8 字节下标、后设覆盖先设、越界钳制）；`text` 20/20
  - [x] 第三批：字体枚举与回退 + 混排行高口径——C 侧一次性建进程内族表（`pango_font_map_list_families` 排序去重、`\n` 拼接，MoonBit 逐字节读）；`families`/`family_available`(大小写不敏感，通用族 serif/sans-serif/monospace 一律可用)/`resolve_family`(CSS 列表口径，全不可用退空族名)/`Font::resolve`；行高定案为**逐字体上抛、行盒 = max ascent + max descent**（`FontMetrics`/`font_metrics`/`line_height_multi`，`line_height_font`/`line_ascent_font` 改为其投影），`AttributedText::line_height()` 把基准与所有区间字体一起喂；`yue/text` 28/28（新增 8 条，含「行高盖得住 get_bounds_for 的绘制高度」）
  - [x] 绘制入口形态：新 `Painter` 门面**不提供** `draw_text`，文本一律走 `yue/text`（`draw_at`/`draw_box_at`/`AttributedText::draw`，画在门面当前会话的 `cairo_t` 上，平移与裁剪才生效）；全仓新栈代码 grep 无一处 `p.draw_text(` 调用，旧契约入口随旧链路包一并消失，无需逐点改写

### 控件（一律自绘，不再引入原生控件皮肤；家族名对应 master `yue/components/` 九个源文件）
- [~] 基础原语：`group`/`separator`/标签/图像/图标/按钮已落新包 **`yue/ui`**（首批 7 件，另附 `container`；文本 measure/baseline 首次回灌布局引擎，`on_pointer`/`on_draw` 首参为控件本身以免自捕获引用环；`type=` 因是保留字改 `kind : ButtonKind`；`yue/components` 属旧链路红点，按批替换）；表单族 15 件已全部落 `yue/ui/form.mbt` + `yue/ui/entry.mbt` + `yue/ui/textarea.mbt`；`tab` 已由 `yue/ui/nav.mbt` 的 `tabs_t` 承担（页签头行 + 预建页区显隐），`scroll` 已落 `yue/ui/scroll.mbt`（垂直滚动容器 + 自绘滚动条，平移用 yoga 新补的相对定位偏移），`splitter` 已落 `yue/ui/split.mbt`（`hsplit`/`vsplit`）、`combo` 已落 `yue/ui/form.mbt`
- [x] 文本族 `components_text.mbt`（3/3）：`TextRole`/`role_font`/`role_color`、`label_t`、`measure_text_height` 已落 `yue/ui/text.mbt`；`code_view` + `tokenize_lang`/`tokenize_moonbit`（8 语言关键字表 + 词分类着色 + 深底代码块组件）落 `yue/ui/codeview.mbt`——构造期逐 token 测宽预排版、on_draw 现画（One Dark 恒深底不随主题）
- [x] 表单族 `components_form.mbt`（15/15）：`checkbox`/`radio_group`/`switch_t`/`slider_t`/`progress`/`stepper`(`input_number` 形态) 与 `button_t`（四变体配色 + 焦点环）/`link`（悬停下划线）/`form_item`（定宽标签 + 常驻错误行）/`form`/`rate_t`（矢量五角星 + 悬停预亮）/`select_t`（浮层图层上的候选列表，超 300 高套 `scroll_v`）/`color_picker_t`（字段 + 色板网格）已落 `yue/ui/form.mbt`（值走 `Store[T]`、订阅随回收袋退订、禁用态用 `Enabled` 单元、滑块拖动靠组件自持的 dragging；`on_change` 只在交互点触发，与 master 的「订阅里回调」差一条已记档；浮层句柄一律用 `overlay_alive` 判活性）；`textarea_t` 落 `yue/ui/textarea.mbt`（显示行布局 + 垂直滚动，见「输入框全语义」条）
- [x] 输入框全语义（单行 `yue/ui/entry.mbt` + 多行 `yue/ui/textarea.mbt`）：选区/双击选词/拖动插入点/Shift+箭头/undo-redo/Ctrl+A-C-V(内核内部剪贴板=记档降级)/placeholder/只读/密码遮罩/IME commit+preedit 内联全部落地，真窗口注入回证 `t3='组件框ab Q'`（点进框→打字→双击只选最后一个词→替换→Home+Shift+End+Delete+Ctrl+Z 撤销回来）。多行形态另落 `yue/ui/textarea.mbt`：`wrap_units`（空格/拉丁词/中日韩逐字分段）+ `layout_lines`（先按 `\n` 断逻辑行、再按盒宽贪心折行，超长单词不拆只溢出）两只纯函数钉住折行数学，`line_of_caret` 与「不超过 x 的最右码点边界」撑上下键跨显示行（记住起算 x）、Home/End 走行首行尾、回车插 `\n`、点击按 y 定行、拖选跨行、插入点自动滚进可视区，滚动复用 `scroll.mbt` 的 `ScrollState` 与滚动条控件（偏移在绘制期平移，不进布局）
- [x] 显示族 `components_display.mbt`（16）：全部落 `yue/ui/display.mbt`——`tag`/`tag_of_type`/`badge_count`/`badge_dot`/`avatar`/`statistic`/`progress_line`/`divider`/`alert`(含 closable 热区，master 的 `alert_closeable` 在此是同名参数而非独立函数)/`card`/`descriptions`/`empty`/`result`/`timeline`/`carousel_t`。两条口径记档：CSS `style` 通道未接（只给类型化参数，随主题批一起做）；轮播自转不走 libyue 的 `set_timeout` 而是本栈新落的**进程级延时通道** `@core.set_timeout`/`clear_timeout`（`App::new` 转派给自己的 `Loop`，无宿主时空操作，故无头测试能自己装通道手动派拍）
- [x] 日期族 `components_datetime.mbt`（5/5）：值模型（`DateYMD`/`TimeHM`/`DateRange`/`TimeRange`/`DateTimeRange` + 纯函数 `month_grid`/`month_shift`/`days_in_month`/`date_weekday` + `range_state_of`）与 `calendar_t` 落 `yue/ui/datetime.mbt`；`date_picker_t`/`date_range_picker_t`/`time_range_picker_t`/`datetime_range_picker_t` 落 `yue/ui/datepicker.mbt`（弹层开在浮层图层上，日历面板与网格数学复用 `build_calendar`/`range_state_of`）。三条记档：CSS `style` 通道未接；「今天」经 `wm_local_date` → `@core.local_ymd()` 走系统日历时间（单调钟 `now_ms` 不能推日期）；时间选择用步进器而非 `input_number`（自绘栈无原生输入框语义）
- [x] 导航族 `components_nav.mbt`（10/10）：`segmented`/`breadcrumb`/`pagination`/`steps`/`collapse`/`side_menu`/`side_menu_sections`/`tree`/`tabs_t`/`transfer` 全落 `yue/ui/nav.mbt`。共用口径记档：CSS `style` 通道未接（只给类型化参数）；底色与文字色由回调现取、悬停读宿主 `Widget.hovered`（不再有 master 的 `stateful_item` 自持 hover/focus）；选中态一律走 `Store[T]` 且画法现取；树/折叠面板/页签/分组菜单统一「子层预建 + `set_visible` 显隐」；圆角由组件层 `fill_round_rect` 拼路径（Painter 门面没有圆角，弧角须递增）；穿梭框的选中集合是组件自持的两张表、行级不持订阅
- [x] 表格 `components_table.mbt`（2/2）：`TableColumn`/`TableSort`/`TableCell`/`TableRow` 模型 + `table_t`（表头排序指示与状态机、斑马纹、悬停、行选择存源下标、四型单元格、`table_widths` 纯函数分列宽、表头边界拖动调列宽）落 `yue/ui/table.mbt`；`table_v_t`（万行级虚拟滚动，固定表头 + `virt_list`，与 `table_t` 共用 `table_header`/`table_row_widget`）落 `yue/ui/virtlist.mbt`。两条记档：排序状态归组件、排序口径归使用方（组件不替调用方排序）；列宽是活的（拖动只改样式不重建树；虚拟表靠 `rev` Store 整窗重挂）
- [x] 浮层族 `components_overlay.mbt` + `overlays.mbt`（6/6）：浮层基座 `yue/core/overlay.mbt`（整窗图层、空则不可见、点外收起在抬起、临开临建、`overlay_show_full` 铺满档）与六件 `yue/ui/overlay.mbt`（`tooltip_t`/`popover_t`/`dropdown_menu`/`dialog_t`/`toast_layer`/`context_menu_for`）。三条记档：tooltip 因自绘栈没有原生 tooltip 通道改为「悬停延时 + 自绘气泡」（走宿主新加的 `on_hover_change` 与父链悬停语义）；dialog 从 master 的「页面内绝对定位遮罩」改为开在浮层图层上；toast 从「调用方挂层 + 推送函数」改为「推送时开在图层上、最后一条撤下即收」，入口只剩推送函数；右键走「祖先优先」派发（上下文菜单是容器级能力）
- [x] 容器与滚动补充：垂直滚动条 `yue/ui/scroll.mbt`（滚轮 / 拖拇指 / 点轨道）+ 虚拟列表与粘性列表 `yue/ui/virtlist.mbt`（只挂可见区间 ±overscan、固定行高；粘性列表的「当前组」由每帧读各组矩形反推，吸顶条是视口里的绝对定位悬浮条）
- [x] 托盘：SNI 后端 + DBusMenu 协议（真实总线已验，真实面板观感由用户复验；见 `yue/dbus`）

### 主题、声明式与应用层
- [~] 主题系统
  - [x] 首批（`yue/theme`）：`Theme` 20 字段色板 + `default_theme`/`dark_theme` + `theme_from_accent` 主色派生公式 + `theme_current`/`on_theme_change`/`off_theme_change`/`theme_apply` + 20 getter + `control_height`/`entry_ctrl_height`；7/7
  - [x] `theme_from_system`（跟随系统深浅与主色）：主题包收两个读数函数作参数（不依赖平台层），探针在 `yue/win`（gsettings：`color-scheme`→`gtk-theme` 两级、`button-settings`/`accent-color` 主色查表，先 `has_key` 再读），轮询与重刷在 `yue/core` 的 `App::follow_system_theme(interval_ms)`（比对 `primary/bg_page` 指纹，变了才 `theme_apply`；返回停表函数）
  - [x] 组件 style 通道**定案为不做 CSS 式样式表**：master 那五个助手（`themed_container`/`set_panel_bg`/`bind_bg`/`bind_fg`/`bind_popover_bg`）的前提是「原生控件的底色/字色是命令式设进去的固定值」，本栈 `on_draw` 现取色板 + 进程级 `watch_theme` 订阅，五个助手结构性不需要；调用方覆盖走类型化参数或 `handle=fn(w){…}`（本栈的样式逃生舱，比字符串表更类型安全）。`sub_bag` 批量退订已在 `yue/core/signal.mbt` 并被组件批次反复覆盖
  - 新栈刻意不做：原生控件 CSS 下发（全自绘后色板是唯一来源）
- [~] 声明式层（`declarative/` 612 行、24 构造器）：地基已落（`Node{mount:(Widget)->Widget}`、`node_of`/`node_of_new`/`mount_children`/`App::mount`、`invalidate` 回路）；**L1 构造器全集落 `yue/ui/declarative.mbt`**——`vbox`/`hbox`/`text_edit`/`picker`/`scroll`/`tab`/`date_picker`（改名者，旧调用点原样跑在新栈上）+ `mount_window`（建宿主并挂载）+ `bind`/`bind_label`（Store/信号驱动的文本绑定），与组件**同名**的（`label`/`button`/`entry`/`checkbox`/`container`/`group`/`separator`/`image`/`icon`/`radio_group`/`slider`/`progress`）直接用组件、不再包第二层；`hover_group` 已落（本栈宿主悬停态是父链语义，旧链路那套全局指针轮询不需要）；`overlay_scroll` 即 `scroll_v`（滚动条一直是视口的绝对定位子控件）。`cursor_group` 已落（配套新增窗口层光标通道：`wm_set_cursor` FFI + `Widget.cursor` 请求 + 宿主按悬停路径取「最深非零」下发）；`combo`（可编辑下拉：`entry` + 随输入过滤的候选浮层，↑↓/回车/Esc 走按键沿祖先链冒泡）已落 `yue/ui/form.mbt`；`gif`（动图组件，走 `@render.Animation` 的逐帧迭代 + 进程级延时通道）已落 `yue/ui/gif.mbt`。**L1 构造器全集到此收口**（旧 24 个里除 `mount`（即 `App::mount`）与同名组件外都已到位）。
- [x] Store 与 signals：内核与 `Store` 自 master 逐行平移进 `yue/core/signal.mbt`/`store.mbt`（`Signal`/`Store` 9 方法、`computed`/`batch`/`sub_bag`、store↔signal 互转，公共名不改，19 条既有测试整段带过来）；`bind_node`/`swap_node` 换成新栈形态并落 `yue/core/node.mbt`，relink 定案=**原位替换**（引擎为此加 `insert_child`/`remove_child_at`，控件层加 `index_of`/`move_child`），旧链路 Windows 的 `post_task` 推迟一拍与 `refresh_layout` 两条规避在本栈不需要（命中矩形每帧从布局结果重取），重绘经进程级 `set_repaint_hook`/`invalidate` 回到 App 宿主
- [x] 组件库约 55 个声明式组件（家族划分见「控件」节）：十族 + Markdown 族全部以 `@core.Node` 构造器形态落 `yue/ui` / `yue/mdview`（文本族含 code_view）——**组件库收口**
- [~] 图表（新栈落 **`yue/chart/`**，旧 `yue/charts/` 属红点按批替换）：
  - [x] 共享算法层（`LineSeries`/`win_push`/`series_push`/`auto_y_range`/`map_y`/`map_xv`/`map_idx`/`nice_step`/`nice_ticks`/`fmt_axis`/`bar_range`/`bar_slot`/`bar_hit`/`sector_angles`/`gauge_angle`/`linreg`/`point_range`/`truncate_to`/`with_alpha`）与 master 同源平移，11 条白盒直接钉住
  - [x] 五种通用图（`line_chart_t` 折线/面积（像素列抽稀 + 末端值标注）、`bar_chart_t` 柱/条（正负基线 + 悬停高亮）、`donut_chart_t` 环形（中心汇总 + 图例百分比 + `donut_hit`）、`gauge_t` 仪表（阈值分段 + 定时器插值平滑）、`scatter_t` 散点（最小二乘趋势线）），真窗口回证五图齐备
  - [x] tooltip 支撑层 + 交互层（`ci_zoom` 窗口数学/`ci_visual_map` 色带/`ci_mark_line`/`ci_mark_area`/`ci_save` PNG 离屏导出（Linux 真落盘）/`ci_legend_hit`/`ci_filter_visible`）+ 3 个交互变体 `charts_it`（`line_chart_it`/`bar_chart_it`/`donut_chart_it`：hover 浮层 + 可点击图例显隐 + 滚轮缩放/拖拽平移；图例色改 `(名字, 索引)` + `color_at` 现取，主题切换免重建；`draw_donut` 拆 `draw_donut_core` 供交互版复用）；chart 37/37、真窗口像素采样回证（图例隐藏项变灰 + 扇区重分配 + tooltip 落位），滚轮注入因 XTest 对 GTK3(XI2) 无效留用户真机复验
  - [x] 15 种专项图按批平移（与 master 同源，一图一文件 + wbtest，组件挂载断言补充；图表线收口）
    - [x] 批 1：boxplot（五数概括/1.5×IQR 须端离群）/ funnel（降序分层梯形/占比标注）/ heatmap（矩阵量程/色带插值/格内数值）/ radar（N 边形网格/多系列叠加）——真窗口四图特征色采样齐全（离群红点/色带深浅/双系列）
    - [x] 批 2：kline（涨红跌绿/影线实体）/ sankey（分层布局/贝塞尔色带）/ treemap（squarified 切分/兄弟明度梯度/hover 画卷命中）/ tree（肘线连线/两形态/深度渐变）——tree 的 orientation 字符串参数改 vertical 布尔（新栈类型化参数口径）；TreeItem 跨包构造用 make+push（字面量构造限定义包）
    - [x] 批 3：sunburst（逐级同心环/中心汇总 20px SemiBold）/ graph（力导向模拟/布局缓存随数据与画布失效）/ parallel（逐轴独立量程/条件对齐标签）/ pictorialbar（符号平铺拉伸/两形态/正负分色）
    - [x] 批 4：effectscatter（涟漪定时器改 @core.set_timeout 句柄 + EffAnim 持真取消 / 8 位 AARRGGBB 输入跳 alpha 位兼容新栈 RGBA 解析）/ themeriver（图例预留 240px、画布 <298 无绘制区）/ geo（VscJson 走 @sys / GeoRect 本地化 / 世界投影下小跨度区域像素占比小）
- [x] Markdown（新包 `yue/mdview`）：`markdown_view` 17 种 block 变体 + GFM 渲染面（表格对齐/任务列表/脚注编号/删除线/块级图片/可点击链接）与 master 同源平移；链接点击改 `on_link` 回调（open_url 属系统能力线，接入后由调用方转接默认浏览器）；富文本行按主题指纹缓存重建（不每帧重建）；表格列宽 percent、块间距交外层 row_gap
- [ ] 富文本编辑（远期 WYSIWYG 块编辑器）
- [ ] 代码高亮、终端模拟器、WebGL 画布（旧栈即无，列为待评估）

### 系统集成（master 参考面：`yue/system` 31 源文件 + `yue/traybus` 16 源文件，属可平移资产）
- [~] A 类平移 · 环境/文件原语
  - [x] `vscjson` → 新包 `yue/sys/json.mbt`（零依赖 JSON，公共名不变、只换包前缀），并按「每包自建 wbtest」补 7 条覆盖
  - [x] `envx`/`fsx`/`procrun` 落 `yue/sys`（桩 `sys_stub.c` 纯标准头直走 native-stub——区别于要 GTK 头的 win/render/text 桩走 prebuild 静态库：目录枚举 dirent、环境变量写删 setenv/unsetenv、文本读写 fopen、删文件幂等、平台标识 `sys_platform`；`sys_getenv` 走 C 层 getenv 保证 setenv 后立即可读——core/env 的表在部分实现是启动快照）；`pr_run` 复用 @subproc（限时回收 + 临时文件捕获 + C locale）
  - [x] `dialog` 落 `yue/sys/dialog.mbt`（GTK 端 `wm_file_*` 在 yue/win/gtk_stub.c：GtkFileChooserDialog 槽表、filters 解析、选项位、run 后才可取结果——未确认的 chooser 查 uri 会段错误桩侧拦下；sys 包不引 yue/win（parent 是纯句柄 id），链接由 prebuild 单独给 sys 下发 `-lyue_win_stub`）；模态 run 与真选文件留真机复验
  - [x] `singleinstance` 落 `yue/dbus/instance.mbt`（总线名字声称 `RequestName(app_id, DO_NOT_QUEUE)` + 入站 `Wake`；二次启动唤起首实例后自行退出，示例回证）
- [~] A 类平移 · 硬件族（六进 yue/sys；sensor/bluetooth 走 @traybus、disk 走 UDisks+@traybus，随 DBus 线）：
  - [x] `brightness`（读路径 sysfs 全套 + 写路径 logind 探针/SetBrightness 改注入槽 `brightness_set_logind_probe`/`brightness_set_action`，DBus 线接入后注入实做）/ `volume`（wpctl/pactl + volx 增强）/ `nightlight`（redshift + gamma 载体）/ `printer`（lpadmin/lp CUPS）/ `powerprofile`（powerprofilesctl）/ `monitor`（xrandr，从会话族提前——夜灯的显示器枚举依赖它）
  - [ ] `sensor`（iio-sensor-proxy）/ `bluetooth`（org.bluez）/ `disk`（UDisks2）随 DBus 线
- [x] A 类平移 · 桌面集成族：`wallpaper`/`defaultapps`/`appfind`/`open_url`+`reveal`（文件管理器定位）/`recent_files`
  - [x] 桌面环境识别落 `yue/sys/desktop.mbt`（XDG_CURRENT_DESKTOP 冒号多值取首个可识别值）——不引旧链 `@traybus`（红点积压 + sys 反向供它用会成环），DBus 线接入后复用这一份
  - [x] `open_url`/`reveal` 落 `yue/sys/launcher.mbt`（xdg-open 走新的分离式启动桩 `yue_sys_spawn_detached`：fork→setsid→fork→execvp + CLOEXEC 管道回传 exec 成败，不阻塞、不留僵尸；`reveal` 的 FileManager1「打开并选中」随 DBus 线补，当前恒落「打开父目录」；Win/mac 分支随平台批）
  - [x] `appfind` 落 `yue/sys/appfind.mbt`（.desktop 扫描按 id 去重、按 name 码点序；which 语义的固定目录查找；注入枚举版留给无 fsx 层的调用方与测试）
  - [x] `wallpaper`（按 DE 分派 xfconf-query / gsettings / qdbus，属性选择与 `mon_list` 的已连接输出联动）/`defaultapps`（xdg-mime + mimeapps.list 三层配置，写路径段内替换/追加/补段）——顺带补 `pr_env_blob` 的 DISPLAY/XAUTHORITY/WAYLAND_DISPLAY/DBUS_SESSION_BUS_ADDRESS 透传（桌面侧命令此前在子进程里必失败，monitor 批只能 skip 的根因）
  - [x] `recent_files` 落 `yue/sys/recent_files.mbt`（只读解析 `$XDG_DATA_HOME/recently-used.xbel`：手写 XBEL 扫描器 + XML 实体/百分号解码/ISO 8601 毫秒三只纯函数；Windows 的 Recent Documents 分支随平台批）
- [x] A 类平移 · 历史族：`browser_history`（含下载）/`browser_bookmarks`/`firefox_history`/`vscode_history` 落 `yue/sys`（SQLite 直读磁盘文件走 `prowk/moonsqlitefile`、只读不写不复制原库；新增 `sys_read_bytes_file` 原始字节入口；profile 按固定候选名探测）
- [~] A 类平移 · 会话与状态：`power`/`session`/`powerctl`/`online`/`idle`/`keepawake`/`clipboard_watch`/`locale_sys`/`sysinfo`/`windowctl`（monitor 已随硬件族提前）
  - [x] `sysinfo`（/etc/os-release + /proc/meminfo + /proc/uptime + /sys/class/dmi/id 纯文本读；桩改成「以 ftell 作提示、按块 fread 到 EOF」，否则伪文件读到成功但空串）/ `windowctl`（`wmctrl -l -p` 列、`-i -a` 激活、`-c` 关闭；设置类动作只在调用方触发）/ `clipboard_watch`（`xclip -o` 只读轮询；排期能力作参数注入，sys 不引 GUI 核心层，GUI 层给 `@core.set_timeout`）
  - [ ] `locale_sys` 的 `timedatectl` 半（可脱总线）+ `idle`（X11 ScreenSaver 扩展，走 `yue/win` 桩新增入口）
  - [~] `power`/`session`/`online`/`keepawake`/`powerctl` 的**总线能力已在 `yue/dbus`**（`upower.mbt`/`logind.mbt`/`netmon.mbt`/`inhibit.mbt`，真总线回证）；`yue/sys` 侧与旧链同名的语义化包装（电量读数、挂起/休眠动作、在线判定、抑制睡眠）待随各能力线补
- [x] 系统能力累积验证页 `examples/native-sys`：五个面板全是只读探测（系统与机器 / 桌面与硬件 / 应用与文件类型 / 窗口与剪贴板 / 最近与历史），三键里只有「重新探测」只读（注入回证点它），「打开链接」「打开目录」属设置类由使用者点；退出打 `NATIVE-SYS-GEO` 与 `NATIVE-SYS-STAT` 两行，字段与屏上读数一一对应（GUI 侧的累计页仍是 `examples/native-app`）
- [~] DBus 系在新事件循环下**重写/重验**：SNI 托盘（`traybus/sni.mbt`）、通知（新栈须重写 `org.freedesktop.Notifications`，含 `Notification::set_progress` 进度文本）、logind（`SetBrightness`/inhibit）、UPower、NetworkManager（`netmon`/`online`）、屏保 `screensaver`、媒体键 MPRIS（`media` 含状态监视轮询）
  - [x] 通用基建落新包 `yue/dbus`（`wire.mbt` 833 行 + `dbus.mbt` 419 行逐行平移，`bus.mbt` 剥掉 SNI/单实例语义后平移）：**不挂 glib fd 监视**——宿主周期调 `dbus_pump()`（缺省非阻塞）、断线自愈走 `dbus_set_post_delayed` 注入的通道，两者不注入时同步调用自带 `pump_until` 泵仍可用；socket 桩 `dbus_stub.c` 只用标准头、错误码与旧 shim 逐位一致；入站调用对外给 `CallReq`（`reply` 签名由参数值推导），线协议值类型不外泄。真总线回证 23/23（会话握手唯一名、ListNames、错误应答、AddMatch、系统总线 96 个名字）
  - [x] 能力模块首批（`yue/dbus`）：UPower / logind / netmon / screensaver / inhibit / MPRIS 逐行平移（测试同批平移并把旧 wbtest 的 inspect 换成 assert），MPRIS 轮询改排期通道注入；通知为新做（`GetCapabilities` 能力探测 + `Notify`/`CloseNotification`，进度 = `replaces_id` 重发 + 标准 hint `value`）；示例加 D-Bus 面板与「发通知(带进度)」按钮 + 宿主泵（`dbus_set_post_delayed` + 每 200ms `dbus_pump`），真窗口回证 `pool=:1.434`、通知能力 7 条
  - [x] SNI 托盘 + DBusMenu 落 `yue/dbus`（sni/icon/instance/filemanager 平移，bus 的托盘挂钩同批接回）；协议侧真总线回证：点示例「托盘图标」后 watcher 的 `RegisteredStatusNotifierItems` 9→10、退出对称注销；面板观感（图标出现/右键菜单/点击计数）留用户真机复验
  - [x] 单实例（总线名字 + Wake，示例回证二次启动唤起首实例后退出）与 `brightness` 的 logind 注入实做（`yue/dbus/bridge.mbt` 把探针与动作注进 `yue/sys` 的槽，注入后 `brightness_supported` 由假变真）
- [ ] 新建项（master 全仓无资产，属新做）：任务栏进度、dock 徽标、勿扰
- [ ] Wayland 后端：`idle`（X11 屏保扩展）/`windowctl`（wmctrl）/`clipboard_watch`（xclip）/`monitor`（xrandr）逐项定替代或降级
- [ ] 平台分派随各能力同批（master 有 Win32 直连族与 mac ObjC++ 族可参照）；真机清单见 `docs/zh/plan-system-integration.md` B8

### webview 与媒体（角色区 pane 模型；已锁决策与批次验收见方案 §4）

窗口内容 = 1..N 个互不重叠的矩形区（pane），每区声明 owner（自绘 = Painter / webview = 原生子件），矩形由 yoga 布局给；Tauri-like、爬虫内容获取页、原生多窗口三种形态同源。**本轮只做 Linux 闭环**，Windows/macOS 后端归输入通道另线与平台批。

- [x] **批 A 多窗口宿主**：`yue/core/app.mbt` 的 `App::new` 从「只建一窗」改成「一宿主管 N 窗，每窗一棵控件树、共用一个 `Loop`」；纯自绘即可验（开一个「关于」窗），两窗各自收到注入点击、关单窗不影响宿主
  - [x] 注册表落 `yue/core/host.mbt`：主窗=注册表第一扇（关掉它或关掉最后一扇才整体退出，`host_close_action` 纯函数钉住）；`App::step` 逐窗排空事件/喂输入法/脏窗上屏；`App::open_window` 开附窗、`App::close_window` 幂等关窗、`App::shutdown` 拆所有窗
  - [x] 两条进程级单槽随多窗升级：`invalidate()` 改**广播**置脏；浮层宿主改**取用函数**（浮层开在当前窗，句柄改进程级递增并加 `overlay_ids()`/`overlay_top_id()`——原先按宿主从 1 数起会跨窗撞号，`yue/ui` 里写死句柄的测试直接 `Array::at` 越界崩）
  - [x] GTK 桩窗口槽复用（扫 `area == NULL`），否则附窗反复开合吃光 32 槽；示例冒烟自杀点 12s→25s 给多步注入留空间
  - [x] 回证：core 70/70（新增 8 条无头注册表）、十包全绿、两示例 `--deny-warn` 零警告、全仓红点 287/68 未增；真窗口 `NATIVE-APP-MW wins=1 opened=1 closes=1 main_clicks=1 sub_clicks=2 sub_focus=101` + 几何行四字段，注入「点开→第二窗点两下与打字→主窗对照→关第二窗→再开」期间主窗始终活着；**待用户目视**：两窗互相遮挡/拖动时的重绘、关于窗里 preedit 下划线观感
- [x] **批 B pane 模型 + webview pane**：`mount_child_surface(kind : ChildKind, rect : (Double,Double,Double,Double)) -> ChildSurface`（`set_rect`/`unmount`/`handle`）的 C 端实现，语义是「容器里放一个原生子件」（Linux = `gtk_container_add` 进 GtkOverlay/GtkFixed，不需要 XEmbed 与像素合成）；WebKitGTK **只能动态链**，`scripts/prebuild.py` 增 `webkit2gtk-4.1` 探测项（本机实测 2.52.6 在位）；验整页与左右分栏两种摆法
  - [x] 窗口内容改「绘制区 + 可定位子件」的 `GtkFixed`（不用 Overlay：带子件的容器 pass_through 事件归属不可靠，Fixed 零机制），`size-allocate` 跟尺寸带「变了才设」闸门；子件槽表记归属窗口、`wm_close` 连带清理（防悬垂 `GtkWidget*`），槽位复用
  - [x] 新包 `yue/web`（`webview_supported()` 探测 / `webview_new` / `Webview::node(width,height,grow)` / `load_url` / `reload` / `stop` / `current_url` / `get_title` / `is_loading` / `close`）；C 之间传容器指针、MoonBit 只搬 int64，包依赖不引 `yue/win` 的 MoonBit 层；`ChildKind` 登记制（当前只有 `Webview = 1`）
  - [x] prebuild 缺 webkit 开发包时编「无宏」占位分支（探测返回不可用）而不是链接失败；链接顺序 `-lyue_web` 在 `-lyue_win_stub` 前
  - [x] 回证：`yue/web` 无头 2/2（矩形取整与去重键、探测与构造一致且未挂载零句柄）、`yue/win`/`yue/web`/`examples/native-web` `--deny-warn` 零警告、全仓红点 287/68 未增；真窗口两种摆法 `NATIVE-WEB-GEO pane=262,71,848x605 sidebar=12,71,240x605`（分栏）→ `pane=12,71,1098x605 sidebar=12,71,0x0`（整页），`title='Example Domain' url='https://example.com/'` 证明真渲染，截图复核
  - [ ] 待使用者肉眼复验：网页内滚动与点链接、webview 聚焦时本栈纯通道 IME 是否让位（离开即恢复）
- [x] **批 C JS 桥 + DOM 抓取 + 导航面**：契约沿用旧链 `yue/browser/browser.mbt` 的 22+6 方法名，但协议载荷改结构化返回（不回旧 ABI 裸字节）
  - [x] 双向通道：原生→网页 `execute_javascript` / `execute_javascript_with_result`（回包按请求序号配对）；网页→原生 `add_raw_binding(name)` 注入 shim 后页面直接调 `name(payload)`，载荷 JSON 化进 `on_invoke`
  - [x] DOM 抓取四档（正文/链接/meta/结构）：`dom_script` + `dom_parse` 两只纯函数，回包 JSON 走 `@sys` 零依赖解析器折成 `DomSnapshot`；解析失败 `ok=false` 且 raw 留着（不静默）
  - [x] 导航面：`load_url`/`load_html`/`reload`/`stop`/`go_back`/`go_forward`/`can_go_back`/`can_go_forward`/`is_loading`/`get_url`/`get_title` + 事件流（导航开始/提交/完成、标题、地址、加载失败）
  - [x] 引擎原生开关：`set_user_agent`、`get_cookies_for_url`（异步回包 JSON）、profile 挂 pane 级（`WebviewOptions.profile` → website data manager）、`browser_profile_persistence() -> Persistent | EphemeralOnly`；`webview_signal_mask()` 报可选信号在位
  - [x] 策略面：新窗（`window.open`）默认拦下并回报、可切「在当前 pane 导航」；权限**默认拒绝**并回报请求类名；下载默认放行可切拦下；web 进程终止回报 + `is_crashed()`
  - [x] pane 级可见性开关 `set_visible`（爬虫后台要的「不可见」在窗口层那条留给后续）；`remove_binding`/`remove_all_user_scripts` 恒 false 并写明是引擎没有注销口
  - [x] 异步事件形态定案：per-view 32 格环形队列 + `@core.set_timeout` 排期泵（**不挂绘制**），C 侧不回调 MoonBit
  - [x] 回证：`yue/web` 无头 11/11（脚本配平、四档解析、失败不静默、未挂载全安全、kind→事件逐条、回包序号配对、invoke 双路、探测一致）、`--deny-warn` 零警告、全仓红点 287/68 未增；真窗口 `NATIVE-WEB-JS binding=1 evals=1 dom_ok=4 dom_bad=0 links=3 text_bytes=68 meta=1 headings=2 elements=14 invokes=1 navs=2 perms=1 wins=1 crashes=0 cookie_bytes=2`，合成截图见「已被原生改过」+ 三条事件流水（回话/权限拒绝/新窗拦下）
  - [ ] 批 C 余项（随后续批按需接）：自定义协议流式回灌（`register_protocol`，旧链有、本栈未接）、`on_start|fail_navigation` 的细粒度 reason、跨窗共享的 cookie 同步
- [~] **批 D 媒体播放器**（可与 B/C 并行）：复用 `modules/ffmpeg-mbt`（零 libyue 依赖，已有 `decode_rgba`/`decode_pcm`/`seek`/`duration_s`/`video_fps`）+ `modules/yue-media` 内嵌的 miniaudio 设备层；**CPU 回灌 + 软解**（RGBA → `yue/render` 的 `Bitmap` → Painter 合成，本档位不做硬解与 GPU 合成）；新写播放器 UI（悬浮控制条/进度与音量/倍速/字幕叠加/seek 防抖）+ 音频时钟与同步；旧链坑照 adaptation.md 逐条验收（音画不同轴、seek 后进度从零重涨、换载崩溃）
  - [x] 新包 `yue/media`：引擎 `audio.mbt`(416 行) + `video.mbt`(476 行) 从 `modules/yue-media` **零 @yue 依赖整段平移**（含 15 条既有回归，旧链的坑随测试一起接住），`vp_tick` 开成公开口 `tick()` + 新增 `frames_decoded()`
  - [x] 字幕层 `subtitle.mbt`：SRT/VTT 同一套解析（时间戳两种写法、编号行/`WEBVTT` 头/`NOTE` 段跳过、`<c.*>`/`{\an8}` 标记剥离）+ `subtitle_at` 命中查询，全纯函数
  - [x] 播放器组件 `player.mbt`：`rgba_to_bitmap`（RGBA→Cairo BGRA，逐字节钉）+ 等比居中适配 + 字幕叠加 + 控制条（播放/暂停、进度轨、时间文字）+ `player_bar_hit` 分区纯函数实现 **seek 防抖（拖动只挪显示位置、抬手才真 seek）** + `on_tick`/`on_error` 观测与降级口
  - [x] 分层与链接：UI 组件放 `yue/media` 而非 `yue/ui`（否则每个用按钮的都要链 ffmpeg+miniaudio）；引擎文件零 UI 依赖；prebuild 给 `yue/media` 下发 `-lpthread -ldl -lm -lstdc++ -latomic`；moon.mod 增 `NoahLiu/ffmpeg-mbt@0.1.0` 依赖
  - [x] 回证：`yue/media` 18/18（15 平移 + 3 新增）、`--deny-warn` 零警告、全仓红点 287/68 未增；真窗口「开一扇播放器窗」= 第三扇窗播 `av_1s.mp4` + 内联 SRT，`NATIVE-WEB-MEDIA frames=10 pos_ms=1000 playing=0 err=''`，截图见彩条不错位 + 白字字幕叠加 + 进度满格 `0:01 / 0:01`
  - [ ] 批 D 余项（下一批做，不假装完成）：**倍速**（音频侧要时间拉伸，只加快视频会破坏音画同步）、内嵌字幕轨（mov_text/ass）、全屏、音量条 UI（引擎已有 `set_volume`，控件未画）、逐帧步进、真出声复验
- [x] **批 E 原生弹层窗口**：自绘 overlay 的「原生档」（`yue/win` 的 popup/transient 通道）——浮层（下拉/右键菜单/tooltip/toast/对话框）走原生窗口，不用自绘像素盖 webview
  - [x] 窗口层三件：`Window::set_popup(owner)`（无边框 + POPUP_MENU 类型 + transient_for + skip taskbar/pager + keep above + 不可调，**必须在 show 之前**）、`Window::move_to(x,y)`、`Window::origin()`（实测坑：`gtk_window_get_position` 在 WM reparent 下恒给 (0,0)，要 `gdk_window_get_origin` 才是屏幕原点）
  - [x] 宿主侧 `App::open_popup(x,y,w,h,screen_w?,screen_h?)` = 批 A 的附窗（共享循环与泵、`close_window` 只摘自己、`shutdown` 一起拆）+ 摆位纯函数 `popup_place`（越界翻到锚点另一侧、仍为负则钳 0、屏幕未知只钳不翻）
  - [x] 回证：core 71/71（新增摆位七边界）、`--deny-warn` 零警告、全仓红点 287/68 未增；真窗口 `NATIVE-WEB-POP opens=1 closed=1 choice='乙' wins=1 owner_origin=2,34`，弹层落在 (422,334) 与请求逐位一致、截图见无边框弹层压在 WebKit 网页文字之上、选项即自关而主窗仍在
  - [ ] 余项：把 `yue/core/overlay.mbt` 六件浮层接成「所在窗有已挂载 pane 时才切原生窗口」的原生档（本批只给了通道与一份自绘弹层示例）
- 积木原则：一个能力一个接口、可单独不用；能力之间不互相依赖（webview 不依赖媒体层，反之亦然，两者只依赖窗口/布局/事件层）；框架只给原语不给产品（爬虫框架、站点适配、内容解析、开发者面板、页面脚本库不进库）；每项能力给探测 + 语义化降级；新 API 一律走 `Painter`/`Bitmap` 门面
- 明确不做（避免反复讨论）：网络拦截/改写、代理配置、一窗多 webview 并排、Linux 上把 webview 变纹理、首批硬解、首批 GPU 合成、网页内 `<video>` 与自绘播放器统一、macOS 13 及以下的持久化隔离（根因是 Apple API 边界：持久化 profile 需 macOS 14+ 且有 bundle id）
- 平台后端（随各自真机，本轮不做）：Windows WebView2（两级异步 COM 创建、失败回退、就绪前排队、跨 HWND 焦点与滚轮转发），macOS WKWebView（自定义协议依赖私有 API，`dataStoreForIdentifier:` 才是真实 API 而非 `initWithIdentifier:`）

### 交付面（webview 批 A/B 落地后接上）
- [ ] 示例迁移：`hello` / `hello-themed` / `showcase`（全功能演示板，15 页）/ `sysmonitor`（6 页）/ `systemprobe`（8 页，`modules/yue-examples`）/ `yue-examples`
- [ ] 文档：中英使用文档按新栈重写（`components`/`components-ui`/`declarative`/`layout`/`relink`/`system-capabilities`/`tutorial`），README 挂新截图
- [ ] 发布：mooncakes 新版本；旧 `bin-*`/`vendor-*` 预构建发布链退役
- [ ] CI：三平台构建与测试脚本随新栈调整（当前分支构建预期为红）
- [ ] 真机验证矩阵：Ubuntu GNOME / KDE / XFCE；Windows 10 / 11；macOS（前置：取得设备）
- [ ] 旧链 `modules/yue-media` 下线：`yue/media` 已自带 miniaudio（4.1 MB 单头文件目前是两份拷贝），旧包删除后这份拷贝归一
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
