# 前端化设计：样式 / 组件 / 响应式 / 视图

本文件是**设计口径文档**（不是使用文档）：写清楚 native-gui 往 Vue 观感靠的四件事各自
做成什么样、边界在哪、分几批落地。实施细节与实测坑按仓库惯例回写 `docs/zh/adaptation.md`。

两条 2026-10-13 的定案，先摆在这里，因为它们改了整份文档的读法：

- **样式表的权威形态是 MoonBit 值**（`Style` 结构体字面量 + 具名常量），CSS 文本降级为
  导入通道 —— 见 §1。
- **不做模板语言**，`render(ctx) -> @core.Node` 函数就是最终形态 —— 见 §4。

## 0. 目标与三条原则

1. **简单优先，向前端直觉靠。** 命名一律取前端最泛的那套写法（`view` / `row` / `col`、
   `color` / `background_color`、`class=@style.card`），不沿用 desktop GUI 的历史叫法
   （`container` / `vbox` / `picker` / `fg` / `bg`）。
2. **平台原生做不到的不强推。** CSS 是参照系不是目标：布局只有 flex（底层是 Yoga），
   做不到的东西**在类型里根本不存在**（写不出来），导入通道解析到则报错并给替代建议
   （带行号），而不是悄悄忽略。
3. **能在编译期查的就不放到运行时。** MoonBit 无 Proxy、无反射、无 eval，也没有宏/插件
   编译与编译期嵌文件能力（实测见 §4），所以视图写 MoonBit 函数、样式写 MoonBit 值、
   响应式走显式信号——类型错误与拼错名字都由 moon 报，不自己实现任何运行时求值或
   外部 codegen。

## 1. 样式层：样式表写在 MoonBit 里

样式落在**新包 `NoahLiu/native-gui/style`**（`gui/style`），theme 只管色板 token，
ui 只管组件，三包职责不混。

**权威形态是 MoonBit 值**：一条规则块 = 一个 `Style` 结构体字面量，一个 class = 一个
具名 `Style` 常量。这不全是口味问题，是工具链边界决定的（实测）：没有宏/插件编译
（`moonc -h` 无 plugin/macro 开关），也没有编译期嵌文件能力（`moon ide doc '*include*'`
无结果），所以 `.css` 文本永远进不了类型检查；而 `T::{ ... }` 具名字面量的字段名既是
补全候选也是编译期检查（本仓已在用，见 `gui/dbus/media_wbtest.mbt` 的 `MediaStatus::{`）。

CSS 文本因此降为**导入通道**：`StyleSheet::parse(css)` 只用于把已有的 `.css` 资产搬进来，
搬进来即变成同一批 `Style` 值；主路上没有字符串解析这一步。

### 1.1 属性集合（字段名 = CSS 属性名，连字符写下划线）

值：长度是 `Double`（逻辑像素，`px` 就是默认单位）或 `Percent(v)`（仅 `width` / `height`）；
颜色是 `Color::hex("#rrggbb")` / `Color::named("red")` / `Color::Var("primary")`。

| 分组 | 字段（对应 CSS 属性） | 落到哪 |
| --- | --- | --- |
| 文本与颜色 | `color`、`background_color`、`font_size`、`font_family`、`font_weight`、`text_align`、`line_height`、`letter_spacing`、`text_decoration`、`white_space` | 文本类存进文本源，绘制时读；`font_size` 参与测量 |
| 尺寸 | `width`、`height`、`min_width`、`min_height`、`max_width`、`max_height` | Yoga 节点（`set_width` / `set_min_width` …） |
| 内外边距 | `padding`、`padding_left/right/top/bottom`、`margin`、`margin_*` | Yoga（`set_padding` / `set_margin`） |
| 边框圆角 | `border_width`、`border_color`、`border_radius` | 绘制阶段；圆角矩形复用 `ui/basic.mbt` 的 `fill_round_rect` |
| flex 布局 | `display`（`flex` / `none`）、`flex_direction`、`justify_content`、`align_items`、`align_self`、`flex`（grow）、`gap`、`row_gap`、`column_gap` | Yoga |
| 状态 | `hover`、`active`、`focus`（各是一个嵌套 `Style`） | 绘制期按控件状态选桶，见 §1.3 |
| 其它 | `visibility`、`cursor` | 宿主 `Widget`（`set_visible` / `cursor`） |

### 1.2 没有的属性（写不出来，而不是运行时报错）

`grid` 相关（`grid_template_*`、`grid_area`）、`position` / `top` / `z-index`（无通用绝对
定位布局）、`box-shadow`、`transition` / `animation`、`@media`、后代/子代/兄弟选择器、
id 与属性选择器、通配符、`!important`、CSS 的**自动继承**。

