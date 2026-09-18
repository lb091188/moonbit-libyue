// 组合控件：滑块 / 下拉选择器 / 可编辑下拉框 / 进度条 / 弹出层。

///|
/// 创建滑块（默认范围 0.0 ~ 1.0）。
pub fn Slider::new() -> Slider {
  { view: ffi_slider_new(), }
}

///|
/// 设置当前值。
pub fn Slider::set_value(self : Slider, value : Double) -> Unit {
  ffi_slider_set_value(self.view, value)
}

///|
/// 读取当前值。
pub fn Slider::get_value(self : Slider) -> Double {
  ffi_slider_get_value(self.view)
}

///|
/// 设置步进（0 表示连续）。
pub fn Slider::set_step(self : Slider, step : Double) -> Unit {
  ffi_slider_set_step(self.view, step)
}

///|
/// 设置取值范围。
pub fn Slider::set_range(self : Slider, min : Double, max : Double) -> Unit {
  ffi_slider_set_range(self.view, min, max)
}

///|
/// 注册值变化回调（拖动过程中持续触发）。
pub fn Slider::on_value_change(self : Slider, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_slider_on_value_change(self.view, fn(f) { f() }, callback)
}

///|
/// 注册拖动结束回调。
pub fn Slider::on_sliding_complete(
  self : Slider,
  callback : () -> Unit,
) -> Unit {
  keep_alive(callback)
  ffi_slider_on_sliding_complete(self.view, fn(f) { f() }, callback)
}

///|
/// 创建下拉选择器。
pub fn Picker::new() -> Picker {
  { view: ffi_picker_new(), }
}

///|
/// 添加选项。
pub fn Picker::add_item(self : Picker, text : String) -> Unit {
  ffi_picker_add_item(ViewLike::view(self), utf8_bytes(text))
}

///|
/// 移除指定位置的选项。
pub fn Picker::remove_item_at(self : Picker, index : Int) -> Unit {
  ffi_picker_remove_item_at(ViewLike::view(self), index)
}

///|
/// 清空全部选项。
pub fn Picker::clear(self : Picker) -> Unit {
  ffi_picker_clear(ViewLike::view(self))
}

///|
/// 选中指定位置的选项。
pub fn Picker::select_item_at(self : Picker, index : Int) -> Unit {
  ffi_picker_select_item_at(ViewLike::view(self), index)
}

///|
/// 当前选中的选项文本。
pub fn Picker::get_selected_item(self : Picker) -> String {
  from_utf8_bytes(ffi_picker_get_selected_item(ViewLike::view(self)))
}

///|
/// 当前选中项下标（无选中为 -1）。
pub fn Picker::get_selected_item_index(self : Picker) -> Int {
  ffi_picker_get_selected_item_index(ViewLike::view(self))
}

///|
/// 注册选择变化回调。
pub fn Picker::on_selection_change(
  self : Picker,
  callback : () -> Unit,
) -> Unit {
  keep_alive(callback)
  ffi_picker_on_selection_change(ViewLike::view(self), fn(f) { f() }, callback)
}

///|
/// 创建可编辑下拉框。
pub fn ComboBox::new() -> ComboBox {
  { view: ffi_combo_box_new(), }
}

///|
/// 设置文本。
pub fn ComboBox::set_text(self : ComboBox, text : String) -> Unit {
  ffi_combo_box_set_text(self.view, utf8_bytes(text))
}

///|
/// 读取文本。
pub fn ComboBox::get_text(self : ComboBox) -> String {
  from_utf8_bytes(ffi_combo_box_get_text(self.view))
}

///|
/// 注册文本变化回调。
pub fn ComboBox::on_text_change(self : ComboBox, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_combo_box_on_text_change(self.view, fn(f) { f() }, callback)
}

///|
/// 创建进度条。
pub fn ProgressBar::new() -> ProgressBar {
  { view: ffi_progress_bar_new(), }
}

///|
/// 设置进度值（0.0 ~ 1.0；-1 与不定态配合）。
pub fn ProgressBar::set_value(self : ProgressBar, value : Double) -> Unit {
  ffi_progress_bar_set_value(self.view, value)
}

