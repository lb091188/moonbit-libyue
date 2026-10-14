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

**样式只有一种形态：MoonBit 值。** 一个规则块 = 一次 `style(...)` 调用，一个 class = 一个具名
`Style` 常量。属性名即参数名，因此同时进补全和编译期检查。不提供 `.css`
文本入口——同一批属性只有一套名字。旧 `.css` 资产按 §1.1 的参数名人工对照搬迁，认不出的
名字丢掉。构造形态是 kwargs 工厂 + 状态方法（工具链依据见 §1.6）。

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

`grid` 相关（`grid_template_*`、`grid_area`）、`@media`、后代/子代/兄弟选择器、id 与属性
选择器、通配符、`!important`、CSS 的**自动继承**——`Style` 里没有对应字段，setter 也没有
同名方法，调用点写不出来。

### 1.3 组合、状态与优先级

- **组合**：`class? : Array[Style]`（也可传单值），组件内按顺序 `Style::merge`；
  优先级 **`class` > 散参数**（散参数折成一个匿名 `Style` 排在最前，见 §1.5）。
- **覆盖顺序**：数组里**后出现的覆盖先出现的**，且**逐属性取并集**——只覆盖写过的字段，
  没写的字段保留前一条的值；`hover` / `active` / `focus` 三个状态桶递归按同一条规则合并，
  不是整块互换。承载优先级的只有调用点的数组顺序：常量彼此的定义先后不承载优先级。
- **样式表粒度**：**App 级一份**，与 `theme` 同为进程级单份（参照 `theme/theme.mbt` 的
  `theme_box`），不提供每窗各叠一份。`class` 是值、随调用点传，不需要注册表。
- **状态**：`hover` / `active` / `focus` 三个状态桶，**状态长在块上，不长在属性名上**
  （W3C 规则模型）。两条入口分工明确：工厂的状态参数收**整块**（`hover=@style.card_hover`，
  复用具名块）；状态方法 `.hover(...)` / `.active(...)` / `.focus(...)` 收**属性参数**现场
  开块——且签名里只有绘制期属性，布局参数不在其列，布局值进状态块连编译都过不了（hover
  改布局需要布局期也选桶，随 P3 帧末 relayout 再评估）。存储端是三个嵌套 `Style` 字段，
  绘制期按 `Widget` 已有的 `hovered` / `pressed` / `focused` 选桶，因此没有伪类字符串、
  没有状态机、也不依赖事件传播。三桶可同时命中（对应 CSS 的层叠），合并/覆盖按桶内逐属性
  递归（上条）。
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

// 规则块 = kwargs 调用：属性名即参数名。前端对照：
// .primary       { background-color: primary; color: #fff }
// .primary:hover { background-color: primary_hover }
pub let primary : Style = @style.style(
  background_color="primary",   // token 名；`#` 开头按 hex、命名色按 named（§1.4）
  color="#fff",
  border_radius=4.0,
  cursor=@core.CURSOR_HAND,
)
.hover(background_color="primary_hover")   // 状态方法现场开块；active(...) / focus(...) 同形

// 具名块复用：工厂的状态参数收整块（W3C 的「预定义规则」）
pub let card_hover : Style = @style.style(background_color="primary_hover")
pub let primary_v2 : Style = @style.style(
  background_color="primary",
  hover=@style.card_hover,
)
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
> 单位、四边展开都关在 `style` 包里。构造走 kwargs：可选 labelled 参数（`width? : Double`）
> 在调用点自动包 `Some`（§1.6），所以属性名即参数名、值就是基元；记录字面量要写满
> 全部字段，`with .. { }` 覆写与「裸 `T` 传显式 `T?` 参数」都不支持（§1.6）。

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
  // 状态桶（构造端：工厂状态参数收整块 + 三个状态方法收属性参数，§1.3）
  mut hover : Style?
  mut active : Style?
  mut focus : Style?
}

// 工厂：全部属性是可选 labelled 参数（属性名即参数名），末尾三个状态参数收整块
pub fn style(width? : Double, /* …其余布局与外观属性… */
             color? : String, background_color? : String, /* … */
             hover? : Style, active? : Style, focus? : Style) -> Style

// 状态方法：只收绘制期属性（布局参数不在签名里），非 None 写进对应状态桶
pub fn Style::hover(self : Style, color? : String, background_color? : String,
                    /* …绘制期属性… */) -> Style

