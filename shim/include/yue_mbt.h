/*
 * moonbit-libyue 的 C ABI 边界（唯一稳定接口）。
 *
 * 分层约定：
 *   MoonBit 层(yue 源码)  --extern-->  本头文件  --C++-->  libyue
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
#include <string>
extern "C" {
#endif

/* ---------- 应用生命周期 ---------- */

int32_t yue_mbt_app_init(void);
void yue_mbt_run(void);
void yue_mbt_quit(void);
int32_t yue_mbt_platform(void);

/* ---------- 窗口（句柄=View） ---------- */

void *yue_mbt_window_new_ex(int32_t frame, int32_t transparent, int32_t no_activate);
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
void yue_mbt_view_set_visible(void *view, int visible);
void yue_mbt_view_schedule_paint(void *view);
void yue_mbt_view_set_borderless(void *view, int on);
void yue_mbt_view_layout(void *view);
void yue_mbt_view_set_font(void *view, void *font);
void yue_mbt_view_set_color(void *view, const char *hex);
void yue_mbt_label_set_align(void *label, int32_t align);

/* ---------- Container ---------- */

void *yue_mbt_container_new(void);
void yue_mbt_container_add_child(void *container, void *child);
/* on_draw 仅 Container 有。invoke(closure, painter)，
 * painter 为回调期借出的裸指针，不得持有。 */
void yue_mbt_container_on_draw(void *container,
                               void (*invoke)(void *closure, void *painter),
                               void *closure);
/* 滚动后强制重摆该容器子树的绝对坐标(Windows 原生 HWND 跟随) */
void yue_mbt_container_update_child_bounds(void *container);

/* ---------- Label ---------- */

void *yue_mbt_label_new(const char *text);
void *yue_mbt_label_get_text(void *label);
void yue_mbt_label_set_text(void *label, const char *text);

/* ---------- TextEdit ---------- */

void *yue_mbt_text_edit_new(void);
void yue_mbt_text_edit_set_text(void *edit, const char *text);
void *yue_mbt_text_edit_get_text(void *edit);
double yue_mbt_text_edit_get_text_bounds_height(void *edit);
void yue_mbt_text_edit_on_text_change(void *edit,
                                      void (*invoke)(void *closure),
                                      void *closure);
int32_t yue_mbt_text_edit_can_undo(void *edit);
void yue_mbt_text_edit_undo(void *edit);
int32_t yue_mbt_text_edit_can_redo(void *edit);
void yue_mbt_text_edit_redo(void *edit);
void yue_mbt_text_edit_cut(void *edit);
void yue_mbt_text_edit_copy(void *edit);
void yue_mbt_text_edit_paste(void *edit);
void yue_mbt_text_edit_select_all(void *edit);
void yue_mbt_text_edit_select_range(void *edit, int32_t start, int32_t end);
void *yue_mbt_text_edit_get_text_in_range(void *edit, int32_t start,
                                          int32_t end);
void yue_mbt_text_edit_insert_text(void *edit, const char *text);
void yue_mbt_text_edit_insert_text_at(void *edit, const char *text,
                                      int32_t pos);
void yue_mbt_text_edit_delete(void *edit);
void yue_mbt_text_edit_delete_range(void *edit, int32_t start, int32_t end);

/* ---------- Button ---------- */

void *yue_mbt_button_new(const char *title);
/* Button::Type：0=Normal 1=Checkbox 2=Radio（Disclosure 为 macOS 专属不暴露） */
void *yue_mbt_button_new_typed(const char *title, int32_t type);
void yue_mbt_button_set_checked(void *button, int32_t checked);
int32_t yue_mbt_button_is_checked(void *button);
void yue_mbt_button_set_title(void *button, const char *title);
void yue_mbt_button_on_click(void *button, void (*invoke)(void *closure),
                             void *closure);

/* ---------- Entry ---------- */

void *yue_mbt_entry_new(void);
void yue_mbt_apply_native_theme_css(const char *css);
void *yue_mbt_entry_new_ex(int32_t type, int32_t width_chars);
/* 设置光标位置(仅 Linux):index 负值=末尾;失焦归 0 使文本回滚首端。 */
void yue_mbt_entry_set_position(void *entry, int32_t index);
/* 前景/背景色(主题跟随):Linux 逐控件 CssProvider,Windows RichEdit
 * 消息通道,mac 空操作;fg/bg 为 #RRGGBB 十六进制串。 */
