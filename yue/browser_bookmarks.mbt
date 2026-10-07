// 浏览器书签读取（只读）：Chrome / Chromium / Edge / Brave 的 Bookmarks
// JSON 文件解析。JSON 解析复用同包 vscode_history.mbt 的 vsc_json 系列
// （纯 MoonBit，整数字段保持 Int64 精度——Chrome 的 date_added 等以
// 数值字符串存储，微秒值经 bh_chrome_time_to_unix_ms 换算为 Unix
// 毫秒）；文件读取走 read_text_file，不复制、不修改原文件。roots 下
// bookmark_bar/other/synced 三根合并为一棵虚拟根树，每个节点带 root
// 根标注，folder 与 url 两类节点递归展开。
//   - bm_browsers   列出有 Bookmarks 文件的浏览器 profile
//   - bm_bookmarks  指定浏览器的书签树（虚拟根 → 三根 → 递归子节点）
//   - bm_flatten    书签树 → url 书签扁平列表（先序）
// 路径拼装 / JSON 节点解析 / 扁平化等纯逻辑集中在文件头部，
// browser_bookmarks_wbtest.mbt 白盒覆盖。

///|
/// 已探测到的浏览器书签 profile：浏览器标识 + profile 名 + Bookmarks 文件路径。
pub(all) struct BookmarkProfile {
  /// 浏览器标识：google-chrome / chromium / microsoft-edge / brave
  browser : String
  /// profile 目录名：Default 或 Profile N
  profile : String
  /// Bookmarks 文件完整路径
  bookmarks_path : String
}

///|
/// 书签树节点：folder 与 url 两类。folder 的 url 为 None 且有
/// children；url 书签的 children 为空数组。
pub(all) struct BookmarkNode {
  /// 节点名称（书签名 / 文件夹名）
  name : String
  /// url 书签的地址；folder 节点为 None
  url : String?
  /// 子节点（folder 有；url 书签为空数组）
  children : Array[BookmarkNode]
  /// 添加时间（Unix 毫秒；Chrome 时间基准换算，未知给 0）
  added : Int64
  /// 所属根：bookmark_bar / other / synced（虚拟根本身为空串）
  root : String
}

///|
/// 节点是否文件夹（url 为 None）。
pub fn BookmarkNode::is_folder(self : BookmarkNode) -> Bool {
  self.url is None
}

///|
/// 节点是否 url 书签（children 为空数组）。
pub fn BookmarkNode::is_url(self : BookmarkNode) -> Bool {
  self.url is Some(_)
}

///|
pub(all) enum BookmarkError {
  /// 平台不支持（本文件仅实现 Linux 路径探测）
  BmUnsupported
  /// 定位配置目录失败（XDG_CONFIG_HOME / HOME 均未设置）
  BmNoConfigDir
  /// 未找到任何含 Bookmarks 文件的浏览器 profile
  BmNoBrowser
  /// 读文件或解析失败，带浏览器/profile 与原因
  BmIoFailed(String)
}

///|
pub impl Show for BookmarkError with fn output(self, logger) {
  match self {
    BmUnsupported => logger.write_string("BookmarkError::BmUnsupported")
    BmNoConfigDir => logger.write_string("BookmarkError::BmNoConfigDir")
    BmNoBrowser => logger.write_string("BookmarkError::BmNoBrowser")
    BmIoFailed(reason) =>
      logger.write_string("BookmarkError::BmIoFailed(\{reason})")
  }
}

///|
pub extend BookmarkError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯逻辑层：数值字符串解析 / JSON 节点解析 / 路径拼装 / 扁平化
// （browser_bookmarks_wbtest.mbt 白盒覆盖）
// ---------------------------------------------------------------------------

///|
/// 三个根的键名（按三根合并进虚拟根 children 的顺序）。
let bm_root_keys : Array[String] = ["bookmark_bar", "other", "synced"]

