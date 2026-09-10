/*
 * moonbit-libyue 的 C ABI 边界（唯一稳定接口）。
 *
 * 分层约定：
 *   MoonBit 层(yue/*.mbt)  --extern-->  本头文件  --C++-->  libyue
 *
 * 句柄约定：
 * - View 系控件（Window/Container/Label/TextEdit/Button/Entry/Browser/MenuBar）
 *   统一为 void* 句柄，内部经 GetClassName() 运行时校验类型，错型即拒绝。
 * - Menu/MenuItem/FileDialog/Tray/Image/Canvas/AttributedText/Font 为独立句柄。
 * - Painter 仅在绘制回调期间有效，由回调参数借出，不得持有。
 * - 所有回调 trampoline 首参数为 closure 指针（MoonBit 注册表保活）。
 * - 字符串一律 UTF-8；成败状态经 int32_t* 出参（extern 不可返回可空）。
 */
#ifndef YUE_MBT_H
#define YUE_MBT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------- 应用生命周期 ---------- */

int32_t yue_mbt_app_init(void);
void yue_mbt_run(void);
void yue_mbt_quit(void);
int32_t yue_mbt_platform(void);

/* ---------- 窗口（句柄=View） ---------- */

void *yue_mbt_window_new_ex(int32_t frame, int32_t transparent);
void yue_mbt_window_set_title(void *window, const char *title);
void yue_mbt_window_set_always_on_top(void *window, int32_t top);
double yue_mbt_window_get_content_size_width(void *window);
double yue_mbt_window_get_content_size_height(void *window);
void yue_mbt_window_set_content(void *window, void *content);
void yue_mbt_window_set_content_size(void *window, double width, double height);
void yue_mbt_window_center(void *window);
void yue_mbt_window_activate(void *window);
void yue_mbt_window_set_menubar(void *window, void *menubar);
void yue_mbt_window_on_close(void *window, void (*invoke)(void *closure),
                             void *closure);

/* ---------- View 通用 ---------- */

void yue_mbt_view_focus(void *view);
void yue_mbt_view_set_enabled(void *view, int32_t enable);
void yue_mbt_view_set_mouse_down_can_move_window(void *view, int32_t yes);
/* style DSL 原样透传给 libyue（键名与官方一致：flex/flexDirection/padding/
 * width/marginLeft/marginRight/marginBottom...） */
void yue_mbt_view_set_style_prop_float(void *view, const char *name, double value);
void yue_mbt_view_set_style_prop_str(void *view, const char *name, const char *value);
void yue_mbt_view_set_background_color(void *view, const char *hex);

/* ---------- Container ---------- */

void *yue_mbt_container_new(void);
void yue_mbt_container_add_child(void *container, void *child);
/* on_draw 仅 Container 有。invoke(closure, painter)，
 * painter 为回调期借出的裸指针，不得持有。 */
void yue_mbt_container_on_draw(void *container,
                               void (*invoke)(void *closure, void *painter),
                               void *closure);

/* ---------- Label ---------- */

void *yue_mbt_label_new(const char *text);
void yue_mbt_label_set_text(void *label, const char *text);

/* ---------- TextEdit ---------- */

void *yue_mbt_text_edit_new(void);
void yue_mbt_text_edit_set_text(void *edit, const char *text);
void *yue_mbt_text_edit_get_text(void *edit);
double yue_mbt_text_edit_get_text_bounds_height(void *edit);
void yue_mbt_text_edit_on_text_change(void *edit,
                                      void (*invoke)(void *closure),
                                      void *closure);

/* ---------- Button ---------- */

void *yue_mbt_button_new(const char *title);
void yue_mbt_button_set_title(void *button, const char *title);
void yue_mbt_button_on_click(void *button, void (*invoke)(void *closure),
                             void *closure);

/* ---------- Entry ---------- */

void *yue_mbt_entry_new(void);
void yue_mbt_entry_set_text(void *entry, const char *text);
void *yue_mbt_entry_get_text(void *entry);

/* ---------- Browser（WebView） ---------- */

