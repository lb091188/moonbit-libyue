// 布局算法测试：预期值均按 CSS Flexbox 规则手算。

///|
/// 固定内容尺寸的叶子节点。
fn leaf(w : Double, h : Double) -> Node {
  let n = Node::new()
  n.set_measure(fn(_aw, _ah) { (w, h) })
  n
}

///|
test "固定尺寸子项" {
  let root = Node::new()
  root.set_width(fixed(800.0))
  root.set_height(fixed(600.0))
  let c = leaf(300.0, 200.0)
  root.append_child(c)
  calculate_layout(root, Some(800.0), Some(600.0))
  assert_eq(c.layout().left, 0.0)
  assert_eq(c.layout().top, 0.0)
  assert_eq(c.layout().width, 300.0)
  // align-items 默认 stretch + 容器交叉轴确定 → 撑满 600
  assert_eq(c.layout().height, 600.0)
}

///|
test "grow 均分剩余空间 + 交叉轴拉伸" {
  let root = Node::new()
  root.set_width(fixed(500.0))
  root.set_height(fixed(200.0))
  let c1 = leaf(100.0, 50.0)
  c1.set_flex_grow(1.0)
  let c2 = leaf(200.0, 50.0)
  c2.set_flex_grow(1.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(500.0), Some(200.0))
  assert_eq(c1.layout().width, 200.0)
  assert_eq(c2.layout().width, 300.0)
  assert_eq(c2.layout().left, 200.0)
  assert_eq(c1.layout().height, 200.0)
}

///|
test "shrink 按基准加权收缩" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  let c1 = leaf(200.0, 50.0)
  let c2 = leaf(200.0, 50.0)
  // min-width:auto 会以内容尺寸为收缩下限，这里显式放开
  c1.set_min_width(fixed(0.0))
  c2.set_min_width(fixed(0.0))
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c1.layout().width, 150.0)
  assert_eq(c2.layout().width, 150.0)
  assert_eq(c2.layout().left, 150.0)
}

///|
test "justify 与 align 居中" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(200.0))
  root.set_justify_content(Center)
  root.set_align_items(Center)
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(200.0))
  assert_eq(c.layout().left, 150.0)
  assert_eq(c.layout().top, 75.0)
}

///|
test "百分比尺寸" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(200.0))
  let c = leaf(0.0, 0.0)
  c.set_width(percent(50.0))
  c.set_height(percent(25.0))
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(200.0))
  assert_eq(c.layout().width, 200.0)
  assert_eq(c.layout().height, 50.0)
}

///|
test "wrap 换行 + align-content stretch" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(200.0))
  root.set_flex_wrap(Wrap)
  let c1 = leaf(200.0, 50.0)
  let c2 = leaf(200.0, 50.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(c1.layout().top, 0.0)
  assert_eq(c1.layout().height, 100.0)
  assert_eq(c2.layout().top, 100.0)
  assert_eq(c2.layout().height, 100.0)
  assert_eq(c2.layout().left, 0.0)
}

///|
test "margin auto 吸收主轴剩余空间" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  let c = leaf(100.0, 50.0)
  c.set_margin_left(auto())
  c.set_margin_right(auto())
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c.layout().left, 150.0)
}

///|
test "padding 偏移子项" {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_padding_left(fixed(10.0))
  root.set_padding_top(fixed(10.0))
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(300.0), Some(100.0))
  assert_eq(c.layout().left, 10.0)
  assert_eq(c.layout().top, 10.0)
}

///|
test "主轴 min:auto 内容下限阻止收缩" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(50.0))
  let c = leaf(200.0, 20.0)
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(50.0))
  assert_eq(c.layout().width, 200.0)
  assert_eq(c.layout().height, 50.0)
}

///|
test "显式 min-width 0 允许收缩到内容以下" {
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_height(fixed(50.0))
  let c = leaf(200.0, 20.0)
  c.set_min_width(fixed(0.0))
  root.append_child(c)
  calculate_layout(root, Some(100.0), Some(50.0))
  assert_eq(c.layout().width, 100.0)
}

