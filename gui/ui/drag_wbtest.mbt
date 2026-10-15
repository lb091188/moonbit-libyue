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
    view([src, tgt], row_gap=40.0, align_items=@yoga.AlignItems::FlexStart),
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
    view([src, tgt], row_gap=40.0, align_items=@yoga.AlignItems::FlexStart),
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
test "拖放：同一拖源连着拖两次都成立，载荷每次现取" {
  let hits : Ref[Int] = Ref(0)
  let last : Ref[String] = Ref("-")
  // 载荷由 `payload()` 每次开拖时现取——会话不缓存，第二次拖要拿到新值
  let seq : Ref[Int] = Ref(0)
  let src = drag_source(
    plain_box(80.0, 30.0),
    payload=fn() -> @core.DragData? {
      seq.val = seq.val + 1
      Some(@core.DragData::Text("第 \{seq.val} 次"))
    },
  )
  let tgt = drop_target(plain_box(80.0, 30.0), on_drop=fn(
    d : @core.DragData,
    _x : Double,
    _y : Double,
  ) -> Unit {
    hits.val = hits.val + 1
    last.val = match d {
      @core.DragData::Text(t) => t
      _ => "非文本"
    }
  })
  let (root, wrap) = mounted(
    view([src, tgt], row_gap=40.0, align_items=@yoga.AlignItems::FlexStart),
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
  // 一整趟拖放（按下 → 过阈值 → 移到目标 → 松手）跑两遍：第二遍的起点态
  // 就是第一遍的终点态，会话与按下捕获都必须已经清干净
  let mut hover = -1
  let mut cap = -1
  for i = 0; i < 2; i = i + 1 {
    let (h1, c1) = drag_step(root, @core.Down, sx, sy, hover, cap)
    let (h2, c2) = drag_step(root, @core.Move, sx + 10.0, sy, h1, c1)
    assert_true(@core.drag_active())
    let (h3, c3) = drag_step(root, @core.Move, tx, ty, h2, c2)
    assert_eq(@core.drag_hover(), tw.id)
    let (h4, c4) = drag_step(root, @core.Up, tx, ty, h3, c3)
    assert_false(@core.drag_active())
    // 松手必须把按下捕获放掉，否则下一次的 Down 会被上一个拖源的捕获牵着走
    assert_eq(c4, -1)
    assert_eq(hits.val, i + 1)
    hover = h4
    cap = c4
  }
  assert_eq(last.val, "第 2 次")
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
    view([src, tgt], row_gap=40.0, align_items=@yoga.AlignItems::FlexStart),
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

///|
/// `accept` 除了松手时判收不收，还要挂成悬停查询——系统级拖入的拖拽光标按它答
/// （`@core.drag_wants`），这里钉住接线。
test "拖放：drop_target 的 accept 同时是悬停查询" {
  let tgt = drop_target(
    plain_box(80.0, 30.0),
    accept=fn(d : @core.DragData) -> Bool { d.kind() == @core.FilePaths },
  )
  let (_root, w) = mounted(tgt, 200.0, 120.0)
  assert_true(w.drag_wants(@core.DragData::Paths(["/a"])))
  assert_false(w.drag_wants(@core.DragData::Text("t")))
  // 没装 accept 的投放目标按「收」处理
  let plain = drop_target(plain_box(60.0, 20.0))
  let (_r2, w2) = mounted(plain, 200.0, 120.0)
  assert_true(w2.drag_wants(@core.DragData::Text("t")))
}
