// 系统监视器（sysmonitor，G7 新栈版）：Ubuntu/Mission Center 式进程管理
// 与硬件信息查看。数据层纯 MoonBit 读 /proc、/sys（sysdata/sysproc/syshw），
// 唯一的系统调用经应用自有 native-stub（stub/sysmon.c，sysffi.mbt）；
// 单一 1Hz 定时器驱动全部采样，各页经 Store 订阅刷新——数值卡只改文本，
// 曲线只进程级 invalidate 重绘画布，不重建视图树。主题深浅启动跟随系统
// 并实时联动（App::follow_system_theme）。左栏资源卡片即菜单，右栏全部
// 详情页一次性挂载、按 view 切可见性（选中态 / 滚动位置 / 表格选择不丢）。
//
// G7 迁移记档（与 master 旧版的差）：
//   - 旧栈 yue/declarative/components 三个别名全部换 core/ui/theme；
//     style 字符串列表换组件的具名参数（padding/row_gap/grow/width）。
//   - 自绘容器重绘从「schedule_paint + on_theme_change」换成
//     「Store.subscribe + @core.invalidate()」（进程级 host_repaint_all）；
//     主题切换重绘同样走 invalidate（on_draw 每次实时读 theme_current）。
//   - 手型光标从「逐子控件 set_cursor」换成 cursor_group（宿主取
//     悬停路径最深的非零请求，组内一处即可盖住全部）。
//   - 图表 fill=true 换 area=true；表格 table_v_t 的固定 width 参数
//     按右栏实际宽度传入（本栈无 fill 形态）。

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
/// 处理器卡值行追加温度位:有最热传感器给「· N℃」,来源不可用
/// (hwmon 读不到 / 列表空)给「· —」——空缺会让用户分不清「没数据」
/// 与「还没刷新」;cpu_text 为空(CPU 采样失败)时整体不追加。
fn with_temp(cpu_text : String, hottest : TempSensor?) -> String {
  if cpu_text == "" {
    return ""
  }
  match hottest {
    None => "\{cpu_text} · —"
    Some(t) => "\{cpu_text} · \{t.celsius.to_int()}℃"
  }
}

