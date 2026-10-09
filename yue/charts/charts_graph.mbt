// 关系图组件（ECharts Graph 对标，纯 MoonBit 全自绘，Painter 承载）：
//   gph_chart_t    力导向关系图：节点-边图经力模拟迭代收敛后静态绘制
//                  ——斥力（库仑，所有节点对）、弹簧引力（边，胡克，
//                  劲度∝weight）、向心力（拉向质心），阻尼步进；边画
//                  半透明色带（宽∝weight），节点画圆（半径∝sqrt(value)，
//                  四语义色循环），节点名标签做防重叠推挤。
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （主题切换重绘跟随）；数据经 Store 驱动，set 后只 schedule_paint 画布，
// 不重建视图树。力模拟为纯函数（圆周均匀布点起步，无随机源，同输入
// 必同输出）；布局按当前画布大小在首次绘制时收敛一次并缓存，数据或
// 画布尺寸变化才重算。节点/边按下标互引。纯函数（力步进 / 能量 /
// 画布适配 / 半径 / 带宽 / 标签防重叠）集中在文件头部，
// charts_graph_wbtest.mbt 白盒覆盖。

///|
/// 弹簧静止长度占画布短边的比例（胡克零点）。
let gph_rest_frac : Double = 0.22

///|
/// 初始圆周布点半径占画布短边的比例（确定性起步，不用随机）。
let gph_init_frac : Double = 0.38

///|
/// 弹簧劲度基准（力 ∝ 劲度×weight×伸长，px/步；按短边/300 缩放）。
let gph_spr_k : Double = 0.16

///|
/// 库仑斥力常数基准（F = gph_rep_k × (短边/300)² / d²，px/步；与弹簧
/// 同口径缩放，保证不同尺寸画布布局同构）。与劲度的配比使"两节点
/// 单步弹簧缩短"成立（劲度项压过斥力项）。
let gph_rep_k : Double = 45000.0

///|
/// 速度阻尼（每步速度保留比例）。
let gph_vel_decay : Double = 0.72

///|
/// 向心力系数（拉向质心，px/步）。
let gph_center_k : Double = 0.006

///|
/// 节点圆半径下限（px）。
let gph_r_min : Double = 6.0

///|
/// 节点圆半径上限（px）。
let gph_r_max : Double = 18.0

///|
/// 边带宽度下限（px）。
let gph_w_min : Double = 1.0

///|
/// 边带宽度上限（px）。
let gph_w_max : Double = 5.0

///|
/// 布局留白与绘制留白（px，标签与圆不贴画布边）。
let gph_pad : Double = 12.0

// ---------------------------------------------------------------------------
// 纯函数层：数据结构 / 力模拟 / 画布适配 / 绘制度量（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 关系图节点：名称 + 量值 value（节点圆面积 ∝ value，<=0 给最小圆）；
/// value 不参与力模拟，只影响绘制大小。
pub(all) struct GraphNode {
  name : String
  value : Double
}

///|
/// 建关系图节点（value 为量值，默认 1）。
pub fn GraphNode::make(name : String, value? : Double = 1.0) -> GraphNode {
  { name, value, }
}

///|
/// 关系图边：source/target 为节点下标，weight 为权重（>0 才参与力模拟
/// 与绘制；弹簧劲度与边带宽度量纲）。
pub(all) struct GraphEdge {
  source : Int
  target : Int
  weight : Double
}

///|
/// 建关系图边（source/target 为节点下标，weight 为权重，默认 1）。
pub fn GraphEdge::make(
  source : Int,
  target : Int,
  weight? : Double = 1.0,
) -> GraphEdge {
  { source, target, weight, }
}

///|
/// 关系图数据（节点表 + 边表，边按下标引用节点）。
pub(all) struct GraphData {
  nodes : Array[GraphNode]
  edges : Array[GraphEdge]
}

///|
/// 建关系图数据。
pub fn GraphData::make(
  nodes : Array[GraphNode],
  edges : Array[GraphEdge],
) -> GraphData {
  { nodes, edges, }
}

