// 按钮。

///|
/// 按钮类型（对照 Button::Type；Disclosure 为 macOS 专属不暴露）。
pub(all) enum ButtonType {
  Normal
  Checkbox
  Radio
}

///|
/// 创建带标题的按钮。
pub fn Button::new(title : String) -> Button {
  { view: ffi_button_new(utf8_bytes(title)), }
}

///|
/// 创建指定类型的按钮（复选/单选）。
pub fn Button::new_of(button_type : ButtonType, title : String) -> Button {
  let id = match button_type {
    Normal => 0
    Checkbox => 1
    Radio => 2
  }
  { view: ffi_button_new_typed(utf8_bytes(title), id), }
}

///|
/// 选中态（复选/单选按钮）。
pub fn Button::set_checked(self : Button, checked : Bool) -> Unit {
  ffi_button_set_checked(self.view, if checked { 1 } else { 0 })
}

///|
pub fn Button::is_checked(self : Button) -> Bool {
  ffi_button_is_checked(self.view) == 1
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
  ffi_button_on_click(self.view, fn(f : () -> Unit) -> Unit { f() }, callback)
}

///|
/// 单行文本输入框。
pub fn Entry::new() -> Entry {
  { view: ffi_entry_new(), }
}

///|
/// 创建指定类型输入框（Password 为掩码显示）。
pub fn Entry::new_of(entry_type : EntryType) -> Entry {
  Entry::new_ex(entry_type, -1)
}

///|
/// 创建指定类型输入框并钉住首选宽度（width_chars，仅 Linux 有意义）：
/// GTK 主题的 entry 最小宽(GTK3 另有 150px 硬编码下限)大于窄容器给
/// Entry 的分配时,原生子窗口在构造期即以主题自然宽创建、横向溢出盖住
/// 相邻内容;构造期传入小 width_chars 把首选宽压到分配以内。其余平台
/// width_chars 被忽略。
pub fn Entry::new_ex(entry_type : EntryType, width_chars : Int) -> Entry {
  {
    view: ffi_entry_new_ex(
      match entry_type {
        Normal => 0
        Password => 1
      },
      width_chars,
    ),
  }
}

///|
/// 输入框类型（对照 Entry::Type）。
pub(all) enum EntryType {
  Normal
  Password
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

///|
/// 注册文本变化回调（每次输入触发）。
pub fn Entry::on_text_change(self : Entry, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_entry_on_text_change(
    self.view,
    fn(f : () -> Unit) -> Unit { f() },
    callback,
  )
}

///|
/// 注册回车激活回调（输入框内按 Enter）。
pub fn Entry::on_activate(self : Entry, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_entry_on_activate(self.view, fn(f : () -> Unit) -> Unit { f() }, callback)
}
