# 前端化设计：样式 / 组件 / 响应式 / 视图

本文件是**设计文档**：写清楚 native-gui 往 Vue 靠的四件事各自做成什么样、边界在哪、分几批落地。实施细节与实测坑按仓库惯例回写 `docs/zh/adaptation.md`。


## 0. 目标与三条原则

1. **简单优先，向前端直觉靠。** 命名一律取前端最泛的那套写法（`view` / `row` / `col`、
   `color` / `background_color`、`class=@style.card`），不沿用 desktop GUI 的历史叫法
   （`container` / `vbox` / `picker` / `fg` / `bg`）。
2. **平台原生做不到的不强推。** CSS 是参照系不是目标：布局是 flex + `absolute` / `relative`
   定位（底层是 Yoga），做不到的东西在类型里根本不存在——不支持的属性名连字符串都不出现，见 §1.2。
3. **能在编译期查的就不放到运行时。** MoonBit 无 Proxy、无反射、无 eval，也没有宏/插件
   编译与编译期嵌文件能力（实测见 §4），所以视图写 MoonBit 函数、样式写 MoonBit 值、
   响应式走显式信号——类型错误与拼错名字都由 moon 报，不自己实现任何运行时求值或
   外部 codegen。

## 1. 样式层：样式表写在 MoonBit 里

样式落在**新包 `NoahLiu/native-gui/style`**（`gui/style`），theme 只管色板 token，
ui 只管组件，三包职责不混。

**样式只有一种形态：MoonBit 值。** 一条规则块 = 一个 `Style` 的链式构造，一个 class = 一个具名
`Style` 常量。属性名既是字段名也是 setter 名，因此同时进补全和编译期检查。不提供 `.css`
文本入口——同一批属性只有一套名字。旧 `.css` 资产按 §1.1 的字段名人工对照搬迁，认不出的
名字丢掉。记录字面量要写满全部字段，所以构造形态是链式 setter（逐条读数见 §1.6）。

### 1.1 属性集合（字段名 = CSS 属性名，连字符写下划线）

值：
- 长度：`Double`，单位是逻辑像素（`px` 即默认单位）；百分比不引入值类型，只在 `width` /
  `height` 上各开一条 `*_percent` 入口（定位组 inset 需要时同此形态，§1.5）。
- 颜色：一个字符串参数搞定，`#` 开头按 hex、命名色按 named、其余按 theme token 名（§1.4），
  三种来源在包内分别是 `Color::Hex` / `Named` / `Var`。

| 分组 | 字段（对应 CSS 属性） | 落到哪 |
| --- | --- | --- |
| 文本与颜色 | `color`、`background_color`、`font_size`、`font_family`、`font_weight`、`text_align`、`line_height`、`letter_spacing`、`text_decoration`、`white_space` | 文本类存进文本源，绘制时读；`font_size` 参与测量 |
| 尺寸 | `width`、`height`、`min_width`、`min_height`、`max_width`、`max_height` | Yoga 节点（`set_width` / `set_min_width` …） |
| 内外边距 | `padding`（**只表示四边同值**）、`padding_left/right/top/bottom`、`margin`、`margin_*` | Yoga（`set_padding` / `set_margin`）。**不做 CSS 的 2/3 值简写**（`padding: 8px 16px` 那种按边数变语义的写法）：要么四边同值，要么逐边单给，档位就这两档 |
| 边框圆角 | `border_width`、`border_color`、`border_radius` | 绘制阶段；圆角矩形复用 `ui/basic.mbt` 的 `fill_round_rect` |
| flex 布局 | `display`（`flex` / `none`）、`flex_direction`、`justify_content`、`align_items`、`align_self`、`flex`（grow）、`gap`、`row_gap`、`column_gap` | Yoga |
| 定位 | `position`（`relative` / `absolute`）、`top`、`right`、`bottom`、`left`、`z_index` | Yoga（`set_position` / `set_top` …底层现成，含百分比 inset；`z_index` 由 yoga-mbt 随 P1 补齐，见 §5）。Style 首批只开逻辑像素值，百分比入口同 `width_percent` 形态另开 |
| 状态 | `hover`、`active`、`focus`（各是一个嵌套 `Style`） | 绘制期按控件状态选桶，见 §1.3 |
| 其它 | `visibility`、`cursor` | 宿主 `Widget`（`set_visible` / `cursor`） |

