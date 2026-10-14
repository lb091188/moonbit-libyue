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

// 视图是否还在：槽里有 view 只说明「我们建过它」。窗口拆掉时 yue/win 的 wm_close
// 会把归属本窗的子件槽整格清零、连同那棵 GtkWidget 树一起销毁，此时 v->view 是
// 悬垂指针，任何 webkit/GTK 调用都打 CRITICAL（真机：关主窗后日志 5 行）。
static int wb_view_alive(WbView *v) {
  return v != NULL && v->view != NULL &&
         wm_surface_container(v->surface_id) != NULL;
}

static WbView *wb_get(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS) {
    return NULL;
  }
  WbView *v = &wb_pool[id];
  return wb_view_alive(v) ? v : NULL;
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

// WebView2 侧才需要的 scheme 预注册（WebKit 按 context 注册，无需预处理）
void wb_predeclare_scheme(const char *scheme) { (void)scheme; }

// ---- 对外面（MoonBit 只搬 int64 与字节缓冲）----
int wb_available(void) { return 1; }

// 这个句柄的视图还在不在（窗口拆掉后一律 0）：调用方据此停泵、清待办
int wb_alive(int64_t id) { return wb_get(id) != NULL ? 1 : 0; }

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

// 焦点主动交给网页（WebView2 分支是 MoveFocus(PROGRAMMATIC)）。GTK 同树
// widget，grab_focus 即等效；焦点变化无事件透出（宿主天然可感知）。
void wb_focus(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL) {
    gtk_widget_grab_focus(GTK_WIDGET(v->view));
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
  if (wb_view_alive(v)) {
    GtkWidget *w = GTK_WIDGET(v->view);
    GtkWidget *parent = gtk_widget_get_parent(w);
    // 先摘出容器再销毁：容器可能已随窗口拆掉（父为空时 remove 会告警）
    if (parent != NULL) {
      gtk_container_remove(GTK_CONTAINER(parent), w);
    } else {
      gtk_widget_destroy(w);
    }
  }
  // 容器没了就说明视图已经随那棵窗口树一起销毁，只还自己 alloc 的东西，
  // 不再碰那个悬垂指针
  g_free(v->data_dir);
  memset(v, 0, sizeof(WbView));
}

#elif defined(WB_HAVE_WKWEBVIEW)

// ---------------- macOS 后端（WKWebView，prebuild 专编） ----------------
//
// 这一支是 Objective-C：本文件由 scripts/prebuild.py 的 Darwin 分支带
// `-DWB_HAVE_WKWEBVIEW -x objective-c -fobjc-arc` 编成 build/libyue_web_mac.a，
// 与 win 桩的归档一起经 link_flags 传入（子件容器符号 wm_surface_container 在
// win 归档里）。WebKit 是系统框架，没有 Linux 那条「发行版缺包」的退路，但形态
// 照旧：**探测 + 语义化降级**，探不到引擎时 wb_available() 给 0。
//
// 与另两平台的差异（都写进 docs/zh/adaptation.md，不静默）：
// - **kind=10 下载 / kind=9 权限请求不发**：WKWebView 到 macOS 15 才有公开的
//   下载与权限请求口（`WKDownload` / `WKUIDelegate` 的媒体授权仍只到文件面板），
//   本层不接私有 API。`wb_signal_mask()` 如实回 10（=进程终止 2 | 新窗 8）。
// - **kind=4 导航提交**由 `decidePolicyForNavigationAction`（放行那一刻）给出，
//   WebKit 侧是引擎自己的 COMMITTED 状态、Windows 侧是 ContentLoading——三家都是
//   「最接近提交」的公开口，不是同一时刻。
// - **data_dir 的持久化**：公开口是 `+[WKWebsiteDataStore dataStoreForIdentifier:]`
//   （macOS 14+，吃 UUID 而不是路径，且进程要有 bundle id）；裸二进制（本仓示例
//   的形态）拿不到，于是 `wb_persistence()` 按实际能不能兑现给 1/0，兑现不了时
//   退回 `nonPersistentDataStore`（会话不落盘，与「指定 profile 目录」的语义不合，
//   所以由探测出声而不是默默换个存储）。路径→UUID 见 wb_uuid_for_dir。
// - **wb_set_size 的像素↔点换算在这里做**：容器 NSView 的 frame 由 win 桩按
//   物理像素换好，webview 填容器要给点，所以本函数把 w/h 除以所在屏的比例。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <CoreFoundation/CoreFoundation.h>

extern void *wm_surface_container(int64_t surface_id);

// applicationNameForUserAgent 在 macOS 26 的 SDK 上不再随 WKPreferences 公开
// 声明（clang 报 no visible @interface），旧 SDK 上它是真实存在的。这里只做
// informal 声明让 selector 编译期可见，调用点先 respondsToSelector: 再发。
@interface NSObject (WMWKOptionalSetters)
- (void)setApplicationNameForUserAgent:(NSString *)name;
@end

