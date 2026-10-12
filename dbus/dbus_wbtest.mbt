// 通用调用层的单元测试:类型签名、a{sv} 构造与线往返、错误应答解析;
// 真总线冒烟只调 org.freedesktop.DBus 的只读方法(ListNames/重复
// Hello/不存在方法),无总线环境自动跳过。

///|
test "类型签名:各构造器与嵌套" {
  assert_eq(gdbus_sig_of(GVBool(true)), "b")
  assert_eq(gdbus_sig_of(GVInt32(-1)), "i")
  assert_eq(gdbus_sig_of(GVUInt32(1)), "u")
  assert_eq(gdbus_sig_of(GVInt64(2L)), "x")
  assert_eq(gdbus_sig_of(GVU64(3L)), "t")
  assert_eq(gdbus_sig_of(GVDouble(0.5)), "d")
  assert_eq(gdbus_sig_of(GVString("s")), "s")
  assert_eq(gdbus_sig_of(GVPath("/obj")), "o")
  assert_eq(gdbus_sig_of(GVArray("s", [])), "as")
  assert_eq(gdbus_sig_of(GVArray("(ii)", [])), "a(ii)")
  assert_eq(gdbus_sig_of(GVArray("{sv}", [])), "a{sv}")
  assert_eq(gdbus_sig_of(GVDict((Map([]) : Map[String, GDBusValue]))), "a{sv}")
  assert_eq(gdbus_sig_of(GVVariant(GVString("s"))), "v")
  assert_eq(gdbus_sig_of(GVVariant(GVArray("s", []))), "v")
  assert_eq(gdbus_sig_of(GVStruct([GVUInt32(1), GVString("s")])), "(us)")
  assert_eq(gdbus_sig_of(GVNone), "")
}

///|
test "a{sv} 构造与线往返:MPRIS Metadata 形状" {
  let meta : Map[String, GDBusValue] = Map([])
  meta.set("mpris:trackid", GVPath("/org/mpris/MediaPlayer2/track/0"))
  meta.set("xesam:title", GVString("标题"))
  meta.set("xesam:artist", GVArray("s", [GVString("歌手")]))
  meta.set("mpris:length", GVInt64(180000000L))
  meta.set("xesam:userRating", GVDouble(4.5))
  match gdbus_args_wire([GVDict(meta)]) {
    Err(_) => assert_true(false) // 走到错误分支：应可构造
    Ok((sig, dvals)) => {
      assert_eq(sig, "a{sv}")
      match
        build_call(
          7, ":1.9", "/org/mpris/MediaPlayer2", "org.if.I", "M", sig, dvals,
        ) {
        Err(_) => assert_true(false) // 走到错误分支：应可编码
        Ok(bytes) =>
          match parse_message(bytes[:]) {
            None => assert_true(false) // 走到错误分支：应可解析
            Some(m) =>
              match gdbus_reply_value(m) {
                Err(_) => assert_true(false) // 走到错误分支：应成功
                Ok(GVDict(props)) => {
                  assert_eq(props.length(), 5)
                  match props.get("xesam:title") {
                    Some(GVString(t)) => assert_eq(t, "标题")
                    _ => assert_true(false) // 走到错误分支：GVString
                  }
                  match props.get("mpris:trackid") {
                    Some(GVPath(p)) =>
                      assert_eq(p, "/org/mpris/MediaPlayer2/track/0")
                    _ => assert_true(false) // 走到错误分支：GVPath
                  }
                  match props.get("xesam:artist") {
                    Some(GVArray(elem, items)) => {
                      assert_eq(elem, "s")
                      assert_eq(items.length(), 1)
                      assert_true(items[0] is GVString("歌手"))
                    }
                    _ => assert_true(false) // 走到错误分支：GVArray
                  }
                  match props.get("mpris:length") {
                    Some(GVInt64(n)) =>
                      assert_eq(n.to_string(), "180000000")
                    _ => assert_true(false) // 走到错误分支：GVInt64
                  }
                  match props.get("xesam:userRating") {
                    Some(GVDouble(x)) => assert_eq(x.to_string(), "4.5")
                    _ => assert_true(false) // 走到错误分支：GVDouble
                  }
                }
                Ok(_) => assert_true(false) // 走到错误分支：GVDict
              }
          }
      }
    }
  }
}

///|
test "属性 Get/Set 的参数与应答形状" {
  // Set(ssv):值在参数层已包 GVVariant
  match
    gdbus_args_wire([
      GVString("org.if.I"),
      GVString("Prop"),
      GVVariant(GVDouble(50.0)),
    ]) {
    Err(_) => assert_true(false) // 走到错误分支：应可构造
    Ok((sig, dvals)) => {
      assert_eq(sig, "ssv")
      assert_true(dvals[2] is VVariant(VDouble(50.0)))
    }
  }
  // Get(ss) 应答 v:回到调用方再拆一层 variant
  match build_reply(1, 5, ":1.5", "v", [VVariant(VDouble(87.5))]) {
    Err(_) => assert_true(false) // 走到错误分支：应可构造
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => assert_true(false) // 走到错误分支：应可解析
        Some(m) =>
          match gdbus_reply_value(m) {
            Ok(GVVariant(inner)) =>
              assert_true(inner is GVDouble(87.5))
            _ => assert_true(false) // 走到错误分支：GVVariant
          }
      }
  }
}

