// DBus 线路编解码的单元测试：签名解析、消息往返、嵌套结构对齐。

///|
test "签名解析" {
  match parse_signature("a(iiay)") {
    Ok(nodes) => inspect(sig_char(nodes[0]), content="a(iiay)")
    Err(_) => inspect("解析失败", content="a(iiay) 应可解析")
  }
  match parse_signature("a{sv}") {
    Ok(nodes) => inspect(sig_char(nodes[0]), content="a{sv}")
    Err(_) => inspect("解析失败", content="a{sv} 应可解析")
  }
  match parse_signature("(sa(iiay)ss)") {
    Ok(nodes) => inspect(sig_char(nodes[0]), content="(sa(iiay)ss)")
    Err(_) => inspect("解析失败", content="复合签名应可解析")
  }
  inspect(parse_signature("a") is Err(_), content="true")
  inspect(parse_signature("z") is Err(_), content="true")
  inspect(parse_signature("{s") is Err(_), content="true")
}

///|
test "消息往返：方法调用" {
  match build_call(
    7,
    "org.example.Dest",
    "/obj/path",
    "org.if.Iface",
    "Member",
    "s",
    [VString("hello")],
  ) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(msg) => {
          inspect(msg.kind, content="1")
          inspect(msg.serial, content="7")
          inspect(msg.path, content="/obj/path")
          inspect(msg.iface, content="org.if.Iface")
          inspect(msg.action, content="Member")
          inspect(msg.sig, content="s")
          inspect(msg.body[0] is VString("hello"), content="true")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}

///|
test "消息往返：空体信号" {
  match build_signal(3, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "NewIcon", "", []) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(msg) => {
          inspect(msg.kind, content="4")
          inspect(msg.path, content="/StatusNotifierItem")
          inspect(msg.action, content="NewIcon")
          inspect(msg.body.length(), content="0")
          inspect(msg.sig, content="")
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}

///|
test "消息往返：a{sv} 属性字典" {
  let dict = VArray(
    "{sv}",
    [
      VStruct([VString("Id"), VVariant(VString("demo"))]),
      VStruct([VString("ItemIsMenu"), VVariant(VBool(true))]),
    ],
  )
  match build_reply(1, 2, ":1.5", "a{sv}", [dict]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          inspect(m.kind, content="2")
          inspect(m.reply_serial, content="2")
          inspect(m.body.length(), content="1")
          match m.body[0] {
            VArray(_, entries) => {
              inspect(entries.length(), content="2")
              match entries[0] {
                VStruct([VString(name), VVariant(VString(value))]) => {
                  inspect(name, content="Id")
                  inspect(value, content="demo")
                }
                _ => inspect("结构不符", content="VStruct[VString, VVariant]")
              }
              match entries[1] {
                VStruct([VString(name), VVariant(VBool(b))]) => {
                  inspect(name, content="ItemIsMenu")
                  inspect(b, content="true")
                }
                _ => inspect("结构不符", content="VStruct[VString, VVariant]")
              }
            }
            _ => inspect("不是数组", content="VArray")
          }
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}

///|
test "消息往返：IconPixmap 嵌套结构 (iiay)" {
  let px = VStruct([
    VI32(2),
    VI32(1),
    VArray("y", [VByte(255), VByte(0), VByte(16), VByte(32)]),
  ])
  match build_reply(1, 1, ":1.1", "(iiay)", [px]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) =>
          match m.body[0] {
            VStruct([VI32(w), VI32(h), VArray(_, pixels)]) => {
              inspect(w, content="2")
              inspect(h, content="1")
              inspect(pixels.length(), content="4")
              inspect(pixels[3] is VByte(32), content="true")
            }
            _ => inspect("结构不符", content="VStruct[VI32, VI32, VArray]")
          }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}

///|
test "消息往返：ToolTip (sa(iiay)ss)" {
  let tip = VStruct([
    VString(""),
    VArray("(iiay)", []),
    VString("标题"),
    VString("内容"),
  ])
  match build_reply(1, 1, ":1.1", "(sa(iiay)ss)", [tip]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) =>
          match m.body[0] {
            VStruct([VString(a), VArray(_, n), VString(t), VString(b)]) => {
              inspect(a, content="")
              inspect(n.length(), content="0")
              inspect(t, content="标题")
              inspect(b, content="内容")
            }
            _ => inspect("结构不符", content="ToolTip")
          }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}

///|
test "畸形与截断输入" {
  inspect(parse_message(Bytes::make(0, 0)[:]) is None, content="true")
  inspect(parse_message(Bytes::make(5, 0)[:]) is None, content="true")
  // 首字节非小端标记应被拒绝
  inspect(parse_message(Bytes::make(16, 0)[:]) is None, content="true")
}

///|
test "月牙图标位图" {
  let (w, h, px) = default_icon_pixmap()
  inspect(w, content="32")
  inspect(h, content="32")
  inspect(px.length(), content="4096")
  inspect(px[0].to_int(), content="0") // 角落透明
  // (10,16) 在月牙主体上，alpha 通道 > 0
  inspect(px[(16 * 32 + 10) * 4].to_int() > 0, content="true")
}

///|
test "桌面环境识别" {
  inspect(parse_desktop_env(Some("ubuntu:GNOME")) is Gnome, content="true")
  inspect(parse_desktop_env(Some("XFCE")) is Xfce, content="true")
  inspect(parse_desktop_env(Some("KDE")) is Kde, content="true")
  inspect(parse_desktop_env(Some("X-Cinnamon")) is Cinnamon, content="true")
  inspect(parse_desktop_env(None) is Unknown, content="true")
}


