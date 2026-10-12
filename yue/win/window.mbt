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
  /// 刚失去键盘焦点（原生浮层据此「点外收起」：点网页区时按钮事件被
  /// webview 子窗吃掉，只有焦点转移能告诉我们用户点了别处）
  LostFocus
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
/// 本地时区的「今天」，打包成 `年*10000 + 月*100 + 日`（月/日 1 起始）；
/// 平台给不出时返回 0，由上层决定退路（本层不猜日期）。
pub fn local_date() -> Int64 {
  wm_local_date()
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
    5 => Event::LostFocus
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
/// 改窗口尺寸（原生浮层先开框、量完内容再收到贴合的大小）。
pub fn Window::set_size_pixels(self : Window, width : Int, height : Int) -> Unit {
  if width < 1 || height < 1 {
    return
  }
  wm_window_set_size(self.id, width, height)
}

///|
/// 本窗已挂的原生子件数：>0 就说明这扇窗里有「自绘像素盖不住」的东西，
/// 浮层必须改走真窗口（方案 §4.5）。
pub fn Window::has_child_surfaces(self : Window) -> Bool {
  wm_window_surface_count(self.id) > 0
}

///|
/// 全屏开关（播放器「铺满整屏」是窗口级动作）。切换由窗口管理器完成，
/// 尺寸变化会照常走 allocate 事件，宿主不需要自己算新矩形。
pub fn Window::set_fullscreen(self : Window, on : Bool) -> Unit {
  wm_window_set_fullscreen(self.id, if on { 1 } else { 0 })
}

///|
/// 设绘图区光标形状：0 默认箭头 / 1 手型 / 2 文本 I 形 / 3 横向调整 / 4 纵向调整。
/// 全自绘栈没有原生控件，形状只能由宿主按命中路径下发（见 `Widget::cursor_at`）。
pub fn Window::set_cursor(self : Window, kind : Int) -> Unit {
  wm_set_cursor(self.id, kind)
}

///|
/// 销毁窗口。必须在 Loop 已 `quit` 之后调用（先停派发、再拆对象）。
pub fn Window::close(self : Window) -> Unit {
  wm_close(self.id)
  self.id = -1L
}

///|
/// 把 C 侧写进缓冲的短字符串读回来（空/读不到都给空串）。
fn sys_read(f : (Bytes, Int) -> Int) -> String {
  let buf = Bytes::new(64)
  let n = f(buf, 64)
  if n <= 0 {
    ""
  } else {
    @utf8.decode_lossy(buf[0:n])
  }
}

///|
/// 系统深浅偏好："dark" / "light" / ""（读不出，例如非 GNOME 桌面或键不存在）。
pub fn sys_color_scheme() -> String {
  sys_read(wm_sys_color_scheme)
}

///|
/// 系统主色（`#rrggbb`）；系统没有「主色」概念时给空串。
pub fn sys_accent() -> String {
  sys_read(wm_sys_accent)
}

///|
/// 注册一个全局快捷键（进程级，与窗口无关）。`mods` 用内核 MOD_* 位
/// （1 shift / 2 ctrl / 4 alt / 8 meta）、`vk` 是 Win32 虚拟键码（非
/// Windows 后端忽略）。返回注册 id（>=1）——`None` 表示注册失败：组合键
/// 被系统或别的程序占用（X11 下 XGrabKey 排他；Win32 的 RegisterHotKey
/// 同样会失败）、表满、或后端不支持（占位分支恒 None）。
pub fn register_global_shortcut(mods : Int, vk : Int) -> Int? {
  let id = wm_hotkey_register(mods, vk)
  if id <= 0 {
    None
  } else {
    Some(id)
  }
}

///|
/// 注销全局快捷键（幂等）。
pub fn unregister_global_shortcut(id : Int) -> Unit {
  wm_hotkey_unregister(id)
}

///|
/// 取一个已触发的快捷键 id；没有则 None。宿主每帧/每拍调用（Win32 的
/// WM_HOTKEY 进线程队列，靠泵里抽；Linux 后端同形）。
pub fn poll_global_shortcut() -> Int? {
  let id = wm_hotkey_poll()
  if id <= 0 {
    None
  } else {
    Some(id)
  }
}

///|
/// 弹一个原生模态消息框，阻塞到用户点按钮，返回语义化结果。
/// `kind` 定图标、`buttons` 定按钮集（两者由 `message_box_utype` 合成 Win32
/// `uType`）；`default_index` 是默认聚焦的按钮序号（0 起，越界当 0）。后端不可
/// 用（macOS 占位 / 无显示服务）或内存不足时返回 `Failed`——调用方据
/// `message_box_result_is_affirmative` 判「继续/取消」即可。
pub fn show_message_box(
  title : String,
  text : String,
  kind : MessageBoxKind,
  buttons : MessageBoxButtons,
  default_index? : Int = 0,
) -> MessageBoxResult {
  let utype = message_box_utype(kind, buttons, default_index~)
  message_box_result_of(
    wm_message_box(@utf8.encode(title), @utf8.encode(text), utype),
  )
}

///|
/// 建一个空的原生菜单条，返回其句柄（0 = 后端不支持/表满）。句柄归平台后端
/// 所有，`Menu::apply` 时把它交给窗口；窗口销毁时后端一并释放。
/// 供 `yue/core/menu.mbt` 的翻译层使用——调用方一般用模型层，不直接碰这个。
pub fn menu_bar_new() -> Int {
  wm_menu_bar_new()
}

///|
/// 在父菜单（句柄）下加一个子菜单，返回子菜单句柄（0 = 失败）。
pub fn menu_new_sub(parent : Int, title : String) -> Int {
  wm_menu_new_sub(parent, @utf8.encode(title))
}

///|
/// 在父菜单（句柄）下加一项，返回命令 id（>=1000；分隔线返回 0，失败也 0）。
/// `kind`：0 command / 1 check / 2 radio / 3 separator；`role`：-1 普通、
/// 0..6 见 `yue/core/menu.mbt` 的 `menu_role_id`（Win32 无 role，暂忽略）；
/// `acc` 为加速键描述串（"" 表示无）；`checked` 给复选/单选初值。
pub fn menu_add_item(
  parent : Int,
  label : String,
  kind : Int,
  role : Int,
  acc : String,
  checked : Bool,
) -> Int {
  wm_menu_add_item(
    parent,
    @utf8.encode(label),
    kind,
    role,
    @utf8.encode(acc),
    if checked { 1 } else { 0 },
  )
}

///|
/// 把菜单条（句柄，0 = 拆掉当前菜单）挂到窗口。
pub fn menu_apply(id : Int64, bar : Int) -> Unit {
  wm_menu_apply(id, bar)
}

///|
/// 取一个已触发的菜单命令 id；没有则 None。宿主每帧/每拍调用（Win32 的
/// WM_COMMAND 进窗口消息队列，靠泵里抽）。
pub fn poll_menu_command() -> Int? {
  let cmd = wm_menu_poll()
  if cmd <= 0 {
    None
  } else {
    Some(cmd)
  }
}