void *yue_mbt_browser_new(void);
void yue_mbt_browser_load_url(void *browser, const char *url);
void *yue_mbt_browser_get_url(void *browser);
void yue_mbt_browser_reload(void *browser);
void yue_mbt_browser_go_back(void *browser);
void yue_mbt_browser_go_forward(void *browser);
int32_t yue_mbt_browser_can_go_back(void *browser);
int32_t yue_mbt_browser_can_go_forward(void *browser);
int32_t yue_mbt_browser_is_loading(void *browser);
void yue_mbt_browser_on_change_loading(void *browser,
                                       void (*invoke)(void *closure),
                                       void *closure);
void yue_mbt_browser_on_update_command(void *browser,
                                       void (*invoke)(void *closure),
                                       void *closure);
void yue_mbt_browser_on_update_title(void *browser,
                                     void (*invoke)(void *closure, void *utf8),
                                     void *closure);
void yue_mbt_browser_on_commit_navigation(void *browser,
                                          void (*invoke)(void *closure, void *utf8),
                                          void *closure);
void yue_mbt_browser_on_finish_navigation(void *browser,
                                          void (*invoke)(void *closure, void *utf8),
                                          void *closure);

/* ---------- 菜单 ---------- */

/* 结构：MenuBar -AddMenu(title)-> Menu -Append-> MenuItem(Submenu 可嵌套)。
 * menu_bar_add_menu 在顶栏创建标题项并返回其子菜单句柄；
 * menu_add_submenu 在菜单内嵌套子菜单并返回子菜单句柄。 */
void *yue_mbt_menu_bar_new(void);
void *yue_mbt_menu_bar_add_menu(void *menubar, const char *title);
void *yue_mbt_menu_add_submenu(void *menu, const char *title);
void *yue_mbt_menu_add_label_item(void *menu, const char *label);
void *yue_mbt_menu_add_role_item(void *menu, int32_t role);
void *yue_mbt_menu_add_separator(void *menu);
void yue_mbt_menu_item_set_label(void *item, const char *label);
void yue_mbt_menu_item_set_accelerator(void *item, const char *accelerator);
void yue_mbt_menu_item_on_click(void *item, void (*invoke)(void *closure),
                                void *closure);

/* ---------- 文件对话框（句柄独立） ---------- */

void *yue_mbt_file_open_dialog_new(void);
void *yue_mbt_file_save_dialog_new(void);
/* filters 打包格式："描述:扩展1,扩展2|描述2:扩展3" */
void yue_mbt_file_dialog_set_filters(void *dialog, const char *filters);
void yue_mbt_file_dialog_set_folder(void *dialog, const char *folder);
void yue_mbt_file_dialog_set_filename(void *dialog, const char *filename);
int32_t yue_mbt_file_dialog_run_for_window(void *dialog, void *window);
void *yue_mbt_file_dialog_get_result(void *dialog);

/* ---------- 文件 IO（文本语义，见 README） ---------- */

void *yue_mbt_read_file(const char *path, int32_t *ok);
void yue_mbt_write_file(const char *path, const void *data, int32_t len,
                        int32_t *ok);

/* ---------- Painter（仅绘制回调期内有效，裸指针借出） ---------- */

void yue_mbt_painter_save(void *painter);
void yue_mbt_painter_restore(void *painter);
void yue_mbt_painter_begin_path(void *painter);
void yue_mbt_painter_close_path(void *painter);
void yue_mbt_painter_move_to(void *painter, double x, double y);
void yue_mbt_painter_line_to(void *painter, double x, double y);
void yue_mbt_painter_bezier_curve_to(void *painter, double cp1x, double cp1y,
                                     double cp2x, double cp2y, double x,
                                     double y);
void yue_mbt_painter_arc(void *painter, double x, double y, double radius,
                         double start_angle, double end_angle, int32_t ccw);
void yue_mbt_painter_fill(void *painter);
void yue_mbt_painter_stroke(void *painter);
void yue_mbt_painter_clip_rect(void *painter, double x, double y, double w,
                               double h);