void yue_mbt_entry_set_colors(void *entry, const char *fg, const char *bg);
/* Entry::Type：0=Normal 1=Password */
void *yue_mbt_entry_new_typed(int32_t type);
void yue_mbt_entry_set_text(void *entry, const char *text);
void *yue_mbt_entry_get_text(void *entry);
void yue_mbt_entry_on_text_change(void *entry, void (*invoke)(void *closure),
                                  void *closure);
void yue_mbt_entry_on_activate(void *entry, void (*invoke)(void *closure),
                               void *closure);
/* ---------- Tab（句柄=View） ---------- */

void *yue_mbt_tab_new(void);
void yue_mbt_tab_add_page(void *tab, const char *title, void *view);
void yue_mbt_tab_remove_page(void *tab, void *view);
int32_t yue_mbt_tab_page_count(void *tab);
void yue_mbt_tab_select_page_at(void *tab, int32_t index);
int32_t yue_mbt_tab_selected_page_index(void *tab);
void yue_mbt_tab_on_selected_page_change(void *tab,
                                         void (*invoke)(void *closure),
                                         void *closure);

/* ---------- Browser（WebView） ---------- */

void yue_mbt_browser_load_html(void *browser, const char *html, const char *base_url);
void yue_mbt_browser_set_user_agent(void *browser, const char *agent);
void yue_mbt_browser_set_magnifiable(void *browser, int32_t yes);
int32_t yue_mbt_browser_is_magnifiable(void *browser);
int32_t yue_mbt_browser_is_loading(void *browser);
void yue_mbt_browser_execute_javascript(void *browser, const char *code);
/* 自定义协议注册：回调返回 [ok:i32][mime_len:i32][mime][content] 编码,ok=0 拒绝 */
void yue_mbt_browser_register_protocol(const char *scheme,
                                       void *(*invoke)(void *, void *), void *closure);
void yue_mbt_browser_unregister_protocol(const char *scheme);
void *yue_mbt_browser_new_ex(int32_t devtools, int32_t context_menu, int32_t allow_file_access, int32_t hardware_acceleration);
/* Cookie 回调：每行一条，字段 \x1f 分隔 name/value/domain/path/http_only/secure */
void yue_mbt_browser_get_cookies_for_url(void *browser, const char *url,
                                         void (*invoke)(void *closure, void *flat_bytes), void *closure);
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
void *yue_mbt_menu_add_check_item(void *menu, const char *label);
void *yue_mbt_menu_add_radio_item(void *menu, const char *label);
void yue_mbt_menu_item_set_checked(void *item, int32_t checked);
int32_t yue_mbt_menu_item_is_checked(void *item);
void yue_mbt_menu_item_set_label(void *item, const char *label);
void yue_mbt_menu_item_set_accelerator(void *item, const char *accelerator);
void yue_mbt_menu_item_on_click(void *item, void (*invoke)(void *closure),
                                void *closure);

/* ---------- 文件对话框（句柄独立） ---------- */

void *yue_mbt_file_open_dialog_new(void);
/* FileDialog::Option 位：1<<0=选文件夹 1<<1=多选 1<<2=显示隐藏 */
void yue_mbt_file_dialog_set_options(void *dialog, int32_t options);
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
void yue_mbt_painter_draw_text_ex(void *painter, const char *text, double x,
                                  double y, double w, double h, int32_t align,
                                  int32_t valign, const char *hex_color,
                                  int32_t wrap, int32_t ellipsis);
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
/* 导出画布位图（format: "png"/"jpeg";Windows GDI+ 编码器,其余平台恒 0） */
int32_t yue_mbt_canvas_write_to_file(void *canvas, const char *format, const char *path);
void *yue_mbt_attributed_text_new(const char *text, int32_t align,
                                  int32_t valign, int32_t wrap, int32_t ellipsis);
void yue_mbt_attributed_text_set_format(void *at, int32_t align,
                                        int32_t valign, int32_t wrap, int32_t ellipsis);
void yue_mbt_attributed_text_set_font(void *at, void *font);
/* 范围版属性（[start, end) 字符区间） */
void yue_mbt_attributed_text_set_font_for(void *at, void *font, int32_t start, int32_t end);
void yue_mbt_attributed_text_set_color(void *at, const char *hex);
void yue_mbt_attributed_text_set_color_for(void *at, const char *hex, int32_t start, int32_t end);
/* 返回 MoonBit Bytes（UTF-8 文本） */
void *yue_mbt_attributed_text_get_text(void *at);
void yue_mbt_attributed_text_set_text(void *at, const char *text);
void yue_mbt_attributed_text_clear(void *at);
/* Color::Name（0=Text 1=DisabledText 2=TextEditBackground 3=DisabledTextEditBackground
 * 4=Control 5=WindowBackground 6=Border）→ ARGB uint32 */
