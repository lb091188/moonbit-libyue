// 2D 绘制：Painter（仅 on_draw 回调期内有效）与离屏 Canvas。
// 坐标为逻辑像素，角度为弧度；颜色为 hex（#RGB/#RGBA/#RRGGBB/#RRGGBBAA）。

///|
pub fn Painter::save(self : Painter) -> Unit {
  ffi_painter_save(self)
}

///|
pub fn Painter::restore(self : Painter) -> Unit {
  ffi_painter_restore(self)
}

///|
pub fn Painter::begin_path(self : Painter) -> Unit {
  ffi_painter_begin_path(self)
}

///|
pub fn Painter::close_path(self : Painter) -> Unit {
  ffi_painter_close_path(self)
}

///|
pub fn Painter::move_to(self : Painter, x : Double, y : Double) -> Unit {
  ffi_painter_move_to(self, x, y)
}

///|
pub fn Painter::line_to(self : Painter, x : Double, y : Double) -> Unit {
  ffi_painter_line_to(self, x, y)
}

///|
pub fn Painter::bezier_curve_to(
  self : Painter,
  cp1x : Double,
  cp1y : Double,
  cp2x : Double,
  cp2y : Double,
  x : Double,
  y : Double,
) -> Unit {
  ffi_painter_bezier_curve_to(self, cp1x, cp1y, cp2x, cp2y, x, y)
}

///|
/// 圆弧。逆时针方向由库内换算为负角跨度（等价 canvas 语义）。
pub fn Painter::arc(
  self : Painter,
  x : Double,
  y : Double,
  radius : Double,
  start_angle : Double,
  end_angle : Double,
  ccw? : Bool = false,
) -> Unit {
  ffi_painter_arc(
    self,
    x,
    y,
    radius,
    start_angle,
    end_angle,
    if ccw {
      1
    } else {
      0
    },
  )
}

///|
pub fn Painter::fill(self : Painter) -> Unit {
  ffi_painter_fill(self)
}

///|
pub fn Painter::stroke(self : Painter) -> Unit {
  ffi_painter_stroke(self)
}

///|
pub fn Painter::clip_rect(
  self : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  ffi_painter_clip_rect(self, x, y, w, h)
}

///|
pub fn Painter::fill_rect(
  self : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  ffi_painter_fill_rect(self, x, y, w, h)
}

///|
pub fn Painter::stroke_rect(
  self : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  ffi_painter_stroke_rect(self, x, y, w, h)
}

///|
pub fn Painter::set_fill_color(self : Painter, hex : String) -> Unit {
  ffi_painter_set_fill_color(self, utf8_bytes(hex))
}

///|
pub fn Painter::set_stroke_color(self : Painter, hex : String) -> Unit {
  ffi_painter_set_stroke_color(self, utf8_bytes(hex))
}

///|
pub fn Painter::translate(self : Painter, dx : Double, dy : Double) -> Unit {
  ffi_painter_translate(self, dx, dy)
}

///|
pub fn Painter::scale(self : Painter, sx : Double, sy : Double) -> Unit {
  ffi_painter_scale(self, sx, sy)
}

///|
pub fn Painter::rotate(self : Painter, angle : Double) -> Unit {
  ffi_painter_rotate(self, angle)
}

///|
/// 文本对齐（start/center/end）。
pub(all) enum TextAlign {
  Start
  Center
  End
}

///|
fn align_id(a : TextAlign) -> Int {
  match a {
    Start => 0
    Center => 1
    End => 2
  }
}

///|
/// 在矩形内绘制文本（指定水平/垂直对齐与颜色）。
pub fn Painter::draw_text(
  self : Painter,
  text : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  align? : TextAlign = Start,
  valign? : TextAlign = Start,
  color? : String = "#000",
) -> Unit {
  ffi_painter_draw_text(
    self,
    utf8_bytes(text),
    x,
    y,
    w,
    h,
    align_id(align),
    align_id(valign),
    utf8_bytes(color),
  )
}

///|
/// 绘制富文本对象。
pub fn Painter::draw_attributed_text(
  self : Painter,
  at : AttributedText,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  ffi_painter_draw_attributed_text(self, at, x, y, w, h)
}

///|
/// 绘制图片（拉伸到目标矩形）。
pub fn Painter::draw_image(
  self : Painter,
  image : Image,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  ffi_painter_draw_image(self, image, x, y, w, h)
}

///|
/// 源矩形 → 目标矩形绘制图片。
pub fn Painter::draw_image_from_rect(
  self : Painter,
  image : Image,
  sx : Double,
  sy : Double,
  sw : Double,
  sh : Double,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
) -> Unit {
  ffi_painter_draw_image_from_rect(self, image, sx, sy, sw, sh, dx, dy, dw, dh)
}

