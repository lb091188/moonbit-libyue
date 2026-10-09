// 漏斗图白盒测试：纯函数（层排序/层几何/梯形顶底宽/占比百分比）语义
// 覆盖，写法对齐 charts_wbtest.mbt；绘制函数（funnel_draw/funnel_t）
// 以 moon check 编译通过为准，不在测试内驱动 GUI。

///|
test "funnel_sort：降序/等值保序/空表/入参不变" {
  // 乱序入参 → 降序
  let items = [
    BarItem::make("a", 30.0),
    BarItem::make("b", 100.0),
    BarItem::make("c", 50.0),
  ]
  let sorted = funnel_sort(items)
  debug_inspect(sorted.map(fn(it) { it.value }), content="[100, 50, 30]")
  // 入参不被修改
  debug_inspect(items.map(fn(it) { it.value }), content="[30, 100, 50]")
  // 等值保持原次序（稳定排序）
  let eq = [
    BarItem::make("b1", 5.0),
    BarItem::make("a1", 5.0),
    BarItem::make("c1", 3.0),
  ]
  let s2 = funnel_sort(eq)
  assert_eq(s2[0].label, "b1")
  assert_eq(s2[1].label, "a1")
  assert_eq(s2[2].label, "c1")
  // 空表
  assert_eq(funnel_sort([]).length(), 0)
}

///|
test "funnel_band：层高均分/层间缝/窄层钳制/退化" {
  // gap=0：三层正好均分
  assert_eq(funnel_band(0, 3, 0.0, 300.0, gap=0.0), (0.0, 100.0))
  assert_eq(funnel_band(1, 3, 0.0, 300.0, gap=0.0), (100.0, 100.0))
  assert_eq(funnel_band(2, 3, 0.0, 300.0, gap=0.0), (200.0, 100.0))
  // gap=10：缝从槽内扣、槽内居中，首末不越界
  let (y0, h0) = funnel_band(0, 3, 0.0, 300.0, gap=10.0)
  assert_eq(y0, 5.0)
  assert_eq(h0, 90.0)
  let (y2, h2) = funnel_band(2, 3, 0.0, 300.0, gap=10.0)
  assert_eq(y2, 205.0)
  assert_true(y2 + h2 <= 300.0)
  // 层多缝大：层高不足 1px 钳到 1
  let (_yn, hn) = funnel_band(0, 500, 0.0, 300.0)
  assert_true(hn >= 1.0)
  // 退化：n <= 0 / 区间退化
  assert_eq(funnel_band(0, 0, 10.0, 300.0), (10.0, 0.0))
  assert_eq(funnel_band(0, 3, 300.0, 300.0), (300.0, 0.0))
  assert_eq(funnel_band(0, 3, 300.0, 100.0), (300.0, 0.0))
}

///|
test "funnel_band_widths：顶底宽∝值/末层收平/负值钳零/退化" {
  let vs = [100.0, 50.0, 25.0]
  // 顶宽=本层值占比，底宽=下一层值占比（漏斗逐层收窄）
  assert_eq(funnel_band_widths(vs, 0, 200.0), (200.0, 100.0))
  assert_eq(funnel_band_widths(vs, 1, 200.0), (100.0, 50.0))
  // 末层收平：底宽=顶宽
  assert_eq(funnel_band_widths(vs, 2, 200.0), (50.0, 50.0))
  // 负值钳零
  assert_eq(funnel_band_widths([100.0, -20.0], 1, 200.0), (0.0, 0.0))
  assert_eq(funnel_band_widths([-5.0, 100.0], 0, 200.0), (0.0, 200.0))
  // 无正值 / full 非正 / i 越界
  assert_eq(funnel_band_widths([0.0, -5.0], 0, 200.0), (0.0, 0.0))
  assert_eq(funnel_band_widths(vs, 0, 0.0), (0.0, 0.0))
  assert_eq(funnel_band_widths(vs, 3, 200.0), (0.0, 0.0))
  assert_eq(funnel_band_widths(vs, -1, 200.0), (0.0, 0.0))
  // 空表
  assert_eq(funnel_band_widths([], 0, 200.0), (0.0, 0.0))
}

///|
test "funnel_pct：相对首层/相对总和/基数与负值退化" {
  let vs = [100.0, 50.0, 25.0]
  // 默认相对首层（最大层）
  assert_eq(funnel_pct(50.0, vs), 50.0)
  assert_eq(funnel_pct(100.0, vs), 100.0)
  assert_eq(funnel_pct(25.0, vs), 25.0)
  // of_total=true 相对全部正值总和（25/175）
  let t = funnel_pct(25.0, vs, of_total=true)
  assert_true((t - 100.0 * 25.0 / 175.0).abs() < 1.0e-9)
  let t0 = funnel_pct(100.0, vs, of_total=true)
  assert_true((t0 - 100.0 * 100.0 / 175.0).abs() < 1.0e-9)
  // 基数 <= 0（无正值）
  assert_eq(funnel_pct(5.0, [0.0, -1.0]), 0.0)
  assert_eq(funnel_pct(5.0, [0.0, -1.0], of_total=true), 0.0)
  assert_eq(funnel_pct(5.0, []), 0.0)
  // v <= 0
  assert_eq(funnel_pct(-3.0, vs), 0.0)
  assert_eq(funnel_pct(0.0, vs, of_total=true), 0.0)
}

///|
test "funnel_layer_color：同系列自顶向下渐浅" {
  // 首层与主题主色同色（hex 经 HSL 往返会小写化，按 RGB 分量比较）
  match (@yue.parse_hex(funnel_layer_color(0, 4)), @yue.parse_hex(@yue.theme_primary())) {
    (Some((r1, g1, b1)), Some((r2, g2, b2))) =>
      assert_eq((r1, g1, b1), (r2, g2, b2))
    _ => assert_true(false)
  }
  // 单层即原色
  match (@yue.parse_hex(funnel_layer_color(0, 1)), @yue.parse_hex(@yue.theme_primary())) {
    (Some((r1, g1, b1)), Some((r2, g2, b2))) =>
      assert_eq((r1, g1, b1), (r2, g2, b2))
    _ => assert_true(false)
  }
  // 末层为提亮色（明度高于基色）
  let base = funnel_layer_color(0, 4)
  let last = funnel_layer_color(3, 4)
  match (@yue.parse_hex(base), @yue.parse_hex(last)) {
    (Some((r0, g0, b0)), Some((r1, g1, b1))) => {
      let (_, _, l0) = @yue.rgb_to_hsl(r0, g0, b0)
      let (_, _, l1) = @yue.rgb_to_hsl(r1, g1, b1)
      assert_true(l1 > l0)
    }
    _ => assert_true(false)
  }
}
