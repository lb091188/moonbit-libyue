# 主题组件库速查

主题组件库速查：Element Plus 风格的成套界面组件（按钮 / 输入 / 选择 / 表单 / 导航 / 布局 / 数据展示 / 图标 / 反馈 / 浮层），全部经 `@yue` 调用、返回 `Node` 直接进界面树。签名中带 `?` 的可选参数必须具名传值（如 `date_picker_t(value=day)`），不带 `?` 的位置参数按序传。响应式 `Store` / `Signal` 参数见 [declarative.md](declarative.md)；原生控件（Window / Label / Button / Entry 等）见 [components.md](components.md)。

完整演示见 `examples/showcase`。

## 主题

全部颜色来自主题色板——深色低饱和配色：蓝 `#2D68C4`、绿 `#2E9E5B`、橙 `#D9822B`、红 `#D64550`，以及文字 / 边框 / 填充灰阶。组件一律直角，hover/active 用背景色表达，文字垂直居中。表单控件统一高度 32px（`control_height`），按钮 / 输入框 / 下拉 / 数字器 / 日期与颜色选择字段混排成行时基线对齐。表单控件统一高度 32px（`control_height`），按钮 / 输入框 / 下拉 / 数字器 / 日期与颜色选择字段混排成行时基线对齐。

### 切换与定制

| API | 用途 |
|---|---|
| `default_theme()` / `dark_theme()` | 内置浅色 / 暗色主题，返回 `Theme` |
| `theme_current()` | 读当前主题快照 |
| `theme_apply(t)` | 应用主题：切换即时生效、无需重建界面（Linux 端原生控件样式一并重建） |
| `on_theme_change(f)` | 订阅主题变更（组件挂载时注册，常驻界面重设定死色用） |
| `system_prefers_dark()` | 读系统深浅偏好（当前仅 Linux 有实现） |
| `on_system_theme_change(f)` | 系统偏好切换时回调（当前仅 Linux 有实现） |
| `system_accent()` | 读系统主色调（强调色）hex，无主色概念时为空串 |
| `theme_from_accent(accent, dark?)` | 由单个主色按公式派生整套色板，返回 `Theme` |
| `theme_from_system()` | 深浅 + 主色全部跟随系统，返回 `Theme` |

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

跟随系统：`theme_from_system()` 一次拿到「深浅 + 主色」全部跟随系统的主题（无主色概念的桌面回落内置 primary），`on_system_theme_change` 回调里重算并重新 `theme_apply` 即可实时跟随。焦点环与字段聚焦边框为中性灰单层描亮（不用主题色）。

```moonbit
@yue.theme_apply(@yue.theme_from_system())
@yue.on_system_theme_change(fn() {
  @yue.theme_apply(@yue.theme_from_system())
})
```

### 主色公式派生与系统主色

只有一个主色时不必手调整套色板：`theme_from_accent(accent, dark?)` 按 HSL 公式即时派生——主色保色相、按深浅模式钳制明度（浅 0.34..0.52 / 深 0.55..0.72）与最低饱和度保证可读；`primary_hover` 明度 ∓8%，`primary_light` 向面板底混色（Soft 按钮底即此）；语义色（success/warning/danger/info）取固定色相轮 142/36/4/210，饱和度假借主色、明度随深浅；中性色（文字 / 边框 / 填充 / 背景）取内置基准盘不随主色偏移。

`system_accent()` 读系统主色调：Linux 三级递进（GNOME 47+ 强调色设置 → 当前 GTK 主题 CSS 的选中底色 → 空串），Windows 取 DWM 颜色化颜色，macOS 取 `controlAccentColor`；读取路径与实测值见 [adaptation.md](adaptation.md)。

```moonbit
// 点选主色即时换肤,深浅切换沿用当前主色
let accent = @yue.Store::new("")
@yue.theme_apply(@yue.theme_from_accent(accent.get(), dark=@yue.system_prefers_dark()))
accent.subscribe(fn(a) {
  @yue.theme_apply(@yue.theme_from_accent(a, dark=@yue.system_prefers_dark()))
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

### 统一 style 通道

主题组件库全部组件的最外层容器都带 `style?`（样式键值对，数值与字符串混装，键表见 [layout.md](layout.md)）与 `handle?`（挂载时收到最外层容器句柄）参数。组件默认尺寸 / 边距 / 方向已进默认样式表，调用方 `style` 键后应用、可覆盖默认值：

```moonbit
// 覆盖宽度与外边距(默认值其余保持)
@yue.input_t(text="姓名", style=[("width", 160.0), ("marginBottom", 4.0)])
// slider 默认横向自适应;定宽需同时取消 grow
@yue.slider_t(v, style=[("flexgrow", 0.0), ("width", 240.0)])
```

布局定制唯一入口是 `style`——组件签名不再保留 margin / width / height / spacing 之类布局命名参数。仍以命名参数保留的是语义 / 结构参数：`avatar` / `icon` 的 `size`（图形内容尺寸）、`table_t` 的 `width`（列宽均分基准）与 `row_height`、`popover_t` 的 `width` / `height`（原生弹层窗口尺寸，不走布局）、`transfer` 的 `width`（栏宽）、`hsplit` / `vsplit` 的 `ratio`（拖动几何）、各数据/交互参数（min/max/step/placeholder/clearable/foldable 等）。

`style` 为挂载期一次性应用；颜色定制优先走主题色板，经 `style` 设的颜色可能与主题切换（`theme_apply`）的取色语义冲突。

```moonbit
let l = @yue.Label::make("标题")
@yue.theme_bind_fg(l, fn() { @yue.theme_current().text_regular })
let panel = @yue.Container::make()
@yue.theme_bind_bg(panel, fn() { @yue.theme_current().bg_panel })
```

## 按钮与文本

### 主题按钮 button_t

`button_t(text, on_click?, variant? = Soft, color? = "", background_color? = "", style?, handle?)`

自绘按钮，hover 变化收敛在主题色板内。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | 必填 | 按钮文本 |
| on_click | () -> Unit | 空操作 | 点击回调 |
| variant | ButtonVariant | `Soft` | `Solid` 实底白字 / `Soft` 浅底 / `Text` 无底 / `Danger` 危险色 |
| color | String | `""` | 文字色覆盖：非空即所有状态用它（hover 不再变色） |
| background_color | String | `""` | 底色覆盖：非空即所有状态用它（hover 不再变色） |

hover 表现：Solid / Danger 加深，Soft 变实底白字，Text 浅灰底；传了 color / background_color 后以传入色为准，hover 不再变色。

```moonbit
@yue.button_t("确定", on_click=fn() { submit() })
@yue.button_t("删除", variant=@yue.Danger)
@yue.button_t("自定义", color="#ffd700", background_color="#1a1a2e")
```

### 主题标签 label_t

`label_t(text, role? = Body, style?, handle?)`

文字角色统一字号 / 颜色，左对齐；可叠加布局样式与句柄回调。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | 必填 | 文本 |
| role | TextRole | `Body` | `Title` / `Section` / `Body` / `Secondary` / `Accent` |
| style | 样式键值对（数值+字符串混装） | `[]` | 见 [layout.md](layout.md) |
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

`entry_t(text? = "", password? = false, on_input?, style?, handle?)`

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

`input_t(text? = "", password? = false, clearable? = false, on_input?, invalid? = Store::new(false), style?, handle?)`

外层自绘 1px 边框（聚焦变主题色）+ 白底，直角。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| margin / width / height | Double | 0 / 280 / 32 | 外边距与尺寸,经 `style` 传入 |
| clearable | Bool | false | 悬停且非空时右侧显示 ✕，点击清空 |
| invalid | Store[Bool] | false | true 时边框变 danger 红（轻量表单校验），set 即生效 |

```moonbit
let valid = @yue.Store::new(false)
@yue.input_t(text="admin", clearable=true, invalid=valid, on_input=fn(s) { check(s) })
```

### 数字输入器 input_number

`input_number(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, num_width? = 64.0, style?, handle?)`

-/+ 按钮步进，范围钳制，状态存 `Store[Double]`。

```moonbit
let count = @yue.Store::new(1.0)
@yue.input_number(count, min=1.0, max=10.0)
```

### 多行输入 textarea_t

`textarea_t(text? = "", on_input?, clearable? = false, invalid? = Store::new(false), style?, handle?)`

input_t 同套路：外层自绘 1px 边框（聚焦变主题色）+ 8px 内边距；内容超出自行滚动。clearable / invalid 语义同 input_t。

```moonbit
@yue.textarea_t(text="第一行\n第二行", style=[("width", 320.0), ("height", 120.0)])
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