uint32_t yue_mbt_system_color(int32_t name);
/* 出参 w/h 返回按 size 布局后的文本包围盒 */
void yue_mbt_attributed_text_get_bounds_for(void *at, double w, double h,
                                            double *out_w, double *out_h);
void *yue_mbt_font_new(const char *name, double size, int32_t weight,
                       int32_t style);
void *yue_mbt_image_new_from_file(const char *path);
/* 从内存 PNG/JPEG 解码 */
void *yue_mbt_image_new_from_data(const void *data, int32_t len, double scale_factor);
int32_t yue_mbt_image_is_empty(void *image);
double yue_mbt_image_get_scale_factor(void *image);
void *yue_mbt_image_resize(void *image, double w, double h, double scale_factor);
int32_t yue_mbt_image_write_to_file(void *image, const char *format, const char *path);
/* 读当前帧像素为 SNI IconPixmap 的 ARGB32 大端序;dst 按 w*h*4 预分配 */
int32_t yue_mbt_image_read_argb32(void *image, uint8_t *dst);
double yue_mbt_image_get_width(void *image);
double yue_mbt_image_get_height(void *image);

/* ---------- Table（表格；模型桥见下） ---------- */

void *yue_mbt_table_new(void);
void yue_mbt_table_add_column_with_options(void *table, const char *title, int32_t type, int32_t column, int32_t width);
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
 * set_value 的 kind/flag：kind=1 时 flag 为 0/1，否则 data 为 UTF-8 文本。
 * 一次调用完成"创建模型桥 + 挂载到表格"。 */
void yue_mbt_table_bind_model(void *table, int32_t column_count, void *closure,
                              uint32_t (*row_count)(void *closure),
                              void *(*get_value)(void *closure, uint32_t column, uint32_t row),
                              void (*set_value)(void *closure, uint32_t column, uint32_t row,
                                                int32_t kind, void *data, int32_t flag));

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
/* ---------- 鼠标/键盘事件（Responder 信号，对照 events_and_delegates 指南） ---------- */

/* modifiers 一律归一化为 1=Shift 2=Ctrl 4=Alt 8=Meta（Linux 原始 GDK 位为
 * 1/4/8/1<<26，在实现侧收敛，MoonBit 层拿到跨平台一致语义）。
 * timestamp 为事件毫秒时间戳（系统启动起算）。 */
/* 鼠标事件：invoke(closure, button, view_x, view_y, window_x, window_y,
 * modifiers, timestamp)。button 语义：1=左 2=右 3=中（libyue 统一后的）。
 * down/up 返回 true 表示事件已处理（阻止默认行为）。 */
void yue_mbt_view_on_mouse_down(void *view,
    int32_t (*invoke)(void *closure, int32_t button, double view_x, double view_y,
                      double window_x, double window_y, double screen_x, double screen_y,
                      int32_t modifiers, int32_t timestamp),
    void *closure);
void yue_mbt_view_on_mouse_up(void *view,
    int32_t (*invoke)(void *closure, int32_t button, double view_x, double view_y,
                      double window_x, double window_y, double screen_x, double screen_y,
                      int32_t modifiers, int32_t timestamp),
    void *closure);
void yue_mbt_view_on_mouse_move(void *view,
    void (*invoke)(void *closure, int32_t button, double view_x, double view_y,
                   double window_x, double window_y, double screen_x, double screen_y,
                   int32_t modifiers, int32_t timestamp),
    void *closure);
void yue_mbt_view_on_mouse_enter(void *view,
    void (*invoke)(void *closure, int32_t button, double view_x, double view_y,
                   double window_x, double window_y, double screen_x, double screen_y,
                   int32_t modifiers, int32_t timestamp),
    void *closure);
void yue_mbt_view_on_mouse_leave(void *view,
    void (*invoke)(void *closure, int32_t button, double view_x, double view_y,
                   double window_x, double window_y, double screen_x, double screen_y,
                   int32_t modifiers, int32_t timestamp),
    void *closure);
/* 滚轮(Linux GTK):invoke(closure, delta_y),+1 下滚 / -1 上滚 / 平滑增量为累计值 */
void yue_mbt_view_on_wheel(void *view,
                           void (*invoke)(void *closure, double delta_y),
                           void *closure);
/* 键盘事件：invoke(closure, key_code, modifiers, timestamp) 返回是否已处理 */
void yue_mbt_view_on_key_down(void *view,
                              int32_t (*invoke)(void *closure, int32_t key_code, int32_t modifiers, int32_t timestamp),
                              void *closure);
