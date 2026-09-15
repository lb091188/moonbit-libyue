///|
test "表格值编码：文本往返" {
  let v : TableValue = Str("hello")
  let (kind, p1, p2) = match v {
    Str(s) => (0, @utf8.encode(s), Bytes::make(0, 0))
    _ => (0, Bytes::make(0, 0), Bytes::make(0, 0))
  }
  inspect(kind, content="0")
  inspect(@utf8.decode_lossy(p1), content="hello")
  inspect(p2.length(), content="0")
}

///|
test "encode_table_value 三种变体的 kind 字节" {
  let enc = encode_table_value(Str("x"))
  inspect(enc[0].to_int(), content="0")
  let enc2 = encode_table_value(Flag(true))
  inspect(enc2[0].to_int(), content="1")
  let enc3 = encode_table_value(ColorText("rgb(1, 2, 3)", "#ff0000"))
  inspect(enc3[0].to_int(), content="2")
}

///|
test "decode_table_value 布尔往返" {
  let enc = encode_table_value(Flag(false))
  // kind 从编码头解出
  let kind = enc[0].to_int()
  // payload：kind=1 时 enc[4] 为 0/1
  inspect(
    decode_table_value(kind, enc, enc[4].to_int()) is Flag(false),
    content="true",
  )
  let enc_t = encode_table_value(Flag(true))
  inspect(decode_table_value(1, enc_t, 1) is Flag(true), content="true")
}
