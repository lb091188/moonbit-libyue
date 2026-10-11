// 单实例（防多开）与二次启动唤起：跨平台统一 API。
// 平台路由：Linux = traybus 声称应用专属总线名 + Wake 方法调用（纯 MoonBit）；
// Windows = 命名互斥体 + message-only 窗口 WM_COPYDATA 透传命令行（shim）；
// macOS = TMPDIR 下的 mkdir 排他锁目录 + pid 判活（纯 MoonBit，见
// [acquire_mac]；无跨实例唤醒通道）。
// 语义归一在本层，使用方零平台感知。
//
// 典型用法：
//   match @system.SingleInstance::acquire("com.example.app") {
//     Ok(Some(si)) => { si.on_activate(fn(args) { ... }); /* 继续启动 */ }
//     Ok(None) => { /* 已有实例且已唤醒，退出 */ }
//     Err(e) => { /* 单实例不可用，自行决定继续启动还是退出 */ }
//   }

///|
/// 首实例句柄：持有期间保持平台侧的单实例所有权。
/// on_activate 收第二实例命令行参数（双平台对称）。
pub struct SingleInstance {
  app_id : String
  mut activate : ((Array[String]) -> Unit)?
}

///|
/// 尝试成为首实例。
/// - Ok(Some(handle))：首实例，继续启动；handle.on_activate 注册唤起回调。
/// - Ok(None)：已存在实例且已向它发唤醒，调用方应退出。
/// - Err：单实例不可用（平台不支持 / app_id 非法 / 后端不可达），
///   调用方自行决定继续启动（降级）还是退出。
pub fn SingleInstance::acquire(
  app_id : String,
) -> Result[SingleInstance?, @yue.SingleInstanceError] {
  if !@traybus.valid_app_id(app_id) {
    return Err(@yue.InvalidAppId)
  }
  match @yue.platform() {
    "linux" =>
      match @traybus.claim_name(app_id) {
        Ok(@traybus.PrimaryOwner) | Ok(@traybus.AlreadyOwner) =>
          Ok(Some({ app_id, activate: None, }))
        Ok(@traybus.AlreadyExists) => {
          let _ = @traybus.wake_existing(app_id, command_line())
          Ok(None)
        }
        // DO_NOT_QUEUE 下不会出现；防御性按「让出」处理
        Ok(@traybus.InQueue) => Ok(None)
        Err(_) => Err(@yue.BackendUnavailable)
      }
    "windows" => acquire_windows(app_id)
    "macos" => acquire_mac(app_id)
    _ => Err(@yue.Unsupported)
  }
}

///|
/// 注册第二实例唤起回调（命令行参数）。取得首实例后调用。
pub fn SingleInstance::on_activate(
  self : SingleInstance,
  cb : (Array[String]) -> Unit,
) -> Unit {
  self.activate = Some(cb)
  // Linux 经 traybus 的 Wake 分发触发；Windows 的 callback 在 acquire 时
  // 已挂到消息窗口蹦床，两条路都归集到 self.activate 一处读出
  match @yue.platform() {
    "linux" =>
      @traybus.on_wake(fn(args) {
        match self.activate {
          Some(f) => f(args)
          None => ()
        }
      })
    // macOS 无跨实例唤醒通道（shim 的窗口消息与置前接口在 macOS 均为桩，
    // 锁目录只能判「已有实例」、传不了命令行）：回调注册后不会被触发
    "macos" => ()
    _ => ()
  }
}

///|
/// Windows 首实例：建 message-only 窗口收 WM_COPYDATA。
fn acquire_windows(
  app_id : String,
) -> Result[SingleInstance?, @yue.SingleInstanceError] {
  let ok = Ref(0)
  if @yue.ffi_win_named_mutex_create(@yue.utf8_bytes(instance_mutex_name(app_id)), ok) !=
    0 {
    return Err(@yue.BackendUnavailable)
  }
  if ok.val == 0 {
    // 已有实例：主路径送命令行到首实例消息窗口（首实例在回调内自置前），
    // 再兜底按标题查找置前——Windows 前台互斥下，刚启动的第二进程往往
    // 是唯一能成功 SetForegroundWindow 的一方
    wake_windows(app_id)
    return Ok(None)
  }
  let handle : SingleInstance = { app_id, activate: None, }
  // WM_COPYDATA 负载是 \n 连接的命令行(wake_windows 同款拼法),收端
  // 拆回数组;空负载不当成一次空参数唤起
  let wrapped : (Bytes) -> Unit = fn(b) {
    let text = @yue.from_utf8_bytes(b)
    let args = if text == "" {
      []
    } else {
      text.split("\n").collect().map(fn(s) { s.to_owned() })
    }
    handle.fire_activate(args)
  }
  @yue.keep_alive_bytes(wrapped)
  // 建窗失败不改变首实例身份（互斥体已持有），只是唤起收不到；
  // 兜底查找置前仍然可用，此处降级继续
  let _ = @yue.ffi_win_instance_window_create(
    @yue.utf8_bytes(instance_class_name(app_id)),
    fn(f : (Bytes) -> Unit, b : Bytes) -> Unit { f(b) },
    wrapped,
  )
  Ok(Some(handle))
}

