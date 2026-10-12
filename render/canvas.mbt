// 离屏画布：一块自有位图 + 取绘制器的入口。与 Image 的分工——Canvas 是
// 「可继续画的目标」，Image 是「解码出来的源」；两者都经
// `Painter::draw_canvas` / `draw_image` 画到窗口位图上。

///|
pub(all) struct Canvas {
  bitmap : Bitmap
}

///|
/// 建离屏画布（尺寸取整，非正得到空画布）。
pub fn Canvas::new(width : Double, height : Double) -> Canvas {
  let w = if width < 0.0 { 0 } else { (width + 0.5).floor().to_int() }
  let h = if height < 0.0 { 0 } else { (height + 0.5).floor().to_int() }
  { bitmap: Bitmap::new(w, h) }
}

///|
/// 取画布的绘制器；返回的 Painter 用完须 `end()`（Cairo 会话槽有限）。
pub fn Canvas::get_painter(self : Canvas) -> Painter {
  Painter::new(self.bitmap)
}

///|
/// 导出画布位图为图片文件；当前只支持 "png"（其余格式返回 false）。
pub fn Canvas::write_to_file(
  self : Canvas,
  format : String,
  path : String,
) -> Bool {
  if format != "png" {
    false
  } else {
    png_write_bitmap(self.bitmap, path)
  }
}
