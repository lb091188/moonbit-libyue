///|
/// 一条规则块：全部属性都是 `Option`（`merge` 靠「非空才覆盖」、`apply` 靠
/// 「`None` 不动」）；调用点不出现 `Some`——构造走 [style] 工厂，属性名即参数名
/// （design.md §1.5）。三个状态桶是嵌套 `Style`，绘制期按控件状态选桶（§1.3）。
pub(all) struct Style {
  // —— 文本与颜色
  mut color : Color?
  mut background_color : Color?
  mut font_size : Double?
  mut font_family : String?
  mut font_weight : FontWeight?
  mut text_align : TextAlign?
  mut line_height : Double?
  mut letter_spacing : Double?
  mut text_decoration : TextDecoration?
  mut white_space : WhiteSpace?
  // —— 尺寸（逻辑像素；百分比是另开的入口字段，落 Yoga 时同一 setter 换值形态）
  mut width : Double?
  mut width_percent : Double?
  mut height : Double?
  mut height_percent : Double?
  mut min_width : Double?
  mut min_height : Double?
  mut max_width : Double?
  mut max_height : Double?
  // —— 内外边距（逐边字段；工厂的 `padding`/`margin` 简写参数包内展开到这四个）
  mut padding_left : Double?
  mut padding_right : Double?
  mut padding_top : Double?
  mut padding_bottom : Double?
  mut margin_left : Double?
  mut margin_right : Double?
  mut margin_top : Double?
  mut margin_bottom : Double?
  // —— 边框圆角（绘制阶段消费）
  mut border_width : Double?
  mut border_color : Color?
  mut border_radius : Double?
  // —— flex 布局
  mut display : Display?
  mut flex_direction : FlexDirection?
  mut flex_wrap : FlexWrap?
  mut justify_content : JustifyContent?
  mut align_items : AlignItems?
  mut align_self : AlignItems?
  mut flex : Double?
  mut row_gap : Double?
  mut column_gap : Double?
  // —— 定位（底层 yoga 现成，含百分比 inset；Style 首批只开逻辑像素值）
  mut position : PositionType?
  mut top : Double?
  mut right : Double?
  mut bottom : Double?
  mut left : Double?
  mut z_index : Int?
  // —— P4：整层透明度（0..1，画期把 global alpha 乘进全路径）
  // 投影档（box_shadow 那四位）已于 2026-10-15 真机复验后整条撤掉：分层近似的
  // 软边在真机上仍不如人意，用户拍板不做——见 docs/zh/adaptation.md「阴影」节。
  mut opacity : Double?
  // —— P5：状态桶切换的过渡时长（毫秒；不写或 0 = 直接切换）
  mut transition_ms : Double?
  // —— 其它（落宿主 Widget）
  mut visibility : Visibility?
  mut cursor : Int?
  // —— 状态桶（构造端：工厂状态参数收整块 + 三个状态方法收属性参数，§1.3）
  mut hover : Style?
  mut active : Style?
  mut focus : Style?
}

///|
/// 空样式：所有属性 `None`。工厂的底座，也是「未应用过样式的控件」的槽初值。
pub fn empty_style() -> Style {
  {
    color: None,
    background_color: None,
    font_size: None,
    font_family: None,
    font_weight: None,
    text_align: None,
    line_height: None,
    letter_spacing: None,
    text_decoration: None,
    white_space: None,
    width: None,
    width_percent: None,
    height: None,
    height_percent: None,
    min_width: None,
    min_height: None,
    max_width: None,
    max_height: None,
    padding_left: None,
    padding_right: None,
    padding_top: None,
    padding_bottom: None,
    margin_left: None,
    margin_right: None,
    margin_top: None,
    margin_bottom: None,
    border_width: None,
    border_color: None,
    border_radius: None,
    display: None,
    flex_direction: None,
    flex_wrap: None,
    justify_content: None,
    align_items: None,
    align_self: None,
    flex: None,
    row_gap: None,
    column_gap: None,
    position: None,
    top: None,
    right: None,
    bottom: None,
    left: None,
    z_index: None,
    opacity: None,
    transition_ms: None,
    visibility: None,
    cursor: None,
    hover: None,
    active: None,
    focus: None,
  }
}

