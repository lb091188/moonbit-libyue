// 电源控制模块白盒测试：logind ListSessions 应答（a(susso)）解析、Can*
// 结果归一、D-Bus 错误名映射。样例值取自 dbus-send 在本机（Ubuntu 24.04
// XFCE）的真实应答。关机/重启/注销属设置类动作一律不执行；只读查询
// （枚举会话 / Can*）在 logind 不在线时跳过。

///|
/// 构造一个会话结构体值（logind ListSessions 的元素形状）。
fn pwrc_session_struct(
  id : String,
  uid : Int,
  user : String,
  seat : String,
  path : String,
) -> @traybus.GDBusValue {
  @traybus.GVStruct([
    @traybus.GVString(id),
    @traybus.GVUInt32(uid),
    @traybus.GVString(user),
    @traybus.GVString(seat),
    @traybus.GVPath(path),
  ])
}

///|
test "pwrc_sessions_of：ListSessions 真实应答形状（a(susso)）" {
  // 实机 dbus-send 应答：一个 c2 会话（uid 1000, lkyh, seat0）
  let reply = @traybus.GVArray("(susso)", [
    pwrc_session_struct(
      "c2", 1000, "lkyh", "seat0", "/org/freedesktop/login1/session/c2",
    ),
  ])
  let out = pwrc_sessions_of(reply)
  assert_eq(out.length(), 1)
  assert_eq(out[0].id, "c2")
  assert_eq(out[0].uid, 1000)
  assert_eq(out[0].user, "lkyh")
  assert_eq(out[0].seat, "seat0")
  assert_eq(out[0].path, "/org/freedesktop/login1/session/c2")
}

///|
test "pwrc_sessions_of：多会话与畸形元素（合法子集）" {
  let reply = @traybus.GVArray("(susso)", [
    pwrc_session_struct(
      "1", 1000, "lkyh", "seat0", "/org/freedesktop/login1/session/1",
    ),
    pwrc_session_struct(
      "c2", 1000, "lkyh", "seat0", "/org/freedesktop/login1/session/c2",
    ),
    pwrc_session_struct(
      "3", 1000, "root", "", "/org/freedesktop/login1/session/3",
    ),
  ])
  let out = pwrc_sessions_of(reply)
  assert_eq(out.length(), 3)
  // 远程/无座位会话 seat 为空串
  assert_eq(out[2].seat, "")
  // 字段数不够的 struct 跳过；非数组应答给空列表
  let short = @traybus.GVArray("(susso)", [
    @traybus.GVStruct([
      @traybus.GVString("c2"),
      @traybus.GVUInt32(1000),
      @traybus.GVString("lkyh"),
    ]),
  ])
  assert_eq(pwrc_sessions_of(short).length(), 0)
  assert_eq(pwrc_sessions_of(@traybus.GVString("garbage")).length(), 0)
  assert_eq(pwrc_sessions_of(@traybus.GVNone).length(), 0)
}

///|
test "pwrc_can_parse：Can* 结果归一" {
  assert_eq(pwrc_can_parse("yes"), true)
  assert_eq(pwrc_can_parse("challenge"), true) // 需 polkit 交互授权
  assert_eq(pwrc_can_parse("no"), false)
  assert_eq(pwrc_can_parse("na"), false) // 能力不存在（如容器内）
  assert_eq(pwrc_can_parse(""), false)
  assert_eq(pwrc_can_parse("maybe"), false)
}

///|
test "pwrc_action_err：关机/重启动作的错误名映射" {
  // polkit 授权被拒 / 环境不允许 → NotAllowed
  inspect(
    pwrc_action_err("org.freedesktop.DBus.Error.AccessDenied", "not authorized"),
    content="PwrcError::NotAllowed(not authorized)",
  )
  inspect(
    pwrc_action_err("org.freedesktop.systemd1.NotSupported", "no boot manager"),
    content="PwrcError::NotAllowed(no boot manager)",
  )
  // 其余错误同总线映射
  inspect(
    pwrc_action_err("org.freedesktop.DBus.Error.Failed", "io error"),
    content="PwrcError::BusFailed(org.freedesktop.DBus.Error.Failed: io error)",
  )
  assert_true(
    pwrc_action_err("org.freedesktop.DBus.Error.ServiceUnknown", "offline") is Unsupported,
  )
}

///|
test "pwrc_text/pwrc_int：D-Bus 值提取" {
  assert_eq(pwrc_text(@traybus.GVString("lkyh")), Some("lkyh"))
  assert_eq(
    pwrc_text(@traybus.GVPath("/org/freedesktop/login1/session/c2")),
    Some("/org/freedesktop/login1/session/c2"),
  )
  assert_true(pwrc_text(@traybus.GVNone) is None)
  assert_eq(pwrc_int(@traybus.GVUInt32(1000)), 1000)
  assert_eq(pwrc_int(@traybus.GVInt32(1000)), 1000)
  assert_eq(pwrc_int(@traybus.GVString("1000")), 0)
  assert_eq(pwrc_int(@traybus.GVNone), 0)
}

///|
test "pwrc_bus_err/pwrc_session_err：错误名映射" {
  // logind 不在线/总线不可达 → Unsupported（等价于无电源控制后端）
  assert_true(
    pwrc_bus_err("org.freedesktop.DBus.Error.ServiceUnknown", "not running")
    is Unsupported,
  )
  assert_true(pwrc_bus_err("gdbus.io", "connect failed") is Unsupported)
  // 其它错误保留原名与说明
  inspect(
    pwrc_bus_err("org.freedesktop.DBus.Error.AccessDenied", "not authorized"),
    content="PwrcError::BusFailed(org.freedesktop.DBus.Error.AccessDenied: not authorized)",
  )
  // 会话级动作：会话不存在按 Unsupported（会话消失也算做不了）
  assert_true(
    pwrc_session_err("org.freedesktop.systemd1.NoSuchSession", "c2")
    is Unsupported,
  )
  inspect(
    pwrc_session_err("org.freedesktop.DBus.Error.AccessDenied", "denied"),
    content="PwrcError::BusFailed(org.freedesktop.DBus.Error.AccessDenied: denied)",
  )
}

///|
test "pwrc 真机只读冒烟（logind 不在线时跳过）" {
  if !pwrc_supported() {
    println("pwrc: skip (logind offline)")
    return
  }
  match pwrc_sessions() {
    Err(e) => {
      println("pwrc_sessions failed: \{e}")
      assert_true(false)
    }
    Ok(sessions) =>
      for s in sessions {
        assert_true(s.id != "")
        assert_true(s.user != "")
        assert_true(s.path.has_prefix("/org/freedesktop/login1/session/"))
        println("pwrc: \{s}")
      }
  }
  // Can* 可查：只读查询，不断言具体值（容器/权限差异环境可能为 no/na）
  match pwrc_can_power_off() {
    Err(e) => {
      println("pwrc_can_power_off failed: \{e}")
      assert_true(false)
    }
    Ok(v) => println("pwrc: can_power_off = \{v}")
  }
  match pwrc_can_reboot() {
    Err(e) => {
      println("pwrc_can_reboot failed: \{e}")
      assert_true(false)
    }
    Ok(v) => println("pwrc: can_reboot = \{v}")
  }
}

///|
test "pwrc_logout：空会话路径在调用侧即拒（不触发总线动作）" {
  let empty : SessionInfo = { id: "", uid: 0, user: "", seat: "", path: "", }
  assert_true(pwrc_logout(empty) is Err(BusFailed(_)))
}
