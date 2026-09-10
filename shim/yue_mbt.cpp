// 平台封装层：libyue C++ API → C ABI 的机械转换。
// 原则：本文件只做 ABI 翻译，不写业务逻辑；平台差异优先交给 libyue，
// 只有 libyue 没暴露的（如托盘后端探测）才在这里补。
//
// 句柄方案：所有控件/对象句柄是 shim 注册表的 id（int64 经 void* 传递）。
// 不用 MoonBit external object：MoonBit native 的 GC 堆段与 C++ new 混用
// 时对象内存会被破坏（Table 上必现 vtable 损坏）。注册表句柄进程级存活，
// 不自动回收（GUI 对象生命周期≈进程，见 README 已知边界）。
//
// 类型安全：View 系句柄经 GetClassName() 运行时校验（CastTo），错型调用
// 被拒绝并记日志而非踩空指针。
#include "yue_mbt.h"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <fstream>
#include <new>
#include <unordered_map>

#include "base/command_line.h"
#include "nativeui/nativeui.h"
#include "nativeui/popover.h"
#include "nativeui/date_picker.h"
#include "nativeui/gif_player.h"
#include "nativeui/global_shortcut.h"
#include "nativeui/notification.h"
#include "nativeui/notification_center.h"
#include "nativeui/cursor.h"
#include "nativeui/app.h"
#include "nativeui/appearance.h"
#include "nativeui/locale.h"
#include "nativeui/screen.h"

// 不包含 <moonbit.h>：它在 extern "C" 里声明的 memcpy 与 glibc 的
// C++ noexcept 声明冲突。只声明用到的运行时入口，签名照抄
// ~/.moon/include/moonbit.h。
extern "C" void *moonbit_make_bytes(int32_t size, int value);

// C++ 对象一律走 glibc 堆：MoonBit 运行时初始化后接管进程的 mimalloc 段
// 作为 GC 堆，普通 new 分配的对象会被 GC 扫描/移动破坏（Table 实测必崩）。
// glibc 导出 __libc_malloc/__libc_free 绕开一切接管。
extern "C" void *__libc_malloc(size_t size);
extern "C" void __libc_free(void *ptr);

void *operator new(std::size_t size) {
  void *p = __libc_malloc(size);
  if (p == nullptr) {
    throw std::bad_alloc();
  }
  return p;
}

void *operator new[](std::size_t size) {
  void *p = __libc_malloc(size);
  if (p == nullptr) {
    throw std::bad_alloc();
  }
  return p;
}

void operator delete(void *p) noexcept {
  __libc_free(p);
}

void operator delete[](void *p) noexcept {
  __libc_free(p);
}

void operator delete(void *p, std::size_t) noexcept {
  __libc_free(p);
}

void operator delete[](void *p, std::size_t) noexcept {
  __libc_free(p);
}

namespace {

nu::Lifetime *g_lifetime = nullptr;
nu::State *g_state = nullptr;

int64_t g_next_handle = 1;

// 句柄注册表：id → scoped_refptr。
template <typename T>
struct Store {
  static std::unordered_map<int64_t, scoped_refptr<T>> &map() {
    static std::unordered_map<int64_t, scoped_refptr<T>> m;
    return m;
  }
  static int64_t put(T *obj) {
    int64_t id = g_next_handle++;
    map()[id] = scoped_refptr<T>(obj);
    return id;
  }
  static int64_t put(const scoped_refptr<T> &obj) {
    int64_t id = g_next_handle++;
    map()[id] = obj;
    return id;
  }
  static T *get(void *handle) {
    auto it = map().find(reinterpret_cast<int64_t>(handle));
    return it == map().end() ? nullptr : it->second.get();
  }
};

using ViewStore = Store<nu::Responder>;
using MenuStore = Store<nu::Menu>;
using ModelStore = Store<nu::TableModel>;
using MenuBarStore = Store<nu::MenuBar>;
using MenuItemStore = Store<nu::MenuItem>;
using FileDialogStore = Store<nu::FileDialog>;
using TrayStore = Store<nu::Tray>;
using ImageStore = Store<nu::Image>;
using CanvasStore = Store<nu::Canvas>;
using AttributedTextStore = Store<nu::AttributedText>;
using FontStore = Store<nu::Font>;
using PopoverStore = Store<nu::Popover>;
using MessageBoxStore = Store<nu::MessageBox>;

// CastTo：从注册表取对象，并用 GetClassName 校验运行时类型。
// （View 自身无 kClassName，故模板仅用于具体控件类型。）
template <typename T>
T *CastTo(void *handle) {
  auto *r = ViewStore::get(handle);
  if (r == nullptr) {
    std::fprintf(stderr, "yue_mbt: 句柄无效\n");
    return nullptr;
  }
  if (std::strcmp(r->GetClassName(), T::kClassName) == 0) {
    return static_cast<T *>(r);
  }
  std::fprintf(stderr, "yue_mbt: 类型不匹配，期望 %s，实际 %s\n", T::kClassName,
               r->GetClassName());
  return nullptr;
}

// 通用 View 检查：View 无 kClassName，类型正确性由 MoonBit 侧
// ViewLike 约束保证。
nu::View *CastToView(void *handle) {
  auto *r = ViewStore::get(handle);
  if (r == nullptr) {
    return nullptr;
  }
  return static_cast<nu::View *>(r);
}

// MoonBit Bytes 内容拷贝
void *BytesFromString(const std::string &s) {
  void *bytes = moonbit_make_bytes(static_cast<int32_t>(s.size()), 0);
  if (!s.empty()) {
    std::memcpy(bytes, s.data(), s.size());
  }
  return bytes;
}

}  // namespace

// ---------- 应用生命周期 ----------

int32_t yue_mbt_app_init(void) {
  if (g_state != nullptr) {
    return 1;
  }
  base::CommandLine::Init(0, nullptr);
  g_lifetime = new nu::Lifetime();
  g_state = new nu::State();
  return 1;
}

void yue_mbt_run(void) {
  nu::MessageLoop::Run();
}

void yue_mbt_quit(void) {
  nu::MessageLoop::Quit();
}

int32_t yue_mbt_platform(void) {
#if defined(OS_WIN)
  return 2;
#elif defined(OS_MAC)
  return 1;
#else
  return 0;
#endif
}

// ---------- 窗口 ----------

void *yue_mbt_window_new_ex(int32_t frame, int32_t transparent) {
  nu::Window::Options options;
  options.frame = frame != 0;
  options.transparent = transparent != 0;
  return reinterpret_cast<void *>(ViewStore::put(new nu::Window(options)));
}

void yue_mbt_window_set_title(void *window, const char *title) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetTitle(title);
  }
}

void yue_mbt_window_set_always_on_top(void *window, int32_t top) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetAlwaysOnTop(top != 0);
  }
}

double yue_mbt_window_get_content_size_width(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->GetContentSize().width();
  }
  return 0;
}

double yue_mbt_window_get_content_size_height(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->GetContentSize().height();
  }
  return 0;
}

void yue_mbt_window_set_content(void *window, void *content) {
  auto *w = CastTo<nu::Window>(window);
  auto *c = CastToView(content);
  if (w != nullptr && c != nullptr) {
    w->SetContentView(scoped_refptr<nu::View>(c));
  }
}

void yue_mbt_window_set_content_size(void *window, double width, double height) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetContentSize(
        nu::SizeF(static_cast<float>(width), static_cast<float>(height)));
  }
}

void yue_mbt_window_center(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->Center();
  }
}

void yue_mbt_window_activate(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->Activate();
  }
}

void yue_mbt_window_set_menubar(void *window, void *menubar) {
  auto *w = CastTo<nu::Window>(window);
  if (w == nullptr || menubar == nullptr) {
    return;
  }
  if (auto *bar = MenuBarStore::get(menubar)) {
    w->SetMenuBar(scoped_refptr<nu::MenuBar>(bar));
  }
}

void yue_mbt_window_on_close(void *window, void (*invoke)(void *), void *closure) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->on_close.Connect([invoke, closure](nu::Window *) { invoke(closure); });
  }
}

// ---------- View 通用 ----------

void yue_mbt_view_focus(void *view) {
  if (auto *v = CastToView(view)) {
    v->Focus();
  }
}

void yue_mbt_view_set_enabled(void *view, int32_t enable) {
  if (auto *v = CastToView(view)) {
    v->SetEnabled(enable != 0);
  }
}

void yue_mbt_view_set_mouse_down_can_move_window(void *view, int32_t yes) {
  if (auto *v = CastToView(view)) {
    v->SetMouseDownCanMoveWindow(yes != 0);
  }
}

