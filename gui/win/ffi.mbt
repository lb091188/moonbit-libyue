// win 的 extern 层：与 gtk_stub.c 逐位对齐（含参数个数）。
// 约定照抄仓库既有形态：extern 私有、非原始参数标 #borrow、文本一律 Bytes、
// 出参用 Ref[Int]；C 侧不回调 MoonBit，事件用 wm_event 消费式取。

///|
extern "c" fn wm_init() -> Int = "wm_init"

///|
#borrow(title)
extern "c" fn wm_window_new(
  width : Int,
  height : Int,
  title : Bytes,
) -> Int64 = "wm_window_new"

///|
extern "c" fn wm_show(id : Int64) -> Unit = "wm_show"

///|
#borrow(out_w, out_h)
extern "c" fn wm_size(
  id : Int64,
  out_w : Ref[Int],
  out_h : Ref[Int],
) -> Unit = "wm_size"

///|
extern "c" fn wm_event(id : Int64) -> Int = "wm_event"

///|
/// 键盘焦点在谁身上：0 本窗无焦点 / 1 绘制区 / 2 本窗内的原生子件（webview）
extern "c" fn wm_focus_owner(id : Int64) -> Int = "wm_focus_owner"

///|
#borrow(rgba)
extern "c" fn wm_present(
  id : Int64,
  rgba : FixedArray[Byte],
  width : Int,
  height : Int,
) -> Unit = "wm_present"

///|
extern "c" fn wm_close(id : Int64) -> Unit = "wm_close"

///|
extern "c" fn wm_pump() -> Unit = "wm_pump"

///|
extern "c" fn wm_wait(timeout_ms : Int) -> Int = "wm_wait"

///|
extern "c" fn wm_wakeup() -> Unit = "wm_wakeup"

///|
extern "c" fn wm_now_ms() -> Int64 = "wm_now_ms"

///|
extern "c" fn wm_local_date() -> Int64 = "wm_local_date"

///|
extern "c" fn wm_take_event(id : Int64) -> Int = "wm_take_event"

///|
extern "c" fn wm_pending_events(id : Int64) -> Int = "wm_pending_events"

///|
extern "c" fn wm_ev_keysym(id : Int64) -> Int = "wm_ev_keysym"

///|
extern "c" fn wm_ev_mods(id : Int64) -> Int = "wm_ev_mods"

///|
extern "c" fn wm_ev_x(id : Int64) -> Int = "wm_ev_x"

///|
extern "c" fn wm_ev_y(id : Int64) -> Int = "wm_ev_y"

///|
extern "c" fn wm_ev_button(id : Int64) -> Int = "wm_ev_button"

///|
extern "c" fn wm_ev_axis(id : Int64) -> Int = "wm_ev_axis"

///|
extern "c" fn wm_request_focus(id : Int64) -> Unit = "wm_request_focus"

///|
#borrow(text)
extern "c" fn wm_im_set_surrounding(
  id : Int64,
  text : Bytes,
  caret : Int,
) -> Unit = "wm_im_set_surrounding"

///|
#borrow(out)
extern "c" fn wm_sys_color_scheme(
  out : Bytes,
  cap : Int,
) -> Int = "wm_sys_color_scheme"

///|
#borrow(out)
extern "c" fn wm_sys_accent(out : Bytes, cap : Int) -> Int = "wm_sys_accent"

///|
extern "c" fn wm_set_cursor(id : Int64, kind : Int) -> Unit = "wm_set_cursor"

