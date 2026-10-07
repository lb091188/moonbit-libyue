// 树图组件（EP Chart 对标，纯 MoonBit 全自绘，Painter 承载）：
//   tree_chart_t 层级树图：横向（默认，根居左）与纵向（根居顶）两形态；
//                 叶节点沿横铺方向均分、父节点取子节点中点、深度方向
//                 分层定位；连线为直角折线（肘线）；节点圆点大小∝value
//                 （无 value 等大），深度渐变着色；节点名标签。
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色
// （主题切换重绘跟随）；数据经 Store 驱动（根节点 TreeItem，子节点为
// 可变列表），set 后只 schedule_paint 画布，不重建视图树。纯函数
// （子树深度 / 叶子数 / 峰值 / 叶槽位均分 / 圆点半径 / 分层布局几何）
// 集中在文件头部，charts_tree_wbtest.mbt 白盒覆盖。

// ---------------------------------------------------------------------------
// 纯函数层：深度 / 叶子数 / 峰值 / 叶槽位 / 圆点半径 / 布局几何
// （白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 树图节点：名称 + 可选数值（圆点大小的量纲）+ 子节点可变列表（直接
/// push 增删子树）。value 为 None 的节点与无任何 value 的树统一按等大
/// 圆点绘制。
pub(all) struct TreeItem {
  name : String
  value : Double?
  children : Array[TreeItem]
}

///|
/// 建树图节点（value 省略时圆点等大；children 建后可再 push）。
pub fn TreeItem::make(name : String, value? : Double? = None) -> TreeItem {
  { name, value, children: [], }
}

///|
/// 子树高度（边数）：叶子（无子节点）为 0，否则 1 + 子节点最大高度。
/// 即布局里深度分层的总层数减一（根深度 0）。
pub fn tree_depth(item : TreeItem) -> Int {
  if item.children.length() == 0 {
    return 0
  }
  let mut m = 0
  for k in item.children {
    let d = tree_depth(k)
    if d > m {
      m = d
    }
  }
  m + 1
}

///|
/// 叶子数：无子节点的节点计 1，否则为各子节点叶子数之和。叶节点沿横铺
/// 方向均分槽位、父节点按子节点定位，故叶子数是布局的行列基准。
pub fn tree_leaf_count(item : TreeItem) -> Int {
  if item.children.length() == 0 {
    return 1
  }
  let mut n = 0
  for k in item.children {
    n = n + tree_leaf_count(k)
  }
  n
}

///|
/// 子树内最大正值（圆点半径 ∝ value 的满值端）：只计 value 存在且 > 0
/// 的节点；全无正值给 0（调用方据此退化到等大圆点）。
pub fn tree_max_value(item : TreeItem) -> Double {
  let mut m = match item.value {
    Some(v) => if v > 0.0 { v } else { 0.0 }
    None => 0.0
  }
  for k in item.children {
    let v = tree_max_value(k)
    if v > m {
      m = v
    }
  }
  m
}

///|
/// 叶槽位中心：n 个叶节点在 [start, start+span] 上均分，第 i 个叶节点
/// 取第 i 段槽位的中心（(i+0.5)/n 处）。n <= 0 或 i 越界退化为区间中点。
pub fn tree_leaf_slot(
  i : Int,
  n : Int,
  start : Double,
  span : Double,
) -> Double {
  if n <= 0 || i < 0 || i >= n {
    return start + span / 2.0
  }
  start + span * (i.to_double() + 0.5) / n.to_double()
}

///|
/// 圆点半径：max_value > 0 时按 value/max_value 在 [min_r, max_r] 间线性
/// 取（钳制）；value 缺失（None）或 max_value <= 0（全树无值）一律取
/// min_r（等大）。
pub fn tree_dot_radius(
  value : Double?,
  max_value : Double,
  min_r? : Double = 4.0,
  max_r? : Double = 10.0,
) -> Double {
  let lo = if min_r < max_r { min_r } else { max_r }
  let hi = if min_r < max_r { max_r } else { min_r }
  if !(max_value > 0.0) {
    return lo
  }
  match value {
    None => lo
    Some(v) => {
      let f = if v < 0.0 {
        0.0
      } else if v > max_value {
        1.0
      } else {
        v / max_value
      }
      lo + (hi - lo) * f
    }
  }
}

///|
/// 形态开关：orientation 传 "vertical" 为纵向（根居顶、子节点横向铺开），
/// 其余取值（含默认 "horizontal"）一律横向（根居左）。
pub fn tree_vertical(orientation : String) -> Bool {
  orientation == "vertical"
}

///|
/// 树图节点几何（画布坐标）：depth 为所在层（根 0），(x, y) 为圆点中心，
/// r 为圆点半径，is_leaf 标记叶节点。
pub(all) struct TreeNodeBox {
  depth : Int
  x : Double
  y : Double
  r : Double
  is_leaf : Bool
}