void yue_mbt_view_set_style_prop_float(void *view, const char *name, double value) {
  if (auto *v = CastToView(view)) {
    v->SetStyleProperty(name, static_cast<float>(value));
  }
}

void yue_mbt_view_set_style_prop_str(void *view, const char *name, const char *value) {
  if (auto *v = CastToView(view)) {
    v->SetStyleProperty(name, std::string(value));
  }
}

void yue_mbt_view_set_background_color(void *view, const char *hex) {
  if (auto *v = CastToView(view)) {
    v->SetBackgroundColor(nu::Color(std::string(hex)));
  }
}

// ---------- Container ----------

void *yue_mbt_container_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Container()));
}

void yue_mbt_container_add_child(void *container, void *child) {
  auto *c = CastTo<nu::Container>(container);
  auto *k = CastToView(child);
  if (c != nullptr && k != nullptr) {
    c->AddChildView(scoped_refptr<nu::View>(k));
  }
}

void yue_mbt_container_on_draw(void *container, void (*invoke)(void *, void *),
                               void *closure) {
  if (auto *c = CastTo<nu::Container>(container)) {
    c->on_draw.Connect(
        [invoke, closure](nu::Container *, nu::Painter *painter, const nu::RectF &) {
          invoke(closure, painter);
        });
  }
}

// ---------- Label ----------

void *yue_mbt_label_new(const char *text) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Label(text)));
}

void yue_mbt_label_set_text(void *label, const char *text) {
  if (auto *l = CastTo<nu::Label>(label)) {
    l->SetText(text);
  }
}

// ---------- TextEdit ----------

void *yue_mbt_text_edit_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::TextEdit()));
}

void yue_mbt_text_edit_set_text(void *edit, const char *text) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->SetText(text);
  }
}

void *yue_mbt_text_edit_get_text(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    return BytesFromString(e->GetText());
  }
  return moonbit_make_bytes(0, 0);
}

double yue_mbt_text_edit_get_text_bounds_height(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    return e->GetTextBounds().height();
  }
  return 0;
}

void yue_mbt_text_edit_on_text_change(void *edit, void (*invoke)(void *),
                                      void *closure) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->on_text_change.Connect([invoke, closure](nu::TextEdit *) { invoke(closure); });
  }
}

int32_t yue_mbt_text_edit_can_undo(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    return e->CanUndo() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_text_edit_undo(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->Undo();
  }
}

int32_t yue_mbt_text_edit_can_redo(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    return e->CanRedo() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_text_edit_redo(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->Redo();
  }
}

void yue_mbt_text_edit_cut(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->Cut();
  }
}

void yue_mbt_text_edit_copy(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->Copy();
  }
}

void yue_mbt_text_edit_paste(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->Paste();
  }
}

void yue_mbt_text_edit_select_all(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->SelectAll();
  }
}

void yue_mbt_text_edit_select_range(void *edit, int32_t start, int32_t end) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->SelectRange(start, end);
  }
}

void *yue_mbt_text_edit_get_text_in_range(void *edit, int32_t start,
                                          int32_t end) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    return BytesFromString(e->GetTextInRange(start, end));
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_text_edit_insert_text(void *edit, const char *text) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->InsertText(text);
  }
}

void yue_mbt_text_edit_insert_text_at(void *edit, const char *text,
                                      int32_t pos) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->InsertTextAt(text, pos);
  }
}

void yue_mbt_text_edit_delete(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->Delete();
  }
}

void yue_mbt_text_edit_delete_range(void *edit, int32_t start, int32_t end) {
  if (auto *e = CastTo<nu::TextEdit>(edit)) {
    e->DeleteRange(start, end);
  }
}

// ---------- Button ----------

void *yue_mbt_button_new(const char *title) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Button(title)));
}

void yue_mbt_button_set_title(void *button, const char *title) {
  if (auto *b = CastTo<nu::Button>(button)) {
    b->SetTitle(title);
  }
}

void yue_mbt_button_on_click(void *button, void (*invoke)(void *), void *closure) {
  if (auto *b = CastTo<nu::Button>(button)) {
    b->on_click.Connect([invoke, closure](nu::Button *) { invoke(closure); });
  }
}

// ---------- Entry ----------

void *yue_mbt_entry_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Entry(nu::Entry::Type::Normal)));
}

void yue_mbt_entry_set_text(void *entry, const char *text) {
  if (auto *e = CastTo<nu::Entry>(entry)) {
    e->SetText(text);
  }
}

void *yue_mbt_entry_get_text(void *entry) {
  if (auto *e = CastTo<nu::Entry>(entry)) {
    return BytesFromString(e->GetText());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_entry_on_text_change(void *entry, void (*invoke)(void *),
                                  void *closure) {
  if (auto *e = CastTo<nu::Entry>(entry)) {
    e->on_text_change.Connect([invoke, closure](nu::Entry *) { invoke(closure); });
  }
}

void yue_mbt_entry_on_activate(void *entry, void (*invoke)(void *),
                               void *closure) {
  if (auto *e = CastTo<nu::Entry>(entry)) {
    e->on_activate.Connect([invoke, closure](nu::Entry *) { invoke(closure); });
  }
}

// ---------- Tab ----------

void *yue_mbt_tab_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Tab()));
}

void yue_mbt_tab_add_page(void *tab, const char *title, void *view) {
  if (auto *t = CastTo<nu::Tab>(tab)) {
    if (auto *v = CastToView(view)) {
      t->AddPage(title, v);
    }
  }
}

void yue_mbt_tab_remove_page(void *tab, void *view) {
  if (auto *t = CastTo<nu::Tab>(tab)) {
    if (auto *v = CastToView(view)) {
      t->RemovePage(v);
    }
  }
}

int32_t yue_mbt_tab_page_count(void *tab) {
  if (auto *t = CastTo<nu::Tab>(tab)) {
    return t->PageCount();
  }
  return 0;
}

void yue_mbt_tab_select_page_at(void *tab, int32_t index) {
  if (auto *t = CastTo<nu::Tab>(tab)) {
    t->SelectPageAt(index);
  }
}

int32_t yue_mbt_tab_selected_page_index(void *tab) {
  if (auto *t = CastTo<nu::Tab>(tab)) {
    return t->GetSelectedPageIndex();
  }
  return -1;
}

void yue_mbt_tab_on_selected_page_change(void *tab, void (*invoke)(void *),
                                         void *closure) {
  if (auto *t = CastTo<nu::Tab>(tab)) {
    t->on_selected_page_change.Connect(
        [invoke, closure](nu::Tab *) { invoke(closure); });
  }
}

// ---------- Browser ----------

void *yue_mbt_browser_new(void) {
  nu::Browser::Options options;
  options.context_menu = true;
  return reinterpret_cast<void *>(ViewStore::put(new nu::Browser(options)));
}

void yue_mbt_browser_load_url(void *browser, const char *url) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->LoadURL(url);
  }
}

void *yue_mbt_browser_get_url(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return BytesFromString(b->GetURL());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_browser_reload(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->Reload();
  }
}

void yue_mbt_browser_go_back(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->GoBack();
  }
}

void yue_mbt_browser_go_forward(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->GoForward();
  }
}

int32_t yue_mbt_browser_can_go_back(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->CanGoBack() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_browser_can_go_forward(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->CanGoForward() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_browser_is_loading(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->IsLoading() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_browser_on_change_loading(void *browser, void (*invoke)(void *),
                                       void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_change_loading.Connect(
        [invoke, closure](nu::Browser *) { invoke(closure); });
  }
}

void yue_mbt_browser_on_update_command(void *browser, void (*invoke)(void *),
                                       void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_update_command.Connect(
        [invoke, closure](nu::Browser *) { invoke(closure); });
  }
}

void yue_mbt_browser_on_update_title(void *browser,
                                     void (*invoke)(void *, void *),
                                     void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_update_title.Connect([invoke, closure](nu::Browser *,
                                                 const std::string &title) {
      invoke(closure, BytesFromString(title));
    });
  }
}

void yue_mbt_browser_on_commit_navigation(void *browser,
                                          void (*invoke)(void *, void *),
                                          void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_commit_navigation.Connect([invoke, closure](nu::Browser *,
                                                      const std::string &url) {
      invoke(closure, BytesFromString(url));
    });
  }
}

void yue_mbt_browser_on_finish_navigation(void *browser,
                                          void (*invoke)(void *, void *),
                                          void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_finish_navigation.Connect([invoke, closure](nu::Browser *,
                                                      const std::string &url) {
      invoke(closure, BytesFromString(url));
    });
  }
}

// ---------- 菜单 ----------

void *yue_mbt_menu_bar_new(void) {
  return reinterpret_cast<void *>(MenuBarStore::put(new nu::MenuBar()));
}

