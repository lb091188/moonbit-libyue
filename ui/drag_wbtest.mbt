// W21c 拖放回归（ui 侧）：把 `drag_source` / `drop_target` 放真控件树里，用宿主的
// 指针路由（`@core.route_pointer`，含按下捕获）走完整条链路——按下 → 过阈值开拖 →
// 移动换落点 → 松手投递。无头运行，不需要真窗口。

///|
/// 定尺寸的空盒子：拖源/投放目标的内容用（不依赖文本测量，也就不必挂 guard）。
fn plain_box(w : Double, h : Double) -> @core.Node {
  @core.node_of_new(fn(b : @core.Widget) -> @core.Widget {
    b.node.set_width(@yoga.fixed(w))
    b.node.set_height(@yoga.fixed(h))
    b
  })
}

///|
/// 命中链上有没有这个 id。
fn path_has(path : Array[@core.Widget], id : Int) -> Bool {
  let mut i = 0
  let mut found = false
  while i < path.length() && !found {
    if path[i].id == id {
      found = true
    }
    i = i + 1
  }
  found
}

///|
/// 把一次指针事件喂给宿主并带回新的 (hover, capture)。
fn drag_step(
  root : @core.Widget,
  kind : @core.PointerKind,
  x : Double,
  y : Double,
  hover : Int,
  cap : Int,
) -> (Int, Int) {
  let (h, c, _consumed, _changed) = @core.route_pointer(root, {
    kind,
    x,
    y,
    button: 1,
    mods: 0,
  }, hover, cap)
  (h, c)
}

///|
test "应用内拖放：按下 → 过阈值开拖 → 移到目标 → 松手投递" {
  let got : Ref[String] = Ref("-")
  let src = drag_source(
    plain_box(80.0, 30.0),
    payload=fn() -> @core.DragData? { Some(@core.DragData::Text("载荷")) },
  )
  let tgt = drop_target(plain_box(80.0, 30.0), on_drop=fn(
    d : @core.DragData,
    _x : Double,
    _y : Double,
  ) -> Unit {
    got.val = match d {
      @core.DragData::Text(t) => t
      _ => "非文本"
    }
  })
  let (root, wrap) = mounted(
    container([src, tgt], row_gap=40.0, align_items=@yoga.AlignItems::FlexStart),
    320.0,
    200.0,
  )
  @core.set_drag_root(root)
  let sw = wrap.children()[0]
  let tw = wrap.children()[1]
  let sx = sw.rect.x + 8.0
  let sy = sw.rect.y + 8.0
  let tx = tw.rect.x + 8.0
  let ty = tw.rect.y + 8.0
  assert_true(sy != ty)
  // 按下：捕获落在**命中链上最深**的控件（拖源包着的内容盒），拖源包装层在这条
  // 链上——事件从最深往上冒泡，最终由包装层的 on_pointer 处理，但 `route_pointer`
  // 记下的捕获 id 是最深那一个（与 Web 的 pointerdown target 同义）。
  let deepest = match root.hit_test(sx, sy) {
    Some(w) => w.id
    None => -1
  }
  assert_true(path_has(root.hit_path(sx, sy), sw.id))
  let (h1, cap) = drag_step(root, @core.Down, sx, sy, -1, -1)
  assert_eq(cap, deepest)
  assert_true(cap != -1)
  assert_false(@core.drag_active())
  // 移动 2px（没过 4px 阈值）：不开拖
  let (h2, cap2) = drag_step(root, @core.Move, sx + 2.0, sy, h1, cap)
  assert_false(@core.drag_active())
  assert_eq(cap2, deepest)
  // 移动 12px（过阈值）：开拖，源 id 记进会话
  let (h3, cap3) = drag_step(root, @core.Move, sx + 12.0, sy, h2, cap2)
  assert_true(@core.drag_active())
  assert_eq(@core.drag_source(), sw.id)
  assert_eq(@core.drag_hover(), 0)
  // 移到投放目标上：落点命中它
  let (h4, cap4) = drag_step(root, @core.Move, tx, ty, h3, cap3)
  assert_eq(@core.drag_hover(), tw.id)
  // 松手：投给目标、拿到数据、会话结束
  let (_h5, _cap5) = drag_step(root, @core.Up, tx, ty, h4, cap4)
  assert_eq(got.val, "载荷")
  assert_false(@core.drag_active())
  @core.clear_drag_root()
}

