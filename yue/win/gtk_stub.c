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
  guint32 keysym;
  guint32 code;    // 0 键 / 1 按下键 / 2 按下指针 / 3 释放指针 / 4 滚轮
  gint32 x;
  gint32 y;
  gint32 dx;
  gint32 dy;
  guint32 mods;
} WmEv;

typedef struct {
  GtkWidget *window;
  GtkWidget *area;
  int need_draw;   // 需要重绘（expose 或尺寸变化后置 1）
  int resized;     // 尺寸变了，本次取事件时回报新宽高
  int closing;     // 窗口管理器请求关闭
  int width;
  int height;
  const unsigned char *pending; // 待贴的 RGBA 缓冲（所有权在 MoonBit）
  int pending_w;
  int pending_h;
  GtkIMContext *im;
  int cursor_kind;   // 当前光标形状（0 默认/1 手/2 文本/3 横向/4 纵向），-1 未设过
  char commit[256]; // 已提交文本（UTF-8），MoonBit 逐字节读走后清零
  int commit_len;
  char preedit[256]; // 未提交的组合串，仅用于自绘显示
  int preedit_len;
  int preedit_caret;
  int preedit_active;
  WmEv evs[64];
  WmEv last;
  int ev_head;
  int ev_count;
} WmWindow;

static WmWindow wm_windows[WM_MAX_WINDOWS];
static int wm_next_id = 1;

// 修饰位必须与 MoonBit 侧 yue/core/keys.mbt 的 MOD_* 一致：
// 1=shift 2=ctrl 4=alt 8=meta（GTK 自身位值是 1/4/8/16，故显式重映射）
static guint32 wm_mods(guint state) {
  guint32 m = 0;
  if (state & GDK_SHIFT_MASK) {
    m |= 1u;
  }
  if (state & GDK_CONTROL_MASK) {
    m |= 2u;
  }
  if (state & GDK_MOD1_MASK) {
    m |= 4u;
  }
  // Meta/Super 只认这两个位；绝不能把 MOD2 当 Meta——MOD2 就是 NumLock，
  // 平时恒为亮，会让每个按键都带上 Meta，内核据此判定为组合键而丢弃可打印键
  // （实测 mods=8、字符全部打不进去）
  if (state & (GDK_META_MASK | GDK_SUPER_MASK)) {
    m |= 8u;
  }
  return m;
}

static void wm_push(WmWindow *w, const WmEv *ev) {
  if (w->ev_count >= 64) {
    return; // 满了丢弃而不是覆盖：宁可丢一个事件，不能把 FIFO 打乱
  }
  int slot = (w->ev_head + w->ev_count) % 64;
  w->evs[slot] = *ev;
  w->ev_count++;
}

static void wm_store_text(char *dst, int *dst_len, const char *src) {
  int n = 0;
  if (src != NULL) {
    while (src[n] != '\0' && n < 255) {
      dst[n] = src[n];
      n++;
    }
  }
  dst[n] = '\0';
  *dst_len = n;
}

static void wm_on_im_commit(GtkIMContext *im, gchar *text, gpointer data) {
  (void)im;
  WmWindow *w = (WmWindow *)data;
  wm_store_text(w->commit, &w->commit_len, text);
  // 串的所有权在 GTK（信号返回后它自己释放），这里绝不能 g_free ——
  // 实测 free(): double free detected in tcache 2 直接 core dump。探针同此。
}

// 「commit」信号带文本；「preedit-changed」只带上下文，串要用
// gtk_im_context_get_preedit_string 取（探针里就是这个形态，签名照抄会错）
static void wm_on_preedit_changed(GtkIMContext *ctx, gpointer data) {
  WmWindow *w = (WmWindow *)data;
  gchar *str = NULL;
  PangoAttrList *attrs = NULL;
  gint caret = 0;
  gtk_im_context_get_preedit_string(ctx, &str, &attrs, &caret);
  wm_store_text(w->preedit, &w->preedit_len, str != NULL ? str : "");
  // caret 是组合串内的**字节**偏移（MoonBit 侧按 UTF-8 字节管光标，同口径）
  w->preedit_caret = caret > w->preedit_len ? w->preedit_len : caret;
  if (attrs != NULL) {
    pango_attr_list_unref(attrs);
  }
  g_free(str);
}

