// 电源:电量查询与交直流切换事件。Linux 走 UPower(系统总线),Windows
// 走 GetSystemPowerStatus(查询;交直流事件随电源消息窗口批次接入);
// macOS 暂缓。

///|
/// 电量读数。充电中含"已充满仍接着电源";时间字段 None = 系统未给出。
pub struct BatteryInfo {
  percent : Int // 0-100
  charging : Bool
  charging_seconds : Int? // 距充满秒数
  discharging_seconds : Int? // 距放空秒数
}

///|
/// 当前平台是否支持电量查询(macOS 暂缓;Linux 看 UPower 是否真实在线)。
pub fn battery_supported() -> Bool {
  match platform() {
    "linux" => @traybus.upower_available()
    "windows" => true
    _ => false
  }
}

///|
/// 查询电量;无电池(台式机)返回 Ok(None),服务不在线返回
/// Err(Unsupported)——"环境没有"与"查询失败"分开。
pub fn battery_query() -> Result[BatteryInfo?, PowerError] {
  match platform() {
    "linux" => {
      if !@traybus.upower_available() {
        return Err(Unsupported)
      }
      match @traybus.upower_battery() {
        Ok(None) => Ok(None)
        Ok(Some((percent, charging, t_full, t_empty))) =>
          Ok(Some({
            percent,
            charging,
            charging_seconds: if t_full > 0L { Some(t_full.to_int()) } else { None },
            discharging_seconds: if t_empty > 0L {
              Some(t_empty.to_int())
            } else {
              None
            },
          }))
        Err(e) => Err(QueryFailed(e))
      }
    }
    "windows" => {
      let ac = Ref(0)
      let percent = Ref(0)
      let charging = Ref(0)
      let has = Ref(0)
      let r = ffi_win_power_status(ac, percent, charging, has)
      if r != 0 {
        return Err(QueryFailed("GetSystemPowerStatus 失败"))
      }
      if has.val != 1 {
        return Ok(None)
      }
      Ok(Some({
        percent: if percent.val < 0 { 0 } else { percent.val },
        charging: charging.val == 1,
        // GetSystemPowerStatus 不给剩余时间(BatteryLifeTime 按"秒"但
        // 交流在线时语义是放空时间,且常为 -1),统一不给数
        charging_seconds: None,
        discharging_seconds: None,
      }))
    }
    _ => Err(Unsupported)
  }
}

///|
/// 电源来源。
pub enum PowerSource {
  /// 交流在线(接着电源)
  Ac
  /// 电池供电
  OnBattery
}

///|
pub impl Show for PowerSource with fn output(self, logger) {
  match self {
    Ac => logger.write_string("PowerSource::Ac")
    OnBattery => logger.write_string("PowerSource::OnBattery")
  }
}

///|
pub extend PowerSource with Show::{to_string, output}

///|
/// 交直流切换事件是否可用(Windows 事件接入随电源消息窗口批次)。
pub fn power_event_supported() -> Bool {
  match platform() {
    "linux" => @traybus.upower_available()
    _ => false
  }
}

///|
/// 注册交直流切换回调(可多次注册;不支持的平台静默忽略,先以
/// power_event_supported 判定)。Linux 语义:UPower 顶层 OnBattery
/// 属性变化即派发。
pub fn on_power_source_change(cb : (PowerSource) -> Unit) -> Unit {
  match platform() {
    "linux" => {
      let _ = @traybus.upower_on_change(fn(on_batt) {
        cb(if on_batt { OnBattery } else { Ac })
      })
      ()
    }
    _ => ()
  }
}
