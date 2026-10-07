// 浏览器历史读取（只读）：Chrome / Chromium / Edge / Brave 的 History
// SQLite 库读取，直接解析磁盘文件（moonsqlitefile，纯 MoonBit 无 FFI），
// 不复制、不修改原库。profile 存在性探测走目录枚举（fsx_list_dir 查
// History 条目，不读库文件内容），取数路径才把命中的库整读一遍——
// 列 profile 不再为判存在把数十 MB 的库读进来。探测按"存在才收、
// 读不到静默跳过"（目录枚举无类型信息，profile 目录里名为 History
// 的条目即算命中）。本包未提供目录枚举之外的 profile 发现手段，
// profile 目录按固定候选名探测（Default 与 Profile 1..N）。
//   - bh_browsers  列出有 History 库的浏览器 profile
//   - bh_history   浏览历史（urls 表，时间降序）
//   - bh_downloads 下载记录（downloads 表，开始时间降序）
//   - bh_search    url/title 子串搜索（ASCII 大小写不敏感）
// 时间换算 / 折叠匹配 / 行解析等纯逻辑集中在文件头部，
// browser_history_wbtest.mbt 白盒覆盖。

///|
/// 已探测到的浏览器 profile：浏览器标识 + profile 名 + History 库路径。
pub(all) struct BrowserProfile {
  /// 浏览器标识：google-chrome / chromium / microsoft-edge / brave
  browser : String
  /// profile 目录名：Default 或 Profile N
  profile : String
  /// History 库完整路径
  history_path : String
}

///|
/// 一条浏览历史（urls 表一行；多 profile 聚合时同 url 会各出现一次）。
pub(all) struct HistoryItem {
  /// 页面地址
  url : String
  /// 页面标题（无标题为空串）
  title : String
  /// 累计访问次数
  visit_count : Int
  /// 最近访问时间（Unix 毫秒；Chrome 时间基准换算，未知为 0）
  last_visit_time : Int64
}

///|
/// 一条下载记录（downloads 表一行）。
pub(all) struct DownloadItem {
  /// 目标保存路径
  target_path : String
  /// 已接收字节数
  received_bytes : Int64
  /// 总字节数（未知为 0）
  total_bytes : Int64
  /// 开始时间（Unix 毫秒，未知为 0）
  start_time : Int64
  /// 结束时间（Unix 毫秒，未知为 0）
  end_time : Int64
  /// 状态数值（见 [bh_download_state_name]）
  state : Int64
}

///|
pub(all) enum BrowserHistoryError {
  /// 平台不支持（本文件仅实现 Linux 路径探测）
  BhUnsupported
  /// 定位配置目录失败（XDG_CONFIG_HOME / HOME 均未设置）
  BhNoConfigDir
  /// 未找到任何含 History 库的浏览器 profile
  BhNoBrowser
  /// 读库或解析失败，带 profile 与原因
  BhIoFailed(String)
}

///|
pub impl Show for BrowserHistoryError with fn output(self, logger) {
  match self {
    BhUnsupported => logger.write_string("BrowserHistoryError::BhUnsupported")
    BhNoConfigDir => logger.write_string("BrowserHistoryError::BhNoConfigDir")
    BhNoBrowser => logger.write_string("BrowserHistoryError::BhNoBrowser")
    BhIoFailed(reason) =>
      logger.write_string("BrowserHistoryError::BhIoFailed(\{reason})")
  }
}

///|
pub extend BrowserHistoryError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯逻辑层：时间换算 / ASCII 折叠匹配 / 状态名 / 截断排序 / 行解析
// （browser_history_wbtest.mbt 白盒覆盖）
// ---------------------------------------------------------------------------

///|
/// Chrome 时间戳（1601-01-01 UTC 起微秒）→ Unix 毫秒；
/// <= 0 视为未知时间给 0；微秒以下截断。
pub fn bh_chrome_time_to_unix_ms(us : Int64) -> Int64 {
  if us <= 0L {
    return 0L
  }
  us / 1000L - 11644473600000L
}

///|
/// ASCII 大小写折叠（A-Z → a-z，其余字符原样保留）。
pub fn bh_lower_ascii(s : String) -> String {
  let sb = StringBuilder()
  let mut i = 0
  while i < s.length() {
    let c = s.unsafe_get(i).to_int()
    if c >= 65 && c <= 90 {
      // 'A'..'Z'
      sb.write_char((c + 32).unsafe_to_char())
    } else {
      sb.write_char(c.unsafe_to_char())
    }
    i += 1
  }
  sb.to_string()
}

