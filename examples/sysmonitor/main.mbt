// sysmonitor：Ubuntu 进程管理与硬件信息查看（示例应用）。
// 数据层纯 MoonBit 读 /proc、/sys（sysdata.mbt / sysproc.mbt / syshw.mbt），
// 唯一的系统调用经应用自有 native-stub（stub/sysmon.c，sysffi.mbt）；
// 单一 1Hz 定时器驱动全部采样，各页经 Store 订阅刷新——数值卡只改文本，
// 曲线只 schedule_paint 画布，不重建视图树。主题深浅启动跟随系统并实时
// 联动（tabs_t 五页：概览 / 进程 / 传感器 / 磁盘 / 网络）。

///|
/// kB 转人类可读（/proc/meminfo 单位为 kB）。
fn fmt_kb(kb : Int64) -> String {
  let gb = kb.to_double() / 1048576.0
  if gb >= 1.0 {
    "\{gb.to_int()}.\{(gb * 10.0).to_int() % 10} GB"
  } else {
    "\{(kb.to_double() / 1024.0).to_int()} MB"
  }
}

///|
/// 字节数人类可读（磁盘 / 网络）。
fn fmt_bytes(b : Int64) -> String {
  let gb = b.to_double() / 1073741824.0
  if gb >= 1.0 {
    "\{gb.to_int()}.\{(gb * 10.0).to_int() % 10} GB"
  } else {
    "\{(b.to_double() / 1048576.0).to_int()} MB"
  }
}

///|
/// 速率人类可读（B/s → KB/s → MB/s）。
fn fmt_rate(bps : Double) -> String {
  if bps >= 1048576.0 {
    "\{(bps / 1048576.0).to_int()} MB/s"
  } else if bps >= 1024.0 {
    "\{(bps / 1024.0).to_int()} KB/s"
  } else {
    "\{bps.to_int()} B/s"
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
  // 概览页：数值卡片
  card_cpu : @yue.Store[String]
  card_mem : @yue.Store[String]
  card_swap : @yue.Store[String]
  card_proc : @yue.Store[String]
  card_temp : @yue.Store[String]
  card_disk : @yue.Store[String]
  card_net : @yue.Store[String]
  card_gpu : @yue.Store[String]
  // 概览页：实时曲线（定长滚动窗口 120 点 = 2 分钟 @1Hz）
  cpu_hist : @yue.Store[Array[@yue.LineSeries]]
  core_bars : @yue.Store[Array[@yue.BarItem]]
  mem_hist : @yue.Store[Array[@yue.LineSeries]]
  swap_hist : @yue.Store[Array[@yue.LineSeries]]
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
  match app.cpu.tick() {
    None => ()
    Some((usage, per_core)) => {
      app.card_cpu.set(pct(usage))
      @yue.series_push(app.cpu_hist, 0, usage * 100.0)
      let bars : Array[@yue.BarItem] = []
      for i, u in per_core {
        bars.push(@yue.BarItem::make("\{i}", u * 100.0))
      }
      app.core_bars.set(bars)
    }
  }
  match mem_info() {
    None => ()
    Some(mem) => {
      let used_gb = mem.used_kb().to_double() / 1048576.0
      let swap_gb = (mem.swap_total_kb - mem.swap_free_kb).to_double() / 1048576.0
      app.card_mem.set("\{pct(mem.usage())} · \{fmt_kb(mem.used_kb())}")
      app.card_swap.set(
        "\{pct(mem.swap_usage())} · \{fmt_kb(mem.swap_total_kb - mem.swap_free_kb)}",
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
        None => app.card_temp.set("—")
        Some(t) => app.card_temp.set("\{t.celsius.to_int()}℃ · \{t.label}")
      }
    }
  }
  match gpu_list() {
    None => ()
    Some(gpus) => {
      app.gpus.set(gpus)
      if gpus.length() > 0 {
        let g = gpus[0]
        app.card_gpu.set("\{g.vendor} \{g.device}")
      } else {
        app.card_gpu.set("—")
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
            "\{pct(d.usage())} · \{fmt_bytes(d.total_bytes - d.avail_bytes)}",
          )
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
      app.card_net.set("↓\{fmt_rate(rx)} ↑\{fmt_rate(tx)}")
    }
  }
}

///|
/// 占位页：数据已在采样，页面在后续批次填充。
fn page_placeholder(title : String) -> @yue.Node {
  @yue.vbox(
    [
      @yue.label_t("\{title}页", role=@yue.Section, style=[
        ("marginBottom", 6.0),
      ]),
      @yue.label_t("数据层已在 1Hz 采样，本页界面在后续批次填充。", role=@yue.Secondary),
    ],
    style=[("padding", 14.0)],
  )
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

  let app : App = {
    cpu: CpuMonitor::new(),
    proc: ProcMonitor::new(info.cores),
    disk: DiskMonitor::new(),
    net: NetMonitor::new(),
    card_cpu: @yue.Store::new("—"),
    card_mem: @yue.Store::new("—"),
    card_swap: @yue.Store::new("—"),
    card_proc: @yue.Store::new("—"),
    card_temp: @yue.Store::new("—"),
    card_disk: @yue.Store::new("—"),
    card_net: @yue.Store::new("—"),
    card_gpu: @yue.Store::new("—"),
    cpu_hist: @yue.Store::new([@yue.LineSeries::make("CPU", max_points=120)]),
    core_bars: @yue.Store::new([]),
    mem_hist: @yue.Store::new([@yue.LineSeries::make("内存", max_points=120)]),
    swap_hist: @yue.Store::new([@yue.LineSeries::make("swap", max_points=120)]),
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
        [
          @yue.label_t(
            "sysmonitor · Ubuntu 进程管理与硬件信息查看 · \{info.model} · \{info.cores} 逻辑核",
            role=@yue.Secondary,
            style=[
              ("paddingLeft", 14.0),
              ("paddingTop", 8.0),
              ("paddingBottom", 4.0),
            ],
          ),
          @yue.tabs_t(
            [
              ("概览", page_overview(app)),
              ("进程", page_placeholder("进程管理")),
              ("传感器", page_placeholder("传感器(温度 / GPU)")),
              ("磁盘", page_placeholder("磁盘")),
              ("网络", page_placeholder("网络")),
            ],
          ),
        ],
        style=[("flex", 1.0), ("padding", 6.0)],
      ),
    ],
    title="sysmonitor",
    size=Some((1180.0, 840.0)),
  )
  ignore(window)
  @yue.run()
}
