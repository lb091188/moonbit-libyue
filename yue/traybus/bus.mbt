// 会话总线连接：地址解析、SASL EXTERNAL 握手、Hello、消息收发与分发。
// 单进程一条连接（glib fd 监视经 shim 只支持一路），全部运行在主线程。

///|
priv struct Conn {
  fd : Int
  mut serial : Int
  mut name : String // 本端唯一名 :1.x
  mut alive : Bool
  mut acc : FixedArray[Byte] // 收包累积缓冲
  mut acc_len : Int
  items : Map[String, Item] // 对象路径 → 托盘项
  menus : Map[String, Item] // 菜单对象路径 → 托盘项（DBusMenu）
  pending : Map[Int, (Msg) -> Unit] // 串号 → 应答处理
  mut match_added : Bool
}

///|
let g_conn : Ref[Conn?] = Ref(None)

///|
/// SNI 后端是否可用：能连上会话总线即视为候选；
/// watcher 是否存在由 Item::create 时的 NameHasOwner 确认。
pub fn sni_available() -> Bool {
  match g_conn.val {
    Some(c) => c.alive
    None =>
      match connect_session() {
        Ok(c) => {
          g_conn.val = Some(c)
          true
        }
        Err(_) => false
      }
  }
}

///|
/// 解析会话总线地址：DBUS_SESSION_BUS_ADDRESS 优先，其次 XDG_RUNTIME_DIR/bus。
fn session_bus_path() -> String? {
  match env_get("DBUS_SESSION_BUS_ADDRESS") {
    Some(addr) => {
      // 形如 "unix:path=/run/user/1000/bus,guid=..."，取第一个 unix:path
      for part in addr.split(",") {
        let t = part.to_owned()
        if t.has_prefix("unix:path=") {
          return Some(t[10:].to_owned())
        }
      }
      None
    }
    None =>
      match env_get("XDG_RUNTIME_DIR") {
        Some(dir) => Some(dir + "/bus")
        None => None
      }
  }
}

///|
fn hex_char(v : Int) -> Char {
  if v < 10 {
    (48 + v).unsafe_to_char() // '0'
  } else {
    (87 + v).unsafe_to_char() // 'a'
  }
}

///|
fn hex_string(data : Bytes) -> String {
  let sb = StringBuilder()
  for i in 0..<data.length() {
    let b = data[i].to_int()
    sb.write_char(hex_char(b >> 4))
    sb.write_char(hex_char(b & 15))
  }
  sb.to_string()
}

///|
/// 本端唯一名（诊断用）。
pub fn conn_unique_name() -> String {
  match g_conn.val {
    Some(c) => c.name
    None => ""
  }
}

///|
/// glib 主循环 fd 回调：无捕获顶层函数（跨 ABI 约定）。
fn on_bus_ready(fd : Int, cond : Int) -> Int {
  ignore(fd)
  match g_conn.val {
    Some(c) => {
      if (cond & 24) != 0 {
        // G_IO_ERR | G_IO_HUP：总线断开
        c.alive = false
      } else {
        c.drain()
      }
      1 // 保持 source
    }
    None => 1
  }
}

///|
fn connect_session() -> Result[Conn, String] {
  let path = match session_bus_path() {
    Some(p) => p
    None =>
      return Err(
        "找不到会话总线地址（DBUS_SESSION_BUS_ADDRESS / XDG_RUNTIME_DIR 未设置）",
      )
  }
  let fd = sys_unix_connect(utf8(path))
  if fd < 0 {
    return Err("无法连接会话总线: \{path}")
  }
  let c : Conn = {
    fd,
    serial: 0,
    name: "",
    alive: true,
    acc: FixedArray::make(4096, b'\x00'),
    acc_len: 0,
    items: (Map([]) : Map[String, Item]),
    menus: (Map([]) : Map[String, Item]),
    pending: (Map([]) : Map[Int, (Msg) -> Unit]),
    match_added: false,
  }
  // SASL EXTERNAL：凭据是十六进制编码的 uid 字符串
  let uid = sys_getuid()
  if uid < 0 {
    sys_close(fd)
    return Err("SNI 后端仅支持 Linux")
  }
  let cred = hex_string(utf8("\{uid}"))
  if !c.send_all(utf8("\u{0}AUTH EXTERNAL \{cred}\r\nBEGIN\r\n")) {
    sys_close(fd)
    return Err("SASL 认证发送失败")
  }
  match c.read_sasl_line() {
    Some(line) =>
      if !line.has_prefix("OK") {
        sys_close(fd)
        return Err("SASL 认证被拒绝: \{line}")
      }
    None => {
      sys_close(fd)
      return Err("SASL 应答超时")
    }
  }
  match
    c.call_sync(
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus",
      "Hello",
      "",
      [],
    ) {
    Ok(m) =>
      match m.body.get(0) {
        Some(v) =>
          match dstr(v) {
            Some(n) => c.name = n
            None => ()
          }
        None => ()
      }
    Err(e) => {
      sys_close(fd)
      return Err("Hello 失败: \{e}")
    }
  }
  // 挂入 GTK 主循环：可读 + 错误 + 挂断
  let _ = sys_watch_fd(fd, 1 | 8 | 16, fn(fd, cond) { on_bus_ready(fd, cond) })
  Ok(c)
}

