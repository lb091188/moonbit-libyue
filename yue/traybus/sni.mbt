// StatusNotifierItem（freedesktop SNI 协议）的纯 MoonBit 实现。
// 直连面板侧的 org.kde.StatusNotifierWatcher：XFCE/KDE/MATE/Cinnamon/
// Budgie/LXQt 及装有 AppIndicator 扩展的 GNOME 原生可用，
// 不再依赖 AppIndicator 运行库（Ubuntu 24.04 已不含传统 libappindicator3）。

///|
let sni_iface : String = "org.kde.StatusNotifierItem"

///|
let watcher_name : String = "org.kde.StatusNotifierWatcher"

///|
/// 一个托盘图标实例（对应总线上一个 StatusNotifierItem 对象）。
pub struct Item {
  path : String
  id : String
  mut title : String
  mut icon_name : String
  mut pixmap_w : Int
  mut pixmap_h : Int
  mut pixmap : Bytes // ARGB 大端序（网络字节序），长度 4*w*h
  mut tip_title : String
  mut tip_body : String
  has_menu : Bool
  mut on_click : (() -> Unit)?
  mut on_context : (() -> Unit)?
}

///|
/// 创建并注册托盘项。id 显示在面板 tooltip 里，icon_path 仅用于推导 id。
/// 图标默认用程序生成的位图；主题图标名可随后用 set_icon_name 指定。
pub fn Item::create(id : String, icon_path : String) -> Result[Item, String] {
  let c = match g_conn.val {
    Some(c) => c
    None =>
      match connect_session() {
        Ok(c) => {
          g_conn.val = Some(c)
          c
        }
        Err(e) => return Err(e)
      }
  }
  if !c.alive {
    return Err("会话总线连接已断开")
  }
  let path = c.next_item_path()
  let item : Item = {
    path,
    id,
    title: id,
    icon_name: "",
    pixmap_w: 0,
    pixmap_h: 0,
    pixmap: Bytes::make(0, 0),
    tip_title: "",
    tip_body: icon_path,
    has_menu: false,
    on_click: None,
    on_context: None,
  }
  let (w, h, px) = default_icon_pixmap()
  item.set_pixmap(w, h, px)
  c.items.set(path, item)
  match c.register_item_path(path) {
    Ok(_) => Ok(item)
    Err(e) => {
      let _ = c.items.remove(path)
      Err(e)
    }
  }
}

///|
fn Conn::next_item_path(self : Conn) -> String {
  let n = self.items.length()
  if n == 0 {
    "/StatusNotifierItem"
  } else {
    "/StatusNotifierItem_\{n + 1}"
  }
}

///|
/// 向 watcher 注册指定路径的托盘项（含 watcher 存在性检查与重启跟踪）。
fn Conn::register_item_path(self : Conn, path : String) -> Result[Unit, String] {
  if !self.match_added {
    // 跟踪 watcher 重启：换了 owner 就把所有项重新注册。
    // AddMatch 是方法调用（此前误发成广播信号被总线忽略）。
    self.call(
      "org.freedesktop.DBus",
      "/org/freedesktop/DBus",
      "org.freedesktop.DBus",
      "AddMatch",
      "s",
      [VString(
        "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.kde.StatusNotifierWatcher'",
      )],
      fn(_m) { () },
    )
    self.match_added = true
  }
  match self.call_sync(
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "NameHasOwner",
    "s",
    [VString(watcher_name)],
  ) {
    Ok(m) =>
      match m.body.get(0) {
        Some(VBool(true)) => ()
        _ => return Err("面板没有 StatusNotifierWatcher（GNOME 需安装 AppIndicator 扩展）")
      }
    Err(e) => return Err(e)
  }
  match self.call_sync(
    watcher_name,
    "/StatusNotifierWatcher",
    "org.kde.StatusNotifierWatcher",
    "RegisterStatusNotifierItem",
    "s",
    [VString(path)],
  ) {
    Ok(_) => Ok(())
    Err(e) => Err("托盘注册失败: \{e}")
  }
}

