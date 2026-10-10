// MoonBit 原生 GUI 栈的平台后端（Linux = GTK3）。
//
// 形态约束（都来自本仓实测）：
// - 循环归 MoonBit：这里只提供「等一等」与「跑已就绪的事件」两个动作，不调
//   gtk_main；等待用 GLib 主上下文的低层配方 prepare/query/poll/check，
//   超时由 MoonBit 的 Loop::wait_budget 给（None 即无限等，靠 wakeup 位回来）。
// - 不做 C→MoonBit 回调：事件以「每窗口标志位 + 消费式取事件」暴露，避开蹦床
//   形参错位那一类坑（docs/zh/adaptation.md「MoonBit ↔ C ABI」）。
// - 像素缓冲归 MoonBit：present 收到的就是 yue/render 的 RGBA 字节，本层做
//   RGBA→BGRx 换序后用 Cairo 贴到窗口，窗口上的像素与离屏快照同源。

#include <gtk/gtk.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define WM_MAX_WINDOWS 32
#define WM_MAX_FDS 64

typedef struct {
  GtkWidget *window;
  GtkWidget *area;
  int need_draw;   // 需要重绘（expose 或尺寸变化后置 1）
  int resized;     // 尺寸变了，本次取事件时回报新宽高
  int closing;     // 窗口管理器请求关闭
  int width;
  int height;
} WmWindow;

static WmWindow wm_windows[WM_MAX_WINDOWS];
static int wm_next_id = 1;

static void wm_mark_draw(WmWindow *w) {
  w->need_draw = 1;
}

static gboolean wm_on_draw(GtkWidget *area, cairo_t *cr, gpointer data) {
  (void)area;
  (void)cr;
  WmWindow *w = (WmWindow *)data;
  w->need_draw = 1; // 内容由 MoonBit 侧 present 负责，这里只记「该画了」
  return FALSE;
}

static void wm_on_size_allocate(GtkWidget *area, GdkRectangle *alloc,
                                gpointer data) {
  (void)area;
  WmWindow *w = (WmWindow *)data;
  w->width = alloc->width;
  w->height = alloc->height;
  w->resized = 1;
  w->need_draw = 1;
}

static gboolean wm_on_delete(GtkWidget *window, GdkEvent *event, gpointer data) {
  (void)window;
  (void)event;
  WmWindow *w = (WmWindow *)data;
  w->closing = 1;
  return TRUE; // 不在此处销毁：先停派发、再拆对象由 MoonBit 侧驱动
}

int wm_init(void) {
  static int argc = 0;
  char **argv = NULL;
  if (!gtk_init_check(&argc, &argv)) {
    return 0; // 没有可用的显示服务，MoonBit 侧据此降级
  }
  return 1;
}

int64_t wm_window_new(int width, int height, const char *title) {
  if (wm_next_id >= WM_MAX_WINDOWS) {
    return 0;
  }
  int id = wm_next_id++;
  WmWindow *w = &wm_windows[id];
  w->width = width > 1 ? width : 1;
  w->height = height > 1 ? height : 1;
  w->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(w->window), title ? title : "MoonBit");
  gtk_window_set_default_size(GTK_WINDOW(w->window), w->width, w->height);
  w->area = gtk_drawing_area_new();
  gtk_container_add(GTK_CONTAINER(w->window), w->area);
  g_signal_connect(w->area, "draw", G_CALLBACK(wm_on_draw), w);
  g_signal_connect(w->area, "size-allocate", G_CALLBACK(wm_on_size_allocate), w);
  g_signal_connect(w->window, "delete-event", G_CALLBACK(wm_on_delete), w);
  return (int64_t)id;
}

void wm_show(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window != NULL) {
    gtk_widget_show_all(w->window);
    // 必须把 map 请求推出去并跑一轮就绪事件：GDK 输出缓冲不 flush 的话，
    // X 服务端收不到 map，poll 就只能等到超时（实测 frames=0 的原因）。
    gdk_display_flush(gdk_display_get_default());
    while (gtk_events_pending()) {
      gtk_main_iteration_do(FALSE);
    }
    wm_mark_draw(w);
  }
}

void wm_size(int64_t id, int32_t *out_w, int32_t *out_h) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (out_w != NULL) {
    *out_w = w->width;
  }
  if (out_h != NULL) {
    *out_h = w->height;
  }
}

// 消费式取事件：1 = 需要重绘，2 = 尺寸变化（宽高已更新），3 = 请求关闭，
// 0 = 没有待处理事件。一次返回一个，MoonBit 侧循环取到 0 为止。
int wm_event(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (w->closing) {
    w->closing = 0;
    return 3;
  }
  if (w->resized) {
    w->resized = 0;
    return 2;
  }
  if (w->need_draw) {
    w->need_draw = 0;
    return 1;
  }
  return 0;
}

