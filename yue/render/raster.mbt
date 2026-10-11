// 纯 MoonBit 光栅器会话：与 `Cairo` 会话同形（方法名、参数、语义逐条对齐
// cairo_stub.c），Painter 门面按运行时探针在两条后端里选（Windows/mac 落这里，
// Linux 落 cairo；探针形态 = Cairo::over 建不出会话即纯路径）。
//
// 状态口径与 cairo 一致：矩阵/算子/线宽/源/裁剪都是图形状态，save/restore
// 一并快照；矩形类绘制在**设备空间**取整后精确填充（无 AA，cr_snap 同规则
// +0.5 后 floor），矩阵含斜切/旋转时退化为路径 AA 绘制；渐变源在设源瞬间的
// 用户空间定义（cairo pattern 语义），采样经捕获的逆矩阵。

///|
/// 光栅会话快照（save/restore 用）。
pub(all) struct RasterState {
  m_a : Double
  m_b : Double
  m_c : Double
  m_d : Double
  m_e : Double
  m_f : Double
  op : BlendMode
  line_width : Double
  source : RSource
  clip_x0 : Int
  clip_y0 : Int
  clip_x1 : Int
  clip_y1 : Int
}

///|
pub struct Raster {
  bitmap : Bitmap
  path : Path
  m : Mat2x3
  mut op : BlendMode
  mut line_width : Double
  mut source : RSource
  mut clip_x0 : Int
  mut clip_y0 : Int
  mut clip_x1 : Int
  mut clip_y1 : Int
  stack : Array[RasterState]
}

///|
/// 在位图上开光栅会话；空位图返回 None（与 Cairo::over 同形）。
pub fn Raster::over(bitmap : Bitmap) -> Raster? {
  if bitmap.width < 1 || bitmap.height < 1 {
    None
  } else {
    Some({
      bitmap,
      path: Path::new(),
      m: Mat2x3::identity(),
      op: Normal,
      line_width: 1.0,
      source: SrcSolid(color_black),
      clip_x0: 0,
      clip_y0: 0,
      clip_x1: bitmap.width,
      clip_y1: bitmap.height,
      stack: [],
    })
  }
}

///|
/// 无会话槽、无 C 资源：释放是空操作（Painter::end 对两后端同形调用）。
pub fn Raster::end(self : Raster) -> Unit {
  let _ = self
}

///|
pub fn Raster::flush(self : Raster) -> Unit {
  let _ = self
}

///|
fn raster_snap(v : Double) -> Int {
  (v + 0.5).floor().to_int()
}

///|
pub fn Raster::save(self : Raster) -> Unit {
  self.stack.push({
    m_a: self.m.a,
    m_b: self.m.b,
    m_c: self.m.c,
    m_d: self.m.d,
    m_e: self.m.e,
    m_f: self.m.f,
    op: self.op,
    line_width: self.line_width,
    source: self.source,
    clip_x0: self.clip_x0,
    clip_y0: self.clip_y0,
    clip_x1: self.clip_x1,
    clip_y1: self.clip_y1,
  })
}

///|
/// 无保存状态时不做任何事（与 Cairo 的 warn-restore 一致）。
pub fn Raster::restore(self : Raster) -> Unit {
  match self.stack.pop() {
    Some(s) => {
      self.m.a = s.m_a
      self.m.b = s.m_b
      self.m.c = s.m_c
      self.m.d = s.m_d
      self.m.e = s.m_e
      self.m.f = s.m_f
      self.op = s.op
      self.line_width = s.line_width
      self.source = s.source
      self.clip_x0 = s.clip_x0
      self.clip_y0 = s.clip_y0
      self.clip_x1 = s.clip_x1
      self.clip_y1 = s.clip_y1
    }
    None => ()
  }
}

///|
pub fn Raster::begin_path(self : Raster) -> Unit {
  self.path.clear()
}

///|
pub fn Raster::close_path(self : Raster) -> Unit {
  self.path.close()
}

///|
pub fn Raster::move_to(self : Raster, x : Double, y : Double) -> Unit {
  self.path.move_to(x, y)
}

///|
pub fn Raster::line_to(self : Raster, x : Double, y : Double) -> Unit {
  self.path.line_to(x, y)
}

