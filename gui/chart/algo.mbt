// 图表层（新栈）：共享算法层 + 五种通用图。
//
// 分层与旧链路（master `yue/charts`）一致：**纯函数与绘制分开**——数据窗口、
// 坐标换算、刻度算法、扇区角度、回归这些不依赖任何平台，白盒直接钉住；绘制只
// 读这些结果。组件一律返回 `@core.Node`（声明式），数据经 `@core.Store` 驱动：
// 换数据只重绘画布，不重建控件树。
//
// 与 master 的两处形态差（记档）：CSS 式 `style` 通道不做（覆盖走类型化参数与
// `handle`）；文本绘制走 `text`（旧契约的 `Painter::draw_text` 在本栈不存在）。

///|
/// 圆周率（core 的 pi 在 deprecated 模块，勿用）。
pub let pi : Double = 3.141592653589793

///|
/// 整圆周（2π）。
pub let tau : Double = 6.283185307179586

///|
/// 折线序列：名称 + 定长滚动窗口（points 旧→新排列）。推点用 `win_push` 换新窗口。
pub(all) struct LineSeries {
  name : String
  max_points : Int
  points : Array[Double]
}

///|
/// 建序列（`max_points` 为窗口容量，超出丢最旧）。
pub fn LineSeries::make(name : String, max_points? : Int = 100) -> LineSeries {
  { name, max_points, points: [], }
}

///|
/// 换上一份点列（测试与一次性灌数据用；高频推点仍走 `win_push`）。
pub fn LineSeries::with_points(self : LineSeries, pts : Array[Double]) -> LineSeries {
  { ..self, points: pts, }
}

///|
/// 滚动窗口推点：返回新窗口（旧→新），超出 `max_points` 丢最旧；入参窗口不变。
/// `max_points <= 0` 时只保留最新一点。
pub fn win_push(win : Array[Double], max_points : Int, v : Double) -> Array[Double] {
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
/// 向多序列 Store 的第 i 个序列推点（窗口超限自动丢最旧），整表 set 一次触发
/// 订阅者重绘；`i` 越界时无操作。
pub fn series_push(series : @core.Store[Array[LineSeries]], i : Int, v : Double) -> Unit {
  let cur = series.get()
  if i < 0 || i >= cur.length() {
    return
  }
  let out = cur.copy()
  let s = out[i]
  out[i] = { ..s, points: win_push(s.points, s.max_points, v) }
  series.set_always(out) // 折线窗口整体替换:数据点无 Eq,去重代价高于收益
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
/// 数值 → y 像素（`lo`/`hi` 为值域，`top`/`bottom` 为画布上下边；值域退化时取中点）。
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
pub fn nice_step(raw : Double) -> Double {
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
/// 带单位缩写的轴标签：值除以单位后最多一位小数、去尾零。
pub fn fmt_axis_unit(v : Double, unit : Double, suffix : String) -> String {
  let a = if v < 0.0 { -v } else { v }
  let scaled = (a / unit * 10.0).round().to_int()
  let ip = scaled / 10
  let frac = scaled % 10
  let body = if frac == 0 { "\{ip}\{suffix}" } else { "\{ip}.\{frac}\{suffix}" }
  if v < 0.0 && scaled != 0 {
    "-\{body}"
  } else {
    body
  }
}

///|
/// 轴标签格式：多级单位动态换挡（≥1e4 用 k、≥1e6 用 M、≥1e9 用 G），数字保持
/// 短，不因标签过宽被排版换行竖排；以下维持最多两位小数、去尾零。
pub fn fmt_axis(v : Double) -> String {
  let a = if v < 0.0 { -v } else { v }
  if a >= 1.0e9 {
    return fmt_axis_unit(v, 1.0e9, "G")
  }
  if a >= 1.0e6 {
    return fmt_axis_unit(v, 1.0e6, "M")
  }
  if a >= 1.0e4 {
    return fmt_axis_unit(v, 1.0e3, "k")
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
/// 柱状图值域：含 0 与全部值，两端 6% 留白；空数据给 (0, 1)，全零退化给 (-1, 1)。
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
/// 第 i 根的矩形（x, w）：n 根均分 [left, right]，根间距 gap，宽不足 1px 时
/// 钳到 1（200 类目窄条仍可见）。
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
/// 柱状图 hover 命中：返回指针下的类目索引，界外/越界为 -1。与绘制两形态共用
/// 同一套几何——纵向柱沿 x 分槽（只看横坐标），横向条沿 y 分行（只看纵坐标）；
/// 绘制与命中必须同源，否则高亮与柱子错位。
pub fn bar_hit(
  horizontal : Bool,
  n : Int,
  w : Double,
  h : Double,
  px : Double,
  py : Double,
) -> Int {
  if n <= 0 {
    return -1
  }
  let idx = if horizontal {
    let pad_t = 12.0
    let pad_b = 24.0
    if py < pad_t || py > h - pad_b {
      return -1
    }
    let slot = (h - pad_t - pad_b) / n.to_double()
    ((py - pad_t) / slot).to_int()
  } else {
    let pad_l = 46.0
    let pad_r = 12.0
    if px < pad_l || px > w - pad_r {
      return -1
    }
    let slot = (w - pad_l - pad_r) / n.to_double()
    ((px - pad_l) / slot).to_int()
  }
  if idx < 0 || idx >= n {
    -1
  } else {
    idx
  }
}

///|
/// 环形图第 i 扇区的起止弧度（12 点方向起，顺时针；0 指向右）。只累计正值；
/// 总和 <= 0 或 i 越界返回 None。
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
/// 仪表盘弧度映射：`frac` 钳到 0..1 后线性映射到 [start, start+sweep]
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
/// 最小二乘趋势线：返回 (斜率 k, 截距 b) 使 y = k*x + b；点数 < 2 或 x 全同
/// （分母为 0）时 None。
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

///|
/// 散点值域：x/y 各自 min/max + 5% 留白；空数据给 (0,1)×(0,1)；单轴等值退化时
/// 该轴 ±1 撑开。
pub fn point_range(
  points : Array[(Double, Double)],
) -> ((Double, Double), (Double, Double)) {
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

///|
/// 柱状图项（类目标签 + 数值，可为负）。
pub(all) struct BarItem {
  label : String
  value : Double
}

///|
pub fn BarItem::make(label : String, value : Double) -> BarItem {
  { label, value, }
}

///|
/// 环形图项（标签 + 占比值）。
pub(all) struct DonutSlice {
  label : String
  value : Double
}

///|
pub fn DonutSlice::make(label : String, value : Double) -> DonutSlice {
  { label, value, }
}

///|
/// 给 `#RRGGBB` 补两位十六进制 alpha（本栈色串解析吃 CSS 的 `#RRGGBBAA`）。
pub fn with_alpha(hex : String, aa : String) -> String {
  if hex.length() == 7 {
    hex + aa
  } else {
    hex
  }
}

///|
/// 文本按可用宽截断（等宽估算：12px 每字符约 7px），超出加省略号。
pub fn truncate_to(text : String, avail : Double) -> String {
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
  for ch in text.to_array() {
    if i >= max_chars - 1 {
      break
    }
    out.write_string(ch.to_string())
    i = i + 1
  }
  out.write_string("…")
  out.to_string()
}
