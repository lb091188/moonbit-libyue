// `apply`：把一条 resolved `Style` 落到控件上（design.md §1.5）。
//
// 分流口径：布局字段走 Yoga（`set_width` / `set_padding` / `set_position` …），
// 外观字段进「样式槽」。core 不能依赖 style（会成环），槽由本包的进程级侧表
// 按控件 id 持有——绘制期 `resolved(w)` 读当前状态桶，`style_for(w)` 读基块。
// z_index 同步落 `Widget.z_index_paint`，core 的绘制遍历按它稳定重排 kids。

///|
/// 外观字段的落点：进程级侧表 `Map[控件 id, Style]`（core 不能反向依赖本包，
/// 槽放不进 `Widget`）。**只增不减会漏**——动态换树每换一代多留一批残账，所以
/// 首次 `apply` 时把 core 的控件丢弃钩子装上，摘下的子树连带清掉它的条目。
let resolved_table : Map[Int, Style] = Map([])
let drop_hook_installed : Ref[Bool] = Ref(false)

///|
fn install_drop_hook() -> Unit {
  if !drop_hook_installed.val {
    drop_hook_installed.val = true
    @core.set_widget_discard_hook(fn(id : Int) -> Unit {
      let _ = resolved_table.remove(id)
      forget_anim(id)
    })
  }
}

///|
/// 侧表当前条数（诊断用：残账清理的判据）。
pub fn resolved_count() -> Int {
  resolved_table.length()
}

///|
/// 把样式落到控件：布局字段进 Yoga 节点，外观字段进侧表；`visibility` 落宿主
/// `set_visible`，`cursor` 落 `Widget.cursor`，`z_index` 落绘制层序键。
/// 多次 apply 逐属性叠加（与 merge 同一规则：后写的属性赢）。
pub fn apply(w : @core.Widget, s : Style) -> Unit {
  install_drop_hook()
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
  match s.flex_wrap {
    Some(v) => n.set_flex_wrap(v)
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
  match s.box_shadow {
    // 阴影外扩量：绘制遍历时把本控件的裁剪窗口放大（core 的 shadow_paint）
    Some(v) => w.shadow_paint = v
    None => ()
  }
  let prev = match resolved_table.get(w.id) {
    Some(p) => p
    None => empty_style()
  }
  let merged = merge(prev, s)
  resolved_table.set(w.id, merged)
  // 带状态桶 = 绘制随悬停/按下/焦点变 → 告诉宿主「悬停变化时我的矩形也要重画」
  let stateful = match (merged.hover, merged.active, merged.focus) {
    (Some(_), _, _) | (_, Some(_), _) | (_, _, Some(_)) => true
    _ => false
  }
  if stateful {
    w.paints_state = true
  }
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
/// 按**控件 id** 读基块（不选桶）。测量回调只需要 id：回调存在布局节点上，
/// 抓住控件句柄就成了「控件 → 节点 → 回调 → 控件」的引用环（计数式回收断不掉）。
/// 布局属性只存在于基块里（状态桶签名里没有它们，§1.3），所以测量期读基块是完整的。
pub fn resolved_by_id(id : Int) -> Style {
  match resolved_table.get(id) {
    Some(st) => st
    None => empty_style()
  }
}

///|
/// 按控件当前交互态选桶后的绘制样式：基块 → 依序并入命中的状态桶。
/// 并存时的优先级是 hover < focus < active（后并入的赢，与 CSS 的 :active 盖过
/// :hover 同向）——按下态必然也在悬停态里，反过来写就永远看不见按下反馈。
/// 布局期不读它（状态桶签名里没有布局属性，§1.5 第五条）。
/// 写了 `transition_ms` 的块，出口再过一道按帧插值（§5 P5）：交出去的是
/// 「这一帧该画的值」，不是目标值。
pub fn style_for(w : @core.Widget) -> Style {
  let base = resolved(w)
  let mut out = base
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
  if w.pressed {
    match base.active {
      Some(a) => out = merge(out, a)
      None => ()
    }
  }
  let animated = match out.transition_ms {
    Some(v) => v > 0.0
    None => false
  }
  if animated {
    step(w.id, out, @core.now_ms())
  } else {
    // 没配过渡的控件不留账
    forget_anim(w.id)
    out
  }
}

///|
/// 绘制期取一条颜色属性：样式给了就用（token 现取当前主题），没给用组件内置基调。
/// 组件侧读样式只有 [style_for] + 这一条回落，外观散参数不在绘制期直接吃。
pub fn color_of(c : Color?, fallback : String) -> String {
  match c {
    Some(v) => resolve_color(v)
    None => fallback
  }
}

///|
/// 绘制期取一条长度属性（字号 / 圆角 / 边框宽 / 内边距），没给用内置基调。
pub fn number_of(v : Double?, fallback : Double) -> Double {
  match v {
    Some(x) => x
    None => fallback
  }
}

///|
/// 绘制期取一条字符串属性（字体名、图标色串那类），没给用内置基调。
pub fn string_of(v : String?, fallback : String) -> String {
  match v {
    Some(x) => x
    None => fallback
  }
}
