// 全量内置基调常量表（design.md §1.3「基调表发全量」）：§2 每个组件的默认观感
// 在此各有一条具名 `Style` 常量。数值逐条取自组件库现状（`on_draw` 现取的
// theme token 与散写的尺寸），不是新发明——P2 起组件绘制改读 `class` 解析出的
// resolved Style，这张表就是它们的默认值来源。
//
// 口径（与现状一致）：
// - 颜色一律写 theme token 名（§1.4 的 20 个），落色在绘制期；
// - 描边现状统一 1.0px、stroke 内缩 0.5，`border_width=1.0` 即该档；
// - 状态桶只收绘制期属性（§1.5 第五条）；现状「lit = hovered‖pressed」的
//   合并档在 hover/active 两桶各写一遍同值；
// - 无对应可表达属性的组件（image/icon/virt_list 的行内容由回调自定）不给块。

// ---- 文本与颜色 ----

///|
/// 正文文本（`text` 基础档：13 / `text_regular`，现状 `label` 缺省）。
pub let text_base : Style = style(font_size=13.0, color="text_regular")

///|
/// 次要小字（12 / `text_secondary`，现状 `Secondary` 角色）。
pub let text_secondary : Style = style(font_size=12.0, color="text_secondary")

///|
/// 区块/面板标题（14 SemiBold / `text_primary`，现状 `Section` 角色与 card 标题）。
pub let text_title : Style = style(
  font_size=14.0,
  font_weight=@text.SemiBold,
  color="text_primary",
)

///|
/// 大标题（18 SemiBold / `text_primary`，现状 `Title` 角色）。
pub let text_heading : Style = style(
  font_size=18.0,
  font_weight=@text.SemiBold,
  color="text_primary",
)

///|
/// 强调文本（13 SemiBold / `primary`，现状 `Accent` 角色）。
pub let text_accent : Style = style(
  font_size=13.0,
  font_weight=@text.SemiBold,
  color="primary",
)

// ---- 容器与面板 ----

///|
/// 通用盒子 `view`：现状 `container` 无自绘底色（透明、直角、无间距），
/// 只有页面根会铺 `bg_page`——那块是宿主缺省，不进组件基调。
pub let view_base : Style = style()

///|
/// 带标题面板 `panel`（现状 `group`：面板底 + 1px 边框 + padding 10 / 行距 6）。
pub let panel_base : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  padding=10.0,
  row_gap=6.0,
)

///|
/// 卡片 `card`（现状：面板底 + 1px 边框 + padding 12 / 行距 6，标题走 `text_title`）。
pub let card : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  padding=12.0,
  row_gap=6.0,
)

///|
/// 分隔线 `divider`（现状 `separator`：1px 线色 `border`，横竖共用颜色）。
pub let divider_base : Style = style(border_color="border", border_width=1.0)

// ---- 按钮族 ----

///|
/// 主按钮 solid 档（现状 `button`(Primary) 与 `button_t`(Solid)：主色底 + 白字 +
/// 左右 12 + 亮档 `primary_hover`；焦点环现状实底按钮走白描边）。
pub let button_solid : Style = style(
  background_color="primary",
  color="#fff",
  font_size=13.0,
  padding_left=12.0,
  padding_right=12.0,
  height=@theme.control_height,
)
.hover(background_color="primary_hover", color="#fff")
.active(background_color="primary_hover", color="#fff")
.focus(border_width=1.0, border_color="#fff")

///|
/// 按钮默认档 soft（**现状组件库默认档是 Soft 不是 Solid**：
/// 浅主色底 + 主色字，亮档翻主色底白字）。
pub let button_base : Style = style(
  background_color="primary_light",
  color="primary",
  font_size=13.0,
  padding_left=12.0,
  padding_right=12.0,
  height=@theme.control_height,
)
.hover(background_color="primary", color="#fff")
.active(background_color="primary", color="#fff")
.focus(border_width=1.0, border_color="primary")

///|
/// 描边按钮 border 档（现状 `button` Border / `stepper` 两侧钮）。
pub let button_border : Style = style(
  background_color="bg_panel",
  color="primary",
  border_width=1.0,
  border_color="border",
  font_size=13.0,
  padding_left=12.0,
  padding_right=12.0,
  height=@theme.control_height,
)
.hover(background_color="fill_hover")
.active(background_color="fill_hover")

