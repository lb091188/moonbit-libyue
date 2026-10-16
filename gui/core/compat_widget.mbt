// G9 Batch 2 过渡兼容层（四）：控件宿主/声明式/浮层/拖放/输入映射与 App 主体
// 已出成 `widget` 子包，本文件把原先住在 core 的公开名转发一层，`@core.*`
// 调用点在迁移期不改写；新代码直接 `import "NoahLiu/native-gui/widget"`。
// 全量替换完成后整文件删除（TODO §1 G9）。事件/拖放枚举的变体（`Down` 一类）
// 别名转不出来（别名不导出构造子，实测），调用点已改 `@widget.PointerKind::Down`
// 全限定形态。

///|
pub type App = @widget.App
pub type Widget = @widget.Widget
pub type Node = @widget.Node
pub type OverlayHost = @widget.OverlayHost
pub type OverlayItem = @widget.OverlayItem
pub type DragData = @widget.DragData
pub type DataKind = @widget.DataKind
pub type DragSession = @widget.DragSession
pub type DragEffect = @widget.DragEffect
pub type DragError = @widget.DragError
pub type ImeRoute = @widget.ImeRoute
pub type RawEvent = @widget.RawEvent
pub type PointerKind = @widget.PointerKind
pub type PointerEvent = @widget.PointerEvent
pub type KeyEvent = @widget.KeyEvent
pub type ScrollEvent = @widget.ScrollEvent
pub type Event = @win.Event

///|
pub const CURSOR_DEFAULT : Int = @widget.CURSOR_DEFAULT
pub const CURSOR_HAND : Int = @widget.CURSOR_HAND
pub const CURSOR_TEXT : Int = @widget.CURSOR_TEXT
pub const CURSOR_RESIZE_H : Int = @widget.CURSOR_RESIZE_H
pub const CURSOR_RESIZE_V : Int = @widget.CURSOR_RESIZE_V

///|
/// 跨模块测试通道（假宿主）。
pub fn fake_session(id : Int, wid : Int, primary : Bool, w : Int, h : Int) -> @shell.Session {
  @shell.fake_session(id, wid, primary, w, h)
}

///|
/// 跨模块测试通道：给一扇（假）壳层窗挂上空的根控件与浮层宿主。
pub fn test_app(s : @shell.Session) -> App {
  let root = Widget::new()
  {
    session: s,
    root,
    focus: FocusStack::new(),
    host: make_overlay_host(root),
    closed: false,
    canvas: None,
    key_fallthrough: [],
    dirty_rect: None,
    dirty_full: false,
  }
}

///|
pub fn overlay_native_tier() -> Bool {
  @widget.overlay_native_tier()
}

///|
pub fn overlay_native_count() -> Int {
  @widget.overlay_native_count()
}

///|
pub fn overlay_fit_pass(app : App) -> Unit {
  @widget.overlay_fit_pass(app)
}

///|
pub fn overlay_set_dismiss_on_blur(on : Bool) -> Unit {
  @widget.overlay_set_dismiss_on_blur(on)
}

///|
pub fn overlay_dismiss_on_blur() -> Bool {
  @widget.overlay_dismiss_on_blur()
}

///|
pub fn overlay_on_lost_focus(app : App) -> Unit {
  @widget.overlay_on_lost_focus(app)
}

///|
pub fn overlay_close_all_native() -> Unit {
  @widget.overlay_close_all_native()
}

///|
pub fn data_kind_id(kind : DataKind) -> Int {
  @widget.data_kind_id(kind)
}

///|
pub fn data_kind_of_id(id : Int) -> DataKind? {
  @widget.data_kind_of_id(id)
}

///|
pub fn drag_encode(data : DragData) -> Bytes {
  @widget.drag_encode(data)
}

///|
pub fn drag_decode(raw : Bytes) -> DragData? {
  @widget.drag_decode(raw)
}

///|
pub fn set_drag_root_provider(f : () -> Widget?) -> Unit {
  @widget.set_drag_root_provider(f)
}

///|
pub fn set_drag_root(root : Widget) -> Unit {
  @widget.set_drag_root(root)
}

