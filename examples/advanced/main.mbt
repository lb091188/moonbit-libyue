// 批次B 综合演示：日期选择 / GIF 播放 / 系统通知 / 全局快捷键。

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let win = @yue.Window::new()
  win.set_content_size(380.0, 300.0)
  win.on_close(fn(_window) { @yue.quit() })

  let content = @yue.Container::new()
  content.set_style("padding", 12.0)
  win.set_content(content)

  // 日期选择
  let date_group = @yue.Group::new("选择日期")
  date_group.set_style("flex", 1.0)
  date_group.set_style("marginBottom", 10.0)
  content.add_child(date_group)
  let date_picker = @yue.DatePicker::new()
  // 时间读写：以 Unix epoch 秒设置为 2000-01-01（UTC），再读回
  date_picker.set_date(946684800L)
  println(
    "日期读写往返：\{date_picker.get_date()}（应为 946684800）",
  )
  date_picker.on_date_change(fn() { println("日期已变化") })
  date_group.set_content(date_picker)

  // GIF 播放
  let gif_group = @yue.Group::new("GIF 播放")
  gif_group.set_style("flex", 1.0)
  gif_group.set_style("marginBottom", 10.0)
  content.add_child(gif_group)
  let player = @yue.GifPlayer::new()
  player.set_image(@yue.Image::new_from_file("examples/advanced/dot.gif"))
  gif_group.set_content(player)

  // 全局快捷键 Ctrl+Shift+M（进程存活期间全局生效）
  let sid = @yue.register_global_shortcut("CmdOrCtrl+Shift+M", fn() {
    println("全局快捷键 Ctrl+Shift+M 触发")
  })
  println("全局快捷键已注册 id=\{sid}")

  // 通知按钮
  let notify_btn = @yue.Button::new("发送系统通知")
  notify_btn.on_click(fn() {
    let n = @yue.Notification::new()
    n.set_title("moonbit-libyue")
    n.set_body("这是一条系统通知")
    n.set_silent(true)
    n.show()
  })
  content.add_child(notify_btn)

  win.center()
  win.activate()
  @yue.run()
}