#define WB_MAX_VIEWS 32
#define WB_EVQ 32
#define WB_EV_TEXT 768
#define WB_MAX_SCHEMES 16
#define WB_SCHEME_NAME 40
#define WB_ROOT_PATH 512
#define WB_DATA_DIR 512
#define WB_MAX_BINDINGS 16

typedef struct {
  int kind;
  int64_t num;
  char text[WB_EV_TEXT];
} WbEv;

@interface WMBSchemeHandler : NSObject <WKURLSchemeHandler> {
@public
  int wsid;
  char wscheme[WB_SCHEME_NAME];
}
@end

@interface WMBView : NSObject <WKNavigationDelegate, WKUIDelegate> {
@public
  int sid;
  int64_t surface_id;
  int new_window_in_place;
  int permission_allow;
  int download_allow;
  int crashed;
  int64_t eval_seq;
  int observing;
  WbEv evs[WB_EVQ];
  int head, count;
  WbEv last;
  char data_dir[WB_DATA_DIR];
  char scheme_name[WB_MAX_SCHEMES][WB_SCHEME_NAME];
  char scheme_root[WB_MAX_SCHEMES][WB_ROOT_PATH];
  char binding_names[WB_MAX_BINDINGS][WB_SCHEME_NAME];
}
@property(nonatomic, strong) WKWebView *view;
@property(nonatomic, strong) WKUserContentController *ucc;
// scheme handler 对象要活到视图销毁（configuration 里是弱引用语义）
@property(nonatomic, strong) NSMutableArray<WMBSchemeHandler *> *scheme_handlers;
@property(nonatomic, strong) NSMutableArray<id> *message_handlers;
@end

@interface WMBMessageHandler : NSObject <WKScriptMessageHandler> {
@public
  int msid;
}
@end

static WMBView *wb_views[WB_MAX_VIEWS];
static int wb_next_id = 1;
static char wb_predeclared[WB_MAX_SCHEMES][WB_SCHEME_NAME];
static int wb_predeclared_n = 0;
static int wb_sealed = 0;

// ---- 队列与读数 ----

static void wb_push(WMBView *v, int kind, int64_t num, const char *text) {
  if (v == nil) {
    return;
  }
  if (v->count >= WB_EVQ) {
    // 事件是提示不是账本：满了丢最旧的一条，而不是丢新的
    v->head = (v->head + 1) % WB_EVQ;
    v->count--;
  }
  int slot = (v->head + v->count) % WB_EVQ;
  v->evs[slot].kind = kind;
  v->evs[slot].num = num;
  v->evs[slot].text[0] = '\0';
  if (text != NULL) {
    strncpy(v->evs[slot].text, text, WB_EV_TEXT - 1);
    v->evs[slot].text[WB_EV_TEXT - 1] = '\0';
  }
  v->count++;
}

static WMBView *wb_get(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS) {
    return nil;
  }
  WMBView *v = wb_views[(int)id];
  if (v == nil || v.view == nil) {
    return nil;
  }
  // 容器没了就说明视图已随那棵窗口树一起拆掉（win 桩拆窗时会把子件槽整格清空）
  if (wm_surface_container(v->surface_id) == NULL) {
    return nil;
  }
  return v;
}

static int wb_copy(int64_t id, char *out, int cap, const char *src) {
  if (out == NULL || cap <= 0) {
    return 0;
  }
  if (src == NULL) {
    out[0] = '\0';
    return 0;
  }
  size_t n = strlen(src);
  if (n >= (size_t)cap) {
    n = (size_t)(cap - 1);
  }
  memcpy(out, src, n);
  out[n] = '\0';
  (void)id;
  return (int)n;
}

static NSString *wb_ns(const char *s) {
  if (s == NULL) {
    return nil;
  }
  return [[NSString alloc] initWithBytes:s
                                  length:strlen(s)
                                encoding:NSUTF8StringEncoding];
}

// ---- MIME（与 Linux/Windows 两支同一张表）----

static const char *wb_mime_of(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return "application/octet-stream";
  }
  // 文本类一律钉 utf-8：协议通道只给 MIME，引擎没别的口径可猜
  if (strcasecmp(dot, ".html") == 0 || strcasecmp(dot, ".htm") == 0) {
    return "text/html; charset=utf-8";
  }
  if (strcasecmp(dot, ".css") == 0) {
    return "text/css; charset=utf-8";
  }
  if (strcasecmp(dot, ".js") == 0 || strcasecmp(dot, ".mjs") == 0) {
    return "application/javascript; charset=utf-8";
  }
  if (strcasecmp(dot, ".json") == 0) {
    return "application/json; charset=utf-8";
  }
  if (strcasecmp(dot, ".txt") == 0) {
    return "text/plain; charset=utf-8";
  }
  if (strcasecmp(dot, ".svg") == 0) {
    return "image/svg+xml";
  }
  if (strcasecmp(dot, ".png") == 0) {
    return "image/png";
  }
  if (strcasecmp(dot, ".jpg") == 0 || strcasecmp(dot, ".jpeg") == 0) {
    return "image/jpeg";
  }
  if (strcasecmp(dot, ".gif") == 0) {
    return "image/gif";
  }
  if (strcasecmp(dot, ".woff") == 0 || strcasecmp(dot, ".woff2") == 0) {
    return "font/woff2";
  }
  return "application/octet-stream";
}