// 在顶栏挂标题项并返回其子菜单；item 由 menu 的 items 持有引用
void *yue_mbt_menu_bar_add_menu(void *menubar, const char *title) {
  auto *bar = MenuBarStore::get(menubar);
  if (bar == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(
      new nu::MenuItem(nu::MenuItem::Type::Submenu));
  item->SetLabel(title);
  auto menu = scoped_refptr<nu::Menu>(new nu::Menu());
  item->SetSubmenu(menu);
  bar->Append(item);
  return reinterpret_cast<void *>(MenuStore::put(menu));
}

void *yue_mbt_menu_add_submenu(void *menu, const char *title) {
  auto *parent = MenuStore::get(menu);
  if (parent == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(
      new nu::MenuItem(nu::MenuItem::Type::Submenu));
  item->SetLabel(title);
  auto sub = scoped_refptr<nu::Menu>(new nu::Menu());
  item->SetSubmenu(sub);
  parent->Append(item);
  return reinterpret_cast<void *>(MenuStore::put(sub));
}

void *yue_mbt_menu_add_label_item(void *menu, const char *label) {
  auto *m = MenuStore::get(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(new nu::MenuItem(nu::MenuItem::Type::Label));
  item->SetLabel(label);
  m->Append(item);
  return reinterpret_cast<void *>(MenuItemStore::put(item));
}

void *yue_mbt_menu_add_role_item(void *menu, int32_t role) {
  auto *m = MenuStore::get(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(
      new nu::MenuItem(static_cast<nu::MenuItem::Role>(role)));
  m->Append(item);
  return reinterpret_cast<void *>(MenuItemStore::put(item));
}

void *yue_mbt_menu_add_separator(void *menu) {
  auto *m = MenuStore::get(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item =
      scoped_refptr<nu::MenuItem>(new nu::MenuItem(nu::MenuItem::Type::Separator));
  m->Append(item);
  return reinterpret_cast<void *>(MenuItemStore::put(item));
}

void yue_mbt_menu_item_set_label(void *item, const char *label) {
  if (auto *i = MenuItemStore::get(item)) {
    i->SetLabel(label);
  }
}

void yue_mbt_menu_item_set_accelerator(void *item, const char *accelerator) {
  if (auto *i = MenuItemStore::get(item)) {
    i->SetAccelerator(nu::Accelerator(std::string(accelerator)));
  }
}

void yue_mbt_menu_item_on_click(void *item, void (*invoke)(void *), void *closure) {
  if (auto *i = MenuItemStore::get(item)) {
    i->on_click.Connect([invoke, closure](nu::MenuItem *) { invoke(closure); });
  }
}

// ---------- 文件对话框 ----------

void *yue_mbt_file_open_dialog_new(void) {
  return reinterpret_cast<void *>(FileDialogStore::put(new nu::FileOpenDialog()));
}

void *yue_mbt_file_save_dialog_new(void) {
  return reinterpret_cast<void *>(FileDialogStore::put(new nu::FileSaveDialog()));
}

// filters 打包："描述:扩展1,扩展2|描述2:扩展3"
void yue_mbt_file_dialog_set_filters(void *dialog, const char *filters) {
  if (auto *d = FileDialogStore::get(dialog)) {
    std::vector<nu::FileDialog::Filter> parsed;
    std::string input(filters);
    size_t pos = 0;
    while (pos <= input.size()) {
      size_t bar = input.find('|', pos);
      if (bar == std::string::npos) {
        bar = input.size();
      }
      std::string group = input.substr(pos, bar - pos);
      size_t colon = group.find(':');
      if (colon != std::string::npos) {
        nu::FileDialog::Filter filter{group.substr(0, colon), {}};
        std::string exts = group.substr(colon + 1);
        size_t epos = 0;
        while (epos <= exts.size()) {
          size_t comma = exts.find(',', epos);
          if (comma == std::string::npos) {
            comma = exts.size();
          }
          if (comma > epos) {
            std::get<1>(filter).push_back(exts.substr(epos, comma - epos));
          }
          epos = comma + 1;
        }
        parsed.push_back(filter);
      }
      pos = bar + 1;
    }
    d->SetFilters(parsed);
  }
}

void yue_mbt_file_dialog_set_folder(void *dialog, const char *folder) {
  if (auto *d = FileDialogStore::get(dialog)) {
    d->SetFolder(base::FilePath(folder));
  }
}

void yue_mbt_file_dialog_set_filename(void *dialog, const char *filename) {
  if (auto *d = FileDialogStore::get(dialog)) {
    d->SetFilename(filename);
  }
}

int32_t yue_mbt_file_dialog_run_for_window(void *dialog, void *window) {
  auto *d = FileDialogStore::get(dialog);
  auto *w = CastTo<nu::Window>(window);
  if (d == nullptr || w == nullptr) {
    return 0;
  }
  return d->RunForWindow(w) ? 1 : 0;
}

void *yue_mbt_file_dialog_get_result(void *dialog) {
  if (auto *d = FileDialogStore::get(dialog)) {
    return BytesFromString(d->GetResult().value());
  }
  return moonbit_make_bytes(0, 0);
}

// ---------- 文件 IO ----------

void *yue_mbt_read_file(const char *path, int32_t *ok) {
  *ok = 0;
  std::ifstream in(path, std::ios::binary);
  if (!in) {
    return moonbit_make_bytes(0, 0);
  }
  std::string content((std::istreambuf_iterator<char>(in)),
                      std::istreambuf_iterator<char>());
  *ok = 1;
  return BytesFromString(content);
}

void yue_mbt_write_file(const char *path, const void *data, int32_t len,
                        int32_t *ok) {
  *ok = 0;
  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) {
    return;
  }
  out.write(static_cast<const char *>(data), len);
  *ok = out.good() ? 1 : 0;
}

// ---------- Painter ----------

void yue_mbt_painter_save(void *painter) {
  static_cast<nu::Painter *>(painter)->Save();
}

void yue_mbt_painter_restore(void *painter) {
  static_cast<nu::Painter *>(painter)->Restore();
}

void yue_mbt_painter_begin_path(void *painter) {
  static_cast<nu::Painter *>(painter)->BeginPath();
}

void yue_mbt_painter_close_path(void *painter) {
  static_cast<nu::Painter *>(painter)->ClosePath();
}

void yue_mbt_painter_move_to(void *painter, double x, double y) {
  static_cast<nu::Painter *>(painter)->MoveTo(
      nu::PointF(static_cast<float>(x), static_cast<float>(y)));
}

void yue_mbt_painter_line_to(void *painter, double x, double y) {
  static_cast<nu::Painter *>(painter)->LineTo(
      nu::PointF(static_cast<float>(x), static_cast<float>(y)));
}

void yue_mbt_painter_bezier_curve_to(void *painter, double cp1x, double cp1y,
                                     double cp2x, double cp2y, double x,
                                     double y) {
  static_cast<nu::Painter *>(painter)->BezierCurveTo(
      nu::PointF(static_cast<float>(cp1x), static_cast<float>(cp1y)),
      nu::PointF(static_cast<float>(cp2x), static_cast<float>(cp2y)),
      nu::PointF(static_cast<float>(x), static_cast<float>(y)));
}

void yue_mbt_painter_arc(void *painter, double x, double y, double radius,
                         double start_angle, double end_angle, int32_t ccw) {
  auto *p = static_cast<nu::Painter *>(painter);
  float sa = static_cast<float>(start_angle);
  float ea = static_cast<float>(end_angle);
  // libyue 的 Arc 无反向参数：逆时针用负角跨度表达（等价 canvas 语义）
  if (ccw != 0 && ea > sa) {
    ea -= static_cast<float>(2 * M_PI);
  }
  p->Arc(nu::PointF(static_cast<float>(x), static_cast<float>(y)),
         static_cast<float>(radius), sa, ea);
}

void yue_mbt_painter_fill(void *painter) {
  static_cast<nu::Painter *>(painter)->Fill();
}

void yue_mbt_painter_stroke(void *painter) {
  static_cast<nu::Painter *>(painter)->Stroke();
}

void yue_mbt_painter_clip_rect(void *painter, double x, double y, double w, double h) {
  static_cast<nu::Painter *>(painter)->ClipRect(nu::RectF(
      static_cast<float>(x), static_cast<float>(y), static_cast<float>(w),
      static_cast<float>(h)));
}

void yue_mbt_painter_fill_rect(void *painter, double x, double y, double w, double h) {
  static_cast<nu::Painter *>(painter)->FillRect(nu::RectF(
      static_cast<float>(x), static_cast<float>(y), static_cast<float>(w),
      static_cast<float>(h)));
}

void yue_mbt_painter_stroke_rect(void *painter, double x, double y, double w,
                                 double h) {
  static_cast<nu::Painter *>(painter)->StrokeRect(nu::RectF(
      static_cast<float>(x), static_cast<float>(y), static_cast<float>(w),
      static_cast<float>(h)));
}

void yue_mbt_painter_set_fill_color(void *painter, const char *hex) {
  static_cast<nu::Painter *>(painter)->SetFillColor(nu::Color(std::string(hex)));
}

void yue_mbt_painter_set_stroke_color(void *painter, const char *hex) {
  static_cast<nu::Painter *>(painter)->SetStrokeColor(nu::Color(std::string(hex)));
}

void yue_mbt_painter_translate(void *painter, double dx, double dy) {
  static_cast<nu::Painter *>(painter)->Translate(
      nu::Vector2dF(static_cast<float>(dx), static_cast<float>(dy)));
}

void yue_mbt_painter_scale(void *painter, double sx, double sy) {
  static_cast<nu::Painter *>(painter)->Scale(
      nu::Vector2dF(static_cast<float>(sx), static_cast<float>(sy)));
}

void yue_mbt_painter_rotate(void *painter, double angle) {
  static_cast<nu::Painter *>(painter)->Rotate(static_cast<float>(angle));
}

void yue_mbt_painter_draw_text(void *painter, const char *text, double x,
                               double y, double w, double h, int32_t align,
                               int32_t valign, const char *hex_color) {
  nu::Color color((std::string(hex_color)));
  nu::TextAttributes attributes(color);
  attributes.align = static_cast<nu::TextAlign>(align);
  attributes.valign = static_cast<nu::TextAlign>(valign);
  static_cast<nu::Painter *>(painter)->DrawText(
      text,
      nu::RectF(static_cast<float>(x), static_cast<float>(y),
                static_cast<float>(w), static_cast<float>(h)),
      attributes);
}

void yue_mbt_painter_draw_attributed_text(void *painter, void *attributed_text,
                                          double x, double y, double w,
                                          double h) {
  auto *at = AttributedTextStore::get(attributed_text);
  auto *p = static_cast<nu::Painter *>(painter);
  if (at == nullptr || p == nullptr) {
    return;
  }
  p->DrawAttributedText(scoped_refptr<nu::AttributedText>(at),
                        nu::RectF(static_cast<float>(x), static_cast<float>(y),
                                  static_cast<float>(w), static_cast<float>(h)));
}

void yue_mbt_painter_draw_image(void *painter, void *image, double x, double y,
                                double w, double h) {
  auto *img = ImageStore::get(image);
  auto *p = static_cast<nu::Painter *>(painter);
  if (img == nullptr || p == nullptr) {
    return;
  }
  p->DrawImage(img,
               nu::RectF(static_cast<float>(x), static_cast<float>(y),
                         static_cast<float>(w), static_cast<float>(h)));
}

void yue_mbt_painter_draw_image_from_rect(void *painter, void *image, double sx,
                                          double sy, double sw, double sh,
                                          double dx, double dy, double dw,
                                          double dh) {
  auto *img = ImageStore::get(image);
  auto *p = static_cast<nu::Painter *>(painter);
  if (img == nullptr || p == nullptr) {
    return;
  }
  p->DrawImageFromRect(
      img,
      nu::RectF(static_cast<float>(sx), static_cast<float>(sy),
                static_cast<float>(sw), static_cast<float>(sh)),
      nu::RectF(static_cast<float>(dx), static_cast<float>(dy),
                static_cast<float>(dw), static_cast<float>(dh)));
}

void yue_mbt_painter_draw_canvas(void *painter, void *canvas, double x, double y,
                                 double w, double h) {
  auto *c = CanvasStore::get(canvas);
  auto *p = static_cast<nu::Painter *>(painter);
  if (c == nullptr || p == nullptr) {
    return;
  }
  p->DrawCanvas(c,
                nu::RectF(static_cast<float>(x), static_cast<float>(y),
                          static_cast<float>(w), static_cast<float>(h)));
}

void yue_mbt_painter_draw_canvas_from_rect(void *painter, void *canvas,
                                           double sx, double sy, double sw,
                                           double sh, double dx, double dy,
                                           double dw, double dh) {
  auto *c = CanvasStore::get(canvas);
  auto *p = static_cast<nu::Painter *>(painter);
  if (c == nullptr || p == nullptr) {
    return;
  }
  p->DrawCanvasFromRect(
      c,
      nu::RectF(static_cast<float>(sx), static_cast<float>(sy),
                static_cast<float>(sw), static_cast<float>(sh)),
      nu::RectF(static_cast<float>(dx), static_cast<float>(dy),
                static_cast<float>(dw), static_cast<float>(dh)));
}

// ---------- Canvas / AttributedText / Font / Image ----------

void *yue_mbt_canvas_new(double width, double height) {
  return reinterpret_cast<void *>(CanvasStore::put(
      new nu::Canvas(nu::SizeF(static_cast<float>(width),
                               static_cast<float>(height)))));
}

void *yue_mbt_canvas_get_painter(void *canvas) {
  if (auto *c = CanvasStore::get(canvas)) {
    return c->GetPainter();
  }
  return nullptr;
}

void *yue_mbt_attributed_text_new(const char *text, int32_t align, int32_t valign) {
  nu::TextFormat format;
  format.align = static_cast<nu::TextAlign>(align);
  format.valign = static_cast<nu::TextAlign>(valign);
  return reinterpret_cast<void *>(AttributedTextStore::put(
      new nu::AttributedText(text, format)));
}

void yue_mbt_attributed_text_set_font(void *at, void *font) {
  auto *t = AttributedTextStore::get(at);
  auto *f = FontStore::get(font);
  if (t != nullptr && f != nullptr) {
    t->SetFont(scoped_refptr<nu::Font>(f));
  }
}

void yue_mbt_attributed_text_set_color(void *at, const char *hex) {
  if (auto *t = AttributedTextStore::get(at)) {
    t->SetColor(nu::Color(std::string(hex)));
  }
}

void yue_mbt_attributed_text_get_bounds_for(void *at, double w, double h,
                                            double *out_w, double *out_h) {
  if (auto *t = AttributedTextStore::get(at)) {
    nu::RectF bounds =
        t->GetBoundsFor(nu::SizeF(static_cast<float>(w), static_cast<float>(h)));
    *out_w = bounds.width();
    *out_h = bounds.height();
  } else {
    *out_w = 0;
    *out_h = 0;
  }
}

void *yue_mbt_font_new(const char *name, double size, int32_t weight,
                       int32_t style) {
  return reinterpret_cast<void *>(FontStore::put(
      new nu::Font(name, static_cast<float>(size),
                   static_cast<nu::Font::Weight>(weight),
                   static_cast<nu::Font::Style>(style))));
}

void *yue_mbt_image_new_from_file(const char *path) {
  return reinterpret_cast<void *>(
      ImageStore::put(new nu::Image(base::FilePath(path))));
}

double yue_mbt_image_get_width(void *image) {
  if (auto *i = ImageStore::get(image)) {
    return i->GetSize().width();
  }
  return 0;
}

double yue_mbt_image_get_height(void *image) {
  if (auto *i = ImageStore::get(image)) {
    return i->GetSize().height();
  }
  return 0;
}

// ---------- Table ----------

namespace {

// 表格模型桥：把 MoonBit 侧 trait 实现挂到 libyue 的 AbstractTableModel。
// get_value 返回 MoonBit Bytes，编码 [kind:i32le][payload]：
//   kind=0 payload 为 UTF-8 文本（Text/Edit 列）
//   kind=1 payload 单字节 0/1（Checkbox 列）
//   kind=2 payload 为 UTF-8 文本 + \0 + 颜色 hex（Custom 列）
class TableModelBridge : public nu::AbstractTableModel {
 public:
  TableModelBridge(uint32_t column_count, void *closure,
                   uint32_t (*row_count)(void *),
                   void *(*get_value)(void *, uint32_t, uint32_t),
                   void (*set_value)(void *, uint32_t, uint32_t, int32_t, void *,
                                     int32_t))
    : nu::AbstractTableModel(true), closure_(closure),
      row_count_(row_count), get_value_(get_value), set_value_(set_value) {}

  uint32_t GetRowCount() const override {
    return row_count_(closure_);
  }

  base::Value GetValue(uint32_t column, uint32_t row) const override {
    int32_t kind = 0;
    std::string text, extra;
    bool flag = false;
    Decode(get_value_(closure_, column, row), &kind, &text, &extra, &flag);
    switch (kind) {
      case 1:
        return base::Value(flag);
      case 2: {
        base::Value::Dict dict;
        dict.Set("name", text);
        dict.Set("color", extra);
        return base::Value(std::move(dict));
      }
      default:
        return base::Value(text);
    }
  }

  void SetValue(uint32_t column, uint32_t row, base::Value value) override {
    if (value.is_bool()) {
      set_value_(closure_, column, row, 1, nullptr, value.GetBool() ? 1 : 0);
    } else if (value.is_string()) {
      set_value_(closure_, column, row, 0, BytesFromString(value.GetString()), 0);
    }
  }

 private:
  // 解析 MoonBit 编码：[kind:i32le][payload]
  static void Decode(const void *bytes, int32_t *kind, std::string *text,
                     std::string *extra, bool *flag) {
    const uint8_t *b = static_cast<const uint8_t *>(bytes);
    int32_t k = static_cast<int32_t>(b[0]) | (static_cast<int32_t>(b[1]) << 8) |
                (static_cast<int32_t>(b[2]) << 16) |
                (static_cast<int32_t>(b[3]) << 24);
    const uint8_t *rest = b + 4;
    switch (k) {
      case 1:
        *flag = rest[0] != 0;
        break;
      case 2:
        *text = reinterpret_cast<const char *>(rest);
        *extra = reinterpret_cast<const char *>(rest + text->size() + 1);
        break;
      default:
        *text = reinterpret_cast<const char *>(rest);
        break;
    }
    *kind = k;
  }

  void *closure_;
  uint32_t (*row_count_)(void *);
  void *(*get_value_)(void *, uint32_t, uint32_t);
  void (*set_value_)(void *, uint32_t, uint32_t, int32_t, void *, int32_t);
};

}  // namespace

void *yue_mbt_table_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Table()));
}

void yue_mbt_table_add_column_text(void *table, const char *title, int32_t width) {
  if (auto *t = CastTo<nu::Table>(table)) {
    nu::Table::ColumnOptions options;
    options.type = nu::Table::ColumnType::Text;
    options.width = width;
    t->AddColumnWithOptions(title, options);
  }
}

void yue_mbt_table_add_column_edit(void *table, const char *title, int32_t width) {
  if (auto *t = CastTo<nu::Table>(table)) {
    nu::Table::ColumnOptions options;
    options.type = nu::Table::ColumnType::Edit;
    options.width = width;
    t->AddColumnWithOptions(title, options);
  }
}

void yue_mbt_table_add_column_checkbox(void *table, const char *title, int32_t width) {
  if (auto *t = CastTo<nu::Table>(table)) {
    nu::Table::ColumnOptions options;
    options.type = nu::Table::ColumnType::Checkbox;
    options.width = width;
    t->AddColumnWithOptions(title, options);
  }
}

void yue_mbt_table_add_column_custom(void *table, const char *title, int32_t width,
                                     void (*draw)(void *, void *, double, double,
                                                  double, double, void *, void *),
                                     void *closure) {
  if (auto *t = CastTo<nu::Table>(table)) {
    nu::Table::ColumnOptions options;
    options.type = nu::Table::ColumnType::Custom;
    options.width = width;
    options.on_draw = [draw, closure](nu::Painter *painter, const nu::RectF &rect,
                                      const base::Value &value) {
      std::string name, color;
      if (value.is_dict()) {
        const base::Value::Dict &dict = value.GetDict();
        if (const base::Value *n = dict.Find("name")) {
          if (n->is_string()) {
            name = n->GetString();
          }
        }
        if (const base::Value *c = dict.Find("color")) {
          if (c->is_string()) {
            color = c->GetString();
          }
        }
      }
      draw(closure, painter, rect.x(), rect.y(), rect.width(), rect.height(),
           BytesFromString(name), BytesFromString(color));
    };
    t->AddColumnWithOptions(title, options);
  }
}

void yue_mbt_table_set_has_border(void *table, int32_t yes) {
  if (auto *t = CastTo<nu::Table>(table)) {
    t->SetHasBorder(yes != 0);
  }
}

void yue_mbt_table_bind_model(void *table, int32_t column_count, void *closure,
                              uint32_t (*row_count)(void *),
                              void *(*get_value)(void *, uint32_t, uint32_t),
                              void (*set_value)(void *, uint32_t, uint32_t,
                                                int32_t, void *, int32_t)) {
  auto *t = CastTo<nu::Table>(table);
  if (t == nullptr) {
    return;
  }
  t->SetModel(scoped_refptr<nu::TableModel>(
      new TableModelBridge(static_cast<uint32_t>(column_count), closure,
                           row_count, get_value, set_value)));
}


// ---------- 拖放 ----------

namespace {

// Clipboard::Data::Type: None=0 Text=1 HTML=2 Image=3 FilePaths=4
nu::Clipboard::Data::Type ToDataType(int32_t kind) {
  return static_cast<nu::Clipboard::Data::Type>(kind);
}

}  // namespace

int32_t yue_mbt_dragging_is_available(void *info, int32_t kind) {
  auto *i = static_cast<nu::DraggingInfo *>(info);
  return i != nullptr && i->IsDataAvailable(ToDataType(kind)) ? 1 : 0;
}

void *yue_mbt_dragging_get_data(void *info, int32_t kind) {
  auto *i = static_cast<nu::DraggingInfo *>(info);
  if (i == nullptr || !i->IsDataAvailable(ToDataType(kind))) {
    return moonbit_make_bytes(0, 0);
  }
  nu::Clipboard::Data data = i->GetData(ToDataType(kind));
  if (kind == 3) {
    // Image：句柄 i64 编码进 Bytes
    nu::Image *img = data.image();
    int64_t handle = img != nullptr ? ImageStore::put(img) : 0;
    void *bytes = moonbit_make_bytes(12, 0);
    int32_t k = 3;
    std::memcpy(bytes, &k, 4);
    std::memcpy(static_cast<char *>(bytes) + 4, &handle, 8);
    return bytes;
  }
  std::string text;
  if (kind == 4) {
    for (const base::FilePath &path : data.file_paths()) {
      if (!text.empty()) {
        text += '\n';
      }
      text += path.value();
    }
  } else {
    text = data.str();
  }
  void *bytes = moonbit_make_bytes(static_cast<int32_t>(4 + text.size()), 0);
  int32_t k = kind;
  std::memcpy(bytes, &k, 4);
  if (!text.empty()) {
    std::memcpy(static_cast<char *>(bytes) + 4, text.data(), text.size());
  }
  return bytes;
}

int32_t yue_mbt_dragging_get_operations(void *info) {
  auto *i = static_cast<nu::DraggingInfo *>(info);
  return i != nullptr ? i->GetDragOperations() : 0;
}

// ---------- View 拖放 ----------

void yue_mbt_view_register_dragged_types(void *view, const int32_t *kinds, int32_t len) {
  if (auto *v = CastToView(view)) {
    std::set<nu::Clipboard::Data::Type> types;
    for (int32_t i = 0; i < len; i++) {
      types.insert(ToDataType(kinds[i]));
    }
    v->RegisterDraggedTypes(types);
  }
}

int32_t yue_mbt_view_do_drag_file_paths(void *view, const char *paths,
                                        int32_t operations, int64_t drag_image) {
  auto *v = CastToView(view);
  if (v == nullptr) {
    return 0;
  }
  std::vector<nu::Clipboard::Data> data;
  nu::Clipboard::Data paths_data(nu::Clipboard::Data::Type::FilePaths,
                                 std::string(paths));
  data.push_back(std::move(paths_data));
  nu::DragOptions options;
  if (drag_image != 0) {
    if (auto *img = ImageStore::get(reinterpret_cast<void *>(drag_image))) {
      options.image = scoped_refptr<nu::Image>(img);
    }
  }
  return v->DoDragWithOptions(std::move(data), operations, options);
}

void yue_mbt_view_handle_drag_enter(void *view,
                                    int32_t (*invoke)(void *, void *, double, double),
                                    void *closure) {
  if (auto *v = CastToView(view)) {
    v->handle_drag_enter = [invoke, closure](nu::View *, nu::DraggingInfo *info,
                                             const nu::PointF &point) {
      return invoke(closure, info, point.x(), point.y());
    };
  }
}

void yue_mbt_view_handle_drag_update(void *view,
                                     int32_t (*invoke)(void *, void *, double, double),
                                     void *closure) {
  if (auto *v = CastToView(view)) {
    v->handle_drag_update = [invoke, closure](nu::View *, nu::DraggingInfo *info,
                                              const nu::PointF &point) {
      return invoke(closure, info, point.x(), point.y());
    };
  }
}

void yue_mbt_view_handle_drop(void *view,
                              int32_t (*invoke)(void *, void *, double, double),
                              void *closure) {
  if (auto *v = CastToView(view)) {
    v->handle_drop = [invoke, closure](nu::View *, nu::DraggingInfo *info,
                                       const nu::PointF &point) {
      return invoke(closure, info, point.x(), point.y()) != 0;
    };
  }
}

void yue_mbt_view_on_drag_leave(void *view, void (*invoke)(void *), void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_drag_leave.Connect([invoke, closure](nu::View *, nu::DraggingInfo *) {
      invoke(closure);
    });
  }
}

