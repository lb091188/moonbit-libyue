// 公开 API：取值构造辅助与样式 setter。

///|
/// 固定值。
pub fn fixed(v : Double) -> Value {
  Fixed(v)
}

///|
/// 百分比（相对父容器对应参照尺寸，p 取 0~100）。
pub fn percent(p : Double) -> Value {
  Percent(p)
}

///|
/// 自动。
pub fn auto() -> Value {
  Auto
}

///|
/// 未设置。
pub fn undefined() -> Value {
  Undefined
}

///|
/// min-content 取值：该轴上「内容不溢出」的最小尺寸。
/// 只用于尺寸类属性（width / height / min-* / max-* / flex-basis）。
pub fn min_content() -> Value {
  MinContent
}

///|
/// max-content 取值：该轴上不受约束时内容需要的尺寸。
pub fn max_content() -> Value {
  MaxContent
}

///|
/// fit-content 取值：`clamp(min-content, 可用空间, max-content)`；
/// 可用空间不受约束时退化为 max-content。
pub fn fit_content() -> Value {
  FitContent
}

///|
pub fn Node::set_display(self : Node, v : Display) -> Unit {
  self.style.display = v
}

///|
/// 设为 Absolute 时该子项脱离文档流，按 top/right/bottom/left 相对父容器
/// padding box 定位；四向全 auto 时落在静态位置（按父容器
/// justify-content / align-items 摆放一个虚拟项）。
pub fn Node::set_position(self : Node, v : PositionType) -> Unit {
  self.style.position = v
}

///|
pub fn Node::set_top(self : Node, v : Value) -> Unit {
  self.style.top = v
}

///|
pub fn Node::set_right(self : Node, v : Value) -> Unit {
  self.style.right = v
}

///|
pub fn Node::set_bottom(self : Node, v : Value) -> Unit {
  self.style.bottom = v
}

///|
pub fn Node::set_left(self : Node, v : Value) -> Unit {
  self.style.left = v
}

///|
/// 设本节点的书写方向：`Rtl` 让行容器的主轴起端落在右侧、列容器的交叉轴
/// 起端落在右侧（与 `RowReverse` 叠加时两番翻转回到左起端）。
/// 只管本节点排布子项，不继承、不改变子项自身的内容方向。
pub fn Node::set_direction(self : Node, v : Direction) -> Unit {
  self.style.direction = v
}

///|
pub fn Node::set_flex_direction(self : Node, v : FlexDirection) -> Unit {
  self.style.flex_direction = v
}

///|
pub fn Node::set_flex_wrap(self : Node, v : FlexWrap) -> Unit {
  self.style.flex_wrap = v
}

///|
/// 一次设置 flex 三要素（grow / shrink / basis）。
pub fn Node::set_flex(
  self : Node,
  grow : Double,
  shrink : Double,
  basis : Value,
) -> Unit {
  self.style.flex_grow = grow
  self.style.flex_shrink = shrink
  self.style.flex_basis = basis
}

///|
pub fn Node::set_flex_grow(self : Node, v : Double) -> Unit {
  self.style.flex_grow = v
}

///|
pub fn Node::set_flex_shrink(self : Node, v : Double) -> Unit {
  self.style.flex_shrink = v
}

///|
pub fn Node::set_flex_basis(self : Node, v : Value) -> Unit {
  self.style.flex_basis = v
}

///|
pub fn Node::set_justify_content(self : Node, v : JustifyContent) -> Unit {
  self.style.justify_content = v
}

///|
pub fn Node::set_align_items(self : Node, v : AlignItems) -> Unit {
  self.style.align_items = v
}

///|
/// 覆盖自身在父容器交叉轴的对齐（None = 跟随父容器 align-items）。
pub fn Node::set_align_self(self : Node, v : Option[AlignItems]) -> Unit {
  self.style.align_self = v
}

///|
/// 多行时的整行对齐（仅 flex-wrap 开启且有确定交叉轴尺寸时生效）。
pub fn Node::set_align_content(self : Node, v : AlignContent) -> Unit {
  self.style.align_content = v
}

