// 桌面屏保服务(会话总线)的锁屏信号源:XFCE 实测锁屏走
// xfce4-screensaver 而不通知 logind(logind Lock/Unlock 收不到),
// 它的 ActiveChanged(b) 是唯一可订阅的锁屏事件;org.freedesktop
// .ScreenSaver 是 GNOME/KDE 侧兼容名,信号同构,按真实在线选定。

///|
let saver_candidates : Array[String] = [
  "org.xfce.ScreenSaver",
  "org.freedesktop.ScreenSaver",
]

///|
/// 选定的屏保信号源(ActiveChanged 订阅与探测同服务)。
let g_saver_service : Ref[String?] = Ref(None)

///|
let g_saver_watched : Ref[Bool] = Ref(false)

///|
let g_saver_cbs : Array[(Bool) -> Unit] = []

///|
/// 有屏保锁屏信号源在线(已选定则不再探测)。
pub fn screensaver_available() -> Bool {
  match g_saver_service.val {
    Some(_) => true
    None => probe_saver_service()
  }
}

///|
fn probe_saver_service() -> Bool {
  match bus_conn() {
    Err(_) => false
    Ok(c) => {
      for name in saver_candidates {
        match c.call_sync(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "NameHasOwner",
            "s",
            [VString(name)],
          ) {
          Ok(m) =>
            match m.body.get(0) {
              Some(VBool(true)) => {
                g_saver_service.val = Some(name)
                return true
              }
              _ => ()
            }
          Err(_) => ()
        }
      }
      false
    }
  }
}

///|
/// 订阅锁屏状态变化(参数 true = 已锁屏)。订阅幂等,回调可多次注册;
/// 信号体单布尔,回调内直解不重查(分发在 drain 栈上)。
pub fn screensaver_on_active(cb : (Bool) -> Unit) -> Result[Unit, String] {
  if !screensaver_available() {
    return Err("无屏保锁屏信号源在线")
  }
  let svc = match g_saver_service.val {
    Some(s) => s
    None => return Err("屏保信号源未选定")
  }
  let c = match bus_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  if !g_saver_watched.val {
    g_saver_watched.val = true
    c.subscribe(
      "type='signal',sender='\{svc}',interface='\{svc}',member='ActiveChanged'",
      "\{svc}.ActiveChanged",
      fn(m) {
        match m.body.get(0) {
          Some(VBool(active)) =>
            for cb2 in g_saver_cbs {
              cb2(active)
            }
          _ => ()
        }
      },
    )
  }
  g_saver_cbs.push(cb)
  Ok(())
}
