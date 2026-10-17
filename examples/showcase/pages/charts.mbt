// 图表页：图表族全量演示板——基础五段（line_chart_t / bar_chart_t /
// donut_chart_t / gauge_t / scatter_t）+ 扩展三段（雷达/热力/K 线/漏斗/箱线/
// 桑基；关系/平行坐标/象形柱/旭日/主题河流/树图/矩形树图/特效散点；
// line/bar/donut 交互版，2026-10-16 由独立示例 examples/charts 并回）。
// 折线与仪表盘由 500ms 自重排延时通道实时驱动；暂停复选框只断数据流
// （定时器本身不停——新栈 set_timeout 是一次性句柄，循环靠回调尾自排，
// 与 master 的重复定时器等价但机制不同，记档）。
//
// **第一拍挂在真·挂载时机（Node::on_mount），不挂 handle、不挂构造期**：
// `set_timeout` 在宿主 `App` 建好之前是空操作（`core/loop.mbt` 的进程级通道
// 由 `App::new` 装），而页面函数是 `mount_window` 的实参、求值早于建窗，且
// `view` 的 `handle` 在 `node_of_new` 里**构造期就执行**、并不是挂载回调——
// 两处排的首拍都进空通道（Windows 真机实证：探针 experiment/timer_probe，
// 挂载回调里排的定时器 pending=0，宿主建好后再排的准点响）。on_mount 包的
// mount 闭包在段正文惰性挂载、首次选中本段时才跑，那时宿主早已就绪。
pub fn page_charts(_app : @shared.App) -> @widget.Node {
  // ---- 折线：3 序列定长窗口，500ms 推点（三角波模拟监控曲线），可暂停 ----
  let line_series : @base.Store[Array[@charts.LineSeries]] = @base.Store::new([
    @charts.LineSeries::make("CPU", max_points=120),
    @charts.LineSeries::make("内存", max_points=120),
    @charts.LineSeries::make("磁盘", max_points=120),
  ])
  // 复选框语义与标签同向：勾上 = 暂停（断数据流，定时器照跑）
  let line_paused : @base.Store[Bool] = @base.Store::new(false)
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
    let _ = @shell.set_timeout(500, line_pump)
  }

  // ---- 柱状：月度净值（含负值）+ Top 语言横向条 ----
  let bar_data : @base.Store[Array[@charts.BarItem]] = @base.Store::new([
    @charts.BarItem::make("1月", 12.0),
    @charts.BarItem::make("2月", -8.0),
    @charts.BarItem::make("3月", 25.0),
    @charts.BarItem::make("4月", 18.0),
    @charts.BarItem::make("5月", -14.0),
    @charts.BarItem::make("6月", 32.0),
    @charts.BarItem::make("7月", 22.0),
    @charts.BarItem::make("8月", 9.0),
  ])
  let bar_h_data : @base.Store[Array[@charts.BarItem]] = @base.Store::new([
    @charts.BarItem::make("MoonBit", 92.0),
    @charts.BarItem::make("Rust", 78.0),
    @charts.BarItem::make("Go", 65.0),
    @charts.BarItem::make("TS", 58.0),
    @charts.BarItem::make("Python", 41.0),
  ])
  // ---- 环形：流量来源占比 ----
  let donut_data : @base.Store[Array[@charts.DonutSlice]] = @base.Store::new([
    @charts.DonutSlice::make("直接访问", 335.0),
    @charts.DonutSlice::make("搜索引擎", 510.0),
    @charts.DonutSlice::make("社交媒体", 234.0),
    @charts.DonutSlice::make("外部链接", 148.0),
    @charts.DonutSlice::make("邮件", 96.0),
  ])
  // ---- 仪表盘：自动（2Hz 三角波）+ 手动（滑杆）双演示 ----
  let gauge_auto : @base.Store[Double] = @base.Store::new(0.0)
  let gauge_tick : Ref[Int] = Ref(0)
  fn gauge_pump() -> Unit {
    let t = gauge_tick.val + 1
    gauge_tick.val = t
    gauge_auto.set(triangle(t, 100, 0.05, 0.9))
    let _ = @shell.set_timeout(500, gauge_pump)
  }

  let gauge_manual : @base.Store[Double] = @base.Store::new(0.35)
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
  let scatter_pts : @base.Store[Array[(Double, Double)]] = @base.Store::new(
    scatter_data,
  )
  let gauge_thresholds = [
    (0.6, @theme.theme_current().success),
    (0.85, @theme.theme_current().warning),
    (1.0, @theme.theme_current().danger),
  ]
  // ---- 扩展段：雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基（内置演示数据） ----
  let radar_ind : @base.Store[Array[@charts.RadarIndicator]] = @base.Store::new([
    @charts.RadarIndicator::make("渲染", 100.0),
    @charts.RadarIndicator::make("IO", 100.0),
    @charts.RadarIndicator::make("内存", 100.0),
    @charts.RadarIndicator::make("启动", 100.0),
    @charts.RadarIndicator::make("体积", 100.0),
    @charts.RadarIndicator::make("功耗", 100.0),
  ])
  let radar_ser : @base.Store[Array[@charts.RadarSeries]] = @base.Store::new([
    @charts.RadarSeries::make("本方案", [88.0, 72.0, 80.0, 92.0, 85.0, 78.0]),
    @charts.RadarSeries::make("对照", [70.0, 90.0, 65.0, 75.0, 60.0, 82.0]),
  ])
  let heat : @base.Store[@charts.HeatGrid] = @base.Store::new(
    @charts.HeatGrid::make(
      ["周一", "周二", "周三", "周四", "周五", "周六", "周日"],
      ["上午", "下午", "晚间"],
      [
        [3.0, 5.0, 7.0, 4.0, 6.0, 9.0, 8.0],
        [6.0, 8.0, 9.0, 7.0, 5.0, 10.0, 9.0],
        [2.0, 3.0, 8.0, 9.0, 7.0, 6.0, 4.0],
      ],
    ),
  )
  let candles : @base.Store[Array[@charts.Candle]] = @base.Store::new([
    @charts.Candle::make(100.0, 108.0, 98.0, 105.0),
    @charts.Candle::make(105.0, 107.0, 99.0, 101.0),
    @charts.Candle::make(101.0, 110.0, 100.0, 108.0),
    @charts.Candle::make(108.0, 112.0, 104.0, 106.0),
    @charts.Candle::make(106.0, 109.0, 101.0, 103.0),
    @charts.Candle::make(103.0, 105.0, 97.0, 99.0),
    @charts.Candle::make(99.0, 104.0, 96.0, 102.0),
  ])
  let funnel : @base.Store[Array[@charts.BarItem]] = @base.Store::new([
    @charts.BarItem::make("浏览", 1000.0),
    @charts.BarItem::make("加购", 420.0),
    @charts.BarItem::make("下单", 260.0),
    @charts.BarItem::make("支付", 190.0),
    @charts.BarItem::make("复购", 80.0),
  ])
  let boxp : @base.Store[Array[(String, Array[Double])]] = @base.Store::new([
    ("渲染", [12.0, 14.0, 15.0, 16.0, 18.0, 21.0, 25.0, 30.0]),
    ("IO", [5.0, 6.0, 6.5, 7.0, 8.0, 9.0, 12.0]),
    ("启动", [70.0, 75.0, 78.0, 80.0, 82.0, 90.0, 110.0]),
  ])
  let sankey : @base.Store[@charts.SankeyData] = @base.Store::new(
    @charts.SankeyData::make(
      [
        @charts.SankeyNode::make("浏览"),
        @charts.SankeyNode::make("加购"),
        @charts.SankeyNode::make("直接下单"),
        @charts.SankeyNode::make("支付"),
        @charts.SankeyNode::make("流失"),
      ],
      [
        @charts.SankeyLink::make(0, 1, 420.0),
        @charts.SankeyLink::make(0, 2, 200.0),
        @charts.SankeyLink::make(1, 3, 190.0),
        @charts.SankeyLink::make(2, 3, 160.0),
        @charts.SankeyLink::make(0, 4, 380.0),
        @charts.SankeyLink::make(1, 4, 230.0),
      ],
    ),
  )
  // ---- 新图表段：关系 / 平行坐标 / 象形柱 / 旭日 / 主题河流 / 树图 / 矩形树图 / 特效散点 ----
  let graph : @base.Store[@charts.GraphData] = @base.Store::new(
    @charts.GraphData::make(
      [
        @charts.GraphNode::make("网关"),
        @charts.GraphNode::make("服务 A"),
        @charts.GraphNode::make("服务 B"),
        @charts.GraphNode::make("服务 C"),
        @charts.GraphNode::make("缓存"),
        @charts.GraphNode::make("数据库", value=2.0),
      ],
      [
        @charts.GraphEdge::make(0, 1),
        @charts.GraphEdge::make(0, 2),
        @charts.GraphEdge::make(1, 3),
        @charts.GraphEdge::make(2, 3, weight=2.0),
        @charts.GraphEdge::make(1, 4),
        @charts.GraphEdge::make(2, 4),
        @charts.GraphEdge::make(4, 5),
        @charts.GraphEdge::make(3, 5, weight=2.0),
      ],
    ),
  )
  let par_axes : @base.Store[Array[@charts.ParAxis]] = @base.Store::new([
    @charts.ParAxis::make("延迟(ms)"),
    @charts.ParAxis::make("吞吐(MB/s)"),
    @charts.ParAxis::make("错误率(%)"),
    @charts.ParAxis::make("饱和度(%)", min=Some(0.0), max=Some(100.0)),
  ])
  let par_rows : @base.Store[Array[Array[Double]]] = @base.Store::new([
    [12.0, 320.0, 0.5, 40.0],
    [18.0, 260.0, 1.2, 55.0],
    [9.0, 410.0, 0.2, 35.0],
    [25.0, 180.0, 2.0, 70.0],
    [15.0, 300.0, 0.8, 48.0],
  ])
  let pb_data : @base.Store[Array[@charts.BarItem]] = @base.Store::new([
    @charts.BarItem::make("北京", 92.0),
    @charts.BarItem::make("上海", 78.0),
    @charts.BarItem::make("广州", 64.0),
    @charts.BarItem::make("成都", 45.0),
    @charts.BarItem::make("西安", 36.0),
  ])
  let sun_root : @base.Store[@charts.SunItem] = @base.Store::new(
    @charts.SunItem::make(
      "访问来源",
      children=[
        @charts.SunItem::make(
          "搜索",
          children=[
            @charts.SunItem::make("百度", value=Some(42.0)),
            @charts.SunItem::make("必应", value=Some(18.0)),
          ],
        ),
        @charts.SunItem::make("直接访问", value=Some(35.0)),
        @charts.SunItem::make(
          "外链",
          children=[
            @charts.SunItem::make("社区", value=Some(22.0)),
            @charts.SunItem::make("博客", value=Some(12.0)),
          ],
        ),
      ],
    ),
  )
  let trv_names : @base.Store[Array[String]] = @base.Store::new(["移动端", "桌面端", "平板"])
  let trv_values : @base.Store[Array[Array[Double]]] = @base.Store::new([
    [12.0, 18.0, 25.0, 22.0, 30.0, 28.0, 20.0],
    [30.0, 32.0, 28.0, 35.0, 40.0, 38.0, 33.0],
    [8.0, 9.0, 11.0, 10.0, 14.0, 13.0, 9.0],
  ])
  let tree_root : @base.Store[@charts.TreeItem] = @base.Store::new(
    {
      name: "产品线",
      value: None,
      children: [
        {
          name: "移动端",
          value: Some(60.0),
          children: [
            { name: "iOS", value: Some(35.0), children: [] },
            { name: "Android", value: Some(25.0), children: [] },
          ],
        },
        {
          name: "桌面端",
          value: Some(40.0),
          children: [
            { name: "Windows", value: Some(22.0), children: [] },
            { name: "Linux", value: Some(18.0), children: [] },
          ],
        },
      ],
    },
  )
  let tm_items : @base.Store[Array[@charts.TmItem]] = @base.Store::new([
    @charts.TmItem::make(
      "研发",
      children=[
        @charts.TmItem::make("前端", value=30.0),
        @charts.TmItem::make("后端", value=45.0),
        @charts.TmItem::make("测试", value=15.0),
      ],
    ),
    @charts.TmItem::make(
      "设计",
      children=[
        @charts.TmItem::make("视觉", value=18.0),
        @charts.TmItem::make("交互", value=12.0),
      ],
    ),
    @charts.TmItem::make("运营", value=25.0),
  ])
  let eff_points : @base.Store[Array[@charts.EffPoint]] = @base.Store::new([
    @charts.EffPoint::make(18.0, 72.0, size=20.0),
    @charts.EffPoint::make(32.0, 58.0, size=14.0),
    @charts.EffPoint::make(47.0, 83.0, size=24.0),
    @charts.EffPoint::make(55.0, 40.0, size=12.0),
    @charts.EffPoint::make(66.0, 63.0, size=16.0),
    @charts.EffPoint::make(78.0, 35.0, size=18.0),
    @charts.EffPoint::make(88.0, 70.0, size=13.0),
  ])
  // ---- 交互段：line / bar 缩放平移 + donut 交互版 ----
  let it_line : @base.Store[Array[@charts.LineSeries]] = @base.Store::new([
    {
      name: "CPU",
      max_points: 16,
      points: [22.0, 28.0, 25.0, 31.0, 36.0, 33.0, 40.0, 38.0, 45.0, 42.0, 50.0, 47.0, 55.0, 60.0, 58.0, 64.0],
    },
    {
      name: "内存",
      max_points: 16,
      points: [40.0, 42.0, 41.0, 44.0, 46.0, 45.0, 48.0, 50.0, 49.0, 52.0, 55.0, 54.0, 57.0, 60.0, 59.0, 62.0],
    },
  ])
  let it_bar : @base.Store[Array[@charts.BarItem]] = @base.Store::new([
    @charts.BarItem::make("一月", 120.0),
    @charts.BarItem::make("二月", 96.0),
    @charts.BarItem::make("三月", 145.0),
    @charts.BarItem::make("四月", -35.0),
    @charts.BarItem::make("五月", 168.0),
    @charts.BarItem::make("六月", 132.0),
  ])
  let it_donut : @base.Store[Array[@charts.DonutSlice]] = @base.Store::new([
    @charts.DonutSlice::make("研发", 42.0),
    @charts.DonutSlice::make("市场", 26.0),
    @charts.DonutSlice::make("运营", 18.0),
    @charts.DonutSlice::make("职能", 14.0),
  ])
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
        "let series = @base.Store::new([",
        "  @charts.LineSeries::make(\"CPU\", max_points=120),",
        "  @charts.LineSeries::make(\"内存\", max_points=120),",
        "])",
        "fn pump() -> Unit {",
        "  @charts.series_push(series, 0, v)",
        "  let _ = @shell.set_timeout(500, pump)  // 自重排循环",
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
        "let bars = @base.Store::new([@charts.BarItem::make(\"1月\", 12.0), @charts.BarItem::make(\"2月\", -8.0)])",
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
        "let donut = @base.Store::new([@charts.DonutSlice::make(\"直接访问\", 335.0)])",
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
        "let gauge = @base.Store::new(0.35)",
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
    @shared.section(
      "扩展",
      "扩展图表（六种）",
      "雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基，全部为内置演示数据。",
      [
        @ui.col(
          [
            @charts.radar_chart_t(radar_ind, radar_ser),
            @charts.heatmap_t(heat, show_values=true),
            @charts.candlestick_t(candles),
            @charts.funnel_t(funnel),
            @charts.boxplot_t(boxp),
            @charts.sankey_t(sankey),
          ],
          row_gap=14.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@charts.radar_chart_t(indicators, series)",
        "@charts.heatmap_t(grid, show_values=true)",
        "@charts.candlestick_t(candles)",
        "@charts.funnel_t(items)",
        "@charts.boxplot_t(groups)",
        "@charts.sankey_t(data)",
      ],
    ),
    @shared.section(
      "新图表",
      "新图表（八种）",
      "关系图 / 平行坐标 / 象形柱 / 旭日 / 主题河流 / 树图 / 矩形树图 / 特效散点（动画自驱动），全部为内置演示数据。地图组件（geo_map_t）已平移但此处暂不展示——演示用抽象多边形容易与真实地图观感混淆，口径等地图能力线一起定。",
      [
        @ui.col(
          [
            @charts.gph_chart_t(graph),
            @charts.par_chart_t(par_axes, par_rows),
            @charts.pb_chart_t(
              pb_data,
              symbol=@charts.PbCircle,
              mode=@charts.PbRepeat,
              unit=12.0,
              show_values=true,
            ),
            @charts.sun_chart_t(sun_root, center_text=Some("总计 129")),
            @charts.trv_chart_t(trv_names, trv_values),
            @charts.tree_chart_t(tree_root),
            @charts.tm_chart_t(tm_items),
            @charts.eff_chart_t(
              eff_points,
              x_range=Some((0.0, 100.0)),
              y_range=Some((0.0, 100.0)),
            ),
          ],
          row_gap=14.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@charts.gph_chart_t(graph)          // 力导向关系图",
        "@charts.par_chart_t(axes, rows)     // 平行坐标",
        "@charts.pb_chart_t(data, symbol=@charts.PbCircle, ...)",
        "@charts.sun_chart_t(root, center_text=Some(\"总计\"))",
        "@charts.trv_chart_t(names, values)  // 主题河流",
        "@charts.tree_chart_t(root)          // 树图",
        "@charts.tm_chart_t(items)           // 矩形树图",
        "@charts.eff_chart_t(points, ...)    // 特效散点(动画自驱动)",
      ],
    ),
    @shared.section(
      "交互",
      "交互图表",
      "line / bar 为交互版（默认 zoom=true，滚轮以鼠标为锚点缩放、左键拖拽平移）；donut 无 x 轴不提供 DataZoom；三图均含 tooltip 与可点击图例。",
      [
        @ui.col(
          [
            @charts.line_chart_it(it_line),
            @charts.bar_chart_it(it_bar),
            @charts.donut_chart_it(it_donut, center="合计 100"),
          ],
          row_gap=14.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@charts.line_chart_it(series)   // 滚轮缩放 + 拖拽平移",
        "@charts.bar_chart_it(items)",
        "@charts.donut_chart_it(slices, center=\"合计 100\")",
        "// DataZoom 状态外置时给 zoom_state=Some(zoom) 自持",
      ],
    ),
  ])
}
