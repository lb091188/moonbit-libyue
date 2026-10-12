// yue/web 的 C 桩：把 WebKitWebView 放进窗口层给的原生子件槽里，并把引擎侧的
// 异步事件（导航、标题、JS 求值回包、页面→原生的 invoke、下载、权限、进程崩溃）
// **排成队列交给 MoonBit 消费式取**。
//
// 四条口径：
// ① **只能动态链** WebKitGTK（发行版的 webkit2gtk-4.1，自带 libsoup-3.0），运行期
//    依赖已知并接受；链接参数由 scripts/prebuild.py 全权托管（AGENTS 规则 1/2）。
// ② 分支形态照 yue/win/stub.c：prebuild 带 -DWB_HAVE_WEBKIT 专编真实现进
//    libyue_web.a；Linux 上不带该宏的那次编译落不进任何分支，编出空翻译单元，
//    于是符号只有一份。缺 webkit 开发包时 prebuild 改编「无宏」的占位分支
//    （wb_available() 返回 0），MoonBit 层按「探测 + 语义化降级」办，不是链接失败。
// ③ **C 不回调 MoonBit**：所有引擎侧事件都进 per-view 队列，MoonBit 每帧
//    `wb_next_event` 取空。这是仓库既有的消费式取事件形态（yue/win 的输入事件同
//    一套），省掉一整套蹦床与闭包生命周期问题。
// ④ webkit 侧只认槽句柄：容器指针由 yue/win 的 `wm_surface_container()` 交出
//    （C 之间传指针，MoonBit 只搬 int64），所以本包不引 yue/win 的 MoonBit 层。

#if defined(WB_HAVE_WEBKIT)

#include <fcntl.h>
#include <gtk/gtk.h>
#include <libsoup/soup-cookie.h>
#include <sys/stat.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <webkit2/webkit2.h>

// 窗口层交出的原生子件容器（实现在 yue/win 的 GTK 桩里，同一个可执行文件内链接）
extern GtkWidget *wm_surface_container(int64_t surface_id);

// ---- 事件队列 ----
// kind：1 标题 2 地址 3 导航开始 4 导航提交 5 导航完成 6 页面调用原生
//       7 JS 求值回包 8 弹窗/新窗请求 9 权限请求 10 下载 11 web 进程终止
//       12 视图请求关闭 13 cookie 回包 14 加载失败
#define WB_EVQ 32
#define WB_EV_TEXT 768

typedef struct {
  int kind;
  int64_t num;
  char text[WB_EV_TEXT];
} WbEv;

typedef struct {
  WebKitWebView *view;
  int64_t surface_id;
  char *data_dir;
  int new_window_in_place;  // 0 丢弃（默认）/ 1 在当前 pane 里导航过去
  int permission_allow;     // 0 默认拒绝 / 1 自动允许
  int download_allow;       // 0 拦下 / 1 交给引擎默认（默认允许）
  int crashed;
  int64_t eval_seq;
  WbEv evs[WB_EVQ];
  int head, count;
  WbEv last;
  // 可选信号有没有真挂上（缺一个就少一条回证，不静默）
  int has_download_signal;
  int has_terminate_signal;
  int has_permission_signal;
  int has_create_signal;
} WbView;

#define WB_MAX_VIEWS 32
static WbView wb_pool[WB_MAX_VIEWS];
static int wb_next_id = 1;

static WbView *wb_get(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_pool[id].view == NULL) {
    return NULL;
  }
  return &wb_pool[id];
}

static void wb_push(WbView *v, int kind, int64_t num, const char *text) {
  if (v == NULL) {
    return;
  }
  if (v->count == WB_EVQ) {
    // 队列满：丢最旧的一条（事件是提示不是账本，堵死会把主循环拖住）
    v->head = (v->head + 1) % WB_EVQ;
    v->count--;
  }
  int at = (v->head + v->count) % WB_EVQ;
  WbEv *e = &v->evs[at];
  e->kind = kind;
  e->num = num;
  e->text[0] = '\0';
  if (text != NULL) {
    strncpy(e->text, text, WB_EV_TEXT - 1);
    e->text[WB_EV_TEXT - 1] = '\0';
  }
  v->count++;
}

