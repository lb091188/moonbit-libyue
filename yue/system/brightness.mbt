// 屏幕亮度与键盘背光:统一语义 supported / devices / get / set_percent /
// step_percent,屏幕走 "backlight" 子系统,键盘背光走 "leds" 子系统。
// Linux 实现:设置经 logind 的 SetBrightness(系统总线,session/auto
// 对象,@traybus 层封装);设备枚举与当前值读 /sys/class/<子系统>/
// <设备名> 的 sysfs 属性(brightness / max_brightness),枚举按常见设备
// 名探测,探测表序即推荐序,表外设备可手工构造 BrightnessDevice 访问。
// 其余平台 Unsupported。sysfs 文本解析与百分比换算为纯函数(bright_
// 前缀),brightness_wbtest.mbt 白盒覆盖。
//
// 典型用法:
//   match brightness_devices() {
//     Ok(devs) if devs.length() > 0 =>
//       brightness_set_percent(devs[0], 50) // 半亮
//     _ => ()
//   }

///|
/// 亮度设备:subsystem 为 "backlight"(屏幕)或 "leds"(键盘背光),
/// name 为 sysfs 设备名;max 为量程上限,current 为枚举时的原始值快照
/// (实时值用 [brightness_get] / [kbd_brightness_get])。
pub(all) struct BrightnessDevice {
  subsystem : String
  name : String
  max : Int
  current : Int // 枚举时快照,0..max
}

///|
pub impl Show for BrightnessDevice with fn output(self, logger) {
  logger.write_string("BrightnessDevice { subsystem: ")
  logger.write_string(self.subsystem)
  logger.write_string(", name: ")
  logger.write_string(self.name)
  logger.write_string(", max: ")
  logger.write_string(self.max.to_string())
  logger.write_string(", current: ")
  logger.write_string(self.current.to_string())
  logger.write_string(" }")
}

///|
pub extend BrightnessDevice with Show::{to_string, output}

///|
pub(all) enum BrightnessError {
  /// 平台/服务不支持(非 Linux;设置时 logind 不在线)
  Unsupported
  /// 总线调用失败(logind 拒绝/应答超时等),带原因
  BusFailed(String)
  /// 设备不存在(sysfs 读不到当前值)
  DeviceNotFound
  /// 非法参数(子系统/设备名/max 非法、百分比越界),带说明
  InvalidParam(String)
}

///|
pub impl Show for BrightnessError with fn output(self, logger) {
  match self {
    Unsupported => logger.write_string("BrightnessError::Unsupported")
    BusFailed(m) => logger.write_string("BrightnessError::BusFailed(\{m})")
    DeviceNotFound => logger.write_string("BrightnessError::DeviceNotFound")
    InvalidParam(m) =>
      logger.write_string("BrightnessError::InvalidParam(\{m})")
  }
}

///|
pub extend BrightnessError with Show::{to_string, output}

// ---------------------------------------------------------------------------
// 纯函数层:sysfs 文本解析 / 百分比换算 / 步进(白盒测试覆盖)
// ---------------------------------------------------------------------------

///|
/// 无符号十进制整数文本("7500" → 7500;空串或含非数字为 None)。
fn bright_parse_uint(s : String) -> Int? {
  if s == "" {
    return None
  }
  let mut v = 0
  for ch in s {
    if ch < '0' || ch > '9' {
      return None
    }
    v = v * 10 + (ch.to_int() - 48)
  }
  Some(v)
}

///|
/// sysfs 整数属性文本 → 值(容忍首尾空白与结尾换行;非法为 None)。
fn bright_parse_sysfs(text : String) -> Int? {
  bright_parse_uint(text.trim().to_owned())
}

///|
/// 百分比钳到 0..100。
fn bright_clamp_percent(p : Int) -> Int {
  if p < 0 {
    0
  } else if p > 100 {
    100
  } else {
    p
  }
}

///|
/// 原始值 → 百分比(0-100,四舍五入;value 出量程钳制,max <= 0 或
/// value <= 0 为 0)。
fn bright_percent(value : Int, max : Int) -> Int {
  if max <= 0 || value <= 0 {
    return 0
  }
  let v = if value > max { max } else { value }
  (v * 100 + max / 2) / max
}

///|
/// 百分比 → 原始值(0..max,四舍五入;percent 先钳 0-100,max <= 0
/// 为 0)。
fn bright_value_of(percent : Int, max : Int) -> Int {
  if max <= 0 {
    return 0
  }
  let p = bright_clamp_percent(percent)
  (p * max + 50) / 100
}

///|
/// 百分比步进:cur 加 delta 后钳 0-100(cur 界外先钳,delta 先钳
/// ±101,极端值不回绕)。
fn bright_step(cur : Int, delta : Int) -> Int {
  let d = if delta > 101 { 101 } else if delta < -101 { -101 } else { delta }
  bright_clamp_percent(bright_clamp_percent(cur) + d)
}

