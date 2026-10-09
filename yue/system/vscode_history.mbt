// VS Code 本地文件历史与最近工作区：读取 User/History 下某文件的历史
// 快照列表与 globalStorage/storage.json 的 windowsState（最近工作区/
// 文件夹）。历史目录名由资源 URI 按 VS Code 同一哈希规则直算定位，
// 单文件查询只读一个 entries.json，不做全目录扫描索引；文件读取统一走
// read_text_file。
//
// 典型用法：
//   let snaps = @system.vsc_local_history("/path/to/file.ext")
//   //  Ok([{ path: "…/History/<hash>/XXXX.ext", timestamp: 毫秒 }, …]) 倒序
//   let recent = @system.vsc_recent() // Ok(["/path/to/workspace", …])

// ---------------------------------------------------------------------------
// 纯函数层：URI 编码/解码与码点（UTF-16 ↔ Unicode 码点 ↔ UTF-8）
// ---------------------------------------------------------------------------

///|
/// 码点 → UTF-8 字节（追加进 out）。
fn vsc_utf8_encode(cp : Int, out : Array[Int]) -> Unit {
  if cp < 0x80 {
    out.push(cp)
  } else if cp < 0x800 {
    out.push(0xC0 | (cp >> 6))
    out.push(0x80 | (cp & 0x3F))
  } else if cp < 0x10000 {
    out.push(0xE0 | (cp >> 12))
    out.push(0x80 | ((cp >> 6) & 0x3F))
    out.push(0x80 | (cp & 0x3F))
  } else {
    out.push(0xF0 | (cp >> 18))
    out.push(0x80 | ((cp >> 12) & 0x3F))
    out.push(0x80 | ((cp >> 6) & 0x3F))
    out.push(0x80 | (cp & 0x3F))
  }
}

///|
/// UTF-8 字节 → 码点（追加进 out）；非法序列以 U+FFFD 逐字节容错。
fn vsc_utf8_decode(bytes : Array[Int], out : Array[Int]) -> Unit {
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let b = bytes[i]
    if b < 0x80 {
      out.push(b)
      i += 1
    } else if b >= 0xC2 && b <= 0xDF && i + 1 < n && vsc_is_cont(bytes[i + 1]) {
      out.push(((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F))
      i += 2
    } else if b >= 0xE0 &&
      b <= 0xEF &&
      i + 2 < n &&
      vsc_is_cont(bytes[i + 1]) &&
      vsc_is_cont(bytes[i + 2]) {
      let cp = ((b & 0x0F) << 12) |
        ((bytes[i + 1] & 0x3F) << 6) |
        (bytes[i + 2] & 0x3F)
      if cp >= 0xD800 && cp <= 0xDFFF {
        out.push(0xFFFD)
      } else {
        out.push(cp)
      }
      i += 3
    } else if b >= 0xF0 &&
      b <= 0xF4 &&
      i + 3 < n &&
      vsc_is_cont(bytes[i + 1]) &&
      vsc_is_cont(bytes[i + 2]) &&
      vsc_is_cont(bytes[i + 3]) {
      let cp = ((b & 0x07) << 18) |
        ((bytes[i + 1] & 0x3F) << 12) |
        ((bytes[i + 2] & 0x3F) << 6) |
        (bytes[i + 3] & 0x3F)
      if cp > 0x10FFFF {
        out.push(0xFFFD)
      } else {
        out.push(cp)
      }
      i += 4
    } else {
      out.push(0xFFFD)
      i += 1
    }
  }
}

///|
/// UTF-8 续字节（10xxxxxx）判定。
fn vsc_is_cont(b : Int) -> Bool {
  b >= 0x80 && b <= 0xBF
}

///|
/// 字节 → "%XX"（大写十六进制，与 JS encodeURIComponent 同形）。
fn vsc_byte_hex(b : Int) -> String {
  let sb = StringBuilder()
  sb.write_char('%')
  sb.write_char(vsc_hex_char(b / 16, true))
  sb.write_char(vsc_hex_char(b % 16, true))
  sb.to_string()
}

///|
/// 数值 → 十六进制字符（大写或小写）。
fn vsc_hex_char(d : Int, upper : Bool) -> Char {
  if d < 10 {
    (48 + d).unsafe_to_char()
  } else if upper {
    (55 + d).unsafe_to_char()
  } else {
    (87 + d).unsafe_to_char()
  }
}

