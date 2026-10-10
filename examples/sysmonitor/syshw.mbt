// S4 温度 / S5 磁盘 / S6 GPU / S7 网络（+ F2 statvfs 封装）。
// 全部经 S0 的 read_text_file 与 native-stub 目录枚举读取 /sys、/proc；
// 速率类指标两次采样差值，墙钟经 ffi_monotonic。磁盘 IO 与挂载容量分列：
// IO 取 diskstats 物理盘（mapper 经 /sys/block/dm-*/dm/name + slaves 反查），
// 容量取 /proc/mounts + statvfs（F2）。
// 平台路由（SYS3）：macOS 由 stub 把 getfsstat / getifaddrs 虚拟成同构
// /proc/mounts、/sys/class/net（挂载点空格按 \040 转义，此处还原），CPU /
// 内存 / 进程同样虚拟 /proc；磁盘 IO 与温度无来源（IOKit / SMC 列远期），
// 速率字段为 None、UI 显示「—」；GPU 走 system_profiler -json 子进程，
// JSON 解析是本文件的纯函数（parse_system_profiler_gpu）。
// GPU 占用来源（SYS4，Linux）：nvidia-smi（N 卡）> sysfs
// gpu_busy_percent（amdgpu，免 root）> DRM fdinfo 聚合（i915 / xe /
// amdgpu 兜底：/proc/<pid>/fdinfo 的 drm-engine-* 按 drm-client-id
// 归并、差值 / 墙钟折算全卡利用率，免 root）；前样本差值状态在
// GpuMonitor。
// GPU 型号名（SYS5，Linux）：nvidia-smi 命中优先；否则 pci.ids
// （/usr/share/hwdata 或 /usr/share/misc，免 root 纯文本）按
// vendor:device 查商业型号名（AMD / Intel 的型号名不在任何 sysfs
// 节点中），查不到回退 device id 原文；pci.ids 文本与解析结果在
// GpuMonitor 常驻（静态硬件信息，首拍查一次）。

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
          if l == "" {
            chip
          } else {
            l
          }
        }
      }
      out.push({ chip, label, celsius, })
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
/// 速率为 None 表示来源不可用：macOS 无等价 diskstats（IOKit 列远期）、
/// Windows 上卷打不开 / IOCTL 不支持（光驱 / 无介质）、挂载点归属不到
/// diskstats 条目（如 NFS）、首帧无前样本——UI 一律显示「—」。
pub(all) struct DiskInfo {
  mount : String
  device : String
  fstype : String
  total_bytes : Int64
  free_bytes : Int64
  avail_bytes : Int64
  read_bps : Double?
  write_bps : Double?
}