// ---------------------------------------------------------------------------
// sysfs 读取与设备探测
// ---------------------------------------------------------------------------

///|
/// 设备 sysfs 属性路径:/sys/class/<subsystem>/<name>/<attr>。
fn bright_sysfs_attr(
  subsystem : String,
  name : String,
  attr : String,
) -> String {
  "/sys/class/" + subsystem + "/" + name + "/" + attr
}

///|
/// 读 sysfs 整数属性(读不到或解析失败为 None)。
fn bright_read_sysfs_int(
  subsystem : String,
  name : String,
  attr : String,
) -> Int? {
  match @yue.read_text_file(bright_sysfs_attr(subsystem, name, attr)) {
    Some(text) => bright_parse_sysfs(text)
    None => None
  }
}

///|
/// 屏幕背光设备名探测表(探测序即推荐序:原生驱动在前,通用/ACPI
/// 兼容层在后)。
let bright_backlight_names : Array[String] = [
  "intel_backlight", "amdgpu_bl0", "amdgpu_bl1", "amdgpu_bl2", "radeon_bl0", "radeon_bl1",
  "nouveau_bl0", "nvidia_wmi_ec_backlight", "nv_backlight", "apple_backlight", "dell_uart_backlight",
  "thinkpad_screen", "asus-nb-wmi", "toshiba", "panasonic", "sony", "fujitsu-lbs",
  "acer-wmi", "hp-wmi", "pwm_backlight", "pwm-backlight", "acpi_video0", "acpi_video1",
  "acpi_video2", "acpi_video3", "acpi_video4",
]

///|
/// 键盘背光 LED 名探测表:厂商固定名在前,后接 input0..15 的
/// "::kbd_backlight" 扫描(HID 键盘背光的 input 序号因机而异)。
fn bright_kbd_names() -> Array[String] {
  let names : Array[String] = [
    "tpacpi::kbd_backlight", "dell::kbd_backlight", "asus::kbd_backlight", "lenovo::kbd_backlight",
    "platform::kbd_backlight", "chromeos::kbd_backlight", "system76_acpi::kbd_backlight",
  ]
  for i in 0..<16 {
    names.push("input\{i}::kbd_backlight")
  }
  names
}

///|
/// 按候选名探测一类设备:max_brightness 可读且 > 0 即收录,current 取
/// 枚举时快照(读不到记 0)。
fn bright_probe_devices(
  subsystem : String,
  names : Array[String],
) -> Array[BrightnessDevice] {
  let out : Array[BrightnessDevice] = []
  for name in names {
    match bright_read_sysfs_int(subsystem, name, "max_brightness") {
      Some(max) =>
        if max > 0 {
          let current = match
            bright_read_sysfs_int(subsystem, name, "brightness") {
            Some(v) => v
            None => 0
          }
          out.push({ subsystem, name, max, current, })
        }
      None => ()
    }
  }
  out
}

///|
/// 设备描述校验:subsystem 限 "backlight"/"leds" 且与 expected 一致,
/// name 非空且不含 '/',max > 0。
fn bright_check_dev(
  dev : BrightnessDevice,
  expected : String,
) -> Result[Unit, BrightnessError] {
  if dev.subsystem != "backlight" && dev.subsystem != "leds" {
    return Err(InvalidParam("子系统非法: \{dev.subsystem}"))
  }
  if dev.subsystem != expected {
    return Err(
      InvalidParam("子系统不符: \{dev.subsystem}(期望 \{expected})"),
    )
  }
  if dev.name == "" {
    return Err(InvalidParam("设备名为空"))
  }
  if dev.name.contains("/") {
    return Err(InvalidParam("设备名含 '/': \{dev.name}"))
  }
  if dev.max <= 0 {
    return Err(InvalidParam("max 非法: \{dev.max}"))
  }
  Ok(())
}

// ---------------------------------------------------------------------------
// 公开 API(屏幕亮度 brightness_*;键盘背光 kbd_brightness_*)
// ---------------------------------------------------------------------------

///|
/// 屏幕亮度调节是否可用:Linux 看 logind 在线(设置走其 SetBrightness;
// devices/get 只读 sysfs 不依赖它)。每次调用真实探测。
pub fn brightness_supported() -> Bool {
  match @yue.platform() {
    "linux" => @traybus.logind_available()
    _ => false
  }
}

///|
/// 枚举屏幕背光设备(按探测表读 /sys/class/backlight,列表序即推荐序;
/// 空列表 = 无背光设备或设备名不在探测表,后者可手工构造
/// BrightnessDevice 访问)。
pub fn brightness_devices() -> Result[Array[BrightnessDevice], BrightnessError] {
  match @yue.platform() {
    "linux" => Ok(bright_probe_devices("backlight", bright_backlight_names))
    _ => Err(Unsupported)
  }
}

