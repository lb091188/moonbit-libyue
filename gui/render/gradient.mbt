// 渐变：旧契约 Painter 没有这个能力，属本栈补面（图表面积填充与主题辉光要用）。
// 语义按 Cairo 图案（与 CSS gradient 同形）：坐标为逻辑像素、offset 0..1，
// 超出端点按 pad 复现端点色；构造后经 `Painter::set_fill_gradient` 生效。
// 值语义：`set_fill_gradient` 存的是入参快照，之后继续 `add_stop` 不再影响已设的笔。

///|
pub(all) enum GradientKind {
  Linear(Double, Double, Double, Double)
  Radial(Double, Double, Double, Double)
}

///|
pub(all) struct Gradient {
  kind : GradientKind
  stops : Array[(Double, Color)]
}

///|
/// 线性渐变：(x0, y0) → (x1, y1)。
pub fn Gradient::linear(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Gradient {
  { kind: Linear(x0, y0, x1, y1), stops: [] }
}

///|
/// 同心径向渐变：中心 (cx, cy)、起止半径 r0 → r1。
pub fn Gradient::radial(
  cx : Double,
  cy : Double,
  r0 : Double,
  r1 : Double,
) -> Gradient {
  { kind: Radial(cx, cy, r0, r1), stops: [] }
}

///|
/// 追加颜色停靠点；offset 钳制到 [0, 1]，hex 非法则忽略。
pub fn Gradient::add_stop(
  self : Gradient,
  offset : Double,
  hex : String,
) -> Unit {
  let at = if offset < 0.0 {
    0.0
  } else if offset > 1.0 {
    1.0
  } else {
    offset
  }
  match Color::parse(hex) {
    Some(c) => self.stops.push((at, c))
    None => ()
  }
}

///|
fn gradient_snapshot(g : Gradient) -> Gradient {
  let stops : Array[(Double, Color)] = []
  for s in g.stops {
    stops.push(s)
  }
  { kind: g.kind, stops, }
}
