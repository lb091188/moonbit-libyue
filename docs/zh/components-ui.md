# 主题组件库速查

主题组件库速查：Element Plus 风格的成套界面组件（按钮 / 输入 / 选择 / 表单 / 导航 / 布局 / 数据展示 / 图标 / 反馈 / 浮层），全部经 `@yue` 调用、返回 `Node` 直接进界面树，具名参数均可选。响应式 `Store` / `Signal` 参数见 [declarative.md](declarative.md)；原生控件（Window / Label / Button / Entry 等）见 [components.md](components.md)。

完整演示见 `examples/showcase`。

## 主题

全部颜色来自主题色板——深色低饱和配色：蓝 `#2D68C4`、绿 `#2E9E5B`、橙 `#D9822B`、红 `#D64550`，以及文字 / 边框 / 填充灰阶。组件一律直角，hover/active 用背景色表达，文字垂直居中。

### 切换与定制

| API | 用途 |
|---|---|
| `default_theme()` / `dark_theme()` | 内置浅色 / 暗色主题，返回 `Theme` |
| `theme_current()` | 读当前主题快照 |
| `theme_apply(t)` | 应用主题：切换即时生效、无需重建界面（Linux 端原生控件样式一并重建） |
| `on_theme_change(f)` | 订阅主题变更（组件挂载时注册，常驻界面重设定死色用） |
| `system_prefers_dark()` | 读系统深浅偏好（当前仅 Linux 有实现） |
| `on_system_theme_change(f)` | 系统偏好切换时回调（当前仅 Linux 有实现） |

`Theme` 字段：主色 `primary` / `primary_light` / `primary_hover`，语义色 `success` / `warning` / `danger` / `info`（各带 `_light` 浅色变体）与 `danger_hover`，文字 `text_primary` / `text_regular` / `text_secondary`，`border`，`fill_hover` / `fill_zebra`，底色 `bg_page`（页面）/ `bg_panel`（面板）。定制即改色板后整体 apply：

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

跟随系统深浅：启动时按 `system_prefers_dark()` 选主题，`on_system_theme_change` 回调里重读并重新 `theme_apply`。焦点环与字段聚焦边框为中性灰单层描亮（不用主题色）。

### 自定义组件接入主题

库内全部组件（含基础 `label()`，默认主题常规色）开箱即跟主题，使用方零颜色负担。自定义组件按三条法则接入，平台坑已封装：

| 场景 | 做法 |
|---|---|
| 自绘（on_draw） | 颜色在 draw 回调里现取 `theme_current()` 色板，无需任何订阅（主题切换时整窗强制重绘） |
| Label 文字设主题色 | `theme_bind_fg(l, fn() { theme_current().text_regular })`——内部处理了「设色后必须同文重排」的平台坑，裸 `set_color` 不跟主题、自行订阅漏重排会残留旧色 |
| 容器背景设主题色 | `theme_bind_bg(v, fn() { theme_current().bg_panel })`——定死背景不会因重绘更新，必须重设 |

固定色（品牌色块等）直接设即可，不受主题影响。

## 按钮与文本

### 主题按钮 button_t

`button_t(text, on_click?, variant? = Soft)`

自绘按钮，hover 变化收敛在主题色板内。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | 必填 | 按钮文本 |
| on_click | () -> Unit | 空操作 | 点击回调 |
| variant | ButtonVariant | `Soft` | `Solid` 实底白字 / `Soft` 浅底 / `Text` 无底 / `Danger` 危险色 |

hover 表现：Solid / Danger 加深，Soft 变实底白字，Text 浅灰底。

### 主题标签 label_t

`label_t(text, role? = Body, style?, style_str?, handle?)`

文字角色统一字号 / 颜色，左对齐；可叠加布局样式与句柄回调。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | 必填 | 文本 |
| role | TextRole | `Body` | `Title` / `Section` / `Body` / `Secondary` / `Accent` |
| style / style_str | 样式键值对 | `[]` | 见 [layout.md](layout.md) |
| handle | (Label) -> Unit | 空操作 | 创建后回调，拿到底层 Label 自行处理 |

### 链接 link

`link(text, on_click)`——主题色文字，悬停加深并显示下划线色条，点击回调。

## 输入

### 主题单行输入 entry_t

`entry_t(text? = "", password? = false, height? = 30.0, on_input?)`

