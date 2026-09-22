// logind(系统总线):休眠唤醒(PrepareForSleep)与锁屏解锁(Session 的
// Lock/Unlock)。锁屏信号由各会话对象发出,订阅按接口+成员匹配(所有
// 会话都收);锁屏工具不调 logind 的桌面(如某些第三方锁屏器)收不到,
// 以 NameHasOwner 判 logind 在线为准。

///|
const LOGIND : String = "org.freedesktop.login1"

///|
/// logind 是否在线(系统总线 NameHasOwner 真实探测)。
pub fn logind_available() -> Bool {
  match system_conn() {
    Err(_) => false
    Ok(c) =>
      match c.call_sync(
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "NameHasOwner",
          "s",
          [VString(LOGIND)],
        ) {
        Ok(m) =>
          match m.body.get(0) {
            Some(VBool(true)) => true
            _ => false
          }
        Err(_) => false
      }
  }
}

///|
let g_on_sleep : Array[(Bool) -> Unit] = []

///|
let g_sleep_watched : Ref[Bool] = Ref(false)

///|
/// 注册休眠唤醒回调(参数 true = 即将休眠,false = 已唤醒)。连接与
/// 订阅幂等建;信号体就一个布尔,回调内直解、不重查(分发在 drain 栈上)。
pub fn logind_on_sleep(cb : (Bool) -> Unit) -> Result[Unit, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  if !g_sleep_watched.val {
    g_sleep_watched.val = true
    c.subscribe(
      "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'",
      "org.freedesktop.login1.Manager.PrepareForSleep",
      fn(m) {
        match m.body.get(0) {
          Some(VBool(start)) =>
            for cb2 in g_on_sleep {
              cb2(start)
            }
          _ => ()
        }
      },
    )
  }
  g_on_sleep.push(cb)
  Ok(())
}

///|
let g_on_lock : Array[(Bool) -> Unit] = []

///|
let g_lock_watched : Ref[Bool] = Ref(false)

///|
/// 注册锁屏解锁回调(参数 true = 已锁屏,false = 已解锁)。
pub fn logind_on_lock(cb : (Bool) -> Unit) -> Result[Unit, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  if !g_lock_watched.val {
    g_lock_watched.val = true
    // Lock/Unlock 各一条规则(信号体为空,按成员区分)
    c.subscribe(
      "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Session',member='Lock'",
      "org.freedesktop.login1.Session.Lock",
      fn(_m) {
        for cb2 in g_on_lock {
          cb2(true)
        }
      },
    )
    c.subscribe(
      "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Session',member='Unlock'",
      "org.freedesktop.login1.Session.Unlock",
      fn(_m) {
        for cb2 in g_on_lock {
          cb2(false)
        }
      },
    )
  }
  g_on_lock.push(cb)
  Ok(())
}
