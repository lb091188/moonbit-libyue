// 图表层回归：纯函数（窗口/换算/刻度/扇区/命中/截断）+ 五种组件（挂载几何、
// 出像素、悬停高亮、仪表盘插值）。绘制像素用 `paint_at` 抵消绝对落位后取样。

///|
fn bm_of(w : @core.Widget) -> @render.Bitmap {
  let bm = @render.Bitmap::new(w.rect.w.round().to_int() + 2, w.rect.h.round().to_int() + 2)
  let p = @render.Painter::new(bm)
  w.paint_at(p, w.rect.x, w.rect.y)
  p.end()
  bm
}

///|
/// 两张位图的不同像素数（组件会先铺一层面板底，所以「有墨」不能只看 alpha，
/// 一切换就得比差异）。
fn diff_of(a : @render.Bitmap, b : @render.Bitmap) -> Int {
  let mut n = 0
  let h = a.height.min(b.height)
  let w = a.width.min(b.width)
  for y = 0; y < h; y = y + 1 {
    for x = 0; x < w; x = x + 1 {
      let pa = a.pixel(x, y)
      let pb = b.pixel(x, y)
      if pa.r != pb.r || pa.g != pb.g || pa.b != pb.b || pa.a != pb.a {
        n = n + 1
      }
    }
  }
  n
}

///|
/// 与「全空位图」的差异数（等价于有墨像素数）。
fn ink_of(bm : @render.Bitmap) -> Int {
  diff_of(bm, @render.Bitmap::new(bm.width, bm.height))
}

///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
/// 挂进根控件并跑一轮布局（交叉轴不拉伸，组件自己算出的宽才是看得见的真值）。
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
test "滚动窗口：定长丢最旧、越界索引无操作、Store 推点整表换一次" {
  let w0 : Array[Double] = []
  let w1 = win_push(w0, 3, 1.0)
  let w2 = win_push(w1, 3, 2.0)
  let w3 = win_push(w2, 3, 3.0)
  let w4 = win_push(w3, 3, 4.0)
  assert_eq(w4, [2.0, 3.0, 4.0])
  // 入参窗口不变
  assert_eq(w3, [1.0, 2.0, 3.0])
  assert_eq(win_push([], 0, 5.0), [5.0])
  let s = @core.Store::new([LineSeries::make("a", max_points=2)])
  series_push(s, 0, 1.0)
  series_push(s, 0, 2.0)
  series_push(s, 0, 3.0)
  assert_eq(s.get()[0].points, [2.0, 3.0])
  // 越界：整表不变
  series_push(s, 5, 9.0)
  assert_eq(s.get().length(), 1)
}

///|
test "坐标换算与值域：退化不炸、单点居中、留白比例正确" {
  let empty = auto_y_range([])
  assert_eq(empty, (0.0, 1.0))
  let one = auto_y_range([LineSeries::make("a", max_points=50).with_points([5.0])])
  assert_eq(one, (4.0, 6.0))
  let two = auto_y_range([LineSeries::make("a").with_points([0.0, 100.0])])
  assert_true(close(two.0, -8.0) && close(two.1, 108.0))
  // map_y：值域退化取中点，否则线性（顶=lo 的反向）
  assert_eq(map_y(3.0, 3.0, 3.0, 10.0, 90.0), 50.0)
  assert_true(close(map_y(0.0, 0.0, 10.0, 0.0, 100.0), 100.0))
  assert_true(close(map_y(10.0, 0.0, 10.0, 0.0, 100.0), 0.0))
  assert_true(close(map_xv(5.0, 0.0, 10.0, 20.0, 120.0), 70.0))
  assert_eq(map_xv(5.0, 5.0, 5.0, 0.0, 100.0), 50.0)
  assert_eq(map_idx(0, 1, 10.0, 90.0), 50.0)
  assert_true(close(map_idx(1, 3, 10.0, 90.0), 50.0))
  assert_true(close(map_idx(2, 3, 10.0, 90.0), 90.0))
}

///|
test "刻度与轴标签：1/2/5 步长、负值起点、单位换挡" {
  // raw 步长 2.5 → 归整到 2 → 刻度 0/2/4/6/8/10
  assert_eq(nice_ticks(0.0, 10.0, count=4), [0.0, 2.0, 4.0, 6.0, 8.0, 10.0])
  assert_eq(nice_step(2.3), 2.0)
  assert_eq(nice_step(0.036), 0.05)
  assert_eq(nice_step(-1.0), 1.0)
  assert_eq(nice_ticks(10.0, 0.0), [])
  assert_eq(nice_ticks(0.0, 10.0, count=0), [])
  // 负值区间：首个刻度 <= lo
  // raw 步长 3.5 → 归整 5：首个刻度是 >= lo 的最小倍数
  let neg = nice_ticks(-7.0, 7.0, count=4)
  assert_eq(neg, [-5.0, 0.0, 5.0])
  assert_eq(fmt_axis(0.0), "0")
  assert_eq(fmt_axis(12.345), "12.35")
  assert_eq(fmt_axis(-12.34), "-12.34")
  assert_eq(fmt_axis(15000.0), "15k")
  assert_eq(fmt_axis(2400000.0), "2.4M")
  assert_eq(fmt_axis(3200000000.0), "3.2G")
  assert_eq(fmt_axis(-15000.0), "-15k")
}

