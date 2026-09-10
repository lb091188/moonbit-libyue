// 应用生命周期：初始化、消息循环、退出。
// 对应 nativeui 的 Lifetime / State / MessageLoop，三件套由 shim 统一管理，
// 消费方不接触任何平台启动差异（如 Windows 的 WinMain）。

///|
/// 初始化 GUI 工具包。必须在创建任何 UI 对象之前调用一次。
pub fn init() -> Bool {
  yue_mbt_app_init()
}

///|
/// 进入平台消息循环，阻塞至 quit() 被调用。
pub fn run() -> Unit {
  yue_mbt_run()
}

///|
/// 请求退出消息循环（线程安全性与平台相关，仅建议在主线程回调中调用）。
pub fn quit() -> Unit {
  yue_mbt_quit()
}

///|
/// 当前运行平台。库内部分支用；消费方正常情况下不应需要它。
pub fn platform() -> String {
  match yue_mbt_platform() {
    0 => "linux"
    1 => "macos"
    2 => "windows"
    _ => "unknown"
  }
}