///|
/// 文本按钮 text 档（现状 `button` Text：无底，亮档浅灰底）。
pub let button_text : Style = style(
  color="primary",
  font_size=13.0,
  padding_left=12.0,
  padding_right=12.0,
  height=@theme.control_height,
)
.hover(background_color="fill_hover")
.active(background_color="fill_hover")

///|
/// 危险按钮 danger 档（现状 `button_t` Danger）。
pub let button_danger : Style = style(
  background_color="danger",
  color="#fff",
  font_size=13.0,
  padding_left=12.0,
  padding_right=12.0,
  height=@theme.control_height,
)
.hover(background_color="danger_hover", color="#fff")
.active(background_color="danger_hover", color="#fff")

///|
/// 禁用按钮通用配方（现状所有变体统一：`fill_hover` 底 + `text_secondary` 字）。
pub let button_disabled : Style = style(
  background_color="fill_hover",
  color="text_secondary",
)

///|
/// 图标按钮 `icon_button`（现状 28×28 盒、无常态底、悬停浅灰、按下浅主色、圆角 4）。
pub let icon_button_base : Style = style(
  width=28.0,
  height=28.0,
  border_radius=4.0,
  color="text_regular",
)
.hover(background_color="fill_hover")
.active(background_color="primary_light")

///|
/// 链接 `link`（现状主色文本、悬停加下划线；悬停口径与 `breadcrumb` 末段一致）。
pub let link_base : Style = style(color="primary", font_size=13.0)
.hover(text_decoration=Underline)

// ---- 输入族 ----

///|
/// 单行输入 `input`（现状 `input`：面板底 + 1px 边框 + 13 号 `text_regular`；
/// 焦点边框转主色，禁用走 `text_secondary`）。
pub let input_base : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  color="text_regular",
  font_size=13.0,
  height=@theme.control_height,
)
.focus(border_color="primary", color="text_primary")

///|
/// 输入禁用档（现状 placeholder 与禁用同走 `text_secondary`）。
pub let input_disabled : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  color="text_secondary",
)

///|
/// 多行输入 `textarea`（皮肤同 `input_base`，现状另带 padding 4 与行内边距）。
pub let textarea_base : Style = merge(
  input_base,
  style(padding=4.0, width=260.0),
)

///|
/// 选择器字段 `select`（现状 `setup_picker_field`：32 高 / 200 宽 / 文本左 10，
/// 空值走占位色 `text_secondary`，有值 `text_primary`）。
pub let select_base : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  color="text_secondary",
  font_size=13.0,
  height=32.0,
  width=200.0,
  padding_left=10.0,
)
.focus(border_color="primary", color="text_primary")

///|
/// 下拉触发钮 `dropdown` 字段（现状：宽=文本+40、高 30、圆角 4、悬停浅灰底）。
pub let dropdown_base : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  color="text_regular",
  font_size=13.0,
  height=30.0,
  border_radius=4.0,
  padding_left=10.0,
)
.hover(background_color="fill_hover")

///|
/// 复选框 `checkbox`（现状 14×14 方框，未选 `border`、选中主色；行内文字同 `text_base`）。
pub let checkbox_base : Style = style(
  width=14.0,
  height=14.0,
  border_width=1.0,
  border_color="border",
)
.hover(border_color="primary")

///|
/// 开关 `switch`（现状胶囊 40×20：开=主色底、关=`border` 底、禁用=`fill_hover`）。
pub let switch_base : Style = style(
  width=40.0,
  height=20.0,
  background_color="border",
)
.hover(background_color="primary")

///|
/// 滑块 `slider`（现状轨道 160×4 走 `border`、拇指 12×12 主色；禁用轨道转浅灰）。
pub let slider_base : Style = style(
  width=160.0,
  height=@theme.control_height,
  background_color="border",
)
.hover(background_color="primary")

///|
/// 进度条 `progress`（现状 200×6：轨道 `fill_zebra`、填充主色）。
pub let progress_base : Style = style(
  width=200.0,
  height=6.0,
  background_color="fill_zebra",
)

///|
/// 步进器值格 `stepper`（现状 44×32 边框格、13 号居中；两侧钮走 `button_border`）。
pub let stepper_field_base : Style = style(
  width=44.0,
  height=@theme.control_height,
  border_width=1.0,
  border_color="border",
  color="text_regular",
  font_size=13.0,
)

///|
/// 评分星 `rate`（现状 22 号星：亮=主色实心、暗=`border` 描边）。
pub let rate_base : Style = style(width=22.0, height=22.0, border_color="border")
.hover(color="primary")

