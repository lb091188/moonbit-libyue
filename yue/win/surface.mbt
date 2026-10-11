// 原生子件通道（方案 §4.7）：窗口内容 = 自绘像素 + 若干**可定位的原生子件**。
//
// 三条语义（都在 C 侧成立，MoonBit 只是转发）：
// ① 子件不被 Painter 绘制，z 序在原生侧、恒覆盖在自绘像素之上；
// ② 子件不吃 `clip_rect`——超出窗口的部分由窗口系统裁掉，圆角/透明/被覆盖不作承诺；
// ③ 矩形由 yoga 布局给出（窗口内容坐标），DPI 换算在后端。
//
// 这是**能力型例外**的通道，不是通用子表面：只有本质上不可自绘的东西走它
// （网页渲染，以及后续登记的原生控件）。`ChildKind` 逐条登记，不开放自定义值。

///|
/// 子件类别（值与 C 侧 `kind` 参数一致，登记一条用一条）。
pub(all) enum ChildKind {
  Webview = 1
}

///|
fn child_kind_int(k : ChildKind) -> Int {
  match k {
    Webview => 1
  }
}

///|
/// 一个已挂上的原生子件槽。句柄是窗口层给的，能力层拿它去放真控件
/// （Linux 侧：`wm_surface_container()` 交出 GtkFixed 容器给 webkit 桩）。
pub(all) struct ChildSurface {
  mut id : Int64
}

///|
fn rect_to_ints(rect : (Double, Double, Double, Double)) -> (Int, Int, Int, Int) {
  (
    rect.0.round().to_int(),
    rect.1.round().to_int(),
    rect.2.round().to_int(),
    rect.3.round().to_int(),
  )
}

///|
/// 在本窗挂一个子件槽并摆到 `rect`；后端不支持或窗口已拆时返回 None。
pub fn Window::mount_child_surface(
  self : Window,
  kind : ChildKind,
  rect : (Double, Double, Double, Double),
) -> ChildSurface? {
  let r = rect_to_ints(rect)
  let id = wm_surface_new(self.id, child_kind_int(kind), r.0, r.1, r.2, r.3)
  if id == 0L {
    None
  } else {
    Some({ id, })
  }
}

///|
/// 移动/改大小（布局每帧算完同步一次；C 侧位置没动就不重排）。
pub fn ChildSurface::set_rect(
  self : ChildSurface,
  rect : (Double, Double, Double, Double),
) -> Unit {
  if self.id == -1L {
    return
  }
  let r = rect_to_ints(rect)
  wm_surface_set_rect(self.id, r.0, r.1, r.2, r.3)
}

///|
/// 摘掉子件（幂等：已摘过再调是空操作）。
pub fn ChildSurface::unmount(self : ChildSurface) -> Unit {
  if self.id == -1L {
    return
  }
  wm_surface_close(self.id)
  self.id = -1L
}

///|
/// 交给能力层的槽句柄（0/-1 = 已摘）。
pub fn ChildSurface::handle(self : ChildSurface) -> Int64 {
  self.id
}

///|
/// 子件是否还挂着。
pub fn ChildSurface::is_mounted(self : ChildSurface) -> Bool {
  self.id != -1L
}
