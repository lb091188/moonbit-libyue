// 导航族回归：分段/面包屑的选中写回、分页的页码与夹取、步骤条三态配色、
// 折叠面板的独立开合。绘制断言只比「两处颜色是否不同」，不锁具体色值。

///|
test "分段控制器：点某段即写 Store，选中段底色与其余段不同" {
  if !ui_text_guard() {
    return
  }
  let sel = @base.Store::new("甲")
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
test "面包屑：点非当前项直达、当前项与分隔符不改值" {
  let sel = @base.Store::new("首页")
  let (root, crumb) = mounted(
    breadcrumb(["首页", "列表", "详情"], sel),
    400.0,
    40.0,
  )
  // 3 项 + 2 个 "/"
  let kids = crumb.children()
  assert_eq(kids.length(), 5)
  // 分隔符不是链接
  click_at(root, kids[1], 4.0, 10.0)
  assert_eq(sel.get(), "首页")
  click_at(root, kids[2], 4.0, 10.0)
  assert_eq(sel.get(), "列表")
  // 末项也照样直达：旧规则按位置把「末项」当当前页，末项不是当前页时永远点不动
  click_at(root, kids[4], 4.0, 10.0)
  assert_eq(sel.get(), "详情")
  // 当前项（值等于导航状态的那一项）点它不改值
  click_at(root, kids[4], 4.0, 10.0)
  assert_eq(sel.get(), "详情")
  click_at(root, kids[0], 4.0, 10.0)
  assert_eq(sel.get(), "首页")
}

///|
test "分页：点页码直落、箭头步进、两端夹取不越界" {
  let cur = @base.Store::new(1)
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
  let cur = @base.Store::new(1)
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
  fn body(i : Int) -> @widget.Widget { cl.children()[i].children()[1] }

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
  let sel = @base.Store::new("首页")
  let (root, menu) = mounted(
    menu(["首页", "报表", "设置"], sel, icons=[("报表", @icons.IconKind::Box)]),
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
  let sel = @base.Store::new("甲一")
  let (root, menu) = mounted(
    menu_sections([
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
  let sel = @base.Store::new(0)
  let (root, tabs) = mounted(
    tabs(
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
  let left = @base.Store::new(["甲", "乙", "丙"])
  let right : @base.Store[Array[String]] = @base.Store::new([])
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

///|
/// P2-e 口径：导航族的项也走样式槽——class 的绘制期属性（经 `paint_subset` 投影）
/// 覆盖内置皮肤；「选中 × 悬停」的取色分支是数据态，留在调色回调里当回落值。
test "导航族只读样式槽：class 覆盖分段底色、页签字色与穿梭框描边" {
  if !ui_text_guard() {
    return
  }
  let warm_of = fn(node : @widget.Node, w : Double, h : Double) -> Int {
    let root = @widget.Widget::new()
    root.set_size(w, h)
    root.set_column()
    let _ = node.mount_into(root)
    root.relayout(w, h)
    let bm = @render.Bitmap::new(w.to_int(), h.to_int())
    let p = @render.Painter::new(bm)
    root.paint(p)
    p.end()
    let mut n = 0
    for y = 0; y < h.to_int(); y = y + 1 {
      for x = 0; x < w.to_int(); x = x + 1 {
        let c = bm.pixel(x, y)
        if c.r > 128 && c.g < 64 && c.b < 64 {
          n = n + 1
        }
      }
    }
    n
  }
  // 分段：内置皮肤只有选中段铺底，class 的底色铺进每一段
  let plain_seg = warm_of(segmented(["甲", "乙"], @base.Store::new("甲")), 300.0, 60.0)
  let classed_seg = warm_of(
    segmented(["甲", "乙"], @base.Store::new("甲"), class=[@style.style(background_color="#ff0000")]),
    300.0,
    60.0,
  )
  assert_true(plain_seg == 0)
  assert_true(classed_seg > 100)

  // 页签：未选中页签的文字色吃 class 的 color
  let plain_tab = warm_of(
    tabs([("概览", text("概览页")), ("明细", text("明细页"))], selected=@base.Store::new(0)),
    320.0,
    120.0,
  )
  let classed_tab = warm_of(
    tabs(
      [("概览", text("概览页")), ("明细", text("明细页"))],
      selected=@base.Store::new(0),
      class=[@style.style(color="#ff0000")],
    ),
    320.0,
    120.0,
  )
  assert_true(classed_tab > plain_tab)

  // 穿梭框：列表框的描边色与宽度吃 class（内置是 1px 主题描边色）
  let left = @base.Store::new(["甲", "乙"])
  let right : @base.Store[Array[String]] = @base.Store::new([])
  let plain_tr = warm_of(transfer(left, right, width=100.0), 320.0, 120.0)
  let classed_tr = warm_of(
    transfer(
      left,
      right,
      width=100.0,
      class=[@style.style(border_color="#ff0000", border_width=4.0)],
    ),
    320.0,
    120.0,
  )
  assert_true(classed_tr > plain_tr)
}

///|
test "穿梭框：面板默认 200×160，height= 可覆，项少也占满面板高" {
  let left = @base.Store::new(["甲"])
  let right : @base.Store[Array[String]] = @base.Store::new([])
  let (_, tr) = mounted(transfer(left, right), 460.0, 220.0)
  let lbox = tr.children()[0]
  assert_eq(lbox.rect.w, 200.0)
  assert_true(lbox.rect.h >= 160.0, msg="面板没有默认 160 高：\{lbox.rect.h}")
  let (_, tr2) = mounted(transfer(left, right, height=90.0), 460.0, 220.0)
  assert_true(tr2.children()[0].rect.h >= 90.0)
}

///|
test "键盘可及性：分段空格/回车选中本段，左右键在段间移动选中" {
  let sel = @base.Store::new("甲")
  let root = mount_root([segmented(["甲", "乙", "丙"], sel)], 300.0, 60.0)
  let seg = kid(root, 0)
  assert_eq(seg.kids.length(), 3)
  let item1 = seg.kids[1]
  assert_true(item1.focus_id > 0)
  let key = fn(ks : Int) -> Unit {
    let _ = root.dispatch_key(item1.focus_id, { press: true, keysym: ks, mods: 0, })
  }
  key(@base.KS_SPACE)
  assert_eq(sel.get(), "乙")
  key(@base.KS_LEFT)
  assert_eq(sel.get(), "甲")
  key(@base.KS_RIGHT)
  assert_eq(sel.get(), "丙")
  key(@base.KS_UP)
  assert_eq(sel.get(), "甲")
  // 回车/空格都是激活焦点段（乙），不是「确认当前选中」
  key(@base.KS_RETURN)
  assert_eq(sel.get(), "乙")
}

///|
/// 侧栏菜单键盘可及：声明 focus_id 进 Tab 链、空格/回车选中本项、方向键组内
/// 环绕换选（修复前 focus_ids 为空——Tab 进不了侧栏、也没有焦点环可画）。
test "menu_sections：键盘链可达且空格/方向键有效" {
  let selected = @base.Store::new("首页")
  let root = mount_root(
    [
      menu_sections([ ("导航", [ "首页", "组件", "文档" ]), ("其它", []) ], selected, width=180.0),
    ],
    300.0,
    500.0,
  )
  let ids = root.focus_ids()
  assert_eq(ids.length(), 3, msg="三个菜单项都应进 Tab 链")
  // 树里找第一个菜单项控件（focus_id 最小的树序项）
  fn find_by_focus(w : @widget.Widget, fid : Int) -> @widget.Widget? {
    if w.focus_id == fid {
      return Some(w)
    }
    for k in w.kids {
      match find_by_focus(k, fid) {
        Some(hit) => return Some(hit)
        None => ()
      }
    }
    None
  }
  let first = find_by_focus(root, ids[0])
  assert_true(first is Some(_))
  match first {
    None => ()
    Some(m) => {
      match m.on_key {
        None => fail("菜单项应挂 on_key")
        Some(k) => {
          // 空格选中本项
          assert_true(k({ press: true, keysym: @base.KS_SPACE, mods: 0 }))
          assert_eq(selected.get(), "首页")
          // 方向键 → 下一项（环绕取模）
          assert_true(k({ press: true, keysym: @base.KS_DOWN, mods: 0 }))
          assert_eq(selected.get(), "组件")
          assert_true(k({ press: true, keysym: @base.KS_UP, mods: 0 }))
          assert_eq(selected.get(), "文档") // 从第一项 UP 环绕到最后一项
          // 修饰键组合的按键不误触（比如 Ctrl+X 的 X 不是这里的业务）
          assert_false(k({ press: true, keysym: 120, mods: 2 }))
        }
      }
    }
  }
}
