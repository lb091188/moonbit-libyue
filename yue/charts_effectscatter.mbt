// 涟漪散点图（charts.mbt 图表族成员，EP 对标 ECharts EffectScatter，纯
// MoonBit 自绘，Painter 承载）：
//   EffPoint      数据点（x/y + 尺寸直径）
//   eff_chart_t   散点 + 涟漪动画组件：每点周期性扩散 N 圈同心圆
//                 （半径随相位增大、描边 alpha 衰减），@yue.set_timer
//                 驱动相位 Store 推进，订阅 schedule_paint 重绘（与其余
//                 图表 Store 订阅模式一致）
//   EffAnim       动画句柄：eff_stop 停止定时器（组件无销毁回调可挂，
//                 见 eff_stop 文档）
// 渲染模型与其余图表一致：单一自绘容器，on_draw 内现取 theme_* 色；
// 数据经 Store 驱动，set 后只 schedule_paint 画布，不重建视图树。网格/
// 刻度/坐标换算复用 charts.mbt 纯函数；相位推进、圈进度/半径/alpha 映射
// 与点直径钳制集中在本文 pure 函数层，charts_effectscatter_wbtest.mbt
// 白盒覆盖。

///|
/// 点直径钳制下限（EffPoint.size 语义为逻辑像素直径）。
let eff_dot_min : Double = 2.0

///|
/// 点直径钳制上限。
let eff_dot_max : Double = 48.0

///|
/// 涟漪圈最大外扩：在点半径之外再扩的像素数。
let eff_ripple_extent : Double = 20.0

///|
/// 单圈半径下限（px）：小于此值不画（出生瞬间不可见）。
let eff_ring_min_r : Double = 0.5

///|
/// 每周期定时器帧数（3000ms 周期 ≈ 50ms 一帧）。
let eff_frames_per_period : Int = 60

///|
/// 定时器帧步长下限（ms）。
let eff_tick_min_ms : Int = 16

///|
/// 涟漪圈数上限（防病态参数把单帧绘制量打爆）。
let eff_rings_max : Int = 8

// ---------------------------------------------------------------------------
// 纯函数层：点直径钳制 / 相位推进 / 圈进度 / 圈半径 / 圈 alpha / 坐标换算
// （白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 涟漪散点数据点：x/y 为数据坐标，size 为点的直径（逻辑像素，钳
/// [2, 48]，默认 12）。
pub(all) struct EffPoint {
  x : Double
  y : Double
  size : Double
}

///|
/// 建涟漪散点数据点（size 为直径，逻辑像素；越界由绘制层钳制）。
pub fn EffPoint::make(
  x : Double,
  y : Double,
  size? : Double = 12.0,
) -> EffPoint {
  { x, y, size, }
}

///|
/// 动画句柄：持有涟漪定时器的运行开关。libyue 的周期定时器无取消 id
/// （见 yue/app.mbt set_timer），停止的唯一途径是让回调返回 false；故
/// 句柄持一个开关，eff_stop 置 false 后下一帧回调即注销定时器。
/// 同一句柄传给多个 eff_chart_t 时联动控制这些实例。
pub(all) struct EffAnim {
  running : Ref[Bool]
}

///|
/// 建动画句柄（默认运行中）。挂载 eff_chart_t 前已 stop 的句柄不会
/// 启动定时器。
pub fn EffAnim::make() -> EffAnim {
  { running: Ref(true), }
}

///|
/// 句柄当前是否为运行中（定时器存活）。
pub fn EffAnim::is_running(self : EffAnim) -> Bool {
  self.running.val
}

///|
/// 停止句柄关联的涟漪定时器（下一帧回调返回 false 即注销）。注意：
/// eff_chart_t 挂载的视图没有销毁回调可挂（yue/view.mbt 无视图销毁
/// 钩子），组件被卸载后定时器仍会存活，故组件销毁前应由调用方显式
/// eff_stop。停止不可恢复——被停止的定时器已从消息循环注销；需要恢复
/// 请用新句柄重新挂载。
pub fn eff_stop(anim : EffAnim) -> Unit {
  anim.running.val = false
}

