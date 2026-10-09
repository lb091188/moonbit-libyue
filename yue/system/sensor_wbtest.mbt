// 传感器模块白盒测试:LightLevel / AccelerometerOrientation 应答类型
// 判定、D-Bus 错误分流(缺服务/缺属性 → Unsupported)与 Show 输出;不连
// 总线、不真实读取传感器。

///|
test "sns_light_from_value:double/整型兼容/类型不符" {
  inspect(
    sns_light_from_value(@traybus.GVDouble(53.5)) is Ok(53.5),
    content="true",
  )
  inspect(
    sns_light_from_value(@traybus.GVDouble(0.0)) is Ok(0.0),
    content="true",
  )
  // 个别代理以整型上报,兼容折算
  inspect(
    sns_light_from_value(@traybus.GVInt32(42)) is Ok(42.0),
    content="true",
  )
  inspect(sns_light_from_value(@traybus.GVUInt32(7)) is Ok(7.0), content="true")
  // 类型不符 → Err 说明
  inspect(
    sns_light_from_value(@traybus.GVString("53.5"))
    is Err("LightLevel 应答类型不符"),
    content="true",
  )
  inspect(
    sns_light_from_value(@traybus.GVBool(true))
    is Err("LightLevel 应答类型不符"),
    content="true",
  )
  inspect(
    sns_light_from_value(@traybus.GVNone)
    is Err("LightLevel 应答类型不符"),
    content="true",
  )
}

///|
test "sns_orientation_from_value:方向串/undefined/类型不符" {
  inspect(
    sns_orientation_from_value(@traybus.GVString("normal")) is Ok("normal"),
    content="true",
  )
  inspect(
    sns_orientation_from_value(@traybus.GVString("left-up")) is Ok("left-up"),
    content="true",
  )
  // 无加速度计:代理上报 undefined / 空串 → Err(无加速度计)
  inspect(
    sns_orientation_from_value(@traybus.GVString("undefined"))
    is Err("无加速度计"),
    content="true",
  )
  inspect(
    sns_orientation_from_value(@traybus.GVString("")) is Err("无加速度计"),
    content="true",
  )
  inspect(
    sns_orientation_from_value(@traybus.GVNone)
    is Err("AccelerometerOrientation 应答类型不符"),
    content="true",
  )
}

///|
test "sns_err_map:缺服务/总线不可达/缺属性 → Unsupported,其余 BusFailed" {
  inspect(
    sns_err_map("org.freedesktop.DBus.Error.ServiceUnknown", ""),
    content="SensorError::Unsupported",
  )
  inspect(sns_err_map("gdbus.io", "no bus"), content="SensorError::Unsupported")
  inspect(
    sns_err_map("org.freedesktop.DBus.Error.InvalidArgs", "No such property"),
    content="SensorError::Unsupported",
  )
  inspect(
    sns_err_map("org.freedesktop.DBus.Error.UnknownProperty", ""),
    content="SensorError::Unsupported",
  )
  inspect(
    sns_err_map("org.freedesktop.DBus.Error.UnknownInterface", ""),
    content="SensorError::Unsupported",
  )
  // 真故障:超时/未知错误保留原名与说明
  inspect(
    sns_err_map("gdbus.timeout", "总线应答超时"),
    content="SensorError::BusFailed(gdbus.timeout: 总线应答超时)",
  )
  inspect(
    sns_err_map("org.freedesktop.DBus.Error.Failed", "io error"),
    content="SensorError::BusFailed(org.freedesktop.DBus.Error.Failed: io error)",
  )
}

///|
test "Show 输出:错误枚举" {
  inspect(
    (Unsupported : SensorError).to_string(),
    content="SensorError::Unsupported",
  )
  inspect(
    (BusFailed("gdbus.timeout: 超时") : SensorError).to_string(),
    content="SensorError::BusFailed(gdbus.timeout: 超时)",
  )
}
