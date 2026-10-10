// Cairo 光栅器的像素级回归：与纯 MoonBit 矩形绘制器的口径一致性，是这一批
// 最要紧的不变量（两者同一份契约、同一块缓冲，将来组件层在它们之间切换）。

fn rgba_of(bm : Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = bm.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

// 同一段绘制序列跑两条路径：门面（Cairo 后端）与降级纯实现（session 置空）。
// 矩形口径（取整、内侧描边、裁剪求交、平移、半透明 source-over）必须逐像素一致，
// 这是将来无 Cairo 平台可用的前提，也是纯实现不被门面改动破坏的回归线。
fn paint_seq(bm : Bitmap, fallback : Bool) -> Unit {
  let p = Painter::new(bm)
  if fallback {
    match p.session {
      Some(c) => c.end()
      None => ()
    }
    p.session = None
  }
  p.set_fill_color("#3366cc")
  p.fill_rect(3.4, 2.7, 5.2, 6.1)
  p.set_stroke_color("#cc3366")
  p.set_line_width(1.0)
  p.stroke_rect(1.2, 1.9, 8.4, 7.3)
  p.set_fill_color("#00ff0080")
  p.save()
  p.translate(1.3, 0.6)
  p.clip_rect(2.4, 2.4, 4.6, 4.6)
  p.fill_rect(0.4, 0.4, 9.0, 9.0)
  p.restore()
  p.set_fill_color("#ff0000")
  p.fill_rect(11.2, 0.6, 1.4, 9.7)
  p.set_fill_color("#ffffff40")
  p.fill_rect(0.3, 9.3, 13.0, 1.4)
  p.end()
}

///|
test "门面（Cairo）与降级纯实现逐像素一致：矩形矩阵" {
  let a = Bitmap::new(14, 12)
  paint_seq(a, false)
  let b = Bitmap::new(14, 12)
  paint_seq(b, true)
  let mut diff = 0
  for y = 0; y < 12; y = y + 1 {
    for x = 0; x < 14; x = x + 1 {
      if rgba_of(a, x, y) != rgba_of(b, x, y) {
        diff = diff + 1
      }
    }
  }
  assert_eq(diff, 0)
  // 两条路径都确实画过东西（防止「两边都空」的假绿）
  assert_eq(a.pixel(5, 5).a, 255)
  assert_eq(b.pixel(5, 5).a, 255)
  assert_eq(a.pixel(12, 10).a, 64)
  assert_eq(b.pixel(12, 10).a, 64)
}

test "路径填充：三角形内部着色、外部透明" {
  let bm = Bitmap::new(16, 16)
  match Cairo::over(bm) {
    Some(c) => {
      c.set_fill_color("#00aa00")
      c.begin_path()
      c.move_to(0.0, 0.0)
      c.line_to(16.0, 0.0)
      c.line_to(0.0, 16.0)
      c.close_path()
      c.fill()
      c.end()
    }
    None => assert_eq(true, false)
  }
  assert_eq(rgba_of(bm, 2, 2), (0, 170, 0, 255))
  assert_eq(rgba_of(bm, 14, 14), (0, 0, 0, 0))
}

test "抗锯齿：斜边像素出现中间 alpha" {
  let bm = Bitmap::new(16, 16)
  match Cairo::over(bm) {
    Some(c) => {
      c.set_fill_color("#000000")
      c.begin_path()
      c.move_to(0.0, 0.0)
      c.line_to(16.0, 16.0)
      c.line_to(0.0, 16.0)
      c.close_path()
      c.fill()
      c.end()
    }
    None => assert_eq(true, false)
  }
  let mut partial = 0
  for y = 0; y < 16; y = y + 1 {
    for x = 0; x < 16; x = x + 1 {
      let (_, _, _, a) = rgba_of(bm, x, y)
      if a > 0 && a < 255 {
        partial = partial + 1
      }
    }
  }
  assert_eq(partial > 0, true)
}

test "clip_rect 与 translate 生效" {
  let bm = Bitmap::new(16, 16)
  match Cairo::over(bm) {
    Some(c) => {
      c.set_fill_color("#ff0000")
      c.save()
      c.clip_rect(0.0, 0.0, 4.0, 4.0)
      c.fill_rect(0.0, 0.0, 16.0, 16.0)
      c.restore()
      c.set_fill_color("#0000ff")
      c.translate(8.0, 8.0)
      c.fill_rect(0.0, 0.0, 4.0, 4.0)
      c.end()
    }
    None => assert_eq(true, false)
  }
  assert_eq(rgba_of(bm, 1, 1), (255, 0, 0, 255))
  assert_eq(rgba_of(bm, 6, 6), (0, 0, 0, 0))
  assert_eq(rgba_of(bm, 9, 9), (0, 0, 255, 255))
}

test "stroke_rect 走内侧口径（与 Painter 同语义）" {
  let a = Bitmap::new(12, 12)
  let pa = Painter::new(a)
  pa.set_stroke_color("#333333")
  pa.stroke_rect(2.0, 2.0, 8.0, 8.0)

  let b = Bitmap::new(12, 12)
  match Cairo::over(b) {
    Some(c) => {
      c.set_fill_color("#333333")
      c.set_line_width(1.0)
      c.stroke_rect(2.0, 2.0, 8.0, 8.0)
      c.end()
    }
    None => assert_eq(true, false)
  }
  // 边框像素：两侧实现都应着色且内部都留空
  assert_eq(a.pixel(2, 2).a, 255)
  assert_eq(b.pixel(2, 2).a, 255)
  assert_eq(a.pixel(5, 5).a, 0)
  assert_eq(b.pixel(5, 5).a, 0)
  // 内侧口径：边框不越出给定矩形
  assert_eq(b.pixel(1, 1).a, 0)
  assert_eq(b.pixel(10, 10).a, 0)
  pa.end()
}

test "颜色含 alpha 时与矩形绘制器结果一致" {
  let a = Bitmap::new(4, 4)
  let pa = Painter::new(a)
  pa.set_fill_color("#ffffff")
  pa.fill_rect(0.0, 0.0, 4.0, 4.0)
  pa.set_fill_color("#00000080")
  pa.fill_rect(0.0, 0.0, 4.0, 4.0)

  let b = Bitmap::new(4, 4)
  match Cairo::over(b) {
    Some(c) => {
      c.set_fill_color("#ffffff")
      c.fill_rect(0.0, 0.0, 4.0, 4.0)
      c.set_fill_color("#00000080")
      c.fill_rect(0.0, 0.0, 4.0, 4.0)
      c.end()
    }
    None => assert_eq(true, false)
  }
  assert_eq(rgba_of(b, 1, 1), rgba_of(a, 1, 1))
  assert_eq(rgba_of(b, 1, 1), (127, 127, 127, 255))
  pa.end()
}
