// 颜色工具：纯 MoonBit 实现，避免为数值颜色进 C 层。

///|
fn hex_digit(v : Int) -> Char {
  if v < 10 {
    (48 + v).unsafe_to_char()
  } else {
    (87 + v).unsafe_to_char()
  }
}

///|
/// Color.argb(a, r, g, b) 的等价实现：转 libyue 的 hex 颜色串。
pub fn argb_hex(a : Int, r : Int, g : Int, b : Int) -> String {
  let sb = StringBuilder()
  for v in [a, r, g, b] {
    sb.write_char(hex_digit((v >> 4) & 15))
    sb.write_char(hex_digit(v & 15))
  }
  "#" + sb.to_string()
}

///|
/// Color.rgb(r, g, b) 的等价实现。
pub fn rgb_hex(r : Int, g : Int, b : Int) -> String {
  argb_hex(255, r, g, b)
}

///|
/// 系统语义色（对照 Color::Name，取当前主题实时值，随深浅色模式变化）。
pub(all) enum SystemColor {
  Text
  DisabledText
  TextEditBackground
  DisabledTextEditBackground
  Control
  WindowBackground
  Border
}

///|
fn system_color_id(c : SystemColor) -> Int {
  match c {
    Text => 0
    DisabledText => 1
    TextEditBackground => 2
    DisabledTextEditBackground => 3
    Control => 4
    WindowBackground => 5
    Border => 6
  }
}

///|
/// 取系统语义色的 ARGB hex（如 "#ff000000"），仅主线程 GUI 初始化后可用。
pub fn system_color(name : SystemColor) -> String {
  let v = ffi_system_color(system_color_id(name))
  argb_hex((v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255)
}