统一字体与行高，文字色跟随主题；文字色不支持自定（平台限制，见 [adaptation.md](adaptation.md)）。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| password | Bool | false | 密码模式 |
| on_input | (String) -> Unit | 空操作 | 内容变化回调，收当前文本 |

### 边框输入框 input_t

`input_t(text? = "", password? = false, margin? = 0.0, width? = 280.0, height? = 30.0, clearable? = false, on_input?, invalid? = Store::new(false))`

外层自绘 1px 边框（聚焦变主题色）+ 白底，直角。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| margin / width / height | Double | 0 / 280 / 30 | 外边距与尺寸 |
| clearable | Bool | false | 悬停且非空时右侧显示 ✕，点击清空 |
| invalid | Store[Bool] | false | true 时边框变 danger 红（轻量表单校验），set 即生效 |

### 数字输入器 input_number

`input_number(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, num_width? = 64.0)`

-/+ 按钮步进，范围钳制，状态存 `Store[Double]`。

### 多行输入 textarea_t

`textarea_t(text? = "", width? = 280.0, height? = 110.0, margin? = 0.0, on_input?, clearable? = false, invalid? = Store::new(false))`

input_t 同套路：外层自绘 1px 边框（聚焦变主题色）+ 8px 内边距；内容超出自行滚动。clearable / invalid 语义同 input_t。

### 复选框 checkbox_t

`checkbox_t(title, checked? = false, disabled? = false, on_change?)`

自绘直角勾选框（14×14）：选中实心主题色 + 白勾，hover 边框变主题色，含禁用态。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| checked | Bool | false | 初始勾选 |
| disabled | Bool | false | 禁用态 |
| on_change | (Bool) -> Unit | 空操作 | 勾选变化回调，收新状态 |

### 单选组 radio_group

`radio_group(options, selected : Store[String], disabled? = false)`

选中项实心方块 + 主题色文字，未选中空心方块，点击互斥。

### 开关 switch_t

`switch_t(checked : Store[Bool], disabled? = false)`——轨道 + 滑块：开 = 主题蓝轨道滑块靠右，关 = 浅灰轨道滑块靠左；状态存 `Store[Bool]`。

### 滑杆 slider_t

`slider_t(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, width? = 0.0, on_change?)`

自绘：浅灰轨道 + 主题色填充段 + 方形 thumb，点击轨道 / 拖拽 thumb 调值，值按 step 量化后写入 `value`（外部 set 同样生效）；on_change 含拖拽过程。

## 选择

### 下拉选择 select_t

`select_t(options, value : Store[String], width? = 200.0, on_change?, clearable? = false)`

全自绘：点击弹候选列表，悬停高亮、当前选中主题色 ✓，点选回填并收起，失焦收起，三平台同形态。clearable=true 时悬停且有值，箭头左侧 ✕ 点击清空（value 置空串、`on_change("")`）。

### 日期选择器 date_picker_t

`date_picker_t(value? : Store[DateYMD?], on_change?, width? = 200.0, placeholder? = "请选择日期", clearable? = false)`

全自绘：输入框样式字段，点击弹出 `calendar_t` 月历面板，点选回填并收起，失焦收起；clearable=true 时悬停且有值，箭头旁 ✕ 清空（不触发 on_change）。

### 日期区间选择器 date_range_picker_t

`date_range_picker_t(value? : Store[DateRange], on_change?, width? = 260.0, placeholder? = "请选择日期区间", clearable? = false)`

字段显示「起 ~ 止」，点击弹区间日历：第一次点选起点，第二次点选终点（终点早于起点自动对调）后收起并回调 `on_change(起, 止)`；中间日期浅主题色底，端点实心方块；再点字段重新开始新区间。clearable 清空两端。

### 时间区间选择器 time_range_picker_t

`time_range_picker_t(value? : Store[TimeRange], on_change?, width? = 180.0, placeholder? = "请选择时间区间", clearable? = false)`

字段显示「起 : 止」时 : 分，点击弹起 / 止两行步进编辑器（时 0-23 / 分 0-59，`input_number` 承载），步进即改即回调 `on_change(起, 止)`；起止默认 00:00，弹层随字段失焦收起。

### 日期时间区间选择器 datetime_range_picker_t

`datetime_range_picker_t(value? : Store[DateTimeRange], on_change?, width? = 340.0, placeholder? = "请选择日期时间区间", clearable? = false)`