void yue_mbt_painter_fill_rect(void *painter, double x, double y, double w,
                               double h);
void yue_mbt_painter_stroke_rect(void *painter, double x, double y, double w,
                                 double h);
void yue_mbt_painter_set_fill_color(void *painter, const char *hex);
void yue_mbt_painter_set_stroke_color(void *painter, const char *hex);
void yue_mbt_painter_translate(void *painter, double dx, double dy);
void yue_mbt_painter_scale(void *painter, double sx, double sy);
void yue_mbt_painter_rotate(void *painter, double angle);
void yue_mbt_painter_draw_text(void *painter, const char *text, double x,
                               double y, double w, double h, int32_t align,
                               int32_t valign, const char *hex_color);
void yue_mbt_painter_draw_attributed_text(void *painter, void *attributed_text,
                                          double x, double y, double w,
                                          double h);
void yue_mbt_painter_draw_image(void *painter, void *image, double x, double y,
                                double w, double h);
void yue_mbt_painter_draw_image_from_rect(void *painter, void *image,
                                          double sx, double sy, double sw,
                                          double sh, double dx, double dy,
                                          double dw, double dh);
void yue_mbt_painter_draw_canvas(void *painter, void *canvas, double x,
                                 double y, double w, double h);
void yue_mbt_painter_draw_canvas_from_rect(void *painter, void *canvas,
                                           double sx, double sy, double sw,
                                           double sh, double dx, double dy,
                                           double dw, double dh);

/* ---------- Canvas / AttributedText / Font / Image（句柄独立） ---------- */

void *yue_mbt_canvas_new(double width, double height);
void *yue_mbt_canvas_get_painter(void *canvas);
void *yue_mbt_attributed_text_new(const char *text, int32_t align,
                                  int32_t valign);
void yue_mbt_attributed_text_set_font(void *at, void *font);
void yue_mbt_attributed_text_set_color(void *at, const char *hex);
/* 出参 w/h 返回按 size 布局后的文本包围盒 */
void yue_mbt_attributed_text_get_bounds_for(void *at, double w, double h,
                                            double *out_w, double *out_h);
void *yue_mbt_font_new(const char *name, double size, int32_t weight,
                       int32_t style);
void *yue_mbt_image_new_from_file(const char *path);
double yue_mbt_image_get_width(void *image);
double yue_mbt_image_get_height(void *image);

/* ---------- Table（表格；模型桥见下） ---------- */

void *yue_mbt_table_new(void);
void yue_mbt_table_add_column_text(void *table, const char *title, int32_t width);
void yue_mbt_table_add_column_edit(void *table, const char *title, int32_t width);
void yue_mbt_table_add_column_checkbox(void *table, const char *title, int32_t width);
/* 自定义列：draw(closure, painter, x, y, w, h, name_utf8, color_utf8)，
 * name/color 由模型 get_value 提供的字典键解析而来。 */
void yue_mbt_table_add_column_custom(void *table, const char *title, int32_t width,
                                     void (*draw)(void *closure, void *painter, double x,
                                                  double y, double w, double h,
                                                  void *name_utf8, void *color_utf8),
                                     void *closure);
void yue_mbt_table_set_has_border(void *table, int32_t yes);

/* 模型桥：把 MoonBit 的 TableModel trait 挂到 libyue 的 AbstractTableModel。
 * get_value 返回 MoonBit Bytes，编码 [kind:i32le][payload]：
 *   kind=0 payload 为 UTF-8 文本（Text/Edit 列）
 *   kind=1 payload 单字节 0/1（Checkbox 列）
 *   kind=2 payload 为 UTF-8 文本 + \0 + 颜色 hex（Custom 列）
 * set_value 的 kind/flag：kind=1 时 flag 为 0/1，否则 data 为 UTF-8 文本。 */
void *yue_mbt_table_model_new(int32_t column_count, void *closure,
                              uint32_t (*row_count)(void *closure),
                              void *(*get_value)(void *closure, uint32_t column, uint32_t row),
                              void (*set_value)(void *closure, uint32_t column, uint32_t row,
                                                int32_t kind, void *data, int32_t flag));
