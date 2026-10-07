// 子进程执行 helper：统一「spawn → 限时回收 → 临时文件捕获 stdout/stderr」
// 的命令行工具调用封装，供音量/显示器/壁纸/窗口/打印机/电源计划等需要
// 调系统命令的模块共用。基于 @subproc（仅 Linux），子进程环境强制
// C locale 使输出语言恒定可解析；退出码 0 归一为 Ok，非零退出归一为
// Err 并携带 stderr，调用方无需再自行判码。

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
  /// 当前平台不支持子进程执行（非 Linux）
  Unsupported
  /// 父侧启动失败（spawn 系统调用失败，如 fork / 内存不足），带命令与
  /// 原因；命令不存在按 Unix 惯例由子进程以退出码 127 呈现，归入非零退出
  SpawnFailed(String)
  /// 超时（超过 timeout_ms 未退出，进程已被强制终止），带命令与预算
  Timeout(String)
  /// 非零退出码，带退出码与捕获到的 stderr（可能为空串）
  NonZeroExit(Int, String)
  /// 进程被信号终止，带信号编号
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
// 子进程执行层（@subproc：spawn → 限时回收 → 临时文件读回）
// ---------------------------------------------------------------------------

///|
/// 临时文件名自增序号（与进程 pid 联合保证并发内唯一）。
let pr_tmp_counter : Ref[Int] = Ref(0)

///|
/// 临时输出文件路径（$TMPDIR 下，缺省 /tmp）。
fn pr_tmp_path(tag : String) -> String {
  pr_tmp_counter.val = pr_tmp_counter.val + 1
  let dir = match @env.get_env_var("TMPDIR") {
    Some(d) => if d != "" { d } else { "/tmp" }
    None => "/tmp"
  }
  "\{dir}/yue-pr-\{@subproc.get_pid()}-\{pr_tmp_counter.val}.\{tag}"
}

///|
/// 传给子进程的环境（NUL 分隔的 "K=V" blob）：PATH（命令名解析）、
/// XDG_RUNTIME_DIR（会话服务套接字定位）、HOME，并固定 C locale 使
/// 输出语言恒定可解析。
fn pr_env_blob() -> Bytes {
  let buf = StringBuilder()
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
  buf.write_char('\u{0}')
  @utf8.encode(buf.to_string())
}

///|
/// 读回临时文件文本（读不到为空串）。
fn pr_slurp(path : String) -> String {
  match read_text_file(path) {
    Some(t) => t
    None => ""
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前平台是否支持子进程执行（仅 Linux）。基于 [pr_run] 的模块可用它
/// 做平台门；每次调用真实判断，高频场景请调用方自行缓存结果。
pub fn pr_available() -> Bool {
  platform() == "linux"
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
  if platform() != "linux" {
    return Err(Unsupported)
  }
  let out_path = pr_tmp_path("out")
  let err_path = pr_tmp_path("err")
  // 多参数以 NUL 分隔拼入 script（spawn 的参数协议）
  let script = StringBuilder()
  let mut first = true
  for a in args {
    if !first {
      script.write_char('\u{0}')
    }
    script.write_string(a)
    first = false
  }
  let ans : Result[ProcOutput, ProcError] = try {
    let pid = @subproc.spawn({
      bun_path: cmd,
      script: script.to_string(),
      cwd: "/",
      out_log: out_path,
      err_log: err_path,
      env_blob: pr_env_blob(),
    })
    let started = @env.now()
    match @subproc.wait_child_timeout(pid, timeout_ms) {
      None => Err(Timeout("\{cmd}: 超时（\{timeout_ms}ms）"))
      Some((_, @subproc.Signaled(sig))) =>
        // wait_child_timeout 越过预算后对进程组 SIGKILL 并就地回收，
        // 表现为 Signaled(SIGKILL)；耗时已达预算即守护超时杀，
        // 预算内被信号终止才是外部信号
        if @env.now() - started >= timeout_ms.to_uint64() {
          Err(Timeout("\{cmd}: 超时（\{timeout_ms}ms）"))
        } else {
          Err(Signaled(sig))
        }
      Some((_, @subproc.Exited(code))) =>
        if code == 0 {
          Ok({ stdout: pr_slurp(out_path), exit_code: 0, })
        } else {
          Err(NonZeroExit(code, pr_slurp(err_path)))
        }
    }
  } catch {
    e => Err(SpawnFailed("\{cmd}: \{e.to_string()}"))
  }
  // 清理临时文件（无论成败）
  let ok = Ref(0)
  let _ = ffi_remove_file(utf8_bytes(out_path), ok)
  let _ = ffi_remove_file(utf8_bytes(err_path), ok)
  ans
}
