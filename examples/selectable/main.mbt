// 文字可选择验证示例:上行 set_selectable(true),下行对照(不可选)。
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_title("文字可选择验证(Linux)")
  let selectable = @yue.Label::new("这行文字应该可以用鼠标拖选,选中后 Ctrl+C 可复制")
  selectable.set_selectable(true)
  let plain = @yue.Label::new("这行是对照:不可选中,拖选无反应")
  let tip = @yue.Label::new("验完点窗口关闭退出")
  let root = @yue.Container::new()
  root.add_child(selectable)
  root.add_child(plain)
  root.add_child(tip)
  window.set_content(root)
  window.on_close(fn(_w) { @yue.quit() })
  window.set_content_size(560.0, 140.0)
  window.activate()
  @yue.run()
}
