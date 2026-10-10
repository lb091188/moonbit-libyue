// Flexbox 布局核心算法。
//
// 按 CSS Flexible Box Layout Module Level 1 的布局流程实现：
// 确定基准尺寸 → 换行 → 解析弹性长度（冻结违规）→ 主轴定位
// （auto margin 优先于 justify-content）→ 交叉轴定尺寸与对齐
// （align-content 处理多行）→ 递归子树。
//
// 宽高语义为 border-box（与 Yoga 一致）：width/height 含自身的
// padding 与 border；aspect-ratio 的比例同样按边框盒计算。
// 尚未实现：跨布局的增量重排与缓存驻留（脏区在集成层做）。
// 内在尺寸（min/max/fit-content）的精确规则见 `intrinsic_border_size` 注释。

///|
let max_dim : Double = 1000000000000000.0

///|
fn is_row(d : FlexDirection) -> Bool {
  match d {
    Row => true
    RowReverse => true
    _ => false
  }
}

///|
fn is_reverse(d : FlexDirection) -> Bool {
  match d {
    RowReverse => true
    ColumnReverse => true
    _ => false
  }
}

///|
fn clamp3(v : Double, lo : Double, hi : Double) -> Double {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// justify-content 在一段剩余空间里的前导偏移（间隙类取 0，间隙由主轴
/// 定位阶段处理；此处用于绝对定位静态位置）。
fn justify_leading(j : JustifyContent, free : Double) -> Double {
  match j {
    FlexStart => 0.0
    FlexEnd => free
    Center => free / 2.0
    SpaceBetween => 0.0
    SpaceAround => 0.0
    SpaceEvenly => 0.0
  }
}

///|
/// align-items 在一段剩余空间里的偏移。
fn align_offset(a : AlignItems, free : Double) -> Double {
  match a {
    FlexEnd => free
    Center => free / 2.0
    _ => 0.0
  }
}

///|
/// 项的交叉轴对齐方式：`align-self` 优先，`auto`（None）继承父容器
/// `align-items`。
fn resolved_align(it : Item, items_align : AlignItems) -> AlignItems {
  match it.node.style.align_self {
    Some(a) => a
    None => items_align
  }
}

///|
/// 项是否参与基线对齐（规范 §9.4：inline 轴平行于主轴 + align-self 为
/// baseline + 交叉轴两侧 margin 均非 auto + 有真实基线）。
fn is_baseline_item(it : Item, items_align : AlignItems, main_is_row : Bool) -> Bool {
  if !main_is_row || it.m.auto_cross_start || it.m.auto_cross_end {
    false
  } else {
    match (resolved_align(it, items_align), it.baseline) {
      (Baseline, Some(_)) => true
      _ => false
    }
  }
}

///|
fn[T] first_some(a : Option[T], b : Option[T]) -> Option[T] {
  match a {
    Some(_) => a
    None => b
  }
}

///|
/// 已解析的四边数值（auto 记数值 0 并带标记）。
priv struct Resolved {
  left : Double
  right : Double
  top : Double
  bottom : Double
  auto_left : Bool
  auto_right : Bool
  auto_top : Bool
  auto_bottom : Bool
}

///|
fn resolve_edges(e : Edges, base_w : Option[Double]) -> Resolved {
  // 百分比 margin/padding/border 一律相对包含块宽度（web 标准）；
  // padding/border 的 Auto 视同 0，margin 的 Auto 保留标记。
  let one = fn(v : Value, is_margin : Bool) -> (Double, Bool) {
    match v {
      Auto =>
        if is_margin {
          (0.0, true)
        } else {
          (0.0, false)
        }
      other => (resolve_value(other, base_w), false)
    }
  }
  let (l, al) = one(e.left, true)
  let (r, ar) = one(e.right, true)
  let (t, at) = one(e.top, true)
  let (b, ab) = one(e.bottom, true)
  {
    left : l,
    right : r,
    top : t,
    bottom : b,
    auto_left : al,
    auto_right : ar,
    auto_top : at,
    auto_bottom : ab,
  }
}

///|
/// 主轴/交叉轴视角下的边距（含 auto 标记）：reverse 翻转主轴起端，
/// 列容器的交叉轴起端随 cross_reverse 翻转（行容器交叉轴是块轴，不受方向影响）。
priv struct AxisMargin {
  mut start : Double
  mut end : Double
  cross_start : Double
  cross_end : Double
  auto_start : Bool
  auto_end : Bool
  auto_cross_start : Bool
  auto_cross_end : Bool
}

///|
fn axis_margin(
  r : Resolved,
  main_is_row : Bool,
  reverse : Bool,
  cross_reverse : Bool,
) -> AxisMargin {
  let (s, e, cs, ce, a_s, a_e, a_cs, a_ce) = if main_is_row {
    let (sv, asv) = if reverse {
      (r.right, r.auto_right)
    } else {
      (r.left, r.auto_left)
    }
    let (ev, aev) = if reverse {
      (r.left, r.auto_left)
    } else {
      (r.right, r.auto_right)
    }
    (sv, ev, r.top, r.bottom, asv, aev, r.auto_top, r.auto_bottom)
  } else {
    let (sv, asv) = if reverse {
      (r.bottom, r.auto_bottom)
    } else {
      (r.top, r.auto_top)
    }
    let (ev, aev) = if reverse {
      (r.top, r.auto_top)
    } else {
      (r.bottom, r.auto_bottom)
    }
    let (csv, acsv) = if cross_reverse {
      (r.right, r.auto_right)
    } else {
      (r.left, r.auto_left)
    }
    let (cev, acev) = if cross_reverse {
      (r.left, r.auto_left)
    } else {
      (r.right, r.auto_right)
    }
    (sv, ev, csv, cev, asv, aev, acsv, acev)
  }
  {
    start : s,
    end : e,
    cross_start : cs,
    cross_end : ce,
    auto_start : a_s,
    auto_end : a_e,
    auto_cross_start : a_cs,
    auto_cross_end : a_ce,
  }
}

///|
priv struct Item {
  node : Node
  m : AxisMargin
  base : Double
  inner_base : Double
  pb_main : Double
  mut content_cross : Double
  hyp_main : Double
  min_main : Double
  max_main : Double
  min_cross : Double
  max_cross : Double
  cross_definite : Option[Double]
  mut baseline : Option[Double]
  grow : Double
  shrink : Double
  mut size_main : Double
  mut final_cross : Double
  mut frozen : Bool
  mut violation : Double
  mut pos_main : Double
  mut pos_cross : Double
}

///|
/// 两个参照尺寸是否同一（逐项比较，避免为比较而构造键元组）。
fn opt_eq(a : Option[Double], b : Option[Double]) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => x == y
    _ => false
  }
}

