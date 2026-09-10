// 顶层窗口。

///|
/// 关闭回调注册表：持有所有已注册闭包的强引用，
/// 保证 C 侧保存的函数指针在窗口存活期内不被 GC 回收。
/// 回调随窗口对象一起 GC 后，注册表条目由窗口 finalizer 清理（见 TODO）。
let window_close_registry : Ref[Array[() -> Unit]] = Ref::new([])

///|
/// 创建默认选项的窗口。
pub fn Window::new() -> Window {
  yue_mbt_window_new()
}

///|
/// 设置窗口内容视图。
pub fn Window::set_content(self : Window, content : Label) -> Unit {
  yue_mbt_window_set_content(self, content)
}

///|
/// 设置内容区尺寸（逻辑像素）。
pub fn Window::set_content_size(
  self : Window,
  width : Double,
  height : Double,
) -> Unit {
  yue_mbt_window_set_content_size(self, width, height)
}

///|
/// 居中到所在屏幕。
pub fn Window::center(self : Window) -> Unit {
  yue_mbt_window_center(self)
}

///|
/// 激活并获得焦点。
pub fn Window::activate(self : Window) -> Unit {
  yue_mbt_window_activate(self)
}

///|
/// 注册窗口关闭回调。callback 在用户点击关闭时被调用；
/// 调用 quit() 结束消息循环是典型用法。
pub fn Window::on_close(self : Window, callback : (Window) -> Unit) -> Unit {
  let wrapped : () -> Unit = fn() { callback(self) }
  window_close_registry.val.push(wrapped)
  yue_mbt_window_on_close(self, fn(f) { f() }, wrapped)
}
