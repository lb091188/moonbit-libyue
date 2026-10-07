// 系统窗口管理（X11）：解析 `wmctrl -l` 的窗口列表（窗口 id / 桌面 /
// 主机 / 标题），并按 id 或标题激活、按标题关闭窗口。不依赖 libyue
// GUI 应用环境，普通 MoonBit 进程即可使用；命令路线经 procrun 的
// [pr_run]（spawn → 限时回收 → 捕获 stdout），不自行 spawn。
//
// 激活 / 关闭会改变真实窗口状态（设置类）：接口完整实现，白盒只验证
// 命令构造与输出解析（windowctl_wbtest.mbt），不真实执行动作。
//
// 典型用法：
//   match win_list() {
//     Ok(wins) => for w in wins { println("\{w.desktop} \{w.title}") }
//     Err(Unsupported) => () // 非 Linux 或 wmctrl 缺失
//     Err(e) => println(e)
//   }
//   win_activate("0x02400004") // 按窗口 id 激活
//   win_close("ZCode")         // 按标题关闭

///|
/// 受管窗口快照：id 为 wmctrl 输出的 "0x" 十六进制窗口 id（可直接回传
/// [win_activate]）；desktop 为窗口所在桌面，-1 表示全部桌面（sticky）；
/// host 为窗口所属主机名；title 为窗口标题（保留原标题内的空白）。
pub(all) struct WindowInfo {
  id : String
  desktop : Int
  host : String
  title : String
}

///|
pub impl Show for WindowInfo with fn output(self, logger) {
  logger.write_string("WindowInfo { id: ")
  logger.write_string(self.id)
  logger.write_string(", desktop: ")
  logger.write_string(self.desktop.to_string())
  logger.write_string(", host: ")
  logger.write_string(self.host)
  logger.write_string(", title: ")
  logger.write_string(self.title)
  logger.write_string(" }")
}

///|
pub extend WindowInfo with Show::{to_string, output}

///|
pub(all) enum WinError {
  /// 当前平台/环境不支持（非 Linux，或 wmctrl 不存在——Unix 以退出码
  /// 127 呈现命令缺失）
  Unsupported
  /// 命令执行失败（spawn 失败 / 非零退出 / 超时 / 被信号终止），带原因
  CommandFailed(String)
  /// wmctrl -l 输出非空但无一行可解析，带原文
  ParseFailed(String)
  /// 参数非法（id_or_title / 标题为空），带说明
  InvalidParam(String)
}

///|
pub impl Show for WinError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("WinError::Unsupported")
    CommandFailed(m) => logger.write_string("WinError::CommandFailed(\{m})")
    ParseFailed(m) => logger.write_string("WinError::ParseFailed(\{m})")
    InvalidParam(m) => logger.write_string("WinError::InvalidParam(\{m})")
  }
}