///|
test "拖放：没过阈值当普通点击（不开会话）、投到空白处不投递" {
  let got : Ref[String] = Ref("-")
  let src = drag_source(
    plain_box(80.0, 30.0),
    payload=fn() -> @core.DragData? { Some(@core.DragData::Text("x")) },
  )
  let tgt = drop_target(plain_box(80.0, 30.0), on_drop=fn(
    _d : @core.DragData,
    _x : Double,
    _y : Double,
  ) -> Unit {
    got.val = "投中了"
  })
  let (root, wrap) = mounted(
    container([src, tgt], row_gap=40.0, align_items=@yoga.AlignItems::FlexStart),
    320.0,
    200.0,
  )
  @core.set_drag_root(root)
  let sw = wrap.children()[0]
  let sx = sw.rect.x + 8.0
  let sy = sw.rect.y + 8.0
  // 按-抬（原地，不过阈值）：不产生拖拽
  let (h1, cap) = drag_step(root, @core.Down, sx, sy, -1, -1)
  let (h2, cap2) = drag_step(root, @core.Up, sx, sy, h1, cap)
  assert_false(@core.drag_active())
  assert_eq(got.val, "-")
  // 开了拖但松手在空白处（没有落点）：不投递，会话照样结束
  let (h3, cap3) = drag_step(root, @core.Down, sx, sy, h2, cap2)
  let (h4, cap4) = drag_step(root, @core.Move, sx + 10.0, sy, h3, cap3)
  assert_true(@core.drag_active())
  let (_h5, _c5) = drag_step(root, @core.Up, 310.0, 190.0, h4, cap4)
  assert_eq(got.val, "-")
  assert_false(@core.drag_active())
  @core.clear_drag_root()
}

///|
test "拖放：accept 判收不收——拒绝时回调不跑、返回不被接受" {
  let dropped : Ref[String] = Ref("-")
  let src = drag_source(
    plain_box(80.0, 30.0),
    payload=fn() -> @core.DragData? { Some(@core.DragData::Text("只收路径")) },
  )
  let tgt = drop_target(
    plain_box(80.0, 30.0),
    // 只收文件路径，文本一律拒
    accept=fn(d : @core.DragData) -> Bool { d.kind() == @core.FilePaths },
    on_drop=fn(_d : @core.DragData, _x : Double, _y : Double) -> Unit {
      dropped.val = "投中了"
    },
  )
  let (root, wrap) = mounted(
    container([src, tgt], row_gap=40.0, align_items=@yoga.AlignItems::FlexStart),
    320.0,
    200.0,
  )
  @core.set_drag_root(root)
  let sw = wrap.children()[0]
  let tw = wrap.children()[1]
  let sx = sw.rect.x + 8.0
  let sy = sw.rect.y + 8.0
  let tx = tw.rect.x + 8.0
  let ty = tw.rect.y + 8.0
  let (h1, cap) = drag_step(root, @core.Down, sx, sy, -1, -1)
  let (h2, cap2) = drag_step(root, @core.Move, sx + 10.0, sy, h1, cap)
  let (h3, cap3) = drag_step(root, @core.Move, tx, ty, h2, cap2)
  // 悬停照样命中（accept 是松手时才问的，悬停高亮不受它影响）
  assert_eq(@core.drag_hover(), tw.id)
  let (_h4, _c4) = drag_step(root, @core.Up, tx, ty, h3, cap3)
  assert_eq(dropped.val, "-")
  assert_false(@core.drag_active())
  @core.clear_drag_root()
}

///|
test "拖放：payload 给 None 时按普通按下处理，不产生会话" {
  let src = drag_source(plain_box(80.0, 30.0))
  let (root, wrap) = mounted(src, 200.0, 120.0)
  @core.set_drag_root(root)
  let sw = wrap.children()[0]
  let sx = sw.rect.x + 8.0
  let sy = sw.rect.y + 8.0
  let (h1, cap) = drag_step(root, @core.Down, sx, sy, -1, -1)
  let (h2, cap2) = drag_step(root, @core.Move, sx + 20.0, sy, h1, cap)
  assert_false(@core.drag_active())
  assert_eq(h2, h1)
  assert_eq(cap2, cap)
  @core.clear_drag_root()
}