///|
/// 容量占用率（0..1，df 口径：已用 = 总 - 可用，可用含保留块）。
pub fn DiskInfo::usage(self : DiskInfo) -> Double {
  if self.total_bytes <= 0 {
    0.0
  } else {
    ((self.total_bytes - self.avail_bytes).to_double() /
    self.total_bytes.to_double())
    .max(0.0)
    .min(1.0)
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
/// 内核伪文件系统集合（statvfs 无容量意义，容量表跳过）。Linux 与 BSD
/// （macOS getfsstat 的 f_fstypename）两份名单合并：Linux 侧原有过滤
/// 不变，BSD 侧补 devfs / fdesc / nullfs / volfs / union / synth
/// （autofs 两平台同名）。
fn is_pseudo_fs(fstype : String) -> Bool {
  match fstype {
    "proc"
    | "sysfs"
    | "cgroup"
    | "cgroup2"
    | "devpts"
    | "mqueue"
    | "hugetlbfs"
    | "securityfs"
    | "pstore"
    | "bpf"
    | "configfs"
    | "debugfs"
    | "tracefs"
    | "fusectl"
    | "binfmt_misc"
    | "autofs"
    | "rpc_pipefs"
    | "selinuxfs"
    | "efivarfs"
    | "nsfs"
    | "ramfs"
    | "fuse.gvfsd-fuse"
    | "fusectl2"
    | "devfs"
    | "fdesc"
    | "nullfs"
    | "volfs"
    | "union"
    | "synth" => true
    _ => false
  }
}

///|
/// /proc/mounts 八进制转义还原（\040 空格 / \011 制表 / \012 换行 /
/// \134 反斜杠，内核同惯例；其余反斜杠序列原样保留）。stub 对 macOS
/// getfsstat 的挂载点与设备名同样转义——用户卷名可含空格，不还原会
/// 按空白切错列、statvfs 失败后整行消失。未转义区间成段拷贝（代理对
/// 安全），只对转义序列逐字符处理。
pub fn unescape_mount(s : StringView) -> String {
  let sb = StringBuilder()
  let n = s.char_length()
  let mut i = 0
  let mut run = 0
  while i < n {
    // 92 = 反斜杠；stub 只产出 \040 / \011 / \012 / \134
    if s.unsafe_get(i).to_int() == 92 && i + 4 <= n {
      let esc = s.exact_view(start=i, end=i + 4).to_owned()
      let ch = if esc == "\\040" {
        Some(' ')
      } else if esc == "\\011" {
        Some('\t')
      } else if esc == "\\012" {
        Some('\n')
      } else if esc == "\\134" {
        Some('\\')
      } else {
        None
      }
      match ch {
        Some(c) => {
          sb.write_stringview(s.exact_view(start=run, end=i))
          sb.write_char(c)
          i += 4
          run = i
          continue
        }
        None => ()
      }
    }
    i += 1
  }
  sb.write_stringview(s.exact_view(start=run))
  sb.to_string()
}

///|
/// 解析 /proc/mounts：只要 /dev/ 开头的真实设备行，跳过伪文件系统。
/// 同一设备多个挂载点（btrfs 子卷 / LVM 快照）由调用方去重。设备与
/// 挂载点按内核惯例做八进制转义还原（见 [unescape_mount]）。
pub fn parse_mounts(text : String) -> Array[MountInfo] {
  let out : Array[MountInfo] = []
  for line in text.split("\n") {
    let f = split_fields(line)
    if f.length() < 3 {
      continue
    }
    let fstype = f[2].to_owned()
    let device = unescape_mount(f[0])
    if !device.has_prefix("/dev/") || is_pseudo_fs(fstype) {
      continue
    }
    out.push({ device, mount: unescape_mount(f[1]), fstype, })
  }
  out
}

///|
/// 系统自用挂载点黑名单：/boot、/snap 等用户用不到或无法使用的分区
/// 不进容量列表（前缀按路径段匹配，避免 /bootstrap 之类误伤；
/// /run/media 可移动介质是用户挂载，保留）。macOS 侧补系统宗卷：
/// /private（swap 后备卷 /private/var/vm）与 /System/Volumes 下的
/// Preboot / Update / VM / Hardware / iSCPreboot；/System/Volumes/Data
/// 是用户数据卷（"Macintosh HD"），保留。
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
  mount == "/run" ||
  hit("/private") ||
  hit("/System/Volumes/Preboot") ||
  hit("/System/Volumes/Update") ||
  hit("/System/Volumes/VM") ||
  hit("/System/Volumes/Hardware") ||
  hit("/System/Volumes/iSCPreboot")
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
/// 合并为一张表；首帧速率为 None（无前样本）。
pub(all) struct DiskMonitor {
  mut prev : Map[String, (Int64, Int64)]
  mut prev_wall : Double
}

///|
pub fn DiskMonitor::new() -> DiskMonitor {
  { prev: Map([]), prev_wall: 0.0, }
}

///|
/// 采样一次。/proc/mounts 读取失败返回 None（平台无挂载表）；IO 速率源
/// /proc/diskstats 读不到时（macOS 无等价来源，IOKit 列远期）按「速率
/// 不可用」处理——容量表照常产出，速率字段 None。单个挂载点 statvfs
/// 失败（竞态消失）跳过该行。
pub fn DiskMonitor::tick(self : DiskMonitor) -> Array[DiskInfo]? {
  let cur : Map[String, (Int64, Int64)] = Map([])
  let io_ok = match read_text_file("/proc/diskstats") {
    None => false
    Some(stats_text) => {
      for d in parse_diskstats(stats_text) {
        cur.set(d.name, (d.sectors_read, d.sectors_written))
      }
      true
    }
  }
  let mounts_text = match read_text_file("/proc/mounts") {
    None => return None
    Some(t) => t
  }
  let wall = ffi_monotonic()
  let wall_dt = if self.prev_wall > 0.0 { wall - self.prev_wall } else { 0.0 }
  let out : Array[DiskInfo] = []
  let seen : Map[String, Bool] = Map([])
  for m in parse_mounts(mounts_text) {
    // 系统自用挂载（/boot、/snap、/private 等）直接跳过，省一次 statvfs
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
    // 速率：IO 来源可用且该挂载能归属到 diskstats 条目时才给出；
    // 否则 None（macOS / NFS 等无归属挂载 / 首帧无前样本），UI 显示「—」
    let mut read_bps : Double? = None
    let mut write_bps : Double? = None
    if io_ok {
      match diskstats_name(m.device) {
        None => ()
        Some(name) =>
          match (self.prev.get(name), cur.get(name)) {
            (Some(p), Some(c)) => {
              read_bps = Some(sector_rate(p.0, c.0, wall_dt))
              write_bps = Some(sector_rate(p.1, c.1, wall_dt))
            }
            _ => ()
          }
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
      Some(t) => if t.trim().to_owned() == mapper { return Some(entry) }
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

// ---------------------------------------------------------------------------
// S6 GPU：pci.ids 商业型号名解析（SYS5）
// ---------------------------------------------------------------------------

///|
/// pci.ids 候选路径：发行版安装位置有差异——hwdata 包装
/// /usr/share/hwdata/pci.ids（不少发行版里它是指向 misc 的符号链接），
/// pciutils 包装 /usr/share/misc/pci.ids。两路都不可达（未装数据库 /
/// Flatpak 沙箱 / 非 Linux）时由 [gpu_model_name] 兜底回退 device id
/// 显示。
pub fn pci_ids_paths() -> Array[String] {
  ["/usr/share/hwdata/pci.ids", "/usr/share/misc/pci.ids"]
}

///|
/// 读 pci.ids 全文（候选路径依次尝试；整文件约 1.4MB，native-stub 单文件
/// 读取上限 16MB）。都读不到返回 None（未装 hwdata / pciutils、Flatpak
/// 沙箱、非 Linux）。
fn read_pci_ids() -> String? {
  for path in pci_ids_paths() {
    match read_text_file(path) {
      Some(text) => return Some(text)
      None => ()
    }
  }
  None
}

///|
/// PCI id 归一化：去 0x / 0X 前缀、转小写、左侧补零到 4 位十六进制
/// （sysfs 的 vendor / device 节点形如 0x10de，pci.ids 形如 10de；
/// 位数不足左补零对齐；空串保持空串——补成 "0000" 会变成假有效 id）。
pub fn norm_pci_id(id : String) -> String {
  let mut s = id.trim().to_owned()
  if s.has_prefix("0x") || s.has_prefix("0X") {
    s = s[2:].to_owned()
  }
  s = s.to_lower()
  if s.is_empty() {
    return ""
  }
  let pad = 4 - s.char_length()
  if pad <= 0 {
    s
  } else {
    String::make(pad, '0') + s
  }
}

///|
/// 是否为 4 位十六进制串（pci.ids 的 vendor / device id 形态；归一化后
/// 用于判 id 是否可用——sysfs 读取失败时是 "(未知)" 之类占位串）。
pub fn is_hex4(s : String) -> Bool {
  if s.char_length() != 4 {
    return false
  }
  for c in s {
    let n = c.to_int()
    if !((n >= 48 && n <= 57) || (n >= 97 && n <= 102)) {
      return false
    }
  }
  true
}

///|
/// pci.ids 行内容（调用方已去缩进）切出 id 与名称：id 为首个空白分隔
/// 字段，名称为其后去首尾空白的部分（名称内部空格保留，如 "Navi 33
/// [Radeon RX 7700S/7600]"）；无名称时返回空串。按 UTF-16 码元索引
/// （与 [StringView::exact_view] 同基准；结构性字符全是 ASCII，代理对
/// 只可能出现在名称里，整体切片不受影响）。
fn pci_ids_id_name(content : StringView) -> (StringView, String) {
  let n = content.length()
  let mut id_end = -1
  let mut name_start = -1
  let mut i = 0
  while i < n {
    let c = content.unsafe_get(i).to_int()
    let ws = c == 32 || c == 9 || c == 10 || c == 13
    if id_end < 0 {
      if ws {
        id_end = i
      }
    } else if name_start < 0 && !ws {
      name_start = i
    }
    i += 1
  }
  let id = if id_end < 0 {
    content
  } else {
    content.exact_view(end=id_end)
  }
  let name = if name_start < 0 {
    ""
  } else {
    content.exact_view(start=name_start).to_owned().trim().to_owned()
  }
  (id, name)
}

///|
/// 在 pci.ids 全文里按 vendor:device 查商业型号名（sysfs 只有数字 id，
/// 商业型号名不在任何 /sys 节点中，免 root 纯文本数据库是唯一来源）。
/// 缩进层级：无缩进行是 vendor（4 位 id + 两空格 + 厂商名），单 Tab 行是
/// 该 vendor 的 device，双 Tab 行是 subsystem（跳过），'#' 起是注释；
/// class 节（"C xx" 起）与 vendor 行同形，id 非四位十六进制自然不匹配。
/// vendor 节唯一且按 id 有序，找到目标 vendor 后只扫其 device 行，遇到
/// 下一个无缩进行（下一 vendor / class 节）即出节、提前返回 None。id
/// 非法（归一化后非 4 位十六进制）直接 None。device 行有条目但无名称
/// （真实数据库不出现）不当命中，继续扫、最终按查不到回退 id 显示。
pub fn pci_ids_device_name(
  text : String,
  vendor : String,
  device : String,
) -> String? {
  let want_v = norm_pci_id(vendor)
  let want_d = norm_pci_id(device)
  if !is_hex4(want_v) || !is_hex4(want_d) {
    return None
  }
  let mut in_vendor = false
  for line in text.split("\n") {
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    if line.has_prefix("\t\t") {
      continue // subsystem 行
    }
    if line.has_prefix("\t") {
      if !in_vendor {
        continue
      }
      let (id, name) = pci_ids_id_name(line[1:])
      if id.equal_to_string(want_d) && name != "" {
        return Some(name)
      }
    } else {
      if in_vendor {
        return None // 已出目标 vendor 节（下一 vendor / class 节）
      }
      let (id, _) = pci_ids_id_name(line)
      if id.equal_to_string(want_v) {
        in_vendor = true
      }
    }
  }
  None
}

///|
/// 显卡型号名：nvidia-smi 命中时用其型号（比 pci.ids 更具体）；Windows
/// 的 stub 虚拟 <addr>/name（DXGI Description，见 GpuMonitor::tick 的
/// 预读）；否则按 vendor:device 查 pci.ids 商业型号名（AMD / Intel 等
/// 免 smi 的卡）；查不到（pci.ids 无该条目 / 数据库不可达）回退 device
/// id 原文（UI 显示「0x7480」，至少可区分多卡）；id 本身不可用（sysfs
/// 读取失败，占位 "(未知)"）时留空，UI 不显示型号位。
fn gpu_model_name(
  smi_model : String,
  vendor : String,
  device : String,
  ids : String,
) -> String {
  if smi_model != "" {
    return smi_model
  }
  match pci_ids_device_name(ids, vendor, device) {
    Some(name) => name
    None =>
      if is_hex4(norm_pci_id(device)) {
        device
      } else {
        ""
      }
  }
}

// ---------------------------------------------------------------------------
// S6 GPU：DRM fdinfo 聚合采样（SYS4）
// ---------------------------------------------------------------------------

///|
/// /proc/<pid>/fdinfo/<fd> 的 DRM 用量条目。engine_ns 是该 fd 全部
/// drm-engine-* 累计忙时间之和（ns，自客户端打开设备起累计，与
/// intel_gpu_top / nvtop 同源）；无任何引擎键的 fd（非 DRM 设备 / 老
/// 驱动无用量统计）解析为 None，不进条目。
pub(all) struct DrmFdinfo {
  driver : String
  pdev : String
  client_id : Int64
  engine_ns : Int64
}

///|
/// 是否 drm-engine-* 引擎时间键。排除 drm-engine-capacity-*：那是同类
/// 并行引擎数（i915 多视频引擎时打印），不是时间。
pub fn is_drm_engine_key(key : StringView) -> Bool {
  key.has_prefix("drm-engine-") && !key.has_prefix("drm-engine-capacity-")
}

///|
/// 解析 /proc/<pid>/fdinfo/<fd> 文本为 DRM 用量条目。键值按首个 ':'
/// 切分（内核以 Tab 分隔；规范只要求冒号后空白可忽略，故两侧都
/// trim），值取首个空白分隔字段（引擎值形如 "914633 ns"，单位后缀可
/// 缺）。收 drm-driver / drm-pdev / drm-client-id 与全部引擎键求和；
/// 无任何引擎键返回 None。client_id 缺失记 -1（聚合时不归并）。
pub fn parse_drm_fdinfo(text : String) -> DrmFdinfo? {
  let mut driver = ""
  let mut pdev = ""
  let mut client_id = -1L
  let mut engine_ns = 0L
  let mut any_engine = false
  for line in text.split("\n") {
    let (k, v) = match line.split_once(":") {
      Some((key, val)) => (key, val)
      None => continue
    }
    let key = k.trim()
    let val = v.trim()
    if key.equal_to_string("drm-driver") {
      driver = val.to_owned()
    } else if key.equal_to_string("drm-pdev") {
      pdev = val.to_owned()
    } else if key.equal_to_string("drm-client-id") {
      match parse_u64(val) {
        Some(id) => client_id = id
        None => ()
      }
    } else if is_drm_engine_key(key) {
      let f = split_fields(val)
      if f.length() > 0 {
        match parse_u64(f[0]) {
          Some(ns) => {
            engine_ns += ns
            any_engine = true
          }
          None => ()
        }
      }
    }
  }
  if any_engine {
    Some({ driver, pdev, client_id, engine_ns, })
  } else {
    None
  }
}

///|
/// fdinfo 条目的设备键：drm-pdev（内核 ≥6.5 的 PCI 槽位地址，与 sysfs
/// 设备目录名同形）优先；老内核 / 非 PCI 设备无该键，回退驱动名。
pub fn drm_device_key(e : DrmFdinfo) -> String {
  if e.pdev != "" {
    e.pdev
  } else {
    e.driver
  }
}

///|
/// 按 drm-client-id 归并：同一客户端（dup 的 fd、经 unix socket 跨进程
/// 传递的 fd）在多个 fdinfo 条目里重复出现且累计值相同，只取最大一次；
/// client_id < 0（缺键）不归并，每条独立计数。各客户端求和得每个设备
/// 键的全卡累计忙时间（ns）。client_id 是每设备计数器，故设备键进复合
/// 键，两个同驱动设备的客户端不会互相归并。
pub fn drm_clients_total(entries : Array[DrmFdinfo]) -> Map[String, Int64] {
  let out : Map[String, Int64] = Map([])
  let merged : Map[String, Int64] = Map([])
  for i, e in entries {
    let dev = drm_device_key(e)
    let ck = if e.client_id >= 0 {
      "\{dev}#\{e.client_id}"
    } else {
      "\{dev}#@\{i}"
    }
    let old = merged.get(ck).unwrap_or(0L)
    if e.engine_ns > old {
      merged.set(ck, e.engine_ns)
      out.set(dev, out.get(dev).unwrap_or(0L) + (e.engine_ns - old))
    }
  }
  out
}

///|
/// 全卡利用率（%，0..100）：两次采样的全卡累计忙时间差值 / 墙钟。墙钟
/// ≤ 0（首帧）按 0；累计值回落（客户端退出重开 / 计数器重置，内核规范
/// 允许非单调更新）按 0；多引擎并行时合计可超墙钟，钳到 100。
pub fn drm_busy_percent(prev_ns : Int64, cur_ns : Int64, wall_s : Double) -> Double {
  if wall_s <= 0.0 {
    0.0
  } else {
    let delta_ns = (cur_ns - prev_ns).max(0).to_double()
    (delta_ns / (wall_s * 1.0e9) * 100.0).min(100.0)
  }
}

///|
/// /proc 目录条目是否为进程目录（纯数字名；过滤 cpuinfo / self / irq
/// 等非进程条目）。
pub fn is_pid_entry(name : String) -> Bool {
  parse_u64(name) is Some(_)
}

///|
/// sysfs uevent 文本的 DRIVER= 值（PCI 设备绑定的驱动名）；未绑定 /
/// 无该行返回空串。
pub fn parse_uevent_driver(text : String) -> String {
  for line in text.split("\n") {
    let (k, v) = match line.split_once("=") {
      Some(pair) => pair
      None => continue
    }
    if k.trim().equal_to_string("DRIVER") {
      return v.trim().to_owned()
    }
  }
  ""
}

///|
/// PCI 设备绑定驱动名（/sys/bus/pci/devices/<addr>/uevent 的 DRIVER=）；
/// 读不到 / 未绑定返回空串。
fn pci_driver_name(addr : String) -> String {
  match read_text_file("/sys/bus/pci/devices/\{addr}/uevent") {
    None => ""
    Some(t) => parse_uevent_driver(t)
  }
}

///|
/// 枚举半成品（fdinfo 归属扫描后再补 busy；无 mut 字段，归属在
/// [gpu_row_busy] 里算）。
struct GpuRow {
  addr : String
  vendor : String
  device : String
  busy : Double?
  vram_used : Double?
  vram_total : Double?
  celsius : Double?
  model : String
}

///|
/// GPU 采样器：PCI 显示控制器枚举 + 占用来源优先级 + fdinfo 前样本差值
/// 状态 + pci.ids 型号名缓存。占用来源：nvidia-smi（N 卡专有驱动）>
/// sysfs gpu_busy_percent（amdgpu，免 root）> DRM fdinfo 聚合（i915 /
/// xe / amdgpu 兜底，免 root）。显存 / 温度走 sysfs 与 nvidia-smi
/// （原有口径不变）；型号名见 [GpuMonitor::gpu_model]。
pub(all) struct GpuMonitor {
  mut prev : Map[String, Int64]
  mut prev_wall : Double
  mut pci_ids : String?
  mut pci_ids_tried : Bool
  mut models : Map[String, String]
}

///|
pub fn GpuMonitor::new() -> GpuMonitor {
  {
    prev: Map([]),
    prev_wall: 0.0,
    pci_ids: None,
    pci_ids_tried: false,
    models: Map([]),
  }
}

///|
/// pci.ids 全文：首次用到时读入并常驻（约 1.4MB，一拍只读一次）；两路
/// 候选路径都读不到记空串，不再每拍重试。
fn GpuMonitor::pci_ids_text(self : GpuMonitor) -> String {
  if !self.pci_ids_tried {
    self.pci_ids = read_pci_ids()
    self.pci_ids_tried = true
  }
  self.pci_ids.unwrap_or("")
}

///|
/// 行的型号名：nvidia-smi 命中优先（其型号名比 pci.ids 更具体）；否则
/// 按 vendor:device 查 pci.ids 商业型号名，查不到回退 device id 原文。
/// 解析结果按 PCI 地址常驻——vendor:device 是静态硬件信息，首拍查一次
/// 即可，之后每拍零成本（pci.ids 全文扫描约 38k 行，不值得每拍重扫）；
/// pci.ids 不可达时常驻的是回退值，重启后重试。
fn GpuMonitor::gpu_model(self : GpuMonitor, r : GpuRow) -> String {
  if r.model != "" {
    return r.model
  }
  match self.models.get(r.addr) {
    Some(m) => m
    None => {
      let m = gpu_model_name(r.model, r.vendor, r.device, self.pci_ids_text())
      self.models.set(r.addr, m)
      m
    }
  }
}

///|
/// 扫描 /proc/<pid>/fdinfo 聚合并折算成全卡利用率表（设备键 → %）。
/// 只统计本用户进程的 fdinfo（他人进程 EACCES 读不到，边界见
/// adaptation.md SYS4 条）；首帧（无前样本）返回空表但记下当前累计值，
/// 次帧起出数；新客户端首现的那帧不计（无前样本），下帧起算。/proc
/// 不可列（非 Linux）返回空表。
pub fn GpuMonitor::fdinfo_usage(self : GpuMonitor) -> Map[String, Double] {
  let cur = drm_clients_total(scan_drm_fdinfo())
  let wall = ffi_monotonic()
  let wall_dt = if self.prev_wall > 0.0 { wall - self.prev_wall } else { 0.0 }
  let out : Map[String, Double] = Map([])
  if !self.prev.is_empty() {
    for k, v in cur.iter2() {
      match self.prev.get(k) {
        Some(p) => out.set(k, drm_busy_percent(p, v, wall_dt))
        None => ()
      }
    }
  }
  self.prev = cur
  self.prev_wall = wall
  out
}

///|
/// 扫全部 /proc/<pid>/fdinfo 收集 DRM 条目。非 DRM fd 与无用量统计的
/// 驱动自然无条目；目录 / 单个文件读不到（他人进程、进程退出竞态）
/// 跳过该条。
fn scan_drm_fdinfo() -> Array[DrmFdinfo] {
  let out : Array[DrmFdinfo] = []
  let pids = match list_dir("/proc") {
    None => return out
    Some(names) => names
  }
  for pid in pids {
    if !is_pid_entry(pid) {
      continue
    }
    let fds = match list_dir("/proc/\{pid}/fdinfo") {
      None => continue
      Some(names) => names
    }
    for fd in fds {
      match read_text_file("/proc/\{pid}/fdinfo/\{fd}") {
        None => ()
        Some(text) =>
          match parse_drm_fdinfo(text) {
            None => ()
            Some(e) => out.push(e)
          }
      }
    }
  }
  out
}

///|
/// 枚举行的占用终值：sysfs / nvidia-smi 已有值优先，否则查 fdinfo 表
/// ——先按设备目录名（drm-pdev 键，内核 ≥6.5），再按绑定驱动名（老内核
/// 无 drm-pdev 的回退；双同驱动卡会合并成同一值，已知边界）。
fn gpu_row_busy(row : GpuRow, usage : Map[String, Double]) -> Double? {
  match row.busy {
    Some(b) => Some(b)
    None =>
      match usage.get(row.addr) {
        Some(v) => Some(v)
        None => {
          let driver = pci_driver_name(row.addr)
          if driver == "" {
            None
          } else {
            usage.get(driver)
          }
        }
      }
  }
}

///|
/// 采样一次：枚举 PCI 显示控制器（class 0x03*），占用按 nvidia-smi >
/// sysfs gpu_busy_percent > DRM fdinfo 聚合取值，显存 / 温度口径不变。
/// fdinfo 只在「有显卡既无 sysfs 占用也无 nvidia-smi 覆盖」时才扫
/// ——AMD / NVIDIA 机器整拍免扫（全 /proc 扫描实测约 56ms/拍，见
/// adaptation.md SYS4 条）。macOS 无 sysfs 设备树，走 system_profiler
/// 解析（[macos_gpu_list]）；目录不可读返回 None。
pub fn GpuMonitor::tick(self : GpuMonitor) -> Array[GpuInfo]? {
  if on_macos() {
    return macos_gpu_list()
  }
  let devs = match list_dir("/sys/bus/pci/devices") {
    None => return None
    Some(names) => names
  }
  let smi = nvidia_smi_map()
  let rows : Array[GpuRow] = []
  let mut need_fdinfo = false
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
    if model == "" {
      // Windows：stub 以 DXGI Description 虚拟 <addr>/name（真适配器
      // 友好名）。Linux sysfs 无此文件，读不到为 None，取名链不变
      model = match read_text_file("\{base}/name") {
        Some(t) => t.trim().to_owned()
        None => ""
      }
    }
    if busy is None {
      need_fdinfo = true
    }
    rows.push({
      addr,
      vendor,
      device,
      busy,
      vram_used,
      vram_total,
      celsius,
      model,
    })
  }
  let mut usage : Map[String, Double] = Map([])
  if need_fdinfo {
    usage = self.fdinfo_usage()
  }
  let out : Array[GpuInfo] = []
  for r in rows {
    out.push({
      pci: r.addr,
      vendor: vendor_name(r.vendor),
      device: r.device,
      model: self.gpu_model(r),
      celsius: r.celsius,
      busy: gpu_row_busy(r, usage),
      vram_used: r.vram_used,
      vram_total: r.vram_total,
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

///|
/// macOS GPU 枚举：system_profiler SPDisplaysDataType -json 子进程（stub
/// 内 fork + 匿名管道 + 8s 超时，首跑秒级、成功后进程内常驻缓存、失败
/// 5s 退避），JSON 原样回传、此处纯函数解析。利用率与温度无来源（GPU
/// 利用率无公开接口、SMC / IOReport 私有键列远期），busy / celsius 留
/// None，UI 按位显示「—」。子进程失败返回 None（无显卡 / 查询失败）。
fn macos_gpu_list() -> Array[GpuInfo]? {
  match ffi_system_profiler_gpu() {
    None => None
    Some(bytes) => Some(parse_system_profiler_gpu(@utf8.decode_lossy(bytes)))
  }
}

///|
/// 从 JSON 对象文本中取字符串键的值（键带引号）；键缺失或值非字符串
/// （数字 / 布尔）返回 None。转义只处理 \" 与 \\（system_profiler 的
/// 字符串值不出现其它转义序列）。未转义区间成段拷贝（代理对安全）。
fn json_string_value(obj : String, key : String) -> String? {
  let pat = "\"\{key}\""
  let k = match obj.find(pat) {
    Some(i) => i
    None => return None
  }
  let n = obj.char_length()
  // 键后找 ':'（58），跳过空白，值须以 '"'（34）起头
  let mut i = k + pat.char_length()
  while i < n && obj.unsafe_get(i).to_int() != 58 {
    i += 1
  }
  if i >= n {
    return None
  }
  i += 1
  while i < n {
    let c = obj.unsafe_get(i).to_int()
    if c == 32 || c == 9 || c == 10 || c == 13 {
      i += 1
    } else {
      break
    }
  }
  if i >= n || obj.unsafe_get(i).to_int() != 34 {
    return None
  }
  i += 1
  let sb = StringBuilder()
  let mut run = i
  while i < n {
    let c = obj.unsafe_get(i).to_int()
    if c == 92 && i + 1 < n {
      // 反斜杠转义：只认 \" 与 \\，其余按普通字符
      let d = obj.unsafe_get(i + 1)
      if d.to_int() == 34 || d.to_int() == 92 {
        sb.write_stringview(obj[run:i])
        sb.write_char(d.unsafe_to_char())
        i += 2
        run = i
        continue
      }
      i += 1
    } else if c == 34 {
      sb.write_stringview(obj[run:i])
      return Some(sb.to_string())
    } else {
      i += 1
    }
  }
  None
}

///|
/// system_profiler -json 的 _items 数组顶层对象（每对象一块显卡）。按
/// 花括号深度切分并跳过字符串内的括号（型号名可能含括号），键序无关。
fn json_items_objects(text : String) -> Array[String] {
  let out : Array[String] = []
  let key = match text.find("\"_items\"") {
    Some(i) => i
    None => return out
  }
  let n = text.char_length()
  // 从 "_items"（8 字符）起找数组左括号 '['（91）
  let mut i = key + 8
  while i < n && text.unsafe_get(i).to_int() != 91 {
    i += 1
  }
  if i >= n {
    return out
  }
  let mut depth = 0
  let mut in_str = false
  let mut esc = false
  let mut start = -1
  while i < n {
    let c = text.unsafe_get(i).to_int()
    if in_str {
      if esc {
        esc = false
      } else if c == 92 {
        esc = true
      } else if c == 34 {
        in_str = false
      }
    } else if c == 34 {
      in_str = true
    } else if c == 123 {
      // '{'
      if depth == 0 {
        start = i
      }
      depth += 1
    } else if c == 125 {
      // '}'
      if depth > 0 {
        depth -= 1
        if depth == 0 && start >= 0 {
          out.push(text[start:i + 1].to_owned())
          start = -1
        }
      }
    } else if c == 93 && depth == 0 {
      // ']'：数组结束
      break
    }
    i += 1
  }
  out
}

///|
/// system_profiler 的显存文本（"16 GB" / "1536 MB" / "1.5 GB"）→ 字节；
/// 无单位按字节；无法解析返回 None。
pub fn parse_vram(s : String) -> Int64? {
  let f = split_fields(s)
  if f.length() == 0 {
    return None
  }
  let v = match parse_double(f[0]) {
    Some(d) => d
    None => return None
  }
  let unit = if f.length() >= 2 { f[1].to_owned() } else { "B".to_string() }
  let scale = match unit {
    "B" | "b" => 1.0
    "KB" | "kb" | "KiB" | "kib" => 1024.0
    "MB" | "mb" | "MiB" | "mib" => 1048576.0
    "GB" | "gb" | "GiB" | "gib" => 1073741824.0
    "TB" | "tb" | "TiB" | "tib" => 1099511627776.0
    _ => return None
  }
  Some((v * scale).to_int64())
}

///|
/// 文本嗅探：型号名 / 厂商字段 → 厂商名（macOS 无 PCI vendor id，按
/// 名字判断；含常见关键字即归类，其余 "(未知)"）。
fn gpu_vendor_name(vendor_text : String, model : String) -> String {
  fn has(s : String, needle : String) -> Bool {
    s.find(needle) is Some(_)
  }

  let t = "\{vendor_text} \{model}"
  if has(t, "nvidia") ||
    has(t, "NVIDIA") ||
    has(t, "GeForce") ||
    has(t, "Quadro") ||
    has(t, "RTX") ||
    has(t, "GTX") {
    "NVIDIA"
  } else if has(t, "amd") || has(t, "AMD") || has(t, "Radeon") {
    "AMD"
  } else if has(t, "intel") || has(t, "Intel") || has(t, "UHD") || has(t, "Iris") {
    "Intel"
  } else if has(t, "Apple") || has(t, "apple") {
    "Apple"
  } else {
    "(未知)"
  }
}

///|
/// 解析 system_profiler SPDisplaysDataType -json：每块显卡一条。型号取
/// sppci_model（回退 _name）；显存总量取 spdisplays_vram；利用率 / 温度
/// 无来源留 None（UI 按位显示「—」）。system_profiler 的键随系统版本
/// 略有出入，宽容口径：取不到的键留空 / None，不报错（真机键名核实项
/// 见 adaptation.md SYS3 条）。
pub fn parse_system_profiler_gpu(json : String) -> Array[GpuInfo] {
  let out : Array[GpuInfo] = []
  for i, obj in json_items_objects(json) {
    let model = match json_string_value(obj, "sppci_model") {
      Some(m) => m
      None => (json_string_value(obj, "_name")).unwrap_or("")
    }
    let vram = match json_string_value(obj, "spdisplays_vram") {
      Some(t) => parse_vram(t)
      None => None
    }
    let vendor_text = (json_string_value(obj, "spdisplays_vendor")).unwrap_or("")
    out.push({
      pci: "spdisplays\{i}",
      vendor: gpu_vendor_name(vendor_text, model),
      device: if model == "" { "(未知)" } else { model },
      model,
      celsius: None,
      busy: None,
      vram_used: None,
      vram_total: vram.map(fn(b) { b.to_double() }),
    })
  }
  out
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
  { prev: Map([]), prev_wall: 0.0, }
}

///|
/// 采样一次。目录不可读（非 Linux）返回 None；单网卡读取失败跳过。
pub fn NetMonitor::tick(self : NetMonitor) -> Array[NetInfo]? {
  let names = match list_dir("/sys/class/net") {
    None => return None
    Some(names) => names
  }
  let wall = ffi_monotonic()
  let wall_dt = if self.prev_wall > 0.0 { wall - self.prev_wall } else { 0.0 }
  let out : Array[NetInfo] = []
  let cur : Map[String, (Int64, Int64)] = Map([])
  for name in names {
    let rx = match
      read_text_file("/sys/class/net/\{name}/statistics/rx_bytes") {
      None => continue
      Some(t) => parse_u64(t.trim()).unwrap_or(0)
    }
    let tx = match
      read_text_file("/sys/class/net/\{name}/statistics/tx_bytes") {
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
    out.push({ name, rx_bytes: rx, tx_bytes: tx, rx_bps, tx_bps, })
    cur.set(name, (rx, tx))
  }
  self.prev = cur
  self.prev_wall = wall
  Some(out)
}
