// 默认应用查询与文件类型识别:查询/设置走 xdg-mime,关联枚举直读
// mimeapps.list(XDG mimeapps 规范的三层配置)。纯 MoonBit,无 FFI。

///|
/// 默认应用查询的错误类型。
pub(all) enum DefaultAppError {
  /// 当前环境没有可用的查询工具（xdg-mime 不在 PATH）
  Unsupported
  /// 查询命令执行失败（含退出码与 stderr）
  QueryFailed(String)
  /// 该 MIME 类型没有登记默认应用
  NoDefault(String)
  /// 读写 mimeapps.list 失败
  IoFailed(String)
}

///|
pub impl Show for DefaultAppError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("当前环境不支持默认应用查询（缺少 xdg-mime）")
    QueryFailed(m) => logger.write_string("查询失败: \{m}")
    NoDefault(m) => logger.write_string("MIME 类型未登记默认应用: \{m}")
    IoFailed(m) => logger.write_string("读写 mimeapps.list 失败: \{m}")
  }
}

///|
pub extend DefaultAppError with Show::{to_string, output}

// ===== 纯函数层 =====

///|
/// 解析 mimeapps.list 内容:返回 (段名, 键值对数组) 列表;注释行、空行、
/// 段外的行跳过;同名段可出现多次(查表时全量扫描)。键重复时首个生效。
pub fn da_parse_mimeapps(content : String) -> Array[(String, Array[(String, String)])] {
  let sections : Array[(String, Array[(String, String)])] = []
  let mut cur : Int = -1
  for raw in content.split("\n") {
    let line = raw.trim().to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    if line.has_prefix("[") && line.has_suffix("]") {
      sections.push((line[1:line.length() - 1].to_owned(), []))
      cur = sections.length() - 1
      continue
    }
    if cur < 0 {
      continue
    }
    let eq = appfind_index_of_char(line, '=')
    if eq < 0 {
      continue
    }
    let key = line[:eq].trim().to_owned()
    let value = line[eq + 1:].trim().to_owned()
    if key == "" {
      continue
    }
    // mimeapps.list 的同名键不去重:多行同名是候选列表,默认应用按规范
    // 后写覆盖先写(da_default_for 取最后一行)
    let pairs = sections[cur].1
    pairs.push((key, value))
  }
  sections
}

///|
/// 取所有指定段里 key 对应 value 的列表(按文件/段出现序)。
pub fn da_section_values(
  sections : Array[(String, Array[(String, String)])],
  section : String,
  key : String,
) -> Array[String] {
  let out : Array[String] = []
  for (name, pairs) in sections {
    if name != section {
      continue
    }
    for (k, v) in pairs {
      if k == key {
        out.push(v)
      }
    }
  }
  out
}

///|
/// 把 mime=desktop 合并进 mimeapps.list 文本:目标段存在且已有该 mime 行
/// 则替换,已有段无该行则段内追加;段不存在时在文末补新段。其余内容原样保留。
pub fn da_merge_default_line(content : String, mime : String, desktop : String) -> String {
  // 找 [Default Applications] 段区间:起始行到下一个段头
  let mut start : Int = -1
  let mut end : Int = -1
  let mut line_no : Int = 0
  let mut replaced : Bool = false
  let result : Array[String] = []
  for raw in content.split("\n") {
    let line = raw.trim().to_owned()
    let is_head = line.has_prefix("[") && line.has_suffix("]")
    if is_head {
      if start < 0 && line[1:line.length() - 1].to_owned() == "Default Applications" {
        start = line_no
      } else if start >= 0 && end < 0 {
        end = line_no
      }
    }
    result.push(raw.to_owned())
    line_no = line_no + 1
  }
  if start >= 0 {
    if end < 0 {
      end = line_no
    }
    for i in start..<end {
      let l = result[i].trim().to_owned()
      let eq = appfind_index_of_char(l, '=')
      if eq >= 0 && l[:eq].trim().to_owned() == mime {
        result[i] = mime + "=" + desktop
        replaced = true
        continue
      }
    }
  }
  let sb = StringBuilder()
  if start < 0 {
    // 原样输出,文末补段
    sb.write_string(content)
    if content.length() > 0 && !content.has_suffix("\n") {
      sb.write_string("\n")
    }
    sb.write_string("[Default Applications]\n")
    sb.write_string(mime + "=" + desktop + "\n")
  } else if replaced {
    for l in result {
      sb.write_string(l)
      sb.write_string("\n")
    }
  } else {
    // 段内追加(插到段尾之前,即下标 end 处)
    let tail : Array[String] = []
    for i in end..<result.length() {
      tail.push(result[i])
    }
    let head : Array[String] = []
    for i in 0..<end {
      head.push(result[i])
    }
    for l in head {
      sb.write_string(l)
      sb.write_string("\n")
    }
    sb.write_string(mime + "=" + desktop + "\n")
    for l in tail {
      sb.write_string(l)
      sb.write_string("\n")
    }
  }
  sb.to_string()
}