///|
pub fn Raster::bezier_curve_to(
  self : Raster,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  self.path.bezier_curve_to(x1, y1, x2, y2, x3, y3)
}

///|
/// 画布语义：0 指向右，正值向下即顺时针；ea < sa 规范化为顺时针长弧
/// （与 cairo_arc / Painter 契约同口径）。
pub fn Raster::arc(
  self : Raster,
  cx : Double,
  cy : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
) -> Unit {
  self.path.add_arc(cx, cy, r, a0, a1)
}

///|
pub fn Raster::fill(self : Raster) -> Unit {
  let polys = self.path.flatten(self.m)
  fill_polys(self.bitmap, polys, (self.clip_x0, self.clip_y0, self.clip_x1, self.clip_y1), self.op, self.source)
}

///|
/// 设备线宽 = 用户线宽 × sqrt(|det|)（非均匀缩放近似，记档）。
pub fn Raster::stroke(self : Raster) -> Unit {
  let det = self.m.det().abs().sqrt()
  let lw = self.line_width * det
  if lw <= 0.0 {
    return
  }
  let polys = stroke_polys(self.path.flatten(self.m), lw)
  fill_polys(self.bitmap, polys, (self.clip_x0, self.clip_y0, self.clip_x1, self.clip_y1), self.op, self.source)
}

///|
/// 设备空间的整数矩形填充（无 AA；cr_fill_device 同语义：算子与源沿用当前
/// 状态，裁剪区相交）。空矩形不画。
fn Raster::fill_device_rect(
  self : Raster,
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
) -> Unit {
  let rx0 = raster_max_i(x0, self.clip_x0)
  let ry0 = raster_max_i(y0, self.clip_y0)
  let rx1 = raster_min_i(x1, self.clip_x1)
  let ry1 = raster_min_i(y1, self.clip_y1)
  if rx1 <= rx0 || ry1 <= ry0 {
    return
  }
  if rx0 < 0 || ry0 < 0 || rx1 > self.bitmap.width || ry1 > self.bitmap.height {
    return
  }
  let cov : FixedArray[Int] = FixedArray::make(self.bitmap.width, 0)
  for y = ry0; y < ry1; y = y + 1 {
    for i = rx0; i < rx1; i = i + 1 {
      cov[i] = 256
    }
    composite_span(self.bitmap.data, self.bitmap.width, y, rx0, rx1, cov, self.op, self.source)
  }
}

///|
/// 用户矩形 → 设备空间取整矩形（轴对齐才成立，斜切/旋转返回 false——
/// cr_rect_device 同口径：取整语义对斜矩形无意义，交给抗锯齿）。
fn Raster::rect_device(
  self : Raster,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Int, Int, Int, Int)? {
  if !self.m.axis_aligned() {
    return None
  }
  let (dx0, dy0) = self.m.apply(x, y)
  let (dx1, dy1) = self.m.apply(x + w, y + h)
  Some((raster_snap(dx0), raster_snap(dy0), raster_snap(dx1), raster_snap(dy1)))
}

///|
pub fn Raster::fill_rect(
  self : Raster,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  match self.rect_device(x, y, w, h) {
    Some((x0, y0, x1, y1)) => {
      if x1 > x0 && y1 > y0 {
        self.fill_device_rect(x0, y0, x1, y1)
      }
    }
    None => {
      // 斜矩形：路径 AA 填充（cairo_rectangle + fill 同语义）
      self.path.move_to(x, y)
      self.path.line_to(x + w, y)
      self.path.line_to(x + w, y + h)
      self.path.line_to(x, y + h)
      self.path.close()
      self.fill()
    }
  }
}

