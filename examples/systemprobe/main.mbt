// 系统能力与扩展图表演示板:系统能力(音量/屏幕亮度/浏览器历史与下载
// 记录/VS Code 最近工作区/应用二进制查找)真实读取本机数据,点按钮
// 呈现,结果因机而异;扩展图表(雷达/热力/K 线/漏斗/箱线/桑基)为内置
// 演示数据。不支持的能力显示对应错误文本,不影响其余部分。

///|
/// 收集系统能力各模块的当前快照(多行文本)。
fn sysprobe_collect() -> String {
  let buf = StringBuilder()
  buf.write_string("== 音量(默认 sink) ==\n")
  match @yue.vol_get() {
    Ok(v) =>
      buf.write_string(
        "sink: \{v.sink}\n音量: \{v.volume}%  静音: \{if v.muted { "是" } else { "否" }}\n",
      )
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 屏幕亮度 ==\n")
  match @yue.brightness_devices() {
    Ok(devs) => {
      if devs.is_empty() {
        buf.write_string("无背光设备\n")
      }
      for d in devs {
        let cur = match @yue.brightness_get(d) {
          Ok(p) => "\{p}%"
          Err(e) => "读取失败(\{e})"
        }
        buf.write_string("\{d.name}(量程 \{d.max}): \{cur}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 浏览器历史(前 6 条) ==\n")
  match @yue.bh_history(limit=6) {
    Ok(items) => {
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for it in items {
        let title = if it.title == "" { "(无标题)" } else { it.title }
        buf.write_string("[\{it.visit_count}次] \{title}\n  \{it.url}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  match @yue.bh_downloads(limit=3) {
    Ok(items) => {
      buf.write_string("\n== 浏览器下载记录(前 3 条) ==\n")
      if items.is_empty() {
        buf.write_string("无记录\n")
      }
      for d in items {
        buf.write_string(
          "\{d.target_path}  \{d.received_bytes}/\{d.total_bytes} 字节  \{@yue.bh_download_state_name(d.state)}\n",
        )
      }
    }
    Err(_) => ()
  }
  buf.write_string("\n== VS Code 最近工作区(前 8 条) ==\n")
  match @yue.vsc_recent() {
    Ok(paths) => {
      if paths.is_empty() {
        buf.write_string("无记录\n")
      }
      let n = if paths.length() > 8 { 8 } else { paths.length() }
      for i = 0; i < n; i = i + 1 {
        buf.write_string("\{paths[i]}\n")
      }
    }
    Err(e) => buf.write_string("不可用: \{e}\n")
  }
  buf.write_string("\n== 应用二进制查找 ==\n")
  for name in ["sh", "firefox", "code", "google-chrome"] {
    match @yue.appfind_executable(name) {
      Ok(p) => buf.write_string("\{name} -> \{p}\n")
      Err(_) => buf.write_string("\{name} -> 未找到\n")
    }
  }
  buf.to_string()
}

///|
fn main {
  if !@yue.initialize() {
    println("GUI 初始化失败")
    return
  }
  @yue.theme_apply(@yue.theme_from_system())
  // 报告标签:点「读取」后 set_text;变长文本须补 update_layout,否则
  // 宽度停在挂载瞬间被截断
  let report : Ref[@yue.Label?] = Ref(None)
  // 雷达图:六维对比,双系列
  let radar_ind : @yue.Store[Array[@yue.RadarIndicator]] = @yue.Store::new([
    @yue.RadarIndicator::make("渲染", 100.0),
    @yue.RadarIndicator::make("IO", 100.0),
    @yue.RadarIndicator::make("内存", 100.0),
    @yue.RadarIndicator::make("启动", 100.0),
    @yue.RadarIndicator::make("体积", 100.0),
    @yue.RadarIndicator::make("功耗", 100.0),
  ])
  let radar_ser : @yue.Store[Array[@yue.RadarSeries]] = @yue.Store::new([
    @yue.RadarSeries::make("本方案", [88.0, 72.0, 80.0, 92.0, 85.0, 78.0]),
    @yue.RadarSeries::make("对照", [70.0, 90.0, 65.0, 75.0, 60.0, 82.0]),
  ])
  // 热力图:一周三时段活跃度矩阵
  let heat : @yue.Store[@yue.HeatGrid] = @yue.Store::new(
    @yue.HeatGrid::make(
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
  let candles : @yue.Store[Array[@yue.Candle]] = @yue.Store::new([
    @yue.Candle::make(100.0, 108.0, 98.0, 105.0),
    @yue.Candle::make(105.0, 107.0, 99.0, 101.0),
    @yue.Candle::make(101.0, 110.0, 100.0, 108.0),
    @yue.Candle::make(108.0, 112.0, 104.0, 106.0),
    @yue.Candle::make(106.0, 109.0, 101.0, 103.0),
    @yue.Candle::make(103.0, 105.0, 97.0, 99.0),
    @yue.Candle::make(99.0, 104.0, 96.0, 102.0),
  ])
  // 漏斗:转化漏斗五层
  let funnel : @yue.Store[Array[@yue.BarItem]] = @yue.Store::new([
    @yue.BarItem::make("浏览", 1000.0),
    @yue.BarItem::make("加购", 420.0),
    @yue.BarItem::make("下单", 260.0),
    @yue.BarItem::make("支付", 190.0),
    @yue.BarItem::make("复购", 80.0),
  ])
  // 箱线:三组耗时分布(含离群点)
  let boxp : @yue.Store[Array[(String, Array[Double])]] = @yue.Store::new([
    ("渲染", [12.0, 14.0, 15.0, 16.0, 18.0, 21.0, 25.0, 30.0]),
    ("IO", [5.0, 6.0, 6.5, 7.0, 8.0, 9.0, 12.0]),
    ("启动", [70.0, 75.0, 78.0, 80.0, 82.0, 90.0, 110.0]),
  ])
  // 桑基:浏览 -> 加购/直接下单 -> 支付/流失 的流向
  let sankey : @yue.Store[@yue.SankeyData] = @yue.Store::new(
    @yue.SankeyData::make(
      [
        @yue.SankeyNode::make("浏览"),
        @yue.SankeyNode::make("加购"),
        @yue.SankeyNode::make("直接下单"),
        @yue.SankeyNode::make("支付"),
        @yue.SankeyNode::make("流失"),
      ],
      [
        @yue.SankeyLink::make(0, 1, 420.0),
        @yue.SankeyLink::make(0, 2, 200.0),
        @yue.SankeyLink::make(1, 3, 190.0),
        @yue.SankeyLink::make(2, 3, 160.0),
        @yue.SankeyLink::make(0, 4, 380.0),
        @yue.SankeyLink::make(1, 4, 230.0),
      ],
    ),
  )
  let inner : Array[@yue.Node] = [
    @yue.label_t("系统能力 · 扩展图表", role=@yue.Title),
    @yue.label_t("系统能力读取本机真实数据,结果因机而异;图表为内置演示数据。", role=@yue.Secondary),
    @yue.button_t(
      "读取系统能力",
      variant=@yue.Solid,
      style=[("marginTop", 12.0)],
      on_click=fn() {
        match report.val {
          Some(l) => {
            l.set_text(sysprobe_collect())
            @yue.ViewLike::update_layout(l)
          }
          None => ()
        }
      },
    ),
    @yue.label_t(
      "(点击按钮后此处显示音量/亮度/浏览器历史/VS Code/应用查找结果)",
      role=@yue.Body,
      style=[("marginTop", 10.0)],
      handle=fn(l) { report.val = Some(l) },
    ),
    @yue.label_t("扩展图表", role=@yue.Section, style=[("marginTop", 16.0)]),
    @yue.radar_chart_t(radar_ind, radar_ser, fill=true),
    @yue.heatmap_t(heat, fill=true, show_values=true),
    @yue.candlestick_t(candles, fill=true),
    @yue.funnel_t(funnel, fill=true),
    @yue.boxplot_t(boxp, fill=true),
    @yue.sankey_t(sankey, fill=true),
  ]
  ignore(
    @yue.mount_window(
    [
      @yue.scroll(
        @yue.vbox(inner, style=[("padding", 20.0), ("gap", 14.0)]),
      ),
    ],
    title="systemprobe",
    size=Some((960.0, 740.0)),
    center=true,
    on_close=fn(_w) { @yue.quit() },
    ),
  )
  @yue.run()
}
