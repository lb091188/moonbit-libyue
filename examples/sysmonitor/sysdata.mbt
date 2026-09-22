// 监控数据层（S0-S2）：纯 MoonBit 读 /proc 文本并解析为结构化数据。
// 唯一的系统调用是文件读取（S0，经应用 native-stub，见 sysffi.mbt）；
// 字段切分、数值解析、差值占用率全部为纯函数，白盒测试直接喂字面量。
// 后续批次在此文件续写 S3 进程 / S4-S7 硬件（sysproc.mbt / syshw.mbt）。

// ---------------------------------------------------------------------------
// S0 文本读取入口
// ---------------------------------------------------------------------------

///|
/// 读整个文本文件为字符串；失败（不存在 / 权限 / 超限 / 是目录）返回
/// None。/proc、/sys 伪文件 stat 尺寸为 0，读取循环在 native-stub 内。
pub fn read_text_file(path : String) -> String? {
  match ffi_read_text_file(@utf8.encode(path)) {
    None => None
    Some(bytes) => Some(@utf8.decode_lossy(bytes))
  }
}

// ---------------------------------------------------------------------------
// 解析原语（纯函数）
// ---------------------------------------------------------------------------

///|
/// ASCII 空白切分（空格 / 制表 / 换行 / 回车，连续空白视为一个分隔，
/// 跳过首尾空白）。面向 /proc、/sys 的 ASCII 数值行；含非 ASCII 的文本
/// （如 cmdline）不走此函数。
pub fn split_fields(s : StringView) -> Array[StringView] {
  let out : Array[StringView] = []
  let mut start = -1
  for i, c in s.iter2() {
    if is_ws(c) {
      if start >= 0 {
        out.push(s.sub(start=start, end=i))
        start = -1
      }
    } else if start < 0 {
      start = i
    }
  }
  if start >= 0 {
    out.push(s.sub(start=start))
  }
  out
}

///|
fn is_ws(c : Char) -> Bool {
  let n = c.to_int()
  n == 32 || n == 9 || n == 10 || n == 13
}

///|
/// 解析无符号十进制整数（/proc、/sys 数值字段）。空串 / 含非数字返回
/// None；溢出按 Int64 回绕（内核计数远小于 2^63，不设防）。
pub fn parse_u64(s : StringView) -> Int64? {
  let mut acc : Int64 = 0
  let mut any = false
  for c in s.iter() {
    let n = c.to_int()
    if n < 48 || n > 57 {
      return None
    }
    acc = acc * 10 + (n - 48).to_int64()
    any = true
  }
  if any {
    Some(acc)
  } else {
    None
  }
}

///|
/// 解析十进制小数（支持负号与前导小数点；cpu MHz 等字段）。空串 /
/// 格式非法（如 "1.2.3"）返回 None。
pub fn parse_double(s : StringView) -> Double? {
  let n = s.char_length()
  let mut i = 0
  let mut neg = false
  if i < n && s.unsafe_get(0).to_int() == 45 {
    neg = true
    i += 1
  }
  let mut ip : Int64 = 0
  let mut any = false
  while i < n {
    let c = s.unsafe_get(i).to_int()
    if c < 48 || c > 57 {
      break
    }
    ip = ip * 10 + (c - 48).to_int64()
    any = true
    i += 1
  }
  let mut fp = 0.0
  if i < n && s.unsafe_get(i).to_int() == 46 {
    i += 1
    let mut scale = 0.1
    while i < n {
      let c = s.unsafe_get(i).to_int()
      if c < 48 || c > 57 {
        break
      }
      fp = fp + (c - 48).to_double() * scale
      scale = scale * 0.1
      any = true
      i += 1
    }
  }
  if !any || i != n {
    None
  } else {
    let v = ip.to_double() + fp
    Some(if neg { -v } else { v })
  }
}

// ---------------------------------------------------------------------------
// S1 CPU
// ---------------------------------------------------------------------------

///|
/// /proc/stat 的 CPU 时间片，单位 USER_HZ（内核配置，通常 100 = 10ms）。
pub(all) struct CpuTimes {
  user : Int64
  nice : Int64
  system : Int64
  idle : Int64
  iowait : Int64
  irq : Int64
  softirq : Int64
  steal : Int64
}

