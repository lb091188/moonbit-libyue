// 显示族回归：语义色档位、按内容定宽、可关闭热区、卡片与描述列表的行数、
// 进度条填充随 Store 变化。绘制断言只比「有没有像素 / 两侧是否不同」，
// 不锁具体色值（换主题换字体都不该假红）。

///|
fn px(bm : @render.Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = bm.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

///|
fn ink_count(bm : @render.Bitmap, x1 : Int, y1 : Int) -> Int {
  let mut n = 0
  for y = 0; y < y1; y = y + 1 {
    for x = 0; x < x1; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        n = n + 1
      }
    }
  }
  n
}

///|
fn mounted(node : @core.Node, w : Double, h : Double) -> (@core.Widget, @core.Widget) {
  let root = @core.Widget::new()
  root.set_size(w, h)
  root.set_column()
  root.node.set_align_items(@yoga.AlignItems::FlexStart)
  let kid = node.mount_into(root)
  root.relayout(w, h)
  (root, kid)
}

///|
test "语义色五档互不相同且都是合法 hex" {
  let kinds : Array[SemanticType] = [Primary, Success, Warning, Danger, Info]
  let seen : Array[String] = []
  for t in kinds {
    let c = type_color(t)
    let l = type_light_color(t)
    assert_true(@render.Color::parse(c) is Some(_) )
    assert_true(@render.Color::parse(l) is Some(_) )
    assert_true(c != l)
    for s in seen {
      assert_true(s != c)
    }
    seen.push(c)
  }
  assert_eq(seen.length(), 5)
}

///|
test "标签与徽标按内容定宽，超上限显示 99+" {
  if !ui_text_guard() {
    return
  }
  let (_, short_tag) = mounted(tag_of_type("新", Primary), 200.0, 60.0)
  let (_, long_tag) = mounted(tag_of_type("很长的一段标签文字", Primary), 300.0, 60.0)
  assert_eq(short_tag.rect.h, 24.0)
  assert_true(long_tag.rect.w > short_tag.rect.w + 40.0)
  let (_, five) = mounted(badge_count(5), 100.0, 40.0)
  let (_, many) = mounted(badge_count(150), 100.0, 40.0)
  // 「150」显示成「99+」，比单个「5」宽
  assert_true(many.rect.w > five.rect.w)
  let (_, dot) = mounted(badge_dot(), 40.0, 40.0)
  assert_eq((dot.rect.w, dot.rect.h), (8.0, 8.0))
}

///|
test "头像取首字符、统计块按内容定宽" {
  if !ui_text_guard() {
    return
  }
  let (_, av) = mounted(avatar("刘斌"), 60.0, 60.0)
  assert_eq((av.rect.w, av.rect.h), (32.0, 32.0))
  let bm = @render.Bitmap::new(60, 60)
  let p = @render.Painter::new(bm)
  av.paint(p)
  p.end()
  assert_true(ink_count(bm, 60, 60) > 20)

  let (_, st) = mounted(statistic("访问量", "1,234"), 200.0, 80.0)
  assert_eq(st.rect.h, 56.0)
  assert_true(st.rect.w > 40.0)
}

///|
test "带文字分隔线：整宽、文字两侧都有线" {
  let root = @core.Widget::new()
  root.set_size(200.0, 60.0)
  root.set_column()
  let d = divider(text="或").mount_into(root)
  root.relayout(200.0, 60.0)
  assert_eq((d.rect.w, d.rect.h), (200.0, 20.0))
  let bm = @render.Bitmap::new(200, 40)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  // 中线左右各有一段实线
  assert_true(ink_count(bm, 40, 20) > 10)
  assert_true(ink_count(bm, 200, 20) > ink_count(bm, 40, 20))
}

///|
test "提示条：有描述时更高，关闭热区只在右上角" {
  let closes = Ref(0)
  let (root1, a1) = mounted(
    alert("标题", description="描述在这里", t=Warning, closable=true, on_close=fn() { closes.val = closes.val + 1 }),
    300.0,
    80.0,
  )
  assert_eq(a1.rect.h, 56.0)
  let _ = root1.dispatch_pointer({
    kind: @core.Down,
    x: a1.rect.x + 20.0,
    y: a1.rect.y + 10.0,
    button: 1,
    mods: 0,
  })
  let _ = root1.dispatch_pointer({
    kind: @core.Up,
    x: a1.rect.x + 20.0,
    y: a1.rect.y + 10.0,
    button: 1,
    mods: 0,
  })
  assert_eq(closes.val, 0)
  let _ = root1.dispatch_pointer({
    kind: @core.Down,
    x: a1.rect.x + a1.rect.w - 8.0,
    y: a1.rect.y + 8.0,
    button: 1,
    mods: 0,
  })
  let _ = root1.dispatch_pointer({
    kind: @core.Up,
    x: a1.rect.x + a1.rect.w - 8.0,
    y: a1.rect.y + 8.0,
    button: 1,
    mods: 0,
  })
  assert_eq(closes.val, 1)

  let (_, a2) = mounted(alert("只有标题"), 300.0, 80.0)
  assert_eq(a2.rect.h, 36.0)
}

