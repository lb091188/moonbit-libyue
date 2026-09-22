// S3 进程数据层 + F1 进程管理。
// S3：/proc/[pid]/{stat,cmdline} 纯函数解析 + 差值采样器（CPU% = 两次
// 采样 utime+stime 增量 / 墙钟增量）；RSS 取 stat 的页数 × 页大小，与
// status 的 VmRSS 等值，省掉每进程第三次读取。
// F1：kill / getpriority / setpriority 经应用 native-stub，errno 语义化
// 为 Result；Windows 侧 stub 返回「不支持」哨兵，封装层统一降级文案。

///|
/// /proc/[pid]/stat 解析结果（时间为 tick，见 ProcMonitor 的 clk_tck）。
pub(all) struct ProcStat {
  pid : Int
  comm : String
  state : String
  ppid : Int
  utime : Int64
  stime : Int64
  nice : Int
  threads : Int
  start_time : Int64
  rss_pages : Int64
}

///|
/// 进程快照（采样器输出，cpu_pct 为两次采样差值）。
pub(all) struct ProcInfo {
  pid : Int
  ppid : Int
  name : String
  cmd : String
  state : String
  nice : Int
  threads : Int
  rss_kb : Int64
  cpu_pct : Double
}

///|
/// 最后一次 ')' 的下标；不存在返回 -1。/proc/[pid]/stat 的 comm 可含
/// 空格与括号（进程名 "(foo (bar))"），只能按最后一个 ')' 切分。
fn last_paren(text : String) -> Int {
  let n = text.length()
  let mut i = n - 1
  while i >= 0 {
    if text.unsafe_get(i).to_int() == 41 {
      return i
    }
    i -= 1
  }
  -1
}

///|
/// 解析 /proc/[pid]/stat。comm 后的字段序号（从 state 起 0 基）：
/// state=0 ppid=1 utime=11 stime=12 nice=16 threads=17 starttime=19
/// rss=21；字段不足 22 个或 pid 非法返回 None。
pub fn parse_proc_pid_stat(text : String) -> ProcStat? {
  let open = match text.find("(") {
    Some(i) => i
    None => return None
  }
  let close = last_paren(text)
  if close < 0 || close <= open {
    return None
  }
  let pid = match parse_u64(text[:open].trim()) {
    Some(p) => p.to_int()
    None => return None
  }
  let comm = text[open + 1:close].to_owned()
  let f = split_fields(text[close + 1:])
  if f.length() < 22 {
    return None
  }
  fn num(i : Int) -> Int64 {
    parse_u64(f[i]).unwrap_or(0)
  }

  fn num_s(i : Int) -> Int {
    parse_u64(f[i]).unwrap_or(0).to_int()
  }

  Some({
    pid,
    comm,
    state: f[0].to_owned(),
    ppid: num_s(1),
    utime: num(11),
    stime: num(12),
    nice: num_s(16),
    threads: num_s(17),
    start_time: num(19),
    rss_pages: num(21),
  })
}

///|
/// 解析 /proc/[pid]/cmdline：参数以 NUL 分隔，替换为空格并去首尾空白；
/// 空结果（内核线程 / 权限不足）由调用方回退到 [comm]。
pub fn parse_cmdline(text : String) -> String {
  let sb = StringBuilder()
  for c in text.iter() {
    sb.write_char(if c == '\u{0}' { ' ' } else { c })
  }
  sb.to_string().trim().to_owned()
}

///|
/// 进程 CPU% = Δ(utime+stime) / clk_tck / 墙钟秒 × 100。首次采样
/// （墙钟增量 ≤ 0）返回 0；多线程进程可超过单核 100%，按 cores × 100
/// 钳制。prev/cur 为 utime+stime 的 tick 累计值。
pub fn proc_cpu_pct(
  prev : Int64,
  cur : Int64,
  clk_tck : Int,
  wall_s : Double,
  cores : Int,
) -> Double {
  if clk_tck <= 0 || wall_s <= 0.0 {
    return 0.0
  }
  let dticks = (cur - prev).max(0).to_double()
  let cap = (cores.max(1) * 100).to_double()
  (dticks / clk_tck.to_double() / wall_s * 100.0).max(0.0).min(cap)
}

///|
/// ppid → 子进程 pid 列表（只收列表中出现的 pid，按 pid 升序）。
pub fn proc_children(procs : Array[ProcInfo]) -> Map[Int, Array[Int]] {
  let by_pid : Map[Int, Bool] = Map([])
  for p in procs {
    by_pid.set(p.pid, true)
  }
  let out : Map[Int, Array[Int]] = Map([])
  for p in procs {
    if p.ppid == p.pid || !by_pid.contains(p.ppid) {
      continue
    }
    match out.get(p.ppid) {
      Some(children) => children.push(p.pid)
      None => out.set(p.ppid, [p.pid])
    }
  }
  for _ppid, children in out {
    children.mut_view().sort_by(fn(a, b) { a - b })
  }
  out
}

