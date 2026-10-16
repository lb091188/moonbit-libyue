// 文件打开/保存对话框（sys 线）：GTK 端在 `gui/win/stub.c` 的 GTK 分支
// （`wm_file_*` 前缀，句柄槽表与窗口桩同制），本层经 extern 直链——对话框要挂
// GTK 父窗口，桩归窗口侧编译（prebuild 静态库），sys 只做语义薄封装。
// run_for_window 的 parent 传 win 的窗口 id（0 = 无父窗口）。

///|
/// 对话框选项位（可组合）。
pub const FILE_OPTION_PICK_FOLDERS : Int = 1

///|
pub const FILE_OPTION_MULTI_SELECT : Int = 2

///|
pub const FILE_OPTION_SHOW_HIDDEN : Int = 4

///|
/// 文件对话框句柄（0 = 无效——建不出或已销毁）。
pub(all) struct FileDialog {
  id : Int64
}

///|
extern "c" fn ffi_file_open_dialog_new() -> Int64 = "wm_file_open_dialog_new"

///|
extern "c" fn ffi_file_save_dialog_new() -> Int64 = "wm_file_save_dialog_new"

///|
extern "c" fn ffi_file_dialog_set_options(id : Int64, options : Int) -> Unit = "wm_file_dialog_set_options"

///|
#borrow(filters)
extern "c" fn ffi_file_dialog_set_filters(id : Int64, filters : Bytes) -> Unit = "wm_file_dialog_set_filters"

///|
#borrow(folder)
extern "c" fn ffi_file_dialog_set_folder(id : Int64, folder : Bytes) -> Unit = "wm_file_dialog_set_folder"

///|
#borrow(filename)
extern "c" fn ffi_file_dialog_set_filename(id : Int64, filename : Bytes) -> Unit = "wm_file_dialog_set_filename"

///|
extern "c" fn ffi_file_dialog_run_for_window(id : Int64, parent : Int64) -> Int = "wm_file_dialog_run_for_window"

///|
extern "c" fn ffi_file_dialog_get_result(id : Int64) -> Bytes = "wm_file_dialog_get_result"

///|
extern "c" fn ffi_file_dialog_destroy(id : Int64) -> Unit = "wm_file_dialog_destroy"

///|
/// 创建打开对话框（选文件；PICK_FOLDERS 选项改选文件夹）。
pub fn FileDialog::new_open() -> FileDialog {
  { id: ffi_file_open_dialog_new() }
}

///|
/// 创建保存对话框。
pub fn FileDialog::new_save() -> FileDialog {
  { id: ffi_file_save_dialog_new() }
}

///|
/// 设置过滤器，格式 "描述:扩展1,扩展2|描述2:扩展3"（"*" 匹配全部）。
pub fn FileDialog::set_filters(self : FileDialog, filters : String) -> Unit {
  ffi_file_dialog_set_filters(self.id, @utf8.encode(filters))
}

///|
/// 设置选项位组合（如 FILE_OPTION_MULTI_SELECT | FILE_OPTION_SHOW_HIDDEN）。
pub fn FileDialog::set_options(self : FileDialog, options : Int) -> Unit {
  ffi_file_dialog_set_options(self.id, options)
}

///|
/// 设置初始目录（URI 或本地路径——转交 GTK 的 current_folder_uri）。
pub fn FileDialog::set_folder(self : FileDialog, folder : String) -> Unit {
  ffi_file_dialog_set_folder(self.id, @utf8.encode(folder))
}

///|
/// 设置初始文件名（保存对话框的默认名）。
pub fn FileDialog::set_filename(self : FileDialog, filename : String) -> Unit {
  ffi_file_dialog_set_filename(self.id, @utf8.encode(filename))
}

///|
/// 模态运行：parent 传 win 的窗口 id（0 = 无父窗口）；返回 true
/// 表示用户确认（GTK_RESPONSE_ACCEPT），取消/关闭为 false。
pub fn FileDialog::run_for_window(self : FileDialog, parent : Int64) -> Bool {
  ffi_file_dialog_run_for_window(self.id, parent) == 1
}

///|
/// 用户选中的本地路径（UTF-8，不做 URI 百分号编码；远端/回收站项与未确认
/// 都给空串）。
pub fn FileDialog::get_result(self : FileDialog) -> String {
  @utf8.decode_lossy(ffi_file_dialog_get_result(self.id))
}

///|
/// 关闭并释放对话框（run 之后调用；未 run 过也能安全释放）。
pub fn FileDialog::destroy(self : FileDialog) -> Unit {
  ffi_file_dialog_destroy(self.id)
}
