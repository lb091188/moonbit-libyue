// 事件系统：对照 libyue events_and_delegates 指南与 Event/MouseEvent/KeyEvent/
// EventType/KeyboardCode/KeyboardModifier 结构体页。
// Mouse/KeyEvent 经 shim 标量展开（invoke(closure, 字段...)）进入 MoonBit，
// 在蹦床里就地组装成不可变 struct；modifiers 已在 shim 归一化为跨平台一致位。

///|
/// 事件类别（对照 nu::EventType，随注册的信号确定）。
pub(all) enum EventType {
  MouseDown
  MouseUp
  MouseMove
  MouseEnter
  MouseLeave
  KeyDown
  KeyUp
  Unknown
}

///|
/// 鼠标事件（对照 nu::MouseEvent；仅在回调期内有效，勿长期持有）。
/// button：1=左 2=右 3=中（libyue 统一语义）。view_* 相对视图，window_* 相对窗口。
pub(all) struct MouseEvent {
  kind : EventType
  button : Int
  view_x : Double
  view_y : Double
  window_x : Double
  window_y : Double
  modifiers : Int
  timestamp : Int
}

///|
/// 键盘事件（对照 nu::KeyEvent；code 为 KeyboardCode，见 VKEY_* 常量）。
pub(all) struct KeyEvent {
  kind : EventType
  code : Int
  modifiers : Int
  timestamp : Int
}

///|
/// 修饰键位（KeyboardModifier，shim 已归一化，跨平台一致）。
pub const KEY_MOD_SHIFT : Int = 1

///|
pub const KEY_MOD_CTRL : Int = 2

///|
pub const KEY_MOD_ALT : Int = 4

///|
pub const KEY_MOD_META : Int = 8

///|
fn mouse_event(
  kind : EventType,
  button : Int,
  vx : Double,
  vy : Double,
  wx : Double,
  wy : Double,
  mods : Int,
  ts : Int,
) -> MouseEvent {
  { kind, button, view_x: vx, view_y: vy, window_x: wx, window_y: wy, modifiers: mods, timestamp: ts }
}

///|
fn key_event(kind : EventType, code : Int, mods : Int, ts : Int) -> KeyEvent {
  { kind, code, modifiers: mods, timestamp: ts }
}

///|
pub fn MouseEvent::has_mod(self : MouseEvent, bit : Int) -> Bool {
  (self.modifiers & bit) != 0
}

///|
pub fn KeyEvent::has_mod(self : KeyEvent, bit : Int) -> Bool {
  (self.modifiers & bit) != 0
}

/// ---------- KeyboardCode 常量 ----------
/// 数值取自 libyue Linux/GTK 表（keyboard_codes_gtk.h，即 GDK 键值）。
/// Windows/macOS 的取值表不同，跨平台常量对齐在对应平台目标里做；
/// 字母/数字键恰好等于其 ASCII 大写码（VKEY_A='A'），可直接比较。

///|
pub const VKEY_UNKNOWN : Int = 0

///|
pub const VKEY_BACK : Int = 0xff08

///|
pub const VKEY_TAB : Int = 0xff09

///|
pub const VKEY_CLEAR : Int = 0xff0b

///|
pub const VKEY_RETURN : Int = 0xff0d

///|
pub const VKEY_SHIFT : Int = 0xffe1

///|
pub const VKEY_CONTROL : Int = 0xffe3

///|
pub const VKEY_MENU : Int = 0xff67

///|
pub const VKEY_PAUSE : Int = 0xff13

///|
pub const VKEY_CAPITAL : Int = 0xffe5

///|
pub const VKEY_ESCAPE : Int = 0xff1b

///|
pub const VKEY_SPACE : Int = 0x020

///|
pub const VKEY_PRIOR : Int = 0xff55

///|
pub const VKEY_NEXT : Int = 0xff56

///|
pub const VKEY_END : Int = 0xff57

