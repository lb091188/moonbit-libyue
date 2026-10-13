// 图片：解码产物与绘制源。解码走平台系统能力（Linux GdkPixbuf / Windows WIC），
// PNG/JPEG/GIF 首帧等，像素统一转成本栈 Bitmap 布局（ARGB32 预乘），此后绘制与
// 离屏画布走同一条 blit 通道。
//
// 尺寸语义照旧契约（libyue `image_gtk.cc:75-77`）：`get_width`/`get_height`
// 返回**逻辑尺寸**（像素 / scale），`get_scale_factor` 返回记录的比例。
// 动图（GIF）另走 `Animation`（本文件末尾）：静态解码仍只取首帧。

///|
#borrow(data)
extern "c" fn img_decode_bytes(data : Bytes, len : Int) -> Int64 = "img_decode_bytes"

///|
#borrow(path)
extern "c" fn img_decode_file(path : Bytes, len : Int) -> Int64 = "img_decode_file"

///|
extern "c" fn img_w(h : Int64) -> Int = "img_w"

///|
extern "c" fn img_h(h : Int64) -> Int = "img_h"

///|
#borrow(out)
extern "c" fn img_copy(h : Int64, out : FixedArray[Byte]) -> Int = "img_copy"

///|
extern "c" fn img_free(h : Int64) -> Unit = "img_free"

///|
#borrow(path)
extern "c" fn img_anim_decode_file(
  path : Bytes,
  len : Int,
) -> Int64 = "img_anim_decode_file"

///|
extern "c" fn img_anim_is_static(h : Int64) -> Int = "img_anim_is_static"

///|
extern "c" fn img_anim_w(h : Int64) -> Int = "img_anim_w"

///|
extern "c" fn img_anim_h(h : Int64) -> Int = "img_anim_h"

///|
extern "c" fn img_anim_delay_ms(h : Int64) -> Int = "img_anim_delay_ms"

///|
extern "c" fn img_anim_frame(h : Int64) -> Int = "img_anim_frame"

///|
extern "c" fn img_anim_advance(h : Int64) -> Int = "img_anim_advance"

///|
#borrow(out)
extern "c" fn img_anim_copy(h : Int64, out : FixedArray[Byte]) -> Int = "img_anim_copy"

///|
extern "c" fn img_anim_free(h : Int64) -> Unit = "img_anim_free"

///|
pub(all) struct Image {
  pixels : Bitmap
  scale : Double
}

///|
fn image_of(h : Int64, scale : Double) -> Image {
  let s = if scale <= 0.0 { 1.0 } else { scale }
  if h == 0L {
    return { pixels: Bitmap::new(0, 0), scale: s }
  }
  let w = img_w(h)
  let ht = img_h(h)
  let bm = Bitmap::new(w, ht)
  let ok = img_copy(h, bm.data)
  img_free(h)
  if ok == 0 {
    { pixels: Bitmap::new(0, 0), scale: s }
  } else {
    { pixels: bm, scale: s }
  }
}

///|
/// 从内存解码图片（PNG/JPEG/GIF 首帧等，按内容嗅探；名字沿用旧契约）。
/// 解码失败得到空图（`is_empty` 为真）。
pub fn Image::new_from_png(data : Bytes, scale? : Double = 1.0) -> Image {
  image_of(img_decode_bytes(data, data.length()), scale)
}

///|
/// 从文件解码图片；读不到或格式不支持得到空图。
pub fn Image::new_from_file(path : String) -> Image {
  let p = @utf8.encode(path)
  image_of(img_decode_file(p, p.length()), 1.0)
}

///|
/// 直接以现有位图为像素源（视频帧、离屏快照等自产数据用，免一次编解码）。
pub fn Image::from_bitmap(bitmap : Bitmap, scale? : Double = 1.0) -> Image {
  let s = if scale <= 0.0 { 1.0 } else { scale }
  { pixels: bitmap, scale: s }
}

///|
pub fn Image::is_empty(self : Image) -> Bool {
  self.pixels.width <= 0 || self.pixels.height <= 0
}

///|
pub fn Image::get_scale_factor(self : Image) -> Double {
  self.scale
}

///|
/// 逻辑宽度（像素宽 / scale）。
pub fn Image::get_width(self : Image) -> Double {
  self.pixels.width.to_double() / self.scale
}