///|
/// 点直径 → 半径（size 钳到 [2, 48] 后取半）。
pub fn eff_point_radius(size : Double) -> Double {
  let d = if size < eff_dot_min {
    eff_dot_min
  } else if size > eff_dot_max {
    eff_dot_max
  } else {
    size
  }
  d / 2.0
}

///|
/// 涟漪最大圈半径（px）：点半径 + 固定外扩量。
pub fn eff_ripple_rmax(dot_r : Double) -> Double {
  dot_r + eff_ripple_extent
}

///|
/// 定时器帧步长（ms）：周期 ÷ 每周期帧数，兜底到最小步长；period_ms
/// <= 0 时给最小步长（调用方据此判定不启动动画）。
pub fn eff_tick_ms(period_ms : Int) -> Int {
  if period_ms < 1 {
    return eff_tick_min_ms
  }
  (period_ms / eff_frames_per_period).max(eff_tick_min_ms)
}

///|
/// 相位推进：phase + delta 后回卷到 [0, 1)；负值/NaN 兜底为 0（动画
/// 相位是归一化时间，0..1 走完一轮涟漪）。
pub fn eff_phase_advance(phase : Double, delta : Double) -> Double {
  let t = phase + delta
  if !(t >= 0.0) {
    0.0
  } else {
    let f = t - t.floor()
    if f >= 1.0 {
      0.0
    } else {
      f
    }
  }
}

///|
/// 第 k 圈的归一进度（0..1）：同轮各圈以 k/rings 错峰出生，进度 =
/// frac(phase + k/rings)；rings < 1 退化为单圈；k 越界（含负值）按
/// 圈数回卷。
pub fn eff_ring_progress(phase : Double, k : Int, rings : Int) -> Double {
  let m = if rings < 1 { 1 } else { rings }
  let kk = (k % m + m) % m
  eff_phase_advance(phase, kk.to_double() / m.to_double())
}

///|
/// 圈半径（px）：进度 × 最大半径；进度或半径非法、半径小于
/// [eff_ring_min_r] 时 None（该圈本帧不可见）。p == 1 视为到界半径
/// （alpha 已衰减为 0，绘制层不会真画出）。
pub fn eff_ring_radius(p : Double, r_max : Double) -> Double? {
  if !(p >= 0.0) || !(p <= 1.0) || !(r_max > 0.0) {
    return None
  }
  let r = p * r_max
  if r < eff_ring_min_r {
    None
  } else {
    Some(r)
  }
}

///|
/// 圈描边 alpha（0..1）：随进度二次衰减（1-p)²，出生最亮、到界全
/// 透明；进度越界（含 NaN）给 0。
pub fn eff_ring_alpha(p : Double) -> Double {
  if !(p >= 0.0) || !(p < 1.0) {
    return 0.0
  }
  let q = 1.0 - p
  q * q
}

///|
/// alpha（0..1）→ 0..255 字节（四舍五入，越界钳制）。
pub fn eff_alpha_u8(a : Double) -> Int {
  let x = if !(a >= 0.0) { 0.0 } else if a > 1.0 { 1.0 } else { a }
  (x * 255.0).round().to_int()
}

///|
/// 主题色按 alpha 量化成 "#AARRGGBB"（libyue 的 alpha 在前约定，见
/// color.mbt with_alpha）；base 非法时原样返回。
fn eff_alpha_color(base : String, a : Double) -> String {
  match parse_hex(base) {
    Some((r, g, b)) => argb_hex(eff_alpha_u8(a), r, g, b)
    None => base
  }
}

///|
/// 数据点表 → (x, y) 数对表（复用 charts.mbt 的 point_range 算量程）。
pub fn eff_xy(points : Array[EffPoint]) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for pt in points {
    out.push((pt.x, pt.y))
  }
  out
}

