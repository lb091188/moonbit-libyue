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
// MSVC 的 M_PI 需要显式开启（painter 角度换算用到）
#if defined(_MSC_VER)
#define _USE_MATH_DEFINES
#endif
#if defined(_WIN32)
// 通知 AUMID 注册与气泡替代窗口所需（shobjidl 提供
// SetCurrentProcessExplicitAppUserModelID）
#include <windows.h>
#include <shobjidl.h>
#include <winreg.h>
#include <shellapi.h>
#include <richedit.h>
#include <commctrl.h>
#endif
#include "yue_mbt.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <ctime>
#include <typeinfo>
#if defined(__linux__)
#include <dlfcn.h>
#endif
#if defined(OS_LINUX)
#include <set>
#endif
#if !defined(_WIN32)
#include <unistd.h> // CurrentDirForDrag 的 getcwd(macOS 分支)
#endif
#include <fstream>
#include <new>
#include <map>
#include <unordered_map>

#include "base/command_line.h"
#include "base/json/json_writer.h"
#include "nativeui/nativeui.h"
#if defined(OS_LINUX) // set_borderless 的 GtkCssProvider 注入(仅 Linux GTK)
#include <gtk/gtk.h>
#include "nativeui/popover.h"
#include "nativeui/gtk/nu_container.h"
#endif
#include "nativeui/date_picker.h"
#include "nativeui/gif_player.h"
#include "nativeui/global_shortcut.h"
#include "nativeui/notification.h"
#include "nativeui/notification_center.h"
#include "nativeui/cursor.h"
#include "nativeui/app.h"
#include "nativeui/appearance.h"
#include "base/strings/sys_string_conversions.h"
#include "nativeui/locale.h"
#include "nativeui/screen.h"
#if defined(OS_WIN)
#include "nativeui/win/window_win.h" // WindowImpl::hwnd()（气泡替代窗口定位/置顶）
#include "nativeui/win/subwin_view.h" // SubwinView::hwnd()（原生子控件 HWND 操作）
#include "nativeui/win/view_win.h" // ViewImpl::wheel_hook（滚轮消费钩子）
#include "nativeui/win/util/tray_host.h" // TrayHost::hwnd()（托盘幽灵图标防护）
#endif

// 不包含 <moonbit.h>：它在 extern "C" 里声明的 memcpy 与 glibc 的
// C++ noexcept 声明冲突。只声明用到的运行时入口，签名照抄
// ~/.moon/include/moonbit.h。
extern "C" void *moonbit_make_bytes(int32_t size, int value);

// C++ 对象一律走系统堆（MoonBit 运行时可能接管进程分配器，普通 new 会被
// GC 破坏）：Linux 用 __libc_malloc/__libc_free；Windows 下 moon 以
// MOONBIT_ALLOCATOR=SYSTEM 编译运行时，重定向到 malloc/free；macOS 用
// libc 的 malloc/free。原理见 docs/adaptation.md。
#if defined(_WIN32)
#include <cstdlib>
static void *raw_heap_malloc(std::size_t size) {
  return std::malloc(size);
}
static void raw_heap_free(void *p) {
  std::free(p);
}
#elif defined(OS_MAC)
#include <cstdlib>
static void *raw_heap_malloc(std::size_t size) {
  return std::malloc(size);
}
static void raw_heap_free(void *p) {
  std::free(p);
}
#else
extern "C" void *__libc_malloc(size_t size);
extern "C" void __libc_free(void *ptr);
static void *raw_heap_malloc(std::size_t size) {
  return __libc_malloc(size);
}
static void raw_heap_free(void *p) {
  __libc_free(p);
}
#endif

void *operator new(std::size_t size) {
  void *p = raw_heap_malloc(size);
  if (p == nullptr) {
    throw std::bad_alloc();
  }
  return p;
}

void *operator new[](std::size_t size) {
  void *p = raw_heap_malloc(size);
  if (p == nullptr) {
    throw std::bad_alloc();
  }
  return p;
}

void operator delete(void *p) noexcept {
  raw_heap_free(p);
}

void operator delete[](void *p) noexcept {
  raw_heap_free(p);
}

void operator delete(void *p, std::size_t) noexcept {
  raw_heap_free(p);
}

void operator delete[](void *p, std::size_t) noexcept {
  raw_heap_free(p);
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
#if defined(OS_LINUX)
using PopoverStore = Store<nu::Popover>;
// DDE(deepin 23/25 实测)下透明气泡窗不可见且 SetCapture 拖慢全局鼠标:
// 回退为无边框普通窗口(非 DDE 桌面仍用原生气泡)
using PopoverWindowStore = Store<nu::Window>;
static bool IsDeepinDesktop() {
  // deepin 23 环境值为 DDE、25 为 Deepin,两种都要认
  const char *cur = std::getenv("XDG_CURRENT_DESKTOP");
  if (cur == nullptr) {
    return false;
  }
  return std::strstr(cur, "Deepin") != nullptr ||
         std::strstr(cur, "DDE") != nullptr;
}
#else
// Windows/macOS 版 libyue 无 Popover：用无边框小窗口替代
// （mac 的 Window::Options 无 no_activate 字段，弹窗可能抢焦点，桩级可接受）
using PopoverStore = Store<nu::Window>;
#endif
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

// base::FilePath 在 Windows（UNICODE 构建）的 StringType 是 std::wstring；
// ABI 边界统一 UTF-8，进出都经 libyue 的 FromUTF8Unsafe/AsUTF8Unsafe。
base::FilePath FilePathFromUTF8(const char *utf8) {
  return base::FilePath::FromUTF8Unsafe(utf8);
}

std::string FilePathValueToUTF8(const base::FilePath &path) {
  return path.AsUTF8Unsafe();
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

void *yue_mbt_window_new_ex(int32_t frame, int32_t transparent, int32_t no_activate) {
  nu::Window::Options options;
  options.frame = frame != 0;
  options.transparent = transparent != 0;
#if !defined(OS_MAC)
  options.no_activate = no_activate != 0; // mac 的 Options 无此字段，忽略
#else
  (void)no_activate;
#endif
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
#if defined(OS_MAC)
  // mac 的 Window 无 SetMenuBar（菜单挂 App 级），降级为提示
  (void)window;
  (void)menubar;
  std::fprintf(stderr, "yue_mbt: macOS 暂不支持窗口级菜单栏\n");
#else
  auto *w = CastTo<nu::Window>(window);
  if (w == nullptr || menubar == nullptr) {
    return;
  }
  if (auto *bar = MenuBarStore::get(menubar)) {
    w->SetMenuBar(scoped_refptr<nu::MenuBar>(bar));
  }
#endif
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

void yue_mbt_view_set_visible(void *view, int visible) {
  if (auto *v = CastToView(view)) {
    v->SetVisible(visible != 0);
  }
}

void yue_mbt_view_schedule_paint(void *view) {
  if (auto *v = CastToView(view)) {
    v->SchedulePaint();
  }
}

void yue_mbt_view_set_borderless(void *view, int on) {
#if defined(OS_LINUX)
  if (auto *v = CastToView(view)) {
    static GtkCssProvider *provider = nullptr;
    if (provider == nullptr) {
      provider = gtk_css_provider_new();
      // 注意:本 class 只做视觉去边框;GTK3 里 class 作用域的 min-height
      // 等尺寸属性压不过主题的 entry{min-height}(实测 G_MAXUINT 优先级
      // 也不行,仅全局 entry{} 类型选择器可,但会波及全应用),内嵌原生
      // 控件的自绘容器必须给足分配尺寸(参照 input_t:外层 40、margin 4)
      gtk_css_provider_load_from_data(provider,
          ".yue-borderless { border: none; box-shadow: none; "
          "background-image: none; }", -1, nullptr);
      gtk_style_context_add_provider_for_screen(
          gdk_screen_get_default(), GTK_STYLE_PROVIDER(provider),
          G_MAXUINT);
    }
    GtkStyleContext *ctx =
        gtk_widget_get_style_context(v->GetNative());
    if (on)
      gtk_style_context_add_class(ctx, "yue-borderless");
    else
      gtk_style_context_remove_class(ctx, "yue-borderless");
  }
#elif defined(OS_WIN)
  // Windows:Entry 是 Win32 EDIT,内阴影来自扩展边缘样式——上游 EntryImpl
  // 创建用 WS_EX_STATICEDGE(不是 CLIENTEDGE!),一并清 CLIENTEDGE/WS_BORDER。
  // ViewImpl 不公开 hwnd;原生子控件(EDIT/DATETIMEPICK 等)的实现在
  // SubwinView(经 Win32Window 暴露 hwnd()),dynamic_cast 取,非子窗口
  // 控件(Container 等自绘)无 HWND 属预期,跳过。
  if (auto *v = CastToView(view)) {
    auto *subwin = dynamic_cast<nu::SubwinView *>(v->GetNative());
    HWND hwnd = subwin != nullptr ? subwin->hwnd() : nullptr;
    if (hwnd) {
      static bool logged = false;
      LONG_PTR ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
      LONG_PTR st = GetWindowLongPtrW(hwnd, GWL_STYLE);
      if (on) {
        ex &= ~(WS_EX_STATICEDGE | WS_EX_CLIENTEDGE);
        st &= ~WS_BORDER;
      } else {
        ex |= WS_EX_CLIENTEDGE;
        st |= WS_BORDER;
      }
      SetWindowLongPtrW(hwnd, GWL_EXSTYLE, ex);
      SetWindowLongPtrW(hwnd, GWL_STYLE, st);
      SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                       SWP_FRAMECHANGED);
      if (!logged) {
        logged = true;
        std::fprintf(stderr, "yue_mbt: set_borderless(on=%d) applied\n", on);
      }
    }
  }
#else
  // macOS:NSScrollView 自身无内嵌边框,无需处理
  (void)view;
  (void)on;
#endif
}

void yue_mbt_view_layout(void *view) {
  if (auto *v = CastToView(view)) {
    // 强制重算布局并同步原生子控件位置(Windows 上滚动后
    // 原生 EDIT HWND 不随容器滚动移动,需在 on_scroll 里补一次)
    v->Layout();
  }
}

void yue_mbt_view_set_font(void *view, void *font) {
  auto *f = FontStore::get(font);
  if (auto *v = CastToView(view)) {
    if (f != nullptr) {
      v->SetFont(scoped_refptr<nu::Font>(f));
    }
  }
}

void yue_mbt_view_set_color(void *view, const char *hex) {
  if (auto *v = CastToView(view)) {
    v->SetColor(nu::Color(std::string(hex)));
  }
}

void yue_mbt_label_set_align(void *label, int32_t align) {
  if (auto *l = CastTo<nu::Label>(label)) {
    l->SetAlign(static_cast<nu::TextAlign>(align));
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

void *yue_mbt_label_get_text(void *label) {
  if (auto *l = CastTo<nu::Label>(label)) {
    return BytesFromString(l->GetText());
  }
  return moonbit_make_bytes(0, 0);
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

/* Button::Type：0=Normal 1=Checkbox 2=Radio（Disclosure 为 macOS 专属不暴露） */
void *yue_mbt_button_new_typed(const char *title, int32_t type) {
  static const nu::Button::Type kTypes[] = {
    nu::Button::Type::Normal,
    nu::Button::Type::Checkbox,
    nu::Button::Type::Radio,
  };
  if (type < 0 || type >= 3) {
    type = 0;
  }
  return reinterpret_cast<void *>(ViewStore::put(new nu::Button(title, kTypes[type])));
}

void yue_mbt_button_set_checked(void *button, int32_t checked) {
  if (auto *b = CastTo<nu::Button>(button)) {
    b->SetChecked(checked != 0);
  }
}

int32_t yue_mbt_button_is_checked(void *button) {
  if (auto *b = CastTo<nu::Button>(button)) {
    return b->IsChecked() ? 1 : 0;
  }
  return 0;
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

#if defined(OS_LINUX)
/* Entry 尺寸归一化(仅 Linux,首次创建 Entry 时注册一次):GTK 主题给
 * entry 的 min-height(Orchis 实测 32px)会被 libyue 在构造期读走钉成
 * yoga 最小值,系统主题一换数值就变,内嵌窄容器的原生子窗口随之溢出
 * (「自定义主题被顶爆」)。全局类型选择器 entry{...} 是唯一能压过主题
 * min-height 的写法(class 作用域与 * 通配实测均无效,G_MAXUINT 优先级
 * 亦然);归零后自然高度≈文字行高,尺寸完全由容器分配决定,与主题无关。
 * 宽度另有 GTK 硬编码 150px 下限,CSS 压不过,由 width_chars 参数绕过。 */
static void yue_mbt_entry_normalize_metrics(void) {
  static GtkCssProvider *provider = nullptr;
  if (provider == nullptr && gdk_screen_get_default() != nullptr) {
    yue_mbt_apply_native_theme_css(nullptr); // 默认浅色接管
    provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider,
        "entry { min-height: 0px; padding: 0px 6px; }", -1, nullptr);
    gtk_style_context_add_provider_for_screen(
        gdk_screen_get_default(), GTK_STYLE_PROVIDER(provider),
        G_MAXUINT);
  }
}

/* 原生控件颜色接管(仅 Linux):文字/插入符/占位符/选区/滚动条/弹层底
 * 全部钉死,不再跟随系统主题(深色系统主题下白底输入框会白字白底、
 * 多行输入框被刷成主题深底)。默认浅色与组件库自绘面一致;theme_apply
 * 经 yue_mbt_apply_native_theme_css 用主题色板整体覆盖。 */
static GtkCssProvider *g_native_color_provider = nullptr;

static const char *kDefaultNativeColors =
    "label { color: #2A2F36; }"
    "entry { color: #2A2F36; caret-color: #2A2F36;"
    "  background-color: #FFFFFF; background-image: none;"
    "  outline-width: 0px; }"
    "entry:not(.yue-borderless) { border: 1px solid #D8DCE1; }"
    "entry undershoot { background: none; }"
    "entry selection { background-color: #E8F0FB; color: #2A2F36; }"
    "entry placeholder { color: #9AA0A6; }"
    "textview { background-color: #FFFFFF; color: #2A2F36; }"
    "textview text { background-color: #FFFFFF; color: #2A2F36; }"
    "textview text selection { background-color: #E8F0FB; color: #2A2F36; }"
    "scrollbar { background-color: transparent; background-image: none;"
    "  border: none; box-shadow: none; }"
    "scrollbar slider { background-color: #C4C9D0; background-image: none;"
    "  border: none; box-shadow: none; border-radius: 0px; }"
    "scrollbar slider:hover { background-color: #9AA0A6; }"
    "scrolledwindow junction { background-color: #FFFFFF; background-image: none; }"
    "scrolledwindow undershoot { background: none; box-shadow: none; }"
    "window { background-color: #FFFFFF; background-image: none;"
    "  border: none; box-shadow: none; }"
    "decoration { border: none; box-shadow: none; }"
    /* 原生 tooltip 恒深底白字:系统主题 tooltip 底/字色是两处独立配置,
     * 深色系统主题下常见深底深字不可读(与 MoonBit 侧
     * apply_native_theme_css 的规则保持一致) */
    "tooltip, tooltip.background, window.tooltip { background-color: #303133; border-radius: 3px; color: #FFFFFF; }"
    "tooltip label, tooltip.background label, window.tooltip label { color: #FFFFFF; }";

#endif

void yue_mbt_apply_native_theme_css(const char *css) {
#if defined(OS_LINUX)

  // 无显示(纯 MoonBit 测试等)时 screen 为 NULL,直接跳过:接管本就
  // 依赖屏幕,此处不注册也不影响有显示时的后续注册
  GdkScreen *screen = gdk_screen_get_default();
  if (screen == nullptr) {
    return;
  }
  if (g_native_color_provider == nullptr) {
    g_native_color_provider = gtk_css_provider_new();
    // G_MAXUINT-1:仍碾压系统主题(200),但低于 metrics/borderless 的
    // G_MAXUINT——libyue 弹层边框色取「GtkEntry#entry 渲染 frame」采样,
    // 这里的 entry border 规则就是给它上浅色的;带 .yue-borderless 的
    // 真实输入框由 borderless 规则去边,不受此 border 影响
    gtk_style_context_add_provider_for_screen(
        screen, GTK_STYLE_PROVIDER(g_native_color_provider), G_MAXUINT - 1);
    // 关闭 overlay 滚动条:滚动时才浮现的条无法稳定呈现钉色,
    // 常驻经典式与 EP 风格一致(属性 3.24 起,缺席时跳过)
    auto *settings = gtk_settings_get_for_screen(screen);
    if (settings != nullptr &&
        g_object_class_find_property(
            G_OBJECT_GET_CLASS(settings), "gtk-overlay-scrolling") != nullptr) {
      g_object_set(settings, "gtk-overlay-scrolling", FALSE, (void *)nullptr);
    }
  }
  gtk_css_provider_load_from_data(
      g_native_color_provider,
      css != nullptr ? css : kDefaultNativeColors, -1, nullptr);
#endif
}


/* 设置光标位置(index 负值=末尾,-1 默认;仅 Linux):GtkEntry 溢出滚动
 * 按像素裁切,左缘余量随光标位置在 0~一个字宽间变化(观感为"内边距
 * 跳变");失焦时把光标归 0 可让文本滚回首端,静态观感固定左对齐。 */
void yue_mbt_entry_set_position(void *entry, int32_t index) {
#if defined(OS_LINUX)
  if (auto *e = CastTo<nu::Entry>(entry)) {
    gtk_editable_set_position(GTK_EDITABLE(e->GetNative()), index);
  }
#endif
}

/* width_chars:可见字符数,-1 用 GTK 默认;仅 Linux 有意义(构造期钉住
 * 首选宽度,运行期再改不生效,见上),其余平台忽略。 */
void *yue_mbt_entry_new_ex(int32_t type, int32_t width_chars) {
#if defined(OS_LINUX)
  yue_mbt_entry_normalize_metrics();
  auto *e = new nu::Entry(
      type == 1 ? nu::Entry::Type::Password : nu::Entry::Type::Normal);
  if (width_chars >= 0) {
    gtk_entry_set_width_chars(GTK_ENTRY(e->GetNative()), width_chars);
  }
  return reinterpret_cast<void *>(ViewStore::put(e));
#else
  return yue_mbt_entry_new_typed(type);
#endif
}

void *yue_mbt_entry_new(void) {
  return yue_mbt_entry_new_ex(0, -1);
}

/* Entry::Type：0=Normal 1=Password */
void *yue_mbt_entry_new_typed(int32_t type) {
  return yue_mbt_entry_new_ex(type, -1);
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

/* GetCookiesForURL：回调收到扁平 UTF-8 文本，每行一条 Cookie，
 * 字段以 \x1f 分隔：name/value/domain/path/http_only/secure */
void yue_mbt_browser_get_cookies_for_url(void *browser, const char *url,
                                         void (*invoke)(void *, void *), void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->GetCookiesForURL(std::string(url),
                        [invoke, closure](std::vector<nu::Cookie> cookies) {
                          std::string flat;
                          for (const auto &c : cookies) {
                            flat += c.name;
                            flat += '\x1f';
                            flat += c.value;
                            flat += '\x1f';
                            flat += c.domain;
                            flat += '\x1f';
                            flat += c.path;
                            flat += '\x1f';
                            flat += c.http_only ? "1" : "0";
                            flat += '\x1f';
                            flat += c.secure ? "1" : "0";
                            flat += '\n';
                          }
                          invoke(closure, BytesFromString(flat));
                        });
  }
}

void yue_mbt_browser_load_html(void *browser, const char *html, const char *base_url) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->LoadHTML(std::string(html), std::string(base_url));
  }
}

void yue_mbt_browser_set_user_agent(void *browser, const char *agent) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->SetUserAgent(std::string(agent));
  }
}

void yue_mbt_browser_execute_javascript(void *browser, const char *code) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->ExecuteJavaScript(std::string(code), nu::Browser::ExecutionCallback());
  }
}

