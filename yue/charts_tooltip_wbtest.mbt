// 图表交互层白盒测试:浮层定位防出界 / 尺寸估算 / 命中测试(最近点 /
// 扇区)/ 绘制区分数换算。纯函数,无 GUI 依赖(浮层绘制与 ci_tooltip
// 组件层需真机验证,不在此列)。

///|
test "ci_tip_size:标题行 + 内容行 + 色标 + 空内容最小盒" {
  // 标题 2 字符 14,行:色标 14 + 5 字符 35 = 49 → 宽 49+16=65;2 行 → 高 52
  debug_inspect(ci_tip_size("t3", [("#111111", "a 1.0")]), content="(65, 52)")
  // 无标题:1 行 → 高 34
  debug_inspect(ci_tip_size("", [("#111111", "a 1.0")]), content="(65, 34)")
  // 空内容:最小盒(1 行空格)
  debug_inspect(ci_tip_size("", []), content="(16, 34)")
  // 多行取最宽行:14(色标) + 5 字符 35 + 16 内边距;2 行 + 标题 = 3 行高
  let (w, h) = ci_tip_size("标题", [
    ("#111111", "x"),
    ("#222222", "长长长内容"),
  ])
  assert_eq(w, 14 + 5 * 7 + 16)
  assert_eq(h, 3 * 18 + 16)
}

///|
test "ci_tooltip_pos:默认偏移 / 右溢翻左 / 钳 margin / 上下钳" {
  // 中部:锚点右上 offset 14,垂直居中
  debug_inspect(
    ci_tooltip_pos(100.0, 150.0, 400.0, 300.0, 100.0, 40.0),
    content="(114, 130)",
  )
  // 右溢:翻到锚点左侧(390-14-100=276,未超 max_x=294)
  debug_inspect(
    ci_tooltip_pos(390.0, 150.0, 400.0, 300.0, 100.0, 40.0),
    content="(276, 130)",
  )
  // 画布比盒窄:两侧都钳到 margin 6
  debug_inspect(
    ci_tooltip_pos(390.0, 150.0, 400.0, 300.0, 500.0, 40.0),
    content="(6, 130)",
  )
  // 贴顶:y 钳到 margin
  debug_inspect(
    ci_tooltip_pos(100.0, 2.0, 400.0, 300.0, 100.0, 40.0),
    content="(114, 6)",
  )
  // 贴底:y 钳到 canvas_h - margin - tip_h
  debug_inspect(
    ci_tooltip_pos(100.0, 299.0, 400.0, 300.0, 100.0, 40.0),
    content="(114, 254)",
  )
  // 自定义 offset/margin
  debug_inspect(
    ci_tooltip_pos(
      100.0,
      150.0,
      400.0,
      300.0,
      100.0,
      40.0,
      offset=20.0,
      margin=10.0,
    ),
    content="(120, 130)",
  )
}

///|
test "ci_nearest_idx:均布最近点 / 界外 / 退化" {
  // 5 点均布 [0,100]:步长 25
  assert_eq(ci_nearest_idx(0.0, 5, 0.0, 100.0), 0)
  assert_eq(ci_nearest_idx(12.0, 5, 0.0, 100.0), 0)
  assert_eq(ci_nearest_idx(13.0, 5, 0.0, 100.0), 1)
  assert_eq(ci_nearest_idx(50.0, 5, 0.0, 100.0), 2)
  assert_eq(ci_nearest_idx(62.0, 5, 0.0, 100.0), 2)
  assert_eq(ci_nearest_idx(63.0, 5, 0.0, 100.0), 3)
  assert_eq(ci_nearest_idx(100.0, 5, 0.0, 100.0), 4)
  // 与 map_idx 互为逆:落在某序号确切像素上必取该序号
  let px3 = map_idx(3, 8, 46.0, 500.0)
  assert_eq(ci_nearest_idx(px3, 8, 46.0, 500.0), 3)
  // 界外(含边界外一粒)
  assert_eq(ci_nearest_idx(-0.1, 5, 0.0, 100.0), -1)
  assert_eq(ci_nearest_idx(100.1, 5, 0.0, 100.0), -1)
  // 退化:n<=0 / 绘制区退化 / 单点
  assert_eq(ci_nearest_idx(50.0, 0, 0.0, 100.0), -1)
  assert_eq(ci_nearest_idx(50.0, 5, 100.0, 100.0), -1)
  assert_eq(ci_nearest_idx(50.0, 1, 0.0, 100.0), 0)
}