///|
/// 注销并移除托盘项。
pub fn Item::unregister(self : Item) -> Unit {
  match g_conn.val {
    Some(c) => {
      // fire-and-forget：watcher 不在时调用会失败，无需关心
      c.call(
        watcher_name,
        "/StatusNotifierWatcher",
        "org.kde.StatusNotifierWatcher",
        "UnregisterStatusNotifierItem",
        "s",
        [VString(self.path)],
        fn(_m) { () },
      )
      let _ = c.items.remove(self.path)
    }
    None => ()
  }
}

///|
fn Item::emit(self : Item, action : String) -> Unit {
  match g_conn.val {
    Some(c) => c.emit_signal(self.path, sni_iface, action, "", [])
    None => ()
  }
}

///|
/// 设置标题（部分面板不渲染，属平台表现差异）。
pub fn Item::set_title(self : Item, title : String) -> Unit {
  self.title = title
  self.emit("NewTitle")
}

///|
/// 设置主题图标名（跟随系统图标主题，如 "utilities-terminal"）。
pub fn Item::set_icon_name(self : Item, name : String) -> Unit {
  self.icon_name = name
  self.emit("NewIcon")
}

///|
fn Item::set_pixmap(self : Item, w : Int, h : Int, argb : Bytes) -> Unit {
  self.pixmap_w = w
  self.pixmap_h = h
  self.pixmap = argb
}

///|
/// 设置悬浮提示。
pub fn Item::set_tooltip(self : Item, title : String, body : String) -> Unit {
  self.tip_title = title
  self.tip_body = body
  self.emit("NewToolTip")
}

///|
/// 注册左键/激活回调。
pub fn Item::set_click_handler(self : Item, cb : () -> Unit) -> Unit {
  self.on_click = Some(cb)
}

///|
/// 注册右键/上下文菜单回调。
pub fn Item::set_context_handler(self : Item, cb : () -> Unit) -> Unit {
  self.on_context = Some(cb)
}

///|
fn Item::pixmap_value(self : Item) -> DVal {
  let pixels : Array[DVal] = []
  for i in 0..<self.pixmap.length() {
    pixels.push(VByte(self.pixmap[i].to_int()))
  }
  VStruct([
    VI32(self.pixmap_w),
    VI32(self.pixmap_h),
    VArray("y", pixels),
  ])
}

///|
/// 属性表（SNI 规范定义的全部常用属性）。
fn Item::property(self : Item, name : String) -> DVal? {
  match name {
    "Category" => Some(VString("ApplicationStatus"))
    "Id" => Some(VString(self.id))
    "Title" => Some(VString(self.title))
    "Status" => Some(VString("Active"))
    "WindowId" => Some(VI32(0))
    "IconName" => Some(VString(self.icon_name))
    "IconPixmap" => Some(VArray("(iiay)", [self.pixmap_value()]))
    "OverlayIconName" => Some(VString(""))
    "OverlayIconPixmap" => Some(VArray("(iiay)", []))
    "AttentionIconName" => Some(VString(""))
    "AttentionIconPixmap" => Some(VArray("(iiay)", []))
    "AttentionMovieName" => Some(VString(""))
    "ToolTip" =>
      Some(
        VStruct([
          VString(""),
          VArray("(iiay)", []),
          VString(self.tip_title),
          VString(self.tip_body),
        ]),
      )
    "Menu" => Some(VPath("/StatusNotifierMenu"))
    "ItemIsMenu" => Some(VBool(self.has_menu))
    _ => None
  }
}

///|
fn item_property_names() -> Array[String] {
  [
    "Category",
    "Id",
    "Title",
    "Status",
    "WindowId",
    "IconName",
    "IconPixmap",
    "OverlayIconName",
    "OverlayIconPixmap",
    "AttentionIconName",
    "AttentionIconPixmap",
    "AttentionMovieName",
    "ToolTip",
    "Menu",
    "ItemIsMenu",
  ]
}

