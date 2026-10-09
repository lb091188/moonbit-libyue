// 涟漪散点图白盒测试：纯函数（点直径钳制/涟漪半径上限/帧步长/相位推进
// 与回卷/圈进度错峰/圈半径/圈 alpha/alpha 量化与 ARGB 拼色/点坐标换算/
// 点数对提取）语义 + 动画句柄开关与「相位 Store 订阅 + stop 开关」的
// 定时器接线镜像（组件内 logic 同款，无 GUI、不起真实定时器）。

///|
test "EffPoint / EffAnim 构造与 eff_stop 开关" {
  let pt = EffPoint::make(3.0, 4.0)
  assert_true((pt.x - 3.0).abs() < 1.0e-12)
  assert_true((pt.y - 4.0).abs() < 1.0e-12)
  assert_true((pt.size - 12.0).abs() < 1.0e-12) // 默认直径 12
  let big = EffPoint::make(0.0, 0.0, size=20.0)
  assert_true((big.size - 20.0).abs() < 1.0e-12)
  let anim = EffAnim::make()
  assert_true(anim.is_running())
  eff_stop(anim)
  assert_false(anim.is_running())
}

///|
test "eff_point_radius：直径钳制（2..48）后取半" {
  assert_true((eff_point_radius(12.0) - 6.0).abs() < 1.0e-12) // 默认
  assert_true((eff_point_radius(0.0) - 1.0).abs() < 1.0e-12) // 下限 2 → r=1
  assert_true((eff_point_radius(-5.0) - 1.0).abs() < 1.0e-12)
  assert_true((eff_point_radius(200.0) - 24.0).abs() < 1.0e-12) // 上限 48 → r=24
}

///|
test "eff_ripple_rmax：最大圈半径 = 点半径 + 固定外扩" {
  assert_true((eff_ripple_rmax(6.0) - 26.0).abs() < 1.0e-12)
  assert_true((eff_ripple_rmax(0.0) - 20.0).abs() < 1.0e-12) // 外扩量与点大小无关
}

///|
test "eff_tick_ms：周期折帧步长与最小步长兜底" {
  assert_eq(eff_tick_ms(3000), 50) // 3000/60
  assert_eq(eff_tick_ms(600), 16) // 600/60=10 → 兜底 16
  assert_eq(eff_tick_ms(0), 16) // 周期非法 → 兜底（调用方据此不启动动画）
  assert_eq(eff_tick_ms(-100), 16)
}

///|
test "eff_phase_advance：推进/回卷/负值与 NaN 兜底" {
  assert_true((eff_phase_advance(0.0, 0.25) - 0.25).abs() < 1.0e-12)
  assert_true((eff_phase_advance(0.9, 0.25) - 0.15).abs() < 1.0e-12) // 回卷
  assert_true((eff_phase_advance(2.5, 0.0) - 0.5).abs() < 1.0e-12) // 超域入参也归一
  assert_eq(eff_phase_advance(0.1, -0.5), 0.0) // 负相位兜底 0
  assert_eq(eff_phase_advance(0.0, 0.0 / 0.0), 0.0) // NaN 兜底 0
  // 任何输入组合恒在 [0, 1)
  for t in [0.0, 0.13, 0.5, 0.99, 1.0, -0.3] {
    for d in [0.0, 0.03, 0.5, 2.7] {
      let p = eff_phase_advance(t, d)
      assert_true(p >= 0.0 && p < 1.0)
    }
  }
}

///|
test "eff_ring_progress：各圈错峰 / k 回卷 / 退化单圈" {
  // 3 圈相位 0：第 0 圈刚出生，1/2 圈分别推进 1/3、2/3
  assert_true((eff_ring_progress(0.0, 0, 3) - 0.0).abs() < 1.0e-12)
  assert_true((eff_ring_progress(0.0, 1, 3) - 1.0 / 3.0).abs() < 1.0e-12)
  assert_true((eff_ring_progress(0.0, 2, 3) - 2.0 / 3.0).abs() < 1.0e-12)
  // k 越界按圈数回卷（含负值）
  assert_true((eff_ring_progress(0.0, 3, 3) - 0.0).abs() < 1.0e-12)
  assert_true((eff_ring_progress(0.0, 5, 3) - 2.0 / 3.0).abs() < 1.0e-12)
  assert_true((eff_ring_progress(0.0, -1, 3) - 2.0 / 3.0).abs() < 1.0e-12)
  // 错峰推进相位自身也回卷
  assert_true((eff_ring_progress(0.5, 1, 2) - 0.0).abs() < 1.0e-12)
  assert_true((eff_ring_progress(0.7, 2, 4) - 0.2).abs() < 1.0e-12)
  // rings < 1 退化为单圈（进度即相位）
  assert_true((eff_ring_progress(0.42, 0, 0) - 0.42).abs() < 1.0e-12)
  assert_true((eff_ring_progress(0.42, 7, -3) - 0.42).abs() < 1.0e-12)
}