///|
/// 子串匹配（ASCII 大小写不敏感）：haystack 含 keyword 给 true；
/// keyword 为空匹配一切。
pub fn bh_contains_fold(haystack : String, keyword : String) -> Bool {
  if keyword == "" {
    return true
  }
  bh_lower_ascii(haystack).contains(bh_lower_ascii(keyword))
}

///|
/// downloads.state 数值 → 名称：0 进行中、1 完成、2 已取消、3/4 中断，
/// 其余给 "未知(数值)"。
pub fn bh_download_state_name(state : Int64) -> String {
  match state {
    0L => "进行中"
    1L => "完成"
    2L => "已取消"
    3L => "中断"
    4L => "中断"
    _ => "未知(\{state})"
  }
}

///|
/// 截断：limit <= 0 或超出长度时全收，否则取前 limit 项（返回新数组）。
fn[T] bh_take(items : Array[T], limit : Int) -> Array[T] {
  if limit <= 0 || limit >= items.length() {
    return items.copy()
  }
  let out : Array[T] = []
  for i = 0; i < limit; i = i + 1 {
    out.push(items[i])
  }
  out
}

///|
/// 浏览历史排序：最近访问时间降序，并列按 url 升序（返回新数组）。
pub fn bh_sort_history(items : Array[HistoryItem]) -> Array[HistoryItem] {
  let out = items.copy()
  out
  .mut_view()
  .sort_by(fn(a, b) {
    if a.last_visit_time > b.last_visit_time {
      -1
    } else if a.last_visit_time < b.last_visit_time {
      1
    } else if a.url < b.url {
      -1
    } else if a.url > b.url {
      1
    } else {
      0
    }
  })
  out
}

///|
/// 下载记录排序：开始时间降序，并列按 target_path 升序（返回新数组）。
pub fn bh_sort_downloads(items : Array[DownloadItem]) -> Array[DownloadItem] {
  let out = items.copy()
  out
  .mut_view()
  .sort_by(fn(a, b) {
    if a.start_time > b.start_time {
      -1
    } else if a.start_time < b.start_time {
      1
    } else if a.target_path < b.target_path {
      -1
    } else if a.target_path > b.target_path {
      1
    } else {
      0
    }
  })
  out
}

///|
/// Value 取文本：Text 给原文，其余（含 Null）给空串。
fn bh_value_text(v : @moonsqlitefile.Value) -> String {
  match v {
    @moonsqlitefile.Text(s) => s
    _ => ""
  }
}

///|
/// Value 取整数：Integer 给数值，其余（含 Null）给 0。
fn bh_value_int(v : @moonsqlitefile.Value) -> Int64 {
  match v {
    @moonsqlitefile.Integer(n) => n
    _ => 0L
  }
}

///|
/// urls 表一行 → [HistoryItem]。列序：id/url/title/visit_count/
/// typed_count/last_visit_time/hidden（id 为 INTEGER PRIMARY KEY，磁盘
/// 记录里存 Null）；列数不足或 hidden 非 0（重定向等隐藏条目）给 None。
pub fn bh_parse_history_row(
  values : Array[@moonsqlitefile.Value],
) -> HistoryItem? {
  if values.length() < 7 {
    return None
  }
  if bh_value_int(values[6]) != 0L {
    return None
  }
  Some({
    url: bh_value_text(values[1]),
    title: bh_value_text(values[2]),
    visit_count: bh_value_int(values[3]).to_int(),
    last_visit_time: bh_chrome_time_to_unix_ms(bh_value_int(values[5])),
  })
}

///|
/// downloads 表一行 → [DownloadItem]。取前 12 列：id/guid/current_path/
/// target_path/start_time/received_bytes/total_bytes/state/…/end_time；
/// 列数不足给 None。
pub fn bh_parse_download_row(
  values : Array[@moonsqlitefile.Value],
) -> DownloadItem? {
  if values.length() < 12 {
    return None
  }
  Some({
    target_path: bh_value_text(values[3]),
    received_bytes: bh_value_int(values[5]),
    total_bytes: bh_value_int(values[6]),
    start_time: bh_chrome_time_to_unix_ms(bh_value_int(values[4])),
    end_time: bh_chrome_time_to_unix_ms(bh_value_int(values[11])),
    state: bh_value_int(values[7]),
  })
}

///|
/// moonsqlitefile 错误 → 文本（其错误类型未实现 Show，不能直接插值）。
fn bh_sqlite_error_text(e : @moonsqlitefile.SqliteError) -> String {
  match e {
    @moonsqlitefile.Invalid(msg) => "Invalid: " + msg
    @moonsqlitefile.Unsupported(msg) => "Unsupported: " + msg
    @moonsqlitefile.LimitExceeded(msg) => "LimitExceeded: " + msg
  }
}

