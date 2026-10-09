// 平行坐标图白盒测试：纯函数（列提取 / 量程推断与合成 / 归一 / 轴 x 坐标
// 分配 / 行折线顶点 / 布局几何）语义，ParAxis 构造与 Store 驱动；绘制函数
// 保证可编译（真实绘制走 on_draw，由用户真机验证）。

///|
test "par_axis_column：跨行提取 / 短行跳过 / 越界" {
  let rows = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]]
  assert_eq(par_axis_column(rows, 0), [1.0, 4.0, 7.0])
  assert_eq(par_axis_column(rows, 2), [3.0, 6.0, 9.0])
  // 短行跳过（第二行只有 1 列，取列 1 时跳过）
  let short = [[1.0, 2.0], [3.0]]
  assert_eq(par_axis_column(short, 1), [2.0])
  // 越界：空
  assert_eq(par_axis_column(rows, 3), [])
  assert_eq(par_axis_column(rows, -1), [])
  assert_eq(par_axis_column([], 0), [])
}

///|
test "par_axis_range：min/max 推断 / 空列 / 等值退化" {
  // 正常：端点即量程，不加留白
  assert_eq(par_axis_range([2.0, 8.0, 5.0]), (2.0, 8.0))
  assert_eq(par_axis_range([-3.0, 7.0]), (-3.0, 7.0))
  // 单值：等值退化，|值|<10 时 ±1
  assert_eq(par_axis_range([4.0]), (3.0, 5.0))
  // 空列：(0, 1)
  assert_eq(par_axis_range([]), (0.0, 1.0))
  // 等值退化：|值|<10 时 ±1，大值时 ±10%
  assert_eq(par_axis_range([5.0, 5.0, 5.0]), (4.0, 6.0))
  assert_eq(par_axis_range([50.0, 50.0]), (45.0, 55.0))
}

///|
test "par_axis_ranges：显式优先 / 缺端推断 / 交换 / 退化兜底" {
  let rows = [[2.0, 100.0], [8.0, 300.0]]
  // 无显式：两轴各自推断
  let auto_axes = [ParAxis::make("a"), ParAxis::make("b")]
  assert_eq(par_axis_ranges(auto_axes, rows), [(2.0, 8.0), (100.0, 300.0)])
  // 显式覆盖一端，另一端仍取推断
  let one = [
    ParAxis::make("a", min=Some(0.0)),
    ParAxis::make("b", max=Some(500.0)),
  ]
  assert_eq(par_axis_ranges(one, rows), [(0.0, 8.0), (100.0, 500.0)])
  // 两端都显式：数据完全不参算
  let both = [ParAxis::make("a", min=Some(-1.0), max=Some(11.0))]
  assert_eq(par_axis_ranges(both, rows), [(-1.0, 11.0)])
  // lo > hi 交换
  let swapped = [ParAxis::make("a", min=Some(10.0), max=Some(0.0))]
  assert_eq(par_axis_ranges(swapped, rows), [(0.0, 10.0)])
  // 合成后退化（min==max）：以值为中心撑开
  let flat = [ParAxis::make("a", min=Some(5.0), max=Some(5.0))]
  assert_eq(par_axis_ranges(flat, rows), [(4.0, 6.0)])
  // 只给 min 且无数据：另一端取空列推断 (0,1) 后交换
  let nodata = [ParAxis::make("a", min=Some(5.0))]
  assert_eq(par_axis_ranges(nodata, []), [(1.0, 5.0)])
  // 无轴：空
  assert_eq(par_axis_ranges([], rows), [])
}

