// DBus 线路格式编解码（只支持小端 'l'）。
//
// 对齐作用域规则：对齐零点随作用域——消息顶层（头/体）相对消息起点，
// 数组内容相对数组数据起点；结构体字段沿用外层零点。
// 因此所有 encode/decode 函数都显式携带 base（当前作用域起点在
// 本缓冲/本消息内的偏移），Buf 的 base 取负值（缓冲起点相对作用域）。

///|
/// 解析后的 DBus 值。
priv enum DVal {
  VByte(Int)
  VBool(Bool)
  VI16(Int)
  VQ16(Int)
  VI32(Int)
  VU32(Int)
  VI64(Int64)
  VString(String)
  VPath(String)
  VSig(String)
  VArray(String, Array[DVal]) // 元素签名 + 值（签名供嵌套 variant 推导）
  VStruct(Array[DVal])
  VVariant(DVal)
}

///|
fn sig_align(s : Sig) -> Int {
  match s {
    SigByte | SigSig | SigVariant => 1
    SigI16 | SigQ16 => 2
    SigBool | SigI32 | SigU32 | SigString | SigPath | SigArray(_) => 4
    SigI64 => 8
    SigStruct(_) => 8
    SigDict(_, _) => 8
  }
}

///|
priv enum Sig {
  SigByte
  SigBool
  SigI16
  SigQ16
  SigI32
  SigU32
  SigI64
  SigString
  SigPath
  SigSig
  SigVariant
  SigArray(Sig)
  SigStruct(Array[Sig])
  SigDict(Sig, Sig) // {k v}，编解码行为同双字段结构体
}

///|
priv struct SigParser {
  sig : String
  mut pos : Int
}

///|
fn SigParser::peek(self : SigParser) -> Int {
  if self.pos < self.sig.length() {
    self.sig.unsafe_get(self.pos).to_int()
  } else {
    -1
  }
}

///|
fn SigParser::next(self : SigParser) -> Int {
  let c = self.peek()
  if c >= 0 {
    self.pos += 1
  }
  c
}

///|
fn parse_one_sig(p : SigParser) -> Result[Sig, String] {
  match p.next() {
    121 => Ok(SigByte) // y
    98 => Ok(SigBool) // b
    110 => Ok(SigI16) // n
    113 => Ok(SigQ16) // q
    105 => Ok(SigI32) // i
    117 => Ok(SigU32) // u
    120 => Ok(SigI64) // x
    115 => Ok(SigString) // s
    111 => Ok(SigPath) // o
    103 => Ok(SigSig) // g
    118 => Ok(SigVariant) // v
    97 => // a
      match parse_one_sig(p) {
        Ok(elem) => Ok(SigArray(elem))
        Err(e) => Err(e)
      }
    40 => { // ( 结构体
      let fields : Array[Sig] = []
      let mut closed = false
      while !closed {
        match p.peek() {
          41 => {
            let _ = p.next()
            closed = true
          }
          -1 => return Err("结构体签名未闭合")
          _ =>
            match parse_one_sig(p) {
              Ok(f) => fields.push(f)
              Err(e) => return Err(e)
            }
        }
      }
      Ok(SigStruct(fields))
    }
    123 => { // { 字典项：恰好两个完整类型
      let k = match parse_one_sig(p) {
        Ok(k) => k
        Err(e) => return Err(e)
      }
      let v = match parse_one_sig(p) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if p.next() != 125 {
        return Err("字典项签名未闭合")
      }
      Ok(SigDict(k, v))
    }
    -1 => Err("签名提前结束")
    c => Err("非法签名字符: \{c}")
  }
}

///|
fn parse_signature(sig : String) -> Result[Array[Sig], String] {
  let p : SigParser = { sig, pos: 0, }
  let out : Array[Sig] = []
  while p.pos < sig.length() {
    match parse_one_sig(p) {
      Ok(s) => out.push(s)
      Err(e) => return Err(e)
    }
  }
  if out.is_empty() {
    Err("空签名")
  } else {
    Ok(out)
  }
}

///|
fn sig_of(v : DVal) -> String {
  match v {
    VByte(_) => "y"
    VBool(_) => "b"
    VI16(_) => "n"
    VQ16(_) => "q"
    VI32(_) => "i"
    VU32(_) => "u"
    VI64(_) => "x"
    VString(_) => "s"
    VPath(_) => "o"
    VSig(_) => "g"
    VArray(elem, _) => "a" + elem
    VStruct(fields) => {
      let sb = StringBuilder()
      sb.write_string("(")
      for f in fields {
        sb.write_string(sig_of(f))
      }
      sb.write_string(")")
      sb.to_string()
    }
    VVariant(inner) => sig_of(inner)
  }
}