///|
/// 边是否有效：两端下标在 [0, n_nodes) 内、非自环、weight > 0。无效
/// 边不参与力模拟、不画带（与节点流量口径一致）。
pub fn gph_edge_valid(e : GraphEdge, n_nodes : Int) -> Bool {
  e.source >= 0 &&
  e.source < n_nodes &&
  e.target >= 0 &&
  e.target < n_nodes &&
  e.source != e.target &&
  e.weight > 0.0
}

///|
/// 当前画布下的弹簧静止长度（短边 × gph_rest_frac；短边退化为 1）。
pub fn gph_rest_len(width : Double, height : Double) -> Double {
  let w = if width > 0.0 { width } else { 1.0 }
  let h = if height > 0.0 { height } else { 1.0 }
  gph_rest_frac * w.min(h)
}

///|
/// 力模拟状态：pos 为各节点当前坐标、vel 为速度（画布像素坐标，与节点
/// 下标对齐）。经 [GraphSim::make] 圆周布点起步，[GraphSim::advance]
/// 阻尼步进原地更新。
pub(all) struct GraphSim {
  pos : Array[(Double, Double)]
  vel : Array[(Double, Double)]
}

///|
/// 建模拟状态：n 个节点在画布内切圆上均匀布点（确定性起步，无随机
/// 源），速度归零；n <= 0 为空表。
pub fn GraphSim::make(n : Int, width : Double, height : Double) -> GraphSim {
  let pos : Array[(Double, Double)] = []
  let vel : Array[(Double, Double)] = []
  if n <= 0 {
    return { pos, vel, }
  }
  let w = if width > 0.0 { width } else { 1.0 }
  let h = if height > 0.0 { height } else { 1.0 }
  let cx = w / 2.0
  let cy = h / 2.0
  let r = gph_init_frac * w.min(h)
  for i in 0..<n {
    let a = tau * i.to_double() / n.to_double()
    pos.push((cx + r * @math.cos(a), cy + r * @math.sin(a)))
    vel.push((0.0, 0.0))
  }
  { pos, vel, }
}

///|
/// 阻尼步进一步（原地更新 pos/vel）：先按全部力（节点对斥力 + 边弹簧
/// + 质心向心）累加，再对速度阻尼后积分位移；坐标越出画布 20% 时反射
/// 并钳回，保证有限步内不发散。n == 0 或无 edges 时只走向心与斥力。
pub fn GraphSim::advance(
  self : GraphSim,
  edges : Array[GraphEdge],
  width : Double,
  height : Double,
) -> Unit {
  let n = self.pos.length()
  if n == 0 {
    return
  }
  let w = if width > 0.0 { width } else { 1.0 }
  let h = if height > 0.0 { height } else { 1.0 }
  let scale = w.min(h) / 300.0
  let rep_k = gph_rep_k * scale * scale
  let spr_k = gph_spr_k * scale
  let rest = gph_rest_len(width, height)
  // 合力累加
  let fx = Array::make(n, 0.0)
  let fy = Array::make(n, 0.0)
  // 斥力（库仑，所有对）
  for i in 0..<n {
    for j in (i + 1)..<n {
      let dx = self.pos[j].0 - self.pos[i].0
      let dy = self.pos[j].1 - self.pos[i].1
      let dist = (dx * dx + dy * dy).sqrt().max(1.0e-3)
      let f = rep_k / (dist * dist)
      let ux = dx / dist
      let uy = dy / dist
      fx[i] = fx[i] - f * ux
      fy[i] = fy[i] - f * uy
      fx[j] = fx[j] + f * ux
      fy[j] = fy[j] + f * uy
    }
  }
  // 弹簧引力（边，胡克；劲度 ∝ weight）
  for e in edges {
    if !gph_edge_valid(e, n) {
      continue
    }
    let i = e.source
    let j = e.target
    let dx = self.pos[j].0 - self.pos[i].0
    let dy = self.pos[j].1 - self.pos[i].1
    let dist = (dx * dx + dy * dy).sqrt().max(1.0e-3)
    let ux = dx / dist
    let uy = dy / dist
    let f = spr_k * e.weight * (dist - rest)
    fx[i] = fx[i] + f * ux
    fy[i] = fy[i] + f * uy
    fx[j] = fx[j] - f * ux
    fy[j] = fy[j] - f * uy
  }
  // 向心力（质心）
  let mut ccx = 0.0
  let mut ccy = 0.0
  for p in self.pos {
    ccx = ccx + p.0
    ccy = ccy + p.1
  }
  ccx = ccx / n.to_double()
  ccy = ccy / n.to_double()
  for i in 0..<n {
    let ax = ccx.min(w).max(0.0)
    let ay = ccy.min(h).max(0.0)
    fx[i] = fx[i] + gph_center_k * (ax - self.pos[i].0)
    fy[i] = fy[i] + gph_center_k * (ay - self.pos[i].1)
  }
  // 阻尼步进 + 边界反射（越界轴反向并衰减，另一轴保持）
  let lo_x = -0.2 * w
  let hi_x = 1.2 * w
  let lo_y = -0.2 * h
  let hi_y = 1.2 * h
  for i in 0..<n {
    let mut nvx = self.vel[i].0 * gph_vel_decay + fx[i]
    let mut nvy = self.vel[i].1 * gph_vel_decay + fy[i]
    let mut nx = self.pos[i].0 + nvx
    let mut ny = self.pos[i].1 + nvy
    if nx < lo_x {
      nx = lo_x
      nvx = -nvx * 0.5
    } else if nx > hi_x {
      nx = hi_x
      nvx = -nvx * 0.5
    }
    if ny < lo_y {
      ny = lo_y
      nvy = -nvy * 0.5
    } else if ny > hi_y {
      ny = hi_y
      nvy = -nvy * 0.5
    }
    self.vel[i] = (nvx, nvy)
    self.pos[i] = (nx, ny)
  }
}

