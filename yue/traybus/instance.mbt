// 应用专属总线名：单实例（防多开）与二次启动唤起。
// 复用 bus.mbt 的进程级会话连接；Wake 分发钩子由 bus.mbt 的 kind==1
// 分支插入——今天入站调用一律进 handle_call，Wake 会落进 UnknownMethod
// 兜底，首实例永远收不到二次唤起。

///|
/// RequestName 的 flags：DO_NOT_QUEUE。第二实例必须立即拿到 EXISTS 回复，
/// 默认 flags=0 会让它排队挂到首实例退出为止。
pub const FLAG_DO_NOT_QUEUE : Int = 4

///|
/// RequestName 回复码（org.freedesktop.DBus.RequestNameReply）的语义化结果。
pub enum NameClaim {
  /// 1：本连接新取得名字——首实例
  PrimaryOwner
  /// 2：进入等待队列（DO_NOT_QUEUE 下不会出现）
  InQueue
  /// 3：其他连接持有——已有实例，应唤醒后退出
  AlreadyExists
  /// 4：本连接已持有——幂等，视为首实例
  AlreadyOwner
}

///|
/// 回复码 → 语义。纯函数，wbtest 覆盖。
pub fn name_claim_of(code : Int) -> NameClaim? {
  match code {
    1 => Some(PrimaryOwner)
    2 => Some(InQueue)
    3 => Some(AlreadyExists)
    4 => Some(AlreadyOwner)
    _ => None
  }
}

///|
/// 单实例对象的固定对象路径（Wake 方法调用目的地）。
pub fn instance_path() -> String {
  "/org/moonbitlibyue/Instance"
}

///|
/// 单实例接口名。
pub fn instance_iface() -> String {
  "org.moonbitlibyue.Instance"
}

///|
/// 唤起方法名：首实例接收，参数 'as' 为第二实例命令行。
pub fn wake_member() -> String {
  "Wake"
}

///|
/// app_id 合法性（DBus 知名名规则）：≥2 个点分元素；每元素以字母或
/// 下划线开头，只含 [A-Za-z0-9_-]；总长 ≤255。合法则原样作为总线名
/// （反向域名约定，如 com.example.app）。
pub fn valid_app_id(app_id : String) -> Bool {
  if app_id.length() == 0 || app_id.length() > 255 {
    return false
  }
  let mut dots = 0
  let mut elem_start = true
  let mut i = 0
  while i < app_id.length() {
    let c = app_id.unsafe_get(i)
    if c == '.' {
      if elem_start {
        return false // 空前元素（打头/连续/收尾的点）
      }
      dots += 1
      elem_start = true
    } else {
      let body_ok = (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '_' ||
        c == '-'
      if !body_ok {
        return false
      }
      if elem_start {
        let head_ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
        if !head_ok {
          return false // 元素不能以数字或 '-' 开头
        }
        elem_start = false
      }
    }
    i += 1
  }
  dots >= 1 && !elem_start
}

///|
/// 取进程级会话连接（没有则现连）。
fn bus_conn() -> Result[Conn, String] {
  match g_conn.val {
    Some(c) =>
      if c.alive {
        Ok(c)
      } else {
        Err("会话总线连接已断开")
      }
    None =>
      match connect_session() {
        Ok(c) => {
          g_conn.val = Some(c)
          Ok(c)
        }
        Err(e) => Err(e)
      }
  }
}

///|
/// 声称应用专属总线名。Err 为 app_id 非法 / 连接失败 / 应答异常 /
/// 未知回复码。
pub fn claim_name(app_id : String) -> Result[NameClaim, String] {
  if !valid_app_id(app_id) {
    return Err("非法 app_id: \{app_id}")
  }
  match bus_conn() {
    Err(e) => Err(e)
    Ok(c) =>
      match
        c.call_sync(
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "RequestName",
          "su",
          [VString(app_id), VU32(FLAG_DO_NOT_QUEUE)],
        ) {
        Ok(m) =>
          match m.body.get(0) {
            Some(VU32(code)) =>
              match name_claim_of(code) {
                Some(claim) => Ok(claim)
                None => Err("RequestName 未知回复码: \{code}")
              }
            _ => Err("RequestName 应答缺少 uint32 出参")
          }
        Err(e) => Err(e)
      }
  }
}

///|
/// 第二实例：向首实例发 Wake('as' 命令行参数)。Ok 表示首实例已应答。
pub fn wake_existing(app_id : String, args : Array[String]) -> Result[Unit, String] {
  if !valid_app_id(app_id) {
    return Err("非法 app_id: \{app_id}")
  }
  match bus_conn() {
    Err(e) => Err(e)
    Ok(c) => {
      let vals : Array[DVal] = []
      for a in args {
        vals.push(VString(a))
      }
      match
        c.call_sync(
          app_id,
          instance_path(),
          instance_iface(),
          wake_member(),
          "as",
          [VArray("s", vals)],
        ) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    }
  }
}

///|
/// 首实例的 Wake 处理器：第二实例命令行参数 → 回调。
let g_on_wake : Ref[((Array[String]) -> Unit)?] = Ref(None)

///|
/// 注册首实例唤起回调（每进程一次，后注册覆盖先注册）。
pub fn on_wake(cb : (Array[String]) -> Unit) -> Unit {
  g_on_wake.val = Some(cb)
}

///|
/// 入站调用是否是发往单实例对象的 Wake（bus.mbt 的 kind==1 分支用）。
fn is_wake_call(msg : Msg) -> Bool {
  msg.path == instance_path() &&
  msg.iface == instance_iface() &&
  msg.action == wake_member()
}

///|
/// 从 Wake 调用体取 'as' 参数（非字符串元素跳过）。
fn wake_args(msg : Msg) -> Array[String] {
  match msg.body.get(0) {
    Some(VArray(_, items)) => {
      let out : Array[String] = []
      for v in items {
        match dstr(v) {
          Some(s) => out.push(s)
          None => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
/// 触发 Wake 回调（bus.mbt 的 kind==1 分支调用；无注册时空转）。
fn fire_wake(msg : Msg) -> Unit {
  match g_on_wake.val {
    Some(cb) => cb(wake_args(msg))
    None => ()
  }
}