void yue_mbt_table_set_model(void *table, void *model);

/* ---------- 拖放（DraggingInfo 仅拖拽回调期内有效，裸指针借出） ---------- */

/* 数据种类：1=Text 2=HTML 3=Image 4=FilePaths（与 Clipboard::Data::Type 一致） */
int32_t yue_mbt_dragging_is_available(void *info, int32_t kind);
/* 返回编码 Bytes [kind:i32le][payload]：
 *   1/2 payload 为 UTF-8 文本；4 payload 为 UTF-8 文本（路径 \n 连接）；
 *   3 payload 为 Image 句柄 i64（由注册表托管）。 */
void *yue_mbt_dragging_get_data(void *info, int32_t kind);
int32_t yue_mbt_dragging_get_operations(void *info);

/* ---------- View 拖放 ---------- */

/* kinds 打包为 [k0:i32le][k1:i32le]... */
void yue_mbt_view_register_dragged_types(void *view, const int32_t *kinds, int32_t len);
/* 发起文件拖动：paths 为 UTF-8 文本（路径 \n 连接），drag_image 为拖动预览图
 * 句柄（0 表示无）。阻塞至拖动结束，返回拖动操作。 */
int32_t yue_mbt_view_do_drag_file_paths(void *view, const char *paths,
                                        int32_t operations, int64_t drag_image);
/* 委托回调：invoke(closure, info, x, y) 返回拖动操作（drop 返回 0/1 表示接受） */
void yue_mbt_view_handle_drag_enter(void *view,
    int32_t (*invoke)(void *closure, void *info, double x, double y), void *closure);
void yue_mbt_view_handle_drag_update(void *view,
    int32_t (*invoke)(void *closure, void *info, double x, double y), void *closure);
void yue_mbt_view_handle_drop(void *view,
    int32_t (*invoke)(void *closure, void *info, double x, double y), void *closure);
void yue_mbt_view_on_drag_leave(void *view, void (*invoke)(void *), void *closure);

void yue_mbt_view_schedule_paint(void *view);
/* 鼠标按下（Responder 信号）：callback 返回 true 表示事件已处理。
 * invoke(closure, modifiers, button_flags)——精简为仅回调无参版本，
 * 拖拽发起不需要修饰键信息。 */
void yue_mbt_view_on_mouse_down(void *view,
                                int32_t (*invoke)(void *closure), void *closure);
/* 视图边界（相对自身坐标系的尺寸 + 原点） */
double yue_mbt_view_get_bounds_x(void *view);
double yue_mbt_view_get_bounds_y(void *view);
double yue_mbt_view_get_bounds_width(void *view);
double yue_mbt_view_get_bounds_height(void *view);
void *yue_mbt_image_from_handle(int64_t h);
int64_t yue_mbt_image_to_handle(void *image);
void yue_mbt_painter_set_color(void *painter, const char *hex);

/* ---------- 组合控件（Slider/Picker/ComboBox/ProgressBar/Popover） ---------- */

void *yue_mbt_slider_new(void);
void yue_mbt_slider_set_value(void *slider, double value);
double yue_mbt_slider_get_value(void *slider);
void yue_mbt_slider_set_step(void *slider, double step);
void yue_mbt_slider_set_range(void *slider, double min, double max);
void yue_mbt_slider_on_value_change(void *slider, void (*invoke)(void *), void *closure);
void yue_mbt_slider_on_sliding_complete(void *slider, void (*invoke)(void *), void *closure);

void *yue_mbt_picker_new(void);
void yue_mbt_picker_add_item(void *picker, const char *text);
void yue_mbt_picker_remove_item_at(void *picker, int32_t index);
void yue_mbt_picker_clear(void *picker);
void yue_mbt_picker_select_item_at(void *picker, int32_t index);
void *yue_mbt_picker_get_selected_item(void *picker);
int32_t yue_mbt_picker_get_selected_item_index(void *picker);
void yue_mbt_picker_on_selection_change(void *picker, void (*invoke)(void *), void *closure);