///|
/// Windows 二次启动：向首实例消息窗口发 Wake，失败按标题兜底置前。
fn wake_windows(app_id : String) -> Unit {
  let sent = Ref(0)
  let rc = @yue.ffi_win_instance_window_send(
    @yue.utf8_bytes(instance_class_name(app_id)),
    @yue.utf8_bytes(command_line().join("\n")),
    sent,
  )
  if rc != 0 || sent.val == 0 {
    let found = Ref(0)
    let _ = @yue.ffi_win_find_and_activate(@yue.utf8_bytes(g_window_title.val), found)
  }
}

///|
/// 读出唤起回调（两条平台路线的汇点）。
fn SingleInstance::fire_activate(
  self : SingleInstance,
  args : Array[String],
) -> Unit {
  match self.activate {
    Some(cb) => cb(args)
    None => ()
  }
}

///|
/// 本进程命令行参数（第二实例透传给首实例）。
fn command_line() -> Array[String] {
  @env.args()
}

///|
/// Windows 命名互斥体名（Local\ 会话命名空间，免提升权限）。
fn instance_mutex_name(app_id : String) -> String {
  "moonbit.libyue.instance." + app_id
}

///|
/// Windows 消息窗口类名：由 app_id 派生（app_id 字符集已由 DBus 知名名
/// 规则保证干净，点换成下划线）。
fn instance_class_name(app_id : String) -> String {
  let sb = StringBuilder()
  sb.write_string("moonbit_libyue_instance_")
  // Char 遍历(码点):app_id 已由知名名规则收窄为 ASCII,点换下划线
  for c in app_id {
    sb.write_char(if c == '.' { '_' } else { c })
  }
  sb.to_string()
}

///|
/// 可选：主窗口标题提示。Windows 兜底路径（首实例消息窗口不可达的新旧
/// 构建混跑场景）用它查找并置前首实例窗口；两个实例都应设置。Linux 忽略。
let g_window_title : Ref[String] = Ref("")

///|
pub fn set_instance_window_title(title : String) -> Unit {
  g_window_title.val = title
}

// ---------------------------------------------------------------------------
// macOS：TMPDIR 下的 mkdir 排他锁 + pid 判活（纯函数层白盒测试覆盖）
//
// macOS 既没有 D-Bus（Linux 的声称总线名不可用），shim 的命名互斥体与
// 窗口消息在 macOS 也是桩，只能自己造锁：POSIX 的 mkdir 对已存在目录
// 必然失败，是本包拿不到 O_EXCL / flock 时唯一可靠的原子互斥手段；锁里
// 记 pid 是为了区分「真有实例在跑」与「上次崩溃留下的陈旧锁」。
// TMPDIR 在 macOS 形如 /var/folders/xx/yy/T，天然按用户隔离（等价于
// Windows 的会话命名空间，无需提升权限）。路径拼装与 pid 解析是纯函数，
// singleinstance_wbtest.mbt 白盒覆盖（无 macOS 真机也能测）。
// ---------------------------------------------------------------------------

///|
/// macOS 锁文件所在临时目录：TMPDIR（设且非空）优先，回退 /tmp。
pub fn si_mac_tmp_dir(tmpdir : String?) -> String {
  match tmpdir {
    Some(d) if d != "" => d
    _ => "/tmp"
  }
}

///|
/// macOS 单实例锁目录：临时目录下的 <应用标识>.lock（由 mkdir 排他创建
/// 的空目录，持有即首实例）。
pub fn si_mac_lock_dir(tmpdir : String?, app_id : String) -> String {
  si_mac_tmp_dir(tmpdir) + "/" + instance_mutex_name(app_id) + ".lock"
}

