// 图表组件白盒测试：纯函数（滚动窗口/坐标换算/刻度/扇区/回归）语义 +
// 重绘耗时基准（release 计时，数值记入 docs/zh/adaptation.md；debug 模式
// 数值偏大，记档以 `moon test --release` 为准）。
// 基准分两级：
//   1) 纯函数管线 + 离屏 Canvas 几何调用镜像（无显示环境可跑，CI 绿）——
//      几何调用（fill/stroke/arc/clip）与 draw_* 每帧调用序一致，仅文本
//      路径（DrawText/AttributedText）离屏需要 initialize + 显示环境；
//   2) 有 DISPLAY 时先 initialize 再跑真实 draw_* 全帧（含文本标注），
//      拿到的即 on_draw 回调真实耗时。
// 长跑内存：推点窗口长度恒定（有界），10 分钟 @2Hz × 4 序列推点计时 +
// 窗口长度断言。

///|
#external
type Timestamp

///|
extern "C" fn mono_start() -> Timestamp = "moonbit_monotonic_clock_start"

///|
extern "C" fn mono_end(ts : Timestamp) -> Double = "moonbit_monotonic_clock_stop"

///|
test "win_push 滚动窗口：容量/丢最旧/退化" {
  // 未满：原样追加
  debug_inspect(win_push([1.0, 2.0], 5, 3.0), content="[1, 2, 3]")
  // 满：丢最旧
  debug_inspect(win_push([1.0, 2.0, 3.0], 3, 4.0), content="[2, 3, 4]")
  // 空窗
  debug_inspect(win_push([], 3, 7.0), content="[7]")
  // max_points <= 0：只保留最新一点
  debug_inspect(win_push([1.0, 2.0], 0, 9.0), content="[9]")
  // 入参不被修改
  let w = [1.0, 2.0, 3.0]
  ignore(win_push(w, 3, 4.0))
  debug_inspect(w, content="[1, 2, 3]")
}

///|
test "series_push：按索引推点 + 越界无操作 + 订阅通知" {
  let series : Store[Array[LineSeries]] = Store::new([
    LineSeries::make("a", max_points=2),
    LineSeries::make("b", max_points=3),
  ])
  let hits = Ref(0)
  series.subscribe(fn(_s) { hits.val = hits.val + 1 })
  series_push(series, 0, 1.0)
  series_push(series, 0, 2.0)
  series_push(series, 0, 3.0) // 超容，丢最旧
  series_push(series, 1, 9.0)
  series_push(series, 5, 0.0) // 越界无操作
  series_push(series, -1, 0.0) // 越界无操作
  let cur = series.get()
  debug_inspect(cur[0].points, content="[2, 3]")
  debug_inspect(cur[1].points, content="[9]")
  assert_eq(hits.val, 4)
}

///|
test "auto_y_range：空窗/等值退化/留白/负值" {
  // 空窗
  assert_eq(auto_y_range([]), (0.0, 1.0))
  // 正常：8% 留白
  let (lo, hi) = auto_y_range([
    { name: "s", max_points: 10, points: [10.0, 20.0], },
  ])
  assert_true((lo - 9.2).abs() < 1.0e-9)
  assert_true((hi - 20.8).abs() < 1.0e-9)
  // 等值退化：|值|<10 时 ±1
  let (lo2, hi2) = auto_y_range([
    { name: "s", max_points: 10, points: [5.0, 5.0], },
  ])
  assert_eq(lo2, 4.0)
  assert_eq(hi2, 6.0)
  // 跨负值：12 跨度 8% 留白
  let (lo3, hi3) = auto_y_range([
    { name: "s", max_points: 10, points: [-4.0, 8.0], },
  ])
  assert_true((lo3 - -4.96).abs() < 1.0e-9)
  assert_true((hi3 - 8.96).abs() < 1.0e-9)
}