///|
/// 表单行 `form_item` 标签列（现状定宽 90 右对齐、12 号 `text_secondary`）。
pub let form_label_base : Style = style(
  width=90.0,
  font_size=13.0,
  color="text_secondary",
  text_align=@text.End,
)

///|
/// 表单错误行（现状 12 号 danger、行高 18）。
pub let form_error_base : Style = style(font_size=12.0, color="danger", height=18.0)

///|
/// 表单容器 `form`（现状无底色：列布局行距 8，标题走 `text_title`）。
pub let form_base : Style = style(row_gap=8.0)

// ---- 弹层与浮层 ----

///|
/// 浮层面板通用块（现状 `overlay_pane`：面板底 + 1px 边框，直角，含下拉菜单/
/// 选择器候选层/日期弹层共用）。
pub let overlay_pane_base : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
)

///|
/// 浮层候选行（现状 `select_row`：行高 28、文本左 8、未选 `text_regular`，
/// 悬停浅灰、选中浅主色底 + 主色字）。
pub let overlay_row_base : Style = style(
  height=28.0,
  font_size=13.0,
  color="text_regular",
  padding_left=8.0,
)
.hover(background_color="fill_hover")

///|
/// 选中行档（现状通用配方：`primary_light` 底 + `primary` 字，选择器/表格/穿梭框共用）。
pub let row_selected : Style = style(
  background_color="primary_light",
  color="primary",
)

///|
/// 对话框 `dialog` 面板（现状 420 宽、圆角 6、面板底 + 1px 边框；标题栏高 40）。
pub let dialog_base : Style = style(
  width=420.0,
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  border_radius=6.0,
)

///|
/// 消息框 `message_box`（面板同 `dialog_base`，正文 13 / `text_regular`）。
pub let message_box_base : Style = merge(
  dialog_base,
  style(font_size=13.0, color="text_regular"),
)

///|
/// 气泡 `tooltip`（现状深色实底 `text_primary` + 白字 12、圆角 4、高 24）。
pub let tooltip_base : Style = style(
  height=24.0,
  background_color="text_primary",
  color="#fff",
  font_size=12.0,
  border_radius=4.0,
)

///|
/// 气泡卡片 `popover`（现状即 `overlay_pane`）。
pub let popover_base : Style = overlay_pane_base

///|
/// 下拉菜单行 `menu` 条目（现状 `menu_row`：高 28、文本左 10、悬停浅灰）。
pub let menu_row_base : Style = style(
  height=28.0,
  font_size=13.0,
  color="text_regular",
  padding_left=10.0,
)
.hover(background_color="fill_hover")

///|
/// 侧边菜单 `menu`（现状容器 padding 6 / 行距 2，项高 40、圆角 4，
/// 悬停浅灰、选中浅主色 + 主色字）。
pub let side_menu_base : Style = style(
  width=180.0,
  padding=6.0,
  row_gap=2.0,
  background_color="bg_panel",
)

///|
/// 侧边菜单项（现状项高 40、圆角 4、未选 `text_primary`）。
pub let side_menu_item_base : Style = style(
  height=40.0,
  border_radius=4.0,
  color="text_primary",
  font_size=13.0,
)
.hover(background_color="fill_hover")

///|
/// 侧边菜单选中项（现状浅主色底 + 主色字 + 左缘 3px 主色条）。
pub let side_menu_item_selected : Style = style(
  background_color="primary_light",
  color="primary",
  border_width=3.0,
)

///|
/// 页签 `tabs` 头行（现状头行高 36、页签 13 号、未选 `text_secondary`、
/// 悬停回 `text_regular`，选中走 `tabs_item_active`）。
pub let tabs_base : Style = style(height=36.0, font_size=13.0, color="text_secondary")
.hover(color="text_regular")

///|
/// 页签选中档（现状主色字 + 底部 2px 主色指示条）。
pub let tabs_item_active : Style = style(color="primary", border_width=2.0)

// ---- 表格 ----

///|
/// 表格 `table` 外壳（现状 560 宽、面板底 + 1px 边框；行高 36、表头 40）。
pub let table_base : Style = style(
  width=560.0,
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
)

///|
/// 表头行（现状 `fill_zebra` 底、13 SemiBold `text_primary`、文本左 10）。
pub let table_head_base : Style = style(
  height=40.0,
  background_color="fill_zebra",
  font_size=13.0,
  font_weight=@text.SemiBold,
  color="text_primary",
  padding_left=10.0,
)

