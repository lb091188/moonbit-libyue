// 开机自启动（W21d）：统一语义 is_supported / is_enabled / enable / disable 的
// 跨平台门面，自由函数形态（无对象、无单例）。
//
// **面在 MoonBit**：Linux（及各 XDG 桌面）拼 `$XDG_CONFIG_HOME/autostart`
// 下的 `.desktop` 并写盘——纯字符串 + 既有的文本文件读写入口（`fsx.mbt`），
// 不需要任何平台接口。**只有 Windows 的注册表写入需要 C**（HKCU 的 Run 键，
// 见 `sys_stub.c` 的自启动节）。macOS 本批显式 `Unsupported`（要走
// LaunchAgents plist，留待真机）。
//
// 典型用法：
//   match autostart_enable("com.example.MyApp") {
//     Ok(_) => ()            // 重新登录 / 重启即拉起
//     Err(e) => println(e.to_string())
//   }
//   match autostart_is_enabled("com.example.MyApp") { ... }
//   match autostart_disable("com.example.MyApp") { ... } // 幂等
//
// 平台落点：
//   Linux   $XDG_CONFIG_HOME/autostart/<app_id>.desktop（XDG_CONFIG_HOME 未设
//           则回退 $HOME/.config/autostart）
//   Windows HKCU\Software\Microsoft\Windows\CurrentVersion\Run 的 <app_id> 值
//   macOS   本批 Unsupported

///|
/// 自启动操作错误（新栈的结构化错误口径：不支持与失败分开，不静默）。
pub(all) enum AutostartError {
  /// 本平台未实现（macOS 本批）
  Unsupported
  /// app_id 不合法（点分元素不足 / 元素打头非字母下划线 / 含非法字符 / 超长）
  InvalidAppId
  /// 取不到当前可执行文件路径（平台入口失败）
  NoExecutablePath
  /// 写盘 / 写注册表 / 建目录失败，带说明
  IoFailed(String)
}

///|
pub impl Show for AutostartError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("AutostartError::Unsupported")
    InvalidAppId => logger.write_string("AutostartError::InvalidAppId")
    NoExecutablePath => logger.write_string("AutostartError::NoExecutablePath")
    IoFailed(m) => logger.write_string("AutostartError::IoFailed(\{m})")
  }
}

///|
pub extend AutostartError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数（无后端也可单测）
// ---------------------------------------------------------------------------

///|
/// 自启动目录：`XDG_CONFIG_HOME`（设且非空）优先，回退 `$HOME/.config`；
/// 两者都不可用给 None。
pub fn autostart_dir_of(
  xdg_config_home : String?,
  home : String?,
) -> String? {
  match xdg_config_home {
    Some(d) if d != "" => Some(d + "/autostart")
    _ =>
      match home {
        Some(h) if h != "" => Some(h + "/.config/autostart")
        _ => None
      }
  }
}

///|
/// `.desktop` 的 Exec 值：按桌面项规范整体双引号包裹，引号内 `\` 与 `"` 做
/// 反斜杠转义、`%` 写成 `%%`（字段码转义）；空格 / `$` / 中文等保留字符在
/// 引号内原样合法。
pub fn autostart_escape_exec(path : String) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  for ch in path {
    if ch == '\\' || ch == '"' {
      sb.write_char('\\')
      sb.write_char(ch)
    } else if ch == '%' {
      sb.write_string("%%")
    } else {
      sb.write_char(ch)
    }
  }
  sb.write_char('"')
  sb.to_string()
}

///|
/// 自启动 `.desktop` 内容（`Hidden` / `X-GNOME-Autostart-enabled` 是系统侧
/// 的禁用开关位，解析时据此判未启用）。
pub fn autostart_desktop_entry(exe_path : String, app_id : String) -> String {
  "[Desktop Entry]\nType=Application\nName=\{app_id}\nExec=\{autostart_escape_exec(exe_path)}\nHidden=false\nX-GNOME-Autostart-enabled=true\n"
}

///|
/// 解析 `.desktop` 判启用：文件存在且 `Hidden` 非 `true` 且
/// `X-GNOME-Autostart-enabled` 非 `false`。
pub fn autostart_desktop_enabled(content : String) -> Bool {
  let mut hidden = false
  let mut enabled = true
  for line in content.split("\n") {
    let l = line.to_owned()
    if l.has_prefix("Hidden=") {
      hidden = l == "Hidden=true"
    } else if l.has_prefix("X-GNOME-Autostart-enabled=") {
      enabled = l != "X-GNOME-Autostart-enabled=false"
    }
  }
  !hidden && enabled
}

