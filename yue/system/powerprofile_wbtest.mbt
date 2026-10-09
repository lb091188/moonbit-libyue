// powerprofile 模块白盒测试：计划名映射、`powerprofilesctl list`/`get`
// 输出解析、set 参数构造与 stderr 压行（纯逻辑）；另有本机只读探测的
// 语义不变量（supported 真 ↔ current 可查）。不真实执行 set（切换电源
// 计划需要认证且有副作用）。

///|
test "pp_name_of/pp_profile_of:三计划来回映射" {
  assert_eq(pp_name_of(PPerformance), "performance")
  assert_eq(pp_name_of(PBalanced), "balanced")
  assert_eq(pp_name_of(PPowerSaver), "power-saver")
  assert_true(pp_profile_of("performance") is Some(PPerformance))
  assert_true(pp_profile_of("balanced") is Some(PBalanced))
  assert_true(pp_profile_of("power-saver") is Some(PPowerSaver))
  assert_true(pp_profile_of("Power-Saver") is None) // 大小写敏感
  assert_true(pp_profile_of("saver") is None)
  assert_true(pp_profile_of("") is None)
  // 来回一致
  for p in [PPerformance, PBalanced, PPowerSaver] {
    assert_true(pp_profile_of(pp_name_of(p)) is Some(_))
  }
}

///|
test "pp_line_profile:计划名行识别/属性行排除" {
  assert_true(pp_line_profile("  balanced:") is Some("balanced"))
  assert_true(pp_line_profile("* balanced:") is Some("balanced"))
  assert_true(pp_line_profile("  power-saver:") is Some("power-saver"))
  assert_true(pp_line_profile("* power-saver:") is Some("power-saver"))
  // 属性行（四空格缩进含空白）与杂行不识别
  assert_true(pp_line_profile("    Driver: power-saver") is None)
  assert_true(pp_line_profile("    Degraded: no") is None)
  assert_true(pp_line_profile("balanced:") is None) // 无两空格缩进
  assert_true(pp_line_profile(" balanced:") is None) // 只有一空格
  assert_true(pp_line_profile("* balanced") is None) // 无结尾冒号
  assert_true(pp_line_profile("  :") is None) // 空计划名
  assert_true(pp_line_profile("") is None)
}

///|
test "pp_parse_profile_list:真实形态样例(属性行/活动标记/顺序)" {
  // power-profiles-daemon 0.20 的典型输出形态
  let sample = "* power-saver:\n    Driver: power-profile-daemon\n    Degraded: lp\n  balanced:\n    Driver: power-profile-daemon\n    Degraded: no\n  performance:\n    Driver: power-profile-daemon\n    Degraded: no\n"
  let profiles = pp_parse_profile_list(sample)
  assert_eq(profiles.length(), 3)
  assert_true(profiles[0] is PPowerSaver) // 活动计划在前
  assert_true(profiles[1] is PBalanced)
  assert_true(profiles[2] is PPerformance)
  // 未知计划名跳过、空输出给空表
  let odd = "  exotic:\n    Driver: x\n  balanced:\n"
  let only = pp_parse_profile_list(odd)
  assert_eq(only.length(), 1)
  assert_true(only[0] is PBalanced)
  assert_eq(pp_parse_profile_list("").length(), 0)
  assert_eq(pp_parse_profile_list("no profiles here\n").length(), 0)
}

///|
test "pp_parse_current:trim 后按名匹配" {
  assert_true(pp_parse_current("balanced\n") is Some(PBalanced))
  assert_true(pp_parse_current("balanced") is Some(PBalanced))
  assert_true(pp_parse_current(" power-saver \n") is Some(PPowerSaver))
  assert_true(pp_parse_current("performance") is Some(PPerformance))
  assert_true(pp_parse_current("unknown\n") is None)
  assert_true(pp_parse_current("") is None)
  assert_true(pp_parse_current("\n") is None)
}

///|
test "pp_set_args:set 子命令参数表" {
  assert_eq(pp_set_args(PPerformance), ["set", "performance"])
  assert_eq(pp_set_args(PBalanced), ["set", "balanced"])
  assert_eq(pp_set_args(PPowerSaver), ["set", "power-saver"])
}

///|
test "pp_first_line:stderr 压单行截断" {
  assert_eq(pp_first_line("stable\n"), "stable")
  assert_eq(pp_first_line("line1\nline2\n"), "line1")
  assert_eq(pp_first_line("ab\ncd"), "ab")
  assert_eq(pp_first_line(""), "")
  // 超过 120 字符的行截断
  let long = StringBuilder()
  let mut i = 0
  while i < 200 {
    long.write_char('x')
    i += 1
  }
  assert_eq(pp_first_line(long.to_string()).length(), 120)
}

///|
test "Show 输出:计划与错误枚举" {
  assert_eq(PBalanced.to_string(), "PowerProfile::balanced")
  assert_eq(PPowerSaver.to_string(), "PowerProfile::power-saver")
  let e1 : PowerProfileError = PpUnsupported
  assert_eq(e1.to_string(), "PowerProfileError::PpUnsupported")
  let e2 : PowerProfileError = PpCommandFailed("powerprofilesctl: 退出码 1")
  assert_eq(
    e2.to_string(),
    "PowerProfileError::PpCommandFailed(powerprofilesctl: 退出码 1)",
  )
  let e3 : PowerProfileError = PpParseFailed("powerprofilesctl get: ")
  assert_eq(
    e3.to_string(),
    "PowerProfileError::PpParseFailed(powerprofilesctl get: )",
  )
}

///|
test "本机探测:supported 真 ↔ current 可查(只读,不执行 set)" {
  // power-profiles-daemon 未安装的机器上走 PpUnsupported 分支,装上
  // 的机器上 current 必为 Ok;两条路径都不断言具体值,只校验语义
  // 不变量
  if pp_supported() {
    match pp_current() {
      Ok(_) => assert_true(pp_profiles() is Ok(_))
      Err(_) =>
        assert_true(false, msg="supported 为真时 current 不应失败")
    }
  } else {
    assert_true(pp_current() is Err(_))
  }
}
