// 平行坐标图组件（ECharts Parallel 对标，纯 MoonBit 全自绘，Painter 承载）：
//   par_chart_t  平行坐标：N 条竖轴等距横排、每轴独立量程归一（缺省由
//                 该轴数据列推断）、每行数据一条折线穿越各轴（系列色
//                 alpha 混合，多行叠显密度）、轴名 + 量程(min/max)标签
//                 + 轴刻度小横线、单行高亮（不透明 + 各轴顶点圆点）
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （主题切换重绘跟随）；axes 与 rows 各经一个 Store 驱动，set 后只
// schedule_paint 画布，不重建视图树。系列色走 charts.mbt 的 series_color
// 四语义色循环。纯函数（列提取 / 量程推断与合成 / 归一 / 轴 x 分配 /
// 行折线顶点 / 布局几何）集中在文件头部，charts_parallel_wbtest.mbt
// 白盒覆盖。

///|
/// 轴线左右预留宽度：量程标签贴轴摆放，首末轴不出画布。
let par_pad_side : Double = 50.0

///|
/// 顶部预留高度：轴名一行。
let par_pad_top : Double = 28.0

///|
/// 底部预留高度。
let par_pad_bottom : Double = 12.0

///|
/// 轴名标签宽度（等距轴距不足时截断）。
let par_name_w : Double = 96.0

///|
/// 量程标签宽度（贴轴右对齐/左对齐的单值文本）。
let par_range_w : Double = 44.0

///|
/// 刻度小横线半长（轴线左右各探 4px）。
let par_tick_half : Double = 4.0

///|
/// 高亮行各轴顶点圆点边长。
let par_dot : Double = 4.0

///|
/// 数据行折线不透明度（alpha 十六进制两位）：多行同色系叠显密度，
/// 高亮行用不透明本色。
let par_line_alpha : String = "66"

// ---------------------------------------------------------------------------
// 纯函数层：列提取 / 量程推断与合成 / 归一 / 轴 x 分配 / 行折线顶点 /
// 布局几何（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 平行坐标轴（名称 + 可选量程）：一个竖轴。min/max 省略（None）时该轴
/// 量程由数据列推断；只给一端时另一端仍取数据列推断值。
pub(all) struct ParAxis {
  name : String
  min : Double?
  max : Double?
}

///|
/// 建平行坐标轴（min/max 省略即由数据推断）。
pub fn ParAxis::make(
  name : String,
  min? : Double? = None,
  max? : Double? = None,
) -> ParAxis {
  { name, min, max, }
}

///|
/// 取数据行的第 i 列（跨行收集；行短于 i+1 列的跳过该行）。i < 0 给空。
pub fn par_axis_column(rows : Array[Array[Double]], i : Int) -> Array[Double] {
  let out : Array[Double] = []
  if i < 0 {
    return out
  }
  for row in rows {
    if i < row.length() {
      out.push(row[i])
    }
  }
  out
}

///|
/// 单轴量程推断：列值 min..max（不加留白，端点即折线贴边）；空列给
/// (0, 1)；等值退化（min==max）以值为中心撑开（|值|<10 时至少 ±1）。
pub fn par_axis_range(values : Array[Double]) -> (Double, Double) {
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
    (0.0, 1.0)
  } else if hi - lo < 1.0e-12 {
    let pad = if lo.abs() < 10.0 { 1.0 } else { lo.abs() * 0.1 }
    (lo - pad, hi + pad)
  } else {
    (lo, hi)
  }
}

///|
/// 每轴有效量程（与 axes 同序）：显式 min/max 优先，缺端取该列推断值；
/// lo > hi 交换；合成后仍退化（两端同值）以 lo 为中心撑开。轴数 0 给空。
pub fn par_axis_ranges(
  axes : Array[ParAxis],
  rows : Array[Array[Double]],
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for i, ax in axes {
    let (dlo, dhi) = par_axis_range(par_axis_column(rows, i))
    let mut lo = match ax.min {
      Some(v) => v
      None => dlo
    }
    let mut hi = match ax.max {
      Some(v) => v
      None => dhi
    }
    if lo > hi {
      let t = lo
      lo = hi
      hi = t
    }
    if hi - lo < 1.0e-12 {
      let pad = if lo.abs() < 10.0 { 1.0 } else { lo.abs() * 0.1 }
      lo = lo - pad
      hi = hi + pad
    }
    out.push((lo, hi))
  }
  out
}

