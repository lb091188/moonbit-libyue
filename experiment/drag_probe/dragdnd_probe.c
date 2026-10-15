/* W23a/W23b 跨进程拖放探针（纯 C，直接 #include stub.c）。
 *
 * 动机：跨进程拖放「另一头是谁」不由我们决定，能自动化的部分是**我们自己那一半
 * 的语义**——拖入侧：IDropTarget 的七个槽位填得对不对、格式认不认、载荷编码是不是
 * 本栈的线形状、效果标志位是不是真的被 DragOver/Drop 读回去。做法是造一个合成的
 * IDataObject（只实现取数据那几条）直喂已注册的 IDropTarget，等价于 OLE 在拖拽
 * 过程中打进来的那串回调，只是不需要第二个进程与真人鼠标。
 * 拖出侧（⑦⑧⑨）反过来验我们**交出去**的那只 IDataObject：格式问得出、GetData/
 * GetDataHere 给得出、CF_HDROP 的表能被 DragQueryFileW 逐条解析回原路径（相对路径
 * 已解析成绝对）、枚举器给得出这一条格式；再把同一只对象喂回本窗的 IDropTarget，
 * 抽出的载荷须与原始编码逐字符一致。`SHDoDragDrop` 本体要真人按下鼠标键才走得动
 * （OLE 的默认 IDropSource 轮询的是真实按键状态），所以那一趟与真·跨进程拖入一样
 * 只能真机验，见 _人工测试清单.md 的对应编号。
 *
 * 编法：本目录 `build.bat`（call vcvars64 + cl 全参数）。整份 stub.c 编进来会
 * 带上剪贴板空壳引用的 `moonbit_make_bytes`，下面 malloc 兜底；托盘/拖放的
 * Shell_NotifyIconW、DragQueryFileW 与 SHDoDragDrop 在 shell32.lib。
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
  int no_get_data_here; // 1 = 只实现 GetData（真资源管理器的形态）
  int no_get_data;      // 1 = 两条都不给（负面用）
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
  if (d->no_get_data) {
    return E_NOTIMPL;
  }
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
  if (d->no_get_data_here || d->no_get_data) {
    // 真 shell 的数据对象对 CF_HDROP 常只给 GetData，就地取这条给 E_NOTIMPL
    return E_NOTIMPL;
  }
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

/* ---- 拖出侧（W23b）用的三只小件 ---- */

// 线形状组装：[kind:i32 LE][正文]，返回总长
static int probe_wire(unsigned char *buf, int kind, const char *body) {
  buf[0] = (unsigned char)(kind & 255);
  buf[1] = 0;
  buf[2] = 0;
  buf[3] = 0;
  int n = (int)strlen(body);
  memcpy(buf + 4, body, (size_t)n);
  return n + 4;
}

static FORMATETC probe_fe(CLIPFORMAT cf) {
  FORMATETC fe;
  fe.cfFormat = cf;
  fe.ptd = NULL;
  fe.dwAspect = DVASPECT_CONTENT;
  fe.lindex = -1;
  fe.tymed = TYMED_HGLOBAL;
  return fe;
}