///|
test "错误应答与空体、多返回值" {
  // 错误应答:错误名 + 首参文本
  match
    build_error(
      9, 3, ":1.0", "org.freedesktop.DBus.Error.UnknownProperty", "没有该属性",
    ) {
    Err(_) => assert_true(false) // 走到错误分支：应可构造
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => assert_true(false) // 走到错误分支：应可解析
        Some(m) =>
          match gdbus_reply_value(m) {
            Err(e) => {
              assert_eq(e.name, "org.freedesktop.DBus.Error.UnknownProperty")
              assert_eq(e.message, "没有该属性")
            }
            Ok(_) => assert_true(false) // 走到错误分支：错误应答
          }
      }
  }
  // 空体应答 → GVNone
  match build_reply(1, 4, ":1.4", "", []) {
    Err(_) => assert_true(false) // 走到错误分支：应可构造
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => assert_true(false) // 走到错误分支：应可解析
        Some(m) => assert_true(gdbus_reply_value(m) is Ok(GVNone))
      }
  }
  // 多返回值 → GVStruct
  match build_reply(1, 6, ":1.6", "ub", [VU32(7), VBool(true)]) {
    Err(_) => assert_true(false) // 走到错误分支：应可构造
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => assert_true(false) // 走到错误分支：应可解析
        Some(m) =>
          match gdbus_reply_value(m) {
            Ok(GVStruct(fields)) => {
              assert_true(fields[0] is GVUInt32(7))
              assert_true(fields[1] is GVBool(true))
            }
            _ => assert_true(false) // 走到错误分支：GVStruct
          }
      }
  }
}

///|
test "from_wire 直映与参数校验" {
  assert_true(gdbus_from_wire(VU64(9L)) is GVU64(9L))
  assert_true(gdbus_from_wire(VQ16(3)) is GVInt32(3))
  assert_true(gdbus_from_wire(VSig("as")) is GVString("as"))
  match gdbus_from_wire(VArray("u", [VU32(1), VU32(2)])) {
    GVArray(elem, items) => {
      assert_eq(elem, "u")
      assert_true(items[1] is GVUInt32(2))
    }
    _ => assert_true(false) // 走到错误分支：GVArray
  }
  // GVNone 不能作参数
  assert_true(gdbus_args_wire([GVNone]) is Err(_))
  assert_true(gdbus_args_wire([GVArray("s", [GVNone])]) is Err(_))
  // 坏元素签名:预检即报错,不带超时代价
  assert_true(gdbus_args_wire([GVArray("", [])]) is Err(_))
}

///|
test "真总线冒烟:ListNames 与错误应答(会话)" {
  match bus_conn() {
    Err(_) => println("skip: 会话总线不可用")
    Ok(c) => {
      // 只读方法:应答 as,含总线自身名
      match
        gdbus_call(
          c,
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "ListNames",
          [],
        ) {
        Ok(GVArray(_, names)) => {
          assert_true(names.length() > 0)
          let mut found = false
          for n in names {
            match n {
              GVString(s) => if s == "org.freedesktop.DBus" { found = true }
              _ => ()
            }
          }
          assert_true(found)
        }
        Ok(_) => assert_true(false) // 走到错误分支：GVArray
        Err(_) => assert_true(false) // 走到错误分支：应成功
      }
      // 不存在的方法:D-Bus 错误应答
      match
        gdbus_call(
          c,
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "NoSuchMethod",
          [],
        ) {
        Err(e) =>
          assert_eq(e.name, "org.freedesktop.DBus.Error.UnknownMethod")
        Ok(_) => assert_true(false) // 走到错误分支：错误应答
      }
      // 连接握手已 Hello,重复 Hello 走错误应答通路(放最后)
      match
        gdbus_call(
          c,
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "Hello",
          [],
        ) {
        Err(e) =>
          assert_true(e.name.has_prefix("org.freedesktop.DBus.Error"))
        Ok(_) => assert_true(false) // 走到错误分支：重复 Hello
      }
    }
  }
}

///|
test "真总线冒烟:ListNames(系统)" {
  match
    gdbus_call_system(
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus",
      "ListNames",
      [],
    ) {
    Ok(GVArray(_, names)) => {
      assert_true(names.length() > 0)
      let mut found = false
      for n in names {
        match n {
          GVString(s) => if s == "org.freedesktop.DBus" { found = true }
          _ => ()
        }
      }
      assert_true(found)
    }
    Ok(_) => assert_true(false) // 走到错误分支：GVArray
    Err(e) => println("skip: 系统总线不可用(\{e.name})")
  }
}
