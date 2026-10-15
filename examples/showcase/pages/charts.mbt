// 图表页：图表族独立演示板（line_chart_t / bar_chart_t / donut_chart_t /
// gauge_t / scatter_t）。折线与仪表盘由 500ms 自重排延时通道实时驱动；
// 暂停复选框只断数据流（定时器本身不停——新栈 set_timeout 是一次性句柄，
// 循环靠回调尾自排，与 master 的重复定时器等价但机制不同，记档）。
//
// **第一拍挂在真·挂载时机（Node::on_mount），不挂 handle、不挂构造期**：
// `set_timeout` 在宿主 `App` 建好之前是空操作（`core/loop.mbt` 的进程级通道
// 由 `App::new` 装），而页面函数是 `mount_window` 的实参、求值早于建窗，且
// `view` 的 `handle` 在 `node_of_new` 里**构造期就执行**、并不是挂载回调——
// 两处排的首拍都进空通道（Windows 真机实证：探针 experiment/timer_probe，
// 挂载回调里排的定时器 pending=0，宿主建好后再排的准点响）。on_mount 包的
// mount 闭包在段正文惰性挂载、首次选中本段时才跑，那时宿主早已就绪。
pub fn page_charts(_app : @shared.App) -> @core.Node {
  // ---- 折线：3 序列定长窗口，500ms 推点（三角波模拟监控曲线），可暂停 ----
  let line_series : @core.Store[Array[@charts.LineSeries]] = @core.Store::new([
    @charts.LineSeries::make("CPU", max_points=120),
    @charts.LineSeries::make("内存", max_points=120),
    @charts.LineSeries::make("磁盘", max_points=120),
  ])
  // 复选框语义与标签同向：勾上 = 暂停（断数据流，定时器照跑）
  let line_paused : @core.Store[Bool] = @core.Store::new(false)
  fn triangle(t : Int, period : Int, base : Double, amp : Double) -> Double {
    let phase = t % period
    let half = period / 2
    base +
    (if phase < half {
      phase.to_double() / half.to_double() * amp
    } else {
      (period - phase).to_double() / half.to_double() * amp
    })
  }

  let line_tick : Ref[Int] = Ref(0)
  fn line_pump() -> Unit {
    if !line_paused.get() {
      let t = line_tick.val + 1
      line_tick.val = t
      @charts.series_push(line_series, 0, triangle(t, 60, 35.0, 40.0))
      @charts.series_push(line_series, 1, triangle(t, 90, 45.0, 20.0))
      @charts.series_push(line_series, 2, triangle(t, 120, 20.0, 30.0))
    }
    let _ = @core.set_timeout(500, line_pump)
  }

  // ---- 柱状：月度净值（含负值）+ Top 语言横向条 ----
  let bar_data : @core.Store[Array[@charts.BarItem]] = @core.Store::new([
    @charts.BarItem::make("1月", 12.0),
    @charts.BarItem::make("2月", -8.0),
    @charts.BarItem::make("3月", 25.0),
    @charts.BarItem::make("4月", 18.0),
    @charts.BarItem::make("5月", -14.0),
    @charts.BarItem::make("6月", 32.0),
    @charts.BarItem::make("7月", 22.0),
    @charts.BarItem::make("8月", 9.0),
  ])
  let bar_h_data : @core.Store[Array[@charts.BarItem]] = @core.Store::new([
    @charts.BarItem::make("MoonBit", 92.0),
    @charts.BarItem::make("Rust", 78.0),
    @charts.BarItem::make("Go", 65.0),
    @charts.BarItem::make("TS", 58.0),
    @charts.BarItem::make("Python", 41.0),
  ])
  // ---- 环形：流量来源占比 ----
  let donut_data : @core.Store[Array[@charts.DonutSlice]] = @core.Store::new([
    @charts.DonutSlice::make("直接访问", 335.0),
    @charts.DonutSlice::make("搜索引擎", 510.0),
    @charts.DonutSlice::make("社交媒体", 234.0),
    @charts.DonutSlice::make("外部链接", 148.0),
    @charts.DonutSlice::make("邮件", 96.0),
  ])
  // ---- 仪表盘：自动（2Hz 三角波）+ 手动（滑杆）双演示 ----
  let gauge_auto : @core.Store[Double] = @core.Store::new(0.0)
  let gauge_tick : Ref[Int] = Ref(0)
  fn gauge_pump() -> Unit {
    let t = gauge_tick.val + 1
    gauge_tick.val = t
    gauge_auto.set(triangle(t, 100, 0.05, 0.9))
    let _ = @core.set_timeout(500, gauge_pump)
  }

  let gauge_manual : @core.Store[Double] = @core.Store::new(0.35)
  // ---- 散点：2000 点确定性伪随机（LCG） ----
  let scatter_data : Array[(Double, Double)] = []
  let mut scatter_seed = 42
  for _i in 0..<2000 {
    // 取低 31 位而不是 `% 2147483647`：乘法溢出成负数后 MoonBit 的 `%` 跟着
    // 被除数取号，x 会落到负半轴（真机读数：坐标轴成了 -100..100）
    scatter_seed = (scatter_seed * 1103515245 + 12345) & 0x7fff_ffff
    let x = scatter_seed.to_double() / 2147483647.0 * 100.0
    scatter_seed = (scatter_seed * 1103515245 + 12345) & 0x7fff_ffff
    let y = x * 0.6 +
      20.0 +
      (scatter_seed.to_double() / 2147483647.0 - 0.5) * 40.0
    scatter_data.push((x, y))
  }
  let scatter_pts : @core.Store[Array[(Double, Double)]] = @core.Store::new(
    scatter_data,
  )
  let gauge_thresholds = [
    (0.6, @theme.theme_current().success),
    (0.85, @theme.theme_current().warning),
    (1.0, @theme.theme_current().danger),
  ]
  @shared.page([
    @shared.section(
      "折线",
      "Line 折线图",
      "定长滚动窗口（max_points=120，超出丢最旧），500ms 定时推点；多序列主题色循环，y 轴自适应 + 网格 + 最新值右端标注。左为折线形态，右为面积形态（半透明填充）。推点只重绘画布，不重建视图树。",
      [
        @ui.row(
          [
            @charts.line_chart_t(line_series, width=320.0, height=240.0),
            @charts.line_chart_t(line_series, area=true, width=320.0, height=240.0),
          ],
          column_gap=16.0,
          align_items=@yoga.AlignItems::FlexStart,
        ).on_mount(fn() -> Unit { line_pump() }),
        @ui.row(
          [
            @ui.checkbox("暂停推点", line_paused),
            @ui.text("窗口容量 120，推点频率 2Hz；暂停只断数据流，自排通道继续。", role=@ui.Secondary),
          ],
          column_gap=12.0,
        ),
      ],
      code=[
        "let series = @core.Store::new([",
        "  @charts.LineSeries::make(\"CPU\", max_points=120),",
        "  @charts.LineSeries::make(\"内存\", max_points=120),",
        "])",
        "fn pump() -> Unit {",
        "  @charts.series_push(series, 0, v)",
        "  let _ = @core.set_timeout(500, pump)  // 自重排循环",
        "}",
        "// 第一拍挂在真·挂载时机：handle 构造期就跑、那时宿主还没建好",
        "@ui.row([chart]).on_mount(fn() { pump() })",
        "@charts.line_chart_t(series, width=320.0, height=240.0)",
        "@charts.line_chart_t(series, area=true, width=320.0, height=240.0)",
      ],
    ),
    @shared.section(
      "柱状",
      "Bar 柱状图 / 条形图",
      "纵向柱（默认）以 0 为基线支持正负值（正主题色、负红色）；横向条（horizontal）适配长类目名。悬停高亮 + 行内数值标注。",
      [
        @ui.row(
          [
            @charts.bar_chart_t(bar_data, width=320.0, height=240.0),
            @charts.bar_chart_t(bar_h_data, horizontal=true, width=320.0, height=240.0),
          ],
          column_gap=16.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "let bars = @core.Store::new([@charts.BarItem::make(\"1月\", 12.0), @charts.BarItem::make(\"2月\", -8.0)])",
        "@charts.bar_chart_t(bars, width=320.0, height=240.0)",
        "@charts.bar_chart_t(top, horizontal=true, width=320.0, height=240.0)",
      ],
    ),
    @shared.section(
      "环形",
      "Donut 环形图",
      "占比扇区（12 点方向起顺时针，五色循环）；中心汇总数值；右侧图例（标签 + 值 + 百分比）。悬停扇区外扩，图例行同步高亮。",
      [
        @charts.donut_chart_t(donut_data, width=440.0, height=240.0),
      ],
      code=[
        "let donut = @core.Store::new([@charts.DonutSlice::make(\"直接访问\", 335.0)])",
        "@charts.donut_chart_t(donut, width=440.0, height=240.0)",
      ],
    ),
    @shared.section(
      "仪表盘",
      "Gauge 仪表盘",
      "单值百分比环 + 中心大数字，阈值分段着色（≤60% 绿 / ≤85% 橙 / 红）。左：2Hz 三角波自动更新，组件内置插值平滑无跳变；右：滑杆手动驱动。",
      [
        @ui.row(
          [
            @charts.gauge_t(gauge_auto, thresholds=gauge_thresholds, width=240.0, height=180.0),
            @charts.gauge_t(gauge_manual, thresholds=gauge_thresholds, width=240.0, height=180.0),
            @ui.col(
              [
                @ui.text("手动值", role=@ui.Body),
                @ui.slider(gauge_manual, min=0.0, max=1.0, step=0.01, width=160.0),
              ],
              row_gap=8.0,
              align_items=@yoga.AlignItems::FlexStart,
            ),
          ],
          column_gap=16.0,
          align_items=@yoga.AlignItems::FlexStart,
        ).on_mount(fn() -> Unit { gauge_pump() }),
      ],
      code=[
        "let gauge = @core.Store::new(0.35)",
        "let thresholds = [",
        "  (0.6, @theme.theme_current().success),",
        "  (0.85, @theme.theme_current().warning),",
        "  (1.0, @theme.theme_current().danger),",
        "]",
        "@charts.gauge_t(gauge, thresholds=thresholds, width=240.0, height=180.0)",
        "@ui.slider(gauge, min=0.0, max=1.0, step=0.01, width=160.0)",
      ],
    ),
    @shared.section(
      "散点",
      "Scatter 散点图",
      "2000 点 x/y 点列（半透明小圆点），双轴自适应刻度 + 网格；右侧叠加最小二乘趋势线。",
      [
        @ui.row(
          [
            @charts.scatter_t(scatter_pts, width=320.0, height=260.0),
            @charts.scatter_t(scatter_pts, trend=true, width=320.0, height=260.0),
          ],
          column_gap=16.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@charts.scatter_t(pts, width=320.0, height=260.0)",
        "@charts.scatter_t(pts, trend=true, width=320.0, height=260.0)",
      ],
    ),
  ])
}
