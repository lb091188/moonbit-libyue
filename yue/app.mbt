// 应用生命周期：初始化、消息循环、退出。
// 对应 nativeui 的 Lifetime / State / MessageLoop，三件套由 shim 统一管理，
// 消费方不接触任何平台启动差异（如 Windows 的 WinMain）。

///|
/// 初始化 GUI 工具包。必须在创建任何 UI 对象之前调用一次。
/// 初始化成功后框架默认应用整套系统主题（深浅 + 主色强调色）；应用层
/// 显式 theme_apply 仍可覆盖，此后系统主题实时联动属 opt-in（见
/// on_system_theme_change）。
pub fn initialize() -> Bool {
  // 调用仅为让链接器抽取 win_gui.c 的归档成员(否则其中的 GUI 子系统
  // pragma 不会被处理);返回值恒 42,分支永不成立
  if ffi_win_gui_marker() < 0 {
    return false
  }
  let ok = ffi_app_init()
  if ok {
    theme_apply(theme_from_system())
  }
  ok
}

///|
/// 进入平台消息循环，阻塞至 quit() 被调用。
pub fn run() -> Unit {
  ffi_run()
}

///|
/// 请求退出消息循环（线程安全性与平台相关，仅建议在主线程回调中调用）。
pub fn quit() -> Unit {
  ffi_quit()
}

///|
/// 当前运行平台。库内部分支用；消费方正常情况下不应需要它。
pub fn platform() -> String {
  match ffi_platform() {
    0 => "linux"
    1 => "macos"
    2 => "windows"
    _ => "unknown"
  }
}

///|
/// 向主循环投递一个立即任务（跨线程安全性见 libyue；GUI 回调内常用）。
pub fn post_task(task : () -> Unit) -> Unit {
  keep_alive(task)
  ffi_post_task(fn(f) { f() }, task)
}

///|
/// 延迟 ms 毫秒执行一次。
pub fn post_delayed_task(ms : Int, task : () -> Unit) -> Unit {
  keep_alive(task)
  ffi_post_delayed_task(ms, fn(f) { f() }, task)
}

///|
/// ms 毫秒后执行一次，返回可用于取消的 id。
pub fn set_timeout(ms : Int, task : () -> Unit) -> Int {
  keep_alive(task)
  ffi_set_timeout(ms, fn(f) { f() }, task)
}

///|
/// 周期定时器：回调返回 true 继续，false 自动停止（libyue 定时器无取消 id）。
pub fn set_timer(ms : Int, task : () -> Bool) -> Unit {
  let wrapped : () -> Int = fn() { if task() { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_set_timer(ms, fn(f) { f() }, wrapped)
}

///|
/// 取消 set_timeout/set_timer 设置的任务。
pub fn clear_timeout(id : Int) -> Unit {
  ffi_clear_timeout(id)
}

///|
/// 系统是否偏好深色(Linux 读 GtkSettings 的深色开关与主题名;其余
/// 平台当前恒 false,联动接入待补)。适合 initialize 后决定初始主题:
/// `theme_apply(if system_prefers_dark() { dark_theme() } else { default_theme() })`。
pub fn system_prefers_dark() -> Bool {
  ffi_system_prefers_dark() == 1
}

///|
/// 系统主色调(强调色):ARGB hex(如 "#ff009688");系统无主色概念或
/// 取不到时返回空串。仅主线程 GUI 初始化后可用。
/// (Linux 三级递进:GNOME 47+ 的 accent-color 设置 → 当前 GTK 主题
/// CSS 的 theme_selected_bg_color → 空;Windows 取注册表用户强调色
/// (DWM\AccentColor),缺失回退 DWM 颜色化色;macOS 取 controlAccentColor。
/// 读取路径与实测值见 adaptation.md。)
pub fn system_accent() -> String {
  let v = ffi_system_accent()
  if v == 0 {
    ""
  } else {
    argb_hex((v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255)
  }
}

///|
/// 系统深浅偏好变化通知(Linux 监听 GtkSettings;其余平台当前不触发)。
/// 回调时机:系统切换深/浅色或更换主题名时;重复注册安全,已有监听时
/// 后注册者立即收到一次回调。配合 system_prefers_dark 在回调里重读,
/// 即可实时跟随系统。
pub fn on_system_theme_change(f : () -> Unit) -> Unit {
  keep_alive(f)
  ffi_on_system_theme_change(fn(g : () -> Unit) -> Unit { g() }, f)
}
