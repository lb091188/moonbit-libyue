// W20a 菜单模型探针：纯数据结构的构建与遍历读数（零 FFI、零后端）。
// 与 yue/core/menu_wbtest.mbt 的断言同源，这里打印成可肉眼对照的读数——
// 用于「本机 moon 起不来时也能验证模型正确」的环境限制兜底（见 memory 记录）。
//
// 跑法：moon run experiment/menu_probe

///|
fn kind_id(k : @core.MenuItemKind) -> Int {
  match k {
    Command => 0
    Check => 1
    Radio => 2
    Separator => 3
  }
}

///|
fn role_id(r : @core.MenuRole) -> Int {
  @core.menu_role_id(r)
}

fn main {
  // ① 建条 + 加菜单
  let bar = @core.MenuBar::new()
  let _file = bar.add_menu("文件")
  let edit = bar.add_menu("编辑")
  println("MENU bar_menus=\{bar.menu_count()}")

  // ② 各类项 + 计数
  let file2 = @core.Menu::new(title="文件")
  let _a = file2.add_item("新建")
  let _b = file2.add_check_item("自动保存")
  let _c = file2.add_radio_item("浅色")
  let _d = file2.add_separator()
  println("MENU file_items=\{file2.item_count()}")
  println("MENU kinds=\{kind_id(file2.items[0].kind)},\{kind_id(file2.items[1].kind)},\{kind_id(file2.items[2].kind)},\{kind_id(file2.items[3].kind)}")
  println("MENU sep0=\{file2.items[0].is_separator()} sep3=\{file2.items[3].is_separator()}")

  // ③ 子菜单嵌套 + 遍历层级
  let sub = file2.add_submenu("更多")
  let _e = sub.add_item("子项一")
  let _f = sub.add_item("子项二")
  let d1 = Ref(0)
  let d2 = Ref(0)
  file2.walk(fn(_it, d) {
    if d == 1 {
      d1.val = d1.val + 1
    } else if d == 2 {
      d2.val = d2.val + 1
    }
  })
  println("MENU walk depth1=\{d1.val} depth2=\{d2.val}")

  // ④ 角色项默认标签/加速键/编号
  let _rc = edit.add_role_item(@core.Copy)
  let c = edit.items[0]
  println("MENU role copy label=\{c.label} acc=\{c.accelerator} id=\{role_id(@core.Copy)}")
  let q = edit.add_role_item(@core.Quit)
  println("MENU role quit label=\{q.label} acc=\{q.accelerator} id=\{role_id(@core.Quit)}")

  // ⑤ 整树项数
  println("MENU total_items=\{bar.total_item_count()}")
  // bar: 文件 0 项 + 编辑 2 项 = 2（file2 是独立 Menu，不在 bar 里）
  let bar2 = @core.MenuBar::new()
  let f = bar2.add_menu("文件")
  let _ = f.add_item("新建")
  let _ = f.add_item("打开")
  let ed = bar2.add_menu("编辑")
  let _ = ed.add_role_item(@core.Copy)
  let s = ed.add_submenu("高级")
  let _ = s.add_item("设置")
  println("MENU bar2 total=\{bar2.total_item_count()} (预期 5)")

  // ⑥ 可变字段
  let it = file2.items[1]
  it.set_checked(true)
  it.set_label("保存草稿")
  it.set_accelerator("CmdOrCtrl+S")
  println("MENU mut checked=\{it.is_checked()} label=\{it.label} acc=\{it.accelerator}")

  // ⑦ 回调槽
  let m = @core.Menu::new(title="测试")
  let clickable = m.add_item("点我")
  let hits = Ref(0)
  clickable.set_on_click(fn() { hits.val = hits.val + 1 })
  match clickable.on_click {
    Some(f) => f()
    None => ()
  }
  println("MENU click_hits=\{hits.val}")
  println("MENU-OK")
}
