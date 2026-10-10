// MoonBit 原生 GUI 栈 G0 探针：Linux 输入法客户端的两形态对照，不经 libyue。
//
// 模式 B（纯通道）：GtkIMContext 只当输入法客户端，文本状态在 MoonBit 只有一份；
//   组合串（preedit）与插入符由本探针按 MoonBit 推下来的状态自绘。
// 模式 C（可见覆盖）：真 GtkEntry 放进固定 22px 高的盒子里并下发 CSS 主题，
//   验两件事——原生外观能否被 CSS 压住、控件自身请求高度与外层给的尺寸是否冲突。
//
// 只依赖系统 GTK3 / Cairo / Pango。链接参数由 scripts/prebuild.py 托管
// （仓库规则：任何包的 moon.pkg 都不写链接参数）。

#include <gtk/gtk.h>
#include <gdk/gdkkeysyms.h>
#include <string.h>
#include <time.h>

// MoonBit 运行时入口：不 include moonbit.h（其 memcpy 声明与 glibc 冲突，
// 见 shim/include/yue_mbt_internal.h 文件头同样的说明），签名照抄
// ~/.moon/include/moonbit.h。
extern void *moonbit_make_bytes(int size, int value);  // 第二参是填充值

enum { MODE_CHANNEL = 0, MODE_ENTRY = 1 };

typedef struct {
  GtkWidget *window;
  GtkWidget *fixed;
  GtkWidget *area;
  GtkWidget *entry;
  GtkIMContext *im;
  PangoLayout *layout;
  PangoFontDescription *font;
  int mode;
  int closed;
  // 自绘显示状态：权威在 MoonBit，由 ip_set_display 推下来，C 只负责画。
  char text[4096];
  int text_len;
  int caret_byte;
  char preedit[1024];
  int preedit_len;
  int preedit_caret_char;
  int preedit_active;
  // 观测计数：spike 的结论全靠这几个数
  int n_filter_used;
  int n_filter_pass;
  int n_commit;
  int n_preedit_changed;
  int n_preedit_start;
  int n_preedit_end;
  int n_key_to_moonbit;
  int entry_request_h;
  int entry_alloc_h;
} Probe;

static Probe pr;

static void *bytes_of(const char *s, int len) {
  void *b = moonbit_make_bytes(len, 0);
  if (len > 0) {
    memcpy(b, s, (gsize)len);
  }
  return b;
}

// ---------- MoonBit 回调表（C 持有 invoke + closure，事件到达时调用）----------

static void (*cb_key)(void *, int, int, int, int);
static void *cb_key_cl;
static void (*cb_commit)(void *, void *);
static void *cb_commit_cl;
static void (*cb_preedit)(void *, void *, int, int);
static void *cb_preedit_cl;
static void (*cb_note)(void *, void *, void *);
static void *cb_note_cl;

void ip_on_key(void (*invoke)(void *, int, int, int, int), void *closure) {
  cb_key = invoke;
  cb_key_cl = closure;
}

void ip_on_commit(void (*invoke)(void *, void *), void *closure) {
  cb_commit = invoke;
  cb_commit_cl = closure;
}

void ip_on_preedit(void (*invoke)(void *, void *, int, int), void *closure) {
  cb_preedit = invoke;
  cb_preedit_cl = closure;
}

void ip_on_note(void (*invoke)(void *, void *, void *), void *closure) {
  cb_note = invoke;
  cb_note_cl = closure;
}

static void note(const char *tag, const char *msg) {
  g_printerr("[probe] %s: %s\n", tag, msg);
  if (cb_note != NULL) {
    void *t = bytes_of(tag, (int)strlen(tag));
    void *m = bytes_of(msg, (int)strlen(msg));
    cb_note(cb_note_cl, t, m);
  }
}

// ---------- 输入法信号 ----------

static void on_im_commit(GtkIMContext *ctx, gchar *utf8, gpointer data) {
  (void)ctx;
  (void)data;
  pr.n_commit++;
  note("commit", utf8);
  if (cb_commit != NULL) {
    cb_commit(cb_commit_cl, bytes_of(utf8, (int)strlen(utf8)));
  }
}

static void on_im_preedit_start(GtkIMContext *ctx, gpointer data) {
  (void)ctx;
  (void)data;
  pr.n_preedit_start++;
  note("preedit", "start");
}

