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
/// 撤销 fd 监视（与 sys_watch_fd 配对）。
extern "c" fn sys_unwatch_fd(fd : Int) -> Unit = "yue_mbt_sys_unwatch_fd"

///|
/// Double → IEEE 754 位模式（DBus 'd' 编码）。
extern "c" fn sys_f64_to_bits(v : Double) -> Int64 = "yue_mbt_sys_f64_to_bits"

///|
/// IEEE 754 位模式 → Double（DBus 'd' 解码）。
extern "c" fn sys_f64_from_bits(bits : Int64) -> Double = "yue_mbt_sys_f64_from_bits"

///|
/// 延迟任务（与 yue 的 post_delayed_task 同一 shim 入口）：断线自愈的
/// 重连须避开 fd 回调现场，投回主循环延迟执行。
#borrow(invoke, callback)
extern "c" fn sys_post_delayed(
  ms : Int,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_post_delayed_task"

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

///|
/// spawn 一个脱离的子进程(PATH 搜索,glib 自动回收子进程,无僵尸)。
#borrow(file, arg)
extern "c" fn sys_spawn_detached(file : Bytes, arg : Bytes) -> Int = "yue_mbt_sys_spawn_detached"

///|
/// spawn 失败给 Err(供 xdg-open 回退与打开 URL 共用)。
pub fn spawn_detached(file : String, arg : String) -> Result[Unit, String] {
  if sys_spawn_detached(utf8(file), utf8(arg)) == 0 {
    Ok(())
  } else {
    Err("spawn 失败: \{file}")
  }
}

///|
#borrow(buf)
extern "c" fn sys_getcwd(buf : Bytes, len : Int) -> Int = "yue_mbt_sys_getcwd"

///|
/// 当前工作目录(失败返回空串)。
pub fn current_dir() -> String {
  let buf = Bytes::make(4096, 0)
  if sys_getcwd(buf, 4096) != 0 {
    return ""
  }
  let mut n = 0
  while n < 4096 && buf[n].to_int() != 0 {
    n += 1
  }
  @utf8.decode_lossy(buf[0:n])
}
