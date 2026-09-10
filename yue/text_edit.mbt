// 多行文本编辑框。

///|
/// 创建文本编辑框。
pub fn TextEdit::new() -> TextEdit {
  { view: ffi_text_edit_new() }
}

///|
/// 设置文本内容。
pub fn TextEdit::set_text(self : TextEdit, text : String) -> Unit {
  ffi_text_edit_set_text(self.view, utf8_bytes(text))
}

///|
/// 读取文本内容。
pub fn TextEdit::get_text(self : TextEdit) -> String {
  from_utf8_bytes(ffi_text_edit_get_text(self.view))
}

///|
/// 当前文本包围盒高度（用于按内容自适应高度）。
pub fn TextEdit::get_text_bounds_height(self : TextEdit) -> Double {
  ffi_text_edit_get_text_bounds_height(self.view)
}

///|
/// 注册文本变化回调。
pub fn TextEdit::on_text_change(self : TextEdit, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_text_edit_on_text_change(self.view, fn(f : (() -> Unit)) -> Unit { f() }, callback)
}
