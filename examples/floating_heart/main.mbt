// 复刻自 yue-sample-apps/floating_heart：无边框透明窗口 + 自绘。
// 偏离：绘制以 bezier 心形为主，保持与官方相同的视觉效果。

///|
fn draw_heart(painter : @yue.Painter) -> Unit {
  painter.begin_path()
  painter.move_to(75.0, 40.0)
  painter.bezier_curve_to(75.0, 37.0, 70.0, 25.0, 50.0, 25.0)
  painter.bezier_curve_to(20.0, 25.0, 20.0, 62.5, 20.0, 62.5)
  painter.bezier_curve_to(20.0, 80.0, 40.0, 102.0, 75.0, 120.0)
  painter.bezier_curve_to(110.0, 102.0, 130.0, 80.0, 130.0, 62.5)
  painter.bezier_curve_to(130.0, 62.5, 130.0, 25.0, 100.0, 25.0)
  painter.bezier_curve_to(85.0, 25.0, 75.0, 37.0, 75.0, 40.0)
  painter.fill()
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new_with_options(false, true)
  win.set_always_on_top(true)
  win.set_content_size(150.0, 130.0)
  win.on_close(fn(_window) { @yue.quit() })
  let content = @yue.Container::new()
  content.set_mouse_down_can_move_window(true)
  win.set_content(content)
  content.on_draw(fn(painter) {
    painter.set_fill_color("#3000")
    draw_heart(painter)
    painter.translate(-5.0, -5.0)
    painter.set_fill_color("#D46A6A")
    draw_heart(painter)
  })
  win.center()
  win.activate()
  @yue.run()
}
