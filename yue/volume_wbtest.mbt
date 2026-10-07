// 音量模块白盒测试：输出解析（真机采集的 wpctl/pactl 真实输出样例断言）
// + 命令构造（vol_ 组两后端语法差异、volx_ 组 pactl 专线）+ 数值边界。
// 样例文本来自 XFCE + PipeWire 实机（pactl 样例为 LC_ALL=C 下的输出；
// 子进程环境由 procrun 固定 C locale，本地化文案不应出现，出现即解析
// 为失败）。volx_ 组写操作只测命令构造，不真机执行。

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
    "PipeWire 'pipewire-0' [1.0.5, lkyh@lkyh-fe, cookie:2856786529]", " └─ Clients:",
    "        32. pipewire                            [1.0.5, lkyh@lkyh-fe, pid:1688]",
    "        53. xfce4-pulseaudio-plugin             [1.0.5, lkyh@lkyh-fe, pid:114247]",
    "", "Audio", " ├─ Devices:", " │      46. GA104 High Definition Audio Controller [alsa]",
    " │      47. Built-in Audio                      [alsa]", " ├─ Sinks:",
    " │  *   33. Built-in Audio 模拟立体声      [vol: 1.00]", " │      48. GA104 High Definition Audio Controller 数字立体声(HDMI) [vol: 0.36]",
    " ├─ Sources:", " │  *   55. GA104 High Definition Audio Controller 数字立体声(HDMI) [vol: 0.60]",
    " ├─ Sink endpoints:", " ├─ Source endpoints:", " └─ Streams:", "",
    "Video", " ├─ Devices:", " ├─ Sinks:", " ├─ Sources:", " └─ Streams:",
    "", "Settings", " └─ Default Configured Node Names:", "         0. Audio/Sink    alsa_output.pci-0000_00_1f.3.analog-stereo",
  ])
  assert_eq(
    vol_parse_wpctl_status_sink(real),
    Some("Built-in Audio 模拟立体声"),
  )
  // 默认 sink 不在首位：仍取带 '*' 的那行
  let swapped = vol_lines([
    "Audio", " ├─ Sinks:", " │      48. GA104 数字立体声(HDMI) [vol: 0.36]",
    " │  *   33. Built-in Audio 模拟立体声 [vol: 1.00]", " ├─ Sources:",
  ])
  assert_eq(
    vol_parse_wpctl_status_sink(swapped),
    Some("Built-in Audio 模拟立体声"),
  )
  // 无默认 sink（无 '*' 行）
  let nostar = vol_lines([
    "Audio", " ├─ Sinks:", " │      33. Built-in Audio 模拟立体声 [vol: 1.00]",
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
  assert_true(
    vol_parse_pactl_percent("Connection failure: Connection refused") is None,
  )
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

// ---------------------------------------------------------------------------
// volx_ 增强能力：pactl 列表输出解析 / 命令构造（写操作不真机执行）
// ---------------------------------------------------------------------------

///|
test "volx_parse_short_sinks：真实 list short sinks 样例" {
  // 实机输出（Tab 分隔）：INDEX / NAME / DRIVER / SAMPLE_SPEC / STATE
  let real = vol_lines([
    "49\talsa_output.pci-0000_00_1f.3.analog-stereo\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED",
    "63\talsa_output.pci-0000_01_00.1.hdmi-stereo\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED",
  ])
  let devs = volx_parse_short_sinks(real)
  assert_eq(devs.length(), 2)
  assert_eq(devs[0].name, "alsa_output.pci-0000_00_1f.3.analog-stereo")
  assert_eq(devs[1].name, "alsa_output.pci-0000_01_00.1.hdmi-stereo")
  // 样例规格列含空格不影响 name 取第 2 列；描述与默认标记留空待上层补全
  assert_eq(devs[0].description, "")
  assert_false(devs[0].is_default)
  // 非数据行：索引非十进制 / 只有一个字段 / 空输出
  assert_eq(
    volx_parse_short_sinks("n/a foo\tPipeWire\ts32le 2ch\tIDLE").length(),
    0,
  )
  assert_eq(volx_parse_short_sinks("49\n").length(), 0)
  assert_eq(volx_parse_short_sinks("").length(), 0)
}

///|
test "volx_parse_sink_pairs/volx_merge_descriptions：真实 list sinks 样例" {
  // 实机 `pactl list sinks` 关键行：属性段里的 device.description /
  // node.name 与 alsa.subdevice_name（值内含 '#'）都不得误当 Description
  // 字段或新块标题
  let sinks = vol_lines([
    "Sink #49", "\tName: alsa_output.pci-0000_00_1f.3.analog-stereo", "\tDescription: Built-in Audio 模拟立体声",
    "\tMute: no", "\tVolume: front-left: 65536 / 100% / 0.00 dB,   front-right: 65536 / 100% / 0.00 dB",
    "\tProperties:", "\t\talsa.subdevice_name = \"subdevice #0\"", "\t\tdevice.description = \"Built-in Audio\"",
    "\t\tnode.name = \"alsa_output.pci-0000_00_1f.3.analog-stereo\"", "Sink #63",
    "\tName: alsa_output.pci-0000_01_00.1.hdmi-stereo", "\tDescription: GA104 High Definition Audio Controller 数字立体声(HDMI)",
    "\tMute: no", "\tVolume: front-left: 23882 /  36% / -26.30 dB,   front-right: 23882 /  36% / -26.30 dB",
    "\tProperties:", "\t\talsa.subdevice_name = \"subdevice #0\"", "\t\tdevice.description = \"GA104 High Definition Audio Controller\"",
    "\t\tnode.name = \"alsa_output.pci-0000_01_00.1.hdmi-stereo\"",
  ])
  let pairs = volx_parse_sink_pairs(sinks)
  assert_eq(pairs.length(), 2)
  assert_eq(pairs[0].0, "alsa_output.pci-0000_00_1f.3.analog-stereo")
  assert_eq(pairs[0].1, "Built-in Audio 模拟立体声")
  assert_eq(pairs[1].0, "alsa_output.pci-0000_01_00.1.hdmi-stereo")
  assert_eq(
    pairs[1].1,
    "GA104 High Definition Audio Controller 数字立体声(HDMI)",
  )
  // 与 short sinks 列表按 name 对上，is_default 等其余字段原样保留
  let short = vol_lines([
    "49\talsa_output.pci-0000_00_1f.3.analog-stereo\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED",
    "63\talsa_output.pci-0000_01_00.1.hdmi-stereo\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED",
  ])
  let merged = volx_merge_descriptions(volx_parse_short_sinks(short), sinks)
  assert_eq(merged.length(), 2)
  assert_eq(merged[0].description, "Built-in Audio 模拟立体声")
  assert_eq(
    merged[1].description,
    "GA104 High Definition Audio Controller 数字立体声(HDMI)",
  )
  // 名字对不上的设备描述留空，is_default 等字段不动
  let lone : Array[AudioDevice] = [
    { name: "no.such.sink", description: "自带描述", is_default: true, },
  ]
  let filled = volx_merge_descriptions(lone, sinks)
  assert_eq(filled.length(), 1)
  assert_eq(filled[0].name, "no.such.sink")
  assert_eq(filled[0].description, "")
  assert_true(filled[0].is_default)
  // 长清单缺段 / 空输出：不补任何描述
  assert_eq(volx_parse_sink_pairs("").length(), 0)
  let bare = volx_merge_descriptions(lone, "")
  assert_eq(bare[0].description, "")
}

///|
test "volx_parse_sink_inputs：真实 list sink-inputs 样例（单流逐字）" {
  // 实机 `pactl list sink-inputs` 全文（LC_ALL=C）：一次 pacat 播 /dev/zero
  // 的流，音量 0%（静音数据流）、未静音，应用名取 application.name
  let real = vol_lines([
    "Sink Input #404", "\tDriver: PipeWire", "\tOwner Module: n/a", "\tClient: 403",
    "\tSink: 49", "\tSample Specification: s16le 2ch 44100Hz", "\tChannel Map: front-left,front-right",
    "\tFormat: pcm, format.sample_format = \"\\\"s16le\\\"\"  format.rate = \"44100\"  format.channels = \"2\"  format.channel_map = \"\\\"front-left,front-right\\\"\"",
    "\tCorked: no", "\tMute: no", "\tVolume: front-left: 0 /   0% / -inf dB,   front-right: 0 /   0% / -inf dB",
    "\t        balance 0.00", "\tBuffer Latency: 0 usec", "\tSink Latency: 0 usec",
    "\tResample method: PipeWire", "\tProperties:", "\t\tclient.api = \"pipewire-pulse\"",
    "\t\tpulse.server.type = \"unix\"", "\t\tapplication.name = \"pacat\"", "\t\tmedia.name = \"/dev/zero\"",
    "\t\tapplication.process.id = \"2440062\"", "\t\tapplication.process.user = \"lkyh\"",
    "\t\tapplication.process.host = \"lkyh-fe\"", "\t\tapplication.process.binary = \"pacat\"",
    "\t\tapplication.language = \"C\"", "\t\twindow.x11.display = \":0.0\"", "\t\tapplication.process.machine_id = \"7342905349eb4e1f9eabb29e7e2c6c4b\"",
    "\t\tapplication.process.session_id = \"c2\"", "\t\tnode.rate = \"1/44100\"",
    "\t\tnode.latency = \"8192/44100\"", "\t\tstream.is-live = \"true\"", "\t\tnode.name = \"pacat\"",
    "\t\tnode.want-driver = \"true\"", "\t\tnode.autoconnect = \"true\"", "\t\tmedia.class = \"Stream/Output/Audio\"",
    "\t\tadapt.follower.spa-node = \"\"", "\t\tobject.register = \"false\"", "\t\tfactory.id = \"6\"",
    "\t\tclock.quantum-limit = \"8192\"", "\t\tfactory.mode = \"split\"", "\t\taudio.adapt.follower = \"\"",
    "\t\tlibrary.name = \"audioconvert/libspa-audioconvert\"", "\t\tclient.id = \"58\"",
    "\t\tobject.id = \"63\"", "\t\tobject.serial = \"404\"", "\t\tpulse.attr.maxlength = \"4194304\"",
    "\t\tpulse.attr.tlength = \"352800\"", "\t\tpulse.attr.prebuf = \"349276\"",
    "\t\tpulse.attr.minreq = \"3528\"", "\t\tmodule-stream-restore.id = \"sink-input-by-application-name:pacat\"",
  ])
  let sts = volx_parse_sink_inputs(real)
  assert_eq(sts.length(), 1)
  assert_eq(sts[0].index, 404)
  assert_eq(sts[0].app_name, "pacat")
  assert_eq(sts[0].volume, 0)
  assert_false(sts[0].muted)
}

///|
test "volx_parse_sink_inputs：多流/派生形态（音量非零、静音、属性缺省）" {
  // 单声道最大百分比、双声道不一致取最响、静音流、application.name 缺省
  // 回落 node.name、属性全缺省记 unknown
  let two = vol_lines([
    "Sink Input #380", "\tMute: no", "\tVolume: front-left: 32768 /  75% / -5.63 dB,   front-right: 24576 /  56% / -11.06 dB",
    "\tProperties:", "\t\tapplication.name = \"Firefox\"", "\t\tnode.name = \"Firefox\"",
    "Sink Input #381", "\tMute: yes", "\tVolume: front-left: 65536 / 100% / 0.00 dB,   front-right: 65536 / 100% / 0.00 dB",
    "\tProperties:", "\t\tnode.name = \"Alsa plug-in [mpv]\"",
  ])
  let sts = volx_parse_sink_inputs(two)
  assert_eq(sts.length(), 2)
  assert_eq(sts[0].index, 380)
  assert_eq(sts[0].app_name, "Firefox")
  assert_eq(sts[0].volume, 75) // 声道不一致取最响
  assert_false(sts[0].muted)
  assert_eq(sts[1].index, 381)
  assert_eq(sts[1].app_name, "Alsa plug-in [mpv]") // application.name 缺省回落 node.name
  assert_eq(sts[1].volume, 100)
  assert_true(sts[1].muted)
  let no_props = vol_lines([
    "Sink Input #390", "\tMute: no", "\tVolume: front-left: 13107 /  20% / -34.19 dB",
  ])
  let sts2 = volx_parse_sink_inputs(no_props)
  assert_eq(sts2.length(), 1)
  assert_eq(sts2[0].app_name, "unknown") // 应用属性全缺省
  assert_eq(sts2[0].volume, 20)
  // 无播放流 / 空输出
  assert_eq(volx_parse_sink_inputs("").length(), 0)
  // 标题不带序号、且缩进行里的 '#' 不新开小节
  let junk = vol_lines([
    "Sink Input", "\tMute: no", "\tVolume: front-left: 0 /   0% / -inf dB", "\t\talsa.subdevice_name = \"subdevice #0\"",
  ])
  assert_eq(volx_parse_sink_inputs(junk).length(), 0)
  // 本地化 Mute 文案（未固 C locale 时才会出现）： muted 解析不到记 false
  let zh = vol_lines([
    "Sink Input #395", "\tMute: 否", "\tVolume: front-left: 65536 / 100% / 0.00 dB",
    "\tProperties:", "\t\tapplication.name = \"pacat\"",
  ])
  let sts3 = volx_parse_sink_inputs(zh)
  assert_eq(sts3.length(), 1)
  assert_false(sts3[0].muted)
  assert_eq(sts3[0].volume, 100)
  assert_eq(sts3[0].app_name, "pacat")
}

///|
test "volx_field/volx_unquote/volx_kv/volx_block_index/volx_yes_no：文本工具" {
  // 冒号字段取值（缩进行同样可判）
  assert_eq(volx_field("\tVolume: 50%", "Volume:"), Some("50%"))
  assert_eq(volx_field("\tMute: no", "Mute:"), Some("no"))
  assert_eq(volx_field("\tCorked: no", "Corked:"), Some("no"))
  assert_true(volx_field("Volume: 50%", "Mute:") is None)
  assert_true(volx_field("Volume: 50%", "Volume") is None) // key 必须含结尾冒号
  // 去包裹引号
  assert_eq(volx_unquote("\"pacat\""), "pacat")
  assert_eq(volx_unquote("\"\""), "")
  assert_eq(volx_unquote("pacat"), "pacat")
  assert_eq(volx_unquote("\"a"), "\"a") // 单边引号不动
  // 属性行拆 key/value
  assert_eq(
    volx_kv("application.name = \"Firefox\""),
    Some(("application.name", "Firefox")),
  )
  assert_eq(volx_kv("node.name = \"mpv\""), Some(("node.name", "mpv")))
  assert_true(volx_kv("Mute: no") is None) // 冒号行不含 '='
  assert_true(volx_kv("") is None)
  // 小节标题序号
  assert_eq(volx_block_index("Sink Input #386"), Some(386))
  assert_eq(volx_block_index("Sink #49"), Some(49))
  assert_true(volx_block_index("Sink Input") is None)
  assert_true(volx_block_index("") is None)
  // 顶格判定：缩进行（含值里的 '#'）与前导空白都不是标题
  assert_true(volx_is_block_head("Sink #49"))
  assert_false(volx_is_block_head("\t\talsa.subdevice_name = \"subdevice #0\""))
  assert_false(volx_is_block_head("  Sink #49"))
  assert_false(volx_is_block_head(""))
  // yes/no
  assert_eq(volx_yes_no("yes"), Some(true))
  assert_eq(volx_yes_no("no"), Some(false))
  assert_true(volx_yes_no("否") is None)
  assert_true(volx_yes_no("") is None)
}

///|
test "volx_set_default_args/volx_set_app_*_args：pactl 专线命令构造" {
  debug_inspect(
    volx_set_default_args("alsa_output.pci-0000_00_1f.3.analog-stereo"),
    content="[\"set-default-sink\", \"alsa_output.pci-0000_00_1f.3.analog-stereo\"]",
  )
  debug_inspect(
    volx_set_app_volume_args(386, 50),
    content="[\"set-sink-input-volume\", \"386\", \"50%\"]",
  )
  // 百分比钳制与 vol_ 组一致
  debug_inspect(
    volx_set_app_volume_args(386, 150),
    content="[\"set-sink-input-volume\", \"386\", \"100%\"]",
  )
  debug_inspect(
    volx_set_app_volume_args(386, -5),
    content="[\"set-sink-input-volume\", \"386\", \"0%\"]",
  )
  // 静音 1/0
  debug_inspect(
    volx_set_app_mute_args(386, true),
    content="[\"set-sink-input-mute\", \"386\", \"1\"]",
  )
  debug_inspect(
    volx_set_app_mute_args(386, false),
    content="[\"set-sink-input-mute\", \"386\", \"0\"]",
  )
}

///|
test "volx Show 输出：AudioDevice / AppStream" {
  let d : AudioDevice = {
    name: "alsa_output.pci-0000_00_1f.3.analog-stereo",
    description: "Built-in Audio 模拟立体声",
    is_default: true,
  }
  assert_eq(
    d.to_string(),
    "AudioDevice { name: alsa_output.pci-0000_00_1f.3.analog-stereo, description: Built-in Audio 模拟立体声, is_default: true }",
  )
  let s : AppStream = {
    index: 386,
    app_name: "pacat",
    volume: 0,
    muted: false,
  }
  assert_eq(
    s.to_string(),
    "AppStream { index: 386, app_name: pacat, volume: 0, muted: false }",
  )
}

///|
test "volx 真机只读冒烟（无 pactl 跳过；只枚举，不切默认设备、不改音量）" {
  if !volx_pactl_ready() {
    println("volx: skip (no pactl)")
    return
  }
  match volx_devices() {
    Ok(devs) => {
      println("volx devices: \{devs.length()}")
      let mut defaults = 0
      for d in devs {
        println("volx device: \{d}")
        assert_true(d.name != "")
        if d.is_default {
          defaults = defaults + 1
        }
      }
      // 默认设备至多一个（pactl get-default-sink 是单值）
      assert_true(defaults <= 1)
    }
    Err(e) => {
      println("volx_devices failed: \{e}")
      assert_true(false)
    }
  }
  match volx_app_streams() {
    Ok(sts) => {
      println("volx streams: \{sts.length()}")
      for s in sts {
        println("volx stream: \{s}")
        assert_true(s.volume >= 0 && s.volume <= 100)
        assert_true(s.index >= 0)
      }
    }
    Err(e) => {
      println("volx_app_streams failed: \{e}")
      assert_true(false)
    }
  }
}
