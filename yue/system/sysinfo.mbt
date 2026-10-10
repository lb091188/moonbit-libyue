// 系统信息（只读 /proc 与 /sys 文本）：发行版标识（/etc/os-release）、
// 机器 DMI 标识（/sys/class/dmi/id/）、物理内存（/proc/meminfo）、开机
// 时长（/proc/uptime）。文件读取统一走 [read_text_file]，解析为纯函数
// （si_ 前缀），sysinfo_wbtest.mbt 白盒覆盖；非 Linux 平台一律
// Unsupported。读不到（文件不存在 / 权限不足）给 Err 并带路径，不糊弄
// 成空串。
//
// 典型用法：
//   let os = si_os()      // Ok({ pretty_name: "Ubuntu 24.04.5 LTS", .. })
//   let mem = si_memory() // Ok({ total_kb: 32665016, available_kb: .. })
//   let up = si_uptime()  // Ok(84088.08)  单位秒

///|
/// 发行版标识：/etc/os-release 的 PRETTY_NAME / ID / VERSION_ID
/// （后两者在该文件中缺失时为空串）。
pub(all) struct OsInfo {
  /// 展示名，如 "Ubuntu 24.04.5 LTS"
  pretty_name : String
  /// 发行版 id，如 "ubuntu"
  id : String
  /// 版本号，如 "24.04"（未标注为空串）
  version_id : String
}

///|
pub impl Show for OsInfo with fn output(self, logger) {
  logger.write_string("OsInfo { pretty_name: ")
  logger.write_string(self.pretty_name)
  logger.write_string(", id: ")
  logger.write_string(self.id)
  logger.write_string(", version_id: ")
  logger.write_string(self.version_id)
  logger.write_string(" }")
}

///|
pub extend OsInfo with Show::{to_string, output}

///|
/// 机器 DMI 标识：厂商（sys_vendor）/ 产品名（product_name）/ 产品序列号
/// （product_serial）。序列号在多数发行版上仅 root 可读，读不到时
/// [si_machine] 给 Err，不用空串糊弄。
pub(all) struct MachineInfo {
  /// 厂商，如 "ASUS"
  vendor : String
  /// 产品名，如 "System Product Name"
  product : String
  /// 产品序列号
  serial : String
}

///|
pub impl Show for MachineInfo with fn output(self, logger) {
  logger.write_string("MachineInfo { vendor: ")
  logger.write_string(self.vendor)
  logger.write_string(", product: ")
  logger.write_string(self.product)
  logger.write_string(", serial: ")
  logger.write_string(self.serial)
  logger.write_string(" }")
}

///|
pub extend MachineInfo with Show::{to_string, output}

///|
/// 物理内存快照：/proc/meminfo 的总量与可用值，单位 kB（MemAvailable
/// 含可回收缓存，是"还能拿来用多少"的更实口径）。
pub(all) struct MemoryInfo {
  /// MemTotal（kB）
  total_kb : Int
  /// MemAvailable（kB）
  available_kb : Int
}

///|
pub impl Show for MemoryInfo with fn output(self, logger) {
  logger.write_string("MemoryInfo { total_kb: ")
  logger.write_string(self.total_kb.to_string())
  logger.write_string(", available_kb: ")
  logger.write_string(self.available_kb.to_string())
  logger.write_string(" }")
}

///|
pub extend MemoryInfo with Show::{to_string, output}

///|
pub(all) enum SysInfoError {
  /// 平台不支持（非 Linux）
  SiUnsupported
  /// 文件读不到（不存在 / 权限不足），带路径
  SiReadFailed(String)
  /// 解析失败（格式不符 / 关键字段缺失），带说明
  SiParseFailed(String)
}

///|
pub impl Show for SysInfoError with fn output(self, logger) {
  match self {
    SiUnsupported => logger.write_string("SysInfoError::SiUnsupported")
    SiReadFailed(p) => logger.write_string("SysInfoError::SiReadFailed(\{p})")
    SiParseFailed(m) => logger.write_string("SysInfoError::SiParseFailed(\{m})")
  }
}

///|
pub extend SysInfoError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：文本切分 / os-release 键值 / meminfo / uptime 解析
// （sysinfo_wbtest.mbt 白盒覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn si_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 去首尾空白。
fn si_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && si_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && si_is_ws(chars[j]) {
    j = j - 1
  }
  let buf = StringBuilder()
  let mut k = i
  while k <= j {
    buf.write_char(chars[k])
    k = k + 1
  }
  buf.to_string()
}

///|
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn si_split_lines(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut has = false
  for ch in s {
    if ch == '\n' {
      if has {
        out.push(cur.to_string())
        cur = StringBuilder()
        has = false
      }
    } else if ch != '\r' {
      cur.write_char(ch)
      has = true
    }
  }
  if has {
    out.push(cur.to_string())
  }
  out
}

