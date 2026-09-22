// 概览页（U2）：资源卡片 + 实时曲线。卡片范式对标 Mission Center：
// 图标 + 标题、规格副标题（CPU 型号等硬件规格放这里，不在窗口顶层
// 占行）、当前值行（多级单位紧凑格式）、卡内迷你曲线——每张卡自包含。
// 数值经 Store 驱动只改文本，迷你曲线与曲线图推点只 schedule_paint
// 画布。CPU 总占用固定 0-100 轴，各核柱状同样固定 0-100（自动量程
// 会让 5% 看起来像满格）；内存 / swap 走自适应轴看细节。数据全部来自
// main.mbt 的 1Hz sample_once。

///|
/// 卡内迷你曲线：序列窗口值 + 末端圆点。y_range 给固定值域；None 时
/// 取窗口峰值自适应（floor 保底，防全零时除零 / 全平时看不出起伏）。
fn sparkline_box(
  hist : @yue.Store[Array[@yue.LineSeries]],
  y_range : (Double, Double)?,
  floor : Double,
) -> @yue.Node {
  @yue.vbox(
    [],
    style=[("height", 34.0), ("marginTop", 8.0)],
    handle=fn(c) {
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        let t = @yue.theme_current()
        let (lo, hi) = match y_range {
          Some((a, bb)) => (a, bb)
          None => {
            let mut peak = floor
            for s in hist.get() {
              for v in s.points {
                if v > peak {
                  peak = v
                }
              }
            }
            (0.0, peak)
          }
        }
        // 多序列同窗叠加（网络卡 rx 主题色 / tx 警告色）
        for si, s in hist.get() {
          let color = if si == 0 {
            t.primary
          } else {
            t.warning
          }
          draw_sparkline(p, 0.0, 2.0, b.width, b.height - 4.0, s.points, lo, hi, color)
        }
      })
      hist.subscribe(fn(_s) { c.schedule_paint() })
      // 主题切换后重绘（绘制时读 theme_current）
      @yue.on_theme_change(fn() { c.schedule_paint() })
    },
  )
}

///|
/// 资源卡片：图标 + 标题 / 规格副标题 / 当前值 / 迷你曲线（hist 为
/// None 时省略，如本机无 GPU 温度数据）。卡片同排等高（hbox 默认
/// stretch），宽度由 flex 均分，随窗口伸缩。
fn res_card(
  icon : @yue.IconKind,
  title : String,
  subtitle : @yue.Store[String],
  value : @yue.Store[String],
  hist : @yue.Store[Array[@yue.LineSeries]]?,
  y_range? : (Double, Double)? = None,
  floor? : Double = 1.0,
) -> @yue.Node {
  let spark = match hist {
    None => @yue.label("")
    Some(h) => sparkline_box(h, y_range, floor)
  }
  @yue.vbox(
    [
      @yue.hbox(
        [
          @yue.icon(icon, size=16.0),
          @yue.label_t(title, role=@yue.Section, style=[("marginLeft", 6.0)]),
        ],
        style_str=[("alignItems", "center")],
      ),
      @yue.label_t(
        subtitle.get(),
        role=@yue.Secondary,
        handle=fn(l) { subtitle.subscribe(fn(s) { l.set_text(s) }) },
        style=[("marginTop", 2.0)],
      ),
      @yue.label_t(
        value.get(),
        role=@yue.Title,
        handle=fn(l) { value.subscribe(fn(v) { l.set_text(v) }) },
        style=[("marginTop", 4.0)],
      ),
      spark,
    ],
    style=[("padding", 12.0), ("flex", 1.0)],
    handle=fn(c) {
      // 卡片底：面板色 + 1px 边框（主题切换现取色重绘）
      c.on_draw(fn(p) {
        let b = @yue.ViewLike::get_bounds(c)
        let t = @yue.theme_current()
        p.set_fill_color(t.bg_panel)
        p.fill_rect(0.0, 0.0, b.width, b.height)
        p.set_stroke_color(t.border)
        p.stroke_rect(0.5, 0.5, b.width - 1.0, b.height - 1.0)
      })
      @yue.on_theme_change(fn() { c.schedule_paint() })
    },
  )
}

///|
/// 一行资源卡片（flex 均分，底部留白）。
fn card_row(items : Array[@yue.Node]) -> @yue.Node {
  @yue.hbox(items, style=[("marginBottom", 10.0)])
}

///|
fn page_overview(app : App) -> @yue.Node {
  let blank = @yue.Store::new("")
  @yue.scroll(
    @yue.vbox(
      [
        card_row([
          res_card(
            @yue.Cpu,
            "处理器",
            app.card_cpu_sub,
            app.card_cpu,
            Some(app.cpu_hist),
            y_range=Some((0.0, 100.0)),
          ),
          res_card(
            @yue.Database,
            "内存",
            app.card_mem_sub,
            app.card_mem,
            Some(app.mem_hist),
          ),
          res_card(
            @yue.HardDrive,
            "磁盘",
            app.card_disk_sub,
            app.card_disk,
            Some(app.disk_hist),
            y_range=Some((0.0, 100.0)),
          ),
        ]),
        card_row([
          res_card(
            @yue.Wifi,
            "网络",
            blank,
            app.card_net,
            Some(app.net_hist),
            floor=1048576.0,
          ),
          res_card(
            @yue.Monitor,
            "显卡",
            app.card_gpu_sub,
            app.card_gpu,
            None,
          ),
          res_card(
            @yue.TableRows,
            "进程",
            blank,
            app.card_proc,
            Some(app.proc_hist),
          ),
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
