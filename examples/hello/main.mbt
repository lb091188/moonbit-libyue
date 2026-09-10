// 使用者视角：只有 MoonBit 类型和回调，没有任何平台相关代码。

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_content(@yue.Label::new("Hello, MoonBit + libyue!"))
  window.set_content_size(400.0, 300.0)
  window.center()
  window.on_close(fn(_window) { @yue.quit() })
  window.activate()
  if @yue.Tray::is_supported() {
    match @yue.Tray::new("examples/hello/icon.png") {
      Ok(tray) => tray.set_title("moonbit-libyue")
      Err(err) => println("托盘创建失败：\{err}")
    }
  } else {
    println("当前系统无托盘后端，跳过托盘")
  }
  @yue.run()
}
