// 应用查找：已装应用清单与应用二进制查找（which 语义的固定目录版）。
// 三个平台各自的后端：Linux 扫 .desktop（XDG 目录约定），Windows 递归扫开始
// 菜单的 .lnk，macOS 扫 .app 包读 Info.plist 的公开键。条目读取复用
// [sys_read_text_file]，目录枚举走 [fsx_list_dir]（只列条目名，不读文件内容），
// 按「存在才扫、读不到静默跳过」处理，全部扫描目录都不存在时报 NoScanDir。

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
  /// 平台不支持（三平台都已有后端，这条只留给认不出来的环境）
  Unsupported
  /// 未找到该名称的可执行文件，带查找名
  NotFound(String)
  /// 扫描目录全都不存在（系统与用户 applications 目录皆缺失）
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
/// 分号列表拆分（Categories 与 mimeapps 的候选列表用）：去空项与首尾空白。
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
// macOS 臂：.app 包 + Info.plist（公开键；纯函数层由 appfind_wbtest 钉住）
// ---------------------------------------------------------------------------

///|
/// macOS 的应用扫描目录（低→高优先级，同 id 后者覆盖前者）：
/// /System/Applications、/Applications、$HOME/Applications；系统两处各带上
/// 自己的 `Utilities` 子目录（macOS 把实用工具嵌在那一层）。
pub fn appfind_mac_dirs(home : String?) -> Array[String] {
  let dirs : Array[String] = []
  for base in ["/System/Applications", "/Applications"] {
    dirs.push(base)
    dirs.push(base + "/Utilities")
  }
  match home {
    Some(h) if h != "" => {
      dirs.push(h + "/Applications")
      ()
    }
    _ => ()
  }
  dirs
}

///|
/// 目录条目名 → .app 包的可读标签（"Safari.app" → Some("Safari")）。
/// 非 .app、以及只有后缀的 ".app" 空名包给 None。
pub fn appfind_mac_bundle_label(name : String) -> String? {
  if !name.has_suffix(".app") || name.length() <= 4 {
    return None
  }
  Some(name[:name.length() - 4].to_owned())
}

///|
/// s 的 at 处是否以 p 开头（下标按 UTF-16 单元，与 unsafe_get 同一口径）。
fn appfind_starts_with_at(s : String, at : Int, p : String) -> Bool {
  let n = p.length()
  if at < 0 || at + n > s.length() {
    return false
  }
  let mut k = 0
  while k < n {
    if s.unsafe_get(at + k) != p.unsafe_get(k) {
      return false
    }
    k += 1
  }
  true
}

///|
/// 从 from 起找子串 p，命中给下标，否则 -1。
fn appfind_index_from(s : String, p : String, from : Int) -> Int {
  let n = p.length()
  if n == 0 || from < 0 {
    return -1
  }
  let mut i = from
  while i + n <= s.length() {
    if appfind_starts_with_at(s, i, p) {
      return i
    }
    i += 1
  }
  -1
}

///|
/// 从 from 起找码值为 code 的 UTF-16 单元，命中给下标，否则 -1。
fn appfind_char_from(s : String, code : Int, from : Int) -> Int {
  let mut i = if from < 0 { 0 } else { from }
  while i < s.length() {
    if s.unsafe_get(i).to_int() == code {
      return i
    }
    i += 1
  }
  -1
}

///|
/// XML 实体回解：`&amp; &lt; &gt; &quot; &apos;` 五个（Info.plist 只用这些），
/// 其余 '&' 原样留着。
fn appfind_plist_unescape(v : String) -> String {
  let names : Array[String] = ["&amp;", "&lt;", "&gt;", "&quot;", "&apos;"]
  let texts : Array[String] = ["&", "<", ">", "\"", "'"]
  let amp = 38 // '&'
  let out = StringBuilder()
  let mut i = 0
  while i < v.length() {
    if v.unsafe_get(i).to_int() != amp {
      // 普通段：一路吃到下一个 '&' 为止（切片边界都是 ASCII，安全）
      let j = appfind_char_from(v, amp, i)
      if j < 0 {
        out.write_string(v[i:].to_owned())
        i = v.length()
      } else {
        out.write_string(v[i:j].to_owned())
        i = j
      }
    } else {
      let mut hit = -1
      let mut k = 0
      while k < names.length() {
        if appfind_starts_with_at(v, i, names[k]) {
          hit = k
          break
        }
        k += 1
      }
      if hit >= 0 {
        out.write_string(texts[hit])
        i += names[hit].length()
      } else {
        out.write_string("&")
        i += 1
      }
    }
  }
  out.to_string()
}

