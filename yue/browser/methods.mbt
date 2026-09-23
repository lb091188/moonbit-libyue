// Browser 方法级能力补齐：标题/停止与 JS 回调、原生绑定。

///|
/// 页面标题。
pub fn Browser::get_title(self : Browser) -> String {
  from_utf8_bytes(ffi_browser_get_title(self.view))
}

///|
/// 停止加载。
pub fn Browser::stop(self : Browser) -> Unit {
  ffi_browser_stop(self.view)
}

///|
/// 执行 JS 并异步取回结果:ok 表示执行成功,json 为结果值的 JSON 文本。
pub fn Browser::execute_javascript_with_result(
  self : Browser,
  code : String,
  callback : (Bool, String) -> Unit,
) -> Unit {
  let wrapped : (Int, Bytes) -> Unit = fn(ok, json) {
    callback(ok == 1, from_utf8_bytes(json))
  }
  keep_alive(fn() { ignore(wrapped) })
  ffi_browser_execute_javascript_callback(
    self.view,
    utf8_bytes(code),
    fn(f : (Int, Bytes) -> Unit, ok : Int, json : Bytes) -> Unit { f(ok, json) },
    wrapped,
  )
}

///|
/// 注册 JS↔原生绑定:网页 JS 调用 name(name) 时收到 JSON 参数文本。
/// 仅原始绑定(返回值不经类型转换回传);SetBindingName 改协议名。
pub fn Browser::add_raw_binding(
  self : Browser,
  name : String,
  callback : (String) -> Unit,
) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(json) { callback(from_utf8_bytes(json)) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_browser_add_raw_binding(
    self.view,
    utf8_bytes(name),
    fn(f : (Bytes) -> Unit, json : Bytes) -> Unit { f(json) },
    wrapped,
  )
}

///|
/// 移除绑定。
pub fn Browser::remove_binding(self : Browser, name : String) -> Unit {
  ffi_browser_remove_binding(self.view, utf8_bytes(name))
}

///|
/// 是否存在已注册绑定。
pub fn Browser::has_bindings(self : Browser) -> Bool {
  ffi_browser_has_bindings(self.view) == 1
}
