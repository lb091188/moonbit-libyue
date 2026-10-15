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
/// 文本测量后端的守卫：本平台的文字层还没接上时（Windows 走 DirectWrite，
/// 见 TODO 的 W5），measure/line_ascent 给 None，「尺寸来自测量」这类断言
/// 无从比较——打印跳过，其余不依赖文本的断言照常跑。
fn ui_text_guard() -> Bool {
  match @text.measure("Ag", 13.0) {
    Some(_) => true
    None => {
      println("ui: skip (无文本测量后端)")
      false
    }
  }
}

///|
/// 图片解码后端的守卫：Linux 走 GdkPixbuf、Windows 走 WIC（W9），macOS 的解码桩
/// 还没实装；解不出图时组件退成 0 尺寸，动图断言无从谈起——打印跳过。
/// moon test 的测试进程 cwd 是模块根（`gui/`），示例资源在仓根 `examples/` 下，
/// 两个候选都试（同 `render` 包 image_wbtest 的 test_asset 口径）。
fn ui_decode_guard() -> Bool {
  if @render.Image::new_from_file(gif_asset()).get_width() > 0.0 {
    true
  } else {
    println("ui: skip (无图片解码后端)")
    false
  }
}

///|
/// 动图资源路径：moon test 的测试进程 cwd 是模块根（`gui/`），示例资源在仓根
/// `examples/` 下——两个候选都试，哪个解得出图用哪个（同 render 包 test_asset）。
fn gif_asset() -> String {
  for rel in [
    "examples/showcase/assets/dot.gif", "../examples/showcase/assets/dot.gif",
  ] {
    if @render.Image::new_from_file(rel).get_width() > 0.0 {
      return rel
    }
  }
  "examples/showcase/assets/dot.gif"
}

