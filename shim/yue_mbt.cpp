// 平台封装层：libyue C++ API → C ABI 的机械转换。
// 原则：本文件只做 ABI 翻译，不写业务逻辑；平台差异优先交给 libyue，
// 只有 libyue 没暴露的（如托盘后端探测）才在这里补。
//
// 类型安全：View 系句柄经 GetClassName() 运行时校验（CastTo），
// MoonBit 侧统一 View 类型后的错型调用在这里被拒绝而非踩空指针。
#include "yue_mbt.h"

#include <cmath>
#include <cstdio>
#include <typeinfo>
#include <cstring>
#include <dlfcn.h>
#include <fstream>

#include "base/command_line.h"
#include "nativeui/nativeui.h"

// 不包含 <moonbit.h>：它在 extern "C" 里声明的 memcpy 与 glibc 的
// C++ noexcept 声明冲突。只声明用到的两个运行时入口，
// 签名照抄 ~/.moon/include/moonbit.h。
extern "C" void *moonbit_make_external_object(void (*finalize)(void *),
                                              uint32_t payload_size);
extern "C" void *moonbit_make_bytes(int32_t size, int value);

namespace {

nu::Lifetime *g_lifetime = nullptr;
nu::State *g_state = nullptr;

// MoonBit Bytes 内容拷贝
void *BytesFromString(const std::string &s) {
  void *bytes = moonbit_make_bytes(static_cast<int32_t>(s.size()), 0);
  if (!s.empty()) {
    std::memcpy(bytes, s.data(), s.size());
  }
  return bytes;
}

// View 系句柄：GC 管容器，finalizer 只释放 scoped_refptr
struct HandleBox {
  scoped_refptr<nu::Responder> resp;  // Window/MenuBar 是 Responder 而非 View
};

template <typename T>
void ReleaseRef(void *ptr) {
  if (ptr != nullptr) {
    static_cast<T *>(ptr)->~T();
  }
}

// 运行时类型校验：错型调用记日志并返回空，MoonBit/上层不踩空指针
template <typename T>
T *CastTo(HandleBox *box) {
  auto *r = box->resp.get();
  if (r == nullptr) {
    std::fprintf(stderr, "yue_mbt: 句柄已释放\n");
    return nullptr;
  }
  auto *t = dynamic_cast<T *>(r);
  if (t == nullptr) {
    std::fprintf(stderr, "yue_mbt: 类型不匹配，期望 %s，实际 %s\n",
                 typeid(T).name(), typeid(*r).name());
  }
  return t;
}

// 通用 View 检查：View 自身无 kClassName，直接 dynamic_cast
nu::View *CastToView(HandleBox *box) {
  return dynamic_cast<nu::View *>(box->resp.get());
}

// 非 View 的独立句柄（MenuBar/Menu/MenuItem 继承 RefCounted 而非 Responder）

struct MenuBarBox {
  scoped_refptr<nu::MenuBar> bar;
};
struct MenuBox {
  scoped_refptr<nu::Menu> menu;
};
struct MenuItemBox {
  scoped_refptr<nu::MenuItem> item;
};
struct FileDialogBox {
  scoped_refptr<nu::FileDialog> dialog;
};
struct TrayBox {
  scoped_refptr<nu::Tray> tray;
};
struct ImageBox {
  scoped_refptr<nu::Image> image;
};
struct CanvasBox {
  scoped_refptr<nu::Canvas> canvas;
};
struct AttributedTextBox {
  scoped_refptr<nu::AttributedText> text;
};
struct FontBox {
  scoped_refptr<nu::Font> font;
};

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
  auto *box = static_cast<HandleBox *>(
      moonbit_make_external_object(ReleaseRef<HandleBox>, sizeof(HandleBox)));
  new (&box->resp) scoped_refptr<nu::Responder>(new nu::Window(options));
  return box;
}

void yue_mbt_window_set_title(void *window, const char *title) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    w->SetTitle(title);
  }
}