///|
/// 值 → 轴内分数 0..1（超出量程两端钳制；lo/hi 退化时取中点 0.5）。
pub fn par_norm(v : Double, lo : Double, hi : Double) -> Double {
  if hi - lo < 1.0e-12 {
    0.5
  } else {
    let f = (v - lo) / (hi - lo)
    if f < 0.0 {
      0.0
    } else if f > 1.0 {
      1.0
    } else {
      f
    }
  }
}

///|
/// 第 i 条轴的 x 像素：N 条竖轴等距横排，首轴贴 left、末轴贴 right
/// （与画布语义 0 指向右一致）；n <= 1 时取绘制区中点。
pub fn par_axis_x(i : Int, n : Int, left : Double, right : Double) -> Double {
  if n <= 1 {
    (left + right) / 2.0
  } else {
    left + i.to_double() / (n - 1).to_double() * (right - left)
  }
}

///|
/// 行折线顶点（画布坐标，轴数以 ranges 为准）：第 i 个顶点落在第 i 条
/// 轴的 x 上，y 由该轴量程把值映射到 [top, bottom]（量程上限贴顶）；
/// 行缺该维（行短于轴数）按中点 0.5 取值；行多出的维忽略。轴数 < 2 时
/// 只有一个顶点（绘制层画点不画线）。
pub fn par_row_vertices(
  row : Array[Double],
  ranges : Array[(Double, Double)],
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
) -> Array[(Double, Double)] {
  let n = ranges.length()
  let out : Array[(Double, Double)] = []
  for i in 0..<n {
    let v = if i < row.length() {
      row[i]
    } else {
      (ranges[i].0 + ranges[i].1) / 2.0
    }
    let (lo, hi) = ranges[i]
    let t = par_norm(v, lo, hi)
    out.push((par_axis_x(i, n, x0, x1), y1 - t * (y1 - y0)))
  }
  out
}

