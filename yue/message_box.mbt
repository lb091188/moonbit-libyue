// 消息框。

///|
/// 消息框类型。
pub(all) enum MessageBoxType {
  None
  Information
  Warning
  Error
}

///|
fn message_box_type_id(t : MessageBoxType) -> Int {
  match t {
    None => 0
    Information => 1
    Warning => 2
    Error => 3
  }
}

///|
/// 创建消息框。
pub fn MessageBox::new(type_ : MessageBoxType) -> MessageBox {
  ffi_message_box_new(message_box_type_id(type_))
}

///|
/// 设置标题。
pub fn MessageBox::set_title(self : MessageBox, title : String) -> Unit {
  ffi_message_box_set_title(self, utf8_bytes(title))
}

///|
/// 设置主文本。
pub fn MessageBox::set_text(self : MessageBox, text : String) -> Unit {
  ffi_message_box_set_text(self, utf8_bytes(text))
}

///|
/// 设置补充说明文本。
pub fn MessageBox::set_informative_text(
  self : MessageBox,
  text : String,
) -> Unit {
  ffi_message_box_set_informative_text(self, utf8_bytes(text))
}

///|
/// 添加按钮（response 为按钮编号，回调原样返回）。
pub fn MessageBox::add_button(
  self : MessageBox,
  title : String,
  response : Int,
) -> Unit {
  ffi_message_box_add_button(self, utf8_bytes(title), response)
}

///|
/// 注册按钮响应回调（response 为被点按钮编号）。
pub fn MessageBox::on_response(
  self : MessageBox,
  callback : (Int) -> Unit,
) -> Unit {
  let wrapped : (Int) -> Unit = fn(response) { callback(response) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_message_box_on_response(self, fn(f, response) { f(response) }, wrapped)
}

///|
/// 显示（独立窗口）。
pub fn MessageBox::show(self : MessageBox) -> Unit {
  ffi_message_box_show(self)
}

///|
/// 以模态方式挂在指定窗口显示。
pub fn[T : ViewLike] MessageBox::show_for_window(
  self : MessageBox,
  window : T,
) -> Unit {
  ffi_message_box_show_for_window(self, window.view())
}

///|
/// 关闭消息框。
pub fn MessageBox::close(self : MessageBox) -> Unit {
  ffi_message_box_close(self)
}