///|
/// 文件路径 → URI 路径段：保留字母数字与 - . _ ~ /，其余按 UTF-8
/// 逐字节 %XX 大写转义（与 VS Code URI 的路径编码同形）。
fn vsc_uri_encode_path(path : String) -> String {
  let sb = StringBuilder()
  let n = path.length()
  let mut i = 0
  while i < n {
    let c = path.unsafe_get(i).to_int()
    if (c >= 97 && c <= 122) ||
      (c >= 65 && c <= 90) ||
      (c >= 48 && c <= 57) ||
      c == 45 ||
      c == 46 ||
      c == 95 ||
      c == 126 ||
      c == 47 {
      sb.write_char(c.unsafe_to_char())
      i += 1
    } else if c < 128 {
      sb.write_string(vsc_byte_hex(c))
      i += 1
    } else {
      let (cp, step) = @yue.vsc_codepoint_at(path, i)
      let bytes : Array[Int] = []
      vsc_utf8_encode(cp, bytes)
      for b in bytes {
        sb.write_string(vsc_byte_hex(b))
      }
      i += step
    }
  }
  sb.to_string()
}

///|
/// URI 段百分号解码（[start, end) 区间）：%XX 连续段按 UTF-8 组合解码，
/// 原样字符直通。
fn vsc_uri_percent_decode(s : String, start : Int, end : Int) -> String {
  let sb = StringBuilder()
  let pending : Array[Int] = []
  let mut i = start
  while i < end {
    let c = s.unsafe_get(i).to_int()
    let is_pct = c == 37 &&
      i + 2 < end &&
      @yue.vsc_hex_val(s.unsafe_get(i + 1).to_int()) is Some(_) &&
      @yue.vsc_hex_val(s.unsafe_get(i + 2).to_int()) is Some(_)
    if is_pct {
      let b = @yue.vsc_hex_val(s.unsafe_get(i + 1).to_int()).unwrap() * 16 +
        @yue.vsc_hex_val(s.unsafe_get(i + 2).to_int()).unwrap()
      pending.push(b)
      i += 3
    } else {
      vsc_flush_pending(sb, pending)
      let (cp, step) = @yue.vsc_codepoint_at(s, i)
      sb.write_char(cp.unsafe_to_char())
      i += step
    }
  }
  vsc_flush_pending(sb, pending)
  sb.to_string()
}

///|
/// 把累积的 %XX 字节按 UTF-8 解码刷入 sb（空则无操作）。
fn vsc_flush_pending(sb : StringBuilder, pending : Array[Int]) -> Unit {
  if pending.length() == 0 {
    return
  }
  let cps : Array[Int] = []
  vsc_utf8_decode(pending, cps)
  for cp in cps {
    sb.write_char(cp.unsafe_to_char())
  }
  pending.clear()
}

// ---------------------------------------------------------------------------
// 纯函数层：资源 URI ↔ 本地路径、历史目录名（哈希与 VS Code 同规则）
// ---------------------------------------------------------------------------

///|
/// 文件路径 → 资源 URI 字符串：
/// - 用户数据目录 User/ 下的文件（settings.json 等）为 "vscode-userdata:<路径>"；
/// - 其余为 "file://<编码路径>"；Windows 反斜杠归正斜杠、盘符小写前置
///   斜杠（C:\x → file:///c%3A/x）；//host/... 形态归 file://host/...。
fn vsc_resource_uri(user_dir : String, file_path : String) -> String {
  let user_prefix = user_dir + "/User/"
  if file_path.has_prefix(user_prefix) {
    return "vscode-userdata:" + vsc_uri_encode_path(file_path)
  }
  let mut p = file_path
  if @yue.platform() == "windows" {
    p = vsc_win_uri_path(p)
  }
  if p.has_prefix("//") {
    // //host/rest → file://host/rest（host 小写）
    let n = p.length()
    let mut idx = 2
    while idx < n && p.unsafe_get(idx).to_int() != 47 {
      idx += 1
    }
    let host_sb = StringBuilder()
    let mut j = 2
    while j < idx {
      let c = p.unsafe_get(j).to_int()
      if c >= 65 && c <= 90 {
        host_sb.write_char((c + 32).unsafe_to_char())
      } else {
        host_sb.write_char(c.unsafe_to_char())
      }
      j += 1
    }
    let rest = if idx < n { vsc_uri_encode_path_from(p, idx) } else { "/" }
    return "file://" + host_sb.to_string() + rest
  }
  "file://" + vsc_uri_encode_path(p)
}

