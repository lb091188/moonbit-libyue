// 蓝牙:经 org.bluez(系统总线)查询适配器与已发现设备,支持开关电源、
// 扫描发现、连接/断开/配对。底层走 @traybus 的通用 D-Bus 层
// (gdbus_*_system),对象枚举用 ObjectManager.GetManagedObjects
// (a{oa{sa{sv}}}),属性读取用 Properties.GetAll;应答形状解析为纯函数
// (bt_objects_of_iface / bt_adapter_from / bt_device_from),
// bluetooth_wbtest.mbt 以真实形状样例白盒覆盖。
//
// 本机无蓝牙适配器是合法状态:org.bluez 不在线或枚举不到 Adapter1 时
// bt_supported() 为 false,查询类 API 返回 BtError::Unsupported,不视为
// 异常;台式机与虚拟机常见。
//
// 典型用法:
//   if bt_supported() {
//     match bt_adapter_info() {
//       Ok(a) if !a.powered => let _ = bt_set_powered(true)
//       _ => ()
//     }
//     let _ = bt_start_discovery()
//     // 数秒后 bt_devices() 见扫描到的设备
//     match bt_devices() {
//       Ok(devs) => for d in devs if !d.paired { let _ = bt_pair(d) }
//       _ => ()
//     }
//   }

///|
let bt_dest : String = "org.bluez"

///|
let bt_root : String = "/"

///|
let bt_objmanager : String = "org.freedesktop.DBus.ObjectManager"

///|
let bt_dbus_props : String = "org.freedesktop.DBus.Properties"

///|
let bt_iface_adapter : String = "org.bluez.Adapter1"

///|
let bt_iface_device : String = "org.bluez.Device1"

///|
/// 蓝牙适配器快照:path 为 D-Bus 对象路径(如 /org/bluez/hci0),address
/// 为 MAC,name 为适配器名(取不到为空串),powered 为电源开关,discovering
/// 为是否正在扫描。
pub(all) struct BtAdapter {
  path : String
  address : String
  name : String
  powered : Bool
  discovering : Bool
}

///|
pub impl Show for BtAdapter with fn output(self, logger) {
  logger.write_string("BtAdapter { path: ")
  logger.write_string(self.path)
  logger.write_string(", address: ")
  logger.write_string(self.address)
  logger.write_string(", name: ")
  logger.write_string(self.name)
  logger.write_string(", powered: ")
  logger.write_string(self.powered.to_string())
  logger.write_string(", discovering: ")
  logger.write_string(self.discovering.to_string())
  logger.write_string(" }")
}

///|
pub extend BtAdapter with Show::{to_string, output}

///|
/// 蓝牙设备快照:path 为 D-Bus 对象路径(如 /org/bluez/hci0/dev_XX_XX),
/// address 为 MAC,name 取 Name 属性(空则回退 Alias,仍空回退 MAC),
/// paired 为已配对(已信任登记),connected 为当前已连接,trusted 为已标记
/// 信任(重连时自动连接)。
pub(all) struct BtDevice {
  path : String
  address : String
  name : String
  paired : Bool
  connected : Bool
  trusted : Bool
}

///|
pub impl Show for BtDevice with fn output(self, logger) {
  logger.write_string("BtDevice { path: ")
  logger.write_string(self.path)
  logger.write_string(", address: ")
  logger.write_string(self.address)
  logger.write_string(", name: ")
  logger.write_string(self.name)
  logger.write_string(", paired: ")
  logger.write_string(self.paired.to_string())
  logger.write_string(", connected: ")
  logger.write_string(self.connected.to_string())
  logger.write_string(", trusted: ")
  logger.write_string(self.trusted.to_string())
  logger.write_string(" }")
}

///|
pub extend BtDevice with Show::{to_string, output}

///|
pub(all) enum BtError {
  /// 系统无蓝牙适配器(org.bluez 不在线,或枚举不到 Adapter1 对象)
  Unsupported
  /// D-Bus 调用失败(bluez 拒绝/应答超时等),带错误名与说明
  BusFailed(String)
  /// 设备对象路径非法(为空或不以 /org/bluez/ 开头),带说明
  InvalidParam(String)
}

///|
pub impl Show for BtError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("BtError::Unsupported")
    BusFailed(m) => logger.write_string("BtError::BusFailed(\{m})")
    InvalidParam(m) => logger.write_string("BtError::InvalidParam(\{m})")
  }
}

