// 电源计划（power-profiles-daemon）：经 procrun 的 [pr_run] 调
// powerprofilesctl 三条命令——list 读可用计划集、get 读当前计划、set
// 切换计划；计划三值 performance / balanced / power-saver 与后端内置
// 计划对齐。命令缺失（power-profiles-daemon 未安装，shell 以退出码 127
// 呈现）→ PpUnsupported，语义化不靠错误文本猜测。list 输出按后端返回
// 序（后端把推荐序排在前面时即推荐序）。list 输出解析与 set 参数构造
// 为纯函数（pp_ 前缀），powerprofile_wbtest.mbt 白盒覆盖；set 有副作用
// （切换系统电源计划），仅实现不执行，wbtest 只断言其参数表。
//
// 典型用法：
//   match pp_profiles() {
//     Ok(profiles) if profiles.contains(PBalanced) =>
//       pp_set(PBalanced) // 需要认证，调用方自行走授权流程
//     _ => ()
//   }

///|
/// 电源计划：PPowerSaver 省电、PBalanced 均衡、PPerformance 性能。
pub(all) enum PowerProfile {
  PPerformance
  PBalanced
  PPowerSaver
}

///|
pub impl Show for PowerProfile with fn output(self, logger) {
  logger.write_string("PowerProfile::")
  logger.write_string(pp_name_of(self))
}

///|
pub extend PowerProfile with Show::{to_string, output}

///|
pub(all) enum PowerProfileError {
  /// 平台不支持或 powerprofilesctl 缺失（power-profiles-daemon 未安装）
  PpUnsupported
  /// 命令执行失败（启动失败 / 非零退出码 / 超时 / 被信号终止），带原因
  PpCommandFailed(String)
  /// 工具输出解析失败，带原文
  PpParseFailed(String)
}

///|
pub impl Show for PowerProfileError with fn output(self, logger) {
  match self {
    PpUnsupported => logger.write_string("PowerProfileError::PpUnsupported")
    PpCommandFailed(m) =>
      logger.write_string("PowerProfileError::PpCommandFailed(\{m})")
    PpParseFailed(m) =>
      logger.write_string("PowerProfileError::PpParseFailed(\{m})")
  }
}

