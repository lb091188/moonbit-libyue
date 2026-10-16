// 桌面通知门面（W21a）：跨平台一致的发送 / 关闭 / 进度 API，平台差异收敛在后端
// 选择与语义化降级里。
//
// 后端选择（按优先级）：
// 1. Linux：freedesktop 通知服务（`dbus/notify.mbt`，`org.freedesktop.
//    Notifications`）。可用性以 `GetCapabilities` 能否查到为准。
// 2. Windows：Shell 托盘气泡（`NIF_INFO`，`win/notify.mbt`）——通知挂在
//    托盘图标上，故与 W20c 同源共槽。
// 3. 皆无 → `Err(NotifyError::Unsupported)`（结构化报错，绝不静默失效）。
//
// 两处平台差异**显式降级、不假装对齐**：
// - `progress`：Linux 走标准 hint `value`（桌面端画进度条）；Win32 气泡没有
//   对应物，把百分比拼进正文（可见降级）。
// - `kind`（信息/警告/错误）：Win32 映射 `NIIF_*`（气泡左侧系统状态图标）；
//   Linux 无此概念，由 `icon` 传主题图标名区分。
// 另：`timeout_ms` 在 Win32 自 Vista 起被系统忽略（气泡时长由系统定）。
//
// 通知 id 是**后端内不透明**的：Linux 是服务端给的 u32，Win32 是托盘槽号。
// 同一进程只用一个后端（首个可用者），故按 id 关闭/改进度时后端归属唯一。

///|
/// 通知后端。
pub(all) enum NotifyBackend {
  /// Linux freedesktop 通知服务（`dbus/notify.mbt`）
  Dbus
  /// Win32 托盘气泡（`NIF_INFO`，`win/notify.mbt`）
  WinBalloon
}

///|
/// 结构化通知错误。（与 `dbus` 的 `NotifyError` 同语义，这里再定义一个
/// 平台中立的对外类型：dbus 那个名字带 `Nf*` 前缀且属 Linux 线，门面不该把它
/// 暴露给三平台调用方。）
pub(all) enum NotifyError {
  /// 系统没有可用的通知后端
  Unsupported
  /// 调用失败（含后端给的错误名与说明）
  Failed(String)
}

///|
pub impl Show for NotifyError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("NotifyError::Unsupported")
    Failed(m) => {
      logger.write_string("NotifyError::Failed(")
      logger.write_string(m)
      logger.write_string(")")
    }
  }
}

///|
pub extend NotifyError with Show::{to_string, output}

///|
/// 通知服务能力视图。
pub(all) struct NotifyCaps {
  /// 支持独立正文
  body : Bool
  /// 支持动作按钮
  actions : Bool
  /// 支持静态图标
  icon_static : Bool
  /// 支持多帧/动画图标
  icon_multi : Bool
  /// 通知可跨会话保留
  persistence : Bool
  /// 原始能力清单（桌面端各自扩展的条目不翻译）
  raw : Array[String]
}

///|
/// 当前可用后端（Linux D-Bus 优先 → Win32 气泡）；都不可用给 None。
pub fn notify_backend() -> NotifyBackend? {
  if @dbus.notify_supported() {
    Some(Dbus)
  } else if @win.notify_supported() {
    Some(WinBalloon)
  } else {
    None
  }
}

///|
/// 后端名（"dbus" / "win-balloon" / "none"，状态行与诊断用）。
pub fn notify_backend_name() -> String {
  match notify_backend() {
    Some(Dbus) => "dbus"
    Some(WinBalloon) => "win-balloon"
    None => "none"
  }
}

///|
/// 通知后端是否可用。消费方可据此决定是否展示通知相关功能。
pub fn notify_supported() -> Bool {
  notify_backend() is Some(_)
}

///|
/// 把后端无关的 `kind`（0 信息 / 1 警告 / 2 错误）夹到合法范围。
pub fn notify_clamp_kind(kind : Int) -> Int {
  if kind < 0 {
    0
  } else if kind > 2 {
    2
  } else {
    kind
  }
}

///|
/// 进度百分比夹到 0..100（Linux hint 与 Win32 正文都用它）。
pub fn notify_clamp_pct(pct : Int) -> Int {
  if pct < 0 {
    0
  } else if pct > 100 {
    100
  } else {
    pct
  }
}

///|
/// Win32 气泡没有进度 hint，把百分比拼进正文（可见降级）；pct 为负表示不带进度。
pub fn notify_body_with_progress(body : String, pct : Int) -> String {
  if pct < 0 {
    body
  } else if body == "" {
    "\{notify_clamp_pct(pct)}%"
  } else {
    "\{body}（\{notify_clamp_pct(pct)}%）"
  }
}