### 1.2 没有的属性（写不出来，而不是运行时报错）

`grid` 相关（`grid_template_*`、`grid_area`）、`@media`（设计决策：**不做**，见下表）、
后代/子代/兄弟选择器、id 与属性选择器、通配符、
`!important`、CSS 的**自动继承**。

`Style` 里没有对应字段，setter 也没有同名方法，调用点写不出来。这些属性分两类：**已排进
§5 计划的**见下面引注，落地后就能写；**永远没有的**按下表替换：

> 定位、层序、阴影、透明、动画**能做、已排进 §5 计划**（不在下表——下表只收永远没有的）：
> `position` / `top` / `right` / `bottom` / `left` 并入 P1 字段集（底层 `set_position` /
> `set_top` … 现成，框架内部滚动条 / 吸顶条 / 关闭按钮 / 覆盖层已在用）；`z_index` 由
> yoga-mbt 随 P1 补齐（上游有据可依，落地前层序按 kids 数组序，后者盖上）；`box_shadow` 进
> P4；`opacity` 进 P4 且**完整落地**（整层 global alpha 铺满绘制全路径，落地即开
> `Style.opacity` 字段，不做只支持部分绘制路径的半成品）；`transition` 进 P5（落地前状态
> 变化是直接切换，§1.3 状态桶）。

| 写不出来的东西 | 替代写法 |
| --- | --- |
| `grid_template_*` / `grid_area` | `col` / `row` + `gap`；等分用 `flex`（grow） |
| `@media` | **不做**（设计决策）：断点由使用者自己读窗口尺寸，落到不同的 `Style` 常量 |
| 后代/子代/兄弟选择器、id 与属性选择器、通配符 | 具名 `Style` 常量 + `class=[...]` 组合 |
| `!important` | 靠数组顺序（§1.3 覆盖顺序），后写的赢 |
| CSS 的自动继承 | 显式传 `class`，或在父组件里算好再传下去 |

> `opacity`（P4 **完整落地**，不拖）：颜色级 alpha 已支持（hex 含 alpha 分量），P4 把**整层**
> global alpha 铺满绘制全路径（填充 / 描边 / 文本 / 图片），落地即开 `Style.opacity` 字段。
> 四边内距的入口形态：`Widget::set_padding` 收 labelled 四边（`top` / `right` / `bottom` /
> `left`，未给按 0），`set_padding_all(v)` 是一值简写；`set_margin` 收位置参数，随 P1 改成
> 同形（§1.5）。`Style.padding` 字段按四边展开落进这两条 setter。

### 1.3 组合、状态与优先级

- **组合**：`class? : Array[Style]`（也可传单值），组件内按顺序 `Style::merge`；
  优先级 **`class` > 散参数**（散参数折成一个匿名 `Style` 排在最前，见 §1.5）。
- **覆盖顺序**：数组里**后出现的覆盖先出现的**，且**逐属性取并集**——只覆盖写过的字段，
  没写的字段保留前一条的值；`hover` / `active` / `focus` 三个状态桶递归按同一条规则合并，
  不是整块互换。承载优先级的只有调用点的数组顺序：常量彼此的定义先后不承载优先级。
- **样式表粒度**：**App 级一份**，与 `theme` 同为进程级单份（参照 `theme/theme.mbt` 的
  `theme_box`），不提供每窗各叠一份。`class` 是值、随调用点传，不需要注册表。
- **状态**：`hover` / `active` / `focus` 三个状态桶，**构造端的主形态是状态前缀糖**——
  `hover_background_color("primary_hover")` 读法同 `.primary:hover { background-color }`，
  对标 Tailwind 的 `hover:` 前缀，`active_` / `focus_` 同形；糖铺满绘制期属性（§1.1 表中
  「绘制时读」的各组），布局属性与「一次换一组观感」走嵌套 `hover(Style)`。存储端就是三个
  嵌套 `Style` 字段，绘制期按 `Widget` 已有的 `hovered` / `pressed` / `focused`
  （`core/widget.mbt:100-104`）选桶——组件的 `on_draw` 本来就在读 `self.hovered`
  （`ui/declarative.mbt:257`），因此没有伪类字符串、没有状态机、也不依赖事件传播。三桶
  可同时命中（对应 CSS 的层叠），合并/覆盖按桶内逐属性递归（上条）。
