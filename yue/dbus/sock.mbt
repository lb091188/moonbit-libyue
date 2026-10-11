// 系统调用面（桩 `dbus_stub.c`，只用标准头）：Unix 套接字、uid、Double 位
// 模式。fd 监视与延迟任务**不走 C**——本包不认识任何事件循环，由宿主注入
// （见 [dbus_set_post_delayed] 与 [dbus_pump]），因此 yue/dbus 不依赖 glib、
// 也不依赖 GUI 层。

///|
fn utf8(s : String) -> Bytes {
  @utf8.encode(s)
}

// ---------------------------------------------------------------------------
// FFI（桩：dbus_stub.c）
// ---------------------------------------------------------------------------

///|
#borrow(path)
extern "c" fn ffi_unix_connect(path : Bytes) -> Int = "yue_dbus_unix_connect"

///|
#borrow(buf)
extern "c" fn ffi_read(
  fd : Int,
  buf : Bytes,
  off : Int,
  len : Int,
) -> Int = "yue_dbus_read"

///|
#borrow(buf)
extern "c" fn ffi_write(
  fd : Int,
  buf : Bytes,
  off : Int,
  len : Int,
) -> Int = "yue_dbus_write"

///|
extern "c" fn ffi_poll(fd : Int, events : Int, timeout_ms : Int) -> Int =
  "yue_dbus_poll"

///|
extern "c" fn ffi_close(fd : Int) -> Unit = "yue_dbus_close"

///|
extern "c" fn ffi_getuid() -> Int = "yue_dbus_getuid"

///|
/// Double → IEEE 754 位模式（DBus 'd' 编码）。
extern "c" fn ffi_f64_to_bits(v : Double) -> Int64 = "yue_dbus_f64_to_bits"

///|
/// IEEE 754 位模式 → Double（DBus 'd' 解码）。
extern "c" fn ffi_f64_from_bits(bits : Int64) -> Double =
  "yue_dbus_f64_from_bits"

///|
/// 读环境变量（走 `yue/sys` 的 C 层 getenv，反映进程内写删后的实时值）。
fn env_get(name : String) -> String? {
  @sys.sys_getenv(name)
}