void yue_mbt_view_on_key_up(void *view,
                            int32_t (*invoke)(void *closure, int32_t key_code, int32_t modifiers, int32_t timestamp),
                            void *closure);
/* 鼠标捕获（Responder）：捕获期间 move/up 事件持续送达捕获视图，直到释放或丢失 */
void yue_mbt_view_set_capture(void *view);
void yue_mbt_view_release_capture(void *view);
int32_t yue_mbt_view_has_capture(void *view);
void yue_mbt_view_on_capture_lost(void *view, void (*invoke)(void *), void *closure);
/* Event 静态查询：全局鼠标位置（屏幕坐标）与修饰键实时状态 */
double yue_mbt_mouse_location_x(void);
double yue_mbt_mouse_location_y(void);
int32_t yue_mbt_is_shift_pressed(void);
int32_t yue_mbt_is_control_pressed(void);
int32_t yue_mbt_is_alt_pressed(void);
int32_t yue_mbt_is_meta_pressed(void);
/* 视图尺寸变化信号 */
void yue_mbt_view_on_size_changed(void *view, void (*invoke)(void *), void *closure);
/* 返回 yoga 计算布局的文本转储（MoonBit Bytes，调试用） */
void *yue_mbt_view_get_computed_layout(void *view);
/* 视图间/视图到窗口的偏移（Vector2dF 拆传） */
double yue_mbt_view_offset_from_window_x(void *view);
double yue_mbt_view_offset_from_window_y(void *view);
double yue_mbt_view_offset_from_view_x(void *view, void *from);
double yue_mbt_view_offset_from_view_y(void *view, void *from);
/* 视图边界（相对自身坐标系的尺寸 + 原点） */
double yue_mbt_view_get_bounds_x(void *view);
double yue_mbt_view_get_bounds_y(void *view);
double yue_mbt_view_get_bounds_width(void *view);
double yue_mbt_view_get_bounds_height(void *view);
double yue_mbt_view_get_bounds_in_screen_x(void *view);
double yue_mbt_view_get_bounds_in_screen_y(void *view);
double yue_mbt_view_get_bounds_in_screen_width(void *view);
double yue_mbt_view_get_bounds_in_screen_height(void *view);
void *yue_mbt_image_from_handle(int64_t h);
int64_t yue_mbt_image_to_handle(void *image);
void yue_mbt_painter_set_color(void *painter, const char *hex);
void yue_mbt_painter_set_blend_mode(void *painter, int32_t mode);

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
/* 弹层窗口背景(主题跟随):仅 Windows 替代弹层(独立小窗)有意义,
 * 其余平台由全局接管 CSS 覆盖。hex 为 #RRGGBB。 */
void yue_mbt_popover_set_bg(void *popover, const char *hex);
void yue_mbt_popover_on_close(void *popover, void (*invoke)(void *), void *closure);
/* 标记弹层放弃键盘焦点(仅 Linux 有实现):accept=0 时弹层出现/点击
 * 均不夺走 X 焦点,供弹层展开期间持续键入的组件(可过滤下拉)使用。 */
void yue_mbt_popover_set_accept_focus(void *popover, int32_t accept);
/* 延迟回调(仅 Linux 有实现):挂到主循环下一拍,待决输入事件处理完
 * 之后执行;其余平台空操作。 */
void yue_mbt_call_delayed(int32_t ms, void (*invoke)(void *), void *closure);

/* ---------- Group / Scroll / Separator ---------- */

void *yue_mbt_group_new(const char *title);
void yue_mbt_group_set_content(void *group, void *view);
void yue_mbt_group_set_title(void *group, const char *title);

void *yue_mbt_scroll_new(void);
void yue_mbt_scroll_set_content(void *scroll, void *view);
void yue_mbt_scroll_set_content_size(void *scroll, double w, double h);
/* ScrollbarPolicy：0=Always 1=Never 2=Automatic */
void yue_mbt_scroll_set_scrollbar_policy(void *scroll, int32_t h, int32_t v);
int32_t yue_mbt_scroll_get_scrollbar_policy_x(void *scroll);
int32_t yue_mbt_scroll_get_scrollbar_policy_y(void *scroll);
void yue_mbt_scroll_set_scroll_position(void *scroll, double horizon, double vertical);
void yue_mbt_scroll_set_overlay_scrollbar(void *scroll, int32_t yes);

void *yue_mbt_separator_new(int32_t orientation);

/* ---------- 剪贴板（句柄独立） ---------- */

