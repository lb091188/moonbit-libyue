// 多行文本编辑框。

///|
/// 创建文本编辑框。
pub fn TextEdit::new() -> TextEdit {
  { view: ffi_text_edit_new(), }
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
  ffi_text_edit_on_text_change(
    self.view,
    fn(f : () -> Unit) -> Unit { f() },
    callback,
  )
}

///|
/// 是否可撤销。
pub fn TextEdit::can_undo(self : TextEdit) -> Bool {
  ffi_text_edit_can_undo(self.view) == 1
}

///|
/// 撤销一步。
pub fn TextEdit::undo(self : TextEdit) -> Unit {
  ffi_text_edit_undo(self.view)
}

///|
/// 是否可重做。
pub fn TextEdit::can_redo(self : TextEdit) -> Bool {
  ffi_text_edit_can_redo(self.view) == 1
}

///|
/// 重做一步。
pub fn TextEdit::redo(self : TextEdit) -> Unit {
  ffi_text_edit_redo(self.view)
}

///|
/// 剪切选中文本到剪贴板。
pub fn TextEdit::cut(self : TextEdit) -> Unit {
  ffi_text_edit_cut(self.view)
}

///|
/// 复制选中文本到剪贴板。
pub fn TextEdit::copy(self : TextEdit) -> Unit {
  ffi_text_edit_copy(self.view)
}

///|
/// 在光标处粘贴剪贴板文本。
pub fn TextEdit::paste(self : TextEdit) -> Unit {
  ffi_text_edit_paste(self.view)
}

///|
/// 全选。
pub fn TextEdit::select_all(self : TextEdit) -> Unit {
  ffi_text_edit_select_all(self.view)
}

///|
/// 选中 [start, end) 字符区间。
pub fn TextEdit::select_range(self : TextEdit, start : Int, end : Int) -> Unit {
  ffi_text_edit_select_range(self.view, start, end)
}

///|
/// 读取 [start, end) 字符区间内的文本。
pub fn TextEdit::get_text_in_range(
  self : TextEdit,
  start : Int,
  end : Int,
) -> String {
  from_utf8_bytes(ffi_text_edit_get_text_in_range(self.view, start, end))
}

///|
/// 在光标处插入文本。
pub fn TextEdit::insert_text(self : TextEdit, text : String) -> Unit {
  ffi_text_edit_insert_text(self.view, utf8_bytes(text))
}

///|
/// 在指定位置插入文本。
pub fn TextEdit::insert_text_at(
  self : TextEdit,
  text : String,
  pos : Int,
) -> Unit {
  ffi_text_edit_insert_text_at(self.view, utf8_bytes(text), pos)
}

///|
/// 删除当前选区（无选区时删除光标前一字符）。
pub fn TextEdit::delete(self : TextEdit) -> Unit {
  ffi_text_edit_delete(self.view)
}

///|
/// 删除 [start, end) 字符区间。
pub fn TextEdit::delete_range(self : TextEdit, start : Int, end : Int) -> Unit {
  ffi_text_edit_delete_range(self.view, start, end)
}
