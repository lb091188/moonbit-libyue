// 单实例白盒测试：macOS 锁路径拼装与 pid 解析（纯逻辑）。
//
// macOS 路径的实现是「TMPDIR 下 mkdir 排他锁目录 + pid 文件判活」，锁
// 目录/mkdir 这些有副作用的部分不在这里执行，只断言纯函数层：临时目录
// 回退、锁目录与 pid 文件路径、pid 文本解析、ps 判活参数表——无 macOS
// 真机也能验证。

///|
/// macOS 锁路径拼装：TMPDIR 直接用（macOS 形如 /var/folders/xx/yy/T，
/// 按用户隔离），未设置或为空回退 /tmp。
test "si_mac 锁路径:TMPDIR 优先/回退 /tmp" {
  assert_eq(si_mac_tmp_dir(Some("/var/folders/xx/yy/T")), "/var/folders/xx/yy/T")
  assert_eq(si_mac_tmp_dir(Some("")), "/tmp") // 空串当未设置
  assert_eq(si_mac_tmp_dir(None), "/tmp")
  // 锁目录与 pid 文件同级，名字由应用标识派生
  assert_eq(
    si_mac_lock_dir(Some("/var/folders/xx/yy/T"), "com.example.app"),
    "/var/folders/xx/yy/T/moonbit.libyue.instance.com.example.app.lock",
  )
  assert_eq(
    si_mac_pid_file(Some("/var/folders/xx/yy/T"), "com.example.app"),
    "/var/folders/xx/yy/T/moonbit.libyue.instance.com.example.app.pid",
  )
  // TMPDIR 缺失：落到 /tmp 下同一套名字
  assert_eq(
    si_mac_lock_dir(None, "com.example.app"),
    "/tmp/moonbit.libyue.instance.com.example.app.lock",
  )
  // 不同 app_id 的锁互不相同
  assert_true(
    si_mac_lock_dir(Some("/tmp"), "com.a.app") !=
    si_mac_lock_dir(Some("/tmp"), "com.b.app"),
  )
}

///|
/// pid 文件文本解析：pid 文件由首实例写入，行尾可能有换行；读不到数字或
/// 值为 0 视为没有可用 pid（按陈旧锁处理）。
test "si_mac_parse_pid:pid 文件文本解析" {
  assert_true(si_mac_parse_pid("1234") is Some(1234))
  assert_true(si_mac_parse_pid("1234\n") is Some(1234))
  assert_true(si_mac_parse_pid("  42  ") is Some(42))
  assert_true(si_mac_parse_pid("") is None) // 空文件
  assert_true(si_mac_parse_pid("abc") is None) // 非数字
  assert_true(si_mac_parse_pid("0") is None) // 0 不是合法 pid
  assert_true(si_mac_parse_pid("\n") is None)
}

///|
/// ps 判活参数表：`ps -p <pid>` 退出码 0 即进程存活（macOS 无 /proc 可查）。
test "si_mac_ps_args:ps 判活参数表" {
  assert_eq(si_mac_ps_args(1234), ["-p", "1234"])
  assert_eq(si_mac_ps_args(1), ["-p", "1"])
}
