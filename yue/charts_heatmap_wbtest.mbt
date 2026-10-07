// 热力图白盒测试：纯函数（矩阵量程/值→色带插值/格坐标）语义。
// 绘制函数（heat_draw/heatmap_t）走 GUI 挂载路径，保证可编译即可，
// 视觉验证按仓库惯例由真机示例承担。

///|
test "heat_range：矩阵 min/max/参差行/空矩阵/等值退化" {
  // 正常矩阵：两端被实际数据命中（无留白）
  assert_eq(heat_range([[1.0, 2.0], [3.0, 4.0]]), (1.0, 4.0))
  // 参差行：全部行全部格参与
  assert_eq(heat_range([[5.0], [1.0, 9.0]]), (1.0, 9.0))
  // 负值
  assert_eq(heat_range([[-3.0, 7.0]]), (-3.0, 7.0))
  // 空矩阵 / 空行
  assert_eq(heat_range([]), (0.0, 1.0))
  assert_eq(heat_range([[], []]), (0.0, 1.0))
  // 等值退化：原样返回（中点规则在 heat_color 消化）
  assert_eq(heat_range([[2.0, 2.0], [2.0, 2.0]]), (2.0, 2.0))
  // 单格
  assert_eq(heat_range([[7.5]]), (7.5, 7.5))
}

///|
test "heat_color：端点/中点/钳制/退化" {
  let low = "#ffffff"
  let high = "#0000ff"
  // 低端取 low、高端取 high
  assert_eq(heat_color(0.0, 0.0, 10.0, low, high), "#ffffff")
  assert_eq(heat_color(10.0, 0.0, 10.0, low, high), "#0000ff")
  // 中点：RGB 逐通道线性（127.5 → 128 = 0x80）
  assert_eq(heat_color(5.0, 0.0, 10.0, low, high), "#8080ff")
  // 越界钳到端点色
  assert_eq(heat_color(-3.0, 0.0, 10.0, low, high), "#ffffff")
  assert_eq(heat_color(99.0, 0.0, 10.0, low, high), "#0000ff")
  // 值域退化：取两色中点
  assert_eq(heat_color(7.0, 7.0, 7.0, low, high), "#8080ff")
  // 非对称通道：黑→白中点灰
  assert_eq(heat_color(0.5, 0.0, 1.0, "#000000", "#ffffff"), "#808080")
  // 4:6 比例（t=0.4 取 low）：r=round(0*0.4+255*0.6)=153=0x99
  assert_eq(heat_color(4.0, 0.0, 10.0, low, high), "#9999ff")
}

///|
test "heat_cell_rect：均分/间距居中/窄格钳制/退化" {
  // 2×2 均分 0..100：槽 50、格 40、四周留 5
  assert_eq(
    heat_cell_rect(0, 0, 2, 2, 0.0, 0.0, 100.0, 100.0, gap=10.0),
    (5.0, 5.0, 40.0, 40.0),
  )
  assert_eq(
    heat_cell_rect(1, 0, 2, 2, 0.0, 0.0, 100.0, 100.0, gap=10.0),
    (55.0, 5.0, 40.0, 40.0),
  )
  assert_eq(
    heat_cell_rect(0, 1, 2, 2, 0.0, 0.0, 100.0, 100.0, gap=10.0),
    (5.0, 55.0, 40.0, 40.0),
  )
  assert_eq(
    heat_cell_rect(1, 1, 2, 2, 0.0, 0.0, 100.0, 100.0, gap=10.0),
    (55.0, 55.0, 40.0, 40.0),
  )
  // 非正方形网格区：宽高各自均分
  assert_eq(
    heat_cell_rect(2, 1, 4, 2, 0.0, 0.0, 100.0, 50.0, gap=5.0),
    (52.5, 27.5, 20.0, 20.0),
  )
  // 默认 gap=2
  assert_eq(
    heat_cell_rect(0, 0, 1, 1, 0.0, 0.0, 10.0, 10.0),
    (1.0, 1.0, 8.0, 8.0),
  )
  // 大矩阵窄格：宽/高钳到 >=1，首格不越网格区左/上界
  let (x0, y0, w0, h0) = heat_cell_rect(
    0,
    0,
    200,
    1,
    46.0,
    12.0,
    548.0,
    276.0,
    gap=2.0,
  )
  assert_true(w0 >= 1.0)
  assert_true(h0 >= 1.0)
  assert_true(x0 >= 46.0)
  assert_true(y0 >= 12.0)
  // 末格不越网格区右/下界
  let (x199, _y, w199, _h) = heat_cell_rect(
    199,
    0,
    200,
    1,
    46.0,
    12.0,
    548.0,
    276.0,
    gap=2.0,
  )
  assert_true(x199 + w199 <= 548.0 + 1.0e-9)
  // cols/rows <= 0：退化为整块网格区
  assert_eq(
    heat_cell_rect(0, 0, 0, 0, 0.0, 0.0, 100.0, 50.0),
    (0.0, 0.0, 100.0, 50.0),
  )
}

///|
test "HeatGrid::make：标签与矩阵原样入表" {
  let g = HeatGrid::make(["a", "b", "c"], ["r1", "r2"], [
    [1.0, 2.0, 3.0],
    [4.0, 5.0, 6.0],
  ])
  assert_eq(g.x_labels.length(), 3)
  assert_eq(g.y_labels.length(), 2)
  assert_eq(g.values.length(), 2)
  assert_eq(g.values[1][2], 6.0)
  assert_eq(g.x_labels[0], "a")
  assert_eq(g.y_labels[1], "r2")
  // 量程 + 插值组合：整表 min→low、max→high
  let (lo, hi) = heat_range(g.values)
  assert_eq(heat_color(g.values[0][0], lo, hi, "#ffffff", "#0000ff"), "#ffffff")
  assert_eq(heat_color(g.values[1][2], lo, hi, "#ffffff", "#0000ff"), "#0000ff")
}