///|
test "par_norm：量程归一 / 两端钳制 / 退化取中点" {
  assert_true((par_norm(5.0, 0.0, 10.0) - 0.5).abs() < 1.0e-12)
  assert_eq(par_norm(0.0, 0.0, 10.0), 0.0)
  assert_eq(par_norm(10.0, 0.0, 10.0), 1.0)
  assert_eq(par_norm(15.0, 0.0, 10.0), 1.0) // 超量程钳到 1
  assert_eq(par_norm(-2.0, 0.0, 10.0), 0.0) // 负值钳到 0
  assert_true((par_norm(7.5, 0.0, 30.0) - 0.25).abs() < 1.0e-12)
  // 负量程：-3 在 [-5, -1] 正中
  assert_true((par_norm(-3.0, -5.0, -1.0) - 0.5).abs() < 1.0e-12)
  // 量程退化：中点
  assert_eq(par_norm(5.0, 3.0, 3.0), 0.5)
  assert_eq(par_norm(-9.0, -5.0, -5.0), 0.5)
}

///|
test "par_axis_x：等距横排 / 首末贴边 / 退化取中点" {
  // 3 轴均布 [50, 500]：50 → 275 → 500，间距 225
  assert_true((par_axis_x(0, 3, 50.0, 500.0) - 50.0).abs() < 1.0e-9)
  assert_true((par_axis_x(1, 3, 50.0, 500.0) - 275.0).abs() < 1.0e-9)
  assert_true((par_axis_x(2, 3, 50.0, 500.0) - 500.0).abs() < 1.0e-9)
  // 等距：任意相邻轴间距一致
  let n = 6
  let step = par_axis_x(1, n, 0.0, 100.0) - par_axis_x(0, n, 0.0, 100.0)
  for i in 1..<n {
    let d = par_axis_x(i + 1, n, 0.0, 100.0) - par_axis_x(i, n, 0.0, 100.0)
    assert_true((d - step).abs() < 1.0e-9)
  }
  // 首末轴即绘制区两端
  assert_eq(par_axis_x(0, 4, 12.0, 88.0), 12.0)
  assert_eq(par_axis_x(3, 4, 12.0, 88.0), 88.0)
  // 退化：n <= 1 取绘制区中点
  assert_eq(par_axis_x(0, 1, 50.0, 500.0), 275.0)
  assert_eq(par_axis_x(0, 0, 50.0, 500.0), 275.0)
  assert_eq(par_axis_x(3, -2, 10.0, 30.0), 20.0)
}

///|
test "par_row_vertices：逐轴归一化顶点 / 缺维取中 / 越界钳制" {
  // 2 轴 [50, 500]×[0, 200]，两轴量程 (0,10)/(0,100)
  let ranges = [(0.0, 10.0), (0.0, 100.0)]
  // [5, 50]：两轴各半 → y 都在中线 100
  let mid = par_row_vertices([5.0, 50.0], ranges, 50.0, 500.0, 0.0, 200.0)
  assert_eq(mid.length(), 2)
  assert_eq(mid[0], (50.0, 100.0))
  assert_eq(mid[1], (500.0, 100.0))
  // [0, 100]：满量程 → 顶点贴上边 y=0；[10, 0] → 贴下边 y=200
  let top = par_row_vertices([10.0, 100.0], ranges, 50.0, 500.0, 0.0, 200.0)
  assert_eq(top[0], (50.0, 0.0))
  assert_eq(top[1], (500.0, 0.0))
  let bottom = par_row_vertices([0.0, 0.0], ranges, 50.0, 500.0, 0.0, 200.0)
  assert_eq(bottom[0], (50.0, 200.0))
  assert_eq(bottom[1], (500.0, 200.0))
  // 超程钳制：[15, -5] → 与满量程同顶点
  let clamped = par_row_vertices([15.0, -5.0], ranges, 50.0, 500.0, 0.0, 200.0)
  assert_eq(clamped[0], (50.0, 0.0))
  assert_eq(clamped[1], (500.0, 200.0))
  // 缺维：行只有 1 列，缺失维按该轴中点（(0+100)/2 → 0.5 → y=100）
  let short = par_row_vertices([5.0], ranges, 50.0, 500.0, 0.0, 200.0)
  assert_eq(short.length(), 2)
  assert_eq(short[0], (50.0, 100.0))
  assert_eq(short[1], (500.0, 100.0))
  // 行多出的维忽略（轴数仍以 ranges 为准）
  let long = par_row_vertices([1.0, 2.0, 3.0], ranges, 50.0, 500.0, 0.0, 200.0)
  assert_eq(long.length(), 2)
  // 各轴独立量程：同分值在不同量程轴上高度不同
  let mixed = par_row_vertices(
    [8.0, 80.0],
    [(0.0, 10.0), (0.0, 100.0)],
    50.0,
    500.0,
    20.0,
    120.0,
  )
  assert_true((mixed[0].1 - 40.0).abs() < 1.0e-9) // 0.8 → y = 120-0.8*100
  assert_true((mixed[1].1 - 40.0).abs() < 1.0e-9)
  let skew = par_row_vertices(
    [5.0, 50.0],
    [(0.0, 10.0), (0.0, 1000.0)],
    50.0,
    500.0,
    20.0,
    120.0,
  )
  assert_true((skew[0].1 - 70.0).abs() < 1.0e-9) // 0.5 → 中线 y=120-0.5*100
  assert_true((skew[1].1 - 115.0).abs() < 1.0e-9) // 0.05 → 贴近底边 y=120-0.05*100
  // 轴数 < 2：单顶点落在中点（绘制层画点不画线）
  let single = par_row_vertices([9.0], [(0.0, 10.0)], 50.0, 500.0, 0.0, 200.0)
  assert_eq(single.length(), 1)
  assert_eq(single[0], (275.0, 20.0)) // 0.9 → y = 200-0.9*200
  // 空量程：无顶点
  assert_eq(
    par_row_vertices([1.0, 2.0], [], 50.0, 500.0, 0.0, 200.0).length(),
    0,
  )
}

