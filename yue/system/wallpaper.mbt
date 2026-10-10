// 当前桌面壁纸：按平台分派读取/设置路径。
//   Windows: SystemParametersInfo（SPI_GET/SETDESKWALLPAPER）直连
//   XFCE   : xfconf-query 读写 xfce4-desktop 频道的
//            /backdrop/<screen>/monitor<输出>/<workspace>/last-image 属性
//   GNOME  : gsettings 读写 org.gnome.desktop.background 的 picture-uri
//   KDE    : qdbus6/qdbus 调 plasmashell 的 evaluateScript（Plasma 脚本
//            约定，本仓库未在 KDE 真机验证）
// 其余桌面环境返回语义化 Err(UnknownDesktop)。DE 识别复用
// @traybus.detect_desktop()（XDG_CURRENT_DESKTOP）。目录/路径解析与
// 命令参数构造为纯函数，wallpaper_wbtest.mbt 白盒覆盖。

///|
pub(all) enum WallpaperError {
  /// 当前平台/工具不支持（非 Linux、子进程不可用、KDE 的 qdbus 不在）
  Unsupported
  /// 不认识的桌面环境（非 XFCE/GNOME/KDE），带 XDG_CURRENT_DESKTOP 原文
  UnknownDesktop(String)
  /// 命令执行失败（启动失败 / 非零退出码 / 超时 / 被信号终止），带原因
  CommandFailed(String)
  /// 工具输出解析失败或取值非法，带原文/说明
  ParseFailed(String)
  /// 调用参数非法（如壁纸路径为空）
  InvalidParam(String)
}

///|
pub impl Show for WallpaperError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("WallpaperError::Unsupported")
    UnknownDesktop(d) =>
      logger.write_string("WallpaperError::UnknownDesktop(\{d})")
    CommandFailed(m) =>
      logger.write_string("WallpaperError::CommandFailed(\{m})")
    ParseFailed(m) => logger.write_string("WallpaperError::ParseFailed(\{m})")
    InvalidParam(m) => logger.write_string("WallpaperError::InvalidParam(\{m})")
  }
}

