// 分组框。

///|
/// 创建带标题的分组框。
pub fn Group::new(title : String) -> Group {
  { view: ffi_group_new(utf8_bytes(title)), }
}

///|
/// 设置分组框内容视图。
pub fn[T : ViewLike] Group::set_content(self : Group, content : T) -> Unit {
  ffi_group_set_content(ViewLike::view(self), content.view())
}

///|
/// 更新分组标题。
pub fn Group::set_title(self : Group, title : String) -> Unit {
  ffi_group_set_title(ViewLike::view(self), utf8_bytes(title))
}