///|
test "坐标换算：端点/中点/退化值域" {
  assert_eq(map_y(0.0, 0.0, 10.0, 0.0, 100.0), 100.0)
  assert_eq(map_y(10.0, 0.0, 10.0, 0.0, 100.0), 0.0)
  assert_eq(map_y(5.0, 0.0, 10.0, 0.0, 100.0), 50.0)
  assert_eq(map_y(3.0, 3.0, 3.0, 10.0, 90.0), 50.0) // 退化取中点
  assert_eq(map_xv(0.0, 0.0, 10.0, 46.0, 500.0), 46.0)
  assert_eq(map_xv(10.0, 0.0, 10.0, 46.0, 500.0), 500.0)
  assert_eq(map_xv(5.0, 0.0, 10.0, 46.0, 500.0), 273.0)
  assert_eq(map_idx(0, 2, 0.0, 100.0), 0.0)
  assert_eq(map_idx(1, 2, 0.0, 100.0), 100.0)
  assert_eq(map_idx(0, 1, 0.0, 100.0), 50.0) // 单点居中
  assert_eq(map_idx(2, 5, 0.0, 100.0), 50.0)
}

///|
test "nice_ticks：整齐值/边界/退化" {
  debug_inspect(
    nice_ticks(0.0, 100.0, count=4),
    content="[0, 20, 40, 60, 80, 100]",
  )
  debug_inspect(
    nice_ticks(0.0, 1.0, count=4),
    content="[0, 0.2, 0.4, 0.6000000000000001, 0.8, 1]",
  )
  // 非对齐下界：首个刻度 >= lo，末个 <= hi
  let t = nice_ticks(3.0, 97.0, count=4)
  assert_true(t.length() >= 4)
  assert_true(t[0] >= 3.0)
  assert_true(t[t.length() - 1] <= 97.0)
  // 负区间
  let neg = nice_ticks(-50.0, 50.0, count=4)
  assert_true(neg[0] >= -50.0)
  assert_true(neg[neg.length() - 1] <= 50.0)
  assert_true(neg.contains(-20.0))
  // 退化
  assert_eq(nice_ticks(5.0, 5.0, count=4).length(), 0)
  assert_eq(nice_ticks(0.0, 10.0, count=0).length(), 0)
}

///|
test "fmt_axis：整数/小数/负数/尾零" {
  assert_eq(fmt_axis(100.0), "100")
  assert_eq(fmt_axis(0.0), "0")
  assert_eq(fmt_axis(-12.5), "-12.5")
  assert_eq(fmt_axis(3.5), "3.5")
  assert_eq(fmt_axis(2.25), "2.25")
  assert_eq(fmt_axis(0.05), "0.05")
  assert_eq(fmt_axis(-0.5), "-0.5")
  assert_eq(fmt_axis(1000.0), "1000")
}

///|
test "bar_range：含零/正负/退化" {
  let (lo, hi) = bar_range([1.0, 2.0, 3.0])
  assert_true((lo - -0.18).abs() < 1.0e-9)
  assert_true((hi - 3.18).abs() < 1.0e-9)
  let (lo2, hi2) = bar_range([-5.0, 3.0])
  assert_true((lo2 - -5.48).abs() < 1.0e-9)
  assert_true((hi2 - 3.48).abs() < 1.0e-9)
  assert_eq(bar_range([]), (0.0, 1.0))
  assert_eq(bar_range([0.0, 0.0]), (-1.0, 1.0))
}

///|
test "bar_slot：均分/间距/窄条钳制" {
  assert_eq(bar_slot(0, 2, 0.0, 100.0, gap=10.0), (5.0, 40.0))
  assert_eq(bar_slot(1, 2, 0.0, 100.0, gap=10.0), (55.0, 40.0))
  // 200 类目窄条：宽钳到 >=1，且首末不越界
  let (x0, w0) = bar_slot(0, 200, 46.0, 548.0, gap=1.0)
  let (x199, w199) = bar_slot(199, 200, 46.0, 548.0, gap=1.0)
  assert_true(w0 >= 1.0)
  assert_true(w199 >= 1.0)
  assert_true(x0 >= 46.0)
  assert_true(x199 + w199 <= 548.0 + 1.0e-9)
  // n=0 兜底
  let (_xn, wn) = bar_slot(0, 0, 0.0, 100.0)
  assert_true(wn >= 1.0)
}

