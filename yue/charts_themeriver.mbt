// 主题河流图（EP ThemeRiver 对标，纯 MoonBit 全自绘，Painer 承载）：
//   trv_chart_t 堆叠流图——等间隔时间轴上逐层堆叠成河流，
//                baseline 支持 TrvSym（围绕水平中轴对称，经典 wiggle）
//                与 TrvZero（底部堆叠）；每层上下缘平滑曲线（Catmull-Rom
//                转三次贝塞尔，经 Painter::bezier_curve_to）；层色走
//                charts.mbt 的 series_color 四语义色循环；右侧图例标注
//                （色块 + 层名 + 序列总量，照抄 donut 图例两段式）。
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （主题切换重绘跟随）；names 与 values 各经一个 Store 驱动，set 后
// 只 schedule_paint 画布，不重建视图树。
// 纯函数（时间轴长度/取值/列总计/堆叠偏移/值域/样条控制点/层带像素/
// 序列总量）集中在文件头部，charts_themeriver_wbtest.mbt 白盒覆盖。

///|
/// 图例列预留宽度（右侧色块 + 层名 + 序列总量）：数值盒占 110px，
/// 层名截断宽度按「数值盒左缘 − 层名起点 − 留缝」算，两段不重叠
/// （口径同 charts.mbt 的 donut 图例给数值预留宽度）。
let trv_legend_w : Double = 240.0

// ---------------------------------------------------------------------------
// 纯函数层：时间轴 / 取值 / 堆叠偏移 / 值域 / 样条 / 层带（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 堆叠基线：TrvZero 底部堆叠（各时间点自 0 起逐层向上累加）；
/// TrvSym 围绕水平中轴对称（各时间点堆叠总量对半，经典 wiggle
/// 中枢形态）。
pub(all) enum TrvBaseline {
  TrvZero
  TrvSym
}

///|
/// 时间轴长度：全体序列取值序列的最大长度（等间隔时间轴按索引对齐，
/// 短序列缺失位按 0 计）。
pub fn trv_axis_len(values : Array[Array[Double]]) -> Int {
  let mut n = 0
  for row in values {
    if row.length() > n {
      n = row.length()
    }
  }
  n
}

///|
/// 第 j 序列第 t 个时间点的取值（负值按 0、越界按 0）。
pub fn trv_row_at(values : Array[Array[Double]], j : Int, t : Int) -> Double {
  if j < 0 || j >= values.length() {
    return 0.0
  }
  let row = values[j]
  if t < 0 || t >= row.length() {
    return 0.0
  }
  let v = row[t]
  if v > 0.0 {
    v
  } else {
    0.0
  }
}

///|
/// 第 t 个时间点的列总计（全部序列该列取值之和，负值已按 0）。
pub fn trv_total_at(values : Array[Array[Double]], t : Int) -> Double {
  let mut total = 0.0
  for j in 0..<values.length() {
    total = total + trv_row_at(values, j, t)
  }
  total
}

///|
/// 堆叠偏移表：返回与 values 同形的双层数组，offsets[j][t] 为第 j 层
/// 第 t 点的下缘值（层厚即 trv_row_at）。TrvZero 自 0 起逐层累加；
/// TrvSym 先把该列总计对半下移，使整列围绕 0（水平中轴）对称——
/// 首层下缘 = -总计/2，末层上缘 = +总计/2。空表或全零列表给全零偏移。
pub fn trv_stack_offsets(
  values : Array[Array[Double]],
  baseline : TrvBaseline,
) -> Array[Array[Double]] {
  let n = trv_axis_len(values)
  let out : Array[Array[Double]] = []
  for _row in values {
    out.push(Array::make(n, 0.0))
  }
  let centered = match baseline {
    TrvZero => false
    TrvSym => true
  }
  for t in 0..<n {
    let base = if centered { 0.0 - trv_total_at(values, t) / 2.0 } else { 0.0 }
    let mut acc = base
    for j in 0..<values.length() {
      out[j][t] = acc
      acc = acc + trv_row_at(values, j, t)
    }
  }
  out
}

///|
/// 河流值域（值 lo..hi → 画布 y0..y1）：取全部层各点上下缘的
/// min/max 加 4% 留白；空数据给 (0, 1)，单点（min==max）撑开 ±1。
/// TrvSym 模式下 lo/hi 天然对偶（-m/2 .. +m/2）。
pub fn trv_range(
  values : Array[Array[Double]],
  baseline : TrvBaseline,
) -> (Double, Double) {
  let mut lo = 0.0
  let mut hi = 0.0
  let mut any = false
  let offsets = trv_stack_offsets(values, baseline)
  for j, _r in values {
    for t in 0..<trv_axis_len(values) {
      let b = offsets[j][t]
      let top = b + trv_row_at(values, j, t)
      if !any {
        lo = b
        hi = top
        any = true
      } else {
        if b < lo {
          lo = b
        }
        if top > hi {
          hi = top
        }
      }
    }
  }
  if !any {
    (0.0, 1.0)
  } else if hi - lo < 1.0e-12 {
    let pad = if lo.abs() < 1.0e-12 { 1.0 } else { lo.abs() * 0.1 }
    (lo - pad, hi + pad)
  } else {
    let pad = (hi - lo) * 0.04
    (lo - pad, hi + pad)
  }
}