/* 自定义协议：MoonBit 回调返回 [ok:i32][mime_len:i32][mime][content] 编码,ok=0 表示拒绝 */
void yue_mbt_browser_register_protocol(const char *scheme,
                                       void *(*invoke)(void *, void *), void *closure) {
  nu::Browser::RegisterProtocol(
      std::string(scheme),
      [invoke, closure](std::string url) -> nu::ProtocolJob * {
        void *bytes = invoke(closure, BytesFromString(url));
        auto *p = static_cast<const char *>(bytes);
        int32_t ok = 0;
        std::memcpy(&ok, p, 4);
        if (ok == 0) {
          return nullptr;
        }
        int32_t mime_len = 0;
        std::memcpy(&mime_len, p + 4, 4);
        std::string mime(p + 8, mime_len);
        int32_t content_len = 0;
        std::memcpy(&content_len, p + 8 + mime_len, 4);
        std::string content(p + 8 + mime_len + 4, content_len);
        return new nu::ProtocolStringJob(mime, content);
      });
}

void yue_mbt_browser_unregister_protocol(const char *scheme) {
  nu::Browser::UnregisterProtocol(std::string(scheme));
}

void *yue_mbt_browser_new_ex(int32_t devtools, int32_t context_menu,
                             int32_t allow_file_access, int32_t hardware_acceleration) {
  nu::Browser::Options options;
  options.devtools = devtools != 0;
  options.context_menu = context_menu != 0;
#if defined(OS_MAC) || defined(OS_LINUX)
  options.allow_file_access_from_files = allow_file_access != 0;
#else
  (void)allow_file_access;
#endif
#if defined(OS_LINUX)
  options.hardware_acceleration = hardware_acceleration != 0;
#else
  (void)hardware_acceleration;
#endif
  return reinterpret_cast<void *>(ViewStore::put(new nu::Browser(options)));
}