void yue_mbt_window_set_always_on_top(void *window, int32_t top) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    w->SetAlwaysOnTop(top != 0);
  }
}

double yue_mbt_window_get_content_size_width(void *window) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    return w->GetContentSize().width();
  }
  return 0;
}

double yue_mbt_window_get_content_size_height(void *window) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    return w->GetContentSize().height();
  }
  return 0;
}

void yue_mbt_window_set_content(void *window, void *content) {
  auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window));
  auto *c = CastToView(static_cast<HandleBox *>(content));
  if (w != nullptr && c != nullptr) {
    w->SetContentView(scoped_refptr<nu::View>(c));
  }
}

void yue_mbt_window_set_content_size(void *window, double width, double height) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    w->SetContentSize(
        nu::SizeF(static_cast<float>(width), static_cast<float>(height)));
  }
}

void yue_mbt_window_center(void *window) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    w->Center();
  }
}

void yue_mbt_window_activate(void *window) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    w->Activate();
  }
}

void yue_mbt_window_set_menubar(void *window, void *menubar) {
  auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window));
  auto *mb = static_cast<MenuBarBox *>(menubar);
  if (w == nullptr || mb == nullptr) {
    return;
  }
  w->SetMenuBar(scoped_refptr<nu::MenuBar>(mb->bar));
}

void yue_mbt_window_on_close(void *window, void (*invoke)(void *), void *closure) {
  if (auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window))) {
    w->on_close.Connect([invoke, closure](nu::Window *) { invoke(closure); });
  }
}

// ---------- View 通用 ----------

void yue_mbt_view_focus(void *view) {
  if (auto *v = CastTo<nu::View>(static_cast<HandleBox *>(view))) {
    v->Focus();
  }
}

void yue_mbt_view_set_enabled(void *view, int32_t enable) {
  if (auto *v = CastTo<nu::View>(static_cast<HandleBox *>(view))) {
    v->SetEnabled(enable != 0);
  }
}

void yue_mbt_view_set_mouse_down_can_move_window(void *view, int32_t yes) {
  if (auto *v = CastTo<nu::View>(static_cast<HandleBox *>(view))) {
    v->SetMouseDownCanMoveWindow(yes != 0);
  }
}

void yue_mbt_view_set_style_prop_float(void *view, const char *name, double value) {
  if (auto *v = CastTo<nu::View>(static_cast<HandleBox *>(view))) {
    v->SetStyleProperty(name, static_cast<float>(value));
  }
}

void yue_mbt_view_set_style_prop_str(void *view, const char *name, const char *value) {
  if (auto *v = CastTo<nu::View>(static_cast<HandleBox *>(view))) {
    v->SetStyleProperty(name, std::string(value));
  }
}

void yue_mbt_view_set_background_color(void *view, const char *hex) {
  if (auto *v = CastTo<nu::View>(static_cast<HandleBox *>(view))) {
    v->SetBackgroundColor(nu::Color(std::string(hex)));
  }
}

// ---------- Container ----------

void *yue_mbt_container_new(void) {
  auto *box = static_cast<HandleBox *>(
      moonbit_make_external_object(ReleaseRef<HandleBox>, sizeof(HandleBox)));
  new (&box->resp) scoped_refptr<nu::Responder>(new nu::Container());
  return box;
}

void yue_mbt_container_add_child(void *container, void *child) {
  auto *c = CastTo<nu::Container>(static_cast<HandleBox *>(container));
  auto *k = CastToView(static_cast<HandleBox *>(child));
  if (c != nullptr && k != nullptr) {
    c->AddChildView(scoped_refptr<nu::View>(k));
  }
}

void yue_mbt_container_on_draw(void *container, void (*invoke)(void *, void *),
                               void *closure) {
  if (auto *c = CastTo<nu::Container>(static_cast<HandleBox *>(container))) {
    c->on_draw.Connect(
        [invoke, closure](nu::Container *, nu::Painter *painter, const nu::RectF &) {
          invoke(closure, painter);
        });
  }
}

