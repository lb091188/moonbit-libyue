# 布局样式键速查

libyue 的布局引擎是 Yoga flexbox。本文是全部可用样式键的速查：键名解析规则、四类键（枚举 / 数值 / 边缘 / 特殊）的取值表、常用组合示例——照此设置即可，不用查 yoga 文档。样式经 `style` / `style_str` 创建即应用，也可运行期用 `set_style` / `set_style_str` 修改；容器与原生控件 API 见 [components.md](components.md)，声明式树里的样式键用法见 [declarative.md](declarative.md)。

## 通用约定

入口 API（任意 `ViewLike`）：

| API | 用途 |
|---|---|
| `set_style(name, Double)` | 数值型样式（像素） |
| `set_style_str(name, String)` | 枚举 / 百分比 / auto 型 |
| `get_bounds() -> (x, y, w, h)` | 读相对父节点的计算几何 |
| `get_computed_layout() -> String` | yoga 布局树文本转储（调试） |
| `on_size_changed(callback)` | 尺寸变化时机 |

- **键名解析**：只保留 ASCII 字母并转小写——`flexDirection` / `flex-direction` / `FLEX_DIRECTION` 等价，推荐统一用小写无分隔（如 `justifycontent`）。
- **值的形式**：数值键传 `Double` 像素；任意像素值都可写字符串百分比（如 `"50%"`，相对父容器**内容区**，即扣掉 padding 后的区域）；`"auto"` 恢复由内容决定。

## 基本概念

| 概念 | 含义 |
|---|---|
| 主轴 / 交叉轴 | 子项沿**主轴**依次排列，方向由 `flexdirection` 决定（默认 `column` 纵向从上到下）；与主轴垂直的方向叫**交叉轴** |
| `justifycontent` | 子项在**主轴**上的分布（靠头 / 居中 / 平分空隙） |
| `alignitems` | 子项在**交叉轴**上的对齐（贴上 / 居中 / 拉伸） |
| 内容决定尺寸 | 子项不设任何尺寸时大小由内容决定，交叉轴默认拉伸填满容器（`alignitems=stretch`） |

## 枚举键

`set_style_str` 设置，值为字符串：

| 键 | 合法值 | 说明 |
|---|---|---|
| `flexdirection` | `column`(默认) `column-reverse` `row` `row-reverse` | 排列方向:`column` 纵向从上到下;`row` 横向从左到右;`-reverse` 反向(从下到上 / 从右到左) |
| `justifycontent` | `flex-start`(默认) `flex-end` `center` `space-between` `space-around` | 子项在**主轴**上的分布:`flex-start` 全靠起点、`flex-end` 全靠终点、`center` 居中、`space-between` 两端顶满中间平分空隙、`space-around` 每个子项两侧留相等的空隙 |
| `alignitems` | `stretch`(默认) `flex-start` `flex-end` `center` | 子项在**交叉轴**上的对齐:`stretch` 拉伸填满、`flex-start` / `flex-end` / `center` 贴起点 / 终点 / 居中 |
| `aligncontent` | `flex-start` `flex-end` `center` `stretch` `space-between` `space-around` | 多行内容的行间分布(仅 `flexwrap=wrap` 换行后生效),取值含义同 `justifycontent`,作用对象从「子项」换成「行」 |
| `alignself` | `auto`(默认) `flex-start` `flex-end` `center` `stretch` | 单个子项覆盖父容器的 `alignitems`;`auto` 表示跟随父容器设置 |
| `flexwrap` | `nowrap`(默认) `wrap` `wrap-reverse` | 一行放不下时:`nowrap` 挤在一行不换行、`wrap` 换行、`wrap-reverse` 反向换行 |
| `position` | `relative`(默认) `absolute` | `relative` 参与正常排列;`absolute` 脱离排列,改用 `top`/`bottom`/`left`/`right` 相对父节点定位 |
| `direction` | `inherit`(默认) `ltr` `rtl` | 内容书写方向(从左 / 从右),一般不用动 |
| `display` | `flex`(默认) `none` | `none` 隐藏且**不占布局空间**(`View::SetVisible(false)` 内部即此);恢复显示设回 `flex` |
| `overflow` | `visible`(默认) `hidden` `scroll` | 内容超出容器时:`visible` 溢出照画、`hidden` 裁掉、`scroll` 可滚动查看 |

```moonbit
let toolbar = @yue.Container::make(
  style_str=[("flexDirection", "row"), ("justifyContent", "space-between")])
toolbar.set_style_str("alignItems", "center")   // 运行期改键同样生效
```

## 数值键

`set_style` 设置，值为 `Double` 像素；字符串 `"50%"` 走百分比、`"auto"` 恢复自动：