static const char *wb_view_uri(WbView *v) {
  if (v == NULL || v->view == NULL) {
    return "";
  }
  const char *u = webkit_web_view_get_uri(v->view);
  return u ? u : "";
}

static const char *wb_view_title(WbView *v) {
  if (v == NULL || v->view == NULL) {
    return "";
  }
  const char *t = webkit_web_view_get_title(v->view);
  return t ? t : "";
}

// ---- 信号处理 ----
static void wb_on_load_changed(WebKitWebView *w, WebKitLoadEvent ev,
                               gpointer data) {
  (void)w;
  WbView *v = (WbView *)data;
  int kind = 3;
  if (ev == WEBKIT_LOAD_COMMITTED) {
    kind = 4;
  } else if (ev == WEBKIT_LOAD_FINISHED) {
    kind = 5;
  } else if (ev == WEBKIT_LOAD_REDIRECTED) {
    kind = 15; // 重定向（细粒度 reason：调用方要能区分「换了地址」与「重新加载」）
  }
  wb_push(v, kind, 0, wb_view_uri(v));
}

static void wb_on_notify_title(GObject *obj, GParamSpec *ps, gpointer data) {
  (void)obj;
  (void)ps;
  WbView *v = (WbView *)data;
  wb_push(v, 1, 0, wb_view_title(v));
}

static void wb_on_notify_uri(GObject *obj, GParamSpec *ps, gpointer data) {
  (void)obj;
  (void)ps;
  WbView *v = (WbView *)data;
  wb_push(v, 2, 0, wb_view_uri(v));
}

static void wb_on_script_message(WebKitUserContentManager *m,
                                 WebKitJavascriptResult *r, gpointer data) {
  (void)m;
  WbView *v = (WbView *)data;
  JSCValue *val = webkit_javascript_result_get_js_value(r);
  char *s = val != NULL ? jsc_value_to_string(val) : NULL;
  wb_push(v, 6, 0, s ? s : "");
  g_free(s);
}

typedef struct {
  int64_t id;
  int64_t seq;
} WbReq;

static void wb_on_eval_done(GObject *src, GAsyncResult *res, gpointer data) {
  WbReq *req = (WbReq *)data;
  WbView *v = wb_get(req->id);
  if (v == NULL) {
    g_free(req);
    return;
  }
  GError *err = NULL;
  JSCValue *val =
      webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(src), res, &err);
  if (err != NULL) {
    wb_push(v, 7, req->seq, err->message);
    g_error_free(err);
  } else {
    char *s = val != NULL ? jsc_value_to_string(val) : NULL;
    wb_push(v, 7, req->seq, s ? s : "");
    g_free(s);
  }
  g_free(req);
}

static gboolean wb_on_decide_policy(WebKitWebView *w,
                                    WebKitPolicyDecision *d,
                                    WebKitPolicyDecisionType type,
                                    gpointer data) {
  (void)w;
  WbView *v = (WbView *)data;
  if (type == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) {
    WebKitNavigationPolicyDecision *nd = WEBKIT_NAVIGATION_POLICY_DECISION(d);
    WebKitNavigationAction *act =
        webkit_navigation_policy_decision_get_navigation_action(nd);
    WebKitURIRequest *req = webkit_navigation_action_get_request(act);
    wb_push(v, 8, 0, req ? webkit_uri_request_get_uri(req) : "");
    webkit_policy_decision_ignore(d);
    return TRUE;  // 已处理：不在这里开第二个视图
  }
  return FALSE;  // 其余（导航/响应）交回默认处理
}

// 权限默认拒绝：把请求报给上层（它可以在提示里给「允许」再改模式）。
// 返回 TRUE = 我们自己处理完了（引擎默认是放行，所以拒绝就是返回 TRUE）；
// 放行则显式 allow 之后同样返回 TRUE，两条路都不走默认处理器。
static gboolean wb_on_permission(WebKitWebView *w, WebKitPermissionRequest *pr,
                                 gpointer data) {
  (void)w;
  WbView *v = (WbView *)data;
  wb_push(v, 9, 0, G_OBJECT_TYPE_NAME(pr));
  if (v->permission_allow) {
    webkit_permission_request_allow(pr);
  }
  return TRUE;
}