`slider_t(value : Store[Double], min? = 0.0, max? = 100.0, step? = 1.0, on_change?, style?, handle?)`

自绘：浅灰轨道 + 主题色填充段 + 方形 thumb，点击轨道 / 拖拽 thumb 调值，值按 step 量化后写入 `value`（外部 set 同样生效）；on_change 含拖拽过程。

```moonbit
let volume = @yue.Store::new(0.5)
@yue.slider_t(volume, max=1.0, step=0.1, on_change=fn(v) { set_volume(v) })
```

## 选择

### 下拉选择 select_t

`select_t(options, value : Store[String], on_change?, clearable? = false, style?)`

全自绘：点击弹候选列表，悬停高亮、当前选中主题色 ✓，点选回填并收起，失焦收起，三平台同形态。clearable=true 时悬停且有值，箭头左侧 ✕ 点击清空（value 置空串、`on_change("")`）。

```moonbit
let color = @yue.Store::new("红")
@yue.select_t(["红", "绿", "蓝"], color, clearable=true, on_change=fn(s) { recolor(s) })
```

### 日期选择器 date_picker_t

`date_picker_t(value? : Store[DateYMD?], on_change?, placeholder? = "请选择日期", clearable? = false, style?)`

全自绘：输入框样式字段，点击弹出 `calendar_t` 月历面板，点选回填并收起，失焦收起；clearable=true 时悬停且有值，箭头旁 ✕ 清空（不触发 on_change）。

```moonbit
let day : @yue.Store[@yue.DateYMD?] = @yue.Store::new(None)
@yue.date_picker_t(value=day, on_change=fn(d) { picked(d) })
```

### 日期区间选择器 date_range_picker_t

`date_range_picker_t(value? : Store[DateRange], on_change?, placeholder? = "请选择日期区间", clearable? = false, style?)`

字段显示「起 ~ 止」，点击弹区间日历：第一次点选起点，第二次点选终点（终点早于起点自动对调）后收起并回调 `on_change(起, 止)`；中间日期浅主题色底，端点实心方块；再点字段重新开始新区间。clearable 清空两端。

```moonbit
let range : @yue.Store[@yue.DateRange] = @yue.Store::new({ start: None, end: None })
@yue.date_range_picker_t(value=range, on_change=fn(s, e) { show(s, e) })
```

### 时间区间选择器 time_range_picker_t

`time_range_picker_t(value? : Store[TimeRange], on_change?, placeholder? = "请选择时间区间", clearable? = false, style?)`

字段显示「起 : 止」时 : 分，点击弹起 / 止两行步进编辑器（时 0-23 / 分 0-59，`input_number` 承载），步进即改即回调 `on_change(起, 止)`；起止默认 00:00，弹层随字段失焦收起。

```moonbit
let tr : @yue.Store[@yue.TimeRange] = @yue.Store::new({ start: None, end: None })
@yue.time_range_picker_t(value=tr, on_change=fn(s, e) { show(s, e) })
```

### 日期时间区间选择器 datetime_range_picker_t

`datetime_range_picker_t(value? : Store[DateTimeRange], on_change?, placeholder? = "请选择日期时间区间", clearable? = false, style?)`

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

`color_picker_t(value : Store[String], colors?, style?)`

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

`side_menu(items, selected : Store[String], icons? = [], style?)`

hover 浅灰、选中主题浅蓝底 + 主题色文字 + 左侧 3px 强调条，4px 圆角。`icons` 给「项文本 → 图标」（缺省不画）；`selected` 为共享状态，主区页面订阅同一 Store 做 `set_visible` 联动。

```moonbit
let page = @yue.Store::new("首页")
@yue.side_menu(["首页", "设置", "关于"], page)
```

### 分组侧边菜单 side_menu_sections

`side_menu_sections(sections : Array[(String, Array[String])], selected : Store[String], icons? = [], foldable? = true, style?, handle?)`

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

`divider(vertical? = false, style?, handle?)`——水平（默认，高 1px 宽 flex）或竖直（宽 1px 高随父容器），两侧留白默认 10px、经 style 覆盖。底色挂载时读主题，重建界面生效。

```moonbit
@yue.divider(style=[("marginTop", 16.0), ("marginBottom", 16.0)])
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

`tag(text, color, style?, handle?)` / `tag_of_type(text, t : SemanticType, style?, handle?)`

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

`progress_line(value : Store[Double], style?, handle?)`——背景浅灰轨道 + 主题色填充（条高默认 8、经 style 覆盖），value 取值 0..1，变化自动重绘。

```moonbit
let ratio = @yue.Store::new(0.42)
@yue.progress_line(ratio, style=[("height", 6.0)])
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

`card(title, children : Array[Node], style?, handle?)`——标题栏（加粗、底部分隔线）+ 边框（卡高默认 160、经 style 覆盖），内容区从标题栏下方开始。

```moonbit
@yue.card("概要", [@yue.statistic("任务数", done)], style=[("height", 120.0)])
```

### 代码高亮 code_view

`code_view(lines, lang? = "moonbit", font_size? = 13.0, line_numbers? = false, style?, handle?)`

逐 token 高亮排版，全平台行为一致（含 Windows）。着色分类：关键字紫 / 类型与大写开头构造器黄 / 后随 `(` 的调用蓝 / 数字橙 / 字符串绿 / 行注释灰；标点与运算符独立断词（`items.push(`、`0..<` 各自正确着色）。lang 关键字集：moonbit / js / ts / python / rust / c / go / bash / sql（大小写不敏感）；line_numbers=true 左侧行号槽。

```moonbit
@yue.code_view(
  ["fn main() {", "  println(\"hello\")", "}"],
  lang="moonbit",
  line_numbers=true,
)
```

### Markdown 展示 markdown_view

`markdown_view(source, style?)`——标题 1-6（ATX/Setext）/ 段落 / **粗体** / *斜体* / ~~删除线~~（区间自画横线）/ `行内代码` / [链接](url)（点击经默认浏览器打开，悬浮手型光标 + 地址提示；引用式链接取文档级链接定义）/ 自动链接 / 无序有序列表（带 start）/ 任务列表（真复选框，点击可勾选）/ 引用（主题色竖条）/ GFM 提示块 / 分隔线 / 围栏与缩进代码块（语言随 fence 标注，复用 code_view）/ 表格（等分列宽网格，单元格富文本，列对齐随 `:---` `:---:` `---:` 标注）/ 定义列表 / 脚注（正文上标引用按出现顺序编号，文末分隔线后渲染被引用的定义）/ 块级图片（本地路径或 `file://` 加载显示，等比缩放、宽度上限 560；加载失败或网络地址降级 alt 文本，行内图片降级 alt）；emoji 等非 BMP 字符后样式区间按 UTF-16 计量不错位；行内 HTML 与 HTML 块默认不渲染；三平台显示一致，链接 / 代码色跟主题。

```moonbit
@yue.markdown_view("# 标题\n\n正文 **粗体**、~~删除线~~ 与 [链接](https://libyue.com)。\n\n- [x] 任务项\n\n| 列甲 | 列乙 |\n|:--|--:|\n| 1 | 2 |\n\n脚注引用[^1]。\n\n[^1]: 脚注定义。")
```

### 表格 table_t

`table_t(columns, rows : Store[Array[TableRow]], width? = 560.0, row_height? = 36.0, selection? : Store[Array[Int]], sort? : Store[TableSort], on_row_click?, style?, handle?)`

表头 + 斑马纹 + 悬停底色 + Store 驱动（set 后整表重建并清空选择）。列用 `TableColumn::make(标题, 宽, align?, sortable?)`（宽 ≤0 为弹性列均分剩余宽；`sortable=false` 的列不参与表头排序）。单元格 `TableCell`：`CellText`（超宽单行省略号截断，拖列宽后按新宽度重截）/ `CellTag(文本, 语义类型)` / `CellColorBox(色值, 名)` / `CellLines(多行, 行自动撑高)`；`TableRow::make(字符串数组)` 建纯文本行。不传 `selection` 时行点击单选高亮；传 `selection` 启用复选框列（行点击勾选、表头全选 / 清空、部分选中画横条，选中行浅蓝底），回调收 `(行号, 行)`。

