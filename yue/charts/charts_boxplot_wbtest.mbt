// 箱线图白盒测试：纯函数层（分位插值/五数概括/须端与离群判定/值域）
// 语义覆盖；绘制函数离屏可编译可跑，视觉验证走真机（AGENTS 规则 6）。

///|
test "boxp_quantile：线性插值/端点/钳制/退化" {
  let odd = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
  assert_eq(boxp_quantile(odd, 0.25), 3.0)
  assert_eq(boxp_quantile(odd, 0.5), 5.0)
  assert_eq(boxp_quantile(odd, 0.75), 7.0)
  assert_eq(boxp_quantile(odd, 0.0), 1.0)
  assert_eq(boxp_quantile(odd, 1.0), 9.0)
  // 偶数 n：位置落在相邻样本间，按小数部分加权
  let even = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
  assert_true((boxp_quantile(even, 0.25) - 3.25).abs() < 1.0e-9)
  assert_true((boxp_quantile(even, 0.5) - 5.5).abs() < 1.0e-9)
  assert_true((boxp_quantile(even, 0.75) - 7.75).abs() < 1.0e-9)
  // q 越界钳到 0..1
  assert_eq(boxp_quantile(odd, -1.0), 1.0)
  assert_eq(boxp_quantile(odd, 2.0), 9.0)
  // 退化
  assert_eq(boxp_quantile([5.0], 0.7), 5.0)
  assert_eq(boxp_quantile([], 0.5), 0.0)
}

///|
test "boxp_summary：奇数五数（乱序输入，内部排序且不改入参）" {
  let vals = [9.0, 1.0, 5.0, 3.0, 7.0, 2.0, 8.0, 4.0, 6.0]
  let s = boxp_summary(vals)
  assert_eq(s.min, 1.0)
  assert_eq(s.q1, 3.0)
  assert_eq(s.median, 5.0)
  assert_eq(s.q3, 7.0)
  assert_eq(s.max, 9.0)
  // IQR=4，围栏 [-3, 13]，无离群：须端即 min/max
  assert_eq(s.whisker_lo, 1.0)
  assert_eq(s.whisker_hi, 9.0)
  debug_inspect(s.outliers, content="[]")
  // 入参数组不变
  debug_inspect(vals, content="[9, 1, 5, 3, 7, 2, 8, 4, 6]")
}

///|
test "boxp_summary：偶数插值 + 高端离群（须端收到围栏内最远样本）" {
  // n=10：Q1=3.25 中位=5.5 Q3=7.75，IQR=4.5，围栏 [-3.5, 14.5]
  let s = boxp_summary([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 100.0])
  assert_eq(s.min, 1.0)
  assert_true((s.q1 - 3.25).abs() < 1.0e-9)
  assert_true((s.median - 5.5).abs() < 1.0e-9)
  assert_true((s.q3 - 7.75).abs() < 1.0e-9)
  assert_eq(s.max, 100.0)
  assert_eq(s.whisker_lo, 1.0)
  assert_eq(s.whisker_hi, 9.0)
  debug_inspect(s.outliers, content="[100]")
}

///|
test "boxp_summary：低端离群 + 双端离群（整数位已知答案）" {
  // n=10：Q1=2.25 中位=4.5 Q3=6.75，围栏 [-4.5, 13.5]
  let lo = boxp_summary([-50.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0])
  assert_true((lo.q1 - 2.25).abs() < 1.0e-9)
  assert_true((lo.median - 4.5).abs() < 1.0e-9)
  assert_true((lo.q3 - 6.75).abs() < 1.0e-9)
  assert_eq(lo.whisker_lo, 1.0)
  assert_eq(lo.whisker_hi, 9.0)
  debug_inspect(lo.outliers, content="[-50]")
  // n=13：Q1=2 中位=5 Q3=8（位置恰为整下标），IQR=6，围栏 [-7, 17]
  let both = boxp_summary([
    5.0, 200.0, 1.0, 3.0, -100.0, 7.0, 9.0, 0.0, 4.0, 10.0, 2.0, 8.0, 6.0,
  ])
  assert_eq(both.min, -100.0)
  assert_eq(both.q1, 2.0)
  assert_eq(both.median, 5.0)
  assert_eq(both.q3, 8.0)
  assert_eq(both.max, 200.0)
  assert_eq(both.whisker_lo, 0.0)
  assert_eq(both.whisker_hi, 10.0)
  debug_inspect(both.outliers, content="[-100, 200]")
}

