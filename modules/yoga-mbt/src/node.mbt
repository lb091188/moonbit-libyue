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
///
/// 内在尺寸（min-content / max-content）用同一测量函数探询，约定：
/// - max-content：两个入参都给 `None`（不受约束），返回内容不折行的宽高；
/// - min-content：请求的那一轴给 `Some(0.0)`、另一轴给 `None`，
///   测量函数应返回「该轴不溢出的最小尺寸」（文本即最长词宽、图片即原始宽）。
/// 忽略入参、恒返回固定尺寸的测量函数，其 min-content 与 max-content 相同。
pub struct Node {
  style : Style
  children : Array[Node]
  mut measure : Option[(Option[Double], Option[Double]) -> (Double, Double)]
  mut baseline_fn : Option[(Option[Double], Option[Double]) -> Option[Double]]
  // 本次布局算出的基线（到本节点边框盒顶部的距离），None = 无基线
  mut baseline : Option[Double]
  // 像素网格取整间隔（0 = 关闭）；只有作为布局根节点的设置生效
  mut pixel_grid : Double
  // 测量缓存：键 = (可用宽, 可用高)，值 = (宽, 高, 基线)。
  // **跨布局驻留**：有效性由节点的版本面判定（见 cache_rev），样式没变的
  // 子树在下一轮直接拿它，测量回调（文本即 Pango）因此不必每帧重跑
  measure_cache : Array[((Option[Double], Option[Double]), (Double, Double, Option[Double]))]
  // 内在尺寸缓存：键 = ((请求行轴?, 求 min-content?), (宽参照, 高参照))，
  // 值 = 边框盒尺寸。与测量缓存同一失效时机（cache_rev）
  intrinsic_cache : Array[(((Bool, Bool), (Option[Double], Option[Double])), Double)]
  mut layout_left : Double
  mut layout_top : Double
  mut layout_width : Double
  mut layout_height : Double
  // ---- 变更通知面（脏区增量重排与缓存驻留的判据，见 algorithm.mbt）----
  // 本节点最后一次「自身变更」的时钟值（样式 setter、增删子项、换测量回调）
  mut rev : Int
  // 本次扫描算出的「本节点子树内最大 rev」
  mut subtree_rev : Int
  // 两份缓存当前所属的 subtree_rev：不等先整体清一次。祖先的内在尺寸依赖
  // 子孙，子孙一变祖先就该废——靠它替代「父指针往上清」的形态
  mut cache_rev : Int
  // 上次完整布局本节点时的 subtree_rev / 入参指纹 / 返回值（跳过判据）
  mut laid_rev : Int
  mut laid : Bool
  mut laid_fp : (Option[Double], Option[Double], Option[Double], Option[Double])
  // 上次 `layout_into` 返回的边框盒尺寸，取整**前**的值：layout_width/height
  // 会被像素网格后处理改写，跳过时必须还它取整前的原值
  mut laid_size : (Double, Double)
}

///|
pub fn Node::new() -> Node {
  {
    style : Style::new(),
    children : [],
    measure : None,
    baseline_fn : None,
    baseline : None,
    pixel_grid : 0.0,
    measure_cache : [],
    intrinsic_cache : [],
    layout_left : 0.0,
    layout_top : 0.0,
    layout_width : 0.0,
    layout_height : 0.0,
    rev : 0,
    subtree_rev : 0,
    cache_rev : 0,
    laid_rev : -1,
    laid : false,
    laid_fp : (None, None, None, None),
    laid_size : (0.0, 0.0),
  }
}

// 全局变更时钟。用 `Ref` 而不是顶层可变绑定：跨文件可见性一致，且
// 顶层 `let mut` 在本工具链不是稳定写法。
let rev_clock : Ref[Int] = Ref(0)

///|
/// 记一次「本节点自身发生变更」。不标自身的话，子树扫描看不出这里变过；
/// 也不走「往上标脏」的传统形态——父指针会与 `children` 成引用环，
/// 本工具链的回收处理不了环，长驻 GUI 里就是稳定泄漏。
fn Node::mark_changed(self : Node) -> Unit {
  rev_clock.val = rev_clock.val + 1
  self.rev = rev_clock.val
}

///|
/// 追加子节点。
pub fn Node::append_child(self : Node, child : Node) -> Unit {
  self.children.push(child)
  self.mark_changed()
}

///|
/// 移除全部子节点。
pub fn Node::clear_children(self : Node) -> Unit {
  self.children.clear()
  self.mark_changed()
}

///|
/// 在 `index` 处插入子节点（`index` 越界时按首/尾钳制）。
/// 与 `append_child` 的区别只在于**位置**：声明式层的就地替换
/// （bind_node 重挂）要在原位换节点，才能让兄弟项的排布与坐标不变。
pub fn Node::insert_child(self : Node, index : Int, child : Node) -> Unit {
  let n = self.children.length()
  let at = if index < 0 { 0 } else if index > n { n } else { index }
  self.children.insert(at, child)
  self.mark_changed()
}

///|
/// 移除 `index` 处的子节点并返回它；下标越界返回 None（不做任何改动）。
pub fn Node::remove_child_at(self : Node, index : Int) -> Node? {
  let n = self.children.length()
  if index < 0 || index >= n {
    return None
  }
  let removed = self.children.remove(index)
  self.mark_changed()
  Some(removed)
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
  self.mark_changed()
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
  self.mark_changed()
}

///|
/// 设像素网格取整间隔：布局完成后，节点的绝对边框按该间隔取整再回推
/// 相对坐标（相邻项共用边取整一致，不会出现 1px 缝）。
/// `0.0`（默认）或负数 = 不取整，保留小数；只有作为布局根节点的设置生效，
/// 间隔为 1.0 即整像素对齐，0.5 即半像素。
pub fn Node::set_pixel_grid(self : Node, interval : Double) -> Unit {
  self.pixel_grid = if interval > 0.0 { interval } else { 0.0 }
  self.mark_changed()
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