表头排序与列宽：传 `sort`（`Store[TableSort]`，`TableSort{ column, asc }`，`column` 为列定义下标、<0 表示不排序）后，可排序列表头右侧常驻灰色 ↕ 双三角提示可点排序；点击三态循环「新列默认升序 → 同列翻转降序 → 再击取消排序」，当前排序列换主题色实心 ▲ / ▼（排序状态一眼可辨），取消后 `column` 置 -1、使用方订阅里恢复原始顺序；数据排序由使用方订阅该 Store 自行完成后回写 `rows`。表头列边界线常驻浅色，悬停 / 拖动变主题色——拖动位置一眼可辨；按住任一列左缘或右缘 4px 调整列宽（末列右缘不设把手），相邻两列此消彼长（最小 56px），拖动经鼠标捕获不丢事件，行不重建、选择不丢。

```moonbit
let rows = @yue.Store::new([@yue.TableRow::make(["甲", "1"]), @yue.TableRow::make(["乙", "2"])])
let sort = @yue.Store::new(@yue.TableSort::{ column: -1, asc: true })
sort.subscribe(fn(st) { /* 按 st.column / st.asc 重排后 rows.set(...) */ })
@yue.table_t(
  [@yue.TableColumn::make("名称", 120.0), @yue.TableColumn::make("数量", 80.0, align=@yue.Center)],
  rows,
  sort=sort,
)
```

### 虚拟滚动表格 table_v_t

`table_v_t(columns, rows : Store[Array[TableRow]], width? = 560.0, height? = 360.0, row_height? = 32.0, selection? : Store[Array[Int]], sort? : Store[TableSort], on_row_click?, fill? = false, style?, handle?)`

table_t 的万行级形态：只画可见行，自管滚动（滚轮 / 拖拽滚动条 / 键盘），不受滚动容器内容高度上限约束；单元格画法同 table_t（CellLines 在行高内最多两行），列 / selection / sort（表头箭头：常驻灰 ↕ 提示、排序列主题色 ▲▼）/ 列宽拖动（左 / 右缘双向边界）语义一致。

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

`line_chart_t(series : Store[Array[LineSeries]], area? = false, y_range?, show_last? = true, fill? = false, style?, handle?)`

定长滚动窗口多序列折线。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| series | Store[Array[LineSeries]] | 必填 | 多序列数据，推点见下 |
| width / height | Double | 560 / 260 | 画布尺寸,经 `style` 传入 |
| area | Bool | false | 半透明面积填充 |
| y_range | (Double, Double)? | None | 手动 y 值域；None 为自适应 |
| show_last | Bool | true | 最新值右端标注 |
`LineSeries::make(名称, max_points?)` 建序列（窗口容量默认 100，超出丢最旧）；推点用 `series_push(store, 序列序号, 值)`（或 `win_push(窗口, max_points, 值)` 换新窗口后整体 set）。y 轴自适应（窗口 min/max + 8% 留白）或经 `y_range = (下限, 上限)` 手动指定；横向网格 + 左侧刻度；`area = true` 半透明面积填充（值域含 0 填到零线，全正值填到绘制区底，全负值填到顶）；`show_last` 控制最新值右端标注。

渲染策略：点数多于绘制区像素列数时按列抽稀（每列保留 min/max 极值）改矩形路径——面积模式每列填到锚线（填充顶边即折线），折线模式每列画 min..max 竖条；点数不多于列数时走真实折线 + 多边形面积。单帧成本与窗口大小脱钩（1000 点 × 4 序列实测约 3ms，见 adaptation.md）。

```moonbit
let series = @yue.Store::new([
  @charts.LineSeries::make("CPU", max_points=120),
  @charts.LineSeries::make("内存", max_points=120),
])
ignore(@yue.set_timer(500, fn() {
  @charts.series_push(series, 0, cpu_usage())
  @charts.series_push(series, 1, mem_usage())
  true
}))
@charts.line_chart_t(series, style=[("width", 380.0), ("height", 220.0)])
@charts.line_chart_t(series, style=[("width", 380.0), ("height", 220.0)], area=true)
```

### 柱状 / 条形图 bar_chart_t

`bar_chart_t(data : Store[Array[BarItem]], horizontal? = false, y_range? = None, fill? = false, style?, handle?)`

纵向柱

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[Array[BarItem]] | 必填 | 类目数据（值可为负） |
| width / height | Double | 560 / 280 | 画布尺寸,经 `style` 传入 |
| horizontal | Bool | false | 横向条形态 |
| y_range | (Double, Double)? | None | 手动值域；缺省按数据自适应（含 0 基线 + 6% 留白） |
（默认）与横向条（`horizontal = true`，适配长类目名）两形态。`BarItem::make(标签, 值)`，值可为负；以 0 为基线，正主题色、负红色。悬停高亮该类目并在行内标注数值（自绘，无弹层）；类目标签过密时自动抽稀截断。200 类目全量重绘实测约 0.4ms。

```moonbit
let bars = @yue.Store::new([
  @charts.BarItem::make("1月", 12.0),
  @charts.BarItem::make("2月", -8.0),
])
@charts.bar_chart_t(bars, style=[("width", 380.0), ("height", 220.0)])
@charts.bar_chart_t(bars, style=[("width", 380.0), ("height", 220.0)], horizontal=true)
```

### 环形 / 饼图 donut_chart_t

`donut_chart_t(data : Store[Array[DonutSlice]], thickness? = 34.0, center? = "", style?, handle?)`

占比扇区

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[Array[DonutSlice]] | 必填 | 扇区数据（负值不计占比） |
| width / height | Double | 480 / 240 | 画布尺寸,经 `style` 传入 |
| thickness | Double | 34 | 环厚（0 为实心饼） |
| center | String | "" | 中心文案，空为汇总值 |
（12 点方向起顺时针，五色循环，相邻扇区不同色）；中心汇总数值（默认总和，`center` 非空时改用该文案）；右侧图例（色块 + 标签 + 值与百分比）。悬停扇区外扩 4px，图例行同步高亮。`DonutSlice::make(标签, 值)`，负值不计入占比。50 扇区重绘实测约 2.9ms。

```moonbit
let slices = @yue.Store::new([
  @charts.DonutSlice::make("直接访问", 335.0),
  @charts.DonutSlice::make("搜索引擎", 510.0),
])
@charts.donut_chart_t(slices, style=[("width", 420.0), ("height", 220.0)])
```

### 仪表盘 gauge_t

`gauge_t(value : Store[Double], thresholds?, style?, handle?)`

单值百分比环

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| value | Store[Double] | 必填 | 0..1，超出钳制 |
| width / height | Double | 240 / 170 | 画布尺寸,经 `style` 传入 |
| thresholds | Array[(Double, String)] | [] | 升序（阈值上限, 颜色）分段着色；空表用主题主色 |
（135° 起扫 270°，开口朝下）+ 中心大数字。`value` 取 0..1（超出钳制）；`thresholds` 为升序的 `[(阈值上限, 颜色), ...]`，值弧按落入分段着色（空表用主题主色），如 `[(0.6, 绿), (0.85, 橙), (1.0, 红)]`。数值插值平滑：目标值变化后经 16ms 定时器每帧补 25% 差值逐步逼近（非动画帧驱动），2Hz 更新无跳变。

```moonbit
let usage = @yue.Store::new(0.0)
@charts.gauge_t(usage, thresholds=[
  (0.6, @yue.theme_current().success),
  (0.85, @yue.theme_current().warning),
  (1.0, @yue.theme_current().danger),
])
```

### 散点图 scatter_t

`scatter_t(points : Store[Array[(Double, Double)]>, trend? = false, dot? = 3.0, style?, handle?)`

x/y 点列

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| points | Store[Array[(Double, Double)]] | 必填 | (x, y) 点列 |
| width / height | Double | 560 / 320 | 画布尺寸,经 `style` 传入 |
| trend | Bool | false | 最小二乘趋势线 |
| dot | Double | 3 | 点边长（px） |
（小方点），双轴自适应刻度 + 网格；`trend = true` 叠加最小二乘趋势线（红色）。10000 点首绘实测约 3ms。框选缩放后置，未做。

```moonbit
let pts = @yue.Store::new([(0.0, 1.0), (1.0, 3.0), (2.0, 5.0)])
@charts.scatter_t(pts, trend=true)
```

以下六个扩展图表与上述同渲染模型（Store 驱动、只重绘画布、主题切换跟随），完整演示见 `examples/systemprobe`。其后九个层级 / 地理 / 力导向 / 时间流图表与图表交互层为后续批次，同样纯 MoonBit 自绘、Store 驱动。

### 雷达图 radar_chart_t