///|
test "boxp_summary：退化（空/单值/全同/IQR 为零）" {
  let e = boxp_summary([])
  assert_eq(e.min, 0.0)
  assert_eq(e.q1, 0.0)
  assert_eq(e.median, 0.0)
  assert_eq(e.q3, 0.0)
  assert_eq(e.max, 0.0)
  debug_inspect(e.outliers, content="[]")
  let one = boxp_summary([5.0])
  assert_eq(one.min, 5.0)
  assert_eq(one.q1, 5.0)
  assert_eq(one.median, 5.0)
  assert_eq(one.q3, 5.0)
  assert_eq(one.max, 5.0)
  assert_eq(one.whisker_lo, 5.0)
  assert_eq(one.whisker_hi, 5.0)
  debug_inspect(one.outliers, content="[]")
  let same = boxp_summary([7.0, 7.0, 7.0, 7.0])
  assert_eq(same.q1, 7.0)
  assert_eq(same.whisker_lo, 7.0)
  assert_eq(same.whisker_hi, 7.0)
  debug_inspect(same.outliers, content="[]")
  // IQR=0：围栏收缩到 [Q1, Q3]，恰好等于围栏的样本不算离群
  let flat = boxp_summary([1.0, 1.0, 1.0, 1.0, 5.0])
  assert_eq(flat.q1, 1.0)
  assert_eq(flat.q3, 1.0)
  assert_eq(flat.whisker_lo, 1.0)
  assert_eq(flat.whisker_hi, 1.0)
  debug_inspect(flat.outliers, content="[5]")
}

///|
test "boxp_summary：BoxSummary::make 字段构造" {
  let m = BoxSummary::make(1.0, 2.0, 3.0, 4.0, 5.0, 2.0, 4.0, [])
  assert_eq(m.min, 1.0)
  assert_eq(m.q1, 2.0)
  assert_eq(m.median, 3.0)
  assert_eq(m.q3, 4.0)
  assert_eq(m.max, 5.0)
  assert_eq(m.whisker_lo, 2.0)
  assert_eq(m.whisker_hi, 4.0)
  debug_inspect(m.outliers, content="[]")
}

///|
test "boxp_range：留白/含离群/空/等值退化/负值" {
  // 正常：8% 留白，跨组取全体样本 min/max
  let (lo, hi) = boxp_range([("a", [10.0, 20.0]), ("b", [15.0])])
  assert_true((lo - 9.2).abs() < 1.0e-9)
  assert_true((hi - 20.8).abs() < 1.0e-9)
  // 离群点计入（圆点不裁剪）
  let (lo2, hi2) = boxp_range([("a", [0.0, 100.0]), ("b", [50.0])])
  assert_true((lo2 - -8.0).abs() < 1.0e-9)
  assert_true((hi2 - 108.0).abs() < 1.0e-9)
  // 空数据 / 组存在但值全空
  assert_eq(boxp_range([]), (0.0, 1.0))
  assert_eq(boxp_range([("a", [])]), (0.0, 1.0))
  // 等值退化：|值|<10 时 ±1
  assert_eq(boxp_range([("a", [5.0, 5.0])]), (4.0, 6.0))
  // 跨负值：12 跨度 8% 留白
  let (lo3, hi3) = boxp_range([("a", [-4.0, 8.0])])
  assert_true((lo3 - -4.96).abs() < 1.0e-9)
  assert_true((hi3 - 8.96).abs() < 1.0e-9)
}
