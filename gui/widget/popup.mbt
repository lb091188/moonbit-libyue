// 原生弹层窗口的宿主侧（批 E）：把「一扇无边框、贴着锚点、恒在自己之上的窗」
// 收成一句 `App::open_popup`。它是宿主注册表里的**附窗**——关掉它不影响宿主
// （批 A 的关窗裁决），所以菜单/下拉/对话框这类弹层可以随开随关。
//
// 为什么非要真窗口而不是自绘图层：自绘像素永远画在原生子件（webview 区）之下，
// 浮层要能盖住网页就只能走窗口系统（方案 §4.5 的浮层纪律）。

///|
/// 弹层摆位的纯规则：`owner` 的屏幕原点 + 锚点在窗口内的坐标 = 期望位置；
/// 越过屏幕右边/下边时翻到锚点另一侧（菜单贴着右边缘时向左展开、贴底时向上），
/// 最后钳回非负。屏幕尺寸给 0 表示未知，此时只钳不翻。
pub fn popup_place(
  owner_x : Int,
  owner_y : Int,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  screen_w : Int,
  screen_h : Int,
) -> (Int, Int) {
  let mut px = owner_x + x
  let mut py = owner_y + y
  if screen_w > 0 && px + w > screen_w {
    px = owner_x + x - w
  }
  if screen_h > 0 && py + h > screen_h {
    py = owner_y + y - h
  }
  (if px < 0 { 0 } else { px }, if py < 0 { 0 } else { py })
}

///|
/// 开一扇弹层窗：位置按「本窗屏幕原点 + (x, y)」算，`screen_w`/`screen_h` 传
/// 工作区尺寸才会做越界翻转（给 0 就是不翻转）。建好即登记为附窗，
/// `mount` 内容、`close_window` 收起；本窗与它共用同一个循环与泵。
pub fn App::open_popup(
  self : App,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  screen_w? : Int = 0,
  screen_h? : Int = 0,
) -> App? {
  let o = self.session.window.origin()
  let pos = popup_place(
    o.0,
    o.1,
    x,
    y,
    width,
    height,
    screen_w,
    screen_h,
  )
  app_window(width, height, "popup", Some(self.session.window), Some(pos))
}
