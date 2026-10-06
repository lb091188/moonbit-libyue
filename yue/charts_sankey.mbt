// 桑基图组件（EP Chart 对标，纯 MoonBit 全自绘，Painter 承载）：
//   sankey_t     节点-链路流量图：分层布局（无入边节点进第 0 列、沿链路
//                拓扑右移），列内按流量比例定高、纵向居中排布；节点画
//                矩形（高∝流量，第 0 列名标左侧、其余列名标右侧），链路
//                画半透明贝塞尔色带（宽∝流量，源右缘到目标左缘）。
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （主题切换重绘跟随）；数据经 Store 驱动，set 后只 schedule_paint
// 画布，不重建视图树。静态分层布局（非力导向）；节点/链路下标走
// charts.mbt 的 series_color 四语义色循环。纯函数（列分配 / 节点流量 /
// 分层布局端缘）集中在文件头部，charts_sankey_wbtest.mbt 白盒覆盖。

// ---------------------------------------------------------------------------
// 纯函数层：列分配 / 节点流量 / 分层布局（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 桑基图节点（名称；几何量由布局按链路算出）。
pub(all) struct SankeyNode {
  name : String
}

///|
/// 建桑基图节点。
pub fn SankeyNode::make(name : String) -> SankeyNode {
  { name, }
}

///|
/// 桑基图链路：source/target 为节点下标，value 为流量（>0 计入布局，
/// 节点高度与色带宽度的量纲）。
pub(all) struct SankeyLink {
  source : Int
  target : Int
  value : Double
}

///|
/// 建桑基图链路（source/target 为节点下标）。
pub fn SankeyLink::make(
  source : Int,
  target : Int,
  value : Double,
) -> SankeyLink {
  { source, target, value, }
}

///|
/// 桑基图数据（节点表 + 链路表，链路按下标引用节点）。
pub(all) struct SankeyData {
  nodes : Array[SankeyNode]
  links : Array[SankeyLink]
}

///|
/// 建桑基图数据。
pub fn SankeyData::make(
  nodes : Array[SankeyNode],
  links : Array[SankeyLink],
) -> SankeyData {
  { nodes, links, }
}

///|
/// 列分配（拓扑层级）：无入边的节点进第 0 列，其余节点列号 = 全部入边
/// 源节点列号的最大值 + 1，迭代至收敛。下标越界、自环或非正值的链路
/// 不参与（与节点流量 / 色带口径一致）；含环的输入在 n_nodes 轮迭代
/// 上限处截断（环上节点停在已推进的列，结果仍为有限非负值）。返回
/// 长度 n_nodes 的列号表。
pub fn sankey_columns(n_nodes : Int, links : Array[SankeyLink]) -> Array[Int] {
  let cols = Array::make(n_nodes, 0)
  if n_nodes <= 0 {
    return cols
  }
  let mut round = 0
  let mut changed = true
  while changed && round < n_nodes {
    changed = false
    for l in links {
      if l.source == l.target || !(l.value > 0.0) {
        continue
      }
      if l.source < 0 || l.source >= n_nodes || l.target < 0 || l.target >= n_nodes {
        continue
      }
      let want = cols[l.source] + 1
      if want > cols[l.target] {
        cols[l.target] = want
        changed = true
      }
    }
    round = round + 1
  }
  cols
}

///|
/// 节点流量（矩形高度的量纲）：每节点取 max(入边和, 出边和)，只计
/// 正值链路；下标越界的链路忽略。返回长度 n_nodes 的流量表。
pub fn sankey_node_flow(n_nodes : Int, links : Array[SankeyLink]) -> Array[Double] {
  let in_tot = Array::make(n_nodes, 0.0)
  let out_tot = Array::make(n_nodes, 0.0)
  for l in links {
    if l.value > 0.0 &&
      l.source >= 0 &&
      l.source < n_nodes &&
      l.target >= 0 &&
      l.target < n_nodes {
      out_tot[l.source] = out_tot[l.source] + l.value
      in_tot[l.target] = in_tot[l.target] + l.value
    }
  }
  let flow = Array::make(n_nodes, 0.0)
  for i in 0..<n_nodes {
    flow[i] = if in_tot[i] > out_tot[i] { in_tot[i] } else { out_tot[i] }
  }
  flow
}

