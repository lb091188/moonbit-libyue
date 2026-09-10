// 使用者视角：只有 MoonBit 类型和回调，没有任何平台相关代码。
// 同一份代码在 Windows / macOS / Linux 上行为一致，
// Linux 托盘缺失 AppIndicator 时由库内部降级为结构化错误。

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

  // 托盘：平台差异由库内收敛。is_supported 为 false 时无需创建，
  // 创建失败也会拿到明确的错误值而不是静默失效。
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