static int wb_scheme_slot(WMBView *v, const char *scheme) {
  for (int i = 0; i < WB_MAX_SCHEMES; i++) {
    if (v->scheme_name[i][0] != '\0' &&
        strcasecmp(v->scheme_name[i], scheme) == 0) {
      return i;
    }
  }
  return -1;
}

// ---- 自定义协议 ----

@implementation WMBSchemeHandler

- (void)webView:(WKWebView *)webView
    startURLSchemeTask:(id<WKURLSchemeTask>)task {
  (void)webView;
  int sid = self->wsid;
  if (sid <= 0 || sid >= WB_MAX_VIEWS || wb_views[sid] == nil) {
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-1
                                           userInfo:@{NSLocalizedDescriptionKey : @"view gone"}]];
    return;
  }
  WMBView *v = wb_views[sid];
  NSURL *url = [[task request] URL];
  NSString *path = [url path];
  if (path == nil || [path length] == 0) {
    path = @"/";
  }
  int idx = wb_scheme_slot(v, [[url scheme] UTF8String]);
  if (idx < 0) {
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-2
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"scheme unregistered"}]];
    return;
  }
  if (v->scheme_root[idx][0] == '\0') {
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-3
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"scheme unregistered"}]];
    return;
  }
  const char *p = [path UTF8String];
  if (p != NULL && strstr(p, "..") != NULL) {
    // 路径穿越：与 Linux/Windows 两支同一道闸
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-4
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"path traversal denied"}]];
    return;
  }
  char full[WB_ROOT_PATH + 4096];
  int n = snprintf(full, sizeof(full), "%s%s", v->scheme_root[idx],
                   (p != NULL && p[0] == '/') ? p : "/");
  if (n < 1 || n >= (int)sizeof(full)) {
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-5
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"path too long"}]];
    return;
  }
  FILE *f = fopen(full, "rb");
  if (f == NULL) {
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-6
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"not found"}]];
    return;
  }
  fseek(f, 0, SEEK_END);
  long size = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (size < 0) {
    fclose(f);
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-7
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"not a regular file"}]];
    return;
  }
  NSMutableData *data = [NSMutableData dataWithLength:(size_t)size];
  if (size > 0 && fread([data mutableBytes], 1, (size_t)size, f) != (size_t)size) {
    fclose(f);
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-8
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"read failed"}]];
    return;
  }
  fclose(f);
  NSString *mime = [NSString stringWithUTF8String:wb_mime_of(full)];
  NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
      initWithURL:url
         statusCode:200
        HTTPVersion:@"HTTP/1.1"
       headerFields:@{@"Content-Type" : mime,
                      @"Cache-Control" : @"no-store"}];
  if (resp == nil) {
    [task didFailWithError:[NSError errorWithDomain:@"native-gui"
                                               code:-9
                                           userInfo:@{NSLocalizedDescriptionKey
                                                          : @"response failed"}]];
    return;
  }
  [task didReceiveResponse:resp];
  [task didReceiveData:data];
  [task didFinish];
}

- (void)webView:(WKWebView *)webView
    stopURLSchemeTask:(id<WKURLSchemeTask>)task {
  (void)webView;
  (void)task; // 全同步回包：这里没有进行中的读取要取消
}

@end

// ---- 页面→原生的绑定通道（shim 把 window.<name>(payload) 变成消息）----

@implementation WMBMessageHandler

- (void)userContentController:(WKUserContentController *)ucc
      didReceiveScriptMessage:(WKScriptMessage *)message {
  (void)ucc;
  int sid = self->msid;
  if (sid <= 0 || sid >= WB_MAX_VIEWS) {
    return;
  }
  WMBView *v = wb_views[sid];
  if (v == nil || wb_get(sid) == nil) {
    return;
  }
  id body = [message body];
  NSString *text = nil;
  if ([body isKindOfClass:[NSString class]]) {
    text = (NSString *)body;
  } else {
    // 非字符串载荷按 JSON 文本给（与两支的 shim 约定一致：载荷本身就是 JSON）
    NSData *d = [NSJSONSerialization dataWithJSONObject:body
                                                options:0
                                                  error:nil];
    if (d != nil) {
      text = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    }
  }
  wb_push(v, 6, 0, text != nil ? [text UTF8String] : "");
}

@end

@implementation WMBView

- (void)dealloc {
  [self stopObserving];
}

