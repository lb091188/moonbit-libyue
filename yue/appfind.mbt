// 应用查找：已装应用清单（desktop entries 扫描）与应用二进制查找
// （which 语义的固定目录版）。文件读取复用 read_text_file /
// read_binary_file；目录探测按"存在才扫、读不到静默跳过"，
// 不存在的目录不报错。

///|
/// 已装应用条目（来自 .desktop 的 [Desktop Entry] 段）。
pub(all) struct AppEntry {
  /// desktop id（.desktop 文件名去掉扩展名）
  id : String
  /// Name 键（显示名）
  name : String
  /// 本地化名：Name[zh_CN] 优先，回退 Name
  locale_name : String
  /// Exec 键（原样，含参数与字段码）
  exec : String
  /// Icon 键（图标名或路径，原样）
  icon : String
  /// Categories 键按分号拆分（去空项）
  categories : Array[String]
}

///|
pub(all) enum AppFindError {
  /// 平台不支持（macOS/Windows 无 XDG 桌面项体系）
  Unsupported
  /// 未找到该名称的可执行文件，带查找名
  NotFound(String)
}

///|
pub impl Show for AppFindError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("AppFindError::Unsupported")
    NotFound(name) => logger.write_string("AppFindError::NotFound(\{name})")
  }
}

///|
pub extend AppFindError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯逻辑层：INI 子集解析 / 条目抽取 / 去重合并 / 目录拼装（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 找字符首次出现下标，无则 -1。
fn appfind_index_of_char(s : String, c : Int) -> Int {
  let mut i = 0
  while i < s.length() {
    if s.unsafe_get(i).to_int() == c {
      return i
    }
    i += 1
  }
  -1
}

///|
/// 解析 .desktop 的 [Desktop Entry] 段为键值对（INI 子集）：
/// # 与 ; 起始的行为注释、空行忽略、其余组整组忽略、首个 = 拆键值
/// （值内 = 保留）、键值首尾空白去除、同名键首个生效；
/// 本地化键（Name[zh_CN]）键名原样保留，GenericName 等其余键一并收录。
pub fn appfind_parse_desktop_entry(content : String) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  let mut in_group = false
  for line in content.split("\n") {
    let l = line.trim().to_owned()
    if l == "" || l.has_prefix("#") || l.has_prefix(";") {
      continue
    }
    if l.has_prefix("[") {
      in_group = l == "[Desktop Entry]"
      continue
    }
    if !in_group {
      continue
    }
    let eq = appfind_index_of_char(l, '=')
    if eq < 0 {
      continue
    }
    let key = l[:eq].trim().to_owned()
    if key == "" {
      continue
    }
    let value = l[eq + 1:].trim().to_owned()
    if !appfind_pairs_has(pairs, key) {
      pairs.push((key, value))
    }
  }
  pairs
}

///|
/// 键值对里是否已有该键（同名键首个生效的去重判断）。
fn appfind_pairs_has(pairs : Array[(String, String)], key : String) -> Bool {
  for p in pairs {
    if p.0 == key {
      return true
    }
  }
  false
}

///|
/// 取键值：无该键给空串。
fn appfind_kv_get(pairs : Array[(String, String)], key : String) -> String {
  for p in pairs {
    if p.0 == key {
      return p.1
    }
  }
  ""
}

///|
/// 分号列表拆分（Categories 用）：去空项与首尾空白。
fn appfind_split_semi(s : String) -> Array[String] {
  let out : Array[String] = []
  for part in s.split(";") {
    let p = part.trim().to_owned()
    if p != "" {
      out.push(p)
    }
  }
  out
}

///|
/// 从 .desktop 内容提取应用条目。过滤规则：Type 非 Application（缺省视为
/// Application）、NoDisplay 为 true、缺 Name 的条目返回 None。
pub fn appfind_desktop_to_entry(content : String, id : String) -> AppEntry? {
  let pairs = appfind_parse_desktop_entry(content)
  let type_ = appfind_kv_get(pairs, "Type")
  if type_ != "" && type_ != "Application" {
    return None
  }
  if appfind_kv_get(pairs, "NoDisplay") == "true" {
    return None
  }
  let name = appfind_kv_get(pairs, "Name")
  if name == "" {
    return None
  }
  let locale = appfind_kv_get(pairs, "Name[zh_CN]")
  Some({
    id,
    name,
    locale_name: if locale != "" { locale } else { name },
    exec: appfind_kv_get(pairs, "Exec"),
    icon: appfind_kv_get(pairs, "Icon"),
    categories: appfind_split_semi(appfind_kv_get(pairs, "Categories")),
  })
}

///|
/// 码点字典序比较（String 默认序是先比长度的 shortlex，应用清单要的是
/// 字母序）：逐码点比，全同则短者前。
fn appfind_str_cmp(a : String, b : String) -> Int {
  let n = a.length()
  let m = b.length()
  let mut i = 0
  while i < n && i < m {
    let x = a.unsafe_get(i).to_int()
    let y = b.unsafe_get(i).to_int()
    if x != y {
      return if x < y { -1 } else { 1 }
    }
    i += 1
  }
  if n < m {
    -1
  } else if n > m {
    1
  } else {
    0
  }
}

