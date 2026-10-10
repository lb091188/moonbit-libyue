// 应用查找：已装应用清单与应用二进制查找。
// Linux：XDG .desktop 条目扫描 + which 语义固定目录查找；
// Windows：开始菜单 .lnk 递归扫描（全用户 %ProgramData% 与用户
// %APPDATA% 两层，同名用户覆盖全用户）+ PATH/PATHEXT 语义查找。
// 文件读取复用 read_text_file；目录枚举与存在性判断走 fsx_list_dir
// （只列条目名，不读文件内容），按"存在才扫、读不到静默跳过"处理，
// 全部扫描目录都不存在时报 NoScanDir。

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
  /// 平台不支持（macOS 无 XDG 桌面项体系与开始菜单体系）
  Unsupported
  /// 未找到该名称的可执行文件，带查找名
  NotFound(String)
  /// 扫描目录全都不存在（Linux 系统与用户 applications 目录、Windows
  /// 两层开始菜单目录皆缺失）
  NoScanDir
}

///|
pub impl Show for AppFindError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("AppFindError::Unsupported")
    NotFound(name) => logger.write_string("AppFindError::NotFound(\{name})")
    NoScanDir => logger.write_string("AppFindError::NoScanDir")
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
    locale_name: if locale != "" {
      locale
    } else {
      name
    },
    exec: appfind_kv_get(pairs, "Exec"),
    icon: appfind_kv_get(pairs, "Icon"),
    categories: appfind_split_semi(appfind_kv_get(pairs, "Categories")),
  })
}