- (void)startObserving {
  if (self->observing || self.view == nil) {
    return;
  }
  // KVO 是标题/地址变化的唯一可靠口（导航 delegate 只给「这页加载完了」）
  [self.view addObserver:self forKeyPath:@"title"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
  [self.view addObserver:self forKeyPath:@"URL"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
  self->observing = 1;
}

- (void)stopObserving {
  if (!self->observing || self.view == nil) {
    return;
  }
  @try {
    [self.view removeObserver:self forKeyPath:@"title"];
    [self.view removeObserver:self forKeyPath:@"URL"];
  } @catch (NSException *e) {
    // 重复摘除：忽略（引擎侧有时已经摘过）
    (void)e;
  }
  self->observing = 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  (void)object;
  (void)change;
  (void)context;
  WMBView *v = wb_get(self->sid);
  if (v == nil) {
    return;
  }
  if ([keyPath isEqualToString:@"title"]) {
    NSString *t = [self.view title];
    wb_push(v, 1, 0, t != nil ? [t UTF8String] : "");
  } else if ([keyPath isEqualToString:@"URL"]) {
    NSString *u = [[self.view URL] absoluteString];
    wb_push(v, 2, 0, u != nil ? [u UTF8String] : "");
  }
}

// 导航开始/提交/完成/失败
- (void)webView:(WKWebView *)webView
    didStartProvisionalNavigation:(WKNavigation *)navigation {
  (void)webView; (void)navigation;
  WMBView *v = wb_get(self->sid);
  if (v == nil) {
    return;
  }
  NSString *u = [[v.view URL] absoluteString];
  wb_push(v, 3, 0, u != nil ? [u UTF8String] : "");
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  (void)webView;
  WMBView *v = wb_get(self->sid);
  if (v != nil) {
    NSString *u = [[[navigationAction request] URL] absoluteString];
    wb_push(v, 4, 0, u != nil ? [u UTF8String] : "");
  }
  decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
  (void)webView; (void)navigation;
  WMBView *v = wb_get(self->sid);
  if (v == nil) {
    return;
  }
  NSString *u = [[v.view URL] absoluteString];
  wb_push(v, 5, 0, u != nil ? [u UTF8String] : "");
}

- (void)wb_fail:(NSError *)err {
  WMBView *v = wb_get(self->sid);
  if (v == nil || err == nil) {
    return;
  }
  NSString *u = [[v.view URL] absoluteString];
  char buf[WB_EV_TEXT];
  // 载荷四段 uri|domain|code|message（与两支同形；解析在 scheme.mbt）
  snprintf(buf, sizeof(buf), "%s|webkit|%ld|%s",
           u != nil ? [u UTF8String] : "", (long)[err code],
           [[err localizedDescription] UTF8String] ?: "");
  wb_push(v, 14, 0, buf);
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
  (void)webView; (void)navigation;
  [self wb_fail:error];
}

- (void)webView:(WKWebView *)webView
        didFailNavigation:(WKNavigation *)navigation
                withError:(NSError *)error {
  (void)webView; (void)navigation;
  [self wb_fail:error];
}

// web 进程终止：kind=11 + crashed 旗标
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
  (void)webView;
  WMBView *v = wb_views[self->sid];
  if (v == nil) {
    return;
  }
  v->crashed = 1;
  wb_push(v, 11, 0, "reason=1");
}

// 新窗请求：kind=8，再按策略丢弃或在当前 pane 里导航过去
- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)features {
  (void)configuration; (void)features;
  WMBView *v = wb_get(self->sid);
  NSString *u = [[[navigationAction request] URL] absoluteString];
  if (v != nil) {
    wb_push(v, 8, 0, u != nil ? [u UTF8String] : "");
    if (v->new_window_in_place && u != nil) {
      [v.view loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:u]]];
    }
  } else if (webView != nil && u != nil) {
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:u]]];
  }
  // WKWebView 的契约：不返回新视图时由调用方自己处理这次导航
  return nil;
}

@end

// ---- 全局探测 ----

int wb_available(void) {
  @autoreleasepool {
    return NSClassFromString(@"WKWebView") != nil ? 1 : 0;
  }
}

// 持久化能力：按目录命名会话的公开口是 `+[WKWebsiteDataStore
// dataStoreForIdentifier:]`，要 macOS 14+ **且**进程有 bundle id（裸二进制
// 拿不到），兑现不了就如实给 0——上层按「profile 参数会落空」降级。
int wb_persistence(void) {
  @autoreleasepool {
    if ([[NSBundle mainBundle] bundleIdentifier] == nil) {
      return 0;
    }
    if (@available(macOS 14.0, *)) {
      return 1;
    }
    return 0;
  }
}

// data_dir → 稳定的会话标识：那个公开口吃的是 NSUUID 而不是路径，于是从路径
// 哈希出一个固定 UUID——同一目录每次给出同一个，会话因此在多次运行之间延续。
// 哈希走 FNV-1a 两条 64 位链，拼成 RFC 4122 的版本/变体位（NSUUID 只认合法串）。
static NSUUID *wb_uuid_for_dir(const char *dir) {
  unsigned long long h1 = 0xcbf29ce484222325ULL;
  unsigned long long h2 = 0x9e3779b97f4a7c15ULL;
  for (const unsigned char *p = (const unsigned char *)dir; *p != '\0'; p++) {
    h1 = (h1 ^ (unsigned long long)*p) * 0x100000001b3ULL;
    h2 = ((h2 ^ (unsigned long long)*p) * 0x100000001b3ULL) ^ (h2 >> 29);
  }
  char s[37];
  snprintf(s, sizeof(s), "%08llx-%04llx-%04llx-%04llx-%012llx",
           (h1 >> 32) & 0xffffffffULL, (h1 >> 16) & 0xffffULL,
           0x4000ULL | (h1 & 0x0fffULL), 0x8000ULL | ((h2 >> 48) & 0x3fffULL),
           h2 & 0xffffffffffffULL);
  return [[NSUUID alloc]
      initWithUUIDString:[[NSString alloc] initWithUTF8String:s]];
}