///|
/// 数据行（现状行高 36、单元格文本 13 / `text_regular` 左 10，斑马行与悬停另给）。
pub let table_row_base : Style = style(
  height=36.0,
  font_size=13.0,
  color="text_regular",
  padding_left=10.0,
)
.hover(background_color="fill_hover")

///|
/// 斑马行档（现状奇数行 `fill_zebra`）。
pub let table_row_zebra : Style = style(background_color="fill_zebra")

///|
/// 虚拟表格 `table_v`（现状与 `table` 共画法，仅默认高 360 与行高 32 不同）。
pub let table_v_base : Style = merge(table_base, style(height=360.0))

///|
/// 虚拟表格行档（现状行高 32）。
pub let table_v_row_base : Style = merge(table_row_base, style(height=32.0))

// ---- 显示族 ----

///|
/// 标签 `tag`（现状高 24、12 号、水平内 8、白字实底）。
pub let tag_base : Style = style(
  height=24.0,
  font_size=12.0,
  color="#fff",
  padding_left=8.0,
  padding_right=8.0,
)

///|
/// 徽标 `badge`（现状高 18、11 号、内 5、danger 底白字）。
pub let badge_base : Style = style(
  height=18.0,
  font_size=11.0,
  color="#fff",
  background_color="danger",
  padding_left=5.0,
  padding_right=5.0,
)

///|
/// 头像 `avatar`（现状 32×32、`info_light` 底、首字 `text_regular`）。
pub let avatar_base : Style = style(
  width=32.0,
  height=32.0,
  background_color="info_light",
  color="text_regular",
)

///|
/// 统计数值 `statistic`（现状标题 12 / `text_secondary`，值 22 / `text_primary`）。
pub let statistic_value_base : Style = style(font_size=22.0, color="text_primary")

///|
/// 描述列表 `descriptions`（现状标签列 12 / `text_secondary`、值列 12 默认色、
/// 标签列最小宽 96）。
pub let descriptions_label_base : Style = style(
  min_width=96.0,
  font_size=12.0,
  color="text_secondary",
)

///|
/// 空态 `empty`（现状 42 号图标走 `border`、文案 12 / `text_secondary`、padding 16）。
pub let empty_base : Style = style(
  padding=16.0,
  font_size=12.0,
  color="text_secondary",
  row_gap=8.0,
)

///|
/// 结果页 `result`（现状标题 16 SemiBold、副题 12 / `text_secondary`、padding 16）。
pub let result_base : Style = style(
  padding=16.0,
  font_size=12.0,
  color="text_secondary",
  row_gap=6.0,
)

///|
/// 结果标题档（现状 16 SemiBold）。
pub let result_title_base : Style = style(
  font_size=16.0,
  font_weight=@text.SemiBold,
  color="text_primary",
)

///|
/// 时间线（现状条目高 56、竖线 `border`、节点点色随类型、标题 13 SemiBold
/// `text_primary`、描述 12 / `text_secondary`）。
pub let timeline_base : Style = style(height=56.0, row_gap=12.0)

///|
/// 提示 `alert`（现状浅类型底 + 左缘 3px 类型条，标题 13 SemiBold、描述 12；
/// 高 36/56 由有无描述决定）。
pub let alert_base : Style = style(
  height=36.0,
  padding_left=12.0,
  font_size=13.0,
  font_weight=@text.SemiBold,
)

///|
/// 走马灯 `carousel`（现状 360×180 + 24 指示行、指示点 8×8、选中主色未选 `border`）。
pub let carousel_base : Style = style(width=360.0, height=180.0)

// ---- 导航其余 ----

///|
/// 树 `tree` 行（现状行高 32、行宽 260、每层缩进 18、文本 13 / `text_primary`，
/// 悬停浅灰）。
pub let tree_row_base : Style = style(
  height=32.0,
  width=260.0,
  font_size=13.0,
  color="text_primary",
  padding_left=14.0,
)
.hover(background_color="fill_hover")

///|
/// 穿梭框列（现状列宽 160、条目高 24、面板底 + 1px 边框、行同 `overlay_row_base` 悬停）。
pub let transfer_col_base : Style = style(
  width=160.0,
  min_height=60.0,
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
)

///|
/// 步骤条 `steps`（现状容器高 40、数字块 24×24、已完成浅主色/当前主色白字/
/// 待办浅灰底、连线高 2）。
pub let steps_base : Style = style(height=40.0, column_gap=6.0)

///|
/// 步骤当前档（现状主色底 + 白字）。
pub let steps_item_active : Style = style(
  width=24.0,
  height=24.0,
  background_color="primary",
  color="#fff",
  font_size=13.0,
)

