// 主题河流图白盒测试：纯函数（时间轴长度 / 取值 / 列总计 / 堆叠偏移 /
// 河流值域 / 样条控制点 / 层带像素 / 序列总量 / 层名兜底）语义，构造函数
// 与 Store 驱动语义；绘制函数（trv_path_spline / trv_draw / trv_chart_t）
// 走 GUI 挂载路径，保证可编译即可，视觉验证按仓库惯例由真机示例承担。

///|
test "trv_axis_len：时间轴长度取全体序列最大长度" {
  assert_eq(trv_axis_len([]), 0)
  assert_eq(trv_axis_len([[1.0, 2.0]]), 2)
  // 参差行：短序列缺失位按 0 计，轴长以最长行为准
  assert_eq(trv_axis_len([[1.0, 1.0, 1.0, 1.0], [10.0], []]), 4)
}

///|
test "trv_row_at：越界按 0 / 负值按 0" {
  let values : Array[Array[Double]] = [[3.0, -1.0], [0.5]]
  assert_eq(trv_row_at(values, 0, 0), 3.0)
  assert_eq(trv_row_at(values, 0, 1), 0.0) // 负值口径
  assert_eq(trv_row_at(values, 1, 0), 0.5)
  // 序列越界 / 时间点越界（短行、轴外）一律 0
  assert_eq(trv_row_at(values, 1, 1), 0.0)
  assert_eq(trv_row_at(values, 2, 0), 0.0)
  assert_eq(trv_row_at(values, -1, 0), 0.0)
  assert_eq(trv_row_at(values, 0, 99), 0.0)
  assert_eq(trv_row_at([], 0, 0), 0.0)
}

///|
test "trv_total_at：列总计（负值已按 0、缺失位按 0）" {
  let values : Array[Array[Double]] = [
    [2.0, 1.0, 1.0, 1.0],
    [3.0, -5.0],
    [1.0, 1.0, 1.0, 1.0],
  ]
  assert_eq(trv_total_at(values, 0), 6.0)
  assert_eq(trv_total_at(values, 1), 2.0) // 1 + 0 + 1
  assert_eq(trv_total_at(values, 3), 2.0)
  assert_eq(trv_total_at([], 0), 0.0)
}

///|
test "trv_stack_offsets：TrvZero 自 0 起逐层累加 / 层序连续" {
  let values : Array[Array[Double]] = [[2.0, 2.0], [3.0], [1.0, 1.0, 1.0]]
  let offs = trv_stack_offsets(values, TrvZero)
  assert_eq(offs.length(), 3)
  // 首层下缘恒 0；逐层累加：offs[j+1] = offs[j] + 本层厚
  assert_eq(offs[0][0], 0.0)
  assert_eq(offs[1][0], 2.0)
  assert_eq(offs[2][0], 5.0) // 2 + 3（末层仅一点）
  // 短行缺失位按 0：t=1/2 该列总计 = 2 + 0 + 1（row0 长 2、row1 长 1）
  assert_eq(offs[0][2], 0.0)
  assert_eq(offs[1][2], 0.0) // 上一层到 t=2 仅累计 0（row0 已越界）
  assert_eq(offs[2][2], 0.0)
  // 末层上缘 = 列总计
  assert_true(
    (offs[2][0] + trv_row_at(values, 2, 0) - trv_total_at(values, 0)).abs() <
    1.0e-12,
  )
  // 层带互不重叠：j+1 层下缘即 j 层上缘
  for t in 0..<trv_axis_len(values) {
    for j in 0..<(values.length() - 1) {
      assert_true(
        (offs[j + 1][t] - (offs[j][t] + trv_row_at(values, j, t))).abs() <
        1.0e-12,
      )
    }
  }
}

