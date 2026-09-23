// 内嵌浏览器 FFI:yue_mbt_browser_* 的 extern 声明与桥接工具。
// 本包独立存在的意义是把 webkit 链接依赖圈在包边界内——主包不 import
// 本包,未用浏览器的程序链接期就见不到任何 webkit 符号。

// String -> UTF-8 Bytes 的统一出口：MoonBit String 是 UTF-16，
// FFI 边界上一律转成 C 侧期望的 UTF-8，转换成本留在库内。
fn utf8_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}

// UTF-8 Bytes -> String：C 侧返回字符串时的统一入口。
fn from_utf8_bytes(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes)
}

///|
/// 回调注册表：持有所有已注册闭包的强引用，保证 C 侧保存的函数指针
/// 在对象存活期内不被 GC 回收。带参与不带参回调分表存放。
let callbacks : Ref[Array[() -> Unit]] = Ref([])

///|
let bytes_callbacks : Ref[Array[(Bytes) -> Unit]] = Ref([])

///|
fn keep_alive(callback : () -> Unit) -> Unit {
  callbacks.val.push(callback)
}

///|
fn keep_alive_bytes(callback : (Bytes) -> Unit) -> Unit {
  bytes_callbacks.val.push(callback)
}

///|
extern "c" fn ffi_browser_new_ex(
  devtools : Int,
  context_menu : Int,
  allow_file_access : Int,
  hardware_acceleration : Int,
) -> @yue.View = "yue_mbt_browser_new_ex"

///|
#borrow(browser, url, invoke, callback)
extern "c" fn ffi_browser_get_cookies_for_url(
  browser : @yue.View,
  url : Bytes,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_get_cookies_for_url"

///|
extern "c" fn ffi_browser_new() -> @yue.View = "yue_mbt_browser_new"

///|
#borrow(browser, url)
extern "c" fn ffi_browser_load_url(browser : @yue.View, url : Bytes) -> Unit = "yue_mbt_browser_load_url"

///|
#borrow(browser)
extern "c" fn ffi_browser_get_url(browser : @yue.View) -> Bytes = "yue_mbt_browser_get_url"

///|
#borrow(browser)
extern "c" fn ffi_browser_reload(browser : @yue.View) -> Unit = "yue_mbt_browser_reload"

///|
#borrow(browser)
extern "c" fn ffi_browser_go_back(browser : @yue.View) -> Unit = "yue_mbt_browser_go_back"

///|
#borrow(browser)
extern "c" fn ffi_browser_go_forward(browser : @yue.View) -> Unit = "yue_mbt_browser_go_forward"

///|
#borrow(browser)
extern "c" fn ffi_browser_can_go_back(browser : @yue.View) -> Int = "yue_mbt_browser_can_go_back"

///|
#borrow(browser)
extern "c" fn ffi_browser_can_go_forward(browser : @yue.View) -> Int = "yue_mbt_browser_can_go_forward"

///|
#borrow(browser)
extern "c" fn ffi_browser_is_loading(browser : @yue.View) -> Int = "yue_mbt_browser_is_loading"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_change_loading(
  browser : @yue.View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_browser_on_change_loading"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_update_command(
  browser : @yue.View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_browser_on_update_command"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_update_title(
  browser : @yue.View,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_on_update_title"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_commit_navigation(
  browser : @yue.View,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_on_commit_navigation"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_finish_navigation(
  browser : @yue.View,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_on_finish_navigation"

///|
#borrow(browser, html, base_url)
extern "c" fn ffi_browser_load_html(
  browser : @yue.View,
  html : Bytes,
  base_url : Bytes,
) -> Unit = "yue_mbt_browser_load_html"

///|
#borrow(browser, agent)
extern "c" fn ffi_browser_set_user_agent(browser : @yue.View, agent : Bytes) -> Unit = "yue_mbt_browser_set_user_agent"

///|
#borrow(browser, code)
extern "c" fn ffi_browser_execute_javascript(
  browser : @yue.View,
  code : Bytes,
) -> Unit = "yue_mbt_browser_execute_javascript"

///|
#borrow(browser)
extern "c" fn ffi_browser_get_title(browser : @yue.View) -> Bytes = "yue_mbt_browser_get_title"

///|
#borrow(browser)
extern "c" fn ffi_browser_stop(browser : @yue.View) -> Unit = "yue_mbt_browser_stop"

///|
#borrow(scheme, invoke, callback)
extern "c" fn ffi_browser_register_protocol(
  scheme : Bytes,
  invoke : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  callback : (Bytes) -> Bytes,
) -> Unit = "yue_mbt_browser_register_protocol"

///|
#borrow(scheme)
extern "c" fn ffi_browser_unregister_protocol(scheme : Bytes) -> Unit = "yue_mbt_browser_unregister_protocol"

///|
#borrow(browser, code, invoke, callback)
extern "c" fn ffi_browser_execute_javascript_callback(
  browser : @yue.View,
  code : Bytes,
  invoke : FuncRef[((Int, Bytes) -> Unit, Int, Bytes) -> Unit],
  callback : (Int, Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_execute_javascript_callback"

///|
#borrow(browser, name, invoke, callback)
extern "c" fn ffi_browser_add_raw_binding(
  browser : @yue.View,
  name : Bytes,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_add_raw_binding"

///|
#borrow(browser, name)
extern "c" fn ffi_browser_remove_binding(browser : @yue.View, name : Bytes) -> Unit = "yue_mbt_browser_remove_binding"

///|
#borrow(browser)
extern "c" fn ffi_browser_has_bindings(browser : @yue.View) -> Int = "yue_mbt_browser_has_bindings"
