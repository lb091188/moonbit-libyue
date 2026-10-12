// 桌面通知（`org.freedesktop.Notifications`）：发通知、按 id 关闭、进度文本。
// 进度不是独立方法——按规范用 `Notify` 带 `replaces_id` 重发同一张通知，
// 并在标准 hint `value`（INT32，0..100）里带百分比，桌面端据此画进度条
// （xfce4-notifyd / GNOME Shell 都认这个 hint）。
//
// 发通知会真的在桌面弹气泡，属于设置类：能力探测（[notify_caps]）无副作用，
// 发送/关闭由调用方在明确时机触发。

///|
pub(all) enum NotifyError {
  /// 会话总线或通知服务不可用
  NfUnsupported
  /// 调用失败（含 D-Bus 错误名与说明）
  NfFailed(String)
}

///|
pub impl Show for NotifyError with fn output(self, logger) {
  match self {
    NfUnsupported => logger.write_string("NotifyError::NfUnsupported")
    NfFailed(m) => logger.write_string("NotifyError::NfFailed(\{m})")
  }
}

///|
pub extend NotifyError with Show::{to_string, output}

///|
/// 通知服务能力（`GetCapabilities`）：常用几项的布尔视图 + 原始清单
/// （桌面端各自扩展的条目不翻译，原样留给调用方）。
pub(all) struct NotifyCaps {
  /// 支持 set_hint("body")
  body : Bool
  /// 支持 actions
  actions : Bool
  /// 支持静态图标
  icon_static : Bool
  /// 支持多帧/动画图标
  icon_multi : Bool
  /// 通知可跨会话保留（persistence）
  persistence : Bool
  /// 原始能力清单
  raw : Array[String]
}

///|
fn nf_dest() -> String { "org.freedesktop.Notifications" }

///|
fn nf_path() -> String { "/org/freedesktop/Notifications" }

///|
fn nf_iface() -> String { "org.freedesktop.Notifications" }

///|
/// 能力清单里是否含某条（原样比对）。
fn nf_has(caps : Array[String], item : String) -> Bool {
  caps.contains(item)
}

///|
/// 查通知服务能力（无副作用）。服务不在线给 [NfUnsupported]。
pub fn notify_caps() -> Result[NotifyCaps, NotifyError] {
  match
    gdbus_call_session(
      nf_dest(),
      nf_path(),
      nf_iface(),
      "GetCapabilities",
      [],
    ) {
    Err(e) =>
      if e.name.has_prefix("gdbus.io") {
        Err(NfUnsupported)
      } else {
        Err(NfFailed("\{e.name}: \{e.message}"))
      }
    Ok(GVArray(_, items)) => {
      let raw : Array[String] = []
      for v in items {
        match v {
          GVString(s) => raw.push(s)
          _ => ()
        }
      }
      Ok({
        body: nf_has(raw, "body"),
        actions: nf_has(raw, "actions"),
        icon_static: nf_has(raw, "icon-static"),
        icon_multi: nf_has(raw, "icon-multi"),
        persistence: nf_has(raw, "persistence"),
        raw,
      })
    }
    Ok(_) => Err(NfFailed("GetCapabilities 返回了非数组值"))
  }
}

///|
/// 通知服务是否可用（能查到能力清单即算可用）。
pub fn notify_supported() -> Bool {
  match notify_caps() {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// 组装 `Notify` 的入参（纯函数，白盒测试钉参数顺序与 hint 形态）：
/// (app_name, replaces_id, app_icon, summary, body, actions, hints, timeout)。
fn nf_notify_args(
  app_name : String,
  summary : String,
  body : String,
  icon : String,
  timeout_ms : Int,
  replaces_id : Int,
  progress : Int,
) -> Array[GDBusValue] {
  let hints : Map[String, GDBusValue] = Map([])
  if progress >= 0 {
    let pct = if progress > 100 { 100 } else { progress }
    hints.set("value", GVInt32(pct))
  }
  [
    GVString(app_name),
    GVUInt32(replaces_id),
    GVString(icon),
    GVString(summary),
    GVString(body),
    GVArray("s", []),
    GVDict(hints),
    GVInt32(timeout_ms),
  ]
}

///|
/// 发一张通知，返回服务端给的 id（后续关闭与改进度都用它）。
/// `timeout_ms` 缺省 -1（服务端默认时长）；`replaces_id` 非 0 时替换那张
/// 通知；`progress` 给 0..100 时带上标准 hint `value`。
pub fn notify_send(
  app_name : String,
  summary : String,
  body : String,
  icon? : String = "",
  timeout_ms? : Int = -1,
  replaces_id? : Int = 0,
  progress? : Int = -1,
) -> Result[Int, NotifyError] {
  let args = nf_notify_args(
    app_name,
    summary,
    body,
    icon,
    timeout_ms,
    replaces_id,
    progress,
  )
  match gdbus_call_session(nf_dest(), nf_path(), nf_iface(), "Notify", args) {
    Err(e) =>
      if e.name.has_prefix("gdbus.io") {
        Err(NfUnsupported)
      } else {
        Err(NfFailed("\{e.name}: \{e.message}"))
      }
    Ok(GVUInt32(id)) => Ok(id)
    Ok(_) => Err(NfFailed("Notify 返回了非 u32 值"))
  }
}

///|
/// 按 id 关掉一张通知（id 0 = 全部）。关闭没有返回值，成功即 Ok。
pub fn notify_close(id : Int) -> Result[Unit, NotifyError] {
  match
    gdbus_call_session(
      nf_dest(),
      nf_path(),
      nf_iface(),
      "CloseNotification",
      [GVUInt32(id)],
    ) {
    Err(e) =>
      if e.name.has_prefix("gdbus.io") {
        Err(NfUnsupported)
      } else {
        Err(NfFailed("\{e.name}: \{e.message}"))
      }
    Ok(_) => Ok(())
  }
}

///|
/// 更新一张通知的进度：`replaces_id` 重发同一张 + hint `value`，返回新 id
/// （服务端通常复用原 id；换 id 时用返回值继续更新）。
pub fn notify_progress(
  id : Int,
  app_name : String,
  summary : String,
  body : String,
  pct : Int,
  icon? : String = "",
) -> Result[Int, NotifyError] {
  notify_send(
    app_name,
    summary,
    body,
    icon=icon,
    timeout_ms=-1,
    replaces_id=id,
    progress=pct,
  )
}