// ---------- 写缓冲 ----------

///|
priv struct Buf {
  mut data : FixedArray[Byte]
  mut len : Int
  mut base : Int // 缓冲内容在其作用域内的负偏移（体缓冲 = -头长度）
}

///|
fn Buf::new() -> Buf {
  { data: FixedArray::make(256, b'\x00'), len: 0, base: 0, }
}

///|
fn Buf::ensure(self : Buf, extra : Int) -> Unit {
  if self.len + extra > self.data.length() {
    let mut cap = self.data.length()
    while cap < self.len + extra {
      cap = cap * 2
    }
    let nd : FixedArray[Byte] = FixedArray::make(cap, b'\x00')
    for i in 0..<self.len {
      nd[i] = self.data[i]
    }
    self.data = nd
  }
}

///|
/// 补齐到 n 的倍数（相对作用域起点）。
fn Buf::pad(self : Buf, n : Int) -> Unit {
  while (self.len + self.base) % n != 0 {
    self.u8(0)
  }
}

///|
fn Buf::u8(self : Buf, v : Int) -> Unit {
  self.ensure(1)
  self.data[self.len] = (v & 0xFF).to_byte()
  self.len += 1
}

///|
fn Buf::u32(self : Buf, v : Int) -> Unit {
  self.pad(4)
  self.u8(v)
  self.u8(v >> 8)
  self.u8(v >> 16)
  self.u8(v >> 24)
}

///|
fn Buf::i64(self : Buf, v : Int64) -> Unit {
  self.pad(8)
  for k in 0..<8 {
    self.u8(((v >> (k * 8)) & 0xFFL).to_int())
  }
}

///|
fn Buf::raw(self : Buf, b : Bytes) -> Unit {
  self.ensure(b.length())
  for i in 0..<b.length() {
    self.data[self.len + i] = b[i]
  }
  self.len += b.length()
}

///|
/// 字符串 = u32 长度 + UTF-8 字节 + '\0'。
fn Buf::string(self : Buf, s : String) -> Unit {
  let b = utf8(s)
  self.u32(b.length())
  self.raw(b)
  self.u8(0)
}

///|
/// 签名 = u8 长度 + ASCII + '\0'（无对齐）。
fn Buf::sig_field(self : Buf, s : String) -> Unit {
  let b = utf8(s)
  self.u8(b.length())
  self.raw(b)
  self.u8(0)
}

///|
fn Buf::to_bytes(self : Buf) -> Bytes {
  Bytes::makei(self.len, fn(i) { self.data[i] })
}

///|
fn Buf::len(self : Buf) -> Int {
  self.len
}

///|
/// 回填已预留的 u32（位置必须已对齐，裸写 4 字节）。
fn Buf::patch_u32(self : Buf, pos : Int, v : Int) -> Unit {
  self.data[pos] = v.to_byte()
  self.data[pos + 1] = (v >> 8).to_byte()
  self.data[pos + 2] = (v >> 16).to_byte()
  self.data[pos + 3] = (v >> 24).to_byte()
}

///|
/// 把子缓冲内容追加进来（子缓冲的作用域已闭合，平移不破坏对齐）。
fn Buf::append(self : Buf, other : Buf) -> Unit {
  self.raw(other.to_bytes())
}