void yue_mbt_view_schedule_paint(void *view) {
  if (auto *v = CastToView(view)) {
    v->SchedulePaint();
  }
}

double yue_mbt_view_get_bounds_x(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBounds().x();
  }
  return 0;
}

double yue_mbt_view_get_bounds_y(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBounds().y();
  }
  return 0;
}

double yue_mbt_view_get_bounds_width(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBounds().width();
  }
  return 0;
}

double yue_mbt_view_get_bounds_height(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBounds().height();
  }
  return 0;
}

void *yue_mbt_image_from_handle(int64_t h) {
  return reinterpret_cast<void *>(h);
}

int64_t yue_mbt_image_to_handle(void *image) {
  return reinterpret_cast<int64_t>(image);
}

void yue_mbt_view_on_mouse_down(void *view, int32_t (*invoke)(void *), void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_mouse_down.Connect([invoke, closure](nu::Responder *,
                                               const nu::MouseEvent &) {
      return invoke(closure) != 0;
    });
  }
}

void yue_mbt_painter_set_color(void *painter, const char *hex) {
  static_cast<nu::Painter *>(painter)->SetColor(nu::Color(std::string(hex)));
}


// ---------- 组合控件（Slider/Picker/ComboBox/ProgressBar/Popover） ----------