static void wm_on_preedit_start(GtkIMContext *im, gpointer data) {
  (void)im;
  ((WmWindow *)data)->preedit_active = 1;
}

static void wm_on_preedit_end(GtkIMContext *im, gpointer data) {
  (void)im;
  WmWindow *w = (WmWindow *)data;
  w->preedit_active = 0;
  w->preedit_len = 0;
  w->preedit[0] = '\0';
}

// 输入法上下文必须在 realize 之后才拿得到 client window：早于 realize 时
// gtk_widget_get_window 返回 NULL，set_client_window 等于没做，multicontext
// 就不会挂上任何输入法模块（实测表现为 filter_keypress 恒不消费、拼音原样进文本）
static void wm_on_realize(GtkWidget *area, gpointer data) {
  WmWindow *w = (WmWindow *)data;
  if (w->im == NULL) {
    return;
  }
  GdkWindow *gw = gtk_widget_get_window(area);
  if (gw != NULL) {
    gtk_im_context_set_client_window(w->im, gw);
  }
  gtk_im_context_focus_in(w->im);
}

static gboolean wm_on_area_focus_in(GtkWidget *area, GdkEventFocus *ev,
                                    gpointer data) {
  (void)area;
  (void)ev;
  WmWindow *w = (WmWindow *)data;
  if (w->im != NULL) {
    gtk_im_context_focus_in(w->im);
  }
  return FALSE;
}

// 失焦必须 focus_out，否则输入法侧残留未完成组合串（清单第 5 项）
static gboolean wm_on_area_focus_out(GtkWidget *area, GdkEventFocus *ev,
                                     gpointer data) {
  (void)area;
  (void)ev;
  WmWindow *w = (WmWindow *)data;
  if (w->im != NULL) {
    gtk_im_context_focus_out(w->im);
    w->preedit_active = 0;
    w->preedit_len = 0;
    w->preedit[0] = '\0';
  }
  return FALSE;
}

static void wm_mark_draw(WmWindow *w) {
  w->need_draw = 1;
}