void *yue_mbt_clipboard_get(void);
void yue_mbt_clipboard_set_text(void *clipboard, const char *text);
void *yue_mbt_clipboard_get_text(void *clipboard);
void yue_mbt_clipboard_clear(void *clipboard);
/* Clipboard::Type：0=CopyPaste 1=Selection(Linux) */
void *yue_mbt_clipboard_from_type(int32_t type);
/* kind 1=Text 2=HTML 4=FilePaths(路径 \n 连接) */
void yue_mbt_clipboard_set_data(void *clipboard, int32_t kind, const char *text);
void yue_mbt_clipboard_set_data_image(void *clipboard, void *image);
/* 读单条数据：[kind:i32][payload] 编码（与拖拽数据一致） */
void *yue_mbt_clipboard_get_data(void *clipboard, int32_t kind);

// ---------- MessageLoop（定时器/任务，跨平台） ----------
void yue_mbt_post_task(void (*invoke)(void *), void *closure);
void yue_mbt_post_delayed_task(int32_t ms, void (*invoke)(void *), void *closure);
uint32_t yue_mbt_set_timeout(int32_t ms, void (*invoke)(void *), void *closure);
void yue_mbt_set_timer(int32_t ms, int32_t (*invoke)(void *), void *closure);
void yue_mbt_clear_timeout(uint32_t id);

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
void *yue_mbt_notification_center_get(void);
/* 通知按钮：[count:i32le]（[len:i32le title][len:i32le info]） */
void yue_mbt_notification_set_actions(void *notification, void *flat_bytes);
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

/* MenuBase 遍历（Menu/MenuBar 共用） */
int32_t yue_mbt_menu_base_item_count(void *menu);
void *yue_mbt_menu_base_item_at(void *menu, int32_t index);
/* elements 位组合：0xC0=年月 0xE0=年月日 0x0C=时分 0x0E=时分秒 */
void *yue_mbt_date_picker_new_ex(int32_t elements, int32_t has_stepper);
void *yue_mbt_date_picker_new(void);

void *yue_mbt_gif_player_new(void);
/* ImageScale：0=None 1=Fill 2=Down 3=UpOrDown */
void yue_mbt_gif_player_set_scale(void *player, int32_t scale);
int32_t yue_mbt_gif_player_get_scale(void *player);
void yue_mbt_gif_player_set_image(void *player, void *image);

/* ---------- App / Appearance / Locale / Screen ---------- */

void yue_mbt_app_set_name(const char *name);
/* 输出参数：name_buf 容量 256 */
int32_t yue_mbt_app_get_name(char *name_buf);
int32_t yue_mbt_appearance_is_dark(void);
/* 本地时区的今天,打包 Int64:y*10000+m*100+d */
int64_t yue_mbt_local_date(void);
/* 返回 UTF-8 字节到 buf，返回长度 */
int32_t yue_mbt_locale_get(char *buf, int32_t cap);
double yue_mbt_screen_get_scale_factor(void);
double yue_mbt_screen_get_primary_width(void);
double yue_mbt_screen_get_primary_height(void);

/* ---------- 追加：DatePicker 时间 / Table 信号 / 键盘 / 窗口状态 / Cursor ---------- */

/* 日期以 Unix epoch 秒传递（base::Time 的 ToTimeT/FromTimeT） */
void yue_mbt_date_picker_set_date(void *picker, int64_t epoch_seconds);
int64_t yue_mbt_date_picker_get_date(void *picker);
void yue_mbt_date_picker_on_date_change(void *picker, void (*invoke)(void *), void *closure);

/* Table 事件 */
void yue_mbt_table_on_row_activate(void *table,
                                   void (*invoke)(void *closure, int32_t row),
                                   void *closure);
void yue_mbt_table_on_selection_change(void *table, void (*invoke)(void *), void *closure);
void yue_mbt_table_on_toggle_checkbox(void *table,
                                      void (*invoke)(void *closure, int32_t column, int32_t row),
                                      void *closure);

/* 键盘事件声明见上方「鼠标/键盘事件」区 */

/* 窗口状态 */
void yue_mbt_window_set_has_shadow(void *window, int32_t has);
int32_t yue_mbt_window_has_shadow(void *window);
void yue_mbt_window_set_resizable(void *window, int32_t yes);
int32_t yue_mbt_window_is_resizable(void *window);
void yue_mbt_window_set_maximizable(void *window, int32_t yes);
void yue_mbt_window_set_minimizable(void *window, int32_t yes);
int32_t yue_mbt_window_is_maximized(void *window);
/* should_close 委托：返回 false 阻止关闭 */
void yue_mbt_window_set_should_close(void *window, int32_t (*invoke)(void *), void *closure);
void yue_mbt_window_maximize(void *window);
void yue_mbt_window_unmaximize(void *window);
void yue_mbt_window_set_fullscreen(void *window, int32_t fullscreen);
int32_t yue_mbt_window_is_fullscreen(void *window);

