// 显示器模块白盒测试：xrandr --query 输出解析（本机真实输出样例断言，
// 含 disconnect 行 / Screen 汇总行 / 首选 '+' / 当前 '*' / 隔行 'i' /
// 多刷新率同行 / 已连接未启用输出）+ 数值换算（厘赫兹、几何偏移）+
// 当前输出提取 + 真机只读冒烟。样例文本来自 Ubuntu 24.04 + X11 + XFCE
// 实机 `xrandr --query`（LC_ALL=C 由 pr_run 固定）。

///|
/// 行数组拼多行文本（每行补换行，与命令行工具输出一致）。
fn mon_lines(lines : Array[String]) -> String {
  let buf = StringBuilder()
  for l in lines {
    buf.write_string(l)
    buf.write_char('\n')
  }
  buf.to_string()
}

///|
/// 本机真实 xrandr --query 样例（截取自 Ubuntu 24.04 + X11 + XFCE 实机；
/// HDMI-0 为主输出 1920x1080@60.00*，HDMI-2 已连接但无当前模式）。
fn mon_real_sample() -> String {
  mon_lines([
    "Screen 0: minimum 8 x 8, current 1920 x 1080, maximum 32767 x 32767", "DP-0 disconnected (normal left inverted right x axis y axis)",
    "DP-1 disconnected (normal left inverted right x axis y axis)", "DP-2 disconnected (normal left inverted right x axis y axis)",
    "DP-3 disconnected (normal left inverted right x axis y axis)", "HDMI-0 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 530mm x 290mm",
    "   2560x1440     59.95 +  75.00  ", "   1920x1080     60.00*   60.00    59.94    50.00    29.97    25.00    23.98  ",
    "   1680x1050     59.95  ", "   1600x900      60.00  ", "   1440x900      59.89  ",
    "   1280x1024     75.02    60.02  ", "   1280x960      60.00  ", "   1280x800      59.81  ",
    "   1280x720      60.00    59.94    50.00    29.97    25.00    23.98  ", "   1024x768      75.03    60.00  ",
    "   800x600       75.00    60.32  ", "   720x480       59.94  ", "   640x480       75.00    59.94    59.93  ",
    "HDMI-1 disconnected (normal left inverted right x axis y axis)", "HDMI-2 connected (normal left inverted right x axis y axis)",
    "   2560x1440     59.95 +  75.00  ", "   1920x1080     60.00    60.00    59.94    50.00    29.97    25.00    23.98  ",
    "   1680x1050     59.95  ", "   1600x900      60.00  ", "   1440x900      59.89  ",
    "   1280x1024     75.02    60.02  ", "   1280x960      60.00  ", "   1280x800      59.81  ",
    "   1280x720      60.00    59.94    50.00    29.97    25.00    23.98  ", "   1024x768      75.03    60.00  ",
    "   800x600       75.00    60.32  ", "   720x480       59.94  ", "   640x480       75.00    59.94    59.93  ",
    "DP-4 disconnected (normal left inverted right x axis y axis)", "DP-5 disconnected (normal left inverted right x axis y axis)",
  ])
}

///|
test "mon_fold_marker_tokens：独立标记 token 回贴前一 token" {
  // xrandr 1.5.2：'59.95 +  75.00'（独立 '+' 位于被标记刷新率之后，
  // 经 xrandr --verbose 证实 59.95 为 +preferred 模式）
  let folded = mon_fold_marker_tokens(["2560x1440", "59.95", "+", "75.00"])
  assert_eq(folded.length(), 3)
  assert_eq(folded[0], "2560x1440")
  assert_eq(folded[1], "59.95+")
  assert_eq(folded[2], "75.00")
  // 旧版附着形态不受影响
  let old = mon_fold_marker_tokens(["1920x1080", "60.00*+", "59.95"])
  assert_eq(old.length(), 3)
  assert_eq(old[1], "60.00*+")
  assert_eq(old[2], "59.95")
  // 独立 '*'（万一出现）同样回贴
  let star = mon_fold_marker_tokens(["1920x1080", "60.00", "*"])
  assert_eq(star.length(), 2)
  assert_eq(star[1], "60.00*")
  // 空表 / 开头就是标记（无前序 token 不贴）
  assert_eq(mon_fold_marker_tokens([]).length(), 0)
  assert_eq(mon_fold_marker_tokens(["+"]).length(), 1)
  assert_eq(mon_fold_marker_tokens(["+"])[0], "+")
}

