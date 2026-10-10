// Flexbox 布局核心算法。
//
// 按 CSS Flexible Box Layout Module Level 1 的布局流程实现：
// 确定基准尺寸 → 换行 → 解析弹性长度（冻结违规）→ 主轴定位
// （auto margin 优先于 justify-content）→ 交叉轴定尺寸与对齐
// （align-content 处理多行）→ 递归子树。
//
// 宽高语义为 border-box（与 Yoga 一致）：width/height 含自身的
// padding 与 border。首版未实现：absolute 定位、baseline 对齐
// （按 flex-start 处理）、RTL（direction）、aspect-ratio、测量缓存、
// 像素网格取整。

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
/// 主轴/交叉轴视角下的边距（含 auto 标记；reverse 时主轴起端随之翻转）。
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
fn axis_margin(r : Resolved, main_is_row : Bool, reverse : Bool) -> AxisMargin {
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
    (sv, ev, r.left, r.right, asv, aev, r.auto_left, r.auto_right)
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
/// 测量节点内容尺寸（border-box）：叶子走 measure 函数，容器递归布局。
fn measure_content(
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
    let (cw, ch) = match c.measure {
      Some(f) => {
        let iw = avail_w.map(fn(w) { (w - pb_w).max(0.0) })
        let ih = avail_h.map(fn(h) { (h - pb_h).max(0.0) })
        f(iw, ih)
      }
      None => (0.0, 0.0)
    }
    let w = first_some(definite_size(s.width, avail_w), None).unwrap_or(cw + pb_w)
    let h = first_some(definite_size(s.height, avail_h), None).unwrap_or(ch + pb_h)
    (w, h)
  } else {
    layout_into(c, avail_w, avail_h, None, None)
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
    let w0 = first_some(pinned_w, definite_size(s.width, avail_w)).unwrap_or(cw + pad_border_w)
    let h0 = first_some(pinned_h, definite_size(s.height, avail_h)).unwrap_or(ch + pad_border_h)
    let w = clamp3(
      w0,
      definite_size(s.min_width, avail_w).unwrap_or(0.0),
      definite_size(s.max_width, avail_w).unwrap_or(max_dim),
    )
    let h = clamp3(
      h0,
      definite_size(s.min_height, avail_h).unwrap_or(0.0),
      definite_size(s.max_height, avail_h).unwrap_or(max_dim),
    )
    node.layout_width = w
    node.layout_height = h
    return (w, h)
  }
  let main_is_row = is_row(s.flex_direction)
  let reverse = is_reverse(s.flex_direction)
  // 自身尺寸（确定值）
  let own_w_def = first_some(pinned_w, definite_size(s.width, avail_w))
  let own_h_def = first_some(pinned_h, definite_size(s.height, avail_h))
  // 子项百分比参照：本节点内容盒确定尺寸优先，退回可用空间
  let child_pct_w = first_some(own_w_def.map(fn(w) { (w - pad_border_w).max(0.0) }), avail_w)
  let child_pct_h = first_some(own_h_def.map(fn(h) { (h - pad_border_h).max(0.0) }), avail_h)
  let pct_base_main = if main_is_row {
    child_pct_w
  } else {
    child_pct_h
  }
  let pct_base_cross = if main_is_row {
    child_pct_h
  } else {
    child_pct_w
  }
  let avail_main = if main_is_row { avail_w } else { avail_h }
  let pad_border_main = if main_is_row { pad_border_w } else { pad_border_h }
  let pad_border_cross = if main_is_row { pad_border_h } else { pad_border_w }
  let inner_main_avail = avail_main.map(fn(v) { (v - pad_border_main).max(0.0) })
  let own_main_def = if main_is_row { own_w_def } else { own_h_def }
  let own_cross_def = if main_is_row { own_h_def } else { own_w_def }
  let inner_main = own_main_def.map(fn(v) { (v - pad_border_main).max(0.0) })
  let inner_cross = own_cross_def.map(fn(v) { (v - pad_border_cross).max(0.0) })
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
    let m = axis_margin(cm, main_is_row, reverse)
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
    let c_avail_main = first_some(definite_size(child_main_style, pct_base_main), wrap_limit)
    let c_avail_cross = first_some(
      definite_size(child_cross_style, pct_base_cross),
      first_some(own_cross_def.map(fn(v) { (v - pad_border_cross).max(0.0) }), None),
    )
    let content = if main_is_row {
      measure_content(c, c_avail_main, c_avail_cross)
    } else {
      let (w, h) = measure_content(c, c_avail_cross, c_avail_main)
      (h, w)
    }
    let content_main = content.0
    let content_cross0 = content.1
    let basis_val = match s.flex_basis {
      Auto => child_main_style
      v => v
    }
    let base = definite_size(basis_val, pct_base_main).unwrap_or(content_main)
    let min_v = if main_is_row { c.style.min_width } else { c.style.min_height }
    // web 语义：主轴 min:auto → 内容下限；显式 Fixed(0) 才是 0
    let min_main = definite_size(min_v, pct_base_main).unwrap_or(content_main)
    let max_v = if main_is_row { c.style.max_width } else { c.style.max_height }
    let max_main = definite_size(max_v, pct_base_main).unwrap_or(max_dim)
    let cross_definite = definite_size(child_cross_style, pct_base_cross)
    let cmin_v = if main_is_row { c.style.min_height } else { c.style.min_width }
    let min_cross = definite_size(cmin_v, pct_base_cross).unwrap_or(0.0)
    let cmax_v = if main_is_row { c.style.max_height } else { c.style.max_width }
    let max_cross = definite_size(cmax_v, pct_base_cross).unwrap_or(max_dim)
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
    // 规范 §9.6：单行且容器交叉轴确定时，行交叉尺寸 = 容器内交叉尺寸
    let line_cross = if nlines == 1 {
      match inner_cross {
        Some(ic) => ic
        None => content_cross
      }
    } else {
      content_cross
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
  for li in 0..<nlines {
    let line = lines[li]
    let lc = line_crosses[li]
    let loff = line_offsets[li]
    for it in line {
      let align = match it.node.style.align_self {
        Some(a) => a
        None => s.align_items
      }
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
          _ => 0.0
        }
      }
      it.pos_cross = loff + off
      let c_w = if main_is_row { it.size_main } else { it.final_cross }
      let c_h = if main_is_row { it.final_cross } else { it.size_main }
      let inner_main_dim = if main_is_row { inner_w } else { inner_h }
      let x = if main_is_row {
        if reverse {
          inner_main_dim.unwrap_or(0.0) - it.pos_main - it.size_main
        } else {
          it.pos_main
        }
      } else {
        it.pos_cross
      }
      let y = if main_is_row {
        it.pos_cross
      } else if reverse {
        inner_main_dim.unwrap_or(0.0) - it.pos_main - it.size_main
      } else {
        it.pos_main
      }
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
  // ---- 自身尺寸 ----
  let content_main_sum = if nlines == 1 {
    lines[0].iter().fold(init=0.0, fn(acc, it) {
      acc + it.size_main + it.m.start + it.m.end
    }) +
    (main_gap * (lines[0].length() - 1).to_double()).max(0.0)
  } else {
    0.0
  }
  let own_main0 = match own_main_def {
    Some(v) => v
    None => content_main_sum
  }
  let own_cross0 = match own_cross_def {
    Some(v) => v
    None => own_cross_content
  }
  let own_main = clamp3(
    own_main0,
    definite_size(
      if main_is_row { s.min_width } else { s.min_height },
      child_pct_w,
    ).unwrap_or(0.0),
    definite_size(
      if main_is_row { s.max_width } else { s.max_height },
      child_pct_w,
    ).unwrap_or(max_dim),
  )
  let own_cross = clamp3(
    own_cross0,
    definite_size(
      if main_is_row { s.min_height } else { s.min_width },
      child_pct_h,
    ).unwrap_or(0.0),
    definite_size(
      if main_is_row { s.max_height } else { s.max_width },
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
      // 尺寸：显式宽高优先；同轴两侧 inset 都设时由 inset 撑出；否则内容
      let sized_w = match definite_size(cs.width, cbw) {
        Some(v) => Some(v.max(cpb_w))
        None =>
          match (ins_l, ins_r) {
            (Some(lv), Some(rv)) => Some((cb_w - lv - rv - cm.left - cm.right).max(cpb_w))
            _ => None
          }
      }
      let sized_h = match definite_size(cs.height, cbh) {
        Some(v) => Some(v.max(cpb_h))
        None =>
          match (ins_t, ins_b) {
            (Some(tv), Some(bv)) => Some((cb_h - tv - bv - cm.top - cm.bottom).max(cpb_h))
            _ => None
          }
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
        definite_size(cs.min_width, cbw).unwrap_or(0.0),
        definite_size(cs.max_width, cbw).unwrap_or(max_dim),
      )
      let ah = clamp3(
        h0,
        definite_size(cs.min_height, cbh).unwrap_or(0.0),
        definite_size(cs.max_height, cbh).unwrap_or(max_dim),
      )
      // 定位：inset 优先；同轴双 auto 落静态位置（按容器对齐属性摆一个虚拟项）
      let x = match ins_l {
        Some(lv) => lv + cm.left
        None =>
          match ins_r {
            Some(rv) => cb_w - rv - cm.right - aw
            None =>
              (if main_is_row {
                justify_leading(s.justify_content, cb_w - aw)
              } else {
                align_offset(s.align_items, cb_w - aw)
              }) + cm.left
          }
      }
      let y = match ins_t {
        Some(tv) => tv + cm.top
        None =>
          match ins_b {
            Some(bv) => cb_h - bv - cm.bottom - ah
            None =>
              (if main_is_row {
                align_offset(s.align_items, cb_h - ah)
              } else {
                justify_leading(s.justify_content, cb_h - ah)
              }) + cm.top
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
