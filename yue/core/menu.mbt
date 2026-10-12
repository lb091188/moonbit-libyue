// 菜单模型（W20a）：顶栏菜单条 + 弹出菜单 + 菜单项。跨平台同构的**纯数据结构**
// ——本文件零 FFI，只描述「菜单长什么样」；平台后端（yue/win 的
// `wm_menu_bar_*`）负责把模型翻译成原生菜单（Win32 CreateMenu/AppendMenuW 或
// GTK GtkMenuBar）。这样三平台共用同一棵树的构建代码，差异只在翻译层。
//
// 结构：MenuBar ──加菜单──> Menu ──加项/子菜单──> MenuItem；Menu 可经
// `add_submenu` 无限嵌套。树用 `Array[MenuItem]` 承载同级项，项自身可带子菜单，
// 因此「遍历整棵树」是一个简单的递归（见 `Menu::walk`）。
//
// 与旧栈的差别：旧栈 MenuBar/Menu/MenuItem 是**不透明句柄**（#external，行为在
// C++），本模型是**可枚举的纯值**——好处是后端翻译前能先做纯函数校验/计数/序列化
// 测试（wbtest），且「模型 → 原生」是一次单向翻译，不需要为每个平台维护一套
// 平行的句柄表。

///|
/// 菜单项角色（编辑菜单免实现直接可用，跨平台行为一致）。`Normal` 是普通项，
/// 其余对应系统标准编辑动作——后端把它翻译成原生 role（macOS 有真 role，
/// Win32 退化为普通项 + 由宿主绑定的加速键）。
pub(all) enum MenuRole {
  Normal
  Copy
  Cut
  Paste
  SelectAll
  Undo
  Redo
  Quit
}

///|
/// 菜单项类型（决定原生侧的勾选/单选外观与行为）。
pub(all) enum MenuItemKind {
  /// 普通命令项
  Command
  /// 复选项（可勾选，`checked` 表示当前态）
  Check
  /// 单选项（同组内互斥）
  Radio
  /// 分隔线（无标签、无行为）
  Separator
}

///|
/// 一个菜单项：标签 + 类型 + 角色 + 可选加速键 + 勾选态 + 点击回调 + 子菜单。
/// 用 `mut` 字段支持构建后动态改（`set_label`/`set_checked`）——后端只在
/// `apply` 时读一次快照，改完需重新 apply 才生效（与「模型 → 原生」单向一致）。
pub(all) struct MenuItem {
  mut kind : MenuItemKind
  mut label : String
  role : MenuRole
  mut accelerator : String
  mut checked : Bool
  mut on_click : (() -> Unit)?
  /// 子菜单（Command/Check/Radio 可有；Separator 无）
  mut submenu : Menu?
  /// 后端翻译时回填的原生 id（模型侧不用，仅后端记账；0 = 未分配）
  mut native_id : Int
}

///|
/// 一个菜单（一组同级菜单项）。MenuBar 里是顶级下拉，Menu 里是子菜单。
pub(all) struct Menu {
  mut title : String
  mut items : Array[MenuItem]
}

///|
/// 顶栏菜单条：一组顶级菜单。挂到窗口用 `Window::set_menu_bar`。
pub(all) struct MenuBar {
  mut menus : Array[Menu]
}

///|
/// 建一个空菜单条。
pub fn MenuBar::new() -> MenuBar {
  { menus: [] }
}

///|
/// 在菜单条上追加一个顶级菜单（返回该菜单以便继续加项）。
pub fn MenuBar::add_menu(self : MenuBar, title : String) -> Menu {
  let m : Menu = { title, items: [] }
  self.menus.push(m)
  m
}

///|
/// 顶级菜单数量。
pub fn MenuBar::menu_count(self : MenuBar) -> Int {
  self.menus.length()
}

///|
/// 建一个独立菜单（可作子菜单，也可将来挂托盘右键菜单）。
pub fn Menu::new(title? : String = "") -> Menu {
  { title, items: [] }
}

///|
/// 加普通命令项。
pub fn Menu::add_item(self : Menu, label : String) -> MenuItem {
  let it : MenuItem = {
    kind: Command,
    label,
    role: Normal,
    accelerator: "",
    checked: false,
    on_click: None,
    submenu: None,
    native_id: 0,
  }
  self.items.push(it)
  it
}

