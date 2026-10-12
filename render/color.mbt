// 绘制契约的颜色端：hex 字符串 → RGBA 分量。
// 接受 #RGB / #RGBA / #RRGGBB / #RRGGBBAA 四种写法（旧 Painter 头注释同一口径）。
// 注意 8 位写法这里按 CSS 的「透明度在尾」解析，而 libyue 的 Color 约定是
// #AARRGGBB（见 `yue/color.mbt` 的 parse_hex 注释）——本栈不沿用前者；
// 混用会表现为颜色漂移而不是透明度变化，属已知口径分岔。

///|
pub(all) struct Color {
  r : Int
  g : Int
  b : Int
  a : Int
}

///|
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
/// 解析 hex 颜色；写法不完整或含非 hex 字符时返回 None。
pub fn Color::parse(hex : String) -> Color? {
  let ds : Array[Int] = []
  for c in hex {
    if c == '#' || c == ' ' {
      continue
    }
    let v = hex_val(c)
    if v < 0 {
      return None
    }
    ds.push(v)
  }
  let n = ds.length()
  let at = fn(i : Int) -> Int { ds[i] * 16 + ds[i + 1] }
  let up = fn(d : Int) -> Int { d * 17 }
  if n == 6 {
    Some({ r: at(0), g: at(2), b: at(4), a: 255, })
  } else if n == 8 {
    Some({ r: at(0), g: at(2), b: at(4), a: at(6), })
  } else if n == 3 {
    Some({ r: up(ds[0]), g: up(ds[1]), b: up(ds[2]), a: 255, })
  } else if n == 4 {
    Some({ r: up(ds[0]), g: up(ds[1]), b: up(ds[2]), a: up(ds[3]), })
  } else {
    None
  }
}

///|
let color_black : Color = { r: 0, g: 0, b: 0, a: 255, }

///|
let color_transparent : Color = { r: 0, g: 0, b: 0, a: 0, }
