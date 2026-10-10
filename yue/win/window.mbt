// 平台窗口后端（Linux = GTK3）：窗口句柄、事件取用、上屏与循环泵。
// 循环归 MoonBit——本文件只给 `pump`/`wait`/`wake` 三个动作，等多久由
// `yue/core` 的 Loop::wait_budget 决定；窗口上的像素来自调用方交来的
// RGBA 缓冲（`yue/render` 的 Bitmap.data），因此离屏快照与上屏同源。

///|
pub(all) enum Event {
  NoEvent
  NeedsDraw
  Resized
  Closing
  /// 有输入事件待取（用 take_input 排空）
  Input
}

///|
pub(all) struct Window {
  mut id : Int64
  mut width : Int
  mut height : Int
}

///|
/// 后端可用性探测：无显示服务时返回 false，调用方据此降级（CI 与远程 shell 即此形态）。
pub fn init_backend() -> Bool {
  wm_init() == 1
}

///|
/// 单调时钟毫秒读数，供 Loop 的定时器与 `wait` 预算使用。
pub fn now_ms() -> Int64 {
  wm_now_ms()
}

///|
/// 跑掉平台已就绪的事件，不阻塞。
pub fn pump() -> Unit {
  wm_pump()
}

///|
/// 等平台事件：`timeout_ms` 传 -1 表示可无限等（无待办时），此时只能靠
/// 事件到达或 `wake` 回来；返回 true 表示确实有东西被跑掉了。
pub fn wait(timeout_ms : Int) -> Bool {
  wm_wait(timeout_ms) == 1
}

///|
/// 跨线程唤醒位（G5 的输入法回调与后续 async 接入都从这里叫醒等待中的循环）。
pub fn wake() -> Unit {
  wm_wakeup()
}

///|
/// 建窗并设定初始尺寸；后端不可用或窗口槽耗尽返回 None。
pub fn Window::new(width : Int, height : Int, title : String) -> Window? {
  let w = if width < 1 { 1 } else { width }
  let h = if height < 1 { 1 } else { height }
  let id = wm_window_new(w, h, @utf8.encode(title))
  if id == 0L {
    None
  } else {
    Some({ id, width: w, height: h })
  }
}

///|
pub fn Window::show(self : Window) -> Unit {
  wm_show(self.id)
}

///|
/// 取一个待处理事件（消费式，一次一个）；尺寸变化时同步更新 `width`/`height`。
pub fn Window::poll_event(self : Window) -> Event {
  match wm_event(self.id) {
    3 => Event::Closing
    2 => {
      let ow = Ref(0)
      let oh = Ref(0)
      wm_size(self.id, ow, oh)
      self.width = ow.val
      self.height = oh.val
      Event::Resized
    }
    1 => Event::NeedsDraw
    4 => Event::Input
    _ => Event::NoEvent
  }
}

///|
/// 当前宽高（尺寸事件之外的兜底读取）。
pub fn Window::size(self : Window) -> (Int, Int) {
  let ow = Ref(self.width)
  let oh = Ref(self.height)
  wm_size(self.id, ow, oh)
  (ow.val, oh.val)
}

///|
/// 把 RGBA 缓冲贴到窗口。缓冲必须是 `width*height*4` 字节、逐行无填充，
/// 即 `yue/render` 的 Bitmap.data；字节序换算是后端的事。
pub fn Window::present(
  self : Window,
  rgba : FixedArray[Byte],
  width : Int,
  height : Int,
) -> Unit {
  wm_present(self.id, rgba, width, height)
}

///|
/// 一条输入事件。`code`：0 键按下 1 键释放 2 按钮按下 3 按钮释放 4 指针移动
/// 5 滚轮；键事件用 `keysym`/`mods`，指针与滚轮用 `x`/`y`（按钮号在
/// `button`，滚轮方向在 `axis`）。
pub(all) struct InputEvent {
  code : Int
  keysym : Int
  mods : Int
  x : Int
  y : Int
  button : Int
  axis : Int
}

///|
/// 待取的输入事件条数。
pub fn Window::pending_input(self : Window) -> Int {
  wm_pending_events(self.id)
}

///|
/// 取一条输入事件；没有则 None。字段取自刚取出的那一条（后端逐字段读）。
pub fn Window::take_input(self : Window) -> InputEvent? {
  let code = wm_take_event(self.id)
  if code < 0 {
    None
  } else {
    Some({
      code,
      keysym: wm_ev_keysym(self.id),
      mods: wm_ev_mods(self.id),
      x: wm_ev_x(self.id),
      y: wm_ev_y(self.id),
      button: wm_ev_button(self.id),
      axis: wm_ev_axis(self.id),
    })
  }
}

///|
/// 把焦点要给自己（Tab/点击后调用；无焦点时按键不会回来）。
pub fn Window::request_focus(self : Window) -> Unit {
  wm_request_focus(self.id)
}

///|
/// 销毁窗口。必须在 Loop 已 `quit` 之后调用（先停派发、再拆对象）。
pub fn Window::close(self : Window) -> Unit {
  wm_close(self.id)
  self.id = -1L
}
