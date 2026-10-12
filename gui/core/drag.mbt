// 拖放门面（W21c）：数据模型 `DragData` + 控件钩子（拖源 `set_draggable` / 投放
// `set_on_drop`）+ **应用内**拖拽会话。
//
// 本批的口径（写清以免被当成「没做完」）：
// - **已做**：同一进程、同一控件树内的拖放——拖源按住拖出内容、指针移动时实时
//   算出落点、松手投给命中的投放目标。新栈全自绘，命中与绘制都在自己手里，这条
//   路不需要任何平台接口，**三平台同构**。
// - **未做（随平台批）**：**跨应用**的系统级拖放（Win32 `IDropTarget`/`DoDragDrop`、
//   Linux GTK/XDG DnD、macOS `NSDraggingSource`）。接口形状已按本批定好
//   （`Widget::set_draggable` / `Widget::set_on_drop`），后端接上后调用方不用改。
//   在此之前**不假装**系统级拖放能用：`DragData` 只在应用内流转。
// - 参照面是旧栈的 `yue/view.mbt`（`DataKind` / `DragData` / `register_dragged_types`
//   / `handle_drag_enter`/`handle_drag_update`/`handle_drop`/`on_drag_leave`）。
//   本批把「拖入三回调」收成一个 `on_drop`（自绘档不需要 enter/update/leave 三件：
//   悬停高亮靠读 `drag_hover()`，见下），编号与旧栈逐值相同。
//
// 数据线形状：`[kind:i32 LE][payload]`——与旧栈拖拽/剪贴板共用的编码同形，
// 为将来 core 侧剪贴板预留（`Paths` 载荷用 `\n` 连接路径，同旧栈）。

///|
/// 拖拽数据种类（与旧栈 `yue/view.mbt` 的 `DataKind` 同义）。
pub(all) enum DataKind {
  Text
  Html
  Image
  FilePaths
}

///|
/// 种类编号。**值不能随手改**：它是「与剪贴板共用的线上形状」的一部分，旧栈
/// 就是这四值。
pub fn data_kind_id(kind : DataKind) -> Int {
  match kind {
    Text => 1
    Html => 2
    Image => 3
    FilePaths => 4
  }
}

///|
/// 编号 → 种类（认不出给 None，调用方走降级而不是当成文本）。
pub fn data_kind_of_id(id : Int) -> DataKind? {
  match id {
    1 => Some(Text)
    2 => Some(Html)
    3 => Some(Image)
    4 => Some(FilePaths)
    _ => None
  }
}

///|
/// 种类相等（走编号，语义与 `==` 同）。手写而不是 `derive(Eq)`：本工具链里给值类型
/// `derive(Eq)` 会把 impl 方法隐式升成普通方法并告警（见 `datetime_wbtest` 的记档），
/// 零警告门禁下不划算。
pub impl Eq for DataKind with fn equal(self : DataKind, other : DataKind) -> Bool {
  data_kind_id(self) == data_kind_id(other)
}

///|
pub extend DataKind with Eq::{not_equal, equal}

///|
/// 拖拽数据本体。
/// 与旧栈的一处差（记档）：旧栈 `Img(Image)` 用的是平台图像句柄类型，本批用
/// **原始 PNG 字节** `Img(Bytes)`——core 层不依赖任何平台图像类型，三平台同构；
/// 要显示时由调用方自己交给解码后端（`@win.icon_from_png` / `render`）。
pub(all) enum DragData {
  Text(String)
  Html(String)
  Paths(Array[String])
  Img(Bytes)
}

///|
/// 数据本体 → 自己的种类（拖源注册用）。
pub fn DragData::kind(self : DragData) -> DataKind {
  match self {
    Text(_) => Text
    Html(_) => Html
    Paths(_) => FilePaths
    Img(_) => Image
  }
}

///|
/// 取文本形态（非文本种类给 None）：给「只想拿文本」的投放方一个短路径。
pub fn DragData::as_text(self : DragData) -> String? {
  match self {
    Text(t) => Some(t)
    Html(t) => Some(t)
    Paths(ps) => Some(ps.join("\n"))
    Img(_) => None
  }
}

///|
/// 数据本体是否属于某一种类（`accept` 判据的常用写法，免得调用方自己 match）。
pub fn DragData::is_kind(self : DragData, kind : DataKind) -> Bool {
  self.kind() == kind
}

