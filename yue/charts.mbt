// 图表组件族（EP Chart 对标，纯 MoonBit 全自绘，Painter 承载）：
//   line_chart_t  折线/面积图：定长滚动窗口、多序列（≤4）、y 轴自适应或
//                  手动范围、横向网格、最新值右端标注
//   bar_chart_t   柱状/条形图：纵向柱与横向条两形态、正负值基线、
//                  hover 高亮 + 行内数值标注（自绘，无弹层）
//   donut_chart_t 环形图：占比扇区、中心汇总数值、图例、hover 扇区外扩
//   gauge_t       仪表盘：单值百分比环、中心大数字、阈值分段着色、
//                  定时器插值平滑（非动画帧驱动）
//   scatter_t     散点图：x/y 点列、最小二乘趋势线可选
// 渲染模型：单一自绘容器，on_draw 内现取 theme_* 色（theme_apply 切换
// 深浅即重绘跟随）；数据经 Store 驱动，set 后只 schedule_paint 画布，
// 不重建视图树。高频推点用 win_push / series_push 换新窗口（旧窗口不变），
// 窗口长度恒定，内存不随推点增长。
// 纯函数（滚动窗口/坐标换算/刻度算法/扇区角度/回归）集中在文件头部，
// charts_wbtest.mbt 白盒覆盖；重绘耗时基准（release 计时）与长跑内存
// 实测数据见 docs/zh/adaptation.md。

///|
/// 圆周率（core 的 pi 在 deprecated 模块，勿用）。
let pi : Double = 3.141592653589793

///|
/// 整圆周（2π）。
let tau : Double = 6.283185307179586

// ---------------------------------------------------------------------------
// 纯函数层：数据窗口 / 坐标换算 / 刻度 / 扇区 / 回归（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 折线序列：名称 + 定长滚动窗口（points 旧→新排列）。
/// 推点用 [win_push] 换新窗口，或对 Store 用 [series_push]。
pub(all) struct LineSeries {
  name : String
  max_points : Int
  points : Array[Double]
}

///|
/// 建序列（max_points 为窗口容量，超出丢最旧）。
pub fn LineSeries::make(name : String, max_points? : Int = 100) -> LineSeries {
  { name, max_points, points: [], }
}

///|
/// 滚动窗口推点：返回新窗口（旧→新），超出 max_points 丢最旧；
/// 入参窗口不变。max_points <= 0 时只保留最新一点。
pub fn win_push(
  win : Array[Double],
  max_points : Int,
  v : Double,
) -> Array[Double] {
  let keep = if max_points < 1 { 1 } else { max_points }
  let n = win.length()
  let start = if n >= keep { n - keep + 1 } else { 0 }
  let out : Array[Double] = []
  for i in start..<n {
    out.push(win[i])
  }
  out.push(v)
  out
}

///|
/// 向多序列 Store 的第 i 个序列推点（窗口超限自动丢最旧），整表 set
/// 一次触发订阅者重绘；i 越界时无操作。
pub fn series_push(
  series : Store[Array[LineSeries]],
  i : Int,
  v : Double,
) -> Unit {
  let cur = series.get()
  if i < 0 || i >= cur.length() {
    return
  }
  let out = cur.copy()
  let s = out[i]
  out[i] = { ..s, points: win_push(s.points, s.max_points, v), }
  series.set(out)
}

///|
/// y 轴自适应范围：全部序列窗口的 min/max + 8% 留白；空窗给 (0, 1)；
/// 等值退化（min==max）以值为中心撑开（|值|<10 时至少 ±1）。
pub fn auto_y_range(series : Array[LineSeries]) -> (Double, Double) {
  let mut lo = 0.0
  let mut hi = 0.0
  let mut any = false
  for s in series {
    for v in s.points {
      if !any {
        lo = v
        hi = v
        any = true
      } else {
        if v < lo {
          lo = v
        }
        if v > hi {
          hi = v
        }
      }
    }
  }
  if !any {
    (0.0, 1.0)
  } else if hi - lo < 1.0e-12 {
    let pad = if lo.abs() < 10.0 { 1.0 } else { lo.abs() * 0.1 }
    (lo - pad, hi + pad)
  } else {
    let pad = (hi - lo) * 0.08
    (lo - pad, hi + pad)
  }
}

///|
/// 数值 → y 像素（lo/hi 为值域，top/bottom 为画布上下边；值域退化时取中点）。
pub fn map_y(
  v : Double,
  lo : Double,
  hi : Double,
  top : Double,
  bottom : Double,
) -> Double {
  if hi - lo < 1.0e-12 {
    (top + bottom) / 2.0
  } else {
    let t = (v - lo) / (hi - lo)
    bottom - t * (bottom - top)
  }
}

///|
/// 数值 → x 像素（值域 lo..hi 映射到 left..right；退化时取中点）。
pub fn map_xv(
  v : Double,
  lo : Double,
  hi : Double,
  left : Double,
  right : Double,
) -> Double {
  if hi - lo < 1.0e-12 {
    (left + right) / 2.0
  } else {
    left + (v - lo) / (hi - lo) * (right - left)
  }
}

///|
/// 序号 → x 像素（n 个点均布 left..right；单点取中点）。
pub fn map_idx(i : Int, n : Int, left : Double, right : Double) -> Double {
  if n <= 1 {
    (left + right) / 2.0
  } else {
    left + i.to_double() / (n - 1).to_double() * (right - left)
  }
}

