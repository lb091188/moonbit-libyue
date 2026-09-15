// 复刻自 yue-sample-apps/drag_destination：接受文件/文本/图片拖入并显示。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(400.0, 400.0)
  win.on_close(fn(_window) { @yue.quit() })

  let content = @yue.Container::new()
  content.set_background_color("#FFF")
  win.set_content(content)

  let drop = @yue.Container::new()
  drop.set_style("flex", 1.0)
  drop.set_style("margin", 10.0)
  content.add_child(drop)

  // 状态：拖拽中的数据
  let is_dragging = Ref(false)
  let dropped_text = Ref("")
  let dropped_image = @yue.ImageSlot::new()

  drop.register_dragged_types([@yue.FilePaths, @yue.Text, @yue.Image])
  drop.handle_drag_enter(fn(_info, _x, _y) {
    is_dragging.val = true
    drop.schedule_paint()
    @yue.DRAG_OPERATION_COPY
  })
  drop.on_drag_leave(fn() {
    is_dragging.val = false
    drop.schedule_paint()
  })
  drop.handle_drop(fn(info, _x, _y) {
    // 优先取文件路径，其次文本，最后图片
    match info.get_data(@yue.FilePaths) {
      Some(@yue.Paths(paths)) => {
        let sb = StringBuilder()
        for i, p in paths {
          if i > 0 {
            sb.write_char('\n')
          }
          sb.write_string(p)
        }
        dropped_text.val = sb.to_string()
      }
      _ =>
        match info.get_data(@yue.Text) {
          Some(@yue.Text(text)) => dropped_text.val = text
          _ =>
            match info.get_data(@yue.Image) {
              Some(@yue.Img(image)) => dropped_image.set(Some(image))
              _ => dropped_text.val = ""
            }
        }
    }
    drop.schedule_paint()
    true
  })

  drop.on_draw(fn(painter) {
    painter.set_color(if is_dragging.val { "#F23" } else { "#A89" })
    let r = drop.get_bounds()
    painter.stroke_rect(r.x, r.y, r.width, r.height)
    let (x, y, w, h) = (r.x + 1.0, r.y + 1.0, r.width - 2.0, r.height - 2.0)
    match dropped_image.get() {
      Some(image) => painter.draw_image(image, x, y, w, h)
      None =>
        if dropped_text.val != "" {
          painter.draw_text(dropped_text.val, x, y, w, h)
        } else {
          painter.draw_text(
            "Please drag things here",
            x,
            y,
            w,
            h,
            align=@yue.Center,
            valign=@yue.Center,
            color="#999",
          )
        }
    }
  })

  win.center()
  win.activate()
  @yue.run()
}
