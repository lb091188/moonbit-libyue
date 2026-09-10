// 桌面环境识别：XDG_CURRENT_DESKTOP 冒号分隔多值（如 "ubuntu:GNOME"）。
// 用于托盘后端选择与降级提示；运行时真伪仍以 StatusNotifierWatcher
// 是否在线为准，环境名只做辅助判断。

///|
pub enum DesktopEnv {
  Gnome
  Kde
  Xfce
  Mate
  Cinnamon
  Budgie
  Lxqt
  Unity
  Unknown
}

///|
fn parse_desktop_value(s : String) -> DesktopEnv {
  let lower = s.to_lower()
  if lower.has_prefix("gnome") || lower == "ubuntu" {
    Gnome
  } else if lower.has_prefix("kde") || lower == "plasma" {
    Kde
  } else if lower == "xfce" {
    Xfce
  } else if lower == "mate" {
    Mate
  } else if lower.has_prefix("x-cinnamon") {
    Cinnamon
  } else if lower.has_prefix("budgie") {
    Budgie
  } else if lower.has_prefix("lxqt") {
    Lxqt
  } else if lower == "unity" {
    Unity
  } else {
    Unknown
  }
}

///|
/// 识别当前桌面环境（取 XDG_CURRENT_DESKTOP 第一个可识别值）。
pub fn detect_desktop() -> DesktopEnv {
  parse_desktop_env(env_get("XDG_CURRENT_DESKTOP"))
}

///|
fn parse_desktop_env(value : String?) -> DesktopEnv {
  match value {
    Some(v) => {
      for part in v.split(":") {
        let env = parse_desktop_value(part.to_owned())
        if !(env is Unknown) {
          return env
        }
      }
      Unknown
    }
    None => Unknown
  }
}

///|
/// 桌面环境名（诊断用）。
pub fn desktop_name() -> String {
  match detect_desktop() {
    Gnome => "GNOME"
    Kde => "KDE"
    Xfce => "XFCE"
    Mate => "MATE"
    Cinnamon => "Cinnamon"
    Budgie => "Budgie"
    Lxqt => "LXQt"
    Unity => "Unity"
    Unknown => "unknown"
  }
}