///|
/// 整齐步长：把 raw 归整到 1/2/5×10^k（k 为整数）。
fn nice_step(raw : Double) -> Double {
  if !(raw > 0.0) {
    return 1.0
  }
  let mut v = raw
  let mut k = 0
  while v >= 10.0 {
    v = v / 10.0
    k = k + 1
  }
  while v < 1.0 {
    v = v * 10.0
    k = k - 1
  }
  let m = if v < 1.5 {
    1.0
  } else if v < 3.5 {
    2.0
  } else if v < 7.5 {
    5.0
  } else {
    10.0
  }
  let mut base = 1.0
  let mut j = 0
  while j < k {
    base = base * 10.0
    j = j + 1
  }
  while j > k {
    base = base / 10.0
    j = j - 1
  }
  m * base
}

///|
/// 轴刻度值：在 [lo, hi] 内取约 count 个 1/2/5×10^k 整齐值；lo >= hi
/// 或 count <= 0 时返回空。
pub fn nice_ticks(lo : Double, hi : Double, count? : Int = 4) -> Array[Double] {
  if count <= 0 || !(hi > lo) {
    return []
  }
  let step = nice_step((hi - lo) / count.to_double())
  if !(step > 0.0) {
    return []
  }
  // 首个刻度：>= lo 的最小 step 倍数（to_int 向零取整，负值需向下兜一圈）
  let mut t = (lo / step).to_int().to_double() * step
  while t < lo {
    t = t + step
  }
  while t - step >= lo {
    t = t - step
  }
  let out : Array[Double] = []
  let mut limit = 0
  while t <= hi + step * 1.0e-9 && limit < 1000 {
    out.push(t)
    t = t + step
    limit = limit + 1
  }
  out
}

///|
/// 轴标签格式：最多两位小数、去尾零（整数不带小数点）；|v| >= 1.0e9 时
/// 按整数值直出（轴标签不会到这种量级，仅兜底）。
pub fn fmt_axis(v : Double) -> String {
  let a = if v < 0.0 { -v } else { v }
  if a >= 1.0e9 {
    return v.to_int().to_string()
  }
  let scaled = (a * 100.0).round().to_int()
  let neg = v < 0.0 && scaled != 0
  let ip = scaled / 100
  let frac = scaled % 100
  let body = if frac == 0 {
    ip.to_string()
  } else if frac % 10 == 0 {
    "\{ip}.\{frac / 10}"
  } else if frac < 10 {
    "\{ip}.0\{frac}"
  } else {
    "\{ip}.\{frac}"
  }
  if neg {
    "-\{body}"
  } else {
    body
  }
}

///|
/// 柱状图值域：含 0 与全部值，两端 6% 留白；空数据给 (0, 1)，
/// 全零退化给 (-1, 1)。
pub fn bar_range(values : Array[Double]) -> (Double, Double) {
  let mut lo = 0.0
  let mut hi = 0.0
  let mut any = false
  for v in values {
    if !any {
      lo = v
      hi = v
      any = true
    } else {
      if v < lo {
        lo = v
      }
      if v > hi {
        hi = v
      }
    }
  }
  if !any {
    return (0.0, 1.0)
  }
  if lo > 0.0 {
    lo = 0.0
  }
  if hi < 0.0 {
    hi = 0.0
  }
  let span = hi - lo
  if span < 1.0e-12 {
    return (-1.0, 1.0)
  }
  let pad = span * 0.06
  (lo - pad, hi + pad)
}

///|
/// 第 i 根的矩形（x, w）：n 根均分 [left, right]，根间距 gap，
/// 宽不足 1px 时钳到 1（200 类目窄条仍可见）。
pub fn bar_slot(
  i : Int,
  n : Int,
  left : Double,
  right : Double,
  gap? : Double = 4.0,
) -> (Double, Double) {
  if n <= 0 {
    return (left, (right - left).max(1.0))
  }
  let slot = (right - left) / n.to_double()
  let w = (slot - gap).max(1.0)
  let x = left + slot * i.to_double() + (slot - w) / 2.0
  (x, w)
}

///|
/// 环形图第 i 扇区的起止弧度（12 点方向起，顺时针；角度为画布语义，
/// 0 指向右）。只累计正值；总和 <= 0 或 i 越界返回 None。
pub fn sector_angles(values : Array[Double], i : Int) -> (Double, Double)? {
  if i < 0 || i >= values.length() {
    return None
  }
  let mut total = 0.0
  for v in values {
    if v > 0.0 {
      total = total + v
    }
  }
  if total <= 0.0 {
    return None
  }
  let mut acc = 0.0
  for j in 0..<i {
    if values[j] > 0.0 {
      acc = acc + values[j]
    }
  }
  let a0 = -pi / 2.0 + tau * acc / total
  let v = if values[i] > 0.0 { values[i] } else { 0.0 }
  let mut sweep = tau * v / total
  if sweep > tau - 0.0002 {
    sweep = tau - 0.0002
  }
  Some((a0, a0 + sweep))
}

///|
/// 仪表盘弧度映射：frac 钳到 0..1 后线性映射到 [start, start+sweep]
/// （默认 135° 起、扫 270°，开口朝下）。
pub fn gauge_angle(
  frac : Double,
  start? : Double = 0.75 * pi,
  sweep? : Double = 1.5 * pi,
) -> Double {
  let f = if frac < 0.0 { 0.0 } else if frac > 1.0 { 1.0 } else { frac }
  start + sweep * f
}

///|
/// 最小二乘趋势线：返回 (斜率 k, 截距 b) 使 y = k*x + b；点数 < 2 或
/// x 全同（分母为 0）时 None。
pub fn linreg(points : Array[(Double, Double)]) -> (Double, Double)? {
  let n = points.length()
  if n < 2 {
    return None
  }
  let mut sx = 0.0
  let mut sy = 0.0
  let mut sxx = 0.0
  let mut sxy = 0.0
  for pt in points {
    sx = sx + pt.0
    sy = sy + pt.1
    sxx = sxx + pt.0 * pt.0
    sxy = sxy + pt.0 * pt.1
  }
  let d = n.to_double() * sxx - sx * sx
  if d.abs() < 1.0e-12 {
    return None
  }
  let k = (n.to_double() * sxy - sx * sy) / d
  let b = (sy - k * sx) / n.to_double()
  Some((k, b))
}