// ---------------------------------------------------------------------------
// 探测与读取（探测走目录枚举，取数读盘走 read_binary_file，只读不开写）
// ---------------------------------------------------------------------------

///|
/// profile 目录候选名：Default 与 Profile 1..24（本包无 profile 目录
/// 枚举手段，按固定候选名探测；自定义目录名的 profile 收不到）。
let bh_profile_probe_max : Int = 24

///|
/// profile 目录候选名列表（Default 在前）。
pub fn bh_profile_candidates() -> Array[String] {
  let out : Array[String] = ["Default"]
  for i = 1; i <= bh_profile_probe_max; i = i + 1 {
    out.push("Profile \{i}")
  }
  out
}

///|
/// 浏览器配置根：XDG_CONFIG_HOME（设且非空）优先，回退 $HOME/.config。
pub fn bh_config_root(xdg_config_home : String?, home : String?) -> String? {
  match xdg_config_home {
    Some(d) if d != "" => Some(d)
    _ =>
      match home {
        Some(h) if h != "" => Some(h + "/.config")
        _ => None
      }
  }
}

///|
/// 浏览器定义：(标识, 配置目录名, 目录内子目录)。
/// Brave 的 profile 在 BraveSoftware/Brave-Browser 下一层。
let bh_browser_defs : Array[(String, String, String)] = [
  ("google-chrome", "google-chrome", ""),
  ("chromium", "chromium", ""),
  ("microsoft-edge", "microsoft-edge", ""),
  ("brave", "BraveSoftware", "Brave-Browser"),
]

///|
/// 目录条目名里是否含 History（存在性判断的纯逻辑：只比条目名，不看
/// 文件内容）。
fn bh_names_hit_history(names : Array[String]) -> Bool {
  for n in names {
    if n == "History" {
      return true
    }
  }
  false
}

///|
/// 探测配置根下所有含 History 库的 profile：浏览器定义 × profile 候选名
/// 逐一目录枚举，命中（目录里有名为 History 的条目）即收，不读库文件
/// 内容；返回按浏览器定义顺序（Chrome → Chromium → Edge → Brave）、同
/// 浏览器内按 profile 候选顺序（Default 在前）排列。
fn bh_probe_profiles(root : String) -> Array[BrowserProfile] {
  let out : Array[BrowserProfile] = []
  for def in bh_browser_defs {
    let (id, dir, subdir) = def
    let base = if subdir != "" {
      root + "/" + dir + "/" + subdir
    } else {
      root + "/" + dir
    }
    for profile in bh_profile_candidates() {
      let dir_path = base + "/" + profile
      match fsx_list_dir(dir_path) {
        Ok(names) =>
          if bh_names_hit_history(names) {
            out.push({
              browser: id,
              profile,
              history_path: dir_path + "/History",
            })
          }
        Err(_) => () // 目录打不开（不存在/非目录/无权限）：当无此 profile
      }
    }
  }
  out
}

///|
/// 当前平台是否支持浏览器历史读取（本文件仅实现 Linux 路径探测）。
pub fn bh_supported() -> Bool {
  platform() == "linux"
}

///|
/// 列出有 History 库的浏览器 profile：按浏览器定义 × profile 候选名
/// 探测（目录枚举查 History 条目，不读库内容）；无可命中 profile 给
/// [BhNoBrowser]，非 Linux 给 [BhUnsupported]。
pub fn bh_browsers() -> Result[Array[BrowserProfile], BrowserHistoryError] {
  match bh_root_or_err() {
    Err(e) => Err(e)
    Ok(root) => {
      let out = bh_probe_profiles(root)
      if out.is_empty() {
        Err(BhNoBrowser)
      } else {
        Ok(out)
      }
    }
  }
}

///|
/// 配置根定位（探测与取数的公共前置）：非 Linux 给 [BhUnsupported]，
/// XDG_CONFIG_HOME / HOME 都定位不到给 [BhNoConfigDir]。
fn bh_root_or_err() -> Result[String, BrowserHistoryError] {
  if platform() != "linux" {
    return Err(BhUnsupported)
  }
  match bh_config_root(getenv_str("XDG_CONFIG_HOME"), getenv_str("HOME")) {
    Some(r) => Ok(r)
    None => Err(BhNoConfigDir)
  }
}

///|
/// 用已读入的库字节打开（只读，交给 moonsqlitefile）。
fn bh_open_db(bytes : Bytes) -> Result[@moonsqlitefile.Database, String] {
  Ok(@moonsqlitefile.open_database(bytes)) catch {
    e => Err(bh_sqlite_error_text(e))
  }
}

