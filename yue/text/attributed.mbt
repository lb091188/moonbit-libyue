// 富文本与布局选项：与旧契约 `yue/painter.mbt` 的 TextAlign / TextFormat /
// TextAttributes / AttributedText 同名同义，含**区间属性**
// （`set_font_for`/`set_color_for`）。区间一律是 **UTF-8 字节下标**
// [start, end)（与编辑内核同口径）；libyue 用字符区间，属已知口径分岔。
// 默认字体是 `font_body()`（空族名 + 13px），主题接线后由主题层给默认值。
//
// 实现形态：本对象只存数据（文本 + 格式 + 基准字体/颜色 + 区间表），每次测量或
// 绘制时把会话建到 C 端的 `rt_*` 槽表上、用完立刻 `rt_free`——不留长驻句柄，
// 也就不存在「对象被 GC 而 C 侧还握着指针」这类问题。

///|
#borrow(text, family)
extern "c" fn rt_new(
  text : Bytes,
  tlen : Int,
  size : Double,
  family : Bytes,
  flen : Int,
  weight : Int,
  italic : Int,
) -> Int64 = "rt_new"

///|
extern "c" fn rt_free(h : Int64) -> Unit = "rt_free"

///|
extern "c" fn rt_set_format(
  h : Int64,
  align : Int,
  valign : Int,
  wrap : Int,
  ellipsize : Int,
) -> Unit = "rt_set_format"

///|
extern "c" fn rt_add_color(
  h : Int64,
  start : Int,
  end : Int,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit = "rt_add_color"

///|
#borrow(family)
extern "c" fn rt_add_font(
  h : Int64,
  start : Int,
  end : Int,
  family : Bytes,
  flen : Int,
  size : Double,
  weight : Int,
  italic : Int,
) -> Unit = "rt_add_font"

///|
#borrow(out_w, out_h, out_baseline)
extern "c" fn rt_measure(
  h : Int64,
  box_w : Double,
  out_w : Ref[Int],
  out_h : Ref[Int],
  out_baseline : Ref[Int],
) -> Int = "rt_measure"

///|
#borrow(data)
extern "c" fn rt_draw(
  h : Int64,
  data : FixedArray[Byte],
  buf_w : Int,
  buf_h : Int,
  x : Double,
  y : Double,
  box_w : Double,
  box_h : Double,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Int = "rt_draw"

///|
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
///|
/// 一条区间属性（`[start, end)` 为 **UTF-8 字节下标**；字体与颜色至多其一）。
pub(all) struct TextRange {
  start : Int
  end : Int
  font : Font?
  color : @render.Color?
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
  mut spans : Array[TextRange]
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
    spans: [],
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
    spans: [],
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
/// 对 [start, end) **字节区间**设字体（后设的覆盖先设的）。
pub fn AttributedText::set_font_for(
  self : AttributedText,
  font : Font,
  start : Int,
  end : Int,
) -> Unit {
  self.spans.push({ start, end, font: Some(font), color: None, })
}

///|
/// 对 [start, end) **字节区间**设颜色；hex 非法时不做任何事。
pub fn AttributedText::set_color_for(
  self : AttributedText,
  hex : String,
  start : Int,
  end : Int,
) -> Unit {
  match @render.Color::parse(hex) {
    Some(c) => self.spans.push({ start, end, font: None, color: Some(c), })
    None => ()
  }
}

///|
/// 已设的区间属性条数（组件层做「是否走富文本路径」的判据用）。
pub fn AttributedText::range_count(self : AttributedText) -> Int {
  self.spans.length()
}

///|
/// 把本对象物化成 C 端会话句柄（0 = 建不了，调用方须回落到无区间的路径）。
fn AttributedText::rt(self : AttributedText) -> Int64 {
  let f = self.effective_font()
  let tb = @utf8.encode(self.text)
  let fb = @utf8.encode(f.name)
  let h = rt_new(
    tb,
    tb.length(),
    f.size,
    fb,
    fb.length(),
    weight_value(f.weight),
    style_id(f.style),
  )
  if h == 0L {
    return 0L
  }
  rt_set_format(
    h,
    align_id(self.align),
    align_id(self.valign),
    if self.wrap { 1 } else { 0 },
    if self.ellipsis { 1 } else { 0 },
  )
  for sp in self.spans {
    match sp.color {
      Some(c) => rt_add_color(h, sp.start, sp.end, c.r, c.g, c.b, c.a)
      None => ()
    }
    match sp.font {
      Some(sf) => {
        let sfb = @utf8.encode(sf.name)
        rt_add_font(
          h,
          sp.start,
          sp.end,
          sfb,
          sfb.length(),
          sf.size,
          weight_value(sf.weight),
          style_id(sf.style),
        )
      }
      None => ()
    }
  }
  h
}

///|
/// 查询在给定可用空间内布局后的文本包围盒（w<=0 不约束宽度；后端不可用给零尺寸）。
pub fn AttributedText::get_bounds_for(
  self : AttributedText,
  w : Double,
  h : Double,
) -> SizeF {
  let _ = h
  let h = self.rt()
  if h == 0L {
    return { width: 0.0, height: 0.0 }
  }
  let ow = Ref(0)
  let oh = Ref(0)
  let ob = Ref(0)
  let ok = rt_measure(h, w, ow, oh, ob)
  rt_free(h)
  if ok != 1 {
    { width: 0.0, height: 0.0 }
  } else {
    { width: ow.val.to_double(), height: oh.val.to_double() }
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
  let session = self.rt()
  if session == 0L {
    return false
  }
  let base = match @render.Color::parse(
    match self.color {
      Some(c) => c
      None => "#000"
    },
  ) {
    Some(c) => c
    None => { r: 0, g: 0, b: 0, a: 255 }
  }
  let ok = rt_draw(
    session,
    target.data,
    target.width,
    target.height,
    x,
    y,
    w,
    h,
    base.r,
    base.g,
    base.b,
    base.a,
  )
  rt_free(session)
  ok == 1
}
