# 主题组件库速查

主题组件库速查：Element Plus 风格的成套界面组件（按钮 / 输入 / 选择 / 表单 / 导航 / 布局 / 数据展示 / 图标 / 反馈 / 浮层），全部经 `@yue` 调用、返回 `Node` 直接进界面树。签名中带 `?` 的可选参数必须具名传值（如 `date_picker_t(value=day)`），不带 `?` 的位置参数按序传。响应式 `Store` / `Signal` 参数见 [declarative.md](declarative.md)；原生控件（Window / Label / Button / Entry 等）见 [components.md](components.md)。

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

`Theme` 字段：

| 字段 | 用途 |
|---|---|
| `primary` / `primary_light` / `primary_hover` | 主色 / 浅主色 / hover 加深 |
| `success` / `warning` / `danger` / `info` | 四种语义色（各带同名 `_light` 浅色变体） |
| `danger_hover` | 危险色 hover 加深 |
| `text_primary` / `text_regular` / `text_secondary` | 主文字 / 常规文字 / 次要文字 |
| `border` | 边框色 |
| `fill_hover` / `fill_zebra` | hover 填充 / 斑马纹 |
| `bg_page` / `bg_panel` | 页面底色 / 面板底色 |

定制即改色板后整体 apply：

```moonbit
@yue.initialize()
let t = @yue.default_theme()
@yue.theme_apply({ ..t, primary: "#1E4FA3", primary_light: "#E3EDFA" })
```

跟随系统深浅：启动时按 `system_prefers_dark()` 选主题，`on_system_theme_change` 回调里重读并重新 `theme_apply`。焦点环与字段聚焦边框为中性灰单层描亮（不用主题色）。

```moonbit
let dark = @yue.system_prefers_dark()
@yue.theme_apply(if dark { @yue.dark_theme() } else { @yue.default_theme() })
@yue.on_system_theme_change(fn() {
  @yue.theme_apply(if @yue.system_prefers_dark() { @yue.dark_theme() } else { @yue.default_theme() })
})
```

### 自定义组件接入主题

库内全部组件（含基础 `label()`，默认主题常规色）开箱即跟主题，使用方零颜色负担。自定义组件按三条法则接入，平台坑已封装：

| 场景 | 做法 |
|---|---|
| 自绘（on_draw） | 颜色在 draw 回调里现取 `theme_current()` 色板，无需任何订阅（主题切换时整窗强制重绘） |
| Label 文字设主题色 | `theme_bind_fg(l, fn() { theme_current().text_regular })`——内部处理了「设色后必须同文重排」的平台坑，裸 `set_color` 不跟主题、自行订阅漏重排会残留旧色 |
| 容器背景设主题色 | `theme_bind_bg(v, fn() { theme_current().bg_panel })`——定死背景不会因重绘更新，必须重设 |

固定色（品牌色块等）直接设即可，不受主题影响。

```moonbit
let l = @yue.Label::make("标题")
@yue.theme_bind_fg(l, fn() { @yue.theme_current().text_regular })
let panel = @yue.Container::make()
@yue.theme_bind_bg(panel, fn() { @yue.theme_current().bg_panel })
```

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

```moonbit
@yue.button_t("确定", on_click=fn() { submit() })
@yue.button_t("删除", variant=@yue.Danger)
```

### 主题标签 label_t

`label_t(text, role? = Body, style?, style_str?, handle?)`

文字角色统一字号 / 颜色，左对齐；可叠加布局样式与句柄回调。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | 必填 | 文本 |
| role | TextRole | `Body` | `Title` / `Section` / `Body` / `Secondary` / `Accent` |
| style / style_str | 样式键值对 | `[]` | 见 [layout.md](layout.md) |
| handle | (Label) -> Unit | 空操作 | 创建后回调，拿到底层 Label 自行处理 |

```moonbit
@yue.label_t("设置", role=@yue.Title)
@yue.label_t("当前用户:admin", role=@yue.Secondary)
```

### 链接 link

`link(text, on_click)`——主题色文字，悬停加深并显示下划线色条，点击回调。

```moonbit
@yue.link("查看详情", fn() { open_detail() })
```

## 输入

### 主题单行输入 entry_t

`entry_t(text? = "", password? = false, height? = 30.0, on_input?)`

统一字体与行高，文字色跟随主题；文字色不支持自定（平台限制，见 [adaptation.md](adaptation.md)）。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| password | Bool | false | 密码模式 |
| on_input | (String) -> Unit | 空操作 | 内容变化回调，收当前文本 |

