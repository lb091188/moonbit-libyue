// 页签控件：多页内容切换（GTK 实现为 GtkNotebook）。

///|
/// 创建空页签控件。
pub fn Tab::new() -> Tab {
  { view: ffi_tab_new() }
}

///|
/// 追加一页（title 为页签标题，view 为页内容）。
pub fn[T : ViewLike] Tab::add_page(self : Tab, title : String, page : T) -> Unit {
  ffi_tab_add_page(self.view, utf8_bytes(title), page.view())
}

///|
/// 移除指定页。
pub fn[T : ViewLike] Tab::remove_page(self : Tab, page : T) -> Unit {
  ffi_tab_remove_page(self.view, page.view())
}

///|
/// 当前页数。
pub fn Tab::page_count(self : Tab) -> Int {
  ffi_tab_page_count(self.view)
}

///|
/// 切换到指定下标的页。
pub fn Tab::select_page_at(self : Tab, index : Int) -> Unit {
  ffi_tab_select_page_at(self.view, index)
}

///|
/// 当前选中页下标（无页为 -1）。
pub fn Tab::get_selected_page_index(self : Tab) -> Int {
  ffi_tab_selected_page_index(self.view)
}

///|
/// 注册页切换回调（点击页签或程序切换均触发）。
pub fn Tab::on_selected_page_change(self : Tab, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_tab_on_selected_page_change(self.view, fn(f : (() -> Unit)) -> Unit { f() }, callback)
}