// 断言「本窗拖入侧当前读回的载荷正文」与期望串逐字符一致
// （配合 probe_payload_kind 打印用）
static void probe_payload_same(const char *want) {
  char buf[4096];
  int n = wm_dragdnd_payload(buf, (int)sizeof(buf) - 1);
  int ok = n >= 4 && n - 4 == (int)strlen(want) &&
           memcmp(buf + 4, want, (size_t)(n - 4)) == 0;
  check_true("载荷正文与原始编码逐字符一致", ok);
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

  /* ⑦ 拖出：路径表 → CF_HDROP（W23b 的数据对象语义 + 与本窗拖入侧的往返）
   * SHDoDragDrop 要真人按下鼠标键才走得动，所以这里验的是「我们造出来的那只
   * 对象对不对」：格式问得出、取得出、DROPFILES 解析回原路径（相对路径已解析成
   * 绝对）、枚举器给得出这一条格式；再把同一只对象喂进本窗的 IDropTarget，
   * 抽出来的载荷必须与原始线形状逐字节一致——等价于「拖出去再拖回来一趟」。 */
  {
    unsigned char wire[4096];
    const char *body = "C:\\Temp\\甲文件.txt\nrel\\乙.txt\nD:\\b.txt";
    int blen = (int)strlen(body);
    int wl = probe_wire(wire, WM_DND_KIND_PATHS, body);
    check("线形状总长 = 4 字节头 + 正文", wl, blen + 4);
    check_true("填路径表成功", wm_dsrc_fill(WM_DND_KIND_PATHS, wire + 4, blen) == 1);
    wm_dsrc.iface.lpVtbl = &wm_dragsource_vtbl;
    IDataObject *dob = &wm_dsrc.iface;
    check_true("格式是 CF_HDROP", wm_dsrc.cf == (CLIPFORMAT)CF_HDROP);
    FORMATETC fe_h = probe_fe((CLIPFORMAT)CF_HDROP);
    FORMATETC fe_t = probe_fe((CLIPFORMAT)CF_UNICODETEXT);
    check_true("QueryGetData 认 CF_HDROP", SUCCEEDED(dob->lpVtbl->QueryGetData(dob, &fe_h)));
    check_true("QueryGetData 不认文本档", FAILED(dob->lpVtbl->QueryGetData(dob, &fe_t)));
    STGMEDIUM stg;
    memset(&stg, 0, sizeof(stg));
    check_true("GetData 成功", SUCCEEDED(dob->lpVtbl->GetData(dob, &fe_h, &stg)));
    check("取回的是 HGLOBAL", (int)stg.tymed, (int)TYMED_HGLOBAL);
    HDROP hh = (HDROP)GlobalLock(stg.hGlobal);
    check("DROPFILES 里 3 条路径", (long long)DragQueryFileW(hh, 0xFFFFFFFF, NULL, 0), 3);
    WCHAR got[WM_DS_ONE_MAX];
    // 期望值独立算：把原串自己转宽字符再 GetFullPathNameW，逐条比
    const char *segs[3] = {"C:\\Temp\\甲文件.txt", "rel\\乙.txt", "D:\\b.txt"};
    char expect[4096];
    WCHAR want0[WM_DS_ONE_MAX];
    int elen = 0;
    expect[0] = '\0';
    want0[0] = L'\0';
    for (int i = 0; i < 3; i++) {
      // 期望值自己算一遍，但**输入与输出用两块缓冲**：GetFullPathNameW 就地写回
      // 同一块会把没读完的输入覆盖掉（这条坑在 stub 侧踩过，见 wm_dsrc_make_hdrop）
      WCHAR srcw[WM_DS_ONE_MAX], want[WM_DS_ONE_MAX];
      int cw = MultiByteToWideChar(CP_UTF8, 0, segs[i], -1, srcw, WM_DS_ONE_MAX);
      DWORD fw = GetFullPathNameW(srcw, WM_DS_ONE_MAX, want, NULL);
      char lbl[64];
      sprintf_s(lbl, sizeof(lbl), "第 %d 条路径解析回原值", i + 1);
      check_true(lbl, cw > 0 && fw > 0 && fw < WM_DS_ONE_MAX &&
                          DragQueryFileW(hh, (UINT)i, got, WM_DS_ONE_MAX) ==
                              (UINT)lstrlenW(want) &&
                          lstrcmpW(got, want) == 0);
      if (i > 0) {
        expect[elen++] = '\n'; // 与拖出侧同一套分隔口径
      } else {
        lstrcpyW(want0, want); // 留给「就地取 vs 新建」那条比对用
      }
      int cn = WideCharToMultiByte(CP_UTF8, 0, want, -1, expect + elen,
                                   (int)sizeof(expect) - elen, NULL, NULL);
      if (cn > 0) {
        elen += cn - 1; // 去掉转换补的结尾 NUL，最后统一收尾
        expect[elen] = '\0';
      }
      if (i == 1) {
        // 相对路径那条必须已被解析成绝对（对方程序照这个位置去拿文件）
        check_true("相对路径已解析成绝对",
                   DragQueryFileW(hh, 1, got, WM_DS_ONE_MAX) >= 3 && got[1] == L':' &&
                       got[2] == L'\\');
      }
    }
    GlobalUnlock(stg.hGlobal);
    GlobalFree(stg.hGlobal);
    // 就地取（拖入侧 wm_dnd_fetch 走的就是这条）
    HGLOBAL inplace = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, 1);
    STGMEDIUM stg2;
    memset(&stg2, 0, sizeof(stg2));
    stg2.tymed = TYMED_HGLOBAL;
    stg2.hGlobal = inplace;
    check_true("GetDataHere 成功", SUCCEEDED(dob->lpVtbl->GetDataHere(dob, &fe_h, &stg2)));
    check("GetDataHere 后仍是 HGLOBAL", (int)stg2.tymed, (int)TYMED_HGLOBAL);
    HDROP hi = (HDROP)GlobalLock(stg2.hGlobal);
    WCHAR a0[WM_DS_ONE_MAX];
    check("就地取的表也 3 条", (long long)DragQueryFileW(hi, 0xFFFFFFFF, NULL, 0), 3);
    check_true("就地取的表首条与新建的一致",
               DragQueryFileW(hi, 0, a0, WM_DS_ONE_MAX) == (UINT)lstrlenW(want0) &&
                   lstrcmpW(a0, want0) == 0);
    GlobalUnlock(stg2.hGlobal);
    GlobalFree(stg2.hGlobal);
    // 格式枚举器
    IEnumFORMATETC *en = NULL;
    check_true("EnumFormatEtc 成功", SUCCEEDED(dob->lpVtbl->EnumFormatEtc(dob, DATADIR_GET, &en)) && en != NULL);
    FORMATETC listed;
    ULONG fetched = 0;
    check_true("枚举第一条给 S_OK", SUCCEEDED(en->lpVtbl->Next(en, 1, &listed, &fetched)));
    check("枚举到的格式 = CF_HDROP", (long long)listed.cfFormat, (long long)CF_HDROP);
    check("枚举第二条给 S_FALSE", (long long)en->lpVtbl->Next(en, 1, &listed, &fetched), (long long)S_FALSE);
    check_true("Reset 成功", SUCCEEDED(en->lpVtbl->Reset(en)));
    check_true("Skip(1) 成功", SUCCEEDED(en->lpVtbl->Skip(en, 1)));
    check("Skip 之后再无元素", (long long)en->lpVtbl->Next(en, 1, &listed, &fetched), (long long)S_FALSE);
    IEnumFORMATETC *clon = NULL;
    check("Clone 明确不支持", (long long)en->lpVtbl->Clone(en, &clon), (long long)E_NOTIMPL);
    check_true("SetData 明确不支持（只读对象）", FAILED(dob->lpVtbl->SetData(dob, &fe_h, &stg, 0)));
    en->lpVtbl->Release(en);
    // 端到端：这只对象喂进本窗的拖入侧，抽出的载荷与原始一致
    dt->lpVtbl->DragEnter(dt, dob, 0, pt, &eff);
    check("拖出对象喂回本窗仍认得（承诺 COPY）", eff, 1);
    check("往返后种类仍是 Paths(4)", probe_payload_kind(), 4);
    probe_payload_same(expect);
    probe_drain();
    wm_dsrc_release_buffers();
  }

  /* ⑧ 拖出：纯文本 → CF_UNICODETEXT（UTF-8 → UTF-16 往返 + 中文） */
  {
    const char *body = "拖出去的中文\t与第二行";
    int blen = (int)strlen(body);
    check_true("填文本成功", wm_dsrc_fill(WM_DND_KIND_TEXT, (const unsigned char *)body, blen) == 1);
    wm_dsrc.iface.lpVtbl = &wm_dragsource_vtbl;
    IDataObject *dob = &wm_dsrc.iface;
    check_true("格式是 CF_UNICODETEXT", wm_dsrc.cf == (CLIPFORMAT)CF_UNICODETEXT);
    FORMATETC fe_t = probe_fe((CLIPFORMAT)CF_UNICODETEXT);
    STGMEDIUM stg;
    memset(&stg, 0, sizeof(stg));
    check_true("文本档 GetData 成功", SUCCEEDED(dob->lpVtbl->GetData(dob, &fe_t, &stg)));
    WCHAR *w = (WCHAR *)GlobalLock(stg.hGlobal);
    WCHAR want[1024];
    int ww = MultiByteToWideChar(CP_UTF8, 0, body, blen, want, 1024);
    want[ww] = L'\0';
    check_true("宽字符正文逐字符一致且以单个 NUL 收尾",
               w != NULL && lstrcmpW(w, want) == 0 &&
                   GlobalSize(stg.hGlobal) == (SIZE_T)(ww + 1) * sizeof(WCHAR));
    GlobalUnlock(stg.hGlobal);
    GlobalFree(stg.hGlobal);
    dt->lpVtbl->DragEnter(dt, dob, 0, pt, &eff);
    check("文本档往返种类 = Text(1)", probe_payload_kind(), 1);
    probe_payload_same(body);
    probe_drain();
    wm_dsrc_release_buffers();
  }

  /* ⑨ 拖出的负面：没有系统级形态的种类、空正文、越界/空指针一律不真起拖 */
  {
    unsigned char wire[64];
    check("Html(3) 没有系统级形态", wm_dsrc_fill(3, (const unsigned char *)"x", 1), 0);
    check("Img(2) 没有系统级形态", wm_dsrc_fill(2, (const unsigned char *)"x", 1), 0);
    check("空正文不算成功", wm_dsrc_fill(WM_DND_KIND_TEXT, (const unsigned char *)"", 0), 0);
    check("填失败后不留格式", wm_dsrc.cf, 0);
    int32_t seff = 999;
    int wl = probe_wire(wire, WM_DND_KIND_TEXT, "abc");
    check("越界窗口不拖", wm_dragdnd_send(9999, (const char *)wire, wl, 7, &seff), 0);
    check("载荷指针为空不拖", wm_dragdnd_send(win, NULL, wl, 7, &seff), 0);
    check("长度不足 4 不拖", wm_dragdnd_send(win, (const char *)wire, 3, 7, &seff), 0);
    check("out_effect 为空不拖", wm_dragdnd_send(win, (const char *)wire, wl, 7, NULL), 0);
    unsigned char bad[8];
    int bl = probe_wire(bad, 3, "abc"); // 种类没有系统级形态：fill 先失败，不会卡住鼠标
    check("不支持的种类不拖", wm_dragdnd_send(win, (const char *)bad, bl, 7, &seff), 0);
    check("失败路径不写效果", seff, 0);
  }

  /* ⑩ 真资源管理器的形态：数据对象**只实现 GetData**（就地取那条给 E_NOTIMPL）。
   * 这条复现的是「从资源管理器拖文件进来显示禁止、什么也拖不进」——只走
   * GetDataHere 时 QueryGetData 认得出格式、载荷却取不回来，效果就答成 NONE。 */
  {
    ProbeDo do5;
    probe_fill(&do5, probe_make_hdrop(paths, 2), NULL);
    do5.no_get_data_here = 1;
    eff = 999;
    check_true("只给 GetData 的对象 DragEnter 也成功",
               SUCCEEDED(dt->lpVtbl->DragEnter(dt, &do5.iface, 0, pt, &eff)));
    check("首拍承诺 COPY（不是禁止符）", eff, 1);
    check("路径档取回 = Paths(4)", probe_payload_kind(), 4);
    probe_payload_same("C:\\Temp\\甲文件.txt\nD:\\b.txt");
    eff = 999;
    dt->lpVtbl->DragOver(dt, 0, pt, &eff);
    check("未写回前 DragOver 答的仍是承诺值 COPY", eff, 1);
    ProbeDo do6;
    probe_fill(&do6, NULL, probe_make_text(L"只给 GetData 的文本"));
    do6.no_get_data_here = 1;
    eff = 999;
    dt->lpVtbl->DragEnter(dt, &do6.iface, 0, pt, &eff);
    check("文本档也取得回 = Text(1)", probe_payload_kind(), 1);
    probe_payload_same("只给 GetData 的文本");
    // 负面：两条取法都不给（真取不到时该老实答 NONE，不假装能收）
    ProbeDo do7;
    probe_fill(&do7, probe_make_hdrop(paths, 1), NULL);
    do7.no_get_data = 1;
    eff = 999;
    dt->lpVtbl->DragEnter(dt, &do7.iface, 0, pt, &eff);
    check("两条都取不到时答 NONE", eff, 0);
    check("两条都取不到时载荷为空", probe_payload_kind(), -1);
    probe_drain();
  }

  /* ⑪ 拆窗即撤钩 */
  wm_dragdnd_disable(win);
  check("撤钩后计数 0", wm_dragdnd_count(), 0);
  check("撤钩后效果读回 -1（未挂）", wm_dragdnd_effect(win), -1);
  wm_dragdnd_set_effect(win, 1); // 未挂时写效果不该崩
  check("未挂时 set_effect 不留痕", wm_dragdnd_effect(win), -1);
  wm_close(win);

  printf("%s\n", g_fail == 0 ? "DRAGDND-OK" : "DRAGDND-FAIL");
  return g_fail == 0 ? 0 : 1;
}
