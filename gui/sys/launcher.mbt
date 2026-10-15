// 打开外部：URL、文件（默认程序/指定程序）、文件管理器定位，单入口 + 单错误枚举。
// Linux 走 xdg-open（argv 直传不经 shell，分离式启动不阻塞调用方）；Windows 直调
// ShellExecuteW（URL/文件走系统关联，指定程序那条把路径放进 lpParameters）；
// macOS 用 open。运行时探测分派，其余平台给 Unsupported。相对路径一律先按工作
// 目录归一，Windows 侧再把分隔符统一成反斜杠。Ok 只表示「已交给系统」，系统侧
// 能否打开由平台负责——所以交出去之前先判一次路径存在与否，不存在给 NotFound。

///|
/// 打开 URL 的错误类型。
pub(all) enum OpenUrlError {
  /// 平台不支持
  Unsupported
  /// 交给系统的 spawn 失败
  SpawnFailed
}

///|
pub impl Show for OpenUrlError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("OpenUrlError::Unsupported")
    SpawnFailed => logger.write_string("OpenUrlError::SpawnFailed")
  }
}

///|
pub extend OpenUrlError with Show::{to_string, output}

///|
/// 文件管理器定位的错误类型。
pub(all) enum FileManagerError {
  /// 平台不支持
  Unsupported
  /// 路径不存在（不存在时 explorer 只会默默开个别处，给 Err 才诚实）
  NotFound
  /// 回退 spawn 也失败
  SpawnFailed
}

///|
pub impl Show for FileManagerError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("FileManagerError::Unsupported")
    NotFound => logger.write_string("FileManagerError::NotFound")
    SpawnFailed => logger.write_string("FileManagerError::SpawnFailed")
  }
}

///|
pub extend FileManagerError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// FFI（桩：sys_stub.c）
// ---------------------------------------------------------------------------

///|
#borrow(file, arg)
extern "c" fn ffi_sys_spawn_detached(
  file : Bytes,
  arg : Bytes,
) -> Int = "yue_sys_spawn_detached"

///|
#borrow(ok)
extern "c" fn ffi_sys_getcwd(ok : Ref[Int]) -> Bytes = "yue_sys_getcwd"

// ---------------------------------------------------------------------------
// 纯逻辑层（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 路径是否已带「绝对」前缀，三平台三种写法都认：POSIX 的 `/…`、Windows 的
/// `C:\…`/`C:/…`（盘符 + 冒号）、Windows 的 UNC `\\主机\…` 与当前盘根 `\…`。
/// 只看前导 `/` 会把 `C:\a\b.txt` 当成相对路径拼到 cwd 后面，产出
/// `<cwd>/C:\a\b.txt` 这种垃圾串（真机踩过：文件管理器定位与打开都不对）。
pub fn launcher_path_absolute(path : String) -> Bool {
  if path.length() == 0 {
    return false
  }
  let b0 = path.unsafe_get(0).to_int()
  if b0 == 47 || b0 == 92 {
    // '/' 或 '\'
    true
  } else if path.length() > 2 && path.unsafe_get(1).to_int() == 58 {
    // ':'：ASCII 字母打头即盘符
    let c = b0 | 32
    c >= 97 && c <= 122
  } else {
    false
  }
}

///|
/// 相对路径按工作目录归一：已绝对（见 `launcher_path_absolute`）或 cwd 读不到
/// 时原样返回，空串不拼。拼接一律用 `/`——POSIX 原生，Windows 侧要交给
/// 只认反斜杠的消费方（explorer 的 `/select`）时再走 `launcher_win_path`。
pub fn launcher_abs_path(path : String, cwd : String) -> String {
  if path == "" || launcher_path_absolute(path) || cwd == "" {
    path
  } else {
    cwd + "/" + path
  }
}