///|
/// 包内通用：`over` 有值就用 `over`，否则保留 `base`（merge 的逐属性规则）。
fn [T] pick(base : T?, over : T?) -> T? {
  match over {
    Some(_) => over
    None => base
  }
}

///|
/// 状态桶合并进已有块：前者逐属性保留、后者覆盖（§1.3 桶内递归）。
fn merge_bucket(base : Style?, over : Style) -> Style {
  match base {
    Some(b) => merge(b, over)
    None => over
  }
}

fn pick_style(base : Style?, over : Style?) -> Style? {
  match (base, over) {
    (Some(b), Some(o)) => Some(merge(b, o))
    (None, Some(_)) => over
    (Some(_), None) => base
    (None, None) => None
  }
}

///|
/// 逐属性并集：只覆盖写过的字段，没写的保留前一条的值；后出现的覆盖先出现的。
/// 造新值、**绝不改入参**（内置常量表只读用，design.md §1.5）。状态桶递归按
/// 同一条规则合并，不是整块互换（整块换会抹掉前者状态块里没写的那些边，§1.3）。
pub fn merge(base : Style, over : Style) -> Style {
  let s = empty_style()
  s.color = pick(base.color, over.color)
  s.background_color = pick(base.background_color, over.background_color)
  s.font_size = pick(base.font_size, over.font_size)
  s.font_family = pick(base.font_family, over.font_family)
  s.font_weight = pick(base.font_weight, over.font_weight)
  s.text_align = pick(base.text_align, over.text_align)
  s.line_height = pick(base.line_height, over.line_height)
  s.letter_spacing = pick(base.letter_spacing, over.letter_spacing)
  s.text_decoration = pick(base.text_decoration, over.text_decoration)
  s.white_space = pick(base.white_space, over.white_space)
  s.width = pick(base.width, over.width)
  s.width_percent = pick(base.width_percent, over.width_percent)
  s.height = pick(base.height, over.height)
  s.height_percent = pick(base.height_percent, over.height_percent)
  s.min_width = pick(base.min_width, over.min_width)
  s.min_height = pick(base.min_height, over.min_height)
  s.max_width = pick(base.max_width, over.max_width)
  s.max_height = pick(base.max_height, over.max_height)
  s.padding_left = pick(base.padding_left, over.padding_left)
  s.padding_right = pick(base.padding_right, over.padding_right)
  s.padding_top = pick(base.padding_top, over.padding_top)
  s.padding_bottom = pick(base.padding_bottom, over.padding_bottom)
  s.margin_left = pick(base.margin_left, over.margin_left)
  s.margin_right = pick(base.margin_right, over.margin_right)
  s.margin_top = pick(base.margin_top, over.margin_top)
  s.margin_bottom = pick(base.margin_bottom, over.margin_bottom)
  s.border_width = pick(base.border_width, over.border_width)
  s.border_color = pick(base.border_color, over.border_color)
  s.border_radius = pick(base.border_radius, over.border_radius)
  s.display = pick(base.display, over.display)
  s.flex_direction = pick(base.flex_direction, over.flex_direction)
  s.flex_wrap = pick(base.flex_wrap, over.flex_wrap)
  s.justify_content = pick(base.justify_content, over.justify_content)
  s.align_items = pick(base.align_items, over.align_items)
  s.align_self = pick(base.align_self, over.align_self)
  s.flex = pick(base.flex, over.flex)
  s.row_gap = pick(base.row_gap, over.row_gap)
  s.column_gap = pick(base.column_gap, over.column_gap)
  s.position = pick(base.position, over.position)
  s.top = pick(base.top, over.top)
  s.right = pick(base.right, over.right)
  s.bottom = pick(base.bottom, over.bottom)
  s.left = pick(base.left, over.left)
  s.z_index = pick(base.z_index, over.z_index)
  s.opacity = pick(base.opacity, over.opacity)
  s.transition_ms = pick(base.transition_ms, over.transition_ms)
  s.visibility = pick(base.visibility, over.visibility)
  s.cursor = pick(base.cursor, over.cursor)
  s.hover = pick_style(base.hover, over.hover)
  s.active = pick_style(base.active, over.active)
  s.focus = pick_style(base.focus, over.focus)
  s
}

