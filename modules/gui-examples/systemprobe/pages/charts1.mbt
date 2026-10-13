// 扩展图表页（第一批六种）：雷达/热力/K 线/漏斗/箱线/桑基，内置演示
// 数据。G7 新栈迁移记档：组件全名与数据类型逐一同源（radar_chart_t/
// heatmap_t/candlestick_t/funnel_t/boxplot_t/sankey_t），旧链 `fill=true`
// 的 CSS 撑宽参数在新栈不存在（组件默认按容器宽 100% 铺），k 线涨跌色
// 走主题语义色（up_color/down_color 缺省）。

///|
/// 扩展图表页。
pub fn page_charts1(_app : @shared.ProbeApp) -> @core.Node {
  // 雷达图:六维对比,双系列
  let radar_ind : @core.Store[Array[@charts.RadarIndicator]] = @core.Store::new([
    @charts.RadarIndicator::make("渲染", 100.0),
    @charts.RadarIndicator::make("IO", 100.0),
    @charts.RadarIndicator::make("内存", 100.0),
    @charts.RadarIndicator::make("启动", 100.0),
    @charts.RadarIndicator::make("体积", 100.0),
    @charts.RadarIndicator::make("功耗", 100.0),
  ])
  let radar_ser : @core.Store[Array[@charts.RadarSeries]] = @core.Store::new([
    @charts.RadarSeries::make("本方案", [88.0, 72.0, 80.0, 92.0, 85.0, 78.0]),
    @charts.RadarSeries::make("对照", [70.0, 90.0, 65.0, 75.0, 60.0, 82.0]),
  ])
  // 热力图:一周三时段活跃度矩阵
  let heat : @core.Store[@charts.HeatGrid] = @core.Store::new(
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
  // K 线:七根演示蜡烛(含涨跌与影线形态)
  let candles : @core.Store[Array[@charts.Candle]] = @core.Store::new([
    @charts.Candle::make(100.0, 108.0, 98.0, 105.0),
    @charts.Candle::make(105.0, 107.0, 99.0, 101.0),
    @charts.Candle::make(101.0, 110.0, 100.0, 108.0),
    @charts.Candle::make(108.0, 112.0, 104.0, 106.0),
    @charts.Candle::make(106.0, 109.0, 101.0, 103.0),
    @charts.Candle::make(103.0, 105.0, 97.0, 99.0),
    @charts.Candle::make(99.0, 104.0, 96.0, 102.0),
  ])
  // 漏斗:转化漏斗五层
  let funnel : @core.Store[Array[@charts.BarItem]] = @core.Store::new([
    @charts.BarItem::make("浏览", 1000.0),
    @charts.BarItem::make("加购", 420.0),
    @charts.BarItem::make("下单", 260.0),
    @charts.BarItem::make("支付", 190.0),
    @charts.BarItem::make("复购", 80.0),
  ])
  // 箱线:三组耗时分布(含离群点)
  let boxp : @core.Store[Array[(String, Array[Double])]] = @core.Store::new([
    ("渲染", [12.0, 14.0, 15.0, 16.0, 18.0, 21.0, 25.0, 30.0]),
    ("IO", [5.0, 6.0, 6.5, 7.0, 8.0, 9.0, 12.0]),
    ("启动", [70.0, 75.0, 78.0, 80.0, 82.0, 90.0, 110.0]),
  ])
  // 桑基:浏览 -> 加购/直接下单 -> 支付/流失 的流向
  let sankey : @core.Store[@charts.SankeyData] = @core.Store::new(
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
  @shared.page([
    @shared.section(
      "扩展图表",
      "扩展图表(第一批:六种)",
      "雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基，全部为内置演示数据。",
      [
        @charts.radar_chart_t(radar_ind, radar_ser),
        @charts.heatmap_t(heat, show_values=true),
        @charts.candlestick_t(candles),
        @charts.funnel_t(funnel),
        @charts.boxplot_t(boxp),
        @charts.sankey_t(sankey),
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
  ])
}