static WebKitWebView *wb_on_create(WebKitWebView *w,
                                   WebKitNavigationAction *action,
                                   gpointer data) {
  (void)w;
  WbView *v = (WbView *)data;
  WebKitURIRequest *req = webkit_navigation_action_get_request(action);
  const char *uri = req ? webkit_uri_request_get_uri(req) : "";
  wb_push(v, 8, 0, uri);
  if (v->new_window_in_place && uri[0] != '\0') {
    webkit_web_view_load_uri(v->view, uri);
  }
  return NULL;  // 本栈不做「一窗多 webview」，弹窗一律不落成新视图
}

static void wb_on_download(WebKitWebView *w, WebKitDownload *dl, gpointer data) {
  (void)w;
  WbView *v = (WbView *)data;
  const char *dest = dl ? webkit_download_get_destination(dl) : "";
  const char *uri = "";
  if (dl != NULL) {
    WebKitURIRequest *req = webkit_download_get_request(dl);
    uri = req ? webkit_uri_request_get_uri(req) : "";
  }
  wb_push(v, 10, 0, uri);
  if (v->download_allow) {
    webkit_download_set_allow_overwrite(dl, TRUE);
  } else {
    webkit_download_cancel(dl);
  }
  (void)dest;
}

static void wb_on_terminated(WebKitWebView *w, WebKitWebProcessTerminationReason why,
                             gpointer data) {
  (void)w;
  char buf[64];
  snprintf(buf, sizeof(buf), "reason=%d", (int)why);
  WbView *v = (WbView *)data;
  v->crashed = 1;
  wb_push(v, 11, 0, buf);
}

static gboolean wb_on_close_view(WebKitWebView *w, gpointer data) {
  (void)w;
  WbView *v = (WbView *)data;
  wb_push(v, 12, 0, NULL);
  return TRUE;
}

static void wb_on_load_failed(WebKitWebView *w, WebKitLoadEvent ev,
                              const char *uri, GError *err, gpointer data) {
  (void)w;
  (void)ev;
  WbView *v = (WbView *)data;
  // 载荷口径：uri|domain|code|message（三段定长、其余全归 message——错误文本里
  // 可能有 '|'）。MoonBit 侧 nav_error_parse 按这个拆成结构。
  char buf[WB_EV_TEXT];
  snprintf(buf, sizeof(buf), "%s|%s|%d|%s", uri ? uri : "",
           err ? g_quark_to_string(err->domain) : "", err ? err->code : 0,
           err && err->message ? err->message : "");
  wb_push(v, 14, 0, buf);
}

typedef struct {
  int64_t id;
  int64_t seq;
} WbCookieReq;

static void wb_on_cookies(GObject *src, GAsyncResult *res, gpointer data) {
  WbCookieReq *req = (WbCookieReq *)data;
  WbView *v = wb_get(req->id);
  if (v == NULL) {
    g_free(req);
    return;
  }
  GError *err = NULL;
  GList *list = webkit_cookie_manager_get_cookies_finish(
      WEBKIT_COOKIE_MANAGER(src), res, &err);
  if (err != NULL) {
    wb_push(v, 13, req->seq, err->message);
    g_error_free(err);
    g_free(req);
    return;
  }
  // 结构化回包：JSON 数组，由 MoonBit 侧的零依赖 JSON 解析器读
  char out[WB_EV_TEXT];
  int at = 0;
  out[at++] = '[';
  for (GList *l = list; l != NULL && at < WB_EV_TEXT - 96; l = l->next) {
    SoupCookie *c = (SoupCookie *)l->data;
    int n = snprintf(out + at, sizeof(out) - at,
                     at == 1 ? "{\"name\":\"%s\",\"value\":\"%s\",\"domain\":\"%s\"}"
                             : ",{\"name\":\"%s\",\"value\":\"%s\",\"domain\":\"%s\"}",
                     soup_cookie_get_name(c), soup_cookie_get_value(c),
                     soup_cookie_get_domain(c));
    if (n <= 0) {
      break;
    }
    at += n;
  }
  out[at++] = ']';
  out[at] = '\0';
  wb_push(v, 13, req->seq, out);
  g_list_free_full(list, (GDestroyNotify)soup_cookie_free);
  g_free(req);
}