///|
/// 样条控制点（Catmull-Rom 转三次贝塞尔）：对折线 pts 逐段求一段
/// 贝塞尔的控制点 (cp1, cp2)，pts[i] → pts[i+1] 一段，返回长度
/// = pts.length() - 1（点数 < 2 给空表）。张力 tension: 1.0 为标准
/// Catmull-Rom，0.0 退化为直线；首末段以端点外推补点（重复端点），
/// 样条因此过全部原始点。
pub fn trv_spline_ctrl(
  pts : Array[(Double, Double)],
  tension? : Double = 1.0,
) -> Array[((Double, Double), (Double, Double))] {
  let out : Array[((Double, Double), (Double, Double))] = []
  let n = pts.length()
  if n < 2 {
    return out
  }
  for i in 0..<(n - 1) {
    let p1 = pts[i]
    let p2 = pts[i + 1]
    let prev = if i - 1 < 0 { pts[0] } else { pts[i - 1] }
    let next = if i + 2 > n - 1 { pts[n - 1] } else { pts[i + 2] }
    let cp1 = (
      p1.0 + (p2.0 - prev.0) / 6.0 * tension,
      p1.1 + (p2.1 - prev.1) / 6.0 * tension,
    )
    let cp2 = (
      p2.0 - (next.0 - p1.0) / 6.0 * tension,
      p2.1 - (next.1 - p1.1) / 6.0 * tension,
    )
    out.push((cp1, cp2))
  }
  out
}

///|
/// 层带像素坐标：第 j 层第 t 点的（上缘 x, 上缘 y, 下缘 x, 下缘 y），
/// 已按值域 lo..hi 与画布区 x0..x1/y0..y1 映射（上缘 y 小于下缘 y）。
/// 层带互不重叠且按层序在纵向上逐层拼接——j+1 层下缘即 j 层下缘加厚。
pub fn trv_layer_band(
  offsets : Array[Array[Double]],
  values : Array[Array[Double]],
  lo : Double,
  hi : Double,
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
  j : Int,
  t : Int,
) -> (Double, Double, Double, Double) {
  let n = trv_axis_len(values)
  let x = map_idx(t, n, x0, x1)
  let b = offsets[j][t]
  let top = b + trv_row_at(values, j, t)
  (x, map_y(top, lo, hi, y0, y1), x, map_y(b, lo, hi, y0, y1))
}

///|
/// 第 j 序列总量（全时间点取值之和，负值按 0）：图例右段数值标注口径。
pub fn trv_series_total(values : Array[Array[Double]], j : Int) -> Double {
  let mut total = 0.0
  if j < 0 || j >= values.length() {
    return 0.0
  }
  for t in 0..<values[j].length() {
    total = total + trv_row_at(values, j, t)
  }
  total
}

