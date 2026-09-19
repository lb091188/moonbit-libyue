# 布局系统样式键参考

libyue 的布局引擎是 **Yoga flexbox**(`View::SetStyleProperty` 直写 yoga 节点)。
本文是从 vendored libyue 源码(`yoga_util.cc` 属性分发表 + `View::SetStyleProperty`)提取的
**完整可用键清单**,并附 Ubuntu 24.04/X11 实测记录;消费方照此表设置样式即可,不用查 yoga 文档。

MoonBit 侧入口(`yue/view.mbt` / `yue/events.mbt`):

- `set_style(name, Double)` 数值型;`set_style_str(name, String)` 枚举/百分比/auto 型
- `get_bounds() -> (x, y, w, h)` 相对父节点的计算几何
- `get_computed_layout() -> String` yoga 布局树文本转储(调试)
- `on_size_changed(callback)` 尺寸变化时机

**键名解析**(`ParseName`):只保留 ASCII 字母并转小写——`flexDirection` / `flex-direction` /
`FLEX_DIRECTION` 等价,推荐统一用小写无分隔(如 `justifycontent`)。

## 基本概念

- 布局就是「容器把空间分给子项」:子项沿**主轴**依次排列,主轴方向由
  `flexdirection` 决定(默认 `column` 纵向,从上到下);与主轴垂直的方向叫**交叉轴**。
- `justifycontent` 决定子项在**主轴**上怎么分布(靠头/居中/平分空隙),
  `alignitems` 决定在**交叉轴**上怎么对齐(贴上/居中/拉伸)。
- 子项不设任何尺寸时,大小由内容决定,交叉轴默认拉伸填满容器(`alignitems=stretch`)。
- 所有像素值都可以写成字符串百分比(如 `"50%"`,相对父容器**内容区**,即扣掉
  padding 后的区域);`"auto"` 恢复自动(由内容决定)。

## 枚举键(set_style_str,值为字符串)

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

## 数值键(set_style,值为像素;标 % 后缀走百分比)

值传 `Double` 像素;字符串 `"50%"` 为相对父容器内容区的百分比;字符串 `"auto"`
恢复自动。主轴 / 交叉轴概念见上一节。

| 键 | 说明 |
|---|---|
| `flex` | 伸缩简写,最常用:`flex=1` 表示「剩余空间按比例平分,不够用时按同比例收缩」——两个子项都设 1 就各占一半,设 2 的拿到的空间是设 1 的两倍;`flex=0`(默认)表示固定尺寸不参与分配 |
| `flexgrow` | 只管「有剩余空间时怎么分」:按值比例伸展,0(默认)不伸展 |
| `flexshrink` | 只管「空间不够时怎么缩」:按值比例收缩,0(默认)不收缩(内容可能溢出) |
| `flexbasis` | 主轴方向的「基准尺寸」:分配剩余空间前先按它占位,再分剩下的;不设则由 `width`/`height` 或内容决定;`"auto"` 恢复 |
| `width` / `height` | 固定尺寸(像素);`"50%"` 为父内容区宽/高的一半;`"auto"` 恢复由内容决定 |
| `minwidth` / `minheight` / `maxwidth` / `maxheight` | 尺寸上下限:先做 flex 分配,再钳制到范围内(实测 `flex=1` + `minwidth=150` 在剩余 100px 时得 150px,见下文实测记录) |
| `aspectratio` | 宽 / 高比值(如 1.78 ≈ 16:9):已知一边自动推出另一边,常配 `width` 或 `flex` 用 |
| `gap` / `rowgap` / `columngap` | 相邻子项的间距(像素):`gap` 统一设,`rowgap` 只管行间、`columngap` 只管列间;不与 `margin` 叠加 |

## 边缘键(set_style,值为像素;支持 % 后缀)

`padding` `paddingtop` `paddingbottom` `paddingleft` `paddingright`
`margin` `margintop` `marginbottom` `marginleft` `marginright`
`border` `bordertop` `borderbottom` `borderleft` `borderright`(border 是绘线宽,不影响布局外尺寸之外的部分)
`top` `bottom` `left` `right`(仅 `position=absolute` 时生效,相对父节点偏移)

## 特殊键(View 直收,不走 yoga)

| 键 | 值 | 等价 API |
|---|---|---|
| `color` | `"#RGB/#RRGGBB/#RRGGBBAA"` | `View::SetColor` |
| `backgroundcolor` | 同上 | `View::SetBackgroundColor` |

## 布局模型要点

- 容器默认 `flexDirection=column`、`alignItems=stretch`:子项默认拉伸填满交叉轴。
- **Group / Scroll 的内容视图是布局根节点**,不是其父容器的子节点(父容器样式不影响它)。
- libyue 不支持 CSS 文本/表格/float,只有 flexbox 概念。
- 尺寸冲突时:min/max 钳制优先于 flex 分配(实测:`flex=1` + `minwidth=150` 在剩余 100px 时得 150px)。
- 调试:`get_computed_layout()` 直接输出 yoga 树的最终计算值。

## Ubuntu 24.04 / X11 / XFCE 4.18 实测记录(2026-09-11)

布局系统内置 16 项几何断言(flex 平分、gap 间距、百分比宽、justify/align 居中、
min-width 托底、absolute 定位),真实窗口实测 **16/16 全过(failures=0)**,±1px 容差。
叠加规律与手算一致:内容区 = 容器 − 2×padding;gap 不与 margin 叠加;百分比基准为父内容区宽。

**GUI 自动化经验**(入档):坐标点击受 WM 框架偏移与窗口遮挡影响、不稳定;
**键盘驱动(Tab 聚焦 + Space 激活)是触发控件的首选方式**;
`xdotool key --window` 走 XSendEvent 合成事件会被 GTK 丢弃,必须用 XTEST(不带 --window)。
