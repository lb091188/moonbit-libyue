// Firefox 浏览历史读取（只读）：~/.mozilla/firefox/profiles.ini 枚举
// profile 目录，读取各 profile 的 places.sqlite（moz_places 表，
// moonsqlitefile 纯 MoonBit 读取，不复制、不修改原库）。条目复用
// browser_history.mbt 的 [HistoryItem]（字段结构与 Chrome 历史完全
// 一致），时间按 Firefox 的 Unix 纪元微秒 → 毫秒换算；排序/截断/
// 取列等纯逻辑同样复用该文件已导出的 bh_sort_history / bh_take /
// bh_value_text / bh_value_int。
//   - ffx_profiles  有 places.sqlite 的 Firefox profile 列表
//   - ffx_history   浏览历史（moz_places，last_visit_date 降序）
// WAL 局限：places.sqlite 常处于 WAL 模式，本实现只读主库文件，尚未
// checkpoint 进主库的最新浏览记录读不到；多 profile 聚合时同一 url
// 会各出现一次（与 Chrome 侧 bh_history 的聚合口径一致）。
// 时间换算 / profiles.ini 解析 / 路径拼装 / 行解析等纯逻辑集中在
// 文件头部，firefox_history_wbtest.mbt 白盒覆盖。

///|
/// 已探测到的 Firefox profile：目录名 + places.sqlite 路径。
pub(all) struct FirefoxProfile {
  /// profile 目录名（profiles.ini 的 Path= 值；绝对路径取末段）
  profile : String
  /// places.sqlite 完整路径
  places_path : String
}

///|
pub(all) enum FirefoxHistoryError {
  /// 平台不支持（profiles.ini 定位仅实现 Linux/macOS/Windows）
  FfxUnsupported
  /// 未找到任何含 places.sqlite 的 profile（未安装 Firefox 或从未启动）
  FfxNoProfile
  /// 读库或解析失败，带 profile 与原因
  FfxIoFailed(String)
}

///|
pub impl Show for FirefoxHistoryError with fn output(self, logger) {
  match self {
    FfxUnsupported => logger.write_string("FirefoxHistoryError::FfxUnsupported")
    FfxNoProfile => logger.write_string("FirefoxHistoryError::FfxNoProfile")
    FfxIoFailed(reason) =>
      logger.write_string("FirefoxHistoryError::FfxIoFailed(\{reason})")
  }
}

///|
pub extend FirefoxHistoryError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯逻辑层：时间换算 / INI 解析 / 路径拼装 / 行解析
// （firefox_history_wbtest.mbt 白盒覆盖）
// ---------------------------------------------------------------------------

///|
/// Firefox places.last_visit_date（Unix 纪元起微秒）→ Unix 毫秒；
/// <= 0 视为未知时间给 0；微秒以下截断。
pub fn ffx_time_to_unix_ms(us : Int64) -> Int64 {
  if us <= 0L {
    return 0L
  }
  us / 1000L
}

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn ffx_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 去首尾空白。
fn ffx_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && ffx_is_ws(chars[i]) {
    i += 1
  }
  while j >= i && ffx_is_ws(chars[j]) {
    j -= 1
  }
  let sb = StringBuilder()
  let mut k = i
  while k <= j {
    sb.write_char(chars[k])
    k += 1
  }
  sb.to_string()
}