///|
test "trv_stack_offsets：TrvSym 围绕水平中轴对称（上下对称断言）" {
  let values : Array[Array[Double]] = [[2.0, 2.0], [3.0, 3.0], [1.0, 1.0]]
  let offs = trv_stack_offsets(values, TrvSym)
  // 每列：首层下缘 = -总计/2，末层上缘 = +总计/2（堆叠整体对偶于 0）
  for t in 0..<trv_axis_len(values) {
    let total = trv_total_at(values, t)
    assert_true((offs[0][t] + total / 2.0).abs() < 1.0e-12)
    assert_true(
      (offs[2][t] + trv_row_at(values, 2, t) - total / 2.0).abs() < 1.0e-12,
    )
    // 对称中轴：堆叠带的纵向中心即 0 值线
    let mid = (offs[0][t] + (offs[2][t] + trv_row_at(values, 2, t))) / 2.0
    assert_true(mid.abs() < 1.0e-12)
  }
  // 等值两层特例：两半列厚度相同、缝恰落在 0（经典 wiggle 中枢形态）
  let pair : Array[Array[Double]] = [[2.0], [2.0]]
  let on = trv_stack_offsets(pair, TrvSym)
  assert_eq(on[0][0], 0.0 - 2.0)
  assert_eq(on[0][0] + 2.0, 0.0)
  assert_eq(on[1][0], 0.0)
  assert_eq(on[1][0] + 2.0, 2.0)
  // 与 TrvZero 同数据不同基线：Zero 首层贴 0，Sym 首层沉到 -总计/2
  let z = trv_stack_offsets(pair, TrvZero)
  assert_eq(z[0][0], 0.0)
  assert_true((z[0][0] - on[0][0] - 2.0).abs() < 1.0e-12)
}

///|
test "trv_stack_offsets：空表 / 全零列表 / 入参不变" {
  let empty : Array[Array[Double]] = []
  assert_eq(trv_stack_offsets(empty, TrvSym).length(), 0)
  let zeros : Array[Array[Double]] = [[0.0, 0.0], [0.0, 0.0]]
  let offs = trv_stack_offsets(zeros, TrvSym)
  assert_eq(offs.length(), 2)
  assert_eq(offs[0][0], 0.0)
  assert_eq(offs[1][1], 0.0) // 全零：对称仍全贴 0
  // 入参不被改写（返回全新表）
  let values : Array[Array[Double]] = [[1.0], [1.0]]
  ignore(trv_stack_offsets(values, TrvSym))
  assert_eq(values[0][0], 1.0)
  assert_eq(values[1][0], 1.0)
}

///|
test "trv_range：空数据 / 全零退化 / 4% 留白" {
  let empty : Array[Array[Double]] = []
  assert_eq(trv_range(empty, TrvZero), (0.0, 1.0))
  // 全零（单点等值退化）：撑开 ±1
  let zeros : Array[Array[Double]] = [[0.0]]
  assert_eq(trv_range(zeros, TrvZero), (0.0 - 1.0, 1.0))
  // 正常带：min..max 之外两端各 4%
  let values : Array[Array[Double]] = [[2.0, 2.0], [3.0, 3.0]]
  let (lo, hi) = trv_range(values, TrvZero) // 数据带 0..5
  assert_true((lo + 5.0 * 0.04).abs() < 1.0e-12)
  assert_true((hi - 5.0 - 5.0 * 0.04).abs() < 1.0e-12)
  // 参差行：缺失位按 0，量程照累计极值（首列 1+10=11 封顶）
  let ragged : Array[Array[Double]] = [[1.0, 1.0, 1.0, 1.0], [10.0]]
  let (rlo, rhi) = trv_range(ragged, TrvZero)
  assert_true((rlo + 11.0 * 0.04).abs() < 1.0e-12)
  assert_true((rhi - 11.0 - 11.0 * 0.04).abs() < 1.0e-12)
}