- **元素级基调**：没有「元素选择器」这个机制；同名基调就是一个常量
  （`pub let button_base : Style = ...`），组件在自己的默认值里引用它，使用者传 `class`
  即覆盖——效果与 CSS 的元素选择器一致，但可跳转、可补全。
- **基调表发全量**：内置常量表覆盖 §2 全部组件的默认观感；**组件库自己也从 `class` 拿样式**，
  组件内不再自持颜色/圆角/间距/字号的硬编码分支（现状是 `on_draw` 里直接读
  `@theme.theme_fill_hover()` 那类），一律读控件上已解析好的 `Style`。因此 P1 的产出是
  「新包 + 全部组件的绘制路径」，见 §1.5 的 `Widget` 样式槽一条与 §5。
- 不设 `!important` 通道。

```moonbit
// class=[card, primary]：数组尾赢，逐属性取并集
@ui.button("保存", class=[@style.card, @style.primary], on_click=on_save)

// 状态样式主形态：前缀即伪类（前端对照 Tailwind `hover:` / `.primary:hover { … }`）
pub let primary : Style = Style::new()
  .background_color("primary")              // 基态：token 名；`#` 开头按 hex、命名色按 named（§1.4）
  .color("#fff")
  .border_radius(4.0)
  .cursor(@core.CURSOR_HAND)
  .hover_background_color("primary_hover")  // hover 换底色；active_ / focus_ 前缀同形

// 底层形态（同一条链里混用也行）：嵌套 Style，用于具名子样式复用与整组替换
pub let card_hover : Style = Style::new().background_color("primary_hover")
pub let primary_v2 : Style = Style::new()
  .background_color("primary")
  .hover(@style.card_hover)
```

### 1.4 主题联动

`Color::Var("primary")` 存的是 **token 名**，落色发生在绘制期，主题切换后随重绘生效——
样式表不固化颜色快照。现状同口径可参照：`TextSource::fg` 空色现取
`@theme.theme_text_regular()`（`ui/base.mbt:55-61`），主题变化经一次进程级订阅请求重绘
（`ui/base.mbt:128`）。

token 名单**不另设一套**，就是 `Theme` 的 20 个颜色字段加一个尺寸：`primary`、
`primary_light`、`primary_hover`、`danger`、`danger_light`、`danger_hover`、`success`、
`success_light`、`warning`、`warning_light`、`info`、`info_light`、`text_primary`、
`text_regular`、`text_secondary`、`border`、`fill_hover`、`fill_zebra`、`bg_page`、
`bg_panel`（`theme/theme.mbt` 的 `Theme` 字段），另有 `control_height`
（`theme.theme.control_height`，32.0）。写法就是 `.background_color("bg_panel")`——没有
`var(--…)` 那层壳，token 名不认识时在应用启动一次性出声（§1.5 末条）。

### 1.5 API 形态

> 形态：字段是 Option（`merge` 靠「非空才覆盖」、`apply` 靠「`None` 不动」），但**调用点不出现
> `Some`、也不出现值类型构造名**——属性名 = CSS 属性名（连字符写下划线），值 = 基元，`Some`、
> 单位、四边展开都关在 `style` 包里。构造走链式 setter：记录字面量要写满全部字段，
> `with .. { }` 记录覆写与「裸 `T` 自动升成 `T?`」都不支持，逐条读数见 §1.6。

```moonbit
pub enum Color { Hex(String) Named(String) Var(String) }

pub struct Style {
  // 文本与颜色
  mut color : Color?
  mut background_color : Color?
  mut font_size : Double?
  ...
  // 尺寸 / 内外边距 / 边框 / flex 布局 / 其它
  mut width : Double?          // 逻辑像素；百分比另开 width_percent 一条入口
  mut padding_left : Double?
  mut padding_right : Double?
  mut padding_top : Double?
  mut padding_bottom : Double?
  mut cursor : Int?
  mut visibility : Visibility?
  // 状态桶（构造端主形态是状态前缀糖 hover_*，§1.3）
  mut hover : Style?
  mut active : Style?
  mut focus : Style?
}

