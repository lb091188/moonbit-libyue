///|
/// 桌面通知（W21a）的平台门面：把 stub.c 的 `wm_notify_*`（Win32 托盘气泡
/// `NIF_INFO`）包成 MoonBit 侧可用的形态。通知 id 就是所属托盘槽号（1 起，
/// 0 = 失败）——Windows 的通知挂在托盘图标上，故与 W20c 共用槽表。
///
/// 回调/事件不涉及：气泡只弹不点（点击语义未定义，后端对通知槽不入托盘事件
/// 队列）。跨平台门面在 `yue/core/notify.mbt`，一般调用方不直接碰这一层。

///|
/// 通知后端是否可用（Win32 上即「托盘消息窗建得出否」；GTK/占位分支恒 false
/// ——Linux 的通知走 D-Bus，不经这一层）。
pub fn notify_supported() -> Bool {
  wm_notify_supported() != 0
}

///|
/// 通知种类：0 = 信息、1 = 警告、2 = 错误（映射到 Win32 的 NIIF_*）。
pub const NOTIFY_INFO : Int = 0

///|
pub const NOTIFY_WARNING : Int = 1

///|
pub const NOTIFY_ERROR : Int = 2

///|
/// 弹一张气泡通知：`icon_slot` 是 W20f 图标句柄（0 = 用状态图标），返回通知
/// id（>=1）或 0（表满 / 失败）。
pub fn notify_send(
  icon_slot : Int,
  title : String,
  text : String,
  kind : Int,
) -> Int {
  wm_notify_send(icon_slot, @utf8.encode(title), @utf8.encode(text), kind)
}

///|
/// 更新（替换）一张气泡通知（同 id 重发 `NIF_INFO`，系统即替换原气泡）。
pub fn notify_update(
  id : Int,
  title : String,
  text : String,
  kind : Int,
) -> Bool {
  wm_notify_update(id, @utf8.encode(title), @utf8.encode(text), kind) != 0
}

///|
/// 收起气泡并摘掉该通知的托盘项（幂等）。
pub fn notify_close(id : Int) -> Unit {
  wm_notify_close(id)
}

///|
/// 在用通知数（探针/测试读回用；不含普通托盘图标）。
pub fn notify_count() -> Int {
  wm_notify_count()
}

///|
/// 读回某通知当前的气泡标题（空串 = 读不到 / 无此项；非 Windows 后端恒空）。
pub fn notify_title(id : Int) -> String {
  let buf = Bytes::new(256)
  let n = wm_notify_title(id, buf, 256)
  if n <= 0 {
    ""
  } else {
    @utf8.decode_lossy(buf[0:n])
  }
}
