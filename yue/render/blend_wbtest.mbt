// 混合与渐变的实测口径：25 个 Cairo 算子在 image surface 上的行为先由独立 C
// 探针（cairo 1.18 / 本机 pixman，探针不进仓库）测出数值，再落成本文件的断言；
// 某个算子若静默退回 source-over，除个别巧合样本外会应声而红。
// 混合/HSL 行留 ±2 容差（跨 pixman 版本的定标差异），Porter-Duff 行按精确值断言。

///|
fn px4(bm : Bitmap, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let c = bm.pixel(x, y)
  (c.r, c.g, c.b, c.a)
}

///|
fn near4(
  got : (Int, Int, Int, Int),
  want : (Int, Int, Int, Int),
  tol : Int,
) -> Bool {
  let (gr, gg, gb, ga) = got
  let (wr, wg, wb, wa) = want
  (gr - wr).abs() <= tol &&
  (gg - wg).abs() <= tol &&
  (gb - wb).abs() <= tol &&
  (ga - wa).abs() <= tol
}

///|
/// 一格样本：不透明底 `#8040c0`，按指定模式叠不透明纯红，取中心像素。
fn blend_sample(mode : BlendMode) -> (Int, Int, Int, Int) {
  let bm = Bitmap::new(2, 2)
  let p = Painter::new(bm)
  p.set_fill_color("#8040c0")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.set_blend_mode(mode)
  p.set_fill_color("#ff0000")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.end()
  px4(bm, 1, 1)
}

///|
test "Porter-Duff 与拷贝系：精确合成结果" {
  assert_eq(blend_sample(Normal), (255, 0, 0, 255))
  assert_eq(blend_sample(Copy), (255, 0, 0, 255))
  assert_eq(blend_sample(Clear), (0, 0, 0, 0))
  assert_eq(blend_sample(SourceOut), (0, 0, 0, 0))
  assert_eq(blend_sample(Xor), (0, 0, 0, 0))
  assert_eq(blend_sample(SourceIn), (255, 0, 0, 255))
  assert_eq(blend_sample(SourceAtop), (255, 0, 0, 255))
  assert_eq(blend_sample(DestinationOver), (128, 64, 192, 255))
  assert_eq(blend_sample(DestinationIn), (128, 64, 192, 255))
  assert_eq(blend_sample(DestinationAtop), (128, 64, 192, 255))
}

///|
test "混合系：25 模式实测表（含 pigment 与 HSL）" {
  assert_eq(near4(blend_sample(Multiply), (128, 0, 0, 255), 2), true)
  assert_eq(near4(blend_sample(Screen), (255, 64, 192, 255), 2), true)
  assert_eq(near4(blend_sample(Overlay), (255, 0, 129, 255), 2), true)
  assert_eq(near4(blend_sample(Darken), (128, 0, 0, 255), 2), true)
  assert_eq(near4(blend_sample(Lighten), (255, 64, 192, 255), 2), true)
  assert_eq(near4(blend_sample(ColorDodge), (255, 64, 192, 255), 2), true)
  assert_eq(near4(blend_sample(ColorBurn), (128, 0, 0, 255), 2), true)
  assert_eq(near4(blend_sample(SoftLight), (181, 16, 145, 255), 2), true)
  assert_eq(near4(blend_sample(HardLight), (255, 0, 0, 255), 2), true)
  assert_eq(near4(blend_sample(Difference), (127, 64, 192, 255), 2), true)
  assert_eq(near4(blend_sample(Exclusion), (127, 64, 192, 255), 2), true)
  assert_eq(near4(blend_sample(Hue), (187, 59, 59, 255), 2), true)
  assert_eq(near4(blend_sample(Saturation), (149, 42, 255, 255), 2), true)
  assert_eq(near4(blend_sample(Color), (255, 29, 29, 255), 2), true)
  assert_eq(near4(blend_sample(Luminosity), (107, 43, 171, 255), 2), true)
}

///|
test "半透明源的混合按 W3C 公式（α 参与）" {
  let bm = Bitmap::new(2, 2)
  let p = Painter::new(bm)
  p.set_fill_color("#8040c0")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.set_blend_mode(Multiply)
  p.set_fill_color("#ff000080")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.end()
  // (1-α)·底 + α·(底×源) = 0.5·(128,64,192) + 0.5·(128,0,0)
  assert_eq(px4(bm, 1, 1), (128, 32, 96, 255))
  p.end()
}

///|
test "透明底上 Multiply 退化为源色" {
  let bm = Bitmap::new(2, 2)
  let p = Painter::new(bm)
  p.set_blend_mode(Multiply)
  p.set_fill_color("#ff0000")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.end()
  assert_eq(px4(bm, 1, 1), (255, 0, 0, 255))
}

///|
test "set_blend_mode 后 set_fill_color 不重置算子" {
  let bm = Bitmap::new(2, 2)
  let p = Painter::new(bm)
  p.set_fill_color("#8040c0")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  // 先设色再设模式与先模式再设色，结果须一致（模式是独立状态）
  p.set_blend_mode(Multiply)
  p.set_fill_color("#ff0000")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.end()
  assert_eq(near4(px4(bm, 1, 1), (128, 0, 0, 255), 2), true)
}

