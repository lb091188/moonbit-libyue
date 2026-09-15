// 复刻自 yue-sample-apps/drag_source：左侧图片容器发起拖动，右侧为提示框。
// 运行后从左侧图片按住拖动到系统任意接受文件的位置。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(240.0, 120.0)
  win.on_close(fn(_window) { @yue.quit() })

  let content = @yue.Container::new()
  content.set_style_str("flexDirection", "row")
  content.set_background_color("#FFF")
  win.set_content(content)

  let drag = @yue.Container::new()
  drag.set_style("width", 100.0)
  drag.set_style("margin", 10.0)
  drag.set_mouse_down_can_move_window(false)
  content.add_child(drag)

  let drop = @yue.Container::new()
  drop.set_style("flex", 1.0)
  drop.set_style("margin", 10.0)
  content.add_child(drop)

  // 拖动数据：本示例的图片
  let image = @yue.Image::new_from_file("examples/drag_source/drag.png")

  // 画图片
  drag.on_draw(fn(painter) {
    let rbounds = drag.get_bounds()
    let w = rbounds.width
    let h = rbounds.height
    painter.draw_image(image, 0.0, 0.0, w, h)
  })

  // 按下即发起拖动：文件路径 + 图片两种数据
  drag.on_mouse_down(fn(_event) {
    let _ = drag.do_drag_file_paths(
      ["examples/drag_source/drag.png"],
      Some(image),
    )
    true
  })

  // 右侧提示框绘制
  drop.on_draw(fn(painter) {
    painter.set_color("#F23")
    let dbounds = drop.get_bounds()
    let x = dbounds.x
    let y = dbounds.y
    let w = dbounds.width
    let h = dbounds.height
    painter.stroke_rect(x, y, w, h)
    painter.draw_text(
      "Drag image here",
      x + 1.0,
      y + 1.0,
      w - 2.0,
      h - 2.0,
      align=@yue.Center,
      valign=@yue.Center,
      color="#999",
    )
  })

  win.center()
  win.activate()
  @yue.run()
}
