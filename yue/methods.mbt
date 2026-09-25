// 方法级审计补齐(2026-09-16):对照 vendor/libyue 头文件的
// 方法级封装批次一(Window/View/Container/Scroll/Label/MessageBox/
// Clipboard/Table/Browser/Screen/Appearance/AttributedText/Font/
// GlobalShortcut/MenuItem/FileDialog/App/GifPlayer/Canvas/Notification)。

///|
/// 关闭窗口(触发 on_close 链路)。
pub fn Window::close(self : Window) -> Unit {
  ffi_window_close(self.view)
}

///|
/// 最小化窗口。
pub fn Window::minimize(self : Window) -> Unit {
  ffi_window_minimize(self.view)
}

///|
/// 从最小化恢复窗口。
pub fn Window::restore(self : Window) -> Unit {
  ffi_window_restore(self.view)
}

///|
/// 窗口是否处于最小化。
pub fn Window::is_minimized(self : Window) -> Bool {
  ffi_window_is_minimized(self.view) == 1
}

///|
/// 限制窗口内容区最小/最大尺寸。
pub fn Window::set_content_size_constraints(
  self : Window,
  min : (Double, Double),
  max : (Double, Double),
) -> Unit {
  ffi_window_set_content_size_constraints(self.view, min.0, min.1, max.0, max.1)
}

///|
/// 设置窗口是否可拖动(Linux/Windows)。
pub fn Window::set_movable(self : Window, movable : Bool) -> Unit {
  ffi_window_set_movable(self.view, if movable { 1 } else { 0 })
}

///|
/// 读取窗口标题。
pub fn Window::get_title(self : Window) -> String {
  from_utf8_bytes(ffi_window_get_title(self.view))
}

///|
/// 设置窗口背景色(hex),可消除启动闪白。
pub fn Window::set_background_color(self : Window, hex : String) -> Unit {
  ffi_window_set_background_color(self.view, utf8_bytes(hex))
}

///|
/// 窗口所在显示器的 DPI 缩放系数。
pub fn Window::get_scale_factor(self : Window) -> Double {
  ffi_window_get_scale_factor(self.view)
}

///|
/// 是否不在任务栏显示(托盘类应用常用;Linux/Windows)。
pub fn Window::set_skip_taskbar(self : Window, skip : Bool) -> Unit {
  ffi_window_set_skip_taskbar(self.view, if skip { 1 } else { 0 })
}

///|
/// 设置任务栏窗口图标(Linux/Windows)。
pub fn Window::set_icon(self : Window, icon : Image) -> Unit {
  ffi_window_set_icon(self.view, icon)
}