// ---------- Label ----------

void *yue_mbt_label_new(const char *text) {
  auto *box = static_cast<HandleBox *>(
      moonbit_make_external_object(ReleaseRef<HandleBox>, sizeof(HandleBox)));
  new (&box->resp) scoped_refptr<nu::Responder>(new nu::Label(text));
  return box;
}

void yue_mbt_label_set_text(void *label, const char *text) {
  if (auto *l = CastTo<nu::Label>(static_cast<HandleBox *>(label))) {
    l->SetText(text);
  }
}

// ---------- TextEdit ----------

void *yue_mbt_text_edit_new(void) {
  auto *box = static_cast<HandleBox *>(
      moonbit_make_external_object(ReleaseRef<HandleBox>, sizeof(HandleBox)));
  new (&box->resp) scoped_refptr<nu::Responder>(new nu::TextEdit());
  return box;
}

void yue_mbt_text_edit_set_text(void *edit, const char *text) {
  if (auto *e = CastTo<nu::TextEdit>(static_cast<HandleBox *>(edit))) {
    e->SetText(text);
  }
}

void *yue_mbt_text_edit_get_text(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(static_cast<HandleBox *>(edit))) {
    return BytesFromString(e->GetText());
  }
  return moonbit_make_bytes(0, 0);
}

double yue_mbt_text_edit_get_text_bounds_height(void *edit) {
  if (auto *e = CastTo<nu::TextEdit>(static_cast<HandleBox *>(edit))) {
    return e->GetTextBounds().height();
  }
  return 0;
}

void yue_mbt_text_edit_on_text_change(void *edit, void (*invoke)(void *),
                                      void *closure) {
  if (auto *e = CastTo<nu::TextEdit>(static_cast<HandleBox *>(edit))) {
    e->on_text_change.Connect([invoke, closure](nu::TextEdit *) { invoke(closure); });
  }
}

// ---------- Button ----------

void *yue_mbt_button_new(const char *title) {
  auto *box = static_cast<HandleBox *>(
      moonbit_make_external_object(ReleaseRef<HandleBox>, sizeof(HandleBox)));
  new (&box->resp) scoped_refptr<nu::Responder>(new nu::Button(title));
  return box;
}

void yue_mbt_button_set_title(void *button, const char *title) {
  if (auto *b = CastTo<nu::Button>(static_cast<HandleBox *>(button))) {
    b->SetTitle(title);
  }
}

void yue_mbt_button_on_click(void *button, void (*invoke)(void *), void *closure) {
  if (auto *b = CastTo<nu::Button>(static_cast<HandleBox *>(button))) {
    b->on_click.Connect([invoke, closure](nu::Button *) { invoke(closure); });
  }
}

// ---------- Entry ----------

void *yue_mbt_entry_new(void) {
  auto *box = static_cast<HandleBox *>(
      moonbit_make_external_object(ReleaseRef<HandleBox>, sizeof(HandleBox)));
  new (&box->resp) scoped_refptr<nu::Responder>(new nu::Entry(nu::Entry::Type::Normal));
  return box;
}

void yue_mbt_entry_set_text(void *entry, const char *text) {
  if (auto *e = CastTo<nu::Entry>(static_cast<HandleBox *>(entry))) {
    e->SetText(text);
  }
}

void *yue_mbt_entry_get_text(void *entry) {
  if (auto *e = CastTo<nu::Entry>(static_cast<HandleBox *>(entry))) {
    return BytesFromString(e->GetText());
  }
  return moonbit_make_bytes(0, 0);
}

// ---------- Browser ----------

void *yue_mbt_browser_new(void) {
  nu::Browser::Options options;
  options.context_menu = true;
  auto *box = static_cast<HandleBox *>(
      moonbit_make_external_object(ReleaseRef<HandleBox>, sizeof(HandleBox)));
  new (&box->resp) scoped_refptr<nu::Responder>(new nu::Browser(options));
  return box;
}