namespace {

// ComboBox 继承 Picker 但 GetClassName 不同，名字双匹配
nu::Picker *CastToPickerLike(void *handle) {
  auto *r = ViewStore::get(handle);
  if (r == nullptr) {
    return nullptr;
  }
  const char *name = r->GetClassName();
  if (std::strcmp(name, nu::Picker::kClassName) == 0 ||
      std::strcmp(name, nu::ComboBox::kClassName) == 0) {
    return static_cast<nu::Picker *>(r);
  }
  std::fprintf(stderr, "yue_mbt: 类型不匹配，期望 Picker/ComboBox，实际 %s\\n", name);
  return nullptr;
}

}  // namespace

void *yue_mbt_slider_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Slider()));
}

void yue_mbt_slider_set_value(void *slider, double value) {
  if (auto *s = CastTo<nu::Slider>(slider)) {
    s->SetValue(static_cast<float>(value));
  }
}

double yue_mbt_slider_get_value(void *slider) {
  if (auto *s = CastTo<nu::Slider>(slider)) {
    return s->GetValue();
  }
  return 0;
}

void yue_mbt_slider_set_step(void *slider, double step) {
  if (auto *s = CastTo<nu::Slider>(slider)) {
    s->SetStep(static_cast<float>(step));
  }
}

