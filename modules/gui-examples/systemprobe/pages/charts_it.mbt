// 交互图表页：line / bar / donut 交互版（hover 浮层 / 图例点击显隐 /
// 滚轮缩放与拖拽平移）。G7 新栈迁移记档：组件名 line_chart_it/
// bar_chart_it/donut_chart_it 与数据类型逐一同源；DataZoom 状态可自持
// （CiZoom），演示页用组件内置状态即可。

///|
/// 交互图表页。
pub fn page_charts_it(_app : @shared.ProbeApp) -> @core.Node {
  let it_line : @core.Store[Array[@charts.LineSeries]] = @core.Store::new([
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
  let it_bar : @core.Store[Array[@charts.BarItem]] = @core.Store::new([
    @charts.BarItem::make("一月", 120.0),
    @charts.BarItem::make("二月", 96.0),
    @charts.BarItem::make("三月", 145.0),
    @charts.BarItem::make("四月", -35.0),
    @charts.BarItem::make("五月", 168.0),
    @charts.BarItem::make("六月", 132.0),
  ])
  let it_donut : @core.Store[Array[@charts.DonutSlice]] = @core.Store::new([
    @charts.DonutSlice::make("研发", 42.0),
    @charts.DonutSlice::make("市场", 26.0),
    @charts.DonutSlice::make("运营", 18.0),
    @charts.DonutSlice::make("职能", 14.0),
  ])
  @shared.page([
    @shared.section(
      "交互图表",
      "交互图表",
      "line / bar 为交互版（默认 zoom=true，滚轮以鼠标为锚点缩放、左键拖拽平移）；donut 无 x 轴，不提供 DataZoom；三图均含 tooltip 与可点击图例。",
      [
        @charts.line_chart_it(it_line),
        @charts.bar_chart_it(it_bar),
        @charts.donut_chart_it(it_donut, center="合计 100"),
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