///|
test "柱状几何：值域含零、槽宽下限、命中与绘制同源" {
  assert_eq(bar_range([]), (0.0, 1.0))
  assert_eq(bar_range([0.0, 0.0]), (-1.0, 1.0))
  let (lo, hi) = bar_range([10.0, 20.0])
  assert_true(lo <= 0.0 && hi > 20.0)
  let (x, w) = bar_slot(1, 4, 0.0, 100.0, gap=5.0)
  assert_true(close(w, 20.0))
  assert_true(close(x, 27.5))
  assert_eq(bar_slot(0, 0, 10.0, 90.0), (10.0, 80.0))
  // 纵向：只看 x 分槽；界外 -1
  assert_eq(bar_hit(false, 4, 200.0, 120.0, 60.0, 60.0), 0)
  assert_eq(bar_hit(false, 4, 200.0, 120.0, 40.0, 60.0), -1)
  assert_eq(bar_hit(false, 4, 200.0, 120.0, 190.0, 60.0), -1)
  // 横向：只看 y 分行
  assert_eq(bar_hit(true, 3, 200.0, 120.0, 100.0, 20.0), 0)
  assert_eq(bar_hit(true, 3, 200.0, 120.0, 100.0, 110.0), -1)
}

///|
test "扇区与仪表：只累计正值、单扇区不满圆、阈值分段取色" {
  assert_eq(sector_angles([0.0, 0.0], 0), None)
  assert_eq(sector_angles([1.0], 3), None)
  let s0 = sector_angles([1.0, 1.0], 0)
  match s0 {
    Some((a0, a1)) => {
      assert_true(close(a0, -pi / 2.0))
      assert_true(close(a1 - a0, pi))
    }
    None => assert_true(false)
  }
  // 只有一个正值时它占满一圈，但要留出 0.0002 弧度避免自交
  let solo = sector_angles([0.0, 5.0], 1)
  match solo {
    Some((a0, a1)) => assert_true(a1 - a0 < tau && a1 - a0 > tau - 0.001)
    None => assert_true(false)
  }
  assert_true(close(gauge_angle(0.0), 0.75 * pi))
  assert_true(close(gauge_angle(1.0), 0.75 * pi + 1.5 * pi))
  assert_true(close(gauge_angle(2.0), gauge_angle(1.0)))
  assert_true(close(gauge_angle(-1.0), gauge_angle(0.0)))
  let bands : Array[(Double, String)] = [(0.6, "#aaaaaa"), (0.85, "#bbbbbb")]
  assert_eq(band_color(0.2, bands), "#aaaaaa")
  assert_eq(band_color(0.7, bands), "#bbbbbb")
  assert_eq(band_color(0.99, bands), "#bbbbbb")
  assert_eq(band_color(0.5, []), @theme.theme_primary())
  // 内弧折线段数：至少 4 段，整圆 32 段
  assert_eq(ring_steps(0.0, 0.1), 4)
  assert_eq(ring_steps(0.0, tau), 32)
}

///|
test "回归与散点值域、8 位色串、类目标签截断" {
  assert_eq(linreg([]), None)
  assert_eq(linreg([(1.0, 2.0)]), None)
  assert_eq(linreg([(1.0, 2.0), (1.0, 5.0)]), None)
  let kb = linreg([(0.0, 1.0), (2.0, 5.0)])
  match kb {
    Some((k, b)) => {
      assert_true(close(k, 2.0))
      assert_true(close(b, 1.0))
    }
    None => assert_true(false)
  }
  assert_eq(point_range([]), ((0.0, 1.0), (0.0, 1.0)))
  let ((xlo, xhi), (ylo, yhi)) = point_range([(5.0, 5.0)])
  assert_eq((xlo, xhi), (4.0, 6.0))
  assert_eq((ylo, yhi), (4.0, 6.0))
  assert_eq(with_alpha("#2D68C4", "26"), "#2D68C426")
  // 已经带 alpha 的串不再追加
  assert_eq(with_alpha("#2D68C426", "26"), "#2D68C426")
  assert_eq(truncate_to("abcd", 100.0), "abcd")
  assert_eq(truncate_to("abcdefghij", 21.0), "ab…")
  assert_eq(truncate_to("abc", 5.0), "")
}