///|
/// 桑基图节点矩形（画布坐标）：node 为节点下标，col 为所在列号。
pub(all) struct SankeyNodeBox {
  node : Int
  col : Int
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
/// 桑基图链路色带端缘（画布坐标）：x0 为源节点右缘、x1 为目标节点左缘，
/// (sy0, sy1) 为源端上下缘、(ty0, ty1) 为目标端上下缘；色带为两条三次
/// 贝塞尔围成的区域（控制点取两端横坐标中点，两端切线水平）。
pub(all) struct SankeyLinkBand {
  link : Int
  x0 : Double
  x1 : Double
  sy0 : Double
  sy1 : Double
  ty0 : Double
  ty1 : Double
}

///|
/// 桑基图分层布局结果：boxes 按列序（列号升序、列内节点下标序）排列，
/// band.link / box.node 为链路 / 节点下标；下标越界、非正值或自环的
/// 链路不产出 band，cols 为列分配副本。
pub(all) struct SankeyLayout {
  boxes : Array[SankeyNodeBox]
  bands : Array[SankeyLinkBand]
  cols : Array[Int]
}

///|
/// 分层布局：节点经 [sankey_columns] 进列，列 x 在 [x0, x1 - node_w] 上
/// 均分（单列居中）；列内按节点下标序纵向排布，高度 = 流量 × scale
/// （scale = 可用高 / 最大列流量，零流量节点给最小高 min_h 3px），列内
/// 整体纵向居中（超出可用高时顶对齐）；同一节点的多条出/入链路沿矩形
/// 纵向依序消费偏移（不重叠、无缝隙），band 高度与节点高度同 scale。
pub fn sankey_layout(
  n_nodes : Int,
  links : Array[SankeyLink],
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
  node_w? : Double = 14.0,
  gap? : Double = 8.0,
  min_h? : Double = 3.0,
) -> SankeyLayout {
  let cols = sankey_columns(n_nodes, links)
  let boxes : Array[SankeyNodeBox] = []
  let bands : Array[SankeyLinkBand] = []
  if n_nodes <= 0 {
    return { boxes, bands, cols }
  }
  // 列号 → 节点集合（按节点下标序，稳定）
  let n_cols = {
    let mut m = 0
    for c in cols {
      if c > m {
        m = c
      }
    }
    m + 1
  }
  let by_col : Array[Array[Int]] = []
  for _ in 0..<n_cols {
    by_col.push([])
  }
  for i in 0..<n_nodes {
    by_col[cols[i]].push(i)
  }
  // 高度比例：可用高对应最大列流量
  let flow = sankey_node_flow(n_nodes, links)
  let avail_h = (y1 - y0).max(0.0)
  let mut max_col = 0.0
  for c in 0..<n_cols {
    let mut tot = 0.0
    for i in by_col[c] {
      tot = tot + flow[i]
    }
    if tot > max_col {
      max_col = tot
    }
  }
  let scale = if max_col > 0.0 { avail_h / max_col } else { 0.0 }
  // 节点矩形：列 x 均分，列内纵向依序 + 居中
  let span = (x1 - x0 - node_w).max(0.0)
  for c in 0..<n_cols {
    let cx = if n_cols > 1 {
      x0 + span * c.to_double() / (n_cols - 1).to_double()
    } else {
      x0 + span / 2.0
    }
    let mut total_h = 0.0
    for i in by_col[c] {
      total_h = total_h + (flow[i] * scale).max(min_h)
    }
    total_h = total_h + gap * (by_col[c].length() - 1).to_double()
    let mut cy = y0 + (avail_h - total_h) / 2.0
    if cy < y0 {
      cy = y0
    }
    for i in by_col[c] {
      let hh = (flow[i] * scale).max(min_h)
      boxes.push({ node: i, col: c, x: cx, y: cy, w: node_w, h: hh })
      cy = cy + hh + gap
    }
  }
  // 节点下标 → boxes 索引（band 取节点矩形用）
  let idx = Array::make(n_nodes, 0)
  for k, b in boxes {
    idx[b.node] = k
  }
  // 链路端缘：出/入偏移沿节点矩形纵向依序消费
  let out_off = Array::make(n_nodes, 0.0)
  let in_off = Array::make(n_nodes, 0.0)
  for li, l in links {
    if l.source == l.target {
      continue
    }
    if l.source < 0 || l.source >= n_nodes || l.target < 0 || l.target >= n_nodes {
      continue
    }
    if !(l.value > 0.0) {
      continue
    }
    let lh = l.value * scale
    let sb = boxes[idx[l.source]]
    let tb = boxes[idx[l.target]]
    bands.push({
      link: li,
      x0: sb.x + sb.w,
      x1: tb.x,
      sy0: sb.y + out_off[l.source],
      sy1: sb.y + out_off[l.source] + lh,
      ty0: tb.y + in_off[l.target],
      ty1: tb.y + in_off[l.target] + lh,
    })
    out_off[l.source] = out_off[l.source] + lh
    in_off[l.target] = in_off[l.target] + lh
  }
  { boxes, bands, cols }
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 桑基图绘制：色带（两条三次贝塞尔围成的区域，源节点色半透明）先画、
/// 节点矩形后画盖住端头；第 0 列节点名标在矩形左侧、其余列标在右侧。
/// 节点 / 链路源节点色均按节点下标走 series_color 四色循环；空节点表
/// 画「暂无数据」。
fn sankey_draw(
  p : Painter,
  w : Double,
  h : Double,
  data : SankeyData,
  show_labels : Bool,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let pad_l = 84.0
  let pad_r = 76.0
  let pad_t = 12.0
  let pad_b = 12.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if data.nodes.length() == 0 {
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
      w / 2.0 - tw / 2.0,
      h / 2.0 - 10.0,
      tw + 4.0,
      20.0,
    )
    return
  }
  if x1 <= x0 + 20.0 || y1 <= y0 {
    return
  }
  let lay = sankey_layout(data.nodes.length(), data.links, x0, x1, y0, y1)
  // 色带：上边 (x0, sy0) → (x1, ty0)，下边回程，控制点取中点横坐标
  for band in lay.bands {
    p.set_fill_color(with_alpha(series_color(data.links[band.link].source), "3d"))
    let mx = (band.x0 + band.x1) / 2.0
    p.begin_path()
    p.move_to(band.x0, band.sy0)
    p.bezier_curve_to(mx, band.sy0, mx, band.ty0, band.x1, band.ty0)
    p.line_to(band.x1, band.ty1)
    p.bezier_curve_to(mx, band.ty1, mx, band.sy1, band.x0, band.sy1)
    p.close_path()
    p.fill()
  }
  // 节点矩形 + 名称标签
  for b in lay.boxes {
    p.set_fill_color(series_color(b.node))
    p.fill_rect(b.x, b.y, b.w, b.h)
    if show_labels {
      let first_col = b.col == 0
      let avail = if first_col { pad_l - 10.0 } else { pad_r - 10.0 }
      let name = truncate_to(data.nodes[b.node].name, avail)
      if name != "" {
        p.draw_text(
          name,
          if first_col { b.x - avail - 4.0 } else { b.x + b.w + 6.0 },
          b.y + b.h / 2.0 - 9.0,
          avail,
          18.0,
          align=if first_col { End } else { Start },
          valign=Center,
          color=theme_text_regular(),
          wrap=false,
        )
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 桑基图（EP 无对应，流向图族）：节点-链路流量图——无入边节点进第
/// 0 列、沿链路拓扑右移分层，列内按流量比例定高、纵向居中；节点画矩形
/// （高∝流量，第 0 列名标左侧、其余列名标右侧），链路画半透明贝塞尔
/// 色带（宽∝流量，源右缘到目标左缘）。静态分层布局（非力导向）；
/// show_labels=false 关闭节点名。数据经 Store 驱动，set 后只重绘画布
/// 不重建视图树；主题切换现取色自动跟随。fill=true 不设固定宽度，
/// 横向铺满父容器（跟随窗口伸缩）。
pub fn sankey_t(
  data : Store[SankeyData],
  show_labels? : Bool = true,
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) { },
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
        sankey_draw(p, b.width, b.height, data.get(), show_labels)
      })
      data.subscribe(fn(_d) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
