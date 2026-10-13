// 声明式层 L1 构造器回归：vbox/hbox 的方向与间距、bind_label 就地改文本、
// hover_group 的父链悬停与点击、旧名构造器（select/scroll/tab）确实落到新组件上。

///|
test "vbox / hbox：方向与间距来自参数，交叉轴按 align_items" {
  let (root, col) = mounted(
    col([text("甲"), text("乙")], row_gap=10.0, padding=4.0),
    300.0,
    200.0,
  )
  assert_eq(col.children().length(), 2)
  let k0 = col.children()[0]
  let k1 = col.children()[1]
  assert_eq(k1.rect.y - (k0.rect.y + k0.rect.h), 10.0)
  assert_eq(k0.rect.x, 4.0)
  assert_true(k1.rect.y > k0.rect.y)
  let (_r2, row) = mounted(row([text("丙"), text("丁")], column_gap=12.0), 300.0, 120.0)
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
  if !ui_text_guard() {
    return
  }
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
      [text("卡片标题"), text("卡片正文")],
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
test "旧名构造器落到新组件上：select 点开浮层、scroll 出滚动条、tab 按 Store 切页" {
  let v = @core.Store::new("")
  let (root, field) = mounted_with_overlay(select(["甲", "乙"], v, width=140.0), 400.0, 300.0)
  click_at(root, field, 30.0, 16.0)
  assert_eq(@core.overlay_count(), 1)
  root.relayout(400.0, 300.0)
  let rows = select_rows(@core.overlay_top_id())
  assert_eq(rows.length(), 2)
  click_at(root, rows[0], 20.0, 14.0)
  assert_eq((v.get(), @core.overlay_count()), ("甲", 0))

  let st = ScrollState::new()
  let rows_in : Array[@core.Node] = []
  for i = 0; i < 20; i = i + 1 {
    rows_in.push(view([text("行 " + i.to_string())], height=22.0))
  }
  let (_r2, view) = mounted(scroll_view(rows_in, st, width=160.0, height=80.0), 220.0, 200.0)
  let (bm, _, _) = shot(view)
  // 内容超视口 → 右缘画得出滚动条（轨道色不是透明）
  let bx = view.rect.w.round().to_int() - 4
  assert_true(color_of(bm, bx, 4) != (0, 0, 0, 0))
  assert_true(st.max() > 0.0)

  let sel = @core.Store::new(0)
  let (_r3, tabs) = mounted(
    tab([("页一", text("第一页内容")), ("页二", text("第二页内容"))], selected=sel),
    300.0,
    160.0,
  )
  let head = tabs.children()[0]
  click_at(_r3, head.children()[1], 10.0, 10.0)
  assert_eq(sel.get(), 1)
}

///|
test "光标形状请求：按钮手型、输入框文本形、分隔把手横向/纵向、cursor_group 可覆盖" {
  let (root, card) = mounted(
    hover_group([text("卡片"), button("按", on_click=fn() -> Unit { () })]),
    300.0,
    160.0,
  )
  assert_eq(card.cursor, @core.CURSOR_HAND)
  // 按钮的请求是**动态**的（`cursor_fn`，按命中查询现算），所以查它自己的请求函数
  assert_eq(card.children()[1].cursor_request(), @core.CURSOR_HAND)
  // 悬停在卡片空白处也是手型（组的请求回退生效）
  assert_eq(root.cursor_at(card.rect.x + 4.0, card.rect.y + 4.0), @core.CURSOR_HAND)
  let (_r2, box1) = mounted(input(@core.Store::new("x"), focus_id=1), 200.0, 60.0)
  assert_eq(box1.cursor, @core.CURSOR_TEXT)
  let (_r3, area) = mounted(textarea(@core.Store::new("y")), 260.0, 90.0)
  assert_eq(area.cursor, @core.CURSOR_TEXT)
  let (_r4, hs) = mounted(split(text("甲"), text("乙")), 220.0, 80.0)
  assert_eq(hs.children()[1].cursor, @core.CURSOR_RESIZE_H)
  let (_r5, vs) = mounted(split(text("甲"), text("乙"), direction=Vertical), 220.0, 120.0)
  assert_eq(vs.children()[1].cursor, @core.CURSOR_RESIZE_V)
  let (_r6, cg) = mounted(
    cursor_group([text("缩放热区")], cursor=@core.CURSOR_RESIZE_V, width=120.0),
    200.0,
    60.0,
  )
  assert_eq(cg.cursor, @core.CURSOR_RESIZE_V)
  assert_eq(cg.children()[0].cursor, @core.CURSOR_DEFAULT)
}
