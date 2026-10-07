// 通用调用层的单元测试:类型签名、a{sv} 构造与线往返、错误应答解析;
// 真总线冒烟只调 org.freedesktop.DBus 的只读方法(ListNames/重复
// Hello/不存在方法),无总线环境自动跳过。

///|
test "类型签名:各构造器与嵌套" {
  inspect(gdbus_sig_of(GVBool(true)), content="b")
  inspect(gdbus_sig_of(GVInt32(-1)), content="i")
  inspect(gdbus_sig_of(GVUInt32(1)), content="u")
  inspect(gdbus_sig_of(GVInt64(2L)), content="x")
  inspect(gdbus_sig_of(GVU64(3L)), content="t")
  inspect(gdbus_sig_of(GVDouble(0.5)), content="d")
  inspect(gdbus_sig_of(GVString("s")), content="s")
  inspect(gdbus_sig_of(GVPath("/obj")), content="o")
  inspect(gdbus_sig_of(GVArray("s", [])), content="as")
  inspect(gdbus_sig_of(GVArray("(ii)", [])), content="a(ii)")
  inspect(gdbus_sig_of(GVArray("{sv}", [])), content="a{sv}")
  inspect(
    gdbus_sig_of(GVDict((Map([]) : Map[String, GDBusValue]))),
    content="a{sv}",
  )
  inspect(gdbus_sig_of(GVVariant(GVString("s"))), content="v")
  inspect(gdbus_sig_of(GVVariant(GVArray("s", []))), content="v")
  inspect(gdbus_sig_of(GVStruct([GVUInt32(1), GVString("s")])), content="(us)")
  inspect(gdbus_sig_of(GVNone), content="")
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
    Err(_) => inspect("构造失败", content="应可构造")
    Ok((sig, dvals)) => {
      inspect(sig, content="a{sv}")
      match
        build_call(
          7, ":1.9", "/org/mpris/MediaPlayer2", "org.if.I", "M", sig, dvals,
        ) {
        Err(_) => inspect("编码失败", content="应可编码")
        Ok(bytes) =>
          match parse_message(bytes[:]) {
            None => inspect("解析失败", content="应可解析")
            Some(m) =>
              match gdbus_reply_value(m) {
                Err(_) => inspect("应答解析失败", content="应成功")
                Ok(GVDict(props)) => {
                  inspect(props.length(), content="5")
                  match props.get("xesam:title") {
                    Some(GVString(t)) => inspect(t, content="标题")
                    _ => inspect("类型不符", content="GVString")
                  }
                  match props.get("mpris:trackid") {
                    Some(GVPath(p)) =>
                      inspect(p, content="/org/mpris/MediaPlayer2/track/0")
                    _ => inspect("类型不符", content="GVPath")
                  }
                  match props.get("xesam:artist") {
                    Some(GVArray(elem, items)) => {
                      inspect(elem, content="s")
                      inspect(items.length(), content="1")
                      inspect(items[0] is GVString("歌手"), content="true")
                    }
                    _ => inspect("类型不符", content="GVArray")
                  }
                  match props.get("mpris:length") {
                    Some(GVInt64(n)) =>
                      inspect(n.to_string(), content="180000000")
                    _ => inspect("类型不符", content="GVInt64")
                  }
                  match props.get("xesam:userRating") {
                    Some(GVDouble(x)) => inspect(x.to_string(), content="4.5")
                    _ => inspect("类型不符", content="GVDouble")
                  }
                }
                Ok(_) => inspect("应答类型不符", content="GVDict")
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
    Err(_) => inspect("构造失败", content="应可构造")
    Ok((sig, dvals)) => {
      inspect(sig, content="ssv")
      inspect(dvals[2] is VVariant(VDouble(50.0)), content="true")
    }
  }
  // Get(ss) 应答 v:回到调用方再拆一层 variant
  match build_reply(1, 5, ":1.5", "v", [VVariant(VDouble(87.5))]) {
    Err(_) => inspect("构造失败", content="应可构造")
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => inspect("解析失败", content="应可解析")
        Some(m) =>
          match gdbus_reply_value(m) {
            Ok(GVVariant(inner)) =>
              inspect(inner is GVDouble(87.5), content="true")
            _ => inspect("应答形状不符", content="GVVariant")
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
    Err(_) => inspect("构造失败", content="应可构造")
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => inspect("解析失败", content="应可解析")
        Some(m) =>
          match gdbus_reply_value(m) {
            Err(e) => {
              inspect(
                e.name,
                content="org.freedesktop.DBus.Error.UnknownProperty",
              )
              inspect(e.message, content="没有该属性")
            }
            Ok(_) => inspect("应失败", content="错误应答")
          }
      }
  }
  // 空体应答 → GVNone
  match build_reply(1, 4, ":1.4", "", []) {
    Err(_) => inspect("构造失败", content="应可构造")
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => inspect("解析失败", content="应可解析")
        Some(m) => inspect(gdbus_reply_value(m) is Ok(GVNone), content="true")
      }
  }
  // 多返回值 → GVStruct
  match build_reply(1, 6, ":1.6", "ub", [VU32(7), VBool(true)]) {
    Err(_) => inspect("构造失败", content="应可构造")
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        None => inspect("解析失败", content="应可解析")
        Some(m) =>
          match gdbus_reply_value(m) {
            Ok(GVStruct(fields)) => {
              inspect(fields[0] is GVUInt32(7), content="true")
              inspect(fields[1] is GVBool(true), content="true")
            }
            _ => inspect("应答形状不符", content="GVStruct")
          }
      }
  }
}

///|
test "from_wire 直映与参数校验" {
  inspect(gdbus_from_wire(VU64(9L)) is GVU64(9L), content="true")
  inspect(gdbus_from_wire(VQ16(3)) is GVInt32(3), content="true")
  inspect(gdbus_from_wire(VSig("as")) is GVString("as"), content="true")
  match gdbus_from_wire(VArray("u", [VU32(1), VU32(2)])) {
    GVArray(elem, items) => {
      inspect(elem, content="u")
      inspect(items[1] is GVUInt32(2), content="true")
    }
    _ => inspect("类型不符", content="GVArray")
  }
  // GVNone 不能作参数
  inspect(gdbus_args_wire([GVNone]) is Err(_), content="true")
  inspect(gdbus_args_wire([GVArray("s", [GVNone])]) is Err(_), content="true")
  // 坏元素签名:预检即报错,不带超时代价
  inspect(gdbus_args_wire([GVArray("", [])]) is Err(_), content="true")
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
          inspect(names.length() > 0, content="true")
          let mut found = false
          for n in names {
            match n {
              GVString(s) => if s == "org.freedesktop.DBus" { found = true }
              _ => ()
            }
          }
          inspect(found, content="true")
        }
        Ok(_) => inspect("应答类型不符", content="GVArray")
        Err(e) => inspect("ListNames 失败: \{e.name}", content="应成功")
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
          inspect(e.name, content="org.freedesktop.DBus.Error.UnknownMethod")
        Ok(_) => inspect("应失败", content="错误应答")
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
          inspect(
            e.name.has_prefix("org.freedesktop.DBus.Error"),
            content="true",
          )
        Ok(_) => inspect("应失败", content="重复 Hello")
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
      inspect(names.length() > 0, content="true")
      let mut found = false
      for n in names {
        match n {
          GVString(s) => if s == "org.freedesktop.DBus" { found = true }
          _ => ()
        }
      }
      inspect(found, content="true")
    }
    Ok(_) => inspect("应答类型不符", content="GVArray")
    Err(e) => println("skip: 系统总线不可用(\{e.name})")
  }
}
