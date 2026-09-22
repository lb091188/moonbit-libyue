// 会话/系统总线连接：地址解析、SASL EXTERNAL 握手、Hello、消息收发与
// 分发。每条总线一条连接（会话 + 系统可并存），fd 监视按 fd 路由，
// 全部运行在主线程。

///|
priv struct Conn {
  fd : Int
  bus : Int // 0 = 会话总线 1 = 系统总线（断线自愈按此重连）
  mut serial : Int
  mut name : String // 本端唯一名 :1.x
  mut alive : Bool
  mut acc : FixedArray[Byte] // 收包累积缓冲
  mut acc_len : Int
  items : Map[String, Item] // 对象路径 → 托盘项
  menus : Map[String, Item] // 菜单对象路径 → 托盘项（DBusMenu）
  pending : Map[Int, (Msg) -> Unit] // 串号 → 应答处理
  subs : Map[String, Array[(Msg) -> Unit]] // "接口.成员" → 信号回调
  match_rules : Array[String] // AddMatch 规则（断线重连后重放）
}

///|
let g_conn : Ref[Conn?] = Ref(None)

///|
let g_sys_conn : Ref[Conn?] = Ref(None)

///|
/// fd → 连接注册表（glib fd 监视按 fd 路由到所属连接）。
let g_conns : Ref[Map[Int, Conn]] = Ref((Map([]) : Map[Int, Conn]))

