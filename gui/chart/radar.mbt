// 雷达图（新栈，与 master 同源平移）：N 边形同心网格（默认 4 层，含轴线
// 与维度标签）、每系列一个半透明填充多边形 + 描边（多系列叠加）、右侧
// 图例列（色块 + 系列名）。indicators 与 series 各经一个 Store 驱动，
// set 后只重绘画布，不重建控件树。纯函数（顶点角度 / 多边形顶点 /
// 量程归一 / 值到半径映射 / 布局几何）集中在文件头部，
// radar_wbtest.mbt 白盒覆盖。

///|
/// 图例列预留宽度（右侧色块 + 系列名）。
let radar_legend_w : Double = 84.0

// ---------------------------------------------------------------------------
// 纯函数层：顶点角度 / 多边形顶点 / 量程归一 / 半径映射 / 布局几何
// （白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 雷达图维度（名称 + 最大值）：一个轴。系列各维取值 0..max 映射到
/// 0..满半径；max <= 0 视为量程无效，该轴取值一律折到中心。
pub(all) struct RadarIndicator {
  name : String
  max : Double
}

///|
/// 建雷达图维度。
pub fn RadarIndicator::make(name : String, max : Double) -> RadarIndicator {
  { name, max, }
}

///|
/// 雷达图系列：名称 + 各维度取值（与 indicators 同序，0..max）。
pub(all) struct RadarSeries {
  name : String
  values : Array[Double]
}

///|
/// 建雷达图系列。
pub fn RadarSeries::make(name : String, values : Array[Double]) -> RadarSeries {
  { name, values, }
}

///|
/// 维度索引 → 轴角（弧度）：顶点 0 在 12 点方向，顺时针均布（画布语义
/// 0 指向右）。n <= 0 一律返回 12 点方向。
pub fn radar_axis_angle(i : Int, n : Int) -> Double {
  if n <= 0 {
    -pi / 2.0
  } else {
    -pi / 2.0 + tau * i.to_double() / n.to_double()
  }
}

///|
/// N 边形网格顶点坐标（顶点 0 在 12 点方向，顺时针）。n <= 0 或 r < 0
/// 返回空。
pub fn radar_polygon(
  cx : Double,
  cy : Double,
  r : Double,
  n : Int,
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  if n <= 0 || r < 0.0 {
    return out
  }
  for i in 0..<n {
    let a = radar_axis_angle(i, n)
    out.push((cx + r * @math.cos(a), cy + r * @math.sin(a)))
  }
  out
}

///|
/// 量程归一：值 v 按维度量程 max 折算成 0..1（超出两端钳制）；max <= 0
/// 视为量程无效，返回 0（该维折到中心）。
pub fn radar_norm(v : Double, max : Double) -> Double {
  if !(max > 0.0) {
    return 0.0
  }
  let f = v / max
  if f < 0.0 {
    0.0
  } else if f > 1.0 {
    1.0
  } else {
    f
  }
}

///|
/// 值 → 半径：归一分数 × 满半径（0..r_max）。
pub fn radar_map_radius(v : Double, max : Double, r_max : Double) -> Double {
  radar_norm(v, max) * r_max
}

///|
/// 系列多边形顶点：第 i 维取值沿第 i 条轴映射到半径（maxes 为各维量程，
/// 与轴同序）。维度数以 maxes 为准——values 多出的忽略、缺失的按 0
/// （折到中心）。
pub fn radar_series_polygon(
  cx : Double,
  cy : Double,
  r_max : Double,
  values : Array[Double],
  maxes : Array[Double],
) -> Array[(Double, Double)] {
  let n = maxes.length()
  let out : Array[(Double, Double)] = []
  for i in 0..<n {
    let v = if i < values.length() { values[i] } else { 0.0 }
    let a = radar_axis_angle(i, n)
    let r = radar_map_radius(v, maxes[i], r_max)
    out.push((cx + r * @math.cos(a), cy + r * @math.sin(a)))
  }
  out
}