///|
pub extend BtError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层:ObjectManager 应答形状解析 / 属性提取 / 参数校验(白盒覆盖;
// 不连总线,样例值取自 bluez 应答的真实线协议折叠形状)
// ---------------------------------------------------------------------------

///|
/// ObjectManager.GetManagedObjects 应答中单个接口条目
/// (o, a{sa{sv}} 的值项) → (接口名, 属性字典);形状不符为 None。
fn bt_iface_props(
  entry : @traybus.GDBusValue,
) -> (String, Map[String, @traybus.GDBusValue])? {
  match entry {
    @traybus.GVStruct(
      [@traybus.GVString(iface), @traybus.GVVariant(@traybus.GVDict(props))]
    ) => Some((iface, props))
    @traybus.GVStruct([@traybus.GVString(iface), @traybus.GVDict(props)]) =>
      Some((iface, props))
    _ => None
  }
}

///|
/// 从 GetManagedObjects 应答(a{oa{sa{sv}}})中收集指定接口的
/// (对象路径, 属性字典) 列表;形状不符的片段安全跳过,总返回合法子集。
fn bt_objects_of_iface(
  v : @traybus.GDBusValue,
  want : String,
) -> Array[(String, Map[String, @traybus.GDBusValue])] {
  let out : Array[(String, Map[String, @traybus.GDBusValue])] = []
  match v {
    @traybus.GVArray(_, items) =>
      for it in items {
        match it {
          @traybus.GVStruct(
            [@traybus.GVPath(path), @traybus.GVArray(_, entries)]
          ) =>
            for entry in entries {
              match bt_iface_props(entry) {
                Some((iface, props)) =>
                  if iface == want {
                    out.push((path, props))
                  }
                None => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  out
}

///|
/// 属性字典取布尔值(类型不符或缺属性为 default)。
fn bt_prop_bool(
  props : Map[String, @traybus.GDBusValue],
  key : String,
  default : Bool,
) -> Bool {
  match props.get(key) {
    Some(@traybus.GVBool(b)) => b
    _ => default
  }
}

///|
/// 属性字典取字符串(类型不符或缺属性为空串)。
fn bt_prop_str(
  props : Map[String, @traybus.GDBusValue],
  key : String,
) -> String {
  match props.get(key) {
    Some(@traybus.GVString(s)) => s
    Some(@traybus.GVPath(s)) => s
    _ => ""
  }
}

///|
/// (对象路径, 属性字典) → 适配器快照。
fn bt_adapter_from(
  path : String,
  props : Map[String, @traybus.GDBusValue],
) -> BtAdapter {
  {
    path,
    address: bt_prop_str(props, "Address"),
    name: bt_prop_str(props, "Name"),
    powered: bt_prop_bool(props, "Powered", false),
    discovering: bt_prop_bool(props, "Discovering", false),
  }
}

///|
/// (对象路径, 属性字典) → 设备快照(name 依次回退 Name → Alias → MAC)。
fn bt_device_from(
  path : String,
  props : Map[String, @traybus.GDBusValue],
) -> BtDevice {
  let address = bt_prop_str(props, "Address")
  let name = bt_prop_str(props, "Name")
  let alias_name = bt_prop_str(props, "Alias")
  {
    path,
    address,
    name: if name != "" {
      name
    } else if alias_name != "" {
      alias_name
    } else {
      address
    },
    paired: bt_prop_bool(props, "Paired", false),
    connected: bt_prop_bool(props, "Connected", false),
    trusted: bt_prop_bool(props, "Trusted", false),
  }
}

///|
/// 设备对象路径校验:非空且以 "/org/bluez/" 开头(手工构造的设备也必须
/// 落在 bluez 命名空间内,否则无法在总线上定位)。
fn bt_device_path(device : BtDevice) -> Result[String, BtError] {
  if device.path == "" {
    return Err(BtError::InvalidParam("设备对象路径为空"))
  }
  if !device.path.has_prefix("/org/bluez/") {
    return Err(
      BtError::InvalidParam(
        "设备对象路径不在 bluez 命名空间: \{device.path}",
      ),
    )
  }
  Ok(device.path)
}

///|
/// D-Bus 调用错误 → BtError:org.bluez 服务不在线 / 总线不可达视为
/// Unsupported(等价于无蓝牙硬件),其余(bus 拒绝/超时/编码失败)为
/// BusFailed。
fn bt_bus_err(name : String, message : String) -> BtError {
  if name == "org.freedesktop.DBus.Error.ServiceUnknown" || name == "gdbus.io" {
    Unsupported
  } else {
    BusFailed("\{name}: \{message}")
  }
}

// ---------------------------------------------------------------------------
// 总线调用封装(真实查询;wbtest 不连总线)
// ---------------------------------------------------------------------------

///|
/// ObjectManager.GetManagedObjects 应答值(org.bluez 不在线 → Unsupported)。
fn bt_managed_objects() -> Result[@traybus.GDBusValue, BtError] {
  match
    @traybus.gdbus_call_system(
      bt_dest,
      bt_root,
      bt_objmanager,
      "GetManagedObjects",
      [],
    ) {
    Ok(v) => Ok(v)
    Err(e) => Err(bt_bus_err(e.name, e.message))
  }
}

///|
/// Properties.GetAll 属性字典(应答形状不符或调用失败为 Err)。
fn bt_get_all(
  path : String,
  iface : String,
) -> Result[Map[String, @traybus.GDBusValue], BtError] {
  match
    @traybus.gdbus_call_system(bt_dest, path, bt_dbus_props, "GetAll", [
      @traybus.GVString(iface),
    ]) {
    Ok(@traybus.GVDict(props)) => Ok(props)
    Ok(_) =>
      Err(BtError::BusFailed("GetAll 应答形状不符: \{path} \{iface}"))
    Err(e) => Err(bt_bus_err(e.name, e.message))
  }
}

///|
/// 适配器对象路径:枚举首个带 org.bluez.Adapter1 的对象(总线按路径字典
/// 序返回,多适配器时 /org/bluez/hci0 在前);无适配器为 Unsupported。
fn bt_adapter_path() -> Result[String, BtError] {
  match bt_managed_objects() {
    Err(e) => Err(e)
    Ok(v) => {
      let adapters = bt_objects_of_iface(v, bt_iface_adapter)
      match adapters.length() {
        0 => Err(BtError::Unsupported)
        _ => Ok(adapters[0].0)
      }
    }
  }
}

///|
/// 无参方法调用统一出口(StartDiscovery/Connect 等;成功无返回值)。
fn bt_void_call(
  path : String,
  iface : String,
  action : String,
) -> Result[Unit, BtError] {
  match @traybus.gdbus_call_system(bt_dest, path, iface, action, []) {
    Ok(_) => Ok(())
    Err(e) => Err(bt_bus_err(e.name, e.message))
  }
}

///|
/// 适配器上的无参方法调用(先定位适配器路径)。
fn bt_adapter_action(action : String) -> Result[Unit, BtError] {
  match bt_adapter_path() {
    Err(e) => Err(e)
    Ok(path) => bt_void_call(path, bt_iface_adapter, action)
  }
}

///|
/// 设备上的无参方法调用(Device1.Connect/Disconnect/Pair 均为无参)。
fn bt_device_action(
  device : BtDevice,
  action : String,
) -> Result[Unit, BtError] {
  match bt_device_path(device) {
    Err(e) => Err(e)
    Ok(path) => bt_void_call(path, bt_iface_device, action)
  }
}

// ---------------------------------------------------------------------------
// 公开 API
// ---------------------------------------------------------------------------

///|
/// 当前系统是否支持蓝牙:系统总线上 org.bluez 至少有一个 Adapter1 对象。
/// 每次调用真实探测,高频场景请调用方自行缓存结果。
pub fn bt_supported() -> Bool {
  bt_adapter_path() is Ok(_)
}

///|
/// 适配器快照(首个 Adapter1 的 Powered/Discovering/Address/Name);无
/// 蓝牙回复 Unsupported。
pub fn bt_adapter_info() -> Result[BtAdapter, BtError] {
  match bt_adapter_path() {
    Err(e) => Err(e)
    Ok(path) =>
      match bt_get_all(path, bt_iface_adapter) {
        Err(e) => Err(e)
        Ok(props) => Ok(bt_adapter_from(path, props))
      }
  }
}

///|
/// 已发现设备列表(枚举全部 org.bluez.Device1 对象)。注意含历史扫描
/// 残留对象(配对记录),以 paired/connected 区分;无蓝牙回复
/// Unsupported。
pub fn bt_devices() -> Result[Array[BtDevice], BtError] {
  match bt_managed_objects() {
    Err(e) => Err(e)
    Ok(v) => {
      let out : Array[BtDevice] = []
      for (path, props) in bt_objects_of_iface(v, bt_iface_device) {
        out.push(bt_device_from(path, props))
      }
      Ok(out)
    }
  }
}

///|
/// 开 / 关适配器电源(写 Adapter1 的 Powered 属性)。
pub fn bt_set_powered(on : Bool) -> Result[Unit, BtError] {
  match bt_adapter_path() {
    Err(e) => Err(e)
    Ok(path) =>
      match
        @traybus.gdbus_set_property_system(
          bt_dest,
          path,
          bt_iface_adapter,
          "Powered",
          @traybus.GVBool(on),
        ) {
        Ok(_) => Ok(())
        Err(e) => Err(bt_bus_err(e.name, e.message))
      }
  }
}

///|
/// 开始扫描(Adapter1.StartDiscovery;扫描到的设备经 bt_devices 查看,
/// 事件未在事件循环派发)。
pub fn bt_start_discovery() -> Result[Unit, BtError] {
  bt_adapter_action("StartDiscovery")
}

///|
/// 停止扫描(Adapter1.StopDiscovery)。
pub fn bt_stop_discovery() -> Result[Unit, BtError] {
  bt_adapter_action("StopDiscovery")
}

///|
/// 连接设备(Device1.Connect;未配对设备通常需先 bt_pair)。
pub fn bt_connect(device : BtDevice) -> Result[Unit, BtError] {
  bt_device_action(device, "Connect")
}

///|
/// 断开设备(Device1.Disconnect)。
pub fn bt_disconnect(device : BtDevice) -> Result[Unit, BtError] {
  bt_device_action(device, "Disconnect")
}

///|
/// 配对设备(Device1.Pair;配对需用户确认的授权码,过程可能持续数秒)。
pub fn bt_pair(device : BtDevice) -> Result[Unit, BtError] {
  bt_device_action(device, "Pair")
}