/* 光标：type 与 Cursor::Type 枚举一致（0=Default 1=Hand 2=Crosshair 3=Progress
 * 4=Text 5=NotAllowed 6=Help 7=Move 8=ResizeEW 9=ResizeNS 10=ResizeNESW 11=ResizeNWSE） */
void *yue_mbt_cursor_new(int32_t type);
void yue_mbt_view_set_cursor(void *view, void *cursor);

/* ---------- 托盘 ---------- */

int32_t yue_mbt_tray_supported(void);
void *yue_mbt_tray_new(const char *icon_path, int32_t *ok);
void yue_mbt_tray_set_title(void *tray, const char *title);
void yue_mbt_tray_set_image(void *tray, void *image);
void yue_mbt_tray_remove(void *tray);

/* 方法级审计补齐(2026-09-16) */
void yue_mbt_window_close(void *window);
void yue_mbt_window_minimize(void *window);
void yue_mbt_window_restore(void *window);
int32_t yue_mbt_window_is_minimized(void *window);
void yue_mbt_window_set_content_size_constraints(void *window, double min_w, double min_h, double max_w, double max_h);
void yue_mbt_window_set_movable(void *window, int32_t movable);
void *yue_mbt_window_get_title(void *window);
void yue_mbt_window_set_background_color(void *window, const char *hex);
double yue_mbt_window_get_scale_factor(void *window);
void yue_mbt_window_set_skip_taskbar(void *window, int32_t skip);
void yue_mbt_window_set_icon(void *window, void *image);
void yue_mbt_window_on_focus_in(void *window, int32_t (*invoke)(void *), void *closure);
void yue_mbt_window_on_blur(void *window, int32_t (*invoke)(void *), void *closure);
void yue_mbt_view_set_tooltip(void *view, const char *text);
int32_t yue_mbt_view_add_tooltip_for_rect(void *view, const char *text, double x, double y, double w, double h);
void yue_mbt_view_remove_tooltip(void *view, int32_t id);
bool yue_mbt_system_prefers_dark(void);
/* 系统主色调(强调色)→ ARGB uint32;无主色概念/取不到返回 0 */
uint32_t yue_mbt_system_accent(void);
#if defined(__APPLE__)
/* macOS 实现(ObjC++ 翻译单元 yue_accent_mac.mm),由 system_accent 转调 */
uint32_t yue_mbt_system_accent_mac(void);
#endif
void yue_mbt_on_system_theme_change(void (*invoke)(void *), void *closure);
void yue_mbt_repaint_all(void);
void yue_mbt_view_set_focusable(void *view, int32_t focusable);
int32_t yue_mbt_view_has_focus(void *view);
void yue_mbt_view_schedule_paint_rect(void *view, double x, double y, double w, double h);
void yue_mbt_view_on_focus_in(void *view, int32_t (*invoke)(void *), void *closure);
void yue_mbt_view_on_focus_out(void *view, int32_t (*invoke)(void *), void *closure);
void yue_mbt_container_add_child_view_at(void *container, void *view, int32_t index);
int32_t yue_mbt_container_remove_child_view(void *container, void *view);
int32_t yue_mbt_container_child_count(void *container);
double yue_mbt_scroll_get_position_x(void *scroll);
double yue_mbt_scroll_get_position_y(void *scroll);
double yue_mbt_scroll_get_max_position_x(void *scroll);
double yue_mbt_scroll_get_max_position_y(void *scroll);
void yue_mbt_scroll_on_scroll(void *scroll, int32_t (*invoke)(void *), void *closure);
void yue_mbt_label_set_valign(void *label, int32_t align);
void yue_mbt_label_set_attributed_text(void *label, void *at);
void yue_mbt_message_box_set_default_response(void *box, int32_t response);
void yue_mbt_message_box_set_cancel_response(void *box, int32_t response);
void yue_mbt_message_box_set_informative_text(void *box, const char *text);
int32_t yue_mbt_message_box_run(void *box);
int32_t yue_mbt_message_box_run_for_window(void *box, void *window);
int32_t yue_mbt_clipboard_is_data_available(void *clipboard, int32_t kind);
void yue_mbt_clipboard_start_watching(void *clipboard);
void yue_mbt_clipboard_stop_watching(void *clipboard);
void yue_mbt_clipboard_on_change(void *clipboard, void (*invoke)(void *), void *closure);
void yue_mbt_table_enable_multiple_selection(void *table, int32_t enable);
void yue_mbt_table_select_row(void *table, int32_t row);
int32_t yue_mbt_table_get_selected_row(void *table);
int32_t yue_mbt_table_notify_row_insertion(void *table, int32_t row);
int32_t yue_mbt_table_notify_row_deletion(void *table, int32_t row);
int32_t yue_mbt_table_notify_value_change(void *table, int32_t column, int32_t row);
void *yue_mbt_browser_get_title(void *browser);
void yue_mbt_browser_stop(void *browser);
double yue_mbt_screen_primary_scale_factor();
double yue_mbt_screen_primary_work_area_x();
double yue_mbt_screen_primary_work_area_y();
double yue_mbt_screen_primary_work_area_width();
double yue_mbt_screen_primary_work_area_height();
double yue_mbt_screen_cursor_x();
double yue_mbt_screen_cursor_y();
void yue_mbt_appearance_set_dark_mode_enabled(int32_t enable);
void yue_mbt_appearance_on_color_scheme_change(void (*invoke)(void *), void *closure);
double yue_mbt_attributed_text_get_one_line_width(void *at);
double yue_mbt_attributed_text_get_one_line_height(void *at);
void *yue_mbt_font_default();
void *yue_mbt_font_get_name(void *font);
double yue_mbt_font_get_size(void *font);
void yue_mbt_global_shortcut_unregister_all();
void yue_mbt_menu_item_set_enabled(void *item, int32_t enabled);
void yue_mbt_menu_item_set_visible(void *item, int32_t visible);
int32_t yue_mbt_menu_item_is_visible(void *item);
void yue_mbt_file_dialog_set_title(void *dialog, const char *title);
void yue_mbt_file_dialog_set_button_label(void *dialog, const char *label);
void yue_mbt_app_set_id(const char *id);
void *yue_mbt_app_get_id();
void yue_mbt_gif_player_set_animating(void *gif, int32_t animating);
int32_t yue_mbt_gif_player_is_animating(void *gif);
int32_t yue_mbt_gif_player_is_playing(void *gif);
void yue_mbt_gif_player_stop_animation_timer(void *gif);
double yue_mbt_canvas_get_scale_factor(void *canvas);
double yue_mbt_canvas_get_width(void *canvas);
double yue_mbt_canvas_get_height(void *canvas);
void yue_mbt_notification_center_clear();
void yue_mbt_notification_center_on_notification_show(void (*invoke)(void *, void *), void *closure);
void yue_mbt_notification_center_on_notification_close(void (*invoke)(void *, void *), void *closure);
void yue_mbt_notification_center_on_notification_click(void (*invoke)(void *, void *), void *closure);
void yue_mbt_notification_center_on_notification_action(void (*invoke)(void *, void *), void *closure);


