// UPower(系统总线):电量查询与交直流事件。DisplayDevice 是聚合显示
// 设备——笔记本反映主电池,台式机 IsPresent=false;接口名注意区分:
// 设备属性接口是 org.freedesktop.UPower.Device,顶层是 org.freedesktop.UPower,
// PropertiesChanged 的 arg0 过滤天然不会把设备级信号混进顶层订阅。

///|
const UPOWER : String = "org.freedesktop.UPower"

///|
const UPOWER_DEVICE_PATH : String = "/org/freedesktop/UPower/devices/DisplayDevice"

///|
/// UPower 是否在线(系统总线 NameHasOwner 真实探测,不猜)。
pub fn upower_available() -> Bool {
  match system_conn() {
    Err(_) => false
    Ok(c) =>
      match c.call_sync(
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "NameHasOwner",
          "s",
          [VString(UPOWER)],
        ) {
        Ok(m) =>
          match m.body.get(0) {
            Some(VBool(true)) => true
            _ => false
          }
        Err(_) => false
      }
  }
}

///|
/// a{sv} 应答体 → 属性表(键 → variant 内值)。
fn props_of(m : Msg) -> Map[String, DVal] {
  let out : Map[String, DVal] = (Map([]) : Map[String, DVal])
  match m.body.get(0) {
    Some(VArray(_, items)) =>
      for it in items {
        match it {
          VStruct([VString(k), VVariant(v)]) => out.set(k, v)
          _ => ()
        }
      }
    _ => ()
  }
  out
}

///|
/// Properties.GetAll。
fn upower_get_all(
  c : Conn,
  path : String,
  iface : String,
) -> Result[Map[String, DVal], String] {
  match
    c.call_sync(
      UPOWER,
      path,
      "org.freedesktop.DBus.Properties",
      "GetAll",
      "s",
      [VString(iface)],
    ) {
    Ok(m) => Ok(props_of(m))
    Err(e) => Err(e)
  }
}

///|
/// DisplayDevice 电量读数:(百分比, 充电中, 距充满秒, 距放空秒)。
/// 无电池(或读不到 IsPresent)返回 None——台式机的常态。
pub fn upower_battery() -> Result[(Int, Bool, Int64, Int64)?, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  match
    upower_get_all(c, UPOWER_DEVICE_PATH, "org.freedesktop.UPower.Device") {
    Err(e) => Err(e)
    Ok(props) =>
      match props.get("IsPresent") {
        Some(VBool(true)) => {
          let percent = match props.get("Percentage") {
            Some(VDouble(d)) => d.to_int()
            _ => 0
          }
          // State: 1=charging 2=discharging 4=fully_charged 5=pending_charge
          // 6=pending_discharge;接电源的充满/待充都算"接着电源"
          let state = match props.get("State") {
            Some(VU32(s)) => s
            _ => 0
          }
          let charging = state == 1 || state == 4 || state == 5
          let t_full = match props.get("TimeToFull") {
            Some(VI64(t)) => t
            _ => 0L
          }
          let t_empty = match props.get("TimeToEmpty") {
            Some(VI64(t)) => t
            _ => 0L
          }
          Ok(Some((percent, charging, t_full, t_empty)))
        }
        _ => Ok(None)
      }
  }
}

///|
/// 顶层 OnBattery 属性(true = 正在用电池)。
pub fn upower_on_battery() -> Result[Bool, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  match
    c.call_sync(
      UPOWER,
      "/org/freedesktop/UPower",
      "org.freedesktop.DBus.Properties",
      "Get",
      "ss",
      [VString(UPOWER), VString("OnBattery")],
    ) {
    Ok(m) =>
      match m.body.get(0) {
        Some(VVariant(VBool(b))) => Ok(b)
        _ => Err("OnBattery 应答类型不符")
      }
    Err(e) => Err(e)
  }
}

///|
let g_on_power : Array[(Bool) -> Unit] = []

///|
let g_upower_watched : Ref[Bool] = Ref(false)

///|
/// PropertiesChanged 体 (s 接口, a{sv} changed, as invalidated) 的
/// changed 字典里找 OnBattery 新值。
fn changed_on_battery(body : Array[DVal]) -> Bool? {
  match body.get(1) {
    Some(VArray(_, items)) => {
      for it in items {
        match it {
          VStruct([VString(k), VVariant(VBool(b))]) =>
            if k == "OnBattery" {
              return Some(b)
            }
          _ => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
/// 注册交直流变化回调(参数 true = 转入电池供电)。连接与订阅幂等建;
/// 信号回调里直接解析 PropertiesChanged 的 changed 字典,不重查——
/// 信号分发在 drain 栈上,call_sync 会重入收包路径。
pub fn upower_on_change(cb : (Bool) -> Unit) -> Result[Unit, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  if !g_upower_watched.val {
    g_upower_watched.val = true
    c.subscribe(
      "type='signal',sender='org.freedesktop.UPower',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.freedesktop.UPower'",
      "org.freedesktop.DBus.Properties.PropertiesChanged",
      fn(m) {
        // arg0 已限定顶层接口(设备接口是 …UPower.Device 进不来),
        // path 再核一道
        if m.path == "/org/freedesktop/UPower" {
          match changed_on_battery(m.body) {
            Some(b) =>
              for cb2 in g_on_power {
                cb2(b)
              }
            None => ()
          }
        }
      },
    )
  }
  g_on_power.push(cb)
  Ok(())
}
