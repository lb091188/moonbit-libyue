// 用户空闲秒数:跨平台统一,阈值判定(active / idle)由调用方自行比较,
// 库不设单独接口。Linux 走 X 屏幕扩展 XSS(运行期 dlopen,Wayland 会话
// 显式不支持);Windows 走最后输入时间;macOS 暂缓。

///|
/// 当前平台是否提供空闲查询(macOS 暂缓)。Wayland 会话在 idle_seconds
/// 里给结构化 Unsupported。
pub fn idle_supported() -> Bool {
  match platform() {
    "linux" | "windows" => true
    _ => false
  }
}

///|
/// 用户空闲秒数(自最后一次输入起)。XWayland 会话输入不进 X 服务端,
/// 读数虚高,显式 Err(Unsupported) 而非给错数。
pub fn idle_seconds() -> Result[Double, IdleError] {
  let ok = Ref(0)
  let ms = ffi_idle_seconds_ms(ok)
  if ok.val == 1 {
    Ok(ms.to_double() / 1000.0)
  } else {
    Err(Unsupported)
  }
}
