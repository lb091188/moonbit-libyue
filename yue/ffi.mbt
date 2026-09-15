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
extern "c" fn ffi_window_new_ex(
  frame : Int,
  transparent : Int,
  no_activate : Int,
) -> View = "yue_mbt_window_new_ex"

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
  invoke : FuncRef[(() -> Unit) -> Unit],
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
extern "c" fn ffi_view_set_mouse_down_can_move_window(
  view : View,
  yes : Int,
) -> Unit = "yue_mbt_view_set_mouse_down_can_move_window"

///|
#borrow(view, name)
extern "c" fn ffi_view_set_style_prop_float(
  view : View,
  name : Bytes,
  value : Double,
) -> Unit = "yue_mbt_view_set_style_prop_float"

///|
#borrow(view, name, value)
extern "c" fn ffi_view_set_style_prop_str(
  view : View,
  name : Bytes,
  value : Bytes,
) -> Unit = "yue_mbt_view_set_style_prop_str"

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
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_text_edit_on_text_change"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_can_undo(edit : View) -> Int = "yue_mbt_text_edit_can_undo"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_undo(edit : View) -> Unit = "yue_mbt_text_edit_undo"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_can_redo(edit : View) -> Int = "yue_mbt_text_edit_can_redo"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_redo(edit : View) -> Unit = "yue_mbt_text_edit_redo"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_cut(edit : View) -> Unit = "yue_mbt_text_edit_cut"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_copy(edit : View) -> Unit = "yue_mbt_text_edit_copy"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_paste(edit : View) -> Unit = "yue_mbt_text_edit_paste"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_select_all(edit : View) -> Unit = "yue_mbt_text_edit_select_all"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_select_range(
  edit : View,
  start : Int,
  end : Int,
) -> Unit = "yue_mbt_text_edit_select_range"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_get_text_in_range(
  edit : View,
  start : Int,
  end : Int,
) -> Bytes = "yue_mbt_text_edit_get_text_in_range"

///|
#borrow(edit, text)
extern "c" fn ffi_text_edit_insert_text(edit : View, text : Bytes) -> Unit = "yue_mbt_text_edit_insert_text"

///|
#borrow(edit, text)
extern "c" fn ffi_text_edit_insert_text_at(
  edit : View,
  text : Bytes,
  pos : Int,
) -> Unit = "yue_mbt_text_edit_insert_text_at"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_delete(edit : View) -> Unit = "yue_mbt_text_edit_delete"

///|
#borrow(edit)
extern "c" fn ffi_text_edit_delete_range(
  edit : View,
  start : Int,
  end : Int,
) -> Unit = "yue_mbt_text_edit_delete_range"

///|
#borrow(title)
extern "c" fn ffi_button_new(title : Bytes) -> View = "yue_mbt_button_new"

///|
#borrow(title)
extern "c" fn ffi_button_new_typed(title : Bytes, type_ : Int) -> View = "yue_mbt_button_new_typed"

///|
extern "c" fn ffi_button_set_checked(button : View, checked : Int) -> Unit = "yue_mbt_button_set_checked"

///|
extern "c" fn ffi_button_is_checked(button : View) -> Int = "yue_mbt_button_is_checked"

///|
#borrow(button, title)
extern "c" fn ffi_button_set_title(button : View, title : Bytes) -> Unit = "yue_mbt_button_set_title"