///|
/// 面包屑 `breadcrumb`（现状项高 24、内 4、13 号，当前项 `text_primary`、
/// 其余 `text_secondary` 悬停转主色）。
pub let breadcrumb_base : Style = style(
  height=24.0,
  font_size=13.0,
  color="text_secondary",
  padding_left=4.0,
  padding_right=4.0,
)
.hover(color="primary")

///|
/// 分页 `pagination`（现状钮 28×28、13 号，当前页主色底白字、其余悬停浅主色底）。
pub let pagination_base : Style = style(
  width=28.0,
  height=28.0,
  font_size=13.0,
  color="text_regular",
  cursor=@widget.CURSOR_HAND,
)
.hover(background_color="primary_light")

///|
/// 分页当前页档（现状主色底 + 白字）。
pub let pagination_active : Style = style(
  background_color="primary",
  color="#fff",
)

///|
/// 折叠面板 `collapse`（现状标题行高 34、`info_light` 底、悬停浅主色、
/// 标题 13 SemiBold `text_primary`）。
pub let collapse_base : Style = style(
  height=34.0,
  background_color="info_light",
  font_size=13.0,
  font_weight=@text.SemiBold,
  color="text_primary",
)
.hover(background_color="primary_light")

///|
/// 分段器 `segmented`（现状容器 `border` 底 + 内 2、项高 30 内 16，
/// 选中面板底主色字）。
pub let segmented_base : Style = style(
  background_color="border",
  padding=2.0,
  column_gap=4.0,
)

///|
/// 分段项（现状高 30、左右 16、13 号 `text_regular`）。
pub let segmented_item_base : Style = style(
  height=30.0,
  padding_left=16.0,
  padding_right=16.0,
  font_size=13.0,
  color="text_regular",
)
.hover(background_color="border")

///|
/// 分段选中档（现状面板底 + 主色字）。
pub let segmented_item_active : Style = style(
  background_color="bg_panel",
  color="primary",
)

// ---- 容器其余 ----

///|
/// 滚动区 `scroll_view`（现状无自底色、视口超滚动描边 1px `border`；
/// 滚动条宽 8、轨道 `fill_zebra`、拇指 `border`）。
pub let scroll_view_base : Style = style(
  border_width=1.0,
  border_color="border",
)

///|
/// 滚动条（现状宽 8、轨道 `fill_zebra`、拇指 `border`）。
pub let scroll_bar_base : Style = style(
  width=8.0,
  background_color="fill_zebra",
)

///|
/// 分隔把手 `split`（现状把手 8.0、常显 `fill_zebra`、悬停浅灰、拖动主色）。
pub let split_handle_base : Style = style(
  width=8.0,
  background_color="fill_zebra",
)
.hover(background_color="fill_hover")
.active(background_color="primary")

///|
/// 颜色选择器 `color_picker`（字段同 `select_base`；色板格 26×26、格边框、
/// 面板 padding 8）。
pub let color_swatch_base : Style = style(
  width=26.0,
  height=26.0,
  border_width=1.0,
  border_color="border",
)

///|
/// 日历 `calendar`（现状面板 `bg_panel` + 1px 边框、格 36×30、头行 32、
/// 星期行 26、今日主色字、跨月 `text_secondary`）。
pub let calendar_base : Style = style(
  background_color="bg_panel",
  border_width=1.0,
  border_color="border",
  padding_top=8.0,
  padding_left=8.0,
)

///|
/// 日历格（现状 36×30、13 号 `text_primary`）。
pub let calendar_cell_base : Style = style(
  width=36.0,
  height=30.0,
  font_size=13.0,
  color="text_primary",
)
.hover(background_color="fill_hover")

///|
/// 日历选中档（现状主色实心块 + 白字）。
pub let calendar_cell_active : Style = style(
  background_color="primary",
  color="#fff",
)

///|
/// 日期选择器 `date_picker`（字段同 `select_base`，现状默认宽 180）。
pub let date_picker_base : Style = merge(select_base, style(width=180.0))

///|
/// 快捷动作块（现状 `primary` 主档示例，§1.3 示例里的 `primary` 具名块——
/// 白字主色底 + 圆角 4 + 手型，状态块现场开）。
pub let primary : Style = style(
  background_color="primary",
  color="#fff",
  border_radius=4.0,
  cursor=@widget.CURSOR_HAND,
)
.hover(background_color="primary_hover")
