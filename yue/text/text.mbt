// 文本层（Linux = Pango）：测量与绘制。测量结果是布局层 measure/baseline
// 回调的数据来源（G7 接线），绘制目标始终是 yue/render 的自有缓冲。
//
// 口径：字号是**逻辑像素**（不是磅）；(x,y) 是布局盒左上角；`baseline` 是
// 首行基线到盒顶的距离，与 yoga-mbt 的 `set_baseline`「基线到内容盒顶部」
// 同一定义，接线时不需要换算。

///|
#borrow(text, family, out_w, out_h, out_baseline)
extern "c" fn pt_measure(
  text : Bytes,
  len : Int,
  size : Double,
  family : Bytes,
  max_width : Int,
  ellipsize : Int,
  wrap : Int,
  out_w : Ref[Int],
  out_h : Ref[Int],
  out_baseline : Ref[Int],
) -> Int = "pt_measure"

///|
#borrow(family, out_h, out_ascent)
extern "c" fn pt_font_line_height(
  size : Double,
  family : Bytes,
  out_h : Ref[Int],
  out_ascent : Ref[Int],
) -> Int = "pt_font_line_height"

///|
#borrow(data, text, family)
extern "c" fn pt_draw(
  data : FixedArray[Byte],
  buf_w : Int,
  buf_h : Int,
  x : Double,
  y : Double,
  text : Bytes,
  len : Int,
  size : Double,
  family : Bytes,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
  max_width : Int,
  ellipsize : Int,
  wrap : Int,
) -> Int = "pt_draw"

///|
pub(all) struct TextMetrics {
  width : Int
  height : Int
  baseline : Int
}

///|
/// 量一段文本。后端不可用（非 Linux 或无字体服务）返回 None。
pub fn measure(
  text : String,
  size : Double,
  family? : String = "",
  max_width? : Int = 0,
  ellipsize? : Bool = false,
  wrap? : Bool = false,
) -> TextMetrics? {
  let tb = @utf8.encode(text)
  let fb = @utf8.encode(family)
  let ow = Ref(0)
  let oh = Ref(0)
  let ob = Ref(0)
  let ok = pt_measure(
    tb,
    tb.length(),
    size,
    fb,
    max_width,
    if ellipsize { 1 } else { 0 },
    if wrap { 1 } else { 0 },
    ow,
    oh,
    ob,
  )
  if ok != 1 {
    None
  } else {
    Some({ width: ow.val, height: oh.val, baseline: ob.val })
  }
}

///|
/// 单行行高：字体 ascent+descent（像素），**与样例文本无关**——绑文本会把
/// 有无下伸部（g/y）当成行高差，布局盒高会随内容抖。探针记的「14px 量得
/// 17」是文本 "M" 的盒高（等于首行基线），不是行高，两者在这里分开。
pub fn line_height(size : Double, family? : String = "") -> Option[Int] {
  let fb = @utf8.encode(family)
  let oh = Ref(0)
  let oa = Ref(0)
  if pt_font_line_height(size, fb, oh, oa) == 1 {
    Some(oh.val)
  } else {
    None
  }
}

///|
/// 首行基线（ascent，像素），给自绘 caret 与文本垂直居中使用。
pub fn line_ascent(size : Double, family? : String = "") -> Option[Int] {
  let fb = @utf8.encode(family)
  let oh = Ref(0)
  let oa = Ref(0)
  if pt_font_line_height(size, fb, oh, oa) == 1 {
    Some(oa.val)
  } else {
    None
  }
}

///|
/// 把文本画进位图。颜色 hex 非法时按黑色（与 Cairo 侧一致的兜底），
/// 后端不可用或目标为空返回 false。
pub fn draw_to(
  target : @render.Bitmap,
  x : Double,
  y : Double,
  text : String,
  size : Double,
  color : String,
  family? : String = "",
  max_width? : Int = 0,
  ellipsize? : Bool = false,
  wrap? : Bool = false,
) -> Bool {
  if target.width < 1 || target.height < 1 {
    return false
  }
  let tb = @utf8.encode(text)
  if tb.length() == 0 {
    return true
  }
  let fb = @utf8.encode(family)
  let c = match @render.Color::parse(color) {
    Some(c) => c
    None => { r: 0, g: 0, b: 0, a: 255 }
  }
  pt_draw(
    target.data,
    target.width,
    target.height,
    x,
    y,
    tb,
    tb.length(),
    size,
    fb,
    c.r,
    c.g,
    c.b,
    c.a,
    max_width,
    if ellipsize { 1 } else { 0 },
    if wrap { 1 } else { 0 },
  ) == 1
}
