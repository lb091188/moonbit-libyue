// 脏区增量重排与缓存跨布局驻留的回归。
//
// 取向：跳过路径**只断言与「从零全量布局的参考树」逐节点一致**——增量布局
// 唯一的正确性标准就是「和全量算出来一模一样」，不额外断言中间状态。
// 另断「测量回调调用次数」作为性能面（不驻留就会每轮重跑）。
//
// 建树函数一律带参数化状态，参考树按同一状态新建后再布局一次即全量口径。

///|
fn snapshot(n : Node, out : Array[(Double, Double, Double, Double)]) -> Unit {
  out.push((n.layout_left, n.layout_top, n.layout_width, n.layout_height))
  for c in n.children {
    snapshot(c, out)
  }
}

///|
/// 一列两行、每行「图标 + 文字 + 徽标」的树。`text_h` 参数化文字叶子的内容高
/// （模拟文本换行/内容变长），`hidden` 参数化第二行显隐。
/// 返回根节点与两处可变探针（第一行的文字叶子、第二行整行）。
fn build_sample(
  text_h : Double,
  hidden : Bool,
  calls : Ref[Int],
) -> (Node, Node, Node) {
  let root = Node::new()
  root.set_width(fixed(200.0))
  root.set_flex_direction(FlexDirection::Column)
  root.set_row_gap(4.0)
  let mut probe_text = root
  let mut probe_row = root
  for i in 0..<2 {
    let row = Node::new()
    row.set_height(fixed(24.0))
    row.set_align_items(AlignItems::Baseline)
    if i == 1 && hidden {
      row.set_display(Display::None)
    }
    let icon = Node::new()
    icon.set_measure(fn(_a, _b) { (16.0, 16.0) })
    row.append_child(icon)
    let txt = Node::new()
    txt.set_measure(fn(_a, _b) {
      calls.val = calls.val + 1
      (60.0, text_h)
    })
    txt.set_baseline(fn(_a, _b) { Some(text_h - 3.0) })
    txt.set_flex_grow(1.0)
    row.append_child(txt)
    let badge = Node::new()
    badge.set_measure(fn(_a, _b) { (20.0, 12.0) })
    row.append_child(badge)
    root.append_child(row)
    if i == 0 {
      probe_text = txt
    } else {
      probe_row = row
    }
  }
  (root, probe_text, probe_row)
}

///|
/// 叶子内容宽随可用宽变化的探针树：缓存若串了宽度立刻看得出来。
fn build_width_probe(calls : Ref[Int]) -> Node {
  let root = Node::new()
  root.set_flex_direction(FlexDirection::Column)
  let leaf = Node::new()
  leaf.set_measure(fn(avail, _h) {
    calls.val = calls.val + 1
    match avail {
      Some(w) => (w * 0.5, 10.0)
      None => (50.0, 10.0)
    }
  })
  root.append_child(leaf)
  root
}

///|
test "同参数重复布局：结果一致，测量回调不再调用" {
  let calls = Ref(0)
  let (root, _, _) = build_sample(18.0, false, calls)
  calculate_layout(root, Some(200.0), None)
  let after_first = calls.val
  assert_true(after_first > 0)
  let a : Array[(Double, Double, Double, Double)] = []
  snapshot(root, a)

  calculate_layout(root, Some(200.0), None)
  let b : Array[(Double, Double, Double, Double)] = []
  snapshot(root, b)
  assert_eq(a, b)
  // 整棵树没变 → 一个测量都不该再跑（缓存与子树结果跨布局驻留）
  assert_eq(calls.val, after_first)
}

///|
test "改一个叶子的内容：增量结果与从零全量布局逐节点一致" {
  let calls = Ref(0)
  let (root, probe_text, _) = build_sample(18.0, false, calls)
  calculate_layout(root, Some(200.0), None)
  // 让第一行的文字变高（内容变更 = 换测量回调，会标脏自身与祖先链）
  probe_text.set_measure(fn(_a, _b) { (60.0, 40.0) })
  probe_text.set_baseline(fn(_a, _b) { Some(37.0) })
  calculate_layout(root, Some(200.0), None)
  let got : Array[(Double, Double, Double, Double)] = []
  snapshot(root, got)

  // 参考：同一状态新建一棵树，只布局一次（全量口径）
  let (ref_root, ref_text, _) = build_sample(18.0, false, Ref(0))
  ref_text.set_measure(fn(_a, _b) { (60.0, 40.0) })
  ref_text.set_baseline(fn(_a, _b) { Some(37.0) })
  calculate_layout(ref_root, Some(200.0), None)
  let want : Array[(Double, Double, Double, Double)] = []
  snapshot(ref_root, want)
  assert_eq(got, want)
}