///|
/// 按 desktop id 去重合并：layers 按低→高优先级顺序传入，同 id 后者覆盖
/// 前者（用户目录覆盖系统目录）；结果按 name 码点字典序排序（同名按 id）。
pub fn appfind_merge_entries(layers : Array[Array[AppEntry]]) -> Array[AppEntry] {
  let acc : Array[AppEntry] = []
  for layer in layers {
    for e in layer {
      let mut hit = -1
      let mut i = 0
      while i < acc.length() {
        if acc[i].id == e.id {
          hit = i
          break
        }
        i += 1
      }
      if hit >= 0 {
        acc[hit] = e
      } else {
        acc.push(e)
      }
    }
  }
  acc.mut_view().sort_by(fn(a, b) {
    let by_name = appfind_str_cmp(a.name, b.name)
    if by_name != 0 {
      by_name
    } else {
      appfind_str_cmp(a.id, b.id)
    }
  })
  acc
}

///|
/// 用户 applications 目录：XDG_DATA_HOME（设且非空）优先，回退
/// $HOME/.local/share。
pub fn appfind_user_apps_dir(
  xdg_data_home : String?,
  home : String?,
) -> String? {
  match xdg_data_home {
    Some(d) if d != "" => Some(d + "/applications")
    _ =>
      match home {
        Some(h) if h != "" => Some(h + "/.local/share/applications")
        _ => None
      }
  }
}

///|
/// desktop entries 扫描目录列表（低→高优先级）：/usr/share →
/// /usr/local/share → 用户目录（无用户目录时仅系统两处）。
pub fn appfind_scan_dirs(
  xdg_data_home : String?,
  home : String?,
) -> Array[String] {
  let dirs : Array[String] = [
    "/usr/share/applications",
    "/usr/local/share/applications",
  ]
  match appfind_user_apps_dir(xdg_data_home, home) {
    Some(d) => {
      dirs.push(d)
      ()
    }
    None => ()
  }
  dirs
}

///|
/// 可执行文件查找目录（按序）：~/.local/bin、/usr/local/bin、/usr/bin、
/// /bin、/usr/sbin、/sbin；无 home 时跳过 ~/.local/bin。
pub fn appfind_bin_dirs(home : String?) -> Array[String] {
  let dirs : Array[String] = []
  match home {
    Some(h) if h != "" => dirs.push(h + "/.local/bin")
    _ => ()
  }
  dirs.push("/usr/local/bin")
  dirs.push("/usr/bin")
  dirs.push("/bin")
  dirs.push("/usr/sbin")
  dirs.push("/sbin")
  dirs
}

// ---------------------------------------------------------------------------
// 扫描与查找（读盘走 read_text_file / read_binary_file）
// ---------------------------------------------------------------------------

///|
/// 取路径最后一段（列举器返回带路径分隔符的条目时只留文件名）。
fn appfind_basename(path : String) -> String {
  let mut cut = 0
  let mut i = 0
  while i < path.length() {
    if path.unsafe_get(i).to_int() == 47 {
      // '/'
      cut = i + 1
    }
    i += 1
  }
  if cut == 0 {
    path
  } else {
    path[cut:].to_owned()
  }
}

///|
/// 扫描收集：dirs 低→高优先级；list_dir 收目录路径、返回该目录下文件名
/// 数组；非 .desktop 与名为 ".desktop" 的条目过滤，单个文件读不到或解析
/// 后被过滤均静默跳过。
fn appfind_collect(
  dirs : Array[String],
  list_dir : (String) -> Array[String],
) -> Array[AppEntry] {
  let layers : Array[Array[AppEntry]] = []
  for dir in dirs {
    let layer : Array[AppEntry] = []
    for fname in list_dir(dir) {
      let base = appfind_basename(fname)
      if !base.has_suffix(".desktop") || base == ".desktop" {
        continue
      }
      let id = base[:base.length() - 8].to_owned()
      match read_text_file(dir + "/" + base) {
        Some(content) =>
          match appfind_desktop_to_entry(content, id) {
            Some(e) => layer.push(e)
            None => ()
          }
        None => ()
      }
    }
    layers.push(layer)
  }
  appfind_merge_entries(layers)
}

///|
/// 已装应用清单：扫描 /usr/share/applications、/usr/local/share/applications、
/// ~/.local/share/applications 三个目录的 .desktop，按 desktop id 去重
/// （用户目录覆盖系统目录），结果按 name 排序；目录不存在跳过不报错。
/// 本包未提供目录枚举原语，调用方须注入 list_dir（收目录路径、返回该
/// 目录下文件名数组，.desktop 之外的条目会被过滤）；非 Linux 给
/// [Unsupported]。
pub fn appfind_installed_with(
  list_dir : (String) -> Array[String],
) -> Result[Array[AppEntry], AppFindError] {
  match platform() {
    "linux" =>
      Ok(appfind_collect(
        appfind_scan_dirs(getenv_str("XDG_DATA_HOME"), getenv_str("HOME")),
        list_dir,
      ))
    _ => Err(Unsupported)
  }
}

///|
/// 应用二进制查找（which 语义的固定目录版）：在 ~/.local/bin、
/// /usr/local/bin、/usr/bin、/bin、/usr/sbin、/sbin 中按序找名为 name 的
/// 文件，返回首个命中的完整路径；找不到给 NotFound。name 为空或含路径
/// 分隔符直接 NotFound。命中判定为文件可打开读取（本包不校验执行
/// 权限位）。
pub fn appfind_executable(name : String) -> Result[String, AppFindError] {
  match platform() {
    "linux" => {
      if name == "" || name.contains("/") {
        return Err(NotFound(name))
      }
      for dir in appfind_bin_dirs(getenv_str("HOME")) {
        let p = dir + "/" + name
        if read_binary_file(p) is Some(_) {
          return Ok(p)
        }
      }
      Err(NotFound(name))
    }
    _ => Err(Unsupported)
  }
}