///|
test "sector_angles：占比/起点/负值忽略/越界" {
  // [1,1,2] 总 4：起手 12 点方向，各占 90°/90°/180°
  let (a0, a1) = match sector_angles([1.0, 1.0, 2.0], 0) {
    Some(p) => p
    None => (0.0, 0.0)
  }
  assert_true((a0 - -pi / 2.0).abs() < 1.0e-12)
  assert_true((a1 - 0.0).abs() < 1.0e-12)
  let (b0, b1) = match sector_angles([1.0, 1.0, 2.0], 2) {
    Some(p) => p
    None => (0.0, 0.0)
  }
  assert_true((b0 - pi / 2.0).abs() < 1.0e-12)
  assert_true((b1 - 1.5 * pi).abs() < 1.0e-12)
  // 负值不计入占比
  let (c0, c1) = match sector_angles([-5.0, 3.0], 1) {
    Some(p) => p
    None => (0.0, 0.0)
  }
  assert_true((c0 - -pi / 2.0).abs() < 1.0e-12)
  assert_true((c1 - (-pi / 2.0 + tau)).abs() < 1.0e-3)
  // 总和 <= 0 / 越界
  assert_true(sector_angles([0.0, -1.0], 0) is None)
  assert_true(sector_angles([1.0], 3) is None)
  // 整圆钳制（不超 2π）
  let (_d0, d1) = match sector_angles([1.0], 0) {
    Some(p) => p
    None => (0.0, 0.0)
  }
  assert_true(d1 - -pi / 2.0 < tau)
}

///|
test "gauge_angle：端点/钳制/半程" {
  assert_true((gauge_angle(0.0) - 0.75 * pi).abs() < 1.0e-12)
  assert_true((gauge_angle(1.0) - 2.25 * pi).abs() < 1.0e-12)
  assert_true((gauge_angle(0.5) - 1.5 * pi).abs() < 1.0e-12)
  assert_true((gauge_angle(-3.0) - 0.75 * pi).abs() < 1.0e-12) // 负钳到 0
  assert_true((gauge_angle(9.0) - 2.25 * pi).abs() < 1.0e-12) // 超 1 钳到 1
  // 自定义起止
  assert_true(
    (gauge_angle(0.5, start=0.0, sweep=pi) - 0.5 * pi).abs() < 1.0e-12,
  )
}

///|
test "linreg：过原点/斜率/退化" {
  // y = x
  let (k, b) = match linreg([(0.0, 0.0), (1.0, 1.0), (2.0, 2.0)]) {
    Some(p) => p
    None => (0.0, 0.0)
  }
  assert_true((k - 1.0).abs() < 1.0e-9)
  assert_true(b.abs() < 1.0e-9)
  // y = 2x + 1
  let (k2, b2) = match linreg([(0.0, 1.0), (1.0, 3.0), (2.0, 5.0)]) {
    Some(p) => p
    None => (0.0, 0.0)
  }
  assert_true((k2 - 2.0).abs() < 1.0e-9)
  assert_true((b2 - 1.0).abs() < 1.0e-9)
  // x 全同：分母为 0
  assert_true(linreg([(5.0, 1.0), (5.0, 2.0)]) is None)
  // 点数不足
  assert_true(linreg([(1.0, 1.0)]) is None)
  assert_true(linreg([]) is None)
}

///|
test "point_range：留白/退化/空" {
  let ((xlo, xhi), (ylo, yhi)) = point_range([(0.0, 0.0), (10.0, 10.0)])
  assert_true((xlo - -0.5).abs() < 1.0e-9)
  assert_true((xhi - 10.5).abs() < 1.0e-9)
  assert_true((ylo - -0.5).abs() < 1.0e-9)
  assert_true((yhi - 10.5).abs() < 1.0e-9)
  // 单轴等值退化
  let ((exlo, exhi), (_eylo, _eyhi)) = point_range([(3.0, 0.0), (3.0, 5.0)])
  assert_true((exlo - 2.0).abs() < 1.0e-9)
  assert_true((exhi - 4.0).abs() < 1.0e-9)
  assert_eq(point_range([]), ((0.0, 1.0), (0.0, 1.0)))
}