///|
/// 进程采样器：持前一次各进程 tick 累计与墙钟，每次 [tick] 全量刷新。
/// 首次采样所有进程 cpu_pct 为 0（无前样本），第二次起为真实差值。
pub(all) struct ProcMonitor {
  mut prev : Map[Int, Int64]
  mut prev_wall : Double
  clk_tck : Int
  page_kb : Int
  cores : Int
}

///|
pub fn ProcMonitor::new(cores : Int) -> ProcMonitor {
  {
    prev: {},
    prev_wall: 0.0,
    clk_tck: ffi_clk_tck(),
    page_kb: ffi_page_size() / 1024,
    cores,
  }
}

///|
/// 采样一次：枚举 /proc pid，逐进程读 stat + cmdline，算差值 CPU%。
/// 读取失败（进程在枚举与读取间退出）跳过该进程；平台不支持
/// （Windows）返回 None。
pub fn ProcMonitor::tick(self : ProcMonitor) -> Array[ProcInfo]? {
  let listed = match ffi_list_pids() {
    None => return None
    Some(bytes) => @utf8.decode_lossy(bytes)
  }
  let pids : Array[Int] = []
  for line in listed.split("\n") {
    match parse_u64(line.trim()) {
      Some(p) => pids.push(p.to_int())
      None => ()
    }
  }
  let wall = ffi_monotonic()
  let wall_dt = if self.prev_wall > 0.0 {
    wall - self.prev_wall
  } else {
    0.0
  }
  let out : Array[ProcInfo] = []
  let cur : Map[Int, Int64] = Map([])
  for pid in pids {
    let stat_text = match read_text_file("/proc/\{pid}/stat") {
      None => continue
      Some(t) => t
    }
    let st = match parse_proc_pid_stat(stat_text) {
      None => continue
      Some(s) => s
    }
    let ticks = st.utime + st.stime
    let cmdline = match read_text_file("/proc/\{pid}/cmdline") {
      None => ""
      Some(t) => parse_cmdline(t)
    }
    let cpu_pct = if wall_dt > 0.0 {
      let prev = self.prev.get(pid).unwrap_or(0)
      proc_cpu_pct(prev, ticks, self.clk_tck, wall_dt, self.cores)
    } else {
      0.0
    }
    out.push({
      pid: st.pid,
      ppid: st.ppid,
      name: st.comm,
      cmd: if cmdline == "" { "[\{st.comm}]" } else { cmdline },
      state: st.state,
      nice: st.nice,
      threads: st.threads,
      rss_kb: st.rss_pages * self.page_kb.to_int64(),
      cpu_pct,
    })
    cur.set(pid, ticks)
  }
  self.prev = cur
  self.prev_wall = wall
  // 目录序不保证有序，按 pid 升序给稳定初始序（列头排序在 UI 层）
  out.mut_view().sort_by(fn(a, b) { a.pid - b.pid })
  Some(out)
}

// ---------------------------------------------------------------------------
// F1 进程管理（errno → Result 语义化）
// ---------------------------------------------------------------------------

///|
/// SIGTERM（可被捕获的终止请求，kill 首选）。
pub const SIGTERM : Int = 15

///|
/// SIGKILL（不可捕获的强杀，SIGTERM 失败后的兜底）。
pub const SIGKILL : Int = 9

///|
/// errno → 中文语义（Linux errno 编号；应用仅面向 Ubuntu，硬编码可接受）。
pub fn errno_text(err : Int) -> String {
  if err == -1000 {
    return "当前平台不支持(仅 Linux)"
  }
  match err {
    1 => "权限不足(EPERM:非属主且非 root)"
    3 => "进程不存在或已退出(ESRCH)"
    13 => "权限不足(EACCES)"
    22 => "参数非法(EINVAL:nice 需在 -20..19)"
    _ => "系统调用失败(errno \{err})"
  }
}

///|
/// 发信号（SIGTERM / SIGKILL）。
pub fn kill_signal(pid : Int, sig : Int) -> Result[Unit, String] {
  let err = ffi_kill(pid, sig)
  if err == 0 {
    Ok(())
  } else {
    Err(errno_text(err))
  }
}

///|
/// 读进程 nice 值（-20..19）。
pub fn get_priority(pid : Int) -> Result[Int, String] {
  let out = Ref(0)
  let err = ffi_get_priority(pid, out)
  if err == 0 {
    Ok(out.val)
  } else {
    Err(errno_text(err))
  }
}

///|
/// 设进程 nice 值（-20..19，越大越谦让）。
pub fn set_priority(pid : Int, nice : Int) -> Result[Unit, String] {
  if nice < -20 || nice > 19 {
    return Err(errno_text(22))
  }
  let err = ffi_set_priority(pid, nice)
  if err == 0 {
    Ok(())
  } else {
    Err(errno_text(err))
  }
}
