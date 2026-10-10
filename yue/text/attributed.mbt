// 富文本与布局选项：与旧契约 `yue/painter.mbt` 的 TextAlign / TextFormat /
// TextAttributes / AttributedText 同名同义。本批是**整体属性**面（字体、颜色、
// 对齐、换行、省略、盒内测量）；区间属性（`set_font_for`/`set_color_for`）
// 需要把范围属性挂进 Pango 的 attribute list，属次批。
//
// 口径：区间若落地用 **UTF-8 字节下标**（与编辑内核同源）；libyue 用字符区间，
// 属已知口径分岔。默认字体是 `font_body()`（空族名 + 13px），主题接线后由
// 主题层给默认值。

///|
pub(all) enum TextAlign {
  Start
  Center
  End
}

///|
pub(all) struct TextFormat {
  align : TextAlign
  valign : TextAlign
  wrap : Bool
  ellipsis : Bool
}

///|
/// 默认布局选项（start 对齐、自动换行、无省略，同 libyue 默认值）。
pub fn TextFormat::new() -> TextFormat {
  { align: Start, valign: Start, wrap: true, ellipsis: false, }
}

///|
/// 文本属性（对照 nu::TextAttributes = TextFormat + 字体 + 颜色）。
pub(all) struct TextAttributes {
  align : TextAlign
  valign : TextAlign
  wrap : Bool
  ellipsis : Bool
  font : Font?
  color : String?
}

///|
/// 默认属性（无字体/颜色覆盖）。
pub fn TextAttributes::new() -> TextAttributes {
  {
    align: Start,
    valign: Start,
    wrap: true,
    ellipsis: false,
    font: None,
    color: None,
  }
}

///|
/// 尺寸（对照 nu::SizeF；几何层尚未平移，先随本包给最小定义）。
pub(all) struct SizeF {
  width : Double
  height : Double
}

///|
pub(all) struct AttributedText {
  mut text : String
  mut align : TextAlign
  mut valign : TextAlign
  mut wrap : Bool
  mut ellipsis : Bool
  mut font : Font?
  mut color : String?
}

// 结构体是引用语义，做法与 Painter 同：字段 mut、外层句柄不重绑。

///|
/// 创建富文本（可设对齐/换行/省略）。
pub fn AttributedText::new(
  text : String,
  align? : TextAlign = Start,
  valign? : TextAlign = Start,
  wrap? : Bool = true,
  ellipsis? : Bool = false,
) -> AttributedText {
  {
    text,
    align,
    valign,
    wrap,
    ellipsis,
    font: None,
    color: None,
  }
}

///|
/// 按属性创建富文本。
pub fn AttributedText::new_with(
  text : String,
  attrs : TextAttributes,
) -> AttributedText {
  {
    text,
    align: attrs.align,
    valign: attrs.valign,
    wrap: attrs.wrap,
    ellipsis: attrs.ellipsis,
    font: attrs.font,
    color: attrs.color,
  }
}

///|
/// 整体重设布局选项。
pub fn AttributedText::set_format(
  self : AttributedText,
  format : TextFormat,
) -> Unit {
  self.align = format.align
  self.valign = format.valign
  self.wrap = format.wrap
  self.ellipsis = format.ellipsis
}

///|
pub fn AttributedText::get_format(self : AttributedText) -> TextFormat {
  { align: self.align, valign: self.valign, wrap: self.wrap, ellipsis: self.ellipsis, }
}

///|
pub fn AttributedText::set_font(self : AttributedText, font : Font) -> Unit {
  self.font = Some(font)
}

///|
pub fn AttributedText::set_color(self : AttributedText, hex : String) -> Unit {
  self.color = Some(hex)
}

///|
/// 实际生效的字体（未设时取默认正文字体）。
pub fn AttributedText::effective_font(self : AttributedText) -> Font {
  match self.font {
    Some(f) => f
    None => font_body()
  }
}

///|
pub fn AttributedText::get_text(self : AttributedText) -> String {
  self.text
}

///|
/// 替换文本（保留属性）。
pub fn AttributedText::set_text(self : AttributedText, text : String) -> Unit {
  self.text = text
}

///|
pub fn AttributedText::clear(self : AttributedText) -> Unit {
  self.text = ""
}

///|
/// 查询在给定可用空间内布局后的文本包围盒（w<=0 不约束宽度；后端不可用给零尺寸）。
pub fn AttributedText::get_bounds_for(
  self : AttributedText,
  w : Double,
  h : Double,
) -> SizeF {
  let _ = h
  let mw = if w > 0.0 { (w + 0.5).floor().to_int() } else { 0 }
  match measure_font(
    self.text,
    self.effective_font(),
    max_width=mw,
    ellipsize=self.ellipsis,
    wrap=self.wrap,
  ) {
    Some(m) => { width: m.width.to_double(), height: m.height.to_double() }
    None => { width: 0.0, height: 0.0 }
  }
}

///|
/// 盒内绘制（对齐/换行/省略按本对象属性）。
pub fn AttributedText::draw(
  self : AttributedText,
  target : @render.Bitmap,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Bool {
  let color = match self.color {
    Some(c) => c
    None => "#000"
  }
  draw_in_box(
    target,
    x,
    y,
    w,
    h,
    self.text,
    self.effective_font(),
    color,
    align=self.align,
    valign=self.valign,
    ellipsize=self.ellipsis,
    wrap=self.wrap,
  )
}
