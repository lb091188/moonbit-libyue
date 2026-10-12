// 会话/系统总线连接：地址解析、SASL EXTERNAL 握手、Hello、消息收发与
// 分发。每条总线一条连接（会话 + 系统可并存），全部运行在主线程。
//
// 与旧链的一条结构性差：**不挂 glib fd 监视**。入站数据由宿主周期调
// [dbus_pump] 取走（默认非阻塞，看一眼就走），断线自愈的延迟重连走
// [dbus_set_post_delayed] 注入的通道。两者都不注入时同步调用
// （[gdbus_call_session] 等）仍可用——它们自带泵（[Conn::pump_until]）。
// 这样本包既不依赖 glib，也不依赖 GUI 层。

///|
priv struct Conn {
  fd : Int
  bus : Int // 0 = 会话总线 1 = 系统总线（断线自愈按此重连）
  mut serial : Int
  mut name : String // 本端唯一名 :1.x
  mut alive : Bool
  mut acc : FixedArray[Byte] // 收包累积缓冲
  mut acc_len : Int
  pending : Map[Int, (Msg) -> Unit] // 串号 → 应答处理
  subs : Map[String, Array[(Msg) -> Unit]] // "接口.成员" → 信号回调
  match_rules : Array[String] // AddMatch 规则（断线重连后重放）
  items : Map[String, Item] // 对象路径 → 托盘项
  menus : Map[String, Item] // 菜单对象路径 → 托盘项（DBusMenu）
}

///|
let g_conn : Ref[Conn?] = Ref(None)

///|
let g_sys_conn : Ref[Conn?] = Ref(None)

///|
/// fd → 连接注册表（[dbus_pump] 按 fd 路由到所属连接）。
let g_conns : Ref[Map[Int, Conn]] = Ref((Map([]) : Map[Int, Conn]))

///|
/// 断线时暂存的旧连接（重连成功后迁移订阅与 match 规则）。
let g_saved : Map[Int, Conn] = (Map([]) : Map[Int, Conn])

///|
/// 宿主注入的延迟任务通道（断线自愈的重连要避开当前调用现场）。
let g_post : Ref[((Int, () -> Unit) -> Unit)?] = Ref(None)

///|
/// 入站方法调用的分发口（同包的能力模块注册；未注册时兜底回错误）。
let g_on_call : Ref[((Conn, Msg) -> Unit)?] = Ref(None)

///|
/// 注入延迟任务通道：GUI 层给 `fn(ms, f) { let _ = app.timer(ms, f) }`。
/// 不注入时断线后不做后台重连，下一次显式调用会按需重建连接。
pub fn dbus_set_post_delayed(f : (Int, () -> Unit) -> Unit) -> Unit {
  g_post.val = Some(f)
}

///|
fn post_delayed(ms : Int, task : () -> Unit) -> Unit {
  match g_post.val {
    Some(f) => f(ms, task)
    None => ()
  }
}

///|
/// 入站方法调用的对外形态：只给已解码数据，回应走 reply / reply_error
/// （线协议值类型不外泄，能力模块与外部调用方看到的是同一份）。
pub(all) struct CallReq {
  /// 0 = 会话总线 1 = 系统总线
  bus : Int
  /// 调用方名字（回信地址）
  sender : String
  /// 被调对象路径
  path : String
  /// 接口名
  iface : String
  /// 方法名
  action : String
  /// 已解码的入参
  args : Array[GDBusValue]
  /// 正常应答（签名由参数值推导）
  reply : (Array[GDBusValue]) -> Unit
  /// 错误应答
  reply_error : (String, String) -> Unit
}

