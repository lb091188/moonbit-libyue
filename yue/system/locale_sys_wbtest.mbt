// locale_sys 模块白盒测试：timedatectl KEY=VALUE 解析（Timezone /
// NTP）、时区标识合法性校验、stderr 压行，以及本机真实查询（D-Bus
// timedate1 优先、timedatectl show 回退，只读；不执行 set_timezone）。

///|
test "lc_strip_prefix:前缀剥除/不匹配" {
  assert_true(
    lc_strip_prefix("Timezone=Asia/Shanghai", "Timezone=")
    is Some("Asia/Shanghai"),
  )
  assert_true(lc_strip_prefix("NTP=yes", "NTP=") is Some("yes"))
  assert_true(lc_strip_prefix("LocalRTC=no", "NTP=") is None)
  assert_true(lc_strip_prefix("NTP=yes", "NTPSynchronized=") is None)
  assert_true(lc_strip_prefix("abc", "abcd") is None) // 短于前缀
  assert_true(lc_strip_prefix("", "x") is None)
}

///|
test "lc_parse_property:真实 timedatectl show 样例" {
  // systemd timedatectl show 的真实输出形态（C locale，LC_ALL=C 固定）
  let sample = "Timezone=Asia/Shanghai\nLocalRTC=no\nCanNTP=yes\nNTP=yes\nNTPSynchronized=yes\nTimeUSec=Wed 2026-10-07 11:01:22 CST\nRTCTimeUSec=Wed 2026-10-07 11:01:22 CST\n"
  assert_true(lc_parse_property(sample, "Timezone") is Some("Asia/Shanghai"))
  assert_true(lc_parse_property(sample, "LocalRTC") is Some("no"))
  assert_true(lc_parse_property(sample, "NTP") is Some("yes"))
  assert_true(lc_parse_property(sample, "NoSuchKey") is None)
  // 首行命中即返回；两个同键行取首个
  let dup = "NTP=no\nNTP=yes\n"
  assert_true(lc_parse_property(dup, "NTP") is Some("no"))
}

///|
test "lc_parse_timezone/lc_parse_ntp:语义化取值" {
  assert_true(lc_parse_timezone("Timezone=Asia/Tokyo\n") is Some("Asia/Tokyo"))
  // 行首空白与值尾部空白容忍（timedatectl 输出无空格形如 Key=value）
  assert_true(
    lc_parse_timezone("  Timezone=Asia/Tokyo  \n") is Some("Asia/Tokyo"),
  )
  assert_true(lc_parse_timezone("Timezone=Asia/Tokyo") is Some("Asia/Tokyo")) // 无结尾换行
  assert_true(lc_parse_timezone("LocalRTC=no\n") is None)
  assert_true(lc_parse_ntp("NTP=yes\n") is Some(true))
  assert_true(lc_parse_ntp("NTP=no\n") is Some(false))
  assert_true(lc_parse_ntp("CanNTP=yes\n") is None) // 前缀不同
  assert_true(lc_parse_ntp("NTP=maybe\n") is None) // 非 yes/no
  assert_true(lc_parse_ntp("") is None)
}

///|
test "lc_valid_timezone:合法/非法形态" {
  assert_true(lc_valid_timezone("Asia/Shanghai"))
  assert_true(lc_valid_timezone("UTC"))
  assert_true(lc_valid_timezone("America/Argentina/Buenos_Aires"))
  assert_true(!lc_valid_timezone("")) // 空串
  assert_true(!lc_valid_timezone("Asia /Shanghai")) // 含空白
  assert_true(!lc_valid_timezone("Asia/Shanghai\n")) // 换行
  assert_true(!lc_valid_timezone("/Asia/Shanghai")) // 以 '/' 开头
  assert_true(!lc_valid_timezone("a/../b")) // 路径穿越
}

///|
test "lc_first_line:stderr 压单行截断" {
  assert_eq(lc_first_line("stable\n"), "stable")
  assert_eq(lc_first_line("line1\nline2\n"), "line1")
  assert_eq(lc_first_line(""), "")
  let long = StringBuilder()
  let mut i = 0
  while i < 200 {
    long.write_char('x')
    i += 1
  }
  assert_eq(lc_first_line(long.to_string()).length(), 120)
}

///|
test "lc_dest/lc_path/lc_iface:timedate1 定位常量" {
  assert_eq(lc_dest(), "org.freedesktop.timedate1")
  assert_eq(lc_path(), "/org/freedesktop/timedate1")
  assert_eq(lc_iface(), "org.freedesktop.timedate1")
}

///|
test "Show 输出:错误枚举" {
  let e1 : LocaleError = LcUnsupported
  assert_eq(e1.to_string(), "LocaleError::LcUnsupported")
  let e2 : LocaleError = LcBusFailed("gdbus.io: 系统总线不可达")
  assert_eq(
    e2.to_string(),
    "LocaleError::LcBusFailed(gdbus.io: 系统总线不可达)",
  )
  let e3 : LocaleError = LcCommandFailed("timedatectl show: 退出码 1")
  assert_eq(
    e3.to_string(),
    "LocaleError::LcCommandFailed(timedatectl show: 退出码 1)",
  )
  let e4 : LocaleError = LcParseFailed("timedatectl show: 无 Timezone 行")
  assert_eq(
    e4.to_string(),
    "LocaleError::LcParseFailed(timedatectl show: 无 Timezone 行)",
  )
  let e5 : LocaleError = LcInvalidTimezone("bad tz")
  assert_eq(e5.to_string(), "LocaleError::LcInvalidTimezone(bad tz)")
}

// ---------------------------------------------------------------------------
// 本机真实查询（只读；D-Bus timedate1 失败会自动回退 timedatectl show）
// ---------------------------------------------------------------------------

///|
test "本机 lc_timezone:D-Bus 或 timedatectl 给出合法时区" {
  match lc_timezone() {
    Ok(tz) => {
      assert_true(lc_valid_timezone(tz))
      // 与 timedatectl show 的命令路径一致（命令可用时）
      match pr_run("timedatectl", ["show"], timeout_ms=3000) {
        Ok(o) =>
          match lc_parse_timezone(o.stdout) {
            Some(t) => assert_eq(tz, t)
            None => ()
          }
        Err(_) => ()
      }
    }
    Err(_) => () // 无 systemd/timedate1 的环境不阻塞
  }
}

///|
test "本机 lc_ntp:布尔值与命令路径一致" {
  match lc_ntp() {
    Ok(on) =>
      match pr_run("timedatectl", ["show"], timeout_ms=3000) {
        Ok(o) =>
          match lc_parse_ntp(o.stdout) {
            Some(t) => assert_eq(on, t)
            None => ()
          }
        Err(_) => ()
      }
    Err(_) => ()
  }
}

///|
test "本机 lc_lang:$LANG 环境变量读取" {
  match @env.get_env_var("LANG") {
    None => assert_true(lc_lang() is Err(LcUnsupported))
    Some(v) =>
      if lc_trim(v) == "" {
        assert_true(lc_lang() is Err(LcUnsupported))
      } else {
        assert_true(lc_lang() is Ok(_))
      }
  }
}
