// 雷达图白盒测试：纯函数（顶点角度 / 多边形顶点 / 量程归一 / 值到半径
// 映射 / 系列多边形 / 布局几何）语义，绘制函数保证可编译（真实绘制走
// on_draw，由用户真机验证）。

///|
test "radar_axis_angle：顶点 0 在 12 点方向、顺时针均布" {
  // 4 边形：上 → 右 → 下 → 左
  assert_true((radar_axis_angle(0, 4) - -pi / 2.0).abs() < 1.0e-12)
  assert_true((radar_axis_angle(1, 4) - 0.0).abs() < 1.0e-12)
  assert_true((radar_axis_angle(2, 4) - pi / 2.0).abs() < 1.0e-12)
  assert_true((radar_axis_angle(3, 4) - pi).abs() < 1.0e-12)
  // 3 边形：上 → 右下 120° → 左下 240°
  assert_true(
    (radar_axis_angle(1, 3) - (-pi / 2.0 + tau / 3.0)).abs() < 1.0e-12,
  )
  // 顶点角跨整圈回归 2π（同余）
  assert_true(
    (radar_axis_angle(4, 4) - radar_axis_angle(0, 4) - tau).abs() < 1.0e-12,
  )
  // 退化：n <= 0 一律 12 点方向
  assert_true((radar_axis_angle(0, 0) - -pi / 2.0).abs() < 1.0e-12)
  assert_true((radar_axis_angle(3, -2) - -pi / 2.0).abs() < 1.0e-12)
}

///|
test "radar_polygon：四边形顶点坐标 / 六边形闭合 / 退化" {
  // 4 边形：上(100,50) 右(150,100) 下(100,150) 左(50,100)
  let pts = radar_polygon(100.0, 100.0, 50.0, 4)
  assert_eq(pts.length(), 4)
  assert_true((pts[0].0 - 100.0).abs() < 1.0e-9)
  assert_true((pts[0].1 - 50.0).abs() < 1.0e-9)
  assert_true((pts[1].0 - 150.0).abs() < 1.0e-9)
  assert_true((pts[1].1 - 100.0).abs() < 1.0e-9)
  assert_true((pts[2].0 - 100.0).abs() < 1.0e-9)
  assert_true((pts[2].1 - 150.0).abs() < 1.0e-9)
  assert_true((pts[3].0 - 50.0).abs() < 1.0e-9)
  assert_true((pts[3].1 - 100.0).abs() < 1.0e-9)
  // 6 边形：单位顶点向量和为 0（闭合均布）
  let hex = radar_polygon(0.0, 0.0, 1.0, 6)
  let mut sx = 0.0
  let mut sy = 0.0
  for pt in hex {
    sx = sx + pt.0
    sy = sy + pt.1
  }
  assert_true(sx.abs() < 1.0e-9)
  assert_true(sy.abs() < 1.0e-9)
  // 顶点到中心等距（= r）
  for pt in hex {
    let d = (pt.0 * pt.0 + pt.1 * pt.1).sqrt()
    assert_true((d - 1.0).abs() < 1.0e-9)
  }
  // 退化：n <= 0 / 负半径 → 空
  assert_eq(radar_polygon(0.0, 0.0, 50.0, 0).length(), 0)
  assert_eq(radar_polygon(0.0, 0.0, -1.0, 5).length(), 0)
  // r = 0：全部顶点收缩到中心
  let zero = radar_polygon(10.0, 20.0, 0.0, 4)
  for pt in zero {
    assert_eq(pt, (10.0, 20.0))
  }
}

///|
test "radar_norm：量程归一 / 两端钳制 / 量程无效" {
  assert_true((radar_norm(5.0, 10.0) - 0.5).abs() < 1.0e-12)
  assert_true((radar_norm(10.0, 10.0) - 1.0).abs() < 1.0e-12)
  assert_true((radar_norm(0.0, 10.0) - 0.0).abs() < 1.0e-12)
  assert_eq(radar_norm(15.0, 10.0), 1.0) // 超量程钳到 1
  assert_eq(radar_norm(-3.0, 10.0), 0.0) // 负值钳到 0
  assert_true((radar_norm(7.5, 30.0) - 0.25).abs() < 1.0e-12)
  // 量程无效（max <= 0）：一律折到中心
  assert_eq(radar_norm(3.0, 0.0), 0.0)
  assert_eq(radar_norm(3.0, -5.0), 0.0)
}

///|
test "radar_map_radius：值到半径 / 满值 / 钳制 / 量程无效" {
  assert_true((radar_map_radius(5.0, 10.0, 80.0) - 40.0).abs() < 1.0e-12)
  assert_true((radar_map_radius(0.0, 10.0, 80.0) - 0.0).abs() < 1.0e-12)
  assert_true((radar_map_radius(10.0, 10.0, 80.0) - 80.0).abs() < 1.0e-12)
  assert_eq(radar_map_radius(99.0, 10.0, 80.0), 80.0) // 超量程钳到满半径
  assert_eq(radar_map_radius(-1.0, 10.0, 80.0), 0.0)
  assert_eq(radar_map_radius(4.0, 0.0, 80.0), 0.0) // 量程无效折中心
  // 不同维度量程各管各的：同值不同 max 半径不同
  let ra = radar_map_radius(5.0, 10.0, 60.0)
  let rb = radar_map_radius(5.0, 20.0, 60.0)
  assert_true((ra - 30.0).abs() < 1.0e-12)
  assert_true((rb - 15.0).abs() < 1.0e-12)
}