`radar_chart_t(indicators : Store[Array[RadarIndicator]], series : Store[Array[RadarSeries]], rings? = 4, show_legend? = true, fill? = false, style?, handle?)`

多维数据对比：N 边形同心网格 + 轴线 + 维度标签，每系列一个半透明填充多边形并描边（多系列叠加）。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| indicators | Store[Array[RadarIndicator]] | 必填 | 维度定义，`RadarIndicator::make(名称, 最大值)`，量程 0..max |
| series | Store[Array[RadarSeries]] | 必填 | `RadarSeries::make(名称, 各维取值)`，与 indicators 同序 |
| width / height | Double | 460 / 340 | 画布尺寸,经 `style` 传入 |
| rings | Int | 4 | 同心网格层数 |
| show_legend | Bool | true | 右侧图例列（色块 + 系列名） |

系列色按主题四语义色循环；维度取值超出量程钳制、缺失按 0（折到中心），量程 max ≤ 0 的维度恒为 0；维度数 < 3 时画「暂无数据」占位。顶点 0 在 12 点方向、顺时针均布。

```moonbit
let ind : @yue.Store[Array[@charts.RadarIndicator]] = @yue.Store::new([
  @charts.RadarIndicator::make("渲染", 100.0),
  @charts.RadarIndicator::make("IO", 100.0),
  @charts.RadarIndicator::make("内存", 100.0),
])
let ser : @yue.Store[Array[@charts.RadarSeries]] = @yue.Store::new([
  @charts.RadarSeries::make("本方案", [88.0, 72.0, 80.0]),
  @charts.RadarSeries::make("对照", [70.0, 90.0, 65.0]),
])
@charts.radar_chart_t(ind, ser, rings=5, style=[("width", 420.0), ("height", 320.0)])
```

### 热力图 heatmap_t

`heatmap_t(data : Store[HeatGrid], low_color? = "", high_color? = "", gap? = 2.0, show_values? = false, fill? = false, style?, handle?)`

二维数值矩阵逐格着色：低值取色带起点、高值取终点，线性映射。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[HeatGrid] | 必填 | `HeatGrid::make(列标签, 行标签, 行×列矩阵)`（外层行、内层列） |
| width / height | Double | 480 / 300 | 画布尺寸,经 `style` 传入 |
| low_color / high_color | String | 跟随主题 | 色带起止色（"#RRGGBB"），空串 = 主题浅主色 → 主色 |
| gap | Double | 2 | 格间距（px） |
| show_values | Bool | false | 格内居中标注数值（格子宽 ≥30 且高 ≥14 才画） |

量程自动取矩阵实际 min/max（两端必被数据命中，不加留白）；全部同值时整表取色带中点色。行标签居左、列标签居底，过密自动抽稀截断；空矩阵画「暂无数据」。

```moonbit
let heat : @yue.Store[@charts.HeatGrid] = @yue.Store::new(
  @charts.HeatGrid::make(
    ["周一", "周二", "周三"],
    ["上午", "下午"],
    [[3.0, 5.0, 7.0], [6.0, 8.0, 9.0]],
  ),
)
@charts.heatmap_t(heat, show_values=true, style=[("width", 420.0), ("height", 280.0)])
@charts.heatmap_t(heat, low_color="#E3EDFA", high_color="#1E4FA3", gap=1.0)
```

### K 线图 candlestick_t

`candlestick_t(candles : Store[Array[Candle]], y_range? = None, up_color? = "", down_color? = "", fill? = false, style?, handle?)`

蜡烛图：影线（high-low 竖线）+ 实体（open-close 矩形），x 等距排布。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| candles | Store[Array[Candle]] | 必填 | `Candle::make(open, high, low, close)` |
| width / height | Double | 560 / 280 | 画布尺寸,经 `style` 传入 |
| y_range | (Double, Double)? | 自适应 | 手动值域；缺省取全体 low/high + 8% 留白 |
| up_color / down_color | String | 主题色 | 涨 / 跌颜色（"#RRGGBB"），空串回主题 danger / success |

涨跌判定 close ≥ open 记涨（平盘归涨）；默认涨红跌绿（中国习惯配色）；平盘实体高度钳 1px 保持可见。横向网格 + 左侧刻度。

```moonbit
let candles : @yue.Store[Array[@charts.Candle]] = @yue.Store::new([
  @charts.Candle::make(100.0, 108.0, 98.0, 105.0),
  @charts.Candle::make(105.0, 107.0, 99.0, 101.0),
  @charts.Candle::make(101.0, 110.0, 100.0, 108.0),
])
@charts.candlestick_t(candles, style=[("width", 420.0), ("height", 260.0)])
@charts.candlestick_t(candles, y_range=Some((90.0, 115.0)))
```

### 漏斗图 funnel_t

`funnel_t(data : Store[Array[BarItem]], alignment? = FunnelCenter, pct_of_total? = false, fill? = false, style?, handle?)`

转化漏斗：按 value 降序分层，每层一个梯形（宽度 ∝ value），同系列色自顶向下渐浅。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[Array[BarItem]] | 必填 | 复用柱状图 `BarItem::make(标签, 值)`，内部按 value 降序稳定排 |
| width / height | Double | 560 / 280 | 画布尺寸,经 `style` 传入 |
| alignment | FunnelAlign | `FunnelCenter` | 层水平对齐：居中 / `FunnelLeft` 左缘对齐 |
| pct_of_total | Bool | false | 占比口径：false 相对首层（最大层，转化率口径），true 相对全部正值总和 |

画布足够宽（扣除右侧标注列后 ≥100px）时逐层标注 标签 + 数值 (百分比)，过窄时省略标注只画梯形；值 ≤ 0 的层宽钳 0。

```moonbit
let funnel : @yue.Store[Array[@charts.BarItem]] = @yue.Store::new([
  @charts.BarItem::make("浏览", 1000.0),
  @charts.BarItem::make("加购", 420.0),
  @charts.BarItem::make("下单", 260.0),
  @charts.BarItem::make("支付", 190.0),
])
@charts.funnel_t(funnel, style=[("width", 420.0), ("height", 260.0)])
@charts.funnel_t(funnel, alignment=@charts.FunnelLeft, pct_of_total=true)
```

### 箱线图 boxplot_t

`boxplot_t(groups : Store[Array[(String, Array[Double])]], y_range? = None, fill? = false, style?, handle?)`

多组并列箱线图：每组自动算五数概括，绘箱体 + 中位线 + 须线端帽 + 离群点。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| groups | Store[Array[(String, Array[Double])]] | 必填 | (组标签, 样本值数组)，每组独立概括 |
| width / height | Double | 560 / 280 | 画布尺寸,经 `style` 传入 |
| y_range | (Double, Double)? | 自适应 | 手动值域；缺省取全部样本 min/max（含离群点）+ 8% 留白 |

五数概括按 1.5×IQR 规则：箱体 Q1-Q3（组序走四语义色循环，半透明填充 + 描边）、中位线 3px、须端取围栏内最远样本（端帽宽 60% 箱宽）、围栏外样本画 danger 色离群点圆点。组标签居中贴底轴，过密自动抽稀截断；空组只画标签。`boxp_summary(values) -> BoxSummary`（min/q1/median/q3/max/whisker_lo/whisker_hi/outliers）可脱离组件单独取概括值。

```moonbit
let boxp : @yue.Store[Array[(String, Array[Double])]] = @yue.Store::new([
  ("渲染", [12.0, 14.0, 15.0, 16.0, 18.0, 21.0, 25.0, 30.0]),
  ("IO", [5.0, 6.0, 6.5, 7.0, 8.0, 9.0, 12.0]),
])
@charts.boxplot_t(boxp, style=[("width", 420.0), ("height", 260.0)])
// 单独取概括值: @charts.boxp_summary([1.0, 2.0, 3.0, 8.0]).median
```

### 桑基图 sankey_t

`sankey_t(data : Store[SankeyData], show_labels? = true, fill? = false, style?, handle?)`

节点-链路流量图（静态分层布局，非力导向）：无入边节点进第 0 列、沿链路拓扑右移分层，列内按流量比例定高、纵向居中。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[SankeyData] | 必填 | `SankeyData::make(节点, 链路)`，见下 |
| width / height | Double | 560 / 320 | 画布尺寸,经 `style` 传入 |
| show_labels | Bool | true | 节点名标签（第 0 列标在矩形左侧、其余列右侧） |

