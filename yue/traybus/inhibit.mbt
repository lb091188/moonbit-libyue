// 屏幕抑制服务(ScreenSaver Inhibit):候选表按 NameHasOwner 真实在线
// 选定——标准名 org.freedesktop.ScreenSaver 之外,XFCE 用 org.xfce.ScreenSaver
// (xfce4-screensaver),以真实在线为准,不按环境名猜。对象路径与接口名
// 由服务名派生(点换斜杠),两家的 Inhibit("ss")->u / UnInhibit("u") 同构。

///|
/// 抑制服务候选表:标准名在前,桌面实测名在后(随真机实测扩充)。
let inhibit_candidates : Array[String] = [
  "org.freedesktop.ScreenSaver",
  "org.xfce.ScreenSaver",
]

///|
/// 选定的抑制服务(UnInhibit 须回同一服务)。
let g_inhibit_service : Ref[String?] = Ref(None)

///|
/// 活动抑制的 cookie(申请时记下,解除时带上)。
let g_inhibit_cookie : Ref[Int?] = Ref(None)

///|
/// 服务名 → 对象路径:org.xfce.ScreenSaver → /org/xfce/ScreenSaver。
fn inhibit_path(service : String) -> String {
  let sb = StringBuilder()
  sb.write_char('/')
  let mut i = 0
  while i < service.length() {
    let c = service.unsafe_get(i).to_int()
    if c == 46 { // '.':点换斜杠
      sb.write_char('/')
    } else {
      sb.write_char(c.unsafe_to_char())
    }
    i += 1
  }
  sb.to_string()
}

///|
/// 是否有抑制服务在线(已选定则不再探测)。
pub fn inhibit_available() -> Bool {
  match g_inhibit_service.val {
    Some(_) => true
    None => probe_inhibit_service()
  }
}

///|
/// 当前是否持有活动抑制。
pub fn inhibit_active() -> Bool {
  g_inhibit_cookie.val is Some(_)
}

fn probe_inhibit_service() -> Bool {
  match bus_conn() {
    Err(_) => false
    Ok(c) => {
      for name in inhibit_candidates {
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
                g_inhibit_service.val = Some(name)
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
/// 申请屏幕抑制,返回 cookie(解除时须带原值)。幂等语义由调用方
/// (KeepAwake)持有。
pub fn inhibit(app_name : String, reason : String) -> Result[Int, String] {
  let service = match g_inhibit_service.val {
    Some(s) => s
    None =>
      if probe_inhibit_service() {
        match g_inhibit_service.val {
          Some(s) => s
          None => return Err("无抑制服务在线")
        }
      } else {
        return Err("无抑制服务在线")
      }
  }
  match bus_conn() {
    Err(e) => Err(e)
    Ok(c) =>
      match c.call_sync(
          service,
          inhibit_path(service),
          service,
          "Inhibit",
          "ss",
          [VString(app_name), VString(reason)],
        ) {
        Ok(m) =>
          match m.body.get(0) {
            Some(VU32(cookie)) => {
              g_inhibit_cookie.val = Some(cookie)
              Ok(cookie)
            }
            _ => Err("Inhibit 应答缺少 cookie")
          }
        Err(e) => Err(e)
      }
  }
}

///|
/// 解除抑制(带原 cookie)。本就未持有视为成功。
pub fn unInhibit() -> Result[Unit, String] {
  let cookie = match g_inhibit_cookie.val {
    Some(c) => c
    None => return Ok(())
  }
  let service = match g_inhibit_service.val {
    Some(s) => s
    None => return Err("抑制服务未选定")
  }
  match bus_conn() {
    Err(e) => Err(e)
    Ok(c) =>
      match c.call_sync(
          service,
          inhibit_path(service),
          service,
          "UnInhibit",
          "u",
          [VU32(cookie)],
        ) {
        Ok(_) => {
          g_inhibit_cookie.val = None
          Ok(())
        }
        Err(e) => Err(e)
      }
  }
}
