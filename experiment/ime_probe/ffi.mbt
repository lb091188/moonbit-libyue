// G0 探针的 extern 层：与 ime_probe_stub.c 逐位对齐（含参数个数），
// 只做声明不做包装。约定照抄仓库既有形态：extern 私有、非原始参数标
// #borrow、文本一律 Bytes（utf8 字节）、C 回传用 moonbit_make_bytes 构造。

///|
#borrow(invoke, closure)
extern "c" fn ip_on_key(
  invoke : FuncRef[((Int, Int, Int, Int) -> Unit, Int, Int, Int, Int) -> Unit],
  closure : (Int, Int, Int, Int) -> Unit,
) -> Unit = "ip_on_key"

///|
#borrow(invoke, closure)
extern "c" fn ip_on_commit(
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  closure : (Bytes) -> Unit,
) -> Unit = "ip_on_commit"

///|
#borrow(invoke, closure)
extern "c" fn ip_on_preedit(
  invoke : FuncRef[((Bytes, Int, Int) -> Unit, Bytes, Int, Int) -> Unit],
  closure : (Bytes, Int, Int) -> Unit,
) -> Unit = "ip_on_preedit"

///|
#borrow(invoke, closure)
extern "c" fn ip_on_note(
  invoke : FuncRef[((Bytes, Bytes) -> Unit, Bytes, Bytes) -> Unit],
  closure : (Bytes, Bytes) -> Unit,
) -> Unit = "ip_on_note"

///|
#borrow(text)
extern "c" fn ip_set_surrounding(
  text : Bytes,
  len : Int,
  cursor_bytes : Int,
) -> Unit = "ip_set_surrounding"

///|
extern "c" fn ip_init(mode : Int) -> Int = "ip_init"

///|
extern "c" fn ip_iterate(blocking : Int) -> Int = "ip_iterate"

///|
extern "c" fn ip_should_quit() -> Int = "ip_should_quit"

///|
extern "c" fn ip_now_ms() -> Int64 = "ip_now_ms"

///|
extern "c" fn ip_counter(idx : Int) -> Int = "ip_counter"

///|
#borrow(text)
extern "c" fn ip_set_display(text : Bytes, len : Int, caret_byte : Int) -> Unit = "ip_set_display"

///|
extern "c" fn ip_set_cursor_rect(x : Int, y : Int, w : Int, h : Int) -> Unit = "ip_set_cursor_rect"

///|
#borrow(text)
extern "c" fn ip_measure(text : Bytes, len : Int) -> Double = "ip_measure"

///|
extern "c" fn ip_line_height() -> Double = "ip_line_height"

///|
#borrow(css)
extern "c" fn ip_apply_css(css : Bytes, len : Int) -> Int = "ip_apply_css"

///|
extern "c" fn ip_report_im_module() -> Unit = "ip_report_im_module"