///|
pub extend WinError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：wmctrl -l 行解析 / 命令构造（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn win_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn win_split_lines(s : String) -> Array[String] {
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
fn win_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && win_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && win_is_ws(chars[j]) {
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
/// stderr 诊断文本压成单行并截断（首行前 120 字符；空串返回空串）。
fn win_first_line(s : String) -> String {
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
/// 有符号十进制整数文本（"-1" → -1；空串或含非数字为 None）。
fn win_parse_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let mut start = 0
  let mut neg = false
  if chars[0] == '-' {
    neg = true
    start = 1
    if chars.length() == 1 {
      return None
    }
  }
  let mut v = 0
  let mut k = start
  while k < chars.length() {
    let ch = chars[k]
    if ch < '0' || ch > '9' {
      return None
    }
    v = v * 10 + (ch.to_int() - 48)
    k = k + 1
  }
  Some(if neg { -v } else { v })
}

///|
/// 是否 wmctrl 窗口 id 形态："0x" 前缀加至少一位十六进制数字
/// （"0x02800003" / "0x00c00008" / "0xABC" 为真）。
fn win_is_hex_id(s : String) -> Bool {
  if !s.has_prefix("0x") {
    return false
  }
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  if chars.length() < 3 {
    return false
  }
  let mut i = 2
  while i < chars.length() {
    let ch = chars[i]
    let is_hex = (ch >= '0' && ch <= '9') ||
      (ch >= 'a' && ch <= 'f') ||
      (ch >= 'A' && ch <= 'F')
    if !is_hex {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// 解析 `wmctrl -l` 单行：`0x<窗口id> <桌面> <主机> <标题>`。桌面号右
/// 对齐两位（0 与 -1 的宽差即分隔空格的多少，故按空白切 token，标题
/// 取主机 token 之后原样保留行内空白）。字段不足三段、id 非 "0x"
/// 形态或桌面号非整数为 None。
fn win_parse_line(line : String) -> WindowInfo? {
  let id_buf = StringBuilder()
  let desk_buf = StringBuilder()
  let host_buf = StringBuilder()
  let title_buf = StringBuilder()
  let mut stage = 0 // 0=id 1=desktop 2=host 3=title
  let mut in_tok = false
  for ch in line {
    if stage < 3 {
      if !win_is_ws(ch) {
        in_tok = true
        if stage == 0 {
          id_buf.write_char(ch)
        } else if stage == 1 {
          desk_buf.write_char(ch)
        } else {
          host_buf.write_char(ch)
        }
      } else if in_tok {
        stage = stage + 1
        in_tok = false
      }
    } else {
      // title：主机后的单个分隔空白已在上行消费，其余字符（含空白）原样收入
      title_buf.write_char(ch)
    }
  }
  if stage < 2 {
    return None // 不足 id/desktop/host 三段
  }
  let id = id_buf.to_string()
  if !win_is_hex_id(id) {
    return None
  }
  match win_parse_int(desk_buf.to_string()) {
    None => None
    Some(desktop) =>
      Some({
        id,
        desktop,
        host: host_buf.to_string(),
        title: title_buf.to_string(),
      })
  }
}

///|
/// 解析 `wmctrl -l` 全文：逐行解析，无法解析的非空行跳过（容错）；空
/// 输出为空列表，非空输出但一行都解析不出为 Err([WinError.ParseFailed])。
fn win_parse_list(text : String) -> Result[Array[WindowInfo], WinError] {
  let out : Array[WindowInfo] = []
  let mut tried = 0
  for line in win_split_lines(text) {
    if win_trim(line) == "" {
      continue
    }
    tried = tried + 1
    match win_parse_line(line) {
      Some(w) => out.push(w)
      None => ()
    }
  }
  if tried > 0 && out.length() == 0 {
    Err(ParseFailed("wmctrl -l: \{win_first_line(text)}"))
  } else {
    Ok(out)
  }
}

///|
/// 激活窗口的参数表：target 为 "0x" 十六进制窗口 id 时带 -i 按数值
/// 解释（[WindowInfo.id] 即此形态），否则按标题子串匹配（不区分大小写，
/// 与 wmctrl 默认行为一致）。
fn win_activate_args(target : String) -> Array[String] {
  if win_is_hex_id(target) {
    ["-i", "-a", target]
  } else {
    ["-a", target]
  }
}

///|
/// 关闭窗口的参数表：按标题子串匹配（不区分大小写）。
fn win_close_args(title : String) -> Array[String] {
  ["-c", title]
}

// ---------------------------------------------------------------------------
// 子进程执行封装（复用 procrun 的 [pr_run]）
// ---------------------------------------------------------------------------

///|
/// 把 [pr_run] 的错误归一为 [WinError]；命令不存在（Unix 退出码 127）
/// 归为 Unsupported，非零退出带 stderr 首行。
fn win_map_err(prog : String, e : ProcError) -> WinError {
  match e {
    NonZeroExit(127, _) => Unsupported
    NonZeroExit(code, err) =>
      CommandFailed("\{prog}: 退出码 \{code}（\{win_first_line(err)}）")
    Timeout(m) => CommandFailed(m)
    SpawnFailed(m) => CommandFailed(m)
    Signaled(sig) => CommandFailed("\{prog}: 被信号 \{sig} 终止")
    Unsupported => Unsupported
  }
}

///|
/// 执行窗口动作（wmctrl -a / -c 等）。
fn win_apply(args : Array[String]) -> Result[Unit, WinError] {
  match pr_run("wmctrl", args, timeout_ms=5000) {
    Ok(_) => Ok(())
    Err(e) => Err(win_map_err("wmctrl", e))
  }
}

///|
/// 探测命令存在且可运行（--version 只读、无副作用，不需要 X 会话）。
fn win_probe(prog : String) -> Bool {
  match pr_run(prog, ["--version"], timeout_ms=3000) {
    Ok(_) => true
    Err(_) => false
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持窗口管理：Linux 且 wmctrl / xdotool 任一存在。
/// 工具缺失是合法状态（返回 false，不是失败）。每次调用真实探测，高频
/// 场景请调用方自行缓存结果。
pub fn win_supported() -> Bool {
  if !pr_available() {
    return false
  }
  win_probe("wmctrl") || win_probe("xdotool")
}

///|
/// 列出当前窗口管理器接管的窗口（wmctrl -l 的逐行解析）。
/// 需要 X 会话；无会话时 wmctrl 以非零退出呈现，返回
/// Err([WinError.CommandFailed])。
pub fn win_list() -> Result[Array[WindowInfo], WinError] {
  match pr_run("wmctrl", ["-l"], timeout_ms=4000) {
    Ok(o) => win_parse_list(o.stdout)
    Err(e) => Err(win_map_err("wmctrl -l", e))
  }
}

///|
/// 激活窗口：id_or_title 为 [WindowInfo.id]（"0x" 十六进制）时按 id
/// 激活，否则按标题子串匹配（不区分大小写）。会切换桌面并置顶目标
/// 窗口；空参数返回 Err([WinError.InvalidParam])。
pub fn win_activate(id_or_title : String) -> Result[Unit, WinError] {
  if id_or_title == "" {
    return Err(InvalidParam("窗口 id 或标题为空"))
  }
  win_apply(win_activate_args(id_or_title))
}

///|
/// 关闭窗口：title 按标题子串匹配（不区分大小写），关闭首个匹配窗口
/// （wmctrl -c 语义）。空参数返回 Err([WinError.InvalidParam])。
pub fn win_close(title : String) -> Result[Unit, WinError] {
  if title == "" {
    return Err(InvalidParam("窗口标题为空"))
  }
  win_apply(win_close_args(title))
}
