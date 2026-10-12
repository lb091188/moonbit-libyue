// 用户空闲秒数（W21e）回归。分两档：
//   ① 纯函数（毫秒夹取 / 毫秒换秒 / 错误 Show）——任何平台都可跑；
//   ② 运行时读数（支持性探测 + 读数非负 + 连续两次读的单调性）——只在
//      `idle_supported()` 的平台上跑（macOS / Wayland 无 X 服务端时自动跳过，
//      不造假）。
//
// 单调性那条特意容了一个例外：空闲时间**只会增长**，变小只可能是「这期间有
// 输入把它清零了」——那种情况下新读数必然很小（< 0.05s）。真机上人手在敲就
// 走这个分支，自动化跑时走增长分支，两种都不误报。

///|
test "idle_clamp_ms / idle_ms_to_seconds：负值归零、毫秒换秒" {
  assert_eq(idle_clamp_ms(-1L), 0L)
  assert_eq(idle_clamp_ms(-100000L), 0L)
  assert_eq(idle_clamp_ms(0L), 0L)
  assert_eq(idle_clamp_ms(1500L), 1500L)
  assert_eq(idle_ms_to_seconds(0L), 0.0)
  assert_eq(idle_ms_to_seconds(1500L), 1.5)
  assert_eq(idle_ms_to_seconds(250L), 0.25)
  // 负值经换算也是 0 秒而不是负秒
  assert_eq(idle_ms_to_seconds(-5000L), 0.0)
}

///|
test "IdleError 的 Show：两档都能打出来" {
  assert_eq(IdleError::Unsupported.to_string(), "IdleError::Unsupported")
  assert_eq(
    IdleError::Failed("x").to_string(),
    "IdleError::Failed(x)",
  )
}

///|
test "idle_supported：Windows 应为真（其余平台只打印运行时探测值，不断言）" {
  let sup = idle_supported()
  match sys_platform() {
    "windows" => assert_true(sup)
    _ => println("idle_supported(本机 " + sys_platform() + ") = " + sup.to_string())
  }
}

///|
test "idle_seconds：读数非负，且连续两次读要么增长、要么被输入清零（无后端自动跳过）" {
  if !idle_supported() {
    println("idle: 本平台/本会话不支持，跳过读数")
    return
  }
  let first = match idle_seconds() {
    Ok(v) => v
    Err(e) => fail("空闲查询失败: " + e.to_string())
  }
  assert_true(first >= 0.0)
  let second = match idle_seconds() {
    Ok(v) => v
    Err(e) => fail("第二次空闲查询失败: " + e.to_string())
  }
  assert_true(second >= 0.0)
  // 空闲时间单调不减；变小只可能是这期间有输入把它清零（此时新值必然很小）
  assert_true(second >= first || second < 0.05)
}