///|
/// 数据点 → 绘制区像素：x/y 各自按值域映射到 [x0, x1] × [y0, y1]
/// （值域退化时取中点，换算与 grid/点列同源，对齐 charts.mbt 的
/// map_xv / map_y）。
pub fn eff_map_point(
  pt : EffPoint,
  x_range : (Double, Double),
  y_range : (Double, Double),
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
) -> (Double, Double) {
  let (xlo, xhi) = x_range
  let (ylo, yhi) = y_range
  (map_xv(pt.x, xlo, xhi, x0, x1), map_y(pt.y, ylo, yhi, y0, y1))
}

// ---------------------------------------------------------------------------
// 绘制私有层
// ---------------------------------------------------------------------------

///|
/// 涟漪散点绘制（画布坐标，数据与相位已由调用方取出）：横向/竖直网格 +
/// 双轴刻度（值域显式指定或经 point_range 自适应）；每点点本体（实心
/// 圆，半径 ∝ size）+ rings 圈同心涟漪（描边 alpha 随进度衰减，圈与
/// 圈以 k/rings 错峰）；绘制区裁剪，中心连最大圈都够不着的点跳过。
fn eff_draw(
  p : Painter,
  w : Double,
  h : Double,
  points : Array[EffPoint],
  phase : Double,
  rings : Int,
  x_range : (Double, Double)?,
  y_range : (Double, Double)?,
) -> Unit {
  if w <= 0.0 || h <= 0.0 {
    return
  }
  let ((xl0, xh0), (yl0, yh0)) = point_range(eff_xy(points))
  let (xlo, xhi) = match x_range {
    Some((a, b)) => if a <= b { (a, b) } else { (b, a) }
    None => (xl0, xh0)
  }
  let (ylo, yhi) = match y_range {
    Some((a, b)) => if a <= b { (a, b) } else { (b, a) }
    None => (yl0, yh0)
  }
  let pad_l = 46.0
  let pad_r = 14.0
  let pad_t = 12.0
  let pad_b = 24.0
  let x0 = pad_l
  let x1 = w - pad_r
  let y0 = pad_t
  let y1 = h - pad_b
  if x1 <= x0 || y1 <= y0 {
    return
  }
  draw_hgrid(
    p,
    x0,
    y0,
    x1,
    y1,
    ylo,
    yhi,
    nice_ticks(ylo, yhi, count=4),
    label_w=pad_l - 12.0,
  )
  draw_vgrid(p, x0, y0, x1, y1, xlo, xhi, nice_ticks(xlo, xhi, count=5))
  if points.length() == 0 {
    let at = AttributedText::new(
      "暂无数据",
      align=Center,
      valign=Center,
      wrap=false,
    )
    at.set_font(Font::new("Sans", 13.0))
    at.set_color(theme_text_secondary())
    let tw = at.get_bounds_for(400.0, 40.0).width
    p.draw_attributed_text(
      at,
      (x0 + x1) / 2.0 - tw / 2.0,
      (y0 + y1) / 2.0 - 10.0,
      tw + 4.0,
      20.0,
    )
    return
  }
  let nr = if rings < 0 {
    0
  } else if rings > eff_rings_max {
    eff_rings_max
  } else {
    rings
  }
  p.save()
  p.clip_rect(x0, y0, x1 - x0, y1 - y0)
  for pt in points {
    let (px, py) = eff_map_point(pt, (xlo, xhi), (ylo, yhi), x0, x1, y0, y1)
    let dot_r = eff_point_radius(pt.size)
    let r_max = eff_ripple_rmax(dot_r)
    // 中心连最大圈都探不出绘制区才跳过（否则圈被裁剪局部切掉也画）
    if px < x0 - r_max || px > x1 + r_max || py < y0 - r_max || py > y1 + r_max {
      continue
    }
    // 涟漪圈：描边 alpha 随进度二次衰减，各圈错峰出生
    let ripple_color = theme_primary()
    for k in 0..<nr {
      let prog = eff_ring_progress(phase, k, nr)
      match eff_ring_radius(prog, r_max) {
        None => ()
        Some(r) => {
          let a = eff_ring_alpha(prog)
          if a <= 0.003 {
            continue
          }
          p.set_stroke_color(eff_alpha_color(ripple_color, a))
          p.begin_path()
          p.arc(px, py, r, 0.0, tau)
          p.stroke()
        }
      }
    }
    // 点本体（实心圆，半径 ∝ size）
    p.set_fill_color(theme_primary())
    p.begin_path()
    p.arc(px, py, dot_r, 0.0, tau)
    p.fill()
  }
  p.restore()
}