///|
/// 清空整棵树的测量缓存与内在尺寸缓存。样式没有脏标记、可能在两次布局之间
/// 被改，所以两类缓存在单次 `calculate_layout` 内有效，入口整体清一次。
fn clear_measure_cache(n : Node) -> Unit {
  n.measure_cache.clear()
  n.intrinsic_cache.clear()
  for c in n.children {
    clear_measure_cache(c)
  }
}

///|
/// 贴到网格：按间隔取最近格点。
fn snap(v : Double, interval : Double) -> Double {
  (v / interval).round() * interval
}

///|
/// 像素网格取整的后处理：按**绝对边框**取整，再回推相对父项的坐标。
/// `raw_*` 是父项取整前的绝对起端（用来还原子项的真实绝对边框），
/// `snap_*` 是父项取整后的绝对起端（用来换算子项的相对坐标）。
/// 同一边被相邻两项共用时取整结果一致，故相邻项之间不会留缝；
/// 取整误差落在各条边上，不会累积进子项宽度。
fn round_to_grid(
  n : Node,
  interval : Double,
  raw_l_parent : Double,
  raw_t_parent : Double,
  snap_l_parent : Double,
  snap_t_parent : Double,
) -> Unit {
  let raw_l = raw_l_parent + n.layout_left
  let raw_t = raw_t_parent + n.layout_top
  let l = snap(raw_l, interval)
  let t = snap(raw_t, interval)
  let r = snap(raw_l + n.layout_width, interval)
  let b = snap(raw_t + n.layout_height, interval)
  n.layout_left = l - snap_l_parent
  n.layout_top = t - snap_t_parent
  n.layout_width = r - l
  n.layout_height = b - t
  for c in n.children {
    round_to_grid(c, interval, raw_l, raw_t, l, t)
  }
}

///|
/// 测量节点内容尺寸（带缓存）。同一节点在同一次布局里会被父容器测两轮
/// （base 测量与交叉轴重测），深层子树还会被逐层重复，命中时直接复用尺寸
/// 与基线。
fn measure_content(
  c : Node,
  avail_w : Option[Double],
  avail_h : Option[Double],
) -> (Double, Double) {
  // 命中比较逐项做，避免每次调用都为构造键而分配
  for e in c.measure_cache {
    let (kw, kh) = e.0
    if opt_eq(kw, avail_w) && opt_eq(kh, avail_h) {
      c.baseline = e.1.2
      return (e.1.0, e.1.1)
    }
  }
  let result = measure_content_uncached(c, avail_w, avail_h)
  c.measure_cache.push(((avail_w, avail_h), (result.0, result.1, c.baseline)))
  result
}

///|
/// 测量的实际工作：叶子走 measure 函数，容器递归布局。
/// 两条路径都会同时刷新节点的基线。
fn measure_content_uncached(
  c : Node,
  avail_w : Option[Double],
  avail_h : Option[Double],
) -> (Double, Double) {
  if c.children.length() == 0 {
    let s = c.style
    let pb_w = resolve_value(edge_value(s.padding, 0), avail_w) +
      resolve_value(edge_value(s.padding, 1), avail_w) +
      resolve_value(edge_value(s.border, 0), avail_w) +
      resolve_value(edge_value(s.border, 1), avail_w)
    let pb_h = resolve_value(edge_value(s.padding, 2), avail_w) +
      resolve_value(edge_value(s.padding, 3), avail_w) +
      resolve_value(edge_value(s.border, 2), avail_w) +
      resolve_value(edge_value(s.border, 3), avail_w)
    let iw = avail_w.map(fn(w) { (w - pb_w).max(0.0) })
    let ih = avail_h.map(fn(h) { (h - pb_h).max(0.0) })
    let (cw, ch) = match c.measure {
      Some(f) => f(iw, ih)
      None => (0.0, 0.0)
    }
    let pb_top = resolve_value(edge_value(s.padding, 2), avail_w) +
      resolve_value(edge_value(s.border, 2), avail_w)
    c.baseline =
      match c.baseline_fn {
        Some(g) =>
          match g(iw, ih) {
            Some(b) => Some(pb_top + b)
            None => None
          }
        None => None
      }
    let w = first_some(definite_size(s.width, avail_w), None).unwrap_or(cw + pb_w)
    let h = first_some(definite_size(s.height, avail_h), None).unwrap_or(ch + pb_h)
    (w, h)
  } else {
    layout_into(c, avail_w, avail_h, None, None)
  }
}

///|
/// 内在尺寸口径。
priv enum IntrinsicKind {
  Min
  Max
}

///|
/// 节点沿指定轴的内在尺寸（min-content / max-content），返回**边框盒**尺寸，
/// 不含自身 margin。`base_w` / `base_h` 是本节点百分比尺寸的参照（包含块
/// 内容盒），`want_row` 请求行轴（宽）还是块轴（高）。
/// 带缓存：同一节点同一口径同一参照在一次布局内复用。
fn intrinsic_size(
  n : Node,
  want_row : Bool,
  kind : IntrinsicKind,
  base_w : Option[Double],
  base_h : Option[Double],
) -> Double {
  let is_min = match kind {
    Min => true
    Max => false
  }
  // 命中比较逐项做，避免每次调用都为构造键而分配
  for e in n.intrinsic_cache {
    let (flag, refs) = e.0
    let (kw, kb) = flag
    let (bw, bh) = refs
    if kw == want_row && kb == is_min && opt_eq(bw, base_w) &&
      opt_eq(bh, base_h) {
      return e.1
    }
  }
  let v = intrinsic_border_size(n, want_row, kind, base_w, base_h)
  n.intrinsic_cache.push((((want_row, is_min), (base_w, base_h)), v))
  v
}