///|
pub const VKEY_HOME : Int = 0xff50

///|
pub const VKEY_LEFT : Int = 0xff51

///|
pub const VKEY_UP : Int = 0xff52

///|
pub const VKEY_RIGHT : Int = 0xff53

///|
pub const VKEY_DOWN : Int = 0xff54

///|
pub const VKEY_SELECT : Int = 0xff60

///|
pub const VKEY_PRINT : Int = 0xff61

///|
pub const VKEY_EXECUTE : Int = 0xff62

///|
pub const VKEY_SNAPSHOT : Int = 0xfd1d

///|
pub const VKEY_INSERT : Int = 0xff63

///|
pub const VKEY_DELETE : Int = 0xffff

///|
pub const VKEY_HELP : Int = 0xff6a

///|
pub const VKEY_LWIN : Int = 0xffe7

///|
pub const VKEY_RWIN : Int = 0xffe8

///|
pub const VKEY_APPS : Int = 0xff67

///|
pub const VKEY_NUMPAD0 : Int = 0xffb0

///|
pub const VKEY_NUMPAD1 : Int = 0xffb1

///|
pub const VKEY_NUMPAD2 : Int = 0xffb2

///|
pub const VKEY_NUMPAD3 : Int = 0xffb3

///|
pub const VKEY_NUMPAD4 : Int = 0xffb4

///|
pub const VKEY_NUMPAD5 : Int = 0xffb5

///|
pub const VKEY_NUMPAD6 : Int = 0xffb6

///|
pub const VKEY_NUMPAD7 : Int = 0xffb7

///|
pub const VKEY_NUMPAD8 : Int = 0xffb8

///|
pub const VKEY_NUMPAD9 : Int = 0xffb9

///|
pub const VKEY_MULTIPLY : Int = 0xffaa

///|
pub const VKEY_ADD : Int = 0xffab

///|
pub const VKEY_SUBTRACT : Int = 0xffad

///|
pub const VKEY_DECIMAL : Int = 0xffae

///|
pub const VKEY_DIVIDE : Int = 0xffaf

///|
pub const VKEY_F1 : Int = 0xffbe

///|
pub const VKEY_F2 : Int = 0xffbf

///|
pub const VKEY_F3 : Int = 0xffc0

///|
pub const VKEY_F4 : Int = 0xffc1

///|
pub const VKEY_F5 : Int = 0xffc2

///|
pub const VKEY_F6 : Int = 0xffc3

///|
pub const VKEY_F7 : Int = 0xffc4

///|
pub const VKEY_F8 : Int = 0xffc5

///|
pub const VKEY_F9 : Int = 0xffc6

///|
pub const VKEY_F10 : Int = 0xffc7

///|
pub const VKEY_F11 : Int = 0xffc8

///|
pub const VKEY_F12 : Int = 0xffc9

///|
pub const VKEY_NUMLOCK : Int = 0xff7f

///|
pub const VKEY_SCROLL : Int = 0xff14

///|
pub const VKEY_LSHIFT : Int = 0xffe1

///|
pub const VKEY_RSHIFT : Int = 0xffe2

///|
pub const VKEY_LCONTROL : Int = 0xffe3

///|
pub const VKEY_RCONTROL : Int = 0xffe4

///|
pub const VKEY_LMENU : Int = 0xff67

///|
pub const VKEY_RMENU : Int = 0xff67

///|
pub const VKEY_OEM_1 : Int = 0x03b

///|
pub const VKEY_OEM_PLUS : Int = 0x02b

///|
pub const VKEY_OEM_COMMA : Int = 0x02c

///|
pub const VKEY_OEM_MINUS : Int = 0x02d

///|
pub const VKEY_OEM_PERIOD : Int = 0x02e

///|
pub const VKEY_OEM_2 : Int = 0x02f

///|
pub const VKEY_OEM_3 : Int = 0x07e

