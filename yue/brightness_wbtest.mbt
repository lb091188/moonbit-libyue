// 亮度模块白盒测试:sysfs 文本解析、百分比换算与步进钳制、设备校验、
// 探测表内容与 sysfs 路径拼装(纯逻辑;不连总线、不读真实 /sys、不改
// 真实亮度)。

///|
test "bright_parse_sysfs:常规/空白容忍/非法" {
  assert_eq(bright_parse_sysfs("7500\n"), Some(7500))
  assert_eq(bright_parse_sysfs("7500"), Some(7500))
  assert_eq(bright_parse_sysfs("  42  \n"), Some(42))
  assert_eq(bright_parse_sysfs("0\n"), Some(0))
  assert_true(bright_parse_sysfs("") is None)
  assert_true(bright_parse_sysfs("\n") is None)
  assert_true(bright_parse_sysfs("abc") is None)
  assert_true(bright_parse_sysfs("12x") is None)
  assert_true(bright_parse_sysfs("-5") is None) // sysfs 亮度恒非负
}

///|
test "bright_percent:换算/四舍五入/钳制/退化" {
  assert_eq(bright_percent(500, 1000), 50)
  assert_eq(bright_percent(0, 1000), 0)
  assert_eq(bright_percent(1000, 1000), 100)
  assert_eq(bright_percent(1, 3), 33) // 33.33 舍
  assert_eq(bright_percent(2, 3), 67) // 66.67 入
  assert_eq(bright_percent(1, 6), 17) // 16.67 入
  assert_eq(bright_percent(5, 6), 83) // 83.33 舍
  assert_eq(bright_percent(1200, 1000), 100) // 越上界钳
  assert_eq(bright_percent(-5, 1000), 0) // 负值按 0
  assert_eq(bright_percent(10, 0), 0) // max 退化
  assert_eq(bright_percent(10, -3), 0) // max 负值退化
}

///|
test "bright_value_of:换算/四舍五入/钳制/退化" {
  assert_eq(bright_value_of(0, 7500), 0)
  assert_eq(bright_value_of(100, 7500), 7500)
  assert_eq(bright_value_of(50, 7500), 3750)
  assert_eq(bright_value_of(1, 7500), 75)
  assert_eq(bright_value_of(33, 3), 1) // 0.99 入
  assert_eq(bright_value_of(50, 7), 4) // 3.5 入
  assert_eq(bright_value_of(49, 7), 3) // 3.43 舍
  assert_eq(bright_value_of(120, 100), 100) // 越界钳
  assert_eq(bright_value_of(-5, 100), 0)
  assert_eq(bright_value_of(50, 0), 0) // max 退化
}

///|
test "bright_step:常规/上下钳/极端 delta 不回绕" {
  assert_eq(bright_step(50, 10), 60)
  assert_eq(bright_step(50, -10), 40)
  assert_eq(bright_step(95, 10), 100)
  assert_eq(bright_step(5, -10), 0)
  assert_eq(bright_step(100, -100), 0)
  assert_eq(bright_step(0, 100), 100)
  assert_eq(bright_step(50, 2147483647), 100) // Int 上界
  assert_eq(bright_step(50, -2147483648), 0) // Int 下界
  assert_eq(bright_step(-20, 30), 30) // 当前值界外先钳到 0
  assert_eq(bright_step(130, -20), 80) // 当前值界外先钳到 100
}

///|
test "bright_check_dev:子系统/设备名/max 校验" {
  let ok : BrightnessDevice = {
    subsystem: "backlight",
    name: "intel_backlight",
    max: 7500,
    current: 0,
  }
  assert_true(bright_check_dev(ok, "backlight") is Ok(_))
  assert_true(bright_check_dev(ok, "leds") is Err(InvalidParam(_)))
  let bad_sub : BrightnessDevice = {
    subsystem: "video",
    name: "x",
    max: 10,
    current: 0,
  }
  assert_true(bright_check_dev(bad_sub, "video") is Err(InvalidParam(_)))
  let mixed : BrightnessDevice = {
    subsystem: "leds",
    name: "input3::kbd_backlight",
    max: 3,
    current: 0,
  }
  assert_true(bright_check_dev(mixed, "backlight") is Err(InvalidParam(_)))
  let slash : BrightnessDevice = { subsystem: "leds", name: "a/b", max: 10, current: 0, }
  assert_true(bright_check_dev(slash, "leds") is Err(InvalidParam(_)))
  let empty_name : BrightnessDevice = { subsystem: "leds", name: "", max: 10, current: 0, }
  assert_true(bright_check_dev(empty_name, "leds") is Err(InvalidParam(_)))
  let no_max : BrightnessDevice = { subsystem: "leds", name: "x", max: 0, current: 0, }
  assert_true(bright_check_dev(no_max, "leds") is Err(InvalidParam(_)))
}

///|
test "探测表:屏幕背光原生优先、ACPI 兼容垫后" {
  assert_eq(bright_backlight_names[0], "intel_backlight")
  assert_true(bright_backlight_names.contains("amdgpu_bl0"))
  assert_true(bright_backlight_names.contains("thinkpad_screen"))
  // intel_backlight 必须排在 acpi_video0 之前(推荐序)
  let mut native_at = -1
  let mut acpi_at = -1
  for i, name in bright_backlight_names {
    if name == "intel_backlight" {
      native_at = i
    }
    if name == "acpi_video0" {
      acpi_at = i
    }
  }
  assert_true(native_at >= 0 && acpi_at > native_at)
}

///|
test "探测表:键盘背光含厂商固定名与 input 扫描" {
  let names = bright_kbd_names()
  assert_true(names.contains("tpacpi::kbd_backlight"))
  assert_true(names.contains("dell::kbd_backlight"))
  assert_true(names.contains("asus::kbd_backlight"))
  assert_true(names.contains("input0::kbd_backlight"))
  assert_true(names.contains("input15::kbd_backlight"))
  assert_true(!names.contains("input16::kbd_backlight"))
}

///|
test "sysfs 属性路径拼装" {
  assert_eq(
    bright_sysfs_attr("backlight", "intel_backlight", "max_brightness"),
    "/sys/class/backlight/intel_backlight/max_brightness",
  )
  assert_eq(
    bright_sysfs_attr("leds", "input3::kbd_backlight", "brightness"),
    "/sys/class/leds/input3::kbd_backlight/brightness",
  )
}

///|
test "Show 输出:错误枚举与设备" {
  let e1 : BrightnessError = Unsupported
  assert_eq(e1.to_string(), "BrightnessError::Unsupported")
  let e2 : BrightnessError = DeviceNotFound
  assert_eq(e2.to_string(), "BrightnessError::DeviceNotFound")
  let e3 : BrightnessError = BusFailed("总线应答超时")
  assert_eq(e3.to_string(), "BrightnessError::BusFailed(总线应答超时)")
  let e4 : BrightnessError = InvalidParam("百分比越界: 150")
  assert_eq(e4.to_string(), "BrightnessError::InvalidParam(百分比越界: 150)")
  let d : BrightnessDevice = {
    subsystem: "backlight",
    name: "b0",
    max: 100,
    current: 25,
  }
  assert_eq(
    d.to_string(),
    "BrightnessDevice { subsystem: backlight, name: b0, max: 100, current: 25 }",
  )
}
