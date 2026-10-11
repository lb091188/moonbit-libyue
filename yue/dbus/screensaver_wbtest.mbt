// 屏保锁屏信号的线格式往返、分发与状态机去重测试(不连总线)。

///|
test "ActiveChanged(b) 信号往返" {
  match
    build_signal(
      31,
      "/org/xfce/ScreenSaver",
      "org.xfce.ScreenSaver",
      "ActiveChanged",
      "b",
      [VBool(true)],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          assert_eq(m.iface, "org.xfce.ScreenSaver")
          assert_eq(m.action, "ActiveChanged")
          assert_true(m.body[0] is VBool(true))
        }
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
}

///|
test "订阅表按 服务名.ActiveChanged 分发" {
  let c : Conn = {
    fd: -1,
    bus: 0,
    serial: 0,
    name: "",
    alive: false,
    acc: FixedArray::make(16, b'\x00'),
    acc_len: 0,
    pending: (Map([]) : Map[Int, (Msg) -> Unit]),
    subs: (Map([]) : Map[String, Array[(Msg) -> Unit]]),
    match_rules: [],
  }
  let got = Ref("")
  c.subs.set("org.xfce.ScreenSaver.ActiveChanged", [
    fn(m : Msg) {
      match m.body.get(0) {
        Some(VBool(active)) => got.val = if active { "锁" } else { "解" }
        _ => ()
      }
    },
  ])
  match
    build_signal(
      32,
      "/org/xfce/ScreenSaver",
      "org.xfce.ScreenSaver",
      "ActiveChanged",
      "b",
      [VBool(true)],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          c.handle(m)
          assert_eq(got.val, "锁")
        }
        None => assert_true(false) // 走到错误分支：应可解析
      }
    Err(_) => assert_true(false) // 走到错误分支：应可构造
  }
}