///|
/// 跨 profile 聚合：探测（目录枚举，不读库内容）后逐 profile 把库整读
/// 一遍交给 read_one，单 profile 读失败或解析失败跳过并记首个原因；
/// 全部失败给 [BhIoFailed]，一个可命中 profile 都没有时给
/// [BhNoBrowser]。
fn[T] bh_merge_profiles(
  read_one : (BrowserProfile, Bytes) -> Result[Array[T], String],
) -> Result[Array[T], BrowserHistoryError] {
  let root = match bh_root_or_err() {
    Ok(r) => r
    Err(e) => return Err(e)
  }
  let profiles = bh_probe_profiles(root)
  if profiles.is_empty() {
    return Err(BhNoBrowser)
  }
  let out : Array[T] = []
  let mut first_error = ""
  let mut ok_count = 0
  for p in profiles {
    let reason = match read_binary_file(p.history_path) {
      Some(bytes) =>
        match read_one(p, bytes) {
          Ok(items) => {
            ok_count = ok_count + 1
            for item in items {
              out.push(item)
            }
            ""
          }
          Err(reason) => reason
        }
      None => "读取失败（库文件不可读）"
    }
    if reason != "" && first_error == "" {
      first_error = p.browser + "/" + p.profile + ": " + reason
    }
  }
  if ok_count == 0 && first_error != "" {
    return Err(BhIoFailed(first_error))
  }
  Ok(out)
}

///|
/// 单 profile 的 urls 表全量读取（含列数不足行的静默跳过）。
fn bh_history_of_profile(bytes : Bytes) -> Result[Array[HistoryItem], String] {
  let db = match bh_open_db(bytes) {
    Ok(d) => d
    Err(reason) => return Err(reason)
  }
  try {
    let out : Array[HistoryItem] = []
    for row in db.table_rows("urls") {
      match bh_parse_history_row(row.values) {
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
/// 单 profile 的 downloads 表全量读取。
fn bh_downloads_of_profile(
  bytes : Bytes,
) -> Result[Array[DownloadItem], String] {
  let db = match bh_open_db(bytes) {
    Ok(d) => d
    Err(reason) => return Err(reason)
  }
  try {
    let out : Array[DownloadItem] = []
    for row in db.table_rows("downloads") {
      match bh_parse_download_row(row.values) {
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
/// 浏览历史：聚合全部已探测 profile 的 urls 表，按最近访问时间降序
/// （并列按 url 升序），取前 limit 项；limit 缺省 200，<= 0 取全部。
/// hidden 条目（重定向等）已滤除；单 profile 读失败跳过，全部失败报错。
pub fn bh_history(
  limit? : Int = 200,
) -> Result[Array[HistoryItem], BrowserHistoryError] {
  match bh_merge_profiles(fn(_p, bytes) { bh_history_of_profile(bytes) }) {
    Err(e) => Err(e)
    Ok(items) => Ok(bh_take(bh_sort_history(items), limit))
  }
}

///|
/// 下载记录：聚合全部已探测 profile 的 downloads 表，按开始时间降序
/// （并列按 target_path 升序），取前 limit 项；limit 缺省 50，<= 0 取全部。
pub fn bh_downloads(
  limit? : Int = 50,
) -> Result[Array[DownloadItem], BrowserHistoryError] {
  match bh_merge_profiles(fn(_p, bytes) { bh_downloads_of_profile(bytes) }) {
    Err(e) => Err(e)
    Ok(items) => Ok(bh_take(bh_sort_downloads(items), limit))
  }
}

///|
/// 搜索浏览历史：url 或 title 含 keyword（子串、ASCII 大小写不敏感）
/// 的条目，按最近访问时间降序取前 limit 项；limit 缺省 50，<= 0 取全部；
/// keyword 为空匹配一切条目（与 [bh_history] 同集，但缺省 limit 是 50
/// 而非 200）。
pub fn bh_search(
  keyword : String,
  limit? : Int = 50,
) -> Result[Array[HistoryItem], BrowserHistoryError] {
  match bh_merge_profiles(fn(_p, bytes) { bh_history_of_profile(bytes) }) {
    Err(e) => Err(e)
    Ok(items) => {
      let hits : Array[HistoryItem] = []
      for item in items {
        if bh_contains_fold(item.url, keyword) ||
          bh_contains_fold(item.title, keyword) {
          hits.push(item)
        }
      }
      Ok(bh_take(bh_sort_history(hits), limit))
    }
  }
}
