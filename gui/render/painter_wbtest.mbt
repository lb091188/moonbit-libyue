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
/// 真投影（`drop_shadow` = 偏移 + 羽化）：分层同心外扩的填充，浓度从本体边向外
/// 线性褪去。这条同时钉住三件事——**有方向**（dy>0 时下方比上方多出去一段）、
/// **是软边**（沿距离出现多档浓度，不是等浓度的一圈）、**角与边同距离同浓度**
/// （旧版靠「外环 + 反向内环挖洞」做不出来：两后端都没有反向弧，四角要么缺一块
/// 要么叠成深色圆斑）。本体区域内会累积浓度，这是有意的——调用方随后把本体画在
/// 上面盖住；本体背景透明时透出阴影，与 CSS 同义。
test "drop_shadow：偏移有方向、边缘有梯度、角边同浓度" {
  let bm = Bitmap::new(200, 160)
  let p = Painter::new(bm)
  // 本体 40,40,120x80 / 圆角 8，偏移 (0, 6)，模糊 8，颜色黑 25%
  p.drop_shadow(40.0, 40.0, 120.0, 80.0, 8.0, 8.0, 0.0, 6.0, "#00000040")
  // ① 方向：偏移后本体底边在 y=126，再往外 4px 仍有墨；顶边在 y=46，往上 10px
  //    早该褪干净（46-8=38）——上下不对称就是"悬浮在下方"
  assert_true(bm.pixel(100, 130).a > 0, msg="下方没有投出去")
  assert_eq(bm.pixel(100, 30).a, 0)
  // ② 梯度：左边 x=40 往外逐像素读，浓度单调不增且至少四档
  let mut prev = 100000
  let mut steps = 0
  let seen : Array[Int] = []
  for x = 39; x >= 32; x = x - 1 {
    let a = bm.pixel(x, 86).a
    assert_true(a <= prev, msg="左缘浓度往外反而变深：x=\{x}")
    prev = a
    if a > 0 && !seen.contains(a) {
      let _ = seen.push(a)
      steps += 1
    }
  }
  assert_true(steps >= 4, msg="左缘只有 \{steps} 档浓度，不是软边")
  assert_true(bm.pixel(38, 86).a > bm.pixel(33, 86).a, msg="贴边不浓、远处不淡")
  assert_eq(bm.pixel(30, 86).a, 0, msg="超出模糊半径还有墨")
  // ③ 角与边同距离同浓度：左边中点 (36,86) 距本体边 3.5px；左上角弧心 (48,54)
  //    沿 45° 外推同样距离落在像素 (39,45)（实测距弧心 12.02 − 半径 8 ≈ 4）
  let edge = bm.pixel(36, 86).a
  let corner = bm.pixel(39, 45).a
  assert_true(edge > 0 && corner > 0, msg="角或边缺墨：\{edge} / \{corner}")
  assert_true((edge - corner).abs() <= 16, msg="角与边同距离浓度差太大：\{edge} vs \{corner}")
  // ④ 本体区域内确有累积（分层填充覆盖它，本体随后盖住）
  assert_true(bm.pixel(100, 86).a > 0)
  p.end()
}