`SankeyNode::make(名称)` 建节点；`SankeyLink::make(源下标, 目标下标, 流量)` 建链路（流量 > 0 才计入布局，节点高度与色带宽度同量纲）。节点矩形高 ∝ 流量，链路画源右缘到目标左缘的半透明贝塞尔色带（宽 ∝ 流量，同一节点多条链路纵向依序排布不重叠）；节点与链路色按源节点下标走四语义色循环。

```moonbit
let sankey : @yue.Store[@charts.SankeyData] = @yue.Store::new(
  @charts.SankeyData::make(
    [
      @charts.SankeyNode::make("浏览"),
      @charts.SankeyNode::make("加购"),
      @charts.SankeyNode::make("支付"),
    ],
    [
      @charts.SankeyLink::make(0, 1, 420.0),
      @charts.SankeyLink::make(1, 2, 190.0),
      @charts.SankeyLink::make(0, 2, 160.0),
    ],
  ),
)
@charts.sankey_t(sankey, style=[("width", 420.0), ("height", 300.0)])
```

以下九个图表与交互层同样纯 MoonBit 自绘、数据经 Store 驱动、set 后只 schedule_paint 画布不重建视图树，主题切换现取色自动跟随；除注明外都能经 `style` 覆盖画布尺寸、经 `fill=true` 横向铺满父容器。

### 树图 tree_chart_t

`tree_chart_t(root : Store[TreeItem], orientation? = "horizontal", fill? = false, style?, handle?)`

层级树：叶节点沿横铺方向均分槽位、父节点取子节点中点、深度方向分层定位；连线为直角肘线。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| root | Store[TreeItem] | 必填 | 树根节点（children 是可变子列表，直接 push 增删后 set 即重绘） |
| orientation | String | "horizontal" | "horizontal" 横向（根居左、叶居右）；"vertical" 纵向（根居顶、叶居底） |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 560 / 320 | 画布尺寸（fill=false 时）,经 `style` 传入 |

`TreeItem::make(名称, value? = None)` 建节点：value 为圆点大小量纲（None 或全树无 value 时圆点等大），children 建后可再 push。节点圆点半径 ∝ value（相对子树最大值），深度方向取主题主色渐变着色，每个节点带名称标签。配套纯函数：`tree_depth`（子树高度）、`tree_leaf_count`（叶子数）、`tree_max_value`（峰值）、`tree_vertical(orientation)`（是否纵形态）。

```moonbit
let root = @charts.TreeItem::make("仓库")
let src = @charts.TreeItem::make("src", value=80.0)
src.children.push(@charts.TreeItem::make("main.mbt", value=40.0))
root.children.push(src)
root.children.push(@charts.TreeItem::make("README.md", value=10.0))
let tree = @yue.Store::new(root)
@charts.tree_chart_t(tree, style=[("width", 420.0), ("height", 260.0)])
@charts.tree_chart_t(tree, orientation="vertical") // 纵向形态
```

### 矩形树图 tm_chart_t

`tm_chart_t(items : Store[Array[TmItem]], levels? = 2, gap? = 4.0, fill? = false, style?, handle?)`

层级数据按面积 ∝ value 正交切分（squarified 宽高比优化）。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| items | Store[Array[TmItem]] | 必填 | 顶层项（每项 children 递归展开） |
| levels | Int | 2 | 展开层数：1=只排顶层；>1 把父矩形让给子项递归布局 |
| gap | Double | 4 | 兄弟格间隙（px） |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 560 / 360 | 画布尺寸（fill=false 时）,经 `style` 传入 |

`TmItem::make(名称, value? = 0.0, children? = [])` 建节点；计值口径 `tm_value_of`——自身 value > 0 取自身值，否则子项递归合计，全零退化为 0（不参与布局）。兄弟格沿主题主色的 HSL 明度轴均摊着色（同色系、相邻可辨），父格浅底 + 名称带；格内标签 `tm_label_lines` 给名称 + 数值两行（格高 ≥30 才两行，16..30 只名称，以下不显示，按可用宽截断）。hover 命中最深可见格（提亮 + 描边），命中表每次 on_draw 重建、与绘制同一 layout。

```moonbit
let tm = @yue.Store::new([
  @charts.TmItem::make(
    "华东",
    children=[
      @charts.TmItem::make("上海", value=320.0),
      @charts.TmItem::make("江苏", value=260.0),
    ],
  ),
  @charts.TmItem::make("华南", children=[@charts.TmItem::make("广东", value=300.0)]),
])
@charts.tm_chart_t(tm, levels=2, gap=3.0, style=[("width", 420.0), ("height", 260.0)])
```

### 旭日图 sun_chart_t

`sun_chart_t(data : Store[SunItem], inner? = 0.0, show_labels? = true, center_text? = None, fill? = false, style?, handle?)`

树形数据逐级同心环：父段角度区间由子项按聚合值占比瓜分。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[SunItem] | 必填 | 树根节点 |
| inner | Double | 0 | 中心孔半径（px）；≤ 0 时取外半径 22% |
| show_labels | Bool | true | 段内名称标签（按可容纳空间判定，放不下不画） |
| center_text | String? | None | 中心文案：None=聚合总值 + 「总计」；`Some("")` 隐藏；`Some(t)` 自定义 |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 440 / 380 | 画布尺寸（fill=false 时）,经 `style` 传入 |

`SunItem::make(名称, value? = None, children? = [])`：value 缺省时按 children 聚合值之和填好。聚合口径 `sun_total`——显式值 > 0 优先，否则子项递归合计，负值不计入，无子项为 0。同支系顶层段取主题五语义色循环、逐层提亮；段间按角度内缩留缝（不依赖描边线宽）。

```moonbit
let sun = @yue.Store::new(
  @charts.SunItem::make(
    "全部",
    children=[
      @charts.SunItem::make("直接", value=335.0),
      @charts.SunItem::make("搜索", children=[
        @charts.SunItem::make("百度", value=120.0),
        @charts.SunItem::make("必应", value=80.0),
      ]),
    ],
  ),
)
@charts.sun_chart_t(sun, style=[("width", 380.0), ("height", 320.0)])
@charts.sun_chart_t(sun, inner=40.0, center_text=Some("总计访问"))
```

### 地图与飞线 geo_map_t

`geo_map_t(regions : Store[Array[GeoRegion]], flights? = [], show_labels? = true, fill? = false, style?, handle?)`

GeoJSON 区域按等距圆柱投影绘制（填充 + 描边 + 质心区域名标签），飞线为起终经纬度间的二次贝塞尔弧线。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| regions | Store[Array[GeoRegion]] | 必填 | 区域表（环列表，每环 `(lon, lat)` 点对） |
| flights | Array[GeoFlight] | [] | 飞线（不经 Store，重画需整体重挂或改 regions 触发） |
| show_labels | Bool | true | 区域名标签（画在质心，按可用宽截断，放得下才画） |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 560 / 360 | 画布尺寸（fill=false 时）,经 `style` 传入 |

地图数据集不内置：文本解析走 `geojson_parse(text) -> Result[Array[GeoRegion], GeoError]`（支持 FeatureCollection / Feature / 裸 Polygon / MultiPolygon，几何不合规给 `GeoError::BadGeometry`），或自行构造 `GeoRegion::make(名称?, 环列表)`。投影矩形 = 区域环与飞线端点的合并包围盒按自身长宽比居中缩进（不变形），无数据时画「暂无数据」。区域填充以主题主色为底、按区域名哈希 ±0.06 微调明度（同名同色、换主题不变）；飞线分段渐变虚线 + 起终点圆点 + 末端箭头，静态表现无动画，hover 未做。配套纯函数：`geo_project`（等距圆柱投影）、`geo_bbox` / `geo_bbox_points`、`geo_fit_rect`、`geo_shoelace`（环有向面积）、`geo_ring_centroid` / `geo_region_centroid`、`geo_flight_points`（弧线采样）、`geo_quad_bezier`。

```moonbit
let geojson = @yue.read_text_file("china.geojson") // 自有文本读取即可
let regions = match geojson {
  Some(text) => @charts.geojson_parse(text) catch { _ => [] }
  None => []
}
@charts.geo_map_t(
  @yue.Store::new(regions),
  flights=[
    @charts.GeoFlight::make((121.47, 31.23), (114.06, 22.54)),
  ],
  style=[("width", 420.0), ("height", 300.0)],
)
```

### 力导向关系图 gph_chart_t

`gph_chart_t(data : Store[GraphData], iterations? = 300, show_labels? = true, fill? = false, style?, handle?)`