///|
/// 加角色项（复制/剪切/退出等标准动作）。
pub fn Menu::add_role_item(self : Menu, role : MenuRole, label? : String = "") -> MenuItem {
  let it : MenuItem = {
    kind: Command,
    label: if label == "" { menu_role_default_label(role) } else { label },
    role,
    accelerator: menu_role_default_accelerator(role),
    checked: false,
    on_click: None,
    submenu: None,
    native_id: 0,
  }
  self.items.push(it)
  it
}

///|
/// 加复选项。
pub fn Menu::add_check_item(self : Menu, label : String) -> MenuItem {
  let it = self.add_item(label)
  it.kind = Check
  it
}

///|
/// 加单选项。
pub fn Menu::add_radio_item(self : Menu, label : String) -> MenuItem {
  let it = self.add_item(label)
  it.kind = Radio
  it
}

///|
/// 加分隔线。
pub fn Menu::add_separator(self : Menu) -> MenuItem {
  let it : MenuItem = {
    kind: Separator,
    label: "",
    role: Normal,
    accelerator: "",
    checked: false,
    on_click: None,
    submenu: None,
    native_id: 0,
  }
  self.items.push(it)
  it
}

///|
/// 加子菜单（嵌套）。
pub fn Menu::add_submenu(self : Menu, title : String) -> Menu {
  let sub = Menu::new(title~)
  let it : MenuItem = {
    kind: Command,
    label: title,
    role: Normal,
    accelerator: "",
    checked: false,
    on_click: None,
    submenu: Some(sub),
    native_id: 0,
  }
  self.items.push(it)
  sub
}

///|
/// 菜单项数量。
pub fn Menu::item_count(self : Menu) -> Int {
  self.items.length()
}

///|
/// 设标签（构建后改，需重新 apply 生效）。
pub fn MenuItem::set_label(self : MenuItem, label : String) -> Unit {
  self.label = label
}

///|
/// 设加速键（描述格式如 `"CmdOrCtrl+Q"`，后端翻译成原生加速键）。
pub fn MenuItem::set_accelerator(self : MenuItem, accelerator : String) -> Unit {
  self.accelerator = accelerator
}

///|
/// 设勾选态（复选/单选）。
pub fn MenuItem::set_checked(self : MenuItem, checked : Bool) -> Unit {
  self.checked = checked
}

///|
/// 是否勾选。
pub fn MenuItem::is_checked(self : MenuItem) -> Bool {
  self.checked
}

///|
/// 注册点击回调。
pub fn MenuItem::set_on_click(self : MenuItem, callback : () -> Unit) -> Unit {
  self.on_click = Some(callback)
}

///|
/// 该菜单项是否分隔线。
pub fn MenuItem::is_separator(self : MenuItem) -> Bool {
  match self.kind {
    Separator => true
    _ => false
  }
}

///|
/// 遍历菜单树（含自身与其所有子菜单），对每个项依次回调 `f`。纯函数，无副作用
/// 之外的东西——后端翻译前统计项数、wbtest 校验结构都走它。`depth` 是被访问项
/// 所在的层级（顶级菜单的项为 1，其子菜单的项为 2……）。
pub fn Menu::walk(self : Menu, f : (MenuItem, Int) -> Unit) -> Unit {
  menu_walk_into(self, 1, f)
}

///|
fn menu_walk_into(menu : Menu, depth : Int, f : (MenuItem, Int) -> Unit) -> Unit {
  for it in menu.items {
    f(it, depth)
    match it.submenu {
      Some(sub) => menu_walk_into(sub, depth + 1, f)
      None => ()
    }
  }
}

///|
/// 整棵树的项数（递归计；含分隔线）。
pub fn MenuBar::total_item_count(self : MenuBar) -> Int {
  let n = Ref(0)
  for m in self.menus {
    m.walk(fn(_it, _d) { n.val = n.val + 1 })
  }
  n.val
}

///|
/// 角色 → 默认标签（中文文案与旧栈口径一致：编辑菜单直接可用）。
pub fn menu_role_default_label(role : MenuRole) -> String {
  match role {
    Normal => ""
    Copy => "复制"
    Cut => "剪切"
    Paste => "粘贴"
    SelectAll => "全选"
    Undo => "撤销"
    Redo => "重做"
    Quit => "退出"
  }
}

///|
/// 角色 → 默认加速键（`CmdOrCtrl` 在 Win 映射 Ctrl、mac 映射 Cmd）。
pub fn menu_role_default_accelerator(role : MenuRole) -> String {
  match role {
    Normal => ""
    Copy => "CmdOrCtrl+C"
    Cut => "CmdOrCtrl+X"
    Paste => "CmdOrCtrl+V"
    SelectAll => "CmdOrCtrl+A"
    Undo => "CmdOrCtrl+Z"
    Redo => "CmdOrCtrl+Shift+Z"
    Quit => "CmdOrCtrl+Q"
  }
}