///|
pub extend WallpaperError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层：文本工具 / 输出解析 / 命令参数构造（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 字符是否空白（空格 / 制表 / 换行 / 回车）。
fn wp_is_ws(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// 按换行切分文本（丢弃行尾回车，空行不保留）。
fn wp_split_lines(s : String) -> Array[String] {
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
fn wp_trim(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  let mut i = 0
  let mut j = n - 1
  while i < n && wp_is_ws(chars[i]) {
    i = i + 1
  }
  while j >= i && wp_is_ws(chars[j]) {
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
/// 剥掉指定前缀（不匹配为 None）。
fn wp_strip_prefix(s : String, prefix : String) -> String? {
  if !s.has_prefix(prefix) {
    return None
  }
  let buf = StringBuilder()
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = prefix.length()
  let mut i = n
  while i < chars.length() {
    buf.write_char(chars[i])
    i = i + 1
  }
  Some(buf.to_string())
}

///|
/// 解析 gsettings get 输出：
/// "'file:///usr/share/a.png'" → Some("/usr/share/a.png")；空串
/// （"''"，即未设置）为 None；不做百分号解码。
fn wp_parse_gsettings_uri(out : String) -> String? {
  let text = wp_trim(out)
  if text.length() >= 2 && text.has_prefix("'") {
    // 去掉首尾单引号（gsettings 字符串以单引号包裹）
    let inner = wp_unquote(text)
    if inner == "" {
      return None
    }
    match wp_strip_prefix(inner, "file://") {
      Some(p) => if p == "" { None } else { Some(p) }
      None => Some(inner) // 非 file:// 的裸路径也接受
    }
  } else if text == "" {
    None
  } else {
    Some(text)
  }
}

///|
/// 去掉首尾单引号（长度 < 2 或首尾不是引号则原样返回）。
fn wp_unquote(s : String) -> String {
  let chars : Array[Char] = []
  for ch in s {
    chars.push(ch)
  }
  let n = chars.length()
  if n < 2 || chars[0] != '\'' || chars[n - 1] != '\'' {
    return s
  }
  let buf = StringBuilder()
  let mut i = 1
  while i <= n - 2 {
    buf.write_char(chars[i])
    i = i + 1
  }
  buf.to_string()
}

///|
/// xfce4-desktop 属性行是否 /backdrop/.../last-image 壁纸属性。
fn wp_is_last_image_prop(line : String) -> Bool {
  let text = wp_trim(line)
  text.has_prefix("/backdrop/") && text.has_suffix("/last-image")
}

///|
/// xfce4-desktop backdrop 壁纸属性解析结果：监控输出名（去掉
/// "monitor" 前缀，"None-1" 为未单独配置输出的兜底项）与工作区序号。
priv struct WpBackdropProp {
  monitor : String
  workspace : Int
}

///|
/// 解析 "/backdrop/screen0/monitorHDMI-0/workspace3/last-image" →
/// { monitor: "HDMI-0", workspace: 3 }；形态不符为 None。
fn wp_parse_backdrop_prop(prop : String) -> WpBackdropProp? {
  let text = wp_trim(prop)
  if !text.has_prefix("/backdrop/") || !text.has_suffix("/last-image") {
    return None
  }
  let parts : Array[String] = []
  let mut cur = StringBuilder()
  for ch in text {
    if ch == '/' {
      parts.push(cur.to_string())
      cur = StringBuilder()
    } else {
      cur.write_char(ch)
    }
  }
  parts.push(cur.to_string())
  // ["", "backdrop", "screenN", "monitorXXX", "workspaceM", "last-image"]
  if parts.length() != 6 {
    return None
  }
  let mon = parts[3]
  match wp_strip_prefix(mon, "monitor") {
    None => return None
    Some(name) => {
      if name == "" {
        return None
      }
      let ws = parts[4]
      match wp_parse_uint(ws, "workspace") {
        None => return None
        Some(w) => Some({ monitor: name, workspace: w, })
      }
    }
  }
}

///|
/// 解析 "<前缀><无符号十进制>" 形态文本（"workspace0" 带 "workspace" →
/// Some(0)；无前缀或含非数字为 None）。
fn wp_parse_uint(s : String, prefix : String) -> Int? {
  match wp_strip_prefix(s, prefix) {
    None => None
    Some(rest) => {
      if rest == "" {
        return None
      }
      let mut v = 0
      for ch in rest {
        if ch < '0' || ch > '9' {
          return None
        }
        v = v * 10 + (ch.to_int() - 48)
      }
      Some(v)
    }
  }
}

///|
/// 从 xfconf 属性行中选要读/写的壁纸属性：优先「workspace0 且输出已
/// 连接」（排除拔掉显示器留下的陈旧项），否则首个 workspace0 项，
/// 否则首个可解析项；无候选为 None。
fn wp_select_last_image_prop(
  props : Array[String],
  connected : Array[String],
) -> String? {
  for prop in props {
    match wp_parse_backdrop_prop(prop) {
      Some(parsed) =>
        if parsed.workspace == 0 && connected.contains(parsed.monitor) {
          return Some(prop)
        }
      None => ()
    }
  }
  for prop in props {
    match wp_parse_backdrop_prop(prop) {
      Some(parsed) => if parsed.workspace == 0 { return Some(prop) }
      None => ()
    }
  }
  for prop in props {
    match wp_parse_backdrop_prop(prop) {
      Some(_) => return Some(prop)
      None => ()
    }
  }
  None
}

///|
/// xfconf-query 写壁纸参数表（属性不存在则创建）。
fn wp_xfce_set_args(prop : String, path : String) -> Array[String] {
  ["-c", "xfce4-desktop", "-p", prop, "-n", "-t", "string", "-s", path]
}

///|
/// gsettings 写 GNOME 壁纸参数表（KEY 为 picture-uri 等，值以 file://
/// URI 形式写入）。
fn wp_gnome_set_args(key : String, path : String) -> Array[String] {
  ["set", "org.gnome.desktop.background", key, "file://\{path}"]
}

///|
/// JS 单引号字符串字面量转义（单引号前置反斜杠）。
fn wp_escape_js_squote(s : String) -> String {
  let buf = StringBuilder()
  for ch in s {
    if ch == '\'' {
      buf.write_char('\\')
    }
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
/// KDE 读壁纸的 evaluateScript JS：对所有桌面打印 org.kde.image 插件的
/// Image 配置（只打印图片路径，便于按行解析）。
fn wp_kde_read_script() -> String {
  "var all = desktops();\n" +
  "for (var i = 0; i < all.length; i++) {\n" +
  "  var g = all[i].currentConfigGroup;\n" +
  "  var img = readConfig(g, 'Image');\n" +
  "  if (img && img.length > 0) { print(img); }\n" +
  "}"
}

///|
/// KDE 写壁纸的 evaluateScript JS：把首个桌面切到 org.kde.image 插件
/// 并写 Image（file:// URI）。
fn wp_kde_write_script(path : String) -> String {
  "var d = desktops()[0];\n" +
  "d.wallpaperPlugin = 'org.kde.image';\n" +
  "d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];\n" +
  "d.writeConfig('Image', 'file://\{wp_escape_js_squote(path)}');"
}

// ---------------------------------------------------------------------------
// 子进程执行封装（复用 [pr_run]，非零退出还原为 (退出码, stdout) 供分流）
// ---------------------------------------------------------------------------

///|
/// 运行命令并捕获标准输出：底层走 [pr_run]，非零退出还原为
/// (退出码, 空 stdout) 正常返回，其余错误映射为 WallpaperError。
fn wp_run_capture(
  prog : String,
  args : Array[String],
  timeout_ms? : Int = 5000,
) -> Result[(Int, String), WallpaperError] {
  match pr_run(prog, args, timeout_ms~) {
    Ok(o) => Ok((o.exit_code, o.stdout))
    Err(NonZeroExit(code, _)) => Ok((code, ""))
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) => Err(CommandFailed("\{prog}: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(Unsupported)
  }
}

///|
/// 已连接输出名列表（读 xrandr 解析；xrandr 不可用时为空表，退化为
/// 「按属性表首个 workspace0 项」选择）。
fn wp_connected_outputs() -> Array[String] {
  match mon_list() {
    Err(_) => []
    Ok(infos) => {
      let names : Array[String] = []
      for info in infos {
        if info.connected {
          names.push(info.name)
        }
      }
      names
    }
  }
}

///|
/// KDE 的 qdbus 程序名：qdbus6（Plasma 6）优先，回退 qdbus（Plasma 5）；
/// --version 退出 0 即存在。
fn wp_kde_prog() -> String? {
  if !pr_available() {
    return None
  }
  for prog in ["qdbus6", "qdbus"] {
    match pr_run(prog, ["--version"], timeout_ms=2000) {
      Ok(_) => return Some(prog)
      Err(_) => ()
    }
  }
  None
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 读当前壁纸路径（按 DE 分派）。XFCE 取 workspace0 的 last-image 属性
/// （存在多个显示器时优先已连接输出）；GNOME 取 picture-uri，未设置时
/// 回退 picture-uri-dark；KDE 走 plasmashell evaluateScript。不认识的
/// DE / 工具缺失为语义化 Err。
pub fn wp_get() -> Result[String, WallpaperError] {
  if @yue.platform() == "windows" {
    let ok = Ref(0)
    let path = wp_trim(@utf8.decode_lossy(@yue.ffi_wallpaper_get(ok)))
    if ok.val != 1 {
      return Err(CommandFailed("SystemParametersInfo(SPI_GETDESKWALLPAPER)"))
    }
    if path == "" {
      return Err(ParseFailed("壁纸未设置"))
    }
    return Ok(path)
  }
  if !pr_available() {
    return Err(Unsupported)
  }
  match @traybus.detect_desktop() {
    Xfce => wp_get_xfce()
    Gnome => wp_get_gnome()
    Kde => wp_get_kde()
    _ => Err(UnknownDesktop(@traybus.desktop_name()))
  }
}

///|
/// 设置当前壁纸（按 DE 分派）。XFCE 写 workspace0 对应输出的 last-image
/// 属性（不存在则创建）；GNOME 写 picture-uri；KDE 走 plasmashell
/// evaluateScript。仅在明确知道环境后才可调用，会改变桌面外观。
pub fn wp_set(path : String) -> Result[Unit, WallpaperError] {
  if wp_trim(path) == "" {
    return Err(InvalidParam("壁纸路径为空"))
  }
  if @yue.platform() == "windows" {
    let ok = Ref(0)
    let _ = @yue.ffi_wallpaper_set(@yue.utf8_bytes(path), ok)
    if ok.val != 1 {
      return Err(
        CommandFailed("SystemParametersInfo(SPI_SETDESKWALLPAPER) 失败"),
      )
    }
    return Ok(())
  }
  if !pr_available() {
    return Err(Unsupported)
  }
  match @traybus.detect_desktop() {
    Xfce => wp_set_xfce(path)
    Gnome => wp_apply("gsettings", wp_gnome_set_args("picture-uri", path))
    Kde =>
      match wp_kde_prog() {
        None => Err(Unsupported)
        Some(prog) =>
          wp_apply(prog, [
            "org.kde.plasmashell",
            "/PlasmaShell",
            "org.kde.PlasmaShell.evaluateScript",
            wp_kde_write_script(path),
          ])
      }
    _ => Err(UnknownDesktop(@traybus.desktop_name()))
  }
}

// ---------------------------------------------------------------------------
// 分 DE 实现
// ---------------------------------------------------------------------------

///|
/// XFCE 读壁纸：列 xfce4-desktop 频道属性 → 选壁纸属性 → 读属性值。
fn wp_get_xfce() -> Result[String, WallpaperError] {
  match wp_run_capture("xfconf-query", ["-c", "xfce4-desktop", "-l"]) {
    Err(e) => Err(e)
    Ok((code, out)) => {
      if code != 0 {
        return Err(CommandFailed("xfconf-query -l: 退出码 \{code}"))
      }
      let candidates : Array[String] = []
      for line in wp_split_lines(out) {
        if wp_is_last_image_prop(line) {
          candidates.push(wp_trim(line))
        }
      }
      match wp_select_last_image_prop(candidates, wp_connected_outputs()) {
        None =>
          Err(
            ParseFailed(
              "xfce4-desktop 频道无 /backdrop/.../last-image 属性",
            ),
          )
        Some(prop) =>
          match
            wp_run_capture("xfconf-query", ["-c", "xfce4-desktop", "-p", prop]) {
            Err(e) => Err(e)
            Ok((0, value)) => {
              let path = wp_trim(value)
              if path == "" {
                Err(ParseFailed("属性 \{prop} 值为空"))
              } else {
                Ok(path)
              }
            }
            Ok((code2, _)) =>
              Err(CommandFailed("xfconf-query -p: 退出码 \{code2}"))
          }
      }
    }
  }
}

///|
/// XFCE 写壁纸：目标属性同 wp_get 的选择规则；无既有属性时创建
/// monitorNone-1 的 workspace0 兜底项。
fn wp_set_xfce(path : String) -> Result[Unit, WallpaperError] {
  let prop = match
    wp_select_last_image_prop(wp_xfce_props(), wp_connected_outputs()) {
    Some(p) => p
    None => "/backdrop/screen0/monitorNone-1/workspace0/last-image"
  }
  wp_apply("xfconf-query", wp_xfce_set_args(prop, path))
}

///|
/// 列 xfce4-desktop 频道的全部 /backdrop/.../last-image 属性（列不到为
/// 空表）。
fn wp_xfce_props() -> Array[String] {
  match wp_run_capture("xfconf-query", ["-c", "xfce4-desktop", "-l"]) {
    Err(_) => []
    Ok((0, out)) => {
      let props : Array[String] = []
      for line in wp_split_lines(out) {
        if wp_is_last_image_prop(line) {
          props.push(wp_trim(line))
        }
      }
      props
    }
    Ok((_, _)) => []
  }
}

///|
/// GNOME 读壁纸：picture-uri 为主，未设置回退 picture-uri-dark。
fn wp_get_gnome() -> Result[String, WallpaperError] {
  match wp_read_gsettings_key("picture-uri") {
    Err(e) => Err(e)
    Ok(Some(path)) => Ok(path)
    Ok(None) =>
      match wp_read_gsettings_key("picture-uri-dark") {
        Err(e) => Err(e)
        Ok(Some(path)) => Ok(path)
        Ok(None) => Err(ParseFailed("gsettings picture-uri 未设置"))
      }
  }
}

///|
/// 读一个 gsettings 字符串键（解析失败/未设置为 Ok(None)）。
fn wp_read_gsettings_key(key : String) -> Result[String?, WallpaperError] {
  match
    wp_run_capture("gsettings", ["get", "org.gnome.desktop.background", key]) {
    Err(e) => Err(e)
    Ok((code, out)) =>
      if code != 0 {
        Err(CommandFailed("gsettings get \{key}: 退出码 \{code}"))
      } else {
        Ok(wp_parse_gsettings_uri(out))
      }
  }
}

///|
/// KDE 读壁纸：qdbus6/qdbus evaluateScript，输出按行取首个非空行。
fn wp_get_kde() -> Result[String, WallpaperError] {
  match wp_kde_prog() {
    None => Err(Unsupported)
    Some(prog) =>
      match
        wp_apply_with(prog, [
          "org.kde.plasmashell",
          "/PlasmaShell",
          "org.kde.PlasmaShell.evaluateScript",
          wp_kde_read_script(),
        ]) {
        Err(e) => Err(e)
        Ok(out) => {
          for line in wp_split_lines(out) {
            let text = wp_trim(line)
            if text != "" {
              return Ok(text)
            }
          }
          Err(ParseFailed("\{prog} evaluateScript: 无壁纸输出"))
        }
      }
  }
}

///|
/// 执行命令并回显 stdout（0 为成功；其余错误映射为 WallpaperError）。
fn wp_apply_with(
  prog : String,
  args : Array[String],
) -> Result[String, WallpaperError] {
  match pr_run(prog, args, timeout_ms=5000) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(code, err)) =>
      Err(
        CommandFailed("\{prog}: 退出码 \{code}（\{wp_first_line(err)}）"),
      )
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) => Err(CommandFailed("\{prog}: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(Unsupported)
  }
}

///|
/// 执行命令并按退出码归一结果（0 为成功）。
fn wp_apply(
  prog : String,
  args : Array[String],
) -> Result[Unit, WallpaperError] {
  match wp_run_capture(prog, args) {
    Err(e) => Err(e)
    Ok((0, _)) => Ok(())
    Ok((code, _)) => Err(CommandFailed("\{prog}: 退出码 \{code}"))
  }
}

///|
/// 取文本首行（错误消息只取首行，避免刷屏）。
fn wp_first_line(s : String) -> String {
  let buf = StringBuilder()
  for ch in s {
    if ch == '\n' {
      break
    }
    buf.write_char(ch)
  }
  buf.to_string()
}
