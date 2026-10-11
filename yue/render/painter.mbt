// 绘制契约：方法名与参数形态照旧 `yue/painter.mbt`，实现 = 双后端——
// Cairo 光栅器（Linux 侧，`scripts/prebuild.py` 编入）与纯 MoonBit 光栅器
// `Raster`（Windows/mac，零第三方依赖）。**运行时探针**选择：`Cairo::over`
// 建不出会话（占位桩返回 0）即落纯路径（AGENTS 规则 11：运行时探测 +
// 模式匹配，不用编译指令）；两后端的方法面逐条同形（`Raster` 镜像
// `Cairo` 会话），门面代码对二者完全对称。
//
// 四条口径先在这里定死：
// - 矩形类绘制（`fill_rect`/`stroke_rect`/`clip_rect`）在取整后的整数像素上
//   完成（+0.5 后向下取整），共用边不留缝、无抗锯齿灰边；路径绘制走抗锯齿
//   （两后端同口径，见 raster.mbt / cairo_stub.c 的镜像注释）；
// - `stroke_rect` 描边落在矩形**内侧**，与布局层「宽高 = border-box」同源；
// - 填充/描边的颜色与渐变是两份独立状态，绘制时才落到 source
//   （`set_stroke_color` 不会踩掉填充色，与旧 Painter 语义一致）；
// - 会话制：`Painter::new` 占一个后端会话（Cairo 共 16 槽，Raster 无槽限），
//   **用完必须 `end()`**（每帧一个会话的用法）；可变状态放在 `PainterState`
//   的内层 mut 字段上，外层 `Painter` 只对 `backend` 重绑，调用点无需 `mut p`。

///|
/// 渲染后端：cairo（Linux 系统库）或纯 MoonBit 光栅器（Windows/mac）。
pub(all) enum Backend {
  CairoBackend(Cairo)
  PureBackend(Raster)
}

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
  mut backend : Backend?
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
/// 以整块位图为初始裁剪区、黑色为初始前景色建绘制器。后端选择在此探针：
/// 位图非空 → 先试 Cairo 会话，建不出（占位桩/无显示栈）落纯光栅器。
pub fn Painter::new(bitmap : Bitmap) -> Painter {
  let black = color_black
  let backend : Backend? = if bitmap.width < 1 || bitmap.height < 1 {
    None
  } else {
    match Cairo::over(bitmap) {
      Some(c) => Some(CairoBackend(c))
      None =>
        match Raster::over(bitmap) {
          Some(r) => Some(PureBackend(r))
          None => None
        }
    }
  }
  let p = {
    bitmap,
    backend,
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
/// 释放后端会话；之后所有绘制静默无效（可安全重复调用）。
pub fn Painter::end(self : Painter) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => {
      c.end()
      self.backend = None
    }
    Some(PureBackend(r)) => {
      r.end()
      self.backend = None
    }
    None => ()
  }
}

///|
/// 把后端数据刷回缓冲；与其它会话交替绘制同一块位图前调用
/// （如直接对位图调 `yue/text` 的绘制入口）。
pub fn Painter::flush(self : Painter) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => c.flush()
    _ => ()
  }
}

///|
/// 把当前填充状态（颜色或渐变）落到后端 source 上。
fn Painter::apply_fill(self : Painter) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) =>
      match self.state.fill_grad {
        Some(g) => c.set_fill_gradient(g)
        None => c.source_rgba(self.state.fill)
      }
    Some(PureBackend(r)) =>
      match self.state.fill_grad {
        Some(g) => r.set_gradient(g)
        None => r.source_rgba(self.state.fill)
      }
    None => ()
  }
}

///|
fn Painter::apply_stroke(self : Painter) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) =>
      match self.state.stroke_grad {
        Some(g) => c.set_stroke_gradient(g)
        None => c.source_rgba(self.state.stroke)
      }
    Some(PureBackend(r)) =>
      match self.state.stroke_grad {
        Some(g) => r.set_gradient(g)
        None => r.source_rgba(self.state.stroke)
      }
    None => ()
  }
}

///|
pub fn Painter::save(self : Painter) -> Unit {
  self.stack.push(snapshot(self.state))
  match self.backend {
    Some(CairoBackend(c)) => c.save()
    Some(PureBackend(r)) => r.save()
    None => ()
  }
}

