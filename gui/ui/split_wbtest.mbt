// 分隔布局回归：把手拖动要跟手（增量按窗口坐标算），抬起后停手。

///|
fn split_mounted(
  node : @widget.Node,
  w : Double,
  h : Double,
) -> (@widget.Widget, @widget.Widget) {
  let root = @widget.Widget::new()
  root.set_size(w, h)
  root.set_column()
  let kid = node.mount_into(root)
  root.relayout(w, h)
  (root, kid)
}

///|
test "分隔把手：拖动增量按窗口坐标算、把手平移不把自己的位移扣掉" {
  let (root, w) = split_mounted(
    split(
      view([], width=100.0, height=20.0),
      view([], width=100.0, height=20.0),
      ratio=0.5,
    ),
    400.0,
    200.0,
  )
  let bar = w.children()[1]
  let x0 = bar.rect.x
  assert_true((x0 - 200.0).abs() < 1.0)
  // 起手必须命中把手（宿主按这个 id 进入捕获期）
  match root.hit_test(x0 + 4.0, 100.0) {
    Some(h) => assert_eq(h.id, bar.id)
    None => assert_true(false)
  }
  let send = fn(kind : @widget.PointerKind, x : Double) -> Unit {
    // 与宿主同款：按下时命中的控件在抬起前一直收事件（指针捕获期）
    let _ = root.dispatch_pointer_to(
      bar.id,
      { kind, x, y: 100.0, button: 1, mods: 0 },
    )
    let _ = root.relayout(400.0, 200.0)
  }
  send(@widget.PointerKind::Down, x0 + 4.0)
  // 拖 +50：首栏 250，把手跟着平移到 250
  send(@widget.PointerKind::Move, x0 + 54.0)
  assert_true((bar.rect.x - (x0 + 50.0)).abs() < 1.5)
  // 再拖 +10：把手已经在 250，若按把手局部坐标算增量，这一帧会把上一帧的
  // 50 扣回去（实测退回 210），正确口径是跟到 260
  send(@widget.PointerKind::Move, x0 + 64.0)
  assert_true((bar.rect.x - (x0 + 60.0)).abs() < 1.5)
  // 抬起后同一方向的移动不再改布局
  send(@widget.PointerKind::Up, x0 + 64.0)
  send(@widget.PointerKind::Move, x0 + 120.0)
  assert_true((bar.rect.x - (x0 + 60.0)).abs() < 1.5)
}

///|
test "分隔把手：两个最小宽度夹取仍然生效" {
  let (root, w) = split_mounted(
    split(
      view([], width=100.0, height=20.0),
      view([], width=100.0, height=20.0),
      ratio=0.5,
      min_first=120.0,
      min_second=80.0,
    ),
    400.0,
    200.0,
  )
  let bar = w.children()[1]
  let send = fn(kind : @widget.PointerKind, x : Double) -> Unit {
    let _ = root.dispatch_pointer_to(
      bar.id,
      { kind, x, y: 100.0, button: 1, mods: 0 },
    )
    let _ = root.relayout(400.0, 200.0)
  }
  send(@widget.PointerKind::Down, bar.rect.x + 4.0)
  send(@widget.PointerKind::Move, 0.0)
  assert_true(bar.rect.x >= 119.0)
  send(@widget.PointerKind::Move, 399.0)
  // 次栏最小 80：把手最远只能到 400-8-80 = 312
  assert_true((bar.rect.x - 312.0).abs() < 1.5)
}
