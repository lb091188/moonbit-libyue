// 事件演示：鼠标 down/up/move/enter/leave + 双击计数 + 鼠标捕获 + 键盘事件。
// 运行后把鼠标移入蓝色区域触发各类事件；点击「捕获」按钮试验鼠标捕获；
// 按 Esc 退出。事件同时打印到 stdout，便于自动化验证。

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_title("Events 演示")
  window.set_content_size(560.0, 420.0)
  window.center()
  window.on_close(fn(_window) { @yue.quit() })

  let root = @yue.Container::new()
  root.set_style("padding", 12.0)
  window.set_content(root)

  let status = @yue.Label::new(
    "把鼠标移进蓝色区域 / 点击 / 按 Esc 退出",
  )
  status.set_style("marginBottom", 8.0)
  root.add_child(status)

  // 事件接收区：所有鼠标事件都打在这里
  let area = @yue.Container::new()
  area.set_style("flex", 1.0)
  area.set_background_color("#4A90D9")
  root.add_child(area)

  let tracker = @yue.ClickTracker::new()

  area.on_mouse_enter(fn(event) {
    status.set_text("enter @(\{event.view_x}, \{event.view_y})")
    println("EVENT enter")
  })
  area.on_mouse_leave(fn(_event) {
    status.set_text("leave")
    println("EVENT leave")
  })
  area.on_mouse_move(fn(event) {
    status.set_text("move @(\{event.view_x}, \{event.view_y})")
  })
  area.on_mouse_down(fn(event) {
    let clicks = tracker.feed(event)
    status.set_text(
      "down btn=\{event.button} 第\{clicks}次点击 mods=\{event.modifiers}",
    )
    println(
      "EVENT down btn=\{event.button} clicks=\{clicks} mods=\{event.modifiers} ts=\{event.timestamp}",
    )
    false
  })
  area.on_mouse_up(fn(event) {
    status.set_text("up btn=\{event.button}")
    println("EVENT up btn=\{event.button}")
    false
  })

  // 鼠标捕获：捕获期间即便按住拖出窗口，move/up 仍送达本视图
  let capture_row = @yue.Container::new()
  capture_row.set_style_str("flexDirection", "row")
  capture_row.set_style("marginTop", 8.0)
  root.add_child(capture_row)
  let capture_btn = @yue.Button::new("切换鼠标捕获")
  capture_btn.set_style("marginRight", 8.0)
  capture_row.add_child(capture_btn)
  let capture_state = @yue.Label::new("未捕获")
  capture_row.add_child(capture_state)
  capture_btn.on_click(fn() {
    if area.has_capture() {
      area.release_capture()
    } else {
      area.set_capture()
    }
    capture_state.set_text(
      if area.has_capture() {
        "已捕获"
      } else {
        "未捕获"
      },
    )
    println("EVENT capture_toggle now=\{area.has_capture()}")
  })
  area.on_capture_lost(fn() {
    capture_state.set_text("捕获被夺走")
    println("EVENT capture_lost")
  })

  // 键盘：Esc 退出；其余打印键值（KeyboardCode 见 yue/events.mbt VKEY_* 常量）
  window.on_key_down(fn(event) {
    println("EVENT key code=\{event.code} mods=\{event.modifiers}")
    if event.code == @yue.VKEY_ESCAPE {
      println("EVENT quit")
      @yue.quit()
      true
    } else {
      false
    }
  })
  window.on_key_up(fn(event) {
    if event.code == @yue.VKEY_ESCAPE {
      println("EVENT keyup esc")
      true
    } else {
      false
    }
  })

  window.activate()
  @yue.run()
}
