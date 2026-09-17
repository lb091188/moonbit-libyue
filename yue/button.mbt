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
  {
    view: ffi_entry_new_typed(
      match entry_type {
        Normal => 0
        Password => 1
      },
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

///|
/// 挂接原生自动补全：输入时按候选过滤弹出原生气泡，点选/回车选中后
/// 回填文本并触发 on_pick。仅 Linux 有原生实现（弹层由 GTK 托管，
/// 不抢键盘焦点），其余平台空操作，由调用方按平台降级。
pub fn Entry::set_completion(
  self : Entry,
  options : Array[String],
  on_pick : (String) -> Unit,
) -> Unit {
  // 候选串经 \x1F(ASCII 单元分隔符)连接过 ABI,正常文本不会含此字节
  let mut joined = ""
  for i, opt in options {
    if i > 0 {
      joined = joined + "\u{1f}"
    }
    joined = joined + opt
  }
  let wrapped : (Bytes) -> Unit = fn(s) { on_pick(from_utf8_bytes(s)) }
  keep_alive_bytes(wrapped)
  ffi_entry_set_completion(
    self.view,
    utf8_bytes(joined),
    fn(f : (Bytes) -> Unit, s : Bytes) -> Unit { f(s) },
    wrapped,
  )
}