///|
/// 设置不定态（如加载中的来回动画）。
pub fn ProgressBar::set_indeterminate(self : ProgressBar, yes : Bool) -> Unit {
  ffi_progress_bar_set_indeterminate(self.view, if yes { 1 } else { 0 })
}

///|
/// 创建弹出层。
pub fn Popover::new() -> Popover {
  ffi_popover_new()
}

///|
/// 设置弹出层内容视图。
pub fn[T : ViewLike] Popover::set_content(self : Popover, content : T) -> Unit {
  ffi_popover_set_content(self, content.view())
}

///|
/// 设置内容区尺寸。
pub fn Popover::set_content_size(
  self : Popover,
  width : Double,
  height : Double,
) -> Unit {
  ffi_popover_set_content_size(self, width, height)
}

///|
/// 在指定视图附近弹出。
pub fn[T : ViewLike] Popover::show_relative_to(
  self : Popover,
  view : T,
) -> Unit {
  ffi_popover_show_relative_to(self, view.view())
}

///|
/// 关闭弹出层。
pub fn Popover::close(self : Popover) -> Unit {
  ffi_popover_close(self)
}

///|
/// 注册弹出层关闭回调。
pub fn Popover::on_close(self : Popover, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_popover_on_close(self, fn(f) { f() }, callback)
}

///|
/// 设置弹层是否接受键盘焦点。传 false 时弹层出现与点击都不夺走当前
/// 焦点控件，键盘事件持续进入锚点（弹层展开期间持续键入的组件依赖
/// 此语义，如 select_t 的输入筛选）。仅 Linux 有实现，其余平台空操作。
pub fn Popover::set_accept_focus(self : Popover, accept : Bool) -> Unit {
  ffi_popover_set_accept_focus(self, if accept { 1 } else { 0 })
}

///|
/// ComboBox 继承 Picker 的选项操作（MoonBit 侧显式委托）。
pub fn ComboBox::add_item(self : ComboBox, text : String) -> Unit {
  ffi_picker_add_item(ViewLike::view(self), utf8_bytes(text))
}

///|
pub fn ComboBox::select_item_at(self : ComboBox, index : Int) -> Unit {
  ffi_picker_select_item_at(ViewLike::view(self), index)
}

///|
pub fn ComboBox::get_selected_item(self : ComboBox) -> String {
  from_utf8_bytes(ffi_picker_get_selected_item(ViewLike::view(self)))
}

///|
pub fn ComboBox::on_selection_change(
  self : ComboBox,
  callback : () -> Unit,
) -> Unit {
  keep_alive(callback)
  ffi_picker_on_selection_change(ViewLike::view(self), fn(f) { f() }, callback)
}

///|
/// 系统通知。
pub fn Notification::new() -> Notification {
  ffi_notification_new()
}

///|
pub fn Notification::set_title(self : Notification, title : String) -> Unit {
  ffi_notification_set_title(self, utf8_bytes(title))
}

///|
pub fn Notification::set_body(self : Notification, body : String) -> Unit {
  ffi_notification_set_body(self, utf8_bytes(body))
}

///|
/// 是否静音（不播放系统提示音）。
pub fn Notification::set_silent(self : Notification, silent : Bool) -> Unit {
  ffi_notification_set_silent(self, if silent { 1 } else { 0 })
}

///|
/// 经系统通知中心弹出。
pub fn Notification::show(self : Notification) -> Unit {
  ffi_notification_show(self)
}

///|
/// 关闭通知。

///|

///|
/// 设置通知按钮（对照 Notification::Action；Linux 经 libnotify action 生效）。
pub fn Notification::set_actions(
  self : Notification,
  actions : Array[(String, String)],
) -> Unit {
  // 协议：[count:i32le]（[len:i32le title][len:i32le info]）*
  let parts : Array[Bytes] = []
  for a in actions {
    parts.push(utf8_bytes(a.0))
    parts.push(utf8_bytes(a.1))
  }
  let mut size = 4
  for b in parts {
    size += 4 + b.length()
  }
  let buf = FixedArray::make(size, b'\x00')
  fn put_i32(buf : FixedArray[Byte], off : Int, v : Int) -> Unit {
    buf[off] = (v & 255).to_byte()
    buf[off + 1] = ((v >> 8) & 255).to_byte()
    buf[off + 2] = ((v >> 16) & 255).to_byte()
    buf[off + 3] = ((v >> 24) & 255).to_byte()
  }

  put_i32(buf, 0, actions.length())
  let mut off = 4
  for b in parts {
    put_i32(buf, off, b.length())
    off += 4
    for j = 0; j < b.length(); j = j + 1 {
      buf[off + j] = b[j]
    }
    off += b.length()
  }
  ffi_notification_set_actions(self, Bytes::from_array(buf))
}