///|
/// 从 start 起做路径段编码（UNC 余段用）。
fn vsc_uri_encode_path_from(path : String, start : Int) -> String {
  let n = path.length()
  if start >= n {
    return ""
  }
  let sb = StringBuilder()
  let mut i = start
  while i < n {
    let c = path.unsafe_get(i).to_int()
    if (c >= 97 && c <= 122) ||
      (c >= 65 && c <= 90) ||
      (c >= 48 && c <= 57) ||
      c == 45 ||
      c == 46 ||
      c == 95 ||
      c == 126 ||
      c == 47 {
      sb.write_char(c.unsafe_to_char())
      i += 1
    } else if c < 128 {
      sb.write_string(vsc_byte_hex(c))
      i += 1
    } else {
      let (cp, step) = @yue.vsc_codepoint_at(path, i)
      let bytes : Array[Int] = []
      vsc_utf8_encode(cp, bytes)
      for b in bytes {
        sb.write_string(vsc_byte_hex(b))
      }
      i += step
    }
  }
  sb.to_string()
}

///|
/// Windows 路径归一：反斜杠 → 正斜杠，盘符 C:/ → /c:/。
fn vsc_win_uri_path(p : String) -> String {
  let n = p.length()
  let sb = StringBuilder()
  let mut i = 0
  let drive = n >= 2 &&
    p.unsafe_get(1).to_int() == 58 &&
    p.unsafe_get(0).to_int() >= 65 &&
    p.unsafe_get(0).to_int() <= 90
  if drive {
    sb.write_char('/')
    sb.write_char((p.unsafe_get(0).to_int() + 32).unsafe_to_char())
    i = 1
  }
  while i < n {
    let c = p.unsafe_get(i).to_int()
    if c == 92 {
      sb.write_char('/')
    } else {
      sb.write_char(c.unsafe_to_char())
    }
    i += 1
  }
  sb.to_string()
}

///|
/// 资源 URI → 本地路径：file:///path 直取；file://host/path 还原为
/// //host/path；vscode-userdata:<路径> 直取；Windows 下 /c:/x → c:\x。
/// 非 file/vscode-userdata 方案返回 None。
fn vsc_uri_to_path(uri : String) -> String? {
  let n = uri.length()
  if uri.has_prefix("file://") {
    let mut i = 7
    let mut authority = ""
    if i < n && uri.unsafe_get(i).to_int() != 47 {
      let start = i
      while i < n && uri.unsafe_get(i).to_int() != 47 {
        i += 1
      }
      authority = vsc_uri_percent_decode(uri, start, i)
    }
    let path = vsc_uri_percent_decode(uri, i, n)
    let mut full = if authority != "" { "//" + authority + path } else { path }
    if @yue.platform() == "windows" &&
      full.has_prefix("/") &&
      full.length() >= 3 &&
      full.unsafe_get(2).to_int() == 58 {
      let sb = StringBuilder()
      sb.write_char(full.unsafe_get(1).to_int().unsafe_to_char())
      sb.write_char(':')
      let mut j = 3
      while j < full.length() {
        let c = full.unsafe_get(j).to_int()
        if c == 47 {
          sb.write_char('\\')
        } else {
          sb.write_char(c.unsafe_to_char())
        }
        j += 1
      }
      full = sb.to_string()
    }
    return Some(full)
  }
  if uri.has_prefix("vscode-userdata:") {
    return Some(vsc_uri_percent_decode(uri, 16, n))
  }
  None
}