///|
/// 总时间片（guest 已由内核计入 user/nice，不重复累加）。
pub fn CpuTimes::total(self : CpuTimes) -> Int64 {
  self.user + self.nice + self.system + self.idle + self.iowait + self.irq +
  self.softirq +
  self.steal
}

///|
/// 忙时间片 = 总 - 空闲 - IO 等待（iowait 不计入 CPU 占用）。
pub fn CpuTimes::busy(self : CpuTimes) -> Int64 {
  self.total() - self.idle - self.iowait
}

///|
/// /proc/cpuinfo 摘要：型号 / 主频(MHz) / 逻辑核数。无 processor 行
/// （非 Linux 内核文本）返回 None。
pub(all) struct CpuInfo {
  model : String
  mhz : Double
  cores : Int
}

///|
/// 解析 /proc/stat，返回 (总体, 各核按 cpu0..N 顺序)。无 cpu 总行返回
/// None；单行字段短缺位补 0（旧内核缺 steal 等）；两次采样差值算占用
/// 率见 [cpu_usage]。首帧以全零为前样本时，结果为开机至今均值。
pub fn parse_proc_stat(text : String) -> (CpuTimes, Array[CpuTimes])? {
  let mut total : CpuTimes? = None
  let cores : Array[CpuTimes] = []
  for line in text.split("\n") {
    let f = split_fields(line)
    if f.length() == 0 {
      continue
    }
    let tag = f[0]
    if tag.char_length() >= 3 && tag.sub(start=0, end=3).equal_to_string("cpu") {
      let t = cpu_line_times(f)
      if tag.char_length() == 3 {
        total = Some(t)
      } else {
        cores.push(t)
      }
    }
  }
  match total {
    None => None
    Some(t) => Some((t, cores))
  }
}

///|
fn cpu_line_times(f : Array[StringView]) -> CpuTimes {
  fn at(i : Int) -> Int64 {
    if i < f.length() {
      parse_u64(f[i]).unwrap_or(0)
    } else {
      0
    }
  }

  {
    user: at(1),
    nice: at(2),
    system: at(3),
    idle: at(4),
    iowait: at(5),
    irq: at(6),
    softirq: at(7),
    steal: at(8),
  }
}

///|
/// 两次采样的占用率（0..1）。总增量 ≤ 0（采样间隔短于一个 tick）时
/// 返回 0；忙增量按总增量钳制，避免计数回绕时越界。
pub fn cpu_usage(prev : CpuTimes, cur : CpuTimes) -> Double {
  let dt = (cur.total() - prev.total()).to_double()
  let db = (cur.busy() - prev.busy()).to_double()
  if dt <= 0.0 {
    0.0
  } else {
    (db / dt).max(0.0).min(1.0)
  }
}

///|
/// 解析 /proc/cpuinfo。型号优先 model name，缺失回退 Processor /
/// Hardware（ARM 开发板）；主频取 cpu MHz，缺失为 0；核数为 processor
/// 行计数（逻辑 CPU 数，含超线程）。
pub fn parse_cpuinfo(text : String) -> CpuInfo? {
  let mut model = ""
  let mut mhz = 0.0
  let mut cores = 0
  for line in text.split("\n") {
    let (key, value) = match line.split_once(":") {
      Some((k, v)) => (k, v)
      None => continue
    }
    let k = key.trim()
    let v = value.trim()
    if k.equal_to_string("model name") {
      model = v.to_owned()
    } else if k.equal_to_string("Processor") && model == "" {
      model = v.to_owned()
    } else if k.equal_to_string("Hardware") && model == "" {
      model = v.to_owned()
    } else if k.equal_to_string("cpu MHz") {
      match parse_double(v) {
        Some(m) => mhz = m
        None => ()
      }
    } else if k.equal_to_string("processor") {
      cores += 1
    }
  }
  if cores == 0 {
    None
  } else {
    Some({ model, mhz, cores })
  }
}

// ---------------------------------------------------------------------------
// S2 内存
// ---------------------------------------------------------------------------

///|
/// /proc/meminfo 摘要，单位 kB。MemAvailable 缺失（内核 < 3.14）时回退
/// MemFree；Swap 行缺失按 0。
pub(all) struct MemInfo {
  total_kb : Int64
  available_kb : Int64
  swap_total_kb : Int64
  swap_free_kb : Int64
}

///|
/// 已用 = 总 - 可用（内核可用口径，含可回收的缓存）。
pub fn MemInfo::used_kb(self : MemInfo) -> Int64 {
  self.total_kb - self.available_kb
}