///|
test "未受影响的兄弟子树不再测量，变过的那一支照样测" {
  let calls = Ref(0)
  let (root, probe_text, _) = build_sample(18.0, false, calls)
  calculate_layout(root, Some(200.0), None)
  let after_first = calls.val
  // 只动第一行的文字：第二行整行没变
  probe_text.set_height(fixed(30.0))
  calculate_layout(root, Some(200.0), None)
  // 变的那一支要重测（否则尺寸是旧的），没变的那一支一次都不该测
  assert_true(calls.val > after_first)
  let rows = root.children
  let second_row_h = rows[1].layout().height
  assert_eq(second_row_h, 24.0)
}

///|
test "根宽变化（拖窗）：全树重排且与参考一致" {
  let (root, _, _) = build_sample(18.0, false, Ref(0))
  calculate_layout(root, Some(200.0), None)
  calculate_layout(root, Some(90.0), None)
  let got : Array[(Double, Double, Double, Double)] = []
  snapshot(root, got)

  let (ref_root, _, _) = build_sample(18.0, false, Ref(0))
  calculate_layout(ref_root, Some(90.0), None)
  let want : Array[(Double, Double, Double, Double)] = []
  snapshot(ref_root, want)
  assert_eq(got, want)
}

///|
test "像素网格开着走跳过路径：取整结果仍与全量一致" {
  let calls = Ref(0)
  let (root, probe_text, _) = build_sample(18.0, false, calls)
  root.set_pixel_grid(1.0)
  calculate_layout(root, Some(100.0), None)
  probe_text.set_height(fixed(19.0))
  calculate_layout(root, Some(100.0), None)
  let got : Array[(Double, Double, Double, Double)] = []
  snapshot(root, got)

  let (ref_root, ref_text, _) = build_sample(18.0, false, Ref(0))
  ref_root.set_pixel_grid(1.0)
  ref_text.set_height(fixed(19.0))
  calculate_layout(ref_root, Some(100.0), None)
  let want : Array[(Double, Double, Double, Double)] = []
  snapshot(ref_root, want)
  assert_eq(got, want)
  // 网格生效：所有边框都落在整数上
  for e in got {
    assert_eq((e.0.round(), e.1.round(), e.2.round(), e.3.round()), e)
  }
}

///|
test "隐藏再显示：重显子树拿到新坐标，不残留上一轮的" {
  let (root, _, probe_row) = build_sample(18.0, false, Ref(0))
  calculate_layout(root, Some(200.0), None)
  probe_row.set_display(Display::None)
  calculate_layout(root, Some(200.0), None)
  probe_row.set_display(Display::Flex)
  calculate_layout(root, Some(200.0), None)
  let got : Array[(Double, Double, Double, Double)] = []
  snapshot(root, got)

  let (ref_root, _, _) = build_sample(18.0, false, Ref(0))
  calculate_layout(ref_root, Some(200.0), None)
  let want : Array[(Double, Double, Double, Double)] = []
  snapshot(ref_root, want)
  assert_eq(got, want)
}

///|
test "自身样式变更要作废本节点缓存（内在尺寸递归结果跟着变）" {
  let (root, _, _) = build_sample(18.0, false, Ref(0))
  // min-content 走内在尺寸缓存：先记一轮值
  root.set_width(min_content())
  calculate_layout(root, None, None)
  let w0 = root.layout().width
  assert_true(w0 > 0.0)
  // 改 padding 后同一份内在缓存必须作废，否则宽度还是旧值
  root.set_padding_left(fixed(20.0))
  calculate_layout(root, None, None)
  assert_eq(root.layout().width, w0 + 20.0)
}

///|
test "结构变更：新增子项与清空子项都不会被跳过路径藏起来" {
  let (root, _, _) = build_sample(18.0, false, Ref(0))
  calculate_layout(root, Some(200.0), None)
  let extra = Node::new()
  extra.set_height(fixed(30.0))
  root.append_child(extra)
  calculate_layout(root, Some(200.0), None)
  assert_eq(root.children.length(), 3)
  assert_eq(root.children[2].layout().height, 30.0)
  assert_eq(root.layout().height, 24.0 + 4.0 + 24.0 + 4.0 + 30.0)

  root.clear_children()
  calculate_layout(root, Some(200.0), None)
  assert_eq(root.layout().height, 0.0)
}

