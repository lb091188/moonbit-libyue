// 私有 FFI 层：所有 extern 声明集中在此，仅 native 后端参与编译。
// 上层模块不得直接调用本文件中的函数。
// 约定：
// - 指针参数一律 #borrow：C 侧只在调用期访问；跨调保存的回调指针
//   由 MoonBit 侧注册表保活（见 view.mbt），不转移所有权。
// - extern 不可返回可空类型（ABI 与 C 指针不兼容），成败经 Ref[Int] 出参。
// - C 的 int32_t 参数在 MoonBit 侧用 Int 表达（bool 以 0/1 传）。

// 类型声明见 types.mbt

///|
extern "c" fn ffi_app_init() -> Bool = "yue_mbt_app_init"

///|
extern "c" fn ffi_run() -> Unit = "yue_mbt_run"

///|
extern "c" fn ffi_quit() -> Unit = "yue_mbt_quit"

///|
extern "c" fn ffi_platform() -> Int = "yue_mbt_platform"

///|
#borrow(frame, transparent)
extern "c" fn ffi_window_new_ex(frame : Int, transparent : Int) -> View = "yue_mbt_window_new_ex"

///|
#borrow(window, title)
extern "c" fn ffi_window_set_title(window : View, title : Bytes) -> Unit = "yue_mbt_window_set_title"

///|
#borrow(window)
extern "c" fn ffi_window_set_always_on_top(window : View, top : Int) -> Unit = "yue_mbt_window_set_always_on_top"

///|
#borrow(window)
extern "c" fn ffi_window_get_content_size_width(window : View) -> Double = "yue_mbt_window_get_content_size_width"

///|
#borrow(window)
extern "c" fn ffi_window_get_content_size_height(window : View) -> Double = "yue_mbt_window_get_content_size_height"

///|
#borrow(window, content)
extern "c" fn ffi_window_set_content(window : View, content : View) -> Unit = "yue_mbt_window_set_content"

///|
#borrow(window)
extern "c" fn ffi_window_set_content_size(
  window : View,
  width : Double,
  height : Double,
) -> Unit = "yue_mbt_window_set_content_size"

///|
#borrow(window)
extern "c" fn ffi_window_center(window : View) -> Unit = "yue_mbt_window_center"

///|
#borrow(window)
extern "c" fn ffi_window_activate(window : View) -> Unit = "yue_mbt_window_activate"

///|
#borrow(window, menubar)
extern "c" fn ffi_window_set_menubar(window : View, menubar : MenuBar) -> Unit = "yue_mbt_window_set_menubar"

///|
/// 关闭回调 trampoline：invoke 由 C 调用，参数即 closure 指针。
#borrow(window, invoke, callback)
extern "c" fn ffi_window_on_close(
  window : View,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  callback : () -> Unit,
) -> Unit = "yue_mbt_window_on_close"

///|
#borrow(view)
extern "c" fn ffi_view_focus(view : View) -> Unit = "yue_mbt_view_focus"

///|
#borrow(view)
extern "c" fn ffi_view_set_enabled(view : View, enable : Int) -> Unit = "yue_mbt_view_set_enabled"

///|
#borrow(view)
extern "c" fn ffi_view_set_mouse_down_can_move_window(view : View, yes : Int) -> Unit = "yue_mbt_view_set_mouse_down_can_move_window"

///|
#borrow(view, name)
extern "c" fn ffi_view_set_style_prop_float(view : View, name : Bytes, value : Double) -> Unit = "yue_mbt_view_set_style_prop_float"

///|
#borrow(view, name, value)
extern "c" fn ffi_view_set_style_prop_str(view : View, name : Bytes, value : Bytes) -> Unit = "yue_mbt_view_set_style_prop_str"

///|
#borrow(view, hex)
extern "c" fn ffi_view_set_background_color(view : View, hex : Bytes) -> Unit = "yue_mbt_view_set_background_color"

///|
extern "c" fn ffi_container_new() -> View = "yue_mbt_container_new"

///|
#borrow(container, child)
extern "c" fn ffi_container_add_child(container : View, child : View) -> Unit = "yue_mbt_container_add_child"

///|
#borrow(container, invoke, callback)
extern "c" fn ffi_container_on_draw(
  container : View,
  invoke : FuncRef[((Painter) -> Unit, Painter) -> Unit],
  callback : (Painter) -> Unit,
) -> Unit = "yue_mbt_container_on_draw"

///|
#borrow(text)
extern "c" fn ffi_label_new(text : Bytes) -> View = "yue_mbt_label_new"

///|
#borrow(label, text)
extern "c" fn ffi_label_set_text(label : View, text : Bytes) -> Unit = "yue_mbt_label_set_text"