```moonbit
let name = @yue.Store::new("")
@yue.entry_t(text="预填", on_input=fn(s) { name.set(s) })
```

### 边框输入框 input_t

`input_t(text? = "", password? = false, margin? = 0.0, width? = 280.0, height? = 30.0, clearable? = false, on_input?, invalid? = Store::new(false))`

外层自绘 1px 边框（聚焦变主题色）+ 白底，直角。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| margin / width / height | Double | 0 / 280 / 30 | 外边距与尺寸 |
| clearable | Bool | false | 悬停且非空时右侧显示 ✕，点击清空 |
| invalid | Store[Bool] | false | true 时边框变 danger 红（轻量表单校验），set 即生效 |

```moonbit
let valid = @yue.Store::new(false)
@yue.input_t(text="admin", clearable=true, invalid=valid, on_input=fn(s) { check(s) })
```

### 数字输入器 input_number

`input_number(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, num_width? = 64.0)`

-/+ 按钮步进，范围钳制，状态存 `Store[Double]`。

```moonbit
let count = @yue.Store::new(1.0)
@yue.input_number(count, min=1.0, max=10.0)
```

### 多行输入 textarea_t

`textarea_t(text? = "", width? = 280.0, height? = 110.0, margin? = 0.0, on_input?, clearable? = false, invalid? = Store::new(false))`

input_t 同套路：外层自绘 1px 边框（聚焦变主题色）+ 8px 内边距；内容超出自行滚动。clearable / invalid 语义同 input_t。

```moonbit
@yue.textarea_t(text="第一行\n第二行", width=320.0, height=120.0)
```

### 复选框 checkbox_t

`checkbox_t(title, checked? = false, disabled? = false, on_change?)`

自绘直角勾选框（14×14）：选中实心主题色 + 白勾，hover 边框变主题色，含禁用态。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| checked | Bool | false | 初始勾选 |
| disabled | Bool | false | 禁用态 |
| on_change | (Bool) -> Unit | 空操作 | 勾选变化回调，收新状态 |

```moonbit
@yue.checkbox_t("记住我", checked=true, on_change=fn(v) { remember(v) })
```

### 单选组 radio_group

`radio_group(options, selected : Store[String], disabled? = false)`

选中项实心方块 + 主题色文字，未选中空心方块，点击互斥。

```moonbit
let choice = @yue.Store::new("甲")
@yue.radio_group(["甲", "乙", "丙"], choice)
```

### 开关 switch_t

`switch_t(checked : Store[Bool], disabled? = false)`——轨道 + 滑块：开 = 主题蓝轨道滑块靠右，关 = 浅灰轨道滑块靠左；状态存 `Store[Bool]`。

```moonbit
let enabled = @yue.Store::new(true)
@yue.switch_t(enabled)
```

### 滑杆 slider_t

`slider_t(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, width? = 0.0, on_change?)`

自绘：浅灰轨道 + 主题色填充段 + 方形 thumb，点击轨道 / 拖拽 thumb 调值，值按 step 量化后写入 `value`（外部 set 同样生效）；on_change 含拖拽过程。

```moonbit
let volume = @yue.Store::new(0.5)
@yue.slider_t(volume, max=1.0, step=0.1, on_change=fn(v) { set_volume(v) })
```

## 选择

### 下拉选择 select_t

`select_t(options, value : Store[String], width? = 200.0, on_change?, clearable? = false)`

全自绘：点击弹候选列表，悬停高亮、当前选中主题色 ✓，点选回填并收起，失焦收起，三平台同形态。clearable=true 时悬停且有值，箭头左侧 ✕ 点击清空（value 置空串、`on_change("")`）。

```moonbit
let color = @yue.Store::new("红")
@yue.select_t(["红", "绿", "蓝"], color, clearable=true, on_change=fn(s) { recolor(s) })
```

### 日期选择器 date_picker_t

`date_picker_t(value? : Store[DateYMD?], on_change?, width? = 200.0, placeholder? = "请选择日期", clearable? = false)`

全自绘：输入框样式字段，点击弹出 `calendar_t` 月历面板，点选回填并收起，失焦收起；clearable=true 时悬停且有值，箭头旁 ✕ 清空（不触发 on_change）。

```moonbit
let day : @yue.Store[@yue.DateYMD?] = @yue.Store::new(None)
@yue.date_picker_t(value=day, on_change=fn(d) { picked(d) })
```

