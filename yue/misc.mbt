// 布局与系统交互：分组框 / 滚动视图 / 分隔线 / 剪贴板 / 消息框。

///|
/// 创建带标题的分组框。
pub fn Group::new(title : String) -> Group {
  { view: ffi_group_new(utf8_bytes(title)) }
}

///|
/// 设置分组框内容视图。
pub fn[T : ViewLike] Group::set_content(self : Group, content : T) -> Unit {
  ffi_group_set_content(self.view(), content.view())
}

///|
/// 更新分组标题。
pub fn Group::set_title(self : Group, title : String) -> Unit {
  ffi_group_set_title(self.view(), utf8_bytes(title))
}

///|
/// 方向。
pub(all) enum Orientation {
  Horizontal
  Vertical
}

///|
fn orientation_id(o : Orientation) -> Int {
  match o {
    Horizontal => 0
    Vertical => 1
  }
}

///|
/// 创建滚动视图。
pub fn Scroll::new() -> Scroll {
  { view: ffi_scroll_new() }
}

///|
/// 设置滚动内容视图。
pub fn[T : ViewLike] Scroll::set_content(self : Scroll, content : T) -> Unit {
  ffi_scroll_set_content(self.view(), content.view())
}

///|
/// 设置内容逻辑尺寸（超出可视区产生滚动）。
pub fn Scroll::set_content_size(self : Scroll, width : Double, height : Double) -> Unit {
  ffi_scroll_set_content_size(self.view(), width, height)
}

///|
/// 设置滚动位置。
pub fn Scroll::set_scroll_position(self : Scroll, horizon : Double, vertical : Double) -> Unit {
  ffi_scroll_set_scroll_position(self.view(), horizon, vertical)
}

///|
/// 是否使用覆盖式滚动条。
pub fn Scroll::set_overlay_scrollbar(self : Scroll, yes : Bool) -> Unit {
  ffi_scroll_set_overlay_scrollbar(self.view(), if yes { 1 } else { 0 })
}

///|
/// 创建分隔线。
pub fn Separator::new(orientation : Orientation) -> Separator {
  { view: ffi_separator_new(orientation_id(orientation)) }
}

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
pub fn Clipboard::clear(self : Clipboard) -> Unit {
  ffi_clipboard_clear(self)
}

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
pub fn MessageBox::set_informative_text(self : MessageBox, text : String) -> Unit {
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
pub fn[T : ViewLike] MessageBox::show_for_window(self : MessageBox, window : T) -> Unit {
  ffi_message_box_show_for_window(self, window.view())
}

///|
/// 关闭消息框。
pub fn MessageBox::close(self : MessageBox) -> Unit {
  ffi_message_box_close(self)
}
