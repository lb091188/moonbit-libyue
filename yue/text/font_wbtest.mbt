// 字体与富文本回归：换行/省略/对齐的语义口径 + AttributedText 属性面。
// 不断言具体像素宽高（随机器字体变），只断相对位置、单调性与约束——
// 唯一锁死的绝对值是「单行高度与多行高度的大小关系」这类结构性事实。

///|
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
/// 空图给哨兵 (0,0,-1,-1)：调用点的「x1 >= 0」断言会把它暴露出来，
/// 同时避免在无 error 签名的辅助函数里用 assert（工具链限制）。
fn box_of(bm : @render.Bitmap) -> (Int, Int, Int, Int) {
  match painted_box(bm) {
    Some(b) => b
    None => (0, 0, -1, -1)
  }
}

///|
test "wrap=false 单行自然宽：宽度不折行（与 wrap=true 的高度对照）" {
  let t = "the quick brown fox jumps over the lazy dog"
  match (
    measure(t, 14.0, max_width=120, wrap=false),
    measure(t, 14.0, max_width=120, wrap=true),
  ) {
    (Some(one), Some(many)) => {
      // 不换行：高度按单行，宽度按自然宽（可超出约束）
      assert_eq(many.height > one.height, true)
      assert_eq(one.width > 120, true)
      assert_eq(many.width <= 120 + 2, true)
    }
    _ => assert_eq(false, true)
  }
}

///|
test "省略：单行截断且宽度受钳" {
  let t = "the quick brown fox jumps over the lazy dog"
  let bm = @render.Bitmap::new(80, 20)
  let f = Font::new("", 14.0)
  assert_eq(
    draw_in_box(
      bm,
      0.0,
      0.0,
      60.0,
      20.0,
      t,
      f,
      "#000",
      ellipsize=true,
      wrap=false,
    ),
    true,
  )
  let (x0, _, x1, _) = box_of(bm)
  assert_eq(x1 >= 0, true)
  assert_eq(x1 - x0 + 1 <= 62, true)
}

///|
test "字重参与度量（粗体不窄于常规）" {
  let t = "Wg jQ 中文宽度"
  let n = Font::new("", 14.0)
  let b = Font::new("", 14.0, weight=Bold)
  match (measure_font(t, n), measure_font(t, b)) {
    (Some(mn), Some(mb)) => {
      assert_eq(mn.width > 0, true)
      assert_eq(mb.width >= mn.width, true)
    }
    _ => assert_eq(false, true)
  }
  match (line_height_font(n), line_height_font(b)) {
    (Some(hn), Some(hb)) => {
      assert_eq(hn > 0, true)
      assert_eq(hb > 0, true)
    }
    _ => assert_eq(false, true)
  }
}

///|
test "盒内水平对齐：start < center < end，且 center 居中" {
  let f = Font::new("", 14.0)
  let make = fn(a : TextAlign) -> (Int, Int, Int, Int) {
    let bm = @render.Bitmap::new(200, 24)
    let _ = draw_in_box(bm, 0.0, 0.0, 200.0, 24.0, "Xg", f, "#000", align=a)
    box_of(bm)
  }
  let (sx0, _, sx1, _) = make(Start)
  let (cx0, _, cx1, _) = make(Center)
  let (ex0, _, ex1, _) = make(End)
  assert_eq(sx1 >= 0 && cx1 >= 0 && ex1 >= 0, true)
  let sc = (sx0 + sx1).to_double() / 2.0
  let cc = (cx0 + cx1).to_double() / 2.0
  let ec = (ex0 + ex1).to_double() / 2.0
  assert_eq(sc < cc, true)
  assert_eq(cc < ec, true)
  assert_eq((cc - 100.0).abs() <= 10.0, true)
  assert_eq(ex1 <= 200, true)
}

///|
test "盒内垂直对齐：start < center < end，且 center 居盒中" {
  let f = Font::new("", 14.0)
  let make = fn(a : TextAlign) -> (Int, Int, Int, Int) {
    let bm = @render.Bitmap::new(60, 80)
    let _ = draw_in_box(bm, 0.0, 0.0, 60.0, 80.0, "Xg", f, "#000", valign=a)
    box_of(bm)
  }
  let (_, sy0, _, _) = make(Start)
  let (_, cy0, _, cy1) = make(Center)
  let (_, ey0, _, _) = make(End)
  assert_eq(cy1 >= 0, true)
  assert_eq(sy0 < cy0, true)
  assert_eq(cy0 < ey0, true)
  let cc = (cy0 + cy1).to_double() / 2.0
  assert_eq((cc - 40.0).abs() <= 12.0, true)
}

///|
test "AttributedText：属性面与包围盒" {
  let at = AttributedText::new("hello world")
  assert_eq(at.get_text(), "hello world")
  at.set_text("again")
  assert_eq(at.get_text(), "again")
  at.set_font(Font::new("", 20.0))
  at.set_color("#336699")
  assert_eq(at.effective_font().size, 20.0)
  let natural = at.get_bounds_for(0.0, 0.0)
  assert_eq(natural.width > 0.0, true)
  assert_eq(natural.height > 0.0, true)
  // 默认 wrap=true：窄盒里高度不小于单行
  at.set_text("the quick brown fox jumps over the lazy dog")
  let wrapped = at.get_bounds_for(80.0, 0.0)
  assert_eq(wrapped.height >= natural.height, true)
  // 单行属性：wrap=false 且省略 → 高度回到单行
  let at2 = AttributedText::new(
    "the quick brown fox jumps over the lazy dog",
    wrap=false,
    ellipsis=true,
  )
  let one_line = at2.get_bounds_for(80.0, 0.0)
  assert_eq(one_line.height < wrapped.height, true)
  at.clear()
  assert_eq(at.get_text(), "")
}

///|
test "new_with 与 format 往返" {
  let attrs : TextAttributes = {
    align: Center,
    valign: End,
    wrap: false,
    ellipsis: true,
    font: Some(Font::new("", 12.0, weight=SemiBold)),
    color: Some("#ff0000"),
  }
  let at = AttributedText::new_with("x", attrs)
  let f = at.get_format()
  assert_eq(align_id(f.align), 1)
  assert_eq(align_id(f.valign), 2)
  assert_eq(f.wrap, false)
  assert_eq(f.ellipsis, true)
  assert_eq(at.effective_font().size, 12.0)
  let fmt = TextFormat::new()
  assert_eq(fmt.wrap, true)
  at.set_format(fmt)
  assert_eq(at.get_format().wrap, true)
  assert_eq(align_id(at.get_format().align), 0)
  assert_eq(font_body().size, 13.0)
}
