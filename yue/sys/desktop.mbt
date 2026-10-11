// 桌面环境识别：读 XDG_CURRENT_DESKTOP（冒号分隔多值，如 "ubuntu:GNOME"），
// 取第一个可识别值。壁纸、默认应用、最近文件等按此分派具体实现；某桌面
// 认得出名字不代表工具一定在，能力真伪仍以命令能否跑通为准。

///|
pub(all) enum DesktopEnv {
  Gnome
  Kde
  Xfce
  Mate
  Cinnamon
  Budgie
  Lxqt
  Unity
  Deepin
  Unknown
}

///|
/// 单个 XDG_CURRENT_DESKTOP 值到桌面枚举的映射（大小写不敏感）。
fn desktop_parse_value(s : String) -> DesktopEnv {
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
  } else if lower == "deepin" {
    Deepin
  } else {
    Unknown
  }
}

///|
/// 解析 XDG_CURRENT_DESKTOP 原文：按冒号逐段试，取第一个可识别值；
/// 全不认或未设置为 Unknown。
fn desktop_parse_env(value : String?) -> DesktopEnv {
  match value {
    Some(v) => {
      for part in v.split(":") {
        let env = desktop_parse_value(part.to_owned())
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
/// 当前桌面环境（读 XDG_CURRENT_DESKTOP；未设置或认不出为 Unknown）。
pub fn desktop_detect() -> DesktopEnv {
  desktop_parse_env(envx_get("XDG_CURRENT_DESKTOP"))
}

///|
/// 当前桌面环境名（诊断与错误信息用；认不出为 "unknown"）。
pub fn desktop_name() -> String {
  match desktop_detect() {
    Gnome => "GNOME"
    Kde => "KDE"
    Xfce => "XFCE"
    Mate => "MATE"
    Cinnamon => "Cinnamon"
    Budgie => "Budgie"
    Lxqt => "LXQt"
    Unity => "Unity"
    Deepin => "Deepin"
    Unknown => "unknown"
  }
}
