// 音量模块白盒测试：输出解析（真机采集的 wpctl/pactl 真实输出样例断言）
// + 命令构造（两后端语法差异）+ 数值边界。样例文本来自
// XFCE + PipeWire 实机（pactl 样例为 LC_ALL=C 下的输出；子进程环境由
// vol_env_blob 固定 C locale，本地化文案不应出现，出现即解析为失败）。

///|
/// 行数组拼多行文本（每行补换行，与命令行工具输出一致）。
fn vol_lines(lines : Array[String]) -> String {
  let buf = StringBuilder()
  for l in lines {
    buf.write_string(l)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
test "vol_parse_wpctl_volume：真实输出样例" {
  // 实机当前输出
  assert_eq(vol_parse_wpctl_volume("Volume: 1.00"), Some((100, false)))
  // 常见形态
  assert_eq(vol_parse_wpctl_volume("Volume: 0.42"), Some((42, false)))
  assert_eq(vol_parse_wpctl_volume("Volume: 0.00 [MUTED]"), Some((0, true)))
  assert_eq(vol_parse_wpctl_volume("Volume: 0.42 [MUTED]"), Some((42, true)))
  assert_eq(vol_parse_wpctl_volume("Volume: 1.00 [MUTED]"), Some((100, true)))
  // 超量程钳到 100
  assert_eq(vol_parse_wpctl_volume("Volume: 1.20"), Some((100, false)))
  // 尾随换行 / 前导空白
  assert_eq(vol_parse_wpctl_volume("Volume: 0.60\n"), Some((60, false)))
  // 解析失败：非量纲文本 / 空输出 / 缺数值
  assert_true(vol_parse_wpctl_volume("wpctl: PipeWire is not running") is None)
  assert_true(vol_parse_wpctl_volume("") is None)
  assert_true(vol_parse_wpctl_volume("Volume:") is None)
}

///|
test "vol_parse_volume_text：小数/舍入/非法" {
  assert_eq(vol_parse_volume_text("0.42"), Some(42))
  assert_eq(vol_parse_volume_text("1.00"), Some(100))
  assert_eq(vol_parse_volume_text("0.425"), Some(43)) // 第三位四舍五入
  assert_eq(vol_parse_volume_text("0.424"), Some(42))
  assert_eq(vol_parse_volume_text("1.20"), Some(120)) // 超量程如实返回
  assert_eq(vol_parse_volume_text("0"), Some(0))
  assert_eq(vol_parse_volume_text("0.99"), Some(99))
  assert_true(vol_parse_volume_text("") is None)
  assert_true(vol_parse_volume_text("abc") is None)
  assert_true(vol_parse_volume_text("1.") is None) // 尾点非法
  assert_true(vol_parse_volume_text(".5") is None) // 无整数部非法
  assert_true(vol_parse_volume_text("0.1.2") is None) // 双点非法
}

///|
test "vol_parse_wpctl_status_sink：真实 status 样例（Audio/Video 分段）" {
  // 实机 wpctl status 全文：Audio 段 Sinks 的 '*' 行是默认 sink，
  // Video 段也有空的 Sinks 小节，Settings 段含配置名，均不得误取
  let real = vol_lines([
      "PipeWire 'pipewire-0' [1.0.5, lkyh@lkyh-fe, cookie:2856786529]",
      " └─ Clients:",
      "        32. pipewire                            [1.0.5, lkyh@lkyh-fe, pid:1688]",
      "        53. xfce4-pulseaudio-plugin             [1.0.5, lkyh@lkyh-fe, pid:114247]",
      "",
      "Audio",
      " ├─ Devices:",
      " │      46. GA104 High Definition Audio Controller [alsa]",
      " │      47. Built-in Audio                      [alsa]",
      " ├─ Sinks:",
      " │  *   33. Built-in Audio 模拟立体声      [vol: 1.00]",
      " │      48. GA104 High Definition Audio Controller 数字立体声(HDMI) [vol: 0.36]",
      " ├─ Sources:",
      " │  *   55. GA104 High Definition Audio Controller 数字立体声(HDMI) [vol: 0.60]",
      " ├─ Sink endpoints:",
      " ├─ Source endpoints:",
      " └─ Streams:",
      "",
      "Video",
      " ├─ Devices:",
      " ├─ Sinks:",
      " ├─ Sources:",
      " └─ Streams:",
      "",
      "Settings",
      " └─ Default Configured Node Names:",
      "         0. Audio/Sink    alsa_output.pci-0000_00_1f.3.analog-stereo",
    ])
  assert_eq(
    vol_parse_wpctl_status_sink(real),
    Some("Built-in Audio 模拟立体声"),
  )
  // 默认 sink 不在首位：仍取带 '*' 的那行
  let swapped = vol_lines([
      "Audio",
      " ├─ Sinks:",
      " │      48. GA104 数字立体声(HDMI) [vol: 0.36]",
      " │  *   33. Built-in Audio 模拟立体声 [vol: 1.00]",
      " ├─ Sources:",
    ])
  assert_eq(
    vol_parse_wpctl_status_sink(swapped),
    Some("Built-in Audio 模拟立体声"),
  )
  // 无默认 sink（无 '*' 行）
  let nostar = vol_lines([
      "Audio",
      " ├─ Sinks:",
      " │      33. Built-in Audio 模拟立体声 [vol: 1.00]",
      " ├─ Sources:",
    ])
  assert_true(vol_parse_wpctl_status_sink(nostar) is None)
  // 无 Audio 段
  assert_true(vol_parse_wpctl_status_sink("Video\n ├─ Sinks:\n") is None)
}

///|
test "vol_parse_pactl_percent：真实输出样例（取声道最大值）" {
  // 实机输出（LC_ALL=C）：双声道 100%
  let full = vol_lines([
      "Volume: front-left: 65536 / 100% / 0.00 dB,   front-right: 65536 / 100% / 0.00 dB",
      "        balance 0.00",
    ])
  assert_eq(vol_parse_pactl_percent(full), Some(100))
  // 声道不一致取最大
  let uneven = vol_lines([
      "Volume: front-left: 32768 /  50% / -18.06 dB,   front-right: 29491 /  45% / -21.07 dB",
      "        balance 0.00",
    ])
  assert_eq(vol_parse_pactl_percent(uneven), Some(50))
  // 单声道
  assert_eq(
    vol_parse_pactl_percent("Volume: front-left: 13107 /  20% / -34.19 dB"),
    Some(20),
  )
  // 无百分比 / 垃圾输出
  assert_true(vol_parse_pactl_percent("Connection failure: Connection refused") is None)
  assert_true(vol_parse_pactl_percent("") is None)
}

///|
test "vol_parse_pactl_mute：C locale 文案与本地化拒绝" {
  assert_eq(vol_parse_pactl_mute("Mute: no"), Some(false))
  assert_eq(vol_parse_pactl_mute("Mute: yes"), Some(true))
  // 本地化文案（未固 C locale 时才会出现）一律解析失败
  assert_true(vol_parse_pactl_mute("Mute: 否") is None)
  assert_true(vol_parse_pactl_mute("Mute: 是") is None)
  assert_true(vol_parse_pactl_mute("") is None)
  assert_true(vol_parse_pactl_mute("Sink 33 not found") is None)
}

///|
test "vol_clamp_percent：边界钳制" {
  assert_eq(vol_clamp_percent(-1), 0)
  assert_eq(vol_clamp_percent(0), 0)
  assert_eq(vol_clamp_percent(42), 42)
  assert_eq(vol_clamp_percent(100), 100)
  assert_eq(vol_clamp_percent(101), 100)
  assert_eq(vol_clamp_percent(1000), 100)
}

///|
test "vol_set_args/vol_add_args/vol_mute_args：两后端语法" {
  // 绝对设置：两后端百分比语法相同，入参钳制
  debug_inspect(
    vol_set_args(Wpctl, 50),
    content="[\"set-volume\", \"@DEFAULT_SINK@\", \"50%\"]",
  )
  debug_inspect(
    vol_set_args(Pactl, 150),
    content="[\"set-sink-volume\", \"@DEFAULT_SINK@\", \"100%\"]",
  )
  debug_inspect(
    vol_set_args(Pactl, -5),
    content="[\"set-sink-volume\", \"@DEFAULT_SINK@\", \"0%\"]",
  )
  // 相对增减：wpctl 后缀 "5%+"/"5%-"，pactl 前缀 "+5%"/"-5%"
  debug_inspect(
    vol_add_args(Wpctl, 5),
    content="[\"set-volume\", \"@DEFAULT_SINK@\", \"5%+\"]",
  )
  debug_inspect(
    vol_add_args(Wpctl, -5),
    content="[\"set-volume\", \"@DEFAULT_SINK@\", \"5%-\"]",
  )
  debug_inspect(
    vol_add_args(Pactl, 5),
    content="[\"set-sink-volume\", \"@DEFAULT_SINK@\", \"+5%\"]",
  )
  debug_inspect(
    vol_add_args(Pactl, -5),
    content="[\"set-sink-volume\", \"@DEFAULT_SINK@\", \"-5%\"]",
  )
  // 静音：1/0
  debug_inspect(
    vol_mute_args(Wpctl, true),
    content="[\"set-mute\", \"@DEFAULT_SINK@\", \"1\"]",
  )
  debug_inspect(
    vol_mute_args(Pactl, false),
    content="[\"set-sink-mute\", \"@DEFAULT_SINK@\", \"0\"]",
  )
}

///|
test "vol_split_ws/vol_trim/vol_parse_uint：文本工具" {
  debug_inspect(vol_split_ws("  a\tb  c "), content="[\"a\", \"b\", \"c\"]")
  debug_inspect(vol_split_ws(""), content="[]")
  assert_eq(vol_trim("  x  "), "x")
  assert_eq(vol_trim(""), "")
  assert_eq(vol_trim("   "), "")
  assert_eq(vol_parse_uint("100"), Some(100))
  assert_eq(vol_parse_uint("0"), Some(0))
  assert_true(vol_parse_uint("") is None)
  assert_true(vol_parse_uint("12a") is None)
}

///|
test "vol_get 真机只读冒烟（无音量工具时跳过）" {
  if !vol_supported() {
    println("vol: skip (no wpctl/pactl)")
    return
  }
  match vol_get() {
    Ok(info) => {
      assert_true(info.volume >= 0 && info.volume <= 100)
      println("vol: \{info}")
    }
    Err(e) => {
      println("vol_get failed: \{e}")
      assert_true(false)
    }
  }
}
