// 内嵌浏览器（WebView）。

///|
/// 创建浏览器视图。
pub fn Browser::new() -> Browser {
  { view: ffi_browser_new() }
}

///|
/// 加载 URL。
pub fn Browser::load_url(self : Browser, url : String) -> Unit {
  ffi_browser_load_url(self.view, utf8_bytes(url))
}

///|
/// 当前 URL。
pub fn Browser::get_url(self : Browser) -> String {
  from_utf8_bytes(ffi_browser_get_url(self.view))
}

///|
/// 重新加载。
pub fn Browser::reload(self : Browser) -> Unit {
  ffi_browser_reload(self.view)
}

///|
/// 后退。
pub fn Browser::go_back(self : Browser) -> Unit {
  ffi_browser_go_back(self.view)
}

///|
/// 前进。
pub fn Browser::go_forward(self : Browser) -> Unit {
  ffi_browser_go_forward(self.view)
}

///|
/// 能否后退。
pub fn Browser::can_go_back(self : Browser) -> Bool {
  ffi_browser_can_go_back(self.view) == 1
}

///|
/// 能否前进。
pub fn Browser::can_go_forward(self : Browser) -> Bool {
  ffi_browser_can_go_forward(self.view) == 1
}

///|
/// 是否正在加载。
pub fn Browser::is_loading(self : Browser) -> Bool {
  ffi_browser_is_loading(self.view) == 1
}

///|
/// 加载状态变化。
pub fn Browser::on_change_loading(self : Browser, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_browser_on_change_loading(self.view, fn(f : (() -> Unit)) -> Unit { f() }, callback)
}

///|
/// 命令状态更新（后退/前进可用性等）。
pub fn Browser::on_update_command(self : Browser, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_browser_on_update_command(self.view, fn(f : (() -> Unit)) -> Unit { f() }, callback)
}

///|
/// 页面标题更新。
pub fn Browser::on_update_title(self : Browser, callback : (String) -> Unit) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(title) { callback(from_utf8_bytes(title)) }
  keep_alive_bytes(wrapped)
  ffi_browser_on_update_title(self.view, fn(f : ((Bytes) -> Unit), b : Bytes) -> Unit { f(b) }, wrapped)
}

///|
/// 导航提交（开始加载目标 URL）。
pub fn Browser::on_commit_navigation(self : Browser, callback : (String) -> Unit) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(url) { callback(from_utf8_bytes(url)) }
  keep_alive_bytes(wrapped)
  ffi_browser_on_commit_navigation(self.view, fn(f : ((Bytes) -> Unit), b : Bytes) -> Unit { f(b) }, wrapped)
}

///|
/// 导航完成。
pub fn Browser::on_finish_navigation(self : Browser, callback : (String) -> Unit) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(url) { callback(from_utf8_bytes(url)) }
  keep_alive_bytes(wrapped)
  ffi_browser_on_finish_navigation(self.view, fn(f : ((Bytes) -> Unit), b : Bytes) -> Unit { f(b) }, wrapped)
}