///|
pub fn clear_drag_root() -> Unit {
  @widget.clear_drag_root()
}

///|
pub fn drag_active() -> Bool {
  @widget.drag_active()
}

///|
pub fn drag_data() -> DragData? {
  @widget.drag_data()
}

///|
pub fn drag_source() -> Int {
  @widget.drag_source()
}

///|
pub fn drag_position() -> (Double, Double) {
  @widget.drag_position()
}

///|
pub fn drag_hover() -> Int {
  @widget.drag_hover()
}

///|
pub fn drag_begin(data : DragData, source : Int, x : Double, y : Double) -> Bool {
  @widget.drag_begin(data, source, x, y)
}

///|
pub fn drag_move(x : Double, y : Double) -> Bool {
  @widget.drag_move(x, y)
}

///|
pub fn drag_drop(x : Double, y : Double) -> Bool {
  @widget.drag_drop(x, y)
}

///|
pub fn drag_cancel() -> Unit {
  @widget.drag_cancel()
}

///|
pub fn drag_external_supported() -> Bool {
  @widget.drag_external_supported()
}

///|
pub fn drag_external_enable(id : Int64) -> Bool {
  @widget.drag_external_enable(id)
}

///|
pub fn drag_external_disable(id : Int64) -> Unit {
  @widget.drag_external_disable(id)
}

///|
pub fn drag_external_effect() -> Int {
  @widget.drag_external_effect()
}

///|
pub fn drag_external_pump() -> Bool {
  @widget.drag_external_pump()
}

///|
pub fn drag_effect_of_flag(flag : Int) -> DragEffect {
  @widget.drag_effect_of_flag(flag)
}

///|
pub fn drag_data_has_system_form(data : DragData) -> Bool {
  @widget.drag_data_has_system_form(data)
}

///|
pub fn drag_external_send_supported() -> Bool {
  @widget.drag_external_send_supported()
}

///|
pub fn drag_external_send(data : DragData) -> Result[DragEffect, DragError] {
  @widget.drag_external_send(data)
}

///|
pub fn make_overlay_host(root : Widget) -> OverlayHost {
  @widget.make_overlay_host(root)
}

///|
pub fn set_overlay_host(h : OverlayHost) -> Unit {
  @widget.set_overlay_host(h)
}

///|
pub fn set_overlay_provider(f : () -> OverlayHost?) -> Unit {
  @widget.set_overlay_provider(f)
}

///|
pub fn overlay_count() -> Int {
  @widget.overlay_count()
}

///|
pub fn overlay_ids() -> Array[Int] {
  @widget.overlay_ids()
}

///|
pub fn overlay_top_id() -> Int {
  @widget.overlay_top_id()
}

///|
pub fn overlay_visible() -> Bool {
  @widget.overlay_visible()
}

///|
pub fn overlay_show_at(
  content : Node,
  x : Double,
  y : Double,
  dismiss_on_outside? : Bool = true,
) -> Int {
  @widget.overlay_show_at(content, x, y, dismiss_on_outside=dismiss_on_outside)
}

///|
pub fn overlay_show_full(content : Node) -> Int {
  @widget.overlay_show_full(content)
}

///|
pub fn overlay_set_pos(id : Int, x : Double, y : Double) -> Bool {
  @widget.overlay_set_pos(id, x, y)
}

///|
pub fn overlay_hide(id : Int) -> Unit {
  @widget.overlay_hide(id)
}

///|
pub fn overlay_hide_top() -> Unit {
  @widget.overlay_hide_top()
}

///|
pub fn overlay_clear() -> Unit {
  @widget.overlay_clear()
}

///|
pub fn overlay_raise() -> Unit {
  @widget.overlay_raise()
}

///|
pub fn overlay_root_of(id : Int) -> Widget? {
  @widget.overlay_root_of(id)
}

///|
pub fn overlay_rect_of(id : Int) -> Rect? {
  @widget.overlay_rect_of(id)
}

///|
pub fn gtk_mods_to_mods(state : Int) -> Int {
  @widget.gtk_mods_to_mods(state)
}