///|
/// 断线时暂存的旧连接（重连成功后迁移订阅与托盘项）。
let g_saved : Map[Int, Conn] = (Map([]) : Map[Int, Conn])

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
/// 解析系统总线地址：DBUS_SYSTEM_BUS_ADDRESS 显式设置了但不是受支持的
/// unix:path 形态时给显式错误（不静默回退，便于诊断）；未设置用发行版
/// 通行默认路径。
fn system_bus_path() -> Result[String, String] {
  match env_get("DBUS_SYSTEM_BUS_ADDRESS") {
    Some(addr) => {
      for part in addr.split(",") {
        let t = part.to_owned()
        if t.has_prefix("unix:path=") {
          return Ok(t[10:].to_owned())
        }
      }
      Err("DBUS_SYSTEM_BUS_ADDRESS 不是受支持的 unix:path 地址: \{addr}")
    }
    None => Ok("/run/dbus/system_bus_socket")
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
/// glib 主循环 fd 回调：无捕获顶层函数（跨 ABI 约定），按 fd 路由到
/// 所属连接（会话/系统可并存）。
fn on_bus_ready(fd : Int, cond : Int) -> Int {
  match g_conns.val.get(fd) {
    Some(c) =>
      if (cond & 24) != 0 {
        // G_IO_ERR | G_IO_HUP：总线断开
        c.mark_dead()
        0 // 撤 source
      } else {
        c.drain()
        if c.alive {
          1
        } else {
          // drain 内判死（EOF 等）：统一走自愈入口
          c.mark_dead()
          0
        }
      }
    None => 0
  }
}

///|
/// 标记连接死亡。已挂入主循环的连接顺带注销监视、关闭 fd、调度自愈
/// （幂等）；握手阶段（未入注册表）只置死——fd 清理是 connect_unix
/// 错误分支的职责。
fn Conn::mark_dead(self : Conn) -> Unit {
  self.alive = false
  if g_conns.val.contains(self.fd) {
    let _ = g_conns.val.remove(self.fd)
    sys_unwatch_fd(self.fd)
    sys_close(self.fd)
    g_saved.set(self.bus, self)
    schedule_reconnect(self.bus)
  }
}

///|
/// 延迟重连：避开 fd 回调现场，投回主循环执行。
fn schedule_reconnect(bus : Int) -> Unit {
  if bus == 0 {
    g_conn.val = None
  }
  if bus == 1 {
    g_sys_conn.val = None
  }
  sys_post_delayed(500, fn(f) { f() }, fn() { try_reconnect(bus, 1) })
}

///|
/// 自愈重连（最多 3 次）：成功后重放 AddMatch、迁移订阅与托盘项。
fn try_reconnect(bus : Int, attempt : Int) -> Unit {
  if attempt > 3 {
    return
  }
  let nc = match bus {
    0 =>
      match connect_session() {
        Ok(c) => {
          g_conn.val = Some(c)
          c
        }
        Err(_) =>
          // 换回环里再试；主循环未运行时（纯 CLI 场景）回调不触发，自然放弃
          {
            sys_post_delayed(
              1000,
              fn(f) { f() },
              fn() { try_reconnect(bus, attempt + 1) },
            )
            return
          }
      }
    _ =>
      match connect_system() {
        Ok(c) => {
          g_sys_conn.val = Some(c)
          c
        }
        Err(_) => {
          sys_post_delayed(
            1000,
            fn(f) { f() },
            fn() { try_reconnect(bus, attempt + 1) },
          )
          return
        }
      }
  }
  match g_saved.get(bus) {
    Some(old) => {
      // 订阅表与 match 规则迁移到新连接
      for k, arr in old.subs {
        nc.subs.set(k, arr)
      }
      for rule in old.match_rules {
        nc.add_match(rule)
      }
      if bus == 0 {
        // 托盘项迁移并重新注册（断线期间 watcher 已按名字消失清掉旧注册）
        for k, it in old.items {
          nc.items.set(k, it)
        }
        for k, it in old.menus {
          nc.menus.set(k, it)
        }
        for k, _ in nc.items {
          let _ = nc.register_item_path(k)
        }
      }
      let _ = g_saved.remove(bus)
    }
    None => ()
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
  connect_unix(path, 0)
}

///|
fn connect_system() -> Result[Conn, String] {
  let path = match system_bus_path() {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  connect_unix(path, 1)
}

///|
/// 系统总线连接（电源/会话/网络监视共用；连接断开时调用方收到错误，
/// 自愈在后台重连）。
fn system_conn() -> Result[Conn, String] {
  match g_sys_conn.val {
    Some(c) => if c.alive { Ok(c) } else { Err("系统总线连接已断开") }
    None =>
      match connect_system() {
        Ok(c) => {
          g_sys_conn.val = Some(c)
          Ok(c)
        }
        Err(e) => Err(e)
      }
  }
}

///|
/// 连接一条总线（SASL EXTERNAL 握手 + Hello + 挂入主循环）。
fn connect_unix(path : String, bus : Int) -> Result[Conn, String] {
  let fd = sys_unix_connect(utf8(path))
  if fd < 0 {
    return Err("无法连接总线 socket: \{path}")
  }
  let c : Conn = {
    fd,
    bus,
    serial: 0,
    name: "",
    alive: true,
    acc: FixedArray::make(4096, b'\x00'),
    acc_len: 0,
    items: (Map([]) : Map[String, Item]),
    menus: (Map([]) : Map[String, Item]),
    pending: (Map([]) : Map[Int, (Msg) -> Unit]),
    subs: (Map([]) : Map[String, Array[(Msg) -> Unit]]),
    match_rules: [],
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
  // 挂入 GTK 主循环：可读 + 错误 + 挂断；先入注册表再挂监视，
  // 避免回调先到时查不到连接
  g_conns.val.set(fd, c)
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
/// 发出方法调用并登记应答处理，返回串号（超时方据此摘除 pending）。
fn Conn::call(
  self : Conn,
  dest : String,
  path : String,
  iface : String,
  action : String,
  sig : String,
  args : Array[DVal],
  cb : (Msg) -> Unit,
) -> Int {
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
  s
}

///|
/// 同步调用：pump 总线直到应答或超时。超时也摘除 pending——应答迟到
/// 时串号已回收，不会误触发后续同串号调用的处理。
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
  let s = self.call(dest, path, iface, action, sig, args, fn(m) {
    resp.val = Some(m)
    done.val = true
  })
  let _ = self.pump_until(done, 1500)
  if resp.val is None {
    let _ = self.pending.remove(s)
  }
  match resp.val {
    Some(m) => if m.kind == 3 { Err(m.error_name) } else { Ok(m) }
    None => Err("总线应答超时: \{iface}.\{action}")
  }
}

///|
/// 添加 match 规则（AddMatch 是方法调用，此前误发成广播信号被总线忽略
/// 的教训见 sni.mbt）。规则登记在案，断线自愈重连后重放。
fn Conn::add_match(self : Conn, rule : String) -> Unit {
  if self.match_rules.contains(rule) {
    return
  }
  self.match_rules.push(rule)
  let _ = self.call(
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "AddMatch",
    "s",
    [VString(rule)],
    fn(_m) { () },
  )
}

///|
/// 订阅信号：rule 为完整 match 规则串，key 为分发键 "接口.成员"
/// （sender/argN 过滤由回调自查——UPower 的 PropertiesChanged 靠
/// arg0 区分，回调里比对更直观）。同一 key 可多次订阅。
fn Conn::subscribe(
  self : Conn,
  rule : String,
  key : String,
  cb : (Msg) -> Unit,
) -> Unit {
  self.add_match(rule)
  match self.subs.get(key) {
    Some(arr) => arr.push(cb)
    None => self.subs.set(key, [cb])
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
        self.mark_dead()
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
      self.mark_dead() // EOF：对端关闭
      return
    } else if n == -1 {
      return // 暂无数据
    } else {
      self.mark_dead()
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
    // 信号：watcher 重启后重注册（SNI 既有特判在前）
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
      self.mark_dead()
      return
    }
    // 订阅注册表分发在后：按 "接口.成员" 查回调
    if msg.iface != "" && msg.action != "" {
      match self.subs.get("\{msg.iface}.\{msg.action}") {
        Some(arr) => for cb in arr { cb(msg) }
        None => ()
      }
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
