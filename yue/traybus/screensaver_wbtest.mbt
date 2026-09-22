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
          inspect(m.iface, content="org.xfce.ScreenSaver")
          inspect(m.action, content="ActiveChanged")
          inspect(m.body[0] is VBool(true), content="true")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
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
    items: (Map([]) : Map[String, Item]),
    menus: (Map([]) : Map[String, Item]),
    pending: (Map([]) : Map[Int, (Msg) -> Unit]),
    subs: (Map([]) : Map[String, Array[(Msg) -> Unit]]),
    match_rules: [],
  }
  let got = Ref("")
  c.subs.set(
    "org.xfce.ScreenSaver.ActiveChanged",
    [
      fn(m : Msg) {
        match m.body.get(0) {
          Some(VBool(active)) => got.val = if active { "锁" } else { "解" }
          _ => ()
        }
      },
    ],
  )
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
          inspect(got.val, content="锁")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}
