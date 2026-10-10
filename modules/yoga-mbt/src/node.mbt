// 布局节点树与布局结果。

///|
/// 已计算的布局结果。left/top 相对父节点边框盒左上角；
/// 根节点 left/top 恒为 0。width/height 为边框盒尺寸。
pub struct Layout {
  left : Double
  top : Double
  width : Double
  height : Double
}

///|
/// 布局树节点。
///
/// 叶子节点（无子节点）可通过 `set_measure` 提供内容尺寸测量函数：
/// 入参为可用宽高（`None` 表示该方向不受约束），返回内容宽高
/// （不含节点自身的 margin/padding/border，由引擎负责叠加）。
/// 文本类叶子还可通过 `set_baseline` 提供基线位置，供父容器做
/// `align-items / align-self: baseline` 对齐。
pub struct Node {
  style : Style
  children : Array[Node]
  mut measure : Option[(Option[Double], Option[Double]) -> (Double, Double)]
  mut baseline_fn : Option[(Option[Double], Option[Double]) -> Option[Double]]
  // 本次布局算出的基线（到本节点边框盒顶部的距离），None = 无基线
  mut baseline : Option[Double]
  // 测量缓存：键 = (可用宽, 可用高)，值 = (宽, 高, 基线)。
  // 单次 calculate_layout 内有效，入口会整体清空（样式可能在两次布局间被改）
  measure_cache : Array[((Option[Double], Option[Double]), (Double, Double, Option[Double]))]
  mut layout_left : Double
  mut layout_top : Double
  mut layout_width : Double
  mut layout_height : Double
}

///|
pub fn Node::new() -> Node {
  {
    style : Style::new(),
    children : [],
    measure : None,
    baseline_fn : None,
    baseline : None,
    measure_cache : [],
    layout_left : 0.0,
    layout_top : 0.0,
    layout_width : 0.0,
    layout_height : 0.0,
  }
}

///|
/// 追加子节点。
pub fn Node::append_child(self : Node, child : Node) -> Unit {
  self.children.push(child)
}

///|
/// 移除全部子节点。
pub fn Node::clear_children(self : Node) -> Unit {
  self.children.clear()
}

///|
/// 子节点快照。
pub fn Node::children(self : Node) -> Array[Node] {
  self.children.copy()
}

///|
/// 设置叶子节点内容测量函数。
pub fn Node::set_measure(
  self : Node,
  f : (Option[Double], Option[Double]) -> (Double, Double),
) -> Unit {
  self.measure = Some(f)
}

///|
/// 设置叶子节点基线测量函数。入参与 `set_measure` 相同（可用宽高，
/// `None` 表示该方向不约束），返回**基线到内容盒顶部**的距离
/// （不含自身 padding/border，引擎负责叠加）；返回 `None` 表示无基线。
/// 仅对叶子节点生效；容器节点的基线由引擎按规范从内部项推出。
pub fn Node::set_baseline(
  self : Node,
  f : (Option[Double], Option[Double]) -> Option[Double],
) -> Unit {
  self.baseline_fn = Some(f)
}

///|
/// 读取已计算的布局结果（须先调用 `calculate_layout`）。
pub fn Node::layout(self : Node) -> Layout {
  {
    left : self.layout_left,
    top : self.layout_top,
    width : self.layout_width,
    height : self.layout_height,
  }
}
