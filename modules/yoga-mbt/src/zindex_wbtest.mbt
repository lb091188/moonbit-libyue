// z_index（层序键）回归：正序 / 负值 / 并列稳定；z_index 不参与布局几何。

///|
fn eq_ints(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut ok = true
  let mut i = 0
  while i < a.length() {
    if a[i] != b[i] {
      ok = false
    }
    i += 1
  }
  ok
}

///|
fn row_root_w3(z : Array[Int]) -> (Node, Array[Node]) {
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.set_height(fixed(100.0))
  root.set_flex_direction(Row)
  let ks : Array[Node] = []
  for v in z {
    let k = Node::new()
    k.set_width(fixed(50.0))
    k.set_height(fixed(50.0))
    k.set_z_index(v)
    root.append_child(k)
    ks.push(k)
  }
  (root, ks)
}

///|
test "z_index 默认 0，读回一致；负值/正值照写入" {
  let a = Node::new()
  assert_eq(a.z_index(), 0)
  a.set_z_index(-3)
  assert_eq(a.z_index(), -3)
  a.set_z_index(7)
  assert_eq(a.z_index(), 7)
}

///|
test "paint_order：升序，负值垫前，并列保持 children 原序（稳定）" {
  // z = [0, 2, -1, 2, 0] → 期望下标 [2, 0, 4, 1, 3]
  let (root, _ks) = row_root_w3([0, 2, -1, 2, 0])
  let order = root.paint_order()
  assert_true(eq_ints(order, [2, 0, 4, 1, 3]))
}

///|
test "paint_order：全 0 即恒等序（后加者仍画在前）" {
  let (root, _ks) = row_root_w3([0, 0, 0])
  assert_true(eq_ints(root.paint_order(), [0, 1, 2]))
}

///|
test "z_index 不改布局几何（不参与 flex 计算）" {
  let (root_a, ks_a) = row_root_w3([0, 0, 0])
  let (root_b, ks_b) = row_root_w3([5, -2, 0])
  calculate_layout(root_a, Some(300.0), Some(100.0))
  calculate_layout(root_b, Some(300.0), Some(100.0))
  for i in [0, 1, 2] {
    assert_eq(ks_a[i].layout().left, ks_b[i].layout().left)
    assert_eq(ks_a[i].layout().top, ks_b[i].layout().top)
    assert_eq(ks_a[i].layout().width, ks_b[i].layout().width)
  }
}