///|
/// 散点值域：x/y 各自 min/max + 5% 留白；空数据给 (0,1)×(0,1)；
/// 单轴等值退化时该轴 ±1 撑开。
pub fn point_range(
  points : Array[(Double, Double)],
) -> ((Double, Double), (Double, Double)) {
  fn axis_range(lo0 : Double, hi0 : Double, any : Bool) -> (Double, Double) {
    if !any {
      (0.0, 1.0)
    } else if hi0 - lo0 < 1.0e-12 {
      let pad = if lo0.abs() < 10.0 { 1.0 } else { lo0.abs() * 0.1 }
      (lo0 - pad, hi0 + pad)
    } else {
      let pad = (hi0 - lo0) * 0.05
      (lo0 - pad, hi0 + pad)
    }
  }

  let mut xlo = 0.0
  let mut xhi = 0.0
  let mut ylo = 0.0
  let mut yhi = 0.0
  let mut any = false
  for pt in points {
    if !any {
      xlo = pt.0
      xhi = pt.0
      ylo = pt.1
      yhi = pt.1
      any = true
    } else {
      if pt.0 < xlo {
        xlo = pt.0
      }
      if pt.0 > xhi {
        xhi = pt.0
      }
      if pt.1 < ylo {
        ylo = pt.1
      }
      if pt.1 > yhi {
        yhi = pt.1
      }
    }
  }
  (axis_range(xlo, xhi, any), axis_range(ylo, yhi, any))
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 图表系列色（≤4 序列循环）：主题四语义色，深浅主题下自动跟随。
fn series_color(i : Int) -> String {
  match i % 4 {
    0 => theme_primary()
    1 => theme_success()
    2 => theme_warning()
    _ => theme_danger()
  }
}

///|
/// 环形图扇区色（5 色循环，相邻扇区不同色）。
fn donut_color(i : Int) -> String {
  match i % 5 {
    0 => theme_primary()
    1 => theme_success()
    2 => theme_warning()
    3 => theme_danger()
    _ => theme_info()
  }
}

///|
/// 横向网格 + 左侧刻度标签（右对齐贴轴）；顺带画底部基线。
fn draw_hgrid(
  p : Painter,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  lo : Double,
  hi : Double,
  ticks : Array[Double],
  label_w? : Double = 40.0,
) -> Unit {
  for t in ticks {
    let ty = map_y(t, lo, hi, y0, y1)
    if ty < y0 - 0.5 || ty > y1 + 0.5 {
      continue
    }
    p.set_stroke_color(theme_border())
    p.begin_path()
    p.move_to(x0, ty)
    p.line_to(x1, ty)
    p.stroke()
    p.draw_text(
      fmt_axis(t),
      x0 - label_w - 4.0,
      ty - 8.0,
      label_w,
      16.0,
      align=End,
      valign=Center,
      color=theme_text_secondary(),
    )
  }
  p.set_stroke_color(theme_border())
  p.begin_path()
  p.move_to(x0, y1)
  p.line_to(x1, y1)
  p.stroke()
}

///|
/// 竖直网格 + 底部刻度标签（居中对齐贴轴）。
fn draw_vgrid(
  p : Painter,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  lo : Double,
  hi : Double,
  ticks : Array[Double],
) -> Unit {
  for t in ticks {
    let tx = map_xv(t, lo, hi, x0, x1)
    if tx < x0 - 0.5 || tx > x1 + 0.5 {
      continue
    }
    p.set_stroke_color(theme_border())
    p.begin_path()
    p.move_to(tx, y0)
    p.line_to(tx, y1)
    p.stroke()
    p.draw_text(
      fmt_axis(t),
      tx - 30.0,
      y1 + 3.0,
      60.0,
      16.0,
      align=Center,
      valign=Center,
      color=theme_text_secondary(),
    )
  }
}

///|
/// 列抽稀：把 n 个点按绘制区宽度压缩为像素列，每列取 (x, y_min, y_max)
/// （保极值）。点数 <= 列数时逐点输出（退化为原始折线，y_min==y_max）；
/// 密集时每列一个竖段，绘制成本与窗口大小脱钩、只随绘制区宽度增长。
fn decimate_columns(
  points : Array[Double],
  lo : Double,
  hi : Double,
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
) -> Array[(Double, Double, Double)] {
  let out : Array[(Double, Double, Double)] = []
  let n = points.length()
  if n <= 0 {
    return out
  }
  let cols = (x1 - x0).round().to_int().max(1)
  if n <= cols {
    for i in 0..<n {
      let y = map_y(points[i], lo, hi, y0, y1)
      out.push((map_idx(i, n, x0, x1), y, y))
    }
    return out
  }
  let span = if cols > 1 { (x1 - x0) / (cols - 1).to_double() } else { 0.0 }
  for c in 0..<cols {
    let i0 = c * n / cols
    let i1 = if c == cols - 1 { n } else { (c + 1) * n / cols }
    if i1 <= i0 {
      continue
    }
    let mut vmin = points[i0]
    let mut vmax = points[i0]
    for i in i0..<i1 {
      let v = points[i]
      if v < vmin {
        vmin = v
      }
      if v > vmax {
        vmax = v
      }
    }
    let x = x0 + c.to_double() * span
    out.push((x, map_y(vmin, lo, hi, y0, y1), map_y(vmax, lo, hi, y0, y1)))
  }
  out
}

///|
/// 面积填充锚点：0 在值域内时取零线，全正值取绘制区底，全负值取绘制区顶。
fn area_anchor(lo : Double, hi : Double, y0 : Double, y1 : Double) -> Double {
  if lo <= 0.0 && hi >= 0.0 {
    map_y(0.0, lo, hi, y0, y1)
  } else if lo > 0.0 {
    y1
  } else {
    y0
  }
}

///|
/// 折线/面积图绘制（画布坐标，序列已由调用方取出）。密集渲染（点数多于
/// 像素列）按列出图：面积模式每列填一个到锚线的矩形（填充顶边即折线），
/// 折线模式每列画 min..max 竖条（等效极值包络）——绘制成本与窗口大小
/// 脱钩，只随绘制区宽度增长；稀疏（点数 <= 列数）走真实折线 + 多边形
/// 面积，保留完整抗锯齿形态。路径描边在软件光栅化下每段约 1.8µs，
/// 1000 点 × 4 序列全描边超 5ms 验收线，故密集态一律改用矩形路径
/// （实测数据见 docs/zh/adaptation.md）。
fn draw_line_chart(
  p : Painter,
  w : Double,
  h : Double,
  series : Array[LineSeries],
  area : Bool,
  y_range : (Double, Double)?,
  show_last : Bool,
) -> Unit {
  let pad_l = 46.0
  let pad_r = if show_last { 56.0 } else { 12.0 }
  let pad_t = 12.0
  let pad_b = 18.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let (lo, hi) = match y_range {
    Some((a, b)) => if a <= b { (a, b) } else { (b, a) }
    None => auto_y_range(series)
  }
  draw_hgrid(
    p,
    x0,
    y0,
    x1,
    y1,
    lo,
    hi,
    nice_ticks(lo, hi, count=4),
    label_w=pad_l - 6.0,
  )
  // 空窗提示
  let mut any = false
  for s in series {
    if s.points.length() > 0 {
      any = true
    }
  }
  if !any {
    let at = AttributedText::new(
      "暂无数据",
      align=Center,
      valign=Center,
      wrap=false,
    )
    at.set_font(Font::new("Sans", 13.0))
    at.set_color(theme_text_secondary())
    let tw = at.get_bounds_for(400.0, 40.0).width
    p.draw_attributed_text(
      at,
      (x0 + x1) / 2.0 - tw / 2.0,
      (y0 + y1) / 2.0 - 10.0,
      tw + 4.0,
      20.0,
    )
    return
  }
  for si, s in series {
    let n = s.points.length()
    if n == 0 {
      continue
    }
    let color = series_color(si)
    let cols = decimate_columns(s.points, lo, hi, x0, x1, y0, y1)
    let colw = if cols.length() > 1 {
      (x1 - x0) / (cols.length() - 1).to_double() + 0.5
    } else {
      x1 - x0 + 0.5
    }
    let dense = n > (x1 - x0).round().to_int().max(1)
    if dense {
      // 密集：按列矩形。面积模式填到锚线（顶边即折线，不再另描）；
      // 折线模式画 min..max 竖条（等效极值包络）。
      if area {
        let anchor = area_anchor(lo, hi, y0, y1)
        p.set_fill_color(color + "26")
        for col in cols {
          let (cx, ymin, ymax) = col
          if ymax < anchor - 0.01 {
            p.fill_rect(cx - colw / 2.0, ymax, colw, anchor - ymax)
          }
          if ymin > anchor + 0.01 {
            p.fill_rect(cx - colw / 2.0, anchor, colw, ymin - anchor)
          }
        }
      } else {
        p.set_fill_color(color)
        for col in cols {
          let (cx, ymin, ymax) = col
          p.fill_rect(cx - colw / 2.0, ymin, colw, (ymax - ymin).max(1.0))
        }
      }
    } else {
      // 稀疏：真实折线 + 多边形面积（点数 <= 像素列，成本可忽略）
      let anchor = area_anchor(lo, hi, y0, y1)
      if area {
        p.set_fill_color(color + "26")
        p.begin_path()
        p.move_to(cols[0].0, anchor)
        for col in cols {
          p.line_to(col.0, col.2)
        }
        p.line_to(cols[cols.length() - 1].0, anchor)
        p.close_path()
        p.fill()
      }
      p.set_stroke_color(color)
      p.begin_path()
      p.move_to(cols[0].0, cols[0].1)
      for col in cols {
        p.line_to(col.0, col.1)
        p.line_to(col.0, col.2)
      }
      p.stroke()
    }
    if show_last {
      let v = s.points[n - 1]
      let ly = map_y(v, lo, hi, y0, y1)
      p.draw_text(
        fmt_axis(v),
        x1 + 8.0,
        ly - 9.0,
        pad_r - 12.0,
        18.0,
        align=Start,
        valign=Center,
        color~,
      )
    }
  }
}

///|
/// 柱状图项（类目标签 + 数值，可为负）。
pub(all) struct BarItem {
  label : String
  value : Double
}

///|
/// 建柱状图项。
pub fn BarItem::make(label : String, value : Double) -> BarItem {
  { label, value, }
}

///|
/// 文本按可用宽截断（等宽估算：Sans 12px 每字符约 7px），超出加省略号。
fn truncate_to(text : String, avail : Double) -> String {
  if avail <= 8.0 {
    return ""
  }
  let max_chars = (avail / 7.0).to_int()
  if text.length() <= max_chars {
    return text
  }
  if max_chars <= 1 {
    return ""
  }
  let out = StringBuilder()
  let mut i = 0
  for ch in text {
    if i >= max_chars - 1 {
      break
    }
    out.write_char(ch)
    i = i + 1
  }
  out.write_char('…')
  out.to_string()
}

///|
/// 柱状图绘制（vertical=true 纵向柱，false 横向条；hover 为高亮类目索引）。
fn draw_bar_chart(
  p : Painter,
  w : Double,
  h : Double,
  data : Array[BarItem],
  vertical : Bool,
  hover : Int,
) -> Unit {
  let n = data.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let values : Array[Double] = []
  for it in data {
    values.push(it.value)
  }
  let (lo, hi) = bar_range(values)
  let ticks = nice_ticks(lo, hi, count=4)
  if vertical {
    let pad_l = 46.0
    let pad_r = 12.0
    let pad_t = 14.0
    let pad_b = 24.0
    let x0 = pad_l
    let x1 = w - pad_r
    let y0 = pad_t
    let y1 = h - pad_b
    if x1 <= x0 || y1 <= y0 {
      return
    }
    draw_hgrid(p, x0, y0, x1, y1, lo, hi, ticks, label_w=pad_l - 6.0)
    let yb = map_y(0.0, lo, hi, y0, y1)
    let slot = (x1 - x0) / n.to_double()
    // 类目标签抽稀：槽宽不足 26px 时每隔 step 个画一个
    let step = if slot >= 26.0 {
      1
    } else {
      (26.0 / slot).ceil().to_int().max(1)
    }
    for i in 0..<n {
      let (bx, bw) = bar_slot(i, n, x0, x1, gap=slot * 0.25)
      let vy = map_y(data[i].value, lo, hi, y0, y1)
      let top = if vy < yb { vy } else { yb }
      let bh = (vy - yb).abs().max(1.0)
      let positive = data[i].value >= 0.0
      let base_color = if positive { theme_primary() } else { theme_danger() }
      let light_color = if positive {
        theme_primary_light()
      } else {
        theme_danger_light()
      }
      if hover == i {
        p.set_fill_color(light_color)
        p.fill_rect(bx, top, bw, bh)
        p.set_stroke_color(base_color)
        p.stroke_rect(bx + 0.5, top + 0.5, bw - 1.0, bh - 1.0)
      } else {
        p.set_fill_color(base_color)
        p.fill_rect(bx, top, bw, bh)
      }
      if i % step == 0 {
        p.draw_text(
          truncate_to(data[i].label, slot),
          bx + bw / 2.0 - slot / 2.0,
          y1 + 3.0,
          slot,
          16.0,
          align=Center,
          valign=Center,
          color=theme_text_secondary(),
        )
      }
      if hover == i {
        // 行内数值标注：正数在柱顶上方，负数在柱底下方
        let ly = if positive { top - 18.0 } else { top + bh + 2.0 }
        p.draw_text(
          fmt_axis(data[i].value),
          bx + bw / 2.0 - slot / 2.0,
          ly,
          slot,
          16.0,
          align=Center,
          valign=Center,
          color=theme_text_primary(),
        )
      }
    }
  } else {
    let pad_l = 84.0
    let pad_r = 20.0
    let pad_t = 12.0
    let pad_b = 24.0
    let x0 = pad_l
    let x1 = w - pad_r
    let y0 = pad_t
    let y1 = h - pad_b
    if x1 <= x0 || y1 <= y0 {
      return
    }
    draw_vgrid(p, x0, y0, x1, y1, lo, hi, ticks)
    let xb = map_xv(0.0, lo, hi, x0, x1)
    let slot = (y1 - y0) / n.to_double()
    let step = if slot >= 22.0 {
      1
    } else {
      (22.0 / slot).ceil().to_int().max(1)
    }
    for i in 0..<n {
      let by = y0 + slot * i.to_double() + (slot - (slot - 4.0).max(1.0)) / 2.0
      let bh = (slot - 4.0).max(1.0)
      let vx = map_xv(data[i].value, lo, hi, x0, x1)
      let left = if vx < xb { vx } else { xb }
      let bw = (vx - xb).abs().max(1.0)
      let positive = data[i].value >= 0.0
      let base_color = if positive { theme_primary() } else { theme_danger() }
      let light_color = if positive {
        theme_primary_light()
      } else {
        theme_danger_light()
      }
      if hover == i {
        // 行内高亮：整行浅底 + 条描边
        p.set_fill_color(theme_fill_hover())
        p.fill_rect(x0 - 76.0, y0 + slot * i.to_double(), x1 - x0 + 76.0, slot)
        p.set_fill_color(light_color)
        p.fill_rect(left, by, bw, bh)
        p.set_stroke_color(base_color)
        p.stroke_rect(left + 0.5, by + 0.5, bw - 1.0, bh - 1.0)
      } else {
        p.set_fill_color(base_color)
        p.fill_rect(left, by, bw, bh)
      }
      if i % step == 0 {
        p.draw_text(
          truncate_to(data[i].label, pad_l - 14.0),
          4.0,
          y0 + slot * i.to_double(),
          pad_l - 14.0,
          slot,
          align=End,
          valign=Center,
          color=theme_text_secondary(),
        )
      }
      if hover == i {
        // 行内数值标注：正数在条右端，负数在条左端
        let lx = if positive { left + bw + 4.0 } else { left - 64.0 }
        p.draw_text(
          fmt_axis(data[i].value),
          lx,
          y0 + slot * i.to_double(),
          60.0,
          slot,
          align=if positive { Start } else { End },
          valign=Center,
          color=theme_text_primary(),
        )
      }
    }
  }
}

///|
/// 环形图项（标签 + 占比值）。
pub(all) struct DonutSlice {
  label : String
  value : Double
}

///|
/// 建环形图项。
pub fn DonutSlice::make(label : String, value : Double) -> DonutSlice {
  { label, value, }
}

///|
/// 环形图绘制（扇区 + 中心汇总 + 图例；hover 扇区外扩 4px）。
fn draw_donut(
  p : Painter,
  w : Double,
  h : Double,
  data : Array[DonutSlice],
  thickness : Double,
  center : String,
  hover : Int,
) -> Unit {
  let n = data.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let d = h - 16.0
  let cx = 8.0 + d / 2.0
  let cy = h / 2.0
  let r_out = d / 2.0
  let r_in = (r_out - thickness).max(1.0)
  let values : Array[Double] = []
  for s in data {
    values.push(s.value)
  }
  for i in 0..<n {
    match sector_angles(values, i) {
      None => ()
      Some((a0, a1)) => {
        if a1 - a0 < 1.0e-6 {
          continue
        }
        let ro = if hover == i { r_out + 4.0 } else { r_out }
        p.set_fill_color(donut_color(i))
        p.begin_path()
        p.arc(cx, cy, ro, a0, a1)
        p.line_to(cx + r_in * @math.cos(a1), cy + r_in * @math.sin(a1))
        p.arc(cx, cy, r_in, a1, a0, ccw=true)
        p.close_path()
        p.fill()
      }
    }
  }
  // 中心汇总数值（默认总和，可用 center 覆盖）
  let total = {
    let mut t = 0.0
    for s in data {
      if s.value > 0.0 {
        t = t + s.value
      }
    }
    t
  }
  let center_txt = if center != "" { center } else { fmt_axis(total) }
  let at = AttributedText::new(
    center_txt,
    align=Center,
    valign=Center,
    wrap=false,
  )
  at.set_font(Font::new("Sans", 20.0, weight=SemiBold))
  at.set_color(theme_text_primary())
  let tw = at.get_bounds_for(400.0, 60.0).width
  p.draw_attributed_text(at, cx - tw / 2.0, cy - 18.0, tw + 4.0, 28.0)
  let cap = AttributedText::new(
    "总计",
    align=Center,
    valign=Center,
    wrap=false,
  )
  cap.set_font(Font::new("Sans", 11.0))
  cap.set_color(theme_text_secondary())
  let cw = cap.get_bounds_for(200.0, 20.0).width
  p.draw_attributed_text(cap, cx - cw / 2.0, cy + 10.0, cw + 4.0, 16.0)
  // 图例（右侧）：色块 + 标签 + 值(百分比)
  let legend_x = 8.0 + d + 20.0
  if legend_x + 60.0 < w {
    let row_h = ((h - 16.0) / n.to_double()).min(24.0).max(14.0)
    for i in 0..<n {
      let ry = 8.0 + row_h * i.to_double()
      if ry + row_h > h - 4.0 {
        break
      }
      if hover == i {
        p.set_fill_color(theme_fill_hover())
        p.fill_rect(legend_x - 4.0, ry, w - legend_x, row_h)
      }
      p.set_fill_color(donut_color(i))
      p.fill_rect(legend_x, ry + (row_h - 10.0) / 2.0, 10.0, 10.0)
      let pct = if total > 0.0 {
        (data[i].value / total * 100.0).round().to_int()
      } else {
        0
      }
      let val_txt = "\{fmt_axis(data[i].value)} (\{pct}%)"
      p.draw_text(
        truncate_to(data[i].label, (w - legend_x - 130.0).max(20.0)),
        legend_x + 16.0,
        ry,
        (w - legend_x - 130.0).max(20.0),
        row_h,
        align=Start,
        valign=Center,
        color=theme_text_regular(),
      )
      p.draw_text(
        val_txt,
        w - 118.0,
        ry,
        110.0,
        row_h,
        align=End,
        valign=Center,
        color=theme_text_secondary(),
      )
    }
  }
}

///|
/// 仪表盘阈值分段取色：thresholds 按阈值升序给（阈值上限, 颜色），
/// 取第一个阈值 >= frac 段的颜色；越界取末段；空表用主题主色。
fn band_color(frac : Double, thresholds : Array[(Double, String)]) -> String {
  if thresholds.length() == 0 {
    return theme_primary()
  }
  for kv in thresholds {
    if frac <= kv.0 {
      return kv.1
    }
  }
  thresholds[thresholds.length() - 1].1
}

///|
/// 实心圆环段（外弧 a0→a1，内弧返回，填充）。
fn fill_ring(
  p : Painter,
  cx : Double,
  cy : Double,
  r_out : Double,
  r_in : Double,
  a0 : Double,
  a1 : Double,
) -> Unit {
  p.begin_path()
  p.arc(cx, cy, r_out, a0, a1)
  p.line_to(cx + r_in * @math.cos(a1), cy + r_in * @math.sin(a1))
  p.arc(cx, cy, r_in, a1, a0, ccw=true)
  p.close_path()
  p.fill()
}

///|
/// 仪表盘绘制（frac 为显示值 0..1，已插值平滑）。
fn draw_gauge(
  p : Painter,
  w : Double,
  h : Double,
  frac : Double,
  thresholds : Array[(Double, String)],
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let r = (w / 2.0 - 16.0).min((h - 26.0) / 1.8).max(10.0)
  let cx = w / 2.0
  let cy = r + 13.0
  let thick = (r * 0.26).max(8.0)
  let r_in = r - thick
  let a0 = gauge_angle(0.0)
  let a1 = gauge_angle(1.0)
  let av = gauge_angle(frac)
  // 轨道
  p.set_fill_color(theme_info_light())
  fill_ring(p, cx, cy, r, r_in, a0, a1)
  // 值弧（阈值分段着色）
  p.set_fill_color(band_color(frac, thresholds))
  if av > a0 + 0.001 {
    fill_ring(p, cx, cy, r, r_in, a0, av)
  }
  // 中心大数字（百分比）
  let pct = (frac * 100.0).round().to_int()
  let at = AttributedText::new(
    "\{pct}%",
    align=Center,
    valign=Center,
    wrap=false,
  )
  at.set_font(Font::new("Sans", 24.0, weight=SemiBold))
  at.set_color(theme_text_primary())
  let tw = at.get_bounds_for(300.0, 60.0).width
  p.draw_attributed_text(at, cx - tw / 2.0, cy - 16.0, tw + 4.0, 32.0)
  // 两端刻度 0 / 100
  p.draw_text(
    "0",
    cx + (r + 4.0) * @math.cos(a0) - 16.0,
    cy + (r + 4.0) * @math.sin(a0) - 8.0,
    32.0,
    16.0,
    align=Center,
    valign=Center,
    color=theme_text_secondary(),
  )
  p.draw_text(
    "100",
    cx + (r + 4.0) * @math.cos(a1) - 18.0,
    cy + (r + 4.0) * @math.sin(a1) - 8.0,
    36.0,
    16.0,
    align=Center,
    valign=Center,
    color=theme_text_secondary(),
  )
}

///|
/// 散点图绘制（点列 + 可选最小二乘趋势线；绘制区裁剪）。
fn draw_scatter(
  p : Painter,
  w : Double,
  h : Double,
  points : Array[(Double, Double)],
  trend : Bool,
  dot : Double,
) -> Unit {
  let pad_l = 46.0
  let pad_r = 14.0
  let pad_t = 12.0
  let pad_b = 24.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let ((xlo, xhi), (ylo, yhi)) = point_range(points)
  draw_hgrid(
    p,
    x0,
    y0,
    x1,
    y1,
    ylo,
    yhi,
    nice_ticks(ylo, yhi, count=4),
    label_w=pad_l - 6.0,
  )
  draw_vgrid(p, x0, y0, x1, y1, xlo, xhi, nice_ticks(xlo, xhi, count=5))
  if points.length() == 0 {
    let at = AttributedText::new(
      "暂无数据",
      align=Center,
      valign=Center,
      wrap=false,
    )
    at.set_font(Font::new("Sans", 13.0))
    at.set_color(theme_text_secondary())
    let tw = at.get_bounds_for(400.0, 40.0).width
    p.draw_attributed_text(
      at,
      (x0 + x1) / 2.0 - tw / 2.0,
      (y0 + y1) / 2.0 - 10.0,
      tw + 4.0,
      20.0,
    )
    return
  }
  p.save()
  p.clip_rect(x0, y0, x1 - x0, y1 - y0)
  // 趋势线（回归直线跨绘制区）
  if trend {
    match linreg(points) {
      None => ()
      Some((k, b)) => {
        let ya = k * xlo + b
        let yb2 = k * xhi + b
        p.set_stroke_color(theme_danger())
        p.begin_path()
        p.move_to(map_xv(xlo, xlo, xhi, x0, x1), map_y(ya, ylo, yhi, y0, y1))
        p.line_to(map_xv(xhi, xlo, xhi, x0, x1), map_y(yb2, ylo, yhi, y0, y1))
        p.stroke()
      }
    }
  }
  // 点列（裁剪区外跳过，少一次绘制调用）
  let half = dot / 2.0
  p.set_fill_color(theme_primary())
  for pt in points {
    let px = map_xv(pt.0, xlo, xhi, x0, x1)
    let py = map_y(pt.1, ylo, yhi, y0, y1)
    if px < x0 - half || px > x1 + half || py < y0 - half || py > y1 + half {
      continue
    }
    p.fill_rect(px - half, py - half, dot, dot)
  }
  p.restore()
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 折线/面积图（EP Line）：定长滚动窗口多序列（≤4，主题色循环），y 轴
/// 自适应（窗口 min/max + 留白）或经 y_range 手动指定；横向网格 + 左侧
/// 刻度；面积半透明填充可选；最新值右端标注。数据经 Store 驱动：推点用
/// [series_push]（或 [win_push] 换窗口后整体 set），只重绘画布不重建
/// 视图树；主题切换现取色自动跟随。
pub fn line_chart_t(
  series : Store[Array[LineSeries]],
  width? : Double = 560.0,
  height? : Double = 260.0,
  area? : Bool = false,
  y_range? : (Double, Double)? = None,
  show_last? : Bool = true,
) -> Node {
  {
    mount: fn(parent) {
      let cv = themed_container(style=[("width", width), ("height", height)])
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        draw_line_chart(
          p,
          b.width,
          b.height,
          series.get(),
          area,
          y_range,
          show_last,
        )
      })
      series.subscribe(fn(_s) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}

///|
/// 柱状/条形图（EP Bar）：纵向柱（默认）与横向条（horizontal=true）两
/// 形态；以 0 为基线支持正负值（正主题色、负 danger 色）；hover 高亮 +
/// 行内数值标注（自绘，不走弹层）；类目标签过密时自动抽稀截断。数据经
/// Store 驱动，hover 移动只重绘画布。
pub fn bar_chart_t(
  data : Store[Array[BarItem]],
  width? : Double = 560.0,
  height? : Double = 280.0,
  horizontal? : Bool = false,
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(-1)
      let cv = themed_container(style=[("width", width), ("height", height)])
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        draw_bar_chart(p, b.width, b.height, data.get(), horizontal, hover.val)
      })
      data.subscribe(fn(_d) { ViewLike::schedule_paint(cv) })
      // hover 命中与绘制同一套几何（bar_slot / 行槽），保证高亮与柱子对齐
      ViewLike::on_mouse_move(cv, fn(e) {
        let b = ViewLike::get_bounds(cv)
        let items = data.get()
        let n = items.length()
        if n == 0 {
          return
        }
        let new_hover = if horizontal {
          let pad_t = 12.0
          let pad_b = 24.0
          if e.view_y < pad_t || e.view_y > b.height - pad_b {
            -1
          } else {
            let slot = (b.height - pad_t - pad_b) / n.to_double()
            ((e.view_y - pad_t) / slot).to_int()
          }
        } else {
          let pad_l = 46.0
          let pad_r = 12.0
          if e.view_x < pad_l || e.view_x > b.width - pad_r {
            -1
          } else {
            let slot = (b.width - pad_l - pad_r) / n.to_double()
            ((e.view_x - pad_l) / slot).to_int()
          }
        }
        let clamped = if new_hover < 0 || new_hover >= n {
          -1
        } else {
          new_hover
        }
        if clamped != hover.val {
          hover.val = clamped
          ViewLike::schedule_paint(cv)
        }
      })
      ViewLike::on_mouse_leave(cv, fn(_e) {
        if hover.val != -1 {
          hover.val = -1
          ViewLike::schedule_paint(cv)
        }
      })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}

///|
/// 环形/饼图（EP Pie/Donut）：占比扇区（12 点方向起顺时针，5 色循环）、
/// 中心汇总数值（默认总和，可经 center 覆盖文案）、右侧图例（标签 + 值
/// + 百分比）；hover 扇区外扩 4px 且图例行高亮。数据经 Store 驱动。
pub fn donut_chart_t(
  data : Store[Array[DonutSlice]],
  width? : Double = 480.0,
  height? : Double = 240.0,
  thickness? : Double = 34.0,
  center? : String = "",
) -> Node {
  {
    mount: fn(parent) {
      let hover = Ref(-1)
      let cv = themed_container(style=[("width", width), ("height", height)])
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        draw_donut(
          p,
          b.width,
          b.height,
          data.get(),
          thickness,
          center,
          hover.val,
        )
      })
      data.subscribe(fn(_d) { ViewLike::schedule_paint(cv) })
      // 图例行与扇区同索引：hover 图例即高亮对应扇区
      ViewLike::on_mouse_move(cv, fn(e) {
        let b = ViewLike::get_bounds(cv)
        let items = data.get()
        let n = items.length()
        if n == 0 {
          return
        }
        let d = b.height - 16.0
        let legend_x = 8.0 + d + 20.0
        let new_hover = if e.view_x < legend_x {
          -1
        } else {
          let row_h = ((b.height - 16.0) / n.to_double()).min(24.0).max(14.0)
          let idx = ((e.view_y - 8.0) / row_h).to_int()
          if idx >= 0 && idx < n {
            idx
          } else {
            -1
          }
        }
        if new_hover != hover.val {
          hover.val = new_hover
          ViewLike::schedule_paint(cv)
        }
      })
      ViewLike::on_mouse_leave(cv, fn(_e) {
        if hover.val != -1 {
          hover.val = -1
          ViewLike::schedule_paint(cv)
        }
      })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}

///|
/// 仪表盘（EP Gauge）：单值百分比环（135° 起 270° 扫，开口朝下）+ 中心
/// 大数字；值弧按 thresholds 阈值分段着色（升序的（阈值上限, 颜色）表，
/// 空表用主题主色）。数值插值平滑：目标值变化后经 16ms 定时器逐步逼近
/// （每帧补 25% 差值，非动画帧驱动），2Hz 更新无跳变。value 为 0..1
/// （超出钳制），Store 驱动。
pub fn gauge_t(
  value : Store[Double],
  width? : Double = 240.0,
  height? : Double = 170.0,
  thresholds? : Array[(Double, String)] = [],
) -> Node {
  {
    mount: fn(parent) {
      let disp = Ref(value.get().max(0.0).min(1.0))
      let running = Ref(false)
      let cv = themed_container(style=[("width", width), ("height", height)])
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        draw_gauge(p, b.width, b.height, disp.val, thresholds)
      })
      // 插值链:未到位就继续排下一帧;新目标值只改 target,不取消在途链
      fn step() -> Unit {
        let target = value.get().max(0.0).min(1.0)
        let d = target - disp.val
        if d.abs() < 0.002 {
          disp.val = target
          running.val = false
          ViewLike::schedule_paint(cv)
        } else {
          disp.val = disp.val + d * 0.25
          ViewLike::schedule_paint(cv)
          ignore(set_timeout(16, step))
        }
      }

      value.subscribe(fn(v) {
        let target = v.max(0.0).min(1.0)
        if (target - disp.val).abs() < 0.002 {
          disp.val = target
          ViewLike::schedule_paint(cv)
        } else if !running.val {
          running.val = true
          ignore(set_timeout(16, step))
        }
      })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}

///|
/// 散点图（EP Scatter）：x/y 点列（小方点，万级首绘 <30ms），双轴自适应
/// 刻度 + 网格；trend=true 时叠加最小二乘趋势线（danger 色）。框选缩放
/// 后置，未做。数据经 Store 驱动。
pub fn scatter_t(
  points : Store[Array[(Double, Double)]],
  width? : Double = 560.0,
  height? : Double = 320.0,
  trend? : Bool = false,
  dot? : Double = 3.0,
) -> Node {
  {
    mount: fn(parent) {
      let cv = themed_container(style=[("width", width), ("height", height)])
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        draw_scatter(p, b.width, b.height, points.get(), trend, dot)
      })
      points.subscribe(fn(_pts) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