### 日期区间选择器 date_range_picker_t

`date_range_picker_t(value? : Store[DateRange], on_change?, width? = 260.0, placeholder? = "请选择日期区间", clearable? = false)`

字段显示「起 ~ 止」，点击弹区间日历：第一次点选起点，第二次点选终点（终点早于起点自动对调）后收起并回调 `on_change(起, 止)`；中间日期浅主题色底，端点实心方块；再点字段重新开始新区间。clearable 清空两端。

```moonbit
let range : @yue.Store[@yue.DateRange] = @yue.Store::new({ start: None, end: None })
@yue.date_range_picker_t(value=range, on_change=fn(s, e) { show(s, e) })
```

### 时间区间选择器 time_range_picker_t

`time_range_picker_t(value? : Store[TimeRange], on_change?, width? = 180.0, placeholder? = "请选择时间区间", clearable? = false)`

字段显示「起 : 止」时 : 分，点击弹起 / 止两行步进编辑器（时 0-23 / 分 0-59，`input_number` 承载），步进即改即回调 `on_change(起, 止)`；起止默认 00:00，弹层随字段失焦收起。

```moonbit
let tr : @yue.Store[@yue.TimeRange] = @yue.Store::new({ start: None, end: None })
@yue.time_range_picker_t(value=tr, on_change=fn(s, e) { show(s, e) })
```

### 日期时间区间选择器 datetime_range_picker_t

`datetime_range_picker_t(value? : Store[DateTimeRange], on_change?, width? = 340.0, placeholder? = "请选择日期时间区间", clearable? = false)`

字段显示「起日期 起:分 ~ 止日期 止:分」，弹层 = 区间日历 + 分隔线 + 起 / 止两行时间步进 + 「完成」按钮；日期两段式选完或时间步进后区间完整即回调 `on_change(起日期, 起时间, 止日期, 止时间)`。值类型 `DateTimeRange{ start : (DateYMD, TimeHM)?, end : (DateYMD, TimeHM)? }`。

```moonbit
let dtr : @yue.Store[@yue.DateTimeRange] = @yue.Store::new({ start: None, end: None })
@yue.datetime_range_picker_t(value=dtr, on_change=fn(sd, st, ed, et) { show(sd, st, ed, et) })
```

### 日历面板 calendar_t

`calendar_t(on_pick?, value? : Store[DateYMD?])`

全自绘月历面板：‹/› 切月 + 星期行 + 42 格月网格，跨月日期灰显，「今天」主题色，选中日期实心主题色方块；点击当月日期回调 on_pick 并写入 value。`DateYMD::format()` 出 `YYYY-MM-DD`，`TimeHM::format()` 出 `HH:MM`。

```moonbit
@yue.calendar_t(on_pick=fn(d) { picked(d) })
```

### 取色器 color_picker_t

`color_picker_t(value : Store[String], colors?, width? = 200.0)`

下拉形态：触发字段（当前色块 + hex + 箭头）点击弹预设色板，点击色块写入 `value`（`"#RRGGBB"`）并收起，选中色块主题色描边 + 白勾，失焦收起；色板可自定义（缺省 15 色）。

```moonbit
let hex = @yue.Store::new("#2D68C4")
@yue.color_picker_t(hex)
```

### 评分 rate_t

`rate_t(value : Store[Int], max? = 5, on_change?)`——五角星序列：选中实心主题色、未选中描边灰，悬停预亮，点击写入 `value`（0..max）。

```moonbit
let stars = @yue.Store::new(4)
@yue.rate_t(stars)
```

## 表单

### 表单项 form_item

`form_item(label, control : Node, label_width? = 90.0, error? = Store::new(""))`

左侧标签（灰，定宽）+ 右侧控件区，垂直居中；`error` 为校验错误文案 Store，非空时控件行下方显示 danger 红字（行高固定预留，错误出现 / 消失不引起布局跳动）。

```moonbit
let err = @yue.Store::new("")
@yue.form_item("用户名", @yue.input_t(text="admin"), error=err)
```

### 表单 form

`form(title, items : Array[Node])`——分组标题 + 一组表单项。

```moonbit
@yue.form("账号设置", [
  @yue.form_item("用户名", @yue.input_t()),
  @yue.form_item("密码", @yue.input_t(password=true)),
])
```

## 导航

### 侧边菜单 side_menu

`side_menu(items, selected : Store[String], width? = 180.0, icons? = [])`

