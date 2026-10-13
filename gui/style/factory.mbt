// kwargs 工厂与状态方法（design.md §1.3 / §1.5）：
// - 规则块 = 一次 `style(...)` 调用，属性名即参数名（可选 labelled 参数在调用点
//   自动包 `Some`，§1.6）；`Some`、单位、四边展开都关在包内。
// - 状态桶两条入口分工：工厂的状态参数收**整块**（具名块复用），状态方法
//   `.hover(...)` / `.active(...)` / `.focus(...)` 收**属性参数**现场开块——
//   签名里只有绘制期属性，布局参数不在其列（布局值进状态块编译不过）。

///|
/// 规则块工厂：全部属性是可选 labelled 参数。颜色参数收字符串（`#` 开头按 hex、
/// 命名色按 named、其余按 theme token 名，token 不认识当场 raise，§1.4）；
/// `padding` / `margin` 简写只表示**四边同值**，逐边参数可覆单条边（§1.1）。
///
/// ```moonbit
/// let card = style(padding=14.0, background_color="bg_panel", border_radius=8.0)
/// ```
pub fn style(
  // —— 文本与颜色
  color? : String,
  background_color? : String,
  font_size? : Double,
  font_family? : String,
  font_weight? : FontWeight,
  text_align? : TextAlign,
  line_height? : Double,
  letter_spacing? : Double,
  text_decoration? : TextDecoration,
  white_space? : WhiteSpace,
  // —— 尺寸
  width? : Double,
  width_percent? : Double,
  height? : Double,
  height_percent? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
  // —— 内外边距（简写=四边同值；逐边覆写其后）
  padding? : Double,
  padding_left? : Double,
  padding_right? : Double,
  padding_top? : Double,
  padding_bottom? : Double,
  margin? : Double,
  margin_left? : Double,
  margin_right? : Double,
  margin_top? : Double,
  margin_bottom? : Double,
  // —— 边框圆角
  border_width? : Double,
  border_color? : String,
  border_radius? : Double,
  // —— flex 布局
  display? : Display,
  flex_direction? : FlexDirection,
  justify_content? : JustifyContent,
  align_items? : AlignItems,
  align_self? : AlignItems,
  flex? : Double,
  gap? : Double,
  row_gap? : Double,
  column_gap? : Double,
  // —— 定位
  position? : PositionType,
  top? : Double,
  right? : Double,
  bottom? : Double,
  left? : Double,
  z_index? : Int,
  // —— P4：整层透明度与硬阴影半径（逻辑像素；模糊档随 blur 能力再评估）
  opacity? : Double,
  box_shadow? : Double,
  // —— 其它
  visibility? : Visibility,
  cursor? : Int,
  // —— 状态桶：收整块（具名块复用）
  hover? : Style,
  active? : Style,
  focus? : Style,
) -> Style {
  let s = empty_style()
  match color {
    Some(c) => s.color = Some(check_color(parse_color(c)))
    None => ()
  }
  match background_color {
    Some(c) => s.background_color = Some(check_color(parse_color(c)))
    None => ()
  }
  s.font_size = font_size
  s.font_family = font_family
  s.font_weight = font_weight
  s.text_align = text_align
  s.line_height = line_height
  s.letter_spacing = letter_spacing
  s.text_decoration = text_decoration
  s.white_space = white_space
  s.width = width
  s.width_percent = width_percent
  s.height = height
  s.height_percent = height_percent
  s.min_width = min_width
  s.min_height = min_height
  s.max_width = max_width
  s.max_height = max_height
  // 简写先铺四边，逐边参数再覆写（`padding=14.0, padding_top=4.0` 即上 4 其余 14）
  match padding {
    Some(v) => {
      s.padding_left = Some(v)
      s.padding_right = Some(v)
      s.padding_top = Some(v)
      s.padding_bottom = Some(v)
    }
    None => ()
  }
  match padding_left {
    Some(v) => s.padding_left = Some(v)
    None => ()
  }
  match padding_right {
    Some(v) => s.padding_right = Some(v)
    None => ()
  }
  match padding_top {
    Some(v) => s.padding_top = Some(v)
    None => ()
  }
  match padding_bottom {
    Some(v) => s.padding_bottom = Some(v)
    None => ()
  }
  match margin {
    Some(v) => {
      s.margin_left = Some(v)
      s.margin_right = Some(v)
      s.margin_top = Some(v)
      s.margin_bottom = Some(v)
    }
    None => ()
  }
  match margin_left {
    Some(v) => s.margin_left = Some(v)
    None => ()
  }
  match margin_right {
    Some(v) => s.margin_right = Some(v)
    None => ()
  }
  match margin_top {
    Some(v) => s.margin_top = Some(v)
    None => ()
  }
  match margin_bottom {
    Some(v) => s.margin_bottom = Some(v)
    None => ()
  }
  s.border_width = border_width
  match border_color {
    Some(c) => s.border_color = Some(check_color(parse_color(c)))
    None => ()
  }
  s.border_radius = border_radius
  s.display = display
  s.flex_direction = flex_direction
  s.justify_content = justify_content
  s.align_items = align_items
  s.align_self = align_self
  s.flex = flex
  match gap {
    Some(v) => {
      s.row_gap = Some(v)
      s.column_gap = Some(v)
    }
    None => ()
  }
  match row_gap {
    Some(v) => s.row_gap = Some(v)
    None => ()
  }
  match column_gap {
    Some(v) => s.column_gap = Some(v)
    None => ()
  }
  s.position = position
  s.top = top
  s.right = right
  s.bottom = bottom
  s.left = left
  s.z_index = z_index
  s.opacity = opacity
  s.box_shadow = box_shadow
  s.visibility = visibility
  s.cursor = cursor
  s.hover = hover
  s.active = active
  s.focus = focus
  s
}

