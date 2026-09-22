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
  menu_path : String
  menu_items : Array[MenuEntry]
  mut menu_revision : Int
  mut on_click : (() -> Unit)?
  mut on_context : (() -> Unit)?
  mut on_context_menu : ((Double, Double) -> Unit)?
}

///|
/// 注册 ContextMenu(x, y) 回调（带图标屏幕坐标，用于应用自绘菜单）。
pub fn Item::set_context_menu_handler(
  self : Item,
  cb : (Double, Double) -> Unit,
) -> Unit {
  self.on_context_menu = Some(cb)
}

///|
fn Item::emit_context_menu(self : Item, x : Double, y : Double) -> Unit {
  match self.on_context_menu {
    Some(cb) => cb(x, y)
    None => ()
  }
}

///|
/// 托盘菜单条目（一级；DBusMenu id = 数组下标 + 1，0 是根）。
pub struct MenuEntry {
  id : Int
  label : String
  is_separator : Bool
  enabled : Bool
  on_click : () -> Unit
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
    // DBusMenu 对象路径：跟随 ksni/fcitx5 的约定用 /MenuBar（固定名）
    menu_path: "/MenuBar",
    menu_items: [],
    menu_revision: 1,
    on_click: None,
    on_context: None,
    on_context_menu: None,
  }
  let (w, h, px) = default_icon_pixmap()
  item.set_pixmap(w, h, px)
  c.items.set(path, item)
  c.menus.set(item.menu_path, item)
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
  // 跟踪 watcher 重启：换了 owner 就把所有项重新注册。
  // AddMatch 走 add_match（规则登记在案，断线自愈重连后重放）。
  self.add_match(
    "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.kde.StatusNotifierWatcher'",
  )
  match
    self.call_sync(
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
        _ =>
          return Err(
            "面板没有 StatusNotifierWatcher（GNOME 需安装 AppIndicator 扩展）",
          )
      }
    Err(e) => return Err(e)
  }
  match
    self.call_sync(
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
      let _ = c.call(
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
/// 同时清空位图：XFCE 等面板 IconPixmap 优先于 IconName，不清空则
/// 换名后重读属性仍画旧位图，视觉上"无效"。
pub fn Item::set_icon_name(self : Item, name : String) -> Unit {
  self.icon_name = name
  self.pixmap_w = 0
  self.pixmap_h = 0
  self.pixmap = Bytes::make(0, 0)
  self.emit("NewIcon")
}

///|
/// 设置位图图标（SNI 的 ARGB32 大端字节流，无行距补齐）。
pub fn Item::set_pixmap(self : Item, w : Int, h : Int, argb : Bytes) -> Unit {
  self.icon_name = ""
  self.pixmap_w = w
  self.pixmap_h = h
  self.pixmap = argb
}

///|
/// 通知面板图标已变化（NewIcon 信号）。
pub fn Item::emit_new_icon(self : Item) -> Unit {
  self.emit("NewIcon")
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
/// 追加一个菜单项（一级菜单；点击触发 on_click）。
pub fn Item::add_menu_entry(
  self : Item,
  label : String,
  enabled : Bool,
  on_click : () -> Unit,
) -> Unit {
  let id = self.menu_items.length() + 1
  self.menu_items.push({ id, label, is_separator: false, enabled, on_click, })
  self.menu_revision += 1
  self.emit_layout_updated()
}

///|
/// 追加一条菜单分隔线。
pub fn Item::add_menu_separator(self : Item) -> Unit {
  let id = self.menu_items.length() + 1
  self.menu_items.push({
    id,
    label: "",
    is_separator: true,
    enabled: true,
    on_click: fn() { () },
  })
  self.menu_revision += 1
  self.emit_layout_updated()
}

///|
fn Item::emit_layout_updated(self : Item) -> Unit {
  match g_conn.val {
    Some(c) =>
      c.emit_signal(
        self.menu_path,
        "com.canonical.dbusmenu",
        "LayoutUpdated",
        "ui",
        [VU32(self.menu_revision), VI32(0)],
      )
    None => ()
  }
}

///|
/// 条目属性对列表（DBusMenu 约定的属性名），外层按需包 a{sv}。
fn menu_entry_prop_pairs(entry : MenuEntry) -> Array[DVal] {
  let props : Array[DVal] = []
  if entry.is_separator {
    props.push(VStruct([VString("type"), VVariant(VString("separator"))]))
  } else {
    props.push(VStruct([VString("label"), VVariant(VString(entry.label))]))
  }
  props.push(VStruct([VString("enabled"), VVariant(VBool(entry.enabled))]))
  props.push(VStruct([VString("visible"), VVariant(VBool(true))]))
  props
}

///|
/// DBusMenu 布局节点：(id, 属性, 子节点 av)。
fn Item::menu_layout(self : Item, id : Int, depth : Int) -> DVal {
  let props : Array[DVal] = []
  if id == 0 {
    props.push(
      VStruct([VString("children-display"), VVariant(VString("submenu"))]),
    )
  } else {
    match self.menu_items.get(id - 1) {
      Some(entry) => {
        let pairs = menu_entry_prop_pairs(entry)
        for pair in pairs {
          props.push(pair)
        }
      }
      None => ()
    }
  }
  let children : Array[DVal] = []
  if id == 0 && depth != 0 {
    for entry in self.menu_items {
      let child_depth = if depth > 0 { depth - 1 } else { 0 }
      children.push(VVariant(self.menu_layout(entry.id, child_depth)))
    }
  }
  VStruct([VI32(id), VArray("{sv}", props), VArray("v", children)])
}

///|
/// 按条目 id 触发点击回调（id 从 1 计，与布局/属性层一致）。
fn Item::dispatch_menu_click(self : Item, id : Int) -> Unit {
  if id >= 1 {
    match self.menu_items.get(id - 1) {
      Some(entry) => if !entry.is_separator { (entry.on_click)() }
      None => ()
    }
  }
}

///|
/// DBusMenu 服务端分发（菜单对象路径上的调用）。
fn Conn::handle_menu_call(self : Conn, item : Item, msg : Msg) -> Unit {
  match msg.action {
    "GetLayout" => {
      let depth = match msg.body.get(1) {
        Some(VI32(d)) => d
        _ => 1
      }
      let layout = item.menu_layout(0, depth)
      // 出参逐个排列：revision(u) + 布局(ia{sv}av)。
      // 签名不能再带外层括号——reply 的 sig 按参数列表编码，
      // 写 "(u(ia{sv}av))" 会把整个元组当成单个结构体参数双重包装，
      // GDBus 客户端签名校验失败，布局解析随之整段跳过。
      self.reply(msg, "u(ia{sv}av)", [VU32(item.menu_revision), layout])
    }
    // 恒 false：libdbusmenu 不尊重返回值，菜单更新靠 LayoutUpdated 信号
    "AboutToShow" => self.reply(msg, "b", [VBool(false)])
    // 批量版 AboutToShow：与 ids 平行的 ab，恒 false
    "AboutToShowGroup" => {
      let flags : Array[DVal] = []
      match msg.body.get(0) {
        Some(VArray(_, ids)) =>
          for _ in ids {
            flags.push(VBool(false))
          }
        _ => ()
      }
      self.reply(msg, "ab", [VArray("b", flags)])
    }
    "Event" => {
      // (i id, s eventId, v data, u timestamp)
      let id = match msg.body.get(0) {
        Some(VI32(id)) => id
        _ => 0
      }
      let event = match msg.body.get(1) {
        Some(VString(e)) => e
        _ => ""
      }
      if event == "clicked" {
        item.dispatch_menu_click(id)
      }
      self.reply(msg, "", [])
    }
    // 批量版 Event：XFCE 面板（libdbusmenu 客户端）实际发的是它而非单条
    // Event；不实现会被 UnknownMethod 拒掉，表现为菜单点击全部无效。
    "EventGroup" => {
      // (a(iisvu) events)，每项 (id, eventId, data, timestamp)
      match msg.body.get(0) {
        Some(VArray(_, events)) =>
          for ev in events {
            match ev {
              VStruct(fields) =>
                match (fields.get(0), fields.get(1)) {
                  (Some(VI32(id)), Some(VString(event))) =>
                    if event == "clicked" {
                      item.dispatch_menu_click(id)
                    }
                  (_, _) => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
      self.reply(msg, "", [])
    }
    "GetProperty" => {
      let id = match msg.body.get(0) {
        Some(VI32(id)) => id
        _ => 0
      }
      let name = match msg.body.get(1) {
        Some(VString(n)) => n
        _ => ""
      }
      let value : DVal = match (id, name) {
        (0, "children-display") => VString("submenu")
        (_, "label") =>
          match item.menu_items.get(id - 1) {
            Some(e) => VString(e.label)
            None => VString("")
          }
        (_, "enabled") =>
          match item.menu_items.get(id - 1) {
            Some(e) => VBool(e.enabled)
            None => VBool(false)
          }
        (_, "visible") => VBool(true)
        (_, "type") =>
          match item.menu_items.get(id - 1) {
            Some(e) =>
              VString(if e.is_separator { "separator" } else { "standard" })
            None => VString("standard")
          }
        // 接口级属性（Qt 适配器同款），客户端经 GetAll 缓存后一般不再单独问
        (0, "Status") => VString("normal")
        (0, "TextDirection") => VString("ltr")
        (_, _) => VString("")
      }
      self.reply(msg, "v", [VVariant(value)])
    }
    "GetGroupProperties" => {
      // libdbusmenu 客户端要求每个请求 id 都有条目：缺失的节点会收到
      // "Error getting properties for ID" 而永不 realize，Gtk 菜单随之留空。
      // root(id=0) 也会排队拉属性，须以空属性集应答。
      let entries : Array[DVal] = []
      match msg.body.get(0) {
        Some(VArray(_, ids)) =>
          for idv in ids {
            let id = match idv {
              VI32(n) => n
              _ => -1
            }
            if id >= 1 {
              match item.menu_items.get(id - 1) {
                Some(entry) =>
                  entries.push(
                    VStruct([
                      VI32(id),
                      VArray("{sv}", menu_entry_prop_pairs(entry)),
                    ]),
                  )
                None => entries.push(VStruct([VI32(id), VArray("{sv}", [])]))
              }
            } else if id == 0 {
              entries.push(VStruct([VI32(0), VArray("{sv}", [])]))
            }
          }
        _ => ()
      }
      self.reply(msg, "a(ia{sv})", [VArray("(ia{sv})", entries)])
    }
    _ =>
      self.reply_error(
        msg,
        "org.freedesktop.DBus.Error.UnknownMethod",
        "未知 DBusMenu 方法: \{msg.action}",
      )
  }
}

///|
let dbusmenu_introspect_xml : String = "<!DOCTYPE node PUBLIC '-//freedesktop//DTD D-BUS Object Introspection 1.0//EN' 'http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd'><node><interface name='com.canonical.dbusmenu'><method name='GetLayout'><arg direction='in' type='i'/><arg direction='in' type='i'/><arg direction='in' type='as'/><arg direction='out' type='u'/><arg direction='out' type='(ia{sv}av)'/></method><method name='AboutToShow'><arg direction='in' type='i'/><arg direction='out' type='b'/></method><method name='Event'><arg direction='in' type='i'/><arg direction='in' type='s'/><arg direction='in' type='v'/><arg direction='in' type='u'/></method><method name='GetProperty'><arg direction='in' type='i'/><arg direction='in' type='s'/><arg direction='out' type='v'/></method><method name='GetGroupProperties'><arg direction='in' type='ai'/><arg direction='in' type='as'/><arg direction='out' type='a(ia{sv})'/></method><signal name='LayoutUpdated'><arg type='u'/><arg type='i'/></signal></interface></node>"

///|
fn Item::pixmap_value(self : Item) -> DVal {
  let pixels : Array[DVal] = []
  for i in 0..<self.pixmap.length() {
    pixels.push(VByte(self.pixmap[i].to_int()))
  }
  VStruct([VI32(self.pixmap_w), VI32(self.pixmap_h), VArray("y", pixels)])
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
    "IconPixmap" =>
      Some(
        VArray("(iiay)", [
          self.pixmap_value(),
          // 附加 16×16 小尺寸,供高密度面板选择
          {
            let (sw, sh, spx) = downscale_pixmap(
              self.pixmap_w,
              self.pixmap_h,
              self.pixmap,
              16,
              16,
            )
            let pixels : Array[DVal] = []
            for i in 0..<spx.length() {
              pixels.push(VByte(spx[i].to_int()))
            }
            VStruct([VI32(sw), VI32(sh), VArray("y", pixels)])
          },
        ]),
      )
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
    // 恒返回真实路径：GNOME AppIndicator 扩展在注册瞬间就读 Menu，若此时
    // set_menu 未执行而返回 "/"，其 DBusMenu 客户端会永久指向无效对象
    // （UnknownObject: /），之后点击图标再也不发 Activate/不开菜单。
    // 空菜单也导出 /MenuBar（Qt 同款语义），后续靠 LayoutUpdated 通知填充。
    "Menu" => Some(VPath(self.menu_path))
    // 恒 false：true 会让面板把左键当菜单键、不再发 Activate（ksni 同款语义）
    "ItemIsMenu" => Some(VBool(false))
    _ => None
  }
}

///|
fn item_property_names() -> Array[String] {
  [
    "Category", "Id", "Title", "Status", "WindowId", "IconName", "IconPixmap", "OverlayIconName",
    "OverlayIconPixmap", "AttentionIconName", "AttentionIconPixmap", "AttentionMovieName",
    "ToolTip", "Menu", "ItemIsMenu",
  ]
}

///|
let introspect_xml : String = "<!DOCTYPE node PUBLIC '-//freedesktop//DTD D-BUS Object Introspection 1.0//EN' 'http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd'><node><interface name='org.kde.StatusNotifierItem'><method name='Activate'><arg direction='in' type='i'/><arg direction='in' type='i'/></method><method name='SecondaryActivate'><arg direction='in' type='i'/><arg direction='in' type='i'/></method><method name='ContextMenu'><arg direction='in' type='i'/><arg direction='in' type='i'/></method><method name='Scroll'><arg direction='in' type='i'/><arg direction='in' type='s'/></method><property name='Id' type='s' access='read'/><property name='Title' type='s' access='read'/><property name='Status' type='s' access='read'/><property name='IconName' type='s' access='read'/><property name='IconPixmap' type='a(iiay)' access='read'/><property name='ToolTip' type='(sa(iiay)ss)' access='read'/><property name='Menu' type='o' access='read'/></interface><interface name='org.freedesktop.DBus.Properties'><method name='Get'><arg direction='in' type='s'/><arg direction='in' type='s'/><arg direction='out' type='v'/></method><method name='GetAll'><arg direction='in' type='s'/><arg direction='out' type='a{sv}'/></method></interface><interface name='org.freedesktop.DBus.Introspectable'><method name='Introspect'><arg direction='out' type='s'/></method></interface></node>"

///|
/// 处理发往托盘对象的入站调用（面板侧查询与激活）。
fn Conn::handle_call(self : Conn, msg : Msg) -> Unit {
  // DBusMenu：托盘菜单对象路径上的全部调用
  if msg.iface == "com.canonical.dbusmenu" {
    match self.menus.get(msg.path) {
      Some(item) => self.handle_menu_call(item, msg)
      None => self.unknown_object(msg)
    }
    return
  }
  // 面板会经 Properties 接口查询 DBusMenu 版本
  if (msg.iface, msg.action) == ("org.freedesktop.DBus.Properties", "GetAll") {
    match (self.menus.get(msg.path), msg.body.get(0)) {
      (Some(_), Some(VString("com.canonical.dbusmenu"))) => {
        // 与 Qt QDBusMenuAdaptor 对齐：客户端缓存这些接口级属性
        let entries : Array[DVal] = [
          VStruct([VString("Version"), VVariant(VU32(3))]),
          VStruct([VString("TextDirection"), VVariant(VString("ltr"))]),
          VStruct([VString("Status"), VVariant(VString("normal"))]),
        ]
        self.reply(msg, "a{sv}", [VArray("{sv}", entries)])
        return
      }
      (_, _) => ()
    }
  }
  match (msg.iface, msg.action) {
    ("org.freedesktop.DBus.Peer", "Ping") => self.reply(msg, "", [])
    ("org.freedesktop.DBus.Introspectable", "Introspect") => {
      let xml = if self.menus.contains(msg.path) {
        dbusmenu_introspect_xml
      } else {
        introspect_xml
      }
      self.reply(msg, "s", [VString(xml)])
    }
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
                  msg, "org.freedesktop.DBus.Error.InvalidArgs", "参数类型错误",
                )
            }
          } else {
            self.reply_error(
              msg, "org.freedesktop.DBus.Error.InvalidArgs", "缺少参数",
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
    ("org.kde.StatusNotifierItem", "SecondaryActivate") => self.fire_click(msg)
    ("org.kde.StatusNotifierItem", "ContextMenu") => {
      // Qt 模式（XFCE 等面板的约定）：应答成功，由应用自己在图标处弹菜单；
      // KDE/GNOME 扩展则走 Menu 属性的 DBusMenu
      let x = match msg.body.get(0) {
        Some(VI32(v)) => v.to_double()
        _ => 0.0
      }
      let y = match msg.body.get(1) {
        Some(VI32(v)) => v.to_double()
        _ => 0.0
      }
      match self.items.get(msg.path) {
        Some(item) => {
          self.reply(msg, "", [])
          match item.on_context {
            Some(cb) => cb()
            None => ()
          }
          item.emit_context_menu(x, y)
        }
        None => self.unknown_object(msg)
      }
    }
    ("org.kde.StatusNotifierItem", "Scroll") =>
      self.reply_error(
        msg, "org.freedesktop.DBus.Error.UnknownMethod", "Scroll 暂不支持",
      )
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