///|
/// macOS 单实例 pid 文件：锁目录同级的 <应用标识>.pid（首实例写入自己的
/// pid，供后续实例判活与陈旧锁回收）。
pub fn si_mac_pid_file(tmpdir : String?, app_id : String) -> String {
  si_mac_tmp_dir(tmpdir) + "/" + instance_mutex_name(app_id) + ".pid"
}

///|
/// pid 文件文本 → pid：取文本里的十进制数字拼成正数（空串 / 无数字 /
/// 值为 0 给 None）。纯函数，singleinstance_wbtest.mbt 白盒覆盖。
fn si_mac_parse_pid(text : String) -> Int? {
  let digits : Array[Int] = []
  for ch in text {
    let c = ch.to_int()
    if c >= 48 && c <= 57 {
      digits.push(c - 48)
    }
  }
  if digits.length() == 0 {
    return None
  }
  let mut v = 0
  for d in digits {
    v = v * 10 + d
  }
  if v <= 0 {
    None
  } else {
    Some(v)
  }
}

///|
/// ps 判活的参数表（`-p <pid>`）。纯函数，singleinstance_wbtest.mbt
/// 白盒覆盖。
fn si_mac_ps_args(pid : Int) -> Array[String] {
  ["-p", pid.to_string()]
}

///|
/// macOS 进程存活判定：`ps -p <pid>` 退出码 0 即存活（macOS 没有 /proc
/// 可查，也不用 kill -0 探活以免跨用户权限误判）。
fn si_mac_pid_alive(pid : Int) -> Bool {
  match pr_run("ps", si_mac_ps_args(pid), timeout_ms=3000) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// macOS 首实例判定：TMPDIR 下用 `mkdir` 排他建锁目录；建成者写 pid 后为
/// 首实例（Ok(Some)），建不成者读 pid 判活——进程还在即让出（Ok(None)），
/// pid 读不到或进程已退出视为陈旧锁，删锁重建一次（崩溃残留不该让应用
/// 再也起不来），重建仍失败按「已有实例」让出；子进程不可用 →
/// BackendUnavailable。
///
/// 与另两平台的差异：macOS 没有跨实例唤醒通道，第二实例只判「已有
/// 实例」，不置前首实例窗口也不透传命令行，因此
/// [SingleInstance::on_activate] 在 macOS 不会被触发。
fn acquire_mac(
  app_id : String,
) -> Result[SingleInstance?, @yue.SingleInstanceError] {
  if !pr_available() {
    return Err(@yue.BackendUnavailable)
  }
  let tmp = @env.get_env_var("TMPDIR")
  let lock_dir = si_mac_lock_dir(tmp, app_id)
  let pid_file = si_mac_pid_file(tmp, app_id)
  match pr_run("mkdir", [lock_dir], timeout_ms=4000) {
    Ok(_) => Ok(si_mac_claim(pid_file, app_id))
    Err(NonZeroExit(_, _)) => {
      // 目录已存在：pid 还活着才让出，否则按陈旧锁回收重建
      let alive = match @yue.read_text_file(pid_file) {
        None => false
        Some(text) =>
          match si_mac_parse_pid(text) {
            None => false
            Some(pid) => pid != @yue.ffi_proc_getpid() && si_mac_pid_alive(pid)
          }
      }
      if alive {
        Ok(None)
      } else {
        let ok = Ref(0)
        let _ = @yue.ffi_remove_file(@yue.utf8_bytes(pid_file), ok)
        let _ = pr_run("rmdir", [lock_dir], timeout_ms=4000)
        match pr_run("mkdir", [lock_dir], timeout_ms=4000) {
          Ok(_) => Ok(si_mac_claim(pid_file, app_id))
          Err(_) => Ok(None)
        }
      }
    }
    Err(_) => Err(@yue.BackendUnavailable)
  }
}

///|
/// 成为首实例：把本进程 pid 写进 pid 文件（供后续实例判活）后给出句柄。
/// pid 文件写失败不影响首实例身份（锁目录已排他持有），只让判活降级。
fn si_mac_claim(pid_file : String, app_id : String) -> SingleInstance? {
  let _ = @yue.write_text_file(pid_file, @yue.ffi_proc_getpid().to_string())
  Some({ app_id, activate: None, })
}