// ---------------------------------------------------------------------------
// 组件层（Node）
// ---------------------------------------------------------------------------

///|
/// 涟漪散点图（EP 对标 ECharts EffectScatter）：散点（点直径 ∝ size，
/// 钳 [2, 48]px）+ 每点周期性扩散 rings 圈同心圆（半径随相位增大、
/// 描边 alpha 二次衰减，各圈错峰出生），双轴自适应刻度或经 x_range /
/// y_range 手动指定；数据经 Store 驱动，set 后只 schedule_paint 画布，
/// 不重建视图树；主题切换现取色自动跟随。fill=true 不设固定宽度，横向
/// 铺满父容器（跟随窗口伸缩）。
/// 动画：定时器帧步长 = period_ms ÷ 60（兜底 16ms），每帧推进相位
/// Store（归一化 0..1 走完一轮），相位订阅触发重绘。period_ms <= 0 或
/// rings <= 0 时退化为静态散点。
/// 停止：组件销毁无 dispose 回调可挂（yue/view.mbt 无视图销毁钩子），
/// 调用方须在卸载前对动画句柄调 [eff_stop] 停止定时器，否则定时器随
/// 应用存活、持续 schedule_paint 已卸载视图；句柄经 anim 参数传入，
/// 未传则每次挂载自建（无法从外部停止）。
pub fn eff_chart_t(
  points : Store[Array[EffPoint]],
  period_ms? : Int = 3000,
  rings? : Int = 3,
  x_range? : (Double, Double)? = None,
  y_range? : (Double, Double)? = None,
  anim? : EffAnim = EffAnim::make(),
  fill? : Bool = false,
  style? : Array[(String, &StyVal)] = [],
  handle? : (Container) -> Unit = fn(_c) {  },
) -> Node {
  {
    mount: fn(parent) {
      // 相位 Store：定时器推进 + 订阅重绘（与其余图表 Store 订阅模式一致）
      let phase = Store::new(0.0)
      let size_style : Array[(String, &StyVal)] = if fill {
        [("height", 320.0)]
      } else {
        [("width", 560.0), ("height", 320.0)]
      }
      for kv in style {
        size_style.push(kv)
      }
      let cv = themed_container(style=size_style)
      handle(cv)
      set_panel_bg(cv)
      cv.on_draw(fn(p) {
        let b = ViewLike::get_bounds(cv)
        p.set_stroke_color(theme_border())
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
        eff_draw(
          p,
          b.width,
          b.height,
          points.get(),
          phase.get(),
          rings,
          x_range,
          y_range,
        )
      })
      points.subscribe(fn(_pts) { ViewLike::schedule_paint(cv) })
      phase.subscribe(fn(_ph) { ViewLike::schedule_paint(cv) })
      // 定时器接线：句柄被 stop 时回调返回 false，libyue 注销该定时器
      let tick = eff_tick_ms(period_ms)
      let step = if period_ms < 1 {
        0.0
      } else {
        tick.to_double() / period_ms.to_double()
      }
      if anim.running.val && rings > 0 && step > 0.0 {
        set_timer(tick, fn() {
          if !anim.running.val {
            false
          } else {
            phase.update(fn(t) { eff_phase_advance(t, step) })
            true
          }
        })
      }
      attach(parent, ViewLike::view(cv))
      ViewLike::view(cv)
    },
  }
}