///|
fn encode(buf : Buf, s : Sig, v : DVal) -> Unit {
  match (s, v) {
    (SigByte, VByte(n)) => buf.u8(n)
    (SigBool, VBool(b)) => buf.u32(if b { 1 } else { 0 })
    (SigI16, VI16(n)) => {
      buf.pad(2)
      buf.u8(n)
      buf.u8(n >> 8)
    }
    (SigQ16, VQ16(n)) => {
      buf.pad(2)
      buf.u8(n)
      buf.u8(n >> 8)
    }
    (SigI32, VI32(n)) => buf.u32(n)
    (SigU32, VU32(n)) => buf.u32(n)
    (SigI64, VI64(n)) => buf.i64(n)
    (SigString, VString(s)) => buf.string(s)
    (SigPath, VPath(s)) => {
      buf.pad(4)
      buf.string(s)
    }
    (SigSig, VSig(s)) => buf.sig_field(s)
    (SigArray(elem), VArray(_, items)) => {
      buf.pad(4)
      let len_pos = buf.len()
      buf.u32(0) // 长度占位，编码完内容后回填
      // 首元素前的对齐填充：写入但不计入数组长度（与 GDBus 行为一致）
      buf.pad(sig_align(elem))
      let content = Buf::new()
      // 元素对齐基准与消息一致：内容起点的绝对偏移 = -buf.base + 当前长度
      content.base = -buf.base + buf.len()
      for it in items {
        encode(content, elem, it)
      }
      buf.patch_u32(len_pos, content.len())
      buf.append(content)
    }
    (SigStruct(fields), VStruct(vals)) => {
      buf.pad(8)
      for i in 0..<fields.length() {
        encode(buf, fields[i], vals[i])
      }
    }
    (SigDict(k, v), VStruct([a, b])) => {
      buf.pad(8)
      encode(buf, k, a)
      encode(buf, v, b)
    }
    (SigVariant, VVariant(inner)) => {
      buf.sig_field(sig_of(inner))
      match parse_signature(sig_of(inner)) {
        Ok([node]) => encode(buf, node, inner)
        _ => () // sig_of 恒可解析，防御分支
      }
    }
    _ => () // 签名与值不匹配：调用方契约，静默跳过
  }
}

// ---------- 消息构造 ----------

///|
priv struct Msg {
  kind : Int // 1 调用 2 返回 3 错误 4 信号
  serial : Int
  mut path : String
  mut iface : String
  mut action : String
  mut error_name : String
  mut reply_serial : Int
  mut sender : String
  mut sig : String
  body : Array[DVal]
}

///|
fn Msg::fresh(kind : Int, serial : Int) -> Msg {
  {
    kind,
    serial,
    path: "",
    iface: "",
    action: "",
    error_name: "",
    reply_serial: 0,
    sender: "",
    sig: "",
    body: [],
  }
}

///|
/// 从值中取字符串（类型不符返回 None）。
fn dstr(v : DVal) -> String? {
  match v {
    VString(s) => Some(s)
    VPath(s) => Some(s)
    _ => None
  }
}

///|
fn put_field_string(fields : Buf, tag : Int, value : String) -> Unit {
  fields.pad(8)
  fields.u8(tag)
  fields.sig_field("s")
  fields.string(value)
}

///|
/// 对象路径：与字符串同编码，variant 签名为 "o"。
fn put_field_path(fields : Buf, tag : Int, value : String) -> Unit {
  fields.pad(8)
  fields.u8(tag)
  fields.sig_field("o")
  fields.string(value)
}

///|
/// 签名头字段：variant 签名为 "g"，值是 u8 长度前缀的签名编码。
fn put_field_signature(fields : Buf, tag : Int, value : String) -> Unit {
  fields.pad(8)
  fields.u8(tag)
  fields.sig_field("g")
  fields.sig_field(value)
}

///|
fn put_field_u32(fields : Buf, tag : Int, value : Int) -> Unit {
  fields.pad(8)
  fields.u8(tag)
  fields.sig_field("u")
  fields.u32(value)
}

///|
fn build_msg(
  kind : Int,
  flags : Int,
  serial : Int,
  path : String,
  iface : String,
  action : String,
  error_name : String,
  reply_serial : Int,
  dest : String,
  sig : String,
  args : Array[DVal],
) -> Result[Bytes, String] {
  let fields = Buf::new()
  fields.base = -16 // 头部字段数组数据从消息偏移 16 开始
  if path != "" {
    put_field_path(fields, 1, path)
  }
  if iface != "" {
    put_field_string(fields, 2, iface)
  }
  if action != "" {
    put_field_string(fields, 3, action)
  }
  if error_name != "" {
    put_field_string(fields, 4, error_name)
  }
  if reply_serial > 0 {
    put_field_u32(fields, 5, reply_serial)
  }
  if dest != "" {
    put_field_string(fields, 6, dest)
  }
  if sig != "" {
    put_field_signature(fields, 8, sig)
  }
  let header_len = (16 + fields.len() + 7) / 8 * 8
  let body = Buf::new()
  body.base = -header_len // 体对齐相对消息起点
  if sig != "" {
    match parse_signature(sig) {
      Ok(nodes) => {
        if nodes.length() != args.length() {
          return Err("签名与参数个数不符: \{sig}")
        }
        for i in 0..<nodes.length() {
          encode(body, nodes[i], args[i])
        }
      }
      Err(e) => return Err(e)
    }
  }
  let head = Buf::new()
  head.u8(108) // 'l' 小端
  head.u8(kind)
  head.u8(flags)
  head.u8(1) // 协议版本
  head.u32(body.len())
  head.u32(serial)
  head.u32(fields.len())
  head.append(fields)
  while head.len() < header_len {
    head.u8(0)
  }
  head.raw(body.to_bytes())
  Ok(head.to_bytes())
}