///|
/// 图能量（Lyapunov 口径，布局不合理度的单调度量）：弹簧势 Σ ½×劲度×
/// weight×(边长-静止长)² + 边两端斥力势 Σ 劲度_rep/d（越近代价越高）+
/// 向心势 Σ ½×center_k×离质心距²。劲度/斥力与 [GraphSim::advance] 同取
/// (短边/300) 口径；含无效边 / 距离下限 1e-3 保护，空输入给 0。用于
/// 收敛性断言：迭代推进该值下降（收敛点附近持平）。
pub fn gph_energy(
  pts : Array[(Double, Double)],
  edges : Array[GraphEdge],
  width : Double,
  height : Double,
) -> Double {
  let n = pts.length()
  let w = if width > 0.0 { width } else { 1.0 }
  let h = if height > 0.0 { height } else { 1.0 }
  let scale = w.min(h) / 300.0
  let rep_k = gph_rep_k * scale * scale
  let spr_k = gph_spr_k * scale
  let rest = gph_rest_len(w, h)
  let mut energy = 0.0
  for e in edges {
    if !gph_edge_valid(e, n) {
      continue
    }
    let dx = pts[e.target].0 - pts[e.source].0
    let dy = pts[e.target].1 - pts[e.source].1
    let dist = (dx * dx + dy * dy).sqrt().max(1.0e-3)
    let ext = dist - rest
    // 弹簧势（胡克势 ½k wt x²，与步进中弹簧力同尺度）
    energy = energy + 0.5 * spr_k * e.weight * ext * ext
    // 斥力势：库仑势 ∝ 1/d，距离越近代价越高（与步进中斥力同向）
    energy = energy + rep_k / dist
  }
  let mut ccx = 0.0
  let mut ccy = 0.0
  for p in pts {
    ccx = ccx + p.0
    ccy = ccy + p.1
  }
  ccx = ccx / n.to_double()
  ccy = ccy / n.to_double()
  for p in pts {
    let ex = p.0 - ccx
    let ey = p.1 - ccy
    energy = energy + 0.5 * gph_center_k * (ex * ex + ey * ey)
  }
  energy
}

///|
/// 力导向布局结果（画布收敛坐标，与节点下标对齐；已适配到画布内）。
pub(all) struct GraphLayout {
  points : Array[(Double, Double)]
}

