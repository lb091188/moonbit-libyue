// 图表交互变体白盒测试：charts_it.mbt 的私有纯函数（折线/柱状绘制区
// 边距——与 charts.mbt draw_line_chart/draw_bar_chart 同源、环形几何——
// 与 draw_donut 同源、图例项构造——色按原始序号取/正负分色、窗口定标
// ——最长序列点数）语义。绘制函数（ci_draw_donut_sectors）走 Painter +
// AttributedText 路径，须 initialize 起的真实画布，按仓库惯例由真机示例
// 承担（见 docs/zh/adaptation.md「离屏 Canvas」条），不在此列。

///|
test "ci_line_plot：边距与 charts.mbt draw_line_chart 同源" {
  let full = ci_line_plot(true)(560.0, 260.0)
  assert_eq(full.x0, 46.0)
  assert_eq(full.y0, 12.0)
  assert_eq(full.x1, 560.0 - 56.0) // show_last 末端标注预留
  assert_eq(full.y1, 260.0 - 18.0)
  let plain = ci_line_plot(false)(560.0, 260.0)
  assert_eq(plain.x1, 560.0 - 12.0) // 无末端标注边距收紧
  assert_eq(plain.y1, 260.0 - 18.0)
  // 命中包含性随边距同收窄:(520,100) 在无标注版区内、在有标注版区外
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
test "ci_donut_geom：与 draw_donut 同源，环厚越界钳内径" {
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
test "ci_line_items：名称 + 系列色按原始序号取" {
  let all : Array[LineSeries] = [
    { name: "s1", max_points: 10, points: [1.0], },
    { name: "s2", max_points: 10, points: [1.0], },
    { name: "s3", max_points: 10, points: [1.0], },
    { name: "s4", max_points: 10, points: [1.0], },
    { name: "s5", max_points: 10, points: [1.0], },
  ]
  let its = ci_line_items(all)
  assert_eq(its.length(), 5)
  assert_eq(its[0].0, "s1")
  assert_eq(its[0].1, @yue.theme_primary())
  assert_eq(its[1].1, @yue.theme_success())
  assert_eq(its[2].1, @yue.theme_warning())
  assert_eq(its[3].1, @yue.theme_danger())
  assert_eq(its[4].1, @yue.theme_primary()) // 四色循环回卷
  assert_eq(ci_line_items([]).length(), 0)
}

///|
test "ci_bar_items：标签 + 正负分色（同 draw_bar_chart）" {
  let data : Array[BarItem] = [
    BarItem::make("a", 30.0),
    BarItem::make("b", -8.0),
    BarItem::make("c", 0.0), // 0 按正数主色
  ]
  let its = ci_bar_items(data)
  assert_eq(its.length(), 3)
  assert_eq(its[0], ("a", @yue.theme_primary()))
  assert_eq(its[1], ("b", @yue.theme_danger()))
  assert_eq(its[2], ("c", @yue.theme_primary()))
  assert_eq(ci_bar_items([]).length(), 0)
}

///|
test "ci_donut_items：标签 + 扇区色按原始序号取" {
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
  assert_eq(its[0].0, "a")
  assert_eq(its[0].1, @yue.theme_primary())
  assert_eq(its[1].1, @yue.theme_success())
  assert_eq(its[2].1, @yue.theme_warning())
  assert_eq(its[3].1, @yue.theme_danger())
  assert_eq(its[4].1, @yue.theme_info()) // 五色循环
  assert_eq(its[5].1, @yue.theme_primary())
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
