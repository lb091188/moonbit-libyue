# 前端化设计：样式 / 组件 / 响应式 / 模板

本文件是**设计口径文档**（不是使用文档）：写清楚 native-gui 往 Vue 观感靠的四件事各自
做成什么样、边界在哪、分几批落地。实施细节与实测坑按仓库惯例回写 `docs/zh/adaptation.md`。

## 0. 目标与三条原则

1. **简单优先，向前端直觉靠。** 命名、样式属性、模板语法一律取前端最泛的那套写法
   （`view` / `row` / `col`、`color` / `background-color`、`class="..."`），不沿用
   desktop GUI 的历史叫法（`container` / `vbox` / `picker` / `fg` / `bg`）。
2. **平台原生做不到的不强推。** CSS 是参照系不是目标：布局只有 flex（底层是 Yoga），
   做不到的属性（grid / position / box-shadow / transition / 媒体查询）**明确不支持并报错
   提示**，而不是悄悄忽略。
3. **能在编译期查的就不放到运行时。** MoonBit 无 Proxy、无反射、无 eval，所以响应式走
   显式信号、模板表达式直接是 MoonBit 代码——类型错误由 moon 报，不自己实现运行时求值。

## 1. 样式层：CSS 最小子集 + class

样式落在**新包 `NoahLiu/native-gui/style`**（`gui/style`），theme 只管色板 token，
ui 只管组件，三包职责不混。

### 1.1 支持的属性

值：长度只认 `px`（裸数字即 px）与 `%`（仅 width/height）；颜色认 `#rgb` / `#rrggbb` /
少量命名色 / `var(--token)`。

| 分组 | 属性 | 落到哪 |
| --- | --- | --- |
| 文本与颜色 | `color`、`background-color`、`font-size`、`font-family`、`font-weight`、`text-align`、`line-height`、`letter-spacing`、`text-decoration`、`white-space` | 文本类存进文本源，绘制时读；`font-size` 参与测量 |
| 尺寸 | `width`、`height`、`min-width`、`min-height`、`max-width`、`max-height` | Yoga 节点（`set_width` / `set_min_width` …） |
| 内外边距 | `padding`、`padding-left/right/top/bottom`、`margin`、`margin-*` | Yoga（`set_padding` / `set_margin`） |
| 边框圆角 | `border-width`、`border-color`、`border-radius` | 绘制阶段；圆角矩形复用 `ui/basic.mbt` 的 `fill_round_rect` |
| flex 布局 | `display`（`flex` / `none`）、`flex-direction`、`justify-content`、`align-items`、`align-self`、`flex`（grow）、`gap`、`row-gap`、`column-gap` | Yoga |
| 其它 | `visibility`、`cursor` | 宿主 `Widget`（`set_visible` / `cursor`） |

### 1.2 不支持（解析即报"不支持"，记档）

`grid` 相关（`grid-template-*`、`grid-area`）、`position` / `top` / `z-index`（无通用绝对
定位布局）、`box-shadow`、`transition` / `animation`、`@media` 与伪类（`:hover` 等）、
后代/子代/兄弟选择器、id 与属性选择器、通配符、`!important`、CSS 的**自动继承**。

> `opacity` 与 `padding` 的四边独立是两项**待补能力**：`Painter` 暂无 alpha 通道，
> `Widget::set_padding` 现只有对称（左右同值、上下同值）形态。两者在本批标为"待补"，
> 落地前解析到就按不支持处理，补完再开（补完当天回写 adaptation）。

### 1.3 选择器与优先级

- 支持两类选择器：**类选择器** `.card`、**元素选择器**（组件名，如 `button`、`text`）。
- 优先级：**内联 `style` > `.class` > 元素选择器**；特异性相同时**按样式表定义顺序**，
  后定义的覆盖先定义的——与 `class="a b"` 里的书写顺序**无关**（同 CSS 规范，前端熟手无惊吓）。
- 不设 `!important` 通道。

```css
/* 例：后定义的 .primary 赢 */
.card { padding: 16px; background-color: var(--bg-panel); }
.primary { background-color: var(--primary); color: #fff; border-radius: 4px; }
button { cursor: pointer; }
```

### 1.4 主题联动

`var(--primary)` / `var(--bg-panel)` / `var(--text-regular)` 等映射到 `theme` 的 token，
取值发生在绘制期，主题切换后随重绘生效——样式表不固化颜色快照。

### 1.5 API 形态（示意，实施时按工具链校验）

```moonbit
pub struct Style { color : String, background_color : String, font_size : Double, .. }

pub fn StyleSheet::parse(css : String) -> StyleSheet
pub fn StyleSheet::lookup(self : StyleSheet, tag : String, class : String) -> Style
pub fn Style::merge(base : Style, over : Style) -> Style   // 后者覆盖前者的非空字段
pub fn apply(w : @core.Widget, s : Style) -> Unit          // 布局字段走 Yoga，绘制字段存进 widget
```

