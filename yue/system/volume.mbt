// 系统音量（默认输出设备）：经 procrun 的 pr_run 调命令行工具读取与
// 设置。wpctl 优先（PipeWire/WirePlumber），不可用时回退 pactl（
// pipewire-pulse / PulseAudio），两者都不可用即不支持。子进程环境由
// procrun 固定 C locale，输出语言固定可解析。输出解析与命令构造均为
// 纯函数，volume_wbtest.mbt 白盒覆盖。
//
// 文件内含两组 API：vol_ 前缀的第一批能力（默认 sink 的读/设音量/
// 增减/静音），以及 volx_ 前缀的增强能力（设备枚举、默认设备切换、
// 逐应用播放流音量）。volx_ 组依赖 pactl（wpctl 无等价的设备枚举与
// 逐流接口），单独探测门控，不影响 vol_ 组行为。

///|
/// 音量快照：默认 sink 名（wpctl 为显示名、pactl 为节点名，取不到为
/// 空串）、音量百分比 0-100、是否静音。
pub(all) struct VolumeInfo {
  sink : String
  volume : Int
  muted : Bool
}

///|
pub impl Show for VolumeInfo with fn output(self, logger) {
  logger.write_string("VolumeInfo { sink: ")
  logger.write_string(self.sink)
  logger.write_string(", volume: ")
  logger.write_string(self.volume.to_string())
  logger.write_string(", muted: ")
  logger.write_string(self.muted.to_string())
  logger.write_string(" }")
}

///|
pub extend VolumeInfo with Show::{to_string, output}

///|
pub(all) enum VolumeError {
  /// 系统无可用音量工具（wpctl 与 pactl 均不可用）
  Unsupported
  /// 命令执行失败（spawn 失败 / 非零退出码 / 超时 / 被信号终止），带原因
  CommandFailed(String)
  /// 工具输出解析失败，带原文
  ParseFailed(String)
}

///|
pub impl Show for VolumeError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("VolumeError::Unsupported")
    CommandFailed(m) => logger.write_string("VolumeError::CommandFailed(\{m})")
    ParseFailed(m) => logger.write_string("VolumeError::ParseFailed(\{m})")
  }
}

