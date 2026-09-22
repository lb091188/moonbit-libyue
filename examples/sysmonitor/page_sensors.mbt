// 传感器页（U4）：GPU 枚举 + hwmon 温度列表，每行带 120 点迷你曲线。
// 数据来自 main.mbt 的 1Hz sample_once；行历史按「chip/label」键保序，
// 用 yue 的 win_push 定长窗口（超出丢最旧）。单容器 on_draw 作画，
// 1Hz 刷新只 schedule_paint。

///|
/// 温度行（含迷你曲线历史窗口）。
struct SensorRow {
  chip : String
  label : String
  celsius : Double
  hist : Array[Double]
}

///|
/// 温度迷你曲线固定值域（CPU 0-100℃ 够用，低温传感器也能看趋势）。
fn temp_lo() -> Double {
  0.0
}

///|
fn temp_hi() -> Double {
  100.0
}

///|
/// GPU 行自绘（地址 · 厂商 · 设备，右侧温度）。
fn draw_gpu_rows(p : @yue.Painter, w : Double, gpus : Array[GpuInfo]) -> Unit {
  let t = @yue.theme_current()
  for i, g in gpus {
    let y = i.to_double() * row_h()
    if zebra_bg(i) {
      p.set_fill_color(t.fill_zebra)
      p.fill_rect(0.0, y, w, row_h())
    }
    p.draw_text(
      "\{g.pci} · \{g.vendor} · \{g.device}",
      12.0,
      y,
      420.0,
      row_h(),
      valign=Center,
      color=t.text_regular,
    )
    let temp = match g.celsius {
      None => "—"
      Some(c) => "\{c.to_int()}℃"
    }
    p.draw_text(
      temp,
      w - 90.0,
      y,
      78.0,
      row_h(),
      align=End,
      valign=Center,
      color=t.text_primary,
    )
  }
}

///|
/// 温度行自绘（chip · 标签，右侧数值 + 迷你曲线）。
fn draw_sensor_rows(
  p : @yue.Painter,
  w : Double,
  rows : Array[SensorRow],
) -> Unit {
  let t = @yue.theme_current()
  for i, r in rows {
    let y = i.to_double() * row_h()
    if zebra_bg(i) {
      p.set_fill_color(t.fill_zebra)
      p.fill_rect(0.0, y, w, row_h())
    }
    p.draw_text(
      "\{r.chip} · \{r.label}",
      12.0,
      y,
      300.0,
      row_h(),
      valign=Center,
      color=t.text_regular,
    )
    // 温度按区间着色（<60 常规 / 60-85 警告 / >85 危险）
    let vc = if r.celsius >= 85.0 {
      t.danger
    } else if r.celsius >= 60.0 {
      t.warning
    } else {
      t.text_primary
    }
    p.draw_text(
      "\{r.celsius.to_int()}℃",
      w - 210.0,
      y,
      78.0,
      row_h(),
      align=End,
      valign=Center,
      color=vc,
    )
    draw_sparkline(
      p,
      w - 120.0,
      y + 7.0,
      108.0,
      row_h() - 14.0,
      r.hist,
      temp_lo(),
      temp_hi(),
      t.primary,
    )
  }
}

///|
/// 页面状态：温度行 + 行历史。
struct SensorPage {
  rows : @yue.Store[Array[SensorRow]]
  hist : Map[String, Array[Double]]
}

///|
fn SensorPage::rebuild(self : SensorPage, sensors : Array[TempSensor]) -> Unit {
  let out : Array[SensorRow] = []
  for s in sensors {
    let key = "\{s.chip}/\{s.label}"
    let prev = self.hist.get(key).unwrap_or([])
    let h = @yue.win_push(prev, 120, s.celsius)
    self.hist.set(key, h)
    out.push({ chip: s.chip, label: s.label, celsius: s.celsius, hist: h })
  }
  self.rows.set(out)
}

///|
fn page_sensors(app : App) -> @yue.Node {
  let page : SensorPage = { rows: @yue.Store::new([]), hist: Map([]) }
  page.rebuild(app.sensors.get())
  app.sensors.subscribe(fn(sensors) { page.rebuild(sensors) })
  let gpus : @yue.Store[Array[GpuInfo]] = @yue.Store::new(app.gpus.get())
  app.gpus.subscribe(fn(g) { gpus.set(g) })
  let gpu_n : @yue.Store[Int] = @yue.Store::new(app.gpus.get().length())
  app.gpus.subscribe(fn(g) { gpu_n.set(g.length()) })
  let sensor_n : @yue.Store[Int] = @yue.Store::new(page.rows.get().length())
  page.rows.subscribe(fn(r) { sensor_n.set(r.length()) })

  @yue.vbox(
    [
      @yue.label_t("显卡（PCI 显示设备，温度走 hwmon）", role=@yue.Section, style=[
        ("marginBottom", 6.0),
      ]),
      @yue.label_t(
        "NVIDIA 专有利用率指标（nvidia-smi 子进程）按计划后置；无 hwmon 温度的显卡显示「—」。",
        role=@yue.Secondary,
        style=[("marginBottom", 10.0)],
      ),
      draw_rows(gpu_n, fn(p, w) { draw_gpu_rows(p, w, gpus.get()) }),
      @yue.separator(style=[("marginTop", 14.0), ("marginBottom", 10.0)]),
      @yue.label_t("温度传感器（/sys/class/hwmon，毫摄氏度换算）", role=@yue.Section, style=[
        ("marginBottom", 4.0),
      ]),
      @yue.label_t(
        "右列 120 点 2 分钟迷你曲线；<60℃ 常规、60-85℃ 警告、>85℃ 危险。",
        role=@yue.Secondary,
        style=[("marginBottom", 8.0)],
      ),
      draw_rows(sensor_n, fn(p, w) { draw_sensor_rows(p, w, page.rows.get()) }),
    ],
    style=[("padding", 12.0)],
  )
}
