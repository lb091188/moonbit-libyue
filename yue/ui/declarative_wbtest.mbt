// 声明式层 L1 构造器回归：vbox/hbox 的方向与间距、bind_label 就地改文本、
// hover_group 的父链悬停与点击、旧名构造器（picker/scroll/tab）确实落到新组件上。

///|
test "vbox / hbox：方向与间距来自参数，交叉轴按 align_items" {
  let (root, col) = mounted(
    vbox([label("甲"), label("乙")], row_gap=10.0, padding=4.0),
    300.0,
    200.0,
  )
  assert_eq(col.children().length(), 2)
  let k0 = col.children()[0]
  let k1 = col.children()[1]
  assert_eq(k1.rect.y - (k0.rect.y + k0.rect.h), 10.0)
  assert_eq(k0.rect.x, 4.0)
  assert_true(k1.rect.y > k0.rect.y)
  let (_r2, row) = mounted(hbox([label("丙"), label("丁")], column_gap=12.0), 300.0, 120.0)
  let h0 = row.children()[0]
  let h1 = row.children()[1]
  assert_eq(h1.rect.x - (h0.rect.x + h0.rect.w), 12.0)
  assert_true(h1.rect.y >= h0.rect.y)
  // 两个方向的排布互不串味：列容器里纵向、行容器里横向
  assert_true(k1.rect.x == k0.rect.x)
  assert_true(h1.rect.x > h0.rect.x)
  ignore(root)
}

///|
test "bind_label：Store 一改就就地换文本并重测宽（不重建子树）" {
  let n = @core.Store::new(1)
  let (root, w) = mounted(
    bind_label(n, fn(v : Int) -> String { "计数 " + v.to_string() }),
    300.0,
    120.0,
  )
  let w0 = w.rect.w
  assert_true(w0 > 0.0)
  n.set(1234)
  let _ = root.relayout(300.0, 120.0)
  // 数字变多 → 宽度跟着变（旧链路「不补一次强制重排就停在挂载时宽度」的坑，
  // 在这里由 relabel 一并解决：改文本即重测）
  assert_true(w.rect.w > w0)
  let (bm, _, _) = shot(w)
  assert_true(color_of(bm, 2, 8) != (0, 0, 0, 0))
}

///|
test "bind：派生信号变化才换文本，订阅随回收袋退订" {
  let src = @core.Store::new(3)
  let doubled = src.map(fn(v : Int) -> Int { v * 2 })
  let holder = @core.Widget::new()
  @core.sub_bag_begin()
  let _w = (bind(doubled.signal(), fn(v : Int) -> String { v.to_string() })).mount_into(holder)
  let offs = @core.sub_bag_end()
  assert_eq(doubled.signal().sub_count(), 1)
  @core.sub_bag_discard(offs)
  assert_eq(doubled.signal().sub_count(), 0)
}

///|
test "hover_group：子控件悬停即整组换底色，松开在组内才算一次点击" {
  let mut hits = 0
  let (root, g) = mounted(
    hover_group(
      [label("卡片标题"), label("卡片正文")],
      on_click=fn() -> Unit { hits = hits + 1 },
      width=180.0,
      padding=8.0,
      row_gap=4.0,
    ),
    260.0,
    140.0,
  )
  let kid = g.children()[0]
  assert_eq(g.rect.w, 180.0)
  let (bm0, _, _) = shot(g)
  let base = color_of(bm0, 4, 4)
  // 悬停落在**子控件**上：宿主的父链语义让整组也算悬停（旧链路做不到，才要轮询）
  root.set_hover(kid.id)
  let (bm1, _, _) = shot(g)
  assert_true(color_of(bm1, 4, 4) != base)
  root.set_hover(0)
  let (bm2, _, _) = shot(g)
  assert_eq(color_of(bm2, 4, 4), base)
  click_at(root, g, 20.0, 10.0)
  assert_eq(hits, 1)
  // 按下在组内、抬起出组：不算一次点击
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: g.rect.x + 20.0,
    y: g.rect.y + 10.0,
    button: 1,
    mods: 0,
  })
  let _ = root.dispatch_pointer({
    kind: @core.Up,
    x: g.rect.x + 20.0,
    y: g.rect.y + g.rect.h + 40.0,
    button: 1,
    mods: 0,
  })
  assert_eq(hits, 1)
}

///|
test "旧名构造器落到新组件上：picker 点开浮层、scroll 出滚动条、tab 按 Store 切页" {
  let v = @core.Store::new("")
  let (root, field) = mounted_with_overlay(picker(["甲", "乙"], v, width=140.0), 400.0, 300.0)
  click_at(root, field, 30.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let rows = select_rows(1)
  assert_eq(rows.length(), 2)
  click_at(root, rows[0], 20.0, 14.0)
  assert_eq((v.get(), @core.overlay_count()), ("甲", 0))

  let st = ScrollState::new()
  let rows_in : Array[@core.Node] = []
  for i = 0; i < 20; i = i + 1 {
    rows_in.push(container([label("行 " + i.to_string())], height=22.0))
  }
  let (_r2, view) = mounted(scroll(rows_in, st, width=160.0, height=80.0), 220.0, 200.0)
  let (bm, _, _) = shot(view)
  // 内容超视口 → 右缘画得出滚动条（轨道色不是透明）
  let bx = view.rect.w.round().to_int() - 4
  assert_true(color_of(bm, bx, 4) != (0, 0, 0, 0))
  assert_true(st.max() > 0.0)

  let sel = @core.Store::new(0)
  let (_r3, tabs) = mounted(
    tab([("页一", label("第一页内容")), ("页二", label("第二页内容"))], selected=sel),
    300.0,
    160.0,
  )
  let head = tabs.children()[0]
  click_at(_r3, head.children()[1], 10.0, 10.0)
  assert_eq(sel.get(), 1)
}
