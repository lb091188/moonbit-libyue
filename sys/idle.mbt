// 用户空闲秒数（W21e）：跨平台门面，自由函数形态（无对象、无单例）。
//
// 语义：**自最后一次输入起的秒数**。阈值判定（「多久算空闲」）由调用方自己
// 比较——库只给读数，不设 active/idle 二值接口（不同应用的阈值差别很大）。
//
// 平台取数（C 桩：`sys_stub.c` 的空闲节）：
//   Windows `GetLastInputInfo` + `GetTickCount`（差值按 DWORD 取模，扛 ~49.7 天回绕）
//   Linux   X11 的 XScreenSaver 扩展（运行期 dlopen libX11 + libXss，不引入链接依赖）
//   macOS   本批未实现（`idle_supported()` 为 false，`idle_seconds()` 给 Unsupported）
//
// **Wayland 会话**：没有 X 服务端（`DISPLAY` 为空）时 `idle_supported()` 就是
// false，`idle_seconds()` 给 `Unsupported` 而**不给错数**——XWayland 下输入不进
// X 服务端，读数只会虚高。
//
// 典型用法：
//   match idle_seconds() {
//     Ok(sec) => if sec > 300.0 { /* 5 分钟没动过 */ }
//     Err(e) => println(e.to_string())
//   }

///|
/// 空闲查询错误（不支持与失败分开，不静默）。
pub(all) enum IdleError {
  /// 本平台 / 本会话不支持（macOS 本批未实现、Wayland 会话、无 X 服务端）
  Unsupported
  /// 支持但这次查询失败（如 X 连接中途断开），带说明
  Failed(String)
}

///|
pub impl Show for IdleError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("IdleError::Unsupported")
    Failed(m) => logger.write_string("IdleError::Failed(\{m})")
  }
}

///|
pub extend IdleError with Show::{to_string, output}

///|
/// 毫秒读数夹取：负数（理论上不该出现，防御平台接口给怪值）一律归零，
/// 免得换算成秒后是负的空闲时间。
pub fn idle_clamp_ms(ms : Int64) -> Int64 {
  if ms < 0L {
    0L
  } else {
    ms
  }
}

///|
/// 毫秒 → 秒（门的换算；夹过负值）。
pub fn idle_ms_to_seconds(ms : Int64) -> Double {
  idle_clamp_ms(ms).to_double() / 1000.0
}

///|
extern "c" fn ffi_sys_idle_supported() -> Int = "yue_sys_idle_supported"

///|
#borrow(ok)
extern "c" fn ffi_sys_idle_seconds_ms(ok : Ref[Int]) -> Int64 = "yue_sys_idle_seconds_ms"

///|
/// 本平台 / 本会话是否提供空闲查询（运行期探测：Windows 恒真；Linux 要有
/// `DISPLAY` 且 libX11 + libXss 能 dlopen；macOS 本批 false）。
pub fn idle_supported() -> Bool {
  ffi_sys_idle_supported() == 1
}

///|
/// 自最后一次输入起的秒数。不支持给 `Err(Unsupported)`；支持但这次取不到
/// （如 X 连接失败）给 `Err(Failed)`——不把失败当 0 秒，否则「空闲了多久」
/// 会被误判成「刚动过」。
pub fn idle_seconds() -> Result[Double, IdleError] {
  let ok = Ref(0)
  let ms = ffi_sys_idle_seconds_ms(ok)
  if ok.val == 1 {
    Ok(idle_ms_to_seconds(ms))
  } else if idle_supported() {
    Err(Failed("空闲查询失败"))
  } else {
    Err(Unsupported)
  }
}