static gboolean wm_on_draw(GtkWidget *area, cairo_t *cr, gpointer data) {
  (void)area;
  WmWindow *w = (WmWindow *)data;
  w->need_draw = 1;
  // 只在这里贴像素：GdkWindow 的生命周期由 GTK/WM 管，在 draw 之外拿它的
  // cairo 画会在窗口被销毁后打到死窗口上（实测 X 错误 RenderBadPicture）
  if (w->pending != NULL && w->pending_w > 0 && w->pending_h > 0) {
    cairo_surface_t *surf = cairo_image_surface_create_for_data(
        (unsigned char *)w->pending, CAIRO_FORMAT_ARGB32, w->pending_w,
        w->pending_h, w->pending_w * 4);
    if (cairo_surface_status(surf) == CAIRO_STATUS_SUCCESS) {
      cairo_set_source_surface(cr, surf, 0, 0);
      cairo_paint(cr);
    }
    cairo_surface_destroy(surf);
  }
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

static gboolean wm_on_key(GtkWidget *widget, GdkEventKey *ev, gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  if (ev->type == GDK_KEY_PRESS && w->im != NULL &&
      gtk_im_context_filter_keypress(w->im, ev)) {
    return TRUE; // 输入法吃掉了：不推按键事件，改由 commit/preedit 通道回报
  }
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = ev->type == GDK_KEY_PRESS ? 0u : 1u;
  // keyval 本身已含 shift 语义（'a' 与 'A' 不同值），不能再小写化
  e.keysym = ev->keyval;
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE; // 已经交给 MoonBit，不再走 GTK 的控件级派发
}

static gboolean wm_on_button(GtkWidget *widget, GdkEventButton *ev,
                             gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  WmEv e;
  memset(&e, 0, sizeof(e));
  // code: 0 键按下 1 键释放 2 按钮按下 3 按钮释放 4 指针移动 5 滚轮
  if (ev->type == GDK_BUTTON_RELEASE) {
    e.code = 3u;
  } else {
    e.code = 2u; // 双击对上层同样先是一次按下，双击语义由上层按时间判
  }
  e.x = (gint32)ev->x;
  e.y = (gint32)ev->y;
  e.dx = ev->button;
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE;
}

static gboolean wm_on_motion(GtkWidget *widget, GdkEventMotion *ev,
                             gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = 4u;
  e.x = (gint32)ev->x;
  e.y = (gint32)ev->y;
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE;
}

static gboolean wm_on_scroll(GtkWidget *widget, GdkEventScroll *ev,
                             gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  WmEv e;
  memset(&e, 0, sizeof(e));
  e.code = 5u;
  e.x = (gint32)ev->x;
  e.y = (gint32)ev->y;
  e.dy = ev->direction == GDK_SCROLL_UP ? 1
                                       : (ev->direction == GDK_SCROLL_DOWN ? -1
                                                                           : 0);
  e.dx = ev->direction == GDK_SCROLL_LEFT
      ? 1
      : (ev->direction == GDK_SCROLL_RIGHT ? -1 : 0);
  e.mods = wm_mods(ev->state);
  wm_push(w, &e);
  return TRUE;
}

// 窗口被 WM/GTK 销毁时必须清空句柄：否则 present 会 queue_draw 到悬垂 widget
// （实测刷一串 gtk_widget_queue_draw: assertion 'GTK_IS_WIDGET' failed）
static void wm_on_destroy(GtkWidget *widget, gpointer data) {
  (void)widget;
  WmWindow *w = (WmWindow *)data;
  w->window = NULL;
  w->area = NULL;
  w->pending = NULL;
  w->need_draw = 0;
  w->closing = 1; // 窗口没了也等于该退出了
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
  gtk_widget_set_can_focus(w->area, TRUE);
  GdkWindow *top = gtk_widget_get_window(w->window);
  (void)top; // realized 之后再设事件掩码
  gtk_widget_add_events(w->area, GDK_KEY_PRESS_MASK | GDK_KEY_RELEASE_MASK |
                                   GDK_BUTTON_PRESS_MASK |
                                   GDK_BUTTON_RELEASE_MASK |
                                   GDK_POINTER_MOTION_MASK |
                                   GDK_SCROLL_MASK);
  gtk_container_add(GTK_CONTAINER(w->window), w->area);
  g_signal_connect(w->area, "realize", G_CALLBACK(wm_on_realize), w);
  g_signal_connect(w->area, "focus-in-event", G_CALLBACK(wm_on_area_focus_in), w);
  g_signal_connect(w->area, "focus-out-event",
                   G_CALLBACK(wm_on_area_focus_out), w);
  g_signal_connect(w->area, "draw", G_CALLBACK(wm_on_draw), w);
  g_signal_connect(w->area, "size-allocate", G_CALLBACK(wm_on_size_allocate), w);
  w->im = gtk_im_multicontext_new();
  // use_preedit 语义是「用 preedit 串做内联反馈」：TRUE（默认）才是自绘内联那一档，
  // 填 FALSE 会让输入法改用自带子窗且本环境一条 preedit 信号都不推（G0 实测读反过）
  gtk_im_context_set_use_preedit(w->im, TRUE);
  g_signal_connect(w->im, "commit", G_CALLBACK(wm_on_im_commit), w);
  g_signal_connect(w->im, "preedit-changed", G_CALLBACK(wm_on_preedit_changed), w);
  g_signal_connect(w->im, "preedit-start", G_CALLBACK(wm_on_preedit_start), w);
  g_signal_connect(w->im, "preedit-end", G_CALLBACK(wm_on_preedit_end), w);
  w->ev_head = 0;
  w->ev_count = 0;
  memset(&w->last, 0, sizeof(WmEv));
  g_signal_connect(w->window, "delete-event", G_CALLBACK(wm_on_delete), w);
  g_signal_connect(w->window, "destroy", G_CALLBACK(wm_on_destroy), w);
  // 按键挂到「焦点控件」而不是顶层窗口：这是 G0 探针用真机定下来的挂法
  // （见 docs/zh/adaptation.md「G0 输入法探针纯通道」条——挂窗口层会让事件顺序
  // 与消费判定都不对，输入法接管后尤其明显）。失焦的 area 不接键。
  g_signal_connect(w->area, "key-press-event", G_CALLBACK(wm_on_key), w);
  g_signal_connect(w->area, "key-release-event", G_CALLBACK(wm_on_key), w);
  g_signal_connect(w->area, "button-press-event", G_CALLBACK(wm_on_button), w);
  g_signal_connect(w->area, "button-release-event", G_CALLBACK(wm_on_button),
                   w);
  g_signal_connect(w->area, "motion-notify-event", G_CALLBACK(wm_on_motion),
                   w);
  g_signal_connect(w->area, "scroll-event", G_CALLBACK(wm_on_scroll), w);
  return (int64_t)id;
}

void wm_show(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->window != NULL) {
    gtk_widget_show_all(w->window);
    gtk_widget_grab_focus(w->area);
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
  if (w->ev_count > 0) {
    return 4; // 有输入事件待取（wm_take_event）
  }
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
  if (w->area == NULL || rgba == NULL || width < 1 || height < 1) {
    return;
  }
  // 缓冲所有权仍在 MoonBit（yue/render 的 Bitmap）；这里只记地址，
  // 真正的贴像素发生在下一次 draw 回调里，那时窗口一定活着。
  w->pending = rgba;
  w->pending_w = width;
  w->pending_h = height;
  gtk_widget_queue_draw(w->area);
}

void wm_close(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  // 已被 WM 销毁过则 window 为 NULL，只清记录即可
  if (w->window != NULL) {
    gtk_widget_destroy(w->window);
    w->window = NULL;
    w->area = NULL;
  }
  w->pending = NULL;
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

// 取一个输入事件，返回其 code（0 键按下 1 键释放 2 按钮按下 3 按钮释放
// 4 指针移动 5 滚轮），无事件返回 -1。字段随后用 wm_ev_* 读这一条——
// MoonBit 侧不能给 C 传可写数组（传过去的是对象头，写 out[0] 会踩坏它），
// 所以走「取一条 + 逐字段读」而不是七个出参。
int wm_take_event(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return -1;
  }
  WmWindow *w = &wm_windows[id];
  if (w->ev_count == 0) {
    return -1;
  }
  w->last = w->evs[w->ev_head];
  w->ev_head = (w->ev_head + 1) % 64;
  w->ev_count--;
  return (int)w->last.code;
}

gint32 wm_ev_keysym(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? (gint32)wm_windows[id].last.keysym : 0;
}
gint32 wm_ev_mods(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? (gint32)wm_windows[id].last.mods : 0;
}
gint32 wm_ev_x(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.x : 0;
}
gint32 wm_ev_y(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.y : 0;
}
gint32 wm_ev_button(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.dx : 0;
}
gint32 wm_ev_axis(int64_t id) {
  return id > 0 && id < WM_MAX_WINDOWS ? wm_windows[id].last.dy : 0;
}

int wm_pending_events(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].ev_count;
}

