// 蓝牙模块白盒测试:ObjectManager GetManagedObjects 应答形状解析(按
// bluez 真实线协议折叠后的 GDBusValue 样例构造)、属性提取、设备/适配器
// 快照构造(name 回退链)、对象路径校验与错误分流;不连总线、不真实
// 开关蓝牙。

///|
/// 属性字典构造助手(逐条 set,与解码器产出的 Map 一致)。
fn bt_props() -> Map[String, @traybus.GDBusValue] {
  Map([])
}

///|
/// hci0 适配器 + 两个设备 + 无关接口的 GetManagedObjects 应答样例
/// (a{oa{sa{sv}}},嵌套形状与 gdbus_from_wire 的折叠结果一致)。
fn bt_sample_managed() -> @traybus.GDBusValue {
  let adapter_props = bt_props()
  adapter_props.set("Address", @traybus.GVString("AA:BB:CC:DD:EE:FF"))
  adapter_props.set("Name", @traybus.GVString("lkyh-bt"))
  adapter_props.set("Powered", @traybus.GVBool(true))
  adapter_props.set("Discovering", @traybus.GVBool(false))
  let dev1_props = bt_props()
  dev1_props.set("Address", @traybus.GVString("11:22:33:44:55:66"))
  dev1_props.set("Name", @traybus.GVString("WH-1000XM4"))
  dev1_props.set("Alias", @traybus.GVString("WH-1000XM4"))
  dev1_props.set("Paired", @traybus.GVBool(true))
  dev1_props.set("Connected", @traybus.GVBool(false))
  dev1_props.set("Trusted", @traybus.GVBool(true))
  let dev2_props = bt_props()
  dev2_props.set("Address", @traybus.GVString("11:22:33:44:55:77"))
  dev2_props.set("Name", @traybus.GVString(""))
  dev2_props.set("Alias", @traybus.GVString("MX Master 3"))
  dev2_props.set("Paired", @traybus.GVBool(false))
  dev2_props.set("Connected", @traybus.GVBool(false))
  dev2_props.set("Trusted", @traybus.GVBool(false))
  @traybus.GVArray("{oa{sa{sv}}}", [
    @traybus.GVStruct([
      @traybus.GVPath("/org/bluez/hci0"),
      @traybus.GVArray("{sa{sv}}", [
        @traybus.GVStruct([
          @traybus.GVString("org.bluez.Adapter1"),
          @traybus.GVVariant(@traybus.GVDict(adapter_props)),
        ]),
        @traybus.GVStruct([
          @traybus.GVString("org.freedesktop.DBus.Introspectable"),
          @traybus.GVVariant(@traybus.GVDict(Map([]))),
        ]),
      ]),
    ]),
    @traybus.GVStruct([
      @traybus.GVPath("/org/bluez/hci0/dev_11_22_33_44_55_66"),
      @traybus.GVArray("{sa{sv}}", [
        @traybus.GVStruct([
          @traybus.GVString("org.bluez.Device1"),
          @traybus.GVVariant(@traybus.GVDict(dev1_props)),
        ]),
      ]),
    ]),
    @traybus.GVStruct([
      @traybus.GVPath("/org/bluez/hci0/dev_11_22_33_44_55_77"),
      @traybus.GVArray("{sa{sv}}", [
        @traybus.GVStruct([
          @traybus.GVString("org.bluez.Device1"),
          @traybus.GVVariant(@traybus.GVDict(dev2_props)),
        ]),
      ]),
    ]),
  ])
}

///|
test "bt_objects_of_iface:适配器/设备/无关接口分流" {
  let v = bt_sample_managed()
  let adapters = bt_objects_of_iface(v, bt_iface_adapter)
  inspect(adapters.length(), content="1")
  inspect(adapters[0].0, content="/org/bluez/hci0")
  inspect(
    adapters[0].1.get("Powered") is Some(@traybus.GVBool(true)),
    content="true",
  )
  let devices = bt_objects_of_iface(v, bt_iface_device)
  inspect(devices.length(), content="2")
  inspect(devices[0].0, content="/org/bluez/hci0/dev_11_22_33_44_55_66")
  inspect(devices[1].0, content="/org/bluez/hci0/dev_11_22_33_44_55_77")
  // 未知接口名 → 空
  inspect(bt_objects_of_iface(v, "org.example.Nope").length(), content="0")
}