void *yue_mbt_browser_new(void) {
  nu::Browser::Options options;
  options.context_menu = true;
#if defined(WEBVIEW2_SUPPORT)
  // Windows 优先 WebView2（loader/运行时缺失时 libyue 内部自动回退 IE）
  options.webview2_support = true;
#endif
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

void *yue_mbt_menu_add_check_item(void *menu, const char *label) {
  auto *m = MenuStore::get(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(new nu::MenuItem(nu::MenuItem::Type::Checkbox));
  item->SetLabel(label);
  m->Append(item);
  return reinterpret_cast<void *>(MenuItemStore::put(item));
}

void *yue_mbt_menu_add_radio_item(void *menu, const char *label) {
  auto *m = MenuStore::get(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto item = scoped_refptr<nu::MenuItem>(new nu::MenuItem(nu::MenuItem::Type::Radio));
  item->SetLabel(label);
  m->Append(item);
  return reinterpret_cast<void *>(MenuItemStore::put(item));
}

void yue_mbt_menu_item_set_checked(void *item, int32_t checked) {
  if (auto *i = MenuItemStore::get(item)) {
    i->SetChecked(checked != 0);
  }
}

int32_t yue_mbt_menu_item_is_checked(void *item) {
  if (auto *i = MenuItemStore::get(item)) {
    return i->IsChecked() ? 1 : 0;
  }
  return 0;
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

/* MenuBase 遍历（Menu 与 MenuBar 共用基类） */
namespace {
nu::MenuBase *CastToMenuBase(void *handle) {
  if (auto *m = MenuStore::get(handle)) {
    return static_cast<nu::MenuBase *>(m);
  }
  if (auto *mb = MenuBarStore::get(handle)) {
    return static_cast<nu::MenuBase *>(mb);
  }
  return nullptr;
}
}  // namespace

int32_t yue_mbt_menu_base_item_count(void *menu) {
  if (auto *m = CastToMenuBase(menu)) {
    return m->ItemCount();
  }
  return 0;
}

void *yue_mbt_menu_base_item_at(void *menu, int32_t index) {
  if (auto *m = CastToMenuBase(menu)) {
    return reinterpret_cast<void *>(MenuItemStore::put(m->ItemAt(index)));
  }
  return nullptr;
}

// ---------- 文件对话框 ----------

void *yue_mbt_file_open_dialog_new(void) {
  return reinterpret_cast<void *>(FileDialogStore::put(new nu::FileOpenDialog()));
}

/* FileDialog::Option 位：1<<0=选文件夹 1<<1=多选 1<<2=显示隐藏 */
void yue_mbt_file_dialog_set_options(void *dialog, int32_t options) {
  if (auto *d = FileDialogStore::get(dialog)) {
    d->SetOptions(options);
  }
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
    d->SetFolder(FilePathFromUTF8(folder));
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
    return BytesFromString(FilePathValueToUTF8(d->GetResult()));
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

void *yue_mbt_attributed_text_new(const char *text, int32_t align, int32_t valign,
                                  int32_t wrap, int32_t ellipsis) {
  nu::TextFormat format;
  format.align = static_cast<nu::TextAlign>(align);
  format.valign = static_cast<nu::TextAlign>(valign);
  format.wrap = wrap != 0;
  format.ellipsis = ellipsis != 0;
  return reinterpret_cast<void *>(AttributedTextStore::put(
      new nu::AttributedText(text, format)));
}

void yue_mbt_attributed_text_set_format(void *at, int32_t align, int32_t valign,
                                        int32_t wrap, int32_t ellipsis) {
  if (auto *t = AttributedTextStore::get(at)) {
    nu::TextFormat format;
    format.align = static_cast<nu::TextAlign>(align);
    format.valign = static_cast<nu::TextAlign>(valign);
    format.wrap = wrap != 0;
    format.ellipsis = ellipsis != 0;
    t->SetFormat(format);
  }
}

void yue_mbt_attributed_text_set_font(void *at, void *font) {
  auto *t = AttributedTextStore::get(at);
  auto *f = FontStore::get(font);
  if (t != nullptr && f != nullptr) {
    t->SetFont(scoped_refptr<nu::Font>(f));
  }
}

void yue_mbt_attributed_text_set_font_for(void *at, void *font, int32_t start, int32_t end) {
  auto *t = AttributedTextStore::get(at);
  auto *f = FontStore::get(font);
  if (t != nullptr && f != nullptr) {
    t->SetFontFor(scoped_refptr<nu::Font>(f), start, end);
  }
}

void yue_mbt_attributed_text_set_color(void *at, const char *hex) {
  if (auto *t = AttributedTextStore::get(at)) {
    t->SetColor(nu::Color(std::string(hex)));
  }
}

void yue_mbt_attributed_text_set_color_for(void *at, const char *hex, int32_t start, int32_t end) {
  if (auto *t = AttributedTextStore::get(at)) {
    t->SetColorFor(nu::Color(std::string(hex)), start, end);
  }
}

void *yue_mbt_attributed_text_get_text(void *at) {
  if (auto *t = AttributedTextStore::get(at)) {
    return BytesFromString(t->GetText());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_attributed_text_set_text(void *at, const char *text) {
  if (auto *t = AttributedTextStore::get(at)) {
    t->SetText(std::string(text));
  }
}

void yue_mbt_attributed_text_clear(void *at) {
  if (auto *t = AttributedTextStore::get(at)) {
    t->Clear();
  }
}

/* Color::Name → ARGB（系统语义色，MoonBit 侧用 argb_hex 格式化） */
uint32_t yue_mbt_system_color(int32_t name) {
  static const nu::Color::Name kNames[] = {
    nu::Color::Name::Text,
    nu::Color::Name::DisabledText,
    nu::Color::Name::TextEditBackground,
    nu::Color::Name::DisabledTextEditBackground,
    nu::Color::Name::Control,
    nu::Color::Name::WindowBackground,
    nu::Color::Name::Border,
  };
  if (name < 0 || name >= static_cast<int32_t>(std::size(kNames))) {
    return 0;
  }
#if defined(OS_WIN)
  // Windows 版 libyue 的 Color::Get 无 Border 分支（内部 NOTREACHED），
  // 这里直接取窗口边框系统色
  if (kNames[name] == nu::Color::Name::Border) {
    DWORD c = ::GetSysColor(COLOR_WINDOWFRAME);
    return (0xFFu << 24) | (GetRValue(c) << 16) | (GetGValue(c) << 8) |
           GetBValue(c);
  }
#endif
  return nu::Color::Get(kNames[name]).value();
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
      ImageStore::put(new nu::Image(FilePathFromUTF8(path))));
}

/* 从内存 PNG/JPEG 解码（对照 Image(Buffer, scale_factor)） */
void *yue_mbt_image_new_from_data(const void *data, int32_t len, double scale_factor) {
  nu::Buffer buffer = nu::Buffer::Wrap(data, static_cast<size_t>(len));
  return reinterpret_cast<void *>(
      ImageStore::put(new nu::Image(buffer, static_cast<float>(scale_factor))));
}



int32_t yue_mbt_image_is_empty(void *image) {
  if (auto *i = ImageStore::get(image)) {
    return i->IsEmpty() ? 1 : 0;
  }
  return 1;
}

double yue_mbt_image_get_scale_factor(void *image) {
  if (auto *i = ImageStore::get(image)) {
    return i->GetScaleFactor();
  }
  return 1;
}

/* 返回新 Image 句柄 */
void *yue_mbt_image_resize(void *image, double w, double h, double scale_factor) {
  if (auto *i = ImageStore::get(image)) {
    return reinterpret_cast<void *>(ImageStore::put(i->Resize(
        nu::SizeF(static_cast<float>(w), static_cast<float>(h)),
        static_cast<float>(scale_factor))));
  }
  return nullptr;
}

/* format 如 "png"；路径 UTF-8 */
int32_t yue_mbt_image_write_to_file(void *image, const char *format, const char *path) {
#if defined(OS_MAC)
  // mac 发行包声明了 Image::WriteToFile 但未编译进库，降级为恒失败
  (void)image;
  (void)format;
  (void)path;
  return 0;
#else
  if (auto *i = ImageStore::get(image)) {
    return i->WriteToFile(std::string(format), FilePathFromUTF8(path)) ? 1 : 0;
  }
  return 0;
#endif
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

/* ColumnType：0=Text 1=Edit 2=Checkbox 3=Custom；column=-1 追加到模型末列 */
void yue_mbt_table_add_column_with_options(void *table, const char *title,
                                           int32_t type, int32_t column, int32_t width) {
  if (auto *t = CastTo<nu::Table>(table)) {
    nu::Table::ColumnOptions options;
    switch (type) {
      case 1:
        options.type = nu::Table::ColumnType::Edit;
        break;
      case 2:
        options.type = nu::Table::ColumnType::Checkbox;
        break;
      case 3:
        options.type = nu::Table::ColumnType::Custom;
        break;
      default:
        options.type = nu::Table::ColumnType::Text;
    }
    options.column = column;
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
/* 拖拽 FilePaths 数据构造:逐行解析并相对路径转绝对
   (Linux 端 g_filename_to_uri 不接受相对路径,且 Data(FilePaths, string)
    构造会被上游强制改写为 Text 导致拖出数据为空) */
static bool IsAbsPathForDrag(const std::string &p) {
#if defined(OS_WIN)
  return p.size() >= 2 && p[1] == ':' ||
         (!p.empty() && (p[0] == '/' || p[0] == '\\'));
#else
  return !p.empty() && p[0] == '/';
#endif
}

static std::string CurrentDirForDrag() {
#if defined(OS_WIN)
  char buf[MAX_PATH];
  DWORD n = GetCurrentDirectoryA(MAX_PATH, buf);
  return std::string(buf, n);
#elif defined(OS_LINUX)
  gchar *cwd = g_get_current_dir();
  std::string s(cwd);
  g_free(cwd);
  return s;
#else
  char buf[4096];
  return getcwd(buf, sizeof(buf)) ? std::string(buf) : std::string();
#endif
}

static std::vector<base::FilePath> MakeFilePathsForDrag(const char *paths) {
  std::vector<base::FilePath> out;
#if defined(OS_WIN)
  const char *sep = "\\";
#else
  const char *sep = "/";
#endif
  std::string cur;
  for (const char *p = paths;; ++p) {
    if (*p == '\n' || *p == '\0') {
      if (!cur.empty()) {
        if (!IsAbsPathForDrag(cur)) {
          cur = CurrentDirForDrag() + sep + cur;
        }
        // Windows 端 FilePath::StringPieceType 为宽字符,窄 string 需转宽
#if defined(OS_WIN)
        out.emplace_back(base::SysUTF8ToWide(cur));
#else
        out.emplace_back(cur);
#endif
      }
      cur.clear();
      if (*p == '\0')
        break;
    } else {
      cur += *p;
    }
  }
  return out;
}

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
      text += FilePathValueToUTF8(path);
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
  data.emplace_back(MakeFilePathsForDrag(paths));
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

double yue_mbt_view_get_bounds_in_screen_x(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBoundsInScreen().x();
  }
  return 0;
}

double yue_mbt_view_get_bounds_in_screen_y(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBoundsInScreen().y();
  }
  return 0;
}

double yue_mbt_view_get_bounds_in_screen_width(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBoundsInScreen().width();
  }
  return 0;
}

double yue_mbt_view_get_bounds_in_screen_height(void *view) {
  if (auto *v = CastToView(view)) {
    return v->GetBoundsInScreen().height();
  }
  return 0;
}

void *yue_mbt_image_from_handle(int64_t h) {
  return reinterpret_cast<void *>(h);
}

int64_t yue_mbt_image_to_handle(void *image) {
  return reinterpret_cast<int64_t>(image);
}

// ---------- 事件（Responder 信号，见 events_and_delegates 指南） ----------

// 修饰键归一化：MoonBit 层统一拿到 1=Shift 2=Ctrl 4=Alt 8=Meta。
// Linux 原始 GDK 位：SHIFT=1<<0 CONTROL=1<<2 ALT(MOD1)=1<<3 META=1<<26（libyue
// 的 KeyboardModifier::MASK_META，实为 GDK Super 位）；Mac 为 NSEventModifierFlags
// 位（Shift=1<<17 Control=1<<18 Alt=1<<19 Cmd=1<<20，未实测）；Windows 为
// libyue 的 MASK 位：SHIFT=1<<1 CONTROL=1<<2 ALT=1<<3 META=1<<4。
static int32_t NormalizeModifiers(int32_t raw) {
#if defined(OS_LINUX)
  int32_t out = 0;
  if (raw & 0x1) {
    out |= 1;
  }
  if (raw & 0x4) {
    out |= 2;
  }
  if (raw & 0x8) {
    out |= 4;
  }
  if (raw & 0x1c000000) {
    out |= 8;
  }
  return out;
#elif defined(OS_WIN)
  int32_t out = 0;
  if (raw & 0x2) {
    out |= 1;
  }
  if (raw & 0x4) {
    out |= 2;
  }
  if (raw & 0x8) {
    out |= 4;
  }
  if (raw & 0x10) {
    out |= 8;
  }
  return out;
#elif defined(OS_MAC)
  int32_t out = 0;
  if (raw & (1 << 17)) {
    out |= 1;
  }
  if (raw & (1 << 18)) {
    out |= 2;
  }
  if (raw & (1 << 19)) {
    out |= 4;
  }
  if (raw & (1 << 20)) {
    out |= 8;
  }
  return out;
#else
  return raw;
#endif
}

void yue_mbt_view_on_mouse_down(void *view,
    int32_t (*invoke)(void *, int32_t, double, double, double, double, int32_t, int32_t),
    void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_mouse_down.Connect([invoke, closure](nu::Responder *,
                                               const nu::MouseEvent &e) {
      return invoke(closure, static_cast<int32_t>(e.button),
                    e.position_in_view.x(), e.position_in_view.y(),
                    e.position_in_window.x(), e.position_in_window.y(),
                    NormalizeModifiers(e.modifiers),
                    static_cast<int32_t>(e.timestamp)) != 0;
    });
  }
}

void yue_mbt_view_on_mouse_up(void *view,
    int32_t (*invoke)(void *, int32_t, double, double, double, double, int32_t, int32_t),
    void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_mouse_up.Connect([invoke, closure](nu::Responder *,
                                             const nu::MouseEvent &e) {
      return invoke(closure, static_cast<int32_t>(e.button),
                    e.position_in_view.x(), e.position_in_view.y(),
                    e.position_in_window.x(), e.position_in_window.y(),
                    NormalizeModifiers(e.modifiers),
                    static_cast<int32_t>(e.timestamp)) != 0;
    });
  }
}

void yue_mbt_view_on_mouse_move(void *view,
    void (*invoke)(void *, int32_t, double, double, double, double, int32_t, int32_t),
    void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_mouse_move.Connect([invoke, closure](nu::Responder *,
                                               const nu::MouseEvent &e) {
      invoke(closure, static_cast<int32_t>(e.button),
             e.position_in_view.x(), e.position_in_view.y(),
             e.position_in_window.x(), e.position_in_window.y(),
             NormalizeModifiers(e.modifiers),
             static_cast<int32_t>(e.timestamp));
    });
  }
}

void yue_mbt_view_on_mouse_enter(void *view,
    void (*invoke)(void *, int32_t, double, double, double, double, int32_t, int32_t),
    void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_mouse_enter.Connect([invoke, closure](nu::Responder *,
                                               const nu::MouseEvent &e) {
      invoke(closure, static_cast<int32_t>(e.button),
             e.position_in_view.x(), e.position_in_view.y(),
             e.position_in_window.x(), e.position_in_window.y(),
             NormalizeModifiers(e.modifiers),
             static_cast<int32_t>(e.timestamp));
    });
  }
}

/* ---------- 滚轮(canvas 自绘视图的虚拟滚动用,如 table_v_t) ----------
 * libyue 无滚轮信号;Linux GTK 在控件上直连 scroll-event(容器的事件
 * 窗口经 nu_container_add_event_mask 加 GDK_SCROLL_MASK 后可收到);
 * Windows 走 ViewImpl::wheel_hook 补丁钩子(vendor 补丁让滚轮按光标命中
 * 下发,不再被外层 Scroll 直接消费)。
 * 回调带 delta_y:+1 向下滚、-1 向上滚,平滑滚轮为累计增量。
 * 返回 TRUE 消费事件,不冒泡给外层滚动容器。 */
#if defined(OS_LINUX) || defined(OS_WIN)
struct WheelCb {
  void (*invoke)(void *, double);
  void *closure;
};
#endif

#if defined(OS_LINUX)
static gboolean ViewWheelTrampoline(GtkWidget *, GdkEventScroll *event,
                                    gpointer data) {
  auto *cb = static_cast<WheelCb *>(data);
  double delta = 0;
  switch (event->direction) {
    case GDK_SCROLL_UP:
      delta = -1;
      break;
    case GDK_SCROLL_DOWN:
      delta = 1;
      break;
    case GDK_SCROLL_SMOOTH:
      delta = event->delta_y;
      break;
    default:
      return FALSE;
  }
  if (delta != 0)
    cb->invoke(cb->closure, delta);
  return TRUE;
}

// NU_CONTAINER 系宏只能在 nu 命名空间内展开(内部用非限定类型函数)
namespace nu {
inline void container_add_scroll_mask(GtkWidget *w) {
  if (NU_IS_CONTAINER(w))
    nu_container_add_event_mask(NU_CONTAINER(w),
                                GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK);
}
}  // namespace nu
#endif

void yue_mbt_view_on_wheel(void *view,
                           void (*invoke)(void *, double),
                           void *closure) {
#if defined(OS_LINUX)
  if (auto *v = CastToView(view)) {
    GtkWidget *w = v->GetNative();
    // NUContainer 系用事件窗口收事件,补 GDK_SCROLL_MASK 才有滚轮
    nu::container_add_scroll_mask(w);
    auto *cb = new WheelCb{invoke, closure};
    g_signal_connect(w, "scroll-event", G_CALLBACK(ViewWheelTrampoline), cb);
  }
#elif defined(OS_WIN)
  if (auto *v = CastToView(view)) {
    auto *impl = static_cast<nu::ViewImpl *>(v->GetNative());
    // WM_MOUSEWHEEL 原始 delta 以 WHEEL_DELTA(120)为单位,正值上滚;
    // 换算对齐 GTK 语义(+1 下滚),精密触控板为小数增量
    auto *cb = new WheelCb{invoke, closure};
    impl->wheel_hook = [cb](int raw) {
      cb->invoke(cb->closure,
                 -static_cast<double>(static_cast<int16_t>(raw)) / 120.0);
      return true;
    };
  }
#else
  (void)view;
  (void)invoke;
  (void)closure; // mac 滚轮接入待补(见 adaptation.md),先静默不挂
#endif
}

void yue_mbt_view_on_mouse_leave(void *view,
    void (*invoke)(void *, int32_t, double, double, double, double, int32_t, int32_t),
    void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_mouse_leave.Connect([invoke, closure](nu::Responder *,
                                                const nu::MouseEvent &e) {
      invoke(closure, static_cast<int32_t>(e.button),
             e.position_in_view.x(), e.position_in_view.y(),
             e.position_in_window.x(), e.position_in_window.y(),
             NormalizeModifiers(e.modifiers),
             static_cast<int32_t>(e.timestamp));
    });
  }
}

void yue_mbt_view_on_capture_lost(void *view, void (*invoke)(void *), void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_capture_lost.Connect([invoke, closure](nu::Responder *) { invoke(closure); });
  }
}

void yue_mbt_view_set_capture(void *view) {
  if (auto *v = CastToView(view)) {
    v->SetCapture();
  }
}

void yue_mbt_view_release_capture(void *view) {
  if (auto *v = CastToView(view)) {
    v->ReleaseCapture();
  }
}

int32_t yue_mbt_view_has_capture(void *view) {
  auto *v = CastToView(view);
  return v != nullptr && v->HasCapture() ? 1 : 0;
}

double yue_mbt_mouse_location_x(void) {
  return nu::Event::GetMouseLocation().x();
}

double yue_mbt_mouse_location_y(void) {
  return nu::Event::GetMouseLocation().y();
}

int32_t yue_mbt_is_shift_pressed(void) {
  return nu::Event::IsShiftPressed() ? 1 : 0;
}

int32_t yue_mbt_is_control_pressed(void) {
  return nu::Event::IsControlPressed() ? 1 : 0;
}

int32_t yue_mbt_is_alt_pressed(void) {
  return nu::Event::IsAltPressed() ? 1 : 0;
}