void yue_mbt_browser_execute_javascript_callback(void *browser, const char *code, void (*invoke)(void *, int32_t, void *), void *closure);
void yue_mbt_browser_add_raw_binding(void *browser, const char *name, void (*invoke)(void *, void *), void *closure);
void yue_mbt_browser_remove_binding(void *browser, const char *name);
int32_t yue_mbt_browser_has_bindings(void *browser);
int32_t yue_mbt_view_do_drag_data(void *view, const char *text, const char *file_paths, int32_t operations, int64_t drag_image);
int32_t yue_mbt_view_cancel_drag(void *view);
int32_t yue_mbt_view_is_dragging(void *view);

void *yue_mbt_null_image();

/* ---------- 单实例（Windows:命名互斥体 + message-only 窗口；非 Windows 为桩） ---------- */

/* 命名互斥体探测/创建：ok=1 取得（首实例），ok=0 已存在（第二实例） */
int32_t yue_mbt_win_named_mutex_create(const char *name, int32_t *ok);
/* 向首实例 message-only 窗口发 Wake（WM_COPYDATA，'\n' 分隔命令行）；ok=1 已送达 */
int32_t yue_mbt_win_instance_window_send(const char *class_name, const char *args, int32_t *ok);
/* 首实例建 message-only 窗口：WM_COPYDATA 经 PostTask 抛回主循环再调 invoke(closure, bytes) */
int32_t yue_mbt_win_instance_window_create(const char *class_name, void (*invoke)(void *, void *), void *closure);
/* 兜底：按标题查找顶层窗口并置前（最小化先恢复）；ok=1 找到 */
int32_t yue_mbt_win_find_and_activate(const char *title, int32_t *ok);

/* ---------- 开机自启动（.desktop 走 MoonBit 文件 API;注册表三件套非 Windows 为桩） ---------- */

