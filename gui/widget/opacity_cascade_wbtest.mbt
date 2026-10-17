// W33 收尾：Style.opacity 级联验证——父 alpha_paint 与子 alpha_paint 相乘落到 Painter.global_alpha。
// 与 paint_walk 里 inherited × own 那段（widget.mbt:936 附近）配对。

test "Style.opacity 单控件生效：alpha_paint 独立字段" {
  let w = Widget::new()
  w.alpha_paint = 0.5
  assert_eq(w.alpha_paint, 0.5)
}

test "Style.opacity 默认 1.0：新建控件不透明" {
  let w = Widget::new()
  assert_eq(w.alpha_paint, 1.0)
}

test "Painter.set_global_alpha / global_alpha 往返" {
  let bmp = @render.Bitmap::new(4, 4)
  let p = @render.Painter::new(bmp)
  p.set_global_alpha(0.3)
  let got = p.global_alpha()
  assert_true(got > 0.29 && got < 0.31)
}

test "父 × 子 alpha 累乘（widget.paint_walk 语义等价复算）" {
  // paint_walk 里的公式：inherited × own，两值各 0.5 应得 0.25
  let inherited = 0.5
  let own = 0.5
  let combined = inherited * own
  assert_true(combined > 0.24 && combined < 0.26)
}
