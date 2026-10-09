// 夜间色温模块白盒测试：色温换算（percent ↔ 暖度 ↔ 千分比 gamma ↔ K）、
// gamma 文本（红微提/蓝衰减、两位小数进位）、两后端命令参数构造、
// 诊断文本截断 + 真机只读探测冒烟。探测只跑 redshift -V 与
// xrandr --query（均只读）；nl_set_temperature / nl_reset 属设置类，
// 本测试只验参数构造、不真实执行。

///|
test "nl_clamp_percent / nl_warmth：量程与反向映射" {
  assert_eq(nl_clamp_percent(-10), 0)
  assert_eq(nl_clamp_percent(0), 0)
  assert_eq(nl_clamp_percent(50), 50)
  assert_eq(nl_clamp_percent(100), 100)
  assert_eq(nl_clamp_percent(150), 100)
  // 暖度与 percent 反向：0 = 最暖、100 = 最冷（中性）
  assert_eq(nl_warmth(0), 100)
  assert_eq(nl_warmth(50), 50)
  assert_eq(nl_warmth(100), 0)
  assert_eq(nl_warmth(-5), 100) // 出界先钳
  assert_eq(nl_warmth(105), 0)
}

///|
test "nl_kelvin：percent 线性映射 2500K-6500K" {
  assert_eq(nl_kelvin(0), 2500) // 最暖
  assert_eq(nl_kelvin(50), 4500)
  assert_eq(nl_kelvin(100), 6500) // 中性
  assert_eq(nl_kelvin(150), 6500) // 钳制
  assert_eq(nl_kelvin(-3), 2500)
}

///|
test "nl_fmt_permille：两位小数与进位" {
  assert_eq(nl_fmt_permille(1000), "1.00")
  assert_eq(nl_fmt_permille(850), "0.85")
  assert_eq(nl_fmt_permille(2100), "2.10")
  assert_eq(nl_fmt_permille(2200), "2.20")
  assert_eq(nl_fmt_permille(0), "0.00")
  assert_eq(nl_fmt_permille(5), "0.01") // 千分位四舍五入
  assert_eq(nl_fmt_permille(1995), "2.00") // 进位带 whole
  assert_eq(nl_fmt_permille(9995), "10.00")
}

///|
test "nl_red_gamma / nl_blue_gamma：端点量程" {
  // 中性（warmth=0）双通道恒 1.00
  assert_eq(nl_red_gamma(0), 1000)
  assert_eq(nl_blue_gamma(0), 1000)
  // 最暖（warmth=100）：红 0.85 微提、蓝 2.20 衰减
  assert_eq(nl_red_gamma(100), 850)
  assert_eq(nl_blue_gamma(100), 2200)
  // 中间值单调
  assert_eq(nl_red_gamma(50), 925)
  assert_eq(nl_blue_gamma(50), 1600)
}

///|
test "nl_gamma_text：R:G:B 三段（绿恒 1.00）" {
  // 最暖：红微提、蓝衰减
  assert_eq(nl_gamma_text(0), "0.85:1.00:2.20")
  // 中间
  assert_eq(nl_gamma_text(50), "0.93:1.00:1.60")
  // 最冷（中性）：不改动
  assert_eq(nl_gamma_text(100), "1.00:1.00:1.00")
  // 出界先钳
  assert_eq(nl_gamma_text(-20), "0.85:1.00:2.20")
  assert_eq(nl_gamma_text(120), "1.00:1.00:1.00")
}

///|
test "nl_xrandr_set_args / nl_redshift_set_args：两后端参数" {
  debug_inspect(
    nl_xrandr_set_args("HDMI-0", 0),
    content="[\"--output\", \"HDMI-0\", \"--gamma\", \"0.85:1.00:2.20\"]",
  )
  debug_inspect(
    nl_xrandr_set_args("eDP-1", 100),
    content="[\"--output\", \"eDP-1\", \"--gamma\", \"1.00:1.00:1.00\"]",
  )
  // redshift：-P 清既有斜坡再 -O 一次性设色温（K）
  debug_inspect(nl_redshift_set_args(0), content="[\"-P\", \"-O\", \"2500\"]")
  debug_inspect(nl_redshift_set_args(50), content="[\"-P\", \"-O\", \"4500\"]")
  debug_inspect(nl_redshift_set_args(100), content="[\"-P\", \"-O\", \"6500\"]")
}

///|
test "nl_trim_msg：诊断文本压单行截断" {
  assert_eq(nl_trim_msg("line1\nline2"), "line1")
  assert_eq(nl_trim_msg(""), "")
  // 120 字符截断
  let long = StringBuilder()
  for _ in 0..<130 {
    long.write_char('x')
  }
  assert_eq(nl_trim_msg(long.to_string()).length(), 120)
}

///|
test "nl_supported 真机只读冒烟（redshift -V / xrandr --query 均只读）" {
  // pr_run 子进程环境不含 DISPLAY：无 X display 时 xrandr 以非零退出
  // 呈现，本机 redshift 未安装，探测结果为 false 属预期分支
  let supported = nl_supported()
  println("nl: supported = \{supported}")
  assert_eq(supported, nl_backend() is Some(_))
  if supported {
    match nl_backend() {
      Some(NlRedshift) => println("nl: redshift backend")
      Some(NlXrandr) =>
        match nl_pick_output() {
          Some(o) => println("nl: pick output \{o}")
          None => println("nl: xrandr 在但无已连接输出")
        }
      None => ()
    }
  } else {
    println("nl: skip (no redshift / xrandr not usable)")
  }
}
