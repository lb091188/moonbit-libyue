// S4 温度 / S5 磁盘 / S6 GPU / S7 网络（+ F2 statvfs 封装）。
// 全部经 S0 的 read_text_file 与 native-stub 目录枚举读取 /sys、/proc；
// 速率类指标两次采样差值，墙钟经 ffi_monotonic。磁盘 IO 与挂载容量分列：
// IO 取 diskstats 物理盘（mapper 经 /sys/block/dm-*/dm/name + slaves 反查），
// 容量取 /proc/mounts + statvfs（F2）。

// ---------------------------------------------------------------------------
// S4 温度
// ---------------------------------------------------------------------------

///|
/// hwmon 传感器（chip 名 + 标签 + 摄氏度）。
pub(all) struct TempSensor {
  chip : String
  label : String
  celsius : Double
}

///|
/// 毫摄氏度文本 → 摄氏度（可为负：电池等低温传感器）。
pub fn parse_temp_input(text : String) -> Double? {
  match parse_i64(text.trim()) {
    None => None
    Some(milli) => Some(milli.to_double() / 1000.0)
  }
}

///|
/// 从 hwmon 目录条目提取 tempN_input 的 N（升序；忽略 label / crit /
/// max 等旁支条目，编号允许跳号）。
pub fn temp_indices(entries : String) -> Array[Int] {
  let out : Array[Int] = []
  for name in nonempty_lines(entries) {
    if !name.has_prefix("temp") || !name.has_suffix("_input") {
      continue
    }
    let core = name[4:name.length() - 6]
    match parse_u64(core) {
      Some(n) => out.push(n.to_int())
      None => ()
    }
  }
  out.mut_view().sort_by(fn(a, b) { a - b })
  out
}

///|
/// 读全部 hwmon 传感器（/sys/class/hwmon/hwmon*/temp*_input）。
/// 目录不可读（非 Linux）返回 None。
pub fn hwmon_sensors() -> Array[TempSensor]? {
  let chips = match list_dir("/sys/class/hwmon") {
    None => return None
    Some(names) => names
  }
  let out : Array[TempSensor] = []
  for entry in chips {
    if !entry.has_prefix("hwmon") {
      continue
    }
    let base = "/sys/class/hwmon/\{entry}"
    let chip = match read_text_file("\{base}/name") {
      None => entry
      Some(t) => t.trim().to_owned()
    }
    let files = match list_dir(base) {
      None => continue
      Some(names) => names
    }
    for n in temp_indices(files.join("\n")) {
      let celsius = match read_text_file("\{base}/temp\{n}_input") {
        None => continue
        Some(t) =>
          match parse_temp_input(t) {
            None => continue
            Some(c) => c
          }
      }
      let label = match read_text_file("\{base}/temp\{n}_label") {
        None => chip
        Some(t) => {
          let l = t.trim().to_owned()
          if l == "" { chip } else { l }
        }
      }
      out.push({ chip, label, celsius })
    }
  }
  Some(out)
}

// ---------------------------------------------------------------------------
// S5 磁盘
// ---------------------------------------------------------------------------

///|
/// /proc/mounts 行（设备 / 挂载点 / 文件系统类型）。
pub(all) struct MountInfo {
  device : String
  mount : String
  fstype : String
}

///|
/// /proc/diskstats 行（IO 计数，扇区恒为 512 字节）。
pub(all) struct DiskStat {
  name : String
  sectors_read : Int64
  sectors_written : Int64
}

///|
/// 磁盘行：挂载点 + 容量 + IO 速率（bps，两次采样差值）。
pub(all) struct DiskInfo {
  mount : String
  device : String
  fstype : String
  total_bytes : Int64
  free_bytes : Int64
  avail_bytes : Int64
  read_bps : Double
  write_bps : Double
}

///|
/// 容量占用率（0..1，df 口径：已用 = 总 - 可用，可用含保留块）。
pub fn DiskInfo::usage(self : DiskInfo) -> Double {
  if self.total_bytes <= 0 {
    0.0
  } else {
    ((self.total_bytes - self.avail_bytes).to_double() /
    self.total_bytes.to_double()).max(0.0).min(1.0)
  }
}