字段显示「起日期 起:分 ~ 止日期 止:分」，弹层 = 区间日历 + 分隔线 + 起 / 止两行时间步进 + 「完成」按钮；日期两段式选完或时间步进后区间完整即回调 `on_change(起日期, 起时间, 止日期, 止时间)`。值类型 `DateTimeRange{ start : (DateYMD, TimeHM)?, end : (DateYMD, TimeHM)? }`。

### 日历面板 calendar_t

`calendar_t(on_pick?, value? : Store[DateYMD?])`

全自绘月历面板：‹/› 切月 + 星期行 + 42 格月网格，跨月日期灰显，「今天」主题色，选中日期实心主题色方块；点击当月日期回调 on_pick 并写入 value。`DateYMD::format()` 出 `YYYY-MM-DD`，`TimeHM::format()` 出 `HH:MM`。

### 取色器 color_picker_t

`color_picker_t(value : Store[String], colors?, width? = 200.0)`

下拉形态：触发字段（当前色块 + hex + 箭头）点击弹预设色板，点击色块写入 `value`（`"#RRGGBB"`）并收起，选中色块主题色描边 + 白勾，失焦收起；色板可自定义（缺省 15 色）。

### 评分 rate_t

`rate_t(value : Store[Int], max? = 5, on_change?)`——五角星序列：选中实心主题色、未选中描边灰，悬停预亮，点击写入 `value`（0..max）。

## 表单

### 表单项 form_item

`form_item(label, control : Node, label_width? = 90.0, error? = Store::new(""))`

左侧标签（灰，定宽）+ 右侧控件区，垂直居中；`error` 为校验错误文案 Store，非空时控件行下方显示 danger 红字（行高固定预留，错误出现 / 消失不引起布局跳动）。

### 表单 form

`form(title, items : Array[Node])`——分组标题 + 一组表单项。

## 导航

### 侧边菜单 side_menu

`side_menu(items, selected : Store[String], width? = 180.0, icons? = [])`

hover 浅灰、选中主题浅蓝底 + 主题色文字 + 左侧 3px 强调条，4px 圆角。`icons` 给「项文本 → 图标」（缺省不画）；`selected` 为共享状态，主区页面订阅同一 Store 做 `set_visible` 联动。

### 分组侧边菜单 side_menu_sections

`side_menu_sections(sections : Array[(String, Array[String])], selected : Store[String], width? = 180.0, icons? = [], foldable? = true)`

组标题行（次要色小字 + 右侧折叠箭头）+ 组内项（画法 / 联动同 side_menu）；foldable=true 时可点收起 / 展开组内项（默认全展开，键盘 Enter/Space 同效）。

### 分段控制器 segmented

`segmented(options, selected : Store[String])`——选中白底 + 主题色文字，hover 灰底，直角。

### 面包屑 breadcrumb

`breadcrumb(items, selected : Store[String])`——当前项深色不可点，其余灰色可点、hover 变主题色。

### 分页 pagination

`pagination(current : Store[Int], pages)`——‹ 页码 ›，当前页主题色实底白字，悬停浅蓝，28×28 直角；`current` 从 1 开始，点击直接写源 Store，‹ › 边界钳制。

### 步骤条 steps

`steps(items, current : Store[Int])`——数字方块（完成浅蓝 / 当前实底 / 待办灰）+ 文字 + 连线。

### 页签 tabs_t

`tabs_t(pages : Array[(String, Node)], selected? : Store[Int])`

顶部形态：页签头行（选中主题色文字 + 底部 2px 指示条，悬停变深）+ 内容区经 `set_visible` 切换；`selected` 为页序号 Store，缺省内部建 0。

## 布局与分隔

### 分隔线 divider

`divider(vertical? = false, spacing? = 10.0)`——水平（默认，高 1px 宽 flex）或竖直（宽 1px 高随父容器），spacing 为两侧留白。底色挂载时读主题，重建界面生效。

### 可分栏 hsplit / vsplit

`hsplit(first, second, ratio? = 0.5, min_first? = 80.0, min_second? = 80.0)`（`vsplit` 的 min 默认 60）

可拖动分隔布局：8px 自绘把手常显分隔线 + 点纹（不靠 hover 就能找到），悬停浅灰底、拖动中主题色底白点，拖动经鼠标捕获不丢事件；ratio 为初始占比，min 钳制两栏下限。

