// yue/web 的 C 桩：把 WebKitWebView 放进窗口层给的原生子件槽里。
//
// 三条口径：
// ① **只能动态链** WebKitGTK（发行版提供 webkit2gtk-4.1），运行期依赖已知并接受；
//    链接参数由 scripts/prebuild.py 全权托管（AGENTS 规则 1/2），本文件不参与。
// ② 分支形态照 yue/win/stub.c：prebuild 带 -DWB_HAVE_WEBKIT 专编真实现进
//    libyue_web.a；Linux 上 moon 的 native-stub 那次编译不带该宏、又落在
//    `#elif !defined(__linux__)` 之外，编出空翻译单元，于是符号只有一份。
//    缺 webkit 开发包时 prebuild 改编**无宏**的那份（占位实现），于是
//    `wb_available()` 返回 0、MoonBit 层按「探测 + 语义化降级」办，不是链接失败。
// ③ webkit 侧只认槽句柄：容器指针由 yue/win 的 `wm_surface_container()` 交出
//    （C 之间传指针，MoonBit 只搬 int64），所以本包不引 yue/win 的 MoonBit 层。

#if defined(WB_HAVE_WEBKIT)

#include <gtk/gtk.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <webkit2/webkit2.h>

// 窗口层交出的原生子件容器（实现在 yue/win 的 GTK 桩里，同一个可执行文件内链接）
extern GtkWidget *wm_surface_container(int64_t surface_id);

typedef struct {
  WebKitWebView *view;
  int64_t surface_id;
} WbView;

#define WB_MAX_VIEWS 32
static WbView wb_views[WB_MAX_VIEWS];
static int wb_next_id = 1;

int wb_available(void) { return 1; }

int64_t wb_create(int64_t surface_id, int w, int h, const char *uri) {
  GtkWidget *box = wm_surface_container(surface_id);
  if (box == NULL || wb_next_id >= WB_MAX_VIEWS) {
    return 0;
  }
  WebKitWebView *view = WEBKIT_WEB_VIEW(webkit_web_view_new());
  if (uri != NULL && uri[0] != '\0') {
    webkit_web_view_load_uri(view, uri);
  }
  gtk_widget_set_size_request(GTK_WIDGET(view), w > 1 ? w : 1, h > 1 ? h : 1);
  gtk_fixed_put(GTK_FIXED(box), GTK_WIDGET(view), 0, 0);
  gtk_widget_show_all(GTK_WIDGET(view));
  int id = wb_next_id++;
  wb_views[id].view = view;
  wb_views[id].surface_id = surface_id;
  return (int64_t)id;
}

void wb_load_uri(int64_t id, const char *uri) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL) {
    return;
  }
  webkit_web_view_load_uri(wb_views[id].view, uri ? uri : "about:blank");
}

void wb_reload(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL) {
    return;
  }
  webkit_web_view_reload(wb_views[id].view);
}

void wb_stop(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL) {
    return;
  }
  webkit_web_view_stop_loading(wb_views[id].view);
}

int wb_is_loading(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL) {
    return 0;
  }
  return webkit_web_view_is_loading(wb_views[id].view) ? 1 : 0;
}

// 当前 URI / 标题：照仓库既有的「C 写缓冲、MoonBit 读」口径（不能给 C 传可写数组）
int wb_uri(int64_t id, char *out, int cap) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL ||
      out == NULL || cap <= 0) {
    return 0;
  }
  const char *u = webkit_web_view_get_uri(wb_views[id].view);
  if (u == NULL) {
    out[0] = '\0';
    return 0;
  }
  strncpy(out, u, (size_t)cap - 1);
  out[cap - 1] = '\0';
  return (int)strlen(out);
}

int wb_title(int64_t id, char *out, int cap) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL ||
      out == NULL || cap <= 0) {
    return 0;
  }
  // get_title 返回内部字符串（随信号更新），不 free
  const char *t = webkit_web_view_get_title(wb_views[id].view);
  if (t == NULL) {
    out[0] = '\0';
    return 0;
  }
  strncpy(out, t, (size_t)cap - 1);
  out[cap - 1] = '\0';
  return (int)strlen(t);
}

void wb_set_size(int64_t id, int w, int h) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL) {
    return;
  }
  gtk_widget_set_size_request(
    GTK_WIDGET(wb_views[id].view), w > 1 ? w : 1, h > 1 ? h : 1
  );
}

void wb_destroy(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_views[id].view == NULL) {
    return;
  }
  // 先摘出容器再销毁：容器可能已随窗口拆掉（父指针为空时 remove 会告警）
  GtkWidget *w = GTK_WIDGET(wb_views[id].view);
  GtkWidget *parent = gtk_widget_get_parent(w);
  if (parent != NULL) {
    gtk_container_remove(GTK_CONTAINER(parent), w);
  } else {
    gtk_widget_destroy(w);
  }
  wb_views[id].view = NULL;
  wb_views[id].surface_id = 0;
}

#elif !defined(__linux__)

// 非 Linux 占位（Windows/macOS 后端随平台批）：符号必须在，能力探测返回不可用。
#include <stdint.h>

int wb_available(void) { return 0; }
int64_t wb_create(int64_t surface_id, int w, int h, const char *uri) {
  (void)surface_id; (void)w; (void)h; (void)uri;
  return 0;
}
void wb_load_uri(int64_t id, const char *uri) { (void)id; (void)uri; }
void wb_reload(int64_t id) { (void)id; }
void wb_stop(int64_t id) { (void)id; }
int wb_is_loading(int64_t id) {
  (void)id;
  return 0;
}
int wb_uri(int64_t id, char *out, int cap) {
  (void)id;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}
int wb_title(int64_t id, char *out, int cap) {
  (void)id;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}
void wb_set_size(int64_t id, int w, int h) { (void)id; (void)w; (void)h; }
void wb_destroy(int64_t id) { (void)id; }

#endif
// Linux 上不带 -DWB_HAVE_WEBKIT 的那次编译（moon native-stub，或 prebuild 发现
// 缺 webkit 开发包时的占位编法）落不进任何分支，编出空翻译单元——真实现只由
// prebuild 的 libyue_web.a 提供，绝不能再定义一份（双定义）。
