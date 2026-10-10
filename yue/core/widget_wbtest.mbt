// 控件宿主回归：绝对矩形折算、命中优先级与显隐、事件本地化与冒泡、
// 按键按焦点 id 定位、绘制遍历的平移与裁剪。全程无头（位图在内存里）。

///|
fn sized(w : Widget, width : Double, height : Double) -> Widget {
  w.node.set_width(@yoga.fixed(width))
  w.node.set_height(@yoga.fixed(height))
  w
}

///|
fn column(w : Widget) -> Widget {
  w.node.set_flex_direction(@yoga.Column)
  w
}

///|
/// Option[Widget] 比不了 `==`（Widget 带闭包字段、Eq 派生不出来），
/// 一律换成取 id：命中不到给 -1。
fn hit_id(w : Widget, x : Double, y : Double) -> Int {
  match w.hit_test(x, y) {
    Some(k) => k.id
    None => -1
  }
}

///|
fn find_id(w : Widget, id : Int) -> Int {
  match w.find_by_focus_id(id) {
    Some(k) => k.id
    None => -1
  }
}

///|
test "relayout 把父子相对偏移折算成窗口绝对矩形" {
  let root = column(Widget::new())
  let _ = sized(root, 200.0, 100.0)
  let a = sized(Widget::new(), 100.0, 40.0)
  let b = sized(Widget::new(), 100.0, 60.0)
  root.append_child(a)
  root.append_child(b)
  a.node.set_padding_left(@yoga.fixed(10.0))
  let inner = sized(Widget::new(), 20.0, 20.0)
  a.append_child(inner)

  root.relayout(200.0, 100.0)
  assert_eq((root.rect.x, root.rect.y, root.rect.w, root.rect.h), (0.0, 0.0, 200.0, 100.0))
  assert_eq((a.rect.x, a.rect.y, a.rect.w, a.rect.h), (0.0, 0.0, 100.0, 40.0))
  assert_eq((b.rect.x, b.rect.y, b.rect.w, b.rect.h), (0.0, 40.0, 100.0, 60.0))
  // 父控件的 padding 要进到子控件的绝对坐标里（只在这一处折算）
  assert_eq((inner.rect.x, inner.rect.y, inner.rect.w, inner.rect.h), (10.0, 0.0, 20.0, 20.0))
}

///|
test "命中取最深、同层后画者优先、出界与隐藏都不命中" {
  let root = sized(Widget::new(), 200.0, 200.0)
  let first = sized(Widget::new(), 100.0, 100.0)
  root.append_child(first)
  // 后追加 + 绝对定位覆盖在同一片区域：命中要取到它（后画在上）
  let last = sized(Widget::new(), 100.0, 100.0)
  last.node.set_position(@yoga.Absolute)
  last.node.set_top(@yoga.fixed(0.0))
  last.node.set_left(@yoga.fixed(0.0))
  last.node.set_padding_left(@yoga.fixed(20.0))
  last.node.set_padding_top(@yoga.fixed(20.0))
  root.append_child(last)
  let leaf = sized(Widget::new(), 20.0, 20.0)
  last.append_child(leaf)
  root.relayout(200.0, 200.0)
  assert_eq((leaf.rect.x, leaf.rect.y), (20.0, 20.0))

  assert_eq(hit_id(root, 25.0, 25.0), leaf.id)
  assert_eq(hit_id(root, 60.0, 60.0), last.id)
  assert_eq(hit_id(root, 150.0, 150.0), root.id)
  assert_eq(hit_id(root, 200.0, 50.0), -1)
  assert_eq(hit_id(root, -1.0, 50.0), -1)

  // 零尺寸控件不命中（半开区间，w/h 为 0 直接否）
  let zero = sized(Widget::new(), 0.0, 0.0)
  zero.node.set_position(@yoga.Absolute)
  root.append_child(zero)
  root.relayout(200.0, 200.0)
  assert_eq(zero.rect.w, 0.0)
  assert_eq(hit_id(zero, 0.0, 0.0), -1)

  // 隐藏：自身与后代都不命中、也不占位
  last.set_visible(false)
  root.relayout(200.0, 200.0)
  assert_eq(leaf.rect.w, 0.0)
  assert_eq(hit_id(last, 60.0, 60.0), -1)
  last.set_visible(true)
}