///|
test "trv_range：TrvSym 量程天然对偶（lo == -hi）" {
  let values : Array[Array[Double]] = [[2.0, 2.0], [3.0, 3.0], [1.0, 1.0]]
  let (lo, hi) = trv_range(values, TrvSym) // 堆叠带恒 -3..+3
  assert_eq(lo, 0.0 - hi)
  assert_true((lo + 3.0 + 6.0 * 0.04).abs() < 1.0e-12)
  // 同一份数据换 Zero 基线：量程不再对偶（0 起堆）
  let (zlo, zhi) = trv_range(values, TrvZero)
  assert_true(zlo < 0.0 && zhi > 3.0)
  assert_true((zlo + 6.0 * 0.04).abs() < 1.0e-12)
  assert_true((zhi - 6.0 - 6.0 * 0.04).abs() < 1.0e-12)
}

///|
test "trv_spline_ctrl：Catmull-Rom 转三次贝塞尔的控制点" {
  let pts : Array[(Double, Double)] = [
    (0.0, 0.0),
    (1.0, 1.0),
    (2.0, 0.0),
    (3.0, 1.0),
  ]
  let ctrl = trv_spline_ctrl(pts)
  // 段数 = 点数 - 1；端点外推补点使样条过全部原始点
  assert_eq(ctrl.length(), 3)
  let (cp1_0, cp2_0) = ctrl[0]
  assert_true((cp1_0.0 - 1.0 / 6.0).abs() < 1.0e-12)
  assert_true((cp1_0.1 - 1.0 / 6.0).abs() < 1.0e-12)
  assert_true((cp2_0.0 - 2.0 / 3.0).abs() < 1.0e-12)
  assert_eq(cp2_0.1, 1.0)
  let (cp1_1, cp2_1) = ctrl[1]
  assert_true((cp1_1.0 - 4.0 / 3.0).abs() < 1.0e-12)
  assert_eq(cp1_1.1, 1.0)
  assert_true((cp2_1.0 - 5.0 / 3.0).abs() < 1.0e-12)
  assert_eq(cp2_1.1, 0.0)
  // 首末段端点外推（首段 prev = pts[0]、末段 next = pts[n-1]）
  let (cp1_2, cp2_2) = ctrl[2]
  assert_true((cp1_2.0 - 7.0 / 3.0).abs() < 1.0e-12)
  assert_eq(cp1_2.1, 0.0)
  assert_true((cp2_2.0 - 17.0 / 6.0).abs() < 1.0e-12)
  assert_true((cp2_2.1 - 5.0 / 6.0).abs() < 1.0e-12)
}

///|
test "trv_spline_ctrl：张力退折线 / 半点张力 / 点数不足空表" {
  let pts : Array[(Double, Double)] = [(0.0, 0.0), (1.0, 2.0), (3.0, 1.0)]
  // tension=0：控制点坍缩到线段两端（退化为直线）
  for i, (cp1, cp2) in trv_spline_ctrl(pts, tension=0.0) {
    assert_eq(cp1, pts[i])
    assert_eq(cp2, pts[i + 1])
  }
  // tension=0.5：标准值减半
  let std = trv_spline_ctrl(pts)
  let half = trv_spline_ctrl(pts, tension=0.5)
  let (s_cp1, s_cp2) = std[0]
  let (h_cp1, h_cp2) = half[0]
  assert_true(
    (h_cp1.0 - (pts[0].0 + (s_cp1.0 - pts[0].0) * 0.5)).abs() < 1.0e-12,
  )
  assert_true(
    (h_cp2.0 - (pts[1].0 + (s_cp2.0 - pts[1].0) * 0.5)).abs() < 1.0e-12,
  )
  // 点数 < 2 给空表（无段可走）
  assert_eq(trv_spline_ctrl([]).length(), 0)
  assert_eq(trv_spline_ctrl([(1.0, 1.0)]).length(), 0)
}

