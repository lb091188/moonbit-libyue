// 拖放门面（W21c）：数据模型 `DragData` + 控件钩子（拖源 `set_draggable` / 投放
// `set_on_drop`）+ **应用内**拖拽会话。
//
// 本批的口径（写清以免被当成「没做完」）：
// - **已做**：同一进程、同一控件树内的拖放——拖源按住拖出内容、指针移动时实时
//   算出落点、松手投给命中的投放目标。新栈全自绘，命中与绘制都在自己手里，这条
//   路不需要任何平台接口，**三平台同构**。
// - **已做（Windows，W23a）**：**系统级拖入**——从资源管理器/编辑器把文件或文本
//   拖进窗口，落到同一个会话里（每拍 `drag_external_pump`，见本文件尾）。落点命中、
//   悬停高亮、`accept` 判据全部复用应用内那一套，调用方的 `@ui.drop_target` 不用改。
// - **已做（Linux/GTK，W23a-b 平台批）**：系统级拖入/拖出同两条门面——GTK 后端
//   把 `drag-motion`/`drag-data-received` 等信号喂进同一条会话链、`gtk_drag_begin`
//   起拖出（阻塞语义同 Windows）；macOS 的 `NSDraggingSource` 仍随后续批。
// - **已做（Windows，W23b）**：**系统级拖出**——`drag_external_send` 把 `Text`/`Paths`
//   交给 OLE 拖放（见本文件尾的「系统级拖出」节）。`drag_source(external=true)` 在
//   过阈值那一刻起这趟；后端不支持或种类没有系统级形态时自动回落到应用内会话。
// - 参照面是旧栈的 `yue/view.mbt`（`DataKind` / `DragData` / `register_dragged_types`
//   / `handle_drag_enter`/`handle_drag_update`/`handle_drop`/`on_drag_leave`）。
//   本批把「拖入三回调」收成一个 `on_drop`（自绘档不需要 enter/update/leave 三件：
//   悬停高亮靠读 `drag_hover()`，见下），编号与旧栈逐值相同。系统级拖入要问
//   「这个落点收不收」又不触发投递，故另开 `drag_accept` 查询钩子（见下）。
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
/// 正在跑外部拖入的窗口（平台窗口 id；0 = 没有）。外部拖入与应用内拖拽共用同
/// 一个会话单例，这条标志用来判断「会话是谁的」，避免互相劫持。
let drag_ext_window : Ref[Int] = Ref(0)

///|
/// 外部拖入的落点树（按事件所属窗找到那扇窗的根）；None = 沿用宿主 provider。
let drag_ext_root : Ref[Widget?] = Ref(None)

///|
/// MoonBit 侧最近一次答给系统的外部拖入效果（1 = 复制、0 = 不收）。
let drag_ext_effect : Ref[Int] = Ref(0)

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
  match drag_ext_root.val {
    // 外部拖入按事件所属窗定位落点树（多窗时每窗一棵树）
    Some(w) => Some(w)
    None => (drag_root_slot.val)()
  }
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

///|
/// 装「这份数据收不收」的查询钩子（悬停期问，不触发投递）。`@ui.drop_target`
/// 的 `accept` 参数会填这里；`on_drop` 那条才是真正投递。
pub fn Widget::set_drag_accept(self : Widget, f : (DragData) -> Bool) -> Unit {
  self.drag_accept = Some(f)
}

///|
/// 取消查询钩子（回到「是投放目标就收」）。
pub fn Widget::clear_drag_accept(self : Widget) -> Unit {
  self.drag_accept = None
}

///|
/// 这份数据落在我身上收不收（悬停查询）。
pub fn Widget::drag_wants(self : Widget, data : DragData) -> Bool {
  match self.drag_accept {
    Some(f) => f(data)
    None => true
  }
}

///|
/// 系统级拖入是否可用（运行时探测：Windows 要 OLE 起得来、Linux 要有显示服务，
/// 其余后端恒 false）。不可用时下面的挂载与抽取全部静默失败，应用内拖放照常。
pub fn drag_external_supported() -> Bool {
  @win.dragdnd_supported()
}

///|
/// 给一扇窗挂上系统投放目标（`App` 建窗时自动调；重复调幂等）。true = 已挂上。
pub fn drag_external_enable(id : Int64) -> Bool {
  @win.dragdnd_enable(id)
}

