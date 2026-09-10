// SNI 托盘后端的系统调用面：全部经 shim 转发（yue_mbt_sys_*）。
// 非 Linux 平台 shim 提供失败桩，本包据此优雅降级，绝不触碰真实系统调用。

///|
fn utf8(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
extern "c" fn sys_getuid() -> Int = "yue_mbt_sys_getuid"

///|
#borrow(path)
extern "c" fn sys_unix_connect(path : Bytes) -> Int = "yue_mbt_sys_unix_connect"

///|
#borrow(buf)
extern "c" fn sys_read(fd : Int, buf : Bytes, off : Int, len : Int) -> Int = "yue_mbt_sys_read"

///|
#borrow(buf)
extern "c" fn sys_write(fd : Int, buf : Bytes, off : Int, len : Int) -> Int = "yue_mbt_sys_write"

///|
extern "c" fn sys_poll(fd : Int, events : Int, timeout_ms : Int) -> Int = "yue_mbt_sys_poll"

///|
extern "c" fn sys_close(fd : Int) -> Unit = "yue_mbt_sys_close"

///|
extern "c" fn sys_watch_fd(
  fd : Int,
  events : Int,
  cb : FuncRef[(Int, Int) -> Int],
) -> Int = "yue_mbt_sys_watch_fd"

///|
#borrow(name, out)
extern "c" fn sys_getenv(name : Bytes, out : Bytes, out_len : Int) -> Int = "yue_mbt_sys_getenv"

///|
/// 读环境变量，未设置返回 None。
fn env_get(name : String) -> String? {
  let buf = Bytes::make(1024, 0)
  let n = sys_getenv(utf8(name), buf, 1024)
  if n < 0 {
    None
  } else {
    Some(@utf8.decode_lossy(buf[0:n]))
  }
}
