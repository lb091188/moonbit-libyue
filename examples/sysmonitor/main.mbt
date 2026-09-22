// sysmonitor：Ubuntu 进程管理与硬件信息查看（示例应用）。
// 数据层纯 MoonBit 读 /proc、/sys（sysdata.mbt / sysproc.mbt / syshw.mbt），
// 唯一的系统调用经应用自有 native-stub（stub/sysmon.c，sysffi.mbt）；
// 刷新走 set_timer，UI 只用 yue 统一 API。
// 当前批次（S0-S2）：CPU 总占用 + 各核、内存与 swap 的 1Hz 采样，
// 标签实时刷新；后续批次替换为 tabs_t 五页结构。

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
fn pct(v : Double) -> String {
  "\{(v * 100.0).to_int()}%"
}

///|
fn main {
  if !@yue.initialize() {
    return
  }
  let monitor = CpuMonitor::new()
  let info = cpu_info().unwrap_or({ model: "(未知)", mhz: 0.0, cores: 0 })
  // 采样值放 Store，标签订阅后随采样刷新（只改文本，不重建视图树）
  let cpu_text : @yue.Store[String] = @yue.Store::new("CPU 采样中…")
  let mem_text : @yue.Store[String] = @yue.Store::new("内存采样中…")

  let window = @yue.mount_window(
    [
      @yue.vbox(
        [
          @yue.label_t(
            "sysmonitor · Ubuntu 进程管理与硬件信息查看",
            role=@yue.Section,
          ),
          @yue.label_t(
            "\{info.model} · \{info.cores} 逻辑核 · \{info.mhz} MHz",
            role=@yue.Secondary,
          ),
          @yue.separator(style=[("marginTop", 8.0), ("marginBottom", 8.0)]),
          @yue.label_t(cpu_text.get(), handle=fn(l) {
            cpu_text.subscribe(fn(t) { l.set_text(t) })
          }),
          @yue.label_t(mem_text.get(), handle=fn(l) {
            mem_text.subscribe(fn(t) { l.set_text(t) })
          }),
          @yue.label_t(
            "1Hz 定时采样：/proc/stat 两次差值算占用率，/proc/meminfo 直读。",
            role=@yue.Secondary,
          ),
        ],
        style=[("padding", 16.0)],
        style_str=[("alignItems", "stretch")],
      ),
    ],
    title="sysmonitor",
    size=Some((520.0, 220.0)),
  )

  ignore(
    @yue.set_timer(1000, fn() {
      match monitor.tick() {
        None => cpu_text.set("CPU 读取失败（/proc/stat）")
        Some((usage, per_core)) => {
          let per = per_core.map(fn(u) { pct(u) })
          cpu_text.set(
            "CPU 总占用 \{pct(usage)} · 各核 [\{per.join(", ")}]",
          )
        }
      }
      match mem_info() {
        None => mem_text.set("内存读取失败（/proc/meminfo）")
        Some(mem) =>
          mem_text.set(
            "内存 \{fmt_kb(mem.used_kb())} / \{fmt_kb(mem.total_kb)} (\{pct(mem.usage())}) · swap \{fmt_kb(mem.swap_total_kb - mem.swap_free_kb)} / \{fmt_kb(mem.swap_total_kb)} (\{pct(mem.swap_usage())})",
          )
      }
      true
    }),
  )
  ignore(window)
  @yue.run()
}
