// 私有 FFI 层：所有 extern 声明集中在此，仅 native 后端参与编译。
// 上层（app/window/label/tray）不得直接调用本文件中的函数。
// 指针参数一律 #borrow：C 侧只在调用期访问；跨调保存的回调指针
// 由 MoonBit 侧注册表保活（见 window.mbt），不转移所有权。

///|
/// 句柄类型：C++ 侧持有 scoped_refptr 的外部对象，GC finalizer 负责释放。
/// 消费方永远接触不到裸指针。
type Window

///|
type Label

///|
type Tray

///|
/// 初始化 GUI 工具包（CommandLine + Lifetime + State）。
/// C ABI 中 bool 以 int32_t 传递。
extern "c" fn ffi_app_init() -> Bool = "yue_mbt_app_init"

///|
extern "c" fn ffi_run() -> Unit = "yue_mbt_run"

///|
extern "c" fn ffi_quit() -> Unit = "yue_mbt_quit"

///|
/// 平台标识：0=linux 1=macos 2=windows。库内部分支用，不对外暴露。
extern "c" fn ffi_platform() -> Int = "yue_mbt_platform"

///|
extern "c" fn ffi_window_new() -> Window = "yue_mbt_window_new"

///|
#borrow(window, content)
extern "c" fn ffi_window_set_content(window : Window, content : Label) -> Unit = "yue_mbt_window_set_content"

///|
#borrow(window)
extern "c" fn ffi_window_set_content_size(
  window : Window,
  width : Double,
  height : Double,
) -> Unit = "yue_mbt_window_set_content_size"

///|
#borrow(window)
extern "c" fn ffi_window_center(window : Window) -> Unit = "yue_mbt_window_center"

///|
#borrow(window)
extern "c" fn ffi_window_activate(window : Window) -> Unit = "yue_mbt_window_activate"

///|
/// 关闭回调 trampoline：invoke 由 C 调用，参数即 closure 指针。
#borrow(window, invoke, callback)
extern "c" fn ffi_window_on_close(
  window : Window,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  callback : () -> Unit,
) -> Unit = "yue_mbt_window_on_close"

///|
#borrow(text)
extern "c" fn ffi_label_new(text : Bytes) -> Label = "yue_mbt_label_new"

///|
#borrow(label, text)
extern "c" fn ffi_label_set_text(label : Label, text : Bytes) -> Unit = "yue_mbt_label_set_text"

///|
/// 托盘后端可用性探测。Linux 上等价于检查 AppIndicator 运行库能否加载，
/// Windows/macOS 恒为 true。平台差异在此收敛，消费方只看统一接口。
extern "c" fn ffi_tray_supported() -> Bool = "yue_mbt_tray_supported"

///|
/// 图标路径为 UTF-8。成败经 Ref[Int] 出参报告（1/0）——
/// extern 可空返回的 ABI 与 C 指针不兼容，句柄一律按非空返回。
#borrow(icon_path, ok)
extern "c" fn ffi_tray_new(icon_path : Bytes, ok : Ref[Int]) -> Tray = "yue_mbt_tray_new"

///|
#borrow(tray, title)
extern "c" fn ffi_tray_set_title(tray : Tray, title : Bytes) -> Unit = "yue_mbt_tray_set_title"

///|
#borrow(tray)
extern "c" fn ffi_tray_remove(tray : Tray) -> Unit = "yue_mbt_tray_remove"

///|
// String -> UTF-8 Bytes 的统一出口：MoonBit String 是 UTF-16，
// FFI 边界上一律转成 C 侧期望的 UTF-8，转换成本留在库内。
fn utf8_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}
