// 关机/重启/注销：统一走 logind（系统总线 org.freedesktop.login1）的
// PowerOff / Reboot 与会话终断。CanPowerOff / CanReboot 可查询当前环境
// 是否允许（Vagrant/容器/权限不足时返回 false 或错误），关机类动作需要
// polkit 授权（交互式桌面由 auth agent 弹框）。底层复用 @traybus 的
// 通用 D-Bus 层（gdbus_call_system）。
//
// 典型用法：
//   if pwrc_can_power_off() {
//     let _ = pwrc_power_off() // 真机执行：会弹 polkit 授权并关机
//   } else {
//     let _ = pwrc_logout_self() // 没有关机权限，只退出自己
//   }
//   for s in pwrc_sessions() { ... } // 登录会话列表（id/user/seat）

///|
let pwrc_logind : String = "org.freedesktop.login1"

///|
let pwrc_manager : String = "/org/freedesktop/login1"

///|
let pwrc_iface_manager : String = "org.freedesktop.login1.Manager"

///|
let pwrc_iface_session : String = "org.freedesktop.login1.Session"

///|
/// 一个登录会话：id 为会话号（如 "2"/"c2"），user 为用户名，uid 为
/// 用户 id，seat 为座位号（本地为 "seat0"，远程/无 seat 的会话为空串）。
pub(all) struct SessionInfo {
  id : String
  uid : Int
  user : String
  seat : String
  path : String
}

///|
pub impl Show for SessionInfo with fn output(self, logger) {
  logger.write_string("SessionInfo { id: ")
  logger.write_string(self.id)
  logger.write_string(", uid: ")
  logger.write_string(self.uid.to_string())
  logger.write_string(", user: ")
  logger.write_string(self.user)
  logger.write_string(", seat: ")
  if self.seat == "" {
    logger.write_string("(remote)")
  } else {
    logger.write_string(self.seat)
  }
  logger.write_string(", path: ")
  logger.write_string(self.path)
  logger.write_string(" }")
}

///|
pub extend SessionInfo with Show::{to_string, output}

///|
pub(all) enum PwrcError {
  /// 平台不支持（非 Linux）；logind 不在线/总线不可达也归入此类
  Unsupported
  /// 当前环境不允许此动作（Can* 返回 no/na；polkit 授权被拒），带说明
  NotAllowed(String)
  /// D-Bus 调用失败（logind 拒绝/应答超时等），带错误名与说明
  BusFailed(String)
}

///|
pub impl Show for PwrcError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("PwrcError::Unsupported")
    NotAllowed(m) => logger.write_string("PwrcError::NotAllowed(\{m})")
    BusFailed(m) => logger.write_string("PwrcError::BusFailed(\{m})")
  }
}

///|
pub extend PwrcError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：ListSessions 应答解析 / Can* 结果归一 / 会话路径构造
// ---------------------------------------------------------------------------