///|
test "eff_ring_radius：半径 ∝ 进度 + 出生不可见 + 非法给 None" {
  assert_true(
    (eff_ring_radius(0.5, 30.0).unwrap_or(-1.0) - 15.0).abs() < 1.0e-12,
  )
  assert_true(
    (eff_ring_radius(1.0, 30.0).unwrap_or(-1.0) - 30.0).abs() < 1.0e-12,
  )
  assert_true(eff_ring_radius(0.0, 30.0) is None) // 刚出生半径为 0
  assert_true(eff_ring_radius(0.01, 30.0) is None) // 0.3px 小于下限不画
  assert_true(eff_ring_radius(0.5, 0.0) is None) // 最大半径非法
  assert_true(eff_ring_radius(1.5, 30.0) is None) // 进度越界
  assert_true(eff_ring_radius(0.0 / 0.0, 30.0) is None) // NaN
}

///|
test "eff_ring_alpha：随进度二次衰减 + 越界为 0" {
  assert_true((eff_ring_alpha(0.0) - 1.0).abs() < 1.0e-12) // 出生最亮
  assert_true((eff_ring_alpha(0.5) - 0.25).abs() < 1.0e-12) // (1/2)²
  assert_true((eff_ring_alpha(0.9) - 0.01).abs() < 1.0e-12)
  assert_eq(eff_ring_alpha(1.0), 0.0) // 到界全透明
  assert_eq(eff_ring_alpha(-0.1), 0.0)
  assert_eq(eff_ring_alpha(0.0 / 0.0), 0.0) // NaN
  // 单调：进度越大 alpha 越小
  let mut last = 2.0
  let mut i = 0
  while i <= 100 {
    let a = eff_ring_alpha(i.to_double() / 100.0)
    assert_true(a <= last)
    last = a
    i = i + 1
  }
}

///|
test "eff_ring 组合：单圈寿命内半径递增、alpha 递减，整周期错峰" {
  let r_max = 26.0
  for k in 0..<3 {
    let mut prev_p = -1.0
    let mut prev_r = -1.0
    let mut prev_a = 2.0
    let mut i = 1
    while i < 100 {
      let phase = i.to_double() / 100.0
      let p = eff_ring_progress(phase, k, 3)
      if p < prev_p {
        // 进度回卷 = 该圈走完一轮扩散后重新出生
        prev_r = -1.0
        prev_a = 2.0
      }
      let r = eff_ring_radius(p, r_max).unwrap_or(0.0)
      let a = eff_ring_alpha(p)
      assert_true(r >= prev_r) // 同一轮扩散内半径只增
      assert_true(a <= prev_a) // alpha 只衰
      prev_p = p
      prev_r = r
      prev_a = a
      i = i + 1
    }
  }
  // 同一相位下 3 圈半径两两不同（错峰扩散，不是同圈重影）
  let r0 = eff_ring_radius(eff_ring_progress(0.5, 0, 3), r_max)
  let r1 = eff_ring_radius(eff_ring_progress(0.5, 1, 3), r_max)
  let r2 = eff_ring_radius(eff_ring_progress(0.5, 2, 3), r_max)
  assert_true(r0 != r1)
  assert_true(r1 != r2)
}

///|
test "eff_alpha_u8 / eff_alpha_color：量化与 #AARRGGBB 拼装" {
  assert_eq(eff_alpha_u8(1.0), 255)
  assert_eq(eff_alpha_u8(0.5), 128) // 127.5 四舍五入
  assert_eq(eff_alpha_u8(0.0), 0)
  assert_eq(eff_alpha_u8(2.0), 255) // 越界钳制
  assert_eq(eff_alpha_u8(-1.0), 0)
  assert_eq(eff_alpha_u8(0.0 / 0.0), 0) // NaN
  // 8 位 hex 往返：alpha 在前（libyue 约定），RGB 不被改写
  assert_eq(eff_alpha_color("#ff009688", 1.0), "#ff009688")
  // 半透明：alpha 在前，RGB 保持
  assert_eq(eff_alpha_color("#009688", 0.5), "#80009688")
  assert_eq(eff_alpha_color("#009688", 0.0), "#00009688")
  // 非法色原样返回（绘制层不至于把 H撑坏）
  assert_eq(eff_alpha_color("not-a-color", 0.5), "not-a-color")
}

