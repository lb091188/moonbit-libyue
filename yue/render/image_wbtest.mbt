// 图片与离屏画布的回归：解码往返（自产 PNG → GdkPixbuf 解码 → 像素比对）、
// 空图语义、缩放与子矩形 blit、混合模式在 blit 上生效、PNG 落盘读回。
// 像素一律比 RGBA 分量（Bitmap::pixel 口径），不引入图片编码以外的工具。

///|
fn fill_color(p : Painter, hex : String, n : Int) -> Unit {
  p.set_fill_color(hex)
  p.fill_rect(0.0, 0.0, n.to_double(), n.to_double())
}

///|
test "PNG 往返：自产 PNG 解码回同像素（不透明）" {
  let bm = Bitmap::new(3, 3)
  let p = Painter::new(bm)
  p.set_fill_color("#ff0000")
  p.fill_rect(0.0, 0.0, 1.0, 3.0)
  p.set_fill_color("#00ff00")
  p.fill_rect(1.0, 0.0, 1.0, 3.0)
  p.set_fill_color("#0000ff")
  p.fill_rect(2.0, 0.0, 1.0, 3.0)
  p.end()
  let png = match png_encode_rgba(bm.to_rgba_bytes(), 3, 3) {
    Ok(b) => b
    Err(_) => {
      assert_eq(true, false)
      return
    }
  }
  let img = Image::new_from_png(png)
  assert_eq(img.is_empty(), false)
  assert_eq(img.get_width(), 3.0)
  assert_eq(img.get_height(), 3.0)
  for y = 0; y < 3; y = y + 1 {
    for x = 0; x < 3; x = x + 1 {
      let a = bm.pixel(x, y)
      let b = img.pixels.pixel(x, y)
      assert_eq((a.r, a.g, a.b, a.a), (b.r, b.g, b.b, b.a))
    }
  }
}

///|
test "PNG 往返：半透明像素在预乘取整域稳定" {
  let bm = Bitmap::new(2, 2)
  let p = Painter::new(bm)
  fill_color(p, "#12345680", 2)
  p.end()
  let png = match png_encode_rgba(bm.to_rgba_bytes(), 2, 2) {
    Ok(b) => b
    Err(_) => {
      assert_eq(true, false)
      return
    }
  }
  let img = Image::new_from_png(png)
  let c = img.pixels.pixel(1, 1)
  assert_eq(c.a, 128)
  let want = bm.pixel(1, 1)
  assert_eq((c.r - want.r).abs() <= 1, true)
  assert_eq((c.g - want.g).abs() <= 1, true)
  assert_eq((c.b - want.b).abs() <= 1, true)
}

///|
test "解码失败与空图语义" {
  let bad = Image::new_from_png(@utf8.encode("not a png at all"))
  assert_eq(bad.is_empty(), true)
  assert_eq(bad.get_width(), 0.0)
  let missing = Image::new_from_file("/tmp/definitely-missing-moonbit-libyue-native.png")
  assert_eq(missing.is_empty(), true)
  // 空图上画不落像素
  let bm = Bitmap::new(4, 4)
  let p = Painter::new(bm)
  p.draw_image(missing, 0.0, 0.0, 4.0, 4.0)
  p.draw_image_from_rect(bad, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 4.0, 4.0)
  p.end()
  assert_eq(bm.pixel(2, 2).a, 0)
}

///|
test "逻辑尺寸随 scale 折算，像素尺寸不变" {
  let bm = Bitmap::new(8, 4)
  let img = Image::from_bitmap(bm, scale=2.0)
  assert_eq(img.get_width(), 4.0)
  assert_eq(img.get_height(), 2.0)
  assert_eq(img.get_scale_factor(), 2.0)
  assert_eq(img.pixels.width, 8)
}

