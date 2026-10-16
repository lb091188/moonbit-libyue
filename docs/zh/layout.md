# 布局样式（@style + yoga-mbt）

布局引擎是本仓自研的 **yoga-mbt**，纯 MoonBit 的 CSS Flexbox Level 1 实现；样式写成 MoonBit 值住在 `@style` 包，`Style` 结构体的字段名就是 CSS 属性名连字符写下划线。组件既给散参数 `padding=` / `row_gap=` …，也收 `class? : Array[@style.Style]` 叠样式块。本文是布局面速查，样式值模型与状态桶的完整设计见 [design.md](design.md)。

## 两条写入路径

- **散参数**：`@ui.col/row/view` 直接吃 `padding` / `row_gap` / `column_gap` / `width` / `height` / `grow` / `align_items` / `background_color` / `border_color`。它们是 `Style` 对应字段的糖，只有一条去向：折进匿名块。
- **`class` 通道**：给一个或多个 `@style.style(...)` 造出的 `Style` 块，数组尾赢——后者的同名属性盖过前者。34 个组件都收 `class?`。

两条合并成一份 `Style`，落到控件样式槽与 Yoga 节点。

## 布局字段速查（`Style`）

`@style.style(...)` 的关键字参数即字段名，全部可选；`None` 表示不设，走引擎默认。

### 尺寸

| 字段 | 含义 |
|---|---|
| `width` / `height` | 定尺寸，逻辑像素 |
| `width_percent` / `height_percent` | 百分比尺寸，相对父内框 |
| `min_width` / `min_height` | 最小尺寸，见下方 min:auto 口径 |
| `max_width` / `max_height` | 最大尺寸 |

### 盒内间距

| 字段 | 含义 |
|---|---|
| `padding` | 四边统一内边距，简写 |
| `padding_left` / `padding_right` / `padding_top` / `padding_bottom` | 单边内边距 |
| `margin` | 四边统一外边距，简写 |
| `margin_left` / `margin_right` / `margin_top` / `margin_bottom` | 单边外边距 |

### Flex

| 字段 | 取值 | 含义 |
|---|---|---|
| `flex_direction` | `Row` / `RowReverse` / `Column` / `ColumnReverse` | 主轴方向，默认 `Row`，web 语义 |
| `flex_wrap` | `NoWrap` / `Wrap` / `WrapReverse` | 是否换行，默认 `NoWrap` |
| `flex` | `Double` | 弹性增长因子，配合 `grow` |
| `justify_content` | `FlexStart` / `FlexEnd` / `Center` / `SpaceBetween` / `SpaceAround` / `SpaceEvenly` | 主轴对齐 |
| `align_items` | `Stretch` / `FlexStart` / `FlexEnd` / `Center` / `Baseline` | 交叉轴对齐，子项默认 |
| `align_self` | 同 `align_items` | 单项覆盖父的 `align_items` |
| `row_gap` / `column_gap` / `gap` | `Double` | 换行行间距 / 列间距 / 统一简写 |

### 定位与层序

| 字段 | 取值 | 含义 |
|---|---|---|
| `position` | `Relative` / `Absolute` | 定位模式 |
| `top` / `right` / `bottom` / `left` | `Double` | 相对或绝对偏移 |
| `z_index` | `Int` | 绘制层序键，越大越后画 |
| `display` | — | 参与布局或隐藏；`Style` 字段，绘制与命中都跳过 |

枚举类型 `FlexDirection` / `AlignItems` / `JustifyContent` / `FlexWrap` / `PositionType` 与组件散参数用的是同一套，都来自 yoga-mbt，写作 `@yoga.Row` / `@yoga.Center` 形态，或直接传给 `view(direction=…)`。

## 必须知道的几个口径

**min:auto 撑爆滚动与换行容器。** Flex 子项的默认最小尺寸是 `auto`，即内容尺寸。滚动视口或换行容器不显式写 `min_width` / `min_height = 0.0`，就会被内容顶到自然尺寸、`max()` 恒 0，结果是滚不动或整行溢出。库级容器 `scroll_view` / `virt_list` / `showcase` 侧栏已补这条；自建滚动或换行结构时要自己写 `min_width=0.0, min_height=0.0`。

**换行要放对方向。** `flex_wrap=Wrap` 只有容器是**列**时才纵向折得下：`row` 容器的交叉轴不拉伸，换行子项按内容定宽会折成竖排。段条这类「超宽自动换行」的场景要放进列容器，并每层显式 `min_* = 0`。

**gap 已从自由空间里扣掉。** 弹性分配 grow/shrink 计算自由空间时会先减去 `gap × (n-1)`，所以「固定项 + grow 项 + gap」的行不会溢出。这是修过的引擎缺陷，已写死在回归里，不必规避。

**文本尺寸回灌布局。** `@ui.text` / `bind_label` 的内容尺寸来自 Pango 测量，`measure` 与 `baseline` 都接进了布局引擎，因此文本能参与基线对齐、并按内容定宽高；折行与截断由 `max_width` + `wrap` + `ellipsis` 三件套控制。

## 增量重排

39 个 setter 与结构、回调变更一律 `mark_changed`，用全局时钟加节点 `rev` 记版本；布局入口按「子树版本 + 入参指纹」跳过没动的子树。于是 `bind_label` 改文本只重算那一条链，整帧布局近乎常数级。这层不需要调用方操心，但解释了为什么推荐就地改、而不是整棵重建，见 [declarative.md](declarative.md)。

## 相关文档

- 样式值模型、状态桶、主题联动：[design.md](design.md) §1
- 组件与散参数：[components.md](components.md)
- 响应式与整棵 / 原位替换：[declarative.md](declarative.md)