///|
/// 树图连线折线点位（画布坐标，直角肘线）：4 点序列
/// 父节点 → 肘点 1 → 肘点 2 → 子节点；横/纵两形态共用，圆点后画盖住
/// 端点。
pub(all) struct TreeEdge {
  pts : Array[(Double, Double)]
}

///|
/// 布局结果：boxes 为 DFS 后序（先子后父）排列的节点几何表，edges 为
/// 连线折线表（各子树边先于父边），max_depth 即根子树高度。
pub(all) struct TreeLayout {
  boxes : Array[TreeNodeBox]
  edges : Array[TreeEdge]
  max_depth : Int
}

///|
/// 分层布局（纯函数，独立可测）：深度方向按 [tree_depth] 给定层数，在
/// [x0, x1]（纵向形态 [y0, y1]）上把根分到起点、最深处分到末端；横铺
/// 方向（纵向形态 y、横向形态 x）上叶节点经 [tree_leaf_slot] 均分槽位、
/// 父节点取各子节点横铺坐标的均值（= 子节点中点）；圆点半径经
/// [tree_dot_radius] ∝ value。允许退化区间（x1<x0 等），坐标仍单调
/// 可推。
pub fn tree_layout(
  root : TreeItem,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  vertical? : Bool = false,
) -> TreeLayout {
  let max_depth = tree_depth(root)
  let n_leaves = tree_leaf_count(root)
  let max_value = tree_max_value(root)
  let boxes : Array[TreeNodeBox] = []
  let edges : Array[TreeEdge] = []
  // 深度方向（根→叶的分层轴）与横铺方向（叶均分轴）
  let start_p = if vertical { y0 } else { x0 }
  let span_p = if vertical { y1 - y0 } else { x1 - x0 }
  let start_c = if vertical { x0 } else { y0 }
  let span_c = if vertical { x1 - x0 } else { y1 - y0 }
  if n_leaves > 0 {
    let leaf_i = Ref(0)
    // 深度 d → 分层轴坐标（最深叶贴末端；单层树全部落在起点）
    fn depth_pos(d : Int) -> Double {
      if max_depth <= 0 {
        start_p
      } else {
        start_p + span_p * d.to_double() / max_depth.to_double()
      }
    }

    // 第 k 个（DFS 序）叶子 → 横铺轴槽位中心
    fn slot(k : Int) -> Double {
      tree_leaf_slot(k, n_leaves, start_c, span_c)
    }

    // 深度优先遍历：返回本节点横铺轴坐标（叶子取槽位中心，父节点取子
    // 节点均值）；节点几何登记 boxes（后序：先子后父），折线登记
    // edges（子树边先于父边）。
    fn walk(item : TreeItem, depth : Int) -> Double {
      let kids = item.children
      let ccs : Array[Double] = []
      let cross = if kids.length() == 0 {
        let c = slot(leaf_i.val)
        leaf_i.val = leaf_i.val + 1
        c
      } else {
        for k in kids {
          ccs.push(walk(k, depth + 1))
        }
        let mut sum = 0.0
        for cc in ccs {
          sum = sum + cc
        }
        sum / kids.length().to_double()
      }
      let r = tree_dot_radius(item.value, max_value)
      let dp = depth_pos(depth)
      let (px, py) = if vertical { (cross, dp) } else { (dp, cross) }
      boxes.push({ depth, x: px, y: py, r, is_leaf: kids.length() == 0, })
      if kids.length() > 0 {
        let dc = depth_pos(depth + 1)
        for j in 0..<kids.length() {
          let (cx, cy) = if vertical { (ccs[j], dc) } else { (dc, ccs[j]) }
          edges.push({ pts: tree_elbow(px, py, cx, cy, vertical), })
        }
      }
      cross
    }

    ignore(walk(root, 0))
  }
  { boxes, edges, max_depth, }
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 直角肘线点位：横向为「父-(中点横, 父纵)-(中点横, 子纵)-子」，纵向为
/// 「父-(父横, 中点纵)-(子横, 中点纵)-子」。
fn tree_elbow(
  px : Double,
  py : Double,
  cx : Double,
  cy : Double,
  vertical : Bool,
) -> Array[(Double, Double)] {
  if vertical {
    let my = (py + cy) / 2.0
    [(px, py), (px, my), (cx, my), (cx, cy)]
  } else {
    let mx = (px + cx) / 2.0
    [(px, py), (mx, py), (mx, cy), (cx, cy)]
  }
}

///|
/// 深度渐变着色：根取主题主色、最深层取主色浅色，中间按层线性混色；
/// on_draw 现取主题色（深浅切换即跟随）。
fn tree_depth_color(depth : Int, max_depth : Int) -> String {
  let f = if max_depth <= 0 {
    0.0
  } else {
    let t = depth.to_double() / max_depth.to_double()
    if t < 0.0 {
      0.0
    } else if t > 1.0 {
      1.0
    } else {
      t
    }
  }
  mix_hex(theme_primary(), theme_primary_light(), f)
}

///|
/// DFS 后序展开节点名（与 [tree_layout] boxes 的 push 序一致：先子后
/// 父），供绘制层按盒子下标反查名称，避免给 TreeNodeBox 背名字拷贝。
fn tree_names(root : TreeItem) -> Array[String] {
  let names : Array[String] = []
  fn expand(item : TreeItem) -> Unit {
    for k in item.children {
      expand(k)
    }
    names.push(item.name)
  }
  expand(root)
  names
}

///|
/// 树图绘制（画布坐标，数据已由调用方取出）：先画直角折线连线，再画
/// 节点圆点（盖住连线端点，半径 ∝ value，深度渐变着色），最后画节点名
/// 标签（横向贴圆点右侧、纵向贴圆点下方，按可用宽截断）。根既无名又
/// 无子视为空树，画「暂无数据」。
fn tree_draw(
  p : Painter,
  w : Double,
  h : Double,
  root : TreeItem,
  vertical : Bool,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  if root.name == "" && root.children.length() == 0 {
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
  // 边距：横向为右侧标签留白，纵向为四周标签留白
  let (pad_l, pad_r, pad_t, pad_b) = if vertical {
    (48.0, 48.0, 16.0, 28.0)
  } else {
    (16.0, 96.0, 12.0, 12.0)
  }
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 + 8.0 || y1 <= y0 + 8.0 {
    return
  }
  let lay = tree_layout(root, x0, y0, x1, y1, vertical~)
  if lay.boxes.length() == 0 {
    return
  }
  // 连线（直角肘线）先画，圆点后画盖住端点
  p.set_stroke_color(theme_border())
  for e in lay.edges {
    if e.pts.length() < 2 {
      continue
    }
    p.begin_path()
    p.move_to(e.pts[0].0, e.pts[0].1)
    for i in 1..<e.pts.length() {
      p.line_to(e.pts[i].0, e.pts[i].1)
    }
    p.stroke()
  }
  // 节点圆点（深度渐变着色）+ 名称标签
  let names = tree_names(root)
  let plot_w = x1 - x0
  let col_w = plot_w / (lay.max_depth + 1).to_double()
  let mut n_leaf = 0
  for b in lay.boxes {
    if b.is_leaf {
      n_leaf = n_leaf + 1
    }
  }
  let leaf_w = if n_leaf > 0 { plot_w / n_leaf.to_double() } else { col_w }
  for i, b in lay.boxes {
    p.set_fill_color(tree_depth_color(b.depth, lay.max_depth))
    p.begin_path()
    p.arc(b.x, b.y, b.r, 0.0, tau)
    p.close_path()
    p.fill()
    let avail = if vertical {
      leaf_w.max(24.0)
    } else if b.depth == lay.max_depth {
      (w - 12.0 - (b.x + b.r + 4.0)).max(24.0)
    } else {
      (col_w - b.r * 2.0 - 8.0).max(24.0)
    }
    let name = if i < names.length() { names[i] } else { "" }
    let label = truncate_to(name, avail)
    if label == "" {
      continue
    }
    if vertical {
      p.draw_text(
        label,
        b.x - avail / 2.0,
        b.y + b.r + 2.0,
        avail,
        16.0,
        align=Center,
        valign=Center,
        color=theme_text_regular(),
        wrap=false,
      )
    } else {
      p.draw_text(
        label,
        b.x + b.r + 4.0,
        b.y - 8.0,
        avail,
        16.0,
        align=Start,
        valign=Center,
        color=theme_text_regular(),
        wrap=false,
      )
    }
  }
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 树图（EP Tree）：层级树两形态——默认横向（根居左、叶居右），
/// orientation="vertical" 纵向（根居顶、叶居底）；叶节点沿横铺方向均分
/// 槽位、父节点取子节点中点、深度方向分层定位；连线为直角折线（肘
/// 线）；节点圆点大小 ∝ value（无 value 等大），深度渐变着色（主题主色
/// 现取），节点均带名称标签。root 经 Store 驱动（TreeItem 的 children
/// 为可变子列表，直接 push 增删后 set 即重绘），set 后只
/// schedule_paint 画布不重建视图树；主题切换现取色自动跟随。
/// fill=true 不设固定宽度，横向铺满父容器（跟随窗口伸缩）。
pub fn tree_chart_t(
  root : Store[TreeItem],
  orientation? : String = "horizontal",
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
        tree_draw(p, b.width, b.height, root.get(), tree_vertical(orientation))
      })
      root.subscribe(fn(_r) { ViewLike::schedule_paint(cv) })
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