void yue_mbt_slider_set_range(void *slider, double min, double max) {
  if (auto *s = CastTo<nu::Slider>(slider)) {
    s->SetRange(static_cast<float>(min), static_cast<float>(max));
  }
}

void yue_mbt_slider_on_value_change(void *slider, void (*invoke)(void *), void *closure) {
  if (auto *s = CastTo<nu::Slider>(slider)) {
    s->on_value_change.Connect([invoke, closure](nu::Slider *) { invoke(closure); });
  }
}

void yue_mbt_slider_on_sliding_complete(void *slider, void (*invoke)(void *), void *closure) {
  if (auto *s = CastTo<nu::Slider>(slider)) {
    s->on_sliding_complete.Connect([invoke, closure](nu::Slider *) { invoke(closure); });
  }
}

void *yue_mbt_picker_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Picker()));
}

void yue_mbt_picker_add_item(void *picker, const char *text) {
  if (auto *p = CastToPickerLike(picker)) {
    p->AddItem(text);
  }
}

void yue_mbt_picker_remove_item_at(void *picker, int32_t index) {
  if (auto *p = CastToPickerLike(picker)) {
    p->RemoveItemAt(index);
  }
}

void yue_mbt_picker_clear(void *picker) {
  if (auto *p = CastToPickerLike(picker)) {
    p->Clear();
  }
}

void yue_mbt_picker_select_item_at(void *picker, int32_t index) {
  if (auto *p = CastToPickerLike(picker)) {
    p->SelectItemAt(index);
  }
}

void *yue_mbt_picker_get_selected_item(void *picker) {
  if (auto *p = CastToPickerLike(picker)) {
    return BytesFromString(p->GetSelectedItem());
  }
  return moonbit_make_bytes(0, 0);
}

int32_t yue_mbt_picker_get_selected_item_index(void *picker) {
  if (auto *p = CastToPickerLike(picker)) {
    return p->GetSelectedItemIndex();
  }
  return -1;
}

void yue_mbt_picker_on_selection_change(void *picker, void (*invoke)(void *), void *closure) {
  if (auto *p = CastToPickerLike(picker)) {
    p->on_selection_change.Connect([invoke, closure](nu::Picker *) { invoke(closure); });
  }
}

void *yue_mbt_combo_box_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::ComboBox()));
}

void yue_mbt_combo_box_set_text(void *combobox, const char *text) {
  if (auto *c = CastTo<nu::ComboBox>(combobox)) {
    c->SetText(text);
  }
}

void *yue_mbt_combo_box_get_text(void *combobox) {
  if (auto *c = CastTo<nu::ComboBox>(combobox)) {
    return BytesFromString(c->GetText());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_combo_box_on_text_change(void *combobox, void (*invoke)(void *), void *closure) {
  if (auto *c = CastTo<nu::ComboBox>(combobox)) {
    c->on_text_change.Connect([invoke, closure](nu::ComboBox *) { invoke(closure); });
  }
}

void *yue_mbt_progress_bar_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::ProgressBar()));
}

void yue_mbt_progress_bar_set_value(void *bar, double value) {
  if (auto *b = CastTo<nu::ProgressBar>(bar)) {
    b->SetValue(static_cast<float>(value));
  }
}

void yue_mbt_progress_bar_set_indeterminate(void *bar, int32_t yes) {
  if (auto *b = CastTo<nu::ProgressBar>(bar)) {
    b->SetIndeterminate(yes != 0);
  }
}

void *yue_mbt_popover_new(void) {
  return reinterpret_cast<void *>(PopoverStore::put(new nu::Popover()));
}

void yue_mbt_popover_set_content(void *popover, void *content) {
  auto *p = PopoverStore::get(popover);
  auto *c = CastToView(content);
  if (p != nullptr && c != nullptr) {
    p->SetContentView(scoped_refptr<nu::View>(c));
  }
}

void yue_mbt_popover_set_content_size(void *popover, double w, double h) {
  if (auto *p = PopoverStore::get(popover)) {
    p->SetContentSize(
        nu::SizeF(static_cast<float>(w), static_cast<float>(h)));
  }
}

void yue_mbt_popover_show_relative_to(void *popover, void *view) {
  auto *p = PopoverStore::get(popover);
  auto *v = CastToView(view);
  if (p != nullptr && v != nullptr) {
    p->ShowRelativeTo(v);
  }
}

void yue_mbt_popover_close(void *popover) {
  if (auto *p = PopoverStore::get(popover)) {
    p->Close();
  }
}

void yue_mbt_popover_on_close(void *popover, void (*invoke)(void *), void *closure) {
  if (auto *p = PopoverStore::get(popover)) {
    p->on_close.Connect([invoke, closure](nu::Popover *) { invoke(closure); });
  }
}


// ---------- Group / Scroll / Separator / 剪贴板 / 消息框 ----------

void *yue_mbt_group_new(const char *title) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Group(title)));
}

void yue_mbt_group_set_content(void *group, void *view) {
  auto *g = CastTo<nu::Group>(group);
  auto *c = CastToView(view);
  if (g != nullptr && c != nullptr) {
    g->SetContentView(scoped_refptr<nu::View>(c));
  }
}

void yue_mbt_group_set_title(void *group, const char *title) {
  if (auto *g = CastTo<nu::Group>(group)) {
    g->SetTitle(title);
  }
}

void *yue_mbt_scroll_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::Scroll()));
}

void yue_mbt_scroll_set_content(void *scroll, void *view) {
  auto *s = CastTo<nu::Scroll>(scroll);
  auto *c = CastToView(view);
  if (s != nullptr && c != nullptr) {
    s->SetContentView(scoped_refptr<nu::View>(c));
  }
}