///|
test "bt_objects_of_iface:退化形状安全跳过" {
  inspect(
    bt_objects_of_iface(@traybus.GVString("x"), bt_iface_adapter).length(),
    content="0",
  )
  inspect(
    bt_objects_of_iface(@traybus.GVNone, bt_iface_device).length(),
    content="0",
  )
  // 数组元素非对象条目(裸字符串/少字段结构体)均跳过
  let v = @traybus.GVArray("{oa{sa{sv}}}", [
    @traybus.GVString("stray"),
    @traybus.GVStruct([@traybus.GVPath("/org/bluez/hci0")]),
  ])
  inspect(bt_objects_of_iface(v, bt_iface_adapter).length(), content="0")
  // 未包 variant 的 a{sv} 变体形状仍可解析(兜底)
  let props = bt_props()
  props.set("Address", @traybus.GVString("AA:BB:CC:DD:EE:FF"))
  let v2 = @traybus.GVArray("{oa{sa{sv}}}", [
    @traybus.GVStruct([
      @traybus.GVPath("/org/bluez/hci0"),
      @traybus.GVArray("{sa{sv}}", [
        @traybus.GVStruct([
          @traybus.GVString("org.bluez.Adapter1"),
          @traybus.GVDict(props),
        ]),
      ]),
    ]),
  ])
  let adapters = bt_objects_of_iface(v2, bt_iface_adapter)
  inspect(adapters.length(), content="1")
}

///|
test "bt_prop_bool / bt_prop_str:缺属性与类型不符" {
  let props = bt_props()
  props.set("Powered", @traybus.GVBool(false))
  props.set("Name", @traybus.GVString("hci"))
  props.set("Alias", @traybus.GVPath("/x"))
  // 显式 false 与缺属性默认值区分
  inspect(bt_prop_bool(props, "Powered", true), content="false")
  inspect(bt_prop_bool(props, "Missing", true), content="true")
  inspect(bt_prop_bool(props, "Missing", false), content="false")
  // 类型不符走默认
  inspect(bt_prop_bool(props, "Name", true), content="true")
  inspect(bt_prop_str(props, "Name"), content="hci")
  inspect(bt_prop_str(props, "Missing"), content="")
}

///|
test "bt_adapter_from:快照字段" {
  let (path, props) = {
    let objs = bt_objects_of_iface(bt_sample_managed(), bt_iface_adapter)
    objs[0]
  }
  let a = bt_adapter_from(path, props)
  inspect(a.path, content="/org/bluez/hci0")
  inspect(a.address, content="AA:BB:CC:DD:EE:FF")
  inspect(a.name, content="lkyh-bt")
  inspect(a.powered, content="true")
  inspect(a.discovering, content="false")
}

///|
test "bt_device_from:name 回退 Name→Alias→MAC" {
  let objs = bt_objects_of_iface(bt_sample_managed(), bt_iface_device)
  let d1 = bt_device_from(objs[0].0, objs[0].1)
  inspect(d1.address, content="11:22:33:44:55:66")
  inspect(d1.name, content="WH-1000XM4") // Name 非空
  inspect(d1.paired, content="true")
  inspect(d1.connected, content="false")
  inspect(d1.trusted, content="true")
  let d2 = bt_device_from(objs[1].0, objs[1].1)
  inspect(d2.name, content="MX Master 3") // Name 空 → Alias
  inspect(d2.paired, content="false")
  // Name 与 Alias 均空 → 回退 MAC
  let props = bt_props()
  props.set("Address", @traybus.GVString("AB:CD:EF:00:11:22"))
  let d3 = bt_device_from("/org/bluez/hci0/dev_x", props)
  inspect(d3.name, content="AB:CD:EF:00:11:22")
  inspect(d3.paired, content="false") // 布尔缺省 false
}

///|
test "bt_device_path:合法/空/命名空间外" {
  fn dev(path : String) -> BtDevice {
    {
      path,
      address: "11:22:33:44:55:66",
      name: "x",
      paired: false,
      connected: false,
      trusted: false,
    }
  }

  inspect(
    bt_device_path(dev("/org/bluez/hci0/dev_11_22_33_44_55_66"))
    is Ok("/org/bluez/hci0/dev_11_22_33_44_55_66"),
    content="true",
  )
  inspect(bt_device_path(dev("")) is Err(InvalidParam(_)), content="true")
  inspect(
    bt_device_path(dev("/org/other/dev_1")) is Err(InvalidParam(_)),
    content="true",
  )
  inspect(
    bt_device_path(dev("/org/bluez")) is Err(InvalidParam(_)), // 无尾斜杠,不匹配前缀
    content="true",
  )
}