///|
/// 逻辑高度（像素高 / scale）。
pub fn Image::get_height(self : Image) -> Double {
  self.pixels.height.to_double() / self.scale
}

///|
/// 缩放为新图片（原图不变）；目标像素尺寸 = 逻辑尺寸 × scale（照旧契约）。
/// 经 `Painter::draw_image` 画到目标位图：Cairo 与纯光栅两个后端都支持
/// 拉伸 blit——原实现只开 Cairo 会话，Windows 无 Cairo 后端时整帧返回空图。
pub fn Image::resize(
  self : Image,
  width : Double,
  height : Double,
  scale? : Double = 1.0,
) -> Image {
  let s = if scale <= 0.0 { 1.0 } else { scale }
  let dw = (width * s + 0.5).floor().to_int()
  let dh = (height * s + 0.5).floor().to_int()
  let dst = Bitmap::new(if dw < 0 { 0 } else { dw }, if dh < 0 { 0 } else { dh })
  if self.is_empty() || dst.width == 0 || dst.height == 0 {
    return { pixels: dst, scale: s }
  }
  let p = Painter::new(dst)
  p.draw_image(self, 0.0, 0.0, dst.width.to_double(), dst.height.to_double())
  p.end()
  { pixels: dst, scale: s }
}

///|
/// 导出为图片文件；当前只支持 "png"（jpeg 等未接），其余格式或写失败返回 false。
pub fn Image::write_to_file(
  self : Image,
  format : String,
  path : String,
) -> Bool {
  if format != "png" || self.is_empty() {
    false
  } else {
    png_write_bitmap(self.pixels, path)
  }
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

///|
/// 动图（GIF）句柄：解码时留在第一帧，组件每拍 `advance` 一次再取当前帧。
/// 槽位有限且不自动回收——不用了要 `close`（组件侧由挂载生命周期负责）。
pub(all) struct Animation {
  mut handle : Int64
  width : Int
  height : Int
  is_static : Bool
}

///|
/// 从文件解码动图。解不出图返回 `None`；静图（PNG/JPEG 或单帧 GIF）返回
/// `is_static=true` 的句柄，`advance` 永远不换帧，组件按静帧画即可。
pub fn Animation::new_from_file(path : String) -> Animation? {
  let b = @utf8.encode(path)
  let h = img_anim_decode_file(b, b.length())
  if h == 0L {
    None
  } else {
    Some({
      handle: h,
      width: img_anim_w(h),
      height: img_anim_h(h),
      is_static: img_anim_is_static(h) != 0,
    })
  }
}

///|
pub fn Animation::is_valid(self : Animation) -> Bool {
  self.handle > 0L && self.width > 0 && self.height > 0
}

///|
/// 当前帧的停留时长（毫秒）；读不到时 C 侧退回 100。
pub fn Animation::delay_ms(self : Animation) -> Int {
  if self.handle == 0L {
    0
  } else {
    img_anim_delay_ms(self.handle)
  }
}

///|
/// 当前帧序号（从 0 起，每次成功 `advance` 加一；归零即说明动画回绕了）。
pub fn Animation::frame(self : Animation) -> Int {
  if self.handle == 0L {
    -1
  } else {
    img_anim_frame(self.handle)
  }
}

///|
/// 前进一帧，返回是否真的换了帧。
pub fn Animation::advance(self : Animation) -> Bool {
  self.handle != 0L && img_anim_advance(self.handle) != 0
}

///|
/// 取当前帧为静态 `Image`（尺寸与整幅不符的帧会被跳过，返回空图）。
pub fn Animation::current(self : Animation) -> Image {
  if self.handle == 0L {
    return { pixels: Bitmap::new(0, 0), scale: 1.0 }
  }
  let bm = Bitmap::new(self.width, self.height)
  if img_anim_copy(self.handle, bm.data) == 0 {
    { pixels: Bitmap::new(0, 0), scale: 1.0 }
  } else {
    { pixels: bm, scale: 1.0 }
  }
}

///|
/// 释放底层槽位（幂等；之后所有方法都是空操作）。
pub fn Animation::close(self : Animation) -> Unit {
  if self.handle != 0L {
    img_anim_free(self.handle)
    self.handle = 0L
  }
}