/* 本进程可执行文件绝对路径（Linux readlink /proc/self/exe;Windows GetModuleFileNameW） */
void *yue_mbt_exe_path(int32_t *ok);
/* 删除文件：目标本就不存在也记 ok=1（disable 幂等） */
int32_t yue_mbt_remove_file(const char *path, int32_t *ok);
/* 读环境变量：未设置 ok=0 */
void *yue_mbt_getenv_bytes(const char *name, int32_t *ok);
/* Windows:HKCU Run 键写值（exe 引号包裹）;非 Windows 返回 -1000 哨兵 */
int32_t yue_mbt_autostart_set(const char *app_id, const char *exe, int32_t *ok);
/* Windows:读 Run 键值（未设置 ok=0）;非 Windows ok=-1000 */
void *yue_mbt_autostart_get(const char *app_id, int32_t *ok);
/* Windows:删 Run 键值（值本就不在也记 ok=1）;非 Windows 返回 -1000 */
int32_t yue_mbt_autostart_remove(const char *app_id, int32_t *ok);

/* ---------- 打开外部（URL / 文件管理器选中;Linux URL 走 traybus spawn） ---------- */

/* spawn 脱离子进程（PATH 搜索,glib 自动回收）;0 成功 -1 失败 */
int32_t yue_mbt_sys_spawn_detached(const char *file, const char *arg);
/* 当前工作目录写入 buf;0 成功 -1 失败 */
int32_t yue_mbt_sys_getcwd(char *buf, int32_t len);
/* Windows:ShellExecuteW open 交给默认处理程序;非 Windows 哨兵 -1000 */
int32_t yue_mbt_open_url(const char *url, int32_t *ok);
/* Windows:explorer /select 选中文件;非 Windows 哨兵 -1000 */
int32_t yue_mbt_win_reveal_file(const char *path, int32_t *ok);

/* ---------- 屏幕常亮与用户空闲 ---------- */

/* 用户空闲毫秒数（无 X 会话/Wayland/加载失败 ok=0） */
int32_t yue_mbt_idle_seconds_ms(int32_t *ok);
/* Windows:SetThreadExecutionState(ES_CONTINUOUS|ES_DISPLAY_REQUIRED);非 Windows 哨兵 -1000 */
int32_t yue_mbt_win_keep_awake_enable(int32_t *ok);
/* Windows:还原线程执行状态;非 Windows 哨兵 -1000 */
int32_t yue_mbt_win_keep_awake_restore(int32_t *ok);

/* ---------- 系统总线基建与电源 ---------- */

/* 撤销 fd 监视（与 yue_mbt_sys_watch_fd 配对） */
void yue_mbt_sys_unwatch_fd(int32_t fd);
/* Double ↔ IEEE 754 位模式（DBus 'd' 编解码,纯位重解释） */
int64_t yue_mbt_sys_f64_to_bits(double v);
double yue_mbt_sys_f64_from_bits(int64_t bits);
/* Windows:GetSystemPowerStatus（出参 ac_online/percent/charging/has_battery,
   percent 未知 -1）;失败 -1,非 Windows 哨兵 -1000 */
int32_t yue_mbt_win_power_status(int32_t *ac_online, int32_t *percent,
                                 int32_t *charging, int32_t *has_battery);
/* Windows:电源/会话事件窗口（event 码 0=将睡 1=已醒 2=锁屏 3=解锁,
   经 PostTask 抛回主循环）;失败 -1,非 Windows 哨兵 -1000 */
int32_t yue_mbt_win_session_power_watch(void (*invoke)(void *, int32_t),
                                        void *closure);
/* Windows:NLM GetConnectivity 位掩码;失败 -1,非 Windows 哨兵 -1000 */
int32_t yue_mbt_win_connectivity(int32_t *ok);
/* Windows:启动后台轮询线程(interval_ms),GetConnectivity 只在该线程
   发生,结果写进程级缓存;重复调用幂等;失败 0,非 Windows 哨兵 0 */
int32_t yue_mbt_netwin_start(int32_t interval_ms);
/* Windows:读最近一次轮询缓存(位掩码);尚未轮询到 -1,非 Windows 哨兵 -1 */
int32_t yue_mbt_netwin_cached(void);

/* ---------- 探测示例(examples/probe) ---------- */

void yue_mbt_probe_env(void *window);
void yue_mbt_probe_view(void *view, const char *label);
void yue_mbt_probe_dark(void *view);
void yue_mbt_view_refresh(void *view);

#ifdef __cplusplus
}
#endif

#endif /* YUE_MBT_H */