///|
pub const VKEY_OEM_4 : Int = 0x05b

///|
pub const VKEY_OEM_5 : Int = 0x05c

///|
pub const VKEY_OEM_6 : Int = 0x05d

///|
pub const VKEY_OEM_7 : Int = 0x027

/// ---------- 事件注册（Responder 信号，全部 View/Window 可用） ----------

///|
/// 鼠标按下：返回 true 表示事件已处理（阻止默认行为）。
impl ViewLike with on_mouse_down(self, callback : (MouseEvent) -> Bool) -> Unit {
  let wrapped : (Int, Double, Double, Double, Double, Int, Int) -> Int =
    fn(button, vx, vy, wx, wy, mods, ts) {
      if callback(mouse_event(MouseDown, button, vx, vy, wx, wy, mods, ts)) {
        1
      } else {
        0
      }
    }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_mouse_down(self.view(), fn(f, b, vx, vy, wx, wy, m, t) { f(b, vx, vy, wx, wy, m, t) }, wrapped)
}

///|
/// 鼠标抬起：返回 true 表示事件已处理。
impl ViewLike with on_mouse_up(self, callback : (MouseEvent) -> Bool) -> Unit {
  let wrapped : (Int, Double, Double, Double, Double, Int, Int) -> Int =
    fn(button, vx, vy, wx, wy, mods, ts) {
      if callback(mouse_event(MouseUp, button, vx, vy, wx, wy, mods, ts)) {
        1
      } else {
        0
      }
    }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_mouse_up(self.view(), fn(f, b, vx, vy, wx, wy, m, t) { f(b, vx, vy, wx, wy, m, t) }, wrapped)
}

///|
/// 鼠标在视图内移动（高频，回调保持轻量）。
impl ViewLike with on_mouse_move(self, callback : (MouseEvent) -> Unit) -> Unit {
  let wrapped : (Int, Double, Double, Double, Double, Int, Int) -> Unit =
    fn(button, vx, vy, wx, wy, mods, ts) {
      callback(mouse_event(MouseMove, button, vx, vy, wx, wy, mods, ts))
    }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_mouse_move(self.view(), fn(f, b, vx, vy, wx, wy, m, t) { f(b, vx, vy, wx, wy, m, t) }, wrapped)
}

///|
/// 鼠标进入视图。
impl ViewLike with on_mouse_enter(self, callback : (MouseEvent) -> Unit) -> Unit {
  let wrapped : (Int, Double, Double, Double, Double, Int, Int) -> Unit =
    fn(button, vx, vy, wx, wy, mods, ts) {
      callback(mouse_event(MouseEnter, button, vx, vy, wx, wy, mods, ts))
    }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_mouse_enter(self.view(), fn(f, b, vx, vy, wx, wy, m, t) { f(b, vx, vy, wx, wy, m, t) }, wrapped)
}

///|
/// 鼠标离开视图。
impl ViewLike with on_mouse_leave(self, callback : (MouseEvent) -> Unit) -> Unit {
  let wrapped : (Int, Double, Double, Double, Double, Int, Int) -> Unit =
    fn(button, vx, vy, wx, wy, mods, ts) {
      callback(mouse_event(MouseLeave, button, vx, vy, wx, wy, mods, ts))
    }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_mouse_leave(self.view(), fn(f, b, vx, vy, wx, wy, m, t) { f(b, vx, vy, wx, wy, m, t) }, wrapped)
}

