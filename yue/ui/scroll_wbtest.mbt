// 滚动容器回归：滚轮改偏移并夹取、内容随偏移整体上移、滚动条在内容之上、
// 拖动与点轨道改偏移、内容不足一屏时不滚也不画条。
// 几何（视口高/内容高）在第一帧绘制时抄进状态，所以用例都先 paint 一次。

///|
/// n 行、每行 h 高的内容节点。
fn scroll_rows(n : Int, h : Double, bg : String) -> Array[@core.Node] {
  let rows : Array[@core.Node] = []
  for i = 0; i < n; i = i + 1 {
    rows.push(container([label("行 " + i.to_string(), size=12.0)], height=h, bg=bg))
  }
  rows
}

///|
fn paint(root : @core.Widget, w : Int, h : Int) -> @render.Bitmap {
  let bm = @render.Bitmap::new(w, h)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  bm
}

///|
test "滚动容器：视口/内容几何来自布局，滚轮改偏移并两端夹取" {
  let st = ScrollState::new()
  let (root, vp) = mounted(
    scroll_v(scroll_rows(20, 20.0, @theme.theme_bg_panel()), st, width=200.0, height=100.0),
    240.0,
    140.0,
  )
  let _ = paint(root, 240, 140)
  assert_eq((vp.rect.w, vp.rect.h), (200.0, 100.0))
  assert_eq(st.content_h, 400.0)
  assert_eq(st.view_h, 100.0)
  assert_eq(st.max(), 300.0)
  // dy 正 = 上滚：到顶再滚不动
  let _ = root.dispatch_scroll({
    x: vp.rect.x + 40.0,
    y: vp.rect.y + 40.0,
    dx: 0.0,
    dy: 1.0,
    mods: 0,
  })
  assert_eq(st.offset_y(), 0.0)
  // 向下滚一格 = 30px
  let _ = root.dispatch_scroll({
    x: vp.rect.x + 40.0,
    y: vp.rect.y + 40.0,
    dx: 0.0,
    dy: -1.0,
    mods: 0,
  })
  assert_eq(st.offset_y(), 30.0)
  for _i = 0; _i < 20; _i = _i + 1 {
    let _ = root.dispatch_scroll({
      x: vp.rect.x + 40.0,
      y: vp.rect.y + 40.0,
      dx: 0.0,
      dy: -1.0,
      mods: 0,
    })
  }
  assert_eq(st.offset_y(), 300.0)
  assert_eq(st.at_bottom(), true)
}

///|
test "滚动容器：内容随偏移整体上移，滚动条在内容之上" {
  let st = ScrollState::new()
  let (root, vp) = mounted(
    scroll_v(scroll_rows(10, 20.0, @theme.theme_bg_panel()), st, width=200.0, height=100.0),
    240.0,
    140.0,
  )
  let content = vp.children()[0]
  let bar = vp.children()[1]
  let _ = paint(root, 240, 140)
  let y0 = content.rect.y
  assert_eq(y0, vp.rect.y)
  st.set_offset(70.0)
  root.relayout(240.0, 140.0)
  assert_eq(content.rect.y, y0 - 70.0)
  // 滚动条贴在视口右缘、与视口同高
  assert_eq((bar.rect.x + bar.rect.w, vp.rect.x + vp.rect.w), (200.0, 200.0))
  assert_eq(bar.rect.h, vp.rect.h)
  // 条在最上层：条覆盖处命中的是条而不是内容行
  let hit = root.hit_test(bar.rect.x + 4.0, bar.rect.y + 10.0)
  match hit {
    Some(w) => assert_eq(w.id, bar.id)
    None => assert_true(false)
  }
}

///|
test "滚动容器：点轨道跳转与拖动拇指（松手后移动不再跟手）" {
  let st = ScrollState::new()
  let (root, vp) = mounted(
    scroll_v(scroll_rows(20, 20.0, @theme.theme_bg_panel()), st, width=200.0, height=100.0),
    240.0,
    140.0,
  )
  let bar = vp.children()[1]
  let _ = paint(root, 240, 140)
  // 点轨道最下端：拇指中心对齐指针 → 偏移接近最大
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: bar.rect.x + 4.0,
    y: bar.rect.y + bar.rect.h - 1.0,
    button: 1,
    mods: 0,
  })
  assert_true(st.offset_y() > 250.0)
  let mid = st.offset_y()
  // 捕获期拖动（宿主按身份投递）继续改偏移
  let _ = root.dispatch_pointer_to(bar.id, {
    kind: @core.Move,
    x: bar.rect.x + 4.0,
    y: bar.rect.y + bar.rect.h / 2.0,
    button: 1,
    mods: 0,
  })
  assert_true(st.offset_y() < mid)
  let after_drag = st.offset_y()
  let _ = root.dispatch_pointer_to(bar.id, {
    kind: @core.Up,
    x: bar.rect.x + 4.0,
    y: bar.rect.y + bar.rect.h / 2.0,
    button: 1,
    mods: 0,
  })
  // 松手后再移动不再跟手
  let _ = root.dispatch_pointer_to(bar.id, {
    kind: @core.Move,
    x: bar.rect.x + 4.0,
    y: bar.rect.y + 4.0,
    button: 1,
    mods: 0,
  })
  assert_eq(st.offset_y(), after_drag)
}

///|
test "滚动容器：内容不足一屏不滚、也不画滚动条" {
  let st = ScrollState::new()
  let (root, vp) = mounted(
    scroll_v(scroll_rows(3, 20.0, "#334455"), st, width=200.0, height=100.0),
    240.0,
    140.0,
  )
  let bar = vp.children()[1]
  let bm = paint(root, 240, 140)
  assert_eq(st.max(), 0.0)
  let _ = root.dispatch_scroll({
    x: vp.rect.x + 40.0,
    y: vp.rect.y + 40.0,
    dx: 0.0,
    dy: -1.0,
    mods: 0,
  })
  assert_eq(st.offset_y(), 0.0)
  // 条的位置露出的是内容行底色（条没画轨道），不是条的取色
  let x = (bar.rect.x + 4.0).round().to_int()
  let y = (bar.rect.y + 10.0).round().to_int()
  let c = px(bm, x, y)
  assert_eq(c, (0x33, 0x44, 0x55, 0xFF))
}