///|
/// 资源 URI → 历史目录名：31 进制滚动哈希（初值先混入种子 149417，
/// Int32 回绕），输出有符号小写十六进制（与 VS Code 目录名同形）。
fn vsc_history_folder(uri : String) -> String {
  let mut h : Int64 = 149417L
  let n = uri.length()
  let mut i = 0
  while i < n {
    let v = h * 31L + uri.unsafe_get(i).to_int().to_int64()
    let u = (v % 4294967296L + 4294967296L) % 4294967296L
    h = if u >= 2147483648L { u - 4294967296L } else { u }
    i += 1
  }
  vsc_i64_hex32(h)
}

///|
/// Int64（Int32 值域内）→ 有符号小写十六进制，无补零（0 → "0"，
/// 负数带 "-"，与 JS Number.prototype.toString(16) 同形）。
fn vsc_i64_hex32(h : Int64) -> String {
  if h == 0L {
    return "0"
  }
  let neg = h < 0L
  let mut u : Int64 = if neg { -h } else { h }
  let digits : Array[Int] = []
  while u > 0L {
    digits.push((u % 16L).to_int())
    u = u / 16L
  }
  let sb = StringBuilder()
  if neg {
    sb.write_char('-')
  }
  let mut i = digits.length() - 1
  while i >= 0 {
    sb.write_char(vsc_hex_char(digits[i], false))
    i -= 1
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 公开 API：错误、快照条目、查询入口
// ---------------------------------------------------------------------------

///|
/// 本地历史/最近工作区查询失败原因。
pub(all) enum VscodeError {
  /// 无法定位 VS Code 用户数据目录（HOME / XDG_CONFIG_HOME / APPDATA 缺失或平台未知）
  Unsupported
  /// storage.json 不存在或不可读（VS Code 从未在本机运行过）
  StorageUnavailable
  /// storage.json 解析失败，带原因
  StorageCorrupted(String)
  /// entries.json 解析失败，带原因
  HistoryCorrupted(String)
}

///|
pub impl Show for VscodeError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("VscodeError::Unsupported")
    StorageUnavailable => logger.write_string("VscodeError::StorageUnavailable")
    StorageCorrupted(m) =>
      logger.write_string("VscodeError::StorageCorrupted(\{m})")
    HistoryCorrupted(m) =>
      logger.write_string("VscodeError::HistoryCorrupted(\{m})")
  }
}

///|
pub extend VscodeError with Show::{to_string, output}

///|
/// 一条本地历史快照：path 为快照文件绝对路径（内容即该时刻文件全文），
/// timestamp 为 Unix 毫秒时间戳。
pub(all) struct VscHistoryEntry {
  path : String
  timestamp : Int64
}

///|
/// 时间戳换算：毫秒 → 秒（去尾）。
pub fn VscHistoryEntry::timestamp_seconds(self : VscHistoryEntry) -> Int64 {
  self.timestamp / 1000L
}

///|
/// VS Code 用户数据目录：Linux 为 $XDG_CONFIG_HOME/Code（缺省 $HOME/.config/Code），
/// macOS 为 $HOME/Library/Application Support/Code，Windows 为 %APPDATA%\Code。
fn vsc_user_data_dir() -> String? {
  match @yue.platform() {
    "linux" =>
      match getenv_str("XDG_CONFIG_HOME") {
        Some(d) if d != "" => Some(d + "/Code")
        _ =>
          match getenv_str("HOME") {
            Some(h) if h != "" => Some(h + "/.config/Code")
            _ => None
          }
      }
    "macos" =>
      match getenv_str("HOME") {
        Some(h) if h != "" => Some(h + "/Library/Application Support/Code")
        _ => None
      }
    "windows" =>
      match getenv_str("APPDATA") {
        Some(d) if d != "" => Some(d + "\\Code")
        _ => None
      }
    _ => None
  }
}

///|
/// windowsState 里单个窗口对象 → 工作区/文件夹路径（folder 或
/// workspaceUri，URI 转本地路径）。
fn vsc_window_path(w : @yue.VscJson) -> String? {
  let uri : String? = match @yue.vsc_json_str(@yue.vsc_json_get(w, "folder")) {
    Some(s) => Some(s)
    None => @yue.vsc_json_str(@yue.vsc_json_get(w, "workspaceUri"))
  }
  match uri {
    Some(u) => vsc_uri_to_path(u)
    None => None
  }
}