hover 浅灰、选中主题浅蓝底 + 主题色文字 + 左侧 3px 强调条，4px 圆角。`icons` 给「项文本 → 图标」（缺省不画）；`selected` 为共享状态，主区页面订阅同一 Store 做 `set_visible` 联动。

```moonbit
let page = @yue.Store::new("首页")
@yue.side_menu(["首页", "设置", "关于"], page)
```

### 分组侧边菜单 side_menu_sections

`side_menu_sections(sections : Array[(String, Array[String])], selected : Store[String], width? = 180.0, icons? = [], foldable? = true)`

组标题行（次要色小字 + 右侧折叠箭头）+ 组内项（画法 / 联动同 side_menu）；foldable=true 时可点收起 / 展开组内项（默认全展开，键盘 Enter/Space 同效）。

```moonbit
let page = @yue.Store::new("按钮")
@yue.side_menu_sections([("组件", ["按钮", "输入"]), ("系统", ["关于"])], page)
```

### 分段控制器 segmented

`segmented(options, selected : Store[String])`——选中白底 + 主题色文字，hover 灰底，直角。

```moonbit
let view = @yue.Store::new("列表")
@yue.segmented(["列表", "网格"], view)
```

### 面包屑 breadcrumb

`breadcrumb(items, selected : Store[String])`——当前项深色不可点，其余灰色可点、hover 变主题色。

```moonbit
let cur = @yue.Store::new("网络")
@yue.breadcrumb(["首页", "设置", "网络"], cur)
```

### 分页 pagination

`pagination(current : Store[Int], pages)`——‹ 页码 ›，当前页主题色实底白字，悬停浅蓝，28×28 直角；`current` 从 1 开始，点击直接写源 Store，‹ › 边界钳制。

```moonbit
let page_no = @yue.Store::new(1)
@yue.pagination(page_no, 10)
```

### 步骤条 steps

`steps(items, current : Store[Int])`——数字方块（完成浅蓝 / 当前实底 / 待办灰）+ 文字 + 连线。

```moonbit
let step = @yue.Store::new(1)
@yue.steps(["填写信息", "验证", "完成"], step)
```

### 页签 tabs_t

`tabs_t(pages : Array[(String, Node)], selected? : Store[Int])`

顶部形态：页签头行（选中主题色文字 + 底部 2px 指示条，悬停变深）+ 内容区经 `set_visible` 切换；`selected` 为页序号 Store，缺省内部建 0。

```moonbit
@yue.tabs_t([("概览", overview_view), ("日志", log_view)])
```

## 布局与分隔

### 分隔线 divider

`divider(vertical? = false, spacing? = 10.0)`——水平（默认，高 1px 宽 flex）或竖直（宽 1px 高随父容器），spacing 为两侧留白。底色挂载时读主题，重建界面生效。

```moonbit
@yue.divider(spacing=16.0)
@yue.divider(vertical=true)
```

### 可分栏 hsplit / vsplit

`hsplit(first, second, ratio? = 0.5, min_first? = 80.0, min_second? = 80.0)`（`vsplit` 的 min 默认 60）

可拖动分隔布局：8px 自绘把手常显分隔线 + 点纹（不靠 hover 就能找到），悬停浅灰底、拖动中主题色底白点，拖动经鼠标捕获不丢事件；ratio 为初始占比，min 钳制两栏下限。

```moonbit
@yue.hsplit(nav_panel, content_panel, ratio=0.25)
@yue.vsplit(editor_panel, terminal_panel)
```

## 数据展示

### 标签 tag / tag_of_type

`tag(text, color, height? = 24.0)` / `tag_of_type(text, t : SemanticType)`

前者彩色实底（自定颜色），后者类型浅底 + 同族深字（`Primary` / `Success` / `Warning` / `Danger` / `Info`）；直角，宽度按文本自适应。

```moonbit
@yue.tag("v1.2", "#2D68C4")
@yue.tag_of_type("运行中", @yue.Success)
```

### 头像 avatar

`avatar(letter, color, size? = 36.0)`——方形实底 + 白字居中。

```moonbit
@yue.avatar("Y", "#2D68C4", size=40.0)
```

### 角标 badge_count / badge_dot

`badge_count(count)` 红底白字数字小块（宽度自适应，颜色跟随主题）；`badge_dot(color? = "")` 8×8 色点。

```moonbit
@yue.badge_count(3)
@yue.badge_dot(color="#2E9E5B")
```

### 数值统计 statistic

