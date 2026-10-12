// yue/win 的 extern 层：与 gtk_stub.c 逐位对齐（含参数个数）。
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