///|
/// 内存占用率（0..1）；总为 0 时返回 0。
pub fn MemInfo::usage(self : MemInfo) -> Double {
  if self.total_kb <= 0 {
    0.0
  } else {
    (self.used_kb().to_double() / self.total_kb.to_double()).max(0.0).min(1.0)
  }
}

///|
/// swap 占用率（0..1）；无 swap（总量 0）时返回 0。
pub fn MemInfo::swap_usage(self : MemInfo) -> Double {
  if self.swap_total_kb <= 0 {
    0.0
  } else {
    ((self.swap_total_kb - self.swap_free_kb).to_double() /
    self.swap_total_kb.to_double()).max(0.0).min(1.0)
  }
}

///|
/// 解析 /proc/meminfo。缺 MemTotal 行返回 None。
pub fn parse_meminfo(text : String) -> MemInfo? {  let mut total : Int64? = None
  let mut free : Int64? = None
  let mut avail : Int64? = None
  let mut swap_total : Int64? = None
  let mut swap_free : Int64? = None
  for line in text.split("\n") {
    let f = split_fields(line)
    if f.length() < 2 {
      continue
    }
    let v = parse_u64(f[1])
    let name = f[0]
    if name.equal_to_string("MemTotal:") {
      total = v
    } else if name.equal_to_string("MemFree:") {
      free = v
    } else if name.equal_to_string("MemAvailable:") {
      avail = v
    } else if name.equal_to_string("SwapTotal:") {
      swap_total = v
    } else if name.equal_to_string("SwapFree:") {
      swap_free = v
    }
  }
  match total {
    None => None
    Some(t) => {
      // MemAvailable 缺失（老内核）回退 MemFree
      let avail_kb = match avail {
        Some(a) => a
        None => free.unwrap_or(0)
      }
      Some({
        total_kb: t,
        available_kb: avail_kb,
        swap_total_kb: swap_total.unwrap_or(0),
        swap_free_kb: swap_free.unwrap_or(0),
      })
    }
  }
}

// ---------------------------------------------------------------------------
// 采样入口（IO 薄封装 + 差值状态）
// ---------------------------------------------------------------------------

///|
fn zero_times() -> CpuTimes {
  {
    user: 0,
    nice: 0,
    system: 0,
    idle: 0,
    iowait: 0,
    irq: 0,
    softirq: 0,
    steal: 0,
  }
}

///|
/// CPU 占用率采样器：持前一次 /proc/stat 时间片，每次 [tick] 做两次
/// 采样差值。首帧前样本为全零，结果为开机至今均值。
pub(all) struct CpuMonitor {
  mut prev : CpuTimes
  mut prev_cores : Array[CpuTimes]
  mut cores : Int
}

///|
pub fn CpuMonitor::new() -> CpuMonitor {
  { prev: zero_times(), prev_cores: [], cores: 0 }
}

///|
/// 采样一次：返回 (总占用率, 各核占用率)。读取 / 解析失败返回 None
/// 并保留前样本（下次 tick 重试）。各核数与静态核数不一致时（CPU
/// 热插拔）以本次为准。
pub fn CpuMonitor::tick(self : CpuMonitor) -> (Double, Array[Double])? {
  match read_text_file("/proc/stat") {
    None => None
    Some(text) =>
      match parse_proc_stat(text) {
        None => None
        Some((total, cores)) => {
          let usage = cpu_usage(self.prev, total)
          let per_core : Array[Double] = []
          for i in 0..<cores.length() {
            let p = if i < self.prev_cores.length() {
              self.prev_cores[i]
            } else {
              zero_times()
            }
            per_core.push(cpu_usage(p, cores[i]))
          }
          self.prev = total
          self.prev_cores = cores
          self.cores = cores.length()
          Some((usage, per_core))
        }
      }
  }
}

///|
/// 读 /proc/cpuinfo 静态信息（型号 / 主频 / 逻辑核数）。
pub fn cpu_info() -> CpuInfo? {
  match read_text_file("/proc/cpuinfo") {
    None => None
    Some(text) => parse_cpuinfo(text)
  }
}

///|
/// 读 /proc/meminfo 内存与 swap 摘要。
pub fn mem_info() -> MemInfo? {
  match read_text_file("/proc/meminfo") {
    None => None
    Some(text) => parse_meminfo(text)
  }
}
