// 窗口管理白盒测试：wmctrl -l 行解析（构造样例 + 本机真实采集样例）、
// 全文解析容错、激活/关闭命令构造、Show 文本，以及 wmctrl 探测与
// win_list 的真实环境探测（只读）。激活/关闭为设置类动作，只验证命令
// 构造不真实执行；本机未装工具时探测测试打印跳过。

///|
/// 数组逐元素相等（避免依赖 Array 的相等实现）。
fn win_args_eq(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
test "win_is_hex_id：0x 前缀 + 十六进制数字判定" {
  assert_true(win_is_hex_id("0x02800003"))
  assert_true(win_is_hex_id("0x00c00008"))
  assert_true(win_is_hex_id("0xABC")) // 大写十六进制
  assert_false(win_is_hex_id("02800003")) // 无 0x 前缀
  assert_false(win_is_hex_id("0x")) // 无数字
  assert_false(win_is_hex_id("0xZZ"))
  assert_false(win_is_hex_id("0x12g4"))
  assert_false(win_is_hex_id(""))
  assert_false(win_is_hex_id("ZCode")) // 标题形态
}

///|
test "win_parse_int：有符号十进制" {
  assert_eq(win_parse_int("0"), Some(0))
  assert_eq(win_parse_int("12"), Some(12))
  assert_eq(win_parse_int("-1"), Some(-1))
  assert_true(win_parse_int("") is None)
  assert_true(win_parse_int("-") is None)
  assert_true(win_parse_int("1-2") is None)
  assert_true(win_parse_int(" 1") is None)
  assert_true(win_parse_int("x") is None)
}

///|
test "win_parse_line：真实采集样例（含桌面 -1 与 %2d 双空格）" {
  // 本机 Ubuntu 24.04 XFCE wmctrl -l 真实行（sticky 窗口桌面 -1；
  // 个位数桌面右对齐两位，id 后是两个空格）
  match win_parse_line("0x02800003 -1 lkyh-fe xfce4-panel") {
    Some(w) => {
      assert_eq(w.id, "0x02800003")
      assert_eq(w.desktop, -1)
      assert_eq(w.host, "lkyh-fe")
      assert_eq(w.title, "xfce4-panel")
    }
    None => assert_true(false)
  }
  match win_parse_line("0x00c00008 -1 lkyh-fe 桌面") {
    Some(w) => assert_eq(w.title, "桌面")
    None => assert_true(false)
  }
  match win_parse_line("0x02400004  0 lkyh-fe ZCode") {
    Some(w) => {
      assert_eq(w.desktop, 0)
      assert_eq(w.title, "ZCode")
    }
    None => assert_true(false)
  }
  match
    win_parse_line(
      "0x07000004  0 lkyh-fe three-native实现计划.md ~/ownCode/steel-front",
    ) {
    Some(w) =>
      assert_eq(w.title, "three-native实现计划.md ~/ownCode/steel-front")
    None => assert_true(false)
  }
}

///|
test "win_parse_line：标题含内部多空格原样保留" {
  match win_parse_line("0x01c00010 0 host a  b   c") {
    Some(w) => {
      assert_eq(w.id, "0x01c00010")
      assert_eq(w.host, "host")
      assert_eq(w.title, "a  b   c")
    }
    None => assert_true(false)
  }
}

///|
test "win_parse_line：缺字段 / id 非 0x / 桌面非整数为 None" {
  assert_true(win_parse_line("") is None)
  assert_true(win_parse_line("   ") is None)
  assert_true(win_parse_line("0x024") is None) // 只一段
  assert_true(win_parse_line("0x024 0") is None) // 缺主机
  assert_true(win_parse_line("garbage -1 host title") is None) // id 非 0x
  assert_true(win_parse_line("0x024 x host title") is None) // 桌面非整数
  assert_true(win_parse_line("zzz host title") is None) // 只两段
}

///|
test "win_parse_line：无标题窗口以空标题成行" {
  match win_parse_line("0x0240000a 0 host ") {
    Some(w) => {
      assert_eq(w.title, "")
      assert_eq(w.host, "host")
    }
    None => assert_true(false)
  }
  match win_parse_line("0x0240000a 0 host") {
    Some(w) => assert_eq(w.title, "")
    None => assert_true(false)
  }
}

///|
test "win_parse_list：真实多行全文 / 空输出 / 全垃圾 / 容错跳过" {
  let real = "0x02800003 -1 lkyh-fe xfce4-panel\n" +
    "0x00c00008 -1 lkyh-fe 桌面\n" +
    "0x02400004  0 lkyh-fe ZCode\n" +
    "0x07000004  0 lkyh-fe three-native实现计划.md ~/ownCode/steel-front\n" +
    "0x05a00007 -1 lkyh-fe 软件更新器\n"
  match win_parse_list(real) {
    Ok(ws) => {
      assert_eq(ws.length(), 5)
      assert_eq(ws[0].id, "0x02800003")
      assert_eq(ws[2].desktop, 0)
      assert_eq(ws[4].title, "软件更新器")
    }
    Err(e) => {
      println("win_parse_list real failed: \{e}")
      assert_true(false)
    }
  }
  match win_parse_list("") {
    Ok(ws) => assert_eq(ws.length(), 0)
    Err(_) => assert_true(false)
  }
  match win_parse_list("\n  \n") {
    Ok(ws) => assert_eq(ws.length(), 0)
    Err(_) => assert_true(false)
  }
  match win_parse_list("garbage\nnot-a-window-line\n") {
    Err(WinError::ParseFailed(_)) => ()
    _ => assert_true(false)
  }
  // 单行无法解析的行跳过，合法行照收
  match win_parse_list("garbage\n0x02400004  0 lkyh-fe ZCode\nbadline\n") {
    Ok(ws) => {
      assert_eq(ws.length(), 1)
      assert_eq(ws[0].title, "ZCode")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "win_activate_args：0x id 带 -i，标题裸传" {
  assert_true(
    win_args_eq(win_activate_args("0x02400004"), ["-i", "-a", "0x02400004"]),
  )
  assert_true(win_args_eq(win_activate_args("ZCode"), ["-a", "ZCode"]))
  assert_true(win_args_eq(win_activate_args("0xABC"), ["-i", "-a", "0xABC"]))
}

///|
test "win_close_args：标题裸传 -c" {
  assert_true(win_args_eq(win_close_args("ZCode"), ["-c", "ZCode"]))
  assert_true(
    win_args_eq(win_close_args("three-native实现计划.md"), [
      "-c", "three-native实现计划.md",
    ]),
  )
}

///|
test "WindowInfo / WinError Show 文本" {
  let w : WindowInfo = {
    id: "0x02400004",
    desktop: 0,
    host: "h",
    title: "ZCode",
  }
  let s = w.to_string()
  assert_true(s.contains("0x02400004"))
  assert_true(s.contains("ZCode"))
  assert_eq(
    WinError::CommandFailed("退出码 1").to_string(),
    "WinError::CommandFailed(退出码 1)",
  )
  assert_eq(WinError::Unsupported.to_string(), "WinError::Unsupported")
  assert_eq(
    WinError::InvalidParam("空").to_string(),
    "WinError::InvalidParam(空)",
  )
  assert_true(WinError::ParseFailed("原文").to_string().contains("原文"))
}

///|
test "win_activate / win_close：空参数 InvalidParam（不执行命令）" {
  assert_true(win_activate("") is Err(WinError::InvalidParam(_)))
  assert_true(win_close("") is Err(WinError::InvalidParam(_)))
}

///|
test "win_map_err：退出码 127 归一为 Unsupported" {
  assert_true(
    win_map_err("wmctrl", ProcError::NonZeroExit(127, "not found"))
    is WinError::Unsupported,
  )
  assert_true(
    win_map_err("wmctrl", ProcError::NonZeroExit(1, "Cannot open display."))
    is WinError::CommandFailed(_),
  )
  assert_true(
    win_map_err("wmctrl", ProcError::Timeout("超时"))
    is WinError::CommandFailed(_),
  )
  assert_true(
    win_map_err("wmctrl", ProcError::Unsupported) is WinError::Unsupported,
  )
}

// ---------------------------------------------------------------------------
// 真实环境探测（只读；本机无对应工具时打印跳过）
// ---------------------------------------------------------------------------

///|
test "win_supported：真实探测（wmctrl/xdotool 存在即真）" {
  if !pr_available() {
    println("win_supported: skip (non-linux)")
    return
  }
  if !win_probe("wmctrl") && !win_probe("xdotool") {
    // 安装指引：sudo apt install wmctrl（或 xdotool）
    println("win_supported: skip (wmctrl/xdotool 均未安装)")
    return
  }
  assert_true(win_supported())
}

///|
test "win_list：真实环境探测（wmctrl -l 读取结果记录）" {
  if !pr_available() || !win_probe("wmctrl") {
    println("win_list: skip (wmctrl 不可用)")
    return
  }
  // pr_run 的子进程环境只传 PATH/XDG_RUNTIME_DIR/HOME/LC_ALL，不含
  // DISPLAY；无 X display 时 wmctrl 以 "Cannot open display." 非零退出，
  // 本条记录真实结果、不断言（与 monitor_wbtest 的 mon_list 冒烟同法）
  match win_list() {
    Ok(ws) => {
      println("win_list: \{ws.length()} 个窗口")
      for w in ws {
        println("  \{w}")
      }
      // 真实 X 会话下至少有面板/桌面等常驻窗口
      assert_true(ws.length() > 0)
    }
    Err(e) => println("win_list: skip (\{e})")
  }
}