///|
/// 窗口获得焦点(返回 true 拦截默认处理)。
pub fn Window::on_focus(self : Window, callback : () -> Bool) -> Unit {
  let wrapped : () -> Int = fn() { if callback() { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_window_on_focus_in(self.view, fn(f : () -> Int) -> Int { f() }, wrapped)
}

///|
/// 窗口失去焦点(返回 true 拦截默认处理)。
pub fn Window::on_blur(self : Window, callback : () -> Bool) -> Unit {
  let wrapped : () -> Int = fn() { if callback() { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_window_on_blur(self.view, fn(f : () -> Int) -> Int { f() }, wrapped)
}

///|
/// 设置悬停工具提示。
impl ViewLike with fn set_tooltip(self, text : String) -> Unit {
  ffi_view_set_tooltip(self.view(), utf8_bytes(text))
}

///|
/// 为视图内子矩形添加工具提示,返回其 id(供 remove_tooltip 用)。
impl ViewLike with fn add_tooltip_for_rect(self, text : String, rect : RectF) -> Int {
  ffi_view_add_tooltip_for_rect(
    self.view(),
    utf8_bytes(text),
    rect.x,
    rect.y,
    rect.width,
    rect.height,
  )
}

///|
/// 移除子矩形工具提示。
impl ViewLike with fn remove_tooltip(self, id : Int) -> Unit {
  ffi_view_remove_tooltip(self.view(), id)
}

///|
/// 设置视图是否可获焦点。
impl ViewLike with fn set_focusable(self, focusable : Bool) -> Unit {
  ffi_view_set_focusable(self.view(), if focusable { 1 } else { 0 })
}

///|
/// 视图当前是否持有焦点。
impl ViewLike with fn has_focus(self) -> Bool {
  ffi_view_has_focus(self.view()) == 1
}

///|
/// 请求重绘局部区域。
impl ViewLike with fn schedule_paint_rect(self, rect : RectF) -> Unit {
  ffi_view_schedule_paint_rect(
    self.view(),
    rect.x,
    rect.y,
    rect.width,
    rect.height,
  )
}

///|
/// 视图获得焦点(返回 true 拦截默认处理)。
impl ViewLike with fn on_focus_in(self, callback : () -> Bool) -> Unit {
  let wrapped : () -> Int = fn() { if callback() { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_focus_in(self.view(), fn(f : () -> Int) -> Int { f() }, wrapped)
}

///|
/// 视图失去焦点(返回 true 拦截默认处理)。
impl ViewLike with fn on_focus_out(self, callback : () -> Bool) -> Unit {
  let wrapped : () -> Int = fn() { if callback() { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_view_on_focus_out(self.view(), fn(f : () -> Int) -> Int { f() }, wrapped)
}

///|
/// 在指定位置插入子视图。
pub fn Container::add_child_view_at(
  self : Container,
  child : View,
  index : Int,
) -> Unit {
  ffi_container_add_child_view_at(self.view, child, index)
}

///|
/// 移除子视图(成功返回 true)。
pub fn Container::remove_child_view(self : Container, child : View) -> Bool {
  ffi_container_remove_child_view(self.view, child) == 1
}

///|
/// 子视图数量。
pub fn Container::child_count(self : Container) -> Int {
  ffi_container_child_count(self.view)
}

///|
/// 当前滚动位置 X。
pub fn Scroll::get_scroll_position_x(self : Scroll) -> Double {
  ffi_scroll_get_position_x(ViewLike::view(self))
}

///|
/// 当前滚动位置 Y。
pub fn Scroll::get_scroll_position_y(self : Scroll) -> Double {
  ffi_scroll_get_position_y(ViewLike::view(self))
}

///|
/// 最大滚动位置 X。
pub fn Scroll::get_max_scroll_position_x(self : Scroll) -> Double {
  ffi_scroll_get_max_position_x(ViewLike::view(self))
}

///|
/// 最大滚动位置 Y。
pub fn Scroll::get_max_scroll_position_y(self : Scroll) -> Double {
  ffi_scroll_get_max_position_y(ViewLike::view(self))
}

///|
/// 滚动事件(返回 true 拦截默认处理)。
pub fn Scroll::on_scroll(self : Scroll, callback : () -> Bool) -> Unit {
  let wrapped : () -> Int = fn() { if callback() { 1 } else { 0 } }
  keep_alive(fn() { ignore(wrapped) })
  ffi_scroll_on_scroll(ViewLike::view(self), fn(f : () -> Int) -> Int { f() }, wrapped)
}

///|
/// 设置 Label 文字垂直对齐。
pub fn Label::set_valign(self : Label, align : TextAlign) -> Unit {
  ffi_label_set_valign(
    self.view,
    match align {
      Start => 0
      Center => 1
      End => 2
    },
  )
}

///|
/// 设置 Label 显示富文本(整段字体/颜色,可绕开 Windows 区间缺陷)。
pub fn Label::set_attributed_text(self : Label, at : AttributedText) -> Unit {
  ffi_label_set_attributed_text(self.view, at)
}

///|
/// 设置回车触发的默认按钮(MessageBox::Response 常量)。
pub fn MessageBox::set_default_response(
  self : MessageBox,
  response : Int,
) -> Unit {
  ffi_message_box_set_default_response(self, response)
}

///|
/// 设置 Esc 触发的取消按钮。
pub fn MessageBox::set_cancel_response(
  self : MessageBox,
  response : Int,
) -> Unit {
  ffi_message_box_set_cancel_response(self, response)
}

///|
/// 阻塞运行消息框并返回用户选择。
pub fn MessageBox::run(self : MessageBox) -> Int {
  ffi_message_box_run(self)
}

///|
/// 阻塞运行并模态于指定窗口。
pub fn MessageBox::run_for_window(self : MessageBox, window : Window) -> Int {
  ffi_message_box_run_for_window(self, window.view())
}

///|
/// 剪贴板中是否存在指定类型数据(kind 语义同 get_data)。
pub fn Clipboard::is_data_available(self : Clipboard, kind : Int) -> Bool {
  ffi_clipboard_is_data_available(self, kind) == 1
}

///|
/// 开始监听剪贴板变化。
pub fn Clipboard::start_watching(self : Clipboard) -> Unit {
  ffi_clipboard_start_watching(self)
}

///|
/// 停止监听剪贴板变化。
pub fn Clipboard::stop_watching(self : Clipboard) -> Unit {
  ffi_clipboard_stop_watching(self)
}

///|
/// 剪贴板内容变化回调。
pub fn Clipboard::on_change(self : Clipboard, callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_clipboard_on_change(self, fn(f : () -> Unit) -> Unit { f() }, callback)
}

///|
/// 启用多选(Linux/Windows)。
pub fn Table::enable_multiple_selection(self : Table, enable : Bool) -> Unit {
  ffi_table_enable_multiple_selection(ViewLike::view(self), if enable { 1 } else { 0 })
}

///|
/// 编程选中一行。
pub fn Table::select_row(self : Table, row : Int) -> Unit {
  ffi_table_select_row(ViewLike::view(self), row)
}

///|
/// 当前选中行(无选中返回 -1)。
pub fn Table::get_selected_row(self : Table) -> Int {
  ffi_table_get_selected_row(ViewLike::view(self))
}

///|
/// 模型刷新:插入行后调用,同步视图。
pub fn Table::notify_row_insertion(self : Table, row : Int) -> Unit {
  ignore(ffi_table_notify_row_insertion(ViewLike::view(self), row))
}

///|
/// 模型刷新:删除行后调用,同步视图。
pub fn Table::notify_row_deletion(self : Table, row : Int) -> Unit {
  ignore(ffi_table_notify_row_deletion(ViewLike::view(self), row))
}

///|
/// 模型刷新:单元格值变化后调用,同步视图。
pub fn Table::notify_value_change(
  self : Table,
  column : Int,
  row : Int,
) -> Unit {
  ignore(ffi_table_notify_value_change(ViewLike::view(self), column, row))
}

///|
/// 读取浏览器页面标题。
pub fn Browser::get_title(self : Browser) -> String {
  from_utf8_bytes(ffi_browser_get_title(self.view))
}

///|
/// 停止页面加载。
pub fn Browser::stop(self : Browser) -> Unit {
  ffi_browser_stop(self.view)
}

///|
/// 主显示器 DPI 缩放系数。
pub fn primary_scale_factor() -> Double {
  ffi_screen_primary_scale_factor()
}

///|
/// 主显示器工作区(去掉任务栏)X。
pub fn primary_work_area_x() -> Double {
  ffi_screen_primary_work_area_x()
}

///|
/// 主显示器工作区 Y。
pub fn primary_work_area_y() -> Double {
  ffi_screen_primary_work_area_y()
}

///|
/// 主显示器工作区宽。
pub fn primary_work_area_width() -> Double {
  ffi_screen_primary_work_area_width()
}

///|
/// 主显示器工作区高。
pub fn primary_work_area_height() -> Double {
  ffi_screen_primary_work_area_height()
}

///|
/// 光标屏幕坐标 X。
pub fn cursor_screen_x() -> Double {
  ffi_screen_cursor_x()
}

///|
/// 光标屏幕坐标 Y。
pub fn cursor_screen_y() -> Double {
  ffi_screen_cursor_y()
}

///|
/// 设置系统暗色模式(Linux/Windows;macOS 行为随上游)。
pub fn set_dark_mode_enabled(enable : Bool) -> Unit {
  ffi_appearance_set_dark_mode_enabled(if enable { 1 } else { 0 })
}

///|
/// 系统配色方案变化回调。
pub fn on_color_scheme_change(callback : () -> Unit) -> Unit {
  keep_alive(callback)
  ffi_appearance_on_color_scheme_change(
    fn(f : () -> Unit) -> Unit { f() },
    callback,
  )
}

///|
/// 单行文本宽度(自绘排版测量)。
pub fn AttributedText::get_one_line_width(self : AttributedText) -> Double {
  ffi_attributed_text_get_one_line_width(self)
}

///|
/// 单行文本高度(自绘排版测量)。
pub fn AttributedText::get_one_line_height(self : AttributedText) -> Double {
  ffi_attributed_text_get_one_line_height(self)
}

///|
/// 系统默认字体。
pub fn Font::default() -> Font {
  ffi_font_default()
}

///|
/// 字体族名。
pub fn Font::get_name(self : Font) -> String {
  from_utf8_bytes(ffi_font_get_name(self))
}

///|
/// 字号。
pub fn Font::get_size(self : Font) -> Double {
  ffi_font_get_size(self)
}

///|
/// 注销全部全局快捷键。
pub fn unregister_all_global_shortcuts() -> Unit {
  ffi_global_shortcut_unregister_all()
}

///|
/// 程序化触发菜单项。
pub fn MenuItem::click(self : MenuItem) -> Unit {
  ffi_menu_item_click(self)
}

///|
/// 菜单项启用/禁用。
pub fn MenuItem::set_enabled(self : MenuItem, enabled : Bool) -> Unit {
  ffi_menu_item_set_enabled(self, if enabled { 1 } else { 0 })
}

///|
/// 菜单项是否启用。
pub fn MenuItem::is_enabled(self : MenuItem) -> Bool {
  ffi_menu_item_is_enabled(self) == 1
}

///|
/// 菜单项显隐。
pub fn MenuItem::set_visible(self : MenuItem, visible : Bool) -> Unit {
  ffi_menu_item_set_visible(self, if visible { 1 } else { 0 })
}

///|
/// 菜单项是否可见。
pub fn MenuItem::is_visible(self : MenuItem) -> Bool {
  ffi_menu_item_is_visible(self) == 1
}

///|
/// 文件对话框标题。
pub fn FileDialog::set_title(self : FileDialog, title : String) -> Unit {
  ffi_file_dialog_set_title(self, utf8_bytes(title))
}

///|
/// 文件对话框确认按钮文案。
pub fn FileDialog::set_button_label(self : FileDialog, label : String) -> Unit {
  ffi_file_dialog_set_button_label(self, utf8_bytes(label))
}

///|
/// 设置应用 ID(Linux/Windows,通知与任务栏分组用)。
pub fn set_app_id(id : String) -> Unit {
  ffi_app_set_id(utf8_bytes(id))
}

///|
/// 读取应用 ID。
pub fn get_app_id() -> String {
  from_utf8_bytes(ffi_app_get_id())
}

///|
/// 设置 GIF 动画开关。
pub fn GifPlayer::set_animating(self : GifPlayer, animating : Bool) -> Unit {
  ffi_gif_player_set_animating(ViewLike::view(self), if animating { 1 } else { 0 })
}

///|
/// GIF 是否处于动画状态。
pub fn GifPlayer::is_animating(self : GifPlayer) -> Bool {
  ffi_gif_player_is_animating(ViewLike::view(self)) == 1
}

///|
/// GIF 是否在播放。
pub fn GifPlayer::is_playing(self : GifPlayer) -> Bool {
  ffi_gif_player_is_playing(ViewLike::view(self)) == 1
}

///|
/// 停止 GIF 动画定时器。
pub fn GifPlayer::stop_animation_timer(self : GifPlayer) -> Unit {
  ffi_gif_player_stop_animation_timer(ViewLike::view(self))
}

///|
/// 画布 DPI 缩放系数(HiDPI 绘制用)。
pub fn Canvas::get_scale_factor(self : Canvas) -> Double {
  ffi_canvas_get_scale_factor(self)
}

///|
/// 画布宽度。
pub fn Canvas::get_width(self : Canvas) -> Double {
  ffi_canvas_get_width(self)
}

///|
/// 画布高度。
pub fn Canvas::get_height(self : Canvas) -> Double {
  ffi_canvas_get_height(self)
}

///|
/// 清除全部通知。
pub fn clear_notifications() -> Unit {
  ffi_notification_center_clear()
}

///|
/// 通知显示回调(参数为通知 id)。
pub fn on_notification_show(callback : (String) -> Unit) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(id) { callback(from_utf8_bytes(id)) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_notification_center_on_notification_show(
    fn(f : (Bytes) -> Unit, id : Bytes) -> Unit { f(id) },
    wrapped,
  )
}

///|
/// 通知关闭回调。
pub fn on_notification_close(callback : (String) -> Unit) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(id) { callback(from_utf8_bytes(id)) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_notification_center_on_notification_close(
    fn(f : (Bytes) -> Unit, id : Bytes) -> Unit { f(id) },
    wrapped,
  )
}

///|
/// 通知点击回调(点击通知本体)。
pub fn on_notification_click(callback : (String) -> Unit) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(id) { callback(from_utf8_bytes(id)) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_notification_center_on_notification_click(
    fn(f : (Bytes) -> Unit, id : Bytes) -> Unit { f(id) },
    wrapped,
  )
}

///|
/// 通知动作按钮回调(点击 actions 按钮)。
pub fn on_notification_action(callback : (String) -> Unit) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(id) { callback(from_utf8_bytes(id)) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_notification_center_on_notification_action(
    fn(f : (Bytes) -> Unit, id : Bytes) -> Unit { f(id) },
    wrapped,
  )
}

///|
/// 执行 JS 并异步取回结果:ok 表示执行成功,json 为结果值的 JSON 文本。
pub fn Browser::execute_javascript_with_result(
  self : Browser,
  code : String,
  callback : (Bool, String) -> Unit,
) -> Unit {
  let wrapped : (Int, Bytes) -> Unit = fn(ok, json) {
    callback(ok == 1, from_utf8_bytes(json))
  }
  keep_alive(fn() { ignore(wrapped) })
  ffi_browser_execute_javascript_callback(
    self.view,
    utf8_bytes(code),
    fn(f : (Int, Bytes) -> Unit, ok : Int, json : Bytes) -> Unit { f(ok, json) },
    wrapped,
  )
}

///|
/// 注册 JS↔原生绑定:网页 JS 调用 name(name) 时收到 JSON 参数文本。
/// 仅原始绑定(返回值不经类型转换回传);SetBindingName 改协议名。
pub fn Browser::add_raw_binding(
  self : Browser,
  name : String,
  callback : (String) -> Unit,
) -> Unit {
  let wrapped : (Bytes) -> Unit = fn(json) { callback(from_utf8_bytes(json)) }
  keep_alive(fn() { ignore(wrapped) })
  ffi_browser_add_raw_binding(
    self.view,
    utf8_bytes(name),
    fn(f : (Bytes) -> Unit, json : Bytes) -> Unit { f(json) },
    wrapped,
  )
}

///|
/// 移除绑定。
pub fn Browser::remove_binding(self : Browser, name : String) -> Unit {
  ffi_browser_remove_binding(self.view, utf8_bytes(name))
}

///|
/// 是否存在已注册绑定。
pub fn Browser::has_bindings(self : Browser) -> Bool {
  ffi_browser_has_bindings(self.view) == 1
}

///|
/// 以文本/文件路径混合数据发起拖拽(空串跳过该类数据),
/// operations 为 DragOperation 位组合,返回最终生效的操作。
impl ViewLike with fn do_drag_data_full(
  self,
  text : String,
  file_paths : String,
  operations : Int,
  drag_image : Image,
) -> Int {
  ffi_view_do_drag_data(
    self.view(),
    utf8_bytes(text),
    utf8_bytes(file_paths),
    operations,
    drag_image,
  )
}

///|
/// 以文本/文件路径混合数据发起拖拽(operations 为 DragOperation 位组合,
/// 默认 COPY=2;drag_image 为可选拖拽预览图),返回最终生效的操作。
pub fn[T : ViewLike] start_drag(
  v : T,
  text? : String = "",
  file_paths? : String = "",
  operations? : Int = 2,
  drag_image? : Image? = None,
) -> Int {
  let img : Image = match drag_image {
    Some(i) => i
    None => ffi_null_image()
  }
  v.do_drag_data_full(text, file_paths, operations, img)
}

///|
/// 取消进行中的拖拽。
impl ViewLike with fn cancel_drag(self) -> Unit {
  ignore(ffi_view_cancel_drag(self.view()))
}

///|
/// 是否正在拖拽。
impl ViewLike with fn is_dragging(self) -> Bool {
  ffi_view_is_dragging(self.view()) == 1
}