// ---- 自定义协议（本地内容流式回灌）----
// 三条口径：① **按 context 注册**（旧链是进程级静态注册，多 profile 之后语义不清）；
// ② 引擎**没有注销口**，所以「注销」= 把这条 scheme 的根目录清空，handler 从此
//    一律回 finish_error——比留着旧目录更安全，也比「假装能注销」诚实；
// ③ 只做「根目录下的静态文件」：路径里出现 ".." 直接拒，绝对化与逃逸都不给机会。

#define WB_MAX_SCHEMES 16
typedef struct {
  WebKitWebContext *ctx;
  char scheme[32];
  char root[512];
  int used;
} WbScheme;

static WbScheme wb_schemes[WB_MAX_SCHEMES];

static const char *wb_mime_of(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return "application/octet-stream";
  }
  // 文本类一律钉 utf-8：协议通道只给 MIME，WebKit 没有别的口径可猜，
  // 裸 "text/html" 会按 ISO-8859-1 解，中文页直接成乱码。
  if (g_ascii_strcasecmp(dot, ".html") == 0 || g_ascii_strcasecmp(dot, ".htm") == 0) {
    return "text/html; charset=utf-8";
  }
  if (g_ascii_strcasecmp(dot, ".css") == 0) {
    return "text/css; charset=utf-8";
  }
  if (g_ascii_strcasecmp(dot, ".js") == 0 || g_ascii_strcasecmp(dot, ".mjs") == 0) {
    return "application/javascript; charset=utf-8";
  }
  if (g_ascii_strcasecmp(dot, ".json") == 0) {
    return "application/json; charset=utf-8";
  }
  if (g_ascii_strcasecmp(dot, ".txt") == 0) {
    return "text/plain; charset=utf-8";
  }
  if (g_ascii_strcasecmp(dot, ".svg") == 0) {
    return "image/svg+xml";
  }
  if (g_ascii_strcasecmp(dot, ".png") == 0) {
    return "image/png";
  }
  if (g_ascii_strcasecmp(dot, ".jpg") == 0 || g_ascii_strcasecmp(dot, ".jpeg") == 0) {
    return "image/jpeg";
  }
  if (g_ascii_strcasecmp(dot, ".gif") == 0) {
    return "image/gif";
  }
  if (g_ascii_strcasecmp(dot, ".woff2") == 0) {
    return "font/woff2";
  }
  if (g_ascii_strcasecmp(dot, ".txt") == 0) {
    return "text/plain";
  }
  return "application/octet-stream";
}

static void wb_scheme_finish_error(WebKitURISchemeRequest *req, const char *msg) {
  GError *err = g_error_new_literal(WEBKIT_NETWORK_ERROR,
                                    WEBKIT_NETWORK_ERROR_FAILED, msg);
  webkit_uri_scheme_request_finish_error(req, err);
  g_error_free(err);
}

static void wb_scheme_cb(WebKitURISchemeRequest *req, gpointer user_data) {
  WbScheme *sc = (WbScheme *)user_data;
  if (sc->root[0] == '\0') {
    wb_scheme_finish_error(req, "scheme unregistered");
    return;
  }
  const char *path = webkit_uri_scheme_request_get_path(req);
  if (path == NULL) {
    path = "/";
  }
  if (strstr(path, "..") != NULL) {
    wb_scheme_finish_error(req, "path traversal denied");
    return;
  }
  char full[1100];
  snprintf(full, sizeof(full), "%s/%s", sc->root, path[0] == '/' ? path + 1 : path);
  gchar *data = NULL;
  gsize len = 0;
  GError *read_err = NULL;
  if (!g_file_get_contents(full, &data, &len, &read_err)) {
    if (read_err != NULL) {
      g_error_free(read_err);
    }
    wb_scheme_finish_error(req, "not found");
    return;
  }
  GInputStream *in = g_memory_input_stream_new_from_data(data, (gssize)len, g_free);
  webkit_uri_scheme_request_finish(req, in, (gssize)len, wb_mime_of(full));
  g_object_unref(in);
}

