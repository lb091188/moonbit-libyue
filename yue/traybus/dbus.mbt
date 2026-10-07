// 通用 D-Bus 调用层:面向任意服务的方法调用与属性读写,是媒体控制/
// 磁盘/电源/蓝牙/传感器/时区等模块的公共地基。值模型 GDBusValue 覆盖
// a{sv}(MPRIS Metadata、udisks 属性)与数组/结构体签名构造;编解码复用
// wire.mbt 的线协议,连接复用 bus.mbt 的会话/系统连接。

///|
/// 通用 D-Bus 值(variant 载荷)。GVArray 首参是元素类型签名字符串
/// ("s"/"v"/"{sv}"/"(ii)" 等完整类型);GVDict 对应 a{sv},值已拆掉
/// variant 包裹,Map 按插入序序列化;GVVariant 保持包裹;GVNone 表示
/// "无返回值",不能作为调用参数。
pub(all) enum GDBusValue {
  GVNone
  GVBool(Bool)
  GVInt32(Int)
  GVUInt32(Int)
  GVInt64(Int64)
  GVU64(Int64) // 't':udisks Size/Time 等无符号 64 位
  GVDouble(Double)
  GVString(String)
  GVPath(String) // 对象路径 'o'
  GVArray(String, Array[GDBusValue])
  GVDict(Map[String, GDBusValue])
  GVVariant(GDBusValue)
  GVStruct(Array[GDBusValue])
}

///|
/// 调用失败:name 为 D-Bus 错误名(如 org.freedesktop.DBus.Error
/// .UnknownMethod)或本地错误前缀 gdbus.io(连不上/已断开)、gdbus
/// .timeout(应答超时)、gdbus.encode(参数无法编码);message 为可读说明。
pub struct GDBusError {
  name : String
  message : String
}

///|
fn gdbus_err(name : String, message : String) -> GDBusError {
  { name, message, }
}

///|
/// 值的类型签名(GVVariant 一律 "v";GVNone 无签名,作参数会被拒)。
fn gdbus_sig_of(v : GDBusValue) -> String {
  match v {
    GVNone => ""
    GVBool(_) => "b"
    GVInt32(_) => "i"
    GVUInt32(_) => "u"
    GVInt64(_) => "x"
    GVU64(_) => "t"
    GVDouble(_) => "d"
    GVString(_) => "s"
    GVPath(_) => "o"
    GVArray(elem, _) => "a" + elem
    GVDict(_) => "a{sv}"
    GVVariant(_) => "v"
    GVStruct(fields) => {
      let sb = StringBuilder()
      sb.write_string("(")
      for f in fields {
        sb.write_string(gdbus_sig_of(f))
      }
      sb.write_string(")")
      sb.to_string()
    }
  }
}

///|
fn gdbus_to_wire(v : GDBusValue) -> DVal {
  match v {
    GVNone => VString("") // 不可达:入口 gdbus_args_wire 已拒
    GVBool(b) => VBool(b)
    GVInt32(n) => VI32(n)
    GVUInt32(n) => VU32(n)
    GVInt64(n) => VI64(n)
    GVU64(n) => VU64(n)
    GVDouble(x) => VDouble(x)
    GVString(s) => VString(s)
    GVPath(s) => VPath(s)
    GVArray(elem, items) => {
      let out : Array[DVal] = []
      for it in items {
        out.push(gdbus_to_wire(it))
      }
      VArray(elem, out)
    }
    GVDict(entries) => {
      let out : Array[DVal] = []
      for k, val in entries {
        out.push(VStruct([VString(k), VVariant(gdbus_to_wire(val))]))
      }
      VArray("{sv}", out)
    }
    GVVariant(inner) => VVariant(gdbus_to_wire(inner))
    GVStruct(fields) => {
      let out : Array[DVal] = []
      for f in fields {
        out.push(gdbus_to_wire(f))
      }
      VStruct(out)
    }
  }
}

///|
/// 参数树里不允许 GVNone(其类型签名无从推导)。
fn gdbus_args_ok(args : Array[GDBusValue]) -> Bool {
  for a in args {
    let ok = match a {
      GVNone => false
      GVArray(_, items) => gdbus_args_ok(items)
      GVDict(entries) => {
        let mut all = true
        for _, val in entries {
          if !gdbus_args_ok([val]) {
            all = false
          }
        }
        all
      }
      GVVariant(inner) => gdbus_args_ok([inner])
      GVStruct(fields) => gdbus_args_ok(fields)
      _ => true
    }
    if !ok {
      return false
    }
  }
  true
}