///|
extern "c" fn ffi_text_edit_new() -> View = "yue_mbt_text_edit_new"

///|
#borrow(edit, text)
extern "c" fn ffi_text_edit_set_text(edit : View, text : Bytes) -> Unit = "yue_mbt_text_edit_set_text"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_get_text(edit : View) -> Bytes = "yue_mbt_text_edit_get_text"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_get_text_bounds_height(edit : View) -> Double = "yue_mbt_text_edit_get_text_bounds_height"

///|
#borrow(edit, invoke, callback)
extern "c" fn ffi_text_edit_on_text_change(
  edit : View,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  callback : () -> Unit,
) -> Unit = "yue_mbt_text_edit_on_text_change"

///|
#borrow(title)
extern "c" fn ffi_button_new(title : Bytes) -> View = "yue_mbt_button_new"

///|
#borrow(button, title)
extern "c" fn ffi_button_set_title(button : View, title : Bytes) -> Unit = "yue_mbt_button_set_title"

///|
#borrow(button, invoke, callback)
extern "c" fn ffi_button_on_click(
  button : View,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  callback : () -> Unit,
) -> Unit = "yue_mbt_button_on_click"

///|
extern "c" fn ffi_entry_new() -> View = "yue_mbt_entry_new"

///|
#borrow(entry, text)
extern "c" fn ffi_entry_set_text(entry : View, text : Bytes) -> Unit = "yue_mbt_entry_set_text"

///|
#borrow(entry)
extern "c" fn ffi_entry_get_text(entry : View) -> Bytes = "yue_mbt_entry_get_text"

///|
extern "c" fn ffi_browser_new() -> View = "yue_mbt_browser_new"

///|
#borrow(browser, url)
extern "c" fn ffi_browser_load_url(browser : View, url : Bytes) -> Unit = "yue_mbt_browser_load_url"

///|
#borrow(browser)
extern "c" fn ffi_browser_get_url(browser : View) -> Bytes = "yue_mbt_browser_get_url"

///|
#borrow(browser)
extern "c" fn ffi_browser_reload(browser : View) -> Unit = "yue_mbt_browser_reload"

///|
#borrow(browser)
extern "c" fn ffi_browser_go_back(browser : View) -> Unit = "yue_mbt_browser_go_back"

///|
#borrow(browser)
extern "c" fn ffi_browser_go_forward(browser : View) -> Unit = "yue_mbt_browser_go_forward"

///|
#borrow(browser)
extern "c" fn ffi_browser_can_go_back(browser : View) -> Int = "yue_mbt_browser_can_go_back"

///|
#borrow(browser)
extern "c" fn ffi_browser_can_go_forward(browser : View) -> Int = "yue_mbt_browser_can_go_forward"