void wm_request_focus(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->area != NULL) {
    gtk_widget_grab_focus(w->area);
  }
}

void wm_im_set_surrounding(int64_t id, const char *text, int caret) {
  if (text == NULL) {
    return;
  }
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->im == NULL) {
    return;
  }
  // 只喂已提交文本：组合串不进 surrounding，否则输入法按错上下文推断。
  // 用探针验证过的四参形态（text, len, cursor 为字节偏移），不走带 SelectionData 的新接口。
  gtk_im_context_set_surrounding(w->im, text, (gint)strlen(text), caret);
}

// 逻辑焦点从一个输入控件切到另一个时清掉输入法侧未完成的组合串：
// 不清的话，前一个框攒下的拼音会在后一个框拿到焦点后 commit 进去。
// 一并清本侧缓存——输入法在 reset 后不一定再推 preedit-changed，
// 旧串留在缓存里就会被继续画出来。
void wm_im_reset(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->im == NULL) {
    return;
  }
  gtk_im_context_reset(w->im);
  w->preedit_len = 0;
  w->preedit[0] = '\0';
}

// 设绘图区光标形状：0 默认箭头 / 1 手型 / 2 文本 I 形 / 3 横向调整 / 4 纵向调整。
// 自绘栈没有原生控件，悬停在手型件上时形状只能由宿主按命中路径下发；
// 未 realize（还没有 GdkWindow）或形状没变时什么都不做。
void wm_set_cursor(int64_t id, int kind) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->area == NULL || w->cursor_kind == kind) {
    return;
  }
  GdkWindow *gw = gtk_widget_get_window(w->area);
  if (gw == NULL) {
    return;
  }
  const char *name = "default";
  if (kind == 1) {
    name = "pointer";
  } else if (kind == 2) {
    name = "text";
  } else if (kind == 3) {
    name = "ew-resize";
  } else if (kind == 4) {
    name = "ns-resize";
  }
  GdkDisplay *dpy = gtk_widget_get_display(w->area);
  GdkCursor *cur = gdk_cursor_new_from_name(dpy, name);
  if (cur == NULL) {
    cur = gdk_cursor_new_from_name(dpy, "default");
  }
  if (cur == NULL) {
    return;
  }
  gdk_window_set_cursor(gw, cur);
  g_object_unref(cur);
  w->cursor_kind = kind;
  gdk_display_flush(dpy);
}

