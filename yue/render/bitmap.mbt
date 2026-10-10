// RGBA8888 位图：本栈唯一拥有的像素缓冲。
//
// 内部布局与 Cairo 的 `CAIRO_FORMAT_ARGB32` 一致（小端 = 字节序 B,G,R,A，
// 且颜色分量**预乘** alpha）——这样 Cairo 光栅器可以直接画进这块内存，
// 上屏也可以直拷，全链路单一格式、零转换。默认格式是 CGBA(预乘)，`pixel`
// 负责反预乘，所以对外语义仍是普通的 RGBA 分量（0~255，独立于 alpha）。

///|
pub(all) struct Bitmap {
  width : Int
  height : Int
  data : FixedArray[Byte]
}

///|
/// 建新位图并清成全透明；尺寸非正时得到空位图（任何写入被丢弃）。
pub fn Bitmap::new(width : Int, height : Int) -> Bitmap {
  let w = if width < 0 { 0 } else { width }
  let h = if height < 0 { 0 } else { height }
  { width: w, height: h, data: FixedArray::make(w * h * 4, b'\x00') }
}

///|
pub fn Bitmap::inside(self : Bitmap, x : Int, y : Int) -> Bool {
  x >= 0 && y >= 0 && x < self.width && y < self.height
}

// 反预乘：预乘分量 p、alpha a → 独立分量 p*255/a（a=0 视为全透明）。
fn unpremul(p : Int, a : Int) -> Int {
  if a == 0 {
    0
  } else {
    (p * 255 + a / 2) / a
  }
}

///|
/// 取像素（反预乘后的独立 RGBA 分量）；越界返回全透明。
pub fn Bitmap::pixel(self : Bitmap, x : Int, y : Int) -> Color {
  if !self.inside(x, y) {
    color_transparent
  } else {
    let i = (y * self.width + x) * 4
    let bs = self.data
    let b = bs[i].to_int()
    let g = bs[i + 1].to_int()
    let r = bs[i + 2].to_int()
    let a = bs[i + 3].to_int()
    if a == 0 {
      color_transparent
    } else {
      { r: unpremul(r, a), g: unpremul(g, a), b: unpremul(b, a), a }
    }
  }
}

///|
/// source-over 覆盖一个像素（在预乘域上混合，与 Cairo 同一套算术）。
pub fn Bitmap::paint(self : Bitmap, x : Int, y : Int, c : Color) -> Unit {
  if !self.inside(x, y) {
    return ()
  }
  let i = (y * self.width + x) * 4
  let sa = c.a
  // 写像素一律经局部句柄：Bytes 的 op_set 只接受可变接收者，
  // 直接 self.data[..] = .. 会让整个方法要求 `Bitmap &mut`，调用点就得写 mut。
  let d = self.data
  if sa == 255 {
    d[i] = c.b.to_byte()
    d[i + 1] = c.g.to_byte()
    d[i + 2] = c.r.to_byte()
    d[i + 3] = b'\xff'
  } else if sa == 0 {
    ()
  } else {
    // src 预乘
    let sr = (c.r * sa + 127) / 255
    let sg = (c.g * sa + 127) / 255
    let sb = (c.b * sa + 127) / 255
    let inv = 255 - sa
    let mix = fn(s : Int, dst : Int) -> Int { s + (dst * inv + 127) / 255 }
    let db = d[i].to_int()
    let dg = d[i + 1].to_int()
    let dr = d[i + 2].to_int()
    let da = d[i + 3].to_int()
    d[i] = mix(sb, db).to_byte()
    d[i + 1] = mix(sg, dg).to_byte()
    d[i + 2] = mix(sr, dr).to_byte()
    d[i + 3] = mix(sa, da).to_byte()
  }
}

///|
/// 导出为独立分量 RGBA（非预乘、行主序，长度 width*height*4）——
/// PNG 编码等对外格式用；内部绘制一律走预乘缓冲，不经过这里。
pub fn Bitmap::to_rgba_bytes(self : Bitmap) -> Bytes {
  let out = FixedArray::make(self.width * self.height * 4, b'\x00')
  for y = 0; y < self.height; y = y + 1 {
    for x = 0; x < self.width; x = x + 1 {
      let c = self.pixel(x, y)
      let i = (y * self.width + x) * 4
      out[i] = c.r.to_byte()
      out[i + 1] = c.g.to_byte()
      out[i + 2] = c.b.to_byte()
      out[i + 3] = c.a.to_byte()
    }
  }
  Bytes::from_array(out)
}

///|
/// 在闭区间 [x0,x1) × [y0,y1) 内逐像素覆盖；非法区间不做任何事。
pub fn Bitmap::fill_area(
  self : Bitmap,
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  c : Color,
) -> Unit {
  if x1 <= x0 || y1 <= y0 {
    return ()
  }
  let ly = if y0 < 0 { 0 } else { y0 }
  let hy = if y1 > self.height { self.height } else { y1 }
  let lx = if x0 < 0 { 0 } else { x0 }
  let hx = if x1 > self.width { self.width } else { x1 }
  for y = ly; y < hy; y = y + 1 {
    for x = lx; x < hx; x = x + 1 {
      self.paint(x, y, c)
    }
  }
}