///|
test "bt_bus_err:错误分流" {
  inspect(
    bt_bus_err("org.freedesktop.DBus.Error.ServiceUnknown", ""),
    content="BtError::Unsupported",
  )
  inspect(bt_bus_err("gdbus.io", "no bus"), content="BtError::Unsupported")
  inspect(
    bt_bus_err("gdbus.timeout", "bus 应答超时"),
    content="BtError::BusFailed(gdbus.timeout: bus 应答超时)",
  )
}

///|
test "Show 输出:适配器/设备/错误" {
  let a : BtAdapter = {
    path: "/org/bluez/hci0",
    address: "AA:BB:CC:DD:EE:FF",
    name: "lkyh-bt",
    powered: true,
    discovering: true,
  }
  inspect(
    a.to_string(),
    content="BtAdapter { path: /org/bluez/hci0, address: AA:BB:CC:DD:EE:FF, name: lkyh-bt, powered: true, discovering: true }",
  )
  let d : BtDevice = {
    path: "/org/bluez/hci0/dev_1",
    address: "11:22:33:44:55:66",
    name: "WH-1000XM4",
    paired: true,
    connected: true,
    trusted: true,
  }
  inspect(
    d.to_string(),
    content="BtDevice { path: /org/bluez/hci0/dev_1, address: 11:22:33:44:55:66, name: WH-1000XM4, paired: true, connected: true, trusted: true }",
  )
  let e : BtError = BusFailed("gdbus.timeout: 超时")
  inspect(e.to_string(), content="BtError::BusFailed(gdbus.timeout: 超时)")
  inspect((Unsupported : BtError).to_string(), content="BtError::Unsupported")
  inspect(
    (InvalidParam("路径空") : BtError).to_string(),
    content="BtError::InvalidParam(路径空)",
  )
}

///|
test "bt_win_parse_adapter:单行两字段与空文本" {
  match bt_win_parse_adapter("MediaTek Bluetooth MT7921\tA0:1B:2C:3D:4E:5F") {
    Some(a) => {
      assert_eq(a.name, "MediaTek Bluetooth MT7921")
      assert_eq(a.address, "A0:1B:2C:3D:4E:5F")
      assert_eq(a.path, "")
      assert_true(a.powered)
      assert_true(!a.discovering)
    }
    None => assert_true(false)
  }
  // 无 radio(空文本)/字段缺失/地址空:None
  assert_true(bt_win_parse_adapter("") is None)
  assert_true(bt_win_parse_adapter("only-name") is None)
  assert_true(bt_win_parse_adapter("name\t") is None)
}

///|
test "bt_win_parse_devices:五字段行/name 空回退 mac/形状不符跳过" {
  let devs = bt_win_parse_devices(
    "MX Master 3\tA0:1B:2C:3D:4E:5F\t1\t1\t1\n\n\tF0:E1:D2:C3:B4:A5\t0\t1\t0\nbroken-line",
  )
  assert_eq(devs.length(), 2)
  assert_eq(devs[0].name, "MX Master 3")
  assert_eq(devs[0].address, "A0:1B:2C:3D:4E:5F")
  assert_true(devs[0].connected && devs[0].trusted && devs[0].paired)
  assert_eq(devs[1].name, "F0:E1:D2:C3:B4:A5") // 空名回退地址
  assert_true(!devs[1].connected && devs[1].trusted && !devs[1].paired)
}

///|
test "bt:Windows 本机冒烟(有无线电才断言)" {
  if @yue.platform() != "windows" {
    return
  }
  match bt_win_adapter() {
    Err(e) => println("bt: adapter err: \{e}") // 本机无蓝牙或服务未运行
    Ok(a) => {
      println("bt: adapter \{a.name} \{a.address}")
      assert_true(a.address != "")
      assert_true(a.name != "")
    }
  }
  match bt_win_devices() {
    Err(e) => println("bt: devices err: \{e}")
    Ok(devs) => {
      println("bt: \{devs.length()} known device(s)")
      for d in devs {
        println(
          "bt: dev \{d.name} \{d.address} paired=\{d.paired} connected=\{d.connected}",
        )
      }
    }
  }
}