///|
extern "c" fn wm_im_set_cursor(
  id : Int64,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Unit = "wm_im_set_cursor"

///|
extern "c" fn wm_im_reset(id : Int64) -> Unit = "wm_im_reset"

///|
extern "c" fn wm_im_commit_len(id : Int64) -> Int = "wm_im_commit_len"

///|
extern "c" fn wm_im_commit_byte(id : Int64, index : Int) -> Int = "wm_im_commit_byte"

///|
extern "c" fn wm_im_commit_done(id : Int64) -> Unit = "wm_im_commit_done"

///|
extern "c" fn wm_im_preedit_len(id : Int64) -> Int = "wm_im_preedit_len"

///|
extern "c" fn wm_im_preedit_byte(id : Int64, index : Int) -> Int = "wm_im_preedit_byte"

///|
extern "c" fn wm_im_preedit_caret(id : Int64) -> Int = "wm_im_preedit_caret"

///|
extern "c" fn wm_im_preedit_active(id : Int64) -> Int = "wm_im_preedit_active"

///|
extern "c" fn wm_surface_new(
  window_id : Int64,
  kind : Int,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Int64 = "wm_surface_new"

///|
extern "c" fn wm_surface_set_rect(
  id : Int64,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Unit = "wm_surface_set_rect"

///|
extern "c" fn wm_surface_close(id : Int64) -> Unit = "wm_surface_close"

///|
extern "c" fn wm_window_set_popup(
  id : Int64,
  owner : Int64,
) -> Unit = "wm_window_set_popup"

///|
extern "c" fn wm_window_move(id : Int64, x : Int, y : Int) -> Unit =
  "wm_window_move"

///|
extern "c" fn wm_window_set_size(id : Int64, w : Int, h : Int) -> Unit =
  "wm_window_set_size"

///|
extern "c" fn wm_window_set_fullscreen(id : Int64, on : Int) -> Unit =
  "wm_window_set_fullscreen"

///|
extern "c" fn wm_window_surface_count(id : Int64) -> Int =
  "wm_window_surface_count"

///|
#borrow(out_x, out_y)
extern "c" fn wm_window_origin(
  id : Int64,
  out_x : Ref[Int],
  out_y : Ref[Int],
) -> Unit = "wm_window_origin"

///|
extern "c" fn wm_hotkey_register(mods : Int, vk : Int) -> Int = "wm_hotkey_register"

///|
extern "c" fn wm_hotkey_unregister(id : Int) -> Unit = "wm_hotkey_unregister"

///|
extern "c" fn wm_hotkey_poll() -> Int = "wm_hotkey_poll"

///|
#borrow(title, text)
extern "c" fn wm_message_box(
  title : Bytes,
  text : Bytes,
  utype : Int,
) -> Int = "wm_message_box"

///|
extern "c" fn wm_menu_bar_new() -> Int = "wm_menu_bar_new"

///|
#borrow(title)
extern "c" fn wm_menu_new_sub(parent : Int, title : Bytes) -> Int = "wm_menu_new_sub"

///|
#borrow(label, acc)
extern "c" fn wm_menu_add_item(
  parent : Int,
  label : Bytes,
  kind : Int,
  role : Int,
  acc : Bytes,
  checked : Int,
) -> Int = "wm_menu_add_item"

///|
extern "c" fn wm_menu_apply(id : Int64, bar : Int) -> Unit = "wm_menu_apply"

///|
extern "c" fn wm_menu_poll() -> Int = "wm_menu_poll"

///|
#borrow(px)
extern "c" fn wm_icon_from_bgra(px : FixedArray[Byte], w : Int, h : Int) -> Int = "wm_icon_from_bgra"

///|
#borrow(path)
extern "c" fn wm_icon_load_file(path : Bytes, size : Int) -> Int = "wm_icon_load_file"

///|
#borrow(data)
extern "c" fn wm_icon_from_png(data : Bytes, len : Int) -> Int = "wm_icon_from_png"

///|
extern "c" fn wm_icon_free(slot : Int) -> Unit = "wm_icon_free"

///|
extern "c" fn wm_icon_alive() -> Int = "wm_icon_alive"

///|
#borrow(title)
extern "c" fn wm_set_title(id : Int64, title : Bytes) -> Unit = "wm_set_title"

///|
extern "c" fn wm_set_icon(id : Int64, icon_slot : Int, which : Int) -> Unit = "wm_set_icon"

///|
extern "c" fn wm_set_min_size(id : Int64, w : Int, h : Int) -> Unit = "wm_set_min_size"

///|
extern "c" fn wm_set_drag_rect(
  id : Int64,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Unit = "wm_set_drag_rect"

///|
extern "c" fn wm_set_borderless(id : Int64, on : Int) -> Unit = "wm_set_borderless"

///|
#borrow(out_w, out_h)
extern "c" fn wm_get_min_size(id : Int64, out_w : Ref[Int], out_h : Ref[Int]) -> Unit = "wm_get_min_size"

///|
#borrow(out_x, out_y, out_w, out_h)
extern "c" fn wm_get_drag_rect(
  id : Int64,
  out_x : Ref[Int],
  out_y : Ref[Int],
  out_w : Ref[Int],
  out_h : Ref[Int],
) -> Unit = "wm_get_drag_rect"

///|
extern "c" fn wm_is_borderless(id : Int64) -> Int = "wm_is_borderless"

///|
#borrow(out)
extern "c" fn wm_window_title(id : Int64, out : Bytes, cap : Int) -> Int = "wm_window_title"

///|
extern "c" fn wm_tray_supported() -> Int = "wm_tray_supported"

///|
#borrow(tip)
extern "c" fn wm_tray_new(icon_slot : Int, tip : Bytes) -> Int = "wm_tray_new"

///|
#borrow(tip)
extern "c" fn wm_tray_set_tooltip(slot : Int, tip : Bytes) -> Unit =
  "wm_tray_set_tooltip"

///|
extern "c" fn wm_tray_set_icon(slot : Int, icon_slot : Int) -> Unit =
  "wm_tray_set_icon"

///|
extern "c" fn wm_tray_set_menu(slot : Int, menu_handle : Int) -> Unit =
  "wm_tray_set_menu"

///|
extern "c" fn wm_tray_popup(slot : Int) -> Int = "wm_tray_popup"

///|
extern "c" fn wm_tray_remove(slot : Int) -> Unit = "wm_tray_remove"

///|
#borrow(out_slot, out_kind)
extern "c" fn wm_tray_poll(
  out_slot : Ref[Int],
  out_kind : Ref[Int],
) -> Int = "wm_tray_poll"

///|
extern "c" fn wm_tray_count() -> Int = "wm_tray_count"

///|
#borrow(out)
extern "c" fn wm_tray_tooltip(slot : Int, out : Bytes, cap : Int) -> Int =
  "wm_tray_tooltip"

///|
extern "c" fn wm_dragdnd_supported() -> Int = "wm_dragdnd_supported"

///|
extern "c" fn wm_dragdnd_enable(id : Int64) -> Int = "wm_dragdnd_enable"

///|
extern "c" fn wm_dragdnd_disable(id : Int64) -> Unit = "wm_dragdnd_disable"

///|
#borrow(out_slot, out_kind, out_x, out_y)
extern "c" fn wm_dragdnd_poll(
  out_slot : Ref[Int],
  out_kind : Ref[Int],
  out_x : Ref[Int],
  out_y : Ref[Int],
) -> Int = "wm_dragdnd_poll"

///|
#borrow(out)
extern "c" fn wm_dragdnd_payload(out : Bytes, cap : Int) -> Int =
  "wm_dragdnd_payload"

///|
extern "c" fn wm_dragdnd_set_effect(id : Int64, effect : Int) -> Unit =
  "wm_dragdnd_set_effect"

///|
extern "c" fn wm_dragdnd_effect(id : Int64) -> Int = "wm_dragdnd_effect"

///|
extern "c" fn wm_dragdnd_count() -> Int = "wm_dragdnd_count"

///|
extern "c" fn wm_menu_popup_new() -> Int = "wm_menu_popup_new"

///|
extern "c" fn wm_notify_supported() -> Int = "wm_notify_supported"

///|
#borrow(title, text)
extern "c" fn wm_notify_send(
  icon_slot : Int,
  title : Bytes,
  text : Bytes,
  kind : Int,
) -> Int = "wm_notify_send"

///|
#borrow(title, text)
extern "c" fn wm_notify_update(
  slot : Int,
  title : Bytes,
  text : Bytes,
  kind : Int,
) -> Int = "wm_notify_update"

///|
extern "c" fn wm_notify_close(slot : Int) -> Unit = "wm_notify_close"

///|
extern "c" fn wm_notify_count() -> Int = "wm_notify_count"

///|
#borrow(out)
extern "c" fn wm_notify_title(slot : Int, out : Bytes, cap : Int) -> Int =
  "wm_notify_title"

///|
/// 任务栏进度后端可用性（§6.3）：Windows 恒 1（COM 起不来才 0），
/// 其余平台 0。
extern "c" fn wm_taskbar_supported() -> Int = "wm_taskbar_supported"

///|
/// 设任务栏按钮进度：`value`/`total` 原样透传（Win32 侧 ULONGLONG）。
/// 返回 1 成功；后端不可用 / 窗口句柄无效给 0。
extern "c" fn wm_taskbar_set_progress(
  id : Int64,
  value : Int64,
  total : Int64,
) -> Int = "wm_taskbar_set_progress"

///|
/// 设任务栏按钮状态：`state` 编号见 taskbar.mbt 的 `taskbar_state_id`
/// （0 无进度 / 1 正常 / 2 错误 / 3 暂停 / 4 不确定）。返回 1 成功。
extern "c" fn wm_taskbar_set_state(id : Int64, state : Int) -> Int =
  "wm_taskbar_set_state"

///|
/// 实现在 win_gui.c（该文件带 GUI 子系统链接 pragma）：由 `init_backend()`
/// 引用，保证那份归档成员被链接器抽取、pragma 才会生效——纯 pragma 的 TU
/// 没有符号引用就会被整体忽略。返回值无意义，只作「被引用」的锚点。
extern "c" fn wm_win_gui_marker() -> Int = "wm_win_gui_marker"