节点-边图经力模拟收敛后静态绘制：节点对库仑斥力 + 边胡克弹簧（劲度 ∝ weight）+ 质心向心，阻尼步进。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[GraphData] | 必填 | `GraphData::make(节点表, 边表)`，边按下标引用节点 |
| iterations | Int | 300 | 力模拟步数 |
| show_labels | Bool | true | 节点名标签（防重叠推挤后的位置） |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 560 / 320 | 画布尺寸（fill=false 时）,经 `style` 传入 |

`GraphNode::make(名称, value? = 1.0)`（value 定节点圆面积，不参与力模拟）、`GraphEdge::make(源下标, 目标下标, weight? = 1.0)`（两端下标越界、自环、weight ≤ 0 的边不参与模拟也不画）。边画半透明平行四边形色带（宽 ∝ weight），节点圆按主题四语义色循环；模拟无随机源（圆周均匀布点起步），同输入必同输出。布局按当前画布尺寸在首次绘制时收敛一次并缓存，数据 set 或画布尺寸变化才重算。

```moonbit
let g = @charts.GraphData::make(
  [
    @charts.GraphNode::make("核心", value=10.0),
    @charts.GraphNode::make("网关", value=5.0),
    @charts.GraphNode::make("终端", value=3.0),
  ],
  [@charts.GraphEdge::make(0, 1, 8.0), @charts.GraphEdge::make(1, 2, 4.0)],
)
@charts.gph_chart_t(@yue.Store::new(g), iterations=200, style=[("width", 420.0), ("height", 300.0)])
```

### 平行坐标图 par_chart_t

`par_chart_t(axes : Store[Array[ParAxis]], rows : Store[Array[Array[Double]]], highlight? = -1, fill? = false, style?, handle?)`

N 条竖轴等距横排、每轴独立量程归一，每行数据一条折线穿越各轴。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| axes | Store[Array[ParAxis]] | 必填 | `ParAxis::make(名称, min? = None, max? = None)`；只给一端时另一端仍由数据推断 |
| rows | Store[Array[Array[Double]]] | 必填 | 数据行，每行一条折线（行短于列数的位按缺失处理） |
| highlight | Int | -1 | 高亮行索引（≥0 时该行不透明重描 + 各轴顶点圆点） |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 640 / 320 | 画布尺寸（fill=false 时）,经 `style` 传入 |

每轴顶部轴名、轴侧 min/max 量程标签、轴身刻度小横线；折线取系列色 alpha 混合（多行叠显密度），高亮行用不透明本色。`par_axis_range` 单轴量程推断（不加留白，等值退化以值为中心撑开）、`par_norm` 归一、`par_row_vertices` 行顶点可供自绘复用。

```moonbit
let axes = @yue.Store::new([
  @charts.ParAxis::make("渲染", 0.0, 100.0),
  @charts.ParAxis::make("IO", 0.0, 100.0),
  @charts.ParAxis::make("内存", 0.0, 100.0),
])
let rows = @yue.Store::new([[88.0, 72.0, 80.0], [70.0, 90.0, 65.0]])
@charts.par_chart_t(axes, rows, highlight=0, style=[("width", 480.0), ("height", 260.0)])
```

### 主题河流图 trv_chart_t

`trv_chart_t(names : Store[Array[String]], values : Store[Array[Array[Double]]], baseline? = TrvZero, tension? = 1.0, show_legend? = true, fill? = false, style?, handle?)`

等间隔时间轴上把多序列堆叠成河流，每层上下缘走平滑曲线。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| names | Store[Array[String]] | 必填 | 序列名，与 values 同序（names[i] ↔ values[i]） |
| values | Store[Array[Array[Double]]] | 必填 | 各序列值时序（按时间索引等距对齐，负值按 0，短序列缺失位按 0） |
| baseline | TrvBaseline | `TrvZero` | `TrvZero` 底部堆叠（自 0 起逐层累加）；`TrvSym` 围绕水平中轴对称（经典 wiggle 中枢） |
| tension | Double | 1.0 | 平滑张力：1 = 标准 Catmull-Rom；0 = 退化为折线 |
| show_legend | Bool | true | 右侧图例（色块 + 层名 + 序列总量） |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 560 / 320 | 画布尺寸（fill=false 时）,经 `style` 传入 |

层色取主题四语义色循环；时间轴长度 = 全体序列最长长度（`trv_axis_len`）。配套纯函数：`trv_row_at` / `trv_total_at`（取值与列总计）、`trv_stack_offsets`（堆叠偏移）、`trv_range`（值域）、`trv_layer_band`（层带像素盒）、`trv_series_total`。

```moonbit
let names = @yue.Store::new(["搜索", "直接"])
let values = @yue.Store::new([[120.0, 132.0, 101.0], [220.0, 182.0, 191.0]])
@charts.trv_chart_t(names, values, baseline=@charts.TrvSym, fill=false)
```

### 涟漪散点图 eff_chart_t

`eff_chart_t(points : Store[Array[EffPoint]], period_ms? = 3000, rings? = 3, x_range?, y_range?, anim? = EffAnim::make(), fill? = false, style?, handle?)`

散点 + 涟漪动画：每点周期性扩散 N 圈同心圆（半径随相位增大、描边 alpha 衰减），`set_timer` 驱动相位 Store 推进后 schedule_paint 重绘。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| points | Store[Array[EffPoint]] | 必填 | `EffPoint::make(x, y, size? = 12.0)`，size 为点直径（逻辑 px，绘层钳 2..48） |
| period_ms | Int | 3000 | 一轮涟漪周期（帧步长 = 周期 ÷ 60，兜底最小 16ms） |
| rings | Int | 3 | 每点同时扩散的圈数（≤0 退化为静态散点） |
| x_range / y_range | (Double, Double)? | None | 手动值域；None 为自适应 |
| anim | EffAnim | 自建 | 动画句柄：`eff_stop(anim)` 停定时器，未传则本次挂载自建（无法从外部停止） |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 560 / 320 | 画布尺寸（fill=false 时）,经 `style` 传入 |

**停止纪律**：本库视图没有销毁回调（`yue/view.mbt` 无 dispose 钩子），组件被卸载后定时器仍会存活、持续 schedule_paint 已卸载视图，故调用方须在卸载前显式 `eff_stop(anim)`；停止不可恢复，需要恢复请用新句柄重新挂载。配套纯函数：`eff_point_radius`（直径钳制取半径）、`eff_ring_progress` / `eff_ring_radius` / `eff_ring_alpha`（单圈进度 → 半径 / alpha）、`eff_phase_advance`、`eff_tick_ms`、`eff_xy`（点数对表）。

```moonbit
let pts = @yue.Store::new([
  @charts.EffPoint::make(120.0, 12.0, size=14.0),
  @charts.EffPoint::make(320.0, 26.0, size=20.0),
])
let anim = @charts.EffAnim::make()
@charts.eff_chart_t(pts, period_ms=2500, rings=3, anim=anim)
// ……页面卸载前
@charts.eff_stop(anim)
```

### 象形柱图 pb_chart_t

`pb_chart_t(data : Store[Array[BarItem]], symbol? = PbRect, mode? = PbRepeat, unit? = 10.0, horizontal? = false, show_values? = false, y_range? = None, fill? = false, style?, handle?)`

以符号沿基线重复平铺或整体拉伸表达数值；坐标语义对齐 `bar_chart_t`（0 基线、正负值、槽位、网格刻度、类目标签抽稀截断同源）。

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| data | Store[Array[BarItem]] | 必填 | 复用柱状图 `BarItem::make(标签, 值)` |
| symbol | PbSymbol | `PbRect` | `PbRect` / `PbCircle` / `PbTriangle`（顶点朝杆轴值端）/ `PbCustom` 自绘回调 |
| mode | PbMode | `PbRepeat` | `PbRepeat` 沿杆轴重复平铺（个数 = ceil 绝对值/unit）；`PbStretch` 整体拉伸铺满基线到值端 |
| unit | Double | 10 | 每个符号代表的数值单位（≤0 时每根柱一个符号） |
| horizontal | Bool | false | 横向条形态 |
| show_values | Bool | false | 逐根标注数值（贴杆端外侧） |
| y_range | (Double, Double)? | None | 手动值域；None 为自适应 |
| fill | Bool | false | 不设固定宽度，横向铺满父容器 |
| width / height | Double | 560 / 280 | 画布尺寸（fill=false 时）,经 `style` 传入 |

