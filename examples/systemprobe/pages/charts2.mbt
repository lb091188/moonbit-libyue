// 新图表页(第二批九种):地图/关系图/平行坐标/象形柱/旭日/主题河流/
// 树图/矩形树图/特效散点,内置演示数据。特效散点的涟漪动画句柄在
// ProbeApp(关窗由 main 停止定时器)。

///|
pub fn page_charts2(app : @ui.ProbeApp) -> @yue.Node {
  // 地图:手绘简化多边形示意(非真实疆界,环为 (lon, lat) 闭合点列),
  // 另配三条城市间飞线
  let geo_regions : @yue.Store[Array[@yue.GeoRegion]] = @yue.Store::new([
    @yue.GeoRegion::make(Some("北部"), [
      [(112.0, 41.0), (118.0, 42.0), (120.0, 40.0), (117.0, 38.0), (113.0, 39.0), (112.0, 41.0)],
    ]),
    @yue.GeoRegion::make(Some("东部"), [
      [(118.0, 32.0), (122.0, 31.0), (121.0, 28.0), (119.0, 27.0), (117.0, 30.0), (118.0, 32.0)],
    ]),
    @yue.GeoRegion::make(Some("南部"), [
      [(110.0, 25.0), (114.0, 25.5), (117.0, 24.0), (114.0, 21.5), (109.5, 22.5), (110.0, 25.0)],
    ]),
    @yue.GeoRegion::make(Some("西部"), [
      [(100.0, 33.0), (106.0, 35.0), (108.0, 31.0), (103.0, 28.5), (99.5, 29.5), (100.0, 33.0)],
    ]),
    @yue.GeoRegion::make(Some("岛屿"), [
      [(119.5, 26.5), (120.5, 26.5), (120.5, 25.0), (119.5, 25.0), (119.5, 26.5)],
    ]),
  ])
  let geo_flights : Array[@yue.GeoFlight] = [
    @yue.GeoFlight::make((116.4, 39.9), (121.47, 31.23)),
    @yue.GeoFlight::make((121.47, 31.23), (113.26, 23.13)),
    @yue.GeoFlight::make((113.26, 23.13), (104.07, 30.67)),
  ]
  // 关系图:网关→服务→缓存/数据库 的力导向布局演示
  let graph : @yue.Store[@yue.GraphData] = @yue.Store::new(
    @yue.GraphData::make(
      [
        @yue.GraphNode::make("网关"),
        @yue.GraphNode::make("服务 A"),
        @yue.GraphNode::make("服务 B"),
        @yue.GraphNode::make("服务 C"),
        @yue.GraphNode::make("缓存"),
        @yue.GraphNode::make("数据库", value=2.0),
      ],
      [
        @yue.GraphEdge::make(0, 1),
        @yue.GraphEdge::make(0, 2),
        @yue.GraphEdge::make(1, 3),
        @yue.GraphEdge::make(2, 3, weight=2.0),
        @yue.GraphEdge::make(1, 4),
        @yue.GraphEdge::make(2, 4),
        @yue.GraphEdge::make(4, 5),
        @yue.GraphEdge::make(3, 5, weight=2.0),
      ],
    ),
  )
  // 平行坐标:四轴五行,「饱和度」轴手动给定 0..100 量程
  let par_axes : @yue.Store[Array[@yue.ParAxis]] = @yue.Store::new([
    @yue.ParAxis::make("延迟(ms)"),
    @yue.ParAxis::make("吞吐(MB/s)"),
    @yue.ParAxis::make("错误率(%)"),
    @yue.ParAxis::make("饱和度(%)", min=Some(0.0), max=Some(100.0)),
  ])
  let par_rows : @yue.Store[Array[Array[Double]]] = @yue.Store::new([
    [12.0, 320.0, 0.5, 40.0],
    [18.0, 260.0, 1.2, 55.0],
    [9.0, 410.0, 0.2, 35.0],
    [25.0, 180.0, 2.0, 70.0],
    [15.0, 300.0, 0.8, 48.0],
  ])
  // 象形柱图:圆形符号沿基线重复平铺(单位 12),带数值标签
  let pb_data : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("北京", 92.0),
    @yue.BarItem::make("上海", 78.0),
    @yue.BarItem::make("广州", 64.0),
    @yue.BarItem::make("成都", 45.0),
    @yue.BarItem::make("西安", 36.0),
  ])
  // 旭日图:两级层级,叶子给显式值、父层按子项聚合
  let sun_root : @yue.Store[@yue.SunItem] = @yue.Store::new(
    @yue.SunItem::make(
      "访问来源",
      children=[
        @yue.SunItem::make(
          "搜索",
          children=[
            @yue.SunItem::make("百度", value=Some(42.0)),
            @yue.SunItem::make("必应", value=Some(18.0)),
          ],
        ),
        @yue.SunItem::make("直接访问", value=Some(35.0)),
        @yue.SunItem::make(
          "外链",
          children=[
            @yue.SunItem::make("社区", value=Some(22.0)),
            @yue.SunItem::make("博客", value=Some(12.0)),
          ],
        ),
      ],
    ),
  )
  // 主题河流:三条层七个时间点的堆叠流域
  let trv_names : @yue.Store[Array[String]] = @yue.Store::new(["移动端", "桌面端", "平板"])
  let trv_values : @yue.Store[Array[Array[Double]]] = @yue.Store::new([
    [12.0, 18.0, 25.0, 22.0, 30.0, 28.0, 20.0],
    [30.0, 32.0, 28.0, 35.0, 40.0, 38.0, 33.0],
    [8.0, 9.0, 11.0, 10.0, 14.0, 13.0, 9.0],
  ])
  // 树图:横向布局的层级树(叶子按 value 定圆点大小)
  let tree_root : @yue.Store[@yue.TreeItem] = @yue.Store::new(
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
  // 矩形树图:两级分区(父节点按子项合计)
  let tm_items : @yue.Store[Array[@yue.TmItem]] = @yue.Store::new([
    @yue.TmItem::make(
      "研发",
      children=[
        @yue.TmItem::make("前端", value=30.0),
        @yue.TmItem::make("后端", value=45.0),
        @yue.TmItem::make("测试", value=15.0),
      ],
    ),
    @yue.TmItem::make(
      "设计",
      children=[
        @yue.TmItem::make("视觉", value=18.0),
        @yue.TmItem::make("交互", value=12.0),
      ],
    ),
    @yue.TmItem::make("运营", value=25.0),
  ])
  let eff_points : @yue.Store[Array[@yue.EffPoint]] = @yue.Store::new([
    @yue.EffPoint::make(18.0, 72.0, size=20.0),
    @yue.EffPoint::make(32.0, 58.0, size=14.0),
    @yue.EffPoint::make(47.0, 83.0, size=24.0),
    @yue.EffPoint::make(55.0, 40.0, size=12.0),
    @yue.EffPoint::make(66.0, 63.0, size=16.0),
    @yue.EffPoint::make(78.0, 35.0, size=18.0),
    @yue.EffPoint::make(88.0, 70.0, size=13.0),
  ])
  @ui.page_shell(
    "新图表(第二批:九种)",
    "地图为手绘简化多边形示意(非真实疆界);全部为内置演示数据。",
    fn(_refresh) {
      [
        @yue.geo_map_t(geo_regions, flights=geo_flights, fill=true),
        @yue.gph_chart_t(graph, fill=true),
        @yue.par_chart_t(par_axes, par_rows, fill=true),
        @yue.pb_chart_t(
          pb_data,
          symbol=@yue.PbCircle,
          mode=@yue.PbRepeat,
          unit=12.0,
          show_values=true,
          fill=true,
        ),
        @yue.sun_chart_t(sun_root, center_text=Some("总计 129"), fill=true),
        @yue.trv_chart_t(trv_names, trv_values, fill=true),
        @yue.tree_chart_t(tree_root, fill=true),
        @yue.tm_chart_t(tm_items, fill=true),
        @yue.eff_chart_t(
          eff_points,
          x_range=Some((0.0, 100.0)),
          y_range=Some((0.0, 100.0)),
          anim=app.eff_anim,
          fill=true,
        ),
      ]
    },
  )
}