///|
test "指针事件：本地坐标换算 + 沿祖先链冒泡 + 消费即停" {
  let root = column(Widget::new())
  let _ = sized(root, 100.0, 100.0)
  let mid = sized(Widget::new(), 80.0, 40.0)
  let leaf = sized(Widget::new(), 20.0, 20.0)
  root.append_child(mid)
  mid.append_child(leaf)
  root.relayout(100.0, 100.0)

  let order : Array[String] = []
  leaf.on_pointer = Some(fn(ev : PointerEvent) -> Bool {
    // 三棵树原点都在 (0,0)：本地坐标应与窗口坐标相同（有偏移的树见下一条用例）
    order.push("leaf@\{ev.x.to_string()},\{ev.y.to_string()}")
    false
  })
  mid.on_pointer = Some(fn(ev : PointerEvent) -> Bool {
    order.push("mid@\{ev.x.to_string()},\{ev.y.to_string()}")
    false
  })
  root.on_pointer = Some(fn(ev : PointerEvent) -> Bool {
    order.push("root@\{ev.x.to_string()},\{ev.y.to_string()}")
    true
  })
  let handled = root.dispatch_pointer({
    kind: Down,
    x: 15.0,
    y: 15.0,
    button: 1,
    mods: 0,
  })
  assert_eq(handled, true)
  assert_eq(order.length(), 3)
  assert_eq(order[0], "leaf@15,15")
  assert_eq(order[1], "mid@15,15")
  // 命中点 (15,15)：leaf 原点 (0,0)? —— leaf 在 mid 内、mid 在 root 内均为 (0,0) 起，
  // 故三者本地坐标相同；下面用带偏移的一棵树的断言区分平移是否生效

  // 消费即停：leaf 返回 true 时父层不见事件
  let order2 : Array[String] = []
  leaf.on_pointer = Some(fn(_ev : PointerEvent) -> Bool {
    order2.push("leaf")
    true
  })
  mid.on_pointer = Some(fn(_ev : PointerEvent) -> Bool {
    order2.push("mid")
    true
  })
  assert_eq(root.dispatch_pointer({ kind: Up, x: 15.0, y: 15.0, button: 1, mods: 0 }), true)
  assert_eq(order2.length(), 1)
  assert_eq(order2[0], "leaf")
}

///|
test "指针本地坐标随控件原点平移（有偏移的一棵树）" {
  let root = column(Widget::new())
  let _ = sized(root, 100.0, 100.0)
  let spacer = sized(Widget::new(), 100.0, 30.0)
  let box_ = sized(Widget::new(), 40.0, 40.0)
  root.append_child(spacer)
  root.append_child(box_)
  root.relayout(100.0, 100.0)
  assert_eq((box_.rect.x, box_.rect.y), (0.0, 30.0))

  let seen : Array[(Double, Double)] = []
  box_.on_pointer = Some(fn(ev : PointerEvent) -> Bool {
    seen.push((ev.x, ev.y))
    true
  })
  let _ = root.dispatch_pointer({
    kind: Down,
    x: 12.0,
    y: 45.0,
    button: 1,
    mods: 0,
  })
  assert_eq(seen.length(), 1)
  assert_eq(seen[0], (12.0, 15.0))
}

///|
test "滚轮冒泡到滚动容器" {
  let scroller = column(Widget::new())
  let _ = sized(scroller, 100.0, 100.0)
  let row = sized(Widget::new(), 100.0, 20.0)
  scroller.append_child(row)
  scroller.relayout(100.0, 100.0)

  let got : Array[String] = []
  scroller.on_scroll = Some(fn(_ev : ScrollEvent) -> Bool {
    got.push("scroller")
    true
  })
  assert_eq(
    scroller.dispatch_scroll({ x: 50.0, y: 10.0, dx: 0.0, dy: -1.0, mods: 0, }),
    true,
  )
  assert_eq(got.length(), 1)
  // 命中点在容器外不路由
  assert_eq(
    scroller.dispatch_scroll({ x: 500.0, y: 10.0, dx: 0.0, dy: -1.0, mods: 0, }),
    false,
  )
}