static void on_im_preedit_end(GtkIMContext *ctx, gpointer data) {
  (void)ctx;
  (void)data;
  pr.n_preedit_end++;
  pr.preedit_active = 0;
  pr.preedit_len = 0;
  pr.preedit[0] = '\0';
  note("preedit", "end");
  if (cb_preedit != NULL) {
    cb_preedit(cb_preedit_cl, bytes_of("", 0), 0, 0);
  }
  if (pr.area != NULL) {
    gtk_widget_queue_draw(pr.area);
  }
}

static void on_im_preedit_changed(GtkIMContext *ctx, gpointer data) {
  (void)data;
  gchar *str = NULL;
  PangoAttrList *attrs = NULL;
  gint caret = 0;
  pr.n_preedit_changed++;
  gtk_im_context_get_preedit_string(ctx, &str, &attrs, &caret);
  const char *safe = str != NULL ? str : "";
  int len = (int)strlen(safe);
  if (len >= (int)sizeof(pr.preedit)) {
    len = (int)sizeof(pr.preedit) - 1;
  }
  memcpy(pr.preedit, safe, (gsize)len);
  pr.preedit[len] = '\0';
  pr.preedit_len = len;
  pr.preedit_caret_char = (int)caret;
  pr.preedit_active = len > 0 ? 1 : 0;
  if (attrs != NULL) {
    pango_attr_list_unref(attrs);
  }
  if (str != NULL) {
    g_free(str);
  }
  char buf[128];
  g_snprintf(buf, sizeof(buf), "changed bytes=%d caret_char=%d", pr.preedit_len,
             pr.preedit_caret_char);
  note("preedit", buf);
  if (cb_preedit != NULL) {
    cb_preedit(cb_preedit_cl, bytes_of(pr.preedit, pr.preedit_len),
               pr.preedit_caret_char, pr.preedit_active);
  }
  if (pr.area != NULL) {
    gtk_widget_queue_draw(pr.area);
  }
}

// ---------- 键盘：先给输入法，未消费才转 MoonBit ----------

static gboolean handle_key(GdkEventKey *ev, int is_press) {
  if (ev->type != GDK_KEY_PRESS && ev->type != GDK_KEY_RELEASE) {
    return FALSE;
  }
  if (pr.mode == MODE_CHANNEL && pr.im != NULL && is_press == 1) {
    gboolean used = gtk_im_context_filter_keypress(pr.im, ev);
    if (used) {
      pr.n_filter_used++;
      return TRUE;
    }
    pr.n_filter_pass++;
  } else if (pr.mode == MODE_ENTRY) {
    // 模式 C 下控件自己有 IME；这里只观察按键是否还会到得了我们
    pr.n_filter_pass++;
  }
  pr.n_key_to_moonbit++;
  if (cb_key != NULL) {
    cb_key(cb_key_cl, (int)ev->keyval, (int)gdk_keyval_to_unicode(ev->keyval),
           (int)ev->state, is_press);
  }
  // Escape 退出探针，方便真机操作
  if (is_press == 1 && ev->keyval == GDK_KEY_Escape) {
    pr.closed = 1;
    return TRUE;
  }
  return FALSE;
}

static void on_destroy(GtkWidget *w, gpointer data) {
  (void)w;
  (void)data;
  pr.closed = 1;
}

// GtkIMContext 的 client window 是 GdkWindow（GDK 层），必须等顶层窗口
// realize 之后才拿得到；早于 realize 传 NULL 等于没挂上输入法。
static void on_realize(GtkWidget *w, gpointer data) {
  (void)data;
  if (pr.im != NULL) {
    gtk_im_context_set_client_window(pr.im, gtk_widget_get_window(w));
    // 关键：裸 GtkIMContext 不 focus_in 就一直处于失活态，GtkIMMulticontext
    // 会落回内建 GtkIMContextSimple——表现就是"每键一次 commit、preedit 恒 0"，
    // 输入法从不接管（实测 fcitx5 即此）。这一行不能少。
    gtk_im_context_focus_in(pr.im);
    note("im-focus", "in(realize)");
  }
}

// 顶层窗口进出焦点时同步 IM 上下文的激活态；失焦必须 focus_out，
// 否则输入法侧会残留未完成的组合串（验收清单第 5 项）。
static gboolean on_window_focus_in(GtkWidget *w, GdkEventFocus *ev,
                                   gpointer data) {
  (void)w;
  (void)ev;
  (void)data;
  if (pr.im != NULL) {
    gtk_im_context_focus_in(pr.im);
    note("im-focus", "in");
  }
  return FALSE;
}

static gboolean on_window_focus_out(GtkWidget *w, GdkEventFocus *ev,
                                    gpointer data) {
  (void)w;
  (void)ev;
  (void)data;
  if (pr.im != NULL) {
    gtk_im_context_focus_out(pr.im);
    note("im-focus", "out");
  }
  return FALSE;
}