///|
/// 节点沿指定轴的内在尺寸（无缓存部分）。规则见
/// `docs/zh/adaptation.md`「布局几何」节 YG3d 条：
/// - 自身在该轴有确定尺寸（Fixed / 可解析 Percent）→ 直接采用（内容可溢出，
///   这正是 `width: min-content` 与 `min-width: min-content` 的差别来源）；
/// - 叶子 → measure 函数按内在探询约定返回的内容尺寸 + 自身 padding/border；
/// - 容器 → in-flow 子项贡献合成（子项的确定尺寸 / min/max 夹取已在其
///   `intrinsic_size` 内完成）：主轴不换行取总和含 gap、换行且求
///   min-content 时取「最宽单项」并按该宽度贪心分行；交叉轴单行取最大项、
///   换行 min-content 取分行之和；最后叠加自身 padding/border，再按本轴
///   的 Fixed / Percent 型 min/max 夹取（关键词型 min/max 在此不夹取，
///   否则自引用）。
/// 不做 aspect-ratio 换算（比例在布局主流程与 §4.5 处单独处理）。
fn intrinsic_border_size(
  n : Node,
  want_row : Bool,
  kind : IntrinsicKind,
  base_w : Option[Double],
  base_h : Option[Double],
) -> Double {
  let s = n.style
  let pb_w = resolve_value(edge_value(s.padding, 0), base_w) +
    resolve_value(edge_value(s.padding, 1), base_w) +
    resolve_value(edge_value(s.border, 0), base_w) +
    resolve_value(edge_value(s.border, 1), base_w)
  let pb_h = resolve_value(edge_value(s.padding, 2), base_w) +
    resolve_value(edge_value(s.padding, 3), base_w) +
    resolve_value(edge_value(s.border, 2), base_w) +
    resolve_value(edge_value(s.border, 3), base_w)
  let style_axis = if want_row { s.width } else { s.height }
  let base_axis = if want_row { base_w } else { base_h }
  let raw = match definite_size(style_axis, base_axis) {
    Some(d) => d
    None =>
      if n.children.length() == 0 {
        // 内在探询直接调测量函数：不走 measure_content，否则探询会把
        // 节点基线覆盖成「不受约束那次测量」的值（基线属于真实布局）
        let is_min = match kind {
          Min => true
          Max => false
        }
        let iw0 = if want_row && is_min {
          Some(0.0)
        } else {
          None
        }
        let ih0 = if !want_row && is_min {
          Some(0.0)
        } else {
          None
        }
        let iw = iw0.map(fn(v) { (v - pb_w).max(0.0) })
        let ih = ih0.map(fn(v) { (v - pb_h).max(0.0) })
        let (cw, ch) = match n.measure {
          Some(f) => f(iw, ih)
          None => (0.0, 0.0)
        }
        let content = if want_row { cw } else { ch }
        let pb = if want_row { pb_w } else { pb_h }
        content + pb
      } else {
        container_intrinsic_size(n, want_row, kind, pb_w, pb_h, base_w, base_h)
      }
  }
  let lo =
    definite_size(if want_row { s.min_width } else { s.min_height }, base_axis)
      .unwrap_or(0.0)
  let hi =
    definite_size(if want_row { s.max_width } else { s.max_height }, base_axis)
      .unwrap_or(max_dim)
  clamp3(raw, lo, hi)
}

///|
/// 容器的内在尺寸（内容盒部分，不含自身 padding/border）。
fn container_intrinsic_size(
  n : Node,
  want_row : Bool,
  kind : IntrinsicKind,
  pb_w : Double,
  pb_h : Double,
  base_w : Option[Double],
  base_h : Option[Double],
) -> Double {
  let s = n.style
  let main_is_row = is_row(s.flex_direction)
  let wrap_on = match s.flex_wrap {
    NoWrap => false
    _ => true
  }
  let main_gap = if main_is_row { s.column_gap } else { s.row_gap }
  let cross_gap = if main_is_row { s.row_gap } else { s.column_gap }
  // 子项百分比参照：本节点该轴确定尺寸的内容盒；不受约束时不解析
  let cb_w = definite_size(s.width, base_w).map(fn(v) { (v - pb_w).max(0.0) })
  let cb_h = definite_size(s.height, base_h).map(fn(v) { (v - pb_h).max(0.0) })
  // 只要请求的是交叉轴才需要子项的交叉贡献；换行 + min-content 请求交叉轴时
  // 还要按 min-content 主轴宽度分行，故保留逐项贡献。内在尺寸递归量大，
  // 少算一半子项直接决定布局成本（bench 实测）。
  let ask_main = want_row == main_is_row
  let need_cross = !ask_main
  let is_min = match kind {
    Min => true
    Max => false
  }
  let split_lines = need_cross && is_min && wrap_on
  let contribs : Array[(Double, Double)] = []
  let mut main_sum = 0.0
  let mut main_max = 0.0
  let mut cross_max = 0.0
  let mut count = 0
  for c in n.children {
    match c.style.display {
      None => continue
      Flex => ()
    }
    match c.style.position {
      Absolute => continue
      Relative => ()
    }
    // 内在尺寸计算里 auto margin 按 0 处理（规范 §9.9）
    let m = resolve_edges(c.style.margin, cb_w)
    let (margin_main, margin_cross) = if main_is_row {
      (m.left + m.right, m.top + m.bottom)
    } else {
      (m.top + m.bottom, m.left + m.right)
    }
    let cm = intrinsic_size(c, main_is_row, kind, cb_w, cb_h) + margin_main
    main_sum = main_sum + cm
    if cm > main_max {
      main_max = cm
    }
    count = count + 1
    if need_cross {
      let cc = intrinsic_size(c, !main_is_row, kind, cb_w, cb_h) + margin_cross
      if cc > cross_max {
        cross_max = cc
      }
      if split_lines {
        contribs.push((cm, cc))
      }
    }
  }
  if count == 0 {
    return if want_row { pb_w } else { pb_h }
  }
  let one_main = main_sum + (main_gap * (count - 1).to_double()).max(0.0)
  let cross_size = if split_lines {
    // 换行容器在 min-content 主轴宽度下贪心分行：交叉轴为各行之和
    let mut total_cross = 0.0
    let mut line_count = 0
    let mut lm = 0.0
    let mut lc = 0.0
    let mut has = false
    for p in contribs {
      if has && lm + main_gap + p.0 > main_max {
        total_cross = total_cross + lc + (if line_count > 0 { cross_gap } else { 0.0 })
        line_count = line_count + 1
        lm = p.0
        lc = p.1
      } else {
        if has {
          lm = lm + main_gap
        }
        lm = lm + p.0
        if !has || p.1 > lc {
          lc = p.1
        }
        has = true
      }
    }
    if has {
      total_cross = total_cross + lc + (if line_count > 0 { cross_gap } else { 0.0 })
    }
    total_cross
  } else {
    cross_max
  }
  // 主轴：max-content 或 nowrap 时单项不折行全放一行；
  // min-content 且可换行时只需装下最宽单项
  let main_size = if is_min && wrap_on { main_max } else { one_main }
  let axis = if ask_main { main_size } else { cross_size }
  axis + (if want_row { pb_w } else { pb_h })
}

///|
/// 带节点上下文的尺寸取值解析：`Fixed` / `Percent` 同 `definite_size`，
/// 内在关键词按节点的内在尺寸给出确定值。`want_row` 决定取宽还是高，
/// `base_w` / `base_h` 为百分比参照。
fn axis_size(
  n : Node,
  v : Value,
  want_row : Bool,
  base_w : Option[Double],
  base_h : Option[Double],
) -> Option[Double] {
  let base_axis = if want_row { base_w } else { base_h }
  match v {
    MinContent => Some(intrinsic_size(n, want_row, Min, base_w, base_h))
    MaxContent => Some(intrinsic_size(n, want_row, Max, base_w, base_h))
    FitContent =>
      match base_axis {
        Some(av) => {
          let lo = intrinsic_size(n, want_row, Min, base_w, base_h)
          let hi = intrinsic_size(n, want_row, Max, base_w, base_h)
          Some(lo.max(av.min(hi)))
        }
        None => Some(intrinsic_size(n, want_row, Max, base_w, base_h))
      }
    other => definite_size(other, base_axis)
  }
}

