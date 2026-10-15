// 扩展图表演示板：三段——扩展图表（雷达/热力/K 线/漏斗/箱线/桑基）、新图表
// （关系图/平行坐标/象形柱/旭日/主题河流/树图/矩形树图/特效散点）、交互图表
// （line/bar 缩放平移 + donut）。数据全部内置演示值；装配是「侧栏菜单 + 三页
// 显隐切换」，与 showcase 的导航同机理（首次选中才挂载，滚动/选中态不丢）。
//
// 由 modules/gui-examples/systemprobe 的三张图表页平移而来（媒体与系统能力
// 各自独立成例后，图表留在主示例模块——不依赖 gui-media）。

///|
/// 导航页：订阅导航状态做 `set_visible` 切换；内容**惰性挂载**——未选中过的页
/// 只留空壳，首次选中才把内容挂进占位（重页全量挂载的启动开销不可行）。
fn nav_page(
  name : String,
  selected : @core.Store[String],
  content : @core.Node,
) -> @core.Node {
  let mounted : Ref[Bool] = Ref(false)
  @ui.col([], grow=1.0, handle=fn(c) {
    fn ensure(s : String) -> Unit {
      if !mounted.val && s == name {
        mounted.val = true
        let _ = content.mount_into(c)
      }
      c.set_visible(s == name)
    }

    ensure(selected.get())
    selected.subscribe(ensure)
  })
}

///|
/// 页骨架：标题 + 说明 + 图表内容（自带滚动）。
fn chart_page(
  title : String,
  desc : String,
  body : Array[@core.Node],
) -> @core.Node {
  @ui.col(
    [
      @ui.scroll_view(
        [
          @ui.col(
            [
              @ui.text(title, role=@ui.Section),
              @ui.text(desc, role=@ui.Secondary, max_width=880.0),
              @ui.col(body, row_gap=18.0, padding=4.0),
            ],
            row_gap=8.0,
            padding=14.0,
          ),
        ],
        @ui.ScrollState::new(),
        handle=fn(v) { v.node.set_flex_grow(1.0) },
      ),
    ],
    grow=1.0,
  )
}

