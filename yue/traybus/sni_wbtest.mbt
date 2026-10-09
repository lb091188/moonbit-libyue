// SNI 托盘项注册表单测:DBusMenu 对象路径派生、多托盘项互不覆盖、
// 注销与注册失败路径的对称清理。真总线部分(建两个托盘项)在无面板
// watcher 时自动跳过;面板侧菜单行为的互操作验证见 adaptation.md。

///|
test "menu_path 随托盘项路径派生(首项沿用 /MenuBar)" {
  inspect(menu_path_of("/StatusNotifierItem"), content="/MenuBar")
  inspect(menu_path_of("/StatusNotifierItem_2"), content="/MenuBar_2")
  inspect(menu_path_of("/StatusNotifierItem_7"), content="/MenuBar_7")
  // 任意后缀都不退化成固定 /MenuBar——那会让多项共享菜单对象路径
  inspect(
    menu_path_of("/StatusNotifierItem_2") != menu_path_of("/StatusNotifierItem_3"),
    content="true",
  )
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
          inspect(a.path != b.path, content="true")
          inspect(a.menu_path != b.menu_path, content="true")
          inspect(a.menu_path == menu_path_of(a.path), content="true")
          inspect(b.menu_path == menu_path_of(b.path), content="true")
          inspect(a.path, content="/StatusNotifierItem")
          inspect(b.path, content="/StatusNotifierItem_2")
          inspect(a.menu_path, content="/MenuBar")
          inspect(b.menu_path, content="/MenuBar_2")
          // 菜单路由各自归位:两个菜单路径都能在注册表里找到自己的项
          match g_conn.val {
            Some(c) => {
              inspect(c.menus.get(a.menu_path) is Some(_), content="true")
              inspect(c.menus.get(b.menu_path) is Some(_), content="true")
              inspect(c.items.length(), content="2")
            }
            None => inspect("连接不在", content="连接在")
          }
          // 注销后两项都从注册表消失(含 menus),第三个项从头拿路径
          a.unregister()
          b.unregister()
          match g_conn.val {
            Some(c) => {
              inspect(c.items.length(), content="0")
              inspect(c.menus.length(), content="0")
            }
            None => inspect("连接不在", content="连接在")
          }
          match Item::create("wbtest-c", "") {
            Err(e) => println("skip: 注销后重建不可用(\{e})")
            Ok(cc) => {
              inspect(cc.path, content="/StatusNotifierItem")
              inspect(cc.menu_path, content="/MenuBar")
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
              inspect(z.path, content="/StatusNotifierItem")
              inspect(z.path != y.path, content="true")
              inspect(z.menu_path != y.menu_path, content="true")
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
          let dest = conn_unique_name()
          // Menu 属性各自报自己的菜单对象路径
          match gdbus_get_property_session(dest, a.path, sni_iface, "Menu") {
            Ok(GVPath(p)) => inspect(p, content=a.menu_path)
            Ok(_) => inspect("Menu 属性类型不符", content="GVPath")
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
          inspect(la.contains("菜单A1"), content="true")
          inspect(la.contains("菜单A2"), content="true")
          inspect(la.contains("菜单B1"), content="false")
          inspect(lb.contains("菜单B1"), content="true")
          inspect(lb.contains("菜单A1"), content="false")
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
          inspect(b.items.contains(item.path), content="true")
          inspect(g_saved.contains(0), content="false")
          let name_b = b.name
          let conns_before = g_conns.val.length()
          // 自愈重连到期:已有活连接,只补迁移,不另建连接
          // (旧实现无条件新建并覆盖 g_conn,按需重建那条连同 fd 与
          // glib 监视一起泄漏)
          try_reconnect(0, 1)
          match g_conn.val {
            Some(c2) => {
              inspect(c2.name == name_b, content="true")
              inspect(c2.alive, content="true")
              inspect(c2.items.contains(item.path), content="true")
            }
            None => inspect("连接被清空", content="连接在")
          }
          inspect(g_conns.val.length(), content="\{conns_before}")
          item.unregister()
        }
      }
    }
  }
}
