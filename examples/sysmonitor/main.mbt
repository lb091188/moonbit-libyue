// sysmonitor：Ubuntu 进程管理与硬件信息查看（示例应用）。
// 数据层纯 MoonBit 读 /proc、/sys（sysdata.mbt / sysproc.mbt / syshw.mbt），
// 唯一的系统调用经应用自有 native-stub（stub/sysmon.c，sysffi.mbt）；
// 单一 1Hz 定时器驱动全部采样，各页经 Store 订阅刷新——数值卡只改文本，
// 曲线只 schedule_paint 画布，不重建视图树。主题深浅启动跟随系统并实时
// 联动（tabs_t 五页：概览 / 进程 / 传感器 / 磁盘 / 网络）。

///|
/// kB 转人类可读（/proc/meminfo 单位为 kB）。
fn fmt_kb(kb : Int64) -> String {
  fmt_bytes(kb * 1024)
}

///|
/// 字节数人类可读：多级单位动态换挡（B / KB / MB / GB），值超 10 后
/// 只留整数档，小数值最多一位小数——保持字符串短，卡片与表格列内
/// 不换行。
fn fmt_bytes(b : Int64) -> String {
  let gb = b.to_double() / 1073741824.0
  if gb >= 1.0 {
    return "\{fmt_scale(gb)} GB"
  }
  let mb = b.to_double() / 1048576.0
  if mb >= 1.0 {
    return "\{fmt_scale(mb)} MB"
  }
  let kb = b.to_double() / 1024.0
  if kb >= 1.0 {
    return "\{fmt_scale(kb)} KB"
  }
  "\{b} B"
}

///|
/// 速率人类可读：B/s → KB/s → MB/s → GB/s，与 fmt_bytes 同档规则。
fn fmt_rate(bps : Double) -> String {
  if bps >= 1073741824.0 {
    "\{fmt_scale(bps / 1073741824.0)} GB/s"
  } else if bps >= 1048576.0 {
    "\{fmt_scale(bps / 1048576.0)} MB/s"
  } else if bps >= 1024.0 {
    "\{fmt_scale(bps / 1024.0)} KB/s"
  } else {
    "\{bps.to_int()} B/s"
  }
}

///|
/// 速率紧凑格式（概览卡片用）：单位缩成单字母且不带 /s，箭头已表方向，
/// 数值位尽量短。
fn fmt_rate_c(bps : Double) -> String {
  if bps >= 1073741824.0 {
    "\{fmt_scale(bps / 1073741824.0)}G"
  } else if bps >= 1048576.0 {
    "\{fmt_scale(bps / 1048576.0)}M"
  } else if bps >= 1024.0 {
    "\{fmt_scale(bps / 1024.0)}K"
  } else {
    "\{bps.to_int()}B"
  }
}

///|
/// 缩放数值：≥10 或恰为整数时只出整数档，否则一位小数——保持字符串短。
fn fmt_scale(v : Double) -> String {
  let scaled = (v * 10.0).round().to_int()
  if scaled % 10 == 0 {
    "\{scaled / 10}"
  } else {
    "\{scaled / 10}.\{scaled % 10}"
  }
}

///|
fn pct(v : Double) -> String {
  "\{(v * 100.0).to_int()}%"
}

