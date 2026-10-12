// 绘制契约的像素级回归：断言直接比 RGBA 字节，不引入图片编码。
// 「布局树 → 像素」的定位断言留给接线 yoga-mbt 的那批（G2/G7），
// 本包尚不依赖布局引擎。

///|
fn rgba(p : Painter, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = p.bitmap.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

///|
fn red_painter(w : Int, h : Int) -> Painter {
  let p = Painter::new(Bitmap::new(w, h))
  p.set_fill_color("#ff0000")
  p
}

///|
test "fill_rect 覆盖半开区间" {
  let p = red_painter(4, 4)
  p.fill_rect(1.0, 1.0, 2.0, 2.0)
  assert_eq(rgba(p, 1, 1), (255, 0, 0, 255))
  assert_eq(rgba(p, 2, 2), (255, 0, 0, 255))
  assert_eq(rgba(p, 0, 0), (0, 0, 0, 0))
  // 右下端点不在覆盖区内
  assert_eq(rgba(p, 3, 1), (0, 0, 0, 0))
  p.end()
}

///|
test "半透明按 source-over 混合" {
  let p = Painter::new(Bitmap::new(2, 2))
  p.set_fill_color("#ffffff")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.set_fill_color("#00000080")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  assert_eq(rgba(p, 1, 1), (127, 127, 127, 255))
  p.end()
}

///|
test "translate 生效且 restore 回退" {
  let p = red_painter(8, 8)
  p.save()
  p.translate(4.0, 4.0)
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.restore()
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  assert_eq(rgba(p, 5, 5), (255, 0, 0, 255))
  assert_eq(rgba(p, 1, 1), (255, 0, 0, 255))
  assert_eq(rgba(p, 3, 3), (0, 0, 0, 0))
  p.end()
}

///|
test "clip_rect 只收紧不放宽" {
  let p = red_painter(6, 6)
  p.save()
  p.clip_rect(0.0, 0.0, 2.0, 2.0)
  p.fill_rect(1.0, 1.0, 4.0, 4.0)
  p.restore()
  assert_eq(rgba(p, 4, 4), (0, 0, 0, 0))
  p.fill_rect(3.0, 3.0, 1.0, 1.0)
  assert_eq(rgba(p, 3, 3), (255, 0, 0, 255))
  let (x0, y0, x1, y1) = p.clip_bounds()
  assert_eq((x0, y0, x1, y1), (0, 0, 6, 6))
  p.end()
}

///|
test "stroke_rect 描内侧一圈" {
  let p = red_painter(6, 6)
  p.set_stroke_color("#0000ff")
  p.stroke_rect(1.0, 1.0, 4.0, 4.0)
  assert_eq(rgba(p, 1, 1), (0, 0, 255, 255))
  assert_eq(rgba(p, 4, 4), (0, 0, 255, 255))
  assert_eq(rgba(p, 2, 2), (0, 0, 0, 0))
  assert_eq(rgba(p, 0, 3), (0, 0, 0, 0))
  assert_eq(rgba(p, 5, 3), (0, 0, 0, 0))
  p.end()
}

///|
test "矩形窄于两倍线宽时整块填满" {
  let p = red_painter(4, 12)
  p.set_stroke_color("#00ff00")
  p.stroke_rect(0.0, 0.0, 1.0, 10.0)
  assert_eq(rgba(p, 0, 5), (0, 255, 0, 255))
  assert_eq(rgba(p, 1, 5), (0, 0, 0, 0))
  p.end()
}

///|
test "等分三段共用边不留缝" {
  let p = red_painter(100, 10)
  let third = 100.0 / 3.0
  p.fill_rect(0.0, 0.0, third, 10.0)
  p.fill_rect(third, 0.0, third, 10.0)
  p.fill_rect(third * 2.0, 0.0, third, 10.0)
  let mut painted = 0
  for x = 0; x < 100; x = x + 1 {
    if p.bitmap.pixel(x, 5).a == 255 {
      painted = painted + 1
    }
  }
  assert_eq(painted, 100)
  p.end()
}

///|
test "非法 hex 与非法尺寸保持原状" {
  let p = red_painter(2, 2)
  p.set_fill_color("not-a-color")
  p.fill_rect(0.0, 0.0, 1.0, 1.0)
  assert_eq(rgba(p, 0, 0), (255, 0, 0, 255))
  let empty = Painter::new(Bitmap::new(0, 4))
  empty.set_fill_color("#ff0000")
  empty.fill_rect(0.0, 0.0, 4.0, 4.0)
  assert_eq(rgba(empty, 0, 0), (0, 0, 0, 0))
  p.end()
  empty.end()
}

///|
/// 造一张 120×120 的源图：(20,20)-(99,99) 一个不透明红方，其余全透明。
fn dot_source() -> Image {
  let src = Bitmap::new(120, 120)
  for y = 20; y < 100; y = y + 1 {
    for x = 20; x < 100; x = x + 1 {
      let i = (y * 120 + x) * 4
      src.data[i] = b'\xff'
      src.data[i + 3] = b'\xff'
    }
  }
  Image::from_bitmap(src)
}

///|
/// 把源图缩到 `size` 画进位图，返回不透明像素的包围盒（空时给 (-1,-1,-1,-1)）。
fn scaled_box(img : Image, size : Int) -> (Int, Int, Int, Int) {
  let bm = Bitmap::new(size + 2, size + 2)
  let p = Painter::new(bm)
  p.draw_image(img, 0.0, 0.0, size.to_double(), size.to_double())
  p.end()
  let mut x0 = -1
  let mut y0 = -1
  let mut x1 = -1
  let mut y1 = -1
  for y = 0; y < size + 2; y = y + 1 {
    for x = 0; x < size + 2; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        if x0 < 0 {
          x0 = x
          y0 = y
          x1 = x
          y1 = y
        } else {
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
  }
  (x0, y0, x1, y1)
}

///|
test "缩放绘制：源矩形按比例映到目标矩形（等比与缩小都对）" {
  let img = dot_source()
  // 1:1 时包围盒就是源方块本身
  assert_eq(scaled_box(img, 120), (20, 20, 99, 99))
  // 缩到 72：20×0.6=12、100×0.6=60
  assert_eq(scaled_box(img, 72), (12, 12, 59, 59))
  // 缩到 48：20×0.4=8、100×0.4=40
  assert_eq(scaled_box(img, 48), (8, 8, 39, 39))
  // 源子矩形 → 目标矩形：取样域收在子矩形内（不邻块串色）
  let bm = Bitmap::new(40, 40)
  let p = Painter::new(bm)
  p.draw_image_from_rect(img, 20.0, 20.0, 80.0, 80.0, 0.0, 0.0, 40.0, 40.0)
  p.end()
  let mut ink = 0
  for y = 0; y < 40; y = y + 1 {
    for x = 0; x < 40; x = x + 1 {
      if bm.pixel(x, y).a > 0 {
        ink = ink + 1
      }
    }
  }
  assert_true(ink > 1500)
}