void wm_present(int64_t id, const unsigned char *rgba, int width, int height) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window == NULL || width < 1 || height < 1) {
    return;
  }
  GdkWindow *gw = gtk_widget_get_window(w->area);
  if (gw == NULL) {
    return; // 还没 realized，等下一次 draw 事件再画
  }
  // 换序到后端暂存缓冲：调用方的 RGBA 位图必须保持原样（离屏快照与它同源，
  // 就地换序会让下一次快照通道错位，重复上屏还会来回颠倒）。
  static unsigned char *scratch = NULL;
  static size_t scratch_len = 0;
  size_t need = (size_t)width * (size_t)height * 4;
  if (need > scratch_len) {
    free(scratch);
    scratch = (unsigned char *)malloc(need);
    scratch_len = need;
  }
  if (scratch == NULL) {
    return;
  }
  for (size_t i = 0; i < (size_t)width * (size_t)height; i++) {
    const unsigned char *px = rgba + i * 4;
    scratch[i * 4] = px[2];      // B
    scratch[i * 4 + 1] = px[1];  // G
    scratch[i * 4 + 2] = px[0];  // R
    scratch[i * 4 + 3] = 0xff;   // Cairo RGB24 忽略 alpha，这里按不透明上屏
  }
  cairo_surface_t *surf = cairo_image_surface_create_for_data(
      scratch, CAIRO_FORMAT_RGB24, width, height, width * 4);
  if (cairo_surface_status(surf) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(surf);
    return;
  }
  cairo_surface_flush(surf);
  G_GNUC_BEGIN_IGNORE_DEPRECATIONS
  cairo_t *cr = gdk_cairo_create(gw);
  G_GNUC_END_IGNORE_DEPRECATIONS
  if (cr == NULL) {
    cairo_surface_destroy(surf);
    return;
  }
  cairo_set_source_surface(cr, surf, 0, 0);
  cairo_paint(cr);
  cairo_destroy(cr);
  cairo_surface_destroy(surf);
}

void wm_close(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window != NULL) {
    gtk_widget_destroy(w->window);
    w->window = NULL;
    w->area = NULL;
  }
  memset(w, 0, sizeof(WmWindow));
}

// 跑掉主上下文里已经就绪的事件；不阻塞。
void wm_pump(void) {
  while (g_main_context_pending(NULL)) {
    g_main_context_iteration(NULL, FALSE);
  }
}

// timeout_ms < 0 表示无限等（MoonBit 侧无待办时用），此时必须有人调 wm_wakeup
// 或事件到达才能回来；否则就是死锁，这是漏唤醒的代价。
int wm_wait(int timeout_ms) {
  GMainContext *ctx = g_main_context_default();
  gint priority = 0;
  gint gtimeout = 0;
  GPollFD fds[WM_MAX_FDS];
  gint n;

  // 本机 glib 的加固签名：query 末位要传缓冲区容量、check 末位是 n_fds
  // （与多数文档示例的四参形态不同，实测按 /usr/include/glib-2.0/glib/gmain.h）
  (void)g_main_context_prepare(ctx, &priority);
  n = (gint)g_main_context_query(ctx, priority, &gtimeout, fds, WM_MAX_FDS);
  if (n > WM_MAX_FDS) {
    n = WM_MAX_FDS;
  }
  // -1 = 无限等；否则取「MoonBit 给的预算」与「GLib 自己要求的超时」中较短者
  gint wait_ms;
  if (timeout_ms < 0) {
    wait_ms = gtimeout;
  } else if (gtimeout < 0) {
    wait_ms = (gint)timeout_ms;
  } else {
    wait_ms = timeout_ms < gtimeout ? timeout_ms : gtimeout;
  }

  struct pollfd pf[WM_MAX_FDS];
  for (gint i = 0; i < n; i++) {
    pf[i].fd = fds[i].fd;
    pf[i].events = 0;
    if (fds[i].events & G_IO_IN) {
      pf[i].events |= POLLIN;
    }
    if (fds[i].events & G_IO_OUT) {
      pf[i].events |= POLLOUT;
    }
    if (fds[i].events & G_IO_PRI) {
      pf[i].events |= POLLPRI;
    }
    pf[i].revents = 0;
    fds[i].revents = 0;
  }
  // 注意：这里绝不能再调 g_main_context_wakeup —— 它会把 GLib 内部的唤醒
  // 管道置为可读，poll 立刻返回，外层退化成忙轮询（实测 dt=0、占满 CPU）。
  // 跨线程唤醒由外部调 wm_wakeup() 触发，效果就是让本次 poll 提前返回。
  gint got = poll(pf, n, wait_ms);
  gint ready = 0;
  for (gint i = 0; i < n; i++) {
    fds[i].revents = pf[i].revents;
    if (pf[i].revents != 0) {
      ready++;
    }
  }
  g_main_context_check(ctx, priority, fds, n);
  if (ready > 0 || g_main_context_pending(ctx)) {
    wm_pump();
    return 1;
  }
  (void)got;
  (void)ready;
  return 0;
}

void wm_wakeup(void) {
  g_main_context_wakeup(g_main_context_default());
}

int64_t wm_now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}