///|
/// 登记入站方法调用的处理者（托盘、单实例唤醒等能力模块用）。
pub fn dbus_set_call_handler(f : (CallReq) -> Unit) -> Unit {
  g_on_call.val = Some(fn(c : Conn, m : Msg) -> Unit {
    let args : Array[GDBusValue] = []
    for v in m.body {
      args.push(gdbus_from_wire(v))
    }
    f({
      bus: c.bus,
      sender: m.sender,
      path: m.path,
      iface: m.iface,
      action: m.action,
      args,
      reply: fn(vals : Array[GDBusValue]) -> Unit {
        match gdbus_args_wire(vals) {
          Ok(pair) => c.reply(m, pair.0, pair.1)
          Err(e) =>
            c.reply_error(
              m,
              "org.freedesktop.DBus.Error.Failed",
              "应答参数无法编码: \{e}",
            )
        }
      },
      reply_error: fn(name : String, text : String) -> Unit {
        c.reply_error(m, name, text)
      },
    })
  })
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
/// 解析系统总线地址：显式设置了但不是受支持的 unix:path 形态时给显式
/// 错误（不静默回退，便于诊断）；未设置用发行版通行默认路径。
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
/// 会话总线是否已连着（不主动建连）。
pub fn dbus_session_alive() -> Bool {
  match g_conn.val {
    Some(c) => c.alive
    None => false
  }
}

///|
/// 系统总线是否已连着（不主动建连）。
pub fn dbus_system_alive() -> Bool {
  match g_sys_conn.val {
    Some(c) => c.alive
    None => false
  }
}

///|
/// 本端唯一名（诊断用；未连接为空串）。
pub fn dbus_unique_name() -> String {
  match g_conn.val {
    Some(c) => c.name
    None => ""
  }
}

///|
/// 确保会话总线已连接（握手 + Hello）；给外部只需布尔/单元结果的调用方。
pub fn dbus_ensure_session() -> Result[Unit, String] {
  match bus_conn() {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// 取走入站数据：对每条活连接 poll 一次，可读就排空并分发。
/// `timeout_ms` 缺省 0（非阻塞，看一眼就走），适合挂在宿主的每帧或每拍
/// 定时器上；给正数时会阻塞到多这么久，只应在没有别的泵可依赖时用。
pub fn dbus_pump(timeout_ms? : Int = 0) -> Unit {
  let fds : Array[Int] = []
  for fd, _ in g_conns.val {
    fds.push(fd)
  }
  for fd in fds {
    match g_conns.val.get(fd) {
      Some(c) => {
        let r = ffi_poll(c.fd, 1, timeout_ms)
        if r > 0 {
          if (r & 24) != 0 {
            // 错误 / 挂断：总线断开
            c.mark_dead()
          } else {
            c.drain()
            if !c.alive {
              // drain 内判死（EOF 等）：统一走自愈入口
              c.mark_dead()
            }
          }
        }
      }
      None => ()
    }
  }
}

///|
/// 标记连接死亡。已入注册表的连接顺带关 fd、暂存状态并调度自愈（幂等）；
/// 握手阶段（未入注册表）只置死——fd 清理是 [connect_unix] 错误分支的职责。
fn Conn::mark_dead(self : Conn) -> Unit {
  self.alive = false
  if g_conns.val.contains(self.fd) {
    let _ = g_conns.val.remove(self.fd)
    ffi_close(self.fd)
    g_saved.set(self.bus, self)
    schedule_reconnect(self.bus)
  }
}

///|
/// 延迟重连：避开当前调用现场，投回宿主通道执行。
fn schedule_reconnect(bus : Int) -> Unit {
  if bus == 0 {
    g_conn.val = None
  }
  if bus == 1 {
    g_sys_conn.val = None
  }
  post_delayed(500, fn() { try_reconnect(bus, 1) })
}

///|
/// 自愈重连（最多 3 次）。先看按需路径是否已把总线重建：有活连接就直接
/// 沿用，不再新建——否则新连接覆盖 g_conn/g_sys_conn，按需重建的那条连同
/// fd 一起泄漏（注册表按 fd 路由，没有引用能再关掉它），订阅也会分裂在
/// 两条连接上。状态迁移在连接建立时经 [Conn::adopt_saved] 完成。
fn try_reconnect(bus : Int, attempt : Int) -> Unit {
  if attempt > 3 {
    return
  }
  let existing = match bus {
    0 => g_conn.val
    _ => g_sys_conn.val
  }
  match existing {
    Some(c) if c.alive => c.adopt_saved(bus)
    _ =>
      match bus {
        0 =>
          match connect_session() {
            Ok(_) => ()
            // 没注入排期通道时就到此为止（纯 CLI 场景由下一次显式调用重建）
            Err(_) => post_delayed(1000, fn() {
              try_reconnect(bus, attempt + 1)
            })
          }
        _ =>
          match connect_system() {
            Ok(_) => ()
            Err(_) => post_delayed(1000, fn() {
              try_reconnect(bus, attempt + 1)
            })
          }
      }
  }
}

///|
/// 迁移断线旧连接的订阅与 match 规则到本连接（任一新建连接建立时调用，
/// 自愈重连与按需重建同路）。
fn Conn::adopt_saved(self : Conn, bus : Int) -> Unit {
  match g_saved.get(bus) {
    Some(old) => {
      for k, arr in old.subs {
        self.subs.set(k, arr)
      }
      for rule in old.match_rules {
        self.add_match(rule)
      }
      if bus == 0 {
        // 托盘项迁移；重新注册投回宿主通道（register_item_path 内部要
        // call_sync 泵总线，在回调现场同步泵会让入站调用重入派发）
        let paths : Array[String] = []
        for k, it in old.items {
          if !self.items.contains(k) {
            self.items.set(k, it)
            paths.push(k)
          }
        }
        for k, it in old.menus {
          if !self.menus.contains(k) {
            self.menus.set(k, it)
          }
        }
        if paths.length() > 0 {
          post_delayed(0, fn() {
            for p in paths {
              if self.items.contains(p) {
                let _ = self.register_item_path(p)
              }
            }
          })
        }
      }
      let _ = g_saved.remove(bus)
    }
    None => ()
  }
}

///|
/// 从当前连接与断线暂存的旧连接里一并摘除托盘项（注销用）：连接已断时
/// 当前表里没有，但暂存连接还持着本项，只清一边会让它重连后复活。
fn sni_drop_item(path : String, menu_path : String) -> Unit {
  match g_conn.val {
    Some(c) => {
      let _ = c.items.remove(path)
      let _ = c.menus.remove(menu_path)
    }
    None => ()
  }
  match g_saved.get(0) {
    Some(c) => {
      let _ = c.items.remove(path)
      let _ = c.menus.remove(menu_path)
    }
    None => ()
  }
}

///|
/// SNI 后端是否可用：能连上会话总线即视为候选；watcher 是否存在由
/// Item::create 时的 NameHasOwner 确认。
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
/// 会话总线连接（没有则现连）。
fn bus_conn() -> Result[Conn, String] {
  match g_conn.val {
    Some(c) => if c.alive { Ok(c) } else { Err("会话总线连接已断开") }
    None =>
      match connect_session() {
        Ok(c) => {
          g_conn.val = Some(c)
          Ok(c)
        }
        Err(e) => Err(e)
      }
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
  match connect_unix(path, 0) {
    Ok(c) => {
      g_conn.val = Some(c)
      // 任一新建连接都立即接管断线前的旧连接状态：按需重建与自愈重连
      // 同走这一条迁移路径，旧订阅不丢，也不会因两条连接并存泄漏 fd
      c.adopt_saved(0)
      Ok(c)
    }
    Err(e) => Err(e)
  }
}

///|
fn connect_system() -> Result[Conn, String] {
  let path = match system_bus_path() {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  match connect_unix(path, 1) {
    Ok(c) => {
      g_sys_conn.val = Some(c)
      c.adopt_saved(1)
      Ok(c)
    }
    Err(e) => Err(e)
  }
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
/// 连接一条总线（SASL EXTERNAL 握手 + Hello + 入 fd 注册表）。
fn connect_unix(path : String, bus : Int) -> Result[Conn, String] {
  let fd = ffi_unix_connect(utf8(path))
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
    pending: (Map([]) : Map[Int, (Msg) -> Unit]),
    subs: (Map([]) : Map[String, Array[(Msg) -> Unit]]),
    match_rules: [],
    items: (Map([]) : Map[String, Item]),
    menus: (Map([]) : Map[String, Item]),
  }
  // SASL EXTERNAL：凭据是十六进制编码的 uid 字符串
  let uid = ffi_getuid()
  if uid < 0 {
    ffi_close(fd)
    return Err("当前平台取不到 uid（仅支持 Linux）")
  }
  let cred = hex_string(utf8("\{uid}"))
  if !c.send_all(utf8("\u{0}AUTH EXTERNAL \{cred}\r\nBEGIN\r\n")) {
    ffi_close(fd)
    return Err("SASL 认证发送失败")
  }
  match c.read_sasl_line() {
    Some(line) =>
      if !line.has_prefix("OK") {
        ffi_close(fd)
        return Err("SASL 认证被拒绝: \{line}")
      }
    None => {
      ffi_close(fd)
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
      ffi_close(fd)
      return Err("Hello 失败: \{e}")
    }
  }
  // 入注册表即代表「可被 [dbus_pump] 取到」；握手期用的同步泵不依赖它
  g_conns.val.set(fd, c)
  Ok(c)
}

///|
fn Conn::send_all(self : Conn, data : Bytes) -> Bool {
  let mut off = 0
  let len = data.length()
  while off < len {
    let n = ffi_write(self.fd, data, off, len - off)
    if n > 0 {
      off += n
    } else if n == -1 {
      if ffi_poll(self.fd, 4, 1000) <= 0 {
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
    let r = ffi_poll(self.fd, 1, 1000)
    if r <= 0 {
      return None
    }
    let n = ffi_read(self.fd, buf, got.val, 256 - got.val)
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
/// 添加 match 规则（AddMatch 是方法调用）。规则登记在案，断线自愈重连后重放。
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
/// （sender/argN 过滤由回调自查）。同一 key 可多次订阅。
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
/// 同步泵：在 fd 上等待并处理消息，直到条件满足或超时。用于连接握手、
/// 注册等「必须拿到结果才能继续」的时点；主循环起来之后由 [dbus_pump] 驱动。
fn Conn::pump_until(self : Conn, done : Ref[Bool], timeout_ms : Int) -> Bool {
  let mut left = timeout_ms
  while !done.val && left > 0 && self.alive {
    let slice = if left < 15 { left } else { 15 }
    let r = ffi_poll(self.fd, 1, slice)
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
    let n = ffi_read(self.fd, buf, 0, 8192)
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
    // watcher 重启后按唯一名清掉旧注册，这里按新主人重注册全部托盘项
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
    // 信号：总线主动断开先判死
    if msg.action == "Disconnected" {
      self.mark_dead()
      return
    }
    // 订阅注册表：按 "接口.成员" 查回调
    if msg.iface != "" && msg.action != "" {
      match self.subs.get("\{msg.iface}.\{msg.action}") {
        Some(arr) =>
          for cb in arr {
            cb(msg)
          }
        None => ()
      }
    }
    return
  }
  if msg.kind == 1 {
    // 入站调用三路：单实例 Wake（先应答后触发——第二实例的 call_sync 有时限，
    // 回调里恢复窗口可能耗时）→ 托盘 SNI 的项与菜单调用 → 调用方登记的处理者；
    // 都没接住时回 UnknownMethod，不能让对端干等
    if is_wake_call(msg) {
      self.reply(msg, "", [])
      fire_wake(msg)
    } else if self.items.contains(msg.path) || self.menus.contains(msg.path) {
      self.handle_call(msg)
    } else {
      match g_on_call.val {
        Some(f) => f(self, msg)
        None =>
          self.reply_error(
            msg,
            "org.freedesktop.DBus.Error.UnknownMethod",
            "本进程未注册入站调用处理者",
          )
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 对外门面：信号订阅与信号发送（同步调用与属性读写在 dbus.mbt）
// ---------------------------------------------------------------------------

///|
/// 订阅总线信号：`rule` 是完整 match 规则串，`key` 是分发键
/// "接口.成员"（sender/argN 的进一步过滤由回调自查）；回调拿到已解码的
/// 载荷。同一 key 可多次订阅。规则登记在案，断线重连后自动重放。
fn dbus_subscribe_on(
  bus : Int,
  rule : String,
  key : String,
  cb : (Array[GDBusValue]) -> Unit,
) -> Result[Unit, String] {
  let c = match bus {
    0 => bus_conn()
    _ => system_conn()
  }
  match c {
    Err(e) => Err(e)
    Ok(conn) => {
      conn.subscribe(rule, key, fn(m : Msg) -> Unit {
        let out : Array[GDBusValue] = []
        for v in m.body {
          out.push(gdbus_from_wire(v))
        }
        cb(out)
      })
      Ok(())
    }
  }
}

///|
/// 订阅会话总线信号。
pub fn dbus_subscribe_session(
  rule : String,
  key : String,
  cb : (Array[GDBusValue]) -> Unit,
) -> Result[Unit, String] {
  dbus_subscribe_on(0, rule, key, cb)
}

///|
/// 订阅系统总线信号。
pub fn dbus_subscribe_system(
  rule : String,
  key : String,
  cb : (Array[GDBusValue]) -> Unit,
) -> Result[Unit, String] {
  dbus_subscribe_on(1, rule, key, cb)
}

///|
/// 在会话总线上发信号（不期待应答）。
pub fn dbus_emit_signal_session(
  path : String,
  iface : String,
  action : String,
  args : Array[GDBusValue],
) -> Result[Unit, String] {
  match bus_conn() {
    Err(e) => Err(e)
    Ok(c) =>
      match gdbus_args_wire(args) {
        Err(m) => Err(m)
        Ok(pair) => {
          c.emit_signal(path, iface, action, pair.0, pair.1)
          Ok(())
        }
      }
  }
}
