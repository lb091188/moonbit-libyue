/* W23a 外部拖入探针（纯 C，直接 #include stub.c）。
 *
 * 动机：跨进程拖放「另一头是谁」不由我们决定，能自动化的部分是**我们自己那一半
 * 的语义**——IDropTarget 的七个槽位填得对不对、格式认不认、载荷编码是不是本栈的
 * 线形状、效果标志位是不是真的被 DragOver/Drop 读回去。做法是造一个合成的
 * IDataObject（只实现取数据那几条）直喂已注册的 IDropTarget，等价于 OLE 在拖拽
 * 过程中打进来的那串回调，只是不需要第二个进程与真人鼠标。
 * 真·跨进程（从资源管理器拖文件进来、拖出去给记事本）只能真机验，见
 * _人工测试清单.md 的对应编号。
 *
 * 编法：本目录 `build.bat`（call vcvars64 + cl 全参数）。整份 stub.c 编进来会
 * 带上剪贴板空壳引用的 `moonbit_make_bytes`，下面 malloc 兜底；托盘/拖放的
 * Shell_NotifyIconW 与 DragQueryFileW 在 shell32.lib。
 *
 * 期望输出末行 DRAGDND-OK。
 */
#include <windows.h>
#include <ole2.h>
#include <shlobj.h> // DROPFILES（CF_HDROP 的内存布局）在这里，shellapi.h 不含
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../gui/win/stub.c"

// stub.c 的剪贴板空壳引用 MoonBit 运行时分配符号；探针不跑运行时，malloc 兜底
void *moonbit_make_bytes(int length, int unused) {
  (void)unused;
  return malloc(length > 0 ? (size_t)length : 1);
}

static int g_fail = 0;

static void check(const char *what, long long got, long long want) {
  if (got == want) {
    printf("PROBE ok   %-46s = %lld\n", what, got);
  } else {
    printf("PROBE FAIL %-46s = %lld (want %lld)\n", what, got, want);
    g_fail++;
  }
}

static void check_true(const char *what, int cond) {
  if (cond) {
    printf("PROBE ok   %s\n", what);
  } else {
    printf("PROBE FAIL %s\n", what);
    g_fail++;
  }
}

/* ---- 合成数据对象：只给 CF_HDROP 与 CF_UNICODETEXT 两种格式 ----------------
 * IDataObject 的 C 侧 vtbl 顺序照 objidl.h：QI/AddRef/Release/GetData/
 * GetDataHere/QueryGetData/GetCanonicalFormatEtc/SetData/EnumFormatEtc/
 * DAdvise/DUnadvise/EnumDAdvise。stub 的取法是 GetDataHere，两条都实现。 */
typedef struct {
  IDataObject iface;
  HGLOBAL hdrop;
  HGLOBAL text;
} ProbeDo;

static HGLOBAL probe_pick(ProbeDo *d, CLIPFORMAT cf) {
  if (cf == (CLIPFORMAT)CF_HDROP) {
    return d->hdrop;
  }
  if (cf == (CLIPFORMAT)CF_UNICODETEXT) {
    return d->text;
  }
  return NULL;
}

static HRESULT STDMETHODCALLTYPE pd_QI(IDataObject *This, REFIID riid,
                                       void **ppv) {
  (void)This;
  if (ppv == NULL) {
    return E_POINTER;
  }
  if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IDataObject)) {
    *ppv = (void *)This;
    return S_OK;
  }
  *ppv = NULL;
  return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE pd_AddRef(IDataObject *This) {
  (void)This;
  return 1;
}

static ULONG STDMETHODCALLTYPE pd_Release(IDataObject *This) {
  (void)This;
  return 0;
}