///|
/// Windows 形态的路径：把 `/` 全换成 `\`。`explorer /select,"…"` 对混合分隔符
/// 的路径**不会选中**（常常只是开一个文件夹，甚至开「文档」），而 cwd 与用户
/// 输入混着给时两种分隔符都会出现，所以在交出去之前统一成反斜杠。
pub fn launcher_win_path(path : String) -> String {
  // 走 Bytes 逐字节替换：中文路径按 Char/UTF-16 位重编码会被写坏
  let src = @utf8.encode(path)
  let buf = FixedArray::make(src.length(), b'\x00')
  let mut changed = false
  for i = 0; i < src.length(); i = i + 1 {
    let c = src[i]
    if c == b'/' {
      buf[i] = b'\\'
      changed = true
    } else {
      buf[i] = c
    }
  }
  if changed { @utf8.decode_lossy(Bytes::from_array(buf)) } else { path }
}

///|
/// 父目录："/a/b/c" → "/a/b"；"/c" → "/"；无斜杠回 "."。
fn parent_dir(path : String) -> String {
  if path.length() == 0 {
    return "."
  }
  let mut i = path.length() - 1
  while i > 0 {
    if path.unsafe_get(i).to_int() == 47 {
      // '/'
      return if i == 0 { "/" } else { path[0:i].to_owned() }
    }
    i -= 1
  }
  if path.unsafe_get(0).to_int() == 47 {
    "/"
  } else {
    "."
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 分离式启动：命令名按 PATH 解析，`arg` 为空串时不传参数；不等待子进程
/// 退出，只回「有没有交出去」（子进程不占本进程句柄、不留僵尸）。
pub fn spawn_detached(file : String, arg : String) -> Result[Unit, String] {
  if file == "" {
    Err("spawn 失败: 命令名为空")
  } else {
    let rc = ffi_sys_spawn_detached(@utf8.encode(file), @utf8.encode(arg))
    if rc == 0 {
      Ok(())
    } else {
      Err("spawn 失败: \{file}")
    }
  }
}

///|
/// 当前工作目录（读不到为空串）。
pub fn current_dir() -> String {
  let ok = Ref(0)
  let v = ffi_sys_getcwd(ok)
  if ok.val == 1 { @utf8.decode_lossy(v) } else { "" }
}

///|
///|
/// Windows 直调：ShellExecuteW「open」打开 URL/文件（>32 成功的约定）。
#borrow(target, ok)
extern "c" fn ffi_shell_open(target : Bytes, ok : Ref[Int]) -> Int = "yue_sys_shell_open"

///|
/// Windows 直调：explorer /select,"path" 在文件管理器里定位。
#borrow(path, ok)
extern "c" fn ffi_shell_reveal(path : Bytes, ok : Ref[Int]) -> Int = "yue_sys_shell_reveal"

///|
/// Windows 直调：ShellExecuteW 用**指定程序**打开文件（lpFile=程序、
/// lpParameters=带引号的路径）。非 Windows 分支恒给 0。
#borrow(app, path, ok)
extern "c" fn ffi_shell_open_with(
  app : Bytes,
  path : Bytes,
  ok : Ref[Int],
) -> Int = "yue_sys_shell_open_with"

///|
/// 打开文件的错误类型（`open_file` / `open_file_with` 共用）。
pub(all) enum OpenFileError {
  /// 平台不支持
  Unsupported
  /// 路径不存在（先判一次，免得把「打不开」报成「已交给系统」）
  NotFound
  /// 交给系统的 spawn 失败（Windows 含程序名解析不到）
  SpawnFailed
}

///|
pub impl Show for OpenFileError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("OpenFileError::Unsupported")
    NotFound => logger.write_string("OpenFileError::NotFound")
    SpawnFailed => logger.write_string("OpenFileError::SpawnFailed")
  }
}

///|
pub extend OpenFileError with Show::{to_string, output}

///|
/// 用**系统默认程序**打开一个文件（相对路径按工作目录解析；文档/图片/可执行
/// 文件都按系统关联走）。Windows 直调 ShellExecuteW「open」，Linux 走
/// `xdg-open`，macOS 走 `open`。`Ok` 只表示「已交给系统」，之后归操作系统。
pub fn open_file(path : String) -> Result[Unit, OpenFileError] {
  let plat = sys_platform()
  if plat != "windows" && plat != "linux" && plat != "macos" {
    return Err(Unsupported)
  }
  let abs = launcher_abs_path(path, current_dir())
  if path == "" || !sys_path_exists(abs) {
    return Err(NotFound)
  }
  match plat {
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_shell_open(@utf8.encode(launcher_win_path(abs)), ok)
      if ok.val == 1 { Ok(()) } else { Err(SpawnFailed) }
    }
    "linux" =>
      match spawn_detached("xdg-open", abs) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
    _ =>
      match spawn_detached("open", abs) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
  }
}