`statistic(title, value : Store[String])`——大号数值（响应式）+ 灰色标题。

```moonbit
let visits = @yue.Store::new("1,024")
@yue.statistic("今日访问", visits)
```

### 线性进度条 progress_line

`progress_line(value : Store[Double], height? = 8.0)`——背景浅灰轨道 + 主题色填充，value 取值 0..1，变化自动重绘。

```moonbit
let ratio = @yue.Store::new(0.42)
@yue.progress_line(ratio, height=6.0)
```

### 描述列表 descriptions

`descriptions(pairs : Array[(String, String)])`——键灰值深的两列网格。

```moonbit
@yue.descriptions([("名称", "libyue"), ("版本", "0.15.6"), ("平台", "Linux")])
```

### 时间线 timeline

`timeline(items : Array[(String, String, SemanticType)])`——左列色点 + 竖线，右列标题 + 描述；item 为（标题, 描述, 语义类型），行高固定 56。

```moonbit
@yue.timeline([
  ("构建", "编译通过", @yue.Success),
  ("测试", "45/45 通过", @yue.Success),
  ("发布", "等待审核", @yue.Warning),
])
```

### 折叠面板 collapse

`collapse(panels : Array[(String, Array[Node])])`——点击标题行切换内容显隐，各面板独立开合，初始仅第一面板展开。

```moonbit
@yue.collapse([
  ("常规", [@yue.label_t("基础设置项", role=@yue.Body)]),
  ("高级", [@yue.label_t("调试选项", role=@yue.Body)]),
])
```

### 卡片 card

`card(title, children : Array[Node], height? = 160.0)`——标题栏（加粗、底部分隔线）+ 边框，内容区从标题栏下方开始。

```moonbit
@yue.card("概要", [@yue.statistic("任务数", done)], height=120.0)
```

### 代码高亮 code_view

`code_view(lines, lang? = "moonbit", font_size? = 13.0, width? = 560.0, line_numbers? = false)`

逐 token 高亮排版，全平台行为一致（含 Windows）。lang 关键字集：moonbit / js / ts / python / rust / c / go / bash / sql（大小写不敏感）；line_numbers=true 左侧行号槽。

```moonbit
@yue.code_view(
  ["fn main() {", "  println(\"hello\")", "}"],
  lang="moonbit",
  line_numbers=true,
)
```

### Markdown 展示 markdown_view

`markdown_view(source, width? = 560.0)`——标题 1-6 / 段落 / **粗体** / *斜体* / `行内代码` / 链接文字 / 无序有序列表 / 引用（主题色竖条）/ 分隔线 / 围栏代码块（语言随 fence 标注，复用 code_view）；三平台显示一致，链接 / 代码色跟主题。

```moonbit
@yue.markdown_view("# 标题\n\n正文 **粗体** 与 `行内代码`。")
```

### 表格 table_t

`table_t(columns, rows : Store[Array[TableRow]], width? = 560.0, row_height? = 36.0, selection? : Store[Array[Int]], on_row_click?)`

表头 + 斑马纹 + 悬停底色 + Store 驱动（set 后整表重建并清空选择）。列用 `TableColumn::make(标题, 宽, align?)`（宽 ≤0 为弹性列均分剩余宽）。单元格 `TableCell`：`CellText` / `CellTag(文本, 语义类型)` / `CellColorBox(色值, 名)` / `CellLines(多行, 行自动撑高)`；`TableRow::make(字符串数组)` 建纯文本行。不传 `selection` 时行点击单选高亮；传 `selection` 启用复选框列（行点击勾选、表头全选 / 清空、部分选中画横条，选中行浅蓝底），回调收 `(行号, 行)`。

```moonbit
let rows = @yue.Store::new([@yue.TableRow::make(["甲", "1"]), @yue.TableRow::make(["乙", "2"])])
@yue.table_t(
  [@yue.TableColumn::make("名称", 120.0), @yue.TableColumn::make("数量", 80.0, align=@yue.Center)],
  rows,
)
```

### 虚拟滚动表格 table_v_t

`table_v_t(columns, rows : Store[Array[TableRow]], width? = 560.0, height? = 360.0, row_height? = 32.0, selection? : Store[Array[Int]], on_row_click?)`

table_t 的万行级形态：只画可见行，自管滚动（滚轮 / 拖拽滚动条 / 键盘），不受滚动容器内容高度上限约束；单元格画法同 table_t（CellLines 在行高内最多两行），列 / selection 语义一致。

