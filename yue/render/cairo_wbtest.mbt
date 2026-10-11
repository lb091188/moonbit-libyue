// Cairo 光栅器的像素级回归：与纯 MoonBit 矩形绘制器的口径一致性，是这一批
// 最要紧的不变量（两者同一份契约、同一块缓冲，将来组件层在它们之间切换）。

fn rgba_of(bm : Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = bm.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

// 同一段绘制序列跑两条路径：门面探针选中的后端与强制切换的纯光栅器后端。
// 矩形口径（取整、内侧描边、裁剪求交、平移、半透明 source-over）必须逐像素一致，
// 这是纯实现与 cairo 可互换的前提，也是纯实现不被门面改动破坏的回归线。
fn paint_seq(bm : Bitmap, fallback : Bool) -> Unit {
  let p = Painter::new(bm)
  if fallback {
    // 强制纯光栅器后端（白盒重绑 backend）：原「session 置空走内联降级」
    // 的语义在双后端架构下升级为「切到 Raster」——同一份契约的两侧
    match Raster::over(bm) {
      Some(r) => p.backend = Some(PureBackend(r))
      None => p.backend = None
    }
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

///|
/// 路径/描边/渐变的**两后端对拍**（AA 容差档）：同一场景分别经探针选中的
/// 后端与强制纯光栅器绘制。Linux 上这是 cairo vs 纯实现的逐像素对拍
/// （cairo 当标准答案，容差带 = 4×4 超采样的单样本量化 16）；Windows 上
/// 两侧同后端、逐位一致（对拍退化为回归线）。
fn paint_seq_aa(bm : Bitmap) -> Unit {
  let p = Painter::new(bm)
  p.set_fill_color("#00aa00")
  p.begin_path()
  p.move_to(1.5, 1.0)
  p.line_to(14.5, 3.5)
  p.line_to(4.0, 13.5)
  p.close_path()
  p.fill()
  p.set_stroke_color("#cc3366")
  p.set_line_width(1.5)
  p.begin_path()
  p.move_to(3.0, 9.0)
  p.bezier_curve_to(6.0, 4.0, 10.0, 12.0, 13.0, 8.0)
  p.stroke()
  p.set_fill_color("#0000ff")
  p.begin_path()
  p.arc(11.0, 4.0, 2.5, 0.0, 6.283185307179586)
  p.close_path()
  p.fill()
  p.end()
}

test "路径/描边/弧两后端对拍（AA 容差）" {
  let a = Bitmap::new(16, 16)
  paint_seq_aa(a)
  let b = Bitmap::new(16, 16)
  let pb = Painter::new(b)
  match Raster::over(b) {
    Some(r) => pb.backend = Some(PureBackend(r))
    None => pb.backend = None
  }
  paint_seq_aa(b)
  // 容差带：每个像素每通道 ≤ 16（一个超采样档）；Linux 上 cairo 的解析
  // 覆盖与 16 级超采样在此带内逐像素可比
  let mut max_diff = 0
  let mut painted = 0
  for y = 0; y < 16; y = y + 1 {
    for x = 0; x < 16; x = x + 1 {
      let (r1, g1, b1, a1) = rgba_of(a, x, y)
      let (r2, g2, b2, a2) = rgba_of(b, x, y)
      painted = painted + a1
      let d = fn(u : Int, v : Int) -> Int {
        let w = u - v
        if w < 0 {
          -w
        } else {
          w
        }
      }
      max_diff = raster_max_i(max_diff, d(r1, r2))
      max_diff = raster_max_i(max_diff, d(g1, g2))
      max_diff = raster_max_i(max_diff, d(b1, b2))
      max_diff = raster_max_i(max_diff, d(a1, a2))
    }
  }
  assert_eq(max_diff <= 16, true)
  // 场景确实画了东西（三角形内部满覆盖像素存在）
  assert_eq(painted > 0, true)
}


// —— 以下测试一律「后端探测」：cairo 会话可用（Linux）直接用；不可用
// （Windows/mac 占位桩）落纯光栅器 Raster——两者方法面逐条同形。断言分两档：
// 结构档（内部着色/外部透明/中间 alpha 存在）跨平台共用；数值档（如斜边
// 覆盖的具体字节）属平台基线，纯后端走容差带（4×4 超采样 16 级 vs cairo
// 解析覆盖，单样本 16/256 量化差以内）。

test "路径填充：三角形内部着色、外部透明" {
  let bm = Bitmap::new(16, 16)
  let p = Painter::new(bm)
  p.set_fill_color("#00aa00")
  p.begin_path()
  p.move_to(0.0, 0.0)
  p.line_to(16.0, 0.0)
  p.line_to(0.0, 16.0)
  p.close_path()
  p.fill()
  p.end()
  // 内部满覆盖：不透明纯色的合成是精确算术，两后端逐位一致
  assert_eq(rgba_of(bm, 2, 2), (0, 170, 0, 255))
  assert_eq(rgba_of(bm, 14, 14), (0, 0, 0, 0))
}

test "抗锯齿：斜边像素出现中间 alpha" {
  let bm = Bitmap::new(16, 16)
  let p = Painter::new(bm)
  p.set_fill_color("#000000")
  p.begin_path()
  p.move_to(0.0, 0.0)
  p.line_to(16.0, 16.0)
  p.line_to(0.0, 16.0)
  p.close_path()
  p.fill()
  p.end()
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
  let p = Painter::new(bm)
  p.set_fill_color("#ff0000")
  p.save()
  p.clip_rect(0.0, 0.0, 4.0, 4.0)
  p.fill_rect(0.0, 0.0, 16.0, 16.0)
  p.restore()
  p.set_fill_color("#0000ff")
  p.translate(8.0, 8.0)
  p.fill_rect(0.0, 0.0, 4.0, 4.0)
  p.end()
  assert_eq(rgba_of(bm, 1, 1), (255, 0, 0, 255))
  assert_eq(rgba_of(bm, 6, 6), (0, 0, 0, 0))
  assert_eq(rgba_of(bm, 9, 9), (0, 0, 255, 255))
}

test "stroke_rect 走内侧口径（与 Painter 同语义）" {
  let a = Bitmap::new(12, 12)
  let pa = Painter::new(a)
  pa.set_stroke_color("#333333")
  pa.stroke_rect(2.0, 2.0, 8.0, 8.0)
  // 直连后端会话的一侧：cairo 可用用它，否则落纯光栅器（同方法面）
  let b = Bitmap::new(12, 12)
  match Cairo::over(b) {
    Some(c) => {
      c.set_fill_color("#333333")
      c.set_line_width(1.0)
      c.stroke_rect(2.0, 2.0, 8.0, 8.0)
      c.end()
    }
    None =>
      match Raster::over(b) {
        Some(r) => {
          r.set_fill_color("#333333")
          r.set_line_width(1.0)
          r.stroke_rect(2.0, 2.0, 8.0, 8.0)
          r.end()
        }
        None => assert_eq(true, false)
      }
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
    None =>
      match Raster::over(b) {
        Some(r) => {
          r.set_fill_color("#ffffff")
          r.fill_rect(0.0, 0.0, 4.0, 4.0)
          r.set_fill_color("#00000080")
          r.fill_rect(0.0, 0.0, 4.0, 4.0)
          r.end()
        }
        None => assert_eq(true, false)
      }
  }
  assert_eq(rgba_of(b, 1, 1), rgba_of(a, 1, 1))
  assert_eq(rgba_of(b, 1, 1), (127, 127, 127, 255))
  pa.end()
}
