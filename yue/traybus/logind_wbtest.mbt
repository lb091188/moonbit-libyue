// logind 信号的线格式往返与注册表分发单元测试(不连总线:分发链用
// 假连接走 Conn::handle 的订阅表分支)。

///|
/// 构造不连总线的假连接(分发只碰订阅表,不触 fd)。
fn fake_conn() -> Conn {
  {
    fd: -1,
    bus: 1,
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
}

///|
test "PrepareForSleep(b) 信号往返与注册表分发" {
  match
    build_signal(
      21,
      "/org/freedesktop/login1",
      "org.freedesktop.login1.Manager",
      "PrepareForSleep",
      "b",
      [VBool(true)],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          inspect(m.kind, content="4")
          inspect(m.iface, content="org.freedesktop.login1.Manager")
          inspect(m.action, content="PrepareForSleep")
          inspect(m.body[0] is VBool(true), content="true")
          let c = fake_conn()
          let got = Ref("")
          c.subs.set(
            "org.freedesktop.login1.Manager.PrepareForSleep",
            [
              fn(m2 : Msg) {
                match m2.body.get(0) {
                  Some(VBool(start)) => got.val = if start { "睡" } else { "醒" }
                  _ => ()
                }
              },
            ],
          )
          c.handle(m)
          inspect(got.val, content="睡")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}

///|
test "Session Lock/Unlock 空体信号按成员分发" {
  let c = fake_conn()
  let got = Ref("")
  c.subs.set(
    "org.freedesktop.login1.Session.Lock",
    [fn(_m : Msg) { got.val = "锁" }],
  )
  c.subs.set(
    "org.freedesktop.login1.Session.Unlock",
    [fn(_m : Msg) { got.val = "解" }],
  )
  match
    build_signal(
      22,
      "/org/freedesktop/login1/session/_31",
      "org.freedesktop.login1.Session",
      "Lock",
      "",
      [],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          inspect(m.body.length(), content="0")
          c.handle(m)
          inspect(got.val, content="锁")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
  match
    build_signal(
      23,
      "/org/freedesktop/login1/session/_31",
      "org.freedesktop.login1.Session",
      "Unlock",
      "",
      [],
    ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          c.handle(m)
          inspect(got.val, content="解")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}