///|
fn build_call(
  serial : Int,
  dest : String,
  path : String,
  iface : String,
  action : String,
  sig : String,
  args : Array[DVal],
) -> Result[Bytes, String] {
  build_msg(1, 0, serial, path, iface, action, "", 0, dest, sig, args)
}

///|
fn build_signal(
  serial : Int,
  path : String,
  iface : String,
  action : String,
  sig : String,
  args : Array[DVal],
) -> Result[Bytes, String] {
  build_msg(4, 1, serial, path, iface, action, "", 0, "", sig, args)
}

///|
fn build_reply(
  serial : Int,
  reply_serial : Int,
  dest : String,
  sig : String,
  args : Array[DVal],
) -> Result[Bytes, String] {
  build_msg(2, 1, serial, "", "", "", "", reply_serial, dest, sig, args)
}

///|
fn build_error(
  serial : Int,
  reply_serial : Int,
  dest : String,
  error_name : String,
  text : String,
) -> Result[Bytes, String] {
  build_msg(3, 1, serial, "", "", "", error_name, reply_serial, dest, "s", [
    VString(text),
  ])
}

// ---------- 解析 ----------

///|
priv struct Rd {
  data : BytesView
  mut pos : Int
}

///|
fn Rd::pad(self : Rd, n : Int, base : Int) -> Unit {
  while (self.pos - base) % n != 0 {
    self.pos += 1
  }
}

///|
fn Rd::u8v(self : Rd) -> Int {
  let v = self.data[self.pos].to_int()
  self.pos += 1
  v
}

///|
fn Rd::u32v(self : Rd) -> Int {
  let v = self.data[self.pos].to_int() |
    (self.data[self.pos + 1].to_int() << 8) |
    (self.data[self.pos + 2].to_int() << 16) |
    (self.data[self.pos + 3].to_int() << 24)
  self.pos += 4
  v
}

///|
fn Rd::i64v(self : Rd) -> Int64 {
  let mut v : Int64 = 0L
  for k in 0..<8 {
    v = v | (Int64::from_int(self.data[self.pos + k].to_int()) << (k * 8))
  }
  self.pos += 8
  v
}

///|
fn Rd::read_string(self : Rd) -> String {
  let len = self.u32v()
  let s = @utf8.decode_lossy(self.data[self.pos:self.pos + len])
  self.pos += len + 1 // 跳过 '\0'
  s
}

///|
fn Rd::read_sig(self : Rd) -> String {
  let len = self.u8v()
  let s = @utf8.decode_lossy(self.data[self.pos:self.pos + len])
  self.pos += len + 1
  s
}

///|
fn decode_in(rd : Rd, s : Sig, base : Int) -> DVal {
  match s {
    SigByte => VByte(rd.u8v())
    SigBool => {
      rd.pad(4, base)
      VBool(rd.u32v() != 0)
    }
    SigI16 => {
      rd.pad(2, base)
      let lo = rd.u8v()
      let hi = rd.u8v()
      let v = lo | (hi << 8)
      VI16(if v >= 0x8000 { v - 0x10000 } else { v })
    }
    SigQ16 => {
      rd.pad(2, base)
      let lo = rd.u8v()
      let hi = rd.u8v()
      VQ16(lo | (hi << 8))
    }
    SigI32 => {
      rd.pad(4, base)
      VI32(rd.u32v())
    }
    SigU32 => {
      rd.pad(4, base)
      VU32(rd.u32v())
    }
    SigI64 => {
      rd.pad(8, base)
      VI64(rd.i64v())
    }
    SigString => {
      rd.pad(4, base)
      VString(rd.read_string())
    }
    SigPath => {
      rd.pad(4, base)
      VPath(rd.read_string())
    }
    SigSig => VSig(rd.read_sig())
    SigArray(elem) => {
      rd.pad(4, base)
      let len = rd.u32v()
      // 长度不含首元素前的对齐填充
      rd.pad(sig_align(elem), base)
      let end = rd.pos + len
      let items : Array[DVal] = []
      while rd.pos < end {
        items.push(decode_in(rd, elem, base))
      }
      rd.pos = end
      VArray(sig_char(elem), items)
    }
    SigStruct(fields) => {
      rd.pad(8, base)
      let vals : Array[DVal] = []
      for f in fields {
        vals.push(decode_in(rd, f, base))
      }
      VStruct(vals)
    }
    SigDict(k, v) => {
      rd.pad(8, base)
      let a = decode_in(rd, k, base)
      let b = decode_in(rd, v, base)
      VStruct([a, b])
    }
    SigVariant => {
      let inner_sig = rd.read_sig()
      match parse_signature(inner_sig) {
        Ok([node]) => VVariant(decode_in(rd, node, base))
        Ok(_) => VVariant(VString(""))
        Err(_) => VVariant(VString(""))
      }
    }
  }
}