///|
/// 字节速率（两次采样差值 / 墙钟秒）；首帧（墙钟 ≤ 0）为 0。
pub fn byte_rate(prev : Int64, cur : Int64, wall_s : Double) -> Double {
  if wall_s <= 0.0 {
    0.0
  } else {
    (cur - prev).max(0).to_double() / wall_s
  }
}

///|
/// 扇区速率（×512B/扇区）。
pub fn sector_rate(prev : Int64, cur : Int64, wall_s : Double) -> Double {
  byte_rate(prev, cur, wall_s) * 512.0
}

///|
/// 内核伪文件系统集合（statvfs 无容量意义，容量表跳过）。
fn is_pseudo_fs(fstype : String) -> Bool {
  match fstype {
    "proc" | "sysfs" | "cgroup" | "cgroup2" | "devpts" | "mqueue" |
    "hugetlbfs" | "securityfs" | "pstore" | "bpf" | "configfs" | "debugfs" |
    "tracefs" | "fusectl" | "binfmt_misc" | "autofs" | "rpc_pipefs" |
    "selinuxfs" | "efivarfs" | "nsfs" | "ramfs" | "fuse.gvfsd-fuse" |
    "fusectl2" =>
      true
    _ => false
  }
}

///|
/// 解析 /proc/mounts：只要 /dev/ 开头的真实设备行，跳过伪文件系统。
/// 同一设备多个挂载点（btrfs 子卷 / LVM 快照）由调用方去重。
pub fn parse_mounts(text : String) -> Array[MountInfo] {
  let out : Array[MountInfo] = []
  for line in text.split("\n") {
    let f = split_fields(line)
    if f.length() < 3 {
      continue
    }
    let fstype = f[2].to_owned()
    let device = f[0].to_owned()
    if !device.has_prefix("/dev/") || is_pseudo_fs(fstype) {
      continue
    }
    out.push({ device, mount: f[1].to_owned(), fstype })
  }
  out
}

///|
/// 系统自用挂载点黑名单：/boot、/snap 等用户用不到或无法使用的分区
/// 不进容量列表（前缀按路径段匹配，避免 /bootstrap 之类误伤；
/// /run/media 可移动介质是用户挂载，保留）。
fn is_system_mount(mount : String) -> Bool {
  fn hit(prefix : String) -> Bool {
    mount == prefix || mount.has_prefix("\{prefix}/")
  }
  hit("/boot") ||
  hit("/efi") ||
  hit("/snap") ||
  hit("/var") ||
  hit("/opt") ||
  hit("/srv") ||
  hit("/tmp") ||
  hit("/run/user") ||
  hit("/run/initramfs") ||
  mount == "/run"
}

///|
/// 解析 /proc/diskstats：major minor name 之后取读扇区(5)与写扇区(9)。
/// 行字段不足 14 个跳过；不过滤设备类型（loop/dm 等由调用方处置）。
pub fn parse_diskstats(text : String) -> Array[DiskStat] {
  let out : Array[DiskStat] = []
  for line in text.split("\n") {
    let f = split_fields(line)
    if f.length() < 14 {
      continue
    }
    out.push({
      name: f[2].to_owned(),
      sectors_read: parse_u64(f[5]).unwrap_or(0),
      sectors_written: parse_u64(f[9]).unwrap_or(0),
    })
  }
  out
}

///|
/// statvfs 容量（F2）：返回 (总, 空闲, 可用) 字节。失败返回 None。
pub fn statvfs_info(path : String) -> (Int64, Int64, Int64)? {
  let total = Ref(0L)
  let free = Ref(0L)
  let avail = Ref(0L)
  let err = ffi_statvfs(@utf8.encode(path), total, free, avail)
  if err == 0 {
    Some((total.val, free.val, avail.val))
  } else {
    None
  }
}

