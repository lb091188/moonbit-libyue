// 传感器:iio-sensor-proxy(net.hadess.SensorProxy,系统总线)汇总 IIO 子
// 系统的传感器读数,当前支持环境光(LightLevel,勒克斯)与加速度计方向
// (AccelerometerOrientation)。取值与探测走 @traybus 通用 D-Bus 层的
// 属性读取;本机/虚拟机没有该服务(未装 iio-sensor-proxy)、没有对应
// 传感器是合法状态:sns_supported() 为 false,取值为 Unsupported,不
// 视为异常。应答类型判定与错误分流为纯函数(sns_light_from_value /
// sns_orientation_from_value / sns_err_map),sensor_wbtest.mbt 白盒
// 覆盖。
//
// 典型用法:
//   if sns_supported() && sns_has_ambient_light() {
//     match sns_ambient_light() {
//       Ok(lux) => // lux 为环境光照度(勒克斯)
//       Err(Unsupported) => ()   // 运行中传感器被拔出/服务退出
//       Err(e) => ()
//     }
//   }

///|
let sns_dest : String = "net.hadess.SensorProxy"

///|
let sns_path : String = "/net/hadess/SensorProxy"

///|
let sns_iface : String = "net.hadess.SensorProxy"

///|
pub(all) enum SensorError {
  /// 无 iio-sensor-proxy 服务,或没有环境光 / 加速度计传感器
  Unsupported
  /// D-Bus 调用失败(应答超时 / 编码失败等),带错误名与说明
  BusFailed(String)
}

///|
pub impl Show for SensorError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("SensorError::Unsupported")
    BusFailed(m) => logger.write_string("SensorError::BusFailed(\{m})")
  }
}

///|
pub extend SensorError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层:应答类型判定 / 错误分流(白盒覆盖;不连总线)
// ---------------------------------------------------------------------------

///|
/// LightLevel 应答值 → 勒克斯(代理以 double 上报;个别实现给整型,兼容
/// 折算;类型不符为 Err 说明)。
fn sns_light_from_value(v : @traybus.GDBusValue) -> Result[Double, String] {
  match v {
    @traybus.GVDouble(x) => Ok(x)
    @traybus.GVInt32(n) => Ok(n.to_double())
    @traybus.GVUInt32(n) => Ok(n.to_double())
    _ => Err("LightLevel 应答类型不符")
  }
}

///|
/// AccelerometerOrientation 应答值 → 方向串(代理在无加速度计时上报
/// "undefined"/空串,按 Unsupported 处理;类型不符为 Err 说明)。
fn sns_orientation_from_value(
  v : @traybus.GDBusValue,
) -> Result[String, String] {
  match v {
    @traybus.GVString(s) =>
      if s == "" || s == "undefined" {
        Err("无加速度计")
      } else {
        Ok(s)
      }
    _ => Err("AccelerometerOrientation 应答类型不符")
  }
}

///|
/// D-Bus 调用错误 → SensorError:服务不在线 / 总线不可达 / 属性或接口
/// 不存在(即无对应传感器)一律 Unsupported,其余为 BusFailed。
fn sns_err_map(name : String, message : String) -> SensorError {
  match name {
    "org.freedesktop.DBus.Error.ServiceUnknown"
    | "gdbus.io"
    | "org.freedesktop.DBus.Error.InvalidArgs"
    | "org.freedesktop.DBus.Error.UnknownProperty"
    | "org.freedesktop.DBus.Error.UnknownInterface" => Unsupported
    _ => BusFailed("\{name}: \{message}")
  }
}

///|
/// 读单属性并路由错误(应答值原样交调用方解析)。
fn sns_get(prop : String) -> Result[@traybus.GDBusValue, SensorError] {
  match
    @traybus.gdbus_get_property_system(sns_dest, sns_path, sns_iface, prop) {
    Ok(v) => Ok(v)
    Err(e) => Err(sns_err_map(e.name, e.message))
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 系统是否装有 iio-sensor-proxy(读 HasAccelerometer 属性探活;属性在
/// 线即可达)。每次调用真实探测,高频场景请调用方自行缓存结果。
pub fn sns_supported() -> Bool {
  match
    @traybus.gdbus_get_property_system(
      sns_dest, sns_path, sns_iface, "HasAccelerometer",
    ) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
/// 是否具备环境光传感器(HasAmbientLight 属性;服务不在线或无属性为
/// false)。每次调用真实探测。
pub fn sns_has_ambient_light() -> Bool {
  match sns_get("HasAmbientLight") {
    Ok(@traybus.GVBool(b)) => b
    _ => false
  }
}

///|
/// 环境光照度(勒克斯)。取值前 ClaimLight 点亮传感器、取完 ReleaseLight
/// 释放(不点灯的读数会停在旧值);无服务/无环境光为 Unsupported。
pub fn sns_ambient_light() -> Result[Double, SensorError] {
  let _ = @traybus.gdbus_call_system(
    sns_dest,
    sns_path,
    sns_iface,
    "ClaimLight",
    [],
  )
  let result = match sns_get("LightLevel") {
    Err(e) => Err(e)
    Ok(v) =>
      match sns_light_from_value(v) {
        Ok(lux) => Ok(lux)
        Err(m) => Err(SensorError::BusFailed(m))
      }
  }
  let _ = @traybus.gdbus_call_system(
    sns_dest,
    sns_path,
    sns_iface,
    "ReleaseLight",
    [],
  )
  result
}

///|
/// 加速度计方向("normal"/"left-up"/"left-down"/"right-up"/"right-down"/
/// "bottom-up"/"bottom-down" 等;无加速度计为 Unsupported)。与 LightLevel
/// 同理,取值前后自动 ClaimAccelerometer/ReleaseAccelerometer。
pub fn sns_accelerometer_orientation() -> Result[String, SensorError] {
  let _ = @traybus.gdbus_call_system(
    sns_dest,
    sns_path,
    sns_iface,
    "ClaimAccelerometer",
    [],
  )
  let result = match sns_get("AccelerometerOrientation") {
    Err(e) => Err(e)
    Ok(v) =>
      match sns_orientation_from_value(v) {
        Ok(s) => Ok(s)
        Err(_) => Err(SensorError::Unsupported)
      }
  }
  let _ = @traybus.gdbus_call_system(
    sns_dest,
    sns_path,
    sns_iface,
    "ReleaseAccelerometer",
    [],
  )
  result
}
