// 磁盘页（U4）：容量条 + IO 曲线。每个挂载点一行（挂载点 · 设备 ·
// 文件系统 · 容量条 · 读写速率），上方根分区读写速率 2 分钟曲线。
// 数据来自 main.mbt 的 1Hz sample_once；IO 曲线用 line_chart_t 的
// 定长窗口（series_push）。行容器单容器 on_draw，只重绘画布。

///|
/// 磁盘行自绘：名称行 + 容量条 + 速率行（全部手绘，行数随挂载增减）。
fn draw_disk_rows(p : @yue.Painter, w : Double, disks : Array[DiskInfo]) -> Unit {
  let t = @yue.theme_current()
  for i, d in disks {
    let y = i.to_double() * row_h()
    if zebra_bg(i) {
      p.set_fill_color(t.fill_zebra)
      p.fill_rect(0.0, y, w, row_h())
    }
    let usage = d.usage()
    p.draw_text(
      "\{d.mount} · \{d.device} · \{d.fstype} · \{(usage * 100.0).to_int()}%",
      12.0,
      y + 3.0,
      460.0,
      16.0,
      valign=Center,
      color=t.text_regular,
    )
    p.draw_text(
      "读 \{fmt_rate(d.read_bps)} · 写 \{fmt_rate(d.write_bps)} · 可用 \{fmt_bytes(d.avail_bytes)} / \{fmt_bytes(d.total_bytes)}",
      w - 330.0,
      y + 3.0,
      318.0,
      16.0,
      align=End,
      valign=Center,
      color=t.text_secondary,
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
fn page_disk(app : App) -> @yue.Node {
  let disks : @yue.Store[Array[DiskInfo]] = @yue.Store::new(app.disks.get())
  app.disks.subscribe(fn(d) { disks.set(d) })
  let disk_n : @yue.Store[Int] = @yue.Store::new(disks.get().length())
  disks.subscribe(fn(d) { disk_n.set(d.length()) })
  // 根分区 IO 曲线（读 / 写两序列，120 点窗口）
  let io : @yue.Store[Array[@yue.LineSeries]] = @yue.Store::new([
    @yue.LineSeries::make("读", max_points=120),
    @yue.LineSeries::make("写", max_points=120),
  ])
  let push_io = fn(ds : Array[DiskInfo]) -> Unit {
    for d in ds {
      if d.mount == "/" {
        @yue.series_push(io, 0, d.read_bps)
        @yue.series_push(io, 1, d.write_bps)
      }
    }
  }

  push_io(app.disks.get())
  app.disks.subscribe(push_io)
  @yue.vbox(
    [
      @yue.label_t("根分区 IO 速率（/proc/diskstats 两次差值，B/s）", role=@yue.Section, style=[
        ("marginBottom", 4.0),
      ]),
      @yue.label_t(
        "LVM 卷经 /sys/block/dm-*/dm/name + slaves 反查归属物理盘；容量条 df 口径（已用 = 总 - 可用）。",
        role=@yue.Secondary,
        style=[("marginBottom", 8.0)],
      ),
      @yue.line_chart_t(io, width=1100.0, height=220.0),
      @yue.separator(style=[("marginTop", 12.0), ("marginBottom", 10.0)]),
      draw_rows(disk_n, fn(p, w) { draw_disk_rows(p, w, disks.get()) }),
    ],
    style=[("padding", 12.0)],
  )
}