// 样式表 = 一组具名常量：内置一份（gui/style/tokens.mbt），使用者可叠自己的一份
pub let card : Style = style(
  padding=14.0,                     // 四边同值，包内展开成四个字段
  gap=10.0,
  background_color="bg_panel",      // # 开头按 hex、命名色命中按 named、否则当 theme token 名
  border_radius=8.0,
  hover=style(border_color="primary"),
)

pub let card_flat : Style = merge(card, style(border_width=0.0))

pub fn merge(base : Style, over : Style) -> Style           // 逐属性并集，后者赢；状态桶递归
pub fn apply(w : @core.Widget, s : Style) -> Unit           // 布局字段走 Yoga；外观字段存进
                                                             // widget 的 Style 槽，绘制期读
                                                             // self 并按状态选桶
```

九条实现口径：

- **`Style` 是引用语义**：`merge` 造新值、绝不改入参，内置常量表只读用。
- **`merge` 递归进状态桶**：两条都带 `hover` 时逐属性覆盖，不是整块 `hover` 互换——整块换会
  抹掉前者 `hover` 里没写的那些边。
- 组件侧统一一个参数：`class? : Array[Style] = []`。没有字符串内联通道——一次性微调写
  `class=[@style.card, @style.style(padding=4.0)]`（数组尾赢）。
- 散参数（`font_size=` / `background_color=` 那批）是糖，只有一条去向：折成一个匿名 `Style`
  排在解析序列**最前**，`class` 在后，于是「`class` > 散参数」由数组顺序直接成立，不需要第二
  条优先级规则；组件内部也只有「读 resolved Style」一条路径。改名对齐 CSS 属性名并进 §2 那批。
  **布局散参数（`width` / `height` / `padding` / `row_gap` / `column_gap` / `grow` / `direction` /
  `align_items` / `justify_content`）走同一条折法**：折进匿名块后由 `apply` 落到 Yoga，控件节点上
  不留第二条写入路径——否则 `class` 给的宽与内边距会被散参数覆写。
- **class 落点分两层**：组件的**主根控件**吃完整 `class`（布局属性 + 绘制属性）；内部件（勾选点、
  滑块拇指、子行、开在浮层图层上的面板）只吃 `class` 的**绘制期投影**（`paint_subset`），布局属性
  不外溢给标记——一个组件的 `class` 因此同时管得住整体排版与细节配色。
- **状态块两条入口，分工不同**：工厂状态参数收**整块**（`hover=@style.card_hover`，具名块
  复用），状态方法 `.hover(...)` 收**属性参数**（现场开块）；状态方法签名里只有绘制期属性
  ——布局参数不在签名中，布局值进状态块编译都过不了。状态桶是绘制期消费的，布局属性混
  进去会把「画的时候」和「量的时候」搅在一起。
  几态同时命中时按 **hover < focus < active** 层叠（后并入的赢，与 CSS 的 `:active` 盖过
  `:hover` 同向）：按下必然也在悬停里，反过来的话按下反馈永远画不出来。
- **标记控件吃 `class` 的绘制期子集**：勾选点、单选环、开关滑珠、滑块拇指、星级这类标记画在
  **子控件**上，而 `class` 落在外层宿主；子控件的 `on_draw` 只读自己的样式槽，所以建树时把
  `class` 里属于绘制期的那几条（`color` / `background_color` / `border_color` / `border_width` /
  `border_radius` 与三个桶）摘出来叠在标记控件的内置基调之上（`paint_subset`）。布局属性不外溢
  给标记——一个「组」的 `class` 同时管得住整行排版与标记配色。
- **数据态不是状态桶**：状态桶只有 `hover` / `active` / `focus` 三条（指针与焦点态）。
  选中、勾选、当前项这类**由数据决定**的态没有对应的桶（CSS 的 `:checked` 在这里没有对应物），
  所以组件代码保留「取哪个态」的分支，态里用的**颜色**一律读样式槽；样式里没有对应属性的
  （如选中行的底色）继续用内置主题色，不为此再加字段或桶。
- **组件的内置皮肤也走同一条槽**：变体配色（按钮的 solid/soft/…）折成「基块 + 状态桶」，
  存的是 **token 名**而非某一刻的色值，所以换主题后绘制期现取。由此两条覆盖路径分工清楚：
  散参数（`color=` / `background_color=`）覆盖的是**所有状态**（基块与状态桶取同一个值，
  悬停不再变色）；`class` 只覆盖它写到的那些属性，点亮态仍由内置桶决定——要把悬停态也
  定死就写 `.hover(...)`，这与 CSS 的 `.btn` / `.btn:hover` 分层同向。
- **不挂运算符**：组合只写 `@style.merge(a, b)`。
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
  `padding` 参数够；长度默认 px，百分比另开 `width_percent`，fixed / percent 的分派
  留在包内。
- 颜色字符串的判定在 setter 内做；**token 名不认识时在应用启动一次性出声报错并列出可用
  token**，不留到绘制期静默回退——值形态没有 CSS 的编译期拼写检查，这条是兜底。

### 1.6 MoonBit 工具链边界（`moon 0.1.20260920 / moonc v0.10.14`）

工具链边界决定 API 形态，读数随版本升级要重测：

| 设想写法 | 结果 | 诊断 / 含义 |
| --- | --- | --- |
| 记录字面量省略字段 `T::{ color: Some("x") }` | ✗ | `[4044] Record fields padding, radius are undefined for type T`——字面量要写满全部字段 |
| 字面量里 `..base` 填充剩余字段 | ✗ | `[3002] Parse error, unexpected token ..` |
| `base with .. { f: v }` / `base with f: v` 记录覆写 | ✗ | `[3002] Parse error, unexpected token with` |
| 裸 `T` 传给 `T?` 型 labelled 参数（指望自动包 `Some`） | ✗ | `[4014] has type: String / wanted: String?`——**显式 `T?` 类型**形态没有隐式提升（与下条的可选 labelled 形态不同） |
| 可选 labelled 参数（`fn f(x? : Int)`），调用点给裸值 `f(x=1)` | ✓ | 调用点自动包 `Some`，全省略得 `None`——kwargs 工厂形态的地基 |
| 以类型名当构造函数调用 `S(w=None)` | ✗ | `[4021] Value S not found in package`——struct 没有函数式构造语法，工厂只能是自己定义的包级函数（`style(...)`） |
| 数组展开字面量 `[..xs, y]` | ✓ | 追加/过滤重建的惯用形态（`items.update(fn(ts) { [..ts, t] })`）；`Array::filter` 返回**新数组**可直接作表达式 |
| 链式 setter（方法收 `self`、就地写字段、返回自身） | ✓ | 可用；kwargs 工厂形态下调用点不出现 setter 链 |
| `pub alias` 给工厂起短调用名（`pub alias g = f`） | ✗ | `[3002]` 解析失败 + `[0035] The word 'alias' is reserved`——**本工具链没有 alias 语法**，`alias` 是保留字；类型别名走 `pub abbrev`，函数没有对应设施 |
| `pub let g = f` 绑函数值再以 `g(width=1.0)` 调用 | ✗ | `[4117] Function with labelled arguments can only be applied directly`——带 labelled 参数的函数**不能间接调用**；转发改成显式 `f(width=width)` 又撞 `[4014] has type: Double? / wanted: Double`（体内可选参数是 `T?`，无自动 unwrap），`f(width!)` / `f(width=width?)` / `f(...)` 三种透传写法全部 `[3002]` 不解析 |
| `pub abbrev t = S` 类型别名当工厂调用名 | ✗ | 别名只能当类型用；构造调用仍撞 [4021]（类型名不是函数），给不了工厂短名 |
| `moon.pkg` 里给依赖包配短名（`"…/style": "st"` 键值形态） | ✗ | moon 直接报 `Parsing error: unexpected token :`——import 只收字符串数组，消费端 `@style.style(...)` 的包名缩不了 |

**探针结论（2026-10-13 补测，工具链同上）**：工厂调用点定死 `@style.style(...)`，没有任何给函数起短名的通道。使用者若嫌重复，可在自己模块里手写收拢函数（如 `pub fn card_style(width? : Double) -> Style { @style.style(width=width?, padding=14.0, …) }`——显式逐参传，无 `...` 透传可用），库侧不提供这种糖。
| **方法名与字段名同名**（`Style` 有字段 `padding`，同时有方法 `Style::padding`） | ✓ | kwargs 形态下属性名转移到参数名上（见下两条） |
| 方法返回值当语句用（`s.set_x(v)` 单独一行） | ✗ | `[4139] its value cannot be implicitly ignored`——只能写成链，包内 setter 体固定为「赋值 + 返回 self」 |
| 字段有 `mut` 但没有对应 setter | 警告 | `[0015] The mutability of field 'padding' is never used`——零警告门禁逼着字段与属性一一对应，留不下死字段 |

调用点写 `@style.style(...)`：短名通道全部不存在（alias 是保留字、labelled 函数不可间接调用、`moon.pkg` 不支持 import 配名），P1 直接按此形态实现。

## 2. 组件层：前端化命名

**策略：直接改名，调用点一起改，不留别名。** 全仓 `@ui.` 调用点 910 处，按包逐批替换，
每批以 `cd gui && moon check` 零错零警 + 分包测试通过为收口条件。

这一批同时收口两件事：

- **事件参数统一成 `on_*`**：现状有的组件走 `on_change?`，有的只留 `handle?` 逃逸闭包
  （`ui/declarative.mbt:34`、`:91`）。命名齐了，`on_click=` / `on_change=` 才不用逐组件记。
- **散参数改名对齐 CSS 属性名**：`bg` → `background_color`、`fg` → `color`、
  `size` → `font_size`，与 §1.1 的 `Style` 字段同名。labelled 参数名本身进 IDE 补全，
  这一步不引入任何新机制就拿到前端直觉。
  **改的判据是「这个数是字号还是几何尺寸」**：字号才叫 `font_size`（`text` / `text_dyn` /
  `input` / `textarea` / `button` / `checkbox` / `link` / `tag*` / `bind*` / `text_source`）；
  图标与圆点的边长仍是 `size`（`icon` / `badge_dot` / `avatar` / `rate`），图标按钮本来就写成
  `icon_size` / `box_size`——把几何尺寸也叫 `font_size` 才是错的。

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
另有 `batch()` 合并通知、`sub_bag_*` 订阅回收袋防泄漏。**不重写内核**，只补上层：

1. **`ListStore[T]` + keyed 差分**（Vue `v-for :key` 的对应物）：现在 table / virt_list /
   transfer 各造各的轮子；抽成通用列表容器后，`push` / `remove` / `update` / `splice` 只
   重挂载变化的子项，是下面第 4 项 `for_list` 的地基，也是收益最大的一块。
2. **`effect` / `watch` 一等 API**：`computed` 能当 effect 用，但没有正式入口，也没有
   "随这一代子树一起退订"的语义（应进订阅回收袋）。
3. **帧末统一 relayout + redraw**：现有 `batch` 只合并通知、不合并重绘，一帧内多次 `set`
   会重复布局与绘制；补一个帧末队列（nextTick 对应物）。落点已有：`invalidate()` 是
   全局单钩子（`core/node.mbt:56-71`）。flush 口径：同一事件回调内合并、回调尾同步
   flush——跨拍队列会让反馈晚一帧。
4. **`for_list` / `when` 两个薄入口**：`v-for` / `v-if` 的对应物，§1 到 §3 三层能独立用起来
   就靠这两个入口。

   ```moonbit
   // v-for 对应物：keyed 差分，改一条只重挂一条；回调拿 (item, index)，
   // key 由 key 提取器给（不给就按位置，等价无 :key）
   @ui.for_list(ctx.items, fn(t, i) {
     @ui.row([@ui.text(t.title)], class=[@style.item])
   }, key=fn(t) { t.id })

   // v-if / v-else 对应物：收 Signal，两支都常驻、切显隐（状态不丢）
   @ui.when(ctx.has_items,
            then=@ui.for_list(ctx.items, fn(t, i) { /* …行… */ }, key=fn(t) { t.id }),
            else=@ui.empty("暂无任务"))

   // 单支：假时隐藏不重建
   @ui.when(ctx.busy, @ui.text("保存中…"))
   ```

   **`when` 就是 if/else**：`else=?` 可选——不给是单支（假时显隐），给了是双支常驻切显隐
   （`swap_node` 落地，`core/node.mbt:119`）；要**销毁重建**的场合（大子树省内存、重置内部
   状态如输入光标）仍走 `bind_node`（`:77-113`），两个原语原样保留，`when` 是它们上面的糖。
   **入参收 `Signal`，不收 `.get()`**——上面示例的 `busy` / `has_items` 直接传信号（绑定
   语义通则见下第 5 条）。
   **`for_list` 与「对象属性」**：JS 的 `v-for` 能枚举对象属性，MoonBit 无反射、struct 字段
   是静态的（与下条不做字符串路径同一原因），没有「动态对象」可枚举；字典数据就是
   `Map[K, V]`，`entries()` 转条目列表进 `for_list`（条目是 `(K, V)` 值），不为对象单独开
   入口。下标就是回调第二参 `i`，写 `fn(t, _)` 即可忽略。
5. **绑定语义通则**：输入类组件第一参数收可写 `Store[T]`（现状约 48 处，`ctx.draft` 即是）；
   展示类组件一律「`x` 收值 + `x_dyn` 收 `Signal[T]`」——叶子展示件已齐（`text_dyn`、
   `tag_dyn` / `tag_of_type_dyn`、`badge_count_dyn`、`avatar_dyn`、`statistic_dyn`，
   值变就地改字并按内容重算宽度，退订随本代回收袋）；容器类（`card` / `descriptions` /
   `alert` / `timeline` / `empty` / `result`）收子节点数组，内容变了走 `for_list` /
   `when` / `bind_node`，不再叠一层 `*_dyn`；`progress` 一族本就直接读 `Store`，已是动态形态；
   `for_list` / `when` 入参收 `Signal`；
   结构级整棵换内容走 `bind_node`（`core/node.mbt:77-113`）显式重建。**不做全树 patch**
   ——列表项里改一格只重绘那一格，粒度由数据层（字段各自是 `Store`）承载。

**没有字符串路径**（`data.set("a.b", v)` 那类）：MoonBit 无反射，路径读写必须类型擦除，
换来的是编译期查不出错的运行时失败。口径是：数据就是普通 struct，字段各自是
`Store`，调用点在 `render` 里直接写字段访问（`ctx.form.name.get()`）——类型安全，
更新粒度不变。

## 4. 视图层：`render` 函数就是最终形态

没有模板语言，也没有 `*.gui` 单文件组件：§1 到 §3 收口完之后，使用者手写的就是原本要生成的
那段代码，形态同构、能力齐全，中间多放一个编译器只增加成本不增加能力。

### 4.0 数据与挂载：render 之前那两块

**数据就是普通 struct**：会变的字段各自是 `Store`（§3 口径），派生值用 `computed`（依赖
自动收集，现成实现），动作是普通函数——里面只写 `Store`，之后差分、显隐、合并重绘全是
框架的事：

```moonbit
struct Task {
  id : Int
  title : String
  done : Store[Bool]          // 会变的最小粒度单独开 Store：勾选只重绘那一格
}