///|
/// 键盘按下：返回 true 表示事件已处理（阻止默认行为）。
impl ViewLike with on_key_down(self, callback : (KeyEvent) -> Bool) -> Unit {
  let wrapped : (Int, Int, Int) -> Int =
    fn(code, mods, ts) { if callback(key_event(KeyDown, code, mods, ts)) { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_key_down(self.view(), fn(f, code, mods, ts) { f(code, mods, ts) }, wrapped)
}

///|
/// 键盘抬起：返回 true 表示事件已处理。
impl ViewLike with on_key_up(self, callback : (KeyEvent) -> Bool) -> Unit {
  let wrapped : (Int, Int, Int) -> Int =
    fn(code, mods, ts) { if callback(key_event(KeyUp, code, mods, ts)) { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_key_up(self.view(), fn(f, code, mods, ts) { f(code, mods, ts) }, wrapped)
}

/// ---------- 鼠标捕获（Responder） ----------

///|
/// 捕获鼠标：捕获期间 move/up 持续送达本视图（拖拽选区等场景）。
impl ViewLike with set_capture(self) -> Unit {
  ffi_view_set_capture(self.view())
}

///|
impl ViewLike with release_capture(self) -> Unit {
  ffi_view_release_capture(self.view())
}

///|
impl ViewLike with has_capture(self) -> Bool {
  ffi_view_has_capture(self.view()) == 1
}

///|
/// 捕获被系统/他人夺走时回调。
impl ViewLike with on_capture_lost(self, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_view_on_capture_lost(self.view(), fn(f) { f() }, callback)
}

///|
/// 视图尺寸变化（首次布局、窗口缩放等时机）。
impl ViewLike with on_size_changed(self, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_view_on_size_changed(self.view(), fn(f) { f() }, callback)
}

///|
/// yoga 计算布局的文本转储（调试布局用）。
impl ViewLike with get_computed_layout(self) -> String {
  @utf8.decode_lossy(ffi_view_get_computed_layout(self.view()))
}

/// ---------- Event 静态查询 ----------

///|
/// 全局鼠标位置（屏幕坐标，无需事件即可查询，弹窗定位用）。
pub fn mouse_location() -> (Double, Double) {
  (ffi_mouse_location_x(), ffi_mouse_location_y())
}

///|
pub fn shift_pressed() -> Bool {
  ffi_is_shift_pressed() == 1
}

///|
pub fn control_pressed() -> Bool {
  ffi_is_control_pressed() == 1
}

///|
pub fn alt_pressed() -> Bool {
  ffi_is_alt_pressed() == 1
}

///|
pub fn meta_pressed() -> Bool {
  ffi_is_meta_pressed() == 1
}

/// ---------- 双击/多击计数 ----------

///|
/// 连击检测器：libyue 的 MouseEvent 不带 click_count，用「同键 + 时间窗 +
/// 距离窗」把连续的 mouse_down 聚合成点击计数（1=单击 2=双击 3=三击…）。
/// 默认窗口取 GTK 惯例：400ms / 5px（gtk-double-click-time / -distance）。
pub(all) struct ClickTracker {
  window_ms : Int
  distance_px : Double
  mut last_button : Int
  mut last_time : Int
  mut last_x : Double
  mut last_y : Double
  mut count : Int
}

///|
pub fn ClickTracker::new() -> ClickTracker {
  ClickTracker::new_with(400, 5.0)
}

///|
pub fn ClickTracker::new_with(window_ms : Int, distance_px : Double) -> ClickTracker {
  {
    window_ms,
    distance_px,
    last_button: -1,
    last_time: 0,
    last_x: 0.0,
    last_y: 0.0,
    count: 0,
  }
}

///|
/// 喂入一次 mouse_down，返回本次是连续第几次点击。
pub fn ClickTracker::feed(self : ClickTracker, e : MouseEvent) -> Int {
  let dx = e.view_x - self.last_x
  let dy = e.view_y - self.last_y
  let consecutive = e.button == self.last_button &&
    e.timestamp - self.last_time <= self.window_ms &&
    dx * dx + dy * dy <= self.distance_px * self.distance_px
  self.last_button = e.button
  self.last_time = e.timestamp
  self.last_x = e.view_x
  self.last_y = e.view_y
  self.count = if consecutive { self.count + 1 } else { 1 }
  self.count
}