///|
test "ci_sector_at:四象限 / 环带容差 / 负值扇区 / 全负" {
  // 4 等值扇区,环带 r 10..50,中心 (100,100)
  let vs = [1.0, 1.0, 1.0, 1.0]
  assert_eq(ci_sector_at(100.0, 70.0, 100.0, 100.0, 10.0, 50.0, vs), 0) // 12 点
  assert_eq(ci_sector_at(130.0, 100.0, 100.0, 100.0, 10.0, 50.0, vs), 1) // 3 点
  assert_eq(ci_sector_at(100.0, 130.0, 100.0, 100.0, 10.0, 50.0, vs), 2) // 6 点
  assert_eq(ci_sector_at(70.0, 100.0, 100.0, 100.0, 10.0, 50.0, vs), 3) // 9 点
  // 环带容差 4:内孔 r=5 出界,r=7 命中;外缘 r=52 命中,r=55 出界
  assert_eq(ci_sector_at(100.0, 95.0, 100.0, 100.0, 10.0, 50.0, vs), -1)
  assert_eq(ci_sector_at(100.0, 93.0, 100.0, 100.0, 10.0, 50.0, vs), 0)
  assert_eq(ci_sector_at(100.0, 48.0, 100.0, 100.0, 10.0, 50.0, vs), 0)
  assert_eq(ci_sector_at(100.0, 45.0, 100.0, 100.0, 10.0, 50.0, vs), -1)
  // 不等值:[2,1,1] → 扇区 0 占一半 [0,0.5),扇区 1 [0.5,0.75),扇区 2 [0.75,1)
  let half = [2.0, 1.0, 1.0]
  assert_eq(ci_sector_at(100.0, 70.0, 100.0, 100.0, 10.0, 50.0, half), 0) // 12 点 → frac 0
  assert_eq(ci_sector_at(130.0, 100.0, 100.0, 100.0, 10.0, 50.0, half), 0) // 3 点 → frac 0.25 仍在扇区 0
  assert_eq(ci_sector_at(82.0, 124.0, 100.0, 100.0, 10.0, 50.0, half), 1) // 约 127° → frac≈0.60
  // 负值零张角不可命中:[1,-1,1] 只有扇区 0([0,0.5))与扇区 2([0.5,1))
  let neg = [1.0, -1.0, 1.0]
  assert_eq(ci_sector_at(130.0, 100.0, 100.0, 100.0, 10.0, 50.0, neg), 0)
  assert_eq(ci_sector_at(70.0, 100.0, 100.0, 100.0, 10.0, 50.0, neg), 2)
  assert_eq(
    ci_sector_at(100.0, 70.0, 100.0, 100.0, 10.0, 50.0, [0.0, -1.0]),
    -1,
  )
}

///|
test "CiPlot::frac:端点 / 中点 / 界外钳制 / 退化" {
  let pl = CiPlot::make(46.0, 12.0, 500.0, 282.0)
  assert_eq(pl.frac(46.0), 0.0)
  assert_eq(pl.frac(500.0), 1.0)
  assert_eq(pl.frac(273.0), 0.5)
  assert_eq(pl.frac(0.0), 0.0)
  assert_eq(pl.frac(600.0), 1.0)
  // 退化宽:0.5(缩放锚点落中点)
  assert_eq(CiPlot::make(10.0, 0.0, 10.0, 100.0).frac(10.0), 0.5)
  // width() 退化兜底 1(拖拽平移除零保护)
  assert_eq(CiPlot::make(10.0, 0.0, 10.0, 100.0).width(), 1.0)
  assert_eq(pl.width(), 454.0)
  // contains 含边界
  assert_true(pl.contains(46.0, 12.0))
  assert_true(pl.contains(500.0, 282.0))
  assert_true(!pl.contains(45.9, 12.0))
}
