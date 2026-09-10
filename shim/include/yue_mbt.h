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

/* ---------- 托盘 ---------- */

int32_t yue_mbt_tray_supported(void);
void *yue_mbt_tray_new(const char *icon_path, int32_t *ok);
void yue_mbt_tray_set_title(void *tray, const char *title);
void yue_mbt_tray_remove(void *tray);

#ifdef __cplusplus
}
#endif

#endif /* YUE_MBT_H */