///|
/// 内侧描边（cr_stroke_rect 同口径）：四条 `line_width` 宽的边带；任一边长
/// 不足两倍线宽时整块填满；斜矩阵下退化为矩形路径填充（居中语义失去线宽，
/// 与 cairo 桩一致——它同样只 cairo_rectangle+fill）。
pub fn Raster::stroke_rect(
  self : Raster,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let lw = self.line_width
  if lw <= 0.0 {
    return
  }
  match self.rect_device(x, y, w, h) {
    None => {
      self.path.move_to(x, y)
      self.path.line_to(x + w, y)
      self.path.line_to(x + w, y + h)
      self.path.line_to(x, y + h)
      self.path.close()
      self.fill()
    }
    Some((ox0, oy0, ox1, oy1)) => {
      if ox1 <= ox0 || oy1 <= oy0 {
        return
      }
      if w <= 2.0 * lw || h <= 2.0 * lw {
        self.fill_device_rect(ox0, oy0, ox1, oy1)
        return
      }
      let ix0 = raster_snap(self.m.apply(x + lw, y).0)
      let ix1 = raster_snap(self.m.apply(x + w - lw, y).0)
      let iy0 = raster_snap(self.m.apply(x, y + lw).1)
      let iy1 = raster_snap(self.m.apply(x, y + h - lw).1)
      self.fill_device_rect(ox0, oy0, ox1, iy0)
      self.fill_device_rect(ox0, iy1, ox1, oy1)
      if ix0 > ox0 {
        self.fill_device_rect(ox0, iy0, ix0, iy1)
      }
      if ix1 < ox1 {
        self.fill_device_rect(ix1, iy0, ox1, iy1)
      }
    }
  }
}

///|
pub fn Raster::translate(self : Raster, dx : Double, dy : Double) -> Unit {
  self.m.mul(1.0, 0.0, 0.0, 1.0, dx, dy)
}

///|
pub fn Raster::scale(self : Raster, sx : Double, sy : Double) -> Unit {
  self.m.mul(sx, 0.0, 0.0, sy, 0.0, 0.0)
}

///|
pub fn Raster::rotate(self : Raster, rad : Double) -> Unit {
  let s = @math.sin(rad)
  let c = @math.cos(rad)
  self.m.mul(c, s, -s, c, 0.0, 0.0)
}

///|
/// 与当前裁剪区求交（只能收紧）。轴对齐时设备取整精确；斜矩阵退化为
/// 变换后包围盒（cairo 是精确路径裁剪，容差带内记档）。空矩形不比
/// 「已无裁剪」更紧（cr_clip_rect 同口径，防止把整窗裁光）。
pub fn Raster::clip_rect(
  self : Raster,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  match self.rect_device(x, y, w, h) {
    None => {
      // 包围盒
      let (ax0, ay0) = self.m.apply(x, y)
      let (bx0, by0) = self.m.apply(x + w, y)
      let (cx0, cy0) = self.m.apply(x, y + h)
      let (dx0, dy0) = self.m.apply(x + w, y + h)
      let lx = raster_min_i(raster_min_i(ax0.floor().to_int(), bx0.floor().to_int()), raster_min_i(cx0.floor().to_int(), dx0.floor().to_int()))
      let ly = raster_min_i(raster_min_i(ay0.floor().to_int(), by0.floor().to_int()), raster_min_i(cy0.floor().to_int(), dy0.floor().to_int()))
      let hx = raster_max_i(raster_max_i(ax0.ceil().to_int(), bx0.ceil().to_int()), raster_max_i(cx0.ceil().to_int(), dx0.ceil().to_int()))
      let hy = raster_max_i(raster_max_i(ay0.ceil().to_int(), by0.ceil().to_int()), raster_max_i(cy0.ceil().to_int(), dy0.ceil().to_int()))
      if hx > lx && hy > ly {
        if lx > self.clip_x0 {
          self.clip_x0 = lx
        }
        if ly > self.clip_y0 {
          self.clip_y0 = ly
        }
        if hx < self.clip_x1 {
          self.clip_x1 = hx
        }
        if hy < self.clip_y1 {
          self.clip_y1 = hy
        }
      }
    }
    Some((x0, y0, x1, y1)) => {
      if x1 > x0 && y1 > y0 {
        if x0 > self.clip_x0 {
          self.clip_x0 = x0
        }
        if y0 > self.clip_y0 {
          self.clip_y0 = y0
        }
        if x1 < self.clip_x1 {
          self.clip_x1 = x1
        }
        if y1 < self.clip_y1 {
          self.clip_y1 = y1
        }
      }
    }
  }
}

