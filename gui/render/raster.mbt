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
/// 当前裁剪框（设备空间；右/下为开区间）——控件绘制遍历做视口剔除时用来判交。
pub fn Raster::clip_bounds(self : Raster) -> (Int, Int, Int, Int) {
  (self.clip_x0, self.clip_y0, self.clip_x1, self.clip_y1)
}

///|
/// 内容坐标 → 设备坐标（当前 CTM）。
pub fn Raster::map_point(self : Raster, x : Double, y : Double) -> (Double, Double) {
  self.m.apply(x, y)
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
/// 填充后清空路径（`cairo_fill` 同口径，见 `Painter` 头注释「两后端方法面逐条
/// 同形」）：不清则上一笔的子路径会跟着下一笔一起落盘，而每只控件的绘制都在
/// **自己的平移系**里——漏过来的旧路径被按当前原点重画，画面上就是控件上多出
/// 一块与它无关的色块。
pub fn Raster::fill(self : Raster) -> Unit {
  let polys = self.path.flatten(self.m)
  fill_polys(self.bitmap, polys, (self.clip_x0, self.clip_y0, self.clip_x1, self.clip_y1), self.op, self.source)
  self.path.clear()
}

///|
/// 设备线宽 = 用户线宽 × sqrt(|det|)（非均匀缩放近似，记档）。
/// 用完清空路径，口径同 `Raster::fill`（零线宽不落像素但同样清）。
pub fn Raster::stroke(self : Raster) -> Unit {
  let det = self.m.det().abs().sqrt()
  let lw = self.line_width * det
  if lw <= 0.0 {
    self.path.clear()
    return
  }
  let polys = stroke_polys(self.path.flatten(self.m), lw)
  fill_polys(self.bitmap, polys, (self.clip_x0, self.clip_y0, self.clip_x1, self.clip_y1), self.op, self.source)
  self.path.clear()
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
  // 纯色不透明源整段直写（背景填充最大宗；实测比逐像素 blend 快 ~10 倍）
  let fast = match (blend_mode_id(self.op) == 0, self.source) {
    (true, SrcSolid(c)) => c.a >= 255
    _ => false
  }
  if fast {
    for y = ry0; y < ry1; y = y + 1 {
      let _ = composite_solid_span(
        self.bitmap.data,
        self.bitmap.width,
        y,
        rx0,
        rx1,
        self.op,
        self.source,
      )
    }
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
/// 圆角矩形解析填充：不走通用路径扫描（路径化 + 多边形 AA 实测单张 400×120
/// 要 20ms，是全帧 paint 的最大单项）。按行求墨迹：中段整行（纯色不透明源走
/// 直写快路径），角部条带像素按圆方程求覆盖（边界 AA）。轴对齐且 x/y 等比
/// （角仍是圆）才适用，返回 false 时调用方退通用路径。
pub fn Raster::fill_round_rect(
  self : Raster,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
) -> Bool {
  if !self.m.axis_aligned() {
    return false
  }
  let ax = self.m.a.abs()
  let ay = self.m.d.abs()
  if ax < 0.000000001 || ay < 0.000000001 {
    return false
  }
  if (ax - ay).abs() / (ax + ay) > 0.001 {
    return false
  }
  match self.rect_device(x, y, w, h) {
    None => return false
    Some((ix0, iy0, ix1, iy1)) => {
      let rx0 = raster_max_i(ix0, self.clip_x0)
      let ry0 = raster_max_i(iy0, self.clip_y0)
      let rx1 = raster_min_i(ix1, self.clip_x1)
      let ry1 = raster_min_i(iy1, self.clip_y1)
      if rx1 <= rx0 || ry1 <= ry0 {
        return true
      }
      if rx0 < 0 ||
        ry0 < 0 ||
        rx1 > self.bitmap.width ||
        ry1 > self.bitmap.height {
        return true
      }
      let rr_d = clamp_radius(radius, w, h) * ax
      let rr_lim = (ix1 - ix0).to_double().min((iy1 - iy0).to_double()) / 2.0
      let rr = if rr_d > rr_lim { rr_lim } else { rr_d }
      if rr <= 0.0 {
        self.fill_device_rect(ix0, iy0, ix1, iy1)
        return true
      }
      let fast = match (blend_mode_id(self.op) == 0, self.source) {
        (true, SrcSolid(c)) => c.a >= 255
        _ => false
      }
      let cov : FixedArray[Int] = FixedArray::make(self.bitmap.width, 0)
      let mid0 = raster_min_i((iy0.to_double() + rr).ceil().to_int(), ry1)
      let mid1 = raster_max_i((iy1.to_double() - rr).floor().to_int(), ry0)
      for j = ry0; j < ry1; j = j + 1 {
        let in_mid = j >= mid0 && j < mid1
        if in_mid && fast {
          let _ = composite_solid_span(
            self.bitmap.data,
            self.bitmap.width,
            j,
            rx0,
            rx1,
            self.op,
            self.source,
          )
          continue
        }
        // 覆盖数组：中段条带恒 256，两侧角部条带按「像素中心到角圆心的距离」
        // 求覆盖（圆外 0、圆边 AA、圆内 256）
        for i = rx0; i < rx1; i = i + 1 {
          cov[i] = 256
        }
        if !in_mid {
          let cy = if j.to_double() + 0.5 < iy0.to_double() + rr {
            iy0.to_double() + rr
          } else {
            iy1.to_double() - rr
          }
          let dy = (j.to_double() + 0.5) - cy
          let dy2 = dy * dy
          // 左角条带
          let ls1 = raster_min_i(rx1, (ix0.to_double() + rr).ceil().to_int())
          for i = rx0; i < ls1; i = i + 1 {
            let dx = (ix0.to_double() + rr) - (i.to_double() + 0.5)
            let dist = (dx * dx + dy2).sqrt()
            let cv = ((rr - dist) * 256.0).to_int()
            cov[i] = if cv < 0 {
              0
            } else if cv > 256 {
              256
            } else {
              cv
            }
          }
          // 右角条带
          let rs0 = raster_max_i(rx0, (ix1.to_double() - rr).floor().to_int())
          for i = rs0; i < rx1; i = i + 1 {
            let dx = (i.to_double() + 0.5) - (ix1.to_double() - rr)
            let dist = (dx * dx + dy2).sqrt()
            let cv = ((rr - dist) * 256.0).to_int()
            cov[i] = if cv < 0 {
              0
            } else if cv > 256 {
              256
            } else {
              cv
            }
          }
        }
        composite_span(
          self.bitmap.data,
          self.bitmap.width,
          j,
          rx0,
          rx1,
          cov,
          self.op,
          self.source,
        )
      }
      true
    }
  }
}

///|
/// 圆角矩形**解析描边**：环带 = 外圈圆角矩形减内圈。像素按中心唯一分区——
/// 直段（上下左右四条带）与角部象限都按「像素中心到环的距离」求覆盖，覆盖 =
/// `hw + 0.5 − 距离`（+0.5 是把像素当一格算面积重叠的修正；没有它，1px 描边
/// 压在整数边上时四条直段重叠恒为 0、整段消失），角部用「到角圆心距离」的
/// SDF 同式。边一律取**精确设备坐标**（取整只用于圈定循环范围）。线宽 ≥
/// 2×圆角时内孔自然消失、角部实心。轴对齐 + 等比 + 纯色不透明 + Normal 才
/// 适用，返回 false 时调用方退通用路径描边。
pub fn Raster::stroke_round_rect(
  self : Raster,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
) -> Bool {
  if !self.m.axis_aligned() {
    return false
  }
  let ax = self.m.a.abs()
  let ay = self.m.d.abs()
  if ax < 0.000000001 || ay < 0.000000001 {
    return false
  }
  if (ax - ay).abs() / (ax + ay) > 0.001 {
    return false
  }
  if blend_mode_id(self.op) != 0 {
    return false
  }
  let sc = match self.source {
    SrcSolid(c) => c
    _ => return false
  }
  if sc.a < 255 {
    return false
  }
  let hw = self.line_width * ax / 2.0
  if hw <= 0.0 {
    return false
  }
  let (px0, py0) = self.m.apply(x, y)
  let (px1, py1) = self.m.apply(x + w, y + h)
  let ex0 = px0.min(px1)
  let ex1 = px0.max(px1)
  let ey0 = py0.min(py1)
  let ey1 = py0.max(py1)
  if ex1 <= ex0 || ey1 <= ey0 {
    return true
  }
  let rr_d = clamp_radius(radius, w, h) * ax
  let rr_lim = (ex1 - ex0).min(ey1 - ey0) / 2.0
  let rr = if rr_d > rr_lim { rr_lim } else { rr_d }
  // 外扩 hw 的环带包围盒（环在矩形边缘内外各占一半线宽）
  let rx0 = raster_max_i((ex0 - hw).floor().to_int(), self.clip_x0)
  let ry0 = raster_max_i((ey0 - hw).floor().to_int(), self.clip_y0)
  let rx1 = raster_min_i((ex1 + hw).ceil().to_int(), self.clip_x1)
  let ry1 = raster_min_i((ey1 + hw).ceil().to_int(), self.clip_y1)
  if rx1 <= rx0 || ry1 <= ry0 {
    return true
  }
  if rx0 < 0 ||
    ry0 < 0 ||
    rx1 > self.bitmap.width ||
    ry1 > self.bitmap.height {
    return true
  }
  // 直段/角部分区界（像素中心 +0.5 与之比较）
  let mx0 = ex0 + rr
  let mx1 = ex1 - rr
  let my0 = ey0 + rr
  let my1 = ey1 - rr
  let band = fn(d : Double) -> Int {
    let v = (hw + 0.5 - d) * 256.0
    if v <= 0.0 {
      0
    } else if v >= 256.0 {
      256
    } else {
      v.to_int()
    }
  }
  let cov : FixedArray[Int] = FixedArray::make(self.bitmap.width, 0)
  for j = ry0; j < ry1; j = j + 1 {
    let ycen = j.to_double() + 0.5
    let in_mid_y = ycen >= my0 && ycen < my1
    for i = rx0; i < rx1; i = i + 1 {
      let xcen = i.to_double() + 0.5
      let in_mid_x = xcen >= mx0 && xcen < mx1
      cov[i] = if in_mid_x && in_mid_y {
        // 矩形内部：不属于环
        0
      } else if in_mid_x {
        // 上下直段
        let edge = if ycen < my0 { ey0 } else { ey1 }
        band((ycen - edge).abs())
      } else if in_mid_y {
        // 左右直段
        let edge = if xcen < mx0 { ex0 } else { ex1 }
        band((xcen - edge).abs())
      } else {
        // 角部象限：dist = 像素中心到角圆心
        let ccx = if xcen < mx0 { ex0 + rr } else { ex1 - rr }
        let ccy = if ycen < my0 { ey0 + rr } else { ey1 - rr }
        let dx = xcen - ccx
        let dy = ycen - ccy
        let dist = (dx * dx + dy * dy).sqrt()
        band((dist - rr).abs())
      }
    }
    composite_span(
      self.bitmap.data,
      self.bitmap.width,
      j,
      rx0,
      rx1,
      cov,
      self.op,
      self.source,
    )
  }
  true
}

///|
/// 用户矩形 → 设备空间取整矩形（轴对齐才成立，斜切/旋转返回 false——
/// cr_rect_device 同口径：取整语义对斜矩形无意义，交给抗锯齿）。
fn Raster::rect_device(  self : Raster,
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
///|
/// 预乘字节的「通用路径等价值」查表（256×256，首次用时建）：
/// 通用路经 `Bitmap::pixel` 解除预乘、再 `premul_bytes` 乘回，值会与存量字节
/// 差 ±1；快路径要逐位一致就得复刻这一趟，而每像素三次除法太贵——查表省掉。
let g_rtt : FixedArray[Int] = FixedArray::make(65536, 0)

///|
let g_rtt_ready : Ref[Bool] = Ref(false)

///|
fn rtt_of(p : Int, a : Int) -> Int {
  if !g_rtt_ready.val {
    g_rtt_ready.val = true
    for a2 = 0; a2 < 256; a2 = a2 + 1 {
      for p2 = 0; p2 < 256; p2 = p2 + 1 {
        let straight = if a2 == 0 { 0 } else { (p2 * 255 + a2 / 2) / a2 }
        g_rtt[p2 * 256 + a2] = (straight * a2 + 127) / 255
      }
    }
  }
  g_rtt[p * 256 + a]
}

///|
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
  // 设备 → 源位图坐标：total = CTM ∘ mt，采样用其逆。mt 必须建在**用户
  // 空间**（e/f 取用户坐标 dx/dy）——rect_device 给的 tx/ty 已是设备坐标，
  // 那份只用于扫描矩形（rx*/ry*），进了 mt 就等于把 CTM 计两次：实测带
  // translate 的会话里 blit 一个像素都落不下来（源采样落到源矩形界外）。
  let mt = Mat2x3::identity()
  mt.a = dw / ssw
  mt.d = dh / ssh
  mt.e = dx
  mt.f = dy
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
  // 快路径：纯整数平移 + 1:1 全幅拷贝 + Normal 混合——文字离屏合成走的就是
  // 这条（每帧几十段；走通用路的逐像素逆矩阵 + 解除预乘实测 5ms/次，一帧能把
  // 窗口拖卡）。门必须同时卡住「无缩放」与「源矩形就是整幅位图」，否则会拿
  // 缩放/子矩形当 1:1 拷（实测踩过：取左上象限铺 4×4 那条当场红）。
  // 两边缓冲都是预乘 BGRA，按字节直接做 Normal over 即可，与 composite_span
  // 的公式同式（cov = 256 满覆盖档）；源字节先过 rtt_of 换成通用路径的等价值。
  if blend_mode_id(self.op) == 0 && self.m.axis_aligned() &&
    self.m.a == 1.0 && self.m.d == 1.0 && self.m.b == 0.0 && self.m.c == 0.0 &&
    tx == tx.floor() && ty == ty.floor() && sx == 0.0 && sy == 0.0 &&
    dw == ssw && dh == ssh && ssw == src.width.to_double() &&
    ssh == src.height.to_double() {
    let sox = lox - tx.to_int()
    let soy = loy - ty.to_int()
    let sdata = src.data
    let ddata = self.bitmap.data
    let sw = src.width
    let dw_width = self.bitmap.width
    for y = ry0; y < ry1; y = y + 1 {
      let syy = y + soy
      if syy < loy || syy > hiy {
        continue
      }
      let srow = syy * sw * 4
      let drow = y * dw_width * 4
      for x = rx0; x < rx1; x = x + 1 {
        let sxx = x + sox
        if sxx < lox || sxx > hix {
          continue
        }
        let si = srow + sxx * 4
        let sa = sdata[si + 3].to_int()
        if sa == 0 {
          continue
        }
        let inv = 255 - sa
        let di = drow + x * 4
        ddata[di] = (
          rtt_of(sdata[si].to_int(), sa) + (ddata[di].to_int() * inv + 127) / 255
        ).to_byte()
        ddata[di + 1] = (
          rtt_of(sdata[si + 1].to_int(), sa) +
          (ddata[di + 1].to_int() * inv + 127) / 255
        ).to_byte()
        ddata[di + 2] = (
          rtt_of(sdata[si + 2].to_int(), sa) +
          (ddata[di + 2].to_int() * inv + 127) / 255
        ).to_byte()
        ddata[di + 3] = (sa + (ddata[di + 3].to_int() * inv + 127) / 255).to_byte()
      }
    }
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