///|
/// 链式属性 setter：非 `None` 才写进字段，返回自身（包内 setter 体固定为
/// 「赋值 + 返回 self」，design.md §1.6）。调用点一般走 [style] 工厂，
/// 这里留给「已构造的块上再补一个属性」的场合。
pub fn Style::set_color(self : Style, v : Color?) -> Style {
  self.color = v
  self
}

///|
pub fn Style::set_background_color(self : Style, v : Color?) -> Style {
  self.background_color = v
  self
}

///|
pub fn Style::set_font_size(self : Style, v : Double?) -> Style {
  self.font_size = v
  self
}

///|
pub fn Style::set_font_family(self : Style, v : String?) -> Style {
  self.font_family = v
  self
}

///|
pub fn Style::set_font_weight(self : Style, v : FontWeight?) -> Style {
  self.font_weight = v
  self
}

///|
pub fn Style::set_text_align(self : Style, v : TextAlign?) -> Style {
  self.text_align = v
  self
}

///|
pub fn Style::set_line_height(self : Style, v : Double?) -> Style {
  self.line_height = v
  self
}

///|
pub fn Style::set_letter_spacing(self : Style, v : Double?) -> Style {
  self.letter_spacing = v
  self
}

///|
pub fn Style::set_text_decoration(self : Style, v : TextDecoration?) -> Style {
  self.text_decoration = v
  self
}

///|
pub fn Style::set_white_space(self : Style, v : WhiteSpace?) -> Style {
  self.white_space = v
  self
}

///|
pub fn Style::set_width(self : Style, v : Double?) -> Style {
  self.width = v
  self
}

///|
pub fn Style::set_width_percent(self : Style, v : Double?) -> Style {
  self.width_percent = v
  self
}

///|
pub fn Style::set_height(self : Style, v : Double?) -> Style {
  self.height = v
  self
}

///|
pub fn Style::set_height_percent(self : Style, v : Double?) -> Style {
  self.height_percent = v
  self
}

///|
pub fn Style::set_min_width(self : Style, v : Double?) -> Style {
  self.min_width = v
  self
}

///|
pub fn Style::set_min_height(self : Style, v : Double?) -> Style {
  self.min_height = v
  self
}

///|
pub fn Style::set_max_width(self : Style, v : Double?) -> Style {
  self.max_width = v
  self
}

///|
pub fn Style::set_max_height(self : Style, v : Double?) -> Style {
  self.max_height = v
  self
}

///|
pub fn Style::set_padding_left(self : Style, v : Double?) -> Style {
  self.padding_left = v
  self
}

///|
pub fn Style::set_padding_right(self : Style, v : Double?) -> Style {
  self.padding_right = v
  self
}

///|
pub fn Style::set_padding_top(self : Style, v : Double?) -> Style {
  self.padding_top = v
  self
}

///|
pub fn Style::set_padding_bottom(self : Style, v : Double?) -> Style {
  self.padding_bottom = v
  self
}

///|
pub fn Style::set_margin_left(self : Style, v : Double?) -> Style {
  self.margin_left = v
  self
}

///|
pub fn Style::set_margin_right(self : Style, v : Double?) -> Style {
  self.margin_right = v
  self
}