///|
/// 屏幕当前亮度百分比(0-100,实时读 sysfs)。
pub fn brightness_get(dev : BrightnessDevice) -> Result[Int, BrightnessError] {
  bright_get_impl(dev, "backlight")
}

///|
/// 设置屏幕亮度百分比(0-100;写走 logind,logind 不在线返回
/// Unsupported)。
pub fn brightness_set_percent(
  dev : BrightnessDevice,
  percent : Int,
) -> Result[Unit, BrightnessError] {
  bright_set_impl(dev, "backlight", percent)
}

///|
/// 屏幕亮度按百分比步进(delta 可正可负;先读当前值,加 delta 钳 0-100
/// 后设置)。
pub fn brightness_step_percent(
  dev : BrightnessDevice,
  delta : Int,
) -> Result[Unit, BrightnessError] {
  bright_step_impl(dev, "backlight", delta)
}

///|
/// 键盘背光是否可用:Linux 看 logind 在线;有无键盘背光设备以
/// kbd_brightness_devices 的空列表判。每次调用真实探测。
pub fn kbd_brightness_supported() -> Bool {
  match @yue.platform() {
    "linux" => @traybus.logind_available()
    _ => false
  }
}

///|
/// 枚举键盘背光设备(探测 /sys/class/leds 下的 *::kbd_backlight 常见
/// 名;空列表 = 无键盘背光)。
pub fn kbd_brightness_devices() -> Result[
  Array[BrightnessDevice],
  BrightnessError,
] {
  match @yue.platform() {
    "linux" => Ok(bright_probe_devices("leds", bright_kbd_names()))
    _ => Err(Unsupported)
  }
}

///|
/// 键盘背光当前百分比(0-100,实时读 sysfs)。
pub fn kbd_brightness_get(
  dev : BrightnessDevice,
) -> Result[Int, BrightnessError] {
  bright_get_impl(dev, "leds")
}

///|
/// 设置键盘背光百分比(0-100;写走 logind,logind 不在线返回
/// Unsupported)。
pub fn kbd_brightness_set_percent(
  dev : BrightnessDevice,
  percent : Int,
) -> Result[Unit, BrightnessError] {
  bright_set_impl(dev, "leds", percent)
}

///|
/// 键盘背光按百分比步进(delta 可正可负;先读当前值,加 delta 钳 0-100
/// 后设置)。
pub fn kbd_brightness_step_percent(
  dev : BrightnessDevice,
  delta : Int,
) -> Result[Unit, BrightnessError] {
  bright_step_impl(dev, "leds", delta)
}

// ---------------------------------------------------------------------------
// 公开 API 公共实现
// ---------------------------------------------------------------------------

///|
/// 读当前百分比公共实现(平台门 → 设备校验 → 读 sysfs 换算)。
fn bright_get_impl(
  dev : BrightnessDevice,
  expected : String,
) -> Result[Int, BrightnessError] {
  match @yue.platform() {
    "linux" => {
      match bright_check_dev(dev, expected) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      match bright_read_sysfs_int(dev.subsystem, dev.name, "brightness") {
        Some(v) => Ok(bright_percent(v, dev.max))
        None => Err(DeviceNotFound)
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// 设置百分比公共实现(平台门 → logind 在线 → 设备与参数校验 → 调用)。
fn bright_set_impl(
  dev : BrightnessDevice,
  expected : String,
  percent : Int,
) -> Result[Unit, BrightnessError] {
  match @yue.platform() {
    "linux" => {
      if !@traybus.logind_available() {
        return Err(Unsupported)
      }
      match bright_check_dev(dev, expected) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      if percent < 0 || percent > 100 {
        return Err(InvalidParam("百分比越界: \{percent}"))
      }
      match
        @traybus.bright_set_brightness(
          dev.subsystem,
          dev.name,
          bright_value_of(percent, dev.max),
        ) {
        Ok(_) => Ok(())
        Err(e) => Err(BusFailed(e))
      }
    }
    _ => Err(Unsupported)
  }
}

///|
/// 步进公共实现(平台门 → logind 在线 → 设备校验 → 读当前值 → 加
/// delta 钳制后调用)。
fn bright_step_impl(
  dev : BrightnessDevice,
  expected : String,
  delta : Int,
) -> Result[Unit, BrightnessError] {
  match @yue.platform() {
    "linux" => {
      if !@traybus.logind_available() {
        return Err(Unsupported)
      }
      match bright_check_dev(dev, expected) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
      match bright_read_sysfs_int(dev.subsystem, dev.name, "brightness") {
        None => return Err(DeviceNotFound)
        Some(v) => {
          let target = bright_step(bright_percent(v, dev.max), delta)
          match
            @traybus.bright_set_brightness(
              dev.subsystem,
              dev.name,
              bright_value_of(target, dev.max),
            ) {
            Ok(_) => Ok(())
            Err(e) => Err(BusFailed(e))
          }
        }
      }
    }
    _ => Err(Unsupported)
  }
}
