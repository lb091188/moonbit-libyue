// 文件打开/保存对话框。

///|
/// 创建打开对话框。
pub fn FileDialog::new_open() -> FileDialog {
  ffi_file_open_dialog_new()
}

///|
/// 创建保存对话框。
pub fn FileDialog::new_save() -> FileDialog {
  ffi_file_save_dialog_new()
}

///|
/// 设置过滤器，格式 "描述:扩展1,扩展2|描述2:扩展3"（"*" 匹配全部）。
pub fn FileDialog::set_filters(self : FileDialog, filters : String) -> Unit {
  ffi_file_dialog_set_filters(self, utf8_bytes(filters))
}

///|
/// 设置初始目录。
///|
/// 对话框选项位（对照 FileDialog::Option，可组合）。
pub const FILE_OPTION_PICK_FOLDERS : Int = 1

///|
pub const FILE_OPTION_MULTI_SELECT : Int = 2

///|
pub const FILE_OPTION_SHOW_HIDDEN : Int = 2 * 2

///|
/// 设置选项位组合（如 FILE_OPTION_MULTI_SELECT | FILE_OPTION_SHOW_HIDDEN）。
pub fn FileDialog::set_options(self : FileDialog, options : Int) -> Unit {
  ffi_file_dialog_set_options(self, options)
}

///|
pub fn FileDialog::set_folder(self : FileDialog, folder : String) -> Unit {
  ffi_file_dialog_set_folder(self, utf8_bytes(folder))
}

///|
/// 设置初始文件名。
pub fn FileDialog::set_filename(self : FileDialog, filename : String) -> Unit {
  ffi_file_dialog_set_filename(self, utf8_bytes(filename))
}

///|
/// 模态运行：返回 true 表示用户确认。
pub fn[T : ViewLike] FileDialog::run_for_window(self : FileDialog, window : T) -> Bool {
  ffi_file_dialog_run_for_window(self, window.view()) == 1
}

///|
/// 用户选中的路径。
pub fn FileDialog::get_result(self : FileDialog) -> String {
  from_utf8_bytes(ffi_file_dialog_get_result(self))
}

///|
/// 读二进制文件：成功返回原始字节，失败返回 None。
pub fn read_binary_file(path : String) -> Bytes? {
  let ok = Ref(0)
  let data = ffi_read_file(utf8_bytes(path), ok)
  if ok.val == 1 {
    Some(data)
  } else {
    None
  }
}

///|
/// 读文本文件：成功返回内容，失败返回 None。
pub fn read_text_file(path : String) -> String? {
  let ok = Ref(0)
  let data = ffi_read_file(utf8_bytes(path), ok)
  if ok.val == 1 {
    Some(from_utf8_bytes(data))
  } else {
    None
  }
}

///|
/// 写文本文件：返回是否成功。
pub fn write_text_file(path : String, content : String) -> Bool {
  let ok = Ref(0)
  let data = utf8_bytes(content)
  ffi_write_file(utf8_bytes(path), data, data.length(), ok)
  ok.val == 1
}
