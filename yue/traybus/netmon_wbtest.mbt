// NM "v"(u) 应答解析测试(纯函数,不连总线)。

///|
test "NM Properties.Get \"v\"(u) 应答往返解析" {
  // Get 的应答体是单 variant,内为 u32(与 GetAll 的 a{sv} 不同)
  match build_reply(1, 8, ":1.8", "v", [VVariant(VU32(70))]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => {
          inspect(m.sig, content="v")
          match vu32_of(m) {
            Some(v) => inspect(v.to_string(), content="70")
            None => inspect("未提取到", content="Some(70)")
          }
        }
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
  // 类型不符(如 bool)→ None,归一化层给 Offline 而非崩
  match build_reply(1, 9, ":1.9", "v", [VVariant(VBool(true))]) {
    Ok(bytes) =>
      match parse_message(bytes[:]) {
        Some(m) => inspect(vu32_of(m) is None, content="true")
        None => inspect("解析失败", content="应可解析")
      }
    Err(_) => inspect("构造失败", content="应可构造")
  }
}
