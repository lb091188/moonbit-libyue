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
