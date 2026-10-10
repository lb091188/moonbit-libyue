// Cairo 光栅器（本栈的完整绘制路径）——方法名与参数形态与 Painter 契约一致，
// 但绘制目标是**调用方拥有的 Bitmap**（会话期间 #borrow 住，见 cairo_stub.c）：
//   let c = Cairo::over(bm)   // 建会话
//   c.fill_rect(..) / c.begin_path(); c.move_to(..); .. c.fill()
//   c.end()                   // 释放会话（Bitmap 内存始终归 MoonBit）
//
// 与纯 MoonBit 矩形绘制器（Painter）的关系：Painter 是零依赖的矩形级子集，
// Cairo 是抗锯齿路径级的实现，两者的 fill_rect 语义对齐（有无抗锯齿的差别
// 在像素级断言里体现）。`stroke_rect` 仍是**内侧**描边口径（与 border-box
// 同源），Cairo 原语居中，故这里用「4 条边带」复现内侧语义，不是直接
// cairo_rectangle + stroke。

///|
#borrow(data)
extern "c" fn cr_begin(
  data : FixedArray[Byte],
  width : Int,
  height : Int,
) -> Int64 = "cr_begin"

///|
extern "c" fn cr_end(id : Int64) -> Unit = "cr_end"

///|
extern "c" fn cr_begin_path(id : Int64) -> Unit = "cr_begin_path"

///|
extern "c" fn cr_close_path(id : Int64) -> Unit = "cr_close_path"

///|
extern "c" fn cr_move_to(id : Int64, x : Double, y : Double) -> Unit = "cr_move_to"

///|
extern "c" fn cr_line_to(id : Int64, x : Double, y : Double) -> Unit = "cr_line_to"