///|
test "mon_parse_centi：厘赫兹换算（四舍五入/非法）" {
  assert_eq(mon_parse_centi("60.00"), Some(6000))
  assert_eq(mon_parse_centi("59.95"), Some(5995))
  assert_eq(mon_parse_centi("60"), Some(6000)) // 整数刷新率
  assert_eq(mon_parse_centi("60.5"), Some(6050))
  assert_eq(mon_parse_centi("59.957"), Some(5996)) // 第三位进位
  assert_eq(mon_parse_centi("59.951"), Some(5995)) // 第三位舍掉
  assert_true(mon_parse_centi("") is None)
  assert_true(mon_parse_centi("abc") is None)
  assert_true(mon_parse_centi("60.0.0") is None)
  assert_true(mon_parse_centi(".5") is None) // 无整数部
  assert_true(mon_parse_centi("5.") is None) // 尾点
  assert_true(mon_parse_centi("1.2345") is None) // 超三位小数
}

///|
test "mon_parse_dims：WxH 分辨率 token" {
  assert_eq(mon_parse_dims("1920x1080"), Some((1920, 1080)))
  assert_eq(mon_parse_dims("640x480"), Some((640, 480)))
  assert_true(mon_parse_dims("x1080") is None)
  assert_true(mon_parse_dims("1920x") is None)
  assert_true(mon_parse_dims("19x20x30") is None)
  assert_true(mon_parse_dims("1920X1080") is None) // 大写 X 不认
  assert_true(mon_parse_dims("16x1050p") is None)
}

///|
test "mon_parse_geometry：WxH+X+Y（含负偏移）" {
  assert_eq(mon_parse_geometry("1920x1080+0+0"), Some((1920, 1080, 0, 0)))
  assert_eq(
    mon_parse_geometry("1920x1080+-1080+0"),
    Some((1920, 1080, -1080, 0)),
  ) // 左邻屏为负偏移
  assert_eq(mon_parse_geometry("1920x1080+1920+0"), Some((1920, 1080, 1920, 0)))
  assert_true(mon_parse_geometry("1920x1080") is None) // 无偏移
  assert_true(mon_parse_geometry("1920x1080+0") is None) // 缺一段偏移
  assert_true(mon_parse_geometry("abc") is None)
}

///|
test "mon_parse_rate_token：'*' 当前 / '+' 首选 / 'i' 隔行" {
  assert_eq(mon_parse_rate_token("60.00*"), Some((6000, true, false)))
  assert_eq(mon_parse_rate_token("59.95+"), Some((5995, false, true)))
  assert_eq(mon_parse_rate_token("59.95i"), Some((5995, false, false)))
  assert_eq(mon_parse_rate_token("75.00"), Some((7500, false, false)))
  assert_true(mon_parse_rate_token("+") is None) // 空壳 token
  assert_true(mon_parse_rate_token("") is None)
  assert_true(mon_parse_rate_token("59.9x5") is None)
}

///|
test "mon_parse_mm / mon_parse_mm_pair：物理尺寸" {
  assert_eq(mon_parse_mm("530mm"), Some(530))
  assert_eq(mon_parse_mm("290mm"), Some(290))
  assert_true(mon_parse_mm("530") is None)
  assert_true(mon_parse_mm("mm") is None)
  assert_true(mon_parse_mm("xmm") is None)
  assert_eq(
    mon_parse_mm_pair(
      mon_split_ws(
        "HDMI-0 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 530mm x 290mm",
      ),
    ),
    (530, 290),
  )
  assert_eq(
    mon_parse_mm_pair(
      mon_split_ws(
        "HDMI-1 disconnected (normal left inverted right x axis y axis)",
      ),
    ),
    (0, 0),
  )
}