///|
/// 应用状态：各采样器（持差值前样本）+ 跨页共享 Store。页面函数以 app
/// 单参取用；页内私有状态不进 App。
struct App {
  cpu : CpuMonitor
  proc : ProcMonitor
  disk : DiskMonitor
  net : NetMonitor
  // 概览页：资源卡片值行（标题行右侧，紧凑格式防溢出）
  card_cpu : @yue.Store[String]
  card_mem : @yue.Store[String]
  card_disk : @yue.Store[String]
  card_net : @yue.Store[String]
  card_proc : @yue.Store[String]
  // 概览页：实时曲线（定长滚动窗口 120 点 = 2 分钟 @1Hz）
  cpu_hist : @yue.Store[Array[@yue.LineSeries]]
  core_bars : @yue.Store[Array[@yue.BarItem]]
  mem_hist : @yue.Store[Array[@yue.LineSeries]]
  swap_hist : @yue.Store[Array[@yue.LineSeries]]
  disk_hist : @yue.Store[Array[@yue.LineSeries]]
  net_hist : @yue.Store[Array[@yue.LineSeries]]
  // GPU 详情页与卡值：每块物理卡一套（数量取启动枚举结果，热插拔不重建）
  card_gpu_vals : Array[@yue.Store[String]]
  gpu_busy_hists : Array[@yue.Store[Array[@yue.LineSeries]]]
  gpu_vram_hists : Array[@yue.Store[Array[@yue.LineSeries]]]
  // 其余页数据源（进程 / 传感器 / 磁盘 / 网络页订阅）
  procs : @yue.Store[Array[ProcInfo]]
  sensors : @yue.Store[Array[TempSensor]]
  gpus : @yue.Store[Array[GpuInfo]]
  disks : @yue.Store[Array[DiskInfo]]
  nets : @yue.Store[Array[NetInfo]]
}

