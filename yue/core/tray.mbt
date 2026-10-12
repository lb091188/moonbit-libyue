// 系统托盘门面（W20c）：跨平台一致的 `Tray` API，平台差异收敛在后端选择里。
//
// 后端选择（按优先级，与旧栈同口径）：
// 1. Linux：纯 MoonBit 的 StatusNotifierItem（`yue/dbus/sni.mbt`，会话总线直连
//    面板，不依赖 AppIndicator 运行库）。判据是 watcher 是否在线
//    （`@dbus.sni_watcher_present()`）——只连得上总线不算数。
// 2. Windows：`yue/win` 的 Shell_NotifyIconW 后端（W20c 本批桩）。
// 3. 皆无 → `Err(TrayError::Unsupported)`（**结构化报错，绝不静默失效**）。
//
// 回调不蹦床：Win32 侧左键/右键压进进程级队列，宿主每拍调
// `dispatch_tray_event()` 抽（与 `dispatch_menu_command()` 同制）；Linux SNI 侧
// 由 DBus 信号直达回调。右键菜单两条路都用同一套菜单模型 `Menu`：Win32 走
// W20a 的 HMENU 翻译（`wm_menu_popup_new` + `menu_translate_into`），选中项经
// `wm_menu_push` 回到 `dispatch_menu_command()` 的同一条派发链；SNI 走
// DBusMenu 条目。

///|
/// 托盘后端。
pub(all) enum TrayBackend {
  /// Win32 Shell 通知图标（槽号，见 `yue/win/tray.mbt`）
  Native(Int)
  /// Linux StatusNotifierItem（`yue/dbus/sni.mbt`）
  Sni(@dbus.Item)
}

///|
/// 结构化托盘错误：后端缺失 / 图标读取失败 / 其他后端原因。消费方 match 即可，
/// 无需探平台。（旧栈同名类型在待退役的 `yue/error.mbt`，新栈口径住本文件。）
pub(all) enum TrayError {
  /// 系统没有可用的托盘后端（Linux watcher 不在线且无原生档；macOS 待真机）
  Unsupported
  /// 图标文件读取或解码失败
  IconLoadFailed
  /// 后端自身的失败原因（如 SNI 注册被拒）
  Backend(String)
}

///|
pub impl Show for TrayError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("TrayError::Unsupported")
    IconLoadFailed => logger.write_string("TrayError::IconLoadFailed")
    Backend(msg) => {
      logger.write_string("TrayError::Backend(")
      logger.write_string(msg)
      logger.write_string(")")
    }
  }
}

///|
pub extend TrayError with Show::{to_string, output}

///|
/// 单个托盘项的回调与状态（Native 后端要按槽号找回回调，故存进进程级表）。
struct TrayState {
  mut on_click : (() -> Unit)?
  mut on_context : (() -> Unit)?
  /// 右键菜单的原生句柄（Win32 弹出菜单根；0 = 无）
  mut menu_handle : Int
}

///|
/// 托盘句柄。`Tray::new` 之后用它改标题/图标/提示/菜单、挂回调、移除。
pub(all) struct Tray {
  backend : TrayBackend
  state : TrayState
}

///|
/// Native 后端槽号 → 同一个 `Tray` 对象（`dispatch_tray_event` 按事件槽号找回
/// 回调）。只登记 Native 后端；SNI 侧点击由 DBus 信号直达回调，不经队列表。
let tray_by_slot : Map[Int, Tray] = Map([])

///|
/// 当前桌面环境名（诊断与降级提示用；认不出为 "unknown"）。运行时真伪始终以
/// `Tray::is_supported()` 为准，本函数只描述「跑在什么桌面上」。
pub fn desktop_environment() -> String {
  @sys.desktop_name()
}

///|
/// 托盘后端是否可用。消费方可据此决定是否展示托盘相关功能。
pub fn Tray::is_supported() -> Bool {
  @dbus.sni_watcher_present() || @win.tray_supported()
}

