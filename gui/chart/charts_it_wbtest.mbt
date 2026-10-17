// 图表交互变体白盒测试：charts_it.mbt 的私有纯函数（折线/柱状绘制区
// 边距——与 draw_line_chart/draw_bar_chart 同源、环形几何——与
// draw_donut_core 同源、图例项构造——按原始序号、窗口定标——最长序列
// 点数）+ 三个交互组件的挂载注入（hover 浮层、图例点击显隐、滚轮缩放）。
// 辅助函数（mounted/bm_of/diff_of）复用 charts_wbtest.mbt。

///|
test "ci_line_plot：边距与 draw.mbt draw_line_chart 同源" {
  let full = ci_line_plot(true)(560.0, 260.0)
  assert_eq(full.x0, 46.0)
  assert_eq(full.y0, 12.0)
  assert_eq(full.x1, 560.0 - 56.0) // show_last 末端标注预留
  assert_eq(full.y1, 260.0 - 18.0)
  let plain = ci_line_plot(false)(560.0, 260.0)
  assert_eq(plain.x1, 560.0 - 12.0) // 无末端标注边距收紧
  assert_eq(plain.y1, 260.0 - 18.0)
  // 命中包含性随边距同收窄：(520,100) 在无标注版区内、在有标注版区外
  assert_true(plain.contains(520.0, 100.0))
  assert_false(full.contains(520.0, 100.0))
}

///|
test "ci_bar_plot：纵向/横向两形态边距同源" {
  let vert = ci_bar_plot(false)(560.0, 280.0)
  assert_eq(vert.x0, 46.0)
  assert_eq(vert.y0, 14.0)
  assert_eq(vert.x1, 560.0 - 12.0)
  assert_eq(vert.y1, 280.0 - 24.0)
  let hori = ci_bar_plot(true)(560.0, 280.0)
  assert_eq(hori.x0, 84.0) // 横向条目名留宽
  assert_eq(hori.y0, 12.0)
  assert_eq(hori.x1, 560.0 - 20.0)
  assert_eq(hori.y1, 280.0 - 24.0)
}

///|
test "ci_donut_geom：与 draw_donut_core 同源，环厚越界钳内径" {
  let (cx, cy, r_in, r_out) = ci_donut_geom(240.0, 34.0)
  assert_eq(cx, 8.0 + (240.0 - 16.0) / 2.0)
  assert_eq(cy, 120.0)
  assert_eq(r_out, (240.0 - 16.0) / 2.0)
  assert_eq(r_in, r_out - 34.0)
  // 环厚超过外径：内径钳到 1（不出现负半径环）
  let (_, _, rin2, rout2) = ci_donut_geom(240.0, 500.0)
  assert_eq(rout2, r_out)
  assert_eq(rin2, 1.0)
}

///|
test "ci_line_items：名称 + 原始序号（色由 ci_legend 的 color_at 现取）" {
  let all : Array[LineSeries] = [
    { name: "s1", max_points: 10, points: [1.0], },
    { name: "s2", max_points: 10, points: [1.0], },
    { name: "s3", max_points: 10, points: [1.0], },
  ]
  let its = ci_line_items(all)
  assert_eq(its.length(), 3)
  assert_eq(its[0], ("s1", 0))
  assert_eq(its[1], ("s2", 1))
  assert_eq(its[2], ("s3", 2))
  assert_eq(ci_line_items([]).length(), 0)
  // color_at 按原始序号给系列色（四色循环回卷）
  assert_eq(series_color(0), @theme.theme_primary())
  assert_eq(series_color(1), @theme.theme_success())
  assert_eq(series_color(4), @theme.theme_primary())
}

///|
test "ci_bar_items：标签 + 原始序号（正负色由 color_at 按值现取）" {
  let data : Array[BarItem] = [
    BarItem::make("a", 30.0),
    BarItem::make("b", -8.0),
    BarItem::make("c", 0.0), // 0 按正数主色
  ]
  let its = ci_bar_items(data)
  assert_eq(its.length(), 3)
  assert_eq(its[0], ("a", 0))
  assert_eq(its[1], ("b", 1))
  assert_eq(its[2], ("c", 2))
  assert_eq(ci_bar_items([]).length(), 0)
}

///|
test "ci_donut_items：标签 + 原始序号（五色循环）" {
  let data : Array[DonutSlice] = [
    DonutSlice::make("a", 1.0),
    DonutSlice::make("b", 1.0),
    DonutSlice::make("c", 1.0),
    DonutSlice::make("d", 1.0),
    DonutSlice::make("e", 1.0),
    DonutSlice::make("f", 1.0),
  ]
  let its = ci_donut_items(data)
  assert_eq(its.length(), 6)
  assert_eq(its[0], ("a", 0))
  assert_eq(its[5], ("f", 5))
  // 色板：前五色循环，第六色回卷主色
  assert_eq(donut_color(0), @theme.theme_primary())
  assert_eq(donut_color(4), @theme.theme_info())
  assert_eq(donut_color(5), @theme.theme_primary())
  assert_eq(ci_donut_items([]).length(), 0)
}