///|
/// 剥掉成对的包裹双引号（`"Ubuntu"` → `Ubuntu`；只有首或末单引号、空
/// 串等不成对情形原样返回）。
fn si_unquote(s : String) -> String {
  let t = si_trim(s)
  if t.length() < 2 {
    return t
  }
  let chars : Array[Char] = []
  for ch in t {
    chars.push(ch)
  }
  if chars[0] == '"' && chars[chars.length() - 1] == '"' {
    let buf = StringBuilder()
    let mut i = 1
    while i < chars.length() - 1 {
      buf.write_char(chars[i])
      i = i + 1
    }
    buf.to_string()
  } else {
    t
  }
}

///|
/// os-release 的 `KEY=VALUE` 行 → (键, 去引号值)；无 '='、空键或 '='
/// 前有空白导致键非标识符形态时为 None。注释行（# 开头）由调用方先过滤。
fn si_split_kv(line : String) -> (String, String)? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let mut eq = -1
  for i in 0..<chars.length() {
    if chars[i] == '=' {
      eq = i
      break
    }
  }
  if eq <= 0 {
    return None // 无 '=' 或 '=' 在首位（空键）
  }
  let key = si_trim(
    {
      let buf = StringBuilder()
      for i in 0..<eq {
        buf.write_char(chars[i])
      }
      buf.to_string()
    },
  )
  if key == "" {
    return None
  }
  let value = si_unquote(
    {
      let buf = StringBuilder()
      for i in (eq + 1)..<chars.length() {
        buf.write_char(chars[i])
      }
      buf.to_string()
    },
  )
  Some((key, value))
}

///|
/// 解析 /etc/os-release 全文：取 PRETTY_NAME / ID / VERSION_ID 三键
/// （PRETTY_NAME 缺失或为空视为非 os-release 格式 → None；ID /
/// VERSION_ID 缺省空串）。忽略注释行与空白行，重复键取最后一次。
fn si_parse_os_release(text : String) -> OsInfo? {
  let mut pretty = ""
  let mut id = ""
  let mut version_id = ""
  for line in si_split_lines(text) {
    let t = si_trim(line)
    if t == "" || t.has_prefix("#") {
      continue
    }
    match si_split_kv(t) {
      None => ()
      Some((k, v)) =>
        match k {
          "PRETTY_NAME" => pretty = v
          "ID" => id = v
          "VERSION_ID" => version_id = v
          _ => ()
        }
    }
  }
  if pretty == "" {
    None
  } else {
    Some({ pretty_name: pretty, id, version_id, })
  }
}

///|
/// 解析 /proc/meminfo 全文：取 MemTotal 与 MemAvailable 两行，单位 kB
/// （`MemTotal:       32665016 kB`；容忍值后无单位后缀）。任一缺失或
/// 非数值 → None。
fn si_parse_meminfo(text : String) -> MemoryInfo? {
  let mut total : Int? = None
  let mut available : Int? = None
  for line in si_split_lines(text) {
    let t = si_trim(line)
    let key = match si_line_key(t) {
      None => continue
      Some(k) => k
    }
    match key {
      "MemTotal" => total = si_meminfo_value(t)
      "MemAvailable" => available = si_meminfo_value(t)
      _ => ()
    }
  }
  match (total, available) {
    (Some(t), Some(a)) => Some({ total_kb: t, available_kb: a, })
    _ => None
  }
}

///|
/// meminfo 行的冒号前的键（`MemTotal:  123 kB` → `MemTotal`；无冒号或
/// 键中含空白为 None）。
fn si_line_key(line : String) -> String? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let mut colon = -1
  for i in 0..<chars.length() {
    if chars[i] == ':' {
      colon = i
      break
    }
  }
  if colon <= 0 {
    return None
  }
  let buf = StringBuilder()
  let mut i = 0
  while i < colon {
    buf.write_char(chars[i])
    i = i + 1
  }
  let key = buf.to_string()
  if key == "" {
    None
  } else {
    Some(key)
  }
}

///|
/// meminfo 行的冒号后的首个 token → 非负整数（kB；`32665016 kB` →
/// 32665016；非数值或无 token 为 None）。
fn si_meminfo_value(line : String) -> Int? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let mut colon = -1
  for i in 0..<chars.length() {
    if chars[i] == ':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    return None
  }
  // 冒号后逐字符扫：跳过前置空白，收连续数字，遇空白/单位即停
  let mut v = 0
  let mut any = false
  let mut i = colon + 1
  while i < chars.length() {
    let c = chars[i]
    if !any {
      if si_is_ws(c) {
        i += 1
        continue
      }
      if c < '0' || c > '9' {
        return None // 首个非空白字符不是数字
      }
      any = true
      v = c.to_int() - 48
    } else if c >= '0' && c <= '9' {
      v = v * 10 + (c.to_int() - 48)
    } else {
      break // 'kB' 等单位后缀或行尾空白
    }
    i += 1
  }
  if any {
    Some(v)
  } else {
    None
  }
}

