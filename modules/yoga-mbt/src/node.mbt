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
pub struct Node {
  style : Style
  children : Array[Node]
  mut measure : Option[(Option[Double], Option[Double]) -> (Double, Double)]
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
/// 读取已计算的布局结果（须先调用 `calculate_layout`）。
pub fn Node::layout(self : Node) -> Layout {
  {
    left : self.layout_left,
    top : self.layout_top,
    width : self.layout_width,
    height : self.layout_height,
  }
}
