// 静态文本标签。

///|
/// 创建指定文本的标签，文本编码由库内转换，消费方直接传 String。
pub fn Label::new(text : String) -> Label {
  ffi_label_new(utf8_bytes(text))
}

///|
/// 更新标签文本。
pub fn Label::set_text(self : Label, text : String) -> Unit {
  ffi_label_set_text(self, utf8_bytes(text))
}