///|
/// 设源为纯色（fill 与 stroke 共用：cairo 只有单一 source，门面按绘制时机切）。
pub fn Raster::source_rgba(self : Raster, c : Color) -> Unit {
  self.source = SrcSolid(c)
}

///|
/// hex 直设（与 Cairo::set_fill_color 同形，非法输入保持原色）。
pub fn Raster::set_fill_color(self : Raster, hex : String) -> Unit {
  match Color::parse(hex) {
    Some(c) => self.source = SrcSolid(c)
    None => ()
  }
}

///|
pub fn Raster::set_stroke_color(self : Raster, hex : String) -> Unit {
  self.set_fill_color(hex)
}

///|
/// 渐变设为当前源：坐标捕获为**当前用户空间**（cairo pattern 语义），采样时
/// 经捕获的逆矩阵。
pub fn Raster::set_gradient(self : Raster, g : Gradient) -> Unit {
  self.source = SrcGrad(g, self.m.inverse())
}

///|
/// 线宽为负按 0 处理（门面已钳，这里兜底）。
pub fn Raster::set_line_width(self : Raster, width : Double) -> Unit {
  self.line_width = if width < 0.0 { 0.0 } else { width }
}

///|
/// 混合模式（对后续绘制生效，含矩形与 blit——cr 系路径同口径）。
pub fn Raster::set_blend_mode(self : Raster, mode : BlendMode) -> Unit {
  self.op = mode
}

///|
/// 源位图子矩形 → 目标矩形（最近邻采样；cr_blit 的采样域收口同语义：
/// 采样恒落在源子矩形内，精灵图/子表面不串色）。目标矩形设备空间取整，
/// 算子与裁剪沿用当前状态；不要把某位图画到它自己。采样映射经
/// 「CTM ∘ 平移缩放」的逆矩阵（斜矩阵下与 cairo 同为广义映射）。
pub fn Raster::blit(
  self : Raster,
  src : Bitmap,
  sx : Double,
  sy : Double,
  ssw : Double,
  ssh : Double,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
) -> Unit {
  if src.width < 1 || src.height < 1 || ssw <= 0.0 || ssh <= 0.0 || dw <= 0.0 || dh <= 0.0 {
    return
  }
  let (tx, ty, tw, th) = match self.rect_device(dx, dy, dw, dh) {
    Some((x0, y0, x1, y1)) => {
      if x1 <= x0 || y1 <= y0 {
        return
      }
      (x0.to_double(), y0.to_double(), (x1 - x0).to_double(), (y1 - y0).to_double())
    }
    None => (dx, dy, dw, dh)
  }
  // 采样域钳制边界（源子矩形的整数像素界）
  let lox = sx.floor().to_int()
  let loy = sy.floor().to_int()
  let hix = (sx + ssw).ceil().to_int() - 1
  let hiy = (sy + ssh).ceil().to_int() - 1
  // 设备 → 源位图坐标：total = CTM ∘ [缩放+平移]，采样用其逆
  let mt = Mat2x3::identity()
  mt.a = tw / ssw
  mt.d = th / ssh
  mt.e = tx
  mt.f = ty
  let total = { a: self.m.a, b: self.m.b, c: self.m.c, d: self.m.d, e: self.m.e, f: self.m.f }
  total.mul(mt.a, mt.b, mt.c, mt.d, mt.e, mt.f)
  let bsrc = SrcPixels(src, total.inverse(), lox, loy, hix, hiy)
  let rx0 = raster_max_i(tx.to_int(), self.clip_x0)
  let rx1 = raster_min_i((tx + tw).to_int(), self.clip_x1)
  let ry0 = raster_max_i(ty.to_int(), self.clip_y0)
  let ry1 = raster_min_i((ty + th).to_int(), self.clip_y1)
  if rx1 <= rx0 || ry1 <= ry0 {
    return
  }
  let cov : FixedArray[Int] = FixedArray::make(self.bitmap.width, 0)
  for y = ry0; y < ry1; y = y + 1 {
    for x = rx0; x < rx1; x = x + 1 {
      cov[x] = 256
    }
    composite_span(self.bitmap.data, self.bitmap.width, y, rx0, rx1, cov, self.op, bsrc)
  }
}
