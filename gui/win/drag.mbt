// 系统级拖入（W23a）的平台门面：把 stub.c 的 `wm_dragdnd_*` 包成 MoonBit 侧
// 可用的形态。OLE 的 `IDropTarget` 回调打在**本线程的消息派发**里，与托盘/菜单/
// 热键同制——C 侧压进程级队列，宿主每拍调 `dragdnd_poll` 抽，不做 C→MoonBit 回调。
//
// 效果标志是两段式的：`DragEnter` 由 C 按「认不认得这份格式」先给个承诺值
// （认识给 COPY、不认识给 NONE），之后每次 `DragOver`/`Drop` 读 MoonBit 上一拍
// `dragdnd_set_effect` 写回的值——于是应用侧「这个落点收不收」的判断能反映到
// 系统光标，而不需要在回调里同步问 MoonBit。
//
// `core/drag.mbt` 的门面在此之上建「跨平台后端选择 + 会话派发」，一般调用方不
// 直接碰这一层。GTK/macOS 分支是失败桩（`dragdnd_supported` 恒 false）。

///|
/// 外部拖入后端是否可用（Win32 要 OLE 起得来才算数，探测一次缓存）。
pub fn dragdnd_supported() -> Bool {
  wm_dragdnd_supported() != 0
}

///|
/// 给一扇窗挂上系统投放目标（建窗后调，重复调幂等）。true = 已挂上。
pub fn dragdnd_enable(id : Int64) -> Bool {
  wm_dragdnd_enable(id) != 0
}

///|
/// 撤销挂接（拆窗时 C 侧自动做，这里给显式撤的路；未挂静默）。
pub fn dragdnd_disable(id : Int64) -> Unit {
  wm_dragdnd_disable(id)
}

///|
/// 事件种类：拖入本窗（载荷已可读）。
pub const DRAGDND_ENTER : Int = 0

///|
/// 事件种类：在本窗内移动（坐标变了，载荷不变）。
pub const DRAGDND_OVER : Int = 1

///|
/// 事件种类：离开本窗（载荷已清空）。
pub const DRAGDND_LEAVE : Int = 2

///|
/// 事件种类：松手投递（载荷仍可读，过了这一拍就作废）。
pub const DRAGDND_DROP : Int = 3

///|
/// 效果值：与 Win32 `DROPEFFECT_*` 同值，落点不收。
pub const DRAGDND_NONE : Int = 0

///|
/// 效果值：复制。
pub const DRAGDND_COPY : Int = 1

///|
/// 效果值：移动。
pub const DRAGDND_MOVE : Int = 2

///|
/// 效果值：建立链接。
pub const DRAGDND_LINK : Int = 4

///|
/// 取一条待处理的拖入事件：`(窗口平台 id, 种类, 客户区 x, 客户区 y)`；
/// None = 队列空。
pub fn dragdnd_poll() -> (Int, Int, Int, Int)? {
  let slot = Ref(0)
  let kind = Ref(0)
  let x = Ref(0)
  let y = Ref(0)
  if wm_dragdnd_poll(slot, kind, x, y) != 0 {
    Some((slot.val, kind.val, x.val, y.val))
  } else {
    None
  }
}

///|
/// 读回最近一次「进入/投递」的载荷（`[kind:i32 LE][payload]` 线形状，与
/// `core/drag.mbt` 的 `drag_encode` 同制）。空 Bytes = 当前没有可用载荷。
pub fn dragdnd_payload() -> Bytes {
  let small = Bytes::new(4096)
  let n = wm_dragdnd_payload(small, 4096)
  if n <= 0 {
    Bytes::new(0)
  } else if n < 4096 {
    small[0:n].to_owned()
  } else {
    // 刚好装满首块缓冲：按上限重读一次，长路径表/大段文本不至于被截断
    let big = Bytes::new(65536)
    let m = wm_dragdnd_payload(big, 65536)
    if m <= 0 {
      Bytes::new(0)
    } else {
      big[0:m].to_owned()
    }
  }
}

///|
/// 写回本窗当前应有的效果（`DRAGDND_NONE`/`COPY`/`MOVE`/`LINK`）。下一次
/// `DragOver`/`Drop` 就按它答系统。
pub fn dragdnd_set_effect(id : Int64, effect : Int) -> Unit {
  wm_dragdnd_set_effect(id, effect)
}

///|
/// 读回当前效果（诊断用；-1 = 这扇窗没挂投放目标）。
pub fn dragdnd_effect(id : Int64) -> Int {
  wm_dragdnd_effect(id)
}

///|
/// 在用的投放目标数（探针读回）。
pub fn dragdnd_count() -> Int {
  wm_dragdnd_count()
}