///|
test "列间距 gap" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(50.0))
  root.set_column_gap(10.0)
  let c1 = leaf(100.0, 20.0)
  let c2 = leaf(100.0, 20.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(400.0), Some(50.0))
  assert_eq(c2.layout().left, 110.0)
}

///|
test "column 方向 + 交叉轴拉伸" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(400.0))
  root.set_flex_direction(Column)
  let c1 = leaf(50.0, 100.0)
  let c2 = leaf(50.0, 100.0)
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(200.0), Some(400.0))
  assert_eq(c1.layout().top, 0.0)
  assert_eq(c2.layout().top, 100.0)
  assert_eq(c1.layout().width, 200.0)
  assert_eq(c1.layout().height, 100.0)
}

///|
test "嵌套容器作为 flex 项（内容推算高度）" {
  let root = Node::new()
  root.set_width(fixed(600.0))
  root.set_height(fixed(200.0))
  let a = leaf(100.0, 100.0)
  let b = Node::new()
  b.set_width(fixed(200.0))
  b.set_flex_direction(Column)
  let b1 = leaf(50.0, 50.0)
  let b2 = leaf(50.0, 50.0)
  b.append_child(b1)
  b.append_child(b2)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(600.0), Some(200.0))
  assert_eq(b.layout().left, 100.0)
  assert_eq(b.layout().width, 200.0)
  // b 高度 auto，随父容器 align-items:stretch 撑满行交叉尺寸 200
  assert_eq(b.layout().height, 200.0)
  assert_eq(b1.layout().top, 0.0)
  assert_eq(b1.layout().width, 200.0)
  assert_eq(b2.layout().top, 50.0)
}

///|
test "justify-content: space-between" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  root.set_justify_content(SpaceBetween)
  let c1 = leaf(100.0, 50.0)
  let c2 = leaf(100.0, 50.0)
  let c3 = leaf(100.0, 50.0)
  root.append_child(c1)
  root.append_child(c2)
  root.append_child(c3)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c1.layout().left, 0.0)
  assert_eq(c2.layout().left, 150.0)
  assert_eq(c3.layout().left, 300.0)
}

///|
test "row-reverse 主轴起端在右" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  root.set_flex_direction(RowReverse)
  let c = leaf(100.0, 50.0)
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c.layout().left, 300.0)
}

///|
test "根节点按内容取尺寸" {
  let root = Node::new()
  let c = leaf(120.0, 80.0)
  root.append_child(c)
  calculate_layout(root, None, None)
  assert_eq(root.layout().width, 120.0)
  assert_eq(root.layout().height, 80.0)
}

///|
test "max-width 收顶" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(100.0))
  let c = leaf(100.0, 50.0)
  c.set_flex_grow(1.0)
  c.set_max_width(fixed(250.0))
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(100.0))
  assert_eq(c.layout().width, 250.0)
}

///|
test "shrink 不低于 min-width 且负溢出" {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_height(fixed(50.0))
  let c1 = leaf(150.0, 30.0)
  c1.set_min_width(fixed(120.0))
  let c2 = leaf(150.0, 30.0)
  c2.set_min_width(fixed(0.0))
  root.append_child(c1)
  root.append_child(c2)
  calculate_layout(root, Some(200.0), Some(50.0))
  // 溢出 100：scaled = 150 + 150 = 300，c2 分摊 100*150/300 = 50 → 100
  // c1 同样分到 100 → 50 < min 120 → 冻结 120，重算：c2 再收缩 20 → 80
  assert_eq(c1.layout().width, 120.0)
  assert_eq(c2.layout().width, 80.0)
}

///|
test "align-self 覆盖 align-items" {
  let root = Node::new()
  root.set_width(fixed(400.0))
  root.set_height(fixed(200.0))
  root.set_align_items(FlexEnd)
  let c = leaf(100.0, 50.0)
  c.set_align_self(Some(Center))
  root.append_child(c)
  calculate_layout(root, Some(400.0), Some(200.0))
  assert_eq(c.layout().top, 75.0)
}