///|
/// 撤销挂接（拆窗时 C 侧自动做，这里给显式撤的路）。
pub fn drag_external_disable(id : Int64) -> Unit {
  @win.dragdnd_disable(id)
}

///|
/// 按平台窗口 id 找到那扇窗的根控件（找不到给 None，落点退回宿主 provider）。
fn drag_window_root_of(slot : Int) -> Widget? {
  let mut found : Widget? = None
  for a in host_windows() {
    if a.window.id.to_int() == slot {
      found = Some(a.root)
    }
  }
  found
}

///|
/// 把「当前落点收不收」写回系统（决定拖拽光标）。收给 COPY（1），不收给
/// NONE（0）。悬停答值仍只有「复制/不收」两档——要答 MOVE/LINK 得把 OLE 的
/// `grfKeyState`（Shift/Alt 修饰位）一起转发上来，`wm_dragdnd_poll` 目前只给
/// 槽号/种类/坐标，那条随后续批。写回的值同时记在 MoonBit 侧一份
/// （`drag_external_effect()` 读回，无头测试与诊断用——后端没挂上时 ffi 那次写
/// 是静默丢弃的）。
fn drag_external_answer(slot : Int, data : DragData) -> Unit {
  let ok = match drag_current.val {
    None => false
    Some(s) =>
      if s.hover == 0 {
        false
      } else {
        match drag_root() {
          None => false
          Some(r) =>
            match r.by_id(s.hover) {
              Some(w) => w.drag_wants(data)
              None => false
            }
        }
      }
  }
  let effect = if ok { @win.DRAGDND_COPY } else { @win.DRAGDND_NONE }
  drag_ext_effect.val = effect
  @win.dragdnd_set_effect(slot.to_int64(), effect)
}

///|
/// 当前效果标志（1 = 复制、0 = 落点不收；没有外部拖入在跑时为 0）。
pub fn drag_external_effect() -> Int {
  drag_ext_effect.val
}

///|
/// 一条外部拖入事件喂给会话。`data` 是「进入/移动」时已经解码好的载荷（认不出
/// 的格式给 None，这一条直接跳过）；离开/投递不看它。
/// 进入/移动走「开会话或更新落点 → 答效果」，离开/投递结束时才会话与落点树一起
/// 收掉。落点命中、悬停高亮、松手投递复用应用内那一条链。
fn drag_external_feed(
  slot : Int,
  kind : Int,
  x : Double,
  y : Double,
  data : DragData?,
) -> Unit {
  if kind == @win.DRAGDND_LEAVE || kind == @win.DRAGDND_DROP {
    if drag_ext_window.val == slot {
      if kind == @win.DRAGDND_DROP {
        // 载荷在 C 侧 Drop 返回前仍可读，会话里的数据是进入时就取好的那份
        let _ = drag_drop(x, y)
      } else {
        drag_cancel()
      }
      drag_ext_window.val = 0
      drag_ext_root.val = None
      drag_ext_effect.val = 0
    }
    return ()
  }
  // 别的窗正在跑外部拖入：不抢它的会话
  if drag_ext_window.val != 0 && drag_ext_window.val != slot {
    return ()
  }
  // 应用内拖拽正在跑：外部事件不劫持（两条会话同一时刻只能有一条）
  if drag_ext_window.val == 0 && drag_current.val is Some(_) {
    return ()
  }
  match data {
    None =>
      // 认不出的格式：不开会话，进入这一拍直接把效果答成 NONE（光标显示禁止）
      if kind == @win.DRAGDND_ENTER {
        @win.dragdnd_set_effect(slot.to_int64(), @win.DRAGDND_NONE)
      }
    Some(d) => {
      if drag_ext_window.val == 0 {
        drag_ext_window.val = slot
        drag_ext_root.val = drag_window_root_of(slot)
      }
      if !drag_begin(d, 0, x, y) {
        let _ = drag_move(x, y)
      }
      drag_external_answer(slot, d)
    }
  }
}