// 给了 data_dir 时选哪个存储：平台兑现得了就按目录命名一个持久会话，
// 兑现不了给「这一会话不落盘」的独立内存存储（不落盘这件事由
// wb_persistence() 先出声，上层据此告诉用户 profile 不会持久，而不是静默
// 换成本来就在磁盘上的共享默认存储）。
static WKWebsiteDataStore *wb_store_for_dir(const char *dir) {
  if (wb_persistence() == 1 && @available(macOS 14.0, *)) {
    NSUUID *u = wb_uuid_for_dir(dir);
    if (u != nil) {
      return [WKWebsiteDataStore dataStoreForIdentifier:u];
    }
  }
  return [WKWebsiteDataStore nonPersistentDataStore];
}

// bit0 下载、bit1 进程终止、bit2 权限、bit3 新窗
int wb_signal_mask(void) {
  return 2 | 8;
}

void wb_predeclare_scheme(const char *scheme) {
  if (scheme == NULL || scheme[0] == '\0') {
    return;
  }
  if (wb_sealed) {
    return; // 封版后不再收（与 Windows 同一道闸：建视图前必须定完）
  }
  for (int i = 0; i < wb_predeclared_n; i++) {
    if (strcasecmp(wb_predeclared[i], scheme) == 0) {
      return;
    }
  }
  if (wb_predeclared_n >= WB_MAX_SCHEMES) {
    return;
  }
  strncpy(wb_predeclared[wb_predeclared_n], scheme, WB_SCHEME_NAME - 1);
  wb_predeclared[wb_predeclared_n][WB_SCHEME_NAME - 1] = '\0';
  wb_predeclared_n++;
}

// ---- 生命周期 ----

int64_t wb_create(int64_t surface_id, int w, int h, const char *uri,
                  const char *data_dir, const char *user_agent) {
  @autoreleasepool {
    if (!wb_available()) {
      return 0;
    }
    void *container = wm_surface_container(surface_id);
    if (container == NULL) {
      return 0;
    }
    NSView *host = (__bridge NSView *)container;
    if (wb_next_id >= WB_MAX_VIEWS) {
      return 0; // 池尽：句柄号不复用，与两支同一条口径
    }
    int id = wb_next_id++;
    wb_sealed = 1;
    WMBView *v = [[WMBView alloc] init];
    v->sid = id;
    v->surface_id = surface_id;
    v->download_allow = 1;
    v->new_window_in_place = 0;
    v->permission_allow = 0;

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [cfg setUserContentController:ucc];
    v.ucc = ucc;
    v.scheme_handlers = [NSMutableArray array];
    v.message_handlers = [NSMutableArray array];
    if (user_agent != NULL && user_agent[0] != '\0') {
      // applicationNameForUserAgent 是「追加在系统 UA 尾部」那一档（整串覆盖
      // 没有公开口，见 wb_set_user_agent）。新 SDK 的 WKPreferences 不再公开
      // 声明这个 setter，故按运行时能力设：设不上就是默认 UA。
      WKPreferences *prefs = [cfg preferences];
      if ([prefs respondsToSelector:@selector(setApplicationNameForUserAgent:)]) {
        [prefs setApplicationNameForUserAgent:wb_ns(user_agent)];
      }
    }
    // 自定义协议必须在建视图前挂上（引擎的硬约束，两支同一形态）
    for (int i = 0; i < wb_predeclared_n; i++) {
      WMBSchemeHandler *sh = [[WMBSchemeHandler alloc] init];
      sh->wsid = id;
      strncpy(sh->wscheme, wb_predeclared[i], WB_SCHEME_NAME - 1);
      [cfg setURLSchemeHandler:sh forURLScheme:wb_ns(wb_predeclared[i])];
      [v.scheme_handlers addObject:sh];
      int slot = i;
      if (slot < WB_MAX_SCHEMES) {
        strncpy(v->scheme_name[slot], wb_predeclared[i], WB_SCHEME_NAME - 1);
      }
    }
    // 存储：给了 data_dir 就按它选会话存储（见 wb_store_for_dir）
    if (data_dir != NULL && data_dir[0] != '\0') {
      strncpy(v->data_dir, data_dir, sizeof(v->data_dir) - 1);
      [cfg setWebsiteDataStore:wb_store_for_dir(data_dir)];
    }
    NSRect frame = [host bounds];
    if (w > 1 && h > 1) {
      CGFloat sc0 = [[NSScreen mainScreen] backingScaleFactor];
      if (sc0 <= 0) {
        sc0 = 1.0;
      }
      frame = NSMakeRect(0, 0, (CGFloat)w / sc0, (CGFloat)h / sc0);
    }
    WKWebView *view = [[WKWebView alloc] initWithFrame:frame configuration:cfg];
    if (view == nil) {
      return 0;
    }
    [view setNavigationDelegate:v];
    [view setUIDelegate:v];
    // 背景不透明由页面自己盖；这里不设 wantsLayer（引擎自带 layer-backed）
    [host addSubview:view];
    v.view = view;
    wb_views[id] = v;
    [v startObserving];
    if (uri != NULL && uri[0] != '\0') {
      NSString *u = wb_ns(uri);
      [view loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:u]]];
    } else if (uri != NULL) {
      [view loadRequest:[NSURLRequest
                            requestWithURL:[NSURL URLWithString:@"about:blank"]]];
    }
    return (int64_t)id;
  }
}