///|
/// 布局几何：返回绘制区 (x0, y0, x1, y1)（画布坐标）。左右各留 50px 给
/// 量程标签，顶部留 28px 给轴名；宽高不足时退化为空矩形（调用方判空）。
pub fn par_layout(w : Double, h : Double) -> (Double, Double, Double, Double) {
  let x0 = par_pad_side
  let y0 = par_pad_top
  let x1 = w - par_pad_side
  let y1 = h - par_pad_bottom
  (x0, y0, x1, y1)
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 空态提示（画布居中「暂无数据」）。
fn par_draw_empty(p : Painter, w : Double, h : Double) -> Unit {
  let at = AttributedText::new(
    "暂无数据",
    align=Center,
    valign=Center,
    wrap=false,
  )
  at.set_font(Font::new("Sans", 13.0))
  at.set_color(theme_text_secondary())
  let tw = at.get_bounds_for(400.0, 40.0).width
  p.draw_attributed_text(at, w / 2.0 - tw / 2.0, h / 2.0 - 10.0, tw + 4.0, 20.0)
}

///|
/// 单条折线描边（n 个顶点依次连线；少于 2 个顶点画一个点）。
fn par_stroke_polyline(
  p : Painter,
  pts : Array[(Double, Double)],
  color : String,
) -> Unit {
  if pts.length() == 0 {
    return
  }
  if pts.length() == 1 {
    let (px, py) = pts[0]
    p.set_fill_color(color)
    p.fill_rect(px - 1.0, py - 1.0, 2.0, 2.0)
    return
  }
  p.set_stroke_color(color)
  p.begin_path()
  p.move_to(pts[0].0, pts[0].1)
  for i in 1..<pts.length() {
    p.line_to(pts[i].0, pts[i].1)
  }
  p.stroke()
}

///|
/// 平行坐标绘制（画布坐标，axes/rows 已由调用方取出）：每轴一条竖线 +
/// 刻度小横线 + 顶部轴名 + 轴侧量程(min/max)标签（奇偶轴左右交替，避免
/// 相邻标签相压）；数据行按 ranges 逐轴归一化后连成折线，系列色 alpha
/// 混合（多行叠显密度）；highlight 行（>=0 且越界忽略）最后以不透明本色
/// 重描并在各轴顶点落圆点。轴数 0 或数据行 0 时画「暂无数据」。
fn par_draw_chart(
  p : Painter,
  w : Double,
  h : Double,
  axes : Array[ParAxis],
  rows : Array[Array[Double]],
  highlight : Int,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let n = axes.length()
  if n == 0 {
    par_draw_empty(p, w, h)
    return
  }
  let (x0, y0, x1, y1) = par_layout(w, h)
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let ranges = par_axis_ranges(axes, rows)
  // 轴层：竖线 + 刻度小横线 + 轴名 + 量程标签
  for i in 0..<n {
    let ax = par_axis_x(i, n, x0, x1)
    p.set_stroke_color(theme_border())
    p.begin_path()
    p.move_to(ax, y0)
    p.line_to(ax, y1)
    p.stroke()
    let (lo, hi) = ranges[i]
    p.begin_path()
    for t in nice_ticks(lo, hi, count=4) {
      let ty = y1 - par_norm(t, lo, hi) * (y1 - y0)
      if ty < y0 - 0.5 || ty > y1 + 0.5 {
        continue
      }
      p.move_to(ax - par_tick_half, ty)
      p.line_to(ax + par_tick_half, ty)
    }
    p.stroke()
    // 轴名：轴顶上方居中
    p.draw_text(
      truncate_to(axes[i].name, par_name_w),
      ax - par_name_w / 2.0,
      y0 - 24.0,
      par_name_w,
      16.0,
      align=Center,
      valign=Center,
      color=theme_text_secondary(),
      wrap=false,
    )
    // 量程标签：max 贴轴顶、min 贴轴底，奇偶轴左右交替
    let right_side = i % 2 == 1
    let (align, lx) = if right_side {
      (Start, ax + 6.0)
    } else {
      (End, ax - 6.0 - par_range_w)
    }
    p.draw_text(
      fmt_axis(hi),
      lx,
      y0 + 2.0,
      par_range_w,
      16.0,
      align~,
      valign=Center,
      color=theme_text_secondary(),
      wrap=false,
    )
    p.draw_text(
      fmt_axis(lo),
      lx,
      y1 - 18.0,
      par_range_w,
      16.0,
      align~,
      valign=Center,
      color=theme_text_secondary(),
      wrap=false,
    )
  }
  if rows.length() == 0 {
    par_draw_empty(p, w, h)
    return
  }
  // 数据行：全部行 alpha 混合先画，高亮行最后不透明重描 + 顶点圆点
  for ri, row in rows {
    if ri == highlight {
      continue
    }
    let pts = par_row_vertices(row, ranges, x0, x1, y0, y1)
    par_stroke_polyline(p, pts, with_alpha(series_color(ri), par_line_alpha))
  }
  if highlight >= 0 && highlight < rows.length() {
    let color = series_color(highlight)
    let pts = par_row_vertices(rows[highlight], ranges, x0, x1, y0, y1)
    par_stroke_polyline(p, pts, color)
    p.set_fill_color(color)
    for pt in pts {
      p.fill_rect(pt.0 - par_dot / 2.0, pt.1 - par_dot / 2.0, par_dot, par_dot)
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 平行坐标图（ECharts Parallel 对标）：N 条竖轴等距横排，每轴独立量程
/// 归一（ParAxis 的 min/max 省略时由该轴数据列推断，只给一端时另一端
/// 仍取推断值）；每行数据一条折线穿越各轴，系列色 alpha 混合、多行叠显
/// 密度；每轴顶部轴名、轴侧 min/max 量程标签、轴身刻度小横线；
/// highlight 给行索引（>=0）时该行不透明重描并在各轴顶点落圆点（越界
/// 忽略）。axes 与 rows 各经一个 Store 驱动，set 后只重绘画布不重建视图
/// 树；主题切换现取色自动跟随。fill=true 不设固定宽度，横向铺满父容器
/// （跟随窗口伸缩）。
pub fn par_chart_t(
  axes : Store[Array[ParAxis]],
  rows : Store[Array[Array[Double]]],
  highlight? : Int = -1,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  {
    mount: fn(parent) {
      let size_style : Array[(String, &StyVal)] = if fill {
        [("height", 320.0)]
      } else {
        [("width", 640.0), ("height", 320.0)]
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
        par_draw_chart(p, b.width, b.height, axes.get(), rows.get(), highlight)
      })
      axes.subscribe(fn(_a) { ViewLike::schedule_paint(cv) })
      rows.subscribe(fn(_r) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