///|
/// 一行两个 100×20 的盒子（第二个左边距 50）与一棵可搬移的子树。
fn boxes_and_inner() -> (Node, Node, Node, Node) {
  let box_a = Node::new()
  box_a.set_width(fixed(100.0))
  box_a.set_height(fixed(20.0))
  let box_b = Node::new()
  box_b.set_width(fixed(100.0))
  box_b.set_height(fixed(20.0))
  box_b.set_margin_left(fixed(50.0))
  let root = Node::new()
  root.set_width(fixed(300.0))
  root.append_child(box_a)
  root.append_child(box_b)
  let inner = Node::new()
  inner.set_width(fixed(40.0))
  inner.set_height(fixed(10.0))
  let leaf = Node::new()
  leaf.set_measure(fn(_a, _b) { (8.0, 8.0) })
  inner.append_child(leaf)
  (root, box_a, box_b, inner)
}

///|
test "子树在两个父容器之间搬移：坐标由新父改写，内部结果照常复用" {
  let (root, box_a, box_b, inner) = boxes_and_inner()
  box_a.append_child(inner)
  calculate_layout(root, Some(300.0), None)
  assert_eq((inner.layout().left, inner.layout().top), (0.0, 0.0))

  box_a.clear_children()
  box_b.append_child(inner)
  calculate_layout(root, Some(300.0), None)
  let got : Array[(Double, Double, Double, Double)] = []
  snapshot(root, got)

  // 参考：直接按最终结构新建一棵树，只布局一次（全量口径，没有任何复用）
  let (r2, a2, b2, i2) = boxes_and_inner()
  a2.clear_children()
  b2.append_child(i2)
  calculate_layout(r2, Some(300.0), None)
  let want : Array[(Double, Double, Double, Double)] = []
  snapshot(r2, want)
  assert_eq(got, want)
  // 搬移确实生效：inner 相对新父仍是 (0,0)，新父自己被排在行尾并带边距
  assert_eq((inner.layout().left, inner.layout().top), (0.0, 0.0))
  assert_eq(box_b.layout().left, 150.0)
}

///|
test "可用宽连续变化（越过缓存槽位上限）：每轮都等于同宽度的全量结果" {
  let calls = Ref(0)
  let root = build_width_probe(calls)
  for i = 10; i < 60; i = i + 3 {
    let w = i.to_double()
    calculate_layout(root, Some(w), None)
    let got : Array[(Double, Double, Double, Double)] = []
    snapshot(root, got)

    let fresh = build_width_probe(Ref(0))
    calculate_layout(fresh, Some(w), None)
    let want : Array[(Double, Double, Double, Double)] = []
    snapshot(fresh, want)
    assert_eq(got, want)
  }
  // 每个新宽度都得真测（缓存丢旧不丢新，测量次数只增不减）
  assert_true(calls.val >= 17)
}

///|
test "原位增删子节点：insert_child / remove_child_at 与参考树一致" {
  let a = Node::new()
  a.set_height(fixed(10.0))
  let b = Node::new()
  b.set_height(fixed(20.0))
  let c = Node::new()
  c.set_height(fixed(30.0))
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_flex_direction(FlexDirection::Column)
  root.append_child(a)
  root.append_child(b)
  root.append_child(c)
  calculate_layout(root, Some(100.0), None)
  assert_eq(root.layout().height, 60.0)

  // 摘掉中间项，再原位插回
  let removed = root.remove_child_at(1)
  assert_true(removed is Some(_))
  calculate_layout(root, Some(100.0), None)
  assert_eq(root.layout().height, 40.0)
  assert_eq((a.layout().top, c.layout().top), (0.0, 10.0))
  root.insert_child(1, b)
  calculate_layout(root, Some(100.0), None)
  let got : Array[(Double, Double, Double, Double)] = []
  snapshot(root, got)

  let (ref_root, ra, rb, rc) = three_rows()
  calculate_layout(ref_root, Some(100.0), None)
  let want : Array[(Double, Double, Double, Double)] = []
  snapshot(ref_root, want)
  assert_eq(got, want)
  assert_eq((ra.layout().height, rb.layout().height, rc.layout().height),
            (10.0, 20.0, 30.0))

  // 越界：删除不动树，插入按尾钳制
  assert_true(root.remove_child_at(9) is None)
  assert_eq(root.children().length(), 3)
  let d = Node::new()
  d.set_height(fixed(5.0))
  root.insert_child(99, d)
  assert_eq(root.children().length(), 4)
  assert_eq(root.children()[3].layout().height, 0.0)
}

///|
/// 与上面同一形态的参考树（a/b/c 三行）。
fn three_rows() -> (Node, Node, Node, Node) {
  let a = Node::new()
  a.set_height(fixed(10.0))
  let b = Node::new()
  b.set_height(fixed(20.0))
  let c = Node::new()
  c.set_height(fixed(30.0))
  let root = Node::new()
  root.set_width(fixed(100.0))
  root.set_flex_direction(FlexDirection::Column)
  root.append_child(a)
  root.append_child(b)
  root.append_child(c)
  (root, a, b, c)
}