主路上这些**不是报错项而是不可写项**——`Style` 里没有对应字段，调用点写不出来。只有
导入通道（`StyleSheet::parse`）会撞上它们：解析到就报「不支持 + 替代建议 + 行号」，
例如 `grid_template_columns` → 「第 12 行：本栈布局只有 flex，请用 col/row + gap；
等分用 `flex`」。所以不支持表要做成**数据**（属性名 → 建议文案），不是散在解析器里的分支。

> `opacity` 与 `padding` 的四边独立是两项**待补能力**：`Painter` 暂无 alpha 通道，
> `Widget::set_padding` 现只有对称（左右同值、上下同值）形态（`core/widget.mbt`，
> 对照 `set_margin` 已是四边）。补完前 `Style` 里不开这两个字段，补完当天回写 adaptation。

### 1.3 组合、状态与优先级

- **组合**：`class? : Array[Style]`（也可传单值），组件内按顺序 `Style::merge`；
  优先级 **`class` > 散参数**。
- **覆盖顺序**：暂按「数组里后出现的覆盖先出现的」——与 JS 对象展开的「后者赢」直觉一致。
  **这一条与 CSS 规范相反**（CSS 是「按样式表定义顺序、与书写顺序无关」），
  定死前不动组件，见 §6 未决 1。
- **状态**：`hover` / `active` / `focus` 三个嵌套字段，绘制期按 `Widget` 已有的
  `hovered` / `pressed` / `focused`（`core/widget.mbt:100-104`）选桶。选它而不做伪类
  字符串的理由：组件的 `on_draw` 本来就在读 `self.hovered`（`ui/declarative.mbt:257`），
  这是**一次分支**，不需要伪类解析、不需要状态机、也不需要事件传播。
- **元素级基调**：没有「元素选择器」这个机制；同名基调就是一个常量
  （`pub let button_base : Style = ...`），组件在自己的默认值里引用它，使用者传 `class`
  即覆盖——效果与 CSS 的元素选择器一致，但可跳转、可补全。
- 不设 `!important` 通道。

```moonbit
// 与「.card + .primary 叠加、primary 赢」等价的写法
@ui.button("保存", class=[@style.card, @style.primary], on_click=on_save)

// 状态桶：hover 换底色，等价于 .primary:hover { background-color: var(--primary-hover) }
pub let primary : Style = Style::{
  background_color: Some(Color::Var("primary")),
  color: Some(Color::hex("#fff")),
  border_radius: Some(4.0),
  cursor: Some(@core.CURSOR_HAND),
  hover: Some(Style::{ background_color: Some(Color::Var("primary_hover")) }),
}
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
（`theme.control_height`，32.0）。导入通道里 `var(--primary)` 就映射到 `Var("primary")`。

### 1.5 API 形态

> 本节是**口径稿**：`Style` 的字段形态、`Percent` / `Edges` 这类值类型、`class=[...]`
> 的写法都还没实现，也没逐条过 `moon check`。定稿前需要一轮真实 API 校准。两个例外是
> 已定的：`T::{ ... }` 具名字面量本仓已在用（`gui/dbus/media_wbtest.mbt`），
> `Style::merge` 的「后者覆盖前者非空字段」是 §1.3 定下的规则。

```moonbit
pub enum Color { Hex(String) Named(String) Var(String) }

pub struct Style {
  // 文本与颜色
  mut color : Color?
  mut background_color : Color?
  mut font_size : Double?
  ...
  // 尺寸 / 内外边距 / 边框 / flex 布局 / 其它
  mut width : Size?
  mut padding : Edges?
  mut gap : (Double, Double)?
  mut cursor : Int?
  mut visibility : Visibility?
  // 状态桶
  mut hover : Style?
  mut active : Style?
  mut focus : Style?
}

// 样式表 = 一组具名常量：内置一份（gui/style/tokens.mbt），使用者可叠自己的一份
pub let card : Style = Style::{
  padding: Some(Edges::all(14.0)),
  gap: Some((10.0, 10.0)),
  background_color: Some(Var("bg_panel")),
  border_radius: Some(8.0),
}
pub let card_flat : Style = Style::merge(card, Style::{ border_width: Some(0.0) })