///|
/// 磁盘采样器：容量（mounts + statvfs）与 IO 速率（diskstats 差值）
/// 合并为一张表；首帧速率为 0。
pub(all) struct DiskMonitor {
  mut prev : Map[String, (Int64, Int64)]
  mut prev_wall : Double
}

///|
pub fn DiskMonitor::new() -> DiskMonitor {
  { prev: Map([]), prev_wall: 0.0 }
}

///|
/// 采样一次。读取失败返回 None；单个挂载点 statvfs 失败（竞态消失）
/// 跳过该行。
pub fn DiskMonitor::tick(self : DiskMonitor) -> Array[DiskInfo]? {
  let stats_text = match read_text_file("/proc/diskstats") {
    None => return None
    Some(t) => t
  }
  let cur : Map[String, (Int64, Int64)] = Map([])
  for d in parse_diskstats(stats_text) {
    cur.set(d.name, (d.sectors_read, d.sectors_written))
  }
  let mounts_text = match read_text_file("/proc/mounts") {
    None => return None
    Some(t) => t
  }
  let wall = ffi_monotonic()
  let wall_dt = if self.prev_wall > 0.0 {
    wall - self.prev_wall
  } else {
    0.0
  }
  let out : Array[DiskInfo] = []
  let seen : Map[String, Bool] = Map([])
  for m in parse_mounts(mounts_text) {
    // 系统自用挂载（/boot、/snap 等）直接跳过，省一次 statvfs
    if is_system_mount(m.mount) {
      continue
    }
    if seen.contains(m.device) {
      continue
    }
    seen.set(m.device, true)
    let (total, free, avail) = match statvfs_info(m.mount) {
      None => continue
      Some(t) => t
    }
    // 零容量挂载（/dev/fuse 控制节点等伪文件系统）不进列表：没有
    // 容量概念，显示出来只会是 0/0 噪音行
    if total <= 0 {
      continue
    }
    let mut read_bps = 0.0
    let mut write_bps = 0.0
    match diskstats_name(m.device) {
      None => ()
      Some(name) =>
        match (self.prev.get(name), cur.get(name)) {
          (Some(p), Some(c)) => {
            read_bps = sector_rate(p.0, c.0, wall_dt)
            write_bps = sector_rate(p.1, c.1, wall_dt)
          }
          _ => ()
        }
    }
    out.push({
      mount: m.mount,
      device: m.device,
      fstype: m.fstype,
      total_bytes: total,
      free_bytes: free,
      avail_bytes: avail,
      read_bps,
      write_bps,
    })
  }
  self.prev = cur
  self.prev_wall = wall
  Some(out)
}

///|
/// /dev/ 设备名 → diskstats 名：普通设备原名；/dev/mapper/xxx 经
/// /sys/block/dm-*/dm/name 反查 dm-N，再取 slaves 首项（物理盘）。
/// 反查不到返回 None（该行无 IO 归属）。
fn diskstats_name(device : String) -> String? {
  if !device.has_prefix("/dev/") {
    return None
  }
  let rest = device[5:]
  if rest.has_prefix("mapper/") {
    let mapper = rest[7:].to_owned()
    match dm_name_for_mapper(mapper) {
      None => None
      Some(dm) => slave_name(dm)
    }
  } else {
    Some(rest.to_owned())
  }
}

///|
fn dm_name_for_mapper(mapper : String) -> String? {
  let blocks = match list_dir("/sys/block") {
    None => return None
    Some(names) => names
  }
  for entry in blocks {
    if !entry.has_prefix("dm-") {
      continue
    }
    match read_text_file("/sys/block/\{entry}/dm/name") {
      None => ()
      Some(t) =>
        if t.trim().to_owned() == mapper {
          return Some(entry)
        }
    }
  }
  None
}

///|
fn slave_name(dm : String) -> String? {
  match list_dir("/sys/block/\{dm}/slaves") {
    None => None
    Some(names) => {
      let mut first : String? = None
      for name in names {
        if first is None {
          first = Some(name)
        }
      }
      first
    }
  }
}

// ---------------------------------------------------------------------------
// S6 GPU
// ---------------------------------------------------------------------------

