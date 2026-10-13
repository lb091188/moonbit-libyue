// `apply`：把一条 resolved `Style` 落到控件上（design.md §1.5）。
//
// 分流口径：布局字段走 Yoga（`set_width` / `set_padding` / `set_position` …），
// 外观字段进「样式槽」。core 不能依赖 style（会成环），槽由本包的进程级侧表
// 按控件 id 持有——绘制期 `resolved(w)` 读当前状态桶，`style_for(w)` 读基块。
// z_index 同步落 `Widget.z_index_paint`，core 的绘制遍历按它稳定重排 kids。

///|
let resolved_table : Map[Int, Style] = Map([])

///|
/// 把样式落到控件：布局字段进 Yoga 节点，外观字段进侧表；`visibility` 落宿主
/// `set_visible`，`cursor` 落 `Widget.cursor`，`z_index` 落绘制层序键。
/// 多次 apply 逐属性叠加（与 merge 同一规则：后写的属性赢）。
pub fn apply(w : @core.Widget, s : Style) -> Unit {
  let n = w.node
  match s.width {
    Some(v) => n.set_width(@yoga.fixed(v))
    None => ()
  }
  match s.width_percent {
    Some(v) => n.set_width(@yoga.percent(v))
    None => ()
  }
  match s.height {
    Some(v) => n.set_height(@yoga.fixed(v))
    None => ()
  }
  match s.height_percent {
    Some(v) => n.set_height(@yoga.percent(v))
    None => ()
  }
  match s.min_width {
    Some(v) => n.set_min_width(@yoga.fixed(v))
    None => ()
  }
  match s.min_height {
    Some(v) => n.set_min_height(@yoga.fixed(v))
    None => ()
  }
  match s.max_width {
    Some(v) => n.set_max_width(@yoga.fixed(v))
    None => ()
  }
  match s.max_height {
    Some(v) => n.set_max_height(@yoga.fixed(v))
    None => ()
  }
  match s.padding_left {
    Some(v) => n.set_padding_left(@yoga.fixed(v))
    None => ()
  }
  match s.padding_right {
    Some(v) => n.set_padding_right(@yoga.fixed(v))
    None => ()
  }
  match s.padding_top {
    Some(v) => n.set_padding_top(@yoga.fixed(v))
    None => ()
  }
  match s.padding_bottom {
    Some(v) => n.set_padding_bottom(@yoga.fixed(v))
    None => ()
  }
  match s.margin_left {
    Some(v) => n.set_margin_left(@yoga.fixed(v))
    None => ()
  }
  match s.margin_right {
    Some(v) => n.set_margin_right(@yoga.fixed(v))
    None => ()
  }
  match s.margin_top {
    Some(v) => n.set_margin_top(@yoga.fixed(v))
    None => ()
  }
  match s.margin_bottom {
    Some(v) => n.set_margin_bottom(@yoga.fixed(v))
    None => ()
  }
  match s.display {
    Some(v) => n.set_display(v)
    None => ()
  }
  match s.flex_direction {
    Some(v) => n.set_flex_direction(v)
    None => ()
  }
  match s.justify_content {
    Some(v) => n.set_justify_content(v)
    None => ()
  }
  match s.align_items {
    Some(v) => n.set_align_items(v)
    None => ()
  }
  match s.align_self {
    Some(v) => n.set_align_self(Some(v))
    None => ()
  }
  match s.flex {
    Some(v) => n.set_flex_grow(v)
    None => ()
  }
  match s.row_gap {
    Some(v) => n.set_row_gap(v)
    None => ()
  }
  match s.column_gap {
    Some(v) => n.set_column_gap(v)
    None => ()
  }
  match s.position {
    Some(v) => n.set_position(v)
    None => ()
  }
  match s.top {
    Some(v) => n.set_top(@yoga.fixed(v))
    None => ()
  }
  match s.right {
    Some(v) => n.set_right(@yoga.fixed(v))
    None => ()
  }
  match s.bottom {
    Some(v) => n.set_bottom(@yoga.fixed(v))
    None => ()
  }
  match s.left {
    Some(v) => n.set_left(@yoga.fixed(v))
    None => ()
  }
  match s.z_index {
    Some(v) => {
      n.set_z_index(v)
      w.z_index_paint = v.to_double()
    }
    None => ()
  }
  match s.visibility {
    Some(Visible) => w.set_visible(true)
    Some(Hidden) => w.set_visible(false)
    None => ()
  }
  match s.opacity {
    // 整层透明度不进侧表快照以外的路径：绘制遍历经 @style.paint_alpha 读取
    Some(v) => w.alpha_paint = v
    None => ()
  }
  match s.cursor {
    Some(c) => w.cursor = c
    None => ()
  }
  let prev = match resolved_table.get(w.id) {
    Some(p) => p
    None => empty_style()
  }
  resolved_table.set(w.id, merge(prev, s))
}

///|
/// 控件上的基块（未应用过样式给空样式）。绘制期一般用 [style_for]——它按状态
/// 选桶（`hovered` / `pressed` / `focused`，三桶可同时命中并按桶内逐属性层叠）。
pub fn resolved(w : @core.Widget) -> Style {
  match resolved_table.get(w.id) {
    Some(s) => s
    None => empty_style()
  }
}

///|
/// 按控件当前交互态选桶后的绘制样式：基块 → 依序并入命中的状态桶。
/// 布局期不读它（状态桶签名里没有布局属性，§1.5 第五条）。
pub fn style_for(w : @core.Widget) -> Style {
  let base = resolved(w)
  let mut out = base
  if w.pressed {
    match base.active {
      Some(a) => out = merge(out, a)
      None => ()
    }
  }
  if w.hovered {
    match base.hover {
      Some(h) => out = merge(out, h)
      None => ()
    }
  }
  if w.focused {
    match base.focus {
      Some(f) => out = merge(out, f)
      None => ()
    }
  }
  out
}
