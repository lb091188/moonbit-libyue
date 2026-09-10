// 私有 FFI 层：所有 extern 声明集中在此，仅 native 后端参与编译。
// 上层（app/window/label/tray）不得直接调用本文件中的函数。

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
extern "c" fn yue_mbt_app_init() -> Bool = "yue_mbt_app_init"

///|
extern "c" fn yue_mbt_run() -> Unit = "yue_mbt_run"

///|
extern "c" fn yue_mbt_quit() -> Unit = "yue_mbt_quit"

///|
/// 平台标识：0=linux 1=macos 2=windows。库内部分支用，不对外暴露。
extern "c" fn yue_mbt_platform() -> Int = "yue_mbt_platform"

///|
extern "c" fn yue_mbt_window_new() -> Window = "yue_mbt_window_new"

///|
#borrow(self)
extern "c" fn yue_mbt_window_set_content(
  self : Window,
  #borrow(content : Label),
) -> Unit = "yue_mbt_window_set_content"

///|
#borrow(self)
extern "c" fn yue_mbt_window_set_content_size(
  self : Window,
  width : Double,
  height : Double,
) -> Unit = "yue_mbt_window_set_content_size"

///|
#borrow(self)
extern "c" fn yue_mbt_window_center(self : Window) -> Unit = "yue_mbt_window_center"

///|
#borrow(self)
extern "c" fn yue_mbt_window_activate(self : Window) -> Unit = "yue_mbt_window_activate"

///|
/// 关闭回调 trampoline：invoke 由 C 调用，参数即 closure 指针。
/// closure 本体由 MoonBit 侧注册表保活（见 window.mbt），C 仅存指针、不持有引用计数，
/// 因此此处不用 #owned，C 侧也永不 decref。
#borrow(self)
extern "c" fn yue_mbt_window_on_close(
  self : Window,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  #borrow(callback : () -> Unit),
) -> Unit = "yue_mbt_window_on_close"

///|
extern "c" fn yue_mbt_label_new(
  #borrow(text : Bytes),
) -> Label = "yue_mbt_label_new"

///|
#borrow(self)
extern "c" fn yue_mbt_label_set_text(
  self : Label,
  #borrow(text : Bytes),
) -> Unit = "yue_mbt_label_set_text"

///|
/// 托盘后端可用性探测。Linux 上等价于检查 AppIndicator 运行库能否加载，
/// Windows/macOS 恒为 true。平台差异在此收敛，消费方只看统一接口。
extern "c" fn yue_mbt_tray_supported() -> Bool = "yue_mbt_tray_supported"

///|
/// 图标路径为 UTF-8。失败（后端缺失/图标读取失败）返回 None。
extern "c" fn yue_mbt_tray_new(
  #borrow(icon_path : Bytes),
) -> Tray? = "yue_mbt_tray_new"

///|
#borrow(self)
extern "c" fn yue_mbt_tray_set_title(
  self : Tray,
  #borrow(title : Bytes),
) -> Unit = "yue_mbt_tray_set_title"

///|
#borrow(self)
extern "c" fn yue_mbt_tray_remove(self : Tray) -> Unit = "yue_mbt_tray_remove"

///|
// String -> UTF-8 Bytes 的统一出口：MoonBit String 是 UTF-16，
// FFI 边界上一律转成 C 侧期望的 UTF-8，转换成本留在库内。
fn utf8_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
// UTF-8 Bytes -> String：C 侧返回字符串时的统一入口。
fn from_utf8_bytes(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes)
}