组件侧统一两个参数：`class? : String = ""` 与 `style? : String = ""`（内联 CSS 文本），
优先级高于组件的散参数（散参数保留，作为不写样式表时的快捷通道）。

## 2. 组件层：前端化命名

**策略：直接改名，调用点一起改，不留别名。** 全仓 `@ui.` 调用点 910 处，按包逐批替换，
每批以 `cd gui && moon check` 零错零警 + 分包测试通过为收口条件。

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

## 3. 响应式：内核已有，补三件

**现状**：`core/signal.mbt` 的 `Signal::computed` 在求值期**自动收集依赖**（不是手工接线），
另有 `batch()` 合并通知、`sub_bag_*` 订阅回收袋防泄漏。这三点已覆盖 san.js 的核心
（显式 `set` + 依赖驱动增量更新）。所以**不重写内核**，只补上层：

1. **`ListStore[T]` + keyed 差分**（Vue `v-for :key` 的对应物）：现在 table / virt_list /
   transfer 各造各的轮子；抽成通用列表容器后，`push` / `remove` / `update` / `splice` 只
   重挂载变化的子项，是模板 `v-for` 的前提，也是收益最大的一块。
2. **`effect` / `watch` 一等 API**：`computed` 能当 effect 用，但没有正式入口，也没有
   "随这一代子树一起退订"的语义（应进订阅回收袋）。
3. **帧末统一 relayout + redraw**：现有 `batch` 只合并通知、不合并重绘，一帧内多次 `set`
   会重复布局与绘制；补一个帧末队列（nextTick 对应物）。

**不做**：san 的 `data.set("a.b", v)` 字符串路径。MoonBit 无反射，路径读写必须类型擦除，
换来的是编译期查不出错的运行时失败。替代口径是：数据就是普通 struct，字段各自是
`Store`，模板编译器生成字段访问代码——类型安全，同时保留 san 的更新粒度。

## 4. 模板引擎：编译期代码生成

### 4.1 形态

单文件组件 `*.gui`（Vue SFC 观感），由编译器生成同包 `*.mbt` 再交给 moon 编译：

```html
<template>
  <col class="page">
    <row class="toolbar">
      <text class="title">{{title}}</text>
      <button class="primary" @click="on_save">保存</button>
    </row>
    <row v-for="item in items" :key="item.id" class="item">
      <text>{{item.name}}</text>
    </row>
  </col>
</template>

<style>
.page { padding: 16px; background-color: var(--bg-page); }
.primary { background-color: var(--primary); color: #fff; border-radius: 4px; }
.item { padding: 8px; gap: 8px; }
</style>
```

触发方式沿用 `prebuild` 同构的外部脚本（`gui/scripts/prebuild.py` 是先例：stdout 只出
JSON、进度走 stderr）；示例模块可自配 prebuild 给自己的包生成代码。

### 4.2 表达式就是 MoonBit 代码（关键差别）

`{{ }}` 与 `:prop="..."` 里的**内容是 MoonBit 表达式**，编译期直接拼进生成物，由 moon
做类型检查；**不实现 JS 式运行时表达式求值**。理由：MoonBit 无 eval / Proxy，自写解释器
要带一套类型和求值规则，代价大而报错还晚。代价是模板里不能写动态属性名这类 JS 式写法。

### 4.3 分期

- **T1**：静态树 + `class` / `style` 属性 + `@click` 等事件（值写 MoonBit 顶层函数名）
- **T2**：`{{ }}` 文本插值与 `:prop` 绑定（生成 Store/Signal 订阅接线）
- **T3**：`v-for`（走 `ListStore` keyed 差分）与 `v-if`（走条件挂载）

## 5. 分期与门禁

| 批 | 内容 | 收口条件 |
| --- | --- | --- |
| P1 | 新建 `gui/style` 包：Style / CSS 解析 / class 解析与合并 / 应用到 Widget | 新包测试 + `cd gui && moon check` 零错零警 |
| P2 | 组件改名（按 §2 映射表，含 `_t` 合并）+ 组件接 `class` / `style` 参数 | 全仓 `moon check` 零错零警，910 处调用点全切完 |
| P3 | 响应式补强：`ListStore` keyed 差分 / `effect`+`watch` / 帧末合并重绘 | 分包测试 + 现有 Store 用例不回归 |
| P4 | 模板引擎（T1 → T2 → T3，各自一批） | 生成的示例能构建并冒烟 |

每批单独提交；实测坑按 `AGENTS.md` 规则 7 回写 `docs/zh/adaptation.md`；使用类说明写进
`docs/zh/` 下的使用文档，不写进本文件。
