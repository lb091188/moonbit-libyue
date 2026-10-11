// 指针分发决策（悬停归属 / 按下捕获 / Leave 补发）的回归。全程无头：
// route_pointer 是纯函数，App 只保存它返回的两个状态。

///|
fn pe(kind : PointerKind, x : Double, y : Double) -> PointerEvent {
  { kind, x, y, button: 1, mods: 0, }
}

///|
/// 一棵三层树：root 里纵向排 A/B/C 各 100×20；B 记「事件名 + 本地坐标」，
/// 只消费按下；C 只记事件名，一律不消费。
fn hover_tree(log : Array[String], tag : String) -> (Widget, Widget, Widget, Widget) {
  let root = Widget::new()
  root.set_column()
  let a = sized(Widget::new(), 100.0, 20.0)
  let b = sized(Widget::new(), 100.0, 20.0)
  let c = sized(Widget::new(), 100.0, 20.0)
  b.on_pointer = Some(fn(_widget : Widget, ev : PointerEvent) -> Bool {
    let kind_str = match ev.kind {
      Down => "down"
      Up => "up"
      Move => "move"
      Leave => "leave"
    }
    let mark =
      ev.x.round().to_int().to_string() + "/" + ev.y.round().to_int().to_string()
    log.push(tag + ":b:" + kind_str + ":" + mark)
    match ev.kind {
      Down => true
      _ => false
    }
  })
  c.on_pointer = Some(fn(_widget : Widget, ev : PointerEvent) -> Bool {
    let kind_str = match ev.kind {
      Down => "down"
      Up => "up"
      Move => "move"
      Leave => "leave"
    }
    log.push(tag + ":c:" + kind_str)
    false
  })
  root.append_child(a)
  root.append_child(b)
  root.append_child(c)
  root.relayout(100.0, 60.0)
  (root, a, b, c)
}

///|
test "悬停跟随指针，换了就补发 Leave" {
  let log : Array[String] = []
  let (root, a, b, c) = hover_tree(log, "h")
  let mut hover = -1
  let mut cap = -1

  let r1 = route_pointer(root, pe(Move, 10.0, 50.0), hover, cap)
  hover = r1.0
  cap = r1.1
  assert_eq((hover, c.hovered, b.hovered, a.hovered), (c.id, true, false, false))

  // 同一控件内再动：状态不变、不重复补发
  let leaves = fn() -> Int {
    let mut n = 0
    for e in log {
      if e.contains("leave") { n = n + 1 }
    }
    n
  }
  let r2 = route_pointer(root, pe(Move, 30.0, 52.0), hover, cap)
  // 事件照常投递（命中者仍是 c），但状态没变、也不补发 Leave
  assert_eq((r2.2, r2.3), (false, false))
  assert_eq(leaves(), 0)

  // 换到 b：c 收到一次 Leave
  let r3 = route_pointer(root, pe(Move, 10.0, 25.0), hover, cap)
  assert_eq(r3.0, b.id)
  assert_eq((b.hovered, c.hovered), (true, false))
  assert_eq(leaves(), 1)
  assert_true(r3.3)
}

///|
test "按下进入捕获：移动与抬起都投给被按下的控件，指针离开也不丢抬起" {
  let log : Array[String] = []
  let (root, a, b, _c) = hover_tree(log, "p")
  let mut hover = -1
  let mut cap = -1

  let r1 = route_pointer(root, pe(Down, 10.0, 25.0), hover, cap)
  hover = r1.0
  cap = r1.1
  // b 消费了按下，并成为捕获者
  assert_eq((r1.2, cap, b.pressed), (true, b.id, true))
  let base = log.length()

  // 拖到 a 的区域：a 拿不到事件（捕获期归 b），b 收到本地化后的移动（y 为负）
  let r2 = route_pointer(root, pe(Move, 10.0, 5.0), hover, cap)
  assert_eq(log[base], "p:b:move:10/-15")
  // 捕获期悬停不动，控件自己也没消费这次移动
  assert_eq((r2.0, r2.2, r2.3), (-1, false, false))

  // 在 a 的区域松手：b 仍收到抬起，按下态清掉、捕获解除（抬起不消费）
  let r3 = route_pointer(root, pe(Up, 10.0, 5.0), r2.0, r2.1)
  assert_eq((r3.1, b.pressed, r3.2), (-1, false, false))
  assert_eq(log[base + 1], "p:b:up:10/-15")
  // 抬起后按位置重新判定悬停者 = a
  assert_eq(r3.0, a.id)
  assert_eq((a.hovered, b.hovered), (true, false))
}