///|
test "ci_win_len：窗口定标取最长序列点数" {
  let all : Array[LineSeries] = [
    { name: "a", max_points: 10, points: [1.0, 2.0, 3.0], },
    { name: "b", max_points: 10, points: [1.0], },
    { name: "c", max_points: 10, points: [], },
  ]
  assert_eq(ci_win_len(all), 3)
  assert_eq(ci_win_len([]), 0)
}

///|
/// 折线交互图：hover 出浮层与准线、离开复原；图例点击隐藏序列后画面变。
test "折线交互图：hover 浮层与准线、图例点击显隐" {
  let s = @base.Store::new([
    LineSeries::make("a", max_points=50).with_points([3.0, 8.0, 5.0, 9.0, 4.0]),
    LineSeries::make("b", max_points=50).with_points([1.0, 2.0, 6.0, 3.0, 7.0]),
  ])
  let (root, panel) = mounted(line_chart_it(s, width=320.0, height=160.0), 360.0, 220.0)
  // panel 是 vbox：kids[0]=图例、kids[1]=画布
  let legend = panel.kids[0]
  let canvas = panel.kids[1]
  let _ = legend.rect
  let plain = bm_of(canvas)
  // 画布中部（绘制区中心附近）悬停：最近点命中 → 浮层 + 准线 + 落点
  let px = 46.0 + (320.0 - 56.0 - 46.0) / 2.0
  let py = 12.0 + (160.0 - 18.0 - 12.0) / 2.0
  let _ = root.dispatch_pointer({
    kind: @widget.PointerKind::Move,
    x: canvas.rect.x + px,
    y: canvas.rect.y + py,
    button: 0,
    mods: 0,
  })
  let lit = bm_of(canvas)
  assert_true(diff_of(lit, plain) > 50)
  // 离开：浮层收起，画面复原
  let _ = root.dispatch_pointer({
    kind: @widget.PointerKind::Leave,
    x: canvas.rect.x + px,
    y: canvas.rect.y + py,
    button: 0,
    mods: 0,
  })
  assert_eq(diff_of(bm_of(canvas), plain), 0)
  // 图例点第二项（b 序列色块附近，图例行高 24）：Down+Up 翻转显隐
  let lg = bm_of(canvas)
  let _ = root.dispatch_pointer({
    kind: @widget.PointerKind::Down,
    x: legend.rect.x + ci_legend_item_w("a") + 12.0,
    y: legend.rect.y + 12.0,
    button: 1,
    mods: 0,
  })
  let _ = root.dispatch_pointer({
    kind: @widget.PointerKind::Up,
    x: legend.rect.x + ci_legend_item_w("a") + 12.0,
    y: legend.rect.y + 12.0,
    button: 1,
    mods: 0,
  })
  assert_true(diff_of(bm_of(canvas), lg) > 50)
}

///|
/// 柱状交互图：滚轮放大后窗口收窄（画面变），再复位回全窗。
test "柱状交互图：滚轮缩放改可见窗" {
  let bars : Array[BarItem] = []
  for i = 0; i < 24; i = i + 1 {
    bars.push(BarItem::make("c\{i}", ((i * 13) % 37).to_double()))
  }
  let data = @base.Store::new(bars)
  let (root, panel) = mounted(bar_chart_it(data, width=320.0, height=160.0), 360.0, 220.0)
  let canvas = panel.kids[1]
  let full = bm_of(canvas)
  // 画布中部上滚一格（dy=1 → delta=-1 → 放大）：窗从 100% 收到 80%
  let px = 46.0 + (320.0 - 12.0 - 46.0) / 2.0
  let py = 14.0 + (160.0 - 24.0 - 14.0) / 2.0
  let handled = root.dispatch_scroll({
    x: canvas.rect.x + px,
    y: canvas.rect.y + py,
    dx: 0.0,
    dy: 1.0,
    mods: 0,
  })
  assert_true(handled)
  assert_true(diff_of(bm_of(canvas), full) > 50)
}

///|
/// 环形交互图：扇区 hover 外扩出浮层、图例隐藏后重算占比。
test "环形交互图：hover 扇区与图例显隐" {
  let data = @base.Store::new([
    DonutSlice::make("甲", 40.0),
    DonutSlice::make("乙", 35.0),
    DonutSlice::make("丙", 25.0),
  ])
  let (root, panel) = mounted(donut_chart_it(data, width=240.0, height=160.0), 280.0, 220.0)
  let canvas = panel.kids[1]
  let plain = bm_of(canvas)
  // 12 点方向第一扇区：圆心 (8+d/2, h/2)，d=h-16
  let d = 160.0 - 16.0
  let cx = 8.0 + d / 2.0
  let cy = 160.0 / 2.0
  let r_out = d / 2.0
  let _ = root.dispatch_pointer({
    kind: @widget.PointerKind::Move,
    x: canvas.rect.x + cx,
    y: canvas.rect.y + (cy - r_out * 0.8),
    button: 0,
    mods: 0,
  })
  let lit = bm_of(canvas)
  assert_true(diff_of(lit, plain) > 50)
  // 离开复原
  let _ = root.dispatch_pointer({
    kind: @widget.PointerKind::Leave,
    x: canvas.rect.x + cx,
    y: canvas.rect.y + (cy - r_out * 0.8),
    button: 0,
    mods: 0,
  })
  assert_eq(diff_of(bm_of(canvas), plain), 0)
}
