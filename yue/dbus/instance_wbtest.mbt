// 单实例纯函数测试：RequestName 回复码映射、app_id 合法性、
// 入站 Wake method_call 的分发判定与参数提取（线路往返，不连总线）。

///|
test "RequestName 回复码映射" {
  // 回复码：1=首实例 2=排队 3=已有实例 4=本连接已持有
  assert_true(name_claim_of(1) is Some(PrimaryOwner))
  assert_true(name_claim_of(2) is Some(InQueue))
  assert_true(name_claim_of(3) is Some(AlreadyExists))
  assert_true(name_claim_of(4) is Some(AlreadyOwner))
  assert_true(name_claim_of(0) is None)
  assert_true(name_claim_of(7) is None)
}

///|
test "app_id 合法性" {
  assert_true(valid_app_id("com.example.app"))
  assert_true(valid_app_id("org.moonbit_libyue.Showcase"))
  assert_true(valid_app_id("a.b"))
  assert_false(valid_app_id("nodots"))
  assert_false(valid_app_id("com..app"))
  assert_false(valid_app_id(".com.app"))
  assert_false(valid_app_id("com.app."))
  assert_false(valid_app_id("com.9app"))
  assert_false(valid_app_id("com.-app"))
  assert_false(valid_app_id("com.app name"))
  assert_false(valid_app_id("com.app/name"))
  assert_false(valid_app_id(""))
}

///|
test "Wake 调用往返与分发判定" {
  match
    build_call(
      9,
      "com.example.app",
      instance_path(),
      instance_iface(),
      wake_member(),
      "as",
      [VArray("s", [VString("showcase"), VString("--flag")])],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(msg) => {
          assert_eq(msg.kind, 1)
          assert_true(is_wake_call(msg))
          let args = wake_args(msg)
          assert_eq(args.length(), 2)
          assert_eq(args[0], "showcase")
          assert_eq(args[1], "--flag")
        }
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
  // 空 'as' 的 Wake：首实例收到零参数也成立
  match
    build_call(
      10,
      "com.example.app",
      instance_path(),
      instance_iface(),
      wake_member(),
      "as",
      [VArray("s", [])],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(msg) => assert_eq(wake_args(msg).length(), 0)
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
  // 非 Wake 调用（RequestName）不得被误判成单实例唤起
  match
    build_call(
      11,
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus",
      "RequestName",
      "su",
      [VString("com.example.app"), VU32(FLAG_DO_NOT_QUEUE)],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(msg) => assert_false(is_wake_call(msg))
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
}
