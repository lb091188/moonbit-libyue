// 单实例（防多开）与二次启动唤起：跨平台统一 API。
// 平台路由：Linux = traybus 声称应用专属总线名 + Wake 方法调用（纯 MoonBit）；
// Windows = 命名互斥体 + message-only 窗口 WM_COPYDATA 透传命令行（shim）。
// 语义归一在本层，使用方零平台感知；macOS 暂缓给结构化 Unsupported。
//
// 典型用法：
//   match @yue.SingleInstance::acquire("com.example.app") {
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
) -> Result[SingleInstance?, SingleInstanceError] {
  if !@traybus.valid_app_id(app_id) {
    return Err(InvalidAppId)
  }
  match platform() {
    "linux" =>
      match @traybus.claim_name(app_id) {
        Ok(@traybus.PrimaryOwner) | Ok(@traybus.AlreadyOwner) =>
          Ok(Some({ app_id, activate: None }))
        Ok(@traybus.AlreadyExists) => {
          let _ = @traybus.wake_existing(app_id, command_line())
          Ok(None)
        }
        // DO_NOT_QUEUE 下不会出现；防御性按「让出」处理
        Ok(@traybus.InQueue) => Ok(None)
        Err(_) => Err(BackendUnavailable)
      }
    "windows" => acquire_windows(app_id)
    _ => Err(Unsupported)
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
  match platform() {
    "linux" =>
      @traybus.on_wake(fn(args) {
        match self.activate {
          Some(f) => f(args)
          None => ()
        }
      })
    _ => ()
  }
}

///|
/// Windows 首实例：建 message-only 窗口收 WM_COPYDATA。
fn acquire_windows(app_id : String) -> Result[SingleInstance?, SingleInstanceError] {
  let ok = Ref(0)
  if ffi_win_named_mutex_create(utf8_bytes(instance_mutex_name(app_id)), ok) != 0 {
    return Err(BackendUnavailable)
  }
  if ok.val == 0 {
    // 已有实例：主路径送命令行到首实例消息窗口（首实例在回调内自置前），
    // 再兜底按标题查找置前——Windows 前台互斥下，刚启动的第二进程往往
    // 是唯一能成功 SetForegroundWindow 的一方
    wake_windows(app_id)
    return Ok(None)
  }
  let handle : SingleInstance = { app_id, activate: None }
  // WM_COPYDATA 负载是 \n 连接的命令行(wake_windows 同款拼法),收端
  // 拆回数组;空负载不当成一次空参数唤起
  let wrapped : (Bytes) -> Unit = fn(b) {
    let text = from_utf8_bytes(b)
    let args = if text == "" {
      []
    } else {
      text.split("\n").collect().map(fn(s) { s.to_owned() })
    }
    handle.fire_activate(args)
  }
  keep_alive_bytes(wrapped)
  // 建窗失败不改变首实例身份（互斥体已持有），只是唤起收不到；
  // 兜底查找置前仍然可用，此处降级继续
  let _ = ffi_win_instance_window_create(
    utf8_bytes(instance_class_name(app_id)),
    fn(f : (Bytes) -> Unit, b : Bytes) -> Unit { f(b) },
    wrapped,
  )
  Ok(Some(handle))
}

///|
/// Windows 二次启动：向首实例消息窗口发 Wake，失败按标题兜底置前。
fn wake_windows(app_id : String) -> Unit {
  let sent = Ref(0)
  let rc = ffi_win_instance_window_send(
    utf8_bytes(instance_class_name(app_id)),
    utf8_bytes(command_line().join("\n")),
    sent,
  )
  if rc != 0 || sent.val == 0 {
    let found = Ref(0)
    let _ = ffi_win_find_and_activate(utf8_bytes(g_window_title.val), found)
  }
}

///|
/// 读出唤起回调（两条平台路线的汇点）。
fn SingleInstance::fire_activate(self : SingleInstance, args : Array[String]) -> Unit {
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