int32_t yue_mbt_is_meta_pressed(void) {
  return nu::Event::IsMetaPressed() ? 1 : 0;
}

void yue_mbt_view_on_size_changed(void *view, void (*invoke)(void *), void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_size_changed.Connect([invoke, closure](nu::View *) { invoke(closure); });
  }
}

void *yue_mbt_view_get_computed_layout(void *view) {
  if (auto *v = CastToView(view)) {
    return BytesFromString(v->GetComputedLayout());
  }
  return moonbit_make_bytes(0, 0);
}

double yue_mbt_view_offset_from_window_x(void *view) {
  if (auto *v = CastToView(view)) {
    return v->OffsetFromWindow().x();
  }
  return 0;
}

double yue_mbt_view_offset_from_window_y(void *view) {
  if (auto *v = CastToView(view)) {
    return v->OffsetFromWindow().y();
  }
  return 0;
}

double yue_mbt_view_offset_from_view_x(void *view, void *from) {
  auto *a = CastToView(view);
  auto *b = CastToView(from);
  if (a != nullptr && b != nullptr) {
    return a->OffsetFromView(b).x();
  }
  return 0;
}

double yue_mbt_view_offset_from_view_y(void *view, void *from) {
  auto *a = CastToView(view);
  auto *b = CastToView(from);
  if (a != nullptr && b != nullptr) {
    return a->OffsetFromView(b).y();
  }
  return 0;
}

void yue_mbt_painter_set_color(void *painter, const char *hex) {
  static_cast<nu::Painter *>(painter)->SetColor(nu::Color(std::string(hex)));
}

/* BlendMode 枚举直传（0=Normal ... 对照 painter.h） */
void yue_mbt_painter_set_blend_mode(void *painter, int32_t mode) {
  static_cast<nu::Painter *>(painter)->SetBlendMode(static_cast<nu::BlendMode>(mode));
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
#if defined(OS_LINUX) || defined(OS_WIN)
    // Linux 端 SetValue 语义为 0..100(内部再除以 100);Windows 端
    // ProgressBarImpl 不设 PBM_SETRANGE,控件默认范围即 0..100,
    // PBM_SETPOS 按其解释——两者 yue 层统一 0..1,此处换算。
    b->SetValue(static_cast<float>(value * 100.0));
#else
    b->SetValue(static_cast<float>(value));
#endif
  }
}

void yue_mbt_progress_bar_set_indeterminate(void *bar, int32_t yes) {
  if (auto *b = CastTo<nu::ProgressBar>(bar)) {
    b->SetIndeterminate(yes != 0);
  }
}

#if defined(OS_LINUX)
void *yue_mbt_popover_new(void) {
  if (IsDeepinDesktop()) {
    nu::Window::Options options;
    options.frame = false;
    options.no_activate = true;
    auto *win = new nu::Window(options);
    win->SetSkipTaskbar(true);
    win->SetResizable(false);
    win->on_mouse_up.Connect([win](nu::Responder *, const nu::MouseEvent &) {
      win->Close();
      return true;
    });
    return reinterpret_cast<void *>(PopoverWindowStore::put(win));
  }
  return reinterpret_cast<void *>(PopoverStore::put(new nu::Popover()));
}
#elif defined(OS_MAC)
// macOS 桩：无边框小窗口（Options 无 no_activate 字段）
void *yue_mbt_popover_new(void) {
  nu::Window::Options options;
  options.frame = false;  // 无边框
  return reinterpret_cast<void *>(PopoverStore::put(new nu::Window(options)));
}
#else
// Windows 桩：无边框、不激活的小窗口 + 8 秒自动关闭
// 替代窗口存储：展示中的气泡（供自动关闭定时器使用）
nu::Window *g_active_popover_window = nullptr;
// 固定定时器 id：重复 show 时重置同一计时
constexpr UINT_PTR kPopoverAutoCloseTimerId = 0x705D;

void CALLBACK PopoverAutoCloseTimer(HWND, UINT, UINT_PTR id, DWORD) {
  ::KillTimer(nullptr, id);
  std::fprintf(stderr, "popover: autoclose\n");
  if (g_active_popover_window != nullptr &&
      g_active_popover_window->IsVisible()) {
    // 隐藏而非 Close:弹层窗口需复用(文本再变时重新 show),
    // Close 在 Windows 是销毁窗口,销毁后句柄失效弹层再也弹不出
    g_active_popover_window->SetVisible(false);
  }
  g_active_popover_window = nullptr;
}

void *yue_mbt_popover_new(void) {
  nu::Window::Options options;
  options.frame = false;       // 无边框
  options.no_activate = true;  // 弹出不抢焦点
  auto *win = new nu::Window(options);
  // 点击弹层本身也不得激活弹窗:一旦激活成为前台窗口,锚点控件
  // 收到失焦,组件按失焦收起弹层,点击候选项落空
  if (HWND hwnd = win->GetNative()->hwnd()) {
    LONG_PTR ex = ::GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    ::SetWindowLongPtrW(hwnd, GWL_EXSTYLE, ex | WS_EX_NOACTIVATE);
  }
  return reinterpret_cast<void *>(PopoverStore::put(win));
}
#endif

/* 标记弹层放弃键盘焦点(仅 Linux 有实现,其余平台空操作):select_t
 * 可过滤下拉需要弹层展开期间键盘事件持续进入锚点 Entry,而 GTK 弹层
 * 窗口映射/点击时窗口管理器可能把 X 焦点交给它(实测 XFCE 会,即使
 * ShowRelativeTo 已不 Activate)。标记的弹层在 show 时给顶层 GtkWindow
 * 补 accept_focus=false + focus_on_map=false,出现与点击均不动焦点。 */
#if defined(OS_LINUX)
std::set<void *> g_popover_no_focus;
#endif

void yue_mbt_popover_set_accept_focus(void *popover, int32_t accept) {
#if defined(OS_LINUX)
  if (accept == 0) {
    g_popover_no_focus.insert(popover);
  } else {
    g_popover_no_focus.erase(popover);
  }
#endif
}

/* 延迟回调(仅 Linux 有实现,其余平台空操作):挂到 GDK 主循环的下一拍,
 * 当前这批输入事件(含待决的鼠标 release)处理完之后才执行。供「焦点
 * 事件里不能立刻开弹层」的组件(select_t 可过滤下拉)推迟弹出动作。 */
void yue_mbt_call_delayed(int32_t ms, void (*invoke)(void *), void *closure) {
#if defined(OS_LINUX)
  struct DelayedCtx {
    void (*invoke)(void *);
    void *closure;
  };
  auto *ctx = new DelayedCtx{invoke, closure};
  g_timeout_add(
      ms,
      [](gpointer data) -> int {
        auto *c = static_cast<DelayedCtx *>(data);
        c->invoke(c->closure);
        delete c;
        return FALSE;
      },
      ctx);
#endif
}

#if defined(OS_LINUX)
void yue_mbt_popover_set_content(void *popover, void *content) {
  auto *c = CastToView(content);
  if (c == nullptr) {
    return;
  }
  if (IsDeepinDesktop()) {
    if (auto *win = PopoverWindowStore::get(popover)) {
      win->SetContentView(scoped_refptr<nu::View>(c));
    }
    return;
  }
  if (auto *p = PopoverStore::get(popover)) {
    p->SetContentView(scoped_refptr<nu::View>(c));
  }
}
#else
void yue_mbt_popover_set_content(void *popover, void *content) {
  auto *w = PopoverStore::get(popover);
  auto *c = CastToView(content);
  if (w != nullptr && c != nullptr) {
    w->SetContentView(scoped_refptr<nu::View>(c));
  }
}
#endif

#if defined(OS_LINUX)
void yue_mbt_popover_set_content_size(void *popover, double w, double h) {
  if (IsDeepinDesktop()) {
    if (auto *win = PopoverWindowStore::get(popover)) {
      win->SetContentSize(
          nu::SizeF(static_cast<float>(w), static_cast<float>(h)));
    }
    return;
  }
  if (auto *p = PopoverStore::get(popover)) {
    p->SetContentSize(
        nu::SizeF(static_cast<float>(w), static_cast<float>(h)));
  }
}
#else
void yue_mbt_popover_set_content_size(void *popover, double w, double h) {
  if (auto *win = PopoverStore::get(popover)) {
    win->SetContentSize(
        nu::SizeF(static_cast<float>(w), static_cast<float>(h)));
  }
}
#endif

#if defined(OS_LINUX)
void yue_mbt_popover_show_relative_to(void *popover, void *view) {
  auto *v = CastToView(view);
  if (v == nullptr) {
    return;
  }
  if (IsDeepinDesktop()) {
    auto *win = PopoverWindowStore::get(popover);
    if (win == nullptr) {
      return;
    }
    // 锚定控件屏幕包围盒正下方居中;不做指针抓取(DDE 下会拖慢全局鼠标)
    const nu::RectF anchor = v->GetBoundsInScreen();
    const nu::SizeF size = win->GetContentSize();
    const float x = anchor.x() + (anchor.width() - size.width()) / 2.0f;
    const float y = anchor.bottom() + 2.0f;
    win->SetBounds(nu::RectF(x, y, size.width(), size.height()));
    win->SetVisible(true);
    return;
  }
  auto *p = PopoverStore::get(popover);
  if (p != nullptr && v != nullptr) {
    // 弃焦弹层:从内容视图上溯顶层 GtkWindow,关掉接受焦点与映射取焦。
    // 必须在映射前设置(focus_on_map 只对首次映射生效),故放 show 前;
    // 内容未挂时拿不到顶层,静默跳过(与未标记弹层同行为)。
    if (g_popover_no_focus.count(popover) > 0) {
      if (auto *c = p->GetContentView()) {
        GtkWidget *top = gtk_widget_get_toplevel(GTK_WIDGET(c->GetNative()));
        if (GTK_IS_WINDOW(top)) {
          gtk_window_set_accept_focus(GTK_WINDOW(top), FALSE);
          gtk_window_set_focus_on_map(GTK_WINDOW(top), FALSE);
        }
      }
    }
    p->ShowRelativeTo(v);
  }
}
#elif defined(OS_MAC)
// macOS 桩：锚定控件屏幕坐标的右下方弹窗（无 Win32 定时器，不自动关闭）
void yue_mbt_popover_show_relative_to(void *popover, void *view) {
  auto *win = PopoverStore::get(popover);
  auto *v = CastToView(view);
  if (win == nullptr || v == nullptr) {
    return;
  }
  const nu::RectF anchor = v->GetBoundsInScreen();
  const nu::SizeF size = win->GetContentSize();
  const float x = anchor.right() + 8.0f;
  float y = anchor.bottom() + 8.0f;
  // 所在显示器工作区放不下时翻到锚点上方(与 fork 翻转补丁对齐)
  nu::Display display =
      nu::Screen::GetCurrent()->GetDisplayNearestPoint(anchor.origin());
  if (y + size.height() > display.work_area.bottom()) {
    y = anchor.y() - size.height() - 8.0f;
  }
  win->SetBounds(nu::RectF(x, y, size.width(), size.height()));
}
#else
void yue_mbt_popover_show_relative_to(void *popover, void *view) {
  auto *win = PopoverStore::get(popover);
  auto *v = CastToView(view);
  if (win == nullptr || v == nullptr) {
    return;
  }
  // 锚点坐标:原生子控件(Entry=EDIT)直接取 GetWindowRect——
  // View::GetBoundsInScreen 在嵌套滚动容器下累加出巨幅偏移(Win10 真机
  // 实测 x=-5.9 亿,弹层被定位到屏幕外不显示),不可信;取不到 HWND 再
  // 回退。坐标系与下方 SetWindowPos 一致按物理像素。
  nu::RectF anchor;
  bool anchored = false;
  if (auto *subwin = dynamic_cast<nu::SubwinView *>(v->GetNative())) {
    HWND anchor_hwnd = subwin->hwnd();
    RECT r;
    if (anchor_hwnd != nullptr && ::GetWindowRect(anchor_hwnd, &r)) {
      anchor = nu::RectF(static_cast<float>(r.left),
                         static_cast<float>(r.top),
                         static_cast<float>(r.right - r.left),
                         static_cast<float>(r.bottom - r.top));
      anchored = true;
    }
  }
  if (!anchored) {
    anchor = v->GetBoundsInScreen();
  }
  const nu::SizeF size = win->GetContentSize();
  const float x = anchor.x() + (anchor.width() - size.width()) / 2.0f;
  float y = anchor.bottom() + 2.0f;
  // 锚点所在显示器的工作区放不下时翻转到锚点上方(与 fork 的
  // Popover::ShowRelativeTo 翻转补丁对齐),贴屏底的取色器/下拉保持可见
  {
    POINT apt = {static_cast<LONG>(anchor.x() + anchor.width() / 2.0f),
                 static_cast<LONG>(anchor.y())};
    HMONITOR mon = ::MonitorFromPoint(apt, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi;
    mi.cbSize = sizeof(mi);
    if (mon != nullptr && ::GetMonitorInfoW(mon, &mi) &&
        y + size.height() > static_cast<float>(mi.rcWork.bottom)) {
      y = anchor.y() - size.height() - 2.0f;
    }
  }
  // libyue 的 SetVisible 在此场景观测为不可见(Win10 真机 visible=0),
  // 直接走 Win32:带尺寸定位 + SW_SHOWNOACTIVATE(不抢输入框焦点)
  win->SetVisible(true);
  HWND popup_hwnd = win->GetNative()->hwnd();
  std::fprintf(stderr, "popover: show at (%.0f,%.0f) size (%.0fx%.0f) hwnd=%p\n",
               x, y, size.width(), size.height(), static_cast<void *>(popup_hwnd));
  if (popup_hwnd != nullptr) {
    ::SetWindowPos(popup_hwnd, HWND_TOPMOST, static_cast<int>(x),
                   static_cast<int>(y), static_cast<int>(size.width()),
                   static_cast<int>(size.height()), SWP_NOACTIVATE);
    ::ShowWindow(popup_hwnd, SW_SHOWNOACTIVATE);
    RECT after;
    if (::GetWindowRect(popup_hwnd, &after)) {
      std::fprintf(stderr,
                   "popover: after rect=(%ld,%ld,%ld,%ld) visible=%d\n",
                   after.left, after.top, after.right, after.bottom,
                   ::IsWindowVisible(popup_hwnd) ? 1 : 0);
    }
  }
  // 8 秒后自动关闭（无外部点击关闭钩子，定时兜底）；固定 id，
  // 每次 show 重置同一计时，避免旧计时器在输入中途误关弹层
  g_active_popover_window = win;
  ::SetTimer(nullptr, kPopoverAutoCloseTimerId, 8000, PopoverAutoCloseTimer);
}
#endif

#if defined(OS_LINUX)
void yue_mbt_popover_close(void *popover) {
  if (IsDeepinDesktop()) {
    if (auto *win = PopoverWindowStore::get(popover)) {
      win->Close();
    }
    return;
  }
  if (auto *p = PopoverStore::get(popover)) {
    p->Close();
  }
}
#else
void yue_mbt_popover_close(void *popover) {
  if (auto *win = PopoverStore::get(popover)) {
    // 隐藏而非 Close:Close 在 Windows 是销毁窗口,弹层实例需复用同一
    // 实例(文本变化重新 show),销毁后句柄失效弹层再也弹不出;
    // on_close 语义照 GTK 版 Close 手动补发
    win->SetVisible(false);
    win->on_close.Emit(win);
  }
}
#endif

#if defined(OS_LINUX)
void yue_mbt_popover_on_close(void *popover, void (*invoke)(void *), void *closure) {
  if (IsDeepinDesktop()) {
    if (auto *win = PopoverWindowStore::get(popover)) {
      win->on_close.Connect([invoke, closure](nu::Window *) { invoke(closure); });
    }
    return;
  }
  if (auto *p = PopoverStore::get(popover)) {
    p->on_close.Connect([invoke, closure](nu::Popover *) { invoke(closure); });
  }
}
#else
void yue_mbt_popover_on_close(void *popover, void (*invoke)(void *), void *closure) {
  if (auto *win = PopoverStore::get(popover)) {
    win->on_close.Connect([invoke, closure](nu::Window *) { invoke(closure); });
  }
}
#endif


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

/* ScrollbarPolicy：0=Always 1=Never 2=Automatic */
void yue_mbt_scroll_set_scrollbar_policy(void *scroll, int32_t h, int32_t v) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    s->SetScrollbarPolicy(static_cast<nu::Scroll::Policy>(h),
                          static_cast<nu::Scroll::Policy>(v));
  }
}