///|
/// 从文本列表合并某 mime 的全部关联 .desktop(默认应用排最前,去重)。
pub fn da_associations_of_texts(texts : Array[String], mime : String) -> Array[String] {
  let out : Array[String] = []
  for text in texts {
    let sections = da_parse_mimeapps(text)
    for v in da_section_values(sections, "Default Applications", mime) {
      da_push_unique(out, v)
    }
    for v in da_section_values(sections, "Added Associations", mime) {
      da_push_unique(out, v)
    }
  }
  out
}

///|
/// push 前去重(按已收录的完整 value)。
fn da_push_unique(out : Array[String], value : String) -> Unit {
  for part in appfind_split_semi(value) {
    if !da_str_has(out, part) {
      out.push(part)
    }
  }
}

///|
fn da_str_has(arr : Array[String], s : String) -> Bool {
  for x in arr {
    if x == s {
      return true
    }
  }
  false
}

// ===== 探测与 IO 层 =====

///|
/// 是否有可用的查询命令（xdg-mime 在 PATH）。
pub fn da_supported() -> Bool {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    return true // Windows AssocQueryString / macOS LaunchServices 直连
  }
  match appfind_executable("xdg-mime") {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// mimeapps.list 候选路径:用户配置优先,系统兜底。
fn da_mimeapps_files() -> Array[String] {
  let files : Array[String] = []
  match getenv_str("XDG_CONFIG_HOME") {
    Some(dir) => files.push(dir + "/mimeapps.list")
    None => ()
  }
  match getenv_str("XDG_DATA_HOME") {
    Some(dir) => files.push(dir + "/applications/mimeapps.list")
    None => ()
  }
  match getenv_str("HOME") {
    Some(home) => {
      if files.length() == 0 {
        files.push(home + "/.config/mimeapps.list")
      }
      files.push(home + "/.local/share/applications/mimeapps.list")
    }
    None => ()
  }
  files.push("/usr/share/applications/mimeapps.list")
  files
}

///|
/// 推断文件的类型：Linux 经 xdg-mime query filetype 给 MIME 类型
/// （"application/pdf" 形态）；Windows 无 MIME 层，给小写扩展名
/// （".pdf" 形态——文件类型键即扩展名，形态差异由调用方消化）。
pub fn da_file_type(path : String) -> Result[String, DefaultAppError] {
  // Windows 无 MIME 层给扩展名；macOS 走 LaunchServices 但键形态同取
  // 扩展名（UTI 差异由 shim 吸收），两分支一致
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    let dot = da_last_index_of(path, '.')
    let slash = da_max(
      da_last_index_of(path, '/'),
      da_last_index_of(path, '\\'),
    )
    if dot < 0 || dot < slash || dot == path.length() - 1 {
      return Err(QueryFailed("无扩展名: \{path}"))
    }
    return Ok(path[dot:].to_owned().to_lower())
  }
  if !da_supported() {
    return Err(Unsupported)
  }
  match pr_run("xdg-mime", ["query", "filetype", path]) {
    Ok(out) => {
      let mime = out.stdout.trim().to_owned()
      if out.exit_code == 0 && mime != "" && mime.contains("/") {
        Ok(mime)
      } else {
        Err(QueryFailed(mime))
      }
    }
    Err(ProcError::NonZeroExit(_, err)) =>
      Err(QueryFailed("xdg-mime 退出码非零: \{err}"))
    Err(ProcError::Timeout(cmd)) =>
      Err(QueryFailed("xdg-mime 超时: \{cmd}"))
    Err(ProcError::SpawnFailed(m)) =>
      Err(QueryFailed("xdg-mime 启动失败: \{m}"))
    Err(ProcError::Signaled(sn)) =>
      Err(QueryFailed("xdg-mime 被信号 \{sn} 终止"))
    Err(ProcError::Unsupported) => Err(Unsupported)
  }
}