int wb_alive(int64_t id) {
  @autoreleasepool {
    return wb_get(id) != nil ? 1 : 0;
  }
}

void wb_destroy(int64_t id) {
  @autoreleasepool {
    if (id <= 0 || id >= WB_MAX_VIEWS) {
      return;
    }
    WMBView *v = wb_views[(int)id];
    if (v == nil) {
      return;
    }
    [v stopObserving];
    if (v.view != nil) {
      [v.view setNavigationDelegate:nil];
      [v.view setUIDelegate:nil];
      [v.view removeFromSuperview];
    }
    v.view = nil;
    wb_views[(int)id] = nil; // ARC 随表位清掉 ucc/handlers
  }
}

// ---- 导航 ----

void wb_load_uri(int64_t id, const char *uri) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil) {
      return;
    }
    NSString *u = (uri == NULL || uri[0] == '\0') ? @"about:blank" : wb_ns(uri);
    NSURL *url = [NSURL URLWithString:u];
    if (url != nil) {
      [v.view loadRequest:[NSURLRequest requestWithURL:url]];
    }
  }
}

void wb_load_html(int64_t id, const char *html, const char *base_uri) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil) {
      return;
    }
    NSURL *base = nil;
    if (base_uri != NULL && base_uri[0] != '\0') {
      base = [NSURL URLWithString:wb_ns(base_uri)];
    }
    if (base == nil) {
      base = [NSURL URLWithString:@"about:blank"];
    }
    // loadHTMLString 是否进前进/后退历史，Apple 无文档承诺（真机复验清单里
    // 有一条专测它；与 Linux 实测「不入历史」、Windows 明写「不改历史」对照）
    [v.view loadHTMLString:(html != NULL ? wb_ns(html) : @"") baseURL:base];
  }
}

void wb_reload(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v != nil) {
      [v.view reload];
    }
  }
}

void wb_stop(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v != nil) {
      [v.view stopLoading];
    }
  }
}

void wb_go_back(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v != nil && [v.view canGoBack]) {
      [v.view goBack];
    }
  }
}

void wb_go_forward(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v != nil && [v.view canGoForward]) {
      [v.view goForward];
    }
  }
}

int wb_can_go_back(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    return (v != nil && [v.view canGoBack]) ? 1 : 0;
  }
}

int wb_can_go_forward(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    return (v != nil && [v.view canGoForward]) ? 1 : 0;
  }
}

int wb_is_loading(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    return (v != nil && [v.view isLoading]) ? 1 : 0;
  }
}

int wb_is_crashed(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS) {
    return 0;
  }
  WMBView *v = wb_views[(int)id];
  return (v != nil && v->crashed) ? 1 : 0;
}

// ---- 读数 ----

int wb_uri(int64_t id, char *out, int cap) {
  @autoreleasepool {
    WMBView *v = wb_get(id); // 严格口径（同 Linux）：容器没了就空串
    if (v == nil) {
      return wb_copy(id, out, cap, "");
    }
    NSString *u = [[v.view URL] absoluteString];
    return wb_copy(id, out, cap, u != nil ? [u UTF8String] : "");
  }
}

int wb_title(int64_t id, char *out, int cap) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil) {
      return wb_copy(id, out, cap, "");
    }
    NSString *t = [v.view title];
    return wb_copy(id, out, cap, t != nil ? [t UTF8String] : "");
  }
}

// ---- JS 求值与页面通道 ----

int64_t wb_evaluate(int64_t wid, const char *script) {
  @autoreleasepool {
    // 形参不叫 id：ObjC 里 `id` 是类型名，函数内再拿它当变量名会把块参数表
    // 里的 `(id result, ...)` 解析成「变量声明」，整块代码报一串莫名的错。
    WMBView *v = wb_get(wid);
    if (v == nil || script == NULL) {
      return -1;
    }
    int64_t seq = ++v->eval_seq;
    int sid = v->sid;
    [v.view
        evaluateJavaScript:wb_ns(script)
         completionHandler:^(id result, NSError *error) {
           WMBView *vv = wb_get(sid);
           if (vv == nil) {
             return; // 视图已拆：回包没人收，丢弃（与两支同形态）
           }
           if (error != nil) {
             wb_push(vv, 7, seq, [[error localizedDescription] UTF8String] ?: "");
             return;
           }
           NSString *text = nil;
           if ([result isKindOfClass:[NSString class]]) {
             // 字符串结果不带引号（与 WebKit 的 jsc_value_to_string 同观感）
             text = (NSString *)result;
           } else if (result != nil &&
                      [NSJSONSerialization isValidJSONObject:result]) {
             NSData *d = [NSJSONSerialization dataWithJSONObject:result
                                                         options:0
                                                           error:nil];
             if (d != nil) {
               text = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];
             }
           } else if (result != nil) {
             text = [result description];
           }
           wb_push(vv, 7, seq, text != nil ? [text UTF8String] : "");
         }];
    return seq;
  }
}

