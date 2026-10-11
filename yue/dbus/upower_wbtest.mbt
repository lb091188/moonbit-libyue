// UPower 应答与信号解析的单元测试(纯函数,不连总线)。

///|
test "GetAll a{sv} 应答解析:IsPresent/Percentage(d)/State" {
  // 顺序照真实应答(UpdateTime 't' 在 Percentage 'd' 之前——'t' 缺失时
  // variant 未知签名会整体错位,真总线实测教训)
  let dict = VArray("{sv}", [
    VStruct([VString("NativePath"), VVariant(VString("BAT0"))]),
    VStruct([VString("UpdateTime"), VVariant(VU64(1789346811L))]),
    VStruct([VString("Type"), VVariant(VU32(2))]),
    VStruct([VString("Energy"), VVariant(VDouble(37.5))]),
    VStruct([VString("IsPresent"), VVariant(VBool(true))]),
    VStruct([VString("Percentage"), VVariant(VDouble(87.5))]),
    VStruct([VString("State"), VVariant(VU32(1))]),
  ])
  match build_reply(1, 5, ":1.55", "a{sv}", [dict]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          let props = props_of(m)
          assert_true(props.get("IsPresent") is Some(VBool(true)))
          assert_true(props.get("Percentage") is Some(VDouble(87.5)))
          assert_true(props.get("State") is Some(VU32(1)))
          assert_true(props.get("UpdateTime") is Some(VU64(1789346811L)))
          assert_true(props.get("NoSuch") is None)
        }
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
}

///|
test "消息往返:'t' UINT64 顶层" {
  match build_reply(1, 4, ":1.4", "t", [VU64(1789346811L)]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) =>
          match m.body[0] {
            VU64(v) => assert_eq(v.to_string(), "1789346811")
            _ => assert_true(false) // 走到错误分支：VU64
          }
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
}

///|
test "PropertiesChanged 信号:OnBattery 变更提取" {
  let changed = VArray("{sv}", [
    VStruct([VString("OnBattery"), VVariant(VBool(true))]),
    VStruct([VString("LidIsClosed"), VVariant(VBool(false))]),
  ])
  match
    build_signal(
      11,
      "/org/freedesktop/UPower",
      "org.freedesktop.DBus.Properties",
      "PropertiesChanged",
      "sa{sv}as",
      [
        VString("org.freedesktop.UPower"),
        changed,
        VArray("s", [VString("WarningLevel")]),
      ],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          assert_eq(m.kind, 4)
          assert_eq(m.path, "/org/freedesktop/UPower")
          assert_eq(m.iface, "org.freedesktop.DBus.Properties")
          assert_eq(m.action, "PropertiesChanged")
          match changed_on_battery(m.body) {
            Some(b) => assert_true(b)
            None => assert_true(false) // 走到错误分支：Some(true)
          }
        }
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
}

///|
test "PropertiesChanged 无 OnBattery / 缺字典 → None" {
  let changed = VArray("{sv}", [
    VStruct([VString("LidIsClosed"), VVariant(VBool(true))]),
  ])
  match
    build_signal(
      12,
      "/org/freedesktop/UPower",
      "org.freedesktop.DBus.Properties",
      "PropertiesChanged",
      "sa{sv}as",
      [VString("org.freedesktop.UPower"), changed, VArray("s", [])],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => assert_true(changed_on_battery(m.body) is None)
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
}