| 键 | 说明 |
|---|---|
| `flex` | 伸缩简写,最常用:`flex=1` 表示「剩余空间按比例平分,不够用时按同比例收缩」——两个子项都设 1 就各占一半,设 2 的拿到的空间是设 1 的两倍;`flex=0`(默认)表示固定尺寸不参与分配 |
| `flexgrow` | 只管「有剩余空间时怎么分」:按值比例伸展,0(默认)不伸展 |
| `flexshrink` | 只管「空间不够时怎么缩」:按值比例收缩,0(默认)不收缩(内容可能溢出) |
| `flexbasis` | 主轴方向的「基准尺寸」:分配剩余空间前先按它占位,再分剩下的;不设则由 `width`/`height` 或内容决定;`"auto"` 恢复 |
| `width` / `height` | 固定尺寸(像素);`"50%"` 为父内容区宽/高的一半;`"auto"` 恢复由内容决定 |
| `minwidth` / `minheight` / `maxwidth` / `maxheight` | 尺寸上下限:先做 flex 分配,再钳制到范围内(见「固有坑」) |
| `aspectratio` | 宽 / 高比值(如 1.78 ≈ 16:9):已知一边自动推出另一边,常配 `width` 或 `flex` 用 |
| `gap` / `rowgap` / `columngap` | 相邻子项的间距(像素):`gap` 统一设,`rowgap` 只管行间、`columngap` 只管列间;不与 `margin` 叠加 |

```moonbit
let page = @yue.Container::make(
  style=[("gap", 12.0), ("padding", 16.0)],
  style_str=[("flexDirection", "row")])
let side = @yue.Container::make(style=[("width", 220.0)])
let main = @yue.Container::make(style=[("flex", 1.0)])
let half = @yue.Container::make(style_str=[("width", "50%")])   // 百分比走 style_str
```

## 边缘键

`set_style` 设置，值为 `Double` 像素，支持 `"50%"` 百分比：

| 键 | 说明 |
|---|---|
| `padding` / `paddingtop` / `paddingbottom` / `paddingleft` / `paddingright` | 内边距:容器边缘到内容区的距离,子项排列在扣除 padding 后的区域 |
| `margin` / `margintop` / `marginbottom` / `marginleft` / `marginright` | 外边距:自身边框外的留白 |
| `border` / `bordertop` / `borderbottom` / `borderleft` / `borderright` | 绘线宽(border 是绘线宽,不影响布局外尺寸之外的部分) |
| `top` / `bottom` / `left` / `right` | 仅 `position=absolute` 时生效,相对父节点偏移 |

## 特殊键

View 直收、不走 yoga：

| 键 | 值 | 等价 API |
|---|---|---|
| `color` | `"#RGB/#RRGGBB/#RRGGBBAA"` | `View::SetColor` |
| `backgroundcolor` | 同上 | `View::SetBackgroundColor` |

## 常用组合

经典两栏（侧栏定宽 + 主区弹性）：

```moonbit
let root = @yue.Container::make(style_str=[("flexDirection", "row")])
root.add_child(@yue.Container::make(style=[("width", 220.0)]))   // 侧栏定宽
root.add_child(@yue.Container::make(style=[("flex", 1.0)]))      // 主区吃剩余空间
```

主轴 / 交叉轴双向居中：

```moonbit
let center_box = @yue.Container::make(
  style_str=[("justifyContent", "center"), ("alignItems", "center")])
```

绝对定位浮层（相对挂载容器，配 `dialog_t` / 自定义遮罩用）：

```moonbit
let overlay = @yue.Container::make(
  style_str=[("position", "absolute"), ("top", "0"), ("left", "0")],
  style=[("width", 120.0), ("height", 80.0)])
```

flex 分配 + min/max 托底（窄屏不塌）：

```moonbit
let pane = @yue.Container::make(style=[("flex", 1.0), ("minWidth", 150.0)])
```

等比缩放占位：

```moonbit
let thumb = @yue.Container::make(
  style=[("width", 160.0), ("aspectRatio", 1.78)])
```

## 固有坑

- **Group / Scroll 的内容视图是布局根节点**，不是其父容器的子节点（父容器样式不影响它）。
- libyue 不支持 CSS 文本 / 表格 / float，只有 flexbox 概念。
- **尺寸冲突时 min/max 钳制优先于 flex 分配**：`flex=1` + `minwidth=150` 在剩余 100px 时得 150px。
- **复合控件（Tab / Scroll / Group）在 yoga 树里是无 measure 函数的叶节点**，外框尺寸必须显式给出（flex / 宽高），否则塌缩——根因与实测见 [adaptation.md](adaptation.md)。
- 调试用 `get_computed_layout()` 直接输出 yoga 树的最终计算值。

布局几何的实测记录（16 项几何断言、叠加规律、GUI 自动化经验）见 [adaptation.md](adaptation.md)「布局几何」节。