void wm_im_set_cursor(int64_t id, int x, int y, int w_, int h_) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  WmWindow *w = &wm_windows[id];
  if (w->im == NULL) {
    return;
  }
  GdkRectangle r;
  r.x = x;
  r.y = y;
  r.width = w_;
  r.height = h_;
  gtk_im_context_set_cursor_location(w->im, &r);
}

// 取一条已提交文本：返回字节数并把内容留在原处供逐字节读，
// 读完必须调 wm_im_commit_done 清零
int wm_im_commit_len(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].commit_len;
}

int wm_im_commit_byte(int64_t id, int index) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (index < 0 || index >= w->commit_len) {
    return 0;
  }
  return (int)(guchar)w->commit[index];
}

void wm_im_commit_done(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return;
  }
  wm_windows[id].commit_len = 0;
  wm_windows[id].commit[0] = '\0';
}

// preedit（组合串）状态：仅供自绘显示，绝不计入文本状态
int wm_im_preedit_len(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_len;
}

int wm_im_preedit_byte(int64_t id, int index) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  WmWindow *w = &wm_windows[id];
  if (index < 0 || index >= w->preedit_len) {
    return 0;
  }
  return (int)(guchar)w->preedit[index];
}

int wm_im_preedit_caret(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_caret;
}

int wm_im_preedit_active(int64_t id) {
  if (id <= 0 || id >= WM_MAX_WINDOWS) {
    return 0;
  }
  return wm_windows[id].preedit_active;
}

void wm_wakeup(void) {
  g_main_context_wakeup(g_main_context_default());
}

int64_t wm_now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}


/* ---- 系统深浅偏好与主色（主题跟随系统用） ----
 * 读 gsettings（GNOME 的 org.gnome.desktop.interface）：color-scheme 优先，
 * 老版本退回 gtk-theme 名字里的 "-dark"。字符串写进调用方给的缓冲并返回长度，
 * 0 表示读不到（非 GNOME 桌面、schema 不存在）——由 MoonBit 侧决定退路。
 * GSettings 对象建一次常驻（每拍轮询新建/销毁会反复走 dconf）。 */
typedef struct {
  GSettings *s;
  GSettingsSchema *schema;
} GsHolder;

