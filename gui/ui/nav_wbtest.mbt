// 导航族回归：分段/面包屑的选中写回、分页的页码与夹取、步骤条三态配色、
// 折叠面板的独立开合。绘制断言只比「两处颜色是否不同」，不锁具体色值。

///|
test "分段控制器：点某段即写 Store，选中段底色与其余段不同" {
  if !ui_text_guard() {
    return
  }
  let sel = @core.Store::new("甲")
  let (root, seg) = mounted(segmented(["甲", "乙", "很长的一段"], sel), 400.0, 60.0)
  let items = seg.children()
  assert_eq(items.length(), 3)
  assert_true(items[2].rect.w > items[0].rect.w + 20.0)
  click_at(root, items[1], 6.0, 6.0)
  assert_eq(sel.get(), "乙")
  let bm = @render.Bitmap::new(400, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let y = (items[0].rect.y + 2.0).round().to_int()
  let plain = px(bm, (items[0].rect.x + 2.0).round().to_int(), y)
  let act = px(bm, (items[1].rect.x + 2.0).round().to_int(), y)
  assert_true(plain != act)
  click_at(root, items[2], 6.0, 6.0)
  assert_eq(sel.get(), "很长的一段")
}

///|
test "面包屑：分隔符占位、点非末项写 Store、末项不改值" {
  let sel = @core.Store::new("首页")
  let (root, crumb) = mounted(
    breadcrumb(["首页", "列表", "详情"], sel),
    400.0,
    40.0,
  )
  // 3 项 + 2 个 "/"
  assert_eq(crumb.children().length(), 5)
  click_at(root, crumb.children()[1], 1.0, 10.0)
  assert_eq(sel.get(), "首页")
  click_at(root, crumb.children()[2], 4.0, 10.0)
  assert_eq(sel.get(), "列表")
  // 末项（详情）是当前层，点它不改值
  click_at(root, crumb.children()[4], 4.0, 10.0)
  assert_eq(sel.get(), "列表")
}

///|
test "分页：点页码直落、箭头步进、两端夹取不越界" {
  let cur = @core.Store::new(1)
  let (root, pg) = mounted(pagination(cur, 5), 400.0, 40.0)
  // 左箭头 + 5 个页码 + 右箭头
  let kids = pg.children()
  assert_eq(kids.length(), 7)
  click_at(root, kids[3], 14.0, 14.0)
  assert_eq(cur.get(), 3)
  click_at(root, kids[6], 14.0, 14.0)
  assert_eq(cur.get(), 4)
  click_at(root, kids[6], 14.0, 14.0)
  assert_eq(cur.get(), 5)
  // 已在末页再点右箭头不动
  click_at(root, kids[6], 14.0, 14.0)
  assert_eq(cur.get(), 5)
  for _i = 0; _i < 8; _i = _i + 1 {
    click_at(root, kids[0], 14.0, 14.0)
  }
  assert_eq(cur.get(), 1)
  click_at(root, kids[0], 14.0, 14.0)
  assert_eq(cur.get(), 1)
}

///|
test "步骤条：已完成/当前/待办三态底色互不相同，连线随当前步着色" {
  let cur = @core.Store::new(1)
  let (root, st) = mounted(
    steps(["下单", "付款", "发货", "签收"], cur),
    500.0,
    60.0,
  )
  // 4 方块 + 4 文字 + 3 连线
  assert_eq(st.children().length(), 11)
  let bm = @render.Bitmap::new(500, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  // 交错排布：方块在 0/3/6/9，连线插在方块前（下标 2/5/8）
  let done = st.children()[0]
  let active = st.children()[3]
  let todo = st.children()[6]
  let y = (done.rect.y + 2.0).round().to_int()
  let c_done = px(bm, (done.rect.x + 2.0).round().to_int(), y)
  let c_active = px(bm, (active.rect.x + 2.0).round().to_int(), y)
  let c_todo = px(bm, (todo.rect.x + 2.0).round().to_int(), y)
  assert_true(c_done != c_active && c_active != c_todo && c_done != c_todo)
  // 连线：当前步之前的那段已着色，之后的那段仍是边框色
  let line1 = st.children()[2]
  let line3 = st.children()[5]
  let ly = (line1.rect.y + 1.0).round().to_int()
  let l1 = px(bm, (line1.rect.x + 4.0).round().to_int(), ly)
  let l3 = px(bm, (line3.rect.x + 4.0).round().to_int(), ly)
  assert_true(l1 != l3)
  cur.set(3)
  let bm2 = @render.Bitmap::new(500, 60)
  let p2 = @render.Painter::new(bm2)
  root.paint(p2)
  p2.end()
  // 走到第 4 步后，原来「待办」的方块不再是待办色
  assert_true(px(bm2, (todo.rect.x + 2.0).round().to_int(), y) != c_todo)
}

///|
test "折叠面板：默认只开第一块，各块独立开合、收起即不占高" {
  if !ui_text_guard() {
    return
  }
  let (root, cl) = mounted(
    collapse([
      ("面板一", [text("内容一")]),
      ("面板二", [text("内容二")]),
      ("面板三", [text("内容三")]),
    ]),
    400.0,
    240.0,
  )
  assert_eq(cl.children().length(), 3)
  fn body(i : Int) -> @core.Widget { cl.children()[i].children()[1] }

  assert_eq([body(0).visible, body(1).visible, body(2).visible], [true, false, false])
  // 点第二块标题行：只开它自己
  click_at(root, cl.children()[1].children()[0], 30.0, 10.0)
  assert_eq([body(0).visible, body(1).visible], [true, true])
  // 再点第一块标题行：关掉第一块，第二块不受影响
  click_at(root, cl.children()[0].children()[0], 30.0, 10.0)
  assert_eq([body(0).visible, body(1).visible], [false, true])
  // 收起的面板不占高度：整块高度回落
  root.relayout(400.0, 240.0)
  let h_two = cl.rect.h
  click_at(root, cl.children()[1].children()[0], 30.0, 10.0)
  root.relayout(400.0, 240.0)
  assert_true(cl.rect.h < h_two)
}

///|
test "侧边菜单：项宽跟随容器、点项写 Store、选中项底色与未选不同" {
  let sel = @core.Store::new("首页")
  let (root, menu) = mounted(
    side_menu(["首页", "报表", "设置"], sel, icons=[("报表", @icons.IconKind::Box)]),
    300.0,
    200.0,
  )
  let kids = menu.children()
  assert_eq(kids.length(), 3)
  assert_eq(kids[0].rect.w, 168.0)
  assert_eq(kids[0].rect.h, 40.0)
  let bm = @render.Bitmap::new(300, 200)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let bg = px(bm, (menu.rect.x + 2.0).round().to_int(), (menu.rect.y + 2.0).round().to_int())
  // 两列同宽同 x，取样必须各按自己行的 y（按第一行的 y 取会落进选中行里）
  let y0 = (kids[0].rect.y + 4.0).round().to_int()
  let y1 = (kids[1].rect.y + 4.0).round().to_int()
  assert_true(px(bm, (kids[0].rect.x + 4.0).round().to_int(), y0) != bg)
  assert_eq(px(bm, (kids[1].rect.x + 4.0).round().to_int(), y1), bg)
  click_at(root, kids[1], 30.0, 20.0)
  assert_eq(sel.get(), "报表")
}

///|
test "分组侧边菜单：标题行收起/展开只影响本组" {
  let sel = @core.Store::new("甲一")
  let (root, menu) = mounted(
    side_menu_sections([
      ("组一", ["甲一", "甲二"]),
      ("组二", ["乙一", "乙二"]),
    ], sel),
    300.0,
    300.0,
  )
  // 每组「标题 + 组内项表」两块
  let kids = menu.children()
  assert_eq(kids.length(), 4)
  assert_eq([kids[1].visible, kids[3].visible], [true, true])
  click_at(root, kids[0], 30.0, 10.0)
  root.relayout(300.0, 300.0)
  assert_eq([kids[1].visible, kids[3].visible], [false, true])
  // 收起组二（组一收起后整列上移，标题坐标必须从刷新后的 rect 取）
  click_at(root, kids[2], 30.0, 10.0)
  root.relayout(300.0, 300.0)
  assert_eq([kids[1].visible, kids[3].visible], [false, false])
  // 再点一次组二标题展开，组内项即可选
  click_at(root, kids[2], 30.0, 10.0)
  root.relayout(300.0, 300.0)
  assert_eq(kids[3].visible, true)
  click_at(root, kids[3].children()[1], 30.0, 20.0)
  assert_eq(sel.get(), "乙二")
}

///|
test "树：子层预建即收起，点父行展开、点叶子行不动作" {
  let root_nodes : Array[TreeNode] = [
    {
      label: "根一",
      children: [
        { label: "子一", children: [] },
        { label: "子二", children: [] },
      ],
    },
    { label: "叶子", children: [] },
  ]
  let (root, tr) = mounted(tree(root_nodes), 320.0, 240.0)
  // 每个节点贡献「行 + 子层容器」两块
  let kids = tr.children()
  assert_eq(kids.length(), 4)
  assert_eq([kids[1].visible, kids[3].visible], [false, false])
  assert_eq(kids[1].children().length(), 4)
  // 点「根一」行：子层展开
  click_at(root, kids[0], 40.0, 16.0)
  assert_eq(kids[1].visible, true)
  // 点叶子行：它没有子层，容器仍收起
  click_at(root, kids[2], 40.0, 16.0)
  assert_eq(kids[3].visible, false)
  assert_eq(kids[1].visible, true)
  // 再点一次父行：收起
  click_at(root, kids[0], 40.0, 16.0)
  assert_eq(kids[1].visible, false)
}

///|
test "页签：预建三页只显当前页，点页签与外部改 Store 都换页" {
  let sel = @core.Store::new(0)
  let (root, tabs) = mounted(
    tabs_t(
      [("概览", text("概览页")), ("明细", text("明细页")), ("设置", text("设置页"))],
      selected=sel,
    ),
    320.0,
    200.0,
  )
  let kids = tabs.children()
  assert_eq(kids.length(), 4)
  let head = kids[0]
  assert_eq(head.children().length(), 3)
  assert_eq([kids[1].visible, kids[2].visible, kids[3].visible], [true, false, false])
  click_at(root, head.children()[1], 10.0, 18.0)
  assert_eq(sel.get(), 1)
  assert_eq([kids[1].visible, kids[2].visible], [false, true])
  // 外部改 Store 也换页（订阅走 show，不只是重绘）
  sel.set(2)
  assert_eq([kids[1].visible, kids[2].visible, kids[3].visible], [false, false, true])
  // 页签头行在最上，页区紧随其后
  assert_true(head.rect.y < kids[1].rect.y)
}

///|
test "穿梭框：点行选中、箭头搬运、搬完清空选中、外部改数据整列重建" {
  let left = @core.Store::new(["甲", "乙", "丙"])
  let right : @core.Store[Array[String]] = @core.Store::new([])
  let (root, tr) = mounted(transfer(left, right, width=120.0), 320.0, 120.0)
  let kids = tr.children()
  assert_eq(kids.length(), 4)
  let lbox = kids[0]
  let rbox = kids[3]
  assert_eq([lbox.children().length(), rbox.children().length()], [3, 0])
  // 选「甲」再搬过去
  click_at(root, lbox.children()[0], 40.0, 10.0)
  click_at(root, kids[1], 16.0, 14.0)
  // 搬完是「整列重建」，新行要到下一次布局才有矩形（宿主每帧都会重排）
  root.relayout(320.0, 120.0)
  assert_eq([lbox.children().length(), rbox.children().length()], [2, 1])
  // 选中已清空：再点右箭头不会继续搬
  click_at(root, kids[1], 16.0, 14.0)
  // 空搬运也会 set 两个 Store（值相同也算变更）→ 又重建一次，坐标仍要重取
  root.relayout(320.0, 120.0)
  assert_eq([lbox.children().length(), rbox.children().length()], [2, 1])
  // 反向搬回
  click_at(root, rbox.children()[0], 40.0, 10.0)
  click_at(root, kids[2], 16.0, 14.0)
  root.relayout(320.0, 120.0)
  assert_eq([lbox.children().length(), rbox.children().length()], [3, 0])
  // 外部改数据：订阅驱动整列重建（不是只重绘）
  left.set(["只有一项"])
  assert_eq(lbox.children().length(), 1)
  right.set(["外", "部", "两", "项"])
  assert_eq(rbox.children().length(), 4)
}