///|
/// 状态方法：收**属性参数**现场开块，写进 `hover`（悬停）桶；已有桶则逐属性
/// 并入（§1.3「合并/覆盖按桶内逐属性递归」）。签名里只有绘制期属性——布局参数混进去会把「画的时候」和「量的时候」搅在一起（design.md §1.5 第五条）。labelled 参数没有透传语法（§1.6），三块构造体各写一遍。
pub fn Style::hover(
  self : Style,
  color? : String,
  background_color? : String,
  font_size? : Double,
  font_family? : String,
  font_weight? : FontWeight,
  text_align? : TextAlign,
  line_height? : Double,
  letter_spacing? : Double,
  text_decoration? : TextDecoration,
  white_space? : WhiteSpace,
  border_width? : Double,
  border_color? : String,
  border_radius? : Double,
  visibility? : Visibility,
  cursor? : Int,
) -> Style {
  let b = empty_style()
  match color {
    Some(c) => b.color = Some(check_color(parse_color(c)))
    None => ()
  }
  match background_color {
    Some(c) => b.background_color = Some(check_color(parse_color(c)))
    None => ()
  }
  b.font_size = font_size
  b.font_family = font_family
  b.font_weight = font_weight
  b.text_align = text_align
  b.line_height = line_height
  b.letter_spacing = letter_spacing
  b.text_decoration = text_decoration
  b.white_space = white_space
  b.border_width = border_width
  match border_color {
    Some(c) => b.border_color = Some(check_color(parse_color(c)))
    None => ()
  }
  b.border_radius = border_radius
  b.visibility = visibility
  b.cursor = cursor
  self.hover = Some(merge_bucket(self.hover, b))
  self
}

///|
/// 状态方法：收**属性参数**现场开块，写进 `active`（按下）桶；已有桶则逐属性
/// 并入（§1.3「合并/覆盖按桶内逐属性递归」）。签名里只有绘制期属性——布局参数混进去会把「画的时候」和「量的时候」搅在一起（design.md §1.5 第五条）。labelled 参数没有透传语法（§1.6），三块构造体各写一遍。
pub fn Style::active(
  self : Style,
  color? : String,
  background_color? : String,
  font_size? : Double,
  font_family? : String,
  font_weight? : FontWeight,
  text_align? : TextAlign,
  line_height? : Double,
  letter_spacing? : Double,
  text_decoration? : TextDecoration,
  white_space? : WhiteSpace,
  border_width? : Double,
  border_color? : String,
  border_radius? : Double,
  visibility? : Visibility,
  cursor? : Int,
) -> Style {
  let b = empty_style()
  match color {
    Some(c) => b.color = Some(check_color(parse_color(c)))
    None => ()
  }
  match background_color {
    Some(c) => b.background_color = Some(check_color(parse_color(c)))
    None => ()
  }
  b.font_size = font_size
  b.font_family = font_family
  b.font_weight = font_weight
  b.text_align = text_align
  b.line_height = line_height
  b.letter_spacing = letter_spacing
  b.text_decoration = text_decoration
  b.white_space = white_space
  b.border_width = border_width
  match border_color {
    Some(c) => b.border_color = Some(check_color(parse_color(c)))
    None => ()
  }
  b.border_radius = border_radius
  b.visibility = visibility
  b.cursor = cursor
  self.active = Some(merge_bucket(self.active, b))
  self
}

///|
/// 状态方法：收**属性参数**现场开块，写进 `focus`（键盘焦点）桶；已有桶则逐属性
/// 并入（§1.3「合并/覆盖按桶内逐属性递归」）。签名里只有绘制期属性——布局参数混进去会把「画的时候」和「量的时候」搅在一起（design.md §1.5 第五条）。labelled 参数没有透传语法（§1.6），三块构造体各写一遍。
pub fn Style::focus(
  self : Style,
  color? : String,
  background_color? : String,
  font_size? : Double,
  font_family? : String,
  font_weight? : FontWeight,
  text_align? : TextAlign,
  line_height? : Double,
  letter_spacing? : Double,
  text_decoration? : TextDecoration,
  white_space? : WhiteSpace,
  border_width? : Double,
  border_color? : String,
  border_radius? : Double,
  visibility? : Visibility,
  cursor? : Int,
) -> Style {
  let b = empty_style()
  match color {
    Some(c) => b.color = Some(check_color(parse_color(c)))
    None => ()
  }
  match background_color {
    Some(c) => b.background_color = Some(check_color(parse_color(c)))
    None => ()
  }
  b.font_size = font_size
  b.font_family = font_family
  b.font_weight = font_weight
  b.text_align = text_align
  b.line_height = line_height
  b.letter_spacing = letter_spacing
  b.text_decoration = text_decoration
  b.white_space = white_space
  b.border_width = border_width
  match border_color {
    Some(c) => b.border_color = Some(check_color(parse_color(c)))
    None => ()
  }
  b.border_radius = border_radius
  b.visibility = visibility
  b.cursor = cursor
  self.focus = Some(merge_bucket(self.focus, b))
  self
}

