// web 的 WebView2 桩（平台批，Windows 专属）：把 WebView2 放进窗口层给的原生子件
// 面板里，并把引擎侧的异步事件（导航、标题、地址、JS 求值回包、页面→原生的
// 消息、新窗请求、权限、下载、进程终止、关窗请求、协议拦截）**排成队列交给
// MoonBit 消费式取**——事件模型与 webkit_stub.c 的 WebKitGTK 分支同构。
//
// 四条口径（与 WebKit 分支一字不差）：
// ① **静态 Loader**：WebView2LoaderStatic.lib（MIT 的 Microsoft.Web.WebView2
//    SDK 1.0.4258.31 vendor 进本包 lib/，许可见 include/SDK-LICENSE.txt）直接
//    链进可执行文件，运行期不再分发 Loader DLL；Evergreen Runtime 在本机的
//    探测走 GetAvailableCoreWebView2BrowserVersionString。头文件相对源文件
//    路径自取（native-stub 拿不到外部 include 路径，同 win 桩 GTK 的教训）；
//    链接参数由 scripts/prebuild.py 的 Windows 分支下发。
// ② 分支形态照 webkit_stub.c：非 _WIN32 平台编出空 TU，wb_* 符号在 Windows 上
//    只有一份（本文件）；Linux 的 WebKitGTK 实现在 webkit_stub.c 的
//    WB_HAVE_WEBKIT 分支，两者互不相见。
// ③ **C 不回调 MoonBit**：所有引擎事件进 per-view 队列，MoonBit 每帧
//    wb_next_event 取空。WebView2 的 COM 事件回调本来就跑在创建线程的消息
//    循环里（win 桩的泵持续 GetMessage），与队列操作同线程，无需加锁。
// ④ 只认槽句柄：父容器由 win 桩的 `wm_surface_container()` 交出（C 之间传
//    指针，MoonBit 只搬 int64），本文件不引 win 的 MoonBit 层。
//
// 与 WebKit 分支的已知语义差异（记档）：
// - `wb_load_html` 走 NavigateToString：没有 base URI 形态，相对资源无从解析；
// - 重定向没有独立事件（WebKit 的 kind=15 不发），地址变化由 SourceChanged 覆盖；
// - `wb_is_loading` 没有同步查询，用 NavigationStarting/Completed 对账计数；
// - 环境与控制器的创建是两段异步（wb_create 返回即分配句柄，就绪前的操作
//   no-op、create 传入的 uri 在就绪后导航），失败置 dead 走 alive=0 语义降级。

#ifdef _WIN32

#include <windows.h>
#include <shlwapi.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "include/WebView2.h"

// 窗口层交出的原生子件容器（实现在 yue/win 桩的 _WIN32 分支里，同一个可执行
// 文件内链接；返回面板 HWND，窗口拆掉后悬垂——存活判定用 IsWindow）。
extern void *wm_surface_container(int64_t surface_id);

// ---- 事件队列（kind 表与 WebKit 分支共用一张）----
// kind：1 标题 2 地址 3 导航开始 4 导航提交 5 导航完成 6 页面调用原生
//       7 JS 求值回包 8 弹窗/新窗请求 9 权限请求 10 下载 11 web 进程终止
//       12 视图请求关闭 13 cookie 回包 14 加载失败（15 重定向 WebView2 无此事件）
//       16 焦点进入 17 焦点离开（WebView2 独有：跨 HWND 焦点账本，
//       WebKitGTK 是同树 widget、宿主天然可感知，不发）
#define WB_EVQ 32
#define WB_EV_TEXT 768
// JS 求值回包的专用大缓冲上限：DOM 抓取的 JSON（正文 4000 字 / 链接 200 条）
// 远超事件槽 768，回包全文存这里、事件只带序号（kind=7 的 text 恒空）
#define WB_EVAL_TEXT_MAX 65536

typedef struct {
  int kind;
  int64_t num;
  char text[WB_EV_TEXT];
} WbEv;

// 前置：事件 handler 壳（宏展开，见下）
#define WB_FWD_HND(TAG, ITF) typedef struct WbHnd_##TAG WbHnd_##TAG;

WB_FWD_HND(NavStart, ICoreWebView2NavigationStartingEventHandler)
WB_FWD_HND(ContentLoad, ICoreWebView2ContentLoadingEventHandler)
WB_FWD_HND(NavDone, ICoreWebView2NavigationCompletedEventHandler)
WB_FWD_HND(SrcChange, ICoreWebView2SourceChangedEventHandler)
WB_FWD_HND(TitleChange, ICoreWebView2DocumentTitleChangedEventHandler)
WB_FWD_HND(WebMsg, ICoreWebView2WebMessageReceivedEventHandler)
WB_FWD_HND(NewWin, ICoreWebView2NewWindowRequestedEventHandler)
WB_FWD_HND(PermReq, ICoreWebView2PermissionRequestedEventHandler)
WB_FWD_HND(DlStart, ICoreWebView2DownloadStartingEventHandler)
WB_FWD_HND(ProcFail, ICoreWebView2ProcessFailedEventHandler)
WB_FWD_HND(WinClose, ICoreWebView2WindowCloseRequestedEventHandler)
WB_FWD_HND(ResReq, ICoreWebView2WebResourceRequestedEventHandler)

typedef struct WbView WbView;

#define WB_MAX_SCHEMES 16

struct WbView {
  int64_t id;
  int64_t surface_id;
  HWND parent;         // win 桩的面板 HWND（建过就不变；存活判定 IsWindow）
  ICoreWebView2Environment *env;
  ICoreWebView2Controller *ctrl;
  ICoreWebView2 *web;
  wchar_t *data_dir;   // 挂给 Environment 的 userDataFolder（UTF-16，桩所有）
  wchar_t *ua;         // 就绪前缓存的 UA 覆盖（wb_set_user_agent 可先于就绪）
  wchar_t *pending_uri;  // create 传入或就绪前 load 的首页 uri
  wchar_t *pending_html; // 就绪前 load 的全文（优先于 pending_uri，load_html 语义）
  int dead;            // 环境/控制器创建失败（失败后一切按「视图不在」办）
  int ready;           // controller 就绪
  int loading;         // 无同步 is_loading，Starting/Completed 对账
  int crashed;
  int new_window_in_place; // 0 丢弃（默认）/ 1 在当前 pane 里导航过去
  int permission_allow;    // 0 默认拒绝 / 1 自动允许
  int download_allow;      // 0 拦下 / 1 交给引擎默认（默认允许）
  int64_t eval_seq;
  char *eval_text; // 最近一次求值回包全文（见 WB_EVAL_TEXT_MAX）
  int eval_len;
  WbEv evs[WB_EVQ];
  int head, count;
  WbEv last;
  // 焦点/滚轮跨 HWND 转发：引擎在面板 HWND 之下建自己的输入窗
  // （Chrome_WidgetWin_1）。滚轮规则按焦点窗口投递，两端各修一半：
  // ① 本桩 subclass 它——焦点在网页但鼠标不在其上时把滚轮还给宿主；
  // ② 宿主 WM_MOUSEWHEEL 分支经 wheel probe 问「该点是否在网页上」，
  //    在则转给 Chrome 窗（对齐 GTK「悬停即滚」观感）。
  HWND chrome;         // subclass 过的引擎输入窗（没找到为 NULL）
  WNDPROC chrome_orig; // 原 WndProc（还原用）
  // per-view 事件 handler（多 webview 各持各的，互不覆盖）
  void *hnd[14];
  // 就绪前后都可登记的 scheme（filter 在就绪时补挂）
  struct {
    char scheme[32];
    char root[512];
    int filter_added;
  } schemes[WB_MAX_SCHEMES];
};

#define WB_MAX_VIEWS 32
static WbView wb_pool[WB_MAX_VIEWS];
static int wb_next_id = 1;

// ---- 基础工具 ----

static int wb_view_alive(WbView *v) {
  // parent 是 create 的第一落点（没建过 = NULL = 死）；窗口拆掉后 IsWindow 变 0
  return v != NULL && v->parent != NULL && !v->dead && IsWindow(v->parent);
}

static WbView *wb_get(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS) {
    return NULL;
  }
  return wb_view_alive(&wb_pool[id]) ? &wb_pool[id] : NULL;
}

// 宽松读：只要求「create 过且未失败/未销毁」，不查面板 HWND 的死活——
// 主窗拆掉（run 返回）到 wb_destroy 之间，COM 对象仍持有、title/url/进度
// 照样可读（对齐 WebKit 分支「close 之前读数非空」的观感）。
static WbView *wb_get_keep(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS) {
    return NULL;
  }
  WbView *v = &wb_pool[id];
  return v->parent != NULL && !v->dead ? v : NULL;
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

static wchar_t *wb_utf8_to_wide(const char *s) {
  if (s == NULL) {
    return NULL;
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
  if (n <= 0) {
    return NULL;
  }
  wchar_t *w = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
  if (w == NULL) {
    return NULL;
  }
  MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
  return w;
}

static char *wb_wide_to_utf8(const wchar_t *w) {
  if (w == NULL) {
    return NULL;
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, NULL, 0, NULL, NULL);
  if (n <= 0) {
    return NULL;
  }
  char *s = (char *)malloc((size_t)n);
  if (s == NULL) {
    return NULL;
  }
  WideCharToMultiByte(CP_UTF8, 0, w, -1, s, n, NULL, NULL);
  return s;
}

// WebKit 的 JS 回包是 JSC 值转字符串（字符串结果不带引号），WebView2 的
// ExecuteScript 回包恒是 JSON 文本（字符串结果带引号）。浅去引号把两边观感
// 对齐（MoonBit 侧不感知平台差异）。
static void wb_json_unquote(char *s) {
  size_t n = strlen(s);
  if (n >= 2 && s[0] == '"' && s[n - 1] == '"') {
    memmove(s, s + 1, n - 2);
    s[n - 2] = '\0';
  }
}

static const char *wb_mime_of(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return "application/octet-stream";
  }
  if (_stricmp(dot, ".html") == 0 || _stricmp(dot, ".htm") == 0) {
    return "text/html; charset=utf-8";
  }
  if (_stricmp(dot, ".css") == 0) {
    return "text/css; charset=utf-8";
  }
  if (_stricmp(dot, ".js") == 0 || _stricmp(dot, ".mjs") == 0) {
    return "application/javascript; charset=utf-8";
  }
  if (_stricmp(dot, ".json") == 0) {
    return "application/json; charset=utf-8";
  }
  if (_stricmp(dot, ".txt") == 0) {
    return "text/plain; charset=utf-8";
  }
  if (_stricmp(dot, ".svg") == 0) {
    return "image/svg+xml";
  }
  if (_stricmp(dot, ".png") == 0) {
    return "image/png";
  }
  if (_stricmp(dot, ".jpg") == 0 || _stricmp(dot, ".jpeg") == 0) {
    return "image/jpeg";
  }
  if (_stricmp(dot, ".gif") == 0) {
    return "image/gif";
  }
  if (_stricmp(dot, ".woff") == 0) {
    return "font/woff";
  }
  if (_stricmp(dot, ".woff2") == 0) {
    return "font/woff2";
  }
  return "application/octet-stream";
}

