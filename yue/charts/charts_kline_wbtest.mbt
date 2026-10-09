// K 线图白盒测试：量程（全体 low/high 外扩）、涨跌判定、槽位（x 等距
// 排布 + 实体宽）、每根 K 线的实体矩形与影线几何计算。

///|
test "kline_range：全体 low/high 外扩/空/等值退化/乱序容错" {
  // 正常：min(low)=9 .. max(high)=15，span 6 + 8% 留白
  let (lo, hi) = kline_range([
    Candle::make(10.0, 12.0, 9.0, 11.0),
    Candle::make(11.0, 15.0, 10.5, 14.0),
  ])
  assert_true((lo - 8.52).abs() < 1.0e-9)
  assert_true((hi - 15.48).abs() < 1.0e-9)
  // 空数据
  assert_eq(kline_range([]), (0.0, 1.0))
  // 等值退化：|值|<10 时 ±1
  let (l2, h2) = kline_range([Candle::make(5.0, 5.0, 5.0, 5.0)])
  assert_eq(l2, 4.0)
  assert_eq(h2, 6.0)
  // 等值退化：|值|>=10 时 ±10%
  let (l3, h3) = kline_range([Candle::make(100.0, 100.0, 100.0, 100.0)])
  assert_true((l3 - 90.0).abs() < 1.0e-9)
  assert_true((h3 - 110.0).abs() < 1.0e-9)
  // 单根 low > high 乱序：交换后仍给有序量程
  let (l4, h4) = kline_range([Candle::make(15.0, 10.0, 20.0, 12.0)])
  assert_true((l4 - 9.2).abs() < 1.0e-9)
  assert_true((h4 - 20.8).abs() < 1.0e-9)
  // open/close 越界不参算：量程只看 low=10/high=30
  let (l5, h5) = kline_range([Candle::make(100.0, 30.0, 10.0, 0.0)])
  assert_true((l5 - 8.4).abs() < 1.0e-9)
  assert_true((h5 - 31.6).abs() < 1.0e-9)
}

///|
test "kline_is_up：close>=open 记涨，平盘归涨" {
  assert_true(kline_is_up(Candle::make(10.0, 12.0, 9.0, 11.0))) // 涨
  assert_false(kline_is_up(Candle::make(11.0, 12.0, 9.0, 10.0))) // 跌
  assert_true(kline_is_up(Candle::make(10.0, 12.0, 9.0, 10.0))) // 平盘归涨
}

///|
test "kline_slot：x 等距排布/实体宽/ratio 钳制/窄槽钳 1" {
  // n=2 均分 0..100：中心 25/75，槽宽 50 × 0.7 = 35
  assert_eq(kline_slot(0, 2, 0.0, 100.0), (25.0, 35.0))
  assert_eq(kline_slot(1, 2, 0.0, 100.0), (75.0, 35.0))
  // 等距：相邻中心差恒为槽宽
  let n = 4
  let slot = 100.0 / n.to_double()
  let mut prev = 0.0
  for i in 0..<n {
    let (cx, _w) = kline_slot(i, n, 0.0, 100.0)
    if i > 0 {
      assert_true((cx - prev - slot).abs() < 1.0e-9)
    }
    prev = cx
  }
  // 自定义比例 / 越界钳制（0 → 宽 1，2.0 → 钳 1）
  assert_eq(kline_slot(0, 2, 0.0, 100.0, ratio=0.5), (25.0, 25.0))
  assert_eq(kline_slot(0, 2, 0.0, 100.0, ratio=0.0), (25.0, 1.0))
  assert_eq(kline_slot(0, 2, 0.0, 100.0, ratio=2.0), (25.0, 50.0))
  // 密集：200 根挤 50px，实体宽钳到 >=1
  let (_cx, w) = kline_slot(0, 200, 0.0, 50.0)
  assert_true(w >= 1.0)
  // n<=0 兜底：居中 + 宽 >=1
  let (cx0, w0) = kline_slot(0, 0, 0.0, 100.0)
  assert_eq(cx0, 50.0)
  assert_true(w0 >= 1.0)
}

///|
test "kline_body_rect：实体矩形（涨跌同跨/平盘钳 1）" {
  // 值域 0..100 → 画布 y 0..100（map_y = 100 - v）
  // 涨：open=40→y=60，close=60→y=40：顶 40，高 20；单根实体宽 70，x=15
  let up = Candle::make(40.0, 80.0, 20.0, 60.0)
  let (x, y, w, h) = kline_body_rect(
    0, 1, up, 0.0, 100.0, 0.0, 100.0, 0.0, 100.0,
  )
  assert_eq(x, 15.0)
  assert_eq(y, 40.0)
  assert_eq(w, 70.0)
  assert_eq(h, 20.0)
  // 跌：open=60→y=40，close=40→y=60：矩形同跨 open..close，顶 40 高 20
  let dn = Candle::make(60.0, 80.0, 20.0, 40.0)
  let (_x2, y2, _w2, h2) = kline_body_rect(
    0, 1, dn, 0.0, 100.0, 0.0, 100.0, 0.0, 100.0,
  )
  assert_eq(y2, 40.0)
  assert_eq(h2, 20.0)
  // 平盘：高度钳到 >=1 保持可见
  let flat = Candle::make(50.0, 70.0, 30.0, 50.0)
  let (_x3, _y3, _w3, h3) = kline_body_rect(
    0, 1, flat, 0.0, 100.0, 0.0, 100.0, 0.0, 100.0,
  )
  assert_true(h3 >= 1.0)
  // 非归一化几何：值域 0..200 映射画布 10..110（每 2 值 1px）
  let c4 = Candle::make(80.0, 180.0, 20.0, 120.0)
  let (_x4, y4, _w4, h4) = kline_body_rect(
    0, 1, c4, 0.0, 200.0, 0.0, 100.0, 10.0, 110.0,
  )
  assert_true((y4 - 50.0).abs() < 1.0e-9) // close=120 → y=110-60=50
  assert_true((h4 - 20.0).abs() < 1.0e-9) // open=80 → y=70
}

///|
test "kline_wick_span：影线过实体中心，high 上 low 下" {
  // 与 kline_slot 同源：n=2 时中心 25
  let c = Candle::make(40.0, 80.0, 20.0, 60.0)
  let (cx, yh, yl) = kline_wick_span(
    0, 2, c, 0.0, 100.0, 0.0, 100.0, 0.0, 100.0,
  )
  assert_eq(cx, 25.0)
  assert_eq(yh, 20.0) // high=80 → y=20（上端）
  assert_eq(yl, 80.0) // low=20 → y=80（下端）
  assert_true(yh < yl)
  // 值域退化：两端都取画布中点
  let (_cx1, yh1, yl1) = kline_wick_span(
    0, 2, c, 5.0, 5.0, 0.0, 100.0, 10.0, 90.0,
  )
  assert_eq(yh1, 50.0)
  assert_eq(yl1, 50.0)
}