void yue_mbt_browser_load_url(void *browser, const char *url) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->LoadURL(url);
  }
}

void *yue_mbt_browser_get_url(void *browser) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    return BytesFromString(b->GetURL());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_browser_reload(void *browser) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->Reload();
  }
}

void yue_mbt_browser_go_back(void *browser) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->GoBack();
  }
}

void yue_mbt_browser_go_forward(void *browser) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->GoForward();
  }
}

int32_t yue_mbt_browser_can_go_back(void *browser) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    return b->CanGoBack() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_browser_can_go_forward(void *browser) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    return b->CanGoForward() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_browser_is_loading(void *browser) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    return b->IsLoading() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_browser_on_change_loading(void *browser, void (*invoke)(void *),
                                       void *closure) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->on_change_loading.Connect(
        [invoke, closure](nu::Browser *) { invoke(closure); });
  }
}

void yue_mbt_browser_on_update_command(void *browser, void (*invoke)(void *),
                                       void *closure) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->on_update_command.Connect(
        [invoke, closure](nu::Browser *) { invoke(closure); });
  }
}

void yue_mbt_browser_on_update_title(void *browser,
                                     void (*invoke)(void *, void *),
                                     void *closure) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->on_update_title.Connect([invoke, closure](nu::Browser *,
                                                 const std::string &title) {
      invoke(closure, BytesFromString(title));
    });
  }
}

void yue_mbt_browser_on_commit_navigation(void *browser,
                                          void (*invoke)(void *, void *),
                                          void *closure) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->on_commit_navigation.Connect([invoke, closure](nu::Browser *,
                                                      const std::string &url) {
      invoke(closure, BytesFromString(url));
    });
  }
}

void yue_mbt_browser_on_finish_navigation(void *browser,
                                          void (*invoke)(void *, void *),
                                          void *closure) {
  if (auto *b = CastTo<nu::Browser>(static_cast<HandleBox *>(browser))) {
    b->on_finish_navigation.Connect([invoke, closure](nu::Browser *,
                                                      const std::string &url) {
      invoke(closure, BytesFromString(url));
    });
  }
}

// ---------- 菜单 ----------

void *yue_mbt_menu_bar_new(void) {
  auto *box = static_cast<MenuBarBox *>(
      moonbit_make_external_object(ReleaseRef<MenuBarBox>, sizeof(MenuBarBox)));
  new (&box->bar) scoped_refptr<nu::MenuBar>(new nu::MenuBar());
  return box;
}

// 在顶栏挂标题项并返回其子菜单；item 由 menu 的 items 持有引用
void *yue_mbt_menu_bar_add_menu(void *menubar, const char *title) {
  auto *mb = static_cast<MenuBarBox *>(menubar);
  if (mb == nullptr) {
    return nullptr;
  }
  auto *bar = mb->bar.get();
  auto item = scoped_refptr<nu::MenuItem>(
      new nu::MenuItem(nu::MenuItem::Type::Submenu));
  item->SetLabel(title);
  auto menu = scoped_refptr<nu::Menu>(new nu::Menu());
  item->SetSubmenu(menu);
  bar->Append(item);
  auto *box = static_cast<MenuBox *>(
      moonbit_make_external_object(ReleaseRef<MenuBox>, sizeof(MenuBox)));
  new (&box->menu) scoped_refptr<nu::Menu>(menu);
  return box;
}

