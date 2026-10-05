// V3 探针:顶层窗口 HWND 暴露验证(Windows 验证清单 V3)。
// 现状:Windows 上 native_handle_view 恒 0(shim TODO);
// 补丁后:native_handle_window 返回顶层窗口 HWND,外部按 PID 枚举
// 顶层可见窗口对号即等价 IsWindow 验证。3 秒自动退出(留外部核对窗口)。

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  let window = @yue.Window::new()
  window.set_title("probe-hwnd")
  let container = @yue.Container::new()
  window.set_content(container)
  window.set_content_size(320.0, 200.0)
  window.center()
  window.activate()
  println("platform=\{@yue.platform()}")
  println("native_handle_view(container) = \{@yue.native_handle_view(container.view)}")
  println("native_handle_view(window.view) = \{@yue.native_handle_view(window.view)}")
  println("native_handle_window(window) = \{@yue.native_handle_window(window)}")
  let _ = @yue.set_timeout(3000, fn() {
    println("probe done (auto quit)")
    @yue.quit()
  })
  @yue.run()
}
