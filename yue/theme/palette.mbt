// 主题调色数学：hex 解析复用 `@render.Color::parse`（CSS 口径——8 位写法透明度
// 在尾，与 libyue 的 #AARRGGBB 是已知分岔，见 adaptation「G1」条），HSL / 混色 /
// 明度升降与 master 线 `yue/color.mbt` 同实现同语义，便于组件层平移时结果可比。

///|
fn hex_digit(v : Int) -> Char {
  if v < 10 {
    (48 + v).unsafe_to_char()
  } else {
    (87 + v).unsafe_to_char()
  }
}

///|
/// 6 位 `#RRGGBB`（派生色板用；输出小写十六进制）。
pub fn hex6(r : Int, g : Int, b : Int) -> String {
  let sb = StringBuilder()
  for v in [r, g, b] {
    sb.write_char(hex_digit((v >> 4) & 15))
    sb.write_char(hex_digit(v & 15))
  }
  "#" + sb.to_string()
}

///|
/// hex → RGB(0..255)；非法写法给 None。
pub fn parse_hex(hex : String) -> (Int, Int, Int)? {
  match @render.Color::parse(hex) {
    Some(c) => Some((c.r, c.g, c.b))
    None => None
  }
}

///|
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
/// RGB(0..255) → HSL(h 0..360, s 0..1, l 0..1)；灰色（s=0）时 h 归零。
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
    let s = if l > 0.5 { d / (2.0 - mx - mn) } else { d / (mx + mn) }
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
/// HSL(h 0..360, s 0..1, l 0..1) → RGB(0..255)。
pub fn hsl_to_rgb(
  h : Double,
  s : Double,
  l : Double,
) -> (Int, Int, Int) {
  let ss = if s < 0.0 { 0.0 } else if s > 1.0 { 1.0 } else { s }
  let ll = if l < 0.0 { 0.0 } else if l > 1.0 { 1.0 } else { l }
  let mut hh = h % 360.0
  if hh < 0.0 {
    hh = hh + 360.0
  }
  let c = (1.0 - (2.0 * ll - 1.0).abs()) * ss
  let x = c * (1.0 - (hh / 60.0 % 2.0 - 1.0).abs())
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
/// HSL → `#RRGGBB`。
pub fn from_hsl(h : Double, s : Double, l : Double) -> String {
  let (r, g, b) = hsl_to_rgb(h, s, l)
  hex6(r, g, b)
}

///|
/// 两色线性混色：`t` 是取 a 的比例（0..1），其余取 b。端点（t=0/1）与任一输入
/// 非法时原样返回对应输入色——不经 hex6 往返（它输出小写，会把主题串的
/// `#2D68C4` 改写成 `#2d68c4`，与原串比较不等）。
pub fn mix_hex(a : String, b : String, t : Double) -> String {
  match (parse_hex(a), parse_hex(b)) {
    (Some((r1, g1, b1)), Some((r2, g2, b2))) =>
      if t >= 1.0 {
        a
      } else if t <= 0.0 {
        b
      } else {
        let ch = fn(x : Int, y : Int) -> Int {
          clamp8((x.to_double() * t + y.to_double() * (1.0 - t)).round().to_int())
        }
        hex6(ch(r1, r2), ch(g1, g2), ch(b1, b2))
      }
    _ => a
  }
}

///|
/// 明度提高（HSL 的 L 加 amount，0..1）。
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
/// 明度降低（HSL 的 L 减 amount，0..1）。
pub fn darken_hex(hex : String, amount : Double) -> String {
  lighten_hex(hex, -amount)
}
