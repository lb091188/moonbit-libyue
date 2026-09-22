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

///|
/// 单个十六进制数字的值,非十六进制字符返回 -1。
fn hex_val(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// 解析十六进制色串为 (r, g, b):"#RRGGBB" 全式、"#RGB" 短式与
/// "#AARRGGBB" 8 位式均收,'#' 前后空白容忍,大小写不敏感;非法输入
/// 返回 None。"RGB"/"RRGGBB"(无 #)形式同样解析,方便直接吃系统主题
/// 里的色值。
pub fn parse_hex(hex : String) -> (Int, Int, Int)? {
  let digits : Array[Int] = []
  for c in hex {
    let v = hex_val(c)
    if v < 0 {
      if c == '#' || c == ' ' {
        continue
      }
      return None
    }
    digits.push(v)
  }
  let at = fn(i : Int) -> Int { digits[i] * 16 + digits[i + 1] }
  if digits.length() == 6 {
    Some((at(0), at(2), at(4)))
  } else if digits.length() == 3 {
    // #RGB 短式:每位重复一遍补足
    Some((digits[0] * 17, digits[1] * 17, digits[2] * 17))
  } else if digits.length() == 8 {
    // #AARRGGBB:丢掉 alpha 取 RGB(不透明化)
    Some((at(2), at(4), at(6)))
  } else {
    None
  }
}

///|
/// 拼 alpha 色为 "#AARRGGBB":hex 传 "#RRGGBB"(容忍无 '#'),aa 传两
/// 位十六进制不透明度。8 位 hex 的 alpha 在前(libyue Color 与上方
/// parse_hex 同一约定,与 CSS 的 #RRGGBBAA 相反)——拼在尾部会落到
/// 蓝分量,表现为颜色漂移而非透明度变化(渐隐变黄即此坑)。
pub fn with_alpha(hex : String, aa : String) -> String {
  let body = StringBuilder()
  let mut skip_hash = true
  for c in hex {
    if skip_hash {
      skip_hash = false
      if c == '#' {
        continue
      }
    }
    body.write_char(c)
  }
  "#" + aa + body.to_string()
}

///|
/// 钳制到 0..255。
fn clamp8(v : Int) -> Int {
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}

///|
/// 6 位 "#RRGGBB" 形式(派生色板用;rgb_hex 带 alpha 前缀,服务系统
/// 语义色的 ARGB 透出)。
fn hex6(r : Int, g : Int, b : Int) -> String {
  let sb = StringBuilder()
  for v in [r, g, b] {
    sb.write_char(hex_digit((v >> 4) & 15))
    sb.write_char(hex_digit(v & 15))
  }
  "#" + sb.to_string()
}

///|
/// RGB(0..255)→ HSL(h 0..360,s 0..1,l 0..1)。灰色(s=0)时 h 归零。
pub fn rgb_to_hsl(r : Int, g : Int, b : Int) -> (Double, Double, Double) {
  let rf = r.to_double() / 255.0
  let gf = g.to_double() / 255.0
  let bf = b.to_double() / 255.0
  let mx = rf.max(gf).max(bf)
  let mn = rf.min(gf).min(bf)
  let l = (mx + mn) / 2.0
  if mx == mn {
    (0.0, 0.0, l)
  } else {
    let d = mx - mn
    let s = if l > 0.5 {
      d / (2.0 - mx - mn)
    } else {
      d / (mx + mn)
    }
    let h6 = if mx == rf {
      (gf - bf) / d + (if gf < bf { 6.0 } else { 0.0 })
    } else if mx == gf {
      (bf - rf) / d + 2.0
    } else {
      (rf - gf) / d + 4.0
    }
    (h6 * 60.0, s, l)
  }
}

///|
/// HSL(h 0..360,s 0..1,l 0..1)→ RGB(0..255)。
pub fn hsl_to_rgb(h : Double, s : Double, l : Double) -> (Int, Int, Int) {
  let ss = if s < 0.0 {
    0.0
  } else if s > 1.0 {
    1.0
  } else {
    s
  }
  let ll = if l < 0.0 {
    0.0
  } else if l > 1.0 {
    1.0
  } else {
    l
  }
  let mut hh = h % 360.0
  if hh < 0.0 {
    hh = hh + 360.0
  }
  let c = (1.0 - (2.0 * ll - 1.0).abs()) * ss
  let x = c * (1.0 - ((hh / 60.0) % 2.0 - 1.0).abs())
  let m = ll - c / 2.0
  let (r1, g1, b1) = if hh < 60.0 {
    (c, x, 0.0)
  } else if hh < 120.0 {
    (x, c, 0.0)
  } else if hh < 180.0 {
    (0.0, c, x)
  } else if hh < 240.0 {
    (0.0, x, c)
  } else if hh < 300.0 {
    (x, 0.0, c)
  } else {
    (c, 0.0, x)
  }
  (
    clamp8(((r1 + m) * 255.0).round().to_int()),
    clamp8(((g1 + m) * 255.0).round().to_int()),
    clamp8(((b1 + m) * 255.0).round().to_int()),
  )
}

///|
/// 由 HSL 分量构造 "#RRGGBB" 色串。
pub fn from_hsl(h : Double, s : Double, l : Double) -> String {
  let (r, g, b) = hsl_to_rgb(h, s, l)
  hex6(r, g, b)
}

///|
/// 两色线性混色:t 为取 a 的比例(0..1),其余取 b;任一输入非法时
/// 原样返回 a。
pub fn mix_hex(a : String, b : String, t : Double) -> String {
  let tt = if t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
  match (parse_hex(a), parse_hex(b)) {
    (Some((r1, g1, b1)), Some((r2, g2, b2))) =>
      hex6(
        clamp8(((r1.to_double() * tt + r2.to_double() * (1.0 - tt)).round()).to_int()),
        clamp8(((g1.to_double() * tt + g2.to_double() * (1.0 - tt)).round()).to_int()),
        clamp8(((b1.to_double() * tt + b2.to_double() * (1.0 - tt)).round()).to_int()),
      )
    _ => a
  }
}

///|
/// 明度提高(HSL 的 L 加 amount,0..1):主色变亮。
pub fn lighten_hex(hex : String, amount : Double) -> String {
  match parse_hex(hex) {
    Some((r, g, b)) => {
      let (h, s, l) = rgb_to_hsl(r, g, b)
      from_hsl(h, s, l + amount)
    }
    None => hex
  }
}

///|
/// 明度降低(HSL 的 L 减 amount,0..1):主色变暗。
pub fn darken_hex(hex : String, amount : Double) -> String {
  lighten_hex(hex, -amount)
}