static gboolean on_key_press(GtkWidget *w, GdkEventKey *ev, gpointer data) {
  (void)w;
  (void)data;
  return handle_key(ev, 1);
}

static gboolean on_key_release(GtkWidget *w, GdkEventKey *ev, gpointer data) {
  (void)w;
  (void)data;
  return handle_key(ev, 0);
}

// ---------- 尺寸协商观测（模式 C 的关键问题）----------

static gboolean on_entry_allocate(GtkWidget *w, GdkRectangle *alloc,
                                  gpointer data) {
  (void)w;
  (void)data;
  pr.entry_alloc_h = (int)alloc->height;
  char buf[160];
  g_snprintf(buf, sizeof(buf),
             "requested_h=%d allocated_h=%d allocated_w=%d",
             pr.entry_request_h, pr.entry_alloc_h, (int)alloc->width);
  note("entry-alloc", buf);
  return FALSE;
}

// ---------- 自绘 ----------

static void draw_line(cairo_t *cr, double x, double y, const char *utf8,
                      int underline) {
  pango_layout_set_text(pr.layout, utf8, -1);
  int w = 0;
  int h = 0;
  pango_layout_get_pixel_size(pr.layout, &w, &h);
  pango_cairo_update_layout(cr, pr.layout);
  cairo_move_to(cr, x, y);
  pango_cairo_show_layout(cr, pr.layout);
  if (underline) {
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, x, y + h - 2);
    cairo_line_to(cr, x + w, y + h - 2);
    cairo_stroke(cr);
  }
}

static gboolean on_draw(GtkWidget *w, cairo_t *cr, gpointer data) {
  (void)data;
  gint area_w = gtk_widget_get_allocated_width(w);
  gint area_h = gtk_widget_get_allocated_height(w);
  cairo_set_source_rgb(cr, 0.11, 0.12, 0.14);
  cairo_rectangle(cr, 0, 0, (double)area_w, (double)area_h);
  cairo_fill(cr);

  // 我们给输入框定的盒子：240x22，由探针（未来的 yoga-mbt）说了算
  double box_x = 20.0;
  double box_y = 20.0;
  double box_w = 240.0;
  double box_h = 22.0;
  if (pr.mode == MODE_CHANNEL) {
    cairo_set_source_rgb(cr, 0.30, 0.55, 0.90);
    cairo_set_line_width(cr, 1.0);
    cairo_rectangle(cr, box_x, box_y, box_w, box_h);
    cairo_stroke(cr);
  }

  // 文本 + 组合串 + 插入符，全部按 MoonBit 推下来的状态画
  cairo_set_source_rgb(cr, 0.92, 0.93, 0.95);
  char composed[5120];
  int caret_x = 0;
  pango_font_description_set_absolute_size(pr.font, 14.0 * PANGO_SCALE);
  pango_layout_set_font_description(pr.layout, pr.font);
  // 插入符横坐标 = 光标前缀的像素宽
  if (pr.caret_byte >= 0 && pr.caret_byte <= pr.text_len) {
    char prefix[4096];
    memcpy(prefix, pr.text, (gsize)pr.caret_byte);
    prefix[pr.caret_byte] = '\0';
    pango_layout_set_text(pr.layout, prefix, -1);
    int pw = 0;
    int ph = 0;
    pango_layout_get_pixel_size(pr.layout, &pw, &ph);
    caret_x = pw;
  }
  g_snprintf(composed, sizeof(composed), "%s%s", pr.text,
             pr.preedit_active ? pr.preedit : "");
  draw_line(cr, box_x + 4.0, box_y + 2.0, composed, pr.preedit_active);
  cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
  cairo_set_line_width(cr, 1.0);
  cairo_move_to(cr, box_x + 4.0 + caret_x, box_y + 2.0);
  cairo_line_to(cr, box_x + 4.0 + caret_x, box_y + 2.0 + box_h - 4.0);
  cairo_stroke(cr);

  // 状态行
  char status[320];
  g_snprintf(status, sizeof(status),
             "mode=%s commit=%d preedit_cb=%d filter_used=%d filter_pass=%d "
             "key_to_moonbit=%d text_bytes=%d preedit_bytes=%d caret_char=%d%s",
             pr.mode == MODE_CHANNEL ? "B(纯通道)" : "C(可见 Entry)",
             pr.n_commit, pr.n_preedit_changed, pr.n_filter_used,
             pr.n_filter_pass, pr.n_key_to_moonbit, pr.text_len,
             pr.preedit_len, pr.preedit_caret_char,
             pr.mode == MODE_ENTRY && pr.entry_alloc_h > 0
                 ? " | entry got its allocation"
                 : "");
  cairo_set_source_rgb(cr, 0.55, 0.85, 0.55);
  draw_line(cr, 20.0, 60.0, status, 0);
  cairo_set_source_rgb(cr, 0.75, 0.75, 0.78);
  draw_line(cr, 20.0, 92.0,
            "Esc = 退出 | 模式 B 自绘文本与组合串 | 模式 C 看原生控件自己的显示",
            0);
  return FALSE;
}

