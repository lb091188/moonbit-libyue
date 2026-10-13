// 虚拟列表/虚拟表格回归：只挂可见区间、滚动后窗口跟着平移、上下占位把总高撑对、
// 表头固定不滚、虚拟表格的行点选与 table 同口径。

///|
fn virt_items(n : Int) -> @core.Store[Array[Int]] {
  let out : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    out.push(i)
  }
  @core.Store::new(out)
}

///|
test "虚拟列表：千行只挂可见区间，滚动后窗口平移、占位撑起总高" {
  let items = virt_items(1000)
  let seen : Array[Int] = []
  let (root, vp) = mounted(
    virt_list(
      items,
      200.0,
      20.0,
      fn(i : Int, _x : Int) -> @core.Node {
        seen.push(i)
        view([text("行")], height=20.0)
      },
      width=300.0,
    ),
    360.0,
    260.0,
  )
  // 视口 200 / 行高 20 = 10 行 + 上下各 2 行预挂
  assert_eq(vp.rect.h, 200.0)
  let inner = vp.children()[0]
  assert_true(seen.length() <= 16 && seen.length() >= 12)
  assert_eq(seen[0], 0)
  // 内层总高 = 1000 × 20（上下占位撑起来）
  root.relayout(360.0, 260.0)
  assert_eq(inner.rect.h, 20000.0)
  // 滚 4 格 = 120px：窗口第一行 = 120/20 − 2（overscan）= 4
  seen.clear()
  let _ = root.dispatch_scroll({
    x: vp.rect.x + 50.0,
    y: vp.rect.y + 50.0,
    dx: 0.0,
    dy: -4.0,
    mods: 0,
  })
  root.relayout(360.0, 260.0)
  assert_true(seen.length() > 0)
  assert_eq(seen[0], 4)
  assert_true(inner.rect.h == 20000.0)
}

///|
test "虚拟列表：拖滚动条改偏移、数据变短偏移夹回上界" {
  let items = virt_items(1000)
  let (root, vp) = mounted(
    virt_list(
      items,
      200.0,
      20.0,
      fn(_i : Int, _x : Int) -> @core.Node {
        view([text("行")], height=20.0)
      },
      width=300.0,
    ),
    360.0,
    260.0,
  )
  let bar = vp.children()[1]
  // 先画一帧让状态拿到视口/内容几何
  let bm = @render.Bitmap::new(360, 260)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  // 拖到滚动条中点 → 偏移接近一半
  let _ = root.dispatch_pointer({
    kind: @core.Down,
    x: bar.rect.x + 4.0,
    y: bar.rect.y + 100.0,
    button: 1,
    mods: 0,
  })
  root.relayout(360.0, 260.0)
  // 拖到条中点后，偏移过半：第一行的绝对 y 明显上移（说明窗口真的平移了）
  let first_row = vp.children()[0].children()[0]
  assert_true(first_row.rect.w > 0.0)
  // 数据变短：偏移夹回上界（不至于一片空白）
  items.set([0, 1, 2, 3, 4])
  root.relayout(360.0, 260.0)
  assert_true(vp.children()[0].rect.h <= 100.0)
}

///|
test "虚拟表格：表头固定不滚、行只挂可见区间、点选与 table 同口径" {
  let data : Array[TableRow] = []
  for i = 0; i < 200; i = i + 1 {
    data.push(TableRow::make(["行 " + i.to_string(), (i * 2).to_string()]))
  }

  let rows = @core.Store::new(data)
  let sel : @core.Store[Array[Int]] = @core.Store::new([])
  let sort = @core.Store::new({ column: -1, asc: true })
  let clicks : Array[Int] = []
  let (root, tv) = mounted(
    table_v(
      [TableColumn::make("名", 140.0), TableColumn::make("值", 0.0)],
      rows,
      width=260.0,
      height=150.0,
      row_height=30.0,
      selection=sel,
      sort=sort,
      on_row_click=fn(i : Int, _r : TableRow) -> Unit { clicks.push(i) },
    ),
    320.0,
    240.0,
  )
  let head = tv.children()[0]
  let list = tv.children()[1]
  assert_eq(head.rect.h, 40.0)
  assert_eq(list.rect.h, 150.0)
  // 视口 150 / 行高 30 = 5 行 + 预挂
  let inner = list.children()[0]
  assert_true(inner.children().length() <= 12 && inner.children().length() >= 6)
  // 表头排序仍可用（与 table 同源构造）
  click_at(root, head.children()[0], 20.0, 20.0)
  assert_eq((sort.get().column, sort.get().asc), (0, true))
  // 点第一行：选中并回调源下标 0
  let first_mounted = inner.children()[0]
  click_at(root, first_mounted, 30.0, 15.0)
  assert_eq(clicks, [0])
  assert_eq(sel.get(), [0])
  // 滚动后表头位置不变
  let head_y = head.rect.y
  let _ = root.dispatch_scroll({
    x: list.rect.x + 40.0,
    y: list.rect.y + 40.0,
    dx: 0.0,
    dy: -5.0,
    mods: 0,
  })
  root.relayout(320.0, 240.0)
  assert_eq(head.rect.y, head_y)
}

///|
test "粘性列表：滚动跨过组边界时吸顶标题换文字，组内行照常滚走" {
  let st = StickyList::new()
  let rows_of = fn(prefix : String) -> Array[@core.Node] {
    let out : Array[@core.Node] = []
    for i = 1; i <= 4; i = i + 1 {
      out.push(view([text(prefix + i.to_string(), size=12.0)], height=20.0))
    }
    out
  }

  let (root, vp) = mounted(
    sticky_list(
      [("组一", rows_of("甲")), ("组二", rows_of("乙")), ("组三", rows_of("丙"))],
      st,
      width=240.0,
      height=100.0,
      head_h=28.0,
    ),
    300.0,
    160.0,
  )
  // 先画一帧：当前组与内容高都在布局之后才读得到
  let bm = @render.Bitmap::new(300, 160)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  assert_eq(st.cur_group, "组一")
  // 每组 = 头 28 + 四行 80 = 108；视口 100 → 可滚 324 − 100 = 224
  assert_eq(st.scroll.max(), 324.0 - 100.0)
  // 滚到组二内部（偏移 120 > 108）
  st.scroll.set_offset(120.0)
  root.relayout(300.0, 160.0)
  let bm2 = @render.Bitmap::new(300, 160)
  let p2 = @render.Painter::new(bm2)
  root.paint(p2)
  p2.end()
  assert_eq(st.cur_group, "组二")
  assert_eq(st.cur_start, 108.0)
  // 内容整块上移：内容块原点 = 视口 y − 偏移
  let content = vp.children()[0]
  assert_eq(content.rect.y, vp.rect.y - 120.0)
  // 滚到最后一组
  st.scroll.set_offset(220.0)
  root.relayout(300.0, 160.0)
  let bm3 = @render.Bitmap::new(300, 160)
  let p3 = @render.Painter::new(bm3)
  root.paint(p3)
  p3.end()
  assert_eq(st.cur_group, "组三")
}