void yue_mbt_scroll_set_content_size(void *scroll, double w, double h) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    s->SetContentSize(
        nu::SizeF(static_cast<float>(w), static_cast<float>(h)));
  }
}

void yue_mbt_scroll_set_scroll_position(void *scroll, double horizon, double vertical) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    s->SetScrollPosition(static_cast<float>(horizon), static_cast<float>(vertical));
  }
}

void yue_mbt_scroll_set_overlay_scrollbar(void *scroll, int32_t yes) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    s->SetOverlayScrollbar(yes != 0);
  }
}

void *yue_mbt_separator_new(int32_t orientation) {
  return reinterpret_cast<void *>(ViewStore::put(
      new nu::Separator(static_cast<nu::Orientation>(orientation))));
}

// ---------- 剪贴板 ----------

// 系统剪贴板是静态单例，句柄即单例指针（进程级稳定，绝不 delete）
void *yue_mbt_clipboard_get(void) {
  static nu::Clipboard *g_clipboard = nu::Clipboard::Get();
  return g_clipboard;
}

void yue_mbt_clipboard_set_text(void *clipboard, const char *text) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    c->SetText(text);
  }
}

void *yue_mbt_clipboard_get_text(void *clipboard) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    return BytesFromString(c->GetText());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_clipboard_clear(void *clipboard) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    c->Clear();
  }
}

// ---------- 消息框 ----------

void *yue_mbt_message_box_new(int32_t type) {
  auto *box = new nu::MessageBox();
  box->SetType(static_cast<nu::MessageBox::Type>(type));
  return reinterpret_cast<void *>(MessageBoxStore::put(box));
}

void yue_mbt_message_box_set_title(void *box, const char *title) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->SetTitle(title);
  }
}

void yue_mbt_message_box_set_text(void *box, const char *text) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->SetText(text);
  }
}

void yue_mbt_message_box_set_informative_text(void *box, const char *text) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->SetInformativeText(text);
  }
}

void yue_mbt_message_box_add_button(void *box, const char *title, int32_t response) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->AddButton(title, response);
  }
}

void yue_mbt_message_box_on_response(void *box,
                                     void (*invoke)(void *, int32_t),
                                     void *closure) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->on_response.Connect([invoke, closure](nu::MessageBox *, int response) {
      invoke(closure, response);
    });
  }
}

void yue_mbt_message_box_show(void *box) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->Show();
  }
}

void yue_mbt_message_box_show_for_window(void *box, void *window) {
  auto *m = MessageBoxStore::get(box);
  auto *w = CastTo<nu::Window>(window);
  if (m != nullptr && w != nullptr) {
    m->ShowForWindow(w);
  }
}

void yue_mbt_message_box_close(void *box) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->Close();
  }
}


// ---------- 通知 / 全局快捷键 / 日期选择 / GIF 播放 ----------

using NotificationStore = Store<nu::Notification>;

void *yue_mbt_notification_new(void) {
  return reinterpret_cast<void *>(NotificationStore::put(new nu::Notification()));
}

void yue_mbt_notification_set_title(void *n, const char *title) {
  if (auto *b = NotificationStore::get(n)) {
    b->SetTitle(title);
  }
}

void yue_mbt_notification_set_body(void *n, const char *body) {
  if (auto *b = NotificationStore::get(n)) {
    b->SetBody(body);
  }
}

void yue_mbt_notification_set_silent(void *n, int32_t silent) {
  if (auto *b = NotificationStore::get(n)) {
    b->SetSilent(silent != 0);
  }
}

void yue_mbt_notification_show(void *n) {
  if (auto *b = NotificationStore::get(n)) {
    nu::NotificationCenter::GetCurrent()->AddNotification(b);
  }
}

void yue_mbt_notification_close(void *n) {
  if (auto *b = NotificationStore::get(n)) {
    b->Close();
  }
}

void *yue_mbt_notification_center_get(void) {
  return nu::NotificationCenter::GetCurrent();
}

void yue_mbt_notification_center_add(void *n) {
  yue_mbt_notification_show(n);
}

int32_t yue_mbt_global_shortcut_register(const char *accelerator,
                                         void (*invoke)(void *), void *closure) {
  return nu::GlobalShortcut::GetCurrent()->Register(
      nu::Accelerator(std::string(accelerator)),
      [invoke, closure]() { invoke(closure); });
}

void yue_mbt_global_shortcut_unregister(int32_t id) {
  nu::GlobalShortcut::GetCurrent()->Unregister(id);
}

void *yue_mbt_date_picker_new(void) {
  nu::DatePicker::Options options;
  return reinterpret_cast<void *>(ViewStore::put(new nu::DatePicker(options)));
}

void *yue_mbt_gif_player_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::GifPlayer()));
}

void yue_mbt_gif_player_set_image(void *player, void *image) {
  auto *g = CastTo<nu::GifPlayer>(player);
  auto *img = ImageStore::get(image);
  if (g != nullptr && img != nullptr) {
    g->SetImage(scoped_refptr<nu::Image>(img));
  }
}


// ---------- App / Appearance / Locale / Screen ----------

void yue_mbt_app_set_name(const char *name) {
  nu::App::GetCurrent()->SetName(name);
}

int32_t yue_mbt_app_get_name(char *name_buf) {
  std::string name = nu::App::GetCurrent()->GetName();
  int32_t len = static_cast<int32_t>(name.size());
  std::memcpy(name_buf, name.data(), name.size());
  return len;
}

int32_t yue_mbt_appearance_is_dark(void) {
  return nu::Appearance::GetCurrent()->IsDarkScheme() ? 1 : 0;
}

int32_t yue_mbt_locale_get(char *buf, int32_t cap) {
  std::string id = nu::Locale::GetCurrentIdentifier();
  int32_t len = static_cast<int32_t>(id.size());
  if (len > cap) {
    len = cap;
  }
  std::memcpy(buf, id.data(), len);
  return len;
}

double yue_mbt_screen_get_scale_factor(void) {
  return nu::Screen::GetDefaultScaleFactor();
}

double yue_mbt_screen_get_primary_width(void) {
  nu::Display display = nu::Screen::GetCurrent()->GetPrimaryDisplay();
  return display.bounds.width();
}

double yue_mbt_screen_get_primary_height(void) {
  nu::Display display = nu::Screen::GetCurrent()->GetPrimaryDisplay();
  return display.bounds.height();
}


// ---------- 追加：DatePicker 时间 / Table 信号 / 键盘 / 窗口状态 / Cursor ----------

void yue_mbt_date_picker_set_date(void *picker, int64_t epoch_seconds) {
  if (auto *d = CastTo<nu::DatePicker>(picker)) {
    d->SetDate(base::Time::FromTimeT(static_cast<time_t>(epoch_seconds)));
  }
}

int64_t yue_mbt_date_picker_get_date(void *picker) {
  if (auto *d = CastTo<nu::DatePicker>(picker)) {
    return static_cast<int64_t>(d->GetDate().ToTimeT());
  }
  return 0;
}

void yue_mbt_date_picker_on_date_change(void *picker, void (*invoke)(void *), void *closure) {
  if (auto *d = CastTo<nu::DatePicker>(picker)) {
    d->on_date_change.Connect([invoke, closure](nu::DatePicker *) { invoke(closure); });
  }
}

void yue_mbt_table_on_row_activate(void *table,
                                   void (*invoke)(void *, int32_t),
                                   void *closure) {
  if (auto *t = CastTo<nu::Table>(table)) {
    t->on_row_activate.Connect([invoke, closure](nu::Table *, int row) {
      invoke(closure, row);
    });
  }
}

void yue_mbt_table_on_selection_change(void *table, void (*invoke)(void *), void *closure) {
  if (auto *t = CastTo<nu::Table>(table)) {
    t->on_selection_change.Connect([invoke, closure](nu::Table *) { invoke(closure); });
  }
}

void yue_mbt_table_on_toggle_checkbox(void *table,
                                      void (*invoke)(void *, int32_t, int32_t),
                                      void *closure) {
  if (auto *t = CastTo<nu::Table>(table)) {
    t->on_toggle_checkbox.Connect([invoke, closure](nu::Table *, int column, int row) {
      invoke(closure, column, row);
    });
  }
}

void yue_mbt_view_on_key_down(void *view,
                              int32_t (*invoke)(void *, int32_t, int32_t),
                              void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_key_down.Connect([invoke, closure](nu::Responder *, const nu::KeyEvent &event) {
      return invoke(closure, static_cast<int32_t>(event.key),
                    static_cast<int32_t>(event.modifiers)) != 0;
    });
  }
}