static HRESULT STDMETHODCALLTYPE pd_GetData(IDataObject *This, FORMATETC *fet,
                                            STGMEDIUM *out) {
  ProbeDo *d = (ProbeDo *)This;
  if (out == NULL || fet == NULL) {
    return E_POINTER;
  }
  memset(out, 0, sizeof(*out));
  HGLOBAL src = probe_pick(d, fet->cfFormat);
  if (src == NULL || fet->tymed != TYMED_HGLOBAL) {
    return DV_E_FORMATETC;
  }
  SIZE_T n = GlobalSize(src);
  HGLOBAL g = GlobalAlloc(GMEM_MOVEABLE, n);
  if (g == NULL) {
    return E_OUTOFMEMORY;
  }
  memcpy(GlobalLock(g), GlobalLock(src), n);
  GlobalUnlock(g);
  GlobalUnlock(src);
  out->tymed = TYMED_HGLOBAL;
  out->hGlobal = g;
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE pd_GetDataHere(IDataObject *This, FORMATETC *fet,
                                                STGMEDIUM *io) {
  ProbeDo *d = (ProbeDo *)This;
  HGLOBAL src = probe_pick(d, fet->cfFormat);
  if (src == NULL || fet->tymed != TYMED_HGLOBAL || io == NULL ||
      io->hGlobal == NULL) {
    return DV_E_FORMATETC;
  }
  SIZE_T n = GlobalSize(src);
  HGLOBAL g = GlobalReAlloc(io->hGlobal, n, GMEM_MOVEABLE);
  if (g == NULL) {
    return E_OUTOFMEMORY;
  }
  memcpy(GlobalLock(g), GlobalLock(src), n);
  GlobalUnlock(g);
  GlobalUnlock(src);
  io->hGlobal = g;
  io->tymed = TYMED_HGLOBAL;
  return S_OK;
}

static HRESULT STDMETHODCALLTYPE pd_QueryGetData(IDataObject *This,
                                                 FORMATETC *fet) {
  ProbeDo *d = (ProbeDo *)This;
  return probe_pick(d, fet->cfFormat) != NULL ? S_OK : DV_E_FORMATETC;
}

static HRESULT STDMETHODCALLTYPE pd_Canonical(IDataObject *This, FORMATETC *in,
                                              FORMATETC *out) {
  (void)This;
  (void)in;
  (void)out;
  return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE pd_SetData(IDataObject *This, FORMATETC *fet,
                                            STGMEDIUM *stg, int fRelease) {
  (void)This;
  (void)fet;
  (void)stg;
  (void)fRelease;
  return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE pd_EnumFormatEtc(IDataObject *This, DWORD dir,
                                                  IEnumFORMATETC **out) {
  (void)This;
  (void)dir;
  if (out != NULL) {
    *out = NULL;
  }
  return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE pd_DAdvise(IDataObject *This, FORMATETC *fet,
                                            DWORD advf, IAdviseSink *sink,
                                            DWORD *conn) {
  (void)This;
  (void)fet;
  (void)advf;
  (void)sink;
  if (conn != NULL) {
    *conn = 0;
  }
  return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE pd_DUnadvise(IDataObject *This, DWORD conn) {
  (void)This;
  (void)conn;
  return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE pd_EnumDAdvise(IDataObject *This,
                                                 IEnumSTATDATA **out) {
  (void)This;
  (void)out;
  return E_NOTIMPL;
}

static IDataObjectVtbl probe_do_vtbl = {
    pd_QI,           pd_AddRef,        pd_Release,
    pd_GetData,      pd_GetDataHere,   pd_QueryGetData,
    pd_Canonical,    pd_SetData,       pd_EnumFormatEtc,
    pd_DAdvise,      pd_DUnadvise,     pd_EnumDAdvise,
};

// 造一份 CF_HDROP：DROPFILES 头 + fWide 的双空结尾宽字符路径表
static HGLOBAL probe_make_hdrop(const wchar_t *const *paths, int n) {
  size_t head = sizeof(DROPFILES);
  size_t chars = 1; // 末尾多一个空 WCHAR 收尾整张表
  for (int i = 0; i < n; i++) {
    chars += lstrlenW(paths[i]) + 1;
  }
  HGLOBAL g = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT,
                          head + chars * sizeof(WCHAR));
  if (g == NULL) {
    return NULL;
  }
  char *base = (char *)GlobalLock(g);
  DROPFILES *df = (DROPFILES *)base;
  df->pFiles = (DWORD)head;
  df->fWide = TRUE;
  WCHAR *w = (WCHAR *)(base + head);
  for (int i = 0; i < n; i++) {
    lstrcpyW(w, paths[i]);
    w += lstrlenW(paths[i]) + 1;
  }
  *w = L'\0';
  GlobalUnlock(g);
  return g;
}

static HGLOBAL probe_make_text(const wchar_t *t) {
  size_t bytes = (lstrlenW(t) + 1) * sizeof(WCHAR);
  HGLOBAL g = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, bytes);
  if (g == NULL) {
    return NULL;
  }
  memcpy(GlobalLock(g), t, bytes);
  GlobalUnlock(g);
  return g;
}

static void probe_fill(ProbeDo *d, HGLOBAL hdrop, HGLOBAL text) {
  memset(d, 0, sizeof(*d));
  d->iface.lpVtbl = &probe_do_vtbl;
  d->hdrop = hdrop;
  d->text = text;
}

// 读回并打印当前载荷（线形状）：给出种类编号与正文
static int probe_payload_kind(void) {
  char buf[4096];
  int n = wm_dragdnd_payload(buf, (int)sizeof(buf) - 1);
  if (n < 4) {
    return -1;
  }
  int id = (unsigned char)buf[0] | ((unsigned char)buf[1] << 8) |
           ((unsigned char)buf[2] << 16) | ((unsigned char)buf[3] << 24);
  buf[n] = '\0';
  printf("         载荷 body = \"%s\"\n", buf + 4);
  return id;
}

// 抽干事件队列（DragOver 这类中间事件按顺序堆着，断言前先把它们清场）
static void probe_drain(void) {
  int32_t s = 0, k = 0, x = 0, y = 0;
  while (wm_dragdnd_poll(&s, &k, &x, &y)) {
  }
}

int main(void) {
  check_true("wm_init 成功（有显示服务）", wm_init() == 1);

  /* ① OLE 起得来、能挂能撤 */
  check("wm_dragdnd_supported == 1", wm_dragdnd_supported(), 1);
  int64_t win = wm_window_new(400, 300, "拖入探针");
  check_true("建窗拿到句柄", win > 0);
  check("未挂时计数 0", wm_dragdnd_count(), 0);
  check("越界 id 挂不上", wm_dragdnd_enable(9999), 0);
  check("wm_dragdnd_enable 成功", wm_dragdnd_enable(win), 1);
  check("重复挂幂等", wm_dragdnd_enable(win), 1);
  check("挂上后计数 1", wm_dragdnd_count(), 1);
  check("未设效果时读回 0（DROPEFFECT_NONE）", wm_dragdnd_effect(win), 0);

  /* ② 拖进来的是文件：CF_HDROP → Paths(4)，多条用 \n 连接 */
  const wchar_t *paths[2] = {L"C:\\Temp\\甲文件.txt", L"D:\\b.txt"};
  ProbeDo do1;
  probe_fill(&do1, probe_make_hdrop(paths, 2), NULL);
  IDropTarget *dt = &wm_dnd[(int)win].iface;
  // OLE 送进来的坐标是**屏幕**坐标，探针要的是「客户区 (20,30)」那一点，
  // 所以用 ClientToScreen 反推（直接拿 (0,0) 加偏移会把窗口自身位置算进去）。
  POINT cl;
  cl.x = 20;
  cl.y = 30;
  check_true("ClientToScreen 换算成功",
             ClientToScreen(wm_windows[(int)win].hwnd, &cl) != 0);
  POINTL pt;
  pt.x = cl.x;
  pt.y = cl.y;
  DWORD eff = 999;
  check_true("DragEnter 返回 S_OK",
             SUCCEEDED(dt->lpVtbl->DragEnter(dt, &do1.iface, 0, pt, &eff)));
  check("认得出的格式首拍承诺 COPY", eff, 1);
  check("编码种类 = Paths(4)", probe_payload_kind(), 4);
  int32_t s = 0, k = 0, x = 0, y = 0;
  check("队列取到一条", wm_dragdnd_poll(&s, &k, &x, &y), 1);
  check("事件槽号 = 窗口号", s, (int)win);
  check("事件种类 = 进入(0)", k, WM_DND_ENTER);
  check("坐标已换算成客户区 x", x, 20);
  check("坐标已换算成客户区 y", y, 30);
  check("队列已空", wm_dragdnd_poll(&s, &k, &x, &y), 0);

  /* ③ 效果标志位真的被 DragOver/Drop 读回去 */
  wm_dragdnd_set_effect(win, 2); // MoonBit 说：这落点按「移动」算
  check("set_effect 读回 2", wm_dragdnd_effect(win), 2);
  eff = 999;
  dt->lpVtbl->DragOver(dt, 0, pt, &eff);
  check("DragOver 答出写回的效果", eff, 2);
  wm_dragdnd_set_effect(win, 0); // 落点不收
  eff = 999;
  dt->lpVtbl->DragOver(dt, 0, pt, &eff);
  check("落点不收时 DragOver 答 NONE", eff, 0);
  wm_dragdnd_set_effect(win, 1);
  probe_drain(); // 中间那几次 DragOver 的事件先清场
  eff = 999;
  check_true("Drop 返回 S_OK",
             SUCCEEDED(dt->lpVtbl->Drop(dt, &do1.iface, 0, pt, &eff)));
  check("Drop 答出写回的效果", eff, 1);
  check("Drop 之后效果复位 NONE", wm_dragdnd_effect(win), 0);
  check("投递事件入队", wm_dragdnd_poll(&s, &k, &x, &y), 1);
  check("投递事件种类 = 3", k, WM_DND_DROP);
  check("投递时载荷仍可读", probe_payload_kind(), 4);

  /* ④ 纯文本：CF_UNICODETEXT → Text(1)（且优先给 HDROP 之后） */
  ProbeDo do2;
  HGLOBAL both_h = probe_make_hdrop(paths, 1);
  HGLOBAL both_t = probe_make_text(L"拖进来的文本");
  probe_fill(&do2, both_h, both_t);
  dt->lpVtbl->DragEnter(dt, &do2.iface, 0, pt, &eff);
  check("两种都有时按文件档", probe_payload_kind(), 4);
  ProbeDo do3;
  probe_fill(&do3, NULL, both_t);
  dt->lpVtbl->DragEnter(dt, &do3.iface, 0, pt, &eff);
  check("只剩文本档时承诺 COPY", eff, 1);
  check("编码种类 = Text(1)", probe_payload_kind(), 1);

  /* ⑤ 不认识的格式：效果给 NONE、载荷为空 */
  ProbeDo do4;
  probe_fill(&do4, NULL, NULL);
  eff = 999;
  dt->lpVtbl->DragEnter(dt, &do4.iface, 0, pt, &eff);
  check("认不出格式时承诺 NONE", eff, 0);
  check("认不出时载荷为空", probe_payload_kind(), -1);

  /* ⑥ 离开：清载荷并复位效果 */
  probe_drain();
  wm_dragdnd_set_effect(win, 1);
  dt->lpVtbl->DragLeave(dt);
  check("离开后效果复位", wm_dragdnd_effect(win), 0);
  check("离开后载荷清空", probe_payload_kind(), -1);
  check("离开事件入队", wm_dragdnd_poll(&s, &k, &x, &y), 1);
  check("离开事件种类 = 2", k, WM_DND_LEAVE);

  /* ⑦ 拆窗即撤钩 */
  wm_dragdnd_disable(win);
  check("撤钩后计数 0", wm_dragdnd_count(), 0);
  check("撤钩后效果读回 -1（未挂）", wm_dragdnd_effect(win), -1);
  wm_dragdnd_set_effect(win, 1); // 未挂时写效果不该崩
  check("未挂时 set_effect 不留痕", wm_dragdnd_effect(win), -1);
  wm_close(win);

  printf("%s\n", g_fail == 0 ? "DRAGDND-OK" : "DRAGDND-FAIL");
  return g_fail == 0 ? 0 : 1;
}
