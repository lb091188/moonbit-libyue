// W20c 托盘门面回归：纯函数部分（文件名 → 托盘 Id、桌面环境名、错误 Show）。
// 后端可用性与回调消息落点归 experiment/tray_probe（纯 C 探针直喂 wm_tray_*），
// 这里的 wbtest 不碰真托盘——那会往用户的系统通知区插图标。

///|
test "basename_no_ext：常见路径" {
  inspect(basename_no_ext("icon.png"), content="icon")
  inspect(basename_no_ext("/usr/share/pixmaps/app.png"), content="app")
  inspect(basename_no_ext("tray.ico"), content="tray")
  inspect(basename_no_ext("noext"), content="noext")
}

///|
test "basename_no_ext：Windows 反斜杠路径" {
  inspect(basename_no_ext("C:\\dir\\icon.ico"), content="icon")
  inspect(basename_no_ext("C:\\a.b\\c\\icon.png"), content="icon")
}

///|
test "basename_no_ext：目录名里的点不算扩展名" {
  // 末段是目录名时，其内的点不该被当扩展名分隔
  inspect(basename_no_ext("a.b/c"), content="c")
  inspect(basename_no_ext("/x.y/z/noext"), content="noext")
  // 反斜杠末段的点同理
  inspect(basename_no_ext("x.y\\win"), content="win")
}

///|
test "basename_no_ext：空串与尾点" {
  inspect(basename_no_ext(""), content="")
  inspect(basename_no_ext("foo."), content="foo")
  // 多重点只切最后一个
  inspect(basename_no_ext("a.tar.gz"), content="a.tar")
}

///|
test "desktop_environment 给非空串（认不出为 unknown）" {
  let name = desktop_environment()
  assert_true(name.length() > 0)
}

///|
test "TrayError 的 Show 三种变体" {
  assert_eq(TrayError::Unsupported.to_string(), "TrayError::Unsupported")
  assert_eq(TrayError::IconLoadFailed.to_string(), "TrayError::IconLoadFailed")
  assert_true(TrayError::Backend("槽表满").to_string().contains("槽表满"))
}

///|
test "Tray 生命周期（无托盘后端的机器自动跳过）" {
  // 这条会真的往系统通知区插一次图标再摘掉（建→摘在同一拍内完成）。无托盘
  // 后端的环境（无显示服务 / Linux watcher 不在线）跳过而非造假——探测即口径。
  if !Tray::is_supported() {
    println("skip: 本机没有可用的托盘后端")
  } else {
    match Tray::new("libyue-wbtest") {
      Err(e) => println("skip: 建托盘失败(\{e})")
      Ok(t) => {
        // Win32 后端应拿到槽号；SNI 后端没槽号，跳过槽号断言
        let slot = match t.backend() {
          Native(s) => s
          Sni(_) => 0
        }
        if slot >= 1 {
          assert_eq(t.backend_name(), "native")
          assert_eq(@win.tray_count(), 1)
          t.set_tooltip("libyue", "wbtest 提示")
          assert_eq(@win.tray_tooltip(slot), "wbtest 提示")
          // 队列空时派发给 false
          assert_false(dispatch_tray_event())
          // 挂菜单不崩，且弹出菜单句柄已回填（W20a 的翻译链走通）
          let menu = Menu::new()
          let _ = menu.add_item("甲")
          let _ = menu.add_separator()
          let _ = menu.add_item("乙")
          t.set_menu(menu)
          assert_true(t.state.menu_handle >= 1)
          t.remove()
          assert_eq(@win.tray_count(), 0)
        } else {
          assert_eq(t.backend_name(), "sni")
          // SNI 侧：设置标题/提示/菜单都不该崩（真面板行为留使用者复验）
          t.set_title("wbtest")
          t.set_tooltip("libyue", "wbtest 提示")
          let menu = Menu::new()
          let _ = menu.add_item("甲")
          t.set_menu(menu)
          t.remove()
        }
      }
    }
  }
}
