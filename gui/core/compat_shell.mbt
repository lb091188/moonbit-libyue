// G9 Batch 2 过渡兼容层（二）：系统能力壳层（menu/hotkey/tray/notify/reveal）
// 已出成 `shell` 子包，本文件把原先住在 core 的公开类型别名与顶层函数转发一层，
// `@core.*` 调用点在迁移期不改写；新代码请直接 `import "NoahLiu/native-gui/shell"`。
// 全量替换完成后整文件删除（TODO §1 G9）。

///|
pub type Menu = @shell.Menu
pub type MenuBar = @shell.MenuBar
pub type MenuItem = @shell.MenuItem
pub type MenuRole = @shell.MenuRole
pub type MenuItemKind = @shell.MenuItemKind

///|
pub type Hotkey = @shell.Hotkey
pub type HotkeyError = @shell.HotkeyError

///|
pub type Tray = @shell.Tray
pub type TrayBackend = @shell.TrayBackend
pub type TrayError = @shell.TrayError

///|
pub type NotifyBackend = @shell.NotifyBackend
pub type NotifyError = @shell.NotifyError
pub type NotifyCaps = @shell.NotifyCaps

///|
pub fn dispatch_menu_command() -> Bool {
  @shell.dispatch_menu_command()
}

///|
pub fn dispatch_tray_event() -> Bool {
  @shell.dispatch_tray_event()
}

///|
pub fn menu_role_id(role : MenuRole) -> Int {
  @shell.menu_role_id(role)
}

///|
pub fn hotkey_supported() -> Bool {
  @shell.hotkey_supported()
}

///|
pub fn hotkey_register(spec : String) -> Result[Hotkey, HotkeyError] {
  @shell.hotkey_register(spec)
}

///|
pub fn hotkey_unregister(hk : Hotkey) -> Result[Unit, HotkeyError] {
  @shell.hotkey_unregister(hk)
}

///|
pub fn hotkey_poll() -> Hotkey? {
  @shell.hotkey_poll()
}

///|
pub fn hotkey_registered_count() -> Int {
  @shell.hotkey_registered_count()
}

///|
pub fn notify_supported() -> Bool {
  @shell.notify_supported()
}

///|
pub fn notify_send(
  app_name : String,
  summary : String,
  body : String,
  icon? : String = "",
  timeout_ms? : Int = -1,
  replaces_id? : Int = 0,
  progress? : Int = -1,
  kind? : Int = 0,
  icon_handle? : Int = 0,
) -> Result[Int, NotifyError] {
  @shell.notify_send(
    app_name,
    summary,
    body,
    icon=icon,
    timeout_ms=timeout_ms,
    replaces_id=replaces_id,
    progress=progress,
    kind=kind,
    icon_handle=icon_handle,
  )
}

///|
pub fn reveal_in_file_manager(path : String) -> Result[Unit, @sys.FileManagerError] {
  @shell.reveal_in_file_manager(path)
}

///|
pub type Loop = @shell.Loop
pub type Job = @shell.Job

///|
pub fn set_timer_hooks(
  schedule : (Int, () -> Unit) -> Int,
  cancel : (Int) -> Unit,
) -> Unit {
  @shell.set_timer_hooks(schedule, cancel)
}

///|
pub fn set_timeout(ms : Int, f : () -> Unit) -> Int {
  @shell.set_timeout(ms, f)
}

///|
pub fn clear_timeout(id : Int) -> Unit {
  @shell.clear_timeout(id)
}

///|
pub fn now_ms() -> Int64 { @shell.now_ms() }

///|
pub fn sys_color_scheme() -> String {
  @shell.sys_color_scheme()
}

///|
pub fn sys_accent() -> String {
  @shell.sys_accent()
}

///|
pub fn local_ymd() -> (Int, Int, Int) {
  @shell.local_ymd()
}

///|
pub type Session = @shell.Session

///|
pub fn host_loop() -> @shell.Loop { @shell.host_loop() }
pub fn host_new_wid() -> Int { @shell.host_new_wid() }
pub fn host_window_count() -> Int { @shell.host_window_count() }
pub fn host_close_action(primary : Bool, remaining : Int) -> Bool {
  @shell.host_close_action(primary, remaining)
}
pub fn host_add_session(s : Session) -> Unit { @shell.host_add(s) }
pub fn host_deregister(s : Session) -> Unit { @shell.host_deregister(s) }
pub fn host_mark_active(s : Session) -> Unit { @shell.host_mark_active(s) }
pub fn shell_sessions() -> Array[Session] { @shell.host_windows() }
pub fn session_active() -> Session? { @shell.session_active() }