///|
test "标签尺寸来自 Pango 测量；文本随信号变化就重测" {
  if !ui_text_guard() {
    return
  }
  let src_text = @core.Signal::new("Hello 基线")
  let n = text_dyn(src_text, font_size=14.0)
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
  if !ui_text_guard() {
    return
  }
  let row = view(
    [text("Ag", font_size=13.0), text("Ag", font_size=26.0)],
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
test "按钮：光标请求跟着禁用单元走（禁用不请求手型，改回可用立刻恢复）" {
  let cell = Enabled::new(true)
  let b = button("禁用", enabled=Some(cell), min_width=80.0)
  let root = mount_root([b], 200.0, 60.0)
  let w = kid(root, 0)
  let cx = w.rect.x + w.rect.w / 2.0
  let cy = w.rect.y + w.rect.h / 2.0
  // 禁用：本控件不提请求 → 默认箭头（光标请求是命中查询时现算的）
  assert_eq(root.cursor_at(cx, cy), @core.CURSOR_DEFAULT)
  // 同一个单元改回可用：下一次查询就是手型，不必重建控件
  set_disabled(cell, false)
  assert_eq(root.cursor_at(cx, cy), @core.CURSOR_HAND)
  set_disabled(cell, true)
  assert_eq(root.cursor_at(cx, cy), @core.CURSOR_DEFAULT)
}

///|
test "按钮：悬停与按下态由宿主置位，配色随状态变化" {
  if !ui_text_guard() {
    return
  }
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
  let line = divider()
  let inner = view([text("内容")], padding=4.0, background_color="bg_page")
  let g = panel("标题", [text("一行"), text("两行")], width=160.0)
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

///|
/// 回归：文本必须随控件原点落位、并被控件矩形裁住。
/// 曾经的缺陷是文本层自建 surface 画字，无视宿主的 translate/clip——
/// 真窗口截图上整屏文字全挤在左上角（见 adaptation 的组件层首批条）。
test "文本随控件原点落位并被裁剪（画在 Painter 会话上）" {
  if !ui_text_guard() {
    return
  }
  let top = text("AAAA", font_size=20.0)
  let bottom = text("BBBB", font_size=20.0)
  let root = @core.Widget::new()
  root.set_size(200.0, 200.0)
  root.set_column()
  let a = @core.Widget::new()
  a.set_size(200.0, 100.0)
  let b = @core.Widget::new()
  b.set_size(200.0, 100.0)
  root.append_child(a)
  root.append_child(b)
  let _ = top.mount_into(a)
  let _ = bottom.mount_into(b)
  root.relayout(200.0, 200.0)
  assert_true(b.rect.y >= 100.0)

  let bm = @render.Bitmap::new(200, 200)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let ink_in = fn(y0 : Int, y1 : Int) -> Int {
    let mut n = 0
    for y = y0; y < y1; y = y + 1 {
      for x = 0; x < 200; x = x + 1 {
        if color_of(bm, x, y) != (0, 0, 0, 0) {
          n = n + 1
        }
      }
    }
    n
  }
  // 两段各自有字：下半段没落位就是 0
  assert_true(ink_in(0, 100) > 20)
  assert_true(ink_in(100, 200) > 20)

  // 裁剪：窄盒里的长文本不得画到盒外
  let narrow = @core.Widget::new()
  narrow.set_size(24.0, 24.0)
  let src = text_source("WWWWWWWWWWWWWWWWWW", font_size=20.0, wrap=false)
  narrow.on_draw = Some(fn(
    self : @core.Widget,
    pp : @render.Painter,
    _r : @core.Rect,
  ) -> Unit {
      let _ = draw_text_in(self, pp, src)
    })
  let holder = @core.Widget::new()
  holder.set_size(200.0, 200.0)
  holder.append_child(narrow)
  holder.relayout(200.0, 200.0)
  let bm2 = @render.Bitmap::new(200, 200)
  let p2 = @render.Painter::new(bm2)
  holder.paint(p2)
  p2.end()
  // 24px 之外不该有字（盒外的 W 会被 clip 掉）
  assert_eq(ink_at(bm2, 40, 60), (0, 0, 0, 0))
  assert_eq(ink_at(bm2, 120, 10), (0, 0, 0, 0))
  // 盒内有字
  assert_true(ink_in_box(bm2, 24, 24) > 4)
}

///|
fn ink_at(bm : @render.Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  color_of(bm, x, y)
}

///|
fn ink_in_box(bm : @render.Bitmap, x1 : Int, y1 : Int) -> Int {
  let mut n = 0
  for y = 0; y < y1; y = y + 1 {
    for x = 0; x < x1; x = x + 1 {
      if color_of(bm, x, y) != (0, 0, 0, 0) {
        n = n + 1
      }
    }
  }
  n
}

///|
test "图标按钮：尺寸固定、悬停换底色、点击在抬起且落在框内、禁用不吃事件" {
  let mut hits = 0
  let root = mount_root(
    [icon_button(@icons.Close2, on_click=fn() { hits = hits + 1 }, box_size=24.0)],
    120.0,
    60.0,
  )
  let w = kid(root, 0)
  assert_eq((w.rect.w, w.rect.h), (24.0, 24.0))
  let (bm0, ox, oy) = shot(w)
  // 图标本身出像素（中心附近有墨）
  assert_true(color_of(bm0, ox + 12, oy + 12) != (0, 0, 0, 0))
  root.set_hover(w.id)
  let (bm1, _, _) = shot(w)
  // 悬停多了圆角底：上缘中点从透明变成有底色（贴角那格被圆角裁掉，不能取）
  assert_true(color_of(bm1, ox + 12, oy + 2) != color_of(bm0, ox + 12, oy + 2))
  root.set_hover(0)
  let _ = click(w, w.rect.x + 12.0, w.rect.y + 12.0)
  assert_eq(hits, 1)
  // 抬起在框外：不算一次点击
  let _ = w.dispatch_pointer({ kind: @core.Down, x: 4.0, y: 4.0, button: 1, mods: 0, })
  let _ = w.dispatch_pointer({
    kind: @core.Up,
    x: 4.0,
    y: w.rect.y + 90.0,
    button: 1,
    mods: 0,
  })
  assert_eq(hits, 1)
  let mut off_hits = 0
  let root2 = mount_root(
    [icon_button(@icons.Close2, on_click=fn() { off_hits = off_hits + 1 }, disabled=true)],
    120.0,
    60.0,
  )
  let w2 = kid(root2, 0)
  let consumed = click(w2, w2.rect.x + 6.0, w2.rect.y + 6.0)
  assert_false(consumed)
  assert_eq(off_hits, 0)
}

///|
test "动图组件：按帧时长自转换帧、暂停不再换帧、play 续上；静图不排自转" {
  if !ui_decode_guard() {
    return
  }
  let queue : Ref[Array[() -> Unit]] = Ref([])
  let delays : Ref[Array[Int]] = Ref([])
  @core.set_timer_hooks(
    fn(ms : Int, f : () -> Unit) -> Int {
      delays.val.push(ms)
      queue.val.push(f)
      delays.val.length()
    },
    fn(_id : Int) -> Unit { () },
  )
  let h = GifHandle::make()
  let (r, w) = mounted(
    gif(gif_asset(), state=h),
    160.0,
    160.0,
  )
  // 自转换帧的前提是「这一帧被画到」：先画一帧，动图才算挂在看得见的地方
  let bm_seen = @render.Bitmap::new(160, 160)
  let p_seen = @render.Painter::new(bm_seen)
  r.paint(p_seen)
  p_seen.end()
  // 尺寸取自动图本身（未显式给宽高的分支）
  assert_eq((w.rect.w, w.rect.h), (120.0, 120.0))
  assert_eq(delays.val.length(), 1)
  assert_true(delays.val[0] > 0)
  // 队空时是空操作（暂停断链之后就是空的，再 fire 不该崩）
  let fire = fn() -> Unit {
    let q = queue.val
    if q.length() > 0 {
      let f = q[q.length() - 1]
      q.truncate(q.length() - 1)
      f()
    }
  }
  // 每拍只把虚拟时钟推「一帧时长 +1ms」，换不换帧由加载器判：连推 12 拍
  // 应该走出若干帧（本素材每帧 400ms、每拍 101ms → 约 3 帧）
  let before = h.frame_count()
  let mut n = 0
  while n < 12 {
    fire()
    n = n + 1
  }
  // 换帧节奏由加载器定：Windows(WIC) 一拍一帧（组件按 delay_ms 节奏问一次进
  // 一帧）、Linux(io-gif) 按虚拟时钟锚定锚点——每拍推进几帧各平台不同，平台
  // 无关的口径是「12 拍确实在走、且没失控一拍多帧」（12 拍至多 12 帧）
  assert_true(h.frame_count() >= 2 && h.frame_count() <= 12)
  let walked = h.frame_count()
  h.pause()
  fire()
  fire()
  // 暂停后待触发的那一拍跑完就断链，帧数不再前进
  assert_eq((h.frame_count(), h.is_running()), (walked, false))
  // play 当场续上一拍，之后按节奏继续走
  h.play()
  assert_true(delays.val.length() > 2)
  let mut m = 0
  while m < 8 {
    fire()
    m = m + 1
  }
  assert_true(h.frame_count() > walked)
  ignore(before)
  // 画得出东西：动图帧确实进了位图（不是一片空）
  let (bm, _, _) = shot(w)
  let mut ink = 0
  for y = 0; y < 120; y = y + 1 {
    for x = 0; x < 120; x = x + 1 {
      if color_of(bm, x, y) != (0, 0, 0, 0) {
        ink = ink + 1
      }
    }
  }
  assert_true(ink > 100)
  // 缩到 48×48 也画得出来（目标尺寸与图幅不符时走缩放那条路）
  let hg2 = GifHandle::make()
  let (_r4, w4) = mounted(gif(gif_asset(), width=48.0, height=48.0, state=hg2), 80.0, 80.0)
  let (bm2, _, _) = shot(w4)
  let mut ink2 = 0
  for y = 0; y < 48; y = y + 1 {
    for x = 0; x < 48; x = x + 1 {
      if color_of(bm2, x, y) != (0, 0, 0, 0) {
        ink2 = ink2 + 1
      }
    }
  }
  assert_eq((w4.rect.w, w4.rect.h), (48.0, 48.0))
  assert_true(ink2 > 40)
  // 静图：解得出图但没有下一帧，不排自转、也不换帧
  let hs = GifHandle::make()
  let (_r2, _w2) = mounted(gif("/tmp/definitely-missing-gif.png", state=hs), 80.0, 80.0)
  assert_eq((hs.frame_count(), hs.is_running(), _w2.rect.w), (0, true, 0.0))
  @core.set_timer_hooks(fn(_ms, _f) { 0 }, fn(_id) { () })
}

///|
/// P2-e 口径：绘制期只读样式槽并按状态选桶，`class` 的属性必须真的落进像素。
test "样式槽是绘制期唯一入口：底色/圆角/边框宽与状态桶都照画" {
  let rounded = view(
    [],
    width=60.0,
    height=40.0,
    class=[@style.style(background_color="#ff0000", border_radius=12.0)],
  )
  let root = mount_root([rounded], 100.0, 60.0)
  let w = kid(root, 0)
  assert_eq((w.rect.w, w.rect.h), (60.0, 40.0))
  let bm = @render.Bitmap::new(100, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  let red = fn(x : Int, y : Int) -> Bool {
    let c = color_of(bm, x, y)
    c.0 > 128 && c.1 < 64 && c.2 < 64
  }
  assert_true(red(30, 20))
  // 左上角落在半径 12 的弧外：圆角真的裁剪了填充
  assert_false(red(1, 1))

  // 状态桶：hover / focus / active 各自换底色，并存时按 hover < focus < active
  let src = view(
    [],
    width=40.0,
    height=40.0,
    class=[
      @style.style(background_color="#00ff00")
        .hover(background_color="#ff0000")
        .focus(background_color="#ffff00")
        .active(background_color="#0000ff"),
    ],
  )
  let root2 = mount_root([src], 60.0, 60.0)
  let w2 = kid(root2, 0)
  let centre : () -> (Int, Int, Int, Int) = fn() -> (Int, Int, Int, Int) {
    let b = @render.Bitmap::new(60, 60)
    let pp = @render.Painter::new(b)
    root2.paint(pp)
    pp.end()
    color_of(b, 20, 20)
  }
  let base_c = centre()
  assert_true(base_c.1 > 128 && base_c.0 < 64)
  w2.hovered = true
  let hov = centre()
  assert_true(hov.0 > 128 && hov != base_c)
  // 按下必然也在悬停里：active 要盖过 hover 才看得见按下反馈
  w2.pressed = true
  let act = centre()
  assert_true(act.2 > 128 && act != hov)
  w2.pressed = false
  w2.hovered = false
  w2.focused = true
  let foc = centre()
  assert_true(foc.0 > 128 && foc.1 > 128 && foc.2 < 64)

  // 边框宽是绘制期属性：class 给 4px 就比默认 1px 粗
  let thin = view([], width=40.0, height=40.0, class=[
    @style.style(border_color="#ff0000", border_width=1.0),
  ])
  let thick = view([], width=40.0, height=40.0, class=[
    @style.style(border_color="#ff0000", border_width=5.0),
  ])
  let root3 = mount_root([thin, thick], 60.0, 120.0)
  let ink_col = fn(bm : @render.Bitmap, y : Int) -> Int {
    let mut n = 0
    for x = 0; x < 40; x = x + 1 {
      if color_of(bm, x, y).0 > 96 {
        n = n + 1
      }
    }
    n
  }
  let bm3 = @render.Bitmap::new(60, 120)
  let p3 = @render.Painter::new(bm3)
  root3.paint(p3)
  p3.end()
  assert_true(ink_col(bm3, 60) > ink_col(bm3, 20))
}

///|
test "内置皮肤也走样式槽：图标按钮悬停/按下有底、divider 与 icon 能被 class 改色" {
  let ib = icon_button(@icons.IconKind::MediumCircleFill, box_size=32.0)
  let root = mount_root([ib], 60.0, 60.0)
  let w = kid(root, 0)
  let ink : () -> Int = fn() -> Int {
    let b = @render.Bitmap::new(60, 60)
    let pp = @render.Painter::new(b)
    root.paint(pp)
    pp.end()
    let mut n = 0
    for y = 0; y < 32; y = y + 1 {
      for x = 0; x < 32; x = x + 1 {
        if color_of(b, x, y).3 > 0 {
          n = n + 1
        }
      }
    }
    n
  }
  let plain = ink()
  w.hovered = true
  assert_true(ink() > plain)
  w.pressed = true
  let pressed_ink = ink()
  w.hovered = false
  w.pressed = false
  assert_true(pressed_ink > plain)

  // divider 两档：直线档吃散参数，文字档的线与字各自吃 class 的 background_color / color
  let d = divider(text="或", class=[
    @style.style(background_color="#ff0000", color="#0000ff"),
  ])
  let root2 = mount_root([d], 200.0, 30.0)
  assert_eq(kid(root2, 0).rect.h, 20.0)
  let bm2 = @render.Bitmap::new(200, 30)
  let p2 = @render.Painter::new(bm2)
  root2.paint(p2)
  p2.end()
  let mut warm = 0
  let mut cool = 0
  for y = 0; y < 30; y = y + 1 {
    for x = 0; x < 200; x = x + 1 {
      let c = color_of(bm2, x, y)
      if c.0 > 128 && c.2 < 64 {
        warm = warm + 1
      }
      if c.2 > 128 && c.0 < 64 {
        cool = cool + 1
      }
    }
  }
  assert_true(warm > 40)
  assert_true(cool > 4)

  // icon 的 class 色覆盖内置正文色
  let ic = icon(@icons.IconKind::MediumCircleFill, size=24.0, class=[
    @style.style(color="#00ff00"),
  ])
  let root3 = mount_root([ic], 40.0, 40.0)
  let bm3 = @render.Bitmap::new(40, 40)
  let p3 = @render.Painter::new(bm3)
  root3.paint(p3)
  p3.end()
  let mut green = 0
  for y = 0; y < 24; y = y + 1 {
    for x = 0; x < 24; x = x + 1 {
      let c = color_of(bm3, x, y)
      if c.1 > 128 && c.0 < 64 && c.2 < 64 {
        green = green + 1
      }
    }
  }
  assert_true(green > 20)
}

///|
/// §1.5「散参数只有一条去向」的布局半边：`width` / `padding` 这类散参数折进匿名块，
/// `class` 排在后面 ⇒ 同名属性由 class 赢，节点上没有第二条写入路径。
test "布局散参数也折进匿名块：class 的宽与内边距盖过散参数" {
  let inner_node = view([], width=40.0, height=10.0)
  let loose = mount_root(
    [view([inner_node], padding=4.0, width=120.0, height=60.0)],
    260.0,
    120.0,
  )
  let box = kid(loose, 0)
  assert_eq(box.rect.w, 120.0)
  // 内边距 4 ⇒ 子项落在 (4,4)
  assert_eq((box.children()[0].rect.x - box.rect.x).round(), 4.0)

  let strict = mount_root(
    [
      view(
        [view([], width=40.0, height=10.0)],
        padding=4.0,
        width=120.0,
        height=60.0,
        class=[@style.style(padding=20.0, width=300.0)],
      ),
    ],
    360.0,
    120.0,
  )
  let box2 = kid(strict, 0)
  assert_eq(box2.rect.w, 300.0)
  assert_eq((box2.children()[0].rect.x - box2.rect.x).round(), 20.0)
}

///|
/// §1.1「文本与颜色」那半张表接上真生效路径：`text_align` / `white_space` /
/// `line_height` / `text_decoration` 由样式槽驱动测量与绘制（投影档已撤，见 style.mbt）。
test "文本类样式属性真生效：对齐/换行/行高/下划线" {
  if !ui_text_guard() {
    return
  }
  // 返回（首墨列, 有墨行数, 墨像素数）：对齐比首列，折行比行数，
  // 下划线比墨量（行距里落进最后一行的线不算「多一行」）
  let ink_scan = fn(node : @core.Node, w : Double, h : Double) -> (
    Int,
    Int,
    Int,
  ) {
    let root = mount_root([node], w, h)
    let bm = @render.Bitmap::new(w.to_int(), h.to_int())
    let p = @render.Painter::new(bm)
    root.paint(p)
    p.end()
    let mut first = -1
    let mut rows = 0
    let mut ink = 0
    for y = 0; y < h.to_int(); y = y + 1 {
      let mut row_ink = 0
      for x = 0; x < w.to_int(); x = x + 1 {
        if bm.pixel(x, y).a > 0 {
          row_ink = row_ink + 1
          ink = ink + 1
          if first < 0 {
            first = x
          }
        }
      }
      if row_ink > 0 {
        rows = rows + 1
      }
    }
    (first, rows, ink)
  }
  let long_text = "一行中文文本用来比较左右位置与折行行数"
  // 1) text_align：同一盒宽下，居中的首墨列比左对齐靠右（文本明显窄于盒）
  let box_of = fn(t : @core.Node) -> @core.Node {
    view([t], width=220.0, height=24.0)
  }
  let (start_col, _sr, _si) = ink_scan(
    box_of(text("短文本", class=[@style.style(text_align=@text.Start)])),
    240.0,
    30.0,
  )
  let (center_col, _cr, _ci) = ink_scan(
    box_of(text("短文本", class=[@style.style(text_align=@text.Center)])),
    240.0,
    30.0,
  )
  assert_true(center_col > start_col + 20)

  // 2) white_space：可折行的有墨行数明显多于不折行
  let (_wx, wrap_rows, _wi) = ink_scan(
    text(long_text, max_width=80.0, class=[@style.style(white_space=@style.WhiteSpace::Normal)]),
    120.0,
    120.0,
  )
  let (_nx, nowrap_rows, _ni) = ink_scan(
    text(long_text, max_width=80.0, class=[@style.style(white_space=@style.WhiteSpace::NoWrap)]),
    120.0,
    120.0,
  )
  assert_true(wrap_rows > nowrap_rows)

  // 3) line_height 单行档：测量高就是行高
  let lh = mount_root(
    [text("行高", class=[@style.style(line_height=40.0)])],
    120.0,
    60.0,
  )
  assert_eq(kid(lh, 0).rect.h, 40.0)

  // 4) text_decoration：下划线要额外多出一份墨（比墨量不比行数——线落进最后一行
  //    的行距时行数是平的，而各后端的行盒高度本来就不一致）
  let (_pu, _pr, plain_ink) = ink_scan(text("下划线", class=[]), 120.0, 40.0)
  let (_uu, _ur, under_ink) = ink_scan(
    text("下划线", class=[@style.style(text_decoration=@style.TextDecoration::Underline)]),
    120.0,
    40.0,
  )
  let probe = match @text.measure_font("下划线", @text.Font::new("", 13.0),
    wrap=false
  ) {
    Some(m) => "w=\{m.width} h=\{m.height} baseline=\{m.baseline}"
    None => "None"
  }
  assert_true(
    under_ink > plain_ink,
    msg="下划线没多出墨：plain=\{plain_ink} under=\{under_ink} 行=\{_pr}/\{_ur} measure_font(13.0)=\{probe}",
  )

}

///|
///|
/// 回归：`size` 是盒子边长，字形须落在盒子内并居中。
/// 曾经的口径错是把盒子边长当内容半径传给 `draw_icon`，字形画到盒子短边的
/// 176%，被控件裁剪后四边各切掉一大块（见 adaptation 的图标尺寸条）。
test "图标字形随盒子缩放、不溢出、居中" {
  let ink_box = fn(bm : @render.Bitmap, x0 : Int, y0 : Int, x1 : Int, y1 : Int) -> (
    Int,
    Int,
    Int,
    Int,
  ) {
    let mut min_x = 1 << 30
    let mut min_y = 1 << 30
    let mut max_x = -1
    let mut max_y = -1
    for y = y0; y <= y1; y = y + 1 {
      for x = x0; x <= x1; x = x + 1 {
        let c = color_of(bm, x, y)
        if c.0 > 128 && c.1 < 64 && c.2 < 64 {
          if x < min_x { min_x = x }
          if x > max_x { max_x = x }
          if y < min_y { min_y = y }
          if y > max_y { max_y = y }
        }
      }
    }
    (min_x, min_y, max_x, max_y)
  }
  let paint = fn(nodes : Array[@core.Node], w : Int, h : Int) -> @render.Bitmap {
    let root = mount_root(nodes, w.to_double(), h.to_double())
    let bm = @render.Bitmap::new(w, h)
    let p = @render.Painter::new(bm)
    root.paint(p)
    p.end()
    bm
  }

  // @ui.icon：24 的盒子，字形须短边内缩且居中在 (12,12)
  let bm1 = paint([icon(@icons.IconKind::MediumCircleFill, size=24.0, color="#ff0000")], 48, 48)
  let a = ink_box(bm1, 0, 0, 47, 47)
  assert_true(a.0 >= 1 && a.1 >= 1)
  assert_true(a.2 <= 22 && a.3 <= 22)
  assert_true(a.2 - a.0 >= 16 && a.2 - a.0 <= 22)
  assert_eq((a.0 + a.2) / 2, (a.1 + a.3) / 2)
  assert_eq((a.0 + a.2) / 2, 11)

  // icon_button：28 的按钮盒 + 16 的字形盒，字形居中在按钮中心 (14,14)
  let bm2 = paint(
    [
      icon_button(
        @icons.IconKind::MediumCircleFill,
        color="#ff0000",
        icon_size=16.0,
        box_size=28.0,
      ),
    ],
    48,
    48,
  )
  let b = ink_box(bm2, 0, 0, 47, 47)
  assert_true(b.0 >= 5 && b.1 >= 5 && b.2 <= 22 && b.3 <= 22)
  assert_true(b.2 - b.0 >= 10 && b.2 - b.0 <= 17)
  assert_eq((b.0 + b.2) / 2, (b.1 + b.3) / 2)
}
