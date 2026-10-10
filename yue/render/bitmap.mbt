// RGBA8888 位图：本栈唯一拥有的像素缓冲。
// 布局顺序为逐行、每像素 4 字节（stride = width * 4，无行末填充），
// 与窗口上屏（XPutImage / Cairo ARGB32）之间的字节序换算在 G2/G3 的
// win 层处理，这里只保证「缓冲归 MoonBit、逐像素口径单一」。

///|
pub struct Bitmap {
  width : Int
  height : Int
  data : FixedArray[Byte]
}

///|
/// 建新位图并清成全透明；尺寸非正时得到空位图（任何写入被丢弃）。
pub fn Bitmap::new(width : Int, height : Int) -> Bitmap {
  let w = if width < 0 { 0 } else { width }
  let h = if height < 0 { 0 } else { height }
  { width: w, height: h, data: FixedArray::make(w * h * 4, b'\x00'), }
}

///|
pub fn Bitmap::inside(self : Bitmap, x : Int, y : Int) -> Bool {
  x >= 0 && y >= 0 && x < self.width && y < self.height
}

///|
/// 取像素；越界返回全透明。
pub fn Bitmap::pixel(self : Bitmap, x : Int, y : Int) -> Color {
  if !self.inside(x, y) {
    color_transparent
  } else {
    let i = (y * self.width + x) * 4
    let bs = self.data
    {
      r: bs[i].to_int(),
      g: bs[i + 1].to_int(),
      b: bs[i + 2].to_int(),
      a: bs[i + 3].to_int(),
    }
  }
}

///|
/// source-over 覆盖一个像素（整数定点混合，a=255 时即直接替换）。
pub fn Bitmap::paint(self : Bitmap, x : Int, y : Int, c : Color) -> Unit {
  if !self.inside(x, y) {
    return ()
  }
  let i = (y * self.width + x) * 4
  let sa = c.a
  // 像素缓冲用 FixedArray[Byte]：本工具链的 Bytes 只读（无 op_set），
  // 而 FixedArray 就地写入不需要 mut 绑定，调用点因此不必写 `mut`。
  let d = self.data
  if sa == 255 {
    d[i] = c.r.to_byte()
    d[i + 1] = c.g.to_byte()
    d[i + 2] = c.b.to_byte()
    d[i + 3] = b'\xff'
  } else if sa == 0 {
    ()
  } else {
    let dr = d[i].to_int()
    let dg = d[i + 1].to_int()
    let db = d[i + 2].to_int()
    let da = d[i + 3].to_int()
    let mix = fn(sc : Int, dc : Int) -> Int {
      (sc * sa + dc * (255 - sa) + 127) / 255
    }
    d[i] = mix(c.r, dr).to_byte()
    d[i + 1] = mix(c.g, dg).to_byte()
    d[i + 2] = mix(c.b, db).to_byte()
    d[i + 3] = (sa + (da * (255 - sa) + 127) / 255).to_byte()
  }
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
