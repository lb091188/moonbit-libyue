// 剪贴板文本监听：只读轮询系统剪贴板，文本内容变化时通过回调派发新
// 文本。Linux 经 xclip（命令路线走 procrun 的 [pr_run]，spawn → 限时
// 回收 → 捕获 stdout，X11 CLIPBOARD 选区）；Windows 直连 Win32 剪贴板
// （CF_UNICODETEXT，shim 提供）。
//
// 与 methods.mbt 里 libyue 原生 Clipboard 的 start_watching / on_change
// 的分工：后者由 GUI 事件循环驱动（需 initialize 的应用环境）；本模块
// 是纯轮询实现，任意 MoonBit 进程可用，回调落在调用方上下文。
//
// 只读监测无副作用：读失败（如 xclip 未安装、选区无文本）静默跳过该
// 拍，不触发回调。定时器经 [set_timer]（libyue 定时器无取消 id），
// [cbw_stop] 置停靠标志，下一拍回调返回 false 自行终止。
//
// 典型用法：
//   let watcher = cbw_start_watch(fn(text) {
//     println("剪贴板新内容：\{text}")
//   })
//   // ……需要时
//   cbw_stop(watcher)

///|
pub(all) enum ClipboardError {
  /// 当前平台/环境不支持（非 Linux / Windows；Linux 下 xclip 不存在——
  /// Unix 以退出码 127 呈现命令缺失）
  Unsupported
  /// 命令执行失败（spawn 失败 / 非零退出 / 超时 / 被信号终止 /
  /// Win32 剪贴板打开失败），带原因
  CommandFailed(String)
}

///|
pub impl Show for ClipboardError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("ClipboardError::Unsupported")
    CommandFailed(m) =>
      logger.write_string("ClipboardError::CommandFailed(\{m})")
  }
}

///|
pub extend ClipboardError with Show::{to_string, output}

///|
/// 剪贴板监听句柄：active 为运行标志（[cbw_stop] 置 false，下一拍定时
/// 器自行终止）；interval_ms 为生效的轮询间隔（用户值经钳制后的结果）；
/// last 为上拍看到的剪贴板文本（比对基线）。
pub(all) struct ClipboardWatcher {
  active : Ref[Bool]
  interval_ms : Int
  last : Ref[String]
}

// ---------------------------------------------------------------------------
// 纯函数层：轮询间隔钳制 / 一拍比对（白盒测试覆盖）
// ---------------------------------------------------------------------------

///|
/// 轮询间隔钳到 100..60000 毫秒（下限防失控 spawn，上限防永驻高频轮询）。
fn cbw_clamp_interval(ms : Int) -> Int {
  if ms < 100 {
    100
  } else if ms > 60000 {
    60000
  } else {
    ms
  }
}

///|
/// 一拍比对：新文本与基线不同则更新基线并返回 Some(新文本)（调用方据此
/// 派发回调），相同返回 None。基线初值取启动时的剪贴板内容，故初始
/// 内容不触发回调。
fn cbw_poll_step(watcher : ClipboardWatcher, text : String) -> String? {
  if text != watcher.last.val {
    watcher.last.val = text
    Some(text)
  } else {
    None
  }
}

///|
/// stderr 诊断文本压成单行并截断（首行前 120 字符；空串返回空串）。
fn cbw_first_line(s : String) -> String {
  let buf = StringBuilder()
  let mut n = 0
  for ch in s {
    if ch == '\n' || n >= 120 {
      break
    }
    buf.write_char(ch)
    n = n + 1
  }
  buf.to_string()
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 读剪贴板当前文本（只读，文本原样返回，不做去空白）：Linux 走
/// `xclip -selection clipboard -o`（xclip 缺失（退出码 127）或无 X 会话
/// 时为对应 Err）；Windows 走 Win32 剪贴板、macOS 走 NSPasteboard（无
/// 文本时为 CommandFailed）。
pub fn cbw_get_text() -> Result[String, ClipboardError] {
  if @yue.platform() == "windows" || @yue.platform() == "macos" {
    let ok = Ref(0)
    let text = @utf8.decode_lossy(@yue.ffi_clipboard_text(ok))
    if ok.val != 1 {
      return Err(CommandFailed("剪贴板无文本或打开失败"))
    }
    return Ok(text)
  }
  match pr_run("xclip", ["-selection", "clipboard", "-o"], timeout_ms=2000) {
    Ok(o) => Ok(o.stdout)
    Err(NonZeroExit(127, _)) => Err(Unsupported)
    Err(NonZeroExit(code, err)) =>
      Err(CommandFailed("xclip: 退出码 \{code}（\{cbw_first_line(err)}）"))
    Err(Timeout(m)) => Err(CommandFailed(m))
    Err(SpawnFailed(m)) => Err(CommandFailed(m))
    Err(Signaled(sig)) => Err(CommandFailed("xclip: 被信号 \{sig} 终止"))
    Err(Unsupported) => Err(Unsupported)
  }
}

///|
/// 定时器一拍：读剪贴板 → 与基线比对 → 变化则回调新文本；返回是否继续
/// 轮询（[ClipboardWatcher.active] 为 false 即 [cbw_stop] 之后的最后一
/// 拍）。读失败静默跳过、继续轮询。轮询读为阻塞式子进程调用，默认
/// 800ms 一拍的间隔已为子进程开销留出余量。
fn cbw_tick(watcher : ClipboardWatcher, cb : (String) -> Unit) -> Bool {
  if !watcher.active.val {
    false
  } else {
    match cbw_get_text() {
      Ok(t) =>
        match cbw_poll_step(watcher, t) {
          Some(fresh) => cb(fresh)
          None => ()
        }
      Err(_) => ()
    }
    true
  }
}

///|
/// 启动剪贴板监听：按 interval_ms（默认 800ms，钳 100..60000）轮询读
/// 剪贴板，文本变化时以新文本调 cb；基线取启动瞬间的剪贴板内容，初始
/// 内容不触发回调。轮询挂在 libyue 定时器上，需在 GUI 消息循环运行后
/// 才会实际派发。句柄交 [cbw_stop] 停止。
pub fn cbw_start_watch(
  interval_ms? : Int = 800,
  cb : (String) -> Unit,
) -> ClipboardWatcher {
  let ms = cbw_clamp_interval(interval_ms)
  let watcher : ClipboardWatcher = {
    active: Ref(true),
    interval_ms: ms,
    last: Ref(
      match cbw_get_text() {
        Ok(t) => t
        Err(_) => ""
      },
    ),
  }
  @yue.set_timer(ms, fn() { cbw_tick(watcher, cb) })
  watcher
}

///|
/// 停止监听：置停靠标志，至多再跑一拍即自行终止（libyue 定时器无取消
/// id）；幂等，重复调用与对已停句柄调用均安全。
pub fn cbw_stop(watcher : ClipboardWatcher) -> Unit {
  watcher.active.val = false
}
