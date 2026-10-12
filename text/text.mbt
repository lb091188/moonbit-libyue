// 文本层（Linux = Pango）：测量与绘制。测量结果是布局层 measure/baseline
// 回调的数据来源（G7 接线），绘制目标始终是 render 的自有缓冲。
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
  weight : Int,
  italic : Int,
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
#borrow(text, family, out_w, out_h, out_baseline)
extern "c" fn pt_measure_font(
  text : Bytes,
  len : Int,
  size : Double,
  family : Bytes,
  weight : Int,
  italic : Int,
  max_width : Int,
  ellipsize : Int,
  wrap : Int,
  out_w : Ref[Int],
  out_h : Ref[Int],
  out_baseline : Ref[Int],
) -> Int = "pt_measure_font"

///|
#borrow(data, text, family)
extern "c" fn pt_draw_box(
  data : FixedArray[Byte],
  buf_w : Int,
  buf_h : Int,
  x : Double,
  y : Double,
  box_w : Double,
  box_h : Double,
  text : Bytes,
  len : Int,
  size : Double,
  family : Bytes,
  weight : Int,
  italic : Int,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
  align : Int,
  valign : Int,
  ellipsize : Int,
  wrap : Int,
) -> Int = "pt_draw_box"

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
  if pt_font_line_height(size, fb, 0, 0, oh, oa) == 1 {
    let floor = line_floor(size)
    Some(if oh.val > floor { oh.val } else { floor })
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
  if pt_font_line_height(size, fb, 0, 0, oh, oa) == 1 {
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

///|
fn align_id(a : TextAlign) -> Int {
  match a {
    Start => 0
    Center => 1
    End => 2
  }
}

///|
/// 按字体量一段文本（字重/斜体参与度量）。
pub fn measure_font(
  text : String,
  font : Font,
  max_width? : Int = 0,
  ellipsize? : Bool = false,
  wrap? : Bool = false,
) -> TextMetrics? {
  let tb = @utf8.encode(text)
  let fb = @utf8.encode(font.name)
  let ow = Ref(0)
  let oh = Ref(0)
  let ob = Ref(0)
  let ok = pt_measure_font(
    tb,
    tb.length(),
    font.size,
    fb,
    weight_value(font.weight),
    style_id(font.style),
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
/// 一份字体的行盒度量（像素）：`ascent` 是基线到盒顶、`descent` 是基线以下，
/// 都来自字体度量本身（字重/斜体参与），与样例文本无关。
pub(all) struct FontMetrics {
  ascent : Int
  descent : Int
}

///|
/// 字体度量。后端不可用返回 None。
pub fn font_metrics(font : Font) -> FontMetrics? {
  let fb = @utf8.encode(font.name)
  let oh = Ref(0)
  let oa = Ref(0)
  if pt_font_line_height(
    font.size,
    fb,
    weight_value(font.weight),
    style_id(font.style),
    oh,
    oa,
  ) ==
    1 {
    Some({ ascent: oa.val, descent: oh.val - oa.val })
  } else {
    None
  }
}

///|
/// 行高 K 地板（平台矩阵定案：行高 = max(引擎自然行高, ceil(size×K))）。
/// K 是实测常量：本机 Windows 10 + 微软雅黑 12..32px 的自然行高比落在
/// 1.29..1.36（最肥一档是 14px→19），取 1.36 作地板——回退到瘦字体（等宽、
/// 位图字）时行高不跟着缩水，行高成为 size 的纯函数；地板顶起来的多余空间
/// 由绘制的盒内垂直居中吸收，观感即半行距。
const LINE_HEIGHT_K : Double = 1.36

///|
/// 行高地板值（size 的纯函数）。
fn line_floor(size : Double) -> Int {
  (size * LINE_HEIGHT_K).ceil().to_int()
}

///|
/// 字体行高（ascent+descent，像素；再套 K 地板），字重/斜体参与度量。
pub fn line_height_font(font : Font) -> Option[Int] {
  font_metrics(font).map(fn(m) {
    let natural = m.ascent + m.descent
    let floor = line_floor(font.size)
    if natural > floor { natural } else { floor }
  })
}

///|
/// 字体首行基线（ascent，像素）。
pub fn line_ascent_font(font : Font) -> Option[Int] {
  font_metrics(font).map(fn(m) { m.ascent })
}

///|
/// **多字体混排的行高**：一行里每个 inline 盒按自己的字体上抛升距与降距，
/// 行盒取「升距最大者 + 降距最大者」（Pango/CSS 的算法），不是「取字号最大的
/// 那一份的行高」——两份字体的 descent 可以来自不同字体。
/// 空表给 None；任一份取不到度量也整体给 None（宁可不给数，也不给按部分字体
/// 算出的偏小行高——布局盒矮了会裁字，比高了难看得多）。
pub fn line_height_multi(fonts : Array[Font]) -> Option[Int] {
  if fonts.length() == 0 {
    return None
  }
  let mut up = 0
  let mut down = 0
  let mut max_size = 0.0
  for f in fonts {
    match font_metrics(f) {
      None => return None
      Some(m) => {
        if m.ascent > up {
          up = m.ascent
        }
        if m.descent > down {
          down = m.descent
        }
        if f.size > max_size {
          max_size = f.size
        }
      }
    }
  }
  // 套 K 地板时用行内最大字号（行高是「最肥那档字号」的纯函数）
  let natural = up + down
  let floor = line_floor(max_size)
  Some(if natural > floor { natural } else { floor })
}

///|
/// 按字体把文本画进位图（(x,y) 为布局盒左上角，语义同 `draw_to`）。
pub fn draw_font(
  target : @render.Bitmap,
  x : Double,
  y : Double,
  text : String,
  font : Font,
  color : String,
  max_width? : Int = 0,
  ellipsize? : Bool = false,
  wrap? : Bool = false,
) -> Bool {
  draw_in_box(
    target,
    x,
    y,
    0.0,
    0.0,
    text,
    font,
    color,
    ellipsize=ellipsize,
    wrap=wrap,
    max_width=max_width,
  )
}

///|
/// 无 Cairo 会话时的绘制通道（Windows 的纯光栅器后端走这条）：文本先画进
/// 自有离屏位图，再经会话的 `blit` 落位——平移、裁剪与混合模式都由会话现算
/// （画的这一趟不经会话，所以吃不到坐标变换，落位统一交给 blit）。
fn draw_box_raster(
  p : @render.Painter,
  x : Double,
  y : Double,
  box_w : Double,
  box_h : Double,
  text : String,
  font : Font,
  color : String,
  align : TextAlign,
  valign : TextAlign,
  ellipsize : Bool,
  wrap : Bool,
) -> Bool {
  let raster = match p.raster() {
    Some(r) => r
    None => return false
  }
  // 离屏尺寸：盒给就按盒，没给就量出来（单行自然宽、包住墨迹即可）
  let measured = if box_w > 0.0 && box_h > 0.0 {
    None
  } else {
    measure_font(
      text,
      font,
      max_width=if box_w > 0.0 { box_w.ceil().to_int() } else { 0 },
      ellipsize=ellipsize,
      wrap=wrap,
    )
  }
  let ow = if box_w > 0.0 {
    box_w.ceil().to_int()
  } else {
    match measured {
      Some(m) => m.width
      None => 0
    }
  }
  let oh = if box_h > 0.0 {
    box_h.ceil().to_int()
  } else {
    match measured {
      Some(m) => m.height
      None => 0
    }
  }
  if ow < 1 || oh < 1 {
    return false
  }
  let off = @render.Bitmap::new(ow, oh)
  if !draw_in_box(
    off,
    0.0,
    0.0,
    box_w,
    box_h,
    text,
    font,
    color,
    align=align,
    valign=valign,
    ellipsize=ellipsize,
    wrap=wrap,
  ) {
    return false
  }
  let dw = ow.to_double()
  let dh = oh.to_double()
  raster.blit(off, 0.0, 0.0, dw, dh, x, y, dw, dh)
  true
}

///|
/// 盒内对齐绘制：`align`/`valign` 在 (x,y,w,h) 盒内对齐；w<=0 时该轴不约束
/// （单行自然宽），h<=0 时竖直不参与对齐。省略/换行语义同 `draw_to`，
/// 宽度约束取 `max_width`（>0 时优先）或盒子宽。
pub fn draw_in_box(
  target : @render.Bitmap,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  text : String,
  font : Font,
  color : String,
  align? : TextAlign = Start,
  valign? : TextAlign = Start,
  ellipsize? : Bool = false,
  wrap? : Bool = true,
  max_width? : Int = 0,
) -> Bool {
  if target.width < 1 || target.height < 1 {
    return false
  }
  let tb = @utf8.encode(text)
  if tb.length() == 0 {
    return true
  }
  let fb = @utf8.encode(font.name)
  let c = match @render.Color::parse(color) {
    Some(c) => c
    None => { r: 0, g: 0, b: 0, a: 255 }
  }
  let bw = if max_width > 0 {
    max_width.to_double()
  } else {
    w
  }
  pt_draw_box(
    target.data,
    target.width,
    target.height,
    x,
    y,
    bw,
    h,
    tb,
    tb.length(),
    font.size,
    fb,
    weight_value(font.weight),
    style_id(font.style),
    c.r,
    c.g,
    c.b,
    c.a,
    align_id(align),
    align_id(valign),
    if ellipsize { 1 } else { 0 },
    if wrap { 1 } else { 0 },
  ) == 1
}

///|
#borrow(text, family)
extern "c" fn pt_draw_box_cr(
  cr_id : Int64,
  x : Double,
  y : Double,
  box_w : Double,
  box_h : Double,
  text : Bytes,
  len : Int,
  size : Double,
  family : Bytes,
  weight : Int,
  italic : Int,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
  align : Int,
  valign : Int,
  ellipsize : Int,
  wrap : Int,
) -> Int = "pt_draw_box_cr"

///|
/// 把文本画在**调用方 Painter 的 Cairo 会话**上：控件原点（宿主的 translate）
/// 与裁剪都生效，所以组件里的文字落在自己盒内、也不会画到邻居身上。
/// 语义与 `draw_in_box` 一致（(x,y) 相对当前坐标系，盒内对齐）。
/// 无 Cairo 会话（纯矩形降级路径）返回 false，由调用方决定退不退。
pub fn draw_box_at(
  p : @render.Painter,
  x : Double,
  y : Double,
  box_w : Double,
  box_h : Double,
  text : String,
  font : Font,
  color : String,
  align? : TextAlign = Start,
  valign? : TextAlign = Start,
  ellipsize? : Bool = false,
  wrap? : Bool = true,
) -> Bool {
  let id = match p.cairo_id() {
    Some(i) => i
    // 纯光栅器后端没有 cairo 会话：走离屏 + blit 的等价通道
    None =>
      return draw_box_raster(
        p,
        x,
        y,
        box_w,
        box_h,
        text,
        font,
        color,
        align,
        valign,
        ellipsize,
        wrap,
      )
  }
  let tb = @utf8.encode(text)
  if tb.length() == 0 {
    return true
  }
  let fb = @utf8.encode(font.name)
  let c = match @render.Color::parse(color) {
    Some(c) => c
    None => { r: 0, g: 0, b: 0, a: 255 }
  }
  pt_draw_box_cr(
    id,
    x,
    y,
    box_w,
    box_h,
    tb,
    tb.length(),
    font.size,
    fb,
    weight_value(font.weight),
    style_id(font.style),
    c.r,
    c.g,
    c.b,
    c.a,
    align_id(align),
    align_id(valign),
    if ellipsize { 1 } else { 0 },
    if wrap { 1 } else { 0 },
  ) == 1
}

///|
/// 单行绘制（不铺盒、不对齐），是 `draw_box_at` 的简化入口。
pub fn draw_at(
  p : @render.Painter,
  x : Double,
  y : Double,
  text : String,
  font : Font,
  color : String,
) -> Bool {
  draw_box_at(p, x, y, 0.0, 0.0, text, font, color, wrap=false)
}

///|
/// 按字号绘制（不铺盒），给「只想画一行字」的调用方用。
pub fn draw_text_at(
  p : @render.Painter,
  x : Double,
  y : Double,
  text : String,
  size : Double,
  color : String,
  family? : String = "",
) -> Bool {
  draw_at(p, x, y, text, Font::new(family, size), color)
}
