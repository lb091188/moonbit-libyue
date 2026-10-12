// web 的 extern 层：与 webkit_stub.c 逐位对齐（含参数个数）。
// 约定照抄仓库既有形态：extern 私有、文本一律 Bytes（`@utf8.encode` 带尾零）、
// C 侧不回调 MoonBit，字符串用「C 写缓冲 + MoonBit 读」的形态取。

///|
extern "c" fn wb_available() -> Int = "wb_available"

///|
/// 这个句柄的视图还在不在（窗口拆掉后一律 0）
extern "c" fn wb_alive(id : Int64) -> Int = "wb_alive"

///|
/// 持久化 profile 能不能用（Linux 恒可，macOS 有 14+ 与 bundle id 那道边界）
extern "c" fn wb_persistence() -> Int = "wb_persistence"

///|
/// 可选信号在位掩码：1 下载 2 进程终止 4 权限 8 新窗
extern "c" fn wb_signal_mask() -> Int = "wb_signal_mask"

///|
#borrow(uri, data_dir, user_agent)
extern "c" fn wb_create(
  surface_id : Int64,
  w : Int,
  h : Int,
  uri : Bytes,
  data_dir : Bytes,
  user_agent : Bytes,
) -> Int64 = "wb_create"

///|
#borrow(uri)
extern "c" fn wb_load_uri(id : Int64, uri : Bytes) -> Unit = "wb_load_uri"

///|
#borrow(html, base_uri)
extern "c" fn wb_load_html(
  id : Int64,
  html : Bytes,
  base_uri : Bytes,
) -> Unit = "wb_load_html"

///|
extern "c" fn wb_reload(id : Int64) -> Unit = "wb_reload"

///|
extern "c" fn wb_stop(id : Int64) -> Unit = "wb_stop"

///|
extern "c" fn wb_go_back(id : Int64) -> Unit = "wb_go_back"

///|
extern "c" fn wb_go_forward(id : Int64) -> Unit = "wb_go_forward"

///|
extern "c" fn wb_can_go_back(id : Int64) -> Int = "wb_can_go_back"

///|
extern "c" fn wb_can_go_forward(id : Int64) -> Int = "wb_can_go_forward"

///|
extern "c" fn wb_is_loading(id : Int64) -> Int = "wb_is_loading"

///|
extern "c" fn wb_is_crashed(id : Int64) -> Int = "wb_is_crashed"

///|
#borrow(out)
extern "c" fn wb_uri(id : Int64, out : Bytes, cap : Int) -> Int = "wb_uri"

///|
#borrow(out)
extern "c" fn wb_title(id : Int64, out : Bytes, cap : Int) -> Int = "wb_title"

///|
#borrow(script)
extern "c" fn wb_evaluate(id : Int64, script : Bytes) -> Int64 = "wb_evaluate"

///|
#borrow(source)
extern "c" fn wb_add_user_script(id : Int64, source : Bytes) -> Unit =
  "wb_add_user_script"

///|
#borrow(name)
extern "c" fn wb_add_binding(id : Int64, name : Bytes) -> Int = "wb_add_binding"

///|
#borrow(scheme, root)
extern "c" fn wb_register_scheme(
  id : Int64,
  scheme : Bytes,
  root : Bytes,
) -> Int = "wb_register_scheme"

///|
#borrow(scheme)
extern "c" fn wb_unregister_scheme(id : Int64, scheme : Bytes) -> Int =
  "wb_unregister_scheme"

///|
extern "c" fn wb_next_event(id : Int64) -> Int = "wb_next_event"

///|
extern "c" fn wb_event_num(id : Int64) -> Int64 = "wb_event_num"

///|
#borrow(out)
extern "c" fn wb_event_text(
  id : Int64,
  out : Bytes,
  cap : Int,
) -> Int = "wb_event_text"

///|
extern "c" fn wb_set_new_window_policy(id : Int64, mode : Int) -> Unit =
  "wb_set_new_window_policy"

///|
extern "c" fn wb_set_permission_mode(id : Int64, allow : Int) -> Unit =
  "wb_set_permission_mode"

///|
extern "c" fn wb_set_download_mode(id : Int64, allow : Int) -> Unit =
  "wb_set_download_mode"

///|
#borrow(uri)
extern "c" fn wb_get_cookies(id : Int64, uri : Bytes) -> Unit = "wb_get_cookies"

///|
#borrow(ua)
extern "c" fn wb_set_user_agent(id : Int64, ua : Bytes) -> Unit =
  "wb_set_user_agent"

///|
extern "c" fn wb_set_visible(id : Int64, visible : Int) -> Unit =
  "wb_set_visible"

///|
extern "c" fn wb_set_size(id : Int64, w : Int, h : Int) -> Unit = "wb_set_size"

///|
extern "c" fn wb_destroy(id : Int64) -> Unit = "wb_destroy"
