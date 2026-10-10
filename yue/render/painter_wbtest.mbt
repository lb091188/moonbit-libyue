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
