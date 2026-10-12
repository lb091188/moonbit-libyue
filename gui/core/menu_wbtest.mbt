// W20a 菜单模型回归：纯数据结构的构建与遍历（零 FFI、零后端）。后端翻译
// （模型 → Win32 CreateMenu / GTK GtkMenuBar）在桩层，本测试只锁「树长什么样」
// ——项数、层级、角色默认值、勾选态可变。这些若有错，后端翻译得再对也白搭。

///|
test "MenuBar/建条与加菜单" {
  let bar = MenuBar::new()
  inspect(bar.menu_count(), content="0")
  let _f = bar.add_menu("文件")
  let _e = bar.add_menu("编辑")
  inspect(bar.menu_count(), content="2")
}

///|
fn kind_id(k : MenuItemKind) -> Int {
  match k {
    Command => 0
    Check => 1
    Radio => 2
    Separator => 3
  }
}

///|
test "Menu/加各类项与计数" {
  let m = Menu::new()
  let _a = m.add_item("新建")
  let _b = m.add_check_item("自动保存")
  let _c = m.add_radio_item("浅色")
  let _d = m.add_separator()
  inspect(m.item_count(), content="4")
  inspect(m.items[0].is_separator(), content="false")
  inspect(m.items[3].is_separator(), content="true")
  inspect(kind_id(m.items[1].kind), content="1")
}

///|
test "Menu/项类型编号" {
  let m = Menu::new()
  let _a = m.add_item("命令")
  let _b = m.add_check_item("复选")
  let _c = m.add_radio_item("单选")
  let _d = m.add_separator()
  inspect(kind_id(m.items[0].kind), content="0")
  inspect(kind_id(m.items[1].kind), content="1")
  inspect(kind_id(m.items[2].kind), content="2")
  inspect(kind_id(m.items[3].kind), content="3")
}

///|
test "Menu/子菜单嵌套与遍历层级" {
  let m = Menu::new()
  let _a = m.add_item("顶级项")
  let sub = m.add_submenu("更多")
  let _b = sub.add_item("子项一")
  let _c = sub.add_item("子项二")
  inspect(m.item_count(), content="2") // 顶级项 + 子菜单挂点
  inspect(sub.item_count(), content="2")
  // 遍历：depth 1 有 2 项，depth 2 有 2 项
  let d1 = Ref(0)
  let d2 = Ref(0)
  m.walk(fn(_it, d) {
    if d == 1 {
      d1.val = d1.val + 1
    } else if d == 2 {
      d2.val = d2.val + 1
    }
  })
  inspect(d1.val, content="2")
  inspect(d2.val, content="2")
}

///|
test "MenuBar/整树项数递归计" {
  let bar = MenuBar::new()
  let file = bar.add_menu("文件")
  let _ = file.add_item("新建")
  let _ = file.add_item("打开")
  let edit = bar.add_menu("编辑")
  let _ = edit.add_role_item(Copy)
  let sub = edit.add_submenu("高级")
  let _ = sub.add_item("设置")
  // 文件 2 + 编辑 2（Copy 项 + 子菜单挂点）+ 高级 1 = 5
  inspect(bar.total_item_count(), content="5")
}

///|
test "Menu/角色项默认标签与加速键" {
  let m = Menu::new()
  let c = m.add_role_item(Copy)
  inspect(c.label, content="复制")
  inspect(c.accelerator, content="CmdOrCtrl+C")
  let q = m.add_role_item(Quit)
  inspect(q.label, content="退出")
  inspect(q.accelerator, content="CmdOrCtrl+Q")
  // 显式标签覆盖默认
  let c2 = m.add_role_item(Cut, label="剪切到剪贴板")
  inspect(c2.label, content="剪切到剪贴板")
}

///|
test "Menu/角色默认表全量" {
  inspect(menu_role_default_label(Copy), content="复制")
  inspect(menu_role_default_label(Cut), content="剪切")
  inspect(menu_role_default_label(Paste), content="粘贴")
  inspect(menu_role_default_label(SelectAll), content="全选")
  inspect(menu_role_default_label(Undo), content="撤销")
  inspect(menu_role_default_label(Redo), content="重做")
  inspect(menu_role_default_label(Quit), content="退出")
  inspect(menu_role_default_label(Normal), content="")
  inspect(menu_role_default_accelerator(Paste), content="CmdOrCtrl+V")
  inspect(menu_role_default_accelerator(Redo), content="CmdOrCtrl+Shift+Z")
  inspect(menu_role_default_accelerator(Normal), content="")
}

///|
test "Menu/角色编号映射" {
  inspect(menu_role_id(Normal), content="-1")
  inspect(menu_role_id(Copy), content="0")
  inspect(menu_role_id(Cut), content="1")
  inspect(menu_role_id(Paste), content="2")
  inspect(menu_role_id(SelectAll), content="3")
  inspect(menu_role_id(Undo), content="4")
  inspect(menu_role_id(Redo), content="5")
  inspect(menu_role_id(Quit), content="6")
}

///|
test "MenuItem/set_label 与 set_checked 可变" {
  let m = Menu::new()
  let it = m.add_check_item("自动保存")
  inspect(it.is_checked(), content="false")
  it.set_checked(true)
  inspect(it.is_checked(), content="true")
  it.set_label("保存草稿")
  inspect(it.label, content="保存草稿")
  it.set_accelerator("CmdOrCtrl+S")
  inspect(it.accelerator, content="CmdOrCtrl+S")
}

///|
test "MenuItem/set_on_click 回填回调槽" {
  let m = Menu::new()
  let it = m.add_item("点我")
  let hits = Ref(0)
  it.set_on_click(fn() { hits.val = hits.val + 1 })
  match it.on_click {
    Some(f) => f()
    None => ()
  }
  inspect(hits.val, content="1")
}
