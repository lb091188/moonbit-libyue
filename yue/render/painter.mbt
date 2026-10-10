// 绘制契约：方法名与参数形态照旧 `yue/painter.mbt`，实现 = Cairo 光栅器
// （Linux 侧，`scripts/prebuild.py` 编入）；Cairo 不可用时退回纯矩形的降级
// 实现（其余平台后端落地前），两条路径的矩形口径逐像素一致。
//
// 四条口径先在这里定死：
// - 矩形类绘制（`fill_rect`/`stroke_rect`/`clip_rect`）在取整后的整数像素上
//   完成（+0.5 后向下取整），共用边不留缝、无抗锯齿灰边；路径绘制走抗锯齿；
// - `stroke_rect` 描边落在矩形**内侧**，与布局层「宽高 = border-box」同源；
// - 填充/描边的颜色与渐变是两份独立状态，绘制时才落到 source
//   （`set_stroke_color` 不会踩掉填充色，与旧 Painter 语义一致）；
// - 会话制：`Painter::new` 占一个 Cairo 会话槽（共 16 个），**用完必须
//   `end()`**（每帧一个会话的用法），槽位耗尽会静默退回降级实现；
//   可变状态放在 `PainterState` 的内层 mut 字段上，外层 `Painter` 只对
//   `session` 重绑，调用点无需 `mut p`。

///|
pub(all) struct PainterState {
  mut tx : Double
  mut ty : Double
  mut clip_x0 : Int
  mut clip_y0 : Int
  mut clip_x1 : Int
  mut clip_y1 : Int
  mut fill : Color
  mut stroke : Color
  mut fill_grad : Gradient?
  mut stroke_grad : Gradient?
  mut line_width : Double
}

///|
pub(all) struct Painter {
  bitmap : Bitmap
  mut session : Cairo?
  state : PainterState
  stack : Array[PainterState]
}

///|
/// 取整：+0.5 后向下取整（0.5 与 -0.5 分别进/退到 1 与 -1）。
fn snap(v : Double) -> Int {
  (v + 0.5).floor().to_int()
}

// 结构体是引用语义，入栈必须拷贝一份快照，否则 restore 拿回的是同一个对象。

///|
fn snapshot(s : PainterState) -> PainterState {
  {
    tx: s.tx,
    ty: s.ty,
    clip_x0: s.clip_x0,
    clip_y0: s.clip_y0,
    clip_x1: s.clip_x1,
    clip_y1: s.clip_y1,
    fill: s.fill,
    stroke: s.stroke,
    fill_grad: s.fill_grad,
    stroke_grad: s.stroke_grad,
    line_width: s.line_width,
  }
}

///|
fn load_state(target : PainterState, from : PainterState) -> Unit {
  target.tx = from.tx
  target.ty = from.ty
  target.clip_x0 = from.clip_x0
  target.clip_y0 = from.clip_y0
  target.clip_x1 = from.clip_x1
  target.clip_y1 = from.clip_y1
  target.fill = from.fill
  target.stroke = from.stroke
  target.fill_grad = from.fill_grad
  target.stroke_grad = from.stroke_grad
  target.line_width = from.line_width
}

///|
/// 以整块位图为初始裁剪区、黑色为初始前景色建绘制器。
pub fn Painter::new(bitmap : Bitmap) -> Painter {
  let black = color_black
  let p = {
    bitmap,
    session: Cairo::over(bitmap),
    state: {
      tx: 0.0,
      ty: 0.0,
      clip_x0: 0,
      clip_y0: 0,
      clip_x1: bitmap.width,
      clip_y1: bitmap.height,
      fill: black,
      stroke: black,
      fill_grad: None,
      stroke_grad: None,
      line_width: 1.0,
    },
    stack: [],
  }
  // 会话初始线宽同步（Cairo 默认 2.0，与契约默认 1.0 不同源）
  p.set_line_width(1.0)
  p
}

///|
/// 释放 Cairo 会话；降级实现无会话，可安全重复调用。
pub fn Painter::end(self : Painter) -> Unit {
  match self.session {
    Some(c) => {
      c.end()
      self.session = None
    }
    None => ()
  }
}

///|
/// 把会话数据刷回缓冲；与其它会话交替绘制同一块位图前调用
/// （如直接对位图调 `yue/text` 的绘制入口）。
pub fn Painter::flush(self : Painter) -> Unit {
  match self.session {
    Some(c) => c.flush()
    None => ()
  }
}

///|
/// 把当前填充状态（颜色或渐变）落到会话 source 上。
fn Painter::apply_fill(self : Painter) -> Unit {
  match self.session {
    None => ()
    Some(c) =>
      match self.state.fill_grad {
        Some(g) => c.set_fill_gradient(g)
        None => c.source_rgba(self.state.fill)
      }
  }
}

///|
fn Painter::apply_stroke(self : Painter) -> Unit {
  match self.session {
    None => ()
    Some(c) =>
      match self.state.stroke_grad {
        Some(g) => c.set_stroke_gradient(g)
        None => c.source_rgba(self.state.stroke)
      }
  }
}

