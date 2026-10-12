// 原生弹层窗口（批 E）：把一扇窗配成「弹层」——无边框、不进任务栏、transient 到
// owner、恒在 owner 之上。存在的理由是一条物理事实：自绘像素永远画在原生子件
// （webview 区）之下，所以浮层要能盖住网页，就必须是真的顶层窗口（方案 §4.5）。

///|
/// 在 `show` 之前调用才生效（类型提示与 transient 关系在映射时定）。
/// owner 给 None 时只去装饰与置顶（例如独立的全屏遮罩）。
pub fn Window::set_popup(self : Window, owner : Window?) -> Unit {
  let oid = match owner {
    None => 0L
    Some(o) => o.id
  }
  wm_window_set_popup(self.id, oid)
}

///|
/// 摆到屏幕坐标（弹层按「owner 原点 + 锚点的窗口内矩形」算）。
pub fn Window::move_to(self : Window, x : Int, y : Int) -> Unit {
  wm_window_move(self.id, x, y)
}

///|
/// 客户区在屏幕上的原点（拿不到时给 (0,0)，调用方按它摆位不会崩，只会贴边）。
pub fn Window::origin(self : Window) -> (Int, Int) {
  let ox = Ref(0)
  let oy = Ref(0)
  wm_window_origin(self.id, ox, oy)
  (ox.val, oy.val)
}