///|
/// blur ≤ 0 / 尺寸非法 / 全透明颜色都不落墨；只给 blur 不给偏移就是 CSS 的
/// 零偏移软边（四周对称）。
test "drop_shadow：无投影的几种输入都不落墨" {
  let p = Painter::new(Bitmap::new(40, 40))
  p.drop_shadow(10.0, 10.0, 20.0, 20.0, 2.0, 0.0, 0.0, 4.0, "#00000040")
  p.drop_shadow(10.0, 10.0, 0.0, 20.0, 2.0, 6.0, 0.0, 0.0, "#00000040")
  p.drop_shadow(10.0, 10.0, 20.0, 20.0, 2.0, 6.0, 0.0, 0.0, "#00000000")
  let mut ink = 0
  for y = 0; y < 40; y = y + 1 {
    for x = 0; x < 40; x = x + 1 {
      if rgba(p, x, y).3 > 0 {
        ink += 1
      }
    }
  }
  assert_eq(ink, 0)
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

///|
/// 两后端同口径：**整圆描边沿线一圈不断**。闭合折线描边时两条侧线各自成环
/// （外圈正向、内圈反向），缝成单条轮廓会在缝合处环绕相消——起点（角度 0）
/// 沿线留下空洞；miter 交点符号写反还会在每个接头处多咬掉一块。
test "整圆描边沿线一圈都有墨" {
  let bm = Bitmap::new(18, 18)
  let p = Painter::new(bm)
  p.set_stroke_color("#ff0000")
  p.set_line_width(1.3)
  p.begin_path()
  p.move_to(13.0, 9.0)
  p.arc(9.0, 9.0, 6.0, 0.0, 6.283185307179586)
  p.stroke()
  // 环带（到圆心距离 5.35~6.65）逐格扫一遍：落在带中间的格子都必须有墨
  let mut holes = 0
  for y = 2; y < 16; y = y + 1 {
    for x = 2; x < 16; x = x + 1 {
      let dx = x.to_double() + 0.5 - 9.0
      let dy = y.to_double() + 0.5 - 9.0
      let d = (dx * dx + dy * dy).sqrt()
      if d > 5.35 && d < 6.65 && rgba(p, x, y).3 <= 60 {
        holes += 1
      }
    }
  }
  assert_eq(holes, 0, msg="环沿线有 \{holes} 格断了")
  // 环心是空的：闭合两侧必须一正一反，否则整块填成实心板
  assert_eq(rgba(p, 9, 9).3, 0)
  p.end()
}

///|
/// 两后端同口径：直角接头的 miter 顶到外角（线宽一半处），不咬进内侧。
test "折线直角接头的 miter 顶到外角" {
  let bm = Bitmap::new(24, 24)
  let p = Painter::new(bm)
  p.set_stroke_color("#ff0000")
  p.set_line_width(4.0)
  p.begin_path()
  p.move_to(4.0, 16.0)
  p.line_to(16.0, 16.0)
  p.line_to(16.0, 4.0)
  p.stroke()
  // 两条臂的带内
  assert_eq(rgba(p, 10, 16).3, 255)
  assert_eq(rgba(p, 16, 10).3, 255)
  // 外角：miter 补到 (18,18)，格 (17,17) 全在带内
  assert_eq(rgba(p, 17, 17).3, 255)
  assert_eq(rgba(p, 18, 18).3, 0)
  // butt 端帽：起点之外的格子不落墨
  assert_eq(rgba(p, 3, 16).3, 0)
  assert_eq(rgba(p, 16, 3).3, 0)
  p.end()
}

///|
/// 两后端同口径：**分数坐标**的圆角矩形按精确设备边做边缘 AA——旧光栅器把
/// 矩形取整到整数格，四条直边完全不 AA、几何还整体偏移半格（圆角看着像像素画）。
test "fill_round_rect：分数边有边缘 AA 且不整体偏移" {
  let bm = Bitmap::new(12, 12)
  let p = Painter::new(bm)
  p.set_fill_color("#ff0000")
  p.fill_round_rect(0.5, 0.5, 10.0, 10.0, 3.0)
  // 左边压在 x=0.5（格中心）：第 0 列该是半墨，而不是整列空白或被推到第 1 列
  let a0 = rgba(p, 0, 5).3
  assert_true(a0 > 60 && a0 < 200, msg="左直边没做边缘 AA：\{a0}")
  assert_eq(rgba(p, 1, 5).3, 255)
  // 左上角是圆角：角点在弧外
  assert_eq(rgba(p, 0, 0).3, 0)
  p.end()
}

///|
/// 边缘灰级读数：一块画布里「半墨像素」的个数与**互不相同的 alpha 档数**。
/// 档数是「像素画感」的直接度量——只有极少几档时，曲线沿线的明暗是跳变的。
fn aa_levels(p : Painter, w : Int, h : Int) -> (Int, Int) {
  let seen : Array[Int] = []
  let mut n = 0
  for y = 0; y < h; y = y + 1 {
    for x = 0; x < w; x = x + 1 {
      let a = rgba(p, x, y).3
      if a > 0 && a < 255 {
        n += 1
        if !seen.contains(a) {
          let _ = seen.push(a)
        }
      }
    }
  }
  (n, seen.length())
}

///|
/// 两后端同口径：**圆/弧/圆环的边缘要有足够多的中间灰级**。
/// 光栅器原先是 4×4 采样点计数，覆盖只有 17 档、横向仅 4 档——实测 r=25 的
/// 填充圆整圈只有 8 档、r=6 的小圆（开关滑珠、单选圆心就是这个尺寸）只有
/// 2 档，真机看着是像素画。现改「纵向 8 子行 + 横向精确跨度」，这条按档数
/// 钉住（旧实现下三条判据全红）。
test "圆与圆环的边缘灰级（不再是像素画）" {
  let p = red_painter(80, 80)
  p.begin_path()
  p.move_to(65.0, 40.0)
  p.arc(40.0, 40.0, 25.0, 0.0, 6.283185307179586)
  p.fill()
  let (n25, l25) = aa_levels(p, 80, 80)
  assert_true(n25 >= 60, msg="r=25 填充圆的边缘格太少：\{n25}")
  assert_true(l25 >= 16, msg="r=25 填充圆的边缘只有 \{l25} 档灰级")
  p.end()

  let q = Painter::new(Bitmap::new(80, 80))
  q.set_stroke_color("#ff0000")
  q.set_line_width(2.0)
  q.begin_path()
  q.move_to(65.0, 40.0)
  q.arc(40.0, 40.0, 25.0, 0.0, 6.283185307179586)
  q.stroke()
  let (_nring, lring) = aa_levels(q, 80, 80)
  assert_true(lring >= 20, msg="lw=2 圆环沿线只有 \{lring} 档灰级")
  q.end()

  // 小尺寸才是真机最常见的（滑珠/圆心 r=6）：旧口径这里只有 2 档
  let s = red_painter(24, 24)
  s.begin_path()
  s.move_to(18.0, 12.0)
  s.arc(12.0, 12.0, 6.0, 0.0, 6.283185307179586)
  s.fill()
  let (_ns, ls) = aa_levels(s, 24, 24)
  assert_true(ls >= 4, msg="r=6 小圆只有 \{ls} 档灰级")
  s.end()
}

///|
/// 浅角度斜边也要有连续灰级。**注意**：正好 45° 的直线段几何上每个像素的相对
/// 位置相同，本来就只有约两档（实测 lw=1 与 lw=3 都是 2 档），那不是 AA 缺陷，
/// 所以这条判据用 32° 的线段。
test "浅角度斜线边缘的灰级连续" {
  let p = Painter::new(Bitmap::new(40, 40))
  p.set_stroke_color("#ff0000")
  p.set_line_width(1.5)
  p.begin_path()
  p.move_to(4.0, 30.0)
  p.line_to(36.0, 10.0)
  p.stroke()
  let (n, l) = aa_levels(p, 40, 40)
  assert_true(n >= 30, msg="32° 描边的边缘格太少：\{n}")
  assert_true(l >= 5, msg="32° 描边只有 \{l} 档灰级")
  p.end()
}