正数取主题主色向上 / 向右，负数取 danger 色向下 / 向左。单杆符号个数钳 64 上限；符号像素尺寸按「单位 × 杆长 / \|值\|」换算并钳在柱槽宽内。自定义符号：`PbCustom((Painter, x, y, w, h, color) -> Unit)` 在给定盒内自绘（颜色自行 set_fill_color）。

```moonbit
let pb = @yue.Store::new([
  @charts.BarItem::make("Q1", 32.0),
  @charts.BarItem::make("Q2", 48.0),
])
@charts.pb_chart_t(pb, symbol=@charts.PbCircle, mode=@charts.PbRepeat, unit=10.0, show_values=true)
@charts.pb_chart_t(pb, symbol=@charts.PbTriangle, mode=@charts.PbStretch, horizontal=true)
```

## 图表交互层

横切层（`charts_tooltip.mbt` 的浮层与命中 + `charts_interactive.mbt` 的图例/缩放/标注/色带/导出 + `charts_it.mbt` 的三个交互变体）：给任意自绘图表加 hover 浮层、可点击图例、DataZoom 缩放平移、阈值线与高亮域、色带映射与导出。与其余图表同一渲染模型，几何知识留在调用方（绘制与命中同源），交互层只管事件接线与浮层落位。

### hover 浮层与命中 ci_tooltip

`ci_tooltip(draw, hit, plot? = ..., zoom? = None, pan? = false, zoom_map? = None, style? = [("width", 560.0), ("height", 280.0)], handle?)`

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| draw | (Painter, Double, Double) -> Unit | 必填 | 图表内容绘制（不含边框与浮层） |
| hit | (x, y, 宽, 高) -> (标题, 行)? | 必填 | 命中 → `Some((标题, [(色标色, 行文本), ...]))`；None 隐藏浮层 |
| plot | (Double, Double) -> CiPlot | 全画布 | 绘制区矩形（缩放锚点 / 命中换算基准，须与绘制几何一致） |
| zoom | CiZoom? | None | 非 None 时绑滚轮缩放；`zoom_map` 默认沿 x 轴取 plot 分数，横向条等类目轴在 y 的场景覆盖之 |
| pan | Bool | false | 左键拖拽平移窗口（按下 `set_capture`、抬起 `release_capture`） |
| style | Array[(String, &StyVal)] | 560×280 | 画布尺寸样式 |

浮层画在图表容器自身 on_draw 内（图表之后绘制即在最上层，无 z-order 问题），恒深底浅字、不随主题变换；定位经 `ci_tooltip_pos` 钳在画布内，右溢时翻到锚点对侧。鼠标移入即刻显隐变化或拖拽时才 schedule_paint，静态移动不重绘。状态结构 `CiTip`（`CiTip::new()` / `ci_tip_show(tip, 标题, 行, px, py)` / `ci_tip_hide(tip)` / `ci_tip_draw(p, tip, w, h)` / `ci_tip_size(标题, 行)`）也可直接用于自绘图表。命中纯函数：`CiPlot::make(x0, y0, x1, y1)`（`width` / `frac` / `contains`）、`ci_nearest_idx(px, n, x0, x1)`（均布点列最近序号，绘制区外 -1）、`ci_sector_at(px, py, cx, cy, r_in, r_out, values)`（扇形命中，12 点方向起顺时针，与 `sector_angles` 同构造）。

```moonbit
let zoom = @charts.ci_zoom_make()
@charts.ci_tooltip(
  draw=fn(p, w, h) { // 按 zoom 窗切片后自绘
    let (i0, i1) = @charts.ci_zoom_visible(zoom, pts.length())
    my_draw(p, w, h, @charts.ci_slice_range(pts, i0, i1))
  },
  hit=fn(px, _py, _w, _h) {
    match @charts.ci_nearest_idx(px, pts.length(), 46.0, 500.0) {
      i if i >= 0 => Some(("第 \{i + 1} 点", [("", "\{pts[i].y}")]))
      _ => None
    }
  },
  zoom=Some(zoom),
  pan=true,
  style=[("width", 420.0), ("height", 240.0)],
)
```

（`draw` / `hit` 两个必填回调也可只写位置参数：`@charts.ci_tooltip(自绘回调, 命中回调, zoom=Some(zoom))`。）

### 可点击图例 ci_legend + 显隐位工具

`ci_legend(items~ : Store[Array[(String, String)]], visible~ : Store[Array[Bool]], on_toggle? = (Int) -> Unit, style?)`

系列色块 + 名称单行排布，hover 浅底，点击切换对应系列显隐并回调 `on_toggle`（调用方重绘图表）；`visible` 不必预先对齐长度，绘制 / 点击时按 `ci_fit_len` 补齐到 items 长度（缺省 true=可见），数据整体更换只 set items。起点超出容器宽的项不绘制（与命中 `ci_legend_hit` 的 width 门槛同源）。显隐辅助：`ci_fit_len(flags, n)`、`ci_toggle_flag(flags, i)`、`ci_filter_visible(arr, flags)` 与 `ci_filter_visible_at(arr, flags, base)`（返回 `(可见项, 各项原序号)`——显隐后颜色 / 索引仍按原始数据定位，不串色）、`ci_slice_range(arr, i0, i1)`（闭区间切片，越界自动收窄）。

```moonbit
let items = @yue.Store::new([("CPU", @yue.theme_current().primary), ("内存", @yue.theme_current().info)])
let visible = @yue.Store::new([true, true])
@charts.ci_legend(items~, visible~, on_toggle=fn(_i) { my_repaint() })
```

### DataZoom 状态窗口 ci_zoom

| 函数 | 说明 |
|---|---|
| `ci_zoom_make(start? = 0.0, end? = 100.0) -> CiZoom` | 建窗口（起止百分比 0..100，默认全窗） |
| `ci_zoom_span(z) -> Double` | 当前窗跨度 |
| `ci_zoom_reset(z)` | 复位全窗 |
| `ci_zoom_set(z, start, end, min_span? = 5.0)` | 设窗（起止先归一，跨度不足 min_span 以中点为心撑开再贴边） |
| `ci_zoom_wheel(z, anchor, delta, min_span? = 5.0, step? = 0.2)` | 滚轮缩放：anchor 为鼠标在类目轴上的百分比，上滚放大（触边界贴边，锚点滑动） |
| `ci_zoom_pan(z, dx)` | 拖拽平移（跨度不变，贴 0/100 边界停住） |
| `ci_zoom_visible(z, n) -> (Int, Int)` | 窗 → 可见序号闭区间 `[i0, i1]`（i0 下取整、i1 上取整−1，窗口内点不漏；n ≤ 0 给 (0, −1)） |

窗口数学是独立可测的纯函数（`ci_zoom_normalize` 互换保序、钳 0..100、跨度下限 1%），状态本身不依赖视图；数据切片由绘制方调用方按 `ci_zoom_visible` + `ci_slice_range` 取出后重绘。

### 阈值线与高亮域 ci_mark_line / ci_mark_area

在任意 `on_draw` 回调内对绘制区 `(x0,y0)-(x1,y1)` 调用：

| 函数 | 说明 |
|---|---|
| `ci_mark_line(p, horizontal, value, lo, hi, x0, y0, x1, y1, label? = "", color? = theme_danger(), dashed? = true)` | 横（y=value）/ 纵（x=value）阈值线 + 端标签；value 超出值域 `[lo, hi]` 不画，标签钳在绘制区内 |
| `ci_mark_area(p, horizontal, from, to, lo, hi, x0, y0, x1, y1, label? = "", color? = theme_warning(), alpha? = "26")` | from..to 值带半透明填充 + 带内端标签；from/to 自动交换，带与值域无交集不画、部分相交按交集裁剪 |

```moonbit
cv.on_draw(fn(p) {
  @charts.ci_mark_area(p, true, 0.0, 60.0, 0.0, 100.0, 46.0, 12.0, 540.0, 240.0, label="安全区")
  @charts.ci_mark_line(p, true, 80.0, 0.0, 100.0, 46.0, 12.0, 540.0, 240.0, label="告警线")
})
```

### 色带映射 ci_visual_map

| 函数 | 说明 |
|---|---|
| `ci_visual_map_make(min, max, low, high) -> CiVisualMap` | 两色带（min/max 无序自动互换，low→high 线性混） |
| `ci_visual_map3_make(min, mid, max, low, midc, high) -> CiVisualMap` | 三色带（mid 缺省或以端点身份落入时取 min/max 中点） |
| `ci_visual_map_frac(v, lo, hi) -> Double` | value → 归一分数 0..1（量程退化给 0，两端外钳制） |
| `CiVisualMap::color(self, v) -> String` | value → 颜色（两色带线性 mix；三色带两段各线性 mix，中点为 midc） |