int32_t yue_mbt_scroll_get_scrollbar_policy_x(void *scroll) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    return static_cast<int32_t>(std::get<0>(s->GetScrollbarPolicy()));
  }
  return 2;
}

int32_t yue_mbt_scroll_get_scrollbar_policy_y(void *scroll) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    return static_cast<int32_t>(std::get<1>(s->GetScrollbarPolicy()));
  }
  return 2;
}

void yue_mbt_scroll_set_overlay_scrollbar(void *scroll, int32_t yes) {
#if !defined(OS_WIN)
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    s->SetOverlayScrollbar(yes != 0);
  }
#else
  (void)scroll; // Windows 滚动条策略由系统决定，无 overlay 概念
  (void)yes;
#endif
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

/* Clipboard::Type：0=CopyPaste 1=Selection(Linux)。返回进程级单例裸指针 */
void *yue_mbt_clipboard_from_type(int32_t type) {
#if defined(OS_LINUX)
  return static_cast<void *>(nu::Clipboard::FromType(
      type == 1 ? nu::Clipboard::Type::Selection : nu::Clipboard::Type::CopyPaste));
#else
  (void)type; // Windows/macOS 无 Selection 剪贴板
  return static_cast<void *>(
      nu::Clipboard::FromType(nu::Clipboard::Type::CopyPaste));
#endif
}

/* 写入单条数据：kind 1=Text 2=HTML 4=FilePaths(路径 \n 连接) */
void yue_mbt_clipboard_set_data(void *clipboard, int32_t kind, const char *text) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    std::vector<nu::Clipboard::Data> datas;
    datas.push_back(nu::Clipboard::Data(ToDataType(kind), std::string(text)));
    c->SetData(std::move(datas));
  }
}

void yue_mbt_clipboard_set_data_image(void *clipboard, void *image) {
  auto *img = ImageStore::get(image);
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    if (img != nullptr) {
      std::vector<nu::Clipboard::Data> datas;
      datas.push_back(nu::Clipboard::Data(scoped_refptr<nu::Image>(img)));
      c->SetData(std::move(datas));
    }
  }
}

/* 读单条数据：与 dragging_get_data 相同的 [kind:i32][payload] 编码 */
void *yue_mbt_clipboard_get_data(void *clipboard, int32_t kind) {
  auto *c = static_cast<nu::Clipboard *>(clipboard);
  if (c == nullptr) {
    return moonbit_make_bytes(0, 0);
  }
  nu::Clipboard::Data data = c->GetData(ToDataType(kind));
  if (kind == 3) {
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
      text += FilePathValueToUTF8(path);
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

// ---------- MessageLoop（定时器/任务，跨平台） ----------

void yue_mbt_post_task(void (*invoke)(void *), void *closure) {
  nu::MessageLoop::PostTask([invoke, closure]() { invoke(closure); });
}

void yue_mbt_post_delayed_task(int32_t ms, void (*invoke)(void *), void *closure) {
  nu::MessageLoop::PostDelayedTask(ms, [invoke, closure]() { invoke(closure); });
}

uint32_t yue_mbt_set_timeout(int32_t ms, void (*invoke)(void *), void *closure) {
  return nu::MessageLoop::SetTimeout(ms, [invoke, closure]() { invoke(closure); });
}

/* 周期任务：返回 true 继续下一次触发，false 停止（libyue SetTimer 无 id） */
void yue_mbt_set_timer(int32_t ms, int32_t (*invoke)(void *), void *closure) {
  nu::MessageLoop::SetTimer(ms, [invoke, closure]() -> bool {
    return invoke(closure) != 0;
  });
}

void yue_mbt_clear_timeout(uint32_t id) {
  nu::MessageLoop::ClearTimeout(id);
}

// ---------- 消息框 ----------

void *yue_mbt_message_box_new(int32_t type) {
  auto *box = new nu::MessageBox();
  box->SetType(static_cast<nu::MessageBox::Type>(type));
  return reinterpret_cast<void *>(MessageBoxStore::put(box));
}

void yue_mbt_message_box_set_title(void *box, const char *title) {
#if defined(OS_MAC)
  // mac 的 MessageBox 无 SetTitle（仅 Linux/Win 提供），忽略
  (void)box;
  (void)title;
#else
  if (auto *m = MessageBoxStore::get(box)) {
    m->SetTitle(title);
  }
#endif
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
#if defined(OS_MAC)
  // mac 无异步 Show()，用模态 Run() 替代（阻塞至关闭，on_response 照常回调）
  if (auto *m = MessageBoxStore::get(box)) {
    m->Run();
  }
#else
  if (auto *m = MessageBoxStore::get(box)) {
    m->Show();
  }
#endif
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

/* 设置通知按钮：flat_bytes 协议 [count:i32le]（[len:i32le title][len:i32le info]）*
 */
void yue_mbt_notification_set_actions(void *notification, void *flat_bytes) {
  auto *n = NotificationStore::get(notification);
  if (n == nullptr) {
    return;
  }
  const char *p = static_cast<const char *>(flat_bytes);
  int32_t count = 0;
  std::memcpy(&count, p, 4);
  p += 4;
  std::vector<nu::Notification::Action> actions;
  for (int32_t i = 0; i < count; i++) {
    int32_t title_len = 0;
    std::memcpy(&title_len, p, 4);
    p += 4;
    std::string title(p, title_len);
    p += title_len;
    int32_t info_len = 0;
    std::memcpy(&info_len, p, 4);
    p += 4;
    std::string info(p, info_len);
    p += info_len;
    actions.push_back(nu::Notification::Action{title, info});
  }
  n->SetActions(actions);
}

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

#if defined(OS_WIN)
// WinRT toast 的 notifier 按 AUMID 查找：进程级设置 AUMID 并在
// HKCU\Software\Classes\AppUserModelId\<AUMID> 写 DisplayName
// （仅显示通知无需 COM 激活注册；缺这一步 Show() 会静默失败）。
static void EnsureToastAumid() {
  static bool done = false;
  if (done) {
    return;
  }
  done = true;
  wchar_t exe_path[MAX_PATH] = L"";
  UINT n = ::GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (n == 0 || n >= MAX_PATH) {
    return;
  }
  std::wstring base(exe_path);
  size_t slash = base.find_last_of(L"\\/");
  base = (slash == std::wstring::npos) ? base : base.substr(slash + 1);
  if (base.size() > 4 && base.compare(base.size() - 4, 4, L".exe") == 0) {
    base.resize(base.size() - 4);
  }
  std::wstring aumid = L"moonbit.libyue." + base;
  if (FAILED(::SetCurrentProcessExplicitAppUserModelID(aumid.c_str()))) {
    return;
  }
  std::wstring key = L"SOFTWARE\\Classes\\AppUserModelId\\" + aumid;
  HKEY handle = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, key.c_str(), 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &handle,
                        nullptr) == ERROR_SUCCESS) {
    std::wstring display = base + L" (moonbit-libyue)";
    ::RegSetValueExW(handle, L"DisplayName", 0, REG_SZ,
                     reinterpret_cast<const BYTE *>(display.data()),
                     static_cast<DWORD>((display.size() + 1) * sizeof(wchar_t)));
    ::RegCloseKey(handle);
  }
}
#endif

void yue_mbt_notification_show(void *n) {
  if (auto *b = NotificationStore::get(n)) {
#if defined(OS_WIN)
    EnsureToastAumid();
#endif
    b->Show();
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

/* DatePicker::Options：elements 位组合（0xC0=年月 0xE0=年月日 0x0C=时分 0x0E=时分秒） */
void *yue_mbt_date_picker_new_ex(int32_t elements, int32_t has_stepper) {
  nu::DatePicker::Options options;
  options.elements = elements;
  options.has_stepper = has_stepper != 0;
  return reinterpret_cast<void *>(ViewStore::put(new nu::DatePicker(options)));
}

void *yue_mbt_date_picker_new(void) {
  nu::DatePicker::Options options;
  return reinterpret_cast<void *>(ViewStore::put(new nu::DatePicker(options)));
}

void *yue_mbt_gif_player_new(void) {
  return reinterpret_cast<void *>(ViewStore::put(new nu::GifPlayer()));
}

/* ImageScale：0=None 1=Fill 2=Down 3=UpOrDown */
void yue_mbt_gif_player_set_scale(void *player, int32_t scale) {
  if (auto *p = CastTo<nu::GifPlayer>(player)) {
    p->SetScale(static_cast<nu::ImageScale>(scale));
  }
}

int32_t yue_mbt_gif_player_get_scale(void *player) {
  if (auto *p = CastTo<nu::GifPlayer>(player)) {
    return static_cast<int32_t>(p->GetScale());
  }
  return 0;
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

/* 本地时区的今天,打包 Int64:y*10000+m*100+d(日历组件"今天"高亮用) */
int64_t yue_mbt_local_date(void) {
  std::time_t t = std::time(nullptr);
  std::tm lt{};
#if defined(_WIN32)
  localtime_s(&lt, &t);
#else
  localtime_r(&t, &lt);
#endif
  return static_cast<int64_t>(lt.tm_year + 1900) * 10000 +
         static_cast<int64_t>(lt.tm_mon + 1) * 100 + lt.tm_mday;
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
                              int32_t (*invoke)(void *, int32_t, int32_t, int32_t),
                              void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_key_down.Connect([invoke, closure](nu::Responder *, const nu::KeyEvent &event) {
      return invoke(closure, static_cast<int32_t>(event.key),
                    NormalizeModifiers(event.modifiers),
                    static_cast<int32_t>(event.timestamp)) != 0;
    });
  }
}

void yue_mbt_view_on_key_up(void *view,
                            int32_t (*invoke)(void *, int32_t, int32_t, int32_t),
                            void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_key_up.Connect([invoke, closure](nu::Responder *, const nu::KeyEvent &event) {
      return invoke(closure, static_cast<int32_t>(event.key),
                    NormalizeModifiers(event.modifiers),
                    static_cast<int32_t>(event.timestamp)) != 0;
    });
  }
}

void yue_mbt_window_set_has_shadow(void *window, int32_t has) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetHasShadow(has != 0);
  }
}

int32_t yue_mbt_window_has_shadow(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->HasShadow() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_window_set_resizable(void *window, int32_t yes) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetResizable(yes != 0);
  }
}

int32_t yue_mbt_window_is_resizable(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->IsResizable() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_window_set_maximizable(void *window, int32_t yes) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetMaximizable(yes != 0);
  }
}

void yue_mbt_window_set_minimizable(void *window, int32_t yes) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetMinimizable(yes != 0);
  }
}

int32_t yue_mbt_window_is_maximized(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->IsMaximized() ? 1 : 0;
  }
  return 0;
}

/* should_close 委托：返回 false 阻止关闭 */
void yue_mbt_window_set_should_close(void *window,
                                     int32_t (*invoke)(void *), void *closure) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->should_close = [invoke, closure](nu::Window *) {
      return invoke(closure) != 0;
    };
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

#if defined(OS_WIN)
// ---------- 托盘幽灵图标防护 ----------
// TrayStore 全局持有 nu::Tray 引用，异常退出（崩溃/abort/关控制台）不走
// CRT 静态析构链。首次创建托盘时捕获 TrayHost 属主窗口并安装进程级钩子，
// 凡还有机会执行代码的退出路径都按属主窗口 + ID 区间补发 NIM_DELETE
// （图标 ID 从 2 起连续分配、只增不复用，对已删除 ID 是无害空操作）；
// 硬杀（TerminateProcess/taskkill /F）无法在进程侧根除，由系统惰性清理。
// 原理见 docs/adaptation.md「运行期差异」。
struct TrayGhostGuard {
  HWND host_hwnd = nullptr;  // TrayHost 窗口,创建首个托盘时捕获
  UINT max_icon_id = 1;      // 已分配的最大图标 ID(初始 1 = 尚未分配过)
  LPTOP_LEVEL_EXCEPTION_FILTER prev_seh_filter = nullptr;
  bool hooks_installed = false;