///|
test "bar_hit：纵向柱只看横坐标、横向条只看纵坐标（与绘制同源）" {
  // 纵向柱（horizontal=false）：类目沿 x 分槽，命中只随横坐标变
  let w = 320.0
  let h = 240.0
  let n = 8
  let x0 = 46.0
  let slot = (w - 12.0 - x0) / n.to_double()
  for i in 0..<n {
    let cx = x0 + slot * (i.to_double() + 0.5)
    // 同一横坐标、不同纵坐标 → 同一类目（纵向图不看 y）
    assert_eq(bar_hit(false, n, w, h, cx, 20.0), i)
    assert_eq(bar_hit(false, n, w, h, cx, 120.0), i)
    assert_eq(bar_hit(false, n, w, h, cx, 200.0), i)
  }
  // 横向移动跨槽：相邻槽命中相邻类目
  assert_eq(bar_hit(false, n, w, h, x0 + slot * 0.5, 100.0), 0)
  assert_eq(bar_hit(false, n, w, h, x0 + slot * 1.5, 100.0), 1)
  assert_eq(bar_hit(false, n, w, h, x0 + slot * 7.5, 100.0), 7)
  // 界外（左刻度区 / 右边距）→ -1
  assert_eq(bar_hit(false, n, w, h, 10.0, 100.0), -1)
  assert_eq(bar_hit(false, n, w, h, w - 5.0, 100.0), -1)
  // 横向条（horizontal=true）：类目沿 y 排列，命中只随纵坐标变
  let m = 5
  let y0 = 12.0
  let rslot = (h - 24.0 - y0) / m.to_double()
  for i in 0..<m {
    let cy = y0 + rslot * (i.to_double() + 0.5)
    // 同一纵坐标、不同横坐标 → 同一类目（横向图不看 x）
    assert_eq(bar_hit(true, m, w, h, 90.0, cy), i)
    assert_eq(bar_hit(true, m, w, h, 200.0, cy), i)
    assert_eq(bar_hit(true, m, w, h, 300.0, cy), i)
  }
  // 纵向移动跨行
  assert_eq(bar_hit(true, m, w, h, 150.0, y0 + rslot * 0.5), 0)
  assert_eq(bar_hit(true, m, w, h, 150.0, y0 + rslot * 4.5), 4)
  // 界外（上 / 下边距）→ -1
  assert_eq(bar_hit(true, m, w, h, 150.0, 5.0), -1)
  assert_eq(bar_hit(true, m, w, h, 150.0, h - 10.0), -1)
  // 退化
  assert_eq(bar_hit(false, 0, w, h, 100.0, 100.0), -1)
}

///|
test "band_color 阈值分段与 truncate_to" {
  let bands = [(0.6, "#00ff00"), (0.85, "#ffaa00"), (1.0, "#ff0000")]
  assert_eq(band_color(0.5, bands), "#00ff00")
  assert_eq(band_color(0.6, bands), "#00ff00") // 边界归入本段
  assert_eq(band_color(0.7, bands), "#ffaa00")
  assert_eq(band_color(0.99, bands), "#ff0000")
  assert_eq(band_color(0.5, []), theme_primary())
  // 截断
  assert_eq(truncate_to("hello", 100.0), "hello")
  assert_eq(truncate_to("abcdefghij", 21.0), "ab…")
  assert_eq(truncate_to("x", 4.0), "")
}

///|
/// 构造基准数据集（与验收口径同尺寸）。折线取两种形态：steep 锯齿
/// （每点跳 37，对抗性最坏情形）与 smooth 正弦 + 抖动（真实监控数据形态）。
fn bench_data() -> (
  Array[LineSeries],
  Array[LineSeries],
  Array[BarItem],
  Array[DonutSlice],
  Array[(Double, Double)],
) {
  let series : Array[LineSeries] = []
  let smooth : Array[LineSeries] = []
  for s in 0..<4 {
    let points : Array[Double] = []
    let smooth_pts : Array[Double] = []
    for i in 0..<1000 {
      points.push((i * 37 % 101).to_double() + s.to_double())
      smooth_pts.push(
        50.0 +
        s.to_double() * 3.0 +
        30.0 * @math.sin(i.to_double() * 0.05 + s.to_double()) +
        (i * 7 % 5).to_double(),
      )
    }
    series.push({ name: "s\{s}", max_points: 1000, points, })
    smooth.push({ name: "s\{s}", max_points: 1000, points: smooth_pts, })
  }
  let bars : Array[BarItem] = []
  for i in 0..<200 {
    bars.push(BarItem::make("cat\{i}", (i * 13 % 71).to_double() - 20.0))
  }
  let slices : Array[DonutSlice] = []
  for i in 0..<50 {
    slices.push(DonutSlice::make("s\{i}", (i % 7 + 1).to_double()))
  }
  let pts : Array[(Double, Double)] = []
  let mut seed = 12345
  for _ in 0..<10000 {
    seed = (seed * 1103515245 + 12345) % 2147483647
    let x = seed.to_double() / 2147483647.0 * 100.0
    seed = (seed * 1103515245 + 12345) % 2147483647
    let y = seed.to_double() / 2147483647.0 * 100.0
    pts.push((x, y))
  }
  (series, smooth, bars, slices, pts)
}

