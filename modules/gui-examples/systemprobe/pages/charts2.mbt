// 新图表页（第二批八种）：关系图/平行坐标/象形柱/旭日/主题河流/
// 树图/矩形树图/特效散点，内置演示数据。G7 新栈迁移记档：
// ① 地图组件（geo_map_t）暂不展示——组件已平移，但演示用的抽象多边形
//    容易与真实地图观感混淆，口径等地图能力线一起定；
// ② 特效散点的 EffAnim 由组件内部自驱动（自挂定时器），ProbeApp 不再
//    持有动画句柄，也没有关窗停表的需求（随进程退出）。

///|
/// 新图表页。
pub fn page_charts2(_app : @shared.ProbeApp) -> @core.Node {
  // 关系图:网关→服务→缓存/数据库 的力导向布局演示
  let graph : @core.Store[@charts.GraphData] = @core.Store::new(
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
  // 平行坐标:四轴五行,「饱和度」轴手动给定 0..100 量程
  let par_axes : @core.Store[Array[@charts.ParAxis]] = @core.Store::new([
    @charts.ParAxis::make("延迟(ms)"),
    @charts.ParAxis::make("吞吐(MB/s)"),
    @charts.ParAxis::make("错误率(%)"),
    @charts.ParAxis::make("饱和度(%)", min=Some(0.0), max=Some(100.0)),
  ])
  let par_rows : @core.Store[Array[Array[Double]]] = @core.Store::new([
    [12.0, 320.0, 0.5, 40.0],
    [18.0, 260.0, 1.2, 55.0],
    [9.0, 410.0, 0.2, 35.0],
    [25.0, 180.0, 2.0, 70.0],
    [15.0, 300.0, 0.8, 48.0],
  ])
  // 象形柱图:圆形符号沿基线重复平铺(单位 12),带数值标签
  let pb_data : @core.Store[Array[@charts.BarItem]] = @core.Store::new([
    @charts.BarItem::make("北京", 92.0),
    @charts.BarItem::make("上海", 78.0),
    @charts.BarItem::make("广州", 64.0),
    @charts.BarItem::make("成都", 45.0),
    @charts.BarItem::make("西安", 36.0),
  ])
  // 旭日图:两级层级,叶子给显式值、父层按子项聚合
  let sun_root : @core.Store[@charts.SunItem] = @core.Store::new(
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
  // 主题河流:三条层七个时间点的堆叠流域
  let trv_names : @core.Store[Array[String]] = @core.Store::new(["移动端", "桌面端", "平板"])
  let trv_values : @core.Store[Array[Array[Double]]] = @core.Store::new([
    [12.0, 18.0, 25.0, 22.0, 30.0, 28.0, 20.0],
    [30.0, 32.0, 28.0, 35.0, 40.0, 38.0, 33.0],
    [8.0, 9.0, 11.0, 10.0, 14.0, 13.0, 9.0],
  ])
  // 树图:横向布局的层级树(叶子按 value 定圆点大小)
  let tree_root : @core.Store[@charts.TreeItem] = @core.Store::new(
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
  let tm_items : @core.Store[Array[@charts.TmItem]] = @core.Store::new([
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
  let eff_points : @core.Store[Array[@charts.EffPoint]] = @core.Store::new([
    @charts.EffPoint::make(18.0, 72.0, size=20.0),
    @charts.EffPoint::make(32.0, 58.0, size=14.0),
    @charts.EffPoint::make(47.0, 83.0, size=24.0),
    @charts.EffPoint::make(55.0, 40.0, size=12.0),
    @charts.EffPoint::make(66.0, 63.0, size=16.0),
    @charts.EffPoint::make(78.0, 35.0, size=18.0),
    @charts.EffPoint::make(88.0, 70.0, size=13.0),
  ])
  @shared.page([
    @shared.section(
      "新图表",
      "新图表(第二批:八种)",
      "关系图 / 平行坐标 / 象形柱 / 旭日 / 主题河流 / 树图 / 矩形树图 / 特效散点，全部为内置演示数据。地图组件（geo_map_t）已平移但此处暂不展示——演示用抽象多边形容易与真实地图观感混淆，口径等地图能力线一起定。",
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
  ])
}
