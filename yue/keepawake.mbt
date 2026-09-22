// 屏幕常亮:跨平台统一。Linux 经抑制服务 Inhibit/UnInhibit(带原 cookie),
// Windows 经 SetThreadExecutionState(ES_DISPLAY_REQUIRED,解除还原)。
// enable 的 Ok 只表示系统已受理;到达息屏时间是否真不熄屏由平台策略决定。

///|
/// 屏幕常亮句柄:持有期间保持常亮,release 解除。
pub struct KeepAwake {
  app_id : String
}

///|
/// 当前是否有活动的常亮(任何一次 enable 后、release 前)。
pub fn keep_awake_active() -> Bool {
  g_keep_awake_held.val
}

///|
let g_keep_awake_held : Ref[Bool] = Ref(false)

///|
/// 屏幕常亮是否可用:macOS 暂缓;Linux 看抑制服务是否真实在线(以
/// NameHasOwner 为准,GNOME/KDE 未装屏保服务时不可用);Windows 恒可用。
pub fn KeepAwake::is_supported() -> Bool {
  match platform() {
    "linux" => @traybus.inhibit_available()
    "windows" => true
    _ => false
  }
}

///|
/// 启用屏幕常亮。app_id 用于抑制服务的身份标识(同一 app_id 可重复
/// enable,覆盖语义由服务端决定)。
pub fn KeepAwake::enable(app_id : String) -> Result[KeepAwake, KeepAwakeError] {
  match platform() {
    "linux" => {
      if !@traybus.inhibit_available() {
        return Err(Unsupported)
      }
      match @traybus.inhibit(app_id, "keep display on") {
        Ok(_) => {
          g_keep_awake_held.val = true
          Ok({ app_id, })
        }
        Err(_) => Err(Failed)
      }
    }
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_win_keep_awake_enable(ok)
      if ok.val == 1 {
        g_keep_awake_held.val = true
        Ok({ app_id, })
      } else {
        Err(Failed)
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// 解除常亮。幂等:未持有也是成功。抑制状态(服务+cookie)全局持有,
/// release 不读句柄字段。
pub fn KeepAwake::release(_self : KeepAwake) -> Result[Unit, KeepAwakeError] {
  match platform() {
    "linux" =>
      match @traybus.unInhibit() {
        Ok(_) => {
          g_keep_awake_held.val = false
          Ok(())
        }
        Err(_) => Err(Failed)
      }
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_win_keep_awake_restore(ok)
      if ok.val == 1 {
        g_keep_awake_held.val = false
        Ok(())
      } else {
        Err(Failed)
      }
    }
    _ => Err(Unsupported)
  }
}