// 注册（或换根目录）。同一个 (context, scheme) 只向引擎注册一次。
int wb_register_scheme(int64_t id, const char *scheme, const char *root) {
  WbView *v = wb_get(id);
  if (v == NULL || scheme == NULL || scheme[0] == '\0') {
    return 0;
  }
  WebKitWebContext *ctx = webkit_web_view_get_context(v->view);
  WbScheme *slot = NULL;
  for (int i = 0; i < WB_MAX_SCHEMES; i++) {
    if (wb_schemes[i].used && wb_schemes[i].ctx == ctx &&
        g_ascii_strcasecmp(wb_schemes[i].scheme, scheme) == 0) {
      slot = &wb_schemes[i];
      break;
    }
  }
  if (slot == NULL) {
    for (int i = 0; i < WB_MAX_SCHEMES; i++) {
      if (!wb_schemes[i].used) {
        slot = &wb_schemes[i];
        slot->used = 1;
        slot->ctx = ctx;
        strncpy(slot->scheme, scheme, sizeof(slot->scheme) - 1);
        slot->scheme[sizeof(slot->scheme) - 1] = '\0';
        slot->root[0] = '\0';
        webkit_web_context_register_uri_scheme(ctx, slot->scheme, wb_scheme_cb,
                                               slot, NULL);
        break;
      }
    }
  }
  if (slot == NULL) {
    return 0;
  }
  if (root != NULL) {
    strncpy(slot->root, root, sizeof(slot->root) - 1);
    slot->root[sizeof(slot->root) - 1] = '\0';
  } else {
    slot->root[0] = '\0';
  }
  return 1;
}

// 「注销」= 清空根目录，之后这条 scheme 的请求一律回错误（引擎没有真注销口）
int wb_unregister_scheme(int64_t id, const char *scheme) {
  WbView *v = wb_get(id);
  if (v == NULL || scheme == NULL) {
    return 0;
  }
  WebKitWebContext *ctx = webkit_web_view_get_context(v->view);
  for (int i = 0; i < WB_MAX_SCHEMES; i++) {
    if (wb_schemes[i].used && wb_schemes[i].ctx == ctx &&
        g_ascii_strcasecmp(wb_schemes[i].scheme, scheme) == 0) {
      wb_schemes[i].root[0] = '\0';
      return 1;
    }
  }
  return 0;
}

// ---- 对外面（MoonBit 只搬 int64 与字节缓冲）----
int wb_available(void) { return 1; }

// 可选信号在位掩码：1 下载 2 进程终止 4 权限 8 新窗（缺哪条就少哪条回证）
int wb_signal_mask(void) {
  int m = 0;
  if (g_signal_lookup("download", WEBKIT_TYPE_WEB_VIEW) != 0) {
    m |= 1;
  }
  if (g_signal_lookup("web-process-terminated", WEBKIT_TYPE_WEB_VIEW) != 0) {
    m |= 2;
  }
  if (g_signal_lookup("permission-request", WEBKIT_TYPE_WEB_VIEW) != 0) {
    m |= 4;
  }
  if (g_signal_lookup("create", WEBKIT_TYPE_WEB_VIEW) != 0) {
    m |= 8;
  }
  return m;
}

// Linux 的持久化 profile 没有平台边界（macOS 才有「14+ 且要有 bundle id」那道坎），
// 所以这里恒给「可持久」；探测口留着，调用方不必为平台写分支。
int wb_persistence(void) { return 1; }