  static TrayGhostGuard &get() {
    static TrayGhostGuard guard;
    return guard;
  }

  void register_tray(HWND hwnd) {
    if (hwnd != nullptr) {
      host_hwnd = hwnd;
    }
    ++max_icon_id;
    install_hooks();
  }

  void sweep() {
    if (host_hwnd == nullptr) {
      return;
    }
    for (UINT id = 2; id <= max_icon_id; ++id) {
      NOTIFYICONDATAW data;
      memset(&data, 0, sizeof(data));
      data.cbSize = sizeof(data);
      data.hWnd = host_hwnd;
      data.uID = id;
      ::Shell_NotifyIconW(NIM_DELETE, &data);
    }
  }

  static void sweep_at_exit() { get().sweep(); }

  static void on_sigabrt(int) {
    get().sweep();  // libyue CHECK 失败走 abort;扫完让默认终止流程继续
  }

  static BOOL WINAPI on_console_ctrl(DWORD event) {
    (void)event;  // Ctrl+C / Ctrl+Break / 关闭控制台 / 注销一律先扫再放行
    get().sweep();
    return FALSE;  // 交回默认处理,进程退出语义不变
  }

  static LONG WINAPI on_seh(EXCEPTION_POINTERS *info) {
    get().sweep();
    // 不吞崩溃:清扫后交还前一过滤器/默认处理
    return TrayGhostGuard::get().prev_seh_filter != nullptr
               ? TrayGhostGuard::get().prev_seh_filter(info)
               : EXCEPTION_CONTINUE_SEARCH;
  }

  void install_hooks() {
    if (hooks_installed) {
      return;
    }
    hooks_installed = true;
    std::atexit(&sweep_at_exit);
    std::signal(SIGABRT, &on_sigabrt);
    ::SetConsoleCtrlHandler(&on_console_ctrl, TRUE);
    prev_seh_filter = ::SetUnhandledExceptionFilter(&on_seh);
  }
};
#endif  // OS_WIN

void *yue_mbt_tray_new(const char *icon_path, int32_t *ok) {
  *ok = 0;
  if (!yue_mbt_tray_supported()) {
    return nullptr;
  }
  auto image = scoped_refptr<nu::Image>(new nu::Image(FilePathFromUTF8(icon_path)));
  if (image->IsEmpty()) {
    return nullptr;
  }
#if defined(OS_WIN)
  // 捕获 TrayHost 窗口,供异常退出时补发 NIM_DELETE(见 TrayGhostGuard)
  nu::TrayHost *tray_host = g_state != nullptr ? g_state->GetTrayHost() : nullptr;
  HWND tray_host_hwnd = tray_host != nullptr ? tray_host->hwnd() : nullptr;
#endif
  auto tray = scoped_refptr<nu::Tray>(new nu::Tray(image));
#if defined(OS_WIN)
  TrayGhostGuard::get().register_tray(tray_host_hwnd);
#endif
  *ok = 1;
  return reinterpret_cast<void *>(TrayStore::put(tray));
}

void yue_mbt_tray_set_title(void *tray, const char *title) {
#if defined(OS_MAC) || defined(OS_LINUX)
  // 构造失败（后端缺失）时 nativeui 内部句柄为空，防御性跳过而非崩溃
  auto *t = TrayStore::get(tray);
  if (t != nullptr) {
    t->SetTitle(title);
  }
#else
  (void)tray; // Windows 托盘无标题概念（原生不支持）
  (void)title;
#endif
}

void yue_mbt_tray_remove(void *tray) {
  auto *t = TrayStore::get(tray);
  if (t != nullptr) {
    t->Remove();
  }
}

// ---------- 托盘：nativeui 后端补充 ----------

// ---------- 菜单桥：供 SNI 自实现托盘遍历统一 Menu 模型 ----------

extern "C" void *yue_mbt_menu_new(void) {
  return reinterpret_cast<void *>(MenuStore::put(new nu::Menu()));
}

extern "C" int32_t yue_mbt_menu_item_count(void *menu) {
  auto *m = MenuStore::get(menu);
  return m != nullptr ? m->ItemCount() : 0;
}

// ItemAt 返回裸指针，登记进注册表；ok=0 表示越界
extern "C" void *yue_mbt_menu_item_at(void *menu, int32_t index, int32_t *ok) {
  *ok = 0;
  auto *m = MenuStore::get(menu);
  if (m == nullptr) {
    return nullptr;
  }
  auto *item = m->ItemAt(index);
  if (item == nullptr) {
    return nullptr;
  }
  *ok = 1;
  return reinterpret_cast<void *>(
      MenuItemStore::put(scoped_refptr<nu::MenuItem>(item)));
}

extern "C" int32_t yue_mbt_menu_item_get_label(void *item, char *out, int32_t len) {
  auto *i = MenuItemStore::get(item);
  if (i == nullptr) {
    return -1;
  }
  std::string label = i->GetLabel();
  int32_t n = static_cast<int32_t>(label.size());
  if (n >= len) {
    return -2;
  }
  memcpy(out, label.c_str(), n + 1);
  return n;
}

// nu::MenuItem::Type：0 Label, 1 Checkbox, 2 Radio, 3 Separator, 4 Submenu
extern "C" int32_t yue_mbt_menu_item_get_type(void *item) {
  auto *i = MenuItemStore::get(item);
  return i != nullptr ? static_cast<int32_t>(i->GetType()) : -1;
}

extern "C" int32_t yue_mbt_menu_item_is_enabled(void *item) {
  auto *i = MenuItemStore::get(item);
  return i != nullptr && i->IsEnabled() ? 1 : 0;
}

// 触发菜单项：原生信号 → 已注册的 MoonBit 回调
extern "C" void yue_mbt_menu_item_click(void *item) {
  auto *i = MenuItemStore::get(item);
  if (i != nullptr) {
    i->Click();
  }
}

void yue_mbt_tray_set_image(void *tray, void *image) {
  auto *t = TrayStore::get(tray);
  auto *img = ImageStore::get(image);
  if (t != nullptr && img != nullptr) {
    t->SetImage(scoped_refptr<nu::Image>(img));
  }
}

// 在屏幕坐标处弹出菜单（Qt 模式：ContextMenu 调用后由应用自绘菜单）
extern "C" void yue_mbt_menu_popup_at(void *menu, double x, double y) {
  auto *m = MenuStore::get(menu);
  if (m != nullptr) {
    m->PopupAt(nu::PointF(x, y));
  }
}

extern "C" void yue_mbt_tray_set_menu(void *tray, void *menu) {
  auto *t = TrayStore::get(tray);
  auto *m = MenuStore::get(menu);
  if (t != nullptr && m != nullptr) {
    t->SetMenu(scoped_refptr<nu::Menu>(m));
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

extern "C" int32_t yue_mbt_sys_getuid(void) { return -1; }

extern "C" int32_t yue_mbt_sys_getenv(const char *, char *, int32_t) { return -1; }

extern "C" int32_t yue_mbt_sys_unix_connect(const char *) { return -1; }

extern "C" int32_t yue_mbt_sys_read(int32_t, uint8_t *, int32_t, int32_t) { return -2; }

extern "C" int32_t yue_mbt_sys_write(int32_t, const uint8_t *, int32_t, int32_t) {
  return -2;
}

extern "C" int32_t yue_mbt_sys_poll(int32_t, int32_t, int32_t) { return -1; }

extern "C" void yue_mbt_sys_close(int32_t) {}

extern "C" int32_t yue_mbt_sys_watch_fd(int32_t, int32_t,
                                        int32_t (*)(int32_t, int32_t)) {
  return 0;
}

#endif  // sys_* 平台分支结束;以下为全平台通用函数

// 本段函数统一包进 extern "C":MoonBit ffi 按 C 名字解析符号,
// 缺 extern "C" 会被 C++ name mangling 改名导致链接期 undefined reference。
extern "C" {

/* ---------------- 方法级审计补齐(2026-09-16) ---------------- */

/* Window */
void yue_mbt_window_close(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->Close();
  }
}

void yue_mbt_window_minimize(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->Minimize();
  }
}

void yue_mbt_window_restore(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->Restore();
  }
}

int32_t yue_mbt_window_is_minimized(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->IsMinimized() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_window_set_content_size_constraints(void *window, double min_w,
                                                 double min_h, double max_w,
                                                 double max_h) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetContentSizeConstraints(nu::SizeF(min_w, min_h),
                                 nu::SizeF(max_w, max_h));
  }
}

void yue_mbt_window_set_movable(void *window, int32_t movable) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetMovable(movable != 0);
  }
}

void *yue_mbt_window_get_title(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return BytesFromString(w->GetTitle());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_window_set_background_color(void *window, const char *hex) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetBackgroundColor(nu::Color(std::string(hex)));
  }
}

double yue_mbt_window_get_scale_factor(void *window) {
  if (auto *w = CastTo<nu::Window>(window)) {
    return w->GetScaleFactor();
  }
  return 1.0;
}

void yue_mbt_window_set_skip_taskbar(void *window, int32_t skip) {
#if defined(OS_WIN) || defined(OS_LINUX)
  if (auto *w = CastTo<nu::Window>(window)) {
    w->SetSkipTaskbar(skip != 0);
  }
#else
  (void)window;
  (void)skip;
#endif
}

void yue_mbt_window_set_icon(void *window, void *image) {
#if defined(OS_WIN) || defined(OS_LINUX)
  auto *img = ImageStore::get(image);
  if (auto *w = CastTo<nu::Window>(window)) {
    if (img != nullptr) {
      w->SetIcon(scoped_refptr<nu::Image>(img));
    }
  }
#else
  // mac 的 Window 无 SetIcon(窗口图标随 Bundle 走)
  (void)window;
  (void)image;
#endif
}

void yue_mbt_window_on_focus_in(void *window,
                                int32_t (*invoke)(void *), void *closure) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->on_focus.Connect(
        [invoke, closure](nu::Window *) { return invoke(closure) != 0; });
  }
}

void yue_mbt_window_on_blur(void *window,
                            int32_t (*invoke)(void *), void *closure) {
  if (auto *w = CastTo<nu::Window>(window)) {
    w->on_blur.Connect(
        [invoke, closure](nu::Window *) { return invoke(closure) != 0; });
  }
}

/* View:tooltip / focus */
void yue_mbt_view_set_tooltip(void *view, const char *text) {
  if (auto *v = CastToView(view)) {
    v->SetTooltip(text);
  }
}

/* 系统深色偏好检测(仅 Linux):读 GtkSettings 的
 * gtk-application-prefer-dark-theme,再按主题名含 dark 兜底判定
 * (部分主题只改名字不改该属性)。其余平台当前恒 false,联动接入待补。 */
bool yue_mbt_system_prefers_dark(void) {
#if defined(OS_LINUX)
  GtkSettings *settings = gtk_settings_get_default();
  if (settings != nullptr) {
    gboolean prefer_dark = FALSE;
    g_object_get(settings, "gtk-application-prefer-dark-theme", &prefer_dark,
                 nullptr);
    if (prefer_dark) {
      return true;
    }
    gchar *theme_name = nullptr;
    g_object_get(settings, "gtk-theme-name", &theme_name, nullptr);
    if (theme_name != nullptr) {
      // 主题名大小写不定(Greybird-dark / Adwaita-dark / OrchisDark),
      // 统一小写后按子串判定
      gchar *lower = g_ascii_strdown(theme_name, -1);
      bool dark = strstr(lower, "dark") != nullptr;
      g_free(lower);
      g_free(theme_name);
      if (dark) {
        return true;
      }
    }
  }
#endif
  return false;
}

/* 系统深色偏好变化通知(仅 Linux):监听 GtkSettings 的深色开关与主题名
 * 两个属性,任一变化即回调 MoonBit;信号只挂一份,后续注册直接回调。
 * 回调用具名函数——G_CALLBACK 是宏,lambda 参数列表的逗号会被预处理器劈开。 */
void yue_mbt_settings_notify(GObject *, GParamSpec *, gpointer d) {
  auto *p = static_cast<std::pair<void (*)(void *), void *> *>(d);
  p->first(p->second);
}

void yue_mbt_on_system_theme_change(void (*invoke)(void *), void *closure) {
#if defined(OS_LINUX)
  GtkSettings *settings = gtk_settings_get_default();
  if (settings == nullptr) {
    return;
  }
  static gulong connected = 0;
  if (connected == 0) {
    connected = 1;
    // 两个信号共用同一份闭包载体,释放钩子挂在其中一个上
    auto *cb = new std::pair<void (*)(void *), void *>(invoke, closure);
    g_signal_connect_data(settings, "notify::gtk-application-prefer-dark-theme",
                          G_CALLBACK(yue_mbt_settings_notify), cb,
                          +[](gpointer d, GClosure *) {
                            delete static_cast<
                                std::pair<void (*)(void *), void *> *>(d);
                          },
                          (GConnectFlags)0);
    g_signal_connect_data(settings, "notify::gtk-theme-name",
                          G_CALLBACK(yue_mbt_settings_notify), cb, nullptr,
                          (GConnectFlags)0);
  } else {
    // 已有监听:仍回调一次,让后注册的 MoonBit 订阅者立即拿到当前状态
    invoke(closure);
  }
#endif
}

static void yue_mbt_repaint_walk(GtkWidget *widget, gpointer) {
  gtk_widget_queue_draw(widget);
  if (GdkWindow *gw = gtk_widget_get_window(widget)) {
    gdk_window_invalidate_rect(gw, nullptr, TRUE);
  }
  if (GTK_IS_CONTAINER(widget)) {
    gtk_container_foreach(GTK_CONTAINER(widget), yue_mbt_repaint_walk,
                          nullptr);
  }
}

