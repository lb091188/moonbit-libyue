// 几何族(对照 PointF/SizeF/RectF/InsetsF/Vector2dF 结构体页):
// 纯 MoonBit 值类型,ABI 仍按 double 拆传,类型在本层组装。

///|
/// 点(对照 nu::PointF)。
pub(all) struct PointF {
  x : Double
  y : Double
}

///|
/// 尺寸(对照 nu::SizeF)。
pub(all) struct SizeF {
  width : Double
  height : Double
}

///|
/// 矩形(对照 nu::RectF;x/y 为相对父节点/所在坐标系的原点偏移)。
pub(all) struct RectF {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
/// 四边内缩量(对照 nu::InsetsF)。
pub(all) struct InsetsF {
  left : Double
  top : Double
  right : Double
  bottom : Double
}

///|
/// 二维偏移向量(对照 nu::Vector2dF)。
pub(all) struct Vector2dF {
  dx : Double
  dy : Double
}

///|
/// 是否包含点(边界按含左上、不含右下算)。
pub fn RectF::contains(self : RectF, p : PointF) -> Bool {
  p.x >= self.x &&
  p.x < self.x + self.width &&
  p.y >= self.y &&
  p.y < self.y + self.height
}

///|
/// 中心点。
pub fn RectF::center(self : RectF) -> PointF {
  { x: self.x + self.width / 2.0, y: self.y + self.height / 2.0, }
}

///|
/// 四周向外扩(对照 RectF::Enlarge)。
pub fn RectF::enlarge(self : RectF, insets : InsetsF) -> RectF {
  {
    x: self.x - insets.left,
    y: self.y - insets.top,
    width: self.width + insets.left + insets.right,
    height: self.height + insets.top + insets.bottom,
  }
}

///|
/// 四周向内缩(Enlarge 的逆操作)。
pub fn RectF::shrink(self : RectF, insets : InsetsF) -> RectF {
  {
    x: self.x + insets.left,
    y: self.y + insets.top,
    width: (self.width - insets.left - insets.right).max(0.0),
    height: (self.height - insets.top - insets.bottom).max(0.0),
  }
}

///|
/// 两矩形并集(包含两者)。
pub fn RectF::union(self : RectF, other : RectF) -> RectF {
  let x = self.x.min(other.x)
  let y = self.y.min(other.y)
  let right = (self.x + self.width).max(other.x + other.width)
  let bottom = (self.y + self.height).max(other.y + other.height)
  { x, y, width: right - x, height: bottom - y, }
}

///|
/// 两尺寸相加(分量和)。
pub fn SizeF::add(self : SizeF, other : SizeF) -> SizeF {
  { width: self.width + other.width, height: self.height + other.height, }
}

///|
/// 视图相对窗口的偏移(对照 View::OffsetFromWindow)。
pub fn[T : ViewLike] offset_from_window(v : T) -> Vector2dF {
  {
    dx: ffi_view_offset_from_window_x(v.view()),
    dy: ffi_view_offset_from_window_y(v.view()),
  }
}

///|
/// 视图相对另一视图的偏移(对照 View::OffsetFromView,可为不同控件类型)。
pub fn[A : ViewLike, B : ViewLike] offset_from_view(
  v : A,
  from : B,
) -> Vector2dF {
  {
    dx: ffi_view_offset_from_view_x(v.view(), from.view()),
    dy: ffi_view_offset_from_view_y(v.view(), from.view()),
  }
}