///|
pub fn Painter::save(self : Painter) -> Unit {
  self.stack.push(snapshot(self.state))
  match self.session {
    Some(c) => c.save()
    None => ()
  }
}

///|
/// 无保存状态时不做任何事（与 Cairo 的 warn-restore 一致，不报错）。
pub fn Painter::restore(self : Painter) -> Unit {
  match self.stack.pop() {
    Some(s) => {
      load_state(self.state, s)
      match self.session {
        Some(c) => c.restore()
        None => ()
      }
    }
    None => ()
  }
}

///|
pub fn Painter::translate(self : Painter, dx : Double, dy : Double) -> Unit {
  let s = self.state
  s.tx = s.tx + dx
  s.ty = s.ty + dy
  match self.session {
    Some(c) => c.translate(dx, dy)
    None => ()
  }
}

///|
/// 降级实现（无 Cairo）不支持缩放，忽略。
pub fn Painter::scale(self : Painter, sx : Double, sy : Double) -> Unit {
  match self.session {
    Some(c) => c.scale(sx, sy)
    None => ()
  }
}

///|
/// 降级实现（无 Cairo）不支持旋转，忽略。
pub fn Painter::rotate(self : Painter, angle : Double) -> Unit {
  match self.session {
    Some(c) => c.rotate(angle)
    None => ()
  }
}

///|
/// 与当前裁剪区求交（裁剪只能收紧，`restore` 才回退）。
pub fn Painter::clip_rect(
  self : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let s = self.state
  let x0 = snap(x + s.tx)
  let y0 = snap(y + s.ty)
  let x1 = snap(x + w + s.tx)
  let y1 = snap(y + h + s.ty)
  if x1 > x0 && y1 > y0 {
    if x0 > s.clip_x0 {
      s.clip_x0 = x0
    }
    if y0 > s.clip_y0 {
      s.clip_y0 = y0
    }
    if x1 < s.clip_x1 {
      s.clip_x1 = x1
    }
    if y1 < s.clip_y1 {
      s.clip_y1 = y1
    }
    match self.session {
      Some(c) => c.clip_rect(x, y, w, h)
      None => ()
    }
  }
}

///|
/// hex 非法时保持原色。
pub fn Painter::set_fill_color(self : Painter, hex : String) -> Unit {
  match Color::parse(hex) {
    Some(c) => {
      self.state.fill = c
      self.state.fill_grad = None
    }
    None => ()
  }
}

///|
pub fn Painter::set_stroke_color(self : Painter, hex : String) -> Unit {
  match Color::parse(hex) {
    Some(c) => {
      self.state.stroke = c
      self.state.stroke_grad = None
    }
    None => ()
  }
}

///|
/// 渐变填充；无 stop 的渐变忽略（保持原状态）。
pub fn Painter::set_fill_gradient(self : Painter, g : Gradient) -> Unit {
  if g.stops.length() > 0 {
    self.state.fill_grad = Some(gradient_snapshot(g))
  }
}

///|
pub fn Painter::set_stroke_gradient(self : Painter, g : Gradient) -> Unit {
  if g.stops.length() > 0 {
    self.state.stroke_grad = Some(gradient_snapshot(g))
  }
}

///|
/// 线宽为负按 0 处理。
pub fn Painter::set_line_width(self : Painter, width : Double) -> Unit {
  let lw = if width < 0.0 { 0.0 } else { width }
  self.state.line_width = lw
  match self.session {
    Some(c) => c.set_line_width(lw)
    None => ()
  }
}

///|
/// 混合模式（对后续绘制生效）；降级实现忽略。
pub fn Painter::set_blend_mode(self : Painter, mode : BlendMode) -> Unit {
  match self.session {
    Some(c) => c.set_blend_mode(mode)
    None => ()
  }
}

///|
/// 把「平移后的用户矩形」换算成裁剪区内的整数覆盖区；空覆盖返回 None。
fn device_area(
  s : PainterState,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Int, Int, Int, Int)? {
  let x0 = snap(x + s.tx)
  let y0 = snap(y + s.ty)
  let x1 = snap(x + w + s.tx)
  let y1 = snap(y + h + s.ty)
  if x1 <= x0 || y1 <= y0 {
    None
  } else {
    let cx0 = if x0 < s.clip_x0 { s.clip_x0 } else { x0 }
    let cy0 = if y0 < s.clip_y0 { s.clip_y0 } else { y0 }
    let cx1 = if x1 > s.clip_x1 { s.clip_x1 } else { x1 }
    let cy1 = if y1 > s.clip_y1 { s.clip_y1 } else { y1 }
    if cx1 <= cx0 || cy1 <= cy0 {
      None
    } else {
      Some((cx0, cy0, cx1, cy1))
    }
  }
}

///|
pub fn Painter::fill_rect(
  self : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  match self.session {
    Some(c) => {
      self.apply_fill()
      c.fill_rect(x, y, w, h)
    }
    None => {
      let s = self.state
      match device_area(s, x, y, w, h) {
        None => ()
        Some((x0, y0, x1, y1)) => self.bitmap.fill_area(x0, y0, x1, y1, s.fill)
      }
    }
  }
}