// 样式表 = 一组具名常量：内置一份（gui/style/tokens.mbt），使用者可叠自己的一份
pub let card : Style = Style::new()
  .padding(14.0)                    // 四边同值，setter 内展开成四个字段
  .gap(10.0)
  .background_color("bg_panel")     // # 开头按 hex、命名色命中按 named、否则当 theme token 名
  .border_radius(8.0)
  .hover(Style::new().border_color("primary"))

pub let card_flat : Style = Style::merge(card, Style::new().border_width(0.0))

pub fn Style::merge(base : Style, over : Style) -> Style   // 逐属性并集，后者赢；状态桶递归
pub fn apply(w : @core.Widget, s : Style) -> Unit          // 布局字段走 Yoga；外观字段存进
                                                            // widget 的 Style 槽，绘制期读
                                                            // self 并按状态选桶
```

九条实现口径：

- **`Style` 是引用语义**：`merge` 造新值、绝不改入参，内置常量表只读用。
- **`merge` 递归进状态桶**：两条都带 `hover` 时逐属性覆盖，不是整块 `hover` 互换——整块换会
  抹掉前者 `hover` 里没写的那些边。
- 组件侧统一一个参数：`class? : Array[Style] = []`。没有字符串内联通道——一次性微调写
  `class=[@style.card, Style::new().padding(4.0)]`（数组尾赢）。
- 散参数（`font_size=` / `background_color=` 那批）是糖，只有一条去向：折成一个匿名 `Style`
  排在解析序列**最前**，`class` 在后，于是「`class` > 散参数」由数组顺序直接成立，不需要第二
  条优先级规则；组件内部也只有「读 resolved Style」一条路径。改名对齐 CSS 属性名并进 §2 那批。
- **状态前缀糖是包内糖，不动机制**：`hover_x(v)` 的实现就是往 `hover` 桶写属性 x（桶不存在
  就建一个），存储与 `merge` 完全不感知糖的存在；糖只覆盖绘制期读的属性——布局属性进状态桶
  会把「画的时候」混成「量的时候」，不给糖，走嵌套 `hover(Style)`。
- **不挂运算符**：组合只写 `Style::merge(a, b)` 或链式。
- **`Widget` 需要一个存放 resolved `Style` 的位置**：现有 `Widget` 只有 `node` / `kids` /
  `rect` / `visible` / 各回调 / `hovered` / `pressed` / `focused` / `cursor` / `focus_id`，
  外观散落在每个组件 `on_draw` 捕获的参数里（`core/widget.mbt`）。P1 加这个位置，P2 把每个
  组件的绘制改成「读 `self` 上的样式并按状态选桶」。这与既有纪律同向：`on_draw` 首参本来就是
  `self`，而现规则明令**不要把控件句柄捕获进闭包**（引用环，计数式回收断不掉，
  `core/widget.mbt:82-87`）。
- **四边类 setter 一律 labelled + 默认值**：`set_padding`（`core/widget.mbt:691`）已同形，
  `set_margin`（`:681`，42 处调用点）随 P1 改成 `top` / `right` / `bottom` / `left`。位置参数
  的类型全是 `Double`，错序编译期查不出；两套形态也会让样式层写两份四边展开的翻译。改法机械，
  但须整批一次改完并逐处核对，靠既有布局用例兜。
- **`Edges` / `Size` 两个值类型不设**：padding 只有两档（四边同值 / 逐边单给），一个
  `padding(v)` setter 够；长度默认 px，百分比另开 `width_percent`，fixed / percent 的分派
  留在包内。
- 颜色字符串的判定在 setter 内做；**token 名不认识时在应用启动一次性出声报错并列出可用
  token**，不留到绘制期静默回退——值形态没有 CSS 的编译期拼写检查，这条是兜底。

### 1.6 MoonBit 工具链边界（`moon 0.1.20260920 / moonc v0.10.14`）

诊断来自 `moon check`，探针是仓库外的临时模块，不落仓：

| 设想写法 | 结果 | 诊断 / 含义 |
| --- | --- | --- |
| 记录字面量省略字段 `T::{ color: Some("x") }` | ✗ | `[4044] Record fields padding, radius are undefined for type T`——字面量要写满全部字段 |
| 字面量里 `..base` 填充剩余字段 | ✗ | `[3002] Parse error, unexpected token ..` |
| `base with .. { f: v }` / `base with f: v` 记录覆写 | ✗ | `[3002] Parse error, unexpected token with` |
| 裸 `T` 传给 `T?` 型 labelled 参数（指望自动包 `Some`） | ✗ | `[4014] has type: String / wanted: String?`——没有隐式提升，所以「参数收 `T?`」等于把 `Some` 摊回调用点 |
| 链式 setter（方法收 `self`、就地写字段、返回自身） | ✓ | `Finished`，零警告 |
| **方法名与字段名同名**（`Style` 有字段 `padding`，同时有方法 `Style::padding`） | ✓ | 这是「属性名即方法名」那条形态的地基 |
| 方法返回值当语句用（`s.set_x(v)` 单独一行） | ✗ | `[4139] its value cannot be implicitly ignored`——只能写成链，包内 setter 体固定为「赋值 + 返回 self」 |
| 字段有 `mut` 但没有对应 setter | 警告 | `[0015] The mutability of field 'padding' is never used`——零警告门禁逼着字段与属性一一对应，留不下死字段 |

待验一条（动 P1 前补探针）：`@style.new()` 这类包级短构造或 `pub alias` 是否可用——决定调用点
要不要写全 `@style.Style::new()`。

## 2. 组件层：前端化命名

**策略：直接改名，调用点一起改，不留别名。** 全仓 `@ui.` 调用点 910 处，按包逐批替换，
每批以 `cd gui && moon check` 零错零警 + 分包测试通过为收口条件。

这一批同时收口两件事：

- **事件参数统一成 `on_*`**：现状有的组件走 `on_change?`，有的只留 `handle?` 逃逸闭包
  （`ui/declarative.mbt:34`、`:91`）。命名齐了，`on_click=` / `on_change=` 才不用逐组件记。
- **散参数改名对齐 CSS 属性名**：`bg` → `background_color`、`fg` → `color`、
  `size` → `font_size`，与 §1.1 的 `Style` 字段同名。labelled 参数名本身进 IDE 补全，
  这一步不引入任何新机制就拿到前端直觉。

`_t` 后缀是历史上的 **themed（主题化变体）** 标记，与同名基础版是两套实现
（`label` / `label_t`、`button` / `button_t`）。改名时**合并为单入口**，差异参数取并集。

| 新名 | 旧名 | 说明 |
| --- | --- | --- |
| `view` | `container` | 通用盒子，`direction` 决定行列 |
| `row` / `col` | `hbox` / `vbox` | |
| `text` | `label` + `label_t` | 合并：`role` 可选，给了就按角色取字号字重 |
| `button` | `button` + `button_t` | 合并：`variant` = solid / soft / border / text / danger |
| `input` | `entry` | 单行输入 |
| `textarea` | `textarea` / `text_edit` | 多行 |
| `select` | `select_t` / `picker` / `combo` | 合并：`combo`（可输入）用 `editable` 参数区分 |
| `switch` | `switch_t` | |
| `tabs` | `tabs_t` / `tab` | |
| `table` | `table_t`；`table_v` ← `table_v_t` | 虚拟表格保持独立名 |
| `dialog` | `dialog_t` | |
| `tooltip` | `tooltip_t` | |
| `popover` | `popover_t` | |
| `dropdown` | `dropdown_menu` | |
| `menu` | `side_menu` | |
| `scroll_view` | `scroll_v` / `scroll` | |
| `split` | `hsplit` / `vsplit` | 合并：`direction` 参数 |
| `divider` | `separator` / `divider` | |
| `panel` | `group` | 带标题的面板 |
| `icon_button` | `icon_button_t` | |
| `rate` | `rate_t` | |
| `color_picker` | `color_picker_t` | |
| `date_picker` | `date_picker_t` | |
| `calendar` | `calendar_t` | |
| `carousel` | `carousel_t` | |
| `message_box` | `message_box_t` | |

保持不变（已与 Element Plus 同形）：`badge`、`tag`、`card`、`statistic`、`descriptions`、
`result`、`timeline`、`tree`、`transfer`、`steps`、`breadcrumb`、`pagination`、`collapse`、
`segmented`、`slider`、`progress`、`checkbox`、`radio_group`、`form`、`form_item`、`empty`、
`avatar`、`alert`、`image`、`icon`、`gif`、`code_view`、`virt_list`、`sticky_list`。

## 3. 响应式：内核已有，补四件

**现状**：`core/signal.mbt` 的 `Signal::computed` 在求值期**自动收集依赖**（不是手工接线），
另有 `batch()` 合并通知、`sub_bag_*` 订阅回收袋防泄漏。这三点已覆盖 san.js 的核心
（显式 `set` + 依赖驱动增量更新）。所以**不重写内核**，只补上层：

1. **`ListStore[T]` + keyed 差分**（Vue `v-for :key` 的对应物）：现在 table / virt_list /
   transfer 各造各的轮子；抽成通用列表容器后，`push` / `remove` / `update` / `splice` 只
   重挂载变化的子项，是下面第 4 项 `for_list` 的地基，也是收益最大的一块。
2. **`effect` / `watch` 一等 API**：`computed` 能当 effect 用，但没有正式入口，也没有
   "随这一代子树一起退订"的语义（应进订阅回收袋）。
3. **帧末统一 relayout + redraw**：现有 `batch` 只合并通知、不合并重绘，一帧内多次 `set`
   会重复布局与绘制；补一个帧末队列（nextTick 对应物）。落点已有：`invalidate()` 是
   全局单钩子（`core/node.mbt:56-71`）。flush 口径未定（回调尾同步 vs 跨拍队列），见 §6 未决 1。
4. **`for_list` / `when` 两个薄入口**：`v-for` / `v-if` 的对应物，§1 到 §3 三层能独立用起来
   就靠这两个入口。

   ```moonbit
   @ui.for_list(app.items, fn(item) {                    // 走 ListStore 的 keyed 差分
     @ui.row([@ui.text(item.name)], class=[@style.item])
   })
   @ui.when(app.busy.get(), @ui.text("保存中…"))          // 走显隐，不重建子树
   ```

   上面 `app.busy.get()` 把值传进去，`when` 就不响应；这两个入口收值还是收 `Signal`，
   见 §6 未决 3。

   现有替代形态是 `bind_node`（整棵子树销毁重建 + 原位替换，`core/node.mbt:77-113`）和
   `swap_node`（两态常驻，`:119`）：列表一改就全重建，或每个分支都得预建两棵。这两个入口
   把 keyed 差分和显隐收成一行，`render` 函数里也就不需要任何语法糖了。

**不做**：san 的 `data.set("a.b", v)` 字符串路径。MoonBit 无反射，路径读写必须类型擦除，
换来的是编译期查不出错的运行时失败。替代口径是：数据就是普通 struct，字段各自是
`Store`，调用点在 `render` 里直接写字段访问（`ctx.form.name.get()`）——类型安全，
同时保留 san 的更新粒度。

## 4. 视图层：`render` 函数就是最终形态

没有模板语言，也没有 `*.gui` 单文件组件：§1 到 §3 收口完之后，使用者手写的就是原本要生成的
那段代码，形态同构、能力齐全，中间多放一个编译器只增加成本不增加能力。最终形态：

```moonbit
fn render(ctx : Ctx) -> @core.Node {
  @ui.col(
    [
      @ui.row(
        [
          @ui.text(ctx.title.get(), class=[@style.title]),
          @ui.button("保存", class=[@style.primary], on_click=ctx.on_save),
        ],
        class=[@style.toolbar],
      ),
      @ui.for_list(ctx.items, fn(item) {
        @ui.text(item.name, class=[@style.item])
      }),
      @ui.when(ctx.saving.get(), @ui.text("保存中…")),
    ],
    class=[@style.page],
  )
}
```

> 这段是 P1/P2/P3 落地后的**目标形态**：`class` 参数来自 P1+P2，`for_list` / `when` 来自 P3，
> 今天写出来还编译不过。其中 `ctx.title.get()` / `ctx.saving.get()` 传的是值（对照
> `ui/basic.mbt:170` 的 `label(text : String)`），`set` 之后这行字不会动——调用点传值还是传
> 信号是 §6 未决 3，定之前这段只说明「没有第二套语法」，不说明会响应。

### 4.1 模板的卖点，逐个看还剩什么

| 模板的卖点 | 本栈的拿法 | 还剩什么 |
| --- | --- | --- |
| `{{ }}` / `:prop` 里的表达式要类型检查 | 本来就是 MoonBit 表达式（`ctx.title.get()`），moon 直接查 | 无 |
| `<style>` 与视图同处编辑 | `@style.*` 具名常量（§1）：可跳转、可补全、可复用 | 无（甚至更好） |
| `v-for` / `v-if` | `@ui.for_list` / `@ui.when`（§3 第 4 项） | 无 |
| 事件写成 `@click="on_save"` | `on_click=ctx.on_save`（§2 已统一 `on_*`） | 无 |
| 标记观感（尖括号、闭合标签） | 拿不到 | **唯一拿不到的一项** |

拿不到的那一项要付的是解析器 + 行号回映射 + `.gui` 文件里没有 LSP 补全与跳转；补全与跳转
是日常开发的主力，标记观感换不掉它们。

### 4.2 工具链边界（`moon 0.1.20260920 / moonc v0.10.14`）

没有编译期语法扩展的可用通道（读数随工具链版本，升级要重测）：

- `moon version --all` → `moon 0.1.20260920 / moonc v0.10.14`；`moonc -h` 没有 plugin /
  macro 相关开关（自编译 Rust 侧插件编译器要锁工具链版本，每次升级重编，不接）。
- `moon ide doc '@moonbit'` → `package moonbit not found in workspace`，即当前工具链里
  没有 `ins` 自定义中缀语法可用（想给 DSL 加 `->`、`?=` 一类新语法这条路暂时不通）。
- `moon ide doc '*include*'` → 无结果，没有编译期嵌文件能力，所以 `.css` / `.gui` 文本
  进不了类型检查（这是 §1 采值形态、本节放弃模板的共同前提）。
- 仓内唯一被验证可用的「构建期外部脚本」通道是 `--moonbit-unstable-prebuild`
  （`gui/moon.mod`，实做 `gui/scripts/prebuild.py`），而它只能给**本模块内**的包下发配置，
  看不见使用者模块里的 `.gui` 文件——真要上 codegen，每个 app 自己配一遍。

表达式层已经是 MoonBit，树的外壳不必换成另一种语法。

### 4.3 重新开启的条件

出现真实用户明确只要「写法像 HTML」，**且** §1/§2/§3 已稳定到能给生成器定死契约（`class`
数组形态、`on_*` 全集、`for_list`/`when` 签名）。届时只做**薄翻译**——标记树 → 现有 MoonBit
调用，`<style>` → `@style.*` 常量；不设计第二套表达式语言，不引入第二套属性名。

## 5. 分期与门禁

| 批 | 内容 | 收口条件 |
| --- | --- | --- |
| P1 | 新建 `gui/style` 包：`Style` 字段集（含定位组 `position` / `top` / `right` / `bottom` / `left`——底层 yoga 现成，含百分比 inset 的能力后补入口）+ `Color` + 链式 setter（属性名即方法名）+ 状态前缀糖（`hover_` / `active_` / `focus_` 铺满绘制期属性，§1.3）+ `merge`（逐属性并集、状态桶递归）+ **全量**内置常量表（§2 每个组件的基调，`tokens.mbt`）+ `Widget` 上存 resolved `Style` 的位置 + `apply`；**yoga-mbt 补 `z_index`**（`set_z_index` + 布局输出按 z_index 稳定排序，Yoga 上游同构；gui 侧绘制按 resolved 值重排 kids，`Style` 同步开 `z_index` 字段）；顺带 `Widget::set_margin` labelled 化（同形统一） | 新包测试 + `Widget` 样式槽用例 + 定位字段落到 yoga 的布局用例 + yoga-mbt 模块 z_index 用例（正序/负值/并列稳定）+ `cd gui && moon check` 零错零警 |
| P2 | 组件改名（按 §2 映射表，含 `_t` 合并）+ `on_*` 统一 + 散参数改名并折算成匿名 `Style`（排解析序列最前）+ **逐组件把 `on_draw` 从「读捕获的散参数」改成「读 `self` 上的样式并按状态选桶」** | 全仓 `moon check` 零错零警，910 处调用点全切完，观感逐页比对不回退 |
| P3 | 响应式补强：`ListStore` keyed 差分 / `effect`+`watch` / 帧末合并重绘 / `for_list`+`when` | 分包测试 + 现有 Store 用例不回归 |
| P4 | 绘制能力补齐：**`Painter` 全局 alpha 完整落地**（`opacity`：alpha 进绘制状态机，铺满填充 / 描边 / 文本 / 图片全路径，`Style` 开 `opacity` 字段——颜色级 alpha 已有，这次补的是整层）+ `box_shadow`（硬阴影档：偏移多层圆角矩形先行，模糊档随 blur 能力再评估） | 各自用例（opacity 含全路径覆盖验证）+ 回写 `docs/zh/adaptation.md` |
| P5 | 动画：`transition`（状态桶属性插值 + 帧驱动，复用 gif 的虚拟时钟与 `invalidate` 回路） | 各自用例 + 回写 `docs/zh/adaptation.md` |

没有模板批，也没有 CSS 解析批（见 §1、§4）。`on_*` 与散参数改名都在 P2 的改名范围内，合批
做，P1 之前不加批。

每批单独提交；实测坑按 `AGENTS.md` 规则 7 回写 `docs/zh/adaptation.md`；使用类说明写进
`docs/zh/` 下的使用文档，不写进本文件。

## 6. 未决（动相应批次之前要定）

1. **帧末合并重绘的 flush 口径**（挡 P3 第 3 项）：取向「同一事件回调内合并、回调尾同步
   flush」；跨拍队列会换来真机「点下去晚一帧才变」，那类反馈只能肉眼发现。
2. **`Store` 要不要去重**（挡 P3 第 1 项）：去重要 `T: Eq` 约束，会顺着签名传播到所有组件
   （`core/store.mbt:26` 现状明确不去重）；备选是加一个要求 `Eq` 的 `set_if_changed`，内核不动。
3. **调用点的绑定语义：传值还是传信号**（挡 P2 的改名表，也挡 §4 那段成果到底会不会响应）。
   §4 的 `@ui.text(ctx.title.get(), ...)` 传的是 `String`，`set` 之后这行字不会动；今天要让
   文本跟着变，走的是另外三条入口之一：`label_dyn(sig : Signal[String])`（`ui/basic.mbt:127`，
   **全仓只有这一条 `_dyn`**）、`bind_label` / `bind`（`ui/declarative.mbt:176`、`:194`）、
   `bind_node` 整棵重挂。也就是说现状是三种约定并存：输入类组件第一参数收可写的 `Store[T]`
   （ui 里约 48 处参数）、展示类「值版 + `_dyn` 信号版」只有一条、结构类靠整棵重建。三条候选：

   - **① 把 `_dyn` 升成通则**：展示类组件一律「`x` 收值 + `x_dyn` 收 `Signal[T]`」，
     `for_list` / `when` 的入参收 `Signal` 而不是值（于是 §4 那段的
     `@ui.when(ctx.saving.get(), ...)` 要写成 `@ui.when(ctx.saving, ...)`——否则 `when`
     退化成一个 `if`）。零新机制、与两条现有先例同向，且和 §3「字段各自是 `Store`」天然一对：
     列表项里改一格只重绘那一格。代价是公开 API 数量翻倍 + 文档要解释后缀。
   - **② 一个入口同时收值或信号**（`enum` 包一层或 trait）。最干净，但要先实测 MoonBit 能否
     给外部类型实现 trait、labelled 参数有无隐式提升——§1.6 已测出「裸 `T` 自动升 `T?`」**不可
     用**，方向不乐观，补一条探针即可判死。
   - **③ 调用点全传值，框架把 `render` 包成 effect**：依赖变化时整棵重建 + keyed 复用。
     Vue 直觉最近（模板里 `{{ title }}` 的「自动」本质就是这个），代价最大：P3 第 1 项要从
     「列表差分」放大成「全树差分」，而且重建会丢原生侧的有状态东西——输入框光标、滚动偏移、
     `focus_id` 重挂，这类「焦点丢了」的回归只能肉眼发现。

   取向 ①；**③ 不进 P3**（`for_list` 的 keyed 差分只管列表，不做全树 patch）。这一条决定
   P2 改名表要不要给每个展示组件补 `_dyn` 一列，所以排在 P2 之前。