```moonbit
let rows = @yue.Store::new([@yue.TableRow::make(["1", "甲"]), @yue.TableRow::make(["2", "乙"])])
@yue.table_v_t(
  [@yue.TableColumn::make("序号", 90.0), @yue.TableColumn::make("名称", 160.0)],
  rows,
  height=480.0,
)
```

### 树形控件 tree

`tree(root : Array[TreeNode])`——缩进层级 + 点击展开 / 折叠（有子节点时箭头指示）。节点 `TreeNode{ label : String, children : Array[TreeNode] }`。

```moonbit
@yue.tree([
  { label: "src", children: [{ label: "main.mbt", children: [] }] },
  { label: "README.md", children: [] },
])
```

### 穿梭框 transfer

`transfer(left_items : Store[Array[String]], right_items : Store[Array[String]], width? = 160.0)`——左右两列，点击行选中（实心方块标记），中间 ›/‹ 按钮把选中项在两列间移动；数据经双 Store 驱动。

```moonbit
let left = @yue.Store::new(["甲", "乙"])
let right = @yue.Store::new(["丙"])
@yue.transfer(left, right)
```

## 图表

图表族（EP Chart 对标）全部纯 MoonBit 自绘：数据经 `Store` 驱动，set 后只 schedule_paint 画布、不重建视图树；颜色在绘制时现取主题色板，`theme_apply` 切换深浅即跟随。序列色按主题四语义色循环（折线 ≤4 序列），环形图五色循环。

### 折线 / 面积图 line_chart_t

`line_chart_t(series : Store[Array[LineSeries]], width? = 560.0, height? = 260.0, area? = false, y_range?, show_last? = true)`

定长滚动窗口多序列折线。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| series | Store[Array[LineSeries]] | 必填 | 多序列数据，推点见下 |
| width / height | Double | 560 / 260 | 画布尺寸 |
| area | Bool | false | 半透明面积填充 |
| y_range | (Double, Double)? | None | 手动 y 值域；None 为自适应 |
| show_last | Bool | true | 最新值右端标注 |
`LineSeries::make(名称, max_points?)` 建序列（窗口容量默认 100，超出丢最旧）；推点用 `series_push(store, 序列序号, 值)`（或 `win_push(窗口, max_points, 值)` 换新窗口后整体 set）。y 轴自适应（窗口 min/max + 8% 留白）或经 `y_range = (下限, 上限)` 手动指定；横向网格 + 左侧刻度；`area = true` 半透明面积填充（值域含 0 填到零线，全正值填到绘制区底，全负值填到顶）；`show_last` 控制最新值右端标注。

渲染策略：点数多于绘制区像素列数时按列抽稀（每列保留 min/max 极值）改矩形路径——面积模式每列填到锚线（填充顶边即折线），折线模式每列画 min..max 竖条；点数不多于列数时走真实折线 + 多边形面积。单帧成本与窗口大小脱钩（1000 点 × 4 序列实测约 3ms，见 adaptation.md）。

```moonbit
let series = @yue.Store::new([
  @yue.LineSeries::make("CPU", max_points=120),
  @yue.LineSeries::make("内存", max_points=120),
])
ignore(@yue.set_timer(500, fn() {
  @yue.series_push(series, 0, cpu_usage())
  @yue.series_push(series, 1, mem_usage())
  true
}))
@yue.line_chart_t(series, width=380.0, height=220.0)
@yue.line_chart_t(series, width=380.0, height=220.0, area=true)
```

### 柱状 / 条形图 bar_chart_t

`bar_chart_t(data : Store[Array[BarItem]], width? = 560.0, height? = 280.0, horizontal? = false)`

纵向柱

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[Array[BarItem]] | 必填 | 类目数据（值可为负） |
| width / height | Double | 560 / 280 | 画布尺寸 |
| horizontal | Bool | false | 横向条形态 |
（默认）与横向条（`horizontal = true`，适配长类目名）两形态。`BarItem::make(标签, 值)`，值可为负；以 0 为基线，正主题色、负红色。悬停高亮该类目并在行内标注数值（自绘，无弹层）；类目标签过密时自动抽稀截断。200 类目全量重绘实测约 0.4ms。

```moonbit
let bars = @yue.Store::new([
  @yue.BarItem::make("1月", 12.0),
  @yue.BarItem::make("2月", -8.0),
])
@yue.bar_chart_t(bars, width=380.0, height=220.0)
@yue.bar_chart_t(bars, width=380.0, height=220.0, horizontal=true)
```

