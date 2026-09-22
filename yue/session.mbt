// 锁屏与解锁事件。Linux 走 logind Session 的 Lock/Unlock 信号(系统
// 总线);Windows 走 WTS 会话变更通知(经电源消息窗口,与休眠共用
// 分发表);macOS 暂缓。

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
/// 锁屏/解锁事件是否可用。Linux 看 logind 是否在线(锁屏工具不调
/// logind 的桌面收不到信号,见 adaptation.md);Windows 恒可用。
pub fn session_lock_supported() -> Bool {
  match platform() {
    "linux" => @traybus.logind_available()
    "windows" => true
    _ => false
  }
}

///|
/// 注册锁屏/解锁回调。失败给结构化错误(logind 不在线 / 总线连不上),
/// 不静默——调用方按需提示。可多次注册。
pub fn session_lock_watch(
  cb : (SessionLockEvent) -> Unit,
) -> Result[Unit, SystemError] {
  match platform() {
    "linux" => {
      if !@traybus.logind_available() {
        return Err(Unsupported)
      }
      match @traybus.logind_on_lock(fn(locked) {
        cb(if locked { Locked } else { Unlocked })
      }) {
        Ok(_) => Ok(())
        Err(e) => Err(Message(e))
      }
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
