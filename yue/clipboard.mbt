// 剪贴板。

///|
/// 系统剪贴板（默认面板）。
pub fn Clipboard::get() -> Clipboard {
  ffi_clipboard_get()
}

///|
/// 写入文本到剪贴板。
pub fn Clipboard::set_text(self : Clipboard, text : String) -> Unit {
  ffi_clipboard_set_text(self, utf8_bytes(text))
}

///|
/// 读取剪贴板文本。
pub fn Clipboard::get_text(self : Clipboard) -> String {
  from_utf8_bytes(ffi_clipboard_get_text(self))
}

///|
/// 清空剪贴板。

///|
/// 写入一条数据（文本类：Text/Html/FilePaths，路径以 \n 连接）。
pub fn Clipboard::set_data(
  self : Clipboard,
  kind : DataKind,
  text : String,
) -> Unit {
  ffi_clipboard_set_data(self, data_kind_id(kind), utf8_bytes(text))
}

///|
/// 写入图片数据。
pub fn Clipboard::set_data_image(self : Clipboard, image : Image) -> Unit {
  ffi_clipboard_set_data_image(self, image)
}

///|
/// 读取指定种类数据（编码与拖拽数据一致）。
pub fn Clipboard::get_data(self : Clipboard, kind : DataKind) -> DragData? {
  decode_data(ffi_clipboard_get_data(self, data_kind_id(kind)))
}

///|
pub fn Clipboard::clear(self : Clipboard) -> Unit {
  ffi_clipboard_clear(self)
}