pub fn Style::merge(base : Style, over : Style) -> Style   // 后者覆盖前者的非空字段
pub fn StyleSheet::parse(css : String) -> Result[StyleSheet, StyleError]  // 仅导入通道
pub fn apply(w : @core.Widget, s : Style) -> Unit          // 布局字段走 Yoga，绘制字段存进 widget
```

三条实现口径：

- **`Style` 是引用语义**（MoonBit struct 通用），所以 `merge` 必须造新值、绝不改入参，
  内置常量表按只读用；这是形态改成值之后新引入的唯一陷阱。
- 组件侧统一一个参数：`class? : Array[Style] = []`。**不再有 `style : String` 内联通道**——
  一次性微调直接传 `class=[Style::{ padding: Some(Edges::all(4.0)) }]`，主路上没有字符串。
- 散参数（`font_size=` / `background_color=` 那批）保留，作为不写样式表时的快捷通道，
  优先级低于 `class`；改名对齐 CSS 属性名的事并进 §2 那批。

## 2. 组件层：前端化命名

**策略：直接改名，调用点一起改，不留别名。** 全仓 `@ui.` 调用点 910 处，按包逐批替换，
每批以 `cd gui && moon check` 零错零警 + 分包测试通过为收口条件。

这一批同时收口两件事，因为它们都是 §4「render 函数即最终形态」的直接依赖：

- **事件参数统一成 `on_*`**。现状有的组件走 `on_change?`，有的只留 `handle?` 逃逸闭包
  （`ui/declarative.mbt:34`、`:91`）。命名不齐，`on_click=` / `on_change=` 就得逐组件记，
  这一层如果将来要给任何人做薄翻译（§4 末尾）也是第一道障碍。
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
   全局单钩子（`core/node.mbt:56-71`）。flush 口径未定（回调尾同步 vs 跨拍队列），见 §6 未决 4。
4. **`for_list` / `when` 两个薄入口**：`v-for` / `v-if` 在「没有模板语言」这条定案下的
   对应物，也是 §1 到 §3 三层能独立用起来的关键一步。

   ```moonbit
   @ui.for_list(app.items, fn(item) {                    // 走 ListStore 的 keyed 差分
     @ui.row([@ui.text(item.name)], class=[@style.item])
   })
   @ui.when(app.busy.get(), @ui.text("保存中…"))          // 走显隐，不重建子树
   ```

   现有替代形态是 `bind_node`（整棵子树销毁重建 + 原位替换，`core/node.mbt:77-113`）和
   `swap_node`（两态常驻，`:119`）：列表一改就全重建，或每个分支都得预建两棵。这两个入口
   把 keyed 差分和显隐收成一行，`render` 函数里也就不需要任何语法糖了。

**不做**：san 的 `data.set("a.b", v)` 字符串路径。MoonBit 无反射，路径读写必须类型擦除，
换来的是编译期查不出错的运行时失败。替代口径是：数据就是普通 struct，字段各自是
`Store`，调用点在 `render` 里直接写字段访问（`ctx.form.name.get()`）——类型安全，
同时保留 san 的更新粒度。

## 4. 视图层：`render` 函数就是最终形态（定案：不做模板语言）

原计划在此节写 `*.gui` 单文件组件与它的 T1/T2/T3 分期。2026-10-13 定案**取消这条线**：
§1 到 §3 收口完之后，使用者手写的就是原本要生成的那段代码，形态同构、能力齐全，
中间多放一个编译器只增加成本不增加能力。最终形态：

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

> 这段是 P1/P2/P3 落地后的**目标形态**：`class` 参数来自 P1+P2、`for_list` / `when`
> 来自 P3，今天写出来还编译不过。它的作用是把「不再有第二套语法」这件事摆成可检查的样子。

### 4.1 模板的卖点，逐个看还剩什么

| 模板的卖点 | 本栈的拿法 | 还剩什么 |
| --- | --- | --- |
| `{{ }}` / `:prop` 里的表达式要类型检查 | 本来就是 MoonBit 表达式（`ctx.title.get()`），moon 直接查 | 无 |
| `<style>` 与视图同处编辑 | `@style.*` 具名常量（§1）：可跳转、可补全、可复用 | 无（甚至更好） |
| `v-for` / `v-if` | `@ui.for_list` / `@ui.when`（§3 第 4 项） | 无 |
| 事件写成 `@click="on_save"` | `on_click=ctx.on_save`（§2 已统一 `on_*`） | 无 |
| 标记观感（尖括号、闭合标签） | 拿不到 | **这一项是本定的唯一净损失** |

拿不到的那行为什么不值钱：外部 codegen 要付的是解析器 + 行号回映射 + `.gui` 文件里
没有 LSP 补全与跳转。而使用者最在意的恰恰是补全与跳转——**为了「像 HTML」要牺牲的
东西，正是「像 Vue 一样开发」最依赖的东西**。

### 4.2 工具链边界（实测，2026-10-13）

「为什么不做一个正经的宏/编译期语法扩展」的答案在这里，而不是在口味：

- `moon version --all` → `moon 0.1.20260920 / moonc v0.10.14`；`moonc -h` 没有 plugin /
  macro 相关开关（自编译 Rust 侧插件编译器要锁工具链版本，每次升级重编，不接）。
- `moon ide doc '@moonbit'` → `package moonbit not found in workspace`，即当前工具链里
  没有 `ins` 自定义中缀语法可用（想给 DSL 加 `->`、`?=` 一类新语法这条路暂时不通）。
- `moon ide doc '*include*'` → 无结果，没有编译期嵌文件能力，所以 `.css` / `.gui` 文本
  进不了类型检查（这是 §1 采值形态、本节放弃模板的共同前提）。
- 仓内唯一被验证可用的「构建期外部脚本」通道是 `--moonbit-unstable-prebuild`
  （`gui/moon.mod`，实做 `gui/scripts/prebuild.py`），而它只能给**本模块内**的包下发配置，
  看不见使用者模块里的 `.gui` 文件——真要上 codegen，每个 app 自己配一遍。

原 §4.2「表达式即 MoonBit 代码」这个判断**保留**，只是它现在推到底了：既然表达式层
已经是 MoonBit，树的外壳也没必要换成另一种语法。

### 4.3 重新开启的条件

写清楚，免得每次讨论从头论证：出现真实用户明确只要「写法像 HTML」，**且** §1/§2/§3 已
稳定到能给生成器定死契约（`class` 数组形态、`on_*` 全集、`for_list`/`when` 签名）。届时
只做**薄翻译**——标记树 → 现有 MoonBit 调用，`<style>` → `@style.*` 常量；不设计第二套
表达式语言，不引入第二套属性名。

## 5. 分期与门禁

| 批 | 内容 | 收口条件 |
| --- | --- | --- |
| P1 | 新建 `gui/style` 包：`Style` 字段集 + `Color`/`Edges`/`Size` 值类型 + `merge` + 内置常量表（`tokens.mbt`）+ `apply` 到 Widget | 新包测试 + `cd gui && moon check` 零错零警 |
| P2 | 组件改名（按 §2 映射表，含 `_t` 合并）+ `on_*` 统一 + 散参数改名对齐 CSS 属性名 + 组件接 `class : Array[Style]` | 全仓 `moon check` 零错零警，910 处调用点全切完 |
| P3 | 响应式补强：`ListStore` keyed 差分 / `effect`+`watch` / 帧末合并重绘 / `for_list`+`when` | 分包测试 + 现有 Store 用例不回归 |
| P4 | 待补能力：`Painter` alpha（`opacity`）、`Widget::set_padding` 四边独立 | 各自用例 + 回写 `docs/zh/adaptation.md` |
| P5 | CSS 导入通道（**可选**，主路不依赖它）：`StyleSheet::parse` + 诊断（行号 + 替代建议）+ 不支持建议表 | 解析用例 + 一页从旧 `.css` 搬过来的示例 |

原 P4「模板引擎 T1/T2/T3」整批撤销，理由与重开条件见 §4。顺序上 P1 之前不加新批：
`on_*` 与散参数改名本来就在 P2 的改名范围内，合批做。

每批单独提交；实测坑按 `AGENTS.md` 规则 7 回写 `docs/zh/adaptation.md`；使用类说明写进
`docs/zh/` 下的使用文档，不写进本文件。

## 6. 未决（动相应批次之前要定）

1. **`class` 数组顺序 vs 样式表定义顺序**（挡 P1 的 `merge` 语义）：值形态下「后覆盖前」
   是自然读法，CSS 规范是「按定义顺序、与书写顺序无关」。§1.3 暂按数组顺序定，
   这条一定就要改组件默认值，所以排在 P1 之前。
2. **样式表的宿主粒度**（挡 P1 的 `apply` 入口）：App 级一份（与 `theme` 同为进程级单份，
   参照 `theme/theme.mbt` 的 `theme_box`）还是允许每窗叠一份。
3. **内置常量表发多少**（挡 P1 的工作量）：只发 `title` / `card` / `button_base` 三条验证
   链路，还是把现有组件默认观感全用 `Style` 常量重写一遍——后者比 P1 大一档。
4. **帧末合并重绘的 flush 口径**（挡 P3 第 3 项）：本文倾向「同一事件回调内合并、回调尾
   同步 flush」；跨拍队列会换来真机「点下去晚一帧才变」，那类反馈只能肉眼发现。
5. **`Store` 要不要去重**（挡 P3 第 1 项）：去重要 `T: Eq` 约束，会顺着签名传播到所有组件
   （`core/store.mbt:26` 现状明确不去重）；备选是加一个要求 `Eq` 的 `set_if_changed`，内核不动。
6. **`Style::merge` 要不要挂运算符**（挡 P1 API 手感）：`merge` 是保底形态；能否给自定义
   类型挂 `+` 别名需要一条 `moon check` 实测。同理 `card with .. { border_width: Some(0.0) }`
   的记录覆写语法在 core 与本仓都没找到用例，落地前先实测一条。
