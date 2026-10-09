// 分隔线与方向。

///|
/// 方向。
pub(all) enum Orientation {
  Horizontal
  Vertical
}

///|
fn orientation_id(o : Orientation) -> Int {
  match o {
    Horizontal => 0
    Vertical => 1
  }
}

///|
/// 创建分隔线。
pub fn Separator::new(orientation : Orientation) -> Separator {
  { view: ffi_separator_new(orientation_id(orientation)), }
}