///|
test "eff_xy：点数对提取（顺序保持）" {
  let pts = [EffPoint::make(1.0, 2.0), EffPoint::make(3.0, 4.0, size=6.0)]
  let xy = eff_xy(pts)
  assert_eq(xy.length(), 2)
  assert_eq(xy[0], (1.0, 2.0))
  assert_eq(xy[1], (3.0, 4.0))
  assert_eq(eff_xy([]).length(), 0)
}

///|
test "eff_map_point：数据点 → 绘制区像素（等比映射/边缘/值域退化）" {
  let pt = EffPoint::make(5.0, 5.0)
  // 值域 0..10 → 绘制区 0..100 × 0..200：中点
  let (px, py) = eff_map_point(
    pt,
    (0.0, 10.0),
    (0.0, 10.0),
    0.0,
    100.0,
    0.0,
    200.0,
  )
  assert_true((px - 50.0).abs() < 1.0e-9)
  assert_true((py - 100.0).abs() < 1.0e-9)
  // 端点：最小值贴左上角刻度侧、最大值贴右下
  let lo = EffPoint::make(0.0, 0.0)
  let hi = EffPoint::make(10.0, 10.0)
  let (lx, ly) = eff_map_point(
    lo,
    (0.0, 10.0),
    (0.0, 10.0),
    20.0,
    120.0,
    10.0,
    210.0,
  )
  assert_true((lx - 20.0).abs() < 1.0e-9)
  assert_true((ly - 210.0).abs() < 1.0e-9) // y 轴反向（canvas 语义）
  let (hx, hy) = eff_map_point(
    hi,
    (0.0, 10.0),
    (0.0, 10.0),
    20.0,
    120.0,
    10.0,
    210.0,
  )
  assert_true((hx - 120.0).abs() < 1.0e-9)
  assert_true((hy - 10.0).abs() < 1.0e-9)
  // 值域退化：两轴都取绘制区中点
  let (dx, dy) = eff_map_point(
    EffPoint::make(7.0, -3.0),
    (7.0, 7.0),
    (-3.0, -3.0),
    0.0,
    100.0,
    0.0,
    50.0,
  )
  assert_true((dx - 50.0).abs() < 1.0e-9)
  assert_true((dy - 25.0).abs() < 1.0e-9)
}

///|
test "相位 Store 订阅 + stop 开关：组件定时器接线镜像（无 GUI）" {
  // 镜像 eff_chart_t 的接线：相位 Store + 订阅重绘 + 句柄开关回调体
  let phase : @yue.Store[Double] = @yue.Store::new(0.0)
  let paints = Ref(0)
  phase.subscribe(fn(_p) { paints.val = paints.val + 1 })
  let anim = EffAnim::make()
  let tick = eff_tick_ms(3000)
  let step = tick.to_double() / 3000.0
  fn timer_body(phase : @yue.Store[Double], anim : EffAnim, step : Double) -> Bool {
    if !anim.is_running() {
      false
    } else {
      phase.update(fn(t) { eff_phase_advance(t, step) })
      true
    }
  }

  // 一整轮周期（60 帧）：相位恒在 [0,1)、每帧触发一次重绘、回到起点
  let mut frames = 0
  let mut alive = true
  while frames < 60 {
    alive = timer_body(phase, anim, step)
    assert_true(alive) // 运行中定时器不注销
    let t = phase.get()
    assert_true(t >= 0.0 && t < 1.0)
    frames = frames + 1
  }
  assert_eq(frames, 60)
  assert_true(phase.get() < 0.05) // 走完一轮回卷到起点附近
  assert_eq(paints.val, 60) // 每帧一次 schedule_paint

  // stop 后回调体返回 false（libyue 即注销定时器），且不再推进相位/
  // 产出重绘
  eff_stop(anim)
  let frozen = phase.get()
  let frozen_paints = paints.val
  assert_false(timer_body(phase, anim, step))
  assert_eq(phase.get(), frozen)
  assert_eq(paints.val, frozen_paints)
}