///|
/// 纯函数管线耗时：每帧 MoonBit 侧 CPU 路径（不含 painter 调用）——
/// 值域、刻度、坐标换算、标签格式、扇区角度、回归，外加长跑推点。
test "图表纯函数管线耗时（release 计时）" {
  let (series, smooth, bars, slices, pts) = bench_data()
  let rounds = 50
  // 折线：值域 + 刻度 + 列抽稀（4×1000 点 → 4×458 列）+ 最新值标签
  fn line_pipe(sers : Array[LineSeries]) -> Unit {
    let (lo, hi) = auto_y_range(sers)
    for t in nice_ticks(lo, hi, count=4) {
      ignore(fmt_axis(t))
    }
    for s in sers {
      let cols = decimate_columns(s.points, lo, hi, 46.0, 504.0, 12.0, 242.0)
      for col in cols {
        ignore(col)
      }
      ignore(area_anchor(lo, hi, 12.0, 242.0))
      ignore(fmt_axis(s.points[s.points.length() - 1]))
    }
  }

  let ts1 = mono_start()
  for _ in 0..<rounds {
    line_pipe(series)
  }
  let line_ms = mono_end(ts1) / rounds.to_double() / 1000.0
  let ts1b = mono_start()
  for _ in 0..<rounds {
    line_pipe(smooth)
  }
  let line_smooth_ms = mono_end(ts1b) / rounds.to_double() / 1000.0
  // 柱状：值域 + 200 槽位 + 标签
  let values : Array[Double] = []
  for it in bars {
    values.push(it.value)
  }
  let ts2 = mono_start()
  for _ in 0..<rounds {
    let (lo, hi) = bar_range(values)
    for t in nice_ticks(lo, hi, count=4) {
      ignore(fmt_axis(t))
    }
    for i in 0..<bars.length() {
      let (bx, bw) = bar_slot(i, bars.length(), 46.0, 548.0, gap=1.25)
      ignore(map_y(bars[i].value, lo, hi, 14.0, 256.0))
      ignore(truncate_to(bars[i].label, bw + 1.25))
      ignore((bx, bw))
    }
  }
  let bar_ms = mono_end(ts2) / rounds.to_double() / 1000.0
  // 环形：50 扇区角度 + 图例标签
  let dvals : Array[Double] = []
  for s in slices {
    dvals.push(s.value)
  }
  let ts3 = mono_start()
  for _ in 0..<rounds {
    for i in 0..<slices.length() {
      ignore(sector_angles(dvals, i))
      ignore(fmt_axis(slices[i].value))
    }
  }
  let donut_ms = mono_end(ts3) / rounds.to_double() / 1000.0
  // 散点：10000 点双轴换算 + 趋势线
  let ts4 = mono_start()
  for _ in 0..<rounds {
    let ((xlo, xhi), (ylo, yhi)) = point_range(pts)
    ignore(linreg(pts))
    for pt in pts {
      ignore(map_xv(pt.0, xlo, xhi, 46.0, 546.0))
      ignore(map_y(pt.1, ylo, yhi, 12.0, 296.0))
    }
  }
  let scatter_ms = mono_end(ts4) / rounds.to_double() / 1000.0
  // 长跑：10 分钟 @2Hz × 4 序列 = 4800 次推点（窗口长度恒定 = 内存有界）
  let run : Store[Array[LineSeries]] = Store::new([
    LineSeries::make("a", max_points=1000),
    LineSeries::make("b", max_points=1000),
    LineSeries::make("c", max_points=1000),
    LineSeries::make("d", max_points=1000),
  ])
  let ts5 = mono_start()
  for i in 0..<1200 {
    for s in 0..<4 {
      series_push(run, s, (i * 31 % 97).to_double())
    }
  }
  let push_ms = mono_end(ts5) / 1000.0
  let lens = run.get().map(fn(s) { s.points.length() })
  assert_eq(lens[0], 1000) // 超限丢最旧，窗口不增长
  assert_eq(lens[3], 1000)
  println(
    "pure: line(steep)=\{line_ms}ms line(smooth)=\{line_smooth_ms}ms bar=\{bar_ms}ms donut=\{donut_ms}ms scatter=\{scatter_ms}ms push4800=\{push_ms}ms",
  )
}