///|
/// 解析十进制小数字符串 → Double（`84088.08` → 84088.08；纯整数合法，
/// 无数字 / 多个小数点 / 含其他字符为 None）。
fn si_parse_seconds(tok : String) -> Double? {
  let mut whole = 0.0
  let mut frac = 0.0
  let mut scale = 0.1
  let mut seen_dot = false
  let mut any_digit = false
  for ch in tok {
    if ch == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
    } else if ch >= '0' && ch <= '9' {
      any_digit = true
      let d = (ch.to_int() - 48).to_double()
      if seen_dot {
        frac = frac + d * scale
        scale = scale / 10.0
      } else {
        whole = whole * 10.0 + d
      }
    } else {
      return None
    }
  }
  if any_digit {
    Some(whole + frac)
  } else {
    None
  }
}

///|
/// 解析 /proc/uptime 全文：取首个 token 为开机秒数（`84088.08 1645.16`
/// → 84088.08；第二列 idle 忽略；空输出 / 非法数值为 None）。
fn si_parse_uptime(text : String) -> Double? {
  let toks = si_split_ws(text)
  if toks.length() == 0 {
    return None
  }
  si_parse_seconds(toks[0])
}

///|
/// 按空白切分 token（连续空白视为一个分隔符，首尾空白忽略）。
fn si_split_ws(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut has = false
  for ch in s {
    if si_is_ws(ch) {
      if has {
        out.push(cur.to_string())
        cur = StringBuilder()
        has = false
      }
    } else {
      cur.write_char(ch)
      has = true
    }
  }
  if has {
    out.push(cur.to_string())
  }
  out
}

///|
/// DMI 属性路径：/sys/class/dmi/id/<name>。
fn si_dmi_path(name : String) -> String {
  "/sys/class/dmi/id/" + name
}

///|
/// 读 DMI 文本属性：成功去首尾空白返回非空内容；读不到或内容为空
/// （属性不存在 / 权限不足 / 空文件）为 None。
fn si_read_dmi(name : String) -> String? {
  match @yue.read_text_file(si_dmi_path(name)) {
    None => None
    Some(text) => {
      let t = si_trim(text)
      if t == "" {
        None
      } else {
        Some(t)
      }
    }
  }
}

///|
/// 按单字符切分文本为字符串数组（保留空字段；Windows 直连组各模块共用）。
fn sys_split_fields(s : String, sep : Char) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  for ch in s {
    if ch == sep {
      out.push(cur.to_string())
      cur = StringBuilder()
    } else {
      cur.write_char(ch)
    }
  }
  out.push(cur.to_string())
  out
}

///|
/// 整数文本 → Int64（非法或溢出为 0；Windows 直连组各模块共用）。
fn sys_parse_i64(s : String) -> Int64 {
  try @string.parse_int64(s) catch {
    _ => 0L
  }
}

// ---------------------------------------------------------------------------
// 公开 API（都只读；非 Linux / Windows → SiUnsupported）
// ---------------------------------------------------------------------------

///|
/// 发行版标识：Linux 读 /etc/os-release 的 PRETTY_NAME / ID / VERSION_ID
/// （文件读不到 → SiReadFailed，格式不符 → SiParseFailed）；Windows 读
/// 注册表 ProductName / DisplayVersion（id 恒 "windows"）。
pub fn si_os() -> Result[OsInfo, SysInfoError] {
  match @yue.platform() {
    "linux" =>
      match @yue.read_text_file("/etc/os-release") {
        None => Err(SiReadFailed("/etc/os-release"))
        Some(text) =>
          match si_parse_os_release(text) {
            Some(info) => Ok(info)
            None => Err(SiParseFailed("/etc/os-release: 缺少 PRETTY_NAME"))
          }
      }
    "windows" => {
      let pretty = match si_win_reg("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", "ProductName") {
        Some(p) => p
        None => return Err(SiReadFailed("HKLM:...ProductName"))
      }
      // DisplayVersion（22H2 形态，Win10 20H1+ 写入）缺失回退 CurrentBuildNumber
      let version = match
        si_win_reg(
          "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
          "DisplayVersion",
        ) {
        Some(v) => v
        None =>
          match
            si_win_reg(
              "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
              "CurrentBuildNumber",
            ) {
            Some(v) => v
            None => return Err(SiReadFailed("HKLM:...CurrentBuildNumber"))
          }
      }
      Ok({ pretty_name: pretty, id: "windows", version_id: version })
    }
    _ => Err(SiUnsupported)
  }
}