## 数据展示

### 标签 tag / tag_of_type

`tag(text, color, height? = 24.0)` / `tag_of_type(text, t : SemanticType)`

前者彩色实底（自定颜色），后者类型浅底 + 同族深字（`Primary` / `Success` / `Warning` / `Danger` / `Info`）；直角，宽度按文本自适应。

### 头像 avatar

`avatar(letter, color, size? = 36.0)`——方形实底 + 白字居中。

### 角标 badge_count / badge_dot

`badge_count(count)` 红底白字数字小块（宽度自适应，颜色跟随主题）；`badge_dot(color? = "")` 8×8 色点。

### 数值统计 statistic

`statistic(title, value : Store[String])`——大号数值（响应式）+ 灰色标题。

### 线性进度条 progress_line

`progress_line(value : Store[Double], height? = 8.0)`——背景浅灰轨道 + 主题色填充，value 取值 0..1，变化自动重绘。

### 描述列表 descriptions

`descriptions(pairs : Array[(String, String)])`——键灰值深的两列网格。

### 时间线 timeline

`timeline(items : Array[(String, String, SemanticType)])`——左列色点 + 竖线，右列标题 + 描述；item 为（标题, 描述, 语义类型），行高固定 56。

### 折叠面板 collapse

`collapse(panels : Array[(String, Array[Node])])`——点击标题行切换内容显隐，各面板独立开合，初始仅第一面板展开。

### 卡片 card

`card(title, children : Array[Node], height? = 160.0)`——标题栏（加粗、底部分隔线）+ 边框，内容区从标题栏下方开始。

### 代码高亮 code_view

`code_view(lines, lang? = "moonbit", font_size? = 13.0, width? = 560.0, line_numbers? = false)`

逐 token 高亮排版，全平台行为一致（含 Windows）。lang 关键字集：moonbit / js / ts / python / rust / c / go / bash / sql（大小写不敏感）；line_numbers=true 左侧行号槽。

### Markdown 展示 markdown_view

`markdown_view(source, width? = 560.0)`——标题 1-6 / 段落 / **粗体** / *斜体* / `行内代码` / 链接文字 / 无序有序列表 / 引用（主题色竖条）/ 分隔线 / 围栏代码块（语言随 fence 标注，复用 code_view）；三平台显示一致，链接 / 代码色跟主题。

### 表格 table_t

`table_t(columns, rows : Store[Array[TableRow]], width? = 560.0, row_height? = 36.0, selection? : Store[Array[Int]], on_row_click?)`

表头 + 斑马纹 + 悬停底色 + Store 驱动（set 后整表重建并清空选择）。列用 `TableColumn::make(标题, 宽, align?)`（宽 ≤0 为弹性列均分剩余宽）。单元格 `TableCell`：`CellText` / `CellTag(文本, 语义类型)` / `CellColorBox(色值, 名)` / `CellLines(多行, 行自动撑高)`；`TableRow::make(字符串数组)` 建纯文本行。不传 `selection` 时行点击单选高亮；传 `selection` 启用复选框列（行点击勾选、表头全选 / 清空、部分选中画横条，选中行浅蓝底），回调收 `(行号, 行)`。

### 虚拟滚动表格 table_v_t

`table_v_t(columns, rows : Store[Array[TableRow]], width? = 560.0, height? = 360.0, row_height? = 32.0, selection? : Store[Array[Int]], on_row_click?)`

table_t 的万行级形态：只画可见行，自管滚动（滚轮 / 拖拽滚动条 / 键盘），不受滚动容器内容高度上限约束；单元格画法同 table_t（CellLines 在行高内最多两行），列 / selection 语义一致。

### 树形控件 tree

`tree(root : Array[TreeNode])`——缩进层级 + 点击展开 / 折叠（有子节点时箭头指示）。节点 `TreeNode{ label : String, children : Array[TreeNode] }`。

### 穿梭框 transfer

`transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width? = 160.0)`——左右两列，点击行选中（实心方块标记），中间 ›/‹ 按钮把选中项在两列间移动；数据经双 Store 驱动。

## 图标

内置矢量图标 136 种（箭头 / 文件 / 编辑 / 视图 / 导航 / 媒体 / 通信 / 系统 / 开发 / 数据 / 状态，风格对齐 Tabler / Lucide）。