///|
/// 取 XML plist 里 `<key>K</key>` 紧跟的 `<string>` 值（带实体回解）。键不存在、
/// 或键后面第一个标签不是 `<string>`（`<array/>`/`<dict>`/`<true/>` 这类）给
/// None——只认字符串值，不去猜别的类型。
pub fn appfind_plist_string(plist : String, key : String) -> String? {
  if key == "" {
    return None
  }
  let needle = "<key>" + key + "</key>"
  let lt = 60 // '<'
  let gt = 62 // '>'
  let mut at = appfind_index_from(plist, needle, 0)
  while at >= 0 {
    let tag = appfind_char_from(plist, lt, at + needle.length())
    let head_ok = tag >= 0 && tag + 7 < plist.length() &&
      appfind_starts_with_at(plist, tag, "<string")
    let head = if head_ok { plist.unsafe_get(tag + 7).to_int() } else { 0 }
    // '<string' 后面必须紧跟 '>' 或属性分隔（防 `<stringify>` 这种同名前缀）
    let is_string_tag =
      head == gt || head == 32 || head == 9 || head == 10
    if head_ok && is_string_tag {
      let open = appfind_char_from(plist, gt, tag)
      if open >= 0 {
        let close = appfind_index_from(plist, "</string>", open + 1)
        if close >= 0 {
          let raw = plist[open + 1:close].to_owned()
          return Some(appfind_plist_unescape(raw))
        }
      }
    }
    at = appfind_index_from(plist, needle, at + 1)
  }
  None
}

///|
/// 一个 .app 包 → 应用条目（`label` 是包目录名去掉 .app）：
/// - `name`：CFBundleDisplayName → CFBundleName → label；
/// - `id`：CFBundleIdentifier → label（与 desktop id 同档的「稳定标识」）；
/// - `exec`：Contents/MacOS/<CFBundleExecutable> 的绝对路径（无该键给空串）；
/// - `icon`：Contents/Resources/<CFBundleIconFile>（无扩展名时补 .icns；
///   无该键给空串——不为图标去读一遍 Resources，上百个 app 各一次不值）；
/// - `locale_name`：与 `name` 同值，本地化名在 .lproj 里，公开 plist 键给不到；
/// - `categories`：恒空，macOS 没有 desktop Categories 的对等物。
/// plist 给 None（二进制 plist 或读不到）时全按回退值给：宁可名字粗一点，
/// 也不要应用从清单里消失。
pub fn appfind_mac_entry(
  app_dir : String,
  label : String,
  plist : String?,
) -> AppEntry {
  match plist {
    None => {
      id: label,
      name: label,
      locale_name: label,
      exec: "",
      icon: "",
      categories: [],
    }
    Some(text) => {
      let res = app_dir + "/Contents/Resources"
      let name = match appfind_plist_string(text, "CFBundleDisplayName") {
        Some(n) if n != "" => n
        _ =>
          match appfind_plist_string(text, "CFBundleName") {
            Some(n) if n != "" => n
            _ => label
          }
      }
      let id = match appfind_plist_string(text, "CFBundleIdentifier") {
        Some(i) if i != "" => i
        _ => label
      }
      let exec = match appfind_plist_string(text, "CFBundleExecutable") {
        Some(e) if e != "" => app_dir + "/Contents/MacOS/" + e
        _ => ""
      }
      let icon = match appfind_plist_string(text, "CFBundleIconFile") {
        Some(f) if f != "" =>
          if f.has_suffix(".icns") {
            res + "/" + f
          } else {
            res + "/" + f + ".icns"
          }
        _ => ""
      }
      {
        id,
        name,
        locale_name: name,
        exec,
        icon,
        categories: [],
      }
    }
  }
}

///|
/// 列表里是否已有该串。
fn appfind_in_list(list : Array[String], s : String) -> Bool {
  let mut i = 0
  while i < list.length() {
    if list[i] == s {
      return true
    }
    i += 1
  }
  false
}

///|
/// macOS 的可执行文件查找目录（按序）：PATH 各段（':' 分隔，取非空且绝对
/// 的）在前，`which` 就是这个顺序；PATH 没覆盖到的再按固定清单补
/// ~/.local/bin、/usr/local/bin、/opt/homebrew/bin、/opt/homebrew/sbin、
/// /usr/bin、/bin、/usr/sbin、/sbin——从 Dock/Finder 起来的进程拿不到
/// shell 的 PATH，Apple Silicon 的 Homebrew 就在其中补的那两条里。
pub fn appfind_mac_exec_dirs(
  path_env : String?,
  home : String?,
) -> Array[String] {
  let out : Array[String] = []
  let path = match path_env {
    Some(p) => p
    None => ""
  }
  for seg in path.split(":") {
    let d = seg.to_owned()
    if d != "" && d.has_prefix("/") && !appfind_in_list(out, d) {
      out.push(d)
    }
  }
  let fixed : Array[String] = [
    "/usr/local/bin", "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/bin",
    "/bin", "/usr/sbin", "/sbin",
  ]
  let user_bin = match home {
    Some(h) if h != "" => h + "/.local/bin"
    _ => ""
  }
  if user_bin != "" && !appfind_in_list(out, user_bin) {
    out.push(user_bin)
  }
  for d in fixed {
    if !appfind_in_list(out, d) {
      out.push(d)
    }
  }
  out
}