///|
fn Conn::send_all(self : Conn, data : Bytes) -> Bool {
  let mut off = 0
  let len = data.length()
  while off < len {
    let n = sys_write(self.fd, data, off, len - off)
    if n > 0 {
      off += n
    } else if n == -1 {
      if sys_poll(self.fd, 4, 1000) <= 0 {
        return false
      }
    } else {
      return false
    }
  }
  true
}

///|
/// 读一行 SASL 应答（以 \r\n 结尾）。
fn Conn::read_sasl_line(self : Conn) -> String? {
  let buf = Bytes::make(256, 0)
  let got = Ref(0)
  while got.val < 256 {
    let r = sys_poll(self.fd, 1, 1000)
    if r <= 0 {
      return None
    }
    let n = sys_read(self.fd, buf, got.val, 256 - got.val)
    if n > 0 {
      got.val += n
      let chunk = buf[0:got.val]
      let mut nl = -1
      for i in 0..<chunk.length() {
        if chunk[i].to_int() == 10 {
          nl = i
          break
        }
      }
      if nl >= 0 {
        let line = @utf8.decode_lossy(chunk[0:nl])
        let mut end = line.length()
        if end > 0 && line.unsafe_get(end - 1).to_int() == 13 {
          end -= 1
        }
        return Some(line[0:end].to_owned())
      }
    } else if n == 0 {
      return None
    }
  }
  None
}

///|
/// 取下一个发送串号。
fn Conn::next_serial(self : Conn) -> Int {
  self.serial += 1
  self.serial
}

///|
/// 发出方法调用并登记应答处理。
fn Conn::call(
  self : Conn,
  dest : String,
  path : String,
  iface : String,
  action : String,
  sig : String,
  args : Array[DVal],
  cb : (Msg) -> Unit,
) -> Unit {
  let s = self.next_serial()
  self.pending[s] = cb
  match build_call(s, dest, path, iface, action, sig, args) {
    Ok(b) =>
      if !self.send_all(b) {
        self.alive = false
        let _ = self.pending.remove(s)
      }
    Err(_) => {
      let _ = self.pending.remove(s)
    }
  }
}

///|
/// 同步调用：pump 总线直到应答或超时。
fn Conn::call_sync(
  self : Conn,
  dest : String,
  path : String,
  iface : String,
  action : String,
  sig : String,
  args : Array[DVal],
) -> Result[Msg, String] {
  let done = Ref(false)
  let resp : Ref[Msg?] = Ref(None)
  self.call(dest, path, iface, action, sig, args, fn(m) {
    resp.val = Some(m)
    done.val = true
  })
  let _ = self.pump_until(done, 1500)
  match resp.val {
    Some(m) => if m.kind == 3 { Err(m.error_name) } else { Ok(m) }
    None => Err("总线应答超时: \{iface}.\{action}")
  }
}

///|
/// 发送信号（不期待应答）。
fn Conn::emit_signal(
  self : Conn,
  path : String,
  iface : String,
  action : String,
  sig : String,
  args : Array[DVal],
) -> Unit {
  match build_signal(self.next_serial(), path, iface, action, sig, args) {
    Ok(b) => if !self.send_all(b) { self.alive = false }
    Err(_) => ()
  }
}

///|
/// 应答一条调用。
fn Conn::reply(
  self : Conn,
  req : Msg,
  sig : String,
  args : Array[DVal],
) -> Unit {
  match build_reply(self.next_serial(), req.serial, req.sender, sig, args) {
    Ok(b) => if !self.send_all(b) { self.alive = false }
    // 编码失败也要回错误，否则对端干等超时（面板会当作托盘无响应）
    Err(e) =>
      self.reply_error(
        req,
        "org.freedesktop.DBus.Error.Failed",
        "应答编码失败: \{e}",
      )
  }
}

///|
fn Conn::reply_error(
  self : Conn,
  req : Msg,
  name : String,
  text : String,
) -> Unit {
  match build_error(self.next_serial(), req.serial, req.sender, name, text) {
    Ok(b) => if !self.send_all(b) { self.alive = false }
    Err(_) => ()
  }
}