///|
test "点在空白处：命中根控件、没有处理器也不炸，且不进捕获" {
  let log : Array[String] = []
  let root = Widget::new()
  let child = sized(Widget::new(), 40.0, 20.0)
  child.on_pointer = Some(fn(_widget : Widget, _ev : PointerEvent) -> Bool {
    log.push("child")
    true
  })
  root.append_child(child)
  root.relayout(100.0, 100.0)
  let r = route_pointer(root, pe(Down, 80.0, 80.0), -1, -1)
  assert_eq((r.1 >= 0, r.2, r.3), (false, false, true))
  assert_eq(log.length(), 0)
}

///|
test "隐藏的控件不参与悬停：同一片区域命中可见的父" {
  let log : Array[String] = []
  let (root, _a, b, c) = hover_tree(log, "v")
  b.set_visible(false)
  root.relayout(100.0, 60.0)
  let r = route_pointer(root, pe(Move, 10.0, 25.0), -1, -1)
  // b 隐藏即不占位（引擎按 display:none 不再给它矩形），c 顶上来占 20..40，
  // 所以这个位置命中的是 c；悬停态绝不会留在隐藏的控件上
  assert_eq(r.0, c.id)
  assert_eq((b.hovered, c.hovered), (false, true))
  // 隐藏项也不撑高父（列容器 auto 高 = 内容），55 已在根控件之外 → 无命中
  let r2 = route_pointer(root, pe(Move, 10.0, 55.0), c.id, -1)
  assert_eq((r2.0, b.hovered, c.hovered), (-1, false, false))
}

///|
test "by_id 与 dispatch_pointer_to：按身份投递，坐标不再决定归属" {
  let log : Array[String] = []
  let (root, a, b, _c) = hover_tree(log, "d")
  // 自己也能按 id 找到（根控件视角）
  assert_true(root.by_id(a.id) is Some(_))
  let found = root.by_id(b.id)
  assert_true(found is Some(_))
  // 把事件投给 b：坐标写在哪都无所谓，本地坐标按 b 的原点折算
  let consumed = root.dispatch_pointer_to(b.id, pe(Down, 500.0, 500.0))
  assert_true(consumed)
  assert_eq(log, ["d:b:down:500/480"])
}

///|
test "滚轮沿用同一传播规则（命中控件起向上冒泡到容器）" {
  let log : Array[String] = []
  let root = Widget::new()
  root.set_column()
  let child = sized(Widget::new(), 100.0, 20.0)
  child.on_scroll = Some(fn(_ev : ScrollEvent) -> Bool {
    log.push("child")
    false
  })
  root.on_scroll = Some(fn(_ev : ScrollEvent) -> Bool {
    log.push("root")
    true
  })
  root.append_child(child)
  root.relayout(100.0, 20.0)
  let handled = root.dispatch_scroll({
    x: 10.0,
    y: 10.0,
    dx: 0.0,
    dy: 1.0,
    mods: 0,
  })
  assert_true(handled)
  assert_eq(log, ["child", "root"])
}

///|
test "悬停带父链语义（CSS :hover 同义），翻转时触发 on_hover_change" {
  let root = Widget::new()
  root.set_size(200.0, 100.0)
  root.set_column()
  let outer = Widget::new()
  outer.set_size(120.0, 60.0)
  let leaf = Widget::new()
  leaf.set_size(40.0, 20.0)
  let sib = Widget::new()
  sib.set_size(40.0, 20.0)
  outer.append_child(leaf)
  root.append_child(outer)
  root.append_child(sib)
  root.relayout(200.0, 100.0)
  let fired : Array[(Int, Bool)] = []
  outer.on_hover_change = Some(fn(w : Widget, on : Bool) -> Unit {
    fired.push((w.id, on))
  })

  root.set_hover(leaf.id)
  // 命中链上的三层都算悬停，兄弟不算
  assert_eq((root.hovered, outer.hovered, leaf.hovered, sib.hovered), (true, true, true, false))
  assert_eq(fired.length(), 1)
  assert_eq(fired[0], (outer.id, true))
  // 同一状态重复设置不重复回调
  root.set_hover(leaf.id)
  assert_eq(fired.length(), 1)
  // 换到兄弟：父链整体翻掉
  root.set_hover(sib.id)
  assert_eq((outer.hovered, leaf.hovered, sib.hovered), (false, false, true))
  assert_eq(fired.length(), 2)
  assert_eq(fired[1], (outer.id, false))
  // 清空
  root.set_hover(0)
  assert_eq((root.hovered, sib.hovered), (false, false))
}