void yue_mbt_view_on_key_up(void *view,
                            int32_t (*invoke)(void *, int32_t, int32_t),
                            void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_key_up.Connect([invoke, closure](nu::Responder *, const nu::KeyEvent &event) {
      return invoke(closure, static_cast<int32_t>(event.key),
                    static_cast<int32_t>(event.modifiers)) != 0;
    });
  }
}

void yue_mbt_window_maximize(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->Maximize();
  }
}

void yue_mbt_window_unmaximize(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->Unmaximize();
  }
}

void yue_mbt_window_set_fullscreen(void *window, int32_t fullscreen) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetFullscreen(fullscreen != 0);
  }
}

int32_t yue_mbt_window_is_fullscreen(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->IsFullscreen() ? 1 : 0;
  }
  return 0;
}

// Cursor 句柄独立（RefCounted）
using CursorStore = Store<nu::Cursor>;

void *yue_mbt_cursor_new(int32_t type) {
  return reinterpret_cast<void *>(
      CursorStore::put(new nu::Cursor(static_cast<nu::Cursor::Type>(type))));
}

void yue_mbt_view_set_cursor(void *view, void *cursor) {
  auto *v = CastToView(view);
  auto *c = CursorStore::get(cursor);
  if (v != nullptr && c != nullptr) {
    v->SetCursor(scoped_refptr<nu::Cursor>(c));
  }
}

// ---------- 托盘 ----------

#if defined(OS_LINUX)

// libyue 的 Linux 托盘在运行期 dlopen AppIndicator，加载失败只打日志，
// 对外无任何查询接口。这里补一个同语义的探测，让 MoonBit 层能提前降级。
// 注意：探测列表必须与 libyue 内部的 dlopen 列表严格一致（只认传统
// libappindicator3，不含 ayatana 分支），否则会"探测可用、实际失效"。
int32_t yue_mbt_tray_supported(void) {
  const char *candidates[] = {
      "libappindicator3.so.1",
      "libappindicator3.so",
  };
  for (const char *name : candidates) {
    if (dlopen(name, RTLD_LAZY) != nullptr) {
      return 1;
    }
  }
  return 0;
}

#else

int32_t yue_mbt_tray_supported(void) {
  return 1;
}

#endif

void *yue_mbt_tray_new(const char *icon_path, int32_t *ok) {
  *ok = 0;
  if (!yue_mbt_tray_supported()) {
    return nullptr;
  }
  auto image = scoped_refptr<nu::Image>(new nu::Image(base::FilePath(icon_path)));
  if (image->IsEmpty()) {
    return nullptr;
  }
  auto tray = scoped_refptr<nu::Tray>(new nu::Tray(image));
  *ok = 1;
  return reinterpret_cast<void *>(TrayStore::put(tray));
}

void yue_mbt_tray_set_title(void *tray, const char *title) {
  // 构造失败（后端缺失）时 nativeui 内部句柄为空，防御性跳过而非崩溃
  auto *t = TrayStore::get(tray);
  if (t != nullptr) {
    t->SetTitle(title);
  }
}

void yue_mbt_tray_remove(void *tray) {
  auto *t = TrayStore::get(tray);
  if (t != nullptr) {
    t->Remove();
  }
}

// ---------- 托盘：nativeui 后端补充 ----------

extern "C" void yue_mbt_tray_set_image(void *tray, void *image) {
  auto *t = TrayStore::get(tray);
  auto *img = ImageStore::get(image);
  if (t != nullptr && img != nullptr) {
    t->SetImage(scoped_refptr<nu::Image>(img));
  }
}

extern "C" void yue_mbt_tray_on_click(void *tray, void (*invoke)(void *), void *closure) {
  auto *t = TrayStore::get(tray);
  if (t != nullptr) {
    t->on_click.Connect([invoke, closure](nu::Tray *) { invoke(closure); });
  }
}

// ---------- 托盘：MoonBit 自实现后端的系统调用转发 ----------
//
// SNI（StatusNotifierItem）协议逻辑全部在 MoonBit 侧（yue/traybus 包），
// 这里只暴露最小化的 fd 级系统调用。全部按"失败返回负值/0"实现，
// 非 Linux 平台走桩函数，MoonBit 侧据此回退 nativeui 托盘。

#if defined(OS_LINUX)

#include <glib-unix.h>

#include <poll.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

extern "C" int32_t yue_mbt_sys_getuid(void) {
  return static_cast<int32_t>(getuid());
}

extern "C" int32_t yue_mbt_sys_getenv(const char *name, char *out, int32_t out_len) {
  const char *v = getenv(name);
  if (v == nullptr) {
    return -1;
  }
  size_t n = strlen(v);
  if (n + 1 > static_cast<size_t>(out_len)) {
    return -2;
  }
  memcpy(out, v, n + 1);
  return static_cast<int32_t>(n);
}

// 连接会话总线（AF_UNIX，非阻塞），失败返回 -1
extern "C" int32_t yue_mbt_sys_unix_connect(const char *path) {
  if (strlen(path) == 0 || strlen(path) >= 108) {
    return -1;
  }
  int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
  if (fd < 0) {
    return -1;
  }
  sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
  if (connect(fd, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) != 0 &&
      errno != EINPROGRESS) {
    close(fd);
    return -1;
  }
  return fd;
}

// >0 = 读到字节数；0 = 对端关闭；-1 = 暂无数据；-2 = 错误
extern "C" int32_t yue_mbt_sys_read(int32_t fd, uint8_t *buf, int32_t off, int32_t len) {
  ssize_t n = read(fd, buf + off, static_cast<size_t>(len));
  if (n > 0) {
    return static_cast<int32_t>(n);
  }
  if (n == 0) {
    return 0;
  }
  return (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) ? -1 : -2;
}

// >=0 = 已写出字节数（可能小于 len）；-1 = 暂不可写；-2 = 错误
extern "C" int32_t yue_mbt_sys_write(int32_t fd, const uint8_t *buf, int32_t off, int32_t len) {
  ssize_t n = write(fd, buf + off, static_cast<size_t>(len));
  if (n >= 0) {
    return static_cast<int32_t>(n);
  }
  return (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) ? -1 : -2;
}

// events: 1 = 可读，4 = 可写。>0 = 就绪事件位，0 = 超时，-1 = 错误
extern "C" int32_t yue_mbt_sys_poll(int32_t fd, int32_t events, int32_t timeout_ms) {
  pollfd p;
  p.fd = fd;
  p.events = static_cast<short>(events);
  p.revents = 0;
  int n = poll(&p, 1, timeout_ms);
  if (n < 0) {
    return -1;
  }
  if (n == 0) {
    return 0;
  }
  return p.revents;
}

extern "C" void yue_mbt_sys_close(int32_t fd) {
  close(fd);
}

// GTK 主循环 fd 监视：回调是无捕获 MoonBit 顶层函数（与 on_click 同一跨
// ABI 模式）。进程级只支持一条 SNI 连接，与 traybus 的全局连接约定一致。
static int32_t (*g_mbt_fd_cb)(int32_t, int32_t) = nullptr;

static gboolean mbt_fd_source_cb(gint fd, GIOCondition cond, gpointer) {
  return g_mbt_fd_cb != nullptr ? g_mbt_fd_cb(fd, static_cast<int32_t>(cond))
                                : TRUE;
}

extern "C" int32_t yue_mbt_sys_watch_fd(int32_t fd, int32_t events,
                             int32_t (*cb)(int32_t, int32_t)) {
  g_mbt_fd_cb = cb;
  return static_cast<int32_t>(g_unix_fd_add(
      fd, static_cast<GIOCondition>(events), mbt_fd_source_cb, nullptr));
}

#else  // 非 Linux：桩实现，托盘回退 nativeui 后端

extern "C" extern "C" int32_t yue_mbt_sys_getuid(void) { return -1; }

extern "C" extern "C" int32_t yue_mbt_sys_getenv(const char *, char *, int32_t) { return -1; }

extern "C" extern "C" int32_t yue_mbt_sys_unix_connect(const char *) { return -1; }

extern "C" extern "C" int32_t yue_mbt_sys_read(int32_t, uint8_t *, int32_t, int32_t) { return -2; }

extern "C" extern "C" int32_t yue_mbt_sys_write(int32_t, const uint8_t *, int32_t, int32_t) {
  return -2;
}

extern "C" extern "C" int32_t yue_mbt_sys_poll(int32_t, int32_t, int32_t) { return -1; }

extern "C" void yue_mbt_sys_close(int32_t) {}

extern "C" extern "C" int32_t yue_mbt_sys_watch_fd(int32_t, int32_t,
                                        int32_t (*)(int32_t, int32_t)) {
  return 0;
}

#endif