///|
/// 目录条目名里是否有该名字（存在性判断的纯逻辑：只比条目名，不看文件
/// 内容，也不校验执行权限）。
fn appfind_names_hit(names : Array[String], name : String) -> Bool {
  for n in names {
    if n == name {
      return true
    }
  }
  false
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
pub fn appfind_merge_entries(
  layers : Array[Array[AppEntry]],
) -> Array[AppEntry] {
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
  acc
  .mut_view()
  .sort_by(fn(a, b) {
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
    "/usr/share/applications", "/usr/local/share/applications",
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
// 扫描与查找（desktop 读盘走 read_text_file，存在性判断走 fsx_list_dir）
// ---------------------------------------------------------------------------

///|
/// 取路径最后一段（列举器返回带路径分隔符的条目时只留文件名）。
fn appfind_basename(path : String) -> String {
  let mut cut = 0
  let mut i = 0
  while i < path.length() {
    let c = path.unsafe_get(i).to_int()
    if c == 47 || c == 92 {
      // '/' 与 '\'
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
/// 单个 applications 目录的一层条目：names 为该目录下的文件名数组，
/// 非 .desktop 与名为 ".desktop" 的条目过滤，单个文件读不到或解析
/// 后被过滤均静默跳过。
fn appfind_dir_layer(dir : String, names : Array[String]) -> Array[AppEntry] {
  let layer : Array[AppEntry] = []
  for fname in names {
    let base = appfind_basename(fname)
    if !base.has_suffix(".desktop") || base == ".desktop" {
      continue
    }
    let id = base[:base.length() - 8].to_owned()
    match @yue.read_text_file(dir + "/" + base) {
      Some(content) =>
        match appfind_desktop_to_entry(content, id) {
          Some(e) => layer.push(e)
          None => ()
        }
      None => ()
    }
  }
  layer
}

///|
/// 扫描收集：dirs 低→高优先级；list_dir 收目录路径、返回该目录下文件名
/// 数组。
fn appfind_collect(
  dirs : Array[String],
  list_dir : (String) -> Array[String],
) -> Array[AppEntry] {
  let layers : Array[Array[AppEntry]] = []
  for dir in dirs {
    layers.push(appfind_dir_layer(dir, list_dir(dir)))
  }
  appfind_merge_entries(layers)
}

///|
/// 已装应用清单公共实现：dirs 低→高优先级；list_dir 收目录路径、返回
/// 该目录下文件名数组的语义化结果，打不开的目录静默跳过；全部目录都
/// 打不开时报 NoScanDir。
fn appfind_installed_impl(
  dirs : Array[String],
  list_dir : (String) -> Result[Array[String], @yue.FsError],
) -> Result[Array[AppEntry], AppFindError] {
  let layers : Array[Array[AppEntry]] = []
  let mut scanned = false
  for dir in dirs {
    match list_dir(dir) {
      Ok(names) => {
        scanned = true
        layers.push(appfind_dir_layer(dir, names))
      }
      Err(_) => () // 存在才扫，读不到的目录静默跳过
    }
  }
  if !scanned {
    return Err(NoScanDir)
  }
  Ok(appfind_merge_entries(layers))
}

///|
/// 已装应用清单：真实扫描 /usr/share/applications、
/// /usr/local/share/applications、~/.local/share/applications（XDG
/// 数据目录约定）下的 .desktop，按 desktop id 去重（用户目录覆盖系统
/// 目录），结果按 name 排序；不存在的目录跳过，全部扫描目录都不存在
/// 时报 NoScanDir；Linux / Windows 之外给 [Unsupported]（Windows 走
/// 开始菜单 .lnk 扫描，见 [appfind_installed_win]）。
pub fn appfind_installed() -> Result[Array[AppEntry], AppFindError] {
  match @yue.platform() {
    "linux" =>
      appfind_installed_impl(
        appfind_scan_dirs(getenv_str("XDG_DATA_HOME"), getenv_str("HOME")),
        fn(path) { @yue.fsx_list_dir(path) },
      )
    "windows" => appfind_installed_win(fn(path) { @yue.fsx_list_dir(path) })
    _ => Err(Unsupported)
  }
}

///|
/// 已装应用清单（注入版）：与 [appfind_installed] 同流程，目录枚举由
/// 调用方注入（收目录路径、返回该目录下文件名数组，.desktop / .lnk
/// 之外的条目会被过滤），供无 fsx 层的调用方与测试使用；Linux /
/// Windows 之外给 [Unsupported]。
pub fn appfind_installed_with(
  list_dir : (String) -> Array[String],
) -> Result[Array[AppEntry], AppFindError] {
  match @yue.platform() {
    "linux" =>
      Ok(
        appfind_collect(
          appfind_scan_dirs(getenv_str("XDG_DATA_HOME"), getenv_str("HOME")),
          list_dir,
        ),
      )
    "windows" =>
      appfind_installed_win(fn(path) { Ok(list_dir(path)) })
    _ => Err(Unsupported)
  }
}

///|
/// 应用二进制查找（which 语义）：Linux 在 ~/.local/bin、/usr/local/bin、
/// /usr/bin、/bin、/usr/sbin、/sbin 中按序找名为 name 的条目；Windows
/// 按 %PATH% 目录序找 name（无扩展名时依次试 %PATHEXT% 扩展，缺省
/// .com/.exe/.bat/.cmd）。返回首个命中的完整路径；找不到给 NotFound。
/// name 为空或含路径分隔符直接 NotFound。命中判定为目录枚举里有该名字
/// 的条目（不读文件内容；本包不校验执行权限位）。
pub fn appfind_executable(name : String) -> Result[String, AppFindError] {
  match @yue.platform() {
    "linux" => {
      if name == "" || name.contains("/") {
        return Err(NotFound(name))
      }
      for dir in appfind_bin_dirs(getenv_str("HOME")) {
        match @yue.fsx_list_dir(dir) {
          Ok(names) =>
            if appfind_names_hit(names, name) {
              return Ok(dir + "/" + name)
            }
          Err(_) => () // 目录打不开（不存在/非目录/无权限）：当无此目录
        }
      }
      Err(NotFound(name))
    }
    "windows" => {
      if name == "" || name.contains("/") || name.contains("\\") || name.contains(":") {
        return Err(NotFound(name))
      }
      let exts = appfind_win_probe_names(name, getenv_str("PATHEXT"))
      let path_env = match getenv_str("PATH") {
        Some(p) => p
        None => ""
      }
      for dir in appfind_win_path_dirs(path_env) {
        match @yue.fsx_list_dir(dir) {
          Ok(names) =>
            for cand in exts {
              if appfind_names_hit(names, cand) {
                return Ok(dir + "/" + cand)
              }
            }
          Err(_) => () // 目录打不开：当无此目录
        }
      }
      Err(NotFound(name))
    }
    _ => Err(Unsupported)
  }
}

// ---------------------------------------------------------------------------
// Windows：开始菜单 .lnk 扫描与 PATH 查找（纯函数层白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// .lnk 后缀判定（ASCII 大小写不敏感，长度含 4 字符扩展）。
pub fn appfind_is_lnk(name : String) -> Bool {
  let n = name.length()
  if n <= 4 {
    return false
  }
  let s = name[n - 4:].to_owned().to_lower()
  s == ".lnk"
}

///|
/// Windows 开始菜单扫描目录（低 → 高优先级）：全用户 %ProgramData%
/// 在前、用户 %APPDATA% 在后（同名条目用户覆盖全用户）；环境变量缺失
/// 的层不入列。
pub fn appfind_win_scan_dirs(
  program_data : String?,
  appdata : String?,
) -> Array[String] {
  let dirs : Array[String] = []
  match program_data {
    Some(d) if d != "" => dirs.push(d + "/Microsoft/Windows/Start Menu/Programs")
    _ => ()
  }
  match appdata {
    Some(d) if d != "" => dirs.push(d + "/Microsoft/Windows/Start Menu/Programs")
    _ => ()
  }
  dirs
}

///|
/// %PATH% 拆分为目录数组（';' 分隔，空段滤除，保持原序）。
pub fn appfind_win_path_dirs(path_env : String) -> Array[String] {
  let dirs : Array[String] = []
  for part in path_env.split(";") {
    let p = part.trim().to_owned()
    if p != "" {
      dirs.push(p)
    }
  }
  dirs
}

///|
/// 候选文件名表：name 已含 '.' 视为带扩展，只试原名；否则依次试原名与
/// PATHEXT 各扩展（PATHEXT 形如 ".COM;.EXE;.BAT;.CMD"，缺省同此四项，
/// 统一小写）。
pub fn appfind_win_probe_names(
  name : String,
  pathext : String?,
) -> Array[String] {
  let cands : Array[String] = [name]
  if name.contains(".") {
    return cands
  }
  let raw = match pathext {
    Some(p) if p != "" => p
    _ => ".COM;.EXE;.BAT;.CMD"
  }
  for part in raw.split(";") {
    let e = part.trim().to_owned().to_lower()
    if e != "" {
      cands.push(name + e)
    }
  }
  cands
}

///|
/// 开始菜单单层条目收集：非 .lnk 与名为 ".lnk" 的条目过滤；条目字段为
/// 文件名派生（id/name 去 .lnk 扩展，exec 为 .lnk 完整路径——启动器
/// 本体，icon/categories 无来源留空，.lnk 元数据不解析）。
fn appfind_win_lnk_layer(dir : String, names : Array[String]) -> Array[AppEntry] {
  let layer : Array[AppEntry] = []
  for fname in names {
    let base = appfind_basename(fname)
    if !appfind_is_lnk(base) {
      continue
    }
    let id = base[:base.length() - 4].to_owned()
    if id == "" {
      continue
    }
    layer.push({
      id,
      name: id,
      locale_name: id,
      exec: dir + "/" + base,
      icon: "",
      categories: [],
    })
  }
  layer
}

///|
/// 开始菜单目录树递归收集（应用组嵌套子目录，深度钳 3）：list_dir 打得
/// 开的目录收 .lnk 条目并对非 .lnk 子项递归（对文件 list_dir 报错即当
/// 非目录跳过）；根目录打不开返回 false。
fn appfind_win_lnk_walk(
  dir : String,
  depth : Int,
  list_dir : (String) -> Result[Array[String], @yue.FsError],
  layer : Array[AppEntry],
) -> Bool {
  let names = match list_dir(dir) {
    Ok(ns) => ns
    Err(_) => return false
  }
  for e in appfind_win_lnk_layer(dir, names) {
    layer.push(e)
  }
  if depth <= 0 {
    return true
  }
  for fname in names {
    let base = appfind_basename(fname)
    if appfind_is_lnk(base) || base == "" {
      continue
    }
    // 子目录尝试：枚举失败（普通文件 / 无权限）静默跳过
    let child : Array[AppEntry] = []
    let _ = appfind_win_lnk_walk(dir + "/" + base, depth - 1, list_dir, child)
    for e in child {
      layer.push(e)
    }
  }
  true
}

///|
/// Windows 已装应用清单公共实现：两层开始菜单（全用户 → 用户）递归扫
/// .lnk，按 id 去重合并排序；两层都打不开报 NoScanDir。
fn appfind_installed_win(
  list_dir : (String) -> Result[Array[String], @yue.FsError],
) -> Result[Array[AppEntry], AppFindError] {
  let layers : Array[Array[AppEntry]] = []
  let mut scanned = false
  for dir in appfind_win_scan_dirs(
      getenv_str("ProgramData"),
      getenv_str("APPDATA"),
    ) {
    let layer : Array[AppEntry] = []
    if appfind_win_lnk_walk(dir, 3, list_dir, layer) {
      scanned = true
    }
    layers.push(layer)
  }
  if !scanned {
    return Err(NoScanDir)
  }
  Ok(appfind_merge_entries(layers))
}