///|
/// 绘制离屏画布（拉伸到目标矩形）。
pub fn Painter::draw_canvas(
  self : Painter,
  canvas : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  ffi_painter_draw_canvas(self, canvas, x, y, w, h)
}

///|
/// 源矩形 → 目标矩形绘制离屏画布。
pub fn Painter::draw_canvas_from_rect(
  self : Painter,
  canvas : Canvas,
  sx : Double,
  sy : Double,
  sw : Double,
  sh : Double,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
) -> Unit {
  ffi_painter_draw_canvas_from_rect(
    self, canvas, sx, sy, sw, sh, dx, dy, dw, dh,
  )
}

///|
/// 创建离屏画布（主屏缩放系数）。
pub fn Canvas::new(width : Double, height : Double) -> Canvas {
  ffi_canvas_new(width, height)
}

///|
/// 取离屏画布的绘制器（画布存续期内有效）。
pub fn Canvas::get_painter(self : Canvas) -> Painter {
  ffi_canvas_get_painter(self)
}

///|
/// 创建富文本（可设字体/颜色/换行/省略，可查询布局包围盒）。
pub fn AttributedText::new(
  text : String,
  align? : TextAlign = Start,
  valign? : TextAlign = Start,
  wrap? : Bool = true,
  ellipsis? : Bool = false,
) -> AttributedText {
  ffi_attributed_text_new(
    utf8_bytes(text),
    align_id(align),
    align_id(valign),
    if wrap {
      1
    } else {
      0
    },
    if ellipsis {
      1
    } else {
      0
    },
  )
}

///|
/// 文本布局选项（对照 nu::TextFormat）。
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
/// 按属性创建富文本。
pub fn AttributedText::new_with(
  text : String,
  attrs : TextAttributes,
) -> AttributedText {
  let at = ffi_attributed_text_new(
    utf8_bytes(text),
    align_id(attrs.align),
    align_id(attrs.valign),
    if attrs.wrap {
      1
    } else {
      0
    },
    if attrs.ellipsis {
      1
    } else {
      0
    },
  )
  match attrs.font {
    Some(f) => at.set_font(f)
    None => ()
  }
  match attrs.color {
    Some(hex) => at.set_color(hex)
    None => ()
  }
  at
}

///|
/// 整体重设布局选项。
pub fn AttributedText::set_format(
  self : AttributedText,
  format : TextFormat,
) -> Unit {
  ffi_attributed_text_set_format(
    self,
    align_id(format.align),
    align_id(format.valign),
    if format.wrap {
      1
    } else {
      0
    },
    if format.ellipsis {
      1
    } else {
      0
    },
  )
}

///|
pub fn AttributedText::set_font(self : AttributedText, font : Font) -> Unit {
  ffi_attributed_text_set_font(self, font)
}

///|
// Windows 的 AttributedText 只支持全文范围的字体/颜色（上游限制，见
// docs/adaptation.md），区间 API 在此统一降级为无操作并只告警一次。

///|
// 区间字体/颜色:GDI+ 无富文本,fork v0.15.6-mbt.9 起 Windows 由 shim
// 侧分段布局绘制,三平台语义一致,不再降级。
///|
/// 对 [start, end) 字符区间设字体。
pub fn AttributedText::set_font_for(
  self : AttributedText,
  font : Font,
  start : Int,
  end : Int,
) -> Unit {
  ffi_attributed_text_set_font_for(self, font, start, end)
}

///|
pub fn AttributedText::set_color(self : AttributedText, hex : String) -> Unit {
  ffi_attributed_text_set_color(self, utf8_bytes(hex))
}

///|
/// 查询在给定可用空间内布局后的文本包围盒尺寸。
pub fn AttributedText::get_bounds_for(
  self : AttributedText,
  w : Double,
  h : Double,
) -> SizeF {
  let out_w = Ref(0.0)
  let out_h = Ref(0.0)
  ffi_attributed_text_get_bounds_for(self, w, h, out_w, out_h)
  { width: out_w.val, height: out_h.val, }
}

///|
/// 对 [start, end) 字符区间设颜色。
pub fn AttributedText::set_color_for(
  self : AttributedText,
  hex : String,
  start : Int,
  end : Int,
) -> Unit {
  ffi_attributed_text_set_color_for(self, utf8_bytes(hex), start, end)
}

///|
/// 取当前文本。
pub fn AttributedText::get_text(self : AttributedText) -> String {
  @utf8.decode_lossy(ffi_attributed_text_get_text(self))
}