static GsHolder gs_iface = { NULL, NULL };
static GsHolder gs_prefs = { NULL, NULL };

/* schema 存在才建 GSettings（非 GNOME 桌面上这些 schema 根本没有）；
 * 建好就常驻，每拍轮询不重复走 dconf。 */
static void gs_open(GsHolder *h, const char *name) {
  if (h->schema != NULL) {
    return;
  }
  GSettingsSchemaSource *src = g_settings_schema_source_get_default();
  if (src == NULL) {
    return;
  }
  h->schema = g_settings_schema_source_lookup(src, name, TRUE);
  if (h->schema != NULL) {
    h->s = g_settings_new(name);
  }
}

static int gs_read(GsHolder *h, const char *key, char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  gs_open(h, h == &gs_iface ? "org.gnome.desktop.interface"
                            : "org.gnome.desktop.wm.preferences");
  if (h->s == NULL || !g_settings_schema_has_key(h->schema, key)) {
    return 0;
  }
  gchar *v = g_settings_get_string(h->s, key);
  if (v == NULL) {
    return 0;
  }
  int n = (int)strlen(v);
  if (n >= cap) {
    n = cap - 1;
  }
  memcpy(out, v, (size_t)n);
  out[n] = '\0';
  g_free(v);
  return n;
}

/* "dark" / "light" / ""（未知）。color-scheme 优先，老版本退回 gtk-theme 名。 */
int wm_sys_color_scheme(char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  char buf[64];
  if (gs_read(&gs_iface, "color-scheme", buf, (int)sizeof(buf)) > 0) {
    if (strstr(buf, "dark") != NULL) {
      return (int)strlen(strcpy(out, "dark"));
    }
    if (strstr(buf, "light") != NULL) {
      return (int)strlen(strcpy(out, "light"));
    }
  }
  if (gs_read(&gs_iface, "gtk-theme", buf, (int)sizeof(buf)) > 0) {
    // 主题名里的 dark/light 大小写不一（Adwaita-dark、Orchis-Teal-Light-Compact）
    for (int i = 0; buf[i] != '\0'; i++) {
      buf[i] = (char)g_ascii_tolower(buf[i]);
    }
    if (strstr(buf, "dark") != NULL) {
      return (int)strlen(strcpy(out, "dark"));
    }
    if (strstr(buf, "light") != NULL) {
      return (int)strlen(strcpy(out, "light"));
    }
  }
  return 0;
}

/* "#rrggbb" / ""（系统没有主色概念）。GNOME 的 accent-color 是**名字**
 * （blue/teal…），查表转 hex；button-settings 里若直接写了十六进制就用它。 */
int wm_sys_accent(char *out, int cap) {
  if (out == NULL || cap < 1) {
    return 0;
  }
  out[0] = '\0';
  char buf[64];
  int n = gs_read(&gs_prefs, "button-settings", buf, (int)sizeof(buf));
  if (n > 0 && buf[0] == '#') {
    return (int)strlen(strcpy(out, buf));
  }
  if (gs_read(&gs_iface, "accent-color", buf, (int)sizeof(buf)) > 0) {
    struct Pair { const char *name; const char *hex; };
    static const struct Pair table[] = {
        { "blue", "#3584e4" },        { "teal", "#2190a4" },
        { "green", "#3a944a" },       { "yellow", "#c88800" },
        { "orange", "#ed5b00" },      { "red", "#da3450" },
        { "pink", "#d56199" },        { "purple", "#9141ac" },
        { "slate", "#6e7688" },       { "violet", "#7d6db8" },
        { "summer-blue", "#6cb5d6" }, { "forest-green", "#6d8762" },
        { "magenta", "#a1529c" },     { NULL, NULL },
    };
    for (int i = 0; table[i].name != NULL; i++) {
      if (strcmp(buf, table[i].name) == 0) {
        return (int)strlen(strcpy(out, table[i].hex));
      }
    }
  }
  return 0;
}