///|
test "卡片与描述列表：标题会多占一行，条目数按传入算" {
  let body = [text("内容一"), text("内容二")]
  let (_, plain) = mounted(card(body, title=""), 240.0, 200.0)
  assert_eq(plain.children().length(), 2)
  let (_, titled) = mounted(card(body, title="标题"), 240.0, 200.0)
  // 标题 + 分隔线 + 两条内容
  assert_eq(titled.children().length(), 4)
  let (_, desc) = mounted(
    descriptions([("姓名", "刘斌"), ("城市", "杭州")], title="信息"),
    240.0,
    200.0,
  )
  // 标题行 + 两条
  assert_eq(desc.children().length(), 3)
}

///|
test "空状态与结果页都真画出像素" {
  let (root, _e) = mounted(empty(), 240.0, 160.0)
  let bm = @render.Bitmap::new(240, 160)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  assert_true(ink_count(bm, 240, 160) > 30)
  let (_, r) = mounted(result("操作完成", subtitle="已保存 3 条记录", t=Success), 240.0, 200.0)
  assert_true(r.rect.h > 60.0)
}

///|
test "折线进度：条与百分比两列，填充随 Store 变化" {
  let v = @core.Store::new(0.25)
  let root = @core.Widget::new()
  root.set_size(260.0, 60.0)
  root.set_column()
  let row = progress_line(v, max=1.0, width=240.0).mount_into(root)
  root.relayout(260.0, 60.0)
  assert_eq(row.children().length(), 2)
  let bar = row.children()[0]
  let bm = @render.Bitmap::new(260, 60)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  // 条宽 = 240 - 44 = 196：x=10 在填充段内，x=100 在 25% 之外
  let left = px(bm, 10, 4)
  let mid = px(bm, 100, 4)
  assert_true(left != mid)
  v.set(1.0)
  let bm2 = @render.Bitmap::new(260, 60)
  let p2 = @render.Painter::new(bm2)
  root.paint(p2)
  p2.end()
  assert_true(px(bm2, 100, 4) != mid)
  assert_eq(bar.rect.h, 8.0)
}

///|
fn click_at(root : @core.Widget, w : @core.Widget, fx : Double, fy : Double) -> Unit {
  let x = w.rect.x + fx
  let y = w.rect.y + fy
  let _ = root.dispatch_pointer({ kind: @core.Down, x, y, button: 1, mods: 0 })
  let _ = root.dispatch_pointer({ kind: @core.Up, x, y, button: 1, mods: 0 })
}

///|
test "时间线：逐行等高、首末行的贯通线只到点心" {
  let items : Array[(String, String, SemanticType)] = [
    ("创建", "2026-01-01 建档", Primary),
    ("构建", "编译通过", Success),
    ("发布", "已上线", Danger),
  ]
  let (root, tl) = mounted(timeline(items), 240.0, 220.0)
  let rows = tl.children()
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].children().length(), 2)
  assert_eq(rows[0].rect.h, 56.0)
  // 行间距 12：第二行落在 68，第三行落在 136
  assert_eq((rows[1].rect.y, rows[2].rect.y), (68.0, 136.0))

  let bm = @render.Bitmap::new(240, 220)
  let p = @render.Painter::new(bm)
  root.paint(p)
  p.end()
  // 首行（0..56，点在 23..33）：点上方无线、点下方有线
  assert_eq(bm.pixel(10, 10).a, 0)
  assert_true(bm.pixel(10, 40).a > 0)
  // 末行（136..192，点心 164）：点上方有线、点下方无线
  assert_true(bm.pixel(10, 150).a > 0)
  assert_eq(bm.pixel(10, 180).a, 0)
  // 点与线不同色（点是语义主色，线是边框色）
  assert_true(px(bm, 10, 164) != px(bm, 10, 150))
}

///|
test "轮播：面板预建只显示当前页，箭头与指示点切页、越界回绕" {
  let h = CarouselHandle::make()
  let pages : Array[@core.Node] = [
    text("第一页", size=14.0),
    text("第二页", size=14.0),
    text("第三页", size=14.0),
  ]
  let (root, c) = mounted(
    carousel(pages, width=200.0, height=80.0, interval_ms=0, rotation=h),
    260.0,
    160.0,
  )
  let stage_row = c.children()[0]
  let stage = stage_row.children()[1]
  let panels = stage.children()
  assert_eq(panels.length(), 3)
  assert_eq([panels[0].visible, panels[1].visible, panels[2].visible], [true, false, false])
  assert_eq(stage.rect.h, 80.0)
  // 舞台 = 左箭头 + 面板区 + 右箭头，两侧各 24px 热区
  click_at(root, stage_row.children()[2], 12.0, 40.0)
  assert_eq(h.index(), 1)
  assert_eq([panels[0].visible, panels[1].visible], [false, true])
  click_at(root, stage_row.children()[0], 12.0, 40.0)
  assert_eq(h.index(), 0)

  let dots_row = c.children()[1]
  assert_eq(dots_row.children().length(), 3)
  click_at(root, dots_row.children()[2], 4.0, 4.0)
  assert_eq(h.index(), 2)

  // 回绕：负数落到末页、超出落到首页
  carousel_goto(h, -1)
  assert_eq(h.index(), 2)
  carousel_goto(h, 9)
  assert_eq(h.index(), 0)
}

