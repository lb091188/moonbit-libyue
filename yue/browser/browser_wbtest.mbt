// 自定义协议载荷编解码白盒测试:与 shim yue_mbt_browser_register_protocol
// 的解码逻辑逐位对齐(测试侧 decode_protocol_payload 与 C 端同构:先按
// Bytes 载荷长度预验,再逐段取 mime/content,任一段越界即拒绝)。
// 覆盖 Some(恒成功)与 None(拒绝)两条路径、UTF-8 多字节按字节计长、
// 空 mime/content 的 12 字节最小载荷,以及 C 端防御性拒绝对应的两类
// 坏载荷:ok=1 但载荷不足 12 字节(旧版拒绝载荷 [1,0,0,0] 的形态)、
// mime_len / content_len 声称长度越出载荷。

///|
/// 测试侧解码:与 C 端 yue_mbt_browser_register_protocol 的逻辑同构,
/// 先按载荷长度预验再逐段取值;任一段越界即拒绝(None)。
fn decode_protocol_payload(payload : Bytes) -> (String, String)? {
  let rd_i32 = fn(off : Int) -> Int {
    (payload[off].to_int() & 255) |
      ((payload[off + 1].to_int() & 255) << 8) |
      ((payload[off + 2].to_int() & 255) << 16) |
      ((payload[off + 3].to_int() & 255) << 24)
  }
  let slice_utf8 = fn(off : Int, len : Int) -> String {
    let buf = FixedArray::make(len, b'\x00')
    for j = 0; j < len; j = j + 1 {
      buf[j] = payload[off + j]
    }
    from_utf8_bytes(Bytes::from_array(buf))
  }
  if payload.length() < 12 {
    return None
  }
  if rd_i32(0) != 1 {
    return None
  }
  let mime_len = rd_i32(4)
  if mime_len < 0 || mime_len + 12 > payload.length() {
    return None
  }
  let content_len = rd_i32(8 + mime_len)
  if content_len < 0 || mime_len + 12 + content_len > payload.length() {
    return None
  }
  Some((slice_utf8(8, mime_len), slice_utf8(12 + mime_len, content_len)))
}

///|
/// 小端 Int32 四字节(与编码侧 put_len 对齐,供期望值拼装)。
fn le_i32(v : Int) -> Array[Byte] {
  [
    (v & 255).to_byte(),
    ((v >> 8) & 255).to_byte(),
    ((v >> 16) & 255).to_byte(),
    ((v >> 24) & 255).to_byte(),
  ]
}

///|
/// 若干字节段顺序连接(当前 core 版本 Array 无 ++ 运算符,显式拼装)。
fn cat_bytes(parts : Array[Array[Byte]]) -> Array[Byte] {
  let out : Array[Byte] = []
  for part in parts {
    for b in part {
      out.push(b)
    }
  }
  out
}

///|
test "protocol_payload None 拒绝载荷为 [0,0,0,0] 且解码侧拒绝" {
  let payload = encode_protocol_payload(None)
  assert_eq(payload.length(), 4)
  assert_eq(payload, Bytes::from_array([0, 0, 0, 0]))
  // 首 4 字节小端读出的 ok 必须为 0(C 端据此返回 nullptr 拒绝请求)
  assert_eq(payload[0].to_int(), 0)
  assert_true(decode_protocol_payload(payload) is None)
}

///|
test "protocol_payload Some 载荷逐字节对齐(ok/mime_len/mime/content_len/content)" {
  let payload = encode_protocol_payload(Some(("text/html", "hi")))
  let expect = cat_bytes([
    le_i32(1),
    le_i32(9),
    utf8_bytes("text/html").to_array(),
    le_i32(2),
    utf8_bytes("hi").to_array(),
  ])
  assert_eq(payload.length(), 12 + 9 + 2)
  assert_eq(payload, Bytes::from_array(expect))
  assert_eq(decode_protocol_payload(payload), Some(("text/html", "hi")))
}

///|
test "protocol_payload Some UTF-8 多字节按字节数计长" {
  let content = "中文✓"
  let payload = encode_protocol_payload(Some(("text/html", content)))
  let mb = utf8_bytes("text/html")
  let cb = utf8_bytes(content)
  assert_eq(mb.length(), 9)
  assert_eq(cb.length(), 9)
  assert_eq(payload.length(), 12 + 9 + 9)
  assert_eq(decode_protocol_payload(payload), Some(("text/html", content)))
}

///|
test "protocol_payload Some 空 mime/content 为 12 字节最小载荷" {
  let payload = encode_protocol_payload(Some(("", "")))
  assert_eq(payload.length(), 12)
  assert_eq(payload[0].to_int(), 1)
  assert_eq(decode_protocol_payload(payload), Some(("", "")))
}

///|
test "protocol_payload 旧版拒绝载荷(ok=1 但仅 4 字节)按拒绝解码" {
  // 回归:旧版 None 路径返回 [1,0,0,0],C 端按 ok=1 当成功后越界读长度。
  // 修复后该形态载荷不足 12 字节,C 端与测试侧解码一致按拒绝处理。
  let stale_reject = Bytes::from_array([1, 0, 0, 0])
  assert_eq(stale_reject.length(), 4)
  assert_true(decode_protocol_payload(stale_reject) is None)
}

///|
test "protocol_payload ok=1 短载荷(8 字节)按拒绝解码" {
  // ok=1 且已带 mime_len,但整体不足 12 字节:预验即拒,不读 mime 段
  let short = Bytes::from_array(cat_bytes([le_i32(1), le_i32(9)]))
  assert_eq(short.length(), 8)
  assert_true(decode_protocol_payload(short) is None)
}

///|
test "protocol_payload mime_len / content_len 越出载荷按拒绝解码" {
  // mime_len 声称 9,实际 mime 段只有 8 字节:整包 16 字节,mime 段越界
  let mime_over = Bytes::from_array(
    cat_bytes([le_i32(1), le_i32(9), utf8_bytes("12345678").to_array()]),
  )
  assert_eq(mime_over.length(), 16)
  assert_true(decode_protocol_payload(mime_over) is None)
  // mime 段够长(1 字节),但 content_len 声称 5 而剩余只有 2 字节
  let content_over = Bytes::from_array(
    cat_bytes([
      le_i32(1),
      le_i32(1),
      utf8_bytes("x").to_array(),
      le_i32(5),
      utf8_bytes("ab").to_array(),
    ]),
  )
  assert_eq(content_over.length(), 15)
  assert_true(decode_protocol_payload(content_over) is None)
}

///|
test "protocol_payload 往返:长内容与含引号/换行的 HTML" {
  let content = "<html>\n<body>\"demo://\" ✓ 自定义协议</body>\n</html>"
  let payload = encode_protocol_payload(Some(("text/html; charset=utf-8", content)))
  assert_eq(
    decode_protocol_payload(payload),
    Some(("text/html; charset=utf-8", content)),
  )
}