static NSString *wb_binding_shim(const char *name) {
  // 与两支同一份 shim：把 window.<name>(payload) 变成 JSON 文本消息
  return [NSString stringWithFormat:
                        @"(function(){"
                        @"if (window['%s']) { return; }"
                        @"window['%s'] = function(payload){"
                        @"try{"
                        @"window.webkit.messageHandlers['%s'].postMessage("
                        @"JSON.stringify(payload === undefined ? null : payload));"
                        @"}catch(e){}"
                        @"};"
                        @"})();",
                        name, name, name];
}

void wb_add_user_script(int64_t id, const char *source) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil || source == NULL) {
      return;
    }
    WKUserScript *us = [[WKUserScript alloc]
           initWithSource:wb_ns(source)
            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
         forMainFrameOnly:NO];
    [v.ucc addUserScript:us];
  }
}

int wb_add_binding(int64_t id, const char *name) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil || name == NULL || name[0] == '\0') {
      return 0;
    }
    for (int i = 0; i < WB_MAX_BINDINGS; i++) {
      if (v->binding_names[i][0] != '\0' &&
          strcmp(v->binding_names[i], name) == 0) {
        return 1; // 已登记：幂等成功（shim 里也有 if(window[...]) return）
      }
    }
    int free_slot = -1;
    for (int i = 0; i < WB_MAX_BINDINGS; i++) {
      if (v->binding_names[i][0] == '\0') {
        free_slot = i;
        break;
      }
    }
    if (free_slot < 0) {
      return 0;
    }
    WMBMessageHandler *mh = [[WMBMessageHandler alloc] init];
    mh->msid = v->sid;
    @try {
      [v.ucc addScriptMessageHandler:mh name:wb_ns(name)];
    } @catch (NSException *e) {
      // 同名重复注册引擎会抛异常：按失败出声（与 Linux 的重复名返 0 同档）
      (void)e;
      return 0;
    }
    [v.message_handlers addObject:mh];
    strncpy(v->binding_names[free_slot], name, WB_SCHEME_NAME - 1);
    wb_add_user_script(id, [wb_binding_shim(name) UTF8String]);
    return 1;
  }
}

// ---- 协议注册 ----

int wb_register_scheme(int64_t id, const char *scheme, const char *root) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil || scheme == NULL || scheme[0] == '\0' || root == NULL) {
      return 0;
    }
    int idx = wb_scheme_slot(v, scheme);
    if (idx < 0) {
      for (int i = 0; i < WB_MAX_SCHEMES; i++) {
        if (v->scheme_name[i][0] == '\0') {
          idx = i;
          strncpy(v->scheme_name[i], scheme, WB_SCHEME_NAME - 1);
          break;
        }
      }
    }
    if (idx < 0) {
      return 0;
    }
    strncpy(v->scheme_root[idx], root, WB_ROOT_PATH - 1);
    v->scheme_root[idx][WB_ROOT_PATH - 1] = '\0';
    return 1;
  }
}

int wb_unregister_scheme(int64_t id, const char *scheme) {
  WMBView *v = wb_get(id);
  if (v == nil || scheme == NULL) {
    return 0;
  }
  int idx = wb_scheme_slot(v, scheme);
  if (idx < 0) {
    return 0;
  }
  v->scheme_root[idx][0] = '\0'; // 「注销」= 清空根目录（引擎无真注销口）
  return 1;
}

// ---- Cookie ----

void wb_get_cookies(int64_t id, const char *uri) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil) {
      return;
    }
    int sid = v->sid;
    WKHTTPCookieStore *store = [[v.view configuration] websiteDataStore].cookieStore;
    if (store == nil) {
      wb_push(v, 13, 1, "cookie store unavailable");
      return;
    }
    (void)uri; // 引擎给的是整站 cookie 表，不按 uri 过滤（与两支同形态）
    [store
        getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
          WMBView *vv = wb_views[sid];
          if (vv == nil) {
            return;
          }
          char buf[WB_EV_TEXT];
          int at = snprintf(buf, sizeof(buf), "[");
          if (at < 0) {
            at = 1;
          }
          for (NSUInteger i = 0; i < [cookies count]; i++) {
            NSHTTPCookie *c = cookies[i];
            const char *n = [[c name] UTF8String] ?: "";
            const char *val = [[c value] UTF8String] ?: "";
            const char *dm = [[c domain] UTF8String] ?: "";
            char item[512];
            int in = snprintf(item, sizeof(item), "%s{\"name\":\"%s\","
                              "\"value\":\"%s\",\"domain\":\"%s\"}",
                              at > 1 ? "," : "", n, val, dm);
            if (in < 0 || at + in >= (int)sizeof(buf) - 96) {
              break; // 缓冲塞不下就截到此条（与两支同一条护栏）
            }
            memcpy(buf + at, item, (size_t)in);
            at += in;
          }
          if (at < (int)sizeof(buf) - 2) {
            buf[at++] = ']';
            buf[at] = '\0';
          } else {
            buf[WB_EV_TEXT - 1] = '\0';
          }
          wb_push(vv, 13, 1, buf);
        }];
  }
}