///|
/// 内侧描边：四条约 `line_width` 宽的带；矩形任一边长不足两倍线宽时整块填满。
/// 上下横带占满整宽、左右竖带只占中间段，四角因此不重复混合。
pub fn Painter::stroke_rect(
  self : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  match self.session {
    Some(c) => {
      self.apply_stroke()
      c.stroke_rect(x, y, w, h)
    }
    None => {
      let s = self.state
      match device_area(s, x, y, w, h) {
        None => ()
        Some((ox0, oy0, ox1, oy1)) =>
          if w <= s.line_width * 2.0 || h <= s.line_width * 2.0 {
            self.bitmap.fill_area(ox0, oy0, ox1, oy1, s.stroke)
          } else {
            let ix0 = snap(x + s.line_width + s.tx)
            let ix1 = snap(x + w - s.line_width + s.tx)
            let iy0 = snap(y + s.line_width + s.ty)
            let iy1 = snap(y + h - s.line_width + s.ty)
            self.bitmap.fill_area(ox0, oy0, ox1, iy0, s.stroke)
            self.bitmap.fill_area(ox0, iy1, ox1, oy1, s.stroke)
            if ix0 > ox0 {
              self.bitmap.fill_area(ox0, iy0, ix0, iy1, s.stroke)
            }
            if ix1 < ox1 {
              self.bitmap.fill_area(ix1, iy0, ox1, iy1, s.stroke)
            }
          }
      }
    }
  }
}

///|
/// 当前裁剪区（调试与快照定位用；`scale`/`rotate` 后为近似值）。
pub fn Painter::clip_bounds(self : Painter) -> (Int, Int, Int, Int) {
  let s = self.state
  (s.clip_x0, s.clip_y0, s.clip_x1, s.clip_y1)
}

///|
pub fn Painter::begin_path(self : Painter) -> Unit {
  match self.session {
    Some(c) => c.begin_path()
    None => ()
  }
}

///|
pub fn Painter::close_path(self : Painter) -> Unit {
  match self.session {
    Some(c) => c.close_path()
    None => ()
  }
}

///|
pub fn Painter::move_to(self : Painter, x : Double, y : Double) -> Unit {
  match self.session {
    Some(c) => c.move_to(x, y)
    None => ()
  }
}

///|
pub fn Painter::line_to(self : Painter, x : Double, y : Double) -> Unit {
  match self.session {
    Some(c) => c.line_to(x, y)
    None => ()
  }
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
  match self.session {
    Some(c) => c.bezier_curve_to(cp1x, cp1y, cp2x, cp2y, x, y)
    None => ()
  }
}

///|
/// 圆弧（画布语义：0 指向右，正值向下即顺时针）。`ccw` 参数照旧契约保留但
/// 两层后端都不可用（cairo_arc 对 ea < sa 会规范化成顺时针长弧）：逆时针需求
/// 用折线近似或交换起止角（仅描边时）表达，见图表圆环与图标弧。
pub fn Painter::arc(
  self : Painter,
  x : Double,
  y : Double,
  radius : Double,
  start_angle : Double,
  end_angle : Double,
  ccw? : Bool = false,
) -> Unit {
  let _ = ccw
  match self.session {
    Some(c) => c.arc(x, y, radius, start_angle, end_angle)
    None => ()
  }
}

///|
/// 绘制离屏画布（拉伸到目标矩形）；降级实现无此能力。
pub fn Painter::draw_canvas(
  self : Painter,
  canvas : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let bm = canvas.bitmap
  match self.session {
    Some(c) =>
      c.blit(
        bm,
        0.0,
        0.0,
        bm.width.to_double(),
        bm.height.to_double(),
        x,
        y,
        w,
        h,
      )
    None => ()
  }
}

///|
/// 画布源矩形 → 目标矩形。
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
  match self.session {
    Some(c) => c.blit(canvas.bitmap, sx, sy, sw, sh, dx, dy, dw, dh)
    None => ()
  }
}

///|
/// 绘制图片（拉伸到目标矩形）；空图忽略。
pub fn Painter::draw_image(
  self : Painter,
  image : Image,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  if image.is_empty() {
    return ()
  }
  self.draw_canvas(
    { bitmap: image.pixels },
    x,
    y,
    w,
    h,
  )
}

///|
/// 图片源矩形 → 目标矩形；空图忽略。
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
  if image.is_empty() {
    return ()
  }
  self.draw_canvas_from_rect(
    { bitmap: image.pixels },
    sx,
    sy,
    sw,
    sh,
    dx,
    dy,
    dw,
    dh,
  )
}

///|
pub fn Painter::fill(self : Painter) -> Unit {
  match self.session {
    Some(c) => {
      self.apply_fill()
      c.fill()
    }
    None => ()
  }
}

///|
pub fn Painter::stroke(self : Painter) -> Unit {
  match self.session {
    Some(c) => {
      self.apply_stroke()
      c.stroke()
    }
    None => ()
  }
}