///|
test "par_layout：标签预留 / 空矩形判定" {
  // 左右各留 50、顶部 28、底部 12
  let (x0, y0, x1, y1) = par_layout(640.0, 320.0)
  assert_eq(x0, 50.0)
  assert_eq(y0, 28.0)
  assert_eq(x1, 590.0)
  assert_eq(y1, 308.0)
  // 窄画布：绘制区退化为空矩形（x1 <= x0）
  let (nx0, _ny0, nx1, _ny1) = par_layout(80.0, 320.0)
  assert_true(nx1 <= nx0)
  // 矮画布
  let (_mx0, my0, _mx1, my1) = par_layout(640.0, 30.0)
  assert_true(my1 <= my0)
}

///|
test "ParAxis 构造 / 量程省略与显式 / Store 驱动" {
  // 省略 min/max：由数据推断
  let auto = ParAxis::make("年龄")
  assert_eq(auto.name, "年龄")
  assert_eq(auto.min, None)
  assert_eq(auto.max, None)
  // 显式一端
  let lo_only = ParAxis::make("分数", max=Some(100.0))
  assert_eq(lo_only.min, None)
  assert_eq(lo_only.max, Some(100.0))
  // 两端显式
  let both = ParAxis::make("温度", min=Some(-20.0), max=Some(60.0))
  assert_eq(both.min, Some(-20.0))
  assert_eq(both.max, Some(60.0))
  // rows 为 Array[Array[Double]]：行即折线，列即轴
  let rows = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]
  assert_eq(rows.length(), 2)
  debug_inspect(rows[0], content="[1, 2, 3]")
  // Store 驱动：axes / rows 各自 set 触发订阅
  let axes : @yue.Store[Array[ParAxis]] = @yue.Store::new([
    ParAxis::make("a"),
    ParAxis::make("b"),
    ParAxis::make("c"),
  ])
  let data : @yue.Store[Array[Array[Double]]] = @yue.Store::new([[1.0, 2.0, 3.0]])
  let hits = Ref(0)
  axes.subscribe(fn(_a) { hits.val = hits.val + 1 })
  data.subscribe(fn(_r) { hits.val = hits.val + 1 })
  axes.set([ParAxis::make("x"), ParAxis::make("y")])
  data.set([[1.0, 2.0], [3.0, 4.0]])
  assert_eq(hits.val, 2)
  assert_eq(axes.get().length(), 2)
  assert_eq(data.get().length(), 2)
}