///|
/// Windows Run 键的值形态：整串双引号包裹（路径含空格而未加引号时，登录
/// 拉起会被截断成第一个词）。C 侧原样写、原样读，不做二次加工。
pub fn autostart_run_value(exe_path : String) -> String {
  "\"" + exe_path + "\""
}

///|
/// 反解 Run 值里的 exe 路径：去一层首尾配对的引号；非引号包裹则原样返回
/// （调用方自己写的裸路径也认）；空串给 None。排查 / 回读用。
pub fn autostart_run_value_exe(value : String) -> String? {
  if value == "" {
    return None
  }
  if value.length() >= 2 && value.unsafe_get(0) == '"' &&
    value.unsafe_get(value.length() - 1) == '"' {
    let inner = value[1:value.length() - 1].to_owned()
    if inner == "" {
      None
    } else {
      Some(inner)
    }
  } else {
    Some(value)
  }
}

///|
/// app_id 合法性：与 DBus 知名名同规则（≥2 个点分元素；每元素以字母或下划线
/// 开头，只含 `[A-Za-z0-9_-]`；总长 ≤255）。**同一规则的本地实现**——`sys`
/// 不反向依赖 `dbus`，而 app_id 同时要当 `.desktop` 文件名与 Windows 的
/// Run 值名，两处都要求这个字符集安全。
pub fn autostart_valid_app_id(app_id : String) -> Bool {
  if app_id.length() == 0 || app_id.length() > 255 {
    return false
  }
  let mut dots = 0
  let mut elem_start = true
  for ch in app_id {
    if ch == '.' {
      if elem_start {
        return false // 空前元素（打头 / 连续 / 收尾的点）
      }
      dots = dots + 1
      elem_start = true
    } else {
      let body_ok = (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') ||
        ch == '_' || ch == '-'
      if !body_ok {
        return false
      }
      if elem_start {
        let head_ok = (ch >= 'a' && ch <= 'z') ||
          (ch >= 'A' && ch <= 'Z') || ch == '_'
        if !head_ok {
          return false // 元素不能以数字或 '-' 开头
        }
        elem_start = false
      }
    }
  }
  dots >= 1 && !elem_start
}

// ---------------------------------------------------------------------------
// 平台后端（C 桩：sys_stub.c 的自启动节）
// ---------------------------------------------------------------------------

///|
#borrow(ok)
extern "c" fn ffi_sys_exe_path(ok : Ref[Int]) -> Bytes = "yue_sys_exe_path"

///|
#borrow(app_id, ok)
extern "c" fn ffi_sys_autostart_get(app_id : Bytes, ok : Ref[Int]) -> Bytes = "yue_sys_autostart_get"

///|
#borrow(app_id, value, ok)
extern "c" fn ffi_sys_autostart_set(
  app_id : Bytes,
  value : Bytes,
  ok : Ref[Int],
) -> Int = "yue_sys_autostart_set"

///|
#borrow(app_id, ok)
extern "c" fn ffi_sys_autostart_remove(app_id : Bytes, ok : Ref[Int]) -> Int = "yue_sys_autostart_remove"

///|
/// 当前进程可执行文件全路径；取不到给 None。
pub fn autostart_exe_path() -> String? {
  let ok = Ref(0)
  let data = ffi_sys_exe_path(ok)
  if ok.val == 1 && data.length() > 0 {
    Some(@utf8.decode_lossy(data))
  } else {
    None
  }
}

///|
/// 读 Windows Run 键值（原样串，含引号）；不存在给 None，读失败给
/// `Err(IoFailed)`。非 Windows 平台不调用本入口（面在 MoonBit 侧）。
fn autostart_win_read(app_id : String) -> Result[String?, AutostartError] {
  let ok = Ref(0)
  let data = ffi_sys_autostart_get(@utf8.encode(app_id), ok)
  if ok.val == 1 {
    Ok(Some(@utf8.decode_lossy(data)))
  } else if ok.val == 0 {
    Ok(None)
  } else {
    Err(IoFailed("读注册表 Run 键失败"))
  }
}

///|
/// 写 Windows Run 键值（覆盖写，幂等）。
fn autostart_win_write(
  app_id : String,
  value : String,
) -> Result[Unit, AutostartError] {
  let ok = Ref(0)
  let rc = ffi_sys_autostart_set(@utf8.encode(app_id), @utf8.encode(value), ok)
  if rc == 0 && ok.val == 1 {
    Ok(())
  } else if rc == -1000 {
    Err(Unsupported)
  } else {
    Err(IoFailed("写注册表 Run 键失败"))
  }
}

///|
/// 删 Windows Run 键值（幂等：本就不在也算成功）。
fn autostart_win_remove(app_id : String) -> Result[Unit, AutostartError] {
  let ok = Ref(0)
  let rc = ffi_sys_autostart_remove(@utf8.encode(app_id), ok)
  if rc == 0 && ok.val == 1 {
    Ok(())
  } else if rc == -1000 {
    Err(Unsupported)
  } else {
    Err(IoFailed("删注册表 Run 键值失败"))
  }
}

// ---------------------------------------------------------------------------
// 公开 API（运行时平台分派，无编译期条件）
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// macOS：LaunchAgents 的 plist（与 Linux 同一形态——面在 MoonBit，落点是一个
// 文本文件，不需要 C）。启用/停用另要过一次 `launchctl`：这里用 `load` /
// `unload` 这对**已废弃但仍在**的动词，因为新写法 `bootstrap gui/<uid>` 要
// 用户的 uid，而本包没有暴露取 uid 的口子（取 uid 属另一族，不为这一条引入）。
// ---------------------------------------------------------------------------

fn autostart_mac_xml_escape(v : String) -> String {
  let buf = StringBuilder()
  for ch in v {
    match ch {
      '&' => buf.write_string("&amp;")
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      _ => buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
/// LaunchAgents 目录（HOME 未设为 None）；条目文件是它下面的 `<app_id>.plist`。
fn autostart_mac_dir() -> String? {
  match sys_getenv("HOME") {
    Some(h) if h != "" => Some(h + "/Library/LaunchAgents")
    _ => None
  }
}

///|
/// plist 正文：Label + ProgramArguments(单条可执行文件) + RunAtLoad。
/// 与 Linux 侧的 `autostart_desktop_entry` 同位（纯函数、可直接钉测试）。
pub fn autostart_mac_plist(app_id : String, exe : String) -> String {
  let a = autostart_mac_xml_escape(app_id)
  let e = autostart_mac_xml_escape(exe)
  let lines : Array[String] = [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
    "<plist version=\"1.0\">",
    "<dict>",
    "  <key>Label</key>",
    "  <string>" + a + "</string>",
    "  <key>ProgramArguments</key>",
    "  <array>",
    "    <string>" + e + "</string>",
    "  </array>",
    "  <key>RunAtLoad</key>",
    "  <true/>",
    "</dict>",
    "</plist>",
  ]
  let buf = StringBuilder()
  for l in lines {
    buf.write_string(l)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// 跑一条 launchctl（命令不存在/非零退出都算失败，交调用方归成语义化 Err）。
fn autostart_mac_launchctl(verb : String, file : String) -> Bool {
  match pr_run("launchctl", [verb, file], timeout_ms=8000) {
    Ok(o) => o.exit_code == 0
    _ => false
  }
}

///|
/// 当前平台是否支持开机自启动（三平台都有公开落点：Linux `.desktop`、
/// Windows Run 键、macOS LaunchAgents plist）。
pub fn autostart_supported() -> Bool {
  match sys_platform() {
    "linux" | "windows" | "macos" => true
    _ => false
  }
}

///|
/// 自启动条目的落点（排查用）：Linux 为 `.desktop` 完整路径；Windows 为
/// Run 键值描述；其余 Unsupported。**不校验 app_id**（纯定位）。
pub fn autostart_path(app_id : String) -> Result[String, AutostartError] {
  match sys_platform() {
    "linux" => {
      let dir = match
        autostart_dir_of(sys_getenv("XDG_CONFIG_HOME"), sys_getenv("HOME")) {
        Some(d) => d
        None =>
          return Err(
            IoFailed("无法定位自启动目录(XDG_CONFIG_HOME / HOME 均未设置)"),
          )
      }
      Ok(dir + "/" + app_id + ".desktop")
    }
    "windows" =>
      Ok(
        "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\" + app_id,
      )
    "macos" =>
      match autostart_mac_dir() {
        Some(dir) => Ok(dir + "/" + app_id + ".plist")
        None => Err(IoFailed("无法定位自启动目录(HOME 未设置)"))
      }
    _ => Err(Unsupported)
  }
}

///|
/// 查询是否已启用。Linux：`.desktop` 在且未被 Hidden / X-GNOME 关掉；
/// Windows：Run 值存在即为启用。
pub fn autostart_is_enabled(app_id : String) -> Result[Bool, AutostartError] {
  if !autostart_valid_app_id(app_id) {
    return Err(InvalidAppId)
  }
  match sys_platform() {
    "linux" => {
      let file = match autostart_path(app_id) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      match sys_read_text_file(file) {
        Some(content) => Ok(autostart_desktop_enabled(content))
        // 文件不存在 = 未启用（目录是否存在由 enable 的写失败兜底报错）
        None => Ok(false)
      }
    }
    "macos" => {
      let file = match autostart_path(app_id) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      Ok(sys_read_text_file(file) is Some(_))
    }
    "windows" =>
      match autostart_win_read(app_id) {
        Ok(Some(_)) => Ok(true)
        Ok(None) => Ok(false)
        Err(e) => Err(e)
      }
    _ => Err(Unsupported)
  }
}

///|
/// 启用：Linux 建目录 + 写 `.desktop`；Windows 写 Run 键（值由
/// `autostart_run_value` 拼成带引号形态）。幂等：重复 enable 覆盖旧条目。
pub fn autostart_enable(app_id : String) -> Result[Unit, AutostartError] {
  if !autostart_valid_app_id(app_id) {
    return Err(InvalidAppId)
  }
  let exe = match autostart_exe_path() {
    Some(p) => p
    None => return Err(NoExecutablePath)
  }
  match sys_platform() {
    "linux" => {
      let file = match autostart_path(app_id) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      // 写文件不会顺手建父目录——先建目录（已存在也算成功）
      match autostart_dir_of(
        sys_getenv("XDG_CONFIG_HOME"),
        sys_getenv("HOME"),
      ) {
        Some(dir) =>
          if !sys_make_dirs(dir) {
            return Err(
              IoFailed("无法创建自启动目录(目录不可写或无 mkdir 通道): " + dir),
            )
          }
        None => ()
      }
      if !sys_write_text_file(file, autostart_desktop_entry(exe, app_id)) {
        return Err(
          IoFailed("写入失败: " + file + " (目录不存在或无权限)"),
        )
      }
      Ok(())
    }
    "windows" => autostart_win_write(app_id, autostart_run_value(exe))
    "macos" => {
      let file = match autostart_path(app_id) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      let dir = match autostart_mac_dir() {
        Some(d) => d
        None => return Err(IoFailed("无法定位自启动目录(HOME 未设置)"))
      }
      if !sys_make_dirs(dir) {
        return Err(IoFailed("无法创建自启动目录(目录不可写或无权限): " + dir))
      }
      if !sys_write_text_file(file, autostart_mac_plist(app_id, exe)) {
        return Err(IoFailed("写入失败: " + file + " (目录不存在或无权限)"))
      }
      // 交给 launchd：load 失败不撤销文件（下次登录仍会生效），但如实报失败
      if !autostart_mac_launchctl("load", file) {
        return Err(IoFailed("launchctl load 失败: " + file))
      }
      Ok(())
    }
    _ => Err(Unsupported)
  }
}

///|
/// 禁用：Linux 删 `.desktop`；Windows 删 Run 键值。幂等：目标本就不在也是
/// 成功。
pub fn autostart_disable(app_id : String) -> Result[Unit, AutostartError] {
  if !autostart_valid_app_id(app_id) {
    return Err(InvalidAppId)
  }
  match sys_platform() {
    "linux" => {
      let file = match autostart_path(app_id) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      if sys_remove_file(file) {
        Ok(())
      } else {
        Err(IoFailed("删除失败: " + file))
      }
    }
    "windows" => autostart_win_remove(app_id)
    "macos" => {
      let file = match autostart_path(app_id) {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      // 先 unload（没装载过也算成功，与「幂等删除」同档），再删 plist
      let _ = autostart_mac_launchctl("unload", file)
      if sys_remove_file(file) {
        Ok(())
      } else {
        Err(IoFailed("删除失败: " + file))
      }
    }
    _ => Err(Unsupported)
  }
}