int64_t wb_create(int64_t surface_id, int w, int h, const char *uri,
                  const char *data_dir, const char *user_agent) {
  GtkWidget *box = wm_surface_container(surface_id);
  if (box == NULL || wb_next_id >= WB_MAX_VIEWS) {
    return 0;
  }
  WebKitWebView *view = NULL;
  char *dir = NULL;
  if (data_dir != NULL && data_dir[0] != '\0') {
    // profile 挂 pane 级：一个数据目录 = 一份会话（多账号 = 多 pane 各给各的）
    dir = g_strdup(data_dir);
    WebKitWebsiteDataManager *mgr = webkit_website_data_manager_new(
        "base-data-directory", dir, "base-cache-directory", dir, NULL);
    WebKitWebContext *ctx = webkit_web_context_new_with_website_data_manager(mgr);
    view = WEBKIT_WEB_VIEW(webkit_web_view_new_with_context(ctx));
    g_object_unref(mgr);
    g_object_unref(ctx);
  } else {
    view = WEBKIT_WEB_VIEW(
        webkit_web_view_new_with_user_content_manager(
            webkit_user_content_manager_new()));
  }
  if (user_agent != NULL && user_agent[0] != '\0') {
    webkit_settings_set_user_agent(webkit_web_view_get_settings(view),
                                   user_agent);
  }
  gtk_widget_set_size_request(GTK_WIDGET(view), w > 1 ? w : 1,
                              h > 1 ? h : 1);
  gtk_fixed_put(GTK_FIXED(box), GTK_WIDGET(view), 0, 0);
  gtk_widget_show_all(GTK_WIDGET(view));

  int id = wb_next_id++;
  WbView *v = &wb_pool[id];
  memset(v, 0, sizeof(WbView));
  v->view = view;
  v->surface_id = surface_id;
  v->data_dir = dir;
  v->download_allow = 1;

  g_signal_connect(view, "load-changed", G_CALLBACK(wb_on_load_changed), v);
  g_object_connect(view, "signal::notify::title", G_CALLBACK(wb_on_notify_title),
                   v, "signal::notify::uri", G_CALLBACK(wb_on_notify_uri), v,
                   NULL);
  g_signal_connect(view, "decide-policy", G_CALLBACK(wb_on_decide_policy), v);
  g_signal_connect(view, "load-failed", G_CALLBACK(wb_on_load_failed), v);
  g_signal_connect(view, "close", G_CALLBACK(wb_on_close_view), v);
  if (g_signal_lookup("download", WEBKIT_TYPE_WEB_VIEW) != 0) {
    g_signal_connect(view, "download", G_CALLBACK(wb_on_download), v);
    v->has_download_signal = 1;
  }
  if (g_signal_lookup("web-process-terminated", WEBKIT_TYPE_WEB_VIEW) != 0) {
    g_signal_connect(view, "web-process-terminated",
                     G_CALLBACK(wb_on_terminated), v);
    v->has_terminate_signal = 1;
  }
  if (g_signal_lookup("permission-request", WEBKIT_TYPE_WEB_VIEW) != 0) {
    g_signal_connect(view, "permission-request", G_CALLBACK(wb_on_permission), v);
    v->has_permission_signal = 1;
  }
  if (g_signal_lookup("create", WEBKIT_TYPE_WEB_VIEW) != 0) {
    g_signal_connect(view, "create", G_CALLBACK(wb_on_create), v);
    v->has_create_signal = 1;
  }
  if (uri != NULL && uri[0] != '\0') {
    webkit_web_view_load_uri(view, uri);
  }
  return (int64_t)id;
}

void wb_load_uri(int64_t id, const char *uri) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    webkit_web_view_load_uri(v->view, uri ? uri : "about:blank");
  }
}

void wb_load_html(int64_t id, const char *html, const char *base_uri) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    webkit_web_view_load_html(v->view, html ? html : "",
                              base_uri && base_uri[0] ? base_uri : "about:blank");
  }
}

void wb_reload(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    webkit_web_view_reload(v->view);
  }
}

void wb_stop(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    webkit_web_view_stop_loading(v->view);
  }
}

void wb_go_back(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    webkit_web_view_go_back(v->view);
  }
}

void wb_go_forward(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    webkit_web_view_go_forward(v->view);
  }
}

int wb_can_go_back(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL && webkit_web_view_can_go_back(v->view) ? 1 : 0;
}

int wb_can_go_forward(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL && webkit_web_view_can_go_forward(v->view) ? 1 : 0;
}

int wb_is_loading(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL && webkit_web_view_is_loading(v->view) ? 1 : 0;
}

int wb_is_crashed(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL && v->crashed ? 1 : 0;
}

// 字符串一律「C 写缓冲、MoonBit 读」（不能给 C 传可写数组）
static int wb_copy(const char *src, char *out, int cap) {
  if (out == NULL || cap <= 0) {
    return 0;
  }
  if (src == NULL) {
    out[0] = '\0';
    return 0;
  }
  strncpy(out, src, (size_t)cap - 1);
  out[cap - 1] = '\0';
  return (int)strlen(out);
}

int wb_uri(int64_t id, char *out, int cap) {
  WbView *v = wb_get(id);
  return wb_copy(v ? wb_view_uri(v) : "", out, cap);
}

int wb_title(int64_t id, char *out, int cap) {
  WbView *v = wb_get(id);
  return wb_copy(v ? wb_view_title(v) : "", out, cap);
}