///|
/// Windows 注册表字符串读（HKLM；读不到或非 REG_SZ 为 None）。
fn si_win_reg(path : String, value : String) -> String? {
  let ok = Ref(0)
  let bytes = @yue.ffi_win_reg_str(
    0,
    @yue.utf8_bytes(path),
    @yue.utf8_bytes(value),
    ok,
  )
  if ok.val != 1 {
    return None
  }
  let text = @utf8.decode_lossy(bytes)
  let t = si_trim(text)
  if t == "" {
    None
  } else {
    Some(t)
  }
}

///|
/// 机器 DMI 标识：Linux 读 /sys/class/dmi/id/ 的 sys_vendor /
/// product_name / product_serial（任一项读不到给 Err(SiReadFailed(路径))，
/// 不用空串糊弄）；Windows 读注册表 BIOS 键的 SystemManufacturer /
/// SystemProductName（serial 无注册表对应、需 WMI/SMBIOS 解析，本批
/// 恒空串，见文档边界）。
pub fn si_machine() -> Result[MachineInfo, SysInfoError] {
  match @yue.platform() {
    "linux" => {
      let vendor = match si_read_dmi("sys_vendor") {
        Some(v) => v
        None => return Err(SiReadFailed(si_dmi_path("sys_vendor")))
      }
      let product = match si_read_dmi("product_name") {
        Some(v) => v
        None => return Err(SiReadFailed(si_dmi_path("product_name")))
      }
      let serial = match si_read_dmi("product_serial") {
        Some(v) => v
        None => return Err(SiReadFailed(si_dmi_path("product_serial")))
      }
      Ok({ vendor, product, serial, })
    }
    "windows" => {
      let vendor = match
        si_win_reg("HARDWARE\\DESCRIPTION\\System\\BIOS", "SystemManufacturer") {
        Some(v) => v
        None =>
          return Err(SiReadFailed("HKLM:HARDWARE\\DESCRIPTION\\System\\BIOS: SystemManufacturer"))
      }
      let product = match
        si_win_reg("HARDWARE\\DESCRIPTION\\System\\BIOS", "SystemProductName") {
        Some(v) => v
        None =>
          return Err(SiReadFailed("HKLM:HARDWARE\\DESCRIPTION\\System\\BIOS: SystemProductName"))
      }
      Ok({ vendor, product, serial: "", })
    }
    _ => Err(SiUnsupported)
  }
}

///|
/// 物理内存快照：Linux 读 /proc/meminfo 的 MemTotal / MemAvailable（单位
/// kB；文件读不到 → SiReadFailed，关键行缺失 → SiParseFailed）；Windows
/// 走 GlobalMemoryStatusEx（total=物理总量，available=当前可用物理内存）。
pub fn si_memory() -> Result[MemoryInfo, SysInfoError] {
  match @yue.platform() {
    "linux" =>
      match @yue.read_text_file("/proc/meminfo") {
        None => Err(SiReadFailed("/proc/meminfo"))
        Some(text) =>
          match si_parse_meminfo(text) {
            Some(m) => Ok(m)
            None =>
              Err(SiParseFailed("/proc/meminfo: 缺少 MemTotal/MemAvailable"))
          }
      }
    "windows" => {
      let total = Ref(0L)
      let avail = Ref(0L)
      if @yue.ffi_win_memory(total, avail) != 1 {
        return Err(SiReadFailed("GlobalMemoryStatusEx"))
      }
      Ok({
        total_kb: total.val.to_int(),
        available_kb: avail.val.to_int(),
      })
    }
    _ => Err(SiUnsupported)
  }
}

///|
/// 开机时长（秒）：Linux 读 /proc/uptime 首列（文件读不到 → SiReadFailed，
/// 格式不符 → SiParseFailed）；Windows 走 GetTickCount64（毫秒换算秒）。
pub fn si_uptime() -> Result[Double, SysInfoError] {
  match @yue.platform() {
    "linux" =>
      match @yue.read_text_file("/proc/uptime") {
        None => Err(SiReadFailed("/proc/uptime"))
        Some(text) =>
          match si_parse_uptime(text) {
            Some(secs) => Ok(secs)
            None => Err(SiParseFailed("/proc/uptime"))
          }
      }
    "windows" => {
      let ms = @yue.ffi_win_uptime_ms()
      if ms < 0L {
        return Err(SiReadFailed("GetTickCount64"))
      }
      Ok(ms.to_double() / 1000.0)
    }
    _ => Err(SiUnsupported)
  }
}