///|
/// 编码成 `[kind:i32 LE][payload]`（`Paths` 用 `\n` 连接，`Img` 直给 PNG 字节）。
pub fn drag_encode(data : DragData) -> Bytes {
  let payload : Bytes = match data {
    Text(t) | Html(t) => @utf8.encode(t)
    Paths(ps) => @utf8.encode(ps.join("\n"))
    Img(b) => b
  }
  let id = data_kind_id(data.kind())
  let buf = FixedArray::make(payload.length() + 4, b'\x00')
  buf[0] = (id & 255).to_byte()
  buf[1] = ((id >> 8) & 255).to_byte()
  buf[2] = ((id >> 16) & 255).to_byte()
  buf[3] = ((id >> 24) & 255).to_byte()
  for i = 0; i < payload.length(); i = i + 1 {
    buf[4 + i] = payload[i]
  }
  Bytes::from_array(buf)
}

///|
/// 解码 `[kind:i32 LE][payload]`；长度不足 4 字节或种类编号认不出给 None。
pub fn drag_decode(raw : Bytes) -> DragData? {
  if raw.length() < 4 {
    return None
  }
  let id = raw[0].to_int() |
    (raw[1].to_int() << 8) |
    (raw[2].to_int() << 16) |
    (raw[3].to_int() << 24)
  let body = FixedArray::make(raw.length() - 4, b'\x00')
  for i = 4; i < raw.length(); i = i + 1 {
    body[i - 4] = raw[i]
  }
  let payload = Bytes::from_array(body)
  match data_kind_of_id(id) {
    None => None
    Some(Text) => Some(Text(@utf8.decode_lossy(payload)))
    Some(Html) => Some(Html(@utf8.decode_lossy(payload)))
    Some(FilePaths) =>
      if payload.length() == 0 {
        Some(Paths([]))
      } else {
        Some(
          Paths(@utf8.decode_lossy(payload).split("\n").collect().map(fn(s) {
            s.to_owned()
          })),
        )
      }
    Some(Image) => Some(Img(payload))
  }
}

///|
/// 一次拖拽会话（进程级单例：同一时刻只有一个拖拽在跑，与浮层宿主同制）。
pub(all) struct DragSession {
  data : DragData
  /// 拖源控件 id（0 = 非控件发起，如程序化拖拽）
  source : Int
  mut x : Double
  mut y : Double
  /// 当前指针下的投放目标控件 id（0 = 没有可投处）
  mut hover : Int
}

///|
let drag_current : Ref[DragSession?] = Ref(None)

///|
/// 取值函数：拖拽落点要在一棵控件树里命中。单窗形态给根控件（`set_drag_root`）；
/// 多窗形态由宿主层装成「取当前窗的根」（`set_drag_root_provider`）——与浮层宿主
/// 同一条通道形态。没装时所有拖拽 API 都能开能关，只是**落点恒为无**（不静默出错，
/// 只是投不中）。
let drag_root_slot : Ref[() -> Widget?] = Ref(fn() -> Widget? { None })

///|
pub fn set_drag_root_provider(f : () -> Widget?) -> Unit {
  drag_root_slot.val = f
}

///|
pub fn set_drag_root(root : Widget) -> Unit {
  drag_root_slot.val = fn() -> Widget? { Some(root) }
}

///|
pub fn clear_drag_root() -> Unit {
  drag_root_slot.val = fn() -> Widget? { None }
}

///|
fn drag_root() -> Widget? {
  (drag_root_slot.val)()
}

///|
/// 拖拽会话是否进行中。
pub fn drag_active() -> Bool {
  drag_current.val is Some(_)
}

///|
/// 当前拖拽的数据（没在拖给 None）。
pub fn drag_data() -> DragData? {
  match drag_current.val {
    Some(s) => Some(s.data)
    None => None
  }
}

///|
/// 拖源控件 id（0 = 非控件发起 / 没在拖）。
pub fn drag_source() -> Int {
  match drag_current.val {
    Some(s) => s.source
    None => 0
  }
}

///|
/// 指针当前位置（没在拖给 (0,0)）。
pub fn drag_position() -> (Double, Double) {
  match drag_current.val {
    Some(s) => (s.x, s.y)
    None => (0.0, 0.0)
  }
}