### 环形 / 饼图 donut_chart_t

`donut_chart_t(data : Store[Array[DonutSlice]], width? = 480.0, height? = 240.0, thickness? = 34.0, center? = "")`

占比扇区

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[Array[DonutSlice]] | 必填 | 扇区数据（负值不计占比） |
| width / height | Double | 480 / 240 | 画布尺寸 |
| thickness | Double | 34 | 环厚（0 为实心饼） |
| center | String | "" | 中心文案，空为汇总值 |
（12 点方向起顺时针，五色循环，相邻扇区不同色）；中心汇总数值（默认总和，`center` 非空时改用该文案）；右侧图例（色块 + 标签 + 值与百分比）。悬停扇区外扩 4px，图例行同步高亮。`DonutSlice::make(标签, 值)`，负值不计入占比。50 扇区重绘实测约 2.9ms。

```moonbit
let slices = @yue.Store::new([
  @yue.DonutSlice::make("直接访问", 335.0),
  @yue.DonutSlice::make("搜索引擎", 510.0),
])
@yue.donut_chart_t(slices, width=420.0, height=220.0)
```

### 仪表盘 gauge_t

`gauge_t(value : Store[Double], width? = 240.0, height? = 170.0, thresholds?)`

单值百分比环

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| value | Store[Double] | 必填 | 0..1，超出钳制 |
| width / height | Double | 240 / 170 | 画布尺寸 |
| thresholds | Array[(Double, String)] | [] | 升序（阈值上限, 颜色）分段着色；空表用主题主色 |
（135° 起扫 270°，开口朝下）+ 中心大数字。`value` 取 0..1（超出钳制）；`thresholds` 为升序的 `[(阈值上限, 颜色), ...]`，值弧按落入分段着色（空表用主题主色），如 `[(0.6, 绿), (0.85, 橙), (1.0, 红)]`。数值插值平滑：目标值变化后经 16ms 定时器每帧补 25% 差值逐步逼近（非动画帧驱动），2Hz 更新无跳变。

```moonbit
let usage = @yue.Store::new(0.0)
@yue.gauge_t(usage, thresholds=[
  (0.6, @yue.theme_current().success),
  (0.85, @yue.theme_current().warning),
  (1.0, @yue.theme_current().danger),
])
```

### 散点图 scatter_t

`scatter_t(points : Store[Array[(Double, Double)]>, width? = 560.0, height? = 320.0, trend? = false, dot? = 3.0)`

x/y 点列

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| points | Store[Array[(Double, Double)]] | 必填 | (x, y) 点列 |
| width / height | Double | 560 / 320 | 画布尺寸 |
| trend | Bool | false | 最小二乘趋势线 |
| dot | Double | 3 | 点边长（px） |
（小方点），双轴自适应刻度 + 网格；`trend = true` 叠加最小二乘趋势线（红色）。10000 点首绘实测约 3ms。框选缩放后置，未做。

```moonbit
let pts = @yue.Store::new([(0.0, 1.0), (1.0, 3.0), (2.0, 5.0)])
@yue.scatter_t(pts, trend=true)
```

## 图标

内置矢量图标 136 种（箭头 / 文件 / 编辑 / 视图 / 导航 / 媒体 / 通信 / 系统 / 开发 / 数据 / 状态，风格对齐 Tabler / Lucide）。

| API | 用途 |
|---|---|
| `icon(kind : IconKind, size? = 16.0, color? = "")` | 图标节点：默认主题常规色，传 color 固定色 |
| `icon_button_t(kind, on_click?, size? = 28.0, tip? = "")` | 方形图标按钮：hover 浅灰底 + 文字色提亮，Enter/Space 触发；tip 非空挂原生悬浮提示；marginRight 6 便于工具栏排列 |
| `draw_icon(p : Painter, kind, cx, cy, s, color)` | 统一自绘入口（中心坐标 + 边长） |
| `all_icons()` / `icon_name(kind)` | 全清单 / 取名 |

```moonbit
@yue.icon(@yue.Search, size=18.0)
@yue.icon_button_t(@yue.Plus, on_click=fn() { add_row() }, tip="新增一行")

// 自绘入口(在 on_draw 回调里):
@yue.draw_icon(p, @yue.Star, 24.0, 24.0, 16.0, "#D9822B")
```

## 反馈

### 提示横幅 alert / alert_closeable