// 从 "<scheme>://<host>/<path>?<query>" 取 root 下的完整路径；拒绝 ".."。
// 返回 0 = 不可给（未注册/已注销/路径逃逸），1 = full 可用。
static int wb_scheme_resolve(WbView *v, const char *uri, char *full,
                             size_t cap) {
  const char *colon = strchr(uri, ':');
  if (colon == NULL) {
    return 0;
  }
  size_t sl = (size_t)(colon - uri);
  if (sl == 0 || sl >= 32) {
    return 0;
  }
  char scheme[32];
  memcpy(scheme, uri, sl);
  scheme[sl] = '\0';
  for (int i = 0; i < WB_MAX_SCHEMES; i++) {
    if (v->schemes[i].scheme[0] != '\0' &&
        _stricmp(v->schemes[i].scheme, scheme) == 0) {
      if (v->schemes[i].root[0] == '\0') {
        return 0; // 已注销（root 清空）
      }
      const char *rest = colon;
      if (strncmp(rest, "://", 3) != 0) {
        return 0;
      }
      const char *path = strchr(rest + 3, '/');
      if (path == NULL) {
        path = "/";
      }
      const char *q = strchr(path, '?');
      size_t pl = q != NULL ? (size_t)(q - path) : strlen(path);
      if (strstr(path, "..") != NULL) {
        return 0; // 路径逃逸不给机会
      }
      size_t skip = path[0] == '/' ? 1 : 0;
      if (pl <= skip) {
        return 0;
      }
      _snprintf(full, cap, "%s/%.*s", v->schemes[i].root, (int)(pl - skip),
                path + skip);
      full[cap - 1] = '\0';
      return 1;
    }
  }
  return 0;
}

// ---- COM 事件 handler ----
// per-view 实例（嵌在 WbView 里，create 时绑 v），静态 vtable；Release 恒 1
//（视图与进程同寿，省一整套计数）；QI 只认自己的接口 IID 与 IUnknown。

static HRESULT STDMETHODCALLTYPE
wb_hnd_qi(IUnknown *self, REFIID riid, void **out, const IID *own) {
  (void)self;
  if (out == NULL) {
    return E_POINTER;
  }
  *out = NULL;
  if (IsEqualGUID(riid, own) || IsEqualGUID(riid, &IID_IUnknown)) {
    *out = self;
    return S_OK;
  }
  return E_NOINTERFACE;
}

// 事件族：Invoke(sender, args)——宏展开 handler 类型与 vtable，函数体随后定义。
// args 类型显式传（EventArgs 名 ≠ Handler 名加后缀，预处理拼不出来）。
#define WB_EVT_HANDLER(TAG, ITF, ARGS_ITF)                                     \
  struct WbHnd_##TAG { ITF itf; WbView *v; };                                  \
  static HRESULT STDMETHODCALLTYPE WbHnd_##TAG##_qi(                           \
      ITF *self, REFIID riid, void **out) {                                    \
    return wb_hnd_qi((IUnknown *)self, riid, out, &IID_##ITF);                 \
  }                                                                            \
  static ULONG STDMETHODCALLTYPE WbHnd_##TAG##_ref(ITF *self) {                \
    (void)self;                                                                \
    return 1;                                                                  \
  }                                                                            \
  static ULONG STDMETHODCALLTYPE WbHnd_##TAG##_rel(ITF *self) {                \
    (void)self;                                                                \
    return 1;                                                                  \
  }                                                                            \
  static HRESULT STDMETHODCALLTYPE WbHnd_##TAG##_inv(                          \
      ITF *self, ICoreWebView2 *sender, ARGS_ITF *args);                       \
  static const ITF##Vtbl WbHnd_##TAG##_vt = {                                  \
      WbHnd_##TAG##_qi, WbHnd_##TAG##_ref, WbHnd_##TAG##_rel,                  \
      WbHnd_##TAG##_inv,                                                       \
  };

WB_EVT_HANDLER(NavStart, ICoreWebView2NavigationStartingEventHandler, ICoreWebView2NavigationStartingEventArgs)
WB_EVT_HANDLER(ContentLoad, ICoreWebView2ContentLoadingEventHandler, ICoreWebView2ContentLoadingEventArgs)
WB_EVT_HANDLER(NavDone, ICoreWebView2NavigationCompletedEventHandler, ICoreWebView2NavigationCompletedEventArgs)
WB_EVT_HANDLER(SrcChange, ICoreWebView2SourceChangedEventHandler, ICoreWebView2SourceChangedEventArgs)
WB_EVT_HANDLER(TitleChange, ICoreWebView2DocumentTitleChangedEventHandler, IUnknown)
WB_EVT_HANDLER(WebMsg, ICoreWebView2WebMessageReceivedEventHandler, ICoreWebView2WebMessageReceivedEventArgs)
WB_EVT_HANDLER(NewWin, ICoreWebView2NewWindowRequestedEventHandler, ICoreWebView2NewWindowRequestedEventArgs)
WB_EVT_HANDLER(PermReq, ICoreWebView2PermissionRequestedEventHandler, ICoreWebView2PermissionRequestedEventArgs)
WB_EVT_HANDLER(DlStart, ICoreWebView2DownloadStartingEventHandler, ICoreWebView2DownloadStartingEventArgs)
WB_EVT_HANDLER(ProcFail, ICoreWebView2ProcessFailedEventHandler, ICoreWebView2ProcessFailedEventArgs)
WB_EVT_HANDLER(WinClose, ICoreWebView2WindowCloseRequestedEventHandler, IUnknown)
WB_EVT_HANDLER(ResReq, ICoreWebView2WebResourceRequestedEventHandler, ICoreWebView2WebResourceRequestedEventArgs)

// GotFocus/LostFocus 不走宏：两个坑——事件挂在 **Controller** 上（不是
// ICoreWebView2），且 Invoke 的 sender 是 ICoreWebView2Controller*（宏写死
// ICoreWebView2*，C4113 在 x64 下不止是警告）。

