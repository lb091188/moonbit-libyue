///|
/// 系统托盘（W20c）的平台门面：把 stub.c 的 `wm_tray_*` 包成 MoonBit 侧可用
/// 的形态。托盘是「一个消息窗 + 一个槽号」的 Shell 通知图标——句柄就是槽号
/// （1 起，0 = 无/失败）。图标走 W20f 的 `Icon`（`Icon::handle()` 取句柄传给
/// `tray_new`），右键菜单走 W20a 的菜单句柄（`menu_popup_new` 建弹出根）。
///
/// 回调（左键/右键）不蹦床回 MoonBit：C 侧压进程级队列，宿主每拍调
/// `poll_tray_event` 抽——与菜单/热键同制。`core/tray.mbt` 的门面在此之上
/// 建「后端选择 + 回调表 + 菜单翻译」，一般调用方不直接碰这一层。

///|
/// 托盘后端是否可用（Win32 恒 true；GTK/占位分支恒 false——Linux 的托盘走
/// SNI，不经这一层）。
pub fn tray_supported() -> Bool {
  wm_tray_supported() != 0
}

///|
/// 建托盘图标：`icon_slot` 是 W20f 的图标句柄（0 = 无图标），`tip` 为初始
/// tooltip。返回槽号（>=1）或 0（表满 / Shell_NotifyIcon 失败）。
pub fn tray_new(icon_slot : Int, tip : String) -> Int {
  wm_tray_new(icon_slot, @utf8.encode(tip))
}

///|
/// 托盘事件种类：0 = 左键单击、1 = 右键单击。
pub const TRAY_EVENT_CLICK : Int = 0

///|
pub const TRAY_EVENT_CONTEXT : Int = 1

///|
/// 改 tooltip。
pub fn tray_set_tooltip(slot : Int, tip : String) -> Unit {
  wm_tray_set_tooltip(slot, @utf8.encode(tip))
}

///|
/// 换图标（`icon_slot` 是 W20f 句柄，0 = 清空图标）。
pub fn tray_set_icon(slot : Int, icon_slot : Int) -> Unit {
  wm_tray_set_icon(slot, icon_slot)
}

///|
/// 挂右键菜单（`menu_handle` 是 `menu_popup_new` 返回的弹出菜单根句柄）。
pub fn tray_set_menu(slot : Int, menu_handle : Int) -> Unit {
  wm_tray_set_menu(slot, menu_handle)
}

///|
/// 在光标处弹出右键菜单（阻塞到选中/取消）；选中项命令 id 进菜单队列，
/// 返回是否选中了一项。无菜单/取消返回 false。
pub fn tray_popup(slot : Int) -> Bool {
  wm_tray_popup(slot) != 0
}

///|
/// 移除托盘图标（幂等）。
pub fn tray_remove(slot : Int) -> Unit {
  wm_tray_remove(slot)
}

///|
/// 取一个待处理托盘事件，返回 `(槽号, 种类)`；无事件给 None。种类见
/// `TRAY_EVENT_CLICK` / `TRAY_EVENT_CONTEXT`。宿主每拍调一次。
pub fn poll_tray_event() -> (Int, Int)? {
  let slot = Ref(0)
  let kind = Ref(0)
  if wm_tray_poll(slot, kind) != 0 {
    Some((slot.val, kind.val))
  } else {
    None
  }
}

///|
/// 在用托盘槽数（探针/测试读回用）。
pub fn tray_count() -> Int {
  wm_tray_count()
}

///|
/// 读回托盘 tooltip（空串 = 读不到/无此项；非 Windows 后端恒空）。
pub fn tray_tooltip(slot : Int) -> String {
  let buf = Bytes::new(256)
  let n = wm_tray_tooltip(slot, buf, 256)
  if n <= 0 {
    ""
  } else {
    @utf8.decode_lossy(buf[0:n])
  }
}

///|
/// 建一个弹出菜单根（托盘右键菜单用；与菜单条同句柄口径）。返回句柄
/// （0 = 表满/后端不支持）。供 `core/tray.mbt` 的菜单翻译层使用。
pub fn menu_popup_new() -> Int {
  wm_menu_popup_new()
}
