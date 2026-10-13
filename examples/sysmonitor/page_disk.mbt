// 磁盘页（U4）：容量条 + IO 曲线。每个挂载点一行（挂载点 · 占用率 ·
// 容量条 · 读写速率），上方根分区读写速率 2 分钟曲线。
// 数据来自 main.mbt 的 1Hz sample_once；IO 曲线用 line_chart_t 的
// 定长窗口（series_push）。行容器单容器 on_draw，只进程级 invalidate。

///|
/// 速率或「—」：来源不可用时（macOS 无磁盘 IO 来源 / 挂载无 IO 归属 /
/// 首帧无前样本）速率字段为 None，显示「—」而不是虚构的 0 B/s。
fn fmt_rate_opt(bps : Double?) -> String {
  match bps {
    None => "—"
    Some(v) => fmt_rate(v)
  }
}

///|
/// 磁盘行自绘：名称行 + 容量条 + 速率行（全部手绘，行数随挂载增减）。
fn draw_disk_rows(
  p : @render.Painter,
  w : Double,
  disks : Array[DiskInfo],
) -> Unit {
  let t = @theme.theme_current()
  let font = @text.Font::new("", 13.0)
  for i, d in disks {
    let y = i.to_double() * row_h()
    if zebra_bg(i) {
      p.set_fill_color(t.fill_zebra)
      p.fill_rect(0.0, y, w, row_h())
    }
    let usage = d.usage()
    p.flush()
    let _ = @text.draw_box_at(
      p,
      12.0,
      y + 3.0,
      460.0,
      16.0,
      "\{d.mount} · \{(usage * 100.0).to_int()}%",
      font,
      t.text_regular,
      valign=@text.Center,
    )
    let _ = @text.draw_box_at(
      p,
      w - 330.0,
      y + 3.0,
      318.0,
      16.0,
      "读 \{fmt_rate_opt(d.read_bps)} · 写 \{fmt_rate_opt(d.write_bps)} · 可用 \{fmt_bytes(d.avail_bytes)} / \{fmt_bytes(d.total_bytes)}",
      font,
      t.text_secondary,
      align=@text.End,
      valign=@text.Center,
    )
    // 容量条：轨道 + 已用填充（df 口径：已用 = 总 - 可用）
    let bar_y = y + 22.0
    let bar_w = w - 24.0
    p.set_fill_color(t.fill_zebra)
    p.fill_rect(12.0, bar_y, bar_w, 6.0)
    if usage > 0.0 {
      let bc = if usage >= 0.9 {
        t.danger
      } else if usage >= 0.75 {
        t.warning
      } else {
        t.primary
      }
      p.set_fill_color(bc)
      p.fill_rect(12.0, bar_y, bar_w * usage.min(1.0), 6.0)
    }
  }
}

///|
fn page_disk(app : App) -> @core.Node {
  let disk_n : @core.Store[Int] = @core.Store::new(app.disks.get().length())
  app.disks.subscribe(fn(d) { disk_n.set(d.length()) })
  // 根分区 IO 曲线（读 / 写两序列，120 点窗口）；速率来源不可用时
  // （macOS 无 IO 数据）不推点，曲线保持空态而不是画一条假的 0 线
  let io : @core.Store[Array[@charts.LineSeries]] = @core.Store::new([
    @charts.LineSeries::make("读", max_points=120),
    @charts.LineSeries::make("写", max_points=120),
  ])
  let push_io = fn(ds : Array[DiskInfo]) -> Unit {
    for d in ds {
      if d.mount == "/" {
        match d.read_bps {
          Some(v) => @charts.series_push(io, 0, v)
          None => ()
        }
        match d.write_bps {
          Some(v) => @charts.series_push(io, 1, v)
          None => ()
        }
      }
    }
  }

  push_io(app.disks.get())
  app.disks.subscribe(push_io)
  @ui.col(
    [
      @ui.text("根分区读写", role=@ui.Section),
      @charts.line_chart_t(io, height=220.0, area=true),
      @ui.separator(),
      draw_rows(disk_n, fn(p, w) { draw_disk_rows(p, w, app.disks.get()) }),
    ],
    padding=12.0,
    row_gap=6.0,
  )
}
