// 锁屏与解锁事件。信号源按真实在线叠加订阅:logind Session 的
// Lock/Unlock(系统总线,GNOME/KDE 等锁屏器走此路)+ 桌面屏保服务的
// ActiveChanged(会话总线,XFCE 的 xfce4-screensaver 锁屏不通知
// logind);多源同报一个状态,经状态机去重后派发;macOS 暂缓。

///|
/// 锁屏/解锁事件。
pub enum SessionLockEvent {
  /// 已锁屏
  Locked
  /// 已解锁
  Unlocked
}

///|
pub impl Show for SessionLockEvent with fn output(self, logger) {
  match self {
    Locked => logger.write_string("SessionLockEvent::Locked")
    Unlocked => logger.write_string("SessionLockEvent::Unlocked")
  }
}

///|
pub extend SessionLockEvent with Show::{to_string, output}

///|
let g_lock_cbs : Array[(SessionLockEvent) -> Unit] = []

///|
/// 当前锁定态(None=未知):多源同报时只在状态真正翻转时派发。
let g_lock_state : Ref[Bool?] = Ref(None)

///|
fn lock_transition(locked : Bool) -> Unit {
  match g_lock_state.val {
    Some(same) => if same == locked { return }
    None => ()
  }
  g_lock_state.val = Some(locked)
  let evt = if locked { Locked } else { Unlocked }
  for cb in g_lock_cbs {
    cb(evt)
  }
}

///|
/// 锁屏/解锁事件是否可用(至少一个信号源在线;锁屏工具不调 logind
/// 也不发屏保信号的桌面收不到事件,见 adaptation.md)。
pub fn session_lock_supported() -> Bool {
  match platform() {
    "linux" => @traybus.logind_available() || @traybus.screensaver_available()
    "windows" => true
    _ => false
  }
}

///|
/// 注册锁屏/解锁回调。失败给结构化错误(无任何信号源在线 / 总线连
/// 不上),不静默——调用方按需提示。可多次注册。
pub fn session_lock_watch(
  cb : (SessionLockEvent) -> Unit,
) -> Result[Unit, SystemError] {
  match platform() {
    "linux" => {
      let registered = Ref(false)
      if @traybus.logind_available() {
        match @traybus.logind_on_lock(fn(locked) { lock_transition(locked) }) {
          Ok(_) => registered.val = true
          Err(e) => return Err(Message(e))
        }
      }
      if @traybus.screensaver_available() {
        match @traybus.screensaver_on_active(fn(active) {
          lock_transition(active)
        }) {
          Ok(_) => registered.val = true
          Err(e) => return Err(Message(e))
        }
      }
      if !registered.val {
        return Err(Unsupported)
      }
      g_lock_cbs.push(cb)
      Ok(())
    }
    "windows" => {
      // evt 码 2=锁屏 3=解锁(电源窗口分发,与休眠共用单点登记)
      g_win_lock_cbs.push(fn(evt) { cb(if evt == 2 { Locked } else { Unlocked }) })
      win_watch_once()
      Ok(())
    }
    _ => Err(Unsupported)
  }
}