///|
/// 布局几何：返回（中心 x, 中心 y, 满半径）。legend=true 时右侧预留
/// 图例列宽度（中心左移）；满半径取绘图区短边一半再留出标签边距
/// （30px），最小 10。
pub fn radar_layout(
  w : Double,
  h : Double,
  legend : Bool,
) -> (Double, Double, Double) {
  let plot_w = if legend { (w - radar_legend_w).max(10.0) } else { w }
  let cx = plot_w / 2.0
  let cy = h / 2.0
  let r = (plot_w.min(h) / 2.0 - 30.0).max(10.0)
  (cx, cy, r)
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 沿多边形顶点闭合路径并执行动作（fill/stroke 共用同一顶点序）。
fn radar_stroke_polygon(
  p : @render.Painter,
  pts : Array[(Double, Double)],
  fill : Bool,
) -> Unit {
  if pts.length() == 0 {
    return
  }
  p.begin_path()
  p.move_to(pts[0].0, pts[0].1)
  for i in 1..<pts.length() {
    p.line_to(pts[i].0, pts[i].1)
  }
  p.close_path()
  if fill {
    p.fill()
  } else {
    p.stroke()
  }
}

///|
/// 雷达图绘制（画布坐标，数据已由调用方取出）：rings 层同心 N 边形网格 +
/// 中心到各顶点的轴线 + 维度标签（外圈外侧，按顶点朝向左右对齐）；每个
/// 系列一个半透明填充多边形并描边（多系列叠加）；show_legend 时右侧图例
/// 列（色块 + 系列名）。维度数 < 3 时画「暂无数据」提示。
fn radar_draw_chart(
  p : @render.Painter,
  w : Double,
  h : Double,
  indicators : Array[RadarIndicator],
  series : Array[RadarSeries],
  rings : Int,
  show_legend : Bool,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let n = indicators.length()
  let (cx, cy, r_max) = radar_layout(w, h, show_legend && series.length() > 0)
  if n < 3 {
    let _ = @text.draw_box_at(
      p,
      w / 2.0 - 100.0,
      h / 2.0 - 10.0,
      200.0,
      20.0,
      "暂无数据",
      hint_font(),
      @theme.theme_text_secondary(),
      align=@text.Center,
      valign=@text.Center,
      wrap=false,
    )
    return
  }
  let layers = if rings < 1 { 1 } else { rings }
  // 网格：layers 层同心 N 边形
  p.set_stroke_color(@theme.theme_border())
  for k in 1..<=layers {
    radar_stroke_polygon(
      p,
      radar_polygon(cx, cy, r_max * k.to_double() / layers.to_double(), n),
      false,
    )
  }
  // 轴线：中心 → 外圈各顶点
  p.begin_path()
  for pt in radar_polygon(cx, cy, r_max, n) {
    p.move_to(cx, cy)
    p.line_to(pt.0, pt.1)
  }
  p.stroke()
  // 系列多边形：半透明填充 + 描边（多系列叠加）
  let maxes : Array[Double] = []
  for ind in indicators {
    maxes.push(ind.max)
  }
  for si, s in series {
    let color = series_color(si)
    let pts = radar_series_polygon(cx, cy, r_max, s.values, maxes)
    p.set_fill_color(with_alpha(color, "26"))
    radar_stroke_polygon(p, pts, true)
    p.set_stroke_color(color)
    radar_stroke_polygon(p, pts, false)
  }
  // 维度标签：外圈顶点外侧，按顶点朝向取 左对齐/右对齐/居中
  let label_w = 56.0
  for i in 0..<n {
    let a = radar_axis_angle(i, n)
    let ca = @math.cos(a)
    let lx = cx + (r_max + 20.0) * ca
    let ly = cy + (r_max + 20.0) * @math.sin(a)
    let (align, ax) = if ca > 0.35 {
      (@text.Start, lx - 6.0)
    } else if ca < -0.35 {
      (@text.End, lx - label_w + 6.0)
    } else {
      (@text.Center, lx - label_w / 2.0)
    }
    let _ = @text.draw_box_at(
      p,
      ax,
      ly - 8.0,
      label_w,
      16.0,
      truncate_to(indicators[i].name, label_w),
      label_font(),
      @theme.theme_text_secondary(),
      align~,
      valign=@text.Center,
      wrap=false,
    )
  }
  // 图例（右列）：色块 + 系列名
  if show_legend {
    let lx = w - radar_legend_w + 4.0
    let row_h = 20.0
    for i, s in series {
      let ry = 10.0 + row_h * i.to_double()
      if ry + row_h > h - 4.0 {
        break
      }
      p.set_fill_color(series_color(i))
      p.fill_rect(lx, ry + 5.0, 10.0, 10.0)
      let _ = @text.draw_box_at(
        p,
        lx + 14.0,
        ry,
        radar_legend_w - 16.0,
        row_h,
        truncate_to(s.name, radar_legend_w - 16.0),
        label_font(),
        @theme.theme_text_regular(),
        align=@text.Start,
        valign=@text.Center,
        wrap=false,
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层
// ---------------------------------------------------------------------------

///|
/// 雷达图：N 边形同心网格（rings 层，默认 4）+ 轴线 + 维度标签；每个系列
/// 一个半透明填充多边形并描边，支持多系列叠加；右侧图例列（色块 +
/// 系列名，show_legend=false 关闭）。indicators 定义维度（名称 + 量程），
/// series 提供各维度取值（与 indicators 同序，0..max，超出钳制、缺失按
/// 0）；两者各经一个 Store 驱动，set 后只重绘画布不重建控件树；主题切换
/// 现取色自动跟随。
pub fn radar_chart_t(
  indicators : @base.Store[Array[RadarIndicator]],
  series : @base.Store[Array[RadarSeries]],
  rings? : Int = 4,
  show_legend? : Bool = true,
  width? : Double = 0.0,
  height? : Double = 340.0,
  handle? : (@widget.Widget) -> Unit = @ui.default_handle,
) -> @widget.Node {
  @ui.follow_store(indicators)
  @ui.follow_store(series)
  let nrings = rings
  let legend = show_legend
  @widget.node_of_new(fn(w : @widget.Widget) -> @widget.Widget {
    @ui.watch_theme()
    w.node.set_height(@yoga.fixed(height))
    if width > 0.0 {
      w.node.set_width(@yoga.fixed(width))
    } else {
      w.node.set_width(@yoga.percent(100.0))
      w.node.set_min_width(@yoga.fixed(120.0))
    }
    w.on_draw = Some(fn(
      _self : @widget.Widget,
      p : @render.Painter,
      r : @base.Rect,
    ) -> Unit {
      p.set_fill_color(@theme.theme_bg_panel())
      p.fill_rect(0.0, 0.0, r.w, r.h)
      radar_draw_chart(
        p,
        r.w,
        r.h,
        indicators.get(),
        series.get(),
        nrings,
        legend,
      )
    })
    handle(w)
    w
  })
}
