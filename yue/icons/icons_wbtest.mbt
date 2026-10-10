// 图标绘制面的回归：清单与路径数据一一对应、名字唯一、路径串字符集封闭，
// 以及「每个图标都真的画出像素且内容居中」。

///|
fn painted_count(bm : @render.Bitmap) -> Int {
  let mut n = 0
  for y = 0; y < bm.height; y = y + 1 {
    for x = 0; x < bm.width; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        n = n + 1
      }
    }
  }
  n
}

///|
/// 已画像素的包围盒（无非空像素给 None）。
fn painted_box(bm : @render.Bitmap) -> (Int, Int, Int, Int)? {
  let mut x0 = bm.width
  let mut y0 = bm.height
  let mut x1 = -1
  let mut y1 = -1
  for y = 0; y < bm.height; y = y + 1 {
    for x = 0; x < bm.width; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        if x < x0 {
          x0 = x
        }
        if y < y0 {
          y0 = y
        }
        if x > x1 {
          x1 = x
        }
        if y > y1 {
          y1 = y
        }
      }
    }
  }
  if x1 < 0 {
    None
  } else {
    Some((x0, y0, x1, y1))
  }
}

///|
test "清单、名字与路径数据一一对应" {
  let all = all_icons()
  let n = all.length()
  assert_eq(n > 0, true)
  assert_eq(icon_path_data.length(), n)
  // kind_index 在清单上取到自身下标（重复项会让计数不为 1）
  let counts = FixedArray::make(n, 0)
  for k in all {
    let i = kind_index(k)
    assert_eq(i >= 0 && i < n, true)
    counts[i] = counts[i] + 1
  }
  for i = 0; i < n; i = i + 1 {
    assert_eq(counts[i], 1)
  }
  // 名字非空且两两不同（n 不大，平方比对够用）
  let names : Array[String] = []
  for k in all {
    let nm = icon_name(k)
    assert_eq(nm.length() > 0, true)
    names.push(nm)
  }
  let mut dup = 0
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      if names[i] == names[j] {
        dup = dup + 1
      }
    }
  }
  assert_eq(dup, 0)
}

///|
/// 路径串字符集封闭：只允许 M/L/C/Z 与数字、'-'、','；首尾为 M…Z。
fn path_charset_ok(d : String) -> Bool {
  let mut ok = true
  for ch in d {
    let c = ch.to_int()
    let good = (c >= 48 && c <= 57) ||
      c == 45 ||
      c == 44 ||
      c == 77 ||
      c == 76 ||
      c == 67 ||
      c == 90
    if !good {
      ok = false
    }
  }
  let n = d.length()
  ok && n >= 2 && d.unsafe_get(0).to_int() == 77 && d.unsafe_get(n - 1).to_int() == 90
}

///|
test "路径串全量字符集封闭" {
  let mut bad = 0
  for d in icon_path_data {
    if !path_charset_ok(d) {
      bad = bad + 1
    }
  }
  assert_eq(bad, 0)
}

///|
test "draw_icon：内容居中且落像素" {
  let bm = @render.Bitmap::new(32, 32)
  let p = @render.Painter::new(bm)
  draw_icon(p, TreeStructure, 16.0, 16.0, 13.0, "#000000")
  p.end()
  assert_eq(painted_count(bm) > 5, true)
  match painted_box(bm) {
    Some((x0, y0, x1, y1)) => {
      let cx = (x0 + x1).to_double() / 2.0
      let cy = (y0 + y1).to_double() / 2.0
      assert_eq((cx - 16.0).abs() <= 2.0, true)
      assert_eq((cy - 16.0).abs() <= 2.0, true)
    }
    None => assert_eq(true, false)
  }
}

///|
test "全部图标都能出像素（24px 扫描）" {
  let all = all_icons()
  let mut empty = 0
  let mut sample = 0
  for k in all {
    let bm = @render.Bitmap::new(24, 24)
    let p = @render.Painter::new(bm)
    draw_icon(p, k, 12.0, 12.0, 10.0, "#336699")
    p.end()
    sample = sample + 1
    if painted_count(bm) == 0 {
      empty = empty + 1
    }
  }
  assert_eq(sample, all.length())
  assert_eq(empty, 0)
}
