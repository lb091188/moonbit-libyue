// 菜单：顶栏菜单条 + 弹出菜单 + 菜单项。
// 结构：MenuBar -add_menu(title)-> Menu -add_*_item-> MenuItem；
// Menu 可经 add_submenu 嵌套。

///|
/// 菜单项角色（编辑菜单免实现直接可用，跨平台行为一致）。
pub(all) enum MenuRole {
  Copy
  Cut
  Paste
  SelectAll
  Undo
  Redo
}

///|
/// 创建顶栏菜单条。
pub fn MenuBar::new() -> MenuBar {
  ffi_menu_bar_new()
}

///|
/// 创建独立弹出菜单（可挂托盘：Tray::set_menu）。
pub fn Menu::new() -> Menu {
  ffi_menu_new()
}

///|
/// 在屏幕坐标处弹出菜单（XFCE 等面板的托盘右键菜单由应用自绘）。
pub fn Menu::popup_at(self : Menu, x : Double, y : Double) -> Unit {
  ffi_menu_popup_at(self, x, y)
}

///|
/// 菜单项数量（MenuBase 遍历；托盘 SNI 后端按它桥接 DBusMenu）。
pub fn Menu::item_count(self : Menu) -> Int {
  ffi_menu_base_item_count(self)
}

///|
/// 取第 index 个菜单项（越界由 shim 拒绝并返回空句柄）。
pub fn Menu::item_at(self : Menu, index : Int) -> MenuItem {
  ffi_menu_base_item_at(self, index)
}

///|
/// 在顶栏添加标题菜单，返回该菜单（继续往里加项）。
pub fn MenuBar::add_menu(self : MenuBar, title : String) -> Menu {
  ffi_menu_bar_add_menu(self, utf8_bytes(title))
}

///|
/// 在菜单内嵌套子菜单，返回子菜单。
pub fn Menu::add_submenu(self : Menu, title : String) -> Menu {
  ffi_menu_add_submenu(self, utf8_bytes(title))
}

///|
/// 添加普通菜单项。
pub fn Menu::add_label_item(self : Menu, label : String) -> MenuItem {
  ffi_menu_add_label_item(self, utf8_bytes(label))
}

///|
/// 添加角色菜单项（复制/剪切等，无需自己实现行为）。
pub fn Menu::add_role_item(self : Menu, role : MenuRole) -> MenuItem {
  let role_id : Int = match role {
    Copy => 0
    Cut => 1
    Paste => 2
    SelectAll => 3
    Undo => 4
    Redo => 5
  }
  ffi_menu_add_role_item(self, role_id)
}

///|
/// 添加分隔线。
///|
/// 添加复选菜单项。
pub fn Menu::add_check_item(self : Menu, label : String) -> MenuItem {
  ffi_menu_add_check_item(self, utf8_bytes(label))
}

///|
/// 添加单选菜单项。
pub fn Menu::add_radio_item(self : Menu, label : String) -> MenuItem {
  ffi_menu_add_radio_item(self, utf8_bytes(label))
}

///|
/// 菜单项选中态（复选/单选项）。
pub fn MenuItem::set_checked(self : MenuItem, checked : Bool) -> Unit {
  ffi_menu_item_set_checked(self, if checked { 1 } else { 0 })
}

///|
pub fn MenuItem::is_checked(self : MenuItem) -> Bool {
  ffi_menu_item_is_checked(self) == 1
}

///|
pub fn Menu::add_separator(self : Menu) -> MenuItem {
  ffi_menu_add_separator(self)
}

///|
/// 更新菜单项文本。
///|
/// 读取菜单项文本。
pub fn MenuItem::get_label(self : MenuItem) -> String {
  let buf = Bytes::make(256, 0)
  let n = ffi_menu_item_get_label(self, buf, 256)
  if n < 0 {
    ""
  } else {
    from_utf8_bytes(buf[0:n].to_owned())
  }
}

///|
pub fn MenuItem::set_label(self : MenuItem, label : String) -> Unit {
  ffi_menu_item_set_label(self, utf8_bytes(label))
}

///|
/// 设置快捷键（描述格式与官方一致，如 "CmdOrCtrl+Q"）。
pub fn MenuItem::set_accelerator(self : MenuItem, accelerator : String) -> Unit {
  ffi_menu_item_set_accelerator(self, utf8_bytes(accelerator))
}

///|
/// 注册菜单项点击回调。
pub fn MenuItem::on_click(self : MenuItem, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_menu_item_on_click(self, fn(f : (() -> Unit)) -> Unit { f() }, callback)
}
///|
/// 菜单条顶级菜单数量。
pub fn MenuBar::item_count(self : MenuBar) -> Int {
  ffi_menubar_item_count(self)
}

///|
/// 取菜单条第 index 个菜单。
pub fn MenuBar::item_at(self : MenuBar, index : Int) -> MenuItem {
  ffi_menubar_item_at(self, index)
}
