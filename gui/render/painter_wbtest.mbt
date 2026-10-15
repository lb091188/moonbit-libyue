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

///|
test "set_global_alpha：钳到 0..1，填充/描边/渐变/图片全路径按系数落像素" {
  let bm = Bitmap::new(10, 10)
  let p = Painter::new(bm)
  p.set_global_alpha(1.5)
  assert_eq(p.global_alpha(), 1.0)
  p.set_global_alpha(-1.0)
  assert_eq(p.global_alpha(), 0.0)
  // 判据用同机对照:先 1.0 全不透明落一版,再半透明落一版比 alpha
  p.set_global_alpha(1.0)
  p.set_fill_color("#ff0000")
  p.fill_rect(0.0, 0.0, 10.0, 10.0)
  let full = bm.pixel(5, 5)
  assert_true(full.a > 200)
  let bm2 = Bitmap::new(10, 10)
  let p2 = Painter::new(bm2)
  p2.set_fill_color("#ff0000")
  p2.set_global_alpha(0.5)
  p2.fill_rect(0.0, 0.0, 10.0, 10.0)
  let half = bm2.pixel(5, 5)
  // 半透明那一版必须比全不透明淡（两后端同判据：alpha 约为半）
  assert_true(half.a > 0 && half.a < full.a)
  let ratio = half.a.to_double() / full.a.to_double()
  assert_true(ratio > 0.25 && ratio < 0.8)
  p2.end()
  // 图片/画布路径：源像素 alpha 同样乘系数（透明目标上判,alpha=0 应无痕）
  let src = Bitmap::new(4, 4)
  let sp = Painter::new(src)
  sp.set_fill_color("#00ff00")
  sp.fill_rect(0.0, 0.0, 4.0, 4.0)
  sp.end()
  let bm3 = Bitmap::new(10, 10)
  let p3 = Painter::new(bm3)
  p3.set_global_alpha(0.0)
  p3.draw_canvas({ bitmap: src }, 0.0, 0.0, 4.0, 4.0)
  assert_eq(bm3.pixel(1, 1).a, 0)
  p3.set_global_alpha(1.0)
  p3.draw_canvas({ bitmap: src }, 0.0, 0.0, 4.0, 4.0)
  assert_true(bm3.pixel(1, 1).a > 200)
  p3.end()
  // 渐变路径：stop alpha 同乘（透明目标上判）
  let grad = Gradient::linear(0.0, 0.0, 10.0, 0.0)
  grad.add_stop(0.0, "#ff0000")
  grad.add_stop(1.0, "#ff0000")
  let bm4 = Bitmap::new(10, 10)
  let p4 = Painter::new(bm4)
  p4.set_fill_gradient(grad)
  p4.fill_rect(0.0, 0.0, 10.0, 10.0)
  let full_g = bm4.pixel(5, 5)
  let bm5 = Bitmap::new(10, 10)
  let p5 = Painter::new(bm5)
  p5.set_global_alpha(0.25)
  p5.set_fill_gradient(grad)
  p5.fill_rect(0.0, 0.0, 10.0, 10.0)
  let g25 = bm5.pixel(5, 5)
  assert_true(
    full_g.a > 200 && g25.a > 0 && g25.a < 100,
  )
  p4.end()
  p5.end()
  p.end()
}

///|
test "fill_round_rect：四角不填、中心填；半径钳到短边一半" {
  let bm = Bitmap::new(20, 20)
  let p = Painter::new(bm)
  p.set_fill_color("#334455")
  p.fill_round_rect(0.0, 0.0, 20.0, 20.0, 6.0)
  assert_eq(bm.pixel(10, 10).a, 255)
  // 左上角点在对角线外侧（圆角外），应保持透明
  assert_eq(bm.pixel(0, 0).a, 0)
  // r 超短边一半：钳到 10 后仍填满中心
  p.fill_round_rect(0.0, 0.0, 20.0, 20.0, 99.0)
  assert_eq(bm.pixel(10, 10).a, 255)
  p.end()
}