///|
/// nvidia-smi 单卡采样结果（占位 / 显存单位换算成字节后存放）。
struct NvmlSample {
  busy : Double
  vram_used : Double
  vram_total : Double
  celsius : Double
  model : String
}

///|
/// 总线地址归一化：取最后一段并去前导零，规避 nvidia-smi 的
/// 00000000:01:00.0 与 sysfs 的 0000:01:00.0 前缀差异。
fn norm_pci(s : String) -> String {
  let parts = s.split(":").collect()
  let tail = parts[parts.length() - 1].to_owned()
  let sb = StringBuilder()
  let mut lead = true
  for c in tail {
    if lead && c == '0' {
      continue
    }
    lead = false
    sb.write_char(c)
  }
  sb.to_string()
}

///|
/// nvidia-smi 批量查询（stub 内 popen，进程内不加载 NVML），按归一化
/// 总线地址建索引；查询失败（无 N 卡 / 未装驱动）返回 None。
fn nvidia_smi_map() -> Map[String, NvmlSample]? {
  let text = match ffi_nvidia_smi() {
    None => return None
    Some(bytes) => @utf8.decode_lossy(bytes)
  }
  let out : Map[String, NvmlSample] = Map([])
  for line in nonempty_lines(text) {
    let f = line.split(",").collect()
    if f.length() < 6 {
      continue
    }
    let busy = match parse_i64(f[1].trim()) {
      Some(v) => v.to_double()
      None => continue
    }
    let used = match parse_i64(f[2].trim()) {
      Some(v) => v.to_double() * 1048576.0
      None => continue
    }
    let total = match parse_i64(f[3].trim()) {
      Some(v) => v.to_double() * 1048576.0
      None => continue
    }
    let temp = match parse_i64(f[4].trim()) {
      Some(v) => v.to_double()
      None => continue
    }
    out.set(norm_pci(f[0].trim().to_owned()), {
      busy,
      vram_used: used,
      vram_total: total,
      celsius: temp,
      model: f[5].trim().to_owned(),
    })
  }
  Some(out)
}

///|
/// 读整行为数值的 sysfs 节点（百分比 / 字节）；失败返回 None。
fn read_u64_file(path : String) -> Double? {
  match read_text_file(path) {
    None => None
    Some(t) =>
      match parse_i64(t.trim()) {
        None => None
        Some(v) => Some(v.to_double())
      }
  }
}

///|
/// PCI 显卡枚举结果（vendor 已语义化；model 为驱动报告名，空串回退
/// device id；busy 0-100；vram_* 单位字节，仅独立显存显卡有值）。
pub(all) struct GpuInfo {
  pci : String
  vendor : String
  device : String
  model : String
  celsius : Double?
  busy : Double?
  vram_used : Double?
  vram_total : Double?
}

///|
/// PCI class 0x03xx 为显示控制器（VGA / 3D / 非 VGA 显示）。
pub fn is_display_class(c : String) -> Bool {
  c.has_prefix("0x03")
}

///|
/// PCI vendor id → 厂商名（未收录的保留原始 id）。
pub fn vendor_name(id : String) -> String {
  match id {
    "0x10de" => "NVIDIA"
    "0x1002" => "AMD"
    "0x8086" => "Intel"
    "0x1a03" => "ASPEED"
    "0x15ad" => "VMware"
    "0x1234" => "QEMU"
    _ => id
  }
}

