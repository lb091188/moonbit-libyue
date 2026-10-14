// 桌面环境识别白盒测试：单值映射（大小写、ubuntu/plasma 别名、未知值）、
// 冒号多值取首个可识别项、原文缺失为 Unknown；真实环境读数用「存—改—
// 断—复」环验证识别确实走进程环境，改完复原不影响其他用例。

///|
test {
  // 单值映射：前缀与全等两套规则
  assert_true(desktop_parse_value("GNOME") is Gnome)
  assert_true(desktop_parse_value("gnome") is Gnome)
  assert_true(desktop_parse_value("Ubuntu") is Gnome)
  assert_true(desktop_parse_value("KDE") is Kde)
  assert_true(desktop_parse_value("plasma") is Kde)
  assert_true(desktop_parse_value("XFCE") is Xfce)
  assert_true(desktop_parse_value("MATE") is Mate)
  assert_true(desktop_parse_value("X-Cinnamon") is Cinnamon)
  assert_true(desktop_parse_value("Budgie") is Budgie)
  assert_true(desktop_parse_value("LxQt") is Lxqt)
  assert_true(desktop_parse_value("unity") is Unity)
  assert_true(desktop_parse_value("Deepin") is Deepin)
  // 认不出：空串与陌生名字
  assert_true(desktop_parse_value("") is Unknown)
  assert_true(desktop_parse_value("Windows") is Unknown)
}

///|
test {
  // 多值：取第一个可识别值（"ubuntu:GNOME" 首段即命中）
  assert_true(desktop_parse_env(Some("ubuntu:GNOME")) is Gnome)
  // 首段认不出则继续往后找
  assert_true(desktop_parse_env(Some("Something:XFCE")) is Xfce)
  // 全认不出 / 未设置
  assert_true(desktop_parse_env(Some("A:B")) is Unknown)
  assert_true(desktop_parse_env(None) is Unknown)
  assert_true(desktop_parse_env(Some("")) is Unknown)
}

///|
test {
  if sys_platform() == "windows" {
    // Windows：desktop_detect 恒为显式成员（不读 XDG 环境变量）
    assert_true(desktop_detect() is Windows)
    assert_eq(desktop_name(), "Windows Shell")
    return
  }
  // 真实环境读数环：改 XDG_CURRENT_DESKTOP 后识别随之变化，随后复原
  let before = desktop_name()
  let saved = envx_get("XDG_CURRENT_DESKTOP")
  assert_true(envx_set("XDG_CURRENT_DESKTOP", "KDE") is Ok(_))
  assert_true(desktop_detect() is Kde)
  assert_eq(desktop_name(), "KDE")
  assert_true(envx_set("XDG_CURRENT_DESKTOP", "Whatever") is Ok(_))
  assert_true(desktop_detect() is Unknown)
  assert_eq(desktop_name(), "unknown")
  match saved {
    Some(v) => {
      let _ = envx_set("XDG_CURRENT_DESKTOP", v)
    }
    None => {
      let _ = envx_unset("XDG_CURRENT_DESKTOP")
    }
  }
  // 复原后与改动前同一读数（本机认不出时也一致为 unknown）
  assert_eq(desktop_name(), before)
}
