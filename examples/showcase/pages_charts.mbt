// 图表页:图表族独立演示板(line_chart_t / bar_chart_t / donut_chart_t /
// gauge_t / scatter_t)。折线与仪表盘由 set_timer 500ms 实时驱动;暂停
// 复选框只断数据流,定时器本身不停(libyue 定时器无取消 id,回调里放行
// 判断即可)。手动仪表盘经滑杆驱动,拖值即触发插值平滑。

///|
fn page_charts(_app : App) -> @yue.Node {
  // ---- 折线:3 序列定长窗口,500ms 推点(三角波模拟监控曲线),可暂停 ----
  let line_series : @yue.Store[Array[@yue.LineSeries]] = @yue.Store::new([
    @yue.LineSeries::make("CPU", max_points=120),
    @yue.LineSeries::make("内存", max_points=120),
    @yue.LineSeries::make("磁盘", max_points=120),
  ])
  let line_running : @yue.Store[Bool] = @yue.Store::new(true)
  let line_tick = @yue.Signal::new(0)
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

  ignore(
    @yue.set_timer(500, fn() {
      if line_running.get() {
        let t = line_tick.get() + 1
        line_tick.set(t)
        @yue.series_push(line_series, 0, triangle(t, 60, 35.0, 40.0))
        @yue.series_push(line_series, 1, triangle(t, 90, 45.0, 20.0))
        @yue.series_push(line_series, 2, triangle(t, 120, 20.0, 30.0))
      }
      true
    }),
  )
  // ---- 柱状:月度净值(含负值)+ Top 语言横向条 ----
  let bar_data : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("1月", 12.0),
    @yue.BarItem::make("2月", -8.0),
    @yue.BarItem::make("3月", 25.0),
    @yue.BarItem::make("4月", 18.0),
    @yue.BarItem::make("5月", -14.0),
    @yue.BarItem::make("6月", 32.0),
    @yue.BarItem::make("7月", 22.0),
    @yue.BarItem::make("8月", 9.0),
  ])
  let bar_h_data : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("MoonBit", 92.0),
    @yue.BarItem::make("Rust", 78.0),
    @yue.BarItem::make("Go", 65.0),
    @yue.BarItem::make("TS", 58.0),
    @yue.BarItem::make("Python", 41.0),
  ])
  // ---- 环形:流量来源占比 ----
  let donut_data : @yue.Store[Array[@yue.DonutSlice]] = @yue.Store::new([
    @yue.DonutSlice::make("直接访问", 335.0),
    @yue.DonutSlice::make("搜索引擎", 510.0),
    @yue.DonutSlice::make("社交媒体", 234.0),
    @yue.DonutSlice::make("外部链接", 148.0),
    @yue.DonutSlice::make("邮件", 96.0),
  ])
  // ---- 仪表盘:自动(2Hz 三角波)+ 手动(滑杆)双演示 ----
  let gauge_auto : @yue.Store[Double] = @yue.Store::new(0.0)
  let gauge_tick = @yue.Signal::new(0)
  ignore(
    @yue.set_timer(500, fn() {
      let t = gauge_tick.get() + 1
      gauge_tick.set(t)
      gauge_auto.set(triangle(t, 100, 0.05, 0.9))
      true
    }),
  )
  let gauge_manual : @yue.Store[Double] = @yue.Store::new(0.35)
  // ---- 散点:2000 点确定性伪随机(LCG) ----
  let scatter_data : Array[(Double, Double)] = []
  let mut scatter_seed = 42
  for _i in 0..<2000 {
    scatter_seed = (scatter_seed * 1103515245 + 12345) % 2147483647
    let x = scatter_seed.to_double() / 2147483647.0 * 100.0
    scatter_seed = (scatter_seed * 1103515245 + 12345) % 2147483647
    let y = x * 0.6 + 20.0 + (scatter_seed.to_double() / 2147483647.0 - 0.5) * 40.0
    scatter_data.push((x, y))
  }
  let scatter_pts : @yue.Store[Array[(Double, Double)]] = @yue.Store::new(scatter_data)
  let gauge_thresholds = [
    (0.6, @yue.theme_current().success),
    (0.85, @yue.theme_current().warning),
    (1.0, @yue.theme_current().danger),
  ]
  scroll_page([
    section(
      "Line 折线图(滚动窗口 + 实时推点)",
      "定长滚动窗口(max_points=120,超出丢最旧),500ms 定时推点;多序列主题色循环,y 轴自适应 + 网格 + 最新值右端标注。左为折线形态,右为面积形态(半透明填充)。推点只重绘画布,不重建视图树。",
      [
        @yue.hbox([
          @yue.line_chart_t(line_series, width=320.0, height=240.0),
          @yue.label("  "),
          @yue.line_chart_t(line_series, width=320.0, height=240.0, area=true),
        ], style_str=[("alignItems", "start")]),
        @yue.hbox([
          @yue.checkbox_t("暂停推点", checked=line_running.get(), on_change=fn(v) {
            line_running.set(v)
          }),
          @yue.label_t("窗口容量 120,推点频率 2Hz;暂停只断数据流,定时器不取消。", role=@yue.Secondary),
        ], style=[("marginTop", 8.0)], style_str=[("alignItems", "center")]),
      ],
    ),
    section(
      "Bar 柱状图 / 条形图",
      "纵向柱(默认)以 0 为基线支持正负值(正主题色、负红色);横向条(horizontal)适配长类目名。悬停高亮 + 行内数值标注,移动只重绘画布。",
      [
        @yue.hbox([
          @yue.bar_chart_t(bar_data, width=320.0, height=240.0),
          @yue.label("  "),
          @yue.bar_chart_t(bar_h_data, width=320.0, height=240.0, horizontal=true),
        ], style_str=[("alignItems", "start")]),
      ],
    ),
    section(
      "Donut 环形图",
      "占比扇区(12 点方向起顺时针,五色循环);中心汇总数值;右侧图例(标签 + 值 + 百分比)。悬停扇区外扩 4px,图例行同步高亮。",
      [
        @yue.donut_chart_t(donut_data, width=440.0, height=240.0),
      ],
    ),
    section(
      "Gauge 仪表盘",
      "单值百分比环 + 中心大数字,阈值分段着色(≤60% 绿 / ≤85% 橙 / 红)。左:2Hz 三角波自动更新,经 16ms 定时器插值平滑(每帧补 25% 差值)无跳变;右:滑杆手动驱动,拖拽过程同样平滑。",
      [
        @yue.hbox([
          @yue.gauge_t(gauge_auto, width=240.0, height=180.0, thresholds=gauge_thresholds),
          @yue.label("  "),
          @yue.gauge_t(gauge_manual, width=240.0, height=180.0, thresholds=gauge_thresholds),
          @yue.label("  "),
          @yue.vbox([
            @yue.label_t("手动值", role=@yue.Body),
            @yue.slider_t(gauge_manual, min=0.0, max=1.0, step=0.01, width=160.0),
          ], style_str=[("justifyContent", "center")]),
        ], style_str=[("alignItems", "start")]),
      ],
    ),
    section(
      "Scatter 散点图",
      "2000 点 x/y 点列(小方点),双轴自适应刻度 + 网格;右侧叠加最小二乘趋势线。",
      [
        @yue.hbox([
          @yue.scatter_t(scatter_pts, width=320.0, height=260.0),
          @yue.label("  "),
          @yue.scatter_t(scatter_pts, width=320.0, height=260.0, trend=true),
        ], style_str=[("alignItems", "start")]),
      ],
    ),
  ])
}