/* 本地时区的今天，打包成 年*10000 + 月*100 + 日（月/日 1 起始）。
 * 用日历时间 + localtime_r 走系统时区；失败返回 0，由 MoonBit 侧决定退路。 */
int64_t wm_local_date(void) {
  time_t now = time(NULL);
  struct tm tm_buf;
  if (now == (time_t)-1 || localtime_r(&now, &tm_buf) == NULL) {
    return 0;
  }
  return (int64_t)(tm_buf.tm_year + 1900) * 10000 +
         (int64_t)(tm_buf.tm_mon + 1) * 100 + (int64_t)tm_buf.tm_mday;
}

// ---------- 文件对话框（sys 线：yue/sys/dialog.mbt 的 GTK 端） ----------

#define WM_DLG_MAX 8
static GtkWidget *wm_dialogs[WM_DLG_MAX];
static int wm_dlg_accepted[WM_DLG_MAX]; // run 后用户确认过才允许取结果

static int64_t wm_dlg_put(GtkWidget *dlg) {
  for (int i = 0; i < WM_DLG_MAX; i++) {
    if (wm_dialogs[i] == NULL) {
      // 槽位号 +1 作句柄（0 保留为无效）
      wm_dialogs[i] = dlg;
      return (int64_t)(i + 1);
    }
  }
  gtk_widget_destroy(dlg);
  return 0;
}

static GtkWidget *wm_dlg_of(int64_t id) {
  if (id <= 0 || id > WM_DLG_MAX) {
    return NULL;
  }
  return wm_dialogs[id - 1];
}

static void wm_dlg_free(int64_t id) {
  if (id <= 0 || id > WM_DLG_MAX) {
    return;
  }
  wm_dlg_accepted[id - 1] = 0;
  if (wm_dialogs[id - 1] != NULL) {
    gtk_widget_destroy(wm_dialogs[id - 1]);
    wm_dialogs[id - 1] = NULL;
  }
}

/* 建 GtkFileChooserDialog：save=0 打开（OPEN）/1 保存（SAVE）。
 * 无显示连接（无头测试环境）时返回 0——句柄无效，各接口安全退化。 */
static int64_t wm_file_dialog_new(int save) {
  if (!gtk_init_check(NULL, NULL)) {
    return 0;
  }
  GtkWidget *dlg = gtk_file_chooser_dialog_new(
      save ? "保存文件" : "打开文件", NULL, save ? GTK_FILE_CHOOSER_ACTION_SAVE
                                                        : GTK_FILE_CHOOSER_ACTION_OPEN,
      "_取消", GTK_RESPONSE_CANCEL, save ? "_保存" : "_打开",
      GTK_RESPONSE_ACCEPT, NULL);
  if (dlg == NULL) {
    return 0;
  }
  return wm_dlg_put(dlg);
}

int64_t wm_file_open_dialog_new(void) { return wm_file_dialog_new(0); }

int64_t wm_file_save_dialog_new(void) { return wm_file_dialog_new(1); }

/* 选项位：1<<0 选文件夹 1<<1 多选 1<<2 显示隐藏。 */
void wm_file_dialog_set_options(int64_t id, int32_t options) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc == NULL) {
    return;
  }
  if (options & 1) {
    gtk_file_chooser_set_action(fc, GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER);
  }
  gtk_file_chooser_set_select_multiple(fc, (options & 2) != 0);
  gtk_file_chooser_set_show_hidden(fc, (options & 4) != 0);
}

