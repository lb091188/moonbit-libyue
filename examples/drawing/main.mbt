// 复刻自 yue-sample-apps/drawing：Painter 能力展示（9 组绘制 + 离屏画布）。
// 颜色数值（Color.argb）在 MoonBit 侧转 hex，不进 C 层。

///|
let image_prefix = "examples/drawing/"

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
fn argb_hex(a : Int, r : Int, g : Int, b : Int) -> String {
  let sb = StringBuilder()
  for v in [a, r, g, b] {
    sb.write_char(hex_digit((v >> 4) & 15))
    sb.write_char(hex_digit(v & 15))
  }
  "#" + sb.to_string()
}

///|
fn draw_example1(painter : @yue.Painter) -> Unit {
  for i = 0; i <= 5; i = i + 1 {
    for j = 0; j <= 5; j = j + 1 {
      let ch = (255.0 - 42.5 * i.to_double()).floor().to_int()
      let cv = (255.0 - 42.5 * j.to_double()).floor().to_int()
      painter.set_fill_color(argb_hex(255, ch, cv, 0))
      painter.fill_rect(j.to_double() * 25.0, i.to_double() * 25.0, 25.0, 25.0)
    }
  }
}

///|
fn draw_example2(painter : @yue.Painter) -> Unit {
  painter.set_stroke_color("#550000")
  painter.set_fill_color("#D46A6A")
  painter.begin_path()
  painter.move_to(25.0, 25.0)
  painter.line_to(105.0, 25.0)
  painter.line_to(25.0, 105.0)
  painter.close_path()
  painter.fill()
  painter.begin_path()
  painter.move_to(125.0, 125.0)
  painter.line_to(125.0, 45.0)
  painter.line_to(45.0, 125.0)
  painter.close_path()
  painter.stroke()
}

///|
fn draw_example3(painter : @yue.Painter) -> Unit {
  painter.begin_path()
  painter.move_to(75.0, 40.0)
  painter.bezier_curve_to(75.0, 37.0, 70.0, 25.0, 50.0, 25.0)
  painter.bezier_curve_to(20.0, 25.0, 20.0, 62.5, 20.0, 62.5)
  painter.bezier_curve_to(20.0, 80.0, 40.0, 102.0, 75.0, 120.0)
  painter.bezier_curve_to(110.0, 102.0, 130.0, 80.0, 130.0, 62.5)
  painter.bezier_curve_to(130.0, 62.5, 130.0, 25.0, 100.0, 25.0)
  painter.bezier_curve_to(85.0, 25.0, 75.0, 37.0, 75.0, 40.0)
  painter.fill()
}

///|
fn draw_example4(painter : @yue.Painter, pi : Double) -> Unit {
  painter.begin_path()
  painter.arc(75.0, 75.0, 50.0, 0.0, pi * 2.0)
  painter.move_to(110.0, 75.0)
  painter.arc(75.0, 75.0, 35.0, 0.0, pi)
  painter.move_to(65.0, 65.0)
  painter.arc(60.0, 65.0, 5.0, 0.0, pi * 2.0)
  painter.move_to(95.0, 65.0)
  painter.arc(90.0, 65.0, 5.0, 0.0, pi * 2.0)
  painter.stroke()
}

///|
fn rounded_rect(
  painter : @yue.Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  pi : Double,
) -> Unit {
  let deg = pi / 180.0
  painter.begin_path()
  painter.arc(x + w - radius, y + radius, radius, -90.0 * deg, 0.0)
  painter.arc(x + w - radius, y + h - radius, radius, 0.0, 90.0 * deg)
  painter.arc(x + radius, y + h - radius, radius, 90.0 * deg, 180.0 * deg)
  painter.arc(x + radius, y + radius, radius, 180.0 * deg, 270.0 * deg)
  painter.close_path()
  painter.stroke()
}

///|
fn draw_example5(painter : @yue.Painter, pi : Double) -> Unit {
  painter.save()
  painter.clip_rect(0.0, 0.0, 150.0, 150.0)
  rounded_rect(painter, 12.0, 12.0, 150.0, 150.0, 15.0, pi)
  rounded_rect(painter, 19.0, 19.0, 150.0, 150.0, 9.0, pi)
  rounded_rect(painter, 53.0, 53.0, 49.0, 33.0, 10.0, pi)
  rounded_rect(painter, 53.0, 119.0, 49.0, 16.0, 6.0, pi)
  rounded_rect(painter, 135.0, 53.0, 49.0, 33.0, 10.0, pi)
  rounded_rect(painter, 135.0, 119.0, 25.0, 49.0, 10.0, pi)
  painter.set_fill_color("#000")
  painter.begin_path()
  painter.arc(37.0, 37.0, 13.0, pi / 7.0, -pi / 7.0)
  painter.line_to(31.0, 37.0)
  painter.fill()
  for i = 0; i <= 7; i = i + 1 {
    painter.fill_rect(51.0 + i.to_double() * 16.0, 35.0, 4.0, 4.0)
  }
  for i = 0; i <= 5; i = i + 1 {
    painter.fill_rect(115.0, 51.0 + i.to_double() * 16.0, 4.0, 4.0)
  }
  for i = 0; i <= 7; i = i + 1 {
    painter.fill_rect(51.0 + i.to_double() * 16.0, 99.0, 4.0, 4.0)
  }
  painter.begin_path()
  painter.move_to(83.0, 116.0)
  painter.line_to(83.0, 102.0)
  painter.bezier_curve_to(83.0, 94.0, 89.0, 88.0, 97.0, 88.0)
  painter.bezier_curve_to(105.0, 88.0, 111.0, 94.0, 111.0, 102.0)
  painter.line_to(111.0, 116.0)
  painter.line_to(106.333, 111.333)
  painter.line_to(101.666, 116.0)
  painter.line_to(97.0, 111.333)
  painter.line_to(92.333, 116.0)
  painter.line_to(87.666, 111.333)
  painter.line_to(83.0, 116.0)
  painter.fill()
  painter.set_fill_color("#FFF")
  painter.begin_path()
  painter.move_to(91.0, 96.0)
  painter.bezier_curve_to(88.0, 96.0, 87.0, 99.0, 87.0, 101.0)
  painter.bezier_curve_to(87.0, 103.0, 88.0, 106.0, 91.0, 106.0)
  painter.bezier_curve_to(94.0, 106.0, 95.0, 103.0, 95.0, 101.0)
  painter.bezier_curve_to(95.0, 99.0, 94.0, 96.0, 91.0, 96.0)
  painter.move_to(103.0, 96.0)
  painter.bezier_curve_to(100.0, 96.0, 99.0, 99.0, 99.0, 101.0)
  painter.bezier_curve_to(99.0, 103.0, 100.0, 106.0, 103.0, 106.0)
  painter.bezier_curve_to(106.0, 106.0, 107.0, 103.0, 107.0, 101.0)
  painter.bezier_curve_to(107.0, 99.0, 106.0, 96.0, 103.0, 96.0)
  painter.fill()
  painter.set_fill_color("#000")
  painter.begin_path()
  painter.arc(101.0, 102.0, 2.0, 0.0, pi * 2.0, ccw=true)
  painter.fill()
  painter.begin_path()
  painter.arc(89.0, 102.0, 2.0, 0.0, pi * 2.0, ccw=true)
  painter.fill()
  painter.restore()
}

