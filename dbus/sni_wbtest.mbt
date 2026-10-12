// SNI 托盘项注册表单测:DBusMenu 对象路径派生、多托盘项互不覆盖、
// 注销与注册失败路径的对称清理。真总线部分(建两个托盘项)在无面板
// watcher 时自动跳过;面板侧菜单行为的互操作验证见 adaptation.md。

///|
test "menu_path 随托盘项路径派生(首项沿用 /MenuBar)" {
  assert_eq(menu_path_of("/StatusNotifierItem"), "/MenuBar")
  assert_eq(menu_path_of("/StatusNotifierItem_2"), "/MenuBar_2")
  assert_eq(menu_path_of("/StatusNotifierItem_7"), "/MenuBar_7")
  // 任意后缀都不退化成固定 /MenuBar——那会让多项共享菜单对象路径
  assert_true(menu_path_of("/StatusNotifierItem_2") != menu_path_of("/StatusNotifierItem_3"))
}

///|
test "真总线:多托盘项路径与菜单对象互不覆盖,注销后对称清理" {
  match Item::create("wbtest-a", "") {
    Err(e) => println("skip: 托盘注册不可用(\{e})")
    Ok(a) =>
      match Item::create("wbtest-b", "") {
        Err(e) => {
          a.unregister()
          println("skip: 第二个托盘项注册不可用(\{e})")
        }
        Ok(b) => {
          // 回归点:两项的 DBusMenu 对象路径必须不同(旧实现恒 /MenuBar,
          // 第二项在 menus 注册表里顶掉第一项的菜单路由)
          assert_true(a.path != b.path)
          assert_true(a.menu_path != b.menu_path)
          assert_true(a.menu_path == menu_path_of(a.path))
          assert_true(b.menu_path == menu_path_of(b.path))
          assert_eq(a.path, "/StatusNotifierItem")
          assert_eq(b.path, "/StatusNotifierItem_2")
          assert_eq(a.menu_path, "/MenuBar")
          assert_eq(b.menu_path, "/MenuBar_2")
          // 菜单路由各自归位:两个菜单路径都能在注册表里找到自己的项
          match g_conn.val {
            Some(c) => {
              assert_true(c.menus.get(a.menu_path) is Some(_))
              assert_true(c.menus.get(b.menu_path) is Some(_))
              assert_eq(c.items.length(), 2)
            }
            None => assert_true(false) // 走到错误分支：连接在
          }
          // 注销后两项都从注册表消失(含 menus),第三个项从头拿路径
          a.unregister()
          b.unregister()
          match g_conn.val {
            Some(c) => {
              assert_eq(c.items.length(), 0)
              assert_eq(c.menus.length(), 0)
            }
            None => assert_true(false) // 走到错误分支：连接在
          }
          match Item::create("wbtest-c", "") {
            Err(e) => println("skip: 注销后重建不可用(\{e})")
            Ok(cc) => {
              assert_eq(cc.path, "/StatusNotifierItem")
              assert_eq(cc.menu_path, "/MenuBar")
              cc.unregister()
            }
          }
        }
      }
  }
}

///|
test "真总线:中间项注销后新项不复用其路径" {
  match Item::create("wbtest-x", "") {
    Err(e) => println("skip: 托盘注册不可用(\{e})")
    Ok(x) =>
      match Item::create("wbtest-y", "") {
        Err(e) => {
          x.unregister()
          println("skip: 第二个托盘项注册不可用(\{e})")
        }
        Ok(y) => {
          x.unregister() // 注销首项,y 仍占 /StatusNotifierItem_2
          match Item::create("wbtest-z", "") {
            Err(e) => {
              y.unregister()
              println("skip: 第三个托盘项注册不可用(\{e})")
            }
            Ok(z) => {
              // 复用会让新旧两项共享对象路径与 DBusMenu 路由
              assert_eq(z.path, "/StatusNotifierItem")
              assert_true(z.path != y.path)
              assert_true(z.menu_path != y.menu_path)
              y.unregister()
              z.unregister()
            }
          }
        }
      }
  }
}