///|
/// 一次全量采样：全部监视器 tick 后写入对应 Store。单个来源读取失败
/// （平台不支持 / 瞬时竞态）只跳过该项，不影响其余卡片。
fn sample_once(app : App) -> Unit {
  // 处理器卡：占用 % · 最高温度（两个来源拼一行，任一缺失只显示有的）
  let mut cpu_text = ""
  match app.cpu.tick() {
    None => ()
    Some((usage, per_core)) => {
      cpu_text = pct(usage)
      @yue.series_push(app.cpu_hist, 0, usage * 100.0)
      let bars : Array[@yue.BarItem] = []
      for i, u in per_core {
        bars.push(@yue.BarItem::make("\{i}", u * 100.0))
      }
      app.core_bars.set(bars)
    }
  }
  match hwmon_sensors() {
    None => ()
    Some(sensors) => {
      app.sensors.set(sensors)
      let mut hottest : TempSensor? = None
      for s in sensors {
        match hottest {
          None => hottest = Some(s)
          Some(t) =>
            if s.celsius > t.celsius {
              hottest = Some(s)
            }
        }
      }
      match hottest {
        None => ()
        Some(t) => cpu_text = "\{cpu_text} · \{t.celsius.to_int()}℃"
      }
    }
  }
  if cpu_text != "" {
    app.card_cpu.set(cpu_text)
  }
  match mem_info() {
    None => ()
    Some(mem) => {
      let used_gb = mem.used_kb().to_double() / 1048576.0
      let swap_gb = (mem.swap_total_kb - mem.swap_free_kb).to_double() / 1048576.0
      app.card_mem.set(
        "\{fmt_rate_c(mem.used_kb().to_double() * 1024.0)} / \{fmt_rate_c(mem.total_kb.to_double() * 1024.0)}",
      )
      @yue.series_push(app.mem_hist, 0, used_gb)
      @yue.series_push(app.swap_hist, 0, swap_gb)
    }
  }
  match app.proc.tick() {
    None => ()
    Some(procs) => {
      app.procs.set(procs)
      app.card_proc.set("\{procs.length()}")
    }
  }
  match gpu_list() {
    None => ()
    Some(gpus) => {
      app.gpus.set(gpus)
      // 数量以启动枚举为准，超界（极端热插拔）只跳过，不重建视图
      for i, g in gpus {
        if i >= app.gpu_busy_hists.length() {
          break
        }
        match g.busy {
          Some(b) => @yue.series_push(app.gpu_busy_hists[i], 0, b)
          None => ()
        }
        match g.vram_used {
          Some(v) =>
            @yue.series_push(app.gpu_vram_hists[i], 0, v / 1073741824.0)
          None => ()
        }
        let val = match (g.busy, g.celsius) {
          (Some(b), Some(c)) => "\{b.to_int()}% · \{c.to_int()}℃"
          (Some(b), None) => "\{b.to_int()}%"
          (None, Some(c)) => "\{c.to_int()}℃"
          (None, None) => "—"
        }
        app.card_gpu_vals[i].set(val)
      }
    }
  }
  match app.disk.tick() {
    None => ()
    Some(disks) => {
      app.disks.set(disks)
      for d in disks {
        if d.mount == "/" {
          app.card_disk.set(
            "\{pct(d.usage())} · \{fmt_rate_c((d.total_bytes - d.avail_bytes).to_double())}",
          )
          @yue.series_push(app.disk_hist, 0, d.usage() * 100.0)
        }
      }
    }
  }
  match app.net.tick() {
    None => ()
    Some(nets) => {
      app.nets.set(nets)
      let mut rx = 0.0
      let mut tx = 0.0
      for n in nets {
        if n.name != "lo" {
          rx += n.rx_bps
          tx += n.tx_bps
        }
      }
      app.card_net.set("↓\{fmt_rate_c(rx)} ↑\{fmt_rate_c(tx)}")
      @yue.series_push(app.net_hist, 0, rx)
      @yue.series_push(app.net_hist, 1, tx)
    }
  }
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let info = cpu_info().unwrap_or({ model: "(未知)", mhz: 0.0, cores: 1 })
  // 深浅主题：启动跟随系统，系统切换时实时联动
  let dark_mode : @yue.Store[Bool] = @yue.Store::new(@yue.system_prefers_dark())
  dark_mode.subscribe(fn(v) {
    if v {
      @yue.theme_apply(@yue.dark_theme())
    } else {
      @yue.theme_apply(@yue.default_theme())
    }
  })
  @yue.on_system_theme_change(fn() { dark_mode.set(@yue.system_prefers_dark()) })

  // GPU 数量取启动枚举结果，卡与曲线按块预建（热插拔不重建视图）
  let gpus0 : Array[GpuInfo] = match gpu_list() {
    Some(g) => g
    None => []
  }

  let app : App = {
    cpu: CpuMonitor::new(),
    proc: ProcMonitor::new(info.cores),
    disk: DiskMonitor::new(),
    net: NetMonitor::new(),
    card_cpu: @yue.Store::new("—"),
    card_mem: @yue.Store::new("—"),
    card_disk: @yue.Store::new("—"),
    card_net: @yue.Store::new("—"),
    card_proc: @yue.Store::new("—"),
    cpu_hist: @yue.Store::new([@yue.LineSeries::make("CPU", max_points=120)]),
    core_bars: @yue.Store::new([]),
    mem_hist: @yue.Store::new([@yue.LineSeries::make("内存", max_points=120)]),
    swap_hist: @yue.Store::new([@yue.LineSeries::make("swap", max_points=120)]),
    disk_hist: @yue.Store::new([@yue.LineSeries::make("已用", max_points=120)]),
    net_hist: @yue.Store::new([
      @yue.LineSeries::make("接收", max_points=120),
      @yue.LineSeries::make("发送", max_points=120),
    ]),
    card_gpu_vals: gpus0.map(fn(_g) { @yue.Store::new("—") }),
    gpu_busy_hists: gpus0.map(fn(_g) {
      @yue.Store::new([@yue.LineSeries::make("占用", max_points=120)])
    }),
    gpu_vram_hists: gpus0.map(fn(_g) {
      @yue.Store::new([@yue.LineSeries::make("显存", max_points=120)])
    }),
    procs: @yue.Store::new([]),
    sensors: @yue.Store::new([]),
    gpus: @yue.Store::new([]),
    disks: @yue.Store::new([]),
    nets: @yue.Store::new([]),
  }
  // 首帧立即采一次（第二帧起差值速率才有值），随后 1Hz 定时
  sample_once(app)
  ignore(
    @yue.set_timer(1000, fn() {
      sample_once(app)
      true
    }),
  )

  let window = @yue.mount_window(
    [
      @yue.vbox(
        [app_shell(app)],
        style=[("flex", 1.0), ("padding", 6.0)],
      ),
    ],
    title="系统监视器",
    size=Some((1240.0, 840.0)),
  )
  ignore(window)
  @yue.run()
}
