// 箱线图（charts.mbt 图表族成员，纯 MoonBit 自绘，Painter 承载）：
//   boxp_summary  五数概括（min/Q1/中位/Q3/max，四分位线性插值），
//                  按 1.5×IQR 规则给出须端与离群点
//   boxplot_t     多组并列箱线图组件：箱体（Q1-Q3）+ 中位线 + 须线端帽
//                  + 离群点圆点 + 组标签；y 自适应（含离群点）或手动范围；
//                  数据经 Store 驱动，set 后只 schedule_paint 画布，
//                  不重建视图树。
// 网格/刻度/坐标换算/槽位复用 charts.mbt 的纯函数；五数与须端/离群
// 判定集中在本文 pure 函数层，charts_boxplot_wbtest.mbt 白盒覆盖。

///|
/// 箱线图五数概括：min/Q1/中位/Q3/max（四分位线性插值）+ 按 1.5×IQR
/// 规则得出的须端（whisker_lo/whisker_hi，取围栏内最远样本值）与
/// 离群点表（升序）。
pub(all) struct BoxSummary {
  min : Double
  q1 : Double
  median : Double
  q3 : Double
  max : Double
  whisker_lo : Double
  whisker_hi : Double
  outliers : Array[Double]
}

///|
/// 建五数概括（通常由 [boxp_summary] 计算得出，手工构造用于测试或覆盖）。
pub fn BoxSummary::make(
  min : Double,
  q1 : Double,
  median : Double,
  q3 : Double,
  max : Double,
  whisker_lo : Double,
  whisker_hi : Double,
  outliers : Array[Double],
) -> BoxSummary {
  { min, q1, median, q3, max, whisker_lo, whisker_hi, outliers, }
}

///|
/// 升序数组的 q 分位（0..1，线性插值）：位置 (n-1)*q，落在相邻两样本
/// 之间按小数部分加权；q 钳到 0..1；空数组给 0.0，单样本给该值。
pub fn boxp_quantile(sorted : Array[Double], q : Double) -> Double {
  let n = sorted.length()
  if n == 0 {
    return 0.0
  }
  if n == 1 {
    return sorted[0]
  }
  let qq = if q < 0.0 {
    0.0
  } else if q > 1.0 {
    1.0
  } else {
    q
  }
  let pos = qq * (n - 1).to_double()
  if pos <= 0.0 {
    return sorted[0]
  }
  if pos >= (n - 1).to_double() {
    return sorted[n - 1]
  }
  let i0 = pos.floor().to_int()
  sorted[i0] + (sorted[i0 + 1] - sorted[i0]) * (pos - i0.to_double())
}