///|
/// logind ListSessions 应答（a(susso)） → 会话快照列表；形状不符或参数
/// 不够的片段安全跳过，总返回合法子集。
fn pwrc_sessions_of(v : @traybus.GDBusValue) -> Array[SessionInfo] {
  let out : Array[SessionInfo] = []
  match v {
    @traybus.GVArray(_, items) =>
      for it in items {
        match it {
          @traybus.GVStruct([id, uid, user, seat, path]) =>
            match (pwrc_text(id), pwrc_int(uid), pwrc_text(user)) {
              (Some(sid), u, Some(suser)) => {
                let sseat = match pwrc_text(seat) {
                  Some(s) => s
                  None => ""
                }
                let spath = match pwrc_text(path) {
                  Some(p) => p
                  None => ""
                }
                out.push({
                  id: sid,
                  uid: u,
                  user: suser,
                  seat: sseat,
                  path: spath,
                })
              }
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  out
}

///|
/// 字符串型 D-Bus 值 → String（GVString / GVPath；GVNone 等其它形状为
/// None）。
fn pwrc_text(v : @traybus.GDBusValue) -> String? {
  match v {
    @traybus.GVString(s) => Some(s)
    @traybus.GVPath(s) => Some(s)
    _ => None
  }
}

///|
/// 整数型 D-Bus 值 → Int（GVU32 / GVInt32 / GVInt64；其余为 0）。
fn pwrc_int(v : @traybus.GDBusValue) -> Int {
  match v {
    @traybus.GVUInt32(n) => n
    @traybus.GVInt32(n) => n
    @traybus.GVInt64(n) => n.to_int()
    _ => 0
  }
}

///|
/// Can* 结果字符串归一："yes"/"challenge" 为允许（challenge = 需交互
/// 授权），"no"/"na"/空串 为不允许，其它值按不允许处理。
fn pwrc_can_parse(result : String) -> Bool {
  result == "yes" || result == "challenge"
}

///|
/// D-Bus 错误名与说明 → PwrcError：logind 服务不在线/总线不可达映射为
/// Unsupported，其余（拒绝/超时/编码失败）为 BusFailed。入参拆成两项而非
/// 收 GDBusError 记录——映射是纯函数，白盒可直接喂样例。
fn pwrc_bus_err(name : String, message : String) -> PwrcError {
  if name == "org.freedesktop.DBus.Error.ServiceUnknown" || name == "gdbus.io" {
    Unsupported
  } else {
    BusFailed("\{name}: \{message}")
  }
}

///|
/// 会话级动作（Terminate）的错误名与说明 → PwrcError：无此会话给
/// Unsupported（会话已消失也算"做不了"），其余同 [pwrc_bus_err]。
fn pwrc_session_err(name : String, message : String) -> PwrcError {
  match name {
    "org.freedesktop.systemd1.NoSuchSession"
    | "org.freedesktop.login1.NoSuchSession" => Unsupported
    _ => pwrc_bus_err(name, message)
  }
}

// ---------------------------------------------------------------------------
// D-Bus 调用（真实查询/动作；wbtest 不连总线）
// ---------------------------------------------------------------------------

///|
/// 关机/重启动作的错误名与说明 → PwrcError：polkit 授权被拒 / 环境不允许
/// 给 NotAllowed，其余同 [pwrc_bus_err]。
fn pwrc_action_err(name : String, message : String) -> PwrcError {
  match name {
    "org.freedesktop.DBus.Error.AccessDenied"
    | "org.freedesktop.DBus.Error.NotSupported"
    | "org.freedesktop.systemd1.NotSupported" => NotAllowed(message)
    _ => pwrc_bus_err(name, message)
  }
}

///|
/// logind Manager 上的无参方法调用（ListSessions/PowerOff/Reboot 等）。
fn pwrc_manager_call(action : String) -> Result[@traybus.GDBusValue, PwrcError] {
  match
    @traybus.gdbus_call_system(
      pwrc_logind,
      pwrc_manager,
      pwrc_iface_manager,
      action,
      [],
    ) {
    Ok(v) => Ok(v)
    Err(e) => Err(pwrc_bus_err(e.name, e.message))
  }
}

///|
/// 会话对象上的无参方法调用（Terminate 等）。
fn pwrc_session_call(
  session_path : String,
  action : String,
) -> Result[Unit, PwrcError] {
  match
    @traybus.gdbus_call_system(
      pwrc_logind,
      session_path,
      pwrc_iface_session,
      action,
      [],
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(pwrc_session_err(e.name, e.message))
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持电源控制（Linux 且 logind 在线）。每次调用真实探测，
/// 高频场景请调用方自行缓存结果。
pub fn pwrc_supported() -> Bool {
  if platform() != "linux" {
    return false
  }
  match
    @traybus.gdbus_call_system(
      pwrc_logind,
      pwrc_manager,
      pwrc_iface_manager,
      "CanPowerOff",
      [],
    ) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// 枚举登录会话（会话号/用户名/uid/座位/对象路径）；logind 不在线时返回
/// Unsupported。本机桌面会话通常形如 seat0 上的 c2/c3（c 前缀为图形
/// 会话序号）。
pub fn pwrc_sessions() -> Result[Array[SessionInfo], PwrcError] {
  match pwrc_manager_call("ListSessions") {
    Err(e) => Err(e)
    Ok(v) => Ok(pwrc_sessions_of(v))
  }
}

///|
/// 查询当前环境是否允许关机（Can* 结果为 yes/challenge 为允许）。logind
/// 不在线时返回 Unsupported；其它查询失败为 BusFailed。
pub fn pwrc_can_power_off() -> Result[Bool, PwrcError] {
  match pwrc_manager_call("CanPowerOff") {
    Err(e) => Err(e)
    Ok(@traybus.GVString(s)) => Ok(pwrc_can_parse(s))
    Ok(_) => Err(BusFailed("CanPowerOff 应答形状不符"))
  }
}

///|
/// 查询当前环境是否允许重启（CanReboot）。语义同 [pwrc_can_power_off]。
pub fn pwrc_can_reboot() -> Result[Bool, PwrcError] {
  match pwrc_manager_call("CanReboot") {
    Err(e) => Err(e)
    Ok(@traybus.GVString(s)) => Ok(pwrc_can_parse(s))
    Ok(_) => Err(BusFailed("CanReboot 应答形状不符"))
  }
}

///|
/// 关机（logind PowerOff，interactive=true 允许 polkit 交互授权）。
/// 需要 polkit 授权；环境不允许时返回 NotAllowed。
pub fn pwrc_power_off() -> Result[Unit, PwrcError] {
  match
    @traybus.gdbus_call_system(
      pwrc_logind,
      pwrc_manager,
      pwrc_iface_manager,
      "PowerOff",
      [@traybus.GVBool(true)],
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(pwrc_action_err(e.name, e.message))
  }
}

///|
/// 重启（logind Reboot，interactive=true 允许 polkit 交互授权）。
/// 需要 polkit 授权；环境不允许时返回 NotAllowed。
pub fn pwrc_reboot() -> Result[Unit, PwrcError] {
  match
    @traybus.gdbus_call_system(
      pwrc_logind,
      pwrc_manager,
      pwrc_iface_manager,
      "Reboot",
      [@traybus.GVBool(true)],
    ) {
    Ok(_) => Ok(())
    Err(e) => Err(pwrc_action_err(e.name, e.message))
  }
}

///|
/// 注销指定会话（logind 会话对象的 Terminate；传入 [pwrc_sessions] 枚举
/// 所得的会话）。仅终止该会话自身，不影响其它用户。
pub fn pwrc_logout(session : SessionInfo) -> Result[Unit, PwrcError] {
  if session.path == "" {
    return Err(BusFailed("会话对象路径为空"))
  }
  pwrc_session_call(session.path, "Terminate")
}

///|
/// 注销当前会话：取第一个非空 seat 的会话（多会话时只退本座位的首个）。
/// 无任何会话时返回 Unsupported。
pub fn pwrc_logout_self() -> Result[Unit, PwrcError] {
  match pwrc_sessions() {
    Err(e) => Err(e)
    Ok(sessions) => {
      let picked : SessionInfo? = for s in sessions {
        if s.seat != "" {
          break Some(s)
        }
      } nobreak {
        if sessions.length() > 0 {
          Some(sessions[0])
        } else {
          None
        }
      }
      match picked {
        Some(s) => pwrc_logout(s)
        None => Err(Unsupported)
      }
    }
  }
}
