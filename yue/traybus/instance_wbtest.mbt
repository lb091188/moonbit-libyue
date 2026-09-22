// 单实例纯函数测试：RequestName 回复码映射、app_id 合法性、
// 入站 Wake method_call 的分发判定与参数提取（线路往返，不连总线）。

///|
test "RequestName 回复码映射" {
  // 回复码：1=首实例 2=排队 3=已有实例 4=本连接已持有
  inspect(name_claim_of(1) is Some(PrimaryOwner), content="true")
  inspect(name_claim_of(2) is Some(InQueue), content="true")
  inspect(name_claim_of(3) is Some(AlreadyExists), content="true")
  inspect(name_claim_of(4) is Some(AlreadyOwner), content="true")
  inspect(name_claim_of(0) is None, content="true")
  inspect(name_claim_of(7) is None, content="true")
}

///|
test "app_id 合法性" {
  inspect(valid_app_id("com.example.app"), content="true")
  inspect(valid_app_id("org.moonbit_libyue.Showcase"), content="true")
  inspect(valid_app_id("a.b"), content="true")
  inspect(valid_app_id("nodots"), content="false")
  inspect(valid_app_id("com..app"), content="false")
  inspect(valid_app_id(".com.app"), content="false")
  inspect(valid_app_id("com.app."), content="false")
  inspect(valid_app_id("com.9app"), content="false")
  inspect(valid_app_id("com.-app"), content="false")
  inspect(valid_app_id("com.app name"), content="false")
  inspect(valid_app_id("com.app/name"), content="false")
  inspect(valid_app_id(""), content="false")
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
          inspect(msg.kind, content="1")
          inspect(is_wake_call(msg), content="true")
          let args = wake_args(msg)
          inspect(args.length(), content="2")
          inspect(args[0], content="showcase")
          inspect(args[1], content="--flag")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
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
        Some(msg) => inspect(wake_args(msg).length(), content="0")
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
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
        Some(msg) => inspect(is_wake_call(msg), content="false")
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}
