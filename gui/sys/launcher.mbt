// 打开外部：URL 与文件管理器定位，单入口 + 单错误枚举。三平台都是「交给系统
// 的公开口」：Linux `xdg-open`（argv 直传不经 shell，分离式启动不阻塞调用方）、
// Windows `ShellExecuteW` / `explorer /select`（extern 直链 sys 桩）、
// macOS `open` / `open -R`（Launch Services CLI；选中态与 explorer /select 同档，
// 不必为这一次调用引入 AppKit 归档）。Ok 只表示「已交给系统」，系统侧能否打开
// 由平台负责。

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
  /// 回退 spawn 也失败
  SpawnFailed
}

///|
pub impl Show for FileManagerError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("FileManagerError::Unsupported")
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
/// 相对路径按工作目录归一：已带前导分隔符或 cwd 读不到时原样返回。
pub fn launcher_abs_path(path : String, cwd : String) -> String {
  if path == "" || path.has_prefix("/") || cwd == "" {
    path
  } else {
    cwd + "/" + path
  }
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
/// 打开 URL 交给系统默认处理（http/https/mailto 等一律透传，不做校验）。
/// 三平台后端：Windows `ShellExecuteW` / Linux `xdg-open` / macOS `open`。
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
    // macOS：Launch Services 的公开 CLI `open <url>`（单参数，走分离式启动不等待）
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
  match sys_platform() {
    "windows" => {
      let abs = launcher_abs_path(path, current_dir())
      let ok = Ref(0)
      let _ = ffi_shell_reveal(@utf8.encode(abs), ok)
      if ok.val == 1 {
        Ok(())
      } else {
        Err(SpawnFailed)
      }
    }
    "linux" => {
      let abs = launcher_abs_path(path, current_dir())
      match spawn_detached("xdg-open", parent_dir(abs)) {
        Ok(_) => Ok(())
        Err(_) => Err(SpawnFailed)
      }
    }
    // macOS：`open -R <路径>` = 打开父目录并**选中**该项（对标 explorer /select）。
    // 两个 argv 项，`spawn_detached` 只带一个参数，所以走 pr_run 那条同步线
    // （`open` 交完活就退出，等待成本是一次进程往返）。
    "macos" => {
      let abs = launcher_abs_path(path, current_dir())
      match pr_run("open", ["-R", abs], timeout_ms=3000) {
        Ok(o) if o.exit_code == 0 => Ok(())
        _ => Err(SpawnFailed)
      }
    }
    _ => Err(Unsupported)
  }
}