///|
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn ffx_split_lines(s : String) -> Array[String] {
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
/// 取子串 [start, end)（越界区间按夹逼到 [0, n] 处理）。
fn ffx_slice(s : String, start : Int, end : Int) -> String {
  let n = s.length()
  let lo = if start < 0 { 0 } else if start > n { n } else { start }
  let hi = if end > n { n } else if end < lo { lo } else { end }
  let sb = StringBuilder()
  let mut i = lo
  while i < hi {
    sb.write_char(s.unsafe_get(i).to_int().unsafe_to_char())
    i += 1
  }
  sb.to_string()
}

///|
/// INI 一行 → (键, 值)：首个 '=' 两侧去空白；键为空或无 '=' 给 None。
fn ffx_ini_split(line : String) -> (String, String)? {
  let n = line.length()
  let mut i = 0
  while i < n && line.unsafe_get(i).to_int() != 61 {
    // '='
    i += 1
  }
  if i >= n {
    return None
  }
  let key = ffx_trim(ffx_slice(line, 0, i))
  let value = ffx_trim(ffx_slice(line, i + 1, n))
  if key == "" {
    None
  } else {
    Some((key, value))
  }
}

///|
/// 路径末段目录名（按 '/' 或 '\\' 取最后一段；无分隔符时原样返回）。
fn ffx_profile_name(path : String) -> String {
  let n = path.length()
  let mut i = n - 1
  while i >= 0 {
    let c = path.unsafe_get(i).to_int()
    if c == 47 || c == 92 {
      // '/' 或 '\'
      break
    }
    i -= 1
  }
  ffx_slice(path, i + 1, n)
}

///|
/// profiles.ini 文本 → profile 目录名列表：收集各节的 Path= 值
/// （IsRelative=0 的绝对路径取末段），节顺序即文件顺序；无 Path 行
/// 给空数组。
fn ffx_parse_profiles_ini(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut is_relative = true
  for raw in ffx_split_lines(text) {
    let line = ffx_trim(raw)
    if line == "" {
      continue
    }
    let first = line.unsafe_get(0).to_int()
    if first == 59 || first == 35 {
      // ';' 与 '#':注释行
      continue
    }
    if first == 91 {
      // '[':节头，复位相对路径开关
      is_relative = true
      continue
    }
    match ffx_ini_split(line) {
      Some((key, value)) =>
        match key {
          "Path" =>
            if is_relative {
              out.push(value)
            } else {
              out.push(ffx_profile_name(value))
            }
          "IsRelative" => is_relative = value != "0"
          _ => ()
        }
      None => ()
    }
  }
  out
}

///|
/// Firefox profile 根目录：Linux/macOS 固定 $HOME/.mozilla/firefox，
/// Windows 为 %APPDATA%\Mozilla\Firefox；HOME/APPDATA 未设置给 None。
fn ffx_firefox_root() -> String? {
  match platform() {
    "windows" =>
      match getenv_str("APPDATA") {
        Some(d) if d != "" => Some(d + "\\Mozilla\\Firefox")
        _ => None
      }
    _ =>
      match getenv_str("HOME") {
        Some(h) if h != "" => Some(h + "/.mozilla/firefox")
        _ => None
      }
  }
}

///|
/// places.sqlite 路径拼装：<profile 根>/<profile>/places.sqlite。
pub fn ffx_places_path(root : String, profile : String) -> String {
  root + "/" + profile + "/places.sqlite"
}

///|
/// moz_places 表一行 → [HistoryItem]。列序（公开 schema）：
/// id/url/title/rev_host/visit_count/hidden/typed/frecency/
/// last_visit_date/guid/…，取前 9 列；列数不足或 hidden 非 0
/// （书签等隐藏条目）给 None。
pub fn ffx_parse_places_row(
  values : Array[@moonsqlitefile.Value],
) -> HistoryItem? {
  if values.length() < 9 {
    return None
  }
  if bh_value_int(values[5]) != 0L {
    return None
  }
  Some({
    url: bh_value_text(values[1]),
    title: bh_value_text(values[2]),
    visit_count: bh_value_int(values[4]).to_int(),
    last_visit_time: ffx_time_to_unix_ms(bh_value_int(values[8])),
  })
}

// ---------------------------------------------------------------------------
// 探测与读取（读盘走 read_binary_file，只读不开写）
// ---------------------------------------------------------------------------

///|
/// profiles.ini 缺失时的兜底 profile 候选名（Firefox 默认 profile 的
/// 几种固定名；随机前缀目录名仍只能靠 profiles.ini）。
let ffx_fallback_profile_names : Array[String] = [
  "default", "default-release", "default-esr", "default-nightly", "dev-edition-default",
]

///|
/// 当前平台是否支持 Firefox 历史读取（profiles.ini 定位实现了
/// Linux/macOS/Windows 三条路径）。
pub fn ffx_supported() -> Bool {
  platform() == "linux" || platform() == "macos" || platform() == "windows"
}

///|
/// 探测的内部版：命中的 profile 连同整库字节一并带回——探测读入的
/// 字节直接作后续打开的输入，同一个库不读第二遍。
fn ffx_profiles_loaded() -> Result[
  Array[(FirefoxProfile, Bytes)],
  FirefoxHistoryError,
] {
  if !ffx_supported() {
    return Err(FfxUnsupported)
  }
  let root = match ffx_firefox_root() {
    Some(r) => r
    None => return Err(FfxNoProfile)
  }
  let names = match read_text_file(root + "/profiles.ini") {
    Some(text) => ffx_parse_profiles_ini(text)
    None => ffx_fallback_profile_names
  }
  let out : Array[(FirefoxProfile, Bytes)] = []
  for name in names {
    if name == "" {
      continue
    }
    let path = ffx_places_path(root, name)
    match read_binary_file(path) {
      Some(bytes) => out.push(({ profile: name, places_path: path, }, bytes))
      None => ()
    }
  }
  if out.is_empty() {
    return Err(FfxNoProfile)
  }
  Ok(out)
}

///|
/// 列出有可读 places.sqlite 的 Firefox profile：先读 <profile 根>/
/// profiles.ini 取 Path= 目录名（缺失时回退固定候选名），再逐一探测
/// 各目录下 places.sqlite；未安装/从未启动 Firefox 给 [FfxNoProfile]，
/// 平台不支持给 [FfxUnsupported]。本包无目录枚举原语，profiles.ini
/// 缺失时收不到随机前缀命名的 profile 目录。
pub fn ffx_profiles() -> Result[Array[FirefoxProfile], FirefoxHistoryError] {
  match ffx_profiles_loaded() {
    Ok(pairs) => Ok(pairs.map(fn(pair) { pair.0 }))
    Err(e) => Err(e)
  }
}

///|
/// 用已读入的库字节打开（只读，交给 moonsqlitefile）。
fn ffx_open_db(bytes : Bytes) -> Result[@moonsqlitefile.Database, String] {
  Ok(@moonsqlitefile.open_database(bytes)) catch {
    e => Err(bh_sqlite_error_text(e))
  }
}

///|
/// 单 profile 的 moz_places 表全量读取（含列数不足行的静默跳过）。
fn ffx_history_of_profile(bytes : Bytes) -> Result[Array[HistoryItem], String] {
  let db = match ffx_open_db(bytes) {
    Ok(d) => d
    Err(reason) => return Err(reason)
  }
  try {
    let out : Array[HistoryItem] = []
    for row in db.table_rows("moz_places") {
      match ffx_parse_places_row(row.values) {
        Some(item) => out.push(item)
        None => ()
      }
    }
    Ok(out)
  } catch {
    e => Err(bh_sqlite_error_text(e))
  }
}

///|
/// 浏览历史：聚合全部已探测 profile 的 moz_places 表，按最近访问时间
/// 降序（并列按 url 升序），取前 limit 项；limit 缺省 200，<= 0 取
/// 全部。hidden 条目（书签等）已滤除；WAL 模式下尚未 checkpoint 进
/// 主库的最新记录读不到；单 profile 读失败跳过，全部失败给
/// [FfxIoFailed]。
pub fn ffx_history(
  limit? : Int = 200,
) -> Result[Array[HistoryItem], FirefoxHistoryError] {
  let pairs = match ffx_profiles_loaded() {
    Ok(ps) => ps
    Err(e) => return Err(e)
  }
  let out : Array[HistoryItem] = []
  let mut first_error = ""
  let mut ok_count = 0
  for pair in pairs {
    let (p, bytes) = pair
    match ffx_history_of_profile(bytes) {
      Ok(items) => {
        ok_count = ok_count + 1
        for item in items {
          out.push(item)
        }
      }
      Err(reason) =>
        if first_error == "" {
          first_error = p.profile + ": " + reason
        }
    }
  }
  if ok_count == 0 && first_error != "" {
    return Err(FfxIoFailed(first_error))
  }
  Ok(bh_take(bh_sort_history(out), limit))
}