// JS 求值：立刻返回请求序号，回包以 kind=7 + 同序号进队列
int64_t wb_evaluate(int64_t id, const char *script) {
  WbView *v = wb_get(id);
  if (v == NULL) {
    return -1;
  }
  v->eval_seq++;
  WbReq *req = g_new0(WbReq, 1);
  req->id = id;
  req->seq = v->eval_seq;
  webkit_web_view_evaluate_javascript(v->view, script ? script : "", -1, NULL,
                                      NULL, NULL, wb_on_eval_done, req);
  return v->eval_seq;
}

void wb_add_user_script(int64_t id, const char *source) {
  WbView *v = wb_get(id);
  if (v == NULL || source == NULL) {
    return;
  }
  WebKitUserContentManager *m = webkit_web_view_get_user_content_manager(v->view);
  WebKitUserScript *s = webkit_user_script_new(
      source, WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES,
      WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, NULL, NULL);
  webkit_user_content_manager_add_script(m, s);
  webkit_user_script_unref(s);
}

// 注册「页面 → 原生」通道：handler 名注册后，注入一段 shim 把
// window.<name>(payload) 变成 postMessage(JSON.stringify(payload))
int wb_add_binding(int64_t id, const char *name) {
  WbView *v = wb_get(id);
  if (v == NULL || name == NULL || name[0] == '\0') {
    return 0;
  }
  WebKitUserContentManager *m = webkit_web_view_get_user_content_manager(v->view);
  if (!webkit_user_content_manager_register_script_message_handler(m, name)) {
    return 0;
  }
  char sig[128];
  snprintf(sig, sizeof(sig), "script-message-received::%s", name);
  g_signal_connect(m, sig, G_CALLBACK(wb_on_script_message), v);
  char shim[1024];
  snprintf(shim, sizeof(shim),
           "(function(){if(window.%s)return;"
           "window.%s=function(p){try{window.webkit.messageHandlers.%s"
           ".postMessage(JSON.stringify(p===undefined?null:p));}"
           "catch(e){window.webkit.messageHandlers.%s.postMessage(String(e));}};"
           "})();",
           name, name, name, name);
  wb_add_user_script(id, shim);
  return 1;
}

// 取一条事件：返回 kind（-1 = 没有），字段随后用 wb_event_* 读
int wb_next_event(int64_t id) {
  WbView *v = wb_get(id);
  if (v == NULL || v->count == 0) {
    return -1;
  }
  v->last = v->evs[v->head];
  v->head = (v->head + 1) % WB_EVQ;
  v->count--;
  return v->last.kind;
}

int64_t wb_event_num(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL ? v->last.num : 0L;
}

int wb_event_text(int64_t id, char *out, int cap) {
  WbView *v = wb_get(id);
  return wb_copy(v ? v->last.text : "", out, cap);
}

void wb_set_new_window_policy(int64_t id, int in_place) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    v->new_window_in_place = in_place ? 1 : 0;
  }
}

void wb_set_permission_mode(int64_t id, int allow) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    v->permission_allow = allow ? 1 : 0;
  }
}

void wb_set_download_mode(int64_t id, int allow) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    v->download_allow = allow ? 1 : 0;
  }
}

int wb_has_download_signal(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL && v->has_download_signal ? 1 : 0;
}

int wb_has_create_signal(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL && v->has_create_signal ? 1 : 0;
}

void wb_get_cookies(int64_t id, const char *uri) {
  WbView *v = wb_get(id);
  if (v == NULL) {
    return;
  }
  WebKitCookieManager *cm =
      webkit_web_context_get_cookie_manager(webkit_web_view_get_context(v->view));
  WbCookieReq *req = g_new0(WbCookieReq, 1);
  req->id = id;
  req->seq = 1;
  webkit_cookie_manager_get_cookies(cm, uri ? uri : "", NULL, wb_on_cookies,
                                    req);
}

void wb_set_user_agent(int64_t id, const char *ua) {
  WbView *v = wb_get(id);
  if (v != NULL && ua != NULL) {
    webkit_settings_set_user_agent(webkit_web_view_get_settings(v->view), ua);
  }
}