///|
/// 用图标文件建托盘图标。失败给结构化错误：后端缺失
/// （`Unsupported`）或图标读取失败（`IconLoadFailed`）。
/// `icon` 可直接传入已建好的 `@win.Icon`（例如像素现建，W20f 的
/// `icon_from_bgra`），给了就不再读 `icon_path`（路径仍用于推导托盘 Id）。
/// Linux SNI 后端的图标走面板的主题图标名 / 程序内置位图，`icon_path` 只用于
/// 推导托盘 Id（旧栈同口径）；PNG 任意像素解码未内置，需要时用
/// `set_icon_name` 指定主题图标名。
pub fn Tray::new(
  icon_path : String,
  icon? : @win.Icon? = None,
) -> Result[Tray, TrayError] {
  let id = basename_no_ext(icon_path)
  if @dbus.sni_watcher_present() {
    match @dbus.Item::create(id, icon_path) {
      Ok(item) => return Ok({ backend: Sni(item), state: new_tray_state() })
      Err(_) => () // watcher 不在线等，继续向下回退
    }
  }
  if @win.tray_supported() {
    let handle = match icon {
      Some(ic) => ic.handle
      None => icon_handle_of(icon_path)
    }
    let slot = @win.tray_new(handle, id)
    if slot > 0 {
      let tray : Tray = { backend: Native(slot), state: new_tray_state() }
      tray_by_slot.set(slot, tray)
      return Ok(tray)
    }
    // 槽表满或 Shell_NotifyIcon 失败
    return Err(Backend("托盘槽表满或 Shell_NotifyIcon 失败"))
  }
  Err(Unsupported)
}

///|
fn new_tray_state() -> TrayState {
  { on_click: None, on_context: None, menu_handle: 0 }
}

///|
/// 载入图标文件取句柄（空路径给 0 = 无图标；加载失败也给 0，交由后端用默认）。
fn icon_handle_of(icon_path : String) -> Int {
  if icon_path == "" {
    0
  } else {
    match @win.load_icon_file(icon_path) {
      Some(ic) => ic.handle
      None => 0
    }
  }
}

///|
/// 从路径取不含扩展名的文件名，作托盘 Id。目录名里的点不算扩展名分隔。
pub fn basename_no_ext(path : String) -> String {
  let name = match path.rev_find("\\") {
    Some(i_bs) =>
      match path.rev_find("/") {
        Some(i_sl) => if i_bs > i_sl { path[i_bs + 1:].to_owned() } else { path[i_sl + 1:].to_owned() }
        None => path[i_bs + 1:].to_owned()
      }
    None =>
      match path.rev_find("/") {
        Some(i) => path[i + 1:].to_owned()
        None => path
      }
  }
  match name.rev_find(".") {
    Some(i) => name[0:i].to_owned()
    None => name
  }
}

///|
/// 后端种类（消费方一般不必关心，诊断/测试用）。
pub fn Tray::backend(self : Tray) -> TrayBackend {
  self.backend
}

///|
/// 后端名（"native" / "sni"，状态行与诊断用）。
pub fn Tray::backend_name(self : Tray) -> String {
  match self.backend {
    Native(_) => "native"
    Sni(_) => "sni"
  }
}

///|
/// 设置托盘标题（部分面板不渲染，属平台表现差异，接口不变）。Win32 托盘没有
/// 标题概念，走 `set_tooltip`；SNI 有 `Title` 属性。
pub fn Tray::set_title(self : Tray, title : String) -> Unit {
  match self.backend {
    Native(_) => self.set_tooltip(title, "")
    Sni(item) => item.set_title(title)
  }
}

///|
/// 换图标（按文件路径）。SNI 后端取路径里的文件名当主题图标名；Win32 走后端
/// 的图标表（加载失败静默保持原图标，不崩）。
pub fn Tray::set_icon(self : Tray, icon_path : String) -> Unit {
  match self.backend {
    Native(slot) => @win.tray_set_icon(slot, icon_handle_of(icon_path))
    Sni(item) => item.set_icon_name(basename_no_ext(icon_path))
  }
}

///|
/// 按主题图标名换图标（Linux 面板认主题名；Win32 无此概念，忽略）。
pub fn Tray::set_icon_name(self : Tray, name : String) -> Unit {
  match self.backend {
    Native(_) => ()
    Sni(item) => item.set_icon_name(name)
  }
}