///|
/// 替换文本（保留属性）。
pub fn AttributedText::set_text(self : AttributedText, text : String) -> Unit {
  ffi_attributed_text_set_text(self, utf8_bytes(text))
}

///|
/// 清空文本。
pub fn AttributedText::clear(self : AttributedText) -> Unit {
  ffi_attributed_text_clear(self)
}

///|
/// 字重（数值语义与 CSS 一致）。
pub(all) enum FontWeight {
  Thin
  ExtraLight
  Light
  Normal
  Medium
  SemiBold
  Bold
  ExtraBold
  Black
}

///|
fn weight_id(w : FontWeight) -> Int {
  match w {
    Thin => 100
    ExtraLight => 200
    Light => 300
    Normal => 400
    Medium => 500
    SemiBold => 600
    Bold => 700
    ExtraBold => 800
    Black => 900
  }
}

///|
/// 字形。
pub(all) enum FontStyle {
  Roman
  Italic
}

///|
/// 创建字体。
pub fn Font::new(
  name : String,
  size : Double,
  weight? : FontWeight = Normal,
  style? : FontStyle = Roman,
) -> Font {
  ffi_font_new(
    utf8_bytes(name),
    size,
    weight_id(weight),
    match style {
      Roman => 0
      Italic => 1
    },
  )
}

///|
/// 混合模式（对照 nu::BlendMode，数值直传）。
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  SoftLight
  HardLight
  Difference
  Exclusion
  Hue
  Saturation
  Color
  Luminosity
  Clear
  Copy
  SourceIn
  SourceOut
  SourceAtop
  DestinationOver
  DestinationIn
  DestinationAtop
  Xor
}

///|
fn blend_mode_id(m : BlendMode) -> Int {
  match m {
    Normal => 0
    Multiply => 1
    Screen => 2
    Overlay => 3
    Darken => 4
    Lighten => 5
    ColorDodge => 6
    ColorBurn => 7
    SoftLight => 8
    HardLight => 9
    Difference => 10
    Exclusion => 11
    Hue => 12
    Saturation => 13
    Color => 14
    Luminosity => 15
    Clear => 16
    Copy => 17
    SourceIn => 18
    SourceOut => 19
    SourceAtop => 20
    DestinationOver => 21
    DestinationIn => 22
    DestinationAtop => 23
    Xor => 24
  }
}

///|
/// 设置绘制混合模式（后续绘制操作生效）。
pub fn Painter::set_blend_mode(self : Painter, mode : BlendMode) -> Unit {
  ffi_painter_set_blend_mode(self, blend_mode_id(mode))
}

///|
/// 从内存解码图片（PNG/JPEG，对照 Image(Buffer, scale_factor)）。
pub fn Image::new_from_png(data : Bytes, scale? : Double = 1.0) -> Image {
  ffi_image_new_from_data(data, data.length(), scale)
}

///|
/// 图片是否为空（加载失败等）。
pub fn Image::is_empty(self : Image) -> Bool {
  ffi_image_is_empty(self) == 1
}

///|
pub fn Image::get_scale_factor(self : Image) -> Double {
  ffi_image_get_scale_factor(self)
}

///|
/// 缩放为新图片（原图不变）。
pub fn Image::resize(
  self : Image,
  width : Double,
  height : Double,
  scale? : Double = 1.0,
) -> Image {
  ffi_image_resize(self, width, height, scale)
}

///|
/// 导出为图片文件（Linux 支持 "png"）。
pub fn Image::write_to_file(
  self : Image,
  format : String,
  path : String,
) -> Bool {
  ffi_image_write_to_file(self, utf8_bytes(format), utf8_bytes(path)) == 1
}

///|
/// 从文件加载图片。
pub fn Image::new_from_file(path : String) -> Image {
  ffi_image_new_from_file(utf8_bytes(path))
}

///|
/// 图片宽度（像素）。
pub fn Image::get_width(self : Image) -> Double {
  ffi_image_get_width(self)
}

///|
/// 图片高度（像素）。
pub fn Image::get_height(self : Image) -> Double {
  ffi_image_get_height(self)
}

///|
/// 可选图片槽：供消费方保存/读取拖拽得到的图片而不必引用底层句柄类型。
pub(all) struct ImageSlot {
  mut value : Image?
}

///|
pub fn ImageSlot::new() -> ImageSlot {
  { value: None, }
}

///|
pub fn ImageSlot::set(self : ImageSlot, img : Image?) -> Unit {
  self.value = img
}

///|
pub fn ImageSlot::get(self : ImageSlot) -> Image? {
  self.value
}
