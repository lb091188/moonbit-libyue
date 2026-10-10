// 子进程执行 helper：统一「spawn → 限时回收 → 临时文件捕获 stdout/stderr」
// 的命令行工具调用封装，供音量/显示器/壁纸/窗口/打印机/电源计划等需要
// 调系统命令的模块共用。原生 spawn/wait 由 shim 提供（Linux
// fork/execvpe + setsid 自成进程组、Windows CreateProcessW +
// CREATE_NO_WINDOW 不闪控制台，macOS 桩），Linux 子进程环境强制 C locale
// 使输出语言恒定可解析，Windows 继承父进程环境；退出码 0 归一为 Ok，
// 非零退出归一为 Err 并携带 stderr，调用方无需再自行判码。
// 平台差异：命令不存在在 Unix 惯例下由子进程以退出码 127 呈现
// （NonZeroExit），Windows 下 CreateProcessW 直接失败（SpawnFailed）。

///|
/// 子进程执行结果：stdout 为捕获的标准输出文本，exit_code 为退出码
/// （[pr_run] 成功时为 0）。
pub(all) struct ProcOutput {
  stdout : String
  exit_code : Int
}

///|
pub impl Show for ProcOutput with fn output(self, logger) {
  logger.write_string("ProcOutput { stdout: ")
  logger.write_string(self.stdout)
  logger.write_string(", exit_code: ")
  logger.write_string(self.exit_code.to_string())
  logger.write_string(" }")
}

///|
pub extend ProcOutput with Show::{to_string, output}

///|
pub(all) enum ProcError {
  /// 当前平台不支持子进程执行（仅 Linux / Windows）
  Unsupported
  /// 父侧启动失败（spawn 系统调用失败，如 fork / 内存不足），带命令与
  /// 原因；Unix 下命令不存在由子进程以退出码 127 呈现（归入非零退出），
  /// Windows 下 CreateProcessW 失败即此错误
  SpawnFailed(String)
  /// 超时（超过 timeout_ms 未退出，进程已被强制终止），带命令与预算
  Timeout(String)
  /// 非零退出码，带退出码与捕获到的 stderr（可能为空串）
  NonZeroExit(Int, String)
  /// 进程被信号终止，带信号编号（仅 Unix 呈现）
  Signaled(Int)
}

///|
pub impl Show for ProcError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("ProcError::Unsupported")
    SpawnFailed(m) => logger.write_string("ProcError::SpawnFailed(\{m})")
    Timeout(m) => logger.write_string("ProcError::Timeout(\{m})")
    NonZeroExit(code, err) =>
      logger.write_string("ProcError::NonZeroExit(\{code}, \{err})")
    Signaled(sig) => logger.write_string("ProcError::Signaled(\{sig})")
  }
}

///|
pub extend ProcError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 子进程执行层（shim：spawn → 限时回收 → 临时文件读回）
// ---------------------------------------------------------------------------

///|
/// 临时文件名自增序号（与进程 pid 联合保证并发内唯一）。
let pr_tmp_counter : Ref[Int] = Ref(0)

///|
/// 临时输出文件路径（Linux 读 $TMPDIR 缺省 /tmp；Windows 读 %TEMP% 缺省
/// 当前目录）。
fn pr_tmp_path(tag : String) -> String {
  pr_tmp_counter.val = pr_tmp_counter.val + 1
  let env_name = if @yue.platform() == "windows" { "TEMP" } else { "TMPDIR" }
  let fallback = if @yue.platform() == "windows" { "." } else { "/tmp" }
  let dir = match @env.get_env_var(env_name) {
    Some(d) => if d != "" { d } else { fallback }
    None => fallback
  }
  let sep = if @yue.platform() == "windows" { "\\" } else { "/" }
  "\{dir}\{sep}yue-pr-\{@yue.ffi_proc_getpid()}-\{pr_tmp_counter.val}.\{tag}"
}

///|
/// 参数表编码为「NUL 分隔条目 + 空条目收尾」文本（shim 的 spawn 参数协议）。
fn pr_args_blob(args : Array[String]) -> Bytes {
  let buf = StringBuilder()
  for a in args {
    buf.write_string(a)
    buf.write_char('\u{0}')
  }
  buf.write_char('\u{0}')
  @utf8.encode(buf.to_string())
}

