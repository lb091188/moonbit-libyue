// 网络页（U4）：网卡 rx/tx 曲线。上方非 lo 汇总收发 2 分钟曲线，
// 下方每块网卡一行（名称 · 累计 · 迷你曲线（rx/tx 叠加）· 瞬时速率）。
// 数据来自 main.mbt 的 1Hz sample_once；行历史按网卡名保序，
// win_push 定长窗口。单容器 on_draw，1Hz 刷新只 schedule_paint。

///|
/// 网卡行（含 rx/tx 迷你曲线历史窗口）。
struct NetRow {
  name : String
  rx_bytes : Int64
  tx_bytes : Int64
  rx_bps : Double
  tx_bps : Double
  rx_hist : Array[Double]
  tx_hist : Array[Double]
}

///|
/// 页面状态：网卡行 + 行历史。
struct NetPage {
  rows : @yue.Store[Array[NetRow]]
  hist : Map[String, (Array[Double], Array[Double])]
}

///|
fn NetPage::rebuild(self : NetPage, nets : Array[NetInfo]) -> Unit {
  let out : Array[NetRow] = []
  for n in nets {
    let (rx_old, tx_old) = self.hist.get(n.name).unwrap_or(([], []))
    let rx_h = @yue.win_push(rx_old, 120, n.rx_bps)
    let tx_h = @yue.win_push(tx_old, 120, n.tx_bps)
    self.hist.set(n.name, (rx_h, tx_h))
    out.push({
      name: n.name,
      rx_bytes: n.rx_bytes,
      tx_bytes: n.tx_bytes,
      rx_bps: n.rx_bps,
      tx_bps: n.tx_bps,
      rx_hist: rx_h,
      tx_hist: tx_h,
    })
  }
  self.rows.set(out)
}

///|
/// 历史窗口峰值（迷你曲线值域上限，保底 1MB/s 防全零时除零）。
fn hist_peak(hist : Array[Double]) -> Double {
  let mut peak = 1048576.0
  for v in hist {
    if v > peak {
      peak = v
    }
  }
  peak
}

///|
/// 网卡行自绘。
fn draw_net_rows(p : @yue.Painter, w : Double, rows : Array[NetRow]) -> Unit {
  let t = @yue.theme_current()
  for i, n in rows {
    let y = i.to_double() * row_h()
    if zebra_bg(i) {
      p.set_fill_color(t.fill_zebra)
      p.fill_rect(0.0, y, w, row_h())
    }
    p.draw_text(n.name, 12.0, y, 130.0, row_h(), valign=Center, color=t.text_regular)
    p.draw_text(
      "累计 ↓\{fmt_bytes(n.rx_bytes)} ↑\{fmt_bytes(n.tx_bytes)}",
      148.0,
      y,
      280.0,
      row_h(),
      valign=Center,
      color=t.text_secondary,
    )
    // 迷你曲线：rx / tx 同窗叠加（值域取两者峰值较大者）
    let peak = hist_peak(n.rx_hist).max(hist_peak(n.tx_hist))
    let sx = w - 450.0
    let sw = 220.0
    draw_sparkline(
      p,
      sx,
      y + 7.0,
      sw,
      row_h() - 14.0,
      n.rx_hist,
      0.0,
      peak,
      t.primary,
    )
    draw_sparkline(
      p,
      sx,
      y + 7.0,
      sw,
      row_h() - 14.0,
      n.tx_hist,
      0.0,
      peak,
      t.warning,
    )
    p.draw_text(
      "↓\{fmt_rate(n.rx_bps)}",
      w - 218.0,
      y,
      100.0,
      row_h(),
      align=End,
      valign=Center,
      color=t.primary,
    )
    p.draw_text(
      "↑\{fmt_rate(n.tx_bps)}",
      w - 108.0,
      y,
      96.0,
      row_h(),
      align=End,
      valign=Center,
      color=t.warning,
    )
  }
}

///|
fn page_net(app : App) -> @yue.Node {
  let page : NetPage = { rows: @yue.Store::new([]), hist: Map([]) }
  page.rebuild(app.nets.get())
  app.nets.subscribe(fn(nets) { page.rebuild(nets) })
  let net_n : @yue.Store[Int] = @yue.Store::new(page.rows.get().length())
  page.rows.subscribe(fn(r) { net_n.set(r.length()) })
  // 非 lo 汇总收发曲线（两序列，120 点窗口）
  let total : @yue.Store[Array[@yue.LineSeries]] = @yue.Store::new([
    @yue.LineSeries::make("接收", max_points=120),
    @yue.LineSeries::make("发送", max_points=120),
  ])
  let push_total = fn(ns : Array[NetInfo]) -> Unit {
    let mut rx = 0.0
    let mut tx = 0.0
    for n in ns {
      if n.name != "lo" {
        rx += n.rx_bps
        tx += n.tx_bps
      }
    }
    @yue.series_push(total, 0, rx)
    @yue.series_push(total, 1, tx)
  }

  push_total(app.nets.get())
  app.nets.subscribe(push_total)
  @yue.vbox(
    [
      @yue.label_t("收发速率（不含 lo）", role=@yue.Section, style=[
        ("marginBottom", 6.0),
      ]),
      @yue.line_chart_t(total, height=220.0, fill=true),
      @yue.separator(style=[("marginTop", 12.0), ("marginBottom", 10.0)]),
      draw_rows(net_n, fn(p, w) { draw_net_rows(p, w, page.rows.get()) }),
    ],
    style=[("padding", 12.0)],
  )
}