///|
/// 数字字符串 → Int64：可选负号加十进制数字，遇非数字字符即止；
/// 空串或无数字给 0；超出 Int64 范围截顶（不再累加）。
pub fn bm_digits_to_int64(s : String) -> Int64 {
  let n = s.length()
  let mut i = 0
  let mut neg = false
  if i < n && s.unsafe_get(i).to_int() == 45 {
    // '-'
    neg = true
    i += 1
  }
  let mut v : Int64 = 0L
  let mut any = false
  while i < n {
    let c = s.unsafe_get(i).to_int()
    if c < 48 || c > 57 {
      break
    }
    any = true
    if v <= 922337203685477580L {
      v = v * 10L + (c - 48).to_int64()
    }
    i += 1
  }
  if !any {
    0L
  } else if neg {
    -v
  } else {
    v
  }
}

///|
/// 书签 JSON 的整数字段取值：整数直取；数值字符串逐位解析（Chrome 的
/// date_added 等以字符串存数值）；缺失或非数值给 0。
fn bm_json_int(v : VscJson?) -> Int64 {
  match v {
    Some(VscJInt(i)) => i
    Some(VscJStr(s)) => bm_digits_to_int64(s)
    _ => 0L
  }
}

///|
/// 单个书签节点（folder 或 url）→ [BookmarkNode]：type 既非 folder
/// 也非 url、或 url 节点缺 url 字段时给 None（不收）；folder 的
/// children 中无法解析的节点静默跳过。
fn bm_parse_node(v : VscJson, root : String) -> BookmarkNode? {
  let name = match vsc_json_str(vsc_json_get(v, "name")) {
    Some(s) => s
    None => ""
  }
  let kind = match vsc_json_str(vsc_json_get(v, "type")) {
    Some(s) => s
    None => ""
  }
  let added = bh_chrome_time_to_unix_ms(
    bm_json_int(vsc_json_get(v, "date_added")),
  )
  if kind == "folder" {
    let children : Array[BookmarkNode] = []
    match vsc_json_get(v, "children") {
      Some(VscJArr(arr)) =>
        for c in arr {
          match bm_parse_node(c, root) {
            Some(child) => children.push(child)
            None => ()
          }
        }
      _ => ()
    }
    Some({ name, url: None, children, added, root, })
  } else if kind == "url" {
    match vsc_json_str(vsc_json_get(v, "url")) {
      Some(url) => Some({ name, url: Some(url), children: [], added, root, })
      None => None
    }
  } else {
    None
  }
}

///|
/// roots 下单个根（可为缺失）→ 根节点；缺失给 None。
fn bm_parse_root(v : VscJson?, root : String) -> BookmarkNode? {
  match v {
    Some(j) => bm_parse_node(j, root)
    None => None
  }
}

///|
/// Bookmarks 文件全文 → 虚拟根书签树：label 作虚拟根名称，children 为
/// roots 下按 bookmark_bar/other/synced 顺序出现的根（缺失的根不占位，
/// 虚拟根本身的 root 字段为空串）。JSON 解析失败、缺 roots 对象或三根
/// 全缺失给 Err。
pub fn bm_parse_bookmarks(
  text : String,
  label : String,
) -> Result[BookmarkNode, String] {
  let parsed = match vsc_json_parse(text) {
    Some(j) => j
    None => return Err("JSON 解析失败")
  }
  let roots = match vsc_json_get(parsed, "roots") {
    Some(r) if r is VscJObj(_) => r
    _ => return Err("缺少 roots 对象")
  }
  let children : Array[BookmarkNode] = []
  for key in bm_root_keys {
    match bm_parse_root(vsc_json_get(roots, key), key) {
      Some(node) => children.push(node)
      None => ()
    }
  }
  if children.is_empty() {
    return Err("roots 下无 bookmark_bar/other/synced")
  }
  Ok({ name: label, url: None, children, added: 0L, root: "", })
}

///|
/// bm_flatten 的递归实现：当前 url 书签先收，folder 按 children 先序
/// 递归追加进 out。
fn bm_flatten_into(node : BookmarkNode, out : Array[BookmarkNode]) -> Unit {
  match node.url {
    Some(_) => out.push(node)
    None =>
      for child in node.children {
        bm_flatten_into(child, out)
      }
  }
}