///|
extern "c" fn cr_bezier_to(
  id : Int64,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit = "cr_bezier_to"

///|
extern "c" fn cr_arc(
  id : Int64,
  cx : Double,
  cy : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
) -> Unit = "cr_arc"

///|
extern "c" fn cr_fill(id : Int64) -> Unit = "cr_fill"

///|
extern "c" fn cr_stroke(id : Int64) -> Unit = "cr_stroke"

///|
extern "c" fn cr_fill_rect(
  id : Int64,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "cr_fill_rect"

///|
extern "c" fn cr_stroke_rect(
  id : Int64,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "cr_stroke_rect"

///|
extern "c" fn cr_set_fill_rgba(
  id : Int64,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit = "cr_set_fill_rgba"

///|
extern "c" fn cr_set_line_width(id : Int64, w : Double) -> Unit = "cr_set_line_width"

///|
extern "c" fn cr_save(id : Int64) -> Unit = "cr_save"

///|
extern "c" fn cr_restore(id : Int64) -> Unit = "cr_restore"

///|
extern "c" fn cr_translate(id : Int64, dx : Double, dy : Double) -> Unit = "cr_translate"

///|
extern "c" fn cr_scale(id : Int64, sx : Double, sy : Double) -> Unit = "cr_scale"

///|
extern "c" fn cr_rotate(id : Int64, rad : Double) -> Unit = "cr_rotate"

///|
extern "c" fn cr_clip_rect(
  id : Int64,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "cr_clip_rect"

///|
extern "c" fn cr_flush(id : Int64) -> Unit = "cr_flush"

///|
extern "c" fn cr_set_operator(id : Int64, mode : Int) -> Unit = "cr_set_operator"

///|
extern "c" fn cr_grad_linear(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Int64 = "cr_grad_linear"

///|
extern "c" fn cr_grad_radial(
  cx : Double,
  cy : Double,
  r0 : Double,
  r1 : Double,
) -> Int64 = "cr_grad_radial"

///|
extern "c" fn cr_grad_stop(
  pid : Int64,
  offset : Double,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit = "cr_grad_stop"

///|
extern "c" fn cr_grad_apply(id : Int64, pid : Int64) -> Unit = "cr_grad_apply"

///|
/// Cairo 绘制会话：目标位图由调用方持有，会话只借它的内存。
pub struct Cairo {
  id : Int64
  // 持有位图引用，保证会话期间内存不被回收
  bitmap : Bitmap
}

///|
/// 在位图上开一个 Cairo 会话；位图为空（尺寸或后端不可用）返回 None。
pub fn Cairo::over(bitmap : Bitmap) -> Cairo? {
  let id = cr_begin(bitmap.data, bitmap.width, bitmap.height)
  if id == 0L {
    None
  } else {
    Some({ id, bitmap })
  }
}

///|
/// 释放会话并把脏数据刷回内存（cairo_surface_flush）。
pub fn Cairo::end(self : Cairo) -> Unit {
  cr_flush(self.id)
  cr_end(self.id)
}

///|
pub fn Cairo::save(self : Cairo) -> Unit {
  cr_save(self.id)
}

///|
pub fn Cairo::restore(self : Cairo) -> Unit {
  cr_restore(self.id)
}

///|
pub fn Cairo::begin_path(self : Cairo) -> Unit {
  cr_begin_path(self.id)
}

///|
pub fn Cairo::close_path(self : Cairo) -> Unit {
  cr_close_path(self.id)
}

///|
pub fn Cairo::move_to(self : Cairo, x : Double, y : Double) -> Unit {
  cr_move_to(self.id, x, y)
}

///|
pub fn Cairo::line_to(self : Cairo, x : Double, y : Double) -> Unit {
  cr_line_to(self.id, x, y)
}

///|
pub fn Cairo::bezier_curve_to(
  self : Cairo,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  cr_bezier_to(self.id, x1, y1, x2, y2, x3, y3)
}

///|
pub fn Cairo::arc(
  self : Cairo,
  cx : Double,
  cy : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
) -> Unit {
  cr_arc(self.id, cx, cy, r, a0, a1)
}

///|
pub fn Cairo::fill(self : Cairo) -> Unit {
  cr_fill(self.id)
}

///|
pub fn Cairo::stroke(self : Cairo) -> Unit {
  cr_stroke(self.id)
}

///|
pub fn Cairo::fill_rect(
  self : Cairo,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  cr_fill_rect(self.id, x, y, w, h)
}

///|
/// 内侧描边（与 Painter 同口径）：四条边带，任一边不足两倍线宽时整块填满。
pub fn Cairo::stroke_rect(
  self : Cairo,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  cr_stroke_rect(self.id, x, y, w, h)
}

///|
pub fn Cairo::translate(self : Cairo, dx : Double, dy : Double) -> Unit {
  cr_translate(self.id, dx, dy)
}

///|
pub fn Cairo::scale(self : Cairo, sx : Double, sy : Double) -> Unit {
  cr_scale(self.id, sx, sy)
}

///|
pub fn Cairo::rotate(self : Cairo, rad : Double) -> Unit {
  cr_rotate(self.id, rad)
}

///|
pub fn Cairo::clip_rect(
  self : Cairo,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  cr_clip_rect(self.id, x, y, w, h)
}

///|
/// 设置填充色（hex 口径同 Painter：非法输入保持原色；Cairo 无独立描边色，
/// 描边前也用它）。
pub fn Cairo::set_fill_color(self : Cairo, hex : String) -> Unit {
  match Color::parse(hex) {
    Some(c) => cr_set_fill_rgba(self.id, c.r, c.g, c.b, c.a)
    None => ()
  }
}

///|
pub fn Cairo::set_stroke_color(self : Cairo, hex : String) -> Unit {
  self.set_fill_color(hex)
}

///|
/// 线宽为负按 0 处理。
pub fn Cairo::set_line_width(self : Cairo, width : Double) -> Unit {
  cr_set_line_width(self.id, if width < 0.0 { 0.0 } else { width })
}

///|
/// 把内存里的颜色对象落为 source（Painter 门面按绘制时机调用）。
fn Cairo::source_rgba(self : Cairo, c : Color) -> Unit {
  cr_set_fill_rgba(self.id, c.r, c.g, c.b, c.a)
}

///|
/// 混合模式（对后续绘制生效）。
pub fn Cairo::set_blend_mode(self : Cairo, mode : BlendMode) -> Unit {
  cr_set_operator(self.id, blend_mode_id(mode))
}

///|
/// 渐变设为当前 source（一次性：建 pattern → 加 stop → 设为 source 即释放句柄）。
pub fn Cairo::set_fill_gradient(self : Cairo, g : Gradient) -> Unit {
  let pid = match g.kind {
    Linear(x0, y0, x1, y1) => cr_grad_linear(x0, y0, x1, y1)
    Radial(cx, cy, r0, r1) => cr_grad_radial(cx, cy, r0, r1)
  }
  if pid == 0L {
    return ()
  }
  for s in g.stops {
    let (off, c) = s
    cr_grad_stop(pid, off, c.r, c.g, c.b, c.a)
  }
  cr_grad_apply(self.id, pid)
}

///|
/// 描边同样只有单一 source，与填充同实现（Painter 门面在描边前自行切换）。
pub fn Cairo::set_stroke_gradient(self : Cairo, g : Gradient) -> Unit {
  self.set_fill_gradient(g)
}

///|
/// 把会话数据刷回缓冲。
pub fn Cairo::flush(self : Cairo) -> Unit {
  cr_flush(self.id)
}
