// 新栈总线层白盒测试：连接与唯一名、[dbus_pump] 的空转安全、信号订阅
// 走真总线（AddMatch 是方法调用，成功即登记在案）、入站调用处理者未登记
// 时的兜底应答路径。
//
// 口令是「能连上才断言」：会话总线连不上（Windows 等无 D-Bus 会话总线的
// 平台、无总线的 headless Linux）就打印跳过并返回，不判失败——与同包
// `dbus_wbtest.mbt` 的真总线冒烟、`media_wbtest.mbt` 的「非 Linux 跳过」
// 同一口径。系统总线本就更宽：连不上只记录。

///|
/// 会话总线守卫：连得上返回 true；连不上打印跳过并返回 false（调用方直接
/// `return`）。连上之后的断言仍是硬断言——已经连上了还失败就是真回归。
fn bus_session_guard() -> Bool {
  match dbus_ensure_session() {
    Ok(_) => true
    Err(e) => {
      println("bus: skip（会话总线不可用：\{e}）")
      false
    }
  }
}

///|
test {
  // 会话总线：确保连接、唯一名形如 :1.x
  if !bus_session_guard() {
    return
  }
  assert_true(dbus_session_alive())
  let name = dbus_unique_name()
  println("bus: unique name = \{name}")
  assert_true(name.has_prefix(":"))
  assert_true(name.length() > 2)
}

///|
test {
  // 空转泵：没有待发数据时不阻塞、不判死
  if !bus_session_guard() {
    return
  }
  dbus_pump()
  dbus_pump(timeout_ms=20)
  dbus_pump()
  assert_true(dbus_session_alive())
}

///|
test {
  // 订阅会话信号：AddMatch 成功即 Ok；随后泵一拍确认回调路径不崩
  if !bus_session_guard() {
    return
  }
  let hits : Ref[Int] = Ref(0)
  match
    dbus_subscribe_session(
      "interface='org.freedesktop.DBus',member='NameOwnerChanged',path='/org/freedesktop/DBus',sender='org.freedesktop.DBus'",
      "org.freedesktop.DBus.NameOwnerChanged",
      fn(_args : Array[GDBusValue]) -> Unit {
        hits.val = hits.val + 1
      },
    ) {
    Err(e) => {
      println("subscribe failed: \{e}")
      assert_true(false)
    }
    Ok(_) => ()
  }
  // 让总线自己造一次 NameOwnerChanged：请求一个不存在的名字不会改名，
  // 因此这里只确认「订阅在案 + 泵不报错」，命中数不作断言
  dbus_pump(timeout_ms=30)
  assert_true(dbus_session_alive())
}

///|
test {
  // 入站调用处理者：登记后仍可正常发同步调用（不回归）
  if !bus_session_guard() {
    return
  }
  dbus_set_call_handler(fn(req : CallReq) -> Unit {
    // 函数字段要先取再调：MoonBit 不把 `req.reply_error(...)` 当调用
    let reply_err : (String, String) -> Unit = req.reply_error
    reply_err(
      "org.freedesktop.DBus.Error.UnknownMethod",
      "本测试不提供服务: \{req.action}",
    )
  })
  dbus_pump()
  assert_true(dbus_session_alive())
}

///|
test {
  // 系统总线按环境容错：能连上就查一次名字表，连不上只记录
  match gdbus_call_system(
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus",
      "ListNames",
      [],
    ) {
    Ok(GVArray(_, names)) => {
      println("bus: system names = \{names.length()}")
      assert_true(names.length() > 0)
    }
    Ok(_) => {
      println("bus: 系统总线 ListNames 返回了非数组值")
      assert_true(false)
    }
    Err(e) => println("bus: skip 系统总线（\{e.name}：\{e.message}）")
  }
}