///|
test "trv_layer_band：值域映射 + 层带纵向拼接（层序）" {
  let values : Array[Array[Double]] = [[0.0, 10.0], [0.0, 10.0]]
  let offs = trv_stack_offsets(values, TrvZero)
  let (lo, hi) = (0.0, 10.0)
  let x0 = 0.0
  let x1 = 100.0
  let y0 = 0.0
  let y1 = 200.0
  // 时间索引入参：n=2 均布 x0..x1
  let (tx0, ty0, bx0, by0) = trv_layer_band(
    offs, values, lo, hi, x0, x1, y0, y1, 0, 0,
  )
  assert_eq(tx0, 0.0) // map_idx(0, 2)
  assert_eq(ty0, 200.0) // 上缘值 0 → 绘制区底
  assert_eq(by0, 200.0) // 下缘值 0 → 同底（该点零厚）
  assert_eq(bx0, tx0) // 上下缘同列
  let (tx1, ty1, bx1, by1) = trv_layer_band(
    offs, values, lo, hi, x0, x1, y0, y1, 0, 1,
  )
  assert_eq(tx1, 100.0) // 右端点贴 x1
  assert_eq(ty1, 0.0) // 上缘值 10 → 绘制区顶
  assert_eq(by1, 200.0) // 下缘回 0
  assert_eq(bx1, tx1) // 上下缘同列
  // 层序：j+1 层下缘即 j 层上缘（层带互不重叠、逐层拼接）
  let (_, tyj, _, _) = trv_layer_band(
    offs, values, lo, hi, x0, x1, y0, y1, 0, 1,
  )
  let (_, _, _, byj1) = trv_layer_band(
    offs, values, lo, hi, x0, x1, y0, y1, 1, 1,
  )
  assert_true((byj1 - tyj).abs() < 1.0e-12)
  // 上缘 y 不大于下缘 y（值域内层厚非负）
  let (_, t2y, _, b2y) = trv_layer_band(
    offs, values, lo, hi, x0, x1, y0, y1, 1, 0,
  )
  assert_true(t2y <= b2y)
  // 单点时间轴：x 取绘制区中点
  let one : Array[Array[Double]] = [[10.0]]
  let o1 = trv_stack_offsets(one, TrvZero)
  let (mx, mty, _, _) = trv_layer_band(
    o1, one, 0.0, 10.0, 40.0, 60.0, 0.0, 100.0, 0, 0,
  )
  assert_eq(mx, 50.0)
  assert_eq(mty, 0.0) // 上缘 10 → 顶
}

///|
test "trv_series_total：全时间点求和（负值按 0）/ 越界 0" {
  let values : Array[Array[Double]] = [[1.0, 2.0, -5.0, 3.0], [7.0]]
  assert_eq(trv_series_total(values, 0), 6.0)
  assert_eq(trv_series_total(values, 1), 7.0)
  assert_eq(trv_series_total(values, 2), 0.0) // 越界
  assert_eq(trv_series_total(values, -1), 0.0)
  assert_eq(trv_series_total([], 0), 0.0)
}

///|
test "trv_series_name：越界兜底占位" {
  let names : Array[String] = ["华东", "华南"]
  assert_eq(trv_series_name(names, 0), "华东")
  assert_eq(trv_series_name(names, 1), "华南")
  assert_eq(trv_series_name(names, 2), "\{2}")
  assert_eq(trv_series_name([], 0), "\{0}")
}

///|
test "Store 驱动：names / values 各自订阅、set 各通知一次" {
  let names : Store[Array[String]] = Store::new(["A", "B"])
  let values : Store[Array[Array[Double]]] = Store::new([[1.0, 1.0], [2.0, 2.0]])
  let nhits = Ref(0)
  let vhits = Ref(0)
  names.subscribe(fn(_n) { nhits.val = nhits.val + 1 })
  values.subscribe(fn(_v) { vhits.val = vhits.val + 1 })
  assert_eq(nhits.val, 0)
  assert_eq(vhits.val, 0)
  names.set(["A", "B", "C"])
  values.set([[1.0, 1.0, 1.0], [2.0, 2.0, 2.0], [3.0, 3.0, 3.0]])
  assert_eq(nhits.val, 1)
  assert_eq(vhits.val, 1)
  // 换数据后纯函数层跟随（时间轴随最长行增长）
  assert_eq(trv_axis_len(values.get()), 3)
  assert_eq(trv_series_name(names.get(), 2), "C")
  assert_eq(trv_total_at(values.get(), 2), 6.0)
}