///|
let introspect_xml : String = "<!DOCTYPE node PUBLIC '-//freedesktop//DTD D-BUS Object Introspection 1.0//EN' 'http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd'><node><interface name='org.kde.StatusNotifierItem'><method name='Activate'><arg direction='in' type='i'/><arg direction='in' type='i'/></method><method name='SecondaryActivate'><arg direction='in' type='i'/><arg direction='in' type='i'/></method><method name='ContextMenu'><arg direction='in' type='i'/><arg direction='in' type='i'/></method><method name='Scroll'><arg direction='in' type='i'/><arg direction='in' type='s'/></method><property name='Id' type='s' access='read'/><property name='Title' type='s' access='read'/><property name='Status' type='s' access='read'/><property name='IconName' type='s' access='read'/><property name='IconPixmap' type='a(iiay)' access='read'/><property name='ToolTip' type='(sa(iiay)ss)' access='read'/><property name='Menu' type='o' access='read'/></interface><interface name='org.freedesktop.DBus.Properties'><method name='Get'><arg direction='in' type='s'/><arg direction='in' type='s'/><arg direction='out' type='v'/></method><method name='GetAll'><arg direction='in' type='s'/><arg direction='out' type='a{sv}'/></method></interface><interface name='org.freedesktop.DBus.Introspectable'><method name='Introspect'><arg direction='out' type='s'/></method></interface></node>"

///|
/// 处理发往托盘对象的入站调用（面板侧查询与激活）。
fn Conn::handle_call(self : Conn, msg : Msg) -> Unit {
  match (msg.iface, msg.action) {
    ("org.freedesktop.DBus.Peer", "Ping") => self.reply(msg, "", [])
    ("org.freedesktop.DBus.Introspectable", "Introspect") =>
      self.reply(msg, "s", [VString(introspect_xml)])
    ("org.freedesktop.DBus.Properties", "Get") =>
      match self.items.get(msg.path) {
        Some(item) =>
          if msg.body.length() >= 2 {
            match (dstr(msg.body[0]), dstr(msg.body[1])) {
              (Some(_), Some(prop)) =>
                match item.property(prop) {
                  Some(v) => self.reply(msg, "v", [VVariant(v)])
                  None =>
                    self.reply_error(
                      msg,
                      "org.freedesktop.DBus.Error.InvalidArgs",
                      "没有属性: \{prop}",
                    )
                }
              _ =>
                self.reply_error(
                  msg,
                  "org.freedesktop.DBus.Error.InvalidArgs",
                  "参数类型错误",
                )
            }
          } else {
            self.reply_error(
              msg,
              "org.freedesktop.DBus.Error.InvalidArgs",
              "缺少参数",
            )
          }
        None => self.unknown_object(msg)
      }
    ("org.freedesktop.DBus.Properties", "GetAll") =>
      match self.items.get(msg.path) {
        Some(item) => {
          let entries : Array[DVal] = []
          for name in item_property_names() {
            match item.property(name) {
              Some(v) => entries.push(VStruct([VString(name), VVariant(v)]))
              None => ()
            }
          }
          self.reply(msg, "a{sv}", [VArray("{sv}", entries)])
        }
        None => self.unknown_object(msg)
      }
    ("org.freedesktop.DBus.Properties", "Set") =>
      // 面板不改我们的属性；按规范回 InvalidArgs 以外的常规应答即可
      self.reply(msg, "", [])
    ("org.kde.StatusNotifierItem", "Activate") => self.fire_click(msg)
    ("org.kde.StatusNotifierItem", "SecondaryActivate") =>
      self.fire_click(msg)
    ("org.kde.StatusNotifierItem", "ContextMenu") =>
      match self.items.get(msg.path) {
        Some(item) => {
          match item.on_context {
            Some(cb) => cb()
            None => ()
          }
          self.reply(msg, "", [])
        }
        None => self.unknown_object(msg)
      }
    ("org.kde.StatusNotifierItem", "Scroll") =>
      match self.items.get(msg.path) {
        Some(_) => self.reply(msg, "", [])
        None => self.unknown_object(msg)
      }
    (_, _) =>
      self.reply_error(
        msg,
        "org.freedesktop.DBus.Error.UnknownMethod",
        "未知方法: \{msg.iface}.\{msg.action}",
      )
  }
}

///|
fn Conn::fire_click(self : Conn, msg : Msg) -> Unit {
  match self.items.get(msg.path) {
    Some(item) => {
      match item.on_click {
        Some(cb) => cb()
        None => ()
      }
      self.reply(msg, "", [])
    }
    None => self.unknown_object(msg)
  }
}

///|
fn Conn::unknown_object(self : Conn, msg : Msg) -> Unit {
  self.reply_error(
    msg,
    "org.freedesktop.DBus.Error.UnknownObject",
    "未知对象: \{msg.path}",
  )
}