///|
/// 参数 → (消息签名, 线协议值序列)。含 GVNone 或签名非法时报错。
fn gdbus_args_wire(
  args : Array[GDBusValue],
) -> Result[(String, Array[DVal]), String] {
  if !gdbus_args_ok(args) {
    return Err("GVNone 不能作为调用参数")
  }
  let sb = StringBuilder()
  for a in args {
    sb.write_string(gdbus_sig_of(a))
  }
  let sig = sb.to_string()
  // 预检签名:坏元素签名在此报错,不带超时代价(空参 = 空体,合法)
  if sig != "" {
    match parse_signature(sig) {
      Err(e) => return Err(e)
      Ok(nodes) =>
        if nodes.length() != args.length() {
          return Err("签名与参数个数不符: \{sig}")
        }
    }
  }
  let dvals : Array[DVal] = []
  for a in args {
    dvals.push(gdbus_to_wire(a))
  }
  Ok((sig, dvals))
}

///|
/// 线协议值 → GDBusValue:{sv} 数组折成 GVDict(variant 拆包),其余直映
/// (Byte/16 位整数并入 GVInt32,签名 'g' 并入 GVString——应答值是终端
/// 数据,类别细分无后续编码影响)。
fn gdbus_from_wire(v : DVal) -> GDBusValue {
  match v {
    VByte(n) => GVInt32(n)
    VBool(b) => GVBool(b)
    VI16(n) => GVInt32(n)
    VQ16(n) => GVInt32(n)
    VI32(n) => GVInt32(n)
    VU32(n) => GVUInt32(n)
    VI64(n) => GVInt64(n)
    VU64(n) => GVU64(n)
    VDouble(x) => GVDouble(x)
    VString(s) => GVString(s)
    VPath(s) => GVPath(s)
    VSig(s) => GVString(s)
    VArray("{sv}", items) => {
      let m : Map[String, GDBusValue] = Map([])
      for it in items {
        match it {
          VStruct([VString(k), VVariant(dv)]) => m.set(k, gdbus_from_wire(dv))
          _ => ()
        }
      }
      GVDict(m)
    }
    VArray(elem, items) => {
      let out : Array[GDBusValue] = []
      for it in items {
        out.push(gdbus_from_wire(it))
      }
      GVArray(elem, out)
    }
    VStruct(fields) => {
      let out : Array[GDBusValue] = []
      for f in fields {
        out.push(gdbus_from_wire(f))
      }
      GVStruct(out)
    }
    VVariant(inner) => GVVariant(gdbus_from_wire(inner))
  }
}

///|
/// 应答消息 → 值:错误应答给错误名+错误文本,空体给 GVNone,单值直取,
/// 多返回值折成 GVStruct。
fn gdbus_reply_value(m : Msg) -> Result[GDBusValue, GDBusError] {
  if m.kind == 3 {
    let text = match m.body.get(0) {
      Some(VString(t)) => t
      _ => ""
    }
    return Err(gdbus_err(m.error_name, text))
  }
  match m.body.length() {
    0 => Ok(GVNone)
    1 => Ok(gdbus_from_wire(m.body[0]))
    _ => {
      let out : Array[GDBusValue] = []
      for v in m.body {
        out.push(gdbus_from_wire(v))
      }
      Ok(GVStruct(out))
    }
  }
}

///|
/// 同步方法调用(等待应答至多 timeout_ms 毫秒)。
fn gdbus_call_timeout(
  c : Conn,
  dest : String,
  path : String,
  iface : String,
  action : String,
  args : Array[GDBusValue],
  timeout_ms : Int,
) -> Result[GDBusValue, GDBusError] {
  let sig = match gdbus_args_wire(args) {
    Ok(sig) => sig
    Err(m) => return Err(gdbus_err("gdbus.encode", m))
  }
  let done = Ref(false)
  let resp : Ref[Msg?] = Ref(None)
  let s = c.call(dest, path, iface, action, sig.0, sig.1, fn(m) {
    resp.val = Some(m)
    done.val = true
  })
  let _ = c.pump_until(done, timeout_ms)
  if resp.val is None {
    let _ = c.pending.remove(s)
  }
  match resp.val {
    Some(m) => gdbus_reply_value(m)
    None =>
      Err(gdbus_err("gdbus.timeout", "总线应答超时: \{iface}.\{action}"))
  }
}