///|
/// 层名（越界兜底 "层\{n}"）：图例左段标注口径。
pub fn trv_series_name(names : Array[String], j : Int) -> String {
  if j < 0 || j >= names.length() {
    "\{j}"
  } else {
    names[j]
  }
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 沿平滑折线走贝塞尔（首点 move_to，其余按 trv_spline_ctrl 的控制点
/// 走 bezier_curve_to）；点数 < 2 无操作。
fn trv_path_spline(
  p : Painter,
  pts : Array[(Double, Double)],
  tension : Double,
) -> Unit {
  let n = pts.length()
  if n < 2 {
    return
  }
  p.move_to(pts[0].0, pts[0].1)
  for i, (cp1, cp2) in trv_spline_ctrl(pts, tension~) {
    let pe = pts[i + 1]
    p.bezier_curve_to(cp1.0, cp1.1, cp2.0, cp2.1, pe.0, pe.1)
  }
}

///|
/// 河流图绘制（画布坐标，数据已由调用方取出）：横轴时间索引等距布点、
/// 左侧值域网格；逐层填充（上缘 → 右端 → 下缘回程闭合）并描上缘平滑
/// 曲线；TrvSym 模式加画水平中轴线；右侧图例列（色块 + 层名 + 序列
/// 总量，照抄 donut 图例两段式）。序列数 0 或时间轴长度 0 画「暂无
/// 数据」占位。
fn trv_draw(
  p : Painter,
  w : Double,
  h : Double,
  names : Array[String],
  values : Array[Array[Double]],
  baseline : TrvBaseline,
  tension? : Double = 1.0,
  show_legend? : Bool = true,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let pad_l = 46.0
  let pad_r = if show_legend { trv_legend_w + 12.0 } else { 12.0 }
  let pad_t = 12.0
  let pad_b = 20.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let n = trv_axis_len(values)
  let m = values.length()
  if m == 0 || n == 0 {
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
  let (lo, hi) = trv_range(values, baseline)
  draw_hgrid(
    p,
    x0,
    y0,
    x1,
    y1,
    lo,
    hi,
    nice_ticks(lo, hi, count=4),
    label_w=pad_l - 12.0,
  )
  let offsets = trv_stack_offsets(values, baseline)
  // 层带填充 + 上缘描边（逐层叠画，后层覆盖前层上缘缝隙）
  p.save()
  p.clip_rect(x0, y0, x1 - x0, y1 - y0)
  for j in 0..<m {
    let color = series_color(j)
    let top_pts : Array[(Double, Double)] = []
    let bot_pts : Array[(Double, Double)] = []
    for t in 0..<n {
      let (tx, ty, bx, by) = trv_layer_band(
        offsets, values, lo, hi, x0, x1, y0, y1, j, t,
      )
      top_pts.push((tx, ty))
      bot_pts.push((bx, by))
    }
    // 下缘回程点序（右 → 左）
    let back : Array[(Double, Double)] = []
    for t in (n - 1)..<=0 {
      back.push(bot_pts[t])
    }
    p.set_fill_color(color)
    p.begin_path()
    trv_path_spline(p, top_pts, tension)
    for pt in back {
      p.line_to(pt.0, pt.1)
    }
    p.close_path()
    p.fill()
    // 上缘平滑曲线（本层上缘 = 上一层下缘，叠画后只见轮廓线）
    p.set_stroke_color(color)
    p.begin_path()
    trv_path_spline(p, top_pts, tension)
    p.stroke()
  }
  p.restore()
  // TrvSym 中轴线（过 0 值那条网格横线）
  match baseline {
    TrvZero => ()
    TrvSym => {
      let yc = map_y(0.0, lo, hi, y0, y1)
      if yc >= y0 - 0.5 && yc <= y1 + 0.5 {
        p.set_stroke_color(theme_text_secondary())
        p.begin_path()
        p.move_to(x0, yc)
        p.line_to(x1, yc)
        p.stroke()
      }
    }
  }
  // 图例（右列）：色块 + 层名 + 序列总量（donut 两段式）
  if show_legend {
    let legend_x = x1 + 20.0
    if legend_x + 60.0 < w {
      let row_h = ((h - 16.0) / m.to_double()).min(24.0).max(14.0)
      // 层名盒右缘让出数值盒（w-118 起 110px 宽）加 4px 缝，不重叠
      let name_w = ((w - 118.0 - 4.0) - (legend_x + 16.0)).max(20.0)
      for j in 0..<m {
        let ry = 8.0 + row_h * j.to_double()
        if ry + row_h > h - 4.0 {
          break
        }
        p.set_fill_color(series_color(j))
        p.fill_rect(legend_x, ry + (row_h - 10.0) / 2.0, 10.0, 10.0)
        p.draw_text(
          truncate_to(trv_series_name(names, j), name_w),
          legend_x + 16.0,
          ry,
          name_w,
          row_h,
          align=Start,
          valign=Center,
          color=theme_text_regular(),
        )
        p.draw_text(
          fmt_axis(trv_series_total(values, j)),
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
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 主题河流图（EP ThemeRiver）：等间隔时间轴上把多序列堆叠成河流，
/// baseline 选 TrvZero（底部堆叠，自 0 起逐层累加）或 TrvSym（围绕
/// 水平中轴对称，经典 wiggle 中枢）；每层上下缘走 Catmull-Rom 转
/// 三次贝塞尔的平滑曲线（tension=1 标准、0 退折线）；层色取主题四
/// 语义色循环；右侧图例标层名 + 序列总量（show_legend=false 关闭）。
/// names 与 values 同序（names[i] ↔ values[i]），值序列按时间索引等距
/// 对齐，负值按 0；两者各经一个 Store 驱动，set 后只重绘画布不重建
/// 视图树；主题切换现取色自动跟随。fill=true 不设固定宽度，横向铺满
/// 父容器（跟随窗口伸缩）。
pub fn trv_chart_t(
  names : Store[Array[String]],
  values : Store[Array[Array[Double]]],
  baseline? : TrvBaseline = TrvZero,
  tension? : Double = 1.0,
  show_legend? : Bool = true,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  {
    mount: fn(parent) {
      let size_style : Array[(String, &StyVal)] = if fill {
        [("height", 320.0)]
      } else {
        [("width", 560.0), ("height", 320.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = themed_container(style=size_style)
      handle(cv)
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        trv_draw(
          p,
          b.width,
          b.height,
          names.get(),
          values.get(),
          baseline,
          tension~,
          show_legend~,
        )
      })
      names.subscribe(fn(_n) { ViewLike::schedule_paint(cv) })
      values.subscribe(fn(_v) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