///|
test "box_shadow：外圈色带等浓度，角上不缺、本体不被着色" {
  let bm = Bitmap::new(200, 160)
  let p = Painter::new(bm)
  p.set_stroke_color("#000000")
  p.box_shadow(40.0, 40.0, 120.0, 80.0, 8.0, 8.0)
  // 直边中点：左边缘外 4px（色带铺满 [0,8]）
  assert_true(bm.pixel(36, 80).a > 200)
  // 四个角的 45° 方向：各角弧心半径 12 处（内外边界正中）也必须在色带里。
  // 旧画法在这里挖不出洞——角上要么缺一块、要么叠成深色圆斑。
  assert_true(bm.pixel(39, 39).a > 200)
  assert_true(bm.pixel(161, 39).a > 200)
  assert_true(bm.pixel(39, 121).a > 200)
  assert_true(bm.pixel(161, 121).a > 200)
  // 本体内部与远处都不该有阴影浓度
  assert_eq(bm.pixel(100, 80).a, 0)
  assert_eq(bm.pixel(20, 20).a, 0)
  assert_eq(bm.pixel(180, 140).a, 0)
  p.end()
}

///|
/// 两后端同口径：`fill()`/`stroke()` 落笔即清路径（cairo_fill/cairo_stroke 语义）。
/// 不清的话，下一笔会把上一笔的子路径**按当前平移系**重画一遍——每只控件都在
/// 自己的原点里画，跨控件漏过来的旧路径就成了画面上凭空多出的色块。
test "fill 与 stroke 用完即清路径，第二笔不带上第一笔" {
  let p = Painter::new(Bitmap::new(16, 16))
  p.set_fill_color("#ff0000")
  p.begin_path()
  p.move_to(1.0, 1.0)
  p.line_to(7.0, 1.0)
  p.line_to(1.0, 7.0)
  p.close_path()
  p.fill()
  assert_eq(rgba(p, 2, 2), (255, 0, 0, 255))
  p.set_fill_color("#00ff00")
  p.move_to(9.0, 9.0)
  p.line_to(14.0, 9.0)
  p.line_to(9.0, 14.0)
  p.close_path()
  p.fill()
  // 第一笔的三角里仍是红：绿填充没把它连着重画
  assert_eq(rgba(p, 2, 2), (255, 0, 0, 255))
  assert_eq(rgba(p, 10, 10), (0, 255, 0, 255))
  // 描边同样清：绿三角不该在红三角上留边
  p.set_stroke_color("#0000ff")
  p.set_line_width(1.0)
  p.move_to(9.0, 9.0)
  p.line_to(14.0, 9.0)
  p.line_to(9.0, 14.0)
  p.close_path()
  p.stroke()
  assert_eq(rgba(p, 2, 2), (255, 0, 0, 255))
  p.end()
}

///|
/// 两后端同口径：1px 圆角描边是**居中式**描边，四条直段都必须有墨。
/// 光栅器早先把矩形取整到整数边、覆盖又按像素中心量，`hw=0.5` 时中心到整数
/// 边的重叠恒为 0 → 四条直段整段消失、只剩角部一圈（cairo 一直画得出）。
test "stroke_round_rect：1px 圆角边框四条直段都落墨" {
  let bm = Bitmap::new(40, 40)
  let p = Painter::new(bm)
  p.set_stroke_color("#ff0000")
  p.set_line_width(1.0)
  // 边压在格中心（0.5）→ 1px 描边正好落满一格：四边中点各一条实心
  p.stroke_round_rect(0.5, 0.5, 30.0, 30.0, 4.0)
  assert_eq(rgba(p, 15, 0).3, 255)
  assert_eq(rgba(p, 15, 30).3, 255)
  assert_eq(rgba(p, 0, 15).3, 255)
  assert_eq(rgba(p, 30, 15).3, 255)
  // 角弧外（左上角点离弧心 (4.5,4.5) 距离 5.66 > rr+hw）与框内都不该有墨
  assert_eq(rgba(p, 0, 0).3, 0)
  assert_eq(rgba(p, 15, 15).3, 0)
  // 边压在整数边界（y=4.0）：环带跨 3、4 两行各摊一半墨，直段仍要在
  p.stroke_round_rect(4.0, 4.0, 20.0, 20.0, 3.0)
  assert_true(rgba(p, 14, 4).3 > 60, msg="压整数边的 1px 描边直段没落墨")
  p.end()
}