///|
/// 应用状态：各采样器（持差值前样本）+ 跨页共享 Store。页面函数以 app
/// 单参取用；页内私有状态不进 App。
struct App {
  cpu : CpuMonitor
  proc : ProcMonitor
  disk : DiskMonitor
  net : NetMonitor
  // GPU：占用来源优先级（nvidia-smi > sysfs gpu_busy_percent > DRM
  // fdinfo 聚合）与 fdinfo 前样本差值状态
  gpu : GpuMonitor
  // 概览页：资源卡片值行（标题行右侧，紧凑格式防溢出）
  card_cpu : @core.Store[String]
  card_mem : @core.Store[String]
  card_net : @core.Store[String]
  card_proc : @core.Store[String]
  // 磁盘卡：每个用户挂载一张（数量取启动枚举结果，热插拔不重建）
  card_disk_vals : Array[@core.Store[String]]
  disk_hists : Array[@core.Store[Array[@charts.LineSeries]]]
  // 概览页：实时曲线（定长滚动窗口 120 点 = 2 分钟 @1Hz）
  cpu_hist : @core.Store[Array[@charts.LineSeries]]
  core_bars : @core.Store[Array[@charts.BarItem]]
  mem_hist : @core.Store[Array[@charts.LineSeries]]
  swap_hist : @core.Store[Array[@charts.LineSeries]]
  net_hist : @core.Store[Array[@charts.LineSeries]]
  // GPU 详情页与卡值：每块物理卡一套（数量取启动枚举结果，热插拔不重建）
  card_gpu_vals : Array[@core.Store[String]]
  gpu_busy_hists : Array[@core.Store[Array[@charts.LineSeries]]]
  gpu_vram_hists : Array[@core.Store[Array[@charts.LineSeries]]]
  // 其余页数据源（进程 / 传感器 / 磁盘 / 网络页订阅）
  procs : @core.Store[Array[ProcInfo]]
  sensors : @core.Store[Array[TempSensor]]
  gpus : @core.Store[Array[GpuInfo]]
  disks : @core.Store[Array[DiskInfo]]
  nets : @core.Store[Array[NetInfo]]
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
      @charts.series_push(app.cpu_hist, 0, usage * 100.0)
      let bars : Array[@charts.BarItem] = []
      for i, u in per_core {
        bars.push(@charts.BarItem::make("\{i}", u * 100.0))
      }
      app.core_bars.set(bars)
    }
  }
  match hwmon_sensors() {
    None => cpu_text = with_temp(cpu_text, None)
    Some(sensors) => {
      app.sensors.set(sensors)
      let mut hottest : TempSensor? = None
      for s in sensors {
        match hottest {
          None => hottest = Some(s)
          Some(t) => if s.celsius > t.celsius { hottest = Some(s) }
        }
      }
      cpu_text = with_temp(cpu_text, hottest)
    }
  }
  if cpu_text != "" {
    app.card_cpu.set(cpu_text)
  }
  match mem_info() {
    None => ()
    Some(mem) => {
      let used_gb = mem.used_kb().to_double() / 1048576.0
      let swap_gb = (mem.swap_total_kb - mem.swap_free_kb).to_double() /
        1048576.0
      app.card_mem.set(
        "\{fmt_rate_c(mem.used_kb().to_double() * 1024.0)} / \{fmt_rate_c(mem.total_kb.to_double() * 1024.0)}",
      )
      @charts.series_push(app.mem_hist, 0, used_gb)
      @charts.series_push(app.swap_hist, 0, swap_gb)
    }
  }
  match app.proc.tick() {
    None => ()
    Some(procs) => {
      app.procs.set(procs)
      app.card_proc.set("\{procs.length()}")
    }
  }
  match app.gpu.tick() {
    None => ()
    Some(gpus) => {
      app.gpus.set(gpus)
      // 数量以启动枚举为准，超界（极端热插拔）只跳过，不重建视图
      for i, g in gpus {
        if i >= app.gpu_busy_hists.length() {
          break
        }
        match g.busy {
          Some(b) => @charts.series_push(app.gpu_busy_hists[i], 0, b)
          None => ()
        }
        match g.vram_used {
          Some(v) =>
            @charts.series_push(app.gpu_vram_hists[i], 0, v / 1073741824.0)
          None => ()
        }
        // 占用与温度任一来源不可用,对应位显示「—」(不用空缺)
        let val = match (g.busy, g.celsius) {
          (Some(b), Some(c)) => "\{b.to_int()}% · \{c.to_int()}℃"
          (Some(b), None) => "\{b.to_int()}% · —"
          (None, Some(c)) => "— · \{c.to_int()}℃"
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
      // 数量以启动枚举为准（根分区必在），热插拔只跳过不重建视图
      for i, d in disks {
        if i >= app.disk_hists.length() {
          break
        }
        app.card_disk_vals[i].set(
          "\{pct(d.usage())} · \{fmt_rate_c((d.total_bytes - d.avail_bytes).to_double())}",
        )
        @charts.series_push(app.disk_hists[i], 0, d.usage() * 100.0)
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
      @charts.series_push(app.net_hist, 0, rx)
      @charts.series_push(app.net_hist, 1, tx)
    }
  }
}

///|
const MON_TITLE : String = "系统监视器"

///|
fn main {
  let info = cpu_info().unwrap_or({ model: "(未知)", mhz: 0.0, cores: 1, })
  // 磁盘与 GPU 数量取启动枚举结果，卡与曲线按块预建（热插拔不重建视图）
  let disk_mon = DiskMonitor::new()
  let disks0 : Array[DiskInfo] = match disk_mon.tick() {
    Some(d) => d
    None => []
  }
  let gpu_mon = GpuMonitor::new()
  let gpus0 : Array[GpuInfo] = match gpu_mon.tick() {
    Some(g) => g
    None => []
  }

  let app : App = {
    cpu: CpuMonitor::new(),
    proc: ProcMonitor::new(info.cores),
    disk: disk_mon,
    net: NetMonitor::new(),
    gpu: gpu_mon,
    card_cpu: @core.Store::new("—"),
    card_mem: @core.Store::new("—"),
    card_net: @core.Store::new("—"),
    card_proc: @core.Store::new("—"),
    card_disk_vals: disks0.map(fn(_d) { @core.Store::new("—") }),
    disk_hists: disks0.map(fn(_d) {
      @core.Store::new([@charts.LineSeries::make("已用", max_points=120)])
    }),
    cpu_hist: @core.Store::new([@charts.LineSeries::make("CPU", max_points=120)]),
    core_bars: @core.Store::new([]),
    mem_hist: @core.Store::new([@charts.LineSeries::make("内存", max_points=120)]),
    swap_hist: @core.Store::new([@charts.LineSeries::make("swap", max_points=120)]),
    net_hist: @core.Store::new([
      @charts.LineSeries::make("接收", max_points=120),
      @charts.LineSeries::make("发送", max_points=120),
    ]),
    card_gpu_vals: gpus0.map(fn(_g) { @core.Store::new("—") }),
    gpu_busy_hists: gpus0.map(fn(_g) {
      @core.Store::new([@charts.LineSeries::make("占用", max_points=120)])
    }),
    gpu_vram_hists: gpus0.map(fn(_g) {
      @core.Store::new([@charts.LineSeries::make("显存", max_points=120)])
    }),
    procs: @core.Store::new([]),
    sensors: @core.Store::new([]),
    gpus: @core.Store::new([]),
    disks: @core.Store::new([]),
    nets: @core.Store::new([]),
  }
  // 首帧立即采一次（第二帧起差值速率才有值）；定时与主题跟随在挂载后接
  sample_once(app)
  let mounted = @ui.mount_window(
    [@ui.hbox([app_shell(app)], grow=1.0, padding=6.0)],
    title=MON_TITLE,
    width=1240,
    height=840,
    handle=fn(a : @core.App) {
      println("SYSMON-READY cores=\{info.cores}")
      // 深浅与主色启动跟随系统并实时联动（1s 轮询，指纹变了才 apply）
      ignore(a.follow_system_theme())
      // 单一 1Hz 定时器驱动全部采样
      let tick : Ref[() -> Unit] = Ref(fn() { () })
      tick.val = fn() -> Unit {
        sample_once(app)
        let _ = a.timer(1000, tick.val)
      }
      let _ = a.timer(1000, tick.val)
    },
  )
  match mounted {
    Some(a) => {
      a.run()
      println("SYSMON-DONE")
    }
    None => println("SYSMON-SKIP: 本平台没有窗口后端或没有显示服务")
  }
}