///|
/// 书签树 → 全部 url 书签节点（先序：父节点在子节点前；folder 本身
/// 不进列表）。返回新数组，入参不被修改。
pub fn bm_flatten(node : BookmarkNode) -> Array[BookmarkNode] {
  let out : Array[BookmarkNode] = []
  bm_flatten_into(node, out)
  out
}

///|
/// 浏览器定义：(标识, 配置目录名, 目录内子目录)。
/// Brave 的 profile 在 BraveSoftware/Brave-Browser 下一层。
let bm_browser_defs : Array[(String, String, String)] = [
  ("google-chrome", "google-chrome", ""),
  ("chromium", "chromium", ""),
  ("microsoft-edge", "microsoft-edge", ""),
  ("brave", "BraveSoftware", "Brave-Browser"),
]

///|
/// Bookmarks 文件路径拼装：
/// <配置根>/<目录[/子目录]>/<profile>/Bookmarks。
pub fn bm_bookmarks_path(
  config_root : String,
  dir : String,
  subdir : String,
  profile : String,
) -> String {
  let base = if subdir != "" {
    config_root + "/" + dir + "/" + subdir
  } else {
    config_root + "/" + dir
  }
  base + "/" + profile + "/Bookmarks"
}

// ---------------------------------------------------------------------------
// 探测与读取（读盘走 read_text_file，只读不开写）
// ---------------------------------------------------------------------------

///|
/// 当前平台是否支持浏览器书签读取（本文件仅实现 Linux 路径探测）。
pub fn bm_supported() -> Bool {
  platform() == "linux"
}

///|
/// 列出有可读 Bookmarks 文件的浏览器 profile：在配置根下按浏览器定义 ×
/// profile 候选名（Default 与 Profile 1..24，见 [bh_profile_candidates]）
/// 逐一探测；无可读文件给 [BmNoBrowser]，非 Linux 给 [BmUnsupported]，
/// 配置目录定位失败给 [BmNoConfigDir]。
pub fn bm_browsers() -> Result[Array[BookmarkProfile], BookmarkError] {
  if platform() != "linux" {
    return Err(BmUnsupported)
  }
  let root = match
    bh_config_root(getenv_str("XDG_CONFIG_HOME"), getenv_str("HOME")) {
    Some(r) => r
    None => return Err(BmNoConfigDir)
  }
  let out : Array[BookmarkProfile] = []
  for def in bm_browser_defs {
    let (id, dir, subdir) = def
    for profile in bh_profile_candidates() {
      let path = bm_bookmarks_path(root, dir, subdir, profile)
      if read_text_file(path) is Some(_) {
        out.push({ browser: id, profile, bookmarks_path: path, })
      }
    }
  }
  if out.is_empty() {
    return Err(BmNoBrowser)
  }
  Ok(out)
}

///|
/// 指定浏览器的首个可读书签树：浏览器标识取 "google-chrome" /
/// "chromium" / "microsoft-edge" / "brave"（浏览器定义之外的标识按
/// [BmNoBrowser] 处理）；profile 取 Default 优先、其次 Profile 1..24。
/// 返回虚拟根树（名称 "<浏览器>/<profile>"，children 为三根），解析
/// 失败给 [BmIoFailed]，该书签文件不存在给 [BmNoBrowser]。
pub fn bm_bookmarks(browser : String) -> Result[BookmarkNode, BookmarkError] {
  if platform() != "linux" {
    return Err(BmUnsupported)
  }
  let root = match
    bh_config_root(getenv_str("XDG_CONFIG_HOME"), getenv_str("HOME")) {
    Some(r) => r
    None => return Err(BmNoConfigDir)
  }
  for def in bm_browser_defs {
    let (id, dir, subdir) = def
    if id != browser {
      continue
    }
    for profile in bh_profile_candidates() {
      let path = bm_bookmarks_path(root, dir, subdir, profile)
      match read_text_file(path) {
        Some(text) => {
          let label = id + "/" + profile
          match bm_parse_bookmarks(text, label) {
            Ok(node) => return Ok(node)
            Err(reason) => return Err(BmIoFailed(label + ": " + reason))
          }
        }
        None => ()
      }
    }
  }
  Err(BmNoBrowser)
}
