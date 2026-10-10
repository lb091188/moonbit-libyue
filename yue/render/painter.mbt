// 绘制契约的矩形级子集：方法名与参数形态照旧 Painter（`yue/painter.mbt`）对齐，
// 实现归本栈。坐标为逻辑像素，角度弧度制在后续曲线批次引入。
//
// 三条口径先在这里定死，接 Cairo 时按同一口径复核：
// - 取整规则「+0.5 后向下取整」，相邻矩形共用边因此不留 1px 缝；
// - `stroke_rect` 描边落在矩形**内侧**，与布局层「宽高 = border-box」同源
//   （Cairo 原语是居中描边，G3 接 Cairo 时需在 win 层补偿，不改本契约）；
// - 可变状态放在 `PainterState` 的内层 mut 字段上，外层 `state` 字段从不重绑，
//   因此调用点不需要 `mut p`（组件层一万行按不可变句柄书写，改签名不可接受）。

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
  mut line_width : Double
}

///|
pub(all) struct Painter {
  bitmap : Bitmap
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
  target.line_width = from.line_width
}

///|
/// 以整块位图为初始裁剪区、黑色为初始前景色建绘制器。
pub fn Painter::new(bitmap : Bitmap) -> Painter {
  let black = color_black
  {
    bitmap,
    state: {
      tx: 0.0,
      ty: 0.0,
      clip_x0: 0,
      clip_y0: 0,
      clip_x1: bitmap.width,
      clip_y1: bitmap.height,
      fill: black,
      stroke: black,
      line_width: 1.0,
    },
    stack: [],
  }
}

///|
pub fn Painter::save(self : Painter) -> Unit {
  self.stack.push(snapshot(self.state))
}

///|
/// 无保存状态时不做任何事（与 Cairo 的 warn-restore 一致，不报错）。
pub fn Painter::restore(self : Painter) -> Unit {
  match self.stack.pop() {
    Some(s) => load_state(self.state, s)
    None => ()
  }
}

///|
pub fn Painter::translate(self : Painter, dx : Double, dy : Double) -> Unit {
  let s = self.state
  s.tx = s.tx + dx
  s.ty = s.ty + dy
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
  }
}

///|
/// hex 非法时保持原色。
pub fn Painter::set_fill_color(self : Painter, hex : String) -> Unit {
  match Color::parse(hex) {
    Some(c) => self.state.fill = c
    None => ()
  }
}

///|
pub fn Painter::set_stroke_color(self : Painter, hex : String) -> Unit {
  match Color::parse(hex) {
    Some(c) => self.state.stroke = c
    None => ()
  }
}

///|
/// 线宽为负按 0 处理。
pub fn Painter::set_line_width(self : Painter, width : Double) -> Unit {
  self.state.line_width = if width < 0.0 { 0.0 } else { width }
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
  let s = self.state
  match device_area(s, x, y, w, h) {
    None => ()
    Some((x0, y0, x1, y1)) => self.bitmap.fill_area(x0, y0, x1, y1, s.fill)
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

///|
/// 当前裁剪区（调试与快照定位用）。
pub fn Painter::clip_bounds(self : Painter) -> (Int, Int, Int, Int) {
  let s = self.state
  (s.clip_x0, s.clip_y0, s.clip_x1, s.clip_y1)
}