| API | 用途 |
|---|---|
| `icon(kind : IconKind, size? = 16.0, color? = "")` | 图标节点：默认主题常规色，传 color 固定色 |
| `icon_button_t(kind, on_click?, size? = 28.0, tip? = "")` | 方形图标按钮：hover 浅灰底 + 文字色提亮，Enter/Space 触发；tip 非空挂原生悬浮提示；marginRight 6 便于工具栏排列 |
| `draw_icon(p : Painter, kind, cx, cy, s, color)` | 统一自绘入口（中心坐标 + 边长） |
| `all_icons()` / `icon_name(kind)` | 全清单 / 取名 |

## 反馈

### 提示横幅 alert / alert_closeable

`alert(text, t : SemanticType, height? = 40.0)` / `alert_closeable(text, t)`

类型浅底 + 左侧 4px 色条 + 同族深字，全宽；后者右侧带关闭钮，点击整条隐藏。

### 结果页 result

`result(t, title, desc, children : Array[Node])`——大色块符号 + 标题 + 描述 + 自定义按钮区。

### 空状态 empty

`empty(desc)`——灰块占位 + 居中说明。

### 对话框 dialog_t

`dialog_t(visible : Store[Bool], title, children : Array[Node], width? = 420.0, confirm_text? = "确定", cancel_text? = "取消", on_confirm?, on_cancel?, close_on_mask? = false)`

应用内对话框：同窗遮罩（半透明黑，absolute 相对挂载容器——挂窗口根即盖全窗）+ 居中面板（标题栏 ✕ + 内容 + 右对齐按钮区）。visible 驱动弹 / 收；✕ / 取消 / 确定触发回调后自动收起，文案传空串隐藏该按钮（两个都空则整行不显示），close_on_mask=true 时点遮罩空白处也收起。视觉模态，非键盘强模态。

### 轻提示 toast_layer

`toast_layer(duration_ms? = 2600) -> (Node, (String, SemanticType) -> Unit)`

层节点挂窗口根（absolute 顶部，不占布局），推送函数弹语义提示条（面板底 + 边框 + 类型图标），默认 2.6s 自动移除，多条自上而下堆叠；须在层 mount 后调用。

### 右键菜单 context_menu_for

`context_menu_for(content : Node, items : Array[(String, () -> Unit)])`——给任意节点包原生右键菜单，文案 "-" 画分隔线；弹出位置经 `bounds_in_screen` 换算屏幕坐标，每次右键现建菜单。

## 浮层

### 悬浮提示 tooltip_t

`tooltip_t(content : Node, tip)`——给任意节点包原生 tooltip（系统样式，零成本；主题化气泡请用 popover_t）。Linux 端 tooltip 颜色已接管为恒深底白字（不随系统主题）。

### 气泡弹层 popover_t

`popover_t(trigger : Node, content : Node, width, height)`——trigger 点击后在自身下方弹出任意 Node 内容，再次点击切换收起。

### 下拉菜单 dropdown_menu

`dropdown_menu(trigger : String, items, on_select : (Int) -> Unit, width? = 160.0)`——触发文字 + 下拉箭头，点击弹菜单项列表：悬停高亮，点击回调序号并收起；items 中 `"-"` 画分隔线。

### 轮播 carousel_t

`carousel_t(pages : Array[Node], width? = 360.0, height? = 180.0, interval_ms? = 3000)`——面板序列 + 左右箭头 + 底部指示点；interval_ms > 0 时每 interval 毫秒自动切换（悬停暂停），点击箭头 / 指示点手动切换。

## 演示

`moon run examples/showcase`——全功能演示板，组件库与 libyue 全部能力按页演示，每页源码独立成文件（`examples/showcase/pages_*.mbt`），是最好的复制粘贴素材库；页面清单见[文档索引](README.md)「演示」节。

![基础组件](../images/components-basic.png)

![导航](../images/components-nav.png)

![数据展示](../images/components-data.png)

![反馈](../images/components-feedback.png)

组件间状态协调统一走 `Store`（subscribe / map / bind_label）或信号 `Signal`（computed 自动依赖收集，batch 批处理；组件 Store 参数可传 `sig.store()` 视图），见 [declarative.md](declarative.md)。English version: [components-ui.md](../components-ui.md).
