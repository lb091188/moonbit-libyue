# NoahLiu/yoga-mbt

纯 MoonBit 实现的 Flexbox 布局引擎。目标是为 moonbit-libyue 的 MoonBit 化
复刻提供布局层（替代内嵌的 C++ Yoga），同时作为独立子包可单独发布与消费。

## 定位

- **只对齐 Web Flexbox 标准**（CSS Flexible Box Layout Module Level 1），
  不保留 Yoga 的「yoga 默认值 / web 默认值」双标准。默认值一律 web 语义：
  `flex-direction: row`、`flex-shrink: 1`、`flex-basis: auto`、
  `align-items: stretch`、`min-width/height: auto`（内容下限）。
- 弹性解析（§9.7）按规范逐条实现：目标尺寸从 flex base 起步、不弹性项
  预冻结、按总违规正负选择性冻结、shrink 加权用内基准尺寸、弹性因子和
  小于 1 时以「初始剩余空间 × 因子和」封顶。与 Yoga 内核的两遍法（官方
  注释自认偏离规范）有意不同。
- 纯 MoonBit 零 FFI，无 prebuild 无链接参数，所有 target 可用。
- 宽高语义为 border-box（width/height 含自身 padding 与 border，与 Yoga
  一致）；百分比相对父容器内容区对应轴尺寸。

## 用法

```moonbit
// moon.mod: import "NoahLiu/yoga-mbt@0.1.0"
let root = @yoga.Node::new()
root.set_width(@yoga.percent(100.0))
root.set_height(@yoga.percent(100.0))

let child = @yoga.Node::new()
child.set_measure(fn(avail_w, _avail_h) {
  // 返回内容尺寸（不含自身 padding/border，引擎负责叠加）
  (120.0, 24.0)
})
root.append_child(child)

@yoga.calculate_layout(root, Some(800.0), Some(600.0))
let l = child.layout()   // left / top 相对父边框盒；width / height 边框盒
```

要点：

- 叶子节点（无子节点）通过 `set_measure` 提供内容测量；入参为可用宽高
  （`None` 表示该方向不受约束，可用于文本折行推算高度）。
- 文本类叶子再通过 `set_baseline` 提供基线：入参与 `set_measure` 相同，
  返回**基线到内容盒顶部**的距离（不含自身 padding/border，引擎负责叠加），
  返回 `None` 表示该节点无基线。容器节点无需设置——它的基线由引擎按规范
  从内部项推出。
- 根节点宽高是 `Option[Double]`，`None` 表示该方向不约束、按内容取尺寸；
  需要撑满可用空间时给根设置 `percent(100.0)`。
- 布局结果 `node.layout()` 需在 `calculate_layout` 之后读取。

## 已实现

主轴 / 交叉轴、grow / shrink / basis、justify-content 全系、
align-items / self / content、wrap 与 wrap-reverse 换行、margin auto 吸收
（主轴优先于 justify-content、交叉轴替代 align）、padding / border /
margin（交叉轴 margin 同时计入项的定位与拉伸）、百分比、min / max（含主轴
min:auto 内容下限）、row / column gap、叶子测量函数、Row / RowReverse /
Column / ColumnReverse、absolute 定位（`set_position(Absolute)` +
top/right/bottom/left：包含块为父容器 padding box，同轴两侧 inset 都设时
撑出尺寸，四向全 auto 落静态位置并按父容器 justify-content / align-items
摆放）、baseline 对齐（`align-items / align-self: baseline`：仅主轴为行方向
时生效；升距最大的项贴行交叉起端，其余项按共同基线定位；基线分组同时决定
本行交叉尺寸。无基线的项按 flex-start 摆放，交叉轴有 auto margin 的项不做
基线对齐。嵌套容器的基线取首行共同基线，否则取交叉轴起端最靠前的有基线项）。

## 未实现（按批次补）

- RTL（direction: rtl）
- aspect-ratio
- 测量缓存（Yoga 的 16 槽缓存）与像素网格取整
- 容器内在尺寸（min-content / max-content）的精确语义（当前 fit-content
  近似）

## 开发

```sh
cd modules/yoga-mbt
moon check   # 零警告
moon test    # 全绿（预期值按规范手算）
```
