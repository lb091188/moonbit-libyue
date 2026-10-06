// logind 亮度(系统总线):当前会话对象(/org/freedesktop/login1/session/
// auto)的 SetBrightness(ssu) 调用封装——subsystem 取 "backlight"(屏幕
// 背光)或 "leds"(键盘背光),name 为 sysfs 设备名,value 为该设备量程
// 内的原始值。设备枚举与当前值查询不经 D-Bus(logind 无对应接口),由
// yue 层读 /sys/class/<subsystem> 完成。

///|
/// logind 自动会话对象路径(解析到调用进程所在会话)。
const BRIGHT_SESSION_AUTO_PATH : String = "/org/freedesktop/login1/session/auto"

///|
/// 设置亮度:对当前会话调用 SetBrightness(ssu)。value 为该设备量程内
/// 原始值(0..max_brightness);权限不足/设备不存在/总线断开等以
/// Err(错误名或原因) 返回。
pub fn bright_set_brightness(
  subsystem : String,
  name : String,
  value : Int,
) -> Result[Unit, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  match
    c.call_sync(
      LOGIND,
      BRIGHT_SESSION_AUTO_PATH,
      "org.freedesktop.login1.Session",
      "SetBrightness",
      "ssu",
      [VString(subsystem), VString(name), VU32(value)],
    ) {
    Ok(_m) => Ok(())
    Err(e) => Err(e)
  }
}