///|
pub extend VolumeError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：文本工具 / 输出解析 / 命令构造（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn vol_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 按空白切分 token（连续空白视为一个分隔符，首尾空白忽略）。
fn vol_split_ws(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = StringBuilder()
  let mut has = false
  for ch in s {
    if vol_is_ws(ch) {
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
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn vol_split_lines(s : String) -> Array[String] {
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
/// 去首尾空白。
fn vol_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && vol_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && vol_is_ws(chars[j]) {
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
/// 首字符（空串为 None）。
fn vol_first_char(s : String) -> Char? {
  for ch in s {
    return Some(ch)
  }
  None
}

///|
/// 无符号整数文本（"100" → 100；空串或含非数字为 None）。
fn vol_parse_uint(s : String) -> Int? {
  if s == "" {
    return None
  }
  let mut v = 0
  for ch in s {
    if ch < '0' || ch > '9' {
      return None
    }
    v = v * 10 + (ch.to_int() - 48)
  }
  Some(v)
}

///|
/// 剥掉指定结尾字符（末字符不匹配或空串为 None）。
fn vol_strip_suffix(s : String, suffix : Char) -> String? {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let last = chars.length() - 1
  if last < 0 || chars[last] != suffix {
    return None
  }
  let buf = StringBuilder()
  for i in 0..<last {
    buf.write_char(chars[i])
  }
  Some(buf.to_string())
}

///|
/// 音量百分比钳到 0..100。
fn vol_clamp_percent(p : Int) -> Int {
  if p < 0 {
    0
  } else if p > 100 {
    100
  } else {
    p
  }
}

///|
/// wpctl 音量文本 → 百分比整数（"0.42" → 42，两位小数内四舍五入，
/// "1.00" → 100，超量程如实返回如 "1.20" → 120；非法为 None）。
fn vol_parse_volume_text(tok : String) -> Int? {
  let mut ip = 0
  let mut int_any = false
  let mut seen_dot = false
  let mut frac1 = -1
  let mut frac2 = -1
  let mut frac3 = -1
  for ch in tok {
    if ch == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
    } else if ch >= '0' && ch <= '9' {
      let d = ch.to_int() - 48
      if !seen_dot {
        ip = ip * 10 + d
        int_any = true
      } else if frac1 < 0 {
        frac1 = d
      } else if frac2 < 0 {
        frac2 = d
      } else if frac3 < 0 {
        frac3 = d
      }
    } else {
      return None
    }
  }
  if !int_any || (seen_dot && frac1 < 0) {
    return None
  }
  let f1 = if frac1 >= 0 { frac1 } else { 0 }
  let f2 = if frac2 >= 0 { frac2 } else { 0 }
  let mut cents = f1 * 10 + f2
  if frac3 >= 5 {
    cents = cents + 1
  }
  Some(ip * 100 + cents)
}

///|
/// 解析 `wpctl get-volume @DEFAULT_SINK@` 输出：
/// "Volume: 0.42" / "Volume: 0.42 [MUTED]" → (百分比 0-100, 是否静音)。
fn vol_parse_wpctl_volume(out : String) -> (Int, Bool)? {
  let toks = vol_split_ws(out)
  if toks.length() < 2 || toks[0] != "Volume:" {
    return None
  }
  let muted = toks.contains("[MUTED]")
  match vol_parse_volume_text(toks[1]) {
    None => None
    Some(v) => Some((vol_clamp_percent(v), muted))
  }
}

///|
/// wpctl status 默认 sink 行（`*   33. 名称 [vol: 1.00]`）→ 名称：
/// 去 '*' 标记、去节点编号前缀、去方括号尾巴。
fn vol_sink_name_from_star_line(line : String) -> String? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let n = chars.length()
  let mut star = -1
  for i in 0..<n {
    if chars[i] == '*' {
      star = i
      break
    }
  }
  if star < 0 {
    return None
  }
  // 编号前缀 "33. " 的点（点后跟空格，取首个）
  let mut dot = -1
  let mut i = star + 1
  while i < n - 1 {
    if chars[i] == '.' && chars[i + 1] == ' ' {
      dot = i
      break
    }
    i = i + 1
  }
  // 方括号尾巴 "[vol: ...]" 的起点
  let jstart = star + 1
  let mut end = n
  for j in jstart..<n {
    if chars[j] == '[' {
      end = j
      break
    }
  }
  let from = if dot >= 0 && dot < end { dot + 1 } else { star + 1 }
  let buf = StringBuilder()
  let mut k = from
  while k < end {
    buf.write_char(chars[k])
    k = k + 1
  }
  let name = vol_trim(buf.to_string())
  if name == "" {
    None
  } else {
    Some(name)
  }
}

///|
/// 解析 `wpctl status` 输出：取 Audio 段 Sinks 小节带 '*' 的默认 sink
/// 显示名（Video 段同名小节与 Sources 小节的 '*' 不取）。
fn vol_parse_wpctl_status_sink(status : String) -> String? {
  let mut in_audio = false
  let mut in_sinks = false
  for line in vol_split_lines(status) {
    match vol_first_char(line) {
      Some(c) =>
        if !vol_is_ws(c) {
          // 顶格段落标题切换段落
          if line.has_prefix("Audio") {
            in_audio = true
            in_sinks = false
          } else if line.has_prefix("Video") || line.has_prefix("Settings") {
            in_audio = false
            in_sinks = false
          }
        } else if in_audio {
          if line.contains("Sinks:") {
            in_sinks = true
          } else if line.contains("Sources:") {
            in_sinks = false
          } else if in_sinks && line.contains("*") {
            return vol_sink_name_from_star_line(line)
          }
        }
      None => ()
    }
  }
  None
}

///|
/// 解析 `pactl get-sink-volume` 输出：取全部 `N%` 形态百分比的最大值
/// （各声道不一致时以最响为准）。
/// 样例："Volume: front-left: 65536 / 100% / 0.00 dB,  front-right: ...".
fn vol_parse_pactl_percent(out : String) -> Int? {
  let mut best : Int? = None
  for tok in vol_split_ws(out) {
    match vol_strip_suffix(tok, '%') {
      None => ()
      Some(numtxt) =>
        match vol_parse_uint(numtxt) {
          None => ()
          Some(v) =>
            match best {
              None => best = Some(v)
              Some(b) => if v > b { best = Some(v) }
            }
        }
    }
  }
  best
}

///|
/// 解析 `pactl get-sink-mute` 输出："Mute: yes" / "Mute: no"（仅认
/// C locale 输出，本地化文案为 None）。
fn vol_parse_pactl_mute(out : String) -> Bool? {
  let toks = vol_split_ws(out)
  if toks.length() >= 2 && toks[0] == "Mute:" {
    if toks[1] == "yes" {
      return Some(true)
    }
    if toks[1] == "no" {
      return Some(false)
    }
  }
  None
}

// ---------------------------------------------------------------------------
// 命令构造（两后端参数语法差异集中在此）
// ---------------------------------------------------------------------------

///|
/// 音量后端（内部探测结果）。
priv enum VolBackend {
  Wpctl
  Pactl
}

///|
/// 后端对应的命令名。
fn vol_prog(b : VolBackend) -> String {
  match b {
    Wpctl => "wpctl"
    Pactl => "pactl"
  }
}

///|
/// 设绝对音量的参数表（入参钳 0..100；两后端百分比语法相同）。
fn vol_set_args(b : VolBackend, percent : Int) -> Array[String] {
  let p = vol_clamp_percent(percent)
  match b {
    Wpctl => ["set-volume", "@DEFAULT_SINK@", "\{p}%"]
    Pactl => ["set-sink-volume", "@DEFAULT_SINK@", "\{p}%"]
  }
}

///|
/// 相对增减音量的参数表（wpctl 相对量后缀 "5%+"/"5%-"，pactl 前缀
/// "+5%"/"-5%"，delta 为负即减）。
fn vol_add_args(b : VolBackend, delta : Int) -> Array[String] {
  let step = if delta < 0 { -delta } else { delta }
  match b {
    Wpctl => {
      let arg = if delta >= 0 { "\{step}%+" } else { "\{step}%-" }
      ["set-volume", "@DEFAULT_SINK@", arg]
    }
    Pactl => {
      let arg = if delta >= 0 { "+\{step}%" } else { "-\{step}%" }
      ["set-sink-volume", "@DEFAULT_SINK@", arg]
    }
  }
}

///|
/// 设静音的参数表（1 静音、0 取消）。
fn vol_mute_args(b : VolBackend, mute : Bool) -> Array[String] {
  let flag = if mute { "1" } else { "0" }
  match b {
    Wpctl => ["set-mute", "@DEFAULT_SINK@", flag]
    Pactl => ["set-sink-mute", "@DEFAULT_SINK@", flag]
  }
}

// ---------------------------------------------------------------------------
// 子进程执行封装（复用 procrun 的 [pr_run]：spawn → 限时回收 → 读临时
// 文件输出；非零退出还原为 (退出码, stdout) 供后端探测按退出码分流）
// ---------------------------------------------------------------------------

///|
/// 运行命令并捕获标准输出：底层走 [pr_run]，把非零退出还原为
/// (退出码, stdout) 正常返回——wpctl/pactl 在服务不在线时以非零退出
/// 呈现属正常分支，由调用方按退出码分流；其余错误映射为 VolumeError。
fn vol_run_capture(
  prog : String,
  args : Array[String],
  timeout_ms? : Int = 4000,
) -> Result[(Int, String), VolumeError] {
  match pr_run(prog, args, timeout_ms~) {
    Ok(o) => Ok((o.exit_code, o.stdout))
    Err(NonZeroExit(code, _)) => Ok((code, ""))
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) => Err(CommandFailed("\{prog}: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(CommandFailed("\{prog}: 子进程执行不可用"))
  }
}

///|
/// 探测可用后端：能跑通只读查询（工具存在且音量服务在线）即视为可用，
/// wpctl 优先。每次调用真实探测。
fn vol_backend() -> VolBackend? {
  match vol_run_capture("wpctl", ["get-volume", "@DEFAULT_SINK@"]) {
    Ok((0, _)) => Some(Wpctl)
    _ =>
      match vol_run_capture("pactl", ["get-default-sink"]) {
        Ok((0, _)) => Some(Pactl)
        _ => None
      }
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持音量控制（Linux：wpctl 或 pactl 任一可用；Windows：
/// 默认输出端点可打开）。每次调用真实探测，高频场景请调用方自行缓存。
pub fn vol_supported() -> Bool {
  if @yue.platform() == "windows" {
    let level = Ref(0.0)
    let muted = Ref(0)
    let ok = Ref(0)
    let _ = @yue.ffi_vol_master(level, muted, ok)
    ok.val == 1
  } else {
    vol_backend() is Some(_)
  }
}

///|
/// 读默认输出音量快照（sink 名 / 音量 0-100 / 是否静音）。Linux 的
/// wpctl 路径两次查询（get-volume + status 取显示名），pactl 路径三次
/// 查询（get-default-sink + get-sink-volume + get-sink-mute）；sink 名
/// 为次要信息，取不到置空串不影响音量与静音。Windows 走默认输出端点
/// （Core Audio 标量音量 0..1 换算百分比，sink 名无对应置空串）。
pub fn vol_get() -> Result[VolumeInfo, VolumeError] {
  if @yue.platform() == "windows" {
    let level = Ref(0.0)
    let muted = Ref(0)
    let ok = Ref(0)
    if @yue.ffi_vol_master(level, muted, ok) != 0 || ok.val != 1 {
      return Err(CommandFailed("Core Audio 默认输出端点不可用"))
    }
    // 0..1 标量 → 百分比（四舍五入，与 wpctl 路径同口径）
    let volume = (level.val * 100.0 + 0.5) |> Double::to_int |> vol_clamp_percent
    return Ok({ sink: "", volume, muted: muted.val == 1, })
  }
  match vol_backend() {
    None => Err(Unsupported)
    Some(Wpctl) => vol_get_wpctl()
    Some(Pactl) => vol_get_pactl()
  }
}

///|
/// wpctl 路径读取。
fn vol_get_wpctl() -> Result[VolumeInfo, VolumeError] {
  match vol_run_capture("wpctl", ["get-volume", "@DEFAULT_SINK@"]) {
    Err(e) => Err(e)
    Ok((code, out)) => {
      if code != 0 {
        return Err(CommandFailed("wpctl get-volume: 退出码 \{code}"))
      }
      match vol_parse_wpctl_volume(out) {
        None => Err(ParseFailed("wpctl get-volume: \{vol_trim(out)}"))
        Some((volume, muted)) => {
          let sink = match vol_run_capture("wpctl", ["status"]) {
            Ok((0, st)) =>
              match vol_parse_wpctl_status_sink(st) {
                Some(name) => name
                None => ""
              }
            _ => ""
          }
          Ok({ sink, volume, muted, })
        }
      }
    }
  }
}

///|
/// pactl 路径读取。
fn vol_get_pactl() -> Result[VolumeInfo, VolumeError] {
  let sink = match vol_run_capture("pactl", ["get-default-sink"]) {
    Ok((0, o)) => vol_trim(o)
    _ => ""
  }
  let volume = match
    vol_run_capture("pactl", ["get-sink-volume", "@DEFAULT_SINK@"]) {
    Err(e) => return Err(e)
    Ok((code, out)) => {
      if code != 0 {
        return Err(CommandFailed("pactl get-sink-volume: 退出码 \{code}"))
      }
      match vol_parse_pactl_percent(out) {
        Some(v) => v
        None =>
          return Err(ParseFailed("pactl get-sink-volume: \{vol_trim(out)}"))
      }
    }
  }
  let muted = match
    vol_run_capture("pactl", ["get-sink-mute", "@DEFAULT_SINK@"]) {
    Err(e) => return Err(e)
    Ok((code, out)) => {
      if code != 0 {
        return Err(CommandFailed("pactl get-sink-mute: 退出码 \{code}"))
      }
      match vol_parse_pactl_mute(out) {
        Some(m) => m
        None => return Err(ParseFailed("pactl get-sink-mute: \{vol_trim(out)}"))
      }
    }
  }
  Ok({ sink, volume, muted, })
}

///|
/// 执行后端命令并按退出码归一结果（0 为成功）。
fn vol_apply(prog : String, args : Array[String]) -> Result[Unit, VolumeError] {
  match vol_run_capture(prog, args) {
    Err(e) => Err(e)
    Ok((0, _)) => Ok(())
    Ok((code, _)) => Err(CommandFailed("\{prog}: 退出码 \{code}"))
  }
}

///|
/// 设绝对音量（0-100，出界钳制），作用于默认 sink / 默认输出端点。
pub fn vol_set(percent : Int) -> Result[Unit, VolumeError] {
  if @yue.platform() == "windows" {
    return vol_win_apply(vol_clamp_percent(percent).to_double() / 100.0, None)
  }
  match vol_backend() {
    None => Err(Unsupported)
    Some(b) => vol_apply(vol_prog(b), vol_set_args(b, percent))
  }
}

///|
/// Windows 写操作公共实现：level 为标量音量，mute 为 None 表示不改静音。
fn vol_win_apply(
  level : Double,
  mute : Bool?,
) -> Result[Unit, VolumeError] {
  let ok = Ref(0)
  let r = match mute {
    Some(m) => @yue.ffi_vol_set_mute(if m { 1 } else { 0 }, ok)
    None => @yue.ffi_vol_set_master(level, ok)
  }
  if r != 0 || ok.val != 1 {
    return Err(CommandFailed("Core Audio 音量操作失败（\{r}）"))
  }
  Ok(())
}

///|
/// 相对增减音量（delta 为正增、为负减，作用于默认 sink / 默认输出端点；
/// Linux 每步量取绝对值交给工具的相对语法执行，Windows 先读当前值加
/// delta 钳制后设置，最终音量均由后端钳制）。
pub fn vol_add(delta : Int) -> Result[Unit, VolumeError] {
  if @yue.platform() == "windows" {
    let cur = match vol_get() {
      Ok(info) => info.volume
      Err(e) => return Err(e)
    }
    return vol_win_apply(vol_clamp_percent(cur + delta).to_double() / 100.0, None)
  }
  match vol_backend() {
    None => Err(Unsupported)
    Some(b) => vol_apply(vol_prog(b), vol_add_args(b, delta))
  }
}

///|
/// 设 / 取消默认 sink / 默认输出端点静音。
pub fn vol_set_mute(mute : Bool) -> Result[Unit, VolumeError] {
  if @yue.platform() == "windows" {
    return vol_win_apply(0.0, Some(mute))
  }
  match vol_backend() {
    None => Err(Unsupported)
    Some(b) => vol_apply(vol_prog(b), vol_mute_args(b, mute))
  }
}

// ---------------------------------------------------------------------------
// 增强能力：设备枚举 / 默认设备切换 / 逐应用播放流音量（volx_ 前缀）
// wpctl 不暴露设备枚举与逐流接口，本组固定走 pactl；可用性由
// [volx_pactl_ready] 单独探测，不依赖也不影响 [vol_backend] 的选择。
// ---------------------------------------------------------------------------

///|
/// 音量输出设备：name 为 pactl 节点名（[volx_set_default] 即用它），
/// description 为人类可读名称（`pactl list sinks` 的 Description，
/// 取不到为空串），is_default 标注枚举时是否为默认输出设备。
pub(all) struct AudioDevice {
  name : String
  description : String
  is_default : Bool
}

///|
pub impl Show for AudioDevice with fn output(self, logger) {
  logger.write_string("AudioDevice { name: ")
  logger.write_string(self.name)
  logger.write_string(", description: ")
  logger.write_string(self.description)
  logger.write_string(", is_default: ")
  logger.write_string(self.is_default.to_string())
  logger.write_string(" }")
}

///|
pub extend AudioDevice with Show::{to_string, output}

///|
/// 单个应用的播放流（sink-input）：index 为流序号，[volx_set_app_volume]
/// 与 [volx_set_app_mute] 以它定位；app_name 取 application.name 属性
/// （缺省回落 node.name，再缺省 "unknown"）；volume 为该流音量百分比
/// 0-100（各声道不一致取最响）；muted 为该流是否静音。
pub(all) struct AppStream {
  index : Int
  app_name : String
  volume : Int
  muted : Bool
}

///|
pub impl Show for AppStream with fn output(self, logger) {
  logger.write_string("AppStream { index: ")
  logger.write_string(self.index.to_string())
  logger.write_string(", app_name: ")
  logger.write_string(self.app_name)
  logger.write_string(", volume: ")
  logger.write_string(self.volume.to_string())
  logger.write_string(", muted: ")
  logger.write_string(self.muted.to_string())
  logger.write_string(" }")
}

///|
pub extend AppStream with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：pactl 列表输出解析 / 命令构造（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 文本是否以指定字符串开头（逐字符比较，键长按字符数计）。
fn volx_starts_with(s : String, key : String) -> Bool {
  let ks : Array[Char] = []
  for ch in key {
    ks.push(ch)
  }
  let ss : Array[Char] = []
  for ch in s {
    ss.push(ch)
  }
  if ss.length() < ks.length() {
    return false
  }
  for i in 0..<ks.length() {
    if ss[i] != ks[i] {
      return false
    }
  }
  true
}

///|
/// 取 "字段名: 值" 行中字段名（key 含结尾冒号，如 "Volume:"）之后的值
/// （行文本先 trim，缩进符同样可判；该行不是此字段为 None）。key 自身
/// 必须以 ':' 结尾，否则一律不中——防 "Volume" 误中 "Volume:" 行。
fn volx_field(line : String, key : String) -> String? {
  let keys : Array[Char] = []
  for ch in key {
    keys.push(ch)
  }
  if keys.length() == 0 || keys[keys.length() - 1] != ':' {
    return None
  }
  let l = vol_trim(line)
  if !volx_starts_with(l, key) {
    return None
  }
  let chars : Array[Char] = []
  for ch in l {
    chars.push(ch)
  }
  let buf = StringBuilder()
  let mut i = keys.length()
  while i < chars.length() {
    buf.write_char(chars[i])
    i = i + 1
  }
  Some(vol_trim(buf.to_string()))
}

///|
/// 去掉属性值外层包裹的成对引号（`"pacat"` → pacat；无引号原样返回）。
fn volx_unquote(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  if n >= 2 && chars[0] == '"' && chars[n - 1] == '"' {
    let buf = StringBuilder()
    let mut i = 1
    while i < n - 1 {
      buf.write_char(chars[i])
      i = i + 1
    }
    buf.to_string()
  } else {
    s
  }
}

///|
/// 拆 "key = \"value\"" 属性行为 (key, value)（value 去首尾空白与包裹
/// 引号；行内无 '=' 为 None）。仅用于属性段，Mute:/Volume: 等冒号字段
/// 不含 '='，不会命中。
fn volx_kv(line : String) -> (String, String)? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  for i in 0..<chars.length() {
    if chars[i] == '=' {
      let kb = StringBuilder()
      let mut j = 0
      while j < i {
        kb.write_char(chars[j])
        j = j + 1
      }
      let vb = StringBuilder()
      let mut k = i + 1
      while k < chars.length() {
        vb.write_char(chars[k])
        k = k + 1
      }
      return Some(
        (vol_trim(kb.to_string()), volx_unquote(vol_trim(vb.to_string()))),
      )
    }
  }
  None
}

///|
/// 取小节标题行里的对象序号（"Sink Input #386" → 386）：认最后一个
/// '#' 之后的十进制数字，标题用什么语言不关心（C locale 下即 Sink /
/// Sink Input 标题）。
fn volx_block_index(line : String) -> Int? {
  let chars : Array[Char] = []
  for ch in line {
    chars.push(ch)
  }
  let n = chars.length()
  let mut at = -1
  for i in 0..<n {
    if chars[i] == '#' {
      at = i
    }
  }
  if at < 0 {
    return None
  }
  let buf = StringBuilder()
  let mut i = at + 1
  while i < n {
    buf.write_char(chars[i])
    i = i + 1
  }
  vol_parse_uint(vol_trim(buf.to_string()))
}

///|
/// 是否小节标题行：顶格（首字符非空白）且带对象序号。pactl 的块标题
/// （"Sink #49" / "Sink Input #386"）顶格输出，字段行与属性行均缩进，
/// 据此分块可避开属性值里的 '#'（如 "subdevice #0"）。
fn volx_is_block_head(line : String) -> Bool {
  match vol_first_char(line) {
    Some(c) => !vol_is_ws(c) && volx_block_index(line) is Some(_)
    None => false
  }
}

///|
/// 按小节标题切分列表输出，返回 [(标题行, 小节正文)]（标题已 trim）；
/// 标题行之前的文本被忽略。
fn volx_split_blocks(out : String) -> Array[(String, String)] {
  let blocks : Array[(String, String)] = []
  let mut head : String? = None
  let mut body = StringBuilder()
  for line in vol_split_lines(out) {
    if volx_is_block_head(line) {
      match head {
        Some(h) => blocks.push((h, body.to_string()))
        None => ()
      }
      head = Some(vol_trim(line))
      body = StringBuilder()
    } else {
      match head {
        Some(_) => {
          body.write_string(line)
          body.write_char('\n')
        }
        None => ()
      }
    }
  }
  match head {
    Some(h) => blocks.push((h, body.to_string()))
    None => ()
  }
  blocks
}

///|
/// yes/no 文本 → 布尔（仅认 C locale 的 yes/no，本地化文案为 None）。
fn volx_yes_no(v : String) -> Bool? {
  if v == "yes" {
    Some(true)
  } else if v == "no" {
    Some(false)
  } else {
    None
  }
}

///|
/// 解析 `pactl list short sinks` 输出：每行
/// "INDEX\tNAME\tDRIVER\tSAMPLE_SPEC\tSTATE"（Tab 分隔），取 name 构成
/// 设备；index 只用于确认该行是数据行。description 与 is_default 留空，
/// 由 [volx_devices] 另行补全。行首不是十进制序号即跳过。
fn volx_parse_short_sinks(out : String) -> Array[AudioDevice] {
  let devs : Array[AudioDevice] = []
  for line in vol_split_lines(out) {
    let toks = vol_split_ws(line)
    if toks.length() >= 2 {
      match vol_parse_uint(toks[0]) {
        Some(_) =>
          devs.push({ name: toks[1], description: "", is_default: false, })
        None => ()
      }
    }
  }
  devs
}

///|
/// 解析 `pactl list sinks` 输出里的 Name / Description 字段对：每个
/// 小节的 Name 行在 Description 行之前，配成一对即消费（防止属性段的
/// device.description 等被误配）；没等到 Description 的 Name 不入列。
fn volx_parse_sink_pairs(out : String) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  let mut name : String? = None
  for line in vol_split_lines(out) {
    let l = vol_trim(line)
    match volx_field(l, "Name:") {
      Some(v) => name = Some(v)
      None => ()
    }
    match name {
      None => ()
      Some(n) =>
        match volx_field(l, "Description:") {
          Some(v) => {
            pairs.push((n, v))
            name = None
          }
          None => ()
        }
    }
  }
  pairs
}

///|
/// 在 (name, description) 对里按 name 查描述（取首个非空命中，查不到
/// 为空串）。
fn volx_lookup(pairs : Array[(String, String)], name : String) -> String {
  for p in pairs {
    if p.0 == name && p.1 != "" {
      return p.1
    }
  }
  ""
}

///|
/// 用 `pactl list sinks` 解析出的字段对补全设备描述（按 name 精确
/// 匹配；匹配不到留空，其余字段原样保留）。
fn volx_merge_descriptions(
  devs : Array[AudioDevice],
  sinks : String,
) -> Array[AudioDevice] {
  let pairs = volx_parse_sink_pairs(sinks)
  let out : Array[AudioDevice] = []
  for d in devs {
    out.push({
      name: d.name,
      description: volx_lookup(pairs, d.name),
      is_default: d.is_default,
    })
  }
  out
}

///|
/// 取小节正文里 "Volume:" 行的百分比（复用 [vol_parse_pactl_percent]，
/// 各声道取最大；无该行或解析失败为 None）。样例（C locale）：
/// "Volume: front-left: 0 /   0% / -inf dB,   front-right: 0 /   0% / -inf dB"。
fn volx_block_volume(body : String) -> Int? {
  for line in vol_split_lines(body) {
    if volx_field(line, "Volume:") is Some(_) {
      return vol_parse_pactl_percent(line)
    }
  }
  None
}

///|
/// 取小节正文里 "Mute:" 行的布尔值（C locale 认 yes/no，本地化文案
/// 为 None）。
fn volx_block_mute(body : String) -> Bool? {
  for line in vol_split_lines(body) {
    match volx_field(line, "Mute:") {
      Some(v) =>
        match volx_yes_no(v) {
          Some(m) => return Some(m)
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
/// 取小节正文里属性段 "key = \"value\"" 行中 key 的值（相同 key 多处
/// 出现取首个；找不到为 None）。样例：application.name = "pacat"。
fn volx_block_prop(body : String, key : String) -> String? {
  for line in vol_split_lines(body) {
    match volx_kv(vol_trim(line)) {
      Some((k, v)) => if k == key { return Some(v) }
      None => ()
    }
  }
  None
}

///|
/// 解析 `pactl list sink-inputs` 输出为逐应用播放流列表：小节标题
/// "Sink Input #386" 给 index，正文取 Mute:/Volume: 与应用属性。
/// volume 解析不到记 0、muted 解析不到记 false；app_name 取
/// application.name，缺省回落 node.name，再缺省 "unknown"。
fn volx_parse_sink_inputs(out : String) -> Array[AppStream] {
  let streams : Array[AppStream] = []
  for blk in volx_split_blocks(out) {
    match volx_block_index(blk.0) {
      None => ()
      Some(index) => {
        let vol = match volx_block_volume(blk.1) {
          Some(v) => v
          None => 0
        }
        let muted = match volx_block_mute(blk.1) {
          Some(m) => m
          None => false
        }
        let app = match volx_block_prop(blk.1, "application.name") {
          Some(n) => n
          None =>
            match volx_block_prop(blk.1, "node.name") {
              Some(n) => n
              None => "unknown"
            }
        }
        streams.push({ index, app_name: app, volume: vol, muted, })
      }
    }
  }
  streams
}

// ---------------------------------------------------------------------------
// 命令构造（pactl 专线：设备与逐流操作只有一套语法）
// ---------------------------------------------------------------------------

///|
/// 切换默认输出设备的参数表（pactl set-default-sink <name>）。
fn volx_set_default_args(name : String) -> Array[String] {
  ["set-default-sink", name]
}

///|
/// 设单个播放流音量的参数表（入参钳 0..100 后转 "N%"）。
fn volx_set_app_volume_args(index : Int, percent : Int) -> Array[String] {
  ["set-sink-input-volume", index.to_string(), "\{vol_clamp_percent(percent)}%"]
}

///|
/// 设单个播放流静音的参数表（1 静音、0 取消）。
fn volx_set_app_mute_args(index : Int, mute : Bool) -> Array[String] {
  let flag = if mute { "1" } else { "0" }
  ["set-sink-input-mute", index.to_string(), flag]
}

// ---------------------------------------------------------------------------
// pactl 执行封装（可用性探测 / 只读查询 / 写操作）
// ---------------------------------------------------------------------------

///|
/// pactl 是否可用（命令存在且 pipewire-pulse / PulseAudio 服务在线）：
/// 只读跑 `pactl info`，退出码 0 即可用。volx_ 组接口先过这道门。
fn volx_pactl_ready() -> Bool {
  match vol_run_capture("pactl", ["info"]) {
    Ok((0, _)) => true
    _ => false
  }
}

///|
/// 跑 pactl 命令并取 stdout（调用方需先过 [volx_pactl_ready] 门）：
/// 退出码 0 成功，非零为 CommandFailed，spawn 失败 / 超时 / 被信号
/// 终止按 [VolumeError] 映射。
fn volx_capture(args : Array[String]) -> Result[String, VolumeError] {
  match vol_run_capture("pactl", args) {
    Err(e) => Err(e)
    Ok((0, out)) => Ok(out)
    Ok((code, _)) => Err(CommandFailed("pactl \{args[0]}: 退出码 \{code}"))
  }
}

///|
/// 执行写操作 pactl 命令（忽略 stdout，退出码 0 为 Ok）。
fn volx_apply(args : Array[String]) -> Result[Unit, VolumeError] {
  match volx_capture(args) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

// ---------------------------------------------------------------------------
// 公开 API（volx_ 组：设备枚举 / 默认设备切换 / 逐应用播放流）
// ---------------------------------------------------------------------------

///|
/// 枚举音量输出设备：`pactl list short sinks` 取名、`pactl list sinks`
/// 补人类可读描述、`pactl get-default-sink` 标默认设备。无 pactl 或
/// 服务不在线为 Unsupported；空列表 = 服务在线但无输出设备。描述与
/// 默认标记是次要信息，取不到时分别留空 / 不标，不影响 name。
pub fn volx_devices() -> Result[Array[AudioDevice], VolumeError] {
  if !volx_pactl_ready() {
    return Err(Unsupported)
  }
  match volx_capture(["list", "short", "sinks"]) {
    Err(e) => Err(e)
    Ok(list) => {
      let base = volx_parse_short_sinks(list)
      let named = match volx_capture(["list", "sinks"]) {
        Ok(sinks) => volx_merge_descriptions(base, sinks)
        Err(_) => base
      }
      match volx_capture(["get-default-sink"]) {
        Ok(cur) => {
          let def = vol_trim(cur)
          let out : Array[AudioDevice] = []
          for d in named {
            out.push({
              name: d.name,
              description: d.description,
              is_default: d.name == def,
            })
          }
          Ok(out)
        }
        Err(_) => Ok(named)
      }
    }
  }
}

///|
/// 切换默认输出设备（pactl set-default-sink <name>，name 取
/// [volx_devices] 枚举出的 AudioDevice.name）。设备名为空为
/// CommandFailed；无 pactl 或服务不在线为 Unsupported。
pub fn volx_set_default(name : String) -> Result[Unit, VolumeError] {
  if !volx_pactl_ready() {
    return Err(Unsupported)
  }
  if name == "" {
    return Err(CommandFailed("pactl set-default-sink: 设备名为空"))
  }
  volx_apply(volx_set_default_args(name))
}

///|
/// 枚举逐应用播放流（`pactl list sink-inputs`）：index 供
/// [volx_set_app_volume] / [volx_set_app_mute] 定位，app_name 取
/// application.name 属性。无播放流返回空列表；无 pactl 或服务不在线为
/// Unsupported。
pub fn volx_app_streams() -> Result[Array[AppStream], VolumeError] {
  if !volx_pactl_ready() {
    return Err(Unsupported)
  }
  match volx_capture(["list", "sink-inputs"]) {
    Err(e) => Err(e)
    Ok(out) => Ok(volx_parse_sink_inputs(out))
  }
}

///|
/// 设单个应用播放流的音量（0-100，出界钳制；pactl set-sink-input-volume
/// <index> <N%>）。index 取 [volx_app_streams] 枚举出的
/// AppStream.index，负序号为 CommandFailed；无 pactl 或服务不在线为
/// Unsupported。
pub fn volx_set_app_volume(
  index : Int,
  percent : Int,
) -> Result[Unit, VolumeError] {
  if !volx_pactl_ready() {
    return Err(Unsupported)
  }
  if index < 0 {
    return Err(
      CommandFailed(
        "pactl set-sink-input-volume: 流序号非法（\{index}）",
      ),
    )
  }
  volx_apply(volx_set_app_volume_args(index, percent))
}

///|
/// 设 / 取消单个应用播放流的静音（pactl set-sink-input-mute <index>
/// <1|0>）。index 语义同 [volx_set_app_volume]，负序号为
/// CommandFailed；无 pactl 或服务不在线为 Unsupported。
pub fn volx_set_app_mute(index : Int, mute : Bool) -> Result[Unit, VolumeError] {
  if !volx_pactl_ready() {
    return Err(Unsupported)
  }
  if index < 0 {
    return Err(
      CommandFailed("pactl set-sink-input-mute: 流序号非法（\{index}）"),
    )
  }
  volx_apply(volx_set_app_mute_args(index, mute))
}