///|
/// 本机是否具备可读的 VS Code 用户数据（能定位用户数据目录且
/// storage.json 可读）。
pub fn vsc_supported() -> Bool {
  match vsc_user_data_dir() {
    Some(d) => @yue.read_text_file(d + "/User/globalStorage/storage.json") is Some(_)
    None => false
  }
}

///|
/// 某文件的本地历史快照列表（快照绝对路径 + 时间戳，按时间倒序，新→旧）。
/// file_path 传普通绝对路径或 file:// URI 均可；该文件无本地历史记录时
/// 返回空数组。
pub fn vsc_local_history(
  file_path : String,
) -> Result[Array[VscHistoryEntry], VscodeError] {
  let dir = match vsc_user_data_dir() {
    Some(d) => d
    None => return Err(Unsupported)
  }
  let path = if file_path.has_prefix("file://") {
    match vsc_uri_to_path(file_path) {
      Some(p) => p
      None => file_path
    }
  } else {
    file_path
  }
  let folder = vsc_history_folder(vsc_resource_uri(dir, path))
  let hist_dir = dir + "/User/History/" + folder
  let entries_path = hist_dir + "/entries.json"
  let content = match @yue.read_text_file(entries_path) {
    Some(c) => c
    // 无该文件的历史目录 = 无本地历史
    None => return Ok([])
  }
  let root = match @yue.vsc_json_parse(content) {
    Some(j) => j
    None => return Err(HistoryCorrupted("JSON 解析失败: " + entries_path))
  }
  let entries = match @yue.vsc_json_get(root, "entries") {
    Some(@yue.VscJArr(a)) => a
    _ => return Err(HistoryCorrupted("缺少 entries 数组: " + entries_path))
  }
  let out : Array[VscHistoryEntry] = []
  for e in entries {
    let id = match @yue.vsc_json_str(@yue.vsc_json_get(e, "id")) {
      Some(s) => s
      None =>
        return Err(HistoryCorrupted("快照条目缺少 id: " + entries_path))
    }
    let ts = match @yue.vsc_json_int64(@yue.vsc_json_get(e, "timestamp")) {
      Some(i) => i
      None =>
        return Err(
          HistoryCorrupted("快照条目缺少 timestamp: " + entries_path),
        )
    }
    out.push({ path: hist_dir + "/" + id, timestamp: ts, })
  }
  out
  .mut_view()
  .sort_by(fn(a, b) {
    if a.timestamp > b.timestamp {
      -1
    } else if a.timestamp < b.timestamp {
      1
    } else {
      0
    }
  })
  Ok(out)
}

///|
/// storage.json 根对象 → 最近路径列表：windowsState.lastActiveWindow
/// 在最前，openedWindows 依次追加（folder 与 workspaceUri 两种形态均
/// 收）；无 windowsState 给空数组。
fn vsc_recent_paths_of(root : @yue.VscJson) -> Array[String] {
  let out : Array[String] = []
  match @yue.vsc_json_get(root, "windowsState") {
    Some(state) => {
      match @yue.vsc_json_get(state, "lastActiveWindow") {
        Some(w) =>
          match vsc_window_path(w) {
            Some(p) => out.push(p)
            None => ()
          }
        None => ()
      }
      match @yue.vsc_json_get(state, "openedWindows") {
        Some(@yue.VscJArr(ws)) =>
          for w in ws {
            match vsc_window_path(w) {
              Some(p) => out.push(p)
              None => ()
            }
          }
        _ => ()
      }
    }
    None => ()
  }
  out
}

///|
/// 最近打开的工作区/文件夹路径列表（最近活动的在最前；.code-workspace
/// 工作区文件与其所在文件夹均以路径返回）。无窗口状态（全新安装）返回
/// 空数组。
pub fn vsc_recent() -> Result[Array[String], VscodeError] {
  let dir = match vsc_user_data_dir() {
    Some(d) => d
    None => return Err(Unsupported)
  }
  let storage_path = dir + "/User/globalStorage/storage.json"
  let content = match @yue.read_text_file(storage_path) {
    Some(c) => c
    None => return Err(StorageUnavailable)
  }
  let root = match @yue.vsc_json_parse(content) {
    Some(j) => j
    None => return Err(StorageCorrupted("JSON 解析失败: " + storage_path))
  }
  Ok(vsc_recent_paths_of(root))
}

