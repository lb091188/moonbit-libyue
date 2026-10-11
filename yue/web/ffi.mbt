// yue/web 的 extern 层：与 webkit_stub.c 逐位对齐（含参数个数）。
// 约定照抄仓库既有形态：extern 私有、文本一律 Bytes（`@utf8.encode` 带尾零）、
// C 侧不回调 MoonBit，字符串用「C 写缓冲 + MoonBit 读」的形态取。

///|
extern "c" fn wb_available() -> Int = "wb_available"

///|
#borrow(uri)
extern "c" fn wb_create(
  surface_id : Int64,
  w : Int,
  h : Int,
  uri : Bytes,
) -> Int64 = "wb_create"

///|
#borrow(uri)
extern "c" fn wb_load_uri(id : Int64, uri : Bytes) -> Unit = "wb_load_uri"

///|
extern "c" fn wb_reload(id : Int64) -> Unit = "wb_reload"

///|
extern "c" fn wb_stop(id : Int64) -> Unit = "wb_stop"

///|
extern "c" fn wb_is_loading(id : Int64) -> Int = "wb_is_loading"

///|
#borrow(out)
extern "c" fn wb_uri(id : Int64, out : Bytes, cap : Int) -> Int = "wb_uri"

///|
#borrow(out)
extern "c" fn wb_title(id : Int64, out : Bytes, cap : Int) -> Int = "wb_title"

///|
extern "c" fn wb_set_size(id : Int64, w : Int, h : Int) -> Unit = "wb_set_size"

///|
extern "c" fn wb_destroy(id : Int64) -> Unit = "wb_destroy"