///|
fn sig_char(s : Sig) -> String {
  match s {
    SigByte => "y"
    SigBool => "b"
    SigI16 => "n"
    SigQ16 => "q"
    SigI32 => "i"
    SigU32 => "u"
    SigI64 => "x"
    SigString => "s"
    SigPath => "o"
    SigSig => "g"
    SigVariant => "v"
    SigArray(elem) => "a" + sig_char(elem)
    SigDict(k, v) => "{" + sig_char(k) + sig_char(v) + "}"
    SigStruct(fields) => {
      let sb = StringBuilder()
      sb.write_string("(")
      for f in fields {
        sb.write_string(sig_char(f))
      }
      sb.write_string(")")
      sb.to_string()
    }
  }
}

///|
fn rd_u32_at(data : BytesView, pos : Int) -> Int {
  data[pos].to_int() |
  (data[pos + 1].to_int() << 8) |
  (data[pos + 2].to_int() << 16) |
  (data[pos + 3].to_int() << 24)
}

///|
/// 解析一条完整消息；数据不完整或畸形返回 None。
fn parse_message(data : BytesView) -> Msg? {
  if data.length() < 16 || data[0].to_int() != 108 {
    return None
  }
  let kind = data[1].to_int()
  let body_len = rd_u32_at(data, 4)
  let serial = rd_u32_at(data, 8)
  let fields_len = rd_u32_at(data, 12)
  let body_start = (16 + fields_len + 7) / 8 * 8
  if data.length() < body_start + body_len {
    return None
  }
  let msg = Msg::fresh(kind, serial)
  // 头部字段数组：数据从 16 开始，结构体对齐 8 相对数组数据起点
  let mut p = 16
  while p - 16 < fields_len {
    while (p - 16) % 8 != 0 {
      p += 1
    }
    let tag = data[p].to_int()
    p += 1
    // variant：签名 g + 值
    let sig_len = data[p].to_int()
    p += 1
    let fs = @utf8.decode_lossy(data[p:p + sig_len])
    p += sig_len + 1
    match (tag, fs) {
      (1, "o") | (2, "s") | (3, "s") | (4, "s") | (6, "s") | (7, "s") => {
        while (p - 16) % 4 != 0 {
          p += 1
        }
        let len = rd_u32_at(data, p)
        p += 4
        let s = @utf8.decode_lossy(data[p:p + len])
        p += len + 1
        match tag {
          1 => msg.path = s
          2 => msg.iface = s
          3 => msg.action = s
          4 => msg.error_name = s
          6 => () // DESTINATION：发给我们的消息不需要
          _ => msg.sender = s
        }
      }
      (5, "u") => {
        while (p - 16) % 4 != 0 {
          p += 1
        }
        msg.reply_serial = rd_u32_at(data, p)
        p += 4
      }
      (8, "g") => {
        while (p - 16) % 1 != 0 {
          p += 1
        }
        let len = data[p].to_int()
        p += 1
        msg.sig = @utf8.decode_lossy(data[p:p + len])
        p += len + 1
      }
      _ => return None // 未知字段
    }
  }
  // 体：对齐相对消息起点（base 0），解析位置从 body_start 起
  if msg.sig != "" {
    let rd : Rd = { data, pos: body_start, }
    match parse_signature(msg.sig) {
      Ok(nodes) =>
        for node in nodes {
          msg.body.push(decode_in(rd, node, 0))
        }
      Err(_) => return None
    }
  }
  Some(msg)
}
