// 交互图表页:line / bar / donut 交互版(hover 浮层 / 图例点击显隐 /
// 滚轮缩放与拖拽平移)。

///|
pub fn page_charts_it(_app : @ui.ProbeApp) -> @yue.Node {
  let it_line : @yue.Store[Array[@yue.LineSeries]] = @yue.Store::new([
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
  let it_bar : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("一月", 120.0),
    @yue.BarItem::make("二月", 96.0),
    @yue.BarItem::make("三月", 145.0),
    @yue.BarItem::make("四月", -35.0),
    @yue.BarItem::make("五月", 168.0),
    @yue.BarItem::make("六月", 132.0),
  ])
  let it_donut : @yue.Store[Array[@yue.DonutSlice]] = @yue.Store::new([
    @yue.DonutSlice::make("研发", 42.0),
    @yue.DonutSlice::make("市场", 26.0),
    @yue.DonutSlice::make("运营", 18.0),
    @yue.DonutSlice::make("职能", 14.0),
  ])
  @ui.page_shell(
    "交互图表",
    "line / bar 为交互版(默认 zoom=true,滚轮以鼠标为锚点缩放、左键拖拽平移);donut 无 x 轴,不提供 DataZoom;三图均含 tooltip 与可点击图例。",
    fn(_refresh) {
      [
        @yue.line_chart_it(it_line, fill=true),
        @yue.bar_chart_it(it_bar, fill=true),
        @yue.donut_chart_it(it_donut, center="合计 100", fill=true),
      ]
    },
  )
}