///|
/// 枚举 PCI 显示设备（/sys/bus/pci/devices class=0x03*）。占用 / 显存 /
/// 温度先试 sysfs 通用节点（amdgpu / nouveau 的 gpu_busy_percent、
/// mem_info_vram_*、hwmon），再 NVML 覆盖（NVIDIA 专有驱动仅有此路，
/// 且附型号名）。目录不可读返回 None。
pub fn gpu_list() -> Array[GpuInfo]? {
  let devs = match list_dir("/sys/bus/pci/devices") {
    None => return None
    Some(names) => names
  }
  let out : Array[GpuInfo] = []
  let smi = nvidia_smi_map()
  for addr in devs {
    let base = "/sys/bus/pci/devices/\{addr}"
    let class = match read_text_file("\{base}/class") {
      None => continue
      Some(t) => t.trim().to_owned()
    }
    if !is_display_class(class) {
      continue
    }
    let vendor = match read_text_file("\{base}/vendor") {
      None => "(未知)".to_string()
      Some(t) => t.trim().to_owned()
    }
    let device = match read_text_file("\{base}/device") {
      None => "(未知)".to_string()
      Some(t) => t.trim().to_owned()
    }
    let mut busy : Double? = read_u64_file("\{base}/gpu_busy_percent")
    let mut vram_used : Double? = read_u64_file("\{base}/mem_info_vram_used")
    let mut vram_total : Double? = read_u64_file("\{base}/mem_info_vram_total")
    let mut celsius : Double? = gpu_hwmon_temp(base)
    let mut model = ""
    match smi {
      Some(m) =>
        match m.get(norm_pci(addr)) {
          Some(n) => {
            busy = Some(n.busy)
            vram_used = Some(n.vram_used)
            vram_total = Some(n.vram_total)
            celsius = Some(n.celsius)
            model = n.model
          }
          None => ()
        }
      None => ()
    }
    out.push({
      pci: addr,
      vendor: vendor_name(vendor),
      device,
      model,
      celsius,
      busy,
      vram_used,
      vram_total,
    })
  }
  Some(out)
}

///|
fn gpu_hwmon_temp(base : String) -> Double? {
  let hwmons = match list_dir("\{base}/hwmon") {
    None => return None
    Some(names) => names
  }
  for entry in hwmons {
    if !entry.has_prefix("hwmon") {
      continue
    }
    match read_text_file("\{base}/hwmon/\{entry}/temp1_input") {
      None => ()
      Some(t) =>
        match parse_temp_input(t) {
          None => ()
          Some(c) => return Some(c)
        }
    }
  }
  None
}

// ---------------------------------------------------------------------------
// S7 网络
// ---------------------------------------------------------------------------

///|
/// 网卡快照：累计字节 + 采样差值速率。
pub(all) struct NetInfo {
  name : String
  rx_bytes : Int64
  tx_bytes : Int64
  rx_bps : Double
  tx_bps : Double
}

///|
/// 网络采样器：/sys/class/net/*/statistics 的 rx/tx 字节累计值差值。
pub(all) struct NetMonitor {
  mut prev : Map[String, (Int64, Int64)]
  mut prev_wall : Double
}

///|
pub fn NetMonitor::new() -> NetMonitor {
  { prev: Map([]), prev_wall: 0.0 }
}

///|
/// 采样一次。目录不可读（非 Linux）返回 None；单网卡读取失败跳过。
pub fn NetMonitor::tick(self : NetMonitor) -> Array[NetInfo]? {
  let names = match list_dir("/sys/class/net") {
    None => return None
    Some(names) => names
  }
  let wall = ffi_monotonic()
  let wall_dt = if self.prev_wall > 0.0 {
    wall - self.prev_wall
  } else {
    0.0
  }
  let out : Array[NetInfo] = []
  let cur : Map[String, (Int64, Int64)] = Map([])
  for name in names {
    let rx = match read_text_file("/sys/class/net/\{name}/statistics/rx_bytes") {
      None => continue
      Some(t) => parse_u64(t.trim()).unwrap_or(0)
    }
    let tx = match read_text_file("/sys/class/net/\{name}/statistics/tx_bytes") {
      None => continue
      Some(t) => parse_u64(t.trim()).unwrap_or(0)
    }
    let mut rx_bps = 0.0
    let mut tx_bps = 0.0
    match self.prev.get(name) {
      None => ()
      Some(p) => {
        rx_bps = byte_rate(p.0, rx, wall_dt)
        tx_bps = byte_rate(p.1, tx, wall_dt)
      }
    }
    out.push({ name, rx_bytes: rx, tx_bytes: tx, rx_bps, tx_bps })
    cur.set(name, (rx, tx))
  }
  self.prev = cur
  self.prev_wall = wall
  Some(out)
}