// ---------- 对外接口 ----------

int ip_init(int mode) {
  if (!gtk_init_check(NULL, NULL)) {
    return 0;
  }
  pr.mode = mode == MODE_ENTRY ? MODE_ENTRY : MODE_CHANNEL;
  pr.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(pr.window),
                       pr.mode == MODE_ENTRY ? "ime probe C (visible GtkEntry)"
                                             : "ime probe B (GtkIMContext)");
  gtk_window_set_default_size(GTK_WINDOW(pr.window), 640, 260);
  pr.fixed = gtk_fixed_new();
  gtk_container_add(GTK_CONTAINER(pr.window), pr.fixed);
  pr.area = gtk_drawing_area_new();
  gtk_widget_set_size_request(pr.area, 640, 260);
  gtk_fixed_put(GTK_FIXED(pr.fixed), pr.area, 0, 0);
  g_signal_connect(pr.area, "draw", G_CALLBACK(on_draw), NULL);

  if (pr.mode == MODE_ENTRY) {
    pr.entry = gtk_entry_new();
    pr.entry_request_h = 22;
    gtk_widget_set_size_request(pr.entry, 240, pr.entry_request_h);
    gtk_fixed_put(GTK_FIXED(pr.fixed), pr.entry, 20, 20);
    g_signal_connect(pr.entry, "size-allocate",
                     G_CALLBACK(on_entry_allocate), NULL);
    gtk_editable_set_editable(GTK_EDITABLE(pr.entry), TRUE);
  } else {
    gtk_widget_set_can_focus(pr.area, TRUE);
    pr.im = gtk_im_multicontext_new();
    // 自绘路线必须关掉输入法客户端的自带 preedit 绘制：默认 use_preedit=TRUE
    // 时输入法会另画一份组合串浮窗，而本探针把 preedit 内联画在文本里，
    // 同一段文字就会显示两份（实测 focus_in 激活输入法之后立刻可见）。
    gtk_im_context_set_use_preedit(pr.im, FALSE);
    g_signal_connect(pr.im, "commit", G_CALLBACK(on_im_commit), NULL);
    g_signal_connect(pr.im, "preedit-start", G_CALLBACK(on_im_preedit_start),
                     NULL);
    g_signal_connect(pr.im, "preedit-changed",
                     G_CALLBACK(on_im_preedit_changed), NULL);
    g_signal_connect(pr.im, "preedit-end", G_CALLBACK(on_im_preedit_end), NULL);
    gtk_widget_grab_focus(pr.area);
  }
  g_signal_connect(pr.window, "key-press-event", G_CALLBACK(on_key_press),
                   NULL);
  g_signal_connect(pr.window, "key-release-event", G_CALLBACK(on_key_release),
                   NULL);
  g_signal_connect(pr.window, "focus-in-event", G_CALLBACK(on_window_focus_in),
                   NULL);
  g_signal_connect(pr.window, "focus-out-event",
                   G_CALLBACK(on_window_focus_out), NULL);
  g_signal_connect(pr.window, "realize", G_CALLBACK(on_realize), NULL);
  g_signal_connect(pr.window, "destroy", G_CALLBACK(on_destroy), NULL);

  pr.layout = pango_layout_new(gtk_widget_get_pango_context(pr.area));
  pr.font = pango_font_description_new();
  gtk_widget_show_all(pr.window);
  return 1;
}

// 循环单步：新栈的地基形态是自己泵主上下文，而不是把线程交给 gtk_main。
// 返回 1 表示这一拍取到了待处理事件，0 表示空转（超时）；是否退出只看
// ip_should_quit，不用这个返回值。
int ip_iterate(int blocking) {
  return g_main_context_iteration(NULL, blocking != 0) ? 1 : 0;
}

int ip_should_quit(void) {
  return pr.closed;
}

long long ip_now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (long long)ts.tv_sec * 1000LL + ts.tv_nsec / 1000000LL;
}