void yue_mbt_repaint_all(void) {
#if defined(OS_LINUX)
  GList *toplevels = gtk_window_list_toplevels();
  for (GList *l = toplevels; l != nullptr; l = l->next) {
    if (gtk_widget_is_toplevel(GTK_WIDGET(l->data)) &&
        gtk_widget_get_visible(GTK_WIDGET(l->data))) {
      yue_mbt_repaint_walk(GTK_WIDGET(l->data), nullptr);
    }
  }
  g_list_free(toplevels);
  // 全部失效完成后再一次性同步绘制
  gdk_window_process_all_updates();
#endif
}

int32_t yue_mbt_view_add_tooltip_for_rect(void *view, const char *text,
                                          double x, double y, double w,
                                          double h) {
  if (auto *v = CastToView(view)) {
    return v->AddTooltipForRect(text, nu::RectF(x, y, w, h));
  }
  return -1;
}

void yue_mbt_view_remove_tooltip(void *view, int32_t id) {
  if (auto *v = CastToView(view)) {
    v->RemoveTooltip(id);
  }
}

void yue_mbt_view_set_focusable(void *view, int32_t focusable) {
  if (auto *v = CastToView(view)) {
    v->SetFocusable(focusable != 0);
  }
}

int32_t yue_mbt_view_has_focus(void *view) {
  if (auto *v = CastToView(view)) {
    return v->HasFocus() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_view_schedule_paint_rect(void *view, double x, double y,
                                      double w, double h) {
  if (auto *v = CastToView(view)) {
    v->SchedulePaintRect(nu::RectF(x, y, w, h));
  }
}

void yue_mbt_view_on_focus_in(void *view, int32_t (*invoke)(void *),
                              void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_focus_in.Connect(
        [invoke, closure](nu::View *) { return invoke(closure) != 0; });
  }
}

void yue_mbt_view_on_focus_out(void *view, int32_t (*invoke)(void *),
                               void *closure) {
  if (auto *v = CastToView(view)) {
    v->on_focus_out.Connect(
        [invoke, closure](nu::View *) { return invoke(closure) != 0; });
  }
}

/* Container:动态子视图 */
void yue_mbt_container_add_child_view_at(void *container, void *view,
                                         int32_t index) {
  auto *child = CastToView(view);
  if (auto *c = CastTo<nu::Container>(container)) {
    if (child != nullptr) {
      c->AddChildViewAt(scoped_refptr<nu::View>(child), index);
    }
  }
}

int32_t yue_mbt_container_remove_child_view(void *container, void *view) {
  auto *child = CastToView(view);
  if (auto *c = CastTo<nu::Container>(container)) {
    if (child != nullptr) {
      c->RemoveChildView(child);
      return 1;
    }
  }
  return 0;
}

int32_t yue_mbt_container_child_count(void *container) {
  if (auto *c = CastTo<nu::Container>(container)) {
    return c->ChildCount();
  }
  return 0;
}

/* Scroll:位置与滚动信号 */
double yue_mbt_scroll_get_position_x(void *scroll) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    return std::get<0>(s->GetScrollPosition());
  }
  return 0.0;
}

double yue_mbt_scroll_get_position_y(void *scroll) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    return std::get<1>(s->GetScrollPosition());
  }
  return 0.0;
}

double yue_mbt_scroll_get_max_position_x(void *scroll) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    return std::get<0>(s->GetMaximumScrollPosition());
  }
  return 0.0;
}

double yue_mbt_scroll_get_max_position_y(void *scroll) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
    return std::get<1>(s->GetMaximumScrollPosition());
  }
  return 0.0;
}

#if defined(OS_WIN)
// Windows:on_scroll 信号发射在 ScrollImpl::Layout 重摆内容之前,
// 回调里立即强制 Layout 会用滚动前的旧 size_allocation 定位原生
// HWND(EDIT/DATETIMEPICK),控件被钉在旧位置遮挡已滚上来的内容。
// 用 0ms 定时器把回调推迟到本次滚动布局全部完成之后执行。
namespace {
struct DeferredScrollCallback {
  int32_t (*invoke)(void *);
  void *closure;
};
std::map<UINT_PTR, DeferredScrollCallback> g_deferred_scroll_callbacks;
void CALLBACK DeferredScrollTimer(HWND, UINT, UINT_PTR id, DWORD) {
  ::KillTimer(nullptr, id);
  const auto it = g_deferred_scroll_callbacks.find(id);
  if (it == g_deferred_scroll_callbacks.end())
    return;
  const DeferredScrollCallback cb = it->second;
  g_deferred_scroll_callbacks.erase(it);
  cb.invoke(cb.closure);
}
}  // namespace
#endif

void yue_mbt_scroll_on_scroll(void *scroll, int32_t (*invoke)(void *),
                              void *closure) {
  if (auto *s = CastTo<nu::Scroll>(scroll)) {
#if defined(OS_WIN)
    s->on_scroll.Connect([invoke, closure](nu::Scroll *) -> bool {
      const UINT_PTR id = ::SetTimer(nullptr, 0, 0, DeferredScrollTimer);
      if (id != 0)
        g_deferred_scroll_callbacks[id] = {invoke, closure};
      return false;  // 回调已推迟,本次发射不吃返回值
    });
#else
    s->on_scroll.Connect(
        [invoke, closure](nu::Scroll *) { return invoke(closure) != 0; });
#endif
  }
}

/* Label:对齐与富文本 */
void yue_mbt_label_set_valign(void *label, int32_t align) {
  if (auto *l = CastTo<nu::Label>(label)) {
    l->SetVAlign(static_cast<nu::TextAlign>(align));
  }
}

void yue_mbt_label_set_attributed_text(void *label, void *at) {
  auto *t = AttributedTextStore::get(at);
  if (auto *l = CastTo<nu::Label>(label)) {
    if (t != nullptr) {
      l->SetAttributedText(scoped_refptr<nu::AttributedText>(t));
    }
  }
}

/* MessageBox:模态与默认按钮 */
void yue_mbt_message_box_set_default_response(void *box, int32_t response) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->SetDefaultResponse(response);
  }
}

void yue_mbt_message_box_set_cancel_response(void *box, int32_t response) {
  if (auto *m = MessageBoxStore::get(box)) {
    m->SetCancelResponse(response);
  }
}

int32_t yue_mbt_message_box_run(void *box) {
  if (auto *m = MessageBoxStore::get(box)) {
    return m->Run();
  }
  return -1;
}

int32_t yue_mbt_message_box_run_for_window(void *box, void *window) {
  auto *w = CastTo<nu::Window>(window);
  if (auto *m = MessageBoxStore::get(box)) {
    return m->RunForWindow(w);
  }
  return -1;
}

/* Clipboard:类型探测与变化监听 */
int32_t yue_mbt_clipboard_is_data_available(void *clipboard, int32_t kind) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    return c->IsDataAvailable(ToDataType(kind)) ? 1 : 0;
  }
  return 0;
}

void yue_mbt_clipboard_start_watching(void *clipboard) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    c->StartWatching();
  }
}

void yue_mbt_clipboard_stop_watching(void *clipboard) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    c->StopWatching();
  }
}

void yue_mbt_clipboard_on_change(void *clipboard, void (*invoke)(void *),
                                 void *closure) {
  if (auto *c = static_cast<nu::Clipboard *>(clipboard)) {
    c->on_change.Connect([invoke, closure](nu::Clipboard *) {
      invoke(closure);
    });
  }
}

/* Table:选择模式与模型刷新 */
void yue_mbt_table_enable_multiple_selection(void *table, int32_t enable) {
  if (auto *t = CastTo<nu::Table>(table)) {
    t->EnableMultipleSelection(enable != 0);
  }
}

void yue_mbt_table_select_row(void *table, int32_t row) {
  if (auto *t = CastTo<nu::Table>(table)) {
    t->SelectRow(row);
  }
}

int32_t yue_mbt_table_get_selected_row(void *table) {
  if (auto *t = CastTo<nu::Table>(table)) {
    return t->GetSelectedRow();
  }
  return -1;
}

int32_t yue_mbt_table_notify_row_insertion(void *table, int32_t row) {
  // Notify* 由 TableModel 公开转发(Table 侧同名方法为 private);
  // Linux(GTK) 端模型变更由 GtkTreeModel 自动通知视图,无需手动触发。
#if defined(OS_LINUX)
  (void)table;
  (void)row;
  return 0;
#else
  if (auto *t = CastTo<nu::Table>(table)) {
    if (auto *m = t->GetModel()) {
      m->NotifyRowInsertion(row);
      return 1;
    }
  }
  return 0;
#endif
}

int32_t yue_mbt_table_notify_row_deletion(void *table, int32_t row) {
#if defined(OS_LINUX)
  (void)table;
  (void)row;
  return 0;
#else
  if (auto *t = CastTo<nu::Table>(table)) {
    if (auto *m = t->GetModel()) {
      m->NotifyRowDeletion(row);
      return 1;
    }
  }
  return 0;
#endif
}

int32_t yue_mbt_table_notify_value_change(void *table, int32_t column,
                                          int32_t row) {
#if defined(OS_LINUX)
  (void)table;
  (void)column;
  (void)row;
  return 0;
#else
  if (auto *t = CastTo<nu::Table>(table)) {
    if (auto *m = t->GetModel()) {
      m->NotifyValueChange(column, row);
      return 1;
    }
  }
  return 0;
#endif
}

/* Browser:标题与停止(回调版 JS 执行与 AddBinding 另批) */
void *yue_mbt_browser_get_title(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return BytesFromString(b->GetTitle());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_browser_stop(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->Stop();
  }
}

/* Screen:主显示器与光标 */
static nu::Display g_screen_display;
static bool g_screen_display_valid = false;

static void RefreshPrimaryDisplay() {
  g_screen_display = nu::Screen::GetCurrent()->GetPrimaryDisplay();
  g_screen_display_valid = true;
}

double yue_mbt_screen_primary_scale_factor() {
  if (!g_screen_display_valid) {
    RefreshPrimaryDisplay();
  }
  return g_screen_display.scale_factor;
}

double yue_mbt_screen_primary_work_area_x() {
  if (!g_screen_display_valid) {
    RefreshPrimaryDisplay();
  }
  return g_screen_display.work_area.x();
}

double yue_mbt_screen_primary_work_area_y() {
  if (!g_screen_display_valid) {
    RefreshPrimaryDisplay();
  }
  return g_screen_display.work_area.y();
}

double yue_mbt_screen_primary_work_area_width() {
  if (!g_screen_display_valid) {
    RefreshPrimaryDisplay();
  }
  return g_screen_display.work_area.width();
}

double yue_mbt_screen_primary_work_area_height() {
  if (!g_screen_display_valid) {
    RefreshPrimaryDisplay();
  }
  return g_screen_display.work_area.height();
}

double yue_mbt_screen_cursor_x() {
  return nu::Screen::GetCurrent()->GetCursorScreenPoint().x();
}

double yue_mbt_screen_cursor_y() {
  return nu::Screen::GetCurrent()->GetCursorScreenPoint().y();
}

/* Appearance:暗色模式切换(SetDarkModeEnabled 为 Windows 独有 API;
 * Linux 由 GTK 主题决定,无此设置) */
void yue_mbt_appearance_set_dark_mode_enabled(int32_t enable) {
#if defined(OS_WIN)
  nu::Appearance::GetCurrent()->SetDarkModeEnabled(enable != 0);
#else
  (void)enable;
#endif
}

void yue_mbt_appearance_on_color_scheme_change(void (*invoke)(void *),
                                                void *closure) {
  nu::Appearance::GetCurrent()->on_color_scheme_change.Connect(
      [invoke, closure]() { invoke(closure); });
}

/* AttributedText:单行测量 */
double yue_mbt_attributed_text_get_one_line_width(void *at) {
  auto *t = AttributedTextStore::get(at);
  if (t != nullptr) {
    return t->GetOneLineSize().width();
  }
  return 0.0;
}

double yue_mbt_attributed_text_get_one_line_height(void *at) {
  auto *t = AttributedTextStore::get(at);
  if (t != nullptr) {
    return t->GetOneLineSize().height();
  }
  return 0.0;
}

/* Font:默认字体与元信息 */
void *yue_mbt_font_default() {
  nu::Font *f = nu::Font::Default();
  return f != nullptr ? reinterpret_cast<void *>(FontStore::put(f))
                      : nullptr;
}

void *yue_mbt_font_get_name(void *font) {
  auto *f = FontStore::get(font);
  if (f != nullptr) {
    return BytesFromString(f->GetName());
  }
  return moonbit_make_bytes(0, 0);
}

double yue_mbt_font_get_size(void *font) {
  auto *f = FontStore::get(font);
  if (f != nullptr) {
    return f->GetSize();
  }
  return 0.0;
}

/* GlobalShortcut */
void yue_mbt_global_shortcut_unregister_all() {
  nu::GlobalShortcut::GetCurrent()->UnregisterAll();
}

/* MenuItem:状态与程序化点击 */
void yue_mbt_menu_item_set_enabled(void *item, int32_t enabled) {
  auto *i = MenuItemStore::get(item);
  if (i != nullptr) {
    i->SetEnabled(enabled != 0);
  }
}

void yue_mbt_menu_item_set_visible(void *item, int32_t visible) {
  auto *i = MenuItemStore::get(item);
  if (i != nullptr) {
    i->SetVisible(visible != 0);
  }
}

int32_t yue_mbt_menu_item_is_visible(void *item) {
  auto *i = MenuItemStore::get(item);
  if (i != nullptr) {
    return i->IsVisible() ? 1 : 0;
  }
  return 0;
}

/* FileDialog */
void yue_mbt_file_dialog_set_title(void *dialog, const char *title) {
  if (auto *d = FileDialogStore::get(dialog)) {
    d->SetTitle(title);
  }
}

void yue_mbt_file_dialog_set_button_label(void *dialog, const char *label) {
  if (auto *d = FileDialogStore::get(dialog)) {
    d->SetButtonLabel(label);
  }
}

/* App:应用 ID */
void yue_mbt_app_set_id(const char *id) {
#if defined(OS_WIN) || defined(OS_LINUX)
  nu::App::GetCurrent()->SetID(id);
#else
  // mac 的 App 无 SetID(应用身份随 Bundle 走)
  (void)id;
#endif
}

void *yue_mbt_app_get_id() {
  return BytesFromString(nu::App::GetCurrent()->GetID());
}

