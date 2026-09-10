// 按钮。

///|
/// 创建带标题的按钮。
pub fn Button::new(title : String) -> Button {
  { view: ffi_button_new(utf8_bytes(title)) }
}

///|
/// 更新按钮标题。
pub fn Button::set_title(self : Button, title : String) -> Unit {
  ffi_button_set_title(self.view, utf8_bytes(title))
}

///|
/// 注册点击回调。
pub fn Button::on_click(self : Button, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_button_on_click(self.view, fn(f : (() -> Unit)) -> Unit { f() }, callback)
}

///|
/// 单行文本输入框。
pub fn Entry::new() -> Entry {
  { view: ffi_entry_new() }
}

///|
/// 设置输入框文本。
pub fn Entry::set_text(self : Entry, text : String) -> Unit {
  ffi_entry_set_text(self.view, utf8_bytes(text))
}

///|
/// 读取输入框文本。
pub fn Entry::get_text(self : Entry) -> String {
  from_utf8_bytes(ffi_entry_get_text(self.view))
}