///|
/// 收集 GDBusValue 树里全部字符串(布局标签断言用)。
fn collect_strings(v : GDBusValue, out : Array[String]) -> Unit {
  match v {
    GVString(s) => out.push(s)
    GVStruct(fields) =>
      for f in fields {
        collect_strings(f, out)
      }
    GVArray(_, items) =>
      for it in items {
        collect_strings(it, out)
      }
    GVVariant(inner) => collect_strings(inner, out)
    GVDict(props) =>
      for _, pv in props {
        collect_strings(pv, out)
      }
    _ => ()
  }
}

///|
test "真总线:两个托盘项的 DBusMenu 路由互不覆盖(GetLayout 各自归位)" {
  match Item::create("wbtest-menu-a", "") {
    Err(e) => println("skip: 托盘注册不可用(\{e})")
    Ok(a) =>
      match Item::create("wbtest-menu-b", "") {
        Err(e) => {
          a.unregister()
          println("skip: 第二个托盘项注册不可用(\{e})")
        }
        Ok(b) => {
          a.add_menu_entry("菜单A1", true, fn() { () })
          a.add_menu_entry("菜单A2", true, fn() { () })
          b.add_menu_entry("菜单B1", true, fn() { () })
          let dest = dbus_unique_name()
          // Menu 属性各自报自己的菜单对象路径
          match gdbus_get_property_session(dest, a.path, sni_iface, "Menu") {
            Ok(GVPath(p)) => assert_eq(p, a.menu_path)
            Ok(_) => assert_true(false) // 走到错误分支：GVPath
            Err(e) => println("skip: Menu 属性读取失败(\{e.name})")
          }
          // 客户端视角:对两个菜单对象路径分别发 GetLayout,布局各自归位
          // (旧实现恒 /MenuBar,两项都路由到后注册那项的菜单)
          fn layout_of(path : String) -> Array[String] {
            let out : Array[String] = []
            match
              gdbus_call_session(
                dest,
                path,
                "com.canonical.dbusmenu",
                "GetLayout",
                [GVInt32(0), GVInt32(-1), GVArray("s", [])],
              ) {
              Ok(v) => collect_strings(v, out)
              Err(_) => ()
            }
            out
          }

          let la = layout_of(a.menu_path)
          let lb = layout_of(b.menu_path)
          assert_true(la.contains("菜单A1"))
          assert_true(la.contains("菜单A2"))
          assert_false(la.contains("菜单B1"))
          assert_true(lb.contains("菜单B1"))
          assert_false(lb.contains("菜单A1"))
          a.unregister()
          b.unregister()
        }
      }
  }
}

///|
test "真总线:断线后按需重建,自愈重连不另建连接(fd 不泄漏)" {
  match Item::create("wbtest-recon", "") {
    Err(e) => println("skip: 托盘注册不可用(\{e})")
    Ok(item) => {
      // 模拟总线断开:mark_dead 撤监视、关 fd、暂存旧连接并挂起重连
      match g_conn.val {
        Some(c) => c.mark_dead()
        None => ()
      }
      match connect_session() {
        Err(e) => {
          item.unregister()
          println("skip: 重建连接不可用(\{e})")
        }
        Ok(b) => {
          // 迁移到位:旧托盘项回到新连接,暂存表已清
          assert_true(b.items.contains(item.path))
          assert_false(g_saved.contains(0))
          let name_b = b.name
          let conns_before = g_conns.val.length()
          // 自愈重连到期:已有活连接,只补迁移,不另建连接
          // (旧实现无条件新建并覆盖 g_conn,按需重建那条连同 fd 与
          // glib 监视一起泄漏)
          try_reconnect(0, 1)
          match g_conn.val {
            Some(c2) => {
              assert_true(c2.name == name_b)
              assert_true(c2.alive)
              assert_true(c2.items.contains(item.path))
            }
            None => assert_true(false) // 走到错误分支：连接在
          }
          assert_eq(g_conns.val.length(), conns_before)
          item.unregister()
        }
      }
    }
  }
}