// ---------------------------------------------------------------------------
// 扫描与查找（desktop 读盘走 sys_read_text_file，存在性判断走 fsx_list_dir；
// macOS 的 .app 读同一份 sys_read_text_file 取 Info.plist）
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
    match sys_read_text_file(dir + "/" + base) {
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
  list_dir : (String) -> Result[Array[String], FsError],
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
/// 单个 applications 目录的一层 .app 条目：非 .app 过滤；Info.plist 读不到
/// （二进制 plist / 无权限）时按包名给条目，应用不会从清单里消失。
fn appfind_mac_dir_layer(
  dir : String,
  names : Array[String],
) -> Array[AppEntry] {
  let layer : Array[AppEntry] = []
  for fname in names {
    let base = appfind_basename(fname)
    match appfind_mac_bundle_label(base) {
      None => ()
      Some(label) => {
        let app_dir = dir + "/" + base
        let plist = sys_read_text_file(app_dir + "/Contents/Info.plist")
        layer.push(appfind_mac_entry(app_dir, label, plist))
      }
    }
  }
  layer
}

///|
/// macOS 的已装应用清单：dirs 低→高优先级（同 id 后者覆盖），打不开的目录
/// 静默跳过，全部打不开时报 NoScanDir——与 Linux 同一道闸。
fn appfind_mac_installed(
  dirs : Array[String],
  list_dir : (String) -> Result[Array[String], FsError],
) -> Result[Array[AppEntry], AppFindError] {
  let layers : Array[Array[AppEntry]] = []
  let mut scanned = false
  for dir in dirs {
    match list_dir(dir) {
      Ok(names) => {
        scanned = true
        layers.push(appfind_mac_dir_layer(dir, names))
      }
      Err(_) => ()
    }
  }
  if !scanned {
    return Err(NoScanDir)
  }
  Ok(appfind_merge_entries(layers))
}

///|
/// 已装应用清单：Linux 扫 /usr/share/applications、
/// /usr/local/share/applications、~/.local/share/applications（XDG 数据目录
/// 约定）下的 .desktop；Windows 递归扫开始菜单的 .lnk（用户级 + 全机级）；
/// macOS 扫 /System/Applications、/Applications（各带 Utilities 一层）与
/// ~/Applications 下的 .app 包。三平台同一条去重与排序口径：按 id 去重
/// （用户目录覆盖系统目录），结果按 name 排序；不存在的目录跳过，全部扫描
/// 目录都不存在时报 NoScanDir。
/// Windows 开始菜单根目录（用户级 + 全机级），不存在的跳过。
fn appfind_windows_dirs() -> Array[String] {
  let dirs : Array[String] = []
  for root in [envx_get("APPDATA"), envx_get("ProgramData")] {
    match root {
      Some(r) if r != "" => {
        let d = r + "\\Microsoft\\Windows\\Start Menu\\Programs"
        match fsx_list_dir(d) {
          Ok(_) => {
            let _ = dirs.push(d)
          }
          Err(_) => ()
        }
      }
      _ => ()
    }
  }
  dirs
}

///|
/// 递归收集 dir 子树下的 .lnk 全路径（目录判定=能列出来）。
fn appfind_windows_collect(dir : String, acc : Array[String]) -> Unit {
  match fsx_list_dir(dir) {
    Ok(names) =>
      for name in names {
        let lower = name.to_lower()
        let full = dir + "\\" + name
        if lower.has_suffix(".lnk") {
          let _ = acc.push(full)
        } else {
          appfind_windows_collect(full, acc)
        }
      }
    Err(_) => () // 文件或打不开的目录：不递归
  }
}

///|
/// .lnk 路径 → AppEntry：id/name 取文件名主干，exec=lnk 全路径
///（ShellExecute 可直接启动），icon/categories Windows 構不建为空。
fn appfind_windows_entry(lnk : String) -> AppEntry {
  // 文件名 = 最后一个反斜杠之后；id/name = 主干（去 .lnk 后缀）
  let mut cut = 0
  let mut j = 0
  for ch in lnk {
    if ch == '\\' {
      cut = j + 1
    }
    j += 1
  }
  let mut fname = ""
  let mut k = 0
  for ch in lnk {
    if k >= cut {
      fname = fname + ch.to_string()
    }
    k += 1
  }
  let base = if fname.has_suffix(".lnk") {
    fname[:fname.length() - 4].to_owned()
  } else {
    fname
  }
  {
    id: base,
    name: base,
    locale_name: base,
    exec: lnk,
    icon: "",
    categories: ["StartMenu"],
  }
}
///|
pub fn appfind_installed() -> Result[Array[AppEntry], AppFindError] {
  match sys_platform() {
    "linux" =>
      appfind_installed_impl(
        appfind_scan_dirs(envx_get("XDG_DATA_HOME"), envx_get("HOME")),
        fn(path) { fsx_list_dir(path) },
      )
    "windows" => {
      // 开始菜单递归扫 .lnk（用户级 + 全机级）；扫描目录皆缺 → NoScanDir
      let dirs = appfind_windows_dirs()
      if dirs.length() == 0 {
        return Err(NoScanDir)
      }
      let acc : Array[String] = []
      for d in dirs {
        appfind_windows_collect(d, acc)
      }
      Ok(acc.map(appfind_windows_entry))
    }
    "macos" =>
      // .app 包扫 /Applications 那三层（含 Utilities 与用户级），读公开
      // plist 键出条目；扫描目录皆缺 → NoScanDir
      appfind_mac_installed(
        appfind_mac_dirs(envx_get("HOME")),
        fn(path) { fsx_list_dir(path) },
      )
    _ => Err(Unsupported)
  }
}

///|
/// 已装应用清单（注入版）：与 [appfind_installed] 同流程，目录枚举由
/// 调用方注入（收目录路径、返回该目录下文件名数组，.desktop 之外的
/// 条目会被过滤），供无 fsx 层的调用方与测试使用；非 Linux 给
/// [Unsupported]。
pub fn appfind_installed_with(
  list_dir : (String) -> Array[String],
) -> Result[Array[AppEntry], AppFindError] {
  match sys_platform() {
    "linux" =>
      Ok(
        appfind_collect(
          appfind_scan_dirs(envx_get("XDG_DATA_HOME"), envx_get("HOME")),
          list_dir,
        ),
      )
    _ => Err(Unsupported)
  }
}

///|
/// 应用二进制查找（which 语义的固定目录版）：在 ~/.local/bin、
/// /usr/local/bin、/usr/bin、/bin、/usr/sbin、/sbin 中按序找名为 name 的
/// 条目，返回首个命中的完整路径；找不到给 NotFound。name 为空或含路径
/// 分隔符直接 NotFound。命中判定为目录枚举里有该名字的条目（不读文件
/// 内容；本包不校验执行权限位）。
pub fn appfind_executable(name : String) -> Result[String, AppFindError] {
  match sys_platform() {
    "windows" => {
      // which 语义：按 PATH 各目录找 name / name.exe
      if name == "" || name.contains("/") || name.contains("\\") {
        return Err(NotFound(name))
      }
      match envx_get("PATH") {
        Some(path) =>
          for dir in path.split(";") {
            let d = dir.to_owned()
            if d == "" {
              continue
            }
            match fsx_list_dir(d) {
              Ok(names) => {
                for n in names {
                  let ln = n.to_lower()
                  let target = name.to_lower()
                  if ln == target || ln == target + ".exe" {
                    return Ok(d + "\\" + n.to_string())
                  }
                }
              }
              Err(_) => ()
            }
          }
        None => ()
      }
      Err(NotFound(name))
    }
    "linux" => {
      if name == "" || name.contains("/") {
        return Err(NotFound(name))
      }
      for dir in appfind_bin_dirs(envx_get("HOME")) {
        match fsx_list_dir(dir) {
          Ok(names) =>
            if appfind_names_hit(names, name) {
              return Ok(dir + "/" + name)
            }
          Err(_) => () // 目录打不开（不存在/非目录/无权限）：当无此目录
        }
      }
      Err(NotFound(name))
    }
    "macos" => {
      // 与 Linux 同一判法（目录枚举里有该名字就算命中，不校验执行权限位），
      // 只是查找目录按 which 的口径走 PATH 再补固定清单，见
      // appfind_mac_exec_dirs——从 Dock/Finder 起来的进程没有 shell 的 PATH，
      // Apple Silicon 的 Homebrew 就靠固定那几条兜住。
      if name == "" || name.contains("/") {
        return Err(NotFound(name))
      }
      for dir in appfind_mac_exec_dirs(envx_get("PATH"), envx_get("HOME")) {
        match fsx_list_dir(dir) {
          Ok(names) =>
            if appfind_names_hit(names, name) {
              return Ok(dir + "/" + name)
            }
          Err(_) => ()
        }
      }
      Err(NotFound(name))
    }
    _ => Err(Unsupported)
  }
}
