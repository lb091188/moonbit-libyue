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