///|
pub fn Node::set_width(self : Node, v : Value) -> Unit {
  self.style.width = v
}

///|
pub fn Node::set_height(self : Node, v : Value) -> Unit {
  self.style.height = v
}

///|
pub fn Node::set_min_width(self : Node, v : Value) -> Unit {
  self.style.min_width = v
}

///|
pub fn Node::set_min_height(self : Node, v : Value) -> Unit {
  self.style.min_height = v
}

///|
pub fn Node::set_max_width(self : Node, v : Value) -> Unit {
  self.style.max_width = v
}

///|
pub fn Node::set_max_height(self : Node, v : Value) -> Unit {
  self.style.max_height = v
}

///|
/// 首选宽高比。比例语义为 **border-box**：`ratio = 边框盒宽 / 边框盒高`
/// （与 CSS 默认的 content-box 比例不同）。一个轴尺寸确定时，另一个轴按
/// 比例换算；`None` 表示不设比例，非正数视同 `None`。
pub fn Node::set_aspect_ratio(self : Node, ratio : Option[Double]) -> Unit {
  self.style.aspect_ratio = match ratio {
    Some(r) => if r > 0.0 { Some(r) } else { None }
    None => None
  }
}

///|
pub fn Node::set_margin_left(self : Node, v : Value) -> Unit {
  self.style.margin.left = v
}

///|
pub fn Node::set_margin_right(self : Node, v : Value) -> Unit {
  self.style.margin.right = v
}

///|
pub fn Node::set_margin_top(self : Node, v : Value) -> Unit {
  self.style.margin.top = v
}

///|
pub fn Node::set_margin_bottom(self : Node, v : Value) -> Unit {
  self.style.margin.bottom = v
}

///|
pub fn Node::set_padding_left(self : Node, v : Value) -> Unit {
  self.style.padding.left = v
}

///|
pub fn Node::set_padding_right(self : Node, v : Value) -> Unit {
  self.style.padding.right = v
}

///|
pub fn Node::set_padding_top(self : Node, v : Value) -> Unit {
  self.style.padding.top = v
}

///|
pub fn Node::set_padding_bottom(self : Node, v : Value) -> Unit {
  self.style.padding.bottom = v
}

///|
pub fn Node::set_border_left(self : Node, v : Value) -> Unit {
  self.style.border.left = v
}

///|
pub fn Node::set_border_right(self : Node, v : Value) -> Unit {
  self.style.border.right = v
}

///|
pub fn Node::set_border_top(self : Node, v : Value) -> Unit {
  self.style.border.top = v
}

///|
pub fn Node::set_border_bottom(self : Node, v : Value) -> Unit {
  self.style.border.bottom = v
}

///|
/// 行间距（交叉轴方向行与行之间）与列间距（主轴方向项与项之间）。
pub fn Node::set_gap(self : Node, row : Double, column : Double) -> Unit {
  self.style.row_gap = row
  self.style.column_gap = column
}

///|
pub fn Node::set_row_gap(self : Node, v : Double) -> Unit {
  self.style.row_gap = v
}

///|
pub fn Node::set_column_gap(self : Node, v : Double) -> Unit {
  self.style.column_gap = v
}

///|
/// 对整棵树做一次布局。width/height 为根节点可用空间（None 表示该方向
/// 不约束，根按内容取尺寸）；需要撑满可用空间时给根设置
/// `set_width(percent(100.0))` / `set_height(percent(100.0))`。
pub fn calculate_layout(
  root : Node,
  width : Option[Double],
  height : Option[Double],
) -> Unit {
  // 测量缓存只在单次布局内有效：入口先整体清一次
  clear_measure_cache(root)
  let _ = layout_into(root, width, height, None, None)
  root.layout_left = 0.0
  root.layout_top = 0.0
  if root.pixel_grid > 0.0 {
    round_to_grid(root, root.pixel_grid, 0.0, 0.0, 0.0, 0.0)
  }
}
