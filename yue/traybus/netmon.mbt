// NetworkManager(系统总线):连接状态查询与变化信号。State(u) 与
// Connectivity(u) 都是顶层对象属性;变化信号两条——老式 StateChanged(u)
// 直带新值,新式 PropertiesChanged(a{sv})的 changed 里可能带任一属性,
// 两条都订,回调更新缓存后归并通知(订阅方拿到的永远是最新双值,不重查)。

///|
const NM : String = "org.freedesktop.NetworkManager"

///|
const NM_PATH : String = "/org/freedesktop/NetworkManager"

///|
/// NM 是否在线(系统总线 NameHasOwner 真实探测)。
pub fn nm_available() -> Bool {
  match system_conn() {
    Err(_) => false
    Ok(c) =>
      match c.call_sync(
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus",
          "org.freedesktop.DBus",
          "NameHasOwner",
          "s",
          [VString(NM)],
        ) {
        Ok(m) =>
          match m.body.get(0) {
            Some(VBool(true)) => true
            _ => false
          }
        Err(_) => false
      }
  }
}

///|
/// Properties.Get("u") 应答的 variant 内值。
fn vu32_of(m : Msg) -> Int? {
  match m.body.get(0) {
    Some(VVariant(VU32(v))) => Some(v)
    _ => None
  }
}

///|
/// 读单个顶层属性(u32)。
fn nm_get_u32(prop : String) -> Result[Int, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  match
    c.call_sync(
      NM,
      NM_PATH,
      "org.freedesktop.DBus.Properties",
      "Get",
      "ss",
      [VString(NM), VString(prop)],
    ) {
    Ok(m) =>
      match vu32_of(m) {
        Some(v) => Ok(v)
        None => Err("\{prop} 应答类型不符")
      }
    Err(e) => Err(e)
  }
}

///|
/// 连接状态原始码(State):70=全球联网 50=站点级 40=连接中 30=断开中
/// 20=已断开 10=休眠。
pub fn nm_state() -> Result[Int, String] {
  nm_get_u32("State")
}

///|
/// 互联网连通性原始码(Connectivity):4=完全 3=受限 2=门户 1=无 0=未知。
pub fn nm_connectivity() -> Result[Int, String] {
  nm_get_u32("Connectivity")
}

///|
let g_nm_state : Ref[Int] = Ref(-1)

///|
let g_nm_conn : Ref[Int] = Ref(-1)

///|
let g_nm_cbs : Array[(Int, Int) -> Unit] = []

///|
let g_nm_watched : Ref[Bool] = Ref(false)

///|
/// 通知回调(以缓存双值归并,不重查)。
fn nm_notify() -> Unit {
  for cb in g_nm_cbs {
    cb(g_nm_state.val, g_nm_conn.val)
  }
}

///|
/// PropertiesChanged 的 changed 字典里找 u32 属性。
fn changed_u32(body : Array[DVal], key : String) -> Int? {
  match body.get(1) {
    Some(VArray(_, items)) => {
      for it in items {
        match it {
          VStruct([VString(k), VVariant(VU32(v))]) =>
            if k == key {
              return Some(v)
            }
          _ => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
/// 注册 (State, Connectivity) 变化回调。注册时同步查询一次建缓存
/// (主线程、非 drain 栈,合法);此后信号驱动,回调内只读缓存。
pub fn nm_on_change(cb : (Int, Int) -> Unit) -> Result[Unit, String] {
  let c = match system_conn() {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  // 建缓存(未建时)
  if g_nm_state.val < 0 {
    match nm_state() {
      Ok(v) => g_nm_state.val = v
      Err(e) => return Err(e)
    }
  }
  if g_nm_conn.val < 0 {
    match nm_connectivity() {
      Ok(v) => g_nm_conn.val = v
      Err(e) => return Err(e)
    }
  }
  if !g_nm_watched.val {
    g_nm_watched.val = true
    // 老式:StateChanged(u) 直带新值
    c.subscribe(
      "type='signal',sender='org.freedesktop.NetworkManager',interface='org.freedesktop.NetworkManager',member='StateChanged'",
      "org.freedesktop.NetworkManager.StateChanged",
      fn(m) {
        match m.body.get(0) {
          Some(VU32(v)) => {
            g_nm_state.val = v
            nm_notify()
          }
          _ => ()
        }
      },
    )
    // 新式:PropertiesChanged(a{sv}),changed 里可能带 State/Connectivity。
    // 与 UPower 的订阅同名同键(同一系统总线连接的订阅表支持多回调)
    c.subscribe(
      "type='signal',sender='org.freedesktop.NetworkManager',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.freedesktop.NetworkManager'",
      "org.freedesktop.DBus.Properties.PropertiesChanged",
      fn(m) {
        if m.path != NM_PATH {
          return // 设备级属性变化不看
        }
        match changed_u32(m.body, "State") {
          Some(v) => g_nm_state.val = v
          None => ()
        }
        match changed_u32(m.body, "Connectivity") {
          Some(v) => g_nm_conn.val = v
          None => ()
        }
        nm_notify()
      },
    )
  }
  g_nm_cbs.push(cb)
  Ok(())
}