///|
/// 同步泵：在 fd 上等待并处理消息，直到条件满足或超时。
/// 用于连接握手、注册等"必须拿到结果才能继续"的时点；
/// 主循环起来之后由 glib fd 监视驱动。
fn Conn::pump_until(self : Conn, done : Ref[Bool], timeout_ms : Int) -> Bool {
  let mut left = timeout_ms
  while !done.val && left > 0 && self.alive {
    let slice = if left < 15 { left } else { 15 }
    let r = sys_poll(self.fd, 1, slice)
    left -= slice
    if r > 0 {
      if (r & 24) != 0 {
        self.alive = false
        return false
      }
      self.drain()
    }
  }
  done.val
}

///|
/// 读尽当前可读数据并分发完整消息。
fn Conn::drain(self : Conn) -> Unit {
  let buf = Bytes::make(8192, 0)
  while self.alive {
    let n = sys_read(self.fd, buf, 0, 8192)
    if n > 0 {
      self.append(buf[0:n])
      while self.alive {
        match self.pop_message() {
          Some(msg) => self.handle(msg)
          None => break
        }
      }
    } else if n == 0 {
      self.alive = false
      return
    } else if n == -1 {
      return // 暂无数据
    } else {
      self.alive = false
      return
    }
  }
}

///|
fn Conn::append(self : Conn, data : BytesView) -> Unit {
  if self.acc_len + data.length() > self.acc.length() {
    let mut cap = self.acc.length()
    while cap < self.acc_len + data.length() {
      cap = cap * 2
    }
    let nd : FixedArray[Byte] = FixedArray::make(cap, b'\x00')
    for i in 0..<self.acc_len {
      nd[i] = self.acc[i]
    }
    self.acc = nd
  }
  for i in 0..<data.length() {
    self.acc[self.acc_len + i] = data[i]
  }
  self.acc_len += data.length()
}

///|
/// 从累积缓冲取出一条完整消息（有则顺带压实缓冲）。
fn Conn::pop_message(self : Conn) -> Msg? {
  if self.acc_len < 16 {
    return None
  }
  let body_len = rd_u32_fixedarray(self.acc, 4)
  let fields_len = rd_u32_fixedarray(self.acc, 12)
  let body_start = (16 + fields_len + 7) / 8 * 8
  let total = body_start + body_len
  if self.acc_len < total {
    return None
  }
  let data = Bytes::makei(self.acc_len, fn(i) { self.acc[i] })
  let msg = parse_message(data[0:total])
  for i in 0..<(self.acc_len - total) {
    self.acc[i] = self.acc[total + i]
  }
  self.acc_len -= total
  msg
}

///|
fn rd_u32_fixedarray(data : FixedArray[Byte], pos : Int) -> Int {
  data[pos].to_int() |
  (data[pos + 1].to_int() << 8) |
  (data[pos + 2].to_int() << 16) |
  (data[pos + 3].to_int() << 24)
}

///|
/// 分发一条入站消息。
fn Conn::handle(self : Conn, msg : Msg) -> Unit {
  if msg.kind == 2 || msg.kind == 3 {
    // 应答
    match msg.reply_serial {
      0 => ()
      s =>
        match self.pending.get(s) {
          Some(cb) => {
            let _ = self.pending.remove(s)
            cb(msg)
          }
          None => ()
        }
    }
    return
  }
  if msg.kind == 4 {
    // 信号：watcher 重启后重注册
    if msg.action == "NameOwnerChanged" && msg.body.length() >= 3 {
      match dstr(msg.body[0]) {
        Some(watched) =>
          if watched == "org.kde.StatusNotifierWatcher" {
            match dstr(msg.body[2]) {
              Some(owner) =>
                if owner != "" {
                  let paths : Array[String] = []
                  for k, _ in self.items {
                    paths.push(k)
                  }
                  for p in paths {
                    let _ = self.register_item_path(p)
                  }
                }
              None => ()
            }
          }
        None => ()
      }
    }
    if msg.action == "Disconnected" {
      self.alive = false
    }
    return
  }
  if msg.kind == 1 {
    // 单实例对象的 Wake 调用先于 SNI 分发：今天入站调用一律进 handle_call，
    // Wake 会落进 UnknownMethod 兜底，首实例永远收不到二次唤起。
    // 先应答后触发——第二实例的 call_sync 有时限，回调里恢复/置前窗口
    // 可能耗时，不能让对端干等。
    if is_wake_call(msg) {
      self.reply(msg, "", [])
      fire_wake(msg)
    } else {
      self.handle_call(msg)
    }
  }
}
