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

## 枚举键(set_style_str,值为字符串)

| 键 | 合法值 |
|---|---|
| `flexdirection` | `column`(默认) `column-reverse` `row` `row-reverse` |
| `justifycontent` | `flex-start`(默认) `flex-end` `center` `space-between` `space-around` |
| `alignitems` | `stretch`(默认) `flex-start` `flex-end` `center` |
| `aligncontent` | `flex-start` `flex-end` `center` `stretch` `space-between` `space-around` |
| `alignself` | `auto`(默认) `flex-start` `flex-end` `center` `stretch` |
| `flexwrap` | `nowrap`(默认) `wrap` `wrap-reverse` |
| `position` | `relative`(默认) `absolute` |
| `direction` | `inherit`(默认) `ltr` `rtl` |
| `display` | `flex`(默认) `none`(隐藏且不参与布局,View::SetVisible 内部即此) |
| `overflow` | `visible`(默认) `hidden` `scroll` |

## 数值键(set_style,值为像素;标 % 后缀走百分比)

| 键 | 说明 |
|---|---|
| `flex` | grow/shrink/basis 三合一简写(常用 `flex=1` 平分剩余空间) |
| `flexgrow` / `flexshrink` | 单独控制伸展/收缩(默认 0) |
| `flexbasis` | 主轴基准尺寸;`"auto"` 字符串设回自动 |
| `width` / `height` | 固定尺寸;支持 `"50%"`;`"auto"` 字符串设回自动 |
| `minwidth` / `minheight` / `maxwidth` / `maxheight` | 尺寸钳制,支持百分比 |
| `aspectratio` | 宽高比(宽/高) |
| `gap` / `rowgap` / `columngap` | 子项间距 |

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

`examples/layout` 内置 16 项几何断言(flex 平分、gap 间距、百分比宽、justify/align 居中、
min-width 托底、absolute 定位),真实窗口实测 **16/16 全过(failures=0)**,±1px 容差。
叠加规律与手算一致:内容区 = 容器 − 2×padding;gap 不与 margin 叠加;百分比基准为父内容区宽。

**GUI 自动化经验**(入档):坐标点击受 WM 框架偏移与窗口遮挡影响、不稳定;
**键盘驱动(Tab 聚焦 + Space 激活)是触发控件的首选方式**;
`xdotool key --window` 走 XSendEvent 合成事件会被 GTK 丢弃,必须用 XTEST(不带 --window)。