///|
test "mon_line_is_output / mon_parse_xrandr：真实样例全解析" {
  assert_true(
    mon_line_is_output(mon_split_ws("HDMI-0 connected primary 1920x1080+0+0")),
  )
  assert_true(mon_line_is_output(mon_split_ws("DP-0 disconnected (normal)")))
  assert_false(
    mon_line_is_output(
      mon_split_ws("Screen 0: minimum 8 x 8, current 1920 x 1080"),
    ),
  )
  assert_false(mon_line_is_output(mon_split_ws("   1920x1080     60.00*")))
  let infos = mon_parse_xrandr(mon_real_sample())
  // Screen 汇总行不产生条目：DP-0..3 + HDMI-0/1/2 + DP-4/5 共 9 个输出
  assert_eq(infos.length(), 9)
  // 首条为未连接 DP-0
  assert_eq(infos[0].name, "DP-0")
  assert_false(infos[0].connected)
  assert_eq(infos[0].modes.length(), 0)
  // HDMI-0：主输出，当前 1920x1080@60.00*，位置 +0+0，物理尺寸 530x290
  let hdmi0 = infos[4]
  assert_eq(hdmi0.name, "HDMI-0")
  assert_true(hdmi0.connected)
  assert_true(hdmi0.primary)
  assert_eq(hdmi0.width, 1920)
  assert_eq(hdmi0.height, 1080)
  assert_eq(hdmi0.refresh_centi, 6000)
  assert_eq(hdmi0.pos_x, 0)
  assert_eq(hdmi0.pos_y, 0)
  assert_eq(hdmi0.mm_width, 530)
  assert_eq(hdmi0.mm_height, 290)
  // 模式列表：13 个分辨率行，多刷新率合并、"59.95 +" 的空壳 '+' 不产模式
  assert_eq(hdmi0.modes.length(), 30)
  let m0 = hdmi0.modes[0]
  assert_eq(m0.width, 2560)
  assert_eq(m0.height, 1440)
  assert_eq(m0.refresh_centi, 5995)
  assert_true(m0.preferred) // "59.95 +"：xrandr 1.5.2 独立 '+' 回贴
  assert_false(m0.current)
  // 同行第二个刷新率不继承首选
  let m1 = hdmi0.modes[1]
  assert_eq(m1.width, 2560)
  assert_eq(m1.refresh_centi, 7500)
  assert_false(m1.preferred)
  assert_false(m1.current)
  // 当前模式唯一且为 1920x1080@60.00*
  let mut current_count = 0
  for m in hdmi0.modes {
    if m.current {
      current_count = current_count + 1
      assert_eq(m.width, 1920)
      assert_eq(m.height, 1080)
      assert_eq(m.refresh_centi, 6000)
    }
  }
  assert_eq(current_count, 1)
  // HDMI-1 未连接且无模式
  assert_eq(infos[5].name, "HDMI-1")
  assert_false(infos[5].connected)
  // HDMI-2 已连接但无当前模式（分辨率/刷新率/位置为 0）
  assert_eq(infos[6].name, "HDMI-2")
  assert_true(infos[6].connected)
  assert_false(infos[6].primary)
  assert_eq(infos[6].width, 0)
  assert_eq(infos[6].refresh_centi, 0)
  assert_eq(infos[6].pos_x, 0)
  assert_eq(infos[6].modes.length(), 30)
  // 末尾 DP-4/DP-5 未连接
  assert_eq(infos[7].name, "DP-4")
  assert_eq(infos[8].name, "DP-5")
  assert_false(infos[8].connected)
}

///|
test "mon_parse_xrandr：边界与畸形输入" {
  assert_eq(mon_parse_xrandr("").length(), 0)
  assert_eq(mon_parse_xrandr("garbage line\n").length(), 0)
  // 首个输出行前无 Screen 行也能解析
  let one = mon_parse_xrandr(
    "eDP-1 connected 1920x1080+0+0 300mm x 190mm\n   1920x1080  60.00*  \n",
  )
  assert_eq(one.length(), 1)
  assert_eq(one[0].name, "eDP-1")
  assert_eq(one[0].refresh_centi, 6000)
  assert_eq(one[0].mm_width, 300)
  assert_eq(one[0].modes.length(), 1)
}

///|
test "mon_current_from：只取已连接且有当前模式的输出" {
  let cur = mon_current_from(mon_parse_xrandr(mon_real_sample()))
  assert_eq(cur.length(), 1) // HDMI-2 无当前模式不计入
  assert_eq(cur[0].name, "HDMI-0")
  assert_eq(cur[0].width, 1920)
  assert_eq(cur[0].height, 1080)
  assert_eq(cur[0].refresh_centi, 6000)
  assert_eq(cur[0].pos_x, 0)
  assert_eq(cur[0].pos_y, 0)
}

///|
test "mon_parse_xrandr / mon_first_line：窗口与诊断文本" {
  // 空解析走 ParseFailed，原文首行为诊断
  assert_eq(mon_first_line("line1\nline2\n"), "line1")
  assert_eq(mon_first_line(""), "")
  // 缩进行在首个输出行之前被忽略（idx = -1）
  let only_modes = mon_parse_xrandr("   1920x1080     60.00*  \n")
  assert_eq(only_modes.length(), 0)
}

///|
test "mon_list 真机只读冒烟（无 X display / 无 xrandr 时跳过）" {
  // pr_run 的子进程环境只传 PATH/XDG_RUNTIME_DIR/HOME，不含 DISPLAY；
  // 无 X display 时 xrandr 以 "Can't open display" 非零退出，本条自动跳过
  match mon_list() {
    Ok(infos) => {
      assert_true(infos.length() > 0)
      for info in infos {
        println("mon: \{info}")
      }
    }
    Err(e) => println("mon: skip (\{e})")
  }
}
