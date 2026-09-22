// 开机自启动：统一语义 is_supported / is_enabled / enable / disable。
// Linux 写 XDG 自启动目录的 .desktop（拼装纯 MoonBit，读写复用
// read/write_text_file）；Windows 写 HKCU Run 键（shim 注册表 ABI）；
// macOS 显式 Unsupported。
//
// 典型用法：
//   let a = @yue.Autostart::new("com.example.app")
//   a.enable()   // 写盘/注册表，重新登录后拉起
//   a.disable()  // 移除

///|
/// 自启动目录：XDG_CONFIG_HOME（设且非空）优先，回退 $HOME/.config。
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
/// .desktop 的 Exec 值：按桌面项规范整体双引号包裹，引号内 \ 与 " 做
/// 反斜杠转义、% 写成 %%（字段码转义）；空格/$/中文等保留字符在引号内
/// 原样合法（systemd 的 xdg-autostart 生成器也按此解析）。
fn escape_exec(path : String) -> String {
  let sb = StringBuilder()
  sb.write_char('"')
  let mut i = 0
  while i < path.length() {
    let c = path.unsafe_get(i).to_int()
    if c == 92 || c == 34 { // '\\' '"':反斜杠转义
      sb.write_char('\\')
      sb.write_char(c.unsafe_to_char())
    } else if c == 37 { // '%':字段码翻倍
      sb.write_string("%%")
    } else {
      sb.write_char(c.unsafe_to_char())
    }
    i += 1
  }
  sb.write_char('"')
  sb.to_string()
}

///|
/// 自启动 .desktop 内容（Hidden / X-GNOME-Autostart-enabled 是系统侧
/// 禁用开关位，解析时据此判未启用）。
fn desktop_entry_content(exe_path : String, app_id : String) -> String {
  "[Desktop Entry]\nType=Application\nName=\{app_id}\nExec=\{escape_exec(exe_path)}\nHidden=false\nX-GNOME-Autostart-enabled=true\n"
}

///|
/// 解析 .desktop 判启用：文件存在且 Hidden 非 true 且
/// X-GNOME-Autostart-enabled 非 false。
fn desktop_entry_enabled(content : String) -> Bool {
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
/// 开机自启动句柄：app_id 同时是 .desktop 文件名与 Windows Run 键值名
/// （DBus 知名名字符集保证两者都安全）。
pub struct Autostart {
  app_id : String
}

///|
/// 创建自启动句柄。app_id 走 DBus 知名名校验（≥2 点分元素、元素以
/// 字母/下划线开头）。
pub fn Autostart::new(app_id : String) -> Result[Autostart, AutostartError] {
  if !@traybus.valid_app_id(app_id) {
    return Err(InvalidAppId)
  }
  Ok({ app_id, })
}

///|
/// 当前平台是否支持开机自启动（macOS 暂缓）。
pub fn Autostart::is_supported() -> Bool {
  match platform() {
    "linux" | "windows" => true
    _ => false
  }
}

///|
/// 自启动条目的位置：Linux 为 .desktop 完整路径；Windows 为 Run 键值
/// 描述。排查用。
pub fn Autostart::path(self : Autostart) -> Result[String, AutostartError] {
  match platform() {
    "linux" => self.linux_file()
    "windows" =>
      Ok("HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\" + self.app_id)
    _ => Err(Unsupported)
  }
}

///|
/// 查询是否已启用。
pub fn Autostart::is_enabled(self : Autostart) -> Result[Bool, AutostartError] {
  match platform() {
    "linux" => {
      let file = match self.linux_file() {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      match read_text_file(file) {
        Some(content) => Ok(desktop_entry_enabled(content))
        // 文件不存在 = 未启用（目录存在性由 enable 时的写失败兜底报错）
        None => Ok(false)
      }
    }
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_autostart_get(utf8_bytes(self.app_id), ok)
      if ok.val == 1 {
        Ok(true)
      } else if ok.val == 0 {
        Ok(false)
      } else {
        Err(IoFailed("读注册表 Run 键失败"))
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// 启用：Linux 写 .desktop；Windows 写 Run 键（值自动引号包裹，重登录
/// /重启后拉起）。幂等：重复 enable 覆盖旧值。
pub fn Autostart::enable(self : Autostart) -> Result[Unit, AutostartError] {
  let exe = match exe_path() {
    Some(p) => p
    None => return Err(NoExecutablePath)
  }
  match platform() {
    "linux" => {
      let file = match self.linux_file() {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      if !write_text_file(file, desktop_entry_content(exe, self.app_id)) {
        return Err(IoFailed("写入失败: " + file + " (目录不存在或无权限)"))
      }
      Ok(())
    }
    "windows" => {
      let ok = Ref(0)
      let rc = ffi_autostart_set(utf8_bytes(self.app_id), utf8_bytes(exe), ok)
      if rc == 0 && ok.val == 1 {
        Ok(())
      } else if rc == -1000 {
        Err(Unsupported)
      } else {
        Err(IoFailed("写注册表 Run 键失败"))
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// 禁用：删除 .desktop / 删除 Run 键值。幂等：目标本就不在也是成功。
pub fn Autostart::disable(self : Autostart) -> Result[Unit, AutostartError] {
  match platform() {
    "linux" => {
      let file = match self.linux_file() {
        Ok(f) => f
        Err(e) => return Err(e)
      }
      let ok = Ref(0)
      let _ = ffi_remove_file(utf8_bytes(file), ok)
      if ok.val == 1 {
        Ok(())
      } else {
        Err(IoFailed("删除失败: " + file))
      }
    }
    "windows" => {
      let ok = Ref(0)
      let rc = ffi_autostart_remove(utf8_bytes(self.app_id), ok)
      if rc == 0 && ok.val == 1 {
        Ok(())
      } else if rc == -1000 {
        Err(Unsupported)
      } else {
        Err(IoFailed("删注册表 Run 键值失败"))
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// Linux 侧 .desktop 完整路径（目录解析失败给结构化错误）。
fn Autostart::linux_file(self : Autostart) -> Result[String, AutostartError] {
  let dir = match autostart_dir_of(getenv_str("XDG_CONFIG_HOME"), getenv_str("HOME")) {
    Some(d) => d
    None =>
      return Err(IoFailed("无法定位自启动目录(XDG_CONFIG_HOME / HOME 均未设置)"))
  }
  Ok(dir + "/" + self.app_id + ".desktop")
}

///|
fn exe_path() -> String? {
  let ok = Ref(0)
  let data = ffi_exe_path(ok)
  if ok.val == 1 && data.length() > 0 {
    Some(from_utf8_bytes(data))
  } else {
    None
  }
}

///|
fn getenv_str(name : String) -> String? {
  let ok = Ref(0)
  let data = ffi_getenv_bytes(utf8_bytes(name), ok)
  if ok.val == 1 && data.length() > 0 {
    Some(from_utf8_bytes(data))
  } else {
    None
  }
}