///|
pub fn Style::set_margin_top(self : Style, v : Double?) -> Style {
  self.margin_top = v
  self
}

///|
pub fn Style::set_margin_bottom(self : Style, v : Double?) -> Style {
  self.margin_bottom = v
  self
}

///|
pub fn Style::set_border_width(self : Style, v : Double?) -> Style {
  self.border_width = v
  self
}

///|
pub fn Style::set_border_color(self : Style, v : Color?) -> Style {
  self.border_color = v
  self
}

///|
pub fn Style::set_border_radius(self : Style, v : Double?) -> Style {
  self.border_radius = v
  self
}

///|
pub fn Style::set_display(self : Style, v : Display?) -> Style {
  self.display = v
  self
}

///|
pub fn Style::set_flex_direction(self : Style, v : FlexDirection?) -> Style {
  self.flex_direction = v
  self
}

///|
pub fn Style::set_justify_content(self : Style, v : JustifyContent?) -> Style {
  self.justify_content = v
  self
}

///|
pub fn Style::set_align_items(self : Style, v : AlignItems?) -> Style {
  self.align_items = v
  self
}

///|
pub fn Style::set_align_self(self : Style, v : AlignItems?) -> Style {
  self.align_self = v
  self
}

///|
pub fn Style::set_flex(self : Style, v : Double?) -> Style {
  self.flex = v
  self
}

///|
pub fn Style::set_row_gap(self : Style, v : Double?) -> Style {
  self.row_gap = v
  self
}

///|
pub fn Style::set_column_gap(self : Style, v : Double?) -> Style {
  self.column_gap = v
  self
}

///|
pub fn Style::set_position(self : Style, v : PositionType?) -> Style {
  self.position = v
  self
}

///|
pub fn Style::set_top(self : Style, v : Double?) -> Style {
  self.top = v
  self
}

///|
pub fn Style::set_right(self : Style, v : Double?) -> Style {
  self.right = v
  self
}

///|
pub fn Style::set_bottom(self : Style, v : Double?) -> Style {
  self.bottom = v
  self
}

///|
pub fn Style::set_left(self : Style, v : Double?) -> Style {
  self.left = v
  self
}

///|
pub fn Style::set_z_index(self : Style, v : Int?) -> Style {
  self.z_index = v
  self
}

///|
pub fn Style::set_visibility(self : Style, v : Visibility?) -> Style {
  self.visibility = v
  self
}

///|
pub fn Style::set_cursor(self : Style, v : Int?) -> Style {
  self.cursor = v
  self
}

///|
pub fn Style::set_hover(self : Style, v : Style?) -> Style {
  self.hover = v
  self
}

///|
pub fn Style::set_active(self : Style, v : Style?) -> Style {
  self.active = v
  self
}

///|
pub fn Style::set_focus(self : Style, v : Style?) -> Style {
  self.focus = v
  self
}

///|
/// 按序合并一组样式块（组件侧 `class : Array[Style]` 的解析通道：散参数折成
/// 匿名块排最前、class 在后，优先级由数组顺序直接成立，design.md §1.5）。
pub fn merge_all(blocks : Array[Style]) -> Style {
  let mut acc = empty_style()
  for b in blocks {
    acc = merge(acc, b)
  }
  acc
}

///|
pub fn Style::set_opacity(self : Style, v : Double?) -> Style {
  self.opacity = v
  self
}

///|
pub fn Style::set_flex_wrap(self : Style, v : FlexWrap?) -> Style {
  self.flex_wrap = v
  self
}

///|
/// 状态桶切换的过渡时长（毫秒）。参与插值的只有绘制期字段（§1.5），时长写在
/// 基块上、由 class 逐属性覆盖；不写或 0 就是直接切换。
pub fn Style::set_transition_ms(self : Style, v : Double?) -> Style {
  self.transition_ms = v
  self
}
