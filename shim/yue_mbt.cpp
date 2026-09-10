// 平台封装层：libyue C++ API → C ABI 的机械转换。
// 原则：本文件只做 ABI 翻译，不写业务逻辑；平台差异优先交给 libyue，
// 只有 libyue 没暴露的（如托盘后端探测）才在这里补。
#include "yue_mbt.h"

#include <dlfcn.h>
#include <moonbit.h>

#include "nativeui/nativeui.h"

namespace {

// 生命周期对象进程级常驻：GUI 库惯例，退出即进程结束，无需析构。
nu::Lifetime *g_lifetime = nullptr;
nu::State *g_state = nullptr;

// 各控件的外部对象容器：MoonBit GC 管理容器本身，
// finalizer 只释放 C++ 引用计数（skill 规则：容器不可 free）。
struct WindowBox {
  scoped_refptr<nu::Window> window;
};

struct LabelBox {
  scoped_refptr<nu::Label> label;
};

struct TrayBox {
  scoped_refptr<nu::Tray> tray;
};

template <typename T>
void ReleaseRef(void *ptr) {
  if (ptr == nullptr) {
    return;
  }
  // 只析构内部 scoped_refptr，容器内存归 GC
  static_cast<T *>(ptr)->~T();
}

}  // namespace

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

void *yue_mbt_window_new(void) {
  auto *box = static_cast<WindowBox *>(
      moonbit_make_external_object(ReleaseRef<WindowBox>, sizeof(WindowBox)));
  new (&box->window) scoped_refptr<nu::Window>(new nu::Window(nu::Window::Options()));
  return box;
}

void yue_mbt_window_set_content(void *window, const void *content) {
  auto *label_box = static_cast<const LabelBox *>(content);
  static_cast<WindowBox *>(window)->window->SetContentView(
      scoped_refptr<nu::View>(label_box->label.get()));
}

void yue_mbt_window_set_content_size(void *window, double width, double height) {
  static_cast<WindowBox *>(window)->window->SetContentSize(
      nu::SizeF(static_cast<float>(width), static_cast<float>(height)));
}

void yue_mbt_window_center(void *window) {
  static_cast<WindowBox *>(window)->window->Center();
}

void yue_mbt_window_activate(void *window) {
  static_cast<WindowBox *>(window)->window->Activate();
}

void yue_mbt_window_on_close(void *window, void (*invoke)(void *), void *closure) {
  // 信号连接随窗口存活；lambda 按值捕获，杜绝悬垂
  static_cast<WindowBox *>(window)->window->on_close.Connect(
      [invoke, closure](nu::Window *) { invoke(closure); });
}

// ---------- 标签 ----------

void *yue_mbt_label_new(const char *text) {
  auto *box = static_cast<LabelBox *>(
      moonbit_make_external_object(ReleaseRef<LabelBox>, sizeof(LabelBox)));
  new (&box->label) scoped_refptr<nu::Label>(new nu::Label(text));
  return box;
}

void yue_mbt_label_set_text(void *label, const char *text) {
  static_cast<LabelBox *>(label)->label->SetText(text);
}

// ---------- 托盘 ----------

#if defined(OS_LINUX)

// libyue 的 Linux 托盘在运行期 dlopen AppIndicator，加载失败只打日志，
// 对外无任何查询接口。这里补一个同语义的探测，让 MoonBit 层能提前降级。
// 探测列表覆盖 gnome/libappindicator 与 ayatana 两个分支（Ubuntu 22.04+
// 只带 ayatana），比 libyue 内置列表更宽。
int32_t yue_mbt_tray_supported(void) {
  const char *candidates[] = {
      "libayatana-appindicator3.so.1",
      "libayatana-appindicator3.so",
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

void *yue_mbt_tray_new(const char *icon_path) {
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
  return box;
}

void yue_mbt_tray_set_title(void *tray, const char *title) {
  static_cast<TrayBox *>(tray)->tray->SetTitle(title);
}

void yue_mbt_tray_remove(void *tray) {
  static_cast<TrayBox *>(tray)->tray->Remove();
}