非法色串的回退语义同 `mix_hex`（原样返回高端色）。

```moonbit
let vm = @charts.ci_visual_map3_make(0.0, 50.0, 100.0, "#E3EDFA", "#409EFF", "#1E4FA3")
let fill_color = vm.color(73.0)
```

### 导出 ci_save / ci_save_chart

| 函数 | 说明 |
|---|---|
| `ci_save(canvas : Canvas, path, format? = "png") -> Result[Unit, CiSaveError]` | 离屏画布落盘：格式非法（仅 png/jpeg/jpg）先行拒绝、不触盘；写失败带格式与路径 |
| `ci_save_chart(draw, w, h, path, format? = "png") -> Result[Unit, CiSaveError]` | 把与挂载时同一支 draw 画到离屏画布后导出（视图像素无 shim API，只能重渲染） |

非 Windows 平台 libyue 未暴露 Canvas 跨平台导出 API（shim 恒失败），错误信息带平台提示；跨平台导出走打包 / 截图工具，不由本层解决。错误 `CiSaveError`：`UnsupportedFormat(String)` / `WriteFailed(String)`。

### 交互变体 line_chart_it / bar_chart_it / donut_chart_it

三个现成「交互版」：数据 / 参数语义同原图表，改挂在 `ci_tooltip` 交互画布上，布局 = vbox(图例行 + 画布)，总高比原图多图例行（30px）。

| 组件 | 新增交互 | DataZoom |
|---|---|---|
| `line_chart_it(series, area? = false, y_range?, show_last? = true, zoom? = true, fill? = false, style?, handle?)` | hover 最近点：浮层「第 N 点」+ 各可见序列值，并画竖直准线 + 序列落点（4×4 色点）；图例点击显隐序列 | 支持（窗按最长序列定标，短序列同窗截取；y 轴随可见窗自适应） |
| `bar_chart_it(data, horizontal? = false, y_range? = None, zoom? = true, fill? = false, style?, handle?)` | hover 类目：浮层显类目标签 + 值（柱体高亮由绘制层 hover 参数承担）；图例点击显隐类目 | 支持（窗按类目索引定标，横向条的窗沿 y 轴经 zoom_map 换算；y 值域按全量类目计算，缩放 / 显隐切换时轴不动） |
| `donut_chart_it(data, thickness? = 34.0, center? = "", fill? = false, style?, handle?)` | hover 扇区：浮层显标签 + 值（占比按当前可见扇区重算），扇区外扩 4px；图例点击显隐扇区 | 无（环形图无 x 轴） |

图例色板随主题重建（`on_theme_change`），Store 订阅与主题回调均在挂载期注册——构造而未挂载的 Node 无残留。

```moonbit
let series = @yue.Store::new([
  @charts.LineSeries::make("CPU", max_points=120),
  @charts.LineSeries::make("内存", max_points=120),
])
@charts.line_chart_it(series, area=true, zoom=true)
@charts.bar_chart_it(bars, horizontal=true)
@charts.donut_chart_it(slices)
```

## 图标

内置矢量图标 803 种，全部由 iconfont 包（元海公共库，MES 场景）经 `scripts/gen_icons.py <iconfont包目录>` 生成：SVG 字体轮廓（贝塞尔/弧线）翻译为 Painter 原语，bbox 归一化 + y 翻转，填充风格，变体名取 `font_class` 的 PascalCase（如 `FilePdf`、`CaretRightSmall`），与控件类型重名的加 `Icon` 后缀（如 `MenuIcon`、`TableIcon`）；`icon_name` 返回 `<font_class>`。覆盖表单表格 / 编辑排版 / 方向翻页 / 布局视图 / 文件文档 / 云运维 / 设备 / 图表 / 通信 / 用户 / 安全 / 时间 / 状态 / 金融商业 / 系统工具 / 天气饮食 / 媒体出行 / 品牌平台等分组，showcase 图标页按组展示（该页由 `scripts/gen_showcase_icons.py` 生成）。换图标库 = 把新包目录传给 `scripts/gen_icons.py` 重跑，`icons-gen` 标记段落勿手改。

| API | 用途 |
|---|---|
| `icon(kind : IconKind, size? = 16.0, color? = "")` | 图标节点：默认主题常规色，传 color 固定色 |
| `icon_button_t(kind, on_click?, size? = 28.0, tip? = "", style?, handle?)` | 方形图标按钮：hover 浅灰底 + 文字色提亮，Enter/Space 触发；tip 非空挂原生悬浮提示；默认 marginRight 6,style 由调用方追加(后应用可覆盖默认) |
| `draw_icon(p : Painter, kind, cx, cy, s, color)` | 统一自绘入口（中心坐标 + 边长） |
| `all_icons()` / `icon_name(kind)` | 全清单 / 取名 |

常用图标按组速查(全部枚举见 `yue/icons/icons.mbt` 的 `IconKind` 与 showcase 图标库页):

| 组 | 图标 |
|---|---|
| 基础 | ChevronLeft/Right/Up/Down、ArrowUp/Left/Right/Down、Plus、Minus、Close、Check、Search、Hamburger、Home、Gear、Refresh、Trash、Edit、Save、Star、User(s)、Pin、Copy、Download、Upload、Play、Pause、Ellipsis、Grip |
| 文件与编辑 | Folder(Open/Plus)、FileDoc/Code/Plus、Clipboard、Bookmark、Undo、Redo、Scissors、Paste、Bold、Italic、Underline、Type、Align*、ListUl/Ol、Link、Unlink、ExternalLink |
| 视图与布局 | ZoomIn/Out、Eye(EyeOff)、Sun、Moon、Grid、Layout、Sidebar、Move、Expand、Shrink、RotateCw/Ccw、Columns、Rows |
| 媒体与通信 | Square、CircleRecord、Volume(Off)、Mic、Camera、Image、Music、Mail、Send、MessageCircle、Bell(BellOff/BellRing)、Phone、Rss、Globe、Share |
| 系统 | Power、LogIn/Out、Lock/Unlock、Key、Shield、Database、Server、HardDrive、Monitor、Smartphone、Wifi(Off)、Bluetooth、Cpu、Keyboard、Mouse、Battery(Charging)、Signal |
| 数据与状态 | TrendingUp/Down、BarChart、PieChart、TableRows、Info、Warning、Error、Success、Help、Heart、Flag、Clock、Tag、CheckCircle、XCircle、InfoCircle、Loader |
| 天气与其他 | Cloud(全家:Cloudy/CloudSun/CloudRain/CloudSnow/Upload/Download)、Droplet、Thermometer、Wind、ShoppingCart、CreditCard、Gift、Rocket、Trophy、Lightbulb、Wrench、Compass、MapPin、Navigation、Crown、Zap、Layers、Package |

```moonbit
@yue.icon(@yue.Search2, size=18.0)
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
@yue.alert_closeable("有新版本可用", @yue.InfoCircleFill)
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

`dropdown_menu(trigger : String, items, on_select : (Int) -> Unit, style?)`——触发文字 + 下拉箭头，点击弹菜单项列表：悬停高亮，点击回调序号并收起；items 中 `"-"` 画分隔线。

```moonbit
@yue.dropdown_menu("操作", ["编辑", "-", "删除"], fn(i) { handle(i) })
```

### 轮播 carousel_t

`carousel_t(pages : Array[Node], width? = 360.0, height? = 180.0, interval_ms? = 3000, rotation?, style?, handle?)`——面板序列 + 左右箭头 + 底部指示点；interval_ms > 0 时每 interval 毫秒自动切换（悬停暂停），点击箭头 / 指示点手动切换。

```moonbit
@yue.carousel_t([banner1, banner2], interval_ms=4000)
```

自动轮播是自排的超时链，**卸载轮播前必须 `carousel_stop(rotation)`**（不 stop 则链继续对已移除的视图空转）：`rotation` 传自建句柄 `CarouselHandle::make()`（`is_running()` 查状态）；不传则组件自建、外部拿不到句柄，仅适合随应用常驻的轮播。

组件间状态协调统一走 `Store`（subscribe / map / bind_label）或信号 `Signal`（computed 自动依赖收集，batch 批处理；组件 Store 参数可传 `sig.store()` 视图），见 [declarative.md](declarative.md)。English version: [components-ui.md](../components-ui.md).
