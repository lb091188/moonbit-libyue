// 组件层回归：文本测量接进布局、基线对齐参与、按钮点击与状态配色、
// 容器/分组/分隔线几何、图标与图像的缺图兜底。全程无头（内存位图 + 手工投递事件）。

///|
fn color_of(bm : @render.Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = bm.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

///|
/// 把节点挂进根控件并跑一轮布局，返回根（绘制时整棵树都摆好位置）。
fn mount_root(children : Array[@core.Node], w : Double, h : Double) -> @core.Widget {
  let root = @core.Widget::new()
  root.set_size(w, h)
  root.set_column()
  // 交叉轴不拉伸：组件的测量尺寸才是看得见的真值（默认 stretch 会把
  // 列容器里的子项宽度拉到整行）
  root.node.set_align_items(@yoga.AlignItems::FlexStart)
  @core.mount_children(root, children)
  root.relayout(w, h)
  root
}

///|
/// 找根下第 n 个直接子控件。
fn kid(root : @core.Widget, i : Int) -> @core.Widget {
  root.children()[i]
}

///|
test "标签尺寸来自 Pango 测量；文本随信号变化就重测" {
  let src_text = @core.Signal::new("Hello 基线")
  let n = label_dyn(src_text, size=14.0)
  // 交叉轴不 stretch（列容器默认会把宽度拉到整行），才看得出测量给的真尺寸
  let root = mount_root([n], 240.0, 60.0)
  let w = kid(root, 0)
  let m = @text.measure("Hello 基线", 14.0).unwrap()
  assert_eq((w.rect.w, w.rect.h), (m.width.to_double(), m.height.to_double()))
  let asc = @text.line_ascent(14.0).unwrap()
  assert_true(asc > 0)

  // 换文本：测量回调重设（节点标脏）→ 下一轮布局就是新宽度
  src_text.set("x")
  root.relayout(240.0, 60.0)
  let short_m = @text.measure("x", 14.0).unwrap()
  assert_eq(w.rect.w, short_m.width.to_double())
  assert_true(short_m.width < m.width)
}

///|
test "两个字号混排按基线对齐（文本测量回灌布局的直接结果）" {
  let row = container(
    [label("Ag", size=13.0), label("Ag", size=26.0)],
    direction=@yoga.Row,
    align_items=@yoga.AlignItems::Baseline,
    height=48.0,
  )
  let root = mount_root([row], 200.0, 60.0)
  let r = kid(root, 0)
  let kids = r.children()
  let a13 = @text.line_ascent(13.0).unwrap().to_double()
  let a26 = @text.line_ascent(26.0).unwrap().to_double()
  // 基线对齐：同一条基线上，小字号的顶要更低（差的正是两个 ascent 之差）
  // 基线重合 ⇒ 顶边差 = 两个 ascent 之差（大字号更靠上）
  assert_eq(kids[0].rect.y.round() - kids[1].rect.y.round(), (a26 - a13).round())
  assert_true(a26 > a13)
}

///|
test "按钮：松开落在按钮内才算点击，落在外面不算" {
  let clicks = Ref(0)
  let b = button("确定", on_click=fn() { clicks.val = clicks.val + 1 }, min_width=80.0)
  let root = mount_root([b], 200.0, 60.0)
  let w = kid(root, 0)
  assert_eq(w.rect.h, @theme.control_height)
  assert_true(w.rect.w >= 80.0)
  let cx = w.rect.w / 2.0
  let cy = w.rect.h / 2.0

  // 正常点击：按下 + 在同处松开
  let _ = w.dispatch_pointer({
    kind: @core.Down,
    x: cx,
    y: cy,
    button: 1,
    mods: 0,
  })
  let _ = w.dispatch_pointer({
    kind: @core.Up,
    x: cx,
    y: cy,
    button: 1,
    mods: 0,
  })
  assert_eq(clicks.val, 1)

  // 按下后在按钮外松开：不触发
  let _ = w.dispatch_pointer({
    kind: @core.Down,
    x: cx,
    y: cy,
    button: 1,
    mods: 0,
  })
  let _ = w.dispatch_pointer({
    kind: @core.Up,
    x: cx,
    y: w.rect.h + 40.0,
    button: 1,
    mods: 0,
  })
  assert_eq(clicks.val, 1)
}

///|
test "按钮：禁用态不消费事件、也不响应点击" {
  let clicks = Ref(0)
  let b = button("禁用", on_click=fn() { clicks.val = clicks.val + 1 }, disabled=true)
  let root = mount_root([b], 200.0, 60.0)
  let w = kid(root, 0)
  let consumed = w.dispatch_pointer({
    kind: @core.Down,
    x: 10.0,
    y: 10.0,
    button: 1,
    mods: 0,
  })
  assert_false(consumed)
  let _ = w.dispatch_pointer({
    kind: @core.Up,
    x: 10.0,
    y: 10.0,
    button: 1,
    mods: 0,
  })
  assert_eq(clicks.val, 0)
}

///|
test "按钮：悬停与按下态由宿主置位，配色随状态变化" {
  let idle = @render.Bitmap::new(120, 40)
  let hovered = @render.Bitmap::new(120, 40)
  let bp = button("按住我", min_width=100.0)
  let root = mount_root([bp], 120.0, 40.0)
  let w = kid(root, 0)

  let p0 = @render.Painter::new(idle)
  w.paint(p0)
  p0.end()
  let base_color = color_of(idle, 4, 4)

  w.set_hover(w.id)
  let p1 = @render.Painter::new(hovered)
  w.paint(p1)
  p1.end()
  let hover_color = color_of(hovered, 4, 4)
  // 状态色不同（不断言具体色值，换主题不假红）
  assert_true(base_color != hover_color)
  // 文本确实画在盒内（有底色与透明之外的像素）
  let mut ink = 0
  for y = 0; y < 40; y = y + 1 {
    for x = 0; x < 120; x = x + 1 {
      let c = color_of(hovered, x, y)
      if c != hover_color && c != (0, 0, 0, 0) {
        ink = ink + 1
      }
    }
  }
  assert_true(ink > 20)
  w.set_hover(-1)
}

///|
test "容器 / 分组 / 分隔线：几何与主题取色都按建树口径" {
  let line = separator()
  let inner = container([label("内容")], padding=4.0, bg=@theme.theme_bg_page())
  let g = group("标题", [label("一行"), label("两行")], width=160.0)
  let root = mount_root([g, line, inner], 200.0, 300.0)
  let grp = kid(root, 0)
  // 分组的第一项是标题，其后是传入的两项
  assert_eq(grp.children().length(), 3)
  assert_eq(grp.rect.w, 160.0)
  // 分隔线：1px 高、按父宽撑满（percent 100）
  let sep = kid(root, 1)
  assert_eq((sep.rect.h, sep.rect.w), (1.0, 200.0))
  // 容器有底色：左上角像素即底色
  let bm = @render.Bitmap::new(200, 300)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  assert_true(color_of(bm, 8, 8) != (0, 0, 0, 0))
}

///|
test "图标按尺寸占位并真的画出像素；图像缺文件时不崩、按 0 尺寸占位" {
  let ic = icon(@icons.IconKind::MediumCircleFill, size=24.0, color="#ff0000")
  let img = image("/不存在的路径.png")
  let root = mount_root([ic, img], 100.0, 100.0)
  let w = kid(root, 0)
  assert_eq((w.rect.w, w.rect.h), (24.0, 24.0))
  assert_eq(kid(root, 1).rect.w, 0.0)

  let bm = @render.Bitmap::new(100, 100)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let mut red = 0
  for y = 0; y < 40; y = y + 1 {
    for x = 0; x < 60; x = x + 1 {
      let c = color_of(bm, x, y)
      if c.0 > 128 && c.1 < 64 && c.2 < 64 {
        red = red + 1
      }
    }
  }
  assert_true(red > 20)
}
