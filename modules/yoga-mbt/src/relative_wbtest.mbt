// 相对定位（position: relative + top/left/right/bottom 偏移）回归：
// 偏移只改落位、不改常规流占位，同轴两端都给值时 top/left 胜。

///|
fn col_root(w : Double, h : Double) -> Node {
  let n = Node::new()
  n.set_width(fixed(w))
  n.set_height(fixed(h))
  n.set_flex_direction(Column)
  n
}

///|
test "relative top 只平移落位，后续兄弟与容器尺寸都不动" {
  let root = col_root(300.0, 200.0)
  let a = Node::new()
  a.set_width(fixed(100.0))
  a.set_height(fixed(50.0))
  a.set_position(Relative)
  a.set_top(fixed(30.0))
  let b = Node::new()
  b.set_width(fixed(100.0))
  b.set_height(fixed(20.0))
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq(a.layout().top, 30.0)
  // b 仍按静态位置排（a 的偏移不占流内空间）
  assert_eq(b.layout().top, 50.0)
  assert_eq(b.layout().left, 0.0)
}

///|
test "relative left 可为负、auto 即不偏移" {
  let root = col_root(300.0, 200.0)
  let a = Node::new()
  a.set_width(fixed(100.0))
  a.set_height(fixed(50.0))
  a.set_position(Relative)
  a.set_left(fixed(-20.0))
  let b = Node::new()
  b.set_width(fixed(60.0))
  b.set_height(fixed(10.0))
  b.set_position(Relative)
  root.append_child(a)
  root.append_child(b)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq((a.layout().left, a.layout().top), (-20.0, 0.0))
  assert_eq((b.layout().left, b.layout().top), (0.0, 50.0))
}

///|
test "同轴两端都给值时 top/left 胜，只给 bottom/right 则反向偏移" {
  let root = col_root(300.0, 200.0)
  let both = Node::new()
  both.set_width(fixed(80.0))
  both.set_height(fixed(40.0))
  both.set_position(Relative)
  both.set_top(fixed(12.0))
  both.set_bottom(fixed(99.0))
  let only_bottom = Node::new()
  only_bottom.set_width(fixed(80.0))
  only_bottom.set_height(fixed(40.0))
  only_bottom.set_position(Relative)
  only_bottom.set_bottom(fixed(10.0))
  let only_right = Node::new()
  only_right.set_width(fixed(80.0))
  only_right.set_height(fixed(40.0))
  only_right.set_position(Relative)
  only_right.set_right(fixed(6.0))
  root.append_child(both)
  root.append_child(only_bottom)
  root.append_child(only_right)
  calculate_layout(root, Some(300.0), Some(200.0))
  assert_eq((both.layout().top, both.layout().left), (12.0, 0.0))
  assert_eq(only_bottom.layout().top, 40.0 - 10.0)
  assert_eq(only_right.layout().left, -6.0)
}

///|
test "relative 百分比按父内容盒解，绝对定位项不吃这套偏移" {
  let root = col_root(400.0, 200.0)
  root.set_padding_top(fixed(20.0))
  root.set_padding_left(fixed(20.0))
  let pct = Node::new()
  pct.set_width(fixed(100.0))
  pct.set_height(fixed(40.0))
  pct.set_position(Relative)
  pct.set_top(Percent(25.0))
  pct.set_left(Percent(10.0))
  let abs = Node::new()
  abs.set_width(fixed(30.0))
  abs.set_height(fixed(30.0))
  abs.set_position(Absolute)
  abs.set_top(fixed(5.0))
  root.append_child(pct)
  root.append_child(abs)
  calculate_layout(root, Some(400.0), Some(200.0))
  // 父内容盒 = 400-20 宽、200-20 高（padding 只给上左各 20）
  assert_eq(pct.layout().top, 20.0 + 180.0 * 0.25)
  assert_eq(pct.layout().left, 20.0 + 380.0 * 0.10)
  // 绝对项的 top 是 inset（从 padding 盒起端量，父 padding 不参与），
  // 与相对项的「静态位置（含父 padding）+ 偏移」是两套参照
  assert_eq(abs.layout().top, 5.0)
}