///|
#borrow(browser)
extern "c" fn ffi_browser_is_loading(browser : View) -> Int = "yue_mbt_browser_is_loading"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_change_loading(
  browser : View,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  callback : () -> Unit,
) -> Unit = "yue_mbt_browser_on_change_loading"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_update_command(
  browser : View,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  callback : () -> Unit,
) -> Unit = "yue_mbt_browser_on_update_command"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_update_title(
  browser : View,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_on_update_title"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_commit_navigation(
  browser : View,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_on_commit_navigation"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_finish_navigation(
  browser : View,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_on_finish_navigation"

///|
extern "c" fn ffi_menu_bar_new() -> MenuBar = "yue_mbt_menu_bar_new"

///|
#borrow(menubar, title)
extern "c" fn ffi_menu_bar_add_menu(menubar : MenuBar, title : Bytes) -> Menu = "yue_mbt_menu_bar_add_menu"

///|
#borrow(menu, title)
extern "c" fn ffi_menu_add_submenu(menu : Menu, title : Bytes) -> Menu = "yue_mbt_menu_add_submenu"

///|
#borrow(menu, label)
extern "c" fn ffi_menu_add_label_item(menu : Menu, label : Bytes) -> MenuItem = "yue_mbt_menu_add_label_item"

///|
#borrow(menu)
extern "c" fn ffi_menu_add_role_item(menu : Menu, role : Int) -> MenuItem = "yue_mbt_menu_add_role_item"

///|
#borrow(menu)
extern "c" fn ffi_menu_add_separator(menu : Menu) -> MenuItem = "yue_mbt_menu_add_separator"

///|
#borrow(item, label)
extern "c" fn ffi_menu_item_set_label(item : MenuItem, label : Bytes) -> Unit = "yue_mbt_menu_item_set_label"

///|
#borrow(item, accelerator)
extern "c" fn ffi_menu_item_set_accelerator(item : MenuItem, accelerator : Bytes) -> Unit = "yue_mbt_menu_item_set_accelerator"

///|
#borrow(item, invoke, callback)
extern "c" fn ffi_menu_item_on_click(
  item : MenuItem,
  invoke : FuncRef[((() -> Unit) -> Unit)],
  callback : () -> Unit,
) -> Unit = "yue_mbt_menu_item_on_click"

///|
extern "c" fn ffi_file_open_dialog_new() -> FileDialog = "yue_mbt_file_open_dialog_new"

///|
extern "c" fn ffi_file_save_dialog_new() -> FileDialog = "yue_mbt_file_save_dialog_new"

///|
#borrow(dialog, filters)
extern "c" fn ffi_file_dialog_set_filters(dialog : FileDialog, filters : Bytes) -> Unit = "yue_mbt_file_dialog_set_filters"

///|
#borrow(dialog, folder)
extern "c" fn ffi_file_dialog_set_folder(dialog : FileDialog, folder : Bytes) -> Unit = "yue_mbt_file_dialog_set_folder"

///|
#borrow(dialog, filename)
extern "c" fn ffi_file_dialog_set_filename(dialog : FileDialog, filename : Bytes) -> Unit = "yue_mbt_file_dialog_set_filename"

///|
#borrow(dialog, window)
extern "c" fn ffi_file_dialog_run_for_window(dialog : FileDialog, window : View) -> Int = "yue_mbt_file_dialog_run_for_window"

///|
#borrow(dialog)
extern "c" fn ffi_file_dialog_get_result(dialog : FileDialog) -> Bytes = "yue_mbt_file_dialog_get_result"

///|
#borrow(path, ok)
extern "c" fn ffi_read_file(path : Bytes, ok : Ref[Int]) -> Bytes = "yue_mbt_read_file"

///|
#borrow(path, data, ok)
extern "c" fn ffi_write_file(path : Bytes, data : Bytes, len : Int, ok : Ref[Int]) -> Unit = "yue_mbt_write_file"

///|
#borrow(painter)
extern "c" fn ffi_painter_save(painter : Painter) -> Unit = "yue_mbt_painter_save"

///|
#borrow(painter)
extern "c" fn ffi_painter_restore(painter : Painter) -> Unit = "yue_mbt_painter_restore"

///|
#borrow(painter)
extern "c" fn ffi_painter_begin_path(painter : Painter) -> Unit = "yue_mbt_painter_begin_path"

///|
#borrow(painter)
extern "c" fn ffi_painter_close_path(painter : Painter) -> Unit = "yue_mbt_painter_close_path"

///|
#borrow(painter)
extern "c" fn ffi_painter_move_to(painter : Painter, x : Double, y : Double) -> Unit = "yue_mbt_painter_move_to"

///|
#borrow(painter)
extern "c" fn ffi_painter_line_to(painter : Painter, x : Double, y : Double) -> Unit = "yue_mbt_painter_line_to"

///|
#borrow(painter)
extern "c" fn ffi_painter_bezier_curve_to(
  painter : Painter,
  cp1x : Double,
  cp1y : Double,
  cp2x : Double,
  cp2y : Double,
  x : Double,
  y : Double,
) -> Unit = "yue_mbt_painter_bezier_curve_to"

///|
#borrow(painter)
extern "c" fn ffi_painter_arc(
  painter : Painter,
  x : Double,
  y : Double,
  radius : Double,
  start_angle : Double,
  end_angle : Double,
  ccw : Int,
) -> Unit = "yue_mbt_painter_arc"

///|
#borrow(painter)
extern "c" fn ffi_painter_fill(painter : Painter) -> Unit = "yue_mbt_painter_fill"

///|
#borrow(painter)
extern "c" fn ffi_painter_stroke(painter : Painter) -> Unit = "yue_mbt_painter_stroke"

///|
#borrow(painter)
extern "c" fn ffi_painter_clip_rect(painter : Painter, x : Double, y : Double, w : Double, h : Double) -> Unit = "yue_mbt_painter_clip_rect"

///|
#borrow(painter)
extern "c" fn ffi_painter_fill_rect(painter : Painter, x : Double, y : Double, w : Double, h : Double) -> Unit = "yue_mbt_painter_fill_rect"

///|
#borrow(painter)
extern "c" fn ffi_painter_stroke_rect(painter : Painter, x : Double, y : Double, w : Double, h : Double) -> Unit = "yue_mbt_painter_stroke_rect"

///|
#borrow(painter, hex)
extern "c" fn ffi_painter_set_fill_color(painter : Painter, hex : Bytes) -> Unit = "yue_mbt_painter_set_fill_color"

///|
#borrow(painter, hex)
extern "c" fn ffi_painter_set_stroke_color(painter : Painter, hex : Bytes) -> Unit = "yue_mbt_painter_set_stroke_color"

///|
#borrow(painter)
extern "c" fn ffi_painter_translate(painter : Painter, dx : Double, dy : Double) -> Unit = "yue_mbt_painter_translate"

///|
#borrow(painter)
extern "c" fn ffi_painter_scale(painter : Painter, sx : Double, sy : Double) -> Unit = "yue_mbt_painter_scale"

///|
#borrow(painter)
extern "c" fn ffi_painter_rotate(painter : Painter, angle : Double) -> Unit = "yue_mbt_painter_rotate"

///|
#borrow(painter, text, hex_color)
extern "c" fn ffi_painter_draw_text(
  painter : Painter,
  text : Bytes,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  align : Int,
  valign : Int,
  hex_color : Bytes,
) -> Unit = "yue_mbt_painter_draw_text"

///|
#borrow(painter, at)
extern "c" fn ffi_painter_draw_attributed_text(
  painter : Painter,
  at : AttributedText,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_painter_draw_attributed_text"

///|
#borrow(painter, image)
extern "c" fn ffi_painter_draw_image(
  painter : Painter,
  image : Image,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_painter_draw_image"

///|
#borrow(painter, image)
extern "c" fn ffi_painter_draw_image_from_rect(
  painter : Painter,
  image : Image,
  sx : Double,
  sy : Double,
  sw : Double,
  sh : Double,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
) -> Unit = "yue_mbt_painter_draw_image_from_rect"

///|
#borrow(painter, canvas)
extern "c" fn ffi_painter_draw_canvas(
  painter : Painter,
  canvas : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_painter_draw_canvas"

///|
#borrow(painter, canvas)
extern "c" fn ffi_painter_draw_canvas_from_rect(
  painter : Painter,
  canvas : Canvas,
  sx : Double,
  sy : Double,
  sw : Double,
  sh : Double,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
) -> Unit = "yue_mbt_painter_draw_canvas_from_rect"

///|
extern "c" fn ffi_canvas_new(width : Double, height : Double) -> Canvas = "yue_mbt_canvas_new"

///|
#borrow(canvas)
extern "c" fn ffi_canvas_get_painter(canvas : Canvas) -> Painter = "yue_mbt_canvas_get_painter"

///|
#borrow(text)
extern "c" fn ffi_attributed_text_new(text : Bytes, align : Int, valign : Int) -> AttributedText = "yue_mbt_attributed_text_new"

///|
#borrow(at, font)
extern "c" fn ffi_attributed_text_set_font(at : AttributedText, font : Font) -> Unit = "yue_mbt_attributed_text_set_font"

///|
#borrow(at, hex)
extern "c" fn ffi_attributed_text_set_color(at : AttributedText, hex : Bytes) -> Unit = "yue_mbt_attributed_text_set_color"

///|
#borrow(at, out_w, out_h)
extern "c" fn ffi_attributed_text_get_bounds_for(
  at : AttributedText,
  w : Double,
  h : Double,
  out_w : Ref[Double],
  out_h : Ref[Double],
) -> Unit = "yue_mbt_attributed_text_get_bounds_for"

///|
#borrow(name)
extern "c" fn ffi_font_new(name : Bytes, size : Double, weight : Int, style : Int) -> Font = "yue_mbt_font_new"

///|
#borrow(path)
extern "c" fn ffi_image_new_from_file(path : Bytes) -> Image = "yue_mbt_image_new_from_file"

///|
#borrow(image)
extern "c" fn ffi_image_get_width(image : Image) -> Double = "yue_mbt_image_get_width"

///|
#borrow(image)
extern "c" fn ffi_image_get_height(image : Image) -> Double = "yue_mbt_image_get_height"

///|
/// 托盘后端可用性探测。Linux 上等价于检查 AppIndicator 运行库能否加载。
extern "c" fn ffi_tray_supported() -> Bool = "yue_mbt_tray_supported"

///|
#borrow(icon_path, ok)
extern "c" fn ffi_tray_new(icon_path : Bytes, ok : Ref[Int]) -> Tray = "yue_mbt_tray_new"

///|
#borrow(tray, title)
extern "c" fn ffi_tray_set_title(tray : Tray, title : Bytes) -> Unit = "yue_mbt_tray_set_title"

///|
#borrow(tray)
extern "c" fn ffi_tray_remove(tray : Tray) -> Unit = "yue_mbt_tray_remove"

///|
// String -> UTF-8 Bytes 的统一出口：MoonBit String 是 UTF-16，
// FFI 边界上一律转成 C 侧期望的 UTF-8，转换成本留在库内。
fn utf8_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
// UTF-8 Bytes -> String：C 侧返回字符串时的统一入口。
fn from_utf8_bytes(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes)
}