`alert(text, t : SemanticType, height? = 40.0)` / `alert_closeable(text, t)`

类型浅底 + 左侧 4px 色条 + 同族深字，全宽；后者右侧带关闭钮，点击整条隐藏。

```moonbit
@yue.alert("保存成功", @yue.Success)
@yue.alert_closeable("有新版本可用", @yue.Info)
```

### 结果页 result

`result(t, title, desc, children : Array[Node])`——大色块符号 + 标题 + 描述 + 自定义按钮区。

```moonbit
@yue.result(@yue.Success, "提交完成", "结果将于 1 个工作日内反馈", [@yue.button_t("好的")])
```

### 空状态 empty

`empty(desc)`——灰块占位 + 居中说明。

```moonbit
@yue.empty("暂无数据")
```

### 对话框 dialog_t

`dialog_t(visible : Store[Bool], title, children : Array[Node], width? = 420.0, confirm_text? = "确定", cancel_text? = "取消", on_confirm?, on_cancel?, close_on_mask? = false)`

应用内对话框：同窗遮罩（半透明黑，absolute 相对挂载容器——挂窗口根即盖全窗）+ 居中面板（标题栏 ✕ + 内容 + 右对齐按钮区）。visible 驱动弹 / 收；✕ / 取消 / 确定触发回调后自动收起，文案传空串隐藏该按钮（两个都空则整行不显示），close_on_mask=true 时点遮罩空白处也收起。视觉模态，非键盘强模态。

```moonbit
let show = @yue.Store::new(false)
@yue.dialog_t(show, "删除确认", [@yue.label_t("删除后不可恢复，确定吗？")],
  confirm_text="删除", on_confirm=fn() { remove() }, close_on_mask=true)
```

### 轻提示 toast_layer

`toast_layer(duration_ms? = 2600) -> (Node, (String, SemanticType) -> Unit)`

层节点挂窗口根（absolute 顶部，不占布局），推送函数弹语义提示条（面板底 + 边框 + 类型图标），默认 2.6s 自动移除，多条自上而下堆叠；须在层 mount 后调用。

```moonbit
let (layer, toast) = @yue.toast_layer()
// 把 layer 挂到窗口根之后:
toast("已保存", @yue.Success)
```

### 右键菜单 context_menu_for

`context_menu_for(content : Node, items : Array[(String, () -> Unit)])`——给任意节点包原生右键菜单，文案 "-" 画分隔线；弹出位置经 `bounds_in_screen` 换算屏幕坐标，每次右键现建菜单。

```moonbit
@yue.context_menu_for(row_view, [("复制", fn() { copy() }), ("-", fn() {}), ("删除", fn() { remove() })])
```

## 浮层

### 悬浮提示 tooltip_t

`tooltip_t(content : Node, tip)`——给任意节点包原生 tooltip（系统样式，零成本；主题化气泡请用 popover_t）。Linux 端 tooltip 颜色已接管为恒深底白字（不随系统主题）。

```moonbit
@yue.tooltip_t(@yue.button_t("删除"), "删除该项")
```

### 气泡弹层 popover_t

`popover_t(trigger : Node, content : Node, width, height)`——trigger 点击后在自身下方弹出任意 Node 内容，再次点击切换收起。

```moonbit
@yue.popover_t(@yue.button_t("更多"), filter_panel, 240.0, 160.0)
```

### 下拉菜单 dropdown_menu

`dropdown_menu(trigger : String, items, on_select : (Int) -> Unit, width? = 160.0)`——触发文字 + 下拉箭头，点击弹菜单项列表：悬停高亮，点击回调序号并收起；items 中 `"-"` 画分隔线。

```moonbit
@yue.dropdown_menu("操作", ["编辑", "-", "删除"], fn(i) { handle(i) })
```

### 轮播 carousel_t

`carousel_t(pages : Array[Node], width? = 360.0, height? = 180.0, interval_ms? = 3000)`——面板序列 + 左右箭头 + 底部指示点；interval_ms > 0 时每 interval 毫秒自动切换（悬停暂停），点击箭头 / 指示点手动切换。

```moonbit
@yue.carousel_t([banner1, banner2], interval_ms=4000)
```

组件间状态协调统一走 `Store`（subscribe / map / bind_label）或信号 `Signal`（computed 自动依赖收集，batch 批处理；组件 Store 参数可传 `sig.store()` 视图），见 [declarative.md](declarative.md)。English version: [components-ui.md](../components-ui.md).
