// 几何基元（G9 Batch 2 步骤 3 前置）：窗口坐标系的绝对矩形。
// 坐标口径的唯一换算在 widget 层（relayout 后折算写回），本层只做形态与
// 判定——命中测试、脏区并集、裁剪框求交都吃这一个类型。

///|
pub(all) struct Rect {
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
/// 半开区间判定：`px ∈ [x, x+w)`、`py ∈ [y, y+h)`；零宽/零高矩形不命中。
pub fn Rect::contains(self : Rect, px : Double, py : Double) -> Bool {
  self.w > 0.0 && self.h > 0.0 && px >= self.x && px < self.x + self.w && py >= self.y && py < self.y + self.h
}

///|
/// 两矩形并集（脏区累积用）。
pub fn Rect::union(self : Rect, b : Rect) -> Rect {
  let x0 = if self.x < b.x { self.x } else { b.x }
  let y0 = if self.y < b.y { self.y } else { b.y }
  let r1x = self.x + self.w
  let b1x = b.x + b.w
  let x1 = if r1x > b1x { r1x } else { b1x }
  let r1y = self.y + self.h
  let b1y = b.y + b.h
  let y1 = if r1y > b1y { r1y } else { b1y }
  { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
}
