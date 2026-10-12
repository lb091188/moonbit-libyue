// 系统剪贴板（W16）：Windows 走 Win32 的 CF_UNICODETEXT（桩在 sys_stub.c 的
// _WIN32 分支）；Linux/macOS 走命令线（xclip / pbpaste|pbcopy，经 pr_run）。
// 统一「探测 + 语义化降级」：不可用给 false/None，调用方回退到自己的内部
// 剪贴板（无头测试与没装 xclip 的环境行为不变）。
//
// 命令线传文本用 `sh -c 'printf %s "$1" | xclip -selection clipboard' sh <文本>`
// 的形态：文本走 argv 而不是拼进脚本体——引号、换行、中文都不需要转义。

///|
#borrow(ok)
extern "c" fn ffi_clipboard_get_text(ok : Ref[Int]) -> Bytes = "yue_sys_clipboard_get_text"

///|
#borrow(text)
extern "c" fn ffi_clipboard_set_text(text : Bytes) -> Int = "yue_sys_clipboard_set_text"

///|
/// 当前平台/环境是否支持系统剪贴板。每次调用真实判断（探命令存在性），
/// 高频场景请调用方自行缓存结果。
pub fn clipboard_available() -> Bool {
  match sys_platform() {
    // Win32 API 恒在：个别时刻被别的进程占着由 get/set 返回失败，不算不可用
    "windows" => true
    "linux" =>
      pr_available() && pr_run("xclip", ["-version"], timeout_ms=1000) is Ok(_)
    "macos" => pr_available()
    _ => false
  }
}

///|
/// 读系统剪贴板文本：空或不可用给 None（两者对「粘贴」是同一个动作）。
/// Windows 侧读回来的就是 CF_UNICODETEXT 的宽串转 UTF-8。
pub fn clipboard_get_text() -> String? {
  match sys_platform() {
    "windows" => {
      let ok = Ref(0)
      let bytes = ffi_clipboard_get_text(ok)
      if ok.val == 1 {
        Some(@utf8.decode_lossy(bytes))
      } else {
        None
      }
    }
    "linux" =>
      match pr_run("xclip", ["-selection", "clipboard", "-o"]) {
        Ok(o) => if o.stdout == "" { None } else { Some(o.stdout) }
        Err(_) => None
      }
    "macos" =>
      match pr_run("pbpaste", []) {
        Ok(o) => if o.stdout == "" { None } else { Some(o.stdout) }
        Err(_) => None
      }
    _ => None
  }
}

///|
/// 写系统剪贴板：成功给 true。
pub fn clipboard_set_text(text : String) -> Bool {
  match sys_platform() {
    "windows" => ffi_clipboard_set_text(@utf8.encode(text)) == 0
    "linux" =>
      pr_run(
        "sh",
        ["-c", "printf %s \"$1\" | xclip -selection clipboard", "sh", text],
        timeout_ms=2000,
      ) is Ok(_)
    "macos" =>
      pr_run("sh", ["-c", "printf %s \"$1\" | pbcopy", "sh", text], timeout_ms=2000) is
        Ok(_)
    _ => false
  }
}