/* GifPlayer:播放控制 */
void yue_mbt_gif_player_set_animating(void *gif, int32_t animating) {
  if (auto *g = CastTo<nu::GifPlayer>(gif)) {
    g->SetAnimating(animating != 0);
  }
}

int32_t yue_mbt_gif_player_is_animating(void *gif) {
  if (auto *g = CastTo<nu::GifPlayer>(gif)) {
    return g->IsAnimating() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_gif_player_is_playing(void *gif) {
  if (auto *g = CastTo<nu::GifPlayer>(gif)) {
    return g->IsPlaying() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_gif_player_stop_animation_timer(void *gif) {
  if (auto *g = CastTo<nu::GifPlayer>(gif)) {
    g->StopAnimationTimer();
  }
}

/* Canvas:尺寸与密度 */
double yue_mbt_canvas_get_scale_factor(void *canvas) {
  if (auto *c = CanvasStore::get(canvas)) {
    return c->GetScaleFactor();
  }
  return 1.0;
}

double yue_mbt_canvas_get_width(void *canvas) {
  if (auto *c = CanvasStore::get(canvas)) {
    return c->GetSize().width();
  }
  return 0.0;
}

double yue_mbt_canvas_get_height(void *canvas) {
  if (auto *c = CanvasStore::get(canvas)) {
    return c->GetSize().height();
  }
  return 0.0;
}

/* NotificationCenter:清除与通知回调 */
void yue_mbt_notification_center_clear() {
  nu::NotificationCenter::GetCurrent()->Clear();
}

#define MBT_NOTIF_SIG(name, field)                                          \
  void yue_mbt_notification_center_##name(void (*invoke)(void *, void *),    \
                                          void *closure) {                   \
    nu::NotificationCenter::GetCurrent()->field.Connect(                      \
        [invoke, closure](const std::string &id) {                            \
          invoke(closure, BytesFromString(id));                               \
        });                                                                   \
  }

MBT_NOTIF_SIG(on_notification_show, on_notification_show)
MBT_NOTIF_SIG(on_notification_close, on_notification_close)
MBT_NOTIF_SIG(on_notification_click, on_notification_click)
MBT_NOTIF_SIG(on_notification_action, on_notification_action)

#undef MBT_NOTIF_SIG


/* 方法级审计补齐二:Browser JS 回调/绑定与通用拖拽 */

void yue_mbt_browser_execute_javascript_callback(
    void *browser, const char *code,
    void (*invoke)(void *, int32_t, void *), void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->ExecuteJavaScript(
        code,
        [invoke, closure](bool ok, base::Value value) {
          std::string json;
          base::JSONWriter::Write(base::ValueView(value), &json);
          invoke(closure, ok ? 1 : 0, BytesFromString(json));
        });
  }
}

void yue_mbt_browser_add_raw_binding(void *browser, const char *name,
                                     void (*invoke)(void *, void *),
                                     void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->AddRawBinding(name, [invoke, closure](nu::Browser *, base::Value args) {
      std::string json;
      base::JSONWriter::Write(base::ValueView(args), &json);
      invoke(closure, BytesFromString(json));
    });
  }
}

void yue_mbt_browser_remove_binding(void *browser, const char *name) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->RemoveBinding(name);
  }
}

int32_t yue_mbt_browser_has_bindings(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->HasBindings() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_view_do_drag_data(void *view, const char *text,
                                  const char *file_paths, int32_t operations,
                                  int64_t drag_image) {
  auto *v = CastToView(view);
  if (v == nullptr) {
    return 0;
  }
  std::vector<nu::Clipboard::Data> data;
  if (text != nullptr && text[0] != '\0') {
    data.emplace_back(nu::Clipboard::Data::Type::Text, std::string(text));
  }
  if (file_paths != nullptr && file_paths[0] != '\0') {
    data.emplace_back(MakeFilePathsForDrag(file_paths));
  }
  if (data.empty()) {
    return 0;
  }
  nu::DragOptions options;
  if (drag_image != 0) {
    if (auto *img = ImageStore::get(reinterpret_cast<void *>(drag_image))) {
      options.image = scoped_refptr<nu::Image>(img);
    }
  }
  return v->DoDragWithOptions(std::move(data), operations, options);
}

int32_t yue_mbt_view_cancel_drag(void *view) {
  if (auto *v = CastToView(view)) {
    v->CancelDrag();
    return 1;
  }
  return 0;
}

int32_t yue_mbt_view_is_dragging(void *view) {
  if (auto *v = CastToView(view)) {
    return v->IsDragging() ? 1 : 0;
  }
  return 0;
}

void *yue_mbt_null_image() {
  return nullptr;
}

// ---------- 探测示例(examples/probe):真机原生控件信息收集 ----------
// 输出全部走 stderr;Windows 真机以 `moon run examples/probe > probe.log 2>&1` 收集

#if defined(OS_WIN)
static BOOL CALLBACK ProbeEnumChildProc(HWND h, LPARAM) {
  WCHAR cls[256] = L"";
  ::GetClassNameW(h, cls, 256);
  WCHAR title[96] = L"";
  ::GetWindowTextW(h, title, 96);
  RECT r;
  ::GetWindowRect(h, &r);
  std::fprintf(stderr,
               "  child hwnd=%p class=%ls title=%ls rect=(%ld,%ld,%ld,%ld) "
               "style=0x%lx\n",
               static_cast<void *>(h), cls, title, static_cast<long>(r.left),
               static_cast<long>(r.top), static_cast<long>(r.right),
               static_cast<long>(r.bottom),
               static_cast<unsigned long>(::GetWindowLongPtrW(h, GWL_STYLE)));
  return TRUE;
}
#endif

/* 环境探针:系统版本/窗口 DPI/系统暗色开关/全部原生子控件枚举。 */
void yue_mbt_probe_env(void *window) {
#if defined(OS_WIN)
  std::fprintf(stderr, "==== PROBE env ====\n");
  auto *win = CastTo<nu::Window>(window);
  HWND h = (win != nullptr && win->GetNative() != nullptr)
               ? win->GetNative()->hwnd()
               : nullptr;
  // 系统版本:RtlGetVersion(GetVersionEx 在新 SDK 一律谎报 6.2)
  struct ProbeOSVersion {
    unsigned long size;
    unsigned long major;
    unsigned long minor;
    unsigned long build;
    unsigned long platform;
    WCHAR pad[128];
  };
  HMODULE ntdll = ::GetModuleHandleW(L"ntdll");
  if (ntdll != nullptr) {
    auto rtl = reinterpret_cast<long(__stdcall *)(ProbeOSVersion *)>(
        ::GetProcAddress(ntdll, "RtlGetVersion"));
    if (rtl != nullptr) {
      ProbeOSVersion v{};
      v.size = sizeof(v);
      rtl(&v);
      std::fprintf(stderr, "  os=%lu.%lu build=%lu\n", v.major, v.minor,
                   v.build);
    }
  }
  // 窗口 DPI(96=100% 缩放)
  HMODULE user32 = ::GetModuleHandleW(L"user32.dll");
  auto get_dpi = reinterpret_cast<UINT(__stdcall *)(HWND)>(
      user32 != nullptr ? ::GetProcAddress(user32, "GetDpiForWindow")
                        : nullptr);
  std::fprintf(stderr, "  window-dpi=%u\n",
               (h != nullptr && get_dpi != nullptr) ? get_dpi(h) : 0);
  // 系统应用暗色开关(1=浅色 0=暗色)
  DWORD light = 1;
  DWORD sz = sizeof(light);
  if (::RegGetValueW(
          HKEY_CURRENT_USER,
          L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
          L"AppsUseLightTheme", RRF_RT_DWORD, nullptr, &light, &sz) ==
      ERROR_SUCCESS) {
    std::fprintf(stderr, "  system-apps-light=%lu\n",
                 static_cast<unsigned long>(light));
  }
  if (h != nullptr) {
    WCHAR cls[256] = L"";
    ::GetClassNameW(h, cls, 256);
    std::fprintf(stderr, "  top hwnd=%p class=%ls\n", static_cast<void *>(h),
                 cls);
    std::fprintf(stderr, "  ---- 原生子控件枚举 ----\n");
    ::EnumChildWindows(h, ProbeEnumChildProc, 0);
  }
#else
  (void)window;
  std::fprintf(stderr, "==== PROBE env: 非 Windows,略 ====\n");
#endif
}

/* 单控件探针:nu 类名/实现 C++ 类型(RTTI)/原生子 HWND 的窗口类名与几何。 */
void yue_mbt_probe_view(void *view, const char *label) {
  if (auto *v = CastToView(view)) {
    std::fprintf(stderr, "PROBE [%s]: nu-class=%s\n", label, v->GetClassName());
#if defined(OS_WIN)
    if (v->GetNative() != nullptr) {
      std::fprintf(stderr, "  impl-typeid=%s\n",
                   typeid(*v->GetNative()).name());
    }
    if (auto *subwin = dynamic_cast<nu::SubwinView *>(v->GetNative())) {
      HWND h = subwin->hwnd();
      if (h != nullptr) {
        WCHAR cls[256] = L"";
        ::GetClassNameW(h, cls, 256);
        RECT r;
        ::GetWindowRect(h, &r);
        std::fprintf(stderr,
                     "  hwnd=%p win-class=%ls rect=(%ld,%ld,%ld,%ld)\n",
                     static_cast<void *>(h), cls, static_cast<long>(r.left),
                     static_cast<long>(r.top), static_cast<long>(r.right),
                     static_cast<long>(r.bottom));
      } else {
        std::fprintf(stderr, "  SubwinView 但 hwnd=null\n");
      }
    } else {
      std::fprintf(stderr, "  无 SubwinView: 自绘 view(无原生子 HWND)\n");
    }
#else
    (void)label;
#endif
  } else {
    std::fprintf(stderr, "PROBE [%s]: 句柄无效\n", label);
  }
}

#if defined(OS_WIN)
/* 暗色化:Explorer 系控件经 uxtheme 的 Darkmode_Explorer 变体
 * (动态加载 SetWindowTheme,避免引入 uxtheme.lib 链接依赖);
 * RichEdit 不吃 theme,发 EM_SETBKCOLOR+CHARFORMAT 暗底白字;
 * 进度条走 PBM_SETBKCOLOR/PBM_SETBARCOLOR 消息自定色。 */
#ifndef EM_SETBKCOLOR // 部分 SDK 的 richedit.h 未定义,值 WM_USER+271 稳定
#define EM_SETBKCOLOR (WM_USER + 271)
#endif
static BOOL CALLBACK ProbeApplyDark(HWND h, LPARAM) {
  auto set_theme = reinterpret_cast<HRESULT(__stdcall *)(HWND, LPCWSTR, LPCWSTR)>(
      ::GetProcAddress(::GetModuleHandleW(L"uxtheme.dll"), "SetWindowTheme"));
  if (set_theme != nullptr) {
    set_theme(h, L"Darkmode_Explorer", nullptr);
  }
  return TRUE; // WNDENUMPROC 要求 BOOL
}
#endif

void yue_mbt_probe_dark(void *view) {
#if defined(OS_WIN)
  auto *v = CastToView(view);
  auto *subwin =
      v != nullptr ? dynamic_cast<nu::SubwinView *>(v->GetNative()) : nullptr;
  HWND h = subwin != nullptr ? subwin->hwnd() : nullptr;
  if (h == nullptr) {
    std::fprintf(stderr, "DARK: 无原生子控件, 跳过\n");
    return;
  }
  WCHAR cls[256] = L"";
  ::GetClassNameW(h, cls, 256);
  std::fprintf(stderr, "DARK: %ls\n", cls);
  ::EnumChildWindows(h, ProbeApplyDark, 0); // 含 Table 的 SysHeader32 表头
  ProbeApplyDark(h, 0);
  if (::lstrcmpiW(cls, L"RICHEDIT50W") == 0) {
    ::SendMessageW(h, EM_SETBKCOLOR, 0,
                   static_cast<LPARAM>(RGB(0x20, 0x21, 0x24)));
    CHARFORMAT2W cf{};
    cf.cbSize = sizeof(cf);
    cf.dwMask = CFM_COLOR;
    cf.dwEffects &= ~CFE_AUTOCOLOR; // 清自动色, 启用 crTextColor
    cf.crTextColor = RGB(0xE8, 0xEA, 0xED);
    ::SendMessageW(h, EM_SETCHARFORMAT, SCF_DEFAULT, reinterpret_cast<LPARAM>(&cf));
  }
  if (::lstrcmpiW(cls, L"msctls_progress32") == 0) {
    // 启用视觉样式的进度条忽略 PBM 颜色消息, 先卸掉 theme 再上色
    auto set_theme2 =
        reinterpret_cast<HRESULT(__stdcall *)(HWND, LPCWSTR, LPCWSTR)>(
            ::GetProcAddress(::GetModuleHandleW(L"uxtheme.dll"),
                             "SetWindowTheme"));
    if (set_theme2 != nullptr) {
      set_theme2(h, L"", L"");
    }
    ::SendMessageW(h, PBM_SETBKCOLOR, 0,
                   static_cast<LPARAM>(RGB(0x2A, 0x2D, 0x31)));
    ::SendMessageW(h, PBM_SETBARCOLOR, 0,
                   static_cast<LPARAM>(RGB(0x5B, 0x8D, 0xEF)));
  }
  if (::lstrcmpiW(cls, L"SysListView32") == 0) {
    // Darkmode_Explorer 只覆盖滚动条/边框, 底色与文字色仍要 LVM 消息
    ::SendMessageW(h, LVM_SETBKCOLOR, 0,
                   static_cast<LPARAM>(RGB(0x20, 0x21, 0x24)));
    ::SendMessageW(h, LVM_SETTEXTBKCOLOR, 0,
                   static_cast<LPARAM>(RGB(0x20, 0x21, 0x24)));
    ::SendMessageW(h, LVM_SETTEXTCOLOR, 0,
                   static_cast<LPARAM>(RGB(0xE8, 0xEA, 0xED)));
  }
  ::RedrawWindow(h, nullptr, nullptr,
                 RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN);
#else
  (void)view;
  std::fprintf(stderr, "DARK: 非 Windows, 略\n");
#endif
}

}  // extern "C"