///|
/// 每拍抽干外部拖入队列并喂给会话（宿主 `App::step` 每拍调）。返回本轮是否抽到
/// 事件。
pub fn drag_external_pump() -> Bool {
  if !@win.dragdnd_supported() {
    return false
  }
  let mut got = false
  let mut more = true
  while more {
    match @win.dragdnd_poll() {
      None => more = false
      Some((slot, kind, x, y)) => {
        got = true
        let data = if kind == @win.DRAGDND_LEAVE || kind == @win.DRAGDND_DROP {
          None
        } else {
          drag_decode(@win.dragdnd_payload())
        }
        drag_external_feed(slot, kind, x.to_double(), y.to_double(), data)
      }
    }
  }
  got
}

///|
/// 拖出这趟最终答回来的效果（编号与 Win32 `DROPEFFECT_*` 同值）。落点不收或按
/// Esc 取消都是 `Rejected`——取消不算错误，见 `drag_external_send`。
pub(all) enum DragEffect {
  Rejected
  Copy
  Move
  Link
}

///|
/// 效果 → 标志位（`Copy`=1、`Move`=2、`Link`=4，与 `@win.DRAGDND_*` 同值）。
pub fn DragEffect::flag(self : DragEffect) -> Int {
  match self {
    Rejected => @win.DRAGDND_NONE
    Copy => @win.DRAGDND_COPY
    Move => @win.DRAGDND_MOVE
    Link => @win.DRAGDND_LINK
  }
}

///|
/// 标志位 → 效果（认不出的组合按「没成交」处理，不猜）。
pub fn drag_effect_of_flag(flag : Int) -> DragEffect {
  match flag {
    1 => Copy
    2 => Move
    4 => Link
    _ => Rejected
  }
}

///|
/// 拖出失败的原因。
pub(all) enum DragError {
  /// 本机后端没有这条能力，或这份数据没有系统级形态（`Html`/`Img`）
  Unsupported
  /// 后端接了但这趟没走成（没有活动窗口、OLE 起不来、载荷装不出）
  Failed(String)
}

///|
/// 这份数据有没有系统级形态：`Text` 走 `CF_UNICODETEXT`、`Paths` 走 `CF_HDROP`
/// （相对路径由后端绝对化）。`Html`/`Img` 本批不给系统级形态——`CF_HTML` 有自己的
/// 源标记格式、位图要 `IDropTarget` 侧的 `METAFILEPICT`/`Bitmap`，都随后续批。
pub fn drag_data_has_system_form(data : DragData) -> Bool {
  match data {
    Text(_) | Paths(_) => true
    Html(_) | Img(_) => false
  }
}

///|
/// 系统级拖出是否可用（运行时探测，不含数据种类判断）。不可用时
/// `drag_external_send` 直接给 `Err(Unsupported)`，`@ui.drag_source` 会回落到
/// 应用内会话——也就是说这条返回 false 时，应用内拖放完全不受影响。
pub fn drag_external_send_supported() -> Bool {
  @win.dragdnd_supported()
}

///|
/// 起一趟系统级**拖出**（Windows W23b）：把数据交给 OLE 拖放，对方程序（资源管理
/// 器、桌面、编辑器）拿到的是标准的复制/移动/链接语义，效果由按住的修饰键定夺。
/// 返回 `Ok(效果)`——`Ok(Rejected)` 表示用户取消或松手处没有成交点；`Err` 表示这趟
/// 根本没起来。
///
/// 用法约束（不是 bug）：**必须在鼠标键仍按下时调用**，也就是拖拽过阈值那一刻；
/// 按钮抬起后再调系统不认。这一支**阻塞**到松手或取消才返回，期间本窗的事件循环
/// 由系统代跑，本窗自己的 `drop_target` 仍能收这份拖出的数据（拖回自己窗口成立），
/// 但**拖拽途中没有应用内实时高亮**——那是应用内会话才有的待遇，两条会话同一时刻
/// 只能跑一条。
pub fn drag_external_send(data : DragData) -> Result[DragEffect, DragError] {
  if !@win.dragdnd_supported() {
    Err(Unsupported)
  } else if !drag_data_has_system_form(data) {
    Err(Unsupported)
  } else {
    match host_active() {
      None => Err(Failed("当前没有活动窗口"))
      Some(app) =>
        match @win.dragdnd_send(
          app.window.id,
          drag_encode(data),
          @win.DRAGDND_COPY | @win.DRAGDND_MOVE | @win.DRAGDND_LINK,
        ) {
          None => Err(Failed("系统未接这趟拖出"))
          Some(flag) => Ok(drag_effect_of_flag(flag))
        }
    }
  }
}
