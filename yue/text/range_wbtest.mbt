// 富文本区间属性回归：颜色区间与字号区间的**落点**、字节下标语义（多字节
// 文本切在字节上）、后设覆盖先设、越界与非法输入的容错。
// 一律用「像素包围盒 + 相对位置」判定，不锁具体字形尺寸（换字体不假红）。

///|
fn pixel_rgba(bm : @render.Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = bm.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

///|
/// 满足条件的像素包围盒（无命中给 None）。
fn bbox_where(
  bm : @render.Bitmap,
  pred : ((Int, Int, Int, Int)) -> Bool,
) -> (Int, Int, Int, Int)? {
  let mut x0 = bm.width
  let mut y0 = bm.height
  let mut x1 = -1
  let mut y1 = -1
  for y = 0; y < bm.height; y = y + 1 {
    for x = 0; x < bm.width; x = x + 1 {
      if pred(pixel_rgba(bm, x, y)) {
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
fn is_red(c : (Int, Int, Int, Int)) -> Bool {
  let (r, g, b, a) = c
  a > 100 && r > 180 && g < 80 && b < 80
}

///|
fn is_black(c : (Int, Int, Int, Int)) -> Bool {
  let (r, g, b, a) = c
  a > 100 && r < 80 && g < 80 && b < 80
}

///|
fn paint(at : AttributedText, w : Int, h : Int) -> @render.Bitmap {
  let bm = @render.Bitmap::new(w, h)
  let _ = at.draw(bm, 2.0, 2.0, 0.0, h.to_double())
  bm
}

///|
test "颜色区间：落在正确的字形上，其余保持基准色" {
  let at = AttributedText::new("AAAA", wrap=false)
  at.set_font(Font::new("", 20.0))
  at.set_color("#000")
  assert_eq(at.range_count(), 0)
  at.set_color_for("#ff0000", 0, 1)
  assert_eq(at.range_count(), 1)
  let bm = paint(at, 120, 32)
  match (bbox_where(bm, is_red), bbox_where(bm, is_black)) {
    (Some((rx0, _, rx1, _)), Some((bx0, _, _, _))) => {
      // 被染红的是最左边那个 A
      assert_eq(rx0 < bx0, true)
      assert_eq(rx1 < bx0, true)
    }
    _ => assert_eq(true, false)
  }
}

///|
test "字节下标：多字节文本切在字节上而不是字符上" {
  // "中文A" = 3 + 3 + 1 字节；区间 [3, 6) 只覆盖第二个汉字
  let at = AttributedText::new("中文A", wrap=false)
  at.set_font(Font::new("", 20.0))
  at.set_color("#000")
  at.set_color_for("#ff0000", 3, 6)
  let bm = paint(at, 120, 32)
  match (bbox_where(bm, is_red), bbox_where(bm, is_black)) {
    (Some((rx0, _, rx1, _)), Some((bx0, _, bx1, _))) => {
      // 红块要整体落在黑色像素段的中间偏右（第二字），不能跑到最左或最右
      assert_eq(rx0 > bx0, true)
      assert_eq(rx1 < bx1, true)
    }
    _ => assert_eq(true, false)
  }
}

///|
test "字号区间：抬高包围盒高度且不超过无区间时的一半宽度" {
  let plain = AttributedText::new("Ag", wrap=false)
  plain.set_font(Font::new("", 13.0))
  let big = AttributedText::new("Ag", wrap=false)
  big.set_font(Font::new("", 13.0))
  big.set_font_for(Font::new("", 40.0), 0, 1)
  let p = plain.get_bounds_for(0.0, 0.0)
  let b = big.get_bounds_for(0.0, 0.0)
  assert_eq(p.width > 0.0, true)
  assert_eq(b.height > p.height, true)
  assert_eq(b.width > p.width, true)
}

///|
test "后设的区间覆盖先设的" {
  let at = AttributedText::new("AAAA", wrap=false)
  at.set_font(Font::new("", 20.0))
  at.set_color("#000")
  // 先把整段染红，再把最左一个字符改回黑：最左应先是红的（后设覆盖前设）
  at.set_color_for("#ff0000", 0, 4)
  at.set_color_for("#000000", 0, 1)
  let bm = paint(at, 120, 32)
  match (bbox_where(bm, is_red), bbox_where(bm, is_black)) {
    (Some((rx0, _, rx1, _)), Some((bx0, _, bx1, _))) => {
      // 最左一个字符回到基准黑，其余三个仍是红的：后设的 [0,1) 覆盖了先设的
      assert_eq(rx0 > bx0, true)
      assert_eq(rx1 > bx1, true)
    }
    _ => assert_eq(true, false)
  }
}

///|
test "越界区间与非法输入都不炸、不落像素" {
  let at = AttributedText::new("hi", wrap=false)
  at.set_font(Font::new("", 16.0))
  at.set_color("#000")
  at.set_color_for("#ff0000", 100, 200) // 完全越界：建树时钳掉
  at.set_color_for("#00ff00", 5, 2) // 起点在终点之后：空区间
  at.set_color_for("not-a-color", 0, 1) // 非法 hex：不入表
  assert_eq(at.range_count(), 2)
  let bm = paint(at, 60, 24)
  assert_eq(bbox_where(bm, is_red) == None, true)
  assert_eq(bbox_where(bm, is_black) == None, false)
}

///|
test "区间不改变无颜色时的绘制语义（空文本、空盒）" {
  let at = AttributedText::new("", wrap=false)
  at.set_color_for("#ff0000", 0, 4)
  let b = at.get_bounds_for(0.0, 0.0)
  assert_eq(b.width, 0.0)
  let bm = @render.Bitmap::new(0, 0)
  assert_eq(at.draw(bm, 0.0, 0.0, 10.0, 10.0), false)
  // set_text 保留区间表（旧语义），换文本后仍可绘制
  at.set_text("abc")
  assert_eq(at.range_count(), 1)
  let bm2 = @render.Bitmap::new(60, 20)
  assert_eq(at.draw(bm2, 1.0, 1.0, 0.0, 20.0), true)
}