///|
/// 画布适配：把模拟坐标按包围盒等比缩放 + 居中到 [gph_pad, w-gph_pad]
/// × [gph_pad, h-gph_pad]（长宽比保持，某轴退化〈span≈0〉时该轴不平移
/// 拉伸、仅居中）；空输入给空表。缩放上限 20 防退化散布被过度放大。
pub fn gph_fit_canvas(
  pts : Array[(Double, Double)],
  width : Double,
  height : Double,
) -> GraphLayout {
  let n = pts.length()
  let out : Array[(Double, Double)] = []
  if n == 0 {
    return { points: out, }
  }
  let w = if width > 0.0 { width } else { 1.0 }
  let h = if height > 0.0 { height } else { 1.0 }
  let mut xmin = pts[0].0
  let mut xmax = pts[0].0
  let mut ymin = pts[0].1
  let mut ymax = pts[0].1
  for p in pts {
    if p.0 < xmin {
      xmin = p.0
    }
    if p.0 > xmax {
      xmax = p.0
    }
    if p.1 < ymin {
      ymin = p.1
    }
    if p.1 > ymax {
      ymax = p.1
    }
  }
  let span_x = xmax - xmin
  let span_y = ymax - ymin
  let avail_w = (w - 2.0 * gph_pad).max(1.0)
  let avail_h = (h - 2.0 * gph_pad).max(1.0)
  let sx = if span_x > 1.0e-9 { avail_w / span_x } else { 1.0 }
  let sy = if span_y > 1.0e-9 { avail_h / span_y } else { 1.0 }
  let s = sx.min(sy).min(20.0)
  let tx = (w - span_x * s) / 2.0 - xmin * s
  let ty = (h - span_y * s) / 2.0 - ymin * s
  for p in pts {
    out.push((p.0 * s + tx, p.1 * s + ty))
  }
  { points: out, }
}

///|
/// 力导向布局：nodes 定节点数（name/value 不影响力），edges 按下标引
/// 用节点提供弹簧；布局在 width × height 画布内从圆周均匀布点起步，
/// 阻尼步进 iterations 步（<0 按 0 步）后按包围盒等比适配回画布。纯
/// 函数：无随机源，同输入必同输出；空节点表给空坐标表。
pub fn gph_layout(
  nodes : Array[GraphNode],
  edges : Array[GraphEdge],
  width : Double,
  height : Double,
  iterations? : Int = 300,
) -> GraphLayout {
  let n = nodes.length()
  let sim = GraphSim::make(n, width, height)
  let iters = if iterations < 0 { 0 } else { iterations }
  for _ in 0..<iters {
    GraphSim::advance(sim, edges, width, height)
  }
  gph_fit_canvas(sim.pos, width, height)
}

///|
/// 节点圆半径：∝ sqrt(value / vmax)，范围 [gph_r_min, gph_r_max]
/// （面积量纲 ∝ value）；vmax <= 0 或 value <= 0 给下限，value 超
/// vmax 钳到上限。
pub fn gph_node_radius(
  value : Double,
  vmax : Double,
  r_min? : Double = gph_r_min,
  r_max? : Double = gph_r_max,
) -> Double {
  if !(vmax > 0.0) {
    return r_min
  }
  let v = value.max(0.0).min(vmax)
  let f = (v / vmax).sqrt()
  r_min + f * (r_max - r_min)
}

///|
/// 边带宽度：∝ weight / wmax，范围 [gph_w_min, gph_w_max]；wmax <= 0
/// 或无有效 weight 时给下限。
pub fn gph_edge_width(
  weight : Double,
  wmax : Double,
  w_min? : Double = gph_w_min,
  w_max? : Double = gph_w_max,
) -> Double {
  if !(wmax > 0.0) {
    return w_min
  }
  let w = weight.max(0.0).min(wmax)
  w_min + w / wmax * (w_max - w_min)
}