///|
#borrow(button, invoke, callback)
extern "c" fn ffi_button_on_click(
  button : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_button_on_click"

///|
extern "c" fn ffi_entry_new() -> View = "yue_mbt_entry_new"

///|
extern "c" fn ffi_entry_new_typed(type_ : Int) -> View = "yue_mbt_entry_new_typed"

///|
#borrow(entry, text)
extern "c" fn ffi_entry_set_text(entry : View, text : Bytes) -> Unit = "yue_mbt_entry_set_text"

///|
#borrow(entry)
extern "c" fn ffi_entry_get_text(entry : View) -> Bytes = "yue_mbt_entry_get_text"

///|
#borrow(entry, invoke, callback)
extern "c" fn ffi_entry_on_text_change(
  entry : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_entry_on_text_change"

///|
#borrow(entry, invoke, callback)
extern "c" fn ffi_entry_on_activate(
  entry : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_entry_on_activate"

///|
extern "c" fn ffi_tab_new() -> View = "yue_mbt_tab_new"

///|
#borrow(tab, title)
extern "c" fn ffi_tab_add_page(tab : View, title : Bytes, view : View) -> Unit = "yue_mbt_tab_add_page"

///|
#borrow(tab)
extern "c" fn ffi_tab_remove_page(tab : View, view : View) -> Unit = "yue_mbt_tab_remove_page"

///|
#borrow(tab)
extern "c" fn ffi_tab_page_count(tab : View) -> Int = "yue_mbt_tab_page_count"

///|
#borrow(tab)
extern "c" fn ffi_tab_select_page_at(tab : View, index : Int) -> Unit = "yue_mbt_tab_select_page_at"

///|
#borrow(tab)
extern "c" fn ffi_tab_selected_page_index(tab : View) -> Int = "yue_mbt_tab_selected_page_index"

///|
#borrow(tab, invoke, callback)
extern "c" fn ffi_tab_on_selected_page_change(
  tab : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_tab_on_selected_page_change"

///|
extern "c" fn ffi_browser_new_ex(
  devtools : Int,
  context_menu : Int,
  allow_file_access : Int,
  hardware_acceleration : Int,
) -> View = "yue_mbt_browser_new_ex"

///|
#borrow(browser, url, invoke, callback)
extern "c" fn ffi_browser_get_cookies_for_url(
  browser : View,
  url : Bytes,
  invoke : FuncRef[((Bytes) -> Unit, Bytes) -> Unit],
  callback : (Bytes) -> Unit,
) -> Unit = "yue_mbt_browser_get_cookies_for_url"

///|
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
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_browser_on_change_loading"

///|
#borrow(browser, invoke, callback)
extern "c" fn ffi_browser_on_update_command(
  browser : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
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
#borrow(menu, label)
extern "c" fn ffi_menu_add_check_item(menu : Menu, label : Bytes) -> MenuItem = "yue_mbt_menu_add_check_item"

///|
#borrow(menu, label)
extern "c" fn ffi_menu_add_radio_item(menu : Menu, label : Bytes) -> MenuItem = "yue_mbt_menu_add_radio_item"

///|
extern "c" fn ffi_menu_item_set_checked(item : MenuItem, checked : Int) -> Unit = "yue_mbt_menu_item_set_checked"

///|
extern "c" fn ffi_menu_item_is_checked(item : MenuItem) -> Int = "yue_mbt_menu_item_is_checked"

///|
///|
#borrow(item, label)
extern "c" fn ffi_menu_item_set_label(item : MenuItem, label : Bytes) -> Unit = "yue_mbt_menu_item_set_label"

///|
#borrow(item, accelerator)
extern "c" fn ffi_menu_item_set_accelerator(
  item : MenuItem,
  accelerator : Bytes,
) -> Unit = "yue_mbt_menu_item_set_accelerator"

///|
#borrow(item, invoke, callback)
extern "c" fn ffi_menu_item_on_click(
  item : MenuItem,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_menu_item_on_click"

///|
extern "c" fn ffi_file_open_dialog_new() -> FileDialog = "yue_mbt_file_open_dialog_new"

///|
#borrow(dialog)
extern "c" fn ffi_file_dialog_set_options(
  dialog : FileDialog,
  options : Int,
) -> Unit = "yue_mbt_file_dialog_set_options"

///|
///|
extern "c" fn ffi_file_save_dialog_new() -> FileDialog = "yue_mbt_file_save_dialog_new"

///|
#borrow(dialog, filters)
extern "c" fn ffi_file_dialog_set_filters(
  dialog : FileDialog,
  filters : Bytes,
) -> Unit = "yue_mbt_file_dialog_set_filters"

///|
#borrow(dialog, folder)
extern "c" fn ffi_file_dialog_set_folder(
  dialog : FileDialog,
  folder : Bytes,
) -> Unit = "yue_mbt_file_dialog_set_folder"

///|
#borrow(dialog, filename)
extern "c" fn ffi_file_dialog_set_filename(
  dialog : FileDialog,
  filename : Bytes,
) -> Unit = "yue_mbt_file_dialog_set_filename"

///|
#borrow(dialog, window)
extern "c" fn ffi_file_dialog_run_for_window(
  dialog : FileDialog,
  window : View,
) -> Int = "yue_mbt_file_dialog_run_for_window"

///|
#borrow(dialog)
extern "c" fn ffi_file_dialog_get_result(dialog : FileDialog) -> Bytes = "yue_mbt_file_dialog_get_result"

///|
#borrow(path, ok)
extern "c" fn ffi_read_file(path : Bytes, ok : Ref[Int]) -> Bytes = "yue_mbt_read_file"

///|
#borrow(path, data, ok)
extern "c" fn ffi_write_file(
  path : Bytes,
  data : Bytes,
  len : Int,
  ok : Ref[Int],
) -> Unit = "yue_mbt_write_file"

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
extern "c" fn ffi_painter_move_to(
  painter : Painter,
  x : Double,
  y : Double,
) -> Unit = "yue_mbt_painter_move_to"

///|
#borrow(painter)
extern "c" fn ffi_painter_line_to(
  painter : Painter,
  x : Double,
  y : Double,
) -> Unit = "yue_mbt_painter_line_to"

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
extern "c" fn ffi_painter_clip_rect(
  painter : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_painter_clip_rect"

///|
#borrow(painter)
extern "c" fn ffi_painter_fill_rect(
  painter : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_painter_fill_rect"

///|
#borrow(painter)
extern "c" fn ffi_painter_stroke_rect(
  painter : Painter,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_painter_stroke_rect"

///|
#borrow(painter, hex)
extern "c" fn ffi_painter_set_fill_color(
  painter : Painter,
  hex : Bytes,
) -> Unit = "yue_mbt_painter_set_fill_color"

///|
#borrow(painter, hex)
extern "c" fn ffi_painter_set_stroke_color(
  painter : Painter,
  hex : Bytes,
) -> Unit = "yue_mbt_painter_set_stroke_color"

///|
#borrow(painter)
extern "c" fn ffi_painter_translate(
  painter : Painter,
  dx : Double,
  dy : Double,
) -> Unit = "yue_mbt_painter_translate"

///|
#borrow(painter)
extern "c" fn ffi_painter_scale(
  painter : Painter,
  sx : Double,
  sy : Double,
) -> Unit = "yue_mbt_painter_scale"

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
extern "c" fn ffi_attributed_text_new(
  text : Bytes,
  align : Int,
  valign : Int,
  wrap : Int,
  ellipsis : Int,
) -> AttributedText = "yue_mbt_attributed_text_new"

///|
#borrow(at)
extern "c" fn ffi_attributed_text_set_format(
  at : AttributedText,
  align : Int,
  valign : Int,
  wrap : Int,
  ellipsis : Int,
) -> Unit = "yue_mbt_attributed_text_set_format"

///|
#borrow(at, font)
extern "c" fn ffi_attributed_text_set_font(
  at : AttributedText,
  font : Font,
) -> Unit = "yue_mbt_attributed_text_set_font"

///|
#borrow(at, font)
extern "c" fn ffi_attributed_text_set_font_for(
  at : AttributedText,
  font : Font,
  start : Int,
  end : Int,
) -> Unit = "yue_mbt_attributed_text_set_font_for"

///|
#borrow(at, hex)
extern "c" fn ffi_attributed_text_set_color(
  at : AttributedText,
  hex : Bytes,
) -> Unit = "yue_mbt_attributed_text_set_color"

///|
#borrow(at, hex)
extern "c" fn ffi_attributed_text_set_color_for(
  at : AttributedText,
  hex : Bytes,
  start : Int,
  end : Int,
) -> Unit = "yue_mbt_attributed_text_set_color_for"

///|
#borrow(at)
extern "c" fn ffi_attributed_text_get_text(at : AttributedText) -> Bytes = "yue_mbt_attributed_text_get_text"

///|
#borrow(at, text)
extern "c" fn ffi_attributed_text_set_text(
  at : AttributedText,
  text : Bytes,
) -> Unit = "yue_mbt_attributed_text_set_text"

///|
#borrow(at)
extern "c" fn ffi_attributed_text_clear(at : AttributedText) -> Unit = "yue_mbt_attributed_text_clear"

///|
extern "c" fn ffi_system_color(name : Int) -> Int = "yue_mbt_system_color"

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
extern "c" fn ffi_font_new(
  name : Bytes,
  size : Double,
  weight : Int,
  style : Int,
) -> Font = "yue_mbt_font_new"

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
extern "c" fn ffi_table_new() -> View = "yue_mbt_table_new"

///|
#borrow(table, title)
extern "c" fn ffi_table_add_column_with_options(
  table : View,
  title : Bytes,
  type_ : Int,
  column : Int,
  width : Int,
) -> Unit = "yue_mbt_table_add_column_with_options"

///|
///|
#borrow(table, title)
extern "c" fn ffi_table_add_column_text(
  table : View,
  title : Bytes,
  width : Int,
) -> Unit = "yue_mbt_table_add_column_text"

///|
#borrow(table, title)
extern "c" fn ffi_table_add_column_edit(
  table : View,
  title : Bytes,
  width : Int,
) -> Unit = "yue_mbt_table_add_column_edit"

///|
#borrow(table, title)
extern "c" fn ffi_table_add_column_checkbox(
  table : View,
  title : Bytes,
  width : Int,
) -> Unit = "yue_mbt_table_add_column_checkbox"

///|
#borrow(table, title, invoke, closure)
extern "c" fn ffi_table_add_column_custom(
  table : View,
  title : Bytes,
  width : Int,
  invoke : FuncRef[
    (
      (Painter, Double, Double, Double, Double, Bytes, Bytes) -> Unit,
      Painter,
      Double,
      Double,
      Double,
      Double,
      Bytes,
      Bytes,
    ) -> Unit,
  ],
  closure : (Painter, Double, Double, Double, Double, Bytes, Bytes) -> Unit,
) -> Unit = "yue_mbt_table_add_column_custom"

///|
#borrow(table)
extern "c" fn ffi_table_set_has_border(table : View, yes : Int) -> Unit = "yue_mbt_table_set_has_border"

///|
#borrow(table, closure, invoke_row_count, invoke_get_value, invoke_set_value)
extern "c" fn ffi_table_bind_model(
  table : View,
  column_count : Int,
  closure : ModelBox,
  invoke_row_count : FuncRef[(ModelBox) -> Int],
  invoke_get_value : FuncRef[(ModelBox, Int, Int) -> Bytes],
  invoke_set_value : FuncRef[(ModelBox, Int, Int, Int, Bytes, Int) -> Unit],
) -> Unit = "yue_mbt_table_bind_model"

///|
#borrow(info)
extern "c" fn ffi_dragging_is_available(info : DraggingInfo, kind : Int) -> Int = "yue_mbt_dragging_is_available"

///|
#borrow(info)
extern "c" fn ffi_dragging_get_data(info : DraggingInfo, kind : Int) -> Bytes = "yue_mbt_dragging_get_data"

///|
#borrow(info)
extern "c" fn ffi_dragging_get_operations(info : DraggingInfo) -> Int = "yue_mbt_dragging_get_operations"

///|
#borrow(view, kinds)
extern "c" fn ffi_view_register_dragged_types(
  view : View,
  kinds : Bytes,
  len : Int,
) -> Unit = "yue_mbt_view_register_dragged_types"

///|
#borrow(view, paths)
extern "c" fn ffi_view_do_drag_file_paths(
  view : View,
  paths : Bytes,
  operations : Int,
  drag_image : Int64,
) -> Int = "yue_mbt_view_do_drag_file_paths"

///|
#borrow(view, invoke, closure)
extern "c" fn ffi_view_handle_drag_enter(
  view : View,
  invoke : FuncRef[
    ((DraggingInfo, Double, Double) -> Int, DraggingInfo, Double, Double) -> Int,
  ],
  closure : (DraggingInfo, Double, Double) -> Int,
) -> Unit = "yue_mbt_view_handle_drag_enter"

///|
#borrow(view, invoke, closure)
extern "c" fn ffi_view_handle_drag_update(
  view : View,
  invoke : FuncRef[
    ((DraggingInfo, Double, Double) -> Int, DraggingInfo, Double, Double) -> Int,
  ],
  closure : (DraggingInfo, Double, Double) -> Int,
) -> Unit = "yue_mbt_view_handle_drag_update"

///|
#borrow(view, invoke, closure)
extern "c" fn ffi_view_handle_drop(
  view : View,
  invoke : FuncRef[
    ((DraggingInfo, Double, Double) -> Int, DraggingInfo, Double, Double) -> Int,
  ],
  closure : (DraggingInfo, Double, Double) -> Int,
) -> Unit = "yue_mbt_view_handle_drop"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_drag_leave(
  view : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_view_on_drag_leave"

///|
#borrow(view)
extern "c" fn ffi_view_schedule_paint(view : View) -> Unit = "yue_mbt_view_schedule_paint"

///|
#borrow(view)
extern "c" fn ffi_view_get_bounds_x(view : View) -> Double = "yue_mbt_view_get_bounds_x"

///|
#borrow(view)
extern "c" fn ffi_view_get_bounds_y(view : View) -> Double = "yue_mbt_view_get_bounds_y"

///|
#borrow(view)
extern "c" fn ffi_view_get_bounds_width(view : View) -> Double = "yue_mbt_view_get_bounds_width"

///|
#borrow(view)
extern "c" fn ffi_view_get_bounds_height(view : View) -> Double = "yue_mbt_view_get_bounds_height"

///|
#borrow(painter, hex)
extern "c" fn ffi_painter_set_color(painter : Painter, hex : Bytes) -> Unit = "yue_mbt_painter_set_color"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_mouse_down(
  view : View,
  invoke : FuncRef[
    (
      (Int, Double, Double, Double, Double, Int, Int) -> Int,
      Int,
      Double,
      Double,
      Double,
      Double,
      Int,
      Int,
    ) -> Int,
  ],
  callback : (Int, Double, Double, Double, Double, Int, Int) -> Int,
) -> Unit = "yue_mbt_view_on_mouse_down"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_mouse_up(
  view : View,
  invoke : FuncRef[
    (
      (Int, Double, Double, Double, Double, Int, Int) -> Int,
      Int,
      Double,
      Double,
      Double,
      Double,
      Int,
      Int,
    ) -> Int,
  ],
  callback : (Int, Double, Double, Double, Double, Int, Int) -> Int,
) -> Unit = "yue_mbt_view_on_mouse_up"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_mouse_move(
  view : View,
  invoke : FuncRef[
    (
      (Int, Double, Double, Double, Double, Int, Int) -> Unit,
      Int,
      Double,
      Double,
      Double,
      Double,
      Int,
      Int,
    ) -> Unit,
  ],
  callback : (Int, Double, Double, Double, Double, Int, Int) -> Unit,
) -> Unit = "yue_mbt_view_on_mouse_move"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_mouse_enter(
  view : View,
  invoke : FuncRef[
    (
      (Int, Double, Double, Double, Double, Int, Int) -> Unit,
      Int,
      Double,
      Double,
      Double,
      Double,
      Int,
      Int,
    ) -> Unit,
  ],
  callback : (Int, Double, Double, Double, Double, Int, Int) -> Unit,
) -> Unit = "yue_mbt_view_on_mouse_enter"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_mouse_leave(
  view : View,
  invoke : FuncRef[
    (
      (Int, Double, Double, Double, Double, Int, Int) -> Unit,
      Int,
      Double,
      Double,
      Double,
      Double,
      Int,
      Int,
    ) -> Unit,
  ],
  callback : (Int, Double, Double, Double, Double, Int, Int) -> Unit,
) -> Unit = "yue_mbt_view_on_mouse_leave"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_capture_lost(
  view : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_view_on_capture_lost"

///|
extern "c" fn ffi_view_set_capture(view : View) -> Unit = "yue_mbt_view_set_capture"

///|
extern "c" fn ffi_view_release_capture(view : View) -> Unit = "yue_mbt_view_release_capture"

///|
extern "c" fn ffi_view_has_capture(view : View) -> Int = "yue_mbt_view_has_capture"

///|
extern "c" fn ffi_mouse_location_x() -> Double = "yue_mbt_mouse_location_x"

///|
extern "c" fn ffi_mouse_location_y() -> Double = "yue_mbt_mouse_location_y"

///|
extern "c" fn ffi_is_shift_pressed() -> Int = "yue_mbt_is_shift_pressed"

///|
extern "c" fn ffi_is_control_pressed() -> Int = "yue_mbt_is_control_pressed"

///|
extern "c" fn ffi_is_alt_pressed() -> Int = "yue_mbt_is_alt_pressed"

///|
extern "c" fn ffi_is_meta_pressed() -> Int = "yue_mbt_is_meta_pressed"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_size_changed(
  view : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_view_on_size_changed"

///|
#borrow(view)
extern "c" fn ffi_view_get_computed_layout(view : View) -> Bytes = "yue_mbt_view_get_computed_layout"

///|
extern "c" fn ffi_view_offset_from_window_x(view : View) -> Double = "yue_mbt_view_offset_from_window_x"

///|
extern "c" fn ffi_view_offset_from_window_y(view : View) -> Double = "yue_mbt_view_offset_from_window_y"

///|
#borrow(view, from)
extern "c" fn ffi_view_offset_from_view_x(view : View, from : View) -> Double = "yue_mbt_view_offset_from_view_x"

///|
#borrow(view, from)
extern "c" fn ffi_view_offset_from_view_y(view : View, from : View) -> Double = "yue_mbt_view_offset_from_view_y"

///|
extern "c" fn ffi_slider_new() -> View = "yue_mbt_slider_new"

///|
#borrow(slider)
extern "c" fn ffi_slider_set_value(slider : View, value : Double) -> Unit = "yue_mbt_slider_set_value"

///|
#borrow(slider)
extern "c" fn ffi_slider_get_value(slider : View) -> Double = "yue_mbt_slider_get_value"

///|
#borrow(slider)
extern "c" fn ffi_slider_set_step(slider : View, step : Double) -> Unit = "yue_mbt_slider_set_step"

///|
#borrow(slider)
extern "c" fn ffi_slider_set_range(
  slider : View,
  min : Double,
  max : Double,
) -> Unit = "yue_mbt_slider_set_range"

///|
#borrow(slider, invoke, callback)
extern "c" fn ffi_slider_on_value_change(
  slider : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_slider_on_value_change"

///|
#borrow(slider, invoke, callback)
extern "c" fn ffi_slider_on_sliding_complete(
  slider : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_slider_on_sliding_complete"

///|
extern "c" fn ffi_picker_new() -> View = "yue_mbt_picker_new"

///|
#borrow(picker, text)
extern "c" fn ffi_picker_add_item(picker : View, text : Bytes) -> Unit = "yue_mbt_picker_add_item"

///|
#borrow(picker)
extern "c" fn ffi_picker_remove_item_at(picker : View, index : Int) -> Unit = "yue_mbt_picker_remove_item_at"

///|
#borrow(picker)
extern "c" fn ffi_picker_clear(picker : View) -> Unit = "yue_mbt_picker_clear"

///|
#borrow(picker)
extern "c" fn ffi_picker_select_item_at(picker : View, index : Int) -> Unit = "yue_mbt_picker_select_item_at"

///|
#borrow(picker)
extern "c" fn ffi_picker_get_selected_item(picker : View) -> Bytes = "yue_mbt_picker_get_selected_item"

///|
#borrow(picker)
extern "c" fn ffi_picker_get_selected_item_index(picker : View) -> Int = "yue_mbt_picker_get_selected_item_index"

///|
#borrow(picker, invoke, callback)
extern "c" fn ffi_picker_on_selection_change(
  picker : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_picker_on_selection_change"

///|
extern "c" fn ffi_combo_box_new() -> View = "yue_mbt_combo_box_new"

///|
#borrow(combobox, text)
extern "c" fn ffi_combo_box_set_text(combobox : View, text : Bytes) -> Unit = "yue_mbt_combo_box_set_text"

///|
#borrow(combobox)
extern "c" fn ffi_combo_box_get_text(combobox : View) -> Bytes = "yue_mbt_combo_box_get_text"

///|
#borrow(combobox, invoke, callback)
extern "c" fn ffi_combo_box_on_text_change(
  combobox : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_combo_box_on_text_change"

///|
extern "c" fn ffi_progress_bar_new() -> View = "yue_mbt_progress_bar_new"

///|
#borrow(bar)
extern "c" fn ffi_progress_bar_set_value(bar : View, value : Double) -> Unit = "yue_mbt_progress_bar_set_value"

///|
#borrow(bar)
extern "c" fn ffi_progress_bar_set_indeterminate(bar : View, yes : Int) -> Unit = "yue_mbt_progress_bar_set_indeterminate"

///|
extern "c" fn ffi_popover_new() -> Popover = "yue_mbt_popover_new"

///|
#borrow(popover, content)
extern "c" fn ffi_popover_set_content(
  popover : Popover,
  content : View,
) -> Unit = "yue_mbt_popover_set_content"

///|
#borrow(popover)
extern "c" fn ffi_popover_set_content_size(
  popover : Popover,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_popover_set_content_size"

///|
#borrow(popover, view)
extern "c" fn ffi_popover_show_relative_to(
  popover : Popover,
  view : View,
) -> Unit = "yue_mbt_popover_show_relative_to"

///|
#borrow(popover)
extern "c" fn ffi_popover_close(popover : Popover) -> Unit = "yue_mbt_popover_close"

///|
#borrow(popover, invoke, callback)
extern "c" fn ffi_popover_on_close(
  popover : Popover,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_popover_on_close"

///|
#borrow(title)
extern "c" fn ffi_group_new(title : Bytes) -> View = "yue_mbt_group_new"

///|
#borrow(group, view)
extern "c" fn ffi_group_set_content(group : View, view : View) -> Unit = "yue_mbt_group_set_content"

///|
#borrow(group, title)
extern "c" fn ffi_group_set_title(group : View, title : Bytes) -> Unit = "yue_mbt_group_set_title"

///|
extern "c" fn ffi_scroll_new() -> View = "yue_mbt_scroll_new"

///|
#borrow(scroll, view)
extern "c" fn ffi_scroll_set_content(scroll : View, view : View) -> Unit = "yue_mbt_scroll_set_content"

///|
#borrow(scroll)
extern "c" fn ffi_scroll_set_content_size(
  scroll : View,
  w : Double,
  h : Double,
) -> Unit = "yue_mbt_scroll_set_content_size"

///|
#borrow(scroll)
extern "c" fn ffi_scroll_set_scroll_position(
  scroll : View,
  horizon : Double,
  vertical : Double,
) -> Unit = "yue_mbt_scroll_set_scroll_position"

///|
extern "c" fn ffi_scroll_set_scrollbar_policy(
  scroll : View,
  h : Int,
  v : Int,
) -> Unit = "yue_mbt_scroll_set_scrollbar_policy"

///|
extern "c" fn ffi_scroll_get_scrollbar_policy_x(scroll : View) -> Int = "yue_mbt_scroll_get_scrollbar_policy_x"

///|
extern "c" fn ffi_scroll_get_scrollbar_policy_y(scroll : View) -> Int = "yue_mbt_scroll_get_scrollbar_policy_y"

///|
///|
#borrow(scroll)
extern "c" fn ffi_scroll_set_overlay_scrollbar(
  scroll : View,
  yes : Int,
) -> Unit = "yue_mbt_scroll_set_overlay_scrollbar"

///|
#borrow(orientation)
extern "c" fn ffi_separator_new(orientation : Int) -> View = "yue_mbt_separator_new"

///|
extern "c" fn ffi_clipboard_get() -> Clipboard = "yue_mbt_clipboard_get"

///|
#borrow(clipboard, text)
extern "c" fn ffi_clipboard_set_text(
  clipboard : Clipboard,
  text : Bytes,
) -> Unit = "yue_mbt_clipboard_set_text"

///|
#borrow(clipboard)
extern "c" fn ffi_clipboard_get_text(clipboard : Clipboard) -> Bytes = "yue_mbt_clipboard_get_text"

///|
extern "c" fn ffi_clipboard_from_type(type_ : Int) -> Clipboard = "yue_mbt_clipboard_from_type"

///|
#borrow(clipboard, text)
extern "c" fn ffi_clipboard_set_data(
  clipboard : Clipboard,
  kind : Int,
  text : Bytes,
) -> Unit = "yue_mbt_clipboard_set_data"

///|
#borrow(clipboard, image)
extern "c" fn ffi_clipboard_set_data_image(
  clipboard : Clipboard,
  image : Image,
) -> Unit = "yue_mbt_clipboard_set_data_image"

///|
#borrow(clipboard)
extern "c" fn ffi_clipboard_get_data(
  clipboard : Clipboard,
  kind : Int,
) -> Bytes = "yue_mbt_clipboard_get_data"

///|
///|
#borrow(clipboard)
extern "c" fn ffi_clipboard_clear(clipboard : Clipboard) -> Unit = "yue_mbt_clipboard_clear"

///|
extern "c" fn ffi_message_box_new(type_ : Int) -> MessageBox = "yue_mbt_message_box_new"

///|
#borrow(box, title)
extern "c" fn ffi_message_box_set_title(
  box : MessageBox,
  title : Bytes,
) -> Unit = "yue_mbt_message_box_set_title"

///|
#borrow(box, text)
extern "c" fn ffi_message_box_set_text(box : MessageBox, text : Bytes) -> Unit = "yue_mbt_message_box_set_text"

///|
#borrow(box, text)
extern "c" fn ffi_message_box_set_informative_text(
  box : MessageBox,
  text : Bytes,
) -> Unit = "yue_mbt_message_box_set_informative_text"

///|
#borrow(box, title)
extern "c" fn ffi_message_box_add_button(
  box : MessageBox,
  title : Bytes,
  response : Int,
) -> Unit = "yue_mbt_message_box_add_button"

///|
#borrow(box, invoke, callback)
extern "c" fn ffi_message_box_on_response(
  box : MessageBox,
  invoke : FuncRef[((Int) -> Unit, Int) -> Unit],
  callback : (Int) -> Unit,
) -> Unit = "yue_mbt_message_box_on_response"

///|
#borrow(box)
extern "c" fn ffi_message_box_show(box : MessageBox) -> Unit = "yue_mbt_message_box_show"

///|
#borrow(box, window)
extern "c" fn ffi_message_box_show_for_window(
  box : MessageBox,
  window : View,
) -> Unit = "yue_mbt_message_box_show_for_window"

///|
#borrow(box)
extern "c" fn ffi_message_box_close(box : MessageBox) -> Unit = "yue_mbt_message_box_close"

///|
#borrow(notification, flat)
extern "c" fn ffi_notification_set_actions(
  notification : Notification,
  flat : Bytes,
) -> Unit = "yue_mbt_notification_set_actions"

///|
///|
extern "c" fn ffi_notification_new() -> Notification = "yue_mbt_notification_new"

///|
#borrow(n, title)
extern "c" fn ffi_notification_set_title(
  n : Notification,
  title : Bytes,
) -> Unit = "yue_mbt_notification_set_title"

///|
#borrow(n, body)
extern "c" fn ffi_notification_set_body(n : Notification, body : Bytes) -> Unit = "yue_mbt_notification_set_body"

///|
#borrow(n)
extern "c" fn ffi_notification_set_silent(
  n : Notification,
  silent : Int,
) -> Unit = "yue_mbt_notification_set_silent"

///|
#borrow(n)
extern "c" fn ffi_notification_show(n : Notification) -> Unit = "yue_mbt_notification_show"

///|
#borrow(n)
extern "c" fn ffi_notification_close(n : Notification) -> Unit = "yue_mbt_notification_close"

///|
#borrow(n)
extern "c" fn ffi_notification_center_add(n : Notification) -> Unit = "yue_mbt_notification_center_add"

///|
#borrow(accelerator, invoke, closure)
extern "c" fn ffi_global_shortcut_register(
  accelerator : Bytes,
  invoke : FuncRef[(() -> Unit) -> Unit],
  closure : () -> Unit,
) -> Int = "yue_mbt_global_shortcut_register"

///|
extern "c" fn ffi_global_shortcut_unregister(id : Int) -> Unit = "yue_mbt_global_shortcut_unregister"

///|
extern "c" fn ffi_date_picker_new() -> View = "yue_mbt_date_picker_new"

///|
extern "c" fn ffi_gif_player_new() -> View = "yue_mbt_gif_player_new"

///|
#borrow(player, image)
extern "c" fn ffi_gif_player_set_image(player : View, image : Image) -> Unit = "yue_mbt_gif_player_set_image"

///|
#borrow(name)
extern "c" fn ffi_app_set_name(name : Bytes) -> Unit = "yue_mbt_app_set_name"

///|
#borrow(name_buf)
extern "c" fn ffi_app_get_name(name_buf : Bytes) -> Int = "yue_mbt_app_get_name"

///|
extern "c" fn ffi_appearance_is_dark() -> Int = "yue_mbt_appearance_is_dark"

///|
/// 读取系统区域标识到容量 cap 的缓冲，返回实际长度。
#borrow(buf)
extern "c" fn ffi_locale_get(buf : Bytes, cap : Int) -> Int = "yue_mbt_locale_get"

///|
extern "c" fn ffi_screen_get_scale_factor() -> Double = "yue_mbt_screen_get_scale_factor"

///|
extern "c" fn ffi_screen_get_primary_width() -> Double = "yue_mbt_screen_get_primary_width"

///|
extern "c" fn ffi_screen_get_primary_height() -> Double = "yue_mbt_screen_get_primary_height"

///|
extern "c" fn ffi_notification_center_get() -> NotificationCenter = "yue_mbt_notification_center_get"

///|
#borrow(picker)
extern "c" fn ffi_date_picker_set_date(
  picker : View,
  epoch_seconds : Int64,
) -> Unit = "yue_mbt_date_picker_set_date"

///|
#borrow(picker)
extern "c" fn ffi_date_picker_get_date(picker : View) -> Int64 = "yue_mbt_date_picker_get_date"

///|
#borrow(picker, invoke, callback)
extern "c" fn ffi_date_picker_on_date_change(
  picker : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_date_picker_on_date_change"

///|
#borrow(table, invoke, callback)
extern "c" fn ffi_table_on_row_activate(
  table : View,
  invoke : FuncRef[((Int) -> Unit, Int) -> Unit],
  callback : (Int) -> Unit,
) -> Unit = "yue_mbt_table_on_row_activate"

///|
#borrow(table, invoke, callback)
extern "c" fn ffi_table_on_selection_change(
  table : View,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_table_on_selection_change"

///|
#borrow(table, invoke, callback)
extern "c" fn ffi_table_on_toggle_checkbox(
  table : View,
  invoke : FuncRef[((Int, Int) -> Unit, Int, Int) -> Unit],
  callback : (Int, Int) -> Unit,
) -> Unit = "yue_mbt_table_on_toggle_checkbox"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_key_down(
  view : View,
  invoke : FuncRef[((Int, Int, Int) -> Int, Int, Int, Int) -> Int],
  callback : (Int, Int, Int) -> Int,
) -> Unit = "yue_mbt_view_on_key_down"

///|
#borrow(view, invoke, callback)
extern "c" fn ffi_view_on_key_up(
  view : View,
  invoke : FuncRef[((Int, Int, Int) -> Int, Int, Int, Int) -> Int],
  callback : (Int, Int, Int) -> Int,
) -> Unit = "yue_mbt_view_on_key_up"

///|
#borrow(window)
extern "c" fn ffi_window_maximize(window : View) -> Unit = "yue_mbt_window_maximize"

///|
#borrow(window)
extern "c" fn ffi_window_unmaximize(window : View) -> Unit = "yue_mbt_window_unmaximize"

///|
#borrow(window)
extern "c" fn ffi_window_set_fullscreen(
  window : View,
  fullscreen : Int,
) -> Unit = "yue_mbt_window_set_fullscreen"

///|
#borrow(window)
extern "c" fn ffi_window_is_fullscreen(window : View) -> Int = "yue_mbt_window_is_fullscreen"

///|
extern "c" fn ffi_cursor_new(type_ : Int) -> Cursor = "yue_mbt_cursor_new"

///|
#borrow(view, cursor)
extern "c" fn ffi_view_set_cursor(view : View, cursor : Cursor) -> Unit = "yue_mbt_view_set_cursor"

///|
/// 托盘后端可用性探测。Linux 上等价于检查 AppIndicator 运行库能否加载。
extern "c" fn ffi_tray_supported() -> Bool = "yue_mbt_tray_supported"

///|
#borrow(icon_path, ok)
extern "c" fn ffi_tray_new(icon_path : Bytes, ok : Ref[Int]) -> NativeTray = "yue_mbt_tray_new"

///|
#borrow(tray, title)
extern "c" fn ffi_tray_set_title(tray : NativeTray, title : Bytes) -> Unit = "yue_mbt_tray_set_title"

///|
#borrow(tray)
extern "c" fn ffi_tray_remove(tray : NativeTray) -> Unit = "yue_mbt_tray_remove"

///|
extern "c" fn ffi_tray_set_image(tray : NativeTray, image : Image) -> Unit = "yue_mbt_tray_set_image"

///|
#borrow(tray, invoke, callback)
extern "c" fn ffi_tray_on_click(
  tray : NativeTray,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_tray_on_click"

///|
extern "c" fn ffi_tray_set_menu(tray : NativeTray, menu : Menu) -> Unit = "yue_mbt_tray_set_menu"

///|
extern "c" fn ffi_menu_new() -> Menu = "yue_mbt_menu_new"

///|
#borrow(menu)
extern "c" fn ffi_menu_popup_at(menu : Menu, x : Double, y : Double) -> Unit = "yue_mbt_menu_popup_at"

///|
#borrow(item, out)
extern "c" fn ffi_menu_item_get_label(
  item : MenuItem,
  out : Bytes,
  len : Int,
) -> Int = "yue_mbt_menu_item_get_label"

///|
extern "c" fn ffi_menu_item_get_type(item : MenuItem) -> Int = "yue_mbt_menu_item_get_type"

///|
extern "c" fn ffi_menu_item_is_enabled(item : MenuItem) -> Int = "yue_mbt_menu_item_is_enabled"

///|
extern "c" fn ffi_menu_item_click(item : MenuItem) -> Unit = "yue_mbt_menu_item_click"

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

///|
#borrow(invoke, callback)
extern "c" fn ffi_post_task(
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_post_task"

///|
#borrow(invoke, callback)
extern "c" fn ffi_post_delayed_task(
  ms : Int,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Unit = "yue_mbt_post_delayed_task"

///|
#borrow(invoke, callback)
extern "c" fn ffi_set_timeout(
  ms : Int,
  invoke : FuncRef[(() -> Unit) -> Unit],
  callback : () -> Unit,
) -> Int = "yue_mbt_set_timeout"

///|
#borrow(invoke, callback)
extern "c" fn ffi_set_timer(
  ms : Int,
  invoke : FuncRef[(() -> Int) -> Int],
  callback : () -> Int,
) -> Unit = "yue_mbt_set_timer"

///|
extern "c" fn ffi_clear_timeout(id : Int) -> Unit = "yue_mbt_clear_timeout"

///|
#borrow(data)
extern "c" fn ffi_image_new_from_data(
  data : Bytes,
  len : Int,
  scale_factor : Double,
) -> Image = "yue_mbt_image_new_from_data"

///|
extern "c" fn ffi_image_is_empty(image : Image) -> Int = "yue_mbt_image_is_empty"

///|
extern "c" fn ffi_image_get_scale_factor(image : Image) -> Double = "yue_mbt_image_get_scale_factor"

///|
extern "c" fn ffi_image_resize(
  image : Image,
  w : Double,
  h : Double,
  scale_factor : Double,
) -> Image = "yue_mbt_image_resize"

///|
#borrow(image, format, path)
extern "c" fn ffi_image_write_to_file(
  image : Image,
  format : Bytes,
  path : Bytes,
) -> Int = "yue_mbt_image_write_to_file"

///|
extern "c" fn ffi_gif_player_set_scale(player : View, scale : Int) -> Unit = "yue_mbt_gif_player_set_scale"

///|
extern "c" fn ffi_gif_player_get_scale(player : View) -> Int = "yue_mbt_gif_player_get_scale"

///|
extern "c" fn ffi_painter_set_blend_mode(painter : Painter, mode : Int) -> Unit = "yue_mbt_painter_set_blend_mode"

///|
extern "c" fn ffi_menu_base_item_count(menu : Menu) -> Int = "yue_mbt_menu_base_item_count"

///|
extern "c" fn ffi_menu_base_item_at(menu : Menu, index : Int) -> MenuItem = "yue_mbt_menu_base_item_at"

///|
extern "c" fn ffi_menubar_item_count(menubar : MenuBar) -> Int = "yue_mbt_menu_base_item_count"

///|
extern "c" fn ffi_menubar_item_at(menubar : MenuBar, index : Int) -> MenuItem = "yue_mbt_menu_base_item_at"

///|
extern "c" fn ffi_date_picker_new_ex(elements : Int, has_stepper : Int) -> View = "yue_mbt_date_picker_new_ex"

///|
#borrow(browser, html, base_url)
extern "c" fn ffi_browser_load_html(
  browser : View,
  html : Bytes,
  base_url : Bytes,
) -> Unit = "yue_mbt_browser_load_html"

///|
#borrow(browser, agent)
extern "c" fn ffi_browser_set_user_agent(browser : View, agent : Bytes) -> Unit = "yue_mbt_browser_set_user_agent"

///|
#borrow(browser, code)
extern "c" fn ffi_browser_execute_javascript(
  browser : View,
  code : Bytes,
) -> Unit = "yue_mbt_browser_execute_javascript"

///|
extern "c" fn ffi_window_set_has_shadow(window : View, has : Int) -> Unit = "yue_mbt_window_set_has_shadow"

///|
extern "c" fn ffi_window_has_shadow(window : View) -> Int = "yue_mbt_window_has_shadow"

///|
extern "c" fn ffi_window_set_resizable(window : View, yes : Int) -> Unit = "yue_mbt_window_set_resizable"

///|
extern "c" fn ffi_window_is_resizable(window : View) -> Int = "yue_mbt_window_is_resizable"

///|
extern "c" fn ffi_window_set_maximizable(window : View, yes : Int) -> Unit = "yue_mbt_window_set_maximizable"

///|
extern "c" fn ffi_window_set_minimizable(window : View, yes : Int) -> Unit = "yue_mbt_window_set_minimizable"

///|
extern "c" fn ffi_window_is_maximized(window : View) -> Int = "yue_mbt_window_is_maximized"

///|
#borrow(window, invoke, callback)
extern "c" fn ffi_window_set_should_close(
  window : View,
  invoke : FuncRef[(() -> Int) -> Int],
  callback : () -> Int,
) -> Unit = "yue_mbt_window_set_should_close"

///|
#borrow(scheme, invoke, callback)
extern "c" fn ffi_browser_register_protocol(
  scheme : Bytes,
  invoke : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  callback : (Bytes) -> Bytes,
) -> Unit = "yue_mbt_browser_register_protocol"

///|
#borrow(scheme)
extern "c" fn ffi_browser_unregister_protocol(scheme : Bytes) -> Unit = "yue_mbt_browser_unregister_protocol"