///|
pub fn win_mods_to_mods(flags : Int) -> Int {
  @widget.win_mods_to_mods(flags)
}

///|
pub fn mac_mods_to_mods(flags : Int) -> Int {
  @widget.mac_mods_to_mods(flags)
}

///|
pub fn mac_caps_lock(flags : Int) -> Bool {
  @widget.mac_caps_lock(flags)
}

///|
pub fn win_vk_to_keysym(vk : Int) -> Int {
  @widget.win_vk_to_keysym(vk)
}

///|
pub fn win_apply_shift(ks : Int, shift : Bool, caps : Bool) -> Int {
  @widget.win_apply_shift(ks, shift, caps)
}

///|
pub fn mac_vk_to_keysym(code : Int) -> Int {
  @widget.mac_vk_to_keysym(code)
}

///|
pub fn win_button_to_index(mk : Int) -> Int {
  @widget.win_button_to_index(mk)
}

///|
pub fn mac_button_to_index(number : Int) -> Int {
  @widget.mac_button_to_index(number)
}

///|
pub fn ime_route(keysym : Int, mods : Int, composing : Bool) -> ImeRoute {
  @widget.ime_route(keysym, mods, composing)
}

///|
pub fn ime_should_reset(prev_focus : Int, next_focus : Int) -> Bool {
  @widget.ime_should_reset(prev_focus, next_focus)
}

///|
pub fn ime_should_feed_surrounding(focus_id : Int) -> Bool {
  @widget.ime_should_feed_surrounding(focus_id)
}

///|
pub fn raw_to_event(
  code : Int,
  keysym : Int,
  mods : Int,
  x : Int,
  y : Int,
  button : Int,
  axis : Int,
) -> RawEvent {
  @widget.raw_to_event(code, keysym, mods, x, y, button, axis)
}

///|
pub fn bump_paint_epoch() -> Int {
  @widget.bump_paint_epoch()
}

///|
pub fn paint_epoch() -> Int {
  @widget.paint_epoch()
}

///|
pub fn set_widget_discard_hook(f : (Int) -> Unit) -> Unit {
  @widget.set_widget_discard_hook(f)
}

///|
pub fn route_pointer(
  root : Widget,
  ev : PointerEvent,
  hover_id : Int,
  capture : Int,
) -> (Int, Int, Bool, Bool) {
  @widget.route_pointer(root, ev, hover_id, capture)
}

///|
pub fn host_add_app(app : App) -> Unit {
  @widget.host_add_app(app)
}

///|
pub fn host_remove_app(wid : Int) -> Unit {
  @widget.host_remove_app(wid)
}

///|
pub fn host_active() -> App? {
  @widget.host_active()
}

///|
pub fn host_windows() -> Array[App] {
  @widget.host_windows()
}

///|
pub fn host_repaint_all() -> Unit {
  @widget.host_repaint_all()
}

///|
pub fn invalidate_id(id : Int) -> Unit {
  @widget.invalidate_id(id)
}

///|
pub fn host_reset() -> Unit {
  @widget.host_reset()
}

///|
pub fn popup_place(
  owner_x : Int,
  owner_y : Int,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  screen_w : Int,
  screen_h : Int,
) -> (Int, Int) {
  @widget.popup_place(owner_x, owner_y, x, y, w, h, screen_w, screen_h)
}

///|
pub fn node_of(w : Widget) -> Node {
  @widget.node_of(w)
}

///|
pub fn node_of_new(finish : (Widget) -> Widget) -> Node {
  @widget.node_of_new(finish)
}

///|
pub fn mount_children(parent : Widget, children : Array[Node]) -> Unit {
  @widget.mount_children(parent, children)
}

///|
pub fn set_repaint_hook(f : () -> Unit) -> Unit {
  @widget.set_repaint_hook(f)
}

///|
pub fn invalidate() -> Unit {
  @widget.invalidate()
}

///|
pub fn swap_node(sig : Signal[Bool], a : Node, b : Node) -> Node {
  @widget.swap_node(sig, a, b)
}

///|
pub fn[T] bind_node(sig : @base.Signal[T], f : (T) -> Node) -> Node {
  @widget.bind_node(sig, f)
}