///|
/// 无保存状态时不做任何事（与 Cairo 的 warn-restore 一致，不报错）。
pub fn Painter::restore(self : Painter) -> Unit {
  match self.stack.pop() {
    Some(s) => {
      load_state(self.state, s)
      match self.backend {
        Some(CairoBackend(c)) => c.restore()
        Some(PureBackend(r)) => r.restore()
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
  match self.backend {
    Some(CairoBackend(c)) => c.translate(dx, dy)
    Some(PureBackend(r)) => r.translate(dx, dy)
    None => ()
  }
}

///|
pub fn Painter::scale(self : Painter, sx : Double, sy : Double) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => c.scale(sx, sy)
    Some(PureBackend(r)) => r.scale(sx, sy)
    None => ()
  }
}

///|
pub fn Painter::rotate(self : Painter, angle : Double) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => c.rotate(angle)
    Some(PureBackend(r)) => r.rotate(angle)
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
    match self.backend {
      Some(CairoBackend(c)) => c.clip_rect(x, y, w, h)
      Some(PureBackend(r)) => r.clip_rect(x, y, w, h)
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
  match self.backend {
    Some(CairoBackend(c)) => c.set_line_width(lw)
    Some(PureBackend(r)) => r.set_line_width(lw)
    None => ()
  }
}

///|
/// 混合模式（对后续绘制生效；两后端同支持）。
pub fn Painter::set_blend_mode(self : Painter, mode : BlendMode) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => c.set_blend_mode(mode)
    Some(PureBackend(r)) => r.set_blend_mode(mode)
    None => ()
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
  match self.backend {
    Some(CairoBackend(c)) => {
      self.apply_fill()
      c.fill_rect(x, y, w, h)
    }
    Some(PureBackend(r)) => {
      self.apply_fill()
      r.fill_rect(x, y, w, h)
    }
    None => ()
  }
}

///|
/// 内侧描边：四条约 `line_width` 宽的带；矩形任一边长不足两倍线宽时整块填满
/// （两后端同口径，见各自实现的镜像注释）。
pub fn Painter::stroke_rect(
  self : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => {
      self.apply_stroke()
      c.stroke_rect(x, y, w, h)
    }
    Some(PureBackend(r)) => {
      self.apply_stroke()
      r.stroke_rect(x, y, w, h)
    }
    None => ()
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
  match self.backend {
    Some(CairoBackend(c)) => c.begin_path()
    Some(PureBackend(r)) => r.begin_path()
    None => ()
  }
}

///|
pub fn Painter::close_path(self : Painter) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => c.close_path()
    Some(PureBackend(r)) => r.close_path()
    None => ()
  }
}

///|
pub fn Painter::move_to(self : Painter, x : Double, y : Double) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => c.move_to(x, y)
    Some(PureBackend(r)) => r.move_to(x, y)
    None => ()
  }
}

///|
pub fn Painter::line_to(self : Painter, x : Double, y : Double) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => c.line_to(x, y)
    Some(PureBackend(r)) => r.line_to(x, y)
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
  match self.backend {
    Some(CairoBackend(c)) => c.bezier_curve_to(cp1x, cp1y, cp2x, cp2y, x, y)
    Some(PureBackend(r)) => r.bezier_curve_to(cp1x, cp1y, cp2x, cp2y, x, y)
    None => ()
  }
}

///|
/// 圆弧（画布语义：0 指向右，正值向下即顺时针）。`ccw` 参数照旧契约保留但
/// 两层后端都不可用（cairo_arc 对 ea < sa 会规范化成顺时针长弧，纯光栅器
/// 复刻同一规范化）：逆时针需求用折线近似或交换起止角（仅描边时）表达，
/// 见图表圆环与图标弧。
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
  match self.backend {
    Some(CairoBackend(c)) => c.arc(x, y, radius, start_angle, end_angle)
    Some(PureBackend(r)) => r.arc(x, y, radius, start_angle, end_angle)
    None => ()
  }
}

///|
/// 绘制离屏画布（拉伸到目标矩形）。
pub fn Painter::draw_canvas(
  self : Painter,
  canvas : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let bm = canvas.bitmap
  match self.backend {
    Some(CairoBackend(c)) =>
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
    Some(PureBackend(r)) =>
      r.blit(
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
  match self.backend {
    Some(CairoBackend(c)) => c.blit(canvas.bitmap, sx, sy, sw, sh, dx, dy, dw, dh)
    Some(PureBackend(r)) => r.blit(canvas.bitmap, sx, sy, sw, sh, dx, dy, dw, dh)
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
  match self.backend {
    Some(CairoBackend(c)) => {
      self.apply_fill()
      c.fill()
    }
    Some(PureBackend(r)) => {
      self.apply_fill()
      r.fill()
    }
    None => ()
  }
}

///|
pub fn Painter::stroke(self : Painter) -> Unit {
  match self.backend {
    Some(CairoBackend(c)) => {
      self.apply_stroke()
      c.stroke()
    }
    Some(PureBackend(r)) => {
      self.apply_stroke()
      r.stroke()
    }
    None => ()
  }
}

///|
/// 当前 Cairo 会话号。文本层拿它在**本上下文**上画字，平移与裁剪才会生效
/// （自己拿 bitmap 画是另一条路径，会无视控件原点）。纯光栅器后端返回 None
/// ——文本层据此走「直接往 Bitmap 画」路径（W5 的 DirectWrite 形态）。
pub fn Painter::cairo_id(self : Painter) -> Int64? {
  match self.backend {
    Some(CairoBackend(c)) => Some(c.id)
    _ => None
  }
}

///|
/// 纯光栅器后端的会话（文本层 W5 在 Windows 直接取 Bitmap 画）；
/// cairo 后端返回 None。
pub fn Painter::raster(self : Painter) -> Raster? {
  match self.backend {
    Some(PureBackend(r)) => Some(r)
    _ => None
  }
}
