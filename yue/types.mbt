// 控件类型：编译期区分 + 统一句柄。
// 每个控件是真实 struct（.view 为 C++ 侧句柄），可经 ViewLike trait
// 传入任何接受"任意视图"的 API（add_child / set_content 等）。

///|
/// 各控件共用的底层句柄（shim 注册表 id）。
/// #external：值不参与 MoonBit 引用计数，GC 不扫描/移动它。
pub extern type View

///|
pub(all) struct Window {
  view : View
}

///|
pub(all) struct Container {
  view : View
}

///|
pub(all) struct Label {
  view : View
}

///|
pub(all) struct TextEdit {
  view : View
}

///|
pub(all) struct Button {
  view : View
}

///|
pub(all) struct Entry {
  view : View
}

///|
pub(all) struct Browser {
  view : View
}

///|
pub(all) struct Slider {
  view : View
}

///|
pub impl ViewLike for Slider with view(self) {
  self.view
}

///|
pub(all) struct Picker {
  view : View
}

///|
pub impl ViewLike for Picker with view(self) {
  self.view
}

///|
pub(all) struct ComboBox {
  view : View
}

///|
pub impl ViewLike for ComboBox with view(self) {
  self.view
}

///|
pub(all) struct ProgressBar {
  view : View
}

///|
pub impl ViewLike for ProgressBar with view(self) {
  self.view
}

///|
/// 弹出层（非 View，独立句柄）。
#external
pub type Popover

///|
/// 能作为视图传入容器/窗口的类型。
/// 通用视图能力（焦点/启停/布局/背景）作为 trait 默认方法，
/// 所有控件自动获得（默认实现见 view.mbt）。
pub(open) trait ViewLike {
  view(Self) -> View
  fn focus(Self) -> Unit = _
  fn set_enabled(Self, Bool) -> Unit = _
  fn set_mouse_down_can_move_window(Self, Bool) -> Unit = _
  fn set_style(Self, String, Double) -> Unit = _
  fn set_style_str(Self, String, String) -> Unit = _
  fn set_background_color(Self, String) -> Unit = _
  fn register_dragged_types(Self, Array[DataKind]) -> Unit = _
  fn do_drag_file_paths(Self, Array[String], Image?) -> Int = _
  fn handle_drag_enter(Self, (DraggingInfo, Double, Double) -> Int) -> Unit = _
  fn handle_drag_update(Self, (DraggingInfo, Double, Double) -> Int) -> Unit = _
  fn handle_drop(Self, (DraggingInfo, Double, Double) -> Bool) -> Unit = _
  fn on_drag_leave(Self, () -> Unit) -> Unit = _
  fn schedule_paint(Self) -> Unit = _
  fn get_bounds(Self) -> (Double, Double, Double, Double) = _
  fn on_mouse_down(Self, () -> Bool) -> Unit = _
}

pub impl ViewLike for Window with view(self) {
  self.view
}

///|
pub impl ViewLike for Container with view(self) {
  self.view
}

///|
pub impl ViewLike for Label with view(self) {
  self.view
}

///|
pub impl ViewLike for TextEdit with view(self) {
  self.view
}

///|
pub impl ViewLike for Button with view(self) {
  self.view
}

///|
pub impl ViewLike for Entry with view(self) {
  self.view
}

///|
pub impl ViewLike for Browser with view(self) {
  self.view
}

///|
pub(all) struct Table {
  view : View
}

///|
pub impl ViewLike for Table with view(self) {
  self.view
}

///|
/// 独立句柄：菜单条（继承 RefCounted 而非 Responder/View）。
pub extern type MenuBar

///|
pub extern type Menu

///|
pub extern type MenuItem

///|
pub extern type FileDialog

///|
pub extern type Tray

///|
pub extern type Image

///|
pub extern type Canvas

///|
pub extern type AttributedText

///|
pub extern type Font

///|
/// 表格模型桥句柄（C++ TableModelBridge）。
pub extern type TableModelHandle

///|
/// 绘制回调期间由 C 借出的裸指针，无 GC 头，不得持有。
pub extern type Painter

///|
/// 拖拽会话信息：仅拖拽回调期内有效（C 借出，无 GC 头）。
pub extern type DraggingInfo