///|
fn draw_example6(painter : @yue.Painter, pi : Double) -> Unit {
  painter.save()
  painter.rotate(pi / 4.0)
  let text = @yue.AttributedText::new("draw example 6", align=@yue.Center)
  let ts = text.get_bounds_for(150.0, 150.0)
  let (bw, bh) = (ts.width, ts.height)
  painter.stroke_rect(75.0, 0.0, bw, bh)
  painter.draw_attributed_text(text, 75.0, 0.0, bw, bh)
  painter.restore()
}

///|
fn draw_example7(painter : @yue.Painter) -> Unit {
  let text = @yue.AttributedText::new("draw example 7", align=@yue.Center)
  text.set_font(@yue.Font::new("Arial", 18.0))
  let ts = text.get_bounds_for(150.0, 150.0)
  let (bw, bh) = (ts.width, ts.height)
  painter.draw_attributed_text(text, (150.0 - bw) / 2.0, 75.0 - bh, bw, bh)
  painter.save()
  painter.scale(1.0, -1.0)
  text.set_color("#888")
  painter.draw_attributed_text(
    text,
    (150.0 - bw) / 2.0,
    -150.0 + (75.0 - bh),
    bw,
    bh,
  )
  painter.restore()
}

///|
fn draw_example8(painter : @yue.Painter) -> Unit {
  let (x, y, w, h) = (10.0, 10.0, 130.0, 130.0)
  rounded_rect(painter, x, y, w, h, 3.0, @math.PI)
  painter.draw_text("aaa", x, y, w, h, align=@yue.Start, valign=@yue.Start)
  painter.draw_text("bbb", x, y, w, h, align=@yue.End, valign=@yue.Start)
  painter.draw_text("ccc", x, y, w, h, align=@yue.Start, valign=@yue.End)
  painter.draw_text("ddd", x, y, w, h, align=@yue.End, valign=@yue.End)
  painter.draw_text("eee", x, y, w, h, align=@yue.Center, valign=@yue.Center)
}

///|
fn draw_example9(painter : @yue.Painter) -> Unit {
  let picture = @yue.Image::new_from_file("\{image_prefix}rhino.jpg")
  painter.draw_image_from_rect(
    picture, 33.0, 71.0, 104.0, 124.0, 32.0, 21.0, 85.0, 102.0,
  )
  let frame = @yue.Image::new_from_file("\{image_prefix}frame.png")
  let fw = frame.get_width()
  let fh = frame.get_height()
  painter.draw_image(frame, 10.0, 0.0, fw, fh)
}

///|
fn draw_all(painter : @yue.Painter, pi : Double) -> Unit {
  draw_example1(painter)
  painter.translate(150.0, 0.0)
  draw_example2(painter)
  painter.translate(150.0, 0.0)
  draw_example3(painter)
  painter.translate(-300.0, 150.0)
  draw_example4(painter, pi)
  painter.translate(150.0, 0.0)
  draw_example5(painter, pi)
  painter.translate(150.0, 0.0)
  draw_example6(painter, pi)
  painter.translate(-300.0, 150.0)
  draw_example7(painter)
  painter.translate(150.0, 0.0)
  draw_example8(painter)
  painter.translate(150.0, 0.0)
  draw_example9(painter)
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  // 先在离屏画布上完成全部绘制，窗口刷新时整块贴上
  let canvas = @yue.Canvas::new(450.0, 450.0)
  draw_all(canvas.get_painter(), @math.PI)
  let win = @yue.Window::new()
  win.set_content_size(500.0, 500.0)
  win.on_close(fn(_window) { @yue.quit() })
  let content = @yue.Container::new()
  content.set_background_color("#FFF")
  content.set_style("flexGrow", 1.0)
  win.set_content(content)
  content.on_draw(fn(painter) {
    painter.draw_canvas(canvas, 25.0, 25.0, 450.0, 450.0)
  })
  win.center()
  win.activate()
  @yue.run()
}