///|
/// 扩展图表页（第一批六种）：雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基。
fn page_charts_ext() -> @core.Node {
  // 雷达图:六维对比,双系列
  let radar_ind : @core.Store[Array[@chart.RadarIndicator]] = @core.Store::new([
    @chart.RadarIndicator::make("渲染", 100.0),
    @chart.RadarIndicator::make("IO", 100.0),
    @chart.RadarIndicator::make("内存", 100.0),
    @chart.RadarIndicator::make("启动", 100.0),
    @chart.RadarIndicator::make("体积", 100.0),
    @chart.RadarIndicator::make("功耗", 100.0),
  ])
  let radar_ser : @core.Store[Array[@chart.RadarSeries]] = @core.Store::new([
    @chart.RadarSeries::make("本方案", [88.0, 72.0, 80.0, 92.0, 85.0, 78.0]),
    @chart.RadarSeries::make("对照", [70.0, 90.0, 65.0, 75.0, 60.0, 82.0]),
  ])
  // 热力图:一周三时段活跃度矩阵
  let heat : @core.Store[@chart.HeatGrid] = @core.Store::new(
    @chart.HeatGrid::make(
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
  let candles : @core.Store[Array[@chart.Candle]] = @core.Store::new([
    @chart.Candle::make(100.0, 108.0, 98.0, 105.0),
    @chart.Candle::make(105.0, 107.0, 99.0, 101.0),
    @chart.Candle::make(101.0, 110.0, 100.0, 108.0),
    @chart.Candle::make(108.0, 112.0, 104.0, 106.0),
    @chart.Candle::make(106.0, 109.0, 101.0, 103.0),
    @chart.Candle::make(103.0, 105.0, 97.0, 99.0),
    @chart.Candle::make(99.0, 104.0, 96.0, 102.0),
  ])
  // 漏斗:转化漏斗五层
  let funnel : @core.Store[Array[@chart.BarItem]] = @core.Store::new([
    @chart.BarItem::make("浏览", 1000.0),
    @chart.BarItem::make("加购", 420.0),
    @chart.BarItem::make("下单", 260.0),
    @chart.BarItem::make("支付", 190.0),
    @chart.BarItem::make("复购", 80.0),
  ])
  // 箱线:三组耗时分布(含离群点)
  let boxp : @core.Store[Array[(String, Array[Double])]] = @core.Store::new([
    ("渲染", [12.0, 14.0, 15.0, 16.0, 18.0, 21.0, 25.0, 30.0]),
    ("IO", [5.0, 6.0, 6.5, 7.0, 8.0, 9.0, 12.0]),
    ("启动", [70.0, 75.0, 78.0, 80.0, 82.0, 90.0, 110.0]),
  ])
  // 桑基:浏览 -> 加购/直接下单 -> 支付/流失 的流向
  let sankey : @core.Store[@chart.SankeyData] = @core.Store::new(
    @chart.SankeyData::make(
      [
        @chart.SankeyNode::make("浏览"),
        @chart.SankeyNode::make("加购"),
        @chart.SankeyNode::make("直接下单"),
        @chart.SankeyNode::make("支付"),
        @chart.SankeyNode::make("流失"),
      ],
      [
        @chart.SankeyLink::make(0, 1, 420.0),
        @chart.SankeyLink::make(0, 2, 200.0),
        @chart.SankeyLink::make(1, 3, 190.0),
        @chart.SankeyLink::make(2, 3, 160.0),
        @chart.SankeyLink::make(0, 4, 380.0),
        @chart.SankeyLink::make(1, 4, 230.0),
      ],
    ),
  )
  chart_page(
    "扩展图表（六种）",
    "雷达 / 热力 / K 线 / 漏斗 / 箱线 / 桑基，全部为内置演示数据。",
    [
      @chart.radar_chart_t(radar_ind, radar_ser),
      @chart.heatmap_t(heat, show_values=true),
      @chart.candlestick_t(candles),
      @chart.funnel_t(funnel),
      @chart.boxplot_t(boxp),
      @chart.sankey_t(sankey),
    ],
  )
}

///|
/// 新图表页（第二批八种）：关系图 / 平行坐标 / 象形柱 / 旭日 / 主题河流 /
/// 树图 / 矩形树图 / 特效散点。
fn page_charts_new() -> @core.Node {
  // 关系图:网关→服务→缓存/数据库 的力导向布局演示
  let graph : @core.Store[@chart.GraphData] = @core.Store::new(
    @chart.GraphData::make(
      [
        @chart.GraphNode::make("网关"),
        @chart.GraphNode::make("服务 A"),
        @chart.GraphNode::make("服务 B"),
        @chart.GraphNode::make("服务 C"),
        @chart.GraphNode::make("缓存"),
        @chart.GraphNode::make("数据库", value=2.0),
      ],
      [
        @chart.GraphEdge::make(0, 1),
        @chart.GraphEdge::make(0, 2),
        @chart.GraphEdge::make(1, 3),
        @chart.GraphEdge::make(2, 3, weight=2.0),
        @chart.GraphEdge::make(1, 4),
        @chart.GraphEdge::make(2, 4),
        @chart.GraphEdge::make(4, 5),
        @chart.GraphEdge::make(3, 5, weight=2.0),
      ],
    ),
  )
  // 平行坐标:四轴五行,「饱和度」轴手动给定 0..100 量程
  let par_axes : @core.Store[Array[@chart.ParAxis]] = @core.Store::new([
    @chart.ParAxis::make("延迟(ms)"),
    @chart.ParAxis::make("吞吐(MB/s)"),
    @chart.ParAxis::make("错误率(%)"),
    @chart.ParAxis::make("饱和度(%)", min=Some(0.0), max=Some(100.0)),
  ])
  let par_rows : @core.Store[Array[Array[Double]]] = @core.Store::new([
    [12.0, 320.0, 0.5, 40.0],
    [18.0, 260.0, 1.2, 55.0],
    [9.0, 410.0, 0.2, 35.0],
    [25.0, 180.0, 2.0, 70.0],
    [15.0, 300.0, 0.8, 48.0],
  ])
  // 象形柱图:圆形符号沿基线重复平铺(单位 12),带数值标签
  let pb_data : @core.Store[Array[@chart.BarItem]] = @core.Store::new([
    @chart.BarItem::make("北京", 92.0),
    @chart.BarItem::make("上海", 78.0),
    @chart.BarItem::make("广州", 64.0),
    @chart.BarItem::make("成都", 45.0),
    @chart.BarItem::make("西安", 36.0),
  ])
  // 旭日图:两级层级,叶子给显式值、父层按子项聚合
  let sun_root : @core.Store[@chart.SunItem] = @core.Store::new(
    @chart.SunItem::make(
      "访问来源",
      children=[
        @chart.SunItem::make(
          "搜索",
          children=[
            @chart.SunItem::make("百度", value=Some(42.0)),
            @chart.SunItem::make("必应", value=Some(18.0)),
          ],
        ),
        @chart.SunItem::make("直接访问", value=Some(35.0)),
        @chart.SunItem::make(
          "外链",
          children=[
            @chart.SunItem::make("社区", value=Some(22.0)),
            @chart.SunItem::make("博客", value=Some(12.0)),
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
  // 树图:横向布局的层级树
  let tree_root : @core.Store[@chart.TreeItem] = @core.Store::new(
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
  let tm_items : @core.Store[Array[@chart.TmItem]] = @core.Store::new([
    @chart.TmItem::make(
      "研发",
      children=[
        @chart.TmItem::make("前端", value=30.0),
        @chart.TmItem::make("后端", value=45.0),
        @chart.TmItem::make("测试", value=15.0),
      ],
    ),
    @chart.TmItem::make(
      "设计",
      children=[
        @chart.TmItem::make("视觉", value=18.0),
        @chart.TmItem::make("交互", value=12.0),
      ],
    ),
    @chart.TmItem::make("运营", value=25.0),
  ])
  let eff_points : @core.Store[Array[@chart.EffPoint]] = @core.Store::new([
    @chart.EffPoint::make(18.0, 72.0, size=20.0),
    @chart.EffPoint::make(32.0, 58.0, size=14.0),
    @chart.EffPoint::make(47.0, 83.0, size=24.0),
    @chart.EffPoint::make(55.0, 40.0, size=12.0),
    @chart.EffPoint::make(66.0, 63.0, size=16.0),
    @chart.EffPoint::make(78.0, 35.0, size=18.0),
    @chart.EffPoint::make(88.0, 70.0, size=13.0),
  ])
  chart_page(
    "新图表（八种）",
    "关系图 / 平行坐标 / 象形柱 / 旭日 / 主题河流 / 树图 / 矩形树图 / 特效散点（动画自驱动），全部为内置演示数据。",
    [
      @chart.gph_chart_t(graph),
      @chart.par_chart_t(par_axes, par_rows),
      @chart.pb_chart_t(
        pb_data,
        symbol=@chart.PbCircle,
        mode=@chart.PbRepeat,
        unit=12.0,
        show_values=true,
      ),
      @chart.sun_chart_t(sun_root, center_text=Some("总计 129")),
      @chart.trv_chart_t(trv_names, trv_values),
      @chart.tree_chart_t(tree_root),
      @chart.tm_chart_t(tm_items),
      @chart.eff_chart_t(
        eff_points,
        x_range=Some((0.0, 100.0)),
        y_range=Some((0.0, 100.0)),
      ),
    ],
  )
}

///|
/// 交互图表页：line / bar 交互版（滚轮缩放 + 拖拽平移）+ donut。
fn page_charts_itx() -> @core.Node {
  let it_line : @core.Store[Array[@chart.LineSeries]] = @core.Store::new([
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
  let it_bar : @core.Store[Array[@chart.BarItem]] = @core.Store::new([
    @chart.BarItem::make("一月", 120.0),
    @chart.BarItem::make("二月", 96.0),
    @chart.BarItem::make("三月", 145.0),
    @chart.BarItem::make("四月", -35.0),
    @chart.BarItem::make("五月", 168.0),
    @chart.BarItem::make("六月", 132.0),
  ])
  let it_donut : @core.Store[Array[@chart.DonutSlice]] = @core.Store::new([
    @chart.DonutSlice::make("研发", 42.0),
    @chart.DonutSlice::make("市场", 26.0),
    @chart.DonutSlice::make("运营", 18.0),
    @chart.DonutSlice::make("职能", 14.0),
  ])
  chart_page(
    "交互图表",
    "line / bar 为交互版（默认 zoom=true，滚轮以鼠标为锚点缩放、左键拖拽平移）；donut 无 x 轴不提供 DataZoom；三图均含 tooltip 与可点击图例。",
    [
      @chart.line_chart_it(it_line),
      @chart.bar_chart_it(it_bar),
      @chart.donut_chart_it(it_donut, center="合计 100"),
    ],
  )
}

///|
fn main {
  let selected : @core.Store[String] = @core.Store::new("扩展图表")
  let mounted = @ui.mount_window(
    [
      @ui.row(
        [
          @ui.col(
            [
              @ui.menu(
                ["扩展图表", "新图表", "交互图表"],
                selected,
                icons=[
                  ("扩展图表", @icons.DataAnalysis),
                  ("新图表", @icons.DataLine),
                  ("交互图表", @icons.PieChart),
                ],
                width=180.0,
              ),
              @ui.text("全部为演示数据", role=@ui.Secondary),
            ],
            width=180.0,
            padding=10.0,
            row_gap=8.0,
            background_color="bg_panel",
            border_color="border",
          ),
          @ui.col(
            [
              nav_page("扩展图表", selected, page_charts_ext()),
              nav_page("新图表", selected, page_charts_new()),
              nav_page("交互图表", selected, page_charts_itx()),
            ],
            grow=1.0,
          ),
        ],
        grow=1.0,
        align_items=@yoga.AlignItems::Stretch,
      ),
    ],
    title="扩展图表演示板",
    width=1080,
    height=760,
    handle=fn(_a : @core.App) { () },
  )
  match mounted {
    None => {
      println("CHARTS-SKIP: 本平台没有窗口后端或没有显示服务")
      return
    }
    Some(host) => {
      println("CHARTS-READY pages=3")
      host.run()
    }
  }
}
