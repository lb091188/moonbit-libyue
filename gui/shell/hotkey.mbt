// 全局快捷键跨平台门面（W22：托盘 / 通知 / 热键三族门面统一的最后一族）。
//
// 形态对齐另两族（`core/tray.mbt` / `core/notify.mbt`）：
//   ① 探测函数 `hotkey_supported()`——不支持时调用方藏 UI，不把失败当成功；
//   ② 结构化错误 `HotkeyError{Unsupported, Failed(String)}`——绝不静默失效；
//   ③ 泵钩子 `hotkey_poll()`——宿主每帧/每拍调一次，命中给 `Hotkey`。
//
// 后端现状：**Windows 真实现**（`RegisterHotKey` + 线程队列，W20b 已交付并验证，
// 纯函数与探针见 `win/hotkey.mbt` / `experiment/…`）；**Linux X11 真实现**
// （`XGrabKey`，W22，GTK 桩的 wm_hotkey_* 三件套；Wayland 会话恒 Unsupported——
// XWayland 的抓键拿不到真全局性）；macOS 的 Carbon/AppKit 热键**未接**，一律
// `Err(Unsupported)`——这是「没做」而不是「失败」，与 tray 的 SNI 探测不到、
// notify 的 watcher 不在线同口径。
//
// 与 win 包的分工：解析（加速串 → mods/vk）与注册/轮询都在 win 包（那里有
// 平台纯函数与桩），本文件只做「跨平台同构的面」：字符串进出、错误统一、
// id→加速串回查（poll 只给 id，回显要查表）。

///|
/// 门面错误（与 `TrayError` / `NotifyError` 同构：不支持与失败分两档）。
pub(all) enum HotkeyError {
  /// 本平台没有后端（Linux Wayland 会话 / macOS 当前落点）
  Unsupported
  /// 有后端但这次没成（加速串解析不了 / 组合被占用 / 表满）
  Failed(String)
}

///|
pub impl Show for HotkeyError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("HotkeyError::Unsupported")
    Failed(msg) => {
      logger.write_string("HotkeyError::Failed(")
      logger.write_string(msg)
      logger.write_string(")")
    }
  }
}

///|
pub extend HotkeyError with Show::{to_string, output}

///|
/// 已注册的热键：`id` 是后端注册 id，`spec` 是注册时给的归一化加速串
/// （poll 命中后回查给调用方，避免调用方自己再持一张表）。
pub(all) struct Hotkey {
  id : Int
  spec : String
}

///|
/// 注册表：id → 加速串的进程级回查表（与 win 侧的注册表同生命周期：
/// 进程级、不退随窗口）。poll 命中的 id 若不在表内（非本门面注册的），
/// `spec` 给空串。
let hotkey_registry : Ref[Array[Hotkey]] = Ref([])

///|
/// 按 id 回查（本工具链的 Array 没有 find，手写循环；表很小，线性扫足够）。
fn hotkey_find(id : Int) -> Hotkey? {
  for h in hotkey_registry.val {
    if h.id == id {
      return Some(h)
    }
  }
  None
}

///|
/// 后端可用性：Windows 恒真；Linux 仅 X11 会话（探测交给 win 桩）；其余
/// 平台 false。注意与「这次注册成败」是两档——不支持时 `hotkey_register`
/// 给 `Err(Unsupported)`，支持但组合被占用给 `Err(Failed)`。
pub fn hotkey_supported() -> Bool {
  @win.hotkey_supported()
}

///|
/// 按加速串注册全局快捷键（进程级，与窗口无关）。
/// `spec` 形态照 win 的纯函数：`"Ctrl+Alt+F9"`、`"CmdOrCtrl+Shift+M"`
/// （`CmdOrCtrl` 在 Windows 映射 Ctrl、macOS 映射 Cmd）。
pub fn hotkey_register(spec : String) -> Result[Hotkey, HotkeyError] {
  if !hotkey_supported() {
    return Err(Unsupported)
  }
  let is_mac = @sys.sys_platform() == "macos"
  match @win.parse_accelerator(spec, is_mac) {
    None => Err(Failed("加速串无法解析：\{spec}"))
    Some(hk) =>
      match @win.register_global_shortcut(hk) {
        None => Err(Failed("注册失败（组合被占用或表满）：\{spec}"))
        Some(id) => {
          hotkey_registry.val.push({ id, spec })
          Ok({ id, spec })
        }
      }
  }
}

///|
/// 注销（幂等）：同时从回查表摘除。表里没有这个 id 也算成功——
/// 与 `unregister_global_shortcut` 的幂等语义一致。
pub fn hotkey_unregister(hk : Hotkey) -> Result[Unit, HotkeyError] {
  if !hotkey_supported() {
    return Err(Unsupported)
  }
  @win.unregister_global_shortcut(hk.id)
  hotkey_registry.val = hotkey_registry.val.filter(fn(h : Hotkey) -> Bool {
    h.id != hk.id
  })
  Ok(())
}

///|
/// 取一个已触发的快捷键；没有则 None。宿主每帧/每拍调用（Win32 的
/// WM_HOTKEY 进线程队列，靠泵里抽）。`spec` 为空串表示这个 id 不是经
/// 本门面注册的（回查表里没有）。
pub fn hotkey_poll() -> Hotkey? {
  match @win.poll_global_shortcut() {
    None => None
    Some(id) =>
      match hotkey_find(id) {
        None => Some({ id, spec: "" })
        Some(h) => Some(h)
      }
  }
}

///|
/// 回查已注册热键的加速串（菜单提示 / 状态行用）。
pub fn hotkey_spec_of(id : Int) -> String {
  match hotkey_find(id) {
    None => ""
    Some(h) => h.spec
  }
}

///|
/// 已注册数（状态行读数用）。
pub fn hotkey_registered_count() -> Int {
  hotkey_registry.val.length()
}