struct WbHnd_FocusGot {
  ICoreWebView2FocusChangedEventHandler itf;
  WbView *v;
};
static HRESULT STDMETHODCALLTYPE WbHnd_FocusGot_qi(
    ICoreWebView2FocusChangedEventHandler *self, REFIID riid, void **out) {
  return wb_hnd_qi((IUnknown *)self, riid, out,
                   &IID_ICoreWebView2FocusChangedEventHandler);
}
static ULONG STDMETHODCALLTYPE WbHnd_FocusGot_ref(
    ICoreWebView2FocusChangedEventHandler *self) {
  (void)self;
  return 1;
}
static ULONG STDMETHODCALLTYPE WbHnd_FocusGot_rel(
    ICoreWebView2FocusChangedEventHandler *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbHnd_FocusGot_inv(
    ICoreWebView2FocusChangedEventHandler *self,
    ICoreWebView2Controller *sender, IUnknown *args) {
  (void)sender;
  (void)args;
  wb_push(((struct WbHnd_FocusGot *)self)->v, 16, 0, NULL);
  return S_OK;
}
static const ICoreWebView2FocusChangedEventHandlerVtbl WbHnd_FocusGot_vt = {
    WbHnd_FocusGot_qi, WbHnd_FocusGot_ref, WbHnd_FocusGot_rel,
    WbHnd_FocusGot_inv,
};

struct WbHnd_FocusLost {
  ICoreWebView2FocusChangedEventHandler itf;
  WbView *v;
};
static HRESULT STDMETHODCALLTYPE WbHnd_FocusLost_qi(
    ICoreWebView2FocusChangedEventHandler *self, REFIID riid, void **out) {
  return wb_hnd_qi((IUnknown *)self, riid, out,
                   &IID_ICoreWebView2FocusChangedEventHandler);
}
static ULONG STDMETHODCALLTYPE WbHnd_FocusLost_ref(
    ICoreWebView2FocusChangedEventHandler *self) {
  (void)self;
  return 1;
}
static ULONG STDMETHODCALLTYPE WbHnd_FocusLost_rel(
    ICoreWebView2FocusChangedEventHandler *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbHnd_FocusLost_inv(
    ICoreWebView2FocusChangedEventHandler *self,
    ICoreWebView2Controller *sender, IUnknown *args) {
  (void)sender;
  (void)args;
  wb_push(((struct WbHnd_FocusLost *)self)->v, 17, 0, NULL);
  return S_OK;
}
static const ICoreWebView2FocusChangedEventHandlerVtbl WbHnd_FocusLost_vt = {
    WbHnd_FocusLost_qi, WbHnd_FocusLost_ref, WbHnd_FocusLost_rel,
    WbHnd_FocusLost_inv,
};

static HRESULT STDMETHODCALLTYPE WbHnd_NavStart_inv(
    ICoreWebView2NavigationStartingEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2NavigationStartingEventArgs *args) {
  (void)sender;
  WbView *v = ((struct WbHnd_NavStart *)self)->v;
  LPWSTR uri = NULL;
  if (SUCCEEDED(args->lpVtbl->get_Uri(args, &uri)) && uri != NULL) {
    char *u8 = wb_wide_to_utf8(uri);
    wb_push(v, 3, 0, u8 ? u8 : "");
    free(u8);
    CoTaskMemFree(uri);
  }
  v->loading++;
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_ContentLoad_inv(
    ICoreWebView2ContentLoadingEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2ContentLoadingEventArgs *args) {
  (void)sender;
  (void)args;
  WbView *v = ((struct WbHnd_ContentLoad *)self)->v;
  LPWSTR uri = NULL;
  if (SUCCEEDED(sender->lpVtbl->get_Source(sender, &uri)) && uri != NULL) {
    char *u8 = wb_wide_to_utf8(uri);
    wb_push(v, 4, 0, u8 ? u8 : ""); // 导航提交（WebKit 的 COMMITTED 同位）
    free(u8);
    CoTaskMemFree(uri);
  }
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_NavDone_inv(
    ICoreWebView2NavigationCompletedEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2NavigationCompletedEventArgs *args) {
  (void)sender;
  WbView *v = ((struct WbHnd_NavDone *)self)->v;
  if (v->loading > 0) {
    v->loading--;
  }
  LPWSTR uri = NULL;
  char *u8 = NULL;
  if (SUCCEEDED(sender->lpVtbl->get_Source(sender, &uri)) && uri != NULL) {
    u8 = wb_wide_to_utf8(uri);
    CoTaskMemFree(uri);
  }
  BOOL ok = FALSE;
  args->lpVtbl->get_IsSuccess(args, &ok);
  if (ok) {
    wb_push(v, 5, 0, u8 ? u8 : "");
  } else {
    // 载荷口径与 WebKit 分支同一张：uri|domain|code|message（nav_error_parse 拆）
    COREWEBVIEW2_WEB_ERROR_STATUS st = COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
    args->lpVtbl->get_WebErrorStatus(args, &st);
    char buf[WB_EV_TEXT];
    snprintf(buf, sizeof(buf), "%s|webview2|%d|navigation failed", u8 ? u8 : "",
             (int)st);
    wb_push(v, 14, 0, buf);
  }
  free(u8);
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_SrcChange_inv(
    ICoreWebView2SourceChangedEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2SourceChangedEventArgs *args) {
  (void)sender;
  (void)args;
  WbView *v = ((struct WbHnd_SrcChange *)self)->v;
  LPWSTR uri = NULL;
  if (SUCCEEDED(sender->lpVtbl->get_Source(sender, &uri)) && uri != NULL) {
    char *u8 = wb_wide_to_utf8(uri);
    wb_push(v, 2, 0, u8 ? u8 : "");
    free(u8);
    CoTaskMemFree(uri);
  }
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_TitleChange_inv(
    ICoreWebView2DocumentTitleChangedEventHandler *self, ICoreWebView2 *sender,
    IUnknown *args) {
  (void)args;
  WbView *v = ((struct WbHnd_TitleChange *)self)->v;
  LPWSTR title = NULL;
  if (SUCCEEDED(sender->lpVtbl->get_DocumentTitle(sender, &title)) &&
      title != NULL) {
    char *u8 = wb_wide_to_utf8(title);
    wb_push(v, 1, 0, u8 ? u8 : "");
    free(u8);
    CoTaskMemFree(title);
  }
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_WebMsg_inv(
    ICoreWebView2WebMessageReceivedEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2WebMessageReceivedEventArgs *args) {
  (void)sender;
  WbView *v = ((struct WbHnd_WebMsg *)self)->v;
  LPWSTR msg = NULL;
  // 页面 shim 传的是 JSON.stringify 的结果（字符串消息），取裸文本与
  // WebKit 分支的 jsc_value_to_string 同观感
  if (SUCCEEDED(args->lpVtbl->TryGetWebMessageAsString(args, &msg)) &&
      msg != NULL) {
    char *u8 = wb_wide_to_utf8(msg);
    wb_push(v, 6, 0, u8 ? u8 : "");
    free(u8);
    CoTaskMemFree(msg);
  }
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_NewWin_inv(
    ICoreWebView2NewWindowRequestedEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2NewWindowRequestedEventArgs *args) {
  WbView *v = ((struct WbHnd_NewWin *)self)->v;
  LPWSTR uri = NULL;
  char *u8 = NULL;
  if (SUCCEEDED(args->lpVtbl->get_Uri(args, &uri)) && uri != NULL) {
    u8 = wb_wide_to_utf8(uri);
    CoTaskMemFree(uri);
  }
  wb_push(v, 8, 0, u8 ? u8 : "");
  // 本栈不做「一窗多 webview」：弹窗一律拦下，in_place 时在当前 pane 里导航
  args->lpVtbl->put_Handled(args, TRUE);
  if (v->new_window_in_place && u8 != NULL && u8[0] != '\0') {
    wchar_t *w = wb_utf8_to_wide(u8);
    if (w != NULL) {
      sender->lpVtbl->Navigate(sender, w);
      free(w);
    }
  }
  free(u8);
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_PermReq_inv(
    ICoreWebView2PermissionRequestedEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2PermissionRequestedEventArgs *args) {
  (void)sender;
  WbView *v = ((struct WbHnd_PermReq *)self)->v;
  LPWSTR uri = NULL;
  if (SUCCEEDED(args->lpVtbl->get_Uri(args, &uri)) && uri != NULL) {
    char *u8 = wb_wide_to_utf8(uri);
    wb_push(v, 9, 0, u8 ? u8 : "");
    free(u8);
    CoTaskMemFree(uri);
  }
  args->lpVtbl->put_State(args, v->permission_allow
                                    ? COREWEBVIEW2_PERMISSION_STATE_ALLOW
                                    : COREWEBVIEW2_PERMISSION_STATE_DENY);
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_DlStart_inv(
    ICoreWebView2DownloadStartingEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2DownloadStartingEventArgs *args) {
  (void)sender;
  WbView *v = ((struct WbHnd_DlStart *)self)->v;
  // uri 要穿过 DownloadOperation 拿（args 上没有 get_Uri）
  ICoreWebView2DownloadOperation *op = NULL;
  if (SUCCEEDED(args->lpVtbl->get_DownloadOperation(args, &op)) &&
      op != NULL) {
    LPWSTR uri = NULL;
    if (SUCCEEDED(op->lpVtbl->get_Uri(op, &uri)) && uri != NULL) {
      char *u8 = wb_wide_to_utf8(uri);
      wb_push(v, 10, 0, u8 ? u8 : "");
      free(u8);
      CoTaskMemFree(uri);
    }
    op->lpVtbl->Release(op);
  }
  if (!v->download_allow) {
    // 拦下：Handle 住再 Cancel（不 Handle 的话默认处理器照下不误）
    args->lpVtbl->put_Handled(args, TRUE);
    args->lpVtbl->put_Cancel(args, TRUE);
  }
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_ProcFail_inv(
    ICoreWebView2ProcessFailedEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2ProcessFailedEventArgs *args) {
  (void)sender;
  WbView *v = ((struct WbHnd_ProcFail *)self)->v;
  COREWEBVIEW2_PROCESS_FAILED_KIND kind =
      COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED;
  args->lpVtbl->get_ProcessFailedKind(args, &kind);
  char buf[64];
  snprintf(buf, sizeof(buf), "reason=%d", (int)kind);
  v->crashed = 1;
  wb_push(v, 11, 0, buf);
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_WinClose_inv(
    ICoreWebView2WindowCloseRequestedEventHandler *self, ICoreWebView2 *sender,
    IUnknown *args) {
  (void)sender;
  (void)args;
  WbView *v = ((struct WbHnd_WinClose *)self)->v;
  wb_push(v, 12, 0, NULL);
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE WbHnd_ResReq_inv(
    ICoreWebView2WebResourceRequestedEventHandler *self, ICoreWebView2 *sender,
    ICoreWebView2WebResourceRequestedEventArgs *args) {
  (void)sender;
  WbView *v = ((struct WbHnd_ResReq *)self)->v;
  ICoreWebView2WebResourceRequest *req = NULL;
  ICoreWebView2WebResourceResponse *resp = NULL;
  if (FAILED(args->lpVtbl->get_Request(args, &req)) || req == NULL) {
    return S_OK;
  }
  LPWSTR wuri = NULL;
  char *uri = NULL;
  if (SUCCEEDED(req->lpVtbl->get_Uri(req, &wuri)) && wuri != NULL) {
    uri = wb_wide_to_utf8(wuri);
    CoTaskMemFree(wuri);
  }
  int status = 404;
  char ctype[128] = "";
  char full[1100] = "";
  if (uri != NULL && wb_scheme_resolve(v, uri, full, sizeof(full))) {
    HANDLE fh = CreateFileA(full, GENERIC_READ, FILE_SHARE_READ, NULL,
                            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (fh != INVALID_HANDLE_VALUE) {
      CloseHandle(fh);
      status = 200;
      _snprintf(ctype, sizeof(ctype), "Content-Type: %s", wb_mime_of(full));
      ctype[sizeof(ctype) - 1] = '\0';
    }
  }
  if (v->env != NULL) {
    if (status == 200) {
      IStream *stream = NULL;
      wchar_t *wpath = wb_utf8_to_wide(full);
      if (wpath != NULL &&
          SUCCEEDED(SHCreateStreamOnFileW(
              wpath, STGM_READ | STGM_SHARE_DENY_WRITE, &stream)) &&
          stream != NULL) {
        wchar_t *wctype = wb_utf8_to_wide(ctype);
        if (SUCCEEDED(v->env->lpVtbl->CreateWebResourceResponse(
                v->env, stream, 200, L"OK", wctype ? wctype : L"", &resp)) &&
            resp != NULL) {
          args->lpVtbl->put_Response(args, resp);
          resp->lpVtbl->Release(resp);
        }
        free(wctype);
        stream->lpVtbl->Release(stream);
      }
      free(wpath);
    } else {
      // 404 / 未注册：给个明确的空响应（不给 put_Response 会走引擎默认，
      // 自定义 scheme 没有默认处理，页面就卡在 ERR_UNKNOWN_URL_SCHEME）
      ICoreWebView2WebResourceResponse *r404 = NULL;
      if (SUCCEEDED(v->env->lpVtbl->CreateWebResourceResponse(
              v->env, NULL, 404, L"Not Found", L"", &r404)) &&
          r404 != NULL) {
        args->lpVtbl->put_Response(args, r404);
        r404->lpVtbl->Release(r404);
      }
    }
  }
  free(uri);
  req->lpVtbl->Release(req);
  return S_OK;
}

// ---- 创建链（两段异步：Environment → Controller）----
// per-view 完成回调（堆分配小结构，回调里 free——与 WebKit 分支的 WbReq 同款）

typedef struct {
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler itf;
  int64_t id;
} WbEnvReq;

typedef struct {
  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler itf;
  int64_t id;
} WbCtrlReq;

static void wb_on_ready(WbView *v);
static const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl wb_ctrl_req_vt;

static HRESULT STDMETHODCALLTYPE WbEnvReq_qi(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self,
    REFIID riid, void **out) {
  return wb_hnd_qi((IUnknown *)self, riid, out,
                   &IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler);
}
static ULONG STDMETHODCALLTYPE WbEnvReq_ref(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self) {
  (void)self;
  return 1;
}
static ULONG STDMETHODCALLTYPE WbEnvReq_rel(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbEnvReq_inv(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self,
    HRESULT errorResult, ICoreWebView2Environment *env) {
  WbEnvReq *req = (WbEnvReq *)self;
  WbView *v = &wb_pool[req->id];
  if (FAILED(errorResult) || env == NULL) {
    v->dead = 1;
    char buf[160];
    snprintf(buf, sizeof(buf),
             "|webview2|0x%08lx|webview2 runtime missing or create failed",
             (unsigned long)errorResult);
    wb_push(v, 14, 0, buf);
    free(req);
    return S_OK;
  }
  v->env = env;
  env->lpVtbl->AddRef(env);
  HWND parent = v->parent;
  WbCtrlReq *creq = (WbCtrlReq *)malloc(sizeof(WbCtrlReq));
  if (creq == NULL) {
    v->dead = 1;
    free(req);
    return S_OK;
  }
  creq->itf.lpVtbl = &wb_ctrl_req_vt;
  creq->id = req->id;
  HRESULT hr = env->lpVtbl->CreateCoreWebView2Controller(
      env, parent, &creq->itf);
  if (FAILED(hr)) {
    v->dead = 1;
    char buf[128];
    snprintf(buf, sizeof(buf), "|webview2|0x%08lx|controller create failed",
             (unsigned long)hr);
    wb_push(v, 14, 0, buf);
    free(creq);
  }
  free(req);
  return S_OK;
}
static const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl
    wb_env_req_vt = {WbEnvReq_qi, WbEnvReq_ref, WbEnvReq_rel, WbEnvReq_inv};

static HRESULT STDMETHODCALLTYPE WbCtrlReq_qi(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self,
    REFIID riid, void **out) {
  return wb_hnd_qi((IUnknown *)self, riid, out,
                   &IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler);
}
static ULONG STDMETHODCALLTYPE WbCtrlReq_ref(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self) {
  (void)self;
  return 1;
}
static ULONG STDMETHODCALLTYPE WbCtrlReq_rel(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbCtrlReq_inv(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self,
    HRESULT errorResult, ICoreWebView2Controller *ctrl) {
  WbCtrlReq *req = (WbCtrlReq *)self;
  WbView *v = &wb_pool[req->id];
  if (FAILED(errorResult) || ctrl == NULL) {
    v->dead = 1;
    char buf[128];
    snprintf(buf, sizeof(buf), "|webview2|0x%08lx|controller create failed",
             (unsigned long)errorResult);
    wb_push(v, 14, 0, buf);
    free(req);
    return S_OK;
  }
  v->ctrl = ctrl;
  ctrl->lpVtbl->AddRef(ctrl);
  ctrl->lpVtbl->get_CoreWebView2(ctrl, &v->web);
  if (v->web == NULL) {
    v->dead = 1;
    wb_push(v, 14, 0, "|webview2|0|core webview unavailable");
    free(req);
    return S_OK;
  }
  wb_on_ready(v);
  free(req);
  return S_OK;
}
static const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl
    wb_ctrl_req_vt = {WbCtrlReq_qi, WbCtrlReq_ref, WbCtrlReq_rel,
                      WbCtrlReq_inv};

// ---- 焦点/滚轮跨 HWND 转发 ----
// Windows 滚轮投递给**焦点窗口**，与鼠标位置无关；WebView2 拿焦点后宿主
// 的滚动区就断了轮。双向各修一半：
// ① chrome proc（subclass 引擎输入窗）：焦点在网页、鼠标不在网页上时，
//    把滚轮消息转回宿主主窗（GTK 按 hover 路由的观感等价物）；
// ② wb_wheel_target（宿主经 wheel probe 调）：滚轮到达宿主且鼠标悬在
//    网页上时，宿主把消息转进 Chrome 窗让网页滚。
static int wb_under_chrome(HWND h, HWND chrome) {
  for (HWND p = h; p != NULL; p = GetAncestor(p, GA_PARENT)) {
    if (p == chrome) {
      return 1;
    }
  }
  return 0;
}

static LRESULT CALLBACK wb_chrome_proc(HWND hwnd, UINT msg, WPARAM wp,
                                       LPARAM lp) {
  if (msg == WM_MOUSEWHEEL || msg == WM_MOUSEHWHEEL) {
    POINT pt;
    pt.x = (short)LOWORD(lp); // 滚轮的 lParam 是屏幕坐标
    pt.y = (short)HIWORD(lp);
    HWND chrome = (HWND)GetPropW(hwnd, L"wb_chrome_self");
    if (chrome != NULL) {
      HWND under = WindowFromPoint(pt);
      if (under == NULL || !wb_under_chrome(under, chrome)) {
        // 鼠标不在本 webview 层级内：交还宿主主窗（其滚轮分支生成滚动事件）
        HWND host = GetAncestor(chrome, GA_ROOT);
        if (host != NULL) {
          return SendMessageW(host, msg, wp, lp);
        }
      }
    }
  }
  WNDPROC orig = (WNDPROC)GetPropW(hwnd, L"wb_chrome_orig");
  return orig != NULL ? CallWindowProcW(orig, hwnd, msg, wp, lp)
                      : DefWindowProcW(hwnd, msg, wp, lp);
}

// 在面板 HWND 下找引擎输入窗（Chrome_WidgetWin_1；找不到不算错——
// 类名是引擎实现细节，找不到只是少一半转发）
static HWND wb_find_chrome(HWND parent) {
  HWND it = NULL;
  while ((it = FindWindowExW(parent, it, NULL, NULL)) != NULL) {
    wchar_t cls[64];
    if (GetClassNameW(it, cls, 64) > 0 &&
        lstrcmpW(cls, L"Chrome_WidgetWin_1") == 0) {
      return it;
    }
  }
  return NULL;
}

static void wb_subclass_chrome(WbView *v) {
  HWND chrome = wb_find_chrome(v->parent);
  if (chrome == NULL || GetPropW(chrome, L"wb_chrome_orig") != NULL) {
    return; // 没找到，或已 subclass 过（重复 create 同一面板的防重）
  }
  WNDPROC orig =
      (WNDPROC)SetWindowLongPtrW(chrome, GWLP_WNDPROC, (LONG_PTR)wb_chrome_proc);
  if (orig != NULL) {
    SetPropW(chrome, L"wb_chrome_orig", (HANDLE)orig);
    SetPropW(chrome, L"wb_chrome_self", (HANDLE)chrome);
    v->chrome = chrome;
    v->chrome_orig = orig;
  }
}

static void wb_unsubclass_chrome(WbView *v) {
  if (v->chrome != NULL && IsWindow(v->chrome) && v->chrome_orig != NULL) {
    SetWindowLongPtrW(v->chrome, GWLP_WNDPROC, (LONG_PTR)v->chrome_orig);
    RemovePropW(v->chrome, L"wb_chrome_orig");
    RemovePropW(v->chrome, L"wb_chrome_self");
  }
  v->chrome = NULL;
  v->chrome_orig = NULL;
}

// 宿主滚轮分支的探针：给定屏幕坐标，返回该点应处理的 Chrome 窗
// （0 = 不在网页上，宿主自己处理）。经 win 桩的函数指针槽注册，
// 避免 win→web 反向符号依赖（不用 web 包的 app 链接不到 wb_* 符号）。
static int64_t wb_wheel_target(int64_t sx, int64_t sy) {
  POINT pt;
  pt.x = (LONG)sx;
  pt.y = (LONG)sy;
  HWND under = WindowFromPoint(pt);
  if (under == NULL) {
    return 0;
  }
  for (int i = 1; i < WB_MAX_VIEWS; i++) {
    WbView *v = &wb_pool[i];
    if (v->chrome != NULL && wb_under_chrome(under, v->chrome)) {
      return (int64_t)(intptr_t)v->chrome;
    }
  }
  return 0;
}

extern void wm_set_wheel_probe(int64_t (*fn)(int64_t sx, int64_t sy));

// 就绪：挂全部事件、补挂 scheme filter、应用缓存的 UA、可见 + bounds、导航首页
static void wb_on_ready(WbView *v) {
  ICoreWebView2 *w = v->web;
  EventRegistrationToken tok;
  // handler 实例都是栈外静态？不行——per-view。这里从 WbView 的 hnd[] 取
  w->lpVtbl->add_NavigationStarting(w, (ICoreWebView2NavigationStartingEventHandler *)v->hnd[0], &tok);
  w->lpVtbl->add_ContentLoading(w, (ICoreWebView2ContentLoadingEventHandler *)v->hnd[1], &tok);
  w->lpVtbl->add_NavigationCompleted(w, (ICoreWebView2NavigationCompletedEventHandler *)v->hnd[2], &tok);
  w->lpVtbl->add_SourceChanged(w, (ICoreWebView2SourceChangedEventHandler *)v->hnd[3], &tok);
  w->lpVtbl->add_DocumentTitleChanged(w, (ICoreWebView2DocumentTitleChangedEventHandler *)v->hnd[4], &tok);
  w->lpVtbl->add_WebMessageReceived(w, (ICoreWebView2WebMessageReceivedEventHandler *)v->hnd[5], &tok);
  w->lpVtbl->add_NewWindowRequested(w, (ICoreWebView2NewWindowRequestedEventHandler *)v->hnd[6], &tok);
  w->lpVtbl->add_PermissionRequested(w, (ICoreWebView2PermissionRequestedEventHandler *)v->hnd[7], &tok);
  {
    ICoreWebView2_4 *w4 = NULL;
    if (SUCCEEDED(w->lpVtbl->QueryInterface(w, &IID_ICoreWebView2_4, (void **)&w4)) && w4 != NULL) {
      w4->lpVtbl->add_DownloadStarting(w4, (ICoreWebView2DownloadStartingEventHandler *)v->hnd[8], &tok);
      w4->lpVtbl->Release(w4);
    }
  }
  w->lpVtbl->add_ProcessFailed(w, (ICoreWebView2ProcessFailedEventHandler *)v->hnd[9], &tok);
  w->lpVtbl->add_WindowCloseRequested(w, (ICoreWebView2WindowCloseRequestedEventHandler *)v->hnd[10], &tok);
  w->lpVtbl->add_WebResourceRequested(w, (ICoreWebView2WebResourceRequestedEventHandler *)v->hnd[11], &tok);
  // 焦点事件在 Controller 上（ICoreWebView2 没有 add_GotFocus/LostFocus）
  v->ctrl->lpVtbl->add_GotFocus(v->ctrl, (ICoreWebView2FocusChangedEventHandler *)v->hnd[12], &tok);
  v->ctrl->lpVtbl->add_LostFocus(v->ctrl, (ICoreWebView2FocusChangedEventHandler *)v->hnd[13], &tok);

  for (int i = 0; i < WB_MAX_SCHEMES; i++) {
    if (v->schemes[i].scheme[0] != '\0' && !v->schemes[i].filter_added) {
      char filter[48];
      _snprintf(filter, sizeof(filter), "%s://*/*", v->schemes[i].scheme);
      filter[sizeof(filter) - 1] = '\0';
      wchar_t *wf = wb_utf8_to_wide(filter);
      if (wf != NULL) {
        HRESULT fhr = w->lpVtbl->AddWebResourceRequestedFilter(
            w, wf, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
        free(wf);
        v->schemes[i].filter_added = 1;
      }
    }
  }

  if (v->ua != NULL) {
    ICoreWebView2Settings *st = NULL;
    if (SUCCEEDED(w->lpVtbl->get_Settings(w, &st)) && st != NULL) {
      ICoreWebView2Settings2 *st2 = NULL;
      if (SUCCEEDED(st->lpVtbl->QueryInterface(st, &IID_ICoreWebView2Settings2, (void **)&st2)) && st2 != NULL) {
        st2->lpVtbl->put_UserAgent(st2, v->ua);
        st2->lpVtbl->Release(st2);
      }
      st->lpVtbl->Release(st);
    }
  }

  v->ctrl->lpVtbl->put_IsVisible(v->ctrl, TRUE);
  RECT rc;
  GetClientRect(v->parent, &rc);
  v->ctrl->lpVtbl->put_Bounds(v->ctrl, rc);
  wb_subclass_chrome(v); // 引擎输入窗此时已在（controller 创建同步完成）
  v->ready = 1;
  if (v->pending_html != NULL) {
    w->lpVtbl->NavigateToString(w, v->pending_html);
    free(v->pending_html);
    v->pending_html = NULL;
  } else if (v->pending_uri != NULL) {
    w->lpVtbl->Navigate(w, v->pending_uri);
    free(v->pending_uri);
    v->pending_uri = NULL;
  }
}


// ---- 自定义 scheme 的 Environment 预注册（平台批）----
// WebView2 不认没预注册的自定义 scheme：导航直接失败（真机实测失败码 9）。
// MoonBit 层 webview_predeclare_schemes 的名单经 wb_predeclare_scheme 流进
// 这里，Environment 创建时经 EnvironmentOptions4::SetCustomSchemeRegistrations
// 交给引擎。Options 单实例四子接口嵌套（QI 按偏移分派）、进程级复用（名单
// 封版后不变），属性全默认——唯一要真给的是 TargetCompatibleBrowserVersion
//（与 vendor 的 SDK 同版）。

#define WB_TARGET_VERSION L"154.0.4258.31"

static wchar_t *wb_predeclared[WB_MAX_SCHEMES];
static int wb_predeclared_n = 0;

void wb_predeclare_scheme(const char *scheme) {
  if (scheme == NULL || scheme[0] == '\0' || wb_predeclared_n >= WB_MAX_SCHEMES) {
    return;
  }
  // 去重（大小写不敏感，与引擎口径一致）
  wchar_t *w = wb_utf8_to_wide(scheme);
  if (w == NULL) {
    return;
  }
  for (int i = 0; i < wb_predeclared_n; i++) {
    if (_wcsicmp(wb_predeclared[i], w) == 0) {
      free(w);
      return;
    }
  }
  wb_predeclared[wb_predeclared_n++] = w;
}

// ---- CustomSchemeRegistration（每条 scheme 一个，进程级缓存）----

typedef struct {
  ICoreWebView2CustomSchemeRegistration itf;
  wchar_t *name;
} WbReg;

static WbReg *wb_regs[WB_MAX_SCHEMES];
static int wb_regs_n = 0;

static HRESULT STDMETHODCALLTYPE WbReg_qi(
    ICoreWebView2CustomSchemeRegistration *self, REFIID riid, void **out) {
  return wb_hnd_qi((IUnknown *)self, riid, out,
                   &IID_ICoreWebView2CustomSchemeRegistration);
}
static ULONG STDMETHODCALLTYPE WbReg_ref(
    ICoreWebView2CustomSchemeRegistration *self) {
  (void)self;
  return 1; // 进程级缓存不真释放
}
static ULONG STDMETHODCALLTYPE WbReg_rel(
    ICoreWebView2CustomSchemeRegistration *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbReg_get_name(
    ICoreWebView2CustomSchemeRegistration *self, LPWSTR *value) {
  WbReg *r = (WbReg *)self;
  if (value == NULL) {
    return E_POINTER;
  }
  size_t n = wcslen(r->name) + 1;
  *value = (LPWSTR)CoTaskMemAlloc(n * sizeof(wchar_t));
  if (*value == NULL) {
    return E_OUTOFMEMORY;
  }
  wcscpy(*value, r->name);
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbReg_get_secure(
    ICoreWebView2CustomSchemeRegistration *self, BOOL *value) {
  (void)self;
  if (value == NULL) {
    return E_POINTER;
  }
  // 本地内容当安全源（与 WebKit 分支自定义协议的安全源口径一致）
  *value = TRUE;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbReg_put_secure(
    ICoreWebView2CustomSchemeRegistration *self, BOOL value) {
  (void)self;
  (void)value;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbReg_get_origins(
    ICoreWebView2CustomSchemeRegistration *self, UINT32 *count,
    LPWSTR **origins) {
  (void)self;
  if (count == NULL || origins == NULL) {
    return E_POINTER;
  }
  *count = 0;
  *origins = NULL;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbReg_set_origins(
    ICoreWebView2CustomSchemeRegistration *self, UINT32 count,
    LPWSTR *origins) {
  (void)self;
  (void)count;
  (void)origins;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbReg_get_authority(
    ICoreWebView2CustomSchemeRegistration *self, BOOL *value) {
  (void)self;
  if (value == NULL) {
    return E_POINTER;
  }
  // URL 形态 scheme://<host>/<path> 带 authority 段（MoonBit 层拼 URL 的形态）
  *value = TRUE;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbReg_put_authority(
    ICoreWebView2CustomSchemeRegistration *self, BOOL value) {
  (void)self;
  (void)value;
  return S_OK;
}
static const ICoreWebView2CustomSchemeRegistrationVtbl wb_reg_vt = {
    WbReg_qi,          WbReg_ref,         WbReg_rel,       WbReg_get_name,
    WbReg_get_secure,  WbReg_put_secure,  WbReg_get_origins,
    WbReg_set_origins, WbReg_get_authority, WbReg_put_authority,
};

static ICoreWebView2CustomSchemeRegistration **wb_regs_build(UINT32 *count) {
  *count = 0;
  for (int i = 0; i < wb_predeclared_n; i++) {
    if (i >= WB_MAX_SCHEMES) {
      break;
    }
    if (wb_regs[i] == NULL) {
      WbReg *r = (WbReg *)malloc(sizeof(WbReg));
      if (r == NULL) {
        break;
      }
      r->itf.lpVtbl = &wb_reg_vt;
      r->name = wb_predeclared[i];
      wb_regs[i] = r;
    }
    wb_regs_n = i + 1;
  }
  *count = (UINT32)wb_regs_n;
  return (ICoreWebView2CustomSchemeRegistration **)wb_regs;
}

// ---- WbOptions：单实例、四个子接口嵌套（QI 按子槽偏移分派）----

typedef struct WbOptions WbOptions;
struct WbOptions {
  ICoreWebView2EnvironmentOptions base;
  ICoreWebView2EnvironmentOptions2 opt2;
  ICoreWebView2EnvironmentOptions3 opt3;
  ICoreWebView2EnvironmentOptions4 opt4;
  int refs;
};

static HRESULT STDMETHODCALLTYPE WbOptions_qi_at(WbOptions *o, REFIID riid,
                                                 void **out, void *slot) {
  if (out == NULL) {
    return E_POINTER;
  }
  *out = NULL;
  if (IsEqualGUID(riid, &IID_IUnknown) ||
      IsEqualGUID(riid, &IID_ICoreWebView2EnvironmentOptions)) {
    *out = &o->base;
  } else if (IsEqualGUID(riid, &IID_ICoreWebView2EnvironmentOptions2)) {
    *out = &o->opt2;
  } else if (IsEqualGUID(riid, &IID_ICoreWebView2EnvironmentOptions3)) {
    *out = &o->opt3;
  } else if (IsEqualGUID(riid, &IID_ICoreWebView2EnvironmentOptions4)) {
    *out = &o->opt4;
  } else {
    (void)slot;
    return E_NOINTERFACE;
  }
  o->refs++;
  return S_OK;
}
static ULONG STDMETHODCALLTYPE WbOptions_ref_at(WbOptions *o) {
  return (ULONG)(++o->refs);
}
static ULONG STDMETHODCALLTYPE WbOptions_rel_at(WbOptions *o) {
  return (ULONG)(--o->refs);
}
#define WB_OPT_SLOTS(F)                                                        \
  F(base, ICoreWebView2EnvironmentOptions)                                     \
  F(opt2, ICoreWebView2EnvironmentOptions2)                                    \
  F(opt3, ICoreWebView2EnvironmentOptions3)                                    \
  F(opt4, ICoreWebView2EnvironmentOptions4)
#define WB_OPT_QI(slot, ITF)                                                   \
  static HRESULT STDMETHODCALLTYPE WbOpt_##slot##_qi(ITF *self, REFIID riid,   \
                                                     void **out) {             \
    WbOptions *o = (WbOptions *)((char *)self - offsetof(WbOptions, slot));    \
    return WbOptions_qi_at(o, riid, out, self);                                \
  }
#define WB_OPT_REF(slot, ITF)                                                  \
  static ULONG STDMETHODCALLTYPE WbOpt_##slot##_ref(ITF *self) {               \
    WbOptions *o = (WbOptions *)((char *)self - offsetof(WbOptions, slot));    \
    return WbOptions_ref_at(o);                                                \
  }
#define WB_OPT_REL(slot, ITF)                                                  \
  static ULONG STDMETHODCALLTYPE WbOpt_##slot##_rel(ITF *self) {               \
    WbOptions *o = (WbOptions *)((char *)self - offsetof(WbOptions, slot));    \
    return WbOptions_rel_at(o);                                                \
  }
WB_OPT_SLOTS(WB_OPT_QI)
WB_OPT_SLOTS(WB_OPT_REF)
WB_OPT_REL(base, ICoreWebView2EnvironmentOptions)
WB_OPT_REL(opt2, ICoreWebView2EnvironmentOptions2)
WB_OPT_REL(opt3, ICoreWebView2EnvironmentOptions3)
WB_OPT_REL(opt4, ICoreWebView2EnvironmentOptions4)

// 属性：全默认（额外参数/语言空、SSO 关），TargetCompatibleBrowserVersion 给
// vendor SDK 的版本
static HRESULT STDMETHODCALLTYPE WbOpt_get_str(LPWSTR *value,
                                               LPCWSTR fallback) {
  if (value == NULL) {
    return E_POINTER;
  }
  size_t n = wcslen(fallback) + 1;
  *value = (LPWSTR)CoTaskMemAlloc(n * sizeof(wchar_t));
  if (*value == NULL) {
    return E_OUTOFMEMORY;
  }
  wcscpy(*value, fallback);
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbOpt_put_str(ICoreWebView2EnvironmentOptions *self,
                                               LPCWSTR value) {
  (void)self;
  (void)value;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbOpt_get_bool(ICoreWebView2EnvironmentOptions *self,
                                                BOOL *value) {
  (void)self;
  if (value == NULL) {
    return E_POINTER;
  }
  *value = FALSE;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbOpt_put_bool(ICoreWebView2EnvironmentOptions *self,
                                                BOOL value) {
  (void)self;
  (void)value;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbOpt_get_args(
    ICoreWebView2EnvironmentOptions *self, LPWSTR *value) {
  (void)self;
  return WbOpt_get_str(value, L"");
}
static HRESULT STDMETHODCALLTYPE WbOpt_get_lang(
    ICoreWebView2EnvironmentOptions *self, LPWSTR *value) {
  (void)self;
  return WbOpt_get_str(value, L"");
}
static HRESULT STDMETHODCALLTYPE WbOpt_get_ver(
    ICoreWebView2EnvironmentOptions *self, LPWSTR *value) {
  (void)self;
  return WbOpt_get_str(value, WB_TARGET_VERSION);
}
static HRESULT STDMETHODCALLTYPE WbOpt_get_sso(
    ICoreWebView2EnvironmentOptions *self, BOOL *value) {
  (void)self;
  return WbOpt_get_bool(self, value);
}
static const ICoreWebView2EnvironmentOptionsVtbl wb_opt_base_vt = {
    WbOpt_base_qi, WbOpt_base_ref, WbOpt_base_rel,
    WbOpt_get_args, WbOpt_put_str, WbOpt_get_lang, WbOpt_put_str,
    WbOpt_get_ver, WbOpt_put_str, WbOpt_get_sso, WbOpt_put_bool,
};
static const ICoreWebView2EnvironmentOptions2Vtbl wb_opt2_vt = {
    WbOpt_opt2_qi, WbOpt_opt2_ref, WbOpt_opt2_rel,
    WbOpt_get_bool, WbOpt_put_bool, // ExclusiveUserDataFolderAccess
};
static const ICoreWebView2EnvironmentOptions3Vtbl wb_opt3_vt = {
    WbOpt_opt3_qi, WbOpt_opt3_ref, WbOpt_opt3_rel,
    WbOpt_get_bool, WbOpt_put_bool, // IsCustomCrashReportingEnabled
};
static HRESULT STDMETHODCALLTYPE WbOpt_get_regs(
    ICoreWebView2EnvironmentOptions4 *self, UINT32 *count,
    ICoreWebView2CustomSchemeRegistration ***regs) {
  (void)self;
  if (count == NULL || regs == NULL) {
    return E_POINTER;
  }
  // 契约：数组本体由调用方 CoTaskMemFree 释放——必须 CoTaskMemAlloc 拷出
  // （静态数组交给 loader free 会触发 0xC0000374 堆损坏，真机实测）。
  WbReg **src = wb_regs_build(count);
  UINT32 n = *count;
  if (n == 0) {
    *regs = NULL;
    return S_OK;
  }
  ICoreWebView2CustomSchemeRegistration **out = (ICoreWebView2CustomSchemeRegistration **)CoTaskMemAlloc(
      (size_t)n * sizeof(ICoreWebView2CustomSchemeRegistration *));
  if (out == NULL) {
    *count = 0;
    *regs = NULL;
    return E_OUTOFMEMORY;
  }
  for (UINT32 i = 0; i < n; i++) {
    out[i] = (ICoreWebView2CustomSchemeRegistration *)src[i];
    out[i]->lpVtbl->AddRef(out[i]);
  }
  *regs = out;
  return S_OK;
}
static HRESULT STDMETHODCALLTYPE WbOpt_set_regs(
    ICoreWebView2EnvironmentOptions4 *self, UINT32 count,
    ICoreWebView2CustomSchemeRegistration **regs) {
  (void)self;
  (void)count;
  (void)regs;
  return S_OK;
}
static const ICoreWebView2EnvironmentOptions4Vtbl wb_opt4_vt = {
    WbOpt_opt4_qi, WbOpt_opt4_ref, WbOpt_opt4_rel,
    WbOpt_get_regs, WbOpt_set_regs,
};

static WbOptions wb_options_inst = {
    {&wb_opt_base_vt}, {&wb_opt2_vt}, {&wb_opt3_vt}, {&wb_opt4_vt}, 1,
};

// ---- 对外面（MoonBit 只搬 int64 与字节缓冲）----

// 主线程 COM：win 桩的其他 COM 消费者（WIC/托盘/对话框）各自局部初始化过，
// WebView2 这里再兜一次（已初始化则 S_FALSE 无害；模式冲突时本线程装不下，
// 与 win 桩同为 APARTMENTTHREADED 口径，不会发生）。
static void wb_ensure_com(void) {
  CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
}

// Runtime 在位探测（结果缓存）：Evergreen 装没装、Loader 能不能起
int wb_available(void) {
  static int cached = -1;
  if (cached < 0) {
    wb_ensure_com();
    LPWSTR ver = NULL;
    HRESULT hr = GetAvailableCoreWebView2BrowserVersionString(NULL, &ver);
    cached = SUCCEEDED(hr) && ver != NULL ? 1 : 0;
    if (ver != NULL) {
      CoTaskMemFree(ver);
    }
  }
  return cached;
}

int wb_alive(int64_t id) { return wb_get(id) != NULL ? 1 : 0; }

int wb_persistence(void) {
  // data_dir 形态的 profile 没有平台边界（macOS 才有 14+/bundle id 那道坎）
  return 1;
}

// 1 下载 2 进程终止 4 权限 8 新窗——WebView2 的事件族恒齐
int wb_signal_mask(void) { return 15; }

int64_t wb_create(int64_t surface_id, int w, int h, const char *uri,
                  const char *data_dir, const char *user_agent) {
  (void)w;
  (void)h;
  if (!wb_available()) {
    return 0;
  }
  HWND parent = (HWND)wm_surface_container(surface_id);
  if (parent == NULL || !IsWindow(parent) || wb_next_id >= WB_MAX_VIEWS) {
    return 0;
  }
  int id = wb_next_id++;
  WbView *v = &wb_pool[id];
  memset(v, 0, sizeof(WbView));
  v->id = id;
  v->surface_id = surface_id;
  v->parent = parent;
  v->download_allow = 1;

  // per-view 事件 handler 实例（建好就绑 v；挂接在就绪回调里）
#define WB_NEW_HND(TAG, SLOT)                                                  \
  do {                                                                         \
    struct WbHnd_##TAG *p =                                                    \
        (struct WbHnd_##TAG *)malloc(sizeof(struct WbHnd_##TAG));              \
    if (p == NULL) {                                                           \
      v->dead = 1;                                                             \
      return (int64_t)id;                                                      \
    }                                                                          \
    p->itf.lpVtbl = &WbHnd_##TAG##_vt;                                         \
    p->v = v;                                                                  \
    v->hnd[SLOT] = p;                                                          \
  } while (0)
  WB_NEW_HND(NavStart, 0);
  WB_NEW_HND(ContentLoad, 1);
  WB_NEW_HND(NavDone, 2);
  WB_NEW_HND(SrcChange, 3);
  WB_NEW_HND(TitleChange, 4);
  WB_NEW_HND(WebMsg, 5);
  WB_NEW_HND(NewWin, 6);
  WB_NEW_HND(PermReq, 7);
  WB_NEW_HND(DlStart, 8);
  WB_NEW_HND(ProcFail, 9);
  WB_NEW_HND(WinClose, 10);
  WB_NEW_HND(ResReq, 11);
  WB_NEW_HND(FocusGot, 12);
  WB_NEW_HND(FocusLost, 13);
#undef WB_NEW_HND
  // 宿主滚轮探针只挂一次（函数指针槽，覆盖无害——多个 view 共用同一实现）
  wm_set_wheel_probe(wb_wheel_target);

  if (data_dir != NULL && data_dir[0] != '\0') {
    v->data_dir = wb_utf8_to_wide(data_dir);
  } else {
    // 无 profile 口径也要给 userDataFolder（WebView2 没有真临时会话形态），
    // 给 exe 旁的缓存目录兜底
    char path[MAX_PATH + 32];
    GetModuleFileNameA(NULL, path, MAX_PATH);
    char *slash = strrchr(path, '\\');
    if (slash != NULL) {
      *slash = '\0';
    }
    strcat(path, "\\.webview2-default");
    v->data_dir = wb_utf8_to_wide(path);
  }
  if (user_agent != NULL && user_agent[0] != '\0') {
    v->ua = wb_utf8_to_wide(user_agent);
  }
  v->pending_uri =
      (uri != NULL && uri[0] != '\0') ? wb_utf8_to_wide(uri) : NULL;

  WbEnvReq *ereq = (WbEnvReq *)malloc(sizeof(WbEnvReq));
  if (ereq == NULL) {
    v->dead = 1;
    return (int64_t)id;
  }
  ereq->itf.lpVtbl = &wb_env_req_vt;
  ereq->id = id;
  // options 单实例（名单封版后不变）；自定义 scheme 预注册挂在它上面
  HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
      NULL, v->data_dir ? v->data_dir : L"", &wb_options_inst.base,
      &ereq->itf);
  if (FAILED(hr)) {
    // 同步失败（Loader 问题等）：直接标死
    v->dead = 1;
    char buf[128];
    snprintf(buf, sizeof(buf), "|webview2|0x%08lx|loader create failed",
             (unsigned long)hr);
    wb_push(v, 14, 0, buf);
    free(ereq);
  }
  return (int64_t)id;
}

void wb_load_uri(int64_t id, const char *uri) {
  WbView *v = wb_get(id);
  if (v == NULL) {
    return;
  }
  wchar_t *w = wb_utf8_to_wide(uri ? uri : "about:blank");
  if (w == NULL) {
    return;
  }
  if (v->ready) {
    v->web->lpVtbl->Navigate(v->web, w);
    free(w);
  } else {
    // 就绪前到达：缓存住（pending_html 优先级更高，互斥清掉）
    free(v->pending_uri);
    v->pending_uri = w;
    free(v->pending_html);
    v->pending_html = NULL;
  }
}

void wb_load_html(int64_t id, const char *html, const char *base_uri) {
  WbView *v = wb_get(id);
  if (v == NULL) {
    return;
  }
  // 没有 base URI 形态（记档差异）：NavigateToString 一次性给全文
  wchar_t *w = wb_utf8_to_wide(html ? html : "");
  if (w == NULL) {
    return;
  }
  if (v->ready) {
    v->web->lpVtbl->NavigateToString(v->web, w);
    free(w);
  } else {
    free(v->pending_html);
    v->pending_html = w;
  }
  (void)base_uri;
}

void wb_reload(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL && v->ready) {
    v->web->lpVtbl->Reload(v->web);
  }
}

void wb_stop(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL && v->ready) {
    v->web->lpVtbl->Stop(v->web);
  }
}

void wb_go_back(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL && v->ready) {
    v->web->lpVtbl->GoBack(v->web);
  }
}

void wb_go_forward(int64_t id) {
  WbView *v = wb_get(id);
  if (v != NULL && v->ready) {
    v->web->lpVtbl->GoForward(v->web);
  }
}

int wb_can_go_back(int64_t id) {
  WbView *v = wb_get(id);
  if (v == NULL || !v->ready) {
    return 0;
  }
  BOOL ok = FALSE;
  v->web->lpVtbl->get_CanGoBack(v->web, &ok);
  return ok ? 1 : 0;
}

int wb_can_go_forward(int64_t id) {
  WbView *v = wb_get(id);
  if (v == NULL || !v->ready) {
    return 0;
  }
  BOOL ok = FALSE;
  v->web->lpVtbl->get_CanGoForward(v->web, &ok);
  return ok ? 1 : 0;
}

int wb_is_loading(int64_t id) {
  WbView *v = wb_get_keep(id);
  return v != NULL && v->ready && v->loading > 0 ? 1 : 0;
}

int wb_is_crashed(int64_t id) {
  WbView *v = wb_get(id);
  return v != NULL && v->crashed ? 1 : 0;
}

int wb_uri(int64_t id, char *out, int cap) {
  WbView *v = wb_get_keep(id);
  if (v == NULL || !v->ready) {
    return wb_copy("", out, cap);
  }
  LPWSTR u = NULL;
  char *u8 = NULL;
  if (SUCCEEDED(v->web->lpVtbl->get_Source(v->web, &u)) && u != NULL) {
    u8 = wb_wide_to_utf8(u);
    CoTaskMemFree(u);
  }
  int n = wb_copy(u8 ? u8 : "", out, cap);
  free(u8);
  return n;
}

int wb_title(int64_t id, char *out, int cap) {
  WbView *v = wb_get_keep(id);
  if (v == NULL || !v->ready) {
    return wb_copy("", out, cap);
  }
  LPWSTR t = NULL;
  char *u8 = NULL;
  if (SUCCEEDED(v->web->lpVtbl->get_DocumentTitle(v->web, &t)) && t != NULL) {
    u8 = wb_wide_to_utf8(t);
    CoTaskMemFree(t);
  }
  int n = wb_copy(u8 ? u8 : "", out, cap);
  free(u8);
  return n;
}

// JS 求值：立刻返回请求序号，回包以 kind=7 + 同序号进队列
typedef struct {
  ICoreWebView2ExecuteScriptCompletedHandler itf;
  int64_t id;
  int64_t seq;
} WbEvalReq;

static HRESULT STDMETHODCALLTYPE WbEvalReq_qi(
    ICoreWebView2ExecuteScriptCompletedHandler *self, REFIID riid, void **out) {
  return wb_hnd_qi((IUnknown *)self, riid, out,
                   &IID_ICoreWebView2ExecuteScriptCompletedHandler);
}
static ULONG STDMETHODCALLTYPE WbEvalReq_ref(
    ICoreWebView2ExecuteScriptCompletedHandler *self) {
  (void)self;
  return 1;
}
static ULONG STDMETHODCALLTYPE WbEvalReq_rel(
    ICoreWebView2ExecuteScriptCompletedHandler *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbEvalReq_inv(
    ICoreWebView2ExecuteScriptCompletedHandler *self, HRESULT errorResult,
    LPCWSTR resultObjectAsJson) {
  WbEvalReq *req = (WbEvalReq *)self;
  WbView *v = wb_get(req->id);
  if (v != NULL) {
    // 回包全文进专用大缓冲（事件槽 768 装不下 DOM JSON，塞进去会被 strncpy
    // 截成半截 JSON，上层解析必失败），事件只带序号、text 恒空
    free(v->eval_text);
    v->eval_text = NULL;
    v->eval_len = 0;
    if (FAILED(errorResult)) {
      char buf[96];
      snprintf(buf, sizeof(buf), "evaluate failed (0x%08lx)",
               (unsigned long)errorResult);
      size_t bl = strlen(buf) + 1;
      v->eval_text = (char *)malloc(bl);
      if (v->eval_text != NULL) {
        memcpy(v->eval_text, buf, bl);
      }
    } else {
      char *u8 = wb_wide_to_utf8(resultObjectAsJson);
      if (u8 != NULL) {
        wb_json_unquote(u8);
        int n = (int)strlen(u8);
        if (n > WB_EVAL_TEXT_MAX) {
          n = WB_EVAL_TEXT_MAX;
          u8[n] = '\0';
        }
        v->eval_text = u8; // 所有权转移，不再 free
        v->eval_len = n;
      }
    }
    if (v->eval_text != NULL && v->eval_len == 0) {
      v->eval_len = (int)strlen(v->eval_text);
    }
    wb_push(v, 7, req->seq, "");
  }
  free(req);
  return S_OK;
}
static const ICoreWebView2ExecuteScriptCompletedHandlerVtbl wb_eval_vt = {
    WbEvalReq_qi, WbEvalReq_ref, WbEvalReq_rel, WbEvalReq_inv};

// 取最近一次 JS 求值回包全文：拷进 out（cap 上限），返回全文总长（>cap 表示
// 被截到 cap；<=0 = 没有回包）。事件 kind=7 的 text 恒空，全文在这里。
int wb_eval_text(int64_t id, char *out, int cap) {
  WbView *v = wb_get(id);
  if (v == NULL || v->eval_text == NULL || out == NULL || cap <= 0) {
    return 0;
  }
  int n = v->eval_len < cap ? v->eval_len : cap;
  memmove(out, v->eval_text, (size_t)n);
  return v->eval_len;
}

int64_t wb_evaluate(int64_t id, const char *script) {
  WbView *v = wb_get(id);
  if (v == NULL || !v->ready) {
    return -1;
  }
  v->eval_seq++;
  WbEvalReq *req = (WbEvalReq *)malloc(sizeof(WbEvalReq));
  if (req == NULL) {
    return -1;
  }
  req->itf.lpVtbl = &wb_eval_vt;
  req->id = id;
  req->seq = v->eval_seq;
  wchar_t *w = wb_utf8_to_wide(script ? script : "");
  if (w == NULL) {
    free(req);
    return -1;
  }
  HRESULT hr = v->web->lpVtbl->ExecuteScript(v->web, w, &req->itf);
  free(w);
  if (FAILED(hr)) {
    free(req);
    return -1;
  }
  return v->eval_seq;
}

// user script 注入的完成回包我们不关心：静态空 handler（Invoke 恒 S_OK 丢弃）
static HRESULT STDMETHODCALLTYPE WbScriptDummy_qi(
    ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler *self,
    REFIID riid, void **out) {
  return wb_hnd_qi(
      (IUnknown *)self, riid, out,
      &IID_ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler);
}
static ULONG STDMETHODCALLTYPE WbScriptDummy_ref(
    ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler *self) {
  (void)self;
  return 1;
}
static ULONG STDMETHODCALLTYPE WbScriptDummy_rel(
    ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbScriptDummy_inv(
    ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler *self,
    HRESULT errorCode, LPCWSTR id) {
  (void)self;
  (void)errorCode;
  (void)id;
  return S_OK;
}
static const ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandlerVtbl
    wb_script_vtbl = {WbScriptDummy_qi, WbScriptDummy_ref, WbScriptDummy_rel,
                      WbScriptDummy_inv};
static ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler
    wb_script_hnd = {&wb_script_vtbl};

void wb_add_user_script(int64_t id, const char *source) {
  WbView *v = wb_get(id);
  if (v == NULL || source == NULL) {
    return;
  }
  // 就绪前缓存不住（AddScriptToExecuteOnDocumentCreated 要 web 在位）——
  // 就绪后补。绑定 shim 的注册时机在 MoonBit 层绑定重试 tick（就绪后），
  // 实际不会撞上未就绪窗口；撞上就静默丢（记档差异）。
  if (!v->ready) {
    return;
  }
  wchar_t *w = wb_utf8_to_wide(source);
  if (w == NULL) {
    return;
  }
  v->web->lpVtbl->AddScriptToExecuteOnDocumentCreated(
      v->web, w, &wb_script_hnd);
  free(w);
}

// 注册「页面 → 原生」通道：注入 shim 把 window.<name>(payload) 变成
// window.chrome.webview.postMessage(JSON.stringify(payload))
int wb_add_binding(int64_t id, const char *name) {
  WbView *v = wb_get(id);
  if (v == NULL || name == NULL || name[0] == '\0') {
    return 0;
  }
  char shim[1024];
  snprintf(shim, sizeof(shim),
           "(function(){if(window.%s)return;"
           "window.%s=function(p){try{window.chrome.webview.postMessage("
           "JSON.stringify(p===undefined?null:p));}"
           "catch(e){window.chrome.webview.postMessage(String(e));}};"
           "})();",
           name, name);
  wb_add_user_script(id, shim);
  return 1;
}

int wb_register_scheme(int64_t id, const char *scheme, const char *root) {
  WbView *v = wb_get(id);
  if (v == NULL || scheme == NULL || scheme[0] == '\0') {
    return 0;
  }
  // 登记（或换根目录）；filter 只挂一次（就绪后登记的立即挂，就绪前的在
  // 就绪回调里补挂）
  int slot_i = -1;
  for (int i = 0; i < WB_MAX_SCHEMES; i++) {
    if (v->schemes[i].scheme[0] != '\0' &&
        _stricmp(v->schemes[i].scheme, scheme) == 0) {
      slot_i = i;
      break;
    }
  }
  if (slot_i < 0) {
    for (int i = 0; i < WB_MAX_SCHEMES; i++) {
      if (v->schemes[i].scheme[0] == '\0') {
        slot_i = i;
        memset(&v->schemes[i], 0, sizeof(v->schemes[i]));
        strncpy(v->schemes[i].scheme, scheme,
                sizeof(v->schemes[i].scheme) - 1);
        break;
      }
    }
  }
  if (slot_i < 0) {
    return 0;
  }
  if (root != NULL) {
    strncpy(v->schemes[slot_i].root, root, sizeof(v->schemes[slot_i].root) - 1);
    v->schemes[slot_i].root[sizeof(v->schemes[slot_i].root) - 1] = '\0';
  } else {
    v->schemes[slot_i].root[0] = '\0';
  }
  if (v->ready && !v->schemes[slot_i].filter_added) {
    char filter[48];
    _snprintf(filter, sizeof(filter), "%s://*/*", v->schemes[slot_i].scheme);
    filter[sizeof(filter) - 1] = '\0';
    wchar_t *wf = wb_utf8_to_wide(filter);
    if (wf != NULL) {
      v->web->lpVtbl->AddWebResourceRequestedFilter(
          v->web, wf, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
      free(wf);
      v->schemes[slot_i].filter_added = 1;
    }
  }
  return 1;
}

// 「注销」= 清空根目录，之后这条 scheme 的请求一律回 404（引擎没有真注销口）
int wb_unregister_scheme(int64_t id, const char *scheme) {
  WbView *v = wb_get(id);
  if (v == NULL || scheme == NULL) {
    return 0;
  }
  for (int i = 0; i < WB_MAX_SCHEMES; i++) {
    if (v->schemes[i].scheme[0] != '\0' &&
        _stricmp(v->schemes[i].scheme, scheme) == 0) {
      v->schemes[i].root[0] = '\0';
      return 1;
    }
  }
  return 0;
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

// cookie 回包：kind=13，结构化 JSON 数组（与 WebKit 分支同一形态）
typedef struct {
  ICoreWebView2GetCookiesCompletedHandler itf;
  int64_t id;
} WbCookieReq;

static HRESULT STDMETHODCALLTYPE WbCookieReq_qi(
    ICoreWebView2GetCookiesCompletedHandler *self, REFIID riid, void **out) {
  return wb_hnd_qi((IUnknown *)self, riid, out,
                   &IID_ICoreWebView2GetCookiesCompletedHandler);
}
static ULONG STDMETHODCALLTYPE WbCookieReq_ref(
    ICoreWebView2GetCookiesCompletedHandler *self) {
  (void)self;
  return 1;
}
static ULONG STDMETHODCALLTYPE WbCookieReq_rel(
    ICoreWebView2GetCookiesCompletedHandler *self) {
  (void)self;
  return 1;
}
static HRESULT STDMETHODCALLTYPE WbCookieReq_inv(
    ICoreWebView2GetCookiesCompletedHandler *self, HRESULT errorResult,
    ICoreWebView2CookieList *args) {
  WbCookieReq *req = (WbCookieReq *)self;
  WbView *v = wb_get(req->id);
  if (v == NULL) {
    free(req);
    return S_OK;
  }
  if (FAILED(errorResult)) {
    char buf[96];
    snprintf(buf, sizeof(buf), "get cookies failed (0x%08lx)",
             (unsigned long)errorResult);
    wb_push(v, 13, 1, buf);
    free(req);
    return S_OK;
  }
  ICoreWebView2CookieList *list = args;
  char out[WB_EV_TEXT];
  int at = 0;
  out[at++] = '[';
  if (list != NULL) {
    INT32 n = 0;
    list->lpVtbl->get_Count(list, &n);
    for (INT32 i = 0; i < n && at < WB_EV_TEXT - 96; i++) {
      ICoreWebView2Cookie *c = NULL;
      if (FAILED(list->lpVtbl->GetValueAtIndex(list, i, &c)) || c == NULL) {
        break;
      }
      LPWSTR nm = NULL, val = NULL, dom = NULL;
      char *n8 = NULL, *v8 = NULL, *d8 = NULL;
      if (SUCCEEDED(c->lpVtbl->get_Name(c, &nm))) {
        n8 = wb_wide_to_utf8(nm);
        CoTaskMemFree(nm);
      }
      if (SUCCEEDED(c->lpVtbl->get_Value(c, &val))) {
        v8 = wb_wide_to_utf8(val);
        CoTaskMemFree(val);
      }
      if (SUCCEEDED(c->lpVtbl->get_Domain(c, &dom))) {
        d8 = wb_wide_to_utf8(dom);
        CoTaskMemFree(dom);
      }
      int wr = snprintf(
          out + at, sizeof(out) - at,
          at == 1 ? "{\"name\":\"%s\",\"value\":\"%s\",\"domain\":\"%s\"}"
                  : ",{\"name\":\"%s\",\"value\":\"%s\",\"domain\":\"%s\"}",
          n8 ? n8 : "", v8 ? v8 : "", d8 ? d8 : "");
      if (wr > 0) {
        at += wr;
      }
      free(n8);
      free(v8);
      free(d8);
      c->lpVtbl->Release(c);
    }
  }
  out[at++] = ']';
  out[at] = '\0';
  wb_push(v, 13, 1, out);
  free(req);
  return S_OK;
}
static const ICoreWebView2GetCookiesCompletedHandlerVtbl wb_cookie_vt = {
    WbCookieReq_qi, WbCookieReq_ref, WbCookieReq_rel, WbCookieReq_inv};

void wb_get_cookies(int64_t id, const char *uri) {
  WbView *v = wb_get(id);
  if (v == NULL || !v->ready) {
    return;
  }
  ICoreWebView2_2 *w2 = NULL;
  if (FAILED(v->web->lpVtbl->QueryInterface(
          v->web, &IID_ICoreWebView2_2, (void **)&w2)) ||
      w2 == NULL) {
    return;
  }
  ICoreWebView2CookieManager *cm = NULL;
  if (SUCCEEDED(w2->lpVtbl->get_CookieManager(w2, &cm)) && cm != NULL) {
    WbCookieReq *req = (WbCookieReq *)malloc(sizeof(WbCookieReq));
    if (req != NULL) {
      req->itf.lpVtbl = &wb_cookie_vt;
      req->id = id;
      wchar_t *w = wb_utf8_to_wide(uri ? uri : "");
      if (w != NULL) {
        cm->lpVtbl->GetCookies(cm, w, &req->itf);
        free(w);
      } else {
        free(req);
      }
    }
    cm->lpVtbl->Release(cm);
  }
  w2->lpVtbl->Release(w2);
}

void wb_focus(int64_t id) {
  WbView *v = wb_get(id);
  if (v == NULL || v->ctrl == NULL) {
    return;
  }
  v->ctrl->lpVtbl->MoveFocus(v->ctrl, COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
}

void wb_set_user_agent(int64_t id, const char *ua) {
  WbView *v = wb_get(id);
  if (v == NULL || ua == NULL) {
    return;
  }
  free(v->ua);
  v->ua = wb_utf8_to_wide(ua);
  if (v->ready && v->ua != NULL) {
    ICoreWebView2Settings *st = NULL;
    if (SUCCEEDED(v->web->lpVtbl->get_Settings(v->web, &st)) && st != NULL) {
      ICoreWebView2Settings2 *st2 = NULL;
      if (SUCCEEDED(st->lpVtbl->QueryInterface(st, &IID_ICoreWebView2Settings2, (void **)&st2)) && st2 != NULL) {
        st2->lpVtbl->put_UserAgent(st2, v->ua);
        st2->lpVtbl->Release(st2);
      }
      st->lpVtbl->Release(st);
    }
  }
}

// pane 级可见性（爬虫后台要的「不可见 webview」在窗口层，本条只管这一区）
void wb_set_visible(int64_t id, int visible) {
  WbView *v = wb_get(id);
  if (v != NULL && v->ctrl != NULL) {
    v->ctrl->lpVtbl->put_IsVisible(v->ctrl, visible ? TRUE : FALSE);
  }
}

void wb_set_size(int64_t id, int w, int h) {
  WbView *v = wb_get(id);
  if (v != NULL && v->ctrl != NULL && v->ready) {
    RECT rc;
    rc.left = 0;
    rc.top = 0;
    rc.right = w > 1 ? w : 1;
    rc.bottom = h > 1 ? h : 1;
    v->ctrl->lpVtbl->put_Bounds(v->ctrl, rc);
  }
}

void wb_destroy(int64_t id) {
  if (id <= 0 || id >= WB_MAX_VIEWS || wb_pool[id].parent == NULL) {
    return;
  }
  WbView *v = &wb_pool[id];
  wb_unsubclass_chrome(v); // 先还原 WndProc（Close 摘子窗前后都安全）
  if (v->ctrl != NULL) {
    v->ctrl->lpVtbl->Close(v->ctrl); // 从 parent HWND 摘掉并停引擎
    v->ctrl->lpVtbl->Release(v->ctrl);
    v->ctrl = NULL;
  }
  if (v->web != NULL) {
    v->web->lpVtbl->Release(v->web);
    v->web = NULL;
  }
  if (v->env != NULL) {
    v->env->lpVtbl->Release(v->env);
    v->env = NULL;
  }
  // 事件 handler 实例归桩所有（已挂进引擎的 token 不摘——Close 之后再挂的
  // 引擎侧引用随引擎释放；handler 结构本身现在 free 是安全的，引擎已停）
  for (int i = 0; i < 14; i++) {
    free(v->hnd[i]);
    v->hnd[i] = NULL;
  }
  free(v->data_dir);
  free(v->ua);
  free(v->pending_uri);
  free(v->eval_text);
  memset(v, 0, sizeof(WbView));
}

#endif /* _WIN32 */