///|
/// 当前指针下的投放目标控件 id（0 = 没有可投处）。拖入高亮由绘制方读它自判
/// （`@core.drag_hover() == self.id`），所以不需要 enter/update/leave 三个回调。
pub fn drag_hover() -> Int {
  match drag_current.val {
    Some(s) => s.hover
    None => 0
  }
}

///|
/// 在 `w` 子树里找指针下的投放目标：**最深的**那个带 `on_drop` 的可见控件
/// （子控件优先，且从后往前找——后画的在上、命中优先）。找不到给 0。
pub fn Widget::drop_target_at(self : Widget, x : Double, y : Double) -> Int {
  if !self.visible {
    return 0
  }
  let ks = self.kids
  for i = ks.length() - 1; i >= 0; i = i - 1 {
    let r = ks[i].drop_target_at(x, y)
    if r != 0 {
      return r
    }
  }
  match self.on_drop {
    Some(_) => if self.rect.contains(x, y) { self.id } else { 0 }
    None => 0
  }
}

///|
/// 把控件标成拖源：按下拖过阈值后（阈值由调用方定，见 `@ui.drag_source`）调
/// `payload` 取数据，取到即开拖拽会话。
pub fn Widget::set_draggable(self : Widget, payload : () -> DragData?) -> Unit {
  self.drag_payload = Some(payload)
}

///|
/// 取消拖源标记。
pub fn Widget::clear_draggable(self : Widget) -> Unit {
  self.drag_payload = None
}

///|
/// 把控件标成投放目标：拖拽松手且本控件是最深命中者时回调，返回是否接受。
pub fn Widget::set_on_drop(
  self : Widget,
  f : (DragData, Double, Double) -> Bool,
) -> Unit {
  self.on_drop = Some(f)
}

///|
/// 取消投放目标标记。
pub fn Widget::clear_on_drop(self : Widget) -> Unit {
  self.on_drop = None
}

///|
/// 重算落点（会话内部用；根取不到时落点归 0）。
fn drag_retarget(s : DragSession) -> Unit {
  s.hover = match drag_root() {
    Some(r) => r.drop_target_at(s.x, s.y)
    None => 0
  }
}

///|
/// 开一次拖拽：`data` 是载荷、`source` 是拖源控件 id（0 = 程序化）、`(x, y)` 是
/// 当前指针位置（窗口坐标）。已在拖时给 false（不叠会话）。
pub fn drag_begin(data : DragData, source : Int, x : Double, y : Double) -> Bool {
  if drag_current.val is Some(_) {
    return false
  }
  let s : DragSession = { data, source, x, y, hover: 0 }
  drag_retarget(s)
  drag_current.val = Some(s)
  invalidate()
  true
}

///|
/// 指针移动：更新位置并重算落点，返回**落点是否变了**（变了才值得重绘）。
pub fn drag_move(x : Double, y : Double) -> Bool {
  match drag_current.val {
    None => false
    Some(s) => {
      let before = s.hover
      s.x = x
      s.y = y
      drag_retarget(s)
      if s.hover != before {
        invalidate()
        true
      } else {
        false
      }
    }
  }
}

///|
/// 松手：把数据投给落点控件（`on_drop(data, x, y)`），然后结束会话。
/// 返回投放目标是否**接受**（false = 无落点或被目标拒绝）。会话无论接受与否都结束。
pub fn drag_drop(x : Double, y : Double) -> Bool {
  match drag_current.val {
    None => false
    Some(s) => {
      s.x = x
      s.y = y
      drag_retarget(s)
      let data = s.data
      let ok = if s.hover != 0 {
        match drag_root() {
          Some(r) =>
            match r.by_id(s.hover) {
              Some(w) =>
                match w.on_drop {
                  Some(f) => f(data, x, y)
                  None => false
                }
              None => false
            }
          None => false
        }
      } else {
        false
      }
      drag_current.val = None
      invalidate()
      ok
    }
  }
}

///|
/// 取消拖拽（Esc / 指针离开窗口 / 拖源被拆）：不投递，直接结束。
pub fn drag_cancel() -> Unit {
  if drag_current.val is Some(_) {
    drag_current.val = None
    invalidate()
  }
}