///|
/// 每帧几何调用耗时（离屏 Canvas）：与 draw_* 每帧几何调用序同构
/// （折线面积填充 + 4×1000 折线、200 柱、50 扇区环、仪表环、10000 点），
/// 仅文本路径离屏不可用（需 initialize + 显示环境，见下一测试）。
test "图表每帧几何调用耗时（离屏 Canvas, release 计时）" {
  let (series, smooth, bars, slices, pts) = bench_data()
  let canvas = Canvas::new(560.0, 320.0)
  let p = canvas.get_painter()
  let rounds = 50
  // 折线（密集态）：列抽稀 + 按列竖条面积填充（与 draw_line_chart 同路径）
  fn line_geom(p : Painter, sers : Array[LineSeries]) -> Unit {
    for si, s in sers {
      let color = series_color(si)
      let cols = decimate_columns(
        s.points,
        0.0,
        100.0,
        46.0,
        504.0,
        12.0,
        242.0,
      )
      let colw = if cols.length() > 1 {
        (504.0 - 46.0) / (cols.length() - 1).to_double() + 0.5
      } else {
        459.0
      }
      let anchor = area_anchor(0.0, 100.0, 12.0, 242.0)
      p.set_fill_color(with_alpha(color, "26"))
      for col in cols {
        let (cx, ymin, ymax) = col
        if ymax < anchor - 0.01 {
          p.fill_rect(cx - colw / 2.0, ymax, colw, anchor - ymax)
        }
        if ymin > anchor + 0.01 {
          p.fill_rect(cx - colw / 2.0, anchor, colw, ymin - anchor)
        }
      }
    }
  }

  let ts1 = mono_start()
  for _ in 0..<rounds {
    line_geom(p, series)
  }
  let line_ms = mono_end(ts1) / rounds.to_double() / 1000.0
  let ts1b = mono_start()
  for _ in 0..<rounds {
    line_geom(p, smooth)
  }
  let line_smooth_ms = mono_end(ts1b) / rounds.to_double() / 1000.0
  // 柱状：200 柱 + hover 描边与整行高亮
  let ts2 = mono_start()
  for r in 0..<rounds {
    for i in 0..<bars.length() {
      let (bx, bw) = bar_slot(i, bars.length(), 46.0, 548.0, gap=1.25)
      let vy = map_y(bars[i].value, -20.5, 50.5, 14.0, 256.0)
      let bh = (135.0 - vy).abs()
      if i == r % bars.length() {
        p.set_fill_color(theme_primary_light())
        p.fill_rect(bx, vy, bw, bh)
        p.set_stroke_color(theme_primary())
        p.stroke_rect(bx + 0.5, vy + 0.5, bw - 1.0, bh - 1.0)
      } else {
        p.set_fill_color(theme_primary())
        p.fill_rect(bx, vy, bw, bh)
      }
    }
  }
  let bar_ms = mono_end(ts2) / rounds.to_double() / 1000.0
  // 环形：50 扇区环（含 hover 外扩半径）
  let ts3 = mono_start()
  for r in 0..<rounds {
    for i in 0..<slices.length() {
      match sector_angles([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0], i % 8) {
        None => ()
        Some((a0, a1)) => {
          let ro = if i == r % slices.length() { 116.0 } else { 112.0 }
          p.set_fill_color(donut_color(i))
          fill_ring(p, 120.0, 120.0, ro, 78.0, a0, a1)
        }
      }
    }
  }
  let donut_ms = mono_end(ts3) / rounds.to_double() / 1000.0
  // 仪表盘：轨道环 + 值弧
  let ts4 = mono_start()
  for r in 0..<rounds {
    p.set_fill_color(theme_info_light())
    fill_ring(p, 120.0, 92.0, 92.0, 68.0, gauge_angle(0.0), gauge_angle(1.0))
    p.set_fill_color(theme_primary())
    fill_ring(
      p,
      120.0,
      92.0,
      92.0,
      68.0,
      gauge_angle(0.0),
      gauge_angle((r % 100).to_double() / 100.0),
    )
  }
  let gauge_ms = mono_end(ts4) / rounds.to_double() / 1000.0
  // 散点：10000 点 + 趋势线
  let ts5 = mono_start()
  for _ in 0..<rounds {
    p.set_stroke_color(theme_danger())
    p.begin_path()
    p.move_to(46.0, 296.0)
    p.line_to(546.0, 12.0)
    p.stroke()
    p.set_fill_color(theme_primary())
    for pt in pts {
      p.fill_rect(
        map_xv(pt.0, 0.0, 100.0, 46.0, 546.0) - 1.5,
        map_y(pt.1, 0.0, 100.0, 12.0, 296.0) - 1.5,
        3.0,
        3.0,
      )
    }
  }
  let scatter_ms = mono_end(ts5) / rounds.to_double() / 1000.0
  println(
    "geom: line(steep)=\{line_ms}ms line(smooth)=\{line_smooth_ms}ms bar=\{bar_ms}ms donut=\{donut_ms}ms gauge=\{gauge_ms}ms scatter=\{scatter_ms}ms",
  )
}