///|
/// 用**指定程序**打开一个文件：`app` 可以是程序名（按 PATH/系统搜索顺序解析，
/// 如 `notepad.exe`）也可以是完整可执行路径，`path` 作为唯一参数传给它。
/// Windows 走 ShellExecuteW（lpFile=程序、lpParameters=带引号的路径，路径里有
/// 空格时对方拿到的才是一整条）；Linux/macOS 走 argv 直传的分离式启动（不经
/// shell，空格天然安全）。macOS 想按 `.app` 起请用可执行文件路径，`open -a`
/// 那种「按应用名」的形态随 mac 平台批再接。
pub fn open_file_with(
  app : String,
  path : String,
) -> Result[Unit, OpenFileError] {
  let plat = sys_platform()
  if plat != "windows" && plat != "linux" && plat != "macos" {
    return Err(Unsupported)
  }
  if app == "" {
    return Err(SpawnFailed)
  }
  let abs = launcher_abs_path(path, current_dir())
  if path == "" || !sys_path_exists(abs) {
    return Err(NotFound)
  }
  match plat {
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_shell_open_with(
        @utf8.encode(app),
        @utf8.encode(launcher_win_path(abs)),
        ok,
      )
      if ok.val == 1 { Ok(()) } else { Err(SpawnFailed) }
    }
    _ =>
      match spawn_detached(app, abs) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
  }
}

///|
/// 本机有没有「把 URL/文件交给系统打开」的后端（Windows `ShellExecuteW`、
/// Linux `xdg-open`、macOS `open`）。运行时探测，纯判据、不碰系统。
/// 用途：示例用它决定按钮文案；测试用它避开真的开窗动作——`ShellExecuteW` 对
/// **未注册的协议**不会返错，而是把系统「你要用什么应用打开」的选择器拉起来，
/// 在测试里调一次就弹一次窗（真踩过），这类动作只归示例与真机复验。
pub fn open_supported() -> Bool {
  match sys_platform() {
    "windows" | "linux" | "macos" => true
    _ => false
  }
}

///|
/// 打开 URL 交给系统默认处理（http/https/mailto 等一律透传，不做校验）。
/// 有真实系统副作用（会拉起浏览器/协议处理程序），不要在测试里调。
pub fn open_url(url : String) -> Result[Unit, OpenUrlError] {
  match sys_platform() {
    "windows" => {
      let ok = Ref(0)
      let _ = ffi_shell_open(@utf8.encode(url), ok)
      if ok.val == 1 {
        Ok(())
      } else {
        Err(SpawnFailed)
      }
    }
    "linux" =>
      match spawn_detached("xdg-open", url) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
    "macos" =>
      match spawn_detached("open", url) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
    _ => Err(Unsupported)
  }
}

///|
/// 在文件管理器中打开路径所在目录（相对路径按工作目录解析）。**这是命令行退路，
/// 选中态丢失**：要「打开并选中」请调 `@core.reveal_in_file_manager`——它在
/// Linux 上先走会话总线的 `FileManager1.ShowItems`（`@dbus` 依赖本包，两条通道
/// 只能在 core 会师），不在线才退回这里。
pub fn reveal_in_file_manager(
  path : String,
) -> Result[Unit, FileManagerError] {
  let plat = sys_platform()
  // 平台门在前：不支持的平台连「路径不存在」都不该说
  if plat != "windows" && plat != "linux" {
    return Err(Unsupported)
  }
  let abs = launcher_abs_path(path, current_dir())
  if path == "" || !sys_path_exists(abs) {
    return Err(NotFound)
  }
  match plat {
    "windows" => {
      // 反斜杠统一后再交出去：混合分隔符下 explorer 的 /select 不选中
      let ok = Ref(0)
      let _ = ffi_shell_reveal(@utf8.encode(launcher_win_path(abs)), ok)
      if ok.val == 1 {
        Ok(())
      } else {
        Err(SpawnFailed)
      }
    }
    _ =>
      match spawn_detached("xdg-open", parent_dir(abs)) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
  }
}
