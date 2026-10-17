// 主色调像素回归：Solid 按钮底、选中 checkbox 的勾线与框、progress 进度段
// 都必须出主题 primary 色（#2D68C4）——样式槽解析或绘制快路径丢色在此立现。

///|
test "主色调像素：Solid 按钮 / 选中 checkbox / progress 都出 primary 色" {
  let (root_b, _) = mounted(button("保存", variant=Solid), 140.0, 44.0)
  let (root_c, _) = mounted(
    checkbox("复选", @base.Store::new(true)),
    140.0,
    32.0,
  )
  let (root_p, _) = mounted(progress(@base.Store::new(0.6)), 240.0, 12.0)
  let bm_b = @render.Bitmap::new(140, 44)
  let pb = @render.Painter::new(bm_b)
  root_b.paint(pb)
  pb.end()
  let bm_c = @render.Bitmap::new(140, 32)
  let pc = @render.Painter::new(bm_c)
  root_c.paint(pc)
  pc.end()
  let bm_p = @render.Bitmap::new(240, 12)
  let pp = @render.Painter::new(bm_p)
  root_p.paint(pp)
  pp.end()
  let mut b_cnt = 0
  let mut c_cnt = 0
  let mut p_cnt = 0
  for y = 0; y < 44; y = y + 1 {
    for x = 0; x < 140; x = x + 1 {
      let c = bm_b.pixel(x, y)
      if c.r == 0x2D && c.g == 0x68 && c.b == 0xC4 && c.a == 255 {
        b_cnt += 1
      }
    }
  }
  for y = 0; y < 32; y = y + 1 {
    for x = 0; x < 140; x = x + 1 {
      let c = bm_c.pixel(x, y)
      // 勾线是亚像素折线，AA 混色后按「蓝显著强于红」计（#2D68C4 的特征）
      if c.a == 255 && c.b - c.r > 40 && c.b > 100 {
        c_cnt += 1
      }
    }
  }
  for y = 0; y < 12; y = y + 1 {
    for x = 0; x < 240; x = x + 1 {
      let c = bm_p.pixel(x, y)
      if c.r == 0x2D && c.g == 0x68 && c.b == 0xC4 && c.a == 255 {
        p_cnt += 1
      }
    }
  }
  assert_true(b_cnt > 50)
  assert_true(c_cnt > 2)
  assert_true(p_cnt > 50)
}