///|
/// 五数概括 + 须端与离群点：内部升序排序（入参数组不变）；围栏取
/// Q1-1.5×IQR 与 Q3+1.5×IQR，须端为围栏内最远样本，围栏外样本列入
/// 离群点（升序）；空数组给全零概括（离群点空表）。
pub fn boxp_summary(values : Array[Double]) -> BoxSummary {
  let sorted = values.copy()
  sorted.mut_view().sort_by(fn(a, b) {
    if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  let n = sorted.length()
  if n == 0 {
    return {
      min: 0.0,
      q1: 0.0,
      median: 0.0,
      q3: 0.0,
      max: 0.0,
      whisker_lo: 0.0,
      whisker_hi: 0.0,
      outliers: [],
    }
  }
  let q1 = boxp_quantile(sorted, 0.25)
  let med = boxp_quantile(sorted, 0.5)
  let q3 = boxp_quantile(sorted, 0.75)
  let iqr = q3 - q1
  let fence_lo = q1 - 1.5 * iqr
  let fence_hi = q3 + 1.5 * iqr
  // 须端：升序扫描，首个 >= 下围栏 / 末个 <= 上围栏；全样本越界时
  // 兜底到 Q1/Q3（正常数据不会走到）
  let mut wlo = q1
  let mut whi = q3
  let mut wlo_set = false
  let outliers : Array[Double] = []
  for v in sorted {
    if !wlo_set && v >= fence_lo {
      wlo = v
      wlo_set = true
    }
    if v <= fence_hi {
      whi = v
    }
    if v < fence_lo || v > fence_hi {
      outliers.push(v)
    }
  }
  {
    min: sorted[0],
    q1,
    median: med,
    q3,
    max: sorted[n - 1],
    whisker_lo: wlo,
    whisker_hi: whi,
    outliers,
  }
}

///|
/// 箱线图 y 轴自适应范围：全部组样本的 min/max + 8% 留白（离群点计入，
/// 圆点不裁剪）；空数据给 (0, 1)；等值退化以值为中心撑开（|值|<10 时
/// 至少 ±1）。
pub fn boxp_range(
  groups : Array[(String, Array[Double])],
) -> (Double, Double) {
  let mut lo = 0.0
  let mut hi = 0.0
  let mut any = false
  for g in groups {
    for v in g.1 {
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

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 箱线图绘制（画布坐标，组数据已由调用方取出）：横向网格 + 左侧刻度；
/// 每组箱体（Q1-Q3，序列色半透明填充 + 描边）、中位线（3px 实心矩形）、
/// 须线与端帽（帽宽 60% 箱宽）、离群点圆点（danger 色，越出绘制区跳过）；
/// 组标签居中贴底轴，槽宽不足 26px 时自动抽稀截断；空组只画标签；
/// 全空画「暂无数据」。
fn draw_boxplot(
  p : Painter,
  w : Double,
  h : Double,
  groups : Array[(String, Array[Double])],
  y_range : (Double, Double)?,
) -> Unit {
  let n = groups.length()
  if n == 0 || w <= 0.0 || h <= 0.0 {
    return
  }
  let pad_l = 46.0
  let pad_r = 14.0
  let pad_t = 14.0
  let pad_b = 24.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let (lo, hi) = match y_range {
    Some((a, b)) => if a <= b { (a, b) } else { (b, a) }
    None => boxp_range(groups)
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
    label_w=pad_l - 12.0,
  )
  // 全空提示
  let mut any = false
  for g in groups {
    if g.1.length() > 0 {
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
  let slot = (x1 - x0) / n.to_double()
  // 组标签抽稀：槽宽不足 26px 时每隔 step 个画一个
  let step = if slot >= 26.0 {
    1
  } else {
    (26.0 / slot).ceil().to_int().max(1)
  }
  for i, g in groups {
    let (label, values) = g
    if i % step == 0 {
      p.draw_text(
        truncate_to(label, slot),
        x0 + slot * i.to_double(),
        y1 + 3.0,
        slot,
        16.0,
        align=Center,
        valign=Center,
        color=theme_text_secondary(),
        wrap=false,
      )
    }
    if values.length() == 0 {
      continue
    }
    let s = boxp_summary(values)
    let (bx, bw) = bar_slot(i, n, x0, x1, gap=slot * 0.5)
    let cx = bx + bw / 2.0
    let color = series_color(i)
    // 箱体（Q1-Q3）
    let yq1 = map_y(s.q1, lo, hi, y0, y1)
    let yq3 = map_y(s.q3, lo, hi, y0, y1)
    let box_h = (yq1 - yq3).max(1.0)
    p.set_fill_color(with_alpha(color, "33"))
    p.fill_rect(bx, yq3, bw, box_h)
    p.set_stroke_color(color)
    p.stroke_rect(bx + 0.5, yq3 + 0.5, bw - 1.0, box_h - 1.0)
    // 中位线（3px 实心）
    let ymed = map_y(s.median, lo, hi, y0, y1)
    p.set_fill_color(color)
    p.fill_rect(bx, ymed - 1.5, bw, 3.0)
    // 须线 + 端帽
    let ywl = map_y(s.whisker_lo, lo, hi, y0, y1)
    let ywh = map_y(s.whisker_hi, lo, hi, y0, y1)
    let cap = bw * 0.6
    p.set_stroke_color(color)
    p.begin_path()
    p.move_to(cx, ywh)
    p.line_to(cx, yq3)
    p.move_to(cx, yq1)
    p.line_to(cx, ywl)
    p.move_to(cx - cap / 2.0, ywh)
    p.line_to(cx + cap / 2.0, ywh)
    p.move_to(cx - cap / 2.0, ywl)
    p.line_to(cx + cap / 2.0, ywl)
    p.stroke()
    // 离群点圆点（越出绘制区跳过）
    if s.outliers.length() > 0 {
      p.set_fill_color(theme_danger())
      for v in s.outliers {
        let oy = map_y(v, lo, hi, y0, y1)
        if oy < y0 - 2.5 || oy > y1 + 2.5 {
          continue
        }
        p.begin_path()
        p.arc(cx, oy, 2.5, 0.0, tau)
        p.fill()
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 箱线图（多组并列）：每组经 [boxp_summary] 取五数，绘箱体（Q1-Q3，
/// 序列色循环）、中位线、须线端帽与离群点圆点（danger 色）；y 自适应
/// （含离群点 + 8% 留白）或经 y_range 手动指定；组标签居中贴底轴，
/// 过密时自动抽稀截断。数据经 Store 驱动：set 后只重绘画布不重建
/// 视图树；主题切换现取色自动跟随。fill=true 不设固定宽度，横向铺满
/// 父容器（跟随窗口伸缩）。
pub fn boxplot_t(
  groups : Store[Array[(String, Array[Double])]],
  y_range? : (Double, Double)? = None,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) { },
) -> Node {
  {
    mount: fn(parent) {
      let size_style : Array[(String, &StyVal)] = if fill {
        [("height", 280.0)]
      } else {
        [("width", 560.0), ("height", 280.0)]
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
        draw_boxplot(p, b.width, b.height, groups.get(), y_range)
      })
      groups.subscribe(fn(_g) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