///|
test "线性渐变：采样值与端点 pad" {
  let bm = Bitmap::new(4, 1)
  let p = Painter::new(bm)
  let g = Gradient::linear(0.0, 0.0, 10.0, 0.0)
  g.add_stop(0.0, "#ff0000")
  g.add_stop(1.0, "#0000ff")
  p.set_fill_gradient(g)
  p.fill_rect(0.0, 0.0, 4.0, 1.0)
  p.end()
  // 采样点在像素中心：(x + 0.5) / 10 处插值，实测 242/217/191/166
  assert_eq(near4(px4(bm, 0, 0), (242, 0, 13, 255), 2), true)
  assert_eq(near4(px4(bm, 1, 0), (217, 0, 38, 255), 2), true)
  assert_eq(near4(px4(bm, 2, 0), (191, 0, 64, 255), 2), true)
  assert_eq(near4(px4(bm, 3, 0), (166, 0, 89, 255), 2), true)

  // 端点 pad：渐变轴 (0,0)→(2,0)，第 2、3 列都复现端点蓝
  let bm2 = Bitmap::new(4, 1)
  let p2 = Painter::new(bm2)
  let g2 = Gradient::linear(0.0, 0.0, 2.0, 0.0)
  g2.add_stop(0.0, "#ff0000")
  g2.add_stop(1.0, "#0000ff")
  p2.set_fill_gradient(g2)
  p2.fill_rect(0.0, 0.0, 4.0, 1.0)
  p2.end()
  assert_eq(near4(px4(bm2, 0, 0), (191, 0, 64, 255), 2), true)
  assert_eq(near4(px4(bm2, 1, 0), (64, 0, 191, 255), 2), true)
  assert_eq(px4(bm2, 2, 0), (0, 0, 255, 255))
  assert_eq(px4(bm2, 3, 0), (0, 0, 255, 255))
}

///|
test "径向渐变：中心亮、四角对称暗" {
  let bm = Bitmap::new(4, 4)
  let p = Painter::new(bm)
  let g = Gradient::radial(2.0, 2.0, 0.0, 4.0)
  g.add_stop(0.0, "#ff0000")
  g.add_stop(1.0, "#0000ff")
  p.set_fill_gradient(g)
  p.fill_rect(0.0, 0.0, 4.0, 4.0)
  p.end()
  assert_eq(near4(px4(bm, 1, 1), (210, 0, 45, 255), 3), true)
  assert_eq(near4(px4(bm, 0, 0), (120, 0, 135, 255), 3), true)
  assert_eq(px4(bm, 0, 0), px4(bm, 3, 0))
  assert_eq(px4(bm, 0, 0), px4(bm, 0, 3))
  assert_eq(px4(bm, 0, 0), px4(bm, 3, 3))
}

///|
test "set_fill_color 覆盖渐变；无 stop 的渐变忽略" {
  let bm = Bitmap::new(2, 1)
  let p = Painter::new(bm)
  let empty = Gradient::linear(0.0, 0.0, 2.0, 0.0)
  p.set_fill_gradient(empty)
  p.set_fill_color("#00ff00")
  p.fill_rect(0.0, 0.0, 2.0, 1.0)
  // 纯色仍生效（空渐变被忽略）
  assert_eq(px4(bm, 0, 0), (0, 255, 0, 255))
  p.end()

  let bm2 = Bitmap::new(2, 1)
  let p2 = Painter::new(bm2)
  let g = Gradient::linear(0.0, 0.0, 2.0, 0.0)
  g.add_stop(0.0, "#ff0000")
  g.add_stop(1.0, "#0000ff")
  p2.set_fill_gradient(g)
  p2.set_fill_color("#00ff00")
  p2.fill_rect(0.0, 0.0, 2.0, 1.0)
  p2.end()
  // 后设的纯色覆盖渐变
  assert_eq(px4(bm2, 0, 0), (0, 255, 0, 255))
}

///|
test "门面路径填充与抗锯齿（forward 到 Cairo）" {
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
  assert_eq(px4(bm, 2, 2), (0, 170, 0, 255))
  assert_eq(px4(bm, 14, 14), (0, 0, 0, 0))

  let bm2 = Bitmap::new(16, 16)
  let p2 = Painter::new(bm2)
  p2.set_fill_color("#000000")
  p2.begin_path()
  p2.move_to(0.0, 0.0)
  p2.line_to(16.0, 16.0)
  p2.line_to(0.0, 16.0)
  p2.close_path()
  p2.fill()
  p2.end()
  let mut partial = 0
  for y = 0; y < 16; y = y + 1 {
    for x = 0; x < 16; x = x + 1 {
      let (_, _, _, a) = px4(bm2, x, y)
      if a > 0 && a < 255 {
        partial = partial + 1
      }
    }
  }
  assert_eq(partial > 0, true)
}

///|
/// 会话槽只有 16 个：泄漏会让后续 Painter 静默退回降级实现，
/// 这条守住「end 正确回收」与「连续开合不退化」。
test "会话槽回收：连续开合 20 个 Painter 仍持有会话" {
  for i = 0; i < 20; i = i + 1 {
    let bm = Bitmap::new(2, 2)
    let p = Painter::new(bm)
    match p.session {
      Some(_) => ()
      None => assert_eq(true, false)
    }
    p.set_fill_color("#ff0000")
    p.fill_rect(0.0, 0.0, 2.0, 2.0)
    p.end()
    assert_eq(px4(bm, 0, 0), (255, 0, 0, 255))
  }
}

///|
test "门面 save/restore 同时回退变换与样式" {
  let bm = Bitmap::new(8, 8)
  let p = Painter::new(bm)
  p.set_fill_color("#ff0000")
  p.save()
  p.translate(4.0, 4.0)
  p.set_fill_color("#00ff00")
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.restore()
  p.fill_rect(0.0, 0.0, 2.0, 2.0)
  p.end()
  assert_eq(px4(bm, 5, 5), (0, 255, 0, 255))
  // restore 后：位置回退且填充色回到红
  assert_eq(px4(bm, 1, 1), (255, 0, 0, 255))
  assert_eq(px4(bm, 3, 3), (0, 0, 0, 0))
}