///|
test "radar_series_polygon：各维按自身量程映射 / 缺失折中心 / 多余忽略" {
  // 3 维：0 半满(顶)、1 满值(右)、2 零值(左下)
  let maxes = [10.0, 20.0, 10.0]
  let pts = radar_series_polygon(100.0, 100.0, 50.0, [5.0, 20.0, 0.0], maxes)
  assert_eq(pts.length(), 3)
  // 维 0：5/10 = 0.5 → r = 25 → 顶点 (100, 75)
  assert_true((pts[0].0 - 100.0).abs() < 1.0e-9)
  assert_true((pts[0].1 - 75.0).abs() < 1.0e-9)
  // 维 1：满值 → 到中心距离 = 满半径，且落在外圈顶点 1（角 -π/2+2π/3）
  let dx = pts[1].0 - 100.0
  let dy = pts[1].1 - 100.0
  assert_true((dx * dx + dy * dy).sqrt() - 50.0 < 1.0e-9)
  let outer = radar_polygon(100.0, 100.0, 50.0, 3)
  assert_true((pts[1].0 - outer[1].0).abs() < 1.0e-9)
  assert_true((pts[1].1 - outer[1].1).abs() < 1.0e-9)
  // 维 2：零值 → 中心
  assert_true((pts[2].0 - 100.0).abs() < 1.0e-9)
  assert_true((pts[2].1 - 100.0).abs() < 1.0e-9)
  // values 缺维：缺失按 0 折中心
  let short = radar_series_polygon(0.0, 0.0, 50.0, [5.0], maxes)
  assert_eq(short.length(), 3)
  assert_true(short[1].0.abs() < 1.0e-12 && short[1].1.abs() < 1.0e-12)
  assert_true(short[2].0.abs() < 1.0e-12 && short[2].1.abs() < 1.0e-12)
  // values 多余维度：忽略（长度仍 = 维度数）
  let long = radar_series_polygon(0.0, 0.0, 50.0, [5.0, 5.0, 5.0, 99.0], maxes)
  assert_eq(long.length(), 3)
  // 量程无效维度：折中心（maxes 2 维，维 0 顶点在 12 点方向）
  let bad = radar_series_polygon(0.0, 0.0, 50.0, [8.0, 8.0], [10.0, 0.0])
  assert_true((bad[0].1 + 40.0).abs() < 1.0e-9) // 8/10 → r=40，向上
  assert_true(bad[0].0.abs() < 1.0e-9)
  assert_true(bad[1].0.abs() < 1.0e-12 && bad[1].1.abs() < 1.0e-12)
}

///|
test "radar_layout：图例预留 / 短边约束 / 小画布半径下限" {
  // 带图例：绘图区宽 400-84=316，中心 x=158；短边 300 → r=300/2-30=120
  let (cx, cy, r) = radar_layout(400.0, 300.0, true)
  assert_true((cx - 158.0).abs() < 1.0e-9)
  assert_true((cy - 150.0).abs() < 1.0e-9)
  assert_true((r - 120.0).abs() < 1.0e-9)
  // 无图例：中心居中；宽为短边
  let (cx2, _cy2, r2) = radar_layout(400.0, 300.0, false)
  assert_true((cx2 - 200.0).abs() < 1.0e-9)
  assert_true((r2 - 120.0).abs() < 1.0e-9)
  // 宽为短边（高更大）：r 受宽约束
  let (_cx3, _cy3, r3) = radar_layout(300.0, 400.0, false)
  assert_true((r3 - 120.0).abs() < 1.0e-9)
  // 小画布：半径钳到最小 10（标签边距挤不掉雷达）
  let (_cx4, _cy4, r4) = radar_layout(20.0, 20.0, false)
  assert_true(r4 >= 10.0)
  // 带图例的极窄画布：绘图区宽钳到 10，中心不越界
  let (cx5, _cy5, _r5) = radar_layout(30.0, 200.0, true)
  assert_true(cx5 > 0.0 && cx5 <= 30.0)
}

///|
test "RadarIndicator / RadarSeries 构造与 Store 驱动" {
  let ind = RadarIndicator::make("输出", 100.0)
  assert_eq(ind.name, "输出")
  assert_true((ind.max - 100.0).abs() < 1.0e-12)
  let s = RadarSeries::make("本机", [1.0, 2.0, 3.0])
  assert_eq(s.name, "本机")
  debug_inspect(s.values, content="[1, 2, 3]")
  // Store 驱动：set 换整表，订阅收到通知
  let inds : Store[Array[RadarIndicator]] = Store::new([
    RadarIndicator::make("a", 10.0),
    RadarIndicator::make("b", 20.0),
    RadarIndicator::make("c", 30.0),
  ])
  let sers : Store[Array[RadarSeries]] = Store::new([
    RadarSeries::make("s1", [1.0, 2.0, 3.0]),
    RadarSeries::make("s2", [4.0, 5.0, 6.0]),
  ])
  let hits = Ref(0)
  sers.subscribe(fn(_v) { hits.val = hits.val + 1 })
  sers.set([RadarSeries::make("s3", [7.0, 8.0, 9.0])])
  assert_eq(hits.val, 1)
  assert_eq(sers.get().length(), 1)
  assert_eq(sers.get()[0].name, "s3")
  assert_eq(inds.get().length(), 3)
}