///|
/// 角色 → 数字编号（后端 FFI 传参用；与旧栈 `ffi_menu_add_role_item` 一致）。
pub fn menu_role_id(role : MenuRole) -> Int {
  match role {
    Normal => -1
    Copy => 0
    Cut => 1
    Paste => 2
    SelectAll => 3
    Undo => 4
    Redo => 5
    Quit => 6
  }
}

///|
/// 菜单项类型 → 数字编号（后端 FFI 传参用）。
pub fn menu_item_kind_id(kind : MenuItemKind) -> Int {
  match kind {
    Command => 0
    Check => 1
    Radio => 2
    Separator => 3
  }
}

// ------------------------- 翻译层：模型 → 原生 -----------------------------
// 「模型 → 原生」是一次单向翻译：把整棵树递归交给平台后端（yue/win 的
// wm_menu_* 入口），后端逐节点建原生菜单。命令 id 由后端分配、回填进
// `native_id`，宿主收到 `poll_menu_command` 的 id 后用本层注册的回调表按 id
// 找 `on_click`——C 侧不回调 MoonBit，仍是「泵里抽」那一套。
//
// 回调表归本层持有（模块级，随进程）：id → 回调。它不随窗口走，因为菜单本身
// 也挂在窗口上、随窗口销毁；重复 apply 会重建表（旧表随重建清空）。

///|
/// 命令 id → 回调的进程级注册表（翻译层用）。`build` 时填，宿主取 id 时查。
/// 用 Ref 包一层（与 host.mbt 的 g_* 同制——模块级可变状态在本工具链走 Ref）。
let menu_callbacks : Ref[Map[Int, () -> Unit]] = Ref(Map([]))

///|
/// 把一个菜单节点的项递归交给后端建（`handle` 是后端菜单句柄）。返回是否全部成功。
fn menu_translate_into(menu : Menu, handle : Int) -> Bool {
  let ok = Ref(true)
  for it in menu.items {
    let kind = menu_item_kind_id(it.kind)
    let acc = it.accelerator
    match it.submenu {
      Some(sub) => {
        // 子菜单：建一个子菜单句柄，递归填，然后……子菜单本身已是 parent 下
        // 的一个 MF_POPUP 项（wm_menu_new_sub 已挂好），无需再 add_item。
        let sub_handle = @win.menu_new_sub(handle, it.label)
        if sub_handle == 0 {
          ok.val = false
          continue
        }
        if !menu_translate_into(sub, sub_handle) {
          ok.val = false
        }
      }
      None => {
        let cmd = @win.menu_add_item(handle, it.label, kind, menu_role_id(it.role), acc, it.checked)
        if cmd > 0 {
          it.native_id = cmd
          match it.on_click {
            Some(cb) => menu_callbacks.val.set(cmd, cb)
            None => ()
          }
        } else if kind != 3 {
          // 可点击项没拿到 id：建失败
          ok.val = false
        }
      }
    }
  }
  ok.val
}

///|
/// 把菜单条翻译成原生菜单并挂到窗口；返回是否成功（后端不支持/建失败给 false，
/// 调用方据此走语义化降级）。翻译后各项 `native_id` 被回填，宿主用
/// `dispatch_menu_command` 按 id 派发。
pub fn MenuBar::apply_to(self : MenuBar, window : @win.Window) -> Bool {
  let handle = @win.menu_bar_new()
  if handle == 0 {
    return false
  }
  for m in self.menus {
    // 顶级菜单：建一个子菜单挂进菜单条（wm_menu_new_sub 对菜单条句柄同样适用）
    let sub = @win.menu_new_sub(handle, m.title)
    if sub == 0 {
      return false
    }
    if !menu_translate_into(m, sub) {
      return false
    }
  }
  @win.menu_apply(window.id, handle)
  true
}

///|
/// 宿主派发：取一个已触发的菜单命令 id，若有对应回调则执行，返回是否命中。
/// 宿主每拍调一次（Win32 的 WM_COMMAND 经 `@win.poll_menu_command` 抽）。
pub fn dispatch_menu_command() -> Bool {
  match @win.poll_menu_command() {
    Some(cmd) =>
      match menu_callbacks.val.get(cmd) {
        Some(cb) => {
          cb()
          true
        }
        None => false
      }
    None => false
  }
}