void *yue_mbt_combo_box_new(void);
void yue_mbt_combo_box_set_text(void *combobox, const char *text);
void *yue_mbt_combo_box_get_text(void *combobox);
void yue_mbt_combo_box_on_text_change(void *combobox, void (*invoke)(void *), void *closure);

void *yue_mbt_progress_bar_new(void);
void yue_mbt_progress_bar_set_value(void *bar, double value);
void yue_mbt_progress_bar_set_indeterminate(void *bar, int32_t yes);

void *yue_mbt_popover_new(void);
void yue_mbt_popover_set_content(void *popover, void *content);
void yue_mbt_popover_set_content_size(void *popover, double w, double h);
void yue_mbt_popover_show_relative_to(void *popover, void *view);
void yue_mbt_popover_close(void *popover);
void yue_mbt_popover_on_close(void *popover, void (*invoke)(void *), void *closure);

/* ---------- Group / Scroll / Separator ---------- */

void *yue_mbt_group_new(const char *title);
void yue_mbt_group_set_content(void *group, void *view);
void yue_mbt_group_set_title(void *group, const char *title);

void *yue_mbt_scroll_new(void);
void yue_mbt_scroll_set_content(void *scroll, void *view);
void yue_mbt_scroll_set_content_size(void *scroll, double w, double h);
void yue_mbt_scroll_set_scroll_position(void *scroll, double horizon, double vertical);
void yue_mbt_scroll_set_overlay_scrollbar(void *scroll, int32_t yes);

void *yue_mbt_separator_new(int32_t orientation);

/* ---------- 剪贴板（句柄独立） ---------- */

void *yue_mbt_clipboard_get(void);
void yue_mbt_clipboard_set_text(void *clipboard, const char *text);
void *yue_mbt_clipboard_get_text(void *clipboard);
void yue_mbt_clipboard_clear(void *clipboard);

/* ---------- 消息框（句柄独立；type 0=None 1=Information 2=Warning 3=Error） ---------- */

void *yue_mbt_message_box_new(int32_t type);
void yue_mbt_message_box_set_title(void *box, const char *title);
void yue_mbt_message_box_set_text(void *box, const char *text);
void yue_mbt_message_box_set_informative_text(void *box, const char *text);
void yue_mbt_message_box_add_button(void *box, const char *title, int32_t response);
void yue_mbt_message_box_on_response(void *box,
                                     void (*invoke)(void *closure, int32_t response),
                                     void *closure);
void yue_mbt_message_box_show(void *box);
void yue_mbt_message_box_show_for_window(void *box, void *window);
void yue_mbt_message_box_close(void *box);

/* ---------- 通知 / 全局快捷键 / 日期选择 / GIF 播放 ---------- */

/* Notification 句柄独立；经系统通知中心弹出 */
void *yue_mbt_notification_new(void);
void yue_mbt_notification_set_title(void *n, const char *title);
void yue_mbt_notification_set_body(void *n, const char *body);
void yue_mbt_notification_set_silent(void *n, int32_t silent);
void yue_mbt_notification_show(void *n);
void yue_mbt_notification_close(void *n);
void yue_mbt_notification_center_add(void *n);

/* GlobalShortcut 单例：register 返回 id */
int32_t yue_mbt_global_shortcut_register(const char *accelerator,
                                         void (*invoke)(void *), void *closure);
void yue_mbt_global_shortcut_unregister(int32_t id);

void *yue_mbt_date_picker_new(void);

void *yue_mbt_gif_player_new(void);
void yue_mbt_gif_player_set_image(void *player, void *image);

/* ---------- 托盘 ---------- */

int32_t yue_mbt_tray_supported(void);
void *yue_mbt_tray_new(const char *icon_path, int32_t *ok);
void yue_mbt_tray_set_title(void *tray, const char *title);
void yue_mbt_tray_remove(void *tray);

#ifdef __cplusplus
}
#endif

#endif /* YUE_MBT_H */