///|
/// 对节点做布局：返回其 border-box (width, height)。
/// avail_w/h 为父内容盒给到本节点的可用空间；pinned_w/h 由父级
/// 弹性解析后钦定的最终尺寸（覆盖自身 style/内容推算）。
fn layout_into(
  node : Node,
  avail_w : Option[Double],
  avail_h : Option[Double],
  pinned_w : Option[Double],
  pinned_h : Option[Double],
) -> (Double, Double) {
  let s = node.style
  match s.display {
    None => {
      node.layout_width = 0.0
      node.layout_height = 0.0
      return (0.0, 0.0)
    }
    Flex => ()
  }
  // 自身 padding/border 的百分比参照：包含块宽度 = 可用宽
  let own_pad = resolve_edges(s.padding, avail_w)
  let own_border = resolve_edges(s.border, avail_w)
  let pad_border_w = own_pad.left + own_pad.right + own_border.left + own_border.right
  let pad_border_h = own_pad.top + own_pad.bottom + own_border.top + own_border.bottom
  // ---- 叶子节点：pinned / style / 内容 ----
  if node.children.length() == 0 {
    let iw = avail_w.map(fn(x) { (x - pad_border_w).max(0.0) })
    let ih = avail_h.map(fn(x) { (x - pad_border_h).max(0.0) })
    let (cw, ch) = match node.measure {
      Some(f) => f(iw, ih)
      None => (0.0, 0.0)
    }
    let w0_ = first_some(pinned_w, axis_size(node, s.width, true, avail_w, avail_h))
    let h0_ = first_some(pinned_h, axis_size(node, s.height, false, avail_w, avail_h))
    // 首选比例（border-box 语义：比例 = 宽/高）：一个轴确定 → 另一轴换算
    let w0 = match (w0_, h0_, s.aspect_ratio) {
      (None, Some(h), Some(r)) => Some(h * r)
      _ => w0_
    }
    let h0 = match (w0, h0_, s.aspect_ratio) {
      (Some(w), None, Some(r)) => Some(w / r)
      _ => h0_
    }
    let w = clamp3(
      w0.unwrap_or(cw + pad_border_w),
      axis_size(node, s.min_width, true, avail_w, avail_h).unwrap_or(0.0),
      axis_size(node, s.max_width, true, avail_w, avail_h).unwrap_or(max_dim),
    )
    let h = clamp3(
      h0.unwrap_or(ch + pad_border_h),
      axis_size(node, s.min_height, false, avail_w, avail_h).unwrap_or(0.0),
      axis_size(node, s.max_height, false, avail_w, avail_h).unwrap_or(max_dim),
    )
    node.layout_width = w
    node.layout_height = h
    // 基线：测量函数给的是「基线到内容盒顶部」，叠加自身 padding/border 后
    // 才是到边框盒顶部的距离（与 measure 的语义对称）
    node.baseline =
      match node.baseline_fn {
        Some(f) =>
          match f(iw, ih) {
            Some(b) => Some(own_border.top + own_pad.top + b)
            None => None
          }
        None => None
      }
    return (w, h)
  }
  let main_is_row = is_row(s.flex_direction)
  let rtl = match s.direction {
    Rtl => true
    Ltr => false
  }
  // 行容器：direction 与 row-reverse 各翻一次（XOR）；列容器：主轴是块轴，
  // direction 只翻交叉轴（inline 轴）
  let rev_main = is_reverse(s.flex_direction) != (rtl && main_is_row)
  let rev_cross = rtl && !main_is_row
  // 自身尺寸（确定值）
  let own_w_def =
    first_some(pinned_w, axis_size(node, s.width, true, avail_w, avail_h))
  let own_h_def =
    first_some(pinned_h, axis_size(node, s.height, false, avail_w, avail_h))
  // 子项百分比参照：本节点内容盒确定尺寸优先，退回可用空间
  let child_pct_w = first_some(own_w_def.map(fn(w) { (w - pad_border_w).max(0.0) }), avail_w)
  let child_pct_h = first_some(own_h_def.map(fn(h) { (h - pad_border_h).max(0.0) }), avail_h)
  let avail_main = if main_is_row { avail_w } else { avail_h }
  let pad_border_main = if main_is_row { pad_border_w } else { pad_border_h }
  let pad_border_cross = if main_is_row { pad_border_h } else { pad_border_w }
  let inner_main_avail = avail_main.map(fn(v) { (v - pad_border_main).max(0.0) })
  let own_main_def = if main_is_row { own_w_def } else { own_h_def }
  let own_cross_def = if main_is_row { own_h_def } else { own_w_def }
  // 主轴无确定尺寸、但交叉轴确定且有比例 → 主轴按比例换算后视同确定
  let ratio_main_own = match (s.aspect_ratio, own_cross_def) {
    (Some(r), Some(cv)) => {
      let bb = if main_is_row { (cv * r).max(0.0) } else { cv / r }
      Some((bb - pad_border_main).max(0.0))
    }
    _ => None
  }
  let inner_main = first_some(
    own_main_def.map(fn(v) { (v - pad_border_main).max(0.0) }),
    ratio_main_own,
  )
  // 交叉轴无确定尺寸、但主轴确定且有比例 → 交叉轴按比例换算后视同确定
  // （参与行交叉尺寸与 stretch，否则容器撑不开子项）
  let ratio_cross = match (s.aspect_ratio, own_main_def) {
    (Some(r), Some(mv)) => {
      let bb = if main_is_row { (mv / r).max(0.0) } else { mv * r }
      Some((bb - pad_border_cross).max(0.0))
    }
    _ => None
  }
  let inner_cross = first_some(
    own_cross_def.map(fn(v) { (v - pad_border_cross).max(0.0) }),
    ratio_cross,
  )
  let main_gap = if main_is_row { s.column_gap } else { s.row_gap }
  let cross_gap = if main_is_row { s.row_gap } else { s.column_gap }
  let wrap_limit = first_some(inner_main, inner_main_avail)
  // ---- 构建 flex 项 ----
  let items : Array[Item] = []
  let abs_children : Array[Node] = []
  for c in node.children {
    match c.style.display {
      None => continue
      Flex => ()
    }
    match c.style.position {
      Absolute => {
        // 脱离文档流：不参与换行 / 弹性解析 / 容器尺寸计算
        abs_children.push(c)
        continue
      }
      Relative => ()
    }
    let cm = resolve_edges(c.style.margin, child_pct_w)
    let m = axis_margin(cm, main_is_row, rev_main, rev_cross)
    let c_pb_main = if main_is_row {
      resolve_value(edge_value(c.style.padding, 0), child_pct_w) +
      resolve_value(edge_value(c.style.padding, 1), child_pct_w) +
      resolve_value(edge_value(c.style.border, 0), child_pct_w) +
      resolve_value(edge_value(c.style.border, 1), child_pct_w)
    } else {
      resolve_value(edge_value(c.style.padding, 2), child_pct_w) +
      resolve_value(edge_value(c.style.padding, 3), child_pct_w) +
      resolve_value(edge_value(c.style.border, 2), child_pct_w) +
      resolve_value(edge_value(c.style.border, 3), child_pct_w)
    }
    let child_main_style = if main_is_row { c.style.width } else { c.style.height }
    let child_cross_style = if main_is_row { c.style.height } else { c.style.width }
    let c_avail_main = first_some(
      axis_size(c, child_main_style, main_is_row, child_pct_w, child_pct_h),
      wrap_limit,
    )
    let c_avail_cross = first_some(
      axis_size(c, child_cross_style, !main_is_row, child_pct_w, child_pct_h),
      first_some(own_cross_def.map(fn(v) { (v - pad_border_cross).max(0.0) }), None),
    )
    let content = if main_is_row {
      measure_content(c, c_avail_main, c_avail_cross)
    } else {
      let (w, h) = measure_content(c, c_avail_cross, c_avail_main)
      (h, w)
    }
    let content_cross0 = content.1
    let basis_val = match s.flex_basis {
      Auto => child_main_style
      v => v
    }
    let cross_definite = axis_size(
      c,
      child_cross_style,
      !main_is_row,
      child_pct_w,
      child_pct_h,
    )
    // 规范 §9.2：有首选比例 + 基准为 content + 交叉轴尺寸确定 → 主轴基准由比例换算
    let ratio_main = match (c.style.aspect_ratio, cross_definite) {
      (Some(r), Some(cv)) => Some(if main_is_row { cv * r } else { cv / r })
      _ => None
    }
    // 内在探询按需要做：基准已由显式尺寸 / 比例给出时不再探 max-content，
    // 显式 min-* 已定时不再探 min-content（探到的值会被丢弃）。
    // 递归到子树代价不低，这一层短路是热路径的主要止损点。
    let basis_style =
      first_some(
        axis_size(c, basis_val, main_is_row, child_pct_w, child_pct_h),
        ratio_main,
      )
    let base = basis_style.unwrap_or(intrinsic_size(
      c,
      main_is_row,
      Max,
      child_pct_w,
      child_pct_h,
    ))
    let min_v = if main_is_row { c.style.min_width } else { c.style.min_height }
    let min_style = axis_size(c, min_v, main_is_row, child_pct_w, child_pct_h)
    // web 语义：主轴 min:auto → 规范 §4.5 的 content size suggestion，
    // 即该项在主轴上的 **min-content 尺寸**（不再用「当前可用空间下的测量值」
    // 近似，否则文本会被压到最长词以下）；有比例换算值时不超过它。
    // 显式 Fixed(0) 才是 0。
    let min_main = match min_style {
      Some(v) => v
      None => {
        let mc =
          intrinsic_size(c, main_is_row, Min, child_pct_w, child_pct_h)
        match ratio_main {
          Some(t) => mc.min(t)
          None => mc
        }
      }
    }
    let max_v = if main_is_row { c.style.max_width } else { c.style.max_height }
    let max_main = axis_size(c, max_v, main_is_row, child_pct_w, child_pct_h)
      .unwrap_or(max_dim)
    let cmin_v = if main_is_row { c.style.min_height } else { c.style.min_width }
    let min_cross =
      axis_size(c, cmin_v, !main_is_row, child_pct_w, child_pct_h)
        .unwrap_or(0.0)
    let cmax_v = if main_is_row { c.style.max_height } else { c.style.max_width }
    let max_cross =
      axis_size(c, cmax_v, !main_is_row, child_pct_w, child_pct_h)
        .unwrap_or(max_dim)
    items.push({
      node : c,
      m,
      base,
      inner_base : (base - c_pb_main).max(0.0),
      pb_main : c_pb_main,
      content_cross : content_cross0,
      hyp_main : clamp3(base, min_main, max_main),
      min_main,
      max_main,
      min_cross,
      max_cross,
      cross_definite,
      baseline : c.baseline,
      grow : c.style.flex_grow,
      shrink : c.style.flex_shrink,
      size_main : 0.0,
      final_cross : 0.0,
      frozen : false,
      violation : 0.0,
      pos_main : 0.0,
      pos_cross : 0.0,
    })
  }
  // ---- 换行 ----
  let lines : Array[Array[Item]] = []
  let wrap_on = match s.flex_wrap {
    NoWrap => false
    _ => true
  }
  let has_limit = match wrap_limit {
    Some(_) => true
    None => false
  }
  let can_wrap = wrap_on && has_limit
  if can_wrap {
    let mut cur : Array[Item] = []
    let mut used = 0.0
    let limit = wrap_limit.unwrap_or(0.0)
    for it in items {
      let outer = it.hyp_main + it.m.start + it.m.end
      let need = if cur.length() > 0 { outer + main_gap } else { outer }
      if cur.length() > 0 && used + need > limit + 0.000001 {
        lines.push(cur)
        cur = [it]
        used = outer
      } else {
        cur.push(it)
        used = used + need
      }
    }
    if cur.length() > 0 {
      lines.push(cur)
    }
  } else {
    lines.push(items)
  }
  // ---- 逐行：弹性解析 → 主轴定位 → 交叉轴内容尺寸 ----
  let nlines = lines.length()
  let line_crosses : Array[Double] = []
  let line_ascents : Array[Option[Double]] = []
  for line in lines {
    for it in line {
      it.size_main = it.hyp_main
      it.frozen = false
    }
    match inner_main {
      Some(im) =>
        // 按 CSS Flexbox §9.7 逐条实现：
        // 目标尺寸从 flex base 起步，先冻结不弹性项，循环内按违规
        // 正负选择性冻结；shrink 加权用内基准尺寸；弹性因子和 <1 时
        // 以「初始剩余空间 × 因子和」封顶。
        {
          let sum_hyp_outer = line.iter().fold(init=0.0, fn(acc, it) {
            acc + it.hyp_main + it.m.start + it.m.end
          })
          let use_grow = sum_hyp_outer < im
          // 目标尺寸初始化为 flex base；冻结不弹性项
          for it in line {
            let factor = if use_grow { it.grow } else { it.shrink }
            if factor == 0.0 ||
              (use_grow && it.base > it.hyp_main) ||
              (!use_grow && it.base < it.hyp_main) {
              it.size_main = it.hyp_main
              it.frozen = true
            } else {
              it.size_main = it.base
              it.frozen = false
            }
          }
          let outer_of = fn(it : Item) -> Double {
            let size = if it.frozen { it.size_main } else { it.base }
            size + it.m.start + it.m.end
          }
          let initial_free = im - line.iter().fold(init=0.0, fn(acc, it) { acc + outer_of(it) })
          let mut done = line.iter().all(fn(it) { it.frozen })
          let mut rounds = 0
          while !done && rounds < line.length() + 2 {
            rounds = rounds + 1
            let mut remaining = im -
              line.iter().fold(init=0.0, fn(acc, it) { acc + outer_of(it) })
            let factor_sum = line.iter().fold(init=0.0, fn(acc, it) {
              if it.frozen {
                acc
              } else if use_grow {
                acc + it.grow
              } else {
                acc + (it.shrink * it.inner_base).max(0.0)
              }
            })
            if factor_sum > 0.0 && factor_sum < 1.0 {
              let scaled = initial_free * factor_sum
              if scaled.abs() < remaining.abs() {
                remaining = scaled
              }
            }
            if remaining != 0.0 && factor_sum > 0.0 {
              for it in line {
                if it.frozen {
                  continue
                }
                let factor = if use_grow {
                  it.grow
                } else {
                  (it.shrink * it.inner_base).max(0.0)
                }
                it.size_main = if use_grow {
                  it.base + remaining * factor / factor_sum
                } else {
                  it.base - remaining.abs() * factor / factor_sum
                }
              }
            }
            // 修 min/max 违规并按总违规正负选择性冻结
            let mut total_violation = 0.0
            for it in line {
              if it.frozen {
                it.violation = 0.0
                continue
              }
              let unclamped = it.size_main
              let clamped = clamp3(unclamped, it.min_main, it.max_main).max(it.pb_main)
              it.violation = clamped - unclamped
              it.size_main = clamped
              total_violation = total_violation + it.violation
            }
            for it in line {
              if it.frozen {
                continue
              }
              let freeze_it = if total_violation == 0.0 {
                true
              } else if total_violation > 0.0 {
                // 正违规 = 被 min 抬大 → 冻结 min 违规项
                it.violation > 0.0
              } else {
                // 负违规 = 被 max 压小 → 冻结 max 违规项
                it.violation < 0.0
              }
              if freeze_it {
                it.frozen = true
              }
            }
            done = line.iter().all(fn(it) { it.frozen })
          }
        }
      None => ()
    }

    // 主轴 auto margin 吸收（优先于 justify-content）
    let sum_fixed = line.iter().fold(init=0.0, fn(acc, it) {
      acc + it.size_main + it.m.start + it.m.end
    })
    let free = match inner_main {
      Some(im) => im - sum_fixed
      None => 0.0
    }
    let auto_count = line.iter().fold(init=0, fn(acc, it) {
      acc +
        (if it.m.auto_start { 1 } else { 0 }) +
        (if it.m.auto_end { 1 } else { 0 })
    })
    let mut seq = false
    if free > 0.0 && auto_count > 0 {
      let share = free / auto_count.to_double()
      for it in line {
        if it.m.auto_start {
          it.m.start = it.m.start + share
        }
        if it.m.auto_end {
          it.m.end = it.m.end + share
        }
      }
      seq = true
    }
    // justify-content 定位
    let n = line.length()
    let free2 = match inner_main {
      Some(im) => im - line.iter().fold(init=0.0, fn(acc, it) {
        acc + it.size_main + it.m.start + it.m.end
      })
      None => 0.0
    }
    let (leading, between) = if seq {
      (0.0, 0.0)
    } else {
      match inner_main {
        Some(_) =>
          match s.justify_content {
            FlexStart => (0.0, 0.0)
            FlexEnd => (free2, 0.0)
            Center => (free2 / 2.0, 0.0)
            SpaceBetween => (0.0, if n > 1 { free2 / (n - 1).to_double() } else { 0.0 })
            SpaceAround => (
              if n > 0 { free2 / (2.0 * n.to_double()) } else { 0.0 },
              if n > 0 { free2 / n.to_double() } else { 0.0 },
            )
            SpaceEvenly => (free2 / (n + 1).to_double(), free2 / (n + 1).to_double())
          }
        None => (0.0, 0.0)
      }
    }
    let mut cursor = leading
    for it in line {
      it.pos_main = cursor + it.m.start
      cursor = cursor + it.m.start + it.size_main + it.m.end + main_gap + between
    }
    // 交叉轴内容尺寸（用最终主尺寸约束重测）
    for it in line {
      match it.cross_definite {
        Some(v) => it.final_cross = v
        None =>
          match it.node.style.aspect_ratio {
            // 规范 §9.4：主轴尺寸已定（含弹性解析结果）→ 交叉轴假想尺寸由比例换算
            Some(r) => {
              let derived = if main_is_row {
                (it.size_main / r).max(0.0)
              } else {
                it.size_main * r
              }
              it.final_cross = clamp3(derived, it.min_cross, it.max_cross)
            }
            None => {
              // 规范 §9.4：以已用主尺寸约束重测内容交叉尺寸
              let cim = (it.size_main - it.pb_main).max(0.0)
              let content = if main_is_row {
                measure_content(it.node, Some(cim), None)
              } else {
                let (w, h) = measure_content(it.node, None, Some(cim))
                (h, w)
              }
              it.content_cross = content.1
              it.final_cross = clamp3(it.content_cross, it.min_cross, it.max_cross)
              it.baseline = it.node.baseline
            }
          }
      }
    }
    let content_cross = line.iter().fold(init=0.0, fn(acc, it) {
      let outer = it.final_cross + it.m.cross_start + it.m.cross_end
      if outer > acc {
        outer
      } else {
        acc
      }
    })
    // 规范 §9.4：基线分组——参与基线对齐的项取「基线到外沿交叉起端」最大值
    // 与「基线到外沿交叉末端」最大值，两者之和即本行的基线尺寸
    let mut max_ascent = 0.0
    let mut max_descent = 0.0
    let mut baseline_items = 0
    for it in line {
      if is_baseline_item(it, s.align_items, main_is_row) {
        let b = it.baseline.unwrap_or(0.0)
        let ascent = it.m.cross_start + b
        let descent = it.final_cross + it.m.cross_end - b
        if ascent > max_ascent {
          max_ascent = ascent
        }
        if descent > max_descent {
          max_descent = descent
        }
        baseline_items = baseline_items + 1
      }
    }
    let baseline_cross = if baseline_items > 0 {
      max_ascent + max_descent
    } else {
      0.0
    }
    line_ascents.push(if baseline_items > 0 { Some(max_ascent) } else { None })
    // 规范 §9.6：单行且容器交叉轴确定时，行交叉尺寸 = 容器内交叉尺寸
    let line_cross = if nlines == 1 {
      match inner_cross {
        Some(ic) => ic
        None => content_cross.max(baseline_cross)
      }
    } else {
      content_cross.max(baseline_cross)
    }
    line_crosses.push(line_cross)
  }
  // ---- 整行分布（align-content）----
  let own_cross_content = line_crosses.iter().fold(init=0.0, fn(acc, v) { acc + v }) +
    (cross_gap * (nlines - 1).to_double()).max(0.0)
  let wrap_reverse = match s.flex_wrap {
    WrapReverse => true
    _ => false
  }
  let line_offsets : Array[Double] = []
  for _i in 0..<nlines {
    line_offsets.push(0.0)
  }
  if nlines > 0 {
    if wrap_reverse {
      // 行序翻转：从交叉轴末端反向堆叠（Stretch 不适用于翻转序）
      let total = match inner_cross {
        Some(ic) => if ic > own_cross_content { ic } else { own_cross_content }
        None => own_cross_content
      }
      let mut from_end = total
      for i in 0..<nlines {
        from_end = from_end - line_crosses[i]
        line_offsets[i] = from_end
        from_end = from_end - cross_gap
      }
    } else {
      match inner_cross {
        Some(ic) => {
          let extra = ic - own_cross_content
          let mut offset = 0.0
          let mut spacing = 0.0
          match s.align_content {
            Stretch =>
              if extra > 0.0 {
                let add = extra / nlines.to_double()
                for i in 0..<nlines {
                  line_crosses[i] = line_crosses[i] + add
                }
              }
            FlexStart => ()
            FlexEnd => offset = extra
            Center => offset = extra / 2.0
            SpaceBetween =>
              if nlines > 1 && extra > 0.0 {
                spacing = extra / (nlines - 1).to_double()
              }
            SpaceAround =>
              if extra > 0.0 {
                spacing = extra / nlines.to_double()
                offset = spacing / 2.0
              }
            SpaceEvenly =>
              if extra > 0.0 {
                spacing = extra / (nlines + 1).to_double()
                offset = spacing
              }
          }
          let mut cur = offset
          for i in 0..<nlines {
            line_offsets[i] = cur
            cur = cur + line_crosses[i] + cross_gap + spacing
          }
        }
        None => {
          let mut cur = 0.0
          for i in 0..<nlines {
            line_offsets[i] = cur
            cur = cur + line_crosses[i] + cross_gap
          }
        }
      }
    }
  }
  // ---- 逐项：交叉轴定尺寸与对齐 → 坐标映射 → 递归子树 ----
  let inner_w = own_w_def.map(fn(v) { (v - pad_border_w).max(0.0) })
  let inner_h = own_h_def.map(fn(v) { (v - pad_border_h).max(0.0) })
  // 各行外沿主轴尺寸的最大值：既作容器内容推算的主轴尺寸，也作主轴
  // 无确定尺寸时翻转定位的参照（否则 row-reverse 的 auto 宽容器会算出负偏移）
  let line_main_of = fn(line : Array[Item]) -> Double {
    line.iter().fold(init=0.0, fn(acc, it) {
      acc + it.size_main + it.m.start + it.m.end
    }) +
    (main_gap * (line.length() - 1).to_double()).max(0.0)
  }
  let mut line_main_max = 0.0
  for line in lines {
    let v = line_main_of(line)
    if v > line_main_max {
      line_main_max = v
    }
  }
  let flip_main_ref = match inner_main {
    Some(v) => v
    None => line_main_max
  }
  let flip_cross_ref = match inner_cross {
    Some(v) => v
    None => own_cross_content
  }
  for li in 0..<nlines {
    let line = lines[li]
    let lc = line_crosses[li]
    let loff = line_offsets[li]
    for it in line {
      let align = resolved_align(it, s.align_items)
      let has_cross_auto = it.m.auto_cross_start || it.m.auto_cross_end
      match it.cross_definite {
        Some(_) => ()
        None =>
          if !has_cross_auto {
            match align {
              Stretch =>
                it.final_cross = clamp3(
                  lc - it.m.cross_start - it.m.cross_end,
                  it.min_cross,
                  it.max_cross,
                )
              _ => ()
            }
          }
      }
      let outer = it.final_cross + it.m.cross_start + it.m.cross_end
      let free_c = lc - outer
      let off = if has_cross_auto {
        if it.m.auto_cross_start && it.m.auto_cross_end {
          free_c / 2.0
        } else if it.m.auto_cross_start {
          free_c
        } else {
          0.0
        }
      } else {
        match align {
          FlexEnd => free_c
          Center => free_c / 2.0
          // 规范 §9.6：升距最大的项贴行交叉起端，其余项按共同基线定位
          Baseline =>
            match (line_ascents[li], it.baseline) {
              (Some(a), Some(b)) => (a - it.m.cross_start - b).max(0.0)
              _ => 0.0
            }
          _ => 0.0
        }
      }
      it.pos_cross = loff + off + it.m.cross_start
      let c_w = if main_is_row { it.size_main } else { it.final_cross }
      let c_h = if main_is_row { it.final_cross } else { it.size_main }
      let m_pos = if rev_main {
        flip_main_ref - it.pos_main - it.size_main
      } else {
        it.pos_main
      }
      let c_pos = if rev_cross {
        flip_cross_ref - it.pos_cross - it.final_cross
      } else {
        it.pos_cross
      }
      let x = if main_is_row { m_pos } else { c_pos }
      let y = if main_is_row { c_pos } else { m_pos }
      it.node.layout_left = own_border.left + own_pad.left + x
      it.node.layout_top = own_border.top + own_pad.top + y
      if it.node.children.length() > 0 {
        let _ = layout_into(it.node, inner_w, inner_h, Some(c_w), Some(c_h))
      } else {
        it.node.layout_width = c_w
        it.node.layout_height = c_h
      }
    }
  }
  // ---- 本节点的基线（规范 §8.5 容器基线）----
  // 首行有基线对齐项 → 取该行共同基线；否则取交叉轴起端最靠前的
  // 有基线 in-flow 项（含嵌套容器上抛的基线），无则本节点无基线。
  let mut first_top = max_dim
  let mut item_baseline : Option[Double] = None
  for line in lines {
    for it in line {
      match it.node.baseline {
        Some(b) =>
          if it.node.layout_top < first_top {
            first_top = it.node.layout_top
            item_baseline = Some(it.node.layout_top + b)
          }
        None => ()
      }
    }
  }
  node.baseline =
    if nlines > 0 {
      match line_ascents[0] {
        Some(a) => Some(own_border.top + own_pad.top + line_offsets[0] + a)
        None => item_baseline
      }
    } else {
      None
    }
  // ---- 自身尺寸 ----
  // 内容推算出的自身尺寸要含自身 padding/border（宽高语义为 border-box）
  let content_main_sum = line_main_max + pad_border_main
  let own_main0 = match own_main_def {
    Some(v) => v
    None =>
      match inner_main {
        Some(im) => im + pad_border_main
        None => content_main_sum
      }
  }
  let own_cross0 = match own_cross_def {
    Some(v) => v
    None =>
      match inner_cross {
        Some(ic) => ic + pad_border_cross
        None => own_cross_content + pad_border_cross
      }
  }
  let own_main = clamp3(
    own_main0,
    axis_size(
      node,
      if main_is_row { s.min_width } else { s.min_height },
      main_is_row,
      child_pct_w,
      child_pct_h,
    ).unwrap_or(0.0),
    axis_size(
      node,
      if main_is_row { s.max_width } else { s.max_height },
      main_is_row,
      child_pct_w,
      child_pct_h,
    ).unwrap_or(max_dim),
  )
  let own_cross = clamp3(
    own_cross0,
    axis_size(
      node,
      if main_is_row { s.min_height } else { s.min_width },
      !main_is_row,
      child_pct_w,
      child_pct_h,
    ).unwrap_or(0.0),
    axis_size(
      node,
      if main_is_row { s.max_height } else { s.max_width },
      !main_is_row,
      child_pct_w,
      child_pct_h,
    ).unwrap_or(max_dim),
  )
  let w = if main_is_row { own_main } else { own_cross }
  let h = if main_is_row { own_cross } else { own_main }
  node.layout_width = w
  node.layout_height = h
  // ---- 绝对定位子项：包含块 = 本节点 padding box ----
  if abs_children.length() > 0 {
    let cb_w = (w - own_border.left - own_border.right).max(0.0)
    let cb_h = (h - own_border.top - own_border.bottom).max(0.0)
    let cbw = Some(cb_w)
    let cbh = Some(cb_h)
    // 静态位置随所属轴的翻转标志走（含 row/column-reverse 与 rtl）
    let h_rev = if main_is_row { rev_main } else { rev_cross }
    let v_rev = if main_is_row { rev_cross } else { rev_main }
    for c in abs_children {
      let cs = c.style
      let cm = resolve_edges(cs.margin, cbw)
      let cp = resolve_edges(cs.padding, cbw)
      let cbd = resolve_edges(cs.border, cbw)
      let cpb_w = cp.left + cp.right + cbd.left + cbd.right
      let cpb_h = cp.top + cp.bottom + cbd.top + cbd.bottom
      let ins_l = definite_size(cs.left, cbw)
      let ins_r = definite_size(cs.right, cbw)
      let ins_t = definite_size(cs.top, cbh)
      let ins_b = definite_size(cs.bottom, cbh)
      // 尺寸：显式宽高（含内在关键词）优先；同轴两侧 inset 都设时由 inset
      // 撑出；否则内容
      let sized_w = match axis_size(c, cs.width, true, cbw, cbh) {
        Some(v) => Some(v.max(cpb_w))
        None =>
          match (ins_l, ins_r) {
            (Some(lv), Some(rv)) => Some((cb_w - lv - rv - cm.left - cm.right).max(cpb_w))
            _ => None
          }
      }
      let sized_h = match axis_size(c, cs.height, false, cbw, cbh) {
        Some(v) => Some(v.max(cpb_h))
        None =>
          match (ins_t, ins_b) {
            (Some(tv), Some(bv)) => Some((cb_h - tv - bv - cm.top - cm.bottom).max(cpb_h))
            _ => None
          }
      }
      // 首选比例（border-box 语义）：一轴已由显式尺寸或两侧 inset 定下,
      // 另一轴按比例换算
      let sized_w = match (sized_w, sized_h, cs.aspect_ratio) {
        (None, Some(hv), Some(r)) => Some((hv * r).max(cpb_w))
        _ => sized_w
      }
      let sized_h = match (sized_w, sized_h, cs.aspect_ratio) {
        (Some(wv), None, Some(r)) => Some((wv / r).max(cpb_h))
        _ => sized_h
      }
      // 内容测量的可用空间以 AtMost 形式传给测量函数（是否折行/收缩由测量
      // 函数决定，引擎不额外截断——固定内容尺寸的叶子因此不会被压小）
      let avail_w = match sized_w {
        Some(v) => (v - cpb_w).max(0.0)
        None =>
          (cb_w - cm.left - cm.right - ins_l.unwrap_or(0.0) - ins_r.unwrap_or(0.0)).max(0.0)
      }
      let avail_h = match sized_h {
        Some(v) => (v - cpb_h).max(0.0)
        None =>
          (cb_h - cm.top - cm.bottom - ins_t.unwrap_or(0.0) - ins_b.unwrap_or(0.0)).max(0.0)
      }
      let (ccw, cch) = measure_content(c, Some(avail_w), Some(avail_h))
      let w0 = match sized_w {
        Some(v) => v
        None => ccw + cpb_w
      }
      let h0 = match sized_h {
        Some(v) => v
        None => cch + cpb_h
      }
      let aw = clamp3(
        w0,
        axis_size(c, cs.min_width, true, cbw, cbh).unwrap_or(0.0),
        axis_size(c, cs.max_width, true, cbw, cbh).unwrap_or(max_dim),
      )
      let ah = clamp3(
        h0,
        axis_size(c, cs.min_height, false, cbw, cbh).unwrap_or(0.0),
        axis_size(c, cs.max_height, false, cbw, cbh).unwrap_or(max_dim),
      )
      // 定位：inset 优先；同轴双 auto 落静态位置（按容器对齐属性摆一个虚拟项）
      let x = match ins_l {
        Some(lv) => lv + cm.left
        None =>
          match ins_r {
            Some(rv) => cb_w - rv - cm.right - aw
            None => {
              let lead = (if main_is_row {
                justify_leading(s.justify_content, cb_w - aw)
              } else {
                align_offset(s.align_items, cb_w - aw)
              }) + (if h_rev { cm.right } else { cm.left })
              if h_rev {
                cb_w - aw - lead
              } else {
                lead
              }
            }
          }
      }
      let y = match ins_t {
        Some(tv) => tv + cm.top
        None =>
          match ins_b {
            Some(bv) => cb_h - bv - cm.bottom - ah
            None => {
              let lead = (if main_is_row {
                align_offset(s.align_items, cb_h - ah)
              } else {
                justify_leading(s.justify_content, cb_h - ah)
              }) + (if v_rev { cm.bottom } else { cm.top })
              if v_rev {
                cb_h - ah - lead
              } else {
                lead
              }
            }
          }
      }
      c.layout_left = own_border.left + x
      c.layout_top = own_border.top + y
      if c.children.length() > 0 {
        let _ = layout_into(c, cbw, cbh, Some(aw), Some(ah))
      } else {
        c.layout_width = aw
        c.layout_height = ah
      }
    }
  }
  (w, h)
}