///|
/// 传给子进程的环境编码（同上协议）。Linux 给最小环境：PATH（命令名解析）、
/// XDG_RUNTIME_DIR（会话服务套接字定位）、HOME，并固定 C locale 使输出
/// 语言恒定可解析；Windows 传空 blob（继承父进程环境，无 locale 语义）。
fn pr_env_blob() -> Bytes {
  let buf = StringBuilder()
  if @yue.platform() == "linux" {
    for name in ["PATH", "XDG_RUNTIME_DIR", "HOME"] {
      match @env.get_env_var(name) {
        Some(v) => {
          buf.write_string(name)
          buf.write_char('=')
          buf.write_string(v)
          buf.write_char('\u{0}')
        }
        None => ()
      }
    }
    buf.write_string("LC_ALL=C")
    buf.write_char('\u{0}')
  }
  buf.write_char('\u{0}')
  @utf8.encode(buf.to_string())
}

///|
/// 读回临时文件文本（读不到为空串）。
fn pr_slurp(path : String) -> String {
  match @yue.read_text_file(path) {
    Some(t) => t
    None => ""
  }
}

///|
/// 当前平台是否支持子进程执行（Linux / Windows）。基于 [pr_run] 的模块
/// 可用它做平台门；每次调用真实判断，高频场景请调用方自行缓存结果。
pub fn pr_available() -> Bool {
  let p = @yue.platform()
  p == "linux" || p == "windows"
}

///|
/// 运行命令并按退出码归一结果：命令名按 PATH 解析；退出码 0 →
/// Ok(stdout)，非零退出 → Err(NonZeroExit(退出码, stderr))，启动失败 /
/// 超时 / 被信号终止 / 平台不支持为对应 Err；超时进程会被强制终止。
///
/// 用法：
///   match pr_run("wpctl", ["get-volume", "@DEFAULT_SINK@"]) {
///     Ok(out) => println(out.stdout)
///     Err(NonZeroExit(_, err)) => println("失败：\{err}")
///     Err(e) => println(e)
///   }
pub fn pr_run(
  cmd : String,
  args : Array[String],
  timeout_ms? : Int = 5000,
) -> Result[ProcOutput, ProcError] {
  let platform = @yue.platform()
  if platform != "linux" && platform != "windows" {
    return Err(Unsupported)
  }
  let out_path = pr_tmp_path("out")
  let err_path = pr_tmp_path("err")
  let cwd = if platform == "windows" { "" } else { "/" }
  let pid = @yue.ffi_proc_spawn(
    @yue.utf8_bytes(cmd),
    pr_args_blob(args),
    @yue.utf8_bytes(cwd),
    @yue.utf8_bytes(out_path),
    @yue.utf8_bytes(err_path),
    pr_env_blob(),
  )
  let ans : Result[ProcOutput, ProcError] = if pid < 0 {
    Err(
      SpawnFailed(
        "\{cmd}: spawn 失败（错误码 \{-pid}，Windows 下含命令不存在）",
      ),
    )
  } else {
    let status = Ref(-1)
    let code = Ref(0)
    let wr = @yue.ffi_proc_wait(pid, timeout_ms, status, code)
    if wr != 0 {
      Err(SpawnFailed("\{cmd}: wait 失败（错误码 \{wr}）"))
    } else if status.val == 1 {
      Err(Timeout("\{cmd}: 超时（\{timeout_ms}ms）"))
    } else if status.val == 2 {
      Err(Signaled(code.val))
    } else if code.val == 0 {
      Ok({ stdout: pr_slurp(out_path), exit_code: 0, })
    } else {
      Err(NonZeroExit(code.val, pr_slurp(err_path)))
    }
  }
  // 清理临时文件（无论成败）
  let ok = Ref(0)
  let _ = @yue.ffi_remove_file(@yue.utf8_bytes(out_path), ok)
  let _ = @yue.ffi_remove_file(@yue.utf8_bytes(err_path), ok)
  ans
}