void *yue_mbt_menu_add_submenu(void *menu, const char *title) {
  auto *parent = static_cast<MenuBox *>(menu);
  if (parent == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(
      new nu::MenuItem(nu::MenuItem::Type::Submenu));
  item->SetLabel(title);
  auto sub = scoped_refptr<nu::Menu>(new nu::Menu());
  item->SetSubmenu(sub);
  parent->menu->Append(item);
  auto *box = static_cast<MenuBox *>(
      moonbit_make_external_object(ReleaseRef<MenuBox>, sizeof(MenuBox)));
  new (&box->menu) scoped_refptr<nu::Menu>(sub);
  return box;
}

void *yue_mbt_menu_add_label_item(void *menu, const char *label) {
  auto *m = static_cast<MenuBox *>(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(new nu::MenuItem(nu::MenuItem::Type::Label));
  item->SetLabel(label);
  m->menu->Append(item);
  auto *box =
      static_cast<MenuItemBox *>(moonbit_make_external_object(
          ReleaseRef<MenuItemBox>, sizeof(MenuItemBox)));
  new (&box->item) scoped_refptr<nu::MenuItem>(item);
  return box;
}

void *yue_mbt_menu_add_role_item(void *menu, int32_t role) {
  auto *m = static_cast<MenuBox *>(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(
      new nu::MenuItem(static_cast<nu::MenuItem::Role>(role)));
  m->menu->Append(item);
  auto *box = static_cast<MenuItemBox *>(
      moonbit_make_external_object(ReleaseRef<MenuItemBox>, sizeof(MenuItemBox)));
  new (&box->item) scoped_refptr<nu::MenuItem>(item);
  return box;
}

void *yue_mbt_menu_add_separator(void *menu) {
  auto *m = static_cast<MenuBox *>(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item =
      scoped_refptr<nu::MenuItem>(new nu::MenuItem(nu::MenuItem::Type::Separator));
  m->menu->Append(item);
  auto *box = static_cast<MenuItemBox *>(
      moonbit_make_external_object(ReleaseRef<MenuItemBox>, sizeof(MenuItemBox)));
  new (&box->item) scoped_refptr<nu::MenuItem>(item);
  return box;
}

void yue_mbt_menu_item_set_label(void *item, const char *label) {
  if (auto *i = static_cast<MenuItemBox *>(item)) {
    i->item->SetLabel(label);
  }
}



void yue_mbt_menu_item_set_accelerator(void *item, const char *accelerator) {
  if (auto *i = static_cast<MenuItemBox *>(item)) {
    i->item->SetAccelerator(nu::Accelerator(std::string(accelerator)));
  }
}

void yue_mbt_menu_item_on_click(void *item, void (*invoke)(void *), void *closure) {
  if (auto *i = static_cast<MenuItemBox *>(item)) {
    i->item->on_click.Connect([invoke, closure](nu::MenuItem *) { invoke(closure); });
  }
}

// ---------- 文件对话框 ----------

void *yue_mbt_file_open_dialog_new(void) {
  auto *box = static_cast<FileDialogBox *>(
      moonbit_make_external_object(ReleaseRef<FileDialogBox>,
                                   sizeof(FileDialogBox)));
  new (&box->dialog) scoped_refptr<nu::FileDialog>(new nu::FileOpenDialog());
  return box;
}

void *yue_mbt_file_save_dialog_new(void) {
  auto *box = static_cast<FileDialogBox *>(
      moonbit_make_external_object(ReleaseRef<FileDialogBox>,
                                   sizeof(FileDialogBox)));
  new (&box->dialog) scoped_refptr<nu::FileDialog>(new nu::FileSaveDialog());
  return box;
}

// filters 打包："描述:扩展1,扩展2|描述2:扩展3"
void yue_mbt_file_dialog_set_filters(void *dialog, const char *filters) {
  if (auto *d = static_cast<FileDialogBox *>(dialog)) {
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
    d->dialog->SetFilters(parsed);
  }
}

void yue_mbt_file_dialog_set_folder(void *dialog, const char *folder) {
  if (auto *d = static_cast<FileDialogBox *>(dialog)) {
    d->dialog->SetFolder(base::FilePath(folder));
  }
}

void yue_mbt_file_dialog_set_filename(void *dialog, const char *filename) {
  if (auto *d = static_cast<FileDialogBox *>(dialog)) {
    d->dialog->SetFilename(filename);
  }
}

int32_t yue_mbt_file_dialog_run_for_window(void *dialog, void *window) {
  auto *d = static_cast<FileDialogBox *>(dialog);
  auto *w = CastTo<nu::Window>(static_cast<HandleBox *>(window));
  if (d == nullptr || w == nullptr) {
    return 0;
  }
  return d->dialog->RunForWindow(w) ? 1 : 0;
}

void *yue_mbt_file_dialog_get_result(void *dialog) {
  if (auto *d = static_cast<FileDialogBox *>(dialog)) {
    return BytesFromString(d->dialog->GetResult().value());
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
  float cx = static_cast<float>(x);
  float cy = static_cast<float>(y);
  float r = static_cast<float>(radius);
  float sa = static_cast<float>(start_angle);
  float ea = static_cast<float>(end_angle);
  // libyue 的 Arc 无反向参数：逆时针用负角跨度表达（等价于 canvas 语义）
  if (ccw != 0 && ea > sa) {
    ea -= static_cast<float>(2 * M_PI);
  }
  p->Arc(nu::PointF(cx, cy), r, sa, ea);
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
  auto *at = static_cast<AttributedTextBox *>(attributed_text);
  auto *p = static_cast<nu::Painter *>(painter);
  if (at == nullptr || p == nullptr) {
    return;
  }
  p->DrawAttributedText(at->text,
                        nu::RectF(static_cast<float>(x), static_cast<float>(y),
                                  static_cast<float>(w), static_cast<float>(h)));
}

void yue_mbt_painter_draw_image(void *painter, void *image, double x, double y,
                                double w, double h) {
  auto *img = static_cast<ImageBox *>(image);
  auto *p = static_cast<nu::Painter *>(painter);
  if (img == nullptr || p == nullptr) {
    return;
  }
  p->DrawImage(img->image.get(),
               nu::RectF(static_cast<float>(x), static_cast<float>(y),
                         static_cast<float>(w), static_cast<float>(h)));
}

void yue_mbt_painter_draw_image_from_rect(void *painter, void *image, double sx,
                                          double sy, double sw, double sh,
                                          double dx, double dy, double dw,
                                          double dh) {
  auto *img = static_cast<ImageBox *>(image);
  auto *p = static_cast<nu::Painter *>(painter);
  if (img == nullptr || p == nullptr) {
    return;
  }
  p->DrawImageFromRect(
      img->image.get(),
      nu::RectF(static_cast<float>(sx), static_cast<float>(sy),
                static_cast<float>(sw), static_cast<float>(sh)),
      nu::RectF(static_cast<float>(dx), static_cast<float>(dy),
                static_cast<float>(dw), static_cast<float>(dh)));
}

void yue_mbt_painter_draw_canvas(void *painter, void *canvas, double x, double y,
                                 double w, double h) {
  auto *c = static_cast<CanvasBox *>(canvas);
  auto *p = static_cast<nu::Painter *>(painter);
  if (c == nullptr || p == nullptr) {
    return;
  }
  p->DrawCanvas(c->canvas.get(),
                nu::RectF(static_cast<float>(x), static_cast<float>(y),
                          static_cast<float>(w), static_cast<float>(h)));
}

void yue_mbt_painter_draw_canvas_from_rect(void *painter, void *canvas,
                                           double sx, double sy, double sw,
                                           double sh, double dx, double dy,
                                           double dw, double dh) {
  auto *c = static_cast<CanvasBox *>(canvas);
  auto *p = static_cast<nu::Painter *>(painter);
  if (c == nullptr || p == nullptr) {
    return;
  }
  p->DrawCanvasFromRect(
      c->canvas.get(),
      nu::RectF(static_cast<float>(sx), static_cast<float>(sy),
                static_cast<float>(sw), static_cast<float>(sh)),
      nu::RectF(static_cast<float>(dx), static_cast<float>(dy),
                static_cast<float>(dw), static_cast<float>(dh)));
}

// ---------- Canvas / AttributedText / Font / Image ----------

void *yue_mbt_canvas_new(double width, double height) {
  auto *box = static_cast<CanvasBox *>(
      moonbit_make_external_object(ReleaseRef<CanvasBox>, sizeof(CanvasBox)));
  new (&box->canvas)
      scoped_refptr<nu::Canvas>(new nu::Canvas(nu::SizeF(
          static_cast<float>(width), static_cast<float>(height))));
  return box;
}

void *yue_mbt_canvas_get_painter(void *canvas) {
  if (auto *c = static_cast<CanvasBox *>(canvas)) {
    return c->canvas->GetPainter();
  }
  return nullptr;
}

void *yue_mbt_attributed_text_new(const char *text, int32_t align, int32_t valign) {
  nu::TextFormat format;
  format.align = static_cast<nu::TextAlign>(align);
  format.valign = static_cast<nu::TextAlign>(valign);
  auto *box = static_cast<AttributedTextBox *>(
      moonbit_make_external_object(ReleaseRef<AttributedTextBox>,
                                   sizeof(AttributedTextBox)));
  new (&box->text) scoped_refptr<nu::AttributedText>(
      new nu::AttributedText(text, format));
  return box;
}

void yue_mbt_attributed_text_set_font(void *at, void *font) {
  auto *t = static_cast<AttributedTextBox *>(at);
  auto *f = static_cast<FontBox *>(font);
  if (t != nullptr && f != nullptr) {
    t->text->SetFont(scoped_refptr<nu::Font>(f->font));
  }
}

void yue_mbt_attributed_text_set_color(void *at, const char *hex) {
  if (auto *t = static_cast<AttributedTextBox *>(at)) {
    t->text->SetColor(nu::Color(std::string(hex)));
  }
}

void yue_mbt_attributed_text_get_bounds_for(void *at, double w, double h,
                                            double *out_w, double *out_h) {
  if (auto *t = static_cast<AttributedTextBox *>(at)) {
    nu::RectF bounds = t->text->GetBoundsFor(
        nu::SizeF(static_cast<float>(w), static_cast<float>(h)));
    *out_w = bounds.width();
    *out_h = bounds.height();
  } else {
    *out_w = 0;
    *out_h = 0;
  }
}

void *yue_mbt_font_new(const char *name, double size, int32_t weight,
                       int32_t style) {
  auto *box = static_cast<FontBox *>(
      moonbit_make_external_object(ReleaseRef<FontBox>, sizeof(FontBox)));
  new (&box->font) scoped_refptr<nu::Font>(
      new nu::Font(name, static_cast<float>(size),
                   static_cast<nu::Font::Weight>(weight),
                   static_cast<nu::Font::Style>(style)));
  return box;
}

void *yue_mbt_image_new_from_file(const char *path) {
  auto *box = static_cast<ImageBox *>(
      moonbit_make_external_object(ReleaseRef<ImageBox>, sizeof(ImageBox)));
  new (&box->image)
      scoped_refptr<nu::Image>(new nu::Image(base::FilePath(path)));
  return box;
}

double yue_mbt_image_get_width(void *image) {
  if (auto *i = static_cast<ImageBox *>(image)) {
    return i->image->GetSize().width();
  }
  return 0;
}

double yue_mbt_image_get_height(void *image) {
  if (auto *i = static_cast<ImageBox *>(image)) {
    return i->image->GetSize().height();
  }
  return 0;
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
  auto *box = static_cast<TrayBox *>(
      moonbit_make_external_object(ReleaseRef<TrayBox>, sizeof(TrayBox)));
  new (&box->tray) scoped_refptr<nu::Tray>(new nu::Tray(image));
  *ok = 1;
  return box;
}

void yue_mbt_tray_set_title(void *tray, const char *title) {
  // 构造失败（后端缺失）时 nativeui 内部句柄为空，防御性跳过而非崩溃
  auto *t = static_cast<TrayBox *>(tray)->tray.get();
  if (t != nullptr) {
    t->SetTitle(title);
  }
}

void yue_mbt_tray_remove(void *tray) {
  auto *t = static_cast<TrayBox *>(tray)->tray.get();
  if (t != nullptr) {
    t->Remove();
  }
}