///|
test "Image::resize 放大后实心色保持" {
  let bm = Bitmap::new(2, 2)
  let p = Painter::new(bm)
  fill_color(p, "#3366cc", 2)
  p.end()
  let img = Image::from_bitmap(bm)
  let big = img.resize(8.0, 8.0)
  assert_eq(big.pixels.width, 8)
  assert_eq(big.pixels.height, 8)
  assert_eq(big.get_width(), 8.0)
  let c = big.pixels.pixel(4, 4)
  assert_eq((c.r, c.g, c.b, c.a), (0x33, 0x66, 0xcc, 255))
  // 原图不变
  assert_eq(img.pixels.width, 2)
}

///|
/// 4x4 画布：左上红、右上绿、左下蓝、右下白。
fn quad_canvas() -> Canvas {
  let cv = Canvas::new(4.0, 4.0)
  let p = cv.get_painter()
  p.set_fill_color("#ff0000")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.set_fill_color("#00ff00")
  p.fill_rect(2.0, 0.0, 2.0, 2.0)
  p.set_fill_color("#0000ff")
  p.fill_rect(0.0, 2.0, 2.0, 2.0)
  p.set_fill_color("#ffffff")
  p.fill_rect(2.0, 2.0, 2.0, 2.0)
  p.end()
  cv
}

///|
test "draw_canvas：整图放大 2 倍" {
  let cv = quad_canvas()
  let bm = Bitmap::new(8, 8)
  let p = Painter::new(bm)
  p.draw_canvas(cv, 0.0, 0.0, 8.0, 8.0)
  p.end()
  assert_eq(bm.pixel(1, 1).r, 255)
  assert_eq(bm.pixel(6, 1).g, 255)
  assert_eq(bm.pixel(1, 6).b, 255)
  assert_eq(bm.pixel(6, 6).r, 255)
  assert_eq(bm.pixel(6, 6).g, 255)
  assert_eq(bm.pixel(6, 6).b, 255)
}

///|
test "draw_canvas_from_rect：取左上象限铺到 4x4" {
  let cv = quad_canvas()
  let bm = Bitmap::new(4, 4)
  let p = Painter::new(bm)
  p.draw_canvas_from_rect(cv, 0.0, 0.0, 2.0, 2.0, 0.0, 0.0, 4.0, 4.0)
  p.end()
  // 全是红（放大后内部像素不掺邻块色）
  for y = 0; y < 4; y = y + 1 {
    for x = 0; x < 4; x = x + 1 {
      let c = bm.pixel(x, y)
      assert_eq((c.r, c.g, c.b, c.a), (255, 0, 0, 255))
    }
  }
}

///|
test "blit 尊重当前混合模式" {
  let cv = Canvas::new(2.0, 2.0)
  let cp = cv.get_painter()
  cp.set_fill_color("#ff0000")
  cp.fill_rect(0.0, 0.0, 2.0, 2.0)
  cp.end()
  let bm = Bitmap::new(2, 2)
  let p = Painter::new(bm)
  p.set_fill_color("#8040c0")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.set_blend_mode(Multiply)
  p.draw_canvas(cv, 0.0, 0.0, 2.0, 2.0)
  p.end()
  let c = bm.pixel(1, 1)
  // 乘算：红 × (128,64,192) = (128,0,0)
  assert_eq((c.r - 128).abs() <= 2, true)
  assert_eq(c.g <= 2, true)
  assert_eq(c.b <= 2, true)
}

///|
test "PNG 落盘再读回：像素不变" {
  let cv = quad_canvas()
  let path = "/tmp/moonbit-native-render-wbtest.png"
  assert_eq(cv.write_to_file("png", path), true)
  assert_eq(cv.write_to_file("bmp", path), false)
  let img = Image::new_from_file(path)
  assert_eq(img.is_empty(), false)
  assert_eq(img.pixels.width, 4)
  assert_eq(img.pixels.height, 4)
  for y = 0; y < 4; y = y + 1 {
    for x = 0; x < 4; x = x + 1 {
      let a = cv.bitmap.pixel(x, y)
      let b = img.pixels.pixel(x, y)
      assert_eq((a.r, a.g, a.b, a.a), (b.r, b.g, b.b, b.a))
    }
  }
}