///|
test "按键按焦点 id 定位并冒泡；未知 id 不做任何事" {
  let root = column(Widget::new())
  let _ = sized(root, 100.0, 100.0)
  let wrapper = sized(Widget::new(), 60.0, 20.0)
  let field = sized(Widget::new(), 60.0, 20.0)
  root.append_child(wrapper)
  wrapper.append_child(field)
  field.focus_id = 7
  root.relayout(100.0, 100.0)

  let log : Array[String] = []
  field.on_key = Some(fn(ev : KeyEvent) -> Bool {
    log.push("field:\{ev.keysym}")
    false
  })
  wrapper.on_key = Some(fn(_ev : KeyEvent) -> Bool {
    log.push("wrapper")
    true
  })
  let ev = { press: true, keysym: 97, mods: 0 }
  assert_eq(root.dispatch_key(7, ev), true)
  assert_eq(log.length(), 2)
  assert_eq(log[0], "field:97")
  assert_eq(log[1], "wrapper")

  // 焦点 id 查得到控件本体（供高亮等判断）
  assert_eq(find_id(root, 7), field.id)
  assert_eq(find_id(root, 99), -1)
  assert_eq(root.dispatch_key(99, ev), false)

  // 隐藏的控件不可达
  wrapper.set_visible(false)
  root.relayout(100.0, 100.0)
  assert_eq(find_id(root, 7), -1)
}

///|
fn color_of(bm : @render.Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = bm.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

///|
test "绘制遍历：逐层平移到控件原点，并裁剪到控件矩形" {
  let root = column(Widget::new())
  let _ = sized(root, 40.0, 40.0)
  let child = sized(Widget::new(), 20.0, 20.0)
  // holder 从根起，靠自身 padding 推出子控件原点 → child 落在 (10,10)
  let holder = sized(Widget::new(), 30.0, 30.0)
  holder.node.set_padding_left(@yoga.fixed(10.0))
  holder.node.set_padding_top(@yoga.fixed(10.0))
  holder.append_child(child)
  root.append_child(holder)
  root.relayout(40.0, 40.0)
  assert_eq((child.rect.x, child.rect.y), (10.0, 10.0))

  root.on_draw = Some(fn(p : @render.Painter, r : Rect) -> Unit {
    p.set_fill_color("#ff0000")
    p.fill_rect(0.0, 0.0, r.w, r.h)
  })
  child.on_draw = Some(fn(p : @render.Painter, _r : Rect) -> Unit {
    p.set_fill_color("#0000ff")
    // 故意画出自己的盒子：局部 (-5,-5) 起、30×30 → 设备 (5,5)-(35,35)
    // 被宿主的 clip_rect(0,0,20,20) 裁回 (10,10)-(30,30)
    p.fill_rect(-5.0, -5.0, 30.0, 30.0)
  })

  let bm = @render.Bitmap::new(40, 40)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()

  assert_eq(color_of(bm, 2, 2), (255, 0, 0, 255))
  // 越界部分被裁掉：设备 (6,6) 仍在 child 的绘制范围内，但不该出现蓝色
  assert_eq(color_of(bm, 6, 6), (255, 0, 0, 255))
  assert_eq(color_of(bm, 12, 12), (0, 0, 255, 255))
  assert_eq(color_of(bm, 29, 29), (0, 0, 255, 255))
  assert_eq(color_of(bm, 31, 31), (255, 0, 0, 255))

  // 隐藏控件及其后代不绘制
  child.set_visible(false)
  let bm2 = @render.Bitmap::new(40, 40)
  let p2 = @render.Painter::new(bm2)
  root.paint(p2)
  p2.end()
  assert_eq(color_of(bm2, 12, 12), (255, 0, 0, 255))
  child.set_visible(true)
}