/* filters 打包："描述:扩展1,扩展2|描述2:扩展3"（'*' 匹配全部）。 */
void wm_file_dialog_set_filters(int64_t id, const char *filters) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc == NULL || filters == NULL) {
    return;
  }
  // 清旧过滤器（GTK 无清空 API，逐个 remove）
  GSList *old = gtk_file_chooser_list_filters(fc);
  for (GSList *p = old; p != NULL; p = p->next) {
    gtk_file_chooser_remove_filter(fc, GTK_FILE_FILTER(p->data));
  }
  if (old != NULL) {
    g_slist_free(old);
  }
  const char *pos = filters;
  while (*pos != '\0') {
    const char *bar = strchr(pos, '|');
    size_t glen = bar != NULL ? (size_t)(bar - pos) : strlen(pos);
    char group[256];
    if (glen >= sizeof(group)) {
      glen = sizeof(group) - 1;
    }
    memcpy(group, pos, glen);
    group[glen] = '\0';
    const char *colon = strchr(group, ':');
    if (colon != NULL) {
      GtkFileFilter *f = gtk_file_filter_new();
      char desc[128];
      size_t dl = (size_t)(colon - group);
      if (dl >= sizeof(desc)) {
        dl = sizeof(desc) - 1;
      }
      memcpy(desc, group, dl);
      desc[dl] = '\0';
      gtk_file_filter_set_name(f, desc);
      const char *ep = colon + 1;
      while (*ep != '\0') {
        const char *comma = strchr(ep, ',');
        size_t el = comma != NULL ? (size_t)(comma - ep) : strlen(ep);
        char pat[64];
        if (el >= sizeof(pat)) {
          el = sizeof(pat) - 1;
        }
        memcpy(pat, ep, el);
        pat[el] = '\0';
        if (strcmp(pat, "*") == 0) {
          gtk_file_filter_add_pattern(f, "*");
        } else {
          char dotpat[68];
          snprintf(dotpat, sizeof(dotpat), "*.%s", pat);
          gtk_file_filter_add_pattern(f, dotpat);
        }
        ep = comma != NULL ? comma + 1 : ep + el;
      }
      gtk_file_chooser_add_filter(fc, f);
    }
    pos = bar != NULL ? bar + 1 : pos + glen;
  }
}

void wm_file_dialog_set_folder(int64_t id, const char *folder) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc != NULL && folder != NULL) {
    gtk_file_chooser_set_current_folder_uri(fc, folder);
  }
}

void wm_file_dialog_set_filename(int64_t id, const char *filename) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc != NULL && filename != NULL) {
    gtk_file_chooser_set_current_name(fc, filename);
  }
}

/* 模态运行：parent_id 是 wm 窗口槽 id（0 = 无父窗口）。返回 1=确认。 */
int32_t wm_file_dialog_run_for_window(int64_t id, int64_t parent_id) {
  GtkWidget *dlg = wm_dlg_of(id);
  if (dlg == NULL) {
    return 0;
  }
  GtkWidget *parent = parent_id > 0 && parent_id <= WM_MAX_WINDOWS
                          ? wm_windows[(int)parent_id - 1].window
                          : NULL;
  if (parent != NULL) {
    gtk_window_set_transient_for(GTK_WINDOW(dlg), GTK_WINDOW(parent));
  }
  gint resp = gtk_dialog_run(GTK_DIALOG(dlg));
  wm_dlg_accepted[id - 1] = resp == GTK_RESPONSE_ACCEPT;
  return resp == GTK_RESPONSE_ACCEPT ? 1 : 0;
}

/* 用户选中的路径（未确认/多选时取首个；空串 = 无）。
 * 只在 run 后用户确认过才查——未 run 的 chooser 内部文件系统模型
 * 未初始化，get_uri 会段错误（本机实测），提前返回空串。 */
void *wm_file_dialog_get_result(int64_t id) {
  GtkFileChooser *fc = GTK_FILE_CHOOSER(wm_dlg_of(id));
  if (fc == NULL || !wm_dlg_accepted[id - 1]) {
    return moonbit_make_bytes(0, 0);
  }
  gchar *uri = gtk_file_chooser_get_uri(fc);
  if (uri == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  // file:// 前缀剥除（与 master 的 FilePath 语义一致，返回本地路径）
  const char *p = uri;
  if (g_str_has_prefix(p, "file://")) {
    p += 7;
  }
  size_t len = strlen(p);
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, p, len);
  }
  g_free(uri);
  return out;
}

/* 关闭并释放对话框（run 之后调用；未 run 过也能安全释放）。 */
void wm_file_dialog_destroy(int64_t id) { wm_dlg_free(id); }