struct Ctx {
  // —— 可变状态：Store。输入类组件直接吃它（v-model 对应物，现状约 48 处参数口径）
  draft : Store[String]
  items : Store[Array[Task]]
  busy : Store[Bool]
  // —— 派生：computed 只读，任一依赖变化后失效、下次 get() 重算
  has_items : Signal[Bool]
  // —— 动作：普通函数
  add : () -> Unit
  remove : (Int) -> Unit
}

fn ctx_new() -> Ctx {
  let next_id : Ref[Int] = Ref(1)
  let draft : Store[String] = @core.Store::new("")
  let items : Store[Array[Task]] = @core.Store::new([])
  let busy : Store[Bool] = @core.Store::new(false)
  {
    draft,
    items,
    busy,
    has_items: @core.Signal::computed(fn() { items.get().length() > 0 }),
    add: fn() {
      let title = draft.get().trim()
      if title == "" { return }
      let t = { id: next_id.val, title, done: @core.Store::new(false) }
      next_id.val += 1
      @core.batch(fn() {        // 多次 set 合并为出批时的一轮通知
        draft.set("")
        items.update(fn(ts) { [..ts, t] })
      })
    },
    remove: fn(id) {
      items.update(fn(ts) { ts.filter(fn(t) { t.id != id }) })
    },
  }
}
```

**render 怎么被调用**：挂载时调用**一次**，此后框架不再重跑它。响应靠 render 建出的树里
**收 Signal 的入口自己订阅、自己差分**（§3 第 5 条通则：`for_list` 管列表 keyed 差分、
`when` 管显隐、`*_dyn` 管展示文本）；整棵换内容走 `bind_node` 显式重建，不做全树 patch。
挂载入口今天收静态节点数组（`hello-themed` / `sysmonitor` 就是这个形态：先建好树再传
`[nodes]`）；P3 补 `mount_window_render`（render 槽入口），二选一——`mount_window` 的
`children` 保持首位位置参数（数百示例调用点不动）：

```moonbit
fn main {
  let ctx = ctx_new()
  let app = match @ui.mount_window_render(   // render 槽入口(与节点数组二选一)
    fn() { [render(ctx)] },   // 挂载时调用一次建首帧；此后由各入口自响应
    title="任务",
    width=420,
    height=560,
  ) {
    None => {
      println("SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(a) => a
  }
  app.run()
}
```

最终形态的视图部分：

```moonbit
// 目标形态：一个「任务页」——P1–P3 落地后可编译、可响应
fn render(ctx : Ctx) -> @core.Node {
  @ui.col(
    [
      // 工具栏：input 直接收 Store（v-model 对应物，现状能力），
      // 每敲一个字只重绘输入框本身，不碰列表
      @ui.row(
        [
          @ui.input(value=ctx.draft, placeholder="新任务…", on_submit=ctx.add),
          @ui.button("添加", class=[@style.primary], on_click=ctx.add),
        ],
        class=[@style.toolbar],
      ),
      // v-if / v-else：收 Signal，两支常驻切显隐；列表走 keyed 差分，
      // 勾选一条只重绘那一行，其余行的焦点/滚动状态原样保留
      @ui.when(
        ctx.has_items,                       // Signal[Bool]，computed 依赖自动收集
        then=@ui.for_list(
          ctx.items,
          fn(t, i) {
            @ui.row(
              [
                @ui.checkbox(checked=t.done),
                @ui.text(t.title, class=[@style.item_title]),
                @ui.icon_button(kind=@icons.trash, on_click=fn() { ctx.remove(t.id) }),
              ],
              class=[@style.item],
            )
          },
          key=fn(t) { t.id },
        ),
        else=@ui.empty("暂无任务，先添加一条"),
      ),
      // 单支 when：busy 为假时隐藏，状态不丢；保存中的转圈动画是 P5 的 transition
      @ui.when(ctx.busy, @ui.text("保存中…", class=[@style.hint])),
    ],
    class=[@style.page],
  )
}
```

> 这段是 P1/P2/P3 落地后的**目标形态**：kwargs 样式与 `class` 来自 P1+P2，`for_list` /
> `when` / `render` 槽来自 P3（数据与挂载见 §4.0），今天写出来还编译不过。`ctx.draft` 是
> `Store[String]`（输入类组件收 Store），`ctx.has_items` / `ctx.busy` 是 `Signal[Bool]`，
> 传信号才响应（§3 第 5 条）。`ctx.add` / `ctx.remove` 里只写 Store，往后的差分、显隐、
> 帧末合并重绘全是框架的事：这就是「写起来像改数据，动起来像改了那一块 UI」的整个设计。

### 4.1 工具链边界（`moon 0.1.20260920 / moonc v0.10.14`）

没有编译期语法扩展的可用通道（读数随工具链版本，升级要重测）：

- `moon version --all` → `moon 0.1.20260920 / moonc v0.10.14`；`moonc -h` 没有 plugin /
  macro 相关开关（自编译 Rust 侧插件编译器要锁工具链版本，每次升级重编，不接）。
- `moon ide doc '@moonbit'` → `package moonbit not found in workspace`，即当前工具链里
  没有 `ins` 自定义中缀语法可用（想给 DSL 加 `->`、`?=` 一类新语法这条路暂时不通）。
- `moon ide doc '*include*'` → 无结果，没有编译期嵌文件能力，所以 `.css` / `.gui` 文本
  进不了类型检查（§1 值形态的前提）。
- 仓内唯一被验证可用的「构建期外部脚本」通道是 `--moonbit-unstable-prebuild`
  （`gui/moon.mod`，实做 `gui/scripts/prebuild.py`），而它只能给**本模块内**的包下发配置，
  看不见使用者模块里的 `.gui` 文件——真要上 codegen，每个 app 自己配一遍。

表达式层已经是 MoonBit，树的外壳不必换成另一种语法。

## 5. 分期与门禁

| 批 | 内容 | 收口条件 |
| --- | --- | --- |
| P1 | 新建 `gui/style` 包：`Style` 字段集（含定位组 `position` / `top` / `right` / `bottom` / `left`——底层 yoga 现成，含百分比 inset 的能力后补入口）+ `Color` + kwargs 构造（`style(...)` 工厂属性名即参数名 + `.hover(...)` / `.active(...)` / `.focus(...)` 状态方法，§1.3，W3C 规则模型）+ `merge`（逐属性并集、状态桶递归）+ **全量**内置常量表（§2 每个组件的基调，`tokens.mbt`）+ `Widget` 上存 resolved `Style` 的位置 + `apply`；**yoga-mbt 补 `z_index`**（`set_z_index` + 布局输出按 z_index 稳定排序，Yoga 上游同构；gui 侧绘制按 resolved 值重排 kids，`Style` 同步开 `z_index` 字段）；顺带 `Widget::set_margin` labelled 化（同形统一） | 新包测试 + `Widget` 样式槽用例 + 定位字段落到 yoga 的布局用例 + yoga-mbt 模块 z_index 用例（正序/负值/并列稳定）+ `cd gui && moon check` 零错零警 |
| P2 | 组件改名（按 §2 映射表，含 `_t` 合并）+ `on_*` 统一 + 散参数改名并折算成匿名 `Style`（排解析序列最前）+ 展示类组件补 `_dyn` 信号版（§3 第 5 条通则）+ **逐组件把 `on_draw` 从「读捕获的散参数」改成「读 `self` 上的样式并按状态选桶」** | 全仓 `moon check` 零错零警，910 处调用点全切完，观感逐页比对不回退 |
| P3 | 响应式补强：`ListStore` keyed 差分 / `effect`+`watch` / 帧末合并重绘 / `for_list`+`when` / `mount_window` 补 `render` 槽（挂载时调用一次建首帧，§4.0；与节点数组二选一） | 分包测试 + 现有 Store 用例不回归 + `hello-themed`/`sysmonitor` 静态挂载形态不回归 |
| P4 | 绘制能力补齐：**`Painter` 全局 alpha**（`opacity`：alpha 进绘制状态机，铺满填充 / 描边 / 文本 / 图片全路径，`Style` 开 `opacity` 字段——颜色级 alpha 已有，本批补整层）+ `box_shadow`（硬阴影档：偏移多层圆角矩形先行，模糊档随 blur 能力再评估） | 各自用例（opacity 含全路径覆盖验证）+ 回写 `docs/zh/adaptation.md` |
| P5 | 动画：`transition`（状态桶属性插值 + 帧驱动，复用 gif 的虚拟时钟与 `invalidate` 回路）——**开工闸门见本表下方注** | 各自用例 + 回写 `docs/zh/adaptation.md` |

`on_*` 与散参数改名都在 P2 的改名范围内，合批做，P1 之前不加批。

**P5 的开工闸门是性能，不是设计。** `transition` 的本质是「连续置脏重绘」，而本栈
Windows/mac 走纯软件光栅：没有脏矩形之前，动画每一帧都是一次全窗重绘（§6.6 性能批
的实测形态）。P4 的 `opacity` / `box_shadow` 是**静态属性**（画一帧就够），可以先行；
P5 排在 §6.6「脏矩形重绘 + 文本布局缓存」落地并量出「局部变化一帧 < 16ms」之后。
判据与读数写在 `docs/zh/adaptation.md` 与 TODO §6.6，不在此重复。

每批单独提交；实测坑按 `AGENTS.md` 规则 7 回写 `docs/zh/adaptation.md`；使用类说明写进
`docs/zh/` 下的使用文档，不写进本文件。

## 6. 口径记录

1. **`Store` 内建去重**（2026-10-13 定案，原 §6 唯一待定项）：`T : Eq` 的 Store，`set` /
   `update` 写相同值时**只存不发**（`Signal::set_eq`，通知发射器 `sig_deliver` 不动，
   `Signal::set` 仍无条件通知）；没有 `Eq` 或需要「同值也重发」的场合走 `set_always` /
   `update_always`。复合值类型（`DateYMD`/`DateRange`/`TableSort`/`SemanticType` 等）补了
   `impl Eq`；图表数据窗口（`Array[LineSeries]` 等元素无 `Eq` 且比较代价高于收益）在
   chart 与示例里一律走 `set_always`。
