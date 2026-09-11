// 复刻自 yue-sample-apps/auto_height_edit：TextEdit 随内容自动调窗口高度。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.on_close(fn(_window) { @yue.quit() })
  let edit = @yue.TextEdit::new()
  win.set_content(edit)
  // 用 1 行和 20 行文本测出高度范围
  edit.set_text("1")
  let min_height = edit.get_text_bounds_height()
  let sb = StringBuilder()
  for i = 0; i < 20; i = i + 1 {
    if i > 0 {
      sb.write_string("\n")
    }
    sb.write_string("1")
  }
  edit.set_text(sb.to_string())
  let max_height = edit.get_text_bounds_height()
  edit.set_text("")
  edit.on_text_change(fn() {
    let mut height = edit.get_text_bounds_height()
    if height < min_height {
      height = min_height
    } else if height > max_height {
      height = max_height
    }
    let cur = win.get_content_size().height
    if height != cur {
      win.set_content_size(win.get_content_size().width, height)
    }
  })
  win.set_content_size(200.0, min_height)
  win.center()
  win.activate()
  edit.focus()
  @yue.run()
}