// pane 级可见性（爬虫后台要的「不可见 webview」在窗口层，本条只管这一区）
void wb_set_visible(int64_t id, int visible) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    gtk_widget_set_visible(GTK_WIDGET(v->view), visible ? TRUE : FALSE);
  }
}

void wb_set_size(int64_t id, int w, int h) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    gtk_widget_set_size_request(GTK_WIDGET(v->view), w > 1 ? w : 1,
                                h > 1 ? h : 1);
  }
}

void wb_destroy(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_pool[id].view == NULL) {
    return;
  }
  WbView *v = &wb_pool[id];
  GtkWidget *w = GTK_WIDGET(v->view);
  GtkWidget *parent = gtk_widget_get_parent(w);
  // 先摘出容器再销毁：容器可能已随窗口拆掉（父为空时 remove 会告警）
  if (parent != NULL) {
    gtk_container_remove(GTK_CONTAINER(parent), w);
  } else {
    gtk_widget_destroy(w);
  }
  g_free(v->data_dir);
  memset(v, 0, sizeof(WbView));
}

#elif !defined(__linux__)

// 非 Linux 占位（Windows/macOS 后端随平台批）：符号必须在，能力探测返回不可用。
#include <stdint.h>

int wb_available(void) { return 0; }
int wb_persistence(void) { return 0; }
int wb_signal_mask(void) { return 0; }
int64_t wb_create(int64_t surface_id, int w, int h, const char *uri,
                  const char *data_dir, const char *user_agent) {
  (void)surface_id; (void)w; (void)h; (void)uri; (void)data_dir;
  (void)user_agent;
  return 0;
}
void wb_load_uri(int64_t id, const char *uri) { (void)id; (void)uri; }
void wb_load_html(int64_t id, const char *html, const char *base_uri) {
  (void)id; (void)html; (void)base_uri;
}
void wb_reload(int64_t id) { (void)id; }
void wb_stop(int64_t id) { (void)id; }
void wb_go_back(int64_t id) { (void)id; }
void wb_go_forward(int64_t id) { (void)id; }
int wb_can_go_back(int64_t id) { (void)id; return 0; }
int wb_can_go_forward(int64_t id) { (void)id; return 0; }
int wb_is_loading(int64_t id) { (void)id; return 0; }
int wb_is_crashed(int64_t id) { (void)id; return 0; }
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
int64_t wb_evaluate(int64_t id, const char *script) {
  (void)id; (void)script;
  return -1;
}
int wb_register_scheme(int64_t id, const char *scheme, const char *root) {
  (void)id; (void)scheme; (void)root;
  return 0;
}
int wb_unregister_scheme(int64_t id, const char *scheme) {
  (void)id; (void)scheme;
  return 0;
}
void wb_add_user_script(int64_t id, const char *source) { (void)id; (void)source; }
int wb_add_binding(int64_t id, const char *name) { (void)id; (void)name; return 0; }
int wb_next_event(int64_t id) { (void)id; return -1; }
int64_t wb_event_num(int64_t id) { (void)id; return 0; }
int wb_event_text(int64_t id, char *out, int cap) {
  (void)id;
  if (out != NULL && cap > 0) {
    out[0] = '\0';
  }
  return 0;
}
void wb_set_new_window_policy(int64_t id, int in_place) { (void)id; (void)in_place; }
void wb_set_permission_mode(int64_t id, int allow) { (void)id; (void)allow; }
void wb_set_download_mode(int64_t id, int allow) { (void)id; (void)allow; }
int wb_has_download_signal(int64_t id) { (void)id; return 0; }
int wb_has_create_signal(int64_t id) { (void)id; return 0; }
void wb_get_cookies(int64_t id, const char *uri) { (void)id; (void)uri; }
void wb_set_user_agent(int64_t id, const char *ua) { (void)id; (void)ua; }
void wb_set_visible(int64_t id, int visible) { (void)id; (void)visible; }
void wb_set_size(int64_t id, int w, int h) { (void)id; (void)w; (void)h; }
void wb_destroy(int64_t id) { (void)id; }

#endif
// Linux 上不带 -DWB_HAVE_WEBKIT 的那次编译（moon native-stub，或 prebuild 发现
// 缺 webkit 开发包时的占位编法）落不进任何分支，编出空翻译单元——真实现只由
// prebuild 的 libyue_web.a 提供，绝不能再定义一份（双定义）。