///|
/// 查通知能力。先按后端选择定「有没有后端」，再问能力，于是 `notify_caps()`
/// 与 `notify_supported()` 同口径：会话总线在、但通知服务没装，那就是「没有
/// 后端」（`Err(Unsupported)`），不拿总线错误码冒充「有后端却查不到」。
/// - Linux/D-Bus：取服务端 `GetCapabilities`。
/// - Win32：合成一份（气泡只有标题 + 正文，无动作/图标/持久化）。
pub fn notify_caps() -> Result[NotifyCaps, NotifyError] {
  match notify_backend() {
    None => Err(Unsupported)
    Some(WinBalloon) =>
      Ok({
        // 只有标题 + 正文（szInfoTitle / szInfo）
        body: true,
        actions: false,
        icon_static: false,
        icon_multi: false,
        persistence: false,
        raw: ["body"],
      })
    Some(Dbus) =>
      match @dbus.notify_caps() {
        Ok(c) =>
          Ok({
            body: c.body,
            actions: c.actions,
            icon_static: c.icon_static,
            icon_multi: c.icon_multi,
            persistence: c.persistence,
            raw: c.raw,
          })
        Err(@dbus.NfUnsupported) => Err(Unsupported)
        Err(@dbus.NfFailed(m)) => Err(Failed(m))
      }
  }
}

///|
/// 发一张通知，返回通知 id（后续关闭/改进度都用它）。
/// - `icon`：Linux 的主题图标名或路径（Win32 忽略，见 `icon_handle`）。
/// - `icon_handle`：Win32 的 W20f 图标句柄（0 = 用系统状态图标）。
/// - `timeout_ms`：Linux 的通知时长（-1 = 服务端默认）；**Win32 自 Vista 起被
///   系统忽略**，气泡时长由系统定。
/// - `replaces_id`：非 0 时替换同 id 的那张（Win32 上是重发同一托盘槽的气泡）。
/// - `progress`：0..100 时带进度（Linux 走 hint `value`；Win32 拼进正文）。
/// - `kind`：0 信息 / 1 警告 / 2 错误（Win32 映射 `NIIF_*`；Linux 无此概念）。
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
  match notify_backend() {
    Some(Dbus) =>
      match
        @dbus.notify_send(
          app_name,
          summary,
          body,
          icon=icon,
          timeout_ms=timeout_ms,
          replaces_id=replaces_id,
          progress=progress,
        ) {
        Ok(id) => Ok(id)
        Err(e) => Err(nf_err(e))
      }
    Some(WinBalloon) => {
      let text = notify_body_with_progress(body, progress)
      let k = notify_clamp_kind(kind)
      if replaces_id > 0 && @win.notify_update(replaces_id, summary, text, k) {
        return Ok(replaces_id)
      }
      let id = @win.notify_send(icon_handle, summary, text, k)
      if id > 0 {
        Ok(id)
      } else {
        Err(Failed("Win32 气泡发送失败（Shell_NotifyIcon NIM_MODIFY）"))
      }
    }
    None => Err(Unsupported)
  }
}

///|
/// 按 id 关掉一张通知（Win32 上 id 0 无「全部」语义，会走无操作）。关闭成功即
/// `Ok(())`；id 无对应后端/无效给 `Err`。
pub fn notify_close(id : Int) -> Result[Unit, NotifyError] {
  match notify_backend() {
    Some(Dbus) => match @dbus.notify_close(id) {
      Ok(_) => Ok(())
      Err(e) => Err(nf_err(e))
    }
    Some(WinBalloon) => {
      if id <= 0 {
        return Err(Failed("Win32 通知 id 必须 > 0（无「关闭全部」语义）"))
      }
      @win.notify_close(id)
      Ok(())
    }
    None => Err(Unsupported)
  }
}

///|
/// 更新一张通知的进度：重发同一张 + 进度，返回新的 id（后端可能复用原 id；
/// 换了就用返回值继续更新）。
pub fn notify_progress(
  id : Int,
  app_name : String,
  summary : String,
  body : String,
  pct : Int,
  icon? : String = "",
) -> Result[Int, NotifyError] {
  match notify_backend() {
    Some(Dbus) =>
      match @dbus.notify_progress(id, app_name, summary, body, pct, icon=icon) {
        Ok(nid) => Ok(nid)
        Err(e) => Err(nf_err(e))
      }
    Some(WinBalloon) => {
      if id <= 0 {
        return Err(Failed("Win32 通知 id 必须 > 0"))
      }
      let text = notify_body_with_progress(body, pct)
      if @win.notify_update(id, summary, text, 0) {
        Ok(id)
      } else {
        Err(Failed("Win32 气泡进度更新失败"))
      }
    }
    None => Err(Unsupported)
  }
}

///|
/// 把 dbus 线错误翻成门面错误。
fn nf_err(e : @dbus.NotifyError) -> NotifyError {
  match e {
    @dbus.NfUnsupported => Unsupported
    @dbus.NfFailed(m) => Failed(m)
  }
}