///|
pub extend PowerProfileError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：计划名映射 / list 输出解析 / set 参数构造（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn pp_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 去首尾空白。
fn pp_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && pp_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && pp_is_ws(chars[j]) {
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
fn pp_split_lines(s : String) -> Array[String] {
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
/// stderr 诊断文本压成单行并截断（错误消息只取首行前 120 字符，
/// 避免刷屏）。
fn pp_first_line(s : String) -> String {
  let buf = StringBuilder()
  let mut n = 0
  for ch in s {
    if ch == '\n' || n >= 120 {
      break
    }
    buf.write_char(ch)
    n = n + 1
  }
  buf.to_string()
}

///|
/// 计划 → powerprofilesctl 侧名字（"performance" / "balanced" /
/// "power-saver"）。
fn pp_name_of(profile : PowerProfile) -> String {
  match profile {
    PPerformance => "performance"
    PBalanced => "balanced"
    PPowerSaver => "power-saver"
  }
}

///|
/// powerprofilesctl 侧名字 → 计划（未知名字为 None）。
fn pp_profile_of(name : String) -> PowerProfile? {
  match name {
    "performance" => Some(PPerformance)
    "balanced" => Some(PBalanced)
    "power-saver" => Some(PPowerSaver)
    _ => None
  }
}

///|
/// 判定 `powerprofilesctl list` 的「计划名行」并取计划名：行形如
/// `  balanced:`（恰好两空格缩进）或 `* balanced:`（活动计划带 '\*'
/// 标记），计划名后带冒号且不含空白；属性行（更深缩进的
/// `    Driver: x`）、无缩进行与其他杂行一律 None。
fn pp_line_profile(line : String) -> String? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 2
  if n < 3 {
    return None
  }
  if chars[0] == '*' && chars[1] == ' ' {
    i = 2 // 活动计划行 "* balanced:"
  } else if chars[0] == ' ' && chars[1] == ' ' {
    i = 2 // 普通计划行 "  balanced:"
  } else {
    return None // 缩进不符：属性行/杂行
  }
  if chars[n - 1] != ':' {
    return None // 计划名行以冒号结尾
  }
  let buf = StringBuilder()
  let mut k = i
  while k < n - 1 {
    if pp_is_ws(chars[k]) {
      return None // 属性行等含空白，排除
    }
    buf.write_char(chars[k])
    k = k + 1
  }
  let name = buf.to_string()
  if name == "" {
    None
  } else {
    Some(name)
  }
}

///|
/// 解析 `powerprofilesctl list` 输出：取全部计划名行映射为计划值，
/// 按输出序返回（未知计划名跳过，属性行不误收）。样例：
///   `* power-saver:` / `    Driver: x` / `  balanced:` / `  performance:`.
fn pp_parse_profile_list(out : String) -> Array[PowerProfile] {
  let profiles : Array[PowerProfile] = []
  for line in pp_split_lines(out) {
    match pp_line_profile(line) {
      None => ()
      Some(name) =>
        match pp_profile_of(name) {
          Some(p) => profiles.push(p)
          None => ()
        }
    }
  }
  profiles
}

///|
/// 解析 `powerprofilesctl get` 输出：整段trim 后按计划名匹配（"balanced"
/// → Some(PBalanced)；未知名字或空输出为 None）。
fn pp_parse_current(out : String) -> PowerProfile? {
  pp_profile_of(pp_trim(out))
}

///|
/// set 子命令的参数表（set <计划名>）。
fn pp_set_args(profile : PowerProfile) -> Array[String] {
  ["set", pp_name_of(profile)]
}

// ---------------------------------------------------------------------------
// 命令执行封装（复用 procrun 的 [pr_run]：spawn → 限时回收 → 临时文件
// 读回；shell 退出码 127 = 命令缺失 → PpUnsupported，其余非零退出为
// PpCommandFailed）
// ---------------------------------------------------------------------------

///|
/// 运行 powerprofilesctl 并捕获标准输出：退出码 0 → Ok(stdout)；127
/// （shell 无此命令，即 power-profiles-daemon 未安装）→ PpUnsupported；
/// 其余错误按 ProcError 类型映射。
fn pp_run(args : Array[String]) -> Result[String, PowerProfileError] {
  match pr_run("powerprofilesctl", args, timeout_ms=4000) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(127, _)) => Err(PpUnsupported)
    Err(NonZeroExit(code, err)) =>
      Err(
        PpCommandFailed(
          "powerprofilesctl: 退出码 \{code}（\{pp_first_line(err)}）",
        ),
      )
    Err(Timeout(m)) => Err(PpCommandFailed(m))
    Err(SpawnFailed(m)) => Err(PpCommandFailed(m))
    Err(Signaled(sig)) =>
      Err(PpCommandFailed("powerprofilesctl: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(PpUnsupported)
  }
}

///|
/// powerprofilesctl 可用性：能跑通只读查询（get 退出 0）即可用；
/// 每次调用真实探测，高频场景请调用方自行缓存结果。
fn pp_available() -> Bool {
  if !pr_available() {
    return false
  }
  match pr_run("powerprofilesctl", ["get"], timeout_ms=3000) {
    Ok(_) => true
    Err(_) => false
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持电源计划（Linux：powerprofilesctl 存在且可查询；
/// Windows：电源计划 API 恒在）。每次调用真实探测，高频场景请调用方
/// 自行缓存结果。
pub fn pp_supported() -> Bool {
  if @yue.platform() == "windows" {
    return true
  }
  pp_available()
}

///|
/// 可用电源计划列表（Linux 按 `powerprofilesctl list` 输出序；Windows 枚举
/// 系统电源方案，未知 GUID 的自定义方案跳过）。查询失败 →
/// PpCommandFailed；解析不到任何已知计划 → PpParseFailed。
pub fn pp_profiles() -> Result[Array[PowerProfile], PowerProfileError] {
  if @yue.platform() == "windows" {
    return pp_win_profiles()
  }
  if !pr_available() {
    return Err(PpUnsupported)
  }
  match pp_run(["list"]) {
    Err(e) => Err(e)
    Ok(out) => {
      let profiles = pp_parse_profile_list(out)
      if profiles.length() == 0 {
        Err(PpParseFailed("powerprofilesctl list: \{pp_first_line(out)}"))
      } else {
        Ok(profiles)
      }
    }
  }
}

///|
/// 当前电源计划（Linux：`powerprofilesctl get`；Windows 读活动方案 GUID
/// 映射三档计划）。查询失败 → PpCommandFailed；活动方案是自定义方案 →
/// PpParseFailed（带 GUID）。
pub fn pp_current() -> Result[PowerProfile, PowerProfileError] {
  if @yue.platform() == "windows" {
    return pp_win_current()
  }
  if !pr_available() {
    return Err(PpUnsupported)
  }
  match pp_run(["get"]) {
    Err(e) => Err(e)
    Ok(out) =>
      match pp_parse_current(out) {
        Some(p) => Ok(p)
        None =>
          Err(PpParseFailed("powerprofilesctl get: \{pp_first_line(out)}"))
      }
  }
}

///|
/// 切换电源计划（`powerprofilesctl set <计划>`；有副作用，需要认证，
/// 调用方自行走授权流程）。power-profiles-daemon 未安装 → PpUnsupported；
/// 查询与执行失败 → PpCommandFailed。
pub fn pp_set(profile : PowerProfile) -> Result[Unit, PowerProfileError] {
  if @yue.platform() == "windows" {
    return pp_win_set(profile)
  }
  if !pr_available() {
    return Err(PpUnsupported)
  }
  match pr_run("powerprofilesctl", pp_set_args(profile), timeout_ms=4000) {
    Ok(_) => Ok(())
    Err(NonZeroExit(127, _)) => Err(PpUnsupported)
    Err(NonZeroExit(code, err)) =>
      Err(
        PpCommandFailed(
          "powerprofilesctl set: 退出码 \{code}（\{pp_first_line(err)}）",
        ),
      )
    Err(Timeout(m)) => Err(PpCommandFailed(m))
    Err(SpawnFailed(m)) => Err(PpCommandFailed(m))
    Err(Signaled(sig)) =>
      Err(PpCommandFailed("powerprofilesctl set: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(PpUnsupported)
  }
}

// ---------------------------------------------------------------------------
// Windows 实现：电源方案 GUID ↔ 三档计划映射（powrprof 直连）
// ---------------------------------------------------------------------------

///|
/// 半字节值 → 十六进制字符（小写）。
fn pp_hex_digit(d : Int) -> Char {
  if d < 10 {
    (d + 48).unsafe_to_char()
  } else {
    (d + 87).unsafe_to_char()
  }
}

///|
/// GUID 内存字节（小端前三字段）→ canonical 文本形（"381b4222-…"，
/// 便于比对与错误信息呈现）。
pub fn pp_guid_text(b : Bytes, off : Int) -> String {
  let sb = StringBuilder()
  let write_byte = fn(i : Int) {
    let v = b[off + i].to_int()
    sb.write_char(pp_hex_digit(v >> 4))
    sb.write_char(pp_hex_digit(v & 15))
  }
  for i = 3; i >= 0; i = i - 1 {
    write_byte(i)
  }
  sb.write_char('-')
  for i = 5; i >= 4; i = i - 1 {
    write_byte(i)
  }
  sb.write_char('-')
  for i = 7; i >= 6; i = i - 1 {
    write_byte(i)
  }
  sb.write_char('-')
  write_byte(8)
  write_byte(9)
  sb.write_char('-')
  for i = 10; i < 16; i = i + 1 {
    write_byte(i)
  }
  sb.to_string()
}

///|
/// 系统内置三档方案的 GUID canonical 文本（Windows 电源方案注册表同款）。
let pp_win_guids : Array[(PowerProfile, String)] = [
  (PPerformance, "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"),
  (PBalanced, "381b4222-f694-41f0-9685-ff5bb260df2e"),
  (PPowerSaver, "a1841308-3541-4fab-bc81-f71556f20b4a"),
]

///|
/// GUID 文本 → 计划（未知为 None）。
fn pp_profile_of_guid(text : String) -> PowerProfile? {
  for pair in pp_win_guids {
    if pair.1 == text {
      return Some(pair.0)
    }
  }
  None
}

///|
/// 十六进制字符 → 半字节值（非法字符为 None）。
fn pp_nibble(c : Int) -> Int? {
  if c >= 48 && c <= 57 {
    Some(c - 48)
  } else if c >= 97 && c <= 102 {
    Some(c - 87)
  } else if c >= 65 && c <= 70 {
    Some(c - 55)
  } else {
    None
  }
}

///|
/// GUID 文本（canonical 形，'-' 可有可无）的小端内存字节（前三段字节
/// 反转、后两段原序）。
pub fn pp_guid_bytes(text : String) -> Bytes {
  let digits : Array[Int] = []
  for i = 0; i < text.length(); i = i + 1 {
    let c = text.unsafe_get(i).to_int()
    if c != 45 {
      digits.push(c) // '-'
    }
  }
  let canonical = FixedArray::make(16, b'\x00')
  for i = 0; i < 16 && i * 2 + 1 < digits.length(); i = i + 1 {
    let hi = match pp_nibble(digits[i * 2]) {
      Some(v) => v
      None => 0
    }
    let lo = match pp_nibble(digits[i * 2 + 1]) {
      Some(v) => v
      None => 0
    }
    canonical[i] = ((hi * 16) + lo).to_byte()
  }
  // 内存布局:Data1(4B 小端) Data2(2B) Data3(2B) Data4(8B 原序)
  let out = FixedArray::make(16, b'\x00')
  for i = 0; i < 4; i = i + 1 {
    out[i] = canonical[3 - i]
  }
  for i = 0; i < 2; i = i + 1 {
    out[4 + i] = canonical[5 - i]
  }
  for i = 0; i < 2; i = i + 1 {
    out[6 + i] = canonical[7 - i]
  }
  for i = 8; i < 16; i = i + 1 {
    out[i] = canonical[i]
  }
  Bytes::from_array(out)
}

///|
/// Windows 枚举电源方案：逐 GUID 映射三档计划（未知方案跳过），保持
/// 枚举序（系统注册序）。
fn pp_win_profiles() -> Result[Array[PowerProfile], PowerProfileError] {
  let buf = Bytes::make(16 * 16, b'0')
  let ok = Ref(0)
  let count = @yue.ffi_power_enumerate_guids(buf, 16, ok)
  if ok.val != 1 || count < 0 {
    return Err(PpCommandFailed("PowerEnumerate 失败（\{count}）"))
  }
  let out : Array[PowerProfile] = []
  for i = 0; i < count; i = i + 1 {
    match pp_profile_of_guid(pp_guid_text(buf, i * 16)) {
      Some(p) => out.push(p)
      None => ()
    }
  }
  if out.is_empty() {
    return Err(PpParseFailed("无已知电源方案"))
  }
  Ok(out)
}

///|
/// Windows 当前方案：活动 GUID 映射三档，自定义方案 → PpParseFailed 带 GUID。
fn pp_win_current() -> Result[PowerProfile, PowerProfileError] {
  let buf = Bytes::make(16, b'0')
  let ok = Ref(0)
  let r = @yue.ffi_power_active_guid(buf, ok)
  if r != 0 || ok.val != 1 {
    return Err(PpCommandFailed("PowerGetActiveScheme 失败（\{r}）"))
  }
  let text = pp_guid_text(buf, 0)
  match pp_profile_of_guid(text) {
    Some(p) => Ok(p)
    None => Err(PpParseFailed("自定义电源方案: \{text}"))
  }
}

///|
/// Windows 切换方案（PowerSetActiveScheme，需要管理员权限）。
fn pp_win_set(profile : PowerProfile) -> Result[Unit, PowerProfileError] {
  let guid = match pp_profile_of_guid_match(profile) {
    Some(g) => g
    None => return Err(PpCommandFailed("无内置方案 GUID"))
  }
  let ok = Ref(0)
  let r = @yue.ffi_power_set_guid(pp_guid_bytes(guid), ok)
  if r != 0 || ok.val != 1 {
    return Err(
      PpCommandFailed("PowerSetActiveScheme 失败（错误码 \{r}，需管理员）"),
    )
  }
  Ok(())
}

///|
/// 计划 → 内置方案 GUID 文本。
fn pp_profile_of_guid_match(profile : PowerProfile) -> String? {
  for pair in pp_win_guids {
    let same = match (pair.0, profile) {
      (PPerformance, PPerformance) => true
      (PBalanced, PBalanced) => true
      (PPowerSaver, PPowerSaver) => true
      _ => false
    }
    if same {
      return Some(pair.1)
    }
  }
  None
}