// MoonBit 把自己的文本状态推下来（权威只有一份）
void ip_set_display(void *text, int len, int caret_byte) {
  int n = len < 0 ? 0 : (len < (int)sizeof(pr.text) ? len
                                                    : (int)sizeof(pr.text) - 1);
  memcpy(pr.text, text, (gsize)n);
  pr.text[n] = '\0';
  pr.text_len = n;
  pr.caret_byte = caret_byte < 0 ? n : caret_byte;
  if (pr.area != NULL) {
    gtk_widget_queue_draw(pr.area);
  }
}

// 插入点矩形交给输入法（候选窗定位的关键）
void ip_set_cursor_rect(int x, int y, int w, int h) {
  if (pr.im == NULL) {
    return;
  }
  GdkRectangle rect;
  rect.x = x;
  rect.y = y;
  rect.width = w;
  rect.height = h;
  gtk_im_context_set_cursor_location(pr.im, &rect);
  char buf[96];
  g_snprintf(buf, sizeof(buf), "cursor rect pushed: %d,%d %dx%d", x, y, w, h);
  note("cursor", buf);
}

// 文本测量（未来的 measure/baseline 回调要用同一套 Pango 口径）
double ip_measure(void *text, int len) {
  char scratch[4096];
  int n = len < 0 ? 0 : (len < (int)sizeof(scratch) ? len
                                                    : (int)sizeof(scratch) - 1);
  memcpy(scratch, text, (gsize)n);
  scratch[n] = '\0';
  pango_font_description_set_absolute_size(pr.font, 14.0 * PANGO_SCALE);
  pango_layout_set_font_description(pr.layout, pr.font);
  pango_layout_set_text(pr.layout, scratch, -1);
  int w = 0;
  int h = 0;
  pango_layout_get_pixel_size(pr.layout, &w, &h);
  (void)h;
  return (double)w;
}

double ip_line_height(void) {
  pango_font_description_set_absolute_size(pr.font, 14.0 * PANGO_SCALE);
  pango_layout_set_font_description(pr.layout, pr.font);
  pango_layout_set_text(pr.layout, "M", -1);
  int w = 0;
  int h = 0;
  pango_layout_get_pixel_size(pr.layout, &w, &h);
  return (double)h;
}

// 模式 C 的关键验证：CSS 能否压住原生外观
int ip_apply_css(void *css, int len) {
  char scratch[4096];
  int n = len <= 0 ? 0 : (len < (int)sizeof(scratch) ? len
                                                     : (int)sizeof(scratch) - 1);
  memcpy(scratch, css, (gsize)n);
  scratch[n] = '\0';
  GtkCssProvider *provider = gtk_css_provider_new();
  GError *err = NULL;
  gtk_css_provider_load_from_data(provider, scratch, -1, &err);
  if (err != NULL) {
    note("css-error", err->message);
    g_error_free(err);
    g_object_unref(provider);
    return 0;
  }
  gtk_style_context_add_provider_for_screen(
      gdk_screen_get_default(), GTK_STYLE_PROVIDER(provider),
      GTK_STYLE_PROVIDER_PRIORITY_USER);
  g_object_unref(provider);
  note("css", "applied");
  return 1;
}

// 输入法模块识别：multicontext 实际加载了哪个子上下文
// multicontext 的类名恒定，真正有用的是它底下按 GTK_IM_MODULE 选到的子上下文；
// GTK3 无公开查询口，这里报类名 + 由 MoonBit 侧打印 GTK_IM_MODULE 环境变量对照。
void ip_report_im_module(void) {
  const char *env = g_getenv("GTK_IM_MODULE");
  char buf[192];
  // 模式 C 没有自建上下文（输入法挂在 GtkEntry 上），此处 pr.im 为空
  g_snprintf(buf, sizeof(buf), "class=%s GTK_IM_MODULE=%s",
             pr.im != NULL ? G_OBJECT_TYPE_NAME(pr.im) : "(挂在 Entry 上)",
             env != NULL ? env : "(unset)");
  note("im-module", buf);
}

// 观测计数按位取回（0..7），供 MoonBit 侧在退出时打印结论
int ip_counter(int idx) {
  switch (idx) {
    case 0: return pr.n_filter_used;
    case 1: return pr.n_filter_pass;
    case 2: return pr.n_commit;
    case 3: return pr.n_preedit_changed;
    case 4: return pr.n_preedit_start;
    case 5: return pr.n_preedit_end;
    case 6: return pr.n_key_to_moonbit;
    case 7: return pr.entry_alloc_h;
    default: return -1;
  }
}