///|
/// 字符在文本中最后出现的下标（无则 -1）。
fn da_last_index_of(s : String, c : Char) -> Int {
  let mut at = -1
  for i = 0; i < s.length(); i = i + 1 {
    if s.unsafe_get(i).to_int() == c.to_int() {
      at = i
    }
  }
  at
}

///|
/// 两数取大。
fn da_max(a : Int, b : Int) -> Int {
  if a >= b {
    a
  } else {
    b
  }
}

///|
/// 查询类型的默认应用：Linux 优先 xdg-mime query default（.desktop 名），
/// 回退解析 mimeapps.list 的 [Default Applications] 段；Windows 经
/// AssocQueryString 查关联的可执行文件完整路径（mime 传扩展名
/// （".pdf"）或协议（"http"），查不到给 NoDefault）。
pub fn da_default_for(mime : String) -> Result[String, DefaultAppError] {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    if mime == "" {
      return Err(QueryFailed("类型/协议为空"))
    }
    let ok = Ref(0)
    let exe = @utf8.decode_lossy(
      @yue.ffi_assoc_query(@yue.utf8_bytes(mime), 0, ok),
    )
    if ok.val != 1 || exe == "" {
      return Err(NoDefault(mime))
    }
    return Ok(exe)
  }
  if da_supported() {
    match pr_run("xdg-mime", ["query", "default", mime]) {
      Ok(out) => {
        let name = out.stdout.trim().to_owned()
        if out.exit_code == 0 && name.has_suffix(".desktop") {
          return Ok(name)
        }
      }
      Err(_) => ()
    }
  }
  // 回退:mimeapps.list(同名多行按规范后写覆盖,取最后一个候选)
  let mut candidate : String? = None
  for file in da_mimeapps_files() {
    match @yue.read_text_file(file) {
      Some(content) => {
        let sections = da_parse_mimeapps(content)
        for v in da_section_values(sections, "Default Applications", mime) {
          let all = appfind_split_semi(v)
          if all.length() > 0 {
            candidate = Some(all[0])
          }
        }
      }
      None => ()
    }
  }
  match candidate {
    Some(name) => Ok(name)
    None => Err(NoDefault(mime))
  }
}

///|
/// 列出类型的全部关联应用：Linux 扫描三处 mimeapps.list（默认应用排
/// 最前，去重）；Windows 无关联应用枚举接口，恒空列表。
pub fn da_associations_for(mime : String) -> Array[String] {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    return [] // Windows/macOS 均无关联应用枚举接口
  }
  let texts : Array[String] = []
  for file in da_mimeapps_files() {
    match @yue.read_text_file(file) {
      Some(content) =>
        if content != "" {
          texts.push(content)
        }
      None => ()
    }
  }
  da_associations_of_texts(texts, mime)
}

///|
/// 设置默认应用（设置类，由调用方决定何时执行）：Linux 把 mime=
/// desktop_id 写入用户 mimeapps.list 的 [Default Applications] 段（已有
/// 该 mime 行则替换，否则段内追加/新建段）；Windows 的用户级默认应用
/// 注册走 IApplicationAssociationRegistration（需 UI 授权流程），本包
/// 未实现，返回 Unsupported。
pub fn da_set_default(mime : String, desktop_id : String) -> Result[Unit, DefaultAppError] {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    return Err(Unsupported) // 用户级默认应用注册需 UI 授权流程，未实现
  }
  if !desktop_id.has_suffix(".desktop") {
    return Err(QueryFailed("desktop_id 必须是 .desktop 文件名: \{desktop_id}"))
  }
  let file = match getenv_str("XDG_CONFIG_HOME") {
    Some(dir) => dir + "/mimeapps.list"
    None =>
      match getenv_str("HOME") {
        Some(home) => home + "/.config/mimeapps.list"
        None => return Err(IoFailed("缺少 HOME/XDG_CONFIG_HOME,无法定位 mimeapps.list"))
      }
  }
  let existing = match @yue.read_text_file(file) {
    Some(c) => c
    None => ""
  }
  let merged = da_merge_default_line(existing, mime, desktop_id)
  if !@yue.write_text_file(file, merged) {
    Err(IoFailed("写入失败: \{file}"))
  } else {
    Ok(())
  }
}