// ---- 策略开关与摆位 ----

void wb_set_new_window_policy(int64_t id, int in_place) {
  WMBView *v = wb_get(id);
  if (v != nil) {
    v->new_window_in_place = in_place != 0 ? 1 : 0;
  }
}

void wb_set_permission_mode(int64_t id, int allow) {
  WMBView *v = wb_get(id);
  if (v != nil) {
    v->permission_allow = allow != 0 ? 1 : 0;
  }
  // macOS 没有权限请求的公开口：旗标存着，kind=9 不发（掩码如实回 bit2=0）
}

void wb_set_download_mode(int64_t id, int allow) {
  WMBView *v = wb_get(id);
  if (v != nil) {
    v->download_allow = allow != 0 ? 1 : 0;
  }
  // 同上：macOS 15 才有 WKDownload，本层不发 kind=10
}

int wb_has_download_signal(int64_t id) {
  (void)id;
  return 0;
}

int wb_has_create_signal(int64_t id) {
  return wb_get(id) != nil ? 1 : 0;
}

void wb_set_user_agent(int64_t id, const char *ua) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil || ua == NULL) {
      return;
    }
    // WKWebView 的整串 UA 覆盖没有公开口（引擎只在 configuration 阶段收
    // applicationNameForUserAgent，那是「追加在系统 UA 尾部」那一档）。
    // 建视图时给过的 user_agent 已生效；运行期再改这一支不改，
    // 缺口记 docs/zh/adaptation.md 的 macOS 差异，不接私有 setter。
    (void)v;
  }
}

void wb_focus(int64_t id) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil) {
      return;
    }
    NSWindow *win = [v.view window];
    if (win != nil) {
      [win makeFirstResponder:v.view];
    }
  }
}

void wb_set_visible(int64_t id, int visible) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v != nil) {
      [v.view setHidden:visible == 0];
    }
  }
}

void wb_set_size(int64_t id, int w, int h) {
  @autoreleasepool {
    WMBView *v = wb_get(id);
    if (v == nil) {
      return;
    }
    CGFloat sc = 1.0;
    NSScreen *sc0 = [[v.view window] screen];
    if (sc0 != nil) {
      sc = [sc0 backingScaleFactor];
      if (sc <= 0) {
        sc = 1.0;
      }
    }
    int ww = w > 1 ? w : 1;
    int hh = h > 1 ? h : 1;
    [v.view setFrame:NSMakeRect(0, 0, ww / sc, hh / sc)];
  }
}

// ---- 事件队列消费式取（next 先行，另两条读的是刚取出的那一条）----

int wb_next_event(int64_t id) {
  WMBView *v = wb_get(id);
  if (v == nil || v->count <= 0) {
    return -1;
  }
  v->last = v->evs[v->head];
  v->head = (v->head + 1) % WB_EVQ;
  v->count--;
  return v->last.kind;
}

int64_t wb_event_num(int64_t id) {
  WMBView *v = wb_get(id);
  return v == nil ? 0 : v->last.num;
}

int wb_event_text(int64_t id, char *out, int cap) {
  WMBView *v = wb_get(id);
  if (v == nil) {
    return wb_copy(id, out, cap, "");
  }
  return wb_copy(id, out, cap, v->last.text);
}

#elif !defined(__linux__) && !defined(_WIN32) && !defined(__APPLE__)

// 其余平台占位（macOS 等后端随平台批）：符号必须在，能力探测返回不可用。
// （Windows 的真实现在本包 webview2_stub.c——符号只有一份，这里必须空出。）
#include <stdint.h>

void wb_predeclare_scheme(const char *scheme) { (void)scheme; }
int wb_available(void) { return 0; }
int wb_alive(int64_t id) { (void)id; return 0; }
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
void wb_focus(int64_t id) { (void)id; }
void wb_set_visible(int64_t id, int visible) { (void)id; (void)visible; }
void wb_set_size(int64_t id, int w, int h) { (void)id; (void)w; (void)h; }
void wb_destroy(int64_t id) { (void)id; }

#endif
// Linux 上不带 -DWB_HAVE_WEBKIT 的那次编译（moon native-stub，或 prebuild 发现
// 缺 webkit 开发包时的占位编法）落不进任何分支，编出空翻译单元——真实现只由
// prebuild 的 libyue_web.a 提供，绝不能再定义一份（双定义）。