///|
pub fn Notification::close(self : Notification) -> Unit {
  ffi_notification_close(self)
}

///|
/// 注册全局快捷键（格式如 "CmdOrCtrl+Shift+M"），返回注册 id；
/// 返回 -1 表示注册失败（X11 下 XGrabKey 排他，组合键被系统或
/// 桌面环境占用即失败，需换键）。
pub fn register_global_shortcut(
  accelerator : String,
  callback : () -> Unit,
) -> Int {
  keep_alive(callback)
  ffi_global_shortcut_register(utf8_bytes(accelerator), fn(f) { f() }, callback)
}

///|
/// 注销全局快捷键。
pub fn unregister_global_shortcut(id : Int) -> Unit {
  ffi_global_shortcut_unregister(id)
}

///|
/// 创建日期选择控件。
pub fn DatePicker::new() -> DatePicker {
  { view: ffi_date_picker_new(), }
}

///|
/// 创建 GIF 播放控件。
pub fn GifPlayer::new() -> GifPlayer {
  { view: ffi_gif_player_new(), }
}

///|
/// 设置要播放的 GIF 图片。

///|
/// 图片缩放模式（对照 ImageScale）。
pub(all) enum ImageScale {
  None
  Fill
  Down
  UpOrDown
}

///|
pub fn GifPlayer::set_scale(self : GifPlayer, scale : ImageScale) -> Unit {
  ffi_gif_player_set_scale(
    self.view,
    match scale {
      None => 0
      Fill => 1
      Down => 2
      UpOrDown => 3
    },
  )
}

///|
pub fn GifPlayer::get_scale(self : GifPlayer) -> ImageScale {
  match ffi_gif_player_get_scale(self.view) {
    1 => Fill
    2 => Down
    3 => UpOrDown
    _ => None
  }
}

///|
pub fn GifPlayer::set_image(self : GifPlayer, image : Image) -> Unit {
  ffi_gif_player_set_image(ViewLike::view(self), image)
}

///|
/// 设置应用名（Linux 下影响通知等系统集成的标识）。
pub fn App::set_name(name : String) -> Unit {
  ffi_app_set_name(utf8_bytes(name))
}

///|
/// 读取应用名。
pub fn App::get_name() -> String {
  let buf = Bytes::make(256, 0)
  let len = ffi_app_get_name(buf)
  @utf8.decode_lossy(buf[0:len])
}

///|
/// 系统当前是否深色主题。
pub fn Appearance::is_dark() -> Bool {
  ffi_appearance_is_dark() == 1
}

///|
/// 系统区域标识（如 zh_CN）。
pub fn locale() -> String {
  let buf = Bytes::make(128, 0)
  let len = ffi_locale_get(buf, 128)
  @utf8.decode_lossy(buf[0:len])
}

///|
/// 主屏缩放系数。
pub fn Screen::scale_factor() -> Double {
  ffi_screen_get_scale_factor()
}

///|
/// 主屏分辨率：返回 (宽, 高)。
pub fn Screen::primary_size() -> (Double, Double) {
  (ffi_screen_get_primary_width(), ffi_screen_get_primary_height())
}

///|
/// 当前拖拽会话允许的操作位。
pub fn DraggingInfo::get_operations(self : DraggingInfo) -> Int {
  ffi_dragging_get_operations(self)
}

///|
/// 经通知中心添加通知（等价 show）。
pub fn NotificationCenter::add(n : Notification) -> Unit {
  ffi_notification_center_add(n)
}

///|
/// 通知中心单例句柄。
#external
pub type NotificationCenter

///|
/// 取通知中心单例。
pub fn NotificationCenter::get() -> NotificationCenter {
  ffi_notification_center_get()
}

///|
/// 设置日期（Unix epoch 秒）。
pub fn DatePicker::set_date(self : DatePicker, epoch_seconds : Int64) -> Unit {
  ffi_date_picker_set_date(ViewLike::view(self), epoch_seconds)
}

