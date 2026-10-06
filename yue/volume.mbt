// 系统音量（默认输出设备）：经 @subproc 调命令行工具读取与设置。
// wpctl 优先（PipeWire/WirePlumber），不可用时回退 pactl（pipewire-pulse
// / PulseAudio），两者都不可用即不支持。子进程环境强制 C locale，
// 输出语言固定可解析。输出解析与命令构造均为纯函数，
// volume_wbtest.mbt 白盒覆盖。

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
      Some(c) => {
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
      Some(numtxt) => {
        match vol_parse_uint(numtxt) {
          None => ()
          Some(v) => {
            match best {
              None => best = Some(v)
              Some(b) => if v > b {
                best = Some(v)
              }
            }
          }
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
// 子进程执行封装（@subproc：spawn → 限时回收 → 读临时文件输出）
// ---------------------------------------------------------------------------

///|
/// 临时文件名自增序号（与进程 pid 联合保证并发内唯一）。
let vol_tmp_counter : Ref[Int] = Ref(0)

///|
/// 临时输出文件路径（$TMPDIR 下，缺省 /tmp）。
fn vol_tmp_path(tag : String) -> String {
  vol_tmp_counter.val = vol_tmp_counter.val + 1
  let dir = match @env.get_env_var("TMPDIR") {
    Some(d) => if d != "" { d } else { "/tmp" }
    None => "/tmp"
  }
  "\{dir}/yue-vol-\{@subproc.get_pid()}-\{vol_tmp_counter.val}.\{tag}"
}

///|
/// 传给音量工具的子进程环境（NUL 分隔的 "K=V" blob）：PATH（命令名
/// 解析）、XDG_RUNTIME_DIR（PipeWire/Pulse 套接字定位）、HOME，并固定
/// C locale 使输出语言恒定可解析。
fn vol_env_blob() -> Bytes {
  let buf = StringBuilder()
  for name in ["PATH", "XDG_RUNTIME_DIR", "HOME"] {
    match @env.get_env_var(name) {
      Some(v) => {
        buf.write_string(name)
        buf.write_char('=')
        buf.write_string(v)
        buf.write_char('\u{0}')
      }
      None => ()
    }
  }
  buf.write_string("LC_ALL=C")
  buf.write_char('\u{0}')
  buf.write_char('\u{0}')
  @utf8.encode(buf.to_string())
}

///|
/// 运行命令并捕获标准输出：spawn（stdout/stderr 重定向到临时文件）→
/// 限时回收 → 读回输出文本。返回 (退出码, stdout)；spawn 失败 / 超时 /
/// 被信号终止为 Err，退出码非 0 属正常返回由调用方判断。
fn vol_run_capture(
  prog : String,
  args : Array[String],
  timeout_ms? : Int = 4000,
) -> Result[(Int, String), VolumeError] {
  let out_path = vol_tmp_path("out")
  let err_path = vol_tmp_path("err")
  // 多参数以 NUL 分隔拼入 script（spawn 的参数协议）
  let script = StringBuilder()
  let mut first = true
  for a in args {
    if !first {
      script.write_char('\u{0}')
    }
    script.write_string(a)
    first = false
  }
  let ans : Result[(Int, String), VolumeError] = try {
    let pid = @subproc.spawn({
      bun_path: prog,
      script: script.to_string(),
      cwd: "/",
      out_log: out_path,
      err_log: err_path,
      env_blob: vol_env_blob(),
    })
    match @subproc.wait_child_timeout(pid, timeout_ms) {
      None => Err(CommandFailed("\{prog}: 超时（\{timeout_ms}ms）"))
      Some((_, @subproc.Signaled(sig))) => Err(CommandFailed("\{prog}: 被信号 \{sig} 终止"))
      Some((_, @subproc.Exited(code))) => {
        let text = match read_text_file(out_path) {
          Some(t) => t
          None => ""
        }
        Ok((code, text))
      }
    }
  } catch {
    e => Err(CommandFailed("\{prog}: \{e.to_string()}"))
  }
  // 清理临时文件（无论成败）
  let ok = Ref(0)
  let _ = ffi_remove_file(utf8_bytes(out_path), ok)
  let _ = ffi_remove_file(utf8_bytes(err_path), ok)
  ans
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
/// 当前系统是否支持音量控制（wpctl 或 pactl 任一可用）。每次调用真实
/// 探测，高频场景请调用方自行缓存结果。
pub fn vol_supported() -> Bool {
  vol_backend() is Some(_)
}

///|
/// 读默认 sink 音量快照（sink 名 / 音量 0-100 / 是否静音）。
/// wpctl 路径两次查询（get-volume + status 取显示名），pactl 路径三次
/// 查询（get-default-sink + get-sink-volume + get-sink-mute）；sink 名
/// 为次要信息，取不到置空串不影响音量与静音。
pub fn vol_get() -> Result[VolumeInfo, VolumeError] {
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
            Ok((0, st)) => {
              match vol_parse_wpctl_status_sink(st) {
                Some(name) => name
                None => ""
              }
            }
            _ => ""
          }
          Ok({ sink, volume, muted })
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
  let volume = match vol_run_capture("pactl", ["get-sink-volume", "@DEFAULT_SINK@"]) {
    Err(e) => return Err(e)
    Ok((code, out)) => {
      if code != 0 {
        return Err(CommandFailed("pactl get-sink-volume: 退出码 \{code}"))
      }
      match vol_parse_pactl_percent(out) {
        Some(v) => v
        None => return Err(ParseFailed("pactl get-sink-volume: \{vol_trim(out)}"))
      }
    }
  }
  let muted = match vol_run_capture("pactl", ["get-sink-mute", "@DEFAULT_SINK@"]) {
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
  Ok({ sink, volume, muted })
}

///|
/// 执行后端命令并按退出码归一结果（0 为成功）。
fn vol_apply(
  prog : String,
  args : Array[String],
) -> Result[Unit, VolumeError] {
  match vol_run_capture(prog, args) {
    Err(e) => Err(e)
    Ok((0, _)) => Ok(())
    Ok((code, _)) => Err(CommandFailed("\{prog}: 退出码 \{code}"))
  }
}

///|
/// 设绝对音量（0-100，出界钳制），作用于默认 sink。
pub fn vol_set(percent : Int) -> Result[Unit, VolumeError] {
  match vol_backend() {
    None => Err(Unsupported)
    Some(b) => vol_apply(vol_prog(b), vol_set_args(b, percent))
  }
}

///|
/// 相对增减音量（delta 为正增、为负减，作用于默认 sink；每步量取绝对
/// 值交给工具的相对语法执行，最终音量由工具侧钳制）。
pub fn vol_add(delta : Int) -> Result[Unit, VolumeError] {
  match vol_backend() {
    None => Err(Unsupported)
    Some(b) => vol_apply(vol_prog(b), vol_add_args(b, delta))
  }
}

///|
/// 设 / 取消默认 sink 静音。
pub fn vol_set_mute(mute : Bool) -> Result[Unit, VolumeError] {
  match vol_backend() {
    None => Err(Unsupported)
    Some(b) => vol_apply(vol_prog(b), vol_mute_args(b, mute))
  }
}
