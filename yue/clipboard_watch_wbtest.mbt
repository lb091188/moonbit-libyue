// 剪贴板监听白盒测试：轮询间隔钳制、一拍比对（变化派发/未变不派发/
// 基线初始内容不派发）、定时器一拍的停靠与读失败路径，以及 xclip 的
// 真实只读探测。cbw_start_watch 的定时器接线不起真实定时器（与
// charts_effectscatter 同约定，libyue 定时器需 GUI 消息循环），其逻辑
// 部件 cbw_tick / cbw_poll_step / cbw_clamp_interval 在此白盒覆盖。

///|
test "cbw_clamp_interval：钳 100..60000" {
  assert_eq(cbw_clamp_interval(800), 800) // 默认值原样
  assert_eq(cbw_clamp_interval(100), 100) // 下界
  assert_eq(cbw_clamp_interval(60000), 60000) // 上界
  assert_eq(cbw_clamp_interval(50), 100) // 低于下限
  assert_eq(cbw_clamp_interval(0), 100)
  assert_eq(cbw_clamp_interval(-1000), 100)
  assert_eq(cbw_clamp_interval(120000), 60000) // 高于上限
}

///|
test "cbw_poll_step：变化派发 / 未变不派发 / 基线不派发" {
  let watcher : ClipboardWatcher = {
    active: Ref(true),
    interval_ms: 800,
    last: Ref(""),
  }
  // 基线（启动时内容）不派发
  assert_true(cbw_poll_step(watcher, "") is None)
  assert_eq(watcher.last.val, "")
  // 首次变化派发并更新基线
  match cbw_poll_step(watcher, "hello") {
    Some(t) => assert_eq(t, "hello")
    None => assert_true(false)
  }
  assert_eq(watcher.last.val, "hello")
  // 相同内容不派发
  assert_true(cbw_poll_step(watcher, "hello") is None)
  // 再次变化派发（含清空：空串也是变化）
  match cbw_poll_step(watcher, "") {
    Some(t) => assert_eq(t, "")
    None => assert_true(false)
  }
  // 空白差异是不同文本（不做去空白）
  match cbw_poll_step(watcher, "  ") {
    Some(t) => assert_eq(t, "  ")
    None => assert_true(false)
  }
  assert_true(cbw_poll_step(watcher, "  ") is None)
}

///|
test "cbw_tick：停靠后一拍返回 false 且不读剪贴板" {
  let watcher : ClipboardWatcher = {
    active: Ref(false),
    interval_ms: 800,
    last: Ref("x"),
  }
  let mut fired = 0
  let again = cbw_tick(watcher, fn(_t) { fired = fired + 1 })
  assert_false(again)
  assert_eq(fired, 0)
  assert_eq(watcher.last.val, "x") // 未动基线
}

///|
test "cbw_tick：运行中一拍返回 true（本机无 xclip 时不派发）" {
  let watcher : ClipboardWatcher = {
    active: Ref(true),
    interval_ms: 800,
    // 基线取当前剪贴板：本拍与基线相同，不应派发
    last: Ref(
      match cbw_get_text() {
        Ok(t) => t
        Err(_) => "sentinel-no-xclip"
      },
    ),
  }
  let mut fired = 0
  let again = cbw_tick(watcher, fn(_t) { fired = fired + 1 })
  assert_true(again) // 运行中继续轮询
  // 基线取自同一拍前的读取，正常不派发；若本机恰好有 xclip 且期间
  // 剪贴板被外部改动，打印出来不断言
  if fired == 0 {
    println("cbw_tick: 未派发（符合基线预期）")
  } else {
    println(
      "cbw_tick: 派发 1 次（剪贴板在测试期间被外部改动）",
    )
  }
}

///|
test "cbw_stop：置停靠标志，幂等" {
  let watcher : ClipboardWatcher = {
    active: Ref(true),
    interval_ms: 800,
    last: Ref(""),
  }
  cbw_stop(watcher)
  assert_false(watcher.active.val)
  cbw_stop(watcher) // 重复调用安全
  assert_false(watcher.active.val)
}

///|
test "cbw_start_watch：构造逻辑的间隔钳制与基线（不起真实定时器）" {
  // start_watch 是「钳制间隔 + 取基线 + set_timer(cbw_tick)」的组合；
  // 定时器接线需 GUI 消息循环，此处只覆盖其组成部件
  assert_eq(cbw_clamp_interval(800), 800)
  let baseline = match cbw_get_text() {
    Ok(t) => t
    Err(_) => ""
  }
  let watcher : ClipboardWatcher = {
    active: Ref(true),
    interval_ms: cbw_clamp_interval(50),
    last: Ref(baseline),
  }
  assert_eq(watcher.interval_ms, 100)
  assert_eq(watcher.last.val, baseline)
  assert_true(watcher.active.val)
}

///|
test "ClipboardError Show 文本" {
  assert_eq(
    ClipboardError::Unsupported.to_string(),
    "ClipboardError::Unsupported",
  )
  assert_eq(
    ClipboardError::CommandFailed("退出码 1").to_string(),
    "ClipboardError::CommandFailed(退出码 1)",
  )
}

///|
test "cbw_get_text：真实只读探测（有 xclip 与 X 会话时读到文本）" {
  if !pr_available() {
    println("cbw_get_text: skip (non-linux)")
    return
  }
  // 只读探测，结果因环境而异打印记录：Ok(文本) / xclip 缺失 Unsupported /
  // 无 X display 时 CommandFailed（pr_run 子进程环境不含 DISPLAY，与
  // mon_list 冒烟同因，不作硬断言）
  match cbw_get_text() {
    Ok(t) => println("cbw_get_text: Ok（\{t.length()} 字符）: \{t}")
    Err(ClipboardError::Unsupported) =>
      println("cbw_get_text: Unsupported（xclip 未安装）")
    Err(e) => println("cbw_get_text: \{e}")
  }
}