///|
test "轮播自转走宿主延时通道：暂停不前进、stop 断链并取消待触发" {
  let queue : Ref[Array[() -> Unit]] = Ref([])
  let delays : Ref[Array[Int]] = Ref([])
  let cancelled : Ref[Array[Int]] = Ref([])
  @core.set_timer_hooks(
    fn(ms : Int, f : () -> Unit) -> Int {
      delays.val.push(ms)
      queue.val.push(f)
      delays.val.length()
    },
    fn(id : Int) -> Unit { cancelled.val.push(id) },
  )
  let h = CarouselHandle::make()
  let _ = carousel(
    [text("一"), text("二"), text("三")],
    width=120.0,
    height=60.0,
    interval_ms=100,
    rotation=h,
  ).mount_into(@core.Widget::new())
  assert_eq(delays.val.length(), 1)
  assert_eq(delays.val[0], 100)

  let fire = fn() -> Unit {
    let q = queue.val
    let f = q[q.length() - 1]
    q.truncate(q.length() - 1)
    f()
  }

  fire()
  assert_eq(h.index(), 1)
  assert_eq(delays.val.length(), 2)
  carousel_pause(h, true)
  fire()
  // 暂停只压住切页，不压住下一拍
  assert_eq(h.index(), 1)
  assert_eq(delays.val.length(), 3)
  carousel_pause(h, false)
  fire()
  assert_eq(h.index(), 2)
  carousel_stop(h)
  assert_eq(h.is_running(), false)
  assert_eq(cancelled.val.length(), 1)
  // 已经在队里的这一拍仍会被跑一次，但既不切页也不再排下一拍
  fire()
  assert_eq(h.index(), 2)
  assert_eq(delays.val.length(), 4)
  // 恢复成「无宿主」通道，别影响同包其余用例
  @core.set_timer_hooks(fn(_ms, _f) { 0 }, fn(_id) { () })
}

///|
test "空条目：时间线零行、空轮播不出面板也不排自转" {
  let (_, tl) = mounted(timeline([]), 200.0, 60.0)
  assert_eq(tl.children().length(), 0)
  let h = CarouselHandle::make()
  let (_, c) = mounted(carousel([], width=100.0, height=40.0, rotation=h), 200.0, 80.0)
  assert_eq(c.children().length(), 0)
  carousel_goto(h, 1)
  assert_eq(h.index(), 0)
  carousel_stop(h)
  assert_eq(h.is_running(), false)
}

///|
test "展示族 *_dyn：值变就地改字、按内容重算宽度" {
  if !ui_text_guard() {
    return
  }
  // 徽标：5 → 150（显示成「99+」），宽度跟着长
  let unread = @core.Store::new(5)
  let (root_b, bd) = mounted(badge_count_dyn(unread.signal(), max=99), 120.0, 40.0)
  let w_small = bd.rect.w
  unread.set(150)
  root_b.relayout(120.0, 40.0)
  assert_true(bd.rect.w > w_small)
  // 标签：文本变长就变宽（tag / tag_of_type 两条入口共用内核）
  let label = @core.Signal::new("新")
  let (root_t, tg) = mounted(tag_dyn(label, "#337ecc"), 200.0, 60.0)
  let w_short = tg.rect.w
  label.set("很长的一段标签文字")
  root_t.relayout(200.0, 60.0)
  assert_true(tg.rect.w > w_short + 40.0)
  let (root_t2, tg2) = mounted(tag_of_type_dyn(label, Success), 200.0, 60.0)
  let w_t2 = tg2.rect.w
  label.set("更长的一段标签文字啊")
  root_t2.relayout(200.0, 60.0)
  assert_true(tg2.rect.w > w_t2)
  // 统计块：数值行走信号，标题与前缀建树时定死
  let hits = @core.Store::new("1,234")
  let (root_s, st) = mounted(statistic_dyn("访问量", hits.signal()), 240.0, 80.0)
  let w_num = st.rect.w
  hits.set("12,345,678")
  root_s.relayout(240.0, 80.0)
  assert_true(st.rect.w > w_num)
  assert_eq(st.rect.h, 56.0)
  // 头像：尺寸不随文本变，换名后仍画得出像素
  let name = @core.Signal::new("刘斌")
  let (root_a, av) = mounted(avatar_dyn(name), 60.0, 60.0)
  assert_eq((av.rect.w, av.rect.h), (32.0, 32.0))
  name.set("李雷")
  root_a.relayout(60.0, 60.0)
  let bm = @render.Bitmap::new(60, 60)
  let p = @render.Painter::new(bm)
  av.paint(p)
  p.end()
  assert_true(ink_count(bm, 60, 60) > 20)
}