///|
/// 真实全帧绘制耗时（含文本标注）：离屏 painter 的文本路径需要先
/// initialize（GTK 栈），无 DISPLAY 的环境跳过（CI 无显示）。
test "图表真实全帧绘制耗时（有显示环境, release 计时）" {
  let has_display = match @env.get_env_var("DISPLAY") {
    Some(_) => true
    None => false
  }
  if !has_display {
    println("full: skip (no DISPLAY)")
    return
  }
  let (series, smooth, bars, slices, pts) = bench_data()
  ignore(initialize())
  let canvas = Canvas::new(560.0, 320.0)
  let p = canvas.get_painter()
  let rounds = 50
  let ts1 = mono_start()
  for _ in 0..<rounds {
    draw_line_chart(p, 560.0, 260.0, series, true, None, true)
  }
  let line_ms = mono_end(ts1) / rounds.to_double() / 1000.0
  let ts1b = mono_start()
  for _ in 0..<rounds {
    draw_line_chart(p, 560.0, 260.0, smooth, true, None, true)
  }
  let line_smooth_ms = mono_end(ts1b) / rounds.to_double() / 1000.0
  let ts2 = mono_start()
  for i in 0..<rounds {
    draw_bar_chart(p, 560.0, 280.0, bars, true, i % 200)
    draw_bar_chart(p, 560.0, 280.0, bars, false, i % 200)
  }
  let bar_ms = mono_end(ts2) / (2 * rounds).to_double() / 1000.0
  let ts3 = mono_start()
  for i in 0..<rounds {
    draw_donut(p, 480.0, 240.0, slices, 34.0, "", i % 50)
  }
  let donut_ms = mono_end(ts3) / rounds.to_double() / 1000.0
  let ts4 = mono_start()
  for i in 0..<rounds {
    draw_gauge(p, 240.0, 170.0, (i % 100).to_double() / 100.0, [
      (0.6, theme_success()),
      (0.85, theme_warning()),
      (1.0, theme_danger()),
    ])
  }
  let gauge_ms = mono_end(ts4) / rounds.to_double() / 1000.0
  let ts5 = mono_start()
  for _ in 0..<rounds {
    draw_scatter(p, 560.0, 320.0, pts, true, 3.0)
  }
  let scatter_ms = mono_end(ts5) / rounds.to_double() / 1000.0
  println(
    "full: line(steep)=\{line_ms}ms line(smooth)=\{line_smooth_ms}ms bar=\{bar_ms}ms donut=\{donut_ms}ms gauge=\{gauge_ms}ms scatter=\{scatter_ms}ms",
  )
}
