// 概览页（U2）：关键数值卡片 + 实时曲线。
// 数值卡用 statistic（Store 驱动只改文本）；曲线用 line_chart_t / bar_chart_t
// （定长滚动窗口 120 点，推点只重绘画布）。CPU 总占用固定 0-100 轴，各核
// 柱状同样固定 0-100（自动量程会让 5% 看起来像满格）；内存 / swap 走
// 自适应轴看细节。数据全部来自 main.mbt 的 1Hz sample_once。

///|
/// 一行数值卡片（statistic 横向排列，底部留白）。
fn card_row(items : Array[(String, @yue.Store[String])]) -> @yue.Node {
  let nodes : Array[@yue.Node] = []
  for item in items {
    let (title, store) = item
    nodes.push(@yue.statistic(title, store))
  }
  @yue.hbox(nodes, style=[("marginBottom", 10.0)], style_str=[
    ("alignItems", "center"),
  ])
}

///|
fn page_overview(app : App) -> @yue.Node {
  @yue.scroll(
    @yue.vbox(
      [
        card_row([
          ("CPU 占用", app.card_cpu),
          ("内存", app.card_mem),
          ("swap", app.card_swap),
          ("进程", app.card_proc),
        ]),
        card_row([
          ("最高温度", app.card_temp),
          ("根磁盘", app.card_disk),
          ("网络(非 lo)", app.card_net),
          ("GPU", app.card_gpu),
        ]),
        @yue.separator(style=[("marginBottom", 10.0)]),
        // 第一行曲线：CPU 总占用（0-100 固定轴）+ 各核占用柱状（0-100）。
        // 图表外层 vbox flex=1、内层 fill 不设宽度，随窗口伸缩
        @yue.hbox(
          [
            @yue.vbox(
              [
                @yue.line_chart_t(
                  app.cpu_hist,
                  height=230.0,
                  y_range=Some((0.0, 100.0)),
                  fill=true,
                ),
              ],
              style=[("flex", 1.0)],
            ),
            @yue.label("  "),
            @yue.vbox(
              [
                @yue.bar_chart_t(
                  app.core_bars,
                  height=230.0,
                  y_range=Some((0.0, 100.0)),
                  fill=true,
                ),
              ],
              style=[("flex", 1.0)],
            ),
          ],
          style_str=[("alignItems", "start")],
        ),
        @yue.separator(style=[("marginTop", 12.0), ("marginBottom", 12.0)]),
        // 第二行曲线：内存 + swap（自适应轴）
        @yue.hbox(
          [
            @yue.vbox(
              [@yue.line_chart_t(app.mem_hist, height=230.0, fill=true)],
              style=[("flex", 1.0)],
            ),
            @yue.label("  "),
            @yue.vbox(
              [@yue.line_chart_t(app.swap_hist, height=230.0, fill=true)],
              style=[("flex", 1.0)],
            ),
          ],
          style_str=[("alignItems", "start")],
        ),
      ],
      style=[("padding", 14.0)],
      style_str=[("alignItems", "stretch")],
    ),
    style=[("flex", 1.0)],
  )
}