///|
/// 设置悬浮提示。SNI 有 title/body 两段；Win32 只有一段 `szTip`，用 body（非空
/// 时）否则 title。
pub fn Tray::set_tooltip(self : Tray, title : String, body : String) -> Unit {
  match self.backend {
    Native(slot) => {
      let text = if body == "" { title } else { body }
      @win.tray_set_tooltip(slot, text)
    }
    Sni(item) => item.set_tooltip(title, body)
  }
}

///|
/// 注册左键单击回调。
pub fn Tray::on_click(self : Tray, callback : () -> Unit) -> Unit {
  self.state.on_click = Some(callback)
  match self.backend {
    Native(_) => ()
    Sni(item) => item.set_click_handler(callback)
  }
}

///|
/// 注册右键回调。**不给回调时右键默认弹已挂的菜单**（Win32 习惯）；给了回调则
/// 交给回调，由它自己决定（例如 `popup_menu`）。
pub fn Tray::on_context(self : Tray, callback : () -> Unit) -> Unit {
  self.state.on_context = Some(callback)
  match self.backend {
    Native(_) => ()
    Sni(item) => item.set_context_handler(callback)
  }
}

///|
/// 挂右键菜单（复用 W20a 的菜单模型）。Win32：翻译成弹出菜单 HMENU 挂上，
/// 选中项经菜单派发链回到 `MenuItem::on_click`。SNI：清空后逐项转成 DBusMenu
/// 条目——**本实现是平铺一级菜单，子菜单被展平**（子项前置一条分隔线）。
pub fn Tray::set_menu(self : Tray, menu : Menu) -> Unit {
  match self.backend {
    Native(slot) => {
      let h = @win.menu_popup_new()
      if h == 0 {
        return
      }
      if menu_translate_into(menu, h) {
        self.state.menu_handle = h
        @win.tray_set_menu(slot, h)
      }
    }
    Sni(item) => {
      item.clear_menu_entries()
      tray_sni_add_items(item, menu.items)
    }
  }
}

///|
/// 把模型菜单平铺进 SNI 的 DBusMenu 条目表（子菜单展平：前置分隔线 + 子项）。
fn tray_sni_add_items(item : @dbus.Item, items : Array[MenuItem]) -> Unit {
  for it in items {
    match it.kind {
      Separator => item.add_menu_separator()
      _ =>
        match it.submenu {
          Some(sub) => {
            item.add_menu_separator()
            tray_sni_add_items(item, sub.items)
          }
          None => {
            let cb = match it.on_click {
              Some(f) => f
              None => fn() { () }
            }
            item.add_menu_entry(it.label, true, cb)
          }
        }
    }
  }
}

///|
/// 在光标处弹出右键菜单（阻塞到选中/取消）；选中项经菜单派发链回到回调。
/// Win32：`TrackPopupMenuEx`；SNI：由面板弹 DBusMenu，本函数是空操作。
/// 返回 Win32 上是否选中了一项。
pub fn Tray::popup_menu(self : Tray) -> Bool {
  match self.backend {
    Native(slot) => @win.tray_popup(slot)
    Sni(_) => false
  }
}

///|
/// 移除托盘图标（幂等）。SNI 走注销 + 从注册表摘除；Win32 走 NIM_DELETE。
pub fn Tray::remove(self : Tray) -> Unit {
  match self.backend {
    Native(slot) => {
      @win.tray_remove(slot)
      let _ = tray_by_slot.remove(slot)
    }
    Sni(item) => item.unregister()
  }
}

///|
/// 宿主每拍调一次：取一个 Win32 托盘事件派发到对应 `Tray` 的回调，命中给 true。
/// 右键无回调时自动弹已挂的菜单（Win32 习惯）。SNI 后端不经此队列（点击由
/// DBus 信号直达回调），故恒返回 false。
pub fn dispatch_tray_event() -> Bool {
  match @win.poll_tray_event() {
    Some((slot, kind)) =>
      match tray_by_slot.get(slot) {
        Some(tray) => {
          if kind == @win.TRAY_EVENT_CONTEXT {
            match tray.state.on_context {
              Some(cb) => {
                cb()
                true
              }
              None =>
                if tray.state.menu_handle != 0 {
                  let _ = tray.popup_menu()
                  true
                } else {
                  false
                }
            }
          } else {
            match tray.state.on_click {
              Some(cb) => {
                cb()
                true
              }
              None => false
            }
          }
        }
        None => false
      }
    None => false
  }
}