///|
/// 标签防重叠推挤：输入各节点锚点与半径，输出每节点标签的中心 y（与
/// 下标对齐）。锚点为圆心 y 加大圆让位（半径 × 0.35，圆越大标签越
/// 靠下）；再按 y 升序推挤到最小间距 gap 之上（下标序为稳定次序）——
/// 绘制坐标与推挤结果同源，标签不糊成一团。空输入给空表。
pub fn gph_label_slots(
  pts : Array[(Double, Double)],
  radii : Array[Double],
  gap? : Double = 14.0,
) -> Array[Double] {
  let n = pts.length()
  let out = Array::make(n, 0.0)
  if n == 0 {
    return out
  }
  // (y, idx) 按 y 升序（稳定：同 y 按下标）
  let order : Array[(Double, Int)] = []
  for i in 0..<n {
    let rr = if i < radii.length() { radii[i] } else { 0.0 }
    order.push((pts[i].1 + rr * 0.35, i))
  }
  order
  .mut_view()
  .sort_by(fn(a, b) {
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else if a.1 < b.1 {
      -1
    } else if a.1 > b.1 {
      1
    } else {
      0
    }
  })
  let mut prev_y = 0.0
  for k, (y, idx) in order {
    let ly = if k == 0 {
      y
    } else if y < prev_y + gap {
      prev_y + gap
    } else {
      y
    }
    out[idx] = ly
    prev_y = ly
  }
  out
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 实心圆（折线近似，子午线弦误差亚像素；arc 整圆跨平台行为不一致，
/// 统一走折线）。r <= 0 无操作。
fn gph_fill_circle(p : @yue.Painter, cx : Double, cy : Double, r : Double) -> Unit {
  if !(r > 0.0) {
    return
  }
  let steps = 32
  p.begin_path()
  for k in 0..<steps {
    let a = tau * k.to_double() / steps.to_double()
    let x = cx + r * @math.cos(a)
    let y = cy + r * @math.sin(a)
    if k == 0 {
      p.move_to(x, y)
    } else {
      p.line_to(x, y)
    }
  }
  p.close_path()
  p.fill()
}

///|
/// 关系图绘制（画布坐标，数据已由调用方取出）：边带（两条直边围成的
/// 平行四边形色带，宽∝weight，两端收入节点圆周内，源节点色半透明）
/// 先画、节点圆后画盖住端头；节点圆半径∝sqrt(value) 走 [gph_node_radius]，
/// 色按节点下标走 series_color 四色循环，面板底描边分隔相邻圆；节点名
/// 标签锚点取标签防重叠推挤结果（[gph_label_slots]），钳在画布内。空
/// 节点表画「暂无数据」。
fn gph_draw_chart(
  p : @yue.Painter,
  w : Double,
  h : Double,
  nodes : Array[GraphNode],
  edges : Array[GraphEdge],
  layout : GraphLayout,
  show_labels : Bool,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let n = nodes.length()
  if n == 0 {
    let at = @yue.AttributedText::new(
      "暂无数据",
      align=@yue.Center,
      valign=@yue.Center,
      wrap=false,
    )
    at.set_font(@yue.Font::new("Sans", 13.0))
    at.set_color(@yue.theme_text_secondary())
    let tw = at.get_bounds_for(400.0, 40.0).width
    p.draw_attributed_text(
      at,
      w / 2.0 - tw / 2.0,
      h / 2.0 - 10.0,
      tw + 4.0,
      20.0,
    )
    return
  }
  let pts = layout.points
  if pts.length() != n {
    return
  }
  // 量程：value 最大者（半径）与有效 weight 最大者（带宽）
  let mut vmax = 0.0
  for nd in nodes {
    if nd.value > vmax {
      vmax = nd.value
    }
  }
  let mut wmax = 0.0
  for e in edges {
    if gph_edge_valid(e, n) && e.weight > wmax {
      wmax = e.weight
    }
  }
  // 边带：平行四边形色带（宽∝weight，两端收入节点圆周内）
  for e in edges {
    if !gph_edge_valid(e, n) {
      continue
    }
    let a = pts[e.source]
    let b = pts[e.target]
    let ra = gph_node_radius(nodes[e.source].value, vmax)
    let rb = gph_node_radius(nodes[e.target].value, vmax)
    let dx = b.0 - a.0
    let dy = b.1 - a.1
    let dist = (dx * dx + dy * dy).sqrt()
    if !(dist > 1.0e-6) {
      continue
    }
    let ux = dx / dist
    let uy = dy / dist
    let nx = -uy
    let ny = ux
    let hw = gph_edge_width(e.weight, wmax) / 2.0
    let sx = a.0 + ux * ra
    let sy = a.1 + uy * ra
    let ex = b.0 - ux * rb
    let ey = b.1 - uy * rb
    p.set_fill_color(@yue.with_alpha(series_color(e.source), "59"))
    p.begin_path()
    p.move_to(sx + nx * hw, sy + ny * hw)
    p.line_to(ex + nx * hw, ey + ny * hw)
    p.line_to(ex - nx * hw, ey - ny * hw)
    p.line_to(sx - nx * hw, sy - ny * hw)
    p.close_path()
    p.fill()
  }
  // 节点圆 + 面板底描边
  for i in 0..<n {
    let (cx, cy) = pts[i]
    let r = gph_node_radius(nodes[i].value, vmax)
    p.set_fill_color(series_color(i))
    gph_fill_circle(p, cx, cy, r)
    p.set_stroke_color(@yue.theme_bg_panel())
    p.begin_path()
    let rr = r + 0.75
    p.move_to(cx + rr, cy)
    for k in 1..<=32 {
      let ang = tau * k.to_double() / 32.0
      p.line_to(cx + rr * @math.cos(ang), cy + rr * @math.sin(ang))
    }
    p.close_path()
    p.stroke()
  }
  // 名称标签（防重叠推挤后的中心 y，钳在画布内）
  if show_labels {
    let radii : Array[Double] = []
    for i in 0..<n {
      radii.push(gph_node_radius(nodes[i].value, vmax))
    }
    let slots = gph_label_slots(pts, radii)
    for i in 0..<n {
      let lx = pts[i].0 + radii[i] + 5.0
      if lx > w - 8.0 {
        continue
      }
      let ly = slots[i].min(h - 9.0).max(9.0)
      let name = truncate_to(nodes[i].name, (w - lx - 4.0).max(8.0))
      if name == "" {
        continue
      }
      p.draw_text(
        name,
        lx,
        ly - 9.0,
        (w - lx - 4.0).max(8.0),
        18.0,
        align=@yue.Start,
        valign=@yue.Center,
        color=@yue.theme_text_regular(),
        wrap=false,
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 力导向关系图（EP 对标，ECharts Graph）：节点-边图经力模拟（节点对
/// 库仑斥力 + 边胡克弹簧 + 质心向心，阻尼步进 iterations 步，默认 300）
/// 收敛后静态绘制——边为半透明平行四边形色带（宽∝weight），节点为圆
/// （面积∝value，四语义色循环），节点名标签做防重叠推挤；show_labels
/// =false 关闭名称。布局按当前画布尺寸在首次绘制时收敛一次并缓存，
/// 数据 set 或画布尺寸变化才重算。数据经 Store 驱动，set 后只重绘画布
/// 不重建视图树；主题切换现取色自动跟随。fill=true 不设固定宽度，
/// 横向铺满父容器（跟随窗口伸缩）。
pub fn gph_chart_t(
  data : @yue.Store[GraphData],
  iterations? : Int = 300,
  show_labels? : Bool = true,
  fill? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      // 布局缓存：(画布宽, 画布高, 布局)；None 表示数据已变更待重算
      let cache : Ref[(Double, Double, GraphLayout)?] = Ref(None)
      let size_style : Array[(String, &@yue.StyVal)] = if fill {
        [("height", 320.0)]
      } else {
        [("width", 560.0), ("height", 320.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = @yue.themed_container(style=size_style)
      handle(cv)
      @yue.set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(cv)
        p.set_stroke_color(@yue.theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        let d = data.get()
        let layout = match cache.val {
          Some((cw, ch, lay)) =>
            if (cw - b.width).abs() > 0.5 || (ch - b.height).abs() > 0.5 {
              gph_layout(d.nodes, d.edges, b.width, b.height, iterations~)
            } else {
              lay
            }
          None => gph_layout(d.nodes, d.edges, b.width, b.height, iterations~)
        }
        cache.val = Some((b.width, b.height, layout))
        gph_draw_chart(
          p,
          b.width,
          b.height,
          d.nodes,
          d.edges,
          layout,
          show_labels,
        )
      })
      data.subscribe(fn(_d) {
        cache.val = None
        @yue.ViewLike::schedule_paint(cv)
      })
      @yue.attach(parent, @yue.ViewLike::view(cv))
      @yue.ViewLike::view(cv)
    },
  }
}
