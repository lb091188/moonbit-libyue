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
          inspect(props.get("IsPresent") is Some(VBool(true)), content="true")
          inspect(
            props.get("Percentage") is Some(VDouble(87.5)),
            content="true",
          )
          inspect(props.get("State") is Some(VU32(1)), content="true")
          inspect(props.get("UpdateTime") is Some(VU64(1789346811L)), content="true")
          inspect(props.get("NoSuch") is None, content="true")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}

///|
test "消息往返:'t' UINT64 顶层" {
  match build_reply(1, 4, ":1.4", "t", [VU64(1789346811L)]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) =>
          match m.body[0] {
            VU64(v) => inspect(v.to_string(), content="1789346811")
            _ => inspect("类型不符", content="VU64")
          }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
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
          inspect(m.kind, content="4")
          inspect(m.path, content="/org/freedesktop/UPower")
          inspect(m.iface, content="org.freedesktop.DBus.Properties")
          inspect(m.action, content="PropertiesChanged")
          match changed_on_battery(m.body) {
            Some(b) => inspect(b, content="true")
            None => inspect("未提取到", content="Some(true)")
          }
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
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
        Some(m) =>
          inspect(
            changed_on_battery(m.body) is None,
            content="true",
          )
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}