///|
/// 同步方法调用(1.5 秒超时,与 bus.mbt 既有约定一致)。
fn gdbus_call(
  c : Conn,
  dest : String,
  path : String,
  iface : String,
  action : String,
  args : Array[GDBusValue],
) -> Result[GDBusValue, GDBusError] {
  gdbus_call_timeout(c, dest, path, iface, action, args, 1500)
}

///|
/// 会话总线连接(bus.mbt 的进程级连接,没有则现连)。
fn gdbus_conn_session() -> Result[Conn, String] {
  bus_conn()
}

///|
/// 系统总线连接(bus.mbt 的进程级连接,没有则现连)。
fn gdbus_conn_system() -> Result[Conn, String] {
  system_conn()
}

///|
/// 会话总线上的同步方法调用。
pub fn gdbus_call_session(
  dest : String,
  path : String,
  iface : String,
  action : String,
  args : Array[GDBusValue],
) -> Result[GDBusValue, GDBusError] {
  match gdbus_conn_session() {
    Ok(c) => gdbus_call(c, dest, path, iface, action, args)
    Err(e) => Err(gdbus_err("gdbus.io", e))
  }
}

///|
/// 系统总线上的同步方法调用。
pub fn gdbus_call_system(
  dest : String,
  path : String,
  iface : String,
  action : String,
  args : Array[GDBusValue],
) -> Result[GDBusValue, GDBusError] {
  match gdbus_conn_system() {
    Ok(c) => gdbus_call(c, dest, path, iface, action, args)
    Err(e) => Err(gdbus_err("gdbus.io", e))
  }
}

///|
/// 读属性(org.freedesktop.DBus.Properties.Get):返回值已拆掉 variant
/// 包裹,直接是属性值;属性不存在等给 D-Bus 错误名。
fn gdbus_get_property(
  c : Conn,
  dest : String,
  path : String,
  iface : String,
  prop : String,
) -> Result[GDBusValue, GDBusError] {
  match
    gdbus_call(c, dest, path, "org.freedesktop.DBus.Properties", "Get", [
      GVString(iface),
      GVString(prop),
    ]) {
    Ok(GVVariant(inner)) => Ok(inner)
    Ok(v) => Ok(v)
    Err(e) => Err(e)
  }
}

///|
/// 会话总线上读属性。
pub fn gdbus_get_property_session(
  dest : String,
  path : String,
  iface : String,
  prop : String,
) -> Result[GDBusValue, GDBusError] {
  match gdbus_conn_session() {
    Ok(c) => gdbus_get_property(c, dest, path, iface, prop)
    Err(e) => Err(gdbus_err("gdbus.io", e))
  }
}

///|
/// 系统总线上读属性。
pub fn gdbus_get_property_system(
  dest : String,
  path : String,
  iface : String,
  prop : String,
) -> Result[GDBusValue, GDBusError] {
  match gdbus_conn_system() {
    Ok(c) => gdbus_get_property(c, dest, path, iface, prop)
    Err(e) => Err(gdbus_err("gdbus.io", e))
  }
}

///|
/// 写属性(org.freedesktop.DBus.Properties.Set):value 传裸值,variant
/// 包裹在本层完成;成功无返回值。
fn gdbus_set_property(
  c : Conn,
  dest : String,
  path : String,
  iface : String,
  prop : String,
  value : GDBusValue,
) -> Result[Unit, GDBusError] {
  match
    gdbus_call(c, dest, path, "org.freedesktop.DBus.Properties", "Set", [
      GVString(iface),
      GVString(prop),
      GVVariant(value),
    ]) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// 会话总线上写属性。
pub fn gdbus_set_property_session(
  dest : String,
  path : String,
  iface : String,
  prop : String,
  value : GDBusValue,
) -> Result[Unit, GDBusError] {
  match gdbus_conn_session() {
    Ok(c) => gdbus_set_property(c, dest, path, iface, prop, value)
    Err(e) => Err(gdbus_err("gdbus.io", e))
  }
}

///|
/// 系统总线上写属性。
pub fn gdbus_set_property_system(
  dest : String,
  path : String,
  iface : String,
  prop : String,
  value : GDBusValue,
) -> Result[Unit, GDBusError] {
  match gdbus_conn_system() {
    Ok(c) => gdbus_set_property(c, dest, path, iface, prop, value)
    Err(e) => Err(gdbus_err("gdbus.io", e))
  }
}