///|
/// 读取日期（Unix epoch 秒）。
pub fn DatePicker::get_date(self : DatePicker) -> Int64 {
  ffi_date_picker_get_date(ViewLike::view(self))
}

///|
/// 注册日期变化回调。
pub fn DatePicker::on_date_change(
  self : DatePicker,
  callback : () -> Unit,
) -> Unit {
  keep_alive(callback)
  ffi_date_picker_on_date_change(ViewLike::view(self), fn(f) { f() }, callback)
}

///|
/// 注册行双击/激活回调（row 为行号）。
pub fn Table::on_row_activate(self : Table, callback : (Int) -> Unit) -> Unit {
  let wrapped : (Int) -> Unit = fn(row) { callback(row) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_table_on_row_activate(self.view, fn(f, row) { f(row) }, wrapped)
}

///|
/// 注册选择变化回调。
pub fn Table::on_selection_change(self : Table, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_table_on_selection_change(self.view, fn(f) { f() }, callback)
}

///|
/// 注册复选框切换回调（column/row 为单元格位置）。
pub fn Table::on_toggle_checkbox(
  self : Table,
  callback : (Int, Int) -> Unit,
) -> Unit {
  let wrapped : (Int, Int) -> Unit = fn(column, row) { callback(column, row) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_table_on_toggle_checkbox(
    self.view,
    fn(f, column, row) { f(column, row) },
    wrapped,
  )
}

///|
/// 最大化窗口。
pub fn Window::maximize(self : Window) -> Unit {
  ffi_window_maximize(ViewLike::view(self))
}

///|
/// 取消最大化。
pub fn Window::unmaximize(self : Window) -> Unit {
  ffi_window_unmaximize(ViewLike::view(self))
}

///|
/// 设置全屏。
pub fn Window::set_fullscreen(self : Window, fullscreen : Bool) -> Unit {
  ffi_window_set_fullscreen(
    ViewLike::view(self),
    if fullscreen {
      1
    } else {
      0
    },
  )
}

///|
/// 当前是否全屏。
pub fn Window::is_fullscreen(self : Window) -> Bool {
  ffi_window_is_fullscreen(ViewLike::view(self)) == 1
}

///|
/// 光标种类。
pub(all) enum CursorType {
  Default
  Hand
  Crosshair
  Progress
  Text
  NotAllowed
  Help
  Move
  ResizeEW
  ResizeNS
  ResizeNESW
  ResizeNWSE
}

///|
fn cursor_type_id(t : CursorType) -> Int {
  match t {
    Default => 0
    Hand => 1
    Crosshair => 2
    Progress => 3
    Text => 4
    NotAllowed => 5
    Help => 6
    Move => 7
    ResizeEW => 8
    ResizeNS => 9
    ResizeNESW => 10
    ResizeNWSE => 11
  }
}

///|
/// 创建指定类型光标。
pub fn Cursor::new(type_ : CursorType) -> Cursor {
  ffi_cursor_new(cursor_type_id(type_))
}

///|
/// 设置视图悬停光标。
pub fn[T : ViewLike] View::set_cursor(self : T, cursor : Cursor) -> Unit {
  ffi_view_set_cursor(ViewLike::view(self), cursor)
}

///|
/// 日期选择器元素组合（对照 DatePicker::Element 位标志）。
pub(all) enum DatePickerElement {
  YearMonth
  YearMonthDay
  HourMinute
  HourMinuteSecond
}

///|
/// 日期选择器选项（对照 DatePicker::Options）。
pub(all) struct DatePickerOptions {
  elements : DatePickerElement
  has_stepper : Bool
}

///|
pub fn DatePickerOptions::new() -> DatePickerOptions {
  { elements: YearMonthDay, has_stepper: true, }
}

///|
/// 按选项创建日期选择器。
pub fn DatePicker::new_with(options : DatePickerOptions) -> DatePicker {
  let elements = match options.elements {
    YearMonth => 0x00C0
    YearMonthDay => 0x00E0
    HourMinute => 0x000C
    HourMinuteSecond => 0x000E
  }
  {
    view: ffi_date_picker_new_ex(
      elements,
      if options.has_stepper {
        1
      } else {
        0
      },
    ),
  }
}