///|
test "折线图：Store 推点后画面变化、空窗只画网格与提示" {
  let s = @core.Store::new([LineSeries::make("a", max_points=50)])
  let (root, w) = mounted(line_chart_t(s, height=120.0), 320.0, 140.0)
  assert_eq((w.rect.w, w.rect.h), (320.0, 120.0))
  let empty = bm_of(w)
  s.set([LineSeries::make("a", max_points=50).with_points([1.0, 4.0, 2.0, 7.0, 5.0])])
  let _ = root.relayout(320.0, 140.0)
  assert_true(diff_of(bm_of(w), empty) > 200)
  // 密集：点数远多于像素列时仍出图（按列矩形，不逐段描边）
  let many : Array[Double] = []
  for i = 0; i < 900; i = i + 1 {
    many.push((i % 37).to_double())
  }
  s.set([LineSeries::make("a").with_points(many)])
  let _ = root.relayout(320.0, 140.0)
  assert_true(diff_of(bm_of(w), empty) > 200)
}

///|
test "柱状图：悬停那根换浅底并标数值，离开后复原" {
  let data = @core.Store::new([
    BarItem::make("甲", 30.0),
    BarItem::make("乙", -12.0),
    BarItem::make("丙", 48.0),
  ])
  let (root, w) = mounted(bar_chart_t(data, width=300.0, height=160.0), 340.0, 180.0)
  let plain = bm_of(w)
  let px = 46.0 + (300.0 - 46.0 - 12.0) / 3.0 * 0.5 + 6.0
  let _ = root.dispatch_pointer({
    kind: @core.Move,
    x: w.rect.x + px,
    y: w.rect.y + 80.0,
    button: 0,
    mods: 0,
  })
  let lit = bm_of(w)
  assert_true(diff_of(lit, plain) > 100)
  let _ = root.dispatch_pointer({
    kind: @core.Leave,
    x: w.rect.x + px,
    y: w.rect.y + 80.0,
    button: 0,
    mods: 0,
  })
  assert_eq(diff_of(bm_of(w), plain), 0)
}

///|
test "环形图：扇区与图例出像素、donut_hit 指到扇区与中心孔" {
  let data = @core.Store::new([
    DonutSlice::make("甲", 40.0),
    DonutSlice::make("乙", 35.0),
    DonutSlice::make("丙", 25.0),
  ])
  let (_root, w) = mounted(donut_chart_t(data, width=420.0, height=180.0), 460.0, 200.0)
  assert_true(ink_of(bm_of(w)) > 2000)
  // 圆心在 (8+d/2, h/2)，d=h-16=164 → cx=90、cy=90；12 点方向第一扇区
  assert_eq(donut_hit(180.0, [DonutSlice::make("甲", 1.0)], 90.0, 20.0), 0)
  // 中心孔里不算命中
  assert_eq(donut_hit(180.0, [DonutSlice::make("甲", 1.0)], 90.0, 90.0), -1)
  // 圆外不算
  assert_eq(donut_hit(180.0, [DonutSlice::make("甲", 1.0)], 300.0, 90.0), -1)
  // 第三扇区（25%，落在左上）
  assert_eq(donut_hit(180.0, data.get(), 45.0, 45.0), 2)
}

///|
test "仪表盘：值弧随 Store 平滑逼近目标，smooth=false 直接跳到位" {
  let v = @core.Store::new(0.0)
  let (_root, w) = mounted(
    gauge_t(v, width=220.0, height=180.0, smooth=false),
    260.0,
    200.0,
  )
  let zero = bm_of(w)
  v.set(0.72)
  assert_true(diff_of(bm_of(w), zero) > 100)
  // 平滑版：排了延时链，逐拍逼近（跑几拍后应已接近目标）
  let fired : Ref[Array[() -> Unit]] = Ref([])
  @core.set_timer_hooks(
    fn(_ms : Int, f : () -> Unit) -> Int {
      fired.val.push(f)
      fired.val.length()
    },
    fn(_id : Int) -> Unit { () },
  )
  let v2 = @core.Store::new(0.0)
  let (_r2, w2) = mounted(gauge_t(v2, width=220.0, height=180.0), 260.0, 200.0)
  let before = bm_of(w2)
  v2.set(0.8)
  let mut n = 0
  while n < 3 && n < fired.val.length() {
    let q = fired.val
    q[n]()
    n = n + 1
  }
  assert_true(diff_of(bm_of(w2), before) > 100)
  @core.set_timer_hooks(fn(_ms, _f) { 0 }, fn(_id) { () })
}

///|
test "散点图：点列与趋势线出像素、空数据只画网格与提示" {
  let pts = @core.Store::new([])
  let (root, w) = mounted(
    scatter_t(pts, trend=true, width=320.0, height=180.0),
    360.0,
    200.0,
  )
  let empty = bm_of(w)
  pts.set([(1.0, 2.0), (2.0, 3.5), (3.0, 4.2), (4.0, 6.1), (5.0, 5.4)])
  let _ = root.relayout(360.0, 200.0)
  assert_true(diff_of(bm_of(w), empty) > 100)
}
